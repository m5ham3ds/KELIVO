import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/skills/skill_execution_security.dart';

void main() {
  test('passes only runtime bootstrap values to Skill processes', () {
    final result = SkillExecutionSecurityPolicy.runtimeBootstrapEnvironment({
      'PATH': '/usr/bin:/bin',
      'VIRTUAL_ENV': '/profile/python',
      'NODE_PATH': '/profile/node/node_modules',
      'CUSTOM_API_HINT': 'private-value',
      'CI_PASSWORD': 'secret-value',
      'HOME': '/root',
    });

    expect(result, {
      'PATH': '/usr/bin:/bin',
      'VIRTUAL_ENV': '/profile/python',
      'NODE_PATH': '/profile/node/node_modules',
    });
    expect(result.values, isNot(contains('private-value')));
    expect(result.values, isNot(contains('secret-value')));
  });

  test('redacts exact argv and credential-like input values from process output', () {
    final values = SkillExecutionSecurityPolicy.collectSensitiveValues(
      arguments: const ['--api-key=long-secret-command-value', 'short'],
      inputs: const {
        'nested': {
          'access_token': 'nested-token-value',
          'normal': 'not-secret',
        },
      },
    );
    final output = SkillExecutionSecurityPolicy.redactOutput(
      'argv=--api-key=long-secret-command-value '
      'token=nested-token-value normal=not-secret',
      knownSensitiveValues: values,
    );

    expect(output, contains('argv=[REDACTED]'));
    expect(output, contains('token=[REDACTED]'));
    expect(output, contains('not-secret'));
    expect(output, isNot(contains('long-secret-command-value')));
    expect(output, isNot(contains('nested-token-value')));
  });

  test('redacts environment-style credential names with prefixes and suffixes', () {
    final output = SkillExecutionSecurityPolicy.redactOutput(
      'AWS_SECRET_ACCESS_KEY=top-secret-value\n'
      'CI_GITHUB_TOKEN: token-value-123456\n'
      'AUTHORIZATION: Bearer ABCdef0123456789token\n'
      'NORMAL_SETTING=visible',
    );

    expect(output, contains('AWS_SECRET_ACCESS_KEY=[REDACTED]'));
    expect(output, contains('CI_GITHUB_TOKEN: [REDACTED]'));
    expect(output, contains('AUTHORIZATION: [REDACTED]'));
    expect(output, contains('NORMAL_SETTING=visible'));
    expect(output, isNot(contains('top-secret-value')));
    expect(output, isNot(contains('token-value-123456')));
    expect(output, isNot(contains('ABCdef0123456789token')));
  });

  test('approval summary accepts counts and never retains raw task or input data', () {
    final summary = SkillExecutionSecurityPolicy.approvalSummary(
      executionGrantId: 'test-grant-id-1234',
      skillId: 'safe-skill-id',
      entryPoint: 'scripts/run.py',
      runtimeProfileId: 'profile-1',
      argumentCount: 2,
      inputCount: 1,
      inputFileCount: 1,
      expectedOutputCount: 1,
      permissionReview: const [
        {'permission': 'runtime.rootfs.write', 'risk': 'critical'},
      ],
      workspaceOutputPath: '.kelivo/skill-execution/<run-id>/io/output',
    );

    final encoded = summary.toString();
    expect(summary['execution_grant_id'], 'test-grant-id-1234');
    expect(summary['grant_scope'], 'single_run');
    expect(summary['argument_count'], 2);
    expect(summary['input_count'], 1);
    expect(summary['input_file_count'], 1);
    expect(summary['expected_output_count'], 1);
    expect(encoded, isNot(contains('private-task-text')));
    expect(encoded, isNot(contains('secret-input-value')));
    expect(encoded, isNot(contains('/private/user/file')));
  });

  test('approval and execution reports disclose the shared writable RootFS', () {
    final approval = SkillExecutionSecurityPolicy.approvalBoundary(
      workspaceOutputPath: '.kelivo/skill-execution/run/io/output',
    );
    final report = SkillExecutionSecurityPolicy.executionBoundary();

    expect(approval['explicitRiskAcknowledgementRequired'], isTrue);
    expect(approval['sharedRootFs'], contains('shared and writable'));
    expect(report['sharedRootFsMountedWritable'], isTrue);
    expect(report['kernelSandbox'], isFalse);
    expect(report['networkRestricted'], isFalse);
    expect(report['installedSkillsMounted'], isFalse);
    expect(report['workspaceRootMounted'], isFalse);
    expect(report['workspaceRunStagingMounted'], isTrue);
    expect(report['customProfileEnvironmentPassed'], isFalse);
    expect(report['credentialEnvironmentPassedToGuest'], isFalse);
    expect(report['sourceAndInputBindsMarkedReadOnly'], isTrue);
    expect(report['readOnlyBindEnforcement'], 'best_effort_common_command_wrappers');
  });
}
