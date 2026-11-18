import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/packages/package_manager_adapters.dart';
import 'package:Kelivo/core/services/packages/package_manager_models.dart';

void main() {
  test('registers all supported package manager adapters', () {
    expect(
      PackageManagerAdapters.all.map((adapter) => adapter.id),
      containsAll(PackageManagerId.values.where((id) => id != PackageManagerId.auto)),
    );
  });

  test('package-manager adapters are registered through an extensible registry', () {
    final registry = PackageManagerAdapters.createRegistry();
    expect(registry.all, hasLength(PackageManagerAdapters.all.length));
    expect(registry.byId(PackageManagerId.pip), isA<PipPackageManagerAdapter>());
    expect(
      () => registry.register(const PipPackageManagerAdapter()),
      throwsStateError,
    );
  });

  test('APT and APK adapters create exact-version system package commands', () {
    final target = PackageScopeTarget.runtime(PackageEcosystem.system);
    final apt = PackageManagerAdapters.byId(PackageManagerId.apt)!;
    final apk = PackageManagerAdapters.byId(PackageManagerId.apk)!;

    expect(
      apt.installCommand(const PackageSpec(name: 'ffmpeg', version: '6.1.1'), target),
      contains('ffmpeg=6.1.1'),
    );
    expect(
      apk.installCommand(const PackageSpec(name: 'ffmpeg', version: '6.1.1'), target),
      contains('ffmpeg=6.1.1'),
    );
    expect(apt.supportsDistro('ubuntu'), isTrue);
    expect(apt.supportsDistro('alpine'), isFalse);
    expect(apk.supportsDistro('alpine'), isTrue);
    expect(apk.prepareInstallCommand(target), isNull);
    expect(apt.prepareInstallCommand(target), isNotNull);
  });

  test('Python adapters isolate packages in virtual environments', () {
    final target = PackageScopeTarget.runtime(PackageEcosystem.python);
    final pip = PackageManagerAdapters.byId(PackageManagerId.pip)!;
    final uv = PackageManagerAdapters.byId(PackageManagerId.uv)!;
    const package = PackageSpec(name: 'requests', version: '2.32.3');

    expect(pip.installCommand(package, target), contains('python3 -m venv'));
    expect(pip.installCommand(package, target), contains('requests==2.32.3'));
    expect(pip.installCommand(package, target), contains('--only-binary=:all:'));
    expect(uv.installCommand(package, target), contains('uv venv'));
    expect(uv.installCommand(package, target), contains('--python'));
    expect(uv.removeCommand(package, target), contains('--yes'));
  });

  test('Node adapters disable lifecycle scripts unless explicitly allowed', () {
    final target = PackageScopeTarget.runtime(PackageEcosystem.node);
    const package = PackageSpec(name: 'typescript', version: '5.6.3');
    for (final id in [
      PackageManagerId.npm,
      PackageManagerId.pnpm,
      PackageManagerId.yarn,
      PackageManagerId.bun,
    ]) {
      final adapter = PackageManagerAdapters.byId(id)!;
      final safeCommand = adapter.installCommand(package, target);
      final scriptsCommand = adapter.installCommand(
        package,
        target,
        allowScripts: true,
      );
      if (id == PackageManagerId.yarn) {
        // Yarn Classic and Berry expose different configuration names.
        // Set both so lifecycle scripts remain disabled across major versions.
        expect(safeCommand, contains('YARN_ENABLE_SCRIPTS=false'));
        expect(safeCommand, contains('YARN_IGNORE_SCRIPTS=true'));
        expect(scriptsCommand, contains('YARN_ENABLE_SCRIPTS=true'));
        expect(scriptsCommand, contains('YARN_IGNORE_SCRIPTS=false'));
        expect(safeCommand, isNot(contains('--ignore-scripts')));
      } else {
        expect(safeCommand, contains('--ignore-scripts'));
        expect(scriptsCommand, isNot(contains('--ignore-scripts')));
      }
      expect(safeCommand, contains('typescript@5.6.3'));
    }
  });


  test('detection script preserves shell variable expansion', () {
    expect(packageManagerDetectionScript, contains(r'"$command_name"'));
    expect(packageManagerDetectionScript, contains(r'$(uname -m'));
    expect(packageManagerDetectionScript, contains('__KELIVO_PM_ARCH__'));
  });

  test('manager resolution respects manifests and lockfile selection', () {
    const availability = PackageManagerAvailability(
      commands: {'python3', 'uv', 'npm', 'pnpm', 'apt-get'},
      distro: 'ubuntu',
      architecture: 'aarch64',
    );
    expect(
      resolvePackageManager(
        requested: PackageManagerId.auto,
        manifestEcosystem: PackageEcosystem.python,
        distro: 'ubuntu',
        availability: availability,
      ),
      PackageManagerId.uv,
    );
    expect(
      resolvePackageManager(
        requested: PackageManagerId.auto,
        manifestEcosystem: PackageEcosystem.node,
        distro: 'ubuntu',
        availability: availability,
        nodeLockfile: 'pnpm-lock.yaml',
      ),
      PackageManagerId.pnpm,
    );
    expect(
      resolvePackageManager(
        requested: PackageManagerId.auto,
        manifestEcosystem: null,
        distro: 'ubuntu',
        availability: availability,
      ),
      PackageManagerId.apt,
    );
  });
}
