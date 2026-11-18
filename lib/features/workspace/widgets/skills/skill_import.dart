import 'dart:async';

import 'package:Kelivo/core/services/haptics.dart';
import 'package:Kelivo/core/services/skills/skills_service.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/services/skills/skill_requirements.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/desktop/menu_anchor.dart';
import 'package:Kelivo/features/settings/widgets/custom_theme_widgets.dart';
import 'package:Kelivo/features/workspace/widgets/skills/skill_labels.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/features/workspace/workspace_layout.dart';
import 'package:Kelivo/shared/utils/format_bytes.dart';
import 'package:Kelivo/shared/widgets/action_sheet.dart';
import 'package:Kelivo/shared/widgets/animated_progress_bar.dart';
import 'package:Kelivo/shared/widgets/form_sheet.dart';
import 'package:Kelivo/shared/widgets/ios_form_text_field.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/section_card.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:Kelivo/shared/utils/file_picker_compat.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum SkillImportKind { paste, file, github, skillsCatalog, githubPrivateAccess }

Future<void> startSkillImport(
  BuildContext context, {
  GlobalKey? anchorKey,
}) async {
  final kind = await showSkillImportMenu(context, anchorKey: anchorKey);
  if (kind == null || !context.mounted) return;
  await runSkillImport(context, kind);
}

Future<void> runSkillImport(BuildContext context, SkillImportKind kind) async {
  switch (kind) {
    case SkillImportKind.paste:
      await showSkillPasteImport(context);
    case SkillImportKind.file:
      await importSkillFromFile(context);
    case SkillImportKind.github:
      await showSkillGitHubImport(context);
    case SkillImportKind.skillsCatalog:
      await showSkillsCatalogSearch(context);
    case SkillImportKind.githubPrivateAccess:
      await showGitHubPrivateAccessDialog(context);
  }
}

Offset _menuAnchor(BuildContext context, GlobalKey? anchorKey) {
  final box = anchorKey?.currentContext?.findRenderObject() as RenderBox?;
  if (box != null && box.hasSize) {
    return box.localToGlobal(Offset.zero);
  }
  return DesktopMenuAnchor.positionOrCenter(context);
}

Future<SkillImportKind?> showSkillImportMenu(
  BuildContext context, {
  GlobalKey? anchorKey,
}) async {
  final l10n = AppLocalizations.of(context)!;
  SkillImportKind? selected;
  await showAdaptiveActionMenu(
    context,
    anchor: _menuAnchor(context, anchorKey),
    items: [
      ActionSheetItem(
        icon: Lucide.ClipboardPaste,
        label: l10n.skillsImportPaste,
        onTap: () => selected = SkillImportKind.paste,
      ),
      ActionSheetItem(
        icon: Lucide.FileUp,
        label: l10n.skillsImportFile,
        onTap: () => selected = SkillImportKind.file,
      ),
      ActionSheetItem(
        icon: Lucide.GitFork,
        label: l10n.skillsImportGitHub,
        onTap: () => selected = SkillImportKind.github,
      ),
      ActionSheetItem(
        icon: Lucide.Search,
        label: Localizations.localeOf(context).languageCode == 'zh'
            ? '从 skills.sh 目录导入'
            : 'Browse skills.sh catalog',
        onTap: () => selected = SkillImportKind.skillsCatalog,
      ),
      ActionSheetItem(
        icon: Lucide.KeyRound,
        label: Localizations.localeOf(context).languageCode == 'zh'
            ? '管理私有 GitHub 访问'
            : 'Private GitHub access',
        onTap: () => selected = SkillImportKind.githubPrivateAccess,
      ),
    ],
  );
  return selected;
}

Future<void> importSkillFromFile(BuildContext context) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['md', 'skill', 'zip'],
  );
  final path = result?.files.single.path;
  if (path == null || !context.mounted) return;
  try {
    final service = context.read<SkillsService>();
    final imported = await service.importSkillsFromFile(
      path,
      chooseSkills: (candidates) => _chooseGitHubSkills(context, candidates),
    );
    if (context.mounted && imported.isNotEmpty) {
      await _showSkillImportReports(context, service, imported);
    }
  } catch (error) {
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      message: skillErrorMessage(error),
      type: NotificationType.error,
    );
  }
}

Future<bool> showSkillPasteImport(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showSkillTextImport(
    context: context,
    title: l10n.skillsImportPaste,
    label: l10n.skillsImportPasteLabel,
    hint: l10n.skillsImportPasteHint,
    confirmLabel: l10n.skillsImportConfirm,
    minLines: 8,
    maxLines: 16,
    onSubmit: (markdown) async {
      final service = context.read<SkillsService>();
      final imported = await service.importFromText(markdown);
      if (context.mounted) {
        await _showSkillImportReports(context, service, [imported]);
      }
    },
  );
}

Future<bool> showSkillGitHubImport(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final service = context.read<SkillsService>();
  final progress = ValueNotifier<SkillImportProgress?>(null);
  final cancel = Completer<void>();
  try {
    List<Skill> importedSkills = const <Skill>[];
    final completed = await showSkillTextImport(
      context: context,
      title: l10n.skillsImportGitHub,
      label: l10n.skillsImportGitHubRepoLabel,
      hint: l10n.skillsImportGitHubUrlHint,
      confirmLabel: l10n.skillsImportConfirm,
      minLines: 1,
      maxLines: 1,
      keyboardType: TextInputType.url,
      progress: progress,
      onSubmit: (url) async {
        importedSkills = await service.importFromGitHubRepository(
          url.trim(),
          cancelSignal: cancel.future,
          onProgress: (value) {
            if (!cancel.isCompleted) progress.value = value;
          },
          chooseSkills: (candidates) => _chooseGitHubSkills(
            context,
            candidates,
          ),
        );
      },
    );
    if (completed && context.mounted && importedSkills.isNotEmpty) {
      await _showSkillImportReports(context, service, importedSkills);
    }
    return completed;
  } finally {
    cancel.complete();
    progress.dispose();
  }
}

Future<Set<String>?> _chooseGitHubSkills(
  BuildContext context,
  List<SkillImportCandidate> candidates,
) async {
  final importable = candidates
      .where((candidate) => candidate.compatibility.isImportable)
      .map((candidate) => candidate.path)
      .toSet();
  final selected = Set<String>.from(importable);
  final isChinese = Localizations.localeOf(context).languageCode == 'zh';
  return showDialog<Set<String>>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        final allSelected = selected.length == importable.length &&
            importable.isNotEmpty;
        return AlertDialog(
          title: Text(isChinese ? '选择要导入的 Skills' : 'Choose Skills to import'),
          content: SizedBox(
            width: 560,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: allSelected ? true : selected.isEmpty ? false : null,
                    tristate: true,
                    title: Text(isChinese ? '选择所有兼容的 Skills' : 'Select all compatible Skills'),
                    onChanged: importable.isEmpty
                        ? null
                        : (value) => setState(() {
                            if (value == true) {
                              selected
                                ..clear()
                                ..addAll(importable);
                            } else {
                              selected.clear();
                            }
                          }),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: candidates.length,
                      itemBuilder: (context, index) {
                        final candidate = candidates[index];
                        final compatible = candidate.compatibility.isImportable;
                        final warnings = candidate.compatibility.warnings;
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: selected.contains(candidate.path),
                          onChanged: compatible
                              ? (value) => setState(() {
                                  if (value == true) {
                                    selected.add(candidate.path);
                                  } else {
                                    selected.remove(candidate.path);
                                  }
                                })
                              : null,
                          title: Text(candidate.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${candidate.path} · ${candidate.fileCount} files'),
                              if (candidate.sharedFileCount > 0)
                                Text('Shared repository assets: ${candidate.sharedFileCount} · ${formatBytes(candidate.sharedBytes)} (stored separately)'),
                              if (candidate.description.isNotEmpty)
                                Text(candidate.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                              if (candidate.license != null)
                                Text('License: ${candidate.license}'),
                              if (candidate.environmentCompatibility != null)
                                Text('Environment: ${candidate.environmentCompatibility}'),
                              if (candidate.metadata.isNotEmpty)
                                Text('Metadata: ${candidate.metadata.entries.map((entry) => '${entry.key}=${entry.value}').join(', ')}'),
                              if (candidate.allowedTools != null)
                                Text('Experimental allowed-tools hint (not permission): ${candidate.allowedTools}'),
                              if (candidate.bodyPreview.isNotEmpty)
                                Text(
                                  candidate.bodyPreview,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              if (warnings.isNotEmpty)
                                Text(
                                  warnings.join(' '),
                                  style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
                                ),
                              if (!compatible)
                                Text(
                                  candidate.compatibility.errors.join(' · '),
                                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(isChinese ? '取消' : 'Cancel'),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.of(dialogContext).pop(Set.unmodifiable(selected)),
              child: Text(isChinese ? '导入 (${selected.length})' : 'Import (${selected.length})'),
            ),
          ],
        );
      },
    ),
  );
}

Future<void> showSkillsCatalogSearch(BuildContext context) async {
  final service = context.read<SkillsService>();
  final languageCode = Localizations.localeOf(context).languageCode;
  final isChinese = languageCode == 'zh';
  final isArabic = languageCode == 'ar';
  final queryController = TextEditingController();
  SkillCatalogEntry? selected;
  try {
    selected = await showDialog<SkillCatalogEntry>(
      context: context,
      builder: (dialogContext) {
        var loading = false;
        var entries = <SkillCatalogEntry>[];
        String? error;
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> search() async {
              final query = queryController.text.trim();
              if (query.length < 2 || loading) return;
              setState(() {
                loading = true;
                error = null;
              });
              try {
                final result = await service.searchSkillsCatalog(query);
                if (!dialogContext.mounted) return;
                setState(() => entries = result);
              } catch (exception) {
                if (!dialogContext.mounted) return;
                setState(() => error = skillErrorMessage(exception));
              } finally {
                if (dialogContext.mounted) {
                  setState(() => loading = false);
                }
              }
            }

            return AlertDialog(
              title: Text(isChinese ? '探索 skills.sh' : 'Explore skills.sh'),
              content: SizedBox(
                width: 560,
                height: 480,
                child: Column(
                  children: [
                    TextField(
                      controller: queryController,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => search(),
                      decoration: InputDecoration(
                        hintText: isChinese ? '搜索 Skill' : 'Search Skills',
                        suffixIcon: IconButton(
                          icon: const Icon(Lucide.Search),
                          onPressed: loading ? null : search,
                        ),
                      ),
                    ),
                    if (loading) const LinearProgressIndicator(),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: entries.isEmpty
                          ? Center(
                              child: Text(
                                isChinese
                                    ? '按名称或描述搜索'
                                    : 'Search by Skill name or description',
                              ),
                            )
                          : ListView.separated(
                              itemCount: entries.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final entry = entries[index];
                                return ListTile(
                                  title: Text(entry.name),
                                  subtitle: Text(
                                    '${entry.source} · ${entry.installs} installs\n'
                                    '${entry.description}',
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  isThreeLine: true,
                                  onTap: () => Navigator.of(dialogContext)
                                      .pop(entry),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(isChinese ? '关闭' : isArabic ? 'إغلاق' : 'Close'),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    queryController.dispose();
  }
  final entry = selected;
  if (entry == null || !context.mounted) return;
  try {
    // Resolve and validate the package before presenting a confirmation. A
    // catalog listing is discovery metadata, not proof of Skill conformance.
    final preview = await service.inspectSkillsCatalog(entry.id);
    if (!context.mounted) return;
    final rawCompatibility = preview['compatibility'];
    final compatibility = rawCompatibility is Map
        ? Map<String, Object?>.from(rawCompatibility)
        : const <String, Object?>{};
    final importable = compatibility['isImportable'] == true;
    final warnings = (compatibility['warnings'] as List? ?? const [])
        .whereType<String>()
        .toList(growable: false);
    final errors = (compatibility['errors'] as List? ?? const [])
        .whereType<String>()
        .toList(growable: false);
    final bodyPreview = preview['bodyPreview']?.toString() ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isChinese ? '审核技能' : 'Review Skill'),
        content: SizedBox(
          width: 560,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 520),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(entry.name, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(entry.description),
                  if (preview['license'] != null)
                    Text('License: ${preview['license']}'),
                  if (preview['compatibilityRequirements'] != null)
                    Text('Environment: ${preview['compatibilityRequirements']}'),
                  if (preview['metadata'] is Map &&
                      (preview['metadata'] as Map).isNotEmpty)
                    Text('Metadata: ${(preview['metadata'] as Map).entries.map((item) => '${item.key}=${item.value}').join(', ')}'),
                  if (preview['allowedToolsHint'] != null)
                    Text('Experimental allowed-tools hint (not permission): ${preview['allowedToolsHint']}'),
                  const SizedBox(height: 8),
                  Text(
                    isChinese
                        ? '${preview['fileCount'] ?? 0} 个文件 · ${preview['scriptCount'] ?? 0} 个脚本'
                        : '${preview['fileCount'] ?? 0} files · ${preview['scriptCount'] ?? 0} scripts',
                  ),
                  if (warnings.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      warnings.join('\n'),
                      style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
                    ),
                  ],
                  if (errors.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      errors.join('\n'),
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  if (bodyPreview.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      isChinese ? 'SKILL.md 预览' : 'SKILL.md preview',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    SelectableText(bodyPreview),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    isChinese
                        ? 'واجهة skills.sh النصية لا تنقل الملفات الثنائية. سيحاول Kelivo تنزيل أرشيف GitHub الكامل؛ وإذا تعذّر ذلك فسيعرض تقرير الاستيراد العناصر غير المتحققة ولن يعتبرها مكتملة.'
                        : 'The skills.sh API is text-only and cannot transfer binary assets. Kelivo will try the full GitHub archive; if unavailable, the import report will mark the snapshot unverified rather than complete.',
                    style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
                  ),
                  Text(
                    isChinese
                        ? '导入时不会运行 scripts，也不会安装任何依赖项。'
                        : 'Scripts will not be executed and dependencies will not be installed during import.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(isChinese ? '取消' : 'Cancel'),
          ),
          FilledButton(
            onPressed: importable
                ? () => Navigator.of(dialogContext).pop(true)
                : null,
            child: Text(isChinese ? '安装技能' : 'Install Skill'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final imported = await service.importFromSkillsCatalog(entry.id);
    if (!context.mounted) return;
    await _showSkillImportReports(context, service, [imported]);
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      message: isChinese ? '已安装 ${entry.name}' : 'Installed ${entry.name}',
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

Future<void> _showSkillImportReports(
  BuildContext context,
  SkillsService service,
  List<Skill> skills,
) async {
  WorkspaceRuntime? runtime;
  EnvironmentProvider? environment;
  try {
    environment = context.read<EnvironmentProvider>();
    runtime = await context
        .read<WorkspaceRuntimeProvider>()
        .ensureInitialized(timeout: const Duration(seconds: 8));
  } catch (_) {
    // The report remains useful without a ready runtime; live command status
    // will be shown as not checked rather than guessed.
  }
  final reports = <({
    Skill skill,
    Map<String, Object?>? report,
    Map<String, Object?>? requirements,
  })>[];
  for (final skill in skills) {
    final report = await service.getImportReportWithRequirements(skill.record.id);
    final requirements = report == null
        ? null
        : await SkillEnvironmentRequirementProbe.assess(
            importReport: report,
            runtime: runtime,
            environment: environment,
          );
    if (requirements != null) {
      final sourceDigest = report?['sourceDigest']?.toString();
      if (sourceDigest != null) requirements['sourceDigest'] = sourceDigest;
      await service.saveEnvironmentAssessment(skill.record.id, requirements);
    }
    reports.add((skill: skill, report: report, requirements: requirements));
  }
  if (!context.mounted) return;
  final languageCode = Localizations.localeOf(context).languageCode;
  final isChinese = languageCode == 'zh';
  final isArabic = languageCode == 'ar';
  String localized(String chinese, String arabic, String english) =>
      isChinese ? chinese : isArabic ? arabic : english;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(isChinese ? '导入报告' : isArabic ? 'تقرير تثبيت المهارة' : 'Skill import report'),
      content: SizedBox(
        width: 600,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 560),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in reports) ...[
                  Text(item.skill.name, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  if (item.report == null)
                    Text(localized('未找到可用的导入清单。', 'لا يتوفر سجل تثبيت لهذه المهارة.', 'No import manifest is available.')),
                  if (item.report != null) ...[
                    Builder(builder: (context) {
                      final report = item.report!;
                      final files = (report['files'] as List? ?? const [])
                          .whereType<Map>()
                          .toList(growable: false);
                      final skipped = (report['skipped'] as List? ?? const [])
                          .whereType<Map>()
                          .toList(growable: false);
                      final capabilities = (report['capabilities'] as List? ?? const [])
                          .whereType<Map>()
                          .map((entry) => entry['kind']?.toString() ?? '')
                          .where((value) => value.isNotEmpty)
                          .toSet()
                          .toList()..sort();
                      final dependencies = (report['dependencies'] as List? ?? const [])
                          .whereType<Map>()
                          .toList(growable: false);
                      final source = report['source'] is Map
                          ? report['source'] as Map
                          : const <Object?, Object?>{};
                      final totalBytes = files.fold<int>(0, (sum, entry) =>
                          sum + ((entry['sizeBytes'] as num?)?.toInt() ?? 0));
                      final savedSummary = files.take(40).map((entry) =>
                          '${entry['path'] ?? '?'} · ${formatBytes((entry['sizeBytes'] as num?)?.toInt() ?? 0)} · ${entry['mediaType'] ?? 'unknown'}').join('\n');
                      final safePackages = (item.requirements?['packages'] as List? ?? const [])
                          .whereType<Map>()
                          .toList(growable: false);
                      final dependencySummary = safePackages.map((entry) =>
                        '${entry['manifestPath'] ?? '?'} (${entry['ecosystem'] ?? 'unknown'}): ${entry['declaration'] ?? entry['name'] ?? '?'}'
                      ).take(80).join('\n');
                      final notes = (report['completenessNotes'] as List? ?? const [])
                          .whereType<String>()
                          .toList(growable: false);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${localized("完整度", "الاكتمال", "Completeness")}: ${report['completeness'] ?? 'unknown'} · ${files.length} ${localized("ملف", "ملف", "files")} · ${formatBytes(totalBytes)}'),
                          if (capabilities.isNotEmpty)
                            Text('${localized('发现能力', 'القدرات المكتشفة', 'Capabilities')}: ${capabilities.join(', ')}'),
                          if (source.isNotEmpty)
                            Text('${localized('来源', 'المصدر', 'Source')}: ${source['type'] ?? 'unknown'} · ${source['repository'] ?? source['url'] ?? ''} · ${source['commit'] ?? source['ref'] ?? ''}'),
                          if (files.isNotEmpty) ...[
                            Text('${localized('已保存文件', 'الملفات المحفوظة', 'Saved files')} (${files.length})'),
                            SelectableText(savedSummary + (files.length > 40 ? '\n… ${files.length - 40} more files in manifest' : '')),
                          ],
                          Text('${localized('依赖清单', 'بيانات الاعتماديات', 'Dependency manifests')}: ${dependencies.length}'),
                          if (dependencySummary.isNotEmpty)
                            SelectableText(dependencySummary),
                          if (skipped.isNotEmpty)
                            Text('${localized('已跳过', 'العناصر المتخطاة', 'Skipped')}: ${skipped.length}'),
                          if (notes.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(notes.join('\n'), style: TextStyle(color: Theme.of(context).colorScheme.tertiary)),
                            ),
                          if (item.requirements != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: SelectableText(
                                SkillEnvironmentRequirementProbe.toMarkdown(
                                  item.requirements!,
                                  arabic: isArabic,
                                ),
                              ),
                            ),
                          if (skipped.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(skipped.take(30).map((entry) =>
                                '${entry['path'] ?? '?'} — ${entry['reason'] ?? 'skipped'}').join('\n'),
                                style: TextStyle(color: Theme.of(context).colorScheme.error),
                              ),
                            ),
                          const SizedBox(height: 6),
                          SelectableText('${localized('源指纹', 'بصمة المصدر', 'Source digest')}: ${report['sourceDigest'] ?? 'unknown'}'),
                        ],
                      );
                    }),
                  ],
                  const Divider(height: 22),
                ],
                Text(
                  isChinese
                      ? '导入不会执行 scripts、启动 MCP 服务器、调用 API 或安装依赖。'
                      : isArabic
                          ? 'التثبيت لا يشغّل السكريبتات أو خوادم MCP، ولا يتصل بواجهات API أو يثبت الاعتماديات.'
                          : 'Import does not execute scripts, start MCP servers, call APIs, or install dependencies.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(isChinese ? '关闭' : isArabic ? 'إغلاق' : 'Close'),
        ),
      ],
    ),
  );
}

Future<void> showGitHubPrivateAccessDialog(BuildContext context) async {
  final service = context.read<SkillsService>();
  final isChinese = Localizations.localeOf(context).languageCode == 'zh';
  final controller = TextEditingController();
  var hasToken = false;
  var checking = true;
  try {
    hasToken = await service.hasGitHubPrivateAccess();
    checking = false;
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isChinese ? '私有 GitHub 仓库访问' : 'Private GitHub repository access'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isChinese
                      ? '输入对目标仓库具有 Contents: Read-only 权限的 Fine-grained Personal Access Token。验证通过后将加密保存在本机。'
                      : 'Enter a fine-grained Personal Access Token with Contents: Read-only access to the required repositories. It is verified before being stored in encrypted device storage.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  obscureText: true,
                  onChanged: (_) => setState(() {}),
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: isChinese ? 'GitHub token' : 'GitHub token',
                    hintText: 'github_pat_…',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  checking
                      ? (isChinese ? '正在验证…' : 'Checking…')
                      : hasToken
                          ? (isChinese ? '本机已安全保存访问令牌。' : 'A token is securely stored on this device.')
                          : (isChinese ? '当前没有保存访问令牌。' : 'No token is stored.'),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          actions: [
            if (hasToken)
              TextButton(
                onPressed: () async {
                  await service.clearGitHubPrivateAccess();
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                },
                child: Text(isChinese ? '移除令牌' : 'Remove token'),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(isChinese ? '取消' : 'Cancel'),
            ),
            FilledButton(
              onPressed: controller.text.trim().isEmpty
                  ? null
                  : () async {
                      try {
                        await service.saveGitHubPrivateAccessToken(controller.text);
                        if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                        if (context.mounted) {
                          showAppSnackBar(
                            context,
                            message: isChinese ? '令牌已验证并安全保存。' : 'Token verified and securely stored.',
                            type: NotificationType.success,
                          );
                        }
                      } catch (error) {
                        if (!dialogContext.mounted) return;
                        showAppSnackBar(
                          dialogContext,
                          message: skillErrorMessage(error),
                          type: NotificationType.error,
                        );
                      }
                    },
              child: Text(isChinese ? '验证并保存' : 'Verify & save'),
            ),
          ],
        ),
      ),
    );
  } finally {
    controller.dispose();
  }
}

Future<bool> showSkillTextImport({
  required BuildContext context,
  required String title,
  required String label,
  required String hint,
  required String confirmLabel,
  int maxLines = 8,
  int? minLines,
  String initial = '',
  TextInputType? keyboardType,
  ValueListenable<SkillImportProgress?>? progress,
  required Future<void> Function(String text) onSubmit,
}) async {
  final form = SkillTextImportForm(
    title: title,
    label: label,
    hint: hint,
    confirmLabel: confirmLabel,
    maxLines: maxLines,
    minLines: minLines,
    initial: initial,
    keyboardType: keyboardType,
    progress: progress,
    onSubmit: onSubmit,
  );

  if (useDesktopWorkspaceLayout(context)) {
    final result = await showAppDialog<bool>(
      context,
      maxWidth: 520,
      child: form,
    );
    return result == true;
  }
  final result = await showFormSheet<bool>(context, builder: (_) => form);
  return result == true;
}

class SkillTextImportForm extends StatefulWidget {
  const SkillTextImportForm({
    super.key,
    required this.title,
    required this.label,
    required this.hint,
    required this.confirmLabel,
    required this.onSubmit,
    this.maxLines = 8,
    this.minLines,
    this.initial = '',
    this.keyboardType,
    this.progress,
  });

  final String title;
  final String label;
  final String hint;
  final String confirmLabel;
  final int maxLines;
  final int? minLines;
  final String initial;
  final TextInputType? keyboardType;
  final ValueListenable<SkillImportProgress?>? progress;
  final Future<void> Function(String text) onSubmit;

  @override
  State<SkillTextImportForm> createState() => _SkillTextImportFormState();
}

class _SkillTextImportFormState extends State<SkillTextImportForm> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );
  String? _error;
  bool _busy = false;

  int get _maxLines => widget.maxLines < 1 ? 1 : widget.maxLines;

  int get _minLines {
    final requested = widget.minLines ?? (_maxLines <= 1 ? 1 : 8);
    if (requested < 1) return 1;
    return requested > _maxLines ? _maxLines : requested;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text;
    if (text.trim().isEmpty || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(text);
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = skillErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final fields = SectionCard(
      children: [
        IosFormTextField(
          label: widget.label,
          controller: _controller,
          hintText: widget.hint,
          inlineLabel: false,
          maxLines: _maxLines,
          minLines: _minLines,
          autofocus: true,
          enabled: !_busy,
          keyboardType: widget.keyboardType,
          textInputAction: _maxLines <= 1
              ? TextInputAction.done
              : TextInputAction.newline,
        ),
        if (_busy && widget.progress != null)
          ValueListenableBuilder<SkillImportProgress?>(
            valueListenable: widget.progress!,
            builder: (context, progress, _) => progress == null
                ? const SizedBox.shrink()
                : _SkillImportProgressView(progress: progress),
          ),
        if (_error != null)
          Padding(
            key: SkillsKeys.importError,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Text(
              _error!,
              style: TextStyle(color: cs.error, fontSize: 13, height: 1.35),
            ),
          ),
      ],
    );
    final actions = FormSheetActions(
      key: SkillsKeys.importSubmit,
      cancelLabel: l10n.skillsCancel,
      confirmLabel: widget.confirmLabel,
      onCancel: () => Navigator.of(context).pop(false),
      onConfirm: _busy ? null : _submit,
      busy: _busy,
    );

    if (useDesktopWorkspaceLayout(context)) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppDialogHeader(title: widget.title),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.65,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: fields,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: actions,
          ),
        ],
      );
    }

    return FormSheet(title: widget.title, actions: actions, children: [fields]);
  }
}

class _SkillImportProgressView extends StatelessWidget {
  const _SkillImportProgressView({required this.progress});

  final SkillImportProgress progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = switch (progress.phase) {
      SkillImportPhase.resolving => l10n.skillsImportResolving,
      SkillImportPhase.downloading => l10n.skillsImportDownloading,
      SkillImportPhase.extracting => l10n.skillsImportExtracting,
      SkillImportPhase.installing => l10n.skillsImportInstalling,
    };
    final fraction = progress.fraction;
    final total = progress.totalBytes;
    final size = total != null && total > 0
        ? '${formatBytes(progress.receivedBytes)} / ${formatBytes(total)}'
        : formatBytes(progress.receivedBytes);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 13)),
              ),
              if (fraction != null)
                Text(
                  '${(fraction * 100).floor()}%',
                  style: const TextStyle(fontSize: 13),
                ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedProgressBar(fraction: fraction),
          if (progress.phase == SkillImportPhase.downloading) ...[
            const SizedBox(height: 6),
            Text(
              size,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// AppBar / pane ＋ that opens the import menu (anchored on desktop).
class SkillsImportPlusButton extends StatefulWidget {
  const SkillsImportPlusButton({
    super.key,
    this.size = 22,
    this.minSize = 44,
    this.color,
  });

  final double size;
  final double? minSize;
  final Color? color;

  @override
  State<SkillsImportPlusButton> createState() => _SkillsImportPlusButtonState();
}

class _SkillsImportPlusButtonState extends State<SkillsImportPlusButton> {
  final GlobalKey _anchorKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Tooltip(
      message: l10n.skillsImportTooltip,
      child: IosIconButton(
        key: _anchorKey,
        icon: Lucide.Plus,
        size: widget.size,
        minSize: widget.minSize,
        color: widget.color,
        semanticLabel: l10n.skillsImportTooltip,
        onTap: () {
          Haptics.light();
          unawaited(startSkillImport(context, anchorKey: _anchorKey));
        },
      ),
    );
  }
}
