import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/services/skills/skill_import_manifest.dart';

void main() {
  late Directory root;
  late Directory shared;

  setUp(() async {
    final temp = await Directory.systemTemp.createTemp('kelivo_skill_manifest_');
    root = Directory(p.join(temp.path, 'skill'));
    shared = Directory(p.join(temp.path, 'shared'));
    await root.create(recursive: true);
    await shared.create(recursive: true);
  });

  tearDown(() async {
    final temp = root.parent;
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('indexes hidden, nested, binary and executable source files without running them', () async {
    await File(p.join(root.path, 'SKILL.md')).writeAsString('---\nname: manifest-demo\ndescription: Demo\n---\n');
    await Directory(p.join(root.path, '.config')).create();
    await File(p.join(root.path, '.config', 'settings.yaml')).writeAsString('enabled: true\n');
    await Directory(p.join(root.path, 'scripts')).create();
    final marker = File(p.join(root.path, 'executed.marker'));
    await File(p.join(root.path, 'scripts', 'check.py')).writeAsString(
      "from pathlib import Path\nPath('${marker.path}').write_text('bad')\n",
    );
    final pngBytes = <int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0];
    await File(p.join(root.path, 'assets.bin')).writeAsBytes(pngBytes);
    await File(p.join(root.path, 'requirements.txt')).writeAsString('httpx>=0.27\n');
    await File(p.join(root.path, 'requirements-dev.txt')).writeAsString('pytest>=8.0\n');
    await File(p.join(root.path, 'pyproject.toml')).writeAsString(
      '[project]\nname = "manifest-demo"\nversion = "1.0"\n'
      '[tool.poetry.dependencies]\npython = "^3.11"\nhttpx = "^0.27"\n',
    );
    await File(p.join(root.path, 'Gemfile.lock')).writeAsString(
      'GEM\n  specs:\n    rake (13.0.6)\n    rspec (3.13.0)\n      rake (~> 13.0)\n',
    );
    await File(p.join(root.path, 'Pipfile')).writeAsString('[packages]\nrequests = "*"\n');
    await File(p.join(root.path, 'package.json')).writeAsString(jsonEncode({
      'dependencies': {'yaml': '^3.1.0'},
      'scripts': {'postinstall': 'python scripts/check.py'},
    }));
    await File(p.join(root.path, 'mcp.json')).writeAsString(jsonEncode({
      'transport': 'stdio',
      'command': 'python',
      'args': ['server.py'],
    }));
    await File(p.join(root.path, 'kelivo.workflow.yaml')).writeAsString('steps: []\n');
    await File(p.join(root.path, 'tools-entry.dart')).writeAsString('void main() {}\n');
    await File(p.join(root.path, 'kelivo.skill.json')).writeAsString(jsonEncode({
      'schemaVersion': 1,
      'capabilities': [
        {'kind': 'native_kelivo_tool', 'id': 'native-check', 'entryPoints': ['tools-entry.dart']},
      ],
    }));

    final report = await SkillImportAnalyzer.analyzeDirectory(
      skillId: 'manifest-demo',
      directory: root,
      sourceType: 'file',
    );

    final paths = report.files.map((file) => file.path).toSet();
    expect(paths, containsAll([
      'SKILL.md', '.config/settings.yaml', 'scripts/check.py', 'assets.bin',
      'requirements.txt', 'pyproject.toml', 'package.json', 'mcp.json', 'kelivo.workflow.yaml',
      'kelivo.skill.json',
    ]));
    final binary = report.files.singleWhere((file) => file.path == 'assets.bin');
    expect(binary.mediaType, 'image/png');
    expect(binary.sha256,
        'sha256:1b56b50ac4e976f488f128cabdcdffb2fc9331d6974bb9968131a415d14ade24');
    expect(binary.sizeBytes, pngBytes.length);
    expect(report.capabilities.map((item) => item.kind.wireValue), containsAll([
      'local_script', 'mcp_server', 'native_kelivo_tool', 'workflow',
    ]));
    expect(report.capabilities.every((item) => !item.executionEnabled), isTrue);
    expect(report.dependencies.map((item) => item.ecosystem), containsAll(['python', 'node', 'ruby']));
    expect(
      report.dependencies.singleWhere((item) => item.manifestPath == 'pyproject.toml').dependencies,
      contains('httpx ^0.27'),
    );
    expect(report.dependencies.singleWhere((item) => item.manifestPath == 'requirements-dev.txt').dependencies,
        contains('pytest >=8.0'));
    expect(report.dependencies.singleWhere((item) => item.manifestPath == 'Gemfile.lock').dependencies,
        containsAll(['rake 13.0.6', 'rspec 3.13.0']));
    expect(report.dependencies.singleWhere((item) => item.manifestPath == 'Pipfile').dependencies,
        contains('requests "*"'));
    final npm = report.dependencies.singleWhere((item) => item.manifestPath == 'package.json');
    expect(npm.dependencies, contains('yaml ^3.1.0'));
    expect(npm.lifecycleScriptNames, contains('postinstall'));
    expect(npm.toJson()['lifecycleScriptsExecuted'], isFalse);
    expect(marker.existsSync(), isFalse, reason: 'import analysis must never execute scripts');
  });


  test('browser example scripts are preserved but are not implicit Node entrypoints', () async {
    await File(p.join(root.path, 'SKILL.md')).writeAsString(
      '---\nname: character-reference\ndescription: Visual reference\n---\n',
    );
    await Directory(p.join(root.path, 'examples')).create();
    await File(p.join(root.path, 'examples', 'scenes.js')).writeAsString(
      'function renderAt(t) { return document.createElement(\'canvas\'); }\n',
    );
    await File(p.join(root.path, 'examples', 'sheet.html')).writeAsString(
      '<canvas id=\'sheet\'></canvas>\n',
    );

    final report = await SkillImportAnalyzer.analyzeDirectory(
      skillId: 'character-reference',
      directory: root,
      sourceType: 'file',
    );
    expect(report.files.map((file) => file.path), contains('examples/scenes.js'));
    expect(report.capabilities.map((item) => item.kind),
        contains(SkillCapabilityKind.instructionOnly));
    expect(report.capabilities.map((item) => item.kind),
        isNot(contains(SkillCapabilityKind.localScript)));
    expect(report.requirements['toolchains'], isEmpty);
  });

  test('persists a detailed environment requirements inventory with the import manifest', () async {
    await File(p.join(root.path, 'SKILL.md')).writeAsString('''---
name: video-builder
description: Build videos
metadata:
  kelivo.required-commands: "ffmpeg curl"
  kelivo.required-env: "VIDEO_API_KEY"
---

## Prerequisites
Install ffmpeg and configure https://video.example-provider.invalid/v1/.
''');
    await Directory(p.join(root.path, 'scripts')).create();
    await File(p.join(root.path, 'scripts', 'render.py')).writeAsString(
      '#!/usr/bin/env python3\n# use ffmpeg\n',
    );
    await File(p.join(root.path, 'requirements.txt')).writeAsString('requests>=2.31\n');
    await File(p.join(root.path, 'mcp.json')).writeAsString(jsonEncode({
      'transport': 'stdio', 'command': 'npx', 'args': ['server.js'],
    }));
    await File(p.join(root.path, '.env.example')).writeAsString(
      'VIDEO_API_KEY=example-placeholder\nAWS_ACCESS_KEY_ID=example-placeholder\n',
    );

    final report = await SkillImportAnalyzer.analyzeDirectory(
      skillId: 'video-builder', directory: root, sourceType: 'file',
    );
    final serialized = report.toJson();
    final requirements = serialized['requirements'] as Map;
    expect(requirements['analysisMode'], 'static_read_only');
    expect(serialized['requirementInventorySourceDigest'], serialized['sourceDigest']);
    expect(requirements['safety'], containsPair('skillScriptsExecuted', false));
    expect(requirements['safety'], containsPair('packagesInstalled', false));
    expect((requirements['toolchains'] as List).whereType<Map>().map((e) => e['command']),
        contains('python3'));
    expect((requirements['commands'] as List).whereType<Map>().map((e) => e['name']),
        containsAll(['ffmpeg', 'curl', 'npx']));
    expect((requirements['packages'] as List).whereType<Map>().any((e) => e['name'] == 'requests'), isTrue);
    expect((requirements['credentials'] as List).whereType<Map>().map((e) => e['name']),
        containsAll(['VIDEO_API_KEY', 'AWS_ACCESS_KEY_ID']));
    expect(requirements.toString(), isNot(contains('example-placeholder')));
    expect((requirements['externalServices'] as List).whereType<Map>().map((e) => e['host']),
        contains('video.example-provider.invalid'));
    expect((requirements['capabilities'] as List).whereType<Map>().map((e) => e['kind']),
        containsAll(['local_script', 'mcp_server']));
  });

  test('requirement scan limits are reported without marking preserved Skill files incomplete', () async {
    await File(p.join(root.path, 'SKILL.md')).writeAsString(
      '---\nname: scan-limits\ndescription: Scan limits\n---\n' +
          ('Requirement notes remain part of the primary Skill instructions.\n' * 9000),
    );
    await File(p.join(root.path, '.env.example')).writeAsString(
      List<String>.filled(30000, 'EXAMPLE_REQUIRED_API_KEY=placeholder').join('\n'),
    );
    final report = await SkillImportAnalyzer.analyzeDirectory(
      skillId: 'scan-limits', directory: root, sourceType: 'file',
    );
    expect(report.completeness, 'complete');
    expect(report.files.map((file) => file.path), contains('.env.example'));
    expect(report.requirements['notes'].toString(), contains('256 KiB per-file inspection limit'));
    expect(report.requirements['notes'].toString(), isNot(contains('SKILL.md exceeds the 256 KiB')));
  });

  test('classifies a Skill without discovered tools as instruction-only', () async {
    await File(p.join(root.path, 'SKILL.md')).writeAsString(
      '---\nname: instructions-only\ndescription: Instructions\n---\n',
    );
    final report = await SkillImportAnalyzer.analyzeDirectory(
      skillId: 'instructions-only', directory: root, sourceType: 'file',
    );
    expect(report.capabilities.map((item) => item.kind),
        contains(SkillCapabilityKind.instructionOnly));
  });

  test('records shared resources as explicit separate references', () async {
    await File(p.join(root.path, 'SKILL.md')).writeAsString('---\nname: shared-demo\ndescription: Demo\n---\n');
    await File(p.join(shared.path, 'requirements.txt')).writeAsString('httpx==0.27.2\n');
    await File(p.join(shared.path, 'mcp.json')).writeAsString(jsonEncode({
      'transport': 'stdio', 'command': 'python', 'args': ['server.py'],
    }));

    final report = await SkillImportAnalyzer.analyzeDirectory(
      skillId: 'shared-demo',
      directory: root,
      sourceType: 'github',
      sharedDirectory: shared,
      sharedResourceSetId: 'bundle-123',
      sharedResourcePaths: const ['requirements.txt'],
      repository: 'owner/repo',
      ref: 'main',
      commit: 'abc123',
    );

    final entry = report.files.singleWhere((file) => file.path == 'shared/requirements.txt');
    expect(entry.scope, 'shared');
    expect(entry.sourcePath, 'requirements.txt');
    expect(report.dependencies.single.manifestPath, 'shared/requirements.txt');
    expect(report.capabilities.map((item) => item.kind), isNot(contains(SkillCapabilityKind.mcpServer)),
        reason: 'shared repository config is not an implicit Skill MCP entry point');
    final sharedJson = report.toJson()['sharedResources'] as Map;
    expect(sharedJson['setId'], 'bundle-123');
    expect(sharedJson['binding'], 'read_only_reference');
    expect(sharedJson['runtimeAccessEnabled'], isFalse);
    expect(report.repository, 'owner/repo');
    expect(report.commit, 'abc123');
  });

  test('empty mcpServers object is not enough to classify a server', () async {
    await File(p.join(root.path, 'SKILL.md')).writeAsString(
      '---\nname: empty-mcp\ndescription: Demo\n---\n',
    );
    await File(p.join(root.path, 'mcp.json')).writeAsString('{"mcpServers":{}}');
    final report = await SkillImportAnalyzer.analyzeDirectory(
      skillId: 'empty-mcp', directory: root, sourceType: 'file',
    );
    expect(report.capabilities.map((entry) => entry.kind),
        isNot(contains(SkillCapabilityKind.mcpServer)));
    expect(report.capabilities.map((entry) => entry.kind),
        contains(SkillCapabilityKind.instructionOnly));
  });

  test('malformed mcp.json is preserved but not classified as MCP', () async {
    await File(p.join(root.path, 'SKILL.md')).writeAsString(
      '---\nname: invalid-mcp\ndescription: Demo\n---\n',
    );
    await File(p.join(root.path, 'mcp.json')).writeAsString('{not-json');

    final report = await SkillImportAnalyzer.analyzeDirectory(
      skillId: 'invalid-mcp', directory: root, sourceType: 'file',
    );

    expect(report.files.map((entry) => entry.path), contains('mcp.json'));
    expect(report.capabilities.map((entry) => entry.kind),
        contains(SkillCapabilityKind.instructionOnly));
    expect(report.capabilities.map((entry) => entry.kind),
        isNot(contains(SkillCapabilityKind.mcpServer)));
    expect(
      report.skipped.any((entry) =>
          entry.path == 'mcp.json' &&
          entry.reason == 'invalid_mcp_config_not_classified'),
      isTrue,
    );
  });

  test('does not infer MCP from tools directory alone', () async {
    await File(p.join(root.path, 'SKILL.md')).writeAsString('---\nname: tools-only\ndescription: Demo\n---\n');
    await Directory(p.join(root.path, 'tools')).create();
    await File(p.join(root.path, 'tools', 'server.py')).writeAsString('print("not MCP")');
    final report = await SkillImportAnalyzer.analyzeDirectory(
      skillId: 'tools-only', directory: root, sourceType: 'file',
    );
    expect(report.capabilities.map((item) => item.kind), contains(SkillCapabilityKind.localScript));
    expect(report.capabilities.map((item) => item.kind), isNot(contains(SkillCapabilityKind.mcpServer)));
  });

  test('reports local symbolic links without following them', () async {
    await File(p.join(root.path, 'SKILL.md')).writeAsString('---\nname: link-demo\ndescription: Demo\n---\n');
    final outside = File(p.join(root.parent.path, 'outside-secret.txt'))..writeAsStringSync('secret');
    final link = Link(p.join(root.path, 'outside-link.txt'));
    try {
      await link.create(outside.path);
    } on FileSystemException {
      return; // Some Windows runners do not grant symlink creation privileges.
    }
    final report = await SkillImportAnalyzer.analyzeDirectory(
      skillId: 'link-demo', directory: root, sourceType: 'file',
    );
    expect(report.files.map((file) => file.path), isNot(contains('outside-link.txt')));
    expect(
      report.skipped.any((item) =>
          item.path == 'outside-link.txt' &&
          item.reason == 'symbolic_link_not_followed'),
      isTrue,
    );
  });
}
