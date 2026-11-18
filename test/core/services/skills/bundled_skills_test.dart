import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/extension_record.dart';
import 'package:Kelivo/core/models/skill_record.dart';
import 'package:Kelivo/core/services/extensions/extension_registry_repository.dart';
import 'package:Kelivo/core/services/skills/core_guidance_service.dart';
import 'package:Kelivo/core/services/skills/skills_service.dart';

import '../../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BusinessTestHarness harness;
  late Directory root;
  late ExtensionEntityStore store;

  setUp(() async {
    harness = await createBusinessTestHarness();
    store = ExtensionEntityStore(harness.database);
    root = await Directory.systemTemp.createTemp('kelivo-skills-empty-');
    addTearDown(() => root.delete(recursive: true));
  });

  test('fresh install starts without pre-installed Skills', () async {
    final service = SkillsService(store: store, skillsDirectory: root);
    addTearDown(service.dispose);
    await service.loaded;

    expect(service.skills, isEmpty);
    expect(await store.listByKind(ExtensionEntityStore.kindSkill), isEmpty);
    expect(
      await Directory(p.join(root.path, 'skill-creator')).exists(),
      isFalse,
    );
    expect(await Directory(p.join(root.path, 'visualize')).exists(), isFalse);
  });

  test('core guidance is available but is not registered as a Skill', () async {
    final service = SkillsService(store: store, skillsDirectory: root);
    addTearDown(service.dispose);
    await service.loaded;

    final core = Directory(
      p.join(root.path, CoreGuidanceService.directoryName),
    );
    expect(
      await File(p.join(core.path, 'skill-authoring', 'GUIDE.md')).exists(),
      isTrue,
    );
    expect(
      await File(p.join(core.path, 'intelligent-ui', 'GUIDE.md')).exists(),
      isTrue,
    );
    expect(service.skills, isEmpty);
    expect(await store.listByKind(ExtensionEntityStore.kindSkill), isEmpty);
  });

  test(
    'legacy user-installed Skills remain discoverable after upgrade',
    () async {
      final legacyDir = Directory(p.join(root.path, 'my-custom-skill'));
      await legacyDir.create(recursive: true);
      await File(p.join(legacyDir.path, 'SKILL.md')).writeAsString('''
---
name: my-custom-skill
description: A user-owned skill retained after upgrade.
---
# My custom skill
Follow the user's workflow.
''');

      final service = SkillsService(store: store, skillsDirectory: root);
      addTearDown(service.dispose);
      await service.loaded;

      expect(service.skills.map((skill) => skill.record.id), [
        'my-custom-skill',
      ]);
      expect(service.skills.single.record.enabled, isTrue);
    },
  );

  test(
    'preserves legacy bundled Skill directories and migrates their metadata',
    () async {
      final legacyDir = Directory(p.join(root.path, 'visualize'));
      await legacyDir.create(recursive: true);
      await File(p.join(legacyDir.path, 'SKILL.md')).writeAsString('''
---
name: visualize
description: A customized legacy UI skill.
---
# Customized visualization workflow
Keep the user's edits.
''');
      final now = DateTime.utc(2025, 12, 1);
      await store.upsert(
        ExtensionEntityStore.kindSkill,
        'visualize',
        SkillRecord(
          id: 'visualize',
          source: SkillSource.bundled,
          installedAt: now,
          updatedAt: now,
        ).toJson(),
      );

      final service = SkillsService(store: store, skillsDirectory: root);
      addTearDown(service.dispose);
      await service.loaded;

      expect(service.skills.map((skill) => skill.record.id), ['visualize']);
      expect(service.skills.single.record.source, SkillSource.bundled);
      expect(
        await File(p.join(legacyDir.path, 'SKILL.md')).readAsString(),
        contains("Keep the user's edits."),
      );
      final registry = ExtensionRegistryRepository(store);
      expect(await registry.get('skill', 'visualize'), isNotNull);
    },
  );

  test(
    'keeps the Skills registry synchronized with Skill operations',
    () async {
      final service = SkillsService(store: store, skillsDirectory: root);
      addTearDown(service.dispose);
      await service.loaded;

      final skill = await service.importFromText('''
---
name: test-video-skill
description: A test skill for registry synchronization.
---
# Test video skill
Create a simple test output.
''');
      final registry = ExtensionRegistryRepository(store);
      final installed = await registry.get('skill', skill.record.id);
      expect(installed, isNotNull);
      expect(installed!.status, ExtensionLifecycleStatus.enabled);

      await service.setEnabled(skill.record.id, false);
      expect(
        (await registry.get('skill', skill.record.id))!.status,
        ExtensionLifecycleStatus.disabled,
      );

      await service.delete(skill.record.id);
      expect(await registry.get('skill', skill.record.id), isNull);
    },
  );
}
