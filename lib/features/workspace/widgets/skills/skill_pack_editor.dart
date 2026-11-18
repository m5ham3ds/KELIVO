import 'dart:async';

import 'package:Kelivo/core/services/skills/skills_service.dart';
import 'package:Kelivo/features/workspace/workspace_layout.dart';
import 'package:Kelivo/features/workspace/widgets/skills/skill_update_source.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Future<void> showSkillPackEditor(
  BuildContext context, {
  SkillPack? pack,
}) {
  if (useDesktopWorkspaceLayout(context)) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 620,
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          ),
          child: SkillPackEditorSheet(pack: pack),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => SkillPackEditorSheet(pack: pack),
  );
}

class SkillPackEditorSheet extends StatefulWidget {
  const SkillPackEditorSheet({super.key, this.pack});

  final SkillPack? pack;

  @override
  State<SkillPackEditorSheet> createState() => _SkillPackEditorSheetState();
}

class _SkillPackEditorSheetState extends State<SkillPackEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _shortcut;
  late final TextEditingController _description;
  late List<String> _selectedIds;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.pack?.name ?? '');
    _shortcut = TextEditingController(text: widget.pack?.shortcut ?? '');
    _description = TextEditingController(text: widget.pack?.description ?? '');
    _selectedIds = List<String>.of(widget.pack?.skillIds ?? const <String>[]);
  }

  @override
  void dispose() {
    _name.dispose();
    _shortcut.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _chooseSkills() async {
    final service = context.read<SkillsService>();
    final l10n = AppLocalizations.of(context)!;
    final selected = Set<String>.of(_selectedIds);
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final skills = service.skills.toList()
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          return AlertDialog(
            title: Text(l10n.skillsPackMembers),
            content: SizedBox(
              width: 420,
              height: MediaQuery.sizeOf(context).height * 0.55,
              child: ListView.builder(
                itemCount: skills.length,
                itemBuilder: (context, index) {
                  final skill = skills[index];
                  final checked = selected.contains(skill.record.id);
                  return CheckboxListTile(
                    dense: true,
                    value: checked,
                    title: Text(skill.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(skill.record.id, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onChanged: (value) => setDialogState(() {
                      if (value == true) {
                        selected.add(skill.record.id);
                      } else {
                        selected.remove(skill.record.id);
                      }
                    }),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.skillsCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(selected),
                child: Text(l10n.skillsSave),
              ),
            ],
          );
        },
      ),
    );
    if (result != null && mounted) {
      setState(() {
        // Keep the existing order, then append newly selected Skills in the
        // visible library order. Users can fine-tune the order by dragging.
        final current = _selectedIds.where(result.contains).toList();
        for (final skill in service.skills) {
          if (result.contains(skill.record.id) && !current.contains(skill.record.id)) {
            current.add(skill.record.id);
          }
        }
        _selectedIds = current;
      });
    }
  }

  Future<void> _deletePack() async {
    final pack = widget.pack;
    if (pack == null) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.skillsPackDelete),
        content: Text(l10n.skillsPackDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.skillsCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.skillsPackDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<SkillsService>().deleteSkillPack(pack.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _save() async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context)!;
    if (_selectedIds.isEmpty) {
      showAppSnackBar(context, message: l10n.skillsPackEmpty, type: NotificationType.warning);
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<SkillsService>().saveSkillPack(
        id: widget.pack?.id,
        name: _name.text,
        shortcut: _shortcut.text,
        description: _description.text,
        skillIds: _selectedIds,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppSnackBar(context, message: l10n.skillsPackSave, type: NotificationType.success);
    } catch (error) {
      if (!mounted) return;
      final message = switch (error) {
        FormatException(message: 'skill_pack_shortcut_already_exists') =>
          l10n.skillsPackShortcutConflict,
        FormatException(message: 'skill_pack_shortcut') =>
          l10n.skillsPackShortcutInvalid,
        FormatException(message: 'skill_pack_name') =>
          l10n.skillsPackNameInvalid,
        FormatException(message: 'skill_pack_members') =>
          l10n.skillsPackMembersInvalid,
        _ => '$error',
      };
      showAppSnackBar(context, message: message, type: NotificationType.error);
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final service = context.watch<SkillsService>();
    final skillById = {for (final skill in service.skills) skill.record.id: skill};
    final selectedSkills = [
      for (final id in _selectedIds)
        if (skillById[id] != null) skillById[id]!,
    ];
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(18, 4, 18, 18 + bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.82,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.pack == null ? l10n.skillsPackCreate : l10n.skillsPackEdit,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (widget.pack != null)
                  IconButton(
                    tooltip: l10n.skillsPackDelete,
                    onPressed: _saving ? null : _deletePack,
                    icon: Icon(Lucide.Trash2, color: cs.error),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n.skillsPackName,
                hintText: l10n.skillsPackNameHint,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _shortcut,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.none,
              decoration: InputDecoration(
                labelText: l10n.skillsPackShortcut,
                hintText: l10n.skillsPackShortcutHint,
                prefixText: '/',
                helperText: 'a-z, 0-9, _',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _description,
              maxLines: 2,
              decoration: InputDecoration(labelText: l10n.skillsPackDescription),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${l10n.skillsPackMembers} · ${selectedSkills.length}',
                    style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
                  ),
                ),
                TextButton.icon(
                  onPressed: _saving ? null : _chooseSkills,
                  icon: const Icon(Lucide.Plus, size: 17),
                  label: Text(l10n.skillsPackMembers),
                ),
              ],
            ),
            Expanded(
              child: selectedSkills.isEmpty
                  ? Center(
                      child: Text(
                        l10n.skillsPackEmpty,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    )
                  : ReorderableListView.builder(
                      itemCount: selectedSkills.length,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex--;
                          final item = _selectedIds.removeAt(oldIndex);
                          _selectedIds.insert(newIndex, item);
                        });
                      },
                      itemBuilder: (context, index) {
                        final skill = selectedSkills[index];
                        return ListTile(
                          key: ValueKey(skill.record.id),
                          leading: const Icon(Lucide.GripVertical, size: 18),
                          title: Text(skill.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(skill.record.id, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!service.canUpdateSkill(skill.record.id))
                                IconButton(
                                  tooltip: l10n.skillsLinkUpdateSource,
                                  onPressed: () => unawaited(
                                    showSkillUpdateSourceDialog(context, skill),
                                  ),
                                  icon: const Icon(Lucide.Link2, size: 17),
                                ),
                              IconButton(
                                tooltip: l10n.skillsDelete,
                                onPressed: () => setState(
                                  () => _selectedIds.remove(skill.record.id),
                                ),
                                icon: const Icon(Lucide.X, size: 18),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Lucide.Check, size: 18),
              label: Text(l10n.skillsPackSave),
            ),
          ],
        ),
      ),
    );
  }
}
