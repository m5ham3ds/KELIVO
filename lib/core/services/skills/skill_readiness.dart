import 'skill_capability_registry.dart';

/// Computes honest, staged readiness for an installed Skill.
///
/// A static requirement inventory or a command found in the base PRoot is not
/// sufficient to mark a Skill fully ready. Full readiness requires dependency
/// and configuration evidence in its target profile and a passed validation
/// record. This phase does not manufacture that validation record.
abstract final class SkillReadinessEngine {
  static const readinessStates = <String>{
    'blocked_incomplete_import',
    'analysis_required',
    'requirements_missing',
    'unsupported_environment',
    'dependencies_pending',
    'configuration_required',
    'validation_required',
    'ready_for_instructions',
    'ready_for_execution',
    'ready',
  };

  static Map<String, Object?> apply({
    required Map<String, Object?> requirements,
    required String importCompleteness,
    Map<String, Object?> validation = const <String, Object?>{},
  }) {
    final analyzed = requirements['schemaVersion'] is num;
    final commands = (requirements['commands'] as List? ?? const [])
        .whereType<Map>().toList(growable: false);
    final packages = (requirements['packages'] as List? ?? const [])
        .whereType<Map>().toList(growable: false);
    final credentials = (requirements['credentials'] as List? ?? const [])
        .whereType<Map>().toList(growable: false);
    final services = (requirements['externalServices'] as List? ?? const [])
        .whereType<Map>().toList(growable: false);
    final capabilities = (requirements['capabilities'] as List? ?? const [])
        .whereType<Map>().toList(growable: false);
    final commandMissing = commands.any((item) => item['status'] == 'missing');
    final credentialMissing = credentials.any((item) => item['status'] == 'missing_configuration');
    final commandProfileVerified = commands.every((item) =>
        item['status'] == 'installed' && item['verifiedIn'] == 'skill_runtime_profile');
    final packageVerified = packages.every((item) => item['status'] == 'installed_or_verified');
    final needsRuntimeProfile = capabilities.any((item) =>
        item['kind'] == 'local_script' || item['kind'] == 'cli_binary');
    final profileVerification = requirements['runtimeProfileVerification'];
    final runtimeProfileVerified = profileVerification is Map &&
        profileVerification['status'] == 'passed' &&
        profileVerification['profileId'] is String &&
        (profileVerification['profileId'] as String).trim().isNotEmpty &&
        profileVerification['validatedAt'] is String &&
        (profileVerification['validatedAt'] as String).trim().isNotEmpty;
    final dependenciesResolved =
        (packages.isEmpty && commands.isEmpty || packageVerified && commandProfileVerified) &&
        (!needsRuntimeProfile || runtimeProfileVerified);
    final credentialConfigured = credentials.every((item) =>
        item['status'] == 'configured_in_kelivo_environment' || item['status'] == 'validated');
    final servicesVerified = services.every((item) =>
        item['verification'] == 'verified' || item['status'] == 'verified');
    final configured = credentialConfigured && servicesVerified;
    final capabilityRegistry = SkillCapabilityRegistry.assessRequirements(requirements);
    final registryCapabilities = (capabilityRegistry['requiredCapabilities'] as List? ?? const [])
        .whereType<Map>();
    final unknownRegistryCapabilityCount = registryCapabilities.where((item) => item['status'] == 'unknown').length;
    final hasUnknownRegistryCapability = unknownRegistryCapabilityCount > 0;
    final rawUnknownCapabilityCount = capabilities.where((item) => item['support'] == 'unknown').length;
    final reportedUnknownCapabilityCount = rawUnknownCapabilityCount > unknownRegistryCapabilityCount
        ? rawUnknownCapabilityCount
        : unknownRegistryCapabilityCount;
    final hasUnsupportedCapability = hasUnknownRegistryCapability || capabilities.any((item) => const {
      'environment_work_required',
      'manual_adapter_required',
      'adapter_required',
      'requires_kelivo_development',
      'unknown',
    }.contains(item['support']));
    final instructionOnly = capabilities.isNotEmpty &&
        capabilities.every((item) => item['kind'] == 'instruction_only') &&
        commands.isEmpty && packages.isEmpty && credentials.isEmpty && services.isEmpty;
    final validationEvidence = validation['evidence'];
    final validationTimestamp = validation['validatedAt'] is String &&
        (validation['validatedAt'] as String).trim().isNotEmpty;
    final validated = validation['status'] == 'passed' &&
        validationTimestamp &&
        validationEvidence is List && validationEvidence.isNotEmpty;
    final capabilityResults = _readCapabilityResults(validation['capabilityResults']);
    final capabilityIds = capabilities
        .where((item) => item['kind'] != 'instruction_only')
        .map(_capabilityKey)
        .where((value) => value.isNotEmpty)
        .toSet();
    final requiredCapabilityIds = capabilities
        .where((item) => item['kind'] != 'instruction_only' && item['requiredForReadiness'] != false)
        .map(_capabilityKey)
        .where((value) => value.isNotEmpty)
        .toSet();
    final passedCapabilityIds = capabilityResults.entries
        .where((entry) => capabilityIds.contains(entry.key) &&
            entry.value['status'] == 'passed' &&
            _hasEvidence(entry.value['evidence']))
        .map((entry) => entry.key)
        .toSet();
    final hasPassedCapability = passedCapabilityIds.isNotEmpty ||
        (capabilityIds.isEmpty && validated);
    final mandatoryCapabilitiesPassed = requiredCapabilityIds.every(
      passedCapabilityIds.contains,
    );
    final executionReady = !instructionOnly &&
        importCompleteness == 'complete' &&
        analyzed &&
        dependenciesResolved &&
        configured &&
        !hasUnsupportedCapability &&
        validationTimestamp &&
        hasPassedCapability;
    final fullyValidated = executionReady && validated && mandatoryCapabilitiesPassed;

    final stages = <String, Object?>{
      'installed': <String, Object?>{
        'status': importCompleteness == 'complete' ? 'complete' : 'blocked',
        'detail': importCompleteness == 'complete'
            ? 'Skill files and import manifest are complete.'
            : 'The import manifest is not confirmed complete.',
      },
      'analyzed': <String, Object?>{
        'status': analyzed ? 'complete' : 'pending',
        'detail': analyzed ? 'A requirement inventory exists.' : 'Run requirement discovery.',
      },
      'dependenciesResolved': <String, Object?>{
        'status': dependenciesResolved ? 'complete' : commandMissing || packages.any((item) => item['status'] == 'missing') ? 'blocked' : 'pending',
        'detail': dependenciesResolved
            ? 'Dependencies have profile-level verification or no executable dependencies were discovered.'
            : 'Packages and commands must be verified inside the Skill-owned Runtime Profile; base PRoot detection is not enough.',
      },
      'configured': <String, Object?>{
        'status': configured ? 'complete' : credentialMissing ? 'blocked' : 'pending',
        'detail': configured
            ? 'Required configuration names are present and external services are marked verified.'
            : 'Required credential names and external service connections still need configuration/verification.',
      },
      'validated': <String, Object?>{
        'status': fullyValidated ? 'complete' : executionReady ? 'partial' : 'pending',
        'detail': fullyValidated
            ? 'Every mandatory capability has passed a recorded Skill-specific validation.'
            : executionReady
                ? 'Some executable capabilities passed; other mandatory capabilities still require tests.'
                : 'No executable capability has sufficient profile-bound validation evidence.',
      },
    };

    String state;
    if (importCompleteness != 'complete') {
      state = 'blocked_incomplete_import';
    } else if (!analyzed) {
      state = 'analysis_required';
    } else if (commandMissing || credentialMissing || packages.any((item) => item['status'] == 'missing')) {
      state = 'requirements_missing';
    } else if (hasUnsupportedCapability) {
      state = 'unsupported_environment';
    } else if (!dependenciesResolved) {
      state = 'dependencies_pending';
    } else if (!configured) {
      state = 'configuration_required';
    } else if (instructionOnly) {
      state = 'ready_for_instructions';
    } else if (executionReady && !fullyValidated) {
      state = 'ready_for_execution';
    } else if (!fullyValidated) {
      state = 'validation_required';
    } else {
      state = 'ready';
    }

    final nextActions = <String>[];
    switch (state) {
      case 'blocked_incomplete_import':
        nextActions.add('Restore missing companion files and complete the Skill import.');
        break;
      case 'analysis_required':
        nextActions.add('Run extension_inspect to generate a current requirement inventory.');
        break;
      case 'requirements_missing':
        nextActions.add('Provide the missing commands/packages/configuration, then re-check the Skill Runtime Profile.');
        break;
      case 'unsupported_environment':
        nextActions.add('Develop or connect the missing Kelivo adapter before using this executable capability.');
        break;
      case 'dependencies_pending':
        nextActions.add('Create or update the Skill-owned Runtime Profile and verify every declared dependency inside it.');
        break;
      case 'configuration_required':
        nextActions.add('Configure required secret names securely and verify external services through an approved test.');
        break;
      case 'validation_required':
        nextActions.add('Run a Skill-specific self-test and record profile-bound evidence for each executable capability.');
        break;
      case 'ready_for_execution':
        nextActions.add('Only capabilities with passed validation evidence may be executed; test the remaining mandatory capabilities before declaring the Skill fully ready.');
        break;
      case 'ready_for_instructions':
        nextActions.add('Instruction-only assistance is available; no executable capability is implied.');
        break;
    }

    final validatedCapabilityIds = passedCapabilityIds.toList()..sort();
    final pendingMandatoryCapabilityIds =
        requiredCapabilityIds.difference(passedCapabilityIds).toList()..sort();

    requirements
      ..['capabilityRegistry'] = capabilityRegistry
      ..['readinessState'] = state
      ..['readinessStages'] = stages
      ..['readinessNextActions'] = nextActions
      ..['readinessCheckedAt'] = DateTime.now().toUtc().toIso8601String()
      ..['readiness'] = switch (state) {
        'ready' => 'ready',
        'ready_for_instructions' => 'instruction_only_ready',
        'ready_for_execution' => 'ready_for_execution',
        'blocked_incomplete_import' => 'blocked_incomplete_import',
        'analysis_required' => 'analysis_required',
        'requirements_missing' => 'requirements_missing',
        'unsupported_environment' => 'unsupported_environment',
        'dependencies_pending' => 'dependencies_pending',
        'configuration_required' => 'configuration_required',
        'validation_required' => 'validation_required',
        _ => 'unknown',
      }
      ..['readinessLevel'] = fullyValidated
          ? 'fully_ready'
          : executionReady
              ? 'ready_for_execution'
              : importCompleteness == 'complete' && analyzed
                  ? 'ready_for_guidance'
                  : 'not_ready'
      ..['readinessLevelLabel'] = fullyValidated
          ? 'Fully Ready'
          : executionReady
              ? 'Ready for Execution'
              : importCompleteness == 'complete' && analyzed
                  ? 'Ready for Guidance'
                  : 'Not Ready'
      ..['validatedCapabilities'] = validatedCapabilityIds
      ..['pendingMandatoryCapabilities'] = pendingMandatoryCapabilityIds
      ..['readinessSummary'] = <String, Object?>{
        'capabilitiesValidated': passedCapabilityIds.length,
        'capabilitiesRequired': requiredCapabilityIds.length,
        'capabilitiesPending': requiredCapabilityIds.difference(passedCapabilityIds).length,
        'commandsVerified': commands.where((item) => item['status'] == 'installed' && item['verifiedIn'] == 'skill_runtime_profile').length,
        'commandsDetectedInBase': commands.where((item) => item['status'] == 'installed' && item['verifiedIn'] == 'base_proot_environment').length,
        'commandsMissing': commands.where((item) => item['status'] == 'missing').length,
        'commandsNotChecked': commands.where((item) => !const {'installed', 'missing'}.contains(item['status'])).length,
        'packagesPending': packages.where((item) => item['status'] != 'installed_or_verified').length,
        'credentialsMissing': credentials.where((item) => item['status'] == 'missing_configuration').length,
        'credentialsNotChecked': credentials.where((item) => item['status'] != 'configured_in_kelivo_environment' && item['status'] != 'validated').length,
        'adaptersRequired': capabilities.where((item) => const {'environment_work_required', 'manual_adapter_required', 'adapter_required', 'requires_kelivo_development'}.contains(item['support'])).length,
        'unknownCapabilities': reportedUnknownCapabilityCount,
        'runtimeProfilesRequired': capabilities.where((item) => item['support'] == 'conditional').length,
        'externalServicesNotVerified': services.where((item) => item['verification'] != 'verified' && item['status'] != 'verified').length,
        'stagesComplete': stages.values.whereType<Map>().where((item) => item['status'] == 'complete').length,
        'stagesTotal': stages.length,
      };
    return requirements;
  }

  static String _capabilityKey(Map capability) =>
      (capability['id'] ?? capability['kind'] ?? '').toString().trim();

  static bool _hasEvidence(Object? evidence) =>
      evidence is List && evidence.isNotEmpty ||
      evidence is String && evidence.trim().isNotEmpty;

  static Map<String, Map<String, Object?>> _readCapabilityResults(Object? raw) {
    final results = <String, Map<String, Object?>>{};
    if (raw is List) {
      for (final value in raw.whereType<Map>()) {
        final id = (value['capabilityId'] ?? value['id'] ?? value['kind'] ?? '')
            .toString()
            .trim();
        if (id.isEmpty) continue;
        results[id] = Map<String, Object?>.from(value);
      }
    } else if (raw is Map) {
      for (final entry in raw.entries) {
        if (entry.value is Map) {
          results[entry.key.toString()] = Map<String, Object?>.from(entry.value as Map);
        } else if (entry.value is String) {
          results[entry.key.toString()] = <String, Object?>{
            'status': entry.value,
          };
        }
      }
    }
    return results;
  }

  /// Compact snapshot embedded in composition output. A persisted assessment
  /// is source-current only when it refers to the same Skill content digest;
  /// environment state must still be rechecked before execution.
  static Map<String, Object?> compositionSnapshot(Map<String, Object?> importReport) {
    final stored = importReport['environmentAssessment'];
    final sourceDigest = importReport['sourceDigest']?.toString();
    if (stored is Map) {
      final assessment = Map<String, Object?>.from(stored);
      final sourceCurrent = sourceDigest != null && assessment['sourceDigest'] == sourceDigest;
      return <String, Object?>{
        'readinessState': sourceCurrent ? assessment['readinessState'] ?? 'not_checked' : 'stale_source',
        'readinessLevel': sourceCurrent ? assessment['readinessLevel'] ?? 'not_ready' : 'not_ready',
        'readinessLevelLabel': sourceCurrent ? assessment['readinessLevelLabel'] ?? 'Not Ready' : 'Not Ready',
        'checkedAt': assessment['readinessCheckedAt'] ?? assessment['checkedAt'],
        'sourceCurrent': sourceCurrent,
        'environmentMustBeRecheckedBeforeExecution': true,
        'nextActions': sourceCurrent
            ? assessment['readinessNextActions'] ?? const <String>[]
            : const <String>['Run extension_inspect to refresh the Skill requirement and readiness assessment.'],
      };
    }
    return <String, Object?>{
      'readinessState': importReport['requirements'] is Map ? 'not_checked' : 'analysis_required',
      'readinessLevel': 'not_ready',
      'readinessLevelLabel': 'Not Ready',
      'sourceCurrent': false,
      'environmentMustBeRecheckedBeforeExecution': true,
      'nextActions': <String>['Run extension_inspect for a current requirement and readiness assessment.'],
    };
  }
}
