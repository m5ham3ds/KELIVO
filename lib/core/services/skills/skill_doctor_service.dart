import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../providers/environment_provider.dart';
import '../../../utils/app_directories.dart';
import '../../models/environment_state.dart';
import '../runtime_profiles/runtime_profile_models.dart';
import '../runtime_profiles/runtime_profile_service.dart';
import '../workspace/workspace_runtime.dart';
import 'skill.dart';
import 'skill_capability_registry.dart';
import 'skill_readiness.dart';
import 'skills_service.dart';

/// Read-only diagnostic orchestration for all installed Agent Skills.
///
/// The doctor never invokes Skill entry points, package managers, MCP servers,
/// workflows or external APIs. Its only runtime command is a bounded
/// `command -v` probe executed in the selected Skill-owned Runtime Profile.
/// Requirement inventories may be read from their existing import manifest;
/// the doctor does not rewrite Skill sources or silently repair dependencies.
class SkillDoctorService {
  SkillDoctorService({
    required this.skills,
    required this.runtimeProfiles,
    required this.runtimeProvider,
    required this.environment,
  });

  final SkillsService skills;
  final RuntimeProfileService runtimeProfiles;
  final WorkspaceRuntimeProvider runtimeProvider;
  final EnvironmentProvider environment;

  static const int _maxManifestFiles = 8192;
  static const int _maxManifestBytes = 500 * 1024 * 1024;
  static const int _maxFileBytes = 200 * 1024 * 1024;
  static const int _maxProcessHistoryFindings = 50;

  Future<Map<String, Object?>> scan() async {
    await skills.loaded;
    await runtimeProfiles.load();
    await environment.loaded;

    RuntimeStatus? runtimeStatus;
    String? runtimeError;
    try {
      final runtime = await runtimeProvider.ensureInitialized(
        timeout: const Duration(seconds: 12),
      );
      if (runtime == null) {
        runtimeError = runtimeProvider.initializationError ?? 'runtime_not_registered';
      } else {
        runtimeStatus = await runtime.status().timeout(const Duration(seconds: 8));
      }
    } catch (error) {
      runtimeError = error.runtimeType.toString();
    }

    final profiles = await runtimeProfiles.list();
    final skillIds = skills.skills.map((skill) => skill.record.id).toSet();
    final globalIssues = <Map<String, Object?>>[];
    if (runtimeStatus == null || !runtimeStatus.ready) {
      globalIssues.add(_issue(
        id: 'runtime-unavailable',
        severity: 'critical',
        category: 'runtime',
        title: 'PRoot runtime is unavailable',
        detail: runtimeError ?? runtimeStatus?.reason ?? 'No ready runtime is registered.',
        source: 'WorkspaceRuntimeProvider',
        fix: 'Open the Environment settings, complete or repair the PRoot installation, then scan again.',
      ));
    } else if (!runtimeStatus.sandboxed || runtimeStatus.engine != 'proot') {
      globalIssues.add(_issue(
        id: 'runtime-unsupported',
        severity: 'critical',
        category: 'runtime',
        title: 'Current runtime cannot execute Skills',
        detail: 'Engine=${runtimeStatus.engine}; sandboxed=${runtimeStatus.sandboxed}. Skill execution currently requires a ready Android PRoot runtime.',
        source: 'WorkspaceRuntimeProvider.status()',
        fix: 'Use a supported Android PRoot runtime. Do not treat native shell availability as Skill execution support.',
      ));
    }

    if (environment.state.phase != EnvironmentPhase.ready) {
      globalIssues.add(_issue(
        id: 'rootfs-not-ready',
        severity: 'warning',
        category: 'environment',
        title: 'Base environment is not marked ready',
        detail: 'RootFS phase: ${environment.state.phase.name}.',
        source: 'EnvironmentProvider.state.phase',
        fix: 'Repair or finish the base environment setup before validating runtime dependencies.',
      ));
    }

    final orphanProfiles = profiles.where((profile) =>
        profile.scope == RuntimeProfileScope.extension &&
        !skillIds.contains(profile.ownerId)).toList(growable: false);
    for (final profile in orphanProfiles) {
      globalIssues.add(_issue(
        id: 'orphan-profile-${profile.id}',
        severity: 'warning',
        category: 'runtime_profile',
        title: 'Runtime Profile has no installed Skill owner',
        detail: 'Profile ${profile.name} (${profile.id}) belongs to missing Skill ID ${profile.ownerId}.',
        source: 'runtime_profile:${profile.id}',
        fix: 'Restore the owning Skill or review and remove the orphaned Profile from the Runtime Profile manager.',
      ));
    }

    final skillResults = <Map<String, Object?>>[];
    for (final skill in skills.skills) {
      skillResults.add(await _inspectSkill(
        skill: skill,
        profiles: profiles.where((profile) =>
            profile.scope == RuntimeProfileScope.extension &&
            profile.ownerId == skill.record.id).toList(growable: false),
        runtimeStatus: runtimeStatus,
      ));
    }

    final hasExecutableSkills = skillResults.any(
      (skill) => skill['requiresRuntimeProfile'] == true,
    );
    if (!hasExecutableSkills) {
      for (final issue in globalIssues.where((item) =>
          item['id'] == 'runtime-unavailable' || item['id'] == 'runtime-unsupported')) {
        issue['severity'] = 'warning';
        issue['detail'] = '${issue['detail']} No installed Skill currently declares a local script or CLI capability.';
      }
    }

    final processIssues = _inspectProcessHistory(profiles);
    globalIssues.addAll(processIssues);

    final allIssues = <Map<String, Object?>>[
      ...globalIssues,
      for (final skill in skillResults)
        ...(skill['issues'] as List? ?? const []).whereType<Map>().map(
          (entry) => Map<String, Object?>.from(entry)..['skillId'] = skill['id'],
        ),
    ];
    final critical = allIssues.where((issue) => issue['severity'] == 'critical').length;
    final warnings = allIssues.where((issue) => issue['severity'] == 'warning').length;
    final info = allIssues.where((issue) => issue['severity'] == 'info').length;
    final healthy = skillResults.where((skill) =>
        (skill['issueCounts'] as Map?)?['critical'] == 0 &&
        (skill['issueCounts'] as Map?)?['warning'] == 0).length;

    return <String, Object?>{
      'schemaVersion': 1,
      'doctorId': 'kelivo.skill-doctor',
      'scannedAt': DateTime.now().toUtc().toIso8601String(),
      'mode': 'read_only_diagnostics',
      'runtime': <String, Object?>{
        'registered': runtimeProvider.runtime != null,
        'ready': runtimeStatus?.ready ?? false,
        'engine': runtimeStatus?.engine ?? 'none',
        'sandboxed': runtimeStatus?.sandboxed ?? false,
        if (runtimeStatus?.reason != null) 'reason': runtimeStatus!.reason,
        if (runtimeError != null) 'error': runtimeError,
        'rootfsPhase': environment.state.phase.name,
        'distribution': environment.state.distro,
        'version': environment.state.version,
        'architecture': environment.state.arch,
      },
      'summary': <String, Object?>{
        'skillsScanned': skillResults.length,
        'healthySkills': healthy,
        'profilesScanned': profiles.length,
        'critical': critical,
        'warnings': warnings,
        'info': info,
        'issues': allIssues.length,
      },
      'globalIssues': globalIssues,
      'skills': skillResults,
      'issues': allIssues,
      'limits': <String, Object?>{
        'skillFiles': _maxManifestFiles,
        'totalBytes': _maxManifestBytes,
        'singleFileBytes': _maxFileBytes,
      },
      'security': <String, Object?>{
        'skillEntryPointsExecuted': false,
        'packageManagersExecuted': false,
        'mcpServersStarted': false,
        'externalApisCalled': false,
        'secretValuesRead': false,
        'runtimeProbe': 'validated command names only; command -v inside an owned Skill Profile',
      },
    };
  }

  Future<Map<String, Object?>> _inspectSkill({
    required Skill skill,
    required List<RuntimeProfile> profiles,
    required RuntimeStatus? runtimeStatus,
  }) async {
    final issues = <Map<String, Object?>>[];
    final skillDirectory = Directory(skill.dir);
    if (!await skillDirectory.exists()) {
      issues.add(_issue(
        id: 'skill-directory-missing',
        severity: 'critical',
        category: 'installation',
        title: 'Skill directory is missing',
        detail: skill.dir,
        source: skill.dir,
        fix: 'Re-import the Skill from its original ZIP, repository or source.',
      ));
    }
    final skillFile = File(skill.skillMdPath);
    if (!await skillFile.exists()) {
      issues.add(_issue(
        id: 'skill-md-missing',
        severity: 'critical',
        category: 'installation',
        title: 'SKILL.md is missing',
        detail: skill.skillMdPath,
        source: skill.skillMdPath,
        fix: 'Restore SKILL.md from the original Skill source; do not replace it with generated placeholder instructions.',
      ));
    }

    Map<String, Object?>? importReport;
    try {
      importReport = await skills.getImportReport(skill.record.id);
    } catch (error) {
      issues.add(_issue(
        id: 'manifest-unreadable',
        severity: 'critical',
        category: 'installation',
        title: 'Skill import manifest could not be read',
        detail: error.runtimeType.toString(),
        source: 'skill-import-metadata/skills/${skill.record.id}.json',
        fix: 'Rebuild the Skill import manifest through the Skill import/inspect flow, then rescan.',
      ));
    }

    if (importReport == null) {
      issues.add(_issue(
        id: 'manifest-missing',
        severity: 'warning',
        category: 'installation',
        title: 'No import manifest is available',
        detail: 'This may be a legacy Skill installed before import manifests were introduced.',
        source: 'skill-import-metadata/skills/${skill.record.id}.json',
        fix: 'Run the Skill inspection/import analysis to create a current evidence manifest.',
      ));
    }

    final completeness = importReport?['completeness']?.toString() ?? 'unknown';
    if (completeness != 'complete') {
      final incompleteSeverity = completeness == 'partial' ? 'critical' : 'warning';
      issues.add(_issue(
        id: 'import-incomplete',
        severity: incompleteSeverity,
        category: 'installation',
        title: 'Skill import is not confirmed complete',
        detail: 'Completeness=$completeness; ${(importReport?['completenessNotes'] as List? ?? const []).whereType<String>().join(' ')}',
        source: 'import manifest completeness/completenessNotes',
        fix: 'Restore missing companion resources from the original source archive and re-import the Skill.',
      ));
    }

    Map<String, Object?> integrity;
    if (importReport == null) {
      integrity = <String, Object?>{'status': 'not_checked'};
    } else {
      try {
        integrity = await _verifyManifestFiles(skill, importReport);
      } catch (error) {
        integrity = <String, Object?>{
          'status': 'inconclusive',
          'reason': 'file_integrity_check_failed:${error.runtimeType}',
        };
      }
    }
    final integrityStatus = integrity['status']?.toString() ?? 'unknown';
    if (integrityStatus == 'changed' || integrityStatus == 'missing' || integrityStatus == 'unsafe') {
      final changed = (integrity['changed'] as List? ?? const []).join(', ');
      final missing = (integrity['missing'] as List? ?? const []).join(', ');
      final unsafe = (integrity['unsafe'] as List? ?? const []).join(', ');
      issues.add(_issue(
        id: 'source-integrity-$integrityStatus',
        severity: 'critical',
        category: 'integrity',
        title: 'Installed Skill files differ from the import manifest',
        detail: [
          if (changed.isNotEmpty) 'Changed: $changed',
          if (missing.isNotEmpty) 'Missing: $missing',
          if (unsafe.isNotEmpty) 'Unsafe: $unsafe',
        ].join(' | '),
        source: 'manifest files[].sha256 / sizeBytes',
        fix: 'Review the changed files, then re-import or update from a trusted source. The Doctor does not overwrite local files.',
      ));
    } else if (integrityStatus == 'inconclusive') {
      issues.add(_issue(
        id: 'source-integrity-inconclusive',
        severity: 'warning',
        category: 'integrity',
        title: 'Skill file integrity could not be fully checked',
        detail: integrity['reason']?.toString() ?? 'The manifest is too large or contains unsupported entries.',
        source: 'Skill import manifest',
        fix: 'Review the source and file count; re-import within the documented manifest size limits if needed.',
      ));
    }
    final untracked = (integrity['untracked'] as List? ?? const []).whereType<String>().toList();
    if (untracked.isNotEmpty) {
      issues.add(_issue(
        id: 'untracked-skill-files',
        severity: 'warning',
        category: 'integrity',
        title: 'Untracked files exist inside the Skill directory',
        detail: untracked.take(20).join(', '),
        source: skill.dir,
        fix: 'Review the added files and re-import/update from a trusted source if they are intended to be part of the Skill.',
      ));
    }

    final rawRequirements = importReport?['requirements'];
    final requirements = rawRequirements is Map
        ? Map<String, Object?>.from(rawRequirements)
        : <String, Object?>{};
    final hasRequirementInventory = requirements['schemaVersion'] is num;
    if (!hasRequirementInventory) {
      issues.add(_issue(
        id: 'requirements-not-analyzed',
        severity: 'warning',
        category: 'requirements',
        title: 'Requirement inventory is missing',
        detail: 'No current static requirement inventory is recorded for this Skill.',
        source: 'import manifest requirements',
        fix: 'Run the Skill inspection flow to analyze SKILL.md, declared dependencies and companion files.',
      ));
    }

    final capabilities = (requirements['capabilities'] as List? ?? const [])
        .whereType<Map>().map((entry) => Map<String, Object?>.from(entry)).toList();
    final needsProfile = SkillDoctorPolicy.requiresRuntimeProfile(requirements);
    final selectedProfileId = (requirements['runtimeProfileVerification'] is Map)
        ? ((requirements['runtimeProfileVerification'] as Map)['profileId']?.toString())
        : null;
    RuntimeProfile? profile;
    if (selectedProfileId != null) {
      profile = profiles.where((candidate) => candidate.id == selectedProfileId).firstOrNull;
      if (profile == null) {
        issues.add(_issue(
          id: 'selected-profile-missing',
          severity: 'critical',
          category: 'runtime_profile',
          title: 'Previously selected Runtime Profile no longer exists',
          detail: 'Profile ID: $selectedProfileId',
          source: 'requirements.runtimeProfileVerification.profileId',
          fix: 'Create or select a Runtime Profile owned by this Skill, then validate it again.',
        ));
      }
    } else if (profiles.length == 1) {
      profile = profiles.single;
    } else if (profiles.length > 1) {
      issues.add(_issue(
        id: 'profile-selection-ambiguous',
        severity: 'warning',
        category: 'runtime_profile',
        title: 'More than one Runtime Profile belongs to this Skill',
        detail: 'Profiles: ${profiles.map((entry) => '${entry.name} (${entry.id})').join(', ')}',
        source: 'runtime_profile records with scope=extension and ownerId=${skill.record.id}',
        fix: 'Select the intended Profile in the Skill execution flow and record fresh readiness evidence for that Profile.',
      ));
    }

    if (needsProfile && profiles.isEmpty) {
      issues.add(_issue(
        id: 'runtime-profile-missing',
        severity: 'critical',
        category: 'runtime_profile',
        title: 'Executable Skill has no owned Runtime Profile',
        detail: 'Executable local-script or CLI capabilities require a Profile with scope=extension and ownerId=${skill.record.id}.',
        source: 'RuntimeProfileService.list(scope: extension)',
        fix: 'Create a Runtime Profile for this Skill and enable the required Python, Node.js or Shell ecosystem.',
      ));
    }

    final requiredEcosystems = SkillDoctorPolicy.requiredEcosystems(requirements);
    if (profile != null) {
      if (profile.status != RuntimeProfileStatus.ready) {
        issues.add(_issue(
          id: 'runtime-profile-${profile.status.name}',
          severity: 'critical',
          category: 'runtime_profile',
          title: 'Skill Runtime Profile is not ready',
          detail: '${profile.name}: ${profile.status.name}${profile.lastError == null ? '' : ' — ${profile.lastError}'}',
          source: 'runtime_profile:${profile.id}.status',
          fix: 'Open Runtime Profiles, inspect the Profile error and provision or repair the selected ecosystems.',
        ));
      }
      final missingEcosystems = requiredEcosystems.difference(profile.ecosystems);
      if (missingEcosystems.isNotEmpty) {
        issues.add(_issue(
          id: 'runtime-profile-ecosystems-missing',
          severity: 'warning',
          category: 'runtime_profile',
          title: 'Runtime Profile does not enable every required ecosystem',
          detail: 'Missing: ${missingEcosystems.map((item) => item.name).join(', ')}.',
          source: 'runtime_profile:${profile.id}.ecosystems',
          fix: 'Update the Profile to include the required ecosystem, then provision it again.',
        ));
      }
    }

    final commandEntries = (requirements['commands'] as List? ?? const [])
        .whereType<Map>().map((entry) => Map<String, Object?>.from(entry)).toList();
    final invalidCommands = commandEntries
        .map((entry) => entry['name']?.toString() ?? '')
        .where((name) => !SkillDoctorPolicy.isSafeCommandName(name))
        .toSet()
        .toList(growable: false);
    if (invalidCommands.isNotEmpty) {
      issues.add(_issue(
        id: 'commands-invalid-name',
        severity: 'critical',
        category: 'security',
        title: 'A declared command name is not safe to probe',
        detail: invalidCommands.take(20).join(', '),
        source: 'import manifest requirements.commands[].name',
        fix: 'Review the command declaration in the original Skill source. Doctor will not pass shell metacharacters or path expressions to command -v.',
      ));
    }
    // A previous import/inspection may have left command results in the
    // manifest. Never reuse them as current evidence; this scan repopulates
    // statuses only from its own bounded Profile probe.
    for (final command in commandEntries) {
      command
        ..remove('status')
        ..remove('verifiedIn')
        ..remove('resolvedPath');
    }
    final profileProbe = <String, Object?>{'status': 'not_run'};
    if (profile != null &&
        profile.status == RuntimeProfileStatus.ready &&
        runtimeStatus?.ready == true &&
        runtimeStatus?.sandboxed == true &&
        runtimeStatus?.engine == 'proot' &&
        commandEntries.isNotEmpty) {
      try {
        final probe = await runtimeProfiles.inspectSkillProfileCommands(
          skillId: skill.record.id,
          profileId: profile.id,
          commandNames: commandEntries.map((item) => item['name']?.toString() ?? ''),
        );
        profileProbe.addAll(probe);
        final probedCommands = (probe['commands'] as List? ?? const [])
            .whereType<Map>().map((entry) => Map<String, Object?>.from(entry));
        for (final result in probedCommands) {
          final name = result['name'];
          for (final command in commandEntries.where((entry) => entry['name'] == name)) {
            command
              ..['status'] = result['status']
              ..remove('verifiedIn');
            if (result['verifiedIn'] != null) {
              command['verifiedIn'] = result['verifiedIn'];
            }
            if (result['path'] != null) command['resolvedPath'] = result['path'];
          }
        }
      } catch (error) {
        profileProbe['status'] = 'failed';
        profileProbe['errorType'] = error.runtimeType.toString();
      }
    } else if (needsProfile && profile != null) {
      profileProbe['status'] = runtimeStatus?.ready == true
          ? 'not_run_profile_or_runtime_unavailable'
          : 'runtime_unavailable';
    }

    if (profileProbe['status'] == 'completed') {
      final commandResults = (profileProbe['commands'] as List? ?? const []).whereType<Map>();
      final missing = commandResults.where((entry) => entry['status'] == 'missing').map((entry) => entry['name']).join(', ');
      final baseOnly = commandResults.where((entry) => entry['verifiedIn'] == 'base_proot_environment').map((entry) => entry['name']).join(', ');
      if (missing.isNotEmpty) {
        issues.add(_issue(
          id: 'commands-missing',
          severity: 'critical',
          category: 'dependency',
          title: 'Required commands are missing from the Skill execution PATH',
          detail: missing,
          source: 'Runtime Profile ${profile?.id} command -v probe',
          fix: 'Install the required command through an approved package workflow or add its provider adapter, then rescan.',
        ));
      }
      if (baseOnly.isNotEmpty) {
        issues.add(_issue(
          id: 'commands-base-only',
          severity: 'warning',
          category: 'dependency',
          title: 'Some commands are available only from shared RootFS paths',
          detail: baseOnly,
          source: 'Runtime Profile PATH lookup',
          fix: 'Review whether the shared system binary is acceptable; a base RootFS command is not an isolated Profile package.',
        ));
      }
    } else if (needsProfile && profile != null) {
      issues.add(_issue(
        id: 'profile-command-probe-not-completed',
        severity: 'warning',
        category: 'dependency',
        title: 'Runtime Profile command verification was not completed',
        detail: 'Probe status: ${profileProbe['status']}.',
        source: 'RuntimeProfileService.inspectSkillProfileCommands',
        fix: 'Ensure the Skill-owned Profile is ready and Android PRoot is available, then rescan.',
      ));
    }

    final packages = (requirements['packages'] as List? ?? const []).whereType<Map>();
    for (final package in packages) {
      final name = package['name']?.toString() ?? 'unknown';
      final ecosystem = package['ecosystem']?.toString() ?? 'unknown';
      final supported = package['managerSupported'] == true;
      issues.add(_issue(
        id: 'package-${ecosystem}-$name',
        severity: 'warning',
        category: 'dependency',
        title: supported ? 'Package dependency is not verified as installed' : 'Package ecosystem is not managed by the current resolver',
        detail: '$ecosystem: $name; status=${package['status'] ?? 'not_checked'}.',
        source: package['manifestPath']?.toString() ?? package['evidence']?.toString() ?? 'requirements.packages',
        fix: supported
            ? 'Use the isolated Profile package manager, retain a lockfile and verify the installed package without running Skill lifecycle scripts.'
            : 'Add a reviewed package-manager adapter for $ecosystem or document a safe manual setup path.',
      ));
    }

    final configuredNames = environment.variables.map((variable) => variable.name).toSet();
    final credentials = (requirements['credentials'] as List? ?? const [])
        .whereType<Map>().map((entry) => Map<String, Object?>.from(entry)).toList();
    for (final credential in credentials) {
      final name = credential['name']?.toString() ?? '';
      final configured = configuredNames.contains(name);
      credential['status'] = configured
          ? 'configured_but_not_granted_to_skill'
          : 'missing_configuration';
      issues.add(_issue(
        id: 'credential-$name',
        severity: configured ? 'info' : 'warning',
        category: 'configuration',
        title: configured ? 'Credential is configured but not granted to this Skill' : 'Required credential is not configured',
        detail: configured
            ? '$name exists in KELIVO settings. Its secret value was not read or injected; the current executor has no scoped secret-grant adapter.'
            : 'Missing configuration name: $name.',
        source: credential['evidence']?.toString() ?? 'requirements.credentials',
        fix: configured
            ? 'Do not assume the Skill can read this credential. Add an explicit, scoped secret-grant adapter before treating it as configured for execution.'
            : 'Add the required credential through the secure settings flow; never place secret values in SKILL.md or ZIP files.',
      ));
    }

    for (final service in (requirements['externalServices'] as List? ?? const []).whereType<Map>()) {
      final name = service['name']?.toString() ?? 'unknown';
      if (service['verification'] != 'verified' && service['status'] != 'verified') {
        issues.add(_issue(
          id: 'external-service-$name',
          severity: 'warning',
          category: 'integration',
          title: 'External service connection has not been verified',
          detail: 'Service: $name. Doctor does not call external APIs.',
          source: service['evidence']?.toString() ?? 'requirements.externalServices',
          fix: 'Configure a reviewed connector and run its explicit approved connection test.',
        ));
      }
    }

    final readinessRequirements = SkillDoctorPolicy.readinessRequirements({
      ...requirements,
      'commands': commandEntries,
      'credentials': credentials,
    });

    final capabilityAssessment = SkillCapabilityRegistry.assessRequirements(readinessRequirements);
    final capabilityResults = (capabilityAssessment['requiredCapabilities'] as List? ?? const [])
        .whereType<Map>();
    for (final capability in capabilityResults) {
      final status = capability['status']?.toString() ?? 'unknown';
      if (status == 'supported' || status == 'verified_in_skill_runtime_profile') continue;
      issues.add(_issue(
        id: 'capability-${capability['skillCapabilityId'] ?? capability['kind']}',
        severity: status == 'unknown' ? 'critical' : 'warning',
        category: 'capability',
        title: 'Capability is not operationally verified',
        detail: '${capability['title'] ?? capability['kind']}: $status. ${capability['scope'] ?? ''}',
        source: 'requirements.capabilities / SkillCapabilityRegistry',
        fix: _capabilityFix(status, capability['kind']?.toString() ?? 'unknown'),
      ));
    }

    final readiness = SkillReadinessEngine.apply(
      requirements: readinessRequirements,
      importCompleteness: completeness,
      validation: const <String, Object?>{},
    );

    if (!skill.record.enabled) {
      issues.add(_issue(
        id: 'skill-disabled',
        severity: 'info',
        category: 'configuration',
        title: 'Skill is disabled',
        detail: 'This Skill is installed but currently disabled.',
        source: 'skill record enabled=false',
        fix: 'Enable the Skill in the Skills library when it is intended for use.',
      ));
    }
    if (issues.isEmpty) {
      issues.add(_issue(
        id: 'no-current-findings',
        severity: 'info',
        category: 'status',
        title: 'No issues were detected by the current checks',
        detail: 'This is not proof that every Skill capability works; execution readiness still requires a Skill-specific output validation.',
        source: 'Skill Doctor read-only scan',
        fix: 'Run PHASE13P end-to-end validation for the capabilities that must be executable.',
      ));
    }

    final counts = <String, int>{
      for (final severity in const ['critical', 'warning', 'info'])
        severity: issues.where((issue) => issue['severity'] == severity).length,
    };
    return <String, Object?>{
      'id': skill.record.id,
      'name': skill.name,
      'description': skill.description,
      'enabled': skill.record.enabled,
      'source': skill.record.source.name,
      'installedAt': skill.record.installedAt.toUtc().toIso8601String(),
      'skillDirectory': skill.dir,
      'skillMarkdown': skill.skillMdPath,
      'importCompleteness': completeness,
      'integrity': integrity,
      'runtimeProfile': profile == null ? null : <String, Object?>{
        'id': profile.id,
        'name': profile.name,
        'status': profile.status.name,
        'scope': profile.scope.name,
        'ownerId': profile.ownerId,
        'ecosystems': profile.ecosystems.map((item) => item.name).toList()..sort(),
        'shareBaseTools': profile.shareBaseTools,
      },
      'runtimeProfileCandidates': profiles.map((item) => <String, Object?>{
        'id': item.id,
        'name': item.name,
        'status': item.status.name,
        'ecosystems': item.ecosystems.map((value) => value.name).toList()..sort(),
      }).toList(growable: false),
      'profileProbe': profileProbe,
      'readiness': readiness,
      'readinessLevel': readiness['readinessLevel'] ?? 'not_ready',
      'readinessLabel': readiness['readinessLevelLabel'] ?? 'Not Ready',
      'readinessState': readiness['readinessState'] ?? 'analysis_required',
      'capabilityCount': capabilities.length,
      'requiresRuntimeProfile': needsProfile,
      'issues': issues,
      'issueCounts': counts,
    };
  }

  Future<Map<String, Object?>> _verifyManifestFiles(
    Skill skill,
    Map<String, Object?> report,
  ) async {
    final rawEntries = report['files'];
    if (rawEntries is! List) return <String, Object?>{'status': 'inconclusive', 'reason': 'manifest_files_list_missing'};
    if (rawEntries.length > _maxManifestFiles) return <String, Object?>{'status': 'inconclusive', 'reason': 'manifest_file_count_limit'};
    final metadataEntries = rawEntries.whereType<Map>().map((entry) => Map<String, Object?>.from(entry)).toList();
    final changed = <String>[];
    final missing = <String>[];
    final unsafe = <String>[];
    final untracked = <String>[];
    final canonical = <String>[];
    final expectedLocalPaths = <String>{};
    var totalBytes = 0;
    Directory? sharedDirectory;
    final shared = report['sharedResources'];
    if (shared is Map && shared['setId'] is String) {
      final setId = shared['setId'].toString();
      if (RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(setId)) {
        final root = await AppDirectories.getSkillImportMetadataDirectory();
        sharedDirectory = Directory(p.join(root.path, 'repositories', setId, 'shared'));
      }
    }

    for (final entry in metadataEntries) {
      final relative = entry['path']?.toString() ?? '';
      final normalized = relative.replaceAll('\\', '/');
      if (normalized.isEmpty ||
          p.posix.isAbsolute(normalized) ||
          p.posix.normalize(normalized) != normalized ||
          p.posix.split(normalized).any((part) => part == '..' || part == '.')) {
        unsafe.add(relative.isEmpty ? '<empty-path>' : relative);
        continue;
      }
      final scope = entry['scope']?.toString() ?? 'skill';
      String hostPath;
      if (scope == 'shared') {
        final sourcePath = entry['sourcePath']?.toString() ?? normalized.replaceFirst(RegExp(r'^shared/'), '');
        if (sharedDirectory == null ||
            sourcePath.isEmpty ||
            p.posix.isAbsolute(sourcePath) ||
            p.posix.normalize(sourcePath) != sourcePath ||
            p.posix.split(sourcePath).any((part) => part == '..' || part == '.')) {
          unsafe.add(relative);
          continue;
        }
        hostPath = p.joinAll([sharedDirectory.path, ...sourcePath.split('/')]);
      } else if (scope == 'skill') {
        expectedLocalPaths.add(normalized);
        hostPath = p.joinAll([skill.dir, ...normalized.split('/')]);
      } else {
        unsafe.add('$relative (unknown scope=$scope)');
        continue;
      }
      final entityType = await FileSystemEntity.type(hostPath, followLinks: false);
      if (entityType == FileSystemEntityType.link) {
        unsafe.add(relative);
        continue;
      }
      if (entityType != FileSystemEntityType.file) {
        missing.add(relative);
        continue;
      }
      final file = File(hostPath);
      final stat = await file.stat();
      totalBytes += stat.size;
      if (totalBytes > _maxManifestBytes || stat.size > _maxFileBytes) {
        return <String, Object?>{
          'status': 'inconclusive',
          'reason': 'manifest_size_limit_exceeded',
          'checkedFiles': canonical.length,
          'changed': changed,
          'missing': missing,
          'unsafe': unsafe,
          'untracked': untracked,
        };
      }
      final expectedSize = entry['sizeBytes'];
      final expectedHash = entry['sha256']?.toString() ?? '';
      final digest = await sha256.bind(file.openRead()).first;
      final actualHash = 'sha256:$digest';
      if (expectedSize is num && expectedSize.toInt() != stat.size || expectedHash != actualHash) {
        changed.add(relative);
      }
      canonical.add('$relative\u0000${stat.size}\u0000$actualHash');
    }

    if (await Directory(skill.dir).exists()) {
      try {
        var count = 0;
        await for (final entity in Directory(skill.dir).list(recursive: true, followLinks: false)) {
          if (entity is Directory) continue;
          count++;
          if (count > _maxManifestFiles) {
            return <String, Object?>{'status': 'inconclusive', 'reason': 'current_file_count_limit'};
          }
          if (entity is Link) {
            final relative = p.relative(entity.path, from: skill.dir).replaceAll('\\', '/');
            unsafe.add(relative);
            continue;
          }
          if (entity is! File) continue;
          final relative = p.relative(entity.path, from: skill.dir).replaceAll('\\', '/');
          if (!expectedLocalPaths.contains(relative)) {
            untracked.add(relative);
          }
        }
      } catch (_) {
        return <String, Object?>{'status': 'inconclusive', 'reason': 'directory_enumeration_failed'};
      }
    }
    final expectedDigest = report['sourceDigest']?.toString();
    canonical.sort();
    final currentDigest = 'sha256:${sha256.convert(utf8.encode(canonical.join('\n')))}';
    final digestMatches = expectedDigest == null
        ? null
        : currentDigest == expectedDigest;
    if (digestMatches == false && changed.isEmpty && missing.isEmpty && unsafe.isEmpty) {
      changed.add('<manifest digest mismatch>');
    }
    final status = unsafe.isNotEmpty
        ? 'unsafe'
        : missing.isNotEmpty
            ? 'missing'
            : changed.isNotEmpty
                ? 'changed'
                : 'passed';
    return <String, Object?>{
      'status': status,
      'checkedFiles': canonical.length,
      'expectedDigest': expectedDigest,
      'currentDigest': currentDigest,
      'digestMatches': digestMatches,
      'changed': changed,
      'missing': missing,
      'unsafe': unsafe,
      'untracked': untracked,
    };
  }

  List<Map<String, Object?>> _inspectProcessHistory(List<RuntimeProfile> profiles) {
    final byId = {for (final profile in profiles) profile.id: profile};
    final failedRecords = runtimeProfiles.processHistory().where((record) =>
        byId.containsKey(record.profileId) &&
        (record.status == RuntimeProcessStatus.failed ||
            record.status == RuntimeProcessStatus.interrupted ||
            record.status == RuntimeProcessStatus.timedOut)).toList(growable: false);
    final issues = <Map<String, Object?>>[];
    for (final record in failedRecords.take(_maxProcessHistoryFindings)) {
      final profile = byId[record.profileId]!;
      final errorDetail = record.error == null
          ? record.commandLabel
          : 'An execution error was recorded.';
      issues.add(_issue(
        id: 'process-${record.runId}',
        severity: record.status == RuntimeProcessStatus.interrupted ? 'warning' : 'info',
        category: 'execution_history',
        title: 'A previous Profile run did not complete successfully',
        detail: '${profile.name}: ${record.status.name}; $errorDetail',
        source: 'runtime_process:${record.id}',
        fix: 'Review the run output and resume hint before retrying. The Doctor does not rerun interrupted tasks.',
      ));
    }
    if (failedRecords.length > _maxProcessHistoryFindings) {
      issues.add(_issue(
        id: 'process-history-truncated',
        severity: 'info',
        category: 'execution_history',
        title: 'Execution history findings were limited',
        detail: 'Showing the latest $_maxProcessHistoryFindings of ${failedRecords.length} failed or interrupted Profile runs.',
        source: 'RuntimeProfileService.processHistory()',
        fix: 'Open the Runtime Profile manager for the full run history.',
      ));
    }
    return issues;
  }

  static Map<String, Object?> _issue({
    required String id,
    required String severity,
    required String category,
    required String title,
    required String detail,
    required String source,
    required String fix,
  }) => <String, Object?>{
    'id': id,
    'severity': severity,
    'category': category,
    'title': title,
    'detail': detail,
    'source': source,
    'suggestedFix': fix,
  };

  static String _capabilityFix(String status, String kind) {
    if (status == 'not_operational_in_current_skill_adapter') {
      return 'Implement and register a reviewed $kind adapter with permission checks and focused tests. Skill metadata alone cannot add executable application code.';
    }
    if (status == 'detected_in_base_environment_only') {
      return 'Provision and verify this dependency inside the Skill-owned Runtime Profile; base RootFS detection is not Profile-level proof.';
    }
    if (status == 'requires_runtime_profile_and_approval') {
      return 'Provision the owned Runtime Profile, request the required approval for execution, and record a Skill-specific validation result.';
    }
    return 'Review the capability declaration and implement a reviewed adapter or provide fresh runtime evidence.';
  }
}

abstract final class SkillDoctorPolicy {
  /// Returns a conservative, scan-local view for readiness assessment.
  /// Previously persisted Profile verification may be stale; discovery by
  /// Skill Doctor is not an end-to-end capability validation and must never
  /// inherit that old approval/evidence.
  static Map<String, Object?> readinessRequirements(
    Map<String, Object?> requirements,
  ) {
    final result = Map<String, Object?>.from(requirements);
    result.remove('runtimeProfileVerification');
    return result;
  }

  static bool isSafeCommandName(String value) =>
      RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.+-]{0,127}$').hasMatch(value.trim());

  static bool requiresRuntimeProfile(Map<String, Object?> requirements) {
    final capabilities = (requirements['capabilities'] as List? ?? const []).whereType<Map>();
    return capabilities.any((capability) =>
        capability['kind'] == 'local_script' || capability['kind'] == 'cli_binary');
  }

  static Set<RuntimeProfileEcosystem> requiredEcosystems(
    Map<String, Object?> requirements,
  ) {
    final result = <RuntimeProfileEcosystem>{};
    final capabilities = (requirements['capabilities'] as List? ?? const []).whereType<Map>();
    for (final capability in capabilities) {
      final kind = capability['kind'];

      // A filename is runtime evidence only for capability kinds that the
      // current SkillExecutor can launch as local scripts. MCP, HTTP/API,
      // Workflow and native-tool descriptors may contain source/reference
      // files, but those names do not authorize or imply a local runtime.
      if (kind == 'cli_binary') {
        result.add(RuntimeProfileEcosystem.shell);
        continue;
      }
      if (kind != 'local_script') continue;

      final entries = (capability['entryPoints'] as List? ?? const [])
          .whereType<String>();
      for (final raw in entries) {
        switch (p.posix.extension(raw).toLowerCase()) {
          case '.py':
            result.add(RuntimeProfileEcosystem.python);
            break;
          case '.js':
          case '.mjs':
          case '.cjs':
            result.add(RuntimeProfileEcosystem.node);
            break;
          case '.sh':
          case '.bash':
          case '.zsh':
            result.add(RuntimeProfileEcosystem.shell);
            break;
        }
      }
    }
    return result;
  }
}
