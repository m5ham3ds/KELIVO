import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../providers/environment_provider.dart';
import '../packages/package_manager_service.dart';
import '../workspace/workspace_runtime.dart';

abstract final class EnvironmentStatusToolNames {
  static const String inspect = 'environment_status';
  static const Set<String> all = {inspect};
}

abstract final class EnvironmentStatusToolCatalog {
  static List<Map<String, dynamic>> definitions() => [
    {
      'type': 'function',
      'function': {
        'name': EnvironmentStatusToolNames.inspect,
        'description':
            'Read-only diagnostics for the active KELIVO Ubuntu/PRoot environment. Waits for app runtime initialization, then separately verifies RootFS metadata, the Android PRoot host runtime, and a real command session inside Ubuntu. Returns a concise assistantSummary plus structured OS, package-manager, runtime and installed-package counts. Use detail=full only when actual package rows are needed. IMPORTANT: trust assistantSummary, verifiedFacts, conversationWorkspace.shellAvailable, conversationWorkspace.skillExecutionAvailable, prootHostRuntime.ready, prootSession.ready and inventory.summary exactly. Never infer or guess the Android handset model from a screenshot, guest MACHINE, KERNEL, architecture, or terminal output. Do not claim Ubuntu packages are absent unless a live package count says zero. Never run apt install, never search for an apt package named proot, and never use command -v proot inside Ubuntu to test the Android PRoot host runtime. Do not search the internet for this diagnostic. This tool is read-only.',
        'parameters': {
          'type': 'object',
          'properties': {
            'detail': {
              'type': 'string',
              'enum': ['summary', 'full'],
              'description':
                  'summary gives all manager/tool detection and package counts; full also lists installed packages up to max_items per package ecosystem.',
              'default': 'summary',
            },
            'max_items': {
              'type': 'integer',
              'minimum': 1,
              'maximum': 500,
              'description':
                  'Maximum package rows returned for each package ecosystem when detail=full. Defaults to 100.',
              'default': 100,
            },
          },
          'additionalProperties': false,
        },
      },
    },
  ];
}

/// Read-only status probe. PRoot host health is obtained from the registered
/// WorkspaceRuntime API; guest package inventory is collected inside that
/// runtime. No host/guest package managers are invoked in mutating mode.
final class EnvironmentStatusService {
  EnvironmentStatusService({
    required this.runtime,
    required this.environment,
    this.packageManager,
    this.runtimeInitializationError,
    this.workspaceAvailable = false,
    this.conversationScopedWorkspace = false,
  });

  final WorkspaceRuntime? runtime;
  final EnvironmentProvider environment;
  final PackageManagerService? packageManager;
  final String? runtimeInitializationError;
  final bool workspaceAvailable;
  final bool conversationScopedWorkspace;

  Future<String> inspect({
    String detail = 'summary',
    int maxItems = 100,
  }) async {
    if (!const {'summary', 'full'}.contains(detail)) {
      throw const FormatException('environment_status_invalid_detail');
    }
    final limit = maxItems.clamp(1, 500).toInt();
    await environment.loaded;

    final runtimeBackend = runtime;
    final Map<String, Object?> result = <String, Object?>{
      'checkedAt': DateTime.now().toUtc().toIso8601String(),
      'environment': <String, Object?>{},
      'prootHostRuntime': <String, Object?>{},
      'prootSession': <String, Object?>{},
      'verifiedFacts': <String, Object?>{
        'rootfsInstalled': false,
        'rootfsDirectoryExists': false,
        'prootRuntimeRegistered': false,
        'prootRuntimeReady': false,
        'prootSessionReady': false,
        'ubuntuReachable': false,
        'shellAvailable': false,
        'skillExecutionAvailable': false,
        'doNotInferDeviceModel': true,
      },
      'modelGuidance': <String>[
        'Use verifiedFacts and assistantSummary as the authoritative result of this tool.',
        'Do not infer the Android phone model from MACHINE, KERNEL, or guest architecture; they describe the Ubuntu guest only.',
        'Do not say no packages are installed unless inventory.summary contains an actual installedPackageCounts value of zero. An absent count is unknown, not zero.',
        'When verifiedFacts.ubuntuReachable is true and shell is present, you MUST use shell to inspect or act inside Ubuntu; do not guess from the phone model or RootFS metadata.',
        'If shell is absent, report that the conversation runtime bridge was not exposed; do not claim you ran a command.',
        'No Android handset model is verified by this tool. Never name a phone model from MACHINE or KERNEL.',
        'Skill execution is available only when conversationWorkspace.skillExecutionAvailable is true and the Skill is enabled with a valid runtime profile.',
      ],
      'inventory': <String, Object?>{
        'detail': detail,
        'maxItemsPerEcosystem': limit,
      },
      'conversationWorkspace': <String, Object?>{
        'bound': workspaceAvailable && !conversationScopedWorkspace,
        'available': workspaceAvailable,
        'scope': conversationScopedWorkspace ? 'conversation_scratch' : 'project',
        'skillExecutionNeedsWorkspaceContext': true,
        'shellAvailable': false,
        'shellRequiresManualApproval': conversationScopedWorkspace,
        'skillExecutionAvailable': false,
        'availabilityReason': 'runtime_session_not_verified',
      },
      'kelivoManagedPackageLedger': <String, Object?>{
        'available': packageManager != null,
        'source': 'KELIVO package manager ledger',
        'liveVerification': false,
      },
      'notes': <String>[
        'PRoot is an Android host runtime. Its presence is not tested with apt or command -v proot inside Ubuntu.',
        'Termux/Android host packages and a separate Termux Python installation are independent of the in-app RootFS; this guest runtime cannot enumerate them.',
        'All package listings are read-only and may be truncated to the requested per-ecosystem limit.',
        'KELIVO-managed package ledger entries are tracked records across isolated scopes, not a live re-scan of each scoped package directory.',
      ],
    };

    void addEnvironmentState() {
      final state = environment.state;
      final rootfsPath = state.rootfsDir;
      var rootfsExists = false;
      if (rootfsPath != null && rootfsPath.isNotEmpty) {
        try {
          rootfsExists = Directory(rootfsPath).existsSync();
        } catch (_) {}
      }
      (result['environment']! as Map<String, Object?>).addAll({
        'phase': state.phase.name,
        'distribution': state.distro,
        'version': state.version,
        'codename': state.codename,
        'architecture': state.arch,
        'rootfsPathConfigured': rootfsPath != null && rootfsPath.isNotEmpty,
        'rootfsDirectoryExists': rootfsExists,
        'installedAt': state.installedAt?.toUtc().toIso8601String(),
      });
    }
    addEnvironmentState();
    final environmentInfo = result['environment']! as Map<String, Object?>;
    final verifiedFacts = result['verifiedFacts']! as Map<String, Object?>;
    final rootfsDirectoryExists = environmentInfo['rootfsDirectoryExists'] == true;
    var rootfsInstalled =
        environmentInfo['phase'] == 'ready' && rootfsDirectoryExists;
    verifiedFacts['rootfsInstalled'] = rootfsInstalled;
    verifiedFacts['rootfsDirectoryExists'] = rootfsDirectoryExists;
    final packageService = packageManager;
    if (packageService != null) {
      try {
        (result['kelivoManagedPackageLedger']! as Map<String, Object?>)
            .addAll(await packageService.inventorySnapshot(
          detail: detail,
          maxItems: limit,
        ));
      } catch (error) {
        (result['kelivoManagedPackageLedger']! as Map<String, Object?>)
            .addAll({'available': false, 'reason': _safeError(error)});
      }
    }

    if (runtimeBackend == null) {
      final initializationReason = runtimeInitializationError;
      verifiedFacts['prootRuntimeRegistered'] = false;
      (result['prootHostRuntime']! as Map<String, Object?>).addAll({
        'registered': false,
        'ready': false,
        'reason': initializationReason == null || initializationReason.isEmpty
            ? 'runtime_not_registered'
            : 'runtime_initialization_failed: ${_safeError(initializationReason)}',
      });
      (result['prootSession']! as Map<String, Object?>).addAll({
        'tested': false,
        'ready': false,
        'reason': 'runtime_not_registered',
      });
      result['assistantSummary'] = _assistantSummary(
        rootfsReady: rootfsInstalled,
        runtimeRegistered: false,
        runtimeReady: false,
        sessionReady: false,
        failureReason: initializationReason ?? 'runtime_not_registered',
        workspaceAvailable: workspaceAvailable,
        conversationScopedWorkspace: conversationScopedWorkspace,
      );
      return JsonEncoder.withIndent('  ').convert(result);
    }

    RuntimeStatus runtimeStatus;
    try {
      runtimeStatus = await runtimeBackend.status();
      // status() may adopt an on-disk RootFS after reinstall and update the
      // EnvironmentProvider. Refresh the facts after that side effect so the
      // status response does not retain the pre-adoption state.
      addEnvironmentState();
      final refreshedEnvironment =
          result['environment']! as Map<String, Object?>;
      final refreshedRootfsExists =
          refreshedEnvironment['rootfsDirectoryExists'] == true;
      rootfsInstalled =
          refreshedEnvironment['phase'] == 'ready' && refreshedRootfsExists;
      verifiedFacts['rootfsDirectoryExists'] = refreshedRootfsExists;
      verifiedFacts['rootfsInstalled'] = rootfsInstalled;
      final prootRuntimeReady = runtimeStatus.ready &&
          runtimeStatus.engine == 'proot' &&
          runtimeStatus.sandboxed;
      (result['prootHostRuntime']! as Map<String, Object?>).addAll({
        'registered': true,
        'ready': prootRuntimeReady,
        'reportedReady': runtimeStatus.ready,
        'engine': runtimeStatus.engine,
        'sandboxed': runtimeStatus.sandboxed,
        'kernelSandbox': false,
        'securityBoundary': 'PRoot is user-space compatibility/runtime execution, not kernel-level isolation.',
        'reason': prootRuntimeReady
            ? runtimeStatus.reason
            : runtimeStatus.reason ??
                'unsupported_runtime_engine:${runtimeStatus.engine}:sandboxed=${runtimeStatus.sandboxed}',
      });
    } catch (error) {
      verifiedFacts['prootRuntimeRegistered'] = true;
      (result['prootHostRuntime']! as Map<String, Object?>).addAll({
        'registered': true,
        'ready': false,
        'reason': _safeError(error),
      });
      (result['prootSession']! as Map<String, Object?>).addAll({
        'tested': false,
        'ready': false,
        'reason': 'runtime_status_failed',
      });
      result['assistantSummary'] = _assistantSummary(
        rootfsReady: rootfsInstalled,
        runtimeRegistered: true,
        runtimeReady: false,
        sessionReady: false,
        failureReason: _safeError(error),
        workspaceAvailable: workspaceAvailable,
        conversationScopedWorkspace: conversationScopedWorkspace,
      );
      return JsonEncoder.withIndent('  ').convert(result);
    }

    final prootRuntimeReady = runtimeStatus.ready &&
        runtimeStatus.engine == 'proot' &&
        runtimeStatus.sandboxed;
    verifiedFacts['prootRuntimeRegistered'] = true;
    verifiedFacts['prootRuntimeReady'] = prootRuntimeReady;
    if (!prootRuntimeReady) {
      final failureReason = runtimeStatus.reason ??
          (!runtimeStatus.ready
              ? 'host_runtime_not_ready'
              : 'unsupported_runtime_engine:${runtimeStatus.engine}:sandboxed=${runtimeStatus.sandboxed}');
      (result['prootSession']! as Map<String, Object?>).addAll({
        'tested': false,
        'ready': false,
        'reason': failureReason,
      });
      final workspaceInfo = result['conversationWorkspace']! as Map<String, Object?>;
      workspaceInfo['shellAvailable'] = false;
      workspaceInfo['skillExecutionAvailable'] = false;
      workspaceInfo['availabilityReason'] = failureReason;
      result['assistantSummary'] = _assistantSummary(
        rootfsReady: rootfsInstalled,
        runtimeRegistered: true,
        runtimeReady: false,
        sessionReady: false,
        failureReason: failureReason,
        workspaceAvailable: workspaceAvailable,
        conversationScopedWorkspace: conversationScopedWorkspace,
      );
      return JsonEncoder.withIndent('  ').convert(result);
    }

    final runId = 'environment-status-${const Uuid().v4()}';
    final output = BytesBuilder(copy: false);
    var capturedBytes = 0;
    var outputTruncated = false;
    int? exitCode;
    bool timedOut = false;
    String? sessionError;
    try {
      await for (final event in runtimeBackend.run(
        CommandRequest(
          runId: runId,
          command: "printf '__KELIVO_PROOT_SESSION_OK__\\n';\n${_buildInventoryCommand(detail, limit)}",
          cwd: '/',
          timeout: const Duration(seconds: 90),
        ),
      )) {
        if (event is CommandOutput) {
          // The inventory has a bounded line count. Keep a hard ceiling too,
          // so malformed runtime output cannot exhaust application memory.
          const outputLimitBytes = 2 * 1024 * 1024;
          if (capturedBytes < outputLimitBytes) {
            final remaining = outputLimitBytes - capturedBytes;
            final chunk = event.bytes.length <= remaining
                ? event.bytes
                : event.bytes.sublist(0, remaining);
            output.add(chunk);
            capturedBytes += chunk.length;
            if (chunk.length < event.bytes.length) outputTruncated = true;
          } else if (event.bytes.isNotEmpty) {
            outputTruncated = true;
          }
        } else if (event is CommandExited) {
          exitCode = event.exitCode;
          timedOut = event.timedOut;
        }
      }
    } catch (error) {
      sessionError = _safeError(error);
    }

    final transcript = utf8.decode(output.takeBytes(), allowMalformed: true);
    const marker = '__KELIVO_PROOT_SESSION_OK__';
    final sessionStarted = transcript.contains(marker);
    (result['prootSession']! as Map<String, Object?>).addAll({
      'tested': true,
      'ready': sessionStarted && exitCode == 0 && !timedOut,
      'exitCode': exitCode,
      'timedOut': timedOut,
      'reason': sessionError ??
          (sessionStarted ? null : 'session_marker_missing'),
    });

    final sessionReady = sessionStarted && exitCode == 0 && !timedOut;
    verifiedFacts['prootSessionReady'] = sessionReady;
    verifiedFacts['ubuntuReachable'] = prootRuntimeReady && sessionReady;
    final workspaceInfo = result['conversationWorkspace']! as Map<String, Object?>;
    final workspaceRuntimeAvailable =
        workspaceAvailable && prootRuntimeReady && sessionReady;
    workspaceInfo['shellAvailable'] = workspaceRuntimeAvailable;
    verifiedFacts['shellAvailable'] = workspaceRuntimeAvailable;
    workspaceInfo['skillExecutionAvailable'] = workspaceRuntimeAvailable;
    verifiedFacts['skillExecutionAvailable'] =
        workspaceInfo['skillExecutionAvailable'] == true;
    workspaceInfo['availabilityReason'] =
        workspaceInfo['skillExecutionAvailable'] == true
            ? 'ready'
            : !workspaceAvailable
                ? 'no_workspace_context'
                : !sessionReady
                    ? 'proot_session_not_ready'
                    : 'unsupported_runtime';
    final inventoryStart = transcript.indexOf(marker);
    final inventoryText = inventoryStart < 0
        ? ''
        : transcript.substring(inventoryStart + marker.length).trim();
    final inventorySummary = _summarizeInventory(inventoryText);
    (result['inventory']! as Map<String, Object?>).addAll({
      'captured': sessionReady,
      'outputTruncated': outputTruncated,
      'capturedBytes': capturedBytes,
      'summary': inventorySummary,
      if (detail == 'full') 'transcript': inventoryText,
    });
    result['assistantSummary'] = _assistantSummary(
      rootfsReady: rootfsInstalled,
      runtimeRegistered: true,
      runtimeReady: prootRuntimeReady,
      sessionReady: sessionReady,
      failureReason: sessionError ??
          (sessionStarted
              ? (exitCode == 0 ? null : 'guest_exit_code_$exitCode')
              : 'session_marker_missing'),
      distribution: (inventorySummary['distribution'] ?? '').toString(),
      workspaceAvailable: workspaceAvailable,
      conversationScopedWorkspace: conversationScopedWorkspace,
    );
    return JsonEncoder.withIndent('  ').convert(result);
  }

  static String _assistantSummary({
    required bool rootfsReady,
    required bool runtimeRegistered,
    required bool runtimeReady,
    required bool sessionReady,
    String? failureReason,
    String distribution = '',
    bool workspaceAvailable = false,
    bool conversationScopedWorkspace = false,
  }) {
    if (!runtimeRegistered) {
      final reason = failureReason == null || failureReason.isEmpty
          ? ''
          : ' Initialization detail: $failureReason.';
      return rootfsReady
          ? 'The Ubuntu RootFS is marked ready in KELIVO, but the app PRoot runtime is not registered. This is a KELIVO runtime-bootstrap/connection issue, not a missing Ubuntu package.$reason Do not tell the user to install proot with apt. Report the runtime initialization reason and retry after runtime initialization.'
          : 'KELIVO does not currently verify an installed Ubuntu RootFS, and no PRoot runtime is registered.$reason Report these separate states; do not infer a phone model or search the internet.';
    }
    if (!runtimeReady) {
      final reason = failureReason == null || failureReason.isEmpty
          ? ''
          : ' Exact reason: $failureReason.';
      return 'The Android PRoot runtime is registered but not ready.$reason Do not claim PRoot is missing from Ubuntu or recommend apt install proot.';
    }
    if (!sessionReady) {
      final reason = failureReason == null || failureReason.isEmpty
          ? ''
          : ' Exact reason: $failureReason.';
      return 'The Android PRoot host runtime reports ready, but the live command-session probe inside the guest failed.$reason Do not claim commands or Skills can execute successfully yet.';
    }
    final os = distribution.isEmpty ? 'The installed guest environment' : distribution;
    final workspaceText = !workspaceAvailable
        ? ' No conversation workspace is available, so workspace shell/Skill execution is not exposed.'
        : conversationScopedWorkspace
            ? ' A private per-conversation workspace is available; it has no external-folder mounts and shell commands require manual approval even in Full Access.'
            : ' A project workspace is available for workspace and Skill execution.';
    return '$os is reachable: the Android PRoot runtime is registered and ready, and a real command session inside the guest completed successfully. This verifies the app can execute commands inside Ubuntu. Use the shell tool now for any requested Ubuntu inspection or action; do not ask the user to install PRoot again.$workspaceText Use inventory.summary for package/tool facts; do not infer the phone model or conflate this guest with Termux.';
  }

  static Map<String, Object?> _summarizeInventory(String transcript) {
    final summary = <String, Object?>{};
    final commands = <String, Object?>{};
    final packageCounts = <String, int>{};
    String? activeSection;

    for (final rawLine in transcript.split('\n')) {
      final line = rawLine.trim();
      if (line.startsWith('OS=')) {
        summary['distribution'] = line.substring(3).trim();
      } else if (line.startsWith('VERSION=')) {
        summary['version'] = line.substring(8).trim();
      } else if (line.startsWith('CODENAME=')) {
        summary['codename'] = line.substring(9).trim();
      } else if (line.startsWith('KERNEL=')) {
        summary['kernel'] = line.substring(7).trim();
      } else if (line.startsWith('MACHINE=')) {
        summary['machine'] = line.substring(8).trim();
      } else if (line.startsWith('SHELL=')) {
        summary['shell'] = line.substring(6).trim();
      } else if (line.startsWith('### ')) {
        activeSection = line.substring(4).trim();
      } else if (line.startsWith('installedCount=')) {
        final count = int.tryParse(line.substring('installedCount='.length));
        if (count != null && activeSection != null) {
          packageCounts[activeSection] = count;
        }
      } else {
        final commandMatch = RegExp(
          r'^([A-Za-z0-9_.+-]+)=(available|not_found)(?: \((.*)\))?$',
        ).firstMatch(line);
        if (commandMatch != null) {
          commands[commandMatch.group(1)!] = <String, Object?>{
            'available': commandMatch.group(2) == 'available',
            if (commandMatch.group(3) != null)
              'path': commandMatch.group(3),
          };
        }
      }
    }

    final availableManagers = <String>[
      for (final name in const [
        'apt', 'apt-get', 'dpkg', 'apk', 'rpm', 'dnf', 'yum', 'zypper',
        'pacman', 'snap', 'flatpak', 'nix', 'guix', 'brew', 'emerge',
      ])
        if ((commands[name] as Map?)?['available'] == true) name,
    ];
    final availableRuntimes = <String>[
      for (final name in const [
        'python3', 'python', 'node', 'npm', 'pnpm', 'yarn', 'bun', 'deno',
        'ruby', 'gem', 'cargo', 'rustc', 'go', 'java', 'dotnet', 'R', 'lua',
        'elixir',
      ])
        if ((commands[name] as Map?)?['available'] == true) name,
    ];
    summary['availablePackageManagers'] = availableManagers;
    summary['availableRuntimes'] = availableRuntimes;
    summary['commandAvailability'] = commands;
    summary['installedPackageCounts'] = packageCounts;
    summary['rawInventoryIncluded'] = false;
    return summary;
  }

  static String _safeError(Object error) {
    final value = error.toString().replaceAll(RegExp(r'[\r\n]+'), ' ');
    return value.length > 240 ? value.substring(0, 240) : value;
  }

  static String _buildInventoryCommand(String detail, int maxItems) =>
      _inventoryScript
          .replaceAll('@DETAIL@', detail)
          .replaceAll('@LIMIT@', '$maxItems');

  static const String _inventoryScript = r'''set +e
export LC_ALL=C
printf '\n## Distribution and machine\n'
if [ -r /etc/os-release ]; then . /etc/os-release; printf 'OS=%s\nVERSION=%s\nCODENAME=%s\n' "${PRETTY_NAME:-${NAME:-unknown}}" "${VERSION_ID:-unknown}" "${VERSION_CODENAME:-${UBUNTU_CODENAME:-unknown}}"; fi
printf 'KERNEL='; uname -sr 2>/dev/null
printf 'MACHINE='; uname -m 2>/dev/null
printf 'SHELL=%s\n' "${SHELL:-unknown}"

printf '\n## Package manager availability\n'
for name in apt apt-get dpkg dpkg-query apk rpm dnf yum zypper pacman snap flatpak nix guix brew emerge qlist xbps-query pip pip3 pipx pipenv uv rye hatch poetry pdm conda mamba micromamba python python3 node npm npx pnpm yarn bun deno corepack volta gem bundle composer cargo rustup rustc go java gradle mvn cpan dotnet nuget R Rscript lua luarocks elixir mix rebar3 docker podman buildah; do
  path="$(command -v "$name" 2>/dev/null)"
  if [ -n "$path" ]; then printf '%s=available (%s)\n' "$name" "$path"; else printf '%s=not_found\n' "$name"; fi
done

LIMIT=@LIMIT@
DETAIL=@DETAIL@
report_list() {
  label="$1"; command_text="$2"
  rows="$(eval "$command_text" 2>/dev/null)"
  total="$(printf '%s\n' "$rows" | sed '/^$/d' | wc -l | tr -d ' ')"
  printf '\n### %s\n' "$label"
  printf 'installedCount=%s\n' "${total:-0}"
  if [ "$DETAIL" = 'full' ] && [ "${total:-0}" -gt 0 ] 2>/dev/null; then
    printf '%s\n' "$rows" | sed '/^$/d' | sed -n "1,${LIMIT}p"
    if [ "$total" -gt "$LIMIT" ] 2>/dev/null; then printf '[TRUNCATED: showing first %s of %s]\n' "$LIMIT" "$total"; fi
  fi
}

if command -v dpkg-query >/dev/null 2>&1; then
  report_list 'APT/dpkg installed packages' "dpkg-query -W -f='\${db:Status-Abbrev} \${binary:Package} \${Version}\\n' 2>/dev/null | awk '\$1 ~ /^ii/ { \$1=\"\"; sub(/^ /,\"\"); print }' | sort"
fi
if command -v apk >/dev/null 2>&1; then report_list 'APK installed packages' 'apk info -v | sort'; fi
if command -v rpm >/dev/null 2>&1; then report_list 'RPM installed packages' 'rpm -qa --qf "%{NAME} %{VERSION}-%{RELEASE}\\n" | sort'; fi
if command -v pacman >/dev/null 2>&1; then report_list 'Pacman installed packages' 'pacman -Q 2>/dev/null | sort'; fi
if command -v zypper >/dev/null 2>&1; then report_list 'Zypper installed packages' 'zypper --no-refresh search --installed-only 2>/dev/null'; fi
if command -v qlist >/dev/null 2>&1; then report_list 'Gentoo installed packages' 'qlist -I 2>/dev/null'; fi
if command -v xbps-query >/dev/null 2>&1; then report_list 'XBPS installed packages' 'xbps-query -l 2>/dev/null'; fi
if command -v guix >/dev/null 2>&1; then report_list 'Guix profile packages' 'guix package --list-installed 2>/dev/null'; fi
if command -v brew >/dev/null 2>&1; then report_list 'Homebrew installed packages' 'brew list --versions 2>/dev/null'; fi
if command -v snap >/dev/null 2>&1; then report_list 'Snap installed packages' 'snap list 2>/dev/null'; fi
if command -v flatpak >/dev/null 2>&1; then report_list 'Flatpak installed applications' 'flatpak list --app --columns=application,version 2>/dev/null'; fi
if command -v nix >/dev/null 2>&1; then report_list 'Nix profile packages' 'nix profile list 2>/dev/null'; fi
PYTHON_BIN=''
if command -v python3 >/dev/null 2>&1; then PYTHON_BIN=python3; elif command -v python >/dev/null 2>&1; then PYTHON_BIN=python; fi
if [ -n "$PYTHON_BIN" ]; then
  printf '\n### Python runtime\n'; "$PYTHON_BIN" --version 2>&1; "$PYTHON_BIN" -m pip --version 2>&1 | sed -n '1p'
  if "$PYTHON_BIN" -m pip --version >/dev/null 2>&1; then report_list 'Python pip packages (active Python interpreter)' "$PYTHON_BIN -m pip list --format=freeze"; fi
fi
if command -v pipx >/dev/null 2>&1; then report_list 'pipx managed applications' 'pipx list --short'; fi
if command -v pipenv >/dev/null 2>&1; then printf '\n### Pipenv toolchain\n'; pipenv --version 2>&1; fi
if command -v rye >/dev/null 2>&1; then printf '\n### Rye toolchain\n'; rye --version 2>&1; fi
if command -v hatch >/dev/null 2>&1; then printf '\n### Hatch toolchain\n'; hatch --version 2>&1; fi
if command -v mamba >/dev/null 2>&1; then report_list 'Mamba active-environment packages' 'mamba list --export'; fi
if command -v conda >/dev/null 2>&1; then report_list 'Conda active-environment packages' 'conda list --export'; fi
if command -v micromamba >/dev/null 2>&1; then report_list 'Micromamba active-environment packages' 'micromamba list --export'; fi
if command -v poetry >/dev/null 2>&1; then printf '\n### Poetry toolchain\n'; poetry --version 2>&1; report_list 'Poetry project packages (when a project is active)' 'poetry show --only main --no-ansi 2>/dev/null'; fi
if command -v pdm >/dev/null 2>&1; then printf '\n### PDM toolchain\n'; pdm --version 2>&1; report_list 'PDM project packages (when a project is active)' 'pdm list --freeze 2>/dev/null'; fi
if command -v uv >/dev/null 2>&1; then report_list 'uv tools' 'uv tool list'; fi
if command -v dotnet >/dev/null 2>&1; then report_list '.NET global tools' 'dotnet tool list --global 2>/dev/null'; fi
if command -v npm >/dev/null 2>&1; then
  printf '\n### Node runtime\n'; node --version 2>&1; npm --version 2>&1
  report_list 'NPM global packages' 'npm list -g --depth=0 --parseable 2>/dev/null | tail -n +2'
fi
if command -v pnpm >/dev/null 2>&1; then report_list 'PNPM global packages' 'pnpm list -g --depth=0 2>/dev/null'; fi
if command -v yarn >/dev/null 2>&1; then report_list 'Yarn global packages' 'yarn global list 2>/dev/null'; fi
if command -v bun >/dev/null 2>&1; then printf '\n### Bun runtime\n'; bun --version 2>&1; report_list 'Bun global packages' 'bun pm ls -g 2>/dev/null'; fi
if command -v deno >/dev/null 2>&1; then printf '\n### Deno runtime\n'; deno --version 2>&1 | sed -n '1,3p'; fi
if command -v volta >/dev/null 2>&1; then report_list 'Volta managed toolchains' 'volta list 2>/dev/null'; fi
if command -v corepack >/dev/null 2>&1; then printf '\n### Corepack\n'; corepack --version 2>&1; fi
if command -v cargo >/dev/null 2>&1; then printf '\n### Rust toolchain\n'; rustc --version 2>&1; cargo --version 2>&1; report_list 'Cargo-installed binaries' 'cargo install --list 2>/dev/null'; fi
if command -v go >/dev/null 2>&1; then printf '\n### Go toolchain\n'; go version 2>&1; printf 'GOPATH='; go env GOPATH 2>/dev/null; fi
if command -v gem >/dev/null 2>&1; then printf '\n### Ruby toolchain\n'; ruby --version 2>&1; report_list 'Ruby gems' 'gem list --local --no-versions'; fi
if command -v composer >/dev/null 2>&1; then printf '\n### Composer toolchain\n'; composer --version 2>&1 | sed -n '1p'; report_list 'Composer global packages' 'composer global show --no-ansi 2>/dev/null'; fi
if command -v java >/dev/null 2>&1; then printf '\n### Java runtime\n'; java -version 2>&1 | sed -n '1,2p'; fi
if command -v gradle >/dev/null 2>&1; then printf '\n### Gradle\n'; gradle --version 2>&1 | sed -n '1,6p'; fi
if command -v mvn >/dev/null 2>&1; then printf '\n### Maven\n'; mvn --version 2>&1 | sed -n '1,3p'; fi
if command -v rustup >/dev/null 2>&1; then printf '\n### Rustup toolchains\n'; rustup toolchain list 2>&1; fi
if command -v Rscript >/dev/null 2>&1; then report_list 'R installed packages' 'Rscript -e \"ip <- installed.packages(); cat(paste(ip[,1], ip[,3]))\" 2>/dev/null'; fi
if command -v luarocks >/dev/null 2>&1; then report_list 'LuaRocks installed packages' 'luarocks list --porcelain 2>/dev/null'; fi
if command -v elixir >/dev/null 2>&1; then printf '\n### Elixir toolchain\n'; elixir --version 2>&1 | sed -n '1,4p'; fi
if command -v mix >/dev/null 2>&1; then printf '\n### Mix toolchain\n'; mix --version 2>&1 | sed -n '1,3p'; fi

printf '\n## Common command-line tools\n'
report_tool() {
  name="$1"; version_cmd="$2"; path="$(command -v "$name" 2>/dev/null)"
  if [ -n "$path" ]; then version="$(eval "$version_cmd" 2>&1 | sed -n '1p')"; printf '%s=available | %s | %s\n' "$name" "$path" "$version"; else printf '%s=not_found\n' "$name"; fi
}
report_tool bash 'bash --version'
report_tool git 'git --version'
report_tool curl 'curl --version'
report_tool wget 'wget --version'
report_tool ssh 'ssh -V'
report_tool scp 'scp -V'
report_tool sftp 'sftp -V'
report_tool zip 'zip -v'
report_tool unzip 'unzip -v'
report_tool tar 'tar --version'
report_tool ffmpeg 'ffmpeg -version'
report_tool ffprobe 'ffprobe -version'
report_tool yt-dlp 'yt-dlp --version'
report_tool mediainfo 'mediainfo --Version'
report_tool ffmpegthumbnailer 'ffmpegthumbnailer -v'
report_tool magick 'magick -version'
report_tool convert 'convert -version'
report_tool identify 'identify -version'
report_tool sqlite3 'sqlite3 --version'
report_tool jq 'jq --version'
report_tool yq 'yq --version'
report_tool tmux 'tmux -V'
report_tool rsync 'rsync --version'
report_tool make 'make --version'
report_tool cmake 'cmake --version'
report_tool clang 'clang --version'
report_tool gcc 'gcc --version'
report_tool perl 'perl --version'
report_tool php 'php --version'
report_tool gh 'gh --version'
report_tool git-lfs 'git-lfs version'
report_tool 7z '7z'
report_tool 7zz '7zz'
report_tool dotnet 'dotnet --version'
report_tool nuget 'nuget help'
report_tool deno 'deno --version'
report_tool rustup 'rustup --version'
report_tool R 'R --version'
report_tool Rscript 'Rscript --version'
report_tool lua 'lua -v'
report_tool luarocks 'luarocks --version'
report_tool elixir 'elixir --version'
report_tool mix 'mix --version'
report_tool rebar3 'rebar3 --version'
report_tool docker 'docker --version'
report_tool podman 'podman --version'
report_tool buildah 'buildah --version'
report_tool zypper 'zypper --version'
report_tool guix 'guix --version'
report_tool brew 'brew --version'
printf '\n## End of read-only inventory\n'
''';
}
