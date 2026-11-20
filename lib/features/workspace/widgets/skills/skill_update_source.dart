import 'package:Kelivo/core/services/skills/skills_service.dart';
import 'package:Kelivo/features/workspace/widgets/skills/skill_labels.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Future<void> showSkillUpdateSourceDialog(
  BuildContext context,
  Skill skill,
) async {
  final l10n = AppLocalizations.of(context)!;
  final value = await showDialog<String>(
    context: context,
    builder: (_) => _SkillUpdateSourceDialog(skill: skill),
  );
  if (value == null || !context.mounted) return;
  try {
    await context.read<SkillsService>().setUpdateSource(skill.record.id, value);
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      message: l10n.skillsLinkUpdateSourceSaved,
      type: NotificationType.success,
    );
  } catch (error) {
    if (!context.mounted) return;
    final message = error is FormatException
        ? l10n.skillsLinkUpdateSourceInvalid
        : skillErrorMessage(error);
    showAppSnackBar(
      context,
      message: message,
      type: NotificationType.error,
    );
  }
}

class _SkillUpdateSourceDialog extends StatefulWidget {
  const _SkillUpdateSourceDialog({required this.skill});

  final Skill skill;

  @override
  State<_SkillUpdateSourceDialog> createState() =>
      _SkillUpdateSourceDialogState();
}

class _SkillUpdateSourceDialogState extends State<_SkillUpdateSourceDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      scrollable: true,
      title: Text(l10n.skillsLinkUpdateSource),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.skillsLinkUpdateSourceHint),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: l10n.skillsImportGitHubRepoLabel,
                hintText: l10n.skillsImportGitHubUrlHint,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.skillsCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.skillsSave),
        ),
      ],
    );
  }
}
