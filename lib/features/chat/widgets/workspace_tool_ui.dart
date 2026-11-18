import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/extensions/extension_command_tools.dart';
import 'package:Kelivo/core/services/extensions/skill_composition_tools.dart';
import 'package:Kelivo/core/services/extensions/skill_execution_tools.dart';
import 'package:Kelivo/core/services/packages/package_manager_tools.dart';
import 'package:Kelivo/core/services/video_engines/video_engine_tools.dart';
import 'package:Kelivo/core/services/video_production/video_production_tools.dart';
import 'package:Kelivo/core/services/video_providers/video_provider_tools.dart';
import 'package:Kelivo/core/services/video_hybrid/video_hybrid_workflow_tools.dart';
import 'package:Kelivo/core/services/video_quality/video_quality_tools.dart';
import 'package:Kelivo/core/services/workspace/shell_output_buffer.dart';
import 'package:Kelivo/core/services/workspace/tool_run_registry.dart';
import 'package:Kelivo/core/services/workspace/workspace_tools_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/features/settings/widgets/custom_theme_widgets.dart';
import 'package:Kelivo/features/workspace/workspace_file_navigation.dart';
import 'package:Kelivo/features/workspace/workspace_layout.dart';
import 'package:Kelivo/features/workspace/workspace_navigation.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_form_text_field.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/ios_tile_button.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';
import 'package:Kelivo/utils/mcp_structured_image.dart';

import 'chat_surface.dart';
import 'tool_permission_widgets.dart';

export 'package:Kelivo/features/workspace/workspace_file_navigation.dart';

/// Snapshot of a tool call used by workspace cards and the detail sheet.
class WorkspaceToolPart {
  const WorkspaceToolPart({
    required this.id,
    required this.toolName,
    this.arguments = const <String, dynamic>{},
    this.content,
    this.metadata,
    this.loading = false,
  });

  final String id;
  final String toolName;
  final Map<String, dynamic> arguments;
  final String? content;
  final Map<String, dynamic>? metadata;
  final bool loading;
}

bool isWorkspaceToolName(String name) =>
    WorkspaceToolsService.toolNames.contains(name) ||
    ExtensionCommandToolNames.all.contains(name) ||
    name == SkillCompositionToolNames.compose ||
    SkillExecutionToolNames.all.contains(name) ||
    PackageManagerToolNames.all.contains(name) ||
    VideoEngineToolNames.all.contains(name) ||
    VideoProductionToolNames.all.contains(name) ||
    VideoProviderToolNames.all.contains(name) ||
    VideoHybridWorkflowToolNames.all.contains(name) ||
    VideoQualityToolNames.all.contains(name);

/// True when this part should use workspace tool chrome. Routed by tool
/// name in every state (pending, running, done, error, and after reload)
/// so a missing `metadata['workspace']` wrapper cannot fall back to
/// "调用工具: …".
bool shouldUseWorkspaceToolUi(WorkspaceToolPart part) =>
    isWorkspaceToolName(part.toolName);

(String, String, String, String) _skillExecutionSecurityWarningCopy(
  Locale locale,
) {
  if (locale.languageCode == 'ar') {
    return (
      'تحذير أمني مهم قبل تشغيل المهارة',
      'RootFS النشط في PRoot مشترك وقابل للكتابة. قد يغيّر السكربت ملفات النظام والحزم المثبتة ويؤثر في التشغيلات اللاحقة.',
      'اتصال الشبكة غير مقيّد، وPRoot ليس عزلًا أمنيًا على مستوى النواة. وافق فقط إذا كنت تثق بمصدر المهارة.',
      'تُشغّل نسخة مؤقتة؛ لا تُركّب شجرة Skills المثبتة أو ملفات المحادثة أو مجلد Workspace مباشرة، ولا تُمرر متغيرات Runtime Profile المخصصة.',
    );
  }
  if (locale.languageCode == 'zh') {
    if (locale.scriptCode == 'Hant' || locale.countryCode == 'TW' || locale.countryCode == 'HK') {
      return (
        '執行技能前的重要安全警告',
        '目前的 PRoot RootFS 是共用且可寫入的。腳本可能修改系統檔案或已安裝套件，並影響後續執行。',
        '網路存取不受限制；PRoot 並非核心層級的安全隔離。只有在信任技能來源時才核准。',
        '技能會在暫存副本中執行；不會直接掛載已安裝的 Skills 樹、聊天檔案或整個 Workspace，也不會傳遞自訂 Runtime Profile 環境變數。',
      );
    }
    return (
      '运行技能前的重要安全警告',
      '当前 PRoot RootFS 是共享且可写入的。脚本可能修改系统文件或已安装软件包，并影响后续运行。',
      '网络访问不受限制；PRoot 并非内核级安全隔离。仅在信任技能来源时批准。',
      '技能在临时副本中运行；不会直接挂载已安装的 Skills 树、聊天文件或整个 Workspace，也不会传递自定义 Runtime Profile 环境变量。',
    );
  }
  return (
    'Important security warning before running this Skill',
    'The active PRoot RootFS is shared and writable. A script may modify system files or installed packages and affect later runs.',
    'Network access is unrestricted, and PRoot is not a kernel-level security sandbox. Approve only if you trust this Skill source.',
    'The Skill runs from a temporary copy; the installed Skills tree, chat files and whole Workspace are not mounted directly, and custom Runtime Profile environment variables are withheld.',
  );
}

WorkspaceToolMetadata? workspaceMetadataFrom(Map<String, dynamic>? metadata) {
  if (metadata == null || metadata.isEmpty) return null;
  return WorkspaceToolMetadata.fromJson(metadata);
}

const Set<String> kWorkspaceImageExtensions = {
  '.png',
  '.jpg',
  '.jpeg',
  '.gif',
  '.webp',
};

const Set<String> _kCodeExtensions = {
  '.dart',
  '.js',
  '.ts',
  '.tsx',
  '.jsx',
  '.py',
  '.rs',
  '.go',
  '.java',
  '.kt',
  '.c',
  '.h',
  '.cpp',
  '.cc',
  '.cs',
  '.swift',
  '.rb',
  '.php',
  '.json',
  '.yaml',
  '.yml',
  '.xml',
  '.html',
  '.css',
  '.sh',
  '.sql',
  '.toml',
};

const Set<String> _kTextExtensions = {
  '.md',
  '.txt',
  '.rst',
  '.rtf',
  '.log',
  '.markdown',
};

const Set<String> _kSpreadsheetExtensions = {'.csv', '.tsv', '.xls', '.xlsx'};

bool isWorkspaceImagePath(String path) {
  final trimmed = path.trim();
  if (trimmed.isEmpty) return false;
  final noQuery = trimmed.split('?').first;
  return kWorkspaceImageExtensions.contains(p.extension(noQuery).toLowerCase());
}

IconData workspaceFileTypeIcon(String path) {
  final ext = p.extension(path.split('?').first).toLowerCase();
  if (kWorkspaceImageExtensions.contains(ext) ||
      ext == '.svg' ||
      ext == '.bmp' ||
      ext == '.heic') {
    return Lucide.FileImage;
  }
  if (_kCodeExtensions.contains(ext)) return Lucide.FileCode;
  if (_kTextExtensions.contains(ext)) return Lucide.FileText;
  if (_kSpreadsheetExtensions.contains(ext)) return Lucide.FileSpreadsheet;
  return Lucide.File;
}

bool workspaceReadWasImage({
  required WorkspaceToolPart part,
  WorkspaceToolMetadata? meta,
}) {
  final raw = part.metadata;
  if (raw != null && raw[kMcpResultMetadataKey] != null) return true;
  final content = part.content ?? '';
  if (content.contains('![](') || content.contains('![')) return true;
  final path = meta?.path ?? (part.arguments['path'] ?? '').toString();
  return isWorkspaceImagePath(path);
}

String workspaceToolTitle(AppLocalizations l10n, String toolName) {
  return switch (toolName) {
    'shell' => l10n.workspaceToolTitleShell,
    'read_file' => l10n.workspaceToolTitleReadFile,
    'view_image' => l10n.workspaceToolTitleViewImage,
    'write_file' => l10n.workspaceToolTitleWriteFile,
    'edit_file' => l10n.workspaceToolTitleEditFile,
    'list_dir' => l10n.workspaceToolTitleListDir,
    'glob' => l10n.workspaceToolTitleGlob,
    'grep' => l10n.workspaceToolTitleGrep,
    ExtensionCommandToolNames.search => 'Search Skills',
    ExtensionCommandToolNames.inspect => 'Inspect Skill',
    ExtensionCommandToolNames.install => 'Install Skill',
    ExtensionCommandToolNames.update => 'Update Skill',
    ExtensionCommandToolNames.enable => 'Enable Skill',
    ExtensionCommandToolNames.disable => 'Disable Skill',
    ExtensionCommandToolNames.remove => 'Remove Skill',
    ExtensionCommandToolNames.rollback => 'Rollback Skill',
    ExtensionCommandToolNames.list => 'Installed Skills',
    SkillCompositionToolNames.compose => 'Plan Skill Composition',
    SkillExecutionToolNames.execute => 'Execute Skill Script',
    PackageManagerToolNames.manage => 'Manage Packages',
    VideoEngineToolNames.manage => 'Manage Video Engines',
    VideoProductionToolNames.manage => 'Manage Video Production',
    VideoProviderToolNames.manage => 'Manage AI Video Providers',
    VideoHybridWorkflowToolNames.manage => 'Compose Hybrid Video Workflow',
    VideoQualityToolNames.manage => 'Review Video Quality',
    _ => toolName,
  };
}

IconData workspaceToolIcon(String toolName) {
  return switch (toolName) {
    'shell' => Lucide.Terminal,
    'read_file' => Lucide.FileText,
    'view_image' => Lucide.Image,
    'write_file' => Lucide.FilePlus,
    'edit_file' => Lucide.FilePen,
    'list_dir' => Lucide.FolderOpen,
    'glob' => Lucide.FileSearch,
    'grep' => Lucide.TextSearch,
    ExtensionCommandToolNames.search => Lucide.Search,
    ExtensionCommandToolNames.inspect => Lucide.FileText,
    ExtensionCommandToolNames.install => Lucide.Download,
    ExtensionCommandToolNames.update => Lucide.RefreshCw,
    ExtensionCommandToolNames.enable => Lucide.CheckCircle,
    ExtensionCommandToolNames.disable => Lucide.Ban,
    ExtensionCommandToolNames.remove => Lucide.Trash2,
    ExtensionCommandToolNames.rollback => Lucide.RotateCcw,
    ExtensionCommandToolNames.list => Lucide.ListTodo,
    SkillCompositionToolNames.compose => Lucide.Layers,
    SkillExecutionToolNames.execute => Lucide.Terminal,
    PackageManagerToolNames.manage => Lucide.Package,
    VideoEngineToolNames.manage => Lucide.FileVideo,
    VideoProductionToolNames.manage => Lucide.FileVideo,
    VideoProviderToolNames.manage => Lucide.KeyRound,
    VideoHybridWorkflowToolNames.manage => Lucide.GitFork,
    VideoQualityToolNames.manage => Lucide.ClipboardCheck,

    _ => Lucide.Wrench,
  };
}

String workspaceCommandOf(
  WorkspaceToolPart part, {
  WorkspaceToolMetadata? meta,
  ToolRun? run,
}) {
  final fromMeta = meta?.command?.trim() ?? '';
  if (fromMeta.isNotEmpty) return fromMeta;
  final fromRun = run?.command?.trim() ?? '';
  if (fromRun.isNotEmpty) return fromRun;
  return (part.arguments['command'] ?? '').toString();
}

String workspacePathOf(WorkspaceToolPart part, {WorkspaceToolMetadata? meta}) {
  final fromMeta = meta?.path?.trim() ?? '';
  if (fromMeta.isNotEmpty) return fromMeta;
  final args = part.arguments;
  final path = (args['path'] ?? '').toString().trim();
  if (path.isNotEmpty) return path;
  return (args['pattern'] ?? '').toString();
}

String workspacePatternOf(WorkspaceToolPart part) {
  return (part.arguments['pattern'] ?? '').toString();
}

int? workspaceWriteLineCount(WorkspaceToolPart part) {
  if (!part.arguments.containsKey('content')) return null;
  final content = part.arguments['content']?.toString() ?? '';
  if (content.isEmpty) return 0;
  return const LineSplitter().convert(content).length;
}

String formatWorkspaceDuration(AppLocalizations l10n, int? durationMs) {
  if (durationMs == null) return '';
  if (durationMs < 1000) {
    return l10n.workspaceToolDurationMs(durationMs);
  }
  final sec = durationMs / 1000;
  final label = sec == sec.roundToDouble()
      ? sec.toStringAsFixed(0)
      : sec.toStringAsFixed(1);
  return l10n.workspaceToolDurationSec(label);
}

int? workspaceDurationMs(WorkspaceToolMetadata? meta, ToolRun? run) {
  if (meta?.durationMs != null) return meta!.durationMs;
  if (run != null && run.status != ToolRunStatus.running) {
    return DateTime.now().difference(run.startedAt).inMilliseconds;
  }
  return null;
}

String? workspaceErrorMessage(
  WorkspaceToolPart part,
  WorkspaceToolMetadata? meta, {
  AppLocalizations? l10n,
}) {
  if (l10n != null) {
    final translated = switch (meta?.code) {
      'path_outside' => l10n.wsDeniedPathOutside,
      'mount_readonly' => l10n.wsDeniedMountReadonly,
      'skills_readonly' => l10n.wsDeniedSkillsReadonly,
      'path_changed' => l10n.wsPathChanged,
      'context_changed' => l10n.wsContextChanged,
      _ => null,
    };
    if (translated != null) return translated;
  }
  final content = part.content?.trim() ?? '';
  if (content.isNotEmpty) {
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map) {
        final message = decoded['message']?.toString().trim() ?? '';
        if (message.isNotEmpty) return message;
      }
    } catch (_) {}
  }
  if (meta?.status == 'error') {
    final code = meta?.code?.trim() ?? '';
    if (code.isNotEmpty) return code;
    if (content.isNotEmpty) return content;
  }
  return null;
}

List<String> workspaceOutputTailLines({
  required WorkspaceToolPart part,
  WorkspaceToolMetadata? meta,
  ToolRun? run,
}) {
  if (run != null) {
    return run.tailLines;
  }
  final preview = part.toolName == 'shell'
      ? [
          workspaceShellOutput(meta: meta),
          workspaceShellOutput(meta: meta, stderr: true),
        ].where((text) => text.isNotEmpty).join('\n')
      : meta?.stdoutPreview ?? '';
  if (preview.isNotEmpty) return const LineSplitter().convert(preview);
  return const <String>[];
}

String workspaceShellOutput({
  WorkspaceToolMetadata? meta,
  ToolRun? run,
  bool stderr = false,
}) {
  if (run != null) return stderr ? run.stderrSoFar : run.stdoutSoFar;
  return ShellOutputBuffer.normalize(
    (stderr ? meta?.stderrPreview : meta?.stdoutPreview) ?? '',
  );
}

Color _workspaceQuietFill(BuildContext context) => chatQuietFill(context);

String workspaceCodeFontFamily(BuildContext context) {
  try {
    final fam = context.watch<SettingsProvider>().codeFontFamily;
    if (fam == null || fam.isEmpty) return 'monospace';
    return fam;
  } on ProviderNotFoundException {
    return 'monospace';
  }
}

T? maybeRead<T>(BuildContext context) {
  try {
    return context.read<T>();
  } on ProviderNotFoundException {
    return null;
  }
}

void showToolApprovalDenyDialog(
  BuildContext context,
  ToolApprovalService approvalService,
  String toolCallId, {
  String? conversationId,
}) {
  final l10n = AppLocalizations.of(context)!;
  unawaited(
    showAppDialog<void>(
      context,
      child: _ToolApprovalDenyDialog(
        title: l10n.toolApprovalDenyTitle,
        hint: l10n.toolApprovalDenyHint,
        cancelLabel: l10n.workspaceToolCancel,
        denyLabel: l10n.workspaceToolDeny,
        onDeny: (reason) {
          approvalService.deny(
            toolCallId,
            reason: reason,
            conversationId: conversationId,
          );
        },
      ),
    ),
  );
}

class _ToolApprovalDenyDialog extends StatefulWidget {
  const _ToolApprovalDenyDialog({
    required this.title,
    required this.hint,
    required this.cancelLabel,
    required this.denyLabel,
    required this.onDeny,
  });

  final String title;
  final String hint;
  final String cancelLabel;
  final String denyLabel;
  final ValueChanged<String?> onDeny;

  @override
  State<_ToolApprovalDenyDialog> createState() =>
      _ToolApprovalDenyDialogState();
}

class _ToolApprovalDenyDialogState extends State<_ToolApprovalDenyDialog> {
  late final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _controller.text.trim();
    widget.onDeny(reason.isEmpty ? null : reason);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 16 + bottomInset),
      child: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: AppFontWeights.emphasis,
              ),
            ),
            const SizedBox(height: 12),
            IosFormTextField(
              label: widget.hint,
              hintText: widget.hint,
              controller: _controller,
              autofocus: true,
              inlineLabel: false,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: IosTileButton(
                    icon: Lucide.X,
                    label: widget.cancelLabel,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: IosTileButton(
                    icon: Lucide.Check,
                    label: widget.denyLabel,
                    onTap: _submit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class WorkspaceFileChip extends StatelessWidget {
  const WorkspaceFileChip({
    super.key,
    required this.path,
    this.link,
    this.conversationId,
    this.displayName,
    this.isDirectory = false,
    this.loading = false,
    this.tags = const <Widget>[],
    this.onTap,
  });

  static const ValueKey<String> chipKey = ValueKey<String>(
    'workspace-tool-file-chip',
  );

  final String path;
  final String? link;
  final String? conversationId;
  final String? displayName;
  final bool isDirectory;
  final bool loading;
  final List<Widget> tags;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = chatSurfaceForegroundPalette(context);
    final name =
        displayName ?? (p.basename(path).isEmpty ? path : p.basename(path));
    final open =
        onTap ??
        ((link == null || link!.isEmpty)
            ? null
            : () {
                unawaited(
                  openWorkspaceLinkedFile(
                    context,
                    link,
                    conversationId: conversationId,
                    title: name,
                  ),
                );
              });
    return Tooltip(
      message: path,
      child: IosCardPress(
        key: chipKey,
        borderRadius: BorderRadius.circular(8),
        baseColor: _workspaceQuietFill(context),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        onTap: open,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isDirectory ? Lucide.Folder : workspaceFileTypeIcon(path),
              size: 14,
              color: fg.muted,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: workspaceCodeFontFamily(context),
                  color: fg.body,
                ),
              ),
            ),
            if (open == null) ...[
              const SizedBox(width: 6),
              Text(
                loading
                    ? AppLocalizations.of(context)!.workspaceToolRunning
                    : AppLocalizations.of(
                        context,
                      )!.workspaceFilePreviewUnavailable,
                style: TextStyle(fontSize: 11, color: fg.muted),
              ),
            ],
            for (final tag in tags) ...[const SizedBox(width: 6), tag],
          ],
        ),
      ),
    );
  }
}

/// Keys for workspace tool status text. The former capsule widget was removed.
abstract final class WorkspaceStatusBadge {
  static const ValueKey<String> exitZeroKey = ValueKey<String>(
    'workspace-tool-badge-exit-zero',
  );
  static const ValueKey<String> exitErrorKey = ValueKey<String>(
    'workspace-tool-badge-exit-error',
  );
  static const ValueKey<String> timeoutKey = ValueKey<String>(
    'workspace-tool-badge-timeout',
  );
  static const ValueKey<String> cancelledKey = ValueKey<String>(
    'workspace-tool-badge-cancelled',
  );
  static const ValueKey<String> interruptedKey = ValueKey<String>(
    'workspace-tool-badge-interrupted',
  );
  static const ValueKey<String> deniedKey = ValueKey<String>(
    'workspace-tool-badge-denied',
  );
  static const ValueKey<String> runningKey = ValueKey<String>(
    'workspace-tool-badge-running',
  );
  static const ValueKey<String> approvalKey = ValueKey<String>(
    'workspace-tool-badge-approval',
  );
  static const ValueKey<String> completedKey = ValueKey<String>(
    'workspace-tool-badge-completed',
  );
}

class WorkspaceAddedRemovedCounts extends StatelessWidget {
  const WorkspaceAddedRemovedCounts({
    super.key,
    required this.added,
    required this.removed,
  });

  final int added;
  final int removed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          key: const ValueKey<String>('workspace-tool-added'),
          '+$added',
          style: TextStyle(
            fontSize: 12,
            fontWeight: AppFontWeights.semibold,
            color: colors.success,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          key: const ValueKey<String>('workspace-tool-removed'),
          '−$removed',
          style: TextStyle(
            fontSize: 12,
            fontWeight: AppFontWeights.semibold,
            color: cs.error,
          ),
        ),
      ],
    );
  }
}

class _WorkspaceToolSummary extends StatelessWidget {
  const _WorkspaceToolSummary({
    required this.part,
    required this.meta,
    required this.run,
  });

  final WorkspaceToolPart part;
  final WorkspaceToolMetadata? meta;
  final ToolRun? run;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fg = chatSurfaceForegroundPalette(context);
    final fontFamily = workspaceCodeFontFamily(context);
    final base = TextStyle(
      fontSize: 12,
      fontWeight: AppFontWeights.regular,
      fontFamily: fontFamily,
      color: fg.body,
    );
    final path = workspacePathOf(part, meta: meta);
    final pattern = workspacePatternOf(part);

    final Widget child;
    switch (part.toolName) {
      case 'shell':
        final command = workspaceCommandOf(part, meta: meta, run: run);
        if (command.isEmpty) return const SizedBox.shrink();
        child = Text(
          command,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: base,
        );
        break;
      case 'write_file':
        final lines = workspaceWriteLineCount(part);
        final text = lines == null
            ? path
            : '$path · ${l10n.workspaceToolLines(lines)}';
        if (text.isEmpty) return const SizedBox.shrink();
        child = Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: base,
        );
        break;
      case 'edit_file':
        final added = meta?.added;
        final removed = meta?.removed;
        if (path.isEmpty && added == null && removed == null) {
          return const SizedBox.shrink();
        }
        child = Text.rich(
          TextSpan(
            style: base,
            children: [
              if (path.isNotEmpty) TextSpan(text: path),
              if (path.isNotEmpty && (added != null || removed != null))
                const TextSpan(text: ' · '),
              if (added != null) TextSpan(text: '+$added'),
              if (added != null && removed != null) const TextSpan(text: ' '),
              if (removed != null) TextSpan(text: '−$removed'),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
        break;
      case 'list_dir':
        final count = meta?.count;
        final text = count == null
            ? path
            : '$path · ${l10n.workspaceToolItems(count)}';
        if (text.isEmpty) return const SizedBox.shrink();
        child = Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: base,
        );
        break;
      case 'glob':
        final count = meta?.count;
        final text = count == null
            ? pattern
            : '$pattern · ${l10n.workspaceToolFileMatches(count)}';
        if (text.isEmpty) return const SizedBox.shrink();
        child = Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: base,
        );
        break;
      case 'grep':
        final count = meta?.count;
        final text = count == null
            ? pattern
            : '$pattern · ${l10n.workspaceToolContentMatches(count)}';
        if (text.isEmpty) return const SizedBox.shrink();
        child = Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: base,
        );
        break;
      case ExtensionCommandToolNames.search:
        final query = (part.arguments['query'] ?? '').toString();
        child = Text(
          'Search: $query',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: base,
        );
        break;
      case ExtensionCommandToolNames.inspect:
      case ExtensionCommandToolNames.install:
      case ExtensionCommandToolNames.update:
      case ExtensionCommandToolNames.enable:
      case ExtensionCommandToolNames.disable:
      case ExtensionCommandToolNames.remove:
      case ExtensionCommandToolNames.rollback:
        final target = (part.arguments['id'] ?? part.arguments['source'] ?? '')
            .toString();
        final label = target.isEmpty ? 'Skill operation' : target;
        child = Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: base,
        );
        break;
      case PackageManagerToolNames.manage:
        final action = (part.arguments['action'] ?? 'plan').toString();
        final package = (part.arguments['package'] ??
                (part.arguments['packages'] is List
                    ? (part.arguments['packages'] as List).join(', ')
                    : ''))
            .toString();
        final text = package.isEmpty ? action : '$action · $package';
        child = Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: base);
        break;
      case SkillCompositionToolNames.compose:
        final task = (part.arguments['task'] ?? '').toString().trim();
        child = Text(
          task.isEmpty ? 'Plan selected Skills' : task,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: base,
        );
        break;
      case ExtensionCommandToolNames.list:
        child = Text(
          'Show all Skills',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: base,
        );
        break;
      default:
        if (path.isEmpty) return const SizedBox.shrink();
        child = Text(
          path,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: base,
        );
        break;
    }
    return child;
  }
}

/// Header extra: exit / denied / timeout plus duration, joined with ` · `.
class WorkspaceToolStatusText extends StatelessWidget {
  const WorkspaceToolStatusText({
    super.key,
    required this.part,
    this.conversationId,
    this.run,
  });

  final WorkspaceToolPart part;
  final String? conversationId;
  final ToolRun? run;

  @override
  Widget build(BuildContext context) {
    ToolRun? liveRun = run;
    if (liveRun == null) {
      try {
        liveRun = context.watch<ToolRunRegistry>().of(
          part.id,
          conversationId: conversationId,
        );
      } on ProviderNotFoundException {
        liveRun = null;
      }
    }
    final resolved = liveRun;
    if (resolved != null && run == null) {
      return ListenableBuilder(
        listenable: resolved,
        builder: (context, _) => _buildStatus(context, resolved),
      );
    }
    return _buildStatus(context, resolved);
  }

  Widget _buildStatus(BuildContext context, ToolRun? liveRun) {
    final approval = maybeRead<ToolApprovalService>(context);
    ToolApprovalRequest? pending;
    if (approval != null) {
      try {
        pending = context.select<ToolApprovalService, ToolApprovalRequest?>(
          (service) => service.pendingFor(
            toolCallId: part.id,
            conversationId: conversationId,
          ),
        );
      } on ProviderNotFoundException {
        pending = approval.pendingFor(
          toolCallId: part.id,
          conversationId: conversationId,
        );
      }
    }
    final meta = workspaceMetadataFrom(part.metadata);
    final liveRunning =
        liveRun != null && liveRun.status == ToolRunStatus.running;
    final finishedStatus = meta?.status;
    final isRunning =
        liveRunning ||
        (part.loading &&
            pending == null &&
            (finishedStatus == null || finishedStatus.isEmpty));
    if (pending != null || isRunning) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final fg = chatSurfaceForegroundPalette(context);

    final denied = meta?.status == 'denied';
    final timedOut =
        meta?.timedOut == true ||
        meta?.status == 'timeout' ||
        liveRun?.status == ToolRunStatus.timedOut;
    final cancelled =
        meta?.cancelled == true ||
        meta?.status == 'cancelled' ||
        liveRun?.status == ToolRunStatus.cancelled;
    final interrupted =
        meta?.interrupted == true || meta?.status == 'interrupted';
    final exitCode = meta?.exitCode ?? liveRun?.exitCode;

    String? label;
    Color color = fg.muted;
    Key? key;
    if (denied) {
      label = l10n.workspaceToolDenied;
      color = cs.error;
      key = WorkspaceStatusBadge.deniedKey;
    } else if (timedOut) {
      label = l10n.workspaceToolTimeout;
      color = colors.warning;
      key = WorkspaceStatusBadge.timeoutKey;
    } else if (cancelled) {
      label = l10n.workspaceToolCancelled;
      color = cs.error;
      key = WorkspaceStatusBadge.cancelledKey;
    } else if (interrupted) {
      label = l10n.workspaceToolInterrupted;
      color = colors.warning;
      key = WorkspaceStatusBadge.interruptedKey;
    } else if (part.toolName == 'shell' && exitCode != null) {
      label = l10n.workspaceToolExitCode(exitCode);
      final ok = exitCode == 0;
      color = ok ? fg.muted : cs.error;
      key = ok
          ? WorkspaceStatusBadge.exitZeroKey
          : WorkspaceStatusBadge.exitErrorKey;
    } else if (meta?.status == 'error' ||
        liveRun?.status == ToolRunStatus.failed) {
      label = l10n.workspaceToolSectionError;
      color = cs.error;
    } else if (ExtensionCommandToolNames.all.contains(part.toolName) &&
        liveRun?.status == ToolRunStatus.succeeded) {
      label = 'Completed';
      color = colors.success;
      key = WorkspaceStatusBadge.completedKey;
    }

    final duration = formatWorkspaceDuration(
      l10n,
      workspaceDurationMs(meta, liveRun),
    );
    if ((label == null || (part.toolName == 'shell' && exitCode == 0)) &&
        part.metadata?['toolPermission'] == 'fullAccess') {
      label = l10n.toolApprovalByFullAccess;
    }
    final pieces = <String>[
      if (label != null) label,
      if (duration.isNotEmpty) duration,
    ];
    if (pieces.isEmpty) return const SizedBox.shrink();
    return Text(
      key: key,
      pieces.join(' · '),
      style: TextStyle(fontSize: 12, color: color),
    );
  }
}

/// Inline workspace tool body under the timeline (or flat-card) title.
class WorkspaceToolCardBody extends StatelessWidget {
  const WorkspaceToolCardBody({
    super.key,
    required this.part,
    required this.conversationId,
    this.run,
  });

  static const ValueKey<String> installButtonKey = ValueKey<String>(
    'workspace-tool-install',
  );
  static const ValueKey<String> fullAccessKey = ValueKey<String>(
    'workspace-tool-full-access',
  );

  final WorkspaceToolPart part;
  final String conversationId;
  final ToolRun? run;

  @override
  Widget build(BuildContext context) {
    ToolRun? liveRun = run;
    if (liveRun == null) {
      try {
        liveRun = context.watch<ToolRunRegistry>().of(
          part.id,
          conversationId: conversationId,
        );
      } on ProviderNotFoundException {
        liveRun = null;
      }
    }
    final resolvedRun = liveRun;
    if (resolvedRun != null) {
      return ListenableBuilder(
        listenable: resolvedRun,
        builder: (context, _) => _buildBody(context, resolvedRun),
      );
    }
    return _buildBody(context, resolvedRun);
  }

  Widget _buildBody(BuildContext context, ToolRun? liveRun) {
    final meta = workspaceMetadataFrom(part.metadata);
    final approval = maybeRead<ToolApprovalService>(context);
    ToolApprovalRequest? pending;
    if (approval != null) {
      try {
        pending = context.select<ToolApprovalService, ToolApprovalRequest?>(
          (service) => service.pendingFor(
            toolCallId: part.id,
            conversationId: conversationId,
          ),
        );
      } on ProviderNotFoundException {
        pending = approval.pendingFor(
          toolCallId: part.id,
          conversationId: conversationId,
        );
      }
    }
    final error = (meta?.status == 'denied' || meta?.status == 'error')
        ? workspaceErrorMessage(part, meta, l10n: AppLocalizations.of(context))
        : null;
    final extra = pending == null ? _extra(context, liveRun, meta) : null;
    final showEnv =
        meta?.status == 'error' && meta?.code == 'environment_not_ready';
    final summary = pending == null && part.toolName != 'view_image'
        ? _WorkspaceToolSummary(part: part, meta: meta, run: liveRun)
        : null;
    final pendingBlock = pending == null
        ? null
        : _WorkspacePendingBody(
            part: part,
            meta: meta,
            run: liveRun,
            request: pending,
            conversationId: conversationId,
          );
    if (summary == null &&
        pendingBlock == null &&
        extra == null &&
        !showEnv &&
        error == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pendingBlock != null) pendingBlock,
        if (error != null)
          Text(
            error,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        if (summary != null) summary,
        if (extra != null) ...[const SizedBox(height: 6), extra],
        if (showEnv) ...[
          const SizedBox(height: 6),
          _EnvironmentNotice(
            onInstall: () => WorkspaceNavigation.openEnvironmentPage(context),
          ).animate().fadeIn(duration: 200.ms),
        ],
      ],
    );
  }

  Widget? _extra(
    BuildContext context,
    ToolRun? liveRun,
    WorkspaceToolMetadata? meta,
  ) {
    switch (part.toolName) {
      case 'shell':
        return _ShellTail(part: part, meta: meta, run: liveRun);
      case 'write_file':
      case 'edit_file':
      case 'read_file':
      case 'list_dir':
      case 'glob':
      case 'grep':
        return _TouchedPathChips(
          part: part,
          meta: meta,
          conversationId: conversationId,
        );
      case ExtensionCommandToolNames.install:
      case ExtensionCommandToolNames.update:
      case ExtensionCommandToolNames.enable:
      case ExtensionCommandToolNames.disable:
      case ExtensionCommandToolNames.remove:
      case ExtensionCommandToolNames.rollback:
        return _ExtensionOperationOutput(run: liveRun, content: part.content);
      case SkillCompositionToolNames.compose:
        return _SkillCompositionPlanOutput(content: part.content);
      case PackageManagerToolNames.manage:
        return _PackageManagerOutput(content: part.content);
      default:
        return null;
    }
  }
}

class _PackageManagerOutput extends StatelessWidget {
  const _PackageManagerOutput({this.content});

  final String? content;

  @override
  Widget build(BuildContext context) {
    final raw = content?.trim() ?? '';
    if (raw.isEmpty) return const SizedBox.shrink();
    Map<String, dynamic> result;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException('invalid result');
      result = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return Text(raw, maxLines: 6, overflow: TextOverflow.ellipsis);
    }
    final ok = result['ok'] == true;
    final action = (result['action'] ?? 'package operation').toString();
    final manager = (result['manager'] ?? '').toString();
    final scope = (result['scope'] ?? '').toString();
    final packages = result['packages'];
    final names = packages is List
        ? packages.map((item) {
            if (item is Map) return (item['name'] ?? '').toString();
            return item.toString();
          }).where((name) => name.isNotEmpty).take(8).join(', ')
        : '';
    final warnings = result['compatibilityWarnings'];
    final color = ok
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(ok ? Lucide.CheckCircle : Lucide.TriangleAlert, size: 14, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${ok ? 'Package operation ready' : 'Package operation failed'} · $action',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
              ),
            ),
          ],
        ),
        if (manager.isNotEmpty || scope.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('$manager${scope.isEmpty ? '' : ' · $scope'}',
              style: const TextStyle(fontSize: 11)),
        ],
        if (names.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(names, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11)),
        ],
        if (warnings is List && warnings.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('${warnings.length} compatibility warning(s)',
              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.error)),
        ],
      ],
    );
  }
}

class _SkillCompositionPlanOutput extends StatelessWidget {
  const _SkillCompositionPlanOutput({this.content});

  final String? content;

  @override
  Widget build(BuildContext context) {
    final raw = content?.trim() ?? '';
    if (raw.isEmpty) return const SizedBox.shrink();

    Map<String, dynamic> plan;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException('invalid plan');
      plan = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return Text(
        raw,
        maxLines: 8,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      );
    }

    final selected = (plan['selectedSkillIds'] as List? ?? const [])
        .whereType<String>()
        .toList(growable: false);
    final stages = (plan['executionStages'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
    final reasons = plan['selectionReasons'] is Map
        ? Map<String, dynamic>.from(plan['selectionReasons'] as Map)
        : const <String, dynamic>{};
    final issues = (plan['issues'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
    final budget = plan['contextBudget'] is Map
        ? Map<String, dynamic>.from(plan['contextBudget'] as Map)
        : const <String, dynamic>{};
    final status = (plan['status'] ?? 'unknown').toString();
    final cs = Theme.of(context).colorScheme;
    final fg = chatSurfaceForegroundPalette(context);
    final statusColor = status == 'blocked'
        ? cs.error
        : status == 'ready'
        ? context.appColors.success
        : context.appColors.warning;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _workspaceQuietFill(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Lucide.Layers, size: 14, color: statusColor),
              const SizedBox(width: 6),
              Text(
                status.replaceAll('_', ' ').toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: AppFontWeights.semibold,
                ),
              ),
              const Spacer(),
              if (budget['estimatedInstructionTokens'] is num &&
                  budget['budgetTokens'] is num)
                Text(
                  '~${budget['estimatedInstructionTokens']} / ${budget['budgetTokens']} tokens',
                  style: TextStyle(color: fg.muted, fontSize: 10),
                ),
            ],
          ),
          if (selected.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Selected Skills',
              style: TextStyle(
                color: fg.body,
                fontSize: 11,
                fontWeight: AppFontWeights.semibold,
              ),
            ),
            const SizedBox(height: 4),
            for (final id in selected)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      id,
                      style: TextStyle(
                        color: fg.body,
                        fontSize: 12,
                        fontWeight: AppFontWeights.medium,
                      ),
                    ),
                    if (reasons[id] is String)
                      Text(
                        reasons[id] as String,
                        style: TextStyle(color: fg.muted, fontSize: 11),
                      ),
                  ],
                ),
              ),
          ],
          if (stages.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Execution stages',
              style: TextStyle(
                color: fg.body,
                fontSize: 11,
                fontWeight: AppFontWeights.semibold,
              ),
            ),
            const SizedBox(height: 4),
            for (final stage in stages)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  'Stage ${stage['stage']}: ${(stage['skillIds'] as List? ?? const []).join(', ')}${stage['parallel'] == true ? ' · parallel' : ''}',
                  style: TextStyle(color: fg.body, fontSize: 11),
                ),
              ),
          ],
          for (final issue in issues)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                '${(issue['severity'] ?? 'info').toString().toUpperCase()}: ${issue['message'] ?? issue['code'] ?? 'Composition issue'}',
                style: TextStyle(
                  color: issue['severity'] == 'error' ? cs.error : fg.muted,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExtensionOperationOutput extends StatelessWidget {
  const _ExtensionOperationOutput({this.run, this.content});

  final ToolRun? run;
  final String? content;

  @override
  Widget build(BuildContext context) {
    final runOutput = run?.stdoutSoFar ?? '';
    final raw = (runOutput.isNotEmpty ? runOutput : content ?? '').trim();
    if (raw.isEmpty) return const SizedBox.shrink();
    final lines = raw.split('\n');
    final visible = lines.length > 8 ? lines.sublist(lines.length - 8) : lines;
    final fg = chatSurfaceForegroundPalette(context);
    final running = run?.status == ToolRunStatus.running;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _workspaceQuietFill(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (running) ...[
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 7),
          ],
          Text(
            visible.join('\n'),
            maxLines: 8,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              height: 1.35,
              fontFamily: workspaceCodeFontFamily(context),
              color: fg.body,
            ),
          ),
        ],
      ),
    );
  }
}

class _EnvironmentNotice extends StatelessWidget {
  const _EnvironmentNotice({required this.onInstall});

  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fg = chatSurfaceForegroundPalette(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.workspaceToolEnvironmentNotReady,
            style: TextStyle(fontSize: 12, height: 1.35, color: fg.body),
          ),
        ),
        const SizedBox(width: 8),
        IosTileButton(
          key: WorkspaceToolCardBody.installButtonKey,
          icon: Lucide.Download,
          label: l10n.workspaceToolInstall,
          backgroundColor: fg.accent,
          onTap: onInstall,
        ),
      ],
    );
  }
}

class _WorkspacePendingBody extends StatelessWidget {
  const _WorkspacePendingBody({
    required this.part,
    required this.meta,
    required this.run,
    required this.request,
    required this.conversationId,
  });

  final WorkspaceToolPart part;
  final WorkspaceToolMetadata? meta;
  final ToolRun? run;
  final ToolApprovalRequest request;
  final String conversationId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final fg = chatSurfaceForegroundPalette(context);
    final securityWarning = _skillExecutionSecurityWarningCopy(
      Localizations.localeOf(context),
    );
    final preview = part.toolName == 'shell'
        ? workspaceCommandOf(part, meta: meta, run: run)
        : workspacePathOf(part, meta: meta);
    return Column(
      key: WorkspaceStatusBadge.approvalKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (preview.isNotEmpty)
          Text(
            preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontFamily: workspaceCodeFontFamily(context),
              color: fg.body,
            ),
          ),
        if (part.toolName == SkillExecutionToolNames.execute) ...[
          DecoratedBox(
            decoration: BoxDecoration(
              color: cs.errorContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 17,
                        color: cs.onErrorContainer,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          securityWarning.$1,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: AppFontWeights.semibold,
                            color: cs.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    securityWarning.$2,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: cs.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    securityWarning.$3,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: cs.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    securityWarning.$4,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: cs.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (request.realTarget != null &&
            request.realTarget != request.requestedPath) ...[
          Text(
            '${l10n.toolApprovalRequestedPath}: ${request.requestedPath}',
            style: TextStyle(fontSize: 12, color: fg.body),
          ),
          Text(
            '${l10n.toolApprovalRealTarget}: ${request.realTarget}',
            style: TextStyle(fontSize: 12, color: fg.body),
          ),
        ],
        if (['list_dir', 'glob', 'grep'].contains(part.toolName))
          Text(
            l10n.toolApprovalScopeOnce,
            style: TextStyle(fontSize: 12, color: fg.muted),
          ),
        if (part.toolName != SkillExecutionToolNames.execute)
          SwitchToFullAccess(
            key: WorkspaceToolCardBody.fullAccessKey,
            conversationId: conversationId,
          ),
      ],
    );
  }
}

class _ShellTail extends StatelessWidget {
  const _ShellTail({required this.part, required this.meta, required this.run});

  final WorkspaceToolPart part;
  final WorkspaceToolMetadata? meta;
  final ToolRun? run;

  @override
  Widget build(BuildContext context) {
    final lines = workspaceOutputTailLines(part: part, meta: meta, run: run);
    if (lines.isEmpty) return const SizedBox.shrink();
    final last = lines.length <= 4 ? lines : lines.sublist(lines.length - 4);
    final fg = chatSurfaceForegroundPalette(context);
    return Text(
      last.join('\n'),
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 12,
        height: 1.4,
        fontFamily: workspaceCodeFontFamily(context),
        color: fg.body,
      ),
    );
  }
}

class _TouchedPathChips extends StatelessWidget {
  const _TouchedPathChips({
    required this.part,
    required this.meta,
    required this.conversationId,
  });

  final WorkspaceToolPart part;
  final WorkspaceToolMetadata? meta;
  final String conversationId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final files = meta?.files ?? const <WorkspaceToolFile>[];
    if (files.isEmpty) {
      final path = workspacePathOf(part, meta: meta);
      if (path.isEmpty ||
          !{'read_file', 'write_file', 'edit_file'}.contains(part.toolName)) {
        return const SizedBox.shrink();
      }
      return WorkspaceFileChip(path: path, loading: part.loading);
    }
    const limit = 3;
    final visible = files.take(limit).toList();
    final overflow = files.length - visible.length;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final file in visible)
          WorkspaceFileChip(
            path: file.path,
            link: file.link,
            isDirectory: file.isDirectory,
            conversationId: conversationId,
          ),
        if (overflow > 0)
          IosCardPress(
            borderRadius: BorderRadius.circular(8),
            baseColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            onTap: () => unawaited(
              showWorkspaceFileList(
                context,
                files: files,
                conversationId: conversationId,
                title: l10n.workspaceToolRelatedFiles,
              ),
            ),
            child: Text(
              l10n.workspaceToolMoreFiles(overflow),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        if (meta?.filesTruncated == true)
          Text(
            l10n.workspaceToolFilesTruncated,
            style: TextStyle(
              fontSize: 12,
              color: chatSurfaceForegroundPalette(context).muted,
            ),
          ),
      ],
    );
  }
}

Future<void> showWorkspaceFileList(
  BuildContext context, {
  required List<WorkspaceToolFile> files,
  required String title,
  String? conversationId,
}) {
  final list = ListView.separated(
    padding: const EdgeInsets.all(16),
    itemCount: files.length,
    separatorBuilder: (_, _) => const SizedBox(height: 8),
    itemBuilder: (_, index) {
      final file = files[index];
      return Align(
        alignment: Alignment.centerLeft,
        child: WorkspaceFileChip(
          path: file.path,
          displayName: file.path,
          link: file.link,
          isDirectory: file.isDirectory,
          conversationId: conversationId,
        ),
      );
    },
  );
  if (useDesktopWorkspaceLayout(context)) {
    return showAppDialog<void>(
      context,
      maxWidth: 760,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Column(
          children: [
            AppDialogHeader(title: title),
            Expanded(child: list),
          ],
        ),
      ),
    );
  }
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: Text(title),
          leading: IosIconButton(
            icon: Lucide.directionalBack(context),
            semanticLabel: AppLocalizations.of(context)!.workspacePreviewBack,
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
        body: list,
      ),
    ),
  );
}
