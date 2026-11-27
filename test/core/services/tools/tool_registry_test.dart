import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/tools/tool_registry.dart';

Map<String, dynamic> _definition(String name, {Map<String, dynamic>? schema}) => <String, dynamic>{
  'type': 'function',
  'function': <String, dynamic>{
    'name': name,
    'description': 'Tool $name',
    'parameters': schema ?? <String, dynamic>{'type': 'object'},
  },
};

void main() {
  group('ToolRegistrySnapshot', () {
    test('keeps direct tools and exposes deferred tools as metadata only', () {
      final builder = ToolRegistryBuilder()
        ..registerToolset(const ToolsetDescriptor(id: 'core', title: 'Core', enabledByDefault: true))
        ..registerToolset(const ToolsetDescriptor(id: 'documents', title: 'Documents'))
        ..register(ToolRegistryEntry(namespace: 'kelivo', name: 'search', definition: _definition('search'), toolsetIds: const <String>{'core'}))
        ..register(ToolRegistryEntry(namespace: 'workspace', name: 'read_document', definition: _definition('read_document'), exposure: ToolExposure.deferred, toolsetIds: const <String>{'documents'}))
        ..register(ToolRegistryEntry(namespace: 'internal', name: 'debug_state', definition: _definition('debug_state'), exposure: ToolExposure.hidden));
      final session = builder.build().createSession(
        selectedToolsets: const <String>{'core', 'documents'},
      );
      expect(session.directDefinitions, hasLength(1));
      expect(session.directDefinitions.single['function']['name'], 'search');
      expect(session.canExecute('search'), isTrue);
      expect(session.canExecute('read_document'), isFalse);
      expect(session.deferredToolIndex, hasLength(1));
      expect(session.deferredToolIndex.single['exposedName'], 'read_document');
      expect(session.deferredToolIndex.single.containsKey('parameters'), isFalse);
      expect(session.deferredToolIndex.single.containsKey('definition'), isFalse);
      expect(session.deferredToolIndex.map((entry) => entry['exposedName']), isNot(contains('debug_state')));
      final loaded = session.loadDeferredTool('read_document');
      expect(loaded['function']['name'], 'read_document');
      expect(session.canExecute('read_document'), isTrue);
      expect(() => session.loadDeferredTool('debug_state'), throwsA(isA<ToolRegistryException>()));
    });

    test('toolset selection excludes unrelated deferred metadata', () {
      final builder = ToolRegistryBuilder()
        ..registerToolset(const ToolsetDescriptor(id: 'core', title: 'Core', enabledByDefault: true))
        ..registerToolset(const ToolsetDescriptor(id: 'browser', title: 'Browser'))
        ..register(ToolRegistryEntry(namespace: 'kelivo', name: 'search', definition: _definition('search'), toolsetIds: const <String>{'core'}))
        ..register(ToolRegistryEntry(namespace: 'browser', name: 'navigate', definition: _definition('navigate'), exposure: ToolExposure.deferred, toolsetIds: const <String>{'browser'}));
      final coreOnly = builder.build().createSession(selectedToolsets: const <String>{'core'});
      expect(coreOnly.directDefinitions, hasLength(1));
      expect(coreOnly.deferredToolIndex, isEmpty);
      expect(() => coreOnly.loadDeferredTool('navigate'), throwsA(isA<ToolRegistryException>()));
    });

    test('rejects exposed-name collisions across namespaces', () {
      final builder = ToolRegistryBuilder()
        ..registerToolset(const ToolsetDescriptor(id: 'core', title: 'Core', enabledByDefault: true))
        ..register(ToolRegistryEntry(namespace: 'kelivo', name: 'read_file', exposedName: 'read_file', definition: _definition('read_file'), toolsetIds: const <String>{'core'}));
      expect(() => builder.register(ToolRegistryEntry(namespace: 'mcp', name: 'read_file', exposedName: 'read_file', definition: _definition('read_file'), toolsetIds: const <String>{'core'})), throwsA(isA<ToolRegistryException>()));
    });

    test('enforces direct tool-count and schema-byte budgets', () {
      final snapshot = ToolRegistrySnapshot.fromProviderDefinitions(<Map<String, dynamic>>[_definition('one'), _definition('two')]);
      expect(() => snapshot.createSession(maxDirectTools: 1), throwsA(isA<ToolRegistryException>()));
      expect(() => snapshot.createSession(maxDirectSchemaBytes: 1), throwsA(isA<ToolRegistryException>()));
    });

    test('assigns provider definitions to source namespaces and selectable toolsets', () {
      final snapshot = ToolRegistrySnapshot.fromProviderDefinitions(
        <Map<String, dynamic>>[
          _definition('search'),
          _definition('remember'),
          _definition('read_document'),
          _definition('mcp_weather'),
        ],
        additionalToolsets: const <ToolsetDescriptor>[
          ToolsetDescriptor(id: 'search', title: 'Search', enabledByDefault: true),
          ToolsetDescriptor(id: 'memory', title: 'Memory', enabledByDefault: true),
          ToolsetDescriptor(id: 'workspace', title: 'Workspace', enabledByDefault: true),
          ToolsetDescriptor(id: 'mcp', title: 'MCP', enabledByDefault: true),
        ],
        namespaceByToolName: const <String, String>{
          'search': 'kelivo.search',
          'remember': 'kelivo.memory',
          'read_document': 'workspace',
          'mcp_weather': 'mcp',
        },
        toolsetByToolName: const <String, String>{
          'search': 'search',
          'remember': 'memory',
          'read_document': 'workspace',
          'mcp_weather': 'mcp',
        },
      );

      expect(
        snapshot.entries.map((entry) => entry.qualifiedId).toSet(),
        <String>{
          'kelivo.search:search',
          'kelivo.memory:remember',
          'workspace:read_document',
          'mcp:mcp_weather',
        },
      );
      expect(
        snapshot.createSession().directDefinitions,
        hasLength(4),
        reason: 'Every source toolset remains enabled by default during migration.',
      );
      final searchOnly = snapshot.createSession(
        selectedToolsets: const <String>{'search'},
      );
      expect(
        searchOnly.directDefinitions
            .map((item) => item['function']['name'])
            .toList(),
        <String>['search'],
      );
    });

    test('loads deferred schemas through the gateway and updates the live provider list', () async {
      final builder = ToolRegistryBuilder()
        ..registerToolset(const ToolsetDescriptor(id: 'video', title: 'Video', enabledByDefault: true))
        ..register(ToolRegistryEntry(
          namespace: 'kelivo.video',
          name: 'video_engine',
          definition: _definition('video_engine'),
          exposure: ToolExposure.deferred,
          toolsetIds: const <String>{'video'},
        ));
      final session = builder.build().createSession();
      final liveDefinitions = session.providerDefinitions;
      expect(liveDefinitions, hasLength(1));
      expect(
        liveDefinitions.single['function']['name'],
        ToolRegistrySession.loadDeferredToolName,
      );
      expect(session.deferredToolIndex.single['exposedName'], 'video_engine');

      var delegated = false;
      final gateway = ToolRegistryCallGateway(
        session: session,
        expectedAdapterSnapshot: null,
        delegate: (_, __, {toolCallId}) async {
          delegated = true;
          return 'unexpected';
        },
      );
      final result = await gateway.call(
        ToolRegistrySession.loadDeferredToolName,
        const <String, dynamic>{'tool_name': 'video_engine'},
        toolCallId: 'call-load-1',
      );

      expect(result, contains('"status":"loaded"'));
      expect(delegated, isFalse);
      expect(session.canExecute('video_engine'), isTrue);
      expect(session.deferredToolIndex, isEmpty);
      expect(liveDefinitions, hasLength(1));
      expect(liveDefinitions.single['function']['name'], 'video_engine');
      expect(
        () => liveDefinitions.add(_definition('mutation')),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('deferred loader refuses an unselected or hidden tool', () async {
      final builder = ToolRegistryBuilder()
        ..registerToolset(const ToolsetDescriptor(id: 'core', title: 'Core', enabledByDefault: true))
        ..registerToolset(const ToolsetDescriptor(id: 'video', title: 'Video'))
        ..register(ToolRegistryEntry(
          namespace: 'kelivo.video',
          name: 'video_engine',
          definition: _definition('video_engine'),
          exposure: ToolExposure.deferred,
          toolsetIds: const <String>{'video'},
        ))
        ..register(ToolRegistryEntry(
          namespace: 'internal',
          name: 'internal_state',
          definition: _definition('internal_state'),
          exposure: ToolExposure.hidden,
          toolsetIds: const <String>{'core'},
        ));
      final session = builder.build().createSession();
      expect(session.deferredToolIndex, isEmpty);
      expect(
        () => session.loadDeferredTool('video_engine'),
        throwsA(isA<ToolRegistryException>()),
      );
      expect(
        () => session.loadDeferredTool('internal_state'),
        throwsA(isA<ToolRegistryException>()),
      );
    });

    test('loading a deferred schema enforces the direct schema byte budget', () {
      final builder = ToolRegistryBuilder()
        ..registerToolset(const ToolsetDescriptor(id: 'video', title: 'Video', enabledByDefault: true))
        ..register(ToolRegistryEntry(
          namespace: 'kelivo.video',
          name: 'video_engine',
          definition: _definition(
            'video_engine',
            schema: <String, dynamic>{
              'type': 'object',
              'properties': {
                'payload': {'type': 'string', 'maxLength': 12000},
              },
            },
          ),
          exposure: ToolExposure.deferred,
          toolsetIds: const <String>{'video'},
        ));
      final session = builder.build().createSession(maxDirectSchemaBytes: 500);
      expect(
        () => session.loadDeferredTool('video_engine'),
        throwsA(isA<ToolRegistryException>()),
      );
      expect(session.canExecute('video_engine'), isFalse);
    });

    test('rejects duplicate names and invalid schemas before exposure', () {
      expect(() => ToolRegistrySnapshot.fromProviderDefinitions(<Map<String, dynamic>>[_definition('duplicate'), _definition('duplicate')]), throwsA(isA<ToolRegistryException>()));
      expect(() => ToolRegistrySnapshot.fromProviderDefinitions(<Map<String, dynamic>>[<String, dynamic>{'type': 'function', 'function': <String, dynamic>{'name': 'broken', 'parameters': 'not-a-schema'}}]), throwsA(isA<ToolRegistryException>()));
    });

    test('freezes registered definitions against later mutation', () {
      final definition = _definition('immutable');
      final snapshot = ToolRegistrySnapshot.fromProviderDefinitions(<Map<String, dynamic>>[definition]);
      (definition['function'] as Map<String, dynamic>)['description'] = 'mutated';
      final returned = snapshot.createSession().directDefinitions.single;
      expect(returned['function']['description'], 'Tool immutable');
      expect(() => (returned['function'] as Map<String, dynamic>)['description'] = 'changed', throwsA(isA<UnsupportedError>()));
    });

    test('normalizes oversized execution results to a safe failure', () async {
      final builder = ToolRegistryBuilder()
        ..registerToolset(const ToolsetDescriptor(id: 'core', title: 'Core', enabledByDefault: true))
        ..register(ToolRegistryEntry(namespace: 'kelivo', name: 'large_output', definition: _definition('large_output'), toolsetIds: const <String>{'core'}, maxOutputBytes: 256, executor: (_) async => ToolExecutionResult(status: ToolExecutionStatus.succeeded, safeText: List<String>.filled(512, 'x').join())));
      final snapshot = builder.build();
      final result = await snapshot.execute(snapshot.createSession(), ToolExecutionInvocation(toolCallId: 'call-1', toolName: 'large_output', arguments: const <String, dynamic>{}));
      expect(result.status, ToolExecutionStatus.failed);
      expect(result.code, 'output_limit_exceeded');
      expect(result.safeText, isNot(contains(List<String>.filled(512, 'x').join())));
    });

    test('cancellation is checked before invoking the executor', () async {
      var executed = false;
      final builder = ToolRegistryBuilder()
        ..registerToolset(const ToolsetDescriptor(id: 'core', title: 'Core', enabledByDefault: true))
        ..register(ToolRegistryEntry(namespace: 'kelivo', name: 'cancelled', definition: _definition('cancelled'), toolsetIds: const <String>{'core'}, executor: (_) async { executed = true; return const ToolExecutionResult(status: ToolExecutionStatus.succeeded); }));
      final snapshot = builder.build();
      final result = await snapshot.execute(snapshot.createSession(), ToolExecutionInvocation(toolCallId: 'call-cancelled', toolName: 'cancelled', arguments: const <String, dynamic>{}, checkCancelled: () => throw const ToolCancellationException()));
      expect(executed, isFalse);
      expect(result.status, ToolExecutionStatus.cancelled);
    });

    test('turn-scoped gateway delegates only registered exposed direct tools', () async {
      final routeSnapshot = Object();
      final snapshot = ToolRegistrySnapshot.fromProviderDefinitions(
        <Map<String, dynamic>>[_definition('search')],
        adapterSnapshot: routeSnapshot,
      );
      final session = snapshot.createSession();
      var calls = 0;
      String? forwardedCallId;
      final gateway = ToolRegistryCallGateway(
        session: session,
        expectedAdapterSnapshot: routeSnapshot,
        delegate: (name, arguments, {toolCallId}) async {
          calls++;
          forwardedCallId = toolCallId;
          expect(name, 'search');
          expect(arguments, const <String, dynamic>{'query': 'kelivo'});
          return 'delegated';
        },
      );
      final result = await gateway.call(
        'search',
        const <String, dynamic>{'query': 'kelivo'},
        toolCallId: 'call-search-1',
      );
      expect(result, 'delegated');
      expect(calls, 1);
      expect(forwardedCallId, 'call-search-1');
      await expectLater(
        gateway.call('not_registered', const <String, dynamic>{}),
        throwsA(isA<ToolRegistryException>()),
      );
      expect(calls, 1);
    });

    test('deferred tools are rejected until loaded in this turn', () async {
      final builder = ToolRegistryBuilder()
        ..registerToolset(const ToolsetDescriptor(id: 'core', title: 'Core', enabledByDefault: true))
        ..registerToolset(const ToolsetDescriptor(id: 'documents', title: 'Documents'))
        ..register(ToolRegistryEntry(
          namespace: 'workspace',
          name: 'read_document',
          definition: _definition('read_document'),
          exposure: ToolExposure.deferred,
          toolsetIds: const <String>{'documents'},
        ));
      final routeSnapshot = Object();
      final session = builder.build(adapterSnapshot: routeSnapshot).createSession(
        selectedToolsets: const <String>{'core', 'documents'},
      );
      var calls = 0;
      final gateway = ToolRegistryCallGateway(
        session: session,
        expectedAdapterSnapshot: routeSnapshot,
        delegate: (name, arguments, {toolCallId}) async {
          calls++;
          return 'loaded';
        },
      );
      await expectLater(
        gateway.call('read_document', const <String, dynamic>{}),
        throwsA(isA<ToolRegistryException>()),
      );
      expect(calls, 0);
      session.loadDeferredTool('read_document');
      expect(
        await gateway.call('read_document', const <String, dynamic>{}),
        'loaded',
      );
      expect(calls, 1);
    });

    test('denied registry policy fails before reaching the legacy handler', () async {
      final builder = ToolRegistryBuilder()
        ..registerToolset(const ToolsetDescriptor(id: 'core', title: 'Core', enabledByDefault: true))
        ..register(ToolRegistryEntry(
          namespace: 'internal',
          name: 'restricted',
          definition: _definition('restricted'),
          toolsetIds: const <String>{'core'},
          permissionPolicy: ToolPermissionPolicy.denied,
        ));
      final session = builder.build().createSession();
      var delegated = false;
      final gateway = ToolRegistryCallGateway(
        session: session,
        expectedAdapterSnapshot: null,
        delegate: (_, __, {toolCallId}) async {
          delegated = true;
          return null;
        },
      );
      await expectLater(
        gateway.call('restricted', const <String, dynamic>{}),
        throwsA(isA<ToolRegistryException>()),
      );
      expect(delegated, isFalse);
    });

    test('approval policies fail closed without a turn approval gate', () async {
      for (final policy in <ToolPermissionPolicy>[
        ToolPermissionPolicy.requireApproval,
        ToolPermissionPolicy.alwaysRequireApproval,
      ]) {
        final builder = ToolRegistryBuilder()
          ..registerToolset(const ToolsetDescriptor(id: 'core', title: 'Core', enabledByDefault: true))
          ..register(ToolRegistryEntry(
            namespace: 'workspace',
            name: 'write_file',
            definition: _definition('write_file'),
            toolsetIds: const <String>{'core'},
            permissionPolicy: policy,
          ));
        final gateway = ToolRegistryCallGateway(
          session: builder.build().createSession(),
          expectedAdapterSnapshot: null,
          delegate: (_, __, {toolCallId}) async => 'unexpected',
        );
        await expectLater(
          gateway.call('write_file', const <String, dynamic>{}),
          throwsA(isA<ToolRegistryException>()),
        );
      }
    });

    test('gateway refuses a different MCP route snapshot identity', () {
      final routeSnapshot = Object();
      final snapshot = ToolRegistrySnapshot.fromProviderDefinitions(
        <Map<String, dynamic>>[_definition('search')],
        adapterSnapshot: routeSnapshot,
      );
      expect(
        () => ToolRegistryCallGateway(
          session: snapshot.createSession(),
          expectedAdapterSnapshot: Object(),
          delegate: (_, __, {toolCallId}) async => null,
        ),
        throwsA(isA<StateError>()),
      );
    });

  });
}