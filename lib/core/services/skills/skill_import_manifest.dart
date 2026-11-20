import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'skill_compatibility.dart';
import 'skill_requirements.dart';

/// The capability kinds Kelivo can discover during import. Discovery is
/// descriptive only: no capability in this model is executable in Phase 13A.
enum SkillCapabilityKind {
  instructionOnly,
  localScript,
  cliBinary,
  mcpServer,
  httpApiConnector,
  nativeKelivoTool,
  workflow,
}

extension SkillCapabilityKindWire on SkillCapabilityKind {
  String get wireValue => switch (this) {
    SkillCapabilityKind.instructionOnly => 'instruction_only',
    SkillCapabilityKind.localScript => 'local_script',
    SkillCapabilityKind.cliBinary => 'cli_binary',
    SkillCapabilityKind.mcpServer => 'mcp_server',
    SkillCapabilityKind.httpApiConnector => 'http_api_connector',
    SkillCapabilityKind.nativeKelivoTool => 'native_kelivo_tool',
    SkillCapabilityKind.workflow => 'workflow',
  };

  static SkillCapabilityKind? parse(String? value) {
    for (final kind in SkillCapabilityKind.values) {
      if (kind.wireValue == value) return kind;
    }
    return null;
  }
}

final class SkillCapabilityDescriptor {
  const SkillCapabilityDescriptor({
    required this.kind,
    required this.id,
    this.entryPoints = const <String>[],
    this.evidence = const <String>[],
    this.transport,
    this.declared = false,
    this.executionEnabled = false,
  });

  final SkillCapabilityKind kind;
  final String id;
  final List<String> entryPoints;
  final List<String> evidence;
  final String? transport;
  final bool declared;

  /// Always false in Phase 13A. A later executor must make its own decision.
  final bool executionEnabled;

  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind.wireValue,
    'id': id,
    'entryPoints': entryPoints,
    'evidence': evidence,
    if (transport != null) 'transport': transport,
    'declared': declared,
    'executionEnabled': false,
  };
}

final class SkillImportFileEntry {
  const SkillImportFileEntry({
    required this.path,
    required this.sizeBytes,
    required this.mediaType,
    required this.sha256,
    required this.scope,
    this.executable,
    this.executableSource,
    this.sourcePath,
  });

  final String path;
  final int sizeBytes;
  final String mediaType;
  final String sha256;
  final String scope;
  final bool? executable;
  final String? executableSource;
  final String? sourcePath;

  Map<String, Object?> toJson() => <String, Object?>{
    'path': path,
    'sizeBytes': sizeBytes,
    'mediaType': mediaType,
    'sha256': sha256,
    'scope': scope,
    if (executable != null) 'executable': executable,
    if (executableSource != null) 'executableSource': executableSource,
    if (sourcePath != null) 'sourcePath': sourcePath,
  };
}

final class SkillImportSkippedEntry {
  const SkillImportSkippedEntry({
    required this.path,
    required this.reason,
    this.scope = 'skill',
  });

  final String path;
  final String reason;
  final String scope;

  Map<String, Object?> toJson() => <String, Object?>{
    'path': path,
    'reason': reason,
    'scope': scope,
  };
}

final class SkillDependencyDeclaration {
  const SkillDependencyDeclaration({
    required this.manifestPath,
    required this.ecosystem,
    this.dependencies = const <String>[],
    this.lockfile = false,
    this.lifecycleScriptNames = const <String>[],
    this.warnings = const <String>[],
  });

  final String manifestPath;
  final String ecosystem;
  final List<String> dependencies;
  final bool lockfile;
  final List<String> lifecycleScriptNames;
  final List<String> warnings;

  Map<String, Object?> toJson() => <String, Object?>{
    'manifestPath': manifestPath,
    'ecosystem': ecosystem,
    'dependencies': dependencies,
    'lockfile': lockfile,
    'lifecycleScriptNames': lifecycleScriptNames,
    'warnings': warnings,
    'installationPerformed': false,
    'lifecycleScriptsExecuted': false,
  };
}

final class SkillImportManifest {
  const SkillImportManifest({
    required this.skillId,
    required this.createdAt,
    required this.sourceType,
    required this.files,
    required this.capabilities,
    required this.dependencies,
    required this.skipped,
    required this.sourceDigest,
    this.sourceUrl,
    this.repository,
    this.ref,
    this.commit,
    this.sharedResourceSetId,
    this.sharedResourcePaths = const <String>[],
    this.completeness = 'complete',
    this.completenessNotes = const <String>[],
    this.requirements = const <String, Object?>{},
  });

  static const int currentSchemaVersion = 1;

  final String skillId;
  final DateTime createdAt;
  final String sourceType;
  final String? sourceUrl;
  final String? repository;
  final String? ref;
  final String? commit;
  final List<SkillImportFileEntry> files;
  final List<SkillCapabilityDescriptor> capabilities;
  final List<SkillDependencyDeclaration> dependencies;
  final List<SkillImportSkippedEntry> skipped;
  final String sourceDigest;
  final String? sharedResourceSetId;
  final List<String> sharedResourcePaths;
  final String completeness;
  final List<String> completenessNotes;
  /// Static, read-only inventory of runtime/tool/package/API requirements.
  /// Live availability is checked separately and is never assumed at import.
  final Map<String, Object?> requirements;

  int get totalBytes => files.fold<int>(0, (sum, file) => sum + file.sizeBytes);

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': currentSchemaVersion,
    'skillId': skillId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'source': <String, Object?>{
      'type': sourceType,
      if (sourceUrl != null) 'url': sourceUrl,
      if (repository != null) 'repository': repository,
      if (ref != null) 'ref': ref,
      if (commit != null) 'commit': commit,
    },
    'sourceDigest': sourceDigest,
    'requirementInventoryUpdatedAt': createdAt.toUtc().toIso8601String(),
    'requirementInventorySourceDigest': sourceDigest,
    'completeness': completeness,
    'completenessNotes': completenessNotes,
    'requirements': requirements,
    'files': files.map((entry) => entry.toJson()).toList(growable: false),
    'capabilities': capabilities
        .map((entry) => entry.toJson())
        .toList(growable: false),
    'dependencies': dependencies
        .map((entry) => entry.toJson())
        .toList(growable: false),
    'skipped': skipped.map((entry) => entry.toJson()).toList(growable: false),
    if (sharedResourceSetId != null)
      'sharedResources': <String, Object?>{
        'setId': sharedResourceSetId,
        'paths': sharedResourcePaths,
        'binding': 'read_only_reference',
        'runtimeAccessEnabled': false,
      },
  };

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}

/// Read-only import scanner. It reads every regular file as bytes, never
/// invokes a file, follows no symlink and never installs dependencies.
final class SkillImportAnalyzer {
  SkillImportAnalyzer._();

  static const int maxFiles = 8192;
  static const int maxTotalBytes = 500 * 1024 * 1024;
  static const int maxFileBytes = 200 * 1024 * 1024;
  static const Set<String> _scriptExtensions = <String>{
    '.py', '.sh', '.bash', '.js', '.mjs', '.cjs', '.ts', '.rb', '.pl',
    '.ps1', '.bat', '.cmd', '.php', '.lua', '.r',
  };
  static const Set<String> _lockfileNames = <String>{
    'package-lock.json', 'npm-shrinkwrap.json', 'pnpm-lock.yaml',
    'yarn.lock', 'bun.lockb', 'uv.lock', 'poetry.lock', 'pipfile.lock',
    'cargo.lock', 'composer.lock', 'gemfile.lock',
  };
  static const Set<String> _lifecycleNames = <String>{
    'preinstall', 'install', 'postinstall', 'prepare', 'prepublish',
    'prepublishonly', 'postpublish', 'prepack', 'postpack',
  };

  static Future<SkillImportManifest> analyzeDirectory({
    required String skillId,
    required Directory directory,
    required String sourceType,
    Directory? sharedDirectory,
    String? sourceUrl,
    String? repository,
    String? ref,
    String? commit,
    String? sharedResourceSetId,
    List<String> sharedResourcePaths = const <String>[],
    List<SkillImportSkippedEntry> skipped = const <SkillImportSkippedEntry>[],
    Map<String, bool?> executableOverrides = const <String, bool?>{},
    Map<String, bool?> sharedExecutableOverrides = const <String, bool?>{},
    String completeness = 'complete',
    List<String> completenessNotes = const <String>[],
    DateTime? now,
  }) async {
    if (!await directory.exists()) {
      throw FileSystemException('Skill directory does not exist', directory.path);
    }
    final canonicalRoot = await directory.resolveSymbolicLinks();
    final allSkipped = <SkillImportSkippedEntry>[...skipped];
    final files = <SkillImportFileEntry>[];
    final dependencyFiles = <({String path, List<int> bytes})>[];
    String? skillMarkdown;
    final inspectedTextFiles = <String, String>{};
    final requirementScanNotes = <String>[];
    final skillFilePaths = <String>{};
    var totalBytes = 0;
    var count = 0;
    await for (final entity in directory.list(recursive: true, followLinks: false)) {
      final relative = p.relative(entity.path, from: directory.path)
          .replaceAll('\\', '/');
      final normalized = _safeRelativePath(relative);
      if (normalized == null) {
        throw const FormatException('unsafe_skill_manifest_path');
      }
      if (entity is Link) {
        allSkipped.add(SkillImportSkippedEntry(
          path: normalized,
          reason: 'symbolic_link_not_followed',
        ));
        continue;
      }
      if (entity is! File) continue;
      final resolved = await entity.resolveSymbolicLinks();
      if (!p.isWithin(canonicalRoot, resolved)) {
        throw const FormatException('skill_manifest_path_escape');
      }
      count++;
      if (count > maxFiles) {
        throw const FormatException('skill_manifest_file_limit');
      }
      final stat = await entity.stat();
      if (stat.size > maxFileBytes) {
        throw FormatException('skill_manifest_file_too_large:$normalized');
      }
      totalBytes += stat.size;
      if (totalBytes > maxTotalBytes) {
        throw const FormatException('skill_manifest_total_size_limit');
      }
      final digest = await _sha256File(entity);
      final hasExecutableOverride = executableOverrides.containsKey(normalized);
      final executableOverride = executableOverrides[normalized];
      final executable = hasExecutableOverride
          ? executableOverride : _executableFromMode(stat.mode);
      skillFilePaths.add(normalized);
      if (normalized == 'SKILL.md') {
        if (stat.size <= 2 * 1024 * 1024) {
          skillMarkdown = await entity.readAsString();
          inspectedTextFiles[normalized] = skillMarkdown;
        } else {
          requirementScanNotes.add(
            'Requirement discovery skipped SKILL.md because it exceeds the 2 MiB frontmatter/instruction inspection limit; inspect it manually.',
          );
        }
      }
      final extension = p.extension(normalized).toLowerCase();
      final basename = p.posix.basename(normalized);
      final isInspectableRequirementFile = normalized != 'SKILL.md' &&
          (_scriptExtensions.contains(extension) ||
          const {'.md', '.markdown', '.txt', '.json', '.yaml', '.yml', '.toml', '.ini', '.cfg', '.conf', '.properties', '.xml', '.lock'}
              .contains(extension) ||
          const {
            'mcp.json', '.mcp.json', 'mcp-server.json', 'kelivo.skill.json',
            'openapi.yaml', 'openapi.yml', 'openapi.json', 'swagger.json',
            'kelivo.connector.yaml', 'kelivo.connector.yml', '.env.example',
            '.env.sample', '.env.template', '.tool-versions', 'dockerfile',
            'compose.yaml', 'compose.yml', 'docker-compose.yaml', 'docker-compose.yml',
          }.contains(basename));
      if (isInspectableRequirementFile && stat.size <= 256 * 1024) {
        try {
          inspectedTextFiles[normalized] = await entity.readAsString();
        } on FormatException {
          requirementScanNotes.add(
            'Requirement discovery skipped non-UTF8 or binary text candidate: $normalized; the file remains preserved in the Skill import.',
          );
        }
      } else if (isInspectableRequirementFile && stat.size > 256 * 1024) {
        requirementScanNotes.add(
          'Requirement discovery skipped $normalized because it exceeds the 256 KiB per-file inspection limit; its presence is indexed but its contents were not scanned.',
        );
      }
      files.add(SkillImportFileEntry(
        path: normalized,
        sizeBytes: stat.size,
        mediaType: await _detectMediaType(entity, normalized),
        sha256: digest,
        scope: 'skill',
        executable: executable,
        executableSource: hasExecutableOverride
            ? (executableOverride == null ? 'source_archive_mode_unavailable' : 'source_archive_unix_mode')
            : (Platform.isWindows ? null : 'local_file_mode'),
      ));
      if (_isDependencyManifest(normalized)) {
        // Read only recognized, bounded text metadata. Binary lockfiles are
        // recorded in the file manifest but not decoded as text.
        if (stat.size <= 2 * 1024 * 1024) {
          dependencyFiles.add((path: normalized, bytes: await entity.readAsBytes()));
        } else {
          allSkipped.add(SkillImportSkippedEntry(
            path: normalized,
            reason: 'dependency_manifest_not_parsed_over_2_mib',
          ));
        }
      }
    }
    if (sharedDirectory != null && await sharedDirectory.exists()) {
      final sharedCanonicalRoot = await sharedDirectory.resolveSymbolicLinks();
      await for (final entity in sharedDirectory.list(
        recursive: true,
        followLinks: false,
      )) {
        final relative = p.relative(entity.path, from: sharedDirectory.path)
            .replaceAll('\\', '/');
        final normalized = _safeRelativePath(relative);
        if (normalized == null) {
          throw const FormatException('unsafe_shared_manifest_path');
        }
        if (entity is Link) {
          allSkipped.add(SkillImportSkippedEntry(
            path: normalized,
            reason: 'shared_symbolic_link_not_followed',
            scope: 'shared',
          ));
          continue;
        }
        if (entity is! File) continue;
        final resolved = await entity.resolveSymbolicLinks();
        if (!p.isWithin(sharedCanonicalRoot, resolved)) {
          throw const FormatException('shared_manifest_path_escape');
        }
        count++;
        if (count > maxFiles) {
          throw const FormatException('skill_manifest_file_limit');
        }
        final stat = await entity.stat();
        if (stat.size > maxFileBytes) {
          throw FormatException('shared_manifest_file_too_large:$normalized');
        }
        totalBytes += stat.size;
        if (totalBytes > maxTotalBytes) {
          throw const FormatException('skill_manifest_total_size_limit');
        }
        final digest = await _sha256File(entity);
        final hasExecutableOverride = sharedExecutableOverrides.containsKey(normalized);
        final executableOverride = sharedExecutableOverrides[normalized];
        final executable = hasExecutableOverride
            ? executableOverride : _executableFromMode(stat.mode);
        files.add(SkillImportFileEntry(
          path: 'shared/$normalized',
          sizeBytes: stat.size,
          mediaType: await _detectMediaType(entity, normalized),
          sha256: digest,
          scope: 'shared',
          executable: executable,
          executableSource: hasExecutableOverride
              ? (executableOverride == null ? 'source_archive_mode_unavailable' : 'source_archive_unix_mode')
              : (Platform.isWindows ? null : 'local_file_mode'),
          sourcePath: normalized,
        ));
        if (_isDependencyManifest(normalized)) {
          if (stat.size <= 2 * 1024 * 1024) {
            dependencyFiles.add((path: 'shared/$normalized', bytes: await entity.readAsBytes()));
          } else {
            allSkipped.add(SkillImportSkippedEntry(
              path: 'shared/$normalized',
              reason: 'dependency_manifest_not_parsed_over_2_mib',
              scope: 'shared',
            ));
          }
        }
      }
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    final manifestNotes = <String>[...completenessNotes];
    if (skillMarkdown != null) {
      final missingReferences = findMissingSkillLocalReferences(
        skillMarkdown,
        skillFilePaths,
      );
      if (missingReferences.isNotEmpty) {
        manifestNotes.add(
          'Missing local Skill companion references: ${missingReferences.join(', ')}. '
          'The source archive did not contain these paths; import preserves every '
          'provided file but cannot reconstruct missing files.',
        );
      }
    } else if (skillFilePaths.contains('SKILL.md')) {
      manifestNotes.add(
        'SKILL.md exceeded the 2 MiB reference-scan limit; local companion '
        'references were not checked.',
      );
    }
    final capabilities = await _discoverCapabilities(directory, files, allSkipped);
    final dependencies = <SkillDependencyDeclaration>[];
    for (final dependencyFile in dependencyFiles) {
      dependencies.add(_parseDependencyFile(
        dependencyFile.path,
        utf8.decode(dependencyFile.bytes, allowMalformed: true),
      ));
    }
    dependencies.sort((a, b) => a.manifestPath.compareTo(b.manifestPath));
    final requirementReport = SkillRequirementsAnalyzer.analyze(
      skillId: skillId,
      skillMarkdown: skillMarkdown ?? '',
      files: files.map((entry) => entry.toJson()).toList(growable: false),
      capabilities: capabilities.map((entry) => entry.toJson()).toList(growable: false),
      dependencies: dependencies.map((entry) => entry.toJson()).toList(growable: false),
      inspectedTextFiles: inspectedTextFiles,
    );
    final requirementNotes = requirementReport['notes'] as List<String>;
    requirementNotes.addAll(requirementScanNotes);
    requirementReport['notes'] = requirementNotes.toSet().toList()..sort();
    final canonicalDigestInput = files
        .map((entry) => '${entry.path}\u0000${entry.sizeBytes}\u0000${entry.sha256}')
        .join('\n');
    final sourceDigest = 'sha256:${sha256.convert(utf8.encode(canonicalDigestInput))}';
    final effectiveCompleteness = manifestNotes.isNotEmpty
        ? 'partial'
        : completeness;
    return SkillImportManifest(
      skillId: skillId,
      createdAt: (now ?? DateTime.now()).toUtc(),
      sourceType: sourceType,
      sourceUrl: _safeSourceUrl(sourceUrl),
      repository: repository,
      ref: ref,
      commit: commit,
      files: List.unmodifiable(files),
      capabilities: List.unmodifiable(capabilities),
      dependencies: List.unmodifiable(dependencies),
      skipped: List.unmodifiable(allSkipped),
      sourceDigest: sourceDigest,
      sharedResourceSetId: sharedResourceSetId,
      sharedResourcePaths: List.unmodifiable(sharedResourcePaths),
      completeness: effectiveCompleteness,
      completenessNotes: List.unmodifiable(manifestNotes),
      requirements: Map.unmodifiable(requirementReport),
    );
  }

  static bool _isImplicitRunnableScript(String path) {
    final segments = p.posix.split(path.toLowerCase());
    const referenceOnlyDirectories = <String>{
      'example', 'examples', 'demo', 'demos', 'sample', 'samples',
      'fixture', 'fixtures', 'test', 'tests', 'assets', 'vendor',
    };
    if (segments.take(segments.length - 1).any(referenceOnlyDirectories.contains)) {
      return false;
    }
    return _scriptExtensions.contains(p.extension(path).toLowerCase());
  }

  static Future<List<SkillCapabilityDescriptor>> _discoverCapabilities(
    Directory directory,
    List<SkillImportFileEntry> files,
    List<SkillImportSkippedEntry> diagnostics,
  ) async {
    // Capability entry points must belong to the Skill itself. Shared
    // repository assets are separately indexed and are never implicit tools.
    final skillFiles = files.where((file) => file.scope == 'skill').toList();
    final paths = skillFiles.map((file) => file.path).toSet();
    final found = <String, SkillCapabilityDescriptor>{};
    void add(SkillCapabilityDescriptor descriptor) {
      found['${descriptor.kind.wireValue}:${descriptor.id}'] = descriptor;
    }

    final scripts = skillFiles
        .where((file) => _isImplicitRunnableScript(file.path))
        .map((file) => file.path)
        .toList(growable: false);
    if (scripts.isNotEmpty) {
      add(SkillCapabilityDescriptor(
        kind: SkillCapabilityKind.localScript,
        id: 'local-scripts',
        entryPoints: scripts,
        evidence: scripts,
      ));
    }
    final binaries = skillFiles
        .where((file) => file.mediaType == 'application/x-executable' ||
            (file.executable == true && !_scriptExtensions.contains(p.extension(file.path).toLowerCase())))
        .map((file) => file.path)
        .toList(growable: false);
    if (binaries.isNotEmpty) {
      add(SkillCapabilityDescriptor(
        kind: SkillCapabilityKind.cliBinary,
        id: 'cli-binaries',
        entryPoints: binaries,
        evidence: binaries,
      ));
    }

    final declaredFile = File(p.join(directory.path, 'kelivo.skill.json'));
    if (await declaredFile.exists() && paths.contains('kelivo.skill.json')) {
      if (await declaredFile.length() > 1024 * 1024) {
        throw const FormatException('kelivo_skill_descriptor_too_large');
      }
      final decoded = jsonDecode(await declaredFile.readAsString());
      if (decoded is! Map || decoded['schemaVersion'] != 1 || decoded['capabilities'] is! List) {
        throw const FormatException('invalid_kelivo_skill_descriptor');
      }
      for (final raw in (decoded['capabilities'] as List).whereType<Map>()) {
        final kind = SkillCapabilityKindWire.parse(raw['kind']?.toString());
        if (kind == null || kind == SkillCapabilityKind.instructionOnly) {
          throw const FormatException('unsupported_kelivo_skill_capability');
        }
        final entryPointsRaw = raw['entryPoints'];
        final entryPoints = <String>[];
        if (entryPointsRaw != null) {
          if (entryPointsRaw is! List || entryPointsRaw.any((item) => item is! String)) {
            throw const FormatException('invalid_kelivo_skill_entry_points');
          }
          for (final item in entryPointsRaw.cast<String>()) {
            final safe = _safeRelativePath(item);
            if (safe == null || !paths.contains(safe)) {
              throw FormatException('missing_or_unsafe_skill_entry_point:$item');
            }
            entryPoints.add(safe);
          }
        }
        final transport = raw['transport']?.toString();
        if (kind == SkillCapabilityKind.mcpServer &&
            (!const {'stdio', 'http', 'sse'}.contains(transport) ||
                entryPoints.isEmpty)) {
          throw const FormatException('mcp_transport_and_server_entry_point_required');
        }
        if (kind == SkillCapabilityKind.nativeKelivoTool && entryPoints.isEmpty) {
          throw const FormatException('native_tool_entry_point_required');
        }
        final id = raw['id']?.toString() ?? kind.wireValue;
        if (!RegExp(r'^[a-z0-9][a-z0-9._-]{0,79}$').hasMatch(id)) {
          throw const FormatException('invalid_kelivo_skill_capability_id');
        }
        add(SkillCapabilityDescriptor(
          kind: kind,
          id: id,
          entryPoints: List.unmodifiable(entryPoints),
          evidence: const <String>['kelivo.skill.json'],
          transport: transport,
          declared: true,
        ));
      }
    }

    // MCP is discovered only from an explicit transport/server definition.
    // A folder named tools/ is deliberately not considered an MCP server.
    final mcpConfigPaths = paths.where((path) =>
        const {'mcp.json', '.mcp.json', 'mcp-server.json'}
            .contains(p.posix.basename(path)));
    for (final configPath in mcpConfigPaths) {
      final configFile = File(p.join(directory.path, configPath));
      if (await configFile.length() > 1024 * 1024) {
        diagnostics.add(SkillImportSkippedEntry(
          path: configPath,
          reason: 'mcp_descriptor_not_inspected_over_1_mib',
        ));
        continue;
      }
      Object? decoded;
      try {
        decoded = jsonDecode(await configFile.readAsString());
      } on FormatException {
        // A filename alone is not proof that the file configures MCP. Keep
        // the asset, report the detection limitation, and do not reject the
        // enclosing Skill or classify it as an MCP server.
        diagnostics.add(SkillImportSkippedEntry(
          path: configPath,
          reason: 'invalid_mcp_config_not_classified',
        ));
        continue;
      }
      // jsonDecode returns Object? on current Dart SDKs. Keep the checked
      // Map promotion explicit before indexing transport/command/url fields.
      final decodedMap = decoded is Map ? decoded : null;
      final servers = decodedMap?['mcpServers'];
      final hasNamedServer = servers is Map && servers.values.any((server) =>
          server is Map && (server['command'] != null || server['url'] != null));
      final hasTransportAndEndpoint = decodedMap != null &&
          const {'stdio', 'http', 'sse'}.contains(decodedMap['transport']) &&
          (decodedMap['command'] != null || decodedMap['url'] != null);
      if (hasNamedServer || hasTransportAndEndpoint) {
        add(SkillCapabilityDescriptor(
          kind: SkillCapabilityKind.mcpServer,
          id: 'mcp-server-config',
          entryPoints: <String>[configPath],
          evidence: <String>[configPath],
          transport: decodedMap?['transport']?.toString() ?? 'declared_in_config',
          declared: true,
        ));
      }
    }
    for (final connectorPath in paths.where((path) => const {
      'openapi.yaml', 'openapi.yml', 'openapi.json', 'swagger.json',
      'kelivo.connector.yaml', 'kelivo.connector.yml',
    }.contains(p.posix.basename(path)))) {
        add(SkillCapabilityDescriptor(
          kind: SkillCapabilityKind.httpApiConnector,
          id: 'http-api-connector',
          entryPoints: <String>[connectorPath],
          evidence: <String>[connectorPath],
          declared: connectorPath.startsWith('kelivo.'),
        ));
    }
    for (final workflowPath in paths.where((path) => const {
      'kelivo.workflow.yaml', 'kelivo.workflow.yml', 'kelivo.workflow.json',
      'workflow.yaml', 'workflow.yml', 'workflow.json',
    }.contains(p.posix.basename(path)))) {
        add(SkillCapabilityDescriptor(
          kind: SkillCapabilityKind.workflow,
          id: 'workflow-definition',
          entryPoints: <String>[workflowPath],
          evidence: <String>[workflowPath],
          declared: workflowPath.startsWith('kelivo.'),
        ));
    }
    if (found.isEmpty && paths.contains('SKILL.md')) {
      add(const SkillCapabilityDescriptor(
        kind: SkillCapabilityKind.instructionOnly,
        id: 'instructions',
        entryPoints: <String>['SKILL.md'],
        evidence: <String>['SKILL.md'],
      ));
    }
    final result = found.values.toList()
      ..sort((a, b) => a.kind.index.compareTo(b.kind.index));
    return result;
  }

  static SkillDependencyDeclaration _parseDependencyFile(String path, String text) {
    final lower = p.basename(path).toLowerCase();
    final extension = p.extension(lower);
    final isLock = _lockfileNames.contains(lower);
    final dependencies = <String>{};
    final lifecycle = <String>{};
    final warnings = <String>[];
    var ecosystem = 'unknown';
    if (lower == 'requirements.txt' || lower == 'dev-requirements.txt' ||
        lower.startsWith('requirements-') && lower.endsWith('.txt') ||
        lower.endsWith('-requirements.txt')) {
      ecosystem = 'python';
      for (final rawLine in const LineSplitter().convert(text)) {
        final line = rawLine.split('#').first.trim();
        if (line.isEmpty) continue;
        if (line.startsWith('-')) {
          warnings.add('pip_option_or_nested_requirements_not_resolved');
          continue;
        }
        final match = RegExp(r'^([A-Za-z0-9_.-]+)\s*(?:\[[^\]]+\])?\s*(.*)$').firstMatch(line);
        if (match != null) {
          final packageName = match.group(1)!;
          final constraint = match.group(2)?.trim();
          dependencies.add(
            constraint == null || constraint.isEmpty
                ? packageName
                : '$packageName $constraint',
          );
        } else {
          warnings.add('unparsed_requirement_line');
        }
      }
    } else if (lower == 'pyproject.toml' || lower == 'poetry.lock' || lower == 'uv.lock') {
      ecosystem = 'python';
      final packageNames = RegExp(r'''^\s*name\s*=\s*["']([^"']+)["']''', multiLine: true);
      for (final match in packageNames.allMatches(text)) {
        dependencies.add(match.group(1)!);
      }
      if (lower == 'pyproject.toml') {
        final dependencyLines = RegExp(r'''^\s*([A-Za-z0-9_.-]+)\s*=\s*["']([^"']+)["']''', multiLine: true);
        for (final match in dependencyLines.allMatches(text)) {
          if (match.group(1) != 'python') dependencies.add('${match.group(1)} ${match.group(2)}');
        }
      }
    } else if (lower == 'pipfile') {
      ecosystem = 'python';
      var inDependencySection = false;
      for (final rawLine in const LineSplitter().convert(text)) {
        final line = rawLine.trim();
        if (line.startsWith('[') && line.endsWith(']')) {
          inDependencySection = const {'[packages]', '[dev-packages]'}.contains(line);
          continue;
        }
        if (!inDependencySection || line.isEmpty || line.startsWith('#')) continue;
        final match = RegExp(r'''^([A-Za-z0-9_.-]+)\s*=\s*(.+)$''').firstMatch(line);
        if (match != null) {
          dependencies.add('${match.group(1)} ${match.group(2)}');
        } else {
          warnings.add('unparsed_pipfile_dependency');
        }
      }
    } else if (lower == 'pipfile.lock') {
      ecosystem = 'python';
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map) {
          for (final field in const ['default', 'develop']) {
            final group = decoded[field];
            if (group is Map) {
              for (final entry in group.entries) {
                dependencies.add('${entry.key} ${entry.value}');
              }
            }
          }
        }
      } catch (_) {
        warnings.add('invalid_pipfile_lock_json');
      }
    } else if (lower == 'package.json' || lower == 'package-lock.json' || lower == 'npm-shrinkwrap.json') {
      ecosystem = 'node';
      try {
        final json = jsonDecode(text);
        if (json is Map) {
          for (final field in const ['dependencies', 'devDependencies', 'optionalDependencies', 'peerDependencies']) {
            final group = json[field];
            if (group is Map) {
              for (final entry in group.entries) {
                dependencies.add('${entry.key} ${entry.value}');
              }
            }
          }
          final scripts = json['scripts'];
          if (scripts is Map) {
            for (final entry in scripts.entries) {
              if (_lifecycleNames.contains(entry.key.toString())) lifecycle.add(entry.key.toString());
            }
          }
          final packages = json['packages'];
          if (packages is Map) {
            for (final entry in packages.entries) {
              final value = entry.value;
              if (value is Map && value['name'] is String) {
                dependencies.add(value['name'].toString());
              }
            }
          }
        }
      } catch (_) {
        warnings.add('invalid_json_dependency_manifest');
      }
    } else if (lower == 'pnpm-lock.yaml' || lower == 'yarn.lock' || lower == 'bun.lockb') {
      ecosystem = 'node';
      if (lower != 'bun.lockb') {
        for (final match in RegExp(r'''^\s{0,4}([@A-Za-z0-9_.-]+)@([^:\s]+):?\s*$''', multiLine: true).allMatches(text)) {
          dependencies.add('${match.group(1)} ${match.group(2)}');
        }
      } else {
        warnings.add('binary_lockfile_indexed_but_not_parsed');
      }
    } else if (lower == 'cargo.toml') {
      ecosystem = 'rust';
      for (final match in RegExp(r'''^\s*([A-Za-z0-9_-]+)\s*=\s*"([^"]+)"''', multiLine: true).allMatches(text)) {
        dependencies.add('${match.group(1)} ${match.group(2)}');
      }
    } else if (lower == 'go.mod') {
      ecosystem = 'go';
      for (final match in RegExp(r'''^\s*([A-Za-z0-9_./-]+)\s+(v[0-9][^\s]+)''', multiLine: true).allMatches(text)) {
        dependencies.add('${match.group(1)} ${match.group(2)}');
      }
    } else if (lower == 'gemfile') {
      ecosystem = 'ruby';
      for (final match in RegExp(r'''^\s*gem\s+["']([^"']+)["'](?:,\s*["']([^"']+)["'])?''', multiLine: true).allMatches(text)) {
        dependencies.add('${match.group(1)}${match.group(2) == null ? '' : ' ${match.group(2)}'}');
      }
    } else if (lower == 'gemfile.lock') {
      ecosystem = 'ruby';
      var inSpecs = false;
      for (final rawLine in const LineSplitter().convert(text)) {
        final line = rawLine.trimRight();
        if (line.trim() == 'specs:') {
          inSpecs = true;
          continue;
        }
        if (inSpecs && line.isNotEmpty && !line.startsWith('  ') && !line.startsWith('    ')) {
          inSpecs = false;
        }
        if (inSpecs) {
          final match = RegExp(r'^\s{4}([A-Za-z0-9_.-]+) \(([^)]+)\)').firstMatch(line);
          if (match != null) dependencies.add('${match.group(1)} ${match.group(2)}');
        }
      }
      if (dependencies.isEmpty) warnings.add('gemfile_lock_specs_not_parsed');
    } else if (lower == 'cargo.lock') {
      ecosystem = 'rust';
      for (final match in RegExp(r'''^name\s*=\s*["']([^"']+)["']''', multiLine: true).allMatches(text)) {
        dependencies.add(match.group(1)!);
      }
    } else if (lower == 'composer.lock') {
      ecosystem = 'php';
      try {
        final json = jsonDecode(text);
        if (json is Map) {
          for (final field in const ['packages', 'packages-dev']) {
            final packages = json[field];
            if (packages is List) {
              for (final package in packages.whereType<Map>()) {
                if (package['name'] is String) dependencies.add(package['name'].toString());
              }
            }
          }
        }
      } catch (_) {
        warnings.add('invalid_json_lockfile');
      }
    } else {
      ecosystem = extension == '.toml' ? 'python-or-tooling' : 'unknown';
    }
    return SkillDependencyDeclaration(
      manifestPath: path,
      ecosystem: ecosystem,
      dependencies: dependencies.toList()..sort(),
      lockfile: isLock,
      lifecycleScriptNames: lifecycle.toList()..sort(),
      warnings: warnings.toList()..sort(),
    );
  }

  static Future<String> _sha256File(File file) async {
    // Hash.bind streams file chunks directly and avoids buffering an entire
    // potentially large imported asset in memory.
    final digest = await sha256.bind(file.openRead()).first;
    return 'sha256:$digest';
  }

  static Future<String> _detectMediaType(File file, String path) async {
    final extension = p.extension(path).toLowerCase();
    final bytes = await file.openRead(0, 16).fold<List<int>>(<int>[], (all, chunk) => all..addAll(chunk));
    bool starts(List<int> signature) => bytes.length >= signature.length &&
        List<int>.generate(signature.length, (index) => bytes[index]).join(',') == signature.join(',');
    if (starts(<int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) return 'image/png';
    if (starts(<int>[0xff, 0xd8, 0xff])) return 'image/jpeg';
    if (starts(<int>[0x47, 0x49, 0x46, 0x38])) return 'image/gif';
    if (bytes.length >= 12 && String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' && String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') return 'image/webp';
    if (starts(<int>[0x25, 0x50, 0x44, 0x46])) return 'application/pdf';
    if (starts(<int>[0x7f, 0x45, 0x4c, 0x46])) return 'application/x-executable';
    if (starts(<int>[0x4d, 0x5a])) return 'application/x-dosexec';
    if (starts(<int>[0x00, 0x61, 0x73, 0x6d])) return 'application/wasm';
    if (starts(<int>[0x50, 0x4b, 0x03, 0x04])) return 'application/zip';
    final byExtension = _mimeByExtension[extension];
    if (byExtension != null) return byExtension;
    // Unknown extensions are binary by default. Guessing text from a short
    // prefix can mislabel compressed or encrypted assets as plain text.
    return 'application/octet-stream';
  }

  static const Map<String, String> _mimeByExtension = <String, String>{
    '.md': 'text/markdown', '.txt': 'text/plain', '.py': 'text/x-python',
    '.sh': 'text/x-shellscript', '.bash': 'text/x-shellscript',
    '.js': 'text/javascript', '.mjs': 'text/javascript', '.cjs': 'text/javascript',
    '.ts': 'text/typescript', '.json': 'application/json', '.yaml': 'application/yaml',
    '.yml': 'application/yaml', '.toml': 'application/toml', '.xml': 'application/xml',
    '.html': 'text/html', '.css': 'text/css', '.svg': 'image/svg+xml',
    '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png',
    '.gif': 'image/gif', '.webp': 'image/webp', '.ico': 'image/x-icon',
    '.pdf': 'application/pdf', '.wasm': 'application/wasm', '.zip': 'application/zip',
    '.lock': 'text/plain', '.yarn': 'text/plain', '.csv': 'text/csv',
  };

  static bool _isDependencyManifest(String path) {
    final name = p.basename(path).toLowerCase();
    return name == 'requirements.txt' ||
        name.startsWith('requirements-') && name.endsWith('.txt') ||
        name.endsWith('-requirements.txt') || name == 'pyproject.toml' || name == 'pipfile' || name == 'gemfile' ||
        name == 'go.mod' || name == 'cargo.toml' || name == 'package.json' ||
        _lockfileNames.contains(name) || name == 'cargo.lock' ||
        name == 'composer.lock';
  }

  static bool? _executableFromMode(int mode) {
    if (Platform.isWindows) return null;
    return (mode & 0x49) != 0;
  }

  static String? _safeRelativePath(String value) {
    final path = value.replaceAll('\\', '/');
    if (path.isEmpty || path.startsWith('/') || path.contains('\u0000') ||
        RegExp(r'^[A-Za-z]:').hasMatch(path) ||
        path.split('/').any((part) => part.isEmpty || part == '.' || part == '..')) {
      return null;
    }
    return p.posix.normalize(path);
  }

  static String? _safeSourceUrl(String? raw) {
    if (raw == null) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty ||
        uri.userInfo.isNotEmpty || uri.queryParameters.keys.any((key) =>
          RegExp(r'token|key|secret|password|auth|credential', caseSensitive: false).hasMatch(key))) {
      return null;
    }
    return uri.toString();
  }
}
