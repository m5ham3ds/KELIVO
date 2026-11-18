abstract final class VideoProductionToolNames {
  static const String manage = 'video_production';
  static const Set<String> all = {manage};
}

abstract final class VideoProductionToolCatalog {
  static List<Map<String, dynamic>> definitions() => [
    {
      'type': 'function',
      'function': {
        'name': VideoProductionToolNames.manage,
        'description': [
          'Plan and manage reproducible, code-generated video projects in the active Workspace. ',
          'Use plan to validate a brief and storyboard without writing files. ',
          'Use create to save the production spec, storyboard and generated source files. ',
          'Use update to revise project parameters, scenes or source files; overwriting existing source requires overwrite=true. ',
          'Use render to invoke the selected optional Phase 7 video engine adapter (Android PRoot; user approval required). ',
          'Use export to copy a verified MP4 and package the project source as a ZIP. ',
          'No video engine, provider, Skill or package is bundled or installed by this tool. ',
          'Use package_manager separately for approved dependencies. Skills are recorded only as project content until a Skills executor is available. ',
          'Preview rendering and live frame-progress are not yet supported by the current engine contract.',
        ].join(),
        'parameters': {
          'type': 'object',
          'additionalProperties': false,
          'properties': {
            'action': {
              'type': 'string',
              'enum': ['plan', 'create', 'update', 'status', 'render', 'export'],
              'description': 'Operation. plan/status are read-only; create/update/render/export require explicit user approval.',
              'default': 'plan',
            },
            'project_name': {
              'type': 'string',
              'description': 'New project name for create, or existing project name when project_dir is omitted.',
              'maxLength': 64,
            },
            'project_dir': {
              'type': 'string',
              'description': 'Workspace-relative path to the project directory. For create it must not already exist.',
              'maxLength': 1024,
            },
            'spec': {
              'type': 'object',
              'additionalProperties': false,
              'properties': {
                'title': {'type': 'string', 'maxLength': 120},
                'prompt': {'type': 'string', 'maxLength': 12000},
                'aspectRatio': {
                  'type': 'string',
                  'enum': ['16:9', '9:16', '1:1', '4:5', '3:2', '2:3', 'custom'],
                },
                'width': {'type': 'integer', 'minimum': 64, 'maximum': 4096},
                'height': {'type': 'integer', 'minimum': 64, 'maximum': 4096},
                'fps': {'type': 'integer', 'minimum': 1, 'maximum': 120},
                'durationSeconds': {'type': 'number', 'minimum': 0.5, 'maximum': 3600},
                'outputFormat': {'type': 'string', 'enum': ['mp4']},
                'visualStyle': {'type': 'string', 'maxLength': 2000},
                'language': {'type': 'string', 'maxLength': 80},
                'narrationDirection': {'type': 'string', 'maxLength': 2000},
                'musicDirection': {'type': 'string', 'maxLength': 2000},
                'notes': {'type': 'string', 'maxLength': 4000},
              },
              'required': ['title', 'prompt'],
            },
            'scenes': {
              'type': 'array',
              'maxItems': 120,
              'items': {
                'type': 'object',
                'additionalProperties': false,
                'properties': {
                  'id': {'type': 'string', 'maxLength': 64},
                  'title': {'type': 'string', 'maxLength': 160},
                  'durationSeconds': {'type': 'number', 'minimum': 0.01, 'maximum': 3600},
                  'description': {'type': 'string', 'maxLength': 3000},
                  'visualPrompt': {'type': 'string', 'maxLength': 6000},
                  'narration': {'type': 'string', 'maxLength': 3000},
                  'transition': {'type': 'string', 'maxLength': 500},
                  'assetPaths': {
                    'type': 'array',
                    'maxItems': 64,
                    'items': {'type': 'string', 'maxLength': 240},
                  },
                },
                'required': ['id', 'title', 'durationSeconds'],
              },
            },
            'files': {
              'type': 'object',
              'description': 'Map of safe project-relative source paths to complete UTF-8 source text. Do not include absolute paths, traversal segments, or Kelivo metadata files.',
              'additionalProperties': {'type': 'string', 'maxLength': 524288},
            },
            'overwrite': {
              'type': 'boolean',
              'description': 'For update only. Must be true to replace an existing source file; the prior file is backed up first.',
              'default': false,
            },
            'engine_id': {
              'type': 'string',
              'description': 'Optional installed Phase 7 engine adapter ID for render. Defaults to the active Workspace engine.',
              'maxLength': 64,
            },
            'runtime_profile_id': {
              'type': 'string',
              'description': 'Optional project Runtime Profile used during render.',
              'maxLength': 64,
            },
          },
          'required': ['action'],
        },
      },
    },
  ];
}
