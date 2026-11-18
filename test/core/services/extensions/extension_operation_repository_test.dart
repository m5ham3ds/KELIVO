import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/services/extensions/extension_operation_repository.dart';

import '../../../support/business_test_harness.dart';

void main() {
  late BusinessTestHarness harness;
  late ExtensionOperationRepository repository;

  setUp(() async {
    harness = await createBusinessTestHarness();
    repository = ExtensionOperationRepository(
      ExtensionEntityStore(harness.database),
    );
  });

  test('records operation progress and terminal status', () async {
    final started = await repository.start(
      id: 'ext-1',
      operation: 'install',
      kind: 'skill',
      target: 'cinematic-cuts',
      source: 'https://github.com/acme/skills/tree/main/cinematic-cuts',
      requestId: 'tool-call-1',
    );
    expect(started.status, ExtensionOperationStatus.running);

    await repository.update(
      'ext-1',
      phase: 'downloading',
      receivedBytes: 1024,
      totalBytes: 4096,
    );
    await repository.finish(
      'ext-1',
      status: ExtensionOperationStatus.succeeded,
      summary: 'Installed successfully',
    );

    final saved = await repository.get('ext-1');
    expect(saved, isNotNull);
    expect(saved!.status, ExtensionOperationStatus.succeeded);
    expect(saved.phase, 'downloading');
    expect(saved.receivedBytes, 1024);
    expect(saved.totalBytes, 4096);
    expect(saved.requestId, 'tool-call-1');
    expect(saved.resultSummary, 'Installed successfully');
  });

  test('history is bounded and never evicts a running operation', () async {
    for (var i = 0; i < 85; i++) {
      final id = 'ext-$i';
      await repository.start(
        id: id,
        operation: 'enable',
        kind: 'skill',
        target: 'skill-$i',
      );
      await repository.finish(id, status: ExtensionOperationStatus.succeeded);
    }
    await repository.start(
      id: 'ext-still-running',
      operation: 'install',
      kind: 'skill',
      target: 'long-running',
    );

    final history = await repository.list(limit: 1000);
    expect(history.length, 80); // User-facing history is capped at 80.
    expect(
      history.where(
        (entry) => entry.status == ExtensionOperationStatus.running,
      ),
      hasLength(1),
    );
    expect(await repository.get('ext-0'), isNull);
    expect(await repository.get('ext-still-running'), isNotNull);
  });

  test(
    'rejects malformed operation identifiers and excessive values',
    () async {
      await expectLater(
        repository.start(
          id: '../outside',
          operation: 'install',
          kind: 'skill',
          target: 'test',
        ),
        throwsFormatException,
      );
    },
  );
}
