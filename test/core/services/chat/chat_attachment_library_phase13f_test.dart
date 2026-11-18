import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/composer_draft_store.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/chat_input_data.dart';
import 'package:Kelivo/core/models/composer_draft.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';

class _Phase13FPathProvider extends PathProviderPlatform {
  _Phase13FPathProvider(this.root);
  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late Directory upload;
  late AppDatabase database;
  late ComposerDraftStore drafts;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('kelivo-attachment-library-');
    upload = Directory('${root.path}/upload')..createSync(recursive: true);
    PathProviderPlatform.instance = _Phase13FPathProvider(root.path);
    SandboxPathResolver.debugSetDirs(
      docsDir: root.path,
      supportDir: root.path,
    );
    database = AppDatabase(NativeDatabase.memory());
    drafts = ComposerDraftStore(
      database,
      directory: () async => Directory('${root.path}/composer-drafts'),
    );
    await drafts.initialize();
  });

  tearDown(() async {
    drafts.dispose();
    await database.close();
    SandboxPathResolver.debugSetDirs(docsDir: null, supportDir: null);
    await root.delete(recursive: true);
  });

  test('recovers original names for legacy published-file rows', () async {
    final legacyFile = await File('${upload.path}/draft-legacy-0.zip')
        .writeAsBytes([9, 8, 7]);
    final storedUri = SandboxPathResolver.canonicalize(legacyFile.path);
    final now = DateTime.utc(2026, 11, 14);
    await database
        .into(database.conversationRows)
        .insert(
          ConversationRowsCompanion.insert(
            id: 'legacy-conversation',
            title: 'Legacy',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await database
        .into(database.messageRows)
        .insert(
          MessageRowsCompanion.insert(
            id: 'legacy-message',
            conversationId: 'legacy-conversation',
            role: 'user',
            timestamp: now,
            messageOrder: 0,
          ),
        );
    await database
        .into(database.messagePartRows)
        .insert(
          MessagePartRowsCompanion.insert(
            conversationId: 'legacy-conversation',
            revisionId: 'legacy-message',
            ordinal: 0,
            kind: 'file',
            payload: jsonEncode({
              'uri': storedUri,
              'name': 'original-upload.zip',
              'mime': 'application/zip',
            }),
            createdAt: now,
            updatedAt: now,
          ),
        );
    // Older versions wrote an empty registry payload and retained the
    // generated storage basename. The library should recover the display
    // metadata from the historical FilePart row.
    await ExtensionEntityStore(database).upsert(
      ComposerDraftStore.publishedFileKind,
      storedUri,
      const <String, dynamic>{},
    );

    final library = await drafts.publishedAttachments();
    expect(library, hasLength(1));
    expect(library.single.fileName, 'original-upload.zip');
    expect(library.single.mime, 'application/zip');
  });

  test('reuses one published upload path across conversations without draft copies', () async {
    final published = await File('${upload.path}/original.zip')
        .writeAsBytes([1, 2, 3, 4, 5]);
    final publishedId = SandboxPathResolver.canonicalize(published.path);
    await ExtensionEntityStore(database).upsert(
      ComposerDraftStore.publishedFileKind,
      publishedId,
      {
        'fileName': 'original.zip',
        'mime': 'application/zip',
        'sizeBytes': 5,
      },
    );

    final library = await drafts.publishedAttachments();
    expect(library, hasLength(1));
    expect(library.single.path, published.path);
    expect(library.single.fileName, 'original.zip');
    expect(library.single.isPublished, isTrue);

    for (final conversationId in ['conversation-a', 'conversation-b']) {
      await drafts.load(conversationId);
      final input = ComposerDraftInput(
        text: 'Reuse the original file',
        documents: [
          DocumentAttachment(
            path: published.path,
            fileName: 'original.zip',
            mime: 'application/zip',
          ),
        ],
      );
      final submission = await drafts.beginSubmission(conversationId, input);
      final prepared = await drafts.prepareSubmissionInput(
        input.toInput(submission: submission),
      );
      expect(prepared.documents.single.path, published.path);
    }

    expect(await published.readAsBytes(), [1, 2, 3, 4, 5]);
    expect(
      (await upload.list(followLinks: false).toList()),
      hasLength(1),
      reason: 'Reusing a published attachment must not create draft-* duplicate files.',
    );
    expect(await drafts.publishedAttachments(), hasLength(1));
  });
}
