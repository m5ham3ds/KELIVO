import 'package:path/path.dart' as p;

/// Package operation scopes supported by the runtime package manager.
enum PackageScope { runtime, project, extension, task }

enum PackageAction { plan, check, install, upgrade, remove, pin, unpin, list }

enum PackageManagerId { auto, apt, apk, pip, uv, npm, pnpm, yarn, bun }

enum PackageEcosystem { system, python, node }

extension PackageScopeName on PackageScope {
  static PackageScope parse(Object? value) {
    if (value == null || value == 'runtime' || value == 'global') {
      return PackageScope.runtime;
    }
    for (final item in PackageScope.values) {
      if (item.name == value) return item;
    }
    throw const FormatException('invalid_package_scope');
  }
}

extension PackageActionName on PackageAction {
  static PackageAction parse(Object? value) {
    if (value == null) return PackageAction.plan;
    for (final item in PackageAction.values) {
      if (item.name == value) return item;
    }
    throw const FormatException('invalid_package_action');
  }
}

extension PackageManagerIdName on PackageManagerId {
  static PackageManagerId parse(Object? value) {
    if (value == null || value == 'auto') return PackageManagerId.auto;
    for (final item in PackageManagerId.values) {
      if (item.name == value) return item;
    }
    throw const FormatException('invalid_package_manager');
  }
}

/// User-supplied package identifiers are parsed before they reach a shell.
/// Only registry package names and exact versions are accepted in this phase;
/// URLs, VCS references, shell flags and arbitrary install arguments are not.
class PackageSpec {
  const PackageSpec({required this.name, this.version});

  final String name;
  final String? version;

  String get normalizedName => name.toLowerCase();

  static PackageSpec fromJson(Object? value) {
    if (value is String) return PackageSpec(name: value.trim());
    if (value is Map) {
      return PackageSpec(
        name: (value['name'] ?? '').toString().trim(),
        version: (value['version'] as String?)?.trim(),
      );
    }
    throw const FormatException('package_entry_must_be_string_or_object');
  }

  String? validate(PackageManagerId manager) {
    final packageName = name.trim();
    if (packageName.isEmpty || packageName.length > 214) {
      return 'invalid_package_name';
    }
    final validName = switch (manager) {
      PackageManagerId.apt || PackageManagerId.apk =>
        RegExp(r'^[a-z0-9][a-z0-9+.-]*$').hasMatch(packageName),
      PackageManagerId.pip || PackageManagerId.uv =>
        RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*(?:\[[A-Za-z0-9_,.-]+\])?$')
            .hasMatch(packageName),
      PackageManagerId.npm ||
      PackageManagerId.pnpm ||
      PackageManagerId.yarn ||
      PackageManagerId.bun => RegExp(
        r'^(?:@[a-z0-9._-]+/)?[a-z0-9][a-z0-9._-]*$',
      ).hasMatch(packageName),
      PackageManagerId.auto => false,
    };
    if (!validName) return 'invalid_package_name';
    final pin = version?.trim();
    if (pin != null && pin.isNotEmpty &&
        (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9.+_~:-]{0,63}$').hasMatch(pin) ||
            const {'latest', 'next', 'beta', 'stable', 'default'}.contains(pin.toLowerCase()))) {
      return 'invalid_exact_version';
    }
    return null;
  }

  String installArgument(PackageManagerId manager, {String? pinnedVersion}) {
    final exact = version ?? pinnedVersion;
    return switch (manager) {
      PackageManagerId.apt || PackageManagerId.apk =>
        exact == null ? name : '$name=$exact',
      PackageManagerId.pip || PackageManagerId.uv =>
        exact == null ? name : '$name==$exact',
      PackageManagerId.npm ||
      PackageManagerId.pnpm ||
      PackageManagerId.yarn ||
      PackageManagerId.bun => exact == null ? name : '$name@$exact',
      PackageManagerId.auto => throw StateError('manager_not_resolved'),
    };
  }

  Map<String, Object?> toJson() => {
    'name': name,
    if (version != null) 'version': version,
  };
}

/// A resolved, validated destination. Shell expressions are generated only
/// from fixed path templates and validated scope identifiers.
class PackageScopeTarget {
  const PackageScopeTarget({
    required this.scope,
    required this.key,
    required this.displayPath,
    required this.shellPath,
    required this.cwd,
    required this.lockfileShellPath,
    this.workspaceId,
    this.profileId,
  });

  final PackageScope scope;
  final String key;
  final String displayPath;
  final String shellPath;
  final String cwd;
  final String lockfileShellPath;
  final String? workspaceId;
  final String? profileId;

  static bool isSafeScopeId(String value) =>
      RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$').hasMatch(value);

  static PackageScopeTarget runtime(PackageEcosystem ecosystem) {
    final suffix = ecosystem.name;
    final root = r'"$HOME/.local/share/kelivo/packages/runtime"';
    return PackageScopeTarget(
      scope: PackageScope.runtime,
      key: 'runtime:$suffix',
      displayPath: '~/.local/share/kelivo/packages/runtime/$suffix',
      shellPath: '$root/$suffix',
      cwd: '/',
      lockfileShellPath: '"\$HOME/.local/share/kelivo/package-locks/runtime/$suffix/dependencies.lock.json"',
    );
  }

  static PackageScopeTarget project({
    required String workspaceId,
    required String workspaceRoot,
    required bool sandboxed,
    required PackageEcosystem ecosystem,
    String? profileId,
  }) {
    final suffix = ecosystem.name;
    if (profileId != null && !isSafeScopeId(profileId)) {
      throw const FormatException('invalid_runtime_profile_id');
    }
    final base = sandboxed
        ? (profileId == null
            ? p.posix.join(workspaceRoot, '.kelivo', 'packages', suffix)
            : p.posix.join(workspaceRoot, '.kelivo', 'runtime-profiles', profileId, suffix))
        : (profileId == null
            ? p.join(workspaceRoot, '.kelivo', 'packages', suffix)
            : p.join(workspaceRoot, '.kelivo', 'runtime-profiles', profileId, suffix));
    final lock = sandboxed
        ? p.posix.join(workspaceRoot, '.kelivo', profileId == null ? 'dependencies.$suffix.lock.json' : 'runtime-profiles/$profileId/dependencies.$suffix.lock.json')
        : p.join(workspaceRoot, '.kelivo', profileId == null ? 'dependencies.$suffix.lock.json' : 'runtime-profiles/$profileId/dependencies.$suffix.lock.json');
    return PackageScopeTarget(
      scope: PackageScope.project,
      key: profileId == null
          ? 'project:$workspaceId:$suffix'
          : 'project:$workspaceId:profile:$profileId:$suffix',
      workspaceId: workspaceId,
      profileId: profileId,
      displayPath: base,
      shellPath: _shellQuote(base),
      cwd: workspaceRoot,
      lockfileShellPath: _shellQuote(lock),
    );
  }

  static PackageScopeTarget extension(
    String id,
    PackageEcosystem ecosystem, {
    String? profileId,
  }) {
    if (!isSafeScopeId(id)) throw const FormatException('invalid_extension_id');
    if (profileId != null && !isSafeScopeId(profileId)) {
      throw const FormatException('invalid_runtime_profile_id');
    }
    final suffix = ecosystem.name;
    final base = r'"$HOME/.local/share/kelivo/packages/extensions"';
    final root = profileId == null
        ? '$base/${_shellQuote(id)}/$suffix'
        : r'"$HOME/.local/share/kelivo/runtime-profiles/extensions"/${_shellQuote(id)}/${_shellQuote(profileId)}/$suffix';
    final lock = profileId == null
        ? '$base/${_shellQuote(id)}/$suffix/dependencies.lock.json'
        : '$root/dependencies.lock.json';
    return PackageScopeTarget(
      scope: PackageScope.extension,
      key: profileId == null
          ? 'extension:$id:$suffix'
          : 'extension:$id:profile:$profileId:$suffix',
      profileId: profileId,
      displayPath: profileId == null
          ? '~/.local/share/kelivo/packages/extensions/$id/$suffix'
          : '~/.local/share/kelivo/runtime-profiles/extensions/$id/$profileId/$suffix',
      shellPath: root,
      cwd: '/',
      lockfileShellPath: lock,
    );
  }

  static PackageScopeTarget task(
    String id,
    PackageEcosystem ecosystem, {
    String? profileId,
  }) {
    if (!isSafeScopeId(id)) throw const FormatException('invalid_task_id');
    if (profileId != null && !isSafeScopeId(profileId)) {
      throw const FormatException('invalid_runtime_profile_id');
    }
    final suffix = ecosystem.name;
    final base = r'"$HOME/.local/share/kelivo/packages/tasks"';
    final root = profileId == null
        ? '$base/${_shellQuote(id)}/$suffix'
        : r'"$HOME/.local/share/kelivo/runtime-profiles/tasks"/${_shellQuote(id)}/${_shellQuote(profileId)}/$suffix';
    final lock = profileId == null
        ? '$base/${_shellQuote(id)}/$suffix/dependencies.lock.json'
        : '$root/dependencies.lock.json';
    return PackageScopeTarget(
      scope: PackageScope.task,
      key: profileId == null
          ? 'task:$id:$suffix'
          : 'task:$id:profile:$profileId:$suffix',
      profileId: profileId,
      displayPath: profileId == null
          ? '~/.local/share/kelivo/packages/tasks/$id/$suffix'
          : '~/.local/share/kelivo/runtime-profiles/tasks/$id/$profileId/$suffix',
      shellPath: root,
      cwd: '/',
      lockfileShellPath: lock,
    );
  }

  static String _shellQuote(String value) =>
      "'${value.replaceAll("'", "'\\''")}'";
}

class PackageManagerAvailability {
  const PackageManagerAvailability({
    required this.commands,
    required this.distro,
    required this.architecture,
  });

  final Set<String> commands;
  final String? distro;
  final String? architecture;

  bool has(String command) => commands.contains(command);
}

class PackageManifest {
  const PackageManifest({
    required this.kind,
    required this.packages,
    this.warnings = const [],
    this.manager,
  });

  final PackageEcosystem kind;
  final PackageManagerId? manager;
  final List<PackageSpec> packages;
  final List<String> warnings;
}

class PackageLedgerEntry {
  const PackageLedgerEntry({
    required this.scopeKey,
    required this.manager,
    required this.name,
    required this.installedVersion,
    required this.updatedAt,
    this.pinnedVersion,
    this.status = 'installed',
    this.sourceManifest,
  });

  final String scopeKey;
  final String manager;
  final String name;
  final String? installedVersion;
  final String? pinnedVersion;
  final String status;
  final String? sourceManifest;
  final DateTime updatedAt;

  PackageLedgerEntry copyWith({
    String? installedVersion,
    String? pinnedVersion,
    bool clearPinnedVersion = false,
    String? status,
    String? sourceManifest,
    bool clearSourceManifest = false,
    DateTime? updatedAt,
  }) => PackageLedgerEntry(
    scopeKey: scopeKey,
    manager: manager,
    name: name,
    installedVersion: installedVersion ?? this.installedVersion,
    pinnedVersion: clearPinnedVersion
        ? null
        : (pinnedVersion ?? this.pinnedVersion),
    status: status ?? this.status,
    sourceManifest: clearSourceManifest
        ? null
        : (sourceManifest ?? this.sourceManifest),
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toJson() => {
    'scopeKey': scopeKey,
    'manager': manager,
    'name': name,
    'installedVersion': installedVersion,
    'pinnedVersion': pinnedVersion,
    'status': status,
    'sourceManifest': sourceManifest,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory PackageLedgerEntry.fromJson(Map<String, Object?> json) =>
      PackageLedgerEntry(
        scopeKey: json['scopeKey'] as String,
        manager: json['manager'] as String,
        name: json['name'] as String,
        installedVersion: json['installedVersion'] as String?,
        pinnedVersion: json['pinnedVersion'] as String?,
        status: json['status'] as String? ?? 'installed',
        sourceManifest: json['sourceManifest'] as String?,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

String shellQuote(String value) =>
    "'${value.replaceAll("'", "'\\''")}'";
