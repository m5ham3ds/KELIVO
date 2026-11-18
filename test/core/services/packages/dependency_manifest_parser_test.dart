import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/packages/dependency_manifest_parser.dart';
import 'package:Kelivo/core/services/packages/package_manager_models.dart';

void main() {
  test('reads exact Python requirements and warns for ranges', () {
    final manifest = DependencyManifestParser.parse('requirements.txt', '''
requests==2.32.3
beautifulsoup4>=4.12
-r private.txt
https://example.test/pkg.whl
''');

    expect(manifest.kind, PackageEcosystem.python);
    expect(manifest.packages, hasLength(2));
    expect(manifest.packages.first.name, 'requests');
    expect(manifest.packages.first.version, '2.32.3');
    expect(manifest.packages.last.version, isNull);
    expect(manifest.warnings, contains('version_range_not_locked:beautifulsoup4'));
    expect(manifest.warnings, contains('ignored_non_registry_requirement'));
  });

  test('reads Node dependencies and does not follow registry or git URLs', () {
    final manifest = DependencyManifestParser.parse('package.json', '''
{
  "dependencies": {
    "typescript": "5.6.3",
    "@scope/tool": "^2.1.0",
    "bad-url": "https://example.test/pkg.tgz",
    "git-tool": "git+https://example.test/repo.git"
  }
}
''');

    expect(manifest.kind, PackageEcosystem.node);
    expect(manifest.packages.map((item) => item.name), ['typescript']);
    expect(manifest.packages.single.version, '5.6.3');
    expect(manifest.warnings, contains('version_range_not_locked:@scope/tool'));
    expect(manifest.warnings, contains('ignored_non_registry_package:bad-url'));
    expect(manifest.warnings, contains('ignored_non_registry_package:git-tool'));
  });

  test('parses exact Skill metadata for Python packages', () {
    final manifest = DependencyManifestParser.parseSkillMetadata({
      'kelivo.package-manager': 'uv',
      'kelivo.packages': 'requests==2.32.3, beautifulsoup4==4.12.3',
    });

    expect(manifest.kind, PackageEcosystem.python);
    expect(manifest.manager, PackageManagerId.uv);
    expect(manifest.packages.map((item) => item.version), [
      '2.32.3',
      '4.12.3',
    ]);
    expect(manifest.warnings, isEmpty);
  });

  test('parses scoped Node package metadata using the final version separator', () {
    final manifest = DependencyManifestParser.parseSkillMetadata({
      'kelivo.package-manager': 'pnpm',
      'kelivo.packages': '@openai/agents@0.2.4,typescript@5.6.3',
    });

    expect(manifest.kind, PackageEcosystem.node);
    expect(manifest.manager, PackageManagerId.pnpm);
    expect(manifest.packages.map((item) => item.name), [
      '@openai/agents',
      'typescript',
    ]);
    expect(manifest.packages.map((item) => item.version), ['0.2.4', '5.6.3']);
  });

  test('reports unpinned Skill packages as actionable version warnings', () {
    final manifest = DependencyManifestParser.parseSkillMetadata({
      'kelivo.package-manager': 'pip',
      'kelivo.packages': 'requests,beautifulsoup4==4.12.3',
    });
    expect(manifest.warnings, contains('version_range_not_locked:requests'));
  });

  test('requires an explicit package manager and package list in Skill metadata', () {
    expect(
      () => DependencyManifestParser.parseSkillMetadata({
        'kelivo.packages': 'requests==2.32.3',
      }),
      throwsFormatException,
    );
    expect(
      () => DependencyManifestParser.parseSkillMetadata({
        'kelivo.package-manager': 'auto',
        'kelivo.packages': 'requests==2.32.3',
      }),
      throwsFormatException,
    );
  });

  test('rejects shell options and URL-like package metadata', () {
    expect(
      () => DependencyManifestParser.parseSkillMetadata({
        'kelivo.package-manager': 'npm',
        'kelivo.packages': '--registry=https://evil.test',
      }),
      throwsFormatException,
    );
  });
}
