import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../api/tool_call_cancellation.dart';
import '../runtime_profiles/runtime_profile_models.dart';
import '../runtime_profiles/runtime_profile_service.dart';
import '../video_hybrid/video_hybrid_workflow_service.dart';
import '../workspace/workspace_runtime.dart';
import '../workspace/workspace_tool_context.dart';
import '../workspace/workspace_paths.dart';

const int _maxVideoBytes = 5 * 1024 * 1024 * 1024;
const int _maxProbeOutputBytes = 4 * 1024 * 1024;
const int _maxSubtitleBytes = 10 * 1024 * 1024;
const int _maxSamples = 12;
const int _maxRecoveryAttemptsPerScene = 2;

class VideoQualityServiceException implements Exception {
  const VideoQualityServiceException(this.code);

  final String code;

  @override
  String toString() => code;
}

class VideoSubtitleFinding {
  const VideoSubtitleFinding({
    required this.code,
    required this.severity,
    this.cue,
  });

  final String code;
  final String severity;
  final int? cue;

  Map<String, Object?> toJson() => {
    'code': code,
    'severity': severity,
    if (cue != null) 'cue': cue,
  };
}

class VideoSubtitleReport {
  const VideoSubtitleReport({
    required this.cueCount,
    required this.findings,
  });

  final int cueCount;
  final List<VideoSubtitleFinding> findings;

  bool get valid => findings.every((finding) => finding.severity != 'error');

  Map<String, Object?> toJson() => {
    'cueCount': cueCount,
    'valid': valid,
    'findings': findings.map((finding) => finding.toJson()).toList(),
  };
}

/// Media QA for optional Android PRoot tools. This service never installs
/// FFmpeg: it detects a missing binary and reports a scoped, user-approved fix.
final class VideoQualityService {
  VideoQualityService({
    required this.runtimeProvider,
    required this.runtimeProfiles,
    this.hybridWorkflow,
  });

  final WorkspaceRuntimeProvider runtimeProvider;
  final RuntimeProfileService runtimeProfiles;
  final VideoHybridWorkflowService? hybridWorkflow;

  Future<Map<String, Object?>> handle({
    required Map<String, dynamic> args,
    required WorkspaceToolContext context,
  }) async {
    _requireWorkspace(context);
    final action = (args['action'] ?? 'inspect').toString();
    switch (action) {
      case 'inspect':
        final report = await _inspectAndPersist(args, context);
        return report;
      case 'deep_scan':
        final inspected = await _inspectAndPersist(args, context);
        if (inspected['ok'] != true) return inspected;
        return _deepScan(args, context, inspected);
      case 'samples':
        return _createSamples(args, context);
      case 'compare':
        return _compareWithPrevious(args, context);
      case 'diagnose':
        return _diagnose(args, context);
      case 'retry_scene':
        return _retryFailedScene(args, context);
      default:
        throw const VideoQualityServiceException('video_quality_action_unsupported');
    }
  }

  Future<Map<String, Object?>> _inspectAndPersist(
    Map<String, dynamic> args,
    WorkspaceToolContext context,
  ) async {
    final audioPolicy = (args['audio_policy'] ?? 'preserve').toString();
    if (!const {'preserve', 'prefer_generated', 'mute'}.contains(audioPolicy)) {
      throw const VideoQualityServiceException('quality_audio_policy_invalid');
    }
    if (audioPolicy == 'mute' && args['require_audio'] == true) {
      throw const VideoQualityServiceException('quality_audio_policy_conflict');
    }
    final input = await _resolveVideo(args, context);
    final missing = await _missingCommands(context, ['ffprobe'], _profileId(args, context));
    if (missing.isNotEmpty) {
      final report = <String, Object?>{
        'ok': false,
        'status': 'blocked',
        'videoPath': input.modelPath,
        'error': 'quality_binary_missing',
        'missingCommands': missing,
        'repair': {
          'tool': 'package_manager',
          'action': 'install',
          'packages': ['ffmpeg'],
          'runtimeProfileId': _profileId(args, context),
          'note': 'Install only after confirming the intended Android PRoot distribution and project Runtime Profile. FFmpeg is not bundled in the APK.',
        },
      };
      await _saveReport(context, input.projectDirectory, report);
      return report;
    }

    final result = await _run(
      context: context,
      command: 'ffprobe -v error -show_entries ${_quote('format=duration,format_name,size,bit_rate:stream=index,codec_type,codec_name,width,height,r_frame_rate,avg_frame_rate,duration,start_time,sample_rate,channels,channel_layout,nb_frames')} -of json -i ${_quote(input.modelPath)}',
      cwd: input.projectDirectoryModel,
      timeout: const Duration(seconds: 90),
      runtimeProfileId: _profileId(args, context),
    );
    if (!result.succeeded) {
      final report = <String, Object?>{
        'ok': false,
        'status': 'failed',
        'videoPath': input.modelPath,
        'error': result.timedOut ? 'ffprobe_timeout' : 'ffprobe_failed',
        'exitCode': result.exitCode,
        'stderr': _redactOutput(result.stderr),
        'diagnosis': classifyFailure(
          exitCode: result.exitCode,
          stdout: result.stdout,
          stderr: result.stderr,
          timedOut: result.timedOut,
        ),
      };
      await _saveReport(context, input.projectDirectory, report);
      return report;
    }

    late final Map<String, Object?> parsed;
    try {
      parsed = parseProbeJson(result.stdout);
    } on Object {
      final report = <String, Object?>{
        'ok': false,
        'status': 'failed',
        'videoPath': input.modelPath,
        'error': 'ffprobe_output_invalid',
        'diagnosis': classifyFailure(exitCode: result.exitCode, stdout: result.stdout, stderr: result.stderr, timedOut: false),
      };
      await _saveReport(context, input.projectDirectory, report);
      return report;
    }
    final findings = evaluateProbe(
      parsed,
      expectedWidth: _optionalInt(args['expected_width']),
      expectedHeight: _optionalInt(args['expected_height']),
      expectedFps: _optionalDouble(args['expected_fps']),
      expectedDuration: _optionalDouble(args['expected_duration_seconds']),
      audioPolicy: (args['audio_policy'] ?? 'preserve').toString(),
      requireAudio: args['require_audio'] == true,
      durationTolerance: _optionalDouble(args['duration_tolerance_seconds']) ?? 1.0,
    );

    final subtitlePaths = _stringList(args['subtitle_paths']);
    final subtitleReports = <Map<String, Object?>>[];
    for (final subtitlePath in subtitlePaths) {
      final subtitle = await _resolveWorkspaceFile(subtitlePath, context);
      if (await File(subtitle.hostPath).length() > _maxSubtitleBytes) {
        subtitleReports.add({
          'path': subtitle.modelPath,
          'valid': false,
          'findings': [{'code': 'subtitle_file_too_large', 'severity': 'error'}],
        });
        continue;
      }
      final text = await File(subtitle.hostPath).readAsString();
      final subtitleReport = validateSubtitle(text, durationSeconds: _formatDuration(parsed));
      subtitleReports.add({'path': subtitle.modelPath, ...subtitleReport.toJson()});
    }
    for (final item in subtitleReports) {
      final subtitleFindings = item['findings'];
      if (subtitleFindings is List) {
        for (final finding in subtitleFindings.whereType<Map>()) {
          findings.add({
            'code': 'subtitle_${finding['code']}',
            'severity': finding['severity'] ?? 'warning',
            'path': item['path'],
            if (finding['cue'] != null) 'cue': finding['cue'],
          });
        }
      }
    }

    final errorCount = findings.where((item) => item['severity'] == 'error').length;
    final warningCount = findings.where((item) => item['severity'] == 'warning').length;
    final report = <String, Object?>{
      'schemaVersion': 1,
      'ok': errorCount == 0,
      'status': errorCount > 0 ? 'failed' : warningCount > 0 ? 'warning' : 'passed',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'videoPath': input.modelPath,
      'videoBytes': await File(input.hostPath).length(),
      'format': parsed['format'],
      'streams': parsed['streams'],
      'summary': _qualitySummary(parsed),
      'findings': findings,
      'subtitleReports': subtitleReports,
      'counts': {'errors': errorCount, 'warnings': warningCount},
      'tools': {'ffprobe': 'available'},
    };
    await _saveReport(context, input.projectDirectory, report);
    return report;
  }

  Future<Map<String, Object?>> _deepScan(
    Map<String, dynamic> args,
    WorkspaceToolContext context,
    Map<String, Object?> baseReport,
  ) async {
    final input = await _resolveVideo(args, context);
    final missing = await _missingCommands(context, ['ffmpeg'], _profileId(args, context));
    if (missing.isNotEmpty) {
      return {
        ...baseReport,
        'deepScan': {'status': 'skipped', 'missingCommands': missing},
      };
    }
    final summary = baseReport['summary'];
    final hasAudio = summary is Map && summary['hasAudio'] == true;
    final filters = <String>[
      'blackdetect=d=1.0:pix_th=0.10:pic_th=0.98',
      if (hasAudio) 'silencedetect=n=-50dB:d=2.0',
    ];
    final filterArg = [
      '-vf ${_quote(filters.first)}',
      if (hasAudio) '-af ${_quote(filters[1])}',
    ].join(' ');
    final result = await _run(
      context: context,
      command: 'ffmpeg -hide_banner -nostats -i ${_quote(input.modelPath)} $filterArg -f null -',
      cwd: input.projectDirectoryModel,
      timeout: const Duration(minutes: 8),
      runtimeProfileId: _profileId(args, context),
    );
    if (!result.succeeded) {
      final diagnosis = classifyFailure(
        exitCode: result.exitCode,
        stdout: result.stdout,
        stderr: result.stderr,
        timedOut: result.timedOut,
      );
      return {
        ...baseReport,
        'deepScan': {
          'status': 'failed',
          'error': result.timedOut ? 'ffmpeg_timeout' : 'ffmpeg_scan_failed',
          'diagnosis': diagnosis,
          'stderr': _redactOutput(result.stderr),
        },
      };
    }
    final findings = <Map<String, Object?>>[];
    final blackIntervals = _parseIntervals(result.stderr, r'black_start:(\d+(?:\.\d+)?).*?black_end:(\d+(?:\.\d+)?)');
    final silenceIntervals = _parseIntervals(result.stderr, r'silence_start: (\d+(?:\.\d+)?).*?silence_end: (\d+(?:\.\d+)?)');
    for (final interval in blackIntervals) {
      findings.add({
        'code': 'black_interval_detected',
        'severity': interval.duration >= 1.0 ? 'warning' : 'info',
        'startSeconds': interval.start,
        'endSeconds': interval.end,
        'durationSeconds': interval.duration,
      });
    }
    final audioPolicy = (args['audio_policy'] ?? 'preserve').toString();
    if (audioPolicy != 'mute') {
      for (final interval in silenceIntervals) {
        findings.add({
          'code': 'long_audio_silence_detected',
          'severity': interval.duration >= 5 ? 'warning' : 'info',
          'startSeconds': interval.start,
          'endSeconds': interval.end,
          'durationSeconds': interval.duration,
        });
      }
    }
    final deepScan = {
      'status': 'completed',
      'blackIntervals': blackIntervals.length,
      'silenceIntervals': silenceIntervals.length,
      'findings': findings,
      'note': 'Black intervals and silence are signals for review, not automatic proof of defects; intentional fades and silent scenes may be valid.',
    };
    final updated = <String, Object?>{...baseReport, 'deepScan': deepScan};
    await _saveReport(context, input.projectDirectory, updated);
    return updated;
  }

  Future<Map<String, Object?>> _createSamples(
    Map<String, dynamic> args,
    WorkspaceToolContext context,
  ) async {
    final input = await _resolveVideo(args, context);
    final count = (_optionalInt(args['count']) ?? 6).clamp(1, _maxSamples);
    final probe = await _probeForSamples(input, context, args);
    final duration = _formatDuration(probe);
    if (duration == null || duration <= 0) {
      throw const VideoQualityServiceException('video_duration_unavailable_for_samples');
    }
    final missing = await _missingCommands(context, ['ffmpeg'], _profileId(args, context));
    if (missing.isNotEmpty) {
      return {
        'ok': false,
        'status': 'blocked',
        'error': 'quality_binary_missing',
        'missingCommands': missing,
      };
    }
    final sampleId = const Uuid().v4();
    final outputDirHost = p.join(input.projectDirectory, '.kelivo', 'quality', 'samples-$sampleId');
    await _assertNoSymlinkPath(context.paths.workspaceHostRoot, outputDirHost);
    await Directory(outputDirHost).create(recursive: true);
    await _assertNoSymlinkPath(context.paths.workspaceHostRoot, outputDirHost);
    final outputDirModel = context.paths.toModelPath(outputDirHost);
    final interval = math.max(0.05, duration / (count + 1));
    final columns = math.min(3, count);
    final rows = (count / columns).ceil();
    final outputPathModel = p.posix.join(outputDirModel, 'contact-sheet.jpg');
    final filter = 'fps=1/${interval.toStringAsFixed(3)},scale=480:270:force_original_aspect_ratio=decrease,pad=480:270:(ow-iw)/2:(oh-ih)/2,tile=${columns}x${rows}:nb_frames=$count';
    final result = await _run(
      context: context,
      command: 'ffmpeg -hide_banner -loglevel error -i ${_quote(input.modelPath)} -vf ${_quote(filter)} -frames:v 1 -y ${_quote(outputPathModel)}',
      cwd: input.projectDirectoryModel,
      timeout: const Duration(minutes: 3),
      runtimeProfileId: _profileId(args, context),
    );
    if (!result.succeeded) {
      return {
        'ok': false,
        'status': 'failed',
        'error': 'contact_sheet_generation_failed',
        'diagnosis': classifyFailure(exitCode: result.exitCode, stdout: result.stdout, stderr: result.stderr, timedOut: result.timedOut),
        'stderr': _redactOutput(result.stderr),
      };
    }
    final outputHost = p.join(outputDirHost, 'contact-sheet.jpg');
    final outputType = await FileSystemEntity.type(outputHost, followLinks: false);
    if (outputType != FileSystemEntityType.file || await File(outputHost).length() == 0) {
      throw const VideoQualityServiceException('contact_sheet_output_missing');
    }
    return {
      'ok': true,
      'status': 'completed',
      'sourceVideo': input.modelPath,
      'contactSheetPath': outputPathModel,
      'samplesRequested': count,
      'durationSeconds': duration,
      'note': 'Open the contact sheet with view_image for visual review. Sampling does not determine semantic correctness by itself.',
    };
  }

  Future<Map<String, Object?>> _compareWithPrevious(
    Map<String, dynamic> args,
    WorkspaceToolContext context,
  ) async {
    final current = await _inspectAndPersist(args, context);
    if (current['summary'] is! Map) return {...current, 'comparison': {'status': 'unavailable'}};
    final project = _optionalString(args['project_dir']) ?? context.cwd;
    final projectDirectory = await _resolveProjectDirectory(project, context);
    final reportFile = File(_reportPath(projectDirectory.hostPath));
    // _inspectAndPersist has already updated latest-report.json, so compare
    // against a separately retained previous-report.json snapshot.
    final previousFile = File(p.join(p.dirname(reportFile.path), 'previous-report.json'));
    await _assertNoSymlinkPath(context.paths.workspaceHostRoot, previousFile.path);
    if (!await previousFile.exists()) {
      await _atomicWriteJson(previousFile, current);
      return {...current, 'comparison': {'status': 'baseline_created'}};
    }
    Object? previous;
    try {
      previous = jsonDecode(await previousFile.readAsString());
    } on FormatException {
      previous = null;
    }
    if (previous is! Map || previous['summary'] is! Map) {
      await _atomicWriteJson(previousFile, current);
      return {...current, 'comparison': {'status': 'baseline_replaced_invalid'}};
    }
    final oldSummary = Map<String, dynamic>.from(previous['summary'] as Map);
    final newSummary = Map<String, dynamic>.from(current['summary'] as Map);
    final changed = <String, Object?>{};
    for (final key in {'durationSeconds', 'width', 'height', 'frameCount', 'fps', 'videoCodec', 'audioCodec', 'hasAudio'}) {
      if (oldSummary[key] != newSummary[key]) {
        changed[key] = {'before': oldSummary[key], 'after': newSummary[key]};
      }
    }
    await _atomicWriteJson(previousFile, current);
    return {
      ...current,
      'comparison': {
        'status': 'compared',
        'changedFields': changed,
        'hasChanges': changed.isNotEmpty,
      },
    };
  }

  Future<Map<String, Object?>> _diagnose(
    Map<String, dynamic> args,
    WorkspaceToolContext context,
  ) async {
    final path = _optionalString(args['video_path']);
    if (path != null) {
      final report = await _inspectAndPersist(args, context);
      if (report['ok'] == true) {
        final findings = (report['findings'] as List? ?? const []).whereType<Map>();
        return {
          ...report,
          'diagnosis': {
            'category': findings.any((item) => item['severity'] == 'error') ? 'media_profile_mismatch' : 'no_blocking_media_issue_detected',
            'recommendedNextAction': findings.isEmpty ? 'deep_scan' : 'review_findings',
          },
        };
      }
      return {
        ...report,
        'diagnosis': classifyFailure(
          exitCode: _optionalInt(report['exitCode']) ?? -1,
          stdout: '',
          stderr: (report['stderr'] ?? '').toString(),
          timedOut: report['error'] == 'ffprobe_timeout',
        ),
      };
    }
    final code = (_optionalString(args['error_code']) ?? 'unknown').toLowerCase();
    final diagnosis = classifyFailure(exitCode: -1, stdout: '', stderr: code, timedOut: false);
    return {
      'ok': true,
      'diagnosis': diagnosis,
      'recommendedAction': diagnosis['recommendedAction'],
      'automaticInstall': false,
      'note': 'KELIVO will not install an arbitrary dependency from an unverified source. Confirm the project Runtime Profile and package source, then use package_manager with explicit approval.',
    };
  }

  Future<Map<String, Object?>> _retryFailedScene(
    Map<String, dynamic> args,
    WorkspaceToolContext context,
  ) async {
    final hybrid = hybridWorkflow;
    if (hybrid == null) {
      throw const VideoQualityServiceException('hybrid_recovery_unavailable');
    }
    final projectDir = _optionalString(args['project_dir']);
    final sceneId = _optionalString(args['scene_id']);
    if (projectDir == null || sceneId == null) {
      throw const VideoQualityServiceException('recovery_project_and_scene_required');
    }
    final status = await hybrid.handle(
      args: {'action': 'status', 'project_dir': projectDir},
      context: context,
    );
    final rawStates = status['sceneStates'];
    final state = rawStates is Map ? rawStates[sceneId] : null;
    if (state is! Map || state['status'] != 'failed') {
      throw const VideoQualityServiceException('recovery_scene_must_be_failed');
    }

    final projectDirectory = await _resolveProjectDirectory(projectDir, context);
    final qualityDirectory = p.join(
      projectDirectory.hostPath,
      '.kelivo',
      'quality',
    );
    await _assertNoSymlinkPath(context.paths.workspaceHostRoot, qualityDirectory);
    await Directory(qualityDirectory).create(recursive: true);
    await _assertNoSymlinkPath(context.paths.workspaceHostRoot, qualityDirectory);
    final recoveryFile = File(_recoveryPath(projectDirectory.hostPath));
    await _assertNoSymlinkPath(context.paths.workspaceHostRoot, recoveryFile.path);
    final lockFile = File('${recoveryFile.path}.lock');
    try {
      await lockFile.create(exclusive: true);
    } on FileSystemException {
      throw const VideoQualityServiceException('recovery_already_in_progress');
    }

    try {
      Map<String, dynamic> ledger = {};
      if (await recoveryFile.exists()) {
        final decoded = jsonDecode(await recoveryFile.readAsString());
        if (decoded is! Map) {
          throw const VideoQualityServiceException('recovery_ledger_invalid');
        }
        ledger = Map<String, dynamic>.from(decoded);
      }
      final attempts = (ledger[sceneId] as num?)?.toInt() ?? 0;
      if (attempts >= _maxRecoveryAttemptsPerScene) {
        throw const VideoQualityServiceException('recovery_attempt_limit_reached');
      }
      ledger[sceneId] = attempts + 1;
      await _atomicWriteJson(recoveryFile, ledger);
      try {
        final retried = await hybrid.handle(
          args: {
            'action': 'run_scene',
            'project_dir': projectDir,
            'scene_id': sceneId,
            'retry': true,
            if (_optionalString(args['runtime_profile_id']) != null)
              'runtime_profile_id': args['runtime_profile_id'],
          },
          context: context,
        );
        return {
          ...retried,
          'recovery': {
            'attempt': attempts + 1,
            'maxAttempts': _maxRecoveryAttemptsPerScene,
            'preservedCompletedScenes': true,
          },
        };
      } on Object catch (error) {
        return {
          'ok': false,
          'status': 'failed',
          'sceneId': sceneId,
          'error': 'scene_retry_failed',
          'errorDetail': _redactOutput(error.toString()),
          'recovery': {
            'attempt': attempts + 1,
            'maxAttempts': _maxRecoveryAttemptsPerScene,
            'preservedCompletedScenes': true,
            'retryAllowed': attempts + 1 < _maxRecoveryAttemptsPerScene,
          },
        };
      }
    } finally {
      if (await lockFile.exists()) await lockFile.delete();
    }
  }

  Future<Map<String, Object?>> _probeForSamples(
    _ResolvedVideo input,
    WorkspaceToolContext context,
    Map<String, dynamic> args,
  ) async {
    final missing = await _missingCommands(context, ['ffprobe'], _profileId(args, context));
    if (missing.isNotEmpty) throw const VideoQualityServiceException('ffprobe_missing');
    final result = await _run(
      context: context,
      command: 'ffprobe -v error -show_entries format=duration:stream=codec_type,width,height,r_frame_rate -of json -i ${_quote(input.modelPath)}',
      cwd: input.projectDirectoryModel,
      timeout: const Duration(seconds: 60),
      runtimeProfileId: _profileId(args, context),
    );
    if (!result.succeeded) throw const VideoQualityServiceException('ffprobe_failed');
    return parseProbeJson(result.stdout);
  }

  Future<_ResolvedVideo> _resolveVideo(
    Map<String, dynamic> args,
    WorkspaceToolContext context,
  ) async {
    final rawPath = _optionalString(args['video_path']);
    if (rawPath == null) throw const VideoQualityServiceException('video_path_required');
    final lexical = context.paths.resolve(rawPath, cwd: context.cwd);
    if (lexical.zone != WorkspaceZone.workspace) {
      throw const VideoQualityServiceException('video_path_must_be_in_workspace');
    }
    await _assertNoSymlinkPath(context.paths.workspaceHostRoot, lexical.hostPath);
    final resolved = await context.paths.resolveReal(rawPath, cwd: context.cwd);
    if (resolved.zone != WorkspaceZone.workspace || p.normalize(resolved.hostPath) != p.normalize(lexical.hostPath)) {
      throw const VideoQualityServiceException('video_path_symlink_or_escape_rejected');
    }
    if (await FileSystemEntity.type(resolved.hostPath, followLinks: false) != FileSystemEntityType.file) {
      throw const VideoQualityServiceException('video_file_not_found');
    }
    final file = File(resolved.hostPath);
    final size = await file.length();
    if (size <= 0 || size > _maxVideoBytes) throw const VideoQualityServiceException('video_file_size_invalid');
    final projectDirRaw = _optionalString(args['project_dir']);
    final projectResolved = projectDirRaw == null
        ? ResolvedPath(hostPath: context.paths.workspaceHostRoot, modelPath: context.paths.modelRoot, zone: WorkspaceZone.workspace)
        : await _resolveProjectDirectory(projectDirRaw, context);
    return _ResolvedVideo(
      hostPath: resolved.hostPath,
      modelPath: resolved.modelPath,
      projectDirectory: projectResolved.hostPath,
      projectDirectoryModel: projectResolved.modelPath,
    );
  }

  Future<ResolvedPath> _resolveProjectDirectory(
    String path,
    WorkspaceToolContext context,
  ) async {
    final lexical = context.paths.resolve(path, cwd: context.cwd);
    if (lexical.zone != WorkspaceZone.workspace) {
      throw const VideoQualityServiceException('quality_project_path_invalid');
    }
    await _assertNoSymlinkPath(context.paths.workspaceHostRoot, lexical.hostPath);
    final resolved = await context.paths.resolveReal(path, cwd: context.cwd);
    if (resolved.zone != WorkspaceZone.workspace || p.normalize(resolved.hostPath) != p.normalize(lexical.hostPath)) {
      throw const VideoQualityServiceException('quality_project_symlink_or_escape_rejected');
    }
    if (await FileSystemEntity.type(resolved.hostPath, followLinks: false) != FileSystemEntityType.directory) {
      throw const VideoQualityServiceException('quality_project_directory_missing');
    }
    return resolved;
  }

  Future<ResolvedPath> _resolveWorkspaceFile(
    String path,
    WorkspaceToolContext context,
  ) async {
    final lexical = context.paths.resolve(path, cwd: context.cwd);
    if (lexical.zone != WorkspaceZone.workspace) throw const VideoQualityServiceException('subtitle_path_outside_workspace');
    await _assertNoSymlinkPath(context.paths.workspaceHostRoot, lexical.hostPath);
    final resolved = await context.paths.resolveReal(path, cwd: context.cwd);
    if (resolved.zone != WorkspaceZone.workspace || p.normalize(resolved.hostPath) != p.normalize(lexical.hostPath)) {
      throw const VideoQualityServiceException('subtitle_symlink_or_escape_rejected');
    }
    if (await FileSystemEntity.type(resolved.hostPath, followLinks: false) != FileSystemEntityType.file) {
      throw const VideoQualityServiceException('subtitle_file_not_found');
    }
    return resolved;
  }

  Future<List<String>> _missingCommands(
    WorkspaceToolContext context,
    List<String> commands,
    String? runtimeProfileId,
  ) async {
    final commandList = commands.map(_quote).join(' ');
    final result = await _run(
      context: context,
      command: 'for __kelivo_cmd in $commandList; do command -v "${r'$'}__kelivo_cmd" >/dev/null 2>&1 || echo "__KELIVO_MISSING__:${r'$'}__kelivo_cmd"; done',
      cwd: context.paths.modelRoot,
      timeout: const Duration(seconds: 20),
      runtimeProfileId: runtimeProfileId,
    );
    if (!result.succeeded) throw const VideoQualityServiceException('quality_dependency_probe_failed');
    return RegExp(r'__KELIVO_MISSING__:([A-Za-z0-9_.+-]+)')
        .allMatches(result.stdout)
        .map((match) => match.group(1)!)
        .toList(growable: false);
  }

  Future<_CommandResult> _run({
    required WorkspaceToolContext context,
    required String command,
    required String cwd,
    required Duration timeout,
    String? runtimeProfileId,
  }) async {
    final runtime = runtimeProvider.runtime;
    if (runtime == null) throw const VideoQualityServiceException('quality_runtime_unavailable');
    final status = await runtime.status();
    if (!status.ready || !status.sandboxed || status.engine != 'proot') {
      throw const VideoQualityServiceException('quality_requires_android_proot');
    }
    final runId = 'video-qa-${const Uuid().v4()}';
    final profile = await runtimeProfiles.resolveExecution(
      context: context,
      runId: runId,
      requestedProfileId: runtimeProfileId,
    );
    final actualTimeout = profile == null || timeout <= profile.timeout ? timeout : profile.timeout;
    final invocation = 'cd -- ${_quote(cwd)} && $command';
    final effectiveCommand = profile?.wrapCommand(invocation) ?? invocation;
    final environment = <String, String>{
      'HOME': '/root',
      'PATH': '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
      'NO_COLOR': '1',
      'CI': 'true',
      'LANG': 'C.UTF-8',
      'TMPDIR': '/tmp',
      if (profile != null) ...profile.environment,
    };
    if (profile != null) {
      try {
        await runtimeProfiles.recordStarted(
          execution: profile,
          runtimeRunId: runId,
          command: command,
        );
      } on Object {
        try {
          await runtimeProfiles.cleanupExecution(
            context: context,
            execution: profile,
          );
        } finally {
          runtimeProfiles.releaseReservation(profile.profile.id, runId);
        }
        rethrow;
      }
    }
    final cancellation = ToolCallCancellation.current;
    void Function()? unregister;
    final stdout = StringBuffer();
    final stderr = StringBuffer();
    var outputBytes = 0;
    CommandExited? exited;
    try {
      cancellation?.throwIfCancelled();
      unregister = cancellation?.onCancel(() => unawaited(runtime.cancel(runId)));
      await for (final event in runtime.run(CommandRequest(
        runId: runId,
        command: effectiveCommand,
        cwd: context.paths.normalizeCwd(cwd),
        timeout: actualTimeout,
        env: environment,
        mounts: context.paths.mounts,
        isCancelled: cancellation?.isCancelled,
      ))) {
        switch (event) {
          case CommandOutput(:final kind, bytes: final chunk):
            if (outputBytes < _maxProbeOutputBytes) {
              final selected = chunk.length > _maxProbeOutputBytes - outputBytes
                  ? chunk.sublist(0, _maxProbeOutputBytes - outputBytes)
                  : chunk;
              outputBytes += selected.length;
              final text = utf8.decode(selected, allowMalformed: true);
              if (kind == OutputStreamKind.stdout) stdout.write(text); else stderr.write(text);
            }
          case CommandExited():
            exited = event;
          case CommandStarted():
            break;
        }
      }
      cancellation?.throwIfCancelled();
    } finally {
      unregister?.call();
      if (profile != null) {
        final event = exited;
        final state = event == null || event.interrupted
            ? RuntimeProcessStatus.failed
            : event.cancelled
            ? RuntimeProcessStatus.cancelled
            : event.timedOut
            ? RuntimeProcessStatus.timedOut
            : event.exitCode != 0
            ? RuntimeProcessStatus.failed
            : RuntimeProcessStatus.succeeded;
        try {
          await runtimeProfiles.cleanupExecution(context: context, execution: profile);
          await runtimeProfiles.recordCompleted(
            execution: profile,
            runtimeRunId: runId,
            status: state,
            exitCode: event?.exitCode,
          );
        } catch (_) {
          runtimeProfiles.releaseReservation(profile.profile.id, runId);
        }
      }
    }
    if (exited == null) throw const VideoQualityServiceException('quality_process_exit_missing');
    if (exited.interrupted) throw const VideoQualityServiceException('quality_process_interrupted');
    return _CommandResult(
      exitCode: exited.exitCode,
      stdout: stdout.toString(),
      stderr: stderr.toString(),
      timedOut: exited.timedOut,
      cancelled: exited.cancelled,
    );
  }

  Future<void> _saveReport(
    WorkspaceToolContext context,
    String projectDirectory,
    Map<String, Object?> report,
  ) async {
    final root = context.paths.workspaceHostRoot;
    final directory = p.join(projectDirectory, '.kelivo', 'quality');
    await _assertNoSymlinkPath(root, directory);
    await Directory(directory).create(recursive: true);
    await _assertNoSymlinkPath(root, directory);
    await _atomicWriteJson(File(p.join(directory, 'latest-report.json')), report);
  }

  String _reportPath(String projectDirectory) =>
      p.join(projectDirectory, '.kelivo', 'quality', 'latest-report.json');

  String _recoveryPath(String projectDirectory) =>
      p.join(projectDirectory, '.kelivo', 'quality', 'recovery-state.json');

  static Map<String, Object?> parseProbeJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map || decoded['format'] is! Map || decoded['streams'] is! List) {
      throw const VideoQualityServiceException('ffprobe_json_schema_invalid');
    }
    final format = Map<String, dynamic>.from(decoded['format'] as Map);
    final streams = (decoded['streams'] as List)
        .whereType<Map>()
        .map((stream) => Map<String, dynamic>.from(stream))
        .toList(growable: false);
    if (streams.isEmpty) throw const VideoQualityServiceException('ffprobe_streams_missing');
    return {'format': format, 'streams': streams};
  }

  static List<Map<String, Object?>> evaluateProbe(
    Map<String, Object?> probe, {
    int? expectedWidth,
    int? expectedHeight,
    double? expectedFps,
    double? expectedDuration,
    String audioPolicy = 'preserve',
    bool requireAudio = false,
    double durationTolerance = 1,
  }) {
    if (!const {'preserve', 'prefer_generated', 'mute'}.contains(audioPolicy)) {
      throw const VideoQualityServiceException('quality_audio_policy_invalid');
    }
    final findings = <Map<String, Object?>>[];
    final streams = (probe['streams'] as List? ?? const []).whereType<Map>().toList();
    final video = streams.where((stream) => stream['codec_type'] == 'video').firstOrNull;
    final audioStreams = streams.where((stream) => stream['codec_type'] == 'audio').toList();
    final format = probe['format'] is Map ? probe['format'] as Map : const {};
    if (video == null) {
      findings.add({'code': 'video_stream_missing', 'severity': 'error'});
      return findings;
    }
    final width = _intValue(video['width']);
    final height = _intValue(video['height']);
    if (width == null || height == null || width <= 0 || height <= 0) {
      findings.add({'code': 'video_dimensions_invalid', 'severity': 'error'});
    }
    if (expectedWidth != null && width != expectedWidth) {
      findings.add({'code': 'video_width_mismatch', 'severity': 'error', 'expected': expectedWidth, 'actual': width});
    }
    if (expectedHeight != null && height != expectedHeight) {
      findings.add({'code': 'video_height_mismatch', 'severity': 'error', 'expected': expectedHeight, 'actual': height});
    }
    final fps = _parseRational(video['avg_frame_rate'] ?? video['r_frame_rate']);
    if (fps == null || fps <= 0 || fps > 240) {
      findings.add({'code': 'video_frame_rate_invalid', 'severity': 'error'});
    } else if (expectedFps != null && (fps - expectedFps).abs() > 0.1) {
      findings.add({'code': 'video_frame_rate_mismatch', 'severity': 'error', 'expected': expectedFps, 'actual': fps});
    }
    final duration = _doubleValue(format['duration']) ?? _doubleValue(video['duration']);
    if (duration == null || duration <= 0) {
      findings.add({'code': 'video_duration_invalid', 'severity': 'error'});
    } else if (expectedDuration != null && (duration - expectedDuration).abs() > durationTolerance) {
      findings.add({'code': 'video_duration_mismatch', 'severity': 'warning', 'expected': expectedDuration, 'actual': duration});
    }
    final formatNames = (format['format_name'] ?? '').toString().toLowerCase();
    if (!formatNames.split(',').any((name) => name == 'mp4' || name == 'mov')) {
      findings.add({'code': 'container_not_mp4_compatible', 'severity': 'error', 'actual': formatNames});
    }
    if (audioPolicy == 'mute' && audioStreams.isNotEmpty) {
      findings.add({'code': 'unexpected_audio_stream', 'severity': 'error'});
    }
    if (requireAudio && audioStreams.isEmpty) {
      findings.add({'code': 'required_audio_stream_missing', 'severity': 'error'});
    }
    if (audioStreams.isNotEmpty) {
      final videoStart = _doubleValue(video['start_time']);
      final audioStart = _doubleValue(audioStreams.first['start_time']);
      if (videoStart != null && audioStart != null && (videoStart - audioStart).abs() > 0.05) {
        findings.add({'code': 'audio_video_start_offset', 'severity': 'warning', 'offsetSeconds': audioStart - videoStart});
      }
      final videoDuration = _doubleValue(video['duration']);
      final audioDuration = _doubleValue(audioStreams.first['duration']);
      if (videoDuration != null && audioDuration != null && (videoDuration - audioDuration).abs() > 0.5) {
        findings.add({'code': 'audio_video_duration_mismatch', 'severity': 'warning', 'offsetSeconds': audioDuration - videoDuration});
      }
    }
    return findings;
  }

  static VideoSubtitleReport validateSubtitle(
    String source, {
    double? durationSeconds,
  }) {
    final findings = <VideoSubtitleFinding>[];
    final lines = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    final timestamp = RegExp(r'^(\d{2}:\d{2}:\d{2}[,.]\d{3}|\d{2}:\d{2}[,.]\d{3})\s+-->\s+(\d{2}:\d{2}:\d{2}[,.]\d{3}|\d{2}:\d{2}[,.]\d{3})(?:\s+.*)?$');
    final cues = <({double start, double end, int line})>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final match = timestamp.firstMatch(line);
      if (match == null) continue;
      final start = _parseSubtitleTimestamp(match.group(1)!);
      final end = _parseSubtitleTimestamp(match.group(2)!);
      if (start == null || end == null || end <= start) {
        findings.add(VideoSubtitleFinding(code: 'timestamp_invalid_or_reversed', severity: 'error', cue: cues.length + 1));
        continue;
      }
      cues.add((start: start, end: end, line: i + 1));
      if (durationSeconds != null && end > durationSeconds + 0.25) {
        findings.add(VideoSubtitleFinding(code: 'cue_exceeds_video_duration', severity: 'warning', cue: cues.length));
      }
    }
    if (cues.isEmpty && source.trim().isNotEmpty) {
      findings.add(const VideoSubtitleFinding(code: 'subtitle_cues_not_recognized', severity: 'error'));
    }
    for (var i = 1; i < cues.length; i++) {
      if (cues[i].start < cues[i - 1].start) {
        findings.add(VideoSubtitleFinding(code: 'cue_order_not_monotonic', severity: 'warning', cue: i + 1));
      }
      if (cues[i].start < cues[i - 1].end - 0.02) {
        findings.add(VideoSubtitleFinding(code: 'cue_overlap', severity: 'warning', cue: i + 1));
      }
    }
    return VideoSubtitleReport(cueCount: cues.length, findings: findings);
  }

  static Map<String, Object?> classifyFailure({
    required int exitCode,
    required String stdout,
    required String stderr,
    required bool timedOut,
  }) {
    final text = '$stdout\n$stderr'.toLowerCase();
    if (timedOut || text.contains('timed out') || text.contains('timeout')) {
      return {'category': 'timeout', 'severity': 'warning', 'recommendedAction': 'reduce_scope_or_increase_runtime_timeout'};
    }
    if (text.contains('not found') || text.contains('no such file') || text.contains('command not found')) {
      return {'category': 'missing_binary_or_file', 'severity': 'error', 'recommendedAction': 'verify_binary_and_workspace_path'};
    }
    if (text.contains('invalid data') || text.contains('moov atom not found') || text.contains('invalid argument')) {
      return {'category': 'invalid_or_incomplete_media', 'severity': 'error', 'recommendedAction': 'preserve_output_and_rerender_failed_stage'};
    }
    if (text.contains('out of memory') || text.contains('cannot allocate memory')) {
      return {'category': 'resource_exhaustion', 'severity': 'error', 'recommendedAction': 'lower_resolution_or_split_render'};
    }
    if (text.contains('connection reset') || text.contains('network is unreachable') || text.contains('connection timed out')) {
      return {'category': 'network_interruption', 'severity': 'warning', 'recommendedAction': 'resume_provider_job_or_retry_download'};
    }
    if (text.contains('syntaxerror') || text.contains('syntax error') || text.contains('traceback') || text.contains('exception')) {
      return {'category': 'code_or_script_failure', 'severity': 'error', 'recommendedAction': 'inspect_stack_trace_before_changing_dependencies'};
    }
    return {'category': exitCode == 0 ? 'no_failure_detected' : 'unknown_failure', 'severity': exitCode == 0 ? 'info' : 'warning', 'recommendedAction': 'inspect_full_error_and_preserve_completed_outputs'};
  }

  static Map<String, Object?> _qualitySummary(Map<String, Object?> probe) {
    final streams = (probe['streams'] as List? ?? const []).whereType<Map>().toList();
    final video = streams.where((item) => item['codec_type'] == 'video').firstOrNull;
    final audio = streams.where((item) => item['codec_type'] == 'audio').firstOrNull;
    final format = probe['format'] is Map ? probe['format'] as Map : const {};
    return {
      'formatName': format['format_name'],
      'durationSeconds': _doubleValue(format['duration']) ?? (video == null ? null : _doubleValue(video['duration'])),
      'videoCodec': video?['codec_name'],
      'width': video == null ? null : _intValue(video['width']),
      'height': video == null ? null : _intValue(video['height']),
      'frameCount': video == null ? null : _intValue(video['nb_frames']),
      'fps': video == null ? null : _parseRational(video['avg_frame_rate'] ?? video['r_frame_rate']),
      'hasAudio': audio != null,
      'audioCodec': audio?['codec_name'],
      'audioStartSeconds': audio == null ? null : _doubleValue(audio['start_time']),
      'videoStartSeconds': video == null ? null : _doubleValue(video['start_time']),
    };
  }

  static double? _formatDuration(Map<String, Object?> probe) {
    final summary = _qualitySummary(probe);
    return _doubleValue(summary['durationSeconds']);
  }

  static List<_MediaInterval> _parseIntervals(String source, String pattern) {
    final regex = RegExp(pattern, dotAll: true);
    return regex.allMatches(source).map((match) {
      final start = double.tryParse(match.group(1) ?? '');
      final end = double.tryParse(match.group(2) ?? '');
      if (start == null || end == null || end < start) return null;
      return _MediaInterval(start, end);
    }).whereType<_MediaInterval>().toList(growable: false);
  }

  static double? _parseRational(Object? value) {
    if (value is num) return value.toDouble();
    if (value is! String || value.isEmpty) return null;
    final parts = value.split('/');
    if (parts.length == 1) return double.tryParse(parts.first);
    if (parts.length != 2) return null;
    final numerator = double.tryParse(parts[0]);
    final denominator = double.tryParse(parts[1]);
    if (numerator == null || denominator == null || denominator == 0) return null;
    return numerator / denominator;
  }

  static double? _parseSubtitleTimestamp(String value) {
    final normalized = value.replaceAll(',', '.');
    final parts = normalized.split(':');
    if (parts.length == 2) {
      final seconds = double.tryParse(parts[1]);
      final minutes = int.tryParse(parts[0]);
      if (seconds == null || minutes == null) return null;
      return minutes * 60 + seconds;
    }
    if (parts.length == 3) {
      final hours = int.tryParse(parts[0]);
      final minutes = int.tryParse(parts[1]);
      final seconds = double.tryParse(parts[2]);
      if (hours == null || minutes == null || seconds == null) return null;
      return hours * 3600 + minutes * 60 + seconds;
    }
    return null;
  }

  static int? _intValue(Object? value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
  static double? _doubleValue(Object? value) => value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
  static int? _optionalInt(Object? value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
  static double? _optionalDouble(Object? value) => value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
  static String? _optionalString(Object? value) { final s = value?.toString().trim(); return s == null || s.isEmpty ? null : s; }
  static List<String> _stringList(Object? value) => value is List ? value.whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty).take(32).toList(growable: false) : const [];
  static String? _profileId(Map<String, dynamic> args, WorkspaceToolContext context) => _optionalString(args['runtime_profile_id']) ?? context.workspace.defaultRuntimeProfileId;

  static String _quote(String value) => "'${value.replaceAll("'", "'\\''")}'";
  static String _redactOutput(String value) => value
      .replaceAll(RegExp(r'(authorization|api[_-]?key|token|secret|password)(\s*[:=]\s*)[^\s,;]+', caseSensitive: false), r'$1$2[REDACTED]')
      .replaceAll(RegExp(r'https?://[^\s]+[?&](?:token|key|signature)=[^\s&]+', caseSensitive: false), '[REDACTED_URL]')
      .substring(0, math.min(value.length, 12000));

  static Future<void> _atomicWriteJson(File file, Map<String, Object?> value) async {
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp-${const Uuid().v4()}');
    try {
      await temporary.writeAsString(
        const JsonEncoder.withIndent('  ').convert(value),
        flush: true,
      );
      // On Android/Linux rename replaces the existing report atomically.
      await temporary.rename(file.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  static Future<void> _assertNoSymlinkPath(String root, String target) async {
    final normalizedRoot = p.normalize(root);
    final normalizedTarget = p.normalize(target);
    if (!p.isWithin(normalizedRoot, normalizedTarget) && normalizedRoot != normalizedTarget) {
      throw const VideoQualityServiceException('quality_path_outside_workspace');
    }
    final relative = p.relative(normalizedTarget, from: normalizedRoot);
    var current = normalizedRoot;
    for (final segment in p.split(relative).where((part) => part != '.')) {
      current = p.join(current, segment);
      if (await FileSystemEntity.type(current, followLinks: false) == FileSystemEntityType.link) {
        throw const VideoQualityServiceException('quality_symlink_path_rejected');
      }
    }
  }

  static void _requireWorkspace(WorkspaceToolContext context) {
    if (context.skillsOnly || context.paths.workspaceHostRoot.isEmpty) {
      throw const VideoQualityServiceException('workspace_required');
    }
  }
}

class _ResolvedVideo {
  const _ResolvedVideo({required this.hostPath, required this.modelPath, required this.projectDirectory, required this.projectDirectoryModel});
  final String hostPath;
  final String modelPath;
  final String projectDirectory;
  final String projectDirectoryModel;
}

class _CommandResult {
  const _CommandResult({required this.exitCode, required this.stdout, required this.stderr, this.timedOut = false, this.cancelled = false});
  final int exitCode;
  final String stdout;
  final String stderr;
  final bool timedOut;
  final bool cancelled;
  bool get succeeded => exitCode == 0 && !timedOut && !cancelled;
}

class _MediaInterval {
  const _MediaInterval(this.start, this.end);
  final double start;
  final double end;
  double get duration => end - start;
}
