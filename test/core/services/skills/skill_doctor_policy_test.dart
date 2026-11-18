import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/runtime_profiles/runtime_profile_models.dart';
import 'package:Kelivo/core/services/skills/skill_doctor_service.dart';

void main() {
  group('SkillDoctorPolicy', () {
    test('instruction-only Skills do not require a Runtime Profile', () {
      expect(
        SkillDoctorPolicy.requiresRuntimeProfile({
          'capabilities': [
            {'kind': 'instruction_only', 'entryPoints': []},
          ],
        }),
        isFalse,
      );
    });

    test('local scripts and CLI capabilities require an owned Runtime Profile', () {
      for (final kind in ['local_script', 'cli_binary']) {
        expect(
          SkillDoctorPolicy.requiresRuntimeProfile({
            'capabilities': [
              {'kind': kind, 'entryPoints': []},
            ],
          }),
          isTrue,
          reason: '$kind must be Profile-bound',
        );
      }
    });

    test('required ecosystems are inferred only from declared entrypoints', () {
      final ecosystems = SkillDoctorPolicy.requiredEcosystems({
        'capabilities': [
          {
            'kind': 'local_script',
            'entryPoints': [
              'scripts/render.py',
              'scripts/prepare.mjs',
              'scripts/cleanup.sh',
              'examples/readme.md',
            ],
          },
          {
            'kind': 'cli_binary',
            'entryPoints': ['bin/ffmpeg'],
          },
        ],
      });

      expect(ecosystems, {
        RuntimeProfileEcosystem.python,
        RuntimeProfileEcosystem.node,
        RuntimeProfileEcosystem.shell,
      });
    });

    test('non-script capability kinds do not infer runtimes from referenced filenames', () {
      expect(
        SkillDoctorPolicy.requiredEcosystems({
          'capabilities': [
            {'kind': 'mcp_server', 'entryPoints': ['server.py']},
            {'kind': 'http_api_connector', 'entryPoints': ['client.js']},
            {'kind': 'native_kelivo_tool', 'entryPoints': ['helper.sh']},
            {'kind': 'workflow', 'entryPoints': ['steps/convert.mjs']},
            {'kind': 'future_adapter_kind', 'entryPoints': ['worker.py']},
          ],
        }),
        isEmpty,
      );
      for (final kind in [
        'mcp_server',
        'http_api_connector',
        'native_kelivo_tool',
        'workflow',
        'future_adapter_kind',
      ]) {
        expect(
          SkillDoctorPolicy.requiresRuntimeProfile({
            'capabilities': [
              {'kind': kind, 'entryPoints': ['server.py']},
            ],
          }),
          isFalse,
          reason: '$kind has no local-script Runtime Profile contract yet',
        );
      }
    });

    test('command probe names reject shell metacharacters and paths', () {
      expect(SkillDoctorPolicy.isSafeCommandName('python3'), isTrue);
      expect(SkillDoctorPolicy.isSafeCommandName('ffmpeg-static'), isTrue);
      expect(SkillDoctorPolicy.isSafeCommandName('bad;touch'), isFalse);
      expect(SkillDoctorPolicy.isSafeCommandName('../python'), isFalse);
      expect(SkillDoctorPolicy.isSafeCommandName(''), isFalse);
    });

    test('readiness assessment never reuses a previous Profile verification', () {
      final requirements = SkillDoctorPolicy.readinessRequirements({
        'runtimeProfileVerification': {
          'status': 'passed',
          'profileId': 'old-profile',
          'validatedAt': '2026-01-01T00:00:00Z',
        },
        'capabilities': [
          {'kind': 'local_script', 'entryPoints': ['scripts/main.py']},
        ],
      });

      expect(requirements, isNot(contains('runtimeProfileVerification')));
      expect(requirements['capabilities'], isNotEmpty);
    });

    test('profile rules are generic and do not depend on bundled Skill names', () {
      final genericRequirements = {
        'capabilities': [
          {
            'kind': 'local_script',
            'id': 'custom-vendor-agent-script',
            'entryPoints': ['tools/worker.py'],
          },
        ],
      };

      expect(SkillDoctorPolicy.requiresRuntimeProfile(genericRequirements), isTrue);
      expect(
        SkillDoctorPolicy.requiredEcosystems(genericRequirements),
        contains(RuntimeProfileEcosystem.python),
      );
    });
  });
}
