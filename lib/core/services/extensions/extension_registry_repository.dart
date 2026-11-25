import 'dart:convert';

import '../../database/extension_entity_store.dart';
import '../../models/extension_record.dart';
import '../../models/plugin_component.dart';

/// Persists all installable extension metadata in the existing extension
/// entity table. This adds no SQLite schema migration and keeps extension
/// packages independent of the Flutter APK.
final class ExtensionRegistryRepository {
  ExtensionRegistryRepository(this._store);

  static const String storageKind = ExtensionEntityStore.kindExtensionRegistry;

  final ExtensionEntityStore _store;

  Future<List<ExtensionRecord>> list({String? kind}) async {
    final rows = await _store.listByKind(storageKind);
    final records = <ExtensionRecord>[];
    for (final row in rows) {
      final record = ExtensionRecord.fromJson(row.payload);
      if (kind == null || record.kind == kind) records.add(record);
    }
    records.sort((a, b) {
      final byKind = a.kind.compareTo(b.kind);
      return byKind != 0 ? byKind : a.id.compareTo(b.id);
    });
    return List<ExtensionRecord>.unmodifiable(records);
  }

  Future<ExtensionRecord?> get(String kind, String id) async {
    final row = await _store.get(storageKind, _storageId(kind, id));
    if (row == null) return null;
    final record = ExtensionRecord.fromJson(row.payload);
    if (record.kind != kind || record.id != id) {
      throw const FormatException('extension_registry_identity');
    }
    return record;
  }

  Future<void> upsert(ExtensionRecord record) async {
    record.validate();
    await _store.upsert(storageKind, record.storageId, record.toJson());
  }

  /// Returns the metadata-only component descriptors owned by one Plugin.
  /// Descriptors never imply that a component is enabled or executable.
  Future<List<PluginComponentDescriptor>> componentsForPlugin(
    String pluginId,
  ) async {
    final plugin = await get('plugin', pluginId);
    if (plugin == null) return const <PluginComponentDescriptor>[];
    final raw = plugin.metadata['components'];
    if (raw == null) return const <PluginComponentDescriptor>[];
    if (raw is! List) {
      throw const FormatException('plugin_components_invalid');
    }
    return List<PluginComponentDescriptor>.unmodifiable([
      for (final item in raw) PluginComponentDescriptor.fromJson(item),
    ]);
  }

  Stream<List<PluginComponentDescriptor>> watchPluginComponents(
    String pluginId,
  ) {
    return watch(kind: 'plugin').asyncMap((plugins) async {
      ExtensionRecord? plugin;
      for (final candidate in plugins) {
        if (candidate.id == pluginId) {
          plugin = candidate;
          break;
        }
      }
      if (plugin == null) return const <PluginComponentDescriptor>[];
      final raw = plugin.metadata['components'];
      if (raw == null) return const <PluginComponentDescriptor>[];
      if (raw is! List) {
        throw const FormatException('plugin_components_invalid');
      }
      return List<PluginComponentDescriptor>.unmodifiable([
        for (final item in raw) PluginComponentDescriptor.fromJson(item),
      ]);
    });
  }

  Future<ExtensionRecord> transition({
    required String kind,
    required String id,
    required ExtensionLifecycleStatus to,
    String? errorCode,
  }) async {
    final current = await get(kind, id);
    if (current == null) throw StateError('extension_not_found');
    if (!_allowedTransitions[current.status]!.contains(to)) {
      throw StateError(
        'extension_transition:${current.status.name}->${to.name}',
      );
    }
    final next = current.copyWith(
      status: to,
      updatedAt: DateTime.now().toUtc(),
      lastErrorCode: errorCode,
      clearLastError: errorCode == null,
    );
    await upsert(next);
    return next;
  }

  Future<void> remove(String kind, String id) =>
      _store.delete(storageKind, _storageId(kind, id));

  Stream<List<ExtensionRecord>> watch({String? kind}) =>
      _store.watchKind(storageKind).map((rows) {
        final records = [
          for (final row in rows) ExtensionRecord.fromJson(row.payload),
        ].where((record) => kind == null || record.kind == kind).toList();
        records.sort((a, b) {
          final byKind = a.kind.compareTo(b.kind);
          return byKind != 0 ? byKind : a.id.compareTo(b.id);
        });
        return List<ExtensionRecord>.unmodifiable(records);
      });

  /// Reconciles the legacy SkillsService record into the generic registry.
  /// Existing origin refs, digests, declared permissions and compatibility
  /// metadata are retained when an old skill record is encountered.
  Future<void> syncSkill({
    required String id,
    required String name,
    required String description,
    required String sourceType,
    required bool enabled,
    required DateTime installedAt,
    required DateTime updatedAt,
    String? sourceUri,
    String? sourceRef,
    String? sourceSubpath,
    String? sourceRevision,
    bool replaceSourceMetadata = false,
  }) async {
    final previous = await get('skill', id);
    final next = ExtensionRecord(
      id: id,
      kind: 'skill',
      name: name,
      source: ExtensionSource(
        type: sourceType,
        uri: replaceSourceMetadata ? sourceUri : sourceUri ?? previous?.source.uri,
        ref: replaceSourceMetadata ? sourceRef : sourceRef ?? previous?.source.ref,
        subpath: replaceSourceMetadata ? sourceSubpath : sourceSubpath ?? previous?.source.subpath,
        revision: replaceSourceMetadata ? sourceRevision : sourceRevision ?? previous?.source.revision,
      ),
      status: enabled
          ? ExtensionLifecycleStatus.enabled
          : ExtensionLifecycleStatus.disabled,
      version: previous?.version,
      digest: previous?.digest,
      compatibility:
          previous?.compatibility ??
          const {'host': 'kelivo', 'skillFormat': 'agent-skills'},
      permissions: previous?.permissions ?? const [],
      entryPoint: 'SKILL.md',
      installedAt: installedAt,
      updatedAt: updatedAt.isAfter(previous?.updatedAt ?? DateTime.utc(1970))
          ? updatedAt
          : previous?.updatedAt ?? updatedAt,
      metadata: {...?previous?.metadata, 'description': description},
    );
    if (previous == null ||
        jsonEncode(previous.toJson()) != jsonEncode(next.toJson())) {
      await upsert(next);
    }
  }

  static String _storageId(String kind, String id) {
    if (!RegExp(r'^[a-z][a-z0-9_-]{0,31}$').hasMatch(kind) ||
        !RegExp(r'^[a-z0-9][a-z0-9._-]{0,127}$').hasMatch(id)) {
      throw const FormatException('extension_registry_key');
    }
    return '$kind::$id';
  }

  static const Map<ExtensionLifecycleStatus, Set<ExtensionLifecycleStatus>>
  _allowedTransitions = {
    ExtensionLifecycleStatus.discovered: {
      ExtensionLifecycleStatus.downloaded,
      ExtensionLifecycleStatus.failed,
      ExtensionLifecycleStatus.incompatible,
    },
    ExtensionLifecycleStatus.downloaded: {
      ExtensionLifecycleStatus.validated,
      ExtensionLifecycleStatus.failed,
      ExtensionLifecycleStatus.incompatible,
    },
    ExtensionLifecycleStatus.validated: {
      ExtensionLifecycleStatus.installed,
      ExtensionLifecycleStatus.failed,
      ExtensionLifecycleStatus.incompatible,
    },
    ExtensionLifecycleStatus.installed: {
      ExtensionLifecycleStatus.enabled,
      ExtensionLifecycleStatus.disabled,
      ExtensionLifecycleStatus.updateAvailable,
      ExtensionLifecycleStatus.failed,
      ExtensionLifecycleStatus.incompatible,
    },
    ExtensionLifecycleStatus.enabled: {
      ExtensionLifecycleStatus.disabled,
      ExtensionLifecycleStatus.updateAvailable,
      ExtensionLifecycleStatus.failed,
      ExtensionLifecycleStatus.incompatible,
    },
    ExtensionLifecycleStatus.disabled: {
      ExtensionLifecycleStatus.enabled,
      ExtensionLifecycleStatus.updateAvailable,
      ExtensionLifecycleStatus.failed,
      ExtensionLifecycleStatus.incompatible,
    },
    ExtensionLifecycleStatus.updateAvailable: {
      ExtensionLifecycleStatus.downloaded,
      ExtensionLifecycleStatus.disabled,
      ExtensionLifecycleStatus.failed,
    },
    ExtensionLifecycleStatus.incompatible: {
      ExtensionLifecycleStatus.discovered,
      ExtensionLifecycleStatus.downloaded,
      ExtensionLifecycleStatus.failed,
    },
    ExtensionLifecycleStatus.failed: {
      ExtensionLifecycleStatus.discovered,
      ExtensionLifecycleStatus.downloaded,
      ExtensionLifecycleStatus.validated,
    },
  };
}
