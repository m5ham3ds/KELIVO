import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:Kelivo/shared/utils/file_picker_compat.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import '../../../l10n/app_localizations.dart';
import '../../../utils/file_import_helper.dart';
import '../../../utils/image_compressor.dart';
import '../../../utils/platform_utils.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../core/models/chat_input_data.dart';
import '../../../core/models/chat_attachment_library_item.dart';
import '../../../core/utils/multimodal_input_utils.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/chat_attachment_library_sheet.dart';

/// 文件选取和上传服务
///
/// 负责处理：
/// - 图片选择 (相册/相机)
/// - 文件选择
/// - 桌面拖放处理
/// - 文件复制到应用目录
class FileUploadService {
  FileUploadService({
    required this.getContext,
    required this.mediaController,
    required this.isImageCropperEnabled,
    required this.getImageCompressConfig,
    this.hasWorkspace,
  });

  /// 媒体控制器，用于添加图片和文件到输入栏
  final ChatInputBarController mediaController;

  /// Context provider callback to avoid storing stale context
  final BuildContext Function() getContext;
  final bool Function() isImageCropperEnabled;
  final ImageCompressConfig Function() getImageCompressConfig;
  final bool Function()? hasWorkspace;

  static const supportedExtensions = [
    'png',
    'jpg',
    'jpeg',
    'gif',
    'webp',
    'bmp',
    'heic',
    'heif',
    'mp4',
    'avi',
    'mkv',
    'mov',
    'flv',
    'wmv',
    'mpeg',
    'mpg',
    'webm',
    '3gp',
    '3gpp',
    'wav',
    'mp3',
    'm4a',
    'aac',
    'flac',
    'ogg',
    'oga',
    'opus',
    'aiff',
    'aif',
    'pcm',
    'pcm16',
    'txt',
    'md',
    'json',
    'js',
    'pdf',
    'docx',
    'html',
    'xml',
    'py',
    'java',
    'kt',
    'dart',
    'ts',
    'tsx',
    'markdown',
    'mdx',
    'yml',
    'yaml',
    'doc',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'csv',
    'tsv',
    'jsonl',
    'toml',
    'ini',
    'conf',
    'log',
    'sql',
    'sh',
    'bash',
    'go',
    'rs',
    'c',
    'cpp',
    'h',
    'hpp',
    'cs',
    'php',
    'rb',
    'swift',
    'gradle',
    'properties',
    'env',
    'ipynb',
  ];

  static bool supportsWithoutWorkspace(DocumentAttachment file) {
    final mime = resolveDocumentAttachmentMime(file);
    return isImageMime(mime) ||
        isAudioMime(mime) ||
        isVideoMime(mime) ||
        supportedExtensions.contains(
          p.extension(file.fileName).replaceFirst('.', '').toLowerCase(),
        ) ||
        isSandboxDataFile(fileName: file.fileName, mime: file.mime);
  }

  /// 复制选中的文件到应用上传目录
  ///
  /// [files] 要复制的文件列表
  /// 返回复制后的文件路径列表
  Future<List<String>> copyPickedFiles(List<XFile> files) async {
    final saved = await _copyPickedFilesKeepingSlots(files);
    return saved.whereType<String>().toList(growable: false);
  }

  Future<List<String?>> _copyPickedFilesKeepingSlots(
    List<XFile> files, {
    ChatInputBarController? target,
  }) async {
    final dir = await (target ?? mediaController.capture()).uploadDirectory();
    final out = <String?>[];
    final context = getContext();
    if (!context.mounted) return out;
    final compressConfig = getImageCompressConfig();
    for (final f in files) {
      final sourceName = f.name.isNotEmpty ? f.name : f.path;
      final savedPath = isImageExtension(sourceName) && f.path.isNotEmpty
          ? (await ImageCompressor.compressToUploadDir(
              f.path,
              dir,
              compressConfig,
            ))?.path
          : await FileImportHelper.copyXFile(f, dir);
      out.add(savedPath);
    }
    return out;
  }

  void _enqueuePickedImages(
    Iterable<XFile> files,
    ChatInputBarController target,
  ) {
    final paths = [
      for (final file in files)
        if (file.path.isNotEmpty) file.path,
    ];
    if (paths.isEmpty) return;
    target.enqueueImages(paths, getImageCompressConfig());
  }

  /// 从相册选取图片
  Future<void> onPickPhotos() async {
    if (mediaController.restoringDraft) return;
    final target = mediaController.capture();
    try {
      // On desktop, fall back to FilePicker as image_picker is not supported.
      if (PlatformUtils.isDesktopTarget) {
        final res = await FilePicker.platform.pickFiles(
          allowMultiple: true,
          withData: false,
          type: FileType.custom,
          allowedExtensions: const [
            'png',
            'jpg',
            'jpeg',
            'gif',
            'webp',
            'bmp',
            'heic',
            'heif',
          ],
        );
        if (res == null || res.files.isEmpty) return;
        final toCopy = <XFile>[];
        for (final f in res.files) {
          if (f.path != null && f.path!.isNotEmpty) {
            toCopy.add(XFile(f.path!));
          }
        }
        if (toCopy.isEmpty) return;
        final croppedFiles = await _maybeCropImages(toCopy);
        if (croppedFiles.isEmpty) return;
        _enqueuePickedImages(croppedFiles, target);
        return;
      }

      final picker = ImagePicker();
      final files = await picker.pickMultiImage();
      if (files.isEmpty) return;
      final croppedFiles = await _maybeCropImages(files);
      if (croppedFiles.isEmpty) return;
      _enqueuePickedImages(croppedFiles, target);
    } catch (_) {}
  }

  /// 从相机拍照
  ///
  /// [context] 用于显示权限提示和错误消息
  Future<void> onPickCamera(BuildContext context) async {
    if (mediaController.restoringDraft) return;
    final target = mediaController.capture();
    try {
      // Proactive permission check on mobile
      if (PlatformUtils.isMobile) {
        var status = await Permission.camera.status;
        // Request if not determined; otherwise guide user
        if (status.isDenied || status.isRestricted) {
          status = await Permission.camera.request();
        }
        if (!status.isGranted) {
          if (!context.mounted) return;
          final l10n = AppLocalizations.of(context)!;
          showAppSnackBar(
            context,
            message: l10n.cameraPermissionDeniedMessage,
            type: NotificationType.error,
            duration: const Duration(seconds: 4),
            actionLabel: l10n.openSystemSettings,
            onAction: () {
              try {
                openAppSettings();
              } catch (_) {}
            },
          );
          return;
        }
      }
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.camera);
      if (file == null) return;
      final croppedFiles = await _maybeCropImages([file]);
      if (croppedFiles.isEmpty) return;
      if (!context.mounted) return;
      _enqueuePickedImages(croppedFiles, target);
    } catch (e) {
      try {
        if (!context.mounted) return;
        final l10n = AppLocalizations.of(context)!;
        showAppSnackBar(
          context,
          message: l10n.cameraPermissionDeniedMessage,
          type: NotificationType.error,
          duration: const Duration(seconds: 3),
        );
      } catch (_) {}
    }
  }

  Future<List<XFile>> _maybeCropImages(List<XFile> files) async {
    if (!isImageCropperEnabled()) return files;

    final context = getContext();
    if (!context.mounted) return files;
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final croppedFiles = <XFile>[];

    for (final file in files) {
      try {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: file.path,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: l10n.displaySettingsPageEnableImageCropperTitle,
              toolbarColor: cs.surface,
              toolbarWidgetColor: cs.onSurface,
              activeControlsWidgetColor: cs.primary,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: false,
            ),
            IOSUiSettings(
              title: l10n.displaySettingsPageEnableImageCropperTitle,
            ),
          ],
        );
        if (croppedFile != null) {
          croppedFiles.add(XFile(croppedFile.path));
        }
      } catch (_) {
        croppedFiles.add(file);
      }
    }

    return croppedFiles;
  }

  /// 根据文件扩展名推断 MIME 类型
  String inferMimeByExtension(String name) {
    final mediaMime = inferMediaMimeFromSource(name);
    if (mediaMime.isNotEmpty) return mediaMime;
    final lower = name.toLowerCase();
    // Documents / text
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.zip')) return 'application/zip';
    if (lower.endsWith('.7z')) return 'application/x-7z-compressed';
    if (lower.endsWith('.rar')) return 'application/vnd.rar';
    if (lower.endsWith('.tar')) return 'application/x-tar';
    if (lower.endsWith('.gz')) return 'application/gzip';
    if (lower.endsWith('.bz2')) return 'application/x-bzip2';
    if (lower.endsWith('.xz')) return 'application/x-xz';
    if (lower.endsWith('.apk')) return 'application/vnd.android.package-archive';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.xls')) return 'application/vnd.ms-excel';
    if (lower.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    if (lower.endsWith('.ppt')) return 'application/vnd.ms-powerpoint';
    if (lower.endsWith('.pptx')) {
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    }
    if (lower.endsWith('.csv')) return 'text/csv';
    if (lower.endsWith('.tsv')) return 'text/tab-separated-values';
    if (lower.endsWith('.json')) return 'application/json';
    if (lower.endsWith('.js')) return 'application/javascript';
    if (lower.endsWith('.html') || lower.endsWith('.htm')) return 'text/html';
    if (lower.endsWith('.xml')) return 'application/xml';
    if (lower.endsWith('.yaml') || lower.endsWith('.yml')) return 'application/yaml';
    if (lower.endsWith('.txt') || lower.endsWith('.md')) return 'text/plain';
    return supportedExtensions.contains(
          p.extension(lower).replaceFirst('.', ''),
        )
        ? 'text/plain'
        : 'application/octet-stream';
  }

  /// 判断文件是否为图片（根据扩展名）
  bool isImageExtension(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.heic') ||
        lower.endsWith('.heif');
  }

  /// Opens the device picker without importing the selected files yet. The
  /// returned items are staged in the library sheet and become attachments
  /// only after the user presses its Add button.
  Future<List<ChatAttachmentLibraryItem>> pickFilesFromDevice() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
      type: FileType.any,
    );
    if (res == null || res.files.isEmpty) {
      return const <ChatAttachmentLibraryItem>[];
    }
    final items = <ChatAttachmentLibraryItem>[];
    final seen = <String>{};
    for (final picked in res.files) {
      final path = picked.path;
      if (path == null || path.isEmpty || !seen.add(path)) continue;
      try {
        final file = File(path);
        if (await FileSystemEntity.type(path, followLinks: false) !=
            FileSystemEntityType.file) {
          continue;
        }
        final stat = await file.stat();
        items.add(
          ChatAttachmentLibraryItem(
            path: file.absolute.path,
            fileName: p.basename(picked.name),
            mime: inferMimeByExtension(picked.name),
            sizeBytes: stat.size,
            isPublished: false,
            modifiedAt: stat.modified,
          ),
        );
      } on FileSystemException {
        continue;
      }
    }
    return items;
  }

  /// Opens the in-app attachment library first. Existing published attachments
  /// can be selected across conversations; new device files remain staged in
  /// the sheet until the user confirms Add.
  Future<void> onPickFiles() async {
    if (mediaController.restoringDraft) return;
    final target = mediaController.capture();
    final context = getContext();
    if (!context.mounted) return;
    try {
      final library = await target.publishedAttachments();
      if (!context.mounted) return;
      final selected = await ChatAttachmentLibrarySheet.show(
        context: context,
        items: library,
        onUploadFromPhone: pickFilesFromDevice,
      );
      if (!context.mounted || selected == null || selected.isEmpty) return;

      final newImages = <XFile>[];
      final publishedImages = <String>[];
      final newDocuments = <ChatAttachmentLibraryItem>[];
      final publishedDocuments = <DocumentAttachment>[];
      for (final item in selected) {
        if (isImageExtension(item.fileName)) {
          if (item.isPublished) {
            publishedImages.add(item.path);
          } else {
            newImages.add(XFile(item.path));
          }
        } else if (item.isPublished) {
          publishedDocuments.add(
            DocumentAttachment(
              path: item.path,
              fileName: item.fileName,
              mime: item.mime,
            ),
          );
        } else {
          newDocuments.add(item);
        }
      }

      // Reused images are already in their final upload form, so bypass the
      // image processing queue and preserve their stable shared file paths.
      if (publishedImages.isNotEmpty) target.addImages(publishedImages);
      if (newImages.isNotEmpty) _enqueuePickedImages(newImages, target);
      if (publishedDocuments.isNotEmpty) target.addFiles(publishedDocuments);

      if (newDocuments.isNotEmpty) {
        final directory = await target.uploadDirectory();
        final docs = <DocumentAttachment>[];
        for (final item in newDocuments) {
          final savedPath = await FileImportHelper.copyFilePath(
            item.path,
            directory,
            fileName: item.fileName,
          );
          if (savedPath == null) continue;
          docs.add(
            DocumentAttachment(
              path: savedPath,
              fileName: item.fileName,
              mime: item.mime,
            ),
          );
        }
        if (docs.isNotEmpty) target.addFiles(docs);
      }
    } catch (_) {}
  }

  /// 处理桌面端拖放的文件 (macOS/Windows/Linux)
  Future<void> onFilesDroppedDesktop(List<XFile> files) async {
    if (mediaController.restoringDraft) return;
    final target = mediaController.capture();
    if (files.isEmpty) return;
    try {
      final docs = <DocumentAttachment>[];
      final images = <XFile>[];
      final documents = <XFile>[];
      for (final f in files) {
        final name = (f.name.isNotEmpty
            ? f.name
            : (f.path.split(Platform.pathSeparator).last));
        if (isImageExtension(name)) {
          images.add(f);
        } else {
          documents.add(f);
        }
      }
      _enqueuePickedImages(images, target);

      final saved = await _copyPickedFilesKeepingSlots(
        documents,
        target: target,
      );
      for (final savedPath in saved) {
        if (savedPath == null) continue;
        final savedName = p.basename(savedPath);
        final mime = inferMimeByExtension(savedName);
        docs.add(
          DocumentAttachment(path: savedPath, fileName: savedName, mime: mime),
        );
      }
      if (docs.isNotEmpty) target.addFiles(docs);
    } catch (_) {}
  }
}
