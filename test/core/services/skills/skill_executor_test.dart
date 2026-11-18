import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/skill_record.dart';
import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/services/api/tool_call_cancellation.dart';
import 'package:Kelivo/core/services/runtime_profiles/runtime_profile_models.dart';
import 'package:Kelivo/core/services/runtime_profiles/runtime_profile_service.dart';
import 'package:Kelivo/core/services/skills/skill.dart';
import 'package:Kelivo/core/services/skills/skill_executor.dart';
import 'package:Kelivo/core/services/skills/skill_execution_permissions.dart';
import 'package:Kelivo/core/services/workspace/workspace_paths.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/core/services/workspace/workspace_tool_context.dart';
import '../../../support/fake_workspace_runtime.dart';

class _ProotOutputRuntime extends FakeWorkspaceRuntime {
  bool _isSkillRun(CommandRequest request) => request.mounts.any(
    (mount) => mount.guest == '${SkillExecutor.runGuestRoot}/source',
  );
  bool writeUndeclaredOutput = false;
  bool writeOutputSymlink = false;
  int exitCode = 0;
  bool timedOut = false;
  bool cancelled = false;
  bool waitForCancellation = false;
  final Completer<void> requestStarted = Completer<void>();
  final Completer<void> cancelSignal = Completer<void>();
  @override
  Future<RuntimeStatus> status() async => const RuntimeStatus(
    ready: true,
    engine: 'proot',
    sandboxed: true,
  );

  @override
  Stream<CommandEvent> run(CommandRequest request) async* {
    if (_isSkillRun(request)) {
      requests.add(request);
      yield const CommandStarted(pid: 1);
      if (waitForCancellation) {
        if (!requestStarted.isCompleted) requestStarted.complete();
        await cancelSignal.future;
        yield const CommandExited(
          exitCode: -1,
          timedOut: false,
          cancelled: true,
          interrupted: false,
          duration: Duration(milliseconds: 1),
        );
        return;
      }
      final outputMount = request.mounts.firstWhere(
        (mount) => mount.guest == '${SkillExecutor.runGuestRoot}/io/output',
      );
      final outputDirectory = Directory(outputMount.host)
        ..createSync(recursive: true);
      if (exitCode == 0 && !timedOut && !cancelled) {
        File(p.join(outputDirectory.path, 'result.txt'))
            .writeAsStringSync('verified output\n', flush: true);
      }
      if (writeUndeclaredOutput) {
        File(p.join(outputDirectory.path, 'extra.tmp'))
            .writeAsStringSync('undeclared', flush: true);
      }
      if (writeOutputSymlink) {
        Link(p.join(outputDirectory.path, 'external-link'))
            .createSync('/etc/passwd');
      }
      yield CommandOutput(
        OutputStreamKind.stdout,
        Uint8List.fromList(utf8.encode('skill execution output\n')),
      );
      yield CommandExited(
        exitCode: exitCode,
        timedOut: timedOut,
        cancelled: cancelled,
        interrupted: false,
        duration: const Duration(milliseconds: 1),
      );
      return;
    }
    yield* super.run(request);
  }

  @override
  Future<void> cancel(String runId) async {
    if (!cancelSignal.isCompleted) cancelSignal.complete();
  }
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
  late _ProotOutputRuntime runtime;
  late RuntimeProfileService profileService;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    await database.customSelect('SELECT 1;').getSingle();
    store = ExtensionEntityStore(database);
    temporaryRoot = await Directory.systemTemp.createTemp('kelivo_skill_executor_');
    workspaceDirectory = Directory(p.join(temporaryRoot.path, 'workspace'))
      ..createSync(recursive: true);
    sessionDirectory = Directory(p.join(temporaryRoot.path, 'session'))
      ..createSync(recursive: true);
    skillsDirectory = Directory(p.join(temporaryRoot.path, 'skills'))
      ..createSync(recursive: true);
    Directory(p.join(sessionDirectory.path, 'outputs')).createSync();

    runtime = _ProotOutputRuntime();
    runtimeProvider = WorkspaceRuntimeProvider()..register(runtime);
    final workspace = Workspace(
      id: 'workspace-skill-test',
      name: 'Skill execution test',
      kind: WorkspaceKind.managed,
      createdAt: DateTime.utc(2026, 11, 10),
      updatedAt: DateTime.utc(2026, 11, 10),
    );
    context = WorkspaceToolContext(
      workspace: workspace,
      binding: const WorkspaceBinding(),
      paths: WorkspacePaths.sandboxed(
        workspaceHostRoot: workspaceDirectory.path,
        sessionHostDir: sessionDirectory.path,
        skillsHostDir: skillsDirectory.path,
      ),
      sessionDir: sessionDirectory,
      outputsDir: Directory(p.join(sessionDirectory.path, 'outputs')),
    );
    profileService = RuntimeProfileService(
      store: store,
      runtimeProvider: runtimeProvider,
    );
  });

  tearDown(() async {
    runtimeProvider.dispose();
    await database.close();
    if (await temporaryRoot.exists()) {
      await temporaryRoot.delete(recursive: true);
    }
  });

  Future<_SkillFixture> _createSkill(String id) async {
    final directory = Directory(p.join(skillsDirectory.path, id))
      ..createSync(recursive: true);
    final scriptDirectory = Directory(p.join(directory.path, 'scripts'))
      ..createSync(recursive: true);
    const markdown = '''---
name: Example Skill
description: A test-only script skill
metadata:
  kelivo.permissions: shell.execute
---
Test skill.
''';
    const script = '#!/usr/bin/env bash\necho test\n';
    final markdownFile = File(p.join(directory.path, 'SKILL.md'))
      ..writeAsStringSync(markdown);
    final scriptFile = File(p.join(scriptDirectory.path, 'run.sh'))
      ..writeAsStringSync(script);
    final markdownBytes = await markdownFile.readAsBytes();
    final scriptBytes = await scriptFile.readAsBytes();
    final sourceDigest = sha256.convert([...markdownBytes, ...scriptBytes]).toString();
    final skill = Skill(
      record: SkillRecord(
        id: id,
        source: SkillSource.github,
        installedAt: DateTime.utc(2026, 11, 10),
        updatedAt: DateTime.utc(2026, 11, 10),
      ),
      name: 'Example Skill',
      description: 'A test-only script skill',
      dir: directory.path,
      skillMdPath: markdownFile.path,
    );
    final manifest = <String, Object?>{
      'schemaVersion': 1,
      'skillId': id,
      'completeness': 'complete',
      'sourceDigest': sourceDigest,
      'files': [
        {
          'path': 'SKILL.md',
          'sizeBytes': markdownBytes.length,
          'sha256': sha256.convert(markdownBytes).toString(),
          'scope': 'skill',
          'mediaType': 'text/markdown',
        },
        {
          'path': 'scripts/run.sh',
          'sizeBytes': scriptBytes.length,
          'sha256': sha256.convert(scriptBytes).toString(),
          'scope': 'skill',
          'mediaType': 'text/plain',
        },
      ],
      'capabilities': [
        {
          'kind': 'local_script',
          'entryPoints': ['scripts/run.sh'],
        },
      ],
    };
    return _SkillFixture(
      skill: skill,
      directory: directory,
      manifest: manifest,
      sourceDigest: sourceDigest,
    );
  }

  const String _testExecutionGrantId = 'skill-test-grant-0001';

  List<Map<String, Object?>> _permissions() =>
      SkillExecutionPermissionPolicy.approveForSingleRun(
        review: SkillExecutionPermissionPolicy.reviewForSkill(const []),
        grantId: _testExecutionGrantId,
      );

  Map<String, Object?> _singleSkillPlan(String skillId) => {
    'status': 'ready',
    'task': 'run the local test script',
    'selectedSkillIds': [skillId],
    'executionStages': [
      {'stage': 1, 'parallel': false, 'skillIds': [skillId]},
    ],
    'dependencyEdges': const [],
    'artifactContracts': {
      'inputs': {skillId: <String>[]},
      'outputs': {skillId: ['result']},
    },
    'pinnedDigests': <String, String>{},
  };

  test('executes only a declared script from a verified snapshot and records output', () async {
    final fixture = await _createSkill('alpha-skill');
    final profile = await profileService.create(
      name: 'Alpha script runtime',
      scope: RuntimeProfileScope.extension,
      ownerId: fixture.skill.record.id,
      ecosystems: {RuntimeProfileEcosystem.shell},
      context: context,
    );
    final executor = SkillExecutor(
      runtimeProvider: runtimeProvider,
      runtimeProfiles: profileService,
      ledgerStore: store,
    );

    final result = await executor.execute(
      skill: fixture.skill,
      context: context,
      compositionPlan: _singleSkillPlan(fixture.skill.record.id),
      importManifest: fixture.manifest,
      entryPoint: 'scripts/run.sh',
      runtimeProfileId: profile.id,
      expectedOutputs: const {'result': 'result.txt'},
      expectedOutputTypes: const {'result': 'text/plain'},
      arguments: const ['--mode=sample'],
      inputs: const {'mode': 'sample'},
      permissionReview: _permissions(),
      executionGrantId: _testExecutionGrantId,
      sharedRootfsRiskAcknowledged: true,
      selectedSourceDigests: {fixture.skill.record.id: fixture.sourceDigest},
    );

    final runRequests = runtime.requests.where(
      (request) => request.mounts.any(
        (mount) => mount.guest == '${SkillExecutor.runGuestRoot}/source',
      ),
    ).toList();
    expect(runRequests, hasLength(1));

    expect(result['tool'], 'skill_execute');
    expect(result['status'], 'succeeded');
    expect(result['exitCode'], 0);
    expect(result['stdout'], 'skill execution output\n');
    final argumentAudit = result['arguments'] as Map;
    expect(argumentAudit['count'], 1);
    final boundary = result['runtimeBoundary'] as Map;
    expect(boundary['installedSkillsMounted'], isFalse);
    final outputs = result['outputs'] as List;
    expect(outputs, hasLength(1));
    expect(outputs.single['mediaType'], 'text/plain');
    expect(outputs.single['sizeBytes'], greaterThan(0));

    expect(runRequests.single.cwd, '${SkillExecutor.runGuestRoot}/source');
    final runtimePath = runRequests.single.env['PATH'] ?? '';
    expect(runtimePath.split(':').take(2), ['/usr/local/bin', '/usr/local/sbin']);
    expect(runtimePath, contains('/usr/bin'));
    final mountsByGuest = {
      for (final mount in runRequests.single.mounts) mount.guest: mount,
    };
    expect(mountsByGuest.keys.toSet(), {
      '${SkillExecutor.runGuestRoot}/source',
      '${SkillExecutor.runGuestRoot}/io/input',
      '${SkillExecutor.runGuestRoot}/io/output',
      '${SkillExecutor.runGuestRoot}/io/tmp',
    });
    expect(mountsByGuest['${SkillExecutor.runGuestRoot}/source']!.readOnly, isTrue);
    expect(mountsByGuest['${SkillExecutor.runGuestRoot}/io/input']!.readOnly, isTrue);
    expect(mountsByGuest['${SkillExecutor.runGuestRoot}/io/output']!.readOnly, isFalse);
    expect(mountsByGuest['${SkillExecutor.runGuestRoot}/io/tmp']!.readOnly, isFalse);
    expect(
      mountsByGuest['${SkillExecutor.runGuestRoot}/source']!.host,
      isNot(contains(fixture.skill.dir)),
    );
    expect(mountsByGuest['${SkillExecutor.runGuestRoot}/source']!.host, contains('.kelivo'));

    final ledgers = await store.listByKind(
      ExtensionEntityStore.kindSkillExecutionLedger,
    );
    expect(ledgers, hasLength(1));
    expect(
      (ledgers.single.payload['records'] as Map)[fixture.skill.record.id]['status'],
      'succeeded',
    );
  });

  test('rejects files not declared in the output contract', () async {
    final fixture = await _createSkill('extra-output-skill');
    final profile = await profileService.create(
      name: 'Extra output runtime',
      scope: RuntimeProfileScope.extension,
      ownerId: fixture.skill.record.id,
      ecosystems: {RuntimeProfileEcosystem.shell},
      context: context,
    );
    runtime.writeUndeclaredOutput = true;
    final executor = SkillExecutor(
      runtimeProvider: runtimeProvider,
      runtimeProfiles: profileService,
      ledgerStore: store,
    );

    await expectLater(
      executor.execute(
        skill: fixture.skill,
        context: context,
        compositionPlan: _singleSkillPlan(fixture.skill.record.id),
        importManifest: fixture.manifest,
        entryPoint: 'scripts/run.sh',
        runtimeProfileId: profile.id,
        expectedOutputs: const {'result': 'result.txt'},
        permissionReview: _permissions(),
        executionGrantId: _testExecutionGrantId,
        sharedRootfsRiskAcknowledged: true,
        selectedSourceDigests: {fixture.skill.record.id: fixture.sourceDigest},
      ),
      throwsA(isA<SkillExecutionException>().having(
        (error) => error.code,
        'code',
        startsWith('undeclared_skill_output_file:'),
      )),
    );
    expect(
      await store.listByKind(ExtensionEntityStore.kindSkillExecutionLedger),
      isEmpty,
    );
  });

  test('rejects symlinks anywhere in the output tree', () async {
    final fixture = await _createSkill('symlink-output-skill');
    final profile = await profileService.create(
      name: 'Symlink output runtime',
      scope: RuntimeProfileScope.extension,
      ownerId: fixture.skill.record.id,
      ecosystems: {RuntimeProfileEcosystem.shell},
      context: context,
    );
    runtime.writeOutputSymlink = true;
    final executor = SkillExecutor(
      runtimeProvider: runtimeProvider,
      runtimeProfiles: profileService,
      ledgerStore: store,
    );

    await expectLater(
      executor.execute(
        skill: fixture.skill,
        context: context,
        compositionPlan: _singleSkillPlan(fixture.skill.record.id),
        importManifest: fixture.manifest,
        entryPoint: 'scripts/run.sh',
        runtimeProfileId: profile.id,
        expectedOutputs: const {'result': 'result.txt'},
        permissionReview: _permissions(),
        executionGrantId: _testExecutionGrantId,
        sharedRootfsRiskAcknowledged: true,
        selectedSourceDigests: {fixture.skill.record.id: fixture.sourceDigest},
      ),
      throwsA(isA<SkillExecutionException>().having(
        (error) => error.code,
        'code',
        'skill_output_symlink_not_allowed',
      )),
    );
    expect(
      await store.listByKind(ExtensionEntityStore.kindSkillExecutionLedger),
      isEmpty,
    );
  });

  test('does not accept a model-asserted completed dependency stage', () async {
    final fixture = await _createSkill('downstream-skill');
    final plan = <String, Object?>{
      'status': 'ready',
      'task': 'produce a downstream artifact',
      'selectedSkillIds': ['upstream-skill', fixture.skill.record.id],
      'executionStages': [
        {'stage': 1, 'parallel': false, 'skillIds': ['upstream-skill']},
        {'stage': 2, 'parallel': false, 'skillIds': [fixture.skill.record.id]},
      ],
      'dependencyEdges': [
        {
          'from': 'upstream-skill',
          'to': fixture.skill.record.id,
          'reason': 'artifact',
          'artifact': 'source-file',
        },
      ],
      'artifactContracts': {
        'inputs': {fixture.skill.record.id: ['source-file']},
        'outputs': {'upstream-skill': ['source-file'], fixture.skill.record.id: []},
      },
      'pinnedDigests': {},
    };
    final executor = SkillExecutor(
      runtimeProvider: runtimeProvider,
      runtimeProfiles: profileService,
      ledgerStore: store,
    );

    await expectLater(
      executor.execute(
        skill: fixture.skill,
        context: context,
        compositionPlan: plan,
        importManifest: fixture.manifest,
        entryPoint: 'scripts/run.sh',
        runtimeProfileId: 'not-used-until-prerequisite-is-verified',
        inputFiles: const {'source-file': '/workspace/fake.txt'},
        permissionReview: _permissions(),
        executionGrantId: _testExecutionGrantId,
        sharedRootfsRiskAcknowledged: true,
        selectedSourceDigests: {
          'upstream-skill': 'b' * 64,
          fixture.skill.record.id: fixture.sourceDigest,
        },
      ),
      throwsA(isA<SkillExecutionException>().having(
        (error) => error.code,
        'code',
        'composition_predecessor_stage_incomplete',
      )),
    );
    expect(runtime.requests, isEmpty);
  });

  test('rejects path traversal before touching the runtime', () async {
    final fixture = await _createSkill('path-skill');
    final executor = SkillExecutor(
      runtimeProvider: runtimeProvider,
      runtimeProfiles: profileService,
      ledgerStore: store,
    );

    await expectLater(
      executor.execute(
        skill: fixture.skill,
        context: context,
        compositionPlan: _singleSkillPlan(fixture.skill.record.id),
        importManifest: fixture.manifest,
        entryPoint: '../escape.sh',
        runtimeProfileId: 'unused-profile',
        permissionReview: _permissions(),
        executionGrantId: _testExecutionGrantId,
        sharedRootfsRiskAcknowledged: true,
        selectedSourceDigests: {fixture.skill.record.id: fixture.sourceDigest},
      ),
      throwsA(isA<SkillExecutionException>().having(
        (error) => error.code,
        'code',
        'invalid_skill_entry_point',
      )),
    );
    expect(runtime.requests, isEmpty);
  });

  test('rejects a tampered entry-point digest before process dispatch', () async {
    final fixture = await _createSkill('tampered-skill');
    await File(p.join(fixture.directory.path, 'scripts', 'run.sh'))
        .writeAsString('#!/bin/sh\necho tampered\n');
    final profile = await profileService.create(
      name: 'Tamper test runtime',
      scope: RuntimeProfileScope.extension,
      ownerId: fixture.skill.record.id,
      ecosystems: {RuntimeProfileEcosystem.shell},
      context: context,
    );
    final executor = SkillExecutor(
      runtimeProvider: runtimeProvider,
      runtimeProfiles: profileService,
      ledgerStore: store,
    );

    await expectLater(
      executor.execute(
        skill: fixture.skill,
        context: context,
        compositionPlan: _singleSkillPlan(fixture.skill.record.id),
        importManifest: fixture.manifest,
        entryPoint: 'scripts/run.sh',
        runtimeProfileId: profile.id,
        expectedOutputs: const {'result': 'result.txt'},
        permissionReview: _permissions(),
        executionGrantId: _testExecutionGrantId,
        sharedRootfsRiskAcknowledged: true,
        selectedSourceDigests: {fixture.skill.record.id: fixture.sourceDigest},
      ),
      throwsA(isA<SkillExecutionException>().having(
        (error) => error.code,
        'code',
        startsWith('skill_file_size_changed:'),
      )),
    );
    expect(
      runtime.requests.where((request) => request.mounts.any(
        (mount) => mount.guest == '${SkillExecutor.runGuestRoot}/source',
      )),
      isEmpty,
    );
  });

  test('rejects output MIME mismatch and discards partial output', () async {
    final fixture = await _createSkill('mime-skill');
    final profile = await profileService.create(
      name: 'MIME test runtime',
      scope: RuntimeProfileScope.extension,
      ownerId: fixture.skill.record.id,
      ecosystems: {RuntimeProfileEcosystem.shell},
      context: context,
    );
    final executor = SkillExecutor(
      runtimeProvider: runtimeProvider,
      runtimeProfiles: profileService,
      ledgerStore: store,
    );

    await expectLater(
      executor.execute(
        skill: fixture.skill,
        context: context,
        compositionPlan: _singleSkillPlan(fixture.skill.record.id),
        importManifest: fixture.manifest,
        entryPoint: 'scripts/run.sh',
        runtimeProfileId: profile.id,
        expectedOutputs: const {'result': 'result.txt'},
        expectedOutputTypes: const {'result': 'application/json'},
        permissionReview: _permissions(),
        executionGrantId: _testExecutionGrantId,
        sharedRootfsRiskAcknowledged: true,
        selectedSourceDigests: {fixture.skill.record.id: fixture.sourceDigest},
      ),
      throwsA(isA<SkillExecutionException>().having(
        (error) => error.code,
        'code',
        startsWith('skill_output_type_mismatch:'),
      )),
    );
    expect(
      (await store.listByKind(ExtensionEntityStore.kindSkillExecutionLedger)),
      isEmpty,
    );
  });

  test('requires explicit acknowledgement of the shared writable RootFS risk', () async {
    final fixture = await _createSkill('rootfs-ack-skill');
    final executor = SkillExecutor(
      runtimeProvider: runtimeProvider,
      runtimeProfiles: profileService,
      ledgerStore: store,
    );

    await expectLater(
      executor.execute(
        skill: fixture.skill,
        context: context,
        compositionPlan: _singleSkillPlan(fixture.skill.record.id),
        importManifest: fixture.manifest,
        entryPoint: 'scripts/run.sh',
        runtimeProfileId: 'unused-profile',
        permissionReview: _permissions(),
        executionGrantId: _testExecutionGrantId,
        selectedSourceDigests: {fixture.skill.record.id: fixture.sourceDigest},
        sharedRootfsRiskAcknowledged: false,
      ),
      throwsA(isA<SkillExecutionException>().having(
        (error) => error.code,
        'code',
        'shared_rootfs_risk_not_acknowledged',
      )),
    );
    expect(runtime.requests, isEmpty);
  }, tags: 'phase13d');

  test('rejects a missing or mismatched single-run permission grant before dispatch', () async {
    final fixture = await _createSkill('permission-grant-skill');
    final profile = await profileService.create(
      name: 'Permission grant runtime',
      scope: RuntimeProfileScope.extension,
      ownerId: fixture.skill.record.id,
      ecosystems: {RuntimeProfileEcosystem.shell},
      context: context,
    );
    final executor = SkillExecutor(
      runtimeProvider: runtimeProvider,
      runtimeProfiles: profileService,
      ledgerStore: store,
    );
    final requestsBeforeExecution = runtime.requests.length;

    await expectLater(
      executor.execute(
        skill: fixture.skill,
        context: context,
        compositionPlan: _singleSkillPlan(fixture.skill.record.id),
        importManifest: fixture.manifest,
        entryPoint: 'scripts/run.sh',
        runtimeProfileId: profile.id,
        permissionReview: _permissions(),
        executionGrantId: 'different-grant-12345',
        selectedSourceDigests: {fixture.skill.record.id: fixture.sourceDigest},
        sharedRootfsRiskAcknowledged: true,
      ),
      throwsA(isA<SkillExecutionException>().having(
        (error) => error.code,
        'code',
        'skill_permission_grant_missing_or_mismatched',
      )),
    );
    expect(runtime.requests, hasLength(requestsBeforeExecution));
  }, tags: 'phase13n');

  test('requires the shared RootFS permission in the execution review', () async {
    final fixture = await _createSkill('permission-review-skill');
    final profile = await profileService.create(
      name: 'Permission review runtime',
      scope: RuntimeProfileScope.extension,
      ownerId: fixture.skill.record.id,
      ecosystems: {RuntimeProfileEcosystem.shell},
      context: context,
    );
    final permissions = _permissions()
        .where((item) => item['permission'] != 'runtime.rootfs.write')
        .toList();
    // Creating an extension Runtime Profile legitimately provisions its
    // private runtime directory through the runtime adapter. Capture that
    // setup baseline so this assertion only detects a new Skill dispatch.
    final requestsBeforeExecution = runtime.requests.length;
    final executor = SkillExecutor(
      runtimeProvider: runtimeProvider,
      runtimeProfiles: profileService,
      ledgerStore: store,
    );

    await expectLater(
      executor.execute(
        skill: fixture.skill,
        context: context,
        compositionPlan: _singleSkillPlan(fixture.skill.record.id),
        importManifest: fixture.manifest,
        entryPoint: 'scripts/run.sh',
        runtimeProfileId: profile.id,
        permissionReview: permissions,
        executionGrantId: _testExecutionGrantId,
        selectedSourceDigests: {fixture.skill.record.id: fixture.sourceDigest},
        sharedRootfsRiskAcknowledged: true,
      ),
      throwsA(isA<SkillExecutionException>().having(
        (error) => error.code,
        'code',
        'skill_permission_review_incomplete',
      )),
    );
    expect(
      runtime.requests,
      hasLength(requestsBeforeExecution),
      reason: 'An incomplete permission review must not dispatch the Skill to the runtime.',
    );
  }, tags: 'phase13d');

  test('reports a non-zero script exit without recording success', () async {
    final fixture = await _createSkill('nonzero-exit-skill');
    final profile = await profileService.create(
      name: 'Non-zero runtime',
      scope: RuntimeProfileScope.extension,
      ownerId: fixture.skill.record.id,
      ecosystems: {RuntimeProfileEcosystem.shell},
      context: context,
    );
    runtime.exitCode = 23;
    final executor = SkillExecutor(
      runtimeProvider: runtimeProvider,
      runtimeProfiles: profileService,
      ledgerStore: store,
    );

    final result = await executor.execute(
      skill: fixture.skill,
      context: context,
      compositionPlan: _singleSkillPlan(fixture.skill.record.id),
      importManifest: fixture.manifest,
      entryPoint: 'scripts/run.sh',
      runtimeProfileId: profile.id,
      expectedOutputs: const {'result': 'result.txt'},
      permissionReview: _permissions(),
      executionGrantId: _testExecutionGrantId,
      selectedSourceDigests: {fixture.skill.record.id: fixture.sourceDigest},
      sharedRootfsRiskAcknowledged: true,
    );
    expect(result['status'], 'failed');
    expect(result['exitCode'], 23);
    expect(await store.listByKind(ExtensionEntityStore.kindSkillExecutionLedger), isEmpty);
  });

  test('reports runtime timeouts and discards partial run state', () async {
    final fixture = await _createSkill('timeout-skill');
    final profile = await profileService.create(
      name: 'Timeout runtime',
      scope: RuntimeProfileScope.extension,
      ownerId: fixture.skill.record.id,
      ecosystems: {RuntimeProfileEcosystem.shell},
      context: context,
    );
    runtime.timedOut = true;
    runtime.exitCode = -1;
    final executor = SkillExecutor(
      runtimeProvider: runtimeProvider,
      runtimeProfiles: profileService,
      ledgerStore: store,
    );

    final result = await executor.execute(
      skill: fixture.skill,
      context: context,
      compositionPlan: _singleSkillPlan(fixture.skill.record.id),
      importManifest: fixture.manifest,
      entryPoint: 'scripts/run.sh',
      runtimeProfileId: profile.id,
      expectedOutputs: const {'result': 'result.txt'},
      permissionReview: _permissions(),
      executionGrantId: _testExecutionGrantId,
      selectedSourceDigests: {fixture.skill.record.id: fixture.sourceDigest},
      sharedRootfsRiskAcknowledged: true,
    );
    expect(result['status'], 'timed_out');
    expect(await store.listByKind(ExtensionEntityStore.kindSkillExecutionLedger), isEmpty);
  });

  test('cancels an active Skill run when its owning tool call is cancelled', () async {
    final fixture = await _createSkill('cancel-skill');
    final profile = await profileService.create(
      name: 'Cancellation runtime',
      scope: RuntimeProfileScope.extension,
      ownerId: fixture.skill.record.id,
      ecosystems: {RuntimeProfileEcosystem.shell},
      context: context,
    );
    runtime.waitForCancellation = true;
    final executor = SkillExecutor(
      runtimeProvider: runtimeProvider,
      runtimeProfiles: profileService,
      ledgerStore: store,
    );
    final cancelled = Completer<void>();
    var isCancelled = false;
    final token = ToolCallCancellation(
      isCancelled: () => isCancelled,
      cancelled: cancelled.future,
    );
    final pending = token.run(() => executor.execute(
      skill: fixture.skill,
      context: context,
      compositionPlan: _singleSkillPlan(fixture.skill.record.id),
      importManifest: fixture.manifest,
      entryPoint: 'scripts/run.sh',
      runtimeProfileId: profile.id,
      expectedOutputs: const {'result': 'result.txt'},
      permissionReview: _permissions(),
      executionGrantId: _testExecutionGrantId,
      selectedSourceDigests: {fixture.skill.record.id: fixture.sourceDigest},
      sharedRootfsRiskAcknowledged: true,
    ));

    await runtime.requestStarted.future;
    isCancelled = true;
    cancelled.complete();
    final result = await pending;
    expect(result['status'], 'cancelled');
    expect(await store.listByKind(ExtensionEntityStore.kindSkillExecutionLedger), isEmpty);
  });

  test('rejects execution when the selected interpreter is not in the profile', () async {
    final fixture = await _createSkill('missing-interpreter-skill');
    final profile = await profileService.create(
      name: 'Python-only runtime',
      scope: RuntimeProfileScope.extension,
      ownerId: fixture.skill.record.id,
      ecosystems: {RuntimeProfileEcosystem.python},
      context: context,
    );
    final executor = SkillExecutor(
      runtimeProvider: runtimeProvider,
      runtimeProfiles: profileService,
      ledgerStore: store,
    );

    await expectLater(
      executor.execute(
        skill: fixture.skill,
        context: context,
        compositionPlan: _singleSkillPlan(fixture.skill.record.id),
        importManifest: fixture.manifest,
        entryPoint: 'scripts/run.sh',
        runtimeProfileId: profile.id,
        permissionReview: _permissions(),
        executionGrantId: _testExecutionGrantId,
        selectedSourceDigests: {fixture.skill.record.id: fixture.sourceDigest},
        sharedRootfsRiskAcknowledged: true,
      ),
      throwsA(isA<SkillExecutionException>().having(
        (error) => error.code,
        'code',
        'runtime_profile_missing_shell_ecosystem',
      )),
    );
    expect(runtime.requests.where((request) => request.mounts.any(
        (mount) => mount.guest == '${SkillExecutor.runGuestRoot}/source',
      )), isEmpty);
  });

  test('rejects concurrent runs on the same Skill Runtime Profile', () async {
    final fixture = await _createSkill('serial-skill');
    final profile = await profileService.create(
      name: 'Serial script runtime',
      scope: RuntimeProfileScope.extension,
      ownerId: fixture.skill.record.id,
      ecosystems: {RuntimeProfileEcosystem.shell},
      context: context,
    );
    final first = await profileService.resolveSkillExecution(
      context: context,
      runId: 'skill-first-run',
      skillId: fixture.skill.record.id,
      requestedProfileId: profile.id,
    );
    await expectLater(
      profileService.resolveSkillExecution(
        context: context,
        runId: 'skill-second-run',
        skillId: fixture.skill.record.id,
        requestedProfileId: profile.id,
      ),
      throwsA(isA<RuntimeProfileException>().having(
        (error) => error.code,
        'code',
        'skill_runtime_profile_busy',
      )),
    );
    profileService.releaseReservation(first.profile.id, 'skill-first-run');
  });


}

class _SkillFixture {
  const _SkillFixture({
    required this.skill,
    required this.directory,
    required this.manifest,
    required this.sourceDigest,
  });
  final Skill skill;
  final Directory directory;
  final Map<String, Object?> manifest;
  final String sourceDigest;
}
