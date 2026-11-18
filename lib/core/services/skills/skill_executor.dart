import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../api/tool_call_cancellation.dart';
import '../../database/extension_entity_store.dart';
import '../runtime_profiles/runtime_profile_models.dart';
import '../runtime_profiles/runtime_profile_service.dart';
import '../workspace/workspace_runtime.dart';
import '../workspace/workspace_tool_context.dart';
import 'skill.dart';
import 'skill_execution_security.dart';
import 'skill_execution_permissions.dart';

/// A typed execution bridge for explicitly declared local-script capabilities.
///
/// This is deliberately not a general shell adapter. It accepts only an exact
/// entry point listed in the Phase 13A local_script descriptor, checks its
/// manifest digest, stages a private snapshot, and invokes a supported
/// interpreter with separately quoted argv values.
final class SkillExecutor {
  SkillExecutor({
    required this.runtimeProvider,
    required this.runtimeProfiles,
    required this.ledgerStore,
    this.maxSnapshotBytes = 128 * 1024 * 1024,
    this.maxSingleFileBytes = 64 * 1024 * 1024,
    this.maxInputBytes = 1024 * 1024,
    this.maxOutputFileBytes = 128 * 1024 * 1024,
  });

  static const String runGuestRoot = '/run/kelivo-skill';
  static const int maxCapturedOutputBytes = 128 * 1024;
  static const int maxManifestEntries = 8192;
  static const Set<String> supportedScriptExtensions = {
    '.py',
    '.sh',
    '.bash',
    '.js',
    '.mjs',
    '.cjs',
  };

  final WorkspaceRuntimeProvider runtimeProvider;
  final RuntimeProfileService runtimeProfiles;
  final ExtensionEntityStore ledgerStore;
  final int maxSnapshotBytes;
  final int maxSingleFileBytes;
  final int maxInputBytes;
  final int maxOutputFileBytes;
  static const int maxTotalOutputBytes = 128 * 1024 * 1024;
  static const int maxTotalInputFileBytes = 128 * 1024 * 1024;
  static const int maxOutputTreeEntries = 512;
  static Future<void> _ledgerWriteTail = Future<void>.value();

  Future<Map<String, Object?>> execute({
    required Skill skill,
    required WorkspaceToolContext context,
    required Map<String, Object?> compositionPlan,
    required Map<String, Object?> importManifest,
    required String entryPoint,
    required String runtimeProfileId,
    List<String> arguments = const <String>[],
    Map<String, Object?> inputs = const <String, Object?>{},
    Map<String, String> inputFiles = const <String, String>{},
    Map<String, String> expectedOutputs = const <String, String>{},
    Map<String, String> expectedOutputTypes = const <String, String>{},
    int requestedTimeoutSeconds = 900,
    required List<Map<String, Object?>> permissionReview,
    required String executionGrantId,
    required Map<String, String> selectedSourceDigests,
    required bool sharedRootfsRiskAcknowledged,
  }) async {
    final cancellation = ToolCallCancellation.current;
    cancellation?.throwIfCancelled();
    _validateSkillIdentity(skill);
    // The dispatcher passes only Skills already resolved for the active
    // assistant/conversation. Do not inspect record.enabled here: an enabled
    // Skill Pack intentionally activates its members as one activation unit.
    if (context.skillsOnly) {
      throw const SkillExecutionException('workspace_required');
    }
    if (!sharedRootfsRiskAcknowledged) {
      throw const SkillExecutionException('shared_rootfs_risk_not_acknowledged');
    }
    if (!context.paths.sandboxed) {
      throw const SkillExecutionException('skill_execution_requires_android_proot');
    }
    if (entryPoint.length > 240 || _safeRelativePath(entryPoint) == null) {
      throw const SkillExecutionException('invalid_skill_entry_point');
    }
    if (arguments.length > 64 || arguments.any((value) =>
        value.length > 4096 || value.contains('\u0000'))) {
      throw const SkillExecutionException('invalid_skill_arguments');
    }
    if (inputs.length > 64 || inputFiles.length > 32 || expectedOutputs.length > 32 ||
        expectedOutputTypes.length > 32 ||
        expectedOutputTypes.keys.any((key) => !expectedOutputs.containsKey(key))) {
      throw const SkillExecutionException('skill_io_limit_exceeded');
    }
    if (expectedOutputs.values.toSet().length != expectedOutputs.length ||
        expectedOutputs.keys.any((key) => !_safeArtifactName(key))) {
      throw const SkillExecutionException('invalid_or_duplicate_expected_skill_output');
    }
    for (final type in expectedOutputTypes.values) {
      if (!RegExp(r'^[a-z0-9][a-z0-9.+-]*/[a-z0-9][a-z0-9.+-]*$')
          .hasMatch(type.toLowerCase())) {
        throw const SkillExecutionException('invalid_expected_output_media_type');
      }
    }
    if (permissionReview.any((item) => item['blockedUntilReviewed'] == true)) {
      throw const SkillExecutionException('skill_permission_review_blocked');
    }
    try {
      SkillExecutionPermissionPolicy.validateSingleRunGrant(
        permissionReview: permissionReview,
        grantId: executionGrantId,
      );
    } on SkillExecutionPermissionException catch (error) {
      throw SkillExecutionException(error.code);
    }

    final manifest = _parseManifest(
      compositionPlan: compositionPlan,
      importManifest: importManifest,
      skillId: skill.record.id,
    );
    final planDigest = _planDigest(context.workspace.id, compositionPlan);
    if (selectedSourceDigests[skill.record.id] != manifest['sourceDigest']) {
      throw const SkillExecutionException('skill_source_digest_not_in_composition_snapshot');
    }
    final rawSelectedIds = compositionPlan['selectedSkillIds'];
    if (rawSelectedIds is! List || rawSelectedIds.isEmpty || rawSelectedIds.length > 64) {
      throw const SkillExecutionException('invalid_selected_skill_snapshot');
    }
    for (final id in rawSelectedIds) {
      if (id is! String || selectedSourceDigests[id] == null || selectedSourceDigests[id]!.isEmpty) {
        throw const SkillExecutionException('selected_skill_import_manifest_missing');
      }
    }
    final predecessorState = await _verifiedCompletedStages(
      context: context,
      plan: compositionPlan,
      planDigest: planDigest,
      currentSkillId: skill.record.id,
      selectedSourceDigests: selectedSourceDigests,
    );
    final stage = _validateCompositionStage(
      compositionPlan,
      skill.record.id,
      predecessorState.completedSkillIds,
    );
    final fileEntries = _readSkillFileEntries(manifest);
    final entryFile = fileEntries[entryPoint];
    if (entryFile == null) {
      throw const SkillExecutionException('entry_point_missing_from_import_manifest');
    }
    final capability = _findLocalScriptCapability(manifest, entryPoint);
    if (capability == null) {
      throw const SkillExecutionException('entry_point_not_declared_local_script');
    }
    final interpreter = _interpreterFor(entryPoint);
    if (interpreter == null) {
      throw const SkillExecutionException('unsupported_script_interpreter');
    }
    // Validate runtime availability and the selected interpreter before
    // checking workflow artifact contracts. A malformed/missing output contract
    // must not mask the more fundamental incompatibility of the chosen profile.
    final runtime = await runtimeProvider.ensureInitialized();
    if (runtime == null) {
      throw const SkillExecutionException('runtime_unavailable');
    }
    final runtimeStatus = await runtime.status();
    if (!runtimeStatus.ready ||
        !runtimeStatus.sandboxed ||
        runtimeStatus.engine != 'proot') {
      throw SkillExecutionException(
        runtimeStatus.reason ?? 'skill_execution_requires_android_proot',
      );
    }

    // WorkspacePlugin adds configured external mounts to every PRoot process,
    // even when this request omits them. Refuse until none are attached.
    await context.paths.refreshExternalMounts();
    if (context.paths.externalMounts.isNotEmpty) {
      throw const SkillExecutionException(
        'skill_execution_blocked_while_external_mounts_attached',
      );
    }

    final runId = 'skill-${const Uuid().v4()}';
    final profileExecution = await runtimeProfiles.resolveSkillExecution(
      context: context,
      runId: runId,
      skillId: skill.record.id,
      requestedProfileId: runtimeProfileId,
    );
    var profileStarted = false;
    var reservationReleased = false;
    var keepOutput = false;
    var captureTruncated = false;
    var processExitCode = -1;
    var processTimedOut = false;
    var processCancelled = false;
    var processError = <String>[];
    var processOutput = <String>[];
    final stopwatch = Stopwatch()..start();
    final outputRedactionValues = SkillExecutionSecurityPolicy.collectSensitiveValues(
      arguments: arguments,
      inputs: inputs,
    );
    Directory? runDirectory;
    String? runRelativePath;
    String? outputDirectoryRelativePath;
    void Function()? unregisterCancellation;

    try {
      _validateProfileInterpreter(profileExecution.profile, interpreter);
      _validateArtifactContracts(
        stage: stage,
        inputs: inputs,
        inputFiles: inputFiles,
        skillId: skill.record.id,
        expectedOutputs: expectedOutputs,
      );
      await _validateLinkedArtifactInputs(
        context: context,
        plan: compositionPlan,
        skillId: skill.record.id,
        inputFiles: inputFiles,
        predecessorArtifacts: predecessorState.artifactHostPaths,
      );
      runDirectory = await _createRunDirectory(context, runId);
      runRelativePath = p.relative(
        runDirectory.path,
        from: context.paths.workspaceHostRoot,
      ).replaceAll('\\', '/');
      final sourceDirectory = Directory(p.join(runDirectory.path, 'source'));
      final ioDirectory = Directory(p.join(runDirectory.path, 'io'));
      final inputDirectory = Directory(p.join(ioDirectory.path, 'input'));
      final outputDirectory = Directory(p.join(ioDirectory.path, 'output'));
      final temporaryDirectory = Directory(p.join(ioDirectory.path, 'tmp'));
      await sourceDirectory.create(recursive: true);
      await inputDirectory.create(recursive: true);
      await outputDirectory.create(recursive: true);
      await temporaryDirectory.create(recursive: true);

      final copiedBytes = await _stageSkillSnapshot(
        skillRoot: Directory(skill.dir),
        trustedSkillsRoot: Directory(context.paths.skillsHostDir),
        destinationRoot: sourceDirectory,
        fileEntries: fileEntries,
      );
      final stagedInputFiles = await _stageInputFiles(
        context: context,
        inputDirectory: inputDirectory,
        inputFiles: inputFiles,
      );
      final inputDocument = <String, Object?>{
        'schemaVersion': 1,
        'skillId': skill.record.id,
        'task': compositionPlan['task'],
        'data': inputs,
        'files': stagedInputFiles,
      };
      final inputJson = jsonEncode(inputDocument);
      if (utf8.encode(inputJson).length > maxInputBytes) {
        throw const SkillExecutionException('skill_input_payload_too_large');
      }
      await File(p.join(inputDirectory.path, 'input.json')).writeAsString(
        inputJson,
        flush: true,
      );

      outputDirectoryRelativePath = p.posix.join(
        runRelativePath,
        'io/output',
      );
      final sourceGuest = '$runGuestRoot/source';
      final ioGuest = '$runGuestRoot/io';
      final scriptGuestPath = p.posix.join(sourceGuest, entryPoint);
      final effectiveTimeoutSeconds = requestedTimeoutSeconds
          .clamp(1, profileExecution.timeout.inSeconds)
          .toInt();
      final command = _buildInterpreterCommand(
        interpreter: interpreter,
        scriptPath: scriptGuestPath,
        arguments: arguments,
      );
      final effectiveCommand = profileExecution.wrapCommand(command);
      final runtimeEnvironment = <String, String>{
        'HOME': '/root',
        'NO_COLOR': '1',
        'CI': 'true',
        'LANG': 'C.UTF-8',
        ...SkillExecutionSecurityPolicy.runtimeBootstrapEnvironment(
          profileExecution.environment,
        ),
        // Put KELIVO's best-effort read-only command wrappers ahead of the
        // profile-specific paths. Keep profile Python/Node bins available.
        'PATH': _guardedSkillPath(profileExecution.environment['PATH']),
        'TMPDIR': '$ioGuest/tmp',
        'TMP': '$ioGuest/tmp',
        'TEMP': '$ioGuest/tmp',
        'KELIVO_TASK_OUTPUT_DIR': '$ioGuest/output',
        'KELIVO_SKILL_INPUT_JSON': '$ioGuest/input/input.json',
        'KELIVO_SKILL_ID': skill.record.id,
        'KELIVO_SKILL_ENTRY_POINT': entryPoint,
      };

      await runtimeProfiles.recordStarted(
        execution: profileExecution,
        runtimeRunId: runId,
        command: '$interpreter $entryPoint',
      );
      profileStarted = true;
      unregisterCancellation = cancellation?.onCancel(() {
        unawaited(runtime.cancel(runId));
      });

      // Recheck immediately before handing control to the third-party process;
      // WorkspacePlugin may attach configured mounts to PRoot requests.
      await context.paths.refreshExternalMounts();
      if (context.paths.externalMounts.isNotEmpty) {
        throw const SkillExecutionException(
          'skill_execution_blocked_while_external_mounts_attached',
        );
      }
      final stdout = BytesBuilder(copy: false);
      final stderr = BytesBuilder(copy: false);
      CommandExited? exited;
      await for (final event in runtime.run(
        CommandRequest(
          runId: runId,
          command: effectiveCommand,
          cwd: sourceGuest,
          timeout: Duration(seconds: effectiveTimeoutSeconds),
          env: runtimeEnvironment,
          // Intentionally do not pass context.paths.mounts: no /workspace,
          // /chat, /skills, /tmp or external user mounts are exposed.
          mounts: [
            // Keep each run surface separate. The Android runtime applies
            // best-effort command guards to read-only source/input binds; PRoot
            // itself does not provide kernel-enforced read-only mount flags.
            Mount(
              host: sourceDirectory.path,
              guest: sourceGuest,
              readOnly: true,
            ),
            Mount(
              host: inputDirectory.path,
              guest: '$ioGuest/input',
              readOnly: true,
            ),
            Mount(
              host: outputDirectory.path,
              guest: '$ioGuest/output',
            ),
            Mount(
              host: temporaryDirectory.path,
              guest: '$ioGuest/tmp',
            ),
          ],
          isCancelled: cancellation?.isCancelled,
        ),
      )) {
        switch (event) {
          case CommandOutput(:final kind, :final bytes):
            final target = kind == OutputStreamKind.stdout ? stdout : stderr;
            captureTruncated =
                _appendBounded(target, bytes, maxCapturedOutputBytes) ||
                captureTruncated;
          case CommandExited():
            exited = event;
          case CommandStarted():
            break;
        }
      }
      stopwatch.stop();
      processExitCode = exited?.exitCode ?? -1;
      processTimedOut = exited?.timedOut ?? false;
      processCancelled = exited?.cancelled ?? cancellation?.isCancelled() ?? false;
      processOutput = _decodeBounded(stdout.takeBytes());
      processError = _decodeBounded(stderr.takeBytes());

      final outputRootType = await FileSystemEntity.type(
        outputDirectory.path,
        followLinks: false,
      );
      final canonicalRunRoot = await runDirectory.resolveSymbolicLinks();
      final canonicalOutputRoot = await outputDirectory.resolveSymbolicLinks();
      if (outputRootType != FileSystemEntityType.directory ||
          !p.isWithin(canonicalRunRoot, canonicalOutputRoot)) {
        throw const SkillExecutionException('skill_output_root_replaced_or_escaped');
      }
      final outputReports = <Map<String, Object?>>[];
      if (exited == null || exited.exitCode != 0 || exited.timedOut || exited.cancelled) {
        final status = exited?.cancelled == true
            ? RuntimeProcessStatus.cancelled
            : exited?.timedOut == true
                ? RuntimeProcessStatus.timedOut
                : RuntimeProcessStatus.failed;
        await runtimeProfiles.recordCompleted(
          execution: profileExecution,
          runtimeRunId: runId,
          status: status,
          exitCode: exited?.exitCode,
          error: exited == null ? 'runtime_exit_event_missing' : null,
        );
        profileStarted = false;
        return _executionReport(
          status: processCancelled
              ? 'cancelled'
              : processTimedOut
                  ? 'timed_out'
                  : 'failed',
          runId: runId,
          skill: skill,
          entryPoint: entryPoint,
          interpreter: interpreter,
          profile: profileExecution.profile,
          processExitCode: processExitCode,
          stdout: processOutput,
          stderr: processError,
          duration: stopwatch.elapsed,
          sourceDigest: manifest['sourceDigest']?.toString() ?? '',
          permissionReview: permissionReview,
          arguments: arguments,
          outputs: outputReports,
          copiedBytes: copiedBytes,
          outputDirectoryRelativePath: outputDirectoryRelativePath,
          captureTruncated: captureTruncated,
          redactionValues: outputRedactionValues,
        );
      }

      await _validateOutputTree(
        outputDirectory: outputDirectory,
        expectedPaths: expectedOutputs.values.toSet(),
      );
      var totalOutputBytes = 0;
      for (final entry in expectedOutputs.entries) {
        final safe = _safeRelativePath(entry.value);
        if (safe == null) {
          throw const SkillExecutionException('invalid_expected_output_path');
        }
        final output = await _resolveRegularFile(outputDirectory, safe);
        final size = await output.length();
        if (size > maxOutputFileBytes) {
          throw SkillExecutionException('skill_output_too_large:${entry.key}');
        }
        totalOutputBytes += size;
        if (totalOutputBytes > maxTotalOutputBytes) {
          throw const SkillExecutionException('skill_total_output_size_limit');
        }
        final detectedMediaType = await _validatedMediaType(output, safe);
        final expectedType = expectedOutputTypes[entry.key]?.toLowerCase();
        if (expectedType != null && expectedType != detectedMediaType) {
          throw SkillExecutionException(
            'skill_output_type_mismatch:${entry.key}:$expectedType:$detectedMediaType',
          );
        }
        outputReports.add({
          'artifact': entry.key,
          'relativePath': safe,
          'workspacePath': context.paths.toModelPath(
            p.joinAll([
              runDirectory.path,
              'io',
              'output',
              ...p.posix.split(safe),
            ]),
          ),
          'workspaceRelativePath': p.posix.join(
            runRelativePath,
            'io/output',
            safe,
          ),
          'sizeBytes': size,
          'sha256': await _sha256File(output),
          'mediaType': detectedMediaType,
          'mediaTypeCheck': detectedMediaType == 'application/octet-stream'
              ? 'extension_only_unclassified'
              : 'content_and_extension',
        });
      }

      await runtimeProfiles.recordCompleted(
        execution: profileExecution,
        runtimeRunId: runId,
        status: RuntimeProcessStatus.succeeded,
        exitCode: processExitCode,
      );
      profileStarted = false;
      reservationReleased = true;
      await _recordSuccessfulStage(
        planDigest: planDigest,
        workspaceId: context.workspace.id,
        plan: compositionPlan,
        skillId: skill.record.id,
        sourceDigest: manifest['sourceDigest']!.toString(),
        runId: runId,
        outputs: outputReports,
      );
      keepOutput = true;
      await sourceDirectory.delete(recursive: true);
      await inputDirectory.delete(recursive: true);
      await temporaryDirectory.delete(recursive: true);
      stopwatch.stop();
      return _executionReport(
        status: 'succeeded',
        runId: runId,
        skill: skill,
        entryPoint: entryPoint,
        interpreter: interpreter,
        profile: profileExecution.profile,
        processExitCode: processExitCode,
        stdout: processOutput,
        stderr: processError,
        duration: stopwatch.elapsed,
        sourceDigest: manifest['sourceDigest']?.toString() ?? '',
        permissionReview: permissionReview,
        arguments: arguments,
        outputs: outputReports,
        copiedBytes: copiedBytes,
        outputDirectoryRelativePath: outputDirectoryRelativePath,
        captureTruncated: captureTruncated,
        redactionValues: outputRedactionValues,
      );
    } catch (_) {
      stopwatch.stop();
      rethrow;
    } finally {
      unregisterCancellation?.call();
      if (!reservationReleased) {
        if (profileStarted) {
          try {
            await runtimeProfiles.recordCompleted(
              execution: profileExecution,
              runtimeRunId: runId,
              status: processCancelled
                  ? RuntimeProcessStatus.cancelled
                  : processTimedOut
                      ? RuntimeProcessStatus.timedOut
                      : RuntimeProcessStatus.failed,
              exitCode: processExitCode < 0 ? null : processExitCode,
              error: 'skill_execution_interrupted',
            );
            reservationReleased = true;
          } catch (_) {
            runtimeProfiles.releaseReservation(profileExecution.profile.id, runId);
            reservationReleased = true;
          }
        } else {
          runtimeProfiles.releaseReservation(profileExecution.profile.id, runId);
          reservationReleased = true;
        }
      }
      if (runDirectory != null && await runDirectory.exists() && !keepOutput) {
        // A failed run is fully discarded, including its untrusted snapshot
        // and any partial output artifacts.
        try {
          await runDirectory.delete(recursive: true);
        } catch (_) {}
      }
      try {
        await runtimeProfiles.cleanupExecution(
          context: context,
          execution: profileExecution,
        );
      } catch (_) {}
    }
  }

  static String _planDigest(String workspaceId, Map<String, Object?> plan) {
    final canonical = _canonicalize(plan);
    return sha256.convert(utf8.encode('$workspaceId\n${jsonEncode(canonical)}')).toString();
  }

  static Object? _canonicalize(Object? value) {
    if (value is Map) {
      final entries = value.entries
          .where((entry) => entry.key is String)
          .toList()
        ..sort((a, b) => (a.key as String).compareTo(b.key as String));
      return <String, Object?>{
        for (final entry in entries)
          entry.key as String: _canonicalize(entry.value),
      };
    }
    if (value is List) return value.map(_canonicalize).toList(growable: false);
    return value;
  }

  Future<_VerifiedSkillStages> _verifiedCompletedStages({
    required WorkspaceToolContext context,
    required Map<String, Object?> plan,
    required String planDigest,
    required String currentSkillId,
    required Map<String, String> selectedSourceDigests,
  }) async {
    final stagesRaw = plan['executionStages'];
    if (stagesRaw is! List) {
      throw const SkillExecutionException('invalid_composition_stages');
    }
    final stages = <List<String>>[];
    for (final raw in stagesRaw) {
      if (raw is! Map || raw['skillIds'] is! List) {
        throw const SkillExecutionException('invalid_composition_stage');
      }
      stages.add((raw['skillIds'] as List).whereType<String>().toList());
    }
    final currentIndex = stages.indexWhere((ids) => ids.contains(currentSkillId));
    if (currentIndex < 0) {
      throw const SkillExecutionException('skill_not_selected_by_composition');
    }
    if (currentIndex == 0) return _VerifiedSkillStages.empty();

    final ledgerId = planDigest;
    final row = await ledgerStore.get(
      ExtensionEntityStore.kindSkillExecutionLedger,
      ledgerId,
    );
    if (row == null) {
      throw const SkillExecutionException('composition_predecessor_stage_incomplete');
    }
    final payload = row.payload;
    if (payload['schemaVersion'] != 1 ||
        payload['planDigest'] != planDigest ||
        payload['workspaceId'] != context.workspace.id ||
        payload['records'] is! Map) {
      throw const SkillExecutionException('skill_execution_ledger_invalid');
    }
    final records = Map<String, dynamic>.from(payload['records'] as Map);
    final contracts = plan['artifactContracts'];
    final expectedOutputs = contracts is Map && contracts['outputs'] is Map
        ? Map<String, dynamic>.from(contracts['outputs'] as Map)
        : <String, dynamic>{};
    final completed = <String>{};
    final artifactHostPaths = <String, String>{};
    for (final id in stages.take(currentIndex).expand((items) => items)) {
      final rawRecord = records[id];
      if (rawRecord is! Map || rawRecord['status'] != 'succeeded' ||
          rawRecord['sourceDigest'] != selectedSourceDigests[id] ||
          rawRecord['outputs'] is! List) {
        throw SkillExecutionException('composition_predecessor_stage_incomplete:$id');
      }
      final actualOutputs = <String>{};
      for (final rawOutput in rawRecord['outputs'] as List) {
        if (rawOutput is! Map) {
          throw const SkillExecutionException('skill_execution_ledger_invalid_output');
        }
        final artifact = rawOutput['artifact'];
        final relativePath = rawOutput['workspaceRelativePath'];
        final digest = rawOutput['sha256'];
        final size = rawOutput['sizeBytes'];
        if (artifact is! String || relativePath is! String ||
            digest is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(digest) ||
            size is! num || size < 0) {
          throw const SkillExecutionException('skill_execution_ledger_invalid_output');
        }
        final safe = _safeRelativePath(relativePath);
        if (safe == null) {
          throw const SkillExecutionException('skill_execution_ledger_path_invalid');
        }
        final output = await _resolveRegularFile(
          Directory(context.paths.workspaceHostRoot),
          safe,
        );
        if (await output.length() != size.toInt() ||
            await _sha256File(output) != digest ||
            rawOutput['workspacePath'] != context.paths.toModelPath(output.path)) {
          throw SkillExecutionException('composition_predecessor_output_changed:$id:$artifact');
        }
        actualOutputs.add(artifact);
        final previous = artifactHostPaths[artifact];
        if (previous != null && previous != output.path) {
          throw SkillExecutionException('ambiguous_verified_artifact:$artifact');
        }
        artifactHostPaths[artifact] = output.path;
      }
      final requiredOutputs = expectedOutputs[id] is List
          ? (expectedOutputs[id] as List).whereType<String>().toSet()
          : <String>{};
      if (!actualOutputs.containsAll(requiredOutputs)) {
        throw SkillExecutionException('composition_predecessor_outputs_missing:$id');
      }
      completed.add(id);
    }
    return _VerifiedSkillStages(
      completedSkillIds: completed,
      artifactHostPaths: artifactHostPaths,
    );
  }

  Future<void> _validateLinkedArtifactInputs({
    required WorkspaceToolContext context,
    required Map<String, Object?> plan,
    required String skillId,
    required Map<String, String> inputFiles,
    required Map<String, String> predecessorArtifacts,
  }) async {
    final rawEdges = plan['dependencyEdges'];
    if (rawEdges is! List) return;
    for (final raw in rawEdges) {
      if (raw is! Map || raw['to'] != skillId || raw['reason'] != 'artifact') {
        continue;
      }
      final artifact = raw['artifact'];
      if (artifact is! String) {
        throw const SkillExecutionException('invalid_dependency_artifact_edge');
      }
      final expectedHost = predecessorArtifacts[artifact];
      final suppliedPath = inputFiles[artifact];
      if (expectedHost == null || suppliedPath == null) {
        throw SkillExecutionException('dependency_artifact_not_verified_or_supplied:$artifact');
      }
      final resolved = await context.paths.resolveReal(
        suppliedPath,
        cwd: context.cwd,
      );
      if (resolved.zone != WorkspaceZone.workspace ||
          p.normalize(resolved.hostPath) != p.normalize(expectedHost)) {
        throw SkillExecutionException('dependency_artifact_path_mismatch:$artifact');
      }
    }
  }

  Future<void> _recordSuccessfulStage({
    required String planDigest,
    required String workspaceId,
    required Map<String, Object?> plan,
    required String skillId,
    required String sourceDigest,
    required String runId,
    required List<Map<String, Object?>> outputs,
  }) async {
    final previous = _ledgerWriteTail;
    final release = Completer<void>();
    _ledgerWriteTail = release.future;
    await previous;
    try {
      await _recordSuccessfulStageUnlocked(
        planDigest: planDigest,
        workspaceId: workspaceId,
        plan: plan,
        skillId: skillId,
        sourceDigest: sourceDigest,
        runId: runId,
        outputs: outputs,
      );
    } finally {
      release.complete();
    }
  }

  Future<void> _recordSuccessfulStageUnlocked({
    required String planDigest,
    required String workspaceId,
    required Map<String, Object?> plan,
    required String skillId,
    required String sourceDigest,
    required String runId,
    required List<Map<String, Object?>> outputs,
  }) async {
    final row = await ledgerStore.get(
      ExtensionEntityStore.kindSkillExecutionLedger,
      planDigest,
    );
    final records = row?.payload['records'] is Map
        ? Map<String, dynamic>.from(row!.payload['records'] as Map)
        : <String, dynamic>{};
    final stagesRaw = plan['executionStages'];
    if (stagesRaw is! List) {
      throw const SkillExecutionException('invalid_composition_stages');
    }
    final stages = <List<String>>[];
    for (final raw in stagesRaw) {
      if (raw is! Map || raw['skillIds'] is! List) {
        throw const SkillExecutionException('invalid_composition_stage');
      }
      stages.add((raw['skillIds'] as List).whereType<String>().toList());
    }
    final index = stages.indexWhere((ids) => ids.contains(skillId));
    if (index < 0) throw const SkillExecutionException('skill_not_selected_by_composition');
    final positions = <String, int>{
      for (var i = 0; i < stages.length; i++)
        for (final id in stages[i]) id: i,
    };
    records.removeWhere((id, _) =>
        id != skillId && (positions[id] ?? -1) > index);
    records[skillId] = {
      'status': 'succeeded',
      'runId': runId,
      'sourceDigest': sourceDigest,
      'outputs': outputs,
      'completedAt': DateTime.now().toUtc().toIso8601String(),
    };
    await ledgerStore.upsert(
      ExtensionEntityStore.kindSkillExecutionLedger,
      planDigest,
      {
        'schemaVersion': 1,
        'workspaceId': workspaceId,
        'planDigest': planDigest,
        'records': records,
      },
    );
  }

  static Map<String, Object?> _validateCompositionStage(
    Map<String, Object?> plan,
    String skillId,
    Set<String> completedSkillIds,
  ) {
    if (!const {'ready', 'ready_with_warnings'}.contains(plan['status'])) {
      throw const SkillExecutionException('composition_plan_not_ready');
    }
    final stagesRaw = plan['executionStages'];
    if (stagesRaw is! List || stagesRaw.isEmpty || stagesRaw.length > 64) {
      throw const SkillExecutionException('invalid_composition_stages');
    }
    final stages = <List<String>>[];
    for (final rawStage in stagesRaw) {
      if (rawStage is! Map || rawStage['skillIds'] is! List) {
        throw const SkillExecutionException('invalid_composition_stage');
      }
      final ids = (rawStage['skillIds'] as List).whereType<String>().toList();
      if (ids.isEmpty || ids.length > 64) {
        throw const SkillExecutionException('invalid_composition_stage');
      }
      stages.add(ids);
    }
    final selected = stages.expand((ids) => ids).toSet();
    if (selected.length != stages.fold<int>(0, (sum, ids) => sum + ids.length) ||
        !selected.contains(skillId)) {
      throw const SkillExecutionException('skill_not_selected_by_composition');
    }
    if (completedSkillIds.any((id) => !selected.contains(id)) ||
        completedSkillIds.contains(skillId)) {
      throw const SkillExecutionException('invalid_completed_skill_ids');
    }
    final stageIndex = stages.indexWhere((ids) => ids.contains(skillId));
    final requiredEarlier = stages.take(stageIndex).expand((ids) => ids).toSet();
    if (!completedSkillIds.containsAll(requiredEarlier)) {
      throw const SkillExecutionException('composition_predecessor_stage_incomplete');
    }
    final contracts = plan['artifactContracts'];
    if (contracts is! Map) {
      throw const SkillExecutionException('composition_artifact_contract_missing');
    }
    return Map<String, Object?>.from(contracts);
  }

  static Map<String, Object?> _parseManifest({
    required Map<String, Object?> compositionPlan,
    required Map<String, Object?> importManifest,
    required String skillId,
  }) {
    if (importManifest['skillId'] != skillId ||
        importManifest['completeness'] != 'complete' ||
        importManifest['sourceDigest'] is! String ||
        (importManifest['sourceDigest'] as String).isEmpty) {
      throw const SkillExecutionException('skill_import_manifest_incomplete_or_mismatched');
    }
    final pins = compositionPlan['pinnedDigests'];
    final pin = pins is Map ? pins[skillId]?.toString() : null;
    if (pin != null && pin.trim().isEmpty) {
      throw const SkillExecutionException('invalid_pinned_skill_digest');
    }
    return importManifest;
  }

  static Map<String, Map<String, Object?>> _readSkillFileEntries(
    Map<String, Object?> manifest,
  ) {
    final raw = manifest['files'];
    if (raw is! List || raw.isEmpty || raw.length > maxManifestEntries) {
      throw const SkillExecutionException('invalid_skill_import_manifest_files');
    }
    final result = <String, Map<String, Object?>>{};
    for (final item in raw) {
      if (item is! Map || item['scope'] != 'skill') continue;
      final path = item['path']?.toString() ?? '';
      final safe = _safeRelativePath(path);
      final digest = item['sha256']?.toString() ?? '';
      final size = item['sizeBytes'];
      if (safe == null ||
          size is! num ||
          size < 0 ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(digest)) {
        throw const SkillExecutionException('invalid_skill_import_manifest_entry');
      }
      if (result.containsKey(safe)) {
        throw const SkillExecutionException('duplicate_skill_import_manifest_path');
      }
      result[safe] = Map<String, Object?>.from(item);
    }
    if (result.isEmpty) {
      throw const SkillExecutionException('skill_import_manifest_has_no_files');
    }
    return result;
  }

  static Map<String, Object?>? _findLocalScriptCapability(
    Map<String, Object?> manifest,
    String entryPoint,
  ) {
    final raw = manifest['capabilities'];
    if (raw is! List) return null;
    for (final item in raw) {
      if (item is! Map || item['kind'] != 'local_script') continue;
      final paths = item['entryPoints'];
      if (paths is List && paths.whereType<String>().contains(entryPoint)) {
        return Map<String, Object?>.from(item);
      }
    }
    return null;
  }

  static String _guardedSkillPath(String? profilePath) {
    final entries = <String>[
      '/usr/local/bin',
      '/usr/local/sbin',
      ...(profilePath ?? '/usr/bin:/bin').split(':'),
    ].map((value) => value.trim()).where((value) => value.isNotEmpty);
    final seen = <String>{};
    return entries.where(seen.add).join(':');
  }

  static String? _interpreterFor(String path) {
    final extension = p.posix.extension(path).toLowerCase();
    return switch (extension) {
      '.py' => 'python3',
      '.sh' || '.bash' => 'bash',
      '.js' || '.mjs' || '.cjs' => 'node',
      _ => null,
    };
  }

  static void _validateProfileInterpreter(
    RuntimeProfile profile,
    String interpreter,
  ) {
    final required = switch (interpreter) {
      'python3' => RuntimeProfileEcosystem.python,
      'node' => RuntimeProfileEcosystem.node,
      'bash' => RuntimeProfileEcosystem.shell,
      _ => throw const SkillExecutionException('unsupported_script_interpreter'),
    };
    if (!profile.ecosystems.contains(required)) {
      throw SkillExecutionException('runtime_profile_missing_${required.name}_ecosystem');
    }
  }

  static void _validateArtifactContracts({
    required Map<String, Object?> stage,
    required String skillId,
    required Map<String, Object?> inputs,
    required Map<String, String> inputFiles,
    required Map<String, String> expectedOutputs,
  }) {
    final inputContracts = stage['inputs'];
    final outputContracts = stage['outputs'];
    final rawInputs = inputContracts is Map ? inputContracts[skillId] : null;
    final rawOutputs = outputContracts is Map ? outputContracts[skillId] : null;
    final requiredInputs = rawInputs is List
        ? rawInputs.whereType<String>().toSet()
        : <String>{};
    final requiredOutputs = rawOutputs is List
        ? rawOutputs.whereType<String>().toSet()
        : <String>{};
    final providedInputs = {...inputs.keys, ...inputFiles.keys};
    if (!providedInputs.containsAll(requiredInputs)) {
      throw SkillExecutionException(
        'missing_skill_artifact_inputs:${(requiredInputs.difference(providedInputs).toList()..sort()).join(',')}',
      );
    }
    if (!expectedOutputs.keys.toSet().containsAll(requiredOutputs)) {
      throw SkillExecutionException(
        'missing_expected_skill_outputs:${(requiredOutputs.difference(expectedOutputs.keys.toSet()).toList()..sort()).join(',')}',
      );
    }
    if (expectedOutputs.keys.any((key) => !requiredOutputs.contains(key))) {
      throw const SkillExecutionException('unexpected_skill_output_contract');
    }
  }

  Future<Directory> _createRunDirectory(
    WorkspaceToolContext context,
    String runId,
  ) async {
    final workspaceRoot = Directory(context.paths.workspaceHostRoot);
    if (await FileSystemEntity.type(workspaceRoot.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw const SkillExecutionException('workspace_root_missing_or_linked');
    }
    final canonicalWorkspace = await workspaceRoot.resolveSymbolicLinks();
    var current = canonicalWorkspace;
    for (final segment in ['.kelivo', 'skill-execution']) {
      final nextPath = p.join(current, segment);
      final type = await FileSystemEntity.type(nextPath, followLinks: false);
      if (type == FileSystemEntityType.link) {
        throw const SkillExecutionException('skill_run_staging_symlink_not_allowed');
      }
      if (type == FileSystemEntityType.notFound) {
        await Directory(nextPath).create();
      } else if (type != FileSystemEntityType.directory) {
        throw const SkillExecutionException('skill_run_staging_parent_not_directory');
      }
      final next = Directory(nextPath);
      final canonicalNext = await next.resolveSymbolicLinks();
      if (!p.isWithin(canonicalWorkspace, canonicalNext)) {
        throw const SkillExecutionException('skill_run_staging_path_escape');
      }
      current = canonicalNext;
    }
    final runPath = p.join(current, runId);
    if (await FileSystemEntity.type(runPath, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw const SkillExecutionException('skill_run_staging_collision');
    }
    await Directory(runPath).create();
    final canonicalRun = await Directory(runPath).resolveSymbolicLinks();
    if (!p.isWithin(canonicalWorkspace, canonicalRun)) {
      throw const SkillExecutionException('skill_run_staging_path_escape');
    }
    return Directory(canonicalRun);
  }

  Future<int> _stageSkillSnapshot({
    required Directory skillRoot,
    required Directory trustedSkillsRoot,
    required Directory destinationRoot,
    required Map<String, Map<String, Object?>> fileEntries,
  }) async {
    if (await FileSystemEntity.type(skillRoot.path, followLinks: false) !=
            FileSystemEntityType.directory ||
        await FileSystemEntity.type(trustedSkillsRoot.path, followLinks: false) !=
            FileSystemEntityType.directory) {
      throw const SkillExecutionException('installed_skill_directory_missing_or_linked');
    }
    final canonicalSkillsRoot = await trustedSkillsRoot.resolveSymbolicLinks();
    final canonicalSkillRoot = await skillRoot.resolveSymbolicLinks();
    if (!p.isWithin(canonicalSkillsRoot, canonicalSkillRoot)) {
      throw const SkillExecutionException('installed_skill_directory_outside_skills_root');
    }
    var totalBytes = 0;
    for (final entry in fileEntries.entries) {
      final relative = entry.key;
      final expectedSize = (entry.value['sizeBytes'] as num).toInt();
      if (expectedSize > maxSingleFileBytes) {
        throw SkillExecutionException('skill_snapshot_file_limit:$relative');
      }
      totalBytes += expectedSize;
      if (totalBytes > maxSnapshotBytes) {
        throw const SkillExecutionException('skill_snapshot_size_limit');
      }
      final source = await _resolveRegularFile(skillRoot, relative);
      final resolved = await source.resolveSymbolicLinks();
      if (!p.isWithin(canonicalSkillRoot, resolved)) {
        throw SkillExecutionException('skill_file_path_escape:$relative');
      }
      final actualSize = await source.length();
      if (actualSize != expectedSize) {
        throw SkillExecutionException('skill_file_size_changed:$relative');
      }
      final digest = await _sha256File(source);
      if (digest != entry.value['sha256']) {
        throw SkillExecutionException('skill_file_digest_mismatch:$relative');
      }
      final destinationPath = p.joinAll([
        destinationRoot.path,
        ...p.posix.split(relative),
      ]);
      final destination = File(destinationPath);
      await destination.parent.create(recursive: true);
      await source.copy(destination.path);
      if (await _sha256File(destination) != digest) {
        throw SkillExecutionException('skill_staging_digest_mismatch:$relative');
      }
    }
    return totalBytes;
  }

  Future<void> _validateOutputTree({
    required Directory outputDirectory,
    required Set<String> expectedPaths,
  }) async {
    if (expectedPaths.length > 32 ||
        expectedPaths.any((path) => _safeRelativePath(path) == null)) {
      throw const SkillExecutionException('invalid_expected_skill_output_paths');
    }
    var entries = 0;
    var totalBytes = 0;
    await for (final entity in outputDirectory.list(
      recursive: true,
      followLinks: false,
    )) {
      entries++;
      if (entries > maxOutputTreeEntries) {
        throw const SkillExecutionException('skill_output_tree_entry_limit');
      }
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (type == FileSystemEntityType.link) {
        throw const SkillExecutionException('skill_output_symlink_not_allowed');
      }
      if (type == FileSystemEntityType.directory) continue;
      if (type != FileSystemEntityType.file) {
        throw const SkillExecutionException('skill_output_non_regular_entry');
      }
      final relative = p.relative(entity.path, from: outputDirectory.path)
          .replaceAll('\\', '/');
      final safe = _safeRelativePath(relative);
      if (safe == null || !expectedPaths.contains(safe)) {
        throw SkillExecutionException('undeclared_skill_output_file:$relative');
      }
      final size = await File(entity.path).length();
      if (size > maxOutputFileBytes) {
        throw SkillExecutionException('skill_output_too_large:$safe');
      }
      totalBytes += size;
      if (totalBytes > maxTotalOutputBytes) {
        throw const SkillExecutionException('skill_total_output_size_limit');
      }
    }
  }

  Future<Map<String, String>> _stageInputFiles({
    required WorkspaceToolContext context,
    required Directory inputDirectory,
    required Map<String, String> inputFiles,
  }) async {
    final staged = <String, String>{};
    var totalInputBytes = 0;
    for (final entry in inputFiles.entries) {
      final artifact = entry.key;
      if (!_safeArtifactName(artifact)) {
        throw const SkillExecutionException('invalid_input_artifact_name');
      }
      final resolved = await context.paths.resolveReal(
        entry.value,
        cwd: context.cwd,
      );
      if (resolved.zone != WorkspaceZone.workspace) {
        throw const SkillExecutionException('skill_input_file_outside_workspace');
      }
      final source = File(resolved.hostPath);
      if (await FileSystemEntity.type(source.path, followLinks: false) !=
          FileSystemEntityType.file) {
        throw SkillExecutionException('skill_input_file_not_regular:$artifact');
      }
      final size = await source.length();
      totalInputBytes += size;
      if (totalInputBytes > maxTotalInputFileBytes) {
        throw const SkillExecutionException('skill_total_input_file_size_limit');
      }
      if (size > maxOutputFileBytes) {
        throw SkillExecutionException('skill_input_file_too_large:$artifact');
      }
      final name = '${_safeFileStem(artifact)}_${p.basename(source.path)}';
      final destination = File(p.join(inputDirectory.path, name));
      await source.copy(destination.path);
      final guestPath = '$runGuestRoot/io/input/$name';
      staged[artifact] = guestPath;
    }
    return staged;
  }

  static Future<File> _resolveRegularFile(Directory root, String relative) async {
    final safe = _safeRelativePath(relative);
    if (safe == null) {
      throw const SkillExecutionException('unsafe_relative_file_path');
    }
    final rootReal = await root.resolveSymbolicLinks();
    var current = root.path;
    final parts = p.posix.split(safe);
    for (var index = 0; index < parts.length; index++) {
      current = p.join(current, parts[index]);
      final type = await FileSystemEntity.type(current, followLinks: false);
      if (type == FileSystemEntityType.link) {
        throw SkillExecutionException('symbolic_link_not_allowed:$safe');
      }
      final isLast = index == parts.length - 1;
      if (isLast && type != FileSystemEntityType.file) {
        throw SkillExecutionException('skill_file_not_regular:$safe');
      }
      if (!isLast && type != FileSystemEntityType.directory) {
        throw SkillExecutionException('skill_parent_not_directory:$safe');
      }
    }
    final file = File(current);
    final canonical = await file.resolveSymbolicLinks();
    if (!p.isWithin(rootReal, canonical)) {
      throw SkillExecutionException('relative_file_path_escape:$safe');
    }
    return File(canonical);
  }

  static String _buildInterpreterCommand({
    required String interpreter,
    required String scriptPath,
    required List<String> arguments,
  }) {
    final invocation = switch (interpreter) {
      'python3' => 'python3 ${_shellQuote(scriptPath)}',
      'bash' => 'bash --noprofile --norc ${_shellQuote(scriptPath)}',
      'node' => 'node ${_shellQuote(scriptPath)}',
      _ => throw const SkillExecutionException('unsupported_script_interpreter'),
    };
    return '$invocation${arguments.isEmpty ? '' : ' ${arguments.map(_shellQuote).join(' ')}'}';
  }

  static String _shellQuote(String value) => "'${value.replaceAll("'", "'\\''")}'";

  static String? _safeRelativePath(String value) {
    if (value.isEmpty ||
        value.startsWith('/') ||
        value.startsWith('\\') ||
        value.contains('\\') ||
        value.contains('\u0000') ||
        value.contains(':')) {
      return null;
    }
    final parts = value.split('/');
    if (parts.any((part) => part.isEmpty || part == '.' || part == '..')) {
      return null;
    }
    if (p.posix.normalize(value) != value) return null;
    return value;
  }

  static bool _safeArtifactName(String value) =>
      value.length <= 100 &&
      RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(value);

  static String _safeFileStem(String value) => value.replaceAll(
    RegExp(r'[^A-Za-z0-9._-]+'),
    '_',
  ).substring(0, value.length.clamp(1, 64));

  static void _validateSkillIdentity(Skill skill) {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$')
        .hasMatch(skill.record.id)) {
      throw const SkillExecutionException('invalid_skill_id');
    }
  }

  static bool _appendBounded(BytesBuilder builder, Uint8List bytes, int limit) {
    final remaining = limit - builder.length;
    if (remaining <= 0) return bytes.isNotEmpty;
    final accepted = bytes.length <= remaining ? bytes : bytes.sublist(0, remaining);
    builder.add(accepted);
    return accepted.length < bytes.length;
  }

  static List<String> _decodeBounded(List<int> bytes) => [
    utf8.decode(bytes, allowMalformed: true),
  ];

  static Future<String> _sha256File(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  static Future<String> _validatedMediaType(File file, String path) async {
    final extensionType = _mediaType(path);
    final header = await file.openRead(0, 16).fold<List<int>>(
      <int>[],
      (bytes, chunk) => bytes..addAll(chunk),
    );
    bool startsWith(List<int> signature) =>
        header.length >= signature.length &&
        List<int>.generate(signature.length, (index) => header[index])
            .join(',') == signature.join(',');
    if (extensionType == 'image/png' &&
        !startsWith([137, 80, 78, 71, 13, 10, 26, 10])) {
      throw const SkillExecutionException('skill_output_content_signature_mismatch');
    }
    if (extensionType == 'image/jpeg' && !startsWith([255, 216, 255])) {
      throw const SkillExecutionException('skill_output_content_signature_mismatch');
    }
    if (extensionType == 'image/webp' &&
        (header.length < 12 ||
            String.fromCharCodes(header.sublist(0, 4)) != 'RIFF' ||
            String.fromCharCodes(header.sublist(8, 12)) != 'WEBP')) {
      throw const SkillExecutionException('skill_output_content_signature_mismatch');
    }
    if (extensionType == 'video/mp4' &&
        (header.length < 8 || String.fromCharCodes(header.sublist(4, 8)) != 'ftyp')) {
      throw const SkillExecutionException('skill_output_content_signature_mismatch');
    }
    if (extensionType == 'audio/mpeg' &&
        !startsWith([73, 68, 51]) &&
        !(header.length >= 2 && header[0] == 255 && (header[1] & 224) == 224)) {
      throw const SkillExecutionException('skill_output_content_signature_mismatch');
    }
    if (extensionType == 'audio/wav' &&
        (header.length < 12 ||
            String.fromCharCodes(header.sublist(0, 4)) != 'RIFF' ||
            String.fromCharCodes(header.sublist(8, 12)) != 'WAVE')) {
      throw const SkillExecutionException('skill_output_content_signature_mismatch');
    }
    if (extensionType == 'application/pdf' && !startsWith([37, 80, 68, 70, 45])) {
      throw const SkillExecutionException('skill_output_content_signature_mismatch');
    }
    if (extensionType == 'application/zip' &&
        !startsWith([80, 75, 3, 4]) && !startsWith([80, 75, 5, 6]) &&
        !startsWith([80, 75, 7, 8])) {
      throw const SkillExecutionException('skill_output_content_signature_mismatch');
    }
    if (extensionType == 'application/json') {
      final length = await file.length();
      if (length > 16 * 1024 * 1024) {
        throw const SkillExecutionException('skill_json_output_validation_limit');
      }
      try {
        jsonDecode(await file.readAsString());
      } catch (_) {
        throw const SkillExecutionException('skill_output_invalid_json');
      }
    }
    if (extensionType == 'text/plain' || extensionType == 'text/markdown' ||
        extensionType == 'application/yaml') {
      try {
        await file.openRead().transform(utf8.decoder).drain<void>();
      } on FormatException {
        throw const SkillExecutionException('skill_output_invalid_utf8');
      }
    }
    return extensionType;
  }

  static String _mediaType(String path) {
    return switch (p.posix.extension(path).toLowerCase()) {
      '.json' => 'application/json',
      '.txt' || '.log' || '.py' || '.sh' || '.bash' || '.js' || '.mjs' || '.cjs' => 'text/plain',
      '.md' => 'text/markdown',
      '.yaml' || '.yml' => 'application/yaml',
      '.png' => 'image/png',
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.webp' => 'image/webp',
      '.mp4' => 'video/mp4',
      '.mp3' => 'audio/mpeg',
      '.wav' => 'audio/wav',
      '.pdf' => 'application/pdf',
      '.zip' => 'application/zip',
      _ => 'application/octet-stream',
    };
  }

  static Map<String, Object?> _executionReport({
    required String status,
    required String runId,
    required Skill skill,
    required String entryPoint,
    required String interpreter,
    required RuntimeProfile profile,
    required int processExitCode,
    required List<String> stdout,
    required List<String> stderr,
    required Duration duration,
    required String sourceDigest,
    required List<Map<String, Object?>> permissionReview,
    required List<String> arguments,
    required List<Map<String, Object?>> outputs,
    required int copiedBytes,
    required String? outputDirectoryRelativePath,
    required bool captureTruncated,
    required Set<String> redactionValues,
  }) => <String, Object?>{
    'schemaVersion': 1,
    'tool': 'skill_execute',
    'runId': runId,
    'skillId': skill.record.id,
    'skillName': skill.name,
    'entryPoint': entryPoint,
    // Do not echo raw argv into model-visible reports: command-line values
    // can contain API keys, passwords, or private user data. A digest keeps
    // the invocation auditable without disclosing those values.
    'arguments': {
      'count': arguments.length,
      'sha256': sha256.convert(utf8.encode(jsonEncode(arguments))).toString(),
      'valuesOmitted': true,
    },
    'interpreter': interpreter,
    'runtimeProfile': {
      'id': profile.id,
      'scope': profile.scope.name,
      'ownerId': profile.ownerId,
      'ecosystems': profile.ecosystems.map((item) => item.name).toList()..sort(),
    },
    'sourceDigest': sourceDigest,
    'status': status,
    'exitCode': processExitCode,
    'stdout': SkillExecutionSecurityPolicy.redactOutput(
      stdout.join(),
      knownSensitiveValues: redactionValues,
    ),
    'stderr': SkillExecutionSecurityPolicy.redactOutput(
      stderr.join(),
      knownSensitiveValues: redactionValues,
    ),
    'capturedOutputTruncated': captureTruncated,
    'outputDirectory': outputDirectoryRelativePath,
    'outputs': outputs,
    'snapshotBytes': copiedBytes,
    'durationMs': duration.inMilliseconds,
    'permissionReview': permissionReview,
    'runtimeBoundary': SkillExecutionSecurityPolicy.executionBoundary(),
  };
}

final class _VerifiedSkillStages {
  const _VerifiedSkillStages({
    required this.completedSkillIds,
    required this.artifactHostPaths,
  });

  factory _VerifiedSkillStages.empty() => const _VerifiedSkillStages(
    completedSkillIds: <String>{},
    artifactHostPaths: <String, String>{},
  );

  final Set<String> completedSkillIds;
  final Map<String, String> artifactHostPaths;
}

final class SkillExecutionException implements Exception {
  const SkillExecutionException(this.code);
  final String code;
  @override
  String toString() => code;
}
