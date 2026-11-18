import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/video_quality/video_quality_service.dart';

void main() {
  group('VideoQualityService probe validation', () {
    const probeJson = '''{
      "format": {"format_name": "mov,mp4,m4a,3gp,3g2,mj2", "duration": "12.5", "size": "500000"},
      "streams": [
        {"index": 0, "codec_type": "video", "codec_name": "h264", "width": 1920, "height": 1080, "avg_frame_rate": "30000/1001", "start_time": "0.000"},
        {"index": 1, "codec_type": "audio", "codec_name": "aac", "sample_rate": "48000", "channels": 2, "start_time": "0.100"}
      ]
    }''';

    test('parses ffprobe stream and format metadata', () {
      final parsed = VideoQualityService.parseProbeJson(probeJson);
      expect((parsed['streams'] as List).length, 2);
      final findings = VideoQualityService.evaluateProbe(
        parsed,
        expectedWidth: 1920,
        expectedHeight: 1080,
        expectedFps: 29.97,
        expectedDuration: 12.5,
        audioPolicy: 'preserve',
        requireAudio: true,
      );
      expect(findings.map((item) => item['code']), contains('audio_video_start_offset'));
      expect(findings.where((item) => item['severity'] == 'error'), isEmpty);
    });


    test('checks audio/video duration mismatch even when stream start is absent', () {
      final parsed = VideoQualityService.parseProbeJson('''{
        "format": {"format_name": "mp4", "duration": "10"},
        "streams": [
          {"codec_type": "video", "codec_name": "h264", "width": 1280, "height": 720, "avg_frame_rate": "30/1", "duration": "10"},
          {"codec_type": "audio", "codec_name": "aac", "duration": "8.5"}
        ]
      }''');
      final findings = VideoQualityService.evaluateProbe(parsed);
      expect(
        findings.map((item) => item['code']),
        contains('audio_video_duration_mismatch'),
      );
    });

    test('rejects missing video stream, wrong profile and audio under mute policy', () {
      final parsed = VideoQualityService.parseProbeJson(probeJson);
      final findings = VideoQualityService.evaluateProbe(
        parsed,
        expectedWidth: 1280,
        expectedHeight: 720,
        expectedFps: 60,
        audioPolicy: 'mute',
      );
      expect(findings.map((item) => item['code']), containsAll([
        'video_width_mismatch',
        'video_height_mismatch',
        'video_frame_rate_mismatch',
        'unexpected_audio_stream',
      ]));
      expect(
        () => VideoQualityService.parseProbeJson('{"format":{},"streams":[]}'),
        throwsA(isA<VideoQualityServiceException>()),
      );
      final audioOnly = VideoQualityService.parseProbeJson('''{
        "format": {"format_name": "mp4", "duration": "5"},
        "streams": [{"codec_type": "audio", "codec_name": "aac"}]
      }''');
      expect(
        VideoQualityService.evaluateProbe(audioOnly).map((item) => item['code']),
        contains('video_stream_missing'),
      );
    });
  });

  group('Subtitle validation', () {
    test('accepts valid SRT cues within the video duration', () {
      final report = VideoQualityService.validateSubtitle(
        '1\n00:00:01,000 --> 00:00:02,000\nHello\n\n2\n00:00:02,500 --> 00:00:03,000\nWorld\n',
        durationSeconds: 4,
      );
      expect(report.cueCount, 2);
      expect(report.valid, isTrue);
    });


    test('accepts WebVTT-style timestamps without an hours field', () {
      final report = VideoQualityService.validateSubtitle(
        'WEBVTT\n\n00:01.200 --> 00:03.000 align:start\nHello\n',
        durationSeconds: 4,
      );
      expect(report.cueCount, 1);
      expect(report.valid, isTrue);
    });

    test('detects overlaps, reversed timestamps and out-of-duration cues', () {
      final report = VideoQualityService.validateSubtitle(
        '1\n00:00:02,000 --> 00:00:04,000\nFirst\n\n2\n00:00:03,000 --> 00:00:02,500\nBroken\n\n3\n00:00:03,500 --> 00:00:04,500\nOverlap\n\n4\n00:00:05,500 --> 00:00:06,000\nLate\n',
        durationSeconds: 5,
      );
      expect(report.findings.map((item) => item.code), contains('timestamp_invalid_or_reversed'));
      expect(report.findings.map((item) => item.code), contains('cue_exceeds_video_duration'));
      expect(report.findings.map((item) => item.code), contains('cue_overlap'));
    });

    test('reports unrecognized non-empty subtitle files', () {
      final report = VideoQualityService.validateSubtitle('not a subtitle');
      expect(report.valid, isFalse);
      expect(report.findings.single.code, 'subtitle_cues_not_recognized');
    });
  });

  group('Failure classification', () {
    test('classifies missing binaries, OOM, network and syntax errors', () {
      expect(
        VideoQualityService.classifyFailure(exitCode: 127, stdout: '', stderr: 'ffmpeg: command not found', timedOut: false)['category'],
        'missing_binary_or_file',
      );
      expect(
        VideoQualityService.classifyFailure(exitCode: 1, stdout: '', stderr: 'Cannot allocate memory', timedOut: false)['recommendedAction'],
        'lower_resolution_or_split_render',
      );
      expect(
        VideoQualityService.classifyFailure(exitCode: 1, stdout: '', stderr: 'connection reset by peer', timedOut: false)['category'],
        'network_interruption',
      );
      expect(
        VideoQualityService.classifyFailure(exitCode: 1, stdout: '', stderr: 'SyntaxError: unexpected token', timedOut: false)['recommendedAction'],
        'inspect_stack_trace_before_changing_dependencies',
      );
    });
  });
}
