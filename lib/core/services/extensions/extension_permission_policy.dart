/// Review metadata for permissions declared by installable extensions.
///
/// This catalog is descriptive only. SkillExecutor uses its dedicated
/// per-run grant policy after mandatory manual approval; other adapters must
/// provide their own enforcement and must not treat this review as a grant.
abstract final class ExtensionPermissionPolicy {
  static const Map<String, _PermissionDefinition> _catalog = {
    'skill.runtime.execute': _PermissionDefinition(
      risk: 'critical',
      description: 'Execute an explicitly declared Skill capability through the approved Skill Executor. This is a per-run grant, not a persistent grant.',
    ),
    'skill.source.read': _PermissionDefinition(
      risk: 'medium',
      description: 'Read the integrity-checked per-run copy of the installed Skill source; the live installed Skills tree is not mounted.',
    ),
    'skill.input.read': _PermissionDefinition(
      risk: 'medium',
      description: 'Read only the staged JSON inputs and explicitly selected files copied into this run.',
    ),
    'skill.output.write': _PermissionDefinition(
      risk: 'high',
      description: 'Write generated artifacts to this run output directory; the full Workspace tree is not mounted.',
    ),
    'workspace.project.read': _PermissionDefinition(
      risk: 'low',
      description: 'Read project files and metadata inside the active Workspace.',
    ),
    'workspace.project.write': _PermissionDefinition(
      risk: 'high',
      description: 'Create or modify files inside the active Workspace.',
    ),
    'workspace.read': _PermissionDefinition(
      risk: 'low',
      description: 'Read files in the explicitly selected Workspace.',
    ),
    'workspace.write': _PermissionDefinition(
      risk: 'high',
      description: 'Write files in the explicitly selected Workspace.',
    ),
    'runtime.proot.execute': _PermissionDefinition(
      risk: 'critical',
      description: 'Run adapter-defined commands inside the Android PRoot runtime.',
    ),
    'runtime.rootfs.write': _PermissionDefinition(
      risk: 'critical',
      description: 'Write access to the shared active PRoot RootFS; an approved Skill can alter system files and installed packages used by later runs.',
    ),
    'shell.execute': _PermissionDefinition(
      risk: 'critical',
      description: 'Execute shell commands; each invocation still requires tool approval.',
    ),
    'network.video_generation': _PermissionDefinition(
      risk: 'high',
      description: 'Send prompts or media references to an external video-generation provider; charges may apply.',
    ),
    'network.read': _PermissionDefinition(
      risk: 'medium',
      description: 'Read remote network resources from a declared source.',
    ),
    'network.write': _PermissionDefinition(
      risk: 'high',
      description: 'Send data to remote network services.',
    ),
    'network.package_install': _PermissionDefinition(
      risk: 'high',
      description: 'Download and install packages from configured package sources.',
    ),
    'external.services': _PermissionDefinition(
      risk: 'high',
      description: 'Connect to external providers or services and transmit data outside Kelivo.',
    ),
    'device.location': _PermissionDefinition(
      risk: 'sensitive',
      description: 'Access device location only through an explicit Android permission flow.',
    ),
    'device.calendar.read': _PermissionDefinition(
      risk: 'sensitive',
      description: 'Read calendar data only after the user grants Android permission.',
    ),
    'device.calendar.write': _PermissionDefinition(
      risk: 'sensitive',
      description: 'Modify calendar data only after the user grants Android permission.',
    ),
  };

  static List<Map<String, Object?>> review(Iterable<String> declared) {
    final identifiers = declared.map((value) => value.trim()).where((value) => value.isNotEmpty).toSet().toList()..sort();
    return List.unmodifiable([
      for (final permission in identifiers)
        _assessment(permission),
    ]);
  }

  static Map<String, Object?> _assessment(String permission) {
    final definition = _catalog[permission];
    return {
      'permission': permission,
      'recognized': definition != null,
      'risk': definition?.risk ?? 'unknown',
      'description': definition?.description ?? 'This permission is not recognized by this Kelivo version.',
      'requiresExplicitApproval': true,
      'executionGranted': false,
      'blockedUntilReviewed': definition == null,
    };
  }
}

final class _PermissionDefinition {
  const _PermissionDefinition({required this.risk, required this.description});

  final String risk;
  final String description;
}
