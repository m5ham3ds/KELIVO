import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/video_engines/video_engine_manifest.dart';

const validManifest = '''
schemaVersion: 1
id: motion-kit
name: Motion Kit
version: 1.2.0
description: A sample optional CLI video engine.
compatibility:
  platforms: [android]
  architectures: [arm64-v8a, aarch64]
runtime:
  ecosystems: [node]
dependencies:
  commands: [node, ffmpeg]
commands:
  version:
    executable: node
    args: [--version]
  preflight:
    executable: node
    args: [scripts/preflight.js, "{{engine_root}}"]
  create:
    executable: node
    args: [scripts/create.js, "{{project_dir}}", "{{project_name}}"]
  render:
    executable: node
    args: [scripts/render.js, "{{project_dir}}", "{{output_path}}"]
  inspect:
    executable: node
    args: [scripts/inspect.js, "{{project_dir}}"]
  cancel:
    executable: node
    args: [scripts/cancel.js, "{{run_id}}"]
outputExtension: mp4
''';

void main() {
  group('VideoEngineManifest', () {
    test('parses a complete declarative CLI adapter contract', () {
      final manifest = VideoEngineManifest.parse(validManifest);

      expect(manifest.id, 'motion-kit');
      expect(manifest.name, 'Motion Kit');
      expect(manifest.version, '1.2.0');
      expect(manifest.requiredCommands, ['node', 'ffmpeg']);
      expect(manifest.requiredEcosystems, ['node']);
      expect(manifest.command('render').executable, 'node');
      expect(
        manifest.command('render').expandArguments({
          'project_dir': '/workspace/Project A',
          'output_path': '/workspace/output.mp4',
        }),
        ['scripts/render.js', '/workspace/Project A', '/workspace/output.mp4'],
      );
    });

    test('hybrid capabilities are explicit and default to unsupported', () {
      final legacy = VideoEngineManifest.parse(validManifest);
      expect(legacy.supportsSceneRendering, isFalse);
      expect(legacy.supportsHybridAssembly, isFalse);
      expect(legacy.acceptsMp4Assets, isFalse);

      final hybrid = VideoEngineManifest.parse(
        validManifest.replaceFirst(
          'outputExtension: mp4',
          'outputExtension: mp4\ncapabilities:\n  sceneRendering: true\n  hybridAssembly: true\n  acceptsMp4Assets: true',
        ),
      );
      expect(hybrid.supportsSceneRendering, isTrue);
      expect(hybrid.supportsHybridAssembly, isTrue);
      expect(hybrid.acceptsMp4Assets, isTrue);
      expect(
        hybrid.toJson()['capabilities'],
        {
          'sceneRendering': true,
          'hybridAssembly': true,
          'acceptsMp4Assets': true,
        },
      );
    });

    test('rejects false or malformed hybrid capability declarations', () {
      for (final capabilities in [
        'capabilities:\n  hybridAssembly: true',
        'capabilities:\n  sceneRendering: yes',
        'capabilities:\n  unknownFeature: true',
      ]) {
        expect(
          () => VideoEngineManifest.parse(
            validManifest.replaceFirst('outputExtension: mp4', 'outputExtension: mp4\n$capabilities'),
          ),
          throwsA(isA<VideoEngineManifestException>()),
        );
      }
    });

    test('round-trips the normalized manifest representation', () {
      final manifest = VideoEngineManifest.parse(validManifest);
      final restored = VideoEngineManifest.parse(
        _toYamlLike(manifest.toJson()),
      );

      expect(restored.id, manifest.id);
      expect(restored.commands.keys, manifest.commands.keys);
      expect(restored.command('create').args, manifest.command('create').args);
    });

    test('rejects unsupported schema versions', () {
      expect(
        () => VideoEngineManifest.parse(validManifest.replaceFirst('schemaVersion: 1', 'schemaVersion: 2')),
        throwsA(isA<VideoEngineManifestException>()),
      );
    });

    test('rejects non-integer schema versions', () {
      expect(
        () => VideoEngineManifest.parse(validManifest.replaceFirst('schemaVersion: 1', 'schemaVersion: 1.5')),
        throwsA(isA<VideoEngineManifestException>()),
      );
    });

    test('rejects malformed nested manifest objects', () {
      expect(
        () => VideoEngineManifest.parse(
          validManifest.replaceFirst('compatibility:\n', 'compatibility: [android]\n'),
        ),
        throwsA(isA<VideoEngineManifestException>()),
      );
    });

    test('rejects missing required command declarations', () {
      expect(
        () => VideoEngineManifest.parse(
          validManifest.replaceFirst(RegExp(r'  inspect:[\s\S]*?\n  cancel:'), '  cancel:'),
        ),
        throwsA(isA<VideoEngineManifestException>()),
      );
    });

    test('rejects shell expressions in executable names', () {
      expect(
        () => VideoEngineManifest.parse(
          validManifest.replaceFirst('executable: node', 'executable: "node; rm -rf /"'),
        ),
        throwsA(isA<VideoEngineManifestException>()),
      );
    });

    test('rejects absolute and traversing adapter executable paths', () {
      for (final executable in ['/usr/bin/node', '../node', 'scripts/../../node']) {
        expect(
          () => VideoEngineManifest.parse(
            validManifest.replaceFirst('executable: node', 'executable: "$executable"'),
          ),
          throwsA(isA<VideoEngineManifestException>()),
        );
      }
    });

    test('rejects unknown argument placeholders', () {
      expect(
        () => VideoEngineManifest.parse(
          validManifest.replaceFirst('{{project_dir}}', '{{arbitrary_command}}'),
        ),
        throwsA(isA<VideoEngineManifestException>()),
      );
    });

    test('requires a value when expanding a declared placeholder', () {
      final command = VideoEngineManifest.parse(validManifest).command('render');
      expect(
        () => command.expandArguments(const {'project_dir': '/workspace'}),
        throwsA(isA<VideoEngineManifestException>()),
      );
    });

    test('rejects malformed output extensions', () {
      for (final replacement in [
        'outputExtension: 123',
        'outputExtension: ../mp4',
        'outputExtension: mp4\n  injected: true',
      ]) {
        expect(
          () => VideoEngineManifest.parse(
            validManifest.replaceFirst('outputExtension: mp4', replacement),
          ),
          throwsA(isA<VideoEngineManifestException>()),
        );
      }
    });

    test('rejects unsupported platforms and architectures', () {
      expect(
        () => VideoEngineManifest.parse(
          validManifest.replaceFirst('[android]', '[windows]'),
        ),
        throwsA(isA<VideoEngineManifestException>()),
      );
      expect(
        () => VideoEngineManifest.parse(
          validManifest.replaceFirst('[arm64-v8a, aarch64]', '[x86_64]'),
        ),
        throwsA(isA<VideoEngineManifestException>()),
      );
    });

    test('rejects secret-like or malformed command argument control characters', () {
      expect(
        () => VideoEngineManifest.parse(
          validManifest.replaceFirst(
            'args: [scripts/create.js,',
            'args: ["scripts/create.js\\nmalicious",',
          ),
        ),
        throwsA(isA<VideoEngineManifestException>()),
      );
    });
  });
}

String _toYamlLike(Map<String, Object?> value) {
  // The parser also accepts JSON because JSON is a YAML 1.2 subset.
  return _JsonEncoder().convert(value);
}

class _JsonEncoder {
  String convert(Object? value) => _encode(value);

  String _encode(Object? value) {
    if (value is Map) {
      return '{${value.entries.map((entry) => '${_quote(entry.key.toString())}:${_encode(entry.value)}').join(',')}}';
    }
    if (value is List) return '[${value.map(_encode).join(',')}]';
    if (value is String) return _quote(value);
    return value.toString();
  }

  String _quote(String value) => '"${value.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';
}
