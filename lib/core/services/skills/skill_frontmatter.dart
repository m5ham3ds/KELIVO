import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

/// Parsed Agent Skills `SKILL.md` frontmatter and Markdown instructions.
///
/// Kelivo keeps every supported standard field and unknown extension field;
/// unknown fields are reported by [compatibilityWarnings] instead of being
/// silently discarded or rewritten.
class SkillFrontmatter {
  const SkillFrontmatter({
    required this.name,
    required this.description,
    required this.body,
    this.extras = const <String, dynamic>{},
    this.hasFrontmatter = true,
    this.parseError,
    this.license,
    this.compatibility,
    this.metadata = const <String, String>{},
    this.metadataIsValid = true,
    this.allowedTools,
    this.unknownFields = const <String>{},
  });

  final String name;
  final String description;
  final String body;
  final Map<String, dynamic> extras;
  final bool hasFrontmatter;
  final String? parseError;
  final String? license;
  final String? compatibility;
  final Map<String, String> metadata;
  final bool metadataIsValid;
  final String? allowedTools;
  final Set<String> unknownFields;

  /// Reads only the bounded leading YAML metadata block from a Skill file.
  /// It stops at the closing fence rather than loading the Markdown body.
  /// Truncated/unterminated headers stay invalid and are rejected by parse().
  static Future<String> readHeader(
    File file, {
    int maxBytes = 64 * 1024,
  }) async {
    if (maxBytes < 1) {
      throw ArgumentError.value(maxBytes, 'maxBytes', 'must be positive');
    }
    final buffer = StringBuffer();
    var firstLine = true;
    await for (final line in file
        .openRead(0, maxBytes)
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())) {
      buffer
        ..write(line)
        ..write('\n');
      if (firstLine) {
        firstLine = false;
        final normalized = line.startsWith('\uFEFF')
            ? line.substring(1)
            : line;
        if (!_isFence(normalized)) return buffer.toString();
      } else if (_isFence(line)) {
        return buffer.toString();
      }
    }
    return buffer.toString();
  }

  /// Parse standard YAML frontmatter. Malformed YAML is retained as a parse
  /// error so callers can show a useful validation result without guessing.
  factory SkillFrontmatter.parse(String markdown) {
    var text = markdown;
    if (text.startsWith('\uFEFF')) text = text.substring(1);
    text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    final lines = text.split('\n');
    if (lines.isEmpty || !_isFence(lines.first)) {
      return SkillFrontmatter(
        name: '',
        description: '',
        body: text,
        hasFrontmatter: false,
      );
    }

    var closing = -1;
    for (var i = 1; i < lines.length; i++) {
      if (_isFence(lines[i])) {
        closing = i;
        break;
      }
    }
    if (closing < 0) {
      return SkillFrontmatter(
        name: '',
        description: '',
        body: text,
        hasFrontmatter: false,
        parseError: 'unterminated YAML frontmatter',
      );
    }

    final yamlText = lines.sublist(1, closing).join('\n');
    final body = lines.skip(closing + 1).join('\n');
    try {
      final decoded = loadYaml(yamlText);
      if (decoded is! Map) {
        throw const FormatException('YAML frontmatter must be a mapping');
      }
      final values = <String, dynamic>{};
      for (final entry in decoded.entries) {
        if (entry.key is! String) {
          throw const FormatException('YAML frontmatter keys must be strings');
        }
        values[entry.key as String] = _toDart(entry.value);
      }

      final name = _stringValue(values['name']);
      final description = _stringValue(values['description']);
      final license = _optionalString(values['license']);
      final compatibility = _optionalString(values['compatibility']);
      final allowedTools = _optionalString(values['allowed-tools']);
      final metadataValue = values['metadata'];
      final metadataIsValid = metadataValue == null ||
          (metadataValue is Map && metadataValue.entries.every(
            (entry) => entry.key is String && entry.value is String,
          ));
      final metadata = _stringMap(metadataValue);
      final known = <String>{
        'name',
        'description',
        'license',
        'compatibility',
        'metadata',
        'allowed-tools',
      };
      final unknown = values.keys.toSet().difference(known);
      final extras = Map<String, dynamic>.from(values);
      for (final key in known) {
        extras.remove(key);
      }
      return SkillFrontmatter(
        name: name,
        description: description,
        body: body,
        extras: extras,
        license: license,
        compatibility: compatibility,
        metadata: metadata,
        metadataIsValid: metadataIsValid,
        allowedTools: allowedTools,
        unknownFields: unknown,
      );
    } catch (error) {
      return SkillFrontmatter(
        name: '',
        description: '',
        body: body,
        hasFrontmatter: true,
        parseError: error.toString(),
      );
    }
  }

  /// Fatal conformance problems. Directory matching is checked when the
  /// original Skill folder name is known (not against temporary staging dirs).
  List<String> validate({String? directoryName}) {
    final errors = <String>[];
    if (!hasFrontmatter) errors.add('missing YAML frontmatter');
    if (parseError != null) errors.add('invalid YAML: $parseError');
    if (name.isEmpty) {
      errors.add('missing name');
    } else {
      if (name.runes.length > 64) errors.add('name exceeds 64 characters');
      if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(name)) {
        errors.add('name must use lowercase letters, digits, and single hyphens');
      }
      if (directoryName != null && directoryName.isNotEmpty &&
          name != directoryName) {
        errors.add('name must match Skill directory "$directoryName"');
      }
    }
    if (description.trim().isEmpty) {
      errors.add('missing description');
    } else if (description.runes.length > 1024) {
      errors.add('description exceeds 1024 characters');
    }
    if (license != null && license!.trim().isEmpty) {
      errors.add('license must not be empty');
    }
    if (compatibility != null &&
        (compatibility!.trim().isEmpty || compatibility!.runes.length > 500)) {
      errors.add('compatibility must contain 1 to 500 characters');
    }
    if (allowedTools != null && allowedTools!.trim().isEmpty) {
      errors.add('allowed-tools must be a space-delimited string');
    }
    if (!metadataIsValid) {
      errors.add('metadata must be a mapping of string keys to string values');
    }
    return errors;
  }

  /// Non-fatal notes about extensions that Kelivo does not currently interpret.
  List<String> compatibilityWarnings({String? directoryName}) {
    final warnings = <String>[];
    if (unknownFields.isNotEmpty) {
      warnings.add(
        'Unknown frontmatter extensions are preserved but not interpreted: '
        '${(unknownFields.toList()..sort()).join(', ')}.',
      );
    }
    if (allowedTools != null) {
      warnings.add(
        'The experimental allowed-tools field is preserved; Kelivo does not '
        'treat it as permission to execute tools.',
      );
    }
    if (directoryName != null && name.isNotEmpty && name != directoryName) {
      warnings.add('Skill name does not match its parent directory.');
    }
    return warnings;
  }
}

/// Lowercase `[a-z0-9-]` slug, at most 64 characters.
String slugify(String name) {
  var slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  slug = slug.replaceAll(RegExp(r'-{2,}'), '-');
  slug = slug.replaceAll(RegExp(r'^-+|-+$'), '');
  if (slug.length > 64) {
    slug = slug.substring(0, 64).replaceAll(RegExp(r'-+$'), '');
  }
  return slug.isEmpty ? 'skill' : slug;
}

bool _isFence(String line) => RegExp(r'^---\s*$').hasMatch(line);

String _stringValue(Object? value) => value is String ? value.trim() : '';

String? _optionalString(Object? value) => value == null
    ? null
    : value is String
    ? value.trim()
    : '';

Map<String, String> _stringMap(Object? value) {
  if (value is! Map) return const <String, String>{};
  final result = <String, String>{};
  for (final entry in value.entries) {
    if (entry.key is String && entry.value is String) {
      result[entry.key as String] = entry.value as String;
    }
  }
  return result;
}

Object? _toDart(Object? value) {
  if (value is Map) {
    return <String, dynamic>{
      for (final entry in value.entries)
        if (entry.key is String) entry.key as String: _toDart(entry.value),
    };
  }
  if (value is List) return value.map(_toDart).toList(growable: false);
  return value;
}
