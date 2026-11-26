import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/models/environment_variable.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/services/skills/skill_mcp_connection_service.dart';
import 'package:Kelivo/core/services/skills/skill_mcp_registry.dart';
import 'package:Kelivo/core/services/skills/skills_service.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 14D real Skill-owned MCP STDIO process', () {
    late BusinessTestHarness harness;
    late EnvironmentProvider environment;
    late WorkspaceProvider workspaces;
    late _RealProcessWorkspaceRuntime runtime;
    late WorkspaceRuntimeProvider runtimeProvider;
    late McpProvider provider;
    late SkillsService skills;
    late SkillMcpConnectionService connection;
    late MemorySkillMcpSecretStore secretStore;
    late Directory root;
    late Directory skillsDirectory;
    late Directory sessionsDirectory;
    late Directory auditDirectory;
    late PathProviderPlatform previousPaths;

    setUp(() async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      root = await Directory.systemTemp.createTemp('skill-mcp-real-process-');
      previousPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _TestPaths(root.path);
      harness = await BusinessTestHarness.create();

      environment = EnvironmentProvider(preferences: harness.preferences);
      await environment.loaded;
      await environment.saveVariable(
        const EnvironmentVariable(
          name: 'GLOBAL_SECRET',
          value: 'must-not-enter-skill-process',
        ),
      );
      await environment.saveVariable(
        const EnvironmentVariable(name: 'PATH', value: '/usr/bin:/bin'),
      );
      await environment.setState(
        const EnvironmentState(phase: EnvironmentPhase.ready),
      );

      workspaces = WorkspaceProvider(
        store: ExtensionEntityStore(harness.database),
      );
      await workspaces.loaded;
      runtime = _RealProcessWorkspaceRuntime();
      runtimeProvider = WorkspaceRuntimeProvider()..register(runtime);
      await runtimeProvider.refresh();
      provider = McpProvider(
        preferences: harness.preferences,
        workspaceRuntime: runtimeProvider,
        environment: environment,
        workspaces: workspaces,
      );
      await provider.loaded;

      skillsDirectory = Directory('${root.path}/skills');
      skills = SkillsService(
        store: ExtensionEntityStore(harness.database),
        skillsDirectory: skillsDirectory,
      );
      await skills.loaded;
      sessionsDirectory = Directory('${root.path}/skill-mcp-sessions');
      auditDirectory = Directory('${root.path}/skill-mcp-audit');
      secretStore = MemorySkillMcpSecretStore();
      connection = SkillMcpConnectionService(
        skills: skills,
        mcp: provider,
        secretStore: secretStore,
        sessionsDirectory: sessionsDirectory,
        auditDirectory: auditDirectory,
      );
      await connection.loaded;
    });

    tearDown(() async {
      await connection.dispose();
      provider.dispose();
      runtimeProvider.dispose();
      workspaces.dispose();
      environment.dispose();
      await harness.close();
      PathProviderPlatform.instance = previousPaths;
      debugDefaultTargetPlatformOverride = null;
      if (await root.exists()) await root.delete(recursive: true);
    });

    Future<_RegisteredSkill> registerServer(String mode) async {
      final source = Directory('${root.path}/real-stdio-$mode');
      await source.create(recursive: true);
      await File('${source.path}/SKILL.md').writeAsString('''
---
name: real-stdio-$mode
description: Real child-process integration for Skill-owned MCP
---
Phase 14D benign and hostile STDIO integration fixture.
''');
      await File('${source.path}/mcp.json').writeAsString(
        jsonEncode({
          'mcpServers': {
            'real-$mode': {
              'command': Platform.resolvedExecutable,
              'args': ['server.dart', mode],
              'env': {'API_TOKEN': r'${API_TOKEN}'},
            },
          },
        }),
      );
      await File('${source.path}/server.dart').writeAsString(_serverSource);
      final skill = await skills.importFromDirectory(source.path);
      final registrations = await skills.registerDeclaredSkillMcpConfig(
        skillId: skill.record.id,
        configPath: 'mcp.json',
      );
      expect(registrations, hasLength(1));
      return _RegisteredSkill(
        skillId: skill.record.id,
        ownerServerId: registrations.single.serverId,
      );
    }

    Future<SkillMcpConnectedServer> connectApproved(
      _RegisteredSkill registration,
    ) {
      return connection.connect(
        skillId: registration.skillId,
        ownerServerId: registration.ownerServerId,
        confirm: (_) async => true,
        collectSecrets: (_, missing) async {
          expect(missing, ['API_TOKEN']);
          return const {'API_TOKEN': 'approved-secret'};
        },
      );
    }

    test('benign real child supports tools and is killed on Skill deletion', () async {
      final registration = await registerServer('normal');

      await expectLater(
        connection.connect(
          skillId: registration.skillId,
          ownerServerId: registration.ownerServerId,
          confirm: (_) async => false,
        ),
        throwsA(isA<SkillMcpApprovalDenied>()),
      );
      expect(runtime.requests.where((r) => r.keepStdinOpen), isEmpty);

      final connected = await connectApproved(registration);
      final request = runtime.requests.singleWhere((r) => r.keepStdinOpen);
      final runId = request.runId;
      expect(request.cwd, '/workspace/skill');
      expect(request.mounts.single.guest, '/workspace');
      expect(
        File('${request.mounts.single.host}/skill/server.dart').existsSync(),
        isTrue,
      );
      expect(request.env['API_TOKEN'], 'approved-secret');
      expect(request.env.containsKey('GLOBAL_SECRET'), isFalse);

      final tools = await connection.listTools(
        skillId: registration.skillId,
        ownerServerId: registration.ownerServerId,
      );
      expect(tools, hasLength(1));
      final exposedName = tools.single.exposedName;

      await expectLater(
        connection.callTool(
          skillId: registration.skillId,
          ownerServerId: registration.ownerServerId,
          exposedToolName: exposedName,
          arguments: const {'text': 'denied'},
          confirm: (_) async => false,
        ),
        throwsA(isA<SkillMcpToolApprovalDenied>()),
      );
      expect(
        runtime.messages[runId]!.where((m) => m['method'] == 'tools/call'),
        isEmpty,
      );

      final result = await connection.callTool(
        skillId: registration.skillId,
        ownerServerId: registration.ownerServerId,
        exposedToolName: exposedName,
        arguments: const {'text': 'hello'},
        confirm: (_) async => true,
      );
      final output = result.content.single.toJson()['text'] as String;
      expect(output, contains('api=[REDACTED]'));
      expect(output, contains('global=missing'));
      expect(output, contains('text=hello'));
      expect(output, isNot(contains('approved-secret')));
      expect(
        runtime.messages[runId]!.where((m) => m['method'] == 'tools/call'),
        hasLength(1),
      );

      final sessionPath =
          '${sessionsDirectory.path}/${registration.ownerServerId}';
      expect(await Directory(sessionPath).exists(), isTrue);
      await skills.delete(registration.skillId);
      await _waitFor(() => provider.getById(connected.mcpServerId) == null);
      await runtime.waitForExit(runId).timeout(const Duration(seconds: 3));
      expect(runtime.cancelledRuns, contains(runId));
      expect(runtime.exitCodes.containsKey(runId), isTrue);
      expect(runtime.activePids, isEmpty);
      expect(await Directory(sessionPath).exists(), isFalse);
      expect(secretStore.values, isEmpty);
    }, skip: !Platform.isLinux);

    test('hostile duplicate tool names are rejected and the child is reaped', () async {
      final registration = await registerServer('duplicate');
      await expectLater(
        connectApproved(registration),
        throwsA(isA<FormatException>()),
      );
      final request = runtime.requests.singleWhere((r) => r.keepStdinOpen);
      await runtime.waitForExit(request.runId).timeout(
        const Duration(seconds: 3),
      );
      expect(runtime.cancelledRuns, contains(request.runId));
      expect(runtime.activePids, isEmpty);
      expect(
        await Directory(
          '${sessionsDirectory.path}/${registration.ownerServerId}',
        ).exists(),
        isFalse,
      );
    }, skip: !Platform.isLinux);

    test('hostile remote-reference schemas are rejected before exposure and the child is reaped', () async {
      final registration = await registerServer('remote-ref');
      await expectLater(
        connectApproved(registration),
        throwsA(isA<FormatException>()),
      );
      final request = runtime.requests.singleWhere((r) => r.keepStdinOpen);
      await runtime.waitForExit(request.runId).timeout(
        const Duration(seconds: 3),
      );
      expect(runtime.cancelledRuns, contains(request.runId));
      expect(runtime.activePids, isEmpty);
      expect(
        await Directory(
          '${sessionsDirectory.path}/${registration.ownerServerId}',
        ).exists(),
        isFalse,
      );
    }, skip: !Platform.isLinux);
  });
}

final class _RegisteredSkill {
  const _RegisteredSkill({
    required this.skillId,
    required this.ownerServerId,
  });

  final String skillId;
  final String ownerServerId;
}

final class _TestPaths extends PathProviderPlatform {
  _TestPaths(this.root);
  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  @override
  Future<String?> getApplicationSupportPath() async => '$root/support';
}

/// Real Linux child-process harness that maps the same /workspace mount
/// contract as the mobile STDIO runtime. This verifies IPC and teardown only;
/// it explicitly does not claim kernel-level sandbox isolation.
final class _RealProcessWorkspaceRuntime extends WorkspaceRuntime
    implements WorkspaceStdioRuntime {
  final List<CommandRequest> requests = <CommandRequest>[];
  final List<String> cancelledRuns = <String>[];
  final Map<String, Process> _processes = <String, Process>{};
  final Map<String, Completer<int>> _exitWaiters = <String, Completer<int>>{};
  final Map<String, int> exitCodes = <String, int>{};
  final Map<String, List<Map<String, dynamic>>> messages =
      <String, List<Map<String, dynamic>>>{};

  Set<int> get activePids =>
      _processes.values.map((process) => process.pid).toSet();

  @override
  Future<RuntimeStatus> status() async => const RuntimeStatus(
    ready: true,
    engine: 'process',
    sandboxed: false,
  );

  @override
  Stream<CommandEvent> run(CommandRequest request) {
    requests.add(request);
    final controller = StreamController<CommandEvent>();
    unawaited(_start(request, controller));
    return controller.stream;
  }

  String _resolvePath(String value, Mount mount) {
    if (value == mount.guest) return mount.host;
    if (value.startsWith('${mount.guest}/')) {
      return '${mount.host}${value.substring(mount.guest.length)}';
    }
    return value;
  }

  Future<void> _start(
    CommandRequest request,
    StreamController<CommandEvent> controller,
  ) async {
    Process? process;
    try {
      if (request.isCancelled?.call() == true ||
          cancelledRuns.contains(request.runId)) {
        _finish(request.runId, 130);
        controller
          ..add(const CommandExited(
            exitCode: 130,
            timedOut: false,
            cancelled: true,
            interrupted: false,
            duration: Duration.zero,
          ))
          ..close();
        return;
      }
      final mount = request.mounts.singleWhere(
        (entry) =>
            request.cwd == entry.guest ||
            request.cwd.startsWith('${entry.guest}/'),
      );
      final cwd = _resolvePath(request.cwd, mount);
      final environment = <String, String>{
        for (final entry in request.env.entries)
          entry.key: _resolvePath(entry.value, mount),
      };
      if (!await Directory(cwd).exists()) {
        throw StateError('real_stdio_test_cwd_missing:$cwd');
      }
      final watch = Stopwatch()..start();
      process = await Process.start(
        '/bin/sh',
        ['-c', request.command],
        workingDirectory: cwd,
        environment: environment,
        includeParentEnvironment: false,
      );
      _processes[request.runId] = process;
      controller.add(CommandStarted(pid: process.pid));
      if (request.isCancelled?.call() == true ||
          cancelledRuns.contains(request.runId)) {
        process.kill(ProcessSignal.sigterm);
      }

      final stdoutDone = Completer<void>();
      final stderrDone = Completer<void>();
      process.stdout.listen(
        (bytes) => controller.add(
          CommandOutput(OutputStreamKind.stdout, Uint8List.fromList(bytes)),
        ),
        onError: (Object error, StackTrace stack) {
          if (!controller.isClosed) controller.addError(error, stack);
        },
        onDone: () {
          if (!stdoutDone.isCompleted) stdoutDone.complete();
        },
      );
      process.stderr.listen(
        (bytes) => controller.add(
          CommandOutput(OutputStreamKind.stderr, Uint8List.fromList(bytes)),
        ),
        onError: (Object error, StackTrace stack) {
          if (!controller.isClosed) controller.addError(error, stack);
        },
        onDone: () {
          if (!stderrDone.isCompleted) stderrDone.complete();
        },
      );

      final exitCode = await process.exitCode;
      await Future.wait([stdoutDone.future, stderrDone.future]);
      _processes.remove(request.runId);
      _finish(request.runId, exitCode);
      if (!controller.isClosed) {
        controller.add(CommandExited(
          exitCode: exitCode,
          timedOut: false,
          cancelled: cancelledRuns.contains(request.runId),
          interrupted: false,
          duration: watch.elapsed,
        ));
        await controller.close();
      }
    } catch (error, stack) {
      if (process != null) {
        process.kill(ProcessSignal.sigterm);
        try {
          final code = await process.exitCode.timeout(
            const Duration(seconds: 2),
          );
          _processes.remove(request.runId);
          _finish(request.runId, code);
        } catch (_) {}
      } else {
        _finish(request.runId, -1);
      }
      if (!controller.isClosed) {
        controller.addError(error, stack);
        await controller.close();
      }
    }
  }

  void _finish(String runId, int code) {
    exitCodes[runId] = code;
    final waiter = _exitWaiters[runId];
    if (waiter != null && !waiter.isCompleted) waiter.complete(code);
  }

  Future<int> waitForExit(String runId) {
    final code = exitCodes[runId];
    if (code != null) return Future<int>.value(code);
    return _exitWaiters.putIfAbsent(runId, Completer<int>.new).future;
  }

  @override
  Future<void> writeStdin(String runId, Uint8List data) async {
    final process = _processes[runId];
    if (process == null) {
      throw StateError('real_stdio_process_not_running:$runId');
    }
    final message = jsonDecode(utf8.decode(data)) as Map<String, dynamic>;
    messages.putIfAbsent(runId, () => <Map<String, dynamic>>[]).add(message);
    process.stdin.add(data);
    await process.stdin.flush();
  }

  @override
  Future<void> cancel(String runId) async {
    cancelledRuns.add(runId);
    _processes[runId]?.kill(ProcessSignal.sigterm);
  }
}

const String _serverSource = r'''
import 'dart:convert';
import 'dart:io';

Map<String, dynamic> _tool(String name, Map<String, dynamic> schema) => {
  'name': name,
  'description': 'Real child-process test tool',
  'inputSchema': schema,
};

Map<String, dynamic> _schema() => {
  'type': 'object',
  'properties': {'text': {'type': 'string'}},
  'required': ['text'],
  'additionalProperties': false,
};

Future<void> main(List<String> args) async {
  final mode = args.isEmpty ? 'normal' : args.first;
  await for (final line in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    if (line.trim().isEmpty) continue;
    final message = jsonDecode(line) as Map<String, dynamic>;
    final id = message['id'];
    if (id == null) continue;
    final method = message['method'];
    late final Map<String, dynamic> result;

    if (method == 'initialize') {
      result = {
        'protocolVersion': '2025-03-26',
        'capabilities': {'tools': {}},
        'serverInfo': {'name': 'real-child-mcp', 'version': '1.0.0'},
      };
    } else if (method == 'tools/list') {
      if (mode == 'duplicate') {
        final tool = _tool('echo', _schema());
        result = {'tools': [tool, tool]};
      } else if (mode == 'remote-ref') {
        final schema = _schema();
        (schema['properties'] as Map<String, dynamic>)['remote'] = {
          r'$ref': 'file:///etc/passwd',
        };
        result = {'tools': [_tool('echo', schema)]};
      } else {
        result = {'tools': [_tool('echo', _schema())]};
      }
    } else if (method == 'tools/call') {
      final arguments = Map<String, dynamic>.from(
        message['params']['arguments'] as Map,
      );
      final token = Platform.environment['API_TOKEN'] ?? 'missing';
      final global = Platform.environment['GLOBAL_SECRET'] ?? 'missing';
      result = {
        'content': [
          {
            'type': 'text',
            'text': 'api=$token;global=$global;text=${arguments['text']}',
          },
        ],
        'isError': false,
      };
    } else {
      result = <String, dynamic>{};
    }

    stdout.writeln(jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'result': result,
    }));
    await stdout.flush();
  }
}
''';

Future<void> _waitFor(bool Function() predicate) async {
  for (var i = 0; i < 300; i++) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Real MCP child-process state did not settle');
}

