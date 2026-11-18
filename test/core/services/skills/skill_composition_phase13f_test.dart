import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/skill_record.dart';
import 'package:Kelivo/core/services/skills/skill.dart';
import 'package:Kelivo/core/services/skills/skill_composition_planner.dart';

SkillCompositionCandidate candidate({
  required String id,
  String description = 'Unrelated helper operation.',
  String metadata = '',
  String completeness = 'complete',
  List<String> completenessNotes = const <String>[],
}) {
  final skill = Skill(
    record: SkillRecord(
      id: id,
      source: SkillSource.file,
      installedAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    ),
    name: id,
    description: description,
    dir: '/skills/$id',
    skillMdPath: '/skills/$id/SKILL.md',
  );
  final markdown = '''
---
name: $id
description: $description
metadata:
${metadata.isEmpty ? '  kelivo.group: phase13f' : metadata}
---
Instructions for $id.
''';
  return SkillCompositionCandidate(
    skill: skill,
    markdown: markdown,
    completeness: completeness,
    completenessNotes: completenessNotes,
  );
}

void main() {
  group('Phase 13F Skill composition', () {
    test('explicitly selecting one Skill does not add unrelated Skills', () {
      final one = candidate(id: 'one', description: 'Write a script.');
      final two = candidate(id: 'two');
      final three = candidate(id: 'three');
      final before = [one, two, three].map((item) => item.skill.record.enabled).toList();

      final plan = SkillCompositionPlanner.plan(
        task: 'Write a script',
        candidates: [one, two, three],
        mode: SkillCompositionMode.explicit,
        requestedSkillIds: const ['one'],
      );

      expect(plan.status, 'ready');
      expect(plan.selectedIds, ['one']);
      expect(plan.selectionReasons['one'], 'Explicitly requested.');
      expect(
        [one, two, three].map((item) => item.skill.record.enabled).toList(),
        before,
        reason: 'Planning must not modify installed Skill or asset state.',
      );
    });

    test('three explicit Skills are selected exactly without auto-matching replacements', () {
      final skills = [
        candidate(id: 'a'),
        candidate(id: 'b'),
        candidate(id: 'c'),
        candidate(id: 'unrelated'),
      ];
      final plan = SkillCompositionPlanner.plan(
        task: 'Task unrelated to any Skill descriptions.',
        candidates: skills,
        mode: SkillCompositionMode.explicit,
        requestedSkillIds: const ['a', 'b', 'c'],
      );
      expect(plan.status, 'ready');
      expect(plan.selectedIds, ['a', 'b', 'c']);
      expect(plan.automaticallyAddedIds, isEmpty);
    });

    test('all_enabled bypasses lexical matching and includes every candidate', () {
      final skills = [
        candidate(id: 'animation-director'),
        candidate(id: 'arabian-motion-video-director'),
        candidate(id: 'character-visual-director'),
        candidate(id: 'ig-profile'),
        candidate(id: 'ig-reel'),
        candidate(id: 'ig-viral'),
      ];
      final plan = SkillCompositionPlanner.plan(
        task: 'An entirely unrelated spreadsheet task.',
        candidates: skills,
        mode: SkillCompositionMode.allEnabled,
      );
      expect(plan.status, 'ready');
      expect(plan.selectedIds, skills.map((item) => item.id).toList()..sort());
      expect(
        plan.selectionReasons.values,
        everyElement(contains('all enabled Skills')),
      );
    });

    test('oversized Unicode task brief is compacted to 8000 characters', () {
      const opening = 'Create a 10-second Arabic animated video. ';
      const ending = ' Keep Arabic narration, 9:16 framing, and export MP4.';
      final source = '$opening${'قصة ومشهد متحرك. ' * 900}$ending';
      final brief = SkillCompositionPlanner.compactTaskBrief(source);
      expect(source.runes.length, greaterThan(8000));
      expect(brief.runes.length, lessThanOrEqualTo(8000));
      expect(brief, startsWith(opening));
      expect(brief, endsWith(ending));
      expect(brief, contains('omitted to meet the 8000-character limit'));
      final plan = SkillCompositionPlanner.plan(
        task: source,
        candidates: [candidate(id: 'video')],
        mode: SkillCompositionMode.explicit,
        requestedSkillIds: const ['video'],
      );
      expect(plan.status, 'ready');
      expect(plan.task.runes.length, lessThanOrEqualTo(8000));
    });

    test('partial or unverifiable Skill imports are blocked, not marked ready', () {
      final partial = candidate(
        id: 'ig-viral',
        completeness: 'partial',
        completenessNotes: const ['Missing required companion file: hooks.json'],
      );
      final plan = SkillCompositionPlanner.plan(
        task: 'Analyze viral content.',
        candidates: [partial],
        mode: SkillCompositionMode.explicit,
        requestedSkillIds: const ['ig-viral'],
      );
      expect(plan.status, 'blocked');
      expect(plan.issues.map((issue) => issue.code), contains('skill_import_incomplete'));
      expect(plan.issues.single.message, contains('hooks.json'));
      expect(plan.instructions, isEmpty);

      final unknown = SkillCompositionPlanner.plan(
        task: 'Use legacy skill.',
        candidates: [candidate(id: 'legacy', completeness: 'unknown')],
        mode: SkillCompositionMode.explicit,
        requestedSkillIds: const ['legacy'],
      );
      expect(unknown.status, 'blocked');
      expect(unknown.issues.map((issue) => issue.code), contains('skill_import_manifest_missing'));
    });

    test('dependency ordering and artifact handoff are preserved across stages', () {
      final director = candidate(
        id: 'director',
        description: 'Prepare a storyboard for video production.',
        metadata: '  kelivo.outputs: storyboard.json',
      );
      final renderer = candidate(
        id: 'renderer',
        description: 'Render a video from a storyboard.',
        metadata: '  kelivo.requires: director\n  kelivo.inputs: storyboard.json\n  kelivo.outputs: final.mp4',
      );
      final plan = SkillCompositionPlanner.plan(
        task: 'Produce the final video.',
        candidates: [renderer, director],
        mode: SkillCompositionMode.explicit,
        requestedSkillIds: const ['renderer'],
        allowParallel: false,
      );
      expect(plan.status, 'ready');
      expect(plan.stages, [ ['director'], ['renderer'] ]);
      expect(plan.outputs['director'], ['storyboard.json']);
      expect(plan.inputs['renderer'], ['storyboard.json']);
      expect(
        plan.edges.any((edge) => edge.from == 'director' && edge.to == 'renderer'),
        isTrue,
      );
    });
  });
}
