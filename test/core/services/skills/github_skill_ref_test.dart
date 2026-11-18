import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/skills/github_skill_ref.dart';

void main() {
  test('parses repository root and default branch', () {
    final ref = GitHubSkillRef.parse('https://github.com/acme/agent-skills');
    expect(ref.owner, 'acme');
    expect(ref.repo, 'agent-skills');
    expect(ref.ref, isNull);
    expect(ref.subdir, isNull);
  });

  test('parses Skill subfolder and blob SKILL.md URLs', () {
    final tree = GitHubSkillRef.parse(
      'https://github.com/acme/agent-skills/tree/main/skills/pdf-tools',
    );
    expect(tree.ref, 'main');
    expect(tree.subdir, 'skills/pdf-tools');

    final blob = GitHubSkillRef.parse(
      'https://github.com/acme/agent-skills/blob/v1/skills/pdf-tools/SKILL.md',
    );
    expect(blob.ref, 'v1');
    expect(blob.subdir, 'skills/pdf-tools');
  });

  test('supports branch names containing slashes through ref query', () {
    final ref = GitHubSkillRef.parse(
      'https://github.com/acme/agent-skills/tree/main/skills/pdf-tools?ref=feature/import-flow',
    );
    expect(ref.ref, 'feature/import-flow');
    expect(ref.subdir, 'skills/pdf-tools');
  });

  test('parses raw GitHub Skill file URLs', () {
    final ref = GitHubSkillRef.parse(
      'https://raw.githubusercontent.com/acme/agent-skills/main/skills/pdf-tools/SKILL.md',
    );
    expect(ref.ref, 'main');
    expect(ref.subdir, 'skills/pdf-tools');
  });


  test('parses canonical raw GitHub refs/heads and refs/tags URLs', () {
    final branch = GitHubSkillRef.parse(
      'https://raw.githubusercontent.com/acme/agent-skills/refs/heads/main/skills/pdf-tools/SKILL.md',
    );
    expect(branch.ref, 'main');
    expect(branch.subdir, 'skills/pdf-tools');

    final tag = GitHubSkillRef.parse(
      'https://raw.githubusercontent.com/acme/agent-skills/refs/tags/v1.2.0/skills/pdf-tools/SKILL.md',
    );
    expect(tag.ref, 'v1.2.0');
    expect(tag.subdir, 'skills/pdf-tools');
  });

  test('rejects unsafe hosts, credentials, opaque queries and path traversal', () {
    for (final url in [
      'https://github.com.evil.test/acme/agent-skills',
      'https://user:pass@github.com/acme/agent-skills',
      'https://github.com/acme/agent-skills?token=secret',
      'https://github.com/acme/agent-skills/tree/main/../outside',
      'https://github.com/acme/agent-skills?ref=feature/../outside',
      'https://raw.githubusercontent.com/acme/agent-skills/main/skills/../SKILL.md',
    ]) {
      expect(
        () => GitHubSkillRef.parse(url),
        throwsFormatException,
        reason: url,
      );
    }
  });
}
