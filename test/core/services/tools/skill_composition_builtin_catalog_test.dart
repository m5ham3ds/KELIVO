import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/extensions/skill_composition_tools.dart';
import 'package:Kelivo/core/services/memory/memory_prompts.dart';
import 'package:Kelivo/core/services/tools/built_in_tool_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('local catalog exposes the read-only Skill composition planner', () {
    final entries = BuiltInToolCatalog.entries(
      lang: MemoryPromptLang.en,
      legacyMemoryMode: false,
    );
    final entry = entries.singleWhere(
      (item) => item.name == SkillCompositionToolNames.compose,
    );

    expect(entry.group, BuiltInToolGroup.local);
    expect(entry.defaultDescription, contains('never executes scripts'));
  });
}
