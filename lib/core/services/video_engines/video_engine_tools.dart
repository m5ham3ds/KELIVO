/// Structured conversational tool for optional, project-local CLI video engines.
/// Mutating operations and every engine command are explicitly approved by the
/// central ToolCallPermission flow in ToolHandlerService.
abstract final class VideoEngineToolNames {
  static const String manage = 'video_engine';
  static const Set<String> all = {manage};
}

abstract final class VideoEngineToolCatalog {
  static List<Map<String, dynamic>> definitions() => [
    {
      'type': 'function',
      'function': {
        'name': VideoEngineToolNames.manage,
        'description':
            'Manage optional CLI video-engine adapters installed inside the active project. Engines are not bundled into the APK. Install from a public GitHub repository/subfolder or a local workspace folder/ZIP containing kelivo.engine.yaml. Installation only validates and stores package files; it does not execute scripts or install dependencies. Run preflight before selecting an engine. Use resource_preflight to inspect Android RAM, storage, process CPU and thermal pressure before local rendering. A render is blocked under critical measured pressure and returns warnings under moderate pressure; no resolution is silently changed and no running process is automatically paused. Mutating engine commands require user approval and run through Android PRoot using an optional project Runtime Profile. An engine is not verified or supported until a real render creates a non-empty output file. PRoot/runtime profiles are not a kernel security sandbox; only install adapters from trusted sources.',
        'parameters': {
          'type': 'object',
          'additionalProperties': false,
          'properties': {
            'action': {
              'type': 'string',
              'enum': [
                'list',
                'resource_preflight',
                'install',
                'inspect',
                'preflight',
                'set_default',
                'clear_default',
                'configure',
                'create',
                'render',
                'inspect_project',
                'cancel',
                'remove',
              ],
              'description': 'Operation. list/inspect/resource_preflight are read-only; preflight and project commands execute adapter-defined commands and require approval.',
              'default': 'list',
            },
            'source': {
              'type': 'string',
              'description': 'For install: public GitHub repository/subfolder URL, or a local folder/ZIP path inside the active workspace. The package root must contain kelivo.engine.yaml.',
              'maxLength': 2048,
            },
            'engine_id': {
              'type': 'string',
              'description': 'Installed adapter ID. Omit for create/render/inspect_project to use the active project default.',
              'maxLength': 64,
            },
            'runtime_profile_id': {
              'type': 'string',
              'description': 'Optional project Runtime Profile whose isolated Python/Node directories and limits should be used. Otherwise the project default Runtime Profile is used.',
              'maxLength': 64,
            },
            'settings': {
              'type': 'object',
              'description': 'Non-secret string settings stored per project and adapter. Keys that look like credentials, tokens, passwords or API keys are rejected.',
              'additionalProperties': {'type': 'string', 'maxLength': 4096},
              'maxProperties': 64,
            },
            'project_name': {
              'type': 'string',
              'description': 'For create: new project folder name. The folder must not already exist.',
              'maxLength': 80,
            },
            'project_dir': {
              'type': 'string',
              'description': 'Workspace-relative project directory for render or inspect_project. Defaults to the active project directory.',
              'maxLength': 1024,
            },
            'run_id': {
              'type': 'string',
              'description': 'For cancel: run ID returned by a previous create/render/inspect operation.',
              'maxLength': 64,
            },
          },
          'required': ['action'],
        },
      },
    },
  ];
}
