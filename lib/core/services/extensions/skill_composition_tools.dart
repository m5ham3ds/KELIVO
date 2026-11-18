/// Conversation tool used to preview and resolve a multi-Skill execution plan.
abstract final class SkillCompositionToolNames {
  static const String compose = 'skill_compose';
}

abstract final class SkillCompositionToolCatalog {
  static List<Map<String, dynamic>> definitions() => [
    {
      'type': 'function',
      'function': {
        'name': SkillCompositionToolNames.compose,
        'description':
            'Plan a task using multiple enabled Agent Skills. Select Skills automatically, explicitly, as all enabled Skills, from assistant defaults, workspace Project Defaults, or this conversation override. The planner checks requirements, conflicts, platform compatibility, artifact inputs/outputs, dependency order, parallel stages and context budget. It only returns a plan and selected SKILL.md instructions; it never executes scripts or installs dependencies.',
        'parameters': {
          'type': 'object',
          'properties': {
            'task': {
              'type': 'string',
              'description': 'The latest user goal and key constraints as a concise task brief. Do not paste the full conversation transcript. This field may be empty when unavailable; Kelivo then recovers the latest user message. Oversized input is compacted to 8000 Unicode characters before planning.',
            },
            'mode': {
              'type': 'string',
              'enum': [
                'auto',
                'explicit',
                'all_enabled',
                'assistant_default',
                'project_default',
                'conversation_override',
              ],
              'description': 'How to select initial Skills. auto uses relevance matching; explicit uses skill_ids exactly; all_enabled bypasses matching and includes every enabled Skill candidate; other modes use their configured bindings.',
              'default': 'auto',
            },
            'skill_ids': {
              'type': 'array',
              'description': 'Required in explicit mode. Skill IDs explicitly selected by the user; these are never replaced by automatic matching.',
              'items': {'type': 'string'},
              'uniqueItems': true,
              'maxItems': 64,
            },
            'exclude_skill_ids': {
              'type': 'array',
              'description': 'Skills that must not be selected, including as dependencies.',
              'items': {'type': 'string'},
              'uniqueItems': true,
              'maxItems': 64,
            },
            'context_budget_tokens': {
              'type': 'integer',
              'minimum': 500,
              'maximum': 32000,
              'description': 'Approximate budget for selected SKILL.md instructions. Defaults to 6000.',
            },
            'allow_parallel': {
              'type': 'boolean',
              'description': 'Allow independent DAG stages to run in parallel. Defaults to true.',
            },
            'pinned_digests': {
              'type': 'object',
              'description': 'Optional expected SHA-256 digests keyed by Skill id; mismatches block the plan.',
              'additionalProperties': {'type': 'string'},
              'maxProperties': 64,
            },
          },
          'required': [],
          'additionalProperties': false,
        },
      },
    },
  ];
}
