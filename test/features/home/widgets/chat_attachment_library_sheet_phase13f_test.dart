import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/chat_attachment_library_item.dart';
import 'package:Kelivo/features/home/widgets/chat_attachment_library_sheet.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

void main() {
  Future<void> pumpHost(
    WidgetTester tester, {
    required List<ChatAttachmentLibraryItem> items,
    required Future<List<ChatAttachmentLibraryItem>> Function() onUpload,
    required void Function(Future<List<ChatAttachmentLibraryItem>?> result) onOpened,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => onOpened(
                  ChatAttachmentLibrarySheet.show(
                    context: context,
                    items: items,
                    onUploadFromPhone: onUpload,
                  ),
                ),
                child: const Text('Open attachment library'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open attachment library'));
    await tester.pumpAndSettle();
  }

  testWidgets('multiple previously uploaded files are only returned after Add', (tester) async {
    final items = [
      const ChatAttachmentLibraryItem(
        path: '/upload/first.zip', fileName: 'first.zip',
        mime: 'application/zip', sizeBytes: 120, isPublished: true,
      ),
      const ChatAttachmentLibraryItem(
        path: '/upload/second.pdf', fileName: 'second.pdf',
        mime: 'application/pdf', sizeBytes: 240, isPublished: true,
      ),
    ];
    Future<List<ChatAttachmentLibraryItem>?>? result;
    await pumpHost(
      tester,
      items: items,
      onUpload: () async => const [],
      onOpened: (value) => result = value,
    );

    expect(find.text('Previously uploaded files'), findsOneWidget);
    expect(find.text('Add to message'), findsNothing);
    await tester.tap(find.text('first.zip'));
    await tester.pumpAndSettle();
    expect(find.text('Add to message'), findsOneWidget);
    expect(result, isNotNull);

    await tester.tap(find.text('second.pdf'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to message'));
    await tester.pumpAndSettle();
    final selected = (await result!)!;
    expect(selected.map((item) => item.path).toSet(), {
      '/upload/first.zip',
      '/upload/second.pdf',
    });
  });

  testWidgets('device-picked files are staged and preselected until Add is pressed', (tester) async {
    const staged = ChatAttachmentLibraryItem(
      path: '/device/new-video.mp4',
      fileName: 'new-video.mp4',
      mime: 'video/mp4',
      sizeBytes: 1024,
      isPublished: false,
    );
    Future<List<ChatAttachmentLibraryItem>?>? result;
    var devicePickerCalls = 0;
    await pumpHost(
      tester,
      items: const [],
      onUpload: () async {
        devicePickerCalls++;
        return const [staged];
      },
      onOpened: (value) => result = value,
    );

    expect(find.text('Upload from Files'), findsOneWidget);
    await tester.tap(find.text('Upload from Files'));
    await tester.pumpAndSettle();
    expect(devicePickerCalls, 1);
    expect(find.text('new-video.mp4'), findsOneWidget);
    expect(find.text('Add to message'), findsOneWidget);
    expect(result, isNotNull);

    await tester.tap(find.text('Add to message'));
    await tester.pumpAndSettle();
    final selected = (await result!)!;
    expect(selected, hasLength(1));
    expect(selected.single.path, staged.path);
    expect(selected.single.isPublished, isFalse);
  });
}
