/// Parsed Claude-compatible Plugin manifest metadata.
///
/// Unknown fields are retained for inspection. This model does not interpret
/// executable declarations as permission to run them.
final class PluginManifest {
  const PluginManifest({
    required this.name,
    this.version,
    this.description,
    this.author,
    this.homepage,
    this.repository,
    this.license,
    this.keywords = const <String>[],
    this.commandPaths = const <String>[],
    this.agentPaths = const <String>[],
    this.skillPaths = const <String>[],
    this.hookPaths = const <String>[],
    this.outputStylePaths = const <String>[],
    this.unknownFields = const <String, Object?>{},
    this.warnings = const <String>[],
  });

  static const int schemaVersion = 1;
  static const Set<String> _knownFields = {
    'name',
    'version',
    'description',
    'author',
    'homepage',
    'repository',
    'license',
    'keywords',
    'commands',
    'agents',
    'skills',
    'hooks',
    'mcpServers',
    'lspServers',
    'outputStyles',
    'strict',
  };

  final String name;
  final String? version;
  final String? description;
  final Object? author;
  final String? homepage;
  final String? repository;
  final String? license;
  final List<String> keywords;
  final List<String> commandPaths;
  final List<String> agentPaths;
  final List<String> skillPaths;
  final List<String> hookPaths;
  final List<String> outputStylePaths;
  final Map<String, Object?> unknownFields;
  final List<String> warnings;

  factory PluginManifest.fromJson(Map<String, Object?> json) {
    String? optionalText(String key, {int maxLength = 2048}) {
      final value = json[key];
      if (value == null) return null;
      if (value is! String ||
          value.trim().isEmpty ||
          value.length > maxLength) {
        throw FormatException('plugin_manifest_' + key);
      }
      return value.trim();
    }

    List<String> readPaths(String key) {
      final value = json[key];
      if (value == null) return const <String>[];
      if (value is String) return [value];
      if (value is! List ||
          value.length > 128 ||
          value.any((item) => item is! String)) {
        throw FormatException('plugin_manifest_' + key);
      }
      return value.cast<String>();
    }

    final name = optionalText('name', maxLength: 160);
    if (name == null) {
      throw const FormatException('plugin_manifest_name_required');
    }
    final rawKeywords = json['keywords'];
    if (rawKeywords != null &&
        (rawKeywords is! List ||
            rawKeywords.length > 256 ||
            rawKeywords.any((item) => item is! String))) {
      throw const FormatException('plugin_manifest_keywords');
    }
    final author = json['author'];
    if (author != null && author is! String && author is! Map) {
      throw const FormatException('plugin_manifest_author');
    }

    final unsupported = <String, Object?>{};
    final warnings = <String>[];
    for (final entry in json.entries) {
      if (!_knownFields.contains(entry.key)) {
        unsupported[entry.key] = entry.value;
      }
    }
    if (unsupported.isNotEmpty) {
      warnings.add(
        'unknown_manifest_fields:' +
            (unsupported.keys.toList()..sort()).join(','),
      );
    }
    if (json['hooks'] is Map) {
      unsupported['hooks'] = json['hooks'];
      warnings.add('inline_hooks_metadata_only');
    }
    for (final key in ['mcpServers', 'lspServers', 'outputStyles', 'strict']) {
      if (json.containsKey(key)) {
        unsupported[key] = json[key];
        warnings.add('unsupported_manifest_field:' + key);
      }
    }

    return PluginManifest(
      name: name,
      version: optionalText('version', maxLength: 128),
      description: optionalText('description', maxLength: 8192),
      author: author,
      homepage: optionalText('homepage'),
      repository: optionalText('repository'),
      license: optionalText('license', maxLength: 256),
      keywords: rawKeywords == null
          ? const <String>[]
          : List<String>.unmodifiable(rawKeywords.cast<String>()),
      commandPaths: List<String>.unmodifiable(readPaths('commands')),
      agentPaths: List<String>.unmodifiable(readPaths('agents')),
      skillPaths: List<String>.unmodifiable(readPaths('skills')),
      hookPaths: json['hooks'] is Map
          ? const <String>[]
          : List<String>.unmodifiable(readPaths('hooks')),
      outputStylePaths: json['outputStyles'] is String ||
              (json['outputStyles'] is List &&
                  (json['outputStyles'] as List).every((item) => item is String))
          ? List<String>.unmodifiable(readPaths('outputStyles'))
          : const <String>[],
      unknownFields: Map<String, Object?>.unmodifiable(unsupported),
      warnings: List<String>.unmodifiable(warnings),
    );
  }
}
