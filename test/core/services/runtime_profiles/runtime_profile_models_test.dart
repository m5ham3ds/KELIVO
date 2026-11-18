import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/runtime_profiles/runtime_profile_models.dart';

void main() {
  group('RuntimeResourceLimits', () {
    test('normalizes resource limits to documented safe ranges', () {
      final limits = RuntimeResourceLimits(
        maxDurationSeconds: 9000,
        maxCpuSeconds: 9000,
        maxConcurrentRuns: 0,
        maxProcesses: 1,
        maxMemoryMegabytes: 16,
        maxTempMegabytes: 9000,
        maxOutputMegabytes: 9000,
        maxFileMegabytes: -10,
      ).normalized();

      expect(limits.maxDurationSeconds, 3600);
      expect(limits.maxCpuSeconds, 3600);
      expect(limits.maxConcurrentRuns, 1);
      expect(limits.maxProcesses, 8);
      expect(limits.maxMemoryMegabytes, 128);
      expect(limits.maxTempMegabytes, 4096);
      expect(limits.maxOutputMegabytes, 8192);
      expect(limits.maxFileMegabytes, 1);
    });

    test('round trips normalized limits through JSON', () {
      final restored = RuntimeResourceLimits.fromJson({
        'maxDurationSeconds': 90,
        'maxCpuSeconds': 45,
        'maxConcurrentRuns': 3,
        'maxProcesses': 48,
        'maxMemoryMegabytes': 1536,
        'maxTempMegabytes': 1024,
        'maxOutputMegabytes': 2048,
        'maxFileMegabytes': 64,
      });

      expect(restored.maxDurationSeconds, 90);
      expect(restored.maxCpuSeconds, 45);
      expect(restored.maxConcurrentRuns, 3);
      expect(restored.maxProcesses, 48);
      expect(restored.maxMemoryMegabytes, 1536);
      expect(restored.maxTempMegabytes, 1024);
      expect(restored.maxOutputMegabytes, 2048);
      expect(restored.maxFileMegabytes, 64);
    });
  });

  group('RuntimeProfileValidation', () {
    test('accepts only safe profile and owner identifiers', () {
      expect(RuntimeProfileValidation.isSafeId('project-1.skill_a'), isTrue);
      expect(RuntimeProfileValidation.isSafeId('../escape'), isFalse);
      expect(RuntimeProfileValidation.isSafeId('has space'), isFalse);
      expect(RuntimeProfileValidation.isSafeId(''), isFalse);
    });

    test('rejects secrets, reserved execution variables and unsafe values', () {
      expect(
        RuntimeProfileValidation.validateEnvironment({'APP_MODE': 'production'}),
        isNull,
      );
      expect(
        RuntimeProfileValidation.validateEnvironment({'API_TOKEN': 'secret'}),
        startsWith('use_secure_secret_store_for:'),
      );
      expect(
        RuntimeProfileValidation.validateEnvironment({'KELIVO_TASK_OUTPUT_DIR': '/tmp'}),
        startsWith('reserved_environment_key:'),
      );
      expect(
        RuntimeProfileValidation.validateEnvironment({'PATH': '/tmp/bin'}),
        startsWith('reserved_environment_key:'),
      );
      expect(
        RuntimeProfileValidation.validateEnvironment({'APP_MODE': 'a\nb'}),
        startsWith('invalid_environment_value:'),
      );
      expect(
        RuntimeProfileValidation.validateEnvironment({
          for (var i = 0; i < 33; i++) 'VALUE_$i': 'x',
        }),
        'too_many_environment_variables_max_32',
      );
    });
  });

  test('wrap command preserves shell status and command substitution', () {
    final execution = RuntimeProfileExecution(
      profile: RuntimeProfile(
        id: 'profile-1',
        name: 'Test',
        scope: RuntimeProfileScope.project,
        ownerId: 'workspace-1',
        ecosystems: const {RuntimeProfileEcosystem.python},
        createdAt: DateTime.utc(2026, 11, 9),
        updatedAt: DateTime.utc(2026, 11, 9),
      ),
      environment: const {},
      temporaryHostPath: '/tmp/kelivo-task',
      temporaryRuntimePath: '/tmp/kelivo-task',
      outputRuntimePath: '/workspace/output',
      timeout: const Duration(minutes: 1),
      commandPrefix: '',
    );
    final command = execution.wrapCommand('echo test');
    expect(command, contains('__kelivo_status=\$?'));
    expect(command, contains('__kelivo_tmp_kb=\$(du -sk'));
    expect(command, contains('__kelivo_output_kb=\$(du -sk'));
    expect(command, contains('__KELIVO_OUTPUT_LIMIT_EXCEEDED__'));
    expect(command, contains('exit "\$__kelivo_status"'));
  });

  test('RuntimeProfileSnapshotRecord validates and round trips safe archive metadata', () {
    final snapshot = RuntimeProfileSnapshotRecord(
      id: 'snapshot-1',
      profileId: 'profile-1',
      ownerId: 'workspace-1',
      scope: RuntimeProfileScope.project,
      archivePath: '/workspace/.kelivo/runtime-profile-snapshots/profile-1/snapshot-1.tar.gz',
      sha256: List.filled(64, 'a').join(),
      sizeBytes: 1024,
      ecosystems: const {RuntimeProfileEcosystem.python},
      createdAt: DateTime.utc(2026, 11, 17),
      label: 'Before install',
    );
    final restored = RuntimeProfileSnapshotRecord.fromJson(snapshot.toJson());
    expect(restored.id, snapshot.id);
    expect(restored.profileId, snapshot.profileId);
    expect(restored.sha256, snapshot.sha256);
    expect(restored.ecosystems, snapshot.ecosystems);
    expect(restored.label, 'Before install');
  });

  test('RuntimeProfileSnapshotRecord rejects archive traversal paths', () {
    expect(
      () => RuntimeProfileSnapshotRecord.fromJson({
        'id': 'snapshot-1',
        'profileId': 'profile-1',
        'ownerId': 'workspace-1',
        'scope': 'project',
        'archivePath': '/tmp/../sensitive/snapshot-1.tar.gz',
        'sha256': List.filled(64, 'a').join(),
        'sizeBytes': 1024,
        'ecosystems': ['python'],
        'createdAt': DateTime.utc(2026, 11, 17).toIso8601String(),
      }),
      throwsFormatException,
    );
  });

  test('RuntimeProcessRecord preserves its process session across JSON and copy', () {
    final record = RuntimeProcessRecord(
      id: 'record-1',
      profileId: 'profile-1',
      ownerId: 'workspace-1',
      runId: 'run-1',
      commandLabel: 'python',
      status: RuntimeProcessStatus.running,
      startedAt: DateTime.utc(2026, 11, 8),
      sessionId: 'app-session-1',
    );

    final restored = RuntimeProcessRecord.fromJson(record.toJson());
    expect(restored.sessionId, 'app-session-1');
    expect(restored.copyWith(status: RuntimeProcessStatus.succeeded).sessionId,
        'app-session-1');
  });

  test('legacy running records without a session are distinguishable', () {
    final record = RuntimeProcessRecord.fromJson({
      'id': 'record-legacy',
      'profileId': 'profile-1',
      'ownerId': 'workspace-1',
      'runId': 'run-legacy',
      'status': 'running',
      'startedAt': DateTime.utc(2026, 11, 8).toIso8601String(),
    });

    expect(record.status, RuntimeProcessStatus.running);
    expect(record.sessionId, isEmpty);
  });
}
