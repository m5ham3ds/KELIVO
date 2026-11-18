import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/skills/skill_requirements.dart';

void main() {
  test('discovers runtimes, commands, packages, credentials and external hosts without executing content', () {
    final report = SkillRequirementsAnalyzer.analyze(
      skillId: 'video-builder',
      skillMarkdown: '''---
name: video-builder
description: Build short videos
metadata:
  kelivo.required-commands: "ffmpeg curl"
  kelivo.required-env: "OPENAI_API_KEY"
---

## Prerequisites
Install ffmpeg and use https://api.openai.com/v1/ for generation.
''',
      files: const [
        {'path': 'SKILL.md', 'scope': 'skill'},
        {'path': 'scripts/render.py', 'scope': 'skill'},
        {'path': 'scripts/setup.sh', 'scope': 'skill'},
      ],
      capabilities: const [
        {
          'id': 'local-scripts',
          'kind': 'local_script',
          'entryPoints': ['scripts/render.py', 'scripts/setup.sh'],
        },
        {'kind': 'mcp_server'},
        {'kind': 'http_api_connector'},
        {'kind': 'native_kelivo_tool'},
      ],
      dependencies: const [
        {
          'ecosystem': 'python',
          'manifestPath': 'requirements.txt',
          'dependencies': ['requests >=2.31'],
        },
        {
          'ecosystem': 'rust',
          'manifestPath': 'Cargo.toml',
          'dependencies': ['serde 1.0'],
        },
      ],
      inspectedTextFiles: const {
        'SKILL.md': 'Use https://api.openai.com/v1/ and set OPENAI_API_KEY.',
        'scripts/render.py': '#!/usr/bin/env python3\n# requires ffmpeg\n',
        'scripts/setup.sh': 'apt-get install -y ffmpeg imagemagick\npython3 -m pip install imageio-ffmpeg==0.5.1\nnpm install @img/sharp-linux-arm64@0.33.5\n',
        'mcp.json': '{"transport":"stdio","command":"npx"}',
        '.env.example': 'AWS_ACCESS_KEY_ID=not-a-real-key\nDATABASE_URL=postgres://user:secret@db.example.invalid/main\nGOOGLE_APPLICATION_CREDENTIALS=/run/secrets/service.json',
      },
    );

    final commands = (report['commands'] as List).whereType<Map>().toList();
    final commandNames = commands.map((item) => item['name']).toSet();
    expect(commandNames, containsAll(['ffmpeg', 'curl', 'python3', 'npx']));
    expect(commands.every((item) => item['status'] == 'not_checked'), isTrue);

    final packages = (report['packages'] as List).whereType<Map>().toList();
    expect(packages.any((item) => item['name'] == 'requests' && item['ecosystem'] == 'python'), isTrue);
    expect(packages.any((item) => item['name'] == 'serde' && item['ecosystem'] == 'rust' && item['managerSupported'] == false), isTrue);
    expect(packages.any((item) => item['name'] == 'imagemagick' && item['ecosystem'] == 'system'), isTrue);
    expect(packages.any((item) => item['name'] == 'imageio-ffmpeg' && item['declaration'] == 'imageio-ffmpeg==0.5.1'), isTrue);
    expect(packages.any((item) => item['name'] == '@img/sharp-linux-arm64' && item['ecosystem'] == 'node'), isTrue);

    final credentials = (report['credentials'] as List).whereType<Map>().toList();
    expect(credentials.map((item) => item['name']), containsAll([
      'OPENAI_API_KEY', 'AWS_ACCESS_KEY_ID', 'DATABASE_URL',
      'GOOGLE_APPLICATION_CREDENTIALS',
    ]));
    expect(report.toString(), isNot(contains('secret-value')));
    expect(report.toString(), isNot(contains('not-a-real-key')));
    expect(report.toString(), isNot(contains('postgres://user:secret')));

    final services = (report['externalServices'] as List).whereType<Map>().toList();
    expect(services.map((item) => item['host']), contains('api.openai.com'));
    expect(services.every((item) => item['verification'] == 'not_contacted'), isTrue);

    final capabilities = (report['capabilities'] as List).whereType<Map>().toList();
    expect(capabilities.map((item) => item['support']), containsAll([
      'conditional', 'manual_adapter_required', 'adapter_required', 'requires_kelivo_development',
    ]));
    final safety = report['safety'] as Map;
    expect(safety['skillScriptsExecuted'], isFalse);
    expect(safety['packagesInstalled'], isFalse);
    expect(safety['mcpServersStarted'], isFalse);
    expect(safety['externalApisCalled'], isFalse);
    expect(safety['secretValuesExtractedOrReturned'], isFalse);
  });


  test('does not infer GNU make from ordinary Markdown prose and reports line evidence', () {
    final report = SkillRequirementsAnalyzer.analyze(
      skillId: 'creative-video-guidance',
      skillMarkdown: '''---
name: creative-video-guidance
description: Direct a video
---
Make the character feel expressive and make the scene more dynamic.

## Examples
The instructions help make a professional reel.
''',
      files: const [
        {'path': 'SKILL.md', 'scope': 'skill'},
      ],
      capabilities: const [
        {'kind': 'instruction_only'},
      ],
      dependencies: const [],
      inspectedTextFiles: const {
        'SKILL.md': 'Make transitions smooth and make sure the scene reads clearly.',
      },
    );

    final commands = (report['commands'] as List).whereType<Map>().toList();
    expect(commands.map((item) => item['name']), isNot(contains('make')));

    final declared = SkillRequirementsAnalyzer.analyze(
      skillId: 'native-build-skill',
      skillMarkdown: '''---
name: native-build-skill
description: Build native assets
---

## Prerequisites
Install GNU make before running the build.
''',
      files: const [
        {'path': 'SKILL.md', 'scope': 'skill'},
      ],
      capabilities: const [],
      dependencies: const [],
      inspectedTextFiles: const {},
    );
    final make = (declared['commands'] as List)
        .whereType<Map>()
        .where((item) => item['name'] == 'make')
        .single;
    expect((make['evidence'] as List).single, 'SKILL.md:7 (prerequisites)');
  });

  test('does not infer commands from JavaScript example assets', () {
    final report = SkillRequirementsAnalyzer.analyze(
      skillId: 'visual-reference-skill',
      skillMarkdown: '---\nname: visual-reference-skill\ndescription: Visuals\n---',
      files: const [
        {'path': 'SKILL.md', 'scope': 'skill'},
        {'path': 'examples/scenes.js', 'scope': 'skill'},
      ],
      capabilities: const [
        {'id': 'instructions', 'kind': 'instruction_only'},
      ],
      dependencies: const [],
      inspectedTextFiles: const {
        'examples/scenes.js': '// node is a reference label in this example\nconst title = "make a scene";\n',
      },
    );

    final commands = (report['commands'] as List).whereType<Map>().toList();
    expect(commands, isEmpty);
  });

  test('keeps capability identity and entrypoint evidence in the requirement report', () {
    final report = SkillRequirementsAnalyzer.analyze(
      skillId: 'identified-script-skill',
      skillMarkdown: '---\nname: identified-script-skill\ndescription: Scripts\n---',
      files: const [
        {'path': 'SKILL.md', 'scope': 'skill'},
        {'path': 'tools/render.py', 'scope': 'skill'},
      ],
      capabilities: const [
        {
          'id': 'render-video-script',
          'kind': 'local_script',
          'entryPoints': ['tools/render.py'],
        },
      ],
      dependencies: const [],
      inspectedTextFiles: const {},
    );

    final capabilities = (report['capabilities'] as List).whereType<Map>().toList();
    expect(capabilities, hasLength(1));
    expect(capabilities.single['id'], 'render-video-script');
    expect(capabilities.single['entryPoints'], ['tools/render.py']);
    expect(capabilities.single['requiredForReadiness'], isTrue);
  });

  test('infers runtime toolchains from dependency manifests even without script files', () {
    final report = SkillRequirementsAnalyzer.analyze(
      skillId: 'manifest-only',
      skillMarkdown: '---\nname: manifest-only\ndescription: Manifest\n---',
      files: const [{'path': 'SKILL.md', 'scope': 'skill'}],
      capabilities: const [],
      dependencies: const [
        {'ecosystem': 'python', 'manifestPath': 'requirements.txt', 'dependencies': ['requests>=2.31']},
        {'ecosystem': 'node', 'manifestPath': 'package.json', 'dependencies': ['sharp ^0.33']},
        {'ecosystem': 'rust', 'manifestPath': 'Cargo.toml', 'dependencies': ['serde 1.0']},
      ],
      inspectedTextFiles: const {},
    );
    final toolchains = (report['toolchains'] as List).whereType<Map>().map((item) => item['command']).toSet();
    expect(toolchains, containsAll(['python3', 'node', 'cargo']));
  });

  test('reports when no requirement evidence was found without claiming operational readiness', () {
    final report = SkillRequirementsAnalyzer.analyze(
      skillId: 'plain-guidance',
      skillMarkdown: '---\nname: plain-guidance\ndescription: Guidance\n---\nUse the written instructions.',
      files: const [{'path': 'SKILL.md', 'scope': 'skill'}],
      capabilities: const [{'kind': 'instruction_only'}],
      dependencies: const [],
      inspectedTextFiles: const {},
    );
    expect(report['readiness'], 'not_probed');
    expect(report['notes'].toString(), contains('not proof'));
  });

  test('does not claim no requirements when an external service is declared', () {
    final report = SkillRequirementsAnalyzer.analyze(
      skillId: 'service-backed-guidance',
      skillMarkdown: '''---
name: service-backed-guidance
description: Uses a remote service
metadata:
  kelivo.required-services: "video-render-api"
---
Use the configured remote video rendering service.
''',
      files: const [{'path': 'SKILL.md', 'scope': 'skill'}],
      capabilities: const [{'kind': 'instruction_only'}],
      dependencies: const [],
      inspectedTextFiles: const {},
    );
    expect(report['externalServices'], isNotEmpty);
    expect(report['notes'].toString(), isNot(contains('not proof')));
  });

  test('renders an explicit information-first report and avoids claiming package readiness', () {
    final markdown = SkillEnvironmentRequirementProbe.toMarkdown({
      'readiness': 'requirements_pending_or_adapter_work',
      'packages': [
        {
          'declaration': 'requests >=2.31',
          'ecosystem': 'python',
          'manifestPath': 'requirements.txt',
          'environmentSupport': 'pip_uv_supported_but_requires_skill_runtime_profile',
          'status': 'not_checked_in_skill_profile',
        },
      ],
      'commands': [
        {'name': 'ffmpeg', 'status': 'installed', 'verifiedIn': 'base_proot_environment', 'evidence': ['SKILL.md']},
      ],
    });
    expect(markdown, contains('not_checked_in_skill_profile'));
    expect(markdown, contains('verified only in base PRoot'));
    expect(markdown, contains('No package was installed'));
    expect(markdown, contains('no external API was called'));
    expect(SkillEnvironmentRequirementProbe.toMarkdown({
      'readiness': 'requirements_pending_or_adapter_work',
    }, arabic: true), contains('متطلبات بيئة المهارة'));
  });
}
