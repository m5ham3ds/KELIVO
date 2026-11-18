import 'skill.dart';
import 'skill_frontmatter.dart';

/// Selection policy for a multi-Skill composition request.
enum SkillCompositionMode {
  automatic,
  explicit,
  allEnabled,
  assistantDefault,
  projectDefault,
  conversationOverride;

  static SkillCompositionMode parse(Object? value) {
    switch (value) {
      case 'explicit':
        return SkillCompositionMode.explicit;
      case 'all_enabled':
      case 'all-enabled':
        return SkillCompositionMode.allEnabled;
      case 'assistant_default':
        return SkillCompositionMode.assistantDefault;
      case 'project_default':
        return SkillCompositionMode.projectDefault;
      case 'conversation_override':
        return SkillCompositionMode.conversationOverride;
      case 'auto':
      case 'automatic':
      case null:
      case '':
        return SkillCompositionMode.automatic;
      default:
        throw const FormatException('invalid_skill_composition_mode');
    }
  }

  String get wireValue => switch (this) {
    SkillCompositionMode.automatic => 'automatic',
    SkillCompositionMode.explicit => 'explicit',
    SkillCompositionMode.allEnabled => 'all_enabled',
    SkillCompositionMode.assistantDefault => 'assistant_default',
    SkillCompositionMode.projectDefault => 'project_default',
    SkillCompositionMode.conversationOverride => 'conversation_override',
  };
}

enum SkillCompositionIssueSeverity { info, warning, error }

class SkillCompositionIssue {
  const SkillCompositionIssue({
    required this.code,
    required this.severity,
    required this.message,
    this.skillIds = const <String>[],
  });

  final String code;
  final SkillCompositionIssueSeverity severity;
  final String message;
  final List<String> skillIds;

  Map<String, Object?> toJson() => {
    'code': code,
    'severity': severity.name,
    'message': message,
    if (skillIds.isNotEmpty) 'skillIds': skillIds,
  };
}

class SkillCompositionCandidate {
  const SkillCompositionCandidate({
    required this.skill,
    required this.markdown,
    this.digest,
    this.instructionsTruncated = false,
    this.completeness = 'complete',
    this.completenessNotes = const <String>[],
  });

  final Skill skill;
  final String markdown;
  final String? digest;
  final bool instructionsTruncated;
  /// Import-manifest completeness; missing legacy manifests are `unknown`.
  final String completeness;
  final List<String> completenessNotes;

  String get id => skill.record.id;
  SkillFrontmatter get frontmatter => SkillFrontmatter.parse(markdown);
}

class SkillCompositionEdge {
  const SkillCompositionEdge({
    required this.from,
    required this.to,
    required this.reason,
    this.artifact,
  });

  final String from;
  final String to;
  final String reason;
  final String? artifact;

  Map<String, Object?> toJson() => {
    'from': from,
    'to': to,
    'reason': reason,
    if (artifact != null) 'artifact': artifact,
  };
}

class SkillCompositionPlan {
  const SkillCompositionPlan({
    required this.mode,
    required this.task,
    required this.selectedIds,
    required this.automaticallyAddedIds,
    required this.scores,
    required this.selectionReasons,
    required this.edges,
    required this.stages,
    required this.inputs,
    required this.outputs,
    required this.issues,
    required this.contextBudgetTokens,
    required this.instructionTokens,
    required this.instructions,
    required this.pinnedDigests,
    required this.requestedPermissions,
  });

  final SkillCompositionMode mode;
  final String task;
  final List<String> selectedIds;
  final List<String> automaticallyAddedIds;
  final Map<String, double> scores;
  final Map<String, String> selectionReasons;
  final List<SkillCompositionEdge> edges;
  final List<List<String>> stages;
  final Map<String, List<String>> inputs;
  final Map<String, List<String>> outputs;
  final List<SkillCompositionIssue> issues;
  final int contextBudgetTokens;
  final int instructionTokens;
  final Map<String, String> instructions;
  final Map<String, String> pinnedDigests;
  final List<String> requestedPermissions;

  bool get isBlocked => issues.any(
    (issue) => issue.severity == SkillCompositionIssueSeverity.error,
  );

  String get status => isBlocked
      ? 'blocked'
      : issues.any(
          (issue) => issue.severity == SkillCompositionIssueSeverity.warning,
        )
      ? 'ready_with_warnings'
      : 'ready';

  Map<String, Object?> toJson() => {
    'status': status,
    'mode': mode.wireValue,
    'task': task,
    'selectedSkillIds': selectedIds,
    'automaticallyAddedSkillIds': automaticallyAddedIds,
    'selectionScores': scores,
    'selectionReasons': selectionReasons,
    'executionStrategy': stages.every((stage) => stage.length == 1)
        ? 'sequential'
        : 'dependency_aware_parallel',
    'executionStages': [
      for (var index = 0; index < stages.length; index++)
        {
          'stage': index + 1,
          'parallel': stages[index].length > 1,
          'skillIds': stages[index],
        },
    ],
    'dependencyEdges': [for (final edge in edges) edge.toJson()],
    'artifactContracts': {
      'inputs': inputs,
      'outputs': outputs,
      'transferRule':
          'Pass artifact references/paths between stages; do not paste large artifacts into conversation text.',
    },
    'contextBudget': {
      'budgetTokens': contextBudgetTokens,
      'estimatedInstructionTokens': instructionTokens,
      'instructionsIncluded': instructions.isNotEmpty,
      'estimator': 'ceil(Unicode code points / 2); conservative heuristic, not a provider tokenizer',
    },
    'pinnedDigests': pinnedDigests,
    'requestedPermissions': requestedPermissions,
    'issues': [for (final issue in issues) issue.toJson()],
    'executionSafety': {
      'scriptsExecuted': false,
      'dependenciesInstalled': false,
      'externalCommandsRun': false,
      'skillInstructionsAreUntrustedContent': true,
      'note':
          'This is a composition plan only. Follow selected SKILL.md instructions through separately approved Kelivo tools; never execute bundled scripts or install dependencies automatically.',
    },
    if (!isBlocked && instructions.isNotEmpty)
      'selectedSkillInstructions': instructions,
  };
}

/// Deterministic planner for selecting Skills and building an execution DAG.
///
/// Kelivo-specific contracts use the standard Agent Skills `metadata` string
/// map with namespaced keys. The imported SKILL.md format is never rewritten.
abstract final class SkillCompositionPlanner {
  static const int defaultContextBudgetTokens = 6000;
  static const int maxContextBudgetTokens = 32000;
  static const int maxSelectedSkills = 64;
  static const int maxTaskCharacters = 8000;

  /// Normalize a task into the planner's character budget without ever
  /// forwarding a full conversation transcript. For oversized briefs, the
  /// opening (where the goal is commonly stated) and ending (where constraints
  /// and acceptance criteria commonly live) are retained around a clear
  /// omission marker. Uses Unicode code points rather than UTF-16 code units.
  static String compactTaskBrief(String task) {
    final normalized = task.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
    final points = normalized.runes.toList(growable: false);
    if (points.length <= maxTaskCharacters) return normalized;
    const marker = '\n\n[Middle of task brief omitted to meet the 8000-character limit.]\n\n';
    final remaining = maxTaskCharacters - marker.runes.length;
    final headCount = (remaining * 0.64).floor();
    final tailCount = remaining - headCount;
    return String.fromCharCodes([
      ...points.take(headCount),
      ...marker.runes,
      ...points.skip(points.length - tailCount),
    ]).trim();
  }

  static const Set<String> _stopWords = {
    'a', 'an', 'and', 'are', 'as', 'at', 'be', 'by', 'can', 'create',
    'do', 'for', 'from', 'how', 'i', 'in', 'into', 'is', 'it', 'make',
    'me', 'my', 'of', 'on', 'or', 'please', 'the', 'to', 'using', 'with',
    'you', 'your', 'في', 'من', 'على', 'الى', 'إلى', 'عن', 'مع', 'هذا',
    'هذه', 'كيف', 'ما', 'هو', 'هي', 'قم', 'اعمل', 'استخدم', 'لي',
  };

  static SkillCompositionPlan plan({
    required String task,
    required List<SkillCompositionCandidate> candidates,
    required SkillCompositionMode mode,
    Iterable<String> requestedSkillIds = const <String>[],
    Iterable<String> excludedSkillIds = const <String>[],
    Iterable<String> assistantDefaultSkillIds = const <String>[],
    Iterable<String> projectDefaultSkillIds = const <String>[],
    Iterable<String> conversationSkillIds = const <String>[],
    int contextBudgetTokens = defaultContextBudgetTokens,
    bool allowParallel = true,
    Map<String, String> pinnedDigests = const <String, String>{},
    String platform = 'android',
  }) {
    final issues = <SkillCompositionIssue>[];
    final normalizedTask = compactTaskBrief(task);
    if (normalizedTask.isEmpty || normalizedTask.runes.length > maxTaskCharacters) {
      issues.add(
        const SkillCompositionIssue(
          code: 'invalid_task',
          severity: SkillCompositionIssueSeverity.error,
          message: 'Task must contain 1 to 8000 characters.',
        ),
      );
    }
    if (contextBudgetTokens < 500 ||
        contextBudgetTokens > maxContextBudgetTokens) {
      issues.add(
        const SkillCompositionIssue(
          code: 'invalid_context_budget',
          severity: SkillCompositionIssueSeverity.error,
          message: 'Context budget must be between 500 and 32000 tokens.',
        ),
      );
    }

    final byId = <String, SkillCompositionCandidate>{};
    for (final candidate in candidates) {
      if (byId.containsKey(candidate.id)) {
        issues.add(
          SkillCompositionIssue(
            code: 'duplicate_candidate_id',
            severity: SkillCompositionIssueSeverity.error,
            message: 'Duplicate Skill id: ${candidate.id}.',
            skillIds: [candidate.id],
          ),
        );
      } else {
        byId[candidate.id] = candidate;
      }
    }

    final excluded = excludedSkillIds.map((id) => id.trim()).where(
      (id) => id.isNotEmpty,
    ).toSet();
    final requested = requestedSkillIds.map((id) => id.trim()).where(
      (id) => id.isNotEmpty,
    ).toSet();
    final defaults = assistantDefaultSkillIds.toSet();
    final projectDefaults = projectDefaultSkillIds.toSet();
    final conversation = conversationSkillIds.toSet();

    final scores = <String, double>{
      for (final candidate in candidates)
        candidate.id: _score(normalizedTask, candidate),
    };
    final roots = <String>{};
    switch (mode) {
      case SkillCompositionMode.automatic:
        final ranked = candidates.toList()
          ..sort((a, b) {
            final score = (scores[b.id] ?? 0).compareTo(scores[a.id] ?? 0);
            return score != 0 ? score : a.id.compareTo(b.id);
          });
        for (final candidate in ranked) {
          final score = scores[candidate.id] ?? 0;
          if (score <= 0 || roots.length >= 6) continue;
          if (!excluded.contains(candidate.id)) roots.add(candidate.id);
        }
        break;
      case SkillCompositionMode.explicit:
        roots.addAll(requested);
        if (roots.isEmpty) {
          issues.add(
            const SkillCompositionIssue(
              code: 'explicit_selection_required',
              severity: SkillCompositionIssueSeverity.error,
              message: 'Explicit mode requires one or more Skill ids.',
            ),
          );
        }
        break;
      case SkillCompositionMode.allEnabled:
        // This is an explicit user choice, not a lexical matching mode. Every
        // supplied enabled candidate becomes a root unless explicitly excluded.
        roots.addAll(byId.keys.where((id) => !excluded.contains(id)));
        if (roots.isEmpty) {
          issues.add(
            const SkillCompositionIssue(
              code: 'all_enabled_skills_empty',
              severity: SkillCompositionIssueSeverity.error,
              message: 'There are no enabled Skills available to include.',
            ),
          );
        }
        break;
      case SkillCompositionMode.assistantDefault:
        roots.addAll(defaults);
        if (roots.isEmpty) {
          issues.add(
            const SkillCompositionIssue(
              code: 'assistant_defaults_empty',
              severity: SkillCompositionIssueSeverity.error,
              message: 'No assistant-default Skills are configured or enabled.',
            ),
          );
        }
        break;
      case SkillCompositionMode.projectDefault:
        roots.addAll(projectDefaults);
        if (roots.isEmpty) {
          issues.add(
            const SkillCompositionIssue(
              code: 'project_defaults_empty',
              severity: SkillCompositionIssueSeverity.error,
              message: 'No Project Default Skills are configured for the active workspace.',
            ),
          );
        }
        break;
      case SkillCompositionMode.conversationOverride:
        roots.addAll(conversation);
        if (roots.isEmpty) {
          issues.add(
            const SkillCompositionIssue(
              code: 'conversation_override_empty',
              severity: SkillCompositionIssueSeverity.error,
              message: 'No Skill ids are selected for this conversation.',
            ),
          );
        }
        break;
    }

    if (mode == SkillCompositionMode.automatic && roots.isEmpty) {
      issues.add(
        const SkillCompositionIssue(
          code: 'no_relevant_skills',
          severity: SkillCompositionIssueSeverity.warning,
          message: 'No enabled Skill matched the task description. Continue without a Skill or ask the user to choose one explicitly.',
        ),
      );
    }

    for (final id in roots) {
      if (!byId.containsKey(id)) {
        issues.add(
          SkillCompositionIssue(
            code: 'skill_not_available',
            severity: SkillCompositionIssueSeverity.error,
            message: 'Skill "$id" is not enabled or is outside this assistant scope.',
            skillIds: [id],
          ),
        );
      }
      if (excluded.contains(id)) {
        issues.add(
          SkillCompositionIssue(
            code: 'selected_skill_excluded',
            severity: SkillCompositionIssueSeverity.error,
            message: 'Skill "$id" is both selected and excluded.',
            skillIds: [id],
          ),
        );
      }
    }

    final descriptors = <String, _Descriptor>{};
    final frontmatterErrors = <String, List<String>>{};
    for (final candidate in candidates) {
      final frontmatter = candidate.frontmatter;
      // SkillRecord.id is an internal unique key and may gain a numeric
      // suffix when two imported Skills share the same standard name.
      // Directory/name conformance is enforced at import time; rechecking it
      // against this internal id would reject otherwise valid duplicates.
      frontmatterErrors[candidate.id] = frontmatter.validate();
      descriptors[candidate.id] = _Descriptor.parse(
        candidate,
        frontmatter,
      );
    }

    final selected = <String>{};
    final automaticallyAdded = <String>{};
    final queue = <String>[...roots];
    while (queue.isNotEmpty) {
      final id = queue.removeLast();
      if (!selected.add(id)) continue;
      if (selected.length > maxSelectedSkills) {
        issues.add(
          const SkillCompositionIssue(
            code: 'selected_skill_limit',
            severity: SkillCompositionIssueSeverity.error,
            message: 'A composition may contain at most 64 Skills.',
          ),
        );
        break;
      }
      final descriptor = descriptors[id];
      if (descriptor == null) continue;
      for (final requiredId in descriptor.requires) {
        if (excluded.contains(requiredId)) {
          issues.add(
            SkillCompositionIssue(
              code: 'required_skill_excluded',
              severity: SkillCompositionIssueSeverity.error,
              message: 'Skill $id requires $requiredId, but it is excluded.',
              skillIds: [id, requiredId],
            ),
          );
          continue;
        }
        if (!descriptors.containsKey(requiredId)) {
          issues.add(
            SkillCompositionIssue(
              code: 'required_skill_missing',
              severity: SkillCompositionIssueSeverity.error,
              message: 'Skill $id requires unavailable Skill $requiredId.',
              skillIds: [id, requiredId],
            ),
          );
          continue;
        }
        if (!selected.contains(requiredId) && !roots.contains(requiredId)) {
          automaticallyAdded.add(requiredId);
          queue.add(requiredId);
        }
      }
    }

    selected.removeAll(excluded);
    final selectedDescriptors = <String, _Descriptor>{
      for (final id in selected)
        if (descriptors.containsKey(id)) id: descriptors[id]!,
    };
    for (final descriptor in selectedDescriptors.values) {
      final completeness = descriptor.candidate.completeness.trim().toLowerCase();
      if (completeness != 'complete') {
        final notes = descriptor.candidate.completenessNotes
            .map((note) => note.trim())
            .where((note) => note.isNotEmpty)
            .toList();
        if (completeness == 'unknown' || completeness.isEmpty) {
          issues.add(
            SkillCompositionIssue(
              code: 'skill_import_manifest_missing',
              severity: SkillCompositionIssueSeverity.error,
              message: 'Skill ${descriptor.id} has no verifiable import manifest. Re-import it before execution.${notes.isEmpty ? '' : ' ${notes.join(' ')}'}',
              skillIds: [descriptor.id],
            ),
          );
        } else {
          issues.add(
            SkillCompositionIssue(
              code: 'skill_import_incomplete',
              severity: SkillCompositionIssueSeverity.error,
              message: 'Skill ${descriptor.id} is not complete (import status: $completeness). Required companion files may be missing.${notes.isEmpty ? '' : ' ${notes.join(' ')}'}',
              skillIds: [descriptor.id],
            ),
          );
        }
      }
      final validation = frontmatterErrors[descriptor.id] ?? const <String>[];
      if (validation.isNotEmpty) {
        issues.add(
          SkillCompositionIssue(
            code: 'invalid_skill_frontmatter',
            severity: SkillCompositionIssueSeverity.error,
            message: 'Skill ${descriptor.id} has invalid SKILL.md metadata: ${validation.join('; ')}',
            skillIds: [descriptor.id],
          ),
        );
      }
      final compatibilityWarnings = descriptor.candidate.frontmatter
          .compatibilityWarnings(directoryName: descriptor.id);
      if (compatibilityWarnings.isNotEmpty) {
        issues.add(
          SkillCompositionIssue(
            code: 'unsupported_frontmatter_extensions',
            severity: SkillCompositionIssueSeverity.warning,
            message: 'Skill ${descriptor.id}: ${compatibilityWarnings.join(' ')}',
            skillIds: [descriptor.id],
          ),
        );
      }
      if (descriptor.invalidContracts.isNotEmpty) {
        issues.add(
          SkillCompositionIssue(
            code: 'invalid_kelivo_skill_contract',
            severity: SkillCompositionIssueSeverity.error,
            message: 'Skill ${descriptor.id} has invalid Kelivo contract metadata: ${descriptor.invalidContracts.join('; ')}.',
            skillIds: [descriptor.id],
          ),
        );
      }
      if (descriptor.frontmatterCompatibilityText) {
        issues.add(
          SkillCompositionIssue(
            code: 'compatibility_text_requires_review',
            severity: SkillCompositionIssueSeverity.warning,
            message: 'Skill ${descriptor.id} declares human-readable compatibility text; review it before execution.',
            skillIds: [descriptor.id],
          ),
        );
      }
      if (descriptor.candidate.instructionsTruncated) {
        issues.add(
          SkillCompositionIssue(
            code: 'skill_instructions_truncated',
            severity: SkillCompositionIssueSeverity.error,
            message: 'Skill ${descriptor.id} exceeds the instruction inspection limit; its instructions were not injected.',
            skillIds: [descriptor.id],
          ),
        );
      }
      if (descriptor.platforms.isNotEmpty &&
          !descriptor.platforms.contains(platform) &&
          !descriptor.platforms.contains('all')) {
        issues.add(
          SkillCompositionIssue(
            code: 'platform_incompatible',
            severity: SkillCompositionIssueSeverity.error,
            message: 'Skill ${descriptor.id} does not declare support for $platform.',
            skillIds: [descriptor.id],
          ),
        );
      }
      final expectedDigest = pinnedDigests[descriptor.id];
      if (expectedDigest != null && expectedDigest.isNotEmpty) {
        final normalizedExpected = _normalizeDigest(expectedDigest);
        final actualDigest = descriptor.candidate.digest;
        if (normalizedExpected == null) {
          issues.add(
            SkillCompositionIssue(
              code: 'pinned_digest_invalid',
              severity: SkillCompositionIssueSeverity.error,
              message: 'Pinned digest for ${descriptor.id} must be a SHA-256 value.',
              skillIds: [descriptor.id],
            ),
          );
        } else if (actualDigest == null || _normalizeDigest(actualDigest) == null) {
          issues.add(
            SkillCompositionIssue(
              code: 'pinned_digest_unavailable',
              severity: SkillCompositionIssueSeverity.error,
              message: 'Cannot verify pinned content digest for ${descriptor.id}.',
              skillIds: [descriptor.id],
            ),
          );
        } else if (_normalizeDigest(actualDigest) != normalizedExpected) {
          issues.add(
            SkillCompositionIssue(
              code: 'pinned_digest_mismatch',
              severity: SkillCompositionIssueSeverity.error,
              message: 'Skill ${descriptor.id} does not match its pinned digest.',
              skillIds: [descriptor.id],
            ),
          );
        }
      }
    }

    final edges = <SkillCompositionEdge>[];
    void addEdge(String from, String to, String reason, {String? artifact}) {
      if (from == to || !selected.contains(from) || !selected.contains(to)) {
        return;
      }
      if (edges.any((edge) => edge.from == from && edge.to == to &&
          edge.reason == reason && edge.artifact == artifact)) return;
      edges.add(
        SkillCompositionEdge(
          from: from,
          to: to,
          reason: reason,
          artifact: artifact,
        ),
      );
    }

    final artifactProducers = <String, List<String>>{};
    for (final descriptor in selectedDescriptors.values) {
      for (final output in descriptor.outputs) {
        artifactProducers.putIfAbsent(output, () => <String>[]).add(descriptor.id);
      }
    }
    for (final entry in artifactProducers.entries) {
      if (entry.value.length > 1) {
        issues.add(
          SkillCompositionIssue(
            code: 'duplicate_artifact_producer',
            severity: SkillCompositionIssueSeverity.error,
            message: 'Multiple Skills produce artifact "${entry.key}": ${entry.value.join(', ')}.',
            skillIds: entry.value,
          ),
        );
      }
    }

    for (final descriptor in selectedDescriptors.values) {
      for (final requiredId in descriptor.requires) {
        addEdge(requiredId, descriptor.id, 'requires');
      }
      for (final input in descriptor.inputs) {
        final producers = selectedDescriptors.values
            .where((other) => other.id != descriptor.id && other.outputs.contains(input))
            .map((other) => other.id)
            .toList()
          ..sort();
        if (producers.isEmpty) {
          issues.add(
            SkillCompositionIssue(
              code: 'external_artifact_input',
              severity: SkillCompositionIssueSeverity.info,
              message: 'Skill ${descriptor.id} expects artifact "$input" from outside this composition or an earlier task.',
              skillIds: [descriptor.id],
            ),
          );
        } else {
          for (final producer in producers) {
            addEdge(producer, descriptor.id, 'artifact', artifact: input);
          }
        }
      }
    }

    final ids = selected.toList()..sort();
    for (var i = 0; i < ids.length; i++) {
      final left = selectedDescriptors[ids[i]];
      if (left == null) continue;
      for (var j = i + 1; j < ids.length; j++) {
        final right = selectedDescriptors[ids[j]];
        if (right == null) continue;
        if (left.conflicts.contains(right.id) ||
            right.conflicts.contains(left.id)) {
          issues.add(
            SkillCompositionIssue(
              code: 'declared_skill_conflict',
              severity: SkillCompositionIssueSeverity.error,
              message: 'Skills ${left.id} and ${right.id} explicitly conflict.',
              skillIds: [left.id, right.id],
            ),
          );
        }
        final sharedWrites = <String>{};
        for (final leftPath in left.writes) {
          for (final rightPath in right.writes) {
            if (_writeTargetsOverlap(leftPath, rightPath)) {
              sharedWrites.add('$leftPath ↔ $rightPath');
            }
          }
        }
        if (sharedWrites.isNotEmpty) {
          issues.add(
            SkillCompositionIssue(
              code: 'shared_write_target',
              severity: SkillCompositionIssueSeverity.error,
              message: 'Skills ${left.id} and ${right.id} declare overlapping write targets: ${sharedWrites.join(', ')}.',
              skillIds: [left.id, right.id],
            ),
          );
        }
        final sharedTools = left.tools.toSet().intersection(right.tools.toSet());
        if (sharedTools.isNotEmpty) {
          issues.add(
            SkillCompositionIssue(
              code: 'tool_name_collision',
              severity: SkillCompositionIssueSeverity.error,
              message: 'Skills ${left.id} and ${right.id} declare colliding tool names: ${sharedTools.join(', ')}.',
              skillIds: [left.id, right.id],
            ),
          );
        }
        if (left.engine != null && right.engine != null &&
            left.engine != right.engine &&
            !_hasPath(edges, left.id, right.id) &&
            !_hasPath(edges, right.id, left.id)) {
          issues.add(
            SkillCompositionIssue(
              code: 'unordered_engine_conflict',
              severity: SkillCompositionIssueSeverity.warning,
              message: 'Skills ${left.id} and ${right.id} declare different engines without an ordering dependency; confirm that both engines are intended.',
              skillIds: [left.id, right.id],
            ),
          );
        }
      }
    }

    edges.sort((a, b) {
      final from = a.from.compareTo(b.from);
      if (from != 0) return from;
      return a.to.compareTo(b.to);
    });

    final stagesResult = _topologicalStages(
      selected.toList(),
      edges,
      allowParallel: allowParallel,
    );
    if (stagesResult.hasCycle) {
      issues.add(
        SkillCompositionIssue(
          code: 'dependency_cycle',
          severity: SkillCompositionIssueSeverity.error,
          message: 'The selected Skills contain a dependency cycle: ${stagesResult.cycleIds.join(' → ')}.',
          skillIds: stagesResult.cycleIds,
        ),
      );
    }

    final requestedPermissions = selectedDescriptors.values
        .expand((descriptor) => descriptor.permissions)
        .toSet()
        .toList()
      ..sort();
    if (requestedPermissions.isNotEmpty) {
      issues.add(
        SkillCompositionIssue(
          code: 'permissions_require_review',
          severity: SkillCompositionIssueSeverity.warning,
          message: 'Selected Skills request permissions: ${requestedPermissions.join(', ')}. No permission is granted by this plan.',
          skillIds: selected.toList()..sort(),
        ),
      );
    }

    final inputs = <String, List<String>>{
      for (final descriptor in selectedDescriptors.values)
        descriptor.id: descriptor.inputs,
    };
    final outputs = <String, List<String>>{
      for (final descriptor in selectedDescriptors.values)
        descriptor.id: descriptor.outputs,
    };

    final selectedCandidates = [
      for (final id in selected)
        if (byId.containsKey(id)) byId[id]!,
    ];
    final instructionTokens = selectedCandidates.fold<int>(
      0,
      (sum, candidate) => sum + _estimateTokens(candidate.markdown),
    );
    final budgetValid = contextBudgetTokens >= 500 &&
        contextBudgetTokens <= maxContextBudgetTokens;
    if (budgetValid && instructionTokens > contextBudgetTokens) {
      issues.add(
        SkillCompositionIssue(
          code: 'context_budget_exceeded',
          severity: SkillCompositionIssueSeverity.error,
          message: 'Selected Skill instructions need approximately $instructionTokens tokens, above the $contextBudgetTokens token budget. Increase the budget or reduce the selection; instructions were not injected.',
          skillIds: selected.toList()..sort(),
        ),
      );
    }

    final instructionMap = <String, String>{};
    final blocked = issues.any(
      (issue) => issue.severity == SkillCompositionIssueSeverity.error,
    );
    if (!blocked && selected.isNotEmpty) {
      for (final candidate in selectedCandidates) {
        instructionMap[candidate.id] = candidate.markdown;
      }
    }

    final selectionReasons = <String, String>{};
    for (final id in selected) {
      if (automaticallyAdded.contains(id) && !roots.contains(id)) {
        final parents = selectedDescriptors.values
            .where((descriptor) => descriptor.requires.contains(id))
            .map((descriptor) => descriptor.id)
            .toList()
          ..sort();
        selectionReasons[id] = 'Required by ${parents.join(', ')}.';
      } else {
        selectionReasons[id] = switch (mode) {
          SkillCompositionMode.automatic =>
            'Automatically matched the task against the Skill name, description, and tags (score ${scores[id] ?? 0}).',
          SkillCompositionMode.explicit => 'Explicitly requested.',
          SkillCompositionMode.allEnabled =>
            'Included because the user explicitly requested all enabled Skills.',
          SkillCompositionMode.assistantDefault => 'Included in the assistant configured defaults.',
          SkillCompositionMode.projectDefault => 'Included in the active workspace Project Defaults.',
          SkillCompositionMode.conversationOverride => 'Selected for this conversation.',
        };
      }
    }

    return SkillCompositionPlan(
      mode: mode,
      task: normalizedTask,
      selectedIds: selected.toList()..sort(),
      automaticallyAddedIds: automaticallyAdded.toList()..sort(),
      scores: {
        for (final id in selected)
          if (scores.containsKey(id)) id: scores[id]!,
      },
      selectionReasons: selectionReasons,
      edges: edges,
      stages: stagesResult.stages,
      inputs: inputs,
      outputs: outputs,
      issues: issues,
      contextBudgetTokens: contextBudgetTokens,
      instructionTokens: instructionTokens,
      instructions: instructionMap,
      pinnedDigests: {
        for (final id in selected)
          if (pinnedDigests.containsKey(id)) id: pinnedDigests[id]!,
      },
      requestedPermissions: requestedPermissions,
    );
  }

  static double _score(String task, SkillCompositionCandidate candidate) {
    final queryTokens = _tokens(task).where((token) => !_stopWords.contains(token)).toSet();
    if (queryTokens.isEmpty) return 0;
    final descriptor = candidate.frontmatter;
    final nameTokens = _tokens('${candidate.skill.name} ${candidate.id}');
    final descriptionTokens = _tokens('${candidate.skill.description} ${descriptor.description}');
    final tags = _csv(descriptor.metadata['kelivo.tags']).expand(_tokens).toSet();
    var points = 0.0;
    var matched = 0;
    for (final token in queryTokens) {
      var weight = 0.0;
      if (nameTokens.contains(token)) weight = 3.0;
      if (tags.contains(token) && weight < 2.0) weight = 2.0;
      if (descriptionTokens.contains(token) && weight < 1.0) weight = 1.0;
      if (weight > 0) {
        matched++;
        points += weight;
      }
    }
    if (matched == 0) return 0;
    final coverage = matched / queryTokens.length;
    return double.parse((points * (0.5 + coverage)).toStringAsFixed(3));
  }

  static Set<String> _tokens(String value) => RegExp(
    r'[\p{L}\p{N}]{2,}',
    unicode: true,
  ).allMatches(value.toLowerCase()).map((match) => match.group(0)!).toSet();

  static List<String> _csv(String? value) {
    if (value == null || value.trim().isEmpty) return const <String>[];
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  // This intentionally conservative heuristic avoids systematically
  // undercounting Arabic and other non-Latin instructions. Actual model
  // tokenization remains provider-specific.
  static int _estimateTokens(String markdown) =>
      (markdown.runes.length / 2).ceil();

  static bool _writeTargetsOverlap(String left, String right) {
    final a = left.replaceAll('\\', '/').replaceAll(RegExp(r'/+'), '/');
    final b = right.replaceAll('\\', '/').replaceAll(RegExp(r'/+'), '/');
    return a == b || a.startsWith('$b/') || b.startsWith('$a/');
  }

  static String? _normalizeDigest(String value) {
    final normalized = value.trim().toLowerCase().replaceFirst(RegExp(r'^sha256:'), '');
    return RegExp(r'^[0-9a-f]{64}$').hasMatch(normalized)
        ? normalized
        : null;
  }

  static bool _hasPath(
    List<SkillCompositionEdge> edges,
    String from,
    String to,
  ) {
    final visited = <String>{};
    final queue = <String>[from];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      if (!visited.add(current)) continue;
      if (current == to) return true;
      for (final edge in edges.where((edge) => edge.from == current)) {
        queue.add(edge.to);
      }
    }
    return false;
  }

  static _StagesResult _topologicalStages(
    List<String> ids,
    List<SkillCompositionEdge> edges, {
    required bool allowParallel,
  }) {
    final remaining = ids.toSet();
    final completed = <String>{};
    final stages = <List<String>>[];
    while (remaining.isNotEmpty) {
      final ready = remaining.where((id) {
        return edges
            .where((edge) => edge.to == id)
            .every((edge) => completed.contains(edge.from));
      }).toList()..sort();
      if (ready.isEmpty) {
        return _StagesResult(
          stages: stages,
          hasCycle: true,
          cycleIds: remaining.toList()..sort(),
        );
      }
      final batch = allowParallel ? ready : [ready.first];
      stages.add(batch);
      completed.addAll(batch);
      remaining.removeAll(batch);
    }
    return _StagesResult(
      stages: stages,
      hasCycle: false,
      cycleIds: const <String>[],
    );
  }
}

class _Descriptor {
  const _Descriptor({
    required this.candidate,
    required this.requires,
    required this.conflicts,
    required this.inputs,
    required this.outputs,
    required this.writes,
    required this.tools,
    required this.platforms,
    required this.engine,
    required this.invalidContracts,
    required this.permissions,
    required this.frontmatterCompatibilityText,
  });

  final SkillCompositionCandidate candidate;
  final List<String> requires;
  final List<String> conflicts;
  final List<String> inputs;
  final List<String> outputs;
  final List<String> writes;
  final List<String> tools;
  final List<String> platforms;
  final String? engine;
  final List<String> invalidContracts;
  final List<String> permissions;
  final bool frontmatterCompatibilityText;

  String get id => candidate.id;

  static _Descriptor parse(
    SkillCompositionCandidate candidate,
    SkillFrontmatter frontmatter,
  ) {
    final metadata = frontmatter.metadata;
    List<String> values(String key) => SkillCompositionPlanner._csv(metadata[key]);
    String? token(String key) {
      final value = metadata[key]?.trim();
      return value == null || value.isEmpty ? null : value.toLowerCase();
    }

    final requires = values('kelivo.requires');
    final conflicts = values('kelivo.conflicts');
    final inputs = values('kelivo.inputs');
    final outputs = values('kelivo.outputs');
    final writes = values('kelivo.writes');
    final tools = values('kelivo.tools');
    final permissions = values('kelivo.permissions');
    final platforms = values('kelivo.platforms').map((value) => value.toLowerCase()).toList();
    final engine = token('kelivo.engine');
    final invalid = <String>[];
    final idPattern = RegExp(r'^[a-z0-9][a-z0-9._-]{0,127}$');
    for (final id in [...requires, ...conflicts]) {
      if (!idPattern.hasMatch(id)) invalid.add('invalid Skill reference "$id"');
    }
    if (requires.contains(candidate.id)) {
      invalid.add('a Skill cannot require itself');
    }
    if (conflicts.contains(candidate.id)) {
      invalid.add('a Skill cannot conflict with itself');
    }
    final artifactPattern = RegExp(r'^[a-z0-9][a-z0-9._-]{0,127}$');
    for (final artifact in [...inputs, ...outputs]) {
      if (!artifactPattern.hasMatch(artifact)) {
        invalid.add('invalid artifact id "$artifact"');
      }
    }
    for (final path in writes) {
      final segments = path.replaceAll('\\', '/').split('/');
      if (path.startsWith('/') ||
          path.contains('\\') ||
          segments.any((segment) => segment.isEmpty || segment == '.' || segment == '..') ||
          path.contains(':')) {
        invalid.add('unsafe write target "$path"');
      }
    }
    for (final tool in tools) {
      if (!RegExp(r'^[a-z][a-z0-9_.-]{0,127}$').hasMatch(tool)) {
        invalid.add('invalid tool name "$tool"');
      }
    }
    for (final permission in permissions) {
      if (!RegExp(r'^[a-z][a-z0-9_.-]{0,127}$').hasMatch(permission)) {
        invalid.add('invalid permission "$permission"');
      }
    }
    const supportedPlatforms = {'android', 'ios', 'linux', 'macos', 'windows', 'web', 'all'};
    for (final value in platforms) {
      if (!supportedPlatforms.contains(value)) invalid.add('unknown platform "$value"');
    }
    if (engine != null &&
        !RegExp(r'^[a-z0-9][a-z0-9._-]{0,127}$').hasMatch(engine)) {
      invalid.add('invalid engine id "$engine"');
    }
    return _Descriptor(
      candidate: candidate,
      requires: requires,
      conflicts: conflicts,
      inputs: inputs,
      outputs: outputs,
      writes: writes,
      tools: tools,
      platforms: platforms,
      engine: engine,
      invalidContracts: invalid,
      permissions: permissions,
      frontmatterCompatibilityText: frontmatter.compatibility?.isNotEmpty == true,
    );
  }
}

class _StagesResult {
  const _StagesResult({
    required this.stages,
    required this.hasCycle,
    required this.cycleIds,
  });

  final List<List<String>> stages;
  final bool hasCycle;
  final List<String> cycleIds;
}
