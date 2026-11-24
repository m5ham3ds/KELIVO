import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../utils/app_directories.dart';
import '../../providers/mcp_provider.dart';
import 'skill_mcp_config.dart';
import 'skill_mcp_registry.dart';
import 'skills_service.dart';

final class SkillMcpConnectionPreview {
  const SkillMcpConnectionPreview({
    required this.skillId,
    required this.ownerServerId,
    required this.serverName,
    required this.command,
    required this.arguments,
    required this.environmentVariableNames,
    required this.sourceDigest,
    required this.workspaceScope,
    required this.securityWarning,
  });

  final String skillId;
  final String ownerServerId;
  final String serverName;
  final String command;
  final List<String> arguments;
  final List<String> environmentVariableNames;
  final String sourceDigest;
  final String workspaceScope;
  final String securityWarning;
}

typedef SkillMcpApprovalCallback =
    Future<bool> Function(SkillMcpConnectionPreview preview);
typedef SkillMcpSecretPromptCallback =
    Future<Map<String, String>?> Function(
      SkillMcpConnectionPreview preview,
      List<String> missingVariableNames,
    );

final class SkillMcpApprovalDenied implements Exception {
  const SkillMcpApprovalDenied();

  @override
  String toString() => 'Skill MCP connection was not approved.';
}

final class SkillMcpConnectedServer {
  const SkillMcpConnectedServer({
    required this.skillId,
    required this.ownerServerId,
    required this.mcpServerId,
    required this.name,
    required this.discoveredToolCount,
  });

  final String skillId;
  final String ownerServerId;
  final String mcpServerId;
  final String name;
  final int discoveredToolCount;
}

final class _ActiveSkillMcpSession {
  const _ActiveSkillMcpSession({
    required this.skillId,
    required this.ownerServerId,
    required this.sourceDigest,
    required this.mcpServerId,
    required this.directory,
    required this.registration,
  });

  final String skillId;
  final String ownerServerId;
  final String sourceDigest;
  final String mcpServerId;
  final Directory directory;
  final SkillMcpOwnerRegistration registration;
}

final class SkillMcpConnectionService {
  SkillMcpConnectionService({
    required this.skills,
    required this.mcp,
    SkillMcpSecretStore? secretStore,
    Directory? sessionsDirectory,
  }) : _secretStore = secretStore ?? SecureSkillMcpSecretStore(),
       _sessionsDirectory = sessionsDirectory;

  static const String securityWarning =
      'PRoot is not a kernel sandbox. Skill MCP processes share the '
      'Environment writable rootFS and network access is not fully restricted. '
      'Only a verified per-session Skill copy is mounted at /workspace; the '
      'installed Skills directory and user project workspaces are not mounted.';
  static const String workspaceScope =
      'A temporary private directory containing a verified copy of this Skill '
      'is mounted at /workspace.';

  static const Set<String> _reservedEnvironmentNames = <String>{
    'PATH',
    'HOME',
    'TMP',
    'TEMP',
    'TMPDIR',
    'LD_PRELOAD',
    'LD_LIBRARY_PATH',
    'PROOT_TMP_DIR',
    'PROOT_LOADER',
    'PROOT_DONT_LOAD',
    'ANDROID_ROOT',
    'ANDROID_DATA',
    'PREFIX',
  };

  final SkillsService skills;
  final McpProvider mcp;
  final SkillMcpSecretStore _secretStore;
  final Directory? _sessionsDirectory;
  final Map<String, _ActiveSkillMcpSession> _activeSessions =
      <String, _ActiveSkillMcpSession>{};
  final Set<String> _connecting = <String>{};
  Future<void> _mutationTail = Future<void>.value();
  late final Future<void> _loaded = _initialize();

  Future<void> get loaded => _loaded;

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _mutationTail.then((_) => operation());
    _mutationTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  Future<Directory> _sessionRoot() async {
    final root = _sessionsDirectory ??
        await AppDirectories.getSkillMcpSessionsDirectory();
    await root.create(recursive: true);
    return root;
  }

  Future<void> _initialize() async {
    final root = await _sessionRoot();
    await for (final entity in root.list(followLinks: false)) {
      final type = await FileSystemEntity.type(
        entity.path,
        followLinks: false,
      );
      if (type == FileSystemEntityType.link) {
        await Link(entity.path).delete();
      } else if (type == FileSystemEntityType.directory) {
        await Directory(entity.path).delete(recursive: true);
      } else if (type == FileSystemEntityType.file) {
        await File(entity.path).delete();
      }
    }
  }

  Future<SkillMcpConnectedServer> connect({
    required String skillId,
    required String ownerServerId,
    required SkillMcpApprovalCallback confirm,
    SkillMcpSecretPromptCallback? collectSecrets,
  }) => _serialize(() async {
    await _loaded;
    if (_connecting.contains(ownerServerId) ||
        _activeSessions.containsKey(ownerServerId)) {
      throw StateError('skill_mcp_session_already_active_or_connecting');
    }
    _connecting.add(ownerServerId);
    Directory? sessionDirectory;
    String? providerServerId;
    SkillMcpOwnerRegistration? registration;
    try {
      final initial = await _findRegistration(skillId, ownerServerId);
      registration = initial;
      _ensureSkillEnabled(skillId);
      final descriptor = initial.descriptor;
      if (descriptor.transport != SkillMcpTransport.stdio) {
        throw UnsupportedError(
          'Skill-owned HTTP/SSE remains disabled until DNS-pinned SSRF '
          'protection and explicit host approval are implemented.',
        );
      }
      if (!mcp.supportsStdio || !mcp.supportsStdioWorkspaceBinding) {
        throw StateError('skill_mcp_workspace_environment_not_ready');
      }

      final preview = SkillMcpConnectionPreview(
        skillId: skillId,
        ownerServerId: ownerServerId,
        serverName: descriptor.name,
        command: descriptor.command!,
        arguments: List<String>.unmodifiable(descriptor.arguments),
        environmentVariableNames: List<String>.unmodifiable(
          descriptor.requiredEnvironmentVariables,
        ),
        sourceDigest: initial.sourceDigest,
        workspaceScope: workspaceScope,
        securityWarning: securityWarning,
      );
      if (!await confirm(preview)) throw const SkillMcpApprovalDenied();

      registration = await _findRegistration(skillId, ownerServerId);
      _requireSameSnapshot(initial, registration);
      _ensureSkillEnabled(skillId);
      final secrets = await _loadSecrets(registration, preview, collectSecrets);

      final beforeCopy = await _findRegistration(skillId, ownerServerId);
      _requireSameSnapshot(registration, beforeCopy);
      registration = beforeCopy;

      final root = await _sessionRoot();
      sessionDirectory =
          Directory(p.join(root.path, registration.serverId));
      if (await sessionDirectory.exists()) {
        throw StateError('skill_mcp_stale_session_directory_exists');
      }
      await sessionDirectory.create(recursive: true);
      await Directory(p.join(sessionDirectory.path, '.home')).create();
      await Directory(p.join(sessionDirectory.path, '.tmp')).create();

      await skills.copyVerifiedSkillSnapshot(
        skillId: skillId,
        sourceDigest: registration.sourceDigest,
        destination: Directory(p.join(sessionDirectory.path, 'skill')),
      );

      final beforeLaunch = await _findRegistration(skillId, ownerServerId);
      _requireSameSnapshot(registration, beforeLaunch);
      _ensureSkillEnabled(skillId);
      providerServerId = await mcp.connectSkillOwnedServer(
        skillId: skillId,
        ownerServerId: ownerServerId,
        sourceDigest: registration.sourceDigest,
        name: descriptor.name,
        command: descriptor.command!,
        args: descriptor.arguments,
        env: secrets,
        workspaceRoot: sessionDirectory.path,
      );

      try {
        final afterConnect = await _findRegistration(skillId, ownerServerId);
        _requireSameSnapshot(registration, afterConnect);
        _ensureSkillEnabled(skillId);
      } catch (_) {
        await mcp.removeSkillOwnedServer(
          providerServerId,
          skillId: skillId,
          ownerServerId: ownerServerId,
          sourceDigest: registration.sourceDigest,
        );
        providerServerId = null;
        rethrow;
      }

      final config = mcp.getById(providerServerId);
      if (config == null || !mcp.isConnected(providerServerId)) {
        throw StateError('skill_mcp_connected_server_disappeared');
      }
      _activeSessions[ownerServerId] = _ActiveSkillMcpSession(
        skillId: skillId,
        ownerServerId: ownerServerId,
        sourceDigest: registration.sourceDigest,
        mcpServerId: providerServerId,
        directory: sessionDirectory,
        registration: registration,
      );
      return SkillMcpConnectedServer(
        skillId: skillId,
        ownerServerId: ownerServerId,
        mcpServerId: providerServerId,
        name: descriptor.name,
        discoveredToolCount: config.tools.length,
      );
    } catch (_) {
      if (providerServerId != null && registration != null) {
        try {
          await mcp.removeSkillOwnedServer(
            providerServerId,
            skillId: skillId,
            ownerServerId: ownerServerId,
            sourceDigest: registration.sourceDigest,
          );
        } catch (_) {}
      }
      if (sessionDirectory != null && await sessionDirectory.exists()) {
        await sessionDirectory.delete(recursive: true);
      }
      rethrow;
    } finally {
      _connecting.remove(ownerServerId);
    }
  });

  Future<void> disconnect({
    required String skillId,
    required String ownerServerId,
    bool clearCredentials = false,
  }) => _serialize(() async {
    await _loaded;
    final session = _activeSessions[ownerServerId];
    if (session == null) return;
    if (session.skillId != skillId) {
      throw StateError('skill_mcp_session_owner_mismatch');
    }
    await mcp.removeSkillOwnedServer(
      session.mcpServerId,
      skillId: session.skillId,
      ownerServerId: session.ownerServerId,
      sourceDigest: session.sourceDigest,
    );
    _activeSessions.remove(ownerServerId);
    if (await session.directory.exists()) {
      await session.directory.delete(recursive: true);
    }
    if (clearCredentials) {
      await _secretStore.clearServer(session.registration);
    }
  });

  Future<void> disconnectSkill(
    String skillId, {
    bool clearCredentials = false,
  }) => _serialize(() async {
    await _loaded;
    final sessions = _activeSessions.values
        .where((session) => session.skillId == skillId)
        .toList(growable: false);
    for (final session in sessions) {
      await mcp.removeSkillOwnedServer(
        session.mcpServerId,
        skillId: session.skillId,
        ownerServerId: session.ownerServerId,
        sourceDigest: session.sourceDigest,
      );
      _activeSessions.remove(session.ownerServerId);
      if (await session.directory.exists()) {
        await session.directory.delete(recursive: true);
      }
      if (clearCredentials) {
        await _secretStore.clearServer(session.registration);
      }
    }
  });

  Future<void> dispose() async {
    await _loaded;
    final sessions = _activeSessions.values.toList(growable: false);
    for (final session in sessions) {
      await mcp.removeSkillOwnedServer(
        session.mcpServerId,
        skillId: session.skillId,
        ownerServerId: session.ownerServerId,
        sourceDigest: session.sourceDigest,
      );
      _activeSessions.remove(session.ownerServerId);
      if (await session.directory.exists()) {
        await session.directory.delete(recursive: true);
      }
    }
  }

  bool isConnected(String skillId, String ownerServerId) {
    final session = _activeSessions[ownerServerId];
    return session != null &&
        session.skillId == skillId &&
        mcp.isConnected(session.mcpServerId);
  }

  Future<SkillMcpOwnerRegistration> _findRegistration(
    String skillId,
    String ownerServerId,
  ) async {
    final registry = await skills.skillMcpOwnerRegistry;
    final registrations = await registry.registrationsForSkill(skillId);
    for (final registration in registrations) {
      if (registration.serverId == ownerServerId) return registration;
    }
    throw StateError('skill_mcp_owner_not_found_or_source_changed');
  }

  void _requireSameSnapshot(
    SkillMcpOwnerRegistration expected,
    SkillMcpOwnerRegistration actual,
  ) {
    if (expected.serverId != actual.serverId ||
        expected.skillId != actual.skillId ||
        expected.sourceDigest != actual.sourceDigest ||
        expected.capabilityId != actual.capabilityId ||
        expected.descriptor.name != actual.descriptor.name ||
        expected.descriptor.transport != actual.descriptor.transport ||
        expected.descriptor.command != actual.descriptor.command ||
        expected.descriptor.configPath != actual.descriptor.configPath ||
        expected.descriptor.url != actual.descriptor.url ||
        expected.descriptor.arguments.join('\u0000') !=
            actual.descriptor.arguments.join('\u0000') ||
        expected.descriptor.requiredEnvironmentVariables.join('\u0000') !=
            actual.descriptor.requiredEnvironmentVariables.join('\u0000')) {
      throw StateError('skill_mcp_owner_snapshot_changed');
    }
  }

  void _ensureSkillEnabled(String skillId) {
    for (final skill in skills.skills) {
      if (skill.record.id == skillId) {
        if (!skill.record.enabled) {
          throw StateError('skill_mcp_skill_disabled');
        }
        return;
      }
    }
    throw StateError('skill_mcp_skill_not_installed');
  }

  Future<Map<String, String>> _loadSecrets(
    SkillMcpOwnerRegistration registration,
    SkillMcpConnectionPreview preview,
    SkillMcpSecretPromptCallback? collectSecrets,
  ) async {
    final names = registration.descriptor.requiredEnvironmentVariables;
    if (names.any(
      (name) => _reservedEnvironmentNames.contains(name.toUpperCase()),
    )) {
      throw const FormatException('skill_mcp_reserved_environment_name');
    }
    final result = <String, String>{};
    final missing = <String>[];
    for (final name in names) {
      final value = await _secretStore.readVariable(registration, name);
      if (value == null || value.isEmpty) {
        missing.add(name);
      } else {
        result[name] = value;
      }
    }
    if (missing.isNotEmpty) {
      if (collectSecrets == null) {
        throw StateError('skill_mcp_credentials_required');
      }
      final provided = await collectSecrets(
        preview,
        List<String>.unmodifiable(missing),
      );
      if (provided == null) throw const SkillMcpApprovalDenied();
      if (provided.keys.any((key) => !missing.contains(key)) ||
          missing.any((key) => !provided.containsKey(key))) {
        throw const FormatException('skill_mcp_credential_set_mismatch');
      }
      for (final name in missing) {
        final value = provided[name]!;
        await _secretStore.writeVariable(registration, name, value);
        result[name] = value;
      }
    }
    return Map<String, String>.unmodifiable(result);
  }
}
