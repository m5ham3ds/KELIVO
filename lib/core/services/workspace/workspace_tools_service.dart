import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../features/home/services/tool_approval_service.dart';
import '../../../utils/app_directories.dart';
import '../../../utils/mcp_structured_image.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../api/tool_call_cancellation.dart';
import '../tool_image.dart';
import '../../models/workspace_binding.dart';
import '../../models/workspace.dart';
import '../../models/external_mount.dart';
import '../../models/environment_variable.dart';
import '../../providers/external_mounts_provider.dart';
import '../../providers/workspace_provider.dart';
import '../chat/chat_service.dart';
import 'conversation_files.dart';
import 'environment_output_redactor.dart';
import 'file_link_resolver.dart';
import 'host_file_tools.dart';
import 'workspace_file_access.dart';
import '../conversation_tool_permissions.dart';
import '../../models/tool_permission_mode.dart';
import 'output_buffer.dart';
import 'tool_run_registry.dart';
import 'workspace_paths.dart';
import 'workspace_runtime.dart';
import 'workspace_tool_context.dart';
import 'workspace_tool_metadata.dart';
import '../runtime_profiles/runtime_profile_models.dart';
import '../runtime_profiles/runtime_profile_service.dart';
import '../runtime_profiles/runtime_profile_tools.dart';

export 'workspace_session_sync.dart' show AttachmentInfo, syncAttachments;
export 'workspace_tool_context.dart';
export 'workspace_tool_metadata.dart';

typedef ConversationExtrasUpdater =
    Future<void> Function(
      String conversationId,
      Map<String, dynamic> Function(Map<String, dynamic> extras) update,
    );

/// Per-generation workspace tool definitions, approval, and execution.
class WorkspaceToolsService {
  WorkspaceToolsService({
    ToolRunRegistry? registry,
    WorkspaceRuntimeProvider? runtimeProvider,
    this.updateConversationExtras,
    this.readPermissionState,
    this.permissionChanges,
    this.touchLastUsed,
    this.onSkillRead,
    this.onShellCompleted,
    this.isToolEnabled,
    this.loadEnvironment,
    this.runtimeProfiles,
  }) : registry = registry ?? ToolRunRegistry(),
       runtimeProvider = runtimeProvider ?? WorkspaceRuntimeProvider();

  static const Set<String> toolNames = {
    'shell',
    'read_file',
    'view_image',
    'write_file',
    'edit_file',
    'list_dir',
    'glob',
    'grep',
    'runtime_profile',
  };

  static const int _previewLimit = WorkspaceToolMetadata.previewMaxChars;
  static const int _changedFilesCap = 50;
  static const String _androidShellHint =
      'Uses the Shell path configured in Environment > PRoot settings; '
      'when unset, prefers /bin/bash if available, otherwise /bin/sh. '
      'This is not an interactive shell; do not assume ~/.bashrc is loaded.';

  static String get _shellInvocation =>
      defaultTargetPlatform == TargetPlatform.android
      ? 'configured shell -lc'
      : 'sh -lc';

  final ToolRunRegistry registry;
  final WorkspaceRuntimeProvider runtimeProvider;
  final ConversationExtrasUpdater? updateConversationExtras;
  final Listenable? permissionChanges;
  final ToolPermissionState? Function(String conversationId)?
  readPermissionState;
  final Future<void> Function(String workspaceId)? touchLastUsed;
  final Future<void> Function(String skillId)? onSkillRead;
  final Future<void> Function()? onShellCompleted;
  final bool Function(String workspaceId, String tool)? isToolEnabled;
  final Future<EnvironmentExecutionConfig> Function()? loadEnvironment;
  final RuntimeProfileService? runtimeProfiles;

  bool _enabled(WorkspaceToolContext ctx, String name) {
    // Conversation-scoped workspaces are intentionally ephemeral and are not
    // persisted in WorkspaceProvider. A provider lookup for their synthetic
    // id therefore returns null; do not let that disable every tool.
    if (ctx.conversationScoped) {
      return ctx.workspace.isToolEnabled(name);
    }
    return isToolEnabled?.call(ctx.workspace.id, name) ??
        ctx.workspace.isToolEnabled(name);
  }

  static Future<WorkspaceToolContext?> resolve({
    required String? conversationId,
    required WorkspaceProvider workspaceProvider,
    required WorkspaceRuntimeProvider runtimeProvider,
    required ChatService chatService,
    ExternalMountsProvider? externalMounts,
  }) async {
    if (conversationId == null || conversationId.isEmpty) return null;
    try {
      await workspaceProvider.loaded;
    } catch (_) {}
    final conversation = chatService.getConversation(conversationId);
    if (conversation == null) return null;
    final binding = WorkspaceBinding.fromExtras(conversation.extras);
    if (!binding.isBound) return null;
    final workspace = workspaceProvider.byId(binding.workspaceId!);
    if (workspace == null) return null;

    late final String hostRoot;
    try {
      hostRoot = await workspaceProvider.hostRootFor(workspace);
    } catch (e) {
      debugPrint('Workspace host root unavailable: $e');
      return null;
    }

    // Do not snapshot a null runtime while the app is still bootstrapping the
    // Android PRoot channel. The Environment page may have loaded its RootFS
    // metadata before this process-wide runtime has registered.
    final runtime = await runtimeProvider.ensureInitialized();
    RuntimeStatus? status;
    if (runtime != null) {
      try {
        status = await runtime.status();
      } catch (e) {
        debugPrint('Workspace runtime status failed: $e');
      }
    }
    final sandboxed = runtime != null
        ? (status?.sandboxed ?? false)
        : (Platform.isAndroid || Platform.isIOS);

    final sessionDir = await AppDirectories.sessionDir(conversationId);
    final skillsDir = await AppDirectories.getSkillsDirectory();
    final paths = sandboxed
        ? WorkspacePaths.sandboxed(
            workspaceHostRoot: hostRoot,
            sessionHostDir: sessionDir.path,
            skillsHostDir: skillsDir.path,
            externalMounts: await externalMounts?.resolveMounts() ?? const [],
            loadExternalMounts: externalMounts?.resolveMounts,
          )
        : WorkspacePaths.native(
            workspaceHostRoot: hostRoot,
            sessionHostDir: sessionDir.path,
            skillsHostDir: skillsDir.path,
          );

    await Directory(paths.tmpHostRoot).create(recursive: true);

    return WorkspaceToolContext(
      workspace: workspace,
      binding: binding,
      paths: paths,
      sessionDir: sessionDir,
      outputsDir: Directory(p.join(sessionDir.path, 'outputs')),
      conversationId: conversationId,
      assistantId: conversation.assistantId,
      runtimeStatus: status,
      runtimeRegistered: runtime != null,
    );
  }

  /// Builds a private per-conversation workspace when the chat has no
  /// explicit project binding. This gives the model a real `/workspace`
  /// mount and enables Skills without silently binding or modifying a user's
  /// project. No external folders are mounted into this context.
  static Future<WorkspaceToolContext?> resolveConversationScoped({
    required String? conversationId,
    required String? assistantId,
    required WorkspaceRuntimeProvider runtimeProvider,
  }) async {
    if (!Platform.isAndroid || conversationId == null || conversationId.isEmpty) {
      return null;
    }

    final runtime = await runtimeProvider.ensureInitialized();
    if (runtime == null) return null;

    RuntimeStatus status;
    try {
      status = await runtime.status();
    } catch (error) {
      debugPrint('Conversation workspace runtime status failed: $error');
      return null;
    }
    // Do not create an executable chat context from RootFS metadata alone.
    // The native PRoot probe must report ready before Shell or Skills are
    // advertised to the model.
    if (!status.ready || status.engine != 'proot' || !status.sandboxed) {
      debugPrint(
        'Conversation workspace unavailable: PRoot not ready '
        '(ready=${status.ready}, engine=${status.engine}, '
        'sandboxed=${status.sandboxed}, reason=${status.reason ?? 'none'})',
      );
      return null;
    }

    final sessionDir = await AppDirectories.sessionDir(conversationId);
    final workspaceRoot = await AppDirectories.conversationWorkspaceFilesDir(
      conversationId,
    );
    final skillsDir = await AppDirectories.getSkillsDirectory();
    await workspaceRoot.create(recursive: true);
    final conversationDigest =
        sha256.convert(utf8.encode(conversationId)).toString().substring(0, 24);
    final workspaceId = 'chat_$conversationDigest';
    final now = DateTime.now().toUtc();
    final workspace = Workspace(
      id: workspaceId,
      name: 'Conversation Workspace',
      kind: WorkspaceKind.managed,
      // A scratch conversation can run arbitrary commands only after a fresh
      // manual approval, even when the chat is in Full Access mode.
      shellNeedsApproval: true,
      createdAt: now,
      updatedAt: now,
    );
    final paths = WorkspacePaths.sandboxed(
      workspaceHostRoot: workspaceRoot.path,
      sessionHostDir: sessionDir.path,
      skillsHostDir: skillsDir.path,
      externalMounts: const [],
    );
    return WorkspaceToolContext(
      workspace: workspace,
      binding: const WorkspaceBinding(),
      paths: paths,
      sessionDir: sessionDir,
      outputsDir: Directory(p.join(sessionDir.path, 'outputs')),
      conversationId: conversationId,
      assistantId: assistantId,
      runtimeStatus: status,
      runtimeRegistered: true,
      conversationScoped: true,
    );
  }

  List<Map<String, dynamic>> buildToolDefinitions(WorkspaceToolContext ctx) {
    if (ctx.skillsOnly) {
      return [
        _fn(
          'read_file',
          [
            'Read a skill file as numbered lines. Use offset/limit to page through long files.',
            'Paths are limited to /skills/...',
          ],
          {
            'path': {
              'type': 'string',
              'description': 'Skill file path under /skills/...',
            },
            'offset': {
              'type': 'integer',
              'description': '1-based line number to start from.',
            },
            'limit': {
              'type': 'integer',
              'description': 'Maximum number of lines to return.',
            },
          },
          ['path'],
        ),
      ];
    }
    return definitions(
          vocab: _pathVocab(ctx.paths),
          outputHint: ctx.paths.sandboxed
              ? '${WorkspacePaths.guestChat}/outputs/<id>.txt'
              : '${ctx.paths.sessionHostDir}/outputs/<id>.txt',
          // Conversation scratch workspaces may create/list Skill-owned profiles.
          // The handler restricts them to scope=extension; project defaults remain unavailable.
          // Expose Skill-owned Runtime Profile management in a chat scratch workspace,
          // but never allow shell commands to select a project/extension profile.
          includeRuntimeProfiles: true,
          includeShellRuntimeProfileId: !ctx.conversationScoped,
          includeRuntimeProfileTools: true,
        )
        .where((definition) {
          final name = (definition['function'] as Map)['name'] as String;
          if (!_enabled(ctx, name)) return false;
          // File tools can still operate on app-managed paths when the guest
          // runtime is unavailable, but never advertise shell execution until
          // Android PRoot has completed its real status probe.
          if (name == 'shell') {
            return ctx.conversationScoped
                ? ctx.hasReadyProotRuntime
                : ctx.runtimeRegistered && ctx.runtimeStatus?.ready == true;
          }
          return true;
        })
        .toList();
  }

  /// Shared schemas for execution and the ungated description editor.
  static List<Map<String, dynamic>> definitions({
    List<String> vocab = const ['/workspace', '/chat', '/skills', '/tmp'],
    String outputHint = '/chat/outputs/<id>.txt',
    bool includeRuntimeProfiles = true,
    bool? includeShellRuntimeProfileId,
    bool? includeRuntimeProfileTools,
  }) {
    return [
      _fn(
        'shell',
        [
          'Fresh non-interactive $_shellInvocation per call; no cwd/env persists. Chain with &&.',
          'Available only when the Android/Linux runtime has completed initialization and its status probe reports ready.',
          'When this tool is exposed in a private conversation workspace, every command requires fresh manual approval even in Full Access mode.',
          if (defaultTargetPlatform == TargetPlatform.android)
            _androidShellHint,
          'Use non-interactive flags (e.g. -y). Output is capped; long output is saved',
          'to $outputHint. Network is available on mobile sandboxes.',
        ],
        {
          'command': {
            'type': 'string',
            'description': 'Shell command to run with $_shellInvocation.',
          },
          'cwd': {
            'type': 'string',
            'description':
                'Working directory in model path vocabulary (${vocab.join(', ')}).',
          },
          if (includeShellRuntimeProfileId ?? includeRuntimeProfiles)
            'runtime_profile_id': {
              'type': 'string',
              'description':
                  'Optional Runtime Profile ID returned by runtime_profile list/inspect. Never invent an ID. If omitted, the active project workspace default profile is used when configured.',
              'maxLength': 64,
            },
          'timeout_seconds': {
            'type': 'integer',
            'description':
                'Command timeout in seconds (default 900, range 1-3600). '
                'Choose a longer timeout for package installs, downloads, builds, '
                'or other long-running commands. Values outside this range are clamped.',
            'default': 900,
            'minimum': 1,
            'maximum': 3600,
          },
        },
        ['command'],
      ),
      _fn(
        'read_file',
        [
          'Read a file as numbered lines. Use offset/limit to page through long files.',
          'ZIP archive paths are files, not directories: read_file returns the archive manifest. To read a text member, pass its exact relative path in archive_entry. Never use list_dir on a ZIP file path.',
          'Paths: ${vocab.join(', ')}.',
        ],
        {
          'path': {'type': 'string', 'description': 'File path to read.'},
          'offset': {
            'type': 'integer',
            'description': '1-based line number to start from.',
          },
          'limit': {
            'type': 'integer',
            'description': 'Maximum number of lines to return.',
          },
          'archive_entry': {
            'type': 'string',
            'description': 'Optional exact relative file path inside a ZIP archive. Omit it to list archive entries.',
          },
        },
        ['path'],
      ),
      _fn(
        'view_image',
        [
          'View a local image file when visual inspection is needed. Use this for images already on disk.',
          'Paths: ${vocab.join(', ')}. Supports PNG, JPEG, GIF, WebP, and BMP; animated images use the first frame.',
          'Returns image content to inspect. Large images are resized to at most 2048 pixels on the longest edge.',
        ],
        {
          'path': {
            'type': 'string',
            'description': 'Local filesystem path to an image file.',
          },
        },
        ['path'],
      ),
      _fn(
        'write_file',
        [
          'Create or overwrite a file with the given content.',
          'Writable zones: workspace, chat, tmp. Skills are read-only.',
        ],
        {
          'path': {'type': 'string', 'description': 'File path to write.'},
          'content': {'type': 'string', 'description': 'Full file contents.'},
        },
        ['path', 'content'],
      ),
      _fn(
        'edit_file',
        [
          'Replace old_string with new_string. Matching is whitespace-tolerant',
          '(exact, then line-trimmed, then block-anchor). old_string must match a',
          'unique location unless replace_all is true. Read the file before editing.',
        ],
        {
          'path': {'type': 'string', 'description': 'File path to edit.'},
          'old_string': {
            'type': 'string',
            'description': 'Exact or whitespace-tolerant text to find.',
          },
          'new_string': {'type': 'string', 'description': 'Replacement text.'},
          'replace_all': {
            'type': 'boolean',
            'description':
                'Replace every match instead of requiring a unique one.',
          },
        },
        ['path', 'old_string', 'new_string'],
      ),
      _fn(
        'list_dir',
        [
          'List directory entries. Directories are suffixed with /; files include size.',
          'ZIP paths are files, not directories. For compatibility, a mistaken list_dir call on a .zip returns its archive manifest; use read_file with archive_entry to inspect a member, or extension_install directly to install a Skill ZIP.',
          'Default path is the current workspace cwd.',
        ],
        {
          'path': {'type': 'string', 'description': 'Directory to list.'},
          'depth': {
            'type': 'integer',
            'description': 'How many directory levels to walk (default 1).',
          },
        },
        const [],
      ),
      _fn(
        'glob',
        [
          'Find files whose relative paths match a glob pattern (e.g. **/*.dart).',
        ],
        {
          'pattern': {
            'type': 'string',
            'description': 'Glob pattern to match.',
          },
          'path': {
            'type': 'string',
            'description': 'Directory to search (default: workspace root).',
          },
        },
        ['pattern'],
      ),
      _fn(
        'grep',
        [
          'Search file contents with a regex (falls back to a literal if invalid).',
        ],
        {
          'pattern': {
            'type': 'string',
            'description': 'Regex or literal to find.',
          },
          'path': {
            'type': 'string',
            'description':
                'File or directory to search (default: workspace root).',
          },
          'ignore_case': {
            'type': 'boolean',
            'description': 'Case-insensitive search.',
          },
          'limit': {
            'type': 'integer',
            'description': 'Maximum matches to return (default 100).',
          },
        },
        ['pattern'],
      ),
      if (includeRuntimeProfileTools ?? includeRuntimeProfiles)
        ...RuntimeProfileToolCatalog.definitions(),
    ];
  }

  static String buildPromptFragment(
    WorkspaceToolContext ctx, {
    Iterable<String> environmentVariableNames = const [],
  }) {
    if (ctx.skillsOnly) return '';
    final paths = ctx.paths;
    final workspace = paths.sandboxed
        ? WorkspacePaths.guestWorkspace
        : paths.workspaceHostRoot;
    final chat = paths.sandboxed
        ? WorkspacePaths.guestChat
        : paths.sessionHostDir;
    final skills = paths.sandboxed
        ? WorkspacePaths.guestSkills
        : paths.skillsHostDir;
    final tmp = paths.sandboxed ? WorkspacePaths.guestTmp : paths.tmpHostRoot;
    final outputsHint = paths.sandboxed
        ? '${WorkspacePaths.guestChat}/outputs/<id>.txt'
        : '${paths.sessionHostDir}/outputs/<id>.txt';
    final shellAvailable = ctx.workspace.isToolEnabled('shell') &&
        (ctx.conversationScoped
            ? ctx.hasReadyProotRuntime
            : ctx.runtimeRegistered && ctx.runtimeStatus?.ready == true);
    final enabledTools = toolNames
        .where(ctx.workspace.isToolEnabled)
        .where((name) => name != 'shell' || shellAvailable)
        .join(', ');
    final buf = StringBuffer()
      ..writeln('<workspace>')
      ..writeln('Path zones:')
      ..writeln('- $workspace — project files (writable)')
      ..writeln('- $chat — this chat\'s attachments/ and outputs/ (writable)')
      ..writeln('- $skills — installed skills (read-only)');
    if (paths.sandboxed) {
      final source = defaultTargetPlatform == TargetPlatform.iOS
          ? "from iOS Files (e.g. an Obsidian vault, Downloads, another app's iCloud container)"
          : 'from Environment settings (on-device folders)';
      final readOnly = paths.externalMounts
          .where((mount) => mount.readOnly)
          .map((mount) => mount.guest)
          .join(', ');
      buf.writeln(
        '- ${ExternalMount.root}/<name>/ — user-mounted external folders '
        '$source, shared across workspaces. '
        'Names and availability vary: list ${ExternalMount.root}/ first for external/user files. '
        'File tools reject writes to read-only mounts; respect this in Shell too.'
        '${readOnly.isEmpty ? '' : ' Read-only: $readOnly.'}',
      );
    }
    buf.writeln('- $tmp — scratch (writable, ephemeral)');
    if (ctx.conversationScoped) {
      buf.writeln(
        'This is a private per-conversation scratch workspace, not a user-selected project.',
      );
      buf.writeln(
        'No external folders are mounted. Keep project files under /workspace and chat artifacts under /chat.',
      );
      buf.writeln(
        'Every shell command requires a fresh manual approval, including in Full Access mode.',
      );
      buf.writeln(
        'This private conversation workspace runs in the Android PRoot guest. You may create/list/inspect Runtime Profiles owned by an installed Skill using runtime_profile with scope=extension and that exact Skill owner_id. Project-scoped default profiles are unavailable in this scratch workspace. Pass the Skill-owned profile_id only to skill_execute or package_manager scope=extension, never to shell; shell still runs in the base guest and requires its own manual approval.',
      );
    }
    if (ctx.hasReadyProotRuntime) {
      buf.writeln(
        'Runtime connection: shell executes inside the installed Android PRoot guest, not the Android host.',
      );
      buf.writeln(
        'For Ubuntu/package questions, use environment_status for verified facts and shell for live follow-up commands.',
      );
      buf.writeln(
        'Never infer the handset model from guest MACHINE, KERNEL, architecture, or terminal output; these identify only the guest runtime.',
      );
      buf.writeln(
        'Do not recommend installing PRoot with apt: PRoot is provided by the Android host runtime.',
      );
    }
    buf
      ..writeln('cwd: ${ctx.cwd}')
      ..writeln(
        'Enabled tools: $enabledTools',
      )
      ..writeln();
    if (shellAvailable) {
      buf.writeln(
        'shell is one-shot: a fresh non-interactive $_shellInvocation each call. '
        'No cd or env persists. Chain with &&. Use non-interactive flags (-y). '
        'Output is capped; long output is saved to $outputsHint.',
      );
      if (ctx.conversationScoped) {
        buf.writeln(
          'This private chat workspace uses the base Android PRoot environment directly. Runtime Profiles are available only for installed-Skill ownership (scope=extension); do not create project profiles or set workspace defaults here. Pass a Skill-owned profile_id only to skill_execute or package_manager scope=extension, never to shell. Every shell command still requires fresh manual approval.',
        );
      } else if (ctx.workspace.defaultRuntimeProfileId != null) {
        buf.writeln(
          'Default Runtime Profile: ${ctx.workspace.defaultRuntimeProfileId}. '
          'Python/Node package-manager operations in project scope use this profile unless an explicit profile_id is supplied. '
          'The profile isolates package roots and environment variables; use KELIVO_TASK_OUTPUT_DIR for this run’s persistent outputs and TMPDIR for disposable scratch files. PRoot remains a shared OS environment, not a kernel security boundary.',
        );
      } else {
        buf.writeln(
          'No default Runtime Profile is configured. Before installing project-specific Python/Node dependencies, '
          'use runtime_profile to create and inspect an isolated project profile, then set it as the workspace default. '
          'When a profile is active, write task results to KELIVO_TASK_OUTPUT_DIR and temporary scratch data to TMPDIR. '
          'APT/APK packages always modify the shared PRoot runtime.',
        );
      }
      buf.writeln(
        'Runtime process history is persisted. After app restart, an interrupted run is marked interrupted with a resume hint; '
        'the original native process cannot be resumed automatically.',
      );
      if (environmentVariableNames.isNotEmpty) {
        buf.writeln(
          'User-configured environment variables are already injected: '
          '${environmentVariableNames.join(', ')}. '
          r'Use $NAME references; do not print or attempt to discover their values.',
        );
      }
    }
    if (ctx.workspace.isToolEnabled('read_file') &&
        ctx.workspace.isToolEnabled('edit_file')) {
      if (ctx.workspace.isToolEnabled('write_file')) {
        buf.writeln(
          'Prefer read_file, edit_file, and write_file over cat/sed.',
        );
      }
      buf.writeln('Always read_file before editing.');
    }
    buf
      ..writeln()
      ..writeln(
        'Cite files as [name](kelivo://workspace/rel/path), outputs as '
        'kelivo://chat/outputs/x.txt, images as ![alt](kelivo://workspace/plot.png). '
        'Percent-encode each path segment (spaces, non-ASCII); raw UTF-8 is also accepted.',
      )
      ..writeln()
      ..writeln(_engineLine(ctx));
    buf.write('</workspace>');
    return buf.toString();
  }

  Future<Object?> handle(
    WorkspaceToolContext ctx,
    String name,
    Map<String, dynamic> args, {
    required String toolCallId,
    ToolApprovalService? approvalService,
    String? conversationId,
  }) async {
    final environment =
        await loadEnvironment?.call() ?? EnvironmentExecutionConfig();
    final redactor = EnvironmentOutputRedactor(environment);
    final id = conversationId ?? ctx.conversationId;
    final access = WorkspaceFileAccess(
      paths: ctx.paths,
      skillsOnly: ctx.skillsOnly,
      arguments: args,
      permission: ToolCallPermission(
        toolName: name,
        toolCallId: toolCallId,
        conversationId: id,
        workspaceId: ctx.skillsOnly || ctx.conversationScoped
            ? null
            : ctx.workspace.id,
        assistantId: ctx.assistantId,
        approvals: approvalService,
        stateChanges: permissionChanges,
        isEnabled: () => ctx.skillsOnly || _enabled(ctx, name),
        readState: () => readPermissionState != null && id != null
            ? readPermissionState!(id)
            : ToolPermissionState(
                mode: ctx.permissionMode,
              workspaceId: ctx.skillsOnly || ctx.conversationScoped
                  ? null
                  : ctx.workspace.id,
              assistantId: ctx.assistantId,
              ),
      ),
    );
    final result = await _handle(
      ctx,
      name,
      args,
      toolCallId: toolCallId,
      approvalService: approvalService,
      conversationId: conversationId,
      environment: environment.variables,
      access: access,
    );
    final client = ClientToolResult.fromHandler(result);
    return redactor.redact(
      ClientToolResult(
        client.content,
        metadata: {
          ...?client.metadata,
          if (access.permission.byFullAccess) 'toolPermission': 'fullAccess',
        },
      ),
    );
  }

  Future<Object?> _handle(
    WorkspaceToolContext ctx,
    String name,
    Map<String, dynamic> args, {
    required String toolCallId,
    ToolApprovalService? approvalService,
    String? conversationId,
    required Map<String, String> environment,
    required WorkspaceFileAccess access,
  }) async {
    if (ctx.skillsOnly && name != 'read_file') {
      return _errorResult(
        tool: name,
        error: 'skills_only',
        message: 'Only read_file is available without a workspace',
      );
    }
    if (!ctx.skillsOnly && !_enabled(ctx, name)) {
      return _errorResult(
        tool: name,
        error: 'tool_disabled',
        message: 'This tool is disabled for the workspace',
      );
    }
    try {
      ToolCallCancellation.current?.throwIfCancelled();
      await ctx.paths.refreshExternalMounts();
      ToolCallCancellation.current?.throwIfCancelled();
      switch (name) {
        case 'shell':
          return await _handleShell(
            ctx,
            args,
            access: access,
            toolCallId: toolCallId,
            approvalService: approvalService,
            conversationId: conversationId,
            environment: environment,
          );
        case 'read_file':
          return await _handleReadFile(ctx, args, access);
        case 'view_image':
          return await _handleViewImage(ctx, args, access);
        case 'write_file':
          return await _handleWriteFile(
            ctx,
            args,
            access: access,
            toolCallId: toolCallId,
            approvalService: approvalService,
            conversationId: conversationId,
          );
        case 'edit_file':
          return await _handleEditFile(
            ctx,
            args,
            access: access,
            toolCallId: toolCallId,
            approvalService: approvalService,
            conversationId: conversationId,
          );
        case 'list_dir':
          return await _handleListDir(ctx, args, access);
        case 'glob':
          return await _handleGlob(ctx, args, access);
        case 'grep':
          return await _handleGrep(ctx, args, access);
        default:
          return _errorResult(
            tool: name,
            error: 'unknown_tool',
            message: 'Unknown workspace tool: $name',
          );
      }
    } on ToolPermissionException catch (e) {
      access.permission.byFullAccess = false;
      return _deniedResult(tool: name, error: e.code, message: e.message);
    } catch (e) {
      return _errorResult(
        tool: name,
        error: 'tool_failed',
        message: e.toString(),
      );
    }
  }

  static String? linkFor(
    ResolvedPath resolved, {
    required WorkspacePaths paths,
  }) {
    switch (resolved.zone) {
      case WorkspaceZone.workspace:
        final rel = WorkspacePaths.relativeToHostRoot(
          paths.workspaceHostRoot,
          resolved.hostPath,
        );
        if (rel == null) return null;
        return 'kelivo://workspace/${KelivoLink.encodePath(rel)}';
      case WorkspaceZone.chat:
        final rel = WorkspacePaths.relativeToHostRoot(
          paths.sessionHostDir,
          resolved.hostPath,
        );
        if (rel == null) return null;
        if (rel == 'attachments' ||
            rel == 'outputs' ||
            rel.startsWith('attachments/') ||
            rel.startsWith('outputs/')) {
          return 'kelivo://chat/${KelivoLink.encodePath(rel)}';
        }
        return 'kelivo://session/${KelivoLink.encodePath(rel)}';
      case WorkspaceZone.skills:
        final rel = WorkspacePaths.relativeToHostRoot(
          paths.skillsHostDir,
          resolved.hostPath,
        );
        if (rel == null) return null;
        return 'kelivo://skills/${KelivoLink.encodePath(rel)}';
      case WorkspaceZone.tmp:
        final rel = WorkspacePaths.relativeToHostRoot(
          paths.tmpHostRoot,
          resolved.hostPath,
        );
        return rel == null
            ? null
            : 'kelivo://tmp/${KelivoLink.encodePath(rel)}';
      case WorkspaceZone.external:
        for (final mount in paths.externalMounts) {
          final rel = WorkspacePaths.relativeToHostRoot(
            mount.host,
            resolved.hostPath,
          );
          if (rel != null && mount.externalId != null) {
            return 'kelivo://mounts/${Uri.encodeComponent(mount.externalId!)}${rel.isEmpty ? '' : '/${KelivoLink.encodePath(rel)}'}';
          }
        }
        return null;
      case WorkspaceZone.outside:
        return null;
    }
  }

  static WorkspaceToolFile _fileFor(
    WorkspaceToolContext ctx,
    ResolvedPath resolved, {
    WorkspaceFileRole role = WorkspaceFileRole.referenced,
    bool isDirectory = false,
  }) => WorkspaceToolFile(
    path: resolved.modelPath,
    link: linkFor(resolved, paths: ctx.paths),
    isDirectory: isDirectory,
    role: role,
    temporary: resolved.zone == WorkspaceZone.tmp,
  );

  static Future<List<WorkspaceToolFile>> _referencedFiles(
    WorkspaceToolContext ctx,
    Iterable<String> paths,
  ) async {
    final files = <WorkspaceToolFile>[];
    final seen = <String>{};
    for (final path in paths.toSet()) {
      try {
        final resolved = await ctx.paths.resolveReal(path, cwd: ctx.cwd);
        final file = _fileFor(
          ctx,
          resolved,
          isDirectory: await FileSystemEntity.isDirectory(resolved.hostPath),
        );
        if (seen.add(file.identity)) files.add(file);
      } on PathResolutionException {
        files.add(WorkspaceToolFile(path: path));
      } on FileSystemException {
        files.add(WorkspaceToolFile(path: path));
      }
    }
    return files;
  }

  Future<Object?> _handleShell(
    WorkspaceToolContext ctx,
    Map<String, dynamic> args, {
    required String toolCallId,
    ToolApprovalService? approvalService,
    String? conversationId,
    required Map<String, String> environment,
    required WorkspaceFileAccess access,
  }) async {
    const tool = 'shell';
    final cancellation = ToolCallCancellation.current;
    cancellation?.throwIfCancelled();
    final command = _stringArg(args, 'command');
    if (command.isEmpty) {
      return _errorResult(
        tool: tool,
        error: 'invalid_arguments',
        message: 'command is required',
      );
    }

    final runtime = await runtimeProvider.ensureInitialized();
    RuntimeStatus? status;
    if (runtime != null) {
      try {
        status = await runtime.status();
      } catch (error) {
        debugPrint('Shell runtime status failed: $error');
      }
    }
    final conversationProotReady = status?.ready == true &&
        status?.engine == 'proot' &&
        status?.sandboxed == true;
    if (runtime == null ||
        status == null ||
        !status.ready ||
        (ctx.conversationScoped && !conversationProotReady)) {
      return _errorResult(
        tool: tool,
        error: 'environment_not_ready',
        message: status?.reason ??
            (ctx.conversationScoped
                ? 'Android PRoot runtime is no longer ready for this conversation.'
                : 'Sandbox environment is not ready'),
        instruction:
            'tell the user to install/enable the sandbox environment in Settings → Workspace',
        meta: const WorkspaceToolMetadata(
          tool: tool,
          status: 'error',
          code: 'environment_not_ready',
        ),
      );
    }

    final sandboxed = status.sandboxed;
    final needsApproval = ctx.workspace.shellNeedsApproval || !sandboxed;
    if (ctx.conversationScoped) {
      // The mandatory manual approval is requested immediately before run(),
      // after preflight/path/profile checks, so it is shown exactly once.
      access.permission.check();
    } else {
      await access.permission.authorize(needed: needsApproval, arguments: args);
    }

    final requestedTimeout = (_intArg(args, 'timeout_seconds') ?? 900)
        .clamp(1, 3600)
        .toInt();
    final cwd = ctx.paths.normalizeCwd(
      _stringArg(args, 'cwd', fallback: ctx.cwd),
    );
    final runtimeRunId = const Uuid().v4();
    RuntimeProfileExecution? profileExecution;
    final profiles = runtimeProfiles;
    final requestedProfileId = _stringArg(args, 'runtime_profile_id').trim();
    // Conversation workspaces are ephemeral scratch areas, not persisted
    // projects. They deliberately execute in the base PRoot guest and must
    // never resolve a project Runtime Profile (including stale/model-invented
    // IDs). Manual approval remains mandatory below for every command.
    final runtimeProfileIgnored = ctx.conversationScoped &&
        (requestedProfileId.isNotEmpty ||
            ctx.workspace.defaultRuntimeProfileId != null);
    try {
      if (!ctx.conversationScoped && profiles != null) {
        profileExecution = await profiles.resolveExecution(
          context: ctx,
          runId: runtimeRunId,
          requestedProfileId: requestedProfileId,
        );
      } else if (!ctx.conversationScoped &&
          (requestedProfileId.isNotEmpty ||
              ctx.workspace.defaultRuntimeProfileId != null)) {
        throw const RuntimeProfileException('runtime_profile_service_unavailable');
      }
    } on RuntimeProfileException catch (error) {
      return _errorResult(
        tool: tool,
        error: error.code,
        message: error.code,
      );
    }
    final timeoutSeconds = profileExecution == null
        ? requestedTimeout
        : (requestedTimeout < profileExecution.timeout.inSeconds
              ? requestedTimeout
              : profileExecution.timeout.inSeconds);
    final env = <String, String>{
      if (!sandboxed) ...Platform.environment,
      'NO_COLOR': '1',
      'CI': 'true',
      'PAGER': 'cat',
      'TERM': 'dumb',
      'LANG': 'C.UTF-8',
      'HOME': sandboxed ? '/root' : (Platform.environment['HOME'] ?? ''),
      for (final name in ['TMPDIR', 'TMP', 'TEMP'])
        name: sandboxed ? '/tmp' : ctx.paths.tmpHostRoot,
      ...environment,
      if (profileExecution != null) ...profileExecution.environment,
    };
    final effectiveCommand = profileExecution?.wrapCommand(command) ?? command;

    late final Map<String, int> before;
    try {
      await Directory(ctx.paths.tmpHostRoot).create(recursive: true);
      before = await FileSnapshot.snapshot([
        Directory(ctx.paths.workspaceHostRoot),
        ctx.sessionDir,
      ], checkCancelled: cancellation?.throwIfCancelled);
    } catch (_) {
      if (profileExecution != null) {
        profiles!.releaseReservation(profileExecution.profile.id, runtimeRunId);
      }
      rethrow;
    }
    final run = registry.start(
      toolCallId,
      tool,
      command: command,
      conversationId: conversationId ?? ctx.conversationId,
      runtimeRunId: runtimeRunId,
    );

    CommandExited? exited;
    Object? executionError;
    void Function()? unregisterCancellation;
    try {
      cancellation?.throwIfCancelled();
      await access.permission.authorize(
        needed: needsApproval || ctx.conversationScoped,
        requireManualApproval: ctx.conversationScoped,
        arguments: args,
      );
      cancellation?.throwIfCancelled();
      unregisterCancellation = cancellation?.onCancel(() {
        unawaited(runtime.cancel(runtimeRunId));
      });
      if (profileExecution != null) {
        await profiles!.recordStarted(
          execution: profileExecution,
          runtimeRunId: runtimeRunId,
          command: command,
        );
      }
      await for (final event in runtime.run(
        CommandRequest(
          runId: runtimeRunId,
          isCancelled: cancellation?.isCancelled,
          command: effectiveCommand,
          cwd: cwd,
          timeout: Duration(seconds: timeoutSeconds),
          env: env,
          mounts: ctx.paths.mounts,
        ),
      )) {
        switch (event) {
          case CommandStarted():
            break;
          case CommandOutput(:final kind, :final bytes):
            if (kind == OutputStreamKind.stdout) {
              run.appendStdout(bytes);
            } else {
              run.appendStderr(bytes);
            }
          case CommandExited():
            exited = event;
        }
      }
    } catch (e) {
      executionError = e;
    } finally {
      unregisterCancellation?.call();
      if (profileExecution != null) {
        await profiles!.cleanupExecution(context: ctx, execution: profileExecution);
        try {
          final profileStatus = executionError != null || exited == null
              ? RuntimeProcessStatus.failed
              : exited.cancelled
              ? RuntimeProcessStatus.cancelled
              : exited.timedOut
              ? RuntimeProcessStatus.timedOut
              : exited.exitCode == 0
              ? RuntimeProcessStatus.succeeded
              : RuntimeProcessStatus.failed;
          await profiles!.recordCompleted(
            execution: profileExecution,
            runtimeRunId: runtimeRunId,
            status: profileStatus,
            exitCode: exited?.exitCode,
            error: executionError?.toString(),
          );
        } catch (error) {
          profiles!.releaseReservation(profileExecution.profile.id, runtimeRunId);
          debugPrint('Runtime profile process ledger update failed: $error');
        }
      }
      // A failed or cancelled command may still have installed/updated files.
      // Refresh observers without turning a refresh failure into a tool error.
      try {
        await onShellCompleted?.call();
      } catch (error) {
        debugPrint('Workspace post-command refresh failed: $error');
      }
    }

    final runStatus = executionError != null || exited == null
        ? ToolRunStatus.failed
        : exited.cancelled
        ? ToolRunStatus.cancelled
        : exited.timedOut
        ? ToolRunStatus.timedOut
        : exited.exitCode == 0
        ? ToolRunStatus.succeeded
        : ToolRunStatus.failed;
    run.complete(
      status: runStatus,
      exitCode: exited?.exitCode,
      retainUntilHandoff: true,
    );
    try {
      final stdout = run.stdoutSoFar;
      final stderr = run.stderrSoFar;

      final after = await FileSnapshot.snapshot([
        Directory(ctx.paths.workspaceHostRoot),
        ctx.sessionDir,
      ]);
      final changedHost = FileSnapshot.changedSince(before, after);
      final files = <WorkspaceToolFile>[];
      for (final hostPath in changedHost.take(_changedFilesCap)) {
        final modelPath = ctx.paths.toModelPath(hostPath);
        try {
          final resolved = await ctx.paths.resolveReal(modelPath, cwd: cwd);
          if (!await FileSystemEntity.isFile(resolved.hostPath)) continue;
          files.add(
            _fileFor(
              ctx,
              resolved,
              role: before.containsKey(hostPath)
                  ? WorkspaceFileRole.modified
                  : WorkspaceFileRole.created,
            ),
          );
        } on PathResolutionException {
          files.add(
            WorkspaceToolFile(
              path: modelPath,
              role: WorkspaceFileRole.modified,
            ),
          );
        } on FileSystemException {
          // A file removed again before collection is not a remaining output.
        }
      }
      final filesTruncated =
          changedHost.length > _changedFilesCap ||
          before.length >= FileSnapshot.defaultMaxEntries ||
          after.length >= FileSnapshot.defaultMaxEntries;

      if (executionError != null || exited == null) {
        return _errorResult(
          tool: tool,
          error: 'shell_failed',
          message:
              executionError?.toString() ??
              'Command ended without an exit event',
          meta: WorkspaceToolMetadata(
            tool: tool,
            status: 'error',
            code: 'shell_failed',
            command: command,
            stdoutPreview: stdout,
            stderrPreview: stderr,
            files: files,
            filesTruncated: filesTruncated,
          ),
        );
      }

      final offload = await ToolOutputOffloader.maybeOffload(
        toolCallId: toolCallId,
        stdout: stdout,
        stderr: stderr,
        outputsDir: ctx.outputsDir,
      );
      final payload = _shellPayload(offload.modelText);
      payload['exit_code'] = exited.exitCode;
      payload['duration_ms'] = exited.duration.inMilliseconds;
      payload['timed_out'] = exited.timedOut;
      payload['cancelled'] = exited.cancelled;
      if (stderr.contains('__KELIVO_TEMP_LIMIT_EXCEEDED__')) {
        payload['resource_limit_exceeded'] = 'temporary_storage';
      }
      payload['interrupted'] = exited.interrupted;
      payload['runtime_engine'] = status.engine;
      if (runtimeProfileIgnored) {
        payload['runtime_profile_ignored'] = true;
        payload['runtime_profile_note'] =
            'Conversation workspaces run in the base PRoot environment; project Runtime Profiles are not applied.';
      }
      if (profileExecution != null) {
        payload['runtime_profile_id'] = profileExecution.profile.id;
        payload['runtime_profile_name'] = profileExecution.profile.name;
        payload['temporary_directory'] = profileExecution.temporaryRuntimePath;
        payload['task_output_directory'] = profileExecution.outputRuntimePath;
      }
      if (run.stdoutTruncated || run.stderrTruncated) {
        payload['truncated'] = true;
      }
      if (files.isNotEmpty) {
        payload['changed_files'] = [for (final file in files) file.path];
      }
      if (filesTruncated) payload['changed_files_truncated'] = true;
      if (offload.offloadHostPath != null) {
        final outputFile = ctx.paths.toModelPath(offload.offloadHostPath!);
        payload['output_file'] = outputFile;
        payload['truncated'] = true;
        final resolved = await ctx.paths.resolveReal(outputFile, cwd: cwd);
        files.add(_fileFor(ctx, resolved, role: WorkspaceFileRole.log));
      }

      final metaStatus = exited.timedOut
          ? 'timeout'
          : exited.cancelled
          ? 'cancelled'
          : 'ok';
      final meta = WorkspaceToolMetadata(
        tool: tool,
        status: metaStatus,
        command: command,
        exitCode: exited.exitCode,
        durationMs: exited.duration.inMilliseconds,
        timedOut: exited.timedOut,
        cancelled: exited.cancelled,
        interrupted: exited.interrupted,
        stdoutPreview: utf16SafeCut(stdout, _previewLimit, keepTail: true),
        stderrPreview: utf16SafeCut(stderr, _previewLimit, keepTail: true),
        files: files,
        filesTruncated: filesTruncated,
        truncated: payload['truncated'] == true,
      );
      await _markToolsUsed(
        ctx,
        conversationId: conversationId,
        status: metaStatus,
      );
      return ClientToolResult(jsonEncode(payload), metadata: meta.toJson());
    } finally {
      // Model output and metadata now own immutable strings (or the offloaded
      // file). Only now may the registry evict this completed execution.
      run.finishHandoff();
    }
  }

  Future<String> _snapshotImage(ToolImage image) async {
    ToolCallCancellation.current?.throwIfCancelled();
    final imagesDir = await AppDirectories.getImagesDirectory();
    await imagesDir.create(recursive: true);
    final extension = image.mime == 'image/png' ? 'png' : 'jpg';
    final snapshot = File(
      p.join(imagesDir.path, 'view_image_${const Uuid().v4()}.$extension'),
    );
    await snapshot.writeAsBytes(image.bytes);
    return SandboxPathResolver.canonicalize(snapshot.path);
  }

  Future<Object?> _handleViewImage(
    WorkspaceToolContext ctx,
    Map<String, dynamic> args,
    WorkspaceFileAccess access,
  ) async {
    const tool = 'view_image';
    final path = args['path'];
    if (path is! String || path.trim().isEmpty) {
      return _errorResult(
        tool: tool,
        error: 'invalid_arguments',
        message: 'path must be a non-empty string',
      );
    }
    try {
      final resolved = await access.resolve(path, ctx.cwd);
      ToolCallCancellation.current?.throwIfCancelled();
      if (ctx.paths.sandboxed && resolved.zone == WorkspaceZone.outside) {
        throw const PathResolutionException('Path is outside sandbox zones');
      }
      final image = await ToolImage.read(resolved.hostPath);
      ToolCallCancellation.current?.throwIfCancelled();
      final uri = await _snapshotImage(image);
      await _markToolsUsed(
        ctx,
        conversationId: ctx.conversationId,
        status: 'ok',
      );
      return ClientToolResult(
        'Image (${image.width} x ${image.height}).\n![](${encodeMarkdownImageDestination(uri)})',
        metadata: {
          ...WorkspaceToolMetadata(
            tool: tool,
            status: 'ok',
            path: resolved.modelPath,
            files: [_fileFor(ctx, resolved)],
          ).toJson(),
          kMcpResultMetadataKey: mcpResultMetadata([uri]),
        },
      );
    } on ToolImageException catch (e) {
      return _errorResult(
        tool: tool,
        error: 'view_image_failed',
        message: e.message,
      );
    } on PathResolutionException catch (e) {
      return _errorResult(tool: tool, error: 'path_error', message: e.message);
    }
  }

  Future<Object?> _handleReadFile(
    WorkspaceToolContext ctx,
    Map<String, dynamic> args,
    WorkspaceFileAccess access,
  ) async {
    const tool = 'read_file';
    final path = _stringArg(args, 'path');
    if (path.isEmpty) {
      return _errorResult(
        tool: tool,
        error: 'invalid_arguments',
        message: 'path is required',
      );
    }
    try {
      final resolved = await access.resolve(path, ctx.cwd);
      if (ctx.skillsOnly && resolved.zone != WorkspaceZone.skills) {
        return _errorResult(
          tool: tool,
          error: 'path_outside_skills',
          message: 'read_file is limited to /skills in skills-only mode',
        );
      }
      final result = await HostFileTools(ctx.paths, access: access).readFile(
        path,
        offset: _intArg(args, 'offset'),
        limit: _intArg(args, 'limit'),
        cwd: ctx.cwd,
        archiveEntry: _stringArg(args, 'archive_entry'),
      );
      final meta = WorkspaceToolMetadata(
        tool: tool,
        status: 'ok',
        path: resolved.modelPath,
        files: [_fileFor(ctx, resolved)],
      );
      if (result.archive) {
        await _maybeNoteSkillRead(ctx, resolved);
        await _markToolsUsed(
          ctx,
          conversationId: ctx.conversationId,
          status: 'ok',
        );
        return ClientToolResult(
          jsonEncode(<String, Object?>{
            'archive': true,
            'format': 'zip',
            'entries': [for (final entry in result.archiveEntries) entry.toJson()],
            'entries_truncated': result.archiveEntriesTruncated,
            'next_step': 'To inspect a text file inside this archive, call read_file again with the same path and archive_entry set to the exact relative member path.',
          }),
          metadata: meta.toJson(),
        );
      }
      if (result.imageBytes != null) {
        final uri = await _snapshotImage(
          await ToolImage.fromBytes(result.imageBytes!),
        );
        await _maybeNoteSkillRead(ctx, resolved);
        await _markToolsUsed(
          ctx,
          conversationId: ctx.conversationId,
          status: 'ok',
        );
        return ClientToolResult(
          '![](${encodeMarkdownImageDestination(uri)})',
          metadata: <String, dynamic>{
            ...meta.toJson(),
            kMcpResultMetadataKey: mcpResultMetadata([uri]),
          },
        );
      }
      if (result.binary) {
        await _maybeNoteSkillRead(ctx, resolved);
        await _markToolsUsed(
          ctx,
          conversationId: ctx.conversationId,
          status: 'ok',
        );
        return ClientToolResult(
          jsonEncode(<String, Object?>{
            'binary': true,
            'hex_preview': result.hexPreview ?? '',
            if (result.archiveEntryName != null)
              'archive_entry': result.archiveEntryName,
          }),
          metadata: meta.toJson(),
        );
      }
      final text = result.text ?? '';
      final content = result.nextOffset == null
          ? text
          : '$text(more lines: use offset=${result.nextOffset})';
      await _maybeNoteSkillRead(ctx, resolved);
      await _markToolsUsed(
        ctx,
        conversationId: ctx.conversationId,
        status: 'ok',
      );
      return ClientToolResult(content, metadata: meta.toJson());
    } on HostFileException catch (e) {
      return _errorResult(tool: tool, error: 'read_failed', message: e.message);
    } on PathResolutionException catch (e) {
      if (ctx.skillsOnly) {
        return _errorResult(
          tool: tool,
          error: 'path_outside_skills',
          message: e.message,
        );
      }
      return _errorResult(tool: tool, error: 'path_error', message: e.message);
    }
  }

  Future<Object?> _handleWriteFile(
    WorkspaceToolContext ctx,
    Map<String, dynamic> args, {
    required WorkspaceFileAccess access,
    required String toolCallId,
    ToolApprovalService? approvalService,
    String? conversationId,
  }) async {
    const tool = 'write_file';
    final path = _stringArg(args, 'path');
    if (path.isEmpty) {
      return _errorResult(
        tool: tool,
        error: 'invalid_arguments',
        message: 'path is required',
      );
    }
    final content = args.containsKey('content')
        ? args['content']?.toString() ?? ''
        : null;
    if (content == null) {
      return _errorResult(
        tool: tool,
        error: 'invalid_arguments',
        message: 'content is required',
      );
    }
    late final ResolvedPath resolved;
    try {
      resolved = await access.resolve(path, ctx.cwd, write: true);
    } on PathResolutionException catch (e) {
      return _errorResult(tool: tool, error: 'path_error', message: e.message);
    }

    try {
      final result = await HostFileTools(
        ctx.paths,
        access: access,
        checkCancelled: ToolCallCancellation.current?.throwIfCancelled,
      ).writeFile(path, content, cwd: ctx.cwd);
      final link = linkFor(resolved, paths: ctx.paths);
      final body = <String, Object?>{
        'ok': true,
        'path': resolved.modelPath,
        'bytes': result.bytes,
        'created': result.created,
        if (link != null) 'link': link,
      };
      final meta = WorkspaceToolMetadata(
        tool: tool,
        status: 'ok',
        path: resolved.modelPath,
        files: [
          _fileFor(
            ctx,
            resolved,
            role: result.created
                ? WorkspaceFileRole.created
                : WorkspaceFileRole.modified,
          ),
        ],
        created: result.created,
        bytes: result.bytes,
      );
      await _markToolsUsed(ctx, conversationId: conversationId, status: 'ok');
      return ClientToolResult(jsonEncode(body), metadata: meta.toJson());
    } on HostFileException catch (e) {
      return _hostFileFailure(
        tool: tool,
        error: 'write_failed',
        message: e.message,
      );
    }
  }

  Future<Object?> _handleEditFile(
    WorkspaceToolContext ctx,
    Map<String, dynamic> args, {
    required WorkspaceFileAccess access,
    required String toolCallId,
    ToolApprovalService? approvalService,
    String? conversationId,
  }) async {
    const tool = 'edit_file';
    final path = _stringArg(args, 'path');
    if (path.isEmpty) {
      return _errorResult(
        tool: tool,
        error: 'invalid_arguments',
        message: 'path is required',
      );
    }
    if (!args.containsKey('old_string') || !args.containsKey('new_string')) {
      return _errorResult(
        tool: tool,
        error: 'invalid_arguments',
        message: 'old_string and new_string are required',
      );
    }
    late final ResolvedPath resolved;
    try {
      resolved = await access.resolve(path, ctx.cwd, write: true);
    } on PathResolutionException catch (e) {
      return _errorResult(tool: tool, error: 'path_error', message: e.message);
    }

    try {
      final result =
          await HostFileTools(
            ctx.paths,
            access: access,
            checkCancelled: ToolCallCancellation.current?.throwIfCancelled,
          ).editFile(
            path,
            args['old_string']?.toString() ?? '',
            args['new_string']?.toString() ?? '',
            replaceAll: _boolArg(args, 'replace_all'),
            cwd: ctx.cwd,
          );
      final link = linkFor(resolved, paths: ctx.paths);
      final body = <String, Object?>{
        'ok': true,
        'path': resolved.modelPath,
        'replacements': result.replacements,
        'strategy': result.strategy,
        'added': result.diff.added,
        'removed': result.diff.removed,
        if (link != null) 'link': link,
      };
      final meta = WorkspaceToolMetadata(
        tool: tool,
        status: 'ok',
        path: resolved.modelPath,
        files: [
          _fileFor(
            ctx,
            resolved,
            role: result.changed
                ? WorkspaceFileRole.modified
                : WorkspaceFileRole.referenced,
          ),
        ],
        diff: result.diff.text,
        added: result.diff.added,
        removed: result.diff.removed,
        diffTruncated: result.diff.truncated,
        strategy: result.strategy,
      );
      await _markToolsUsed(ctx, conversationId: conversationId, status: 'ok');
      return ClientToolResult(jsonEncode(body), metadata: meta.toJson());
    } on HostFileException catch (e) {
      return _hostFileFailure(
        tool: tool,
        error: 'edit_failed',
        message: e.message,
      );
    }
  }

  Future<Object?> _handleListDir(
    WorkspaceToolContext ctx,
    Map<String, dynamic> args,
    WorkspaceFileAccess access,
  ) async {
    const tool = 'list_dir';
    final path = _stringArg(args, 'path', fallback: ctx.cwd);

    // Models occasionally pass an attached ZIP to list_dir despite the
    // attachment instructions. Treat it as an archive file and return its
    // manifest instead of a misleading "directory not found" error.
    if (p.extension(path).toLowerCase() == '.zip') {
      try {
        final resolved = await access.resolve(path, ctx.cwd);
        if (ctx.skillsOnly && resolved.zone != WorkspaceZone.skills) {
          return _errorResult(
            tool: tool,
            error: 'path_outside_skills',
            message: 'list_dir is limited to /skills in skills-only mode',
          );
        }
        final archive = await HostFileTools(
          ctx.paths,
          access: access,
        ).readFile(path, cwd: ctx.cwd);
        if (!archive.archive) {
          return _errorResult(
            tool: tool,
            error: 'zip_inspection_failed',
            message: 'The supplied .zip path did not produce a ZIP manifest.',
          );
        }
        final meta = WorkspaceToolMetadata(
          tool: tool,
          status: 'ok',
          path: resolved.modelPath,
          files: [_fileFor(ctx, resolved)],
          count: archive.archiveEntries.length,
          truncated: archive.archiveEntriesTruncated,
        );
        await _markToolsUsed(
          ctx,
          conversationId: ctx.conversationId,
          status: 'ok',
        );
        return ClientToolResult(
          jsonEncode(<String, Object?>{
            'archive': true,
            'format': 'zip',
            'path': resolved.modelPath,
            'entries': [
              for (final entry in archive.archiveEntries) entry.toJson(),
            ],
            'entries_truncated': archive.archiveEntriesTruncated,
            'note':
              'This attachment is a ZIP file, not a directory. For inspection '
              'call read_file with archive_entry. For a Skill import call '
              'extension_install directly with this exact ZIP path.',
          }),
          metadata: meta.toJson(),
        );
      } on HostFileException catch (e) {
        final missing = e.message.startsWith('file not found:');
        return _errorResult(
          tool: tool,
          error: missing ? 'zip_attachment_missing' : 'zip_inspection_failed',
          message: missing
              ? 'The ZIP attachment is not present in this conversation workspace at $path. Reattach the file or retry after attachment sync completes. Details: ${e.message}'
              : 'The ZIP attachment could not be inspected at $path. Details: ${e.message}',
        );
      } on PathResolutionException catch (e) {
        return _errorResult(
          tool: tool,
          error: 'path_error',
          message: e.message,
        );
      }
    }

    try {
      final result = await HostFileTools(
        ctx.paths,
        access: access,
      ).listDir(path, depth: _intArg(args, 'depth') ?? 1, cwd: ctx.cwd);
      final lines = <String>[
        for (final entry in result.entries)
          entry.isDirectory ? '${entry.path}/' : '${entry.path}  ${entry.size}',
      ];
      if (result.truncated) lines.add('... truncated');
      ResolvedPath? resolved;
      try {
        resolved = await access.resolve(path, ctx.cwd);
      } catch (_) {}
      final meta = WorkspaceToolMetadata(
        tool: tool,
        status: 'ok',
        path: resolved?.modelPath,
        files: await _referencedFiles(ctx, [
          if (resolved != null) resolved.modelPath,
          for (final entry in result.entries) entry.path,
        ]),
        filesTruncated: result.truncated,
        count: result.entries.length,
        truncated: result.truncated,
      );
      await _markToolsUsed(
        ctx,
        conversationId: ctx.conversationId,
        status: 'ok',
      );
      return ClientToolResult(lines.join('\n'), metadata: meta.toJson());
    } on HostFileException catch (e) {
      return _errorResult(tool: tool, error: 'list_failed', message: e.message);
    } on PathResolutionException catch (e) {
      return _errorResult(tool: tool, error: 'path_error', message: e.message);
    }
  }

  Future<Object?> _handleGlob(
    WorkspaceToolContext ctx,
    Map<String, dynamic> args,
    WorkspaceFileAccess access,
  ) async {
    const tool = 'glob';
    final pattern = _stringArg(args, 'pattern');
    if (pattern.isEmpty) {
      return _errorResult(
        tool: tool,
        error: 'invalid_arguments',
        message: 'pattern is required',
      );
    }
    try {
      final result = await HostFileTools(
        ctx.paths,
        access: access,
      ).glob(pattern, path: _optionalString(args, 'path'), cwd: ctx.cwd);
      final lines = List<String>.from(result.paths);
      if (result.truncated) lines.add('... truncated');
      final meta = WorkspaceToolMetadata(
        tool: tool,
        status: 'ok',
        files: await _referencedFiles(ctx, result.paths),
        filesTruncated: result.truncated,
        count: result.paths.length,
        truncated: result.truncated,
      );
      await _markToolsUsed(
        ctx,
        conversationId: ctx.conversationId,
        status: 'ok',
      );
      return ClientToolResult(lines.join('\n'), metadata: meta.toJson());
    } on HostFileException catch (e) {
      return _errorResult(tool: tool, error: 'glob_failed', message: e.message);
    } on PathResolutionException catch (e) {
      return _errorResult(tool: tool, error: 'path_error', message: e.message);
    }
  }

  Future<Object?> _handleGrep(
    WorkspaceToolContext ctx,
    Map<String, dynamic> args,
    WorkspaceFileAccess access,
  ) async {
    const tool = 'grep';
    final pattern = _stringArg(args, 'pattern');
    if (pattern.isEmpty) {
      return _errorResult(
        tool: tool,
        error: 'invalid_arguments',
        message: 'pattern is required',
      );
    }
    try {
      final result = await HostFileTools(ctx.paths, access: access).grep(
        pattern,
        path: _optionalString(args, 'path'),
        cwd: ctx.cwd,
        ignoreCase: _boolArg(args, 'ignore_case'),
        limit: _intArg(args, 'limit') ?? HostFileTools.defaultGrepLimit,
      );
      final lines = [for (final match in result.matches) match.display];
      if (result.truncated) lines.add('... truncated');
      final meta = WorkspaceToolMetadata(
        tool: tool,
        status: 'ok',
        files: await _referencedFiles(
          ctx,
          result.matches.map((match) => match.path),
        ),
        filesTruncated: result.truncated,
        count: result.matches.length,
        truncated: result.truncated,
      );
      await _markToolsUsed(
        ctx,
        conversationId: ctx.conversationId,
        status: 'ok',
      );
      return ClientToolResult(lines.join('\n'), metadata: meta.toJson());
    } on HostFileException catch (e) {
      return _errorResult(tool: tool, error: 'grep_failed', message: e.message);
    } on PathResolutionException catch (e) {
      return _errorResult(tool: tool, error: 'path_error', message: e.message);
    }
  }

  Future<void> _markToolsUsed(
    WorkspaceToolContext ctx, {
    String? conversationId,
    required String status,
  }) async {
    if (ctx.skillsOnly || ctx.conversationScoped) return;
    if (status != 'ok') return;
    if (ctx.binding.toolsUsed) return;
    final id = conversationId ?? ctx.conversationId;
    if (id == null || id.isEmpty) return;
    try {
      await updateConversationExtras?.call(id, (extras) {
        final current = WorkspaceBinding.fromExtras(extras);
        if (current.workspaceId != ctx.binding.workspaceId) return extras;
        return WorkspaceBinding(
          workspaceId: current.workspaceId,
          cwd: current.cwd,
          toolsUsed: true,
        ).applyTo(extras);
      });
      await touchLastUsed?.call(ctx.workspace.id);
    } catch (e) {
      debugPrint('Failed to mark workspace tools used: $e');
    }
  }

  static ClientToolResult _errorResult({
    required String tool,
    required String error,
    required String message,
    String? instruction,
    WorkspaceToolMetadata? meta,
  }) {
    return ClientToolResult(
      jsonEncode(<String, Object?>{
        'type': 'tool_error',
        'error': error,
        'message': message,
        'tool': tool,
        if (instruction != null) 'instruction': instruction,
      }),
      metadata:
          (meta ??
                  WorkspaceToolMetadata(
                    tool: tool,
                    status: 'error',
                    code: error,
                  ))
              .toJson(),
    );
  }

  static ClientToolResult _deniedResult({
    required String tool,
    required String error,
    required String message,
    String? path,
  }) {
    return ClientToolResult(
      jsonEncode(<String, Object?>{
        'type': 'tool_error',
        'error': error,
        'message': message,
        'tool': tool,
      }),
      metadata: WorkspaceToolMetadata(
        tool: tool,
        status: 'denied',
        code: error,
        path: path,
      ).toJson(),
    );
  }

  static ClientToolResult _hostFileFailure({
    required String tool,
    required String error,
    required String message,
  }) {
    return ClientToolResult(
      jsonEncode(<String, Object?>{'error': error, 'message': message}),
      metadata: WorkspaceToolMetadata(
        tool: tool,
        status: 'error',
        code: error,
      ).toJson(),
    );
  }

  static Map<String, dynamic> _fn(
    String name,
    List<String> description,
    Map<String, dynamic> properties,
    List<String> required,
  ) {
    return <String, dynamic>{
      'type': 'function',
      'function': <String, dynamic>{
        'name': name,
        if (name == 'view_image') 'strict': false,
        'description': description.join(' '),
        'parameters': <String, dynamic>{
          'type': 'object',
          'properties': properties,
          if (name == 'view_image') 'additionalProperties': false,
          if (required.isNotEmpty) 'required': required,
        },
      },
    };
  }

  static List<String> _pathVocab(WorkspacePaths paths) {
    if (paths.sandboxed) {
      return [
        WorkspacePaths.guestWorkspace,
        WorkspacePaths.guestChat,
        WorkspacePaths.guestSkills,
        WorkspacePaths.guestTmp,
        ExternalMount.root,
      ];
    }
    return [
      paths.workspaceHostRoot,
      paths.sessionHostDir,
      paths.skillsHostDir,
      paths.tmpHostRoot,
    ];
  }

  static String _engineLine(WorkspaceToolContext ctx) {
    final status = ctx.runtimeStatus;
    if (!ctx.runtimeRegistered || status == null || !status.ready) {
      return 'Sandbox environment not installed — `shell` will fail until the user installs it';
    }
    switch (status.engine) {
      case 'proot':
        return 'Engine: Linux (PRoot); check /etc/os-release for distro';
      case 'ish':
        return 'Engine: Alpine (iSH)';
      case 'process':
      case 'fake':
        return 'Engine: native shell';
      default:
        return 'Engine: ${status.engine}';
    }
  }

  static Map<String, dynamic> _shellPayload(String modelText) {
    final jsonLine = modelText.split('\n').first;
    try {
      final decoded = jsonDecode(jsonLine);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return <String, dynamic>{'stdout': modelText, 'stderr': ''};
  }

  Future<void> _maybeNoteSkillRead(
    WorkspaceToolContext ctx,
    ResolvedPath resolved,
  ) async {
    if (onSkillRead == null) return;
    if (resolved.zone != WorkspaceZone.skills) return;
    final base = p.basename(resolved.hostPath.replaceAll('\\', '/'));
    final modelBase = p.posix.basename(
      resolved.modelPath.replaceAll('\\', '/'),
    );
    // Windows path canonicalization lowercases SKILL.md along with its parents.
    if (base.toLowerCase() != 'skill.md' &&
        modelBase.toLowerCase() != 'skill.md') {
      return;
    }
    final skillId = _skillIdUnderSkillsRoot(ctx, resolved);
    if (skillId == null || skillId.isEmpty) return;
    try {
      await onSkillRead!(skillId);
    } catch (e) {
      debugPrint('onSkillRead failed: $e');
    }
  }

  static String? _skillIdUnderSkillsRoot(
    WorkspaceToolContext ctx,
    ResolvedPath resolved,
  ) {
    final model = resolved.modelPath.replaceAll('\\', '/');
    const prefix = '${WorkspacePaths.guestSkills}/';
    if (model.startsWith(prefix)) {
      final rel = model.substring(prefix.length);
      if (rel.isEmpty) return null;
      return rel.split('/').first;
    }
    final rel = WorkspacePaths.relativeToHostRoot(
      ctx.paths.skillsHostDir,
      resolved.hostPath,
    );
    if (rel != null && rel.isNotEmpty) {
      return rel.replaceAll('\\', '/').split('/').first;
    }
    try {
      final root = p.canonicalize(
        Directory(ctx.paths.skillsHostDir).resolveSymbolicLinksSync(),
      );
      final host = p.canonicalize(
        File(resolved.hostPath).resolveSymbolicLinksSync(),
      );
      if (p.isWithin(root, host)) {
        return p
            .relative(host, from: root)
            .replaceAll('\\', '/')
            .split('/')
            .first;
      }
    } catch (_) {}
    return null;
  }

  static String _stringArg(
    Map<String, dynamic> args,
    String key, {
    String fallback = '',
  }) {
    final value = args[key];
    if (value == null) return fallback;
    return value.toString();
  }

  static String? _optionalString(Map<String, dynamic> args, String key) {
    final value = args[key];
    if (value == null) return null;
    final text = value.toString();
    return text.isEmpty ? null : text;
  }

  static int? _intArg(Map<String, dynamic> args, String key) {
    final value = args[key];
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static bool _boolArg(Map<String, dynamic> args, String key) {
    final value = args[key];
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }
}
