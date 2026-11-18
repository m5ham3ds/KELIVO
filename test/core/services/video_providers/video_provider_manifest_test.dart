import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/video_providers/video_provider_manifest.dart';

const validProviderManifest = '''
schemaVersion: 1
id: cinematic-cloud
name: Cinematic Cloud
version: 1.0.0
description: Example declarative video generation connector.
api:
  baseUrl: https://api.example.com/
  apiKey:
    required: true
    header: Authorization
    prefix: Bearer
capabilities:
  textToVideo: true
  imageToVideo: true
models:
  - cinematic-v1
defaultModel: cinematic-v1
limits:
  maxPromptCharacters: 4000
  maxDurationSeconds: 30
  maxDownloadBytes: 67108864
downloadHosts:
  - cdn.example.com
endpoints:
  submit:
    path: /v1/videos
    jobIdPath: data.id
    fields:
      model: model
      prompt: input.prompt
      imageUrl: input.image_url
      durationSeconds: duration
      aspectRatio: aspect_ratio
  poll:
    path: /v1/videos/{job_id}
    statusPath: data.status
    outputUrlPath: data.output_url
    progressPath: data.progress
    statuses:
      queued: [queued, pending]
      running: [processing, running]
      succeeded: [completed, succeeded]
      failed: [failed, error]
  quote:
    path: /v1/videos/quote
    costPath: data.cost
    currency: USD
''';

void main() {
  group('VideoProviderManifest', () {
    test('parses a declarative async connector and exposes safe summary data', () {
      final manifest = VideoProviderManifest.parse(validProviderManifest);

      expect(manifest.id, 'cinematic-cloud');
      expect(manifest.baseUri.host, 'api.example.com');
      expect(manifest.supportsTextToVideo, isTrue);
      expect(manifest.supportsImageToVideo, isTrue);
      expect(manifest.submit.fields.prompt, 'input.prompt');
      expect(manifest.poll.path, '/v1/videos/{job_id}');
      expect(manifest.quote?.currency, 'USD');
      expect(manifest.allowsDownloadHost('cdn.example.com'), isTrue);
      expect(manifest.allowsDownloadHost('untrusted.example.net'), isFalse);
      expect(manifest.toSummaryJson().containsKey('apiKey'), isFalse);
    });

    test('accepts root and nested absolute endpoint paths', () {
      final manifest = VideoProviderManifest.parse(
        validProviderManifest.replaceFirst('path: /v1/videos\n', 'path: /\n'),
      );
      expect(manifest.submit.path, '/');
      expect(manifest.poll.path, '/v1/videos/{job_id}');
    });

    test('rejects unknown manifest fields', () {
      expect(
        () => VideoProviderManifest.parse(
          validProviderManifest.replaceFirst(
            'description: Example declarative video generation connector.',
            'description: Example declarative video generation connector.\nscript: run.sh',
          ),
        ),
        throwsA(isA<VideoProviderManifestException>()),
      );
    });

    test('rejects HTTP, credentials, and non-standard API ports', () {
      for (final replacement in [
        'baseUrl: http://api.example.com/',
        'baseUrl: https://user:pass@api.example.com/',
        'baseUrl: https://api.example.com:8443/',
        'baseUrl: https://api.example.com:0/',
        'baseUrl: https://api.example.com/v1/',
      ]) {
        expect(
          () => VideoProviderManifest.parse(
            validProviderManifest.replaceFirst(
              'baseUrl: https://api.example.com/',
              replacement,
            ),
          ),
          throwsA(isA<VideoProviderManifestException>()),
        );
      }
    });

    test('rejects endpoint traversal and unsupported placeholders', () {
      for (final path in [
        '/v1/../admin',
        '/v1//videos',
        '/v1/videos/{other_id}',
      ]) {
        expect(
          () => VideoProviderManifest.parse(
            validProviderManifest.replaceFirst(
              'path: /v1/videos/{job_id}',
              'path: $path',
            ),
          ),
          throwsA(isA<VideoProviderManifestException>()),
        );
      }
    });

    test('rejects overlapping JSON request field mappings', () {
      expect(
        () => VideoProviderManifest.parse(
          validProviderManifest.replaceFirst(
            'prompt: input.prompt',
            'prompt: input',
          ),
        ),
        throwsA(isA<VideoProviderManifestException>()),
      );
      expect(
        () => VideoProviderManifest.parse(
          validProviderManifest.replaceFirst(
            'imageUrl: input.image_url',
            'imageUrl: input.prompt',
          ),
        ),
        throwsA(isA<VideoProviderManifestException>()),
      );
    });

    test('rejects unapproved credential header names', () {
      expect(
        () => VideoProviderManifest.parse(
          validProviderManifest.replaceFirst('header: Authorization', 'header: Cookie'),
        ),
        throwsA(isA<VideoProviderManifestException>()),
      );
    });

    test('requires the fields needed by each declared generation capability', () {
      expect(
        () => VideoProviderManifest.parse(
          validProviderManifest.replaceFirst('      imageUrl: input.image_url\n', ''),
        ),
        throwsA(isA<VideoProviderManifestException>()),
      );
      expect(
        () => VideoProviderManifest.parse(
          validProviderManifest.replaceFirst('      prompt: input.prompt\n', ''),
        ),
        throwsA(isA<VideoProviderManifestException>()),
      );
    });

    test('rejects duplicate statuses and download host entries', () {
      expect(
        () => VideoProviderManifest.parse(
          validProviderManifest.replaceFirst(
            'running: [processing, running]',
            'running: [queued, running]',
          ),
        ),
        throwsA(isA<VideoProviderManifestException>()),
      );
      expect(
        () => VideoProviderManifest.parse(
          validProviderManifest.replaceFirst(
            'running: [processing, running]',
            'running: [Queued, running]',
          ),
        ),
        throwsA(isA<VideoProviderManifestException>()),
      );
      expect(
        () => VideoProviderManifest.parse(
          validProviderManifest.replaceFirst(
            'path: /v1/videos/{job_id}',
            'path: /v1/%2e%2e/admin/{job_id}',
          ),
        ),
        throwsA(isA<VideoProviderManifestException>()),
      );
      expect(
        () => VideoProviderManifest.parse(
          validProviderManifest.replaceFirst(
            '  - cdn.example.com',
            '  - cdn.example.com\n  - cdn.example.com',
          ),
        ),
        throwsA(isA<VideoProviderManifestException>()),
      );
    });

    test('rejects non-string YAML keys and recursive aliases', () {
      expect(
        () => VideoProviderManifest.parse(
          validProviderManifest.replaceFirst(
            'description: Example declarative video generation connector.',
            'description: Example declarative video generation connector.\ntrue: invalid',
          ),
        ),
        throwsA(isA<VideoProviderManifestException>()),
      );
      expect(
        () => VideoProviderManifest.parse(
          validProviderManifest.replaceFirst(
            'limits:\n  maxPromptCharacters: 4000\n  maxDurationSeconds: 30\n  maxDownloadBytes: 67108864',
            'limits: &recursive\n  nested: *recursive',
          ),
        ),
        throwsA(isA<VideoProviderManifestException>()),
      );
    });

    test('rejects an oversized manifest', () {
      expect(
        () => VideoProviderManifest.parse(List.filled(64 * 1024 + 1, 'x').join()),
        throwsA(isA<VideoProviderManifestException>()),
      );
    });
  });
}
