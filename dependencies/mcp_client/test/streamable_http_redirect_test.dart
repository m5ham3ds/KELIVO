@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mcp_client/mcp_client.dart';
import 'package:test/test.dart';

void main() {
  test('stateless HTTP advertises metadata on the first request and uses routed headers', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final methods = <String>[];
    final observations = <Map<String, dynamic>>[];
    final serving = () async {
      await for (final request in server) {
        methods.add(request.method);
        final body = jsonDecode(
          await request.cast<List<int>>().transform(utf8.decoder).join(),
        ) as Map<String, dynamic>;
        observations.add({
          'body': body,
          'protocolVersion': request.headers.value('MCP-Protocol-Version'),
          'method': request.headers.value('Mcp-Method'),
          'name': request.headers.value('Mcp-Name'),
          'session': request.headers.value('Mcp-Session-Id'),
        });

        final result = body['method'] == McpProtocol.methodServerDiscover
            ? <String, dynamic>{
                'resultType': 'complete',
                'supportedVersions': [McpProtocol.v2026_07_28],
                'capabilities': {'tools': {}, 'resources': {}},
                '_meta': {
                  McpProtocol.metaServerInfo: {
                    'name': 'stateless-http-test',
                    'version': '1.0.0',
                  },
                },
                'ttlMs': 60000,
                'cacheScope': 'public',
              }
            : <String, dynamic>{
                'resultType': 'complete',
                'content': [
                  {'type': 'text', 'text': 'ok'},
                ],
                'isError': false,
              };

        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({
            'jsonrpc': McpProtocol.jsonRpcVersion,
            'id': body['id'],
            'result': result,
          }));
        await request.response.close();
      }
    }();

    final transport = await StreamableHttpClientTransport.create(
      baseUrl: 'http://${server.address.host}:${server.port}/mcp',
      timeout: const Duration(seconds: 3),
      terminateOnClose: true,
    );
    final client = Client(
      name: 'stateless-http-client',
      version: '1.0.0',
      protocolVersion: McpProtocol.v2026_07_28,
      requestTimeout: const Duration(seconds: 3),
    );

    try {
      await client.connectWithRetry(transport, maxRetries: 1);
      final result = await client.callTool('demo-tool', {'input': 'hello'});
      expect((result.content.single as TextContent).text, 'ok');

      expect(methods, ['POST', 'POST']);
      expect(observations, hasLength(2));
      expect(observations[0]['protocolVersion'], McpProtocol.v2026_07_28);
      expect(observations[0]['method'], McpProtocol.methodServerDiscover);
      expect(observations[0]['name'], isNull);
      expect(observations[0]['session'], isNull);
      final discoveryMeta =
          (observations[0]['body'] as Map)['params']['_meta'] as Map;
      expect(
        discoveryMeta[McpProtocol.metaProtocolVersion],
        McpProtocol.v2026_07_28,
      );

      expect(observations[1]['protocolVersion'], McpProtocol.v2026_07_28);
      expect(observations[1]['method'], 'tools/call');
      expect(observations[1]['name'], 'demo-tool');
      expect(observations[1]['session'], isNull);
      final callMeta =
          (observations[1]['body'] as Map)['params']['_meta'] as Map;
      expect(
        callMeta[McpProtocol.metaProtocolVersion],
        McpProtocol.v2026_07_28,
      );

      await transport.terminateSession();
      client.disconnect();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(methods, everyElement('POST'));
    } finally {
      client.dispose();
      await server.close(force: true);
      await serving;
    }
  });

  test('stateless HTTP accepts request-scoped SSE and never resumes with GET', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final methods = <String>[];
    final serving = () async {
      await for (final request in server) {
        methods.add(request.method);
        final body = jsonDecode(
          await request.cast<List<int>>().transform(utf8.decoder).join(),
        ) as Map<String, dynamic>;
        final result = <String, dynamic>{
          'resultType': 'complete',
          'supportedVersions': [McpProtocol.v2026_07_28],
          'capabilities': {'resources': {}},
          '_meta': {
            McpProtocol.metaServerInfo: {
              'name': 'stateless-sse-test',
              'version': '1.0.0',
            },
          },
          'ttlMs': 60000,
          'cacheScope': 'private',
        };
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType('text', 'event-stream')
          ..write(
            'event: message\n'
            'data: ${jsonEncode({
              'jsonrpc': McpProtocol.jsonRpcVersion,
              'id': body['id'],
              'result': result,
            })}\n\n',
          );
        await request.response.close();
      }
    }();

    final transport = await StreamableHttpClientTransport.create(
      baseUrl: 'http://${server.address.host}:${server.port}/mcp',
      timeout: const Duration(seconds: 3),
    );
    final client = Client(
      name: 'stateless-sse-client',
      version: '1.0.0',
      protocolVersion: McpProtocol.v2026_07_28,
      requestTimeout: const Duration(seconds: 3),
    );

    try {
      await client.connect(transport);
      expect(client.negotiatedProtocolVersion, McpProtocol.v2026_07_28);
      expect(methods, ['POST']);
      client.disconnect();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(methods, ['POST']);
    } finally {
      client.dispose();
      await server.close(force: true);
      await serving;
    }
  });


  test('stateless subscriptions use a real HTTP SSE stream through acknowledgement and completion', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final methods = <String>[];
    final observations = <Map<String, String?>>[];
    final ackSent = Completer<void>();
    final notificationReceived = Completer<void>();
    final finishSubscription = Completer<void>();
    final finalResponseSent = Completer<void>();

    final serving = () async {
      await for (final request in server) {
        final message = await _readMessage(request);
        final method = message['method'] as String;
        methods.add(request.method);
        observations.add({
          'method': method,
          'methodHeader': request.headers.value('Mcp-Method'),
          'protocolVersion': request.headers.value('MCP-Protocol-Version'),
          'session': request.headers.value('MCP-Session-Id'),
          'lastEventId': request.headers.value('Last-Event-ID'),
        });

        if (method == McpProtocol.methodServerDiscover) {
          _writeJson(request.response, {
            'jsonrpc': McpProtocol.jsonRpcVersion,
            'id': message['id'],
            'result': {
              'resultType': 'complete',
              'supportedVersions': [McpProtocol.v2026_07_28],
              'capabilities': {'tools': {}, 'resources': {}, 'prompts': {}},
              '_meta': {
                McpProtocol.metaServerInfo: {
                  'name': 'subscription-http-test',
                  'version': '1.0.0',
                },
              },
              'ttlMs': 60000,
              'cacheScope': 'private',
            },
          });
          await request.response.close();
          continue;
        }

        expect(method, McpProtocol.methodSubscriptionsListen);
        final id = message['id'] as int;
        request.response
          ..statusCode = HttpStatus.ok
          ..bufferOutput = false
          ..headers.contentType = ContentType('text', 'event-stream');

        request.response.write(
          'event: message\\n'
          'data: ${jsonEncode({
            'jsonrpc': McpProtocol.jsonRpcVersion,
            'method': McpProtocol.methodSubscriptionsAcknowledged,
            'params': {
              '_meta': {McpProtocol.metaSubscriptionId: id},
              'notifications': {'toolsListChanged': true},
            },
          })}\\n\\n',
        );
        await request.response.flush();
        if (!ackSent.isCompleted) ackSent.complete();

        request.response.write(
          'event: message\\n'
          'data: ${jsonEncode({
            'jsonrpc': McpProtocol.jsonRpcVersion,
            'method': McpProtocol.methodToolListChanged,
            'params': {
              '_meta': {McpProtocol.metaSubscriptionId: id},
            },
          })}\\n\\n',
        );
        await request.response.flush();

        await finishSubscription.future.timeout(const Duration(seconds: 3));
        request.response.write(
          'event: message\\n'
          'data: ${jsonEncode({
            'jsonrpc': McpProtocol.jsonRpcVersion,
            'id': id,
            'result': {
              'resultType': 'complete',
              '_meta': {McpProtocol.metaSubscriptionId: id},
            },
          })}\\n\\n',
        );
        await request.response.close();
        if (!finalResponseSent.isCompleted) finalResponseSent.complete();
      }
    }();

    final transport = await StreamableHttpClientTransport.create(
      baseUrl: 'http://${server.address.host}:${server.port}/mcp',
      timeout: const Duration(seconds: 3),
      terminateOnClose: false,
    );
    final client = Client(
      name: 'subscription-http-client',
      version: '1.0.0',
      protocolVersion: McpProtocol.v2026_07_28,
      requestTimeout: const Duration(seconds: 3),
    );
    client.onToolsListChanged(() {
      if (!notificationReceived.isCompleted) notificationReceived.complete();
    });

    try {
      await client.connect(transport);
      final listening = client.listenForNotifications(toolsListChanged: true);
      await ackSent.future.timeout(const Duration(seconds: 3));
      final subscription = await listening;
      expect(subscription.acceptedFilter, {'toolsListChanged': true});
      await notificationReceived.future.timeout(const Duration(seconds: 3));

      expect(methods, ['POST', 'POST']);
      expect(observations[1]['methodHeader'], McpProtocol.methodSubscriptionsListen);
      expect(observations[1]['protocolVersion'], McpProtocol.v2026_07_28);
      expect(observations[1]['session'], isNull);
      expect(observations[1]['lastEventId'], isNull);

      finishSubscription.complete();
      await subscription.done.timeout(const Duration(seconds: 3));
      await finalResponseSent.future.timeout(const Duration(seconds: 3));
      expect(methods, everyElement('POST'));
    } finally {
      if (!finishSubscription.isCompleted) finishSubscription.complete();
      client.dispose();
      await server.close(force: true);
      await serving;
    }
  });

  test('cancelling a stateless HTTP subscription aborts only its POST and preserves the client', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final methods = <String>[];
    final ackSent = Completer<void>();
    final subscriptionCancelled = Completer<void>();
    final toolCallReceived = Completer<void>();
    final tasks = <Future<void>>[];

    Future<void> handle(HttpRequest request) async {
      final message = await _readMessage(request);
      final method = message['method'] as String;
      methods.add(request.method);

      if (method == McpProtocol.methodServerDiscover) {
        _writeJson(request.response, {
          'jsonrpc': McpProtocol.jsonRpcVersion,
          'id': message['id'],
          'result': {
            'resultType': 'complete',
            'supportedVersions': [McpProtocol.v2026_07_28],
            'capabilities': {'tools': {}},
            '_meta': {
              McpProtocol.metaServerInfo: {
                'name': 'subscription-cancel-http-test',
                'version': '1.0.0',
              },
            },
            'ttlMs': 60000,
            'cacheScope': 'private',
          },
        });
        await request.response.close();
        return;
      }

      if (method == McpProtocol.methodSubscriptionsListen) {
        final id = message['id'] as int;
        request.response
          ..statusCode = HttpStatus.ok
          ..bufferOutput = false
          ..headers.contentType = ContentType('text', 'event-stream');
        request.response.write(
          'event: message\\n'
          'data: ${jsonEncode({
            'jsonrpc': McpProtocol.jsonRpcVersion,
            'method': McpProtocol.methodSubscriptionsAcknowledged,
            'params': {
              '_meta': {McpProtocol.metaSubscriptionId: id},
              'notifications': {'toolsListChanged': true},
            },
          })}\\n\\n',
        );
        await request.response.flush();
        if (!ackSent.isCompleted) ackSent.complete();

        // Keep this response alive until the client aborts only this POST.
        for (var attempt = 0; attempt < 200; attempt++) {
          try {
            request.response.write(': subscription heartbeat\\n\\n');
            await request.response.flush();
          } catch (_) {
            if (!subscriptionCancelled.isCompleted) {
              subscriptionCancelled.complete();
            }
            return;
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        if (!subscriptionCancelled.isCompleted) {
          subscriptionCancelled.completeError(
            StateError('The subscription POST was not aborted by the client'),
          );
        }
        return;
      }

      if (method == McpProtocol.methodCallTool) {
        if (!toolCallReceived.isCompleted) toolCallReceived.complete();
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({
            'jsonrpc': McpProtocol.jsonRpcVersion,
            'id': message['id'],
            'result': {
              'resultType': 'complete',
              'content': [
                {'type': 'text', 'text': 'client-still-connected'},
              ],
              'isError': false,
            },
          }));
        await request.response.close();
        return;
      }

      request.response
        ..statusCode = HttpStatus.notFound
        ..write('Unexpected MCP method: $method');
      await request.response.close();
    }

    final serving = () async {
      await for (final request in server) {
        tasks.add(handle(request));
      }
      await Future.wait(tasks);
    }();

    final transport = await StreamableHttpClientTransport.create(
      baseUrl: 'http://${server.address.host}:${server.port}/mcp',
      timeout: const Duration(seconds: 3),
      terminateOnClose: false,
    );
    final client = Client(
      name: 'subscription-cancel-http-client',
      version: '1.0.0',
      protocolVersion: McpProtocol.v2026_07_28,
      requestTimeout: const Duration(seconds: 3),
    );

    try {
      await client.connect(transport);
      final listening = client.listenForNotifications(toolsListChanged: true);
      await ackSent.future.timeout(const Duration(seconds: 3));
      final subscription = await listening;

      subscription.cancel();
      await subscriptionCancelled.future.timeout(const Duration(seconds: 3));
      await subscription.done.timeout(const Duration(seconds: 3));
      expect(client.isConnected, isTrue);

      final result = await client.callTool('still-connected', const {});
      expect((result.content.single as TextContent).text, 'client-still-connected');
      await toolCallReceived.future.timeout(const Duration(seconds: 3));
      expect(methods, ['POST', 'POST', 'POST']);
    } finally {
      client.dispose();
      await server.close(force: true);
      await serving;
    }
  });

  test('rejects oversized chunked JSON responses before decoding', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final serving = _serveOversizedStatelessResponse(server, useSse: false);
    final transport = await StreamableHttpClientTransport.create(
      baseUrl: 'http://${server.address.host}:${server.port}/mcp',
      timeout: const Duration(seconds: 3),
      maxResponseBytes: 1024,
      terminateOnClose: false,
    );
    final client = Client(
      name: 'bounded-json-client',
      version: '1.0.0',
      protocolVersion: McpProtocol.v2026_07_28,
      requestTimeout: const Duration(seconds: 3),
    );

    try {
      await client.connect(transport);
      await expectLater(
        client.callTool('oversized-json', const {}),
        throwsA(
          isA<McpError>().having(
            (error) => error.message,
            'message',
            contains('response_too_large'),
          ),
        ),
      );
    } finally {
      client.dispose();
      await server.close(force: true);
      await serving;
    }
  });

  test('rejects oversized request-scoped SSE responses without resuming', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final methods = <String>[];
    final serving = _serveOversizedStatelessResponse(
      server,
      useSse: true,
      methods: methods,
    );
    final transport = await StreamableHttpClientTransport.create(
      baseUrl: 'http://${server.address.host}:${server.port}/mcp',
      timeout: const Duration(seconds: 3),
      maxResponseBytes: 1024,
      terminateOnClose: false,
    );
    final client = Client(
      name: 'bounded-sse-client',
      version: '1.0.0',
      protocolVersion: McpProtocol.v2026_07_28,
      requestTimeout: const Duration(seconds: 3),
    );

    try {
      await client.connect(transport);
      await expectLater(
        client.callTool('oversized-sse', const {}),
        throwsA(
          isA<McpError>().having(
            (error) => error.message,
            'message',
            contains('response_too_large'),
          ),
        ),
      );
      expect(methods, ['server/discover', 'tools/call']);
    } finally {
      client.dispose();
      await server.close(force: true);
      await serving;
    }
  });

  test('rejects oversized chunked HTTP 202 responses while draining', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final methods = <String>[];
    final serving = _serveOversizedStatelessResponse(
      server,
      useSse: false,
      methods: methods,
      oversizedAccepted: true,
    );
    final transport = await StreamableHttpClientTransport.create(
      baseUrl: 'http://${server.address.host}:${server.port}/mcp',
      timeout: const Duration(seconds: 3),
      maxResponseBytes: 1024,
      terminateOnClose: false,
    );
    final client = Client(
      name: 'bounded-accepted-client',
      version: '1.0.0',
      protocolVersion: McpProtocol.v2026_07_28,
      requestTimeout: const Duration(seconds: 3),
    );

    try {
      await client.connect(transport);
      await expectLater(
        client.callTool('oversized-accepted', const {}),
        throwsA(
          isA<McpError>().having(
            (error) => error.message,
            'message',
            contains('response_too_large'),
          ),
        ),
      );
      expect(methods, ['server/discover', 'tools/call']);
    } finally {
      client.dispose();
      await server.close(force: true);
      await serving;
    }
  });

  test('rejects invalid response byte limits', () async {
    await expectLater(
      StreamableHttpClientTransport.create(
        baseUrl: 'http://127.0.0.1:1/mcp',
        maxResponseBytes: 0,
      ),
      throwsArgumentError,
    );
  });

  test('rejects oversized chunked redirect bodies before following', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final methods = <String>[];
    final serving = _serveOversizedStatelessResponse(
      server,
      useSse: false,
      methods: methods,
      oversizedRedirect: true,
    );
    final transport = await StreamableHttpClientTransport.create(
      baseUrl: 'http://${server.address.host}:${server.port}/mcp',
      timeout: const Duration(seconds: 3),
      maxResponseBytes: 1024,
      terminateOnClose: false,
    );
    final client = Client(
      name: 'bounded-redirect-client',
      version: '1.0.0',
      protocolVersion: McpProtocol.v2026_07_28,
      requestTimeout: const Duration(seconds: 3),
    );

    try {
      await client.connect(transport);
      await expectLater(
        client.callTool('oversized-redirect', const {}),
        throwsA(
          isA<McpError>().having(
            (error) => error.message,
            'message',
            contains('response_too_large'),
          ),
        ),
      );
      expect(methods, [McpProtocol.methodServerDiscover, 'tools/call']);
    } finally {
      client.dispose();
      await server.close(force: true);
      await serving;
    }
  });

  test('follows 307 redirect for streamable HTTP POST', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <String>[];
    final serving = _serveRedirectingMcp(server, requests);

    final transport = await StreamableHttpClientTransport.create(
      baseUrl: 'http://${server.address.host}:${server.port}/mcp',
    );
    final client = McpClient.createClient(
      McpClient.simpleConfig(
        name: 'Redirect Test Client',
        version: '1.0.0',
        requestTimeout: const Duration(seconds: 2),
      ),
    );

    addTearDown(() async {
      client.disconnect();
      await server.close(force: true);
      await serving;
    });

    await client.connect(transport);

    expect(requests, contains('POST /mcp'));
    expect(requests, contains('POST /mcp/'));
    expect(client.serverInfo?['name'], 'Redirect MCP Server');
  });

  test('rejects cross-origin redirects without forwarding secrets', () async {
    final source = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final target = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var targetRequests = 0;
    final sourceServing = () async {
      await for (final request in source) {
        await request.drain<void>();
        request.response
          ..statusCode = HttpStatus.temporaryRedirect
          ..headers.set(
            HttpHeaders.locationHeader,
            'http://${target.address.host}:${target.port}/capture',
          );
        await request.response.close();
      }
    }();
    final targetServing = () async {
      await for (final request in target) {
        targetRequests++;
        await request.drain<void>();
        request.response.statusCode = HttpStatus.noContent;
        await request.response.close();
      }
    }();
    final transport = await StreamableHttpClientTransport.create(
      baseUrl: 'http://${source.address.host}:${source.port}/mcp',
      headers: const {
        HttpHeaders.authorizationHeader: 'Bearer secret',
        'X-Api-Key': 'also-secret',
      },
      terminateOnClose: false,
    );
    final client = Client(
      name: 'redirect-origin-test',
      version: '1.0.0',
      requestTimeout: const Duration(seconds: 1),
    );

    addTearDown(() async {
      client.dispose();
      await source.close(force: true);
      await target.close(force: true);
      await Future.wait([sourceServing, targetServing]);
    });

    await expectLater(
      client.connect(transport),
      throwsA(
        isA<McpError>().having(
          (error) => error.message,
          'message',
          contains('cross-origin'),
        ),
      ),
    );
    expect(targetRequests, 0);
  });

  test('concurrent POST SSE requests resume independently', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final openStreams = <HttpResponse>[];
    final resumedIds = <String>[];
    final serving = _serveConcurrentResumptions(
      server,
      openStreams: openStreams,
      resumedIds: resumedIds,
    );
    final client = await _connectClient(server, requestTimeoutSeconds: 4);

    addTearDown(() async {
      client.disconnect();
      for (final stream in openStreams) {
        await stream.close();
      }
      await server.close(force: true);
      await serving;
    });

    final results = await Future.wait([
      client.callTool('echo', const {'value': 'a'}),
      client.callTool('echo', const {'value': 'b'}),
    ]);

    expect(
      results.map((result) => (result.content.single as TextContent).text),
      unorderedEquals(['a', 'b']),
    );
    expect(resumedIds, hasLength(2));
    expect(resumedIds.toSet(), hasLength(2));
  });

  test(
    'interrupted POST SSE resumes from its cursor without reposting',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final openStreams = <HttpResponse>[];
      var toolPosts = 0;
      var resumedGets = 0;
      final serving = _serveInterruptedPost(
        server,
        openStreams: openStreams,
        onToolPost: () => toolPosts++,
        onResumeGet: () => resumedGets++,
      );
      final client = await _connectClient(server, requestTimeoutSeconds: 3);

      addTearDown(() async {
        client.dispose();
        for (final stream in openStreams) {
          await stream.close();
        }
        await server.close(force: true);
        await serving;
      });

      final result = await client.callTool('interrupted', const {});

      expect(result.isError, isFalse);
      expect((result.content.single as TextContent).text, 'resumed');
      expect(toolPosts, 1);
      expect(resumedGets, 1);
    },
  );

  test('final POST SSE response releases the request slot', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final openStreams = <HttpResponse>[];
    final pingReceived = Completer<void>();
    final serving = _serveHeldFinalResponse(
      server,
      openStreams: openStreams,
      pingReceived: pingReceived,
    );
    final transport = await StreamableHttpClientTransport.create(
      baseUrl: 'http://${server.address.host}:${server.port}/mcp',
      maxConcurrentRequests: 1,
      terminateOnClose: false,
    );
    final client = Client(
      name: 'slot-test',
      version: '1.0.0',
      requestTimeout: const Duration(seconds: 2),
    );
    await client.connect(transport);

    addTearDown(() async {
      client.dispose();
      for (final stream in openStreams) {
        await stream.close();
      }
      await server.close(force: true);
      await serving;
    });

    final result = await client.callTool('held', const {});
    expect(result.isError, isFalse);
    await client.ping();
    await pingReceived.future.timeout(const Duration(seconds: 1));
  });

  test(
    'failed reverse response does not fail same-number client request',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final openStreams = <HttpResponse>[];
      final serving = _serveCollidingReverseRequest(server, openStreams);
      final client = await _connectClient(server, requestTimeoutSeconds: 3);

      addTearDown(() async {
        client.disconnect();
        for (final stream in openStreams) {
          await stream.close();
        }
        await server.close(force: true);
        await serving;
      });

      final result = await client.callTool('collision', const {});
      expect(result.isError, isFalse);
      expect((result.content.single as TextContent).text, 'original-success');
    },
  );

  test('Retry-After accepts all HTTP dates and rejects negative seconds', () {
    final now = DateTime.utc(1994, 11, 6, 8, 49, 7);
    expect(McpHttpError.parseRetryAfter('-1', now: now), isNull);
    expect(
      McpHttpError.parseRetryAfter('Sun, 06 Nov 1994 08:49:37 GMT', now: now),
      const Duration(seconds: 30),
    );
    expect(
      McpHttpError.parseRetryAfter('Sunday, 06-Nov-94 08:49:37 GMT', now: now),
      const Duration(seconds: 30),
    );
    expect(
      McpHttpError.parseRetryAfter('Sun Nov  6 08:49:37 1994', now: now),
      const Duration(seconds: 30),
    );
  });

  test('user session header is removed from initialization', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requestCount = 0;
    String? receivedSessionHeader;
    final serving = () async {
      await for (final request in server) {
        requestCount++;
        receivedSessionHeader = request.headers.value('MCP-Session-Id');
        await request.drain<void>();
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }();
    final transport = await StreamableHttpClientTransport.create(
      baseUrl: 'http://${server.address.host}:${server.port}/missing',
      headers: const {'mCp-SeSsIoN-Id': ''},
      terminateOnClose: false,
    );
    final client = Client(
      name: 'reserved-header-test',
      version: '1.0.0',
      requestTimeout: const Duration(seconds: 1),
    );

    addTearDown(() async {
      client.dispose();
      await server.close(force: true);
      await serving;
    });

    await expectLater(
      client.connect(transport),
      throwsA(
        isA<McpHttpError>()
            .having((error) => error.sessionIdPresent, 'session', isFalse)
            .having((error) => error.canRetryRequest, 'retry', isFalse),
      ),
    );
    expect(requestCount, 1);
    expect(receivedSessionHeader, isNull);
  });

  test('runtime timeout reaches HTTP headers and DELETE body drain', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final openStreams = <HttpResponse>[];
    final serving = _serveRuntimeTimeout(server, openStreams: openStreams);
    final transport = await StreamableHttpClientTransport.create(
      baseUrl: 'http://${server.address.host}:${server.port}/mcp',
      timeout: const Duration(milliseconds: 50),
      terminateOnClose: false,
    );
    final client = Client(
      name: 'runtime-timeout-test',
      version: '1.0.0',
      requestTimeout: const Duration(seconds: 1),
    );
    await client.connect(transport);

    addTearDown(() async {
      client.dispose();
      for (final stream in openStreams) {
        unawaited(stream.close());
      }
      await server.close(force: true);
      await serving.timeout(const Duration(seconds: 1), onTimeout: () {});
    });

    client.setRequestTimeout(const Duration(milliseconds: 300));
    await client.ping();

    final stopwatch = Stopwatch()..start();
    await client.terminateSession();
    stopwatch.stop();

    expect(
      stopwatch.elapsed,
      greaterThanOrEqualTo(const Duration(milliseconds: 250)),
    );
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
  });

  test(
    'factory retry creates a fresh transport after initialization closes',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final openStreams = <HttpResponse>[];
      var initializeCount = 0;
      final serving = _serveFactoryRetry(
        server,
        openStreams: openStreams,
        onInitialize: () => ++initializeCount,
      );
      final config = McpClient.simpleConfig(
        name: 'factory-retry-test',
        version: '1.0.0',
        requestTimeout: const Duration(seconds: 1),
      ).copyWith(maxRetries: 2, retryDelay: const Duration(milliseconds: 10));

      final result = await McpClient.createAndConnect(
        config: config,
        transportConfig: TransportConfig.streamableHttp(
          baseUrl: 'http://${server.address.host}:${server.port}/mcp',
          terminateOnClose: false,
        ),
      );
      final client = result.getOrNull();

      addTearDown(() async {
        client?.dispose();
        for (final stream in openStreams) {
          unawaited(stream.close());
        }
        await server.close(force: true);
        await serving.timeout(const Duration(seconds: 1), onTimeout: () {});
      });

      expect(client, isNotNull);
      expect(client?.isConnected, isTrue);
      expect(initializeCount, 2);
    },
  );
}

Future<void> _serveOversizedStatelessResponse(
  HttpServer server, {
  required bool useSse,
  List<String>? methods,
  bool oversizedAccepted = false,
  bool oversizedRedirect = false,
}) async {
  await for (final request in server) {
    final message = await _readMessage(request);
    final method = message['method'] as String;
    methods?.add(method);
    if (method == McpProtocol.methodServerDiscover) {
      _writeJson(request.response, {
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'id': message['id'],
        'result': {
          'resultType': 'complete',
          'supportedVersions': [McpProtocol.v2026_07_28],
          'capabilities': {'tools': {}, 'resources': {}},
          '_meta': {
            McpProtocol.metaServerInfo: {
              'name': 'oversized-response-test',
              'version': '1.0.0',
            },
          },
          'ttlMs': 60000,
          'cacheScope': 'private',
        },
      });
      await request.response.close();
      continue;
    }

    if (oversizedAccepted) {
      request.response
        ..statusCode = HttpStatus.accepted
        ..bufferOutput = false;
      request.response.write(List<String>.filled(768, 'x').join());
      await request.response.flush();
      request.response.write(List<String>.filled(768, 'x').join());
      await request.response.close();
      continue;
    }

    if (oversizedRedirect) {
      request.response
        ..statusCode = HttpStatus.temporaryRedirect
        ..headers.set(HttpHeaders.locationHeader, '/mcp/')
        ..bufferOutput = false;
      request.response.write(List<String>.filled(768, 'x').join());
      await request.response.flush();
      request.response.write(List<String>.filled(768, 'x').join());
      await request.response.close();
      continue;
    }

    final payload = jsonEncode({
      'jsonrpc': McpProtocol.jsonRpcVersion,
      'id': message['id'],
      'result': {
        'content': [
          {'type': 'text', 'text': List<String>.filled(4096, 'x').join()},
        ],
        'isError': false,
      },
    });
    request.response.bufferOutput = false;
    if (useSse) {
      request.response.headers.contentType = ContentType('text', 'event-stream');
      final event = 'event: message\\ndata: $payload\\n\\n';
      request.response.write(event.substring(0, 1536));
      await request.response.flush();
      request.response.write(event.substring(1536));
    } else {
      request.response.headers.contentType = ContentType.json;
      request.response.write(payload.substring(0, 1536));
      await request.response.flush();
      request.response.write(payload.substring(1536));
    }
    await request.response.close();
  }
}

Future<Client> _connectClient(
  HttpServer server, {
  required int requestTimeoutSeconds,
}) async {
  final transport = await StreamableHttpClientTransport.create(
    baseUrl: 'http://${server.address.host}:${server.port}/mcp',
    terminateOnClose: false,
  );
  final client = Client(
    name: 'stream-test',
    version: '1.0.0',
    requestTimeout: Duration(seconds: requestTimeoutSeconds),
  );
  await client.connect(transport);
  return client;
}

Map<String, dynamic> _initializeResult(Object? id) => {
  'jsonrpc': '2.0',
  'id': id,
  'result': {
    'protocolVersion': McpProtocol.defaultVersion,
    'serverInfo': {'name': 'Adversarial MCP', 'version': '1.0.0'},
    'capabilities': {'tools': <String, dynamic>{}},
  },
};

Future<Map<String, dynamic>> _readMessage(HttpRequest request) async =>
    jsonDecode(await utf8.decoder.bind(request).join()) as Map<String, dynamic>;

void _writeJson(HttpResponse response, Object value) {
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(value));
}

Future<void> _serveInterruptedPost(
  HttpServer server, {
  required List<HttpResponse> openStreams,
  required void Function() onToolPost,
  required void Function() onResumeGet,
}) async {
  await for (final request in server) {
    if (request.method == 'GET') {
      final cursor = request.headers.value('Last-Event-ID');
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
      );
      if (cursor == null) {
        request.response.write(': public\n\n');
        await request.response.flush();
        openStreams.add(request.response);
      } else {
        onResumeGet();
        request.response.write(
          'id: interrupted-done\n'
          'data: ${jsonEncode({
            'jsonrpc': '2.0',
            'id': 2,
            'result': {
              'content': [
                {'type': 'text', 'text': 'resumed'},
              ],
              'isError': false,
            },
          })}\n\n',
        );
        await request.response.close();
      }
      continue;
    }

    final message = await _readMessage(request);
    if (message['method'] == 'initialize') {
      request.response.headers.set('MCP-Session-Id', 'interrupted-session');
      _writeJson(request.response, _initializeResult(message['id']));
      await request.response.close();
    } else if (message['method'] == 'tools/call') {
      onToolPost();
      final socket = await request.response.detachSocket(writeHeaders: false);
      const event = 'id: interrupted-cursor\ndata:\n\n';
      socket.write(
        'HTTP/1.1 200 OK\r\n'
        'Content-Type: text/event-stream\r\n'
        'Transfer-Encoding: chunked\r\n'
        '\r\n'
        '${event.length.toRadixString(16)}\r\n'
        '$event\r\n',
      );
      await socket.flush();
      socket.destroy();
    } else {
      request.response.statusCode = HttpStatus.accepted;
      await request.response.close();
    }
  }
}

Future<void> _serveRuntimeTimeout(
  HttpServer server, {
  required List<HttpResponse> openStreams,
}) async {
  await for (final request in server) {
    if (request.method == 'GET') {
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
      );
      request.response.write(': public\n\n');
      await request.response.flush();
      openStreams.add(request.response);
      continue;
    }
    if (request.method == 'DELETE') {
      await request.drain<void>();
      request.response
        ..bufferOutput = false
        ..statusCode = HttpStatus.ok
        ..write('held');
      await request.response.flush();
      openStreams.add(request.response);
      continue;
    }

    final message = await _readMessage(request);
    if (message['method'] == 'initialize') {
      request.response.headers.set('MCP-Session-Id', 'timeout-session');
      _writeJson(request.response, _initializeResult(message['id']));
    } else if (message['method'] == 'ping') {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      _writeJson(request.response, {
        'jsonrpc': '2.0',
        'id': message['id'],
        'result': <String, dynamic>{},
      });
    } else {
      request.response.statusCode = HttpStatus.accepted;
    }
    await request.response.close();
  }
}

Future<void> _serveFactoryRetry(
  HttpServer server, {
  required List<HttpResponse> openStreams,
  required int Function() onInitialize,
}) async {
  await for (final request in server) {
    if (request.method == 'GET') {
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
      );
      request.response.write(': public\n\n');
      await request.response.flush();
      openStreams.add(request.response);
      continue;
    }

    final message = await _readMessage(request);
    if (message['method'] == 'initialize') {
      final attempt = onInitialize();
      if (attempt == 1) {
        final socket = await request.response.detachSocket(writeHeaders: false);
        socket.destroy();
        continue;
      }
      request.response.headers.set('MCP-Session-Id', 'factory-session');
      _writeJson(request.response, _initializeResult(message['id']));
    } else {
      request.response.statusCode = HttpStatus.accepted;
    }
    await request.response.close();
  }
}

Future<void> _serveConcurrentResumptions(
  HttpServer server, {
  required List<HttpResponse> openStreams,
  required List<String> resumedIds,
}) async {
  final calls = <String, ({int id, String value})>{};
  await for (final request in server) {
    if (request.method == 'GET') {
      final cursor = request.headers.value('Last-Event-ID');
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
      );
      if (cursor == null) {
        request.response.write(': public\n\n');
        await request.response.flush();
        openStreams.add(request.response);
      } else {
        resumedIds.add(cursor);
        final call = calls[cursor]!;
        request.response.write(
          'id: $cursor-done\n'
          'data: ${jsonEncode({
            'jsonrpc': '2.0',
            'id': call.id,
            'result': {
              'content': [
                {'type': 'text', 'text': call.value},
              ],
              'isError': false,
            },
          })}\n\n',
        );
        await request.response.close();
      }
      continue;
    }

    final message = await _readMessage(request);
    if (message['method'] == 'initialize') {
      request.response.headers.set('MCP-Session-Id', 'concurrent-session');
      _writeJson(request.response, _initializeResult(message['id']));
    } else if (message['method'] == 'tools/call') {
      final id = message['id'] as int;
      final value =
          ((message['params'] as Map)['arguments'] as Map)['value'].toString();
      final cursor = 'post-$id';
      calls[cursor] = (id: id, value: value);
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
      );
      request.response.write('id: $cursor\ndata:\nretry: 1\n\n');
    } else {
      request.response.statusCode = HttpStatus.accepted;
    }
    await request.response.close();
  }
}

Future<void> _serveHeldFinalResponse(
  HttpServer server, {
  required List<HttpResponse> openStreams,
  required Completer<void> pingReceived,
}) async {
  await for (final request in server) {
    if (request.method == 'GET') {
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
      );
      request.response.write(': public\n\n');
      await request.response.flush();
      openStreams.add(request.response);
      continue;
    }
    final message = await _readMessage(request);
    if (message['method'] == 'initialize') {
      request.response.headers.set('MCP-Session-Id', 'held-session');
      _writeJson(request.response, _initializeResult(message['id']));
      await request.response.close();
    } else if (message['method'] == 'tools/call') {
      request.response.bufferOutput = false;
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
      );
      request.response.write(
        'data: ${jsonEncode({
          'jsonrpc': '2.0',
          'id': message['id'],
          'result': {
            'content': [
              {'type': 'text', 'text': 'done'},
            ],
            'isError': false,
          },
        })}\n\n',
      );
      await request.response.flush();
      openStreams.add(request.response);
    } else if (message['method'] == 'ping') {
      if (!pingReceived.isCompleted) pingReceived.complete();
      _writeJson(request.response, {
        'jsonrpc': '2.0',
        'id': message['id'],
        'result': <String, dynamic>{},
      });
      await request.response.close();
    } else {
      request.response.statusCode = HttpStatus.accepted;
      await request.response.close();
    }
  }
}

Future<void> _serveCollidingReverseRequest(
  HttpServer server,
  List<HttpResponse> openStreams,
) async {
  await for (final request in server) {
    if (request.method == 'GET') {
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
      );
      request.response.write(': public\n\n');
      await request.response.flush();
      openStreams.add(request.response);
      continue;
    }
    final message = await _readMessage(request);
    if (message['method'] == 'initialize') {
      request.response.headers.set('MCP-Session-Id', 'collision-session');
      _writeJson(request.response, _initializeResult(message['id']));
      await request.response.close();
    } else if (message['method'] == 'tools/call') {
      final id = message['id'];
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
      );
      request.response.write(
        'data: ${jsonEncode({'jsonrpc': '2.0', 'id': id, 'method': 'roots/list', 'params': <String, dynamic>{}})}\n\n',
      );
      await request.response.flush();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      request.response.write(
        'data: ${jsonEncode({
          'jsonrpc': '2.0',
          'id': id,
          'result': {
            'content': [
              {'type': 'text', 'text': 'original-success'},
            ],
            'isError': false,
          },
        })}\n\n',
      );
      await request.response.close();
    } else if (message['id'] != null && message['method'] == null) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('reverse response rejected');
      await request.response.close();
    } else {
      request.response.statusCode = HttpStatus.accepted;
      await request.response.close();
    }
  }
}

Future<void> _serveRedirectingMcp(
  HttpServer server,
  List<String> requests,
) async {
  await for (final request in server) {
    requests.add('${request.method} ${request.uri.path}');
    if (request.uri.path == '/mcp') {
      request.response
        ..statusCode = HttpStatus.temporaryRedirect
        ..headers.set(HttpHeaders.locationHeader, '/mcp/');
      await request.response.close();
      continue;
    }

    if (request.uri.path != '/mcp/') {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      continue;
    }

    await request.drain<void>();
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType('text', 'event-stream')
      ..headers.set('MCP-Session-Id', 'redirect-test-session')
      ..write(
        'event: message\n'
        'data: ${jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'result': {
            'protocolVersion': McpProtocol.v2025_11_25,
            'serverInfo': {'name': 'Redirect MCP Server', 'version': '1.0.0'},
            'capabilities': {'tools': {}},
          },
        })}\n\n',
      );
    await request.response.close();
  }
}
