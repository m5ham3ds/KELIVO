import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

/// Platform-specific application data directory utilities.
///
/// - Windows: the selected data directory, defaulting to Application Support.
/// - macOS/Linux: Application Support, provided by `path_provider`.
/// - iOS: database state in Application Support; user files in Documents.
/// - Android: Application Documents directory.
class AppDirectories {
  AppDirectories._();

  /// Android application data is stored in the app's private documents folder.
  static Future<Directory> getAppDataDirectory() =>
      getApplicationDocumentsDirectory();

  /// Android has no separate public Documents area for the private app data.
  static Future<Directory?> documentsDirectoryFor(Directory active) async =>
      null;

  /// On Android, user files and the database share the app data root.
  static Future<Directory> getContentDirectory() => getAppDataDirectory();

  static Future<Directory> contentDirectoryFor(Directory databaseRoot) async =>
      databaseRoot;

  /// Gets the directory for uploaded files.
  static Future<Directory> getUploadDirectory() async {
    final root = await getContentDirectory();
    return Directory('${root.path}/upload');
  }

  /// Gets the directory for image files.
  static Future<Directory> getImagesDirectory() async {
    final root = await getContentDirectory();
    return Directory('${root.path}/images');
  }

  /// Gets the directory for avatar files.
  static Future<Directory> getAvatarsDirectory() async {
    final root = await getContentDirectory();
    return Directory('${root.path}/avatars');
  }

  /// Gets the directory for user-imported font files.
  static Future<Directory> getFontsDirectory() async {
    final root = await getContentDirectory();
    return Directory('${root.path}/fonts');
  }

  /// Gets the directory for cache files.
  static Future<Directory> getCacheDirectory() async {
    final root = await getContentDirectory();
    return Directory('${root.path}/cache');
  }

  /// Managed workspace roots: `<appData>/workspaces`.
  static Future<Directory> getWorkspacesDirectory() =>
      _ensureSubdir('workspaces');

  /// Per-conversation session roots: `<appData>/sessions`.
  static Future<Directory> getSessionsDirectory() => _ensureSubdir('sessions');

  /// Installed skill bodies: `<appData>/skills`.
  static Future<Directory> getSkillsDirectory() => _ensureSubdir('skills');
  /// Installed Plugin bundles kept inert until a later execution phase.
  static Future<Directory> getPluginsDirectory() => _ensureSubdir('plugins');

  /// Managed storage directory for one validated Plugin id.
  static Future<Directory> pluginDir(String pluginId) {
    if (pluginId.isEmpty || pluginId.length > 128) {
      throw const FormatException('plugin_id');
    }
    for (var index = 0; index < pluginId.length; index++) {
      final unit = pluginId.codeUnitAt(index);
      final isLower = unit >= 97 && unit <= 122;
      final isDigit = unit >= 48 && unit <= 57;
      final isPunctuation = unit == 45 || unit == 46 || unit == 95;
      if ((!isLower && !isDigit && !isPunctuation) ||
          (index == 0 && !isLower && !isDigit)) {
        throw const FormatException('plugin_id');
      }
    }
    return _ensurePath('plugins/' + pluginId);
  }

  /// Import provenance/manifests and repository-shared Skill resources. Kept
  /// outside the `/skills` PRoot bind mount; runtime access is not enabled by
  /// this storage location.
  static Future<Directory> getSkillImportMetadataDirectory() =>
      _ensureSubdir('skill-import-metadata');

  /// Private per-session directories for explicitly approved Skill MCP processes.
  /// These contain verified Skill copies, not the installed Skills tree.
  static Future<Directory> getSkillMcpSessionsDirectory() =>
      _ensureSubdir('skill-mcp-sessions');

  /// Bounded local audit records for explicitly approved Skill MCP tool calls.
  static Future<Directory> getSkillMcpAuditDirectory() =>
      _ensureSubdir('skill-mcp-audit');

  /// Sandbox environment install root: `<appData>/environment`.
  static Future<Directory> getEnvironmentDirectory() =>
      _ensureSubdir('environment');

  /// Files root for a managed workspace: `<appData>/workspaces/<id>/files`.
  static Future<Directory> workspaceFilesDir(String workspaceId) {
    return _ensurePath('workspaces/$workspaceId/files');
  }

  /// Private working tree for an unbound conversation. It is mounted at
  /// `/workspace` in that conversation's PRoot session and is kept separate
  /// from attachments, outputs, installed Skills, and user-selected projects.
  static Future<Directory> conversationWorkspaceFilesDir(
    String conversationId,
  ) => _ensurePath(
    'conversation-workspaces/${sha256.convert(utf8.encode(conversationId)).toString().substring(0, 24)}/files',
  );

  /// Session root for a conversation, with `attachments/` and `outputs/`.
  static Future<Directory> sessionDir(String conversationId) async {
    final dir = await _ensurePath('sessions/$conversationId');
    await Directory('${dir.path}/attachments').create(recursive: true);
    await Directory('${dir.path}/outputs').create(recursive: true);
    return dir;
  }

  /// Skill body directory: `<appData>/skills/<id>`.
  static Future<Directory> skillDir(String skillId) {
    return _ensurePath('skills/$skillId');
  }

  static Future<Directory> _ensureSubdir(String name) => _ensurePath(name);

  static Future<Directory> _ensurePath(String relativePath) async {
    final root = await getContentDirectory();
    final dir = Directory('${root.path}/$relativePath');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Gets the platform-provided application cache directory.
  ///
  /// Android's platform-provided application cache directory.
  static Future<Directory> getSystemCacheDirectory() async {
    return await getApplicationCacheDirectory();
  }

  /// Gets the directory for avatar cache files.
  static Future<Directory> getAvatarCacheDirectory() async {
    final root = await getContentDirectory();
    return Directory('${root.path}/cache/avatars');
  }

  /// Get file extension from MIME type
  static String extFromMime(String mime) {
    switch (mime.toLowerCase()) {
      case 'image/jpeg':
      case 'image/jpg':
        return 'jpg';
      case 'image/gif':
        return 'gif';
      case 'image/webp':
        return 'webp';
      default:
        return 'png';
    }
  }

  /// Save base64 image data to images directory.
  /// [prefix] is used for filename (e.g. 'img', 'mcp_img').
  /// Returns the saved file path, or null if failed.
  static Future<String?> saveBase64Image(
    String mime,
    String base64Data, {
    String prefix = 'img',
  }) async {
    try {
      final dir = await getImagesDirectory();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final cleaned = base64Data.replaceAll(RegExp(r'\s'), '');
      List<int> bytes;
      // Support both standard base64 and URL-safe base64
      if (cleaned.contains('-') || cleaned.contains('_')) {
        bytes = base64Url.decode(cleaned);
      } else {
        bytes = base64Decode(cleaned);
      }
      final ext = extFromMime(mime);
      final path =
          '${dir.path}/${prefix}_${DateTime.now().microsecondsSinceEpoch}.$ext';
      final file = File(path);
      await file.writeAsBytes(bytes, flush: true);
      return path;
    } catch (e) {
      debugPrint('Failed to save image: $e');
      return null;
    }
  }
}
