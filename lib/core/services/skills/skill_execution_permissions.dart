import '../extensions/extension_permission_policy.dart';

/// Permission contract for the current local-script Skill execution adapter.
///
/// Grants are deliberately single-run and are issued only after the manual
/// ToolCallPermission approval completes. This is an app-level authorization
/// gate; it does not claim that PRoot can enforce network or RootFS isolation.
abstract final class SkillExecutionPermissionPolicy {
  static const int schemaVersion = 1;
  // A grant is bound to the exact in-memory review list that was created after
  // manual approval. Expando keeps the token out of serializable/model data.
  // The entry is cleared at dispatch so the same grant cannot be replayed.
  static final Expando<String> _singleRunGrantIds = Expando<String>(
    'kelivo.singleRunSkillExecutionGrant',
  );

  /// These are the capabilities the current PRoot local-script adapter
  /// actually exposes. Network and shared RootFS access remain in this set
  /// because the current runtime cannot technically deny either capability.
  static const Set<String> requiredLocalScriptPermissions = <String>{
    'skill.runtime.execute',
    'skill.source.read',
    'skill.input.read',
    'skill.output.write',
    'runtime.proot.execute',
    'runtime.rootfs.write',
    'shell.execute',
    'network.read',
    'network.write',
    'network.package_install',
    'external.services',
  };

  /// Permissions recognized by this local-script adapter. Other known
  /// application permissions (for example Android calendar or location) need
  /// their own native adapter and must not be treated as granted to PRoot code.
  static const Set<String> supportedLocalScriptPermissions = <String>{
    ...requiredLocalScriptPermissions,
  };

  static List<Map<String, Object?>> reviewForSkill(
    Iterable<String> declaredPermissions,
  ) {
    final requested = <String>{
      ...requiredLocalScriptPermissions,
      ...declaredPermissions.map((value) => value.trim()).where((value) => value.isNotEmpty),
    };
    final reviewed = ExtensionPermissionPolicy.review(requested);
    return List<Map<String, Object?>>.unmodifiable([
      for (final item in reviewed)
        <String, Object?>{
          ...item,
          'enforcement': enforcementFor(item['permission']?.toString() ?? ''),
          if (item['recognized'] == true &&
              !supportedLocalScriptPermissions.contains(item['permission']))
            'blockedUntilReviewed': true,
          if (item['recognized'] == true &&
              !supportedLocalScriptPermissions.contains(item['permission']))
            'blockedReason': 'permission_requires_native_adapter',
          'executionGranted': false,
          'grantScope': 'none',
        },
    ]);
  }

  /// Converts a reviewed set into a single-run grant after the user has
  /// explicitly approved the complete execution summary.
  static List<Map<String, Object?>> approveForSingleRun({
    required List<Map<String, Object?>> review,
    required String grantId,
  }) {
    _validateGrantId(grantId);
    if (!isCompleteReview(review)) {
      throw const SkillExecutionPermissionException(
        'skill_permission_review_incomplete',
      );
    }
    final approved = List<Map<String, Object?>>.unmodifiable([
      for (final item in review)
        Map<String, Object?>.unmodifiable({
          ...item,
          'executionGranted': true,
          'grantScope': 'single_run',
          'executionGrantId': grantId,
        }),
    ]);
    _singleRunGrantIds[approved] = grantId;
    return approved;
  }

  static bool isCompleteReview(List<Map<String, Object?>> review) {
    final permissions = review
        .where((item) => item['recognized'] == true &&
            item['blockedUntilReviewed'] != true)
        .map((item) => item['permission']?.toString())
        .whereType<String>()
        .toSet();
    return !review.any((item) =>
            item['recognized'] != true || item['blockedUntilReviewed'] == true) &&
        permissions.containsAll(requiredLocalScriptPermissions);
  }

  /// Verify the in-memory grant immediately before dispatch. The identifier is
  /// created by the app, is shown in the approval record, and is never accepted
  /// from model-provided tool arguments.
  static void validateSingleRunGrant({
    required List<Map<String, Object?>> permissionReview,
    required String grantId,
  }) {
    _validateGrantId(grantId);
    if (!isCompleteReview(permissionReview)) {
      throw const SkillExecutionPermissionException(
        'skill_permission_review_incomplete',
      );
    }
    if (_singleRunGrantIds[permissionReview] != grantId) {
      throw const SkillExecutionPermissionException(
        'skill_permission_grant_missing_or_mismatched',
      );
    }
    for (final item in permissionReview) {
      if (item['executionGranted'] != true ||
          item['grantScope'] != 'single_run' ||
          item['executionGrantId'] != grantId) {
        throw const SkillExecutionPermissionException(
          'skill_permission_grant_missing_or_mismatched',
        );
      }
    }
    // Dispatch consumes the grant. Reusing the same review object for another
    // invocation is rejected even when its visible fields are unchanged.
    _singleRunGrantIds[permissionReview] = null;
  }

  static String enforcementFor(String permission) {
    switch (permission) {
      case 'skill.runtime.execute':
      case 'runtime.proot.execute':
      case 'shell.execute':
        return 'kelivo_executor_gate';
      case 'skill.source.read':
      case 'skill.input.read':
        return 'staged_readonly_mount_best_effort';
      case 'skill.output.write':
        return 'run_output_mount';
      case 'runtime.rootfs.write':
      case 'network.read':
      case 'network.write':
      case 'network.package_install':
      case 'external.services':
        return 'guest_runtime_unrestricted_manual_approval_only';
      default:
        return 'native_adapter_required';
    }
  }

  static Map<String, Object?> policySummary() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'grantLifetime': 'single_run',
    'unknownPermissions': 'blocked',
    'unsupportedKnownPermissions': 'blocked_until_native_adapter_exists',
    'requiredPermissions': requiredLocalScriptPermissions.toList()..sort(),
    'limitations': <String>[
      'PRoot is not a kernel sandbox.',
      'The active RootFS remains shared and writable by the guest process.',
      'The guest process can access the device network; the current runtime cannot enforce a deny or host allowlist.',
      'Read-only bind guards cover common shell commands only and can be bypassed by interpreters, direct syscalls, absolute paths, shell redirection, or modifying the shared guard files.',
    ],
  };

  static void _validateGrantId(String grantId) {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{7,127}$').hasMatch(grantId)) {
      throw const SkillExecutionPermissionException('invalid_skill_execution_grant_id');
    }
  }
}

final class SkillExecutionPermissionException implements Exception {
  const SkillExecutionPermissionException(this.code);
  final String code;

  @override
  String toString() => code;
}
