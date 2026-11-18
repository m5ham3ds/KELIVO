/// Conversation-first management for optional, declarative AI video providers.
abstract final class VideoProviderToolNames {
  static const String manage = 'video_provider';
  static const Set<String> all = {manage};
}

abstract final class VideoProviderToolCatalog {
  static List<Map<String, dynamic>> definitions() => [
    {
      'type': 'function',
      'function': {
        'name': VideoProviderToolNames.manage,
        'description': [
          'Manage optional AI video-generation provider connectors in the active Workspace. ',
          'Connectors are declarative YAML REST mappings; no downloaded connector code is executed. ',
          'Install accepts a kelivo.video-provider.yaml manifest or a raw.githubusercontent.com manifest URL. ',
          'Use credential_status to check whether the API key was configured in Workspace settings; never request or include API keys in chat/tool arguments. ',
          'submit starts an asynchronous provider job and may incur charges, so explicit approval is required. ',
          'poll checks a job; download imports the resulting MP4 into the selected scene of an existing video_production project. ',
          'Price is shown only when the connector provides a live quote endpoint. Set a daily budget to block submissions when a quote cannot be verified. ',
          'Provider selection is per task and does not change the selected local video render engine.',
        ].join(),
        'parameters': {
          'type': 'object',
          'additionalProperties': false,
          'properties': {
            'action': {
              'type': 'string',
              'enum': [
                'list', 'inspect', 'install', 'update', 'remove',
                'credential_status', 'limits', 'set_limits', 'submit', 'poll', 'download',
              ],
              'default': 'list',
            },
            'provider_id': {'type': 'string', 'maxLength': 64},
            'manifest': {
              'type': 'string',
              'maxLength': 65536,
              'description': 'Complete declarative kelivo.video-provider.yaml contents. Must not contain API keys or secrets.',
            },
            'source': {
              'type': 'string',
              'maxLength': 2048,
              'description': 'Workspace path to kelivo.video-provider.yaml or HTTPS raw.githubusercontent.com URL.',
            },
            'max_requests_per_day': {'type': 'integer', 'minimum': 1, 'maximum': 1000},
            'max_concurrent_jobs': {'type': 'integer', 'minimum': 1, 'maximum': 10},
            'max_download_bytes': {'type': 'integer', 'minimum': 1048576, 'maximum': 268435456},
            'daily_budget_micros': {
              'type': 'integer',
              'minimum': 0,
              'maximum': 100000000000000,
              'description': 'Optional per-Workspace daily budget in millionths of budget_currency. A positive budget requires a provider quote endpoint.',
            },
            'budget_currency': {'type': 'string', 'pattern': r'^[A-Za-z]{3}$'},
            'prompt': {'type': 'string', 'maxLength': 12000},
            'image_url': {
              'type': 'string',
              'maxLength': 4096,
              'description': 'Optional public HTTPS image URL for image-to-video connectors. The URL is sent to the selected provider and is not persisted in job history.',
            },
            'model': {'type': 'string', 'maxLength': 120},
            'duration_seconds': {'type': 'number', 'minimum': 0.1, 'maximum': 3600},
            'aspect_ratio': {'type': 'string', 'maxLength': 32},
            'project_dir': {
              'type': 'string',
              'maxLength': 1024,
              'description': 'Workspace-relative path to an existing video_production project.',
            },
            'scene_id': {
              'type': 'string',
              'maxLength': 64,
              'description': 'Existing scene in the target video project. The downloaded MP4 is linked to this scene.',
            },
            'job_id': {'type': 'string', 'maxLength': 128},
          },
          'required': ['action'],
        },
      },
    },
  ];
}
