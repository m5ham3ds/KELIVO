# Arabic localization status

Kelivo registers Arabic (`ar`) as a supported application locale alongside English, Simplified Chinese, and Traditional Chinese. Arabic can be selected in both mobile and desktop display settings. The preference is persisted through the existing app-locale setting. Flutter's standard Material, Cupertino, and Widgets localization delegates provide Arabic right-to-left directionality.

## Current coverage

- Total application messages: **4,733**
- Arabic translations reviewed/overridden: **4,614 (97.49%)**
- English fallbacks: **119 (2.51%)**
- Every Arabic message key is present, and the declared placeholder metadata matches the English template.

Most remaining unchanged strings are intentionally language-neutral technical tokens, including provider and service names, API/protocol identifiers, code samples, file format labels, keyboard shortcuts, operating-system names, and numeric format patterns. The generated status is recorded in `lib/l10n/app_ar_status.json`.

## RTL behavior

Flutter's `GlobalWidgetsLocalizations` sets the text direction to RTL for `ar`. Back-navigation icons use `Lucide.directionalBack(context)` so they point toward the correct logical direction. Code, terminal output, URLs, API identifiers, paths, and other technical tokens should remain LTR where appropriate. This does not imply that every custom screen layout has undergone a visual device review; the RTL widget test and device verification remain important.

## Validation

Run the following in the Flutter environment:

```bash
flutter pub get
python3 .github/scripts/check_l10n_parity.py
flutter gen-l10n
```

The focused Arabic RTL widget and persisted-locale test sources remain under `test/`, but they are intentionally not invoked by Android ARM64 Release CI: `flutter test` selects Linux host assets and triggers the `super_native_extensions` Linux native build hook. They remain available for a dedicated compatible host-test environment.

The automatic Android GitHub Actions workflow validates ARB key/placeholder parity, runs `flutter gen-l10n`, and builds the ARM64 APK. It no longer contains a skipped host-test placeholder or runs the historical Phase regression suites.

**Status:** Arabic locale, mobile/desktop selection, persisted preference, RTL direction, translated resource bundle, and Android Release CI gates are implemented. Source-level localization coverage is 97.49%; technical tokens listed above are intentionally preserved. The focused test sources are retained but are not part of Android Release CI; visual RTL review and device-level locale persistence verification remain recommended.
