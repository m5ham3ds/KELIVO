import '../../../core/services/memory/memory_tools.dart';
import '../../../core/services/search/search_tool_service.dart';
import '../../../core/services/search/web_fetch_tool_service.dart';
import '../../../core/services/workspace/workspace_tools_service.dart';
import '../../../core/services/extensions/extension_command_tools.dart';
import '../../../core/services/extensions/skill_composition_tools.dart';
import '../../../core/services/extensions/skill_execution_tools.dart';
import '../../../core/services/packages/package_manager_tools.dart';
import '../../../core/services/sandbox/environment_status_tool.dart';
import '../../../core/services/runtime_profiles/runtime_profile_tools.dart';
import '../../../core/services/video_engines/video_engine_tools.dart';
import '../../../core/services/video_production/video_production_tools.dart';
import '../../../core/services/video_providers/video_provider_tools.dart';
import '../../../core/services/video_hybrid/video_hybrid_workflow_tools.dart';
import '../../../core/services/video_quality/video_quality_tools.dart';
import 'local_tools_service.dart';

/// Client-side built-in function names that MCP tools must not expose.
///
/// Reservation is static and unconditional: every name here is always
/// reserved, independent of the current assistant's tool switches.
abstract final class BuiltInToolNames {
  static Set<String> get all => {
    SearchToolService.toolName,
    WebFetchToolService.toolName,
    'builtin_search',
    'read_chat_image',
    'kelivo_load_deferred_tool',
    ...MemoryTools.allToolNames,
    ...MemoryTools.legacyToolNames,
    ...LocalToolNames.all,
    ...WorkspaceToolsService.toolNames,
    ...ExtensionCommandToolNames.all,
    SkillCompositionToolNames.compose,
    ...SkillExecutionToolNames.all,
    ...PackageManagerToolNames.all,
    ...EnvironmentStatusToolNames.all,
    ...RuntimeProfileToolNames.all,
    ...VideoEngineToolNames.all,
    ...VideoProductionToolNames.all,
    ...VideoProviderToolNames.all,
    ...VideoHybridWorkflowToolNames.all,
    ...VideoQualityToolNames.all,
  };
}
