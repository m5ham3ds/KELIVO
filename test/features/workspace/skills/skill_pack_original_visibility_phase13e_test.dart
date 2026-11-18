import 'dart:io';

import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/skill_pack.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/skills/skills_service.dart';
import 'package:Kelivo/features/workspace/pages/skills_page.dart';
import 'package:Kelivo/features/workspace/widgets/skills/conversation_skills_sheet.dart';
import 'package:Kelivo/features/workspace/widgets/skills/skill_detail.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../support/business_test_harness.dart';
import 'skills_test_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kelivo_pack_visibility_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  SkillPack packFor(String skillId) => SkillPack(
    id: 'pack-visual-tools',
    name: 'Visual Toolkit',
    shortcut: 'visual_tools',
    skillIds: [skillId],
    enabled: false,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  Future<AssistantProvider> loadAssistant(
    WidgetTester tester,
  ) async {
    final harness = await createBusinessTestHarness(
      initial: {
        'assistants_v1': Assistant.encodeList([
          const Assistant(id: 'assistant-1', name: 'Assistant'),
        ]),
      },
    );
    final provider = AssistantProvider(preferences: harness.preferences);
    await tester.runAsync(() => provider.loaded);
    return provider;
  }

  testWidgets('Skills page shows pack members as original standalone rows', (
    tester,
  ) async {
    final skill = createTempSkill(
      id: 'character-visual-director',
      name: 'Character Visual Director',
      description: 'Build character visual systems',
      enabled: false,
      parent: tempDir,
    );
    final skills = FakeSkillsService(
      skills: [skill],
      skillPacks: [packFor(skill.record.id)],
      skillsDirectory: tempDir,
    );
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(createBusinessTestPreferences()),
          ),
          ChangeNotifierProvider<SkillsService>.value(value: skills),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SkillsPane(showHeader: true)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byKey(SkillsPane.itemKey(skill.record.id)), findsOneWidget);
    expect(find.byKey(SkillsPane.enableKey(skill.record.id)), findsOneWidget);
    expect(find.text('Visual Toolkit'), findsOneWidget);

    await tester.tap(find.byKey(SkillsPane.itemKey(skill.record.id)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(IosSwitch),
      ),
      findsOneWidget,
      reason: 'a pack member must retain its own detail-page enabled switch',
    );
    expect(find.byType(SkillDetailView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('conversation selector lists a pack member independently', (
    tester,
  ) async {
    final skill = createTempSkill(
      id: 'conversation-member',
      name: 'Conversation Member',
      description: 'Can be selected alone',
      enabled: false,
      parent: tempDir,
    );
    final skills = FakeSkillsService(
      skills: [skill],
      skillPacks: [packFor(skill.record.id)],
      skillsDirectory: tempDir,
    );
    final chat = FakeChatService(
      conversation: Conversation(id: 'chat-1', title: 'Chat'),
    );
    final assistants = await loadAssistant(tester);
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(createBusinessTestPreferences()),
          ),
          ChangeNotifierProvider<AssistantProvider>.value(value: assistants),
          ChangeNotifierProvider<SkillsService>.value(value: skills),
          ChangeNotifierProvider<ChatService>.value(value: chat),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: ConversationSkillsPanel(
              conversationId: 'chat-1',
              assistant: Assistant(id: 'assistant-1', name: 'Assistant'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(ConversationSkillsPanel.skillKey(skill.record.id)),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>(
        'skills-conversation-pack-pack-visual-tools',
      )),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(ConversationSkillsPanel.skillKey(skill.record.id)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(skills.enabledCalls, [(skill.record.id, true)]);
    expect(skills.skills.single.record.enabled, isTrue);
    expect(tester.takeException(), isNull);
  });
}
