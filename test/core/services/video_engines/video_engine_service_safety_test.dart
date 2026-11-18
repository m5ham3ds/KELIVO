import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/video_engines/video_engine_service.dart';

void main() {

  group('VideoEngineService output budget', () {
    test('accepts outputs at or below the configured post-run budget', () {
      expect(
        VideoEngineService.isOutputWithinBudgetForTesting(
          bytes: 10 * 1024 * 1024,
          maxOutputMegabytes: 10,
        ),
        isTrue,
      );
    });

    test('rejects output above the configured budget and invalid budgets', () {
      expect(
        VideoEngineService.isOutputWithinBudgetForTesting(
          bytes: 10 * 1024 * 1024 + 1,
          maxOutputMegabytes: 10,
        ),
        isFalse,
      );
      expect(
        VideoEngineService.isOutputWithinBudgetForTesting(
          bytes: 1,
          maxOutputMegabytes: 0,
        ),
        isFalse,
      );
    });
  });

  group('VideoEngineService archive path validation', () {
    test('normalizes safe nested paths', () {
      expect(
        VideoEngineService.normalizeArchivePathForTesting(r'scripts\\render.js'),
        'scripts/render.js',
      );
    });

    test('ignores directory-only entries', () {
      expect(
        VideoEngineService.normalizeArchivePathForTesting('scripts/'),
        isNull,
      );
    });

    test('rejects absolute, drive-prefixed and traversal paths', () {
      for (final path in [
        '/etc/passwd',
        r'C:\\Windows\\system.ini',
        '../outside.txt',
        r'..\\outside.txt',
        'scripts/../outside.txt',
        'scripts/./render.js',
      ]) {
        expect(
          () => VideoEngineService.normalizeArchivePathForTesting(path),
          throwsA(isA<VideoEngineServiceException>()),
          reason: path,
        );
      }
    });

    test('rejects null bytes', () {
      expect(
        () => VideoEngineService.normalizeArchivePathForTesting('safe/\u0000bad'),
        throwsA(isA<VideoEngineServiceException>()),
      );
    });
  });
}
