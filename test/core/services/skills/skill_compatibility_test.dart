import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/skills/skill_compatibility.dart';
import 'package:Kelivo/core/services/skills/skill_frontmatter.dart';

void main() {
  test('recognizes a standard Agent Skill with optional fields', () {
    final parsed = SkillFrontmatter.parse('''
---
name: file-reader
description: Read common office documents.
license: MIT
compatibility: Android and desktop compatible.
metadata:
  author: kelivo-tests
  version: "1.0"
allowed-tools: Read
---
# File Reader
''');
    final report = SkillCompatibilityAnalyzer.analyze(
      parsed,
      directoryName: 'file-reader',
      files: const ['SKILL.md', 'references/formats.md', 'assets/sample.txt'],
    );
    expect(report.level, SkillCompatibilityLevel.warnings);
    expect(report.isImportable, isTrue);
    expect(report.errors, isEmpty);
    expect(report.standardFields, containsAll([
      'name', 'description', 'license', 'compatibility', 'metadata', 'allowed-tools',
    ]));
    expect(report.warnings, isNotEmpty); // allowed-tools is preserved, not executed.
  });

  test('flags platform-specific plugin configuration without deleting it', () {
    final parsed = SkillFrontmatter.parse('''
---
name: mixed-platform-skill
description: A Skill with additional plugin metadata.
---
Instructions.
''');
    final report = SkillCompatibilityAnalyzer.analyze(
      parsed,
      directoryName: 'mixed-platform-skill',
      files: const ['SKILL.md', '.claude-plugin/plugin.json', 'scripts/run.py'],
    );
    expect(report.level, SkillCompatibilityLevel.warnings);
    expect(report.unsupportedExtensions, contains('.claude-plugin/plugin.json'));
    expect(report.warnings.join(' '), contains('preserved'));
  });



  test('rejects malformed standard frontmatter', () {
    final parsed = SkillFrontmatter.parse('''
---
name: Invalid Name
description: ''
---
''');
    final report = SkillCompatibilityAnalyzer.analyze(parsed);
    expect(report.level, SkillCompatibilityLevel.unsupported);
    expect(report.isImportable, isFalse);
    expect(report.errors, isNotEmpty);
  });
}
