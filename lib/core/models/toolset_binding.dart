/// Conversation extras binding for per-chat Toolset restrictions.
///
/// A null [toolsetIds] inherits the assistant's Toolset allow-list. An empty
/// list explicitly disables every source Toolset while the Registry's core
/// control-plane Toolset remains available.
class ToolsetBinding {
  static const String keyIds = 'toolsets.ids';

  final List<String>? toolsetIds;

  const ToolsetBinding({this.toolsetIds});

  factory ToolsetBinding.fromExtras(Map<String, dynamic> extras) {
    if (!extras.containsKey(keyIds)) {
      return const ToolsetBinding();
    }
    final raw = extras[keyIds];
    if (raw == null) return const ToolsetBinding();
    if (raw is List) {
      return ToolsetBinding(
        toolsetIds: [for (final item in raw) item.toString()],
      );
    }
    return const ToolsetBinding();
  }

  /// Writes the conversation override or removes it to inherit the assistant.
  Map<String, dynamic> applyTo(Map<String, dynamic> extras) {
    final next = Map<String, dynamic>.from(extras);
    if (toolsetIds == null) {
      next.remove(keyIds);
      return next;
    }
    next[keyIds] = List<String>.from(toolsetIds!);
    return next;
  }
}
