import 'package:path/path.dart' as p;

enum RuntimeProfileScope { project, extension, task }

enum RuntimeProfileEcosystem { shell, python, node }

enum RuntimeProfileStatus { provisioning, ready, failed, disabled }

enum RuntimeProcessStatus { running, succeeded, failed, cancelled, timedOut, interrupted }

class RuntimeResourceLimits {
  const RuntimeResourceLimits({
    this.maxDurationSeconds = 900,
    this.maxCpuSeconds = 900,
    this.maxConcurrentRuns = 2,
    this.maxProcesses = 64,
    this.maxMemoryMegabytes = 2048,
    this.maxTempMegabytes = 512,
    this.maxOutputMegabytes = 1024,
    this.maxFileMegabytes = 256,
  });

  /// Wall-clock timeout enforced by the runtime process API.
  final int maxDurationSeconds;
  /// Best-effort RLIMIT_CPU ceiling inherited by child processes in PRoot.
  final int maxCpuSeconds;
  final int maxConcurrentRuns;
  final int maxProcesses;
  /// Best-effort virtual-memory ceiling inside the PRoot shell (not a RAM quota).
  final int maxMemoryMegabytes;
  final int maxTempMegabytes;
  /// Post-run output directory budget. The current PRoot runner verifies this
  /// after the process exits; it is not a live filesystem quota.
  final int maxOutputMegabytes;
  final int maxFileMegabytes;

  RuntimeResourceLimits normalized() => RuntimeResourceLimits(
    maxDurationSeconds: maxDurationSeconds.clamp(1, 3600).toInt(),
    maxCpuSeconds: maxCpuSeconds.clamp(1, 3600).toInt(),
    maxConcurrentRuns: maxConcurrentRuns.clamp(1, 4).toInt(),
    maxProcesses: maxProcesses.clamp(8, 256).toInt(),
    maxMemoryMegabytes: maxMemoryMegabytes.clamp(128, 8192).toInt(),
    maxTempMegabytes: maxTempMegabytes.clamp(16, 4096).toInt(),
    maxOutputMegabytes: maxOutputMegabytes.clamp(1, 8192).toInt(),
    maxFileMegabytes: maxFileMegabytes.clamp(1, 2048).toInt(),
  );

  Map<String, Object?> toJson() => {
    'maxDurationSeconds': normalized().maxDurationSeconds,
    'maxCpuSeconds': normalized().maxCpuSeconds,
    'maxConcurrentRuns': normalized().maxConcurrentRuns,
    'maxProcesses': normalized().maxProcesses,
    'maxMemoryMegabytes': normalized().maxMemoryMegabytes,
    'maxTempMegabytes': normalized().maxTempMegabytes,
    'maxOutputMegabytes': normalized().maxOutputMegabytes,
    'maxFileMegabytes': normalized().maxFileMegabytes,
  };

  factory RuntimeResourceLimits.fromJson(Object? value) {
    if (value is! Map) return const RuntimeResourceLimits();
    int read(String key, int fallback) =>
        value[key] is num ? (value[key] as num).toInt() : fallback;
    return RuntimeResourceLimits(
      maxDurationSeconds: read('maxDurationSeconds', 900),
      maxCpuSeconds: read('maxCpuSeconds', 900),
      maxConcurrentRuns: read('maxConcurrentRuns', 2),
      maxProcesses: read('maxProcesses', 64),
      maxMemoryMegabytes: read('maxMemoryMegabytes', 2048),
      maxTempMegabytes: read('maxTempMegabytes', 512),
      maxOutputMegabytes: read('maxOutputMegabytes', 1024),
      maxFileMegabytes: read('maxFileMegabytes', 256),
    ).normalized();
  }
}

class RuntimeProfile {
  const RuntimeProfile({
    required this.id,
    required this.name,
    required this.scope,
    required this.ownerId,
    required this.ecosystems,
    required this.createdAt,
    required this.updatedAt,
    this.status = RuntimeProfileStatus.provisioning,
    this.environment = const {},
    this.limits = const RuntimeResourceLimits(),
    this.shareBaseTools = true,
    this.lastError,
  });

  final String id;
  final String name;
  final RuntimeProfileScope scope;
  /// Workspace ID for project profiles, Skill/extension ID for extension
  /// profiles, and task ID for task profiles.
  final String ownerId;
  final Set<RuntimeProfileEcosystem> ecosystems;
  final Map<String, String> environment;
  final RuntimeResourceLimits limits;
  final bool shareBaseTools;
  final RuntimeProfileStatus status;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;

  RuntimeProfile copyWith({
    String? name,
    Set<RuntimeProfileEcosystem>? ecosystems,
    Map<String, String>? environment,
    RuntimeResourceLimits? limits,
    bool? shareBaseTools,
    RuntimeProfileStatus? status,
    String? lastError,
    bool clearLastError = false,
    DateTime? updatedAt,
  }) => RuntimeProfile(
    id: id,
    name: name ?? this.name,
    scope: scope,
    ownerId: ownerId,
    ecosystems: ecosystems ?? this.ecosystems,
    environment: environment ?? this.environment,
    limits: limits ?? this.limits,
    shareBaseTools: shareBaseTools ?? this.shareBaseTools,
    status: status ?? this.status,
    lastError: clearLastError ? null : (lastError ?? this.lastError),
    createdAt: createdAt,
    updatedAt: updatedAt ?? DateTime.now().toUtc(),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'scope': scope.name,
    'ownerId': ownerId,
    'ecosystems': ecosystems.map((value) => value.name).toList()..sort(),
    'environment': environment,
    'limits': limits.toJson(),
    'shareBaseTools': shareBaseTools,
    'status': status.name,
    'lastError': lastError,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory RuntimeProfile.fromJson(Map<String, dynamic> json) {
    T readEnum<T extends Enum>(List<T> values, Object? value, T fallback) =>
        values.where((item) => item.name == value).firstOrNull ?? fallback;
    final rawEnvironment = json['environment'];
    final environment = <String, String>{};
    if (rawEnvironment is Map) {
      for (final entry in rawEnvironment.entries) {
        if (entry.key is String && entry.value is String) {
          environment[entry.key as String] = entry.value as String;
        }
      }
    }
    final rawEcosystems = json['ecosystems'];
    final ecosystems = <RuntimeProfileEcosystem>{};
    if (rawEcosystems is List) {
      for (final raw in rawEcosystems) {
        final match = RuntimeProfileEcosystem.values
            .where((item) => item.name == raw)
            .firstOrNull;
        if (match != null) ecosystems.add(match);
      }
    }
    return RuntimeProfile(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Runtime profile',
      scope: readEnum(RuntimeProfileScope.values, json['scope'], RuntimeProfileScope.project),
      ownerId: json['ownerId'] as String,
      ecosystems: ecosystems,
      environment: environment,
      limits: RuntimeResourceLimits.fromJson(json['limits']),
      shareBaseTools: json['shareBaseTools'] as bool? ?? true,
      status: readEnum(RuntimeProfileStatus.values, json['status'], RuntimeProfileStatus.failed),
      lastError: json['lastError'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now().toUtc(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now().toUtc(),
    );
  }
}

class RuntimeProcessRecord {
  const RuntimeProcessRecord({
    required this.id,
    required this.profileId,
    required this.ownerId,
    required this.runId,
    required this.commandLabel,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.exitCode,
    this.error,
    this.resumeHint,
    this.sessionId = '',
  });

  final String id;
  final String profileId;
  final String ownerId;
  final String runId;
  final String commandLabel;
  final RuntimeProcessStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int? exitCode;
  final String? error;
  final String? resumeHint;
  /// Identifies the current app process. A new app process marks older
  /// in-flight entries interrupted, while additional service instances in
  /// the same process must leave live runs untouched.
  final String sessionId;

  RuntimeProcessRecord copyWith({
    RuntimeProcessStatus? status,
    DateTime? completedAt,
    int? exitCode,
    String? error,
    String? resumeHint,
  }) => RuntimeProcessRecord(
    id: id,
    profileId: profileId,
    ownerId: ownerId,
    runId: runId,
    commandLabel: commandLabel,
    status: status ?? this.status,
    startedAt: startedAt,
    completedAt: completedAt ?? this.completedAt,
    exitCode: exitCode ?? this.exitCode,
    error: error ?? this.error,
    resumeHint: resumeHint ?? this.resumeHint,
    sessionId: sessionId,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'profileId': profileId,
    'ownerId': ownerId,
    'runId': runId,
    'commandLabel': commandLabel,
    'status': status.name,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'completedAt': completedAt?.toUtc().toIso8601String(),
    'exitCode': exitCode,
    'error': error,
    'resumeHint': resumeHint,
    'sessionId': sessionId,
  };

  factory RuntimeProcessRecord.fromJson(Map<String, dynamic> json) {
    final status = RuntimeProcessStatus.values
        .where((item) => item.name == json['status'])
        .firstOrNull ?? RuntimeProcessStatus.interrupted;
    return RuntimeProcessRecord(
      id: json['id'] as String,
      profileId: json['profileId'] as String,
      ownerId: json['ownerId'] as String,
      runId: json['runId'] as String,
      commandLabel: json['commandLabel'] as String? ?? '',
      status: status,
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '') ?? DateTime.now().toUtc(),
      completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
      exitCode: json['exitCode'] is num ? (json['exitCode'] as num).toInt() : null,
      error: json['error'] as String?,
      resumeHint: json['resumeHint'] as String?,
      sessionId: json['sessionId'] as String? ?? '',
    );
  }
}

/// A content-addressed snapshot of the dependency roots owned by one Runtime
/// Profile. It deliberately excludes the shared PRoot system layer, per-run
/// temporary directories, and generated task outputs.
class RuntimeProfileSnapshotRecord {
  const RuntimeProfileSnapshotRecord({
    required this.id,
    required this.profileId,
    required this.ownerId,
    required this.scope,
    required this.archivePath,
    required this.sha256,
    required this.sizeBytes,
    required this.ecosystems,
    required this.createdAt,
    this.label,
  });

  final String id;
  final String profileId;
  final String ownerId;
  final RuntimeProfileScope scope;
  final String archivePath;
  final String sha256;
  final int sizeBytes;
  final Set<RuntimeProfileEcosystem> ecosystems;
  final DateTime createdAt;
  final String? label;

  Map<String, Object?> toJson() => {
    'id': id,
    'profileId': profileId,
    'ownerId': ownerId,
    'scope': scope.name,
    'archivePath': archivePath,
    'sha256': sha256,
    'sizeBytes': sizeBytes,
    'ecosystems': ecosystems.map((item) => item.name).toList()..sort(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    if (label != null) 'label': label,
  };

  factory RuntimeProfileSnapshotRecord.fromJson(Map<String, dynamic> json) {
    final scope = RuntimeProfileScope.values
        .where((item) => item.name == json['scope'])
        .firstOrNull;
    final ecosystems = <RuntimeProfileEcosystem>{};
    final rawEcosystems = json['ecosystems'];
    if (rawEcosystems is List) {
      for (final raw in rawEcosystems) {
        final item = RuntimeProfileEcosystem.values
            .where((candidate) => candidate.name == raw)
            .firstOrNull;
        if (item != null) ecosystems.add(item);
      }
    }
    final digest = json['sha256']?.toString() ?? '';
    final size = json['sizeBytes'];
    final id = json['id']?.toString() ?? '';
    final archivePath = json['archivePath']?.toString() ?? '';
    if (scope == null ||
        !RuntimeProfileValidation.isSafeId(id) ||
        !RuntimeProfileValidation.isSafeId(json['profileId']?.toString() ?? '') ||
        !RuntimeProfileValidation.isSafeId(json['ownerId']?.toString() ?? '') ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(digest) ||
        size is! num || size < 1 ||
        size > 512 * 1024 * 1024 || ecosystems.isEmpty ||
        !p.posix.isAbsolute(archivePath) ||
        p.posix.normalize(archivePath) != archivePath ||
        p.posix.basename(archivePath) != '$id.tar.gz') {
      throw const FormatException('invalid_runtime_profile_snapshot_record');
    }
    return RuntimeProfileSnapshotRecord(
      id: json['id'] as String,
      profileId: json['profileId'] as String,
      ownerId: json['ownerId'] as String,
      scope: scope,
      archivePath: archivePath,
      sha256: digest,
      sizeBytes: size.toInt(),
      ecosystems: ecosystems,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
      label: json['label'] as String?,
    );
  }
}

class RuntimeProfileExecution {
  const RuntimeProfileExecution({
    required this.environment,
    required this.temporaryHostPath,
    required this.temporaryRuntimePath,
    required this.outputRuntimePath,
    required this.timeout,
    required this.commandPrefix,
    required this.profile,
  });

  final RuntimeProfile profile;
  final Map<String, String> environment;
  final String temporaryHostPath;
  final String temporaryRuntimePath;
  /// Persistent per-run output directory; unlike TMPDIR it is not auto-deleted.
  final String outputRuntimePath;
  final Duration timeout;
  final String commandPrefix;

  /// Wraps an invocation so its task temp directory is isolated and cleaned.
  /// Resource limits are best-effort shell limits inside PRoot, not a kernel
  /// security boundary.
  String wrapCommand(String command) {
    final limits = profile.limits.normalized();
    final quotedTemp = _shellQuote(temporaryRuntimePath);
    final quotedOutput = _shellQuote(outputRuntimePath);
    final maxTempKb = limits.maxTempMegabytes * 1024;
    final maxOutputKb = limits.maxOutputMegabytes * 1024;
    return '$commandPrefix'
        '( $command ); '
        '__kelivo_status=${r'$'}?; '
        '__kelivo_tmp_kb=${r'$'}(du -sk $quotedTemp 2>/dev/null | cut -f1); '
        '__kelivo_output_kb=${r'$'}(du -sk $quotedOutput 2>/dev/null | cut -f1); '
        'if [ "${r'$'}{__kelivo_tmp_kb:-0}" -gt $maxTempKb ]; then '
        'echo __KELIVO_TEMP_LIMIT_EXCEEDED__ >&2; __kelivo_status=125; fi; '
        'if [ "${r'$'}{__kelivo_output_kb:-0}" -gt $maxOutputKb ]; then '
        'echo __KELIVO_OUTPUT_LIMIT_EXCEEDED__ >&2; '
        'rm -rf -- $quotedOutput; __kelivo_status=125; fi; '
        'rm -rf -- $quotedTemp; exit "${r'$'}__kelivo_status"';
  }

  static String _shellQuote(String value) =>
      "'${value.replaceAll("'", "'\\''")}'";
}

abstract final class RuntimeProfileValidation {
  static bool isSafeId(String value) =>
      RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$').hasMatch(value);

  static String? validateEnvironment(Map<String, String> values) {
    if (values.length > 32) return 'too_many_environment_variables_max_32';
    for (final entry in values.entries) {
      final key = entry.key;
      final value = entry.value;
      if (!RegExp(r'^[A-Z_][A-Z0-9_]{0,63}$').hasMatch(key)) {
        return 'invalid_environment_key:$key';
      }
      if (RegExp(r'(TOKEN|PASSWORD|SECRET|API_KEY|CREDENTIAL|AUTH)', caseSensitive: false).hasMatch(key)) {
        return 'use_secure_secret_store_for:$key';
      }
      if ({'PATH', 'HOME', 'TMP', 'TMPDIR', 'TEMP', 'VIRTUAL_ENV', 'PYTHONPATH', 'PYTHONHOME', 'NODE_PATH', 'NODE_OPTIONS', 'KELIVO_TASK_OUTPUT_DIR', 'LD_PRELOAD', 'LD_LIBRARY_PATH', 'BASH_ENV', 'ENV', 'IFS'}.contains(key)) {
        return 'reserved_environment_key:$key';
      }
      if (value.length > 4096 || value.contains('\u0000') || value.contains('\n') || value.contains('\r')) {
        return 'invalid_environment_value:$key';
      }
    }
    return null;
  }
}

String runtimeProfileRoot({
  required RuntimeProfile profile,
  required String workspaceRoot,
  required bool sandboxed,
}) {
  final id = profile.id;
  if (!RuntimeProfileValidation.isSafeId(id) ||
      !RuntimeProfileValidation.isSafeId(profile.ownerId)) {
    throw const FormatException('invalid_runtime_profile_path_id');
  }
  switch (profile.scope) {
    case RuntimeProfileScope.project:
      if (sandboxed) {
        return p.posix.join(workspaceRoot, '.kelivo', 'runtime-profiles', id);
      }
      return p.join(workspaceRoot, '.kelivo', 'runtime-profiles', id);
    case RuntimeProfileScope.extension:
      return '/root/.local/share/kelivo/runtime-profiles/extensions/${profile.ownerId}/$id';
    case RuntimeProfileScope.task:
      return '/root/.local/share/kelivo/runtime-profiles/tasks/${profile.ownerId}/$id';
  }
}
