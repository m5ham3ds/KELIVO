import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/services/extensions/conversational_extension_service.dart';
import 'package:Kelivo/core/services/extensions/extension_command_tools.dart';
import 'package:Kelivo/core/services/extensions/extension_operation_repository.dart';
import 'package:Kelivo/core/services/extensions/extension_registry_repository.dart';
import 'package:Kelivo/core/services/skills/skills_service.dart';
import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/services/workspace/tool_run_registry.dart';
import 'package:Kelivo/core/services/workspace/workspace_paths.dart';
import 'package:Kelivo/core/services/workspace/workspace_tool_context.dart';

Uint8List _skillZip({
  required String body,
  String name = 'cinematic-demo',
  String? permissions,
  String? directoryName,
}) {
  final permissionMetadata = permissions == null
      ? ''
      : 'metadata:\n  kelivo.permissions: $permissions\n';
  final skillDirectory = directoryName ?? name;
  final archive = Archive()
    ..addFile(
      ArchiveFile.string('$skillDirectory/SKILL.md', '''
---
name: $name
description: A test Skill for conversational management.
$permissionMetadata---
$body
'''),
    )
    ..addFile(
      ArchiveFile.string('$skillDirectory/helper.sh', 'echo not-executed'),
    );
  return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
}

Uint8List _multiSkillZip({String version = 'v1'}) => Uint8List.fromList(ZipEncoder().encodeBytes(
  Archive()
    ..addFile(ArchiveFile.string('repo-main/skills/pdf-tools/SKILL.md', '''
---
name: pdf-tools
description: PDF helper Skill.
---
PDF instructions $version.
'''))
    ..addFile(ArchiveFile.string('repo-main/skills/csv-tools/SKILL.md', '''
---
name: csv-tools
description: CSV helper Skill.
---
CSV instructions $version.
''')),
));

void main() {
  late AppDatabase database;
  late ExtensionEntityStore store;
  late ExtensionRegistryRepository registry;
  late ExtensionOperationRepository operations;
  late Directory temp;
  late Directory skillsDirectory;
  late SkillsService skills;
  late ConversationalExtensionService service;
  late ToolRunRegistry toolRuns;
  late Uint8List zip;
  late int zipDownloads;
  late String skillsCatalogBody;
  late String githubRemoteSha;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    store = ExtensionEntityStore(database);
    await database.customSelect('SELECT 1;').getSingle();
    registry = ExtensionRegistryRepository(store);
    operations = ExtensionOperationRepository(store);
    toolRuns = ToolRunRegistry();
    temp = await Directory.systemTemp.createTemp('kelivo_extension_commands_');
    skillsDirectory = Directory(p.join(temp.path, 'skills'));
    zip = _skillZip(body: '# First version');
    zipDownloads = 0;
    skillsCatalogBody = 'Catalog instructions.';
    githubRemoteSha = List<String>.filled(40, 'a').join();
    final client = MockClient((request) async {
      if (request.url.host == 'api.github.com' &&
          request.url.path == '/repos/acme/demo/commits/main') {
        return http.Response(jsonEncode({'sha': githubRemoteSha}), 200);
      }
      if (request.url.host == 'codeload.github.com') {
        zipDownloads++;
        return http.Response.bytes(zip, 200);
      }
      if (request.url.host == 'skills.sh' &&
          request.url.path == '/api/v1/skills/search') {
        return http.Response(jsonEncode({
          'data': [
            {
              'id': 'acme/agent-skills/sample-skill',
              'name': 'Sample Skill',
              'description': 'A catalog fixture',
              'sourceType': 'github',
              'source': 'acme/agent-skills',
              'installs': 42,
              'url': 'https://skills.sh/acme/agent-skills/sample-skill',
            },
          ],
        }), 200);
      }
      if (request.url.host == 'skills.sh' &&
          request.url.path == '/api/v1/skills/acme/agent-skills/sample-skill') {
        return http.Response(jsonEncode({
          'id': 'acme/agent-skills/sample-skill',
          'sourceType': 'github',
          'files': [
            {
              'path': 'SKILL.md',
              'contents': '---\nname: sample-skill\ndescription: A catalog Skill.\n---\n$skillsCatalogBody',
            },
            {'path': 'references/guide.md', 'contents': '# Guide'},
          ],
        }), 200);
      }
      return http.Response('not found', 404);
    });
    skills = SkillsService(
      store: store,
      extensionRegistry: registry,
      skillsDirectory: skillsDirectory,
      httpClient: client,
    );
    await skills.loaded;
    service = ConversationalExtensionService(
      skills: skills,
      registry: registry,
      operations: operations,
      toolRuns: toolRuns,
      conversationId: 'conversation-1',
    );
  });

  tearDown(() async {
    skills.dispose();
    toolRuns.dispose();
    await database.close();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('exposes a unique set of typed extension tools', () {
    final definitions = ExtensionCommandToolCatalog.definitions();
    final names = [
      for (final definition in definitions)
        (definition['function'] as Map)['name'] as String,
    ];
    expect(names.toSet(), hasLength(names.length));
    expect(names, unorderedEquals(ExtensionCommandToolNames.all));
    expect(names, contains(ExtensionCommandToolNames.install));
    expect(names, contains(ExtensionCommandToolNames.rollback));
    final installDefinition = definitions.singleWhere(
      (definition) =>
          (definition['function'] as Map)['name'] ==
          ExtensionCommandToolNames.install,
    );
    final function = installDefinition['function'] as Map;
    final parameters = function['parameters'] as Map;
    expect(parameters['type'], 'object');
    expect(parameters['additionalProperties'], isFalse);
    expect(parameters['properties'], isA<Map>());
    expect(parameters['required'], contains('source'));
    expect((parameters['properties'] as Map).keys, contains('skill_paths'));
    final searchDefinition = definitions.singleWhere(
      (definition) =>
          (definition['function'] as Map)['name'] ==
          ExtensionCommandToolNames.search,
    );
    final searchProperties =
        ((searchDefinition['function'] as Map)['parameters'] as Map)['properties']
            as Map;
    expect(
      ((searchProperties['scope'] as Map)['enum'] as List),
      contains('catalog'),
    );
  });


  test(
    'installs an attached Skill ZIP from the conversation chat mount',
    () async {
      final workspaceDir =
          Directory(p.join(temp.path, 'attached_zip_workspace'))
            ..createSync(recursive: true);
      final chatDir = Directory(p.join(temp.path, 'attached_zip_chat'))
        ..createSync(recursive: true);
      final attachmentsDir = Directory(p.join(chatDir.path, 'attachments'))
        ..createSync(recursive: true);
      final outputsDir = Directory(p.join(chatDir.path, 'outputs'))
        ..createSync(recursive: true);
      final attachedZip =
          File(p.join(attachmentsDir.path, 'animation-director.zip'))
            ..writeAsBytesSync(
              _skillZip(name: 'animation-director', body: '# Motion direction'),
              flush: true,
            );
      final now = DateTime.utc(2026, 11, 14);
      final context = WorkspaceToolContext(
        workspace: Workspace(
          id: 'attached-zip-workspace',
          name: 'Attached ZIP test',
          kind: WorkspaceKind.managed,
          defaultCwd: '/workspace',
          createdAt: now,
          updatedAt: now,
        ),
        binding: const WorkspaceBinding(
          workspaceId: 'attached-zip-workspace',
          cwd: '/workspace',
        ),
        paths: WorkspacePaths.sandboxed(
          workspaceHostRoot: workspaceDir.path,
          sessionHostDir: chatDir.path,
          skillsHostDir: skillsDirectory.path,
        ),
        sessionDir: chatDir,
        outputsDir: outputsDir,
        conversationId: 'conversation-1',
      );

      final response = await service.handle(
        ExtensionCommandToolNames.install,
        {
          'kind': 'skill',
          'source': '/chat/attachments/animation-director.zip',
        },
        workspaceContext: context,
        toolCallId: 'install-attached-animation-director',
      );

      expect(response, contains('Installed 1 Agent Skill'));
      expect(response, contains('animation-director'));
      expect(skills.skills, hasLength(1));
      expect(skills.skills.single.record.enabled, isTrue);
      expect(
        await skills.readSkillMarkdown(skills.skills.single.record.id),
        contains('# Motion direction'),
      );
      expect(await attachedZip.exists(), isTrue);
    },
  );

  test(
    'rejects an attached Skill ZIP with mismatched folder metadata with actionable details',
    () async {
      final workspaceDir =
          Directory(p.join(temp.path, 'invalid_attached_zip_workspace'))
            ..createSync(recursive: true);
      final chatDir = Directory(p.join(temp.path, 'invalid_attached_zip_chat'))
        ..createSync(recursive: true);
      final attachmentsDir = Directory(p.join(chatDir.path, 'attachments'))
        ..createSync(recursive: true);
      final outputsDir = Directory(p.join(chatDir.path, 'outputs'))
        ..createSync(recursive: true);
      File(p.join(attachmentsDir.path, 'animation-director.zip'))
        ..writeAsBytesSync(
          _skillZip(
            name: 'animation-director',
            directoryName: 'wrong-folder-name',
            body: '# Motion direction',
          ),
          flush: true,
        );
      final now = DateTime.utc(2026, 11, 14);
      final context = WorkspaceToolContext(
        workspace: Workspace(
          id: 'invalid-attached-zip-workspace',
          name: 'Invalid attached ZIP test',
          kind: WorkspaceKind.managed,
          defaultCwd: '/workspace',
          createdAt: now,
          updatedAt: now,
        ),
        binding: const WorkspaceBinding(
          workspaceId: 'invalid-attached-zip-workspace',
          cwd: '/workspace',
        ),
        paths: WorkspacePaths.sandboxed(
          workspaceHostRoot: workspaceDir.path,
          sessionHostDir: chatDir.path,
          skillsHostDir: skillsDirectory.path,
        ),
        sessionDir: chatDir,
        outputsDir: outputsDir,
        conversationId: 'conversation-1',
      );

      await expectLater(
        service.handle(
          ExtensionCommandToolNames.install,
          {
            'kind': 'skill',
            'source': '/chat/attachments/animation-director.zip',
          },
          workspaceContext: context,
          toolCallId: 'install-invalid-attached-animation-director',
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            allOf(
              contains('No compatible Agent Skills'),
              contains('animation-director'),
              contains('name must match Skill directory'),
            ),
          ),
        ),
      );
      expect(skills.skills, isEmpty);
    },
  );

  test('read-only update check detects a new GitHub revision without mutating the installed Skill', () async {
    await service.handle(
      ExtensionCommandToolNames.install,
      {'source': 'https://github.com/acme/demo/tree/main'},
      toolCallId: 'install-check-updates',
    );
    final skillId = skills.skills.single.record.id;
    final beforeMarkdown = await skills.readSkillMarkdown(skillId);
    final beforeDownloadCount = zipDownloads;
    githubRemoteSha = List<String>.filled(40, 'b').join();

    final response = jsonDecode(await service.handle(
      ExtensionCommandToolNames.checkUpdates,
      {'id': skillId},
    )) as Map<String, dynamic>;

    expect(response['readOnly'], isTrue);
    expect(response['filesChanged'], isFalse);
    expect(response['updatesFound'], 1);
    expect((response['results'] as List).single['status'], 'update_available');
    expect(await skills.readSkillMarkdown(skillId), beforeMarkdown);
    expect(skills.hasRollback(skillId), isFalse);
    expect(zipDownloads, beforeDownloadCount);
  });

  test(
    'installs, disables, enables, updates, rolls back, lists and removes',
    () async {
      const source =
          'https://github.com/acme/demo/tree/main';
      final installed = await service.handle(
        ExtensionCommandToolNames.install,
        {'source': source},
        toolCallId: 'install-call-1',
      );
      expect(installed, contains('Installed Skill'));
      expect(installed, contains('not executed'));
      expect(skills.skills, hasLength(1));
      final liveRun = toolRuns.of(
        'install-call-1',
        conversationId: 'conversation-1',
      );
      expect(liveRun?.status, ToolRunStatus.succeeded);
      expect(liveRun?.stdoutSoFar, contains('Completed successfully'));

      final skillId = skills.skills.single.record.id;
      final registryRecord = await registry.get('skill', skillId);
      expect(registryRecord, isNotNull);
      expect(
        registryRecord!.source.uri,
        'https://github.com/acme/demo/tree/main',
      );
      expect(registryRecord.source.ref, 'main');
      expect(registryRecord.source.subpath, isNull);

      await service.handle(ExtensionCommandToolNames.disable, {'id': skillId});
      expect(skills.skills.single.record.enabled, isFalse);
      await service.handle(ExtensionCommandToolNames.enable, {'id': skillId});
      expect(skills.skills.single.record.enabled, isTrue);

      zip = _skillZip(body: '# Updated version');
      githubRemoteSha = List<String>.filled(40, 'b').join();
      final checkJson = jsonDecode(await service.handle(
        ExtensionCommandToolNames.checkUpdates,
        {'id': skillId},
      )) as Map<String, dynamic>;
      expect(checkJson['readOnly'], isTrue);
      expect(checkJson['filesChanged'], isFalse);
      expect(checkJson['updatesFound'], 1);
      expect((checkJson['results'] as List).single['status'], 'update_available');
      expect(await skills.readSkillMarkdown(skillId), contains('First version'));
      expect(skills.hasRollback(skillId), isFalse);

      final updated = await service.handle(ExtensionCommandToolNames.update, {
        'id': skillId,
      });
      expect(updated, contains('Updated'));
      expect(
        await skills.readSkillMarkdown(skillId),
        contains('Updated version'),
      );
      expect(skills.hasRollback(skillId), isTrue);

      await service.handle(ExtensionCommandToolNames.rollback, {'id': skillId});
      expect(
        await skills.readSkillMarkdown(skillId),
        contains('First version'),
      );

      final listed = await service.handle(ExtensionCommandToolNames.list, {
        'status': 'enabled',
        'include_history': true,
      });
      expect(listed, contains(skillId));
      expect(listed, contains('Recent Extension Operations'));

      await service.handle(ExtensionCommandToolNames.remove, {'id': skillId});
      expect(skills.skills, isEmpty);
      expect(await registry.get('skill', skillId), isNull);

      final history = await operations.list(limit: 20);
      expect(
        history.map((entry) => entry.operation),
        containsAll([
          'install',
          'disable',
          'enable',
          'update',
          'rollback',
          'remove',
        ]),
      );
      expect(
        history.every(
          (entry) => entry.status == ExtensionOperationStatus.succeeded,
        ),
        isTrue,
      );
    },
  );

  test('extension list preserves original Skill status and reports pack membership separately', () async {
    final original = await skills.importFromText('''
---
name: original-skill
description: Original standalone Skill.
---
Original instructions.
''');
    final companion = await skills.importFromText('''
---
name: companion-skill
description: Companion standalone Skill.
---
Companion instructions.
''');
    await skills.setEnabled(original.record.id, false);
    final pack = await skills.saveSkillPack(
      name: 'Creative Toolkit',
      shortcut: 'creative_toolkit',
      skillIds: [original.record.id, companion.record.id],
    );
    await skills.setSkillPackEnabled(pack.id, true);

    final listing = await service.handle(
      ExtensionCommandToolNames.list,
      {'status': 'all', 'include_history': false},
    );

    expect(listing, contains('**original-skill**'));
    expect(listing, contains('standalone: disabled; effective: enabled by pack'));
    expect(listing, contains('**companion-skill**'));
    expect(listing, contains('standalone: enabled; effective: enabled'));
    expect(listing, contains('## Skill Packs'));
    expect(listing, contains('**Creative Toolkit** (/creative_toolkit, enabled)'));
    expect(skills.skills.singleWhere((skill) => skill.record.id == original.record.id).record.enabled, isFalse);

    final disabledOnly = await service.handle(
      ExtensionCommandToolNames.list,
      {'status': 'disabled', 'include_history': false},
    );
    expect(disabledOnly, contains('**original-skill**'));
    expect(disabledOnly, isNot(contains('**companion-skill**')));
    expect(disabledOnly, contains('effective: enabled by pack'));
  });

  test('updating one member of a repository pack refreshes every pack member in one download', () async {
    zip = _multiSkillZip();
    final installed = await service.handle(
      ExtensionCommandToolNames.install,
      {'source': 'https://github.com/acme/repo/tree/main/skills'},
    );
    expect(installed, contains('Installed 2 Agent Skills'));
    expect(skills.skillPacks, hasLength(1));
    final pack = skills.skillPacks.single;
    final beforeDownloads = zipDownloads;
    zip = _multiSkillZip(version: 'v2 updated');

    final result = await service.handle(
      ExtensionCommandToolNames.update,
      {'id': pack.skillIds.first},
    );

    expect(result, contains('Updated Skill Pack'));
    expect(result, contains('/${pack.shortcut}'));
    expect(zipDownloads - beforeDownloads, 1);
    for (final skillId in pack.skillIds) {
      expect(await skills.readSkillMarkdown(skillId), contains('v2 updated'));
      expect(skills.hasRollback(skillId), isTrue);
    }
  });

  test('reviews declared Skill permissions after install and on inspect', () async {
    zip = _skillZip(
      body: '# Permission review fixture',
      permissions: 'workspace.project.write,device.root_access',
    );
    final installed = await service.handle(ExtensionCommandToolNames.install, {
      'source': 'https://github.com/acme/demo/tree/main',
    });
    expect(installed, contains('Permission review'));
    expect(installed, contains('workspace.project.write'));
    expect(installed, contains('high risk'));
    expect(installed, contains('device.root_access'));
    expect(installed, contains('unknown risk'));
    expect(installed, contains('blocked until reviewed'));
    expect(installed, contains('not granted automatically'));

    final skillId = skills.skills.single.record.id;
    final inspected = await service.handle(ExtensionCommandToolNames.inspect, {
      'id': skillId,
    });
    expect(inspected, contains('### Permission review'));
    expect(inspected, contains('device.root_access'));
    expect(inspected, contains('not granted automatically'));
  });

  test(
    'does not persist credential-like GitHub query strings in operation history',
    () async {
      const unsafeSource =
          'https://github.com/acme/demo/tree/main?access_token=do-not-store';
      await expectLater(
        service.handle(ExtensionCommandToolNames.install, {
          'source': unsafeSource,
        }),
        throwsFormatException,
      );
      final history = await operations.list();
      expect(history, hasLength(1));
      expect(history.single.target, 'local-source');
      expect(history.single.source, 'local-source');
      expect(
        history.single.toJson().toString(),
        isNot(contains('do-not-store')),
      );
    },
  );

  test(
    'rejects unsupported extension kinds before performing changes',
    () async {
      await expectLater(
        service.handle(ExtensionCommandToolNames.install, {
          'kind': 'engine',
          'source': 'https://github.com/acme/demo',
        }),
        throwsFormatException,
      );
      expect(skills.skills, isEmpty);
      expect(await operations.list(), isEmpty);
    },
  );

  test(
    'inspect previews a public GitHub Skill without installing it',
    () async {
      final inspected = await service.handle(
        ExtensionCommandToolNames.inspect,
        {'source': 'https://github.com/acme/demo/tree/main'},
      );
      expect(inspected, contains('First version'));
      expect(inspected, contains('scriptsAreNotExecuted'));
      expect(skills.skills, isEmpty);
    },
  );

  test('searches and inspects skills.sh catalog entries through chat tools', () async {
    final result = jsonDecode(await service.handle(
      ExtensionCommandToolNames.search,
      {'query': 'sample', 'scope': 'catalog'},
    )) as Map<String, dynamic>;
    expect(result['skillsShCatalog'], isA<List>());
    expect((result['skillsShCatalog'] as List).single['id'],
        'acme/agent-skills/sample-skill');

    final inspected = jsonDecode(await service.handle(
      ExtensionCommandToolNames.inspect,
      {'source': 'https://skills.sh/acme/agent-skills/sample-skill'},
    )) as Map<String, dynamic>;
    expect(inspected['name'], 'sample-skill');
    expect(inspected['scriptsAreNotExecuted'], isTrue);
    expect(skills.skills, isEmpty);

    final installed = await service.handle(
      ExtensionCommandToolNames.install,
      {'source': 'https://skills.sh/acme/agent-skills/sample-skill'},
    );
    expect(installed, contains('Installed 1 Agent Skill'));
    expect(skills.skills.single.record.source.name, 'skillsSh');
    expect(skills.skills.single.name, 'sample-skill');
  });

  test('updates an installed skills.sh Skill through the chat update tool', () async {
    await service.handle(
      ExtensionCommandToolNames.install,
      {'source': 'https://skills.sh/acme/agent-skills/sample-skill'},
    );
    skillsCatalogBody = 'Updated catalog instructions.';

    final result = await service.handle(
      ExtensionCommandToolNames.update,
      {'id': 'sample-skill'},
    );

    expect(result, contains('Updated'));
    final installed = skills.skills.single;
    expect(
      File(installed.skillMdPath).readAsStringSync(),
      contains('Updated catalog instructions.'),
    );
    final source = await registry.get('skill', 'sample-skill');
    expect(source?.source.ref, 'acme/agent-skills/sample-skill');
    expect(source?.source.uri, 'https://skills.sh/acme/agent-skills/sample-skill');
  });

  test('update tool can refresh all remotely managed Skills without an id', () async {
    await service.handle(
      ExtensionCommandToolNames.install,
      {'source': 'https://skills.sh/acme/agent-skills/sample-skill'},
    );
    skillsCatalogBody = 'Updated through update-all.';

    final result = await service.handle(
      ExtensionCommandToolNames.update,
      {'all': true},
    );

    expect(result, contains('Updated 1 Skills'));
    expect(result, contains('0 failed'));
    expect(
      File(skills.skills.single.skillMdPath).readAsStringSync(),
      contains('Updated through update-all.'),
    );
  });

  test('installs selected Skills from a multi-Skill GitHub repository', () async {
    zip = _multiSkillZip();
    final result = await service.handle(
      ExtensionCommandToolNames.install,
      {
        'source': 'https://github.com/acme/repo/tree/main/skills',
        'skill_paths': ['skills/pdf-tools'],
      },
    );
    expect(result, contains('Installed 1 Agent Skill'));
    expect(skills.skills, hasLength(1));
    expect(skills.skills.single.name, 'pdf-tools');
  });

}
