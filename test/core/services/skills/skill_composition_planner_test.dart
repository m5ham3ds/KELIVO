import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/skill_record.dart';
import 'package:Kelivo/core/services/skills/skill.dart';
import 'package:Kelivo/core/services/skills/skill_composition_planner.dart';

SkillCompositionCandidate _candidate({
  required String id,
  required String description,
  String metadata = '',
  String body = 'Follow this Skill instruction.',
  String? digest,
}) {
  final now = DateTime.utc(2026, 1, 1);
  final skill = Skill(
    record: SkillRecord(
      id: id,
      source: SkillSource.file,
      installedAt: now,
      updatedAt: now,
    ),
    name: id,
    description: description,
    dir: '/skills/$id',
    skillMdPath: '/skills/$id/SKILL.md',
  );
  final md = '''
---
name: $id
description: $description
metadata:
${metadata.isEmpty ? '  kelivo.group: test' : metadata}
---
$body
''';
  return SkillCompositionCandidate(skill: skill, markdown: md, digest: digest);
}

void main() {
  group('SkillCompositionPlanner', () {
    test('auto selection ranks relevant descriptions and respects exclusions', () {
      final story = _candidate(
        id: 'story-planner',
        description: 'Write story scripts and narrative outlines.',
      );
      final audio = _candidate(
        id: 'audio-mixer',
        description: 'Mix voice recordings and music tracks.',
      );
      final unrelated = _candidate(
        id: 'spreadsheet-helper',
        description: 'Format spreadsheets and financial tables.',
      );

      final plan = SkillCompositionPlanner.plan(
        task: 'Write a story script and narrative outline',
        candidates: [story, audio, unrelated],
        mode: SkillCompositionMode.automatic,
        excludedSkillIds: ['audio-mixer'],
      );

      expect(plan.selectedIds, ['story-planner']);
      expect(plan.scores['story-planner'], greaterThan(0));
      expect(plan.selectedIds, isNot(contains('audio-mixer')));
      expect(plan.status, 'ready');
      expect(plan.instructions.keys, ['story-planner']);
      expect(plan.selectionReasons['story-planner'], contains('Automatically matched'));

    });

    test('explicit selection recursively adds requirements and orders the DAG', () {
      final storyboard = _candidate(
        id: 'storyboard',
        description: 'Create a storyboard.',
        metadata: '  kelivo.outputs: storyboard.json',
      );
      final renderer = _candidate(
        id: 'renderer',
        description: 'Render scenes from a storyboard.',
        metadata: '  kelivo.requires: storyboard\n  kelivo.inputs: storyboard.json\n  kelivo.outputs: render.mp4',
      );

      final plan = SkillCompositionPlanner.plan(
        task: 'Render the video',
        candidates: [renderer, storyboard],
        mode: SkillCompositionMode.explicit,
        requestedSkillIds: ['renderer'],
      );

      expect(plan.status, 'ready');
      expect(plan.selectedIds, ['renderer', 'storyboard']);
      expect(plan.automaticallyAddedIds, ['storyboard']);
      expect(plan.selectionReasons['renderer'], 'Explicitly requested.');
      expect(plan.selectionReasons['storyboard'], 'Required by renderer.');
      expect(plan.stages, [
        ['storyboard'],
        ['renderer'],
      ]);
      expect(plan.edges, hasLength(2));
      expect(plan.edges.map((edge) => edge.reason), contains('requires'));
      expect(plan.edges.map((edge) => edge.reason), contains('artifact'));
      expect(plan.outputs['storyboard'], ['storyboard.json']);
      expect(plan.inputs['renderer'], ['storyboard.json']);
    });

    test('independent Skills can share a parallel stage', () {
      final voice = _candidate(
        id: 'voice-design',
        description: 'Create voice design.',
        metadata: '  kelivo.outputs: voice.wav',
      );
      final captions = _candidate(
        id: 'caption-design',
        description: 'Create subtitle captions.',
        metadata: '  kelivo.outputs: captions.srt',
      );

      final parallel = SkillCompositionPlanner.plan(
        task: 'Create voice and captions',
        candidates: [voice, captions],
        mode: SkillCompositionMode.explicit,
        requestedSkillIds: ['voice-design', 'caption-design'],
      );
      final sequential = SkillCompositionPlanner.plan(
        task: 'Create voice and captions',
        candidates: [voice, captions],
        mode: SkillCompositionMode.explicit,
        requestedSkillIds: ['voice-design', 'caption-design'],
        allowParallel: false,
      );

      expect(parallel.stages, [ ['caption-design', 'voice-design'] ]);
      expect(sequential.stages, [ ['caption-design'], ['voice-design'] ]);
    });

    test('declared conflicts and shared write targets block instruction loading', () {
      final first = _candidate(
        id: 'engine-a',
        description: 'Render with engine A.',
        metadata: '  kelivo.conflicts: engine-b\n  kelivo.writes: output/final.mp4',
      );
      final second = _candidate(
        id: 'engine-b',
        description: 'Render with engine B.',
        metadata: '  kelivo.writes: output/final.mp4',
      );

      final plan = SkillCompositionPlanner.plan(
        task: 'Render a video',
        candidates: [first, second],
        mode: SkillCompositionMode.explicit,
        requestedSkillIds: ['engine-a', 'engine-b'],
      );

      expect(plan.status, 'blocked');
      expect(plan.issues.map((issue) => issue.code), contains('declared_skill_conflict'));
      expect(plan.issues.map((issue) => issue.code), contains('shared_write_target'));
      expect(plan.instructions, isEmpty);
    });

    test('overlapping parent and child write paths block unsafe composition', () {
      final directoryWriter = _candidate(
        id: 'directory-writer',
        description: 'Writes into the output directory.',
        metadata: '  kelivo.writes: output',
      );
      final fileWriter = _candidate(
        id: 'file-writer',
        description: 'Writes a final output file.',
        metadata: '  kelivo.writes: output/final.mp4',
      );
      final plan = SkillCompositionPlanner.plan(
        task: 'Create the output',
        candidates: [directoryWriter, fileWriter],
        mode: SkillCompositionMode.explicit,
        requestedSkillIds: ['directory-writer', 'file-writer'],
      );

      expect(plan.status, 'blocked');
      expect(plan.issues.map((issue) => issue.code), contains('shared_write_target'));
    });

    test('missing and excluded requirements are reported as blockers', () {
      final dependent = _candidate(
        id: 'dependent',
        description: 'Uses a required helper.',
        metadata: '  kelivo.requires: helper-skill',
      );
      final missing = SkillCompositionPlanner.plan(
        task: 'Use dependent skill',
        candidates: [dependent],
        mode: SkillCompositionMode.explicit,
        requestedSkillIds: ['dependent'],
      );
      final excluded = SkillCompositionPlanner.plan(
        task: 'Use dependent skill',
        candidates: [dependent, _candidate(id: 'helper-skill', description: 'Helper.')],
        mode: SkillCompositionMode.explicit,
        requestedSkillIds: ['dependent'],
        excludedSkillIds: ['helper-skill'],
      );

      expect(missing.issues.map((issue) => issue.code), contains('required_skill_missing'));
      expect(excluded.issues.map((issue) => issue.code), contains('required_skill_excluded'));
      expect(missing.instructions, isEmpty);
      expect(excluded.instructions, isEmpty);
    });

    test('explicit roots are not mislabeled as automatically added dependencies', () {
      final first = _candidate(
        id: 'first',
        description: 'First stage.',
        metadata: '  kelivo.requires: second',
      );
      final second = _candidate(id: 'second', description: 'Second stage.');
      final plan = SkillCompositionPlanner.plan(
        task: 'Run both stages',
        candidates: [first, second],
        mode: SkillCompositionMode.explicit,
        requestedSkillIds: ['first', 'second'],
      );

      expect(plan.automaticallyAddedIds, isEmpty);
      expect(plan.selectionReasons['second'], 'Explicitly requested.');
    });

    test('standard compatibility extensions are preserved as warnings', () {
      final skill = SkillCompositionCandidate(
        skill: _candidate(id: 'extended', description: 'Extended Skill.').skill,
        markdown: '''
---
name: extended
description: Extended Skill.
allowed-tools: read_file
metadata:
  kelivo.tags: documents
custom-field: preserved
---
Follow this Skill instruction.
''',
      );
      final plan = SkillCompositionPlanner.plan(
        task: 'Use extended Skill',
        candidates: [skill],
        mode: SkillCompositionMode.explicit,
        requestedSkillIds: ['extended'],
      );

      expect(plan.status, 'ready_with_warnings');
      expect(plan.issues.map((issue) => issue.code), contains('unsupported_frontmatter_extensions'));
      expect(plan.instructions, contains('extended'));
    });

    test('internal duplicate id suffix does not invalidate imported Skill name', () {
      final duplicate = SkillCompositionCandidate(
        skill: _candidate(id: 'story-planner-2', description: 'Duplicate name.').skill,
        markdown: '''
---
name: story-planner
description: Duplicate name.
metadata:
  kelivo.group: test
---
Instructions.
''',
      );
      final plan = SkillCompositionPlanner.plan(
        task: 'Use duplicate skill',
        candidates: [duplicate],
        mode: SkillCompositionMode.explicit,
        requestedSkillIds: ['story-planner-2'],
      );

      expect(plan.issues.map((issue) => issue.code), isNot(contains('invalid_skill_frontmatter')));
      expect(plan.instructions, contains('story-planner-2'));
    });

    test('dependency cycles are detected', () {
      final alpha = _candidate(
        id: 'alpha',
        description: 'Alpha stage.',
        metadata: '  kelivo.requires: beta',
      );
      final beta = _candidate(
        id: 'beta',
        description: 'Beta stage.',
        metadata: '  kelivo.requires: alpha',
      );

      final plan = SkillCompositionPlanner.plan(
        task: 'Run alpha and beta',
        candidates: [alpha, beta],
        mode: SkillCompositionMode.explicit,
        requestedSkillIds: ['alpha'],
      );

      expect(plan.issues.map((issue) => issue.code), contains('dependency_cycle'));
      expect(plan.status, 'blocked');
    });

    test('platform constraints and pinned digests are enforced', () {
      final skill = _candidate(
        id: 'linux-only',
        description: 'A Linux-only Skill.',
        metadata: '  kelivo.platforms: linux',
        digest: 'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      );
      final plan = SkillCompositionPlanner.plan(
        task: 'Use this Skill',
        candidates: [skill],
        mode: SkillCompositionMode.explicit,
        requestedSkillIds: ['linux-only'],
        pinnedDigests: {
          'linux-only': 'sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        },
      );

      expect(plan.issues.map((issue) => issue.code), contains('platform_incompatible'));
      expect(plan.issues.map((issue) => issue.code), contains('pinned_digest_mismatch'));
      expect(plan.instructions, isEmpty);
    });

    test('context budget is checked before any SKILL.md is injected', () {
      final large = _candidate(
        id: 'large-skill',
        description: 'A large instruction set.',
        body: List<String>.filled(5000, 'instruction').join(' '),
      );
      final plan = SkillCompositionPlanner.plan(
        task: 'Use the large skill',
        candidates: [large],
        mode: SkillCompositionMode.explicit,
        requestedSkillIds: ['large-skill'],
        contextBudgetTokens: 500,
      );

      expect(plan.issues.map((issue) => issue.code), contains('context_budget_exceeded'));
      expect(plan.instructions, isEmpty);
    });

    test('assistant defaults and conversation overrides select only their scope', () {
      final a = _candidate(id: 'alpha', description: 'Alpha helper.');
      final b = _candidate(id: 'beta', description: 'Beta helper.');
      final candidates = [a, b];

      final defaults = SkillCompositionPlanner.plan(
        task: 'Use configured defaults',
        candidates: candidates,
        mode: SkillCompositionMode.assistantDefault,
        assistantDefaultSkillIds: ['beta'],
      );
      final project = SkillCompositionPlanner.plan(
        task: 'Use workspace Project Defaults',
        candidates: candidates,
        mode: SkillCompositionMode.projectDefault,
        projectDefaultSkillIds: ['alpha'],
      );
      final conversation = SkillCompositionPlanner.plan(
        task: 'Use conversation choices',
        candidates: candidates,
        mode: SkillCompositionMode.conversationOverride,
        conversationSkillIds: ['alpha'],
      );

      expect(defaults.selectedIds, ['beta']);
      expect(project.selectedIds, ['alpha']);
      expect(project.selectionReasons['alpha'], contains('Project Defaults'));
      expect(conversation.selectedIds, ['alpha']);
    });

    test('unsafe contracts and requested permissions are surfaced', () {
      final skill = _candidate(
        id: 'unsafe-contract',
        description: 'A Skill with declared workspace capabilities.',
        metadata: '  kelivo.writes: ../outside.txt\n  kelivo.permissions: workspace.write',
      );
      final plan = SkillCompositionPlanner.plan(
        task: 'Use the Skill',
        candidates: [skill],
        mode: SkillCompositionMode.explicit,
        requestedSkillIds: ['unsafe-contract'],
      );

      expect(plan.status, 'blocked');
      expect(
        plan.issues.map((issue) => issue.code),
        contains('invalid_kelivo_skill_contract'),
      );
      expect(plan.issues.map((issue) => issue.code), contains('permissions_require_review'));
      expect(plan.requestedPermissions, ['workspace.write']);
      expect(plan.instructions, isEmpty);
    });

    test('plan explicitly states that scripts and dependency installs are not run', () {
      final skill = _candidate(id: 'safe-skill', description: 'Safe test Skill.');
      final json = SkillCompositionPlanner.plan(
        task: 'Use safe skill',
        candidates: [skill],
        mode: SkillCompositionMode.explicit,
        requestedSkillIds: ['safe-skill'],
      ).toJson();

      final safety = json['executionSafety'] as Map<String, Object?>;
      expect(safety['scriptsExecuted'], isFalse);
      expect(safety['dependenciesInstalled'], isFalse);
      expect(json['selectedSkillInstructions'], isA<Map<String, String>>());
    });
  });
}
