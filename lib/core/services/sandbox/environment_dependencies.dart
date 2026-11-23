import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:Kelivo/core/services/mobile_background.dart';
import 'package:uuid/uuid.dart';
import 'package:Kelivo/core/services/sandbox/mirror_service.dart';

import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';

enum EnvironmentDependency { python, node, git, ssh, network, archive, mediaTools, browserRenderer }

enum DependencyStatus { unknown, missing, installed }

enum DependencyFailure { check, install, cancelled }

extension EnvironmentDependencyCommands on EnvironmentDependency {
  String packages({required bool alpine}) => switch (this) {
    EnvironmentDependency.python =>
      alpine
          ? 'python3 py3-pip py3-virtualenv'
          : 'python3 python3-pip python3-venv',
    EnvironmentDependency.node => 'nodejs npm',
    EnvironmentDependency.git => 'git',
    EnvironmentDependency.ssh =>
      alpine ? 'openssh-client-default' : 'openssh-client',
    EnvironmentDependency.network => 'curl wget',
    EnvironmentDependency.archive => 'zip unzip',
    EnvironmentDependency.mediaTools => 'ffmpeg',
    EnvironmentDependency.browserRenderer => 'playwright@1.65.1',
  };

  String probe({required bool alpine}) => switch (this) {
    EnvironmentDependency.python =>
      'python3 --version && python3 -m pip --version && ${alpine ? 'virtualenv --version' : 'python3 -m venv --help'}',
    EnvironmentDependency.node => 'node --version && npm --version',
    EnvironmentDependency.git => 'git --version',
    EnvironmentDependency.ssh =>
      'ssh -V && command -v scp && command -v sftp && command -v ssh-keygen',
    EnvironmentDependency.network => 'curl --version && wget --version',
    EnvironmentDependency.archive => 'zip -v && unzip -v',
    EnvironmentDependency.mediaTools => 'ffmpeg -version && ffprobe -version',
    EnvironmentDependency.browserRenderer => r'test -x "$HOME/.local/share/kelivo/browser-renderer/node/bin/node" && grep -Fxq "node=26.13.1" "$HOME/.local/share/kelivo/browser-renderer/.verified" && grep -Fxq "playwright=1.65.1" "$HOME/.local/share/kelivo/browser-renderer/.verified" && PLAYWRIGHT_BROWSERS_PATH="$HOME/.local/share/kelivo/browser-renderer/browsers" timeout 30s "$HOME/.local/share/kelivo/browser-renderer/node/bin/node" "$HOME/.local/share/kelivo/browser-renderer/smoke.mjs"',
  };
}

/// A process-wide installer: leaving the page does not lose progress or start
/// another package transaction. Installed state is probed from the guest.
class EnvironmentDependencies extends ChangeNotifier {
  EnvironmentDependencies({
    required this.runtime,
    required this.env,
    required bool alpine,
    required this.mirrors,
  }) : _defaultAlpine = alpine {
    env.addListener(_environmentChanged);
  }

  final WorkspaceRuntime runtime;
  final EnvironmentProvider env;
  final bool _defaultAlpine;
  bool get alpine =>
      env.state.distro == null ? _defaultAlpine : env.state.distro == 'alpine';
  bool get supportsPackages =>
      env.state.distro == null ||
      {'ubuntu', 'debian', 'alpine'}.contains(env.state.distro);

  /// Playwright documents Debian/Ubuntu on ARM64/x64; Android PRoot itself is
  /// not listed as an official platform, so this install remains experimental.
  bool supportsDependency(EnvironmentDependency dependency) {
    if (dependency != EnvironmentDependency.browserRenderer) return true;
    final arch = env.state.arch?.toLowerCase();
    return !alpine &&
        {'ubuntu', 'debian'}.contains(env.state.distro) &&
        {'arm64', 'aarch64', 'x86_64', 'amd64'}.contains(arch);
  }
  final MirrorService mirrors;
  MirrorCancelToken? _mirrorCancel;
  final Map<EnvironmentDependency, DependencyStatus> _statuses = {};
  final Map<String, DependencyStatus> _optionalMediaStatuses = {};
  String? installingMediaCommand;
  String? lastInstalledMediaCommand;
  String? _backgroundTaskId;
  final Map<String, String> _mediaVersions = {};
  static const List<String> optionalMediaTools = [
    'yt-dlp',
    'mediainfo',
    'ffmpegthumbnailer',
    // ImageMagick 7 and 6 command names; detected only, never installed by the preset.
    'magick',
    'convert',
    'identify',
  ];
  final List<int> _output = [];
  String? _runId;
  bool _cancelled = false;
  bool busy = false;
  EnvironmentDependency? installing;
  EnvironmentDependency? lastInstalled;
  EnvironmentDependency? lastAttempt;
  DependencyFailure? failure;
  String get log => utf8.decode(_output, allowMalformed: true);
  DependencyStatus status(EnvironmentDependency dependency) =>
      _statuses[dependency] ?? DependencyStatus.unknown;

  DependencyStatus optionalMediaStatus(String command) =>
      _optionalMediaStatuses[command] ?? DependencyStatus.unknown;

  String? mediaToolVersion(String command) => _mediaVersions[command];
  DependencyStatus mediaCommandStatus(String command) {
    if (command == 'ffmpeg' || command == 'ffprobe') {
      return _mediaVersions.containsKey(command)
          ? DependencyStatus.installed
          : status(EnvironmentDependency.mediaTools) == DependencyStatus.unknown
              ? DependencyStatus.unknown
              : DependencyStatus.missing;
    }
    if (command == 'magick' &&
        (optionalMediaStatus('magick') == DependencyStatus.installed ||
            optionalMediaStatus('convert') == DependencyStatus.installed)) {
      return DependencyStatus.installed;
    }
    return optionalMediaStatus(command);
  }

  String? mediaCommandVersion(String command) => _mediaVersions[command];


  void _environmentChanged() {
    if (env.state.phase != EnvironmentPhase.ready) {
      _statuses.clear();
      _optionalMediaStatuses.clear();
      _mediaVersions.clear();
      lastInstalled = null;
      notifyListeners();
    }
  }

  String get probeScript => [
    for (final dependency in EnvironmentDependency.values)
      'if ( ${dependency.probe(alpine: alpine)} ) >/dev/null 2>&1; then '
          "echo '__kelivo_dep_${dependency.name}=1'; else "
          "echo '__kelivo_dep_${dependency.name}=0'; fi",
    for (final command in [
      'yt-dlp',
      'mediainfo',
      'ffmpegthumbnailer',
      'magick',
      'convert',
      'identify',
    ])
      'if command -v ${_shellQuote(command)} >/dev/null 2>&1; then '
          "echo '__kelivo_media_optional_${command}=1'; else "
          "echo '__kelivo_media_optional_${command}=0'; fi",
    for (final command in ['ffmpeg', 'ffprobe'])
      'if command -v ${_shellQuote(command)} >/dev/null 2>&1; then '
          '__kelivo_media_version=\$(${_shellQuote(command)} -version 2>/dev/null | head -n 1 | cut -c1-160); '
          "printf '__kelivo_media_version_${command}=%s\\n' \"${r'$'}__kelivo_media_version\"; fi",
  ].join('\n');

  static String _shellQuote(String value) =>
      "'${value.replaceAll("'", "'\\''")}'";

  String installScript(EnvironmentDependency dependency) {
    if (dependency == EnvironmentDependency.browserRenderer) {
      return browserRendererInstallScript;
    }
    if (dependency == EnvironmentDependency.mediaTools) {
      return mediaToolsInstallScript();
    }
    final packages = dependency.packages(alpine: alpine);
    if (alpine) {
      return 'set -e\napk --wait 60 update\napk --wait 60 add $packages\n';
    }
    return 'set -e\nexport DEBIAN_FRONTEND=noninteractive\n'
        'dpkg --configure -a\n'
        'apt-get -o DPkg::Lock::Timeout=60 -o Acquire::Retries=2 '
        '-o APT::Update::Error-Mode=any update\n'
        'apt-get -o DPkg::Lock::Timeout=60 -f install -y\n'
        'apt-get -o DPkg::Lock::Timeout=60 -o Acquire::Retries=2 '
        'install -y --no-install-recommends ca-certificates $packages\n';
  }

  String _mediaToolPackage(String command) => switch (command) {
    'ffmpeg' || 'ffprobe' => 'ffmpeg',
    'yt-dlp' => 'yt-dlp',
    'mediainfo' => 'mediainfo',
    'ffmpegthumbnailer' => 'ffmpegthumbnailer',
    'magick' || 'convert' || 'identify' => 'imagemagick',
    _ => throw ArgumentError.value(command, 'command', 'Unknown media tool'),
  };

  String _packageInstallScript(String packages) {
    if (alpine) {
      return 'set -e\napk --wait 60 update\napk --wait 60 add $packages\n';
    }
    return 'set -e\nexport DEBIAN_FRONTEND=noninteractive\n'
        'dpkg --configure -a\n'
        'apt-get -o DPkg::Lock::Timeout=60 -o Acquire::Retries=2 '
        '-o APT::Update::Error-Mode=any update\n'
        'apt-get -o DPkg::Lock::Timeout=60 -f install -y\n'
        'apt-get -o DPkg::Lock::Timeout=60 -o Acquire::Retries=2 '
        'install -y --no-install-recommends ca-certificates $packages\n';
  }

  String mediaToolInstallScript(String command) =>
      _packageInstallScript(_mediaToolPackage(command));

  String mediaToolsInstallScript() => _packageInstallScript(
    'ffmpeg yt-dlp mediainfo ffmpegthumbnailer imagemagick',
  );

  /// Installs a pinned renderer inside the guest rootfs only.
  static const String browserRendererInstallScript = r'''set -euo pipefail
NODE_VERSION=26.13.1
PLAYWRIGHT_VERSION=1.65.1
ROOT="$HOME/.local/share/kelivo/browser-renderer"
TMP="$HOME/.cache/kelivo-browser-renderer"
if [ "$(id -u)" -ne 0 ]; then echo "Guest root is required for Chromium system libraries."; exit 1; fi
. /etc/os-release
case "$ID:$VERSION_ID" in ubuntu:22.04|ubuntu:24.04|ubuntu:26.04|debian:12|debian:13) ;; *) echo "Supports Ubuntu 22.04/24.04/26.04 or Debian 12/13 only."; exit 1 ;; esac
case "$(uname -m)" in aarch64|arm64) NODE_ARCH=arm64 ;; x86_64|amd64) NODE_ARCH=x64 ;; *) echo "Unsupported Linux architecture: $(uname -m)"; exit 1 ;; esac
mkdir -p "$TMP" "$ROOT/node" "$ROOT/app" "$ROOT/browsers"
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl xz-utils
archive="node-v$NODE_VERSION-linux-$NODE_ARCH.tar.xz"
curl --fail --location --silent --show-error --retry 3 "https://nodejs.org/dist/$NODE_VERSION/SHASUMS256.txt" -o "$TMP/SHASUMS256.txt"
curl --fail --location --silent --show-error --retry 3 "https://nodejs.org/dist/$NODE_VERSION/$archive" -o "$TMP/$archive"
awk -v archive="$archive" '$2 == archive { print $1 "  " $2; found=1; exit } END { if (!found) exit 1 }' "$TMP/SHASUMS256.txt" > "$TMP/archive.sha256"
(cd "$TMP" && sha256sum --check archive.sha256)
tar -xJf "$TMP/$archive" --strip-components=1 -C "$ROOT/node"
"$ROOT/node/bin/node" --version | grep -Fx "v$NODE_VERSION"
"$ROOT/node/bin/npm" install --prefix "$ROOT/app" --no-audit --no-fund --save-exact "playwright@1.65.1"
export PLAYWRIGHT_BROWSERS_PATH="$ROOT/browsers"
"$ROOT/node/bin/node" "$ROOT/app/node_modules/playwright/cli.js" install-deps chromium
"$ROOT/node/bin/node" "$ROOT/app/node_modules/playwright/cli.js" install chromium
cat > "$ROOT/smoke.mjs" <<'JS'
import { chromium } from './app/node_modules/playwright/index.mjs';
const browser = await chromium.launch({headless:true,args:['--no-sandbox','--disable-dev-shm-usage','--disable-gpu','--no-zygote']});
try {
 const page=await browser.newPage({viewport:{width:720,height:1280}});
 await page.setContent('<!doctype html><html lang="ar" dir="rtl"><meta charset="utf-8"><body style="background:#0c1014;color:#f4f3ee;font:28px sans-serif"><h1>اختبار التصيير العربي</h1><p>Reel Studio · موشن جرافيك</p></body></html>');
 const image=await page.screenshot({type:'png'});
 if(!image||image.length<1024) throw new Error('Chromium screenshot is empty');
 console.log('CHROMIUM_SMOKE_OK bytes='+image.length);
} finally { await browser.close(); }
JS
PLAYWRIGHT_BROWSERS_PATH="$ROOT/browsers" timeout 45s "$ROOT/node/bin/node" "$ROOT/smoke.mjs"
printf 'node=%s\nplaywright=%s\nchromium=smoke-passed\n' "$NODE_VERSION" "$PLAYWRIGHT_VERSION" > "$ROOT/.verified"
echo "Browser renderer installed and Chromium smoke test passed."
''';

  Future<void> refresh() async {
    if (busy ||
        !supportsPackages ||
        env.state.phase != EnvironmentPhase.ready) {
      return;
    }
    busy = true;
    _cancelled = false;
    failure = null;
    notifyListeners();
    try {
      await _probe();
    } catch (_) {
      failure = _cancelled
          ? DependencyFailure.cancelled
          : DependencyFailure.check;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _applyPackageMirror() async {
    final category = alpine ? MirrorCategory.apk : MirrorCategory.apt;
    final selection = env.mirrors[category];
    if (selection == null) return;
    final entry = selection.useMirror
        ? MirrorService.findEntry(
            category,
            id: selection.mirrorId,
            url: selection.selectedBaseUrl,
            arch: env.state.arch ?? 'arm64',
            distro: env.state.distro ?? 'ubuntu',
          )
        : MirrorService.officialEntry(
            category,
            arch: env.state.arch ?? 'arm64',
            distro: env.state.distro ?? 'ubuntu',
          );
    if (entry == null) throw StateError('Unknown package source');
    await mirrors.applyEntry(
      category,
      entry,
      manual: selection.manual,
      cancelToken: _mirrorCancel,
    );
  }

  Future<String?> _startBackgroundOperation(String title) async {
    if (!Platform.isAndroid) return null;
    final id = 'environment-dependency-${const Uuid().v4()}';
    final coordinator = MobileBackgroundCoordinator.instance;
    try {
      await coordinator.start(
        id: id,
        conversationId: '',
        title: title,
        cancel: cancel,
      );
      _backgroundTaskId = id;
      return id;
    } catch (error) {
      debugPrint('[EnvironmentDependencies] Background service unavailable: $error');
      try {
        await coordinator.finish(
          id,
          BackgroundTaskOutcome.failed,
          resultPersisted: false,
        );
      } catch (_) {}
      return null;
    }
  }

  Future<void> _finishBackgroundOperation(String? id) async {
    if (id == null) return;
    if (_backgroundTaskId == id) _backgroundTaskId = null;
    final outcome = _cancelled
        ? BackgroundTaskOutcome.cancelled
        : failure == null
            ? BackgroundTaskOutcome.completed
            : BackgroundTaskOutcome.failed;
    try {
      await MobileBackgroundCoordinator.instance.finish(
        id,
        outcome,
        resultPersisted: false,
      );
    } catch (error) {
      debugPrint('[EnvironmentDependencies] Background completion failed: $error');
    }
  }

  void _updateBackgroundOperation() {
    final id = _backgroundTaskId;
    if (id == null) return;
    MobileBackgroundCoordinator.instance.update(
      id,
      phase: BackgroundTaskPhase.tool,
      toolName: 'APT / APK',
      progressLabel: 'Installing packages',
    );
  }

  Future<void> installMediaTools({
    Future<bool> Function()? confirm,
  }) async {
    if (confirm != null && !await confirm()) return;
    if (busy || !supportsPackages || env.state.phase != EnvironmentPhase.ready) {
      return;
    }
    busy = true;
    _cancelled = false;
    installing = EnvironmentDependency.mediaTools;
    lastAttempt = EnvironmentDependency.mediaTools;
    lastInstalled = null;
    failure = null;
    _output.clear();
    _statuses[EnvironmentDependency.mediaTools] = DependencyStatus.unknown;
    notifyListeners();
    final backgroundId = await _startBackgroundOperation('Installing Media tools');
    try {
      _mirrorCancel = MirrorCancelToken();
      await _applyPackageMirror();
      if (_cancelled) throw StateError('Cancelled');
      await _run(
        mediaToolsInstallScript(),
        timeout: const Duration(minutes: 30),
        showOutput: true,
      );
      if (_cancelled) throw StateError('Cancelled');
      await _probe();
      final allRequiredPresent =
          _mediaVersions.containsKey('ffmpeg') &&
          _mediaVersions.containsKey('ffprobe') &&
          optionalMediaStatus('yt-dlp') == DependencyStatus.installed &&
          optionalMediaStatus('mediainfo') == DependencyStatus.installed &&
          optionalMediaStatus('ffmpegthumbnailer') == DependencyStatus.installed &&
          (optionalMediaStatus('magick') == DependencyStatus.installed ||
              optionalMediaStatus('convert') == DependencyStatus.installed);
      if (!allRequiredPresent) {
        throw StateError('Media tools failed executable verification');
      }
      _statuses[EnvironmentDependency.mediaTools] = DependencyStatus.installed;
      lastInstalled = EnvironmentDependency.mediaTools;
      await env.clearCachedDiskUsage();
    } catch (_) {
      failure = _cancelled
          ? DependencyFailure.cancelled
          : DependencyFailure.install;
      _statuses[EnvironmentDependency.mediaTools] = DependencyStatus.missing;
    } finally {
      _mirrorCancel = null;
      installing = null;
      busy = false;
      await _finishBackgroundOperation(backgroundId);
      notifyListeners();
    }
  }

  Future<void> installMediaTool(
    String command, {
    Future<bool> Function()? confirm,
  }) async {
    final package = _mediaToolPackage(command);
    if (mediaCommandStatus(command) == DependencyStatus.installed) return;
    if (confirm != null && !await confirm()) return;
    if (busy || !supportsPackages || env.state.phase != EnvironmentPhase.ready) {
      return;
    }
    busy = true;
    _cancelled = false;
    installing = EnvironmentDependency.mediaTools;
    installingMediaCommand = command;
    lastAttempt = EnvironmentDependency.mediaTools;
    lastInstalled = null;
    lastInstalledMediaCommand = null;
    failure = null;
    _output.clear();
    notifyListeners();
    final backgroundId = await _startBackgroundOperation('Installing $command');
    try {
      _mirrorCancel = MirrorCancelToken();
      await _applyPackageMirror();
      if (_cancelled) throw StateError('Cancelled');
      await _run(
        _packageInstallScript(package),
        timeout: const Duration(minutes: 30),
        showOutput: true,
      );
      if (_cancelled) throw StateError('Cancelled');
      await _probe();
      if (mediaCommandStatus(command) != DependencyStatus.installed) {
        throw StateError('Media tool failed executable verification: $command');
      }
      lastInstalled = EnvironmentDependency.mediaTools;
      lastInstalledMediaCommand = command;
      await env.clearCachedDiskUsage();
    } catch (_) {
      failure = _cancelled
          ? DependencyFailure.cancelled
          : DependencyFailure.install;
    } finally {
      _mirrorCancel = null;
      installing = null;
      installingMediaCommand = null;
      busy = false;
      await _finishBackgroundOperation(backgroundId);
      notifyListeners();
    }
  }

  Future<void> install(EnvironmentDependency dependency) async {
    if (!supportsDependency(dependency)) return;
    if (busy ||
        !supportsPackages ||
        env.state.phase != EnvironmentPhase.ready) {
      return;
    }
    busy = true;
    _cancelled = false;
    installing = dependency;
    lastAttempt = dependency;
    lastInstalled = null;
    failure = null;
    _output.clear();
    _statuses[dependency] = DependencyStatus.unknown;
    notifyListeners();
    final backgroundId = await _startBackgroundOperation(
      'Installing ${dependency.name}',
    );
    try {
      _mirrorCancel = MirrorCancelToken();
      final categories = {
        alpine ? MirrorCategory.apk : MirrorCategory.apt,
        if (dependency == EnvironmentDependency.python) MirrorCategory.pip,
        if (dependency == EnvironmentDependency.node ||
            dependency == EnvironmentDependency.browserRenderer)
          MirrorCategory.npm,
      };
      for (final category in categories) {
        final selection = env.mirrors[category];
        if (selection == null) continue;
        final entry = selection.useMirror
            ? MirrorService.findEntry(
                category,
                id: selection.mirrorId,
                url: selection.selectedBaseUrl,
                arch: env.state.arch ?? 'arm64',
                distro: env.state.distro ?? 'ubuntu',
              )
            : MirrorService.officialEntry(
                category,
                arch: env.state.arch ?? 'arm64',
                distro: env.state.distro ?? 'ubuntu',
              );
        if (entry == null) throw StateError('Unknown package source');
        await mirrors.applyEntry(
          category,
          entry,
          manual: selection.manual,
          cancelToken: _mirrorCancel,
        );
      }
      if (_cancelled) throw StateError('Cancelled');
      await _run(
        installScript(dependency),
        timeout: Duration(minutes: dependency == EnvironmentDependency.browserRenderer ? 60 : 30),
        showOutput: true,
      );
      if (_cancelled) throw StateError('Cancelled');
      await _probe();
      if (status(dependency) != DependencyStatus.installed) {
        throw StateError('Installed commands failed verification');
      }
      lastInstalled = dependency;
      await env.clearCachedDiskUsage();
    } catch (_) {
      failure = _cancelled
          ? DependencyFailure.cancelled
          : DependencyFailure.install;
    } finally {
      _mirrorCancel = null;
      installing = null;
      busy = false;
      await _finishBackgroundOperation(backgroundId);
      notifyListeners();
    }
  }

  Future<void> cancel() async {
    if (!busy) return;
    _cancelled = true;
    _mirrorCancel?.cancel();
    final id = _runId;
    if (id != null) await runtime.cancel(id);
  }

  Future<void> _probe() async {
    final output = await _run(
      probeScript,
      timeout: const Duration(seconds: 90),
    );
    final lines = const LineSplitter().convert(output).toSet();
    final statuses = <EnvironmentDependency, DependencyStatus>{};
    for (final dependency in EnvironmentDependency.values) {
      final prefix = '__kelivo_dep_${dependency.name}=';
      final installed = lines.contains('${prefix}1');
      final missing = lines.contains('${prefix}0');
      if (installed == missing) {
        throw const FormatException('Incomplete dependency probe');
      }
      statuses[dependency] = installed
          ? DependencyStatus.installed
          : DependencyStatus.missing;
    }
    _statuses.addAll(statuses);
    for (final command in optionalMediaTools) {
      final prefix = '__kelivo_media_optional_${command}=';
      final installed = lines.contains('${prefix}1');
      final missing = lines.contains('${prefix}0');
      _optionalMediaStatuses[command] = installed == missing
          ? DependencyStatus.unknown
          : installed
          ? DependencyStatus.installed
          : DependencyStatus.missing;
    }
    _mediaVersions.clear();
    for (final line in lines) {
      if (!line.startsWith('__kelivo_media_version_')) continue;
      final separator = line.indexOf('=');
      if (separator <= '__kelivo_media_version_'.length) continue;
      final command = line.substring('__kelivo_media_version_'.length, separator);
      final version = line.substring(separator + 1).trim();
      if ({'ffmpeg', 'ffprobe'}.contains(command) && version.isNotEmpty && version.length <= 160) {
        _mediaVersions[command] = version;
      }
    }
  }

  Future<String> _run(
    String script, {
    required Duration timeout,
    bool showOutput = false,
  }) async {
    if (_cancelled) throw StateError('Cancelled');
    final config = await env.loadExecutionConfig();
    if (_cancelled) throw StateError('Cancelled');
    final id = _runId = 'dependency-${const Uuid().v4()}';
    final output = <int>[];
    CommandExited? exit;
    try {
      await for (final event in runtime.run(
        CommandRequest(
          runId: id,
          command: script,
          cwd: '/',
          timeout: timeout,
          env: config.variables,
        ),
      )) {
        if (event is CommandOutput) {
          output.addAll(event.bytes);
          if (output.length > 65536) {
            output.removeRange(0, output.length - 65536);
          }
          if (showOutput) {
            _updateBackgroundOperation();
            _output.addAll(event.bytes);
            if (_output.length > 65536) {
              _output.removeRange(0, _output.length - 65536);
            }
            notifyListeners();
          }
        } else if (event is CommandExited) {
          exit = event;
          _cancelled = _cancelled || event.cancelled;
        }
      }
      if (exit == null ||
          exit.exitCode != 0 ||
          exit.timedOut ||
          exit.cancelled ||
          exit.interrupted ||
          _cancelled) {
        throw StateError('Dependency command failed');
      }
      return utf8.decode(output, allowMalformed: true);
    } finally {
      _runId = null;
    }
  }

  @override
  void dispose() {
    env.removeListener(_environmentChanged);
    super.dispose();
  }
}
