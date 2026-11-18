import 'package:Kelivo/core/services/packages/package_manager_models.dart';

abstract interface class PackageManagerAdapter {
  PackageManagerId get id;
  PackageEcosystem get ecosystem;
  Set<String> get requiredCommands;

  bool supportsDistro(String? distro);

  String? prepareInstallCommand(PackageScopeTarget target) => null;

  String installCommand(
    PackageSpec package,
    PackageScopeTarget target, {
    String? pinnedVersion,
    bool allowScripts = false,
    bool allowSourceBuilds = false,
  });

  String upgradeCommand(
    PackageSpec package,
    PackageScopeTarget target, {
    String? pinnedVersion,
    bool allowScripts = false,
    bool allowSourceBuilds = false,
  });

  String removeCommand(
    PackageSpec package,
    PackageScopeTarget target, {
    bool allowScripts = false,
  });
  String checkCommand(PackageSpec package, PackageScopeTarget target);
}

abstract base class _Adapter implements PackageManagerAdapter {
  const _Adapter();

  @override
  String? prepareInstallCommand(PackageScopeTarget target) => null;

  String argument(PackageSpec package, {String? pinnedVersion}) =>
      shellQuote(package.installArgument(id, pinnedVersion: pinnedVersion));

  @override
  bool supportsDistro(String? distro) {
    final normalized = distro?.toLowerCase();
    return switch (id) {
    PackageManagerId.apt => normalized == 'ubuntu' || normalized == 'debian',
    PackageManagerId.apk => normalized == 'alpine',
    _ => true,
    };
  }
}

final class AptPackageManagerAdapter extends _Adapter {
  const AptPackageManagerAdapter();

  @override
  PackageManagerId get id => PackageManagerId.apt;
  @override
  PackageEcosystem get ecosystem => PackageEcosystem.system;
  @override
  Set<String> get requiredCommands => const {'apt-get', 'dpkg-query'};

  @override
  String? prepareInstallCommand(PackageScopeTarget target) =>
      'export DEBIAN_FRONTEND=noninteractive; '
      'apt-get -o DPkg::Lock::Timeout=60 -o Acquire::Retries=2 '
      '-o APT::Update::Error-Mode=any update';

  @override
  String installCommand(
    PackageSpec package,
    PackageScopeTarget target, {
    String? pinnedVersion,
    bool allowScripts = false,
    bool allowSourceBuilds = false,
  }) {
    final spec = argument(package, pinnedVersion: pinnedVersion);
    return 'export DEBIAN_FRONTEND=noninteractive; '
        'apt-get -o DPkg::Lock::Timeout=60 install -y '
        '--no-install-recommends -- $spec';
  }

  @override
  String upgradeCommand(
    PackageSpec package,
    PackageScopeTarget target, {
    String? pinnedVersion,
    bool allowScripts = false,
    bool allowSourceBuilds = false,
  }) {
    final spec = argument(package, pinnedVersion: pinnedVersion);
    return 'set -e; export DEBIAN_FRONTEND=noninteractive; '
        'apt-get -o DPkg::Lock::Timeout=60 -o Acquire::Retries=2 '
        'install -y --only-upgrade -- $spec';
  }

  @override
  String removeCommand(PackageSpec package, PackageScopeTarget target, {bool allowScripts = false}) =>
      'export DEBIAN_FRONTEND=noninteractive; '
      'apt-get -o DPkg::Lock::Timeout=60 remove -y -- ${shellQuote(package.name)}';

  @override
  String checkCommand(PackageSpec package, PackageScopeTarget target) {
    final name = shellQuote(package.name);
    return "if dpkg-query -W -f='\${Status}|\${Version}\\n' -- $name "
        "2>/dev/null | grep -q '^install ok installed|'; "
        "then dpkg-query -W -f='__KELIVO_INSTALLED__|\${Version}\\n' "
        "-- $name 2>/dev/null; else echo __KELIVO_MISSING__; fi";
  }
}

final class ApkPackageManagerAdapter extends _Adapter {
  const ApkPackageManagerAdapter();

  @override
  PackageManagerId get id => PackageManagerId.apk;
  @override
  PackageEcosystem get ecosystem => PackageEcosystem.system;
  @override
  Set<String> get requiredCommands => const {'apk'};

  @override
  String installCommand(
    PackageSpec package,
    PackageScopeTarget target, {
    String? pinnedVersion,
    bool allowScripts = false,
    bool allowSourceBuilds = false,
  }) =>
      'set -e; apk --wait 60 add --no-progress '
      '${argument(package, pinnedVersion: pinnedVersion)}';

  @override
  String upgradeCommand(
    PackageSpec package,
    PackageScopeTarget target, {
    String? pinnedVersion,
    bool allowScripts = false,
    bool allowSourceBuilds = false,
  }) =>
      'set -e; apk --wait 60 upgrade '
      '${argument(package, pinnedVersion: pinnedVersion)}';

  @override
  String removeCommand(PackageSpec package, PackageScopeTarget target, {bool allowScripts = false}) =>
      'apk --wait 60 del ${shellQuote(package.name)}';

  @override
  String checkCommand(PackageSpec package, PackageScopeTarget target) {
    final name = shellQuote(package.name);
    return 'if apk info -e $name >/dev/null 2>&1; then '
        'apk info -v $name | head -n 1 | sed \'s/^/__KELIVO_INSTALLED__|/\'; '
        'else echo __KELIVO_MISSING__; fi';
  }
}

final class PipPackageManagerAdapter extends _Adapter {
  const PipPackageManagerAdapter();

  @override
  PackageManagerId get id => PackageManagerId.pip;
  @override
  PackageEcosystem get ecosystem => PackageEcosystem.python;
  @override
  Set<String> get requiredCommands => const {'python3'};


  String _prepare(PackageScopeTarget target) =>
      'mkdir -p ${target.shellPath}; '
      'if [ ! -x ${target.shellPath}/bin/python ]; then '
      'python3 -m venv ${target.shellPath}; fi; ';

  @override
  String installCommand(
    PackageSpec package,
    PackageScopeTarget target, {
    String? pinnedVersion,
    bool allowScripts = false,
    bool allowSourceBuilds = false,
  }) {
    final python = '${target.shellPath}/bin/python';
    return '${_prepare(target)}$python -m pip install '
        '--disable-pip-version-check --no-input '
        '${allowSourceBuilds ? '' : '--only-binary=:all: '} '
        '${argument(package, pinnedVersion: pinnedVersion)}';
  }

  @override
  String upgradeCommand(
    PackageSpec package,
    PackageScopeTarget target, {
    String? pinnedVersion,
    bool allowScripts = false,
    bool allowSourceBuilds = false,
  }) {
    final python = '${target.shellPath}/bin/python';
    return '${_prepare(target)}$python -m pip install --upgrade '
        '--disable-pip-version-check --no-input '
        '${allowSourceBuilds ? '' : '--only-binary=:all: '} '
        '${argument(package, pinnedVersion: pinnedVersion)}';
  }

  @override
  String removeCommand(PackageSpec package, PackageScopeTarget target, {bool allowScripts = false}) {
    final python = '${target.shellPath}/bin/python';
    return '${_prepare(target)}$python -m pip uninstall -y ${shellQuote(package.name)}';
  }

  @override
  String checkCommand(PackageSpec package, PackageScopeTarget target) {
    final python = '${target.shellPath}/bin/python';
    final checkName = package.name.split('[').first;
    return 'if [ -x $python ]; then if $python -m pip show ${shellQuote(checkName)} '
        '> /tmp/.kelivo-pip-show 2>/dev/null; then '
        'sed -n \'s/^Version: /__KELIVO_INSTALLED__|/p\' /tmp/.kelivo-pip-show; '
        'else echo __KELIVO_MISSING__; fi; else echo __KELIVO_MISSING__; fi; '
        'rm -f /tmp/.kelivo-pip-show';
  }
}

final class UvPackageManagerAdapter extends _Adapter {
  const UvPackageManagerAdapter();

  @override
  PackageManagerId get id => PackageManagerId.uv;
  @override
  PackageEcosystem get ecosystem => PackageEcosystem.python;
  @override
  Set<String> get requiredCommands => const {'uv', 'python3'};

  String _prepare(PackageScopeTarget target) =>
      'mkdir -p ${target.shellPath}; '
      'if [ ! -x ${target.shellPath}/bin/python ]; then '
      'uv venv ${target.shellPath} --python python3; fi; ';

  String _python(PackageScopeTarget target) =>
      '${target.shellPath}/bin/python';

  @override
  String installCommand(
    PackageSpec package,
    PackageScopeTarget target, {
    String? pinnedVersion,
    bool allowScripts = false,
    bool allowSourceBuilds = false,
  }) =>
      '${_prepare(target)}uv pip install --python ${_python(target)} '
      '${allowSourceBuilds ? '' : '--only-binary=:all: '} '
      '${argument(package, pinnedVersion: pinnedVersion)}';

  @override
  String upgradeCommand(
    PackageSpec package,
    PackageScopeTarget target, {
    String? pinnedVersion,
    bool allowScripts = false,
    bool allowSourceBuilds = false,
  }) =>
      '${_prepare(target)}uv pip install --upgrade --python ${_python(target)} '
      '${allowSourceBuilds ? '' : '--only-binary=:all: '} '
      '${argument(package, pinnedVersion: pinnedVersion)}';

  @override
  String removeCommand(PackageSpec package, PackageScopeTarget target, {bool allowScripts = false}) =>
      '${_prepare(target)}uv pip uninstall --python ${_python(target)} '
      '--yes ${shellQuote(package.name)}';

  @override
  String checkCommand(PackageSpec package, PackageScopeTarget target) =>
      'if [ -x ${_python(target)} ]; then if uv pip show --python ${_python(target)} '
      '${shellQuote(package.name)} >/tmp/.kelivo-uv-show 2>/dev/null; then '
      'sed -n \'s/^Version: /__KELIVO_INSTALLED__|/p\' /tmp/.kelivo-uv-show; '
      'else echo __KELIVO_MISSING__; fi; else echo __KELIVO_MISSING__; fi; '
      'rm -f /tmp/.kelivo-uv-show';
}

abstract base class _NodePackageManagerAdapter extends _Adapter {
  const _NodePackageManagerAdapter();

  String installSpec(PackageSpec package, {String? pinnedVersion}) =>
      shellQuote(package.installArgument(id, pinnedVersion: pinnedVersion));

  String _prepare(PackageScopeTarget target) =>
      'mkdir -p ${target.shellPath}; ';

  String _packagePath(PackageSpec package, PackageScopeTarget target) {
    final relative = 'node_modules/${package.name}';
    final base = target.shellPath;
    if ((base.startsWith('"') && base.endsWith('"')) ||
        (base.startsWith("'") && base.endsWith("'"))) {
      return '${base.substring(0, base.length - 1)}/$relative${base.substring(base.length - 1)}';
    }
    return '$base/$relative';
  }

  @override
  String checkCommand(PackageSpec package, PackageScopeTarget target) {
    final packageFile = '${_packagePath(package, target)}/package.json';
    return 'if [ -f $packageFile ]; then '
        'node -e \'const p=require(process.argv[1]); console.log("__KELIVO_INSTALLED__|"+p.version)\' '
        '$packageFile; else echo __KELIVO_MISSING__; fi';
  }
}

final class NpmPackageManagerAdapter extends _NodePackageManagerAdapter {
  const NpmPackageManagerAdapter();
  @override
  PackageManagerId get id => PackageManagerId.npm;
  @override
  PackageEcosystem get ecosystem => PackageEcosystem.node;
  @override
  Set<String> get requiredCommands => const {'npm', 'node'};

  @override
  String installCommand(
    PackageSpec package,
    PackageScopeTarget target, {
    String? pinnedVersion,
    bool allowScripts = false,
    bool allowSourceBuilds = false,
  }) =>
      '${_prepare(target)}npm install --prefix ${target.shellPath} '
      '--no-audit --no-fund ${allowScripts ? '' : '--ignore-scripts '} ${installSpec(package, pinnedVersion: pinnedVersion)}';

  @override
  String upgradeCommand(
    PackageSpec package,
    PackageScopeTarget target, {
    String? pinnedVersion,
    bool allowScripts = false,
    bool allowSourceBuilds = false,
  }) =>
      '${_prepare(target)}npm install --prefix ${target.shellPath} '
      '--no-audit --no-fund ${allowScripts ? '' : '--ignore-scripts '} ${installSpec(package, pinnedVersion: pinnedVersion ?? 'latest')}';

  @override
  String removeCommand(PackageSpec package, PackageScopeTarget target, {bool allowScripts = false}) =>
      '${_prepare(target)}npm uninstall --prefix ${target.shellPath} ${allowScripts ? '' : '--ignore-scripts '} ${shellQuote(package.name)}';
}

final class PnpmPackageManagerAdapter extends _NodePackageManagerAdapter {
  const PnpmPackageManagerAdapter();
  @override
  PackageManagerId get id => PackageManagerId.pnpm;
  @override
  PackageEcosystem get ecosystem => PackageEcosystem.node;
  @override
  Set<String> get requiredCommands => const {'pnpm', 'node'};

  @override
  String installCommand(
    PackageSpec package,
    PackageScopeTarget target, {
    String? pinnedVersion,
    bool allowScripts = false,
    bool allowSourceBuilds = false,
  }) =>
      '${_prepare(target)}pnpm --dir ${target.shellPath} add '
      '${allowScripts ? '' : '--ignore-scripts '} ${installSpec(package, pinnedVersion: pinnedVersion)}';

  @override
  String upgradeCommand(
    PackageSpec package,
    PackageScopeTarget target, {
    String? pinnedVersion,
    bool allowScripts = false,
    bool allowSourceBuilds = false,
  }) =>
      '${_prepare(target)}pnpm --dir ${target.shellPath} add '
      '${allowScripts ? '' : '--ignore-scripts '} ${installSpec(package, pinnedVersion: pinnedVersion ?? 'latest')}';

  @override
  String removeCommand(PackageSpec package, PackageScopeTarget target, {bool allowScripts = false}) =>
      '${_prepare(target)}pnpm --dir ${target.shellPath} remove ${allowScripts ? '' : '--ignore-scripts '} ${shellQuote(package.name)}';
}

final class YarnPackageManagerAdapter extends _NodePackageManagerAdapter {
  const YarnPackageManagerAdapter();
  @override
  PackageManagerId get id => PackageManagerId.yarn;
  @override
  PackageEcosystem get ecosystem => PackageEcosystem.node;
  @override
  Set<String> get requiredCommands => const {'yarn', 'node'};

  @override
  String installCommand(
    PackageSpec package,
    PackageScopeTarget target, {
    String? pinnedVersion,
    bool allowScripts = false,
    bool allowSourceBuilds = false,
  }) =>
      '${_prepare(target)}YARN_NODE_LINKER=node-modules '
      'YARN_ENABLE_SCRIPTS=${allowScripts ? 'true' : 'false'} '
      'YARN_IGNORE_SCRIPTS=${allowScripts ? 'false' : 'true'} '
      'yarn --cwd ${target.shellPath} add '
      '${installSpec(package, pinnedVersion: pinnedVersion)}';

  @override
  String upgradeCommand(
    PackageSpec package,
    PackageScopeTarget target, {
    String? pinnedVersion,
    bool allowScripts = false,
    bool allowSourceBuilds = false,
  }) =>
      '${_prepare(target)}YARN_NODE_LINKER=node-modules '
      'YARN_ENABLE_SCRIPTS=${allowScripts ? 'true' : 'false'} '
      'YARN_IGNORE_SCRIPTS=${allowScripts ? 'false' : 'true'} '
      'yarn --cwd ${target.shellPath} add '
      '${installSpec(package, pinnedVersion: pinnedVersion ?? 'latest')}';

  @override
  String removeCommand(PackageSpec package, PackageScopeTarget target, {bool allowScripts = false}) =>
      '${_prepare(target)}YARN_NODE_LINKER=node-modules '
      'YARN_ENABLE_SCRIPTS=${allowScripts ? 'true' : 'false'} '
      'YARN_IGNORE_SCRIPTS=${allowScripts ? 'false' : 'true'} '
      'yarn --cwd ${target.shellPath} remove ${shellQuote(package.name)}';
}

final class BunPackageManagerAdapter extends _NodePackageManagerAdapter {
  const BunPackageManagerAdapter();
  @override
  PackageManagerId get id => PackageManagerId.bun;
  @override
  PackageEcosystem get ecosystem => PackageEcosystem.node;
  @override
  Set<String> get requiredCommands => const {'bun', 'node'};

  @override
  String installCommand(
    PackageSpec package,
    PackageScopeTarget target, {
    String? pinnedVersion,
    bool allowScripts = false,
    bool allowSourceBuilds = false,
  }) =>
      '${_prepare(target)}bun --cwd ${target.shellPath} add '
      '${allowScripts ? '' : '--ignore-scripts '} ${installSpec(package, pinnedVersion: pinnedVersion)}';

  @override
  String upgradeCommand(
    PackageSpec package,
    PackageScopeTarget target, {
    String? pinnedVersion,
    bool allowScripts = false,
    bool allowSourceBuilds = false,
  }) =>
      '${_prepare(target)}bun --cwd ${target.shellPath} add '
      '${allowScripts ? '' : '--ignore-scripts '} ${installSpec(package, pinnedVersion: pinnedVersion ?? 'latest')}';

  @override
  String removeCommand(PackageSpec package, PackageScopeTarget target, {bool allowScripts = false}) =>
      '${_prepare(target)}bun --cwd ${target.shellPath} remove ${allowScripts ? '' : '--ignore-scripts '} ${shellQuote(package.name)}';
}

/// Runtime registry for package-manager adapters.
///
/// New application integrations can register an adapter without changing the
/// package operation engine. A Skill archive cannot register executable Dart
/// code or replace a trusted adapter at runtime.
final class PackageManagerAdapterRegistry {
  PackageManagerAdapterRegistry({Iterable<PackageManagerAdapter> adapters = const []}) {
    for (final adapter in adapters) {
      register(adapter);
    }
  }

  final Map<PackageManagerId, PackageManagerAdapter> _adapters = {};

  List<PackageManagerAdapter> get all => List.unmodifiable(_adapters.values);

  PackageManagerAdapter? byId(PackageManagerId id) => _adapters[id];

  void register(PackageManagerAdapter adapter, {bool replace = false}) {
    final existing = _adapters[adapter.id];
    if (existing != null && !replace) {
      throw StateError('package_manager_adapter_already_registered:${adapter.id.name}');
    }
    _adapters[adapter.id] = adapter;
  }
}

abstract final class PackageManagerAdapters {
  static const List<PackageManagerAdapter> all = [
    AptPackageManagerAdapter(),
    ApkPackageManagerAdapter(),
    PipPackageManagerAdapter(),
    UvPackageManagerAdapter(),
    NpmPackageManagerAdapter(),
    PnpmPackageManagerAdapter(),
    YarnPackageManagerAdapter(),
    BunPackageManagerAdapter(),
  ];

  static PackageManagerAdapterRegistry createRegistry() =>
      PackageManagerAdapterRegistry(adapters: all);

  /// Compatibility lookup for tests and existing app callers.
  static PackageManagerAdapter? byId(PackageManagerId id) =>
      createRegistry().byId(id);
}

String get packageManagerDetectionScript => r'''
for command_name in apt-get dpkg-query apk python3 uv npm pnpm yarn bun node; do
  if command -v "$command_name" >/dev/null 2>&1; then
    printf '__KELIVO_PM_COMMAND__|%s\n' "$command_name"
  fi
done
printf '__KELIVO_PM_ARCH__|%s\n' "$(uname -m 2>/dev/null || echo unknown)"
''';

PackageManagerId resolvePackageManager({
  required PackageManagerId requested,
  required PackageEcosystem? manifestEcosystem,
  required String? distro,
  required PackageManagerAvailability availability,
  String? nodeLockfile,
}) {
  if (requested != PackageManagerId.auto) return requested;
  if (manifestEcosystem == PackageEcosystem.python) {
    if (availability.has('uv')) return PackageManagerId.uv;
    if (availability.has('python3')) return PackageManagerId.pip;
  }
  if (manifestEcosystem == PackageEcosystem.node) {
    final fromLock = switch (nodeLockfile) {
      'pnpm-lock.yaml' => PackageManagerId.pnpm,
      'yarn.lock' => PackageManagerId.yarn,
      'bun.lock' || 'bun.lockb' => PackageManagerId.bun,
      'package-lock.json' => PackageManagerId.npm,
      _ => null,
    };
    if (fromLock != null) return fromLock;
    if (availability.has('pnpm')) return PackageManagerId.pnpm;
    if (availability.has('yarn')) return PackageManagerId.yarn;
    if (availability.has('bun')) return PackageManagerId.bun;
    if (availability.has('npm')) return PackageManagerId.npm;
  }
  return switch (distro?.toLowerCase()) {
    'alpine' when availability.has('apk') => PackageManagerId.apk,
    'ubuntu' || 'debian' when availability.has('apt-get') =>
      PackageManagerId.apt,
    _ => PackageManagerId.auto,
  };
}
