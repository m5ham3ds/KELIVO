import 'package:flutter/foundation.dart';

enum WorkspaceKind { managed, linked }

class Workspace {
  final String id;
  final String name;
  final WorkspaceKind kind;
  final String? hostPath;
  final bool shellNeedsApproval;
  final String defaultCwd;
  final Set<String> disabledTools;
  /// Skill ids used as this workspace's Project Default. Null inherits the
  /// assistant's configured defaults (or all enabled Skills when unset).
  final List<String>? skillIds;
  /// Optional Runtime Profile used by workspace shell/terminal invocations.
  final String? defaultRuntimeProfileId;
  /// Optional installed CLI video engine selected for this project.
  final String? defaultVideoEngineId;
  /// Non-secret, project-local settings keyed by installed video engine id.
  final Map<String, Map<String, String>> videoEngineSettings;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastUsedAt;

  const Workspace({
    required this.id,
    required this.name,
    required this.kind,
    this.hostPath,
    this.shellNeedsApproval = false,
    this.defaultCwd = '',
    this.disabledTools = const {},
    this.skillIds,
    this.defaultRuntimeProfileId,
    this.defaultVideoEngineId,
    this.videoEngineSettings = const {},
    required this.createdAt,
    required this.updatedAt,
    this.lastUsedAt,
  });

  bool isToolEnabled(String name) => !disabledTools.contains(name);

  Workspace copyWith({
    String? id,
    String? name,
    WorkspaceKind? kind,
    String? hostPath,
    bool? shellNeedsApproval,
    String? defaultCwd,
    Set<String>? disabledTools,
    List<String>? skillIds,
    bool clearSkillIds = false,
    String? defaultRuntimeProfileId,
    bool clearDefaultRuntimeProfileId = false,
    String? defaultVideoEngineId,
    bool clearDefaultVideoEngineId = false,
    Map<String, Map<String, String>>? videoEngineSettings,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastUsedAt,
    bool clearHostPath = false,
    bool clearLastUsedAt = false,
  }) {
    return Workspace(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      hostPath: clearHostPath ? null : (hostPath ?? this.hostPath),
      shellNeedsApproval: shellNeedsApproval ?? this.shellNeedsApproval,
      defaultCwd: defaultCwd ?? this.defaultCwd,
      disabledTools: disabledTools == null
          ? this.disabledTools
          : Set.unmodifiable(disabledTools),
      skillIds: clearSkillIds
          ? null
          : skillIds == null
          ? this.skillIds
          : List.unmodifiable(skillIds),
      defaultRuntimeProfileId: clearDefaultRuntimeProfileId
          ? null
          : defaultRuntimeProfileId ?? this.defaultRuntimeProfileId,
      defaultVideoEngineId: clearDefaultVideoEngineId
          ? null
          : defaultVideoEngineId ?? this.defaultVideoEngineId,
      videoEngineSettings: videoEngineSettings == null
          ? this.videoEngineSettings
          : _immutableEngineSettings(videoEngineSettings),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastUsedAt: clearLastUsedAt ? null : (lastUsedAt ?? this.lastUsedAt),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'hostPath': hostPath,
    'shellNeedsApproval': shellNeedsApproval,
    'defaultCwd': defaultCwd,
    'disabledTools': disabledTools.toList()..sort(),
    'skillIds': skillIds,
    'defaultRuntimeProfileId': defaultRuntimeProfileId,
    'defaultVideoEngineId': defaultVideoEngineId,
    'videoEngineSettings': videoEngineSettings,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'lastUsedAt': lastUsedAt?.toIso8601String(),
  };

  factory Workspace.fromJson(Map<String, dynamic> json) {
    return Workspace(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      kind: workspaceKindFromString(json['kind'] as String?),
      hostPath: json['hostPath'] as String?,
      shellNeedsApproval: json['shellNeedsApproval'] as bool? ?? false,
      defaultCwd: (json['defaultCwd'] as String?) ?? '',
      disabledTools: Set.unmodifiable(
        (json['disabledTools'] as List? ?? const []).cast<String>(),
      ),
      skillIds: json['skillIds'] == null
          ? null
          : List<String>.unmodifiable(
              (json['skillIds'] as List).cast<String>(),
            ),
      defaultRuntimeProfileId: json['defaultRuntimeProfileId'] as String?,
      defaultVideoEngineId: json['defaultVideoEngineId'] as String?,
      videoEngineSettings: _readEngineSettings(json['videoEngineSettings']),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      lastUsedAt: json['lastUsedAt'] == null
          ? null
          : DateTime.parse(json['lastUsedAt'] as String),
    );
  }

  static WorkspaceKind workspaceKindFromString(String? value) {
    switch (value) {
      case 'linked':
        return WorkspaceKind.linked;
      case 'managed':
      default:
        return WorkspaceKind.managed;
    }
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Workspace &&
            other.id == id &&
            other.name == name &&
            other.kind == kind &&
            other.hostPath == hostPath &&
            other.shellNeedsApproval == shellNeedsApproval &&
            other.defaultCwd == defaultCwd &&
            setEquals(other.disabledTools, disabledTools) &&
            ((skillIds == null && other.skillIds == null) ||
                (skillIds != null && other.skillIds != null &&
                    listEquals(skillIds, other.skillIds))) &&
            other.defaultRuntimeProfileId == defaultRuntimeProfileId &&
            other.defaultVideoEngineId == defaultVideoEngineId &&
            _engineSettingsEquals(other.videoEngineSettings, videoEngineSettings) &&
            other.createdAt == createdAt &&
            other.updatedAt == updatedAt &&
            other.lastUsedAt == lastUsedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    kind,
    hostPath,
    shellNeedsApproval,
    defaultCwd,
    Object.hashAllUnordered(disabledTools),
    skillIds == null ? null : Object.hashAll(skillIds!),
    defaultRuntimeProfileId,
    defaultVideoEngineId,
    Object.hashAllUnordered(videoEngineSettings.entries.map((entry) => Object.hash(
      entry.key,
      Object.hashAllUnordered(
        entry.value.entries.map((setting) => Object.hash(setting.key, setting.value)),
      ),
    ))),
    createdAt,
    updatedAt,
    lastUsedAt,
  );
}


Map<String, Map<String, String>> _readEngineSettings(Object? value) {
  if (value is! Map) return const {};
  final result = <String, Map<String, String>>{};
  for (final entry in value.entries) {
    if (entry.key is! String || entry.value is! Map) continue;
    final settings = <String, String>{};
    for (final setting in (entry.value as Map).entries) {
      if (setting.key is String && setting.value is String) {
        settings[setting.key as String] = setting.value as String;
      }
    }
    result[entry.key as String] = Map.unmodifiable(settings);
  }
  return Map.unmodifiable(result);
}

Map<String, Map<String, String>> _immutableEngineSettings(
  Map<String, Map<String, String>> value,
) => Map.unmodifiable({
  for (final entry in value.entries)
    entry.key: Map<String, String>.unmodifiable(entry.value),
});

bool _engineSettingsEquals(
  Map<String, Map<String, String>> a,
  Map<String, Map<String, String>> b,
) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    final other = b[entry.key];
    if (other == null || other.length != entry.value.length) return false;
    for (final setting in entry.value.entries) {
      if (other[setting.key] != setting.value) return false;
    }
  }
  return true;
}
