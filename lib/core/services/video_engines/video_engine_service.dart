import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../models/extension_record.dart';
import '../../models/workspace.dart';
import '../../providers/workspace_provider.dart';
import '../api/tool_call_cancellation.dart';
import '../device_resources/device_resource_monitor.dart';
import '../extensions/extension_registry_repository.dart';
import '../extensions/extension_permission_policy.dart';
import '../runtime_profiles/runtime_profile_models.dart';
import '../runtime_profiles/runtime_profile_service.dart';
import '../skills/github_skill_ref.dart';
import '../workspace/workspace_runtime.dart';
import '../workspace/workspace_tool_context.dart';
import 'video_engine_manifest.dart';

const int _maxEngineArchiveBytes = 200 * 1024 * 1024;
const int _maxEngineExtractedBytes = 500 * 1024 * 1024;
const int _maxEngineFiles = 4096;
const int _maxEngineOutputBytes = 1024 * 1024;

class VideoEngineServiceException implements Exception {
  const VideoEngineServiceException(this.code);

  final String code;

  @override
  String toString() => code;
}

class InstalledVideoEngine {
  const InstalledVideoEngine({
    required this.record,
    required this.manifest,
    required this.rootHostPath,
    required this.rootRuntimePath,
  });

  final ExtensionRecord record;
  final VideoEngineManifest manifest;
  final String rootHostPath;
  final String rootRuntimePath;
}

class VideoEngineCommandResult {
  const VideoEngineCommandResult({
    required this.runId,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.duration,
    this.timedOut = false,
    this.cancelled = false,
  });

  final String runId;
  final int exitCode;
  final String stdout;
  final String stderr;
  final Duration duration;
  final bool timedOut;
  final bool cancelled;

  bool get succeeded => exitCode == 0 && !timedOut && !cancelled;
}

/// Installs and runs declarative CLI video-engine adapters inside Android PRoot.
/// Engine package contents are treated as untrusted data until a user-approved
/// engine command is explicitly invoked.
final class VideoEngineService {
  VideoEngineService({
    required this.registry,
    required this.runtimeProvider,
    required this.runtimeProfiles,
    DeviceResourceMonitor? deviceResourceMonitor,
    VideoRenderResourceGuard? resourceGuard,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null,
       _deviceResourceMonitor = deviceResourceMonitor ?? const DeviceResourceMonitor(),
       _resourceGuard = resourceGuard ?? const VideoRenderResourceGuard();

  final ExtensionRegistryRepository registry;
  final WorkspaceRuntimeProvider runtimeProvider;
  final RuntimeProfileService runtimeProfiles;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final DeviceResourceMonitor _deviceResourceMonitor;
  final VideoRenderResourceGuard _resourceGuard;

  Future<List<InstalledVideoEngine>> list(WorkspaceToolContext context) async {
    _requireWorkspace(context);
    final records = await registry.list(kind: 'engine');
    final installed = <InstalledVideoEngine>[];
    for (final record in records) {
      if (record.metadata['workspaceId'] != context.workspace.id) continue;
      try {
        installed.add(await _loadInstalled(context, record));
      } on Object catch (error) {
        debugPrint('Skipping invalid installed engine ${record.id}: $error');
      }
    }
    installed.sort((a, b) => a.manifest.name.toLowerCase().compareTo(b.manifest.name.toLowerCase()));
    return List.unmodifiable(installed);
  }

  Future<InstalledVideoEngine> inspect({
    required String engineId,
    required WorkspaceToolContext context,
  }) async {
    final record = await _record(context, engineId);
    return _loadInstalled(context, record);
  }

  Future<InstalledVideoEngine> install({
    required String source,
    required WorkspaceToolContext context,
  }) async {
    _requireWorkspace(context);
    final trimmedSource = source.trim();
    if (trimmedSource.isEmpty || trimmedSource.length > 2048) {
      throw const VideoEngineServiceException('engine_source_invalid');
    }
    final stagingId = const Uuid().v4();
    final packageBaseHost = p.join(context.paths.workspaceHostRoot, '.kelivo', 'engine-staging');
    await _prepareWorkspaceDirectory(context, packageBaseHost);
    final stagingHost = p.join(packageBaseHost, stagingId);
    await _prepareWorkspaceDirectory(context, stagingHost);
    final root = Directory(stagingHost);

    ExtensionSource sourceRecord;
    try {
      final githubRef = GitHubSkillRef.tryParse(trimmedSource);
      if (githubRef != null) {
        final archiveBytes = await _downloadGitHubArchive(githubRef);
        _extractEngineArchive(
          archiveBytes,
          stagingHost,
          subdir: githubRef.subdir,
        );
        sourceRecord = ExtensionSource(
          type: 'github',
          uri: 'https://github.com/${githubRef.owner}/${githubRef.repo}',
          ref: githubRef.ref,
          subpath: githubRef.subdir,
        );
      } else {
        final sourcePath = await context.paths.resolveReal(
          trimmedSource,
          cwd: context.cwd,
        );
        if (sourcePath.zone != WorkspaceZone.workspace ||
            context.paths.isReadOnlyPath(sourcePath.hostPath)) {
          throw const VideoEngineServiceException('engine_source_must_be_writable_workspace_path');
        }
        final type = await FileSystemEntity.type(sourcePath.hostPath, followLinks: false);
        if (type == FileSystemEntityType.directory) {
          await _copyPackageDirectory(sourcePath.hostPath, stagingHost);
        } else if (type == FileSystemEntityType.file &&
            p.extension(sourcePath.hostPath).toLowerCase() == '.zip') {
          final file = File(sourcePath.hostPath);
          if (await file.length() > _maxEngineArchiveBytes) {
            throw const VideoEngineServiceException('engine_archive_too_large');
          }
          _extractEngineArchive(await file.readAsBytes(), stagingHost);
        } else {
          throw const VideoEngineServiceException('engine_source_must_be_folder_or_zip');
        }
        sourceRecord = ExtensionSource(
          type: 'workspace',
          uri: context.paths.toModelPath(sourcePath.hostPath),
        );
      }

      final manifestFile = File(p.join(stagingHost, kVideoEngineManifestFile));
      if (!await manifestFile.exists()) {
        throw const VideoEngineServiceException('engine_manifest_not_found_at_package_root');
      }
      final manifestText = await manifestFile.readAsString();
      final manifest = VideoEngineManifest.parse(manifestText);
      final recordId = _recordId(context.workspace.id, manifest.id);
      final existing = await registry.get('engine', recordId);
      if (existing != null) {
        throw VideoEngineServiceException('engine_already_installed:${manifest.id}');
      }
      final destinationHost = _engineRootHost(context, manifest.id);
      await _prepareWorkspaceDirectory(context, p.dirname(destinationHost));
      _assertWithinWorkspace(context, destinationHost);
      if (await FileSystemEntity.type(destinationHost, followLinks: false) != FileSystemEntityType.notFound) {
        throw VideoEngineServiceException('engine_install_directory_exists:${manifest.id}');
      }
      await root.rename(destinationHost);

      final manifestDigest = sha256.convert(utf8.encode(manifestText)).toString();
      final record = ExtensionRecord(
        id: recordId,
        kind: 'engine',
        name: manifest.name,
        source: sourceRecord,
        status: ExtensionLifecycleStatus.installed,
        version: manifest.version,
        digest: manifestDigest,
        compatibility: {
          'platforms': manifest.platforms,
          'architectures': manifest.architectures,
          'preflightPassed': false,
          'renderVerified': false,
        },
        permissions: const [
          'workspace.project.read',
          'workspace.project.write',
          'runtime.proot.execute',
        ],
        entryPoint: kVideoEngineManifestFile,
        installedAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
        metadata: {
          'engineId': manifest.id,
          'workspaceId': context.workspace.id,
          'packagePath': '.kelivo/engines/${manifest.id}',
          'manifestSchemaVersion': manifest.schemaVersion,
          'renderVerified': false,
        },
      );
      try {
        await registry.upsert(record);
      } on Object {
        await Directory(destinationHost).delete(recursive: true);
        rethrow;
      }
      return await _loadInstalled(context, record);
    } on Object {
      if (await root.exists()) {
        try {
          await root.delete(recursive: true);
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<void> remove({
    required String engineId,
    required WorkspaceToolContext context,
    required WorkspaceProvider workspaces,
  }) async {
    final record = await _record(context, engineId);
    if (context.workspace.defaultVideoEngineId == engineId) {
      throw const VideoEngineServiceException('clear_project_default_before_engine_removal');
    }
    final installation = await _loadInstalled(context, record);
    await _assertNoSymlinkPath(context, installation.rootHostPath);
    await Directory(installation.rootHostPath).delete(recursive: true);
    await registry.remove('engine', record.id);
    final remainingSettings = <String, Map<String, String>>{
      ...context.workspace.videoEngineSettings,
    }..remove(engineId);
    if (remainingSettings.length != context.workspace.videoEngineSettings.length) {
      await workspaces.update(
        context.workspace.copyWith(videoEngineSettings: remainingSettings),
      );
    }
  }

  Future<Workspace> setDefault({
    required String engineId,
    required WorkspaceToolContext context,
    required WorkspaceProvider workspaces,
  }) async {
    final installation = await inspect(engineId: engineId, context: context);
    if (installation.record.compatibility['preflightPassed'] != true) {
      throw const VideoEngineServiceException('engine_preflight_required_before_selection');
    }
    final updated = context.workspace.copyWith(defaultVideoEngineId: engineId);
    await workspaces.update(updated);
    return updated;
  }

  Future<Workspace> clearDefault({
    required WorkspaceToolContext context,
    required WorkspaceProvider workspaces,
  }) async {
    final updated = context.workspace.copyWith(clearDefaultVideoEngineId: true);
    await workspaces.update(updated);
    return updated;
  }

  Future<Workspace> configure({
    required String engineId,
    required Map<String, String> settings,
    required WorkspaceToolContext context,
    required WorkspaceProvider workspaces,
  }) async {
    await inspect(engineId: engineId, context: context);
    if (settings.length > 64) {
      throw const VideoEngineServiceException('engine_settings_limit_exceeded');
    }
    final normalized = <String, String>{};
    for (final entry in settings.entries) {
      final key = entry.key.trim().toLowerCase();
      final value = entry.value;
      if (!RegExp(r'^[a-z][a-z0-9_.-]{0,63}$').hasMatch(key) ||
          RegExp(r'(?:token|secret|password|credential|authorization|api[_-]?key)').hasMatch(key) ||
          value.length > 4096 || value.contains(RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]'))) {
        throw const VideoEngineServiceException('engine_setting_invalid_or_sensitive');
      }
      if (normalized.containsKey(key)) {
        throw const VideoEngineServiceException('engine_setting_key_duplicate');
      }
      normalized[key] = value;
    }
    final merged = <String, String>{
      ...?context.workspace.videoEngineSettings[engineId],
      ...normalized,
    };
    if (merged.length > 64) {
      throw const VideoEngineServiceException('engine_settings_limit_exceeded');
    }
    final all = <String, Map<String, String>>{
      ...context.workspace.videoEngineSettings,
      engineId: Map.unmodifiable(merged),
    };
    final updated = context.workspace.copyWith(videoEngineSettings: all);
    await workspaces.update(updated);
    return updated;
  }

  Future<Map<String, Object?>> preflight({
    required String engineId,
    required WorkspaceToolContext context,
    String? runtimeProfileId,
  }) async {
    final installation = await inspect(engineId: engineId, context: context);
    final status = await _requireProotRuntime();
    final architecture = await _readArchitecture(context);
    final archCompatible = installation.manifest.architectures.contains('all') ||
        installation.manifest.architectures.any((item) =>
            item == architecture ||
            (item == 'arm64-v8a' && architecture == 'aarch64') ||
            (item == 'aarch64' && architecture == 'arm64-v8a'));
    final platformCompatible = installation.manifest.platforms.contains('all') ||
        installation.manifest.platforms.contains('android');
    if (!archCompatible || !platformCompatible) {
      final updated = installation.record.copyWith(
        status: ExtensionLifecycleStatus.incompatible,
        compatibility: {
          ...installation.record.compatibility,
          'preflightPassed': false,
          'architecture': architecture,
          'preflightError': !archCompatible ? 'architecture_unsupported' : 'platform_unsupported',
        },
      );
      await registry.upsert(updated);
      return {
        'ok': false,
        'engineId': engineId,
        'architecture': architecture,
        'error': !archCompatible ? 'architecture_unsupported' : 'platform_unsupported',
        'message': 'This adapter does not declare compatibility with this Android PRoot architecture.',
      };
    }
    await _validateRequiredEcosystems(
      installation.manifest,
      context,
      runtimeProfileId: runtimeProfileId,
    );

    final missing = await _missingCommands(
      installation.manifest.requiredCommands,
      context,
      runtimeProfileId: runtimeProfileId,
    );
    if (missing.isNotEmpty) {
      final updated = installation.record.copyWith(
        compatibility: {
          ...installation.record.compatibility,
          'preflightPassed': false,
          'architecture': architecture,
          'missingCommands': missing,
          'preflightAt': DateTime.now().toUtc().toIso8601String(),
        },
      );
      await registry.upsert(updated);
      return {
        'ok': false,
        'engineId': engineId,
        'architecture': architecture,
        'missingCommands': missing,
        'error': 'engine_dependencies_missing',
      };
    }

    final baseValues = _placeholderValues(
      installation,
      context,
      projectDir: context.cwd,
      projectName: p.posix.basename(context.cwd),
      outputPath: _defaultOutputPath(
        context, engineId, extension: installation.manifest.outputExtension,
      ),
      runId: 'preflight',
    );
    String? versionOutput;
    final versionCommand = installation.manifest.commands['version'];
    if (versionCommand != null) {
      final versionRunId = 'engine-version-${const Uuid().v4()}';
      final versionResult = await _executeSpec(
        installation: installation,
        spec: versionCommand,
        values: {...baseValues, 'run_id': versionRunId},
        context: context,
        runtimeProfileId: runtimeProfileId,
        timeout: const Duration(seconds: 45),
        runtimeRunId: versionRunId,
      );
      if (!versionResult.succeeded) {
        return _persistPreflightFailure(installation, architecture, 'version_command_failed', versionResult);
      }
      versionOutput = _trimOutput(versionResult.stdout);
    }
    final preflightRunId = 'engine-preflight-${const Uuid().v4()}';
    final result = await _executeSpec(
      installation: installation,
      spec: installation.manifest.command('preflight'),
      values: {...baseValues, 'run_id': preflightRunId},
      context: context,
      runtimeProfileId: runtimeProfileId,
      timeout: const Duration(minutes: 2),
      runtimeRunId: preflightRunId,
    );
    if (!result.succeeded) {
      return _persistPreflightFailure(installation, architecture, 'preflight_command_failed', result,
          versionOutput: versionOutput);
    }
    final updated = installation.record.copyWith(
      status: ExtensionLifecycleStatus.installed,
      compatibility: {
        ...installation.record.compatibility,
        'preflightPassed': true,
        'renderVerified': installation.record.compatibility['renderVerified'] == true,
        'architecture': architecture,
        'missingCommands': const <String>[],
        'preflightAt': DateTime.now().toUtc().toIso8601String(),
      },
      metadata: {
        ...installation.record.metadata,
        if (versionOutput != null) 'detectedVersion': versionOutput,
      },
      clearLastError: true,
    );
    await registry.upsert(updated);
    return {
      'ok': true,
      'engineId': engineId,
      'name': installation.manifest.name,
      'declaredVersion': installation.manifest.version,
      if (versionOutput != null) 'detectedVersion': versionOutput,
      'architecture': architecture,
      'runtime': status.engine,
      'preflightOutput': _trimOutput(result.stdout),
      'renderVerified': updated.compatibility['renderVerified'] == true,
      'supportStatus': updated.compatibility['renderVerified'] == true
          ? 'render_verified'
          : 'preflight_passed_render_not_yet_verified',
    };
  }

  Future<Map<String, Object?>> createProject({
    required String engineId,
    required String projectName,
    required WorkspaceToolContext context,
    String? runtimeProfileId,
  }) async {
    final installation = await _readyForExecution(engineId, context);
    final name = _validateProjectName(projectName);
    final projectDir = p.posix.join(context.cwd, name);
    final resolved = context.paths.resolve(projectDir, cwd: context.cwd);
    if (resolved.zone != WorkspaceZone.workspace) {
      throw const VideoEngineServiceException('engine_project_path_outside_workspace');
    }
    if (await FileSystemEntity.type(resolved.hostPath, followLinks: false) != FileSystemEntityType.notFound) {
      throw const VideoEngineServiceException('engine_project_directory_already_exists');
    }
    await _assertNoSymlinkPath(context, resolved.hostPath);
    final createRunId = 'engine-create-${const Uuid().v4()}';
    final result = await _executeSpec(
      installation: installation,
      spec: installation.manifest.command('create'),
      values: _placeholderValues(
        installation,
        context,
        projectDir: resolved.modelPath,
        projectName: name,
        outputPath: _defaultOutputPath(
          context, engineId, extension: installation.manifest.outputExtension,
        ),
        runId: createRunId,
      ),
      context: context,
      runtimeProfileId: runtimeProfileId,
      cwd: context.cwd,
      timeout: const Duration(minutes: 5),
      runtimeRunId: createRunId,
    );
    if (!result.succeeded) {
      throw VideoEngineServiceException('engine_create_failed:${result.exitCode}:${_trimOutput(result.stderr)}');
    }
    if (await FileSystemEntity.type(resolved.hostPath, followLinks: false) != FileSystemEntityType.directory) {
      throw const VideoEngineServiceException('engine_create_did_not_create_project_directory');
    }
    return {
      'ok': true,
      'engineId': engineId,
      'projectDirectory': resolved.modelPath,
      'runId': result.runId,
      'output': _trimOutput(result.stdout),
    };
  }

  Future<Map<String, Object?>> resourcePreflight() async {
    final snapshot = await _deviceResourceMonitor.sample();
    final assessment = _resourceGuard.evaluate(snapshot);
    return {
      'ok': true,
      'action': 'resource_preflight',
      ...assessment.toJson(),
      'note': assessment.level == VideoRenderResourceLevel.unknown
          ? 'Device telemetry is unavailable; no local-render safety conclusion can be made.'
          : 'This is a best-effort snapshot, not a guarantee that a long render will remain within resource limits.',
    };
  }

  Future<Map<String, Object?>> render({
    required String engineId,
    required WorkspaceToolContext context,
    String? projectDir,
    String? runtimeProfileId,
    ValueChanged<int>? onProgress,
  }) async {
    final installation = await _readyForExecution(engineId, context);
    final resourceSnapshot = await _deviceResourceMonitor.sample();
    final resourceAssessment = _resourceGuard.evaluate(resourceSnapshot);
    if (resourceAssessment.blocksRender) {
      final reasons = resourceAssessment.reasons.join(',');
      throw VideoEngineServiceException(
        'engine_render_blocked_resource_guard:$reasons',
      );
    }
    final requestedProjectDir = projectDir?.trim().isNotEmpty == true
        ? projectDir!.trim()
        : context.cwd;
    final resolvedProject = context.paths.resolve(requestedProjectDir, cwd: context.cwd);
    if (resolvedProject.zone != WorkspaceZone.workspace ||
        await FileSystemEntity.type(resolvedProject.hostPath, followLinks: false) != FileSystemEntityType.directory) {
      throw const VideoEngineServiceException('engine_project_directory_invalid');
    }
    await _assertNoSymlinkPath(context, resolvedProject.hostPath);
    final outputPath = _defaultOutputPath(
      context, engineId, extension: installation.manifest.outputExtension,
    );
    final outputResolved = context.paths.resolve(outputPath, cwd: context.cwd);
    await _prepareWorkspaceDirectory(context, p.dirname(outputResolved.hostPath));
    final renderRunId = 'engine-render-${const Uuid().v4()}';
    final result = await _executeSpec(
      installation: installation,
      spec: installation.manifest.command('render'),
      values: _placeholderValues(
        installation,
        context,
        projectDir: resolvedProject.modelPath,
        projectName: p.posix.basename(resolvedProject.modelPath),
        outputPath: outputResolved.modelPath,
        runId: renderRunId,
      ),
      context: context,
      runtimeProfileId: runtimeProfileId,
      cwd: resolvedProject.modelPath,
      timeout: const Duration(minutes: 30),
      runtimeRunId: renderRunId,
      onProgress: onProgress,
    );
    if (!result.succeeded) {
      throw VideoEngineServiceException('engine_render_failed:${result.exitCode}:${_trimOutput(result.stderr)}');
    }
    final outputType = await FileSystemEntity.type(
      outputResolved.hostPath, followLinks: false,
    );
    if (outputType != FileSystemEntityType.file) {
      throw const VideoEngineServiceException('engine_render_output_missing_or_unsafe');
    }
    final outputFile = File(outputResolved.hostPath);
    final realOutputPath = await outputFile.resolveSymbolicLinks();
    final realWorkspaceRoot = await Directory(
      context.paths.workspaceHostRoot,
    ).resolveSymbolicLinks();
    if (!p.isWithin(realWorkspaceRoot, realOutputPath) ||
        await outputFile.length() == 0) {
      throw const VideoEngineServiceException('engine_render_output_missing_or_unsafe');
    }
    // RuntimeProfileExecution's directory check covers KELIVO_TASK_OUTPUT_DIR.
    // Video engines write their primary artifact to the workspace output path,
    // so enforce the configured per-render budget here as a post-run check too.
    final selectedProfileId = runtimeProfileId ??
        context.workspace.defaultRuntimeProfileId;
    final selectedProfile = selectedProfileId == null || selectedProfileId.isEmpty
        ? null
        : await runtimeProfiles.inspectOwned(
            profileId: selectedProfileId,
            context: context,
          );
    if (selectedProfile != null &&
        selectedProfile.scope != RuntimeProfileScope.project) {
      throw const VideoEngineServiceException('engine_runtime_profile_scope_mismatch');
    }
    final maxOutputMegabytes = selectedProfile?.limits.normalized().maxOutputMegabytes ??
        const RuntimeResourceLimits().maxOutputMegabytes;
    final outputBytes = await outputFile.length();
    if (!isOutputWithinBudgetForTesting(
      bytes: outputBytes,
      maxOutputMegabytes: maxOutputMegabytes,
    )) {
      await outputFile.delete();
      throw VideoEngineServiceException(
        'engine_render_output_budget_exceeded:$maxOutputMegabytes',
      );
    }
    final updated = installation.record.copyWith(
      status: ExtensionLifecycleStatus.enabled,
      compatibility: {
        ...installation.record.compatibility,
        'preflightPassed': true,
        'renderVerified': true,
        'lastRenderVerifiedAt': DateTime.now().toUtc().toIso8601String(),
      },
      metadata: {
        ...installation.record.metadata,
        'renderVerified': true,
        'lastOutputPath': outputResolved.modelPath,
      },
      clearLastError: true,
    );
    await registry.upsert(updated);
    return {
      'ok': true,
      'engineId': engineId,
      'renderVerified': true,
      'outputPath': outputResolved.modelPath,
      'outputBytes': outputBytes,
      'outputBudgetMegabytes': maxOutputMegabytes,
      'outputBudgetEnforcement': 'post_run',
      'runId': result.runId,
      'durationMs': result.duration.inMilliseconds,
      'resourceAssessment': resourceAssessment.toJson(),
      'output': _trimOutput(result.stdout),
    };
  }

  Future<Map<String, Object?>> inspectProject({
    required String engineId,
    required WorkspaceToolContext context,
    String? projectDir,
    String? runtimeProfileId,
  }) async {
    final installation = await _readyForExecution(engineId, context);
    final requestedProjectDir = projectDir?.trim().isNotEmpty == true
        ? projectDir!.trim()
        : context.cwd;
    final resolved = context.paths.resolve(requestedProjectDir, cwd: context.cwd);
    if (resolved.zone != WorkspaceZone.workspace ||
        await FileSystemEntity.type(resolved.hostPath, followLinks: false) != FileSystemEntityType.directory) {
      throw const VideoEngineServiceException('engine_project_directory_invalid');
    }
    await _assertNoSymlinkPath(context, resolved.hostPath);
    final inspectRunId = 'engine-inspect-${const Uuid().v4()}';
    final result = await _executeSpec(
      installation: installation,
      spec: installation.manifest.command('inspect'),
      values: _placeholderValues(
        installation,
        context,
        projectDir: resolved.modelPath,
        projectName: p.posix.basename(resolved.modelPath),
        outputPath: _defaultOutputPath(
          context, engineId, extension: installation.manifest.outputExtension,
        ),
        runId: inspectRunId,
      ),
      context: context,
      runtimeProfileId: runtimeProfileId,
      cwd: resolved.modelPath,
      timeout: const Duration(minutes: 2),
      runtimeRunId: inspectRunId,
    );
    if (!result.succeeded) {
      throw VideoEngineServiceException('engine_inspect_failed:${result.exitCode}:${_trimOutput(result.stderr)}');
    }
    return {
      'ok': true,
      'engineId': engineId,
      'projectDirectory': resolved.modelPath,
      'runId': result.runId,
      'inspection': _trimOutput(result.stdout),
    };
  }

  Future<void> cancel({
    required String engineId,
    required String runId,
    required WorkspaceToolContext context,
    String? runtimeProfileId,
  }) async {
    if (!RuntimeProfileValidation.isSafeId(runId)) {
      throw const VideoEngineServiceException('engine_run_id_invalid');
    }
    final installation = await _readyForExecution(engineId, context);
    final cancelCommandRunId = 'engine-cancel-${const Uuid().v4()}';
    final cancelResult = await _executeSpec(
      installation: installation,
      spec: installation.manifest.command('cancel'),
      values: _placeholderValues(
        installation,
        context,
        projectDir: context.cwd,
        projectName: p.posix.basename(context.cwd),
        outputPath: _defaultOutputPath(
          context, engineId, extension: installation.manifest.outputExtension,
        ),
        runId: runId,
      ),
      context: context,
      runtimeProfileId: runtimeProfileId,
      timeout: const Duration(seconds: 30),
      runtimeRunId: cancelCommandRunId,
    );
    final runtime = runtimeProvider.runtime;
    if (runtime == null) throw const VideoEngineServiceException('engine_runtime_unavailable');
    await runtime.cancel(runId);
    if (!cancelResult.succeeded) {
      throw VideoEngineServiceException(
        'engine_cancel_command_failed:${cancelResult.exitCode}:${_trimOutput(cancelResult.stderr)}',
      );
    }
  }

  Future<Map<String, Object?>> handle({
    required Map<String, dynamic> args,
    required WorkspaceToolContext context,
    required WorkspaceProvider workspaces,
    ValueChanged<int>? onProgress,
  }) async {
    final action = (args['action'] ?? 'list').toString();
    final engineId = (args['engine_id'] ?? '').toString().trim();
    switch (action) {
      case 'resource_preflight':
        return resourcePreflight();
      case 'list':
        final engines = await list(context);
        return {
          'ok': true,
          'defaultEngineId': context.workspace.defaultVideoEngineId,
          'engines': [
            for (final item in engines)
              {
                'id': item.manifest.id,
                'name': item.manifest.name,
                'version': item.manifest.version,
                'status': item.record.status.wireValue,
                'preflightPassed': item.record.compatibility['preflightPassed'] == true,
                'renderVerified': item.record.compatibility['renderVerified'] == true,
                'description': item.manifest.description,
              },
          ],
        };
      case 'install':
        final installed = await install(
          source: (args['source'] ?? '').toString(),
          context: context,
        );
        return {
          'ok': true,
          'action': action,
          'engineId': installed.manifest.id,
          'name': installed.manifest.name,
          'version': installed.manifest.version,
          'status': installed.record.status.wireValue,
          'permissionsReview': ExtensionPermissionPolicy.review(installed.record.permissions),
          'note': 'The package was inspected and stored. Its commands and dependencies were not executed or installed. Declared permissions are reviewed, not automatically granted.',
        };
      case 'inspect':
        final installed = await inspect(engineId: _requireEngineId(engineId), context: context);
        return {
          'ok': true,
          'engine': installed.manifest.toJson(),
          'status': installed.record.status.wireValue,
          'compatibility': installed.record.compatibility,
          'metadata': installed.record.metadata,
          'permissionsReview': ExtensionPermissionPolicy.review(installed.record.permissions),
        };
      case 'preflight':
        return preflight(
          engineId: _requireEngineId(engineId),
          context: context,
          runtimeProfileId: (args['runtime_profile_id'] ?? '').toString().trim().nullIfEmpty,
        );
      case 'set_default':
        final updated = await setDefault(
          engineId: _requireEngineId(engineId),
          context: context,
          workspaces: workspaces,
        );
        return {'ok': true, 'defaultEngineId': updated.defaultVideoEngineId};
      case 'clear_default':
        final updated = await clearDefault(context: context, workspaces: workspaces);
        return {'ok': true, 'defaultEngineId': updated.defaultVideoEngineId};
      case 'configure':
        final raw = args['settings'];
        if (raw is! Map || raw.entries.any((entry) => entry.key is! String || entry.value is! String)) {
          throw const VideoEngineServiceException('engine_settings_must_be_string_map');
        }
        final updated = await configure(
          engineId: _requireEngineId(engineId),
          settings: {for (final entry in raw.entries) entry.key as String: entry.value as String},
          context: context,
          workspaces: workspaces,
        );
        return {
          'ok': true,
          'engineId': engineId,
          'settingKeys': (updated.videoEngineSettings[engineId] ?? const <String, String>{}).keys.toList()..sort(),
        };
      case 'create':
        return createProject(
          engineId: _effectiveEngineId(engineId, context),
          projectName: (args['project_name'] ?? '').toString(),
          context: context,
          runtimeProfileId: (args['runtime_profile_id'] ?? '').toString().trim().nullIfEmpty,
        );
      case 'render':
        return render(
          engineId: _effectiveEngineId(engineId, context),
          context: context,
          projectDir: (args['project_dir'] ?? '').toString().trim().nullIfEmpty,
          runtimeProfileId: (args['runtime_profile_id'] ?? '').toString().trim().nullIfEmpty,
          onProgress: onProgress,
        );
      case 'inspect_project':
        return inspectProject(
          engineId: _effectiveEngineId(engineId, context),
          context: context,
          projectDir: (args['project_dir'] ?? '').toString().trim().nullIfEmpty,
          runtimeProfileId: (args['runtime_profile_id'] ?? '').toString().trim().nullIfEmpty,
        );
      case 'cancel':
        final runId = (args['run_id'] ?? '').toString().trim();
        await cancel(
          engineId: _effectiveEngineId(engineId, context),
          runId: runId,
          context: context,
          runtimeProfileId: (args['runtime_profile_id'] ?? '').toString().trim().nullIfEmpty,
        );
        return {'ok': true, 'cancelledRunId': runId};
      case 'remove':
        await remove(
          engineId: _requireEngineId(engineId),
          context: context,
          workspaces: workspaces,
        );
        return {'ok': true, 'removedEngineId': engineId};
      default:
        throw VideoEngineServiceException('engine_action_unknown:$action');
    }
  }

  Future<InstalledVideoEngine> _readyForExecution(
    String engineId,
    WorkspaceToolContext context,
  ) async {
    final installation = await inspect(engineId: engineId, context: context);
    if (installation.record.compatibility['preflightPassed'] != true) {
      throw const VideoEngineServiceException('engine_preflight_required');
    }
    await _requireProotRuntime();
    return installation;
  }

  Future<InstalledVideoEngine> _loadInstalled(
    WorkspaceToolContext context,
    ExtensionRecord record,
  ) async {
    if (record.kind != 'engine' || record.metadata['workspaceId'] != context.workspace.id) {
      throw const VideoEngineServiceException('engine_workspace_mismatch');
    }
    final engineId = record.metadata['engineId'];
    final packagePath = record.metadata['packagePath'];
    if (engineId is! String ||
        packagePath is! String ||
        packagePath != '.kelivo/engines/$engineId') {
      throw const VideoEngineServiceException('engine_registry_path_invalid');
    }
    final rootHost = p.join(context.paths.workspaceHostRoot, packagePath);
    _assertWithinWorkspace(context, rootHost);
    await _assertNoSymlinkPath(context, rootHost);
    final manifestFile = File(p.join(rootHost, kVideoEngineManifestFile));
    await _assertNoSymlinkPath(context, manifestFile.path);
    if (await FileSystemEntity.type(manifestFile.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const VideoEngineServiceException('installed_engine_manifest_missing');
    }
    final manifestText = await manifestFile.readAsString();
    final manifest = VideoEngineManifest.parse(manifestText);
    final manifestDigest = sha256.convert(utf8.encode(manifestText)).toString();
    if (manifest.id != engineId ||
        record.version != manifest.version ||
        record.digest != manifestDigest) {
      throw const VideoEngineServiceException('engine_manifest_registry_mismatch');
    }
    final rootRuntime = p.posix.join(context.paths.modelRoot, packagePath);
    return InstalledVideoEngine(
      record: record,
      manifest: manifest,
      rootHostPath: rootHost,
      rootRuntimePath: rootRuntime,
    );
  }

  Future<ExtensionRecord> _record(
    WorkspaceToolContext context,
    String engineId,
  ) async {
    _requireWorkspace(context);
    if (!RegExp(r'^[a-z0-9][a-z0-9._-]{0,63}$').hasMatch(engineId)) {
      throw const VideoEngineServiceException('engine_id_invalid');
    }
    final record = await registry.get('engine', _recordId(context.workspace.id, engineId));
    if (record == null) throw const VideoEngineServiceException('engine_not_installed');
    return record;
  }

  Future<RuntimeStatus> _requireProotRuntime() async {
    final runtime = runtimeProvider.runtime;
    if (runtime == null) throw const VideoEngineServiceException('engine_runtime_not_registered');
    final status = await runtime.status();
    if (!status.ready) throw VideoEngineServiceException(status.reason ?? 'engine_runtime_not_ready');
    if (!status.sandboxed || status.engine != 'proot') {
      throw const VideoEngineServiceException('video_engines_require_android_proot');
    }
    return status;
  }

  Future<String> _readArchitecture(WorkspaceToolContext context) async {
    final result = await _runRaw(
      context: context,
      command: 'uname -m',
      cwd: context.cwd,
      timeout: const Duration(seconds: 15),
    );
    if (!result.succeeded) throw const VideoEngineServiceException('engine_architecture_detection_failed');
    final value = result.stdout.trim().split(RegExp(r'\s+')).firstOrNull ?? '';
    return value == 'arm64' ? 'arm64-v8a' : value;
  }

  Future<void> _validateRequiredEcosystems(
    VideoEngineManifest manifest,
    WorkspaceToolContext context, {
    String? runtimeProfileId,
  }) async {
    final profileId = runtimeProfileId ?? context.workspace.defaultRuntimeProfileId;
    for (final ecosystem in manifest.requiredEcosystems) {
      if (profileId == null || profileId.isEmpty) {
        throw VideoEngineServiceException('engine_runtime_profile_required:$ecosystem');
      }
      await runtimeProfiles.validatePackageTarget(
        profileId: profileId,
        scope: 'project',
        ownerId: context.workspace.id,
        ecosystem: ecosystem,
      );
    }
  }

  Future<List<String>> _missingCommands(
    List<String> commands,
    WorkspaceToolContext context, {
    String? runtimeProfileId,
  }) async {
    if (commands.isEmpty) return const [];
    final quoted = commands.map(_quote).join(' ');
    final command =
        'for __kelivo_cmd in $quoted; do command -v "${r'$'}__kelivo_cmd" >/dev/null 2>&1 || echo "__KELIVO_MISSING__:${r'$'}__kelivo_cmd"; done';
    final result = await _runRaw(
      context: context,
      command: command,
      cwd: context.cwd,
      timeout: const Duration(seconds: 30),
      runtimeProfileId: runtimeProfileId,
    );
    if (!result.succeeded) {
      throw const VideoEngineServiceException('engine_dependency_probe_failed');
    }
    return [
      for (final match in RegExp(r'__KELIVO_MISSING__:([A-Za-z0-9_.+-]+)').allMatches(result.stdout))
        match.group(1)!,
    ];
  }

  Future<Map<String, Object?>> _persistPreflightFailure(
    InstalledVideoEngine installation,
    String architecture,
    String error,
    VideoEngineCommandResult result, {
    String? versionOutput,
  }) async {
    final updated = installation.record.copyWith(
      compatibility: {
        ...installation.record.compatibility,
        'preflightPassed': false,
        'architecture': architecture,
        'preflightError': error,
        'preflightAt': DateTime.now().toUtc().toIso8601String(),
      },
      metadata: {
        ...installation.record.metadata,
        if (versionOutput != null) 'detectedVersion': versionOutput,
      },
    );
    await registry.upsert(updated);
    return {
      'ok': false,
      'engineId': installation.manifest.id,
      'error': error,
      'exitCode': result.exitCode,
      'stdout': _trimOutput(result.stdout),
      'stderr': _trimOutput(result.stderr),
    };
  }

  Future<VideoEngineCommandResult> _executeSpec({
    required InstalledVideoEngine installation,
    required VideoEngineCommand spec,
    required Map<String, String> values,
    required WorkspaceToolContext context,
    String? runtimeProfileId,
    String? cwd,
    required Duration timeout,
    String? runtimeRunId,
    ValueChanged<int>? onProgress,
  }) async {
    final executable = spec.executable.contains('/')
        ? p.posix.join(installation.rootRuntimePath, spec.executable)
        : spec.executable;
    if (spec.executable.contains('/')) {
      final executableHostPath = p.join(
        installation.rootHostPath,
        spec.executable,
      );
      await _assertNoSymlinkPath(context, executableHostPath);
      if (await FileSystemEntity.type(executableHostPath, followLinks: false) !=
          FileSystemEntityType.file) {
        throw const VideoEngineServiceException('engine_executable_missing_or_unsafe');
      }
    }
    final args = spec.expandArguments(values);
    final command = [executable, ...args].map(_quote).join(' ');
    return _runRaw(
      context: context,
      command: command,
      cwd: cwd ?? context.cwd,
      timeout: timeout,
      runtimeProfileId: runtimeProfileId,
      env: _engineSettingsEnvironment(context, installation.manifest.id),
      runId: runtimeRunId,
      onProgress: onProgress,
    );
  }

  Map<String, String> _engineSettingsEnvironment(
    WorkspaceToolContext context,
    String engineId,
  ) {
    final settings = context.workspace.videoEngineSettings[engineId] ??
        const <String, String>{};
    final environment = <String, String>{};
    final sensitiveKey = RegExp(
      r'(?:token|secret|password|credential|authorization|api[_-]?key)',
      caseSensitive: false,
    );
    for (final entry in settings.entries) {
      final key = entry.key.trim().toLowerCase();
      final value = entry.value;
      if (!RegExp(r'^[a-z][a-z0-9_.-]{0,63}$').hasMatch(key) ||
          sensitiveKey.hasMatch(key) ||
          value.length > 4096 ||
          value.contains(RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]'))) {
        throw const VideoEngineServiceException('engine_setting_invalid_or_sensitive');
      }
      final environmentKey = 'KELIVO_ENGINE_SETTING_${key.toUpperCase()}';
      if (environment.containsKey(environmentKey)) {
        throw const VideoEngineServiceException('engine_setting_key_duplicate');
      }
      environment[environmentKey] = value;
    }
    return environment;
  }

  Future<VideoEngineCommandResult> _runRaw({
    required WorkspaceToolContext context,
    required String command,
    required String cwd,
    required Duration timeout,
    String? runtimeProfileId,
    Map<String, String>? env,
    String? runId,
    ValueChanged<int>? onProgress,
  }) async {
    final runtime = runtimeProvider.runtime;
    if (runtime == null) throw const VideoEngineServiceException('engine_runtime_unavailable');
    final status = await runtime.status();
    if (!status.ready || !status.sandboxed || status.engine != 'proot') {
      throw const VideoEngineServiceException('video_engines_require_android_proot');
    }
    final runtimeRunId = runId ?? 'engine-${const Uuid().v4()}';
    final profileExecution = await runtimeProfiles.resolveExecution(
      context: context,
      runId: runtimeRunId,
      requestedProfileId: runtimeProfileId,
    );
    final actualTimeout = profileExecution == null ||
            timeout.inSeconds <= profileExecution.timeout.inSeconds
        ? timeout
        : profileExecution.timeout;
    final invocation = 'cd -- ${_quote(cwd)} && $command';
    final effectiveCommand = profileExecution?.wrapCommand(invocation) ?? invocation;
    final environment = <String, String>{
      'HOME': '/root',
      'PATH': '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
      'NO_COLOR': '1',
      'CI': 'true',
      'LANG': 'C.UTF-8',
      'TMPDIR': '/tmp',
      if (profileExecution != null) ...profileExecution.environment,
      ...?env,
    };
    if (profileExecution != null) {
      try {
        await runtimeProfiles.recordStarted(
          execution: profileExecution,
          runtimeRunId: runtimeRunId,
          command: command,
        );
      } on Object {
        try {
          await runtimeProfiles.cleanupExecution(
            context: context, execution: profileExecution,
          );
        } finally {
          runtimeProfiles.releaseReservation(profileExecution.profile.id, runtimeRunId);
        }
        rethrow;
      }
    }
    final cancellation = ToolCallCancellation.current;
    void Function()? unregisterCancellation;
    final stopwatch = Stopwatch()..start();
    final stdout = StringBuffer();
    final stderr = StringBuffer();
    var progressBuffer = '';
    int? lastProgressPercent;
    var outputBytes = 0;
    CommandExited? exited;
    try {
      cancellation?.throwIfCancelled();
      unregisterCancellation = cancellation?.onCancel(() {
        unawaited(runtime.cancel(runtimeRunId));
      });
      await for (final event in runtime.run(CommandRequest(
        runId: runtimeRunId,
        command: effectiveCommand,
        cwd: context.paths.normalizeCwd(cwd),
        timeout: actualTimeout,
        env: environment,
        mounts: context.paths.mounts,
        isCancelled: cancellation?.isCancelled,
      ))) {
        switch (event) {
          case CommandOutput(:final kind, :final bytes):
            if (outputBytes < _maxEngineOutputBytes) {
              final remaining = _maxEngineOutputBytes - outputBytes;
              final selected = bytes.length > remaining ? bytes.sublist(0, remaining) : bytes;
              outputBytes += selected.length;
              final text = utf8.decode(selected, allowMalformed: true);
              if (kind == OutputStreamKind.stdout) {
                stdout.write(text);
                if (onProgress != null) {
                  // Engine adapters may emit `KELIVO_PROGRESS: 42` or a
                  // conventional `42%` status line. Only real reported values
                  // are surfaced; otherwise Android keeps an indeterminate bar.
                  progressBuffer = '$progressBuffer$text';
                  final matches = RegExp(
                    r'(?:KELIVO_PROGRESS|progress|percent)\s*[:=]\s*(\d{1,3})(?:\.\d+)?%?|\b(\d{1,3})(?:\.\d+)?%',
                    caseSensitive: false,
                  ).allMatches(progressBuffer);
                  for (final match in matches) {
                    final raw = match.group(1) ?? match.group(2);
                    final percent = int.tryParse(raw ?? '');
                    if (percent == null) continue;
                    final bounded = percent.clamp(0, 100);
                    if (bounded != lastProgressPercent) {
                      lastProgressPercent = bounded;
                      onProgress(bounded);
                    }
                  }
                  if (progressBuffer.length > 512) {
                    progressBuffer = progressBuffer.substring(progressBuffer.length - 512);
                  }
                }
              } else {
                stderr.write(text);
              }
            }
          case CommandExited():
            exited = event;
          case CommandStarted():
            break;
        }
      }
      cancellation?.throwIfCancelled();
    } finally {
      stopwatch.stop();
      unregisterCancellation?.call();
      if (profileExecution != null) {
        try {
          await runtimeProfiles.cleanupExecution(
            context: context, execution: profileExecution,
          );
        } catch (error) {
          debugPrint('Video engine Runtime Profile cleanup failed: $error');
        }
        final profileStatus = exited == null
            ? RuntimeProcessStatus.failed
            : exited.cancelled
            ? RuntimeProcessStatus.cancelled
            : exited.timedOut
            ? RuntimeProcessStatus.timedOut
            : exited.exitCode == 0
            ? RuntimeProcessStatus.succeeded
            : RuntimeProcessStatus.failed;
        try {
          await runtimeProfiles.recordCompleted(
            execution: profileExecution,
            runtimeRunId: runtimeRunId,
            status: profileStatus,
            exitCode: exited?.exitCode,
          );
        } catch (error) {
          runtimeProfiles.releaseReservation(profileExecution.profile.id, runtimeRunId);
          debugPrint('Video engine Runtime Profile ledger update failed: $error');
        }
      }
    }
    final commandResult = exited;
    if (commandResult == null) {
      throw const VideoEngineServiceException('engine_command_terminated_without_exit_event');
    }
    if (commandResult.interrupted) {
      throw const VideoEngineServiceException('engine_command_interrupted');
    }
    return VideoEngineCommandResult(
      runId: runtimeRunId,
      exitCode: commandResult.exitCode,
      stdout: stdout.toString(),
      stderr: stderr.toString(),
      duration: stopwatch.elapsed,
      timedOut: commandResult.timedOut,
      cancelled: commandResult.cancelled,
    );
  }

  Future<Uint8List> _downloadGitHubArchive(GitHubSkillRef ref) async {
    final path = '/repos/${Uri.encodeComponent(ref.owner)}/${Uri.encodeComponent(ref.repo)}/zipball/${Uri.encodeComponent(ref.ref ?? 'HEAD')}';
    final uri = Uri.https('api.github.com', path);
    final response = await _httpClient.get(uri, headers: const {
      'Accept': 'application/vnd.github+json',
      'User-Agent': 'Kelivo-Video-Engine-Installer',
      'X-GitHub-Api-Version': '2022-11-28',
    });
    if (response.statusCode != 200) {
      throw VideoEngineServiceException('engine_github_download_failed:${response.statusCode}');
    }
    final finalHost = response.request?.url.host.toLowerCase();
    if (finalHost != null && !const {
      'api.github.com',
      'github.com',
      'codeload.github.com',
      'objects.githubusercontent.com',
    }.contains(finalHost)) {
      throw const VideoEngineServiceException('engine_github_redirect_untrusted');
    }
    final bytes = response.bodyBytes;
    if (bytes.length > _maxEngineArchiveBytes) {
      throw const VideoEngineServiceException('engine_archive_too_large');
    }
    return bytes;
  }

  static void _extractEngineArchive(
    List<int> archiveBytes,
    String outputDirectory, {
    String? subdir,
  }) {
    if (archiveBytes.length > _maxEngineArchiveBytes) {
      throw const VideoEngineServiceException('engine_archive_too_large');
    }
    final archive = ZipDecoder().decodeBytes(archiveBytes);
    final entries = <String, ArchiveFile>{};
    var expandedSize = 0;
    for (final file in archive) {
      if (!file.isFile) continue;
      if (file.isSymbolicLink) {
        throw const VideoEngineServiceException('engine_archive_symlink_rejected');
      }
      final name = _safeArchivePath(file.name);
      if (name == null) continue;
      if (entries.containsKey(name)) {
        throw const VideoEngineServiceException('engine_archive_duplicate_entry');
      }
      if (entries.length >= _maxEngineFiles) {
        throw const VideoEngineServiceException('engine_archive_file_count_exceeded');
      }
      expandedSize += file.size;
      if (expandedSize > _maxEngineExtractedBytes) {
        throw const VideoEngineServiceException('engine_archive_expanded_size_exceeded');
      }
      entries[name] = file;
    }
    if (entries.isEmpty) throw const VideoEngineServiceException('engine_archive_empty');

    var selected = entries;
    final roots = entries.keys.map((name) => name.split('/').first).toSet();
    if (roots.length == 1) {
      final onlyRoot = roots.single;
      selected = {
        for (final entry in entries.entries)
          if (entry.key.startsWith('$onlyRoot/'))
            entry.key.substring(onlyRoot.length + 1): entry.value,
      };
    }
    if (subdir != null && subdir.isNotEmpty) {
      final normalizedSubdir = _safeArchivePath(subdir);
      if (normalizedSubdir == null) {
        throw const VideoEngineServiceException('engine_archive_subpath_invalid');
      }
      final prefix = '$normalizedSubdir/';
      selected = {
        for (final entry in selected.entries)
          if (entry.key.startsWith(prefix))
            entry.key.substring(prefix.length): entry.value,
      };
    }
    if (!selected.containsKey(kVideoEngineManifestFile)) {
      throw const VideoEngineServiceException('engine_manifest_not_found_at_selected_root');
    }
    final canonicalOutput = p.canonicalize(outputDirectory);
    for (final entry in selected.entries) {
      final destination = p.join(outputDirectory, entry.key);
      if (!p.isWithin(canonicalOutput, p.canonicalize(destination))) {
        throw const VideoEngineServiceException('engine_archive_path_escape');
      }
      final content = entry.value.content;
      final file = File(destination);
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(content, flush: false);
    }
  }

  static Future<void> _copyPackageDirectory(String source, String destination) async {
    final root = Directory(source);
    var count = 0;
    var totalBytes = 0;
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (type == FileSystemEntityType.link) {
        throw const VideoEngineServiceException('engine_package_symlink_rejected');
      }
      final relative = p.relative(entity.path, from: source).replaceAll('\\', '/');
      if (relative.isEmpty || relative == '.') continue;
      final safe = _safeArchivePath(relative);
      if (safe == null) continue;
      if (type == FileSystemEntityType.directory) {
        await Directory(p.join(destination, safe)).create(recursive: true);
      } else if (type == FileSystemEntityType.file) {
        count++;
        if (count > _maxEngineFiles) {
          throw const VideoEngineServiceException('engine_package_file_count_exceeded');
        }
        final file = File(entity.path);
        totalBytes += await file.length();
        if (totalBytes > _maxEngineExtractedBytes) {
          throw const VideoEngineServiceException('engine_package_size_exceeded');
        }
        final target = File(p.join(destination, safe));
        await target.parent.create(recursive: true);
        await file.copy(target.path);
      }
    }
    if (!await File(p.join(destination, kVideoEngineManifestFile)).exists()) {
      throw const VideoEngineServiceException('engine_manifest_not_found_at_package_root');
    }
  }

  @visibleForTesting
  static String? normalizeArchivePathForTesting(String raw) => _safeArchivePath(raw);

  static String? _safeArchivePath(String raw) {
    final value = raw.replaceAll('\\', '/');
    if (value.startsWith('/') ||
        value.contains('\u0000') ||
        RegExp(r'^[A-Za-z]:').hasMatch(value) ||
        value.split('/').any((part) => part == '..' || part == '.')) {
      throw const VideoEngineServiceException('engine_archive_path_unsafe');
    }
    if (value.isEmpty || value.endsWith('/')) return null;
    final normalized = p.posix.normalize(value);
    if (normalized == '.' || normalized.startsWith('/') || normalized.split('/').contains('..')) {
      throw const VideoEngineServiceException('engine_archive_path_unsafe');
    }
    return normalized;
  }

  Map<String, String> _placeholderValues(
    InstalledVideoEngine installation,
    WorkspaceToolContext context, {
    required String projectDir,
    required String projectName,
    required String outputPath,
    required String runId,
  }) => {
    'workspace': context.paths.modelRoot,
    'project_dir': projectDir,
    'project_name': projectName,
    'output_path': outputPath,
    'output_dir': p.posix.dirname(outputPath),
    'engine_root': installation.rootRuntimePath,
    'run_id': runId,
  };

  String _defaultOutputPath(
    WorkspaceToolContext context,
    String engineId, {
    String extension = 'mp4',
  }) {
    final file = 'render-${const Uuid().v4()}.$extension';
    return p.posix.join(context.paths.modelRoot, '.kelivo', 'engine-output', engineId, file);
  }


  @visibleForTesting
  static bool isOutputWithinBudgetForTesting({
    required int bytes,
    required int maxOutputMegabytes,
  }) {
    if (bytes < 0 || maxOutputMegabytes < 1) return false;
    return bytes <= maxOutputMegabytes * 1024 * 1024;
  }

  static String _validateProjectName(String value) {
    final name = value.trim();
    if (name.isEmpty || name.length > 80 ||
        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9 _.-]{0,79}$').hasMatch(name) ||
        name == '.' || name == '..' || name.contains('..')) {
      throw const VideoEngineServiceException('engine_project_name_invalid');
    }
    return name;
  }

  static String _requireEngineId(String value) {
    if (!RegExp(r'^[a-z0-9][a-z0-9._-]{0,63}$').hasMatch(value)) {
      throw const VideoEngineServiceException('engine_id_required');
    }
    return value;
  }

  static String _effectiveEngineId(String requested, WorkspaceToolContext context) {
    final value = requested.isNotEmpty ? requested : context.workspace.defaultVideoEngineId;
    if (value == null || value.isEmpty) {
      throw const VideoEngineServiceException('project_video_engine_not_selected');
    }
    return _requireEngineId(value);
  }

  static String _recordId(String workspaceId, String engineId) {
    final workspaceKey = sha256
        .convert(utf8.encode(workspaceId))
        .toString()
        .substring(0, 16);
    return 'ws-$workspaceKey--$engineId';
  }

  String _engineRootHost(WorkspaceToolContext context, String engineId) =>
      p.join(context.paths.workspaceHostRoot, '.kelivo', 'engines', engineId);

  static String _quote(String value) => "'${value.replaceAll("'", "'\\''")}'";

  static String _trimOutput(String value, {int maxLength = 6000}) {
    final normalized = value.trim();
    if (normalized.length <= maxLength) return normalized;
    return '${normalized.substring(0, maxLength)}…[truncated]';
  }

  static Future<void> _prepareWorkspaceDirectory(
    WorkspaceToolContext context,
    String path,
  ) async {
    _assertWithinWorkspace(context, path);
    final rootPath = p.normalize(p.absolute(context.paths.workspaceHostRoot));
    final targetPath = p.normalize(p.absolute(path));
    final rootType = await FileSystemEntity.type(rootPath, followLinks: false);
    if (rootType == FileSystemEntityType.link) {
      throw const VideoEngineServiceException('engine_workspace_root_symlink_rejected');
    }
    if (rootType == FileSystemEntityType.notFound) {
      throw const VideoEngineServiceException('engine_workspace_root_missing');
    }
    if (rootType != FileSystemEntityType.directory) {
      throw const VideoEngineServiceException('engine_workspace_root_invalid');
    }
    final realRoot = await Directory(rootPath).resolveSymbolicLinks();
    var current = rootPath;
    final relative = p.relative(targetPath, from: rootPath);
    for (final segment in p.split(relative)) {
      if (segment.isEmpty || segment == '.') continue;
      if (segment == '..') {
        throw const VideoEngineServiceException('engine_path_outside_workspace');
      }
      current = p.join(current, segment);
      final type = await FileSystemEntity.type(current, followLinks: false);
      if (type == FileSystemEntityType.link) {
        throw const VideoEngineServiceException('engine_workspace_symlink_rejected');
      }
      if (type == FileSystemEntityType.notFound) {
        await Directory(current).create();
      } else if (type != FileSystemEntityType.directory) {
        throw const VideoEngineServiceException('engine_install_parent_not_directory');
      }
      final realCurrent = await Directory(current).resolveSymbolicLinks();
      if (realCurrent != realRoot && !p.isWithin(realRoot, realCurrent)) {
        throw const VideoEngineServiceException('engine_path_outside_workspace');
      }
    }
  }

  static Future<void> _assertNoSymlinkPath(
    WorkspaceToolContext context,
    String path,
  ) async {
    _assertWithinWorkspace(context, path);
    final rootPath = p.normalize(p.absolute(context.paths.workspaceHostRoot));
    final targetPath = p.normalize(p.absolute(path));
    final rootType = await FileSystemEntity.type(rootPath, followLinks: false);
    if (rootType != FileSystemEntityType.directory) {
      throw const VideoEngineServiceException('engine_workspace_root_invalid');
    }
    final realRoot = await Directory(rootPath).resolveSymbolicLinks();
    var current = rootPath;
    final relative = p.relative(targetPath, from: rootPath);
    for (final segment in p.split(relative)) {
      if (segment.isEmpty || segment == '.') continue;
      if (segment == '..') {
        throw const VideoEngineServiceException('engine_path_outside_workspace');
      }
      current = p.join(current, segment);
      final type = await FileSystemEntity.type(current, followLinks: false);
      if (type == FileSystemEntityType.notFound) return;
      if (type == FileSystemEntityType.link) {
        throw const VideoEngineServiceException('engine_workspace_symlink_rejected');
      }
      final realCurrent = type == FileSystemEntityType.directory
          ? await Directory(current).resolveSymbolicLinks()
          : await File(current).resolveSymbolicLinks();
      if (realCurrent != realRoot && !p.isWithin(realRoot, realCurrent)) {
        throw const VideoEngineServiceException('engine_path_outside_workspace');
      }
    }
  }

  static void _assertWithinWorkspace(WorkspaceToolContext context, String path) {
    final root = p.canonicalize(context.paths.workspaceHostRoot);
    final canonical = p.canonicalize(path);
    if (canonical == root || !p.isWithin(root, canonical)) {
      throw const VideoEngineServiceException('engine_path_outside_workspace');
    }
  }

  static void _requireWorkspace(WorkspaceToolContext context) {
    if (context.skillsOnly) throw const VideoEngineServiceException('workspace_required');
    if (!RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]{0,127}$').hasMatch(context.workspace.id)) {
      throw const VideoEngineServiceException('workspace_id_invalid_for_engine_registry');
    }
  }

  void dispose() {
    if (_ownsHttpClient) _httpClient.close();
  }
}

extension _NullableString on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
