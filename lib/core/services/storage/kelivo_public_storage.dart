import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class KelivoPublicFolder {
  const KelivoPublicFolder({
    required this.uri,
    required this.name,
    required this.accessible,
  });

  final String uri;
  final String name;
  final bool accessible;
}

/// User-visible storage picked through Android's Storage Access Framework.
/// The retained URI is never treated as a filesystem path or mounted into
/// PRoot; files are copied into private Workspaces before execution and
/// validated output files are copied back through the native document API.
class KelivoPublicStorageService {
  KelivoPublicStorageService({
    MethodChannel? channel,
    Future<SharedPreferences> Function()? preferences,
  }) : _channel = channel ?? const MethodChannel('app.kelivo/public_storage'),
       _preferences = preferences ?? SharedPreferences.getInstance;

  static const String _uriKey = 'kelivo_public_storage_tree_uri_v1';
  static const String _nameKey = 'kelivo_public_storage_tree_name_v1';
  static const List<String> standardFolders = <String>[
    'Projects',
    'Results',
    'Downloads',
    'Skills-Exports',
    'Reports',
    'Backups',
  ];

  final MethodChannel _channel;
  final Future<SharedPreferences> Function() _preferences;

  bool get isSupported => !kIsWeb && Platform.isAndroid;

  Future<KelivoPublicFolder?> currentFolder({bool verifyAccess = true}) async {
    if (!isSupported) return null;
    final prefs = await _preferences();
    final uri = prefs.getString(_uriKey);
    if (uri == null || uri.isEmpty) return null;
    final savedName = prefs.getString(_nameKey) ?? 'KELIVO';
    if (!verifyAccess) {
      return KelivoPublicFolder(uri: uri, name: savedName, accessible: true);
    }
    try {
      final info = await _channel.invokeMapMethod<String, Object?>(
        'getFolderInfo',
        <String, Object?>{'uri': uri},
      );
      return KelivoPublicFolder(
        uri: uri,
        name: (info?['name'] as String?)?.trim().isNotEmpty == true
            ? (info!['name'] as String)
            : savedName,
        accessible: info?['accessible'] == true,
      );
    } on PlatformException {
      return KelivoPublicFolder(uri: uri, name: savedName, accessible: false);
    } on MissingPluginException {
      return KelivoPublicFolder(uri: uri, name: savedName, accessible: false);
    }
  }

  Future<KelivoPublicFolder?> chooseFolder() async {
    if (!isSupported) {
      throw UnsupportedError('The KELIVO public folder is currently supported on Android only.');
    }
    final previous = await currentFolder(verifyAccess: false);
    final selected = await _channel.invokeMapMethod<String, Object?>('selectFolder');
    if (selected == null) return null;
    final uri = (selected['uri'] as String?)?.trim() ?? '';
    final name = (selected['name'] as String?)?.trim() ?? 'KELIVO';
    if (uri.isEmpty) throw const FormatException('The selected folder did not return a URI.');

    try {
      await _channel.invokeMethod<Object?>(
        'ensureStructure',
        <String, Object?>{'uri': uri},
      );
      final prefs = await _preferences();
      await prefs.setString(_uriKey, uri);
      await prefs.setString(_nameKey, name);
    } catch (_) {
      if (previous?.uri != uri) {
        try {
          await _channel.invokeMethod<void>(
            'releaseFolder',
            <String, Object?>{'uri': uri},
          );
        } catch (_) {}
      }
      rethrow;
    }
    if (previous != null && previous.uri != uri) {
      try {
        await _channel.invokeMethod<void>(
          'releaseFolder',
          <String, Object?>{'uri': previous.uri},
        );
      } catch (_) {
        // The new permission is already persisted. A stale old grant is harmless.
      }
    }
    return KelivoPublicFolder(uri: uri, name: name, accessible: true);
  }

  /// Returns null when the user has not configured a public folder.
  Future<Map<String, Object?>?> exportFile({
    required String sourcePath,
    required String relativePath,
    bool overwrite = true,
  }) async {
    if (!isSupported) return null;
    final folder = await currentFolder();
    if (folder == null) return null;
    if (!folder.accessible) {
      throw FileSystemException('The saved KELIVO folder permission was revoked. Select the folder again.');
    }
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('The private source file no longer exists.', sourcePath);
    }
    final result = await _channel.invokeMapMethod<String, Object?>(
      'exportFile',
      <String, Object?>{
        'uri': folder.uri,
        'sourcePath': source.path,
        'relativePath': relativePath,
        'overwrite': overwrite,
      },
    );
    return result == null ? null : Map<String, Object?>.from(result);
  }

  Future<void> forgetFolder() async {
    final prefs = await _preferences();
    final uri = prefs.getString(_uriKey);
    if (uri != null && uri.isNotEmpty && isSupported) {
      try {
        await _channel.invokeMethod<void>(
          'releaseFolder',
          <String, Object?>{'uri': uri},
        );
      } catch (_) {}
    }
    await prefs.remove(_uriKey);
    await prefs.remove(_nameKey);
  }
}
