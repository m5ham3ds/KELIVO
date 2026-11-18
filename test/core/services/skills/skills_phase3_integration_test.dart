import 'dart:io';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/skill_record.dart';
import 'package:Kelivo/core/services/extensions/extension_registry_repository.dart';
import 'package:Kelivo/core/services/skills/github_credential_store.dart';
import 'package:Kelivo/core/services/skills/skills_catalog_adapter.dart';
import 'package:Kelivo/core/services/skills/skills_service.dart';

List<int> _repositoryZip() => ZipEncoder().encodeBytes(
  Archive()
    ..addFile(ArchiveFile.string('repo-main/skills/pdf-tools/SKILL.md', '''
---
name: pdf-tools
description: Read PDF documents.
---
PDF instructions.
'''))
    ..addFile(ArchiveFile.string(
      'repo-main/skills/pdf-tools/references/formats.md', '# Formats',
    ))
    ..addFile(ArchiveFile.string(
      'repo-main/skills/pdf-tools/scripts/read.py', 'print("not run")',
    ))
    ..addFile(ArchiveFile.string('repo-main/skills/csv-tools/SKILL.md', '''
---
name: csv-tools
description: Work with CSV files.
---
CSV instructions.
'''))
    ..addFile(ArchiveFile.string(
      'repo-main/skills/csv-tools/assets/example.csv', 'a,b\n1,2',
    ))
    ..addFile(ArchiveFile.string('repo-main/README.md', 'Repository readme')),
);

void main() {
  late AppDatabase database;
  late ExtensionEntityStore store;
  late ExtensionRegistryRepository registry;
  late DirectoryFixture fixture;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    store = ExtensionEntityStore(database);
    registry = ExtensionRegistryRepository(store);
    await database.customSelect('SELECT 1;').getSingle();
    fixture = DirectoryFixture();
    await fixture.create();
  });

  tearDown(() async {
    await database.close();
    await fixture.delete();
  });

  test('imports a selected Skill from a multi-Skill GitHub subfolder', () async {
    final zip = _repositoryZip();
    final client = MockClient((request) async {
      expect(request.url.host, 'codeload.github.com');
      return http.Response.bytes(zip, 200);
    });
    final service = SkillsService(
      store: store,
      extensionRegistry: registry,
      skillsDirectory: fixture.skills,
      httpClient: client,
      credentialStore: MemoryGitHubCredentialStore(),
    );
    addTearDown(service.dispose);
    await service.loaded;

    final candidates = <String>[];
    final imported = await service.importFromGitHubRepository(
      'https://github.com/acme/repo/tree/main/skills',
      chooseSkills: (available) async {
        candidates.addAll(available.map((item) => item.path));
        return {'skills/pdf-tools'};
      },
    );

    expect(candidates, unorderedEquals(['skills/pdf-tools', 'skills/csv-tools']));
    expect(imported, hasLength(1));
    expect(imported.single.name, 'pdf-tools');
    expect(File(p.join(imported.single.dir, 'references/formats.md')).existsSync(), isTrue);
    expect(File(p.join(imported.single.dir, 'scripts/read.py')).existsSync(), isTrue);
    expect(service.skills, hasLength(1));
    final record = await registry.get('skill', imported.single.record.id);
    expect(record?.source.uri, 'https://github.com/acme/repo/tree/main/skills/pdf-tools');
    expect(record?.source.subpath, 'skills/pdf-tools');
    expect(record?.source.ref, 'main');
    client.close();
  });

  test('installs all compatible Skills when explicitly selected by chooser', () async {
    final client = MockClient((_) async => http.Response.bytes(_repositoryZip(), 200));
    final service = SkillsService(
      store: store,
      extensionRegistry: registry,
      skillsDirectory: fixture.skills,
      httpClient: client,
      credentialStore: MemoryGitHubCredentialStore(),
    );
    addTearDown(service.dispose);
    await service.loaded;
    final imported = await service.importFromGitHubRepository(
      'https://github.com/acme/repo/tree/main/skills',
      chooseSkills: (candidates) async => candidates.map((item) => item.path).toSet(),
    );
    expect(imported.map((skill) => skill.name), unorderedEquals(['pdf-tools', 'csv-tools']));
    expect(service.skills, hasLength(2));
    client.close();
  });

  test('inspects multiple GitHub Skills and reports scripts are not executed', () async {
    final client = MockClient((_) async => http.Response.bytes(_repositoryZip(), 200));
    final service = SkillsService(
      store: store,
      skillsDirectory: fixture.skills,
      httpClient: client,
      credentialStore: MemoryGitHubCredentialStore(),
    );
    addTearDown(service.dispose);
    await service.loaded;
    final preview = await service.inspectGitHubSkill(
      'https://github.com/acme/repo/tree/main/skills',
    );
    expect(preview['skillCount'], 2);
    expect(preview['scriptsAreNotExecuted'], isTrue);
    expect(preview['candidates'], isA<List>());
    expect(service.skills, isEmpty);
    client.close();
  });

  test('local Skill inspection previews extras without installing or running scripts', () async {
    final source = Directory(p.join(fixture.root.path, 'local-skill'));
    await source.create(recursive: true);
    final script = File(p.join(source.path, 'scripts', 'setup.sh'));
    await script.parent.create(recursive: true);
    await script.writeAsString('#!/bin/sh\necho must-not-run\n');
    await File(p.join(source.path, 'references.md')).writeAsString('# Reference');
    await File(p.join(source.path, 'SKILL.md')).writeAsString('''
---
name: local-skill
description: Inspect a local skill package.
license: MIT
metadata:
  author: local-test
---
Read the reference before using the skill.
''');

    final service = SkillsService(
      store: store,
      extensionRegistry: registry,
      skillsDirectory: fixture.skills,
      httpClient: MockClient((_) async => http.Response('', 404)),
      credentialStore: MemoryGitHubCredentialStore(),
    );
    addTearDown(service.dispose);
    await service.loaded;

    final preview = await service.inspectLocalSource(source.path);
    expect(preview['name'], 'local-skill');
    expect(preview['license'], 'MIT');
    expect(preview['metadata'], {'author': 'local-test'});
    expect(preview['fileCount'], 3);
    expect(preview['scriptCount'], 1);
    expect(preview['scriptsAreNotExecuted'], isTrue);
    expect(preview['bodyPreview'], contains('Read the reference'));
    expect(service.skills, isEmpty);
    expect(await script.readAsString(), contains('must-not-run'));
  });

  test('imports a skills.sh package with references, scripts and assets preserved', () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'skills.sh');
      expect(request.url.path, '/api/v1/skills/acme/agent-skills/pdf-tools');
      return http.Response(jsonEncode({
        'id': 'acme/agent-skills/pdf-tools',
        'sourceType': 'github',
        'hash': 'feedbeef',
        'files': [
          {
            'path': 'SKILL.md',
            'contents': '---\nname: pdf-tools\ndescription: Read PDFs.\n---\nInstructions.',
          },
          {'path': 'references/formats.md', 'contents': '# Formats'},
          {'path': 'scripts/read.py', 'contents': 'print("not run")'},
          {'path': 'assets/example.txt', 'contents': 'asset'},
        ],
      }), 200);
    });
    final service = SkillsService(
      store: store,
      extensionRegistry: registry,
      skillsDirectory: fixture.skills,
      httpClient: client,
      skillsCatalogAdapter: SkillsShAdapter(client),
      credentialStore: MemoryGitHubCredentialStore(),
    );
    addTearDown(service.dispose);
    await service.loaded;

    final skill = await service.importFromSkillsCatalog('acme/agent-skills/pdf-tools');
    expect(skill.record.source, SkillSource.skillsSh);
    expect(File(p.join(skill.dir, 'references/formats.md')).existsSync(), isTrue);
    expect(File(p.join(skill.dir, 'scripts/read.py')).readAsStringSync(), contains('not run'));
    expect(File(p.join(skill.dir, 'assets/example.txt')).readAsStringSync(), 'asset');
    final record = await registry.get('skill', skill.record.id);
    expect(record?.source.uri, 'https://skills.sh/acme/agent-skills/pdf-tools');
    client.close();
  });

  test('groups skills.sh entries from one repository and refreshes the pack together', () async {
    var revision = 1;
    var resolves = 0;
    final client = MockClient((request) async {
      expect(request.url.host, 'skills.sh');
      final segments = request.url.pathSegments;
      expect(segments.take(3).toList(), ['api', 'v1', 'skills']);
      final catalogId = segments.skip(3).join('/');
      expect(catalogId, anyOf(
        'acme/agent-skills/yt-audit',
        'acme/agent-skills/yt-seo',
      ));
      resolves++;
      final slug = catalogId.split('/').last;
      return http.Response(jsonEncode({
        'id': catalogId,
        'sourceType': 'github',
        'hash': 'revision-$revision',
        'files': [
          {
            'path': 'SKILL.md',
            'contents': '---\nname: $slug\ndescription: $slug helper.\n---\n$slug instructions v$revision.',
          },
          {'path': 'references/guide.md', 'contents': 'guide v$revision'},
        ],
      }), 200);
    });
    final service = SkillsService(
      store: store,
      extensionRegistry: registry,
      skillsDirectory: fixture.skills,
      httpClient: client,
      skillsCatalogAdapter: SkillsShAdapter(client),
      credentialStore: MemoryGitHubCredentialStore(),
    );
    addTearDown(service.dispose);
    await service.loaded;

    await service.importFromSkillsCatalog('acme/agent-skills/yt-audit');
    await service.importFromSkillsCatalog('acme/agent-skills/yt-seo');
    expect(service.skillPacks, hasLength(1));
    final pack = service.skillPacks.single;
    expect(pack.id, 'skills-sh-acme-agent-skills');
    expect(pack.name, 'Agent Skills');
    expect(pack.skillIds, ['yt-audit', 'yt-seo']);
    expect(service.canUpdateSkillPack(pack.id), isTrue);

    revision = 2;
    final updated = await service.updateSkillPack(pack.id);
    expect(updated, hasLength(2));
    expect(resolves, 4, reason: 'two installs and two refresh resolves');
    for (final skill in updated) {
      expect(File(skill.skillMdPath).readAsStringSync(), contains('instructions v2'));
      expect(File(p.join(skill.dir, 'references/guide.md')).readAsStringSync(), 'guide v2');
    }
    client.close();
  });

  test('rejects GitHub archive redirects that use a non-standard port', () async {
    final credentials = MemoryGitHubCredentialStore();
    const token = 'github_pat_test_private_read_token_0123456789';
    var archiveHostReached = false;
    var zipballRequests = 0;
    final client = MockClient((request) async {
      if (request.url.host == 'api.github.com' && request.url.path == '/user') {
        return http.Response('{}', 200);
      }
      if (request.url.host == 'api.github.com' && request.url.path.contains('/zipball/')) {
        zipballRequests++;
        if (request.headers['Authorization'] == null) {
          return http.Response('private', 404);
        }
        expect(request.headers['Authorization'], 'Bearer $token');
        return http.Response('', 302, headers: {
          'location': 'https://codeload.github.com:8443/acme/private/zip/feature-private',
        });
      }
      if (request.url.host == 'codeload.github.com') {
        archiveHostReached = true;
      }
      return http.Response('not found', 404);
    });
    final service = SkillsService(
      store: store,
      extensionRegistry: registry,
      skillsDirectory: fixture.skills,
      httpClient: client,
      credentialStore: credentials,
    );
    addTearDown(service.dispose);
    await service.loaded;
    await service.saveGitHubPrivateAccessToken(token);

    await expectLater(
      service.importFromGitHubRepository(
        'https://github.com/acme/private?ref=feature/private',
        chooseSkills: (_) async => const <String>{},
      ),
      throwsA(isA<HttpException>()),
    );
    expect(zipballRequests, 2);
    expect(archiveHostReached, isFalse);
    client.close();
  });

  test('validates private GitHub token and never forwards it to archive host', () async {
    final credentials = MemoryGitHubCredentialStore();
    final zip = ZipEncoder().encodeBytes(
      Archive()..addFile(ArchiveFile.string('repo-main/SKILL.md', '''
---
name: private-tool
description: A private test Skill.
---
Private instructions.
''')),
    );
    const token = 'github_pat_test_private_read_token_0123456789';
    var unauthenticatedZipballAttempt = false;
    var authenticatedZipballAttempt = false;
    var archiveRequestWasUnauthenticated = false;
    final client = MockClient((request) async {
      if (request.url.host == 'api.github.com' && request.url.path == '/user') {
        expect(request.headers['Authorization'], 'Bearer $token');
        return http.Response('{}', 200);
      }
      if (request.url.host == 'api.github.com' && request.url.path.contains('/zipball/')) {
        if (request.headers['Authorization'] == null) {
          unauthenticatedZipballAttempt = true;
          return http.Response('private', 404);
        }
        authenticatedZipballAttempt = true;
        expect(request.headers['Authorization'], 'Bearer $token');
        return http.Response('', 302, headers: {
          'location': 'https://codeload.github.com/acme/private/zip/feature-private',
        });
      }
      if (request.url.host == 'codeload.github.com') {
        archiveRequestWasUnauthenticated = request.headers['Authorization'] == null;
        return http.Response.bytes(zip, 200);
      }
      return http.Response('not found', 404);
    });
    final service = SkillsService(
      store: store,
      extensionRegistry: registry,
      skillsDirectory: fixture.skills,
      httpClient: client,
      credentialStore: credentials,
    );
    addTearDown(service.dispose);
    await service.loaded;

    await service.saveGitHubPrivateAccessToken(token);
    expect(await service.hasGitHubPrivateAccess(), isTrue);
    final imported = await service.importFromGitHubRepository(
      'https://github.com/acme/private?ref=feature/private',
      chooseSkills: (candidates) async => {candidates.single.path},
    );
    expect(imported.single.record.id, 'private-tool');
    expect(unauthenticatedZipballAttempt, isTrue);
    expect(authenticatedZipballAttempt, isTrue);
    expect(archiveRequestWasUnauthenticated, isTrue);
    await service.clearGitHubPrivateAccess();
    expect(await service.hasGitHubPrivateAccess(), isFalse);
    client.close();
  });
}

class DirectoryFixture {
  late final Directory root;
  late final Directory skills;

  Future<void> create() async {
    root = await Directory.systemTemp.createTemp('kelivo_phase3_test_');
    skills = Directory(p.join(root.path, 'skills'));
  }

  Future<void> delete() async {
    if (await root.exists()) await root.delete(recursive: true);
  }
}
