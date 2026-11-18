import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/extension_record.dart';
import 'package:Kelivo/core/services/extensions/extension_registry_repository.dart';

import '../../../support/business_test_harness.dart';

void main() {
  late BusinessTestHarness harness;
  late ExtensionRegistryRepository registry;

  setUp(() async {
    harness = await createBusinessTestHarness();
    registry = ExtensionRegistryRepository(
      ExtensionEntityStore(harness.database),
    );
  });

  ExtensionRecord record(String kind, String id) => ExtensionRecord(
    id: id,
    kind: kind,
    name: '$kind $id',
    source: const ExtensionSource(
      type: 'github',
      uri: 'https://github.com/acme/repo',
    ),
    status: ExtensionLifecycleStatus.discovered,
    updatedAt: DateTime.utc(2026, 11, 7),
  );

  test(
    'stores multiple extension kinds with colliding ids independently',
    () async {
      await registry.upsert(record('skill', 'shared-id'));
      await registry.upsert(record('engine', 'shared-id'));

      expect(await registry.get('skill', 'shared-id'), isNotNull);
      expect(await registry.get('engine', 'shared-id'), isNotNull);
      expect((await registry.list()).length, 2);
      expect((await registry.list(kind: 'skill')).single.kind, 'skill');
    },
  );

  test(
    'enforces lifecycle transitions and rejects skipped validation',
    () async {
      await registry.upsert(record('engine', 'motion-canvas'));

      await expectLater(
        registry.transition(
          kind: 'engine',
          id: 'motion-canvas',
          to: ExtensionLifecycleStatus.installed,
        ),
        throwsStateError,
      );

      await registry.transition(
        kind: 'engine',
        id: 'motion-canvas',
        to: ExtensionLifecycleStatus.downloaded,
      );
      await registry.transition(
        kind: 'engine',
        id: 'motion-canvas',
        to: ExtensionLifecycleStatus.validated,
      );
      await registry.transition(
        kind: 'engine',
        id: 'motion-canvas',
        to: ExtensionLifecycleStatus.installed,
      );
      final enabled = await registry.transition(
        kind: 'engine',
        id: 'motion-canvas',
        to: ExtensionLifecycleStatus.enabled,
      );
      expect(enabled.status, ExtensionLifecycleStatus.enabled);
    },
  );

  test('removes only the requested extension kind and id', () async {
    await registry.upsert(record('skill', 'shared-id'));
    await registry.upsert(record('engine', 'shared-id'));

    await registry.remove('skill', 'shared-id');

    expect(await registry.get('skill', 'shared-id'), isNull);
    expect(await registry.get('engine', 'shared-id'), isNotNull);
  });

  test('syncs installed Skills into the unified registry', () async {
    await registry.syncSkill(
      id: 'cinematic-cuts',
      name: 'Cinematic Cuts',
      description: 'Creates cinematic video edits.',
      sourceType: 'github',
      enabled: true,
      installedAt: DateTime.utc(2026, 10, 1),
      updatedAt: DateTime.utc(2026, 10, 2),
    );

    final skill = await registry.get('skill', 'cinematic-cuts');
    expect(skill, isNotNull);
    expect(skill!.status, ExtensionLifecycleStatus.enabled);
    expect(skill.entryPoint, 'SKILL.md');
    expect(skill.compatibility['skillFormat'], 'agent-skills');

    await registry.syncSkill(
      id: 'cinematic-cuts',
      name: 'Cinematic Cuts',
      description: 'Creates cinematic video edits.',
      sourceType: 'github',
      enabled: false,
      installedAt: DateTime.utc(2026, 10, 1),
      updatedAt: DateTime.utc(2026, 10, 3),
    );
    expect(
      (await registry.get('skill', 'cinematic-cuts'))!.status,
      ExtensionLifecycleStatus.disabled,
    );
  });

  test('watch publishes registry changes', () async {
    final events = <List<ExtensionRecord>>[];
    final subscription = registry.watch(kind: 'workflow').listen(events.add);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(events, isNotEmpty);
    expect(events.last, isEmpty);

    await registry.upsert(record('workflow', 'cinematic-trailer'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(events.last.map((item) => item.id), ['cinematic-trailer']);

    await subscription.cancel();
  });
}
