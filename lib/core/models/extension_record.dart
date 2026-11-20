import 'dart:convert';

/// Lifecycle states shared by installable Skills, Engines, Tools, Providers,
/// Workflows and Assets. A status describes the extension package, not whether
/// its code is currently executing.
enum ExtensionLifecycleStatus {
  discovered,
  downloaded,
  validated,
  installed,
  enabled,
  disabled,
  incompatible,
  updateAvailable,
  failed;

  String get wireValue => switch (this) {
    ExtensionLifecycleStatus.updateAvailable => 'update_available',
    _ => name,
  };

  static ExtensionLifecycleStatus parse(Object? value) {
    if (value is String) {
      for (final status in values) {
        if (status.wireValue == value || status.name == value) return status;
      }
    }
    throw const FormatException('extension_status');
  }
}

/// Provenance information for an extension. Credentials must never be stored
/// here; authenticated downloads belong to the protected credential store.
final class ExtensionSource {
  const ExtensionSource({
    required this.type,
    this.uri,
    this.ref,
    this.subpath,
    this.revision,
  });

  final String type;
  final String? uri;
  final String? ref;
  final String? subpath;
  final String? revision;

  Map<String, Object?> toJson() => {
    'type': type,
    if (uri != null) 'uri': uri,
    if (ref != null) 'ref': ref,
    if (subpath != null) 'subpath': subpath,
    if (revision != null) 'revision': revision,
  };

  factory ExtensionSource.fromJson(Object? value) {
    if (value is! Map) throw const FormatException('extension_source');
    final map = Map<String, Object?>.from(value);
    // Normalize the enum's camelCase value written by older builds.
    final rawType = map['type'];
    final type = rawType == 'skillsSh' ? 'skills_sh' : rawType;
    if (type is! String || !_tokenPattern.hasMatch(type)) {
      throw const FormatException('extension_source_type');
    }
    String? optionalString(String key) {
      final item = map[key];
      if (item == null) return null;
      if (item is! String || item.length > 2048) {
        throw FormatException('extension_source_$key');
      }
      return item;
    }

    final source = ExtensionSource(
      type: type,
      uri: optionalString('uri'),
      ref: optionalString('ref'),
      subpath: optionalString('subpath'),
      revision: optionalString('revision'),
    );
    source.validate();
    return source;
  }

  void validate() {
    if (!_tokenPattern.hasMatch(type)) {
      throw const FormatException('extension_source_type');
    }
    if (uri != null) {
      if (uri!.isEmpty || uri!.length > 2048 || _hasControlCharacter(uri!)) {
        throw const FormatException('extension_source_uri');
      }
      final parsed = Uri.tryParse(uri!);
      if (parsed == null || parsed.userInfo.isNotEmpty) {
        throw const FormatException('extension_source_uri');
      }
      if ((parsed.scheme == 'http' || parsed.scheme == 'https') &&
          parsed.host.isEmpty) {
        throw const FormatException('extension_source_uri');
      }
      final decodedFragment = Uri.decodeComponent(parsed.fragment);
      if (parsed.queryParameters.keys.any(_sensitiveKeyPattern.hasMatch) ||
          _sensitiveKeyPattern.hasMatch(decodedFragment)) {
        throw const FormatException('extension_source_embedded_secret');
      }
    }
    for (final value in [ref, revision]) {
      if (value != null &&
          (value.length > 2048 || _hasControlCharacter(value))) {
        throw const FormatException('extension_source_reference');
      }
    }
    if (subpath != null && !_isSafeRelativePath(subpath!)) {
      throw const FormatException('extension_source_subpath');
    }
  }
}

/// Versioned, serializable metadata for any user-installed extension.
///
/// This record intentionally contains metadata only. It must not contain API
/// keys, OAuth tokens, passwords, private keys, or other credentials.
final class ExtensionRecord {
  ExtensionRecord({
    required this.id,
    required this.kind,
    required this.name,
    required this.source,
    required this.status,
    required this.updatedAt,
    this.version,
    this.digest,
    this.compatibility = const <String, Object?>{},
    this.permissions = const <String>[],
    this.entryPoint,
    this.installedAt,
    this.lastErrorCode,
    this.metadata = const <String, Object?>{},
    this.schemaVersion = currentSchemaVersion,
  });

  static const int currentSchemaVersion = 1;
  static final RegExp _idPattern = RegExp(r'^[a-z0-9][a-z0-9._-]{0,127}$');
  static final RegExp _kindPattern = RegExp(r'^[a-z][a-z0-9_-]{0,31}$');
  static final RegExp _digestPattern = RegExp(r'^(sha256:)?[0-9a-fA-F]{64}$');

  final String id;
  final String kind;
  final String name;
  final ExtensionSource source;
  final ExtensionLifecycleStatus status;
  final DateTime updatedAt;
  final String? version;
  final String? digest;
  final Map<String, Object?> compatibility;
  final List<String> permissions;
  final String? entryPoint;
  final DateTime? installedAt;
  final String? lastErrorCode;
  final Map<String, Object?> metadata;
  final int schemaVersion;

  /// The backing table is keyed by (storage kind, id). Prefixing the id with
  /// the extension kind allows `skill/foo` and `engine/foo` to coexist.
  String get storageId => '$kind::$id';

  void validate() {
    if (schemaVersion != currentSchemaVersion) {
      throw const FormatException('extension_schema_version');
    }
    if (!_idPattern.hasMatch(id)) throw const FormatException('extension_id');
    if (!_kindPattern.hasMatch(kind)) {
      throw const FormatException('extension_kind');
    }
    if (name.trim().isEmpty || name.length > 160) {
      throw const FormatException('extension_name');
    }
    if (version != null && version!.length > 128) {
      throw const FormatException('extension_version');
    }
    source.validate();
    if (digest != null && !_digestPattern.hasMatch(digest!)) {
      throw const FormatException('extension_digest');
    }
    if (entryPoint != null && !_isSafeRelativePath(entryPoint!)) {
      throw const FormatException('extension_entry_point');
    }
    if (lastErrorCode != null &&
        !RegExp(r'^[a-z0-9][a-z0-9_.-]{0,79}$').hasMatch(lastErrorCode!)) {
      throw const FormatException('extension_error_code');
    }
    if (permissions.length > 128 ||
        permissions.any(
          (permission) =>
              !RegExp(r'^[a-z][a-z0-9._-]{0,63}$').hasMatch(permission),
        )) {
      throw const FormatException('extension_permissions');
    }
    _validateSafeJsonMap(compatibility, 'extension_compatibility');
    _validateSafeJsonMap(metadata, 'extension_metadata');
  }

  Map<String, Object?> toJson() {
    validate();
    return {
      'schemaVersion': schemaVersion,
      'id': id,
      'kind': kind,
      'name': name,
      'source': source.toJson(),
      'status': status.wireValue,
      if (version != null) 'version': version,
      if (digest != null) 'digest': digest,
      'compatibility': compatibility,
      'permissions': permissions,
      if (entryPoint != null) 'entryPoint': entryPoint,
      if (installedAt != null) 'installedAt': installedAt!.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      if (lastErrorCode != null) 'lastErrorCode': lastErrorCode,
      'metadata': metadata,
    };
  }

  factory ExtensionRecord.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'];
    final id = json['id'];
    final kind = json['kind'];
    final name = json['name'];
    final updatedAt = json['updatedAt'];
    if (schemaVersion is! int ||
        id is! String ||
        kind is! String ||
        name is! String ||
        updatedAt is! String) {
      throw const FormatException('extension_record');
    }
    Map<String, Object?> readMap(String key) {
      final value = json[key];
      if (value == null) return const <String, Object?>{};
      if (value is! Map) throw FormatException('extension_$key');
      return Map<String, Object?>.from(value);
    }

    List<String> readStrings(String key) {
      final value = json[key];
      if (value == null) return const <String>[];
      if (value is! List || value.any((item) => item is! String)) {
        throw FormatException('extension_$key');
      }
      return value.cast<String>();
    }

    DateTime? optionalDate(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! String) throw FormatException('extension_$key');
      return DateTime.parse(value).toUtc();
    }

    final record = ExtensionRecord(
      schemaVersion: schemaVersion,
      id: id,
      kind: kind,
      name: name,
      source: ExtensionSource.fromJson(json['source']),
      status: ExtensionLifecycleStatus.parse(json['status']),
      version: json['version'] as String?,
      digest: json['digest'] as String?,
      compatibility: readMap('compatibility'),
      permissions: readStrings('permissions'),
      entryPoint: json['entryPoint'] as String?,
      installedAt: optionalDate('installedAt'),
      updatedAt: DateTime.parse(updatedAt).toUtc(),
      lastErrorCode: json['lastErrorCode'] as String?,
      metadata: readMap('metadata'),
    );
    record.validate();
    return record;
  }

  ExtensionRecord copyWith({
    String? name,
    ExtensionSource? source,
    ExtensionLifecycleStatus? status,
    DateTime? updatedAt,
    String? version,
    String? digest,
    Map<String, Object?>? compatibility,
    List<String>? permissions,
    String? entryPoint,
    DateTime? installedAt,
    String? lastErrorCode,
    bool clearLastError = false,
    Map<String, Object?>? metadata,
  }) => ExtensionRecord(
    schemaVersion: schemaVersion,
    id: id,
    kind: kind,
    name: name ?? this.name,
    source: source ?? this.source,
    status: status ?? this.status,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version ?? this.version,
    digest: digest ?? this.digest,
    compatibility: compatibility ?? this.compatibility,
    permissions: permissions ?? this.permissions,
    entryPoint: entryPoint ?? this.entryPoint,
    installedAt: installedAt ?? this.installedAt,
    lastErrorCode: clearLastError
        ? null
        : (lastErrorCode ?? this.lastErrorCode),
    metadata: metadata ?? this.metadata,
  );

  static void _validateSafeJsonMap(
    Map<String, Object?> value,
    String errorCode,
  ) {
    void visit(Object? current, int depth) {
      if (depth > 16) throw FormatException('${errorCode}_too_deep');
      if (current is Map) {
        if (current.length > 2048) {
          throw FormatException('${errorCode}_too_many_fields');
        }
        for (final entry in current.entries) {
          final key = entry.key.toString();
          if (_sensitiveKeyPattern.hasMatch(key)) {
            throw FormatException('${errorCode}_secret_field');
          }
          visit(entry.value, depth + 1);
        }
      } else if (current is Iterable) {
        var count = 0;
        for (final item in current) {
          if (++count > 2048) {
            throw FormatException('${errorCode}_too_many_items');
          }
          visit(item, depth + 1);
        }
      }
    }

    visit(value, 0);
    late final String encoded;
    try {
      encoded = jsonEncode(value);
    } catch (_) {
      throw FormatException(errorCode);
    }
    if (utf8.encode(encoded).length > 64 * 1024) {
      throw FormatException('${errorCode}_too_large');
    }
  }
}

final RegExp _tokenPattern = RegExp(r'^[a-z][a-z0-9_-]{0,31}$');
final RegExp _sensitiveKeyPattern = RegExp(
  r'(api[_-]?key|access[_-]?token|refresh[_-]?token|token|credential|'
  r'password|secret|private[_-]?key|authorization|\bauth\b)',
  caseSensitive: false,
);

bool _isSafeRelativePath(String value) {
  final decoded = Uri.decodeComponent(value);
  if (decoded.isEmpty ||
      decoded.startsWith('/') ||
      decoded.contains('\\') ||
      decoded.contains(':') ||
      _hasControlCharacter(decoded)) {
    return false;
  }
  final segments = decoded.split('/');
  return segments.every(
    (segment) => segment.isNotEmpty && segment != '.' && segment != '..',
  );
}

bool _hasControlCharacter(String value) =>
    value.codeUnits.any((unit) => unit < 0x20 || unit == 0x7f);
