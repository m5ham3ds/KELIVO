import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/packages/package_ledger_store.dart';
import 'package:Kelivo/core/services/packages/package_manager_models.dart';
import '../../../support/business_test_harness.dart';

void main() {
  test('persists package versions and exact pins through BusinessPreferences', () async {
    final harness = await createBusinessTestHarness();
    final ledger = PackageLedgerStore(harness.preferences);
    final now = DateTime.utc(2026, 11, 8);
    await ledger.upsert(PackageLedgerEntry(
      scopeKey: 'project:demo:python',
      manager: 'pip',
      name: 'requests',
      installedVersion: '2.32.3',
      pinnedVersion: '2.32.3',
      updatedAt: now,
    ));

    final reloaded = PackageLedgerStore(harness.preferences);
    await reloaded.load();
    final entry = reloaded.find(
      scopeKey: 'project:demo:python',
      manager: 'pip',
      packageName: 'REQUESTS',
    );
    expect(entry?.installedVersion, '2.32.3');
    expect(entry?.pinnedVersion, '2.32.3');
  });

  test('keeps one package record when switching compatible managers in a scope', () async {
    final harness = await createBusinessTestHarness();
    final ledger = PackageLedgerStore(harness.preferences);
    final now = DateTime.utc(2026, 11, 8);
    await ledger.upsert(PackageLedgerEntry(
      scopeKey: 'runtime:python',
      manager: 'pip',
      name: 'requests',
      installedVersion: '2.32.3',
      updatedAt: now,
    ));
    await ledger.upsert(PackageLedgerEntry(
      scopeKey: 'runtime:python',
      manager: 'uv',
      name: 'requests',
      installedVersion: '2.32.3',
      updatedAt: now.add(const Duration(minutes: 1)),
    ));

    expect(ledger.entries(scopeKey: 'runtime:python'), hasLength(1));
    expect(
      ledger.find(scopeKey: 'runtime:python', packageName: 'requests')?.manager,
      'uv',
    );
  });

  test('updates a started operation in place when final outcome is recorded', () async {
    final harness = await createBusinessTestHarness();
    final ledger = PackageLedgerStore(harness.preferences);
    await ledger.recordOperation({
      'operationId': 'op-1',
      'status': 'started',
    });
    await ledger.recordOperation({
      'operationId': 'op-1',
      'status': 'succeeded',
    });

    expect(ledger.history(limit: PackageLedgerStore.maxHistory), hasLength(1));
    expect(ledger.history().single['status'], 'succeeded');
  });

  test('keeps newest operation history and bounds the ledger history', () async {
    final harness = await createBusinessTestHarness();
    final ledger = PackageLedgerStore(harness.preferences);
    for (var i = 0; i < PackageLedgerStore.maxHistory + 5; i++) {
      await ledger.recordOperation({'operationId': '$i', 'status': 'succeeded'});
    }

    expect(ledger.history(), hasLength(30));
    expect(ledger.history(limit: PackageLedgerStore.maxHistory), hasLength(PackageLedgerStore.maxHistory));
    expect(ledger.history().first['operationId'], '${PackageLedgerStore.maxHistory + 4}');
  });
}
