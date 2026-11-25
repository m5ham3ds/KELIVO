import 'dart:async';

import 'package:Kelivo/core/services/haptics.dart';
import 'package:Kelivo/core/services/skills/skills_service.dart';
import 'package:Kelivo/features/workspace/pages/plugins_page.dart';
import 'package:Kelivo/features/workspace/widgets/skills/skill_detail.dart';
import 'package:Kelivo/features/workspace/widgets/skills/skill_import.dart';
import 'package:Kelivo/features/workspace/widgets/skills/skill_labels.dart';
import 'package:Kelivo/features/workspace/widgets/skills/skill_pack_editor.dart';
import 'package:Kelivo/features/workspace/widgets/skills/skill_update_source.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_settings_rows.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/ios_tile_button.dart';
import 'package:Kelivo/shared/widgets/section_card.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

/// Embeddable skills list for the Skills page and desktop settings.
///
/// When [showHeader] is false the pane renders the list only — no ＋ row.
class SkillsPane extends StatefulWidget {
  const SkillsPane({super.key, this.padding, this.showHeader = true});

  final EdgeInsetsGeometry? padding;
  final bool showHeader;

  static const Key emptyKey = SkillsKeys.empty;
  static const Key listKey = SkillsKeys.list;
  static const Key searchKey = SkillsKeys.search;
  static const Key importKey = SkillsKeys.import;
  static const Key importPasteKey = SkillsKeys.importPaste;
  static const Key importFileKey = SkillsKeys.importFile;
  static const Key importGitHubKey = SkillsKeys.importGitHub;
  static const Key importSubmitKey = SkillsKeys.importSubmit;
  static const Key importErrorKey = SkillsKeys.importError;
  static const Key deleteKey = SkillsKeys.delete;
  static const Key emptyCtasKey = SkillsKeys.emptyCtas;

  static Key itemKey(String id) => SkillsKeys.item(id);

  static Key enableKey(String id) => SkillsKeys.enable(id);

  @override
  State<SkillsPane> createState() => SkillsPaneState();
}

class SkillsPaneState extends State<SkillsPane> {
  final TextEditingController _searchController = TextEditingController();

  final Set<String> _updatingPackIds = <String>{};
  final Set<String> _updatingSkillIds = <String>{};
  bool _updatingAll = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _updatePack(SkillPack pack) async {
    if (_updatingPackIds.contains(pack.id)) return;
    setState(() => _updatingPackIds.add(pack.id));
    final l10n = AppLocalizations.of(context)!;
    try {
      await context.read<SkillsService>().updateSkillPack(pack.id);
      if (mounted) {
        showAppSnackBar(context, message: l10n.skillsPackUpdateSuccess, type: NotificationType.success);
      }
    } catch (error) {
      if (mounted) {
        showAppSnackBar(
          context,
          message: '${l10n.skillsPackUpdateFailed}: $error',
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _updatingPackIds.remove(pack.id));
    }
  }

  Future<void> _updateSkill(Skill skill) async {
    if (_updatingSkillIds.contains(skill.record.id)) return;
    setState(() => _updatingSkillIds.add(skill.record.id));
    final l10n = AppLocalizations.of(context)!;
    try {
      await context.read<SkillsService>().updateFromRegistered(skill.record.id);
      if (mounted) {
        showAppSnackBar(context, message: l10n.skillsPackUpdateSuccess, type: NotificationType.success);
      }
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, message: '${l10n.skillsPackUpdateFailed}: $error', type: NotificationType.error);
      }
    } finally {
      if (mounted) setState(() => _updatingSkillIds.remove(skill.record.id));
    }
  }

  Future<void> _updateAll() async {
    if (_updatingAll) return;
    setState(() => _updatingAll = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      final result = await context
          .read<SkillsService>()
          .updateAllFromRegisteredSources();
      if (!mounted) return;
      if (result.failed.isEmpty) {
        showAppSnackBar(
          context,
          message: '${l10n.skillsPackUpdateSuccess} (${result.updated.length})',
          type: NotificationType.success,
        );
      } else {
        final details = result.failed.entries
            .take(2)
            .map((entry) => '${entry.key}: ${entry.value}')
            .join(' · ');
        showAppSnackBar(
          context,
          message: '${l10n.skillsPackUpdateFailed}: ${result.failed.length} · $details',
          type: NotificationType.error,
        );
      }
    } catch (error) {
      if (mounted) {
        showAppSnackBar(
          context,
          message: '${l10n.skillsPackUpdateFailed}: $error',
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _updatingAll = false);
    }
  }

  List<Skill> _filtered(List<Skill> skills) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return skills;
    return [
      for (final skill in skills)
        if (skill.name.toLowerCase().contains(query) ||
            skill.description.toLowerCase().contains(query))
          skill,
    ];
  }

  Widget _emptyState(AppLocalizations l10n, ColorScheme cs) {
    final child = Center(
      key: SkillsPane.emptyKey,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Lucide.WandSparkles,
                size: 44,
                color: cs.onSurface.withValues(alpha: 0.26),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.skillsEmptyTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: AppFontWeights.semibold,
                  color: cs.onSurface.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.skillsEmptyHint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: cs.onSurface.withValues(alpha: 0.52),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: context.appColors.surfaceFill,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  l10n.skillsEmptyFormat,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.4,
                    color: cs.onSurface.withValues(alpha: 0.72),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                key: SkillsKeys.emptyCtas,
                width: 260,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    IosTileButton(
                      key: SkillsKeys.importPaste,
                      icon: Lucide.ClipboardPaste,
                      label: l10n.skillsImportPaste,
                      onTap: () => unawaited(showSkillPasteImport(context)),
                    ),
                    const SizedBox(height: 8),
                    IosTileButton(
                      key: SkillsKeys.importFile,
                      icon: Lucide.FileUp,
                      label: l10n.skillsImportFile,
                      onTap: () => unawaited(importSkillFromFile(context)),
                    ),
                    const SizedBox(height: 8),
                    IosTileButton(
                      key: SkillsKeys.importGitHub,
                      leading: const GitHubGlyph(),
                      label: l10n.skillsImportGitHub,
                      onTap: () => unawaited(showSkillGitHubImport(context)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return child.animate().fadeIn(duration: 200.ms);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final service = context.watch<SkillsService>();
    final skills = service.skills;
    final packs = service.skillPacks;
    final query = _searchController.text.trim().toLowerCase();
    // Packs are additional reusable groupings; keep every installed Skill
    // visible in the standalone list even when it belongs to one or more packs.
    final filtered = _filtered(skills);
    final filteredPacks = packs.where((pack) {
      if (query.isEmpty) return true;
      if (pack.name.toLowerCase().contains(query) ||
          pack.shortcut.toLowerCase().contains(query) ||
          pack.description.toLowerCase().contains(query)) return true;
      return pack.skillIds.any((id) {
        final skill = skills.where((item) => item.record.id == id).firstOrNull;
        return skill != null && (skill.name.toLowerCase().contains(query) || id.toLowerCase().contains(query));
      });
    }).toList();
    final showSearch = skills.length > 8;

    return Padding(
      padding: widget.padding ?? EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showHeader)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.skillsTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: AppFontWeights.emphasis,
                            color: cs.onSurface,
                          ),
                        ),
                        if (packs.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              l10n.skillsPacksSubtitle,
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.skillsUpdateAll,
                    onPressed: _updatingAll ||
                            !skills.any((skill) => service.canUpdateSkill(skill.record.id))
                        ? null
                        : () => unawaited(_updateAll()),
                    icon: _updatingAll
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Lucide.RefreshCw, size: 20),
                  ),
                  IconButton(
                    tooltip: l10n.skillsPackCreate,
                    onPressed: skills.isEmpty ? null : () => unawaited(showSkillPackEditor(context)),
                    icon: const Icon(Lucide.FolderPlus, size: 21),
                  ),
                  const SkillsImportPlusButton(key: SkillsKeys.import),
                ],
              ),
            ),
          if (showSearch)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SkillsSearchField(
                controller: _searchController,
                onChanged: () => setState(() {}),
              ),
            ),
          Expanded(
            child: skills.isEmpty
                ? _emptyState(l10n, cs)
                : ListView(
                    key: SkillsPane.listKey,
                    padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
                    children: [
                      if (filteredPacks.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                          child: Text(
                            l10n.skillsPacksTitle,
                            style: TextStyle(fontSize: 13, fontWeight: AppFontWeights.semibold, color: cs.onSurfaceVariant),
                          ),
                        ),
                        SectionCard(
                          children: [
                            for (final pack in filteredPacks) ...[
                              if (pack != filteredPacks.first) const IosRowDivider(),
                              _SkillPackTile(
                                pack: pack,
                                index: packs.indexWhere((item) => item.id == pack.id),
                                total: packs.length,
                                updating: _updatingPackIds.contains(pack.id),
                                canUpdate: service.canUpdateSkillPack(pack.id),
                                onTap: () => unawaited(showSkillPackEditor(context, pack: pack)),
                                onUpdate: () => unawaited(_updatePack(pack)),
                                onToggle: (value) => unawaited(service.setSkillPackEnabled(pack.id, value)),
                                onMove: (delta) {
                                  final oldIndex = packs.indexWhere((item) => item.id == pack.id);
                                  final newIndex = oldIndex + delta;
                                  if (oldIndex < 0 || newIndex < 0 || newIndex >= packs.length) return;
                                  unawaited(service.reorderSkillPacks(oldIndex, delta > 0 ? newIndex + 1 : newIndex));
                                },
                              ),
                            ],
                          ],
                        ),
                      ],
                      if (filtered.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                          child: Text(
                            l10n.skillsTitle,
                            style: TextStyle(fontSize: 13, fontWeight: AppFontWeights.semibold, color: cs.onSurfaceVariant),
                          ),
                        ),
                        SectionCard(
                          children: [
                            for (var i = 0; i < filtered.length; i++) ...[
                              if (i > 0) const IosRowDivider(),
                              _SkillTile(
                                skill: filtered[i],
                                updating: _updatingSkillIds.contains(filtered[i].record.id),
                                onUpdate: service.canUpdateSkill(filtered[i].record.id)
                                    ? () => unawaited(_updateSkill(filtered[i]))
                                    : null,
                                onLinkSource: service.canUpdateSkill(filtered[i].record.id)
                                    ? null
                                    : () => unawaited(
                                        showSkillUpdateSourceDialog(context, filtered[i]),
                                      ),
                              ),
                            ],
                          ],
                        ),
                      ],
                      if (filteredPacks.isEmpty && filtered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(child: Text(l10n.skillsSearchNoResults)),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Management controls shared by the full Skills page AppBars and the
/// embedded SkillsPane header. Keeping these actions outside the scrollable
/// list makes refresh and pack creation available on small screens too.
class SkillsPageActions extends StatefulWidget {
  const SkillsPageActions({super.key, this.compact = false});

  final bool compact;

  @override
  State<SkillsPageActions> createState() => _SkillsPageActionsState();
}

class _SkillsPageActionsState extends State<SkillsPageActions> {
  bool _updatingAll = false;

  Future<void> _updateAll() async {
    if (_updatingAll) return;
    setState(() => _updatingAll = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      final result = await context
          .read<SkillsService>()
          .updateAllFromRegisteredSources();
      if (!mounted) return;
      if (result.failed.isEmpty) {
        showAppSnackBar(
          context,
          message: '${l10n.skillsPackUpdateSuccess} (${result.updated.length})',
          type: NotificationType.success,
        );
      } else {
        final details = result.failed.entries
            .take(2)
            .map((entry) => '${entry.key}: ${entry.value}')
            .join(' · ');
        showAppSnackBar(
          context,
          message: '${l10n.skillsPackUpdateFailed}: '
              '${result.failed.length} · $details',
          type: NotificationType.error,
        );
      }
    } catch (error) {
      if (mounted) {
        showAppSnackBar(
          context,
          message: '${l10n.skillsPackUpdateFailed}: $error',
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _updatingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final service = context.watch<SkillsService>();
    final canUpdate = service.skills.any(
      (skill) => service.canUpdateSkill(skill.record.id),
    );
    final iconSize = widget.compact ? 18.0 : 20.0;
    final minSize = widget.compact ? 34.0 : 44.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: SkillsKeys.updateAll,
          tooltip: l10n.skillsUpdateAll,
          visualDensity: widget.compact
              ? VisualDensity.compact
              : VisualDensity.standard,
          onPressed: _updatingAll || !canUpdate
              ? null
              : () => unawaited(_updateAll()),
          icon: _updatingAll
              ? SizedBox(
                  width: iconSize,
                  height: iconSize,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Lucide.RefreshCw, size: iconSize),
        ),
        IconButton(
          key: SkillsKeys.createPack,
          tooltip: l10n.skillsPackCreate,
          visualDensity: widget.compact
              ? VisualDensity.compact
              : VisualDensity.standard,
          onPressed: service.skills.isEmpty
              ? null
              : () => unawaited(showSkillPackEditor(context)),
          icon: Icon(Lucide.FolderPlus, size: iconSize + 1),
        ),
        IconButton(
          tooltip: Localizations.localeOf(context).languageCode == 'ar'
              ? 'إدارة Plugins'
              : 'Manage Plugins',
          visualDensity: widget.compact
              ? VisualDensity.compact
              : VisualDensity.standard,
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => const PluginsPage(),
            ),
          ),
          icon: Icon(Icons.extension_outlined, size: iconSize + 1),
        ),
        SkillsImportPlusButton(
          key: SkillsKeys.import,
          size: iconSize + 1,
          minSize: minSize,
        ),
      ],
    );
  }
}

class _SkillsSearchField extends StatelessWidget {
  const _SkillsSearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final hasText = controller.text.isNotEmpty;
    return TextField(
      key: SkillsPane.searchKey,
      controller: controller,
      onChanged: (_) => onChanged(),
      cursorColor: cs.primary,
      style: TextStyle(color: cs.onSurface),
      decoration: InputDecoration(
        hintText: l10n.skillsSearchHint,
        prefixIcon: Icon(
          Lucide.Search,
          size: 18,
          color: cs.onSurface.withValues(alpha: 0.6),
        ),
        suffixIcon: hasText
            ? Tooltip(
                message: l10n.skillsSearchClear,
                child: IosIconButton(
                  icon: Lucide.X,
                  size: 16,
                  semanticLabel: l10n.skillsSearchClear,
                  onTap: () {
                    Haptics.light();
                    controller.clear();
                    onChanged();
                  },
                ),
              )
            : null,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        filled: true,
        fillColor: context.appColors.surfaceFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.primary.withValues(alpha: 0.5)),
        ),
      ),
    );
  }
}

class _SkillTile extends StatelessWidget {
  const _SkillTile({
    required this.skill,
    this.updating = false,
    this.onUpdate,
    this.onLinkSource,
  });

  final Skill skill;
  final bool updating;
  final VoidCallback? onUpdate;
  final VoidCallback? onLinkSource;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final description = skill.description.trim();
    return IosNavRow(
      key: SkillsPane.itemKey(skill.record.id),
      icon: Lucide.WandSparkles,
      label: skill.name,
      labelWeight: AppFontWeights.medium,
      subtitle: description.isEmpty ? null : description,
      caption: l10n.skillsUsedCount(skill.record.useCount),
      onTap: () =>
          unawaited(showSkillDetail(context, skillId: skill.record.id)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onUpdate != null)
            IconButton(
              tooltip: l10n.skillsUpdate,
              onPressed: updating ? null : onUpdate,
              icon: updating
                  ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Lucide.RefreshCw, size: 18),
            ),
          if (onLinkSource != null)
            IconButton(
              key: SkillsKeys.linkSource(skill.record.id),
              tooltip: l10n.skillsLinkUpdateSource,
              onPressed: onLinkSource,
              icon: const Icon(Lucide.Link2, size: 18),
            ),
          IosSwitch(
            key: SkillsPane.enableKey(skill.record.id),
            value: skill.record.enabled,
            semanticLabel: l10n.skillsEnabled,
            onChanged: (value) {
              unawaited(
                context.read<SkillsService>().setEnabled(skill.record.id, value),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SkillPackTile extends StatelessWidget {
  const _SkillPackTile({
    required this.pack,
    required this.index,
    required this.total,
    required this.updating,
    required this.canUpdate,
    required this.onTap,
    required this.onUpdate,
    required this.onToggle,
    required this.onMove,
  });

  final SkillPack pack;
  final int index;
  final int total;
  final bool updating;
  final bool canUpdate;
  final VoidCallback onTap;
  final VoidCallback onUpdate;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onMove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final service = context.watch<SkillsService>();
    final names = pack.skillIds.map((id) {
      for (final skill in service.skills) {
        if (skill.record.id == id) return skill.name;
      }
      return id;
    }).join(' · ');
    return IosNavRow(
      icon: Lucide.FolderOpen,
      label: pack.name,
      labelWeight: AppFontWeights.semibold,
      subtitle: [
        '/${pack.shortcut}',
        l10n.skillsPackCount(pack.skillIds.length),
        if (pack.autoDetected) l10n.skillsPackAutoDetected,
      ].join(' · '),
      caption: names,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canUpdate)
            IconButton(
              tooltip: l10n.skillsPackUpdate,
              onPressed: updating ? null : onUpdate,
              icon: updating
                  ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Lucide.RefreshCw, size: 17),
            ),
          PopupMenuButton<String>(
            tooltip: l10n.skillsMoreActions,
            onSelected: (value) {
              if (value == 'up') onMove(-1);
              if (value == 'down') onMove(1);
              if (value == 'edit') onTap();
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'up', enabled: index > 0, child: Text(l10n.skillsPackMoveUp)),
              PopupMenuItem(value: 'down', enabled: index >= 0 && index < total - 1, child: Text(l10n.skillsPackMoveDown)),
              PopupMenuItem(value: 'edit', child: Text(l10n.skillsPackEdit)),
            ],
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Lucide.Ellipsis, size: 19),
            ),
          ),
          IosSwitch(
            value: pack.enabled,
            semanticLabel: l10n.skillsEnabled,
            onChanged: onToggle,
          ),
        ],
      ),
    );
  }
}
