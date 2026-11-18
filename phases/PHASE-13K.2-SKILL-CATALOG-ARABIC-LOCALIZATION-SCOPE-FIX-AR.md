# PHASE13K.2 — إصلاح نطاق توطين نافذة كتالوج المهارات

## ملخص فشل CI

- المستودع: `m5ham3ds/KELIVO`
- Workflow: `Android ARM64 Build & Comprehensive Report`
- Run: `43770150805`
- Commit الذي جُرّب: `bdfa654f90e9417a6c4469708fe03dce7e0443e9`
- Flutter: `3.47.6`
- Dart: `3.13.5`
- أول فشل: Phase 13E test lane، أثناء تحميل `test/features/workspace/skills/skill_pack_original_visibility_phase13e_test.dart`.

## السبب الجذري

أظهر سجل الاختبار:

```text
lib/features/workspace/widgets/skills/skill_import.dart:420:50:
Error: Undefined name 'isArabic'.
child: Text(isChinese ? '关闭' : isArabic ? 'إغلاق' : 'Close'),
```

كان `showSkillsCatalogSearch()` يعرّف `isChinese` فقط ثم يستخدم `isArabic` في زر إغلاق نافذة كتالوج skills.sh. كان `isArabic` معرفاً في دالة أخرى (`_showSkillImportReports`)؛ ومتغيرات Dart المحلية لا تمتد إلى دوال أخرى، لذلك فشل تحميل الاختبار قبل تنفيذ assertions.

هذا الخطأ لا يتعلق بمحرك Skill Readiness أو Capability Registry أو ZIP/PRoot. وهو خطأ توطين UI يمنع ترجمة الملف المستورد من قبل الاختبار.

## الإصلاح

في `lib/features/workspace/widgets/skills/skill_import.dart`، أصبحت بداية `showSkillsCatalogSearch()`:

```dart
Future<void> showSkillsCatalogSearch(BuildContext context) async {
  final service = context.read<SkillsService>();
  final languageCode = Localizations.localeOf(context).languageCode;
  final isChinese = languageCode == 'zh';
  final isArabic = languageCode == 'ar';
```

وهذا يبقي قرار اللغة ضمن نطاق الدالة التي تستخدمه.

## منع التكرار

أضيف الاختبار:

`test/features/workspace/skills/skill_catalog_arabic_localization_phase13k_test.dart`

ويقوم بفتح نافذة كتالوج المهارات على locale عربية والتحقق من وجود زر `إغلاق` وعدم صدور استثناء أثناء العرض.

تم إدراج الاختبار في:

- `.github/scripts/run_phase13k_tests.sh`
- `.github/scripts/preflight_phase13k_tests.sh`
- `.github/scripts/test_phase13k_ci.sh`

كما أضيف فحص ثابت يراجع أن دالة `showSkillsCatalogSearch()` تعرّف `isArabic` محلياً وتستخدمه في النص العربي. وتوسعت خطوة `phase13k_syntax_preflight` المبكرة لتشمل تنسيق ملف واجهة الاستيراد واختبار التوطين الجديد قبل تشغيل اختبارات الانحدار الأولى.

## الفحوص المنفذة محلياً

نجحت:

- Phase 13K Preflight: جميع الفحوص البنيوية.
- Phase 13K CI Self-Test.
- Phase 13J Preflight.
- سلامة أوامر Bash للسكربتات التي تم تعديلها.
- Android-only Audit وRelease Hardening (يُعاد تأكيدهما بعد تغليف النسخة).
- التحقق من YAML وسلامة ZIP.

لم تتوفر Flutter أو Dart أو Gradle في بيئة الإصلاح، لذلك لم يتم تشغيل Flutter widget test الجديد أو `dart analyze` أو بناء APK فعلياً. نجاح الفحوص البنيوية ليس دليلاً على نجاح تجميع Dart الكامل.

## المطلوب لإغلاق المرحلة

1. تشغيل GitHub Actions على هذه النسخة.
2. التأكد من نجاح Phase 13E بما فيها اختبار `skill_pack_original_visibility_phase13e_test.dart`.
3. نجاح اختبار نافذة كتالوج المهارات بالعربية ضمن Phase 13K.
4. نجاح مجموعات 13F–13K والتوطين واختبارات Android الخلفية.
5. إنتاج APK ARM64 ثم اختباره على الهاتف.

لا تُعاد اختبارات 13A–13D. تبقى حالة PHASE13K.2 غير معتمدة نهائياً حتى نجاح CI والبناء الفعلي.
