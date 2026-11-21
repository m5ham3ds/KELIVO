import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:Kelivo/core/models/tool_permission_mode.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/services/conversation_tool_permissions.dart';
import 'package:Kelivo/utils/mcp_structured_image.dart';

import '../../../core/models/assistant.dart';
import '../../../core/models/message_part.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/model_spec.dart';
import '../../../core/models/reasoning_request.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/environment_provider.dart';
import '../../../core/providers/mcp_provider.dart';
import '../../../core/providers/memory_provider.dart';
import '../../../core/providers/memory_provider_v2.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/tts_provider.dart';
import '../../../core/providers/workspace_provider.dart';
import '../../../core/services/api/builtin_tools.dart' as native_tools;
import '../../../core/services/api/chat_api_service.dart';
import '../../../core/services/api/json_schema_utils.dart';
import '../../../core/services/api/request_image_context.dart';
import '../../../core/services/browser/browser_tools_service.dart';
import '../../../core/services/browser/browser_service.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../core/services/extensions/conversational_extension_service.dart';
import '../../../core/services/extensions/extension_command_tools.dart';
import '../../../core/services/extensions/skill_execution_tools.dart';
import '../../../core/services/skills/skill_executor.dart';
import '../../../core/services/skills/skill_import_progress.dart';
import '../../../core/services/skills/skill_execution_security.dart';
import '../../../core/services/skills/skill_execution_permissions.dart';
import '../../../core/services/skills/skill_frontmatter.dart';
import '../../../core/services/extensions/extension_operation_repository.dart';
import '../../../core/services/extensions/extension_registry_repository.dart';
import '../../../core/services/extensions/skill_composition_tools.dart';
import '../../../core/services/packages/package_manager_service.dart';
import '../../../core/services/packages/package_manager_tools.dart';
import '../../../core/services/sandbox/environment_status_tool.dart';
import '../../../core/services/storage/kelivo_public_storage.dart';
import '../../../core/services/runtime_profiles/runtime_profile_models.dart';
import '../../../core/services/runtime_profiles/runtime_profile_service.dart';
import '../../../core/services/runtime_profiles/runtime_profile_tools.dart';
import '../../../core/services/video_engines/video_engine_service.dart';
import '../../../core/services/video_engines/video_engine_tools.dart';
import '../../../core/services/video_production/video_production_service.dart';
import '../../../core/services/video_production/video_production_tools.dart';
import '../../../core/services/video_providers/video_provider_connector_service.dart';
import '../../../core/services/video_providers/video_provider_credential_store.dart';
import '../../../core/services/video_providers/video_provider_tools.dart';
import '../../../core/services/video_hybrid/video_hybrid_workflow_service.dart';
import '../../../core/services/video_hybrid/video_hybrid_workflow_tools.dart';
import '../../../core/services/video_quality/video_quality_service.dart';
import '../../../core/services/video_quality/video_quality_tools.dart';
import '../../../core/database/extension_entity_store.dart';
import '../../../core/services/mcp/mcp_tool_service.dart';
import '../../../core/services/memory/memory_pipeline.dart';
import '../../../core/services/memory/memory_tools.dart';
import '../../../core/services/model_spec/model_spec_resolver.dart';
import '../../../core/services/search/search_tool_service.dart';
import '../../../core/services/search/web_fetch_service.dart';
import '../../../core/services/search/web_fetch_tool_service.dart';
import '../../../core/services/skills/skills_service.dart';
import '../../../core/services/skills/skill_composition_planner.dart';
import '../../../core/services/skills/skill_composition_service.dart';
import '../../../core/models/skills_binding.dart';
import '../../../core/services/tools/tool_schema_overrides.dart';
import '../../../core/services/workspace/tool_run_registry.dart';
import '../../../core/services/workspace/workspace_runtime.dart';
import '../../../core/services/workspace/workspace_tools_service.dart';
import 'ask_user_interaction_service.dart';
import 'built_in_tool_names.dart';
import 'local_tools_service.dart';
import 'tool_approval_service.dart';
import '../../../core/services/mobile_background.dart';

/// 工具调用处理服务
///
/// 处理各类工具调用：
/// - MCP 工具
/// - Memory 工具 (§10)
/// - Search 工具
class ToolHandlerService {
  ToolHandlerService({required this.contextProvider});

  /// Build context (used for accessing providers)
  final BuildContext contextProvider;

  WorkspaceToolsService _workspaceTools() {
    try {
      final chat = contextProvider.read<ChatService>();
      final workspaces = contextProvider.read<WorkspaceProvider>();
      Future<void> Function(String skillId)? onSkillRead;
      Future<void> Function()? onShellCompleted;
      try {
        final skills = contextProvider.read<SkillsService>();
        onSkillRead = skills.incrementUseCount;
        onShellCompleted = skills.rescan;
      } catch (_) {}
      return WorkspaceToolsService(
        registry: contextProvider.read<ToolRunRegistry>(),
        runtimeProvider: contextProvider.read<WorkspaceRuntimeProvider>(),
        runtimeProfiles: RuntimeProfileService(
          store: contextProvider.read<ExtensionEntityStore>(),
          runtimeProvider: contextProvider.read<WorkspaceRuntimeProvider>(),
        ),
        updateConversationExtras: chat.updateConversationExtras,
        readPermissionState: ConversationToolPermissions.forChat(chat).read,
        permissionChanges: chat,
        touchLastUsed: workspaces.touchLastUsed,
        onSkillRead: onSkillRead,
        onShellCompleted: onShellCompleted,
        loadEnvironment: contextProvider
            .read<EnvironmentProvider?>()
            ?.loadExecutionConfig,
        isToolEnabled: (id, name) =>
            workspaces.byId(id)?.isToolEnabled(name) ?? false,
      );
    } catch (_) {
      return WorkspaceToolsService();
    }
  }

  // ============================================================================
  // Tool Schema Sanitization
  // ============================================================================

  /// Sanitize/translate JSON Schema to each provider's accepted subset.
  ///
  /// Different providers (Google, OpenAI, Claude) have different requirements
  /// for tool parameter schemas. This method normalizes schemas to work across
  /// all providers.
  static Map<String, dynamic> sanitizeToolParametersForProvider(
    Map<String, dynamic> schema,
    ProviderKind kind,
  ) {
    Map<String, dynamic> clone = _deepCloneMap(schema);
    // Inline local references before translating provider-specific schema fields.
    clone = resolveJsonSchemaRefs(
      clone,
      preserveJsonSchema: kind != ProviderKind.google,
    );
    if (kind != ProviderKind.google) return clone;
    return _sanitizeGoogleNode(clone) as Map<String, dynamic>;
  }

  static dynamic _sanitizeGoogleNode(dynamic node) {
    if (node is List) {
      return node.map(_sanitizeGoogleNode).toList();
    }
    if (node is! Map) return node;

    final m = Map<String, dynamic>.from(node);
    // Remove $schema as it's not needed for tool definitions
    m.remove(r'$schema');

    // Google's native Schema does not have const.
    if (m.containsKey('const')) {
      final v = m['const'];
      if (v is String || v is num || v is bool) {
        m['enum'] = [v];
        // Keep the declared type in sync so a non-string const is not mistaken
        // for a string enum downstream.
        if (m['type'] == null) {
          if (v is bool) {
            m['type'] = 'boolean';
          } else if (v is int) {
            m['type'] = 'integer';
          } else if (v is num) {
            m['type'] = 'number';
          } else {
            m['type'] = 'string';
          }
        }
      }
      m.remove('const');
    }

    // Keep Google's existing conversion to the native Schema subset.
    for (final key in [
      'anyOf',
      'oneOf',
      'allOf',
      'any_of',
      'one_of',
      'all_of',
    ]) {
      final variants = m[key];
      if (variants is! List) continue;
      if (variants.isNotEmpty) {
        final first = variants.first;
        final flattened = _sanitizeGoogleNode(first);
        m.remove(key);
        if (flattened is Map<String, dynamic>) {
          m
            ..remove('type')
            ..remove('properties')
            ..remove('items');
          m.addAll(flattened);
        }
      }
    }

    // Google's native Schema needs a single type.
    final t = m['type'];
    if (t is List && t.isNotEmpty) {
      m['type'] = t.first.toString();
    }

    // Keep Google's existing conversion of tuple-form items.
    final items = m['items'];
    if (items is List && items.isNotEmpty) {
      m['items'] = items.first;
    }
    if (m['items'] is Map || m['items'] is List) {
      m['items'] = _sanitizeGoogleNode(m['items']);
    }

    if (m['properties'] is Map) {
      final props = Map<String, dynamic>.from(m['properties']);
      final norm = <String, dynamic>{};
      props.forEach((k, v) {
        norm[k] = _sanitizeGoogleNode(v);
      });
      m['properties'] = norm;
    }

    const allowed = {
      'type',
      'description',
      'properties',
      'required',
      'items',
      'enum',
    };
    m.removeWhere((k, v) => !allowed.contains(k));
    return m;
  }

  static Map<String, dynamic> _deepCloneMap(Map<String, dynamic> input) {
    return jsonDecode(jsonEncode(input)) as Map<String, dynamic>;
  }

  static String _toolError({
    required String error,
    required String message,
    required String tool,
    String? instruction,
  }) {
    return jsonEncode({
      'type': 'tool_error',
      'error': error,
      'message': message,
      'tool': tool,
      if (instruction != null) 'instruction': instruction,
    });
  }

  // ============================================================================
  // Tool Definitions Builder
  // ============================================================================

  McpToolRouteSnapshot captureMcpToolRoutes(
    Assistant? assistant, {
    String? conversationId,
  }) {
    return contextProvider.read<McpToolService>().captureRoutesForAssistant(
      contextProvider.read<McpProvider>(),
      contextProvider.read<AssistantProvider>(),
      assistantId: assistant?.id,
      conversation: conversationId == null
          ? null
          : contextProvider.read<ChatService>().getConversation(conversationId),
      reservedNames: BuiltInToolNames.all,
    );
  }

  /// Build tool definitions for API call.
  ///
  /// Returns a list of tool definitions including:
  /// - Search tool (if enabled and model supports tools)
  /// - Memory tools (if assistant has memory / past-recall enabled)
  /// - MCP tools (from the effective conversation or assistant selection)
  /// Whether the chat being generated is a throwaway one.
  ///
  /// Scheduled sends can target a different conversation from the visible one.
  bool _isTemporaryConversation(String? conversationId) {
    try {
      final chatService = contextProvider.read<ChatService>();
      return chatService.isTemporaryConversation(
        conversationId ?? chatService.currentConversationId,
      );
    } catch (_) {
      return false;
    }
  }

  List<Map<String, dynamic>> buildToolDefinitions(
    SettingsProvider settings,
    Assistant? assistant,
    String providerKey,
    String modelId,
    bool hasBuiltInSearch, {
    required bool Function(String providerKey, String modelId) isToolModel,
    McpToolRouteSnapshot? mcpRouteSnapshot,
    WorkspaceToolContext? workspaceContext,
    String? conversationId,
  }) {
    final List<Map<String, dynamic>> toolDefs = <Map<String, dynamic>>[];
    final supportsTools = isToolModel(providerKey, modelId);
    // Keep this candidate for images returned later in the tool loop.
    // RequestImageContext gates its declaration on every outgoing request.
    if (supportsTools &&
        conversationId != null &&
        ModelSpecResolver.instance
            .spec(settings.getProviderConfig(providerKey), modelId)
            .supportsImageInput) {
      toolDefs.add({
        'type': 'function',
        'function': {
          'name': 'read_chat_image',
          'description':
              'Read an image from this conversation using its image_id. Omit image_id to list available images, then use next_offset to list more. Reading adds a fresh observation without rewriting earlier history.',
          'parameters': {
            'type': 'object',
            'properties': {
              'image_id': {
                'type': 'string',
                'description':
                    'The img_ identifier from an image placeholder or listing.',
              },
              'offset': {
                'type': 'integer',
                'minimum': 0,
                'description': 'Offset for listing images; default 0.',
              },
            },

            'additionalProperties': false,
          },
        },
      });
    }

    // Search tool (skip when Gemini built-in search is active)
    if (assistant?.searchEnabled == true &&
        !hasBuiltInSearch &&
        supportsTools) {
      toolDefs.add(SearchToolService.getToolDefinition());
      if (settings.webFetchMode != WebFetchMode.off &&
          !native_tools.BuiltInToolsHelper.isBuiltInFetchEnabled(
            cfg: settings.getProviderConfig(providerKey),
            modelId: modelId,
          )) {
        toolDefs.add(WebFetchToolService.getToolDefinition());
      }
    }

    // Memory tools (§10.1)
    if (settings.legacyMemoryMode) {
      if (assistant?.enableMemory == true && supportsTools) {
        toolDefs.addAll(
          MemoryTools.legacyDefinitions(settings.resolvedMemoryPromptLang),
        );
      }
    } else if (supportsTools && assistant != null) {
      toolDefs.addAll(
        MemoryTools.buildDefinitions(
          lang: settings.resolvedMemoryPromptLang,
          writeScope: assistant.memoryWriteScope,
          enableMemory: assistant.enableMemory,
          allowPastConversationRecall: assistant.allowPastConversationRecall,
          allowMemoryWrites: !_isTemporaryConversation(conversationId),
        ),
      );
    }

    // Local tools
    toolDefs.addAll(
      LocalToolsService.buildToolDefinitions(
        assistant: assistant,
        supportsTools: supportsTools,
      ).where(
        // Browser is a global capability, not an assistant-local checkbox.
        (definition) =>
            (definition['function'] as Map)['name'] !=
                BrowserToolsService.toolName,
      ),
    );
    if (supportsTools &&
        conversationId != null &&
        BrowserService.instance.isSupported &&
        BrowserService.instance.isInitialized &&
        BrowserService.instance.settings.agentEnabled &&
        !toolDefs.any(
          (definition) =>
              (definition['function'] as Map)['name'] ==
              BrowserToolsService.toolName,
        )) {
      toolDefs.add(BrowserToolsService.getToolDefinition());
    }

    // Conversation-first extension management. These tools are core control
    // plane capabilities, not workspace shell commands, so they remain
    // available even when no workspace is bound.
    if (supportsTools) {
      toolDefs.addAll(ExtensionCommandToolCatalog.definitions());
      toolDefs.addAll(SkillCompositionToolCatalog.definitions());
      // Skill execution needs a real workspace context (a selected project or
      // a private per-conversation scratch workspace), plus a registered and
      // ready sandboxed PRoot runtime. Never expose it in skills-only mode.
      if (workspaceContext != null &&
          !workspaceContext.skillsOnly &&
          workspaceContext.hasReadyProotRuntime) {
        toolDefs.addAll(SkillExecutionToolCatalog.definitions());
      }
      toolDefs.addAll(PackageManagerToolCatalog.definitions());
      toolDefs.addAll(EnvironmentStatusToolCatalog.definitions());
    }

    // MCP tools
    final mcpTools = _buildMcpToolDefinitions(
      settings: settings,
      assistant: assistant,
      providerKey: providerKey,
      supportsTools: supportsTools,
      mcpRouteSnapshot: mcpRouteSnapshot,
      conversationId: conversationId,
    );
    toolDefs.addAll(mcpTools);

    if (supportsTools && workspaceContext != null && !workspaceContext.skillsOnly) {
      toolDefs.addAll(VideoEngineToolCatalog.definitions());
      toolDefs.addAll(VideoProductionToolCatalog.definitions());
      toolDefs.addAll(VideoProviderToolCatalog.definitions());
      toolDefs.addAll(VideoHybridWorkflowToolCatalog.definitions());
      toolDefs.addAll(VideoQualityToolCatalog.definitions());
    }

    if (supportsTools && workspaceContext != null) {
      final canImageInput = ModelSpecResolver.instance
          .spec(settings.getProviderConfig(providerKey), modelId)
          .input
          .contains(Modality.image);
      toolDefs.addAll(
        _workspaceTools()
            .buildToolDefinitions(workspaceContext)
            .where(
              (definition) =>
                  canImageInput ||
                  (definition['function'] as Map)['name'] != 'view_image',
            ),
      );
    }

    final overrides = settings.toolSchemaOverrides;
    if (overrides.isEmpty) return toolDefs;
    return ToolSchemaOverrides.apply(toolDefs, overrides);
  }

  /// Build MCP tool definitions from connected servers.
  List<Map<String, dynamic>> _buildMcpToolDefinitions({
    required SettingsProvider settings,
    required Assistant? assistant,
    required String providerKey,
    required bool supportsTools,
    McpToolRouteSnapshot? mcpRouteSnapshot,
    String? conversationId,
  }) {
    if (!supportsTools) return [];

    final mcp = contextProvider.read<McpProvider>();
    final toolSvc = contextProvider.read<McpToolService>();
    final tools = toolSvc.listAvailableToolsForAssistant(
      mcp,
      contextProvider.read<AssistantProvider>(),
      assistant?.id,
      conversation: conversationId == null
          ? null
          : contextProvider.read<ChatService>().getConversation(conversationId),
      routeSnapshot: mcpRouteSnapshot,
      reservedNames: BuiltInToolNames.all,
    );

    if (tools.isEmpty) return [];

    final providerCfg = settings.getProviderConfig(providerKey);
    final providerKind = ProviderConfig.classify(
      providerCfg.id,
      explicitType: providerCfg.providerType,
    );

    return tools.map((t) {
      Map<String, dynamic> baseSchema;
      if (t.schema != null && t.schema!.isNotEmpty) {
        baseSchema = Map<String, dynamic>.from(t.schema!);
      } else {
        final props = <String, dynamic>{
          for (final p in t.params) p.name: {'type': (p.type ?? 'string')},
        };
        final required = [
          for (final p in t.params.where((e) => e.required)) p.name,
        ];
        baseSchema = {
          'type': 'object',
          'properties': props,
          if (required.isNotEmpty) 'required': required,
        };
      }
      final sanitized = sanitizeToolParametersForProvider(
        baseSchema,
        providerKind,
      );
      return {
        'type': 'function',
        'function': {
          'name': t.name,
          if ((t.description ?? '').isNotEmpty) 'description': t.description,
          'parameters': sanitized,
        },
      };
    }).toList();
  }

  // ============================================================================
  // Tool Call Handler
  // ============================================================================

  /// Build tool call handler function.
  ///
  /// Returns a function that handles tool calls by name and arguments.
  /// Supports:
  /// - Search tool calls
  /// - Memory tool calls (§10)
  /// - MCP tool calls
  ToolCallHandler? buildToolCallHandler(
    SettingsProvider settings,
    Assistant? assistant, {
    ToolApprovalService? approvalService,
    AskUserInteractionService? askUserService,
    String? conversationId,
    McpToolRouteSnapshot? mcpRouteSnapshot,
    WorkspaceToolContext? workspaceContext,
  }) {
    final mcp = contextProvider.read<McpProvider>();
    final toolSvc = contextProvider.read<McpToolService>();
    // Capture AssistantProvider reference before async gap to avoid
    // use_build_context_synchronously warning
    final assistantProvider = contextProvider.read<AssistantProvider>();
    ChatService? permissionChat;
    try {
      permissionChat = contextProvider.read<ChatService>();
    } catch (_) {}
    final routes =
        mcpRouteSnapshot ??
        toolSvc.captureRoutesForAssistant(
          mcp,
          assistantProvider,
          assistantId: assistant?.id,
          conversation: conversationId == null
              ? null
              : permissionChat?.getConversation(conversationId),
          reservedNames: BuiltInToolNames.all,
        );

    String approvalIdFor(String name, String? toolCallId) {
      final trimmed = toolCallId?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
      return '${name}_${DateTime.now().microsecondsSinceEpoch}';
    }

    ToolCallPermission permissionFor(String name, String? toolCallId) =>
        ToolCallPermission(
          toolName: name,
          toolCallId: approvalIdFor(name, toolCallId),
          conversationId: conversationId,
          workspaceId: workspaceContext?.workspace.id,
          assistantId: assistant?.id,
          approvals: approvalService,
          stateChanges: permissionChat,
          readState: () => permissionChat != null && conversationId != null
              ? ConversationToolPermissions.forChat(
                  permissionChat,
                ).read(conversationId)
              : ToolPermissionState(
                  mode:
                      workspaceContext?.permissionMode ??
                      ToolPermissionMode.requestApproval,
                  workspaceId: workspaceContext?.workspace.id,
                  assistantId: assistant?.id,
                ),
        );
    Future<Object?> approveAndExecuteMcp(
      String name,
      Map<String, dynamic> args,
      ToolCallPermission permission,
    ) async {
      void checkEnabled() {
        if (!toolSvc.isToolEnabledForAssistant(
          mcp,
          assistantProvider,
          assistantId: assistant?.id,
          conversation: conversationId == null
              ? null
              : permissionChat?.getConversation(conversationId),
          toolName: name,
          routeSnapshot: routes,
        )) {
          throw const ToolPermissionException(
            'tool_disabled',
            'This MCP tool is disabled',
          );
        }
      }

      checkEnabled();
      await permission.authorize(
        needed: toolSvc.toolNeedsApprovalForAssistant(
          mcp,
          assistantProvider,
          assistantId: assistant?.id,
          conversation: conversationId == null
              ? null
              : permissionChat?.getConversation(conversationId),
          toolName: name,
          routeSnapshot: routes,
          reservedNames: BuiltInToolNames.all,
        ),
        arguments: args,
      );
      checkEnabled();
      return toolSvc.callToolForAssistant(
        mcp,
        assistantProvider,
        assistantId: assistant?.id,
        conversation: conversationId == null
            ? null
            : permissionChat?.getConversation(conversationId),
        toolName: name,
        arguments: args,
        routeSnapshot: routes,
        reservedNames: BuiltInToolNames.all,
      );
    }

    final workspaceTools = workspaceContext == null ? null : _workspaceTools();

    return (name, args, {toolCallId}) async {
      final permission = permissionFor(name, toolCallId);
      Future<Object?> execute() async {
        try {
          if (name == SkillExecutionToolNames.execute) {
            final workspace = workspaceContext;
            if (workspace == null || workspace.skillsOnly) {
              throw const SkillExecutionException('workspace_required');
            }
            // Capture providers before any user-approval await. The execution
            // bridge is never allowed to resolve a different Skill scope after
            // the approval prompt has been displayed.
            final skills = contextProvider.read<SkillsService>();
            final registry = contextProvider.read<ExtensionRegistryRepository>();
            final runtimeProvider = contextProvider.read<WorkspaceRuntimeProvider>();
            final entityStore = contextProvider.read<ExtensionEntityStore>();
            // Resolve the process-wide runtime before building the approval
            // review or executing a Skill. Capturing runtimeProvider.runtime
            // earlier can race native PRoot bootstrap after a RootFS install.
            final runtime = await runtimeProvider.ensureInitialized();
            if (runtime == null) {
              throw SkillExecutionException(
                runtimeProvider.initializationError ?? 'runtime_unavailable',
              );
            }
            final runtimeStatus = await runtime.status();
            if (!runtimeStatus.ready ||
                !runtimeStatus.sandboxed ||
                runtimeStatus.engine != 'proot') {
              throw SkillExecutionException(
                runtimeStatus.reason ?? 'skill_execution_requires_android_proot',
              );
            }
            final profileService = RuntimeProfileService(
              store: entityStore,
              runtimeProvider: runtimeProvider,
            );
            await skills.loaded;

            final task = SkillCompositionPlanner.compactTaskBrief(
              (args['task'] ?? '').toString(),
            );
            final skillId = (args['skill_id'] ?? '').toString().trim();
            final entryPoint = (args['entry_point'] ?? '').toString();
            final runtimeProfileId = (args['runtime_profile_id'] ?? '').toString().trim();
            if (task.isEmpty || task.runes.length > SkillCompositionPlanner.maxTaskCharacters || skillId.isEmpty ||
                entryPoint.isEmpty || runtimeProfileId.isEmpty) {
              throw const SkillExecutionException('invalid_skill_execution_arguments');
            }
            List<String>? conversationOverride;
            if (conversationId != null && conversationId.isNotEmpty) {
              final conversation = permissionChat?.getConversation(conversationId);
              if (conversation != null) {
                conversationOverride = SkillsBinding.fromExtras(
                  conversation.extras,
                ).skillIds;
              }
            }
            final selectionMode = SkillCompositionMode.parse(
              args['selection_mode'] ?? 'explicit',
            );
            if (selectionMode != SkillCompositionMode.explicit &&
                selectionMode != SkillCompositionMode.allEnabled) {
              throw const SkillExecutionException('invalid_skill_execution_selection_mode');
            }
            final candidates = selectionMode == SkillCompositionMode.allEnabled
                ? skills.resolveForAssistant(null)
                : skills.resolveForAssistant(
                    assistant,
                    conversationOverride: conversationOverride,
                  );
            final selected = candidates.where(
              (item) => item.record.id == skillId,
            ).firstOrNull;
            if (selected == null) {
              throw const SkillExecutionException('skill_not_enabled_for_current_context');
            }
            final importManifest = await skills.getImportReport(skillId);
            if (importManifest == null) {
              throw const SkillExecutionException('skill_import_manifest_missing_reimport_required');
            }

            // Rebuild the dependency-aware plan server-side. Model-supplied
            // stage data is not accepted as an execution authority.
            final composition = SkillCompositionService(
              skills: skills,
              registry: registry,
            );
            final compositionJson = await composition.compose(
              task: SkillCompositionPlanner.compactTaskBrief(task),
              availableSkills: candidates,
              mode: selectionMode,
              requestedSkillIds: selectionMode == SkillCompositionMode.explicit
                  ? [skillId]
                  : const <String>[],
              excludedSkillIds: const <String>[],
              allowParallel: false,
            );
            final decodedPlan = jsonDecode(compositionJson);
            if (decodedPlan is! Map) {
              throw const SkillExecutionException('invalid_server_composition_plan');
            }
            final compositionPlan = Map<String, Object?>.from(decodedPlan);
            final rawSelectedIds = compositionPlan['selectedSkillIds'];
            if (rawSelectedIds is! List || rawSelectedIds.isEmpty ||
                rawSelectedIds.length > 64 || rawSelectedIds.any((id) => id is! String)) {
              throw const SkillExecutionException('invalid_selected_skill_snapshot');
            }
            final selectedSourceDigests = <String, String>{};
            for (final selectedId in rawSelectedIds.cast<String>()) {
              final selectedManifest = selectedId == skillId
                  ? importManifest
                  : await skills.getImportReport(selectedId);
              if (selectedManifest == null ||
                  selectedManifest['completeness'] != 'complete' ||
                  selectedManifest['sourceDigest'] is! String ||
                  (selectedManifest['sourceDigest'] as String).isEmpty) {
                throw SkillExecutionException(
                  'selected_skill_requires_complete_import_manifest:$selectedId',
                );
              }
              selectedSourceDigests[selectedId] = selectedManifest['sourceDigest'] as String;
            }

            final markdown = await skills.readSkillMarkdown(
              skillId,
              maxCharacters: 64000,
            );
            final frontmatter = SkillFrontmatter.parse(markdown);
            if (!frontmatter.hasFrontmatter ||
                frontmatter.parseError != null ||
                !frontmatter.metadataIsValid ||
                frontmatter.validate().isNotEmpty) {
              throw const SkillExecutionException('skill_permission_frontmatter_invalid');
            }
            final declaredPermissions = (frontmatter.metadata['kelivo.permissions'] ?? '')
                .split(RegExp(r'[,;\s]+'))
                .map((value) => value.trim())
                .where((value) => value.isNotEmpty);
            // PRoot is not a kernel security boundary. These capabilities are
            // included in every execution review because a script can reach
            // the network and package tools from inside the guest. Workspace
            // writes are scoped to the temporary run mount; existing project,
            // chat and installed-Skill trees are not attached.
            final permissionReview = SkillExecutionPermissionPolicy.reviewForSkill(
              declaredPermissions,
            );
            if (permissionReview.any((item) => item['blockedUntilReviewed'] == true)) {
              throw const SkillExecutionException('skill_declares_unrecognized_permissions');
            }

            // The summary API accepts identifiers/counts only; raw task text,
            // argv, input values and file paths cannot enter pending approval state.
            final executionGrantId = const Uuid().v4();
            final approvalArguments = SkillExecutionSecurityPolicy.approvalSummary(
              executionGrantId: executionGrantId,
              skillId: skillId,
              entryPoint: entryPoint,
              runtimeProfileId: runtimeProfileId,
              argumentCount: args['arguments'] is List
                  ? (args['arguments'] as List).length
                  : 0,
              inputCount: args['inputs'] is Map ? (args['inputs'] as Map).length : 0,
              inputFileCount: args['input_files'] is Map
                  ? (args['input_files'] as Map).length
                  : 0,
              expectedOutputCount: args['expected_outputs'] is Map
                  ? (args['expected_outputs'] as Map).length
                  : 0,
              permissionReview: permissionReview,
              workspaceOutputPath: '.kelivo/skill-execution/<run-id>/io/output',
            );
            // Skill code is third-party executable content. Even conversations
            // configured for Full Access must receive a manual approval for
            // each run because the shared PRoot RootFS is writable.
            await permission.authorize(
              needed: true,
              requireManualApproval: true,
              arguments: approvalArguments,
            );
            permission.check();

            Map<String, Object?> readObjectMap(Object? value, String error) {
              if (value == null) return <String, Object?>{};
              if (value is! Map || value.length > 64) {
                throw SkillExecutionException(error);
              }
              return Map<String, Object?>.from(value);
            }
            List<String> readArgumentList(Object? value) {
              if (value == null) return const <String>[];
              if (value is! List || value.length > 64 ||
                  value.any((item) => item is! String ||
                      item.length > 4096 || item.contains('\u0000'))) {
                throw const SkillExecutionException('invalid_skill_arguments');
              }
              return value.cast<String>();
            }
            Map<String, String> readStringMap(Object? value, String error, {int max = 32}) {
              if (value == null) return <String, String>{};
              if (value is! Map || value.length > max ||
                  value.entries.any((item) => item.key is! String || item.value is! String)) {
                throw SkillExecutionException(error);
              }
              return <String, String>{
                for (final item in value.entries)
                  item.key as String: item.value as String,
              };
            }
            final executor = SkillExecutor(
              runtimeProvider: runtimeProvider,
              runtimeProfiles: profileService,
              ledgerStore: entityStore,
            );
            final result = await executor.execute(
              skill: selected,
              context: workspace,
              compositionPlan: compositionPlan,
              importManifest: importManifest,
              entryPoint: entryPoint,
              runtimeProfileId: runtimeProfileId,
              arguments: readArgumentList(args['arguments']),
              inputs: readObjectMap(args['inputs'], 'invalid_skill_inputs'),
              inputFiles: readStringMap(args['input_files'], 'invalid_skill_input_files'),
              expectedOutputs: readStringMap(args['expected_outputs'], 'invalid_skill_expected_outputs'),
              expectedOutputTypes: readStringMap(args['expected_output_types'], 'invalid_skill_expected_output_types'),
              requestedTimeoutSeconds: args['timeout_seconds'] is int
                  ? args['timeout_seconds'] as int
                  : 900,
              permissionReview: SkillExecutionPermissionPolicy.approveForSingleRun(
                review: permissionReview,
                grantId: executionGrantId,
              ),
              executionGrantId: executionGrantId,
              selectedSourceDigests: selectedSourceDigests,
              sharedRootfsRiskAcknowledged: true,
            );
            if (result['status'] == 'succeeded') {
              await skills.incrementUseCount(skillId);
              final rawOutputs = result['outputs'];
              if (rawOutputs is List && rawOutputs.isNotEmpty) {
                final publicStorage = KelivoPublicStorageService();
                final exported = <Map<String, Object?>>[];
                final exportErrors = <String>[];
                for (final rawOutput in rawOutputs.take(32)) {
                  if (rawOutput is! Map) continue;
                  final relative = rawOutput['workspaceRelativePath'];
                  final artifactPath = rawOutput['relativePath'];
                  final size = rawOutput['sizeBytes'];
                  if (relative is! String || artifactPath is! String || size is! num) {
                    continue;
                  }
                  final normalized = p.posix.normalize(relative);
                  if (normalized.startsWith('/') || normalized == '..' ||
                      normalized.startsWith('../') || normalized.split('/').contains('..')) {
                    exportErrors.add('unsafe_output_path');
                    continue;
                  }
                  final source = File(p.join(workspace.paths.workspaceHostRoot, normalized));
                  try {
                    if (!await source.exists() || await source.length() != size.toInt()) {
                      exportErrors.add('output_missing_or_size_changed:$artifactPath');
                      continue;
                    }
                    final destination = p.posix.join(
                      'Results',
                      workspace.workspace.id.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_'),
                      result['runId']?.toString().replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_') ?? 'run',
                      artifactPath,
                    );
                    final saved = await publicStorage.exportFile(
                      sourcePath: source.path,
                      relativePath: destination,
                      overwrite: true,
                    );
                    if (saved != null) {
                      exported.add({
                        'artifact': rawOutput['artifact'],
                        'path': saved['relativePath'] ?? destination,
                      });
                    }
                  } catch (error) {
                    exportErrors.add('$artifactPath: ${error.toString()}');
                  }
                }
                result['publicStorageExport'] = <String, Object?>{
                  'attempted': true,
                  'exportedCount': exported.length,
                  'files': exported,
                  if (exportErrors.isNotEmpty) 'warnings': exportErrors.take(8).toList(),
                  if (exported.isEmpty && exportErrors.isEmpty)
                    'note': 'No public KELIVO folder is configured; results remain in the private workspace.',
                };
              }
            }
            return const JsonEncoder.withIndent('  ').convert(result);
          }
          if (name == SkillCompositionToolNames.compose) {
            permission.check();
            final skills = contextProvider.read<SkillsService>();
            final registry = contextProvider.read<ExtensionRegistryRepository>();
            List<String>? conversationOverride;
            if (conversationId != null && conversationId.isNotEmpty) {
              final conversation = permissionChat?.getConversation(conversationId);
              if (conversation != null) {
                conversationOverride = SkillsBinding.fromExtras(
                  conversation.extras,
                ).skillIds;
              }
            }
            await skills.loaded;
            final mode = SkillCompositionMode.parse(args['mode']);
            final candidates = skills.resolveForAssistant(
              assistant,
              conversationOverride: conversationOverride,
            );
            final allEnabledSkills = skills.resolveForAssistant(null);
            final projectDefaults = workspaceContext?.workspace.skillIds ??
                assistant?.skillIds ??
                candidates.map((skill) => skill.record.id).toList();
            final available = switch (mode) {
              SkillCompositionMode.allEnabled => allEnabledSkills,
              SkillCompositionMode.conversationOverride
                  when conversationOverride == null => <Skill>[],
              SkillCompositionMode.projectDefault
                  when workspaceContext == null || workspaceContext.skillsOnly =>
                <Skill>[],
              SkillCompositionMode.projectDefault => [
                for (final skill in allEnabledSkills)
                  if (projectDefaults.contains(skill.record.id)) skill,
              ],
              _ => candidates,
            };
            final requestedIds = args['skill_ids'] is List
                ? (args['skill_ids'] as List).whereType<String>().toList()
                : const <String>[];
            final excludedIds = args['exclude_skill_ids'] is List
                ? (args['exclude_skill_ids'] as List).whereType<String>().toList()
                : const <String>[];
            final rawPins = args['pinned_digests'];
            final pinnedDigests = rawPins is Map
                ? <String, String>{
                    for (final entry in rawPins.entries)
                      if (entry.key is String && entry.value is String)
                        entry.key as String: entry.value as String,
                  }
                : const <String, String>{};
            final service = SkillCompositionService(
              skills: skills,
              registry: registry,
            );
            var taskBrief = (args['task'] ?? '').toString();
            if (taskBrief.trim().isEmpty &&
                conversationId != null && conversationId.isNotEmpty &&
                permissionChat != null) {
              String latestUserText(List<ChatMessage> messages) {
                for (final message in messages.reversed) {
                  if (message.role != 'user') continue;
                  final content = message.parts
                      .whereType<TextPart>()
                      .map((part) => part.text)
                      .join('\n')
                      .trim();
                  if (content.isNotEmpty) return content;
                }
                return '';
              }

              var recent = permissionChat.getRecentMessages(
                conversationId,
                maxMessages: 20,
              );
              taskBrief = latestUserText(recent);
              if (taskBrief.isEmpty) {
                recent = await permissionChat.loadRecentMessages(
                  conversationId,
                  minMessages: 1,
                  maxMessages: 20,
                );
                taskBrief = latestUserText(recent);
              }
            }
            return await service.compose(
              task: SkillCompositionPlanner.compactTaskBrief(taskBrief),
              availableSkills: available,
              mode: mode,
              requestedSkillIds: requestedIds,
              excludedSkillIds: excludedIds,
              assistantDefaultSkillIds: assistant == null
                  ? const <String>[]
                  : assistant.skillIds ??
                      candidates.map((skill) => skill.record.id),
              projectDefaultSkillIds: projectDefaults,
              conversationSkillIds: conversationOverride ?? const <String>[],
              contextBudgetTokens: args['context_budget_tokens'] is int
                  ? args['context_budget_tokens'] as int
                  : SkillCompositionPlanner.defaultContextBudgetTokens,
              allowParallel: args['allow_parallel'] != false,
              pinnedDigests: pinnedDigests,
            );
          }
          if (EnvironmentStatusToolNames.all.contains(name)) {
            permission.check();
            final environment = contextProvider.read<EnvironmentProvider>();
            final runtimeProvider = contextProvider.read<WorkspaceRuntimeProvider>();
            WorkspaceRuntime? runtime;
            String? runtimeInitializationError;
            try {
              runtime = await runtimeProvider.ensureInitialized();
            } catch (error) {
              runtimeInitializationError = error.toString();
            }
            runtimeInitializationError ??= runtimeProvider.initializationError;
            final packageManager = PackageManagerService(
              runtime: runtime,
              environment: environment,
              preferences: contextProvider.read<BusinessPreferences>(),
              skills: contextProvider.read<SkillsService>(),
              runtimeProfiles: RuntimeProfileService(
                store: contextProvider.read<ExtensionEntityStore>(),
                runtimeProvider: runtimeProvider,
              ),
            );
            final service = EnvironmentStatusService(
              runtime: runtime,
              environment: environment,
              packageManager: packageManager,
              runtimeInitializationError: runtimeInitializationError,
              workspaceAvailable:
                  workspaceContext != null && !workspaceContext.skillsOnly,
              conversationScopedWorkspace:
                  workspaceContext?.conversationScoped == true,
            );
            final detail = (args['detail'] ?? 'summary').toString();
            final maxItems = args['max_items'] is int
                ? (args['max_items'] as int).clamp(1, 500).toInt()
                : 100;
            return ClientToolResult(
              await service.inspect(detail: detail, maxItems: maxItems),
            );
          }
          if (PackageManagerToolNames.all.contains(name)) {
            // Capture all providers before permission.authorize introduces an
            // async gap. Package mutations never execute without this approval.
            final environment = contextProvider.read<EnvironmentProvider>();
            final runtimeProvider = contextProvider.read<WorkspaceRuntimeProvider>();
            final runtime = await runtimeProvider.ensureInitialized();
            final preferences = contextProvider.read<BusinessPreferences>();
            final packageSkills = contextProvider.read<SkillsService>();
            final profileService = RuntimeProfileService(
              store: contextProvider.read<ExtensionEntityStore>(),
              runtimeProvider: runtimeProvider,
            );
            final packageService = PackageManagerService(
              runtime: runtime,
              environment: environment,
              preferences: preferences,
              workspace: workspaceContext,
              skills: packageSkills,
              runtimeProfiles: profileService,
            );
            final action = (args['action'] ?? 'plan').toString();
            if (PackageManagerToolNames.requiresManualApprovalActions.contains(action)) {
              await permission.authorize(
                needed: true,
                requireManualApproval: true,
                arguments: args,
              );
            } else {
              permission.check();
            }
            final packageScope = (args['scope'] ?? 'runtime').toString();
            final profileId = (args['profile_id'] ?? '').toString().trim();
            if (packageScope == 'extension' && profileId.isNotEmpty) {
              final extensionId = (args['extension_id'] ?? args['skill_id'] ?? '')
                  .toString()
                  .trim();
              await packageSkills.loaded;
              if (extensionId.isEmpty ||
                  !packageSkills.skills.any((skill) => skill.record.id == extensionId)) {
                throw const RuntimeProfileException('runtime_profile_skill_owner_not_found');
              }
            }
            return await packageService.handle(args);
          }
          if (VideoEngineToolNames.all.contains(name)) {
            final workspace = workspaceContext;
            if (workspace == null || workspace.skillsOnly) {
              throw const VideoEngineServiceException('workspace_required');
            }
            // Capture dependencies before the permission prompt to avoid using
            // BuildContext after its asynchronous approval flow.
            final runtimeProvider = contextProvider.read<WorkspaceRuntimeProvider>();
            final entityStore = contextProvider.read<ExtensionEntityStore>();
            final workspaceProvider = contextProvider.read<WorkspaceProvider>();
            final registry = contextProvider.read<ExtensionRegistryRepository>();
            final profiles = RuntimeProfileService(
              store: entityStore,
              runtimeProvider: runtimeProvider,
            );
            const mutatingActions = {
              'install',
              'preflight',
              'set_default',
              'clear_default',
              'configure',
              'create',
              'render',
              'inspect_project',
              'cancel',
              'remove',
            };
            final action = (args['action'] ?? 'list').toString();
            if (mutatingActions.contains(action)) {
              await permission.authorize(needed: true, arguments: args);
            } else {
              permission.check();
            }
            final engines = VideoEngineService(
              registry: registry,
              runtimeProvider: runtimeProvider,
              runtimeProfiles: profiles,
            );
            try {
              if (action == 'render' && permission.conversationId != null) {
                MobileBackgroundCoordinator.instance.updateForConversation(
                  permission.conversationId!,
                  phase: BackgroundTaskPhase.tool,
                  toolName: 'Video render',
                  progressLabel: 'Preparing render',
                );
              }
              final result = await engines.handle(
                args: args,
                context: workspace,
                workspaces: workspaceProvider,
                onProgress: permission.conversationId == null
                    ? null
                    : (percent) => MobileBackgroundCoordinator.instance
                        .updateForConversation(
                          permission.conversationId!,
                          phase: BackgroundTaskPhase.tool,
                          toolName: 'Video render',
                          progress: percent / 100,
                          progressLabel: 'Rendering',
                        ),
              );
              return ClientToolResult(jsonEncode(result));
            } finally {
              engines.dispose();
            }
          }
          if (VideoProductionToolNames.all.contains(name)) {
            final workspace = workspaceContext;
            if (workspace == null || workspace.skillsOnly) {
              throw const VideoProductionServiceException('workspace_required');
            }
            // Capture dependencies before approval introduces an async gap.
            final runtimeProvider = contextProvider.read<WorkspaceRuntimeProvider>();
            final entityStore = contextProvider.read<ExtensionEntityStore>();
            final registry = contextProvider.read<ExtensionRegistryRepository>();
            const mutatingActions = {'create', 'update', 'render', 'export'};
            final action = (args['action'] ?? 'plan').toString();
            if (mutatingActions.contains(action)) {
              await permission.authorize(needed: true, arguments: args);
            } else {
              permission.check();
            }
            final profiles = RuntimeProfileService(
              store: entityStore,
              runtimeProvider: runtimeProvider,
            );
            final engines = VideoEngineService(
              registry: registry,
              runtimeProvider: runtimeProvider,
              runtimeProfiles: profiles,
            );
            try {
              final production = VideoProductionService(videoEngines: engines);
              if (action == 'render' && permission.conversationId != null) {
                MobileBackgroundCoordinator.instance.updateForConversation(
                  permission.conversationId!,
                  phase: BackgroundTaskPhase.tool,
                  toolName: 'Video production render',
                  progressLabel: 'Preparing render',
                );
              }
              final result = await production.handle(
                args: args,
                context: workspace,
                onProgress: permission.conversationId == null
                    ? null
                    : (percent) => MobileBackgroundCoordinator.instance
                        .updateForConversation(
                          permission.conversationId!,
                          phase: BackgroundTaskPhase.tool,
                          toolName: 'Video production render',
                          progress: percent / 100,
                          progressLabel: 'Rendering',
                        ),
              );
              return ClientToolResult(jsonEncode(result));
            } finally {
              engines.dispose();
            }
          }
          if (VideoProviderToolNames.all.contains(name)) {
            final workspace = workspaceContext;
            if (workspace == null || workspace.skillsOnly) {
              throw const VideoProviderServiceException('workspace_required');
            }
            // Capture dependencies before the approval flow introduces an async gap.
            final entityStore = contextProvider.read<ExtensionEntityStore>();
            final registry = contextProvider.read<ExtensionRegistryRepository>();
            final action = (args['action'] ?? 'list').toString();
            const mutatingActions = {
              'install', 'update', 'remove', 'set_limits', 'submit', 'download',
            };
            if (mutatingActions.contains(action)) {
              await permission.authorize(needed: true, arguments: args);
            } else {
              permission.check();
            }
            final runtimeProvider = contextProvider.read<WorkspaceRuntimeProvider>();
            final profiles = RuntimeProfileService(
              store: entityStore,
              runtimeProvider: runtimeProvider,
            );
            final engines = VideoEngineService(
              registry: registry,
              runtimeProvider: runtimeProvider,
              runtimeProfiles: profiles,
            );
            final production = VideoProductionService(videoEngines: engines);
            final providers = VideoProviderConnectorService(
              registry: registry,
              credentials: SecureVideoProviderCredentialStore(),
              videoProduction: production,
            );
            try {
              if (permission.conversationId != null &&
                  const {'poll', 'download'}.contains(action)) {
                MobileBackgroundCoordinator.instance.updateForConversation(
                  permission.conversationId!,
                  phase: BackgroundTaskPhase.tool,
                  toolName: 'Video provider',
                  progressLabel: action == 'download'
                      ? 'Downloading generated video'
                      : 'Checking generation status',
                );
              }
              final result = await providers.handle(
                args: args,
                context: workspace,
                onProgress: permission.conversationId == null ||
                        !const {'poll', 'download'}.contains(action)
                    ? null
                    : (percent) => MobileBackgroundCoordinator.instance
                        .updateForConversation(
                          permission.conversationId!,
                          phase: BackgroundTaskPhase.tool,
                          toolName: 'Video provider',
                          progress: percent / 100,
                          progressLabel: action == 'download'
                              ? 'Downloading generated video'
                              : 'Provider generation',
                        ),
              );
              return ClientToolResult(jsonEncode(result));
            } finally {
              providers.dispose();
              engines.dispose();
            }
          }
          if (VideoHybridWorkflowToolNames.all.contains(name)) {
            final workspace = workspaceContext;
            if (workspace == null || workspace.skillsOnly) {
              throw const VideoHybridWorkflowServiceException('workspace_required');
            }
            // Capture service dependencies before the approval flow yields.
            final entityStore = contextProvider.read<ExtensionEntityStore>();
            final registry = contextProvider.read<ExtensionRegistryRepository>();
            final runtimeProvider = contextProvider.read<WorkspaceRuntimeProvider>();
            const mutatingActions = {
              'configure', 'run_scene', 'download_scene', 'assemble', 'export',
            };
            final action = (args['action'] ?? 'plan').toString();
            if (mutatingActions.contains(action)) {
              await permission.authorize(needed: true, arguments: args);
            } else {
              permission.check();
            }
            final profiles = RuntimeProfileService(
              store: entityStore,
              runtimeProvider: runtimeProvider,
            );
            final engines = VideoEngineService(
              registry: registry,
              runtimeProvider: runtimeProvider,
              runtimeProfiles: profiles,
            );
            final production = VideoProductionService(videoEngines: engines);
            final providers = VideoProviderConnectorService(
              registry: registry,
              credentials: SecureVideoProviderCredentialStore(),
              videoProduction: production,
            );
            try {
              final hybrid = VideoHybridWorkflowService(
                videoEngines: engines,
                videoProduction: production,
                videoProviders: providers,
              );
              if (conversationId != null &&
                  const {'run_scene', 'poll_scene', 'download_scene', 'assemble'}
                      .contains(action)) {
                final stage = switch (action) {
                  'run_scene' => 'Preparing video scene',
                  'poll_scene' => 'Checking video generation',
                  'download_scene' => 'Downloading generated scene',
                  'assemble' => 'Preparing final video assembly',
                  _ => 'Working on video',
                };
                MobileBackgroundCoordinator.instance.updateForConversation(
                  conversationId,
                  phase: BackgroundTaskPhase.tool,
                  toolName: 'Hybrid video workflow',
                  progressLabel: stage,
                );
              }
              final result = await hybrid.handle(
                args: args,
                context: workspace,
                onProgress: conversationId == null
                    ? null
                    : (percent) => MobileBackgroundCoordinator.instance
                        .updateForConversation(
                          conversationId,
                          phase: BackgroundTaskPhase.tool,
                          toolName: 'Hybrid video workflow',
                          progress: percent / 100,
                          progressLabel: switch (action) {
                            'run_scene' => 'Rendering video scene',
                            'poll_scene' => 'AI provider generation',
                            'download_scene' => 'Downloading generated scene',
                            'assemble' => 'Assembling final video',
                            _ => 'Video workflow',
                          },
                        ),
              );
              return ClientToolResult(jsonEncode(result));
            } finally {
              providers.dispose();
              engines.dispose();
            }
          }
          if (VideoQualityToolNames.all.contains(name)) {
            final workspace = workspaceContext;
            if (workspace == null || workspace.skillsOnly) {
              throw const VideoQualityServiceException('workspace_required');
            }
            final runtimeProvider = contextProvider.read<WorkspaceRuntimeProvider>();
            final entityStore = contextProvider.read<ExtensionEntityStore>();
            final profiles = RuntimeProfileService(
              store: entityStore,
              runtimeProvider: runtimeProvider,
            );
            final registry = contextProvider.read<ExtensionRegistryRepository>();
            final engines = VideoEngineService(
              registry: registry,
              runtimeProvider: runtimeProvider,
              runtimeProfiles: profiles,
            );
            final production = VideoProductionService(videoEngines: engines);
            final providers = VideoProviderConnectorService(
              registry: registry,
              credentials: SecureVideoProviderCredentialStore(),
              videoProduction: production,
            );
            final hybrid = VideoHybridWorkflowService(
              videoEngines: engines,
              videoProduction: production,
              videoProviders: providers,
            );
            final action = (args['action'] ?? 'inspect').toString();
            const approvalActions = {'inspect', 'deep_scan', 'samples', 'compare', 'diagnose', 'retry_scene'};
            if (approvalActions.contains(action)) {
              await permission.authorize(needed: true, arguments: args);
            } else {
              permission.check();
            }
            try {
              final quality = VideoQualityService(
                runtimeProvider: runtimeProvider,
                runtimeProfiles: profiles,
                hybridWorkflow: hybrid,
              );
              final result = await quality.handle(args: args, context: workspace);
              return ClientToolResult(jsonEncode(result));
            } finally {
              providers.dispose();
              engines.dispose();
            }
          }
          if (RuntimeProfileToolNames.all.contains(name)) {
            final workspace = workspaceContext;
            if (workspace == null || workspace.skillsOnly) {
              throw const RuntimeProfileException('workspace_required');
            }
            // Capture dependencies before requesting approval; the BuildContext
            // must not be used after the permission flow's async gap.
            final runtimeProvider = contextProvider.read<WorkspaceRuntimeProvider>();
            final entityStore = contextProvider.read<ExtensionEntityStore>();
            final workspaceProvider = contextProvider.read<WorkspaceProvider>();
            final profiles = RuntimeProfileService(
              store: entityStore,
              runtimeProvider: runtimeProvider,
            );
            final installedSkills = contextProvider.read<SkillsService>();
            Future<void> validateProfileOwner(RuntimeProfile profile) async {
              if (profile.scope == RuntimeProfileScope.project) {
                if (profile.ownerId != workspace.workspace.id) {
                  throw const RuntimeProfileException('runtime_profile_workspace_mismatch');
                }
                return;
              }
              if (profile.scope == RuntimeProfileScope.extension) {
                await installedSkills.loaded;
                if (!installedSkills.skills.any((skill) => skill.record.id == profile.ownerId)) {
                  throw const RuntimeProfileException('runtime_profile_skill_owner_not_found');
                }
                return;
              }
              throw const RuntimeProfileException('task_runtime_profiles_not_exposed_to_chat');
            }
            const mutating = {
              'create', 'set_default', 'clear_default', 'remove', 'cancel',
              'snapshot', 'restore_snapshot', 'delete_snapshot',
            };
            final action = (args['action'] ?? '').toString();
            if (workspace.conversationScoped &&
                (action == 'set_default' || action == 'clear_default')) {
              throw const RuntimeProfileException(
                'conversation_workspace_has_no_project_runtime_default',
              );
            }
            if (mutating.contains(action)) {
              await permission.authorize(needed: true, arguments: args);
            } else {
              permission.check();
            }
            await profiles.load();
            switch (action) {
              case 'create':
                final rawScope = (args['scope'] ?? 'project').toString();
                final scope = RuntimeProfileScope.values
                    .where((item) => item.name == rawScope)
                    .firstOrNull;
                if (scope == null) throw const RuntimeProfileException('invalid_profile_scope');
                if (workspace.conversationScoped &&
                    scope != RuntimeProfileScope.extension) {
                  throw const RuntimeProfileException(
                    'conversation_workspace_requires_skill_owned_profile',
                  );
                }
                final rawEcosystems = args['ecosystems'];
                final ecosystems = <RuntimeProfileEcosystem>{};
                if (rawEcosystems is List) {
                  for (final raw in rawEcosystems) {
                    final match = RuntimeProfileEcosystem.values
                        .where((item) => item.name == raw)
                        .firstOrNull;
                    if (match != null) ecosystems.add(match);
                  }
                }
                final rawEnvironment = args['environment'];
                final environment = <String, String>{};
                if (rawEnvironment is Map) {
                  for (final entry in rawEnvironment.entries) {
                    if (entry.key is String && entry.value is String) {
                      environment[entry.key as String] = entry.value as String;
                    }
                  }
                }
                final rawLimits = args['limits'];
                final limits = RuntimeResourceLimits.fromJson(
                  rawLimits is Map ? Map<String, dynamic>.from(rawLimits) : null,
                );
                if (scope == RuntimeProfileScope.task) {
                  throw const RuntimeProfileException('task_runtime_profiles_not_exposed_to_chat');
                }
                final ownerId = scope == RuntimeProfileScope.project
                    ? workspace.workspace.id
                    : (args['owner_id'] ?? '').toString().trim();
                if (scope == RuntimeProfileScope.extension) {
                  await installedSkills.loaded;
                  if (!installedSkills.skills.any((skill) => skill.record.id == ownerId)) {
                    throw const RuntimeProfileException('runtime_profile_skill_owner_not_found');
                  }
                }
                final profile = await profiles.create(
                  name: (args['name'] ?? '').toString(),
                  scope: scope,
                  ownerId: ownerId,
                  ecosystems: ecosystems,
                  context: workspace,
                  environment: environment,
                  limits: limits,
                  shareBaseTools: args['share_base_tools'] != false,
                );
                return ClientToolResult(jsonEncode({
                  'ok': true,
                  'action': action,
                  'profile': profile.toJson(),
                }));
              case 'list':
                final rawScope = args['scope']?.toString();
                final scope = rawScope == null
                    ? null
                    : RuntimeProfileScope.values.where((item) => item.name == rawScope).firstOrNull;
                if (rawScope != null && scope == null) {
                  throw const RuntimeProfileException('invalid_profile_scope');
                }
                if (workspace.conversationScoped &&
                    (scope != RuntimeProfileScope.extension ||
                        (args['owner_id'] ?? '').toString().trim().isEmpty)) {
                  throw const RuntimeProfileException(
                    'conversation_workspace_requires_skill_scope_and_owner',
                  );
                }
                final ownerId = (args['owner_id'] ?? workspace.workspace.id).toString();
                if (scope == RuntimeProfileScope.project || scope == null && ownerId == workspace.workspace.id) {
                  if (ownerId != workspace.workspace.id) {
                    throw const RuntimeProfileException('runtime_profile_workspace_mismatch');
                  }
                } else if (scope == RuntimeProfileScope.extension || scope == null) {
                  await installedSkills.loaded;
                  if (!installedSkills.skills.any((skill) => skill.record.id == ownerId)) {
                    throw const RuntimeProfileException('runtime_profile_skill_owner_not_found');
                  }
                }
                final values = await profiles.list(ownerId: ownerId, scope: scope);
                return ClientToolResult(jsonEncode({
                  'ok': true,
                  'action': action,
                  'profiles': values.map((item) => item.toJson()).toList(),
                }));
              case 'inspect':
                final profile = await profiles.inspectOwned(
                  profileId: (args['profile_id'] ?? '').toString(),
                  context: workspace,
                );
                await validateProfileOwner(profile);
                final history = profiles.processHistory(profileId: profile.id);
                return ClientToolResult(jsonEncode({
                  'ok': true,
                  'action': action,
                  'profile': profile.toJson(),
                  'recent_processes': history.take(20).map((item) => item.toJson()).toList(),
                }));
              case 'set_default':
                await profiles.setDefault(
                  profileId: (args['profile_id'] ?? '').toString(),
                  context: workspace,
                  workspaces: workspaceProvider,
                );
                return ClientToolResult(jsonEncode({
                  'ok': true,
                  'action': action,
                  'default_runtime_profile_id': args['profile_id'],
                }));
              case 'clear_default':
                await profiles.clearDefault(
                  context: workspace,
                  workspaces: workspaceProvider,
                );
                return ClientToolResult(jsonEncode({'ok': true, 'action': action}));
              case 'remove':
                final profileId = (args['profile_id'] ?? '').toString();
                final profile = await profiles.inspectOwned(profileId: profileId, context: workspace);
                await validateProfileOwner(profile);
                if (workspace.workspace.defaultRuntimeProfileId == profileId) {
                  await profiles.clearDefault(context: workspace, workspaces: workspaceProvider);
                }
                await profiles.remove(profileId: profileId, context: workspace);
                return ClientToolResult(jsonEncode({'ok': true, 'action': action, 'profile_id': profileId}));
              case 'snapshot':
                final profileId = (args['profile_id'] ?? '').toString();
                final profile = await profiles.inspectOwned(
                  profileId: profileId,
                  context: workspace,
                );
                await validateProfileOwner(profile);
                final snapshot = await profiles.createSnapshot(
                  profileId: profile.id,
                  context: workspace,
                  label: args['description']?.toString(),
                );
                return ClientToolResult(jsonEncode({
                  'ok': true,
                  'action': action,
                  'snapshot': snapshot.toJson(),
                  'sharedSystemPackagesIncluded': false,
                  'note': 'apt/apk packages are in the shared PRoot RootFS and are not part of this profile snapshot.',
                }));
              case 'snapshots':
                final profileId = (args['profile_id'] ?? '').toString();
                final profile = await profiles.inspectOwned(
                  profileId: profileId,
                  context: workspace,
                );
                await validateProfileOwner(profile);
                return ClientToolResult(jsonEncode({
                  'ok': true,
                  'action': action,
                  'profile_id': profile.id,
                  'snapshots': profiles.snapshots(profileId: profile.id)
                      .map((item) => item.toJson()).toList(),
                  'maxSnapshotsPerProfile': RuntimeProfileService.maxSnapshotsPerProfile,
                }));
              case 'restore_snapshot':
              case 'delete_snapshot':
                final snapshotId = (args['snapshot_id'] ?? '').toString();
                final snapshot = profiles.snapshots().where((item) => item.id == snapshotId).firstOrNull;
                if (snapshot == null) {
                  throw const RuntimeProfileException('runtime_profile_snapshot_not_found');
                }
                final profile = await profiles.inspectOwned(
                  profileId: snapshot.profileId,
                  context: workspace,
                );
                await validateProfileOwner(profile);
                if (action == 'restore_snapshot') {
                  await profiles.restoreSnapshot(
                    snapshotId: snapshot.id,
                    context: workspace,
                  );
                } else {
                  await profiles.deleteSnapshot(
                    snapshotId: snapshot.id,
                    context: workspace,
                  );
                }
                return ClientToolResult(jsonEncode({
                  'ok': true,
                  'action': action,
                  'snapshot_id': snapshot.id,
                  'profile_id': profile.id,
                }));
              case 'processes':
                final profileId = args['profile_id']?.toString();
                if (profileId != null && profileId.isNotEmpty) {
                  final profile = await profiles.inspectOwned(profileId: profileId, context: workspace);
                  await validateProfileOwner(profile);
                }
                final history = profiles.processHistory(
                  profileId: profileId,
                  ownerId: profileId == null ? workspace.workspace.id : null,
                );
                return ClientToolResult(jsonEncode({
                  'ok': true,
                  'action': action,
                  'processes': history.take(50).map((item) => item.toJson()).toList(),
                }));
              case 'cancel':
                final runId = (args['run_id'] ?? '').toString();
                final record = profiles.processes.where((item) => item.runId == runId && item.status == RuntimeProcessStatus.running).firstOrNull;
                if (record == null) throw const RuntimeProfileException('active_process_not_found');
                final profile = await profiles.inspectOwned(profileId: record.profileId, context: workspace);
                await validateProfileOwner(profile);
                await profiles.cancelRun(runId);
                return ClientToolResult(jsonEncode({'ok': true, 'action': action, 'run_id': runId}));
              default:
                throw const RuntimeProfileException('invalid_runtime_profile_action');
            }
          }
          if (ExtensionCommandToolNames.all.contains(name)) {
            // Resolve providers before permission.authorize introduces an async
            // gap; BuildContext must not be accessed after that await.
            ToolRunRegistry? toolRuns;
            try {
              toolRuns = contextProvider.read<ToolRunRegistry>();
            } catch (_) {}
            final extensionService = ConversationalExtensionService(
              skills: contextProvider.read<SkillsService>(),
              registry: contextProvider.read<ExtensionRegistryRepository>(),
              operations: contextProvider.read<ExtensionOperationRepository>(),
              toolRuns: toolRuns,
              conversationId: conversationId,
              runtimeProvider: contextProvider.read<WorkspaceRuntimeProvider>(),
              environment: contextProvider.read<EnvironmentProvider>(),
              onProgress: conversationId == null
                  ? null
                  : (progress) => MobileBackgroundCoordinator.instance
                      .updateForConversation(
                        conversationId,
                        phase: BackgroundTaskPhase.tool,
                        toolName: 'Skill ${progress.phase.name}',
                        progress: progress.fraction,
                        progressLabel: switch (progress.phase) {
                          SkillImportPhase.resolving => 'Resolving source',
                          SkillImportPhase.downloading => 'Downloading Skill',
                          SkillImportPhase.extracting => 'Extracting files',
                          SkillImportPhase.installing => 'Installing Skill',
                        },
                      ),
            );
            if (ExtensionCommandToolNames.requiresManualApproval.contains(name)) {
              await permission.authorize(
                needed: true,
                requireManualApproval: true,
                arguments: args,
              );
            } else {
              permission.check();
            }
            return await extensionService.handle(
              name,
              args,
              workspaceContext: workspaceContext,
              toolCallId: toolCallId,
            );
          }
          if (name == 'read_chat_image') {
            final imageContext = RequestImageContext.current;
            final chat = permissionChat;
            if (imageContext == null ||
                conversationId == null ||
                chat == null) {
              return const ClientToolResult(
                'Image is unavailable in the current conversation context.',
              );
            }
            if (!(await chat.imageContextSettings(
              conversationId,
            )).allowRecall) {
              return const ClientToolResult(
                'Image recall is disabled for this conversation. Ask the user to attach the image again if needed.',
              );
            }
            final allowed = await chat.imageContextHistory(
              conversationId,
              throughMessageId: imageContext.targetMessageId,
            );
            return imageContext.readImage(
              (args['image_id'] ?? '').toString(),
              allowedMessages: allowed.map((m) => m.id).toSet(),
              offset: args['offset'] is int ? args['offset'] as int : 0,
            );
          }
          if (name == BrowserToolsService.toolName) {
            if (conversationId == null ||
                !BrowserService.instance.isSupported ||
                !BrowserService.instance.isInitialized ||
                !BrowserService.instance.settings.agentEnabled) {
              return _toolError(
                error: 'browser_control_disabled',
                message:
                    'The embedded browser is unavailable or disabled in global Browser settings.',
                tool: name,
              );
            }
            return await BrowserToolsService().handle(
              conversationId,
              args,
              capturePreview: settings.showBrowserPageCards,
              temporary: _isTemporaryConversation(conversationId),
            );
          }
          if (workspaceContext != null &&
              workspaceTools != null &&
              WorkspaceToolsService.toolNames.contains(name)) {
            return await workspaceTools.handle(
              workspaceContext,
              name,
              args,
              toolCallId: toolCallId ?? '',
              approvalService: approvalService,
              conversationId: conversationId,
            );
          }

          if (routes.containsExposedName(name)) {
            return await approveAndExecuteMcp(name, args, permission);
          }

          // Search tool
          if (name == SearchToolService.toolName &&
              assistant?.searchEnabled == true) {
            final q = (args['query'] ?? '').toString();
            return await SearchToolService.executeSearch(q, settings);
          }
          if (name == WebFetchToolService.toolName &&
              assistant?.searchEnabled == true) {
            return await WebFetchToolService.executeFetch(args, settings);
          }

          // Memory tools
          final memoryResult = await _handleMemoryToolCall(
            name,
            args,
            assistant,
            conversationId: conversationId,
          );
          if (memoryResult != null) {
            return memoryResult;
          }

          // Full access skips only the ordinary execution prompt.
          if (LocalToolNames.requiresUserApproval.contains(name)) {
            final current = assistant == null
                ? null
                : assistantProvider.getById(assistant.id);
            if (current == null || !current.localToolIds.contains(name)) {
              return _toolError(
                error: 'tool_disabled',
                message: 'This tool is disabled',
                tool: name,
              );
            }
            await permission.authorize(needed: true, arguments: args);
            final latest = assistantProvider.getById(current.id);
            if (latest == null || !latest.localToolIds.contains(name)) {
              return _toolError(
                error: 'tool_disabled',
                message: 'This tool is disabled',
                tool: name,
              );
            }
          }

          // Re-read phone-control permission on every call so disabling it also
          // stops a tool loop that was built with an older assistant snapshot.
          if (name == LocalToolNames.phoneControl) {
            final current = assistant == null
                ? null
                : assistantProvider.getById(assistant.id);
            if (current == null || !current.localToolIds.contains(name)) {
              return _toolError(
                error: 'permission_denied',
                message: 'Phone control is disabled for this assistant.',
                tool: name,
              );
            }
          }

          // Local tools
          final localResult = await LocalToolsService.tryHandleToolCall(
            name,
            args,
            assistant,
            onSpeakText: (text) async {
              final tts = contextProvider.read<TtsProvider>();
              if (!tts.isAvailable) {
                throw StateError('Text-to-speech is unavailable.');
              }
              unawaited(
                tts.speak(text).catchError((Object error, StackTrace stack) {
                  FlutterError.reportError(
                    FlutterErrorDetails(
                      exception: error,
                      stack: stack,
                      library: 'Kelivo local tools',
                      context: ErrorDescription('while playing text-to-speech'),
                    ),
                  );
                }),
              );
            },
          );
          if (localResult != null) {
            return localResult;
          }

          if (name == LocalToolNames.askUser &&
              assistant != null &&
              assistant.localToolIds.contains(LocalToolNames.askUser)) {
            if (askUserService == null) {
              return _toolError(
                error: 'ask_user_unavailable',
                message: 'Ask user interaction service is unavailable.',
                tool: name,
              );
            }
            try {
              final result = await askUserService.requestAnswer(
                toolCallId: (toolCallId?.trim().isNotEmpty == true)
                    ? toolCallId!.trim()
                    : '${name}_${DateTime.now().microsecondsSinceEpoch}',
                arguments: args,
                conversationId: conversationId,
              );
              return result.toJsonString();
            } on AskUserInvalidRequestException catch (e) {
              return _toolError(
                error: 'invalid_ask_user_request',
                message: e.message,
                tool: name,
              );
            }
          }

          return await approveAndExecuteMcp(name, args, permission);
        } on ToolPermissionException catch (e) {
          permission.byFullAccess = false;
          return ClientToolResult(
            _toolError(error: e.code, message: e.message, tool: name),
            metadata: {'toolPermissionError': e.code},
          );
        } catch (e) {
          // Catch unexpected exceptions and return error JSON to LLM
          // This prevents tool failures from terminating the chat flow
          return _toolError(
            error: 'execution_error',
            message: e.toString(),
            tool: name,
            instruction:
                'The tool execution failed unexpectedly. You may try again with different parameters or inform the user about the issue.',
          );
        }
      }

      final result = await execute();
      if (!permission.byFullAccess) return result;
      final client = ClientToolResult.fromHandler(result);
      return ClientToolResult(
        client.content,
        metadata: {...?client.metadata, 'toolPermission': 'fullAccess'},
      );
    };
  }

  /// Handle memory tool calls (§10).
  ///
  /// Returns null if the tool is not a memory tool or the relevant gate is off.
  Future<String?> _handleMemoryToolCall(
    String name,
    Map<String, dynamic> args,
    Assistant? assistant, {
    String? conversationId,
  }) async {
    final settings = contextProvider.read<SettingsProvider>();
    if (settings.legacyMemoryMode) {
      if (MemoryTools.allToolNames.contains(name)) return null;
      return _handleLegacyMemoryToolCall(name, args, assistant);
    }

    if (assistant == null) return null;
    if (!MemoryTools.allToolNames.contains(name)) return null;

    final memoryV2 = contextProvider.read<MemoryProviderV2>();
    ChatService? chatService;
    try {
      chatService = contextProvider.read<ChatService>();
    } catch (_) {
      chatService = null;
    }

    MemoryPipelineService? pipeline;
    try {
      pipeline = contextProvider.read<MemoryPipelineService>();
    } catch (_) {
      pipeline = null;
    }

    Future<String> Function(String prompt)? memoryLlmCall;
    final provKey = settings.memoryModelProvider;
    final mdlId = settings.memoryModelId;
    if (provKey != null && mdlId != null) {
      final cfg = settings.getProviderConfig(provKey);
      final reasoning = settings.memoryModelThinkingEnabled
          ? (assistant.reasoning ?? ReasoningRequest.auto)
          : ReasoningRequest.off;
      memoryLlmCall = (prompt) => ChatApiService.generateText(
        conversationId: conversationId,
        config: cfg,
        modelId: mdlId,
        prompt: prompt,
        reasoning: reasoning,
      );
    }

    final temporary =
        chatService?.isTemporaryConversation(conversationId) ?? false;
    return MemoryTools.handle(
      name: name,
      args: args,
      assistant: assistant,
      repository: memoryV2.repository,
      chatRepository: memoryV2.chatRepository,
      chatService: chatService,
      conversationId: conversationId,
      // Reload without changing which assistants the open memory UI is showing.
      onMutated: memoryV2.reloadCurrentScope,
      smartAdd: pipeline?.smartAdd,
      promptLang: settings.resolvedMemoryPromptLang,
      memoryLlmCall: memoryLlmCall,
      smartAddPromptZh: settings.memorySmartAddPromptZh,
      smartAddPromptEn: settings.memorySmartAddPromptEn,
      // Temporary chats are discarded on exit; their tool traces must not linger.
      traceRecorder: temporary ? null : pipeline?.traceRecorder,
      conversationTitle: conversationId == null
          ? null
          : chatService?.getConversation(conversationId)?.title,
    );
  }

  /// Handle legacy create/edit/delete_memory calls via [MemoryProvider].
  ///
  /// Returns null if memory is disabled or [name] is not a legacy memory tool.
  Future<String?> _handleLegacyMemoryToolCall(
    String name,
    Map<String, dynamic> args,
    Assistant? assistant,
  ) async {
    if (assistant?.enableMemory != true) return null;
    if (name != 'create_memory' &&
        name != 'edit_memory' &&
        name != 'delete_memory') {
      return null;
    }

    try {
      final mp = contextProvider.read<MemoryProvider>();

      if (name == 'create_memory') {
        final content = (args['content'] ?? '').toString();
        if (content.isEmpty) {
          return _toolError(
            error: 'invalid_memory_content',
            message: 'Memory content must not be empty.',
            tool: name,
          );
        }
        final m = await mp.add(assistantId: assistant!.id, content: content);
        return m.content;
      } else if (name == 'edit_memory') {
        final id = (args['id'] as num?)?.toInt() ?? -1;
        final content = (args['content'] ?? '').toString();
        if (id <= 0) {
          return _toolError(
            error: 'invalid_memory_id',
            message: 'Memory id must be a positive integer.',
            tool: name,
          );
        }
        if (content.isEmpty) {
          return _toolError(
            error: 'invalid_memory_content',
            message: 'Memory content must not be empty.',
            tool: name,
          );
        }
        final m = await mp.update(id: id, content: content);
        if (m == null) {
          return _toolError(
            error: 'memory_not_found',
            message: 'No memory record was found for id $id.',
            tool: name,
            instruction:
                'Use the available memory records shown in context, or create a new memory instead of editing a missing one.',
          );
        }
        return m.content;
      } else if (name == 'delete_memory') {
        final id = (args['id'] as num?)?.toInt() ?? -1;
        if (id <= 0) {
          return _toolError(
            error: 'invalid_memory_id',
            message: 'Memory id must be a positive integer.',
            tool: name,
          );
        }
        final ok = await mp.delete(id: id);
        if (!ok) {
          return _toolError(
            error: 'memory_not_found',
            message: 'No memory record was found for id $id.',
            tool: name,
            instruction:
                'Use the available memory records shown in context, or skip deleting a missing memory.',
          );
        }
        return 'deleted';
      }
    } catch (e) {
      return _toolError(
        error: 'memory_execution_error',
        message: e.toString(),
        tool: name,
        instruction:
            'The memory tool failed. Retry only after correcting the parameters, or inform the user about the issue.',
      );
    }

    return null;
  }
}
