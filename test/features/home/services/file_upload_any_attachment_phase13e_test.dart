import 'dart:io';

import 'package:Kelivo/features/home/services/file_upload_service.dart';
import 'package:Kelivo/features/home/widgets/chat_input_bar.dart';
import 'package:Kelivo/shared/utils/file_picker_compat.dart';
import 'package:flutter_test/flutter_test.dart';

class _AnyFilePicker extends FilePicker {
  FileType? type;
  List<String>? extensions;
  bool? buffered;
  bool? multiple;
  FilePickerResult? result;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    this.type = type;
    extensions = allowedExtensions;
    buffered = withData;
    multiple = allowMultiple;
    return result;
  }
}

void main() {
  test('device picker accepts any extension without loading all bytes into RAM', () async {
    final root = await Directory.systemTemp.createTemp('kelivo-file-picker-');
    final picked = await File('${root.path}/source.bundle').writeAsBytes([1, 2, 3]);
    try {
      final picker = _AnyFilePicker()
        ..result = FilePickerResult([
          PlatformFile(name: 'source.bundle', size: 3, path: picked.path),
        ]);
      FilePicker.platform = picker;
      final service = FileUploadService(
        getContext: () => throw StateError('No UI is used by the device picker.'),
        mediaController: ChatInputBarController(),
        isImageCropperEnabled: () => false,
        getImageCompressConfig: () => throw StateError('No image processing is used.'),
      );

      final staged = await service.pickFilesFromDevice();
      expect(picker.type, FileType.any);
      expect(picker.extensions, isNull);
      expect(picker.buffered, isFalse);
      expect(picker.multiple, isTrue);
      expect(staged, hasLength(1));
      expect(staged.single.fileName, 'source.bundle');
      expect(staged.single.isPublished, isFalse);
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('archive and common binary types receive useful MIME labels', () {
    final service = FileUploadService(
      getContext: () => throw StateError('No UI is used'),
      mediaController: ChatInputBarController(),
      isImageCropperEnabled: () => false,
      getImageCompressConfig: () => throw StateError('No images'),
    );
    expect(service.inferMimeByExtension('skills.zip'), 'application/zip');
    expect(service.inferMimeByExtension('assets.7z'), 'application/x-7z-compressed');
    expect(service.inferMimeByExtension('app.apk'), 'application/vnd.android.package-archive');
    expect(service.inferMimeByExtension('report.xlsx'),
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  });
}
