import 'dart:convert';

import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/services/mcp/remote_skill_discovery_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mcp_client/mcp_client.dart' as mcp;

const _skillUri = 'skill://remote-guide/SKILL.md';
const _markdown =
    '---\n'
    'name: remote-guide\n'
    'description: A remote guide for testing metadata-first discovery.\n'
    'license: MIT\n'
    '---\n\n'
    'Untrusted remote content.';

Map<String, dynamic> _manifest() => <String, dynamic>{
  'uri': _skillUri,
  'frontmatter': <String, dynamic>{
    'name': 'remote-guide',
    'description': 'A remote guide for testing metadata-first discovery.',
    'license': 'MIT',
  },
  'resources': <Map<String, dynamic>>[
    <String, dynamic>{
      'uri': _skillUri,
      'digest': 'sha256:${sha256.convert(utf8.encode(_markdown))}',
      'size': utf8.encode(_markdown).length,
    },
  ],
};

Map<String, dynamic> _reply(int id, Map<String, dynamic> result) =>
    <String, dynamic>{
      'jsonrpc': mcp.McpProtocol.jsonRpcVersion,
      'id': id,
      'result': result,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  McpServerConfig server({
    bool enabled = true,
    McpTransportType transport = McpTransportType.http,
    String url = 'https://mcp.example.test/mcp',
    Map<String, String> headers = const <String, String>{},
    McpOAuthState? oauth,
  }) => McpServerConfig(
    id: 'configured-remote-source',
    enabled: enabled,
    name: 'Configured Remote',
    transport: transport,
    url: url,
    headers: headers,
    oauth: oauth,
  );

  test('lists metadata after connect and reads content only on explicit call', () async {
    final requests = <Map<String, dynamic>>[];
    final mock = MockClient((request) async {
      final message = jsonDecode(request.body) as Map<String, dynamic>;
      requests.add(message);
      final method = message['method'];
      if (method == mcp.McpProtocol.methodServerDiscover) {
        return http.Response(
          jsonEncode(
            _reply(1, <String, dynamic>{
              'resultType': 'complete',
              'supportedVersions': <String>[mcp.McpProtocol.v2026_07_28],
              'capabilities': <String, dynamic>{
                'resources': <String, dynamic>{},
                'extensions': <String, dynamic>{
                  mcp.McpProtocol.skillsExtensionId: <String, dynamic>{},
                },
              },
              '_meta': <String, dynamic>{
                mcp.McpProtocol.metaServerInfo: <String, dynamic>{
                  'name': 'Example Skills',
                  'version': '1.0.0',
                },
              },
              'ttlMs': 60000,
              'cacheScope': 'private',
            }),
          ),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }
      if (method == mcp.McpProtocol.methodListSkills) {
        return http.Response(
          jsonEncode(
            _reply(2, <String, dynamic>{
              'resultType': 'complete',
              'skills': <Map<String, dynamic>>[_manifest()],
              'ttlMs': 60000,
              'cacheScope': 'private',
            }),
          ),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }
      if (method == 'resources/read') {
        return http.Response(
          jsonEncode(
            _reply(3, <String, dynamic>{
              'resultType': 'complete',
              'ttlMs': 60000,
              'cacheScope': 'private',
              'contents': <Map<String, dynamic>>[
                <String, dynamic>{
                  'uri': _skillUri,
                  'mimeType': 'text/markdown',
                  'text': _markdown,
                },
              ],
            }),
          ),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }
      return http.Response('', 404);
    });
    final service = RemoteSkillDiscoveryService(
      httpClientFactory: (_) async => mock,
    );

    final session = await service.connect(server());
    addTearDown(session.dispose);
    expect(session.serverInfo['name'], 'Example Skills');
    expect(
      requests.map((message) => message['method']),
      <String>[mcp.McpProtocol.methodServerDiscover],
    );

    final listing = await session.listSkills();
    expect(listing.skills, hasLength(1));
    expect(listing.skills.single.name, 'remote-guide');
    expect(
      requests.map((message) => message['method']),
      <String>[
        mcp.McpProtocol.methodServerDiscover,
        mcp.McpProtocol.methodListSkills,
      ],
    );
    expect(requests.any((message) => message['method'] == 'resources/read'), isFalse);

    final verified = await session.readSkillResource(
      snapshot: listing.snapshots.single,
      uri: _skillUri,
    );
    expect(verified.text, _markdown);
    expect(verified.digest, 'sha256:${sha256.convert(utf8.encode(_markdown))}');
    expect(requests.last['method'], 'resources/read');
  });

  test('rejects disabled, non-HTTP and non-HTTPS sources before opening a client', () async {
    var factoryCalls = 0;
    final service = RemoteSkillDiscoveryService(
      httpClientFactory: (_) async {
        factoryCalls++;
        return MockClient((_) async => http.Response('', 500));
      },
    );

    await expectLater(
      service.connect(server(enabled: false)),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      service.connect(server(transport: McpTransportType.sse)),
      throwsA(isA<UnsupportedError>()),
    );
    await expectLater(
      service.connect(server(url: 'http://mcp.example.test/mcp')),
      throwsA(isA<FormatException>()),
    );
    expect(factoryCalls, 0);
  });

  test('rejects reserved, malformed and duplicated HTTP headers before connect', () async {
    var factoryCalls = 0;
    final service = RemoteSkillDiscoveryService(
      httpClientFactory: (_) async {
        factoryCalls++;
        return MockClient((_) async => http.Response('', 500));
      },
    );

    await expectLater(
      service.connect(server(headers: const <String, String>{'Host': 'evil.test'})),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      service.connect(server(headers: const <String, String>{'X-Test': 'ok\r\nAuthorization: Bearer leak'})),
      throwsA(isA<FormatException>()),
    );
    expect(factoryCalls, 0);
  });

  test('fails closed on an expired OAuth token when no explicit auth header exists', () async {
    var factoryCalls = 0;
    final service = RemoteSkillDiscoveryService(
      clock: () => DateTime.utc(2026, 11, 26),
      httpClientFactory: (_) async {
        factoryCalls++;
        return MockClient((_) async => http.Response('', 500));
      },
    );
    final expired = McpOAuthState(
      clientId: 'client',
      authorizationServer: 'https://auth.example.test',
      authorizationEndpoint: 'https://auth.example.test/authorize',
      tokenEndpoint: 'https://auth.example.test/token',
      serverUrl: 'https://mcp.example.test/mcp',
      resource: 'https://mcp.example.test/mcp',
      accessToken: 'expired-token',
      expiresAt: DateTime.utc(2026, 11, 25),
    );
    await expectLater(
      service.connect(server(oauth: expired)),
      throwsA(isA<StateError>()),
    );
    expect(factoryCalls, 0);
  });

  test('does not expose a read operation for resources other than SKILL.md', () async {
    final mock = MockClient((request) async {
      final message = jsonDecode(request.body) as Map<String, dynamic>;
      final id = message['id'] as int;
      return http.Response(
        jsonEncode(
          _reply(id, <String, dynamic>{
            'resultType': 'complete',
            'supportedVersions': <String>[mcp.McpProtocol.v2026_07_28],
            'capabilities': <String, dynamic>{
              'resources': <String, dynamic>{},
              'extensions': <String, dynamic>{
                mcp.McpProtocol.skillsExtensionId: <String, dynamic>{},
              },
            },
            'ttlMs': 60000,
            'cacheScope': 'private',
          }),
        ),
        200,
        headers: const <String, String>{'content-type': 'application/json'},
      );
    });
    final service = RemoteSkillDiscoveryService(
      httpClientFactory: (_) async => mock,
    );
    // Connect succeeds; the read facade refuses URI changes without sending
    // any follow-up network request.
    final session = await service.connect(server());
    addTearDown(session.dispose);
    final before = requestsCount;
    expect(before, 0);
    expect(
      () => session.readSkillResource(
        snapshot: mcp.McpSkillSnapshotTestingOnly,
        uri: 'skill://remote-guide/references/other.md',
      ),
      throwsA(anything),
    );
  });
}

const int requestsCount = 0;
