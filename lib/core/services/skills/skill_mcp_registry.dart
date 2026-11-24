import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import 'skill_mcp_config.dart';

typedef SkillMcpSourceDigestReader = Future<String?> Function(String skillId);

/// One persisted server declaration owned by one exact installed Skill snapshot.
///
/// Registrations are inventory only. They are never enabled or connected by
/// this registry. A future connection flow must re-check the digest and obtain
/// explicit approval before creating a normal MCP server session.
final class SkillMcpOwnerRegistration {
  const SkillMcpOwnerRegistration._({
    required this.serverId,
    required this.skillId,
    required this.sourceDigest,
    required this.capabilityId,
    required this.descriptor,
    required this.createdAt,
  });

  static const String requiredCapabilityId = 'agent_skill.mcp_server';
  static final RegExp _skillIdPattern =
      RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$');
  static final RegExp _digestPattern = RegExp(r'^[a-f0-9]{64}$');
  static final RegExp _uuidPattern = RegExp(
    r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
  );
  static final RegExp _commandPattern =
      RegExp(r'^[A-Za-z0-9_./+-]{1,256}$');
  static final RegExp _environmentNamePattern =
      RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

  final String serverId;
  final String skillId;
  final String sourceDigest;
  final String capabilityId;
  final SkillMcpServerDescriptor descriptor;
  final DateTime createdAt;

  /// Skill-owned declarations are always disabled until Phase 13Q.3 approval.
  bool get enabled => false;
  bool get requiresManualApproval => true;

  static SkillMcpOwnerRegistration create({
    required String serverId,
    required String skillId,
    required String sourceDigest,
    required String capabilityId,
    required SkillMcpServerDescriptor descriptor,
    DateTime? createdAt,
  }) {
    if (!_uuidPattern.hasMatch(serverId)) {
      throw const FormatException('invalid_skill_mcp_owner_server_id');
    }
    if (!_skillIdPattern.hasMatch(skillId)) {
      throw const FormatException('invalid_skill_mcp_owner_skill_id');
    }
    final digest = sourceDigest.toLowerCase();
    if (!_digestPattern.hasMatch(digest)) {
      throw const FormatException('invalid_skill_mcp_owner_source_digest');
    }
    if (capabilityId != requiredCapabilityId) {
      throw const FormatException('invalid_skill_mcp_owner_capability');
    }
    _validateDescriptor(descriptor);
    final immutableDescriptor = SkillMcpServerDescriptor(
      name: descriptor.name.trim(),
      transport: descriptor.transport,
      configPath: descriptor.configPath,
      command: descriptor.command,
      arguments: List<String>.unmodifiable(descriptor.arguments),
      requiredEnvironmentVariables:
          List<String>.unmodifiable(descriptor.requiredEnvironmentVariables),
      url: descriptor.url,
    );
    return SkillMcpOwnerRegistration._(
      serverId: serverId,
      skillId: skillId,
      sourceDigest: digest,
      capabilityId: capabilityId,
      descriptor: immutableDescriptor,
      createdAt: (createdAt ?? DateTime.now()).toUtc(),
    );
  }

  static void _validateDescriptor(SkillMcpServerDescriptor descriptor) {
    final name = descriptor.name.trim();
    if (name.isEmpty || name.length > 64 ||
        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$').hasMatch(name)) {
      throw const FormatException('invalid_skill_mcp_owner_server_name');
    }
    SkillMcpConfigParser.validateConfigPath(descriptor.configPath);
    if (descriptor.arguments.length > SkillMcpConfigParser.maxArguments) {
      throw const FormatException('invalid_skill_mcp_owner_arguments');
    }
    for (final argument in descriptor.arguments) {
      if (argument.length > 4096 || argument.contains('\u0000')) {
        throw const FormatException('invalid_skill_mcp_owner_argument');
      }
    }
    final envNames = <String>{};
    if (descriptor.requiredEnvironmentVariables.length >
        SkillMcpConfigParser.maxEnvironmentVariables) {
      throw const FormatException('invalid_skill_mcp_owner_environment');
    }
    for (final name in descriptor.requiredEnvironmentVariables) {
      if (!_environmentNamePattern.hasMatch(name) || !envNames.add(name)) {
        throw const FormatException('invalid_skill_mcp_owner_environment_name');
      }
    }

    switch (descriptor.transport) {
      case SkillMcpTransport.stdio:
        final command = descriptor.command;
        if (command == null || !_commandPattern.hasMatch(command) ||
            descriptor.url != null) {
          throw const FormatException('invalid_skill_mcp_owner_stdio');
        }
        break;
      case SkillMcpTransport.http:
      case SkillMcpTransport.sse:
        final url = descriptor.url;
        if (url == null || url.scheme.toLowerCase() != 'https' ||
            !url.hasAuthority || url.host.isEmpty ||
            url.userInfo.isNotEmpty || url.hasQuery || url.hasFragment ||
            descriptor.command != null || descriptor.arguments.isNotEmpty) {
          throw const FormatException('invalid_skill_mcp_owner_remote_endpoint');
        }
        break;
    }
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'serverId': serverId,
    'skillId': skillId,
    'sourceDigest': sourceDigest,
    'capabilityId': capabilityId,
    'name': descriptor.name,
    'transport': descriptor.transport.name,
    'configPath': descriptor.configPath,
    if (descriptor.command != null) 'command': descriptor.command,
    'arguments': descriptor.arguments,
    if (descriptor.url != null) 'url': descriptor.url.toString(),
    // These are variable names only. Values are held by SkillMcpSecretStore.
    'requiredEnvironmentVariables': descriptor.requiredEnvironmentVariables,
    'enabled': false,
    'requiresManualApproval': true,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  factory SkillMcpOwnerRegistration.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('invalid_skill_mcp_owner_record');
    }
    final json = <String, Object?>{};
    for (final entry in raw.entries) {
      if (entry.key is! String) {
        throw const FormatException('invalid_skill_mcp_owner_record');
      }
      json[entry.key as String] = entry.value;
    }
    const allowed = <String>{
      'serverId',
      'skillId',
      'sourceDigest',
      'capabilityId',
      'name',
      'transport',
      'configPath',
      'command',
      'arguments',
      'url',
      'requiredEnvironmentVariables',
      'enabled',
      'requiresManualApproval',
      'createdAt',
    };
    if (json.keys.any((key) => !allowed.contains(key)) ||
        json['enabled'] != false ||
        json['requiresManualApproval'] != true) {
      throw const FormatException('invalid_skill_mcp_owner_policy');
    }

    final rawArguments = json['arguments'];
    final rawEnvironmentNames = json['requiredEnvironmentVariables'];
    if (rawArguments is! List || rawEnvironmentNames is! List) {
      throw const FormatException('invalid_skill_mcp_owner_lists');
    }
    final arguments = <String>[];
    for (final item in rawArguments) {
      if (item is! String) {
        throw const FormatException('invalid_skill_mcp_owner_arguments');
      }
      arguments.add(item);
    }
    final environmentNames = <String>[];
    for (final item in rawEnvironmentNames) {
      if (item is! String) {
        throw const FormatException('invalid_skill_mcp_owner_environment');
      }
      environmentNames.add(item);
    }

    final transportName = json['transport'];
    final transport = switch (transportName) {
      'stdio' => SkillMcpTransport.stdio,
      'http' => SkillMcpTransport.http,
      'sse' => SkillMcpTransport.sse,
      _ => throw const FormatException('invalid_skill_mcp_owner_transport'),
    };
    final rawUrl = json['url'];
    final uri = rawUrl == null
        ? null
        : rawUrl is String
            ? Uri.tryParse(rawUrl)
            : null;
    if (rawUrl != null && uri == null) {
      throw const FormatException('invalid_skill_mcp_owner_url');
    }
    final createdAtRaw = json['createdAt'];
    if (createdAtRaw is! String) {
      throw const FormatException('invalid_skill_mcp_owner_timestamp');
    }
    DateTime timestamp;
    try {
      timestamp = DateTime.parse(createdAtRaw);
    } catch (_) {
      throw const FormatException('invalid_skill_mcp_owner_timestamp');
    }

    final name = json['name'];
    final configPath = json['configPath'];
    final command = json['command'];
    final serverId = json['serverId'];
    final skillId = json['skillId'];
    final sourceDigest = json['sourceDigest'];
    final capabilityId = json['capabilityId'];
    if (name is! String || configPath is! String ||
        (command != null && command is! String) ||
        serverId is! String || skillId is! String ||
        sourceDigest is! String || capabilityId is! String) {
      throw const FormatException('invalid_skill_mcp_owner_fields');
    }

    return SkillMcpOwnerRegistration.create(
      serverId: serverId,
      skillId: skillId,
      sourceDigest: sourceDigest,
      capabilityId: capabilityId,
      descriptor: SkillMcpServerDescriptor(
        name: name,
        transport: transport,
        configPath: configPath,
        command: command as String?,
        arguments: arguments,
        requiredEnvironmentVariables: environmentNames,
        url: uri,
      ),
      createdAt: timestamp,
    );
  }
}

/// Durable owner registry for Skill-declared MCP servers.
///
/// The JSON file contains descriptors and ownership only, never credentials.
/// Stale source digests are removed before records are returned to callers.
final class SkillMcpOwnerRegistry {
  SkillMcpOwnerRegistry({
    required this.directory,
    required this.currentSourceDigestForSkill,
  });

  static const int schemaVersion = 1;
  static const int maxRegistrations = 256;
  static const int maxRegistryBytes = 4 * 1024 * 1024;
  static const String registryFileName = 'skill-mcp-owners-v1.json';

  final Directory directory;
  final SkillMcpSourceDigestReader currentSourceDigestForSkill;

  File get _file => File(directory.path + '/' + registryFileName);

  List<SkillMcpOwnerRegistration> _registrations =
      <SkillMcpOwnerRegistration>[];
  bool _loaded = false;
  Future<void>? _loadFuture;
  Future<void> _mutationTail = Future<void>.value();

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _mutationTail.then((_) => operation());
    _mutationTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final pending = _loadFuture;
    if (pending != null) {
      await pending;
      return;
    }
    final future = _loadFromDisk();
    _loadFuture = future;
    try {
      await future;
    } catch (_) {
      if (identical(_loadFuture, future)) _loadFuture = null;
      rethrow;
    }
  }

  Future<void> _loadFromDisk() async {
    await directory.create(recursive: true);
    if (await _file.exists()) {
      final length = await _file.length();
      if (length > maxRegistryBytes) {
        throw const FormatException('skill_mcp_owner_registry_too_large');
      }
      final decoded = jsonDecode(await _file.readAsString());
      if (decoded is! Map ||
          decoded['schemaVersion'] != schemaVersion ||
          decoded['registrations'] is! List ||
          decoded.keys.any(
            (key) => key != 'schemaVersion' && key != 'registrations',
          )) {
        throw const FormatException('invalid_skill_mcp_owner_registry');
      }
      final rawRecords = decoded['registrations'] as List;
      if (rawRecords.length > maxRegistrations) {
        throw const FormatException('too_many_skill_mcp_owner_registrations');
      }
      final parsed = rawRecords
          .map(SkillMcpOwnerRegistration.fromJson)
          .toList(growable: false);
      _validateUniqueRecords(parsed);
      _registrations = List<SkillMcpOwnerRegistration>.of(parsed);
    }
    _loaded = true;
  }

  static void _validateUniqueRecords(
    List<SkillMcpOwnerRegistration> registrations,
  ) {
    final ids = <String>{};
    final identities = <String>{};
    for (final registration in registrations) {
      final identity = _identity(registration);
      if (!ids.add(registration.serverId) || !identities.add(identity)) {
        throw const FormatException('duplicate_skill_mcp_owner_registration');
      }
    }
  }

  static String _identity(SkillMcpOwnerRegistration registration) =>
      registration.skillId.toLowerCase() +
      '|' +
      registration.sourceDigest +
      '|' +
      registration.capabilityId +
      '|' +
      registration.descriptor.name.toLowerCase();

  Future<List<SkillMcpOwnerRegistration>> registerMany({
    required String skillId,
    required String sourceDigest,
    required String capabilityId,
    required List<SkillMcpServerDescriptor> descriptors,
  }) => _serialize(() async {
    await _ensureLoaded();
    if (descriptors.isEmpty ||
        descriptors.length > SkillMcpConfigParser.maxServers) {
      throw const FormatException('invalid_skill_mcp_owner_descriptor_count');
    }
    final currentDigest = await currentSourceDigestForSkill(skillId);
    final normalizedDigest = sourceDigest.toLowerCase();
    if (currentDigest == null ||
        currentDigest.toLowerCase() != normalizedDigest) {
      throw StateError('skill_mcp_owner_stale_or_missing_skill');
    }

    final next = _registrations
        .where((entry) =>
            entry.skillId != skillId || entry.sourceDigest == normalizedDigest)
        .toList(growable: true);
    final identities = <String>{
      for (final entry in next) _identity(entry),
    };
    final ids = <String>{for (final entry in next) entry.serverId};
    final created = <SkillMcpOwnerRegistration>[];
    for (final descriptor in descriptors) {
      final registration = SkillMcpOwnerRegistration.create(
        serverId: const Uuid().v4(),
        skillId: skillId,
        sourceDigest: normalizedDigest,
        capabilityId: capabilityId,
        descriptor: descriptor,
      );
      if (!identities.add(_identity(registration))) {
        throw StateError('duplicate_skill_mcp_owner_server');
      }
      if (!ids.add(registration.serverId)) {
        throw StateError('duplicate_skill_mcp_owner_server_id');
      }
      created.add(registration);
    }
    if (next.length + created.length > maxRegistrations) {
      throw const FormatException('too_many_skill_mcp_owner_registrations');
    }
    next.addAll(created);
    await _persist(next);
    _registrations = next;
    return List<SkillMcpOwnerRegistration>.unmodifiable(created);
  });

  Future<List<SkillMcpOwnerRegistration>> registrationsForSkill(
    String skillId,
  ) => _serialize(() async {
    await _ensureLoaded();
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$').hasMatch(skillId)) {
      throw const FormatException('invalid_skill_mcp_owner_skill_id');
    }
    final currentDigest = await currentSourceDigestForSkill(skillId);
    final normalizedDigest = currentDigest?.toLowerCase();
    final next = _registrations
        .where((entry) =>
            entry.skillId != skillId ||
            (normalizedDigest != null && entry.sourceDigest == normalizedDigest))
        .toList(growable: false);
    if (next.length != _registrations.length) {
      await _persist(next);
      _registrations = List<SkillMcpOwnerRegistration>.of(next);
    }
    return List<SkillMcpOwnerRegistration>.unmodifiable(
      next.where((entry) => entry.skillId == skillId),
    );
  });

  Future<List<SkillMcpOwnerRegistration>> allCurrentRegistrations() =>
      _serialize(() async {
        await _ensureLoaded();
        final currentDigests = <String, String?>{};
        for (final skillId in _registrations.map((e) => e.skillId).toSet()) {
          currentDigests[skillId] =
              (await currentSourceDigestForSkill(skillId))?.toLowerCase();
        }
        final next = _registrations
            .where((entry) =>
                currentDigests[entry.skillId] == entry.sourceDigest)
            .toList(growable: false);
        if (next.length != _registrations.length) {
          await _persist(next);
          _registrations = List<SkillMcpOwnerRegistration>.of(next);
        }
        return List<SkillMcpOwnerRegistration>.unmodifiable(next);
      });

  Future<void> removeSkill(String skillId) => _serialize(() async {
    await _ensureLoaded();
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$').hasMatch(skillId)) {
      throw const FormatException('invalid_skill_mcp_owner_skill_id');
    }
    final next = _registrations
        .where((entry) => entry.skillId != skillId)
        .toList(growable: false);
    if (next.length == _registrations.length) return;
    await _persist(next);
    _registrations = List<SkillMcpOwnerRegistration>.of(next);
  });

  Future<bool> removeServer(String serverId) => _serialize(() async {
    await _ensureLoaded();
    final next = _registrations
        .where((entry) => entry.serverId != serverId)
        .toList(growable: false);
    if (next.length == _registrations.length) return false;
    await _persist(next);
    _registrations = List<SkillMcpOwnerRegistration>.of(next);
    return true;
  });

  Future<void> _persist(List<SkillMcpOwnerRegistration> registrations) async {
    final content = const JsonEncoder.withIndent('  ').convert(
      <String, Object?>{
        'schemaVersion': schemaVersion,
        'registrations': registrations.map((entry) => entry.toJson()).toList(),
      },
    );
    if (utf8.encode(content).length > maxRegistryBytes) {
      throw const FormatException('skill_mcp_owner_registry_too_large');
    }
    await directory.create(recursive: true);
    final temporary = File(_file.path + '.tmp');
    try {
      await temporary.writeAsString(content, flush: true);
      // On Android/Linux, rename replaces the previous file atomically.
      await temporary.rename(_file.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }
}

/// Secrets are stored independently from the Skill owner registry. The
/// registry itself only contains environment variable names.
abstract interface class SkillMcpSecretStore {
  Future<void> writeVariable(
    SkillMcpOwnerRegistration registration,
    String variableName,
    String value,
  );

  Future<String?> readVariable(
    SkillMcpOwnerRegistration registration,
    String variableName,
  );

  Future<void> clearServer(SkillMcpOwnerRegistration registration);
}

class SecureSkillMcpSecretStore implements SkillMcpSecretStore {
  SecureSkillMcpSecretStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<void> writeVariable(
    SkillMcpOwnerRegistration registration,
    String variableName,
    String value,
  ) async {
    _validateBinding(registration, variableName);
    if (value.isEmpty || value.length > 65536 || value.contains('\u0000')) {
      throw const FormatException('invalid_skill_mcp_secret_value');
    }
    await _storage.write(
      key: _storageKey(registration, variableName),
      value: value,
    );
  }

  @override
  Future<String?> readVariable(
    SkillMcpOwnerRegistration registration,
    String variableName,
  ) {
    _validateBinding(registration, variableName);
    return _storage.read(key: _storageKey(registration, variableName));
  }

  @override
  Future<void> clearServer(SkillMcpOwnerRegistration registration) async {
    for (final variableName
        in registration.descriptor.requiredEnvironmentVariables) {
      await _storage.delete(key: _storageKey(registration, variableName));
    }
  }

  static void _validateBinding(
    SkillMcpOwnerRegistration registration,
    String variableName,
  ) {
    if (!registration.descriptor.requiredEnvironmentVariables
        .contains(variableName)) {
      throw const FormatException('skill_mcp_secret_not_declared');
    }
  }

  static String _storageKey(
    SkillMcpOwnerRegistration registration,
    String variableName,
  ) {
    final identity = <String>[
      registration.skillId,
      registration.sourceDigest,
      registration.serverId,
      variableName,
    ].join('\u0000');
    final digest = sha256.convert(utf8.encode(identity)).toString();
    return 'skill_mcp_secret_v1.' + digest;
  }
}

/// Deterministic test implementation. Production must use Keystore storage.
class MemorySkillMcpSecretStore implements SkillMcpSecretStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> writeVariable(
    SkillMcpOwnerRegistration registration,
    String variableName,
    String value,
  ) async {
    SecureSkillMcpSecretStore._validateBinding(registration, variableName);
    if (value.isEmpty || value.length > 65536 || value.contains('\u0000')) {
      throw const FormatException('invalid_skill_mcp_secret_value');
    }
    values[SecureSkillMcpSecretStore._storageKey(registration, variableName)] =
        value;
  }

  @override
  Future<String?> readVariable(
    SkillMcpOwnerRegistration registration,
    String variableName,
  ) async {
    SecureSkillMcpSecretStore._validateBinding(registration, variableName);
    return values[SecureSkillMcpSecretStore._storageKey(
      registration,
      variableName,
    )];
  }

  @override
  Future<void> clearServer(SkillMcpOwnerRegistration registration) async {
    for (final variableName
        in registration.descriptor.requiredEnvironmentVariables) {
      values.remove(
        SecureSkillMcpSecretStore._storageKey(registration, variableName),
      );
    }
  }
}
