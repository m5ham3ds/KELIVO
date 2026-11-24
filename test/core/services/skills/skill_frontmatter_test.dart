import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/skills/skill_frontmatter.dart';
import 'package:Kelivo/core/services/skills/skill_compatibility.dart';

void main() {
  test('parses standard YAML frontmatter and preserves standard optional fields', () {
    const markdown = '''
---
name: pdf-tools
description: Extract text and tables from PDF files with pdfplumber.
license: Apache-2.0
compatibility: Requires Python and a local PDF utility.
metadata:
  author: example-org
  version: "1.0"
allowed-tools: Read Bash(git:*)
---
# PDF Tools

Use pdfplumber.
''';
    final parsed = SkillFrontmatter.parse(markdown);
    expect(parsed.name, 'pdf-tools');
    expect(
      parsed.description,
      'Extract text and tables from PDF files with pdfplumber.',
    );
    expect(parsed.license, 'Apache-2.0');
    expect(parsed.compatibility, contains('Python'));
    expect(parsed.metadata, {'author': 'example-org', 'version': '1.0'});
    expect(parsed.allowedTools, 'Read Bash(git:*)');
    expect(parsed.body, contains('# PDF Tools'));
    expect(parsed.body, contains('Use pdfplumber.'));
    expect(parsed.validate(directoryName: 'pdf-tools'), isEmpty);
    expect(
      SkillCompatibilityAnalyzer.analyze(
        parsed,
        directoryName: 'pdf-tools',
      ).level,
      SkillCompatibilityLevel.warnings,
    );
  });

  test('tolerates BOM and CRLF', () {
    final markdown =
        '\uFEFF---\r\nname: crlf-skill\r\ndescription: "Windows line endings"\r\n---\r\nBody\r\n';
    final parsed = SkillFrontmatter.parse(markdown);
    expect(parsed.name, 'crlf-skill');
    expect(parsed.description, 'Windows line endings');
    expect(parsed.body, contains('Body'));
    expect(parsed.validate(), isEmpty);
  });

  test('frontmatter is required; heading text is not used as metadata', () {
    const markdown = '''
# Spreadsheet Helper

Read CSV files.
''';
    final parsed = SkillFrontmatter.parse(markdown);
    expect(parsed.hasFrontmatter, isFalse);
    expect(parsed.name, isEmpty);
    expect(parsed.description, isEmpty);
    expect(
      parsed.validate(),
      containsAll(['missing YAML frontmatter', 'missing name', 'missing description']),
    );
  });

  test('malformed YAML is rejected instead of silently discarded', () {
    const markdown = '''
---
name: [unterminated
description: Broken YAML
---
body
''';
    final parsed = SkillFrontmatter.parse(markdown);
    expect(parsed.parseError, isNotNull);
    expect(parsed.validate(), contains(startsWith('invalid YAML:')));
  });

  test('quoted description keeps colons', () {
    const markdown = '''
---
name: quoted
description: "Extract: text, tables, and images"
---
body
''';
    final parsed = SkillFrontmatter.parse(markdown);
    expect(parsed.description, 'Extract: text, tables, and images');
  });

  test('multiline block description', () {
    const markdown = '''
---
name: multi
description: |
  Line one
  Line two
---
body
''';
    final parsed = SkillFrontmatter.parse(markdown);
    expect(parsed.description, contains('Line one'));
    expect(parsed.description, contains('Line two'));
  });

  test('validates name syntax, limits, metadata, and directory matching', () {
    final markdown = '''
---
name: PDF--Tools
description: "${'x' * 1025}"
compatibility: "${'c' * 501}"
metadata:
  author: 42
---
body
''';
    final parsed = SkillFrontmatter.parse(markdown);
    final errors = parsed.validate(directoryName: 'pdf-tools');
    expect(errors, contains('name must use lowercase letters, digits, and single hyphens'));
    expect(errors, contains('description exceeds 1024 characters'));
    expect(errors, contains('compatibility must contain 1 to 500 characters'));
    expect(errors, contains('metadata must be a mapping of string keys to string values'));
    expect(errors, contains('name must match Skill directory "pdf-tools"'));
  });

  test('description limits count Unicode code points rather than UTF-16 units', () {
    final valid = SkillFrontmatter.parse('''
---
name: unicode-limit
description: "${'😀' * 1024}"
---
body
''');
    expect(valid.validate(), isEmpty);

    final invalid = SkillFrontmatter.parse('''
---
name: unicode-over-limit
description: "${'😀' * 1025}"
---
body
''');
    expect(
      invalid.validate(),
      contains('description exceeds 1024 characters'),
    );
  });

  test('unknown platform extensions are preserved and flagged', () {
    const markdown = '''
---
name: sample-skill
description: A standard skill.
claude:
  model: opus
---
body
''';
    final parsed = SkillFrontmatter.parse(markdown);
    expect(parsed.extras['claude'], isA<Map>());
    expect(parsed.unknownFields, contains('claude'));
    expect(parsed.compatibilityWarnings().single, contains('claude'));
  });

  test('readHeader stops at the YAML closing fence and omits a large body', () async {
    final temporary = await Directory.systemTemp.createTemp('kelivo_skill_header_');
    try {
      final file = File(temporary.path + '/SKILL.md');
      const header = '''
---
name: large-body
description: Read only metadata before selecting this Skill.
metadata:
  kelivo.tags: metadata lazy loading
---
''';
      await file.writeAsString(header + List<String>.filled(20000, 'large body content').join(' '));
      final bounded = await SkillFrontmatter.readHeader(file, maxBytes: 8192);
      final parsed = SkillFrontmatter.parse(bounded);
      expect(bounded, contains('name: large-body'));
      expect(bounded, isNot(contains('large body content')));
      expect(bounded.length, lessThan(512));
      expect(parsed.name, 'large-body');
      expect(parsed.metadata['kelivo.tags'], 'metadata lazy loading');
      expect(parsed.body, isEmpty);
      expect(parsed.validate(), isEmpty);
    } finally {
      await temporary.delete(recursive: true);
    }
  });

  test('readHeader does not repair an oversized or unterminated frontmatter block', () async {
    final temporary = await Directory.systemTemp.createTemp('kelivo_skill_header_invalid_');
    try {
      final file = File(temporary.path + '/SKILL.md');
      final oversized = '---\nname: oversized-header\ndescription: ' +
          List<String>.filled(9000, 'x').join() +
          '\n---\nbody\n';
      await file.writeAsString(oversized);
      final bounded = await SkillFrontmatter.readHeader(file, maxBytes: 4096);
      final parsed = SkillFrontmatter.parse(bounded);
      expect(bounded.length, lessThanOrEqualTo(4097));
      expect(parsed.parseError, isNotNull);
      expect(parsed.validate(), contains(startsWith('invalid YAML:')));
    } finally {
      await temporary.delete(recursive: true);
    }
  });

  group('slugify', () {
    test('lowercases and hyphenates', () {
      expect(slugify('PDF Tools'), 'pdf-tools');
    });

    test('strips punctuation and collapses dashes', () {
      expect(slugify('Hello,  World!!!'), 'hello-world');
    });

    test('truncates to 64 characters', () {
      final slug = slugify('A' * 80);
      expect(slug.length, 64);
      expect(RegExp(r'^[a-z0-9-]+$').hasMatch(slug), isTrue);
    });

    test('falls back when nothing remains', () {
      expect(slugify('!!!'), 'skill');
      expect(slugify('表格'), 'skill');
    });
  });
}
