import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/device_resources/device_resource_monitor.dart';

void main() {
  group('DeviceResourceSnapshot', () {
    test('parses Android measurements and names thermal status', () {
      final snapshot = DeviceResourceSnapshot.fromMap({
        'availableMemoryBytes': 1024 * kMiB,
        'totalMemoryBytes': 8 * kGiB,
        'memoryThresholdBytes': 256 * kMiB,
        'lowMemory': false,
        'processPssBytes': 120 * kMiB,
        'processCpuPercentOfOneCore': 22.5,
        'availableStorageBytes': 12 * kGiB,
        'totalStorageBytes': 128 * kGiB,
        'thermalStatus': 2,
        'thermalHeadroom': 0.55,
        'batteryTemperatureCelsius': 38.4,
        'measuredAtEpochMs': 123456,
      });

      expect(snapshot.availableMemoryBytes, 1024 * kMiB);
      expect(snapshot.processCpuPercentOfOneCore, 22.5);
      expect(snapshot.thermalStatusLabel, 'moderate');
      expect(snapshot.batteryTemperatureCelsius, 38.4);
    });

    test('ignores malformed or out-of-range telemetry', () {
      final snapshot = DeviceResourceSnapshot.fromMap({
        'availableMemoryBytes': -1,
        'thermalStatus': 99,
        'thermalHeadroom': double.nan,
        'processCpuPercentOfOneCore': 6401,
        'batteryTemperatureCelsius': 200,
      });
      expect(snapshot.availableMemoryBytes, isNull);
      expect(snapshot.thermalStatus, isNull);
      expect(snapshot.thermalHeadroom, isNull);
      expect(snapshot.processCpuPercentOfOneCore, isNull);
      expect(snapshot.batteryTemperatureCelsius, isNull);
    });
  });

  group('VideoRenderResourceGuard', () {
    const guard = VideoRenderResourceGuard();

    test('does not assume healthy state when Android telemetry is missing', () {
      final result = guard.evaluate(null);
      expect(result.level, VideoRenderResourceLevel.unknown);
      expect(result.blocksRender, isFalse);
      expect(result.reasons, contains('device_resource_telemetry_unavailable'));
    });

    test('uses app CPU telemetry even when system metrics are unavailable', () {
      final result = guard.evaluate(const DeviceResourceSnapshot(
        processCpuPercentOfOneCore: 96,
      ));
      expect(result.level, VideoRenderResourceLevel.warning);
      expect(result.reasons, contains('app_cpu_load_high'));
    });

    test('blocks a render under critical memory pressure', () {
      final result = guard.evaluate(const DeviceResourceSnapshot(
        availableMemoryBytes: 128 * kMiB,
        totalMemoryBytes: 4 * kGiB,
        lowMemory: true,
      ));
      expect(result.level, VideoRenderResourceLevel.blocked);
      expect(result.reasons, contains('available_memory_critical'));
      expect(result.recommendations, contains('use_cloud_rendering'));
    });

    test('blocks a render when storage is critically low', () {
      final result = guard.evaluate(const DeviceResourceSnapshot(
        availableStorageBytes: 256 * kMiB,
        totalStorageBytes: 64 * kGiB,
      ));
      expect(result.blocksRender, isTrue);
      expect(result.reasons, contains('available_storage_critical'));
    });

    test('blocks when device thermal state is severe or worse', () {
      final result = guard.evaluate(const DeviceResourceSnapshot(
        availableMemoryBytes: 2 * kGiB,
        availableStorageBytes: 20 * kGiB,
        thermalStatus: 3,
      ));
      expect(result.blocksRender, isTrue);
      expect(result.recommendations, contains('pause_until_device_cools'));
    });

    test('warns on moderate resource pressure without blocking', () {
      final result = guard.evaluate(const DeviceResourceSnapshot(
        availableMemoryBytes: 512 * kMiB,
        totalMemoryBytes: 8 * kGiB,
        availableStorageBytes: 1 * kGiB,
        totalStorageBytes: 128 * kGiB,
        thermalStatus: 2,
        processCpuPercentOfOneCore: 94,
      ));
      expect(result.level, VideoRenderResourceLevel.warning);
      expect(result.blocksRender, isFalse);
      expect(result.reasons, containsAll([
        'available_memory_low',
        'available_storage_low',
        'device_thermal_pressure',
        'app_cpu_load_high',
      ]));
    });

    test('blocks high battery temperature and exhausted thermal headroom', () {
      final result = guard.evaluate(const DeviceResourceSnapshot(
        availableMemoryBytes: 2 * kGiB,
        availableStorageBytes: 20 * kGiB,
        thermalHeadroom: 1.1,
        batteryTemperatureCelsius: 49,
      ));
      expect(result.blocksRender, isTrue);
      expect(result.reasons, contains('thermal_headroom_exhausted'));
      expect(result.reasons, contains('battery_temperature_critical'));
    });

    test('reports ready for measured healthy resources', () {
      final result = guard.evaluate(const DeviceResourceSnapshot(
        availableMemoryBytes: 3 * kGiB,
        totalMemoryBytes: 8 * kGiB,
        availableStorageBytes: 30 * kGiB,
        totalStorageBytes: 128 * kGiB,
        thermalStatus: 0,
        thermalHeadroom: 0.25,
        batteryTemperatureCelsius: 35,
        processCpuPercentOfOneCore: 12,
      ));
      expect(result.level, VideoRenderResourceLevel.ready);
      expect(result.reasons, isEmpty);
    });
  });
}
