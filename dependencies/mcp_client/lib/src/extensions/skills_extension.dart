import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:yaml/yaml.dart';

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
/// A point-in-time Skill manifest bound to the host-assigned server identity.
final class McpSkillSnapshot {
  const McpSkillSnapshot._({
    required this.identity,
    required this.skill,
    required this.ttlMs,
    required this.cacheScope,
    required this.retrievedAt,
    required this.generation,
    required this.resourceSetKey,
  });

  final McpSkillIdentity identity;
  final McpSkillEntry skill;
  final int ttlMs;
  final String cacheScope;
  final DateTime retrievedAt;
  final int generation;

  /// Stable fingerprint of every URI, digest and size in the complete manifest.
  final String resourceSetKey;
}

/// Content that has passed the declared size and SHA-256 checks.
final class McpVerifiedSkillResource {
  const McpVerifiedSkillResource._({
    required this.snapshot,
    required this.uri,
    required this.digest,
    required this.size,
    required this.mimeType,
    required this.bytes,
    required this.cacheScope,
    required this.fromCache,
  });

  final McpSkillSnapshot snapshot;
  final String uri;
  final String digest;
  final int size;
  final String? mimeType;
  final List<int> bytes;
  final String cacheScope;
  final bool fromCache;

  String get text => utf8.decode(bytes, allowMalformed: false);

  McpVerifiedSkillResource _asCacheHit() => McpVerifiedSkillResource._(
        snapshot: snapshot,
        uri: uri,
        digest: digest,
        size: size,
        mimeType: mimeType,
        bytes: bytes,
        cacheScope: cacheScope,
        fromCache: true,
      );
}

/// Host-side integrity failure. The unverified bytes are never returned.
final class McpSkillIntegrityException implements Exception {
  const McpSkillIntegrityException(this.code, this.uri);

  final String code;
  final String uri;

  @override
  String toString() => 'McpSkillIntegrityException($code, $uri)';
}

final class _McpCachedSkillResource {
  const _McpCachedSkillResource({
    required this.identity,
    required this.content,
    required this.expiresAt,
  });

  final McpSkillIdentity identity;
  final McpVerifiedSkillResource content;
  final DateTime expiresAt;
}

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
    required this.snapshots,
    required this.ttlMs,
    required this.cacheScope,
    required this.pagesFetched,
    required this.paginationTruncated,
    required this.nextCursor,
  });

  final List<McpSkillEntry> skills;
  final List<McpSkillSnapshot> snapshots;
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
    required this.snapshot,
    required this.ttlMs,
    required this.cacheScope,
  });

  final McpSkillEntry skill;
  final McpSkillSnapshot snapshot;
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
    DateTime Function()? clock,
  }) : serverIdentity = serverIdentity.trim(),
       _clock = clock ?? DateTime.now {
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
    _resourcesListChangedSubscription =
        client.onResourcesListChangedStream.listen((_) => invalidateAll());
    _disconnectSubscription =
        client.onDisconnect.listen((_) => invalidateAll());
  }

  final Client client;
  final String serverIdentity;
  final McpSkillsLimits limits;
  final DateTime Function() _clock;
  late final StreamSubscription<void> _resourcesListChangedSubscription;
  late final StreamSubscription<dynamic> _disconnectSubscription;
  final Map<String, _McpCachedSkillResource> _resourceCache =
      <String, _McpCachedSkillResource>{};
  final Map<String, String> _latestManifestKeys = <String, String>{};
  int _cacheGeneration = 0;
  bool _disposed = false;

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

  String _identityKey(McpSkillIdentity identity) =>
      jsonEncode(<String>[identity.serverIdentity, identity.uri]);

  String _resourceSetFingerprint(McpSkillEntry skill) {
    if (skill.isDynamic) return 'dynamic';
    final entries = skill.resources
        .map((resource) => <String, dynamic>{
              'uri': resource.uri,
              'digest': resource.digest,
              'size': resource.size,
            })
        .toList()
      ..sort(
        (left, right) =>
            (left['uri'] as String).compareTo(right['uri'] as String),
      );
    return sha256.convert(utf8.encode(jsonEncode(entries))).toString();
  }

  McpSkillSnapshot _createSnapshot(
    McpSkillEntry skill, {
    required int ttlMs,
    required String cacheScope,
  }) {
    final identity = identityFor(skill);
    final resourceSetKey = _resourceSetFingerprint(skill);
    final identityKey = _identityKey(identity);
    final previous = _latestManifestKeys[identityKey];
    if (previous != null && previous != resourceSetKey) {
      _resourceCache.removeWhere(
        (key, cached) => cached.identity == identity,
      );
    }
    _latestManifestKeys[identityKey] = resourceSetKey;
    return McpSkillSnapshot._(
      identity: identity,
      skill: skill,
      ttlMs: ttlMs,
      cacheScope: cacheScope,
      retrievedAt: _clock(),
      generation: _cacheGeneration,
      resourceSetKey: resourceSetKey,
    );
  }

  /// Drop every verified byte cache after a source/list change.
  ///
  /// Existing snapshots become unusable and must be refreshed with skills/get
  /// or skills/list before a subsequent resource read.
  void invalidateAll() {
    _cacheGeneration++;
    _resourceCache.clear();
    _latestManifestKeys.clear();
  }

  /// Release notification subscriptions and in-memory verified content.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _resourcesListChangedSubscription.cancel();
    await _disconnectSubscription.cancel();
    invalidateAll();
  }

  void _requireSnapshotCurrent(McpSkillSnapshot snapshot) {
    if (_disposed) throw StateError('skills_extension_disposed');
    if (snapshot.identity.serverIdentity != serverIdentity ||
        snapshot.identity.uri != snapshot.skill.uri) {
      throw const McpSkillIntegrityException(
        'skill_snapshot_origin_mismatch',
        '',
      );
    }
    if (snapshot.generation != _cacheGeneration) {
      throw McpSkillIntegrityException(
        'skill_snapshot_invalidated_refresh_required',
        snapshot.skill.uri,
      );
    }
    final currentKey = _latestManifestKeys[_identityKey(snapshot.identity)];
    if (currentKey != null && currentKey != snapshot.resourceSetKey) {
      throw McpSkillIntegrityException(
        'skill_manifest_changed_refresh_required',
        snapshot.skill.uri,
      );
    }
    if (snapshot.ttlMs > 0 &&
        !_clock().isBefore(
          snapshot.retrievedAt.add(Duration(milliseconds: snapshot.ttlMs)),
        )) {
      throw McpSkillIntegrityException(
        'skill_manifest_expired_refresh_required',
        snapshot.skill.uri,
      );
    }
  }

  /// Fetch one declared file only when requested, then verify its raw bytes.
  ///
  /// This method never loads or activates the Skill. It returns immutable
  /// verified bytes, with origin identity retained for the caller.
  Future<McpVerifiedSkillResource> readSkillResource({
    required McpSkillSnapshot snapshot,
    required String uri,
  }) async {
    _requireSupported();
    _requireSnapshotCurrent(snapshot);
    if (snapshot.skill.isDynamic) {
      throw McpSkillIntegrityException(
        'dynamic_skill_resources_are_unverifiable',
        uri,
      );
    }

    McpSkillResource declared;
    try {
      declared = snapshot.skill.resources.firstWhere(
        (resource) => resource.uri == uri,
      );
    } on StateError {
      throw McpSkillIntegrityException(
        'skill_resource_not_in_held_manifest',
        uri,
      );
    }

    final cacheKey = jsonEncode(<String>[
      snapshot.identity.serverIdentity,
      snapshot.identity.uri,
      snapshot.resourceSetKey,
      uri,
    ]);
    final now = _clock();
    final cached = _resourceCache[cacheKey];
    if (cached != null && now.isBefore(cached.expiresAt)) {
      return cached.content._asCacheHit();
    }
    _resourceCache.remove(cacheKey);

    final readResult = await client.readResource(uri);
    if (readResult.resultType != 'complete' ||
        readResult.ttlMs == null ||
        readResult.cacheScope == null) {
      throw McpSkillIntegrityException(
        'skill_resource_cache_metadata_missing',
        uri,
      );
    }
    if (readResult.contents.length != 1) {
      throw McpSkillIntegrityException(
        'skill_resource_read_content_count_invalid',
        uri,
      );
    }
    final content = readResult.contents.single;
    if (content.uri != uri) {
      throw McpSkillIntegrityException(
        'skill_resource_read_uri_mismatch',
        uri,
      );
    }

    final hasText = content.text != null;
    final hasBlob = content.blob != null;
    if (hasText == hasBlob) {
      throw McpSkillIntegrityException(
        'skill_resource_content_encoding_invalid',
        uri,
      );
    }

    final List<int> rawBytes;
    if (hasText) {
      rawBytes = utf8.encode(content.text!);
    } else {
      try {
        rawBytes = base64Decode(content.blob!);
      } on FormatException {
        throw McpSkillIntegrityException(
          'skill_resource_blob_invalid',
          uri,
        );
      }
    }

    if (rawBytes.length != declared.size) {
      throw McpSkillIntegrityException(
        'skill_resource_size_mismatch',
        uri,
      );
    }
    final actualDigest = 'sha256:' + sha256.convert(rawBytes).toString();
    if (actualDigest != declared.digest) {
      throw McpSkillIntegrityException(
        'skill_resource_digest_mismatch',
        uri,
      );
    }

    if (uri == snapshot.skill.uri) {
      _verifySkillFrontmatter(rawBytes, snapshot.skill);
    }

    final immutableBytes = List<int>.unmodifiable(rawBytes);
    final mergedCacheScope =
        snapshot.cacheScope == 'private' || readResult.cacheScope == 'private'
            ? 'private'
            : 'public';
    final verified = McpVerifiedSkillResource._(
      snapshot: snapshot,
      uri: uri,
      digest: declared.digest,
      size: rawBytes.length,
      mimeType: content.mimeType,
      bytes: immutableBytes,
      cacheScope: mergedCacheScope,
      fromCache: false,
    );

    // Cache only in memory. Persistent storage is intentionally deferred until
    // a host-only path outside every local Skill discovery root is guaranteed.
    if (snapshot.ttlMs > 0 && readResult.ttlMs! > 0) {
      final snapshotExpiry = snapshot.retrievedAt.add(
        Duration(milliseconds: snapshot.ttlMs),
      );
      final readExpiry = now.add(
        Duration(milliseconds: readResult.ttlMs!),
      );
      final expiresAt = snapshotExpiry.isBefore(readExpiry)
          ? snapshotExpiry
          : readExpiry;
      if (now.isBefore(expiresAt)) {
        _resourceCache[cacheKey] = _McpCachedSkillResource(
          identity: snapshot.identity,
          content: verified,
          expiresAt: expiresAt,
        );
      }
    }
    return verified;
  }

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
    final snapshots = <McpSkillSnapshot>[];
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
        snapshots.add(
          _createSnapshot(
            skill,
            ttlMs: pageTtl,
            cacheScope: pageScope,
          ),
        );
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
      snapshots: List<McpSkillSnapshot>.unmodifiable(snapshots),
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
    final ttlMs = _readTtl(result);
    final cacheScope = _readCacheScope(result);
    final snapshot = _createSnapshot(
      skill,
      ttlMs: ttlMs,
      cacheScope: cacheScope,
    );
    return McpSkillsGetResult(
      skill: skill,
      snapshot: snapshot,
      ttlMs: ttlMs,
      cacheScope: cacheScope,
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

void _verifySkillFrontmatter(
  List<int> rawBytes,
  McpSkillEntry skill,
) {
  final String text;
  try {
    text = utf8.decode(rawBytes, allowMalformed: false);
  } on FormatException {
    throw McpSkillIntegrityException(
      'skill_markdown_is_not_valid_utf8',
      skill.uri,
    );
  }

  try {
    final lines = text.split(RegExp(r'\r?\n'));
    if (lines.isEmpty || lines.first.trim() != '---') {
      throw const FormatException('skill_frontmatter_opening_delimiter_missing');
    }
    final closingIndex = lines.indexWhere(
      (line) => line.trim() == '---',
      1,
    );
    if (closingIndex < 0) {
      throw const FormatException('skill_frontmatter_closing_delimiter_missing');
    }
    final yamlText = lines.sublist(1, closingIndex).join('\n');
    if (yamlText.trim().isEmpty) {
      throw const FormatException('skill_frontmatter_empty');
    }
    final parsed = loadYaml(yamlText);
    final normalized = _normalizeYamlValue(parsed);
    if (normalized is! Map<String, dynamic>) {
      throw const FormatException('skill_frontmatter_root_not_mapping');
    }
    if (!_deepJsonEquals(normalized, skill.frontmatter)) {
      throw McpSkillIntegrityException(
        'skill_frontmatter_mismatch',
        skill.uri,
      );
    }
  } on McpSkillIntegrityException {
    rethrow;
  } catch (_) {
    throw McpSkillIntegrityException(
      'skill_frontmatter_invalid',
      skill.uri,
    );
  }
}

dynamic _normalizeYamlValue(dynamic value) {
  if (value is Map) {
    final result = <String, dynamic>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw const FormatException('skill_frontmatter_key_not_string');
      }
      result[entry.key as String] = _normalizeYamlValue(entry.value);
    }
    return result;
  }
  if (value is List) {
    return value.map(_normalizeYamlValue).toList(growable: false);
  }
  if (value is DateTime) return value.toIso8601String();
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  throw const FormatException('skill_frontmatter_value_not_json_compatible');
}

bool _deepJsonEquals(dynamic left, dynamic right) {
  if (left is Map && right is Map) {
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      if (!right.containsKey(entry.key) ||
          !_deepJsonEquals(entry.value, right[entry.key])) {
        return false;
      }
    }
    return true;
  }
  if (left is List && right is List) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (!_deepJsonEquals(left[index], right[index])) return false;
    }
    return true;
  }
  return left == right;
}

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
