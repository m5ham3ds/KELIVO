import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/services/skills/skill_archive.dart';

void main() {
  late Directory tmp;
  late File zip;
  late String output;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('skill_archive_test_');
    zip = File(p.join(tmp.path, 'input.zip'));
    output = p.join(tmp.path, 'output');
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('rejects a >200 MB local zip before decoding', () {
    final handle = zip.openSync(mode: FileMode.write);
    handle.truncateSync(kSkillImportMaxBytes + 1);
    handle.closeSync();
    expect(
      () => extractSkillArchive(zip.path, output),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          'zip exceeds 200 MB',
        ),
      ),
    );
  });

  test('rejects expanded size before writing files', () {
    final bytes = encodeSkillZip({'SKILL.md': utf8.encode('skill')});
    _setDeclaredSize(bytes, 'SKILL.md', kSkillImportMaxExtractedBytes + 1);
    zip.writeAsBytesSync(bytes);
    expect(
      () => extractSkillArchive(zip.path, output),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          'extracted skill exceeds 500 MB',
        ),
      ),
    );
    expect(Directory(output).existsSync(), isFalse);
  });

  test('unrelated repository files are not decompressed or counted', () {
    final bytes = encodeSkillZip({
      'repo-main/skills/demo/SKILL.md': utf8.encode('skill'),
      'repo-main/skills/demo/helper.py': utf8.encode('print(1)'),
      'repo-main/other/large.bin': [1],
    });
    _setDeclaredSize(
      bytes,
      'repo-main/other/large.bin',
      kSkillImportMaxExtractedBytes + 1,
    );
    zip.writeAsBytesSync(bytes);
    extractSkillArchive(
      zip.path,
      output,
      subdir: 'skills/demo',
      stripSingleRoot: true,
    );
    expect(File(p.join(output, 'SKILL.md')).readAsStringSync(), 'skill');
    expect(File(p.join(output, 'helper.py')).readAsStringSync(), 'print(1)');
    expect(Directory(p.join(output, 'other')).existsSync(), isFalse);
  });

  test(
    'does not arbitrarily select one Skill from a multi-Skill repository',
    () {
      final bytes = encodeSkillZip({
        'repo-main/skills/video/SKILL.md': utf8.encode('video'),
        'repo-main/skills/audio/SKILL.md': utf8.encode('audio'),
      });
      zip.writeAsBytesSync(bytes);

      expect(
        () => extractSkillArchive(zip.path, output, stripSingleRoot: true),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('multiple_skills_found'),
          ),
        ),
      );
    },
  );

  test('extracts every Skill from a repository subfolder and preserves resources', () {
    final bytes = encodeSkillZip({
      'repo-main/skills/pdf-tools/SKILL.md': utf8.encode('''
---
name: pdf-tools
description: Read PDF documents.
---
'''),
      'repo-main/skills/pdf-tools/references/formats.md': utf8.encode('# Formats'),
      'repo-main/skills/pdf-tools/scripts/read.py': utf8.encode('print(1)'),
      'repo-main/skills/csv-tools/SKILL.md': utf8.encode('''
---
name: csv-tools
description: Work with CSV files.
---
'''),
      'repo-main/skills/csv-tools/assets/sample.csv': utf8.encode('a,b\n1,2'),
      'repo-main/docs/README.md': utf8.encode('not part of a Skill'),
    });
    zip.writeAsBytesSync(bytes);

    final found = extractSkillArchiveMultiple(
      zip.path,
      output,
      subdir: 'skills',
      stripSingleRoot: true,
    );
    expect(found.keys, unorderedEquals(['skills/pdf-tools', 'skills/csv-tools']));
    final pdf = Directory(p.join(output, found['skills/pdf-tools']!));
    final csv = Directory(p.join(output, found['skills/csv-tools']!));
    expect(File(p.join(pdf.path, 'SKILL.md')).existsSync(), isTrue);
    expect(File(p.join(pdf.path, 'references/formats.md')).readAsStringSync(), '# Formats');
    expect(File(p.join(pdf.path, 'scripts/read.py')).existsSync(), isTrue);
    expect(File(p.join(csv.path, 'assets/sample.csv')).existsSync(), isTrue);
    expect(Directory(p.join(output, 'docs')).existsSync(), isFalse);
  });


  test('nested Skill roots receive their own files when a root Skill exists', () {
    final bytes = encodeSkillZip({
      'repo/SKILL.md': utf8.encode('root skill'),
      'repo/root-guide.md': utf8.encode('root guide'),
      'repo/nested/SKILL.md': utf8.encode('nested skill'),
      'repo/nested/nested-guide.md': utf8.encode('nested guide'),
    });
    zip.writeAsBytesSync(bytes);
    final found = extractSkillArchiveMultiple(
      zip.path,
      output,
      stripSingleRoot: true,
    );
    expect(found.keys, unorderedEquals(['.', 'nested']));
    final root = Directory(p.join(output, found['.']!));
    final nested = Directory(p.join(output, found['nested']!));
    expect(File(p.join(root.path, 'SKILL.md')).readAsStringSync(), 'root skill');
    expect(File(p.join(root.path, 'root-guide.md')).readAsStringSync(), 'root guide');
    expect(File(p.join(root.path, 'nested/SKILL.md')).existsSync(), isFalse);
    expect(File(p.join(nested.path, 'SKILL.md')).readAsStringSync(), 'nested skill');
    expect(File(p.join(nested.path, 'nested-guide.md')).readAsStringSync(), 'nested guide');
  });

  test('rejects aggregate expansion above 500 MB across multiple Skills', () {
    final bytes = encodeSkillZip({
      'repo/alpha/SKILL.md': utf8.encode('skill'),
      'repo/beta/SKILL.md': utf8.encode('skill'),
    });
    _setDeclaredSize(bytes, 'repo/alpha/SKILL.md', 300 * 1024 * 1024);
    _setDeclaredSize(bytes, 'repo/beta/SKILL.md', 300 * 1024 * 1024);
    zip.writeAsBytesSync(bytes);
    expect(
      () => extractSkillArchiveMultiple(
        zip.path,
        output,
        stripSingleRoot: true,
      ),
      throwsFormatException,
    );
  });


  test('rejects parent traversal components even when normalization stays inside root', () {
    final archive = Archive()
      ..addFile(ArchiveFile.string('repo/../SKILL.md', 'skill'));
    zip.writeAsBytesSync(ZipEncoder().encodeBytes(archive));
    expect(() => extractSkillArchive(zip.path, output), throwsFormatException);
  });

  test('returns the original Skill folder name before narrowing the archive', () {
    final bytes = encodeSkillZip({
      'archive-root/target-skill/SKILL.md': utf8.encode('skill'),
    });
    zip.writeAsBytesSync(bytes);
    final directoryName = extractSkillArchive(
      zip.path,
      output,
      stripSingleRoot: true,
    );
    expect(directoryName, 'target-skill');
    expect(File(p.join(output, 'SKILL.md')).existsSync(), isTrue);
  });

  test('zip-slip is still rejected and symlinks are not installed', () {
    final archive = Archive()
      ..addFile(ArchiveFile.string('../escape/SKILL.md', 'skill'));
    zip.writeAsBytesSync(ZipEncoder().encodeBytes(archive));
    expect(() => extractSkillArchive(zip.path, output), throwsFormatException);
    final link = ArchiveFile.string('outside', '../outside')
      ..mode = 0xa1ff
      ..symbolicLink = '../outside';
    final linkedZip = ZipEncoder().encodeBytes(
      Archive()
        ..addFile(ArchiveFile.string('SKILL.md', 'skill'))
        ..addFile(link),
    );
    // ZipEncoder writes DOS headers; mark this fixture as a Unix archive.
    final data = ByteData.sublistView(linkedZip);
    for (var i = 0; i + 46 <= linkedZip.length; i++) {
      if (data.getUint32(i, Endian.little) == 0x02014b50) {
        data.setUint8(i + 5, 3);
      }
    }
    zip.writeAsBytesSync(linkedZip);
    extractSkillArchive(zip.path, output);
    expect(File(p.join(output, 'SKILL.md')).existsSync(), isTrue);
    expect(
      FileSystemEntity.typeSync(p.join(output, 'outside'), followLinks: false),
      FileSystemEntityType.notFound,
    );
  });
  test('repository extractor preserves shared files, hidden files and binary assets', () {
    final binary = <int>[0, 1, 2, 255, 128];
    final bytes = encodeSkillZip({
      'repo-main/README.md': utf8.encode('# repository guide'),
      'repo-main/config/shared.json': utf8.encode('{"enabled":true}'),
      'repo-main/skills/alpha/SKILL.md': utf8.encode('''
---
name: alpha
description: Alpha skill
---
'''),
      'repo-main/skills/alpha/.env.example': utf8.encode('TOKEN=placeholder'),
      'repo-main/skills/alpha/assets/blob.bin': binary,
      'repo-main/skills/beta/SKILL.md': utf8.encode('''
---
name: beta
description: Beta skill
---
'''),
      'repo-main/scripts/repo-check.sh': utf8.encode('#!/bin/sh\necho not-run'),
    });
    zip.writeAsBytesSync(bytes);

    final result = extractSkillRepositoryArchive(
      zip.path,
      output,
      stripSingleRoot: true,
    );
    final skills = Map<String, String>.from(result['skills'] as Map);
    expect(skills.keys, unorderedEquals(['skills/alpha', 'skills/beta']));
    final alpha = Directory(p.join(output, skills['skills/alpha']!));
    expect(File(p.join(alpha.path, '.env.example')).readAsStringSync(), 'TOKEN=placeholder');
    expect(File(p.join(alpha.path, 'assets/blob.bin')).readAsBytesSync(), binary);
    final sharedName = result['sharedDirectory'] as String;
    final shared = Directory(p.join(output, sharedName));
    expect(File(p.join(shared.path, 'README.md')).readAsStringSync(), '# repository guide');
    expect(File(p.join(shared.path, 'config/shared.json')).existsSync(), isTrue);
    expect(File(p.join(shared.path, 'scripts/repo-check.sh')).existsSync(), isTrue);
    expect(result['sharedPaths'], containsAll(['README.md', 'config/shared.json', 'scripts/repo-check.sh']));
  });

  test('repository extractor enforces the per-file expanded-size limit', () {
    final bytes = encodeSkillZip({
      'repo/skills/demo/SKILL.md': utf8.encode('skill'),
      'repo/skills/demo/assets/oversized.bin': [1],
    });
    _setDeclaredSize(
      bytes,
      'repo/skills/demo/assets/oversized.bin',
      200 * 1024 * 1024 + 1,
    );
    zip.writeAsBytesSync(bytes);
    expect(
      () => extractSkillRepositoryArchive(zip.path, output, stripSingleRoot: true),
      throwsA(isA<FormatException>().having(
        (error) => error.message,
        'message',
        startsWith('skill_repository_single_file_too_large:'),
      )),
    );
  });

  test('repository extractor enforces aggregate expanded-size limit', () {
    final bytes = encodeSkillZip({
      'repo/skills/demo/SKILL.md': utf8.encode('skill'),
      'repo/skills/demo/assets/a.bin': [1],
      'repo/skills/demo/assets/b.bin': [2],
      'repo/skills/demo/assets/c.bin': [3],
    });
    for (final name in ['a.bin', 'b.bin', 'c.bin']) {
      _setDeclaredSize(
        bytes,
        'repo/skills/demo/assets/$name',
        180 * 1024 * 1024,
      );
    }
    zip.writeAsBytesSync(bytes);
    expect(
      () => extractSkillRepositoryArchive(zip.path, output, stripSingleRoot: true),
      throwsA(isA<FormatException>().having(
        (error) => error.message,
        'message',
        'skill_repository_expanded_size_limit',
      )),
    );
  });

  test('repository extractor rejects absolute and traversal archive paths', () {
    for (final unsafe in ['../outside.txt', '/etc/passwd', 'C:\\Windows\\win.ini']) {
      final archive = Archive()..addFile(ArchiveFile.string(unsafe, 'bad'));
      zip.writeAsBytesSync(ZipEncoder().encodeBytes(archive));
      expect(() => extractSkillRepositoryArchive(zip.path, output), throwsFormatException);
    }
  });

  test('repository extractor rejects archive entry-count overflow before extraction', () {
    final archive = Archive()
      ..addFile(ArchiveFile.string('repo/SKILL.md', 'skill'));
    for (var index = 0; index < 8192; index++) {
      archive.addFile(ArchiveFile.string('repo/data/file-$index.txt', ''));
    }
    zip.writeAsBytesSync(ZipEncoder().encodeBytes(archive));
    expect(
      () => extractSkillRepositoryArchive(zip.path, output, stripSingleRoot: true),
      throwsA(isA<FormatException>().having((error) => error.message, 'message', 'skill_repository_entry_limit')),
    );
    expect(Directory(output).existsSync(), isFalse);
  });

  test('repository extractor reports archive symlinks as skipped instead of writing them', () {
    final link = ArchiveFile.string('repo/shared-link', '../outside')
      ..mode = 0xa1ff
      ..symbolicLink = '../outside';
    final bytes = ZipEncoder().encodeBytes(
      Archive()
        ..addFile(ArchiveFile.string('repo/SKILL.md', 'skill'))
        ..addFile(link),
    );
    final data = ByteData.sublistView(bytes);
    for (var index = 0; index + 46 <= bytes.length; index++) {
      if (data.getUint32(index, Endian.little) == 0x02014b50) {
        data.setUint8(index + 5, 3);
      }
    }
    zip.writeAsBytesSync(bytes);
    final result = extractSkillRepositoryArchive(zip.path, output, stripSingleRoot: true);
    expect(result['skipped'], contains(predicate((item) =>
      item is Map && item['reason'] == 'symbolic_link_not_supported')));
    expect(FileSystemEntity.typeSync(p.join(output, 'shared', 'shared-link'), followLinks: false),
      FileSystemEntityType.notFound);
  });

}

// Change the central-directory size without allocating a huge test payload.
void _setDeclaredSize(List<int> bytes, String name, int size) {
  final data = ByteData.sublistView(bytes as Uint8List);
  for (var i = 0; i + 46 <= bytes.length; i++) {
    if (data.getUint32(i, Endian.little) != 0x02014b50) continue;
    final length = data.getUint16(i + 28, Endian.little);
    if (utf8.decode(bytes.sublist(i + 46, i + 46 + length)) == name) {
      data.setUint32(i + 24, size, Endian.little);
      return;
    }
  }
  fail('missing zip entry: $name');

}
