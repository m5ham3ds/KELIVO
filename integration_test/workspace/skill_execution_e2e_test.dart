import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/models/mobile_background_settings.dart';
import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/services/mobile_background.dart';
import 'package:Kelivo/core/services/runtime_profiles/runtime_profile_models.dart';
import 'package:Kelivo/core/services/runtime_profiles/runtime_profile_service.dart';
import 'package:Kelivo/core/services/sandbox/environment_installer.dart';
import 'package:Kelivo/core/services/sandbox/mobile_workspace_bootstrap.dart';
import 'package:Kelivo/core/services/skills/skill_execution_permissions.dart';
import 'package:Kelivo/core/services/skills/skill_executor.dart';
import 'package:Kelivo/core/services/skills/skills_service.dart';
import 'package:Kelivo/core/services/workspace/workspace_paths.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/core/services/workspace/workspace_tool_context.dart';
import 'package:Kelivo/core/services/workspace/workspace_tools_service.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/utils/mcp_structured_image.dart';

const _e2eTimeout = Timeout(Duration(minutes: 25));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  if (!Platform.isAndroid) {
    testWidgets(
      'Phase 13P Skill execution E2E is Android-only',
      (tester) async {},
      skip: true,
    );
    return;
  }

  late _SkillE2EHarness harness;

  setUpAll(() async {
    harness = await _SkillE2EHarness.open();
  });

  tearDownAll(() async {
    await harness.dispose();
  });

  testWidgets(
    'Phase 13P imports a Skill ZIP, provisions its Profile, executes, opens output, and completes in background',
    (tester) async {
      await tester.pump();
      await harness.ensureReady();

      final fixtureRoot = await Directory.systemTemp.createTemp(
        'kelivo-phase13p-e2e-',
      );
      final database = AppDatabase(NativeDatabase.memory());
      await database.customSelect('SELECT 1;').getSingle();
      final store = ExtensionEntityStore(database);
      final runtimeProvider = WorkspaceRuntimeProvider()
        ..register(harness.stack.runtime);
      final skillsRoot = Directory(p.join(fixtureRoot.path, 'installed-skills'))
        ..createSync(recursive: true);
      final metadataRoot = Directory(p.join(fixtureRoot.path, 'skill-metadata'))
        ..createSync(recursive: true);
      final workspaceRoot = Directory(p.join(fixtureRoot.path, 'workspace'))
        ..createSync(recursive: true);
      final sessionRoot = Directory(p.join(fixtureRoot.path, 'session'))
        ..createSync(recursive: true);
      final outputsRoot = Directory(p.join(sessionRoot.path, 'outputs'))
        ..createSync(recursive: true);
      final profileService = RuntimeProfileService(
        store: store,
        runtimeProvider: runtimeProvider,
      );
      final skills = SkillsService(
        store: store,
        skillsDirectory: skillsRoot,
        skillImportMetadataDirectory: metadataRoot,
      );
      MobileBackgroundCoordinator? background;
      Skill? importedSkill;
      RuntimeProfile? profile;

      final workspace = Workspace(
        id: 'phase13p-e2e',
        name: 'Phase 13P Skill E2E',
        kind: WorkspaceKind.managed,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
      final paths = WorkspacePaths.sandboxed(
        workspaceHostRoot: workspaceRoot.path,
        sessionHostDir: sessionRoot.path,
        skillsHostDir: skillsRoot.path,
      );
      final context = WorkspaceToolContext(
        workspace: workspace,
        binding: const WorkspaceBinding(workspaceId: 'phase13p-e2e'),
        paths: paths,
        sessionDir: sessionRoot,
        outputsDir: outputsRoot,
        conversationId: 'phase13p-e2e-conversation',
        runtimeStatus: await harness.stack.runtime.status(),
        runtimeRegistered: true,
      );

      try {
        await skills.loaded;
        final sourceRoot = Directory(p.join(fixtureRoot.path, 'zip-source'))
          ..createSync(recursive: true);
        final scriptsRoot = Directory(p.join(sourceRoot.path, 'scripts'))
          ..createSync(recursive: true);
        final markdown = File(p.join(sourceRoot.path, 'SKILL.md'))
          ..writeAsStringSync('''---
name: phase-13p-e2e-verification
description: Creates a deterministic JSON artifact for the KELIVO Android execution test.
---

Use the declared local script to copy the validated KELIVO input envelope into the expected output directory.
''');
        final script = File(p.join(scriptsRoot.path, 'run.sh'))
          ..writeAsStringSync('''#!/usr/bin/env bash
set -euo pipefail
: "\$KELIVO_SKILL_INPUT_JSON"
: "\$KELIVO_TASK_OUTPUT_DIR"
sleep 3
cat "\$KELIVO_SKILL_INPUT_JSON" > "\$KELIVO_TASK_OUTPUT_DIR/result.json"
printf '\\n' >> "\$KELIVO_TASK_OUTPUT_DIR/result.json"
printf 'PHASE13P_E2E_DONE\\n'
''');
        final zipFile = File(p.join(fixtureRoot.path, 'phase13p-e2e.zip'));
        final encoder = ZipFileEncoder()..create(zipFile.path);
        try {
          encoder.addFileSync(markdown, 'phase-13p-e2e-verification/SKILL.md');
          encoder.addFileSync(script, 'phase-13p-e2e-verification/scripts/run.sh');
        } finally {
          encoder.closeSync();
        }

        final skill = await skills.importFromFile(zipFile.path);
        importedSkill = skill;
        final loadedImportReport = await skills.getImportReport(skill.record.id);
        if (loadedImportReport == null) {
          throw StateError('The imported Skill has no persisted import manifest');
        }
        final importReport = loadedImportReport;
        expect(importReport['completeness'], 'complete');
        expect(importReport['files'], isA<List>());
        final capabilities = (importReport['capabilities'] as List)
            .whereType<Map>()
            .toList(growable: false);
        expect(
          capabilities.any((item) =>
              item['kind'] == 'local_script' &&
              (item['entryPoints'] as List?)?.contains('scripts/run.sh') == true),
          isTrue,
          reason: 'ZIP import must produce a declared script capability',
        );
        final sourceDigest = importReport['sourceDigest'] as String;
        expect(sourceDigest, matches(RegExp(r'^sha256:[a-f0-9]{64}$')));

        final skillProfile = await profileService.create(
          name: 'Phase 13P E2E Shell Profile',
          scope: RuntimeProfileScope.extension,
          ownerId: skill.record.id,
          ecosystems: {RuntimeProfileEcosystem.shell},
          context: context,
        );
        profile = skillProfile;
        expect(skillProfile.status, RuntimeProfileStatus.ready);
        final profileCheck = await profileService.inspectSkillProfileCommands(
          skillId: skill.record.id,
          profileId: skillProfile.id,
          commandNames: const ['bash'],
        );
        final checkedCommands = (profileCheck['commands'] as List)
            .whereType<Map>()
            .toList(growable: false);
        expect(profileCheck['status'], 'completed');
        expect(
          checkedCommands.any((item) =>
              item['name'] == 'bash' && item['status'] == 'installed'),
          isTrue,
          reason: 'Bash must be visible on the Skill-owned Profile PATH',
        );

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        final coordinator = MobileBackgroundCoordinator(
          platform: TargetPlatform.android,
        );
        background = coordinator;
        await coordinator.configure(
          const MobileBackgroundSettings(
            androidEnabled: true,
            notificationsEnabled: true,
          ),
          l10n,
        );
        const backgroundTaskId = 'phase13p-skill-e2e-task';
        await coordinator.start(
          id: backgroundTaskId,
          conversationId: 'phase13p-e2e-conversation',
          title: 'KELIVO Skill E2E',
          cancel: () async {},
        );
        coordinator.update(
          backgroundTaskId,
          phase: BackgroundTaskPhase.tool,
          toolName: 'skill_execute',
          progress: 0.25,
          progressLabel: 'Running isolated Skill script',
        );
        await coordinator.refreshStatus();
        expect(
          coordinator.status.flag('foregroundServiceActive'),
          isTrue,
          reason: 'Android foreground service must own the active Skill task',
        );
        if (!coordinator.status.flag('notificationsAuthorized')) {
          debugPrint(
            'PHASE13P: notification permission is not granted on this device; '
            'foreground-service status remains testable, visible notification is not asserted.',
          );
        }

        // Model the activity leaving the foreground while the task and its
        // native foreground service remain registered. A force-stop is not
        // simulated: Android force-stop terminates the process by design.
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

        final permissionReview =
            SkillExecutionPermissionPolicy.reviewForSkill(const <String>[]);
        final grantId = 'phase13p-${const Uuid().v4()}';
        final approvedPermissions =
            SkillExecutionPermissionPolicy.approveForSingleRun(
          review: permissionReview,
          grantId: grantId,
        );
        final compositionPlan = <String, Object?>{
          'status': 'ready',
          'task': 'Verify ZIP import, profile-bound execution and artifact readback.',
          'selectedSkillIds': [skill.record.id],
          'executionStages': [
            {
              'stage': 1,
              'parallel': false,
              'skillIds': [skill.record.id],
            },
          ],
          'dependencyEdges': const <Object?>[],
          'artifactContracts': {
            'inputs': {skill.record.id: const <String>[]},
            'outputs': {skill.record.id: const ['result']},
          },
          'pinnedDigests': {skill.record.id: sourceDigest},
        };
        final executor = SkillExecutor(
          runtimeProvider: runtimeProvider,
          runtimeProfiles: profileService,
          ledgerStore: store,
        );
        final result = await executor.execute(
          skill: skill,
          context: context,
          compositionPlan: compositionPlan,
          importManifest: importReport,
          entryPoint: 'scripts/run.sh',
          runtimeProfileId: skillProfile.id,
          inputs: const {'marker': 'phase13p-verified'},
          expectedOutputs: const {'result': 'result.json'},
          expectedOutputTypes: const {'result': 'application/json'},
          requestedTimeoutSeconds: 120,
          permissionReview: approvedPermissions,
          executionGrantId: grantId,
          selectedSourceDigests: {skill.record.id: sourceDigest},
          sharedRootfsRiskAcknowledged: true,
        );
        expect(result['status'], 'succeeded');
        expect(result['exitCode'], 0);
        expect(result['stdout'], contains('PHASE13P_E2E_DONE'));
        expect(result['stderr'], isEmpty);
        final outputs = (result['outputs'] as List)
            .whereType<Map>()
            .toList(growable: false);
        expect(outputs, hasLength(1));
        expect(outputs.single['mediaType'], 'application/json');
        expect(outputs.single['sizeBytes'], greaterThan(0));
        expect(outputs.single['sha256'], matches(RegExp(r'^[a-f0-9]{64}$')));
        final outputPath = outputs.single['workspacePath'] as String;
        final resolvedOutput = context.paths.resolve(
          outputPath,
          cwd: context.cwd,
        );
        final outputBytes = await File(resolvedOutput.hostPath).readAsBytes();
        expect(
          outputs.single['sha256'],
          sha256.convert(outputBytes).toString(),
          reason: 'The recorded artifact digest must match the file on disk',
        );

        final tools = WorkspaceToolsService(
          runtimeProvider: runtimeProvider,
        );
        final opened = await tools.handle(
          context,
          'read_file',
          {'path': outputPath},
          toolCallId: 'phase13p-read-output',
        );
        final openedText = ClientToolResult.fromHandler(opened).content;
        final firstLine = openedText
            .split('\n')
            .firstWhere((line) => line.trim().isNotEmpty);
        final jsonSeparator = firstLine.indexOf('|');
        expect(jsonSeparator, greaterThanOrEqualTo(0));
        final openedJson = jsonDecode(
          firstLine.substring(jsonSeparator + 1),
        ) as Map<String, dynamic>;
        expect(openedJson['skillId'], skill.record.id);
        expect(
          (openedJson['data'] as Map<String, dynamic>)['marker'],
          'phase13p-verified',
        );
        expect(openedText, contains('phase13p-verified'));

        final ledger = await store.listByKind(
          ExtensionEntityStore.kindSkillExecutionLedger,
        );
        expect(ledger, isNotEmpty);
        final latestRecords = ledger.last.payload['records'];
        expect(latestRecords, isA<Map>());
        expect(
          (latestRecords as Map)[skill.record.id]['status'],
          'succeeded',
        );
        await coordinator.finish(
          backgroundTaskId,
          BackgroundTaskOutcome.completed,
          resultPersisted: true,
          replyPreview: 'Skill execution and output validation completed.',
        );
        await coordinator.refreshStatus();
        expect(coordinator.status.values['activeTasks'], 0);
        expect(
          coordinator.status.flag('foregroundServiceActive'),
          isFalse,
          reason: 'Foreground service should stop after the task is completed',
        );
        debugPrint(
          'PHASE13P_E2E imported=${skill.record.id} '
          'profile=${skillProfile.id} output=$outputPath '
          'notificationAuthorized=${coordinator.status.flag('notificationsAuthorized')}',
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      } finally {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        if (background != null) {
          if (background.activeTaskIds.isNotEmpty) {
            for (final id in background.activeTaskIds.toList()) {
              await background.finish(id, BackgroundTaskOutcome.failed);
            }
          }
          background.dispose();
        }
        if (profile != null) {
          try {
            await profileService.remove(
              profileId: profile.id,
              context: context,
            );
          } catch (error) {
            debugPrint('PHASE13P profile cleanup deferred: $error');
          }
        }
        if (importedSkill != null) {
          try {
            await skills.delete(importedSkill.record.id);
          } catch (error) {
            debugPrint('PHASE13P Skill cleanup deferred: $error');
          }
        }
        skills.dispose();
        runtimeProvider.dispose();
        await database.close();
        if (await fixtureRoot.exists()) {
          await fixtureRoot.delete(recursive: true);
        }
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      }
    },
    timeout: _e2eTimeout,
  );
}

final class _SkillE2EHarness {
  _SkillE2EHarness({
    required this.database,
    required this.env,
    required this.stack,
  });

  final AppDatabase database;
  final EnvironmentProvider env;
  final MobileWorkspaceStack stack;

  static Future<_SkillE2EHarness> open() async {
    final database = AppDatabase(NativeDatabase.memory());
    await database.customSelect('SELECT 1;').getSingle();
    final preferences = BusinessPreferences(BusinessRepository(database));
    await preferences.load();
    final env = EnvironmentProvider(preferences: preferences);
    await env.loaded;
    final stack = await createMobileWorkspaceStack(env: env);
    if (stack == null) {
      env.dispose();
      await database.close();
      throw StateError('Android workspace stack is unavailable');
    }
    try {
      await stack.channel.keepScreenOn(true);
    } catch (_) {}
    return _SkillE2EHarness(database: database, env: env, stack: stack);
  }

  Future<void> ensureReady() async {
    final probe = await stack.channel.probe();
    debugPrint(
      'PHASE13P_NATIVE_PROBE supported=${probe.supported} abi=${probe.abi} '
      'proot=${probe.prootPath} loader=${probe.loaderPath} '
      'nativeLibDir=${probe.nativeLibDir} reason=${probe.reason}',
    );
    if (!probe.supported) {
      throw StateError(
        'PRoot native runtime unavailable for ABI ${probe.abi}: '
        '${probe.reason ?? "unknown probe failure"} '
        '(proot=${probe.prootPath}, loader=${probe.loaderPath}, '
        'nativeLibDir=${probe.nativeLibDir})',
      );
    }
    final installer = stack.manager as EnvironmentInstaller;
    final versionFile = File(
      p.join(installer.rootfsDir.path, kKelivoVersionFile),
    );
    if (await versionFile.exists()) {
      if (env.state.phase != EnvironmentPhase.ready) {
        final parsed = (await versionFile.readAsString())
            .trim()
            .split(RegExp(r'\s+'));
        await env.setState(
          EnvironmentState(
            phase: EnvironmentPhase.ready,
            distro: parsed.isNotEmpty ? parsed[0] : env.rootfsImage.distro,
            version: parsed.length > 1 ? parsed[1] : env.rootfsImage.version,
            arch: parsed.length > 2 ? parsed[2] : 'arm64',
            installedAt: DateTime.now().toUtc(),
            rootfsDir: installer.rootfsDir.path,
            lastMirrorBase: env.state.lastMirrorBase,
          ),
        );
      }
      return;
    }
    await installer.install();
    if (env.state.phase != EnvironmentPhase.ready) {
      throw StateError(
        'PRoot environment did not reach ready: ${env.state.phase} '
        '(${env.state.errorMessage})',
      );
    }
  }

  Future<void> dispose() async {
    try {
      await stack.channel.keepScreenOn(false);
    } catch (_) {}
    env.dispose();
    await database.close();
  }
}
