import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/models/environment_variable.dart';
import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/core/services/skills/skill_mcp_connection_service.dart';
import 'package:Kelivo/core/services/skills/skill_mcp_registry.dart';
import 'package:Kelivo/core/services/skills/skills_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../support/business_test_harness.dart';
import '../../support/fake_workspace_runtime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    group('fixed workspace binding on ${platform.name}', () {
      late BusinessTestHarness harness;
      late EnvironmentProvider environment;
      late WorkspaceProvider workspaces;
      late WorkspaceRuntimeProvider runtimeProvider;
      late _McpRuntime runtime;
      late McpProvider provider;
      late Directory files;
      late PathProviderPlatform previousPaths;

      setUp(() async {
        debugDefaultTargetPlatformOverride = platform;
        files = await Directory.systemTemp.createTemp('mcp-workspace-');
        previousPaths = PathProviderPlatform.instance;
        PathProviderPlatform.instance = _Paths(files.path);
        harness = await BusinessTestHarness.create();
        environment = EnvironmentProvider(preferences: harness.preferences);
        await environment.loaded;
        await environment.setState(
          const EnvironmentState(phase: EnvironmentPhase.ready),
        );
        workspaces = WorkspaceProvider(
          store: ExtensionEntityStore(harness.database),
        );
        await workspaces.loaded;
        runtime = _McpRuntime();
        runtimeProvider = WorkspaceRuntimeProvider()..register(runtime);
        await runtimeProvider.refresh();
        provider = McpProvider(
          preferences: harness.preferences,
          workspaceRuntime: runtimeProvider,
          environment: environment,
          workspaces: workspaces,
        );
        await provider.loaded;
      });

      tearDown(() async {
        await provider.disconnect('guest');
        provider.dispose();
        runtimeProvider.dispose();
        workspaces.dispose();
        environment.dispose();
        await harness.close();
        PathProviderPlatform.instance = previousPaths;
        debugDefaultTargetPlatformOverride = null;
        await files.delete(recursive: true);
      });

      Future<void> configure(String? workspaceId, {String? cwd}) async {
        await provider.replaceAllFromJson(
          jsonEncode({
            'mcpServers': {
              'guest': {
                'command': 'python3',
                'args': ['./mcp_server.py'],
                if (workspaceId != null) 'workspaceId': workspaceId,
                if (cwd != null) 'workingDirectory': cwd,
              },
            },
          }),
        );
      }

      test(
        'probe and server share only the selected workspace mount',
        () async {
          final workspace = await workspaces.create(name: 'MCP scripts');
          final root = await workspaces.hostRootFor(workspace);
          await configure(workspace.id);
          await _waitFor(() => provider.isConnected('guest'));
          final request = runtime.requests.single;
          expect(request.cwd, '/workspace');
          expect(request.command, "exec 'python3' './mcp_server.py'");
          expect(request.mounts, [Mount(host: root, guest: '/workspace')]);
          expect(runtime.probes.single.mounts, request.mounts);
          expect(runtime.probes.single.cwd, request.cwd);
          expect(provider.getById('guest')!.workspaceId, workspace.id);
          final exported = jsonDecode(provider.exportServersAsUiJson());
          expect(exported['mcpServers']['guest']['workspaceId'], workspace.id);
          final persisted =
              jsonDecode(harness.preferences.getString('mcp_servers_v1')!)
                  as List;
          final saved = McpServerConfig.fromJson(
            Map<String, dynamic>.from(
              persisted.firstWhere((s) => s['id'] == 'guest'),
            ),
          );
          expect(saved.workspaceId, workspace.id);
          expect(saved.copyWith(name: 'Renamed').workspaceId, workspace.id);
          expect(saved.copyWith(clearWorkspace: true).workspaceId, isNull);
        },
      );

      test(
        'explicit cwd is preserved while the workspace remains mounted',
        () async {
          final workspace = await workspaces.create(name: 'Scripts');
          await configure(workspace.id, cwd: '/root');
          await _waitFor(() => provider.isConnected('guest'));
          expect(runtime.requests.single.cwd, '/root');
          expect(runtime.requests.single.mounts.single.guest, '/workspace');
          expect(runtime.probes.single.cwd, '/root');
        },
      );

      test('changing and clearing a binding replaces the process', () async {
        final first = await workspaces.create(name: 'First');
        final second = await workspaces.create(name: 'Second');
        await configure(first.id);
        await _waitFor(() => provider.isConnected('guest'));
        final firstRun = runtime.requests.single.runId;
        await provider.updateServerMetadata(
          provider.getById('guest')!.copyWith(workspaceId: second.id),
        );
        await _waitFor(() => provider.isConnected('guest'));
        expect(runtime.cancelledRuns, contains(firstRun));
        expect(runtime.requests, hasLength(2));
        expect(
          runtime.requests.last.mounts.single.host,
          await workspaces.hostRootFor(second),
        );
        await provider.updateServerMetadata(
          provider.getById('guest')!.copyWith(clearWorkspace: true),
        );
        await _waitFor(() => provider.isConnected('guest'));
        expect(runtime.requests, hasLength(3));
        expect(runtime.requests.last.mounts, isEmpty);
        expect(runtime.requests.last.cwd, '/root');
        expect(runtime.probes.last.mounts, isEmpty);
      });

      test(
        'renaming or using a workspace does not restart the server',
        () async {
          final workspace = await workspaces.create(name: 'Scripts');
          await configure(workspace.id);
          await _waitFor(() => provider.isConnected('guest'));
          await workspaces.update(workspace.copyWith(name: 'Renamed'));
          await workspaces.touchLastUsed(workspace.id);
          await workspaces.create(name: 'Unrelated');
          await Future<void>.delayed(Duration.zero);
          expect(runtime.requests, hasLength(1));
          expect(runtime.cancelledRuns, isEmpty);
        },
      );

      test(
        'deleted workspace stops the server and prevents unbound startup',
        () async {
          final workspace = await workspaces.create(name: 'Scripts');
          await configure(workspace.id);
          await _waitFor(() => provider.isConnected('guest'));
          final run = runtime.requests.single.runId;
          await workspaces.delete(workspace.id);
          await _waitFor(() => provider.statusFor('guest') == McpStatus.error);
          expect(runtime.cancelledRuns, contains(run));
          expect(
            provider.errorFor('guest'),
            contains('Bound workspace not found'),
          );
          expect(provider.getById('guest')!.workspaceId, workspace.id);
          await provider.connect('guest');
          expect(runtime.requests, hasLength(1));
          expect(runtime.probes, hasLength(1));
        },
      );

      test(
        'missing imported workspace reports an error before probing',
        () async {
          await configure('missing-workspace');
          await _waitFor(() => provider.statusFor('guest') == McpStatus.error);
          expect(
            provider.errorFor('guest'),
            contains('Bound workspace not found'),
          );
          expect(runtime.requests, isEmpty);
          expect(runtime.probes, isEmpty);
        },
      );

      test('addServer persists and mounts its optional workspace', () async {
        final workspace = await workspaces.create(name: 'Scripts');
        final id = await provider.addServer(
          enabled: true,
          name: 'Workspace server',
          transport: McpTransportType.stdio,
          command: 'python3',
          workspaceId: workspace.id,
        );
        await _waitFor(() => provider.isConnected(id));
        expect(provider.getById(id)!.workspaceId, workspace.id);
        expect(
          runtime.requests.single.mounts.single.host,
          await workspaces.hostRootFor(workspace),
        );
        await provider.disconnect(id);
      });

      test(
        'deleting a workspace cancels blocked initialization immediately',
        () async {
          runtime = _McpRuntime(holdFirstInitialization: true);
          runtimeProvider.register(runtime);
          await runtimeProvider.refresh();
          final workspace = await workspaces.create(name: 'Scripts');
          await configure(workspace.id);
          await runtime.initializationStarted.future;
          final runId = runtime.requests.single.runId;
          try {
            await workspaces.delete(workspace.id);
            await _waitFor(() => runtime.cancelledRuns.contains(runId));
            await _waitFor(
              () => provider.statusFor('guest') == McpStatus.error,
            );
            expect(runtime.releaseInitialization.isCompleted, isFalse);
            expect(
              provider.errorFor('guest'),
              contains('Bound workspace not found'),
            );
            expect(runtime.requests, hasLength(1));
          } finally {
            runtime.releaseInitialization.complete();
          }
        },
      );

      test(
        'changing a binding during initialization discards the old connection',
        () async {
          runtime = _McpRuntime(holdFirstInitialization: true);
          runtimeProvider.register(runtime);
          await runtimeProvider.refresh();
          addTearDown(() {
            if (!runtime.releaseInitialization.isCompleted) {
              runtime.releaseInitialization.complete();
            }
          });
          final first = await workspaces.create(name: 'First');
          final second = await workspaces.create(name: 'Second');
          await configure(first.id);
          await runtime.initializationStarted.future;
          final update = provider.updateServerMetadata(
            provider.getById('guest')!.copyWith(workspaceId: second.id),
          );
          await update.timeout(const Duration(seconds: 2));
          await _waitFor(() => provider.isConnected('guest'));
          expect(runtime.releaseInitialization.isCompleted, isFalse);
          expect(runtime.requests, hasLength(2));
          expect(runtime.cancelledRuns, contains(runtime.requests.first.runId));
          expect(
            runtime.requests.last.mounts.single.host,
            await workspaces.hostRootFor(second),
          );
        },
      );

      test(
        'moving a linked workspace reconnects and missing folders fail',
        () async {
          final first = await Directory('${files.path}/first folder').create();
          final second = await Directory(
            '${files.path}/second folder',
          ).create();
          final workspace = await workspaces.create(
            name: 'Linked scripts',
            kind: WorkspaceKind.linked,
            hostPath: first.path,
          );
          await configure(workspace.id);
          await _waitFor(() => provider.isConnected('guest'));
          await workspaces.update(workspace.copyWith(hostPath: second.path));
          await _waitFor(
            () => provider.isConnected('guest') && runtime.requests.length == 2,
          );
          expect(runtime.requests.last.mounts.single.host, second.path);
          await workspaces.update(
            workspace.copyWith(hostPath: '${files.path}/missing'),
          );
          await _waitFor(() => provider.statusFor('guest') == McpStatus.error);
          expect(
            provider.errorFor('guest'),
            contains('workspace folder is unavailable'),
          );
          expect(runtime.requests, hasLength(2));
          expect(await Directory('${files.path}/missing').exists(), isFalse);
        },
      );

      test(
        'reloading config and workspaces restores the binding before startup',
        () async {
          final workspace = await workspaces.create(name: 'Scripts');
          await configure(workspace.id);
          await _waitFor(() => provider.isConnected('guest'));
          await provider.disconnect('guest');
          provider.dispose();
          workspaces.dispose();
          workspaces = WorkspaceProvider(
            store: ExtensionEntityStore(harness.database),
          );
          provider = McpProvider(
            preferences: harness.preferences,
            workspaceRuntime: runtimeProvider,
            environment: environment,
            workspaces: workspaces,
          );
          await provider.loaded;
          await _waitFor(() => provider.isConnected('guest'));
          expect(runtime.requests, hasLength(2));
          expect(runtime.requests.last.mounts, runtime.requests.first.mounts);
        },
      );
    });
  }

  test(
    'desktop rejects a mobile binding before launching a host process',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final harness = await createBusinessTestHarness();
      final provider = McpProvider(preferences: harness.preferences);
      addTearDown(() {
        provider.dispose();
        debugDefaultTargetPlatformOverride = null;
      });
      await provider.replaceAllFromJson(
        jsonEncode({
          'mcpServers': {
            'guest': {'command': 'python3', 'workspaceId': 'mobile-workspace'},
          },
        }),
      );
      await _waitFor(() => provider.statusFor('guest') == McpStatus.error);
      expect(
        provider.errorFor('guest'),
        contains('requires the mobile Linux environment'),
      );
    },
  );

  test(
    'package startup can outlast tool timeout, which is restored after connect',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final harness = await BusinessTestHarness.create();
      final environment = EnvironmentProvider(preferences: harness.preferences);
      await environment.loaded;
      await environment.setState(
        const EnvironmentState(phase: EnvironmentPhase.ready),
      );
      final runtime = _McpRuntime(
        holdFirstInitialization: true,
        stallToolCalls: true,
      );
      final runtimeProvider = WorkspaceRuntimeProvider()..register(runtime);
      await runtimeProvider.refresh();
      final provider = McpProvider(
        preferences: harness.preferences,
        workspaceRuntime: runtimeProvider,
        environment: environment,
      );
      addTearDown(() async {
        provider.dispose();
        runtimeProvider.dispose();
        environment.dispose();
        await harness.close();
        debugDefaultTargetPlatformOverride = null;
      });
      await provider.updateRequestTimeout(const Duration(milliseconds: 20));
      await provider.replaceAllFromJson(
        jsonEncode({
          'mcpServers': {
            'guest': {'command': 'server'},
          },
        }),
      );
      await runtime.initializationStarted.future;
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(provider.statusFor('guest'), McpStatus.connecting);
      runtime.releaseInitialization.complete();
      await _waitFor(() => provider.isConnected('guest'));
      final result = await provider
          .callTool('guest', 'slow', {})
          .timeout(const Duration(seconds: 1));
      expect(
        result!.content.single.toJson()['text'],
        contains('Request timed out: tools/call'),
      );
      expect(provider.requestTimeout, const Duration(milliseconds: 20));
    },
  );

  for (final duringInitialization in [true, false]) {
    test(
      'stdio exit keeps diagnostics (initializing=$duringInitialization)',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final harness = await BusinessTestHarness.create();
        final environment = EnvironmentProvider(
          preferences: harness.preferences,
        );
        await environment.loaded;
        await environment.setState(
          const EnvironmentState(phase: EnvironmentPhase.ready),
        );
        final runtime = _McpRuntime(failInitialization: duringInitialization);
        final runtimeProvider = WorkspaceRuntimeProvider()..register(runtime);
        await runtimeProvider.refresh();
        final provider = McpProvider(
          preferences: harness.preferences,
          workspaceRuntime: runtimeProvider,
          environment: environment,
        );
        addTearDown(() async {
          provider.dispose();
          runtimeProvider.dispose();
          environment.dispose();
          await harness.close();
          debugDefaultTargetPlatformOverride = null;
        });
        await provider.replaceAllFromJson(
          jsonEncode({
            'mcpServers': {
              'guest': {'command': 'server'},
            },
          }),
        );
        if (!duringInitialization) {
          await _waitFor(() => provider.isConnected('guest'));
          runtime.failProcess(runtime.requests.single.runId);
        }
        await _waitFor(() => provider.statusFor('guest') == McpStatus.error);
        expect(provider.errorFor('guest'), contains('code 1'));
        expect(provider.errorFor('guest'), contains('Package not found'));
      },
    );
  }

  for (final disableBeforeCleanup in [false, true]) {
    test(
      'environment recovery cancels initialization and waits for process cleanup (disabled=$disableBeforeCleanup)',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final harness = await BusinessTestHarness.create();
        final environment = EnvironmentProvider(
          preferences: harness.preferences,
        );
        await environment.loaded;
        await environment.setState(
          const EnvironmentState(phase: EnvironmentPhase.ready),
        );
        final cancellationGate = Completer<void>();
        final runtime = _McpRuntime(
          holdFirstInitialization: true,
          cancellationGate: cancellationGate,
        );
        final runtimeProvider = WorkspaceRuntimeProvider()..register(runtime);
        await runtimeProvider.refresh();
        final provider = McpProvider(
          preferences: harness.preferences,
          workspaceRuntime: runtimeProvider,
          environment: environment,
        );
        addTearDown(() async {
          if (!cancellationGate.isCompleted) cancellationGate.complete();
          if (!runtime.releaseInitialization.isCompleted) {
            runtime.releaseInitialization.complete();
          }
          provider.dispose();
          runtimeProvider.dispose();
          environment.dispose();
          await harness.close();
          debugDefaultTargetPlatformOverride = null;
        });
        await provider.replaceAllFromJson(
          jsonEncode({
            'mcpServers': {
              'guest': {'command': 'server'},
            },
          }),
        );
        await runtime.initializationStarted.future;
        for (var i = 0; i < 2; i++) {
          await environment.setState(
            const EnvironmentState(phase: EnvironmentPhase.patching),
          );
          await environment.setState(
            const EnvironmentState(phase: EnvironmentPhase.ready),
          );
        }
        expect(runtime.requests, hasLength(1));
        if (disableBeforeCleanup) {
          await environment.setState(const EnvironmentState());
        }
        expect(runtime.cancelledRuns, contains(runtime.requests.first.runId));
        cancellationGate.complete();
        if (disableBeforeCleanup) {
          await _waitFor(() => runtime.cancelled);
          await Future<void>.delayed(const Duration(milliseconds: 100));
          expect(runtime.requests, hasLength(1));
          expect(provider.isConnected('guest'), isFalse);
        } else {
          await _waitFor(() => provider.isConnected('guest'));
          expect(runtime.requests, hasLength(2));
          expect(runtime.cancelled, isTrue);
        }
        expect(runtime.releaseInitialization.isCompleted, isFalse);
      },
    );
  }

  test(
    'mobile keeps imported stdio config hidden until environment is ready, then disconnects on removal',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final harness = await BusinessTestHarness.create();
      final environment = EnvironmentProvider(preferences: harness.preferences);
      await environment.loaded;
      final runtime = _McpRuntime();
      final runtimeProvider = WorkspaceRuntimeProvider()..register(runtime);
      await runtimeProvider.refresh();
      final provider = McpProvider(
        preferences: harness.preferences,
        workspaceRuntime: runtimeProvider,
        environment: environment,
      );
      addTearDown(() async {
        provider.dispose();
        runtimeProvider.dispose();
        environment.dispose();
        await harness.close();
        debugDefaultTargetPlatformOverride = null;
      });
      await provider.replaceAllFromJson(
        jsonEncode({
          'mcpServers': {
            'guest': {
              'command': 'npx',
              'args': ['-y', 'server', 'a b'],
              'env': {'TOKEN': 'server-value'},
              'workingDirectory': '/root/project',
            },
          },
        }),
      );
      expect(provider.supportsStdio, isFalse);
      expect(provider.servers.any((s) => s.id == 'guest'), isFalse);
      expect(runtime.requests, isEmpty);
      final exported = jsonDecode(provider.exportServersAsUiJson());
      expect(exported['mcpServers']['guest']['args'], ['-y', 'server', 'a b']);
      await environment.saveVariable(
        const EnvironmentVariable(name: 'GLOBAL', value: 'global-value'),
      );
      await environment.saveVariable(
        const EnvironmentVariable(name: 'TOKEN', value: 'global-token'),
      );
      await environment.setState(
        const EnvironmentState(phase: EnvironmentPhase.ready),
      );
      await _waitFor(() => provider.statusFor('guest') == McpStatus.connected);
      expect(provider.supportsStdio, isTrue);
      expect(provider.servers.any((s) => s.id == 'guest'), isTrue);
      expect(runtime.requests.single.cwd, '/root/project');
      expect(runtime.requests.single.env, {
        'GLOBAL': 'global-value',
        'TOKEN': 'server-value',
      });
      await environment.setState(const EnvironmentState());
      await _waitFor(() => runtime.cancelled);
      expect(provider.supportsStdio, isFalse);
      expect(provider.servers.any((s) => s.id == 'guest'), isFalse);
      expect(provider.isConnected('guest'), isFalse);
      expect(provider.getById('guest')?.command, 'npx');
    },
  );

  test(
    'Skill MCP launches only after approval in a verified private session and never inherits global secrets',
    () async {
      debugDefaultTargetPlatformOverride=TargetPlatform.android;
      final root=await Directory.systemTemp.createTemp('skill-mcp-e2e-');
      final oldPaths=PathProviderPlatform.instance;
      PathProviderPlatform.instance=_Paths(root.path);
      final harness=await BusinessTestHarness.create();
      final environment=EnvironmentProvider(preferences:harness.preferences);
      await environment.loaded;
      await environment.saveVariable(
        const EnvironmentVariable(name:'GLOBAL_SECRET',value:'global-secret-value'),
      );
      await environment.saveVariable(
        const EnvironmentVariable(name:'PATH',value:'/usr/bin:/bin'),
      );
      await environment.setState(
        const EnvironmentState(phase:EnvironmentPhase.ready),
      );
      final workspaces=WorkspaceProvider(
        store:ExtensionEntityStore(harness.database),
      );
      await workspaces.loaded;
      final toolSchema = <String, dynamic>{
        'type': 'object',
        'properties': {
          'prompt': {'type': 'string', 'minLength': 1},
          'api_token': {'type': 'string'},
          'context': {'type': 'string'},
        },
        'required': ['prompt'],
        'additionalProperties': false,
      };
      final runtime = _McpRuntime(
        tools: <Map<String, dynamic>>[
          {
            'name': 'echo',
            'description': 'Returns the supplied prompt',
            'inputSchema': toolSchema,
          },
        ],
        toolResultText: 'tool output includes approved-secret',
      );
      final runtimeProvider=WorkspaceRuntimeProvider()..register(runtime);
      await runtimeProvider.refresh();
      final provider=McpProvider(
        preferences:harness.preferences,
        workspaceRuntime:runtimeProvider,
        environment:environment,
        workspaces:workspaces,
      );
      await provider.loaded;

      final skillsDirectory=Directory(root.path+'/skills');
      final skills=SkillsService(
        store:ExtensionEntityStore(harness.database),
        skillsDirectory:skillsDirectory,
      );
      await skills.loaded;
      final source=Directory(root.path+'/isolated-mcp-skill');
      await source.create(recursive:true);
      await File(source.path+'/SKILL.md').writeAsString('''
---
name: isolated-mcp-skill
description: Verify Skill-owned MCP connection approval
---
The Skill server is never started during import.
''');
      await File(source.path+'/mcp.json').writeAsString(
        r'''{"mcpServers":{"demo":{"command":"python3","args":["server.py"],"env":{"API_TOKEN":"${API_TOKEN}"}}}}''',
      );
      await File(source.path+'/server.py').writeAsString('print("mcp demo")\n');

      final skill=await skills.importFromDirectory(source.path);
      final registrations=await skills.registerDeclaredSkillMcpConfig(
        skillId:skill.record.id,
        configPath:'mcp.json',
      );
      expect(registrations,hasLength(1));
      expect(registrations.single.enabled,isFalse);
      expect(registrations.single.sourceDigest,matches(RegExp(r'^[a-f0-9]{64}$')));

      final secretStore = MemorySkillMcpSecretStore();
      final sessionRoot = Directory(root.path + '/skill-mcp-sessions');
      final auditRoot = Directory(root.path + '/skill-mcp-audit');
      final connection = SkillMcpConnectionService(
        skills: skills,
        mcp: provider,
        secretStore: secretStore,
        sessionsDirectory: sessionRoot,
        auditDirectory: auditRoot,
      );
      await connection.loaded;
      String? activeOwner;
      addTearDown(() async {
        if (activeOwner != null) {
          try {
            final ownerToDisconnect = activeOwner;
            await connection.disconnect(
              skillId: skill.record.id,
              ownerServerId: ownerToDisconnect,
            );
          } catch (_) {}
        }
        await connection.dispose();
        skills.dispose();
        provider.dispose();
        runtimeProvider.dispose();
        workspaces.dispose();
        environment.dispose();
        await harness.close();
        PathProviderPlatform.instance=oldPaths;
        debugDefaultTargetPlatformOverride=null;
        if(await root.exists())await root.delete(recursive:true);
      });

      await expectLater(
        connection.connect(
          skillId:skill.record.id,
          ownerServerId:registrations.single.serverId,
          confirm:(preview) async {
            expect(preview.command,'python3');
            expect(preview.arguments,['server.py']);
            expect(preview.environmentVariableNames,['API_TOKEN']);
            expect(preview.securityWarning,contains('not a kernel sandbox'));
            return false;
          },
        ),
        throwsA(isA<SkillMcpApprovalDenied>()),
      );
      expect(runtime.requests,isEmpty,
        reason:'a denied approval must not start a process');

      final connected=await connection.connect(
        skillId:skill.record.id,
        ownerServerId:registrations.single.serverId,
        confirm:(preview) async {
          expect(preview.workspaceScope,contains('verified'));
          return true;
        },
        collectSecrets:(preview,missing) async {
          expect(missing,['API_TOKEN']);
          return <String,String>{'API_TOKEN':'approved-secret'};
        },
      );
      activeOwner=registrations.single.serverId;
      expect(connection.isConnected(skill.record.id,registrations.single.serverId),isTrue);
      expect(runtime.requests,hasLength(1));
      final request=runtime.requests.single;
      expect(request.cwd,'/workspace/skill');
      expect(request.mounts,hasLength(1));
      expect(request.mounts.single.guest,'/workspace');
      expect(request.mounts.single.host,isNot(skillsDirectory.path));
      expect(File(request.mounts.single.host+'/skill/SKILL.md').existsSync(),isTrue);
      expect(File(request.mounts.single.host+'/skill/server.py').existsSync(),isTrue);
      expect(request.env['API_TOKEN'],'approved-secret');
      expect(request.env.containsKey('GLOBAL_SECRET'),isFalse);
      expect(request.env['HOME'],'/workspace/.home');
      expect(request.env['TMPDIR'],'/workspace/.tmp');

      expect(provider.servers.any((entry)=>entry.id==connected.mcpServerId),isFalse);
      expect(provider.connectedServers.any((entry)=>entry.id==connected.mcpServerId),isFalse);
      final export=jsonDecode(provider.exportServersAsUiJson()) as Map;
      expect((export['mcpServers'] as Map).containsKey(connected.mcpServerId),isFalse);
      final saved=harness.preferences.getString('mcp_servers_v1')??'';
      expect(saved,isNot(contains(connected.mcpServerId)));
      expect(saved,isNot(contains('approved-secret')));
      expect(secretStore.values.values, contains('approved-secret'));
      expect(connected.discoveredToolCount, 1);

      final discovered = await connection.listTools(
        skillId: skill.record.id,
        ownerServerId: registrations.single.serverId,
      );
      expect(discovered, hasLength(1));
      final exposedToolName = discovered.single.exposedName;
      expect(exposedToolName, isNotEmpty);
      expect(exposedToolName.length, lessThanOrEqualTo(64));
      expect(exposedToolName.startsWith('skill_echo_'), isTrue);
      expect(discovered.single.requiresManualApproval, isTrue);

      var approvalPromptedForInvalidInput = false;
      await expectLater(
        connection.callTool(
          skillId: skill.record.id,
          ownerServerId: registrations.single.serverId,
          exposedToolName: exposedToolName,
          arguments: const <String, dynamic>{},
          confirm: (_) async {
            approvalPromptedForInvalidInput = true;
            return true;
          },
        ),
        throwsA(isA<FormatException>()),
      );
      expect(approvalPromptedForInvalidInput, isFalse);
      expect(runtime.toolCalls, isEmpty);

      SkillMcpToolCallPreview? deniedPreview;
      await expectLater(
        connection.callTool(
          skillId: skill.record.id,
          ownerServerId: registrations.single.serverId,
          exposedToolName: exposedToolName,
          arguments: const <String, dynamic>{
            'prompt': 'private user prompt',
            'api_token': 'approved-secret',
            'context': 'approved-secret',
          },
          confirm: (preview) async {
            deniedPreview = preview;
            return false;
          },
        ),
        throwsA(isA<SkillMcpToolApprovalDenied>()),
      );
      expect(deniedPreview!.redactedArguments['api_token'], '[REDACTED]');
      expect(deniedPreview!.redactedArguments['context'], '[REDACTED]');
      expect(runtime.toolCalls, isEmpty,
          reason: 'a denied tool approval must never reach tools/call');

      final approvedResult = await connection.callTool(
        skillId: skill.record.id,
        ownerServerId: registrations.single.serverId,
        exposedToolName: exposedToolName,
        arguments: const <String, dynamic>{
          'prompt': 'safe request',
          'api_token': 'approved-secret',
          'context': 'approved-secret',
        },
        confirm: (preview) async {
          expect(preview.tool.exposedName, exposedToolName);
          expect(preview.redactedArguments['api_token'], '[REDACTED]');
          expect(preview.redactedArguments['context'], '[REDACTED]');
          return true;
        },
      );
      expect(runtime.toolCalls, hasLength(1));
      expect((runtime.toolCalls.single['params'] as Map)['name'], 'echo');
      final returnedText =
          approvedResult.content.single.toJson()['text'] as String;
      expect(returnedText, contains('[REDACTED]'));
      expect(returnedText, isNot(contains('approved-secret')));

      final changedSchema = <String, dynamic>{
        ...toolSchema,
        'properties': <String, dynamic>{
          ...Map<String, dynamic>.from(toolSchema['properties'] as Map),
          'new_field': {'type': 'boolean'},
        },
      };
      await expectLater(
        connection.callTool(
          skillId: skill.record.id,
          ownerServerId: registrations.single.serverId,
          exposedToolName: exposedToolName,
          arguments: const <String, dynamic>{'prompt': 'stale schema test'},
          confirm: (_) async {
            runtime.tools = <Map<String, dynamic>>[
              {
                'name': 'echo',
                'description': 'Returns the supplied prompt',
                'inputSchema': changedSchema,
              },
            ];
            return true;
          },
        ),
        throwsA(isA<SkillMcpProviderSessionChanged>()),
      );
      expect(runtime.toolCalls, hasLength(1),
          reason: 'schema drift after approval must prevent tool execution');
      runtime.tools = <Map<String, dynamic>>[
        {
          'name': 'echo',
          'description': 'Returns the supplied prompt',
          'inputSchema': toolSchema,
        },
      ];

      final auditFile = File(
        auditRoot.path + '/skill-mcp-tool-audit-v1.jsonl',
      );
      expect(await auditFile.exists(), isTrue);
      final auditContents = await auditFile.readAsString();
      expect(auditContents, contains('"outcome":"denied"'));
      expect(auditContents, contains('"outcome":"approved"'));
      expect(auditContents, contains('"outcome":"success"'));
      expect(auditContents, contains('"outcome":"failed"'));
      expect(auditContents, isNot(contains('approved-secret')));
      expect(auditContents, isNot(contains('private user prompt')));

      final callResult = await provider.callTool(
        connected.mcpServerId,
        'echo',
        <String, dynamic>{'prompt': 'generic bypass'},
      );
      expect(callResult, isNotNull,
          reason: 'generic MCP calls must never bypass Skill approval');

      final callResult=await provider.callTool(
        connected.mcpServerId,'not-approved',<String,dynamic>{},
      );
      expect(callResult,isNotNull,
        reason:'generic MCP calls are blocked until the 13Q.4 per-tool approval layer');
      await connection.disconnect(
        skillId: skill.record.id,
        ownerServerId: registrations.single.serverId,
      );
      activeOwner=null;
      expect(runtime.cancelledRuns,contains(request.runId));
      expect(provider.getById(connected.mcpServerId),isNull);
      expect(
        await Directory(sessionRoot.path+'/'+registrations.single.serverId).exists(),
        isFalse,
      );
      expect(
        await File(skillsDirectory.path+'/'+skill.record.id+'/SKILL.md').exists(),
        isTrue,
      );
    },
  );

}

Future<void> _waitFor(bool Function() predicate) async {
  for (var i = 0; i < 200; i++) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('MCP state did not settle');
}

class _McpRuntime extends FakeWorkspaceRuntime
    implements WorkspaceStdioRuntime {
  _McpRuntime({
    this.holdFirstInitialization = false,
    this.failInitialization = false,
    this.stallToolCalls = false,
    this.cancellationGate,
    List<Map<String, dynamic>> tools = const <Map<String, dynamic>>[],
    this.toolResultText = 'tool result',
  }) : tools = List<Map<String, dynamic>>.of(tools);
  final bool holdFirstInitialization;
  final bool failInitialization;
  final bool stallToolCalls;
  final Completer<void>? cancellationGate;
  List<Map<String, dynamic>> tools;
  final String toolResultText;
  final toolCalls = <Map<String, dynamic>>[];
  final initializationStarted = Completer<void>();
  final releaseInitialization = Completer<void>();
  final events = <String, StreamController<CommandEvent>>{};
  final probes = <CommandRequest>[];
  final cancelledRuns = <String>[];
  bool cancelled = false;
  @override
  Stream<CommandEvent> run(CommandRequest request) {
    if (!request.keepStdinOpen) {
      probes.add(request);
      return Stream.value(
        const CommandExited(
          exitCode: 0,
          timedOut: false,
          cancelled: false,
          interrupted: false,
          duration: Duration.zero,
        ),
      );
    }
    requests.add(request);
    final stream = StreamController<CommandEvent>();
    events[request.runId] = stream;
    stream.add(const CommandStarted());
    return stream.stream;
  }

  @override
  Future<void> writeStdin(String runId, Uint8List data) async {
    final request = jsonDecode(utf8.decode(data)) as Map<String, dynamic>;
    if (!request.containsKey('id')) return;
    if (stallToolCalls && request['method'] == 'tools/call') return;
    if (request['method'] == 'initialize' && runId == requests.first.runId) {
      if (failInitialization) {
        failProcess(runId);
        return;
      }
      if (!initializationStarted.isCompleted) initializationStarted.complete();
      if (holdFirstInitialization) await releaseInitialization.future;
    }
    final method = request['method'];
    late final Map<String, dynamic> result;
    if (method == 'initialize') {
      result = {
        'protocolVersion': '2025-03-26',
        'capabilities': {'tools': {}},
        'serverInfo': {'name': 'guest', 'version': '1'},
      };
    } else if (method == 'tools/list') {
      result = {'tools': tools};
    } else if (method == 'tools/call') {
      toolCalls.add(Map<String, dynamic>.from(request));
      result = {
        'content': [
          {'type': 'text', 'text': toolResultText},
        ],
        'isError': false,
      };
    } else {
      result = <String, dynamic>{};
    }
    events[runId]!.add(
      CommandOutput(
        OutputStreamKind.stdout,
        Uint8List.fromList(
          utf8.encode(
            '${jsonEncode({'jsonrpc': '2.0', 'id': request['id'], 'result': result})}\n',
          ),
        ),
      ),
    );
  }

  void failProcess(String runId) {
    events[runId]!.add(
      CommandOutput(
        OutputStreamKind.stderr,
        Uint8List.fromList(utf8.encode('Package not found\n')),
      ),
    );
    events[runId]!.add(
      const CommandExited(
        exitCode: 1,
        timedOut: false,
        cancelled: false,
        interrupted: false,
        duration: Duration.zero,
      ),
    );
  }

  @override
  Future<void> cancel(String runId) async {
    cancelled = true;
    cancelledRuns.add(runId);
    await cancellationGate?.future;
  }
}

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final String root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  @override
  Future<String?> getApplicationSupportPath() async => '$root/support';
}
