import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/video_production/video_production_spec.dart';

Map<String, Object?> _spec({
  String aspectRatio = '9:16',
  int? width,
  int? height,
  int fps = 30,
  double durationSeconds = 20,
}) => {
  'title': 'Sample short video',
  'prompt': 'A calm cinematic story about a lantern.',
  'aspectRatio': aspectRatio,
  if (width != null) 'width': width,
  if (height != null) 'height': height,
  'fps': fps,
  'durationSeconds': durationSeconds,
};

void main() {
  group('VideoProductionSpec', () {
    test('applies portrait defaults and estimates frame count', () {
      final spec = VideoProductionSpec.parse(_spec());
      expect(spec.width, 1080);
      expect(spec.height, 1920);
      expect(spec.estimatedFrames, 600);
      expect(spec.outputFormat, 'mp4');
    });

    test('accepts bounded custom dimensions and frame rates', () {
      final spec = VideoProductionSpec.parse(
        _spec(aspectRatio: 'custom', width: 1280, height: 720, fps: 60),
      );
      expect(spec.width, 1280);
      expect(spec.height, 720);
      expect(spec.fps, 60);
    });

    test('rejects dimensions that contradict a named aspect ratio', () {
      expect(
        () => VideoProductionSpec.parse(
          _spec(aspectRatio: '9:16', width: 1920, height: 1080),
        ),
        throwsA(isA<VideoProductionSpecException>()),
      );
      final scaledPortrait = VideoProductionSpec.parse(
        _spec(aspectRatio: '9:16', width: 720, height: 1280),
      );
      expect(scaledPortrait.width, 720);
      expect(scaledPortrait.height, 1280);
    });

    test('rejects unknown ratios, unsafe dimensions, and invalid fps', () {
      expect(
        () => VideoProductionSpec.parse(_spec(aspectRatio: '5:7')),
        throwsA(isA<VideoProductionSpecException>()),
      );
      expect(
        () => VideoProductionSpec.parse(_spec(width: 8192)),
        throwsA(isA<VideoProductionSpecException>()),
      );
      expect(
        () => VideoProductionSpec.parse(_spec(fps: 240)),
        throwsA(isA<VideoProductionSpecException>()),
      );
    });

    test('rejects invalid durations and unsupported output formats', () {
      expect(
        () => VideoProductionSpec.parse(_spec(durationSeconds: 0.1)),
        throwsA(isA<VideoProductionSpecException>()),
      );
      expect(
        () => VideoProductionSpec.parse({..._spec(), 'outputFormat': 'mov'}),
        throwsA(isA<VideoProductionSpecException>()),
      );
    });

    test('parses storyboard scenes and sums their durations', () {
      final spec = VideoProductionSpec.parse(_spec(durationSeconds: 12));
      final scenes = parseVideoProductionScenes([
        {
          'id': 'opening',
          'title': 'Lantern appears',
          'durationSeconds': 5,
          'visualPrompt': 'Warm light in a dark room.',
        },
        {
          'id': 'reveal',
          'title': 'The story begins',
          'durationSeconds': 7,
        },
      ], spec: spec);
      expect(scenes, hasLength(2));
      expect(scenes.first.id, 'opening');
      expect(scenes.last.durationSeconds, 7);
    });

    test('rejects duplicate scene ids and scenes exceeding the brief duration', () {
      final spec = VideoProductionSpec.parse(_spec(durationSeconds: 5));
      final duplicate = [
        {'id': 'same', 'title': 'A', 'durationSeconds': 2},
        {'id': 'same', 'title': 'B', 'durationSeconds': 2},
      ];
      expect(
        () => parseVideoProductionScenes(duplicate, spec: spec),
        throwsA(isA<VideoProductionSpecException>()),
      );
      expect(
        () => parseVideoProductionScenes([
          {'id': 'a', 'title': 'A', 'durationSeconds': 3},
          {'id': 'b', 'title': 'B', 'durationSeconds': 3},
        ], spec: spec),
        throwsA(isA<VideoProductionSpecException>()),
      );
    });
  });

  group('VideoProductionScene asset references', () {
    test('accepts normalized project-relative asset paths', () {
      final scene = VideoProductionScene.parse({
        'id': 'opening',
        'title': 'Opening',
        'durationSeconds': 2,
        'assetPaths': ['assets/lantern.png', 'audio/narration.wav'],
      });
      expect(scene.assetPaths, ['assets/lantern.png', 'audio/narration.wav']);
    });

    test('rejects traversal and absolute asset references', () {
      for (final path in ['/sdcard/video.png', '../outside.png', 'assets/../../secret']) {
        expect(
          () => VideoProductionScene.parse({
            'id': 'opening',
            'title': 'Opening',
            'durationSeconds': 2,
            'assetPaths': [path],
          }),
          throwsA(isA<VideoProductionSpecException>()),
          reason: path,
        );
      }
    });
  });

  group('validateRelativeSourcePath', () {
    test('accepts safe nested source paths', () {
      expect(validateRelativeSourcePath('src/scenes/opening.js'), 'src/scenes/opening.js');
    });

    test('rejects absolute paths, traversal and Kelivo metadata paths', () {
      for (final path in [
        '/etc/passwd',
        '../escape.js',
        'src/../../escape.js',
        r'src\\escape.js',
        '.kelivo/engine.yaml',
        'src/.env',
        'src/.git/config',
        'kelivo.production.json',
        'storyboard.json',
      ]) {
        expect(
          () => validateRelativeSourcePath(path),
          throwsA(isA<VideoProductionSpecException>()),
          reason: path,
        );
      }
    });
  });
}
