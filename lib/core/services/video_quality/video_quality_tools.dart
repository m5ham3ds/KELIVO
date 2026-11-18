abstract final class VideoQualityToolNames {
  static const String manage = 'video_quality';
  static const Set<String> all = {manage};
}

abstract final class VideoQualityToolCatalog {
  static List<Map<String, dynamic>> definitions() => [
    {
      'type': 'function',
      'function': {
        'name': VideoQualityToolNames.manage,
        'description': [
          'Inspect rendered video outputs and recover a failed hybrid scene without discarding completed scenes. ',
          'inspect uses ffprobe when installed in the selected Android PRoot Runtime Profile and checks MP4 container, video stream, dimensions, FPS, duration, audio policy, A/V start offset and optional SRT/VTT cue timing. ',
          'deep_scan uses ffmpeg blackdetect and silencedetect; results are review signals, not proof that intentional fades or silent scenes are defects. ',
          'samples creates a contact sheet in the project .kelivo/quality folder; then use view_image to inspect it. ',
          'compare compares core media metadata against the prior QA baseline. diagnose classifies a supplied failure without installing arbitrary packages. ',
          'retry_scene retries only a failed scene in an already-configured hybrid workflow, with a maximum of two QA recovery retries per scene; successful scene assets are retained. ',
          'FFmpeg is not bundled or automatically installed. When missing, use package_manager only after confirming the project Runtime Profile, distribution and package source. ',
          'All generated reports and sample images remain inside the Workspace project. No media file is overwritten by QA.',
        ].join(),
        'parameters': {
          'type': 'object',
          'additionalProperties': false,
          'properties': {
            'action': {
              'type': 'string',
              'enum': ['inspect', 'deep_scan', 'samples', 'compare', 'diagnose', 'retry_scene'],
              'default': 'inspect',
            },
            'video_path': {
              'type': 'string',
              'maxLength': 1024,
              'description': 'Workspace-relative path to an MP4 output. Required for inspect, deep_scan, samples and compare.',
            },
            'project_dir': {
              'type': 'string',
              'maxLength': 1024,
              'description': 'Optional Workspace-relative production project directory for report persistence or failed-scene recovery.',
            },
            'runtime_profile_id': {'type': 'string', 'maxLength': 64},
            'expected_width': {'type': 'integer', 'minimum': 64, 'maximum': 8192},
            'expected_height': {'type': 'integer', 'minimum': 64, 'maximum': 8192},
            'expected_fps': {'type': 'number', 'minimum': 1, 'maximum': 240},
            'expected_duration_seconds': {'type': 'number', 'minimum': 0.1, 'maximum': 86400},
            'duration_tolerance_seconds': {'type': 'number', 'minimum': 0, 'maximum': 30, 'default': 1},
            'audio_policy': {'type': 'string', 'enum': ['preserve', 'prefer_generated', 'mute'], 'default': 'preserve'},
            'require_audio': {'type': 'boolean', 'default': false},
            'subtitle_paths': {
              'type': 'array',
              'maxItems': 32,
              'items': {'type': 'string', 'maxLength': 1024},
            },
            'count': {'type': 'integer', 'minimum': 1, 'maximum': 12, 'default': 6},
            'error_code': {'type': 'string', 'maxLength': 4000},
            'scene_id': {'type': 'string', 'maxLength': 64},
          },
          'required': ['action'],
        },
      },
    },
  ];
}
