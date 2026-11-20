import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/services/packages/dependency_manifest_parser.dart';
import 'package:Kelivo/core/services/packages/package_ledger_store.dart';
import 'package:Kelivo/core/services/packages/package_manager_adapters.dart';
import 'package:Kelivo/core/services/packages/package_manager_models.dart';
import 'package:Kelivo/core/services/skills/skill_frontmatter.dart';
import 'package:Kelivo/core/services/skills/skills_service.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/core/services/runtime_profiles/runtime_profile_service.dart';
import 'package:Kelivo/core/services/workspace/workspace_tool_context.dart';

/// Conversation-facing package manager for the active PRoot/runtime.
///
/// Only validated registry package names and exact version pins reach command
/// builders. Manifest parsing is read-only. Mutating actions must be gated by
/// ToolPermissionService in the conversation handler before calling [handle].
final class PackageManagerService {
  PackageManagerService({
    required this.runtime,
    required this.environment,
    required BusinessPreferences preferences,
    this.workspace,
    this.skills,
    this.runtimeProfiles,
    PackageManagerAdapterRegistry? adapterRegistry,
  }) : ledger = PackageLedgerStore(preferences),
       adapterRegistry = adapterRegistry ?? PackageManagerAdapters.createRegistry();

  final WorkspaceRuntime? runtime;
  final EnvironmentProvider environment;
  final PackageLedgerStore ledger;
  final WorkspaceToolContext? workspace;
  final SkillsService? skills;
  final RuntimeProfileService? runtimeProfiles;
  final PackageManagerAdapterRegistry adapterRegistry;

  static const int maxPackagesPerOperation = 24;
  static const int maxOutputBytes = 64 * 1024;
  static const Duration _checkTimeout = Duration(seconds: 90);
  static const Duration _installTimeout = Duration(minutes: 45);

  /// A bounded, read-only view of packages tracked by KELIVO's isolated
  /// runtime/project/extension/task package scopes. This ledger complements
  /// the live package-manager inventory collected inside the guest RootFS.
  Future<Map<String, Object?>> inventorySnapshot({
    String detail = 'summary',
    int maxItems = 100,
  }) async {
    if (!const {'summary', 'full'}.contains(detail)) {
      throw const FormatException('invalid_package_inventory_detail');
    }
    final limit = maxItems.clamp(1, 500).toInt();
    await ledger.load();
    final entries = ledger.entries();
    final managerCounts = <String, int>{};
    final scopeCounts = <String, int>{};
    final statusCounts = <String, int>{};
    for (final entry in entries) {
      managerCounts.update(entry.manager, (count) => count + 1, ifAbsent: () => 1);
      scopeCounts.update(entry.scopeKey, (count) => count + 1, ifAbsent: () => 1);
      statusCounts.update(entry.status, (count) => count + 1, ifAbsent: () => 1);
    }
    return <String, Object?>{
      'source': 'kelivo_package_ledger',
      'liveVerification': false,
      'recordCount': entries.length,
      'managerCounts': managerCounts,
      'scopeCounts': scopeCounts,
      'statusCounts': statusCounts,
      if (detail == 'full')
        'entries': entries
            .take(limit)
            .map((entry) => entry.toJson())
            .toList(growable: false),
      'truncated': detail == 'full' && entries.length > limit,
      'maxItems': limit,
      'note': 'These are KELIVO-managed package records across isolated scopes; live OS and active ecosystem package inventories are reported separately.',
    };
  }

  Future<String> handle(Map<String, dynamic> arguments) async {
    try {
      final action = PackageActionName.parse(arguments['action']);
      await ledger.load();
      if (action == PackageAction.list) {
        return _json(_listResult(arguments));
      }

      final scope = PackageScopeName.parse(arguments['scope']);
      final requestedManager =
          PackageManagerIdName.parse(arguments['manager']);
      final manifestPath = _optionalString(arguments['manifest_path']);
      PackageManifest? manifest;
      if (manifestPath != null) {
        manifest = await _readManifest(manifestPath);
      }
      final skillId = _optionalString(arguments['skill_id']);
      if (skillId != null) {
        final skillManifest = await _readSkillManifest(skillId);
        manifest = _combineManifests(manifest, skillManifest);
      }

      final packages = _parsePackages(
        arguments['packages'],
        arguments['package'],
        defaultVersion: _optionalString(arguments['version']),
      );
      final merged = _mergePackages(packages, manifest?.packages ?? const []);
      if (action != PackageAction.pin &&
          action != PackageAction.unpin &&
          merged.isEmpty) {
        throw const FormatException('no_packages_or_supported_manifest');
      }
      if (merged.length > maxPackagesPerOperation) {
        throw const FormatException('too_many_packages_max_24');
      }

      if (action == PackageAction.pin || action == PackageAction.unpin) {
        final manager = requestedManager == PackageManagerId.auto
            ? (manifest?.manager ??
                _managerFromLedger(merged, scope: scope, arguments: arguments))
            : requestedManager;
        if (manager == PackageManagerId.auto) {
          throw const FormatException('manager_required_for_pin_operation');
        }
        await _validateProfileTarget(
          arguments: arguments,
          scope: scope,
          ecosystem: _ecosystemForManager(manager),
        );
        return _json(await _pinOperation(
          action: action,
          manager: manager,
          scope: scope,
          packages: merged,
          arguments: arguments,
        ));
      }

      final runtimeInstance = runtime;
      if (runtimeInstance == null) {
        throw const PackageManagerException(
          'runtime_unavailable',
          'The Android/Linux package runtime is not registered.',
        );
      }
      await environment.loaded;
      if (environment.state.phase != EnvironmentPhase.ready) {
        throw const PackageManagerException(
          'environment_not_ready',
          'Install or start the PRoot environment before managing packages.',
        );
      }
      final runtimeStatus = await runtimeInstance.status();
      if (!runtimeStatus.ready) {
        throw PackageManagerException(
          'runtime_not_ready',
          runtimeStatus.reason ?? 'The package runtime is not ready.',
        );
      }
      final availability = await _detectManagers(runtimeInstance);
      final nodeLockfile = await _nodeLockfileName();
      final manifestEcosystem = manifest?.kind ??
          _parseEcosystem(arguments['ecosystem']);
      final resolvedManager = requestedManager != PackageManagerId.auto
          ? requestedManager
          : (manifest?.manager ?? resolvePackageManager(
        requested: requestedManager,
        manifestEcosystem: manifestEcosystem,
        distro: environment.state.distro,
        availability: availability,
        nodeLockfile: nodeLockfile,
      ));
      if (resolvedManager == PackageManagerId.auto) {
        throw const PackageManagerException(
          'package_manager_not_detected',
          'No compatible package manager was detected. Choose apt/apk, pip/uv or a Node package manager explicitly after installing its runtime.',
        );
      }
      final adapter = adapterRegistry.byId(resolvedManager);
      if (adapter == null || !adapter.supportsDistro(environment.state.distro)) {
        throw PackageManagerException(
          'package_manager_not_supported',
          '${resolvedManager.name} is not supported by the active ${environment.state.distro ?? 'unknown'} environment.',
        );
      }
      final missingCommands = adapter.requiredCommands
          .where((command) => !availability.has(command))
          .toList();
      if (missingCommands.isNotEmpty) {
        throw PackageManagerException(
          'package_manager_unavailable',
          '${resolvedManager.name} is missing required commands: ${missingCommands.join(', ')}.',
        );
      }
      if (manifestEcosystem != null &&
          manifestEcosystem != adapter.ecosystem) {
        throw const PackageManagerException(
          'manifest_manager_mismatch',
          'The selected package manager does not match the manifest ecosystem.',
        );
      }
      for (final package in merged) {
        final issue = package.validate(resolvedManager);
        if (issue != null) {
          throw PackageManagerException(
            issue,
            'Invalid package reference: ${package.name}. Use a registry package name and an exact version, not a URL, git source, shell option or command.',
          );
        }
      }
      await _validateProfileTarget(
        arguments: arguments,
        scope: scope,
        ecosystem: adapter.ecosystem,
      );
      final target = _resolveTarget(
        scope: scope,
        ecosystem: adapter.ecosystem,
        arguments: arguments,
      );
      if (adapter.ecosystem == PackageEcosystem.system &&
          scope != PackageScope.runtime) {
        throw const PackageManagerException(
          'system_packages_are_runtime_scoped',
          'apt/apk packages modify the shared PRoot runtime and cannot be isolated to a project, extension or task.',
        );
      }

      if (action == PackageAction.plan) {
        return _json(_planResult(
          manager: resolvedManager,
          target: target,
          packages: merged,
          manifest: manifest,
          availability: availability,
        ));
      }

      final unresolvedManifestPins = (manifest?.warnings ?? const <String>[])
          .where((warning) => warning.startsWith('version_range_not_locked:'))
          .map((warning) => warning.substring('version_range_not_locked:'.length).toLowerCase())
          .where((name) => merged.any(
            (package) => package.normalizedName == name && package.version == null,
          ))
          .toList();
      if ((action == PackageAction.install || action == PackageAction.upgrade) &&
          unresolvedManifestPins.isNotEmpty) {
        throw const PackageManagerException(
          'manifest_requires_exact_versions',
          'The manifest contains version ranges. Resolve them to exact versions before applying this dependency set; use action=plan to review the packages and warnings.',
        );
      }

      if (action == PackageAction.check) {
        final inspections = <Map<String, Object?>>[];
        for (final package in merged) {
          inspections.add(await _inspectPackage(
            adapter,
            package,
            target,
          ));
        }
        return _json({
          'ok': true,
          'action': action.name,
          'manager': resolvedManager.name,
          'scope': scope.name,
          'scopePath': target.displayPath,
          'packages': inspections,
          'manifestWarnings': manifest?.warnings ?? const <String>[],
        });
      }

      return _json(await _mutate(
        action: action,
        manager: resolvedManager,
        adapter: adapter,
        target: target,
        packages: merged,
        manifest: manifest,
        verifyBinaries: _parseBinaries(arguments['verify_binaries']),
        allowScripts: arguments['allow_install_scripts'] == true,
        allowSourceBuilds: arguments['allow_source_builds'] == true,
      ));
    } on PackageManagerException catch (error) {
      return _json({
        'ok': false,
        'error': error.code,
        'message': error.message,
      });
    } on FormatException catch (error) {
      return _json({
        'ok': false,
        'error': 'invalid_request',
        'message': error.message,
      });
    } catch (error, stack) {
      debugPrint('Package manager failed: $error\n$stack');
      return _json({
        'ok': false,
        'error': 'package_manager_failed',
        'message': error.toString(),
      });
    }
  }

  Future<Map<String, Object?>> _mutate({
    required PackageAction action,
    required PackageManagerId manager,
    required PackageManagerAdapter adapter,
    required PackageScopeTarget target,
    required List<PackageSpec> packages,
    required PackageManifest? manifest,
    required List<String> verifyBinaries,
    required bool allowScripts,
    required bool allowSourceBuilds,
  }) async {
    if (action != PackageAction.install &&
        action != PackageAction.upgrade &&
        action != PackageAction.remove) {
      throw const FormatException('unsupported_package_action');
    }
    final startedAt = DateTime.now().toUtc();
    final logs = <String>[];
    final changed = <_PackageRollbackSnapshot>[];
    final outcomes = <Map<String, Object?>>[];
    final operationId = const Uuid().v4();
    final initialStates = <String, Map<String, Object?>>{};
    var prepared = false;
    String? environmentSnapshotId;
    String? profileReservationId;
    var profileReserved = false;
    try {
      // Profile-scoped dependency changes share the Skill execution lock and
      // always take a full package-root checkpoint before the first mutation.
      // Runtime-wide apt/apk operations are intentionally excluded because
      // their RootFS is shared rather than profile-isolated.
      if (target.profileId != null) {
        final profiles = runtimeProfiles;
        final context = workspace;
        if (profiles == null || context == null) {
          throw const PackageManagerException(
            'runtime_profile_snapshot_service_unavailable',
            'A Runtime Profile service and bound workspace are required for isolated dependency updates.',
          );
        }
        profileReservationId = 'package-$operationId';
        await profiles.reserveMaintenance(
          profileId: target.profileId!,
          context: context,
          reservationId: profileReservationId,
        );
        profileReserved = true;
        final snapshot = await profiles.createSnapshot(
          profileId: target.profileId!,
          context: context,
          label: 'Before ${action.name} ${manager.name}',
          reservationId: profileReservationId,
          pruneOldestSnapshots: true,
        );
        environmentSnapshotId = snapshot.id;
      }
      // Capture the package versions before the first side effect. The durable
      // operation record doubles as a recovery snapshot if the app is killed.
      for (final package in packages) {
        initialStates[package.normalizedName] =
            await _inspectPackage(adapter, package, target);
      }
      final previousPackages = initialStates.values.toList();
      await ledger.recordOperation({
        'operationId': operationId,
        'action': action.name,
        'manager': manager.name,
        'scope': target.key,
        'status': 'started',
        'previousPackages': previousPackages,
        if (environmentSnapshotId != null)
          'environmentSnapshotId': environmentSnapshotId,
        'startedAt': startedAt.toIso8601String(),
      });
      for (final requested in packages) {
        final record = ledger.find(
          scopeKey: target.key,
          packageName: requested.name,
        );
        final spec = PackageSpec(
          name: requested.name,
          version: requested.version,
        );
        final pinnedVersion = spec.version ?? record?.pinnedVersion;
        final before = initialStates[spec.normalizedName] ??
            await _inspectPackage(adapter, spec, target);
        final installed = before['installed'] == true;
        final actualVersion = before['version'] as String?;

        if (action == PackageAction.install &&
            installed &&
            (pinnedVersion == null || actualVersion == pinnedVersion)) {
          outcomes.add({
            'name': spec.name,
            'status': 'already_installed',
            'version': actualVersion,
          });
          continue;
        }
        if (action == PackageAction.upgrade && !installed) {
          throw PackageManagerException(
            'package_not_installed',
            '${spec.name} is not installed; use install instead of upgrade.',
          );
        }
        if (action == PackageAction.remove && !installed) {
          outcomes.add({'name': spec.name, 'status': 'already_absent'});
          continue;
        }

        final command = switch (action) {
          PackageAction.install => adapter.installCommand(
            spec,
            target,
            pinnedVersion: pinnedVersion,
            allowScripts: allowScripts,
            allowSourceBuilds: allowSourceBuilds,
          ),
          PackageAction.upgrade => adapter.upgradeCommand(
            spec,
            target,
            pinnedVersion: pinnedVersion,
            allowScripts: allowScripts,
            allowSourceBuilds: allowSourceBuilds,
          ),
          PackageAction.remove => adapter.removeCommand(
            spec,
            target,
            allowScripts: allowScripts,
          ),
          _ => throw const FormatException('invalid_mutating_action'),
        };
        if ((action == PackageAction.install || action == PackageAction.upgrade) &&
            !prepared &&
            adapter.prepareInstallCommand(target) != null) {
          await _run(
            adapter.prepareInstallCommand(target)!,
            cwd: target.cwd,
            timeout: const Duration(minutes: 20),
            logs: logs,
          );
          prepared = true;
        }
        changed.add(_PackageRollbackSnapshot(
          package: PackageSpec(name: spec.name),
          previousVersion: actualVersion,
          wasInstalled: installed,
          previousRecord: record,
        ));
        await _run(
          command,
          cwd: target.cwd,
          timeout: _installTimeout,
          logs: logs,
        );
        final after = await _inspectPackage(adapter, spec, target);
        final isNowInstalled = after['installed'] == true;
        if (action == PackageAction.remove && isNowInstalled) {
          throw PackageManagerException(
            'package_remove_verification_failed',
            '${spec.name} is still detected after removal.',
          );
        }
        if (action != PackageAction.remove && !isNowInstalled) {
          throw PackageManagerException(
            'package_install_verification_failed',
            '${spec.name} was not detected after ${action.name}.',
          );
        }
        if (pinnedVersion != null &&
            action != PackageAction.remove &&
            after['version'] != pinnedVersion) {
          throw PackageManagerException(
            'package_version_mismatch',
            '${spec.name} resolved to ${after['version'] ?? 'unknown'}, expected $pinnedVersion.',
          );
        }

        if (action == PackageAction.remove) {
          await ledger.upsert(PackageLedgerEntry(
            scopeKey: target.key,
            manager: manager.name,
            name: spec.name,
            installedVersion: actualVersion,
            pinnedVersion: record?.pinnedVersion,
            status: 'removed',
            sourceManifest: manifest == null ? null : 'manifest',
            updatedAt: DateTime.now().toUtc(),
          ));
        } else {
          await ledger.upsert(PackageLedgerEntry(
            scopeKey: target.key,
            manager: manager.name,
            name: spec.name,
            installedVersion: after['version'] as String?,
            pinnedVersion: record?.pinnedVersion,
            status: 'installed',
            sourceManifest: manifest == null ? null : 'manifest',
            updatedAt: DateTime.now().toUtc(),
          ));
        }
        outcomes.add({
          'name': spec.name,
          'status': action == PackageAction.remove ? 'removed' : 'installed',
          'version': after['version'],
          'previousVersion': actualVersion,
        });
      }

      if (action != PackageAction.remove && verifyBinaries.isNotEmpty) {
        final missing = await _verifyBinaries(verifyBinaries, target, logs);
        if (missing.isNotEmpty) {
          throw PackageManagerException(
            'binary_verification_failed',
            'The package operation completed, but these commands are not on PATH: ${missing.join(', ')}.',
          );
        }
      }
      final lockfile = await _writeLockfile(manager, target, logs);
      await ledger.recordOperation({
        'operationId': operationId,
        'action': action.name,
        'manager': manager.name,
        'scope': target.key,
        'packages': packages.map((package) => package.toJson()).toList(),
        'previousPackages': initialStates.values.toList(),
        'results': outcomes,
        if (environmentSnapshotId != null)
          'environmentSnapshotId': environmentSnapshotId,
        'allowInstallScripts': allowScripts,
        'allowSourceBuilds': allowSourceBuilds,
        'status': 'succeeded',
        'startedAt': startedAt.toIso8601String(),
        'completedAt': DateTime.now().toUtc().toIso8601String(),
      });
      await environment.clearCachedDiskUsage();
      return {
        'ok': true,
        'action': action.name,
        'manager': manager.name,
        'scope': target.key,
        'scopePath': target.displayPath,
        'packages': outcomes,
        'manifestWarnings': manifest?.warnings ?? const <String>[],
        'lockfile': lockfile,
        'compatibilityWarnings': _compatibilityWarnings(manager, environment.state.arch),
        'log': _tail(logs.join('\n')),
      };
    } catch (error) {
      var rollback = <Map<String, Object?>>[];
      var environmentRestored = false;
      if (environmentSnapshotId != null &&
          profileReservationId != null &&
          runtimeProfiles != null &&
          workspace != null) {
        try {
          await runtimeProfiles!.restoreSnapshot(
            snapshotId: environmentSnapshotId,
            context: workspace!,
            reservationId: profileReservationId,
          );
          environmentRestored = true;
          rollback = [
            {
              'status': 'runtime_profile_snapshot_restored',
              'snapshotId': environmentSnapshotId,
            },
          ];
        } catch (snapshotError) {
          logs.add('Environment snapshot restore failed: $snapshotError');
        }
      }
      if (!environmentRestored) {
        rollback = await _rollbackChanges(
          adapter,
          target,
          changed,
          logs,
        );
      }
      await ledger.recordOperation({
        'operationId': operationId,
        'action': action.name,
        'manager': manager.name,
        'scope': target.key,
        'packages': packages.map((package) => package.toJson()).toList(),
        'previousPackages': initialStates.values.toList(),
        'results': outcomes,
        'allowInstallScripts': allowScripts,
        'allowSourceBuilds': allowSourceBuilds,
        'status': 'failed',
        'error': error.toString(),
        'rollback': rollback,
        if (environmentSnapshotId != null)
          'environmentSnapshotId': environmentSnapshotId,
        'environmentSnapshotRestored': environmentRestored,
        'startedAt': startedAt.toIso8601String(),
        'completedAt': DateTime.now().toUtc().toIso8601String(),
      });
      return {
        'ok': false,
        'action': action.name,
        'manager': manager.name,
        'scope': target.key,
        'error': error.toString(),
        'packagesCompletedBeforeFailure': outcomes,
        'rollback': rollback,
        if (environmentSnapshotId != null)
          'environmentSnapshotId': environmentSnapshotId,
        'environmentSnapshotRestored': environmentRestored,
        'log': _tail(logs.join('\n')),
      };
    } finally {
      if (profileReserved && profileReservationId != null && target.profileId != null) {
        runtimeProfiles?.releaseReservation(target.profileId!, profileReservationId);
      }
    }
  }

  Future<List<Map<String, Object?>>> _rollbackChanges(
    PackageManagerAdapter adapter,
    PackageScopeTarget target,
    List<_PackageRollbackSnapshot> changed,
    List<String> logs,
  ) async {
    final results = <Map<String, Object?>>[];
    for (final snapshot in changed.reversed) {
      try {
        if (snapshot.wasInstalled) {
          final oldVersion = snapshot.previousVersion;
          if (oldVersion == null || oldVersion.isEmpty) {
            throw StateError('previous_version_unavailable');
          }
          await _run(
            adapter.installCommand(
              PackageSpec(name: snapshot.package.name, version: oldVersion),
              target,
            ),
            cwd: target.cwd,
            timeout: _installTimeout,
            logs: logs,
          );
          final previousRecord = snapshot.previousRecord;
          if (previousRecord != null) {
            await ledger.upsert(previousRecord);
          } else {
            await ledger.remove(
              scopeKey: target.key,
              packageName: snapshot.package.name,
            );
          }
          results.add({
            'name': snapshot.package.name,
            'status': 'previous_version_restored',
            'version': oldVersion,
          });
        } else {
          final current = await _inspectPackage(adapter, snapshot.package, target);
          if (current['installed'] == true) {
            await _run(
              adapter.removeCommand(snapshot.package, target),
              cwd: target.cwd,
              timeout: _installTimeout,
              logs: logs,
            );
          }
          await ledger.remove(
            scopeKey: target.key,
            packageName: snapshot.package.name,
          );
          results.add({'name': snapshot.package.name, 'status': 'removed'});
        }
      } catch (error) {
        await ledger.upsert(PackageLedgerEntry(
          scopeKey: target.key,
          manager: adapter.id.name,
          name: snapshot.package.name,
          installedVersion: snapshot.previousVersion,
          pinnedVersion: snapshot.previousRecord?.pinnedVersion,
          status: 'rollback_failed',
          sourceManifest: snapshot.previousRecord?.sourceManifest,
          updatedAt: DateTime.now().toUtc(),
        ));
        results.add({
          'name': snapshot.package.name,
          'status': 'rollback_failed',
          'error': error.toString(),
        });
      }
    }
    return results;
  }

  Future<Map<String, Object?>> _inspectPackage(
    PackageManagerAdapter adapter,
    PackageSpec package,
    PackageScopeTarget target,
  ) async {
    final result = await _run(
      adapter.checkCommand(package, target),
      cwd: target.cwd,
      timeout: _checkTimeout,
      allowFailure: true,
    );
    final lines = result.stdout.split(RegExp(r'\r?\n'));
    final installedLine = lines.firstWhere(
      (line) => line.startsWith('__KELIVO_INSTALLED__|'),
      orElse: () => '',
    );
    if (installedLine.isEmpty) {
      return {
        'name': package.name,
        'installed': false,
        'version': null,
      };
    }
    final version = installedLine.substring('__KELIVO_INSTALLED__|'.length).trim();
    return {
      'name': package.name,
      'installed': true,
      'version': _versionFromManagerOutput(adapter.id, package.name, version),
    };
  }

  String? _versionFromManagerOutput(
    PackageManagerId manager,
    String packageName,
    String raw,
  ) {
    if (raw.isEmpty) return null;
    if (manager == PackageManagerId.apk) {
      final prefix = '$packageName-';
      return raw.startsWith(prefix) ? raw.substring(prefix.length) : raw;
    }
    return raw;
  }

  Future<PackageManagerAvailability> _detectManagers(
    WorkspaceRuntime runtimeInstance,
  ) async {
    final result = await _run(
      packageManagerDetectionScript,
      cwd: '/',
      timeout: _checkTimeout,
      runtimeOverride: runtimeInstance,
    );
    final commands = <String>{};
    for (final line in result.stdout.split(RegExp(r'\r?\n'))) {
      if (line.startsWith('__KELIVO_PM_COMMAND__|')) {
        commands.add(line.substring('__KELIVO_PM_COMMAND__|'.length).trim());
      }
    }
    var architecture = environment.state.arch;
    for (final line in result.stdout.split(RegExp(r'\r?\n'))) {
      if (line.startsWith('__KELIVO_PM_ARCH__|')) {
        architecture = line.substring('__KELIVO_PM_ARCH__|'.length).trim();
      }
    }
    return PackageManagerAvailability(
      commands: commands,
      distro: environment.state.distro,
      architecture: architecture,
    );
  }

  Future<String?> _nodeLockfileName() async {
    final context = workspace;
    if (context == null || context.skillsOnly) return null;
    const names = [
      'pnpm-lock.yaml',
      'yarn.lock',
      'bun.lock',
      'bun.lockb',
      'package-lock.json',
    ];
    final existing = <String>[];
    for (final name in names) {
      try {
        final file = await context.paths.resolveReal(
          name,
          cwd: context.paths.modelRoot,
        );
        if (await File(file.hostPath).exists()) existing.add(name);
      } catch (_) {}
    }
    return DependencyManifestParser.nodeLockfileFromNames(existing);
  }

  Future<PackageManifest> _readManifest(String path) async {
    final context = workspace;
    if (context == null || context.skillsOnly) {
      throw const PackageManagerException(
        'workspace_required',
        'A bound workspace is required to read dependency manifests.',
      );
    }
    final resolved = await context.paths.resolveReal(
      path,
      cwd: context.cwd,
    );
    if (resolved.zone != WorkspaceZone.workspace) {
      throw const PackageManagerException(
        'manifest_outside_workspace',
        'Dependency manifests must be inside the active workspace.',
      );
    }
    final file = File(resolved.hostPath);
    if (!await file.exists()) {
      throw const PackageManagerException(
        'manifest_not_found',
        'The requested dependency manifest does not exist.',
      );
    }
    final length = await file.length();
    if (length > 1024 * 1024) {
      throw const PackageManagerException(
        'manifest_too_large',
        'Dependency manifests larger than 1 MB are not supported.',
      );
    }
    return DependencyManifestParser.parse(
      path,
      await file.readAsString(),
    );
  }

  Future<PackageManifest> _readSkillManifest(String skillId) async {
    final service = skills;
    if (service == null) {
      throw const PackageManagerException(
        'skills_service_unavailable',
        'Kelivo could not access the installed Skill metadata.',
      );
    }
    await service.loaded;
    final matches = service.skills.where((skill) => skill.record.id == skillId);
    if (matches.isEmpty) {
      throw const PackageManagerException(
        'skill_not_found',
        'The requested Skill is not installed.',
      );
    }
    final skill = matches.first;
    if (!skill.record.enabled) {
      throw const PackageManagerException(
        'skill_disabled',
        'Enable this Skill before using its declared package dependencies.',
      );
    }
    final file = File(skill.skillMdPath);
    if (!await file.exists()) {
      throw const PackageManagerException(
        'skill_manifest_not_found',
        'The installed Skill has no readable SKILL.md file.',
      );
    }
    final length = await file.length();
    if (length > 1024 * 1024) {
      throw const PackageManagerException(
        'skill_manifest_too_large',
        'SKILL.md files larger than 1 MB are not supported for dependency parsing.',
      );
    }
    final markdown = await file.readAsString();
    final frontmatter = SkillFrontmatter.parse(markdown);
    if (frontmatter.parseError != null ||
        !frontmatter.hasFrontmatter ||
        !frontmatter.metadataIsValid) {
      throw PackageManagerException(
        'invalid_skill_frontmatter',
        frontmatter.parseError ??
            (!frontmatter.metadataIsValid
                ? 'The Skill metadata must contain string keys and values.'
                : 'The Skill frontmatter is missing.'),
      );
    }
    return DependencyManifestParser.parseSkillMetadata(frontmatter.metadata);
  }

  PackageManifest? _combineManifests(
    PackageManifest? first,
    PackageManifest second,
  ) {
    if (first == null) return second;
    if (first.kind != second.kind ||
        (first.manager != null &&
            second.manager != null &&
            first.manager != second.manager)) {
      throw const PackageManagerException(
        'mixed_manifest_ecosystems',
        'A project manifest and Skill metadata cannot be combined when they require different package ecosystems or managers. Run separate package-manager plans for each ecosystem.',
      );
    }
    final firstByName = {
      for (final package in first.packages) package.normalizedName: package,
    };
    for (final package in second.packages) {
      final existing = firstByName[package.normalizedName];
      if (existing?.version != null &&
          package.version != null &&
          existing!.version != package.version) {
        throw PackageManagerException(
          'manifest_version_conflict',
          'Conflicting exact versions are declared for ${package.name}. Resolve the project manifest and Skill metadata before installing.',
        );
      }
    }
    final mergedByName = <String, PackageSpec>{
      for (final package in first.packages) package.normalizedName: package,
    };
    for (final package in second.packages) {
      final current = mergedByName[package.normalizedName];
      if (current == null ||
          (current.version == null && package.version != null)) {
        mergedByName[package.normalizedName] = package;
      }
    }
    final mergedPackages = mergedByName.values.toList();
    final exactNames = mergedPackages
        .where((package) => package.version != null)
        .map((package) => package.normalizedName)
        .toSet();
    final warnings = [...first.warnings, ...second.warnings].where((warning) {
      if (!warning.startsWith('version_range_not_locked:')) return true;
      final name = warning.substring('version_range_not_locked:'.length).toLowerCase();
      return !exactNames.contains(name);
    }).toSet().toList();
    return PackageManifest(
      kind: first.kind,
      manager: first.manager ?? second.manager,
      packages: List.unmodifiable(mergedPackages),
      warnings: warnings,
    );
  }

  PackageEcosystem _ecosystemForManager(PackageManagerId manager) => switch (manager) {
    PackageManagerId.apt || PackageManagerId.apk => PackageEcosystem.system,
    PackageManagerId.pip || PackageManagerId.uv => PackageEcosystem.python,
    PackageManagerId.npm || PackageManagerId.pnpm || PackageManagerId.yarn || PackageManagerId.bun => PackageEcosystem.node,
    PackageManagerId.auto => throw const FormatException('manager_not_resolved'),
  };

  Future<void> _validateProfileTarget({
    required Map<String, dynamic> arguments,
    required PackageScope scope,
    required PackageEcosystem ecosystem,
  }) async {
    final profileId = _profileIdForScope(
      arguments: arguments,
      scope: scope,
      ecosystem: ecosystem,
    );
    if (scope == PackageScope.extension &&
        ecosystem != PackageEcosystem.system &&
        profileId == null) {
      throw const PackageManagerException(
        'extension_runtime_profile_required',
        'Create or select a Runtime Profile owned by this Skill before planning or changing Python/Node packages.',
      );
    }
    if (profileId == null) return;
    if (scope == PackageScope.runtime || ecosystem == PackageEcosystem.system) {
      throw const PackageManagerException(
        'runtime_profile_not_supported_for_system_packages',
        'apt/apk packages modify the shared PRoot runtime and cannot be installed into a Runtime Profile.',
      );
    }
    final ownerId = switch (scope) {
      PackageScope.project => workspace?.workspace.id,
      PackageScope.extension => _optionalString(arguments['extension_id'] ?? arguments['skill_id']),
      PackageScope.task => _optionalString(arguments['task_id']),
      PackageScope.runtime => null,
    };
    final profiles = runtimeProfiles;
    if (ownerId == null || profiles == null) {
      throw const PackageManagerException(
        'runtime_profile_unavailable',
        'A matching Runtime Profile is required for profile-scoped package operations.',
      );
    }
    try {
      await profiles.validatePackageTarget(
        profileId: profileId,
        scope: scope.name,
        ownerId: ownerId,
        ecosystem: ecosystem.name,
      );
    } on RuntimeProfileException catch (error) {
      throw PackageManagerException(error.code, error.code);
    }
  }

  String? _profileIdForScope({
    required Map<String, dynamic> arguments,
    required PackageScope scope,
    required PackageEcosystem ecosystem,
  }) {
    final explicit = _optionalString(arguments['profile_id']);
    if (explicit != null) return explicit;
    // A project default profile is the natural target for Python/Node
    // operations. System package managers remain shared PRoot operations and
    // must never be redirected into a virtual environment.
    if (scope == PackageScope.project && ecosystem != PackageEcosystem.system) {
      return workspace?.workspace.defaultRuntimeProfileId;
    }
    return null;
  }

  PackageScopeTarget _resolveTarget({
    required PackageScope scope,
    required PackageEcosystem ecosystem,
    required Map<String, dynamic> arguments,
  }) {
    switch (scope) {
      case PackageScope.runtime:
        return PackageScopeTarget.runtime(ecosystem);
      case PackageScope.project:
        final context = workspace;
        if (context == null || context.skillsOnly) {
          throw const PackageManagerException(
            'workspace_required',
            'Bind a workspace before installing project-scoped dependencies.',
          );
        }
        return PackageScopeTarget.project(
          workspaceId: context.workspace.id,
          workspaceRoot: context.paths.modelRoot,
          sandboxed: context.paths.sandboxed,
          ecosystem: ecosystem,
          profileId: _profileIdForScope(
            arguments: arguments,
            scope: scope,
            ecosystem: ecosystem,
          ),
        );
      case PackageScope.extension:
        final id = _requiredString(
          arguments['extension_id'] ?? arguments['skill_id'],
          'extension_id',
        );
        return PackageScopeTarget.extension(
          id,
          ecosystem,
          profileId: _optionalString(arguments['profile_id']),
        );
      case PackageScope.task:
        final id = _requiredString(arguments['task_id'], 'task_id');
        return PackageScopeTarget.task(
          id,
          ecosystem,
          profileId: _optionalString(arguments['profile_id']),
        );
    }
  }

  Map<String, Object?> _planResult({
    required PackageManagerId manager,
    required PackageScopeTarget target,
    required List<PackageSpec> packages,
    required PackageManifest? manifest,
    required PackageManagerAvailability availability,
  }) => {
    'ok': true,
    'action': 'plan',
    'manager': manager.name,
    'scope': target.key,
    'scopePath': target.displayPath,
    'packages': packages.map((package) => package.toJson()).toList(),
    'availablePackageManagers': availability.commands.toList()..sort(),
    'manifestWarnings': manifest?.warnings ?? const <String>[],
    'compatibilityWarnings': _compatibilityWarnings(manager, availability.architecture),
    'requiresApproval': true,
    'sideEffects': false,
    'notes': [
      if (manager == PackageManagerId.apt || manager == PackageManagerId.apk)
        'OS packages change the shared PRoot runtime and are runtime-scoped.',
      if (manager == PackageManagerId.pip || manager == PackageManagerId.uv)
        'Python packages are isolated in a per-scope virtual environment. Source builds are disabled by default.',
      if ([PackageManagerId.npm, PackageManagerId.pnpm, PackageManagerId.yarn, PackageManagerId.bun].contains(manager))
        'Node package lifecycle scripts are disabled by default. Enable them only for a package you trust.',
      if (manager == PackageManagerId.npm ||
          manager == PackageManagerId.pnpm ||
          manager == PackageManagerId.yarn ||
          manager == PackageManagerId.bun)
        'Node packages are isolated in a per-scope prefix with a native lockfile.',
      'Package names are registry-only in this phase; URLs and VCS references are rejected.',
    ],
  };

  Map<String, Object?> _listResult(Map<String, dynamic> arguments) {
    final scope = _optionalString(arguments['scope_key']);
    final entries = ledger.entries()
        .where((entry) =>
            scope == null ||
            entry.scopeKey == scope ||
            entry.scopeKey.startsWith('$scope:'))
        .map((entry) => entry.toJson())
        .toList();
    final history = ledger.history(limit: 100)
        .where((operation) {
          if (scope == null) return true;
          final operationScope = operation['scope'];
          return operationScope == scope ||
              (operationScope is String &&
                  operationScope.startsWith('$scope:'));
        })
        .take(20)
        .toList();
    return {
      'ok': true,
      'action': 'list',
      'entries': entries,
      'history': history,
    };
  }

  Future<Map<String, Object?>> _pinOperation({
    required PackageAction action,
    required PackageManagerId manager,
    required PackageScope scope,
    required List<PackageSpec> packages,
    required Map<String, dynamic> arguments,
  }) async {
    final target = _resolveTarget(
      scope: scope,
      ecosystem: switch (manager) {
        PackageManagerId.apt || PackageManagerId.apk => PackageEcosystem.system,
        PackageManagerId.pip || PackageManagerId.uv => PackageEcosystem.python,
        _ => PackageEcosystem.node,
      },
      arguments: arguments,
    );
    if (packages.isEmpty || packages.length > maxPackagesPerOperation) {
      throw const FormatException('pin_requires_package_entries');
    }
    final pinnedValues = <Map<String, Object?>>[];
    for (final package in packages) {
      final problem = package.validate(manager);
      if (problem != null) throw FormatException(problem);
      final current = ledger.find(
        scopeKey: target.key,
        packageName: package.name,
      );
      if (action == PackageAction.pin) {
        final version = package.version ??
            _optionalString(arguments['version']);
        if (version == null ||
            !RegExp(r'^[A-Za-z0-9][A-Za-z0-9.+_~:-]{0,63}$')
                .hasMatch(version)) {
          throw const FormatException('pin_requires_exact_version');
        }
        await ledger.upsert(PackageLedgerEntry(
          scopeKey: target.key,
          manager: manager.name,
          name: package.name,
          installedVersion: current?.installedVersion,
          pinnedVersion: version,
          status: current?.status ?? 'not_installed',
          sourceManifest: current?.sourceManifest,
          updatedAt: DateTime.now().toUtc(),
        ));
        pinnedValues.add({'name': package.name, 'version': version});
      } else if (current != null) {
        await ledger.upsert(current.copyWith(
          clearPinnedVersion: true,
          updatedAt: DateTime.now().toUtc(),
        ));
      }
    }
    await ledger.recordOperation({
      'operationId': const Uuid().v4(),
      'action': action.name,
      'manager': manager.name,
      'scope': target.key,
      'packages': pinnedValues.isEmpty
          ? packages.map((package) => package.toJson()).toList()
          : pinnedValues,
      'status': 'succeeded',
      'completedAt': DateTime.now().toUtc().toIso8601String(),
    });
    return {
      'ok': true,
      'action': action.name,
      'manager': manager.name,
      'scope': target.key,
      'packages': packages.map((package) => package.toJson()).toList(),
      'message': action == PackageAction.pin
          ? 'Exact versions were pinned for future package operations.'
          : 'Version pins were removed; installed packages were not upgraded.',
    };
  }

  PackageManagerId _managerFromLedger(
    List<PackageSpec> packages, {
    required PackageScope scope,
    required Map<String, dynamic> arguments,
  }) {
    if (packages.isEmpty) return PackageManagerId.auto;
    final managerNames = <String>{};
    final scopePrefix = switch (scope) {
      PackageScope.runtime => 'runtime:',
      PackageScope.project => 'project:${workspace?.workspace.id ?? ''}:',
      PackageScope.extension => 'extension:${_requiredString(arguments['extension_id'] ?? arguments['skill_id'], 'extension_id')}:',
      PackageScope.task => 'task:${_requiredString(arguments['task_id'], 'task_id')}:',
    };
    for (final package in packages) {
      for (final entry in ledger.entries()) {
        if (entry.scopeKey.startsWith(scopePrefix) &&
            entry.name.toLowerCase() == package.name.toLowerCase()) {
          managerNames.add(entry.manager);
        }
      }
    }
    if (managerNames.length != 1) return PackageManagerId.auto;
    return PackageManagerIdName.parse(managerNames.single);
  }

  PackageEcosystem? _parseEcosystem(Object? value) => switch (value) {
    'system' => PackageEcosystem.system,
    'python' => PackageEcosystem.python,
    'node' => PackageEcosystem.node,
    null => null,
    _ => throw const FormatException('invalid_package_ecosystem'),
  };

  List<PackageSpec> _parsePackages(
    Object? raw,
    Object? single, {
    String? defaultVersion,
  }) {
    final values = raw is List ? raw : (single == null ? const [] : [single]);
    final packages = <PackageSpec>[];
    for (final value in values) {
      final parsed = PackageSpec.fromJson(value);
      packages.add(
        parsed.version == null && defaultVersion != null && values.length == 1
            ? PackageSpec(name: parsed.name, version: defaultVersion)
            : parsed,
      );
    }
    return packages;
  }

  List<PackageSpec> _mergePackages(
    List<PackageSpec> requested,
    List<PackageSpec> fromManifest,
  ) {
    final merged = <String, PackageSpec>{};
    for (final package in fromManifest) {
      merged[package.normalizedName] = package;
    }
    for (final package in requested) {
      final current = merged[package.normalizedName];
      if (current?.version != null &&
          package.version != null &&
          current!.version != package.version) {
        throw PackageManagerException(
          'package_version_conflict',
          'The request and dependency manifest specify different exact versions for ${package.name}. Resolve the conflict before changing the environment.',
        );
      }
      // An unversioned explicit name must never erase an exact version from a
      // manifest or installed Skill metadata contract.
      if (current?.version != null && package.version == null) continue;
      merged[package.normalizedName] = package;
    }
    return merged.values.toList();
  }

  List<String> _parseBinaries(Object? raw) {
    if (raw == null) return const [];
    if (raw is! List) throw const FormatException('verify_binaries_must_be_array');
    final values = <String>[];
    for (final value in raw) {
      if (value is! String ||
          !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._+-]{0,127}$').hasMatch(value)) {
        throw const FormatException('invalid_binary_name');
      }
      values.add(value);
    }
    return values.toSet().toList();
  }

  Future<List<String>> _verifyBinaries(
    List<String> binaries,
    PackageScopeTarget target,
    List<String> logs,
  ) async {
    final binPath = switch (target.scope) {
      PackageScope.runtime when target.displayPath.endsWith('/python') =>
        '${target.shellPath}/bin',
      PackageScope.runtime when target.displayPath.endsWith('/node') =>
        '${target.shellPath}/node_modules/.bin',
      PackageScope.project when target.displayPath.endsWith('/python') =>
        '${target.shellPath}/bin',
      PackageScope.project when target.displayPath.endsWith('/node') =>
        '${target.shellPath}/node_modules/.bin',
      PackageScope.extension when target.displayPath.endsWith('/python') =>
        '${target.shellPath}/bin',
      PackageScope.extension when target.displayPath.endsWith('/node') =>
        '${target.shellPath}/node_modules/.bin',
      PackageScope.task when target.displayPath.endsWith('/python') =>
        '${target.shellPath}/bin',
      PackageScope.task when target.displayPath.endsWith('/node') =>
        '${target.shellPath}/node_modules/.bin',
      _ => null,
    };
    final pathPrefix = binPath == null
        ? ''
        : 'PATH=$binPath:"${r'$'}PATH"; export PATH; ';
    final commands = binaries
        .map((binary) => 'command -v ${shellQuote(binary)} >/dev/null 2>&1 || echo ${shellQuote(binary)}')
        .join('; ');
    final result = await _run(
      '$pathPrefix$commands',
      cwd: target.cwd,
      timeout: _checkTimeout,
      logs: logs,
    );
    return result.stdout
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  List<String> _compatibilityWarnings(
    PackageManagerId manager,
    String? architecture,
  ) {
    final normalized = architecture?.toLowerCase();
    final warnings = <String>[];
    if (normalized != 'arm64' && normalized != 'aarch64' && normalized != 'armv8l') {
      warnings.add(
        'runtime_architecture_unverified:${architecture ?? 'unknown'}: native packages may not match the Android ARM64 device; verify binaries before use.',
      );
    }
    if (manager == PackageManagerId.pip || manager == PackageManagerId.uv) {
      warnings.add('python_wheel_compatibility_is_checked_by_the_package_index; source builds are disabled unless explicitly allowed.');
    }
    if ([PackageManagerId.npm, PackageManagerId.pnpm, PackageManagerId.yarn, PackageManagerId.bun].contains(manager)) {
      warnings.add('native_node_addons_must_match_linux_arm64_and_the_active_libc; verify the installed executable.');
    }
    return warnings;
  }

  Future<String> _writeLockfile(
    PackageManagerId manager,
    PackageScopeTarget target,
    List<String> logs,
  ) async {
    final entries = ledger.entries(scopeKey: target.key)
        .map((entry) => entry.toJson())
        .toList();
    final payload = jsonEncode({
      'schemaVersion': 1,
      'scope': target.key,
      'manager': manager.name,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'packages': entries,
    });
    final encoded = base64Encode(utf8.encode(payload));
    final command = 'LOCK_PATH=${target.lockfileShellPath}; '
        'LOCK_DIR=${r'$'}(dirname "${r'$'}LOCK_PATH"); mkdir -p "${r'$'}LOCK_DIR"; '
        "printf '%s' '${encoded}' | base64 -d > \"${r'$'}LOCK_PATH.tmp\"; "
        'mv "${r'$'}LOCK_PATH.tmp" "${r'$'}LOCK_PATH"';
    try {
      await _run(command, cwd: target.cwd, timeout: _checkTimeout, logs: logs);
      return 'written';
    } catch (error) {
      logs.add('Lockfile write failed: $error');
      return 'preferences_only';
    }
  }

  Future<_PackageCommandResult> _run(
    String command, {
    required String cwd,
    required Duration timeout,
    List<String>? logs,
    WorkspaceRuntime? runtimeOverride,
    bool allowFailure = false,
  }) async {
    final activeRuntime = runtimeOverride ?? runtime;
    if (activeRuntime == null) {
      throw const PackageManagerException('runtime_unavailable', 'Runtime unavailable.');
    }
    final config = await environment.loadExecutionConfig();
    final id = 'package-${const Uuid().v4()}';
    final stdout = <int>[];
    final stderr = <int>[];
    CommandExited? exited;
    await for (final event in activeRuntime.run(CommandRequest(
      runId: id,
      command: command,
      cwd: cwd,
      timeout: timeout,
      env: config.variables,
    ))) {
      if (event is CommandOutput) {
        final target = event.kind == OutputStreamKind.stdout ? stdout : stderr;
        target.addAll(event.bytes);
        if (target.length > maxOutputBytes) {
          target.removeRange(0, target.length - maxOutputBytes);
        }
      } else if (event is CommandExited) {
        exited = event;
      }
    }
    final out = utf8.decode(stdout, allowMalformed: true);
    final err = utf8.decode(stderr, allowMalformed: true);
    if (logs != null) {
      if (out.trim().isNotEmpty) logs.add(_tail(out));
      if (err.trim().isNotEmpty) logs.add(_tail(err));
    }
    if (exited == null ||
        exited.exitCode != 0 ||
        exited.timedOut ||
        exited.cancelled ||
        exited.interrupted) {
      if (!allowFailure) {
        throw PackageManagerException(
          exited?.timedOut == true ? 'package_operation_timed_out' : 'package_command_failed',
          _tail(err.isEmpty ? out : err),
        );
      }
    }
    return _PackageCommandResult(
      exitCode: exited?.exitCode ?? -1,
      stdout: out,
      stderr: err,
    );
  }

  static String _requiredString(Object? value, String field) {
    final parsed = _optionalString(value);
    if (parsed == null || !PackageScopeTarget.isSafeScopeId(parsed)) {
      throw FormatException('invalid_$field');
    }
    return parsed;
  }

  static String? _optionalString(Object? value) {
    if (value is! String) return null;
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  static String _tail(String value) {
    const maxChars = 12000;
    return value.length <= maxChars
        ? value
        : value.substring(value.length - maxChars);
  }

  static String _json(Map<String, Object?> value) => jsonEncode(value);
}

class _PackageRollbackSnapshot {
  const _PackageRollbackSnapshot({
    required this.package,
    required this.previousVersion,
    required this.wasInstalled,
    required this.previousRecord,
  });

  final PackageSpec package;
  final String? previousVersion;
  final bool wasInstalled;
  final PackageLedgerEntry? previousRecord;
}

class PackageManagerException implements Exception {
  const PackageManagerException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}

class _PackageCommandResult {
  const _PackageCommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}
