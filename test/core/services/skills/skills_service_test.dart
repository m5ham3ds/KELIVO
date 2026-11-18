import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/skill_record.dart';
import 'package:Kelivo/core/services/skills/core_guidance_service.dart';
import 'package:Kelivo/core/services/skills/skill_archive.dart';
import 'package:Kelivo/core/services/skills/skills_service.dart';

const _skillMd = '''
---
name: pdf-tools
description: Extract text and tables from PDF files with pdfplumber.
---
# PDF Tools
''';

class _PausingSkillStore extends ExtensionEntityStore {
  _PausingSkillStore(super.database);

  Completer<void>? pauseNextRead;
  Completer<void>? readStarted;
  bool failNextRead = false;

  @override
  Future<List<ExtensionEntity>> listByKind(String kind) async {
    if (failNextRead) {
      failNextRead = false;
      throw StateError('store temporarily unavailable');
    }
    final rows = await super.listByKind(kind);
    final pause = pauseNextRead;
    if (pause != null) {
      pauseNextRead = null;
      readStarted!.complete();
      await pause.future;
    }
    return rows;
  }
}

void main() {
  late AppDatabase database;
  late _PausingSkillStore store;
  late Directory tmp;
  late Directory skillsDir;
  late SkillsService service;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    store = _PausingSkillStore(database);
    await database.customSelect('SELECT 1;').getSingle();
    tmp = await Directory.systemTemp.createTemp('kelivo_skills_');
    skillsDir = Directory(p.join(tmp.path, 'skills'));
    service = SkillsService(store: store, skillsDirectory: skillsDir);
    await service.loaded;
  });

  Future<List<FileSystemEntity>> userSkillEntries() async {
    if (!await skillsDir.exists()) return const [];
    return skillsDir
        .list(followLinks: false)
        .where(
          (entry) =>
              p.basename(entry.path) != CoreGuidanceService.directoryName,
        )
        .toList();
  }

  tearDown(() async {
    service.dispose();
    await database.close();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test(
    'rescan drops records without SKILL.md and adopts orphan dirs',
    () async {
      await store.upsert(ExtensionEntityStore.kindSkill, 'ghost', {
        'id': 'ghost',
        'enabled': true,
        'useCount': 0,
        'source': 'file',
        'installedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
        'updatedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
      });
      final orphan = Directory(p.join(skillsDir.path, 'orphan-skill'));
      await orphan.create(recursive: true);
      await File(p.join(orphan.path, 'SKILL.md')).writeAsString('''
---
name: orphan-skill
description: Found on disk
---
body
''');

      await service.rescan();
      expect(await store.get(ExtensionEntityStore.kindSkill, 'ghost'), isNull);
      expect(service.skills.map((s) => s.record.id), contains('orphan-skill'));
      expect(
        service.skills
            .singleWhere((s) => s.record.id == 'orphan-skill')
            .record
            .source,
        SkillSource.file,
      );
      expect(
        service.skills
            .singleWhere((s) => s.record.id == 'orphan-skill')
            .description,
        'Found on disk',
      );
    },
  );

  test(
    'live rescan preserves concurrent settings, usage and imports',
    () async {
      final skill = await service.importFromText(_skillMd);
      final release = Completer<void>();
      final started = Completer<void>();
      store.pauseNextRead = release;
      store.readStarted = started;
      final scan = service.rescan();
      await started.future;
      final toggle = service.setEnabled(skill.record.id, false);
      final use = service.incrementUseCount(skill.record.id);
      final imported = service.importFromText(
        _skillMd.replaceAll('pdf-tools', 'another-skill'),
      );
      release.complete();
      await Future.wait([scan, toggle, use, imported]);
      final current = service.skills.firstWhere(
        (s) => s.record.id == skill.record.id,
      );
      expect(current.record.enabled, isFalse);
      expect(current.record.useCount, 1);
      expect(service.skills, hasLength(2));
      await service.rescan();
      final saved = service.skills.firstWhere(
        (s) => s.record.id == skill.record.id,
      );
      expect(saved.record.enabled, isFalse);
      expect(saved.record.useCount, 1);
      expect(
        service.skills
            .singleWhere((s) => s.record.id == 'another-skill')
            .record
            .source,
        SkillSource.paste,
      );
    },
  );

  test('a failed refresh does not block later imports or refreshes', () async {
    store.failNextRead = true;
    await expectLater(service.rescan(), throwsStateError);
    final skill = await service.importFromText(_skillMd);
    await service.rescan();
    expect(service.skills.single.record.id, skill.record.id);
    await Future.wait([service.delete(skill.record.id), service.rescan()]);
    expect(service.skills, isEmpty);
  });

  test('importFromText writes SKILL.md and dedupes ids', () async {
    final first = await service.importFromText(_skillMd);
    expect(first.record.id, 'pdf-tools');
    expect(first.record.source, SkillSource.paste);
    expect(File(first.skillMdPath).existsSync(), isTrue);
    expect(first.name, 'pdf-tools');

    final second = await service.importFromText(_skillMd);
    expect(second.record.id, 'pdf-tools-2');
    expect(service.skills, hasLength(2));
  });

  test('importFromFile accepts a markdown file', () async {
    final md = File(p.join(tmp.path, 'custom.md'));
    await md.writeAsString('''
---
name: from-file
description: Imported from a markdown file
---
hi
''');
    final skill = await service.importFromFile(md.path);
    expect(skill.record.id, 'from-file');
    expect(skill.record.source, SkillSource.file);
    expect(File(skill.skillMdPath).readAsStringSync(), contains('from-file'));
  });

  test(
    'importFromDirectory copies nested files into managed Skills storage',
    () async {
      final source = Directory(p.join(tmp.path, 'local-directory-skill'));
      await Directory(p.join(source.path, 'scripts')).create(recursive: true);
      await File(p.join(source.path, 'SKILL.md')).writeAsString('''
---
name: local-directory-skill
description: Imported from a local folder
---
Use the bundled helper when needed.
''');
      await File(
        p.join(source.path, 'scripts', 'helper.py'),
      ).writeAsString('print("ok")');

      final skill = await service.importFromDirectory(source.path);

      expect(skill.record.id, 'local-directory-skill');
      expect(skill.record.source, SkillSource.file);
      expect(
        File(p.join(skill.dir, 'scripts', 'helper.py')).readAsStringSync(),
        contains('print'),
      );
      final importReport = await service.getImportReport(skill.record.id);
      expect(importReport, isNotNull);
      expect(importReport!['completeness'], 'complete');
      final importFiles = (importReport['files'] as List).cast<Map>();
      expect(importFiles.map((entry) => entry['path']), contains('scripts/helper.py'));
      expect(importFiles.singleWhere((entry) => entry['path'] == 'scripts/helper.py')['sha256'], startsWith('sha256:'));
    },
  );

  test('rebuilds and persists requirement inventory for a legacy installed Skill', () async {
    final skill = await service.importFromText(_skillMd);
    await Directory(p.join(skill.dir, 'scripts')).create();
    await File(p.join(skill.dir, 'scripts', 'render.py')).writeAsString(
      '#!/usr/bin/env python3\n# requires ffmpeg\n',
    );
    await File(p.join(skill.dir, 'requirements.txt')).writeAsString('requests>=2.31\n');

    final metadataDirectory = Directory(p.join(tmp.path, 'skill-import-metadata', 'skills'));
    final sidecar = File(p.join(metadataDirectory.path, '${skill.record.id}.json'));
    final legacy = jsonDecode(await sidecar.readAsString()) as Map<String, dynamic>;
    legacy.remove('requirements');
    await sidecar.writeAsString(jsonEncode(legacy));

    final upgraded = await service.getImportReportWithRequirements(skill.record.id);
    expect(upgraded, isNotNull);
    final upgradedReport = upgraded!;
    final requirements = upgradedReport['requirements'] as Map;
    expect(requirements['analysisMode'], 'static_read_only');
    expect(upgradedReport['requirementInventorySourceDigest'], upgradedReport['sourceDigest']);
    expect((requirements['toolchains'] as List).whereType<Map>().map((e) => e['command']), contains('python3'));
    expect((requirements['commands'] as List).whereType<Map>().map((e) => e['name']), contains('ffmpeg'));
    expect((requirements['packages'] as List).whereType<Map>().map((e) => e['name']), contains('requests'));

    final persisted = jsonDecode(await sidecar.readAsString()) as Map<String, dynamic>;
    expect(persisted['requirements'], isA<Map>());
    expect(persisted['requirementInventoryUpdatedAt'], isA<String>());
  });

  test('persists a source-bound Skill readiness assessment in the import sidecar', () async {
    final skill = await service.importFromText(_skillMd);
    final report = await service.getImportReportWithRequirements(skill.record.id);
    expect(report, isNotNull);
    final assessment = <String, Object?>{
      'sourceDigest': report!['sourceDigest'],
      'readinessState': 'validation_required',
      'readinessStages': <String, Object?>{
        'installed': <String, Object?>{'status': 'complete'},
      },
      'readinessNextActions': <String>['Run the Skill self-test.'],
      'readinessCheckedAt': '2026-11-15T00:00:00Z',
    };

    await service.saveEnvironmentAssessment(skill.record.id, assessment);
    final saved = await service.getImportReport(skill.record.id);
    final persisted = saved!['environmentAssessment'] as Map;
    expect(persisted['readinessState'], 'validation_required');
    expect(persisted['sourceDigest'], saved['sourceDigest']);
    expect(persisted['persistedAt'], isA<String>());

    // A real SKILL.md edit invalidates the inventory and prevents a result
    // for the previous source digest from being attached to the edited Skill.
    await service.updateBody(
      skill.record.id,
      _skillMd.replaceFirst('Extract text and tables', 'Extract metadata and tables'),
    );
    await expectLater(
      service.saveEnvironmentAssessment(skill.record.id, {
        'sourceDigest': saved['sourceDigest'],
        'readinessState': 'ready',
      }),
      throwsA(isA<FormatException>()),
    );
    final refreshed = await service.getImportReportWithRequirements(skill.record.id);
    expect(refreshed!.containsKey('environmentAssessment'), isFalse);
    expect(refreshed['sourceDigest'], isNot(saved['sourceDigest']));
  });

  test(
    'importFromDirectory supports cancellation during a large local copy',
    () async {
      final source = Directory(p.join(tmp.path, 'cancel-local-skill'));
      await source.create(recursive: true);
      await File(p.join(source.path, 'SKILL.md')).writeAsString('''
---
name: cancel-local-skill
description: Cancellation fixture
---
''');
      await File(
        p.join(source.path, 'large.bin'),
      ).writeAsBytes(List<int>.filled(2 * 1024 * 1024, 7));
      final cancel = Completer<void>();

      await expectLater(
        service.importFromDirectory(
          source.path,
          cancelSignal: cancel.future,
          onProgress: (_) {
            if (!cancel.isCompleted) cancel.complete();
          },
        ),
        throwsA(isA<http.RequestAbortedException>()),
      );
      expect(service.skills, isEmpty);
    },
  );

  test('importFromFile extracts a zip at root or one level down', () async {
    final zipPath = p.join(tmp.path, 'packed.zip');
    File(zipPath).writeAsBytesSync(
      encodeSkillZip({
        'pdf-tools/SKILL.md': utf8.encode(_skillMd),
        'pdf-tools/helper.py': utf8.encode('print(1)'),
      }),
    );
    final skill = await service.importFromFile(zipPath);
    expect(skill.record.id, 'pdf-tools');
    expect(skill.record.source, SkillSource.file);
    expect(File(p.join(skill.dir, 'helper.py')).existsSync(), isTrue);
  });


  test('importFromFile rejects a ZIP Skill whose folder does not match its name', () async {
    final zipPath = p.join(tmp.path, 'mismatched.zip');
    File(zipPath).writeAsBytesSync(
      encodeSkillZip({
        'wrong-folder/SKILL.md': utf8.encode(_skillMd),
      }),
    );
    await expectLater(
      service.importFromFile(zipPath),
      throwsA(isA<FormatException>()),
    );
    expect(service.skills, isEmpty);
  });

  test('importFromFile rejects zip-slip', () async {
    final archive = Archive()
      ..addFile(ArchiveFile.string('../escape/SKILL.md', _skillMd));
    final zipPath = p.join(tmp.path, 'slip.zip');
    File(zipPath).writeAsBytesSync(ZipEncoder().encodeBytes(archive));
    expect(
      () => service.importFromFile(zipPath),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'importFromGitHub downloads a codeload zip via the injected client',
    () async {
      final zip = encodeSkillZip({
        'demo-main/SKILL.md': utf8.encode('''
---
name: gh-skill
description: From GitHub
---
hello
'''),
        'demo-main/notes.txt': utf8.encode('n'),
      });
      final client = MockClient((request) async {
        if (request.url.host == 'api.github.com') {
          return http.Response('{"default_branch":"main"}', 200);
        }
        if (request.url.host == 'codeload.github.com') {
          expect(request.url.path, '/acme/demo/zip/main');
          return http.Response.bytes(zip, 200);
        }
        return http.Response('missing', 404);
      });
      final github = SkillsService(
        store: store,
        skillsDirectory: skillsDir,
        httpClient: client,
      );
      addTearDown(github.dispose);
      await github.loaded;
      final skill = await github.importFromGitHub(
        'https://github.com/acme/demo',
      );
      expect(skill.record.id, 'gh-skill');
      expect(skill.record.source, SkillSource.github);
      expect(File(p.join(skill.dir, 'notes.txt')).existsSync(), isTrue);

      final nested = await github.importFromGitHub(
        'https://github.com/acme/demo/tree/main',
      );
      expect(nested.record.id, 'gh-skill-2');
    },
  );

  test('importFromGitHub follows a SKILL.md blob URL subdir', () async {
    final zip = encodeSkillZip({
      'demo-main/skills/pdf-tools/SKILL.md': utf8.encode(_skillMd),
      'demo-main/skills/pdf-tools/x.py': utf8.encode('x'),
      'demo-main/README.md': utf8.encode('no'),
    });
    final client = MockClient((request) async {
      if (request.url.host == 'codeload.github.com') {
        expect(request.url.path, contains('/zip/v1'));
        return http.Response.bytes(zip, 200);
      }
      return http.Response('{"default_branch":"main"}', 200);
    });
    final github = SkillsService(
      store: store,
      skillsDirectory: skillsDir,
      httpClient: client,
    );
    addTearDown(github.dispose);
    await github.loaded;
    final skill = await github.importFromGitHub(
      'https://github.com/acme/demo/blob/v1/skills/pdf-tools/SKILL.md',
    );
    expect(skill.record.id, 'pdf-tools');
    expect(File(p.join(skill.dir, 'x.py')).existsSync(), isTrue);
    expect(File(p.join(skill.dir, 'README.md')).existsSync(), isFalse);
  });

  for (final knownLength in [true, false]) {
    test(
      'GitHub streams a >20 MB zip with progress (length=$knownLength)',
      () async {
        final payload = Uint8List(21 * 1024 * 1024)..[0] = 42;
        final archive = Archive()
          ..addFile(ArchiveFile.string('demo-main/SKILL.md', _skillMd))
          ..addFile(
            ArchiveFile.noCompress(
              'demo-main/large.bin',
              payload.length,
              payload,
            ),
          );
        final zip = ZipEncoder().encodeBytes(archive);
        expect(zip.length, greaterThan(20 * 1024 * 1024));
        Stream<List<int>> chunks() async* {
          for (var start = 0; start < zip.length; start += 1024 * 1024) {
            yield Uint8List.sublistView(
              zip,
              start,
              (start + 1024 * 1024).clamp(0, zip.length),
            );
            if (start == 0) {
              await Future<void>.delayed(const Duration(milliseconds: 120));
            }
          }
        }

        final client = MockClient.streaming(
          (request, _) async => http.StreamedResponse(
            chunks(),
            200,
            contentLength: knownLength ? zip.length : null,
          ),
        );
        final github = SkillsService(
          store: store,
          skillsDirectory: skillsDir,
          httpClient: client,
        );
        addTearDown(github.dispose);
        final progress = <SkillImportProgress>[];
        final skill = await github.importFromGitHub(
          'https://github.com/acme/demo/tree/main',
          onProgress: progress.add,
        );
        final downloaded = progress
            .where((p) => p.phase == SkillImportPhase.downloading)
            .toList();
        expect(
          downloaded.any(
            (p) => p.receivedBytes > 0 && p.receivedBytes < zip.length,
          ),
          isTrue,
        );
        expect(downloaded.last.receivedBytes, zip.length);
        expect(downloaded.last.totalBytes, knownLength ? zip.length : null);
        expect(downloaded.last.fraction, knownLength ? 1 : null);
        expect(
          progress.map((p) => p.phase).toSet(),
          SkillImportPhase.values.toSet(),
        );
        expect(
          await File(p.join(skill.dir, 'large.bin')).length(),
          payload.length,
        );
        expect(
          await skillsDir
              .list()
              .where((e) => p.basename(e.path).startsWith('.import-'))
              .isEmpty,
          isTrue,
        );
      },
    );
  }

  test(
    'GitHub rejects oversized content length without reading the body',
    () async {
      var bodyCancelled = false;
      final body = StreamController<List<int>>(
        onCancel: () => bodyCancelled = true,
      );
      final client = MockClient.streaming(
        (_, _) async => http.StreamedResponse(
          body.stream,
          200,
          contentLength: kSkillImportMaxBytes + 1,
        ),
      );
      final github = SkillsService(
        store: store,
        skillsDirectory: skillsDir,
        httpClient: client,
      );
      addTearDown(github.dispose);
      await expectLater(
        github.importFromGitHub('https://github.com/acme/demo/tree/main'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'zip exceeds 200 MB',
          ),
        ),
      );
      expect(bodyCancelled, isTrue);
      await body.close();
      expect(await userSkillEntries(), isEmpty);
    },
  );

  test(
    'GitHub enforces the limit while streaming without content length',
    () async {
      var stopped = false;
      Stream<List<int>> chunks() async* {
        try {
          final chunk = Uint8List(1024 * 1024);
          for (var i = 0; i < 202; i++) {
            yield chunk;
          }
          fail('should stop reading once the download limit is reached');
        } finally {
          stopped = true;
        }
      }

      final client = MockClient.streaming(
        (_, _) async => http.StreamedResponse(chunks(), 200),
      );
      final github = SkillsService(
        store: store,
        skillsDirectory: skillsDir,
        httpClient: client,
      );
      addTearDown(github.dispose);
      await expectLater(
        github.importFromGitHub('https://github.com/acme/demo/tree/main'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'zip exceeds 200 MB',
          ),
        ),
      );
      expect(stopped, isTrue);
      expect(await userSkillEntries(), isEmpty);
    },
  );

  test(
    'GitHub cancellation aborts downloading and removes partial files',
    () async {
      final cancel = Completer<void>();
      final started = Completer<void>();
      final body = StreamController<List<int>>();
      final client = MockClient.streaming((request, _) async {
        final abortable = request as http.AbortableRequest;
        unawaited(
          abortable.abortTrigger!.then((_) {
            body.addError(http.RequestAbortedException());
            unawaited(body.close());
          }),
        );
        started.complete();
        return http.StreamedResponse(body.stream, 200);
      });
      final github = SkillsService(
        store: store,
        skillsDirectory: skillsDir,
        httpClient: client,
      );
      addTearDown(github.dispose);
      final result = github.importFromGitHub(
        'https://github.com/acme/demo/tree/main',
        cancelSignal: cancel.future,
      );
      final assertion = expectLater(
        result,
        throwsA(isA<http.RequestAbortedException>()),
      );
      await started.future;
      body.add([1, 2, 3]);
      cancel.complete();
      await assertion;
      expect(github.skills, isEmpty);
      expect(await userSkillEntries(), isEmpty);
    },
  );

  test('cancel during extraction never installs the completed skill', () async {
    final cancel = Completer<void>();
    final zip = encodeSkillZip({'demo-main/SKILL.md': utf8.encode(_skillMd)});
    final github = SkillsService(
      store: store,
      skillsDirectory: skillsDir,
      httpClient: MockClient((_) async => http.Response.bytes(zip, 200)),
    );
    addTearDown(github.dispose);
    await expectLater(
      github.importFromGitHub(
        'https://github.com/acme/demo/tree/main',
        cancelSignal: cancel.future,
        onProgress: (value) {
          if (value.phase == SkillImportPhase.extracting) cancel.complete();
        },
      ),
      throwsA(isA<http.RequestAbortedException>()),
    );
    expect(github.skills, isEmpty);
    expect(await userSkillEntries(), isEmpty);
  });

  test('download failure cleans up and allows retry', () async {
    var calls = 0;
    final zip = encodeSkillZip({'demo-main/SKILL.md': utf8.encode(_skillMd)});
    final github = SkillsService(
      store: store,
      skillsDirectory: skillsDir,
      httpClient: MockClient.streaming(
        (_, _) async => http.StreamedResponse(
          calls++ == 0
              ? Stream<List<int>>.error(
                  const SocketException('connection reset'),
                )
              : Stream.value(zip),
          200,
        ),
      ),
    );
    addTearDown(github.dispose);
    await expectLater(
      github.importFromGitHub('https://github.com/acme/demo/tree/main'),
      throwsA(isA<SocketException>()),
    );
    expect(await userSkillEntries(), isEmpty);
    final skill = await github.importFromGitHub(
      'https://github.com/acme/demo/tree/main',
    );
    expect(skill.record.id, 'pdf-tools');
  });

  test('legacy remote Skill can reconnect a missing update source safely', () async {
    final skill = await service.importFromText('''
---
name: yt-audit
description: Audit a YouTube channel
---
Audit instructions
''');
    final legacyRecord = skill.record.copyWith(source: SkillSource.github);
    await store.upsert(
      ExtensionEntityStore.kindSkill,
      skill.record.id,
      legacyRecord.toJson(),
    );
    await service.rescan();

    expect(
      service.canUpdateSkill(skill.record.id),
      isFalse,
      reason: 'a broad legacy source enum is not enough to perform an update',
    );

    await service.setUpdateSource(
      skill.record.id,
      'https://github.com/acme/youtube-toolkit/tree/main/skills/yt-audit',
    );

    expect(service.canUpdateSkill(skill.record.id), isTrue);
    expect(
      service.skills.single.record.source,
      SkillSource.github,
    );
    final extension = await store.get(
      ExtensionEntityStore.kindExtensionRegistry,
      'skill::${skill.record.id}',
    );
    expect(extension, isNotNull);
    final source = extension!.payload['source'] as Map<String, Object?>;
    expect(source['uri'], contains('github.com/acme/youtube-toolkit'));
    expect(source['subpath'], 'skills/yt-audit');

    // Replacing an old folder-level source with a repository root must clear
    // the old subpath instead of silently reusing stale origin metadata.
    await service.setUpdateSource(
      skill.record.id,
      'https://github.com/acme/new-youtube-toolkit',
    );
    final replaced = await store.get(
      ExtensionEntityStore.kindExtensionRegistry,
      'skill::${skill.record.id}',
    );
    final replacedSource = replaced!.payload['source'] as Map<String, Object?>;
    expect(replacedSource['uri'], contains('new-youtube-toolkit'));
    expect(replacedSource['subpath'], isNull);
  });

  test('GitHub Skills from one repository become one ordered pack and update in one download', () async {
    final auditMarkdown = utf8.encode('''
---
name: yt-audit
description: Audit YouTube channels
---
Audit instructions v1
''');
    final seoMarkdown = utf8.encode('''
---
name: yt-seo
description: Improve YouTube search
---
SEO instructions v1
''');
    final firstZip = encodeSkillZip({
      'toolkit-main/yt-audit/SKILL.md': auditMarkdown,
      'toolkit-main/yt-seo/SKILL.md': seoMarkdown,
      'toolkit-main/README.md': utf8.encode('# shared toolkit docs'),
      'toolkit-main/config/common.json': utf8.encode('{"mode":"shared"}'),
    });
    var downloads = 0;
    final github = SkillsService(
      store: store,
      skillsDirectory: skillsDir,
      httpClient: MockClient((request) async {
        if (request.url.host == 'api.github.com') {
          return http.Response(
            '{"sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}',
            200,
          );
        }
        if (request.url.host == 'codeload.github.com') {
          downloads++;
          return http.Response.bytes(firstZip, 200);
        }
        return http.Response('not found', 404);
      }),
    );
    addTearDown(github.dispose);

    final installed = await github.importFromGitHubRepository(
      'https://github.com/acme/toolkit/tree/main',
      chooseSkills: (candidates) async => {
        for (final candidate in candidates) candidate.path,
      },
    );
    expect(installed, hasLength(2));
    final importReport = await github.getImportReport('yt-audit');
    expect(importReport, isNotNull);
    final fileEntries = (importReport!['files'] as List).cast<Map>();
    expect(fileEntries.map((entry) => entry['path']), contains('shared/README.md'));
    expect(fileEntries.map((entry) => entry['path']), contains('shared/config/common.json'));
    final sharedResources = importReport['sharedResources'] as Map;
    expect(sharedResources['binding'], 'read_only_reference');
    expect(sharedResources['runtimeAccessEnabled'], isFalse);
    expect(github.skillPacks, hasLength(1));
    final pack = github.skillPacks.single;
    expect(pack.name, 'Toolkit');
    expect(pack.shortcut, 'toolkit');
    expect(pack.skillIds, ['yt-audit', 'yt-seo']);
    expect(
      github.resolveForAssistant(null).map((skill) => skill.record.id),
      unorderedEquals(['yt-audit', 'yt-seo']),
      reason: 'repository packs do not hide or disable standalone Skills',
    );
    expect(
      github.skills.map((skill) => skill.record.enabled),
      everyElement(isTrue),
      reason: 'auto-detected packs must not overwrite standalone enabled flags',
    );

    final updated = await github.updateSkillPack(pack.id);
    expect(updated, hasLength(2));
    expect(downloads, 2, reason: 'one import archive plus one pack update archive');
    expect(github.skillPacks.single.skillIds, ['yt-audit', 'yt-seo']);
    expect(File(updated.first.skillMdPath).readAsStringSync(), contains('instructions v1'));
  });

  test('GitHub update and rollback restore the prior Skill import manifest', () async {
    final original = await service.importFromText(_skillMd);
    final before = await service.getImportReport(original.record.id);
    expect(before, isNotNull);

    final updatedZip = encodeSkillZip({
      'demo-main/SKILL.md': utf8.encode(_skillMd.replaceFirst('# PDF Tools', '# Updated PDF Tools')),
      'demo-main/new-helper.py': utf8.encode('print("not executed")'),
    });
    final githubClient = MockClient((request) async {
      if (request.url.host == 'api.github.com') {
        return http.Response(
          '{"sha":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}',
          200,
        );
      }
      if (request.url.host == 'codeload.github.com') {
        return http.Response.bytes(updatedZip, 200);
      }
      return http.Response('not found', 404);
    });
    final updater = SkillsService(
      store: store,
      skillsDirectory: skillsDir,
      httpClient: githubClient,
    );
    addTearDown(updater.dispose);
    await updater.loaded;
    await updater.rescan();

    final changed = await updater.updateFromGitHub(
      original.record.id,
      'https://github.com/acme/demo/tree/main',
    );
    expect(File(p.join(changed.dir, 'new-helper.py')).existsSync(), isTrue);
    final afterUpdate = await updater.getImportReport(original.record.id);
    expect(afterUpdate, isNotNull);
    expect(afterUpdate!['sourceDigest'], isNot(before!['sourceDigest']));

    final restored = await updater.rollback(original.record.id);
    expect(File(restored.skillMdPath).readAsStringSync(), _skillMd);
    expect(File(p.join(restored.dir, 'new-helper.py')).existsSync(), isFalse);
    final afterRollback = await updater.getImportReport(original.record.id);
    expect(afterRollback, isNotNull);
    expect(afterRollback!['sourceDigest'], before['sourceDigest']);
  });

  test('exportZip, delete, toggle, useCount, updateBody', () async {
    final skill = await service.importFromText(_skillMd);
    final exported = await service.exportZip(
      skill.record.id,
      Directory(tmp.path),
    );
    expect(exported.existsSync(), isTrue);
    expect(p.basename(exported.path), 'pdf-tools.zip');

    await service.setEnabled(skill.record.id, false);
    expect(
      service.skills
          .singleWhere((s) => s.record.id == skill.record.id)
          .record
          .enabled,
      isFalse,
    );

    await service.setEnabled(skill.record.id, true);
    await service.incrementUseCount(skill.record.id);
    expect(
      service.skills
          .singleWhere((s) => s.record.id == skill.record.id)
          .record
          .useCount,
      1,
    );

    await service.updateBody(skill.record.id, '''
---
name: pdf-tools
description: Updated description
---
new body
''');
    final updated = service.skills.singleWhere(
      (s) => s.record.id == skill.record.id,
    );
    expect(updated.description, 'Updated description');
    expect(File(updated.skillMdPath).readAsStringSync(), contains('new body'));

    await service.delete(skill.record.id);
    expect(service.skills, isEmpty);
    expect(Directory(skill.dir).existsSync(), isFalse);
    expect(
      await store.get(ExtensionEntityStore.kindSkill, skill.record.id),
      isNull,
    );
  });

  test(
    'resolveForAssistant respects assistant and conversation overrides',
    () async {
      await service.importFromText(_skillMd);
      await service.importFromText('''
---
name: other
description: Another skill
---
x
''');
      await service.importFromText('''
---
name: disabled
description: Off
---
x
''');
      await service.setEnabled('disabled', false);

      final all = service.resolveForAssistant(null);
      expect(
        all.map((s) => s.record.id),
        unorderedEquals(['pdf-tools', 'other']),
      );

      const assistant = Assistant(id: 'a1', name: 'A', skillIds: ['other']);
      expect(service.resolveForAssistant(assistant).map((s) => s.record.id), [
        'other',
      ]);
      expect(
        service
            .resolveForAssistant(assistant, conversationOverride: ['pdf-tools'])
            .map((s) => s.record.id),
        ['pdf-tools'],
      );
      expect(
        service.resolveForAssistant(assistant, conversationOverride: []),
        isEmpty,
      );
    },
  );

  test('skill packs keep member order and validate slash shortcuts', () async {
    final pack = SkillPack(
      id: 'pack-youtube',
      name: 'YouTube Toolkit',
      shortcut: 'youtube',
      skillIds: const ['yt-audit', 'yt-seo'],
      enabled: false,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
    );
    final restored = SkillPack.fromJson(pack.toJson());
    expect(restored.shortcut, 'youtube');
    expect(restored.skillIds, ['yt-audit', 'yt-seo']);
    expect(restored.enabled, isFalse);
    expect(
      () => pack.copyWith(shortcut: 'Bad Shortcut').validate(),
      throwsFormatException,
    );
  });

  test('pack activation and standalone Skill activation are independent', () async {
    final first = await service.importFromText('''
---
name: yt-audit
description: Audit a channel
---
Audit instructions
''');
    final second = await service.importFromText('''
---
name: yt-seo
description: Improve search visibility
---
SEO instructions
''');
    await service.setEnabled(second.record.id, false);
    final pack = await service.saveSkillPack(
      name: 'YouTube Toolkit',
      shortcut: 'youtube',
      skillIds: [first.record.id, second.record.id],
    );

    expect(service.skillPacks.single.id, pack.id);
    expect(service.skills.map((skill) => skill.record.enabled), [true, false]);
    expect(
      service.resolveForAssistant(null).map((skill) => skill.record.id),
      [first.record.id],
      reason: 'saving a disabled pack must not rewrite standalone states',
    );

    await service.rescan();
    expect(service.skills.map((skill) => skill.record.enabled), [true, false]);
    expect(service.resolveForAssistant(null).map((skill) => skill.record.id), [first.record.id]);

    await service.setEnabled(second.record.id, true);
    expect(service.skillPacks.single.enabled, isFalse);
    expect(service.skills.map((skill) => skill.record.enabled), [true, true]);
    expect(
      service.resolveForAssistant(null).map((skill) => skill.record.id),
      unorderedEquals([first.record.id, second.record.id]),
    );

    await service.setEnabled(first.record.id, false);
    expect(service.skillPacks.single.enabled, isFalse);
    expect(
      service.resolveForAssistant(null).map((skill) => skill.record.id),
      [second.record.id],
    );
    final selected = service.resolveForAssistant(
      null,
      conversationOverride: [first.record.id],
    );
    expect(
      selected.map((skill) => skill.record.id),
      [first.record.id],
      reason: 'selecting one original Skill must not expand to its pack',
    );

    await service.setSkillPackEnabled(pack.id, true);
    expect(
      service.resolveForAssistant(null).map((skill) => skill.record.id),
      unorderedEquals([first.record.id, second.record.id]),
      reason: 'an enabled pack activates every member as a group',
    );
    expect(service.skills.map((skill) => skill.record.enabled), [false, true]);

    await service.setSkillPackEnabled(pack.id, false);
    expect(
      service.resolveForAssistant(null).map((skill) => skill.record.id),
      [second.record.id],
      reason: 'disabling the pack restores the independent member states',
    );
  });

  test('deleting a pack leaves member standalone states untouched', () async {
    final first = await service.importFromText('''
---
name: delete-pack-first
description: First member
---
First
''');
    final second = await service.importFromText('''
---
name: delete-pack-second
description: Second member
---
Second
''');
    await service.setEnabled(second.record.id, false);
    final pack = await service.saveSkillPack(
      name: 'Disabled Toolkit',
      shortcut: 'disabled_toolkit',
      skillIds: [first.record.id, second.record.id],
    );

    expect(service.skills.map((skill) => skill.record.enabled), [true, false]);
    await service.deleteSkillPack(pack.id);

    expect(service.skillPacks, isEmpty);
    expect(service.skills.map((skill) => skill.record.enabled), [true, false]);
    expect(
      service.resolveForAssistant(null).map((skill) => skill.record.id),
      [first.record.id],
      reason: 'deleting a pack must not change either original Skill',
    );
  });

  test('deleting an enabled pack does not enable disabled standalone members', () async {
    final first = await service.importFromText('''
---
name: enabled-pack-first
description: First member
---
First
''');
    final second = await service.importFromText('''
---
name: enabled-pack-second
description: Second member
---
Second
''');
    await service.setEnabled(second.record.id, false);
    final pack = await service.saveSkillPack(
      name: 'Enabled Toolkit',
      shortcut: 'enabled_toolkit',
      skillIds: [first.record.id, second.record.id],
    );
    await service.setSkillPackEnabled(pack.id, true);
    expect(service.skills.map((skill) => skill.record.enabled), [true, false]);
    await service.deleteSkillPack(pack.id);

    expect(service.skills.map((skill) => skill.record.enabled), [true, false]);
    expect(
      service.resolveForAssistant(null).map((skill) => skill.record.id),
      [first.record.id],
    );
  });

  test('a Skill can belong to multiple packs without moving or disappearing', () async {
    final first = await service.importFromText('''
---
name: move-first
description: First member
---
First
''');
    final second = await service.importFromText('''
---
name: move-second
description: Second member
---
Second
''');
    final third = await service.importFromText('''
---
name: move-third
description: Third member
---
Third
''');

    final original = await service.saveSkillPack(
      name: 'Original',
      shortcut: 'original',
      skillIds: [first.record.id, second.record.id],
    );
    final overlapping = await service.saveSkillPack(
      name: 'Overlapping',
      shortcut: 'overlapping',
      skillIds: [second.record.id, third.record.id],
    );

    expect(service.skillPacks, hasLength(2));
    expect(
      service.skillPacks.singleWhere((pack) => pack.id == original.id).skillIds,
      [first.record.id, second.record.id],
    );
    expect(
      service.skillPacks.singleWhere((pack) => pack.id == overlapping.id).skillIds,
      [second.record.id, third.record.id],
    );
    expect(
      service.skills.map((skill) => skill.record.id),
      unorderedEquals([first.record.id, second.record.id, third.record.id]),
    );
    expect(service.skills.map((skill) => skill.record.enabled), everyElement(isTrue));

    await service.setEnabled(second.record.id, false);
    expect(
      service.skills.singleWhere((skill) => skill.record.id == second.record.id).record.enabled,
      isFalse,
    );
    expect(service.skillPacks, hasLength(2));

    await service.rescan();
    expect(service.skillPacks, hasLength(2));
    expect(
      service.skillPacks.singleWhere((pack) => pack.id == original.id).skillIds,
      [first.record.id, second.record.id],
    );
    expect(
      service.skillPacks.singleWhere((pack) => pack.id == overlapping.id).skillIds,
      [second.record.id, third.record.id],
    );
    expect(
      service.skills.singleWhere((skill) => skill.record.id == second.record.id).record.enabled,
      isFalse,
    );
  });

  test('manual Skill Pack order and member order survive a rescan', () async {
    final first = await service.importFromText('''
---
name: first
description: First
---
First
''');
    final second = await service.importFromText('''
---
name: second
description: Second
---
Second
''');
    final third = await service.importFromText('''
---
name: third
description: Third
---
Third
''');
    final alpha = await service.saveSkillPack(
      name: 'Alpha',
      shortcut: 'alpha',
      skillIds: [first.record.id, second.record.id],
    );
    final beta = await service.saveSkillPack(
      name: 'Beta',
      shortcut: 'beta',
      skillIds: [third.record.id],
    );

    await service.saveSkillPack(
      id: alpha.id,
      name: 'Alpha',
      shortcut: 'alpha',
      skillIds: [second.record.id, first.record.id],
    );
    await service.reorderSkillPacks(0, 2);
    expect(service.skillPacks.map((pack) => pack.id), [beta.id, alpha.id]);

    await service.rescan();
    expect(service.skillPacks.map((pack) => pack.id), [beta.id, alpha.id]);
    expect(service.skillPacks.last.skillIds, [second.record.id, first.record.id]);
  });

  test('incrementUseCount never throws for a missing id', () async {
    await service.incrementUseCount('nope');
  });
}
