import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/skills/skill_compatibility.dart';
import 'package:Kelivo/core/services/skills/skill_frontmatter.dart';

void main() {
  test('warns when a Skill references companion files missing from the source', () {
    final parsed = SkillFrontmatter.parse('''
---
name: incomplete-skill
description: A Skill with missing companion references.
---
Read `rubric.json` and `hooks.json`, run `scripts/normalize_env.py` and `scripts/preview.mjs`, and consult
`references/production-guide.md` before continuing.
''');
    final report = SkillCompatibilityAnalyzer.analyze(
      parsed,
      directoryName: 'incomplete-skill',
      files: const <String>['SKILL.md', 'scripts/present.py'],
    );
    expect(report.isImportable, isTrue);
    expect(report.level, SkillCompatibilityLevel.warnings);
    final warnings = report.warnings.join(' ');
    expect(warnings, contains('rubric.json'));
    expect(warnings, contains('hooks.json'));
    expect(warnings, contains('scripts/normalize_env.py'));
    expect(warnings, contains('scripts/preview.mjs'));
    expect(warnings, contains('references/production-guide.md'));
  });

  test('does not warn for project state and generated asset paths', () {
    final parsed = SkillFrontmatter.parse('''
---
name: project-output-skill
description: A Skill that creates project files.
---
Read `PROGRESS.md` and `LOG.md`, then write `manifest.json` and
`assets/vo/vo_v1.mp3`, `channel.json`, `hooks.txt` and `script.txt` as project outputs.
''');
    final report = SkillCompatibilityAnalyzer.analyze(
      parsed,
      directoryName: 'project-output-skill',
      files: const <String>['SKILL.md'],
    );
    expect(
      report.warnings.where((warning) => warning.contains('local companion files')),
      isEmpty,
    );
  });

  test('does not warn for relative companion files that are present', () {
    final parsed = SkillFrontmatter.parse('''
---
name: complete-skill
description: A Skill with complete companion files.
---
Read `rubric.json` and run `scripts/normalize_env.py`.
''');
    final report = SkillCompatibilityAnalyzer.analyze(
      parsed,
      directoryName: 'complete-skill',
      files: const <String>[
        'SKILL.md',
        'rubric.json',
        'scripts/normalize_env.py',
      ],
    );
    expect(
      report.warnings.where((warning) => warning.contains('local companion files')),
      isEmpty,
    );
  });
}
