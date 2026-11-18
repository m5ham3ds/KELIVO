import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

import '../video_engines/video_engine_service.dart';
import '../video_production/video_production_service.dart';
import '../video_production/video_production_spec.dart';
import '../video_providers/video_provider_connector_service.dart';
import '../workspace/workspace_tool_context.dart';
import 'hybrid_workflow_spec.dart';

final class VideoHybridWorkflowServiceException implements Exception {
  const VideoHybridWorkflowServiceException(this.code);

  final String code;

  @override
  String toString() => code;
}

/// Orchestrates per-scene code engines and AI providers, then delegates final
/// normalization/composition to an explicitly selected hybrid-capable engine.
/// Provider credentials and transient image URLs are never saved here.
final class VideoHybridWorkflowService {
  VideoHybridWorkflowService({
    required this.videoEngines,
    required this.videoProduction,
    required this.videoProviders,
  });

  final VideoEngineService videoEngines;
  final VideoProductionService videoProduction;
  final VideoProviderConnectorService videoProviders;

  Future<Map<String, Object?>> handle({
    required Map<String, dynamic> args,
    required WorkspaceToolContext context,
    ValueChanged<int>? onProgress,
  }) async {
    if (context.skillsOnly || context.paths.workspaceHostRoot.isEmpty) {
      throw const VideoHybridWorkflowServiceException('workspace_required');
    }
    final action = (args['action'] ?? 'plan').toString();
    switch (action) {
      case 'plan':
        return _plan(args, context);
      case 'configure':
        return _configure(args, context);
      case 'status':
        return _status(args, context);
      case 'run_scene':
        return _runScene(args, context, onProgress: onProgress);
      case 'poll_scene':
        return _pollScene(args, context, onProgress: onProgress);
      case 'download_scene':
        return _downloadScene(args, context, onProgress: onProgress);
      case 'assemble':
        return _assemble(args, context, onProgress: onProgress);
      case 'export':
        return _export(args, context);
      default:
        throw const VideoHybridWorkflowServiceException('hybrid_action_unsupported');
    }
  }

  Future<Map<String, Object?>> _plan(
    Map<String, dynamic> args,
    WorkspaceToolContext context,
  ) async {
    final project = await _readProject(args, context);
    final workflow = _parseRequestedWorkflow(args, project);
    final routeSummary = <Map<String, Object?>>[];
    for (final route in workflow.routes) {
      routeSummary.add({
        'sceneId': route.sceneId,
        'mode': route.mode.name,
        if (route.engineId != null) 'engineId': route.engineId,
        if (route.providerId != null) 'providerId': route.providerId,
        if (route.model != null) 'model': route.model,
        'skillIds': route.skillIds,
        'execution': route.skillIds.isEmpty
            ? 'no_skill_selected'
            : 'skill_selection_recorded_execution_pending_phase4',
      });
    }
    return {
      'ok': true,
      'action': 'plan',
      'projectDirectory': project['projectDirectory'],
      'sceneCount': workflow.routes.length,
      'codeSceneCount': workflow.routes
          .where((route) => route.mode == HybridSceneMode.code)
          .length,
      'providerSceneCount': workflow.routes
          .where((route) => route.mode == HybridSceneMode.provider)
          .length,
      'assemblyEngineId': workflow.assemblyEngineId,
      'targetProfile': {
        'width': workflow.width,
        'height': workflow.height,
        'fps': workflow.fps,
        'durationSeconds': workflow.durationSeconds,
        'format': 'mp4',
        'audioPolicy': workflow.audioPolicy,
      },
      'routes': routeSummary,
      'warnings': [
        if ((project['missingProjectFiles'] as List).isNotEmpty)
          'project_has_missing_files',
        if (routeSummary.any((route) => (route['skillIds'] as List).isNotEmpty))
          'skill_execution_is_not_available_until_phase4_executor_is_implemented',
        'scene_and_assembly_engines_must_declare_the_required_phase10_capabilities',
        'assembly_engine_is_responsible_for_media_normalization_and_audio_policy',
      ],
      'note': 'Plan validation only. No provider job was submitted and no engine was executed.',
    };
  }

  Future<Map<String, Object?>> _configure(
    Map<String, dynamic> args,
    WorkspaceToolContext context,
  ) async {
    final project = await _readProject(args, context);
    final workflowSpec = _parseRequestedWorkflow(args, project);
    final missing = project['missingProjectFiles'] as List;
    if (missing.isNotEmpty) {
      throw const VideoHybridWorkflowServiceException('hybrid_project_files_missing');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final workflowId = const Uuid().v4();
    final providerCredentials = <String, bool>{};
    final engineDependencies = <String, Object?>{};
    final providerDependencies = <String, Object?>{};
    final enginePreflightPending = <String>[];
    for (final route in workflowSpec.routes) {
      if (route.mode == HybridSceneMode.code) {
        final installation = await videoEngines.inspect(
          engineId: route.engineId!,
          context: context,
        );
        if (!installation.manifest.supportsSceneRendering ||
            installation.manifest.outputExtension != 'mp4') {
          throw const VideoHybridWorkflowServiceException(
            'hybrid_scene_engine_capability_missing',
          );
        }
        final engineDigest = installation.record.digest;
        if (engineDigest == null ||
            !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(engineDigest)) {
          throw const VideoHybridWorkflowServiceException(
            'hybrid_engine_manifest_digest_missing',
          );
        }
        engineDependencies[route.engineId!] = HybridDependencyPin(
          version: installation.manifest.version,
          digest: engineDigest,
        ).toJson();
        if (installation.record.compatibility['preflightPassed'] != true) {
          enginePreflightPending.add(route.engineId!);
        }
      } else {
        final inspected = await videoProviders.handle(
          args: {'action': 'inspect', 'provider_id': route.providerId},
          context: context,
        );
        final provider = inspected['provider'];
        if (provider is! Map) {
          throw const VideoHybridWorkflowServiceException(
            'hybrid_provider_inspection_invalid',
          );
        }
        final capabilities = provider['capabilities'];
        if (capabilities is! Map ||
            (capabilities['textToVideo'] != true &&
                capabilities['imageToVideo'] != true)) {
          throw const VideoHybridWorkflowServiceException(
            'hybrid_provider_generation_capability_missing',
          );
        }
        final models = provider['models'];
        if (route.model != null && models is List && models.isNotEmpty &&
            !models.contains(route.model)) {
          throw const VideoHybridWorkflowServiceException(
            'hybrid_provider_model_not_supported',
          );
        }
        final providerVersion = provider['version'];
        final providerDigest = inspected['manifestDigest'];
        if (providerVersion is! String || providerVersion.isEmpty ||
            providerDigest is! String ||
            !RegExp(r'^sha256:[0-9a-fA-F]{64}$').hasMatch(providerDigest)) {
          throw const VideoHybridWorkflowServiceException(
            'hybrid_provider_manifest_pin_missing',
          );
        }
        providerDependencies[route.providerId!] = HybridDependencyPin(
          version: providerVersion,
          digest: providerDigest,
        ).toJson();
        providerCredentials[route.providerId!] =
            inspected['credentialConfigured'] == true;
      }
    }
    final assembly = await videoEngines.inspect(
      engineId: workflowSpec.assemblyEngineId,
      context: context,
    );
    if (!assembly.manifest.supportsHybridAssembly ||
        !assembly.manifest.acceptsMp4Assets ||
        assembly.manifest.outputExtension != 'mp4') {
      throw const VideoHybridWorkflowServiceException(
        'hybrid_assembly_engine_capability_missing',
      );
    }
    final assemblyDigest = assembly.record.digest;
    if (assemblyDigest == null ||
        !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(assemblyDigest)) {
      throw const VideoHybridWorkflowServiceException(
        'hybrid_engine_manifest_digest_missing',
      );
    }
    engineDependencies[workflowSpec.assemblyEngineId] = HybridDependencyPin(
      version: assembly.manifest.version,
      digest: assemblyDigest,
    ).toJson();
    if (assembly.record.compatibility['preflightPassed'] != true) {
      enginePreflightPending.add(workflowSpec.assemblyEngineId);
    }

    final workflow = workflowSpec.toJson(workflowId: workflowId, now: now);
    workflow['sourceFingerprint'] = project['sourceFingerprint'];
    workflow['dependencies'] = {
      'engines': engineDependencies,
      'providers': providerDependencies,
    };
    await videoProduction.saveHybridWorkflow(
      context: context,
      projectDir: project['projectDirectory'] as String,
      workflow: workflow,
      invalidateRender: true,
    );
    return {
      'ok': true,
      'action': 'configure',
      'workflowId': workflowId,
      'projectDirectory': project['projectDirectory'],
      'status': 'configured',
      'sceneCount': workflowSpec.routes.length,
      'assemblyEngineId': workflowSpec.assemblyEngineId,
      'providerCredentials': providerCredentials,
      'warnings': [
        if (enginePreflightPending.isNotEmpty)
          'engine_preflight_pending:${enginePreflightPending.toSet().join(',')}',
        if (workflowSpec.routes.any((route) => route.skillIds.isNotEmpty))
          'skill_execution_is_not_available_until_phase4_executor_is_implemented',
      ],
      'nextAction': 'run_scene',
    };
  }

  Future<Map<String, Object?>> _status(
    Map<String, dynamic> args,
    WorkspaceToolContext context,
  ) async {
    final project = await _readProject(args, context);
    final workflow = _requireSavedWorkflow(project['hybridWorkflow']);
    _ensureWorkflowFresh(workflow, project);
    final states = _sceneStates(workflow);
    final routes = workflow['routes'] as List;
    final completed = states.values.where((state) => state['status'] == 'completed').length;
    return {
      'ok': true,
      'action': 'status',
      'projectDirectory': project['projectDirectory'],
      'workflowId': workflow['workflowId'],
      'status': workflow['status'],
      'assemblyEngineId': workflow['assemblyEngineId'],
      'dependencies': workflow['dependencies'],
      'sceneCount': routes.length,
      'completedScenes': completed,
      'pendingScenes': routes.length - completed,
      'sceneStates': states,
      'assembly': workflow['assembly'],
      'export': workflow['export'],
      'missingProjectFiles': project['missingProjectFiles'],
    };
  }

  Future<Map<String, Object?>> _runScene(
    Map<String, dynamic> args,
    WorkspaceToolContext context, {
    ValueChanged<int>? onProgress,
  }) async {
    final project = await _readProject(args, context);
    final workflow = _requireSavedWorkflow(project['hybridWorkflow']);
    _ensureWorkflowFresh(workflow, project);
    final sceneId = _requiredSceneId(args);
    final route = _routeFor(workflow, sceneId);
    final states = _sceneStates(workflow);
    final currentState = states[sceneId] ?? <String, Object?>{'status': 'pending', 'attempt': 0};
    final currentStatus = (currentState['status'] ?? 'pending').toString();
    if (const {'queued', 'running', 'ready_to_download'}.contains(currentStatus)) {
      throw const VideoHybridWorkflowServiceException('hybrid_scene_already_active');
    }
    if (currentStatus == 'completed') {
      throw const VideoHybridWorkflowServiceException('hybrid_scene_already_completed');
    }
    if (currentStatus == 'failed' && args['retry'] != true) {
      throw const VideoHybridWorkflowServiceException('hybrid_scene_retry_requires_confirmation');
    }

    final scenes = parseVideoProductionScenes(
      project['scenes'],
      spec: VideoProductionSpec.parse(project['spec']),
    );
    final scene = scenes.firstWhere((item) => item.id == sceneId);
    final nextAttempt = ((currentState['attempt'] as num?)?.toInt() ?? 0) + 1;

    if (route.mode == HybridSceneMode.provider) {
      final providerInspection = await videoProviders.handle(
        args: {'action': 'inspect', 'provider_id': route.providerId},
        context: context,
      );
      final providerSummary = providerInspection['provider'];
      if (providerSummary is! Map) {
        throw const VideoHybridWorkflowServiceException(
          'hybrid_provider_inspection_invalid',
        );
      }
      final providerPin = _requireDependencyPin(
        workflow,
        kind: 'providers',
        id: route.providerId!,
        version: providerSummary['version'],
        digest: providerInspection['manifestDigest'],
      );
      await _setSceneState(
        context,
        project['projectDirectory'] as String,
        workflow,
        sceneId,
        {'status': 'submitting', 'attempt': nextAttempt},
      );
      try {
        final projectPrompt =
            ((project['spec'] as Map)['prompt'] ?? '').toString().trim();
        final prompt = scene.visualPrompt.trim().isNotEmpty
            ? scene.visualPrompt.trim()
            : scene.description.trim().isNotEmpty
                ? scene.description.trim()
                : projectPrompt;
        final imageUrl = _optionalString(args['image_url']);
        if (prompt.isEmpty && imageUrl == null) {
          throw const VideoHybridWorkflowServiceException(
            'hybrid_provider_scene_prompt_or_image_missing',
          );
        }
        final providerArgs = <String, dynamic>{
          'action': 'submit',
          'provider_id': route.providerId,
          'prompt': prompt,
          'model': route.model,
          'duration_seconds': scene.durationSeconds,
          'aspect_ratio': _aspectRatio(project['spec'] as Map),
          'project_dir': project['projectDirectory'],
          'scene_id': sceneId,
          'expected_provider_version': providerPin.version,
          'expected_provider_digest': providerPin.digest,
          if (imageUrl != null) 'image_url': imageUrl,
        };
        final result = await videoProviders.handle(args: providerArgs, context: context);
        final jobId = result['jobId'];
        if (jobId is! String || jobId.isEmpty) {
          throw const VideoHybridWorkflowServiceException('hybrid_provider_job_id_missing');
        }
        await _setSceneState(
          context,
          project['projectDirectory'] as String,
          workflow,
          sceneId,
          {
            'status': 'queued',
            'attempt': nextAttempt,
            'jobId': jobId,
            'providerId': route.providerId,
            'submittedAt': DateTime.now().toUtc().toIso8601String(),
          },
        );
        return {
          ...result,
          'action': 'run_scene',
          'sceneId': sceneId,
          'route': 'provider',
          'workflowStatus': 'running',
        };
      } on Object {
        await _setSceneState(
          context,
          project['projectDirectory'] as String,
          workflow,
          sceneId,
          {'status': 'failed', 'attempt': nextAttempt, 'errorCode': 'provider_submission_failed'},
        );
        rethrow;
      }
    }

    final engineId = route.engineId!;
    final installation = await videoEngines.inspect(engineId: engineId, context: context);
    if (!installation.manifest.supportsSceneRendering ||
        installation.manifest.outputExtension != 'mp4') {
      throw const VideoHybridWorkflowServiceException('hybrid_scene_engine_capability_missing');
    }
    _requireDependencyPin(
      workflow,
      kind: 'engines',
      id: engineId,
      version: installation.manifest.version,
      digest: installation.record.digest,
    );
    await _setSceneState(
      context,
      project['projectDirectory'] as String,
      workflow,
      sceneId,
      {'status': 'running', 'attempt': nextAttempt, 'engineId': engineId},
    );
    String? stagingDirectory;
    try {
      final staging = await videoProduction.prepareHybridSceneRenderWorkspace(
        context: context,
        projectDir: project['projectDirectory'] as String,
        workflowId: workflow['workflowId'] as String,
        sceneId: sceneId,
      );
      stagingDirectory = staging['projectDirectory'] as String;
      final render = await videoEngines.render(
        engineId: engineId,
        context: context,
        projectDir: stagingDirectory,
        runtimeProfileId: _optionalString(args['runtime_profile_id']),
        onProgress: onProgress,
      );
      if (render['renderVerified'] != true || render['outputPath'] is! String ||
          render['runId'] is! String) {
        throw const VideoHybridWorkflowServiceException('hybrid_scene_engine_render_unverified');
      }
      final imported = await videoProduction.importEngineClip(
        context: context,
        projectDir: project['projectDirectory'] as String,
        sceneId: sceneId,
        engineId: engineId,
        outputPath: render['outputPath'] as String,
        runId: render['runId'] as String,
      );
      await _setSceneState(
        context,
        project['projectDirectory'] as String,
        workflow,
        sceneId,
        {
          'status': 'completed',
          'attempt': nextAttempt,
          'engineId': engineId,
          'runId': render['runId'],
          'assetPath': imported['assetPath'],
          'completedAt': DateTime.now().toUtc().toIso8601String(),
        },
      );
      return {
        'ok': true,
        'action': 'run_scene',
        'sceneId': sceneId,
        'route': 'code',
        'assetPath': imported['assetPath'],
        'bytes': imported['bytes'],
        'runId': render['runId'],
      };
    } on Object {
      await _setSceneState(
        context,
        project['projectDirectory'] as String,
        workflow,
        sceneId,
        {
          'status': 'failed',
          'attempt': nextAttempt,
          'engineId': engineId,
          'errorCode': 'scene_render_failed',
        },
      );
      rethrow;
    } finally {
      if (stagingDirectory != null) {
        try {
          await videoProduction.cleanupHybridSceneWorkspace(
            context: context,
            projectDirectory: stagingDirectory,
          );
        } catch (_) {}
      }
    }
  }

  Future<Map<String, Object?>> _pollScene(
    Map<String, dynamic> args,
    WorkspaceToolContext context, {
    ValueChanged<int>? onProgress,
  }) async {
    final project = await _readProject(args, context);
    final workflow = _requireSavedWorkflow(project['hybridWorkflow']);
    _ensureWorkflowFresh(workflow, project);
    final sceneId = _requiredSceneId(args);
    final route = _routeFor(workflow, sceneId);
    if (route.mode != HybridSceneMode.provider) {
      throw const VideoHybridWorkflowServiceException('hybrid_poll_requires_provider_scene');
    }
    final states = _sceneStates(workflow);
    final state = states[sceneId] ?? const <String, Object?>{};
    final jobId = state['jobId'];
    if (jobId is! String || jobId.isEmpty) {
      throw const VideoHybridWorkflowServiceException('hybrid_provider_job_missing');
    }
    final providerInspection = await videoProviders.handle(
      args: {'action': 'inspect', 'provider_id': route.providerId},
      context: context,
    );
    final providerSummary = providerInspection['provider'];
    if (providerSummary is! Map) {
      throw const VideoHybridWorkflowServiceException(
        'hybrid_provider_inspection_invalid',
      );
    }
    final providerPin = _requireDependencyPin(
      workflow,
      kind: 'providers',
      id: route.providerId!,
      version: providerSummary['version'],
      digest: providerInspection['manifestDigest'],
    );
    final result = await videoProviders.handle(
      args: {
        'action': 'poll',
        'job_id': jobId,
        'expected_provider_version': providerPin.version,
        'expected_provider_digest': providerPin.digest,
      },
      context: context,
      onProgress: onProgress == null ? null : (value) => onProgress(value.round()),
    );
    final providerStatus = (result['status'] ?? 'unknown').toString();
    final nextStatus = providerStatus == 'succeeded' && result['outputAvailable'] == true
        ? 'ready_to_download'
        : providerStatus == 'failed'
            ? 'failed'
            : providerStatus;
    await _setSceneState(
      context,
      project['projectDirectory'] as String,
      workflow,
      sceneId,
      {
        ...state,
        'status': nextStatus,
        if (result['progress'] is num) 'progress': result['progress'],
        'lastPolledAt': DateTime.now().toUtc().toIso8601String(),
      },
    );
    return {
      ...result,
      'action': 'poll_scene',
      'sceneId': sceneId,
      'workflowSceneStatus': nextStatus,
    };
  }

  Future<Map<String, Object?>> _downloadScene(
    Map<String, dynamic> args,
    WorkspaceToolContext context, {
    ValueChanged<int>? onProgress,
  }) async {
    final project = await _readProject(args, context);
    final workflow = _requireSavedWorkflow(project['hybridWorkflow']);
    _ensureWorkflowFresh(workflow, project);
    final sceneId = _requiredSceneId(args);
    final route = _routeFor(workflow, sceneId);
    if (route.mode != HybridSceneMode.provider) {
      throw const VideoHybridWorkflowServiceException('hybrid_download_requires_provider_scene');
    }
    final states = _sceneStates(workflow);
    final state = states[sceneId] ?? const <String, Object?>{};
    if (!const {'ready_to_download', 'succeeded'}.contains(state['status'])) {
      throw const VideoHybridWorkflowServiceException('hybrid_provider_output_not_ready');
    }
    final jobId = state['jobId'];
    if (jobId is! String || jobId.isEmpty) {
      throw const VideoHybridWorkflowServiceException('hybrid_provider_job_missing');
    }
    final providerInspection = await videoProviders.handle(
      args: {'action': 'inspect', 'provider_id': route.providerId},
      context: context,
    );
    final providerSummary = providerInspection['provider'];
    if (providerSummary is! Map) {
      throw const VideoHybridWorkflowServiceException(
        'hybrid_provider_inspection_invalid',
      );
    }
    final providerPin = _requireDependencyPin(
      workflow,
      kind: 'providers',
      id: route.providerId!,
      version: providerSummary['version'],
      digest: providerInspection['manifestDigest'],
    );
    final result = await videoProviders.handle(
      args: {
        'action': 'download',
        'job_id': jobId,
        'expected_provider_version': providerPin.version,
        'expected_provider_digest': providerPin.digest,
      },
      context: context,
      onProgress: onProgress == null ? null : (value) => onProgress(value.round()),
    );
    final downloadedPath = result['downloadedPath'];
    if (downloadedPath is! String || downloadedPath.isEmpty) {
      throw const VideoHybridWorkflowServiceException('hybrid_provider_download_unverified');
    }
    await _setSceneState(
      context,
      project['projectDirectory'] as String,
      workflow,
      sceneId,
      {
        ...state,
        'status': 'completed',
        'assetPath': downloadedPath,
        'completedAt': DateTime.now().toUtc().toIso8601String(),
      },
    );
    return {
      ...result,
      'action': 'download_scene',
      'sceneId': sceneId,
      'workflowSceneStatus': 'completed',
    };
  }

  Future<Map<String, Object?>> _assemble(
    Map<String, dynamic> args,
    WorkspaceToolContext context, {
    ValueChanged<int>? onProgress,
  }) async {
    final project = await _readProject(args, context);
    final workflow = _requireSavedWorkflow(project['hybridWorkflow']);
    _ensureWorkflowFresh(workflow, project);
    final states = _sceneStates(workflow);
    final incomplete = states.entries
        .where((entry) => entry.value['status'] != 'completed')
        .map((entry) => entry.key)
        .toList()
      ..sort();
    if (incomplete.isNotEmpty) {
      throw VideoHybridWorkflowServiceException(
        'hybrid_scenes_incomplete:${incomplete.join(',')}',
      );
    }
    final missing = project['missingProjectFiles'] as List;
    if (missing.isNotEmpty) {
      throw const VideoHybridWorkflowServiceException('hybrid_project_assets_missing');
    }
    final engineId = (workflow['assemblyEngineId'] ?? '').toString();
    final installation = await videoEngines.inspect(engineId: engineId, context: context);
    if (!installation.manifest.supportsHybridAssembly ||
        !installation.manifest.acceptsMp4Assets ||
        installation.manifest.outputExtension != 'mp4') {
      throw const VideoHybridWorkflowServiceException('hybrid_assembly_engine_capability_missing');
    }
    _requireDependencyPin(
      workflow,
      kind: 'engines',
      id: engineId,
      version: installation.manifest.version,
      digest: installation.record.digest,
    );
    final result = await videoProduction.handle(
      args: {
        'action': 'render',
        'project_dir': project['projectDirectory'],
        'engine_id': engineId,
        if (_optionalString(args['runtime_profile_id']) != null)
          'runtime_profile_id': _optionalString(args['runtime_profile_id']),
      },
      context: context,
      onProgress: onProgress,
    );
    workflow['status'] = 'assembled';
    workflow['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    workflow['assembly'] = {
      'engineId': engineId,
      'runId': result['runId'],
      'outputPath': result['outputPath'],
      'outputBytes': result['outputBytes'],
      'completedAt': DateTime.now().toUtc().toIso8601String(),
    };
    workflow['export'] = null;
    await videoProduction.saveHybridWorkflow(
      context: context,
      projectDir: project['projectDirectory'] as String,
      workflow: workflow,
    );
    return {
      ...result,
      'action': 'assemble',
      'workflowId': workflow['workflowId'],
      'normalizationProfile': workflow['normalization'],
      'note':
          'The selected assembly adapter produced the final MP4; detailed codec/timing/audio QA remains a Phase 11 responsibility.',
    };
  }

  Future<Map<String, Object?>> _export(
    Map<String, dynamic> args,
    WorkspaceToolContext context,
  ) async {
    final project = await _readProject(args, context);
    final workflow = _requireSavedWorkflow(project['hybridWorkflow']);
    _ensureWorkflowFresh(workflow, project);
    if (workflow['status'] != 'assembled') {
      throw const VideoHybridWorkflowServiceException('hybrid_export_requires_assembled_workflow');
    }
    final result = await videoProduction.handle(
      args: {'action': 'export', 'project_dir': project['projectDirectory']},
      context: context,
    );
    workflow['status'] = 'completed';
    workflow['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    workflow['export'] = {
      'videoPath': result['videoPath'],
      'sourceArchivePath': result['sourceArchivePath'],
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
    };
    await videoProduction.saveHybridWorkflow(
      context: context,
      projectDir: project['projectDirectory'] as String,
      workflow: workflow,
    );
    return {...result, 'workflowId': workflow['workflowId'], 'workflowStatus': 'completed'};
  }

  Future<Map<String, Object?>> _readProject(
    Map<String, dynamic> args,
    WorkspaceToolContext context,
  ) {
    final path = _optionalString(args['project_dir']);
    if (path == null) {
      throw const VideoHybridWorkflowServiceException('hybrid_project_dir_required');
    }
    return videoProduction.readHybridProject(context: context, projectDir: path);
  }

  HybridWorkflowSpec _parseRequestedWorkflow(
    Map<String, dynamic> args,
    Map<String, Object?> project,
  ) => HybridWorkflowSpec.parse(
    routes: args['routes'],
    productionScenes: project['scenes'],
    productionSpec: project['spec'],
    assemblyEngineId: args['assembly_engine_id'],
    audioPolicy: args['audio_policy'],
  );

  Map<String, Object?> _requireSavedWorkflow(Object? raw) {
    if (raw is! Map || raw['schemaVersion'] != 1 ||
        raw['workflowId'] is! String || raw['routes'] is! List ||
        raw['sceneStates'] is! Map || raw['assemblyEngineId'] is! String) {
      throw const VideoHybridWorkflowServiceException('hybrid_workflow_not_configured');
    }
    return Map<String, Object?>.from(raw);
  }

  HybridDependencyPin _requireDependencyPin(
    Map<String, Object?> workflow, {
    required String kind,
    required String id,
    required Object? version,
    required Object? digest,
  }) {
    final dependencies = workflow['dependencies'];
    final collection = dependencies is Map ? dependencies[kind] : null;
    final pin = collection is Map ? HybridDependencyPin.tryParse(collection[id]) : null;
    if (pin == null || !pin.matches(version, digest)) {
      throw VideoHybridWorkflowServiceException(
        'hybrid_dependency_changed_reconfigure:$kind:$id',
      );
    }
    return pin;
  }

  void _ensureWorkflowFresh(
    Map<String, Object?> workflow,
    Map<String, Object?> project,
  ) {
    if (workflow['sourceFingerprint'] is! String ||
        workflow['sourceFingerprint'] != project['sourceFingerprint']) {
      throw const VideoHybridWorkflowServiceException(
        'hybrid_workflow_source_changed_reconfigure',
      );
    }
    final currentIds = (project['scenes'] as List? ?? const [])
        .whereType<Map>()
        .map((scene) => scene['id'])
        .whereType<String>()
        .toSet();
    final routes = workflow['routes'];
    if (routes is! List) {
      throw const VideoHybridWorkflowServiceException('hybrid_routes_invalid');
    }
    final routeIds = routes
        .whereType<Map>()
        .map((route) => route['sceneId'])
        .whereType<String>()
        .toSet();
    if (routeIds.length != routes.length ||
        routeIds.length != currentIds.length ||
        !routeIds.containsAll(currentIds)) {
      throw const VideoHybridWorkflowServiceException(
        'hybrid_workflow_routes_stale_reconfigure',
      );
    }
  }

  Map<String, Map<String, Object?>> _sceneStates(Map<String, Object?> workflow) {
    final raw = workflow['sceneStates'];
    if (raw is! Map || raw.keys.any((key) => key is! String) ||
        raw.values.any((value) => value is! Map)) {
      throw const VideoHybridWorkflowServiceException('hybrid_scene_states_invalid');
    }
    return {
      for (final entry in raw.entries)
        entry.key as String: Map<String, Object?>.from(entry.value as Map),
    };
  }

  HybridSceneRoute _routeFor(Map<String, Object?> workflow, String sceneId) {
    final routes = workflow['routes'];
    if (routes is! List) {
      throw const VideoHybridWorkflowServiceException('hybrid_routes_invalid');
    }
    for (final item in routes) {
      if (item is Map && (item['sceneId'] ?? item['scene_id']) == sceneId) {
        return HybridSceneRoute.fromSavedJson(item);
      }
    }
    throw const VideoHybridWorkflowServiceException('hybrid_scene_route_not_found');
  }

  Future<void> _setSceneState(
    WorkspaceToolContext context,
    String projectDir,
    Map<String, Object?> workflow,
    String sceneId,
    Map<String, Object?> state,
  ) async {
    final nextWorkflow = Map<String, Object?>.from(workflow);
    final states = _sceneStates(nextWorkflow);
    states[sceneId] = state;
    nextWorkflow['sceneStates'] = states;
    nextWorkflow['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    final routeStates = states.values.map((item) => item['status']).toSet();
    if (routeStates.every((item) => item == 'completed')) {
      nextWorkflow['status'] = 'scenes_ready';
    } else if (routeStates.any((item) => item == 'failed')) {
      nextWorkflow['status'] = 'scene_error';
    } else if (routeStates.any(
      (item) => item == 'queued' || item == 'running' || item == 'submitting',
    )) {
      nextWorkflow['status'] = 'running';
    } else {
      nextWorkflow['status'] = 'configured';
    }
    await videoProduction.saveHybridWorkflow(
      context: context,
      projectDir: projectDir,
      workflow: nextWorkflow,
    );
    workflow
      ..clear()
      ..addAll(nextWorkflow);
  }

  String _requiredSceneId(Map<String, dynamic> args) {
    final value = _optionalString(args['scene_id']);
    if (value == null || !RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(value)) {
      throw const VideoHybridWorkflowServiceException('hybrid_scene_id_required');
    }
    return value;
  }

  String _aspectRatio(Map spec) {
    final width = spec['width'];
    final height = spec['height'];
    if (width is! int || height is! int || width <= 0 || height <= 0) return '16:9';
    var a = width;
    var b = height;
    while (b != 0) {
      final next = a % b;
      a = b;
      b = next;
    }
    final ratioWidth = width ~/ a;
    final ratioHeight = height ~/ a;
    if (ratioWidth <= 100 && ratioHeight <= 100) return '$ratioWidth:$ratioHeight';
    return '16:9';
  }

  String? _optionalString(Object? value) {
    if (value is! String) return null;
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}
