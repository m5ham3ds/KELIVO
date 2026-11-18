import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const int kMiB = 1024 * 1024;
const int kGiB = 1024 * kMiB;

/// Best-effort Android resource snapshot. Unknown values stay null; callers
/// must not interpret missing telemetry as a healthy measurement.
@immutable
final class DeviceResourceSnapshot {
  const DeviceResourceSnapshot({
    this.availableMemoryBytes,
    this.totalMemoryBytes,
    this.memoryThresholdBytes,
    this.lowMemory,
    this.processPssBytes,
    this.processCpuPercentOfOneCore,
    this.availableStorageBytes,
    this.totalStorageBytes,
    this.thermalStatus,
    this.thermalHeadroom,
    this.batteryTemperatureCelsius,
    this.measuredAtEpochMs,
  });

  final int? availableMemoryBytes;
  final int? totalMemoryBytes;
  final int? memoryThresholdBytes;
  final bool? lowMemory;
  final int? processPssBytes;
  /// Process CPU use normalized to one logical core (0–100% per core).
  final double? processCpuPercentOfOneCore;
  final int? availableStorageBytes;
  final int? totalStorageBytes;
  /// Android PowerManager thermal status (0–6); null on unsupported APIs.
  final int? thermalStatus;
  /// Android thermal headroom forecast for ~10 seconds; null if unavailable.
  final double? thermalHeadroom;
  final double? batteryTemperatureCelsius;
  final int? measuredAtEpochMs;

  bool get hasMeasurements =>
      availableMemoryBytes != null ||
      availableStorageBytes != null ||
      thermalStatus != null ||
      thermalHeadroom != null ||
      batteryTemperatureCelsius != null ||
      processPssBytes != null ||
      processCpuPercentOfOneCore != null ||
      lowMemory != null;

  factory DeviceResourceSnapshot.fromMap(Map<Object?, Object?> value) {
    int? integer(String key) {
      final item = value[key];
      if (item is int && item >= 0) return item;
      if (item is num && item.isFinite && item >= 0 && item <= 0x7fffffff) {
        return item.toInt();
      }
      return null;
    }

    double? decimal(String key) {
      final item = value[key];
      if (item is num && item.isFinite) return item.toDouble();
      return null;
    }

    final thermalStatus = integer('thermalStatus');
    final thermalHeadroom = decimal('thermalHeadroom');
    final cpu = decimal('processCpuPercentOfOneCore');
    final battery = decimal('batteryTemperatureCelsius');
    return DeviceResourceSnapshot(
      availableMemoryBytes: integer('availableMemoryBytes'),
      totalMemoryBytes: integer('totalMemoryBytes'),
      memoryThresholdBytes: integer('memoryThresholdBytes'),
      lowMemory: value['lowMemory'] is bool ? value['lowMemory'] as bool : null,
      processPssBytes: integer('processPssBytes'),
      processCpuPercentOfOneCore:
          cpu != null && cpu >= 0 && cpu <= 6400 ? cpu : null,
      availableStorageBytes: integer('availableStorageBytes'),
      totalStorageBytes: integer('totalStorageBytes'),
      thermalStatus: thermalStatus != null && thermalStatus <= 6 ? thermalStatus : null,
      thermalHeadroom: thermalHeadroom != null && thermalHeadroom >= 0 && thermalHeadroom <= 10
          ? thermalHeadroom
          : null,
      batteryTemperatureCelsius:
          battery != null && battery >= -30 && battery <= 100 ? battery : null,
      measuredAtEpochMs: integer('measuredAtEpochMs'),
    );
  }

  Map<String, Object?> toJson() => {
    'availableMemoryBytes': availableMemoryBytes,
    'totalMemoryBytes': totalMemoryBytes,
    'memoryThresholdBytes': memoryThresholdBytes,
    'lowMemory': lowMemory,
    'processPssBytes': processPssBytes,
    'processCpuPercentOfOneCore': processCpuPercentOfOneCore,
    'availableStorageBytes': availableStorageBytes,
    'totalStorageBytes': totalStorageBytes,
    'thermalStatus': thermalStatus,
    'thermalStatusLabel': thermalStatusLabel,
    'thermalHeadroom': thermalHeadroom,
    'batteryTemperatureCelsius': batteryTemperatureCelsius,
    'measuredAtEpochMs': measuredAtEpochMs,
  };

  String? get thermalStatusLabel => switch (thermalStatus) {
    0 => 'none',
    1 => 'light',
    2 => 'moderate',
    3 => 'severe',
    4 => 'critical',
    5 => 'emergency',
    6 => 'shutdown',
    _ => null,
  };
}

/// Android-only method-channel client; it returns null on unsupported hosts.
final class DeviceResourceMonitor {
  const DeviceResourceMonitor({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('app.device_resources');

  final MethodChannel _channel;

  Future<DeviceResourceSnapshot?> sample() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final raw = await _channel.invokeMethod<Object?>('snapshot');
      if (raw is! Map) return null;
      final snapshot = DeviceResourceSnapshot.fromMap(raw);
      return snapshot.hasMeasurements ? snapshot : null;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    } on Object {
      return null;
    }
  }
}

enum VideoRenderResourceLevel { unknown, ready, warning, blocked }

@immutable
final class VideoRenderResourceAssessment {
  const VideoRenderResourceAssessment({
    required this.level,
    required this.reasons,
    required this.recommendations,
    this.snapshot,
  });

  final VideoRenderResourceLevel level;
  final List<String> reasons;
  final List<String> recommendations;
  final DeviceResourceSnapshot? snapshot;

  bool get blocksRender => level == VideoRenderResourceLevel.blocked;

  Map<String, Object?> toJson() => {
    'level': level.name,
    'blocksRender': blocksRender,
    'reasons': reasons,
    'recommendations': recommendations,
    'snapshot': snapshot?.toJson(),
  };
}

/// Conservative preflight policy for long-running, local video renders.
/// Unknown telemetry never blocks by itself; measured critical pressure does.
final class VideoRenderResourceGuard {
  const VideoRenderResourceGuard({
    this.minimumAvailableMemoryBytes = 256 * kMiB,
    this.warningAvailableMemoryBytes = 768 * kMiB,
    this.minimumAvailableStorageBytes = 768 * kMiB,
    this.warningAvailableStorageBytes = 2 * kGiB,
    this.warningProcessCpuPercent = 90,
    this.warningBatteryTemperatureCelsius = 43,
    this.blockBatteryTemperatureCelsius = 48,
  });

  final int minimumAvailableMemoryBytes;
  final int warningAvailableMemoryBytes;
  final int minimumAvailableStorageBytes;
  final int warningAvailableStorageBytes;
  final double warningProcessCpuPercent;
  final double warningBatteryTemperatureCelsius;
  final double blockBatteryTemperatureCelsius;

  VideoRenderResourceAssessment evaluate(DeviceResourceSnapshot? snapshot) {
    if (snapshot == null || !snapshot.hasMeasurements) {
      return const VideoRenderResourceAssessment(
        level: VideoRenderResourceLevel.unknown,
        reasons: ['device_resource_telemetry_unavailable'],
        recommendations: ['check_device_temperature_and_free_storage_before_render'],
      );
    }

    final blocked = <String>[];
    final warnings = <String>[];
    final recommendations = <String>{};
    final memory = snapshot.availableMemoryBytes;
    final storage = snapshot.availableStorageBytes;
    final thermal = snapshot.thermalStatus;
    final headroom = snapshot.thermalHeadroom;
    final batteryTemperature = snapshot.batteryTemperatureCelsius;
    final cpu = snapshot.processCpuPercentOfOneCore;

    if (snapshot.lowMemory == true ||
        (memory != null && memory < minimumAvailableMemoryBytes)) {
      blocked.add('available_memory_critical');
      recommendations.addAll(['close_other_apps', 'lower_output_resolution', 'use_cloud_rendering']);
    } else if (memory != null && memory < warningAvailableMemoryBytes) {
      warnings.add('available_memory_low');
      recommendations.addAll(['close_other_apps', 'lower_output_resolution']);
    }

    if (storage != null && storage < minimumAvailableStorageBytes) {
      blocked.add('available_storage_critical');
      recommendations.addAll(['free_device_storage', 'export_to_external_storage']);
    } else if (storage != null && storage < warningAvailableStorageBytes) {
      warnings.add('available_storage_low');
      recommendations.addAll(['free_device_storage', 'check_expected_output_size']);
    }

    if (thermal != null && thermal >= 3) {
      blocked.add('device_thermal_status_severe');
      recommendations.addAll(['pause_until_device_cools', 'use_cloud_rendering']);
    } else if ((thermal != null && thermal >= 2) || (headroom != null && headroom >= 0.8)) {
      warnings.add('device_thermal_pressure');
      recommendations.addAll(['pause_until_device_cools', 'lower_output_resolution']);
    }
    if (headroom != null && headroom >= 1.0) {
      if (!blocked.contains('device_thermal_status_severe')) {
        blocked.add('thermal_headroom_exhausted');
      }
    }

    if (batteryTemperature != null && batteryTemperature >= blockBatteryTemperatureCelsius) {
      blocked.add('battery_temperature_critical');
      recommendations.addAll(['pause_until_device_cools', 'use_cloud_rendering']);
    } else if (batteryTemperature != null &&
        batteryTemperature >= warningBatteryTemperatureCelsius) {
      warnings.add('battery_temperature_high');
      recommendations.add('pause_until_device_cools');
    }

    if (cpu != null && cpu >= warningProcessCpuPercent) {
      warnings.add('app_cpu_load_high');
      recommendations.addAll(['wait_for_background_work', 'lower_output_resolution']);
    }

    final level = blocked.isNotEmpty
        ? VideoRenderResourceLevel.blocked
        : warnings.isNotEmpty
        ? VideoRenderResourceLevel.warning
        : VideoRenderResourceLevel.ready;
    return VideoRenderResourceAssessment(
      level: level,
      reasons: List.unmodifiable([...blocked, ...warnings]),
      recommendations: List.unmodifiable(recommendations),
      snapshot: snapshot,
    );
  }
}
