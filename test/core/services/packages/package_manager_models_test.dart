import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/packages/package_manager_models.dart';

void main() {
  test('validates package names and rejects shell or URL references', () {
    expect(const PackageSpec(name: 'requests').validate(PackageManagerId.pip), isNull);
    expect(const PackageSpec(name: '@scope/tool').validate(PackageManagerId.npm), isNull);
    expect(const PackageSpec(name: 'ffmpeg').validate(PackageManagerId.apt), isNull);
    expect(const PackageSpec(name: '--index-url=https://evil').validate(PackageManagerId.pip), isNotNull);
    expect(const PackageSpec(name: 'https://example.test/pkg').validate(PackageManagerId.npm), isNotNull);
  });

  test('only exact package versions are accepted as pins', () {
    expect(const PackageSpec(name: 'requests', version: '2.32.3').validate(PackageManagerId.pip), isNull);
    expect(const PackageSpec(name: 'requests', version: '^2.32').validate(PackageManagerId.pip), isNotNull);
    expect(const PackageSpec(name: 'requests', version: 'latest').validate(PackageManagerId.pip), isNotNull);
  });

  test('scope identifiers reject traversal and shell metacharacters', () {
    expect(PackageScopeTarget.isSafeScopeId('my-extension_1'), isTrue);
    expect(PackageScopeTarget.isSafeScopeId('../outside'), isFalse);
    expect(PackageScopeTarget.isSafeScopeId('$(touch-file)'), isFalse);
  });

  test('runtime and project targets isolate lockfiles by ecosystem', () {
    final runtimePython = PackageScopeTarget.runtime(PackageEcosystem.python);
    final runtimeNode = PackageScopeTarget.runtime(PackageEcosystem.node);
    final projectPython = PackageScopeTarget.project(
      workspaceId: 'demo',
      workspaceRoot: '/workspace/demo',
      sandboxed: false,
      ecosystem: PackageEcosystem.python,
    );
    final projectNode = PackageScopeTarget.project(
      workspaceId: 'demo',
      workspaceRoot: '/workspace/demo',
      sandboxed: false,
      ecosystem: PackageEcosystem.node,
    );
    expect(runtimePython.key, isNot(runtimeNode.key));
    expect(runtimePython.lockfileShellPath, isNot(runtimeNode.lockfileShellPath));
    expect(projectPython.key, isNot(projectNode.key));
    expect(projectPython.lockfileShellPath, isNot(projectNode.lockfileShellPath));
  });

  test('extension and task package targets are isolated by identifier and ecosystem', () {
    final extension = PackageScopeTarget.extension('pdf-skill', PackageEcosystem.python);
    final task = PackageScopeTarget.task('task-42', PackageEcosystem.node);

    expect(extension.key, 'extension:pdf-skill:python');
    expect(extension.displayPath, contains('/extensions/pdf-skill/python'));
    expect(task.key, 'task:task-42:node');
    expect(task.displayPath, contains('/tasks/task-42/node'));
    expect(() => PackageScopeTarget.extension('../unsafe', PackageEcosystem.node), throwsFormatException);
  });
}
