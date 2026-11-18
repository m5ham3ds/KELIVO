import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/services/skills/skills_service.dart';

String _markdown(String name) => '''
---
name: $name
description: $name standalone skill
---
# $name
Run this Skill independently or as part of a pack.
''';

void main() {
  late AppDatabase database;
  late ExtensionEntityStore store;
  late Directory temp;
  late SkillsService skills;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    store = ExtensionEntityStore(database);
    temp = await Directory.systemTemp.createTemp('kelivo_pack_independent_');
    skills = SkillsService(
      store: store,
      skillsDirectory: Directory(p.join(temp.path, 'skills')),
    );
    await skills.loaded;
  });

  tearDown(() async {
    skills.dispose();
    await database.close();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('pack creation and activation never overwrite standalone Skill state', () async {
    final alpha = await skills.importFromText(_markdown('alpha'));
    final beta = await skills.importFromText(_markdown('beta'));
    await skills.setEnabled(beta.record.id, false);

    final pack = await skills.saveSkillPack(
      name: 'Alpha Beta Toolkit',
      shortcut: 'alpha_beta',
      skillIds: [alpha.record.id, beta.record.id],
    );

    expect(skills.skills.map((skill) => skill.record.enabled), [true, false]);
    expect(
      skills.resolveForAssistant(null).map((skill) => skill.record.id),
      [alpha.record.id],
    );

    await skills.setEnabled(alpha.record.id, false);
    expect(skills.skillPacks.single.enabled, isFalse);
    expect(skills.resolveForAssistant(null), isEmpty);
    expect(
      skills.resolveForAssistant(
        null,
        conversationOverride: [alpha.record.id],
      ).map((skill) => skill.record.id),
      [alpha.record.id],
      reason: 'an explicit standalone selection must not expand to the pack',
    );

    await skills.setSkillPackEnabled(pack.id, true);
    expect(
      skills.resolveForAssistant(null).map((skill) => skill.record.id),
      unorderedEquals([alpha.record.id, beta.record.id]),
    );
    expect(skills.skills.map((skill) => skill.record.enabled), [false, false]);

    await skills.setEnabled(beta.record.id, true);
    expect(skills.skillPacks.single.enabled, isTrue);
    await skills.setSkillPackEnabled(pack.id, false);
    expect(
      skills.resolveForAssistant(null).map((skill) => skill.record.id),
      [beta.record.id],
    );
    expect(skills.skills.map((skill) => skill.record.enabled), [false, true]);

    await skills.deleteSkillPack(pack.id);
    expect(skills.skillPacks, isEmpty);
    expect(skills.skills.map((skill) => skill.record.id),
      unorderedEquals([alpha.record.id, beta.record.id]));
    expect(skills.skills.map((skill) => skill.record.enabled), [false, true]);
  });

  test('manual Skill Packs never take ownership of member updates', () async {
    final alpha = await skills.importFromText(_markdown('alpha'));
    final beta = await skills.importFromText(_markdown('beta'));
    final pack = await skills.saveSkillPack(
      name: 'Manual Toolkit',
      shortcut: 'manual_toolkit',
      skillIds: [alpha.record.id, beta.record.id],
    );

    expect(pack.autoDetected, isFalse);
    expect(skills.canUpdateSkillPack(pack.id), isFalse);
    await expectLater(
      skills.updateSkillPack(pack.id),
      throwsA(isA<StateError>().having(
        (error) => error.message,
        'message',
        'skill_pack_not_repository_group',
      )),
    );
    expect(skills.skills, hasLength(2));
    expect(Directory(p.join(temp.path, 'skills', alpha.record.id)).existsSync(),
        isTrue);
    expect(Directory(p.join(temp.path, 'skills', beta.record.id)).existsSync(),
        isTrue);
  });

  test('editing Pack membership never moves or deletes original Skills', () async {
    final alpha = await skills.importFromText(_markdown('alpha'));
    final beta = await skills.importFromText(_markdown('beta'));
    final pack = await skills.saveSkillPack(
      name: 'Editable Toolkit',
      shortcut: 'editable_toolkit',
      skillIds: [alpha.record.id],
    );

    final edited = await skills.saveSkillPack(
      id: pack.id,
      name: 'Editable Toolkit',
      shortcut: 'editable_toolkit',
      skillIds: [beta.record.id],
    );

    expect(edited.skillIds, [beta.record.id]);
    expect(skills.skills.map((skill) => skill.record.id),
        unorderedEquals([alpha.record.id, beta.record.id]));
    expect(Directory(p.join(temp.path, 'skills', alpha.record.id)).existsSync(),
        isTrue);
    expect(Directory(p.join(temp.path, 'skills', beta.record.id)).existsSync(),
        isTrue);
    expect(skills.skills.map((skill) => skill.record.enabled), [true, true]);

    await skills.deleteSkillPack(pack.id);
    expect(skills.skills, hasLength(2));
    expect(Directory(p.join(temp.path, 'skills', alpha.record.id)).existsSync(),
        isTrue);
    expect(Directory(p.join(temp.path, 'skills', beta.record.id)).existsSync(),
        isTrue);
  });

  test('one original Skill can belong to multiple independent packs', () async {
    final alpha = await skills.importFromText(_markdown('alpha'));
    final beta = await skills.importFromText(_markdown('beta'));
    final gamma = await skills.importFromText(_markdown('gamma'));

    final first = await skills.saveSkillPack(
      name: 'Alpha Beta',
      shortcut: 'alpha_beta',
      skillIds: [alpha.record.id, beta.record.id],
    );
    final second = await skills.saveSkillPack(
      name: 'Beta Gamma',
      shortcut: 'beta_gamma',
      skillIds: [beta.record.id, gamma.record.id],
    );

    expect(skills.skillPacks, hasLength(2));
    expect(first.skillIds, [alpha.record.id, beta.record.id]);
    expect(second.skillIds, [beta.record.id, gamma.record.id]);
    expect(skills.skills, hasLength(3));
    expect(skills.skills.map((skill) => skill.record.enabled), everyElement(isTrue));

    await skills.setEnabled(beta.record.id, false);
    expect(
      skills.skills.singleWhere((skill) => skill.record.id == beta.record.id)
          .record.enabled,
      isFalse,
    );
    expect(skills.skillPacks, hasLength(2));

    await skills.rescan();
    expect(skills.skillPacks, hasLength(2));
    expect(
      skills.skillPacks.singleWhere((pack) => pack.id == first.id).skillIds,
      [alpha.record.id, beta.record.id],
    );
    expect(
      skills.skillPacks.singleWhere((pack) => pack.id == second.id).skillIds,
      [beta.record.id, gamma.record.id],
    );
    expect(
      skills.skills.singleWhere((skill) => skill.record.id == beta.record.id)
          .record.enabled,
      isFalse,
      reason: 'rescan must not migrate pack state into the original Skill',
    );

    await skills.deleteSkillPack(first.id);
    expect(skills.skillPacks.single.id, second.id);
    expect(skills.skills, hasLength(3));
    expect(
      skills.skills.singleWhere((skill) => skill.record.id == beta.record.id)
          .record.enabled,
      isFalse,
    );
  });
}
