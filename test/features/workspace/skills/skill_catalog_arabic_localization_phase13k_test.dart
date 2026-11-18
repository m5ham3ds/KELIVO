import 'package:Kelivo/core/services/skills/skills_service.dart';
import 'package:Kelivo/features/workspace/widgets/skills/skill_import.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'skills_test_fakes.dart';

void main() {
  testWidgets('skills catalog search dialog renders the Arabic close action', (
    tester,
  ) async {
    final skills = FakeSkillsService();
    addTearDown(skills.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<SkillsService>.value(
        value: skills,
        child: MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showSkillsCatalogSearch(context),
                child: const Text('Open catalog'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open catalog'));
    await tester.pumpAndSettle();

    expect(find.text('إغلاق'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
