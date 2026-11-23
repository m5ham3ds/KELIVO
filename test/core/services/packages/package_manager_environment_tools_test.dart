import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/packages/package_manager_tools.dart';

void main() {
  group('PackageManagerEnvironmentTools', () {
    test('maps FFmpeg and FFprobe to one package', () {
      final result = PackageManagerEnvironmentTools.resolve(
        {
          'action': 'install',
          'tools': ['ffmpeg', 'ffprobe', 'yt-dlp'],
        },
        distro: 'ubuntu',
      );
      expect(result['ecosystem'], 'system');
      expect(result['manager'], 'apt');
      expect(result['packages'], ['ffmpeg', 'yt-dlp']);
      expect(result['requested_tools'], ['ffmpeg', 'ffprobe', 'yt-dlp']);
    });

    test('resolves a single canonical media package argument', () {
      final result = PackageManagerEnvironmentTools.resolve(
        {'action': 'plan', 'package': 'ffprobe'},
        distro: 'ubuntu',
      );
      expect(result['packages'], ['ffmpeg']);
      expect(result['requested_tools'], ['ffprobe']);
      expect(result['ecosystem'], 'system');
    });

    test('uses apk for Alpine', () {
      final result = PackageManagerEnvironmentTools.resolve(
        {'action': 'plan', 'tools': ['ffprobe']},
        distro: 'alpine',
      );
      expect(result['manager'], 'apk');
      expect(result['packages'], ['ffmpeg']);
    });

    test('rejects unknown or malformed tool names', () {
      expect(
        () => PackageManagerEnvironmentTools.resolve(
          {'action': 'install', 'tools': ['curl']},
          distro: 'ubuntu',
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => PackageManagerEnvironmentTools.resolve(
          {'action': 'install', 'tools': 'ffmpeg'},
          distro: 'ubuntu',
        ),
        throwsFormatException,
      );
    });

    test('leaves ordinary package manager arguments unchanged', () {
      final args = {'action': 'plan', 'package': 'requests', 'ecosystem': 'python'};
      final result = PackageManagerEnvironmentTools.resolve(args, distro: 'ubuntu');
      expect(result, args);
    });
  });
}
