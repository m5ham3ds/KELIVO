import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Arabic locale provides Arabic strings and RTL direction', (
    tester,
  ) async {
    TextDirection? direction;
    String? appLanguageLabel;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) {
            direction = Directionality.of(context);
            appLanguageLabel =
                AppLocalizations.of(context)!.displaySettingsPageLanguageTitle;
            return Text(AppLocalizations.of(context)!.settingsPageTitle);
          },
        ),
      ),
    );

    expect(direction, TextDirection.rtl);
    expect(appLanguageLabel, 'لغة التطبيق');
    expect(find.text('الإعدادات'), findsOneWidget);
  });
}
