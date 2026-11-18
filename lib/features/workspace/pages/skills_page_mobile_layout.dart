import 'package:Kelivo/core/services/haptics.dart';
import 'package:Kelivo/features/workspace/widgets/skills/skills_pane.dart';
import 'package:Kelivo/features/workspace/pages/skill_doctor_page.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:flutter/material.dart';

class SkillsPageMobileLayout extends StatelessWidget {
  const SkillsPageMobileLayout({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        leading: Tooltip(
          message: l10n.settingsPageBackButton,
          child: IosIconButton(
            icon: Lucide.directionalBack(context),
            color: cs.onSurface,
            size: 22,
            minSize: 44,
            semanticLabel: l10n.settingsPageBackButton,
            onTap: () {
              Haptics.light();
              Navigator.of(context).maybePop();
            },
          ),
        ),
        title: Text(l10n.skillsTitle),
        actions: [
          IconButton(
            tooltip: Localizations.localeOf(context).languageCode == 'ar'
                ? 'طبيب المهارات'
                : 'Skill Doctor',
            onPressed: () => openSkillDoctorPage(context),
            icon: const Icon(Icons.health_and_safety_outlined),
          ),
          const SkillsPageActions(),
          const SizedBox(width: 8),
        ],
      ),
      body: const Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: SkillsPane(showHeader: false),
      ),
    );
  }
}
