/// A user-facing, reusable grouping of Agent Skills.
///
/// Members remain independent Agent Skills on disk and in the UI. A pack only
/// stores their IDs, a display name and a slash-command shortcut; membership
/// is non-exclusive, and deleting/editing a pack never changes its members.
final class SkillPack {
  const SkillPack({
    required this.id,
    required this.name,
    required this.shortcut,
    required this.skillIds,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
    this.autoDetected = false,
  });

  static final RegExp _idPattern =
      RegExp(r'^[a-z0-9][a-z0-9._-]{0,127}$');
  static final RegExp shortcutPattern =
      RegExp(r'^[a-z][a-z0-9_-]{0,31}$');

  final String id;
  final String name;
  final String shortcut;
  final List<String> skillIds;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String description;
  /// Repository-detected packs can be refreshed when more Skills are found.
  /// Editing a pack turns this off so the user's arrangement is preserved.
  final bool autoDetected;

  void validate() {
    if (!_idPattern.hasMatch(id)) {
      throw const FormatException('skill_pack_id');
    }
    if (name.trim().isEmpty || name.trim().length > 80) {
      throw const FormatException('skill_pack_name');
    }
    if (!shortcutPattern.hasMatch(shortcut)) {
      throw const FormatException('skill_pack_shortcut');
    }
    if (description.length > 500) {
      throw const FormatException('skill_pack_description');
    }
    if (skillIds.isEmpty || skillIds.length > 64 ||
        skillIds.any((id) => !_idPattern.hasMatch(id)) ||
        skillIds.toSet().length != skillIds.length) {
      throw const FormatException('skill_pack_members');
    }
  }

  SkillPack copyWith({
    String? id,
    String? name,
    String? shortcut,
    List<String>? skillIds,
    bool? enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? description,
    bool? autoDetected,
  }) => SkillPack(
    id: id ?? this.id,
    name: name ?? this.name,
    shortcut: shortcut ?? this.shortcut,
    skillIds: List.unmodifiable(skillIds ?? this.skillIds),
    enabled: enabled ?? this.enabled,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    description: description ?? this.description,
    autoDetected: autoDetected ?? this.autoDetected,
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'id': id,
    'name': name,
    'shortcut': shortcut,
    'skillIds': skillIds,
    'enabled': enabled,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'description': description,
    'autoDetected': autoDetected,
  };

  factory SkillPack.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1 ||
        json['id'] is! String ||
        json['name'] is! String ||
        json['shortcut'] is! String ||
        json['skillIds'] is! List ||
        (json['skillIds'] as List).any((value) => value is! String) ||
        json['createdAt'] is! String ||
        json['updatedAt'] is! String) {
      throw const FormatException('skill_pack_record');
    }
    final value = SkillPack(
      id: json['id'] as String,
      name: json['name'] as String,
      shortcut: json['shortcut'] as String,
      skillIds: List.unmodifiable((json['skillIds'] as List).cast<String>()),
      enabled: json['enabled'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      description: json['description'] as String? ?? '',
      autoDetected: json['autoDetected'] as bool? ?? false,
    );
    value.validate();
    return value;
  }
}
