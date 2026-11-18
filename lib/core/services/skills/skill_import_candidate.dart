import 'skill_compatibility.dart';

class SkillImportCandidate {
  const SkillImportCandidate({
    required this.path,
    required this.name,
    required this.description,
    required this.bodyPreview,
    this.license,
    this.environmentCompatibility,
    this.metadata = const <String, String>{},
    this.allowedTools,
    required this.fileCount,
    this.sharedFileCount = 0,
    this.sharedBytes = 0,
    required this.compatibility,
  });

  /// Path relative to the selected repository folder; `.` means repository root.
  final String path;
  final String name;
  final String description;
  final String bodyPreview;
  final String? license;
  final String? environmentCompatibility;
  final Map<String, String> metadata;
  final String? allowedTools;
  final int fileCount;
  final int sharedFileCount;
  final int sharedBytes;
  final SkillCompatibilityReport compatibility;
}
