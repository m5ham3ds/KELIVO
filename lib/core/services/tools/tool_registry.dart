import 'dart:async';
import 'dart:convert';

enum ToolExposure { direct, deferred, hidden }

enum ToolPermissionPolicy { inheritConversation, requireApproval, alwaysRequireApproval, denied }
enum ToolExecutionStatus { succeeded, failed, cancelled }

class ToolRegistryException implements Exception {
  const ToolRegistryException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => '$code: $message';
}

class ToolCancellationException implements Exception {
  const ToolCancellationException([this.reason = 'cancelled']);
  final String reason;
}

class ToolsetDescriptor {
  const ToolsetDescriptor({required this.id, required this.title, this.description = '', this.enabledByDefault = false});
  final String id;
  final String title;
  final String description;
  final bool enabledByDefault;
}

class ToolExecutionInvocation {
  ToolExecutionInvocation({required this.toolCallId, required this.toolName, required Map<String, dynamic> arguments, this.checkCancelled})
    : arguments = _freezeJsonMap(arguments);
  final String toolCallId;
  final String toolName;
  final Map<String, dynamic> arguments;
  final void Function()? checkCancelled;
}

typedef ToolExecutor = FutureOr<ToolExecutionResult> Function(ToolExecutionInvocation invocation);

class ToolExecutionResult {
  const ToolExecutionResult({required this.status, this.code, this.structuredContent, this.safeText = '', this.outputReferences = const <Map<String, Object?>>[], this.duration = Duration.zero, this.retryable = false, this.errorClass});
  final ToolExecutionStatus status;
  final String? code;
  final Object? structuredContent;
  final String safeText;
  final List<Map<String, Object?>> outputReferences;
  final Duration duration;
  final bool retryable;
  final String? errorClass;

  Map<String, Object?> toJson() => <String, Object?>{
    'status': status.name,
    if (code != null) 'code': code,
    if (structuredContent != null) 'structuredContent': structuredContent,
    'safeText': safeText,
    'outputReferences': outputReferences,
    'durationMs': duration.inMilliseconds < 0 ? 0 : duration.inMilliseconds,
    'retryable': retryable,
    if (errorClass != null) 'errorClass': errorClass,
  };
}

class ToolRegistryEntry {
  ToolRegistryEntry({
    required this.namespace,
    required this.name,
    String? exposedName,
    required Map<String, dynamic> definition,
    this.exposure = ToolExposure.direct,
    Set<String> toolsetIds = const <String>{},
    this.permissionPolicy = ToolPermissionPolicy.inheritConversation,
    this.supportsCancellation = true,
    this.maxOutputBytes = 256 * 1024,
    this.executor,
  }) : exposedName = exposedName ?? name,
       definition = _freezeJsonMap(definition),
       toolsetIds = Set<String>.unmodifiable(toolsetIds);

  final String namespace;
  final String name;
  final String exposedName;
  final Map<String, dynamic> definition;
  final ToolExposure exposure;
  final Set<String> toolsetIds;
  final ToolPermissionPolicy permissionPolicy;
  final bool supportsCancellation;
  final int maxOutputBytes;
  final ToolExecutor? executor;
  String get qualifiedId => '$namespace:$name';
  String get description {
    final function = definition['function'];
    if (function is! Map) return '';
    final value = function['description'];
    return value is String ? value : '';
  }
  Map<String, Object?> deferredMetadata() => <String, Object?>{
    'namespace': namespace,
    'name': name,
    'exposedName': exposedName,
    'exposure': exposure.name,
    'description': description,
    'toolsetIds': toolsetIds.toList()..sort(),
    'permissionPolicy': permissionPolicy.name,
    'supportsCancellation': supportsCancellation,
  };
}

class ToolRegistryBuilder {
  final Map<String, ToolsetDescriptor> _toolsets = <String, ToolsetDescriptor>{};
  final Map<String, ToolRegistryEntry> _entries = <String, ToolRegistryEntry>{};
  final Map<String, String> _exposedNames = <String, String>{};

  void registerToolset(ToolsetDescriptor toolset) {
    if (!_isValidToolsetId(toolset.id) || toolset.title.trim().isEmpty) {
      throw const ToolRegistryException('invalid_toolset', 'Toolset id and title must be valid and non-empty.');
    }
    if (_toolsets.containsKey(toolset.id)) {
      throw ToolRegistryException('duplicate_toolset', 'Toolset already registered: ${toolset.id}');
    }
    _toolsets[toolset.id] = toolset;
  }

  void register(ToolRegistryEntry entry) {
    if (!_isValidNamespace(entry.namespace) || !_isValidToolName(entry.name) || !_isValidToolName(entry.exposedName)) {
      throw ToolRegistryException('invalid_tool_identity', 'Invalid tool namespace, name, or exposed name: ${entry.qualifiedId}');
    }
    if (entry.maxOutputBytes < 1 || entry.maxOutputBytes > 1024 * 1024) {
      throw const ToolRegistryException('invalid_tool_output_limit', 'Tool output cap must be between 1 byte and 1 MiB.');
    }
    for (final toolsetId in entry.toolsetIds) {
      if (!_toolsets.containsKey(toolsetId)) {
        throw ToolRegistryException('unknown_toolset', 'Tool ${entry.exposedName} references unknown toolset $toolsetId.');
      }
    }
    _validateDefinition(entry);
    if (_entries.containsKey(entry.qualifiedId)) {
      throw ToolRegistryException('duplicate_tool_identity', 'Tool identity is already registered: ${entry.qualifiedId}');
    }
    final existing = _exposedNames[entry.exposedName];
    if (existing != null) {
      throw ToolRegistryException('tool_name_collision', 'Exposed name ${entry.exposedName} is already owned by $existing.');
    }
    _entries[entry.qualifiedId] = entry;
    _exposedNames[entry.exposedName] = entry.qualifiedId;
  }

  ToolRegistrySnapshot build({Object? adapterSnapshot}) => ToolRegistrySnapshot._(
    entries: _entries.values.toList(growable: false),
    toolsets: _toolsets.values.toList(growable: false),
    adapterSnapshot: adapterSnapshot,
  );

  void _validateDefinition(ToolRegistryEntry entry) {
    final definition = entry.definition;
    if (definition['type'] != 'function') {
      throw const ToolRegistryException('invalid_tool_definition', 'Only provider-neutral function tool definitions are accepted.');
    }
    final function = definition['function'];
    if (function is! Map || function['name'] != entry.exposedName) {
      throw const ToolRegistryException('invalid_tool_definition_name', 'Function name must match the registered exposed name.');
    }
    final parameters = function['parameters'];
    if (parameters is! Map) {
      throw const ToolRegistryException('invalid_tool_schema', 'Function parameters must be a JSON object schema.');
    }
    if (utf8.encode(jsonEncode(parameters)).length > 64 * 1024) {
      throw const ToolRegistryException('tool_schema_too_large', 'Tool schema exceeds the 64 KiB registry limit.');
    }
  }
}

class ToolRegistrySnapshot {
  ToolRegistrySnapshot._({
    required List<ToolRegistryEntry> entries,
    required List<ToolsetDescriptor> toolsets,
    this.adapterSnapshot,
  }) : entries = List<ToolRegistryEntry>.unmodifiable(entries),
      toolsets = List<ToolsetDescriptor>.unmodifiable(toolsets),
      _byExposedName = Map<String, ToolRegistryEntry>.unmodifiable({for (final entry in entries) entry.exposedName: entry}),
      _toolsetsById = Map<String, ToolsetDescriptor>.unmodifiable({for (final toolset in toolsets) toolset.id: toolset});

  final List<ToolRegistryEntry> entries;
  final Object? adapterSnapshot;
  final List<ToolsetDescriptor> toolsets;
  final Map<String, ToolRegistryEntry> _byExposedName;
  final Map<String, ToolsetDescriptor> _toolsetsById;

  factory ToolRegistrySnapshot.fromProviderDefinitions(
    List<Map<String, dynamic>> definitions, {
    Object? adapterSnapshot,
  }) {
    final builder = ToolRegistryBuilder()..registerToolset(const ToolsetDescriptor(id: 'core', title: 'Core tools', description: 'Existing KELIVO tools exposed through the legacy handler.', enabledByDefault: true));
    for (final definition in definitions) {
      final function = definition['function'];
      if (function is! Map || function['name'] is! String) {
        throw const ToolRegistryException('invalid_tool_definition_name', 'A provider tool definition has no function name.');
      }
      final name = function['name'] as String;
      builder.register(ToolRegistryEntry(namespace: 'kelivo', name: name, exposedName: name, definition: definition, toolsetIds: const <String>{'core'}));
    }
    return builder.build(adapterSnapshot: adapterSnapshot);
  }

  ToolRegistryEntry? entryFor(String exposedName) => _byExposedName[exposedName];

  ToolRegistrySession createSession({Set<String>? selectedToolsets, int maxDirectTools = 512, int maxDirectSchemaBytes = 2 * 1024 * 1024, int maxDeferredMetadataBytes = 64 * 1024}) {
    if (maxDirectTools < 0 || maxDirectSchemaBytes < 0 || maxDeferredMetadataBytes < 0) {
      throw const ToolRegistryException('invalid_tool_budget', 'Tool budgets cannot be negative.');
    }
    final enabled = selectedToolsets == null
        ? _toolsetsById.values.where((toolset) => toolset.enabledByDefault).map((toolset) => toolset.id).toSet()
        : Set<String>.unmodifiable(selectedToolsets);
    for (final id in enabled) {
      if (!_toolsetsById.containsKey(id)) {
        throw ToolRegistryException('unknown_toolset', 'Selected toolset is not registered: $id');
      }
    }
    final direct = <ToolRegistryEntry>[];
    final deferred = <ToolRegistryEntry>[];
    var directBytes = 0;
    var deferredBytes = 0;
    for (final entry in entries) {
      if (!_isSelected(entry, enabled)) continue;
      switch (entry.exposure) {
        case ToolExposure.direct:
          direct.add(entry);
          directBytes += utf8.encode(jsonEncode(entry.definition)).length;
          break;
        case ToolExposure.deferred:
          deferred.add(entry);
          deferredBytes += utf8.encode(jsonEncode(entry.deferredMetadata())).length;
          break;
        case ToolExposure.hidden:
          break;
      }
    }
    if (direct.length > maxDirectTools) {
      throw ToolRegistryException('direct_tool_count_budget_exceeded', 'Direct tool count ${direct.length} exceeds limit $maxDirectTools.');
    }
    if (directBytes > maxDirectSchemaBytes) {
      throw const ToolRegistryException('direct_tool_schema_budget_exceeded', 'Direct tool definitions exceed the configured byte budget.');
    }
    if (deferredBytes > maxDeferredMetadataBytes) {
      throw const ToolRegistryException('deferred_metadata_budget_exceeded', 'Deferred tool metadata exceeds the configured byte budget.');
    }
    return ToolRegistrySession._(snapshot: this, selectedToolsets: enabled, directEntries: direct, deferredEntries: deferred, directDefinitionBytes: directBytes);
  }

  Future<ToolExecutionResult> execute(ToolRegistrySession session, ToolExecutionInvocation invocation) async {
    final entry = _byExposedName[invocation.toolName];
    if (entry == null || !session.canExecute(invocation.toolName)) {
      throw const ToolRegistryException('tool_not_exposed', 'The tool is not directly exposed or loaded in this turn.');
    }
    final executor = entry.executor;
    if (executor == null) {
      throw const ToolRegistryException('tool_executor_unavailable', 'The registered adapter has no execution handler.');
    }
    try {
      invocation.checkCancelled?.call();
      final result = await executor(invocation);
      invocation.checkCancelled?.call();
      if (utf8.encode(jsonEncode(result.toJson())).length > entry.maxOutputBytes) {
        return ToolExecutionResult(status: ToolExecutionStatus.failed, code: 'output_limit_exceeded', safeText: 'Tool output exceeded its configured size limit.', duration: result.duration, errorClass: 'output_limit');
      }
      return result;
    } on ToolCancellationException catch (error) {
      return ToolExecutionResult(status: ToolExecutionStatus.cancelled, code: error.reason, safeText: 'Tool execution was cancelled.', errorClass: 'cancelled');
    }
  }

  static bool _isSelected(ToolRegistryEntry entry, Set<String> selectedToolsets) =>
      entry.toolsetIds.isEmpty || entry.toolsetIds.any(selectedToolsets.contains);
}

class ToolRegistrySession {
  ToolRegistrySession._({required ToolRegistrySnapshot snapshot, required Set<String> selectedToolsets, required List<ToolRegistryEntry> directEntries, required List<ToolRegistryEntry> deferredEntries, required this.directDefinitionBytes})
    : _snapshot = snapshot,
      selectedToolsets = Set<String>.unmodifiable(selectedToolsets),
      _directNames = directEntries.map((entry) => entry.exposedName).toSet(),
      _deferredEntries = Map<String, ToolRegistryEntry>.unmodifiable({for (final entry in deferredEntries) entry.exposedName: entry}),
      directDefinitions = List<Map<String, dynamic>>.unmodifiable(directEntries.map((entry) => entry.definition));

  final ToolRegistrySnapshot _snapshot;
  Object? get adapterSnapshot => _snapshot.adapterSnapshot;
  final Set<String> selectedToolsets;
  final Set<String> _directNames;
  final Map<String, ToolRegistryEntry> _deferredEntries;
  final Set<String> _loadedDeferredNames = <String>{};
  final List<Map<String, dynamic>> directDefinitions;
  final int directDefinitionBytes;

  List<Map<String, Object?>> get deferredToolIndex => List<Map<String, Object?>>.unmodifiable(
    _deferredEntries.values.map((entry) => Map<String, Object?>.unmodifiable(entry.deferredMetadata())),
  );

  bool canExecute(String exposedName) => _directNames.contains(exposedName) || _loadedDeferredNames.contains(exposedName);

  Map<String, dynamic> loadDeferredTool(String exposedName) {
    final entry = _deferredEntries[exposedName];
    if (entry == null) {
      throw const ToolRegistryException('deferred_tool_not_found', 'The tool is not available in the selected toolsets.');
    }
    _loadedDeferredNames.add(exposedName);
    return entry.definition;
  }

  bool isToolsetEnabled(String id) => selectedToolsets.contains(id);
  ToolRegistryEntry? entryFor(String exposedName) => _snapshot.entryFor(exposedName);
}


typedef ToolRegistryCallDelegate = Future<Object?> Function(
  String name,
  Map<String, dynamic> arguments, {
  String? toolCallId,
});

typedef ToolRegistryPolicyGate = Future<void> Function(
  ToolRegistryEntry entry, {
  String? toolCallId,
});

/// Turn-scoped exposure gateway. It validates registry membership and the
/// exact adapter snapshot before handing execution to KELIVO's existing
/// permission-aware ToolCallHandler.
class ToolRegistryCallGateway {
  ToolRegistryCallGateway({
    required this.session,
    required this.delegate,
    required Object? expectedAdapterSnapshot,
    this.policyGate,
  }) {
    if (!identical(session.adapterSnapshot, expectedAdapterSnapshot)) {
      throw StateError('tool_registry_adapter_snapshot_mismatch');
    }
  }

  final ToolRegistrySession session;
  final ToolRegistryCallDelegate delegate;
  final ToolRegistryPolicyGate? policyGate;

  Future<Object?> call(
    String name,
    Map<String, dynamic> arguments, {
    String? toolCallId,
  }) async {
    final entry = session.entryFor(name);
    if (entry == null || !session.canExecute(name)) {
      throw const ToolRegistryException(
        'tool_not_exposed',
        'The tool is not directly exposed or loaded in this turn.',
      );
    }

    switch (entry.permissionPolicy) {
      case ToolPermissionPolicy.inheritConversation:
        // The existing ToolCallHandler remains the permission authority.
        break;
      case ToolPermissionPolicy.denied:
        throw const ToolRegistryException(
          'tool_permission_denied',
          'This registered tool is denied by registry policy.',
        );
      case ToolPermissionPolicy.requireApproval:
      case ToolPermissionPolicy.alwaysRequireApproval:
        final gate = policyGate;
        if (gate == null) {
          throw const ToolRegistryException(
            'tool_permission_policy_unavailable',
            'The registry requires an approval gate but none was supplied.',
          );
        }
        await gate(entry, toolCallId: toolCallId);
    }

    return delegate(name, arguments, toolCallId: toolCallId);
  }

  ToolRegistryCallDelegate bind() => call;
}

bool _isValidNamespace(String value) => RegExp(r'^[A-Za-z][A-Za-z0-9._-]{0,63}$').hasMatch(value);
bool _isValidToolName(String value) => RegExp(r'^[A-Za-z_][A-Za-z0-9_.-]{0,63}$').hasMatch(value);
bool _isValidToolsetId(String value) => RegExp(r'^[a-z][a-z0-9._-]{0,63}$').hasMatch(value);

Map<String, dynamic> _freezeJsonMap(Map<String, dynamic> value) {
  final decoded = jsonDecode(jsonEncode(value));
  if (decoded is! Map) {
    throw const ToolRegistryException('invalid_json_value', 'Tool definitions must be JSON objects.');
  }
  return _freezeMap(decoded);
}

Map<String, dynamic> _freezeMap(Map value) => Map<String, dynamic>.unmodifiable({
  for (final entry in value.entries) entry.key.toString(): _freezeValue(entry.value),
});

Object? _freezeValue(Object? value) {
  if (value is Map) return _freezeMap(value);
  if (value is List) return List<Object?>.unmodifiable(value.map(_freezeValue));
  return value;
}