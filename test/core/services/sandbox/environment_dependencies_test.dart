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
        for (final dependency in EnvironmentDependency.values) {
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
              .every((r) => r.timeout == const Duration(minutes: 30)),
          isTrue,
        );
      },
    );
  }

  test('media preset installs FFmpeg and verifies both ffmpeg and ffprobe', () async {
    await setup();
    final script = service.installScript(EnvironmentDependency.mediaTools);
    expect(service.status(EnvironmentDependency.mediaTools), DependencyStatus.unknown);
    expect(EnvironmentDependency.mediaTools.packages(alpine: false), 'ffmpeg');
    expect(EnvironmentDependency.mediaTools.packages(alpine: true), 'ffmpeg');
    expect(EnvironmentDependency.mediaTools.probe(alpine: false), contains('ffmpeg -version'));
    expect(EnvironmentDependency.mediaTools.probe(alpine: false), contains('ffprobe -version'));
    expect(script, contains('ffmpeg'));
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
