import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/services/skills/core_guidance_service.dart';
import 'package:Kelivo/core/services/skills/skills_service.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_guidance.dart';

import '../../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BusinessTestHarness harness;
  late Directory root;
  late ExtensionEntityStore store;

  setUp(() async {
    harness = await createBusinessTestHarness();
    root = await Directory.systemTemp.createTemp('kelivo-core-guidance-');
    store = ExtensionEntityStore(harness.database);
    addTearDown(() => root.delete(recursive: true));
  });

  test(
    'interactive UI guidance is materialized outside installed Skills',
    () async {
      final service = SkillsService(store: store, skillsDirectory: root);
      addTearDown(service.dispose);
      await service.loaded;

      final guidanceRoot = Directory(
        p.join(root.path, CoreGuidanceService.directoryName, 'intelligent-ui'),
      );
      final expected = UiGuidance.generateAssets();
      final actual = guidanceRoot
          .listSync(recursive: true)
          .whereType<File>()
          .map(
            (file) => p.posix.joinAll(
              p.split(p.relative(file.path, from: guidanceRoot.path)),
            ),
          )
          .toSet();

      expect(actual, expected.keys.toSet());
      for (final entry in expected.entries) {
        expect(
          await File(p.join(guidanceRoot.path, entry.key)).readAsString(),
          entry.value,
          reason: entry.key,
        );
      }
      expect(service.skills, isEmpty);
      expect(await store.listByKind(ExtensionEntityStore.kindSkill), isEmpty);
    },
  );
}
