import 'dart:convert';

/// Read-only parser for MCP server declarations stored inside an Agent Skill.
/// It never registers, connects, launches, or calls an MCP server.
enum SkillMcpTransport { stdio, http, sse }

final class SkillMcpServerDescriptor {
  const SkillMcpServerDescriptor({
    required this.name,
    required this.transport,
    required this.configPath,
    this.command,
    this.arguments = const <String>[],
    this.requiredEnvironmentVariables = const <String>[],
    this.url,
  });

  final String name;
  final SkillMcpTransport transport;
  final String configPath;
  final String? command;
  final List<String> arguments;
  /// Variable names only. Imported environment values are never retained.
  final List<String> requiredEnvironmentVariables;
  final Uri? url;

  bool get requiresManualApproval => true;
  bool get executionSupported => false;
}

abstract final class SkillMcpConfigParser {
  static const int maxConfigBytes = 1024 * 1024;
  static const int maxServers = 32;
  static const int maxArguments = 64;
  static const int maxEnvironmentVariables = 32;

  static final RegExp _serverName = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$');
  static final RegExp _command = RegExp(r'^[A-Za-z0-9_./+-]{1,256}$');
  static final RegExp _environmentName = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');
  static final RegExp _environmentReference = RegExp(r'^\$\{([A-Za-z_][A-Za-z0-9_]*)\}$');

  static List<SkillMcpServerDescriptor> parse(String source, {String configPath = 'mcp.json'}) {
    if (utf8.encode(source).length > maxConfigBytes) {
      throw const FormatException('skill_mcp_config_too_large');
    }
    _validateConfigPath(configPath);
    final decoded = _decodeJson(source);
    if (decoded is! Map) throw const FormatException('invalid_skill_mcp_config_root');
    final rawServers = decoded['mcpServers'];
    if (rawServers is! Map || rawServers.isEmpty) {
      throw const FormatException('skill_mcp_servers_missing');
    }
    if (rawServers.length > maxServers) {
      throw const FormatException('too_many_skill_mcp_servers');
    }

    final descriptors = <SkillMcpServerDescriptor>[];
    final names = <String>{};
    for (final entry in rawServers.entries) {
      if (entry.key is! String || entry.value is! Map) {
        throw const FormatException('invalid_skill_mcp_server_entry');
      }
      final name = (entry.key as String).trim();
      if (!_serverName.hasMatch(name) || !names.add(name.toLowerCase())) {
        throw const FormatException('invalid_or_duplicate_skill_mcp_server_name');
      }
      final config = <String, Object?>{};
      for (final field in (entry.value as Map).entries) {
        if (field.key is! String) throw const FormatException('invalid_skill_mcp_server_field');
        config[field.key as String] = field.value;
      }
      final rawCommand = config['command'];
      final rawUrl = config['url'] ?? config['baseUrl'];
      if (rawCommand != null) {
        if (rawUrl != null) throw const FormatException('ambiguous_skill_mcp_transport');
        descriptors.add(_parseStdio(name, config, configPath));
      } else {
        descriptors.add(_parseRemote(name, config, rawUrl, configPath));
      }
    }
    descriptors.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return List<SkillMcpServerDescriptor>.unmodifiable(descriptors);
  }

  static Object? _decodeJson(String source) {
    try {
      return jsonDecode(source);
    } catch (_) {
      // Never echo malformed source: it may contain credentials.
      throw const FormatException('invalid_skill_mcp_config_json');
    }
  }

  static SkillMcpServerDescriptor _parseStdio(
    String name, Map<String, Object?> config, String configPath,
  ) {
    final command = config['command'];
    if (command is! String || !_command.hasMatch(command.trim())) {
      throw const FormatException('invalid_skill_mcp_stdio_command');
    }
    final rawArgs = config['args'];
    final args = <String>[];
    if (rawArgs != null) {
      if (rawArgs is! List || rawArgs.length > maxArguments) {
        throw const FormatException('invalid_skill_mcp_stdio_arguments');
      }
      for (final item in rawArgs) {
        if (item is! String || item.length > 4096 || item.contains('\u0000')) {
          throw const FormatException('invalid_skill_mcp_stdio_argument');
        }
        args.add(item);
      }
    }
    return SkillMcpServerDescriptor(
      name: name,
      transport: SkillMcpTransport.stdio,
      configPath: configPath,
      command: command.trim(),
      arguments: List<String>.unmodifiable(args),
      requiredEnvironmentVariables: _parseEnvironmentNames(config['env']),
    );
  }

  static List<String> _parseEnvironmentNames(Object? raw) {
    if (raw == null) return const <String>[];
    if (raw is! Map || raw.length > maxEnvironmentVariables) {
      throw const FormatException('invalid_skill_mcp_environment');
    }
    final names = <String>{};
    for (final entry in raw.entries) {
      if (entry.key is! String || entry.value is! String) {
        throw const FormatException('invalid_skill_mcp_environment_entry');
      }
      final key = (entry.key as String).trim();
      final value = entry.value as String;
      if (!_environmentName.hasMatch(key)) {
        throw const FormatException('invalid_skill_mcp_environment_name');
      }
      if (value.isEmpty) {
        names.add(key);
        continue;
      }
      final reference = _environmentReference.firstMatch(value.trim());
      if (reference != null) {
        names.add(reference.group(1)!);
        continue;
      }
      throw FormatException('literal_skill_mcp_environment_value_requires_secure_setup:$key');
    }
    final sorted = names.toList()..sort();
    return List<String>.unmodifiable(sorted);
  }

  static SkillMcpServerDescriptor _parseRemote(
    String name, Map<String, Object?> config, Object? rawUrl, String configPath,
  ) {
    if (rawUrl is! String || rawUrl.trim().isEmpty) {
      throw const FormatException('unsupported_skill_mcp_transport');
    }
    final rawType = (config['type'] ?? config['transport'] ?? 'http')
        .toString().trim().toLowerCase();
    final transport = switch (rawType) {
      'http' || 'streamablehttp' || 'streamable_http' => SkillMcpTransport.http,
      'sse' => SkillMcpTransport.sse,
      _ => throw const FormatException('unsupported_skill_mcp_remote_transport'),
    };
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty ||
        uri.scheme.toLowerCase() != 'https' || uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty || uri.hasQuery) {
      throw const FormatException('skill_mcp_remote_url_requires_clean_https_endpoint');
    }
    final headers = config['headers'];
    if (headers is Map && headers.isNotEmpty) {
      throw const FormatException('skill_mcp_remote_headers_require_secure_credential_setup');
    }
    if (headers != null && headers is! Map) {
      throw const FormatException('invalid_skill_mcp_remote_headers');
    }
    return SkillMcpServerDescriptor(
      name: name, transport: transport, configPath: configPath, url: uri,
    );
  }

  static void _validateConfigPath(String path) {
    if (path.isEmpty || path.length > 240 || path.startsWith('/') ||
        path.contains(r'\') ||
        path.split('/').any((part) => part.isEmpty || part == '.' || part == '..')) {
      throw const FormatException('unsafe_skill_mcp_config_path');
    }
  }
}
