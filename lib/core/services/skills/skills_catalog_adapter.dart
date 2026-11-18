import 'dart:convert';

import 'package:http/http.dart' as http;

import 'skill_archive.dart';

class SkillCatalogEntry {
  const SkillCatalogEntry({
    required this.id,
    required this.name,
    required this.description,
    required this.source,
    required this.installUrl,
    required this.installs,
    required this.url,
  });

  final String id;
  final String name;
  final String description;
  final String source;
  final String? installUrl;
  final int installs;
  final String? url;
}

class SkillCatalogPackage {
  const SkillCatalogPackage({
    required this.id,
    required this.files,
    this.hash,
    this.sourceUrl,
    this.repository,
    this.slug,
    this.unsupportedPaths = const <String>[],
    this.notes = const <String>[],
  });

  final String id;
  final Map<String, List<int>> files;
  final String? hash;
  final String? sourceUrl;
  final String? repository;
  final String? slug;
  final List<String> unsupportedPaths;
  final List<String> notes;
  bool get hasTextSnapshot => files.containsKey('SKILL.md');
  bool get transportComplete => unsupportedPaths.isEmpty && notes.isEmpty;
}

/// Generic adapter boundary so the application is not coupled to skills.sh.
abstract interface class SkillsCatalogAdapter {
  Future<List<SkillCatalogEntry>> search(String query, {int limit = 10});
  Future<SkillCatalogPackage> resolve(String id);
}

/// Public skills.sh API adapter. This only downloads Skill files; it never
/// invokes scripts or package-manager commands included in the file tree.
class SkillsShAdapter implements SkillsCatalogAdapter {
  SkillsShAdapter(this._client);

  final http.Client _client;
  static const _baseHeaders = <String, String>{
    'User-Agent': 'Kelivo-Skills-Adapter',
    'Accept': 'application/json',
  };
  static const int _maxResponseBytes = 24 * 1024 * 1024;
  static const int _maxFiles = 2048;

  @override
  Future<List<SkillCatalogEntry>> search(
    String query, {
    int limit = 10,
  }) async {
    final value = query.trim();
    if (value.length < 2 || value.length > 160) {
      throw const FormatException('invalid_skills_catalog_query');
    }
    final uri = Uri.https('skills.sh', '/api/v1/skills/search', {
      'q': value,
      'limit': '${limit.clamp(1, 30)}',
    });
    final response = await _client.get(uri, headers: _baseHeaders);
    final decoded = _decodeResponse(response, uri);
    final data = decoded['data'];
    if (data is! List) {
      throw const FormatException('invalid_skills_catalog_search_response');
    }
    final entries = <SkillCatalogEntry>[];
    for (final item in data.whereType<Map>()) {
      final id = item['id']?.toString() ?? '';
      if (!_isValidId(id)) continue;
      final sourceType = item['sourceType']?.toString();
      // Well-known sources are informational only until a dedicated adapter
      // for their /.well-known/ installation format is implemented.
      if (sourceType != 'github') continue;
      entries.add(
        SkillCatalogEntry(
          id: id,
          name: item['name']?.toString() ?? item['slug']?.toString() ?? id,
          description: item['description']?.toString() ?? '',
          source: item['source']?.toString() ?? '',
          installUrl: _httpsUrl(item['installUrl']),
          installs: (item['installs'] as num?)?.toInt() ?? 0,
          url: _httpsUrl(item['url']),
        ),
      );
    }
    return List.unmodifiable(entries);
  }

  @override
  Future<SkillCatalogPackage> resolve(String id) async {
    final segments = id.split('/');
    if (!_isValidId(id)) {
      throw const FormatException('invalid_skills_catalog_id');
    }
    final uri = Uri(
      scheme: 'https',
      host: 'skills.sh',
      pathSegments: <String>['api', 'v1', 'skills', ...segments],
    );
    final response = await _client.get(uri, headers: _baseHeaders);
    final decoded = _decodeResponse(response, uri);
    final responseId = decoded['id']?.toString();
    if (responseId != null && responseId != id) {
      throw const FormatException('skills_catalog_id_mismatch');
    }
    final sourceType = decoded['sourceType']?.toString();
    if (sourceType != null && sourceType != 'github') {
      throw const FormatException('unsupported_skills_catalog_source_type');
    }
    final rawFiles = decoded['files'];
    if (rawFiles is List && rawFiles.length > _maxFiles) {
      throw const FormatException('skills_catalog_file_limit');
    }
    final files = <String, List<int>>{};
    final unsupported = <String>[];
    final notes = <String>[];
    var total = 0;
    if (rawFiles is List) {
      for (var index = 0; index < rawFiles.length; index++) {
        final item = rawFiles[index];
        if (item is! Map) {
          unsupported.add('entry-$index');
          continue;
        }
        final rawPath = item['path'];
        if (rawPath is! String) {
          unsupported.add('entry-$index');
          continue;
        }
        final normalized = safeZipEntryName(rawPath);
        if (normalized == null || normalized != rawPath.replaceAll('\\', '/')) {
          throw const FormatException('unsafe_skills_catalog_file_path');
        }
        if (files.containsKey(normalized)) {
          throw const FormatException('duplicate_skills_catalog_file_path');
        }
        final contents = item['contents'];
        if (contents is! String) {
          unsupported.add(normalized);
          continue;
        }
        final bytes = utf8.encode(contents);
        total += bytes.length;
        if (total > _maxResponseBytes) {
          throw const FormatException('skills_catalog_package_too_large');
        }
        files[normalized] = bytes;
      }
      if (unsupported.isNotEmpty) {
        notes.add('skills_sh_api_text_contents_only; GitHub archive fallback required');
      }
    } else {
      notes.add('skills_sh_api_snapshot_unavailable; GitHub archive fallback required');
    }
    if (!files.containsKey('SKILL.md')) {
      notes.add('skills_sh_snapshot_does_not_contain_SKILL.md');
    }
    return SkillCatalogPackage(
      id: id,
      files: Map.unmodifiable(files),
      hash: decoded['hash']?.toString(),
      sourceUrl: Uri.https('skills.sh', '/$id').toString(),
      repository: '${segments[0]}/${segments[1]}',
      slug: segments[2],
      unsupportedPaths: List.unmodifiable(unsupported),
      notes: List.unmodifiable(notes),
    );
  }

  Map<String, dynamic> _decodeResponse(http.Response response, Uri uri) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Skills catalog request failed (${response.statusCode})',
        uri,
      );
    }
    if (response.bodyBytes.length > _maxResponseBytes) {
      throw const FormatException('skills_catalog_response_too_large');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) {
      throw const FormatException('invalid_skills_catalog_response');
    }
    return Map<String, dynamic>.from(decoded);
  }

  static bool _isValidId(String id) {
    final segments = id.split('/');
    return segments.length == 3 &&
        segments.every(
          (segment) =>
              segment.isNotEmpty &&
              segment != '.' &&
              segment != '..' &&
              RegExp(r'^[A-Za-z0-9_.-]{1,100}$').hasMatch(segment),
        );
  }

  static String? _httpsUrl(Object? value) {
    final text = value?.toString();
    if (text == null || text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri.toString();
  }
}
