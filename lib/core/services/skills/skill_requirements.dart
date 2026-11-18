import 'dart:convert';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../models/environment_state.dart';
import '../../providers/environment_provider.dart';
import '../workspace/workspace_runtime.dart';
import 'skill_frontmatter.dart';
import 'skill_readiness.dart';

/// Read-only requirement discovery for an installed Agent Skill.
///
/// The analyzer is intentionally conservative: file declarations and known
/// command invocations are reported with evidence and confidence. It never
/// executes a Skill file, installs a package, starts an MCP server, or calls an
/// external API.
abstract final class SkillRequirementsAnalyzer {
  static const _supportedManagers = <String, String>{
    'python': 'pip or uv (isolated Skill Runtime Profile)',
    'node': 'npm, pnpm, yarn or bun (isolated Skill Runtime Profile)',
    'system': 'apt or apk (shared Android PRoot RootFS)',
  };

  static const _knownCommands = <String>{
    'python', 'python3', 'pip', 'pip3', 'uv', 'node', 'npm', 'npx', 'pnpm',
    'yarn', 'bun', 'bunx', 'uvx', 'pipx', 'deno', 'tsx', 'ts-node', 'bash', 'sh', 'git', 'curl', 'wget', 'jq', 'unzip', 'zip',
    'ffmpeg', 'ffprobe', 'yt-dlp', 'mediainfo', 'ffmpegthumbnailer', 'magick',
    'convert', 'identify', 'tesseract', 'sox', 'pandoc', 'aria2c', 'sqlite3',
    'java', 'javac', 'gradle', 'flutter', 'dart', 'cargo', 'rustc', 'go', 'cmake', 'make', 'gcc', 'g++', 'apt', 'apt-get', 'apk',
    'ruby', 'gem', 'php', 'composer', 'perl', 'lua', 'Rscript', 'pwsh', 'chromium',
    'chromium-browser', 'google-chrome', 'playwright', 'docker', 'podman',
    'gh', 'git-lfs', '7z', 'tar', 'rclone', 'rsync', 'ssh', 'scp', 'adb', 'mvn', 'dotnet', 'msbuild',
    'ollama', 'whisper', 'whisper-cpp', 'huggingface-cli', 'aws', 'gcloud',
  };

  static const _extensionInterpreters = <String, String>{
    '.py': 'python3',
    '.sh': 'bash',
    '.bash': 'bash',
    '.js': 'node',
    '.mjs': 'node',
    '.cjs': 'node',
    '.rb': 'ruby',
    '.php': 'php',
    '.pl': 'perl',
    '.lua': 'lua',
    '.r': 'Rscript',
    '.ps1': 'pwsh',
  };

  static Map<String, Object?> analyze({
    required String skillId,
    required String skillMarkdown,
    required List<Map<String, Object?>> files,
    required List<Map<String, Object?>> capabilities,
    required List<Map<String, Object?>> dependencies,
    required Map<String, String> inspectedTextFiles,
  }) {
    final commands = <String, Map<String, Object?>>{};
    final toolchains = <String, Map<String, Object?>>{};
    final packages = <Map<String, Object?>>[];
    final credentials = <String, Map<String, Object?>>{};
    final services = <String, Map<String, Object?>>{};
    final notes = <String>[];

    void addCommand(String name, String evidence, String confidence) {
      final normalized = name.trim();
      if (!_isSafeToken(normalized)) return;
      final item = commands.putIfAbsent(normalized, () => <String, Object?>{
        'name': normalized,
        'evidence': <String>[],
        'confidence': confidence,
        'status': 'not_checked',
      });
      final evidenceList = item['evidence'] as List<String>;
      if (!evidenceList.contains(evidence)) evidenceList.add(evidence);
      if (confidence == 'declared') item['confidence'] = 'declared';
    }

    void addToolchain(String label, String command, String evidence) {
      final item = toolchains.putIfAbsent(command, () => <String, Object?>{
        'name': label,
        'command': command,
        'evidence': <String>[],
        'status': 'not_checked',
      });
      final entries = item['evidence'] as List<String>;
      if (!entries.contains(evidence)) entries.add(evidence);
      addCommand(command, evidence, 'declared');
    }

    final frontmatter = SkillFrontmatter.parse(skillMarkdown);
    final metadata = <String, Object?>{...frontmatter.metadata};
    if (frontmatter.parseError != null) {
      notes.add('SKILL.md frontmatter could not be fully parsed: ${frontmatter.parseError}. Requirements declared only in malformed metadata may be missing.');
    }
    List<String> metadataValues(List<String> keys) {
      final result = <String>{};
      for (final key in keys) {
        final raw = metadata[key];
        if (raw is! String) continue;
        for (final token in raw.split(RegExp(r'[,;\s]+'))) {
          final value = token.trim();
          if (value.isNotEmpty) result.add(value);
        }
      }
      return result.toList()..sort();
    }

    for (final command in metadataValues(const [
      'kelivo.required-commands', 'kelivo.required-binaries', 'kelivo.binaries',
    ])) {
      final evidence = '${_lineEvidence('SKILL.md', skillMarkdown, command)} (metadata)';
      if (_runtimeToolchainLabels.containsKey(command)) {
        addToolchain(_toolchainLabel(command), command, evidence);
      } else {
        addCommand(command, evidence, 'declared');
      }
    }
    for (final variable in metadataValues(const [
      'kelivo.required-env', 'kelivo.api-keys', 'kelivo.environment',
    ])) {
      if (_isSafeEnvName(variable)) {
        final evidence = '${_lineEvidence('SKILL.md', skillMarkdown, variable)} (metadata)';
        credentials.putIfAbsent(variable, () => <String, Object?>{
          'name': variable,
          'evidence': <String>[evidence],
          'status': 'not_checked',
        });
      }
    }
    for (final rawService in metadataValues(const [
      'kelivo.required-services', 'kelivo.services',
    ])) {
      final service = _safeServiceIdentifier(rawService);
      if (service.isEmpty) continue;
      final evidence = '${_lineEvidence('SKILL.md', skillMarkdown, rawService)} (metadata)';
      services.putIfAbsent(service, () => <String, Object?>{
        'name': service,
        'evidence': <String>[evidence],
        'status': 'manual_configuration_required',
        'verification': 'not_contacted',
      });
    }

    // Only files declared as executable entry points imply an interpreter.
    // Example/demo assets are preserved as Skill resources, not treated as
    // runnable Node/Python programs merely because of their file extension.
    final declaredEntryPoints = <String>{};
    for (final capability in capabilities) {
      if (!const {'local_script', 'cli_binary'}.contains(capability['kind'])) continue;
      final entryPoints = capability['entryPoints'];
      if (entryPoints is List) declaredEntryPoints.addAll(entryPoints.whereType<String>());
    }
    for (final file in files) {
      if (file['scope'] != 'skill') continue;
      final path = file['path']?.toString() ?? '';
      if (!declaredEntryPoints.contains(path)) continue;
      final interpreter = _extensionInterpreters[_extension(path)];
      if (interpreter != null) {
        addToolchain(_toolchainLabel(interpreter), interpreter, path);
      }
    }

    // Scan executable excerpts rather than arbitrary Markdown prose. A word
    // such as "make" in a sentence is not a GNU Make dependency. Markdown
    // commands are inferred only from inline/fenced code; prose is considered
    // only inside an explicit prerequisite section below.
    for (final entry in inspectedTextFiles.entries) {
      final source = entry.key;
      final text = entry.value;
      final isMarkdown = _extension(source) == '.md';
      final isDeclaredEntryPoint = declaredEntryPoints.contains(source);
      final isMcpConfig = const {'mcp.json', '.mcp.json', 'mcp-server.json'}
          .contains(source.split('/').last.toLowerCase());
      // Non-Markdown source excerpts are scanned for executable commands only
      // when the importer explicitly declared them as entry points or when
      // they are a structured MCP config whose command field is a dependency.
      // Example/demo/test/assets stay reference material, not requirements.
      final scanText = isMarkdown
          ? _markdownExecutableText(text)
          : isDeclaredEntryPoint || isMcpConfig
              ? text
              : '';
      final shebang = !isMarkdown && isDeclaredEntryPoint
          ? RegExp(r'^#!\s*(?:/usr/bin/env\s+)?([A-Za-z0-9_.+-]+)')
              .firstMatch(text.trimLeft())
          : null;
      if (shebang != null) {
        final interpreter = shebang.group(1)!;
        final mapped = switch (interpreter) {
          'python' => 'python3',
          'sh' => 'bash',
          'nodejs' => 'node',
          _ => interpreter,
        };
        addToolchain(_toolchainLabel(mapped), mapped, '$source:1 (shebang)');
      }
      for (final command in _knownCommands) {
        final detected = command == 'make'
            ? _hasExplicitMakeInvocation(scanText)
            : RegExp(
                r"""(?:^|[\s;&|()\"'`])""" + RegExp.escape(command) +
                    r"""(?=[\s$\"'`,;]|$)""",
                multiLine: true,
              ).hasMatch(scanText);
        if (detected) {
          addCommand(command, _lineEvidence(source, scanText, command), 'inferred');
          final associatedRuntime = switch (command) {
            'npm' || 'npx' || 'pnpm' || 'yarn' => 'node',
            'pip' || 'pip3' || 'pipx' || 'uv' || 'uvx' => 'python3',
            _ => null,
          };
          if (associatedRuntime != null) {
            addToolchain(_toolchainLabel(associatedRuntime), associatedRuntime, '$source (required by $command)');
          }
        }
      }
      for (final match in RegExp(r'\b[A-Z][A-Z0-9_]{1,}_(?:API_KEY|TOKEN|SECRET|PASSWORD|ACCESS_KEY|ACCESS_KEY_ID|CLIENT_ID|CLIENT_SECRET|BASE_URL|ENDPOINT|URL|USERNAME|APPLICATION_CREDENTIALS|SERVICE_ACCOUNT_FILE|PRIVATE_KEY)\b')
          .allMatches(text)) {
        final variable = match.group(0)!;
        final evidence = _lineEvidence(source, text, variable);
        credentials.putIfAbsent(variable, () => <String, Object?>{
          'name': variable,
          'evidence': <String>[evidence],
          'status': 'not_checked',
        });
        final evidenceList = credentials[variable]!['evidence'] as List<String>;
        if (!evidenceList.contains(evidence)) evidenceList.add(evidence);
      }
    }

    // Extract external hosts without retaining URL paths, query strings, or
    // possible tokens. This is discovery only; no connection is attempted.
    final serviceEvidence = <String, Set<String>>{};
    final serviceSources = <String, String>{
      'SKILL.md': skillMarkdown,
      ...inspectedTextFiles,
    };
    final urlPattern = RegExp(r'''https?://([^/?#\s"'<>`]+)''', caseSensitive: false);
    for (final entry in serviceSources.entries) {
      final text = entry.value;
      for (final match in urlPattern.allMatches(text)) {
        var host = (match.group(1) ?? '').toLowerCase();
        host = host.split('@').last.split(':').first.replaceAll(RegExp(r'[.,;:)\]}]+$'), '');
        if (host.isEmpty || host == 'localhost' || host == '127.0.0.1' ||
            host.endsWith('.local') || host == 'example.com' ||
            host == 'example.org' || host == 'example.net') {
          continue;
        }
        final lineNumber = text.substring(0, match.start).split('\n').length;
        serviceEvidence.putIfAbsent(host, () => <String>{}).add('${entry.key}:$lineNumber');
      }
    }
    for (final entry in serviceEvidence.entries) {
      services.putIfAbsent(entry.key, () => <String, Object?>{
        'name': entry.key,
        'host': entry.key,
        'evidence': entry.value.toList()..sort(),
        'status': 'manual_configuration_required',
        'verification': 'not_contacted',
      });
    }

    // Only explicitly titled prerequisite sections are mined for natural-
    // language declarations. Common verb "make" is accepted only when the
    // line clearly refers to the executable (install/run/require/command or
    // inline code), never when it means "make a video" or "make sure".
    final prerequisiteLines = _extractPrerequisiteLines(skillMarkdown);
    for (final line in prerequisiteLines) {
      for (final command in _knownCommands) {
        final text = line['text'] as String;
        final matches = command == 'make'
            ? _hasExplicitMakeRequirement(text)
            : RegExp('\\b${RegExp.escape(command)}\\b', caseSensitive: false).hasMatch(text);
        if (matches) {
          addCommand(command, 'SKILL.md:${line['number']} (prerequisites)', 'inferred');
        }
      }
    }

    for (final line in prerequisiteLines) {
      final text = line['text'] as String;
      for (final match in RegExp(r'\b[A-Z][A-Z0-9_]{1,}_(?:API_KEY|TOKEN|SECRET|PASSWORD|ACCESS_KEY|ACCESS_KEY_ID|CLIENT_ID|CLIENT_SECRET|BASE_URL|ENDPOINT|URL|USERNAME|APPLICATION_CREDENTIALS|SERVICE_ACCOUNT_FILE|PRIVATE_KEY)\b')
          .allMatches(text)) {
        final variable = match.group(0)!;
        final evidence = 'SKILL.md:${line['number']} (prerequisites)';
        credentials.putIfAbsent(variable, () => <String, Object?>{
          'name': variable,
          'evidence': <String>[evidence],
          'status': 'not_checked',
        });
      }
    }

    for (final dependency in dependencies) {
      final ecosystem = dependency['ecosystem']?.toString() ?? 'unknown';
      final manifestPath = dependency['manifestPath']?.toString() ?? 'unknown';
      final runtimeCommand = switch (ecosystem) {
        'python' => 'python3',
        'node' => 'node',
        'rust' => 'cargo',
        'go' => 'go',
        'ruby' => 'ruby',
        'php' => 'php',
        _ => null,
      };
      if (runtimeCommand != null) {
        addToolchain(_toolchainLabel(runtimeCommand), runtimeCommand, manifestPath);
      }
      final rawPackages = dependency['dependencies'];
      if (rawPackages is List) {
        for (final raw in rawPackages.whereType<String>()) {
          final trimmed = _safeDependencyDeclaration(raw.trim());
          if (trimmed.isEmpty) continue;
          final name = trimmed.split(RegExp(r'\s+')).first;
          final manifestText = inspectedTextFiles[manifestPath] ?? '';
          packages.add(<String, Object?>{
            'name': name,
            'declaration': trimmed,
            'ecosystem': ecosystem,
            'manifestPath': manifestPath,
            'evidence': _lineEvidence(manifestPath, manifestText, name),
            'manager': _supportedManagers[ecosystem],
            'managerSupported': _supportedManagers.containsKey(ecosystem),
            'status': 'not_checked_in_skill_profile',
          });
        }
      }
      if (!_supportedManagers.containsKey(ecosystem) && ecosystem != 'unknown') {
        notes.add('$ecosystem dependencies are detected in $manifestPath, but Kelivo does not currently manage this ecosystem through its package manager.');
      }
    }

    // Capture explicit package-install declarations in Skill scripts and
    // deployment instructions. This is static parsing only: no command is run.
    final installPatterns = <({RegExp pattern, String ecosystem, String manager})>[
      (pattern: RegExp(r'\b(?:python3?\s+-m\s+)?pip3?\s+install\s+(.+)$'), ecosystem: 'python', manager: 'pip'),
      (pattern: RegExp(r'\b(?:npm\s+(?:install|i)|pnpm\s+add|yarn\s+add|bun\s+add)\s+(.+)$'), ecosystem: 'node', manager: 'npm-family'),
      (pattern: RegExp(r'\b(?:apt-get|apt)\s+install(?:\s+-y)?\s+(.+)$'), ecosystem: 'system', manager: 'apt'),
      (pattern: RegExp(r'\bapk\s+add(?:\s+--no-cache)?\s+(.+)$'), ecosystem: 'system', manager: 'apk'),
      (pattern: RegExp(r'\bcargo\s+install\s+(.+)$'), ecosystem: 'rust', manager: 'cargo'),
      (pattern: RegExp(r'\bgo\s+install\s+(.+)$'), ecosystem: 'go', manager: 'go'),
      (pattern: RegExp(r'\bgem\s+install\s+(.+)$'), ecosystem: 'ruby', manager: 'gem'),
      (pattern: RegExp(r'\bcomposer\s+require\s+(.+)$'), ecosystem: 'php', manager: 'composer'),
    ];
    for (final entry in inspectedTextFiles.entries) {
      final installLines = const LineSplitter().convert(entry.value);
      for (var lineIndex = 0; lineIndex < installLines.length; lineIndex++) {
        final line = installLines[lineIndex].trim();
        if (line.isEmpty || line.startsWith('#')) continue;
        for (final descriptor in installPatterns) {
          final match = descriptor.pattern.firstMatch(line);
          if (match == null) continue;
          final tail = match.group(1) ?? '';
          final tokens = tail.split(RegExp(r'\s+'));
          for (var tokenIndex = 0; tokenIndex < tokens.length; tokenIndex++) {
            var token = tokens[tokenIndex].trim().replaceAll(RegExp(r'''^[\"']+|[\"',;]+$'''), '');
            if (const {'-r', '--requirement', '-c', '--constraint', '-e', '--editable',
              '-f', '--find-links', '--index-url', '--extra-index-url'}.contains(token)) {
              tokenIndex++;
              continue;
            }
            if (token.isEmpty || token.startsWith('-') ||
                const {'&&', '||', ';', '\\'}.contains(token) ||
                token.startsWith(r'$') || token.startsWith('<') || token.startsWith('>')) {
              continue;
            }
            final safeDeclaration = _safeDependencyDeclaration(token);
            if (safeDeclaration.isEmpty || safeDeclaration.contains('://')) continue;
            final packagePattern = switch (descriptor.ecosystem) {
              'node' => RegExp(r'^@?[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)?(?:@[^\s]+)?$'),
              'go' || 'php' => RegExp(r'^[A-Za-z0-9_.+-]+(?:/[A-Za-z0-9_.+-]+)+(?:@[A-Za-z0-9_.+-]+)?$'),
              _ => RegExp(r'^[A-Za-z0-9_.+-]+(?:(?:==|>=|<=|~=|!=|=|>|<)[A-Za-z0-9_.+,:-]+)?$'),
            };
            if (!packagePattern.hasMatch(safeDeclaration)) continue;
            final manager = descriptor.manager == 'npm-family'
                ? (line.startsWith('pnpm ') ? 'pnpm' : line.startsWith('yarn ') ? 'yarn' : line.startsWith('bun ') ? 'bun' : 'npm')
                : descriptor.manager;
            final packageName = descriptor.ecosystem == 'node' && safeDeclaration.startsWith('@')
                ? safeDeclaration.substring(0, safeDeclaration.indexOf('@', safeDeclaration.indexOf('/') + 1) < 0
                    ? safeDeclaration.length
                    : safeDeclaration.indexOf('@', safeDeclaration.indexOf('/') + 1))
                : safeDeclaration.split(RegExp(r'[=<>!~^@]')).first;
            packages.add(<String, Object?>{
              'name': packageName,
              'declaration': safeDeclaration,
              'ecosystem': descriptor.ecosystem,
              'manifestPath': entry.key,
              'manager': manager,
              'managerSupported': _supportedManagers.containsKey(descriptor.ecosystem),
              'status': 'not_checked_in_skill_profile',
              'evidence': '${entry.key}:${lineIndex + 1} (explicit install command; not executed)',
            });
          }
          break;
        }
      }
    }

    final declaredManager = metadata['kelivo.package-manager']?.toString().trim();
    final declaredPackages = metadataValues(const ['kelivo.packages']);
    if (declaredPackages.isNotEmpty) {
      final ecosystem = switch (declaredManager) {
        'apt' || 'apk' => 'system',
        'pip' || 'uv' => 'python',
        'npm' || 'pnpm' || 'yarn' || 'bun' => 'node',
        _ => 'unknown',
      };
      for (final rawDeclaration in declaredPackages) {
        final declaration = _safeDependencyDeclaration(rawDeclaration);
        if (declaration.isEmpty) continue;
        packages.add(<String, Object?>{
          'name': declaration,
          'declaration': declaration,
          'ecosystem': ecosystem,
          'manifestPath': 'SKILL.md metadata',
          'manager': declaredManager,
          'managerSupported': _supportedManagers.containsKey(ecosystem),
          'status': 'not_checked_in_skill_profile',
        });
      }
      if (ecosystem == 'unknown') {
        notes.add('The Skill declares package dependencies but does not use a supported explicit Kelivo package manager contract.');
      }
    }

    final capabilityAssessment = <Map<String, Object?>>[];
    for (final capability in capabilities) {
      final kind = capability['kind']?.toString() ?? 'unknown';
      final descriptorId = capability['id']?.toString().trim();
      final rawEntryPoints = capability['entryPoints'];
      final descriptorFields = <String, Object?>{
        'id': descriptorId?.isNotEmpty == true ? descriptorId : kind,
        if (rawEntryPoints is List)
          'entryPoints': rawEntryPoints.whereType<String>().toList(growable: false),
        'requiredForReadiness': capability['requiredForReadiness'] != false,
      };
      final item = switch (kind) {
        'instruction_only' => <String, Object?>{
          ...descriptorFields,
          'kind': kind,
          'support': 'supported',
          'detail': 'Instructions can be read and followed by the assistant. This does not install tools or execute scripts.',
        },
        'local_script' => <String, Object?>{
          ...descriptorFields,
          'kind': kind,
          'support': 'conditional',
          'detail': 'Only Python, Bash and Node entry points are supported by the approved Skill executor; a Skill-owned Runtime Profile and per-run approval are required.',
        },
        'cli_binary' => <String, Object?>{
          ...descriptorFields,
          'kind': kind,
          'support': 'environment_work_required',
          'detail': 'Bundled native executables are preserved but are not launched by skill_execute. Install/validate a compatible tool in the Linux PRoot environment and add an approved adapter before use.',
        },
        'mcp_server' => <String, Object?>{
          ...descriptorFields,
          'kind': kind,
          'support': 'manual_adapter_required',
          'detail': 'The MCP configuration is detected and preserved, but Skill import does not register or start this server. Add it through Kelivo MCP configuration after reviewing command, transport and permissions.',
        },
        'http_api_connector' => <String, Object?>{
          ...descriptorFields,
          'kind': kind,
          'support': 'adapter_required',
          'detail': 'The API/OpenAPI descriptor is preserved; automatic Skill-owned connector activation is not implemented. The required API host, authentication and operations must be reviewed and connected.',
        },
        'native_kelivo_tool' => <String, Object?>{
          ...descriptorFields,
          'kind': kind,
          'support': 'requires_kelivo_development',
          'detail': 'A Skill package cannot add executable native Dart code to Kelivo. Implement and register a reviewed native adapter in the app.',
        },
        'workflow' => <String, Object?>{
          ...descriptorFields,
          'kind': kind,
          'support': 'adapter_required',
          'detail': 'The workflow definition is preserved, but a compatible workflow runner/adapter is required before it can run.',
        },
        _ => <String, Object?>{
          ...descriptorFields,
          'kind': kind,
          'support': 'unknown',
          'detail': 'Kelivo has not classified this capability.',
        },
      };
      capabilityAssessment.add(item);
    }

    final unsupportedCapabilities = capabilityAssessment.where((item) =>
      const {'environment_work_required', 'manual_adapter_required', 'adapter_required', 'requires_kelivo_development'}
          .contains(item['support'])).length;
    final conditionalCapabilities = capabilityAssessment.where((item) =>
      item['support'] == 'conditional').length;
    final uniquePackages = <String, Map<String, Object?>>{};
    for (final package in packages) {
      final key = '${package['ecosystem']}:${package['name']}';
      uniquePackages.putIfAbsent(key, () => package);
    }

    for (final item in [...commands.values, ...toolchains.values]) {
      final evidence = item['evidence'];
      if (evidence is List<String>) evidence.sort();
    }
    for (final item in credentials.values) {
      final evidence = item['evidence'];
      if (evidence is List<String>) evidence.sort();
    }

    // Capability declarations describe what a Skill can do, not necessarily
    // what external environment dependencies it requires. In particular,
    // instruction_only is descriptive metadata and must not suppress this
    // conservative no-evidence warning. External services are requirement
    // evidence even when no local command/package/credential is declared.
    final hasRequirementEvidence = commands.isNotEmpty ||
        uniquePackages.isNotEmpty ||
        credentials.isNotEmpty ||
        services.isNotEmpty;
    if (!hasRequirementEvidence) {
      notes.add('No external runtime, command, package, credential, or service requirements could be identified from the available Skill files. Instruction-only capability declarations are not environment requirement evidence. Inspect SKILL.md manually; absence of detection is not proof that no requirements exist.');
    }

    return <String, Object?>{
      'schemaVersion': 1,
      'analyzedAt': DateTime.now().toUtc().toIso8601String(),
      'analysisMode': 'static_read_only',
      'skillId': skillId,
      'toolchains': toolchains.values.toList()..sort((a, b) => a['command'].toString().compareTo(b['command'].toString())),
      'commands': commands.values.toList()..sort((a, b) => a['name'].toString().compareTo(b['name'].toString())),
      'packages': uniquePackages.values.toList()..sort((a, b) => '${a['ecosystem']}:${a['name']}'.compareTo('${b['ecosystem']}:${b['name']}')),
      'credentials': credentials.values.toList()..sort((a, b) => a['name'].toString().compareTo(b['name'].toString())),
      'externalServices': services.values.toList()..sort((a, b) => a['name'].toString().compareTo(b['name'].toString())),
      'capabilities': capabilityAssessment,
      'summary': <String, Object?>{
        'commandCount': commands.length,
        'toolchainCount': toolchains.length,
        'packageCount': uniquePackages.length,
        'credentialCount': credentials.length,
        'externalServiceCount': services.length,
        'capabilityCount': capabilityAssessment.length,
        'unsupportedOrAdapterRequiredCapabilities': unsupportedCapabilities,
        'conditionalCapabilities': conditionalCapabilities,
      },
      'readiness': 'not_probed',
      'notes': notes.toSet().toList()..sort(),
      'safety': <String, Object?>{
        'skillScriptsExecuted': false,
        'packagesInstalled': false,
        'mcpServersStarted': false,
        'externalApisCalled': false,
        'secretValuesExtractedOrReturned': false,
      },
    };
  }

  static List<Map<String, Object?>> _extractPrerequisiteLines(String markdown) {
    final output = <Map<String, Object?>>[];
    var inSection = false;
    final lines = const LineSplitter().convert(markdown);
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      if (RegExp(r'^#{1,6}\s+').hasMatch(line)) {
        inSection = RegExp(r'^#{1,6}\s+(?:requirements?|prerequisites?|dependencies|setup|installation|environment)(?:\s|$)', caseSensitive: false)
            .hasMatch(line.trim());
        continue;
      }
      if (inSection) output.add({'number': index + 1, 'text': line});
    }
    return output;
  }

  /// Keeps only fenced and inline code while preserving line positions.
  static String _markdownExecutableText(String markdown) {
    // Dart String indices are UTF-16 code-unit offsets. Work on codeUnits so
    // Arabic and other non-BMP text cannot desynchronize line offsets.
    final codeUnits = List<int>.of(markdown.codeUnits);
    final keep = List<bool>.filled(codeUnits.length, false);
    var offset = 0;
    var fenceMarker = '';
    var fenceLength = 0;
    for (final rawLine in markdown.split('\n')) {
      final line = rawLine.endsWith('\r')
          ? rawLine.substring(0, rawLine.length - 1)
          : rawLine;
      final trimmed = line.trimLeft();
      final marker = RegExp(r'^(`{3,}|~{3,})').firstMatch(trimmed);
      if (marker != null) {
        final token = marker.group(1)!;
        if (fenceMarker.isEmpty) {
          fenceMarker = token.substring(0, 1);
          fenceLength = token.length;
        } else if (token.startsWith(fenceMarker) && token.length >= fenceLength) {
          fenceMarker = '';
          fenceLength = 0;
        }
      } else if (fenceMarker.isNotEmpty) {
        for (var i = 0; i < line.length; i++) {
          keep[offset + i] = true;
        }
      } else {
        for (final match in RegExp(r'(`+)(.+?)\1').allMatches(line)) {
          final start = match.start + match.group(1)!.length;
          final end = match.end - match.group(1)!.length;
          for (var i = start; i < end; i++) {
            keep[offset + i] = true;
          }
        }
      }
      offset += rawLine.length + 1;
    }
    for (var i = 0; i < codeUnits.length; i++) {
      if (codeUnits[i] != 0x0A && !keep[i]) codeUnits[i] = 0x20;
    }
    return String.fromCharCodes(codeUnits);
  }

  static bool _hasExplicitMakeInvocation(String text) {
    return RegExp(r'^\s*(?:\$\s*)?(?:sudo\s+)?make(?:\s|$)', multiLine: true)
            .hasMatch(text) ||
        RegExp(r"""(?:spawn|exec|execFile|run|Process\.run|command)\s*\([^)]*['\"]make['\"]""", caseSensitive: false)
            .hasMatch(text) ||
        RegExp(r"""(?:command\s+-v|which)\s+make(?:\s|$)""", multiLine: true)
            .hasMatch(text);
  }

  static bool _hasExplicitMakeRequirement(String line) {
    final value = line.trim();
    if (value.isEmpty) return false;
    if (RegExp(r'`+\s*make(?:\s|`)', caseSensitive: false).hasMatch(value)) return true;
    // GNU Make is an unambiguous tool name even in a descriptive sentence.
    if (RegExp(r'\bGNU\s+Make\b', caseSensitive: false).hasMatch(value)) return true;
    // Accept explicit tool/utility/package wording, but not ordinary prose
    // such as "make a reel", "make sure", or "need to make a scene".
    return RegExp(
      r'\b(?:install|requires?|required|needs?|need|run|execute|invoke|check(?:\s+for)?|verify)\s+(?:the\s+)?make\s+(?:tool|utility|command|package|binary|executable)\b',
      caseSensitive: false,
    ).hasMatch(value);
  }

  static String _lineEvidence(String source, String text, String token) {
    final pattern = RegExp('\\b${RegExp.escape(token)}\\b', caseSensitive: false);
    final lines = const LineSplitter().convert(text);
    for (var index = 0; index < lines.length; index++) {
      if (pattern.hasMatch(lines[index])) return '$source:${index + 1}';
    }
    return source;
  }

  static String _safeDependencyDeclaration(String value) {
    var safe = value.replaceAllMapped(
      RegExp(r'''https?://([^/\s?#"'<>`]+)[^\s"'<>`]*''', caseSensitive: false),
      (match) {
        final host = _safeServiceIdentifier('https://${match.group(1)}');
        return host.isEmpty ? '[external-url]' : 'https://$host';
      },
    );
    safe = safe.replaceAllMapped(
      RegExp(r'''([A-Za-z0-9_]*(?:API_KEY|TOKEN|SECRET|PASSWORD|ACCESS_KEY(?:_ID)?|CLIENT_SECRET)=)[^\s]+''', caseSensitive: false),
      (match) => '${match.group(1)}[redacted]',
    );
    return safe;
  }

  static String _safeServiceIdentifier(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasAuthority && uri.host.isNotEmpty) {
      return uri.host.toLowerCase();
    }
    final candidate = trimmed
        .split('/').first
        .split('?').first
        .split('#').first
        .split('@').last
        .split(':').first
        .replaceAll(RegExp(r'[.,;:)\\]}]+$'), '');
    return RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,253}$').hasMatch(candidate)
        ? candidate.toLowerCase()
        : '';
  }

  static String _extension(String path) {
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot).toLowerCase();
  }

  static const _runtimeToolchainLabels = <String, String>{
    'python': 'Python', 'python3': 'Python 3', 'node': 'Node.js', 'bash': 'Bash', 'sh': 'Shell',
    'java': 'Java', 'javac': 'Java compiler', 'ruby': 'Ruby', 'php': 'PHP',
    'perl': 'Perl', 'lua': 'Lua', 'Rscript': 'R', 'pwsh': 'PowerShell',
    'go': 'Go', 'cargo': 'Rust toolchain', 'rustc': 'Rust compiler',
    'flutter': 'Flutter SDK', 'dart': 'Dart SDK', 'gradle': 'Gradle', 'deno': 'Deno',
  };

  static String _toolchainLabel(String command) => _runtimeToolchainLabels[command] ?? command;

  static bool _isSafeToken(String value) =>
      RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.+-]{0,127}$').hasMatch(value);

  static bool _isSafeEnvName(String value) =>
      RegExp(r'^[A-Z][A-Z0-9_]{2,127}$').hasMatch(value);
}

/// Live, read-only environment check. It probes only validated command names
/// with `command -v`; it never runs Skill scripts or installs packages.
abstract final class SkillEnvironmentRequirementProbe {
  static Future<Map<String, Object?>> assess({
    required Map<String, Object?> importReport,
    required WorkspaceRuntime? runtime,
    required EnvironmentProvider? environment,
  }) async {
    final rawRequirements = importReport['requirements'];
    final result = rawRequirements is Map
        ? Map<String, Object?>.from(rawRequirements)
        : <String, Object?>{};
    final commands = (result['commands'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .toList();
    result['commands'] = commands;
    result['checkedAt'] = DateTime.now().toUtc().toIso8601String();

    if (environment != null) {
      try {
        await environment.loaded.timeout(const Duration(seconds: 8));
      } catch (error) {
        result['environmentLoadError'] = error.runtimeType.toString();
        for (final command in commands) {
          command['status'] = 'not_checked_environment_load_failed';
        }
        for (final credential in (result['credentials'] as List? ?? const []).whereType<Map>()) {
          credential['status'] = 'not_checked_environment_unavailable';
        }
        result['environment'] = <String, Object?>{
          'status': 'unavailable',
          'reason': 'environment_load_failed',
        };
        _finalizeReadiness(
          result,
          importCompleteness: importReport['completeness']?.toString() ?? 'unknown',
        );
        return result;
      }
    }
    final envState = environment?.state;
    final runtimeAssessment = <String, Object?>{
      'status': 'not_checked',
      'distribution': envState?.distro,
      'version': envState?.version,
      'architecture': envState?.arch,
    };
    result['environment'] = runtimeAssessment;
    final distro = (envState?.distro ?? '').toLowerCase();
    result['packageManagerSupport'] = <String, Object?>{
      'system': const {'ubuntu', 'debian'}.contains(distro)
          ? 'apt_expected_from_distribution_not_verified'
          : distro == 'alpine'
              ? 'apk_expected_from_distribution_not_verified'
              : 'unsupported_or_unknown_distribution',
      'python': 'pip_uv_supported_but_requires_skill_runtime_profile',
      'node': 'npm_family_supported_but_requires_skill_runtime_profile',
      'rust': 'not_supported_by_current_package_manager',
      'go': 'not_supported_by_current_package_manager',
      'ruby': 'not_supported_by_current_package_manager',
      'php': 'not_supported_by_current_package_manager',
    };
    for (final package in (result['packages'] as List? ?? const []).whereType<Map>()) {
      final ecosystem = package['ecosystem']?.toString() ?? 'unknown';
      package['environmentSupport'] = (result['packageManagerSupport'] as Map)[ecosystem] ?? 'unsupported_or_unclassified';
      package['status'] = package['managerSupported'] == true
          ? 'not_checked_in_skill_profile'
          : 'requires_environment_development_or_manual_setup';
    }

    // Only test whether a variable name is configured; secret values are never
    // read, copied into reports, or passed to this analyzer.
    final configuredNames = environment == null
        ? <String>{}
        : environment.variables.map((item) => item.name).toSet();
    for (final credential in (result['credentials'] as List? ?? const []).whereType<Map>()) {
      final name = credential['name']?.toString() ?? '';
      credential['status'] = environment == null
          ? 'not_checked_environment_unavailable'
          : configuredNames.contains(name)
              ? 'configured_in_kelivo_environment'
              : 'missing_configuration';
    }

    void markCommands(String status) {
      for (final command in commands) {
        command['status'] = status;
      }
    }

    if (environment == null || runtime == null) {
      runtimeAssessment['reason'] = 'environment_or_runtime_provider_unavailable';
      markCommands('not_checked_environment_unavailable');
      _finalizeReadiness(
        result,
        importCompleteness: importReport['completeness']?.toString() ?? 'unknown',
      );
      return result;
    }
    if (envState?.phase != EnvironmentPhase.ready) {
      runtimeAssessment
        ..['status'] = 'not_ready'
        ..['reason'] = 'rootfs_phase_${envState?.phase.name ?? 'unknown'}';
      markCommands('not_checked_environment_not_ready');
      _finalizeReadiness(
        result,
        importCompleteness: importReport['completeness']?.toString() ?? 'unknown',
      );
      return result;
    }

    RuntimeStatus runtimeStatus;
    try {
      runtimeStatus = await runtime.status().timeout(const Duration(seconds: 8));
    } catch (error) {
      runtimeAssessment
        ..['status'] = 'unavailable'
        ..['reason'] = error.runtimeType.toString();
      markCommands('not_checked_runtime_unavailable');
      _finalizeReadiness(
        result,
        importCompleteness: importReport['completeness']?.toString() ?? 'unknown',
      );
      return result;
    }
    runtimeAssessment.addAll({
      'status': runtimeStatus.ready && runtimeStatus.sandboxed && runtimeStatus.engine == 'proot'
          ? 'ready'
          : 'unsupported_for_skill_execution',
      'engine': runtimeStatus.engine,
      'sandboxed': runtimeStatus.sandboxed,
      'ready': runtimeStatus.ready,
      if (runtimeStatus.reason != null) 'reason': runtimeStatus.reason,
    });
    if (!runtimeStatus.ready || !runtimeStatus.sandboxed || runtimeStatus.engine != 'proot') {
      markCommands('not_checked_unsupported_environment');
      _finalizeReadiness(
        result,
        importCompleteness: importReport['completeness']?.toString() ?? 'unknown',
      );
      return result;
    }

    final commandNames = commands
        .map((item) => item['name']?.toString() ?? '')
        .where((name) => RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.+-]{0,127}$').hasMatch(name))
        .toSet()
        .take(64)
        .toList();
    if (commandNames.isEmpty) {
      result['commandProbe'] = 'not_needed';
    } else {
      final output = BytesBuilder(copy: false);
      var captured = 0;
      CommandExited? exit;
      final script = StringBuffer();
      for (var index = 0; index < commandNames.length; index++) {
        final name = commandNames[index];
        script.writeln("if command -v '$name' >/dev/null 2>&1; then printf '__KELIVO_SKILL_REQ_${index}=1\\n'; else printf '__KELIVO_SKILL_REQ_${index}=0\\n'; fi");
      }
      try {
        await for (final event in runtime.run(CommandRequest(
          runId: 'skill-requirements-${const Uuid().v4()}',
          command: script.toString(),
          cwd: '/',
          timeout: const Duration(seconds: 30),
        ))) {
          if (event is CommandOutput && captured < 16 * 1024) {
            final remaining = 16 * 1024 - captured;
            final chunk = event.bytes.length <= remaining ? event.bytes : event.bytes.sublist(0, remaining);
            output.add(chunk);
            captured += chunk.length;
          } else if (event is CommandExited) {
            exit = event;
          }
        }
      } catch (error) {
        result['commandProbeError'] = error.runtimeType.toString();
        exit = null;
      }
      final lines = const LineSplitter().convert(utf8.decode(output.takeBytes(), allowMalformed: true));
      if (exit == null || exit.timedOut || exit.cancelled || exit.interrupted) {
        result['commandProbe'] = 'failed';
        markCommands('probe_failed');
      } else {
        result['commandProbe'] = 'completed';
        for (var index = 0; index < commandNames.length; index++) {
          final marker = '__KELIVO_SKILL_REQ_$index=';
          final matching = lines.where((value) => value.startsWith(marker)).toList();
          final line = matching.isEmpty ? null : matching.first;
          final status = line == null ? 'unknown' : line.endsWith('=1') ? 'installed' : 'missing';
          for (final command in commands.where((item) => item['name'] == commandNames[index])) {
            command['status'] = status;
            command['verifiedIn'] = 'base_proot_environment';
          }
        }
      }
    }
    _finalizeReadiness(
      result,
      importCompleteness: importReport['completeness']?.toString() ?? 'unknown',
    );
    return result;
  }

  static void _finalizeReadiness(
    Map<String, Object?> result, {
    required String importCompleteness,
  }) {
    SkillReadinessEngine.apply(
      requirements: result,
      importCompleteness: importCompleteness,
    );
  }

  static String toMarkdown(
    Map<String, Object?> report, {
    bool arabic = false,
  }) {
    String managerLabel(Object? value) {
      final raw = value?.toString() ?? 'unknown';
      if (!arabic) return raw;
      const labels = <String, String>{
        'pip_uv_supported_but_requires_skill_runtime_profile': 'مدعوم عبر pip/uv بعد إنشاء ملف تشغيل معزول والتحقق منه',
        'npm_family_supported_but_requires_skill_runtime_profile': 'مدعوم عبر npm/pnpm/yarn/bun بعد إنشاء ملف تشغيل معزول والتحقق منه',
        'apt_expected_from_distribution_not_verified': 'يُتوقع apt حسب التوزيعة، ولم يتم التحقق من مدير الحزم',
        'apk_expected_from_distribution_not_verified': 'يُتوقع apk حسب التوزيعة، ولم يتم التحقق من مدير الحزم',
        'not_supported_by_current_package_manager': 'غير مدعوم حالياً من مدير الحزم في KELIVO',
        'unsupported_or_unknown_distribution': 'توزيعة غير معروفة أو غير مدعومة',
        'unsupported_or_unclassified': 'غير مدعوم أو غير مصنف',
      };
      return labels[raw] ?? raw;
    }

    String statusLabel(Object? value) {
      final raw = value?.toString() ?? 'not_checked';
      if (!arabic) return raw;
      return switch (raw) {
        'installed' => 'مثبّت في بيئة PRoot الأساسية',
        'missing' => 'غير موجود',
        'not_checked' => 'لم يُفحص',
        'not_checked_in_skill_profile' => 'لم يُفحص داخل ملف تشغيل المهارة',
        'configured_in_kelivo_environment' => 'اسم المتغير مُعدّ في KELIVO؛ لم يتم التحقق من صلاحية السر',
        'missing_configuration' => 'الإعداد مفقود',
        'manual_configuration_required' => 'يتطلب إعداداً يدوياً',
        'requirements_missing' => 'متطلبات مفقودة',
        'requirements_pending_or_adapter_work' => 'متطلبات معلّقة أو تحتاج إلى موائم',
        'ready' => 'جاهزة ومجتازة للتحقق',
        'instruction_only_ready' => 'جاهزة للتوجيهات النصية فقط',
        'blocked_incomplete_import' => 'محجوبة: ملفات التثبيت غير مكتملة',
        'analysis_required' => 'تحتاج إلى تحليل المتطلبات',
        'dependencies_pending' => 'تحتاج إلى حل الاعتماديات داخل ملف التشغيل',
        'configuration_required' => 'تحتاج إلى إعداد أو تحقق الاتصال',
        'validation_required' => 'تحتاج إلى اختبار ذاتي ناجح',
        'commands_verified' => 'تم التحقق من أوامر البيئة الأساسية',
        'no_cli_requirements_detected' => 'لم تُكتشف أدوات سطر أوامر',
        'unsupported_environment' => 'البيئة الحالية غير مدعومة',
        'environment_not_ready' => 'بيئة PRoot غير جاهزة',
        'probe_failed' => 'تعذر فحص البيئة',
        'not_checked_environment_unavailable' => 'لم يُفحص: البيئة غير متاحة',
        'not_checked_environment_not_ready' => 'لم يُفحص: بيئة PRoot غير جاهزة',
        'not_checked_unsupported_environment' => 'لم يُفحص: البيئة غير مدعومة',
        'not_checked_runtime_unavailable' => 'لم يُفحص: runtime غير متاح',
        'not_checked_environment_load_failed' => 'لم يُفحص: تعذر تحميل إعدادات البيئة',
        _ => raw,
      };
    }

    final out = StringBuffer()
      ..writeln(arabic ? '### متطلبات بيئة المهارة' : '### Skill environment requirements')
      ..writeln(arabic
          ? '- حالة الجاهزية: **${statusLabel(report['readiness'])}**'
          : '- Readiness: **${statusLabel(report['readiness'])}**')
      ..writeln(arabic
          ? '- نوع التقرير: اكتشاف للقراءة فقط؛ وجود المتطلبات في التقرير لا يثبت أن المهارة تعمل بالكامل.'
          : '- Report type: read-only discovery; detection does not prove the Skill is fully operational.');
    final readinessState = report['readinessState']?.toString();
    if (readinessState != null) {
      final stateLabel = arabic ? switch (readinessState) {
        'ready' => 'جاهزة بعد التحقق',
        'ready_for_instructions' => 'جاهزة للتعليمات فقط',
        'blocked_incomplete_import' => 'محجوبة بسبب نقص ملفات الاستيراد',
        'analysis_required' => 'تحتاج إلى تحليل',
        'requirements_missing' => 'توجد متطلبات مفقودة',
        'unsupported_environment' => 'توجد قدرات غير مدعومة',
        'dependencies_pending' => 'الاعتماديات لم تُتحقق داخل ملف التشغيل',
        'configuration_required' => 'تحتاج إلى إعداد أو تحقق خارجي',
        'validation_required' => 'تحتاج إلى اختبار ذاتي ناجح',
        _ => readinessState,
      } : readinessState;
      out.writeln(arabic ? '- الحالة التفصيلية: **$stateLabel**.' : '- Detailed state: **$stateLabel**.');
      final stages = report['readinessStages'];
      if (stages is Map) {
        out.writeln(arabic ? '\n**مراحل الجاهزية**' : '\n**Readiness stages**');
        const labels = <String, String>{
          'installed': 'التثبيت',
          'analyzed': 'تحليل المتطلبات',
          'dependenciesResolved': 'حل الاعتماديات',
          'configured': 'الإعداد',
          'validated': 'الاختبار والتحقق',
        };
        for (final entry in stages.entries) {
          if (entry.value is! Map) continue;
          final stage = Map<String, Object?>.from(entry.value as Map);
          final complete = stage['status'] == 'complete';
          out.writeln(arabic
              ? '- ${labels[entry.key] ?? entry.key}: ${complete ? 'مكتمل' : stage['status'] == 'blocked' ? 'محجوب' : 'معلّق'} — ${stage['detail'] ?? ''}'
              : '- ${entry.key}: ${stage['status']} — ${stage['detail'] ?? ''}');
        }
      }
    }
    final registry = report['capabilityRegistry'];
    if (registry is Map) {
      final required = (registry['requiredCapabilities'] as List? ?? const []).whereType<Map>().toList();
      if (required.isNotEmpty) {
        out.writeln(arabic ? '\n**سجل قدرات KELIVO لهذه المهارة**' : '\n**Kelivo capability registry assessment**');
        for (final item in required) {
          final status = item['status']?.toString() ?? 'unknown';
          final label = arabic ? switch (status) {
            'supported' => 'مدعومة',
            'requires_runtime_profile_and_approval' => 'تحتاج ملف تشغيل وموافقة لكل تنفيذ',
            'verified_in_skill_runtime_profile' => 'تم التحقق داخل ملف تشغيل المهارة',
            'detected_in_base_environment_only' => 'مكتشفة في PRoot الأساسي فقط',
            'environment_not_verified' => 'لم يتم التحقق من البيئة',
            'not_operational_in_current_skill_adapter' => 'غير مدعومة حالياً بواسطة موائم المهارات',
            'unknown' => 'قدرة غير معروفة؛ لا يفترض KELIVO دعمها',
            _ => 'غير معروفة',
          } : status;
          out.writeln('- `${item['title'] ?? item['kind']}`: $label — ${item['scope'] ?? ''}');
        }
      }
    }
    final environment = report['environment'];
    if (environment is Map) {
      out.writeln(arabic
          ? '- البيئة: ${environment['distribution'] ?? 'غير معروفة'} ${environment['version'] ?? ''}؛ المعمارية ${environment['architecture'] ?? 'غير معروفة'}؛ حالة runtime: ${statusLabel(environment['status'])}.'
          : '- Environment: ${environment['distribution'] ?? 'unknown'} ${environment['version'] ?? ''}; ${environment['architecture'] ?? 'architecture unknown'}; runtime ${environment['status'] ?? 'not checked'}');
      out.writeln(arabic
          ? '- معلومات مدير الحزم مستنتجة من التوزيعة فقط؛ لم يتم تثبيت الحزم أو التحقق من ملف تشغيل المهارة.'
          : '- Package-manager entries are distribution hints only; actual package installation and Skill Runtime Profile verification have not been performed.');
    }
    final summary = report['readinessSummary'];
    if (summary is Map) {
      out.writeln(arabic
          ? '- أوامر تم التحقق منها داخل ملف تشغيل المهارة: ${summary['commandsVerified'] ?? 0}؛ مكتشفة في PRoot الأساسي فقط: ${summary['commandsDetectedInBase'] ?? 0}؛ مفقودة: ${summary['commandsMissing'] ?? 0}؛ حزم معلّقة: ${summary['packagesPending'] ?? 0}؛ مفاتيح إعداد مفقودة: ${summary['credentialsMissing'] ?? 0}؛ ملفات تشغيل مطلوبة: ${summary['runtimeProfilesRequired'] ?? 0}؛ موائمات مطلوبة: ${summary['adaptersRequired'] ?? 0}؛ قدرات غير مصنفة: ${summary['unknownCapabilities'] ?? 0}.'
          : '- Commands verified in the Skill Runtime Profile: ${summary['commandsVerified'] ?? 0}; detected in base PRoot only: ${summary['commandsDetectedInBase'] ?? 0}; missing: ${summary['commandsMissing'] ?? 0}; packages pending: ${summary['packagesPending'] ?? 0}; credentials missing: ${summary['credentialsMissing'] ?? 0}; runtime profiles required: ${summary['runtimeProfilesRequired'] ?? 0}; adapters required: ${summary['adaptersRequired'] ?? 0}; unknown capabilities: ${summary['unknownCapabilities'] ?? 0}.');
    }
    final toolchains = (report['toolchains'] as List? ?? const []).whereType<Map>().toList();
    if (toolchains.isNotEmpty) {
      out.writeln(arabic ? '\n**بيئات التشغيل المطلوبة**' : '\n**Required runtimes**');
      for (final item in toolchains) {
        final command = item['command']?.toString() ?? '';
        final matching = (report['commands'] as List? ?? const []).whereType<Map>().where((entry) => entry['name'] == command).toList();
        final actual = matching.isEmpty ? null : matching.first;
        out.writeln(arabic
            ? '- ${item['name']} (`$command`): ${statusLabel(actual?['status'] ?? item['status'])} — الدليل: ${(item['evidence'] as List? ?? const []).join(', ')}'
            : '- ${item['name']} (`$command`): ${actual?['status'] ?? item['status'] ?? 'not checked'} — evidence: ${(item['evidence'] as List? ?? const []).join(', ')}');
      }
    }
    final commands = (report['commands'] as List? ?? const []).whereType<Map>().toList();
    if (commands.isNotEmpty) {
      out.writeln(arabic ? '\n**أدوات سطر الأوامر المطلوبة**' : '\n**Required CLI tools**');
      for (final item in commands) {
        final baseOnly = item['verifiedIn'] == 'base_proot_environment';
        out.writeln(arabic
            ? '- `${item['name']}`: ${statusLabel(item['status'])}${baseOnly ? ' (تم التحقق في PRoot الأساسي فقط)' : ''} — ${(item['evidence'] as List? ?? const []).join(', ')}'
            : '- `${item['name']}`: ${item['status'] ?? 'not checked'}${baseOnly ? ' (verified only in base PRoot)' : ''} — ${(item['evidence'] as List? ?? const []).join(', ')}');
      }
    }
    final packages = (report['packages'] as List? ?? const []).whereType<Map>().toList();
    if (packages.isNotEmpty) {
      out.writeln(arabic ? '\n**الحزم والمكتبات**' : '\n**Packages and libraries**');
      for (final item in packages) {
        out.writeln(arabic
            ? '- `${item['declaration']}` (${item['ecosystem']}، ${item['manifestPath']}): مدير الحزم/الدعم ${managerLabel(item['environmentSupport'] ?? item['manager'] ?? 'غير معروف')}؛ الحالة ${statusLabel(item['status'])}. لم يتم التثبيت أو التحقق داخل ملف تشغيل المهارة.'
            : '- `${item['declaration']}` (${item['ecosystem']}, ${item['manifestPath']}): ${item['environmentSupport'] ?? item['manager'] ?? 'manager unknown'}; ${item['status'] ?? 'not checked'}. No installation or profile-level validation was performed.');
      }
    }
    final credentials = (report['credentials'] as List? ?? const []).whereType<Map>().toList();
    if (credentials.isNotEmpty) {
      out.writeln(arabic ? '\n**مفاتيح API ومتغيرات البيئة**' : '\n**API keys / environment variables**');
      for (final item in credentials) {
        out.writeln(arabic
            ? '- `${item['name']}` — ${statusLabel(item['status'])}؛ يجب ضبطه بشكل آمن. يفهرس KELIVO اسم المتغير فقط؛ ولا يستخرج قيمة السر أو يحفظها أو يعرضها أو يسجلها أو يتحقق من صلاحيتها.'
            : '- `${item['name']}` — ${item['status'] ?? 'not checked'}; configure securely; Kelivo inventories the variable name only; it does not extract, persist, return, log, or validate secret values.');
      }
    }
    final services = (report['externalServices'] as List? ?? const []).whereType<Map>().toList();
    if (services.isNotEmpty) {
      out.writeln(arabic ? '\n**الخدمات الخارجية**' : '\n**External services**');
      for (final item in services) {
        out.writeln(arabic
            ? '- ${item['name']}: ${statusLabel(item['status'])}؛ لم يتم الاتصال بالخدمة؛ الدليل: ${(item['evidence'] as List? ?? const []).join(', ')}.'
            : '- ${item['name']}: ${item['status']} — ${item['verification'] ?? 'not verified'}; detected in ${(item['evidence'] as List? ?? const []).join(', ')}.');
      }
    }
    final capabilities = (report['capabilities'] as List? ?? const []).whereType<Map>().toList();
    if (capabilities.isNotEmpty) {
      out.writeln(arabic ? '\n**التوافق مع KELIVO**' : '\n**Kelivo compatibility**');
      const kindLabelsAr = <String, String>{
        'instruction_only': 'تعليمات نصية',
        'local_script': 'سكريبت محلي',
        'cli_binary': 'ملف تنفيذي / أداة CLI',
        'mcp_server': 'خادم MCP',
        'http_api_connector': 'موصل HTTP / API',
        'native_kelivo_tool': 'أداة أصلية داخل KELIVO',
        'workflow': 'سير عمل',
      };
      const supportLabelsAr = <String, String>{
        'supported': 'مدعوم كتعليمات',
        'conditional': 'مدعوم بشروط وملف تشغيل معزول',
        'environment_work_required': 'يتطلب تجهيز البيئة وموائماً تنفيذياً',
        'manual_adapter_required': 'يتطلب إعداد MCP وموائماً يدوياً',
        'adapter_required': 'يتطلب موائماً',
        'requires_kelivo_development': 'يتطلب تطوير KELIVO',
        'unknown': 'توافق غير مصنف',
      };
      const detailLabelsAr = <String, String>{
        'instruction_only': 'يمكن قراءة التعليمات واتباعها بواسطة المساعد؛ لا يؤدي ذلك إلى تثبيت أدوات أو تشغيل سكريبتات.',
        'local_script': 'يدعم منفذ المهارات نقاط الدخول Python وBash وNode بشروط؛ يلزم ملف تشغيل معزول خاص بالمهارة وموافقة لكل تنفيذ، ولم يثبت ذلك بعد.',
        'cli_binary': 'تم حفظ الملفات التنفيذية فقط؛ يجب التحقق من المعمارية والاعتماديات وتجهيز أداة متوافقة داخل PRoot وإضافة موائم معتمد قبل التشغيل. لم يتم تشغيل الملف.',
        'mcp_server': 'تم اكتشاف إعداد MCP وحفظه، لكن الاستيراد لا يسجل الخادم ولا يشغله. يلزم إعداد الموائم والنقل والصلاحيات ومراجعتها يدوياً.',
        'http_api_connector': 'تم حفظ وصف API/OpenAPI؛ لا يوجد تفعيل تلقائي لموصل تابع للمهارة. يلزم مراجعة المضيف والمصادقة والعمليات وبناء أو تفعيل موائم مناسب. لم يتم الاتصال بالخدمة.',
        'native_kelivo_tool': 'لا تستطيع حزمة المهارة إضافة Dart تنفيذي إلى KELIVO؛ يلزم تطوير موائم أصلي ومراجعته وتسجيل الأداة داخل التطبيق.',
        'workflow': 'تم حفظ تعريف سير العمل؛ يلزم محرك سير عمل وموائم متوافق قبل تنفيذه.',
      };

      for (final item in capabilities) {
        final kind = item['kind']?.toString() ?? 'unknown';
        final support = item['support']?.toString() ?? 'unknown';
        out.writeln(arabic
            ? '- ${kindLabelsAr[kind] ?? kind}: ${supportLabelsAr[support] ?? support} — ${detailLabelsAr[kind] ?? item['detail']}'
            : '- `$kind`: $support — ${item['detail']}');
      }
    }
    final notes = (report['notes'] as List? ?? const []).whereType<String>();
    if (notes.isNotEmpty) {
      out.writeln(arabic ? '\n**ملاحظات**' : '\n**Notes**');
      for (final note in notes) out.writeln('- $note');
    }
    out.writeln(arabic
        ? '\nهذا تقرير اكتشاف للقراءة فقط. لم يتم تثبيت أي حزمة، أو تشغيل أي سكريبت أو خادم MCP، أو الاتصال بأي API خارجي. وجود الأمر في PRoot الأساسي لا يثبت توفره داخل ملف تشغيل المهارة. تبقى الحزم والموائمات معلّقة حتى تطوير بيئة التشغيل المخصصة والتحقق منها بموافقة صريحة.'
        : '\nThis is a read-only requirement report. No package was installed, no Skill script or MCP server was executed, and no external API was called. A command verified in the base PRoot does not prove that it is available in the Skill-owned Runtime Profile. Package dependencies and adapter capabilities remain pending until their dedicated Kelivo runtime/profile is implemented and explicitly approved.');
    return out.toString();
  }

}
