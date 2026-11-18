import 'dart:convert';

import '../extensions/extension_registry_repository.dart';
import 'skill_composition_planner.dart';
import 'skill_capability_registry.dart';
import 'skill_readiness.dart';
import 'skills_service.dart';

/// Loads the metadata required for planning and only returns full instructions
/// for Skills that survive selection, dependency and context-budget checks.
final class SkillCompositionService {
  SkillCompositionService({
    required this.skills,
    required this.registry,
  });

  final SkillsService skills;
  final ExtensionRegistryRepository registry;

  Future<String> compose({
    required String task,
    required List<Skill> availableSkills,
    required SkillCompositionMode mode,
    Iterable<String> requestedSkillIds = const <String>[],
    Iterable<String> excludedSkillIds = const <String>[],
    Iterable<String> assistantDefaultSkillIds = const <String>[],
    Iterable<String> projectDefaultSkillIds = const <String>[],
    Iterable<String> conversationSkillIds = const <String>[],
    int contextBudgetTokens = SkillCompositionPlanner.defaultContextBudgetTokens,
    bool allowParallel = true,
    Map<String, String> pinnedDigests = const <String, String>{},
    String platform = 'android',
  }) async {
    await skills.loaded;
    if (availableSkills.length > 64) {
      return jsonEncode({
        'status': 'blocked',
        'issues': [
          {
            'code': 'candidate_limit',
            'severity': 'error',
            'message': 'At most 64 enabled Skills can be considered in one composition request.',
          },
        ],
      });
    }

    final candidates = <SkillCompositionCandidate>[];
    for (final skill in availableSkills) {
      final markdown = await skills.readSkillMarkdown(
        skill.record.id,
        maxCharacters: 64000,
      );
      final extension = await registry.get('skill', skill.record.id);
      Map<String, Object?>? importReport;
      try {
        importReport = await skills.getImportReport(skill.record.id);
      } catch (error) {
        importReport = <String, Object?>{
          'completeness': 'unknown',
          'completenessNotes': <String>[
            'The import report could not be read: ${error.runtimeType}.',
          ],
        };
      }
      final rawNotes = importReport?['completenessNotes'];
      final completenessNotes = rawNotes is List
          ? rawNotes.whereType<String>().toList(growable: false)
          : const <String>[];
      final rawCompleteness = importReport?['completeness'];
      final completeness = rawCompleteness is String && rawCompleteness.isNotEmpty
          ? rawCompleteness
          : 'unknown';
      candidates.add(
        SkillCompositionCandidate(
          skill: skill,
          markdown: markdown,
          digest: extension?.digest,
          instructionsTruncated: markdown.contains(
            '[Skill instructions truncated by Kelivo inspection limit.]',
          ),
          completeness: completeness,
          completenessNotes: completenessNotes,
        ),
      );
    }

    final plan = SkillCompositionPlanner.plan(
      task: SkillCompositionPlanner.compactTaskBrief(task),
      candidates: candidates,
      mode: mode,
      requestedSkillIds: requestedSkillIds,
      excludedSkillIds: excludedSkillIds,
      assistantDefaultSkillIds: assistantDefaultSkillIds,
      projectDefaultSkillIds: projectDefaultSkillIds,
      conversationSkillIds: conversationSkillIds,
      contextBudgetTokens: contextBudgetTokens,
      allowParallel: allowParallel,
      pinnedDigests: pinnedDigests,
      platform: platform,
    );
    final result = Map<String, Object?>.from(plan.toJson());
    final selectedRequirements = <String, Object?>{};
    final selectedReadiness = <String, Object?>{};
    for (final id in plan.selectedIds) {
      final report = await skills.getImportReportWithRequirements(id);
      final raw = report?['requirements'];
      if (raw is Map) {
        selectedRequirements[id] = Map<String, Object?>.from(raw);
      } else {
        selectedRequirements[id] = <String, Object?>{
          'readiness': 'not_available',
          'notes': <String>[
            'No environment requirement inventory exists for this legacy Skill. Run extension_inspect before relying on scripts or external capabilities.',
          ],
        };
      }
      selectedReadiness[id] = report == null
          ? <String, Object?>{
              'readinessState': 'analysis_required',
              'sourceCurrent': false,
              'environmentMustBeRecheckedBeforeExecution': true,
              'nextActions': <String>['Run extension_inspect to inspect and assess this Skill.'],
            }
          : SkillReadinessEngine.compositionSnapshot(report);
    }
    result['selectedSkillRequirements'] = selectedRequirements;
    result['selectedSkillReadiness'] = selectedReadiness;
    result['capabilityRegistry'] = SkillCapabilityRegistry.catalogJson();
    result['requirementPolicy'] = <String, Object?>{
      'mode': 'discovery_before_execution',
      'requirementsAreProofOfReadiness': false,
      'missingOrUnsupportedRequirementsBlockClaimsOfOperationalReadiness': true,
      'readinessRequiresProfileLevelDependencyEvidenceAndPassedValidation': true,
      'instructionOnlyReadinessDoesNotImplyExecutableCapabilities': true,
      'savedAssessmentsMustMatchCurrentSkillSourceDigest': true,
      'environmentMustBeRecheckedBeforeExecution': true,
      'automaticInstallationPerformed': false,
      'scriptsExecuted': false,
      'externalServicesContacted': false,
      'instruction': 'Review selectedSkillRequirements and selectedSkillReadiness for every selected Skill. A saved assessment is only a source-bound snapshot, not proof that the current environment has not changed; call extension_inspect for a fresh read-only check before relying on executable capabilities. Only readinessLevel=fully_ready can be described as fully ready. readinessLevel=ready_for_execution permits only individually tested capabilities with their recorded evidence from a passed Skill-specific validation; never extend that claim to untested capabilities. readinessLevel=ready_for_guidance permits written guidance only. If a package, runtime, credential, external service, or Kelivo adapter is missing or unsupported, explain the exact environment/application work required and do not claim execution support.',
    };
    return jsonEncode(result);
  }
}
