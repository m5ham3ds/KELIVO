import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/services/packages/package_manager_service.dart';
import 'package:Kelivo/core/services/packages/package_ledger_store.dart';
import 'package:Kelivo/core/services/packages/package_manager_models.dart';
import 'package:Kelivo/core/services/runtime_profiles/runtime_profile_models.dart';
import 'package:Kelivo/core/services/runtime_profiles/runtime_profile_service.dart';
import 'package:Kelivo/core/services/workspace/workspace_paths.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/core/services/workspace/workspace_tool_context.dart';
import '../../../support/business_test_harness.dart';

void main() {
  test('extension Python package plans require an owner Runtime Profile', () async {
    final harness = await createBusinessTestHarness();
    final environment = EnvironmentProvider(preferences: harness.preferences);
    addTearDown(environment.dispose);
    await environment.loaded;
    await environment.setState(const EnvironmentState(
      phase: EnvironmentPhase.ready,
      distro: 'ubuntu',
      version: '24.04',
      arch: 'aarch64',
    ));
    final service = PackageManagerService(
      runtime: _FakePackageRuntime(),
      environment: environment,
      preferences: harness.preferences,
    );
    final result = _decode(await service.handle({
      'action': 'plan',
      'manager': 'pip',
      'ecosystem': 'python',
      'scope': 'extension',
      'extension_id': 'ig-reel',
      'package': 'requests',
    }));
    expect(result['ok'], isFalse);
    expect(result['error'], 'extension_runtime_profile_required');
  });

  test('project Python operations inherit the workspace default Runtime Profile', () async {
    final harness = await createBusinessTestHarness();
    final environment = EnvironmentProvider(preferences: harness.preferences);
    addTearDown(environment.dispose);
    final temporary = await Directory.systemTemp.createTemp('kelivo_package_profile_');
    addTearDown(() async {
      if (await temporary.exists()) await temporary.delete(recursive: true);
    });
    final workspaceDirectory = Directory(p.join(temporary.path, 'workspace'))
      ..createSync(recursive: true);
    final sessionDirectory = Directory(p.join(temporary.path, 'session'))
      ..createSync(recursive: true);
    final skillsDirectory = Directory(p.join(temporary.path, 'skills'))
      ..createSync(recursive: true);
    final workspace = Workspace(
      id: 'workspace-profile',
      name: 'Profile project',
      kind: WorkspaceKind.managed,
      defaultRuntimeProfileId: 'profile-python-default',
      createdAt: DateTime.utc(2026, 11, 8),
      updatedAt: DateTime.utc(2026, 11, 8),
    );
    final context = WorkspaceToolContext(
      workspace: workspace,
      binding: const WorkspaceBinding(),
      paths: WorkspacePaths.native(
        workspaceHostRoot: workspaceDirectory.path,
        sessionHostDir: sessionDirectory.path,
        skillsHostDir: skillsDirectory.path,
      ),
      sessionDir: sessionDirectory,
      outputsDir: Directory(p.join(sessionDirectory.path, 'outputs')),
    );
    final store = ExtensionEntityStore(harness.database);
    final now = DateTime.utc(2026, 11, 8);
    await store.upsert(
      RuntimeProfileEntityKinds.profiles,
      'profile-python-default',
      RuntimeProfile(
        id: 'profile-python-default',
        name: 'Project Python',
        scope: RuntimeProfileScope.project,
        ownerId: workspace.id,
        ecosystems: {RuntimeProfileEcosystem.python},
        status: RuntimeProfileStatus.ready,
        createdAt: now,
        updatedAt: now,
      ).toJson(),
    );
    final runtimeProfiles = RuntimeProfileService(
      store: store,
      runtimeProvider: WorkspaceRuntimeProvider(),
    );
    final service = PackageManagerService(
      runtime: null,
      environment: environment,
      preferences: harness.preferences,
      workspace: context,
      runtimeProfiles: runtimeProfiles,
    );

    final result = _decode(await service.handle({
      'action': 'pin',
      'manager': 'pip',
      'scope': 'project',
      'package': 'requests',
      'version': '2.32.0',
    }));

    expect(result['ok'], isTrue, reason: result.toString());
    expect(
      result['scope'],
      'project:workspace-profile:profile:profile-python-default:python',
    );
  });

  test(
    'provides a bounded package-ledger snapshot without live verification',
    () async {
      final harness = await createBusinessTestHarness();
      final environment = EnvironmentProvider(preferences: harness.preferences);
      addTearDown(environment.dispose);
      final ledger = PackageLedgerStore(harness.preferences);
      for (var index = 1; index <= 2; index++) {
        await ledger.upsert(PackageLedgerEntry(
          scopeKey: 'runtime:ubuntu',
          manager: 'pip',
          name: 'package-$index',
          installedVersion: '1.0.$index',
          updatedAt: DateTime.utc(2026, 11, 11),
        ));
      }
      final service = PackageManagerService(
        runtime: null,
        environment: environment,
        preferences: harness.preferences,
      );

      final full = await service.inventorySnapshot(detail: 'full', maxItems: 1);
      expect(full['source'], 'kelivo_package_ledger');
      expect(full['liveVerification'], isFalse);
      expect(full['recordCount'], 2);
      expect(full['managerCounts'], containsPair('pip', 2));
      expect((full['entries'] as List), hasLength(1));
      expect(full['truncated'], isTrue);
      expect(full['maxItems'], 1);

      final summary = await service.inventorySnapshot(detail: 'summary');
      expect(summary.containsKey('entries'), isFalse);
      expect(summary['recordCount'], 2);
      expect(summary['truncated'], isFalse);
    },
  );

  test('plans, installs an exact apt version, checks and removes it in runtime scope', () async {
    final harness = await createBusinessTestHarness();
    final environment = EnvironmentProvider(preferences: harness.preferences);
    addTearDown(environment.dispose);
    await environment.loaded;
    await environment.setState(const EnvironmentState(
      phase: EnvironmentPhase.ready,
      distro: 'ubuntu',
      version: '24.04',
      arch: 'aarch64',
    ));

    final runtime = _FakePackageRuntime();
    final service = PackageManagerService(
      runtime: runtime,
      environment: environment,
      preferences: harness.preferences,
    );

    final plan = _decode(await service.handle({
      'action': 'plan',
      'manager': 'auto',
      'ecosystem': 'system',
      'scope': 'runtime',
      'package': 'ffmpeg',
      'version': '6.1.1',
    }));
    expect(plan['ok'], isTrue);
    expect(plan['manager'], 'apt');
    expect(plan['scope'], 'runtime:system');
    expect(plan['sideEffects'], isFalse);
    expect(runtime.installed, isEmpty);

    final installed = _decode(await service.handle({
      'action': 'install',
      'manager': 'auto',
      'ecosystem': 'system',
      'scope': 'runtime',
      'package': 'ffmpeg',
      'version': '6.1.1',
    }));
    expect(installed['ok'], isTrue, reason: installed.toString());
    expect(runtime.installed['ffmpeg'], '6.1.1');
    expect(installed['packages'], isA<List>());

    final checked = _decode(await service.handle({
      'action': 'check',
      'manager': 'auto',
      'ecosystem': 'system',
      'scope': 'runtime',
      'package': 'ffmpeg',
    }));
    expect(checked['ok'], isTrue);
    final packageCheck = (checked['packages'] as List).single as Map;
    expect(packageCheck['installed'], isTrue);
    expect(packageCheck['version'], '6.1.1');

    final removed = _decode(await service.handle({
      'action': 'remove',
      'manager': 'auto',
      'ecosystem': 'system',
      'scope': 'runtime',
      'package': 'ffmpeg',
    }));
    expect(removed['ok'], isTrue, reason: removed.toString());
    expect(runtime.installed, isEmpty);

    final ledger = _decode(await service.handle({
      'action': 'list',
      'scope_key': 'runtime:system',
    }));
    final entries = ledger['entries'] as List;
    expect(entries, hasLength(1));
    expect((entries.single as Map)['status'], 'removed');
    expect(ledger['history'], hasLength(2));
  });
}

Map<String, dynamic> _decode(String value) =>
    jsonDecode(value) as Map<String, dynamic>;

final class _FakePackageRuntime extends WorkspaceRuntime {
  final Map<String, String> installed = {};

  @override
  Future<RuntimeStatus> status() async => const RuntimeStatus(
    ready: true,
    engine: 'fake',
    sandboxed: false,
  );

  @override
  Future<void> cancel(String runId) async {}

  @override
  Stream<CommandEvent> run(CommandRequest request) async* {
    final command = request.command;
    var output = '';
    if (command.contains('for command_name in apt-get')) {
      output = [
        '__KELIVO_PM_COMMAND__|apt-get',
        '__KELIVO_PM_COMMAND__|dpkg-query',
        '__KELIVO_PM_COMMAND__|python3',
        '__KELIVO_PM_COMMAND__|pip',
        '__KELIVO_PM_COMMAND__|pip3',
        '__KELIVO_PM_ARCH__|aarch64',
      ].join('\n');
    } else if (command.startsWith('if dpkg-query')) {
      final name = _packageName(command);
      final version = installed[name];
      output = version == null
          ? '__KELIVO_MISSING__\n'
          : '__KELIVO_INSTALLED__|$version\n';
    } else if (command.contains('apt-get') && command.contains('install -y')) {
      final spec = _packageSpec(command);
      final split = spec.split('=');
      installed[split.first] = split.length > 1 ? split.last : '1.0.0';
    } else if (command.contains('apt-get') && command.contains('remove -y')) {
      installed.remove(_packageName(command));
    }

    if (output.isNotEmpty) {
      yield CommandOutput(
        OutputStreamKind.stdout,
        Uint8List.fromList(utf8.encode(output)),
      );
    }
    yield const CommandExited(
      exitCode: 0,
      timedOut: false,
      cancelled: false,
      interrupted: false,
      duration: Duration(milliseconds: 1),
    );
  }

  String _packageSpec(String command) {
    final match = RegExp(r"-- '([^']+)'(?:\s|$)").firstMatch(command);
    return match?.group(1) ?? 'ffmpeg';
  }

  String _packageName(String command) =>
      _packageSpec(command).split('=').first;
}
