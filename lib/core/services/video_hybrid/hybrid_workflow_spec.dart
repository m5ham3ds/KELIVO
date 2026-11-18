/// Declarative routing for a hybrid video production workflow.
///
/// This model deliberately contains only non-secret routing metadata. Provider
/// credentials and transient image URLs are never part of a saved workflow.
final class HybridWorkflowSpecException implements Exception {
  const HybridWorkflowSpecException(this.code);

  final String code;

  @override
  String toString() => code;
}

/// Immutable identity for a renderer/provider manifest selected by a workflow.
/// The digest is a SHA-256 hex value; provider digests may use the `sha256:` prefix.
final class HybridDependencyPin {
  const HybridDependencyPin({required this.version, required this.digest});

  final String version;
  final String digest;

  Map<String, Object?> toJson() => {
    'version': version,
    'digest': digest.toLowerCase(),
  };

  bool matches(Object? currentVersion, Object? currentDigest) =>
      currentVersion == version &&
      currentDigest is String &&
      currentDigest.toLowerCase() == digest.toLowerCase();

  static HybridDependencyPin? tryParse(Object? raw) {
    if (raw is! Map || raw['version'] is! String || raw['digest'] is! String) {
      return null;
    }
    final version = (raw['version'] as String).trim();
    final digest = (raw['digest'] as String).trim();
    if (version.isEmpty || version.length > 128 ||
        !RegExp(r'^(?:sha256:)?[0-9a-fA-F]{64}$').hasMatch(digest)) {
      return null;
    }
    return HybridDependencyPin(version: version, digest: digest.toLowerCase());
  }
}

final class HybridSceneRoute {
  const HybridSceneRoute({
    required this.sceneId,
    required this.mode,
    this.engineId,
    this.providerId,
    this.model,
    this.skillIds = const <String>[],
  });

  final String sceneId;
  final HybridSceneMode mode;
  final String? engineId;
  final String? providerId;
  final String? model;
  final List<String> skillIds;

  /// Parses a route that has already been persisted by [toJson].
  /// The external request schema uses snake_case, while stored workflow JSON
  /// intentionally follows the application's camelCase serialization style.
  factory HybridSceneRoute.fromSavedJson(Object? raw) {
    if (raw is! Map || raw.keys.any((key) => key is! String)) {
      throw const HybridWorkflowSpecException('hybrid_route_object_invalid');
    }
    // Accept both the persisted camelCase shape and older/request-style
    // snake_case data so previously saved workflows remain readable.
    final saved = <String, Object?>{
      for (final entry in raw.entries) entry.key as String: entry.value,
    };
    Object? value(String camelCase, String snakeCase) =>
        saved[camelCase] ?? saved[snakeCase];

    return HybridSceneRoute.parse({
      'scene_id': value('sceneId', 'scene_id'),
      'mode': saved['mode'],
      'engine_id': value('engineId', 'engine_id'),
      'provider_id': value('providerId', 'provider_id'),
      'model': saved['model'],
      'skill_ids': value('skillIds', 'skill_ids') ?? const <String>[],
    });
  }

  factory HybridSceneRoute.parse(Object? raw) {
    if (raw is! Map || raw.keys.any((key) => key is! String)) {
      throw const HybridWorkflowSpecException('hybrid_route_object_invalid');
    }
    final map = <String, Object?>{
      for (final entry in raw.entries) entry.key as String: entry.value,
    };
    final sceneId = _requiredText(map, 'scene_id', 64);
    if (!_safeId.hasMatch(sceneId)) {
      throw const HybridWorkflowSpecException('hybrid_scene_id_invalid');
    }
    final modeRaw = _requiredText(map, 'mode', 16);
    final mode = switch (modeRaw) {
      'code' => HybridSceneMode.code,
      'provider' => HybridSceneMode.provider,
      _ => throw const HybridWorkflowSpecException('hybrid_route_mode_invalid'),
    };
    final engineIdRaw = _optionalText(map['engine_id'], 64);
    final providerIdRaw = _optionalText(map['provider_id'], 64);
    final model = _optionalText(map['model'], 120);
    final skillsRaw = map['skill_ids'] ?? const <Object?>[];
    if (skillsRaw is! List || skillsRaw.length > 12 ||
        skillsRaw.any((item) => item is! String)) {
      throw const HybridWorkflowSpecException('hybrid_skill_ids_invalid');
    }
    final skillIds = <String>[];
    for (final item in skillsRaw.cast<String>()) {
      if (!_safeId.hasMatch(item) || skillIds.contains(item)) {
        throw const HybridWorkflowSpecException('hybrid_skill_ids_invalid');
      }
      skillIds.add(item);
    }

    if (mode == HybridSceneMode.code) {
      if (engineIdRaw == null || !_safeId.hasMatch(engineIdRaw) ||
          providerIdRaw != null || model != null) {
        throw const HybridWorkflowSpecException('hybrid_code_route_invalid');
      }
    } else if (providerIdRaw == null || !_safeId.hasMatch(providerIdRaw) ||
        engineIdRaw != null) {
      throw const HybridWorkflowSpecException('hybrid_provider_route_invalid');
    }

    return HybridSceneRoute(
      sceneId: sceneId,
      mode: mode,
      engineId: engineIdRaw,
      providerId: providerIdRaw,
      model: model,
      skillIds: List.unmodifiable(skillIds),
    );
  }

  Map<String, Object?> toJson() => {
    'sceneId': sceneId,
    'mode': mode.name,
    if (engineId != null) 'engineId': engineId,
    if (providerId != null) 'providerId': providerId,
    if (model != null) 'model': model,
    if (skillIds.isNotEmpty) 'skillIds': skillIds,
  };
}

enum HybridSceneMode { code, provider }

final class HybridWorkflowSpec {
  const HybridWorkflowSpec({
    required this.assemblyEngineId,
    required this.routes,
    required this.width,
    required this.height,
    required this.fps,
    required this.durationSeconds,
    required this.audioPolicy,
  });

  final String assemblyEngineId;
  final List<HybridSceneRoute> routes;
  final int width;
  final int height;
  final int fps;
  final double durationSeconds;
  final String audioPolicy;

  factory HybridWorkflowSpec.parse({
    required Object? routes,
    required Object? productionScenes,
    required Object? productionSpec,
    required Object? assemblyEngineId,
    Object? audioPolicy,
  }) {
    final assemblyId = _requiredValueText(assemblyEngineId, 64);
    if (!_safeId.hasMatch(assemblyId)) {
      throw const HybridWorkflowSpecException('hybrid_assembly_engine_id_invalid');
    }
    if (routes is! List || routes.isEmpty || routes.length > 120) {
      throw const HybridWorkflowSpecException('hybrid_routes_invalid');
    }
    if (productionScenes is! List || productionScenes.isEmpty ||
        productionScenes.length > 120) {
      throw const HybridWorkflowSpecException('hybrid_project_scenes_invalid');
    }
    if (productionSpec is! Map ||
        productionSpec.keys.any((key) => key is! String)) {
      throw const HybridWorkflowSpecException('hybrid_production_spec_invalid');
    }

    final sceneIds = <String>{};
    for (final rawScene in productionScenes) {
      if (rawScene is! Map || rawScene['id'] is! String) {
        throw const HybridWorkflowSpecException('hybrid_project_scenes_invalid');
      }
      final id = rawScene['id'] as String;
      if (!_safeId.hasMatch(id) || !sceneIds.add(id)) {
        throw const HybridWorkflowSpecException('hybrid_project_scenes_invalid');
      }
    }

    final parsedRoutes = <HybridSceneRoute>[];
    final routedScenes = <String>{};
    for (final rawRoute in routes) {
      final route = HybridSceneRoute.parse(rawRoute);
      if (!sceneIds.contains(route.sceneId) || !routedScenes.add(route.sceneId)) {
        throw const HybridWorkflowSpecException('hybrid_route_scene_mismatch');
      }
      if (route.mode == HybridSceneMode.code && route.engineId == assemblyId) {
        // This is allowed: a single engine may render scenes and assemble them.
      }
      parsedRoutes.add(route);
    }
    if (routedScenes.length != sceneIds.length) {
      throw const HybridWorkflowSpecException('hybrid_route_scene_missing');
    }

    final width = _boundedInt(productionSpec['width'], 64, 4096);
    final height = _boundedInt(productionSpec['height'], 64, 4096);
    final fps = _boundedInt(productionSpec['fps'], 1, 120);
    final durationRaw = productionSpec['durationSeconds'];
    if (durationRaw is! num || !durationRaw.toDouble().isFinite ||
        durationRaw <= 0 || durationRaw > 3600) {
      throw const HybridWorkflowSpecException('hybrid_duration_invalid');
    }
    final policy = (audioPolicy ?? 'preserve').toString();
    if (!const {'preserve', 'prefer_generated', 'mute'}.contains(policy)) {
      throw const HybridWorkflowSpecException('hybrid_audio_policy_invalid');
    }

    return HybridWorkflowSpec(
      assemblyEngineId: assemblyId,
      routes: List.unmodifiable(parsedRoutes),
      width: width,
      height: height,
      fps: fps,
      durationSeconds: durationRaw.toDouble(),
      audioPolicy: policy,
    );
  }

  Map<String, Object?> toJson({required String workflowId, required String now}) => {
    'schemaVersion': 1,
    'workflowId': workflowId,
    'createdAt': now,
    'updatedAt': now,
    'status': 'configured',
    'assemblyEngineId': assemblyEngineId,
    'targetProfile': {
      'width': width,
      'height': height,
      'fps': fps,
      'durationSeconds': durationSeconds,
      'format': 'mp4',
      'audioPolicy': audioPolicy,
    },
    'normalization': {
      'width': width,
      'height': height,
      'fps': fps,
      'audioPolicy': audioPolicy,
      'performedBy': 'selected_assembly_engine',
    },
    'routes': [for (final route in routes) route.toJson()],
    'sceneStates': {
      for (final route in routes)
        route.sceneId: <String, Object?>{'status': 'pending', 'attempt': 0},
    },
    'skillExecution': 'not_available_phase4_executor_pending',
  };
}

final _safeId = RegExp(r'^[a-z0-9][a-z0-9._-]{0,63}$');

String _requiredText(Map<String, Object?> map, String key, int maxLength) {
  final value = map[key];
  if (value is! String) {
    throw HybridWorkflowSpecException('hybrid_${key}_required');
  }
  return _requiredValueText(value, maxLength);
}

String _requiredValueText(Object? raw, int maxLength) {
  if (raw is! String) {
    throw const HybridWorkflowSpecException('hybrid_text_value_invalid');
  }
  final value = raw.trim();
  if (value.isEmpty || value.length > maxLength ||
      value.contains(RegExp(r'[\u0000-\u001f\u007f]'))) {
    throw const HybridWorkflowSpecException('hybrid_text_value_invalid');
  }
  return value;
}

String? _optionalText(Object? raw, int maxLength) {
  if (raw == null) return null;
  if (raw is! String) {
    throw const HybridWorkflowSpecException('hybrid_text_value_invalid');
  }
  final value = raw.trim();
  if (value.isEmpty) return null;
  if (value.length > maxLength ||
      value.contains(RegExp(r'[\u0000-\u001f\u007f]'))) {
    throw const HybridWorkflowSpecException('hybrid_text_value_invalid');
  }
  return value;
}

int _boundedInt(Object? raw, int min, int max) {
  if (raw is! int || raw < min || raw > max) {
    throw const HybridWorkflowSpecException('hybrid_target_profile_invalid');
  }
  return raw;
}
