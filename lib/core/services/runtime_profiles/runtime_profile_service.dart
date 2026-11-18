import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/core/services/workspace/workspace_tool_context.dart';

import 'runtime_profile_models.dart';

abstract final class RuntimeProfileEntityKinds {
  static const profiles = 'runtime_profile';
  static const processes = 'runtime_process';
  static const snapshots = 'runtime_profile_snapshot';
}

// Shared by every RuntimeProfileService instance in this Dart process. The
// tool handler can construct more than one service during a single generation;
// those instances must agree on active reservations and process ownership.
final String _runtimeProfileProcessSessionId = const Uuid().v4();

class RuntimeProfileService {
  RuntimeProfileService({
    required this.store,
    required this.runtimeProvider,
    String? processSessionId,
  }) : processSessionId = processSessionId ?? _runtimeProfileProcessSessionId;

  final ExtensionEntityStore store;
  final WorkspaceRuntimeProvider runtimeProvider;
  final String processSessionId;

  bool _loaded = false;
  Future<void>? _loading;
  final Map<String, RuntimeProfile> _profiles = {};
  final Map<String, RuntimeProcessRecord> _processes = {};
  final Map<String, RuntimeProfileSnapshotRecord> _snapshots = {};
  static final Map<String, Set<String>> _activeByProfile = {};
  static const int maxSnapshotsPerProfile = 10;
  static const int maxSnapshotBytes = 512 * 1024 * 1024;
  static const int maxTotalSnapshotBytesPerProfile = 2 * 1024 * 1024 * 1024;

  List<RuntimeProfile> get profiles => List.unmodifiable(_profiles.values);
  List<RuntimeProcessRecord> get processes => List.unmodifiable(_processes.values);

  Future<void> load() async {
    if (_loaded) return;
    final pending = _loading;
    if (pending != null) return pending;
    _loading = _loadInternal();
    try {
      await _loading;
    } finally {
      _loading = null;
    }
  }

  Future<void> _loadInternal() async {
    final profileRows = await store.listByKind(RuntimeProfileEntityKinds.profiles);
    final processRows = await store.listByKind(RuntimeProfileEntityKinds.processes);
    final snapshotRows = await store.listByKind(RuntimeProfileEntityKinds.snapshots);
    _profiles
      ..clear()
      ..addEntries(profileRows.map((row) => MapEntry(
        row.id,
        RuntimeProfile.fromJson(row.payload),
      )));
    _processes
      ..clear()
      ..addEntries(processRows.map((row) => MapEntry(
        row.id,
        RuntimeProcessRecord.fromJson(row.payload),
      )));
    _snapshots
      ..clear()
      ..addEntries(snapshotRows.map((row) {
        try {
          return MapEntry(
            row.id,
            RuntimeProfileSnapshotRecord.fromJson(row.payload),
          );
        } catch (_) {
          // A corrupt snapshot index must not make every runtime profile
          // unavailable. Restore will only accept validated records.
          return null;
        }
      }).whereType<MapEntry<String, RuntimeProfileSnapshotRecord>>());

    // Workspace commands are owned by the app process. After a process death
    // the native runner cannot be resumed by Dart; mark stale ledger entries
    // interrupted and retain an actionable resume hint instead of pretending
    // the command is still running.
    final stale = _processes.values
        .where((record) =>
            record.status == RuntimeProcessStatus.running &&
            record.sessionId != processSessionId)
        .toList();
    for (final record in stale) {
      final interrupted = record.copyWith(
        status: RuntimeProcessStatus.interrupted,
        completedAt: DateTime.now().toUtc(),
        error: 'app_process_restarted',
        resumeHint: 'Review outputs and rerun the last incomplete step from its latest valid checkpoint.',
      );
      _processes[record.id] = interrupted;
      await store.upsert(
        RuntimeProfileEntityKinds.processes,
        interrupted.id,
        interrupted.toJson(),
      );
    }
    _loaded = true;
  }

  Future<List<RuntimeProfile>> list({
    String? ownerId,
    RuntimeProfileScope? scope,
  }) async {
    await load();
    return _profiles.values.where((profile) {
      if (ownerId != null && profile.ownerId != ownerId) return false;
      if (scope != null && profile.scope != scope) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  RuntimeProfile? byId(String id) => _profiles[id];

  Future<RuntimeProfile> inspectOwned({
    required String profileId,
    required WorkspaceToolContext context,
  }) async {
    await load();
    final profile = _profiles[profileId];
    if (profile == null) throw const RuntimeProfileException('runtime_profile_not_found');
    _validateOwner(profile.scope, profile.ownerId, context);
    return profile;
  }

  Future<RuntimeProfile> validatePackageTarget({
    required String profileId,
    required String scope,
    required String ownerId,
    required String ecosystem,
  }) async {
    await load();
    final profile = _profiles[profileId];
    if (profile == null) throw const RuntimeProfileException('runtime_profile_not_found');
    if (profile.status != RuntimeProfileStatus.ready) {
      throw const RuntimeProfileException('runtime_profile_not_ready');
    }
    if (profile.scope.name != scope || profile.ownerId != ownerId) {
      throw const RuntimeProfileException('runtime_profile_scope_mismatch');
    }
    final selected = RuntimeProfileEcosystem.values
        .where((item) => item.name == ecosystem)
        .firstOrNull;
    if (selected == null || !profile.ecosystems.contains(selected)) {
      throw const RuntimeProfileException('runtime_profile_ecosystem_not_enabled');
    }
    return profile;
  }

  Future<RuntimeProfile> create({
    required String name,
    required RuntimeProfileScope scope,
    required String ownerId,
    required Set<RuntimeProfileEcosystem> ecosystems,
    required WorkspaceToolContext context,
    Map<String, String> environment = const {},
    RuntimeResourceLimits limits = const RuntimeResourceLimits(),
    bool shareBaseTools = true,
  }) async {
    await load();
    final trimmedName = name.trim();
    if (trimmedName.isEmpty || trimmedName.length > 80) {
      throw const RuntimeProfileException('invalid_profile_name');
    }
    if (!RuntimeProfileValidation.isSafeId(ownerId)) {
      throw const RuntimeProfileException('invalid_profile_owner_id');
    }
    if (ecosystems.isEmpty) {
      throw const RuntimeProfileException('at_least_one_ecosystem_required');
    }
    final runtime = await runtimeProvider.ensureInitialized();
    if (runtime == null) {
      throw const RuntimeProfileException('runtime_unavailable');
    }
    final runtimeStatus = await runtime.status();
    if (!runtimeStatus.ready) {
      throw RuntimeProfileException(runtimeStatus.reason ?? 'runtime_not_ready');
    }
    if (scope != RuntimeProfileScope.project &&
        (!runtimeStatus.sandboxed || runtimeStatus.engine != 'proot')) {
      throw const RuntimeProfileException('extension_and_task_profiles_require_android_proot');
    }
    final environmentIssue = RuntimeProfileValidation.validateEnvironment(environment);
    if (environmentIssue != null) {
      throw RuntimeProfileException(environmentIssue);
    }
    _validateOwner(scope, ownerId, context);

    final id = const Uuid().v4();
    final now = DateTime.now().toUtc();
    var profile = RuntimeProfile(
      id: id,
      name: trimmedName,
      scope: scope,
      ownerId: ownerId,
      ecosystems: Set.unmodifiable(ecosystems),
      environment: Map.unmodifiable(environment),
      limits: limits.normalized(),
      shareBaseTools: shareBaseTools,
      status: RuntimeProfileStatus.provisioning,
      createdAt: now,
      updatedAt: now,
    );
    _profiles[id] = profile;
    await store.upsert(RuntimeProfileEntityKinds.profiles, id, profile.toJson());
    try {
      final root = runtimeProfileRoot(
        profile: profile,
        workspaceRoot: context.paths.modelRoot,
        sandboxed: context.paths.sandboxed,
      );
      final commands = <String>['mkdir -p ${_quote(root)}'];
      if (ecosystems.contains(RuntimeProfileEcosystem.shell)) {
        commands.add('command -v bash >/dev/null 2>&1 || { echo __KELIVO_MISSING_BASH__; exit 127; }');
      }
      if (ecosystems.contains(RuntimeProfileEcosystem.python)) {
        commands.add('command -v python3 >/dev/null 2>&1 || { echo __KELIVO_MISSING_PYTHON3__; exit 127; }');
        commands.add('if [ ! -x ${_quote('$root/python/bin/python')} ]; then python3 -m venv ${_quote('$root/python')}; fi');
      }
      if (ecosystems.contains(RuntimeProfileEcosystem.node)) {
        commands.add('command -v node >/dev/null 2>&1 || { echo __KELIVO_MISSING_NODE__; exit 127; }');
        commands.add('mkdir -p ${_quote('$root/node')}');
      }
      await _runInternal(
        context: context,
        command: commands.join('; '),
        timeout: const Duration(minutes: 3),
        label: 'runtime profile provisioning',
      );
      profile = profile.copyWith(
        status: RuntimeProfileStatus.ready,
        clearLastError: true,
      );
    } catch (error) {
      profile = profile.copyWith(
        status: RuntimeProfileStatus.failed,
        lastError: _safeError(error),
      );
      _profiles[id] = profile;
      await store.upsert(RuntimeProfileEntityKinds.profiles, id, profile.toJson());
      rethrow;
    }
    _profiles[id] = profile;
    await store.upsert(RuntimeProfileEntityKinds.profiles, id, profile.toJson());
    return profile;
  }

  /// Updates user-editable settings for a project profile without
  /// recreating its Python/Node package roots. Running profiles are immutable
  /// until their active processes finish.
  Future<RuntimeProfile> updateProjectSettings({
    required String profileId,
    required WorkspaceToolContext context,
    String? name,
    RuntimeResourceLimits? limits,
    bool? shareBaseTools,
  }) async {
    await load();
    final profile = _profiles[profileId];
    if (profile == null) {
      throw const RuntimeProfileException('runtime_profile_not_found');
    }
    _validateOwner(profile.scope, profile.ownerId, context);
    if (profile.scope != RuntimeProfileScope.project ||
        profile.ownerId != context.workspace.id) {
      throw const RuntimeProfileException('project_profile_required');
    }
    if ((_activeByProfile[profileId]?.isNotEmpty ?? false)) {
      throw const RuntimeProfileException('profile_has_active_processes');
    }
    final nextName = name?.trim();
    if (nextName != null && (nextName.isEmpty || nextName.length > 80)) {
      throw const RuntimeProfileException('invalid_profile_name');
    }
    final updated = profile.copyWith(
      name: nextName,
      limits: limits?.normalized(),
      shareBaseTools: shareBaseTools,
      clearLastError: true,
    );
    _profiles[profileId] = updated;
    await store.upsert(RuntimeProfileEntityKinds.profiles, profileId, updated.toJson());
    return updated;
  }

  Future<void> remove({
    required String profileId,
    required WorkspaceToolContext context,
  }) async {
    await load();
    final profile = _profiles[profileId];
    if (profile == null) throw const RuntimeProfileException('profile_not_found');
    _validateOwner(profile.scope, profile.ownerId, context);
    if ((_activeByProfile[profileId]?.isNotEmpty ?? false)) {
      throw const RuntimeProfileException('profile_has_active_processes');
    }
    final root = runtimeProfileRoot(
      profile: profile,
      workspaceRoot: context.paths.modelRoot,
      sandboxed: context.paths.sandboxed,
    );
    final allowedRoot = switch (profile.scope) {
      RuntimeProfileScope.project => '${context.paths.modelRoot}/.kelivo/runtime-profiles/',
      RuntimeProfileScope.extension => '/root/.local/share/kelivo/runtime-profiles/extensions/${profile.ownerId}/',
      RuntimeProfileScope.task => '/root/.local/share/kelivo/runtime-profiles/tasks/${profile.ownerId}/',
    };
    if (!root.startsWith(allowedRoot) || root == allowedRoot) {
      throw const RuntimeProfileException('invalid_runtime_profile_root');
    }
    final profileSnapshots = snapshots(profileId: profileId);
    final expectedSnapshotDirectory = _snapshotDirectory(
      profile: profile,
      workspaceRoot: context.paths.modelRoot,
      sandboxed: context.paths.sandboxed,
    );
    if (profileSnapshots.any((snapshot) =>
        p.posix.dirname(snapshot.archivePath) != expectedSnapshotDirectory)) {
      throw const RuntimeProfileException('runtime_profile_snapshot_path_mismatch');
    }
    final snapshotDirectories = profileSnapshots.isEmpty
        ? <String>{}
        : <String>{expectedSnapshotDirectory};
    await _runInternal(
      context: context,
      command: 'rm -rf -- ${_quote(root)}'
          '${snapshotDirectories.map((path) => ' ${_quote(path)}').join()}',
      timeout: const Duration(minutes: 2),
      label: 'runtime profile removal',
    );
    for (final snapshot in profileSnapshots) {
      await store.delete(RuntimeProfileEntityKinds.snapshots, snapshot.id);
      _snapshots.remove(snapshot.id);
    }
    _profiles.remove(profileId);
    await store.delete(RuntimeProfileEntityKinds.profiles, profileId);
  }

  /// Reserves a profile for a package-manager/snapshot maintenance operation.
  /// This shares the same lock as Skill execution, preventing a package update
  /// from mutating Python/Node roots while a Skill process is using them.
  Future<void> reserveMaintenance({
    required String profileId,
    required WorkspaceToolContext context,
    required String reservationId,
  }) async {
    await load();
    if (!RuntimeProfileValidation.isSafeId(reservationId)) {
      throw const RuntimeProfileException('invalid_runtime_profile_reservation');
    }
    final profile = _profiles[profileId];
    if (profile == null) {
      throw const RuntimeProfileException('runtime_profile_not_found');
    }
    if (profile.status != RuntimeProfileStatus.ready) {
      throw RuntimeProfileException('runtime_profile_not_ready:${profile.status.name}');
    }
    _validateOwner(profile.scope, profile.ownerId, context);
    final active = _activeByProfile.putIfAbsent(profileId, () => <String>{});
    if (active.isNotEmpty) {
      throw const RuntimeProfileException('runtime_profile_busy');
    }
    active.add(reservationId);
  }

  List<RuntimeProfileSnapshotRecord> snapshots({String? profileId}) {
    return _snapshots.values.where((snapshot) {
      return profileId == null || snapshot.profileId == profileId;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Creates an archive of the profile-owned package roots and lockfiles.
  /// The snapshot is stored outside the profile root to avoid self-inclusion.
  /// PRoot's shared apt/apk layer is intentionally excluded and remains a
  /// separately disclosed shared-system dependency surface.
  Future<RuntimeProfileSnapshotRecord> createSnapshot({
    required String profileId,
    required WorkspaceToolContext context,
    String? label,
    String? reservationId,
    bool pruneOldestSnapshots = false,
  }) async {
    await load();
    final profile = _profiles[profileId];
    if (profile == null) {
      throw const RuntimeProfileException('runtime_profile_not_found');
    }
    _validateOwner(profile.scope, profile.ownerId, context);
    if (profile.status != RuntimeProfileStatus.ready) {
      throw const RuntimeProfileException('runtime_profile_not_ready');
    }
    final ownsReservation = reservationId == null;
    final effectiveReservation = reservationId ?? 'snapshot-${const Uuid().v4()}';
    if (ownsReservation) {
      await reserveMaintenance(
        profileId: profileId,
        context: context,
        reservationId: effectiveReservation,
      );
    } else if (!(_activeByProfile[profileId]?.contains(effectiveReservation) ?? false)) {
      throw const RuntimeProfileException('runtime_profile_reservation_required');
    }
    String? createdArchivePath;
    try {
      final retainedSnapshots = snapshots(profileId: profileId).toList();
      var existingBytes = retainedSnapshots.fold<int>(
        0,
        (sum, item) => sum + item.sizeBytes,
      );
      final runtime = await runtimeProvider.ensureInitialized();
      if (runtime == null) throw const RuntimeProfileException('runtime_unavailable');
      final status = await runtime.status();
      if (!status.ready) {
        throw RuntimeProfileException(status.reason ?? 'runtime_not_ready');
      }
      final root = runtimeProfileRoot(
        profile: profile,
        workspaceRoot: context.paths.modelRoot,
        sandboxed: status.sandboxed,
      );
      final archiveDirectory = _snapshotDirectory(
        profile: profile,
        workspaceRoot: context.paths.modelRoot,
        sandboxed: status.sandboxed,
      );
      final snapshotId = const Uuid().v4();
      final archivePath = p.posix.join(archiveDirectory, '$snapshotId.tar.gz');
      createdArchivePath = archivePath;
      final temporaryArchivePath = '$archivePath.tmp';
      final includedItems = <String>[
        if (profile.ecosystems.contains(RuntimeProfileEcosystem.python)) 'python',
        if (profile.ecosystems.contains(RuntimeProfileEcosystem.node)) 'node',
        if (profile.ecosystems.contains(RuntimeProfileEcosystem.python))
          'dependencies.python.lock.json',
        if (profile.ecosystems.contains(RuntimeProfileEcosystem.node))
          'dependencies.node.lock.json',
      ];
      if (includedItems.isEmpty) {
        throw const RuntimeProfileException('runtime_profile_has_no_snapshotable_dependencies');
      }
      final itemArgs = includedItems.map(_quote).join(' ');
      final command = 'set -eu; '
          'ROOT=${_quote(root)}; ARCHIVE=${_quote(archivePath)}; '
          'TMP_ARCHIVE=${_quote(temporaryArchivePath)}; '
          'if [ -L ${_quote(archiveDirectory)} ]; then exit 6; fi; '
          'mkdir -p ${_quote(archiveDirectory)}; '
          "trap 'rm -f -- \"\$TMP_ARCHIVE\"' EXIT; "
          'set --; '
          'for item in $itemArgs; do '
          'if [ -e "${r'$'}ROOT/${r'$'}item" ]; then set -- "${r'$'}@" "${r'$'}item"; fi; '
          'done; '
          'if [ "${r'$'}#" -eq 0 ]; then echo __KELIVO_SNAPSHOT_EMPTY__; exit 3; fi; '
          'tar -czf "${r'$'}TMP_ARCHIVE" -C "${r'$'}ROOT" "${r'$'}@"; '
          'SIZE=${r'$'}(wc -c < "${r'$'}TMP_ARCHIVE"); '
          'if [ "${r'$'}SIZE" -gt $maxSnapshotBytes ]; then echo __KELIVO_SNAPSHOT_TOO_LARGE__; exit 0; fi; '
          'mv "${r'$'}TMP_ARCHIVE" "${r'$'}ARCHIVE"; '
          'sha256sum "${r'$'}ARCHIVE" | awk \'{print "__KELIVO_SNAPSHOT_SHA256__|" ${r'$'}1}\'; '
          'wc -c < "${r'$'}ARCHIVE" | awk \'{print "__KELIVO_SNAPSHOT_BYTES__|" ${r'$'}1}\'';
      final output = await _runInternalCaptured(
        context: context,
        command: command,
        timeout: const Duration(minutes: 20),
        label: 'runtime profile dependency snapshot',
      );
      if (output.contains('__KELIVO_SNAPSHOT_TOO_LARGE__')) {
        throw const RuntimeProfileException('runtime_profile_snapshot_too_large');
      }
      final digest = _markerValue(output, '__KELIVO_SNAPSHOT_SHA256__|');
      final size = int.tryParse(_markerValue(output, '__KELIVO_SNAPSHOT_BYTES__|') ?? '');
      if (digest == null || !RegExp(r'^[a-f0-9]{64}$').hasMatch(digest) ||
          size == null || size < 1 || size > maxSnapshotBytes) {
        throw const RuntimeProfileException('runtime_profile_snapshot_verification_failed');
      }
      while (retainedSnapshots.length >= maxSnapshotsPerProfile ||
          existingBytes + size > maxTotalSnapshotBytesPerProfile) {
        if (!pruneOldestSnapshots || retainedSnapshots.isEmpty) {
          throw RuntimeProfileException(
            retainedSnapshots.length >= maxSnapshotsPerProfile
                ? 'runtime_profile_snapshot_limit_reached'
                : 'runtime_profile_snapshot_storage_limit_reached',
          );
        }
        final oldest = retainedSnapshots.removeLast();
        await deleteSnapshot(
          snapshotId: oldest.id,
          context: context,
          reservationId: effectiveReservation,
        );
        existingBytes -= oldest.sizeBytes;
      }
      final record = RuntimeProfileSnapshotRecord(
        id: snapshotId,
        profileId: profile.id,
        ownerId: profile.ownerId,
        scope: profile.scope,
        archivePath: archivePath,
        sha256: digest,
        sizeBytes: size,
        ecosystems: profile.ecosystems,
        createdAt: DateTime.now().toUtc(),
        label: _safeSnapshotLabel(label),
      );
      await store.upsert(
        RuntimeProfileEntityKinds.snapshots,
        snapshotId,
        record.toJson(),
      );
      _snapshots[snapshotId] = record;
      return record;
    } catch (_) {
      // Do not leave an untracked archive behind when hashing, validation, or
      // metadata persistence fails after the archive has been written.
      if (createdArchivePath != null) {
        try {
          await _runInternal(
            context: context,
            command: 'rm -f -- ${_quote(createdArchivePath)}',
            timeout: const Duration(minutes: 2),
            label: 'runtime profile failed snapshot cleanup',
          );
        } catch (_) {
          // Preserve the original snapshot failure. A later Doctor scan can
          // report an orphan if the runtime itself is no longer available.
        }
      }
      rethrow;
    } finally {
      if (ownsReservation) releaseReservation(profileId, effectiveReservation);
    }
  }

  /// Restores only the package roots and lockfiles captured by a verified
  /// snapshot. The archive digest and member paths are checked before extract.
  Future<void> restoreSnapshot({
    required String snapshotId,
    required WorkspaceToolContext context,
    String? reservationId,
  }) async {
    await load();
    final snapshot = _snapshots[snapshotId];
    if (snapshot == null) {
      throw const RuntimeProfileException('runtime_profile_snapshot_not_found');
    }
    final profile = _profiles[snapshot.profileId];
    if (profile == null || profile.ownerId != snapshot.ownerId ||
        profile.scope != snapshot.scope ||
        !setEquals(profile.ecosystems, snapshot.ecosystems)) {
      throw const RuntimeProfileException('runtime_profile_snapshot_owner_mismatch');
    }
    _validateOwner(profile.scope, profile.ownerId, context);
    if (profile.status != RuntimeProfileStatus.ready) {
      throw const RuntimeProfileException('runtime_profile_not_ready');
    }
    final ownsReservation = reservationId == null;
    final effectiveReservation = reservationId ?? 'restore-${const Uuid().v4()}';
    if (ownsReservation) {
      await reserveMaintenance(
        profileId: profile.id,
        context: context,
        reservationId: effectiveReservation,
      );
    } else if (!(_activeByProfile[profile.id]?.contains(effectiveReservation) ?? false)) {
      throw const RuntimeProfileException('runtime_profile_reservation_required');
    }
    try {
      final runtime = await runtimeProvider.ensureInitialized();
      if (runtime == null) throw const RuntimeProfileException('runtime_unavailable');
      final status = await runtime.status();
      if (!status.ready) {
        throw RuntimeProfileException(status.reason ?? 'runtime_not_ready');
      }
      final root = runtimeProfileRoot(
        profile: profile,
        workspaceRoot: context.paths.modelRoot,
        sandboxed: status.sandboxed,
      );
      final expectedArchiveDirectory = _snapshotDirectory(
        profile: profile,
        workspaceRoot: context.paths.modelRoot,
        sandboxed: status.sandboxed,
      );
      if (p.posix.dirname(snapshot.archivePath) != expectedArchiveDirectory) {
        throw const RuntimeProfileException('runtime_profile_snapshot_path_mismatch');
      }
      final listing = await _runInternalCaptured(
        context: context,
        command: 'set -eu; ARCHIVE=${_quote(snapshot.archivePath)}; '
            '[ -f "${r'$'}ARCHIVE" ] || exit 4; '
            'sha256sum "${r'$'}ARCHIVE" | awk \'{print "__KELIVO_ARCHIVE_SHA256__|" ${r'$'}1}\'; '
            'wc -c < "${r'$'}ARCHIVE" | awk \'{print "__KELIVO_ARCHIVE_BYTES__|" ${r'$'}1}\'; '
            'tar -tzf "${r'$'}ARCHIVE"',
        timeout: const Duration(minutes: 5),
        label: 'runtime profile snapshot integrity check',
      );
      final actualDigest = _markerValue(listing, '__KELIVO_ARCHIVE_SHA256__|');
      if (actualDigest != snapshot.sha256) {
        throw const RuntimeProfileException('runtime_profile_snapshot_digest_mismatch');
      }
      final actualSize = int.tryParse(_markerValue(listing, '__KELIVO_ARCHIVE_BYTES__|') ?? '');
      if (actualSize == null || actualSize != snapshot.sizeBytes ||
          actualSize > maxSnapshotBytes) {
        throw const RuntimeProfileException('runtime_profile_snapshot_size_mismatch');
      }
      final members = listing.split(RegExp(r'\r?\n'))
          .where((line) => line.isNotEmpty &&
              !line.startsWith('__KELIVO_ARCHIVE_SHA256__|') &&
              !line.startsWith('__KELIVO_ARCHIVE_BYTES__|'))
          .toList();
      for (final member in members) {
        final normalized = member.replaceAll(RegExp(r'/+$'), '');
        if (normalized.isEmpty || normalized.startsWith('/') ||
            normalized.split('/').any((part) => part == '..') ||
            !const {
              'python', 'node',
              'dependencies.python.lock.json',
              'dependencies.node.lock.json',
            }.contains(normalized.split('/').first)) {
          throw const RuntimeProfileException('runtime_profile_snapshot_contains_unsafe_path');
        }
        final topLevel = normalized.split('/').first;
        final allowedForProfile = switch (topLevel) {
          'python' || 'dependencies.python.lock.json' =>
            profile.ecosystems.contains(RuntimeProfileEcosystem.python),
          'node' || 'dependencies.node.lock.json' =>
            profile.ecosystems.contains(RuntimeProfileEcosystem.node),
          _ => false,
        };
        if (!allowedForProfile) {
          throw const RuntimeProfileException('runtime_profile_snapshot_ecosystem_mismatch');
        }
      }
      final archiveDirectory = p.posix.dirname(snapshot.archivePath);
      final staging = p.posix.join(
        archiveDirectory,
        'restore-${snapshot.id}-${const Uuid().v4()}',
      );
      final restoreFolders = <String>[
        if (profile.ecosystems.contains(RuntimeProfileEcosystem.python)) 'python',
        if (profile.ecosystems.contains(RuntimeProfileEcosystem.node)) 'node',
      ];
      final restoreLocks = <String>[
        if (profile.ecosystems.contains(RuntimeProfileEcosystem.python))
          'dependencies.python.lock.json',
        if (profile.ecosystems.contains(RuntimeProfileEcosystem.node))
          'dependencies.node.lock.json',
      ];
      final backup = p.posix.join(
        archiveDirectory,
        'restore-backup-${snapshot.id}-${const Uuid().v4()}',
      );
      final restoreItems = <String>[...restoreFolders, ...restoreLocks];
      final restoreItemList = restoreItems.join(' ');
      await _runInternal(
        context: context,
        command: 'set -eu; '
            'ROOT=${_quote(root)}; STAGING=${_quote(staging)}; BACKUP=${_quote(backup)}; '
            'RESTORE_ITEMS=${_quote(restoreItemList)}; '
            'if [ -L ${_quote(archiveDirectory)} ] || [ -L "${r'$'}STAGING" ] || [ -L "${r'$'}BACKUP" ]; then exit 8; fi; '
            'mkdir -p "${r'$'}STAGING" "${r'$'}BACKUP"; '
            'RESTORE_FAILED=1; BACKED_UP=""; INSTALLED=""; '
            'cleanup_restore() { set +e; '
            'if [ "${r'$'}RESTORE_FAILED" -ne 0 ]; then '
            'for item in ${r'$'}INSTALLED; do rm -rf -- "${r'$'}ROOT/${r'$'}item"; done; '
            'for item in ${r'$'}BACKED_UP; do rm -rf -- "${r'$'}ROOT/${r'$'}item"; mv -- "${r'$'}BACKUP/${r'$'}item" "${r'$'}ROOT/${r'$'}item"; done; '
            'fi; rm -rf -- "${r'$'}STAGING" "${r'$'}BACKUP"; }; '
            'trap cleanup_restore EXIT; '
            'tar --no-same-owner --no-same-permissions -xzf ${_quote(snapshot.archivePath)} -C "${r'$'}STAGING"; '
            'for item in ${r'$'}RESTORE_ITEMS; do '
            'if [ -e "${r'$'}ROOT/${r'$'}item" ] || [ -L "${r'$'}ROOT/${r'$'}item" ]; then '
            'mv -- "${r'$'}ROOT/${r'$'}item" "${r'$'}BACKUP/${r'$'}item"; BACKED_UP="${r'$'}BACKED_UP ${r'$'}item"; fi; '
            'if [ -e "${r'$'}STAGING/${r'$'}item" ] || [ -L "${r'$'}STAGING/${r'$'}item" ]; then '
            'mv -- "${r'$'}STAGING/${r'$'}item" "${r'$'}ROOT/${r'$'}item"; INSTALLED="${r'$'}INSTALLED ${r'$'}item"; fi; '
            'done; RESTORE_FAILED=0',
        timeout: const Duration(minutes: 20),
        label: 'runtime profile snapshot restore',
      );
    } finally {
      if (ownsReservation) releaseReservation(profile.id, effectiveReservation);
    }
  }

  Future<void> deleteSnapshot({
    required String snapshotId,
    required WorkspaceToolContext context,
    String? reservationId,
  }) async {
    await load();
    final snapshot = _snapshots[snapshotId];
    if (snapshot == null) {
      throw const RuntimeProfileException('runtime_profile_snapshot_not_found');
    }
    final profile = _profiles[snapshot.profileId];
    if (profile == null || profile.ownerId != snapshot.ownerId ||
        profile.scope != snapshot.scope ||
        !setEquals(profile.ecosystems, snapshot.ecosystems)) {
      throw const RuntimeProfileException('runtime_profile_snapshot_owner_mismatch');
    }
    _validateOwner(profile.scope, profile.ownerId, context);
    final runtime = await runtimeProvider.ensureInitialized();
    if (runtime == null) throw const RuntimeProfileException('runtime_unavailable');
    final runtimeStatus = await runtime.status();
    if (!runtimeStatus.ready) {
      throw RuntimeProfileException(runtimeStatus.reason ?? 'runtime_not_ready');
    }
    final expectedArchiveDirectory = _snapshotDirectory(
      profile: profile,
      workspaceRoot: context.paths.modelRoot,
      sandboxed: runtimeStatus.sandboxed,
    );
    if (p.posix.dirname(snapshot.archivePath) != expectedArchiveDirectory) {
      throw const RuntimeProfileException('runtime_profile_snapshot_path_mismatch');
    }
    final ownsReservation = reservationId == null;
    final effectiveReservation = reservationId ?? 'delete-${const Uuid().v4()}';
    if (ownsReservation) {
      await reserveMaintenance(
        profileId: profile.id,
        context: context,
        reservationId: effectiveReservation,
      );
    } else if (!(_activeByProfile[profile.id]?.contains(effectiveReservation) ?? false)) {
      throw const RuntimeProfileException('runtime_profile_reservation_required');
    }
    try {
      await _runInternal(
        context: context,
        command: 'rm -f -- ${_quote(snapshot.archivePath)}',
        timeout: const Duration(minutes: 2),
        label: 'runtime profile snapshot removal',
      );
      await store.delete(RuntimeProfileEntityKinds.snapshots, snapshotId);
      _snapshots.remove(snapshotId);
    } finally {
      if (ownsReservation) releaseReservation(profile.id, effectiveReservation);
    }
  }

  Future<void> setDefault({
    required String profileId,
    required WorkspaceToolContext context,
    required WorkspaceProvider workspaces,
  }) async {
    await load();
    final profile = _profiles[profileId];
    if (profile == null || profile.status != RuntimeProfileStatus.ready) {
      throw const RuntimeProfileException('profile_not_ready');
    }
    if (profile.scope != RuntimeProfileScope.project ||
        profile.ownerId != context.workspace.id) {
      throw const RuntimeProfileException('default_profile_must_belong_to_project');
    }
    await workspaces.update(
      context.workspace.copyWith(defaultRuntimeProfileId: profileId),
    );
  }

  Future<void> clearDefault({
    required WorkspaceToolContext context,
    required WorkspaceProvider workspaces,
  }) async {
    await workspaces.update(
      context.workspace.copyWith(clearDefaultRuntimeProfileId: true),
    );
  }

  Future<RuntimeProfileExecution?> resolveExecution({
    required WorkspaceToolContext context,
    required String runId,
    String? requestedProfileId,
  }) async {
    await load();
    if (!RuntimeProfileValidation.isSafeId(runId)) {
      throw const RuntimeProfileException('invalid_runtime_run_id');
    }
    final id = (requestedProfileId?.trim().isNotEmpty == true)
        ? requestedProfileId!.trim()
        : context.workspace.defaultRuntimeProfileId;
    if (id == null || id.isEmpty) return null;
    final profile = _profiles[id];
    if (profile == null) throw const RuntimeProfileException('runtime_profile_not_found');
    if (profile.status != RuntimeProfileStatus.ready) {
      throw RuntimeProfileException('runtime_profile_not_ready:${profile.status.name}');
    }
    _validateOwner(profile.scope, profile.ownerId, context);
    if (profile.scope != RuntimeProfileScope.project ||
        profile.ownerId != context.workspace.id) {
      throw const RuntimeProfileException('workspace_shell_requires_project_profile');
    }
    final active = _activeByProfile.putIfAbsent(id, () => <String>{});
    if (active.length >= profile.limits.maxConcurrentRuns) {
      throw const RuntimeProfileException('runtime_profile_concurrency_limit_reached');
    }
    active.add(runId);

    final root = runtimeProfileRoot(
      profile: profile,
      workspaceRoot: context.paths.modelRoot,
      sandboxed: context.paths.sandboxed,
    );
    final tempGuest = '$root/tmp/$runId';
    final outputGuest = '$root/outputs/$runId';
    final tempHost = context.paths.sandboxed
        ? '${context.paths.workspaceHostRoot}/.kelivo/runtime-profiles/${profile.id}/tmp/$runId'
        : '$root/tmp/$runId';
    final pathParts = <String>[];
    if (profile.ecosystems.contains(RuntimeProfileEcosystem.python)) {
      pathParts.add('$root/python/bin');
    }
    if (profile.ecosystems.contains(RuntimeProfileEcosystem.node)) {
      pathParts.add('$root/node/node_modules/.bin');
    }
    if (profile.shareBaseTools) {
      pathParts.addAll(['/usr/local/sbin', '/usr/local/bin', '/usr/sbin', '/usr/bin', '/sbin', '/bin']);
    } else {
      pathParts.addAll(['/usr/bin', '/bin']);
    }
    final env = <String, String>{
      'PATH': pathParts.join(':'),
      'TMPDIR': tempGuest,
      'TMP': tempGuest,
      'TEMP': tempGuest,
      'KELIVO_TASK_OUTPUT_DIR': outputGuest,
      if (profile.ecosystems.contains(RuntimeProfileEcosystem.python)) ...{
        'VIRTUAL_ENV': '$root/python',
        'PYTHONNOUSERSITE': '1',
        'PIP_REQUIRE_VIRTUALENV': '1',
      },
      if (profile.ecosystems.contains(RuntimeProfileEcosystem.node)) ...{
        'NODE_PATH': '$root/node/node_modules',
        'npm_config_prefix': '$root/node',
      },
      ...profile.environment,
    };
    // Environment overrides are intentionally restricted to safe custom keys;
    // reserved execution keys are rejected by RuntimeProfileValidation.
    final limits = profile.limits.normalized();
    // A process killed with the app cannot be resumed; remove only its known,
    // UUID-scoped temp directory before the next run, keeping its output files.
    await _cleanupInterruptedTemporaryDirectories(
      context: context,
      profile: profile,
      root: root,
    );
    final commandPrefix = 'mkdir -p ${_quote(tempGuest)} ${_quote(outputGuest)} || exit ${r'$'}?; '
        'ulimit -t ${limits.maxCpuSeconds} 2>/dev/null || true; '
        'ulimit -u ${limits.maxProcesses} 2>/dev/null || true; '
        'ulimit -v ${limits.maxMemoryMegabytes * 1024} 2>/dev/null || true; '
        'ulimit -f ${limits.maxFileMegabytes * 2048} 2>/dev/null || true; ';
    return RuntimeProfileExecution(
      profile: profile,
      environment: env,
      temporaryHostPath: tempHost,
      temporaryRuntimePath: tempGuest,
      outputRuntimePath: outputGuest,
      timeout: Duration(seconds: limits.maxDurationSeconds),
      commandPrefix: commandPrefix,
    );
  }


  /// Reserves and resolves a Runtime Profile owned by exactly one installed
  /// Skill. Skill execution is Android PRoot-only; project profiles are not
  /// accepted here because they would broaden the execution owner scope.
  Future<RuntimeProfileExecution> resolveSkillExecution({
    required WorkspaceToolContext context,
    required String runId,
    required String skillId,
    required String requestedProfileId,
  }) async {
    await load();
    if (!RuntimeProfileValidation.isSafeId(runId) ||
        !RuntimeProfileValidation.isSafeId(skillId) ||
        !RuntimeProfileValidation.isSafeId(requestedProfileId)) {
      throw const RuntimeProfileException('invalid_skill_runtime_identity');
    }
    if (!context.paths.sandboxed) {
      throw const RuntimeProfileException('skill_execution_requires_sandboxed_context');
    }
    final profile = _profiles[requestedProfileId];
    if (profile == null) {
      throw const RuntimeProfileException('runtime_profile_not_found');
    }
    if (profile.status != RuntimeProfileStatus.ready) {
      throw RuntimeProfileException('runtime_profile_not_ready:${profile.status.name}');
    }
    if (profile.scope != RuntimeProfileScope.extension ||
        profile.ownerId != skillId) {
      throw const RuntimeProfileException('skill_runtime_profile_scope_mismatch');
    }
    _validateOwner(profile.scope, profile.ownerId, context);
    final runtime = await runtimeProvider.ensureInitialized();
    if (runtime == null) {
      throw const RuntimeProfileException('runtime_unavailable');
    }
    final status = await runtime.status();
    if (!status.ready || !status.sandboxed || status.engine != 'proot') {
      throw RuntimeProfileException(status.reason ?? 'skill_execution_requires_android_proot');
    }
    final activeForSkill = _profiles.values.any((candidate) =>
        candidate.scope == RuntimeProfileScope.extension &&
        candidate.ownerId == skillId &&
        (_activeByProfile[candidate.id]?.isNotEmpty ?? false));
    if (activeForSkill) {
      throw const RuntimeProfileException('skill_runtime_profile_busy');
    }
    final active = _activeByProfile.putIfAbsent(profile.id, () => <String>{});
    // Skill scripts share one extension profile filesystem (venv/node bin and
    // profile temp roots). Serialize them even when a general profile allows
    // higher concurrency, preventing cross-run mutation and output collisions.
    if (active.isNotEmpty) {
      throw const RuntimeProfileException('skill_runtime_profile_busy');
    }
    active.add(runId);

    final root = runtimeProfileRoot(
      profile: profile,
      workspaceRoot: context.paths.modelRoot,
      sandboxed: true,
    );
    final tempGuest = '$root/tmp/$runId';
    final outputGuest = '$root/outputs/$runId';
    final pathParts = <String>[];
    if (profile.ecosystems.contains(RuntimeProfileEcosystem.python)) {
      pathParts.add('$root/python/bin');
    }
    if (profile.ecosystems.contains(RuntimeProfileEcosystem.node)) {
      pathParts.add('$root/node/node_modules/.bin');
    }
    if (profile.shareBaseTools) {
      pathParts.addAll(['/usr/local/sbin', '/usr/local/bin', '/usr/sbin', '/usr/bin', '/sbin', '/bin']);
    } else {
      pathParts.addAll(['/usr/bin', '/bin']);
    }
    final environment = <String, String>{
      'PATH': pathParts.join(':'),
      'TMPDIR': tempGuest,
      'TMP': tempGuest,
      'TEMP': tempGuest,
      'KELIVO_TASK_OUTPUT_DIR': outputGuest,
      if (profile.ecosystems.contains(RuntimeProfileEcosystem.python)) ...{
        'VIRTUAL_ENV': '$root/python',
        'PYTHONNOUSERSITE': '1',
        'PIP_REQUIRE_VIRTUALENV': '1',
      },
      if (profile.ecosystems.contains(RuntimeProfileEcosystem.node)) ...{
        'NODE_PATH': '$root/node/node_modules',
        'npm_config_prefix': '$root/node',
      },
      // Unlike the general Workspace shell, third-party Skill processes do
      // not inherit custom Runtime Profile variables. Those values may contain
      // credentials under innocuous names; a future explicit credential grant
      // must use a separate per-run consent flow and secure secret provider.
    };
    final limits = profile.limits.normalized();
    try {
      await _cleanupInterruptedTemporaryDirectories(
        context: context,
        profile: profile,
        root: root,
      );
      final commandPrefix = 'mkdir -p ${_quote(tempGuest)} ${_quote(outputGuest)} || exit ${r'$'}?; '
          'ulimit -t ${limits.maxCpuSeconds} 2>/dev/null || true; '
          'ulimit -u ${limits.maxProcesses} 2>/dev/null || true; '
          'ulimit -v ${limits.maxMemoryMegabytes * 1024} 2>/dev/null || true; '
          'ulimit -f ${limits.maxFileMegabytes * 2048} 2>/dev/null || true; ';
      return RuntimeProfileExecution(
        profile: profile,
        environment: Map.unmodifiable(environment),
        temporaryHostPath: p.join(context.paths.workspaceHostRoot, '.kelivo', 'skill-execution', runId, 'tmp'),
        temporaryRuntimePath: tempGuest,
        outputRuntimePath: outputGuest,
        timeout: Duration(seconds: limits.maxDurationSeconds),
        commandPrefix: commandPrefix,
      );
    } catch (_) {
      releaseReservation(profile.id, runId);
      rethrow;
    }
  }

  /// Read-only command availability probe for a Skill-owned Runtime Profile.
  /// It never runs Skill entry points, package managers, lifecycle hooks or
  /// arbitrary profile environment values. Only validated command names are
  /// passed to the shell's `command -v` builtin.
  Future<Map<String, Object?>> inspectSkillProfileCommands({
    required String skillId,
    required String profileId,
    required Iterable<String> commandNames,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    await load();
    if (!RuntimeProfileValidation.isSafeId(skillId) ||
        !RuntimeProfileValidation.isSafeId(profileId)) {
      throw const RuntimeProfileException('invalid_skill_runtime_identity');
    }
    final profile = _profiles[profileId];
    if (profile == null) {
      throw const RuntimeProfileException('runtime_profile_not_found');
    }
    if (profile.scope != RuntimeProfileScope.extension ||
        profile.ownerId != skillId) {
      throw const RuntimeProfileException('skill_runtime_profile_scope_mismatch');
    }
    if (profile.status != RuntimeProfileStatus.ready) {
      return <String, Object?>{
        'status': 'profile_not_ready',
        'profileId': profile.id,
        'profileStatus': profile.status.name,
        'commands': <Map<String, Object?>>[],
      };
    }

    final uniqueCommands = commandNames
        .map((value) => value.trim())
        .where((value) => RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.+-]{0,127}$').hasMatch(value))
        .toSet()
        .take(64)
        .toList(growable: false);
    if (uniqueCommands.isEmpty) {
      return <String, Object?>{
        'status': 'not_required',
        'profileId': profile.id,
        'commands': <Map<String, Object?>>[],
        'checkedAt': DateTime.now().toUtc().toIso8601String(),
      };
    }

    final runtime = await runtimeProvider.ensureInitialized(
      timeout: const Duration(seconds: 12),
    );
    if (runtime == null) {
      return <String, Object?>{
        'status': 'runtime_unavailable',
        'profileId': profile.id,
        'commands': <Map<String, Object?>>[],
      };
    }
    final runtimeStatus = await runtime.status();
    if (!runtimeStatus.ready ||
        !runtimeStatus.sandboxed ||
        runtimeStatus.engine != 'proot') {
      return <String, Object?>{
        'status': 'unsupported_runtime',
        'profileId': profile.id,
        'runtimeEngine': runtimeStatus.engine,
        'runtimeSandboxed': runtimeStatus.sandboxed,
        'runtimeReady': runtimeStatus.ready,
        'reason': runtimeStatus.reason,
        'commands': <Map<String, Object?>>[],
      };
    }

    final root = runtimeProfileRoot(
      profile: profile,
      workspaceRoot: '/workspace',
      sandboxed: true,
    );
    final pathParts = <String>[];
    if (profile.ecosystems.contains(RuntimeProfileEcosystem.python)) {
      pathParts.add('$root/python/bin');
    }
    if (profile.ecosystems.contains(RuntimeProfileEcosystem.node)) {
      pathParts.add('$root/node/node_modules/.bin');
    }
    if (profile.shareBaseTools) {
      pathParts.addAll([
        '/usr/local/sbin', '/usr/local/bin', '/usr/sbin', '/usr/bin', '/sbin', '/bin',
      ]);
    } else {
      pathParts.addAll(['/usr/bin', '/bin']);
    }
    final pathValue = pathParts.join(':');
    final boundedTimeout = Duration(seconds: timeout.inSeconds.clamp(1, 30).toInt());
    final script = StringBuffer();
    for (var index = 0; index < uniqueCommands.length; index++) {
      final name = uniqueCommands[index];
      script.writeln(
        "if command -v '$name' >/dev/null 2>&1; then "
        "__kelivo_path=\$(command -v '$name'); "
        "printf '__KELIVO_DOCTOR_${index}=%s\\n' \"\$__kelivo_path\"; "
        "else printf '__KELIVO_DOCTOR_${index}=__MISSING__\\n'; fi",
      );
    }

    final output = StringBuffer();
    var captured = 0;
    CommandExited? exit;
    try {
      await for (final event in runtime.run(CommandRequest(
        runId: 'skill-doctor-${const Uuid().v4()}',
        command: script.toString(),
        cwd: '/',
        timeout: boundedTimeout,
        env: <String, String>{
          'HOME': '/root',
          'PATH': pathValue,
          'NO_COLOR': '1',
          'CI': 'true',
          'LANG': 'C.UTF-8',
          'TMPDIR': '/tmp',
        },
      ))) {
        if (event is CommandOutput && event.kind == OutputStreamKind.stdout && captured < 16 * 1024) {
          final available = 16 * 1024 - captured;
          final boundedBytes = event.bytes.length <= available
              ? event.bytes
              : event.bytes.take(available).toList(growable: false);
          output.write(utf8.decode(boundedBytes, allowMalformed: true));
          captured += boundedBytes.length;
        } else if (event is CommandExited) {
          exit = event;
        }
      }
    } catch (error) {
      return <String, Object?>{
        'status': 'probe_failed',
        'profileId': profile.id,
        'errorType': error.runtimeType.toString(),
        'commands': <Map<String, Object?>>[],
      };
    }
    if (exit == null || exit.timedOut || exit.cancelled || exit.interrupted || exit.exitCode != 0) {
      return <String, Object?>{
        'status': 'probe_failed',
        'profileId': profile.id,
        'timedOut': exit?.timedOut ?? false,
        'exitCode': exit?.exitCode,
        'commands': <Map<String, Object?>>[],
      };
    }

    final lines = const LineSplitter().convert(output.toString());
    final results = <Map<String, Object?>>[];
    for (var index = 0; index < uniqueCommands.length; index++) {
      final marker = '__KELIVO_DOCTOR_$index=';
      final line = lines.where((value) => value.startsWith(marker)).firstOrNull;
      final path = line == null ? null : line.substring(marker.length).trim();
      if (path == null || path.isEmpty || path == '__MISSING__') {
        results.add(<String, Object?>{
          'name': uniqueCommands[index],
          'status': path == '__MISSING__' ? 'missing' : 'unknown',
        });
        continue;
      }
      final profileOwned =
          path.startsWith('$root/python/bin/') ||
          path.startsWith('$root/node/node_modules/.bin/');
      results.add(<String, Object?>{
        'name': uniqueCommands[index],
        'status': 'installed',
        'path': path,
        'verifiedIn': profileOwned
            ? 'skill_runtime_profile'
            : 'base_proot_environment',
      });
    }
    return <String, Object?>{
      'status': 'completed',
      'profileId': profile.id,
      'checkedAt': DateTime.now().toUtc().toIso8601String(),
      'commands': results,
    };
  }

  Future<void> _cleanupInterruptedTemporaryDirectories({
    required WorkspaceToolContext context,
    required RuntimeProfile profile,
    required String root,
  }) async {
    final staleRuns = _processes.values.where((record) =>
        record.profileId == profile.id &&
        record.status == RuntimeProcessStatus.interrupted &&
        RuntimeProfileValidation.isSafeId(record.runId));
    final directories = staleRuns
        .map((record) => '$root/tmp/${record.runId}')
        .toList(growable: false);
    if (directories.isEmpty) return;
    try {
      await _runInternal(
        context: context,
        command: directories.map((path) => 'rm -rf -- ${_quote(path)}').join('; '),
        timeout: const Duration(seconds: 30),
        label: 'interrupted task temp cleanup',
      );
    } catch (error) {
      debugPrint('Runtime profile interrupted temp cleanup deferred: $error');
    }
  }


  Future<void> cleanupExecution({
    required WorkspaceToolContext context,
    required RuntimeProfileExecution execution,
  }) async {
    try {
      await _runInternal(
        context: context,
        command: 'rm -rf -- ${_quote(execution.temporaryRuntimePath)}',
        timeout: const Duration(seconds: 20),
        label: 'runtime profile temporary directory cleanup',
      );
    } catch (error) {
      debugPrint('Runtime profile temp cleanup deferred: $error');
    }
  }

  Future<RuntimeProcessRecord> recordStarted({
    required RuntimeProfileExecution execution,
    required String runtimeRunId,
    required String command,
  }) async {
    await load();
    final record = RuntimeProcessRecord(
      id: const Uuid().v4(),
      profileId: execution.profile.id,
      ownerId: execution.profile.ownerId,
      runId: runtimeRunId,
      commandLabel: _commandLabel(command),
      status: RuntimeProcessStatus.running,
      startedAt: DateTime.now().toUtc(),
      sessionId: processSessionId,
    );
    _processes[record.id] = record;
    await store.upsert(RuntimeProfileEntityKinds.processes, record.id, record.toJson());
    return record;
  }

  Future<void> recordCompleted({
    required RuntimeProfileExecution execution,
    required String runtimeRunId,
    required RuntimeProcessStatus status,
    int? exitCode,
    String? error,
  }) async {
    await load();
    final record = _processes.values
        .where((item) => item.runId == runtimeRunId && item.status == RuntimeProcessStatus.running)
        .firstOrNull;
    if (record != null) {
      final updated = record.copyWith(
        status: status,
        completedAt: DateTime.now().toUtc(),
        exitCode: exitCode,
        error: error == null ? null : _safeError(error),
      );
      _processes[record.id] = updated;
      await store.upsert(RuntimeProfileEntityKinds.processes, updated.id, updated.toJson());
    }
    _activeByProfile[execution.profile.id]?.remove(runtimeRunId);
    if (_activeByProfile[execution.profile.id]?.isEmpty == true) {
      _activeByProfile.remove(execution.profile.id);
    }
  }

  List<RuntimeProcessRecord> processHistory({String? profileId, String? ownerId}) {
    return _processes.values.where((record) {
      if (profileId != null && record.profileId != profileId) return false;
      if (ownerId != null && record.ownerId != ownerId) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  Future<void> cancelRun(String runtimeRunId) async {
    final runtime = await runtimeProvider.ensureInitialized();
    await runtime?.cancel(runtimeRunId);
  }

  void releaseReservation(String profileId, String runtimeRunId) {
    _activeByProfile[profileId]?.remove(runtimeRunId);
    if (_activeByProfile[profileId]?.isEmpty == true) {
      _activeByProfile.remove(profileId);
    }
  }

  Future<void> _runInternal({
    required WorkspaceToolContext context,
    required String command,
    required Duration timeout,
    required String label,
  }) async {
    await _runInternalCaptured(
      context: context,
      command: command,
      timeout: timeout,
      label: label,
    );
  }

  Future<String> _runInternalCaptured({
    required WorkspaceToolContext context,
    required String command,
    required Duration timeout,
    required String label,
  }) async {
    final runtime = await runtimeProvider.ensureInitialized();
    if (runtime == null) throw const RuntimeProfileException('runtime_unavailable');
    final status = await runtime.status();
    if (!status.ready) throw RuntimeProfileException(status.reason ?? 'runtime_not_ready');
    final runId = 'runtime-profile-${const Uuid().v4()}';
    var exitCode = -1;
    final stdout = StringBuffer();
    final stderr = StringBuffer();
    await for (final event in runtime.run(CommandRequest(
      runId: runId,
      command: command,
      cwd: context.cwd,
      timeout: timeout,
      env: {
        'HOME': status.sandboxed ? '/root' : (Platform.environment['HOME'] ?? ''),
        'PATH': '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
        'NO_COLOR': '1',
        'CI': 'true',
        'LANG': 'C.UTF-8',
        'TMPDIR': status.sandboxed ? '/tmp' : Directory.systemTemp.path,
      },
      mounts: context.paths.mounts,
    ))) {
      if (event is CommandOutput) {
        final text = utf8.decode(event.bytes, allowMalformed: true);
        if (event.kind == OutputStreamKind.stdout) {
          stdout.write(text);
        } else {
          stderr.write(text);
        }
        if (text.contains('__KELIVO_MISSING_BASH__')) {
          throw const RuntimeProfileException('bash_runtime_missing_install_or_select_bash');
        }
        if (text.contains('__KELIVO_MISSING_PYTHON3__')) {
          throw const RuntimeProfileException('python3_runtime_missing_install_python_first');
        }
        if (text.contains('__KELIVO_MISSING_NODE__')) {
          throw const RuntimeProfileException('node_runtime_missing_install_node_first');
        }
        if (text.contains('__KELIVO_INVALID_PROFILE_ROOT__')) {
          throw const RuntimeProfileException('invalid_runtime_profile_root');
        }
      } else if (event is CommandExited) {
        if (event.timedOut) throw RuntimeProfileException('$label timed out');
        if (event.cancelled) throw RuntimeProfileException('$label was cancelled');
        exitCode = event.exitCode;
      }
    }
    if (exitCode != 0) {
      final detail = stderr.toString().trim();
      throw RuntimeProfileException(
        '$label failed (exit $exitCode)${detail.isEmpty ? '' : ': ${_safeError(detail)}'}',
      );
    }
    return stdout.toString();
  }

  static String _snapshotDirectory({
    required RuntimeProfile profile,
    required String workspaceRoot,
    required bool sandboxed,
  }) {
    return switch (profile.scope) {
      RuntimeProfileScope.project => sandboxed
          ? p.posix.join(workspaceRoot, '.kelivo', 'runtime-profile-snapshots', profile.id)
          : p.join(workspaceRoot, '.kelivo', 'runtime-profile-snapshots', profile.id),
      RuntimeProfileScope.extension =>
        '/root/.local/share/kelivo/runtime-profile-snapshots/extensions/${profile.ownerId}/${profile.id}',
      RuntimeProfileScope.task =>
        '/root/.local/share/kelivo/runtime-profile-snapshots/tasks/${profile.ownerId}/${profile.id}',
    };
  }

  static String? _markerValue(String output, String prefix) {
    for (final line in output.split(RegExp(r'\r?\n'))) {
      if (line.startsWith(prefix)) return line.substring(prefix.length).trim();
    }
    return null;
  }

  static String? _safeSnapshotLabel(String? value) {
    final normalized = value?.replaceAll(RegExp(r'[\x00-\x1f]+'), ' ').trim();
    if (normalized == null || normalized.isEmpty) return null;
    return normalized.length <= 80 ? normalized : normalized.substring(0, 80);
  }

  void _validateOwner(
    RuntimeProfileScope scope,
    String ownerId,
    WorkspaceToolContext context,
  ) {
    if (scope == RuntimeProfileScope.project && ownerId != context.workspace.id) {
      throw const RuntimeProfileException('runtime_profile_workspace_mismatch');
    }
    if (!RuntimeProfileValidation.isSafeId(ownerId)) {
      throw const RuntimeProfileException('invalid_runtime_profile_owner_id');
    }
  }

  static String _quote(String value) => "'${value.replaceAll("'", "'\\''")}'";

  static String _commandLabel(String command) {
    final match = RegExp(r'^\s*([A-Za-z0-9_./-]+)').firstMatch(command);
    return match?.group(1)?.split('/').last ?? 'shell command';
  }

  static String _safeError(Object error) {
    final value = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return value.length > 240 ? '${value.substring(0, 240)}…' : value;
  }
}

class RuntimeProfileException implements Exception {
  const RuntimeProfileException(this.code);
  final String code;
  @override
  String toString() => code;
}
