/// A dependency requirement declared by a Skill, project, or other runtime
/// owner. This type is intentionally independent of any bundled Skill.
final class DependencyClaim {
  const DependencyClaim({
    required this.ownerId,
    required this.packageName,
    required this.ecosystem,
    required this.isolationKey,
    this.manager,
    this.versionConstraint,
    this.sourcePath,
    this.sourceLine,
  });

  final String ownerId;
  final String packageName;
  final String ecosystem;
  /// Identifies the actual package root. Use `profile:<id>` for isolated
  /// Python/Node roots and a shared key for global PRoot/system dependencies.
  final String isolationKey;
  final String? manager;
  /// Exact versions are compared conservatively. Ranges are preserved but are
  /// never interpreted as compatible without a manager-specific resolver.
  final String? versionConstraint;
  final String? sourcePath;
  final int? sourceLine;

  String get normalizedPackageName => packageName.trim().toLowerCase();

  Map<String, Object?> toJson() => <String, Object?>{
    'ownerId': ownerId,
    'packageName': packageName,
    'ecosystem': ecosystem,
    'isolationKey': isolationKey,
    if (manager != null) 'manager': manager,
    if (versionConstraint != null) 'versionConstraint': versionConstraint,
    if (sourcePath != null) 'sourcePath': sourcePath,
    if (sourceLine != null) 'sourceLine': sourceLine,
  };
}

final class DependencyConflict {
  const DependencyConflict({
    required this.packageName,
    required this.ecosystem,
    required this.isolationKey,
    required this.claims,
    required this.reason,
  });

  final String packageName;
  final String ecosystem;
  final String isolationKey;
  final List<DependencyClaim> claims;
  final String reason;

  Map<String, Object?> toJson() => <String, Object?>{
    'packageName': packageName,
    'ecosystem': ecosystem,
    'isolationKey': isolationKey,
    'reason': reason,
    'claims': claims.map((claim) => claim.toJson()).toList(growable: false),
  };
}

final class DependencyResolution {
  const DependencyResolution({
    required this.conflicts,
    required this.unresolvedConstraints,
    required this.dependencyGroups,
  });

  final List<DependencyConflict> conflicts;
  final List<Map<String, Object?>> unresolvedConstraints;
  final int dependencyGroups;

  bool get isConflictFree => conflicts.isEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
    'isConflictFree': isConflictFree,
    'conflictCount': conflicts.length,
    'unresolvedConstraintCount': unresolvedConstraints.length,
    'dependencyGroups': dependencyGroups,
    'conflicts': conflicts.map((item) => item.toJson()).toList(growable: false),
    'unresolvedConstraints': unresolvedConstraints,
  };
}

/// Detects package conflicts only when requirements target the same real
/// package root. Different Runtime Profiles are intentionally independent.
/// This resolver does not guess semantic compatibility for version ranges;
/// those require the selected ecosystem's native package manager.
abstract final class DependencyResolver {
  static DependencyResolution resolve(Iterable<DependencyClaim> input) {
    final claims = input.toList(growable: false);
    final groups = <String, List<DependencyClaim>>{};
    for (final claim in claims) {
      final package = claim.normalizedPackageName;
      final ecosystem = claim.ecosystem.trim().toLowerCase();
      final isolation = claim.isolationKey.trim();
      if (package.isEmpty || ecosystem.isEmpty || isolation.isEmpty) continue;
      final key = '$isolation\u0000$ecosystem\u0000$package';
      groups.putIfAbsent(key, () => <DependencyClaim>[]).add(claim);
    }

    final conflicts = <DependencyConflict>[];
    final unresolved = <Map<String, Object?>>[];
    for (final group in groups.values) {
      if (group.length < 2) continue;
      final exactVersions = group
          .map((claim) => claim.versionConstraint?.trim())
          .whereType<String>()
          .where((value) => value.isNotEmpty && _isExactVersion(value))
          .toSet();
      final managers = group
          .map((claim) => claim.manager?.trim().toLowerCase())
          .whereType<String>()
          .where((value) => value.isNotEmpty)
          .toSet();
      final first = group.first;
      if (exactVersions.length > 1) {
        conflicts.add(DependencyConflict(
          packageName: first.packageName,
          ecosystem: first.ecosystem,
          isolationKey: first.isolationKey,
          claims: List.unmodifiable(group),
          reason: 'incompatible_exact_versions',
        ));
      } else if (managers.length > 1) {
        conflicts.add(DependencyConflict(
          packageName: first.packageName,
          ecosystem: first.ecosystem,
          isolationKey: first.isolationKey,
          claims: List.unmodifiable(group),
          reason: 'multiple_package_managers_for_same_root',
        ));
      } else if (group.any((claim) {
        final value = claim.versionConstraint?.trim();
        return value != null && value.isNotEmpty && !_isExactVersion(value);
      })) {
        unresolved.add(<String, Object?>{
          'packageName': first.packageName,
          'ecosystem': first.ecosystem,
          'isolationKey': first.isolationKey,
          'reason': 'version_ranges_require_native_resolver',
          'claims': group.map((claim) => claim.toJson()).toList(growable: false),
        });
      }
    }

    return DependencyResolution(
      conflicts: List.unmodifiable(conflicts),
      unresolvedConstraints: List.unmodifiable(unresolved),
      dependencyGroups: groups.length,
    );
  }

  static bool _isExactVersion(String value) =>
      RegExp(r'^[0-9]+(?:\.[0-9A-Za-z_-]+){0,5}(?:\+[0-9A-Za-z_.-]+)?$')
          .hasMatch(value);
}
