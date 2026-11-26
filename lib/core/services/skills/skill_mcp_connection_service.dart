import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:mcp_client/mcp_client.dart' as mcp_client;
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


final class SkillMcpToolDescriptor {
  const SkillMcpToolDescriptor({
    required this.skillId,
    required this.ownerServerId,
    required this.sourceDigest,
    required this.mcpServerId,
    required this.name,
    required this.exposedName,
    required this.description,
    required this.inputSchema,
  });

  final String skillId;
  final String ownerServerId;
  final String sourceDigest;
  final String mcpServerId;
  final String name;
  final String exposedName;
  final String description;
  final Map<String, dynamic> inputSchema;
  bool get requiresManualApproval => true;
}

final class SkillMcpToolCallPreview {
  const SkillMcpToolCallPreview({
    required this.tool,
    required this.redactedArguments,
  });

  final SkillMcpToolDescriptor tool;
  final Map<String, Object?> redactedArguments;
}

typedef SkillMcpToolApprovalCallback =
    Future<bool> Function(SkillMcpToolCallPreview preview);

final class SkillMcpToolApprovalDenied implements Exception {
  const SkillMcpToolApprovalDenied();

  @override
  String toString() => 'Skill MCP tool call was not approved.';
}

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
    Directory? auditDirectory,
  }) : _secretStore = secretStore ?? SecureSkillMcpSecretStore(),
       _sessionsDirectory = sessionsDirectory,
       _auditDirectory = auditDirectory {
    skills.addListener(_onSkillsChanged);
  }

  static const String securityWarning =
      'PRoot is not a kernel sandbox. Skill MCP processes share the '
      'Environment writable rootFS and network access is not fully restricted. '
      'Only a verified per-session Skill copy is mounted at /workspace; the '
      'installed Skills directory and user project workspaces are not mounted.';
  static const String workspaceScope =
      'A temporary private directory containing a verified copy of this Skill '
      'is mounted at /workspace.';

  static const int maxToolsPerSkillServer = 128;
  static const int maxInputSchemaBytes = 64 * 1024;
  static const int maxToolArgumentsBytes = 64 * 1024;
  static const int maxToolResultBytes = 256 * 1024;
  static const int maxToolResultItems = 64;
  static const int maxAuditBytes = 512 * 1024;

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
  final Directory? _auditDirectory;
  final Map<String, _ActiveSkillMcpSession> _activeSessions =
      <String, _ActiveSkillMcpSession>{};
  final Set<String> _connecting = <String>{};
  Future<void> _mutationTail = Future<void>.value();
  bool _disposed = false;
  bool _reconcileScheduled = false;
  bool _reconcilePending = false;
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

  Future<Directory> _auditRoot() async {
    final root = _auditDirectory ??
        await AppDirectories.getSkillMcpAuditDirectory();
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
    if (_disposed) {
      throw StateError('skill_mcp_connection_service_disposed');
    }
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

      final discoveredTools = await mcp.listSkillOwnedTools(
        serverId: providerServerId,
        skillId: skillId,
        ownerServerId: ownerServerId,
        sourceDigest: registration.sourceDigest,
      );
      final afterToolDiscovery = await _findRegistration(skillId, ownerServerId);
      _requireSameSnapshot(registration, afterToolDiscovery);
      _ensureSkillEnabled(skillId);

      // Validate every discovered schema before making this owner session
      // active or exposing any tool descriptor to callers. In particular,
      // remote $ref variants must fail closed during initial connection,
      // not only when the user later opens the tool list.
      final pendingSession = _ActiveSkillMcpSession(
        skillId: skillId,
        ownerServerId: ownerServerId,
        sourceDigest: registration.sourceDigest,
        mcpServerId: providerServerId,
        directory: sessionDirectory,
        registration: registration,
      );
      for (final tool in discoveredTools) {
        _describeTool(pendingSession, tool);
      }

      final config = mcp.getById(providerServerId);
      if (config == null || !mcp.isConnected(providerServerId)) {
        throw StateError('skill_mcp_connected_server_disappeared');
      }
      _activeSessions[ownerServerId] = pendingSession;
      return SkillMcpConnectedServer(
        skillId: skillId,
        ownerServerId: ownerServerId,
        mcpServerId: providerServerId,
        name: descriptor.name,
        discoveredToolCount: discoveredTools.length,
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


  Future<void> _recordToolAudit({
    required _ActiveSkillMcpSession session,
    required SkillMcpToolDescriptor tool,
    required String outcome,
    required int durationMs,
    String? errorType,
  }) async {
    final root = await _auditRoot();
    final file = File(p.join(root.path, 'skill-mcp-tool-audit-v1.jsonl'));
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type == FileSystemEntityType.link ||
        type == FileSystemEntityType.directory) {
      throw StateError('skill_mcp_audit_path_is_not_a_regular_file');
    }
    final entry = <String, Object?>{
      'schemaVersion': 1,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'skillId': session.skillId,
      'sourceDigest': session.sourceDigest,
      'ownerServerId': session.ownerServerId,
      'mcpServerId': session.mcpServerId,
      'toolName': tool.name,
      'exposedToolName': tool.exposedName,
      'outcome': outcome,
      'durationMs': durationMs.clamp(0, 24 * 60 * 60 * 1000),
      if (errorType != null) 'errorType': errorType,
    };
    final line = '${jsonEncode(entry)}\n';
    final lineBytes = utf8.encode(line).length;
    if (lineBytes > 4096) {
      throw const FormatException('skill_mcp_audit_entry_too_large');
    }
    if (await file.exists()) {
      final length = await file.length();
      if (length + lineBytes > maxAuditBytes) {
        final rotated = File('${file.path}.1');
        final rotatedType = await FileSystemEntity.type(
          rotated.path,
          followLinks: false,
        );
        if (rotatedType == FileSystemEntityType.link ||
            rotatedType == FileSystemEntityType.directory) {
          throw StateError('skill_mcp_audit_rotation_target_invalid');
        }
        if (await rotated.exists()) await rotated.delete();
        await file.rename(rotated.path);
      }
    }
    await file.writeAsString(
      line,
      mode: FileMode.append,
      flush: true,
    );
  }

  Future<List<SkillMcpToolDescriptor>> listTools({
    required String skillId,
    required String ownerServerId,
  }) => _serialize(() async {
    await _loaded;
    final session = _requireActiveSession(skillId, ownerServerId);
    final registration = await _findRegistration(skillId, ownerServerId);
    _requireSameSnapshot(session.registration, registration);
    _ensureSkillEnabled(skillId);
    final tools = await mcp.listSkillOwnedTools(
      serverId: session.mcpServerId,
      skillId: session.skillId,
      ownerServerId: session.ownerServerId,
      sourceDigest: session.sourceDigest,
    );
    final after = await _findRegistration(skillId, ownerServerId);
    _requireSameSnapshot(registration, after);
    _ensureSkillEnabled(skillId);
    return List<SkillMcpToolDescriptor>.unmodifiable([
      for (final tool in tools) _describeTool(session, tool),
    ]);
  });

  Future<mcp_client.CallToolResult> callTool({
    required String skillId,
    required String ownerServerId,
    required String exposedToolName,
    required Map<String, dynamic> arguments,
    required SkillMcpToolApprovalCallback confirm,
  }) => _serialize(() async {
    await _loaded;
    final session = _requireActiveSession(skillId, ownerServerId);
    final registration = await _findRegistration(skillId, ownerServerId);
    _requireSameSnapshot(session.registration, registration);
    _ensureSkillEnabled(skillId);

    final available = await mcp.listSkillOwnedTools(
      serverId: session.mcpServerId,
      skillId: session.skillId,
      ownerServerId: session.ownerServerId,
      sourceDigest: session.sourceDigest,
    );
    final matches = <({McpToolConfig tool, SkillMcpToolDescriptor descriptor})>[];
    for (final tool in available) {
      final descriptor = _describeTool(session, tool);
      if (descriptor.exposedName == exposedToolName) {
        matches.add((tool: tool, descriptor: descriptor));
      }
    }
    if (matches.length != 1) {
      throw StateError('skill_mcp_tool_not_found_or_namespace_mismatch');
    }
    final selected = matches.single;
    final schema = selected.tool.schema;
    if (schema == null) {
      throw const FormatException('skill_mcp_tool_input_schema_missing');
    }
    _validateToolSchema(schema);
    _validateToolArguments(arguments, schema);
    final schemaJson = jsonEncode(schema);
    final schemaDigest = sha256.convert(
      utf8.encode(_canonicalJson(schema)),
    ).toString();
    final previewSecrets = <String>[];
    for (final variableName
        in registration.descriptor.requiredEnvironmentVariables) {
      final value = await _secretStore.readVariable(registration, variableName);
      if (value != null && value.isNotEmpty) previewSecrets.add(value);
    }
    final preview = SkillMcpToolCallPreview(
      tool: selected.descriptor,
      redactedArguments: Map<String, Object?>.unmodifiable(
        _redactMap(arguments, previewSecrets),
      ),
    );
    final stopwatch = Stopwatch()..start();
    var approvalWritten = false;
    try {
      final result = await mcp.callSkillOwnedTool(
        serverId: session.mcpServerId,
        skillId: session.skillId,
        ownerServerId: session.ownerServerId,
        sourceDigest: session.sourceDigest,
        toolName: selected.tool.name,
        args: arguments,
        expectedInputSchemaJson: schemaJson,
        confirmApproval: () async {
          final approved = await confirm(preview);
          await _recordToolAudit(
            session: session,
            tool: selected.descriptor,
            outcome: approved ? 'approved' : 'denied',
            durationMs: stopwatch.elapsedMilliseconds,
          );
          approvalWritten = true;
          return approved;
        },
        revalidateOwner: () async {
          final current = await _findRegistration(skillId, ownerServerId);
          _requireSameSnapshot(registration, current);
          _ensureSkillEnabled(skillId);
          final digest = sha256.convert(
            utf8.encode(_canonicalJson(schema)),
          ).toString();
          if (digest != schemaDigest) {
            throw StateError('skill_mcp_tool_schema_changed');
          }
        },
      );
      final current = await _findRegistration(skillId, ownerServerId);
      _requireSameSnapshot(registration, current);
      _ensureSkillEnabled(skillId);
      final secrets = <String>[];
      for (final variableName
          in registration.descriptor.requiredEnvironmentVariables) {
        final value = await _secretStore.readVariable(
          registration,
          variableName,
        );
        if (value != null && value.isNotEmpty) secrets.add(value);
      }
      final redactedResult = _redactToolResult(result, secrets);
      await _recordToolAudit(
        session: session,
        tool: selected.descriptor,
        outcome: 'success',
        durationMs: stopwatch.elapsedMilliseconds,
      );
      return redactedResult;
    } on SkillMcpProviderApprovalDenied {
      if (!approvalWritten) {
        await _recordToolAudit(
          session: session,
          tool: selected.descriptor,
          outcome: 'denied',
          durationMs: stopwatch.elapsedMilliseconds,
        );
      }
      throw const SkillMcpToolApprovalDenied();
    } catch (error) {
      await _recordToolAudit(
        session: session,
        tool: selected.descriptor,
        outcome: 'failed',
        durationMs: stopwatch.elapsedMilliseconds,
        errorType: error.runtimeType.toString(),
      );
      rethrow;
    } finally {
      stopwatch.stop();
    }
  });

  _ActiveSkillMcpSession _requireActiveSession(
    String skillId,
    String ownerServerId,
  ) {
    final session = _activeSessions[ownerServerId];
    if (session == null || session.skillId != skillId) {
      throw StateError('skill_mcp_session_not_active_or_owner_mismatch');
    }
    if (!mcp.isConnected(session.mcpServerId)) {
      throw StateError('skill_mcp_session_not_connected');
    }
    return session;
  }

  SkillMcpToolDescriptor _describeTool(
    _ActiveSkillMcpSession session,
    McpToolConfig tool,
  ) {
    final schema = tool.schema;
    if (schema == null) {
      throw const FormatException('skill_mcp_tool_input_schema_missing');
    }
    _validateToolSchema(schema);
    final identity = <String>[
      session.skillId,
      session.ownerServerId,
      session.sourceDigest,
      tool.name,
    ].join('\u0000');
    final suffix = sha256
        .convert(utf8.encode(identity))
        .toString()
        .substring(0, 12);
    final sanitized = tool.name
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')
        .replaceAll(RegExp(r'^[_-]+'), '');
    final base = sanitized.isEmpty ? 'tool' : sanitized;
    final prefixLength = 64 - 'skill_'.length - 1 - suffix.length;
    final prefix = base.length > prefixLength
        ? base.substring(0, prefixLength)
        : base;
    return SkillMcpToolDescriptor(
      skillId: session.skillId,
      ownerServerId: session.ownerServerId,
      sourceDigest: session.sourceDigest,
      mcpServerId: session.mcpServerId,
      name: tool.name,
      exposedName: 'skill_${prefix}_$suffix',
      description: tool.description ?? '',
      inputSchema: Map<String, dynamic>.unmodifiable(
        Map<String, dynamic>.from(jsonDecode(jsonEncode(schema)) as Map),
      ),
    );
  }

  String _canonicalJson(Object? value) {
    Object? canonicalize(Object? item) {
      if (item is Map) {
        final keys = item.keys.whereType<String>().toList()..sort();
        return <String, Object?>{
          for (final key in keys) key: canonicalize(item[key]),
        };
      }
      if (item is List) {
        return item.map(canonicalize).toList(growable: false);
      }
      return item;
    }

    return jsonEncode(canonicalize(value));
  }

  void _validateToolSchema(Map<String, dynamic> schema) {
    final encoded = _canonicalJson(schema);
    if (utf8.encode(encoded).length > maxInputSchemaBytes) {
      throw const FormatException('skill_mcp_tool_schema_too_large');
    }
    var nodes = 0;
    void inspect(Object? value, int depth) {
      nodes++;
      if (nodes > 2048 || depth > 16) {
        throw const FormatException('skill_mcp_tool_schema_complexity_limit');
      }
      if (value is Map) {
        if (value.containsKey(r'$ref') ||
            value.containsKey(r'$dynamicRef') ||
            value.containsKey(r'$recursiveRef')) {
          throw const FormatException('skill_mcp_tool_schema_remote_ref_unsupported');
        }
        for (final entry in value.entries) {
          if (entry.key is! String) {
            throw const FormatException('invalid_skill_mcp_tool_schema_key');
          }
          inspect(entry.value, depth + 1);
        }
      } else if (value is List) {
        if (value.length > 512) {
          throw const FormatException('skill_mcp_tool_schema_list_limit');
        }
        for (final item in value) {
          inspect(item, depth + 1);
        }
      } else if (value != null &&
          value is! String &&
          value is! num &&
          value is! bool) {
        throw const FormatException('invalid_skill_mcp_tool_schema_value');
      }
    }

    inspect(schema, 0);
    final required = schema['required'];
    if (required != null &&
        (required is! List ||
            required.any((value) => value is! String) ||
            required.toSet().length != required.length)) {
      throw const FormatException('invalid_skill_mcp_tool_schema_required');
    }
    final properties = schema['properties'];
    if (properties != null && properties is! Map) {
      throw const FormatException('invalid_skill_mcp_tool_schema_properties');
    }
    if (properties is Map && properties.length > 256) {
      throw const FormatException('skill_mcp_tool_schema_property_limit');
    }
  }

  void _validateToolArguments(
    Map<String, dynamic> arguments,
    Map<String, dynamic> schema,
  ) {
    final encoded = _canonicalJson(arguments);
    if (utf8.encode(encoded).length > maxToolArgumentsBytes) {
      throw const FormatException('skill_mcp_tool_arguments_too_large');
    }
    _validateSchemaValue(arguments, schema, r'$');
  }

  void _validateSchemaValue(
    Object? value,
    Map<String, dynamic> schema,
    String path, {
    int depth = 0,
  }) {
    if (depth > 16) {
      throw FormatException('skill_mcp_tool_argument_depth_limit:$path');
    }
    if (schema.containsKey(r'$ref') ||
        schema.containsKey(r'$dynamicRef') ||
        schema.containsKey(r'$recursiveRef')) {
      throw const FormatException('skill_mcp_tool_schema_remote_ref_unsupported');
    }
    final allOf = schema['allOf'];
    if (allOf is List) {
      for (final branch in allOf.whereType<Map>()) {
        _validateSchemaValue(
          value,
          Map<String, dynamic>.from(branch),
          path,
          depth: depth + 1,
        );
      }
    }
    final anyOf = schema['anyOf'];
    if (anyOf is List && anyOf.isNotEmpty) {
      var matched = false;
      for (final branch in anyOf.whereType<Map>()) {
        try {
          _validateSchemaValue(
            value,
            Map<String, dynamic>.from(branch),
            path,
            depth: depth + 1,
          );
          matched = true;
          break;
        } on FormatException {
          // Continue until one branch validates.
        }
      }
      if (!matched) {
        throw FormatException('skill_mcp_tool_argument_any_of:$path');
      }
    }
    final oneOf = schema['oneOf'];
    if (oneOf is List && oneOf.isNotEmpty) {
      var matches = 0;
      for (final branch in oneOf.whereType<Map>()) {
        try {
          _validateSchemaValue(
            value,
            Map<String, dynamic>.from(branch),
            path,
            depth: depth + 1,
          );
          matches++;
        } on FormatException {
          // Count only matching branches.
        }
      }
      if (matches != 1) {
        throw FormatException('skill_mcp_tool_argument_one_of:$path');
      }
    }
    final enumValues = schema['enum'];
    if (enumValues is List &&
        !enumValues.any((item) => _jsonEqual(item, value))) {
      throw FormatException('skill_mcp_tool_argument_enum:$path');
    }
    if (schema.containsKey('const') && !_jsonEqual(schema['const'], value)) {
      throw FormatException('skill_mcp_tool_argument_const:$path');
    }

    final rawType = schema['type'];
    final types = rawType is String
        ? <String>[rawType]
        : rawType is List
            ? rawType.whereType<String>().toList()
            : <String>['object'];
    if (!types.any((type) => _matchesJsonType(value, type))) {
      throw FormatException('skill_mcp_tool_argument_type:$path');
    }

    if (value is Map) {
      final required = schema['required'];
      if (required is List) {
        for (final field in required.whereType<String>()) {
          if (!value.containsKey(field)) {
            throw FormatException('skill_mcp_tool_argument_required:$path.$field');
          }
        }
      }
      final properties = schema['properties'];
      if (properties is Map) {
        for (final entry in value.entries) {
          final propertySchema = properties[entry.key];
          if (propertySchema is Map) {
            _validateSchemaValue(
              entry.value,
              Map<String, dynamic>.from(propertySchema),
              '$path.${entry.key}',
              depth: depth + 1,
            );
          } else if (schema['additionalProperties'] == false) {
            throw FormatException(
              'skill_mcp_tool_argument_additional:$path.${entry.key}',
            );
          } else if (schema['additionalProperties'] is Map) {
            _validateSchemaValue(
              entry.value,
              Map<String, dynamic>.from(schema['additionalProperties'] as Map),
              '$path.${entry.key}',
              depth: depth + 1,
            );
          }
        }
      } else if (schema['additionalProperties'] == false && value.isNotEmpty) {
        throw FormatException('skill_mcp_tool_argument_additional:$path');
      }
      final min = schema['minProperties'];
      final max = schema['maxProperties'];
      if ((min is int && value.length < min) ||
          (max is int && value.length > max)) {
        throw FormatException('skill_mcp_tool_argument_property_count:$path');
      }
    } else if (value is List) {
      final min = schema['minItems'];
      final max = schema['maxItems'];
      if ((min is int && value.length < min) ||
          (max is int && value.length > max)) {
        throw FormatException('skill_mcp_tool_argument_item_count:$path');
      }
      final itemSchema = schema['items'];
      if (itemSchema is Map) {
        for (var i = 0; i < value.length; i++) {
          _validateSchemaValue(
            value[i],
            Map<String, dynamic>.from(itemSchema),
            '$path[$i]',
            depth: depth + 1,
          );
        }
      }
    } else if (value is String) {
      final min = schema['minLength'];
      final max = schema['maxLength'];
      if ((min is int && value.length < min) ||
          (max is int && value.length > max)) {
        throw FormatException('skill_mcp_tool_argument_string_length:$path');
      }
      final pattern = schema['pattern'];
      if (pattern is String && !RegExp(pattern).hasMatch(value)) {
        throw FormatException('skill_mcp_tool_argument_pattern:$path');
      }
    } else if (value is num && value is! bool) {
      final min = schema['minimum'];
      final max = schema['maximum'];
      if ((min is num && value < min) || (max is num && value > max)) {
        throw FormatException('skill_mcp_tool_argument_numeric_range:$path');
      }
    }
  }

  bool _matchesJsonType(Object? value, String type) => switch (type) {
    'object' => value is Map,
    'array' => value is List,
    'string' => value is String,
    'number' => value is num && value is! bool,
    'integer' => value is int,
    'boolean' => value is bool,
    'null' => value == null,
    _ => false,
  };

  bool _jsonEqual(Object? left, Object? right) =>
      _canonicalJson(left) == _canonicalJson(right);

  Map<String, Object?> _redactMap(
    Map<String, dynamic> source,
    List<String> secrets,
  ) => Map<String, Object?>.from(
    _redactJson(source, secrets) as Map,
  );

  Object? _redactJson(Object? value, List<String> secrets, {String? key}) {
    const sensitiveKeyParts = <String>[
      'password',
      'passwd',
      'token',
      'secret',
      'authorization',
      'credential',
      'private_key',
      'apikey',
      'api_key',
    ];
    if (key != null &&
        sensitiveKeyParts.any((part) => key.toLowerCase().contains(part))) {
      return '[REDACTED]';
    }
    if (value is String) {
      var sanitized = value;
      final sortedSecrets = secrets.where((secret) => secret.length >= 4).toList()
        ..sort((a, b) => b.length.compareTo(a.length));
      for (final secret in sortedSecrets) {
        sanitized = sanitized.replaceAll(secret, '[REDACTED]');
      }
      return sanitized;
    }
    if (value is Map) {
      return <String, Object?>{
        for (final entry in value.entries)
          if (entry.key is String)
            entry.key as String: _redactJson(
              entry.value,
              secrets,
              key: entry.key as String,
            ),
      };
    }
    if (value is List) {
      return value
          .map((item) => _redactJson(item, secrets))
          .toList(growable: false);
    }
    return value;
  }

  mcp_client.CallToolResult _redactToolResult(
    mcp_client.CallToolResult result,
    List<String> secrets,
  ) {
    if (result.content.length > maxToolResultItems) {
      throw const FormatException('skill_mcp_tool_result_item_limit');
    }
    final sanitizedContent = <mcp_client.Content>[];
    for (final item in result.content) {
      final raw = _redactJson(item.toJson(), secrets);
      if (raw is! Map) {
        throw const FormatException('invalid_skill_mcp_tool_result_content');
      }
      sanitizedContent.add(
        mcp_client.Content.fromJson(Map<String, dynamic>.from(raw)),
      );
    }
    final structured = result.structuredContent == null
        ? null
        : _redactJson(result.structuredContent, secrets) as Map<String, dynamic>;
    final sanitized = mcp_client.CallToolResult(
      List<mcp_client.Content>.unmodifiable(sanitizedContent),
      structuredContent: structured,
      isError: result.isError,
    );
    if (utf8.encode(jsonEncode(sanitized.toJson())).length > maxToolResultBytes) {
      throw const FormatException('skill_mcp_tool_result_too_large');
    }
    return sanitized;
  }

  void _onSkillsChanged() {
    if (_disposed) return;
    _reconcilePending = true;
    if (_reconcileScheduled) return;
    _reconcileScheduled = true;
    unawaited(_runLifecycleReconciliation());
  }

  Future<void> _runLifecycleReconciliation() async {
    try {
      do {
        _reconcilePending = false;
        await _serialize(() async {
          await _loaded;
          if (_disposed) return;
          final sessions = _activeSessions.values.toList(growable: false);
          for (final session in sessions) {
            if (_disposed ||
                !identical(
                  _activeSessions[session.ownerServerId],
                  session,
                )) {
              continue;
            }
            Skill? installedSkill;
            for (final skill in skills.skills) {
              if (skill.record.id == session.skillId) {
                installedSkill = skill;
                break;
              }
            }
            final enabled = installedSkill?.record.enabled == true;
            var ownerSnapshotCurrent = false;
            // Source trust is independent from the user's enabled switch.
            // Validate the owner snapshot even when disabled so its secure
            // credentials can be retained for a later re-enable.
            if (installedSkill != null) {
              try {
                final registration = await _findRegistration(
                  session.skillId,
                  session.ownerServerId,
                );
                _requireSameSnapshot(session.registration, registration);
                ownerSnapshotCurrent = true;
              } catch (_) {
                ownerSnapshotCurrent = false;
              }
            }
            if (!enabled || !ownerSnapshotCurrent) {
              // Keep credentials when the user only disables the Skill.
              // A deletion or source/manifest change revokes the old trust
              // binding and therefore removes credentials bound to its digest.
              await _removeActiveSession(
                session,
                clearCredentials: !ownerSnapshotCurrent,
              );
            }
          }
        });
      } while (_reconcilePending && !_disposed);
    } finally {
      _reconcileScheduled = false;
      if (_reconcilePending && !_disposed) _onSkillsChanged();
    }
  }

  Future<void> _removeActiveSession(
    _ActiveSkillMcpSession session, {
    required bool clearCredentials,
  }) async {
    if (!identical(_activeSessions[session.ownerServerId], session)) return;
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
    await _removeActiveSession(
      session,
      clearCredentials: clearCredentials,
    );
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
      await _removeActiveSession(
        session,
        clearCredentials: clearCredentials,
      );
    }
  });

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    skills.removeListener(_onSkillsChanged);
    await _serialize(() async {
      await _loaded;
      final sessions = _activeSessions.values.toList(growable: false);
      for (final session in sessions) {
        await _removeActiveSession(session, clearCredentials: false);
      }
    });
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
