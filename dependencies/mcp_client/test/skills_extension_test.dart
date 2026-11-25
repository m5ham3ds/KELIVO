import 'package:mcp_client/mcp_client.dart';
import 'package:test/test.dart';

import 'mock_transport.dart';

const _skillUri = 'skill://git-workflow/SKILL.md';

Map<String, dynamic> _manifest({
  String uri = _skillUri,
  String name = 'git-workflow',
  List<Map<String, dynamic>>? resources,
  Object? resourceValue,
}) {
  final parsedUri = Uri.parse(uri);
  final rootSegments = parsedUri.pathSegments
      .where((segment) => segment.isNotEmpty)
      .take(parsedUri.pathSegments.length - 1)
      .toList();
  final referenceUri = parsedUri
      .replace(pathSegments: <String>[
        ...rootSegments,
        'references',
        'BRANCHES.md',
      ])
      .toString();
  return <String, dynamic>{
    'uri': uri,
    'frontmatter': <String, dynamic>{
      'name': name,
      'description': 'Follow the repository Git workflow.',
      'license': 'MIT',
      'metadata': <String, dynamic>{'team': 'platform'},
    },
    'resources': resourceValue ??
        resources ??
        <Map<String, dynamic>>[
          <String, dynamic>{
            'uri': uri,
            'digest':
                'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'size': 42,
          },
          <String, dynamic>{
            'uri': referenceUri,
            'digest':
                'sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            'size': 100,
          },
        ],
  };
}

Map<String, dynamic> _cacheable({
  required Map<String, dynamic> result,
  String cacheScope = 'public',
  int ttlMs = 60000,
}) {
  return <String, dynamic>{
    'resultType': 'complete',
    ...result,
    'ttlMs': ttlMs,
    'cacheScope': cacheScope,
  };
}

Future<({Client client, MockTransport transport})> _connected({
  Map<String, dynamic>? extensions,
  bool resources = true,
}) async {
  final client = Client(
    name: 'skills-test-client',
    version: '1.0.0',
    protocolVersion: McpProtocol.v2026_07_28,
  );
  final transport = MockTransport();
  transport.queueResponse(<String, dynamic>{
    'jsonrpc': McpProtocol.jsonRpcVersion,
    'id': 1,
    'result': <String, dynamic>{
      'resultType': 'complete',
      'supportedVersions': <String>[McpProtocol.v2026_07_28],
      'capabilities': <String, dynamic>{
        if (resources) 'resources': <String, dynamic>{},
        if (extensions != null)
          'extensions': <String, dynamic>{
            McpProtocol.skillsExtensionId: extensions,
          },
      },
      '_meta': <String, dynamic>{
        McpProtocol.metaServerInfo: <String, dynamic>{
          'name': 'mock-skills-server',
          'version': '1.0.0',
        },
      },
      'ttlMs': 60000,
      'cacheScope': 'private',
    },
  });
  await client.connect(transport);
  return (client: client, transport: transport);
}

void main() {
  group('MCP Skills capability gate', () {
    test('does not call skills/list when the extension was not advertised', () async {
      final connection = await _connected();
      final adapter = McpSkillsExtension(
        client: connection.client,
        serverIdentity: 'host-server-label-1',
      );
      expect(adapter.isSupported, isFalse);
      await expectLater(
        adapter.listSkills(),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        connection.transport.sentMessages.map((message) => message['method']),
        <String>[McpProtocol.methodServerDiscover],
      );
      connection.client.dispose();
    });

    test('rejects Skills extension when the server lacks Resources capability', () async {
      final connection = await _connected(
        resources: false,
        extensions: <String, dynamic>{},
      );
      final adapter = McpSkillsExtension(
        client: connection.client,
        serverIdentity: 'host-server-label-1',
      );
      await expectLater(
        adapter.listSkills(),
        throwsA(isA<StateError>()),
      );
      expect(connection.transport.sentMessages, hasLength(1));
      connection.client.dispose();
    });

    test('rejects malformed directoryRead capability declarations', () async {
      final connection = await _connected(
        extensions: <String, dynamic>{'directoryRead': 'yes'},
      );
      final adapter = McpSkillsExtension(
        client: connection.client,
        serverIdentity: 'host-server-label-1',
      );
      expect(
        () => adapter.supportsDirectoryRead,
        throwsA(isA<FormatException>()),
      );
      connection.client.dispose();
    });

    test('directoryRead is exposed only when explicitly true', () async {
      final supported = await _connected(
        extensions: <String, dynamic>{'directoryRead': true},
      );
      final unsupported = await _connected(
        extensions: <String, dynamic>{},
      );
      expect(
        McpSkillsExtension(
          client: supported.client,
          serverIdentity: 'server-a',
        ).supportsDirectoryRead,
        isTrue,
      );
      expect(
        McpSkillsExtension(
          client: unsupported.client,
          serverIdentity: 'server-b',
        ).supportsDirectoryRead,
        isFalse,
      );
      supported.client.dispose();
      unsupported.client.dispose();
    });
  });

  group('MCP Skills manifest models', () {
    test('parses complete frontmatter and a complete resource manifest', () {
      final skill = McpSkillEntry.fromJson(_manifest());
      expect(skill.name, 'git-workflow');
      expect(skill.description, 'Follow the repository Git workflow.');
      expect(skill.frontmatter['license'], 'MIT');
      expect(skill.resources, hasLength(2));
      expect(skill.resources.first.uri, _skillUri);
      expect(skill.isDynamic, isFalse);
    });

    test('accepts dynamic resources but marks them unverifiable', () {
      final skill = McpSkillEntry.fromJson(
        _manifest(resourceValue: 'dynamic'),
      );
      expect(skill.isDynamic, isTrue);
      expect(skill.resources, isEmpty);
    });

    test('rejects a manifest missing the SKILL.md resource', () {
      expect(
        () => McpSkillEntry.fromJson(
          _manifest(
            resources: <Map<String, dynamic>>[
              <String, dynamic>{
                'uri': 'skill://git-workflow/references/BRANCHES.md',
                'digest':
                    'sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
                'size': 10,
              },
            ],
          ),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects duplicate, cross-origin and traversal resource URIs', () {
      final duplicate = <Map<String, dynamic>>[
        <String, dynamic>{
          'uri': _skillUri,
          'digest':
              'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          'size': 1,
        },
        <String, dynamic>{
          'uri': _skillUri,
          'digest':
              'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          'size': 1,
        },
      ];
      expect(
        () => McpSkillEntry.fromJson(_manifest(resources: duplicate)),
        throwsA(isA<FormatException>()),
      );

      final traversal = <Map<String, dynamic>>[
        <String, dynamic>{
          'uri': _skillUri,
          'digest':
              'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          'size': 1,
        },
        <String, dynamic>{
          'uri': 'skill://git-workflow/../secret.txt',
          'digest':
              'sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          'size': 1,
        },
      ];
      expect(
        () => McpSkillEntry.fromJson(_manifest(resources: traversal)),
        throwsA(isA<FormatException>()),
      );

      final crossOrigin = <Map<String, dynamic>>[
        <String, dynamic>{
          'uri': _skillUri,
          'digest':
              'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          'size': 1,
        },
        <String, dynamic>{
          'uri': 'https://attacker.invalid/git-workflow/secret.txt',
          'digest':
              'sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          'size': 1,
        },
      ];
      expect(
        () => McpSkillEntry.fromJson(_manifest(resources: crossOrigin)),
        throwsA(isA<FormatException>()),
      );
    });

    test('enforces per-skill resource count and aggregate byte limits', () {
      final moreThan512 = List<Map<String, dynamic>>.generate(
        513,
        (index) => <String, dynamic>{
          'uri': index == 0
              ? _skillUri
              : 'skill://git-workflow/files/$index.bin',
          'digest':
              'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          'size': 1,
        },
      );
      expect(
        () => McpSkillEntry.fromJson(_manifest(resources: moreThan512)),
        throwsA(isA<FormatException>()),
      );

      final over16MiB = <Map<String, dynamic>>[
        <String, dynamic>{
          'uri': _skillUri,
          'digest':
              'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          'size': 16 * 1024 * 1024,
        },
        <String, dynamic>{
          'uri': 'skill://git-workflow/large.bin',
          'digest':
              'sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          'size': 1,
        },
      ];
      expect(
        () => McpSkillEntry.fromJson(_manifest(resources: over16MiB)),
        throwsA(isA<FormatException>()),
      );
    });

    test('does not impose the per-skill resource limit on the server catalog', () async {
      final connection = await _connected(extensions: <String, dynamic>{});
      final entries = List<Map<String, dynamic>>.generate(513, (index) {
        final name = 'skill-' + index.toString();
        final uri = 'skill://' + name + '/SKILL.md';
        return _manifest(
          uri: uri,
          name: name,
          resources: <Map<String, dynamic>>[
            <String, dynamic>{
              'uri': uri,
              'digest':
                  'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
              'size': 1,
            },
          ],
        );
      });
      connection.transport.queueResponse(<String, dynamic>{
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'id': 2,
        'result': _cacheable(result: <String, dynamic>{'skills': entries}),
      });
      final adapter = McpSkillsExtension(
        client: connection.client,
        serverIdentity: 'host-server-label-1',
      );
      final result = await adapter.listSkills();
      expect(result.skills, hasLength(513));
      connection.client.dispose();
    });

    test('parses a nested skill URI and uses the final path segment as its name', () {
      final uri = 'skill://acme/billing/refunds/SKILL.md';
      final nestedResources = <Map<String, dynamic>>[
        <String, dynamic>{
          'uri': uri,
          'digest':
              'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          'size': 10,
        },
        <String, dynamic>{
          'uri': 'skill://acme/billing/refunds/references/guide.md',
          'digest':
              'sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          'size': 20,
        },
      ];
      final skill = McpSkillEntry.fromJson(
        _manifest(uri: uri, name: 'refunds', resources: nestedResources),
      );
      expect(skill.name, 'refunds');
    });

    test('rejects malformed names, descriptions and resource digests', () {
      expect(
        () => McpSkillEntry.fromJson(_manifest(name: 'Bad_Name')),
        throwsA(isA<FormatException>()),
      );

      final badDescription = _manifest();
      (badDescription['frontmatter'] as Map<String, dynamic>)['description'] =
          List<String>.filled(1025, 'x').join();
      expect(
        () => McpSkillEntry.fromJson(badDescription),
        throwsA(isA<FormatException>()),
      );

      final badDigest = <Map<String, dynamic>>[
        <String, dynamic>{
          'uri': _skillUri,
          'digest': 'sha256:INVALID',
          'size': 1,
        },
      ];
      expect(
        () => McpSkillEntry.fromJson(_manifest(resources: badDigest)),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('MCP Skills list and get requests', () {
    test('follows pagination and aggregates cache hints without reading files', () async {
      final connection = await _connected(
        extensions: <String, dynamic>{'directoryRead': true},
      );
      connection.transport
        ..queueResponse(<String, dynamic>{
          'jsonrpc': McpProtocol.jsonRpcVersion,
          'id': 2,
          'result': _cacheable(
            result: <String, dynamic>{
              'skills': <Map<String, dynamic>>[_manifest()],
              'nextCursor': 'page-2',
            },
            cacheScope: 'public',
            ttlMs: 60000,
          ),
        })
        ..queueResponse(<String, dynamic>{
          'jsonrpc': McpProtocol.jsonRpcVersion,
          'id': 3,
          'result': _cacheable(
            result: <String, dynamic>{'skills': <dynamic>[]},
            cacheScope: 'private',
            ttlMs: 30000,
          ),
        });

      final adapter = McpSkillsExtension(
        client: connection.client,
        serverIdentity: 'host-server-label-1',
      );
      final result = await adapter.listSkills();
      final skillRequests = connection.transport.sentMessages
          .where((message) => message['method'] == McpProtocol.methodListSkills)
          .toList(growable: false);

      expect(result.skills, hasLength(1));
      expect(result.pagesFetched, 2);
      expect(result.paginationTruncated, isFalse);
      expect(result.reachedPaginationEnd, isTrue);
      expect(result.listingMayBePartial, isTrue);
      expect(result.ttlMs, 30000);
      expect(result.cacheScope, 'private');
      expect(skillRequests, hasLength(2));
      expect(skillRequests.last['params']['cursor'], 'page-2');
      expect(
        connection.transport.sentMessages.any(
          (message) => message['method'] == 'resources/read',
        ),
        isFalse,
      );
      expect(
        adapter.identityFor(result.skills.single).serverIdentity,
        'host-server-label-1',
      );
      connection.client.dispose();
    });

    test('returns a resumable partial listing when the page cap is reached', () async {
      final connection = await _connected(extensions: <String, dynamic>{});
      connection.transport
        ..queueResponse(<String, dynamic>{
          'jsonrpc': McpProtocol.jsonRpcVersion,
          'id': 2,
          'result': _cacheable(
            result: <String, dynamic>{
              'skills': <dynamic>[],
              'nextCursor': 'next-page',
            },
          ),
        })
        ..queueResponse(<String, dynamic>{
          'jsonrpc': McpProtocol.jsonRpcVersion,
          'id': 3,
          'result': _cacheable(
            result: <String, dynamic>{'skills': <dynamic>[]},
          ),
        });
      final adapter = McpSkillsExtension(
        client: connection.client,
        serverIdentity: 'host-server-label-1',
        limits: const McpSkillsLimits(maxPages: 1),
      );
      final first = await adapter.listSkills();
      expect(first.paginationTruncated, isTrue);
      expect(first.nextCursor, 'next-page');
      expect(first.pagesFetched, 1);
      final resumed = await adapter.listSkills(cursor: first.nextCursor);
      expect(resumed.paginationTruncated, isFalse);
      expect(resumed.pagesFetched, 1);
      expect(
        connection.transport.sentMessages.last['params']['cursor'],
        'next-page',
      );
      connection.client.dispose();
    });

    test('rejects repeated cursors rather than looping forever', () async {
      final connection = await _connected(extensions: <String, dynamic>{});
      connection.transport
        ..queueResponse(<String, dynamic>{
          'jsonrpc': McpProtocol.jsonRpcVersion,
          'id': 2,
          'result': _cacheable(
            result: <String, dynamic>{
              'skills': <dynamic>[],
              'nextCursor': 'cursor-1',
            },
          ),
        })
        ..queueResponse(<String, dynamic>{
          'jsonrpc': McpProtocol.jsonRpcVersion,
          'id': 3,
          'result': _cacheable(
            result: <String, dynamic>{
              'skills': <dynamic>[],
              'nextCursor': 'cursor-1',
            },
          ),
        });
      final adapter = McpSkillsExtension(
        client: connection.client,
        serverIdentity: 'host-server-label-1',
      );
      await expectLater(
        adapter.listSkills(),
        throwsA(isA<FormatException>()),
      );
      expect(
        connection.transport.sentMessages
            .where((message) => message['method'] == McpProtocol.methodListSkills)
            .length,
        2,
      );
      connection.client.dispose();
    });

    test('skills/get works for an explicit URI omitted from the listing', () async {
      final connection = await _connected(extensions: <String, dynamic>{});
      connection.transport.queueResponse(<String, dynamic>{
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'id': 2,
        'result': _cacheable(
          result: <String, dynamic>{
            'skill': _manifest(
              uri: 'skill://unlisted-skill/SKILL.md',
              name: 'unlisted-skill',
            ),
          },
          cacheScope: 'private',
          ttlMs: 5000,
        ),
      });
      final adapter = McpSkillsExtension(
        client: connection.client,
        serverIdentity: 'host-server-label-1',
      );
      final result = await adapter.getSkill(
        uri: 'skill://unlisted-skill/SKILL.md',
      );
      expect(result.skill.name, 'unlisted-skill');
      expect(result.ttlMs, 5000);
      expect(result.cacheScope, 'private');
      expect(
        connection.transport.sentMessages.last['method'],
        McpProtocol.methodGetSkill,
      );
      connection.client.dispose();
    });

    test('does not conflate identical skill URIs from different servers', () async {
      final connection = await _connected(extensions: <String, dynamic>{});
      final adapterA = McpSkillsExtension(
        client: connection.client,
        serverIdentity: 'host-server-label-A',
      );
      final adapterB = McpSkillsExtension(
        client: connection.client,
        serverIdentity: 'host-server-label-B',
      );
      final skill = McpSkillEntry.fromJson(_manifest());
      expect(adapterA.identityFor(skill).uri, adapterB.identityFor(skill).uri);
      expect(adapterA.identityFor(skill), isNot(adapterB.identityFor(skill)));
      connection.client.dispose();
    });
  });
}
