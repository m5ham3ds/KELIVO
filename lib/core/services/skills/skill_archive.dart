import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

const int kSkillImportMaxBytes = 200 * 1024 * 1024;
const int kSkillImportMaxExtractedBytes = 500 * 1024 * 1024;

/// Extract only the selected skill to disk. Run in an isolate so large archives
/// do not block the UI or keep the whole download and extracted tree in memory.
String? extractSkillArchive(
  String archivePath,
  String outputDirectory, {
  String? subdir,
  bool stripSingleRoot = false,
}) {
  if (File(archivePath).lengthSync() > kSkillImportMaxBytes) {
    throw const FormatException('zip exceeds 200 MB');
  }
  final input = InputFileStream(archivePath);
  try {
    final archive = ZipDecoder().decodeStream(input);
    final entries = <String, ArchiveFile>{};
    var archiveEntryCount = 0;
    for (final file in archive) {
      archiveEntryCount++;
      if (archiveEntryCount > 8192) {
        throw const FormatException('skill_archive_entry_limit');
      }
      if (!file.isFile || file.isSymbolicLink) continue;
      final name = safeZipEntryName(file.name);
      if (name == null) continue;
      if (entries.containsKey(name)) {
        throw FormatException('duplicate_zip_entry: $name');
      }
      entries[name] = file;
    }
    if (entries.isEmpty) {
      throw const FormatException('zip contains no files');
    }
    var files = stripSingleRoot ? _stripSingleRoot(entries) : entries;
    if (subdir != null && subdir.isNotEmpty) {
      files = _takePrefix(files, _posixRel(subdir));
    }
    final skillRoot = _findSkillRoot(files);
    files = _narrowToSkillRoot(files);
    // Check metadata before decompressing; files outside the skill are skipped.
    final total = files.values.fold<int>(0, (sum, file) => sum + file.size);
    if (total > kSkillImportMaxExtractedBytes) {
      throw const FormatException('extracted skill exceeds 500 MB');
    }
    var written = 0;
    for (final entry in files.entries) {
      final dest = p.join(outputDirectory, entry.key);
      if (!p.isWithin(p.canonicalize(outputDirectory), p.canonicalize(dest))) {
        throw const FormatException('zip-slip');
      }
      Directory(p.dirname(dest)).createSync(recursive: true);
      final output = _LimitedSkillOutputStream(
        dest,
        kSkillImportMaxExtractedBytes - written,
      );
      try {
        entry.value.writeContent(output);
        written += output.length;
      } finally {
        output.closeSync();
      }
    }
    final sourceSkillRoot = skillRoot == '.' && subdir != null && subdir.isNotEmpty
        ? _posixRel(subdir)
        : skillRoot;
    return sourceSkillRoot == '.'
        ? null
        : p.posix.basename(sourceSkillRoot);
  } finally {
    input.closeSync();
  }
}

/// Enforce the actual output size too, even if a zip's size metadata is wrong.
class _LimitedSkillOutputStream extends OutputFileStream {
  _LimitedSkillOutputStream(String path, this.maxBytes)
    : super.withFileHandle(FileHandle(path, mode: FileAccess.write));

  final int maxBytes;

  void _check(int count) {
    if (length + count > maxBytes) {
      throw const FormatException('extracted skill exceeds 500 MB');
    }
  }

  @override
  void writeByte(int value) {
    _check(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    _check(length ?? bytes.length);
    super.writeBytes(bytes, length: length);
  }
}

List<int> encodeSkillZip(Map<String, List<int>> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    archive.addFile(ArchiveFile.bytes(entry.key, entry.value));
  }
  return ZipEncoder().encodeBytes(archive);
}

/// Returns a normalized relative path, or `null` for a directory entry.
/// Throws [FormatException] on zip-slip.
String? safeZipEntryName(String raw) {
  var name = raw.replaceAll('\\', '/');
  if (name.startsWith('/') ||
      RegExp(r'^[A-Za-z]:').hasMatch(name) ||
      name.contains('\u0000')) {
    throw const FormatException('zip-slip');
  }
  while (name.startsWith('./')) {
    name = name.substring(2);
  }
  if (name.isEmpty || name.endsWith('/')) return null;
  if (name.split('/').any((part) => part == '..' || part == '.')) {
    throw const FormatException('zip-slip');
  }
  final normalized = p.posix.normalize(name);
  if (normalized.isEmpty ||
      normalized == '.' ||
      normalized.startsWith('/') ||
      normalized.split('/').contains('..')) {
    throw const FormatException('zip-slip');
  }
  return normalized;
}

String _posixRel(String value) {
  var path = value.replaceAll('\\', '/');
  while (path.startsWith('/')) {
    path = path.substring(1);
  }
  if (path.endsWith('/')) path = path.substring(0, path.length - 1);
  return p.posix.normalize(path);
}

Map<String, ArchiveFile> _stripSingleRoot(Map<String, ArchiveFile> files) {
  final roots = <String>{};
  for (final name in files.keys) {
    roots.add(name.split('/').first);
  }
  if (roots.length != 1) return files;
  final root = roots.single;
  if (root == 'SKILL.md') return files;
  return _takePrefix(files, root);
}

Map<String, ArchiveFile> _takePrefix(
  Map<String, ArchiveFile> files,
  String prefix,
) {
  if (prefix.isEmpty || prefix == '.') return files;
  final lead = '$prefix/';
  final out = <String, ArchiveFile>{};
  for (final entry in files.entries) {
    if (entry.key == prefix) continue;
    if (entry.key.startsWith(lead)) {
      out[entry.key.substring(lead.length)] = entry.value;
    }
  }
  if (out.isEmpty) {
    throw FormatException('zip is missing $prefix');
  }
  return out;
}

String _findSkillRoot(Map<String, ArchiveFile> files) {
  if (files.containsKey('SKILL.md')) return '.';
  final dirs = <String>{};
  for (final name in files.keys) {
    if (p.posix.basename(name) != 'SKILL.md') continue;
    final directory = p.posix.dirname(name);
    if (directory != '.' && directory != '/') dirs.add(directory);
  }
  if (dirs.isEmpty) {
    throw const FormatException('SKILL.md not found');
  }
  if (dirs.length > 1) {
    final candidates = (dirs.toList()..sort()).take(12).join(', ');
    throw FormatException(
      'multiple_skills_found: specify the exact Skill folder in the GitHub '
      'URL. Candidates: $candidates',
    );
  }
  return dirs.single;
}

Map<String, ArchiveFile> _narrowToSkillRoot(Map<String, ArchiveFile> files) {
  final root = _findSkillRoot(files);
  return root == '.' ? files : _takePrefix(files, root);
}

int _skillPathDepth(String path) => path == '.' ? 0 : path.split('/').length;

/// Extract every valid Agent Skill root from one archive without selecting an
/// arbitrary candidate. The returned map is `repository-relative skill path`
/// to an isolated directory under [outputDirectory]. Nested Skills receive
/// only their own files (the deepest matching root owns each archive entry).
Map<String, String> extractSkillArchiveMultiple(
  String archivePath,
  String outputDirectory, {
  String? subdir,
  bool stripSingleRoot = false,
}) {
  if (File(archivePath).lengthSync() > kSkillImportMaxBytes) {
    throw const FormatException('zip exceeds 200 MB');
  }
  final input = InputFileStream(archivePath);
  try {
    final archive = ZipDecoder().decodeStream(input);
    final entries = <String, ArchiveFile>{};
    var archiveEntryCount = 0;
    for (final file in archive) {
      archiveEntryCount++;
      if (archiveEntryCount > 8192) {
        throw const FormatException('skill_archive_entry_limit');
      }
      if (!file.isFile || file.isSymbolicLink) continue;
      final name = safeZipEntryName(file.name);
      if (name == null) continue;
      if (entries.containsKey(name)) {
        throw FormatException('duplicate_zip_entry: $name');
      }
      entries[name] = file;
    }
    if (entries.isEmpty) {
      throw const FormatException('zip contains no files');
    }
    var files = stripSingleRoot ? _stripSingleRoot(entries) : entries;
    final sourcePrefix = subdir == null || subdir.isEmpty
        ? ''
        : _posixRel(subdir);
    if (sourcePrefix.isNotEmpty) {
      files = _takePrefix(files, sourcePrefix);
    }

    final roots = <String>{};
    for (final name in files.keys) {
      if (p.posix.basename(name) != 'SKILL.md') continue;
      final dir = p.posix.dirname(name);
      roots.add(dir == '.' || dir == '/' ? '.' : dir);
    }
    if (roots.isEmpty) {
      throw const FormatException('SKILL.md not found');
    }
    if (roots.length > 128) {
      throw const FormatException('too_many_skills_in_repository');
    }

    final sortedRoots = roots.toList()
      ..sort((a, b) {
        final depth = _skillPathDepth(a).compareTo(_skillPathDepth(b));
        return depth != 0 ? depth : a.compareTo(b);
      });
    final outputRoot = Directory(outputDirectory);
    outputRoot.createSync(recursive: true);
    final canonicalRoot = p.canonicalize(outputRoot.path);
    final result = <String, String>{};
    for (var index = 0; index < sortedRoots.length; index++) {
      final root = sortedRoots[index];
      final folderName = 'skill_${index.toString().padLeft(4, '0')}';
      final originalPath = root == '.'
          ? (sourcePrefix.isEmpty ? '.' : sourcePrefix)
          : (sourcePrefix.isEmpty ? root : '$sourcePrefix/$root');
      result[originalPath] = folderName;
    }

    var totalBytes = 0;
    var actualWrittenBytes = 0;
    var totalFiles = 0;
    for (final entry in files.entries) {
      // A file belongs to the deepest Skill root containing it.
      String? owner;
      for (final root in sortedRoots) {
        final isWithinRoot = root == '.' || entry.key.startsWith('$root/');
        if (!isWithinRoot) continue;
        if (owner == null ||
            _skillPathDepth(root) > _skillPathDepth(owner)) {
          owner = root;
        }
      }
      if (owner == null) continue;
      final relative = owner == '.'
          ? entry.key
          : entry.key.substring(owner.length + 1);
      final normalized = safeZipEntryName(relative);
      if (normalized == null) continue;
      totalFiles++;
      if (totalFiles > 4096) {
        throw const FormatException('skill_repository_file_limit');
      }
      totalBytes += entry.value.size;
      if (totalBytes > kSkillImportMaxExtractedBytes) {
        throw const FormatException('extracted skill exceeds 500 MB');
      }
      final folder = result[owner == '.'
          ? (sourcePrefix.isEmpty ? '.' : sourcePrefix)
          : (sourcePrefix.isEmpty ? owner : '$sourcePrefix/$owner')]!;
      final destination = p.join(outputRoot.path, folder, normalized);
      final canonicalDestination = p.canonicalize(destination);
      if (!p.equals(canonicalRoot, canonicalDestination) &&
          !p.isWithin(canonicalRoot, canonicalDestination)) {
        throw const FormatException('zip-slip');
      }
      Directory(p.dirname(destination)).createSync(recursive: true);
      final alreadyWritten = Directory(p.join(outputRoot.path, folder));
      final output = _LimitedSkillOutputStream(
        destination,
        kSkillImportMaxExtractedBytes - actualWrittenBytes,
      );
      try {
        entry.value.writeContent(output);
        actualWrittenBytes += output.length;
      } finally {
        output.closeSync();
      }
      if (!alreadyWritten.existsSync()) {
        throw const FormatException('skill_extract_failed');
      }
    }
    return result;
  } finally {
    input.closeSync();
  }
}

/// Extracts a repository snapshot without losing files that live outside
/// individual Skill roots. Skill folders stay separate; repository-level
/// resources are staged under a separate `shared/` directory and are never
/// copied into a Skill implicitly.
///
/// The return value is isolate-sendable JSON-like data so callers can use
/// Flutter's `compute` without moving decoded archive objects across isolates.
Map<String, Object?> extractSkillRepositoryArchive(
  String archivePath,
  String outputDirectory, {
  String? subdir,
  bool stripSingleRoot = false,
}) {
  if (File(archivePath).lengthSync() > kSkillImportMaxBytes) {
    throw const FormatException('zip exceeds 200 MB');
  }
  final input = InputFileStream(archivePath);
  try {
    final archive = ZipDecoder().decodeStream(input);
    var archiveEntryCount = 0;
    final entries = <String, ArchiveFile>{};
    final skipped = <Map<String, Object?>>[];
    for (final file in archive) {
      archiveEntryCount++;
      if (archiveEntryCount > 8192) {
        throw const FormatException('skill_repository_entry_limit');
      }
      final name = safeZipEntryName(file.name);
      if (name == null) continue;
      if (entries.containsKey(name)) {
        throw FormatException('duplicate_zip_entry: $name');
      }
      if (file.isSymbolicLink) {
        skipped.add(<String, Object?>{
          'path': name,
          'reason': 'symbolic_link_not_supported',
          'scope': 'repository',
        });
        continue;
      }
      if (!file.isFile) continue;
      entries[name] = file;
    }
    if (entries.isEmpty) {
      throw const FormatException('zip contains no regular files');
    }

    var files = stripSingleRoot ? _stripSingleRoot(entries) : entries;
    final sourcePrefix = subdir == null || subdir.isEmpty
        ? ''
        : _safeArchiveSubdir(subdir);
    if (sourcePrefix.isNotEmpty) {
      files = _takePrefix(files, sourcePrefix);
    }

    final roots = <String>{};
    for (final name in files.keys) {
      if (p.posix.basename(name) != 'SKILL.md') continue;
      final directory = p.posix.dirname(name);
      roots.add(directory == '.' || directory == '/' ? '.' : directory);
    }
    if (roots.isEmpty) {
      throw const FormatException('SKILL.md not found');
    }
    if (roots.length > 128) {
      throw const FormatException('too_many_skills_in_repository');
    }

    final sortedRoots = roots.toList()
      ..sort((a, b) {
        final depth = _skillPathDepth(a).compareTo(_skillPathDepth(b));
        return depth != 0 ? depth : a.compareTo(b);
      });
    final outputRoot = Directory(outputDirectory);
    outputRoot.createSync(recursive: true);
    if (FileSystemEntity.typeSync(outputRoot.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw const FormatException('skill_extract_output_not_directory');
    }
    final canonicalRoot = p.canonicalize(outputRoot.path);
    final skillDirectories = <String, String>{};
    final skillModes = <String, Map<String, bool?>>{};
    for (var index = 0; index < sortedRoots.length; index++) {
      final root = sortedRoots[index];
      final folderName = 'skill_${index.toString().padLeft(4, '0')}';
      final originalPath = root == '.'
          ? (sourcePrefix.isEmpty ? '.' : sourcePrefix)
          : (sourcePrefix.isEmpty ? root : '$sourcePrefix/$root');
      skillDirectories[originalPath] = folderName;
      skillModes[originalPath] = <String, bool?>{};
    }

    const sharedDirectoryName = 'shared';
    final sharedPaths = <String>[];
    final sharedModes = <String, bool?>{};
    var totalFiles = 0;
    var declaredExpandedBytes = 0;
    var actualExpandedBytes = 0;

    for (final entry in files.entries) {
      String? owner;
      for (final root in sortedRoots) {
        final within = root == '.' || entry.key.startsWith('$root/');
        if (!within) continue;
        if (owner == null || _skillPathDepth(root) > _skillPathDepth(owner)) {
          owner = root;
        }
      }

      final isShared = owner == null;
      final relative = isShared
          ? entry.key
          : (owner == '.' ? entry.key : entry.key.substring(owner.length + 1));
      final normalized = safeZipEntryName(relative);
      if (normalized == null) continue;
      totalFiles++;
      if (totalFiles > 8192) {
        throw const FormatException('skill_repository_file_limit');
      }
      if (entry.value.size > 200 * 1024 * 1024) {
        throw FormatException('skill_repository_single_file_too_large:$relative');
      }
      declaredExpandedBytes += entry.value.size;
      if (declaredExpandedBytes > kSkillImportMaxExtractedBytes) {
        throw const FormatException('skill_repository_expanded_size_limit');
      }

      final folder = isShared
          ? sharedDirectoryName
          : skillDirectories[owner == '.'
              ? (sourcePrefix.isEmpty ? '.' : sourcePrefix)
              : (sourcePrefix.isEmpty ? owner : '$sourcePrefix/$owner')]!;
      final destination = p.join(outputRoot.path, folder, normalized);
      final canonicalDestination = p.canonicalize(destination);
      if (!p.equals(canonicalRoot, canonicalDestination) &&
          !p.isWithin(canonicalRoot, canonicalDestination)) {
        throw const FormatException('zip-slip');
      }
      final parent = Directory(p.dirname(destination));
      parent.createSync(recursive: true);
      final canonicalParent = p.canonicalize(parent.path);
      if (!p.equals(canonicalRoot, canonicalParent) &&
          !p.isWithin(canonicalRoot, canonicalParent)) {
        throw const FormatException('zip-slip');
      }
      if (FileSystemEntity.typeSync(destination, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw FormatException('duplicate_extracted_path:$relative');
      }
      final output = _LimitedSkillOutputStream(
        destination,
        kSkillImportMaxExtractedBytes - actualExpandedBytes,
      );
      try {
        entry.value.writeContent(output);
        actualExpandedBytes += output.length;
      } finally {
        output.closeSync();
      }
      final mode = entry.value.mode;
      // Preserve the source archive's Unix execute-bit evidence when present.
      // A zero mode is explicitly unknown and must not be replaced by the
      // temporary extraction file's host permissions.
      final bool? executable = mode == 0 ? null : (mode & 0x49) != 0;
      if (isShared) {
        sharedModes[normalized] = executable;
      } else {
        final ownerKey = owner == '.'
            ? (sourcePrefix.isEmpty ? '.' : sourcePrefix)
            : (sourcePrefix.isEmpty ? owner : '$sourcePrefix/$owner');
        skillModes[ownerKey]![normalized] = executable;
      }
      if (isShared) sharedPaths.add(normalized);
    }

    return <String, Object?>{
      'skills': skillDirectories,
      'sharedDirectory': sharedPaths.isEmpty ? null : sharedDirectoryName,
      'sharedPaths': sharedPaths..sort(),
      'skipped': skipped,
      'skillExecutableModes': skillModes,
      'sharedExecutableModes': sharedModes,
      'fileCount': totalFiles,
      'expandedBytes': actualExpandedBytes,
    };
  } finally {
    input.closeSync();
  }
}

/// Expand a package ZIP that contains one or more nested Skill ZIP files.
///
/// Each nested ZIP is treated as a complete Agent Skill repository snapshot:
/// its SKILL.md and every companion file remain together in their own
/// extracted Skill directory. Files from the outer package and files that
/// live outside a nested Skill root are retained separately under `shared/`.
/// No scripts or executables are run during normalization.
Map<String, Object?> extractNestedSkillBundleArchive(
  (String, String) args,
) {
  final archivePath = args.$1;
  final outputDirectory = args.$2;
  if (File(archivePath).lengthSync() > kSkillImportMaxBytes) {
    throw const FormatException('zip exceeds 200 MB');
  }
  final outputRoot = Directory(outputDirectory)..createSync(recursive: true);
  if (FileSystemEntity.typeSync(outputRoot.path, followLinks: false) !=
      FileSystemEntityType.directory) {
    throw const FormatException('skill_extract_output_not_directory');
  }
  final canonicalRoot = p.canonicalize(outputRoot.path);
  final input = InputFileStream(archivePath);
  try {
    final archive = ZipDecoder().decodeStream(input);
    final outerEntries = <String, ArchiveFile>{};
    final skipped = <Map<String, Object?>>[];
    var outerEntryCount = 0;
    for (final entry in archive) {
      outerEntryCount++;
      if (outerEntryCount > 8192) {
        throw const FormatException('skill_repository_entry_limit');
      }
      final name = safeZipEntryName(entry.name);
      if (name == null) continue;
      if (outerEntries.containsKey(name)) {
        throw FormatException('duplicate_zip_entry: $name');
      }
      if (entry.isSymbolicLink) {
        skipped.add(<String, Object?>{
          'path': name,
          'reason': 'symbolic_link_not_supported',
          'scope': 'package',
        });
        continue;
      }
      if (entry.isFile) outerEntries[name] = entry;
    }
    if (outerEntries.isEmpty) {
      throw const FormatException('zip contains no regular files');
    }

    final skillDirectories = <String, String>{};
    final skillModes = <String, Map<String, bool?>>{};
    final sharedModes = <String, bool?>{};
    final sharedPaths = <String>[];
    final sharedRoot = Directory(p.join(outputRoot.path, 'shared'));
    var totalExpandedBytes = 0;
    var totalFiles = 0;
    var skillIndex = 0;
    final usedBundleNames = <String>{};
    var nestedZipCount = 0;
    var totalArchiveEntries = outerEntryCount;

    bool isWithinRoot(String path) =>
        p.equals(canonicalRoot, path) || p.isWithin(canonicalRoot, path);

    void ensureSafeOutput(FileSystemEntity entity) {
      if (!isWithinRoot(p.canonicalize(entity.path))) {
        throw const FormatException('zip-slip');
      }
    }

    void writeSharedEntry(ArchiveFile entry, String relativePath) {
      final safe = safeZipEntryName(relativePath);
      if (safe == null) return;
      final destination = File(p.join(sharedRoot.path, safe));
      Directory(p.dirname(destination.path)).createSync(recursive: true);
      ensureSafeOutput(destination.parent);
      if (FileSystemEntity.typeSync(destination.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw FormatException('duplicate_extracted_path:$safe');
      }
      final remaining = kSkillImportMaxExtractedBytes - totalExpandedBytes;
      final output = _LimitedSkillOutputStream(destination.path, remaining);
      try {
        entry.writeContent(output);
        totalExpandedBytes += output.length;
      } finally {
        output.closeSync();
      }
      totalFiles++;
      if (totalFiles > 8192) {
        throw const FormatException('skill_repository_file_limit');
      }
      final mode = entry.mode;
      sharedModes[safe] = mode == 0 ? null : (mode & 0x49) != 0;
      sharedPaths.add(safe);
    }

    for (final outer in outerEntries.entries) {
      final name = outer.key;
      final entry = outer.value;
      if (p.posix.extension(name).toLowerCase() != '.zip') {
        writeSharedEntry(entry, 'package/$name');
        continue;
      }

      nestedZipCount++;
      if (nestedZipCount > 128) {
        throw const FormatException('too_many_nested_skill_archives');
      }
      final stem = p.posix.basenameWithoutExtension(name);
      final safeStem = safeZipEntryName(stem);
      if (safeStem == null || safeStem.contains('/')) {
        throw FormatException('invalid_nested_skill_archive_name:$name');
      }
      if (!usedBundleNames.add(safeStem.toLowerCase())) {
        throw FormatException('duplicate_nested_skill_bundle_name:$safeStem');
      }
      final nestedZip = File(p.join(outputRoot.path, '.nested-$nestedZipCount.zip'));
      final nestedOutput = _LimitedSkillOutputStream(
        nestedZip.path,
        kSkillImportMaxBytes,
      );
      try {
        entry.writeContent(nestedOutput);
      } finally {
        nestedOutput.closeSync();
      }
      if (nestedOutput.length > kSkillImportMaxBytes) {
        throw const FormatException('nested_skill_zip_exceeds_200_mb');
      }

      // Inspect inner ZIP metadata before extraction so multiple nested
      // archives share one aggregate expansion budget.
      final nestedInput = InputFileStream(nestedZip.path);
      var nestedDeclaredBytes = 0;
      var nestedEntryCount = 0;
      try {
        final nestedArchive = ZipDecoder().decodeStream(nestedInput);
        final seen = <String>{};
        for (final nestedEntry in nestedArchive) {
          nestedEntryCount++;
          totalArchiveEntries++;
          if (nestedEntryCount > 8192 || totalArchiveEntries > 8192) {
            throw const FormatException('skill_archive_entry_limit');
          }
          final nestedName = safeZipEntryName(nestedEntry.name);
          if (nestedName == null) continue;
          if (!seen.add(nestedName)) {
            throw FormatException('duplicate_zip_entry: $nestedName');
          }
          if (!nestedEntry.isFile || nestedEntry.isSymbolicLink) continue;
          nestedDeclaredBytes += nestedEntry.size;
          if (nestedDeclaredBytes > kSkillImportMaxExtractedBytes ||
              totalExpandedBytes + nestedDeclaredBytes >
                  kSkillImportMaxExtractedBytes) {
            throw const FormatException('skill_repository_expanded_size_limit');
          }
        }
      } finally {
        nestedInput.closeSync();
      }

      final nestedDirectory = Directory(
        p.join(outputRoot.path, '.nested-$nestedZipCount'),
      )..createSync(recursive: true);
      Map<String, Object?> nestedExtraction;
      try {
        nestedExtraction = extractSkillRepositoryArchive(
          nestedZip.path,
          nestedDirectory.path,
          stripSingleRoot: true,
        );
      } on FormatException catch (error) {
        if (!error.message.toString().contains('SKILL.md not found')) rethrow;
        // Keep non-Skill ZIPs from the package rather than silently discarding
        // them. They remain shared resources and are never executed.
        final rawEntry = ArchiveFile.bytes(
          'ignored.zip',
          nestedZip.readAsBytesSync(),
        );
        writeSharedEntry(rawEntry, 'package/unclassified-zips/$name');
        skipped.add(<String, Object?>{
          'path': name,
          'reason': 'nested_zip_contains_no_skill_md',
          'scope': 'package',
        });
        nestedZip.deleteSync();
        nestedDirectory.deleteSync(recursive: true);
        continue;
      }

      final nestedSkills = Map<String, String>.from(
        (nestedExtraction['skills'] as Map).map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        ),
      );
      final nestedSharedPaths = (nestedExtraction['sharedPaths'] as List? ??
              const <Object?>[])
          .whereType<String>()
          .toList(growable: false);
      final nestedSharedName = nestedExtraction['sharedDirectory'] as String?;
      final nestedShared = nestedSharedName == null
          ? null
          : Directory(p.join(nestedDirectory.path, nestedSharedName));

      final nestedModes = nestedExtraction['skillExecutableModes'];
      for (final skillEntry in nestedSkills.entries) {
        if (skillIndex >= 128) {
          throw const FormatException('too_many_skills_in_repository');
        }
        final internalPath = skillEntry.key;
        final bundlePath = internalPath == '.'
            ? 'Skills/$safeStem'
            : 'Skills/$safeStem/$internalPath';
        final folderName = 'skill_${skillIndex.toString().padLeft(4, '0')}';
        final sourceDirectory = Directory(
          p.join(nestedDirectory.path, skillEntry.value),
        );
        final destination = Directory(p.join(outputRoot.path, folderName));
        if (FileSystemEntity.typeSync(destination.path, followLinks: false) !=
            FileSystemEntityType.notFound) {
          throw const FormatException('duplicate_extracted_path');
        }
        ensureSafeOutput(destination);
        sourceDirectory.renameSync(destination.path);
        skillDirectories[bundlePath] = folderName;
        final modeMap = <String, bool?>{};
        if (nestedModes is Map) {
          final rawMap = nestedModes[internalPath];
          if (rawMap is Map) {
            for (final item in rawMap.entries) {
              modeMap[item.key.toString()] = item.value as bool?;
            }
          }
        }
        skillModes[bundlePath] = modeMap;
        skillIndex++;
      }

      if (nestedShared != null && nestedSharedPaths.isNotEmpty) {
        for (final relative in nestedSharedPaths) {
          final safe = safeZipEntryName(relative);
          if (safe == null) continue;
          final source = File(p.join(nestedShared.path, safe));
          if (FileSystemEntity.typeSync(source.path, followLinks: false) !=
              FileSystemEntityType.file) {
            throw FormatException('nested_shared_resource_missing:$safe');
          }
          final destinationPath = 'nested/$safeStem/$safe';
          final destination = File(p.join(sharedRoot.path, destinationPath));
          Directory(p.dirname(destination.path)).createSync(recursive: true);
          ensureSafeOutput(destination.parent);
          if (FileSystemEntity.typeSync(destination.path, followLinks: false) !=
              FileSystemEntityType.notFound) {
            throw FormatException('duplicate_extracted_path:$destinationPath');
          }
          source.copySync(destination.path);
          sharedPaths.add(destinationPath);
          final rawModes = nestedExtraction['sharedExecutableModes'];
          if (rawModes is Map && rawModes.containsKey(safe)) {
            sharedModes[destinationPath] = rawModes[safe] as bool?;
          } else {
            sharedModes[destinationPath] = null;
          }
        }
      }

      totalExpandedBytes += (nestedExtraction['expandedBytes'] as num?)?.toInt() ?? 0;
      if (totalExpandedBytes > kSkillImportMaxExtractedBytes) {
        throw const FormatException('skill_repository_expanded_size_limit');
      }
      totalFiles += (nestedExtraction['fileCount'] as num?)?.toInt() ?? 0;
      if (totalFiles > 8192) {
        throw const FormatException('skill_repository_file_limit');
      }
      final nestedSkipped = nestedExtraction['skipped'] as List? ?? const [];
      for (final value in nestedSkipped) {
        if (value is Map) {
          skipped.add(<String, Object?>{
            ...value.map((key, item) => MapEntry(key.toString(), item)),
            'path': '$name/${value['path'] ?? ''}',
          });
        }
      }
      if (nestedZip.existsSync()) nestedZip.deleteSync();
      if (nestedDirectory.existsSync()) nestedDirectory.deleteSync(recursive: true);
    }

    if (nestedZipCount == 0) {
      throw const FormatException('nested_skill_bundle_no_nested_zip_files');
    }
    if (skillDirectories.isEmpty) {
      throw const FormatException('nested_skill_bundle_no_agent_skills_found');
    }
    sharedPaths.sort();
    return <String, Object?>{
      'skills': skillDirectories,
      'sharedDirectory': sharedPaths.isEmpty ? null : 'shared',
      'sharedPaths': sharedPaths,
      'skipped': skipped,
      'skillExecutableModes': skillModes,
      'sharedExecutableModes': sharedModes,
      'fileCount': totalFiles,
      'expandedBytes': totalExpandedBytes,
      'bundleKind': 'nested_skill_zip_bundle',
    };
  } finally {
    input.closeSync();
  }
}

/// Extract one exact file from a GitHub repository snapshot after optionally
/// removing the common top-level repository directory.
String extractGitHubRepositoryFile(
  (String, String, String, bool) args,
) {
  final archivePath = args.$1;
  final outputPath = args.$2;
  final targetPath = safeZipEntryName(args.$3);
  final stripSingleRoot = args.$4;
  if (targetPath == null) {
    throw const FormatException('invalid_github_skill_file_path');
  }
  if (File(archivePath).lengthSync() > kSkillImportMaxBytes) {
    throw const FormatException('zip exceeds 200 MB');
  }
  final input = InputFileStream(archivePath);
  try {
    final archive = ZipDecoder().decodeStream(input);
    final files = <String, ArchiveFile>{};
    var count = 0;
    for (final entry in archive) {
      count++;
      if (count > 8192) {
        throw const FormatException('skill_repository_entry_limit');
      }
      final name = safeZipEntryName(entry.name);
      if (name == null) continue;
      if (entry.isSymbolicLink) continue;
      if (entry.isFile) {
        if (files.containsKey(name)) {
          throw FormatException('duplicate_zip_entry: $name');
        }
        files[name] = entry;
      }
    }
    final normalized = stripSingleRoot ? _stripSingleRoot(files) : files;
    final entry = normalized[targetPath];
    if (entry == null) {
      throw FormatException('github_skill_file_not_found:$targetPath');
    }
    if (entry.size > kSkillImportMaxBytes) {
      throw const FormatException('github_skill_file_too_large');
    }
    final destination = File(outputPath);
    Directory(p.dirname(destination.path)).createSync(recursive: true);
    final output = _LimitedSkillOutputStream(
      destination.path,
      kSkillImportMaxBytes,
    );
    try {
      entry.writeContent(output);
    } finally {
      output.closeSync();
    }
    return destination.path;
  } finally {
    input.closeSync();
  }
}

String _safeArchiveSubdir(String value) {
  final normalized = value.replaceAll('\\', '/');
  if (normalized.isEmpty || normalized.startsWith('/') ||
      normalized.contains('\u0000') ||
      RegExp(r'^[A-Za-z]:').hasMatch(normalized) ||
      normalized.split('/').any((part) => part.isEmpty || part == '.' || part == '..')) {
    throw const FormatException('unsafe_archive_subdirectory');
  }
  return p.posix.normalize(normalized);
}
