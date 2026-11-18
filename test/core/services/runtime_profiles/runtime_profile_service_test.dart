import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/services/runtime_profiles/runtime_profile_models.dart';
import 'package:Kelivo/core/services/runtime_profiles/runtime_profile_service.dart';
import 'package:Kelivo/core/services/workspace/workspace_paths.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/core/services/workspace/workspace_tool_context.dart';
import '../../../support/fake_workspace_runtime.dart';

class _ProotFakeRuntime extends FakeWorkspaceRuntime {
  @override
  Future<RuntimeStatus> status() async => const RuntimeStatus(
    ready: true,
    engine: 'proot',
    sandboxed: true,
  );
}

void main() {
  late AppDatabase database;
  late ExtensionEntityStore store;
  late Directory temporaryRoot;
  late Directory workspaceDirectory;
  late Directory sessionDirectory;
  late Directory skillsDirectory;
  late WorkspaceToolContext context;
  late WorkspaceRuntimeProvider runtimeProvider;
  late FakeWorkspaceRuntime runtime;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    await database.customSelect('SELECT 1;').getSingle();
    store = ExtensionEntityStore(database);
    temporaryRoot = await Directory.systemTemp.createTemp('kelivo_runtime_profiles_');
    workspaceDirectory = Directory(p.join(temporaryRoot.path, 'workspace'))
      ..createSync(recursive: true);
    sessionDirectory = Directory(p.join(temporaryRoot.path, 'session'))
      ..createSync(recursive: true);
    skillsDirectory = Directory(p.join(temporaryRoot.path, 'skills'))
      ..createSync(recursive: true);
    Directory(p.join(sessionDirectory.path, 'outputs')).createSync();

    runtime = FakeWorkspaceRuntime();
    runtimeProvider = WorkspaceRuntimeProvider()..register(runtime);
    final workspace = Workspace(
      id: 'workspace-a',
      name: 'Workspace A',
      kind: WorkspaceKind.managed,
      createdAt: DateTime.utc(2026, 11, 8),
      updatedAt: DateTime.utc(2026, 11, 8),
    );
    context = WorkspaceToolContext(
      workspace: workspace,
      binding: const WorkspaceBinding(),
      paths: WorkspacePaths.native(
        workspaceHostRoot: workspaceDirectory.path,
        sessionHostDir: sessionDirectory.path,
        skillsHostDir: skillsDirectory.path,
      ),
      sessionDir: sessionDirectory,
      outputsDir: Directory(p.join(sessionDirectory.path, 'outputs')),
    );
  });

  tearDown(() async {
    runtimeProvider.dispose();
    await database.close();
    if (await temporaryRoot.exists()) {
      await temporaryRoot.delete(recursive: true);
    }
  });

  test('Skill Doctor probes only validated commands in the owning Runtime Profile', () async {
    final prootRuntime = _ProotFakeRuntime();
    final prootProvider = WorkspaceRuntimeProvider()..register(prootRuntime);
    addTearDown(prootProvider.dispose);
    final now = DateTime.utc(2026, 11, 17);
    final profile = RuntimeProfile(
      id: 'doctor-profile',
      name: 'Doctor Skill Profile',
      scope: RuntimeProfileScope.extension,
      ownerId: 'doctor-skill',
      ecosystems: {
        RuntimeProfileEcosystem.python,
        RuntimeProfileEcosystem.node,
      },
      status: RuntimeProfileStatus.ready,
      shareBaseTools: false,
      createdAt: now,
      updatedAt: now,
    );
    await store.upsert(RuntimeProfileEntityKinds.profiles, profile.id, profile.toJson());
    final root = runtimeProfileRoot(
      profile: profile,
      workspaceRoot: '/workspace',
      sandboxed: true,
    );
    prootRuntime.enqueueNext([
      const CommandStarted(pid: 7),
      CommandOutput(
        OutputStreamKind.stdout,
        Uint8List.fromList(utf8.encode(
          '__KELIVO_DOCTOR_0=$root/python/bin/python3\n'
          '__KELIVO_DOCTOR_1=$root/node/node_modules/.bin/node\n',
        )),
      ),
      const CommandExited(
        exitCode: 0,
        timedOut: false,
        cancelled: false,
        interrupted: false,
        duration: Duration(milliseconds: 5),
      ),
    ]);

    final service = RuntimeProfileService(
      store: store,
      runtimeProvider: prootProvider,
    );
    final result = await service.inspectSkillProfileCommands(
      skillId: 'doctor-skill',
      profileId: profile.id,
      commandNames: ['python3', 'node', 'bad;touch'],
    );

    expect(result['status'], 'completed');
    final commands = (result['commands'] as List).cast<Map>();
    expect(commands, hasLength(2));
    expect(commands.map((item) => item['status']), everyElement('installed'));
    expect(commands.map((item) => item['verifiedIn']), everyElement('skill_runtime_profile'));
    final request = prootRuntime.requests.single;
    expect(request.env['PATH'], startsWith('$root/python/bin:$root/node/node_modules/.bin:'));
    expect(request.command, contains("command -v 'python3'"));
    expect(request.command, contains("command -v 'node'"));
    expect(request.command, isNot(contains('bad;touch')));
    expect(request.command, isNot(contains('npm install')));
    expect(request.cwd, '/');
    expect(request.timeout, const Duration(seconds: 20));
  });

  test('Skill Doctor rejects a Runtime Profile owned by another Skill', () async {
    final prootRuntime = _ProotFakeRuntime();
    final prootProvider = WorkspaceRuntimeProvider()..register(prootRuntime);
    addTearDown(prootProvider.dispose);
    final now = DateTime.utc(2026, 11, 17);
    final profile = RuntimeProfile(
      id: 'foreign-profile',
      name: 'Foreign Profile',
      scope: RuntimeProfileScope.extension,
      ownerId: 'owner-skill',
      ecosystems: {RuntimeProfileEcosystem.python},
      status: RuntimeProfileStatus.ready,
      createdAt: now,
      updatedAt: now,
    );
    await store.upsert(RuntimeProfileEntityKinds.profiles, profile.id, profile.toJson());
    final service = RuntimeProfileService(store: store, runtimeProvider: prootProvider);
    await expectLater(
      service.inspectSkillProfileCommands(
        skillId: 'another-skill',
        profileId: profile.id,
        commandNames: ['python3'],
      ),
      throwsA(isA<RuntimeProfileException>()),
    );
    expect(prootRuntime.requests, isEmpty);
  });

  test('creates isolated Python and Node roots and resolves a workspace execution', () async {
    final service = RuntimeProfileService(
      store: store,
      runtimeProvider: runtimeProvider,
    );
    final profile = await service.create(
      name: 'Project Python + Node',
      scope: RuntimeProfileScope.project,
      ownerId: context.workspace.id,
      ecosystems: {
        RuntimeProfileEcosystem.python,
        RuntimeProfileEcosystem.node,
      },
      context: context,
      environment: const {'APP_MODE': 'development'},
      limits: const RuntimeResourceLimits(
        maxDurationSeconds: 75,
        maxCpuSeconds: 33,
        maxMemoryMegabytes: 768,
      ),
      shareBaseTools: false,
    );

    expect(profile.status, RuntimeProfileStatus.ready);
    expect(runtime.requests.first.command, contains('python3 -m venv'));
    expect(runtime.requests.first.command, contains('/node'));
    final workspaces = WorkspaceProvider(store: store);
    addTearDown(workspaces.dispose);
    await workspaces.loaded;
    await service.setDefault(
      profileId: profile.id,
      context: context,
      workspaces: workspaces,
    );
    expect(workspaces.byId(context.workspace.id)?.defaultRuntimeProfileId, profile.id);

    final secondWorkspaceDirectory = Directory(
      p.join(temporaryRoot.path, 'workspace-b'),
    )..createSync(recursive: true);
    final secondSessionDirectory = Directory(
      p.join(temporaryRoot.path, 'session-b'),
    )..createSync(recursive: true);
    final secondSkillsDirectory = Directory(
      p.join(temporaryRoot.path, 'skills-b'),
    )..createSync(recursive: true);
    final secondWorkspace = Workspace(
      id: 'workspace-b',
      name: 'Workspace B',
      kind: WorkspaceKind.managed,
      createdAt: DateTime.utc(2026, 11, 8),
      updatedAt: DateTime.utc(2026, 11, 8),
    );
    final secondContext = WorkspaceToolContext(
      workspace: secondWorkspace,
      binding: const WorkspaceBinding(),
      paths: WorkspacePaths.native(
        workspaceHostRoot: secondWorkspaceDirectory.path,
        sessionHostDir: secondSessionDirectory.path,
        skillsHostDir: secondSkillsDirectory.path,
      ),
      sessionDir: secondSessionDirectory,
      outputsDir: Directory(p.join(secondSessionDirectory.path, 'outputs')),
    );
    final secondProfile = await service.create(
      name: 'Second isolated project profile',
      scope: RuntimeProfileScope.project,
      ownerId: secondWorkspace.id,
      ecosystems: {RuntimeProfileEcosystem.python},
      context: secondContext,
    );
    expect(secondProfile.id, isNot(profile.id));
    expect(
      runtimeProfileRoot(
        profile: profile,
        workspaceRoot: context.paths.modelRoot,
        sandboxed: false,
      ),
      p.join(workspaceDirectory.path, '.kelivo', 'runtime-profiles', profile.id),
    );

    final execution = await service.resolveExecution(
      context: WorkspaceToolContext(
        workspace: workspaces.byId(context.workspace.id)!,
        binding: context.binding,
        paths: context.paths,
        sessionDir: context.sessionDir,
        outputsDir: context.outputsDir,
      ),
      runId: 'run-project-1',
    );

    expect(execution, isNotNull);
    expect(execution!.timeout, const Duration(seconds: 75));
    expect(execution.commandPrefix, contains('ulimit -t 33'));
    expect(execution.commandPrefix, contains('ulimit -v 786432'));
    expect(execution.environment['APP_MODE'], 'development');
    expect(execution.environment['VIRTUAL_ENV'], endsWith('/python'));
    expect(execution.environment['NODE_PATH'], endsWith('/node/node_modules'));
    expect(execution.environment['TMPDIR'], execution.temporaryRuntimePath);
    expect(execution.environment['KELIVO_TASK_OUTPUT_DIR'], execution.outputRuntimePath);
    expect(execution.outputRuntimePath, contains('/outputs/'));
    expect(execution.commandPrefix, contains(execution.outputRuntimePath));
    expect(execution.environment['PATH'], startsWith('${execution.environment['VIRTUAL_ENV']}/bin:'));
    expect(execution.environment['PATH'], isNot(contains('/usr/local/bin')));
    expect(execution.wrapCommand('echo test'), contains('du -sk'));
    final secondExecution = await service.resolveExecution(
      context: secondContext,
      runId: 'run-project-2',
      requestedProfileId: secondProfile.id,
    );
    expect(secondExecution, isNotNull);
    expect(secondExecution!.environment['VIRTUAL_ENV'], isNot(execution.environment['VIRTUAL_ENV']));
    expect(secondExecution.profile.id, secondProfile.id);
    expect(secondExecution.environment['NODE_PATH'], isNull);
    expect(secondExecution.outputRuntimePath, isNot(execution.outputRuntimePath));
    expect(execution.wrapCommand('echo test'), contains(execution.temporaryRuntimePath));

    service.releaseReservation(profile.id, 'run-project-1');
    service.releaseReservation(secondProfile.id, 'run-project-2');
    await service.clearDefault(context: context, workspaces: workspaces);
    expect(workspaces.byId(context.workspace.id)?.defaultRuntimeProfileId, isNull);
  });

  test('shares active reservations and process history between service instances', () async {
    final serviceA = RuntimeProfileService(
      store: store,
      runtimeProvider: runtimeProvider,
    );
    final profile = await serviceA.create(
      name: 'Single concurrent run',
      scope: RuntimeProfileScope.project,
      ownerId: context.workspace.id,
      ecosystems: {RuntimeProfileEcosystem.python},
      context: context,
      limits: const RuntimeResourceLimits(maxConcurrentRuns: 1),
    );
    final boundContext = WorkspaceToolContext(
      workspace: context.workspace.copyWith(defaultRuntimeProfileId: profile.id),
      binding: context.binding,
      paths: context.paths,
      sessionDir: context.sessionDir,
      outputsDir: context.outputsDir,
    );
    final execution = (await serviceA.resolveExecution(
      context: boundContext,
      runId: 'run-one',
    ))!;
    final record = await serviceA.recordStarted(
      execution: execution,
      runtimeRunId: 'run-one',
      command: 'python -m compileall .',
    );
    expect(record.sessionId, isNotEmpty);
    await expectLater(
      serviceA.remove(profileId: profile.id, context: context),
      throwsA(isA<RuntimeProfileException>()),
    );

    // A separate handler/service instance in the same app process must not
    // mark the active run interrupted or bypass the concurrency ceiling.
    final serviceB = RuntimeProfileService(
      store: store,
      runtimeProvider: runtimeProvider,
    );
    await serviceB.load();
    expect(serviceB.processHistory(profileId: profile.id).single.status,
        RuntimeProcessStatus.running);
    await expectLater(
      serviceB.resolveExecution(context: boundContext, runId: 'run-two'),
      throwsA(isA<RuntimeProfileException>()),
    );

    serviceA.releaseReservation(profile.id, 'run-one');
    final restarted = RuntimeProfileService(
      store: store,
      runtimeProvider: runtimeProvider,
      processSessionId: 'simulated-new-app-process',
    );
    await restarted.load();
    final recovered = restarted.processHistory(profileId: profile.id).single;
    expect(recovered.status, RuntimeProcessStatus.interrupted);
    expect(recovered.resumeHint, contains('rerun'));
    final resumedExecution = await restarted.resolveExecution(
      context: boundContext,
      runId: 'run-after-restart',
      requestedProfileId: profile.id,
    );
    expect(runtime.requests.last.command, contains('/tmp/run-one'));
    expect(resumedExecution, isNotNull);
    restarted.releaseReservation(profile.id, 'run-after-restart');
  });


  test('updates project profile limits without recreating isolated package roots', () async {
    final service = RuntimeProfileService(
      store: store,
      runtimeProvider: runtimeProvider,
    );
    final profile = await service.create(
      name: 'Editable profile',
      scope: RuntimeProfileScope.project,
      ownerId: context.workspace.id,
      ecosystems: {RuntimeProfileEcosystem.python},
      context: context,
    );
    final provisionCalls = runtime.requests.length;
    final updated = await service.updateProjectSettings(
      profileId: profile.id,
      context: context,
      name: 'Updated profile',
      limits: const RuntimeResourceLimits(
        maxDurationSeconds: 300,
        maxCpuSeconds: 120,
        maxOutputMegabytes: 256,
      ),
      shareBaseTools: false,
    );
    expect(updated.name, 'Updated profile');
    expect(updated.limits.maxDurationSeconds, 300);
    expect(updated.limits.maxCpuSeconds, 120);
    expect(updated.limits.maxOutputMegabytes, 256);
    expect(updated.shareBaseTools, isFalse);
    expect(runtime.requests, hasLength(provisionCalls));

    final execution = await service.resolveExecution(
      context: context,
      runId: 'edit-active-run',
      requestedProfileId: profile.id,
    );
    expect(execution, isNotNull);
    await expectLater(
      service.updateProjectSettings(
        profileId: profile.id,
        context: context,
        name: 'Must not update while running',
      ),
      throwsA(isA<RuntimeProfileException>()),
    );
    service.releaseReservation(profile.id, 'edit-active-run');
  });

  test('creates, verifies, restores and rejects corrupted profile dependency snapshots', () async {
    runtime.useRealProcess = true;
    final now = DateTime.utc(2026, 11, 17);
    final profile = RuntimeProfile(
      id: 'snapshot-profile',
      name: 'Snapshot profile',
      scope: RuntimeProfileScope.project,
      ownerId: context.workspace.id,
      ecosystems: {RuntimeProfileEcosystem.python, RuntimeProfileEcosystem.node},
      status: RuntimeProfileStatus.ready,
      createdAt: now,
      updatedAt: now,
    );
    await store.upsert(RuntimeProfileEntityKinds.profiles, profile.id, profile.toJson());
    final profileRoot = runtimeProfileRoot(
      profile: profile,
      workspaceRoot: context.paths.modelRoot,
      sandboxed: false,
    );
    final pythonRoot = Directory(p.join(profileRoot, 'python'))..createSync(recursive: true);
    Directory(p.join(profileRoot, 'node')).createSync(recursive: true);
    final packageFile = File(p.join(pythonRoot.path, 'requirements-state.txt'))
      ..writeAsStringSync('requests==2.31.0\n');

    final service = RuntimeProfileService(store: store, runtimeProvider: runtimeProvider);
    final snapshot = await service.createSnapshot(
      profileId: profile.id,
      context: context,
      label: 'before dependency update',
    );
    expect(snapshot.sha256, matches(RegExp(r'^[a-f0-9]{64}$')));
    expect(snapshot.sizeBytes, greaterThan(0));
    expect(service.snapshots(profileId: profile.id), hasLength(1));

    packageFile.writeAsStringSync('requests==2.32.0\n');
    await service.restoreSnapshot(snapshotId: snapshot.id, context: context);
    expect(packageFile.readAsStringSync(), 'requests==2.31.0\n');

    packageFile.writeAsStringSync('requests==2.32.0\n');
    final archive = File(snapshot.archivePath);
    final archiveBytes = await archive.readAsBytes();
    await archive.writeAsBytes(<int>[...archiveBytes, 0x00], flush: true);
    await expectLater(
      service.restoreSnapshot(snapshotId: snapshot.id, context: context),
      throwsA(isA<RuntimeProfileException>()),
    );
    expect(packageFile.readAsStringSync(), 'requests==2.32.0\n');

    await service.deleteSnapshot(snapshotId: snapshot.id, context: context);
    expect(service.snapshots(profileId: profile.id), isEmpty);
  });

  test('rejects unsafe run IDs before constructing runtime paths', () async {
    final service = RuntimeProfileService(
      store: store,
      runtimeProvider: runtimeProvider,
    );
    final profile = await service.create(
      name: 'Safe paths',
      scope: RuntimeProfileScope.project,
      ownerId: context.workspace.id,
      ecosystems: {RuntimeProfileEcosystem.python},
      context: context,
    );
    await expectLater(
      service.resolveExecution(
        context: context,
        runId: '../escape',
        requestedProfileId: profile.id,
      ),
      throwsA(isA<RuntimeProfileException>()),
    );
  });

  test('extension profiles require a sandboxed PRoot runtime', () async {
    final prootRuntime = _ProotFakeRuntime();
    final prootProvider = WorkspaceRuntimeProvider()..register(prootRuntime);
    addTearDown(prootProvider.dispose);
    final prootContext = WorkspaceToolContext(
      workspace: context.workspace,
      binding: context.binding,
      paths: WorkspacePaths.sandboxed(
        workspaceHostRoot: workspaceDirectory.path,
        sessionHostDir: sessionDirectory.path,
        skillsHostDir: skillsDirectory.path,
      ),
      sessionDir: context.sessionDir,
      outputsDir: context.outputsDir,
    );
    final service = RuntimeProfileService(store: store, runtimeProvider: prootProvider);
    final profile = await service.create(
      name: 'Skill environment',
      scope: RuntimeProfileScope.extension,
      ownerId: 'installed-skill',
      ecosystems: {RuntimeProfileEcosystem.node},
      context: prootContext,
    );

    expect(profile.status, RuntimeProfileStatus.ready);
    expect(
      runtimeProfileRoot(
        profile: profile,
        workspaceRoot: prootContext.paths.modelRoot,
        sandboxed: true,
      ),
      '/root/.local/share/kelivo/runtime-profiles/extensions/installed-skill/${profile.id}',
    );
  });

  test('rejects extension profiles on a non-PRoot runtime', () async {
    final service = RuntimeProfileService(
      store: store,
      runtimeProvider: runtimeProvider,
    );
    await expectLater(
      service.create(
        name: 'Not isolated',
        scope: RuntimeProfileScope.extension,
        ownerId: 'installed-skill',
        ecosystems: {RuntimeProfileEcosystem.python},
        context: context,
      ),
      throwsA(isA<RuntimeProfileException>()),
    );
  });
}
