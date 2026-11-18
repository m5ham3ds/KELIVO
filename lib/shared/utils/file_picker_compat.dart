import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart' as fp;

export 'package:file_picker/file_picker.dart' show FileType, FilePickerStatus;

/// KELIVO's compatibility layer for the file_picker 12 federated API.
///
/// Keeps existing call sites and injectable test doubles stable while the
/// maintained package moves to static methods and lazy file reads.
class FilePicker {
  FilePicker();

  static FilePicker platform = FilePicker();

  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    fp.FileType type = fp.FileType.any,
    List<String>? allowedExtensions,
    Function(fp.FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    // These legacy flags are retained for existing callers and test doubles.
    // KELIVO reads content on demand with PlatformFile.readAsBytes().
    final List<fp.PlatformFile> picked;
    if (allowMultiple) {
      picked = await fp.FilePicker.pickFiles(
        dialogTitle: dialogTitle,
        initialDirectory: initialDirectory,
        type: type,
        allowedExtensions: allowedExtensions,
        compressionQuality: compressionQuality,
        onFileLoading: onFileLoading,
      );
    } else {
      final single = await fp.FilePicker.pickFile(
        dialogTitle: dialogTitle,
        initialDirectory: initialDirectory,
        type: type,
        allowedExtensions: allowedExtensions,
        compressionQuality: compressionQuality,
        onFileLoading: onFileLoading,
      );
      picked = single == null ? const <fp.PlatformFile>[] : [single];
    }
    if (picked.isEmpty) return null;
    return FilePickerResult(
      picked.map(PlatformFile._fromPicker).toList(growable: false),
    );
  }

  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    fp.FileType type = fp.FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    final name = fileName?.trim();
    if (name == null || name.isEmpty) {
      throw ArgumentError.value(fileName, 'fileName', 'A file name is required');
    }
    // v12 requires bytes and performs the write. Existing desktop flows choose
    // a path first and then copy/write their own source; an empty payload keeps
    // that behavior without buffering the source file.
    final uri = await fp.FilePicker.saveFile(
      fileName: name,
      bytes: bytes ?? Uint8List(0),
      dialogTitle: dialogTitle,
      initialDirectory: initialDirectory,
      type: type,
      allowedExtensions: allowedExtensions,
    );
    if (uri == null) return null;
    return uri.scheme == 'file' ? uri.toFilePath() : uri.toString();
  }

  Future<String?> getDirectoryPath({
    String? dialogTitle,
    bool lockParentWindow = false,
    String? initialDirectory,
  }) {
    return fp.FilePicker.getDirectoryPath(
      dialogTitle: dialogTitle,
      initialDirectory: initialDirectory,
    );
  }
}

String? _extensionFromName(String name) {
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) return null;
  return name.substring(dot + 1);
}

/// Result wrapper retained for call sites that used the pre-v12 result object.
class FilePickerResult {
  const FilePickerResult(this.files);

  final List<PlatformFile> files;
}

/// Small compatibility wrapper around file_picker's new PlatformFile.
class PlatformFile {
  PlatformFile({
    required this.name,
    required this.size,
    this.bytes,
    this.path,
    String? extension,
    fp.PlatformFile? delegate,
  }) : extension = extension ?? _extensionFromName(name),
       _delegate = delegate;

  factory PlatformFile._fromPicker(fp.PlatformFile file) {
    return PlatformFile(
      name: file.name,
      size: file.lengthSync() ?? 0,
      path: file.path,
      extension: file.extension,
      delegate: file,
    );
  }

  final String name;
  final int size;
  final Uint8List? bytes;
  final String? path;
  final String? extension;
  final fp.PlatformFile? _delegate;

  Future<Uint8List> readAsBytes() async {
    final cached = bytes;
    if (cached != null) return cached;
    final delegate = _delegate;
    if (delegate != null) return delegate.readAsBytes();
    final localPath = path;
    if (localPath != null && localPath.isNotEmpty) {
      return File(localPath).readAsBytes();
    }
    throw FileSystemException('The selected file has no readable source', name);
  }
}
