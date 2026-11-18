import 'dart:convert';

import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> expectStillPending(Future<dynamic> future) async {
  var completed = false;
  future.whenComplete(() {
    completed = true;
  });
  await Future<void>.delayed(Duration.zero);
  expect(completed, isFalse);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const notificationChannel = MethodChannel('test.tool_approval_notifications');
  test('Android approval notifications expose only safe identifiers and resume the pending decision', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationChannel, (call) async {
          calls.add(call);
          return call.method == 'show' ? true : null;
        });
    final service = ToolApprovalService(
      enableSystemNotifications: true,
      isAndroid: true,
      notificationChannel: notificationChannel,
    );
    addTearDown(() {
      service.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(notificationChannel, null);
    });

    final pending = service.requestApproval(
      toolCallId: 'approval-42',
      toolName: 'skill_install',
      arguments: const {'path': '/private/path.zip', 'api_key': 'private-secret'},
      conversationId: 'conversation-42',
    );
    await Future<void>.delayed(Duration.zero);
    expect(calls, hasLength(1));
    expect(calls.single.method, 'show');
    final args = calls.single.arguments as Map;
    expect(args.keys.toSet(), {'toolCallId', 'conversationId', 'toolName'});
    expect(args['toolName'], 'skill_install');
    expect(jsonEncode(args), isNot(contains('private-secret')));
    expect(jsonEncode(args), isNot(contains('/private/path.zip')));

    // Android sends this method-channel action after the user taps a
    // notification button. It must complete the original in-memory approval.
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          notificationChannel.name,
          notificationChannel.codec.encodeMethodCall(
            const MethodCall('approvalAction', {
              'toolCallId': 'approval-42',
              'conversationId': 'conversation-42',
              'approved': true,
            }),
          ),
          (_) {},
        );
    expect((await pending).approved, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(calls.map((call) => call.method), ['show', 'dismiss']);
  });

  test('notification deny action rejects only its matching pending request', () async {
    const channel = MethodChannel('test.tool_approval_notifications.deny');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
    final service = ToolApprovalService(
      enableSystemNotifications: true,
      isAndroid: true,
      notificationChannel: channel,
    );
    addTearDown(() {
      service.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    final pending = service.requestApproval(
      toolCallId: 'deny-42',
      toolName: 'skill_install',
      arguments: const {'source': 'private'},
      conversationId: 'conversation-deny',
    );
    await Future<void>.delayed(Duration.zero);
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(
            const MethodCall('approvalAction', {
              'toolCallId': 'deny-42',
              'conversationId': 'conversation-deny',
              'approved': false,
            }),
          ),
          (_) {},
        );
    final result = await pending;
    expect(result.approved, isFalse);
    expect(result.denyReason, 'notification_denied');
    expect(service.pendingRequests, isEmpty);
  });

  test(
    'full access releases matching conversation tools and rejects stale workspaces',
    () async {
      final service = ToolApprovalService();
      addTearDown(service.dispose);
      final requests = [
        for (final (chat, workspace, tool, id)
            in <(String?, String?, String, String)>[
              ('a', 'ws1', 'shell', 'first'),
              ('a', 'ws1', 'shell', 'second'),
              ('b', 'ws1', 'shell', 'first'),
              ('a', 'ws2', 'shell', 'other-workspace'),
              ('a', 'ws1', 'write_file', 'outside-write'),
              ('a', null, 'mcp_tool', 'mcp'),
              (null, 'ws1', 'shell', 'unscoped'),
            ])
          service.requestApproval(
            toolCallId: id,
            toolName: tool,
            arguments: const {},
            conversationId: chat,
            workspaceId: workspace,
          ),
      ];

      service.approveConversationTools(conversationId: 'a', workspaceId: 'ws1');
      expect((await requests[0]).approved, isTrue);
      expect((await requests[1]).approved, isTrue);
      expect((await requests[3]).denyReason, 'context_changed');
      expect((await requests[4]).byFullAccess, isTrue);
      expect((await requests[5]).byFullAccess, isTrue);
      expect(service.pendingRequests, hasLength(2));
      await expectStillPending(requests[2]);
      await expectStillPending(requests[6]);
      service.cancelAll();
      expect((await requests[2]).approved, isFalse);
      expect((await requests[6]).approved, isFalse);
    },
  );

  test(
    'two conversations sharing a placeholder id keep both Completers',
    () async {
      final service = ToolApprovalService();
      final futureA = service.requestApproval(
        toolCallId: 'round-0:tool-1',
        toolName: 'lookup',
        arguments: const {'q': 'a'},
        conversationId: 'conversation-a',
      );
      final futureB = service.requestApproval(
        toolCallId: 'round-0:tool-1',
        toolName: 'lookup',
        arguments: const {'q': 'b'},
        conversationId: 'conversation-b',
      );

      expect(service.pendingRequests, hasLength(2));
      expect(
        service.pendingFor(
          toolCallId: 'round-0:tool-1',
          conversationId: 'conversation-a',
        ),
        isNotNull,
      );
      expect(
        service.pendingFor(
          toolCallId: 'round-0:tool-1',
          conversationId: 'conversation-b',
        ),
        isNotNull,
      );

      service.approve('round-0:tool-1', conversationId: 'conversation-a');
      final resultA = await futureA;
      expect(resultA.approved, isTrue);
      await expectStillPending(futureB);
      expect(
        service.isPending('round-0:tool-1', conversationId: 'conversation-b'),
        isTrue,
      );
      expect(
        service.isPending('round-0:tool-1', conversationId: 'conversation-a'),
        isFalse,
      );

      service.approve('round-0:tool-1', conversationId: 'conversation-b');
      final resultB = await futureB;
      expect(resultB.approved, isTrue);
      expect(service.hasPending, isFalse);
    },
  );

  test(
    'requestApproval does not overwrite an existing Completer for the same key',
    () async {
      final service = ToolApprovalService();
      final first = service.requestApproval(
        toolCallId: 'round-0:tool-1',
        toolName: 'lookup',
        arguments: const {'q': 'first'},
        conversationId: 'conversation-a',
      );
      final second = service.requestApproval(
        toolCallId: 'round-0:tool-1',
        toolName: 'lookup',
        arguments: const {'q': 'second'},
        conversationId: 'conversation-a',
      );

      expect(service.pendingRequests, hasLength(1));
      service.approve('round-0:tool-1', conversationId: 'conversation-a');
      expect((await first).approved, isTrue);
      expect((await second).approved, isTrue);
    },
  );

  test('unscoped requests with the same toolCallId do not overwrite', () async {
    final service = ToolApprovalService();
    final first = service.requestApproval(
      toolCallId: 'round-0:tool-1',
      toolName: 'lookup',
      arguments: const {'q': 'first'},
    );
    final second = service.requestApproval(
      toolCallId: 'round-0:tool-1',
      toolName: 'lookup',
      arguments: const {'q': 'second'},
    );

    expect(service.pendingRequests, hasLength(2));
    await expectStillPending(first);
    await expectStillPending(second);

    service.cancelAll();
    expect((await first).approved, isFalse);
    expect((await second).approved, isFalse);
  });

  test('cancelForConversation leaves the other chat waiting', () async {
    final service = ToolApprovalService();
    final futureA = service.requestApproval(
      toolCallId: 'round-0:tool-1',
      toolName: 'lookup',
      arguments: const {},
      conversationId: 'conversation-a',
    );
    final futureB = service.requestApproval(
      toolCallId: 'round-0:tool-1',
      toolName: 'lookup',
      arguments: const {},
      conversationId: 'conversation-b',
    );

    service.cancelForConversation('conversation-a');
    expect((await futureA).approved, isFalse);
    await expectStillPending(futureB);
    expect(
      service.pendingFor(
        toolCallId: 'round-0:tool-1',
        conversationId: 'conversation-b',
      ),
      isNotNull,
    );
  });
}
