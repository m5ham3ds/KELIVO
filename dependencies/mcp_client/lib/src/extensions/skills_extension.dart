import '../client/client.dart';
import '../protocol/protocol.dart';

/// Host-side policy limits for one skills/list traversal and one Skill manifest.
final class McpSkillsLimits {
  const McpSkillsLimits({
    this.maxPages = 32,
    this.maxResourcesPerSkill = 512,
    this.maxBytesPerSkill = 16 * 1024 * 1024,
  });

  final int maxPages;
  final int maxResourcesPerSkill;
  final int maxBytesPerSkill;

  void validate() {
    if (maxPages < 1 || maxPages > 32) {
      throw ArgumentError.value(maxPages, 'maxPages', 'must be between 1 and 32');
    }
    if (maxResourcesPerSkill < 1 || maxResourcesPerSkill > 512) {
      throw ArgumentError.value(
        maxResourcesPerSkill,
        'maxResourcesPerSkill',
        'must be between 1 and 512',
      );
    }
    if (maxBytesPerSkill < 1 || maxBytesPerSkill > 16 * 1024 * 1024) {
      throw ArgumentError.value(
        maxBytesPerSkill,
        'maxBytesPerSkill',
        'must be between 1 byte and 16 MiB',
      );
    }
  }
}

/// Host-assigned identity for one Skill from one MCP server.
final class McpSkillIdentity {
  const McpSkillIdentity({
    required this.serverIdentity,
    required this.uri,
  });

  final String serverIdentity;
  final String uri;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is McpSkillIdentity &&
          serverIdentity == other.serverIdentity &&
          uri == other.uri;

  @override
  int get hashCode => Object.hash(serverIdentity, uri);
}

/// One file resource in a Skill's complete manifest.
final class McpSkillResource {
  McpSkillResource._({
    required this.uri,
    required this.digest,
    required this.size,
  });

  static final RegExp _digestPattern = RegExp(r'^sha256:[a-f0-9]{64}$');

  final String uri;
  final String digest;
  final int size;

  factory McpSkillResource.fromJson(Map<String, dynamic> json) {
    final rawUri = json['uri'];
    final rawDigest = json['digest'];
    final rawSize = json['size'];
    if (rawUri is! String || rawUri.trim().isEmpty) {
      throw const FormatException('skill_resource_uri_invalid');
    }
    _parseAbsoluteUri(rawUri, 'skill_resource_uri_invalid');
    if (rawDigest is! String || !_digestPattern.hasMatch(rawDigest)) {
      throw const FormatException('skill_resource_digest_invalid');
    }
    if (rawSize is! int || rawSize < 0) {
      throw const FormatException('skill_resource_size_invalid');
    }
    return McpSkillResource._(
      uri: rawUri,
      digest: rawDigest,
      size: rawSize,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'uri': uri,
        'digest': digest,
        'size': size,
      };
}

/// Typed metadata-only entry for an MCP-served Skill.
///
/// Parsing an entry never fetches any file. A dynamic resource set has no
/// stable digest manifest and therefore cannot be content-verified.
final class McpSkillEntry {
  McpSkillEntry._({
    required this.uri,
    required this.frontmatter,
    required this.resources,
    required this.isDynamic,
    required this.meta,
  });

  static final RegExp _namePattern = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');

  final String uri;
  final Map<String, dynamic> frontmatter;
  final List<McpSkillResource> resources;
  final bool isDynamic;
  final Map<String, dynamic>? meta;

  String get name => frontmatter['name']! as String;
  String get description => frontmatter['description']! as String;

  factory McpSkillEntry.fromJson(
    Map<String, dynamic> json, {
    McpSkillsLimits limits = const McpSkillsLimits(),
  }) {
    limits.validate();

    final rawUri = json['uri'];
    if (rawUri is! String || rawUri.trim().isEmpty) {
      throw const FormatException('skill_uri_invalid');
    }
    final skillUri = _parseSkillDocumentUri(rawUri);

    final rawFrontmatter = json['frontmatter'];
    if (rawFrontmatter is! Map ||
        rawFrontmatter.keys.any((key) => key is! String)) {
      throw const FormatException('skill_frontmatter_invalid');
    }
    final frontmatter = Map<String, dynamic>.unmodifiable(
      Map<String, dynamic>.from(rawFrontmatter),
    );
    final rawName = frontmatter['name'];
    final rawDescription = frontmatter['description'];
    if (rawName is! String ||
        rawName.isEmpty ||
        rawName.length > 64 ||
        !_namePattern.hasMatch(rawName)) {
      throw const FormatException('skill_frontmatter_name_invalid');
    }
    if (rawDescription is! String ||
        rawDescription.trim().isEmpty ||
        rawDescription.length > 1024) {
      throw const FormatException('skill_frontmatter_description_invalid');
    }
    if (rawName != skillUri.skillName) {
      throw const FormatException('skill_uri_name_mismatch');
    }

    final rawResources = json['resources'];
    final List<McpSkillResource> parsedResources;
    final bool isDynamic;
    if (rawResources == 'dynamic') {
      parsedResources = const <McpSkillResource>[];
      isDynamic = true;
    } else if (rawResources is List) {
      if (rawResources.length > limits.maxResourcesPerSkill) {
        throw const FormatException('skill_resource_count_limit_exceeded');
      }
      final resources = <McpSkillResource>[];
      final seenUris = <String>{};
      var totalBytes = 0;
      for (final rawResource in rawResources) {
        if (rawResource is! Map ||
            rawResource.keys.any((key) => key is! String)) {
          throw const FormatException('skill_resource_entry_invalid');
        }
        final resource = McpSkillResource.fromJson(
          Map<String, dynamic>.from(rawResource),
        );
        if (!seenUris.add(resource.uri)) {
          throw const FormatException('skill_resource_uri_duplicate');
        }
        if (resource.uri != rawUri &&
            !_isWithinSkillDirectory(skillUri.uri, resource.uri)) {
          throw const FormatException('skill_resource_outside_skill_directory');
        }
        totalBytes += resource.size;
        if (totalBytes > limits.maxBytesPerSkill) {
          throw const FormatException('skill_resource_total_size_limit_exceeded');
        }
        resources.add(resource);
      }
      if (!seenUris.contains(rawUri)) {
        throw const FormatException('skill_manifest_missing_skill_md');
      }
      parsedResources = List<McpSkillResource>.unmodifiable(resources);
      isDynamic = false;
    } else {
      throw const FormatException('skill_resources_invalid');
    }

    final rawMeta = json['_meta'];
    if (rawMeta != null &&
        (rawMeta is! Map || rawMeta.keys.any((key) => key is! String))) {
      throw const FormatException('skill_meta_invalid');
    }
    final meta = rawMeta is Map
        ? Map<String, dynamic>.unmodifiable(
            Map<String, dynamic>.from(rawMeta),
          )
        : null;

    return McpSkillEntry._(
      uri: rawUri,
      frontmatter: frontmatter,
      resources: parsedResources,
      isDynamic: isDynamic,
      meta: meta,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'uri': uri,
        'frontmatter': Map<String, dynamic>.from(frontmatter),
        'resources': isDynamic
            ? 'dynamic'
            : resources.map((resource) => resource.toJson()).toList(),
        if (meta != null) '_meta': Map<String, dynamic>.from(meta!),
      };
}

final class McpSkillsListResult {
  const McpSkillsListResult._({
    required this.skills,
    required this.ttlMs,
    required this.cacheScope,
    required this.pagesFetched,
    required this.paginationTruncated,
    required this.nextCursor,
  });

  final List<McpSkillEntry> skills;
  final int ttlMs;
  final String cacheScope;
  final int pagesFetched;

  /// True when the host page cap stopped traversal while a cursor remained.
  final bool paginationTruncated;
  final String? nextCursor;

  /// The extension allows empty or partial catalogues even after pagination
  /// ends. Exhaustion does not prove global absence.
  bool get listingMayBePartial => true;

  bool get reachedPaginationEnd => !paginationTruncated && nextCursor == null;
}

final class McpSkillsGetResult {
  const McpSkillsGetResult({
    required this.skill,
    required this.ttlMs,
    required this.cacheScope,
  });

  final McpSkillEntry skill;
  final int ttlMs;
  final String cacheScope;
}

/// Typed, capability-gated client for the MCP Skills extension.
///
/// It retrieves manifests only. It does not read Skill files, install or
/// activate Skills, or grant tool permissions.
final class McpSkillsExtension {
  McpSkillsExtension({
    required this.client,
    required String serverIdentity,
    this.limits = const McpSkillsLimits(),
  }) : serverIdentity = serverIdentity.trim() {
    if (this.serverIdentity.isEmpty ||
        this.serverIdentity.length > 256 ||
        this.serverIdentity.contains(RegExp(r'[\x00-\x1f]'))) {
      throw ArgumentError.value(
        serverIdentity,
        'serverIdentity',
        'must be a non-empty host-assigned label',
      );
    }
    limits.validate();
  }

  final Client client;
  final String serverIdentity;
  final McpSkillsLimits limits;

  Map<String, dynamic>? get _declaration {
    final capabilities = client.serverCapabilities;
    if (capabilities == null ||
        !capabilities.extensions.containsKey(McpProtocol.skillsExtensionId)) {
      return null;
    }
    final raw = capabilities.extensions[McpProtocol.skillsExtensionId];
    if (raw is! Map || raw.keys.any((key) => key is! String)) {
      throw const FormatException('skills_extension_capability_invalid');
    }
    return Map<String, dynamic>.from(raw);
  }

  bool get isSupported {
    if (client.serverCapabilities?.resources != true) return false;
    return _declaration != null;
  }

  /// Optional directory browsing is available only when the server explicitly
  /// advertises directoryRead=true. This adapter does not fetch files.
  bool get supportsDirectoryRead {
    final declaration = _declaration;
    if (declaration == null || client.serverCapabilities?.resources != true) {
      return false;
    }
    final value = declaration['directoryRead'];
    if (value != null && value is! bool) {
      throw const FormatException('skills_directory_read_capability_invalid');
    }
    return value == true;
  }

  McpSkillIdentity identityFor(McpSkillEntry skill) =>
      McpSkillIdentity(serverIdentity: serverIdentity, uri: skill.uri);

  void _requireSupported() {
    if (client.negotiatedProtocolVersion != McpProtocol.v2026_07_28) {
      throw StateError('skills_extension_requires_protocol_2026_07_28');
    }
    if (client.serverCapabilities?.resources != true) {
      throw StateError('skills_extension_requires_resources_capability');
    }
    if (_declaration == null) {
      throw UnsupportedError('server_did_not_advertise_skills_extension');
    }
  }

  static int _readTtl(Map<String, dynamic> result) {
    final ttl = result['ttlMs'];
    if (ttl is! int || ttl < 0) {
      throw const FormatException('skills_cache_ttl_invalid');
    }
    return ttl;
  }

  static String _readCacheScope(Map<String, dynamic> result) {
    final scope = result['cacheScope'];
    if (scope != 'public' && scope != 'private') {
      throw const FormatException('skills_cache_scope_invalid');
    }
    return scope as String;
  }

  static void _requireCompleteResult(Map<String, dynamic> result) {
    if (result['resultType'] != 'complete') {
      throw const FormatException('skills_result_type_invalid');
    }
  }

  /// Lists the server's paginated Skill catalog.
  ///
  /// Provide [cursor] to resume a result that reached [limits.maxPages]. Empty
  /// and partial catalogues are valid, so an empty result is not proof that
  /// no explicit Skill URI can be fetched with [getSkill].
  Future<McpSkillsListResult> listSkills({
    String? cursor,
    int? maxPages,
  }) async {
    _requireSupported();
    final pageLimit = maxPages ?? limits.maxPages;
    if (pageLimit < 1 || pageLimit > limits.maxPages) {
      throw ArgumentError.value(
        pageLimit,
        'maxPages',
        'must not exceed the configured page limit',
      );
    }
    if (cursor != null && cursor.isEmpty) {
      throw ArgumentError.value(cursor, 'cursor', 'must not be empty');
    }

    final skills = <McpSkillEntry>[];
    final seenSkillUris = <String>{};
    final requestedCursors = <String>{};
    var nextRequestCursor = cursor;
    String? nextCursor;
    var pagesFetched = 0;
    var ttlMs = 0;
    var hasPage = false;
    var cacheScope = 'public';
    var paginationTruncated = false;

    while (pagesFetched < pageLimit) {
      if (nextRequestCursor != null &&
          !requestedCursors.add(nextRequestCursor)) {
        throw const FormatException('skills_cursor_repeated');
      }
      final result = await client.requestExtension(
        extensionId: McpProtocol.skillsExtensionId,
        method: McpProtocol.methodListSkills,
        params: <String, dynamic>{
          if (nextRequestCursor != null) 'cursor': nextRequestCursor,
        },
      );
      _requireCompleteResult(result);
      final pageTtl = _readTtl(result);
      final pageScope = _readCacheScope(result);
      if (!hasPage || pageTtl < ttlMs) ttlMs = pageTtl;
      hasPage = true;
      if (pageScope == 'private') cacheScope = 'private';

      final rawSkills = result['skills'];
      if (rawSkills is! List) {
        throw const FormatException('skills_list_items_invalid');
      }
      for (final rawSkill in rawSkills) {
        if (rawSkill is! Map || rawSkill.keys.any((key) => key is! String)) {
          throw const FormatException('skills_list_entry_invalid');
        }
        final skill = McpSkillEntry.fromJson(
          Map<String, dynamic>.from(rawSkill),
          limits: limits,
        );
        if (!seenSkillUris.add(skill.uri)) {
          throw const FormatException('skills_list_uri_duplicate');
        }
        skills.add(skill);
      }
      pagesFetched++;

      final rawNextCursor = result['nextCursor'];
      if (rawNextCursor == null) {
        nextCursor = null;
        break;
      }
      if (rawNextCursor is! String || rawNextCursor.isEmpty) {
        throw const FormatException('skills_next_cursor_invalid');
      }
      if (requestedCursors.contains(rawNextCursor)) {
        throw const FormatException('skills_cursor_repeated');
      }
      nextCursor = rawNextCursor;
      if (pagesFetched >= pageLimit) {
        paginationTruncated = true;
        break;
      }
      nextRequestCursor = nextCursor;
    }

    return McpSkillsListResult._(
      skills: List<McpSkillEntry>.unmodifiable(skills),
      ttlMs: ttlMs,
      cacheScope: cacheScope,
      pagesFetched: pagesFetched,
      paginationTruncated: paginationTruncated,
      nextCursor: nextCursor,
    );
  }

  /// Reads a manifest for an explicit SKILL.md URI, even when absent from the
  /// server's current (possibly partial) skills/list result.
  Future<McpSkillsGetResult> getSkill({required String uri}) async {
    _requireSupported();
    _parseSkillDocumentUri(uri);
    final result = await client.requestExtension(
      extensionId: McpProtocol.skillsExtensionId,
      method: McpProtocol.methodGetSkill,
      params: <String, dynamic>{'uri': uri},
    );
    _requireCompleteResult(result);
    final rawSkill = result['skill'];
    if (rawSkill is! Map || rawSkill.keys.any((key) => key is! String)) {
      throw const FormatException('skills_get_entry_invalid');
    }
    final skill = McpSkillEntry.fromJson(
      Map<String, dynamic>.from(rawSkill),
      limits: limits,
    );
    if (skill.uri != uri) {
      throw const FormatException('skills_get_uri_mismatch');
    }
    return McpSkillsGetResult(
      skill: skill,
      ttlMs: _readTtl(result),
      cacheScope: _readCacheScope(result),
    );
  }
}

({Uri uri, String skillName}) _parseSkillDocumentUri(String value) {
  final uri = _parseAbsoluteUri(value, 'skill_uri_invalid');
  if (uri.pathSegments.isEmpty || uri.pathSegments.last != 'SKILL.md') {
    throw const FormatException('skill_uri_must_end_in_skill_md');
  }
  if (uri.pathSegments.any(_isUnsafePathSegment)) {
    throw const FormatException('skill_uri_path_invalid');
  }

  // On the skill:// scheme the authority is the first skill-path segment.
  // Other schemes encode the full skill path in pathSegments.
  final String? skillName;
  if (uri.scheme == 'skill' && uri.pathSegments.length == 1) {
    skillName = uri.host;
  } else if (uri.pathSegments.length >= 2) {
    skillName = uri.pathSegments[uri.pathSegments.length - 2];
  } else {
    skillName = null;
  }
  if (skillName == null || skillName.isEmpty) {
    throw const FormatException('skill_uri_name_missing');
  }
  return (uri: uri, skillName: skillName);
}

Uri _parseAbsoluteUri(String value, String errorCode) {
  if (value.trim() != value) {
    throw FormatException(errorCode);
  }
  final schemeSeparator = value.indexOf(':');
  if (schemeSeparator < 1) throw FormatException(errorCode);
  var rawPath = value.substring(schemeSeparator + 1);
  if (rawPath.startsWith('//')) {
    final authorityEnd = rawPath.indexOf('/', 2);
    rawPath = authorityEnd < 0 ? '' : rawPath.substring(authorityEnd);
  }
  final queryIndex = rawPath.indexOf('?');
  if (queryIndex >= 0) rawPath = rawPath.substring(0, queryIndex);
  final fragmentIndex = rawPath.indexOf('#');
  if (fragmentIndex >= 0) rawPath = rawPath.substring(0, fragmentIndex);

  final traversalPattern = RegExp(
    r'(?:^|/)(?:[.]|%2e){1,2}(?:/|$)',
    caseSensitive: false,
  );
  final encodedSeparatorPattern = RegExp(
    r'%(?:2f|5c)',
    caseSensitive: false,
  );
  if (traversalPattern.hasMatch(rawPath) ||
      encodedSeparatorPattern.hasMatch(rawPath) ||
      rawPath.contains(String.fromCharCode(92))) {
    throw FormatException(errorCode);
  }

  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme) {
    throw FormatException(errorCode);
  }
  return uri;
}

bool _isUnsafePathSegment(String segment) =>
    segment == '.' ||
    segment == '..' ||
    segment.contains('/') ||
    segment.contains(String.fromCharCode(92)) ||
    segment.contains(RegExp(r'[\x00-\x1f]'));

bool _isWithinSkillDirectory(Uri skillUri, String resourceValue) {
  final resource = _parseAbsoluteUri(
    resourceValue,
    'skill_resource_uri_invalid',
  );
  if (resource.scheme != skillUri.scheme ||
      resource.authority != skillUri.authority) {
    return false;
  }
  final rootSegments = skillUri.pathSegments
      .where((segment) => segment.isNotEmpty)
      .take(skillUri.pathSegments.length - 1)
      .toList();
  final resourceSegments = resource.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList();
  if (rootSegments.any(_isUnsafePathSegment) ||
      resourceSegments.any(_isUnsafePathSegment)) {
    return false;
  }
  if (resourceSegments.length <= rootSegments.length) return false;
  for (var index = 0; index < rootSegments.length; index++) {
    if (resourceSegments[index] != rootSegments[index]) return false;
  }
  return true;
}
