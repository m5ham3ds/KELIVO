import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/tool_permission_mode.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/extensions/extension_command_tools.dart';
import 'package:Kelivo/core/services/extensions/skill_composition_tools.dart';
import 'package:Kelivo/core/services/extensions/skill_execution_tools.dart';
import 'package:Kelivo/core/services/packages/package_manager_tools.dart';
import 'package:Kelivo/core/services/video_engines/video_engine_tools.dart';
import 'package:Kelivo/core/services/video_providers/video_provider_tools.dart';
import 'package:Kelivo/core/services/video_production/video_production_tools.dart';
import 'package:Kelivo/core/services/video_hybrid/video_hybrid_workflow_tools.dart';
import 'package:Kelivo/core/services/video_quality/video_quality_tools.dart';
import 'package:Kelivo/core/services/workspace/tool_run_registry.dart';
import 'package:Kelivo/core/services/workspace/workspace_tool_metadata.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/features/chat/widgets/produced_files_row.dart';
import 'package:Kelivo/features/chat/widgets/workspace_tool_detail.dart';
import 'package:Kelivo/features/chat/widgets/workspace_tool_ui.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/features/workspace/workspace_navigation.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/custom_bottom_sheet.dart';
import 'package:Kelivo/shared/widgets/ios_form_text_field.dart';

import '../../../support/business_test_harness.dart';

class _FakeChatService extends ChatService {
  Conversation conversation = Conversation(
    id: 'c1',
    title: 'Chat',
    extras: const WorkspaceBinding(workspaceId: 'ws1').applyTo({}),
  );

  @override
  Conversation? getConversation(String id) =>
      id == conversation.id ? conversation : null;

  @override
  Future<void> updateConversationExtras(
    String conversationId,
    Map<String, dynamic> Function(Map<String, dynamic>) update, {
    Conversation? expectedOwner,
  }) async {
    expect(conversationId, conversation.id);
    conversation = conversation.copyWith(extras: update(conversation.extras));
    notifyListeners();
  }
}

ToolUIPart _uiPart({
  required String tool,
  WorkspaceToolMetadata? meta,
  String id = 'tc-1',
  Map<String, dynamic>? arguments,
  String? content,
  bool loading = false,
  Map<String, dynamic>? extraMetadata,
}) {
  return ToolUIPart(
    id: id,
    toolName: tool,
    arguments: arguments ?? const <String, dynamic>{},
    content: content,
    metadata: meta == null && extraMetadata == null
        ? null
        : <String, dynamic>{...?meta?.toJson(), ...?extraMetadata},
    loading: loading,
  );
}

Widget _harness({
  required List<ToolUIPart> toolParts,
  ToolRunRegistry? registry,
  ToolApprovalService? approval,
  ChatService? chat,
  Locale? locale,
}) {
  return MultiProvider(
    providers: [
      if (chat != null) ChangeNotifierProvider<ChatService>.value(value: chat),
      ChangeNotifierProvider(
        create: (_) => SettingsProvider(createBusinessTestPreferences()),
      ),
      ChangeNotifierProvider(
        create: (_) =>
            AssistantProvider(preferences: createBusinessTestPreferences()),
      ),
      ChangeNotifierProvider(
        create: (_) =>
            TtsProvider(preferences: createBusinessTestPreferences()),
      ),
      ChangeNotifierProvider(
        create: (_) =>
            UserProvider(preferences: createBusinessTestPreferences()),
      ),
      if (registry != null)
        ChangeNotifierProvider<ToolRunRegistry>.value(value: registry)
      else
        ChangeNotifierProvider(create: (_) => ToolRunRegistry()),
      ChangeNotifierProvider(create: (_) => approval ?? ToolApprovalService()),
      ChangeNotifierProvider(create: (_) => AskUserInteractionService()),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ChatMessageWidget(
          showModelIcon: false,
          showToolCards: true,
          message: ChatMessage(
            id: 'm1',
            role: 'assistant',
            conversationId: 'c1',
            content: '',
          ),
          toolParts: toolParts,
        ),
      ),
    ),
  );
}

Finder get _timelineIconColumn =>
    find.byKey(const ValueKey('chatMessageTimelineIconColumn:true:true'));

void main() {
  test(
    'stored shell tail folds stdout and stderr while file previews retain frames',
    () {
      const meta = WorkspaceToolMetadata(
        tool: 'shell',
        status: 'ok',
        stdoutPreview: '10%\r\x1b[32m100%\x1b[0m',
        stderrPreview: 'warning\rfixed',
      );
      expect(
        workspaceOutputTailLines(
          part: const WorkspaceToolPart(id: 'progress', toolName: 'shell'),
          meta: meta,
        ),
        ['100%', 'fixed'],
      );
      expect(
        workspaceOutputTailLines(
          part: const WorkspaceToolPart(id: 'read', toolName: 'read_file'),
          meta: const WorkspaceToolMetadata(
            tool: 'read_file',
            status: 'ok',
            stdoutPreview: '10%\r100%',
          ),
        ),
        ['10%', '100%'],
      );
    },
  );

  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    WorkspaceNavigation.onOpenEnvironmentPage = null;
    WorkspaceNavigation.onOpenTerminal = null;
    WorkspaceNavigation.onOpenWorkspaceFiles = null;
  });

  testWidgets(
    'each workspace tool renders its title and icon in the timeline',
    (tester) async {
      const cases = <(String, IconData, String)>[
        ('shell', Lucide.Terminal, 'Run command'),
        ('read_file', Lucide.FileText, 'Read file'),
        ('view_image', Lucide.Image, 'View image'),
        ('write_file', Lucide.FilePlus, 'Write file'),
        ('edit_file', Lucide.FilePen, 'Edit file'),
        ('list_dir', Lucide.FolderOpen, 'List directory'),
        ('glob', Lucide.FileSearch, 'Glob'),
        ('grep', Lucide.TextSearch, 'Grep'),
        (ExtensionCommandToolNames.search, Lucide.Search, 'Search Skills'),
        (ExtensionCommandToolNames.inspect, Lucide.FileText, 'Inspect Skill'),
        (ExtensionCommandToolNames.install, Lucide.Download, 'Install Skill'),
        (ExtensionCommandToolNames.update, Lucide.RefreshCw, 'Update Skill'),
        (ExtensionCommandToolNames.enable, Lucide.CheckCircle, 'Enable Skill'),
        (ExtensionCommandToolNames.disable, Lucide.Ban, 'Disable Skill'),
        (ExtensionCommandToolNames.remove, Lucide.Trash2, 'Remove Skill'),
        (
          ExtensionCommandToolNames.rollback,
          Lucide.RotateCcw,
          'Rollback Skill',
        ),
        (ExtensionCommandToolNames.list, Lucide.ListTodo, 'Installed Skills'),
        (SkillCompositionToolNames.compose, Lucide.Layers, 'Plan Skill Composition'),
        (PackageManagerToolNames.manage, Lucide.Package, 'Manage Packages'),
        (VideoEngineToolNames.manage, Lucide.FileVideo, 'Manage Video Engines'),
        (VideoProductionToolNames.manage, Lucide.FileVideo, 'Manage Video Production'),
        (VideoProviderToolNames.manage, Lucide.KeyRound, 'Manage AI Video Providers'),
        (VideoHybridWorkflowToolNames.manage, Lucide.GitFork, 'Compose Hybrid Video Workflow'),
        (VideoQualityToolNames.manage, Lucide.ClipboardCheck, 'Review Video Quality'),
      ];
      for (final (tool, icon, title) in cases) {
        await tester.pumpWidget(
          _harness(
            toolParts: [
              _uiPart(
                tool: tool,
                arguments: {
                  'command': 'ls',
                  'path': 'src/app.dart',
                  'pattern': '*.dart',
                  'content': 'a\nb\n',
                },
                meta: WorkspaceToolMetadata(
                  tool: tool,
                  status: 'ok',
                  path: 'src/app.dart',
                  command: 'ls',
                  added: 1,
                  removed: 1,
                  count: 2,
                ),
              ),
            ],
          ),
        );
        await tester.pump();
        expect(_timelineIconColumn, findsOneWidget);
        expect(find.text(title), findsOneWidget);
        expect(find.byIcon(icon), findsWidgets);
        expect(find.byIcon(Lucide.ChevronRight), findsOneWidget);
      }
    },
  );

  testWidgets('AI video provider tool renders its workspace card', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        toolParts: [
          _uiPart(
            tool: VideoProviderToolNames.manage,
            arguments: const {'action': 'list'},
            content: jsonEncode({'ok': true, 'action': 'list', 'providers': []}),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('Manage AI Video Providers'), findsOneWidget);
    expect(find.byIcon(Lucide.KeyRound), findsWidgets);
    expect(_timelineIconColumn, findsOneWidget);
  });

  testWidgets('quality review tool renders its workspace card', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        toolParts: [
          _uiPart(
            tool: VideoQualityToolNames.manage,
            arguments: const {'action': 'inspect'},
            content: jsonEncode({'ok': true, 'status': 'passed', 'counts': {'errors': 0, 'warnings': 0}}),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('Review Video Quality'), findsOneWidget);
    expect(find.byIcon(Lucide.ClipboardCheck), findsWidgets);
    expect(_timelineIconColumn, findsOneWidget);
  });

  testWidgets('hybrid workflow tool renders its workspace card', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        toolParts: [
          _uiPart(
            tool: VideoHybridWorkflowToolNames.manage,
            arguments: const {'action': 'status'},
            content: jsonEncode({'ok': true, 'action': 'status', 'status': 'configured'}),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('Compose Hybrid Video Workflow'), findsOneWidget);
    expect(find.byIcon(Lucide.GitFork), findsWidgets);
    expect(_timelineIconColumn, findsOneWidget);
  });

  testWidgets('extension install tool shows live operation progress', (
    tester,
  ) async {
    final registry = ToolRunRegistry();
    final run = registry.start(
      'ext-call-1',
      ExtensionCommandToolNames.install,
      command: 'install https://github.com/acme/demo/tree/main',
      conversationId: 'c1',
    );
    run.appendStdout(
      Uint8List.fromList(
        utf8.encode('Started install\nDownloading skill archive\n'),
      ),
    );
    await tester.pumpWidget(
      _harness(
        registry: registry,
        toolParts: [
          _uiPart(
            tool: ExtensionCommandToolNames.install,
            id: 'ext-call-1',
            arguments: {'source': 'https://github.com/acme/demo/tree/main'},
            loading: true,
          ),
        ],
      ),
    );
    await tester.pump();
    expect(find.text('Install Skill'), findsOneWidget);
    expect(find.textContaining('Downloading skill archive'), findsOneWidget);
    run.complete(status: ToolRunStatus.succeeded, retainUntilHandoff: true);
    expect(
      registry.of('ext-call-1', conversationId: 'c1')?.status,
      ToolRunStatus.succeeded,
    );
    await tester.pumpWidget(
      _harness(
        registry: registry,
        toolParts: [
          _uiPart(
            tool: ExtensionCommandToolNames.install,
            id: 'ext-call-1',
            arguments: {'source': 'https://github.com/acme/demo/tree/main'},
            content: 'Installed successfully.',
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
    // The status text appends the elapsed duration (for example,
    // `Completed · 12 ms`), so exact-text matching would reject a valid
    // completed state. Assert the semantic status key and the visible label.
    expect(find.byKey(WorkspaceStatusBadge.completedKey), findsOneWidget);
    expect(find.textContaining('Completed'), findsOneWidget);
    registry.dispose();
  });

  testWidgets('skill composition output shows selected Skills and dependency stages', (
    tester,
  ) async {
    final result = jsonEncode({
      'status': 'ready_with_warnings',
      'selectedSkillIds': ['story-plan', 'scene-builder'],
      'selectionReasons': {
        'story-plan': 'Explicitly requested.',
        'scene-builder': 'Required by story-plan.',
      },
      'executionStages': [
        {'stage': 1, 'parallel': false, 'skillIds': ['story-plan']},
        {'stage': 2, 'parallel': false, 'skillIds': ['scene-builder']},
      ],
      'issues': [
        {
          'severity': 'warning',
          'code': 'permissions_require_review',
          'message': 'A selected Skill requests permissions.',
        },
      ],
      'contextBudget': {
        'estimatedInstructionTokens': 900,
        'budgetTokens': 6000,
      },
    });
    await tester.pumpWidget(
      _harness(
        toolParts: [
          _uiPart(
            tool: SkillCompositionToolNames.compose,
            arguments: {'task': 'Create a storyboard and scenes'},
            content: result,
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('Plan Skill Composition'), findsOneWidget);
    expect(find.text('story-plan'), findsOneWidget);
    expect(find.text('scene-builder'), findsOneWidget);
    expect(find.text('Required by story-plan.'), findsOneWidget);
    expect(find.textContaining('Stage 1:'), findsOneWidget);
    expect(find.textContaining('Stage 2:'), findsOneWidget);
    expect(find.textContaining('A selected Skill requests permissions.'), findsOneWidget);
  });

  testWidgets('hiding produced files leaves the tool file chip available', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        toolParts: [
          _uiPart(
            tool: 'write_file',
            meta: const WorkspaceToolMetadata(
              tool: 'write_file',
              status: 'ok',
              path: '/workspace/result.txt',
              files: [
                WorkspaceToolFile(
                  path: '/workspace/result.txt',
                  link: 'kelivo://workspace/result.txt',
                  role: WorkspaceFileRole.created,
                ),
              ],
            ),
          ),
        ],
      ),
    );
    await tester.pump();
    expect(find.byKey(ProducedFilesRow.rowKey), findsOneWidget);
    expect(find.text('result.txt'), findsNWidgets(2));
    final settings = tester
        .element(find.byType(ChatMessageWidget))
        .read<SettingsProvider>();
    await settings.setShowProducedFiles(false);
    await tester.pump();
    expect(find.byKey(ProducedFilesRow.rowKey), findsNothing);
    expect(find.text('result.txt'), findsOneWidget);
    expect(find.text('Write file'), findsOneWidget);
    await settings.setShowProducedFiles(true);
    await tester.pump();
    expect(find.byKey(ProducedFilesRow.rowKey), findsOneWidget);
  });

  testWidgets('status for running / exit 0 / exit 1', (tester) async {
    await tester.pumpWidget(
      _harness(
        toolParts: [
          const ToolUIPart(
            id: 'run-1',
            toolName: 'shell',
            arguments: {'command': 'sleep 1'},
            loading: true,
          ),
        ],
      ),
    );
    await tester.pump();
    expect(find.byType(LoadingIndicator), findsOneWidget);
    expect(find.byKey(WorkspaceStatusBadge.runningKey), findsOneWidget);
    expect(find.text('Running'), findsNothing);

    await tester.pumpWidget(
      _harness(
        toolParts: [
          _uiPart(
            tool: 'shell',
            meta: const WorkspaceToolMetadata(
              tool: 'shell',
              status: 'ok',
              command: 'ls -la',
              exitCode: 0,
              durationMs: 1200,
            ),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('ls -la'), findsOneWidget);
    expect(find.byKey(WorkspaceStatusBadge.exitZeroKey), findsOneWidget);
    expect(find.textContaining('exit 0'), findsOneWidget);
    expect(find.textContaining('1.2s'), findsOneWidget);
    final exitZero = tester.widget<Text>(
      find.byKey(WorkspaceStatusBadge.exitZeroKey),
    );
    expect(exitZero.style?.color, isNotNull);

    await tester.pumpWidget(
      _harness(
        toolParts: [
          _uiPart(
            tool: 'shell',
            meta: const WorkspaceToolMetadata(
              tool: 'shell',
              status: 'error',
              command: 'false',
              exitCode: 1,
            ),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.byKey(WorkspaceStatusBadge.exitErrorKey), findsOneWidget);
    expect(find.textContaining('exit 1'), findsOneWidget);
    final errorStatus = tester.widget<Text>(
      find.byKey(WorkspaceStatusBadge.exitErrorKey),
    );
    final errorContext = tester.element(
      find.byKey(WorkspaceStatusBadge.exitErrorKey),
    );
    expect(errorStatus.style?.color, Theme.of(errorContext).colorScheme.error);
  });

  testWidgets('status for cancelled / timeout', (tester) async {
    await tester.pumpWidget(
      _harness(
        toolParts: [
          _uiPart(
            tool: 'shell',
            meta: const WorkspaceToolMetadata(
              tool: 'shell',
              status: 'cancelled',
              command: 'sleep 99',
              cancelled: true,
            ),
          ),
        ],
      ),
    );
    await tester.pump();
    expect(find.byKey(WorkspaceStatusBadge.cancelledKey), findsOneWidget);
    expect(find.textContaining('cancelled'), findsOneWidget);

    await tester.pumpWidget(
      _harness(
        toolParts: [
          _uiPart(
            tool: 'shell',
            meta: const WorkspaceToolMetadata(
              tool: 'shell',
              status: 'timeout',
              command: 'sleep 99',
              timedOut: true,
            ),
          ),
        ],
      ),
    );
    await tester.pump();
    expect(find.byKey(WorkspaceStatusBadge.timeoutKey), findsOneWidget);
    expect(find.textContaining('timeout'), findsOneWidget);
  });

  testWidgets('shell timeout and denied badges', (tester) async {
    await tester.pumpWidget(
      _harness(
        toolParts: [
          _uiPart(
            tool: 'shell',
            meta: const WorkspaceToolMetadata(
              tool: 'shell',
              status: 'timeout',
              command: 'sleep 99',
              timedOut: true,
            ),
          ),
        ],
      ),
    );
    await tester.pump();
    expect(find.byKey(WorkspaceStatusBadge.timeoutKey), findsOneWidget);
    expect(find.textContaining('timeout'), findsOneWidget);

    await tester.pumpWidget(
      _harness(
        toolParts: [
          _uiPart(
            tool: 'shell',
            meta: const WorkspaceToolMetadata(
              tool: 'shell',
              status: 'denied',
              command: 'rm -rf /',
            ),
          ),
        ],
      ),
    );
    await tester.pump();
    expect(find.byKey(WorkspaceStatusBadge.deniedKey), findsOneWidget);
    expect(find.text('Denied'), findsOneWidget);
  });

  testWidgets('environment_not_ready shows Install and opens environment', (
    tester,
  ) async {
    var opened = 0;
    WorkspaceNavigation.onOpenEnvironmentPage = (_) => opened++;
    await tester.pumpWidget(
      _harness(
        toolParts: [
          _uiPart(
            tool: 'shell',
            meta: const WorkspaceToolMetadata(
              tool: 'shell',
              status: 'error',
              code: 'environment_not_ready',
              command: 'uname',
            ),
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Sandbox environment not installed'), findsOneWidget);
    await tester.tap(find.byKey(WorkspaceToolCardBody.installButtonKey));
    await tester.pump();
    expect(opened, 1);
  });

  testWidgets('edit_file shows path and +N −N without an inline diff', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        toolParts: [
          _uiPart(
            tool: 'edit_file',
            arguments: const {'path': 'src/app.dart'},
            meta: const WorkspaceToolMetadata(
              tool: 'edit_file',
              status: 'ok',
              path: 'src/app.dart',
              added: 4,
              removed: 2,
              strategy: 'line_trimmed',
              diff: '--- a/src/app.dart\n+++ b/src/app.dart\n+ok\n-old\n',
            ),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.textContaining('src/app.dart'), findsWidgets);
    expect(find.textContaining('+4'), findsWidgets);
    expect(find.textContaining('−2'), findsWidgets);
    expect(find.text('Expand'), findsNothing);
    expect(find.textContaining('--- a/src/app.dart'), findsNothing);
  });

  testWidgets('write_file / read_file chips; list_dir is path and count', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        toolParts: [
          _uiPart(
            tool: 'write_file',
            arguments: const {
              'path': 'notes/hello.txt',
              'content': 'a\nb\nc\n',
            },
            meta: const WorkspaceToolMetadata(
              tool: 'write_file',
              status: 'ok',
              path: 'notes/hello.txt',
              created: true,
              bytes: 12,
            ),
          ),
          _uiPart(
            id: 'tc-2',
            tool: 'read_file',
            extraMetadata: const {'mcpResult': <String, dynamic>{}},
            meta: const WorkspaceToolMetadata(
              tool: 'read_file',
              status: 'ok',
              path: 'plot.png',
            ),
          ),
          _uiPart(
            id: 'tc-3',
            tool: 'list_dir',
            arguments: const {'path': 'src'},
            content: 'empty.md\nattachments/\noutputs/\n',
            meta: const WorkspaceToolMetadata(
              tool: 'list_dir',
              status: 'ok',
              path: 'src',
              count: 8,
              truncated: true,
              files: [
                WorkspaceToolFile(
                  path: 'src/empty.md',
                  link: 'kelivo://workspace/src/empty.md',
                ),
                WorkspaceToolFile(
                  path: 'src/attachments',
                  link: 'kelivo://workspace/src/attachments',
                  isDirectory: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('hello.txt'), findsWidgets);
    expect(find.text('plot.png'), findsWidgets);
    expect(find.textContaining('src'), findsWidgets);
    expect(find.textContaining('3 lines'), findsOneWidget);
    expect(find.textContaining('8 items'), findsOneWidget);
    expect(find.text('empty.md'), findsOneWidget);
    expect(find.text('attachments'), findsOneWidget);
    expect(find.text('outputs'), findsNothing);
  });

  testWidgets('live tail updates from an injected ToolRun', (tester) async {
    final registry = ToolRunRegistry();
    final run = registry.start(
      'live-1',
      'shell',
      command: 'echo hi',
      conversationId: 'c1',
    );
    await tester.pumpWidget(
      _harness(
        registry: registry,
        toolParts: [
          const ToolUIPart(
            id: 'live-1',
            toolName: 'shell',
            arguments: {'command': 'echo hi'},
            loading: true,
          ),
        ],
      ),
    );
    await tester.pump();
    expect(find.byType(LoadingIndicator), findsOneWidget);
    expect(find.byKey(WorkspaceStatusBadge.runningKey), findsOneWidget);

    run.appendStdout(utf8.encode('alpha\nbeta\ngamma\n'));
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.textContaining('gamma'), findsOneWidget);
    expect(find.textContaining('beta'), findsOneWidget);
  });

  testWidgets('pending workspace approval uses header buttons and allow-all', (
    tester,
  ) async {
    final approval = ToolApprovalService();
    unawaited(
      approval.requestApproval(
        toolCallId: 'pending-1',
        toolName: 'shell',
        arguments: const {'command': 'ls'},
        conversationId: 'c1',
      ),
    );
    await tester.pumpWidget(
      _harness(
        approval: approval,
        toolParts: [
          const ToolUIPart(
            id: 'pending-1',
            toolName: 'shell',
            arguments: {'command': 'ls'},
            loading: true,
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.byKey(WorkspaceStatusBadge.approvalKey), findsOneWidget);
    expect(find.bySemanticsLabel('Deny'), findsOneWidget);
    expect(find.bySemanticsLabel('Allow'), findsOneWidget);
    expect(find.text('Switch to full access'), findsOneWidget);
    expect(find.text('ls'), findsWidgets);
    expect(find.byIcon(Lucide.Terminal), findsWidgets);
  });

  testWidgets('Skill execution approval displays the shared PRoot RootFS risk', (
    tester,
  ) async {
    final approval = ToolApprovalService();
    final pending = approval.requestApproval(
      toolCallId: 'skill-run-risk',
      toolName: SkillExecutionToolNames.execute,
      arguments: const {
        'execution_boundary': {
          'sharedRootFs': 'shared and writable',
          'network': 'unrestricted',
          'kernelIsolation': false,
        },
      },
      conversationId: 'c1',
      workspaceId: 'ws1',
    );
    await tester.pumpWidget(
      _harness(
        approval: approval,
        locale: const Locale('ar'),
        toolParts: [
          const ToolUIPart(
            id: 'skill-run-risk',
            toolName: SkillExecutionToolNames.execute,
            arguments: {'skill_id': 'sample-skill'},
            loading: true,
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('تحذير أمني مهم قبل تشغيل المهارة'), findsOneWidget);
    expect(find.textContaining('RootFS النشط في PRoot مشترك وقابل للكتابة'), findsOneWidget);
    expect(find.textContaining('اتصال الشبكة غير مقيّد'), findsOneWidget);
    expect(find.textContaining('ليس عزلًا أمنيًا على مستوى النواة'), findsOneWidget);
    expect(find.bySemanticsLabel('Deny'), findsOneWidget);
    expect(find.bySemanticsLabel('Allow'), findsOneWidget);
    expect(find.text('Switch to full access'), findsNothing);

    approval.deny('skill-run-risk', conversationId: 'c1');
    expect((await pending).approved, isFalse);
  });

  testWidgets('card allow-all saves grant and releases all pending shells', (
    tester,
  ) async {
    final chat = _FakeChatService();
    addTearDown(chat.dispose);
    final approval = ToolApprovalService();
    final pending = [
      for (final id in ['pending-1', 'pending-2'])
        approval.requestApproval(
          toolCallId: id,
          toolName: 'shell',
          arguments: const {'command': 'ls'},
          conversationId: 'c1',
          workspaceId: 'ws1',
        ),
    ];
    await tester.pumpWidget(
      _harness(
        chat: chat,
        approval: approval,
        toolParts: [
          const ToolUIPart(
            id: 'pending-1',
            toolName: 'shell',
            arguments: {'command': 'ls'},
            loading: true,
          ),
        ],
      ),
    );
    await tester.tap(find.byKey(WorkspaceToolCardBody.fullAccessKey));
    await tester.pump();
    expect(
      ToolPermissionMode.fromExtras(chat.conversation.extras) ==
          ToolPermissionMode.fullAccess,
      isTrue,
    );
    expect(approval.hasPending, isFalse);
    for (final result in pending) {
      expect((await result).approved, isTrue);
    }
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('long pressing deny offers an optional denial reason', (
    tester,
  ) async {
    final approval = ToolApprovalService();
    final pending = approval.requestApproval(
      toolCallId: 'pending-deny',
      toolName: 'shell',
      arguments: const {'command': 'ls'},
      conversationId: 'c1',
    );
    await tester.pumpWidget(
      _harness(
        approval: approval,
        toolParts: [
          const ToolUIPart(
            id: 'pending-deny',
            toolName: 'shell',
            arguments: {'command': 'ls'},
            loading: true,
          ),
        ],
      ),
    );
    await tester.pump();

    await tester.longPress(find.bySemanticsLabel('Deny'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(IosFormTextField), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(approval.isPending('pending-deny', conversationId: 'c1'), isTrue);
    await tester.enterText(
      find.byType(EditableText),
      'Use the project directory',
    );
    await tester.tap(find.text('Deny').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final result = await pending;
    expect(result.approved, isFalse);
    expect(result.denyReason, 'Use the project directory');
  });

  testWidgets('assistant shell tool sits in the timeline card', (tester) async {
    await tester.pumpWidget(
      _harness(
        toolParts: [
          _uiPart(
            tool: 'shell',
            arguments: const {'command': 'uname'},
            content: 'Darwin',
            meta: const WorkspaceToolMetadata(
              tool: 'shell',
              status: 'ok',
              command: 'uname',
              exitCode: 0,
              durationMs: 8,
            ),
          ),
        ],
      ),
    );
    await tester.pump();
    expect(_timelineIconColumn, findsOneWidget);
    expect(find.byType(WorkspaceToolCardBody), findsOneWidget);
    expect(find.text('Tool Call: shell'), findsNothing);
    expect(find.text('uname'), findsWidgets);
  });

  testWidgets('shell tool uses the timeline while running and when completed', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        toolParts: [
          const ToolUIPart(
            id: 'tc-run',
            toolName: 'shell',
            arguments: {'command': 'ls -la'},
            loading: true,
          ),
        ],
      ),
    );
    await tester.pump();
    expect(_timelineIconColumn, findsOneWidget);
    expect(find.text('Tool Call: shell'), findsNothing);
    expect(find.text('ls -la'), findsWidgets);

    await tester.pumpWidget(
      _harness(
        toolParts: [
          _uiPart(
            tool: 'shell',
            arguments: const {'command': 'uname'},
            content: 'Darwin',
            meta: const WorkspaceToolMetadata(
              tool: 'shell',
              status: 'ok',
              command: 'uname',
              exitCode: 0,
            ),
          ),
        ],
      ),
    );
    await tester.pump();
    expect(_timelineIconColumn, findsOneWidget);
    expect(find.text('Tool Call: shell'), findsNothing);
    expect(find.text('uname'), findsWidgets);
  });

  testWidgets('tapping a timeline shell step opens tool detail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _harness(
        toolParts: [
          _uiPart(
            tool: 'shell',
            arguments: const {'command': 'uname'},
            meta: const WorkspaceToolMetadata(
              tool: 'shell',
              status: 'ok',
              command: 'uname',
              exitCode: 0,
            ),
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Run command'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(CustomBottomSheet.panelKey), findsOneWidget);
  });

  testWidgets('detail opens as a bottom sheet on mobile size', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(createBusinessTestPreferences()),
          ),
          ChangeNotifierProvider(create: (_) => ToolRunRegistry()),
          ChangeNotifierProvider(create: (_) => ToolApprovalService()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showWorkspaceToolDetail(
                  context,
                  WorkspaceToolPart(
                    id: 'd1',
                    toolName: 'read_file',
                    metadata: const WorkspaceToolMetadata(
                      tool: 'read_file',
                      status: 'ok',
                      path: 'README.md',
                    ).toJson(),
                  ),
                ),
                child: const Text('open-detail'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open-detail'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(CustomBottomSheet.panelKey), findsOneWidget);
    expect(find.byKey(kWorkspaceToolDetailDesktopKey), findsNothing);
    expect(find.text('Path'), findsWidgets);
    expect(find.text('Command'), findsNothing);
  });

testWidgets('video engine tool renders its workspace card', (tester) async {
  await tester.pumpWidget(
    _harness(
      toolParts: [
        _uiPart(
          tool: VideoEngineToolNames.manage,
          arguments: {'action': 'list'},
          content: jsonEncode({
            'ok': true,
            'defaultEngineId': 'motion-kit',
            'engines': [
              {
                'id': 'motion-kit',
                'name': 'Motion Kit',
                'status': 'installed',
                'preflightPassed': true,
                'renderVerified': false,
              },
            ],
          }),
        ),
      ],
    ),
  );
  await tester.pump();
  expect(find.text('Manage Video Engines'), findsOneWidget);
  expect(find.byIcon(Lucide.FileVideo), findsWidgets);
});

testWidgets('video production tool renders its workspace card', (tester) async {
  await tester.pumpWidget(
    _harness(
      toolParts: [
        _uiPart(
          tool: VideoProductionToolNames.manage,
          arguments: {'action': 'status', 'project_name': 'sample-film'},
          content: jsonEncode({
            'ok': true,
            'action': 'status',
            'status': 'source_ready',
            'sceneCount': 3,
            'sourceFiles': ['src/main.js'],
          }),
        ),
      ],
    ),
  );
  await tester.pump();
  expect(find.text('Manage Video Production'), findsOneWidget);
  expect(find.byIcon(Lucide.FileVideo), findsWidgets);
});

testWidgets('package manager output shows manager and isolated scope', (tester) async {
  await tester.pumpWidget(
    _harness(
      toolParts: [
        _uiPart(
          tool: PackageManagerToolNames.manage,
          arguments: {'action': 'plan', 'package': 'requests'},
          content: jsonEncode({
            'ok': true,
            'action': 'plan',
            'manager': 'uv',
            'scope': 'project:demo',
            'packages': [
              {'name': 'requests', 'version': '2.32.3'},
            ],
            'compatibilityWarnings': [],
          }),
        ),
      ],
    ),
  );
  await tester.pump();
  expect(find.text('Manage Packages'), findsOneWidget);
  expect(find.text('uv · project:demo'), findsOneWidget);
  expect(find.text('requests'), findsOneWidget);
});

}
