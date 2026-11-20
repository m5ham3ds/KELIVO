import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../models/extension_record.dart';
import '../extensions/extension_registry_repository.dart';
import '../extensions/extension_permission_policy.dart';
import '../video_production/video_production_service.dart';
import '../workspace/workspace_tool_context.dart';
import '../workspace/workspace_runtime.dart';
import 'video_provider_credential_store.dart';
import 'video_provider_manifest.dart';

const int _maxProviderManifestBytes = 64 * 1024;
const int _maxProviderJsonBytes = 1024 * 1024;

final class VideoProviderServiceException implements Exception {
  const VideoProviderServiceException(this.code);

  final String code;

  @override
  String toString() => code;
}

final class _InstalledVideoProvider {
  const _InstalledVideoProvider({
    required this.record,
    required this.manifest,
    required this.manifestPath,
  });

  final ExtensionRecord record;
  final VideoProviderManifest manifest;
  final String manifestPath;
}

final class _ProviderJobSnapshot {
  const _ProviderJobSnapshot({
    required this.status,
    required this.outputUrl,
    this.progress,
    this.actualCostMicros,
    this.currency,
  });

  final String status;
  final Uri? outputUrl;
  final double? progress;
  final int? actualCostMicros;
  final String? currency;
}

/// Manages declarative, optional AI video REST connectors per Workspace.
/// Connector manifests never contain executable code or credentials.
final class VideoProviderConnectorService {
  VideoProviderConnectorService({
    required this.registry,
    required this.credentials,
    required this.videoProduction,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null;

  final ExtensionRegistryRepository registry;
  final VideoProviderCredentialStore credentials;
  final VideoProductionService videoProduction;
  final http.Client _httpClient;
  final bool _ownsHttpClient;

  Future<Map<String, Object?>> handle({
    required Map<String, dynamic> args,
    required WorkspaceToolContext context,
    ValueChanged<double>? onProgress,
  }) async {
    _requireWorkspace(context);
    final action = (args['action'] ?? 'list').toString();
    switch (action) {
      case 'list':
        return _list(context);
      case 'inspect':
        return _inspect(_string(args, 'provider_id'), context);
      case 'install':
        return _install(args, context, update: false);
      case 'update':
        return _install(args, context, update: true);
      case 'remove':
        return _remove(_string(args, 'provider_id'), context);
      case 'credential_status':
        return _credentialStatus(_string(args, 'provider_id'), context);
      case 'set_limits':
        return _setLimits(args, context);
      case 'limits':
        return _limits(context);
      case 'submit':
        return _submit(args, context);
      case 'poll':
        return _poll(
          _string(args, 'job_id'),
          context,
          expectedVersion: args['expected_provider_version'],
          expectedDigest: args['expected_provider_digest'],
          onProgress: onProgress,
        );
      case 'download':
        return _download(
          _string(args, 'job_id'),
          context,
          expectedVersion: args['expected_provider_version'],
          expectedDigest: args['expected_provider_digest'],
          onProgress: onProgress,
        );
      default:
        throw const VideoProviderServiceException('provider_action_unsupported');
    }
  }

  Future<Map<String, Object?>> _list(WorkspaceToolContext context) async {
    final records = await registry.list(kind: 'video_provider');
    final items = <Map<String, Object?>>[];
    for (final record in records) {
      if (record.metadata['workspaceId'] != context.workspace.id) continue;
      try {
        final provider = await _loadProvider(record, context);
        items.add({
          ...provider.manifest.toSummaryJson(),
          'installedVersion': record.version,
          'status': record.status.wireValue,
          'credentialConfigured': await credentials.has(
            workspaceId: context.workspace.id,
            providerId: provider.manifest.id,
          ),
        });
      } on Object {
        items.add({
          'id': record.metadata['providerId'] ?? record.id,
          'name': record.name,
          'status': 'invalid_manifest',
        });
      }
    }
    return {'ok': true, 'action': 'list', 'providers': items};
  }

  Future<Map<String, Object?>> _inspect(
    String providerId,
    WorkspaceToolContext context,
  ) async {
    final provider = await _loadProvider(await _providerRecord(providerId, context), context);
    return {
      'ok': true,
      'action': 'inspect',
      'provider': provider.manifest.toSummaryJson(),
      'manifestDigest': provider.record.digest,
      'source': provider.record.source.toJson(),
      'installedAt': provider.record.installedAt?.toIso8601String(),
      'updatedAt': provider.record.updatedAt.toIso8601String(),
      'credentialConfigured': await credentials.has(
        workspaceId: context.workspace.id,
        providerId: providerId,
      ),
      'credentialValueReturned': false,
      'permissionsReview': ExtensionPermissionPolicy.review(provider.record.permissions),
    };
  }

  Future<Map<String, Object?>> _credentialStatus(
    String providerId,
    WorkspaceToolContext context,
  ) async {
    await _providerRecord(providerId, context);
    return {
      'ok': true,
      'action': 'credential_status',
      'providerId': providerId,
      'configured': await credentials.has(
        workspaceId: context.workspace.id,
        providerId: providerId,
      ),
      'secretReturned': false,
    };
  }

  Future<Map<String, Object?>> _install(
    Map<String, dynamic> args,
    WorkspaceToolContext context, {
    required bool update,
  }) async {
    final source = await _readManifestSource(args, context);
    final manifest = VideoProviderManifest.parse(source.contents);
    final registryId = _scopedProviderRecordId(context.workspace.id, manifest.id);
    final existing = await registry.get('video_provider', registryId);
    if (update && existing == null) {
      throw const VideoProviderServiceException('provider_not_installed');
    }
    if (!update && existing != null &&
        existing.metadata['workspaceId'] == context.workspace.id) {
      throw const VideoProviderServiceException('provider_already_installed');
    }
    if (existing != null && existing.metadata['workspaceId'] != context.workspace.id) {
      throw const VideoProviderServiceException('provider_id_owned_by_another_workspace');
    }
    if (update && await _hasActiveJobs(manifest.id, context)) {
      throw const VideoProviderServiceException('provider_update_blocked_by_active_jobs');
    }

    final root = p.join(
      context.paths.workspaceHostRoot,
      '.kelivo',
      'video-providers',
      manifest.id,
    );
    String? rollbackBackupPath;
    await _assertNoSymlinkPath(context, root);
    await Directory(root).create(recursive: true);
    await _assertNoSymlinkPath(context, root);
    final manifestPath = p.join(root, kVideoProviderManifestFile);
    await _assertNoSymlinkPath(context, manifestPath);
    if (existing != null) {
      final oldPath = existing.metadata['manifestPath'];
      if (oldPath is String) {
        final prior = p.join(context.paths.workspaceHostRoot, oldPath);
        if (p.normalize(prior) != p.normalize(manifestPath)) {
          throw const VideoProviderServiceException('provider_manifest_path_invalid');
        }
        await _assertNoSymlinkPath(context, prior);
        if (await FileSystemEntity.type(prior, followLinks: false) ==
            FileSystemEntityType.file) {
          final backupRoot = p.join(
            context.paths.workspaceHostRoot,
            '.kelivo',
            'video-provider-backups',
            manifest.id,
          );
          await _assertNoSymlinkPath(context, backupRoot);
          await Directory(backupRoot).create(recursive: true);
          await _assertNoSymlinkPath(context, backupRoot);
          final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
          final backup = p.join(backupRoot, '$stamp.yaml');
          await File(prior).copy(backup);
          rollbackBackupPath = backup;
        }
      }
    }
    final temporary = p.join(root, '.manifest-${const Uuid().v4()}.tmp');
    await _assertNoSymlinkPath(context, temporary);
    await File(temporary).writeAsString(source.contents, flush: true);
    await _assertNoSymlinkPath(context, temporary);
    try {
      if (await FileSystemEntity.type(manifestPath, followLinks: false) ==
          FileSystemEntityType.file) {
        await File(manifestPath).delete();
      }
      await File(temporary).rename(manifestPath);
      final digest = 'sha256:${sha256.convert(utf8.encode(source.contents))}';
      final now = DateTime.now().toUtc();
      final record = ExtensionRecord(
        id: registryId,
        kind: 'video_provider',
        name: manifest.name,
        source: source.source,
        status: ExtensionLifecycleStatus.enabled,
        version: manifest.version,
        digest: digest,
        compatibility: const {'platforms': ['android'], 'protocol': 'kelivo-video-provider-rest-v1'},
        permissions: const ['network.video_generation'],
        entryPoint: kVideoProviderManifestFile,
        installedAt: existing?.installedAt ?? now,
        updatedAt: now,
        metadata: {
          'workspaceId': context.workspace.id,
          'providerId': manifest.id,
          'manifestPath': p.relative(manifestPath, from: context.paths.workspaceHostRoot),
        },
      );
      await registry.upsert(record);
      return {
        'ok': true,
        'action': update ? 'update' : 'install',
        'providerId': manifest.id,
        'name': manifest.name,
        'version': manifest.version,
        'capabilities': {
          'textToVideo': manifest.supportsTextToVideo,
          'imageToVideo': manifest.supportsImageToVideo,
        },
        'credentialPreserved': update && await credentials.has(
          workspaceId: context.workspace.id,
          providerId: manifest.id,
        ),
        'executionModel': 'declarative_rest_no_connector_code_executed',
        'permissionsReview': ExtensionPermissionPolicy.review(record.permissions),
      };
    } on Object {
      try {
        if (await FileSystemEntity.type(manifestPath, followLinks: false) ==
            FileSystemEntityType.file) {
          await File(manifestPath).delete();
        }
        if (rollbackBackupPath != null &&
            await FileSystemEntity.type(rollbackBackupPath, followLinks: false) ==
                FileSystemEntityType.file) {
          await File(rollbackBackupPath).copy(manifestPath);
        }
        if (await FileSystemEntity.type(temporary, followLinks: false) ==
            FileSystemEntityType.file) {
          await File(temporary).delete();
        }
      } catch (_) {}
      rethrow;
    }
  }

  Future<Map<String, Object?>> _remove(
    String providerId,
    WorkspaceToolContext context,
  ) async {
    final record = await _providerRecord(providerId, context);
    if (await _hasActiveJobs(providerId, context)) {
      throw const VideoProviderServiceException('provider_remove_blocked_by_active_jobs');
    }
    final path = record.metadata['manifestPath'];
    if (path is String) {
      final manifestPath = p.join(context.paths.workspaceHostRoot, path);
      await _assertNoSymlinkPath(context, manifestPath);
      if (await FileSystemEntity.type(manifestPath, followLinks: false) ==
          FileSystemEntityType.file) {
        await File(manifestPath).delete();
      }
    }
    await credentials.clear(
      workspaceId: context.workspace.id,
      providerId: providerId,
    );
    await registry.remove('video_provider', record.id);
    return {
      'ok': true,
      'action': 'remove',
      'providerId': providerId,
      'credentialRemoved': true,
      'jobHistoryPreserved': true,
    };
  }

  Future<Map<String, Object?>> _limits(WorkspaceToolContext context) async {
    final current = await _readLimits(context);
    return {'ok': true, 'action': 'limits', 'limits': current};
  }

  Future<Map<String, Object?>> _setLimits(
    Map<String, dynamic> args,
    WorkspaceToolContext context,
  ) async {
    final current = await _readLimits(context);
    final maxDailyRequests = _intArg(
      args,
      'max_requests_per_day',
      fallback: current['maxRequestsPerDay'] as int,
      min: 1,
      max: 1000,
    );
    final maxConcurrentJobs = _intArg(
      args,
      'max_concurrent_jobs',
      fallback: current['maxConcurrentJobs'] as int,
      min: 1,
      max: 10,
    );
    final maxDownloadBytes = _intArg(
      args,
      'max_download_bytes',
      fallback: current['maxDownloadBytes'] as int,
      min: 1024 * 1024,
      max: 256 * 1024 * 1024,
    );
    final dailyBudgetMicros = _intArg(
      args,
      'daily_budget_micros',
      fallback: current['dailyBudgetMicros'] as int,
      min: 0,
      max: 100000000000000,
    );
    final currencyRaw = (args['budget_currency'] ?? current['budgetCurrency'] ?? 'USD')
        .toString().trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currencyRaw)) {
      throw const VideoProviderServiceException('provider_budget_currency_invalid');
    }
    final now = DateTime.now().toUtc();
    await registry.upsert(ExtensionRecord(
      id: context.workspace.id,
      kind: 'video_provider_limits',
      name: 'Video provider limits',
      source: const ExtensionSource(type: 'local'),
      status: ExtensionLifecycleStatus.enabled,
      updatedAt: now,
      installedAt: now,
      metadata: {
        'workspaceId': context.workspace.id,
        'maxRequestsPerDay': maxDailyRequests,
        'maxConcurrentJobs': maxConcurrentJobs,
        'maxDownloadBytes': maxDownloadBytes,
        'dailyBudgetMicros': dailyBudgetMicros,
        'budgetCurrency': currencyRaw,
      },
    ));
    return {'ok': true, 'action': 'set_limits', 'limits': await _readLimits(context)};
  }

  Future<Map<String, Object?>> _readLimits(WorkspaceToolContext context) async {
    final record = await registry.get('video_provider_limits', context.workspace.id);
    final metadata = record?.metadata ?? const <String, Object?>{};
    return {
      'maxRequestsPerDay': metadata['maxRequestsPerDay'] ?? 20,
      'maxConcurrentJobs': metadata['maxConcurrentJobs'] ?? 2,
      'maxDownloadBytes': metadata['maxDownloadBytes'] ?? 128 * 1024 * 1024,
      'dailyBudgetMicros': metadata['dailyBudgetMicros'] ?? 0,
      'budgetCurrency': metadata['budgetCurrency'] ?? 'USD',
      'costBudgetEnforcement': (metadata['dailyBudgetMicros'] is int &&
              (metadata['dailyBudgetMicros'] as int) > 0)
          ? 'requires_provider_quote_endpoint'
          : 'disabled',
    };
  }

  Future<Map<String, Object?>> _submit(
    Map<String, dynamic> args,
    WorkspaceToolContext context,
  ) async {
    final providerId = _string(args, 'provider_id');
    final provider = await _loadProvider(await _providerRecord(providerId, context), context);
    final manifest = provider.manifest;
    _verifyExpectedProviderPin(
      provider,
      expectedVersion: args['expected_provider_version'],
      expectedDigest: args['expected_provider_digest'],
    );
    final promptRaw = args['prompt'] ?? '';
    final imageUrlValue = args['image_url'] ?? '';
    if (promptRaw is! String || imageUrlValue is! String) {
      throw const VideoProviderServiceException('provider_prompt_or_image_invalid');
    }
    final prompt = promptRaw.trim();
    final imageUrlRaw = imageUrlValue.trim();
    final imageUrl = imageUrlRaw.isEmpty ? null : _validateUserImageUrl(imageUrlRaw);
    if (imageUrl != null) await _ensurePublicDnsHost(imageUrl.host);
    if (prompt.isEmpty && imageUrl == null) {
      throw const VideoProviderServiceException('provider_prompt_or_image_required');
    }
    if (prompt.length > manifest.maxPromptCharacters) {
      throw const VideoProviderServiceException('provider_prompt_too_long');
    }
    if (imageUrl != null && !manifest.supportsImageToVideo) {
      throw const VideoProviderServiceException('provider_image_to_video_not_supported');
    }
    if (imageUrl == null && !manifest.supportsTextToVideo) {
      throw const VideoProviderServiceException('provider_text_to_video_not_supported');
    }
    final projectDir = _string(args, 'project_dir');
    final sceneId = _string(args, 'scene_id');
    await videoProduction.validateProviderTarget(
      context: context,
      projectDir: projectDir,
      sceneId: sceneId,
    );
    final modelValue = args['model'] ?? manifest.defaultModel ?? '';
    if (modelValue is! String) {
      throw const VideoProviderServiceException('provider_model_invalid');
    }
    final modelRaw = modelValue.trim();
    if (modelRaw.length > 120 || _hasControl(modelRaw)) {
      throw const VideoProviderServiceException('provider_model_invalid');
    }
    if (modelRaw.isNotEmpty && manifest.models.isNotEmpty && !manifest.models.contains(modelRaw)) {
      throw const VideoProviderServiceException('provider_model_not_allowed');
    }
    final durationRaw = args['duration_seconds'];
    double? duration;
    if (durationRaw != null) {
      if (durationRaw is! num || !durationRaw.toDouble().isFinite ||
          durationRaw <= 0 || durationRaw > manifest.maxDurationSeconds) {
        throw const VideoProviderServiceException('provider_duration_invalid');
      }
      duration = durationRaw.toDouble();
    }
    final aspectRatioRaw = args['aspect_ratio'];
    final aspectRatio = aspectRatioRaw == null ? null : aspectRatioRaw.toString().trim();
    if (aspectRatio != null) {
      final match = RegExp(r'^([0-9]{1,2}):([0-9]{1,2})$').firstMatch(aspectRatio);
      final width = match == null ? null : int.tryParse(match.group(1)!);
      final height = match == null ? null : int.tryParse(match.group(2)!);
      if (aspectRatio.length > 32 || width == null || height == null ||
          width < 1 || width > 100 || height < 1 || height > 100) {
        throw const VideoProviderServiceException('provider_aspect_ratio_invalid');
      }
    }
    final requestBody = _buildRequestBody(
      manifest,
      prompt: prompt,
      imageUrl: imageUrl,
      model: modelRaw.isEmpty ? null : modelRaw,
      durationSeconds: duration,
      aspectRatio: aspectRatio,
    );
    final limits = await _readLimits(context);
    final jobs = await _jobs(context);
    final now = DateTime.now().toUtc();
    final today = _dayKey(now);
    final todaysJobs = jobs.where((job) => _dayKey(_date(job.metadata['createdAt'])) == today).toList();
    final maxRequests = limits['maxRequestsPerDay'] as int;
    if (todaysJobs.length >= maxRequests) {
      throw const VideoProviderServiceException('provider_daily_request_limit_reached');
    }
    final activeCount = jobs.where((job) => const {
      'queued', 'running', 'unknown',
    }.contains(job.metadata['status'])).length;
    if (activeCount >= (limits['maxConcurrentJobs'] as int)) {
      throw const VideoProviderServiceException('provider_concurrent_job_limit_reached');
    }

    final apiKey = await credentials.read(
      workspaceId: context.workspace.id,
      providerId: providerId,
    );
    if (manifest.apiKeyRequired && (apiKey == null || apiKey.isEmpty)) {
      throw const VideoProviderServiceException('provider_api_key_not_configured');
    }
    int? quotedCostMicros;
    String? quoteCurrency;
    final dailyBudget = limits['dailyBudgetMicros'] as int;
    if (dailyBudget > 0) {
      final quote = manifest.quote;
      if (quote == null) {
        throw const VideoProviderServiceException('provider_cost_limit_requires_quote_support');
      }
      quoteCurrency = quote.currency;
      if (quoteCurrency != limits['budgetCurrency']) {
        throw const VideoProviderServiceException('provider_budget_currency_mismatch');
      }
      final quoteResponse = await _requestJson(
        manifest: manifest,
        path: quote.path,
        method: 'POST',
        body: requestBody,
        apiKey: apiKey,
      );
      final amount = _readJsonPath(quoteResponse, quote.costPath);
      if (amount is! num || !amount.toDouble().isFinite ||
          amount < 0 || amount > 100000000) {
        throw const VideoProviderServiceException('provider_quote_response_invalid');
      }
      if (todaysJobs.any((job) => job.metadata['quotedCostMicros'] == null)) {
        throw const VideoProviderServiceException('provider_daily_cost_unknown_prior_job');
      }
      quotedCostMicros = (amount.toDouble() * 1000000).round();
      if (todaysJobs.any((job) =>
          job.metadata['quotedCostMicros'] is num &&
          job.metadata['quoteCurrency'] != quoteCurrency)) {
        throw const VideoProviderServiceException('provider_daily_cost_currency_mixed');
      }
      final spentOrReserved = todaysJobs.fold<int>(0, (sum, job) {
        final value = job.metadata['quotedCostMicros'];
        return sum + (value is num ? value.toInt() : 0);
      });
      if (spentOrReserved + quotedCostMicros > dailyBudget) {
        throw const VideoProviderServiceException('provider_daily_cost_limit_reached');
      }
    }

    final response = await _requestJson(
      manifest: manifest,
      path: manifest.submit.path,
      method: 'POST',
      body: requestBody,
      apiKey: apiKey,
    );
    final remoteJobId = _readJsonPath(response, manifest.submit.jobIdPath);
    if (remoteJobId is! String || remoteJobId.trim().isEmpty ||
        remoteJobId.length > 512 || _hasControl(remoteJobId)) {
      throw const VideoProviderServiceException('provider_submit_response_invalid');
    }
    final localJobId = const Uuid().v4();
    final record = ExtensionRecord(
      id: localJobId,
      kind: 'video_job',
      name: '${manifest.name} video job',
      source: const ExtensionSource(type: 'provider_job'),
      status: ExtensionLifecycleStatus.installed,
      version: manifest.version,
      installedAt: now,
      updatedAt: now,
      metadata: {
        'workspaceId': context.workspace.id,
        'providerId': providerId,
        'remoteJobId': remoteJobId,
        'projectDir': projectDir,
        'sceneId': sceneId,
        'status': 'queued',
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        if (modelRaw.isNotEmpty) 'model': modelRaw,
        if (quotedCostMicros != null) 'quotedCostMicros': quotedCostMicros,
        if (quoteCurrency != null) 'quoteCurrency': quoteCurrency,
      },
    );
    await registry.upsert(record);
    return {
      'ok': true,
      'action': 'submit',
      'jobId': localJobId,
      'providerId': providerId,
      'status': 'queued',
      'projectDirectory': projectDir,
      'sceneId': sceneId,
      'asynchronous': true,
      'quotedCostMicros': quotedCostMicros,
      'quoteCurrency': quoteCurrency,
      'apiKeyStoredOrReturned': false,
    };
  }

  Future<Map<String, Object?>> _poll(
    String localJobId,
    WorkspaceToolContext context, {
    Object? expectedVersion,
    Object? expectedDigest,
    ValueChanged<double>? onProgress,
  }) async {
    final record = await _jobRecord(localJobId, context);
    final downloadedPath = record.metadata['downloadedPath'];
    if (downloadedPath is String && downloadedPath.isNotEmpty) {
      return _jobSummary(
        record,
        action: 'poll',
        downloadedPath: downloadedPath,
      );
    }
    final providerId = (record.metadata['providerId'] ?? '').toString();
    final provider = await _loadProvider(await _providerRecord(providerId, context), context);
    _verifyExpectedProviderPin(
      provider,
      expectedVersion: expectedVersion,
      expectedDigest: expectedDigest,
    );
    final key = await credentials.read(workspaceId: context.workspace.id, providerId: providerId);
    if (provider.manifest.apiKeyRequired && (key == null || key.isEmpty)) {
      throw const VideoProviderServiceException('provider_api_key_not_configured');
    }
    final snapshot = await _fetchJobSnapshot(
      provider.manifest,
      (record.metadata['remoteJobId'] ?? '').toString(),
      key,
    );
    final updated = await _saveSnapshot(record, snapshot);
    if (snapshot.progress != null) onProgress?.call(snapshot.progress!);
    return _jobSummary(updated, action: 'poll', outputAvailable: snapshot.outputUrl != null);
  }

  Future<Map<String, Object?>> _download(
    String localJobId,
    WorkspaceToolContext context, {
    Object? expectedVersion,
    Object? expectedDigest,
    ValueChanged<double>? onProgress,
  }) async {
    final record = await _jobRecord(localJobId, context);
    final alreadyDownloaded = record.metadata['downloadedPath'];
    if (alreadyDownloaded is String && alreadyDownloaded.isNotEmpty) {
      return _jobSummary(
        record,
        action: 'download',
        downloadedPath: alreadyDownloaded,
      );
    }
    final providerId = (record.metadata['providerId'] ?? '').toString();
    final provider = await _loadProvider(await _providerRecord(providerId, context), context);
    _verifyExpectedProviderPin(
      provider,
      expectedVersion: expectedVersion,
      expectedDigest: expectedDigest,
    );
    final manifest = provider.manifest;
    final key = await credentials.read(workspaceId: context.workspace.id, providerId: providerId);
    if (manifest.apiKeyRequired && (key == null || key.isEmpty)) {
      throw const VideoProviderServiceException('provider_api_key_not_configured');
    }
    final snapshot = await _fetchJobSnapshot(
      manifest,
      (record.metadata['remoteJobId'] ?? '').toString(),
      key,
    );
    final updated = await _saveSnapshot(record, snapshot);
    if (snapshot.status != 'succeeded' || snapshot.outputUrl == null) {
      throw const VideoProviderServiceException('provider_job_output_not_ready');
    }
    final limits = await _readLimits(context);
    final maxBytes = (limits['maxDownloadBytes'] as int) < manifest.maxDownloadBytes
        ? limits['maxDownloadBytes'] as int
        : manifest.maxDownloadBytes;
    await _ensurePublicDnsHost(snapshot.outputUrl!.host);
    final request = http.Request('GET', snapshot.outputUrl!)..followRedirects = false;
    final http.StreamedResponse response;
    try {
      response = await _httpClient.send(request).timeout(const Duration(seconds: 90));
    } on Object {
      throw const VideoProviderServiceException('provider_download_network_error');
    }
    if (response.statusCode != 200) {
      await response.stream.listen((_) {}).cancel();
      throw VideoProviderServiceException('provider_download_http_${response.statusCode}');
    }
    final contentType = (response.headers['content-type'] ?? 'application/octet-stream')
        .split(';').first.trim().toLowerCase();
    if (!const {'video/mp4', 'application/octet-stream'}.contains(contentType)) {
      await response.stream.listen((_) {}).cancel();
      throw const VideoProviderServiceException('provider_download_content_type_invalid');
    }
    final declaredLength = int.tryParse(response.headers['content-length'] ?? '');
    if (declaredLength != null && declaredLength > maxBytes) {
      await response.stream.listen((_) {}).cancel();
      throw const VideoProviderServiceException('provider_download_too_large');
    }
    var downloadedBytes = 0;
    Stream<List<int>> trackedBytes() async* {
      await for (final chunk in response.stream.timeout(const Duration(seconds: 90))) {
        downloadedBytes += chunk.length;
        if (declaredLength != null && declaredLength > 0) {
          onProgress?.call(
            (downloadedBytes / declaredLength * 100).clamp(0, 100).toDouble(),
          );
        }
        yield chunk;
      }
    }
    final importResult = await videoProduction.importProviderClip(
      context: context,
      projectDir: (record.metadata['projectDir'] ?? '').toString(),
      sceneId: (record.metadata['sceneId'] ?? '').toString(),
      providerId: providerId,
      jobId: localJobId,
      bytes: trackedBytes(),
      maxBytes: maxBytes,
      contentType: contentType,
    );
    final metadata = {
      ...updated.metadata,
      'status': 'downloaded',
      'downloadedPath': importResult['assetPath'],
      'downloadedBytes': importResult['bytes'],
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
    final next = updated.copyWith(metadata: metadata, updatedAt: DateTime.now().toUtc());
    await registry.upsert(next);
    return _jobSummary(next, action: 'download', downloadedPath: importResult['assetPath'] as String?);
  }

  Future<_ProviderJobSnapshot> _fetchJobSnapshot(
    VideoProviderManifest manifest,
    String remoteJobId,
    String? apiKey,
  ) async {
    if (remoteJobId.isEmpty || remoteJobId.length > 512 || _hasControl(remoteJobId)) {
      throw const VideoProviderServiceException('provider_remote_job_id_invalid');
    }
    final path = manifest.poll.path.replaceFirst('{job_id}', Uri.encodeComponent(remoteJobId));
    final response = await _requestJson(
      manifest: manifest,
      path: path,
      method: 'GET',
      apiKey: apiKey,
    );
    final rawStatus = _readJsonPath(response, manifest.poll.statusPath);
    if (rawStatus is! String || rawStatus.isEmpty || rawStatus.length > 80 || _hasControl(rawStatus)) {
      throw const VideoProviderServiceException('provider_poll_status_invalid');
    }
    final status = rawStatus.toLowerCase();
    String normalized;
    if (manifest.poll.queuedStatuses.contains(status)) {
      normalized = 'queued';
    } else if (manifest.poll.runningStatuses.contains(status)) {
      normalized = 'running';
    } else if (manifest.poll.succeededStatuses.contains(status)) {
      normalized = 'succeeded';
    } else if (manifest.poll.failedStatuses.contains(status)) {
      normalized = 'failed';
    } else {
      normalized = 'unknown';
    }
    final outputRaw = _readJsonPath(response, manifest.poll.outputUrlPath);
    Uri? outputUrl;
    if (outputRaw is String && outputRaw.trim().isNotEmpty) {
      outputUrl = _validateOutputUrl(outputRaw.trim(), manifest);
    }
    double? progress;
    if (manifest.poll.progressPath != null) {
      final raw = _readJsonPath(response, manifest.poll.progressPath!);
      if (raw is num && raw.toDouble().isFinite) {
        progress = raw.toDouble().clamp(0, 100).toDouble();
      }
    }
    int? actualCostMicros;
    String? currency;
    if (manifest.poll.costPath != null) {
      final rawCost = _readJsonPath(response, manifest.poll.costPath!);
      if (rawCost is num && rawCost.toDouble().isFinite &&
          rawCost >= 0 && rawCost <= 100000000) {
        actualCostMicros = (rawCost.toDouble() * 1000000).round();
        currency = manifest.quote?.currency;
      }
    }
    return _ProviderJobSnapshot(
      status: normalized,
      outputUrl: outputUrl,
      progress: progress,
      actualCostMicros: actualCostMicros,
      currency: currency,
    );
  }

  Future<ExtensionRecord> _saveSnapshot(
    ExtensionRecord record,
    _ProviderJobSnapshot snapshot,
  ) async {
    final metadata = <String, Object?>{
      ...record.metadata,
      'status': snapshot.status,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      if (snapshot.progress != null) 'progress': snapshot.progress,
      if (snapshot.actualCostMicros != null) 'actualCostMicros': snapshot.actualCostMicros,
      if (snapshot.currency != null) 'actualCostCurrency': snapshot.currency,
      if (snapshot.status == 'failed') 'errorCode': 'provider_job_failed',
    };
    final next = record.copyWith(metadata: metadata, updatedAt: DateTime.now().toUtc());
    await registry.upsert(next);
    return next;
  }

  Map<String, Object?> _jobSummary(
    ExtensionRecord record, {
    required String action,
    bool? outputAvailable,
    String? downloadedPath,
  }) => {
    'ok': true,
    'action': action,
    'jobId': record.id,
    'providerId': record.metadata['providerId'],
    'status': record.metadata['status'],
    'progress': record.metadata['progress'],
    'outputAvailable': outputAvailable ?? false,
    if (downloadedPath != null) 'downloadedPath': downloadedPath,
    if (record.metadata['quotedCostMicros'] != null) ...{
      'quotedCostMicros': record.metadata['quotedCostMicros'],
      'quoteCurrency': record.metadata['quoteCurrency'],
    },
    if (record.metadata['actualCostMicros'] != null) ...{
      'actualCostMicros': record.metadata['actualCostMicros'],
      'actualCostCurrency': record.metadata['actualCostCurrency'],
    },
    'providerOutputUrlReturned': false,
    'apiKeyReturned': false,
  };

  Future<Map<String, Object?>> _requestJson({
    required VideoProviderManifest manifest,
    required String path,
    required String method,
    Map<String, Object?>? body,
    String? apiKey,
  }) async {
    await _ensurePublicDnsHost(manifest.baseUri.host);
    final uri = _endpointUri(manifest.baseUri, path);
    final request = http.Request(method, uri)
      ..followRedirects = false
      ..headers['Accept'] = 'application/json';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    if (apiKey != null && apiKey.isNotEmpty) {
      final headerValue = manifest.apiKeyPrefix.isEmpty
          ? apiKey
          : '${manifest.apiKeyPrefix} $apiKey';
      request.headers[manifest.apiKeyHeader] = headerValue;
    }
    final http.StreamedResponse response;
    try {
      response = await _httpClient.send(request).timeout(const Duration(seconds: 45));
    } on Object {
      throw const VideoProviderServiceException('provider_api_network_error');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.stream.listen((_) {}).cancel();
      throw VideoProviderServiceException('provider_http_${response.statusCode}');
    }
    final declaredLength = int.tryParse(response.headers['content-length'] ?? '');
    if (declaredLength != null && declaredLength > _maxProviderJsonBytes) {
      await response.stream.listen((_) {}).cancel();
      throw const VideoProviderServiceException('provider_response_too_large');
    }
    final bytes = await _readBounded(
      response.stream.timeout(const Duration(seconds: 60)),
      _maxProviderJsonBytes,
    );
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on Object {
      throw const VideoProviderServiceException('provider_response_json_invalid');
    }
    if (decoded is! Map || decoded.keys.any((key) => key is! String)) {
      throw const VideoProviderServiceException('provider_response_object_required');
    }
    return {for (final entry in decoded.entries) entry.key as String: entry.value};
  }

  Future<Uint8List> _readBounded(Stream<List<int>> stream, int maxBytes) async {
    final builder = BytesBuilder(copy: false);
    var count = 0;
    await for (final chunk in stream) {
      count += chunk.length;
      if (count > maxBytes) {
        throw const VideoProviderServiceException('provider_response_too_large');
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  Map<String, Object?> _buildRequestBody(
    VideoProviderManifest manifest, {
    required String prompt,
    required Uri? imageUrl,
    required String? model,
    required double? durationSeconds,
    required String? aspectRatio,
  }) {
    final fields = manifest.submit.fields;
    final result = <String, Object?>{};
    void add(String? path, Object? value) {
      if (path == null || value == null) return;
      final parts = path.split('.');
      Map<String, Object?> current = result;
      for (final part in parts.take(parts.length - 1)) {
        final next = current.putIfAbsent(part, () => <String, Object?>{});
        if (next is! Map<String, Object?>) {
          throw const VideoProviderServiceException('provider_request_field_conflict');
        }
        current = next;
      }
      current[parts.last] = value;
    }
    add(fields.model, model);
    add(fields.prompt, prompt.isEmpty ? null : prompt);
    add(fields.imageUrl, imageUrl?.toString());
    add(fields.durationSeconds, durationSeconds);
    add(fields.aspectRatio, aspectRatio);
    return result;
  }

  Uri _endpointUri(Uri base, String path) {
    if (!path.startsWith('/') || path.contains('?') || path.contains('#') ||
        path.contains('\\') || path.contains('..')) {
      throw const VideoProviderServiceException('provider_endpoint_path_invalid');
    }
    final uri = base.resolve(path.substring(1));
    if (uri.scheme != 'https' || uri.host != base.host || uri.userInfo.isNotEmpty) {
      throw const VideoProviderServiceException('provider_endpoint_origin_invalid');
    }
    return uri;
  }

  Uri _validateOutputUrl(String raw, VideoProviderManifest manifest) {
    final uri = Uri.tryParse(raw);
    if (raw.length > 4096 || uri == null || uri.scheme != 'https' || uri.host.isEmpty ||
        uri.userInfo.isNotEmpty || uri.hasFragment || uri.port != 443 ||
        !manifest.allowsDownloadHost(uri.host)) {
      throw const VideoProviderServiceException('provider_output_url_not_allowed');
    }
    return uri;
  }

  Uri _validateUserImageUrl(String raw) {
    final uri = Uri.tryParse(raw);
    if (raw.length > 4096 || uri == null || uri.scheme != 'https' || uri.host.isEmpty ||
        uri.userInfo.isNotEmpty || uri.hasFragment || uri.port != 443 ||
        !_isPublicDnsHost(uri.host)) {
      throw const VideoProviderServiceException('provider_image_url_invalid');
    }
    return uri;
  }

  void _verifyExpectedProviderPin(
    _InstalledVideoProvider provider, {
    required Object? expectedVersion,
    required Object? expectedDigest,
  }) {
    if (expectedVersion == null && expectedDigest == null) return;
    if (expectedVersion is! String || expectedDigest is! String ||
        expectedVersion != provider.manifest.version ||
        expectedDigest.toLowerCase() != provider.record.digest?.toLowerCase()) {
      throw const VideoProviderServiceException('provider_dependency_pin_mismatch');
    }
  }

  Future<_InstalledVideoProvider> _loadProvider(
    ExtensionRecord record,
    WorkspaceToolContext context,
  ) async {
    if (record.kind != 'video_provider' ||
        record.metadata['workspaceId'] != context.workspace.id) {
      throw const VideoProviderServiceException('provider_workspace_mismatch');
    }
    final relative = record.metadata['manifestPath'];
    if (relative is! String || relative.isEmpty || relative.startsWith('/') ||
        relative.contains('..') || relative.contains('\\')) {
      throw const VideoProviderServiceException('provider_manifest_path_invalid');
    }
    final path = p.join(context.paths.workspaceHostRoot, relative);
    await _assertNoSymlinkPath(context, path);
    if (await FileSystemEntity.type(path, followLinks: false) != FileSystemEntityType.file) {
      throw const VideoProviderServiceException('provider_manifest_missing');
    }
    final contents = await File(path).readAsString();
    final digest = 'sha256:${sha256.convert(utf8.encode(contents))}';
    if (record.digest != digest) {
      throw const VideoProviderServiceException('provider_manifest_digest_mismatch');
    }
    final manifest = VideoProviderManifest.parse(contents);
    if (manifest.id != record.metadata['providerId'] || manifest.version != record.version) {
      throw const VideoProviderServiceException('provider_manifest_registry_mismatch');
    }
    return _InstalledVideoProvider(record: record, manifest: manifest, manifestPath: path);
  }

  Future<ExtensionRecord> _providerRecord(
    String providerId,
    WorkspaceToolContext context,
  ) async {
    if (!RegExp(r'^[a-z0-9][a-z0-9._-]{0,63}$').hasMatch(providerId)) {
      throw const VideoProviderServiceException('provider_id_invalid');
    }
    final record = await registry.get(
      'video_provider',
      _scopedProviderRecordId(context.workspace.id, providerId),
    );
    if (record == null ||
        record.metadata['workspaceId'] != context.workspace.id ||
        record.metadata['providerId'] != providerId) {
      throw const VideoProviderServiceException('provider_not_installed');
    }
    return record;
  }

  String _scopedProviderRecordId(String workspaceId, String providerId) {
    final digest = sha256.convert(utf8.encode(jsonEncode([workspaceId, providerId])));
    return 'vp-${digest.toString().substring(0, 48)}';
  }

  Future<ExtensionRecord> _jobRecord(
    String jobId,
    WorkspaceToolContext context,
  ) async {
    if (!RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]{0,127}$').hasMatch(jobId)) {
      throw const VideoProviderServiceException('provider_job_id_invalid');
    }
    final record = await registry.get('video_job', jobId);
    if (record == null || record.metadata['workspaceId'] != context.workspace.id) {
      throw const VideoProviderServiceException('provider_job_not_found');
    }
    return record;
  }

  Future<List<ExtensionRecord>> _jobs(WorkspaceToolContext context) async {
    final records = await registry.list(kind: 'video_job');
    return records
        .where((record) => record.metadata['workspaceId'] == context.workspace.id)
        .toList(growable: false);
  }

  Future<bool> _hasActiveJobs(String providerId, WorkspaceToolContext context) async {
    final records = await _jobs(context);
    return records.any((record) {
      if (record.metadata['providerId'] != providerId) return false;
      final status = record.metadata['status'];
      if (const {'queued', 'running', 'unknown'}.contains(status)) return true;
      // A completed remote job still depends on its provider until its MP4 is
      // imported locally. Do not remove/update the connector in that window.
      return status == 'succeeded' &&
          (record.metadata['downloadedPath'] is! String ||
              (record.metadata['downloadedPath'] as String).isEmpty);
    });
  }

  Future<_ManifestSource> _readManifestSource(
    Map<String, dynamic> args,
    WorkspaceToolContext context,
  ) async {
    final inline = args['manifest'];
    if (inline is String && inline.trim().isNotEmpty) {
      if (utf8.encode(inline).length > _maxProviderManifestBytes) {
        throw const VideoProviderServiceException('provider_manifest_too_large');
      }
      return _ManifestSource(
        contents: inline,
        source: const ExtensionSource(type: 'inline'),
      );
    }
    final source = _string(args, 'source');
    final uri = Uri.tryParse(source);
    if (uri != null && uri.hasScheme) {
      if (uri.scheme != 'https' || uri.host != 'raw.githubusercontent.com' ||
          uri.port != 443 || uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment ||
          uri.pathSegments.length < 4 ||
          uri.pathSegments.last != kVideoProviderManifestFile ||
          uri.pathSegments.any((part) => part == '.' || part == '..')) {
        throw const VideoProviderServiceException('provider_remote_manifest_url_not_allowed');
      }
      await _ensurePublicDnsHost(uri.host);
      final request = http.Request('GET', uri)..followRedirects = false;
      final response = await _httpClient.send(request).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        await response.stream.listen((_) {}).cancel();
        throw VideoProviderServiceException('provider_manifest_http_${response.statusCode}');
      }
      final bytes = await _readBounded(
        response.stream.timeout(const Duration(seconds: 30)),
        _maxProviderManifestBytes,
      );
      return _ManifestSource(
        contents: utf8.decode(bytes),
        source: ExtensionSource(type: 'github', uri: uri.toString()),
      );
    }
    final resolved = context.paths.resolve(source, cwd: context.cwd);
    if (resolved.zone != WorkspaceZone.workspace ||
        context.paths.isReadOnlyPath(resolved.hostPath) ||
        p.basename(resolved.hostPath) != kVideoProviderManifestFile) {
      throw const VideoProviderServiceException('provider_manifest_source_not_allowed');
    }
    await _assertNoSymlinkPath(context, resolved.hostPath);
    if (await FileSystemEntity.type(resolved.hostPath, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const VideoProviderServiceException('provider_manifest_source_not_allowed');
    }
    final file = File(resolved.hostPath);
    if (await file.length() > _maxProviderManifestBytes) {
      throw const VideoProviderServiceException('provider_manifest_too_large');
    }
    return _ManifestSource(
      contents: await file.readAsString(),
      source: ExtensionSource(type: 'workspace', uri: resolved.modelPath),
    );
  }

  Future<void> _assertNoSymlinkPath(WorkspaceToolContext context, String targetPath) async {
    final root = p.normalize(context.paths.workspaceHostRoot);
    final target = p.normalize(targetPath);
    if (!_inside(root, target)) {
      throw const VideoProviderServiceException('provider_path_outside_workspace');
    }
    var current = root;
    if (await FileSystemEntity.type(current, followLinks: false) == FileSystemEntityType.link) {
      throw const VideoProviderServiceException('provider_workspace_root_symlink');
    }
    for (final segment in p.split(p.relative(target, from: root))) {
      if (segment.isEmpty || segment == '.') continue;
      current = p.join(current, segment);
      if (await FileSystemEntity.type(current, followLinks: false) == FileSystemEntityType.link) {
        throw const VideoProviderServiceException('provider_symlink_path_rejected');
      }
    }
  }

  bool _inside(String root, String candidate) {
    final relative = p.relative(candidate, from: root);
    return relative != '..' && !relative.startsWith('..${p.separator}') && !p.isAbsolute(relative);
  }

  Object? _readJsonPath(Map<String, Object?> root, String path) {
    Object? current = root;
    for (final part in path.split('.')) {
      if (current is Map) {
        current = current[part];
      } else if (current is List) {
        final index = int.tryParse(part);
        if (index == null || index < 0 || index >= current.length) return null;
        current = current[index];
      } else {
        return null;
      }
    }
    return current;
  }

  String _string(Map<String, dynamic> args, String key) {
    final value = args[key];
    if (value is! String || value.trim().isEmpty || value.length > 2048 || _hasControl(value)) {
      throw VideoProviderServiceException('provider_argument_invalid:$key');
    }
    return value.trim();
  }

  int _intArg(
    Map<String, dynamic> args,
    String key, {
    required int fallback,
    required int min,
    required int max,
  }) {
    final value = args[key];
    if (value == null) return fallback;
    if (value is! int || value < min || value > max) {
      throw VideoProviderServiceException('provider_limit_invalid:$key');
    }
    return value;
  }

  DateTime _date(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true) :
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  String _dayKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  bool _isPublicDnsHost(String host) {
    final value = host.toLowerCase();
    return value.length <= 253 && value != 'localhost' &&
        !value.endsWith('.localhost') && !value.endsWith('.local') &&
        !RegExp(r'^\d+(?:\.\d+){3}$').hasMatch(value) &&
        RegExp(r'^(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$')
            .hasMatch(value);
  }

  Future<void> _ensurePublicDnsHost(String host) async {
    final List<InternetAddress> addresses;
    try {
      addresses = await InternetAddress.lookup(host).timeout(
        const Duration(seconds: 10),
      );
    } on Object {
      throw const VideoProviderServiceException('provider_host_dns_failed');
    }
    if (addresses.isEmpty || addresses.any((address) => !_isPublicAddress(address))) {
      throw const VideoProviderServiceException('provider_host_not_public');
    }
  }

  bool _isPublicAddress(InternetAddress address) {
    final bytes = address.rawAddress;
    if (address.type == InternetAddressType.IPv4 && bytes.length == 4) {
      final a = bytes[0];
      final b = bytes[1];
      final c = bytes[2];
      if (a == 0 || a == 10 || a == 127 || a >= 224 ||
          a == 100 && b >= 64 && b <= 127 ||
          a == 169 && b == 254 ||
          a == 172 && b >= 16 && b <= 31 ||
          a == 192 && b == 0 && (c == 0 || c == 2) ||
          a == 192 && b == 168 ||
          a == 192 && b == 88 && c == 99 ||
          a == 198 && (b == 18 || b == 19 || b == 51 && c == 100) ||
          a == 203 && b == 0 && c == 113) {
        return false;
      }
      return true;
    }
    if (address.type == InternetAddressType.IPv6 && bytes.length == 16) {
      final first = bytes[0];
      final second = bytes[1];
      final third = bytes[2];
      final fourth = bytes[3];
      // Only global-unicast 2000::/3 addresses are accepted. This excludes
      // loopback, unspecified, link-local, unique-local, multicast and v4-map.
      if ((first & 0xe0) != 0x20) return false;
      if (first == 0x20 && second == 0x01 &&
          (third == 0x0d && fourth == 0xb8 || third == 0x00 && fourth == 0x00)) {
        return false;
      }
      if (first == 0x20 && second == 0x02) return false; // 6to4.
      return true;
    }
    return false;
  }

  bool _hasControl(String value) =>
      value.codeUnits.any((unit) => unit < 0x20 || unit == 0x7f);

  void _requireWorkspace(WorkspaceToolContext context) {
    if (context.skillsOnly || context.workspace.id.isEmpty ||
        context.paths.workspaceHostRoot.isEmpty) {
      throw const VideoProviderServiceException('workspace_required');
    }
  }

  void dispose() {
    if (_ownsHttpClient) _httpClient.close();
  }
}

final class _ManifestSource {
  const _ManifestSource({required this.contents, required this.source});

  final String contents;
  final ExtensionSource source;
}
