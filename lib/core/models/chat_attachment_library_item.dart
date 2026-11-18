import 'package:path/path.dart' as p;

/// A file already published by a sent message, or temporarily staged from the
/// device picker while the attachment-library sheet is open.
class ChatAttachmentLibraryItem {
  const ChatAttachmentLibraryItem({
    required this.path,
    required this.fileName,
    required this.mime,
    required this.sizeBytes,
    required this.isPublished,
    this.modifiedAt,
  });

  final String path;
  final String fileName;
  final String mime;
  final int sizeBytes;
  final bool isPublished;
  final DateTime? modifiedAt;

  String get id => path;

  bool get isImage {
    if (mime.toLowerCase().startsWith('image/')) return true;
    return const {
      '.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp', '.heic', '.heif',
    }.contains(p.extension(fileName).toLowerCase());
  }
}
