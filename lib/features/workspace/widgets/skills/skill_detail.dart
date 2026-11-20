import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:Kelivo/core/services/haptics.dart';
import 'package:Kelivo/core/services/skills/skills_service.dart';
import 'package:Kelivo/core/services/skills/skill_requirements.dart';
import 'package:Kelivo/core/services/skills/skill_capability_registry.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/core/services/storage/kelivo_public_storage.dart';
import 'package:Kelivo/desktop/menu_anchor.dart';
import 'package:Kelivo/features/settings/widgets/custom_theme_widgets.dart';
import 'package:Kelivo/features/workspace/widgets/files/file_browser.dart';
import 'package:Kelivo/features/workspace/widgets/files/workspace_prompts.dart';
import 'package:Kelivo/features/workspace/widgets/preview/preview_states.dart';
import 'package:Kelivo/features/workspace/widgets/skills/skill_import.dart';
import 'package:Kelivo/features/workspace/widgets/skills/skill_update_source.dart';
import 'package:Kelivo/features/workspace/widgets/skills/skill_labels.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/features/workspace/workspace_layout.dart';
import 'package:Kelivo/shared/utils/format_bytes.dart';
import 'package:Kelivo/shared/utils/save_file_picker.dart';
import 'package:Kelivo/shared/widgets/action_sheet.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/markdown/markdown_with_code_highlight.dart';
import 'package:Kelivo/shared/widgets/app_selection_area.dart';
import 'package:Kelivo/shared/widgets/section_card.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

String skillModelPath(Skill skill, String hostPath) {
  final rel = p.relative(hostPath, from: skill.dir).replaceAll('\\', '/');
  if (rel == '.' || rel == './') return '/skills/${skill.record.id}';
  return '/skills/${skill.record.id}/$rel';
}

Future<void> showSkillDetail(BuildContext context, {required String skillId}) {
  if (useDesktopWorkspaceLayout(context)) {
    final height = MediaQuery.sizeOf(context).height * 0.8;
    return showAppDialog<void>(
      context,
      maxWidth: 720,
      child: SizedBox(
        height: height,
        child: SkillDetailView(skillId: skillId, dialog: true),
      ),
    );
  }
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => SkillDetailPage(skillId: skillId)),
  );
}

Future<void> editSkillBody(BuildContext context, Skill skill) async {
  final l10n = AppLocalizations.of(context)!;
  var initial = '';
  try {
    initial = File(skill.skillMdPath).readAsStringSync();
  } catch (_) {}
  await showSkillTextImport(
    context: context,
    title: l10n.skillsEditTitle,
    label: l10n.skillsImportPasteLabel,
    hint: l10n.skillsImportPasteHint,
    confirmLabel: l10n.skillsSave,
    minLines: 8,
    maxLines: 16,
    initial: initial,
    onSubmit: (markdown) async {
      await context.read<SkillsService>().updateBody(skill.record.id, markdown);
    },
  );
}

Future<void> exportSkill(BuildContext context, Skill skill) async {
  final l10n = AppLocalizations.of(context)!;
  final service = context.read<SkillsService>();
  try {
    final outDir = await Directory.systemTemp.createTemp(
      'kelivo_skill_export_',
    );
    final zip = await service.exportZip(skill.record.id, outDir);
    if (!context.mounted) return;
    String? publicStorageNotice;
    NotificationType? publicStorageNoticeType;
    if (Platform.isAndroid) {
      try {
        final copied = await KelivoPublicStorageService().exportFile(
          sourcePath: zip.path,
          relativePath: 'Skills-Exports/${skill.record.id}.zip',
          overwrite: true,
        );
        if (copied != null) {
          publicStorageNotice = l10n.kelivoPublicStorageSkillExportCopied;
          publicStorageNoticeType = NotificationType.success;
        }
      } catch (_) {
        publicStorageNotice = l10n.kelivoPublicStorageSkillExportCopyFailed;
        publicStorageNoticeType = NotificationType.error;
      }
    }
    if (publicStorageNotice != null && context.mounted) {
      showAppSnackBar(
        context,
        message: publicStorageNotice,
        type: publicStorageNoticeType ?? NotificationType.info,
      );
    }
    final savePath = await saveHostFileWithPicker(
      file: zip,
      fileName: '${skill.record.id}.zip',
      dialogTitle: l10n.skillsExport,
    );
    if (savePath == null || !context.mounted) return;
    showAppSnackBar(
      context,
      message: l10n.messageExportSheetExportedAs(p.basename(savePath)),
      type: NotificationType.success,
    );
  } catch (error) {
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      message: skillErrorMessage(error),
      type: NotificationType.error,
    );
  }
}

Future<void> deleteSkill(
  BuildContext context,
  Skill skill, {
  bool popAfter = false,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showWorkspaceConfirm(
    context: context,
    title: l10n.skillsDeleteTitle,
    message: l10n.skillsDeleteMessage(skill.name),
    confirmLabel: l10n.skillsDelete,
    destructive: true,
  );
  if (!confirmed || !context.mounted) return;
  await context.read<SkillsService>().delete(skill.record.id);
  if (popAfter && context.mounted) Navigator.of(context).maybePop();
}

Future<void> showSkillItemActions(
  BuildContext context,
  Skill skill, {
  Offset? anchor,
  bool popAfterDelete = false,
}) {
  final l10n = AppLocalizations.of(context)!;
  final canUpdate = context.read<SkillsService>().canUpdateSkill(skill.record.id);
  return showAdaptiveActionMenu(
    context,
    anchor: anchor ?? DesktopMenuAnchor.positionOrCenter(context),
    items: [
      if (!canUpdate)
        ActionSheetItem(
          icon: Lucide.Link2,
          label: l10n.skillsLinkUpdateSource,
          onTap: () => unawaited(showSkillUpdateSourceDialog(context, skill)),
        ),
      ActionSheetItem(
        icon: Lucide.FolderOpen,
        label: l10n.skillsBrowseFiles,
        onTap: () => unawaited(browseSkillFiles(context, skill)),
      ),
      ActionSheetItem(
        icon: Lucide.Pencil,
        label: l10n.skillsEdit,
        onTap: () => unawaited(editSkillBody(context, skill)),
      ),
      ActionSheetItem(
        icon: Lucide.Share2,
        label: l10n.skillsExport,
        onTap: () => unawaited(exportSkill(context, skill)),
      ),
      ActionSheetItem(
        icon: Lucide.Trash2,
        label: l10n.skillsDelete,
        destructive: true,
        onTap: () =>
            unawaited(deleteSkill(context, skill, popAfter: popAfterDelete)),
      ),
    ],
  );
}

class SkillDetailPage extends StatelessWidget {
  const SkillDetailPage({super.key, required this.skillId});

  final String skillId;

  @override
  Widget build(BuildContext context) {
    return SkillDetailView(skillId: skillId);
  }
}

class SkillDetailView extends StatelessWidget {
  const SkillDetailView({
    super.key,
    required this.skillId,
    this.dialog = false,
  });

  final String skillId;
  final bool dialog;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final service = context.watch<SkillsService>();
    Skill? skill;
    for (final item in service.skills) {
      if (item.record.id == skillId) {
        skill = item;
        break;
      }
    }
    if (skill == null) {
      return Center(
        child: Text(
          l10n.skillsEmptyTitle,
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      );
    }
    final current = skill;
    final body = _SkillDetailBody(
      key: ValueKey(current.skillMdPath),
      skill: current,
    );

    if (dialog) {
      return Column(
        children: [
          AppDialogHeader(
            title: current.name,
            actions: [
              _SkillEnabledSwitch(skill: current),
              _SkillMoreButton(skill: current, popAfterDelete: true),
            ],
          ),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        leading: Tooltip(
          message: l10n.settingsPageBackButton,
          child: IosIconButton(
            icon: Lucide.directionalBack(context),
            color: cs.onSurface,
            size: 22,
            minSize: 44,
            semanticLabel: l10n.settingsPageBackButton,
            onTap: () {
              Haptics.light();
              Navigator.of(context).maybePop();
            },
          ),
        ),
        title: Text(current.name),
        actions: [
          _SkillEnabledSwitch(skill: current),
          _SkillMoreButton(skill: current, popAfterDelete: true),
          const SizedBox(width: 8),
        ],
      ),
      body: body,
    );
  }
}

class _SkillEnabledSwitch extends StatelessWidget {
  const _SkillEnabledSwitch({required this.skill});

  final Skill skill;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final service = context.watch<SkillsService>();
    return Tooltip(
      message: l10n.skillsEnabled,
      child: IosSwitch(
        key: SkillsKeys.enable(skill.record.id),
        value: skill.record.enabled,
        semanticLabel: l10n.skillsEnabled,
        onChanged: (value) {
          unawaited(
            service.setEnabled(skill.record.id, value),
          );
        },
      ),
    );
  }
}

class _SkillMoreButton extends StatelessWidget {
  const _SkillMoreButton({required this.skill, required this.popAfterDelete});

  final Skill skill;
  final bool popAfterDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: l10n.skillsMoreActions,
      child: IosIconButton(
        key: SkillsKeys.more,
        icon: Lucide.Ellipsis,
        size: 22,
        minSize: 44,
        color: cs.onSurface,
        semanticLabel: l10n.skillsMoreActions,
        onTap: () {
          Haptics.light();
          final box = context.findRenderObject() as RenderBox?;
          final anchor = (box != null && box.hasSize)
              ? box.localToGlobal(Offset.zero)
              : DesktopMenuAnchor.positionOrCenter(context);
          unawaited(
            showSkillItemActions(
              context,
              skill,
              anchor: anchor,
              popAfterDelete: popAfterDelete,
            ),
          );
        },
      ),
    );
  }
}

/// Markdown body of a SKILL.md with YAML frontmatter removed.
String skillDetailMarkdownBody(String raw) {
  return SkillFrontmatter.parse(raw).body.trim();
}

class _SkillDetailBody extends StatefulWidget {
  const _SkillDetailBody({super.key, required this.skill});

  final Skill skill;

  @override
  State<_SkillDetailBody> createState() => _SkillDetailBodyState();
}

class _SkillDetailBodyState extends State<_SkillDetailBody> {
  static const _previewMaxBytes = 100 * 1024;

  (int, DateTime, DateTime)? _fileVersion;
  int _loadGeneration = 0;
  bool _loading = true;
  bool _missing = false;
  String? _body;
  int? _largeFileBytes;

  Skill get skill => widget.skill;

  @override
  void initState() {
    super.initState();
    unawaited(_loadBody());
  }

  @override
  void didUpdateWidget(covariant _SkillDetailBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A rescan can discover file edits without changing Skill metadata.
    unawaited(_loadBody());
  }

  Future<void> _loadBody() async {
    final generation = ++_loadGeneration;
    try {
      final file = File(skill.skillMdPath);
      final stat = await file.stat();
      if (!mounted || generation != _loadGeneration) return;
      if (stat.type != FileSystemEntityType.file) {
        throw FileSystemException('Skill file is not available', file.path);
      }
      final version = (stat.size, stat.modified, stat.changed);
      // Metadata-only changes may replace Skill without changing its file.
      if (_fileVersion == version) return;

      String? body;
      int? largeFileBytes;
      if (stat.size > _previewMaxBytes) {
        largeFileBytes = stat.size;
      } else {
        // Bound the read too, in case the file grows after the size check.
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in file.openRead(0, _previewMaxBytes + 1)) {
          bytes.add(chunk);
        }
        if (bytes.length > _previewMaxBytes) {
          final currentSize = await file.length();
          largeFileBytes = currentSize > bytes.length
              ? currentSize
              : bytes.length;
        } else {
          body = skillDetailMarkdownBody(utf8.decode(bytes.takeBytes()));
        }
      }
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _fileVersion = version;
        _loading = false;
        _missing = false;
        _body = body;
        _largeFileBytes = largeFileBytes;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _fileVersion = null;
        _loading = false;
        _missing = true;
        _body = null;
        _largeFileBytes = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final body = _body;
    final largeFileBytes = _largeFileBytes;
    final description = skill.description.trim();

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Lucide.WandSparkles,
                size: 22,
                color: cs.onSurface.withValues(alpha: 0.9),
              ),
              const SizedBox(height: 10),
              Text(
                skill.name,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: AppFontWeights.semibold,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.skillsDetailKindLabel,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: cs.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                l10n.skillsUsedCount(skill.record.useCount),
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
        _SkillReadinessPanel(skill: skill),
        if (_loading)
          const Padding(
            key: SkillsKeys.bodyLoading,
            padding: EdgeInsets.symmetric(vertical: 48),
            child: PreviewLoading(),
          )
        else if (_missing)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                l10n.workspaceFileNotAvailable,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          )
        else if (largeFileBytes != null)
          _SkillBodyHint(
            key: SkillsKeys.bodyTooLarge,
            label: l10n.skillsDetailBodyTooLarge(formatBytes(largeFileBytes)),
          )
        else if (body == null || body.isEmpty)
          _SkillBodyHint(
            key: SkillsKeys.bodyEmpty,
            label: l10n.skillsDetailBodyEmpty,
          )
        else
          SectionCard(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: AppSelectionArea(
              child: MarkdownWithCodeHighlight(
                text: body,
                useBlockRendering: true,
                baseStyle: const TextStyle(fontSize: 15, height: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}

class _SkillReadinessPanel extends StatefulWidget {
  const _SkillReadinessPanel({required this.skill});

  final Skill skill;

  @override
  State<_SkillReadinessPanel> createState() => _SkillReadinessPanelState();
}

class _SkillReadinessPanelState extends State<_SkillReadinessPanel> {
  Map<String, Object?>? _assessment;
  bool _loading = true;
  bool _checking = false;
  String? _error;

  bool get _arabic => Localizations.localeOf(context).languageCode == 'ar';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant _SkillReadinessPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.skill.record.id != widget.skill.record.id) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report = await context.read<SkillsService>()
          .getImportReportWithRequirements(widget.skill.record.id);
      final stored = report?['environmentAssessment'];
      if (!mounted) return;
      setState(() {
        _assessment = stored is Map ? Map<String, Object?>.from(stored) : null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.runtimeType.toString();
        _loading = false;
      });
    }
  }

  Future<void> _check() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final service = context.read<SkillsService>();
      final importReport = await service.getImportReportWithRequirements(widget.skill.record.id);
      if (importReport == null) throw StateError('skill_import_report_missing');
      EnvironmentProvider? environment;
      WorkspaceRuntime? runtime;
      try {
        environment = context.read<EnvironmentProvider>();
        runtime = await context.read<WorkspaceRuntimeProvider>()
            .ensureInitialized(timeout: const Duration(seconds: 8));
      } catch (_) {
        // A report without a ready runtime remains useful and records unknown
        // states instead of guessing that requirements are available.
      }
      final assessment = await SkillEnvironmentRequirementProbe.assess(
        importReport: importReport,
        runtime: runtime,
        environment: environment,
      );
      final sourceDigest = importReport['sourceDigest']?.toString();
      if (sourceDigest != null) assessment['sourceDigest'] = sourceDigest;
      await service.saveEnvironmentAssessment(widget.skill.record.id, assessment);
      if (!mounted) return;
      setState(() => _assessment = assessment);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.runtimeType.toString());
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _showReport() async {
    final assessment = _assessment;
    if (assessment == null) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_arabic ? 'تقرير جاهزية المهارة' : 'Skill readiness report'),
        content: SizedBox(
          width: 680,
          child: SingleChildScrollView(
            child: SelectableText(
              SkillEnvironmentRequirementProbe.toMarkdown(assessment, arabic: _arabic),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(_arabic ? 'إغلاق' : 'Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCapabilityRegistry() async {
    final catalog = SkillCapabilityRegistry.catalogJson();
    final entries = (catalog['capabilities'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .toList(growable: false);
    String implementationLabel(String value) => _arabic ? switch (value) {
      'implemented' => 'مدمج في KELIVO',
      'implemented_conditional' => 'مدمج بشروط: ملف تشغيل وموافقة',
      'environment_dependent' => 'يعتمد على بيئة التشغيل والتحقق منها',
      'manual_adapter_required' => 'يحتاج إلى موائم وإعداد يدوي',
      'adapter_required' => 'يحتاج إلى تطوير/ربط موائم',
      'requires_kelivo_development' => 'يتطلب تطويراً داخل KELIVO',
      _ => 'غير معروف',
    } : value;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_arabic ? 'سجل قدرات KELIVO' : 'Kelivo Capability Registry'),
        content: SizedBox(
          width: 680,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_arabic
                    ? 'هذا السجل يصف قدرات التطبيق نفسه، ولا يتغير بمجرد تثبيت Skill أو Skill Pack.'
                    : 'This catalog describes app-level capabilities. Installing a Skill or Skill Pack does not add application capabilities.'),
                const SizedBox(height: 12),
                for (final entry in entries) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry['title']?.toString() ?? entry['id']?.toString() ?? 'Unknown'),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(implementationLabel(entry['implementation']?.toString() ?? 'unknown')),
                          const SizedBox(height: 3),
                          Text(entry['scope']?.toString() ?? '', style: Theme.of(dialogContext).textTheme.bodySmall),
                          Text(entry['id']?.toString() ?? '', style: Theme.of(dialogContext).textTheme.labelSmall),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(_arabic ? 'إغلاق' : 'Close'),
          ),
        ],
      ),
    );
  }

  String _readinessLevelLabel(String level) => _arabic ? switch (level) {
    'fully_ready' => 'جاهزة بالكامل',
    'ready_for_execution' => 'جاهزة للتنفيذ للقدرات المختبرة فقط',
    'ready_for_guidance' => 'جاهزة للإرشاد',
    _ => 'لم تثبت الجاهزية بعد',
  } : switch (level) {
    'fully_ready' => 'Fully Ready',
    'ready_for_execution' => 'Ready for Execution',
    'ready_for_guidance' => 'Ready for Guidance',
    _ => 'Not Ready',
  };

  String _stateLabel(String state) => _arabic ? switch (state) {
    'ready' => 'جاهزة بالكامل بعد التحقق',
    'ready_for_execution' => 'جاهزة لتنفيذ القدرات التي اجتازت الاختبار فقط',
    'ready_for_instructions' => 'جاهزة للإرشاد من التعليمات',
    'blocked_incomplete_import' => 'محجوبة: ملفات التثبيت غير مكتملة',
    'analysis_required' => 'تحتاج إلى تحليل المتطلبات',
    'requirements_missing' => 'توجد متطلبات مفقودة',
    'unsupported_environment' => 'توجد قدرات غير مدعومة',
    'dependencies_pending' => 'تحتاج إلى تجهيز الاعتماديات',
    'configuration_required' => 'تحتاج إلى إعداد أو تحقق الاتصال',
    'validation_required' => 'تحتاج إلى اختبار ذاتي ناجح',
    'stale_source' => 'التقرير قديم بسبب تغير ملفات المهارة',
    _ => 'لم يتم فحص الجاهزية بعد',
  } : switch (state) {
    'ready' => 'Fully Ready',
    'ready_for_execution' => 'Ready for Execution (validated capabilities only)',
    'ready_for_instructions' => 'Ready for Guidance',
    _ => state,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = _assessment?['readinessState']?.toString() ?? 'not_checked';
    final readinessLevelId = _assessment?['readinessLevel']?.toString() ?? 'not_ready';
    final readinessLevel = _readinessLevelLabel(readinessLevelId);
    final showStateDetail = !const {'ready', 'ready_for_execution', 'ready_for_instructions'}.contains(state);
    final stages = _assessment?['readinessStages'];
    final stageValues = stages is Map ? stages.values.whereType<Map>().toList() : <Map>[];
    final complete = stageValues.where((stage) => stage['status'] == 'complete').length;
    final partial = stageValues.where((stage) => stage['status'] == 'partial').length;
    final progress = stageValues.isEmpty ? null : (complete + partial * 0.5) / stageValues.length;
    final color = readinessLevelId == 'fully_ready'
        ? Colors.green
        : readinessLevelId == 'ready_for_guidance' || readinessLevelId == 'ready_for_execution'
            ? cs.primary
            : state == 'blocked_incomplete_import' || state == 'requirements_missing' || state == 'unsupported_environment'
                ? cs.error
                : cs.tertiary;
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.health_and_safety_outlined, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _arabic ? 'جاهزية المهارة وقدرات KELIVO' : 'Skill readiness & Kelivo capabilities',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (_loading || _checking)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            readinessLevel,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
          if (showStateDetail) ...[
            const SizedBox(height: 3),
            Text(
              _stateLabel(state),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
          if (progress != null) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 4),
            Text(
              _arabic ? '$complete من ${stageValues.length} مراحل مكتملة' : '$complete of ${stageValues.length} stages complete',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (_assessment?['readinessNextActions'] is List) ...[
            const SizedBox(height: 6),
            for (final action in (_assessment!['readinessNextActions'] as List).whereType<String>())
              Text('• $action', style: Theme.of(context).textTheme.bodySmall),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _arabic ? 'تعذر فحص الجاهزية: $_error' : 'Readiness check failed: $_error',
                style: TextStyle(color: cs.error),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton.icon(
                onPressed: _checking ? null : _check,
                icon: const Icon(Icons.fact_check_outlined, size: 18),
                label: Text(_arabic ? 'فحص الجاهزية الآن' : 'Check readiness'),
              ),
              if (_assessment != null)
                TextButton.icon(
                  onPressed: _showReport,
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: Text(_arabic ? 'التقرير الكامل' : 'Full report'),
                ),
              TextButton.icon(
                onPressed: _showCapabilityRegistry,
                icon: const Icon(Icons.hub_outlined, size: 18),
                label: Text(_arabic ? 'قدرات KELIVO' : 'Kelivo capabilities'),
              ),
            ],
          ),
          Text(
            _arabic
                ? 'يمكن استخدام التعليمات للإرشاد. التنفيذ يقتصر على القدرات التي اجتازت اختباراً موثقاً داخل بيئتها، أما الجاهزية الكاملة فتتطلب اجتياز جميع القدرات الإلزامية.'
                : 'Guidance may be available before execution. Only individually tested capabilities may run; Fully Ready requires every mandatory capability to pass.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _SkillBodyHint extends StatelessWidget {
  const _SkillBodyHint({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Icon(
            Lucide.FileText,
            size: 44,
            color: cs.onSurface.withValues(alpha: 0.26),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: AppFontWeights.semibold,
              color: cs.onSurface.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> browseSkillFiles(BuildContext context, Skill skill) async {
  final l10n = AppLocalizations.of(context)!;
  final cs = Theme.of(context).colorScheme;
  final browser = FileBrowser(
    root: Directory(skill.dir),
    rootLabel: skill.name,
    modelPathOf: (hostPath) => skillModelPath(skill, hostPath),
  );
  if (useDesktopWorkspaceLayout(context)) {
    final height = MediaQuery.sizeOf(context).height * 0.8;
    await showAppDialog<void>(
      context,
      maxWidth: 720,
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            AppDialogHeader(title: l10n.skillsBrowseFiles),
            Expanded(child: browser),
          ],
        ),
      ),
    );
    return;
  }
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (pageContext) => Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
          leading: Tooltip(
            message: l10n.settingsPageBackButton,
            child: IosIconButton(
              icon: Lucide.directionalBack(context),
              color: cs.onSurface,
              size: 22,
              minSize: 44,
              semanticLabel: l10n.settingsPageBackButton,
              onTap: () {
                Haptics.light();
                Navigator.of(pageContext).maybePop();
              },
            ),
          ),
          title: Text(l10n.skillsBrowseFiles),
        ),
        body: browser,
      ),
    ),
  );
}
