import '../../database/extension_entity_store.dart';

/// Status of a user-requested extension operation.
enum ExtensionOperationStatus { running, succeeded, failed, cancelled }

/// A compact, non-secret audit record for conversational extension commands.
final class ExtensionOperationRecord {
  const ExtensionOperationRecord({
    required this.id,
    required this.operation,
    required this.kind,
    required this.target,
    required this.status,
    required this.startedAt,
    required this.updatedAt,
    this.source,
    this.requestId,
    this.phase,
    this.receivedBytes,
    this.totalBytes,
    this.resultSummary,
    this.errorCode,
  });

  final String id;
  final String operation;
  final String kind;
  final String target;
  final String? source;
  final String? requestId;
  final ExtensionOperationStatus status;
  final String? phase;
  final int? receivedBytes;
  final int? totalBytes;
  final String? resultSummary;
  final String? errorCode;
  final DateTime startedAt;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'id': id,
    'operation': operation,
    'kind': kind,
    'target': target,
    if (source != null) 'source': source,
    if (requestId != null) 'requestId': requestId,
    'status': status.name,
    if (phase != null) 'phase': phase,
    if (receivedBytes != null) 'receivedBytes': receivedBytes,
    if (totalBytes != null) 'totalBytes': totalBytes,
    if (resultSummary != null) 'resultSummary': resultSummary,
    if (errorCode != null) 'errorCode': errorCode,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory ExtensionOperationRecord.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1 ||
        json['id'] is! String ||
        json['operation'] is! String ||
        json['kind'] is! String ||
        json['target'] is! String ||
        json['status'] is! String ||
        json['startedAt'] is! String ||
        json['updatedAt'] is! String) {
      throw const FormatException('extension_operation_record');
    }
    return ExtensionOperationRecord(
      id: json['id'] as String,
      operation: json['operation'] as String,
      kind: json['kind'] as String,
      target: json['target'] as String,
      source: json['source'] as String?,
      requestId: json['requestId'] as String?,
      status: ExtensionOperationStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => throw const FormatException('extension_operation_status'),
      ),
      phase: json['phase'] as String?,
      receivedBytes: (json['receivedBytes'] as num?)?.toInt(),
      totalBytes: (json['totalBytes'] as num?)?.toInt(),
      resultSummary: json['resultSummary'] as String?,
      errorCode: json['errorCode'] as String?,
      startedAt: DateTime.parse(json['startedAt'] as String).toUtc(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
    );
  }

  ExtensionOperationRecord copyWith({
    ExtensionOperationStatus? status,
    String? phase,
    int? receivedBytes,
    int? totalBytes,
    String? resultSummary,
    String? errorCode,
    bool clearError = false,
  }) => ExtensionOperationRecord(
    id: id,
    operation: operation,
    kind: kind,
    target: target,
    source: source,
    requestId: requestId,
    status: status ?? this.status,
    phase: phase ?? this.phase,
    receivedBytes: receivedBytes ?? this.receivedBytes,
    totalBytes: totalBytes ?? this.totalBytes,
    resultSummary: resultSummary ?? this.resultSummary,
    errorCode: clearError ? null : (errorCode ?? this.errorCode),
    startedAt: startedAt,
    updatedAt: DateTime.now().toUtc(),
  );
}

/// Stores the last operations in the existing generic extension entity table.
/// No Drift schema migration is required.
final class ExtensionOperationRepository {
  ExtensionOperationRepository(this._store);

  static const String storageKind = ExtensionEntityStore.kindExtensionOperation;
  static const int maxHistory = 80;

  final ExtensionEntityStore _store;

  Future<ExtensionOperationRecord> start({
    required String id,
    required String operation,
    required String kind,
    required String target,
    String? source,
    String? requestId,
  }) async {
    if (!RegExp(r'^[a-zA-Z0-9_.:-]{1,160}$').hasMatch(id) ||
        !RegExp(r'^[a-z][a-z_]{0,39}$').hasMatch(operation) ||
        !RegExp(r'^[a-z][a-z0-9_-]{0,31}$').hasMatch(kind) ||
        target.trim().isEmpty ||
        target.length > 160 ||
        (source?.length ?? 0) > 2048 ||
        (requestId?.length ?? 0) > 80 ||
        (requestId != null &&
            !RegExp(r'^[a-zA-Z0-9_.:-]{1,80}$').hasMatch(requestId))) {
      throw const FormatException('extension_operation_input');
    }
    final now = DateTime.now().toUtc();
    final record = ExtensionOperationRecord(
      id: id,
      operation: operation,
      kind: kind,
      target: target,
      source: source,
      requestId: requestId,
      status: ExtensionOperationStatus.running,
      startedAt: now,
      updatedAt: now,
    );
    await _store.upsert(storageKind, id, record.toJson());
    await _trimHistory();
    return record;
  }

  Future<void> update(
    String id, {
    String? phase,
    int? receivedBytes,
    int? totalBytes,
  }) async {
    final record = await get(id);
    if (record == null || record.status != ExtensionOperationStatus.running) {
      return;
    }
    await _save(
      record.copyWith(
        phase: phase,
        receivedBytes: receivedBytes,
        totalBytes: totalBytes,
      ),
    );
  }

  Future<void> finish(
    String id, {
    required ExtensionOperationStatus status,
    String? summary,
    String? errorCode,
  }) async {
    final record = await get(id);
    if (record == null) return;
    await _save(
      record.copyWith(
        status: status,
        resultSummary: summary,
        errorCode: errorCode,
        clearError: errorCode == null,
      ),
    );
  }

  Future<ExtensionOperationRecord?> get(String id) async {
    final row = await _store.get(storageKind, id);
    if (row == null) return null;
    return ExtensionOperationRecord.fromJson(row.payload);
  }

  Future<List<ExtensionOperationRecord>> list({int limit = 20}) async {
    final rows = await _store.listByKind(storageKind);
    final records = <ExtensionOperationRecord>[];
    for (final row in rows) {
      try {
        records.add(ExtensionOperationRecord.fromJson(row.payload));
      } catch (_) {
        // Ignore damaged historical entries; new records remain usable.
      }
    }
    records.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return List.unmodifiable(records.take(limit.clamp(1, maxHistory).toInt()));
  }

  Future<void> _save(ExtensionOperationRecord record) =>
      _store.upsert(storageKind, record.id, record.toJson());

  Future<void> _trimHistory() async {
    // Read the full set here: list() intentionally clamps user-facing history
    // to maxHistory, which would otherwise hide the records to be trimmed.
    final rows = await _store.listByKind(storageKind);
    final records = <ExtensionOperationRecord>[];
    for (final row in rows) {
      try {
        records.add(ExtensionOperationRecord.fromJson(row.payload));
      } catch (_) {
        await _store.delete(storageKind, row.id);
      }
    }
    records.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final completed = records
        .where((record) => record.status != ExtensionOperationStatus.running)
        .toList();
    for (final old in completed.skip(maxHistory)) {
      await _store.delete(storageKind, old.id);
    }
  }
}
