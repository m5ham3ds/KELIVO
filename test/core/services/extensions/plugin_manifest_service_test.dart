import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/extension_record.dart';
import 'package:Kelivo/core/services/extensions/plugin_manifest_service.dart';
import 'package:Kelivo/core/services/skills/skill_archive.dart';
import 'package:Kelivo/core/services/extensions/extension_registry_repository.dart';

import '../../../support/business_test_harness.dart';

void main() {
  late BusinessTestHarness harness;
  late ExtensionRegistryRepository registry;
  late Directory source;
  late Directory pluginsRoot;
  late PluginManifestService service;

  Future<void> writePluginFile(String relativePath, String contents) async {
    final file = File(p.join(source.path, relativePath));
    await file.parent.create(recursive: true);
    await file.writeAsString(contents);
  }

  Future<void> createValidPlugin() async {
    await writePluginFile(
      '.claude-plugin/plugin.json',
      '''
{
  "name": "Demo Plugin",
  "version": "1.0.0",
  "description": "A metadata-only test plugin",
  "author": {"name": "KELIVO Tests"},
  "commands": "./commands/",
  "agents": "agents",
  "hooks": "hooks/hooks.json",
  "mcpServers": {"demo": {"command": "do-not-run"}},
  "xFutureField": {"preserve": true, "apiToken": "must-not-persist"}
}
''',
    );
    await writePluginFile('commands/hello.md', '# Hello command');
    await writePluginFile('agents/reviewer.md', '# Reviewer agent');
    await writePluginFile('skills/summarizer/SKILL.md', '---\nname: summarizer\n---\n');
    await writePluginFile(
      'skills/summarizer/references/guide.md',
      '# Supporting reference',
    );
    await writePluginFile('hooks/hooks.json', '{"hooks": {}}');
    await writePluginFile('.mcp.json', '{"mcpServers": {}}');
    await writePluginFile(
      'scripts/not-executed.sh',
      '#!/bin/sh\nprintf "this must remain inert"\n',
    );
  }

  setUp(() async {
    harness = await createBusinessTestHarness();
    registry = ExtensionRegistryRepository(
      ExtensionEntityStore(harness.database),
    );
    source = await Directory.systemTemp.createTemp('kelivo-plugin-source-');
    pluginsRoot = await Directory.systemTemp.createTemp('kelivo-plugin-store-');
    service = PluginManifestService(
      registry: registry,
      pluginsRoot: pluginsRoot,
    );
    await createValidPlugin();
  });

  tearDown(() async {
    if (await source.exists()) await source.delete(recursive: true);
    if (await pluginsRoot.exists()) await pluginsRoot.delete(recursive: true);
  });

  test('inspects a Claude Plugin directory and retains unknown metadata', () async {
    final inspection = await service.inspectDirectory(source);

    expect(inspection.canInstall, isTrue);
    expect(inspection.errors, isEmpty);
    expect(inspection.components.map((item) => item.kind), containsAll([
      'command',
      'agent',
      'skill',
      'hook',
      'mcp_server',
      'script',
    ]));
    expect(
      inspection.components
          .where((item) => item.kind == 'hook')
          .single
          .status,
      'disabled_by_default',
    );
    expect(
      inspection.components
          .where((item) => item.kind == 'script')
          .single
          .status,
      'unsupported',
    );
    expect(
      inspection.warnings.any((warning) => warning.contains('xFutureField')),
      isTrue,
    );
    expect(
      inspection.components.where((item) => item.kind == 'skill'),
      hasLength(1),
    );
    expect(inspection.fileCount, greaterThanOrEqualTo(8));
  });

  test('rejects traversal and missing declared paths before installation', () async {
    await writePluginFile(
      '.claude-plugin/plugin.json',
      '{"name":"Bad Path","commands":"../outside"}',
    );
    final inspection = await service.inspectDirectory(source);

    expect(inspection.canInstall, isFalse);
    expect(
      inspection.errors,
      contains('unsafe_component_path:command'),
    );
    await expectLater(
      service.installDirectory(sourceDirectory: source),
      throwsFormatException,
    );
    expect(await registry.get('plugin', 'bad-path'), isNull);
  });

  test('rejects symlink entries inside a Plugin directory', () async {
    final external = File(
      p.join(
        source.parent.path,
        'kelivo-plugin-external-${DateTime.now().microsecondsSinceEpoch}.txt',
      ),
    );
    await external.writeAsString('outside plugin root');
    final link = Link(p.join(source.path, 'commands/external.md'));
    await link.create(external.path);

    await expectLater(
      service.inspectDirectory(source),
      throwsFormatException,
    );
    await external.delete();
  });

  test('rejects missing manifest component paths', () async {
    await writePluginFile(
      '.claude-plugin/plugin.json',
      '{"name":"Missing Component","commands":"commands/not-there"}',
    );
    final inspection = await service.inspectDirectory(source);

    expect(inspection.canInstall, isFalse);
    expect(
      inspection.errors,
      contains('missing_component_path:command:commands/not-there'),
    );
  });

  test('rejects duplicate component names instead of silently shadowing them', () async {
    await writePluginFile('commands/nested/HELLO.md', '# Duplicate');
    final inspection = await service.inspectDirectory(source);

    expect(inspection.canInstall, isFalse);
    expect(
      inspection.errors,
      contains('duplicate_component_name:command:hello'),
    );
  });

  test('installs, lists, rolls back a failed update, updates and uninstalls atomically', () async {
    final installed = await service.installDirectory(
      sourceDirectory: source,
      source: const ExtensionSource(
        type: 'local',
        ref: 'fixture-v1',
      ),
    );
    expect(installed.kind, 'plugin');
    expect(installed.status.name, 'installed');
    expect(installed.id, 'demo-plugin');
    expect(await registry.get('plugin', installed.id), isNotNull);
    final unknownFields = installed.metadata['unknownFields'] as Map;
    final futureField = unknownFields['xFutureField'] as Map;
    expect(futureField['preserve'], isTrue);
    expect(futureField.containsKey('apiToken'), isFalse);
    expect(
      (installed.metadata['warnings'] as List).any(
        (warning) => warning.toString().contains('sensitive_manifest_field_omitted'),
      ),
      isTrue,
    );
    expect(
      await registry.componentsForPlugin(installed.id),
      hasLength(6),
    );

    final destination = Directory(p.join(pluginsRoot.path, installed.id));
    final originalCommand = await File(
      p.join(destination.path, 'commands/hello.md'),
    ).readAsString();
    final previousDigest = installed.digest;

    await writePluginFile('commands/hello.md', '# Updated command');
    final failingService = PluginManifestService(
      registry: registry,
      pluginsRoot: pluginsRoot,
      beforeRegistryWrite: (_) async {
        throw StateError('simulated registry write failure');
      },
    );
    await expectLater(
      failingService.installDirectory(sourceDirectory: source),
      throwsStateError,
    );
    expect(
      await File(p.join(destination.path, 'commands/hello.md')).readAsString(),
      originalCommand,
    );
    expect(
      (await registry.get('plugin', installed.id))!.digest,
      previousDigest,
    );

    final updated = await service.installDirectory(sourceDirectory: source);
    expect(updated.digest, isNot(previousDigest));
    expect(
      await File(p.join(destination.path, 'commands/hello.md')).readAsString(),
      '# Updated command',
    );

    await service.uninstallPlugin(installed.id);
    expect(await registry.get('plugin', installed.id), isNull);
    expect(await destination.exists(), isFalse);
  });

  test('never executes scripts during inspection or install', () async {
    final marker = File(
      p.join(
        source.parent.path,
        'kelivo-plugin-script-${DateTime.now().microsecondsSinceEpoch}.marker',
      ),
    );
    await File(p.join(source.path, 'scripts/not-executed.sh')).writeAsString(
      '#!/bin/sh\ntouch "${marker.path}"\n',
    );
    try {
      final inspection = await service.inspectDirectory(source);
      expect(inspection.canInstall, isTrue);
      await service.installDirectory(sourceDirectory: source);
      expect(await marker.exists(), isFalse);
    } finally {
      if (await marker.exists()) await marker.delete();
    }
  });

  test('rejects traversal paths in Plugin ZIP entries', () async {
    final temporary = await Directory.systemTemp.createTemp(
      'kelivo-plugin-malicious-zip-',
    );
    final zipFile = File(p.join(temporary.path, 'plugin.zip'));
    try {
      final bytes = encodeSkillZip({
        'bad-plugin/.claude-plugin/plugin.json': '''
{"name":"Zip Traversal","commands":"commands"}
'''.codeUnits,
        'bad-plugin/commands/../outside.md': '# escaped'.codeUnits,
      });
      await zipFile.writeAsBytes(bytes, flush: true);
      await expectLater(
        service.installArchive(archiveFile: zipFile),
        throwsFormatException,
      );
      expect(await registry.get('plugin', 'zip-traversal'), isNull);
    } finally {
      await temporary.delete(recursive: true);
    }
  });

  test('imports a Plugin ZIP rooted at a repository folder', () async {
    final archiveFiles = <String, List<int>>{};
    await for (final entity in source.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final relative = p.relative(entity.path, from: source.path)
            .replaceAll(p.separator, '/');
        archiveFiles['demo-plugin-main/' + relative] = await entity.readAsBytes();
      }
    }
    final archiveBytes = encodeSkillZip(archiveFiles);
    final temporary = await Directory.systemTemp.createTemp(
      'kelivo-plugin-zip-test-',
    );
    final zipFile = File(p.join(temporary.path, 'plugin.zip'));
    try {
      await zipFile.writeAsBytes(archiveBytes, flush: true);
      final record = await service.installArchive(archiveFile: zipFile);
      expect(record.kind, 'plugin');
      expect(record.id, 'demo-plugin');
      expect(await registry.componentsForPlugin(record.id), hasLength(6));
    } finally {
      await temporary.delete(recursive: true);
    }
  });
}
