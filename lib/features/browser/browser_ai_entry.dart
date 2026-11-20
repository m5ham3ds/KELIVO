import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../core/services/browser/browser_service.dart';
import '../../core/services/chat/chat_service.dart';
import '../../core/services/notification_service.dart';
import '../../l10n/app_localizations.dart';
import 'models/browser_models.dart';

enum BrowserAiEntryResult {
  requested,
  unavailable,
  browserPermissionDisabled,
}

/// Reuses the application's existing conversation navigation and composer.
/// The caller closes the browser route after [BrowserAiEntryResult.requested].
/// The user must edit/send the draft before any model request starts.
Future<BrowserAiEntryResult> requestBrowserAiDraft(
  BuildContext context, {
  required BrowserService browser,
  required String? conversationId,
  BrowserTab? tab,
}) async {
  if (conversationId == null || conversationId.isEmpty) {
    return BrowserAiEntryResult.unavailable;
  }
  final ChatService? chat;
  try {
    chat = context.read<ChatService?>();
  } on ProviderNotFoundException {
    return BrowserAiEntryResult.unavailable;
  }
  final conversation = chat?.getConversation(conversationId);
  if (conversation == null) {
    return BrowserAiEntryResult.unavailable;
  }
  try {
    await browser.initialize();
  } catch (_) {
    return BrowserAiEntryResult.unavailable;
  }
  if (!context.mounted) return BrowserAiEntryResult.unavailable;
  if (!browser.settings.agentEnabled) {
    return BrowserAiEntryResult.browserPermissionDisabled;
  }
  final l = AppLocalizations.of(context);
  if (l == null) return BrowserAiEntryResult.unavailable;
  final uri = Uri.tryParse(tab?.url ?? '');
  final page =
      uri != null &&
          (uri.isScheme('http') || uri.isScheme('https')) &&
          uri.host.isNotEmpty
      ? uri.replace(userInfo: '').toString()
      : l.browserAskAiCurrentPage;
  NotificationService.openConversation(
    conversationId,
    composerText: l.browserAskAiDraft(page),
  );
  return BrowserAiEntryResult.requested;
}
