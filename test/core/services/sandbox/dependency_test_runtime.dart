import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:Kelivo/core/services/sandbox/environment_dependencies.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';

class DependencyTestRuntime extends WorkspaceRuntime {
  final requests = <CommandRequest>[];
  final installed = <EnvironmentDependency>{};
  final installedMediaPackages = <String>{};
  Completer<void>? installGate;
  bool failInstall = false;
  bool incompleteProbe = false;
  bool cancelled = false;
  String? cancelledId;

  bool _mediaCommandInstalled(String command) {
    if ((installedMediaPackages.contains('ffmpeg') ||
            installed.contains(EnvironmentDependency.mediaTools)) &&
        {'ffmpeg', 'ffprobe'}.contains(command)) {
      return true;
    }
    if ({'magick', 'convert', 'identify'}.contains(command)) {
      return installedMediaPackages.contains('imagemagick');
    }
    return installedMediaPackages.contains(command);
  }

  @override
  Future<RuntimeStatus> status() async =>
      const RuntimeStatus(ready: true, engine: 'fake', sandboxed: true);
  @override
  Stream<CommandEvent> run(CommandRequest request) async* {
    requests.add(request);
    if (request.command.contains('__kelivo_dep_')) {
      final body = incompleteProbe
          ? '__kelivo_dep_python=1\n'
          : [
              for (final dependency in EnvironmentDependency.values)
                '__kelivo_dep_${dependency.name}=${installed.contains(dependency) ? 1 : 0}\n',
            ].join() + [
              if (installedMediaPackages.contains('ffmpeg') ||
                  installed.contains(EnvironmentDependency.mediaTools)) ...[
                '__kelivo_media_version_ffmpeg=ffmpeg version test 7.0\n',
                '__kelivo_media_version_ffprobe=ffprobe version test 7.0\n',
              ],
              for (final command in EnvironmentDependencies.optionalMediaTools)
                '__kelivo_media_optional_${command}=${_mediaCommandInstalled(command) ? 1 : 0}\n',
            ].join();
      yield CommandOutput(
        OutputStreamKind.stdout,
        Uint8List.fromList(utf8.encode(body)),
      );
    } else {
      yield CommandOutput(
        OutputStreamKind.stdout,
        Uint8List.fromList(utf8.encode('Installing packages…\n')),
      );
      await installGate?.future;
      if (!failInstall && !cancelled) {
        for (final dependency in EnvironmentDependency.values) {
          if (request.command.contains(
            dependency.packages(alpine: request.command.contains('apk ')),
          )) {
            installed.add(dependency);
          }
        }
        for (final package in [
          'ffmpeg', 'yt-dlp', 'mediainfo', 'ffmpegthumbnailer', 'imagemagick',
        ]) {
          if (request.command.contains(' $package ') ||
              request.command.contains(' $package\n')) {
            installedMediaPackages.add(package);
          }
        }
      }
    }
    yield CommandExited(
      exitCode: failInstall ? 1 : 0,
      timedOut: false,
      cancelled: cancelled,
      interrupted: false,
      duration: Duration.zero,
    );
  }

  @override
  Future<void> cancel(String runId) async {
    cancelledId = runId;
    cancelled = true;
    if (installGate?.isCompleted == false) installGate!.complete();
  }
}
