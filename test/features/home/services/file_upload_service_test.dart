import 'package:Kelivo/core/models/chat_input_data.dart';
import 'package:Kelivo/core/utils/multimodal_input_utils.dart';
import 'package:Kelivo/features/home/services/file_upload_service.dart';
import 'package:Kelivo/features/home/widgets/chat_input_bar.dart';
import 'package:Kelivo/shared/utils/file_picker_compat.dart';
import 'package:flutter_test/flutter_test.dart';

class _Picker extends FilePicker {
  FileType? type;
  List<String>? extensions;
  bool? buffered;

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
    return null;
  }
}

void main() {
  test(
    'chat picker accepts every file type with or without a bound workspace',
    () async {
      final picker = _Picker();
      FilePicker.platform = picker;
      var bound = false;
      final service = FileUploadService(
        getContext: () => throw StateError('Cancelled picker needs no UI'),
        mediaController: ChatInputBarController(),
        isImageCropperEnabled: () => false,
        getImageCompressConfig: () => throw StateError('No images selected'),
        hasWorkspace: () => bound,
      );
      await service.pickFilesFromDevice();
      expect(picker.type, FileType.any);
      expect(picker.extensions, isNull);
      expect(picker.buffered, isFalse);
      bound = true;
      await service.pickFilesFromDevice();
      expect(picker.type, FileType.any);
      expect(picker.extensions, isNull);
      expect(picker.buffered, isFalse);
      expect(
        service.inferMimeByExtension('Dockerfile'),
        'application/octet-stream',
      );
      expect(service.inferMimeByExtension('Voice.M4A'), 'audio/mp4');
      expect(service.inferMimeByExtension('recording.flac'), 'audio/flac');
      expect(service.inferMimeByExtension('archive.zip'), 'application/zip');
      expect(
        service.inferMimeByExtension('app.apk'),
        'application/vnd.android.package-archive',
      );
      expect(service.inferMimeByExtension('opaque.bin'), 'application/octet-stream');
      expect(
        resolveDocumentAttachmentMime(
          const DocumentAttachment(
            path: '/upload/opaque',
            fileName: 'Voice.M4A',
            mime: 'application/octet-stream',
          ),
        ),
        'audio/mp4',
      );
      expect(
        resolveDocumentAttachmentMime(
          const DocumentAttachment(
            path: '/upload/opaque',
            fileName: 'animation-director.zip',
            mime: 'application/octet-stream',
          ),
        ),
        'application/zip',
      );
      expect(
        inferMediaMimeFromSource(
          'https://example.com/voice.m4a?token=redacted',
        ),
        'audio/mp4',
      );
    },
  );

  test(
    'binary archives are not misclassified as inline-readable text files',
    () {
      DocumentAttachment file(String name, String mime) =>
          DocumentAttachment(path: '/upload/$name', fileName: name, mime: mime);
      expect(
        FileUploadService.supportsWithoutWorkspace(
          file('app.apk', 'application/octet-stream'),
        ),
        isFalse,
      );
      expect(
        FileUploadService.supportsWithoutWorkspace(
          file('bundle.zip', 'application/zip'),
        ),
        isFalse,
      );
      expect(
        FileUploadService.supportsWithoutWorkspace(
          file('notes.pdf', 'application/pdf'),
        ),
        isTrue,
      );
      expect(
        FileUploadService.supportsWithoutWorkspace(
          file('song.m4a', 'audio/mp4'),
        ),
        isTrue,
      );
      expect(
        FileUploadService.supportsWithoutWorkspace(
          file('data.xlsx', 'application/octet-stream'),
        ),
        isTrue,
      );
    },
  );
}
