import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/skills/github_skill_ref.dart';

void main() {
  test('parses direct GitHub blob links to .skill files without converting them into folder URLs', () {
    final ref = GitHubSkillRef.parse(
      'https://github.com/m5ham3ds/REELSMOSHAN/blob/main/character-visual-director.skill',
    );
    expect(ref.owner, 'm5ham3ds');
    expect(ref.repo, 'REELSMOSHAN');
    expect(ref.ref, 'main');
    expect(ref.subdir, isNull);
    expect(ref.filePath, 'character-visual-director.skill');
  });

  test('parses direct GitHub ZIP and raw file links', () {
    final blob = GitHubSkillRef.parse(
      'https://github.com/acme/skills/blob/v1/bundles/skills.zip',
    );
    expect(blob.filePath, 'bundles/skills.zip');
    expect(blob.subdir, isNull);

    final raw = GitHubSkillRef.parse(
      'https://raw.githubusercontent.com/acme/skills/main/skills/demo.skill',
    );
    expect(raw.filePath, 'skills/demo.skill');
    expect(raw.subdir, isNull);
  });

  test('keeps SKILL.md blob links as Skill-folder references', () {
    final ref = GitHubSkillRef.parse(
      'https://github.com/acme/skills/blob/main/skills/demo/SKILL.md',
    );
    expect(ref.filePath, isNull);
    expect(ref.subdir, 'skills/demo');
  });

  test('rejects literal and encoded traversal in direct file references', () {
    const unsafeUrls = <String>[
      'https://github.com/acme/skills/blob/main/skills/../outside.skill',
      'https://github.com/acme/skills/blob/main/skills/%2e%2e/outside.skill',
      'https://github.com/acme/skills/blob/main/skills/%2E./outside.skill',
      'https://github.com/acme/skills/blob/main/skills/%252e%252e/outside.skill',
      'https://github.com/acme/skills/blob/main/skills/%2f..%2foutside.skill',
      'https://github.com/acme/skills/blob/main/skills/%5c..%5coutside.skill',
      'https://github.com/acme/skills/blob/main/skills/%25252e%25252e/outside.skill',
    ];

    for (final url in unsafeUrls) {
      expect(
        () => GitHubSkillRef.parse(url),
        throwsFormatException,
        reason: 'Unsafe GitHub path must be rejected: $url',
      );
    }
  });

  test('accepts ordinary dotted and percent-encoded filenames', () {
    final dotted = GitHubSkillRef.parse(
      'https://github.com/acme/skills/blob/main/character..director.skill',
    );
    expect(dotted.filePath, 'character..director.skill');

    final spaced = GitHubSkillRef.parse(
      'https://github.com/acme/skills/blob/main/my%20skill.skill',
    );
    expect(spaced.filePath, 'my skill.skill');
  });
}
