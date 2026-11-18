/// Conversation-first planner and runner for hybrid code/provider video scenes.
abstract final class VideoHybridWorkflowToolNames {
  static const String manage = 'video_hybrid_workflow';
  static const Set<String> all = {manage};
}

abstract final class VideoHybridWorkflowToolCatalog {
  static List<Map<String, dynamic>> definitions() => [
    {
      'type': 'function',
      'function': {
        'name': VideoHybridWorkflowToolNames.manage,
        'description': [
          'Compose and run a hybrid video workflow for an existing video_production project. ',
          'Assign exactly one code engine or AI provider to each scene, then use a separate assembly engine to combine the scene MP4 assets. ',
          'Use plan to validate routes without writing files; configure saves the reproducible route and target profile. ',
          'run_scene renders one code scene with its selected engine, or submits an asynchronous provider job; provider submission may incur charges. ',
          'poll_scene checks a provider job, download_scene imports its MP4 into the scene, assemble renders the complete hybrid project, and export delivers MP4 plus source ZIP. ',
          'The selected assembly engine is responsible for normalizing dimensions, frame rate, timing and audio according to the saved target profile. ',
          'Skill IDs may be recorded as intended collaborators, but Skill execution and artifact handoff remain unavailable until the Phase 4 executor is implemented. ',
          'Provider image URLs are transient inputs and are never saved in workflow metadata. API keys remain in secure Workspace settings. ',
          'No video engine, provider, Skill or package is bundled by this tool.',
        ].join(),
        'parameters': {
          'type': 'object',
          'additionalProperties': false,
          'properties': {
            'action': {
              'type': 'string',
              'enum': [
                'plan', 'configure', 'status', 'run_scene', 'poll_scene',
                'download_scene', 'assemble', 'export',
              ],
              'default': 'plan',
            },
            'project_dir': {
              'type': 'string',
              'maxLength': 1024,
              'description': 'Workspace-relative path to an existing video_production project.',
            },
            'assembly_engine_id': {
              'type': 'string',
              'maxLength': 64,
              'description': 'Installed Phase 7 engine adapter used to assemble all scene assets into the final project video.',
            },
            'routes': {
              'type': 'array',
              'maxItems': 120,
              'description': 'Exactly one route per project scene. Each route: {scene_id, mode: code|provider, engine_id OR provider_id, optional model and skill_ids}.',
              'items': {
                'type': 'object',
                'additionalProperties': false,
                'properties': {
                  'scene_id': {'type': 'string', 'maxLength': 64},
                  'mode': {'type': 'string', 'enum': ['code', 'provider']},
                  'engine_id': {'type': 'string', 'maxLength': 64},
                  'provider_id': {'type': 'string', 'maxLength': 64},
                  'model': {'type': 'string', 'maxLength': 120},
                  'skill_ids': {
                    'type': 'array',
                    'maxItems': 12,
                    'uniqueItems': true,
                    'items': {'type': 'string', 'maxLength': 64},
                  },
                },
                'required': ['scene_id', 'mode'],
              },
            },
            'audio_policy': {
              'type': 'string',
              'enum': ['preserve', 'prefer_generated', 'mute'],
              'default': 'preserve',
            },
            'scene_id': {'type': 'string', 'maxLength': 64},
            'image_url': {
              'type': 'string',
              'maxLength': 4096,
              'description': 'Optional public HTTPS image input for this provider scene only. It is not persisted.',
            },
            'runtime_profile_id': {'type': 'string', 'maxLength': 64},
            'retry': {
              'type': 'boolean',
              'default': false,
              'description': 'Must be true to deliberately retry a failed scene.',
            },
          },
          'required': ['action'],
        },
      },
    },
  ];
}
