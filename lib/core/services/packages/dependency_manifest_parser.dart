import 'dart:convert';

import 'package:Kelivo/core/services/packages/package_manager_models.dart';

/// Read-only parser for the common project dependency manifests. It never
/// evaluates scripts, follows package URLs, or expands shell/environment data.
abstract final class DependencyManifestParser {
  static PackageManifest parse(String fileName, String contents) {
    final normalized = fileName.replaceAll('\\', '/').split('/').last;
    if (contents.length > 1024 * 1024) {
      throw const FormatException('manifest_too_large');
    }
    return switch (normalized) {
      'requirements.txt' => _parseRequirements(contents),
      'package.json' => _parsePackageJson(contents),
      'pyproject.toml' => _parsePyproject(contents),
      _ => throw FormatException('unsupported_manifest:$normalized'),
    };
  }

  /// Parse the optional Kelivo package contract carried in standard Agent
  /// Skills metadata. Example:
  /// metadata:
  ///   kelivo.package-manager: pip
  ///   kelivo.packages: "requests==2.32.3, beautifulsoup4==4.12.3"
  /// This remains inert metadata until the package manager is explicitly
  /// invoked and any requested mutation is approved by the user.
  static PackageManifest parseSkillMetadata(Map<String, String> metadata) {
    final managerValue = metadata['kelivo.package-manager']?.trim();
    final packagesValue = metadata['kelivo.packages']?.trim();
    if ((managerValue == null || managerValue.isEmpty) &&
        (packagesValue == null || packagesValue.isEmpty)) {
      throw const FormatException('skill_has_no_declared_packages');
    }
    if (managerValue == null || packagesValue == null) {
      throw const FormatException(
        'skill_package_metadata_requires_manager_and_packages',
      );
    }
    final manager = PackageManagerIdName.parse(managerValue);
    if (manager == PackageManagerId.auto) {
      throw const FormatException('skill_package_manager_must_be_explicit');
    }
    final ecosystem = switch (manager) {
      PackageManagerId.apt || PackageManagerId.apk => PackageEcosystem.system,
      PackageManagerId.pip || PackageManagerId.uv => PackageEcosystem.python,
      PackageManagerId.npm ||
      PackageManagerId.pnpm ||
      PackageManagerId.yarn ||
      PackageManagerId.bun => PackageEcosystem.node,
      PackageManagerId.auto => throw const FormatException(
        'skill_package_manager_must_be_explicit',
      ),
    };
    final specs = <PackageSpec>[];
    final seen = <String>{};
    for (final item in packagesValue.split(RegExp(r'[,\n]'))) {
      final token = item.trim();
      if (token.isEmpty) continue;
      final spec = _parseSkillPackageToken(token, manager);
      final error = spec.validate(manager);
      if (error != null) throw FormatException('invalid_skill_package:$error');
      if (seen.add(spec.normalizedName)) specs.add(spec);
    }
    if (specs.isEmpty || specs.length > 24) {
      throw const FormatException('skill_package_count_must_be_1_to_24');
    }
    final warnings = <String>[
      for (final package in specs)
        if (package.version == null)
          'version_range_not_locked:${package.name}',
    ];
    return PackageManifest(
      kind: ecosystem,
      manager: manager,
      packages: List.unmodifiable(specs),
      warnings: List.unmodifiable(warnings),
    );
  }

  static PackageSpec _parseSkillPackageToken(
    String token,
    PackageManagerId manager,
  ) {
    final separator = switch (manager) {
      PackageManagerId.apt || PackageManagerId.apk => '=',
      PackageManagerId.pip || PackageManagerId.uv => '==',
      PackageManagerId.npm ||
      PackageManagerId.pnpm ||
      PackageManagerId.yarn ||
      PackageManagerId.bun => '@',
      PackageManagerId.auto => throw const FormatException(
        'skill_package_manager_must_be_explicit',
      ),
    };
    final index = switch (manager) {
      PackageManagerId.npm ||
      PackageManagerId.pnpm ||
      PackageManagerId.yarn ||
      PackageManagerId.bun => token.lastIndexOf(separator),
      _ => token.indexOf(separator),
    };
    if (index <= 0) return PackageSpec(name: token);
    final name = token.substring(0, index).trim();
    final version = token.substring(index + separator.length).trim();
    if (version.isEmpty) throw const FormatException('empty_skill_package_version');
    return PackageSpec(name: name, version: version);
  }

  static PackageManifest _parseRequirements(String contents) {
    final packages = <PackageSpec>[];
    final warnings = <String>[];
    final seen = <String>{};
    for (final raw in const LineSplitter().convert(contents)) {
      final line = raw.split('#').first.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('-') ||
          line.contains('://') ||
          line.startsWith('git+') ||
          line.startsWith('file:')) {
        warnings.add('ignored_non_registry_requirement');
        continue;
      }
      final match = RegExp(
        r'^([A-Za-z0-9][A-Za-z0-9._-]*)(?:\[[A-Za-z0-9_,.-]+\])?\s*(?:(==|!=|~=|>=|<=|>|<)\s*([A-Za-z0-9][A-Za-z0-9.+!_-]*))?(?:\s*;.*)?$',
      ).firstMatch(line);
      if (match == null) {
        warnings.add('ignored_unparsed_requirement');
        continue;
      }
      final name = match.group(1)!;
      final operator = match.group(2);
      final version = match.group(3);
      if (operator != null && operator != '==') {
        warnings.add('version_range_not_locked:$name');
      }
      final spec = PackageSpec(
        name: name,
        version: operator == '==' ? version : null,
      );
      if (seen.add(spec.normalizedName)) packages.add(spec);
    }
    return PackageManifest(
      kind: PackageEcosystem.python,
      packages: List.unmodifiable(packages),
      warnings: List.unmodifiable(warnings.toSet()),
    );
  }

  static PackageManifest _parsePackageJson(String contents) {
    final decoded = jsonDecode(contents);
    if (decoded is! Map) throw const FormatException('invalid_package_json');
    final packages = <PackageSpec>[];
    final warnings = <String>[];
    final seen = <String>{};
    for (final section in const [
      'dependencies',
      'devDependencies',
      'optionalDependencies',
    ]) {
      final raw = decoded[section];
      if (raw == null) continue;
      if (raw is! Map) {
        warnings.add('invalid_package_json_section:$section');
        continue;
      }
      for (final entry in raw.entries) {
        if (entry.key is! String || entry.value is! String) {
          warnings.add('ignored_non_string_package_entry');
          continue;
        }
        final name = entry.key as String;
        final rawVersion = (entry.value as String).trim();
        final exact = RegExp(
          r'^(?:=)?([A-Za-z0-9][A-Za-z0-9.+_~:-]{0,63})$',
        ).firstMatch(rawVersion);
        final version = exact != null &&
                !rawVersion.startsWith('^') &&
                !rawVersion.startsWith('~')
            ? exact.group(1)
            : null;
        if (version == null) warnings.add('version_range_not_locked:$name');
        if (name.startsWith('file:') ||
            name.startsWith('git+') ||
            rawVersion.contains('://')) {
          warnings.add('ignored_non_registry_package:$name');
          continue;
        }
        final spec = PackageSpec(name: name, version: version);
        if (seen.add(spec.normalizedName)) packages.add(spec);
      }
    }
    return PackageManifest(
      kind: PackageEcosystem.node,
      packages: List.unmodifiable(packages),
      warnings: List.unmodifiable(warnings.toSet()),
    );
  }

  static PackageManifest _parsePyproject(String contents) {
    final dependencies = <String>[];
    final warnings = <String>[];
    var inProjectDependencies = false;
    var inArray = false;
    for (final raw in const LineSplitter().convert(contents)) {
      final line = raw.trim();
      if (line.startsWith('[')) {
        if (inArray) inArray = false;
        inProjectDependencies = line == '[project]';
        continue;
      }
      if (!inProjectDependencies) continue;
      if (!inArray && RegExp(r'^dependencies\s*=\s*\[').hasMatch(line)) {
        inArray = !line.contains(']');
        final value = line.substring(line.indexOf('[') + 1);
        _collectQuotedDependencies(value, dependencies);
        continue;
      }
      if (inArray) {
        if (line.contains(']')) inArray = false;
        _collectQuotedDependencies(line, dependencies);
      }
    }
    if (inArray) warnings.add('unterminated_pyproject_dependencies_array');
    final packages = <PackageSpec>[];
    final seen = <String>{};
    for (final raw in dependencies) {
      final match = RegExp(
        r'^([A-Za-z0-9][A-Za-z0-9._-]*)(?:\[[A-Za-z0-9_,.-]+\])?(?:\s*(==|!=|~=|>=|<=|>|<)\s*([A-Za-z0-9][A-Za-z0-9.+!_-]*))?(?:\s*;.*)?$',
      ).firstMatch(raw.trim());
      if (match == null) {
        warnings.add('ignored_unparsed_pyproject_dependency');
        continue;
      }
      final name = match.group(1)!;
      final operator = match.group(2);
      if (operator != null && operator != '==') {
        warnings.add('version_range_not_locked:$name');
      }
      final spec = PackageSpec(
        name: name,
        version: operator == '==' ? match.group(3) : null,
      );
      if (seen.add(spec.normalizedName)) packages.add(spec);
    }
    return PackageManifest(
      kind: PackageEcosystem.python,
      packages: List.unmodifiable(packages),
      warnings: List.unmodifiable(warnings.toSet()),
    );
  }

  static void _collectQuotedDependencies(String line, List<String> output) {
    final pattern = RegExp(r'''['"]([^'"]+)['"]''');
    for (final match in pattern.allMatches(line)) {
      output.add(match.group(1)!);
    }
  }

  static String? nodeLockfileFromNames(Iterable<String> names) {
    final available = names.toSet();
    for (final file in const [
      'pnpm-lock.yaml',
      'yarn.lock',
      'bun.lock',
      'bun.lockb',
      'package-lock.json',
    ]) {
      if (available.contains(file)) return file;
    }
    return null;
  }
}
