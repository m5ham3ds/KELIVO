import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/services/sandbox/environment_dependencies.dart';
import 'dependency_test_runtime.dart';
import '../../../support/business_test_harness.dart';
import '../../../features/workspace/environment/environment_test_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late EnvironmentProvider env;
  late DependencyTestRuntime runtime;
  late FakeMirrorService mirrors;
  late EnvironmentDependencies service;
  Future<void> setup({bool alpine = false}) async {
    env = EnvironmentProvider(preferences: createBusinessTestPreferences());
    await env.loaded;
    await env.setState(
      EnvironmentState(
        phase: EnvironmentPhase.ready,
        distro: alpine ? 'alpine' : 'ubuntu',
        arch: 'arm64',
      ),
    );
    runtime = DependencyTestRuntime();
    mirrors = FakeMirrorService(env);
    service = EnvironmentDependencies(
      runtime: runtime,
      env: env,
      alpine: alpine,
      mirrors: mirrors,
    );
    addTearDown(service.dispose);
    addTearDown(env.dispose);
  }

  for (final alpine in [false, true]) {
    test(
      '${alpine ? 'apk' : 'apt'} installs and verifies each preset in the guest',
      () async {
        await setup(alpine: alpine);
        await service.refresh();
        expect(
          service.status(EnvironmentDependency.python),
          DependencyStatus.missing,
        );
        for (final dependency in EnvironmentDependency.values.where(service.supportsDependency)) {
          await service.install(dependency);
          expect(service.failure, isNull);
          expect(service.status(dependency), DependencyStatus.installed);
          expect(service.lastInstalled, dependency);
        }
        expect(runtime.requests.every((r) => r.cwd == '/'), isTrue);
        expect(
          runtime.requests
              .where(
                (r) =>
                    r.command.contains('install -y') ||
                    r.command.contains('apk --wait 60 add'),
              )
              .every((r) => r.timeout == const Duration(minutes: 30) ||
                  (r.command.contains('playwright@1.65.1') &&
                      r.timeout == const Duration(minutes: 60))),
          isTrue,
        );
      },
    );
  }

  test('browser renderer installer is pinned and smoke-tests Chromium', () async {
    await setup();
    expect(service.supportsDependency(EnvironmentDependency.browserRenderer), isTrue);
    final script = service.installScript(EnvironmentDependency.browserRenderer);
    expect(script, contains('NODE_VERSION=26.13.1'));
    expect(script, contains('PLAYWRIGHT_VERSION=1.65.1'));
    expect(script, contains('SHASUMS256.txt'));
    expect(script, contains('sha256sum --check'));
    expect(script, contains('install-deps chromium'));
    expect(script, contains('install chromium'));
    expect(script, contains('CHROMIUM_SMOKE_OK'));
    expect(script, contains('dir="rtl"'));
    expect(script, contains('.verified'));
    await service.install(EnvironmentDependency.browserRenderer);
    expect(service.failure, isNull);
    expect(service.status(EnvironmentDependency.browserRenderer), DependencyStatus.installed);
    expect(runtime.requests.any((r) => r.command.contains('playwright@1.65.1')), isTrue);
    await setup(alpine: true);
    expect(service.supportsDependency(EnvironmentDependency.browserRenderer), isFalse);
    final requestCount = runtime.requests.length;
    await service.install(EnvironmentDependency.browserRenderer);
    expect(runtime.requests.length, requestCount);
  });

  test('grouped media installer installs unique packages and verifies six tools', () async {
    await setup();
    expect(service.mediaToolsInstallScript(), contains('ffmpeg yt-dlp mediainfo ffmpegthumbnailer imagemagick'));
    expect(RegExp(r'\bffmpeg\b').allMatches(service.mediaToolsInstallScript()).length, 1);
    final future = service.installMediaTools();
    await future;
    expect(service.failure, isNull);
    expect(service.status(EnvironmentDependency.mediaTools), DependencyStatus.installed);
    final command = runtime.requests.singleWhere(
      (request) => request.command.contains('ffmpegthumbnailer'),
    );
    expect(command.command, contains('dpkg --configure -a'));
    expect(command.command, contains('imagemagick'));
    expect(runtime.requests.length, 2); // one full probe and one package transaction
  });

  test('individual yt-dlp install installs only its package', () async {
    await setup();
    await service.installMediaTool('yt-dlp');
    expect(service.failure, isNull);
    expect(service.mediaCommandStatus('yt-dlp'), DependencyStatus.installed);
    expect(service.mediaCommandStatus('ffmpeg'), DependencyStatus.missing);
    expect(service.mediaCommandStatus('ffprobe'), DependencyStatus.missing);
    final transaction = runtime.requests.singleWhere(
      (request) => request.command.contains('install -y'),
    );
    expect(transaction.command, contains('yt-dlp'));
    expect(transaction.command, isNot(contains('imagemagick')));
  });

  test('individual FFprobe install verifies the shared FFmpeg package', () async {
    await setup();
    await service.installMediaTool('ffprobe');
    expect(service.failure, isNull);
    expect(service.mediaCommandStatus('ffmpeg'), DependencyStatus.installed);
    expect(service.mediaCommandStatus('ffprobe'), DependencyStatus.installed);
    final transaction = runtime.requests.singleWhere(
      (request) => request.command.contains('install -y'),
    );
    expect(transaction.command, contains('ffmpeg'));
    expect(transaction.command, isNot(contains('yt-dlp')));
  });

  test('ImageMagick individual install recognizes the convert alias', () async {
    await setup();
    await service.installMediaTool('magick');
    expect(service.failure, isNull);
    expect(service.mediaCommandStatus('magick'), DependencyStatus.installed);
    expect(service.mediaCommandStatus('convert'), DependencyStatus.installed);
    final transaction = runtime.requests.singleWhere(
      (request) => request.command.contains('install -y'),
    );
    expect(transaction.command, contains('imagemagick'));
    expect(transaction.command, isNot(contains('ffmpegthumbnailer')));
  });

  test('media preset installs FFmpeg and verifies both ffmpeg and ffprobe', () async {
    await setup();
    final script = service.installScript(EnvironmentDependency.mediaTools);
    expect(service.status(EnvironmentDependency.mediaTools), DependencyStatus.unknown);
    expect(EnvironmentDependency.mediaTools.packages(alpine: false), 'ffmpeg');
    expect(EnvironmentDependency.mediaTools.packages(alpine: true), 'ffmpeg');
    expect(EnvironmentDependency.mediaTools.probe(alpine: false), contains('ffmpeg -version'));
    expect(EnvironmentDependency.mediaTools.probe(alpine: false), contains('ffprobe -version'));
    expect(script, contains('ffmpeg'));
    expect(script, isNot(contains('yt-dlp')));
    expect(script, isNot(contains('mediainfo')));
    await service.install(EnvironmentDependency.mediaTools);
    expect(service.failure, isNull);
    expect(service.status(EnvironmentDependency.mediaTools), DependencyStatus.installed);
    expect(service.optionalMediaStatus('yt-dlp'), DependencyStatus.missing);
    expect(service.optionalMediaStatus('mediainfo'), DependencyStatus.missing);
    expect(service.optionalMediaStatus('ffmpegthumbnailer'), DependencyStatus.missing);
    expect(service.optionalMediaStatus('magick'), DependencyStatus.missing);
    expect(service.optionalMediaStatus('convert'), DependencyStatus.missing);
    expect(service.optionalMediaStatus('identify'), DependencyStatus.missing);
    expect(service.mediaToolVersion('ffmpeg'), 'ffmpeg version test 7.0');
    expect(service.mediaToolVersion('ffprobe'), 'ffprobe version test 7.0');
    final probe = service.probeScript;
    expect(probe, contains(r'__kelivo_media_version=$('));
    expect(probe, contains("printf '__kelivo_media_version_ffmpeg=%s\\n'"));
  });
  test(
    'incomplete status output stays unknown instead of reporting missing',
    () async {
      await setup();
      runtime.incompleteProbe = true;
      await service.refresh();
      expect(service.failure, DependencyFailure.check);
      expect(
        service.status(EnvironmentDependency.python),
        DependencyStatus.unknown,
      );
    },
  );
  test(
    'failed install has log, remains retryable, then verifies success',
    () async {
      await setup();
      runtime.failInstall = true;
      await service.install(EnvironmentDependency.python);
      expect(service.failure, DependencyFailure.install);
      expect(
        service.status(EnvironmentDependency.python),
        DependencyStatus.unknown,
      );
      expect(service.log, contains('Installing packages'));
      runtime.failInstall = false;
      await service.install(EnvironmentDependency.python);
      expect(service.failure, isNull);
      expect(
        service.status(EnvironmentDependency.python),
        DependencyStatus.installed,
      );
    },
  );
  test(
    'serializes installs, cancels the active guest and never claims success',
    () async {
      await setup();
      runtime.installGate = Completer<void>();
      final installing = service.install(EnvironmentDependency.node);
      await Future<void>.delayed(Duration.zero);
      await service.install(EnvironmentDependency.git);
      expect(runtime.requests, hasLength(1));
      expect(service.busy, isTrue);
      await service.cancel();
      await installing;
      expect(runtime.cancelledId, runtime.requests.first.runId);
      expect(service.failure, DependencyFailure.cancelled);
      expect(service.lastInstalled, isNull);
      expect(service.busy, isFalse);
    },
  );
  test(
    'does not cancel a committed package while targeted verification is running',
    () async {
      await setup();
      await service.refresh();
      runtime.probeGate = Completer<void>();
      runtime.probeStarted = Completer<void>();

      final installation = service.install(EnvironmentDependency.python);
      await runtime.probeStarted!.future.timeout(const Duration(seconds: 2));

      expect(service.busy, isTrue);
      expect(service.canCancel, isFalse);
      await service.cancel();
      expect(runtime.cancelledId, isNull);

      runtime.probeGate!.complete();
      await installation;
      expect(service.busy, isFalse);
      expect(service.failure, isNull);
      expect(service.lastInstalled, EnvironmentDependency.python);
      expect(service.status(EnvironmentDependency.python), DependencyStatus.installed);
      final verification = runtime.requests.last.command;
      expect(verification, contains('__kelivo_dep_python='));
      expect(verification, isNot(contains('playwright')));
      expect(verification, isNot(contains('__kelivo_dep_browserRenderer=')));
    },
  );

  test(
    'reapplies saved official and mirror sources before installing',
    () async {
      await setup();
      await env.setMirror(
        MirrorCategory.apt,
        const MirrorSelection(useMirror: false, manual: true),
      );
      await env.setMirror(
        MirrorCategory.pip,
        const MirrorSelection(
          useMirror: true,
          mirrorId: 'pip.tuna',
          manual: true,
        ),
      );
      await service.install(EnvironmentDependency.python);
      expect(mirrors.applied.map((v) => v.$1), [
        MirrorCategory.apt,
        MirrorCategory.pip,
      ]);
      expect(mirrors.applied.first.$2.host, 'ports.ubuntu.com');
      expect(mirrors.applied.last.$2.host, 'pypi.tuna.tsinghua.edu.cn');
    },
  );
  test(
    'reset clears detected packages and blocks installation until ready',
    () async {
      await setup();
      await service.install(EnvironmentDependency.git);
      await env.setState(const EnvironmentState());
      final count = runtime.requests.length;
      await service.install(EnvironmentDependency.node);
      expect(runtime.requests, hasLength(count));
      expect(
        service.status(EnvironmentDependency.git),
        DependencyStatus.unknown,
      );
    },
  );
}
