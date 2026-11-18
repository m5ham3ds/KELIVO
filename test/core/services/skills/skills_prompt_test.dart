import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/skill_record.dart';
import 'package:Kelivo/core/services/skills/skill.dart';
import 'package:Kelivo/core/services/skills/skills_prompt.dart';

Skill _skill({
  required String id,
  required String name,
  required String description,
  int useCount = 0,
  SkillSource source = SkillSource.file,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return Skill(
    record: SkillRecord(
      id: id,
      useCount: useCount,
      source: source,
      installedAt: now,
      updatedAt: now,
    ),
    name: name,
    description: description,
    dir: '/tmp/$id',
    skillMdPath: '/tmp/$id/SKILL.md',
  );
}

void main() {
  test('lists skills with model paths and instructions', () {
    final fragment = buildAvailableSkillsFragment([
      _skill(
        id: 'pdf-tools',
        name: 'pdf-tools',
        description: 'Extract text and tables from PDF files with pdfplumber.',
      ),
    ], skillsModelRoot: '/skills');
    expect(fragment, contains('<available_skills>'));
    expect(
      fragment,
      contains(
        'When a task matches a Skill, read its SKILL.md first and follow its instructions.',
      ),
    );
    expect(
      fragment,
      contains(
        '- pdf-tools — Extract text and tables from PDF files with pdfplumber. '
        '(/skills/pdf-tools/SKILL.md)',
      ),
    );
    expect(fragment, endsWith('</available_skills>'));
  });

  test('caps descriptions at 20 and orders by stable name/id', () {
    final skills = <Skill>[
      for (var i = 0; i < 21; i++)
        _skill(
          id: 's${i.toString().padLeft(2, '0')}',
          name: 's${i.toString().padLeft(2, '0')}',
          description: 'd$i',
          useCount: i == 7 ? 5 : (i == 3 ? 5 : 0),
        ),
    ];
    final fragment = buildAvailableSkillsFragment(
      skills,
      skillsModelRoot: '/skills',
    );
    final items = RegExp(r'^- ', multiLine: true).allMatches(fragment);
    expect(items.length, 20);
    expect(fragment, isNot(contains('s20')));
    final first = fragment.split('\n').firstWhere((l) => l.startsWith('- '));
    expect(first, startsWith('- s00 —'));
    final second = fragment
        .split('\n')
        .where((l) => l.startsWith('- '))
        .skip(1)
        .first;
    expect(second, startsWith('- s01 —'));
  });

  test('clips descriptions to 200 UTF-16 units', () {
    final long = '${'a' * 180}${'😀' * 20}bbbb';
    final fragment = buildAvailableSkillsFragment([
      _skill(id: 'clip', name: 'clip', description: long),
    ], skillsModelRoot: '/skills');
    final match = RegExp(
      r'- clip — (.+) \(/skills/clip/SKILL.md\)',
    ).firstMatch(fragment);
    expect(match, isNotNull);
    final clipped = match!.group(1)!;
    expect(clipped.length, lessThanOrEqualTo(200));
    expect(clipped, isNot(contains('bbbb')));
  });

  test('uses the supplied skillsModelRoot', () {
    final fragment = buildAvailableSkillsFragment([
      _skill(id: 'x', name: 'x', description: 'd'),
    ], skillsModelRoot: '/custom/skills/');
    expect(fragment, contains('(/custom/skills/x/SKILL.md)'));
  });

  test('usage changes and equal names cannot reorder the model prefix', () {
    List<Skill> skills(int uses) => [
      _skill(id: 'z', name: 'Same', description: 'Z', useCount: uses),
      _skill(id: 'a', name: 'same', description: 'A'),
    ];
    final first = buildAvailableSkillsFragment(
      skills(0),
      skillsModelRoot: '/skills',
    );
    expect(
      buildAvailableSkillsFragment(
        skills(999).reversed.toList(),
        skillsModelRoot: '/skills',
      ),
      first,
    );
    expect(first.indexOf('- a —'), lessThan(first.indexOf('- z —')));
  });

  test('core capabilities are independent from installed Skills', () {
    final empty = buildAvailableSkillsFragment(
      const [],
      skillsModelRoot: '/skills',
    );
    expect(empty, contains('<kelivo_core_capabilities>'));
    expect(empty, contains('/skills/.kelivo-core/intelligent-ui/GUIDE.md'));
    expect(empty, contains('/skills/.kelivo-core/skill-authoring/GUIDE.md'));
    expect(empty, contains('extension_install'));
    expect(empty, contains('extension_update'));
    expect(empty, contains('call `skill_compose` before following them'));
    expect(empty, contains('Phase 4 adds `skill_compose`'));
    expect(empty, contains('Phase 3 supports the Agent Skills standard'));
    expect(empty, contains('Skill environment requirement discovery is mandatory'));
    expect(empty, contains('Skill Readiness is staged'));
    expect(empty, contains('ready_for_instructions'));
    expect(empty, contains('Capability Registry is independent of installed Skills'));
    expect(empty, contains('not_checked_in_skill_profile'));
    expect(empty, contains('never install packages'));
    expect(empty, contains('extension_inspect'));
    expect(
      empty,
      contains(
        'Do not claim a Skill was installed until its files have been saved and verified.',
      ),
    );
    expect(empty, contains('<available_skills>'));
    expect(empty, endsWith('</available_skills>'));
    expect(empty, isNot(contains('- visualize —')));
    expect(empty, isNot(contains('- skill-creator —')));
  });

  test('legacy bundled Skills receive no hidden priority', () {
    final other = _skill(id: 'aaa', name: 'aaa', description: 'A');
    final legacy = _skill(
      id: 'visualize',
      name: 'visualize',
      description: 'Legacy user-owned Skill',
      source: SkillSource.bundled,
    );
    final value = buildAvailableSkillsFragment([
      other,
      legacy,
    ], skillsModelRoot: '/skills');
    expect(value.indexOf('- aaa —'), lessThan(value.indexOf('- visualize —')));
  });

  test(
    'explicit selections survive the description cap and remain readable',
    () {
      final skills = [
        for (var i = 0; i < 25; i++)
          _skill(
            id: 's${i.toString().padLeft(2, '0')}',
            name: 'Skill ${i.toString().padLeft(2, '0')}',
            description: 'Entry $i',
          ),
      ];
      final pinned = buildAvailableSkillsFragment(
        skills,
        skillsModelRoot: '/skills',
        selectedSkillIds: ['s24'],
      );
      expect(pinned, contains('- s24 —'));
      expect(pinned.indexOf('- s24 —'), lessThan(pinned.indexOf('- s00 —')));
      final all = buildAvailableSkillsFragment(
        skills,
        skillsModelRoot: '/custom',
        selectedSkillIds: skills.map((s) => s.record.id),
      );
      expect(RegExp(r'^- ', multiLine: true).allMatches(all), hasLength(20));
      for (final skill in skills) {
        expect(all, contains('/custom/${skill.record.id}/SKILL.md'));
      }
      expect(all, contains('Additional explicitly selected skills'));
      expect(all, contains('  s24: /custom/s24/SKILL.md'));
    },
  );
}
