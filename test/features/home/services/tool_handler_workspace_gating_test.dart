import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/mcp/mcp_tool_service.dart';
import 'package:Kelivo/core/services/workspace/workspace_paths.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/core/services/workspace/workspace_tools_service.dart';
import 'package:Kelivo/features/home/services/built_in_tool_names.dart';
import 'package:Kelivo/features/home/services/tool_handler_service.dart';

import '../../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('kelivo_ws_gating_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  WorkspaceToolContext context() {
    final workspace = Directory(p.join(tmp.path, 'ws'))..createSync();
    final session = Directory(p.join(tmp.path, 'session'))..createSync();
    final skills = Directory(p.join(tmp.path, 'skills'))..createSync();
    return WorkspaceToolContext(
      workspace: Workspace(
        id: 'ws1',
        name: 'Test',
        kind: WorkspaceKind.managed,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
      binding: const WorkspaceBinding(workspaceId: 'ws1'),
      paths: WorkspacePaths.native(
        workspaceHostRoot: workspace.path,
        sessionHostDir: session.path,
        skillsHostDir: skills.path,
      ),
      sessionDir: session,
      outputsDir: Directory(p.join(session.path, 'outputs'))..createSync(),
    );
  }

  testWidgets('workspace tools appear only when a context is passed', (
    tester,
  ) async {
    final assistants = AssistantProvider(
      preferences: createBusinessTestPreferences(),
    );
    final mcpProvider = McpProvider(
      preferences: createBusinessTestPreferences(),
    );
    final settings = SettingsProvider(createBusinessTestPreferences());
    addTearDown(assistants.dispose);
    addTearDown(mcpProvider.dispose);
    addTearDown(settings.dispose);
    await settings.loaded;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AssistantProvider>.value(value: assistants),
          ChangeNotifierProvider<McpProvider>.value(value: mcpProvider),
          ChangeNotifierProvider<McpToolService>.value(value: McpToolService()),
        ],
        child: const SizedBox.shrink(),
      ),
    );

    final service = ToolHandlerService(
      contextProvider: tester.element(find.byType(SizedBox)),
    );
    const assistant = Assistant(id: 'a1', name: 'A');

    String nameOf(Map<String, dynamic> def) =>
        (def['function'] as Map)['name'] as String;

    final without = service.buildToolDefinitions(
      settings,
      assistant,
      'openai',
      'gpt-4.1',
      false,
      isToolModel: (_, __) => true,
    );
    expect(
      without.map(nameOf),
      isNot(containsAll(WorkspaceToolsService.toolNames)),
    );
    for (final name in WorkspaceToolsService.toolNames) {
      expect(without.map(nameOf), isNot(contains(name)));
    }

    final withCtx = service.buildToolDefinitions(
      settings,
      assistant,
      'openai',
      'gpt-4.1',
      false,
      isToolModel: (_, __) => true,
      workspaceContext: context(),
    );
    expect(withCtx.map(nameOf), containsAll(WorkspaceToolsService.toolNames));

    final textOnly = service.buildToolDefinitions(
      settings,
      assistant,
      'openai',
      'gpt',
      false,
      isToolModel: (_, __) => true,
      workspaceContext: context(),
    );
    expect(textOnly.map(nameOf), isNot(contains('view_image')));
    expect(textOnly.map(nameOf), contains('read_file'));

    final noTools = service.buildToolDefinitions(
      settings,
      assistant,
      'openai',
      'gpt',
      false,
      isToolModel: (_, __) => false,
      workspaceContext: context(),
    );
    for (final name in WorkspaceToolsService.toolNames) {
      expect(noTools.map(nameOf), isNot(contains(name)));
    }
  });

  testWidgets('ready conversation PRoot context exposes Shell and Skill execution', (
    tester,
  ) async {
    final assistants = AssistantProvider(
      preferences: createBusinessTestPreferences(),
    );
    final mcpProvider = McpProvider(
      preferences: createBusinessTestPreferences(),
    );
    final chatService = _EmptyChatService();
    final settings = SettingsProvider(createBusinessTestPreferences());
    addTearDown(assistants.dispose);
    addTearDown(mcpProvider.dispose);
    addTearDown(chatService.dispose);
    addTearDown(settings.dispose);
    await settings.loaded;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AssistantProvider>.value(value: assistants),
          ChangeNotifierProvider<McpProvider>.value(value: mcpProvider),
          ChangeNotifierProvider<ChatService>.value(
            value: chatService,
          ),
          ChangeNotifierProvider<McpToolService>.value(value: McpToolService()),
        ],
        child: const SizedBox.shrink(),
      ),
    );

    final workspace = Directory(p.join(tmp.path, 'chat-workspace'))
      ..createSync();
    final session = Directory(p.join(tmp.path, 'chat-session'))
      ..createSync();
    final skills = Directory(p.join(tmp.path, 'chat-skills'))
      ..createSync();
    final context = WorkspaceToolContext(
      workspace: Workspace(
        id: 'chat_0123456789abcdef01234567',
        name: 'Conversation Workspace',
        kind: WorkspaceKind.managed,
        shellNeedsApproval: true,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
      binding: const WorkspaceBinding(),
      paths: WorkspacePaths.sandboxed(
        workspaceHostRoot: workspace.path,
        sessionHostDir: session.path,
        skillsHostDir: skills.path,
      ),
      sessionDir: session,
      outputsDir: Directory(p.join(session.path, 'outputs')),
      conversationId: 'conversation-1',
      assistantId: 'a1',
      runtimeStatus: const RuntimeStatus(
        ready: true,
        engine: 'proot',
        sandboxed: true,
      ),
      runtimeRegistered: true,
      conversationScoped: true,
    );
    final service = ToolHandlerService(
      contextProvider: tester.element(find.byType(SizedBox)),
    );
    const assistant = Assistant(id: 'a1', name: 'A');
    String nameOf(Map<String, dynamic> def) =>
        (def['function'] as Map)['name'] as String;

    final definitions = service.buildToolDefinitions(
      settings,
      assistant,
      'openai',
      'gpt-4.1',
      false,
      isToolModel: (_, __) => true,
      workspaceContext: context,
      conversationId: 'conversation-1',
    );
    final names = definitions.map(nameOf).toSet();
    expect(names, contains('shell'));
    expect(names, contains('skill_execute'));
    expect(names, contains('environment_status'));
    expect(names, contains('runtime_profile'));
    expect(names, contains('package_manager'));
  });

  test('workspace tool names are reserved in BuiltInToolNames.all', () {
    expect(BuiltInToolNames.all, containsAll(WorkspaceToolsService.toolNames));
  });
}

/// The MCP catalog reads the current conversation from ChatService when a
/// conversation id is supplied. Keep this test isolated from the database.
class _EmptyChatService extends ChatService {
  @override
  Conversation? getConversation(String id) => null;
}
