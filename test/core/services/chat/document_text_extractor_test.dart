import 'dart:io';
import 'package:Kelivo/core/services/chat/document_text_extractor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  setUp(
    () => directory = Directory.systemTemp.createTempSync('kelivo_extract_'),
  );
  tearDown(() => directory.deleteSync(recursive: true));

  test(
    'binary files stay attachments instead of being decoded as prompt text',
    () async {
      final file = File('${directory.path}/app.apk')
        ..writeAsBytesSync([0x50, 0x4b, 3, 4, 0, 1]);
      await expectLater(
        DocumentTextExtractor.extractResolved(
          path: file.path,
          mime: 'application/vnd.android.package-archive',
        ),
        throwsA(isA<AttachmentRequiresWorkspace>()),
      );
    },
  );

  test('ZIP archives are never sent through inline text extraction', () async {
    // A ZIP signature followed by printable bytes is enough to expose the old
    // bug: the header does not necessarily contain a NUL byte.
    final zip = File('${directory.path}/animation-director.zip')
      ..writeAsBytesSync([
        0x50,
        0x4b,
        0x03,
        0x04,
        0x41,
        0x42,
        0x43,
        0x44,
        0x45,
        0x46,
        0x47,
        0x48,
      ]);
    await expectLater(
      DocumentTextExtractor.extractResolved(
        path: zip.path,
        mime: 'application/octet-stream',
      ),
      throwsA(isA<AttachmentRequiresWorkspace>()),
    );

    // Content sniffing also protects archives whose extension is missing or
    // has been changed by a file provider.
    final renamed = File('${directory.path}/download.bin')
      ..writeAsBytesSync([
        0x50,
        0x4b,
        0x03,
        0x04,
        0x41,
        0x42,
        0x43,
        0x44,
      ]);
    await expectLater(
      DocumentTextExtractor.extractResolved(
        path: renamed.path,
        mime: 'application/octet-stream',
      ),
      throwsA(isA<AttachmentRequiresWorkspace>()),
    );
  });

  test('large files are not read into memory for prompt extraction', () async {
    final file = File('${directory.path}/large.pdf');
    final handle = file.openSync(mode: FileMode.write)
      ..truncateSync(256 * 1024 * 1024);
    handle.closeSync();
    await expectLater(
      DocumentTextExtractor.extractResolved(
        path: file.path,
        mime: 'application/pdf',
      ),
      throwsA(isA<AttachmentRequiresWorkspace>()),
    );
    expect(file.lengthSync(), 256 * 1024 * 1024);
  });

  test(
    'CJK text survives an incomplete UTF8 sequence at the probe boundary',
    () async {
      final expected = '文件内容' * 2000;
      final file = File('${directory.path}/notes.txt')
        ..writeAsStringSync(expected);
      expect(
        await DocumentTextExtractor.extractResolved(
          path: file.path,
          mime: 'text/plain',
        ),
        expected,
      );
    },
  );
}
