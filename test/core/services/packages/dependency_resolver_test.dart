import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/packages/dependency_resolver.dart';

void main() {
  test('allows different versions in isolated Runtime Profiles', () {
    final result = DependencyResolver.resolve(const [
      DependencyClaim(
        ownerId: 'skill-a',
        packageName: 'requests',
        ecosystem: 'python',
        isolationKey: 'profile:profile-a',
        manager: 'pip',
        versionConstraint: '2.31.0',
      ),
      DependencyClaim(
        ownerId: 'skill-b',
        packageName: 'Requests',
        ecosystem: 'python',
        isolationKey: 'profile:profile-b',
        manager: 'pip',
        versionConstraint: '2.32.0',
      ),
    ]);

    expect(result.isConflictFree, isTrue);
    expect(result.dependencyGroups, 2);
  });

  test('reports exact version conflicts inside the same package root', () {
    final result = DependencyResolver.resolve(const [
      DependencyClaim(
        ownerId: 'skill-a',
        packageName: 'requests',
        ecosystem: 'python',
        isolationKey: 'profile:shared-profile',
        manager: 'pip',
        versionConstraint: '2.31.0',
        sourcePath: 'requirements.txt',
        sourceLine: 4,
      ),
      DependencyClaim(
        ownerId: 'skill-b',
        packageName: 'requests',
        ecosystem: 'python',
        isolationKey: 'profile:shared-profile',
        manager: 'pip',
        versionConstraint: '2.32.0',
      ),
    ]);

    expect(result.isConflictFree, isFalse);
    expect(result.conflicts.single.reason, 'incompatible_exact_versions');
    expect(result.conflicts.single.claims.first.sourceLine, 4);
  });

  test('does not guess compatibility for version ranges', () {
    final result = DependencyResolver.resolve(const [
      DependencyClaim(
        ownerId: 'skill-a',
        packageName: 'urllib3',
        ecosystem: 'python',
        isolationKey: 'profile:shared-profile',
        manager: 'pip',
        versionConstraint: '>=2.0,<3.0',
      ),
      DependencyClaim(
        ownerId: 'skill-b',
        packageName: 'urllib3',
        ecosystem: 'python',
        isolationKey: 'profile:shared-profile',
        manager: 'pip',
        versionConstraint: '>=2.1,<3.0',
      ),
    ]);

    expect(result.conflicts, isEmpty);
    expect(result.unresolvedConstraints.single['reason'], 'version_ranges_require_native_resolver');
  });
}
