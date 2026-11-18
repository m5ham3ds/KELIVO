/// Central, Skill-independent inventory of capabilities implemented by
/// Kelivo. This registry describes application support, not the availability
/// of a particular command, package, credential, or remote provider.
///
/// Per-Skill environment evidence is attached by [assessRequirements].
abstract final class SkillCapabilityRegistry {
  static const int schemaVersion = 1;

  static const List<Map<String, Object?>> _catalog = <Map<String, Object?>>[
    {
      'id': 'agent_skill.instructions',
      'title': 'Agent Skill instructions',
      'implementation': 'implemented',
      'scope': 'Read and follow selected SKILL.md guidance; this is not code execution.',
    },
    {
      'id': 'agent_skill.local_scripts',
      'title': 'Local Skill scripts (runtime not yet identified)',
      'implementation': 'implemented_conditional',
      'scope': 'The Skill declares executable local scripts but the entrypoint/runtime has not been identified. Resolve a supported runtime profile and obtain per-run approval before execution.',
    },
    {
      'id': 'agent_skill.local_scripts.python',
      'title': 'Python Skill scripts',
      'implementation': 'implemented_conditional',
      'scope': 'SkillExecutor + Skill-owned Python Runtime Profile + single-run permission grant. Android PRoot remains a best-effort runtime, not a kernel sandbox.',
    },
    {
      'id': 'agent_skill.local_scripts.shell',
      'title': 'Bash/Shell Skill scripts',
      'implementation': 'implemented_conditional',
      'scope': 'SkillExecutor + Skill-owned Shell Runtime Profile + single-run permission grant. Android PRoot remains a best-effort runtime, not a kernel sandbox.',
    },
    {
      'id': 'agent_skill.local_scripts.node',
      'title': 'Node.js Skill scripts',
      'implementation': 'implemented_conditional',
      'scope': 'SkillExecutor + Skill-owned Node Runtime Profile + single-run permission grant. Android PRoot remains a best-effort runtime, not a kernel sandbox.',
    },
    {
      'id': 'agent_skill.cli_tools',
      'title': 'CLI tools required by Skills',
      'implementation': 'environment_dependent',
      'scope': 'Must be probed in the target runtime profile; base PRoot detection is not proof.',
    },
    {
      'id': 'agent_skill.mcp_server',
      'title': 'Skill-declared MCP servers',
      'implementation': 'manual_adapter_required',
      'scope': 'Configuration may be inspected; Skill import does not register or start a server.',
    },
    {
      'id': 'agent_skill.http_api_connector',
      'title': 'Skill-owned HTTP/OpenAPI connectors',
      'implementation': 'adapter_required',
      'scope': 'Requires a reviewed connector adapter and credential binding.',
    },
    {
      'id': 'agent_skill.workflow',
      'title': 'Skill workflow definitions',
      'implementation': 'adapter_required',
      'scope': 'Requires a compatible workflow runner and reviewed adapter.',
    },
    {
      'id': 'agent_skill.native_kelivo_tool',
      'title': 'Native Kelivo tools contributed by Skills',
      'implementation': 'requires_kelivo_development',
      'scope': 'A Skill archive cannot inject executable Dart code into the app.',
    },
  ];

  /// Returns an immutable, app-wide capability catalog, independent of which
  /// Skills happen to be installed or enabled.
  static Map<String, Object?> catalogJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'registryId': 'kelivo.skill-capabilities',
    'registryMode': 'application_implementation_inventory',
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'capabilities': _catalog.map((entry) => Map<String, Object?>.unmodifiable(entry)).toList(growable: false),
    'policy': <String, Object?>{
      'installedSkillsDoNotCreateApplicationCapabilities': true,
      'skillPacksDoNotOwnOrReplaceOriginalSkills': true,
      'runtimeEvidenceIsRequiredBeforeClaimingAvailability': true,
      'unknownCapabilitiesAreNeverAssumedSupported': true,
    },
  };

  /// Matches discovered per-Skill capability declarations against the
  /// application catalog and the actual read-only probe results.
  static Map<String, Object?> assessRequirements(Map<String, Object?> requirements) {
    final commands = (requirements['commands'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .toList(growable: false);
    final commandByName = <String, Map<String, Object?>>{
      for (final item in commands)
        if (item['name'] is String) item['name'] as String: item,
    };
    final declared = (requirements['capabilities'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .toList(growable: false);
    final assessments = <Map<String, Object?>>[];

    for (final item in declared) {
      final kind = item['kind']?.toString() ?? 'unknown';
      final entryPoints = (item['entryPoints'] as List? ?? const []).whereType<String>().toList();
      final descriptors = _descriptorsForKind(kind, entryPoints);
      final descriptor = descriptors.isNotEmpty
          ? descriptors.first
          : kind == 'local_script' ? null : _descriptorForKind(kind);
      final supportedEntryPoints = entryPoints.where((entry) {
        final extension = entry.toLowerCase().split('.').last;
        return const {'py', 'sh', 'bash', 'js', 'mjs', 'cjs'}.contains(extension);
      }).toSet();
      final unclassifiedEntryPoints = kind == 'local_script'
          ? entryPoints.where((entry) => !supportedEntryPoints.contains(entry)).toList(growable: false)
          : const <String>[];
      final relatedCommands = <Map<String, Object?>>[];
      for (final entry in entryPoints) {
        final extension = entry.toLowerCase().split('.').last;
        final command = switch (extension) {
          'py' => 'python3',
          'sh' || 'bash' => 'bash',
          'js' || 'mjs' || 'cjs' => 'node',
          _ => null,
        };
        final evidence = command == null ? null : commandByName[command];
        if (evidence != null && !relatedCommands.contains(evidence)) {
          relatedCommands.add(evidence);
        }
      }
      // CLI capability entry points name the executable itself (for example
      // `ffmpeg`) rather than a script extension. Match the command inventory
      // directly, accepting absolute paths while comparing only the basename.
      if (kind == 'cli_binary') {
        for (final entry in entryPoints) {
          final normalizedEntry = entry.trim().replaceAll('\\', '/');
          final commandName = normalizedEntry.split('/').last;
          final evidence = commandByName[commandName];
          if (evidence != null && !relatedCommands.contains(evidence)) {
            relatedCommands.add(evidence);
          }
        }
      }
      final implementation = unclassifiedEntryPoints.isNotEmpty
          ? 'unknown'
          : descriptor?['implementation']?.toString() ?? 'unknown';
      // Compute the display title in separate steps. Besides avoiding an
      // ambiguous conditional/null-aware-index expression, this keeps the
      // fallback behavior explicit for unknown and unclassified capabilities.
      final descriptorTitles = descriptors
          .map((entry) => entry['title'])
          .whereType<String>()
          .where((title) => title.trim().isNotEmpty)
          .toList(growable: false);
      final descriptorTitle = descriptor == null
          ? null
          : descriptor['title']?.toString();
      final resolvedTitle = descriptorTitles.isNotEmpty
          ? descriptorTitles.join(', ')
          : (descriptorTitle == null || descriptorTitle.trim().isEmpty
              ? kind
              : descriptorTitle.trim());
      final profileVerification = requirements['runtimeProfileVerification'];
      final profileVerified = profileVerification is Map &&
          profileVerification['status'] == 'passed' &&
          profileVerification['profileId'] is String &&
          (profileVerification['profileId'] as String).trim().isNotEmpty &&
          profileVerification['validatedAt'] is String &&
          (profileVerification['validatedAt'] as String).trim().isNotEmpty;
      final status = switch (implementation) {
        'implemented' => 'supported',
        'implemented_conditional' => profileVerified ? 'verified_in_skill_runtime_profile' : 'requires_runtime_profile_and_approval',
        'environment_dependent' => profileVerified &&
                relatedCommands.any((item) => item['status'] == 'installed' && item['verifiedIn'] == 'skill_runtime_profile')
            ? 'verified_in_skill_runtime_profile'
            : relatedCommands.any((item) =>
                    item['status'] == 'installed' &&
                    item['verifiedIn'] == 'base_proot_environment')
                ? 'detected_in_base_environment_only'
                : 'environment_not_verified',
        'manual_adapter_required' || 'adapter_required' || 'requires_kelivo_development' => 'not_operational_in_current_skill_adapter',
        _ => 'unknown',
      };
      assessments.add(<String, Object?>{
        'skillCapabilityId': item['id'],
        'kind': kind,
        'applicationCapabilityId': descriptor?['id'],
        'applicationCapabilityIds': descriptors.map((entry) => entry['id']).whereType<String>().toList(growable: false),
        'title': resolvedTitle,
        'implementation': implementation,
        'status': status,
        'scope': descriptor?['scope'] ?? 'No capability contract is registered for this kind.',
        'entryPoints': entryPoints,
        'unclassifiedEntryPoints': unclassifiedEntryPoints,
        'relatedCommands': relatedCommands.map((command) => <String, Object?>{
          'name': command['name'],
          'status': command['status'],
          'verifiedIn': command['verifiedIn'],
        }).toList(growable: false),
      });
    }

    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'catalog': catalogJson(),
      'requiredCapabilities': assessments,
      'summary': <String, Object?>{
        'required': assessments.length,
        'supported': assessments.where((item) => item['status'] == 'supported').length,
        'conditional': assessments.where((item) => item['status'] == 'requires_runtime_profile_and_approval').length,
        'notOperational': assessments.where((item) => item['status'] == 'not_operational_in_current_skill_adapter').length,
        'unknown': assessments.where((item) => item['status'] == 'unknown').length,
      },
    };
  }

  static List<Map<String, Object?>> _descriptorsForKind(
    String kind,
    List<String> entryPoints,
  ) {
    if (kind != 'local_script') {
      final descriptor = _descriptorForKind(kind);
      return descriptor == null ? const [] : [descriptor];
    }
    if (entryPoints.isEmpty) {
      final generic = _descriptorForKind('local_script');
      return generic == null ? const [] : [generic];
    }
    final ids = <String>{};
    for (final entry in entryPoints) {
      final extension = entry.toLowerCase().split('.').last;
      switch (extension) {
        case 'py':
          ids.add('agent_skill.local_scripts.python');
          break;
        case 'sh':
        case 'bash':
          ids.add('agent_skill.local_scripts.shell');
          break;
        case 'js':
        case 'mjs':
        case 'cjs':
          ids.add('agent_skill.local_scripts.node');
          break;
      }
    }
    if (ids.isEmpty) return const [];
    return [
      for (final descriptor in _catalog)
        if (ids.contains(descriptor['id'])) descriptor,
    ];
  }

  static Map<String, Object?>? _descriptorForKind(String kind) {
    const ids = <String, String>{
      'instruction_only': 'agent_skill.instructions',
      'local_script': 'agent_skill.local_scripts',
      'cli_binary': 'agent_skill.cli_tools',
      'mcp_server': 'agent_skill.mcp_server',
      'http_api_connector': 'agent_skill.http_api_connector',
      'native_kelivo_tool': 'agent_skill.native_kelivo_tool',
      'workflow': 'agent_skill.workflow',
    };
    final id = ids[kind];
    if (id == null) return null;
    for (final descriptor in _catalog) {
      if (descriptor['id'] == id) return descriptor;
    }
    return null;
  }
}
