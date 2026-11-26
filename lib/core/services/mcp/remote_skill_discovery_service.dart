import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/services/mcp/mcp_oauth_http_client.dart';
import 'package:http/http.dart' as http;
import 'package:mcp_client/mcp_client.dart' as mcp;

/// Injectable only at the HTTP-client boundary so the service can be tested
/// with deterministic protocol fixtures. Production always uses DNS pinning.
typedef RemoteSkillsHttpClientFactory = Future<http.Client> Function(Uri endpoint);

final class RemoteSkillDiscoveryService {
  RemoteSkillDiscoveryService({
    RemoteSkillsHttpClientFactory? httpClientFactory,
    DateTime Function()? clock,
  }) : _httpClientFactory =
           httpClientFactory ?? createMcpSkillsPinnedHttpClient,
       _clock = clock ?? DateTime.now;

  final RemoteSkillsHttpClientFactory _httpClientFactory;
  final DateTime Function() _clock;

  Future<RemoteSkillDiscoverySession> connect(McpServerConfig server) async {
    if (!server.enabled) {
      throw StateError('remote_skills_server_disabled');
    }
    if (server.transport != McpTransportType.http) {
      throw UnsupportedError('remote_skills_requires_streamable_http');
    }
    final endpoint = Uri.tryParse(server.url);
    if (endpoint == null ||
        endpoint.scheme != 'https' ||
        !endpoint.hasAuthority ||
        endpoint.host.trim().isEmpty ||
        endpoint.userInfo.isNotEmpty ||
        endpoint.hasFragment ||
        endpoint.port < 1) {
      throw const FormatException(
        'remote_skills_endpoint_requires_https_without_userinfo_or_fragment',
      );
    }

    final headers = _validatedHeaders(server);
    final httpClient = await _httpClientFactory(endpoint);
    mcp.Client? client;
    mcp.McpSkillsExtension? skills;
    try {
      final transport = await mcp.StreamableHttpClientTransport.create(
        baseUrl: server.url,
        headers: headers,
        timeout: const Duration(seconds: 30),
        maxResponseBytes: 24 * 1024 * 1024,
        terminateOnClose: false,
        httpClient: httpClient,
      );
      client = mcp.Client(
        name: 'KELIVO Remote Skills',
        version: '1.3.4',
        protocolVersion: mcp.McpProtocol.v2026_07_28,
        requestTimeout: const Duration(seconds: 30),
      );
      await client.connect(transport);
      final identity =
          'kelivo-remote:${server.id}@${endpoint.origin}${endpoint.path}';
      skills = mcp.McpSkillsExtension(
        client: client,
        serverIdentity: identity,
      );
      if (!skills.isSupported) {
        throw UnsupportedError('remote_skills_extension_not_advertised');
      }
      return RemoteSkillDiscoverySession._(
        server: server,
        endpoint: endpoint,
        client: client,
        skills: skills,
      );
    } catch (_) {
      if (skills != null) await skills.dispose();
      client?.dispose();
      httpClient.close();
      rethrow;
    }
  }

  Map<String, String> _validatedHeaders(McpServerConfig server) {
    final headers = <String, String>{};
    final seen = <String>{};
    var totalBytes = 0;
    if (server.headers.length > 32) {
      throw const FormatException('remote_skills_header_count_limit');
    }
    for (final entry in server.headers.entries) {
      final name = entry.key.trim();
      final value = entry.value;
      final lowerName = name.toLowerCase();
      if (!RegExp(r"^[!#$%&'*+.^_`|~0-9a-zA-Z-]+$").hasMatch(name) ||
          value.contains(RegExp(r'[\x00-\x1f\x7f]')) ||
          value.length > 8192 ||
          !seen.add(lowerName)) {
        throw const FormatException('remote_skills_header_invalid');
      }
      if (_restrictedHeaders.contains(lowerName)) {
        throw const FormatException('remote_skills_header_reserved');
      }
      totalBytes += name.length + value.length;
      if (totalBytes > 16384) {
        throw const FormatException('remote_skills_header_size_limit');
      }
      headers[name] = value;
    }

    if (!seen.contains('authorization') && server.oauth != null) {
      final oauth = server.oauth!;
      final expiresAt = oauth.expiresAt;
      if (expiresAt != null && !expiresAt.isAfter(_clock())) {
        throw StateError('remote_skills_oauth_token_expired_reauthorize_source');
      }
      if (oauth.accessToken.trim().isNotEmpty) {
        headers['Authorization'] = oauth.authorizationHeader;
      }
    }
    return Map<String, String>.unmodifiable(headers);
  }

  static const Set<String> _restrictedHeaders = <String>{
    'accept',
    'connection',
    'content-length',
    'content-type',
    'host',
    'keep-alive',
    'last-event-id',
    'mcp-method',
    'mcp-name',
    'mcp-protocol-version',
    'mcp-session-id',
    'proxy-authenticate',
    'proxy-authorization',
    'te',
    'trailer',
    'transfer-encoding',
    'upgrade',
  };
}

/// One explicitly opened Remote Skills discovery session.
///
/// It exposes only metadata listing and caller-approved reads of resources
/// declared in the selected Skill manifest. No tool or installation API is
/// exposed by this wrapper.
final class RemoteSkillDiscoverySession {
  RemoteSkillDiscoverySession._({
    required this.server,
    required this.endpoint,
    required mcp.Client client,
    required mcp.McpSkillsExtension skills,
  }) : _client = client,
       _skills = skills;

  final McpServerConfig server;
  final Uri endpoint;
  final mcp.Client _client;
  final mcp.McpSkillsExtension _skills;
  bool _disposed = false;

  Map<String, dynamic> get serverInfo =>
      Map<String, dynamic>.unmodifiable(_client.serverInfo ?? const {});

  Future<mcp.McpSkillsListResult> listSkills({
    String? cursor,
  }) {
    _ensureOpen();
    return _skills.listSkills(cursor: cursor);
  }

  Future<mcp.McpVerifiedSkillResource> readSkillResource({
    required mcp.McpSkillSnapshot snapshot,
    required String uri,
  }) {
    _ensureOpen();
    // The page currently offers SKILL.md only; the extension independently
    // enforces manifest membership, origin identity, size and digest checks.
    if (uri != snapshot.skill.uri) {
      throw const FormatException('remote_skills_read_must_target_skill_md');
    }
    return _skills.readSkillResource(snapshot: snapshot, uri: uri);
  }

  void _ensureOpen() {
    if (_disposed) throw StateError('remote_skills_session_disposed');
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _skills.dispose();
    _client.dispose();
  }
}
