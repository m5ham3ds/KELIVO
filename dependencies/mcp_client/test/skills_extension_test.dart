import 'dart:convert';

import 'package:crypto/crypto.dart';
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

      final encodedTraversal = <Map<String, dynamic>>[
        <String, dynamic>{
          'uri': _skillUri,
          'digest':
              'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          'size': 1,
        },
        <String, dynamic>{
          'uri': 'skill://git-workflow/%2e%2e/secret.txt',
          'digest':
              'sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          'size': 1,
        },
      ];
      expect(
        () => McpSkillEntry.fromJson(_manifest(resources: encodedTraversal)),
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

String _validSkillMarkdown({String license = 'MIT'}) =>
    '---\n'
    'name: git-workflow\n'
    'description: Follow the repository Git workflow.\n'
    'license: ' + license + '\n'
    'metadata:\n'
    '  team: platform\n'
    '---\n\n'
    '# Git Workflow\n';

Map<String, dynamic> _manifestForMarkdown(
  String markdown, {
  int? declaredSize,
  String? declaredDigest,
}) {
  final bytes = utf8.encode(markdown);
  return _manifest(
    resources: <Map<String, dynamic>>[
      <String, dynamic>{
        'uri': _skillUri,
        'digest': declaredDigest ??
            'sha256:' + sha256.convert(bytes).toString(),
        'size': declaredSize ?? bytes.length,
      },
    ],
  );
}

Map<String, dynamic> _manifestWithSupportingBlob(
  String markdown,
  String resourceUri,
  List<int> blobBytes,
) {
  final markdownBytes = utf8.encode(markdown);
  return _manifest(
    resources: <Map<String, dynamic>>[
      <String, dynamic>{
        'uri': _skillUri,
        'digest': 'sha256:' + sha256.convert(markdownBytes).toString(),
        'size': markdownBytes.length,
      },
      <String, dynamic>{
        'uri': resourceUri,
        'digest': 'sha256:' + sha256.convert(blobBytes).toString(),
        'size': blobBytes.length,
      },
    ],
  );
}

Map<String, dynamic> _readReply({
  required String uri,
  String? text,
  String? blob,
  int ttlMs = 60000,
  String cacheScope = 'public',
}) {
  final content = <String, dynamic>{'uri': uri};
  if (text != null) content['text'] = text;
  if (blob != null) content['blob'] = blob;
  return <String, dynamic>{
    'jsonrpc': McpProtocol.jsonRpcVersion,
    'id': 99,
    'result': _cacheable(
      result: <String, dynamic>{
        'contents': <Map<String, dynamic>>[content],
      },
      ttlMs: ttlMs,
      cacheScope: cacheScope,
    ),
  };
}


  group('MCP Skills lazy resource integrity', () {
    test('verifies raw UTF-8 bytes and frontmatter, then serves cache hits', () async {
      final connection = await _connected(extensions: <String, dynamic>{});
      final markdown = _validSkillMarkdown();
      final manifest = _manifestForMarkdown(markdown);
      connection.transport
        ..queueResponse(<String, dynamic>{
          'jsonrpc': McpProtocol.jsonRpcVersion,
          'id': 2,
          'result': _cacheable(
            result: <String, dynamic>{'skill': manifest},
            ttlMs: 60000,
            cacheScope: 'private',
          ),
        })
        ..queueResponse(_readReply(
          uri: _skillUri,
          text: markdown,
          ttlMs: 30000,
          cacheScope: 'public',
        ));

      final adapter = McpSkillsExtension(
        client: connection.client,
        serverIdentity: 'host-server-label-1',
      );
      final entry = await adapter.getSkill(uri: _skillUri);
      final first = await adapter.readSkillResource(
        snapshot: entry.snapshot,
        uri: _skillUri,
      );
      final cached = await adapter.readSkillResource(
        snapshot: entry.snapshot,
        uri: _skillUri,
      );

      expect(first.digest, manifest['resources'] is List
          ? (manifest['resources'] as List).single['digest']
          : isNotNull);
      expect(first.size, utf8.encode(markdown).length);
      expect(first.bytes, utf8.encode(markdown));
      expect(first.text, markdown);
      expect(first.fromCache, isFalse);
      expect(cached.fromCache, isTrue);
      expect(cached.cacheScope, 'private');
      expect(
        connection.transport.sentMessages
            .where((message) => message['method'] == 'resources/read')
            .length,
        1,
      );
      await adapter.dispose();
      connection.client.dispose();
    });

    test('decodes and verifies base64 resource bytes', () async {
      final connection = await _connected(extensions: <String, dynamic>{});
      const binaryUri = 'skill://git-workflow/references/data.bin';
      final markdown = _validSkillMarkdown();
      final bytes = <int>[0, 255, 1, 2, 128, 65];
      connection.transport
        ..queueResponse(<String, dynamic>{
          'jsonrpc': McpProtocol.jsonRpcVersion,
          'id': 2,
          'result': _cacheable(
            result: <String, dynamic>{
              'skill': _manifestWithSupportingBlob(markdown, binaryUri, bytes),
            },
          ),
        })
        ..queueResponse(_readReply(
          uri: binaryUri,
          blob: base64Encode(bytes),
          ttlMs: 30000,
        ));
      final adapter = McpSkillsExtension(
        client: connection.client,
        serverIdentity: 'host-server-label-1',
      );
      final entry = await adapter.getSkill(uri: _skillUri);
      final result = await adapter.readSkillResource(
        snapshot: entry.snapshot,
        uri: binaryUri,
      );
      expect(result.bytes, bytes);
      expect(result.digest, 'sha256:' + sha256.convert(bytes).toString());
      await adapter.dispose();
      connection.client.dispose();
    });

    test('rejects bytes whose length differs from the manifest', () async {
      final connection = await _connected(extensions: <String, dynamic>{});
      final markdown = _validSkillMarkdown();
      final bytes = utf8.encode(markdown);
      connection.transport
        ..queueResponse(<String, dynamic>{
          'jsonrpc': McpProtocol.jsonRpcVersion,
          'id': 2,
          'result': _cacheable(
            result: <String, dynamic>{
              'skill': _manifestForMarkdown(
                markdown,
                declaredSize: bytes.length + 1,
              ),
            },
          ),
        })
        ..queueResponse(_readReply(uri: _skillUri, text: markdown));
      final adapter = McpSkillsExtension(
        client: connection.client,
        serverIdentity: 'host-server-label-1',
      );
      final entry = await adapter.getSkill(uri: _skillUri);
      await expectLater(
        adapter.readSkillResource(snapshot: entry.snapshot, uri: _skillUri),
        throwsA(
          isA<McpSkillIntegrityException>().having(
            (error) => error.code,
            'code',
            'skill_resource_size_mismatch',
          ),
        ),
      );
      await adapter.dispose();
      connection.client.dispose();
    });

    test('rejects bytes whose SHA-256 differs from the manifest', () async {
      final connection = await _connected(extensions: <String, dynamic>{});
      final markdown = _validSkillMarkdown();
      const incorrectDigest =
          'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      connection.transport
        ..queueResponse(<String, dynamic>{
          'jsonrpc': McpProtocol.jsonRpcVersion,
          'id': 2,
          'result': _cacheable(
            result: <String, dynamic>{
              'skill': _manifestForMarkdown(
                markdown,
                declaredDigest: incorrectDigest,
              ),
            },
          ),
        })
        ..queueResponse(_readReply(uri: _skillUri, text: markdown));
      final adapter = McpSkillsExtension(
        client: connection.client,
        serverIdentity: 'host-server-label-1',
      );
      final entry = await adapter.getSkill(uri: _skillUri);
      await expectLater(
        adapter.readSkillResource(snapshot: entry.snapshot, uri: _skillUri),
        throwsA(
          isA<McpSkillIntegrityException>().having(
            (error) => error.code,
            'code',
            'skill_resource_digest_mismatch',
          ),
        ),
      );
      await adapter.dispose();
      connection.client.dispose();
    });

    test('rejects a frontmatter mismatch after byte integrity succeeds', () async {
      final connection = await _connected(extensions: <String, dynamic>{});
      final markdown = _validSkillMarkdown(license: 'Apache-2.0');
      connection.transport
        ..queueResponse(<String, dynamic>{
          'jsonrpc': McpProtocol.jsonRpcVersion,
          'id': 2,
          'result': _cacheable(
            result: <String, dynamic>{
              // The manifest helper keeps the declared license as MIT.
              'skill': _manifestForMarkdown(markdown),
            },
          ),
        })
        ..queueResponse(_readReply(uri: _skillUri, text: markdown));
      final adapter = McpSkillsExtension(
        client: connection.client,
        serverIdentity: 'host-server-label-1',
      );
      final entry = await adapter.getSkill(uri: _skillUri);
      await expectLater(
        adapter.readSkillResource(snapshot: entry.snapshot, uri: _skillUri),
        throwsA(
          isA<McpSkillIntegrityException>().having(
            (error) => error.code,
            'code',
            'skill_frontmatter_mismatch',
          ),
        ),
      );
      await adapter.dispose();
      connection.client.dispose();
    });

    test('rejects malformed or missing SKILL.md frontmatter delimiters', () async {
      final connection = await _connected(extensions: <String, dynamic>{});
      const malformed = '# no YAML frontmatter\n';
      connection.transport
        ..queueResponse(<String, dynamic>{
          'jsonrpc': McpProtocol.jsonRpcVersion,
          'id': 2,
          'result': _cacheable(
            result: <String, dynamic>{
              'skill': _manifestForMarkdown(malformed),
            },
          ),
        })
        ..queueResponse(_readReply(uri: _skillUri, text: malformed));
      final adapter = McpSkillsExtension(
        client: connection.client,
        serverIdentity: 'host-server-label-1',
      );
      final entry = await adapter.getSkill(uri: _skillUri);
      await expectLater(
        adapter.readSkillResource(snapshot: entry.snapshot, uri: _skillUri),
        throwsA(
          isA<McpSkillIntegrityException>().having(
            (error) => error.code,
            'code',
            'skill_frontmatter_invalid',
          ),
        ),
      );
      await adapter.dispose();
      connection.client.dispose();
    });

    test('rejects dynamic resources and unlisted files without reading', () async {
      final connection = await _connected(extensions: <String, dynamic>{});
      connection.transport.queueResponse(<String, dynamic>{
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'id': 2,
        'result': _cacheable(
          result: <String, dynamic>{
            'skill': _manifest(resourceValue: 'dynamic'),
          },
        ),
      });
      final adapter = McpSkillsExtension(
        client: connection.client,
        serverIdentity: 'host-server-label-1',
      );
      final dynamicEntry = await adapter.getSkill(uri: _skillUri);
      await expectLater(
        adapter.readSkillResource(
          snapshot: dynamicEntry.snapshot,
          uri: _skillUri,
        ),
        throwsA(isA<McpSkillIntegrityException>()),
      );
      await expectLater(
        adapter.readSkillResource(
          snapshot: dynamicEntry.snapshot,
          uri: 'skill://git-workflow/secret.txt',
        ),
        throwsA(isA<McpSkillIntegrityException>()),
      );
      expect(
        connection.transport.sentMessages.any(
          (message) => message['method'] == 'resources/read',
        ),
        isFalse,
      );
      await adapter.dispose();
      connection.client.dispose();
    });

    test('resource-list invalidation preserves existing callbacks and requires refresh', () async {
      final connection = await _connected(extensions: <String, dynamic>{});
      final markdown = _validSkillMarkdown();
      final manifest = _manifestForMarkdown(markdown);
      var legacyCallbackCount = 0;
      connection.client.onResourcesListChanged(() {
        legacyCallbackCount++;
      });
      connection.transport
        ..queueResponse(<String, dynamic>{
          'jsonrpc': McpProtocol.jsonRpcVersion,
          'id': 2,
          'result': _cacheable(
            result: <String, dynamic>{'skill': manifest},
          ),
        })
        ..queueResponse(_readReply(uri: _skillUri, text: markdown))
        ..queueResponse(<String, dynamic>{
          'jsonrpc': McpProtocol.jsonRpcVersion,
          'id': 4,
          'result': _cacheable(
            result: <String, dynamic>{'skill': manifest},
          ),
        })
        ..queueResponse(_readReply(uri: _skillUri, text: markdown));

      final adapter = McpSkillsExtension(
        client: connection.client,
        serverIdentity: 'host-server-label-1',
      );
      final firstEntry = await adapter.getSkill(uri: _skillUri);
      final firstRead = await adapter.readSkillResource(
        snapshot: firstEntry.snapshot,
        uri: _skillUri,
      );
      final cachedRead = await adapter.readSkillResource(
        snapshot: firstEntry.snapshot,
        uri: _skillUri,
      );
      expect(cachedRead.fromCache, isTrue);

      connection.transport.simulateMessage(<String, dynamic>{
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'method': McpProtocol.methodResourceListChanged,
        'params': <String, dynamic>{},
      });
      await Future<void>.delayed(Duration.zero);
      expect(legacyCallbackCount, 1);
      await expectLater(
        adapter.readSkillResource(
          snapshot: firstEntry.snapshot,
          uri: _skillUri,
        ),
        throwsA(isA<McpSkillIntegrityException>()),
      );

      final refreshed = await adapter.getSkill(uri: _skillUri);
      final secondRead = await adapter.readSkillResource(
        snapshot: refreshed.snapshot,
        uri: _skillUri,
      );
      expect(firstRead.fromCache, isFalse);
      expect(secondRead.fromCache, isFalse);
      expect(
        connection.transport.sentMessages
            .where((message) => message['method'] == 'resources/read')
            .length,
        2,
      );
      await adapter.dispose();
      connection.client.dispose();
    });

    test('manifest digest-set changes revoke old snapshots and cache keys', () async {
      final connection = await _connected(extensions: <String, dynamic>{});
      final markdown = _validSkillMarkdown();
      final markdownBytes = utf8.encode(markdown);
      final firstManifest = _manifestForMarkdown(markdown);
      final supportUri = 'skill://git-workflow/references/extra.md';
      final secondManifest = _manifest(
        resources: <Map<String, dynamic>>[
          <String, dynamic>{
            'uri': _skillUri,
            'digest': 'sha256:' + sha256.convert(markdownBytes).toString(),
            'size': markdownBytes.length,
          },
          <String, dynamic>{
            'uri': supportUri,
            'digest':
                'sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            'size': 1,
          },
        ],
      );
      connection.transport
        ..queueResponse(<String, dynamic>{
          'jsonrpc': McpProtocol.jsonRpcVersion,
          'id': 2,
          'result': _cacheable(
            result: <String, dynamic>{'skill': firstManifest},
          ),
        })
        ..queueResponse(_readReply(uri: _skillUri, text: markdown))
        ..queueResponse(<String, dynamic>{
          'jsonrpc': McpProtocol.jsonRpcVersion,
          'id': 4,
          'result': _cacheable(
            result: <String, dynamic>{'skill': secondManifest},
          ),
        })
        ..queueResponse(_readReply(uri: _skillUri, text: markdown));

      final adapter = McpSkillsExtension(
        client: connection.client,
        serverIdentity: 'host-server-label-1',
      );
      final first = await adapter.getSkill(uri: _skillUri);
      await adapter.readSkillResource(snapshot: first.snapshot, uri: _skillUri);
      final second = await adapter.getSkill(uri: _skillUri);
      await expectLater(
        adapter.readSkillResource(snapshot: first.snapshot, uri: _skillUri),
        throwsA(isA<McpSkillIntegrityException>()),
      );
      final secondRead = await adapter.readSkillResource(
        snapshot: second.snapshot,
        uri: _skillUri,
      );
      expect(secondRead.fromCache, isFalse);
      expect(
        connection.transport.sentMessages
            .where((message) => message['method'] == 'resources/read')
            .length,
        2,
      );
      await adapter.dispose();
      connection.client.dispose();
    });

    test('expired manifests must be refreshed before a resource read', () async {
      final connection = await _connected(extensions: <String, dynamic>{});
      final markdown = _validSkillMarkdown();
      var now = DateTime.utc(2026, 11, 25);
      connection.transport.queueResponse(<String, dynamic>{
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'id': 2,
        'result': _cacheable(
          result: <String, dynamic>{
            'skill': _manifestForMarkdown(markdown),
          },
          ttlMs: 1000,
        ),
      });
      final adapter = McpSkillsExtension(
        client: connection.client,
        serverIdentity: 'host-server-label-1',
        clock: () => now,
      );
      final entry = await adapter.getSkill(uri: _skillUri);
      now = now.add(const Duration(seconds: 2));
      await expectLater(
        adapter.readSkillResource(snapshot: entry.snapshot, uri: _skillUri),
        throwsA(
          isA<McpSkillIntegrityException>().having(
            (error) => error.code,
            'code',
            'skill_manifest_expired_refresh_required',
          ),
        ),
      );
      expect(
        connection.transport.sentMessages.any(
          (message) => message['method'] == 'resources/read',
        ),
        isFalse,
      );
      await adapter.dispose();
      connection.client.dispose();
    });

    test('zero resource TTL disables byte caching', () async {
      final connection = await _connected(extensions: <String, dynamic>{});
      final markdown = _validSkillMarkdown();
      connection.transport
        ..queueResponse(<String, dynamic>{
          'jsonrpc': McpProtocol.jsonRpcVersion,
          'id': 2,
          'result': _cacheable(
            result: <String, dynamic>{
              'skill': _manifestForMarkdown(markdown),
            },
          ),
        })
        ..queueResponse(_readReply(uri: _skillUri, text: markdown, ttlMs: 0))
        ..queueResponse(_readReply(uri: _skillUri, text: markdown, ttlMs: 0));
      final adapter = McpSkillsExtension(
        client: connection.client,
        serverIdentity: 'host-server-label-1',
      );
      final entry = await adapter.getSkill(uri: _skillUri);
      final first = await adapter.readSkillResource(
        snapshot: entry.snapshot,
        uri: _skillUri,
      );
      final second = await adapter.readSkillResource(
        snapshot: entry.snapshot,
        uri: _skillUri,
      );
      expect(first.fromCache, isFalse);
      expect(second.fromCache, isFalse);
      expect(
        connection.transport.sentMessages
            .where((message) => message['method'] == 'resources/read')
            .length,
        2,
      );
      await adapter.dispose();
      connection.client.dispose();
    });
  });

}
