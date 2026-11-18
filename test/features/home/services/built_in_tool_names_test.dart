import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/extensions/extension_command_tools.dart';
import 'package:Kelivo/core/services/extensions/skill_composition_tools.dart';
import 'package:Kelivo/core/services/packages/package_manager_tools.dart';
import 'package:Kelivo/core/services/sandbox/environment_status_tool.dart';
import 'package:Kelivo/core/services/runtime_profiles/runtime_profile_tools.dart';
import 'package:Kelivo/core/services/video_engines/video_engine_tools.dart';
import 'package:Kelivo/core/services/video_production/video_production_tools.dart';
import 'package:Kelivo/core/services/video_providers/video_provider_tools.dart';
import 'package:Kelivo/core/services/video_hybrid/video_hybrid_workflow_tools.dart';
import 'package:Kelivo/core/services/video_quality/video_quality_tools.dart';
import 'package:Kelivo/core/services/workspace/workspace_tools_service.dart';
import 'package:Kelivo/core/services/memory/memory_tools.dart';
import 'package:Kelivo/core/services/search/search_tool_service.dart';
import 'package:Kelivo/features/home/services/built_in_tool_names.dart';
import 'package:Kelivo/features/home/services/local_tools_service.dart';

void main() {
  test(
    'BuiltInToolNames.all reserves search, memory, local, and extension names',
    () {
      expect(
        BuiltInToolNames.all,
        containsAll(<String>[
          SearchToolService.toolName,
          'builtin_search',
          ...MemoryTools.allToolNames,
          ...MemoryTools.legacyToolNames,
          ...LocalToolNames.all,
          ...ExtensionCommandToolNames.all,
          SkillCompositionToolNames.compose,
          ...PackageManagerToolNames.all,
          ...EnvironmentStatusToolNames.all,
          ...RuntimeProfileToolNames.all,
          ...VideoEngineToolNames.all,
          ...VideoProductionToolNames.all,
          ...VideoProviderToolNames.all,
          ...VideoHybridWorkflowToolNames.all,
          ...VideoQualityToolNames.all,
        ]),
      );
      expect(SearchToolService.toolName, 'search_web');
      expect(
        BuiltInToolNames.all,
        containsAll(const ['create_memory', 'edit_memory', 'delete_memory']),
      );
      expect(LocalToolNames.all, [
        LocalToolNames.timeInfo,
        LocalToolNames.clipboard,
        LocalToolNames.textToSpeech,
        LocalToolNames.askUser,
        LocalToolNames.calculate,
        LocalToolNames.screenTime,
        LocalToolNames.calendarQuery,
        LocalToolNames.calendarCreate,
        LocalToolNames.currentLocation,
        LocalToolNames.phoneControl,
        LocalToolNames.browser,
        LocalToolNames.weather,
        LocalToolNames.healthSummary,
        LocalToolNames.remindersQuery,
        LocalToolNames.remindersCreate,
        LocalToolNames.remindersComplete,
      ]);
    },
  );

  test(
    'Phase 13E registers environment inventory and read-only Skill update tools',
    () {
      expect(BuiltInToolNames.all, contains(EnvironmentStatusToolNames.inspect));
      expect(BuiltInToolNames.all, contains(ExtensionCommandToolNames.checkUpdates));
      expect(
        ExtensionCommandToolNames.requiresManualApproval,
        unorderedEquals({
          ExtensionCommandToolNames.install,
          ExtensionCommandToolNames.update,
          ExtensionCommandToolNames.enable,
          ExtensionCommandToolNames.disable,
          ExtensionCommandToolNames.remove,
          ExtensionCommandToolNames.rollback,
        }),
      );
      expect(
        ExtensionCommandToolNames.requiresManualApproval,
        isNot(contains(ExtensionCommandToolNames.checkUpdates)),
      );
      expect(
        PackageManagerToolNames.requiresManualApprovalActions,
        unorderedEquals(const {'install', 'upgrade', 'remove', 'pin', 'unpin'}),
      );
      final extensionDefinitions = ExtensionCommandToolCatalog.definitions();
      final extensionNames = [
        for (final definition in extensionDefinitions)
          (definition['function'] as Map)['name'] as String,
      ];
      expect(extensionNames, contains(ExtensionCommandToolNames.checkUpdates));
      final environmentDefinitions = EnvironmentStatusToolCatalog.definitions();
      expect(environmentDefinitions, hasLength(1));
      expect(
        ((environmentDefinitions.single['function'] as Map)['name']),
        EnvironmentStatusToolNames.inspect,
      );
    },
  );

  test('Runtime Profile manager is exposed as a structured workspace tool', () {
    expect(RuntimeProfileToolNames.all, contains('runtime_profile'));
    final definition = WorkspaceToolsService.definitions().singleWhere(
      (item) =>
          ((item['function'] as Map<String, dynamic>)['name']) ==
          RuntimeProfileToolNames.manage,
    );
    final function = definition['function'] as Map<String, dynamic>;
    final parameters = function['parameters'] as Map<String, dynamic>;
    final properties = parameters['properties'] as Map<String, dynamic>;
    expect((properties['action'] as Map)['enum'], contains('create'));
    expect((properties['scope'] as Map)['enum'], contains('extension'));
    expect((properties['ecosystems'] as Map)['minItems'], 1);
    expect(function['description'], contains('not a kernel security boundary'));
  });

  test('package manager is exposed as a structured tool', testPackageManagerToolCatalog);

  test('video engine adapter is exposed as a reserved structured tool', () {
    final definition = VideoEngineToolCatalog.definitions().single;
    final function = definition['function'] as Map<String, dynamic>;
    expect(function['name'], VideoEngineToolNames.manage);
    expect(function['description'], contains('not a kernel security sandbox'));
    final parameters = function['parameters'] as Map<String, dynamic>;
    final properties = parameters['properties'] as Map<String, dynamic>;
    expect((properties['action'] as Map)['enum'], contains('preflight'));
    expect((properties['action'] as Map)['enum'], contains('resource_preflight'));
    expect((properties['action'] as Map)['enum'], contains('render'));
    expect((properties['source'] as Map)['maxLength'], 2048);
  });


  test('video production workflow is exposed as a structured workspace tool', () {
    final definition = VideoProductionToolCatalog.definitions().single;
    final function = definition['function'] as Map<String, dynamic>;
    expect(function['name'], VideoProductionToolNames.manage);
    expect(function['description'], contains('not yet supported'));
    final parameters = function['parameters'] as Map<String, dynamic>;
    final properties = parameters['properties'] as Map<String, dynamic>;
    expect((properties['action'] as Map)['enum'], contains('create'));
    expect((properties['action'] as Map)['enum'], contains('render'));
    expect((properties['action'] as Map)['enum'], contains('export'));
    expect((properties['spec'] as Map)['required'], contains('prompt'));
    expect((properties['files'] as Map)['type'], 'object');
  });

  test('AI video providers are exposed without an API-key tool argument', () {
    final definition = VideoProviderToolCatalog.definitions().single;
    final function = definition['function'] as Map<String, dynamic>;
    expect(function['name'], VideoProviderToolNames.manage);
    expect(function['description'], contains('never request or include API keys'));
    final parameters = function['parameters'] as Map<String, dynamic>;
    final properties = parameters['properties'] as Map<String, dynamic>;
    expect((properties['action'] as Map)['enum'], contains('submit'));
    expect((properties['action'] as Map)['enum'], contains('download'));
    expect(properties.containsKey('api_key'), isFalse);
    expect(properties.containsKey('apiKey'), isFalse);
  });

  test('hybrid workflow composer is exposed as a structured tool', () {
    final definition = VideoHybridWorkflowToolCatalog.definitions().single;
    final function = definition['function'] as Map<String, dynamic>;
    expect(function['name'], VideoHybridWorkflowToolNames.manage);
    expect(function['description'], contains('normalizing dimensions'));
    expect(function['description'], contains('never saved'));
    final parameters = function['parameters'] as Map<String, dynamic>;
    final properties = parameters['properties'] as Map<String, dynamic>;
    expect((properties['action'] as Map)['enum'], contains('run_scene'));
    expect((properties['action'] as Map)['enum'], contains('assemble'));
    expect((properties['routes'] as Map)['maxItems'], 120);
    expect(properties.containsKey('api_key'), isFalse);
  });

  test('video quality assurance is exposed as a structured tool', testVideoQualityToolCatalog);

  test('skill composition is exposed as a reserved read-only planning tool', () {
    final definition = SkillCompositionToolCatalog.definitions().single;
    final function = definition['function'] as Map<String, dynamic>;
    expect(function['name'], SkillCompositionToolNames.compose);
    expect(function['description'], contains('never executes scripts'));
    final parameters = function['parameters'] as Map<String, dynamic>;
    expect(parameters['required'], contains('task'));
    final properties = parameters['properties'] as Map<String, dynamic>;
    expect((properties['mode'] as Map)['enum'], contains('explicit'));
    expect((properties['mode'] as Map)['enum'], contains('project_default'));
    expect((properties['pinned_digests'] as Map)['type'], 'object');
  });
}


void testPackageManagerToolCatalog() {
  final definition = PackageManagerToolCatalog.definitions().single;
  final function = definition['function'] as Map<String, dynamic>;
  expect(function['name'], PackageManagerToolNames.manage);
  final parameters = function['parameters'] as Map<String, dynamic>;
  final properties = parameters['properties'] as Map<String, dynamic>;
  expect((properties['action'] as Map)['enum'], contains('install'));
  expect((properties['manager'] as Map)['enum'], contains('uv'));
  expect((properties['skill_id'] as Map)['type'], 'string');
  expect((properties['allow_install_scripts'] as Map)['default'], false);
}


void testVideoQualityToolCatalog() {
  final definition = VideoQualityToolCatalog.definitions().single;
  final function = definition['function'] as Map<String, dynamic>;
  expect(function['name'], VideoQualityToolNames.manage);
  final parameters = function['parameters'] as Map<String, dynamic>;
  final properties = parameters['properties'] as Map<String, dynamic>;
  expect((properties['action'] as Map)['enum'], containsAll(['inspect', 'deep_scan', 'samples', 'compare', 'diagnose', 'retry_scene']));
  expect(properties.containsKey('api_key'), isFalse);
}
