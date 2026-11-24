import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/services/extensions/conversational_extension_service.dart';
import 'package:Kelivo/core/services/extensions/extension_command_tools.dart';
import 'package:Kelivo/core/services/extensions/extension_operation_repository.dart';
import 'package:Kelivo/core/services/extensions/extension_registry_repository.dart';
import 'package:Kelivo/core/services/skills/skill_composition_planner.dart';
import 'package:Kelivo/core/services/skills/skill_composition_service.dart';
import 'package:Kelivo/core/services/skills/skills_prompt.dart';
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

  test('extension_search discovers a Skill beyond the prompt cap and applies its result limit', () async {
    for (var index = 0; index < 20; index++) {
      await skills.importFromText('''
---
name: a-visible-phase14a-$index
description: searchable phase14a skill number $index.
---
Visible instructions for $index.
''');
    }
    final hidden = await skills.importFromText('''
---
name: z-hidden-phase14a
description: searchable phase14a hidden capability.
---
Hidden full instructions.
''');

    final visiblePrompt = buildAvailableSkillsFragment(
      skills.skills,
      skillsModelRoot: '/skills',
    );
    expect(visiblePrompt, isNot(contains(hidden.record.id)));

    final registry = ExtensionRegistryRepository(store);
    final extensionService = ConversationalExtensionService(
      skills: skills,
      registry: registry,
      operations: ExtensionOperationRepository(store),
    );
    final bounded = jsonDecode(await extensionService.handle(
      ExtensionCommandToolNames.search,
      <String, dynamic>{
        'query': 'searchable phase14a',
        'scope': 'installed',
        'limit': 3,
      },
    )) as Map<String, dynamic>;
    expect(bounded['installedSkills'], hasLength(3));
    expect(bounded['installedSkillsTotal'], 21);
    expect(bounded['installedSkillsTruncated'], isTrue);

    final discovered = jsonDecode(await extensionService.handle(
      ExtensionCommandToolNames.search,
      <String, dynamic>{
        'query': 'z-hidden-phase14a',
        'scope': 'installed',
        'limit': 1,
      },
    )) as Map<String, dynamic>;
    final results = discovered['installedSkills'] as List<dynamic>;
    expect(results, hasLength(1));
    final discoveredId = (results.single as Map<String, dynamic>)['id'] as String;
    expect(discoveredId, hidden.record.id);

    final instructionReads = <String>[];
    final composition = SkillCompositionService(
      skills: skills,
      registry: registry,
      instructionReader: (id, {required maxCharacters}) async {
        instructionReads.add(id);
        return skills.readSkillMarkdown(id, maxCharacters: maxCharacters);
      },
    );
    final decoded = jsonDecode(await composition.compose(
      task: 'Use the discovered hidden skill',
      availableSkills: skills.skills,
      mode: SkillCompositionMode.explicit,
      requestedSkillIds: [discoveredId],
    )) as Map<String, dynamic>;
    expect(decoded['status'], 'ready');
    expect(decoded['selectedSkillIds'], [hidden.record.id]);
    expect(instructionReads, [hidden.record.id]);
  });

  test('composition blocks when full selected instructions exceed the context budget', () async {
    final selected = await skills.importFromText('''
---
name: selected-large-instructions
description: A Skill with a deliberately large instruction body.
metadata:
  kelivo.tags: large context budget regression
---
${List<String>.filled(1200, 'instruction').join(' ')}
''');
    final instructionReads = <String>[];
    final composition = SkillCompositionService(
      skills: skills,
      registry: ExtensionRegistryRepository(store),
      instructionReader: (id, {required maxCharacters}) async {
        instructionReads.add(id);
        return skills.readSkillMarkdown(id, maxCharacters: maxCharacters);
      },
    );

    final decoded = jsonDecode(await composition.compose(
      task: 'Use the selected large instruction skill',
      availableSkills: skills.skills,
      mode: SkillCompositionMode.explicit,
      requestedSkillIds: [selected.record.id],
      contextBudgetTokens: 500,
    )) as Map<String, dynamic>;

    expect(instructionReads, [selected.record.id]);
    expect(decoded['status'], 'blocked');
    final issues = decoded['issues'] as List<dynamic>;
    expect(
      issues.map((issue) => (issue as Map<String, dynamic>)['code']),
      contains('context_budget_exceeded'),
    );
    final budget = decoded['contextBudget'] as Map<String, dynamic>;
    expect(budget['estimatedInstructionTokens'], greaterThan(500));
    final instructions = decoded['selectedSkillInstructions'] as Map<String, dynamic>;
    expect(instructions, isEmpty);
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
