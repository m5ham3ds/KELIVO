import 'dart:io';

import 'package:path/path.dart' as p;

import '../../models/workspace.dart';
import '../../models/tool_permission_mode.dart';
import '../../models/workspace_binding.dart';
import 'workspace_paths.dart';
import 'workspace_runtime.dart';

class WorkspaceToolContext {
  const WorkspaceToolContext({
    required this.workspace,
    required this.binding,
    required this.paths,
    required this.sessionDir,
    required this.outputsDir,
    this.conversationId,
    this.assistantId,
    this.permissionMode = ToolPermissionMode.requestApproval,
    this.runtimeStatus,
    this.runtimeRegistered = false,
    this.skillsOnly = false,
    this.conversationScoped = false,
  });

  /// Sandboxed `read_file` over `/skills` when no workspace is bound.
  factory WorkspaceToolContext.skillsOnly({
    required String skillsHostDir,
    String? conversationId,
    String? assistantId,
  }) {
    final placeholder = p.join(
      Directory.systemTemp.path,
      'kelivo-skills-only-unused',
    );
    final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return WorkspaceToolContext(
      workspace: Workspace(
        id: 'skills-only',
        name: '',
        kind: WorkspaceKind.managed,
        createdAt: epoch,
        updatedAt: epoch,
      ),
      binding: const WorkspaceBinding(),
      paths: WorkspacePaths.sandboxed(
        workspaceHostRoot: placeholder,
        sessionHostDir: placeholder,
        skillsHostDir: skillsHostDir,
      ),
      sessionDir: Directory(placeholder),
      outputsDir: Directory(p.join(placeholder, 'outputs')),
      conversationId: conversationId,
      assistantId: assistantId,
      skillsOnly: true,
    );
  }

  final Workspace workspace;
  final WorkspaceBinding binding;
  final WorkspacePaths paths;
  final Directory sessionDir;
  final Directory outputsDir;
  final String? conversationId;
  final String? assistantId;
  final ToolPermissionMode permissionMode;
  final RuntimeStatus? runtimeStatus;
  final bool runtimeRegistered;
  final bool skillsOnly;

  /// True when this is an app-managed per-conversation scratch workspace,
  /// not a user-selected project Workspace.
  final bool conversationScoped;

  /// True only when this context captured a registered Android PRoot runtime
  /// that reported ready and sandboxed. Individual Shell calls re-check the
  /// runtime status immediately before execution.
  bool get hasReadyProotRuntime =>
      runtimeRegistered &&
      runtimeStatus?.ready == true &&
      runtimeStatus?.engine == 'proot' &&
      runtimeStatus?.sandboxed == true &&
      paths.sandboxed;

  String get cwd {
    final raw = binding.cwd.isNotEmpty ? binding.cwd : workspace.defaultCwd;
    return paths.normalizeCwd(raw.isEmpty ? null : raw);
  }
}
