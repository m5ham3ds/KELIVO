import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/skills/skill_readiness.dart';

void main() {
  group('Phase 13L Skill readiness evidence levels', () {
    test('instruction-only Skills are Ready for Guidance, never Fully Ready', () {
      final result = SkillReadinessEngine.apply(
        requirements: {
          'schemaVersion': 1,
          'commands': [],
          'packages': [],
          'credentials': [],
          'externalServices': [],
          'capabilities': [
            {'id': 'written-guidance', 'kind': 'instruction_only', 'support': 'supported'},
          ],
        },
        importCompleteness: 'complete',
        validation: {
          'status': 'passed',
          'validatedAt': '2026-11-16T00:00:00Z',
          'evidence': ['instructions-read'],
        },
      );

      expect(result['readinessState'], 'ready_for_instructions');
      expect(result['readinessLevel'], 'ready_for_guidance');
      expect(result['readinessLevelLabel'], 'Ready for Guidance');
    });

    test('a passed capability is Ready for Execution while other required capabilities remain pending', () {
      final result = SkillReadinessEngine.apply(
        requirements: {
          'schemaVersion': 1,
          'commands': [
            {'name': 'python3', 'status': 'installed', 'verifiedIn': 'skill_runtime_profile'},
          ],
          'packages': [],
          'credentials': [],
          'externalServices': [],
          'capabilities': [
            {
              'id': 'render-script',
              'kind': 'local_script',
              'support': 'conditional',
              'requiredForReadiness': true,
            },
            {
              'id': 'probe-cli',
              'kind': 'local_script',
              'support': 'conditional',
              'requiredForReadiness': true,
            },
          ],
          'runtimeProfileVerification': {
            'status': 'passed',
            'profileId': 'profile-video',
            'validatedAt': '2026-11-16T00:00:00Z',
          },
        },
        importCompleteness: 'complete',
        validation: {
          'status': 'partial',
          'validatedAt': '2026-11-16T00:02:00Z',
          'evidence': ['profile-smoke-test:completed'],
          'capabilityResults': {
            'render-script': {
              'status': 'passed',
              'evidence': ['render-script:exit-0', 'output:rendered.mp4:sha256:abc123'],
            },
            'probe-cli': {'status': 'pending', 'evidence': []},
          },
        },
      );

      expect(result['readinessState'], 'ready_for_execution');
      expect(result['readinessLevel'], 'ready_for_execution');
      expect(result['readinessLevelLabel'], 'Ready for Execution');
      expect(result['validatedCapabilities'], ['render-script']);
      expect(result['pendingMandatoryCapabilities'], ['probe-cli']);
      expect((result['readinessStages'] as Map)['validated'], containsPair('status', 'partial'));
    });

    test('Fully Ready requires passed evidence for every mandatory capability', () {
      final requirements = <String, Object?>{
        'schemaVersion': 1,
        'commands': [
          {'name': 'python3', 'status': 'installed', 'verifiedIn': 'skill_runtime_profile'},
        ],
        'packages': [],
        'credentials': [],
        'externalServices': [],
        'capabilities': [
          {'id': 'render-script', 'kind': 'local_script', 'support': 'conditional'},
          {'id': 'audio-script', 'kind': 'local_script', 'support': 'conditional'},
        ],
        'runtimeProfileVerification': {
          'status': 'passed',
          'profileId': 'profile-video',
          'validatedAt': '2026-11-16T00:00:00Z',
        },
      };

      final partial = SkillReadinessEngine.apply(
        requirements: Map<String, Object?>.from(requirements),
        importCompleteness: 'complete',
        validation: {
          'status': 'passed',
          'validatedAt': '2026-11-16T00:03:00Z',
          'evidence': ['global-run:passed'],
          'capabilityResults': {
            'render-script': {'status': 'passed', 'evidence': ['render:output-verified']},
            'audio-script': {'status': 'failed', 'evidence': ['audio:exit-1']},
          },
        },
      );
      expect(partial['readinessLevel'], 'ready_for_execution');
      expect(partial['readinessLevel'], isNot('fully_ready'));

      final complete = SkillReadinessEngine.apply(
        requirements: Map<String, Object?>.from(requirements),
        importCompleteness: 'complete',
        validation: {
          'status': 'passed',
          'validatedAt': '2026-11-16T00:04:00Z',
          'evidence': ['global-run:passed'],
          'capabilityResults': {
            'render-script': {'status': 'passed', 'evidence': ['render:output-verified']},
            'audio-script': {'status': 'passed', 'evidence': ['audio:output-verified']},
          },
        },
      );
      expect(complete['readinessState'], 'ready');
      expect(complete['readinessLevel'], 'fully_ready');
      expect(complete['readinessLevelLabel'], 'Fully Ready');
      expect(complete['pendingMandatoryCapabilities'], isEmpty);

      final missingConfiguration = SkillReadinessEngine.apply(
        requirements: {
          ...requirements,
          'credentials': [
            {'name': 'VIDEO_API_KEY', 'status': 'missing_configuration'},
          ],
        },
        importCompleteness: 'complete',
        validation: {
          'status': 'passed',
          'validatedAt': '2026-11-16T00:05:00Z',
          'evidence': ['global-run:passed'],
          'capabilityResults': {
            'render-script': {'status': 'passed', 'evidence': ['render:output-verified']},
            'audio-script': {'status': 'passed', 'evidence': ['audio:output-verified']},
          },
        },
      );
      expect(missingConfiguration['readinessState'], 'requirements_missing');
      expect(missingConfiguration['readinessLevel'], isNot('fully_ready'));
    });

    test('capability evidence lists are sorted deterministically', () {
      final result = SkillReadinessEngine.apply(
        requirements: {
          'schemaVersion': 1,
          'commands': [
            {'name': 'python3', 'status': 'installed', 'verifiedIn': 'skill_runtime_profile'},
          ],
          'packages': [],
          'credentials': [],
          'externalServices': [],
          'capabilities': [
            {'id': 'zeta', 'kind': 'local_script', 'support': 'conditional'},
            {'id': 'alpha', 'kind': 'local_script', 'support': 'conditional'},
            {'id': 'theta', 'kind': 'local_script', 'support': 'conditional'},
            {'id': 'beta', 'kind': 'local_script', 'support': 'conditional'},
          ],
          'runtimeProfileVerification': {
            'status': 'passed',
            'profileId': 'profile-sorted',
            'validatedAt': '2026-11-16T00:00:00Z',
          },
        },
        importCompleteness: 'complete',
        validation: {
          'status': 'partial',
          'validatedAt': '2026-11-16T00:01:00Z',
          'evidence': ['partial-capability-validation'],
          'capabilityResults': {
            'zeta': {'status': 'passed', 'evidence': ['zeta:output-verified']},
            'beta': {'status': 'passed', 'evidence': ['beta:output-verified']},
            'theta': {'status': 'pending', 'evidence': []},
            'alpha': {'status': 'pending', 'evidence': []},
          },
        },
      );

      expect(result['validatedCapabilities'], ['beta', 'zeta']);
      expect(result['pendingMandatoryCapabilities'], ['alpha', 'theta']);
    });

    test('base PRoot detection cannot substitute for Skill-owned profile evidence', () {
      final result = SkillReadinessEngine.apply(
        requirements: {
          'schemaVersion': 1,
          'commands': [
            {'name': 'python3', 'status': 'installed', 'verifiedIn': 'base_proot_environment'},
          ],
          'packages': [],
          'credentials': [],
          'externalServices': [],
          'capabilities': [
            {'id': 'render-script', 'kind': 'local_script', 'support': 'conditional'},
          ],
          'runtimeProfileVerification': {
            'status': 'passed',
            'validatedAt': '2026-11-16T00:00:00Z',
          },
        },
        importCompleteness: 'complete',
        validation: {
          'status': 'passed',
          'validatedAt': '2026-11-16T00:01:00Z',
          'evidence': ['script:passed'],
          'capabilityResults': {
            'render-script': {'status': 'passed', 'evidence': ['output:verified']},
          },
        },
      );

      expect(result['readinessState'], 'dependencies_pending');
      expect(result['readinessLevel'], 'ready_for_guidance');
    });
  });
}
