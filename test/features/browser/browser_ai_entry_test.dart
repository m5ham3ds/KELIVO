import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/services/browser/browser_service.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/notification_service.dart';
import 'package:Kelivo/features/browser/browser_ai_entry.dart';
import 'package:Kelivo/features/browser/models/browser_models.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

class _EntryBrowser extends ChangeNotifier implements BrowserService {
  BrowserSettings configuration = const BrowserSettings(agentEnabled: false);
  @override
  BrowserSettings get settings => configuration;
  @override
  Future<void> initialize() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EntryChat extends ChangeNotifier implements ChatService {
  _EntryChat(this.conversation);
  final Conversation conversation;
  @override
  Conversation? getConversation(String id) =>
      id == conversation.id ? conversation : null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('standalone browser reports unavailable without app providers', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox();
          },
        ),
      ),
    );
    final browser = _EntryBrowser();
    expect(
      await requestBrowserAiDraft(
        context,
        browser: browser,
        conversationId: 'missing',
      ),
      BrowserAiEntryResult.unavailable,
    );
    expect(tester.takeException(), isNull);
    browser.dispose();
  });

  testWidgets(
    'browser AI entry follows the global browser permission, not assistant toggles',
    (tester) async {
      final chat = _EntryChat(
        Conversation(
          id: 'browser-chat',
          title: 'Browser chat',
        ),
      );
      final browser = _EntryBrowser();
      late BuildContext context;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            InheritedProvider<ChatService>.value(value: chat),
          ],
          child: Localizations(
            locale: const Locale('en'),
            delegates: AppLocalizations.localizationsDelegates,
            child: Builder(
              builder: (value) {
                context = value;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      NotificationService.takePendingConversationId();
      expect(
        await requestBrowserAiDraft(
          context,
          browser: browser,
          conversationId: 'browser-chat',
        ),
        BrowserAiEntryResult.browserPermissionDisabled,
      );
      expect(NotificationService.takePendingConversationId(), isNull);
      expect(browser.settings.agentEnabled, isFalse);
      expect(
        await requestBrowserAiDraft(
          context,
          browser: browser,
          conversationId: 'browser-chat',
        ),
        BrowserAiEntryResult.browserPermissionDisabled,
      );
      expect(NotificationService.takePendingConversationId(), isNull);
      browser.configuration = const BrowserSettings(agentEnabled: true);
      expect(
        await requestBrowserAiDraft(
          context,
          browser: browser,
          conversationId: 'browser-chat',
          tab: const BrowserTab(
            id: 'tab-a',
            url: 'https://user:secret@example.com/page',
          ),
        ),
        BrowserAiEntryResult.requested,
      );
      expect(NotificationService.takePendingConversationId(), 'browser-chat');
      final draft = NotificationService.takePendingComposerText(
        'browser-chat',
      )!;
      expect(draft, contains('https://example.com/page'));
      expect(draft, isNot(contains('secret')));
      expect(draft, contains('My request:'));
      browser.dispose();
      chat.dispose();
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );
}
