import 'package:yaml/yaml.dart';

const String kVideoEngineManifestFile = 'kelivo.engine.yaml';

class VideoEngineManifestException implements Exception {
  const VideoEngineManifestException(this.code);

  final String code;

  @override
  String toString() => code;
}

/// Declarative contract for an optional CLI video engine adapter.
///
/// The manifest describes commands; it never executes them while parsing or
/// installing an adapter. Every invocation is routed through the workspace
/// runtime after explicit tool approval.
class VideoEngineManifest {
  const VideoEngineManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.description,
    required this.platforms,
    required this.architectures,
    required this.requiredCommands,
    required this.requiredEcosystems,
    required this.commands,
    this.outputExtension = 'mp4',
    this.supportsSceneRendering = false,
    this.supportsHybridAssembly = false,
    this.acceptsMp4Assets = false,
    this.schemaVersion = 1,
  });

  final int schemaVersion;
  final String id;
  final String name;
  final String version;
  final String description;
  final List<String> platforms;
  final List<String> architectures;
  final List<String> requiredCommands;
  final List<String> requiredEcosystems;
  final Map<String, VideoEngineCommand> commands;
  final String outputExtension;
  /// True only when the adapter can render one isolated scene project.
  final bool supportsSceneRendering;
  /// True only when the adapter can assemble a multi-scene Kelivo project.
  final bool supportsHybridAssembly;
  /// True only when the adapter accepts imported MP4 scene assets.
  final bool acceptsMp4Assets;

  VideoEngineCommand command(String name) {
    final value = commands[name];
    if (value == null) {
      throw VideoEngineManifestException('engine_command_not_declared:$name');
    }
    return value;
  }

  factory VideoEngineManifest.parse(String source) {
    final Object? decoded;
    try {
      decoded = _toPlain(loadYaml(source));
    } on Object {
      throw const VideoEngineManifestException('engine_manifest_yaml_invalid');
    }
    if (decoded is! Map<String, Object?>) {
      throw const VideoEngineManifestException('engine_manifest_root_invalid');
    }
    final schemaVersion = decoded['schemaVersion'];
    if (schemaVersion is! int || schemaVersion != 1) {
      throw const VideoEngineManifestException('engine_manifest_schema_unsupported');
    }

    final id = _requiredString(decoded, 'id', 64);
    if (!RegExp(r'^[a-z0-9][a-z0-9._-]{0,63}$').hasMatch(id)) {
      throw const VideoEngineManifestException('engine_manifest_id_invalid');
    }
    final name = _requiredString(decoded, 'name', 120);
    final version = _requiredString(decoded, 'version', 64);
    final description = _requiredString(decoded, 'description', 1000);

    final compatibility = _asMap(decoded['compatibility']);
    final platforms = _stringList(
      compatibility['platforms'] ?? const ['android'],
      'platforms',
      maxItems: 8,
    );
    final architectures = _stringList(
      compatibility['architectures'] ?? const ['arm64-v8a', 'aarch64'],
      'architectures',
      maxItems: 8,
    );
    const allowedPlatforms = {'android', 'all'};
    const allowedArchitectures = {
      'arm64-v8a',
      'aarch64',
      'all',
    };
    if (platforms.isEmpty || platforms.any((item) => !allowedPlatforms.contains(item))) {
      throw const VideoEngineManifestException('engine_manifest_platform_invalid');
    }
    if (architectures.isEmpty ||
        architectures.any((item) => !allowedArchitectures.contains(item))) {
      throw const VideoEngineManifestException('engine_manifest_architecture_invalid');
    }

    final runtime = _asMap(decoded['runtime']);
    final requiredEcosystems = _stringList(
      runtime['ecosystems'] ?? const <String>[],
      'runtime.ecosystems',
      maxItems: 2,
    );
    if (requiredEcosystems.any((item) => !const {'node', 'python'}.contains(item))) {
      throw const VideoEngineManifestException('engine_manifest_ecosystem_invalid');
    }

    final dependencies = _asMap(decoded['dependencies']);
    final requiredCommands = _stringList(
      dependencies['commands'] ?? const <String>[],
      'dependencies.commands',
      maxItems: 32,
    );
    if (requiredCommands.any(
      (item) => !RegExp(r'^[A-Za-z0-9_.+-]{1,80}$').hasMatch(item),
    )) {
      throw const VideoEngineManifestException('engine_manifest_dependency_command_invalid');
    }

    final rawCommands = _asMap(decoded['commands']);
    final commands = <String, VideoEngineCommand>{};
    for (final key in const ['version', 'preflight', 'create', 'render', 'inspect', 'cancel']) {
      final raw = rawCommands[key];
      if (raw != null) commands[key] = VideoEngineCommand.fromValue(raw, key);
    }
    for (final key in const ['preflight', 'create', 'render', 'inspect', 'cancel']) {
      if (!commands.containsKey(key)) {
        throw VideoEngineManifestException('engine_manifest_command_required:$key');
      }
    }
    final rawCapabilities = decoded['capabilities'];
    var supportsSceneRendering = false;
    var supportsHybridAssembly = false;
    var acceptsMp4Assets = false;
    if (rawCapabilities != null) {
      if (rawCapabilities is! Map ||
          rawCapabilities.keys.any((key) => key is! String) ||
          rawCapabilities.keys.any((key) => !const {
            'sceneRendering', 'hybridAssembly', 'acceptsMp4Assets',
          }.contains(key))) {
        throw const VideoEngineManifestException('engine_manifest_capabilities_invalid');
      }
      for (final entry in rawCapabilities.entries) {
        if (entry.value is! bool) {
          throw const VideoEngineManifestException('engine_manifest_capabilities_invalid');
        }
      }
      supportsSceneRendering = rawCapabilities['sceneRendering'] == true;
      supportsHybridAssembly = rawCapabilities['hybridAssembly'] == true;
      acceptsMp4Assets = rawCapabilities['acceptsMp4Assets'] == true;
      if (supportsHybridAssembly && !acceptsMp4Assets) {
        throw const VideoEngineManifestException('engine_manifest_hybrid_assets_required');
      }
    }

    final rawExtension = decoded['outputExtension'];
    if (rawExtension != null && rawExtension is! String) {
      throw const VideoEngineManifestException('engine_manifest_output_extension_invalid');
    }
    final extension = (rawExtension as String?)?.trim() ?? 'mp4';
    if (!RegExp(r'^[a-z0-9]{2,8}$').hasMatch(extension)) {
      throw const VideoEngineManifestException('engine_manifest_output_extension_invalid');
    }

    return VideoEngineManifest(
      id: id,
      name: name,
      version: version,
      description: description,
      platforms: List.unmodifiable(platforms),
      architectures: List.unmodifiable(architectures),
      requiredCommands: List.unmodifiable(requiredCommands),
      requiredEcosystems: List.unmodifiable(requiredEcosystems),
      commands: Map.unmodifiable(commands),
      outputExtension: extension,
      supportsSceneRendering: supportsSceneRendering,
      supportsHybridAssembly: supportsHybridAssembly,
      acceptsMp4Assets: acceptsMp4Assets,
      schemaVersion: schemaVersion,
    );
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'id': id,
    'name': name,
    'version': version,
    'description': description,
    'compatibility': {
      'platforms': platforms,
      'architectures': architectures,
    },
    'runtime': {'ecosystems': requiredEcosystems},
    'dependencies': {'commands': requiredCommands},
    'commands': {
      for (final entry in commands.entries) entry.key: entry.value.toJson(),
    },
    'outputExtension': outputExtension,
    'capabilities': {
      'sceneRendering': supportsSceneRendering,
      'hybridAssembly': supportsHybridAssembly,
      'acceptsMp4Assets': acceptsMp4Assets,
    },
  };
}

class VideoEngineCommand {
  const VideoEngineCommand({required this.executable, this.args = const []});

  final String executable;
  final List<String> args;

  factory VideoEngineCommand.fromValue(Object? value, String name) {
    if (value is! Map) {
      throw VideoEngineManifestException('engine_manifest_command_invalid:$name');
    }
    final map = _asMap(value);
    final executable = map['executable'];
    if (executable is! String || executable.isEmpty || executable.length > 240) {
      throw VideoEngineManifestException('engine_manifest_executable_invalid:$name');
    }
    final isPath = executable.contains('/');
    final validExecutable = isPath
        ? !executable.startsWith('/') &&
            !executable.contains('\\') &&
            !executable.split('/').any((part) => part.isEmpty || part == '.' || part == '..') &&
            RegExp(r'^[A-Za-z0-9_.+-]+(/[A-Za-z0-9_.+-]+)*$').hasMatch(executable)
        : RegExp(r'^[A-Za-z0-9_.+-]+$').hasMatch(executable);
    if (!validExecutable) {
      throw VideoEngineManifestException('engine_manifest_executable_unsafe:$name');
    }
    final rawArgs = map['args'] ?? const <Object?>[];
    if (rawArgs is! List || rawArgs.length > 64 || rawArgs.any((item) => item is! String)) {
      throw VideoEngineManifestException('engine_manifest_args_invalid:$name');
    }
    final args = rawArgs.cast<String>();
    for (final argument in args) {
      if (argument.length > 2048 || _hasControlCharacter(argument)) {
        throw VideoEngineManifestException('engine_manifest_arg_unsafe:$name');
      }
      for (final match in RegExp(r'\{\{([^{}]+)\}\}').allMatches(argument)) {
        if (!_allowedPlaceholders.contains(match.group(1))) {
          throw VideoEngineManifestException('engine_manifest_placeholder_unknown:$name');
        }
      }
      if (argument.contains('{{') &&
          !RegExp(r'^(?:[^{}]|\{\{(?:workspace|project_dir|project_name|output_path|output_dir|engine_root|run_id)\}\})*$')
              .hasMatch(argument)) {
        throw VideoEngineManifestException('engine_manifest_placeholder_invalid:$name');
      }
    }
    return VideoEngineCommand(
      executable: executable,
      args: List.unmodifiable(args),
    );
  }

  Map<String, Object?> toJson() => {
    'executable': executable,
    'args': args,
  };

  List<String> expandArguments(Map<String, String> values) {
    return [
      for (final argument in args)
        _expandArgument(argument, values),
    ];
  }

  static String _expandArgument(String input, Map<String, String> values) {
    return input.replaceAllMapped(RegExp(r'\{\{([^{}]+)\}\}'), (match) {
      final name = match.group(1)!;
      final value = values[name];
      if (value == null) {
        throw VideoEngineManifestException('engine_placeholder_value_missing:$name');
      }
      return value;
    });
  }
}

const Set<String> _allowedPlaceholders = {
  'workspace',
  'project_dir',
  'project_name',
  'output_path',
  'output_dir',
  'engine_root',
  'run_id',
};

Map<String, Object?> _asMap(Object? value) {
  if (value == null) return const <String, Object?>{};
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw const VideoEngineManifestException('engine_manifest_object_invalid');
  }
  return {
    for (final entry in value.entries)
      entry.key as String: _toPlain(entry.value),
  };
}

Object? _toPlain(Object? value) {
  if (value is YamlMap) {
    if (value.keys.any((key) => key is! String)) {
      throw const VideoEngineManifestException('engine_manifest_object_invalid');
    }
    return {
      for (final entry in value.entries)
        entry.key as String: _toPlain(entry.value),
    };
  }
  if (value is YamlList) return value.map(_toPlain).toList();
  if (value is Map) {
    if (value.keys.any((key) => key is! String)) {
      throw const VideoEngineManifestException('engine_manifest_object_invalid');
    }
    return {
      for (final entry in value.entries)
        entry.key as String: _toPlain(entry.value),
    };
  }
  if (value is List) return value.map(_toPlain).toList();
  return value;
}

String _requiredString(Map<String, Object?> map, String key, int maxLength) {
  final value = map[key];
  if (value is! String || value.trim().isEmpty || value.length > maxLength ||
      _hasControlCharacter(value)) {
    throw VideoEngineManifestException('engine_manifest_${key}_invalid');
  }
  return value.trim();
}

List<String> _stringList(Object? value, String label, {required int maxItems}) {
  if (value is! List || value.length > maxItems || value.any((item) => item is! String)) {
    throw VideoEngineManifestException('engine_manifest_list_invalid:$label');
  }
  final result = value.cast<String>().map((item) => item.trim()).toList();
  if (result.any((item) => item.isEmpty || item.length > 80 || _hasControlCharacter(item)) ||
      result.toSet().length != result.length) {
    throw VideoEngineManifestException('engine_manifest_list_invalid:$label');
  }
  return result;
}

bool _hasControlCharacter(String value) =>
    value.contains(RegExp(r'[\x00-\x1f\x7f]'));
