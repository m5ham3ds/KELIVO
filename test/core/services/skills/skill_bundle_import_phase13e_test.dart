import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/skill_record.dart';
import 'package:Kelivo/core/services/skills/skill_archive.dart';
import 'package:Kelivo/core/services/skills/skills_service.dart';

List<int> _skillZip(
  String name,
  Map<String, String> files, {
  Map<String, List<int>> binaryFiles = const <String, List<int>>{},
  String instructions = '',
}) {
  final archive = Archive();
  archive.addFile(
    ArchiveFile.string(
      '$name/SKILL.md',
      '''
---
name: $name
description: Test skill $name for nested bundle import.
---
# $name
$instructions
''',
    ),
  );
  for (final entry in files.entries) {
    archive.addFile(ArchiveFile.string('$name/${entry.key}', entry.value));
  }
  for (final entry in binaryFiles.entries) {
    archive.addFile(ArchiveFile.bytes('$name/${entry.key}', entry.value));
  }
  return ZipEncoder().encodeBytes(archive);
}

void main() {
  late Directory temp;
  late File packageZip;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('kelivo_skill_bundle_13e_');
    packageZip = File(p.join(temp.path, 'Viral-Motion-Reel-Playbook_Skills.zip'));
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('expands nested Skill ZIPs while retaining their complete resources and package docs', () async {
    final outer = Archive()
      ..addFile(ArchiveFile.bytes(
        'Skills/alpha.zip',
        _skillZip('alpha', {
          'references/guide.md': '# Alpha reference',
          'scripts/build.py': 'print("alpha")',
          'assets/config.json': '{"quality":"high"}',
        }),
      ))
      ..addFile(ArchiveFile.bytes(
        'Skills/beta.zip',
        _skillZip(
          'beta',
          {
            'examples/sample.js': 'console.log("beta")',
            'assets/scene.json': '{"scene":1}',
          },
          binaryFiles: {
            'examples/character_sheet.png': [0x89, 0x50, 0x4e, 0x47, 0x00, 0xff],
          },
        ),
      ))
      ..addFile(ArchiveFile.string('Prompts.txt', 'Package prompt library'));
    await packageZip.writeAsBytes(ZipEncoder().encodeBytes(outer));

    final output = Directory(p.join(temp.path, 'expanded'));
    final result = extractNestedSkillBundleArchive((packageZip.path, output.path));
    final skills = Map<String, String>.from(result['skills'] as Map);
    expect(skills.keys, unorderedEquals(['Skills/alpha', 'Skills/beta']));

    final alpha = Directory(p.join(output.path, skills['Skills/alpha']!));
    final beta = Directory(p.join(output.path, skills['Skills/beta']!));
    expect(File(p.join(alpha.path, 'SKILL.md')).existsSync(), isTrue);
    expect(File(p.join(alpha.path, 'references/guide.md')).readAsStringSync(), '# Alpha reference');
    expect(File(p.join(alpha.path, 'scripts/build.py')).readAsStringSync(), 'print("alpha")');
    expect(File(p.join(alpha.path, 'assets/config.json')).existsSync(), isTrue);
    expect(File(p.join(beta.path, 'examples/sample.js')).existsSync(), isTrue);
    expect(File(p.join(beta.path, 'assets/scene.json')).existsSync(), isTrue);
    expect(
      File(p.join(beta.path, 'examples/character_sheet.png')).readAsBytesSync(),
      [0x89, 0x50, 0x4e, 0x47, 0x00, 0xff],
    );

    final sharedDirectory = Directory(p.join(output.path, result['sharedDirectory'] as String));
    expect(
      File(p.join(sharedDirectory.path, 'package/Prompts.txt')).readAsStringSync(),
      'Package prompt library',
    );
    expect(result['bundleKind'], 'nested_skill_zip_bundle');
  });

  test('SkillsService imports every compatible nested Skill atomically and preserves companion files', () async {
    final outer = Archive()
      ..addFile(ArchiveFile.bytes(
        'Skills/alpha.zip',
        _skillZip(
          'alpha',
          {
            'references/guide.md': '# Alpha reference',
            'scripts/build.py': 'print("alpha")',
          },
          instructions: 'Run `scripts/missing-helper.py` after reading `references/guide.md`.',
        ),
      ))
      ..addFile(ArchiveFile.bytes(
        'Skills/beta.zip',
        _skillZip('beta', {
          'assets/scene.json': '{"scene":1}',
        }),
      ))
      ..addFile(ArchiveFile.string('Prompts.txt', 'Keep this package resource'));
    await packageZip.writeAsBytes(ZipEncoder().encodeBytes(outer));

    final database = AppDatabase(NativeDatabase.memory());
    final store = ExtensionEntityStore(database);
    final skillsDirectory = Directory(p.join(temp.path, 'installed-skills'));
    final metadataDirectory = Directory(p.join(temp.path, 'skill-metadata'));
    final service = SkillsService(
      store: store,
      skillsDirectory: skillsDirectory,
      skillImportMetadataDirectory: metadataDirectory,
    );
    await service.loaded;
    try {
      final preview = await service.inspectLocalSource(packageZip.path);
      expect(preview['skillCount'], 2);
      final previewNames = (preview['candidates'] as List)
          .map((candidate) => (candidate as Map)['name'])
          .toList();
      expect(previewNames, unorderedEquals(['alpha', 'beta']));
      final alphaPreview = (preview['candidates'] as List)
          .cast<Map>()
          .singleWhere((candidate) => candidate['name'] == 'alpha');
      expect(
        ((alphaPreview['compatibility'] as Map)['warnings'] as List).join(' '),
        contains('scripts/missing-helper.py'),
      );

      final installed = await service.importSkillsFromFile(
        packageZip.path,
        chooseSkills: (candidates) async => candidates
            .where((candidate) => candidate.compatibility.isImportable)
            .map((candidate) => candidate.path)
            .toSet(),
      );
      expect(installed.map((skill) => skill.name), unorderedEquals(['alpha', 'beta']));
      final alpha = installed.singleWhere((skill) => skill.name == 'alpha');
      final beta = installed.singleWhere((skill) => skill.name == 'beta');
      expect(File(p.join(skillsDirectory.path, alpha.record.id, 'references/guide.md')).existsSync(), isTrue);
      expect(File(p.join(skillsDirectory.path, alpha.record.id, 'scripts/build.py')).existsSync(), isTrue);
      expect(File(p.join(skillsDirectory.path, beta.record.id, 'assets/scene.json')).existsSync(), isTrue);
      final alphaReport = await service.getImportReport(alpha.record.id);
      expect(alphaReport, isNotNull);
      final alphaImportReport = alphaReport!;
      expect(alphaImportReport['completeness'], 'partial');
      expect(
        (alphaImportReport['completenessNotes'] as List).join(' '),
        contains('scripts/missing-helper.py'),
      );

      final sharedDocs = Directory(p.join(metadataDirectory.path, 'repositories'));
      final promptCopies = await sharedDocs
          .list(recursive: true, followLinks: false)
          .where((entity) => entity is File && p.basename(entity.path) == 'Prompts.txt')
          .toList();
      expect(promptCopies, hasLength(1));
      expect(await File(promptCopies.single.path).readAsString(), 'Keep this package resource');
    } finally {
      service.dispose();
      await database.close();
    }
  });

  test('extracts a direct GitHub .skill file from a repository snapshot', () async {
    final archive = Archive()
      ..addFile(ArchiveFile.string(
        'repository-main/character-visual-director.skill',
        '''
---
name: character-visual-director
description: Direct GitHub Skill file fixture.
---
# Character Visual Director
''',
      ));
    await packageZip.writeAsBytes(ZipEncoder().encodeBytes(archive));
    final output = File(p.join(temp.path, 'character-visual-director.skill'));
    final path = extractGitHubRepositoryFile((
      packageZip.path,
      output.path,
      'character-visual-director.skill',
      true,
    ));
    expect(await File(path).readAsString(), contains('name: character-visual-director'));
  });

  test('imports the exact direct GitHub ZIP file as a complete Skill archive', () async {
    final directSkillZip = _skillZip('github-bundle-skill', {
      'scripts/run.py': 'print("from github zip")',
      'references/guide.md': '# GitHub bundle guide',
      'assets/config.json': '{"source":"github-direct-zip"}',
    });
    final repositorySnapshot = Archive()
      ..addFile(ArchiveFile.bytes(
        'repository-main/bundles/viral-skills.zip',
        directSkillZip,
      ));
    await packageZip.writeAsBytes(ZipEncoder().encodeBytes(repositorySnapshot));

    // GitHub's repository snapshot is only the transport container. Extract
    // the exact ZIP payload first; the payload is then a regular Skill archive
    // with SKILL.md at its own root, not a nested-ZIP package.
    final extractedZip = File(p.join(temp.path, 'viral-skills.zip'));
    final extractedPath = extractGitHubRepositoryFile((
      packageZip.path,
      extractedZip.path,
      'bundles/viral-skills.zip',
      true,
    ));
    expect(await File(extractedPath).readAsBytes(), directSkillZip);

    final database = AppDatabase(NativeDatabase.memory());
    final service = SkillsService(
      store: ExtensionEntityStore(database),
      skillsDirectory: Directory(p.join(temp.path, 'installed-skills')),
      skillImportMetadataDirectory: Directory(p.join(temp.path, 'skill-metadata')),
    );
    await service.loaded;
    try {
      final preview = await service.inspectLocalSource(extractedPath);
      expect(preview['skillCount'], 1);
      final previewCandidate = (preview['candidates'] as List).single as Map;
      expect(previewCandidate['name'], 'github-bundle-skill');
      expect(previewCandidate['fileCount'], 4);

      final installed = await service.importSkillsFromFile(
        extractedPath,
        source: SkillSource.github,
        sourceUrl: 'https://github.com/example/repo/blob/main/bundles/viral-skills.zip',
        repository: 'example/repo',
        sourceRef: 'main',
        sourceRevision: 'main',
        sourceSubpath: 'bundles/viral-skills.zip',
        chooseSkills: (candidates) async => candidates
            .map((candidate) => candidate.path)
            .toSet(),
      );
      expect(installed, hasLength(1));
      final skill = installed.single;
      final installedRoot = Directory(
        p.join(service.skillsDirectory.path, skill.record.id),
      );
      expect(File(p.join(installedRoot.path, 'SKILL.md')).existsSync(), isTrue);
      expect(
        File(p.join(installedRoot.path, 'scripts/run.py')).readAsStringSync(),
        'print("from github zip")',
      );
      expect(
        File(p.join(installedRoot.path, 'references/guide.md')).readAsStringSync(),
        '# GitHub bundle guide',
      );
      expect(
        File(p.join(installedRoot.path, 'assets/config.json')).readAsStringSync(),
        '{"source":"github-direct-zip"}',
      );
    } finally {
      service.dispose();
      await database.close();
    }
  });

  test('imports a direct GitHub ZIP containing a nested multi-Skill package', () async {
    final packagePayload = Archive()
      ..addFile(ArchiveFile.bytes(
        'Skills/alpha.zip',
        _skillZip('alpha', {
          'scripts/alpha.py': 'print("alpha from direct GitHub package")',
          'references/alpha.md': '# Alpha reference',
        }),
      ))
      ..addFile(ArchiveFile.bytes(
        'Skills/beta.zip',
        _skillZip('beta', {
          'assets/beta.json': '{"beta":true}',
        }),
      ))
      ..addFile(ArchiveFile.string('Prompts.txt', 'Shared prompt resource'));
    final directPackageZip = ZipEncoder().encodeBytes(packagePayload);
    final repositorySnapshot = Archive()
      ..addFile(ArchiveFile.bytes(
        'repository-main/releases/Viral-Motion-Reel-Playbook_Skills.zip',
        directPackageZip,
      ));
    await packageZip.writeAsBytes(ZipEncoder().encodeBytes(repositorySnapshot));

    final extractedZip = File(p.join(temp.path, 'Viral-Motion-Reel-Playbook_Skills.zip'));
    final extractedPath = extractGitHubRepositoryFile((
      packageZip.path,
      extractedZip.path,
      'releases/Viral-Motion-Reel-Playbook_Skills.zip',
      true,
    ));
    expect(await File(extractedPath).readAsBytes(), directPackageZip);

    final database = AppDatabase(NativeDatabase.memory());
    final metadataDirectory = Directory(p.join(temp.path, 'package-metadata'));
    final service = SkillsService(
      store: ExtensionEntityStore(database),
      skillsDirectory: Directory(p.join(temp.path, 'installed-package-skills')),
      skillImportMetadataDirectory: metadataDirectory,
    );
    await service.loaded;
    try {
      final preview = await service.inspectLocalSource(extractedPath);
      expect(preview['skillCount'], 2);
      final previewNames = (preview['candidates'] as List)
          .map((candidate) => (candidate as Map)['name'])
          .toSet();
      expect(previewNames, {'alpha', 'beta'});

      final installed = await service.importSkillsFromFile(
        extractedPath,
        source: SkillSource.github,
        sourceUrl: 'https://github.com/example/repo/blob/main/releases/Viral-Motion-Reel-Playbook_Skills.zip',
        repository: 'example/repo',
        sourceRef: 'main',
        sourceRevision: 'main',
        sourceSubpath: 'releases/Viral-Motion-Reel-Playbook_Skills.zip',
        chooseSkills: (candidates) async => candidates
            .map((candidate) => candidate.path)
            .toSet(),
      );
      expect(installed.map((skill) => skill.name), unorderedEquals(['alpha', 'beta']));
      final alpha = installed.singleWhere((skill) => skill.name == 'alpha');
      final beta = installed.singleWhere((skill) => skill.name == 'beta');
      expect(
        File(p.join(service.skillsDirectory.path, alpha.record.id, 'scripts/alpha.py'))
            .readAsStringSync(),
        'print("alpha from direct GitHub package")',
      );
      expect(
        File(p.join(service.skillsDirectory.path, beta.record.id, 'assets/beta.json'))
            .readAsStringSync(),
        '{"beta":true}',
      );

      final sharedDocs = Directory(p.join(metadataDirectory.path, 'repositories'));
      final promptCopies = await sharedDocs
          .list(recursive: true, followLinks: false)
          .where((entity) => entity is File && p.basename(entity.path) == 'Prompts.txt')
          .toList();
      expect(promptCopies, hasLength(1));
      expect(await File(promptCopies.single.path).readAsString(), 'Shared prompt resource');
    } finally {
      service.dispose();
      await database.close();
    }
  });

  test('rejects path traversal inside a nested Skill ZIP', () async {
    final inner = Archive()
      ..addFile(ArchiveFile.string('alpha/SKILL.md', '''
---
name: alpha
description: Test skill.
---
'''))
      ..addFile(ArchiveFile.string('../escape.txt', 'outside'));
    final outer = Archive()
      ..addFile(ArchiveFile.bytes('Skills/alpha.zip', ZipEncoder().encodeBytes(inner)));
    await packageZip.writeAsBytes(ZipEncoder().encodeBytes(outer));
    expect(
      () => extractNestedSkillBundleArchive((
        packageZip.path,
        p.join(temp.path, 'unsafe-output'),
      )),
      throwsFormatException,
    );
    expect(File(p.join(temp.path, 'escape.txt')).existsSync(), isFalse);
  });
}
