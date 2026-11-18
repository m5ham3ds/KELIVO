import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/skills/skill_capability_registry.dart';
import 'package:Kelivo/core/services/skills/skill_readiness.dart';

void main() {
  group('Phase 13K capability registry', () {
    test('application capability catalog is independent from installed Skills', () {
      final catalog = SkillCapabilityRegistry.catalogJson();
      final entries = (catalog['capabilities'] as List).whereType<Map>().toList();
      final ids = entries.map((entry) => entry['id']).toSet();

      expect(catalog['registryId'], 'kelivo.skill-capabilities');
      expect(ids, contains('agent_skill.instructions'));
      expect(ids, contains('agent_skill.local_scripts'));
      expect(ids, contains('agent_skill.local_scripts.python'));
      expect(ids, contains('agent_skill.mcp_server'));
      expect(ids, contains('agent_skill.http_api_connector'));
      expect(ids, contains('agent_skill.workflow'));
      expect(catalog['policy'], isA<Map>());
    });

    test('declared script and MCP capabilities map to application support honestly', () {
      final assessment = SkillCapabilityRegistry.assessRequirements({
        'commands': [
          {'name': 'python3', 'status': 'installed', 'verifiedIn': 'base_proot_environment'},
        ],
        'capabilities': [
          {'id': 'script-1', 'kind': 'local_script', 'entryPoints': ['scripts/run.py']},
          {'id': 'mcp-1', 'kind': 'mcp_server', 'entryPoints': []},
        ],
      });
      final items = (assessment['requiredCapabilities'] as List).whereType<Map>().toList();

      expect(items.firstWhere((item) => item['kind'] == 'local_script')['status'],
          'requires_runtime_profile_and_approval');
      expect(items.firstWhere((item) => item['kind'] == 'mcp_server')['status'],
          'not_operational_in_current_skill_adapter');
    });

    test('multiple local script runtimes produce a stable combined capability title', () {
      final assessment = SkillCapabilityRegistry.assessRequirements({
        'commands': [],
        'capabilities': [
          {
            'id': 'multi-script',
            'kind': 'local_script',
            'entryPoints': ['scripts/run.py', 'scripts/postprocess.sh'],
          },
        ],
      });
      final item = (assessment['requiredCapabilities'] as List).whereType<Map>().single;

      expect(item['title'], 'Python Skill scripts, Bash/Shell Skill scripts');
      expect(item['applicationCapabilityIds'], [
        'agent_skill.local_scripts.python',
        'agent_skill.local_scripts.shell',
      ]);
    });

    test('unknown capability titles fall back to their declared kind', () {
      final assessment = SkillCapabilityRegistry.assessRequirements({
        'commands': [],
        'capabilities': [
          {'id': 'custom-capability', 'kind': 'custom_unregistered_capability'},
        ],
      });
      final item = (assessment['requiredCapabilities'] as List).whereType<Map>().single;

      expect(item['title'], 'custom_unregistered_capability');
      expect(item['status'], 'unknown');
    });

    test('unknown local script extensions are not guessed to be Python', () {
      final assessment = SkillCapabilityRegistry.assessRequirements({
        'commands': [],
        'capabilities': [
          {'id': 'script-unknown', 'kind': 'local_script', 'entryPoints': ['scripts/render.bin']},
        ],
      });
      final item = (assessment['requiredCapabilities'] as List).whereType<Map>().single;
      expect(item['status'], 'unknown');
      expect(item['unclassifiedEntryPoints'], ['scripts/render.bin']);
    });

    test('a runtime profile is not verified without identity and timestamp evidence', () {
      final assessment = SkillCapabilityRegistry.assessRequirements({
        'commands': [
          {'name': 'python3', 'status': 'installed', 'verifiedIn': 'skill_runtime_profile'},
        ],
        'runtimeProfileVerification': {'status': 'passed'},
        'capabilities': [
          {'id': 'script-1', 'kind': 'local_script', 'entryPoints': ['scripts/run.py']},
        ],
      });
      final item = (assessment['requiredCapabilities'] as List).whereType<Map>().single;
      expect(item['status'], 'requires_runtime_profile_and_approval');
    });

    test('a CLI found in the base PRoot is not treated as profile-ready', () {
      final assessment = SkillCapabilityRegistry.assessRequirements({
        'commands': [
          {'name': 'ffmpeg', 'status': 'installed', 'verifiedIn': 'base_proot_environment'},
        ],
        'capabilities': [
          {'id': 'cli-1', 'kind': 'cli_binary', 'entryPoints': ['ffmpeg']},
        ],
      });
      final item = (assessment['requiredCapabilities'] as List).whereType<Map>().single;
      expect(item['status'], 'detected_in_base_environment_only');
      expect(item['relatedCommands'], [
        {'name': 'ffmpeg', 'status': 'installed', 'verifiedIn': 'base_proot_environment'},
      ]);
    });

    test('CLI entrypoint paths match command evidence by executable basename', () {
      final assessment = SkillCapabilityRegistry.assessRequirements({
        'commands': [
          {'name': 'ffmpeg', 'status': 'installed', 'verifiedIn': 'base_proot_environment'},
        ],
        'capabilities': [
          {'id': 'cli-path', 'kind': 'cli_binary', 'entryPoints': ['/usr/bin/ffmpeg']},
        ],
      });
      final item = (assessment['requiredCapabilities'] as List).whereType<Map>().single;

      expect(item['status'], 'detected_in_base_environment_only');
      expect((item['relatedCommands'] as List).single['name'], 'ffmpeg');
    });

    test('CLI runtime evidence is not trusted without profile identity and timestamp', () {
      final assessment = SkillCapabilityRegistry.assessRequirements({
        'commands': [
          {'name': 'ffmpeg', 'status': 'installed', 'verifiedIn': 'skill_runtime_profile'},
        ],
        'runtimeProfileVerification': {'status': 'passed'},
        'capabilities': [
          {'id': 'cli-incomplete-profile', 'kind': 'cli_binary', 'entryPoints': ['ffmpeg']},
        ],
      });
      final item = (assessment['requiredCapabilities'] as List).whereType<Map>().single;

      expect(item['status'], 'environment_not_verified');
    });

    test('generic local script declarations remain conditional until runtime is identified', () {
      final assessment = SkillCapabilityRegistry.assessRequirements({
        'commands': [],
        'capabilities': [
          {'id': 'generic-script', 'kind': 'local_script', 'entryPoints': []},
        ],
      });
      final item = (assessment['requiredCapabilities'] as List).whereType<Map>().single;

      expect(item['applicationCapabilityId'], 'agent_skill.local_scripts');
      expect(item['implementation'], 'implemented_conditional');
      expect(item['status'], 'requires_runtime_profile_and_approval');
      expect(item['status'], isNot('unknown'));
    });
  });

  group('Phase 13K Skill Readiness Engine', () {
    test('incomplete imports are blocked before dependency analysis can imply readiness', () {
      final result = SkillReadinessEngine.apply(
        requirements: {'schemaVersion': 1, 'commands': [], 'packages': [], 'credentials': [], 'externalServices': [], 'capabilities': []},
        importCompleteness: 'partial',
      );
      expect(result['readinessState'], 'blocked_incomplete_import');
      expect((result['readinessStages'] as Map)['installed'], containsPair('status', 'blocked'));
    });

    test('instruction-only Skill is ready for guidance but not execution', () {
      final result = SkillReadinessEngine.apply(
        requirements: {
          'schemaVersion': 1,
          'commands': [],
          'packages': [],
          'credentials': [],
          'externalServices': [],
          'capabilities': [{'kind': 'instruction_only', 'support': 'supported'}],
        },
        importCompleteness: 'complete',
      );
      expect(result['readinessState'], 'ready_for_instructions');
      expect(result['readiness'], 'instruction_only_ready');
      expect(result['readinessLevel'], 'ready_for_guidance');
      expect(result['readinessLevelLabel'], 'Ready for Guidance');
      expect(result['readinessState'], isNot('ready'));
    });

    test('base PRoot command discovery leaves dependencies pending', () {
      final result = SkillReadinessEngine.apply(
        requirements: {
          'schemaVersion': 1,
          'commands': [{'name': 'ffmpeg', 'status': 'installed', 'verifiedIn': 'base_proot_environment'}],
          'packages': [],
          'credentials': [],
          'externalServices': [],
          'capabilities': [{'kind': 'cli_binary', 'support': 'environment_work_required'}],
        },
        importCompleteness: 'complete',
      );
      expect(result['readinessState'], 'unsupported_environment');
      expect((result['readinessStages'] as Map)['dependenciesResolved'], containsPair('status', 'pending'));
      expect((result['readinessSummary'] as Map)['commandsVerified'], 0);
      expect((result['readinessSummary'] as Map)['commandsDetectedInBase'], 1);
    });

    test('unknown capability declarations block operational readiness', () {
      final result = SkillReadinessEngine.apply(
        requirements: {
          'schemaVersion': 1,
          'commands': [],
          'packages': [],
          'credentials': [],
          'externalServices': [],
          'capabilities': [
            {'kind': 'future_capability', 'support': 'unknown'},
          ],
        },
        importCompleteness: 'complete',
        validation: {
          'status': 'passed',
          'validatedAt': '2026-11-15T00:00:00Z',
          'evidence': ['placeholder-validation'],
        },
      );
      expect(result['readinessState'], 'unsupported_environment');
      expect((result['readinessSummary'] as Map)['unknownCapabilities'], 1);
    });

    test('missing credentials and adapters cannot be reported as ready', () {
      final result = SkillReadinessEngine.apply(
        requirements: {
          'schemaVersion': 1,
          'commands': [],
          'packages': [],
          'credentials': [{'name': 'VIDEO_API_KEY', 'status': 'missing_configuration'}],
          'externalServices': [],
          'capabilities': [{'kind': 'http_api_connector', 'support': 'adapter_required'}],
        },
        importCompleteness: 'complete',
      );
      expect(result['readinessState'], 'requirements_missing');
    });

    test('executable Skill requires an explicit passed validation record', () {
      final requirements = {
        'schemaVersion': 1,
        'commands': [],
        'packages': [],
        'credentials': [],
        'externalServices': [],
        'capabilities': [{'kind': 'local_script', 'support': 'conditional'}],
      };
      final pending = SkillReadinessEngine.apply(
        requirements: Map<String, Object?>.from(requirements),
        importCompleteness: 'complete',
      );
      expect(pending['readinessState'], 'dependencies_pending');

      final passed = SkillReadinessEngine.apply(
        requirements: Map<String, Object?>.from(requirements),
        importCompleteness: 'complete',
        validation: {
          'status': 'passed',
          'validatedAt': '2026-11-15T00:00:00Z',
          'evidence': ['skill-self-test:passed'],
        },
      );
      // Runtime-profile and adapter checks remain authoritative; validation
      // metadata alone must not bypass those gates.
      expect(passed['readinessState'], 'dependencies_pending');
    });

    test('fully ready requires verified runtime profile plus passed self-test evidence', () {
      final result = SkillReadinessEngine.apply(
        requirements: {
          'schemaVersion': 1,
          'commands': [
            {'name': 'python3', 'status': 'installed', 'verifiedIn': 'skill_runtime_profile'},
          ],
          'packages': [
            {'name': 'requests', 'status': 'installed_or_verified'},
          ],
          'credentials': [],
          'externalServices': [],
          'capabilities': [
            {'kind': 'local_script', 'support': 'conditional'},
          ],
          'runtimeProfileVerification': {
            'status': 'passed',
            'profileId': 'profile-video',
            'validatedAt': '2026-11-15T00:00:00Z',
          },
        },
        importCompleteness: 'complete',
        validation: {
          'status': 'passed',
          'validatedAt': '2026-11-15T00:01:00Z',
          'evidence': ['smoke-test:passed'],
          'capabilityResults': {
            'local_script': {
              'status': 'passed',
              'evidence': ['python-smoke:output-file-verified'],
            },
          },
        },
      );
      expect(result['readinessState'], 'ready');
      expect(result['readinessLevel'], 'fully_ready');
      expect(result['readinessLevelLabel'], 'Fully Ready');
      expect((result['readinessStages'] as Map)['validated'], containsPair('status', 'complete'));
    });

    test('composition snapshot marks old or absent readiness as not checked', () {
      final report = {
        'sourceDigest': 'new-digest',
        'requirements': {'schemaVersion': 1},
        'environmentAssessment': {
          'sourceDigest': 'old-digest',
          'readinessState': 'ready',
        },
      };
      final snapshot = SkillReadinessEngine.compositionSnapshot(report);
      expect(snapshot['readinessState'], 'stale_source');
      expect(snapshot['environmentMustBeRecheckedBeforeExecution'], isTrue);
    });
  });
}
