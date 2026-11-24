import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/services/extensions/extension_registry_repository.dart';
import 'package:Kelivo/core/services/skills/skill_composition_planner.dart';
import 'package:Kelivo/core/services/skills/skill_composition_service.dart';
import 'package:Kelivo/core/services/skills/skills_service.dart';

void main() {
  late AppDatabase database;
  late ExtensionEntityStore store;
  late Directory temporary;
  late SkillsService skills;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    store = ExtensionEntityStore(database);
    await database.customSelect('SELECT 1;').getSingle();
    temporary = await Directory.systemTemp.createTemp('kelivo_phase14a_');
    skills = SkillsService(
      store: store,
      skillsDirectory: Directory(p.join(temporary.path, 'skills')),
    );
    await skills.loaded;
  });

  tearDown(() async {
    skills.dispose();
    await database.close();
    if (await temporary.exists()) {
      await temporary.delete(recursive: true);
    }
  });

  test('composition reads metadata for candidates but full instructions only for selected Skills', () async {
    final selected = await skills.importFromText('''
---
name: selected-video-skill
description: Create and edit short videos.
metadata:
  kelivo.tags: video editing
  kelivo.outputs: final.mp4
---
SELECTED FULL INSTRUCTIONS
''');
    final unselected = await skills.importFromText('''
---
name: unrelated-spreadsheet-skill
description: Format spreadsheets and CSV data.
metadata:
  kelivo.tags: spreadsheet csv
---
UNSELECTED BODY MUST NOT BE READ
''');
    final metadataReads = <String>[];
    final instructionReads = <String>[];
    final composition = SkillCompositionService(
      skills: skills,
      registry: ExtensionRegistryRepository(store),
      frontmatterReader: (id) async {
        metadataReads.add(id);
        return skills.readSkillFrontmatterMarkdown(id);
      },
      instructionReader: (id, {required maxCharacters}) async {
        instructionReads.add(id);
        return skills.readSkillMarkdown(id, maxCharacters: maxCharacters);
      },
    );

    final decoded = jsonDecode(await composition.compose(
      task: 'Create a short video and export MP4',
      availableSkills: skills.skills,
      mode: SkillCompositionMode.automatic,
    )) as Map<String, dynamic>;

    expect(decoded['status'], 'ready');
    expect(decoded['selectedSkillIds'], [selected.record.id]);
    expect(metadataReads.toSet(), {selected.record.id, unselected.record.id});
    expect(instructionReads, [selected.record.id]);
    final instructions = decoded['selectedSkillInstructions'] as Map<String, dynamic>;
    expect(instructions[selected.record.id], contains('SELECTED FULL INSTRUCTIONS'));
    expect(instructions.values.join('\n'), isNot(contains('UNSELECTED BODY MUST NOT BE READ')));
  });

  test('explicitly selected Skills beyond the prompt listing cap can still be composed', () async {
    final skillIds = <String>[];
    for (var index = 0; index < 21; index++) {
      final skill = await skills.importFromText('''
---
name: phase14a-skill-$index
description: Helper number $index.
---
Instruction body for $index.
''');
      skillIds.add(skill.record.id);
    }
    final instructionReads = <String>[];
    final composition = SkillCompositionService(
      skills: skills,
      registry: ExtensionRegistryRepository(store),
      instructionReader: (id, {required maxCharacters}) async {
        instructionReads.add(id);
        return skills.readSkillMarkdown(id, maxCharacters: maxCharacters);
      },
    );
    final target = skillIds.last;
    final decoded = jsonDecode(await composition.compose(
      task: 'Use the selected skill',
      availableSkills: skills.skills,
      mode: SkillCompositionMode.explicit,
      requestedSkillIds: [target],
    )) as Map<String, dynamic>;

    expect(decoded['status'], 'ready');
    expect(decoded['selectedSkillIds'], [target]);
    expect(instructionReads, [target]);
  });
}
