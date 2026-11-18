import 'package:flutter/material.dart';

import 'package:Kelivo/core/services/storage/kelivo_public_storage.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_settings_rows.dart';
import 'package:Kelivo/shared/widgets/section_card.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';

/// Selects a durable, user-owned folder through Android SAF. This folder is
/// for copies/exports only; it is never mounted into the PRoot guest.
class EnvironmentPublicStorageSection extends StatefulWidget {
  const EnvironmentPublicStorageSection({super.key});

  @override
  State<EnvironmentPublicStorageSection> createState() =>
      _EnvironmentPublicStorageSectionState();
}

class _EnvironmentPublicStorageSectionState
    extends State<EnvironmentPublicStorageSection> {
  final KelivoPublicStorageService _storage = KelivoPublicStorageService();
  KelivoPublicFolder? _folder;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final folder = await _storage.currentFolder();
      if (!mounted) return;
      setState(() {
        _folder = folder;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _folder = null;
        _loading = false;
      });
    }
  }

  Future<void> _choose() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final selected = await _storage.chooseFolder();
      if (!mounted) return;
      if (selected != null) {
        setState(() => _folder = selected);
        showAppSnackBar(
          context,
          message: AppLocalizations.of(context)!.kelivoPublicStorageSaved,
          type: NotificationType.success,
        );
      }
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: '${AppLocalizations.of(context)!.kelivoPublicStorageFailed}: $error',
        type: NotificationType.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final folder = _folder;
    final subtitle = _loading
        ? l10n.kelivoPublicStorageLoading
        : folder == null
        ? l10n.kelivoPublicStorageNotConfigured
        : folder.accessible
        ? '${folder.name} · ${l10n.kelivoPublicStorageActive}'
        : '${folder.name} · ${l10n.kelivoPublicStoragePermissionLost}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        IosSectionHeader(text: l10n.kelivoPublicStorageTitle),
        SectionCard(
          children: [
            IosNavRow(
              icon: Lucide.FolderOpen,
              label: l10n.kelivoPublicStorageChoose,
              subtitle: subtitle,
              trailing: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: _busy || _loading ? null : () => _choose(),
            ),
          ],
        ),
        IosSectionFooter(text: l10n.kelivoPublicStorageSubtitle),
      ],
    );
  }
}
