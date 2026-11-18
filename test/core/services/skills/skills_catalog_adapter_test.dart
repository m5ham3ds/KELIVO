import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:Kelivo/core/services/skills/skills_catalog_adapter.dart';

void main() {
  test('search uses skills.sh API and returns GitHub-backed entries only', () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'skills.sh');
      expect(request.url.path, '/api/v1/skills/search');
      expect(request.url.queryParameters['q'], 'pdf');
      expect(request.url.queryParameters['limit'], '7');
      return http.Response(jsonEncode({
        'data': [
          {
            'id': 'owner/repo/pdf-tools',
            'name': 'PDF Tools',
            'description': 'Work with PDFs',
            'sourceType': 'github',
            'installs': 120,
            'url': 'https://skills.sh/owner/repo/pdf-tools',
          },
          {
            'id': 'example.com/pdf-tools',
            'name': 'Well Known Skill',
            'sourceType': 'well-known',
          },
        ],
      }), 200);
    });
    final adapter = SkillsShAdapter(client);
    final entries = await adapter.search('pdf', limit: 7);
    expect(entries, hasLength(1));
    expect(entries.single.id, 'owner/repo/pdf-tools');
    expect(entries.single.installs, 120);
    client.close();
  });

  test('resolves all supporting files without rewriting their paths', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/v1/skills/owner/repo/pdf-tools');
      return http.Response(jsonEncode({
        'id': 'owner/repo/pdf-tools',
        'sourceType': 'github',
        'hash': 'abc123',
        'files': [
          {
            'path': 'SKILL.md',
            'contents': '---\nname: pdf-tools\ndescription: PDF helper\n---\nbody',
          },
          {'path': 'references/formats.md', 'contents': '# Formats'},
          {'path': 'scripts/read.py', 'contents': 'print(1)'},
          {'path': 'assets/example.txt', 'contents': 'data'},
        ],
      }), 200);
    });
    final adapter = SkillsShAdapter(client);
    final bundle = await adapter.resolve('owner/repo/pdf-tools');
    expect(bundle.hash, 'abc123');
    expect(bundle.files.keys, containsAll([
      'SKILL.md', 'references/formats.md', 'scripts/read.py', 'assets/example.txt',
    ]));
    expect(bundle.sourceUrl, 'https://skills.sh/owner/repo/pdf-tools');
    client.close();
  });

  test('rejects path traversal and non-GitHub catalog IDs', () async {
    final client = MockClient((request) async {
      return http.Response(jsonEncode({
        'id': 'owner/repo/pdf-tools',
        'files': [
          {'path': 'SKILL.md', 'contents': 'valid'},
          {'path': '../escape.txt', 'contents': 'unsafe'},
        ],
      }), 200);
    });
    final adapter = SkillsShAdapter(client);
    await expectLater(
      adapter.resolve('owner/repo/pdf-tools'),
      throwsFormatException,
    );
    await expectLater(
      adapter.resolve('example.com/pdf-tools'),
      throwsFormatException,
    );
    client.close();
  });

  test('rejects catalog ID mismatch', () async {
    final client = MockClient((request) async => http.Response(
      jsonEncode({
        'id': 'someone-else/repo/pdf-tools',
        'files': [
          {'path': 'SKILL.md', 'contents': '---\nname: pdf-tools\ndescription: PDF helper\n---\n'},
        ],
      }), 200,
    ));
    final adapter = SkillsShAdapter(client);
    await expectLater(
      adapter.resolve('owner/repo/pdf-tools'),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', 'skills_catalog_id_mismatch')),
    );
    client.close();
  });

  test('reports catalog entries without textual contents for archive fallback', () async {
    final client = MockClient((request) async => http.Response(jsonEncode({
      'id': 'owner/repo/pdf-tools',
      'sourceType': 'github',
      'files': [
        {'path': 'SKILL.md', 'contents': '---\nname: pdf-tools\ndescription: PDF helper\n---\n'},
        {'path': 'assets/logo.png', 'encoding': 'base64', 'contents': null},
      ],
    }), 200));
    final adapter = SkillsShAdapter(client);
    final bundle = await adapter.resolve('owner/repo/pdf-tools');
    expect(bundle.files.keys, contains('SKILL.md'));
    expect(bundle.unsupportedPaths, contains('assets/logo.png'));
    expect(bundle.transportComplete, isFalse);
    expect(bundle.notes, isNotEmpty);
    client.close();
  });

  test('marks a missing API snapshot without pretending it is complete', () async {
    final client = MockClient((request) async => http.Response(jsonEncode({
      'id': 'owner/repo/pdf-tools',
      'sourceType': 'github',
      'files': null,
    }), 200));
    final adapter = SkillsShAdapter(client);
    final bundle = await adapter.resolve('owner/repo/pdf-tools');
    expect(bundle.files, isEmpty);
    expect(bundle.transportComplete, isFalse);
    expect(bundle.notes, contains(contains('snapshot_unavailable')));
    client.close();
  });

}
