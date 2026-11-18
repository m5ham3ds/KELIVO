/// Validated, renderer-neutral production brief and scene plan.
///
/// This is project metadata, not an engine-specific timeline format. Optional
/// engines receive the saved project/source files through the Phase 7 adapter.
final class VideoProductionSpecException implements Exception {
  const VideoProductionSpecException(this.code);

  final String code;

  @override
  String toString() => code;
}

final class VideoProductionSpec {
  const VideoProductionSpec({
    required this.title,
    required this.prompt,
    required this.aspectRatio,
    required this.width,
    required this.height,
    required this.fps,
    required this.durationSeconds,
    required this.outputFormat,
    this.visualStyle = '',
    this.language = '',
    this.narrationDirection = '',
    this.musicDirection = '',
    this.notes = '',
  });

  final String title;
  final String prompt;
  final String aspectRatio;
  final int width;
  final int height;
  final int fps;
  final double durationSeconds;
  final String outputFormat;
  final String visualStyle;
  final String language;
  final String narrationDirection;
  final String musicDirection;
  final String notes;

  int get estimatedFrames => (durationSeconds * fps).ceil();

  factory VideoProductionSpec.parse(Object? raw) {
    if (raw is! Map || raw.keys.any((key) => key is! String)) {
      throw const VideoProductionSpecException('production_spec_object_required');
    }
    final map = <String, Object?>{
      for (final entry in raw.entries) entry.key as String: entry.value,
    };
    final title = _requiredText(map, 'title', maxLength: 120);
    final prompt = _requiredText(map, 'prompt', maxLength: 12000);
    final aspectRatio = (map['aspectRatio'] ?? '16:9').toString().trim();
    const presets = {
      '16:9': (1920, 1080),
      '9:16': (1080, 1920),
      '1:1': (1080, 1080),
      '4:5': (1080, 1350),
      '3:2': (1620, 1080),
      '2:3': (1080, 1620),
      'custom': (1920, 1080),
    };
    final preset = presets[aspectRatio];
    if (preset == null) {
      throw const VideoProductionSpecException('production_aspect_ratio_invalid');
    }
    final width = _integer(map['width'], fallback: preset.$1);
    final height = _integer(map['height'], fallback: preset.$2);
    if (width < 64 || width > 4096 || height < 64 || height > 4096) {
      throw const VideoProductionSpecException('production_dimensions_out_of_range');
    }
    if (aspectRatio != 'custom' && width * preset.$2 != height * preset.$1) {
      throw const VideoProductionSpecException(
        'production_aspect_ratio_dimensions_mismatch',
      );
    }
    final fps = _integer(map['fps'], fallback: 30);
    if (fps < 1 || fps > 120) {
      throw const VideoProductionSpecException('production_fps_out_of_range');
    }
    final durationRaw = map['durationSeconds'] ?? 30;
    if (durationRaw is! num || !durationRaw.toDouble().isFinite) {
      throw const VideoProductionSpecException('production_duration_invalid');
    }
    final duration = durationRaw.toDouble();
    if (duration < 0.5 || duration > 3600) {
      throw const VideoProductionSpecException('production_duration_out_of_range');
    }
    final outputFormat = (map['outputFormat'] ?? 'mp4').toString().trim().toLowerCase();
    if (outputFormat != 'mp4') {
      throw const VideoProductionSpecException('production_output_format_unsupported');
    }

    return VideoProductionSpec(
      title: title,
      prompt: prompt,
      aspectRatio: aspectRatio,
      width: width,
      height: height,
      fps: fps,
      durationSeconds: duration,
      outputFormat: outputFormat,
      visualStyle: _optionalText(map, 'visualStyle', 2000),
      language: _optionalText(map, 'language', 80),
      narrationDirection: _optionalText(map, 'narrationDirection', 2000),
      musicDirection: _optionalText(map, 'musicDirection', 2000),
      notes: _optionalText(map, 'notes', 4000),
    );
  }

  Map<String, Object?> toJson() => {
    'title': title,
    'prompt': prompt,
    'aspectRatio': aspectRatio,
    'width': width,
    'height': height,
    'fps': fps,
    'durationSeconds': durationSeconds,
    'estimatedFrames': estimatedFrames,
    'outputFormat': outputFormat,
    'visualStyle': visualStyle,
    'language': language,
    'narrationDirection': narrationDirection,
    'musicDirection': musicDirection,
    'notes': notes,
  };
}

final class VideoProductionScene {
  const VideoProductionScene({
    required this.id,
    required this.title,
    required this.durationSeconds,
    required this.description,
    required this.visualPrompt,
    this.narration = '',
    this.transition = '',
    this.assetPaths = const <String>[],
  });

  final String id;
  final String title;
  final double durationSeconds;
  final String description;
  final String visualPrompt;
  final String narration;
  final String transition;
  final List<String> assetPaths;

  factory VideoProductionScene.parse(Object? raw) {
    if (raw is! Map || raw.keys.any((key) => key is! String)) {
      throw const VideoProductionSpecException('production_scene_object_invalid');
    }
    final map = <String, Object?>{
      for (final entry in raw.entries) entry.key as String: entry.value,
    };
    final id = _requiredText(map, 'id', maxLength: 64);
    if (!RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(id)) {
      throw const VideoProductionSpecException('production_scene_id_invalid');
    }
    final title = _requiredText(map, 'title', maxLength: 160);
    final durationRaw = map['durationSeconds'];
    if (durationRaw is! num ||
        !durationRaw.toDouble().isFinite ||
        durationRaw <= 0 ||
        durationRaw > 3600) {
      throw const VideoProductionSpecException('production_scene_duration_invalid');
    }
    final assetsRaw = map['assetPaths'] ?? const <Object?>[];
    if (assetsRaw is! List || assetsRaw.length > 64) {
      throw const VideoProductionSpecException('production_scene_assets_invalid');
    }
    final assets = <String>[];
    for (final value in assetsRaw) {
      if (value is! String) {
        throw const VideoProductionSpecException('production_scene_assets_invalid');
      }
      assets.add(validateRelativeSourcePath(value));
    }
    return VideoProductionScene(
      id: id,
      title: title,
      durationSeconds: durationRaw.toDouble(),
      description: _optionalText(map, 'description', 3000),
      visualPrompt: _optionalText(map, 'visualPrompt', 6000),
      narration: _optionalText(map, 'narration', 3000),
      transition: _optionalText(map, 'transition', 500),
      assetPaths: List.unmodifiable(assets),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'durationSeconds': durationSeconds,
    'description': description,
    'visualPrompt': visualPrompt,
    'narration': narration,
    'transition': transition,
    'assetPaths': assetPaths,
  };
}

List<VideoProductionScene> parseVideoProductionScenes(
  Object? raw, {
  required VideoProductionSpec spec,
}) {
  if (raw == null) return const <VideoProductionScene>[];
  if (raw is! List || raw.length > 120) {
    throw const VideoProductionSpecException('production_scenes_invalid');
  }
  final scenes = raw.map(VideoProductionScene.parse).toList(growable: false);
  final seen = <String>{};
  var total = 0.0;
  for (final scene in scenes) {
    if (!seen.add(scene.id)) {
      throw const VideoProductionSpecException('production_scene_id_duplicate');
    }
    total += scene.durationSeconds;
  }
  if (total > spec.durationSeconds + 0.001) {
    throw const VideoProductionSpecException('production_scene_total_exceeds_duration');
  }
  return List.unmodifiable(scenes);
}

/// Validates a source-file path relative to a video project directory.
///
/// Hidden Kelivo metadata paths and absolute/traversal paths are reserved.
String validateRelativeSourcePath(String raw) {
  if (raw.isEmpty ||
      raw.length > 240 ||
      raw.startsWith('/') ||
      raw.contains('\\') ||
      raw.contains('\u0000') ||
      raw.contains(RegExp(r'[\x00-\x1f\x7f]'))) {
    throw const VideoProductionSpecException('production_source_path_invalid');
  }
  final segments = raw.split('/');
  if (segments.any((part) => part.isEmpty || part == '.' || part == '..')) {
    throw const VideoProductionSpecException('production_source_path_invalid');
  }
  if (segments.any((part) => part.startsWith('.')) ||
      const {'kelivo.production.json', 'storyboard.json', 'storyboard.md'}
          .contains(raw.toLowerCase())) {
    throw const VideoProductionSpecException('production_source_path_reserved');
  }
  if (segments.any((part) => part.contains(':'))) {
    throw const VideoProductionSpecException('production_source_path_invalid');
  }
  return raw;
}

String _requiredText(
  Map<String, Object?> map,
  String key, {
  required int maxLength,
}) {
  final value = map[key];
  if (value is! String || value.trim().isEmpty || value.length > maxLength) {
    throw VideoProductionSpecException('production_${key}_invalid');
  }
  return value.trim();
}

String _optionalText(Map<String, Object?> map, String key, int maxLength) {
  final value = map[key];
  if (value == null) return '';
  if (value is! String || value.length > maxLength ||
      value.contains(RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]'))) {
    throw VideoProductionSpecException('production_${key}_invalid');
  }
  return value.trim();
}

int _integer(Object? value, {required int fallback}) {
  if (value == null) return fallback;
  if (value is! num || value % 1 != 0 || !value.isFinite) {
    throw const VideoProductionSpecException('production_integer_invalid');
  }
  return value.toInt();
}
