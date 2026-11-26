import 'dart:async';

import 'package:mcp_client/mcp_client.dart';
import 'package:test/test.dart';

import 'mock_transport.dart';

Map<String, dynamic> discoveryResult() => {
  'supportedVersions': [McpProtocol.v2026_07_28],
  'capabilities': {
    'tools': {},
    'resources': {},
    'prompts': {},
  },
  '_meta': {
    McpProtocol.metaServerInfo: {'name': 'stateless-test-server', 'version': '1'},
  },
  'resultType': 'complete',
  'ttlMs': 1000,
  'cacheScope': 'private',
};

Future<void> connectStateless(
  Client client,
  MockTransport transport,
) async {
  transport.queueResponse({
    'jsonrpc': McpProtocol.jsonRpcVersion,
    'result': discoveryResult(),
  });
  await client.connect(transport);
}

void main() {
  group('MCP 2026-07-28 MRTR', () {
    late Client client;
    late MockTransport transport;

    setUp(() {
      client = Client(
        name: 'kelivo-test',
        version: '1.0.0',
        protocolVersion: McpProtocol.v2026_07_28,
        capabilities: const ClientCapabilities(
          roots: true,
          sampling: true,
          elicitation: true,
        ),
      );
      transport = MockTransport();
    });

    tearDown(() {
      client.dispose();
    });

    test('elicitation input is fulfilled and original request is retried', () async {
      await connectStateless(client, transport);
      client.onElicitationRequest((params) async {
        expect(params['message'], 'Enter project name');
        return {
          'action': 'accept',
          'content': {'name': 'KELIVO'},
        };
      });
      transport.queueResponse({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'result': {
          'resultType': 'input_required',
          'inputRequests': {
            'project_name': {
              'method': 'elicitation/create',
              'params': {'mode': 'form', 'message': 'Enter project name'},
            },
          },
          'requestState': 'opaque-server-state:do-not-parse',
        },
      });
      transport.queueResponse({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'result': {
          'resultType': 'complete',
          'content': [
            {'type': 'text', 'text': 'done'},
          ],
        },
      });

      final result = await client.callTool('create_project', const {});
      expect(result.content, hasLength(1));

      final requests = transport.sentMessages
          .where((message) => message['method'] == 'tools/call')
          .toList();
      expect(requests, hasLength(2));
      expect(requests[0]['id'], isNot(requests[1]['id']));
      final retryParams = requests[1]['params'] as Map<String, dynamic>;
      expect(retryParams['name'], 'create_project');
      expect(retryParams['arguments'], isEmpty);
      expect(retryParams['inputResponses'], {
        'project_name': {
          'action': 'accept',
          'content': {'name': 'KELIVO'},
        },
      });
      expect(
        retryParams['requestState'],
        'opaque-server-state:do-not-parse',
      );
      expect(
        (retryParams['_meta'] as Map)[McpProtocol.metaProtocolVersion],
        McpProtocol.v2026_07_28,
      );
    });

    test('requestState without inputRequests is echoed unchanged', () async {
      await connectStateless(client, transport);
      transport.queueResponse({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'result': {
          'resultType': 'input_required',
          'requestState': 'opaque-state-+/=',
        },
      });
      transport.queueResponse({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'result': {'resultType': 'complete', 'content': []},
      });

      await client.callTool('continue_work', const {});
      final requests = transport.sentMessages
          .where((message) => message['method'] == 'tools/call')
          .toList();
      expect(requests, hasLength(2));
      final retryParams = requests.last['params'] as Map<String, dynamic>;
      expect(retryParams['requestState'], 'opaque-state-+/=');
      expect(retryParams.containsKey('inputResponses'), isFalse);
    });

    test('rejects unsupported MRTR capabilities without retrying', () async {
      final unsupportedClient = Client(
        name: 'kelivo-test',
        version: '1.0.0',
        protocolVersion: McpProtocol.v2026_07_28,
      );
      addTearDown(unsupportedClient.dispose);
      await connectStateless(unsupportedClient, transport);
      transport.queueResponse({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'result': {
          'resultType': 'input_required',
          'inputRequests': {
            'ask_user': {
              'method': 'elicitation/create',
              'params': {'message': 'This capability was not declared'},
            },
          },
        },
      });

      await expectLater(
        unsupportedClient.callTool('restricted', const {}),
        throwsA(isA<McpError>()),
      );
      expect(
        transport.sentMessages.where((message) => message['method'] == 'tools/call'),
        hasLength(1),
      );
    });

    test('rejects malformed InputRequiredResult and unsupported resultType', () async {
      await connectStateless(client, transport);
      transport.queueResponse({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'result': {'resultType': 'input_required'},
      });
      await expectLater(
        client.callTool('malformed', const {}),
        throwsA(isA<McpError>()),
      );

      transport.queueResponse({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'result': {'resultType': 'partial'},
      });
      await expectLater(
        client.callTool('unsupported', const {}),
        throwsA(isA<McpError>()),
      );
    });

    test('rejects server-initiated requests in stateless mode', () async {
      await connectStateless(client, transport);
      var handlerCalled = false;
      client.onElicitationRequest((params) async {
        handlerCalled = true;
        return {'action': 'decline'};
      });
      final sentBefore = transport.sentMessages.length;

      transport.simulateMessage({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'id': 900,
        'method': 'elicitation/create',
        'params': {'message': 'must use MRTR'},
      });
      await Future<void>.delayed(Duration.zero);

      expect(handlerCalled, isFalse);
      expect(transport.sentMessages, hasLength(sentBefore));
    });
  });

  group('MCP 2026-07-28 notification subscriptions', () {
    late Client client;
    late MockTransport transport;

    setUp(() {
      client = Client(
        name: 'kelivo-test',
        version: '1.0.0',
        protocolVersion: McpProtocol.v2026_07_28,
      );
      transport = MockTransport();
    });

    tearDown(() {
      client.dispose();
    });

    test('uses an object filter and returns after correlated acknowledgement', () async {
      await connectStateless(client, transport);
      client.setRequestTimeout(const Duration(milliseconds: 2));
      final changedMethods = <String>[];
      client.onToolsListChanged(() => changedMethods.add('tools'));
      client.onPromptsListChanged(() => changedMethods.add('prompts'));
      final updatedUris = <String>[];
      client.onResourceUpdated(updatedUris.add);

      final listening = client.listenForNotifications(
        toolsListChanged: true,
        promptsListChanged: true,
        resourceSubscriptions: ['file:///tmp/a'],
      );
      await Future<void>.delayed(Duration.zero);
      final request = transport.sentMessages.singleWhere(
        (message) => message['method'] == McpProtocol.methodSubscriptionsListen,
      );
      final params = request['params'] as Map<String, dynamic>;
      expect(params['notifications'], {
        'toolsListChanged': true,
        'promptsListChanged': true,
        'resourceSubscriptions': ['file:///tmp/a'],
      });
      expect(
        (params['_meta'] as Map)[McpProtocol.metaProtocolVersion],
        McpProtocol.v2026_07_28,
      );

      transport.sendMockNotification({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'method': McpProtocol.methodSubscriptionsAcknowledged,
        'params': {
          '_meta': {
            McpProtocol.metaSubscriptionId: request['id'],
          },
          'notifications': {
            'toolsListChanged': true,
            'promptsListChanged': true,
            'resourceSubscriptions': ['file:///tmp/a'],
          },
        },
      });
      final subscription = await listening;
      expect(subscription.id, request['id']);
      expect(subscription.acceptedFilter, {
        'toolsListChanged': true,
        'promptsListChanged': true,
        'resourceSubscriptions': ['file:///tmp/a'],
      });

      transport.sendMockNotification({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'method': McpProtocol.methodToolListChanged,
        'params': {
          '_meta': {McpProtocol.metaSubscriptionId: request['id']},
        },
      });
      transport.sendMockNotification({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'method': McpProtocol.methodPromptListChanged,
        'params': {
          '_meta': {McpProtocol.metaSubscriptionId: request['id']},
        },
      });
      transport.sendMockNotification({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'method': McpProtocol.methodPromptListChanged,
        'params': {
          '_meta': {McpProtocol.metaSubscriptionId: request['id']},
        },
      });
      transport.sendMockNotification({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'method': McpProtocol.methodResourceUpdated,
        'params': {
          '_meta': {McpProtocol.metaSubscriptionId: request['id']},
          'uri': 'file:///tmp/a',
        },
      });
      transport.sendMockNotification({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'method': McpProtocol.methodResourceUpdated,
        'params': {
          '_meta': {McpProtocol.metaSubscriptionId: request['id']},
          'uri': 'file:///tmp/not-requested',
        },
      });
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(changedMethods, ['tools', 'prompts']);
      expect(updatedUris, ['file:///tmp/a']);

      transport.sendMockNotification({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'id': request['id'],
        'result': {
          'resultType': 'complete',
          '_meta': {McpProtocol.metaSubscriptionId: request['id']},
        },
      });
      await expectLater(subscription.done, completes);
    });

    test('allows the server to acknowledge only a supported subset', () async {
      await connectStateless(client, transport);
      final listening = client.listenForNotifications(
        toolsListChanged: true,
        resourceSubscriptions: ['file:///tmp/a'],
      );
      await Future<void>.delayed(Duration.zero);
      final request = transport.sentMessages.singleWhere(
        (message) => message['method'] == McpProtocol.methodSubscriptionsListen,
      );
      transport.sendMockNotification({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'method': McpProtocol.methodSubscriptionsAcknowledged,
        'params': {
          '_meta': {McpProtocol.metaSubscriptionId: request['id']},
          'notifications': {'toolsListChanged': true},
        },
      });
      final subscription = await listening;
      expect(subscription.acceptedFilter, {'toolsListChanged': true});
      subscription.cancel();
      await expectLater(subscription.done, completes);
    });

    test('cancels only the subscription stream after acknowledgement', () async {
      await connectStateless(client, transport);
      final listening = client.listenForNotifications(toolsListChanged: true);
      await Future<void>.delayed(Duration.zero);
      final request = transport.sentMessages.singleWhere(
        (message) => message['method'] == McpProtocol.methodSubscriptionsListen,
      );
      transport.sendMockNotification({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'method': McpProtocol.methodSubscriptionsAcknowledged,
        'params': {
          '_meta': {McpProtocol.metaSubscriptionId: request['id']},
          'notifications': {'toolsListChanged': true},
        },
      });
      final subscription = await listening;
      subscription.cancel();
      expect(subscription.isCancelled, isTrue);
      await expectLater(subscription.done, completes);
      expect(client.isConnected, isTrue);
    });

    test('rejects an acknowledgement for a different subscription ID', () async {
      await connectStateless(client, transport);
      client.setRequestTimeout(const Duration(milliseconds: 5));
      final listening = client.listenForNotifications(toolsListChanged: true);
      await Future<void>.delayed(Duration.zero);
      final request = transport.sentMessages.singleWhere(
        (message) => message['method'] == McpProtocol.methodSubscriptionsListen,
      );
      transport.sendMockNotification({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'method': McpProtocol.methodSubscriptionsAcknowledged,
        'params': {
          '_meta': {
            McpProtocol.metaSubscriptionId: (request['id'] as int) + 1,
          },
          'notifications': {'toolsListChanged': true},
        },
      });
      transport.sendMockNotification({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'id': request['id'],
        'result': {'resultType': 'complete'},
      });
      await expectLater(listening, throwsA(isA<McpError>()));
    });

    test('rejects empty and malformed subscription filters before sending', () async {
      await connectStateless(client, transport);
      await expectLater(
        client.listenForNotifications(),
        throwsArgumentError,
      );
      await expectLater(
        client.listenForNotifications(
          resourceSubscriptions: ['relative/path'],
        ),
        throwsArgumentError,
      );
      await expectLater(
        client.listenForNotifications(
          resourceSubscriptions: [
            'file:///tmp/a',
            'file:///tmp/a',
          ],
        ),
        throwsArgumentError,
      );
      expect(
        transport.sentMessages.where(
          (message) => message['method'] == McpProtocol.methodSubscriptionsListen,
        ),
        isEmpty,
      );
    });

    test('legacy resource subscription API is not sent in stateless mode', () async {
      await connectStateless(client, transport);
      await expectLater(
        client.subscribeResource('file:///tmp/example'),
        throwsUnsupportedError,
      );
      await expectLater(
        client.unsubscribeResource('file:///tmp/example'),
        throwsUnsupportedError,
      );
      expect(
        transport.sentMessages.where(
          (message) =>
              message['method'] == 'resources/subscribe' ||
              message['method'] == 'resources/unsubscribe',
        ),
        isEmpty,
      );
    }); 
    test('sends STDIO cancellation with the original request ID', () async {
      await connectStateless(client, transport);
      final listening = client.listenForNotifications(toolsListChanged: true);
      await Future<void>.delayed(Duration.zero);
      final request = transport.sentMessages.singleWhere(
        (message) => message['method'] == McpProtocol.methodSubscriptionsListen,
      );
      transport.sendMockNotification({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'method': McpProtocol.methodSubscriptionsAcknowledged,
        'params': {
          '_meta': {McpProtocol.metaSubscriptionId: request['id']},
          'notifications': {'toolsListChanged': true},
        },
      });
      final subscription = await listening;
      subscription.cancel();
      await expectLater(subscription.done, completes);
      expect(
        transport.sentMessages.any(
          (message) =>
              message['method'] == McpProtocol.methodCancelled &&
              (message['params'] as Map)['requestId'] == request['id'],
        ),
        isTrue,
      );
    });

    test('rejects MRTR beyond the local round-trip cap', () async {
      await connectStateless(client, transport);
      for (var i = 0; i < 5; i++) {
        transport.queueResponse({
          'jsonrpc': McpProtocol.jsonRpcVersion,
          'result': {
            'resultType': 'input_required',
            'requestState': 'opaque-$i',
          },
        });
      }
      await expectLater(
        client.callTool('loop', const {}),
        throwsA(isA<McpError>()),
      );
      expect(
        transport.sentMessages.where((message) => message['method'] == 'tools/call'),
        hasLength(5),
      );
    });

    test('uses per-request log metadata and does not send removed 2026 RPCs', () async {
      await connectStateless(client, transport);
      await expectLater(client.ping(), throwsUnsupportedError);
      await client.setLoggingLevel(McpLogLevel.debug);
      client.addRoot(const Root(uri: 'file:///tmp/root', name: 'root'));
      client.removeRoot('file:///tmp/root');

      transport.queueResponse({
        'jsonrpc': McpProtocol.jsonRpcVersion,
        'result': {
          'resultType': 'complete',
          'content': const [],
        },
      });
      await client.callTool('log-aware', const {});
      final call = transport.sentMessages.singleWhere(
        (message) => message['method'] == 'tools/call',
      );
      final metadata = (call['params'] as Map)['_meta'] as Map;
      expect(metadata[McpProtocol.metaLogLevel], 'debug');
      expect(
        transport.sentMessages.any(
          (message) =>
              message['method'] == 'ping' ||
              message['method'] == 'logging/setLevel' ||
              message['method'] == McpProtocol.methodRootListChanged,
        ),
        isFalse,
      );
    });

  });

  test('2026-07-28 advertises Elicitation and requires protocol header', () {
    expect(McpProtocol.supportsElicitation(McpProtocol.v2026_07_28), isTrue);
    expect(McpProtocol.requiresProtocolHeader(McpProtocol.v2026_07_28), isTrue);
  });
}
