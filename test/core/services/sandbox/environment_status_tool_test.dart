import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/services/packages/package_manager_service.dart';
import 'package:Kelivo/core/services/sandbox/environment_status_tool.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/models/tool_permission_mode.dart';
import 'package:Kelivo/core/services/workspace/workspace_paths.dart';
import 'package:Kelivo/core/services/workspace/workspace_tool_context.dart';
import 'package:Kelivo/core/services/workspace/workspace_tools_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/utils/mcp_structured_image.dart';
import '../../../support/business_test_harness.dart';
import '../../../support/fake_workspace_runtime.dart';

final class _FakeProotRuntime extends FakeWorkspaceRuntime {
  @override
  Future<RuntimeStatus> status() async => const RuntimeStatus(
    ready: true,
    engine: 'proot',
    sandboxed: true,
  );
}

final class _FakeNonProotRuntime extends FakeWorkspaceRuntime {
  @override
  Future<RuntimeStatus> status() async => const RuntimeStatus(
    ready: true,
    engine: 'process',
    sandboxed: false,
  );
}

void main() {
  test('exposes a read-only environment diagnostic tool with bounded detail', () {
    final definitions = EnvironmentStatusToolCatalog.definitions();
    expect(definitions, hasLength(1));
    final function = definitions.single['function'] as Map<String, dynamic>;
    expect(function['name'], EnvironmentStatusToolNames.inspect);
    expect(function['description'], contains('Android PRoot host runtime'));
    expect(function['description'], contains('Never run apt install'));
    expect(function['description'], contains('never search for an apt package named proot'));

    final parameters = function['parameters'] as Map<String, dynamic>;
    final properties = parameters['properties'] as Map<String, dynamic>;
    expect((properties['detail'] as Map)['enum'], ['summary', 'full']);
    expect((properties['max_items'] as Map)['minimum'], 1);
    expect((properties['max_items'] as Map)['maximum'], 500);
    expect(parameters['additionalProperties'], isFalse);
  });

  test(
    'reports the KELIVO package ledger even without a registered runtime',
    () async {
      final harness = await createBusinessTestHarness();
      final environment = EnvironmentProvider(
        preferences: harness.preferences,
      );
      addTearDown(environment.dispose);
      final packageManager = PackageManagerService(
        runtime: null,
        environment: environment,
        preferences: harness.preferences,
      );

      final decoded = jsonDecode(
        await EnvironmentStatusService(
          runtime: null,
          environment: environment,
          packageManager: packageManager,
        ).inspect(),
      ) as Map<String, dynamic>;

      expect((decoded['prootHostRuntime'] as Map)['ready'], isFalse);
      expect(
        (decoded['prootSession'] as Map)['reason'],
        'runtime_not_registered',
      );
      final ledger = decoded['kelivoManagedPackageLedger'] as Map;
      expect(ledger['available'], isTrue);
      expect(ledger['recordCount'], 0);
      expect(ledger['liveVerification'], isFalse);
      expect(
        decoded['assistantSummary'],
        contains('no PRoot runtime is registered'),
      );
      expect(
        decoded['assistantSummary'],
        contains('runtime_not_registered'),
      );
    },
  );

  test(
    'does not recommend apt installation when RootFS exists but PRoot host runtime is not registered',
    () async {
      final harness = await createBusinessTestHarness();
      final environment = EnvironmentProvider(
        preferences: harness.preferences,
      );
      addTearDown(environment.dispose);
      final rootfs = await Directory.systemTemp.createTemp(
        'kelivo-rootfs-without-host-runtime-',
      );
      addTearDown(() => rootfs.delete(recursive: true));
      await environment.setState(
        EnvironmentState(
          phase: EnvironmentPhase.ready,
          distro: 'ubuntu',
          version: '24.04.3',
          codename: 'noble',
          arch: 'arm64',
          rootfsDir: rootfs.path,
        ),
      );

      final decoded = jsonDecode(
        await EnvironmentStatusService(
          runtime: null,
          environment: environment,
        ).inspect(),
      ) as Map<String, dynamic>;
      final facts = decoded['verifiedFacts'] as Map;
      expect(facts['rootfsInstalled'], isTrue);
      expect(facts['prootRuntimeRegistered'], isFalse);
      expect(facts['ubuntuReachable'], isFalse);
      expect(
        decoded['assistantSummary'],
        contains('app PRoot runtime is not registered'),
      );
      expect(
        decoded['assistantSummary'],
        contains('Do not tell the user to install proot with apt'),
      );
    },
  );

  test('waits for runtime bootstrap before returning the registered runtime', () async {
    final ready = Completer<void>();
    final runtime = _FakeProotRuntime();
    final provider = WorkspaceRuntimeProvider()..initialization = ready.future;

    final pending = provider.ensureInitialized();
    provider.register(runtime);
    ready.complete();

    expect(await pending, same(runtime));
  });

  test('exposes shell for a ready conversation sandbox with a manual approval boundary', () async {
    final root = await Directory.systemTemp.createTemp('kelivo-chat-workspace-');
    addTearDown(() => root.delete(recursive: true));
    final workspaceRoot = Directory('${root.path}/workspace')..createSync();
    final sessionRoot = Directory('${root.path}/session')..createSync();
    final skillsRoot = Directory('${root.path}/skills')..createSync();
    final now = DateTime.utc(2026, 11, 12);
    final context = WorkspaceToolContext(
      workspace: Workspace(
        id: 'chat_0123456789abcdef01234567',
        name: 'Conversation Workspace',
        kind: WorkspaceKind.managed,
        shellNeedsApproval: true,
        defaultRuntimeProfileId: 'stale-project-profile-id',
        createdAt: now,
        updatedAt: now,
      ),
      binding: const WorkspaceBinding(),
      paths: WorkspacePaths.sandboxed(
        workspaceHostRoot: workspaceRoot.path,
        sessionHostDir: sessionRoot.path,
        skillsHostDir: skillsRoot.path,
      ),
      sessionDir: sessionRoot,
      outputsDir: Directory('${sessionRoot.path}/outputs'),
      conversationId: 'conversation-1',
      runtimeStatus: const RuntimeStatus(
        ready: true,
        engine: 'proot',
        sandboxed: true,
      ),
      runtimeRegistered: true,
      conversationScoped: true,
    );

    // The normal ToolHandlerService callback checks WorkspaceProvider.byId.
    // A chat scratch workspace is intentionally not persisted there; that
    // callback must not turn a missing project record into a blanket disable.
    final toolNames = WorkspaceToolsService(
      isToolEnabled: (_, _) => false,
    )
        .buildToolDefinitions(context)
        .map((item) => (item['function'] as Map)['name'])
        .toSet();
    expect(context.skillsOnly, isFalse);
    expect(context.hasReadyProotRuntime, isTrue);
    expect(context.paths.externalMounts, isEmpty);
    expect(toolNames, contains('shell'));
    expect(toolNames, contains('runtime_profile'));
    final shellDefinition = WorkspaceToolsService()
        .buildToolDefinitions(context)
        .firstWhere((item) => (item['function'] as Map)['name'] == 'shell');
    final shellProperties =
        ((shellDefinition['function'] as Map)['parameters'] as Map)['properties']
            as Map;
    expect(shellProperties.containsKey('runtime_profile_id'), isFalse);
    final prompt = WorkspaceToolsService.buildPromptFragment(context);
    expect(prompt, contains('private per-conversation scratch workspace'));
    expect(prompt, contains('fresh manual approval'));
    expect(
      prompt,
      contains('Runtime Profiles are available only for installed-Skill ownership'),
    );
    expect(prompt, contains('scope=extension'));
    expect(
      prompt,
      contains('shell executes inside the installed Android PRoot guest'),
    );

    final unready = WorkspaceToolContext(
      workspace: context.workspace,
      binding: context.binding,
      paths: context.paths,
      sessionDir: context.sessionDir,
      outputsDir: context.outputsDir,
      conversationId: context.conversationId,
      runtimeStatus: const RuntimeStatus(
        ready: false,
        reason: 'proot_missing',
        engine: 'proot',
        sandboxed: true,
      ),
      runtimeRegistered: true,
      conversationScoped: true,
    );
    expect(unready.hasReadyProotRuntime, isFalse);
    final unreadyService = WorkspaceToolsService();
    final unreadyNames = unreadyService
        .buildToolDefinitions(unready)
        .map((item) => (item['function'] as Map)['name'])
        .toSet();
    expect(unreadyNames, isNot(contains('shell')));
    expect(
      WorkspaceToolsService.buildPromptFragment(unready),
      isNot(contains('shell is one-shot')),
    );
  });

  test('routes chat-scoped shell calls to PRoot after fresh approval in Full Access', () async {
    final root = await Directory.systemTemp.createTemp('kelivo-chat-shell-bridge-');
    addTearDown(() => root.delete(recursive: true));
    final workspaceRoot = Directory('${root.path}/workspace')..createSync();
    final sessionRoot = Directory('${root.path}/session')..createSync();
    final skillsRoot = Directory('${root.path}/skills')..createSync();
    final runtime = _FakeProotRuntime()
      ..enqueueNext([
        const CommandStarted(pid: 77),
        CommandOutput(
          OutputStreamKind.stdout,
          Uint8List.fromList(utf8.encode('UBUNTU_PRoot_BRIDGE_OK\n')),
        ),
        const CommandExited(
          exitCode: 0,
          timedOut: false,
          cancelled: false,
          interrupted: false,
          duration: Duration(milliseconds: 5),
        ),
      ]);
    final runtimeProvider = WorkspaceRuntimeProvider()..register(runtime);
    final approval = ToolApprovalService();
    addTearDown(approval.dispose);
    final pendingApproval = Completer<void>();
    approval.addListener(() {
      if (approval.hasPending && !pendingApproval.isCompleted) {
        pendingApproval.complete();
      }
    });
    final context = WorkspaceToolContext(
      workspace: Workspace(
        id: 'chat_0123456789abcdef01234567',
        name: 'Conversation Workspace',
        kind: WorkspaceKind.managed,
        shellNeedsApproval: true,
        defaultRuntimeProfileId: 'stale-project-profile-id',
        createdAt: DateTime.utc(2026, 11, 12),
        updatedAt: DateTime.utc(2026, 11, 12),
      ),
      binding: const WorkspaceBinding(),
      paths: WorkspacePaths.sandboxed(
        workspaceHostRoot: workspaceRoot.path,
        sessionHostDir: sessionRoot.path,
        skillsHostDir: skillsRoot.path,
      ),
      sessionDir: sessionRoot,
      outputsDir: Directory('${sessionRoot.path}/outputs'),
      conversationId: 'conversation-bridge-1',
      assistantId: 'assistant-1',
      permissionMode: ToolPermissionMode.fullAccess,
      runtimeStatus: const RuntimeStatus(
        ready: true,
        engine: 'proot',
        sandboxed: true,
      ),
      runtimeRegistered: true,
      conversationScoped: true,
    );
    final service = WorkspaceToolsService(
      runtimeProvider: runtimeProvider,
      readPermissionState: (_) => const ToolPermissionState(
        mode: ToolPermissionMode.fullAccess,
        workspaceId: null,
        assistantId: 'assistant-1',
      ),
    );

    final pendingResult = service.handle(
      context,
      'shell',
      const {
        'command': 'printf UBUNTU_PRoot_BRIDGE_OK',
        'runtime_profile_id': 'model-invented-missing-profile-id',
      },
      toolCallId: 'chat-shell-bridge-1',
      approvalService: approval,
      conversationId: 'conversation-bridge-1',
    );
    await pendingApproval.future.timeout(const Duration(seconds: 2));
    expect(approval.pendingRequests, hasLength(1));
    expect(approval.pendingRequests.single.workspaceId, isNull);
    expect(approval.pendingRequests.single.assistantId, 'assistant-1');
    expect(runtime.requests, isEmpty, reason: 'PRoot must not run before approval');

    approval.approve(
      'chat-shell-bridge-1',
      conversationId: 'conversation-bridge-1',
    );
    final result = ClientToolResult.fromHandler(await pendingResult);
    final decoded = jsonDecode(result.content) as Map<String, dynamic>;

    expect(decoded['exit_code'], 0);
    expect(decoded['stdout'], contains('UBUNTU_PRoot_BRIDGE_OK'));
    expect(decoded['runtime_profile_ignored'], isTrue);
    expect(
      decoded['runtime_profile_note'],
      contains('project Runtime Profiles are not applied'),
    );
    expect(runtime.requests, hasLength(1));
    expect(runtime.requests.single.cwd, '/workspace');
    expect(runtime.requests.single.mounts.map((mount) => mount.guest), [
      '/workspace',
      '/chat',
      '/skills',
      '/tmp',
    ]);
  });

  test('does not report a non-PRoot runtime as Ubuntu reachable', () async {
    final harness = await createBusinessTestHarness();
    final environment = EnvironmentProvider(
      preferences: harness.preferences,
    );
    addTearDown(environment.dispose);
    final rootfs = await Directory.systemTemp.createTemp('kelivo-rootfs-non-proot-');
    addTearDown(() => rootfs.delete(recursive: true));
    await environment.setState(
      EnvironmentState(
        phase: EnvironmentPhase.ready,
        distro: 'ubuntu',
        version: '24.04.3',
        codename: 'noble',
        arch: 'arm64',
        rootfsDir: rootfs.path,
      ),
    );
    final runtime = _FakeNonProotRuntime();

    final decoded = jsonDecode(
      await EnvironmentStatusService(
        runtime: runtime,
        environment: environment,
        workspaceAvailable: true,
        conversationScopedWorkspace: true,
      ).inspect(),
    ) as Map<String, dynamic>;

    expect((decoded['prootHostRuntime'] as Map)['reportedReady'], isTrue);
    expect((decoded['prootHostRuntime'] as Map)['ready'], isFalse);
    expect((decoded['prootSession'] as Map)['tested'], isFalse);
    expect((decoded['verifiedFacts'] as Map)['ubuntuReachable'], isFalse);
    expect((decoded['conversationWorkspace'] as Map)['skillExecutionAvailable'], isFalse);
    expect(runtime.requests, isEmpty);
    expect(decoded['assistantSummary'], contains('not ready'));
  });

  test('keeps chat-scoped file tools unbound from synthetic project ids', () async {
    final root = await Directory.systemTemp.createTemp('kelivo-chat-tool-permission-');
    addTearDown(() => root.delete(recursive: true));
    final workspaceRoot = Directory('${root.path}/workspace')..createSync();
    final sessionRoot = Directory('${root.path}/session')..createSync();
    final skillsRoot = Directory('${root.path}/skills')..createSync();
    await File('${workspaceRoot.path}/probe.txt').writeAsString('reachable');
    final now = DateTime.utc(2026, 11, 12);
    final context = WorkspaceToolContext(
      workspace: Workspace(
        id: 'chat_0123456789abcdef01234567',
        name: 'Conversation Workspace',
        kind: WorkspaceKind.managed,
        shellNeedsApproval: true,
        createdAt: now,
        updatedAt: now,
      ),
      binding: const WorkspaceBinding(),
      paths: WorkspacePaths.sandboxed(
        workspaceHostRoot: workspaceRoot.path,
        sessionHostDir: sessionRoot.path,
        skillsHostDir: skillsRoot.path,
      ),
      sessionDir: sessionRoot,
      outputsDir: Directory('${sessionRoot.path}/outputs'),
      conversationId: 'conversation-1',
      assistantId: 'assistant-1',
      runtimeStatus: const RuntimeStatus(
        ready: true,
        engine: 'proot',
        sandboxed: true,
      ),
      runtimeRegistered: true,
      conversationScoped: true,
    );
    final service = WorkspaceToolsService(
      isToolEnabled: (_, _) => false,
      readPermissionState: (_) => const ToolPermissionState(
        mode: ToolPermissionMode.requestApproval,
        workspaceId: null,
        assistantId: 'assistant-1',
      ),
    );

    final raw = await service.handle(
      context,
      'list_dir',
      const {'path': '/workspace'},
      toolCallId: 'chat-list-dir-1',
    );
    final result = raw as ClientToolResult;

    expect(result.content, contains('probe.txt'));
    expect(result.metadata, isNotNull);
    expect(result.content, isNot(contains('context_changed')));
  });

  test('returns a concise structured Ubuntu/PRoot result to the model', () async {
    final harness = await createBusinessTestHarness();
    final environment = EnvironmentProvider(
      preferences: harness.preferences,
    );
    addTearDown(environment.dispose);
    final rootfs = await Directory.systemTemp.createTemp('kelivo-rootfs-');
    addTearDown(() => rootfs.delete(recursive: true));
    await environment.setState(
      EnvironmentState(
        phase: EnvironmentPhase.ready,
        distro: 'ubuntu',
        version: '24.04.3',
        codename: 'noble',
        arch: 'arm64',
        rootfsDir: rootfs.path,
      ),
    );

    final runtime = _FakeProotRuntime()
      ..enqueueNext([
        CommandStarted(pid: 123),
        CommandOutput(
          OutputStreamKind.stdout,
          Uint8List.fromList(utf8.encode('''
__KELIVO_PROOT_SESSION_OK__
OS=Ubuntu 24.04.3 LTS
VERSION=24.04
CODENAME=noble
KERNEL=Linux 6.1
MACHINE=aarch64
SHELL=/bin/bash
apt=available (/usr/bin/apt)
dpkg=available (/usr/bin/dpkg)
python3=available (/usr/bin/python3)
node=not_found

### APT/dpkg installed packages
installedCount=142
''')),
        ),
        const CommandExited(
          exitCode: 0,
          timedOut: false,
          cancelled: false,
          interrupted: false,
          duration: Duration(milliseconds: 10),
        ),
      ]);

    final decoded = jsonDecode(
      await EnvironmentStatusService(
        runtime: runtime,
        environment: environment,
        workspaceAvailable: true,
        conversationScopedWorkspace: true,
      ).inspect(),
    ) as Map<String, dynamic>;

    expect(decoded['assistantSummary'], contains('real command session'));
    expect(decoded['assistantSummary'], contains('Ubuntu 24.04.3 LTS'));
    expect((decoded['prootHostRuntime'] as Map)['ready'], isTrue);
    expect((decoded['prootSession'] as Map)['ready'], isTrue);
    final verifiedFacts = decoded['verifiedFacts'] as Map;
    expect(verifiedFacts['ubuntuReachable'], isTrue);
    expect(verifiedFacts['shellAvailable'], isTrue);
    expect(verifiedFacts['skillExecutionAvailable'], isTrue);
    final inventory = decoded['inventory'] as Map;
    expect(inventory['captured'], isTrue);
    expect(inventory.containsKey('transcript'), isFalse);
    final summary = inventory['summary'] as Map;
    expect(summary['distribution'], 'Ubuntu 24.04.3 LTS');
    expect(summary['availablePackageManagers'], containsAll(['apt', 'dpkg']));
    expect(summary['availableRuntimes'], contains('python3'));
    expect(
      (summary['installedPackageCounts'] as Map)['APT/dpkg installed packages'],
      142,
    );
    final workspace = decoded['conversationWorkspace'] as Map;
    expect(workspace['bound'], isFalse);
    expect(workspace['available'], isTrue);
    expect(workspace['scope'], 'conversation_scratch');
    expect(workspace['shellAvailable'], isTrue);
    expect(workspace['shellRequiresManualApproval'], isTrue);
    expect(workspace['skillExecutionAvailable'], isTrue);
    expect(workspace['availabilityReason'], 'ready');
    expect(decoded['assistantSummary'], contains('private per-conversation workspace'));
    expect(decoded['assistantSummary'], contains('manual approval'));
  });
}
