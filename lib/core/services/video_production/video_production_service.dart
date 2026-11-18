import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../video_engines/video_engine_service.dart';
import '../workspace/workspace_paths.dart';
import '../workspace/workspace_runtime.dart';
import '../workspace/workspace_tool_context.dart';
import 'video_production_spec.dart';

final class VideoProductionServiceException implements Exception {
  const VideoProductionServiceException(this.code);

  final String code;

  @override
  String toString() => code;
}

/// Creates reproducible, engine-neutral video projects in the active Workspace.
/// Rendering is delegated to the optional Phase 7 engine adapter; no renderer,
/// package manager, or user Skill is installed or executed by this service.
final class VideoProductionService {
  VideoProductionService({required this.videoEngines});

  static const String manifestName = 'kelivo.production.json';
  static const String storyboardJsonName = 'storyboard.json';
  static const String storyboardMarkdownName = 'storyboard.md';
  static const int _maxFiles = 120;
  static const int _maxFileBytes = 512 * 1024;
  static const int _maxTotalSourceBytes = 8 * 1024 * 1024;
  static const int _maxExportFiles = 2000;
  static const int _maxExportBytes = 256 * 1024 * 1024;

  final VideoEngineService videoEngines;

  Future<Map<String, Object?>> handle({
    required Map<String, dynamic> args,
    required WorkspaceToolContext context,
    ValueChanged<int>? onProgress,
  }) async {
    _requireWorkspace(context);
    final action = (args['action'] ?? 'plan').toString();
    switch (action) {
      case 'plan':
        return _plan(args);
      case 'create':
        return _create(args, context);
      case 'update':
        return _update(args, context);
      case 'status':
        return _status(args, context);
      case 'render':
        return _render(args, context, onProgress: onProgress);
      case 'export':
        return _export(args, context);
      default:
        throw const VideoProductionServiceException(
          'production_action_unsupported',
        );
    }
  }

  Map<String, Object?> _plan(Map<String, dynamic> args) {
    final spec = VideoProductionSpec.parse(args['spec']);
    final scenes = parseVideoProductionScenes(args['scenes'], spec: spec);
    final sourceFiles = _parseSourceFiles(args['files']);
    final sceneAssetPaths = scenes.expand((scene) => scene.assetPaths).toSet();
    final missingAssets = sceneAssetPaths.difference(sourceFiles.keys.toSet()).toList()..sort();
    final sceneDuration = scenes.fold<double>(
      0,
      (total, scene) => total + scene.durationSeconds,
    );
    return {
      'ok': true,
      'action': 'plan',
      'spec': spec.toJson(),
      'scenes': [for (final scene in scenes) scene.toJson()],
      'sceneCount': scenes.length,
      'estimatedFrames': spec.estimatedFrames,
      'sceneDurationSeconds': sceneDuration,
      'unallocatedDurationSeconds':
          (spec.durationSeconds - sceneDuration).clamp(0.0, spec.durationSeconds),
      'warnings': [
        if (scenes.isEmpty) 'storyboard_not_provided',
        if (scenes.isNotEmpty && sceneDuration < spec.durationSeconds - 0.001)
          'scene_plan_does_not_fill_full_duration',
        if (args['files'] == null) 'source_files_not_provided',
        if (missingAssets.isNotEmpty) 'scene_assets_not_in_source_bundle:${missingAssets.join(',')}',
      ],
      'note': 'This is a validated production brief only; no files were written and no engine was run.',
    };
  }

  Future<Map<String, Object?>> _create(
    Map<String, dynamic> args,
    WorkspaceToolContext context,
  ) async {
    final projectName = _validateProjectName(args['project_name']?.toString() ?? '');
    final spec = VideoProductionSpec.parse(args['spec']);
    final scenes = parseVideoProductionScenes(args['scenes'], spec: spec);
    final sourceFiles = _parseSourceFiles(args['files']);
    final projectModelPath = _requestedProjectPath(
      args['project_dir']?.toString(),
      projectName,
      context,
    );
    final target = context.paths.resolve(projectModelPath, cwd: context.cwd);
    if (target.zone != WorkspaceZone.workspace) {
      throw const VideoProductionServiceException('production_project_outside_workspace');
    }
    await _assertNoSymlinkPath(context, target.hostPath);
    if (await FileSystemEntity.type(target.hostPath, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw const VideoProductionServiceException('production_project_already_exists');
    }

    final parent = Directory(p.dirname(target.hostPath));
    await parent.create(recursive: true);
    await _assertNoSymlinkPath(context, parent.path);
    final stagePath = p.join(
      parent.path,
      '.${p.basename(target.hostPath)}.kelivo-stage-${const Uuid().v4()}',
    );
    final stage = Directory(stagePath);
    await stage.create();
    try {
      for (final entry in sourceFiles.entries) {
        await _writeRelativeFile(
          context: context,
          projectRoot: stage.path,
          relativePath: entry.key,
          content: entry.value,
          allowExisting: false,
        );
      }
      final now = DateTime.now().toUtc().toIso8601String();
      final metadata = <String, Object?>{
        'schemaVersion': 1,
        'projectName': projectName,
        'createdAt': now,
        'updatedAt': now,
        'status': 'source_ready',
        'spec': spec.toJson(),
        'scenes': [for (final scene in scenes) scene.toJson()],
        'sourceFiles': sourceFiles.keys.toList()..sort(),
        'lastRender': null,
        'lastExport': null,
      };
      await _writeInternalJson(context, stage.path, manifestName, metadata);
      await _writeInternalJson(context, stage.path, storyboardJsonName, {
        'schemaVersion': 1,
        'projectName': projectName,
        'scenes': [for (final scene in scenes) scene.toJson()],
      });
      await _writeInternalText(
        context,
        stage.path,
        storyboardMarkdownName,
        _storyboardMarkdown(spec, scenes),
      );
      await _assertNoSymlinkPath(context, target.hostPath);
      await stage.rename(target.hostPath);
    } on Object {
      try {
        if (await stage.exists()) await stage.delete(recursive: true);
      } catch (_) {}
      rethrow;
    }

    return {
      'ok': true,
      'action': 'create',
      'projectName': projectName,
      'projectDirectory': target.modelPath,
      'sourceFiles': sourceFiles.keys.toList()..sort(),
      'sceneCount': scenes.length,
      'estimatedFrames': spec.estimatedFrames,
      'missingAssetFiles': scenes.expand((scene) => scene.assetPaths).toSet().where((path) => !sourceFiles.containsKey(path)).toList()..sort(),
      'note': 'Project brief, storyboard and source files were saved. No engine or dependencies were installed or executed.',
    };
  }

  Future<Map<String, Object?>> _update(
    Map<String, dynamic> args,
    WorkspaceToolContext context,
  ) async {
    final project = await _resolveExistingProject(args, context);
    final metadata = await _readMetadata(context, project.hostPath);
    final spec = args['spec'] == null
        ? VideoProductionSpec.parse(metadata['spec'])
        : VideoProductionSpec.parse(args['spec']);
    final scenes = parseVideoProductionScenes(
      args['scenes'] ?? metadata['scenes'],
      spec: spec,
    );
    final sourceFiles = _parseSourceFiles(args['files']);
    final overwrite = args['overwrite'] == true;
    final backupRoot = p.join(
      project.hostPath,
      '.kelivo',
      'source-backups',
      DateTime.now().toUtc().toIso8601String().replaceAll(':', '-'),
    );
    final updatedFiles = <String>[];
    for (final entry in sourceFiles.entries) {
      final targetPath = _joinRelative(project.hostPath, entry.key);
      await _assertNoSymlinkPath(context, targetPath);
      final targetType = await FileSystemEntity.type(targetPath, followLinks: false);
      if (targetType == FileSystemEntityType.directory ||
          targetType == FileSystemEntityType.link) {
        throw const VideoProductionServiceException('production_source_target_unsafe');
      }
      if (targetType == FileSystemEntityType.file) {
        if (!overwrite) {
          throw const VideoProductionServiceException('production_source_overwrite_requires_confirmation');
        }
        final backupPath = _joinRelative(backupRoot, entry.key);
        await _assertNoSymlinkPath(context, backupPath);
        await Directory(p.dirname(backupPath)).create(recursive: true);
        await _assertNoSymlinkPath(context, backupPath);
        await File(targetPath).copy(backupPath);
      }
      await _writeRelativeFile(
        context: context,
        projectRoot: project.hostPath,
        relativePath: entry.key,
        content: entry.value,
        allowExisting: overwrite,
      );
      updatedFiles.add(entry.key);
    }

    final existingFiles = (metadata['sourceFiles'] as List? ?? const [])
        .whereType<String>()
        .toSet();
    existingFiles.addAll(sourceFiles.keys);
    metadata['spec'] = spec.toJson();
    metadata['scenes'] = [for (final scene in scenes) scene.toJson()];
    metadata['sourceFiles'] = existingFiles.toList()..sort();
    metadata['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    metadata['status'] = 'source_updated';
    metadata['lastRender'] = null;
    metadata['lastExport'] = null;
    await _assertNoSymlinkPath(context, p.join(project.hostPath, storyboardJsonName));
    await _assertNoSymlinkPath(context, p.join(project.hostPath, storyboardMarkdownName));
    await _writeInternalJson(context, project.hostPath, manifestName, metadata);
    await _writeInternalJson(context, project.hostPath, storyboardJsonName, {
      'schemaVersion': 1,
      'projectName': metadata['projectName'],
      'scenes': [for (final scene in scenes) scene.toJson()],
    });
    await _writeInternalText(
      context,
      project.hostPath,
      storyboardMarkdownName,
      _storyboardMarkdown(spec, scenes),
    );
    return {
      'ok': true,
      'action': 'update',
      'projectDirectory': project.modelPath,
      'updatedFiles': updatedFiles,
      'sceneCount': scenes.length,
      'backupsCreated': overwrite && updatedFiles.isNotEmpty,
    };
  }

  Future<Map<String, Object?>> _status(
    Map<String, dynamic> args,
    WorkspaceToolContext context,
  ) async {
    final project = await _resolveExistingProject(args, context);
    final metadata = await _readMetadata(context, project.hostPath);
    final sourceFiles = (metadata['sourceFiles'] as List? ?? const [])
        .whereType<String>()
        .toList(growable: false);
    final referencedAssets = <String>{
      for (final scene in (metadata['scenes'] as List? ?? const []))
        if (scene is Map)
          ...((scene['assetPaths'] as List? ?? const []).whereType<String>()),
    };
    final missingProjectFiles = await _missingProjectFiles(
      context,
      project.hostPath,
      metadata,
    );
    final existingFiles = sourceFiles
        .where((relative) => !missingProjectFiles.contains(relative))
        .toList(growable: false);
    return {
      'ok': true,
      'action': 'status',
      'projectDirectory': project.modelPath,
      'status': metadata['status'],
      'spec': metadata['spec'],
      'sceneCount': (metadata['scenes'] as List? ?? const []).length,
      'sourceFiles': existingFiles,
      'referencedAssets': referencedAssets.toList()..sort(),
      'missingProjectFiles': missingProjectFiles,
      'sourceBundleComplete': missingProjectFiles.isEmpty,
      'lastRender': metadata['lastRender'],
      'lastExport': metadata['lastExport'],
    };
  }

  /// Confirms that a provider job is attached to an existing project scene.
  /// This is read-only and does not expose any project asset contents.
  Future<void> validateProviderTarget({
    required WorkspaceToolContext context,
    required String projectDir,
    required String sceneId,
  }) async {
    _requireWorkspace(context);
    final project = await _resolveExistingPath(projectDir, context);
    final metadata = await _readMetadata(context, project.hostPath);
    final spec = VideoProductionSpec.parse(metadata['spec']);
    final scenes = parseVideoProductionScenes(metadata['scenes'], spec: spec);
    if (!scenes.any((scene) => scene.id == sceneId)) {
      throw const VideoProductionServiceException('production_provider_scene_not_found');
    }
  }

  /// Returns the non-secret project data needed by the hybrid workflow composer.
  Future<Map<String, Object?>> readHybridProject({
    required WorkspaceToolContext context,
    required String projectDir,
  }) async {
    _requireWorkspace(context);
    final project = await _resolveExistingPath(projectDir, context);
    final metadata = await _readMetadata(context, project.hostPath);
    final spec = VideoProductionSpec.parse(metadata['spec']);
    final scenes = parseVideoProductionScenes(metadata['scenes'], spec: spec);
    final sourceFiles = (metadata['sourceFiles'] as List? ?? const [])
        .whereType<String>()
        .toList(growable: false);
    final missing = await _missingProjectFiles(context, project.hostPath, metadata);
    final fingerprintFiles = <Map<String, Object?>>[];
    final referencedUserAssets = <String>{
      for (final scene in scenes)
        ...scene.assetPaths.where((path) => !path.startsWith('assets/generated/')),
    };
    for (final relative in <String>{...sourceFiles, ...referencedUserAssets}) {
      final safe = validateRelativeSourcePath(relative);
      final hostPath = _joinRelative(project.hostPath, safe);
      await _assertNoSymlinkPath(context, hostPath);
      if (await FileSystemEntity.type(hostPath, followLinks: false) !=
          FileSystemEntityType.file) {
        continue;
      }
      final stat = await File(hostPath).stat();
      fingerprintFiles.add({
        'path': safe,
        'bytes': stat.size,
        'modifiedMicros': stat.modified.microsecondsSinceEpoch,
      });
    }
    fingerprintFiles.sort((a, b) => (a['path'] as String).compareTo(b['path'] as String));
    final fingerprintInput = jsonEncode({
      'spec': spec.toJson(),
      'scenes': [
        for (final scene in scenes)
          {
            ...scene.toJson(),
            'assetPaths': scene.assetPaths
                .where((path) => !path.startsWith('assets/generated/'))
                .toList(growable: false),
          },
      ],
      'files': fingerprintFiles,
    });
    return {
      'projectDirectory': project.modelPath,
      'projectName': metadata['projectName'],
      'spec': spec.toJson(),
      'scenes': [for (final scene in scenes) scene.toJson()],
      'sourceFiles': sourceFiles,
      'sourceFingerprint': sha256.convert(utf8.encode(fingerprintInput)).toString(),
      'hybridWorkflow': metadata['hybridWorkflow'],
      'missingProjectFiles': missing,
    };
  }

  /// Saves the hybrid route and task state without accepting executable code
  /// or credentials from the workflow document.
  Future<void> saveHybridWorkflow({
    required WorkspaceToolContext context,
    required String projectDir,
    required Map<String, Object?> workflow,
    bool invalidateRender = false,
  }) async {
    _requireWorkspace(context);
    if (workflow['schemaVersion'] != 1 ||
        workflow['workflowId'] is! String ||
        !RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]{0,127}$')
            .hasMatch(workflow['workflowId'] as String)) {
      throw const VideoProductionServiceException('production_hybrid_workflow_invalid');
    }
    final project = await _resolveExistingPath(projectDir, context);
    final metadata = await _readMetadata(context, project.hostPath);
    metadata['hybridWorkflow'] = workflow;
    metadata['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    if (invalidateRender) {
      metadata['lastRender'] = null;
      metadata['lastExport'] = null;
      metadata['status'] = 'hybrid_workflow_updated';
    }
    await _assertNoSymlinkPath(context, p.join(project.hostPath, manifestName));
    await _writeInternalJson(context, project.hostPath, manifestName, metadata);
  }

  /// Builds a single-scene, reproducible input project for a selected code
  /// engine. Only declared source files and that scene's assets are copied.
  Future<Map<String, Object?>> prepareHybridSceneRenderWorkspace({
    required WorkspaceToolContext context,
    required String projectDir,
    required String workflowId,
    required String sceneId,
  }) async {
    _requireWorkspace(context);
    if (!RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]{0,127}$').hasMatch(workflowId) ||
        !RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(sceneId)) {
      throw const VideoProductionServiceException('production_hybrid_scene_identity_invalid');
    }
    final project = await _resolveExistingPath(projectDir, context);
    final metadata = await _readMetadata(context, project.hostPath);
    final spec = VideoProductionSpec.parse(metadata['spec']);
    final scenes = parseVideoProductionScenes(metadata['scenes'], spec: spec);
    VideoProductionScene? selected;
    for (final scene in scenes) {
      if (scene.id == sceneId) selected = scene;
    }
    final selectedScene = selected;
    if (selectedScene == null) {
      throw const VideoProductionServiceException('production_hybrid_scene_not_found');
    }

    final sourcePaths = <String>{
      ...(metadata['sourceFiles'] as List? ?? const []).whereType<String>(),
      ...selectedScene.assetPaths,
    };
    if (sourcePaths.length > _maxFiles + 64) {
      throw const VideoProductionServiceException('production_hybrid_scene_file_count_exceeded');
    }
    final stagePath = p.join(
      context.paths.workspaceHostRoot,
      '.kelivo',
      'hybrid-staging',
      workflowId,
      '$sceneId-${const Uuid().v4()}',
    );
    await _assertNoSymlinkPath(context, stagePath);
    await Directory(stagePath).create(recursive: true);
    await _assertNoSymlinkPath(context, stagePath);
    var totalBytes = 0;
    try {
      for (final relative in sourcePaths) {
        final safe = validateRelativeSourcePath(relative);
        final source = _joinRelative(project.hostPath, safe);
        await _assertNoSymlinkPath(context, source);
        if (await FileSystemEntity.type(source, followLinks: false) !=
            FileSystemEntityType.file) {
          throw VideoProductionServiceException('production_hybrid_scene_file_missing:$safe');
        }
        final sourceFile = File(source);
        totalBytes += await sourceFile.length();
        if (totalBytes > _maxExportBytes) {
          throw const VideoProductionServiceException('production_hybrid_scene_assets_too_large');
        }
        final destination = _joinRelative(stagePath, safe);
        await _assertNoSymlinkPath(context, destination);
        await Directory(p.dirname(destination)).create(recursive: true);
        await _assertNoSymlinkPath(context, destination);
        await sourceFile.copy(destination);
      }
      final stagedSpec = <String, Object?>{
        ...spec.toJson(),
        'title': selectedScene.title.length <= 120
            ? selectedScene.title
            : selectedScene.title.substring(0, 120),
        'prompt': selectedScene.visualPrompt.trim().isNotEmpty
            ? selectedScene.visualPrompt.trim()
            : selectedScene.description.trim().isNotEmpty
                ? selectedScene.description.trim()
                : spec.prompt,
        'durationSeconds': selectedScene.durationSeconds,
        'estimatedFrames': (selectedScene.durationSeconds * spec.fps).ceil(),
      };
      final stagedScene = selectedScene.toJson();
      final now = DateTime.now().toUtc().toIso8601String();
      await _writeInternalJson(context, stagePath, manifestName, {
        'schemaVersion': 1,
        'projectName': '${metadata['projectName'] ?? p.basename(project.hostPath)}-$sceneId',
        'createdAt': now,
        'updatedAt': now,
        'status': 'hybrid_scene_source_ready',
        'spec': stagedSpec,
        'scenes': [stagedScene],
        'sourceFiles': (metadata['sourceFiles'] as List? ?? const [])
            .whereType<String>()
            .toList(growable: false),
        'hybridScene': {'workflowId': workflowId, 'sceneId': sceneId},
        'lastRender': null,
        'lastExport': null,
      });
      await _writeInternalJson(context, stagePath, storyboardJsonName, {
        'schemaVersion': 1,
        'projectName': '${metadata['projectName'] ?? p.basename(project.hostPath)}-$sceneId',
        'scenes': [stagedScene],
      });
      await _writeInternalText(
        context,
        stagePath,
        storyboardMarkdownName,
        _storyboardMarkdown(
          VideoProductionSpec.parse(stagedSpec),
          [selectedScene],
        ),
      );
      return {
        'projectDirectory': context.paths.toModelPath(stagePath),
        'sceneId': sceneId,
        'copiedFileCount': sourcePaths.length,
        'copiedBytes': totalBytes,
      };
    } on Object {
      try {
        if (await Directory(stagePath).exists()) {
          await Directory(stagePath).delete(recursive: true);
        }
      } catch (_) {}
      rethrow;
    }
  }

  /// Imports the output of a selected code-scene engine into the project.
  /// Output is restricted to that engine's private output directory and must
  /// carry an MP4 file signature before it becomes a scene asset.
  Future<Map<String, Object?>> importEngineClip({
    required WorkspaceToolContext context,
    required String projectDir,
    required String sceneId,
    required String engineId,
    required String outputPath,
    required String runId,
  }) async {
    _requireWorkspace(context);
    if (!RegExp(r'^[a-z0-9][a-z0-9._-]{0,63}$').hasMatch(engineId) ||
        !RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]{0,127}$').hasMatch(runId) ||
        p.extension(outputPath).toLowerCase() != '.mp4') {
      throw const VideoProductionServiceException('production_hybrid_engine_output_invalid');
    }
    final project = await _resolveExistingPath(projectDir, context);
    final metadata = await _readMetadata(context, project.hostPath);
    final spec = VideoProductionSpec.parse(metadata['spec']);
    final scenes = parseVideoProductionScenes(metadata['scenes'], spec: spec).toList();
    final sceneIndex = scenes.indexWhere((scene) => scene.id == sceneId);
    if (sceneIndex < 0) {
      throw const VideoProductionServiceException('production_hybrid_scene_not_found');
    }
    final output = context.paths.resolve(outputPath, cwd: context.cwd);
    final allowedRoot = p.normalize(
      p.join(context.paths.workspaceHostRoot, '.kelivo', 'engine-output', engineId),
    );
    if (output.zone != WorkspaceZone.workspace ||
        !_inside(allowedRoot, p.normalize(output.hostPath)) ||
        output.hostPath == allowedRoot) {
      throw const VideoProductionServiceException('production_hybrid_engine_output_unsafe');
    }
    await _assertNoSymlinkPath(context, output.hostPath);
    if (await FileSystemEntity.type(output.hostPath, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const VideoProductionServiceException('production_hybrid_engine_output_missing');
    }
    final source = File(output.hostPath);
    final length = await source.length();
    if (length < 12 || length > _maxExportBytes) {
      throw const VideoProductionServiceException('production_hybrid_engine_output_size_invalid');
    }
    final header = await source.openRead(0, 12).fold<BytesBuilder>(
      BytesBuilder(copy: false),
      (builder, chunk) => builder..add(chunk),
    );
    final signature = header.takeBytes();
    if (signature.length < 8 ||
        ascii.decode(signature.sublist(4, 8), allowInvalid: true) != 'ftyp') {
      throw const VideoProductionServiceException('production_hybrid_engine_output_not_mp4');
    }

    final relativePath = validateRelativeSourcePath(
      'assets/generated/engine/$engineId/$runId.mp4',
    );
    final targetPath = _joinRelative(project.hostPath, relativePath);
    await _assertNoSymlinkPath(context, targetPath);
    if (await FileSystemEntity.type(targetPath, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw const VideoProductionServiceException('production_hybrid_engine_asset_exists');
    }
    await Directory(p.dirname(targetPath)).create(recursive: true);
    await _assertNoSymlinkPath(context, targetPath);
    final temporary = '$targetPath.${const Uuid().v4()}.part';
    await _assertNoSymlinkPath(context, temporary);
    try {
      await source.copy(temporary);
      await _assertNoSymlinkPath(context, temporary);
      await File(temporary).rename(targetPath);
    } on Object {
      try {
        if (await FileSystemEntity.type(temporary, followLinks: false) ==
            FileSystemEntityType.file) {
          await File(temporary).delete();
        }
      } catch (_) {}
      rethrow;
    }

    final scene = scenes[sceneIndex];
    scenes[sceneIndex] = VideoProductionScene(
      id: scene.id,
      title: scene.title,
      durationSeconds: scene.durationSeconds,
      description: scene.description,
      visualPrompt: scene.visualPrompt,
      narration: scene.narration,
      transition: scene.transition,
      assetPaths: List.unmodifiable([...scene.assetPaths, relativePath]),
    );
    metadata['scenes'] = [for (final item in scenes) item.toJson()];
    final generatedAssets = (metadata['generatedAssets'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .toList();
    generatedAssets.add({
      'source': 'engine',
      'engineId': engineId,
      'runId': runId,
      'sceneId': sceneId,
      'path': relativePath,
      'bytes': length,
      'importedAt': DateTime.now().toUtc().toIso8601String(),
    });
    metadata['generatedAssets'] = generatedAssets;
    metadata['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    metadata['status'] = 'source_updated';
    metadata['lastRender'] = null;
    metadata['lastExport'] = null;
    await _writeInternalJson(context, project.hostPath, manifestName, metadata);
    await _writeInternalJson(context, project.hostPath, storyboardJsonName, {
      'schemaVersion': 1,
      'projectName': metadata['projectName'],
      'scenes': [for (final item in scenes) item.toJson()],
    });
    await _writeInternalText(
      context,
      project.hostPath,
      storyboardMarkdownName,
      _storyboardMarkdown(spec, scenes),
    );
    return {
      'ok': true,
      'sceneId': sceneId,
      'assetPath': p.posix.join(project.modelPath, relativePath),
      'relativeAssetPath': relativePath,
      'bytes': length,
      'runId': runId,
    };
  }

  Future<void> cleanupHybridSceneWorkspace({
    required WorkspaceToolContext context,
    required String projectDirectory,
  }) async {
    _requireWorkspace(context);
    final resolved = context.paths.resolve(projectDirectory, cwd: context.cwd);
    final expectedRoot = p.normalize(
      p.join(context.paths.workspaceHostRoot, '.kelivo', 'hybrid-staging'),
    );
    if (resolved.zone != WorkspaceZone.workspace ||
        !_inside(expectedRoot, p.normalize(resolved.hostPath)) ||
        resolved.hostPath == expectedRoot) {
      throw const VideoProductionServiceException('production_hybrid_staging_path_invalid');
    }
    await _assertNoSymlinkPath(context, resolved.hostPath);
    if (await FileSystemEntity.type(resolved.hostPath, followLinks: false) ==
        FileSystemEntityType.directory) {
      await Directory(resolved.hostPath).delete(recursive: true);
    }
  }

  /// Streams a generated MP4 into a production scene as a first-class asset.
  /// The provider output URL is never persisted; only the local project path
  /// and non-secret provenance are added to the production manifest.
  Future<Map<String, Object?>> importProviderClip({
    required WorkspaceToolContext context,
    required String projectDir,
    required String sceneId,
    required String providerId,
    required String jobId,
    required Stream<List<int>> bytes,
    required int maxBytes,
    String contentType = 'video/mp4',
  }) async {
    _requireWorkspace(context);
    if (!RegExp(r'^[a-z0-9][a-z0-9._-]{0,63}$').hasMatch(providerId) ||
        !RegExp(r'^[a-z0-9][a-z0-9._-]{0,127}$').hasMatch(jobId) ||
        maxBytes < 1024 * 1024 || maxBytes > 256 * 1024 * 1024 ||
        !const {'video/mp4', 'application/octet-stream'}.contains(
          contentType.split(';').first.trim().toLowerCase(),
        )) {
      throw const VideoProductionServiceException('production_provider_asset_metadata_invalid');
    }
    final project = await _resolveExistingPath(projectDir, context);
    final metadata = await _readMetadata(context, project.hostPath);
    final spec = VideoProductionSpec.parse(metadata['spec']);
    final scenes = parseVideoProductionScenes(metadata['scenes'], spec: spec).toList();
    final sceneIndex = scenes.indexWhere((scene) => scene.id == sceneId);
    if (sceneIndex < 0) {
      throw const VideoProductionServiceException('production_provider_scene_not_found');
    }

    final relativePath = validateRelativeSourcePath(
      'assets/generated/$providerId/$jobId.mp4',
    );
    final targetPath = _joinRelative(project.hostPath, relativePath);
    await _assertNoSymlinkPath(context, targetPath);
    if (await FileSystemEntity.type(targetPath, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw const VideoProductionServiceException('production_provider_asset_exists');
    }
    final parent = Directory(p.dirname(targetPath));
    await parent.create(recursive: true);
    await _assertNoSymlinkPath(context, parent.path);
    final stagingPath = p.join(
      parent.path,
      '.${jobId}.download-${const Uuid().v4()}.part',
    );
    await _assertNoSymlinkPath(context, stagingPath);
    final sink = File(stagingPath).openWrite(mode: FileMode.writeOnly);
    final prefix = BytesBuilder(copy: false);
    var totalBytes = 0;
    var sinkClosed = false;
    try {
      await for (final chunk in bytes) {
        totalBytes += chunk.length;
        if (totalBytes > maxBytes) {
          throw const VideoProductionServiceException('production_provider_asset_too_large');
        }
        if (prefix.length < 12) {
          final remaining = 12 - prefix.length;
          prefix.add(chunk.length <= remaining ? chunk : chunk.sublist(0, remaining));
        }
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();
      sinkClosed = true;
      if (totalBytes == 0) {
        throw const VideoProductionServiceException('production_provider_asset_empty');
      }
      final header = prefix.takeBytes();
      if (header.length < 8 || ascii.decode(header.sublist(4, 8), allowInvalid: true) != 'ftyp') {
        throw const VideoProductionServiceException('production_provider_asset_not_mp4');
      }
      await _assertNoSymlinkPath(context, stagingPath);
      await _assertNoSymlinkPath(context, targetPath);
      await File(stagingPath).rename(targetPath);
    } on Object {
      if (!sinkClosed) {
        try {
          await sink.close();
        } catch (_) {}
      }
      try {
        if (await FileSystemEntity.type(stagingPath, followLinks: false) ==
            FileSystemEntityType.file) {
          await File(stagingPath).delete();
        }
      } catch (_) {}
      rethrow;
    }

    final currentScene = scenes[sceneIndex];
    final nextAssets = [...currentScene.assetPaths, relativePath];
    scenes[sceneIndex] = VideoProductionScene(
      id: currentScene.id,
      title: currentScene.title,
      durationSeconds: currentScene.durationSeconds,
      description: currentScene.description,
      visualPrompt: currentScene.visualPrompt,
      narration: currentScene.narration,
      transition: currentScene.transition,
      assetPaths: List.unmodifiable(nextAssets),
    );
    metadata['scenes'] = [for (final scene in scenes) scene.toJson()];
    final generatedAssets = (metadata['generatedAssets'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .toList();
    generatedAssets.add({
      'providerId': providerId,
      'jobId': jobId,
      'sceneId': sceneId,
      'path': relativePath,
      'bytes': totalBytes,
      'importedAt': DateTime.now().toUtc().toIso8601String(),
    });
    metadata['generatedAssets'] = generatedAssets;
    metadata['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    metadata['status'] = 'source_updated';
    metadata['lastRender'] = null;
    metadata['lastExport'] = null;
    await _assertNoSymlinkPath(context, p.join(project.hostPath, manifestName));
    await _writeInternalJson(context, project.hostPath, manifestName, metadata);
    await _writeInternalJson(context, project.hostPath, storyboardJsonName, {
      'schemaVersion': 1,
      'projectName': metadata['projectName'],
      'scenes': [for (final scene in scenes) scene.toJson()],
    });
    await _writeInternalText(
      context,
      project.hostPath,
      storyboardMarkdownName,
      _storyboardMarkdown(spec, scenes),
    );
    return {
      'ok': true,
      'assetPath': p.posix.join(project.modelPath, relativePath),
      'relativeAssetPath': relativePath,
      'sceneId': sceneId,
      'bytes': totalBytes,
      'projectDirectory': project.modelPath,
      'renderInvalidated': true,
    };
  }

  Future<Map<String, Object?>> _render(
    Map<String, dynamic> args,
    WorkspaceToolContext context, {
    ValueChanged<int>? onProgress,
  }) async {
    final project = await _resolveExistingProject(args, context);
    final metadata = await _readMetadata(context, project.hostPath);
    final missingProjectFiles = await _missingProjectFiles(
      context,
      project.hostPath,
      metadata,
    );
    if (missingProjectFiles.isNotEmpty) {
      throw VideoProductionServiceException(
        'production_project_files_missing:${missingProjectFiles.join(',')}',
      );
    }
    final requestedEngine = (args['engine_id'] ?? '').toString().trim();
    final engineId = requestedEngine.isNotEmpty
        ? requestedEngine
        : (context.workspace.defaultVideoEngineId ?? '').trim();
    if (engineId.isEmpty) {
      throw const VideoProductionServiceException('production_video_engine_not_selected');
    }
    final result = await videoEngines.render(
      engineId: engineId,
      context: context,
      projectDir: project.modelPath,
      runtimeProfileId: (args['runtime_profile_id'] ?? '').toString().trim().isEmpty
          ? null
          : args['runtime_profile_id'].toString().trim(),
      onProgress: onProgress,
    );
    if (result['renderVerified'] != true || result['outputPath'] is! String) {
      throw const VideoProductionServiceException(
        'production_engine_render_not_verified',
      );
    }
    final outputPath = context.paths.resolve(
      result['outputPath'] as String,
      cwd: context.cwd,
    );
    final engineOutputRoot = p.normalize(
      p.join(context.paths.workspaceHostRoot, '.kelivo', 'engine-output', engineId),
    );
    if (outputPath.zone != WorkspaceZone.workspace ||
        !_inside(engineOutputRoot, p.normalize(outputPath.hostPath)) ||
        outputPath.hostPath == engineOutputRoot) {
      throw const VideoProductionServiceException(
        'production_engine_render_output_unsafe',
      );
    }
    await _assertNoSymlinkPath(context, outputPath.hostPath);
    if (await FileSystemEntity.type(outputPath.hostPath, followLinks: false) !=
            FileSystemEntityType.file ||
        await File(outputPath.hostPath).length() == 0) {
      throw const VideoProductionServiceException(
        'production_engine_render_output_missing',
      );
    }
    final lastRender = {
      'engineId': engineId,
      'outputPath': outputPath.modelPath,
      'outputBytes': await File(outputPath.hostPath).length(),
      'runId': result['runId'],
      'durationMs': result['durationMs'],
      'renderVerified': true,
      'completedAt': DateTime.now().toUtc().toIso8601String(),
    };
    metadata['lastRender'] = lastRender;
    metadata['lastExport'] = null;
    metadata['status'] = 'rendered';
    metadata['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    await _assertNoSymlinkPath(context, p.join(project.hostPath, manifestName));
    await _writeInternalJson(context, project.hostPath, manifestName, metadata);
    return {
      ...result,
      'action': 'render',
      'projectDirectory': project.modelPath,
      'productionRenderRecorded': true,
    };
  }

  Future<Map<String, Object?>> _export(
    Map<String, dynamic> args,
    WorkspaceToolContext context,
  ) async {
    final project = await _resolveExistingProject(args, context);
    final metadata = await _readMetadata(context, project.hostPath);
    final lastRender = metadata['lastRender'];
    if (lastRender is! Map ||
        lastRender['renderVerified'] != true ||
        lastRender['outputPath'] is! String) {
      throw const VideoProductionServiceException('production_export_requires_verified_render');
    }
    final outputModelPath = lastRender['outputPath'] as String;
    final engineId = (lastRender['engineId'] ?? '').toString().trim();
    if (!RegExp(r'^[a-z0-9][a-z0-9._-]{0,63}$').hasMatch(engineId)) {
      throw const VideoProductionServiceException('production_render_engine_invalid');
    }
    final output = context.paths.resolve(outputModelPath, cwd: context.cwd);
    final engineOutputRoot = p.normalize(
      p.join(context.paths.workspaceHostRoot, '.kelivo', 'engine-output', engineId),
    );
    if (output.zone != WorkspaceZone.workspace ||
        !_inside(engineOutputRoot, p.normalize(output.hostPath)) ||
        output.hostPath == engineOutputRoot) {
      throw const VideoProductionServiceException('production_render_output_unsafe');
    }
    await _assertNoSymlinkPath(context, output.hostPath);
    if (await FileSystemEntity.type(output.hostPath, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const VideoProductionServiceException('production_render_output_missing');
    }
    final outputFile = File(output.hostPath);
    if (await outputFile.length() == 0) {
      throw const VideoProductionServiceException('production_render_output_empty');
    }
    if (p.extension(outputModelPath).toLowerCase() != '.mp4') {
      throw const VideoProductionServiceException('production_export_requires_mp4_output');
    }
    final exportDir = Directory(p.join(project.hostPath, 'exports'));
    await _assertNoSymlinkPath(context, exportDir.path);
    await exportDir.create(recursive: true);
    await _assertNoSymlinkPath(context, exportDir.path);
    final projectName = _validateProjectName(
      (metadata['projectName'] ?? p.basename(project.hostPath)).toString(),
    );
    final videoDestination = p.join(exportDir.path, '$projectName-final.mp4');
    await _assertNoSymlinkPath(context, videoDestination);

    final sourceArchive = Archive();
    final sceneAssets = <String>{
      for (final scene in (metadata['scenes'] as List? ?? const []))
        if (scene is Map)
          ...((scene['assetPaths'] as List? ?? const []).whereType<String>()),
    };
    final sourcePaths = <String>{
      manifestName,
      storyboardJsonName,
      storyboardMarkdownName,
      ...(metadata['sourceFiles'] as List? ?? const []).whereType<String>(),
      ...sceneAssets,
    };
    final missingProjectFiles = await _missingProjectFiles(
      context,
      project.hostPath,
      metadata,
    );
    if (missingProjectFiles.isNotEmpty) {
      throw VideoProductionServiceException(
        'production_project_files_missing:${missingProjectFiles.join(',')}',
      );
    }
    var totalBytes = 0;
    for (final relative in sourcePaths) {
      final safe = relative == manifestName ||
              relative == storyboardJsonName ||
              relative == storyboardMarkdownName
          ? relative
          : validateRelativeSourcePath(relative);
      final hostPath = _joinRelative(project.hostPath, safe);
      await _assertNoSymlinkPath(context, hostPath);
      if (await FileSystemEntity.type(hostPath, followLinks: false) !=
          FileSystemEntityType.file) {
        throw VideoProductionServiceException(
          'production_project_file_missing:$safe',
        );
      }
      final file = File(hostPath);
      final length = await file.length();
      totalBytes += length;
      if (sourceArchive.files.length >= _maxExportFiles ||
          totalBytes > _maxExportBytes) {
        throw const VideoProductionServiceException('production_source_export_limit_exceeded');
      }
      sourceArchive.addFile(ArchiveFile.bytes(safe, await file.readAsBytes()));
    }
    final encoded = ZipEncoder().encodeBytes(sourceArchive);
    final sourceZip = File(p.join(exportDir.path, '$projectName-source.zip'));
    await _assertNoSymlinkPath(context, sourceZip.path);
    await sourceZip.writeAsBytes(encoded, flush: true);
    await _assertNoSymlinkPath(context, videoDestination);
    await outputFile.copy(videoDestination);

    final export = {
      'videoPath': context.paths.toModelPath(videoDestination),
      'videoBytes': await File(videoDestination).length(),
      'sourceArchivePath': context.paths.toModelPath(sourceZip.path),
      'sourceArchiveBytes': await sourceZip.length(),
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
    };
    metadata['lastExport'] = export;
    metadata['status'] = 'exported';
    metadata['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    await _writeInternalJson(context, project.hostPath, manifestName, metadata);
    return {'ok': true, 'action': 'export', ...export};
  }

  Future<ResolvedPath> _resolveExistingProject(
    Map<String, dynamic> args,
    WorkspaceToolContext context,
  ) async {
    final requested = (args['project_dir'] ?? '').toString().trim();
    if (requested.isEmpty) {
      final name = _validateProjectName(args['project_name']?.toString() ?? '');
      return _resolveExistingPath(p.posix.join(context.cwd, name), context);
    }
    return _resolveExistingPath(requested, context);
  }

  Future<ResolvedPath> _resolveExistingPath(
    String requestedPath,
    WorkspaceToolContext context,
  ) async {
    final resolved = context.paths.resolve(requestedPath, cwd: context.cwd);
    if (resolved.zone != WorkspaceZone.workspace) {
      throw const VideoProductionServiceException('production_project_outside_workspace');
    }
    await _assertNoSymlinkPath(context, resolved.hostPath);
    if (await FileSystemEntity.type(resolved.hostPath, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw const VideoProductionServiceException('production_project_not_found');
    }
    return resolved;
  }

  Future<Map<String, dynamic>> _readMetadata(
    WorkspaceToolContext context,
    String projectRoot,
  ) async {
    final path = p.join(projectRoot, manifestName);
    await _assertNoSymlinkPath(context, path);
    if (await FileSystemEntity.type(path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const VideoProductionServiceException('production_manifest_not_found');
    }
    final decoded = jsonDecode(await File(path).readAsString());
    if (decoded is! Map || decoded['schemaVersion'] != 1) {
      throw const VideoProductionServiceException('production_manifest_invalid');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<List<String>> _missingProjectFiles(
    WorkspaceToolContext context,
    String projectRoot,
    Map<String, dynamic> metadata,
  ) async {
    final paths = <String>{
      storyboardJsonName,
      storyboardMarkdownName,
      ...(metadata['sourceFiles'] as List? ?? const []).whereType<String>(),
      for (final scene in (metadata['scenes'] as List? ?? const []))
        if (scene is Map)
          ...((scene['assetPaths'] as List? ?? const []).whereType<String>()),
    };
    final missing = <String>[];
    for (final relative in paths) {
      final safe = relative == storyboardJsonName ||
              relative == storyboardMarkdownName
          ? relative
          : validateRelativeSourcePath(relative);
      final hostPath = _joinRelative(projectRoot, safe);
      await _assertNoSymlinkPath(context, hostPath);
      if (await FileSystemEntity.type(hostPath, followLinks: false) !=
          FileSystemEntityType.file) {
        missing.add(safe);
      }
    }
    missing.sort();
    return missing;
  }

  Map<String, String> _parseSourceFiles(Object? raw) {
    if (raw == null) return const <String, String>{};
    if (raw is! Map || raw.length > _maxFiles ||
        raw.entries.any((entry) => entry.key is! String || entry.value is! String)) {
      throw const VideoProductionServiceException('production_source_files_invalid');
    }
    final result = <String, String>{};
    var totalBytes = 0;
    for (final entry in raw.entries) {
      final path = validateRelativeSourcePath(entry.key as String);
      final content = entry.value as String;
      final bytes = utf8.encode(content);
      if (bytes.length > _maxFileBytes) {
        throw const VideoProductionServiceException('production_source_file_too_large');
      }
      totalBytes += bytes.length;
      if (totalBytes > _maxTotalSourceBytes) {
        throw const VideoProductionServiceException('production_source_bundle_too_large');
      }
      result[path] = content;
    }
    return result;
  }

  Future<void> _writeRelativeFile({
    required WorkspaceToolContext context,
    required String projectRoot,
    required String relativePath,
    required String content,
    required bool allowExisting,
  }) async {
    final safe = validateRelativeSourcePath(relativePath);
    final target = _joinRelative(projectRoot, safe);
    await _assertNoSymlinkPath(context, target);
    final type = await FileSystemEntity.type(target, followLinks: false);
    if (type == FileSystemEntityType.link || type == FileSystemEntityType.directory ||
        (type == FileSystemEntityType.file && !allowExisting)) {
      throw const VideoProductionServiceException('production_source_target_conflict');
    }
    await Directory(p.dirname(target)).create(recursive: true);
    await _assertNoSymlinkPath(context, target);
    await File(target).writeAsString(content, flush: true);
  }

  Future<void> _assertNoSymlinkPath(
    WorkspaceToolContext context,
    String targetPath,
  ) async {
    final root = p.normalize(context.paths.workspaceHostRoot);
    final target = p.normalize(targetPath);
    if (!_inside(root, target)) {
      throw const VideoProductionServiceException('production_path_outside_workspace');
    }
    final relative = p.relative(target, from: root);
    var current = root;
    if (await FileSystemEntity.type(current, followLinks: false) ==
        FileSystemEntityType.link) {
      throw const VideoProductionServiceException('production_workspace_root_is_symlink');
    }
    for (final part in p.split(relative)) {
      if (part == '.' || part.isEmpty) continue;
      current = p.join(current, part);
      if (await FileSystemEntity.type(current, followLinks: false) ==
          FileSystemEntityType.link) {
        throw const VideoProductionServiceException('production_symlink_path_rejected');
      }
    }
  }

  Future<void> _writeInternalJson(
    WorkspaceToolContext context,
    String projectRoot,
    String name,
    Map<String, Object?> value,
  ) async {
    await _writeInternalText(
      context,
      projectRoot,
      name,
      const JsonEncoder.withIndent('  ').convert(value),
    );
  }

  Future<void> _writeInternalText(
    WorkspaceToolContext context,
    String projectRoot,
    String name,
    String contents,
  ) async {
    final path = p.join(projectRoot, name);
    await _assertNoSymlinkPath(context, path);
    await File(path).writeAsString(contents, flush: true);
  }

  String _storyboardMarkdown(
    VideoProductionSpec spec,
    List<VideoProductionScene> scenes,
  ) {
    final buffer = StringBuffer()
      ..writeln('# ${spec.title}')
      ..writeln()
      ..writeln(spec.prompt)
      ..writeln()
      ..writeln('**${spec.width}×${spec.height} · ${spec.fps} FPS · ${spec.durationSeconds}s · ${spec.outputFormat.toUpperCase()}**')
      ..writeln();
    if (spec.visualStyle.isNotEmpty) {
      buffer
        ..writeln('## Visual direction')
        ..writeln(spec.visualStyle)
        ..writeln();
    }
    buffer.writeln('## Storyboard');
    if (scenes.isEmpty) {
      buffer.writeln('_No scenes supplied yet._');
    }
    var start = 0.0;
    for (final scene in scenes) {
      final end = start + scene.durationSeconds;
      buffer
        ..writeln()
        ..writeln('### ${scene.id} — ${scene.title}')
        ..writeln('**${start.toStringAsFixed(2)}s–${end.toStringAsFixed(2)}s · ${scene.durationSeconds}s**')
        ..writeln()
        ..writeln(scene.description);
      if (scene.visualPrompt.isNotEmpty) buffer.writeln('\nVisual: ${scene.visualPrompt}');
      if (scene.narration.isNotEmpty) buffer.writeln('\nNarration: ${scene.narration}');
      if (scene.transition.isNotEmpty) buffer.writeln('\nTransition: ${scene.transition}');
      if (scene.assetPaths.isNotEmpty) buffer.writeln('\nAssets: ${scene.assetPaths.join(', ')}');
      start = end;
    }
    return buffer.toString();
  }

  String _requestedProjectPath(
    String? requested,
    String projectName,
    WorkspaceToolContext context,
  ) {
    final raw = requested?.trim() ?? '';
    final value = raw.isEmpty ? p.posix.join(context.cwd, projectName) : raw;
    if (value.contains('\u0000') || value.contains('\\')) {
      throw const VideoProductionServiceException('production_project_path_invalid');
    }
    return value;
  }

  String _validateProjectName(String value) {
    final name = value.trim();
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$').hasMatch(name) ||
        name == '.' || name == '..') {
      throw const VideoProductionServiceException('production_project_name_invalid');
    }
    return name;
  }

  static String _joinRelative(String root, String relative) =>
      p.joinAll([root, ...relative.split('/')]);

  static bool _inside(String root, String path) =>
      path == root || p.isWithin(root, path);

  static void requireWorkspaceForTesting(WorkspaceToolContext context) =>
      _requireWorkspace(context);

  static void _requireWorkspace(WorkspaceToolContext context) {
    if (context.skillsOnly || context.paths.workspaceHostRoot.isEmpty) {
      throw const VideoProductionServiceException('workspace_required');
    }
  }
}
