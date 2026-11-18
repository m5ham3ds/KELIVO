import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../features/intelligent_ui/catalog/ui_guidance.dart';
import 'skill_authoring_guidance.dart';

/// Materializes read-only application guidance under a hidden directory inside
/// the Skills zone. These files are not Skills and never appear in the user's
/// installed Skill list. Models can read them through the existing /skills
/// read_file capability without adding another workspace path zone.
abstract final class CoreGuidanceService {
  static const directoryName = '.kelivo-core';

  static Future<void> ensureInstalled(Directory skillsRoot) async {
    await _ensureDirectory(skillsRoot);
    final root = Directory(p.join(skillsRoot.path, directoryName));
    await _ensureDirectory(root);

    final files = <String, String>{
      'skill-authoring/GUIDE.md': SkillAuthoringGuidance.guide,
      for (final entry in UiGuidance.generateAssets().entries)
        'intelligent-ui/${entry.key}': entry.value,
    };

    for (final entry in files.entries) {
      await _writeManagedFile(root, entry.key, entry.value);
    }
  }

  static Future<void> _ensureDirectory(Directory directory) async {
    final type = await FileSystemEntity.type(
      directory.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.notFound) {
      await directory.create(recursive: true);
      return;
    }
    if (type != FileSystemEntityType.directory) {
      throw const FormatException('core_guidance_path');
    }
  }

  static Future<void> _writeManagedFile(
    Directory root,
    String relativePath,
    String contents,
  ) async {
    final segments = p.posix.split(relativePath);
    if (relativePath.startsWith('/') ||
        relativePath.contains('\\') ||
        segments.any(
          (segment) => segment.isEmpty || segment == '.' || segment == '..',
        )) {
      throw const FormatException('core_guidance_relative_path');
    }

    var parent = root;
    for (final segment in segments.take(segments.length - 1)) {
      parent = Directory(p.join(parent.path, segment));
      await _ensureDirectory(parent);
    }
    final target = File(p.join(root.path, p.joinAll(segments)));
    final targetType = await FileSystemEntity.type(
      target.path,
      followLinks: false,
    );
    if (targetType != FileSystemEntityType.notFound &&
        targetType != FileSystemEntityType.file) {
      throw const FormatException('core_guidance_file');
    }
    if (targetType == FileSystemEntityType.file &&
        await target.readAsString() == contents) {
      return;
    }

    final temporary = File('${target.path}.tmp');
    final tempType = await FileSystemEntity.type(
      temporary.path,
      followLinks: false,
    );
    if (tempType != FileSystemEntityType.notFound &&
        tempType != FileSystemEntityType.file) {
      throw const FormatException('core_guidance_temp_file');
    }
    if (tempType == FileSystemEntityType.file) await temporary.delete();
    await temporary.writeAsString(contents, flush: true);
    if (targetType == FileSystemEntityType.file) await target.delete();
    await temporary.rename(target.path);
  }
}
