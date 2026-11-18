/// Defense-in-depth policy for third-party Skill process inputs and reports.
///
/// PRoot is not a security boundary: this policy reduces accidental exposure,
/// but it cannot prevent an approved process from modifying the shared RootFS
/// or using the device network.
abstract final class SkillExecutionSecurityPolicy {
  /// Environment variables synthesized by RuntimeProfileService and required
  /// to resolve the selected interpreter/package roots. Arbitrary profile
  /// variables are deliberately withheld from third-party Skill processes.
  static const Set<String> _runtimeBootstrapEnvironmentKeys = {
    'PATH',
    'VIRTUAL_ENV',
    'PYTHONNOUSERSITE',
    'PIP_REQUIRE_VIRTUALENV',
    'NODE_PATH',
    'npm_config_prefix',
  };

  static Map<String, String> runtimeBootstrapEnvironment(
    Map<String, String> resolvedEnvironment,
  ) => Map.unmodifiable({
    for (final entry in resolvedEnvironment.entries)
      if (_runtimeBootstrapEnvironmentKeys.contains(entry.key))
        entry.key: entry.value,
  });

  /// Exact invocation values are scrubbed from captured output because scripts
  /// sometimes echo argv for debugging. Sensitive JSON values are collected
  /// only when their containing key clearly denotes a credential.
  static Set<String> collectSensitiveValues({
    required Iterable<String> arguments,
    required Map<String, Object?> inputs,
  }) {
    final values = <String>{
      for (final argument in arguments)
        if (argument.length >= 8) argument,
    };
    void visit(Object? value, {required bool sensitive}) {
      if (value is String) {
        if (sensitive && value.isNotEmpty) values.add(value);
      } else if (value is Map) {
        for (final entry in value.entries) {
          final key = entry.key.toString();
          final keyIsSensitive = RegExp(
            r'(secret|token|password|passwd|api.?key|authorization|cookie|credential|private.?key|access.?key)',
            caseSensitive: false,
          ).hasMatch(key);
          visit(entry.value, sensitive: sensitive || keyIsSensitive);
        }
      } else if (value is List) {
        for (final item in value) {
          visit(item, sensitive: sensitive);
        }
      }
    }

    visit(inputs, sensitive: false);
    return Set.unmodifiable(values.where((value) => value.isNotEmpty));
  }

  static String redactOutput(
    String value, {
    Iterable<String> knownSensitiveValues = const <String>[],
  }) {
    var redacted = value;
    final exactValues = knownSensitiveValues.toSet().toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final secret in exactValues) {
      if (secret.isNotEmpty) {
        redacted = redacted.replaceAll(secret, '[REDACTED]');
      }
    }

    final labelledSecrets = RegExp(
      r'''([A-Za-z0-9_.-]*(?:authorization|set-cookie|cookie|api[_-]?key|access[_-]?token|refresh[_-]?token|client[_-]?secret|password|passwd|secret|token)[A-Za-z0-9_.-]*)(["']?\s*[:=]\s*["']?)((?:Bearer\s+)?[^\s,;"']+)''',
      caseSensitive: false,
    );
    return redacted
        .replaceAllMapped(
          labelledSecrets,
          (match) => '${match.group(1)}${match.group(2)}[REDACTED]',
        )
        .replaceAll(
          RegExp(r'\bBearer\s+[A-Za-z0-9._~+/=-]{8,}', caseSensitive: false),
          'Bearer [REDACTED]',
        )
        .replaceAll(
          RegExp(r'\b(?:sk-[A-Za-z0-9_-]{16,}|gh[pousr]_[A-Za-z0-9]{20,})\b'),
          '[REDACTED_TOKEN]',
        );
  }

  /// Build the pending approval payload from counts and identifiers only.
  /// Raw task text, argv, JSON input values and paths are deliberately not
  /// accepted by this API, so they cannot be retained in approval state.
  static Map<String, Object?> approvalSummary({
    required String executionGrantId,
    required String skillId,
    required String entryPoint,
    required String runtimeProfileId,
    required int argumentCount,
    required int inputCount,
    required int inputFileCount,
    required int expectedOutputCount,
    required List<Map<String, Object?>> permissionReview,
    required String workspaceOutputPath,
  }) => {
    'execution_grant_id': executionGrantId,
    'grant_scope': 'single_run',
    'skill_id': skillId,
    'entry_point': entryPoint,
    'runtime_profile_id': runtimeProfileId,
    'argument_count': argumentCount,
    'input_count': inputCount,
    'input_file_count': inputFileCount,
    'expected_output_count': expectedOutputCount,
    'skill_permission_review': permissionReview,
    'execution_boundary': approvalBoundary(
      workspaceOutputPath: workspaceOutputPath,
    ),
  };

  /// Approval copy must make the remaining PRoot risk explicit for every run.
  static Map<String, Object?> approvalBoundary({
    required String workspaceOutputPath,
  }) => {
    'runtime': 'Android PRoot only',
    'workspace': 'The full Workspace, chat and installed Skills trees are not mounted. Separate per-run source, input, output and temporary directories are exposed.',
    'workspaceOutput': workspaceOutputPath,
    'installedSkills': 'The live installed Skills tree is not mounted; an integrity-checked per-run snapshot is used.',
    'credentials': 'No Android host environment, secret-store values, or custom Runtime Profile environment variables are passed to the Skill process. Only interpreter/bootstrap variables are supplied.',
    'sharedRootFs': 'The active PRoot RootFS remains shared and writable by the Skill process. Approved code may modify system files or installed packages and affect later runs; the current Android PRoot backend cannot deny these writes.',
    'network': 'PRoot does not restrict device network access. The Skill process can connect to remote services and package sources; the current backend cannot enforce network deny or host allowlists.',
    'readOnlyStaging': 'Source and input binds request read-only treatment. Android applies per-run common-command guards only; interpreters, shell redirection, direct syscalls, absolute executables and modification of shared guard files can bypass them.',
    'permissionGrant': 'All reviewed permissions are approved together for this single run only. This grant is not stored as a persistent Skill permission.',
    'kernelIsolation': false,
    'explicitRiskAcknowledgementRequired': true,
  };

  static Map<String, Object?> executionBoundary() => {
    'workspaceRootMounted': false,
    'workspaceRunStagingMounted': true,
    'sourceAndInputBindsMarkedReadOnly': true,
    'readOnlyBindEnforcement': 'best_effort_common_command_wrappers',
    'outputAndTemporaryBindsWritable': true,
    'chatMounted': false,
    'installedSkillsMounted': false,
    'externalMountsAttached': false,
    'networkRestricted': false,
    'customProfileEnvironmentPassed': false,
    'credentialEnvironmentPassedToGuest': false,
    'sharedRootFsMountedWritable': true,
    'kernelSandbox': false,
    'note': 'Separate per-run source, input, output and temporary paths are mounted; source/input are marked read-only but only common write commands are guarded. The guest environment is rebuilt with env -i and omits custom profile variables. The active PRoot RootFS remains shared and writable; PRoot does not restrict device network access and is not a kernel sandbox.',
  };
}
