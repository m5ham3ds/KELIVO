import 'package:flutter/material.dart';
import 'package:Kelivo/core/models/chat_attachment_library_item.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

/// Lets the user reuse previously sent files, or stage new files from Android,
/// before any of them are attached to the current message draft.
class ChatAttachmentLibrarySheet extends StatefulWidget {
  const ChatAttachmentLibrarySheet({
    required this.items,
    required this.onUploadFromPhone,
    super.key,
  });

  final List<ChatAttachmentLibraryItem> items;
  final Future<List<ChatAttachmentLibraryItem>> Function() onUploadFromPhone;

  static Future<List<ChatAttachmentLibraryItem>?> show({
    required BuildContext context,
    required List<ChatAttachmentLibraryItem> items,
    required Future<List<ChatAttachmentLibraryItem>> Function() onUploadFromPhone,
  }) => showModalBottomSheet<List<ChatAttachmentLibraryItem>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => ChatAttachmentLibrarySheet(
      items: items,
      onUploadFromPhone: onUploadFromPhone,
    ),
  );

  @override
  State<ChatAttachmentLibrarySheet> createState() =>
      _ChatAttachmentLibrarySheetState();
}

class _ChatAttachmentLibrarySheetState
    extends State<ChatAttachmentLibrarySheet> {
  late final TextEditingController _searchController;
  late final List<ChatAttachmentLibraryItem> _items;
  final Set<String> _selected = <String>{};
  bool _openingDevicePicker = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _items = List<ChatAttachmentLibraryItem>.of(widget.items);
    _searchController.addListener(_refresh);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  List<ChatAttachmentLibraryItem> get _visibleItems {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _items;
    return _items.where((item) {
      return item.fileName.toLowerCase().contains(query) ||
          item.mime.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  Future<void> _uploadFromPhone() async {
    if (_openingDevicePicker) return;
    setState(() => _openingDevicePicker = true);
    try {
      final picked = await widget.onUploadFromPhone();
      if (!mounted || picked.isEmpty) return;
      final known = _items.map((item) => item.path).toSet();
      setState(() {
        for (final item in picked) {
          if (known.add(item.path)) _items.add(item);
          _selected.add(item.path);
        }
      });
    } finally {
      if (mounted) setState(() => _openingDevicePicker = false);
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  IconData _fileIcon(ChatAttachmentLibraryItem item) {
    if (item.isImage) return Icons.image_outlined;
    final mime = item.mime.toLowerCase();
    if (mime.startsWith('video/')) return Icons.video_file_outlined;
    if (mime.startsWith('audio/')) return Icons.audio_file_outlined;
    if (mime == 'application/zip' || item.fileName.toLowerCase().endsWith('.7z')) {
      return Icons.folder_zip_outlined;
    }
    if (mime == 'application/pdf') return Icons.picture_as_pdf_outlined;
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final visible = _visibleItems;
    final selectedItems = [
      for (final item in _items)
        if (_selected.contains(item.path)) item,
    ];

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.78,
      child: Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.chatAttachmentLibraryTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.chatAttachmentLibrarySearch,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                        onPressed: _searchController.clear,
                        icon: const Icon(Icons.close),
                      ),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: visible.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _items.isEmpty
                              ? l10n.chatAttachmentLibraryEmpty
                              : l10n.chatAttachmentLibraryNoResults,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: visible.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = visible[index];
                        final selected = _selected.contains(item.path);
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            foregroundColor: theme.colorScheme.onSurfaceVariant,
                            child: Icon(_fileIcon(item)),
                          ),
                          title: Text(
                            item.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${_formatSize(item.sizeBytes)} · ${item.isPublished ? l10n.chatAttachmentLibraryPreviouslyUploaded : l10n.chatAttachmentLibraryFromDevice}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Checkbox.adaptive(
                            value: selected,
                            onChanged: (value) => setState(() {
                              if (value == true) {
                                _selected.add(item.path);
                              } else {
                                _selected.remove(item.path);
                              }
                            }),
                          ),
                          onTap: () => setState(() {
                            if (selected) {
                              _selected.remove(item.path);
                            } else {
                              _selected.add(item.path);
                            }
                          }),
                        );
                      },
                    ),
            ),
            if (selectedItems.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                l10n.chatAttachmentLibrarySelectedCount(selectedItems.length),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: _openingDevicePicker
                    ? null
                    : selectedItems.isEmpty
                    ? _uploadFromPhone
                    : () => Navigator.of(context).pop(selectedItems),
                icon: _openingDevicePicker
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        selectedItems.isEmpty
                            ? Icons.upload_file_rounded
                            : Icons.add_rounded,
                      ),
                label: Text(
                  _openingDevicePicker
                      ? l10n.chatAttachmentLibraryOpeningFiles
                      : selectedItems.isEmpty
                      ? l10n.chatAttachmentLibraryUploadFromFiles
                      : l10n.chatAttachmentLibraryAdd,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
