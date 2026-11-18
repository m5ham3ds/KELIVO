import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/skill_pack.dart';

void main() {
  test('SkillPack round-trips its custom shortcut and ordered members', () {
    final pack = SkillPack(
      id: 'pack-youtube',
      name: 'YouTube Toolkit',
      shortcut: 'youtube',
      skillIds: const ['yt-audit', 'yt-chapters', 'yt-seo'],
      enabled: false,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
      description: 'Research, plan and optimize YouTube content.',
    );

    final restored = SkillPack.fromJson(pack.toJson());
    expect(restored.id, pack.id);
    expect(restored.shortcut, 'youtube');
    expect(restored.skillIds, ['yt-audit', 'yt-chapters', 'yt-seo']);
    expect(restored.enabled, isFalse);
  });

  test('SkillPack rejects duplicate members and unsafe slash aliases', () {
    final now = DateTime.utc(2026);
    SkillPack make({
      String shortcut = 'valid',
      List<String> ids = const ['one'],
    }) => SkillPack(
      id: 'pack-test',
      name: 'Test pack',
      shortcut: shortcut,
      skillIds: ids,
      enabled: false,
      createdAt: now,
      updatedAt: now,
    );

    expect(() => make(shortcut: 'Bad Alias').validate(), throwsFormatException);
    expect(() => make(ids: const ['one', 'one']).validate(), throwsFormatException);
    expect(() => make(shortcut: '../escape').validate(), throwsFormatException);
  });
}
