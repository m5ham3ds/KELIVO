import 'skill_frontmatter.dart';

/// Finds likely local Skill resources named in its Markdown instructions.
/// Only explicit inline-code and Markdown-link references are examined. Paths
/// created as project state/output (for example PROGRESS.md or assets/vo/*)
/// are not treated as missing Skill companions.
List<String> findMissingSkillLocalReferences(
  String body,
  Set<String> files,
) {
  const resourceDirectories = <String>{
    'data',
    'examples',
    'fonts',
    'lib',
    'models',
    'prompts',
    'references',
    'samples',
    'schemas',
    'scripts',
    'snippets',
    'templates',
    'tools',
    'tests',
  };
  const resourceExtensions = <String>{
    'cjs', 'css', 'csv', 'html', 'jpeg', 'jpg', 'js', 'json', 'jsonl', 'md', 'mjs',
    'pdf', 'png', 'py', 'sh', 'sql', 'svg', 'toml', 'ts', 'txt', 'woff2',
    'xml', 'yaml', 'yml',
  };
  const generatedProjectFiles = <String>{
    'project.md',
    'progress.md',
    'log.md',
    'manifest.json',
    'channel.json',
    'hooks.txt',
    'script.txt',
    'script.md',
    'storyboard.md',
    'shotlist.md',
    'styleboard.png',
    'build.py',
    'render.js',
    'data.js',
    'beats.json',
    'scene.blend',
    '.mcp.json',
    'claude_desktop_config.json',
    'cursor.json',
  };
  final codeSpanExpression = RegExp(r'`([^`]+)`');
  final markdownLinkExpression = RegExp(r'\]\(([^)\s]+)(?:\s+[^)]*)?\)');
  final pathExpression = RegExp(
    r'((?:\./)?[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)*\.[A-Za-z0-9]+)(?![A-Za-z0-9_])',
    caseSensitive: false,
  );
  final explicitReferences = <String>[];
  for (final span in codeSpanExpression.allMatches(body)) {
    explicitReferences.add(span.group(1) ?? '');
  }
  for (final link in markdownLinkExpression.allMatches(body)) {
    explicitReferences.add(link.group(1) ?? '');
  }

  final missing = <String>{};
  for (final reference in explicitReferences) {
    for (final match in pathExpression.allMatches(reference)) {
      if (match.start > 0) {
        final previous = reference.substring(match.start - 1, match.start);
        if (RegExp(r'[A-Za-z0-9_./~:-]').hasMatch(previous)) continue;
      }
      var candidate = match.group(1)?.replaceAll('\\', '/') ?? '';
      if (candidate.isEmpty ||
          candidate.startsWith('~') ||
          candidate.startsWith('/') ||
          candidate.contains(r'$')) {
        continue;
      }
      if (candidate.startsWith('./')) candidate = candidate.substring(2);
      final segments = candidate.split('/');
      if (segments.any((segment) =>
          segment.isEmpty || segment == '.' || segment == '..')) {
        continue;
      }
      final extension = segments.last.split('.').last.toLowerCase();
      if (!resourceExtensions.contains(extension)) continue;
      if (segments.length > 1) {
        if (!resourceDirectories.contains(segments.first.toLowerCase())) {
          continue;
        }
        // assets/ is commonly a project output directory (voiceover, renders,
        // downloaded stock); it is not assumed to be a bundled Skill resource.
        if (segments.first.toLowerCase() == 'assets') continue;
        // Fetch helpers in this Skill are examples to be authored later, not
        // companion files expected to be present in the distribution archive.
        if (segments.first.toLowerCase() == 'scripts' &&
            segments.last.toLowerCase().startsWith('fetch_')) {
          continue;
        }
      } else if (generatedProjectFiles.contains(candidate.toLowerCase()) ||
          candidate.toLowerCase() == 'three.js' ||
          candidate.toLowerCase() == 'node.js' ||
          candidate.startsWith('.')) {
        continue;
      }
      if (!files.contains(candidate)) missing.add(candidate);
    }
  }
  return missing.toList()..sort();
}

enum SkillCompatibilityLevel { compatible, warnings, unsupported }

class SkillCompatibilityReport {
  const SkillCompatibilityReport({
    required this.level,
    this.errors = const <String>[],
    this.warnings = const <String>[],
    this.standardFields = const <String>[],
    this.unsupportedExtensions = const <String>[],
  });

  final SkillCompatibilityLevel level;
  final List<String> errors;
  final List<String> warnings;
  final List<String> standardFields;
  final List<String> unsupportedExtensions;

  bool get isImportable => level != SkillCompatibilityLevel.unsupported;

  Map<String, Object?> toJson() => <String, Object?>{
    'level': level.name,
    'isImportable': isImportable,
    'errors': errors,
    'warnings': warnings,
    'standardFields': standardFields,
    'unsupportedExtensions': unsupportedExtensions,
  };
}

/// Reports Agent Skills conformance separately from platform-specific extras.
/// It never executes or interprets scripts, shell commands, or permission hints.
class SkillCompatibilityAnalyzer {
  static const _standardFields = <String>{
    'name',
    'description',
    'license',
    'compatibility',
    'metadata',
    'allowed-tools',
  };

  static SkillCompatibilityReport analyze(
    SkillFrontmatter frontmatter, {
    String? directoryName,
    Iterable<String> files = const <String>[],
  }) {
    final errors = frontmatter.validate(directoryName: directoryName);
    final warnings = frontmatter.compatibilityWarnings(
      directoryName: directoryName,
    );
    final normalizedFiles = files
        .map((file) => file.replaceAll('\\', '/'))
        .toSet();
    if (normalizedFiles.contains('SKILL.md')) {
      final missingReferences = findMissingSkillLocalReferences(
        frontmatter.body,
        normalizedFiles,
      );
      if (missingReferences.isNotEmpty) {
        warnings.add(
          'The Skill mentions local companion files that are not present in '
          'this source: ${missingReferences.join(', ')}. These files cannot '
          'be reconstructed during import; obtain the complete Skill folder '
          'or bundle before relying on those instructions.',
        );
      }
    }
    final unsupported = <String>[];
    const platformDirectories = <String>{
      '.claude-plugin',
      '.claude',
      '.codex',
      '.cursor',
      '.opencode',
      '.windsurf',
      '.roo',
      '.continue',
    };
    const platformConfigFiles = <String>{
      'plugin.json',
      'claude_desktop_config.json',
      'opencode.json',
      'cursor.json',
    };
    for (final file in files) {
      final path = file.replaceAll('\\', '/');
      final segments = path.split('/');
      if (segments.any(platformDirectories.contains) ||
          platformConfigFiles.contains(segments.last)) {
        unsupported.add(path);
      }
    }
    if (unsupported.isNotEmpty) {
      warnings.add(
        'Platform-specific configuration files are preserved but not '
        'interpreted by the Agent Skills adapter: '
        '${(unsupported.toSet().toList()..sort()).join(', ')}.',
      );
    }
    final level = errors.isNotEmpty
        ? SkillCompatibilityLevel.unsupported
        : (warnings.isNotEmpty
              ? SkillCompatibilityLevel.warnings
              : SkillCompatibilityLevel.compatible);
    return SkillCompatibilityReport(
      level: level,
      errors: List.unmodifiable(errors),
      warnings: List.unmodifiable(warnings),
      standardFields: List.unmodifiable(
        _standardFields.where((field) {
          switch (field) {
            case 'name':
              return frontmatter.name.isNotEmpty;
            case 'description':
              return frontmatter.description.isNotEmpty;
            case 'license':
              return frontmatter.license != null;
            case 'compatibility':
              return frontmatter.compatibility != null;
            case 'metadata':
              return frontmatter.metadata.isNotEmpty;
            case 'allowed-tools':
              return frontmatter.allowedTools != null;
          }
          return false;
        }),
      ),
      unsupportedExtensions: List.unmodifiable(
        <String>{...frontmatter.unknownFields, ...unsupported}.toList()..sort(),
      ),
    );
  }
}
