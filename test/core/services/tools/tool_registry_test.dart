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
  });
}