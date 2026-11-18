import 'dart:convert';

import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/services/packages/package_manager_models.dart';

/// Persists package pins, observed versions and a bounded audit trail in the
/// existing SQLite-backed BusinessPreferences store (no schema migration).
final class PackageLedgerStore {
  PackageLedgerStore(this.preferences);

  static const String storageKey = 'kelivo_package_ledger_v1';
  static const int maxHistory = 100;

  final BusinessPreferences preferences;
  Future<void> _writeTail = Future<void>.value();
  List<PackageLedgerEntry> _entries = [];
  List<Map<String, Object?>> _history = [];
  Future<void>? _loaded;

  Future<void> load() {
    final active = _loaded;
    if (active != null) return active;
    final future = _load();
    _loaded = future;
    return future;
  }

  Future<void> _load() async {
    await preferences.load();
    final raw = preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final rawEntries = decoded['entries'];
      final rawHistory = decoded['history'];
      _entries = [
        if (rawEntries is List)
          for (final item in rawEntries)
            if (item is Map)
              PackageLedgerEntry.fromJson(Map<String, Object?>.from(item)),
      ];
      _history = [
        if (rawHistory is List)
          for (final item in rawHistory)
            if (item is Map) Map<String, Object?>.from(item),
      ].take(maxHistory).toList();
    } catch (_) {
      // Ignore a damaged user ledger rather than blocking package operations.
      _entries = [];
      _history = [];
    }
  }

  List<PackageLedgerEntry> entries({String? scopeKey}) {
    return List.unmodifiable(
      _entries.where((entry) => scopeKey == null || entry.scopeKey == scopeKey),
    );
  }

  List<Map<String, Object?>> history({int limit = 30}) =>
      List.unmodifiable(_history.take(limit));

  PackageLedgerEntry? find({
    required String scopeKey,
    String? manager,
    required String packageName,
  }) {
    for (final entry in _entries) {
      if (entry.scopeKey == scopeKey &&
          (manager == null || entry.manager == manager) &&
          entry.name.toLowerCase() == packageName.toLowerCase()) {
        return entry;
      }
    }
    return null;
  }

  Future<void> upsert(PackageLedgerEntry entry) async {
    await load();
    await _serialize(() async {
      final index = _entries.indexWhere(
        (current) =>
            current.scopeKey == entry.scopeKey &&
            current.name.toLowerCase() == entry.name.toLowerCase(),
      );
      final next = [..._entries];
      if (index < 0) {
        next.add(entry);
      } else {
        next[index] = entry;
      }
      _entries = next;
      await _save();
    });
  }

  Future<void> remove({
    required String scopeKey,
    String? manager,
    required String packageName,
  }) async {
    await load();
    await _serialize(() async {
      _entries = _entries
          .where(
            (entry) =>
                !(entry.scopeKey == scopeKey &&
                    (manager == null || entry.manager == manager) &&
                    entry.name.toLowerCase() == packageName.toLowerCase()),
          )
          .toList();
      await _save();
    });
  }

  Future<void> recordOperation(Map<String, Object?> operation) async {
    await load();
    await _serialize(() async {
      final next = Map<String, Object?>.from(operation);
      final operationId = next['operationId'];
      final existingIndex = operationId is String
          ? _history.indexWhere((item) => item['operationId'] == operationId)
          : -1;
      if (existingIndex >= 0) {
        _history[existingIndex] = next;
        final updated = _history.removeAt(existingIndex);
        _history.insert(0, updated);
      } else {
        _history.insert(0, next);
      }
      if (_history.length > maxHistory) {
        _history = _history.take(maxHistory).toList();
      }
      await _save();
    });
  }

  Future<void> _save() => preferences.setString(
    storageKey,
    jsonEncode({
      'schemaVersion': 1,
      'entries': _entries.map((entry) => entry.toJson()).toList(),
      'history': _history,
    }),
  );

  Future<void> _serialize(Future<void> Function() operation) {
    final result = _writeTail.then((_) => operation());
    _writeTail = result.catchError((Object _) {});
    return result;
  }
}
