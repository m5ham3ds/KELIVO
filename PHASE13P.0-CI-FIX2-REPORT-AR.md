# تقرير إصلاح KELIVO PHASE13P.0 — CI-FIX2

## سبب الفشل في تشغيل 17 نوفمبر 2026

بحسب `Kelivo-Build-Report-1-1(20261117-153533).zip` والسجل الخام:

- نجح Android-only source audit.
- نجح إعداد Flutter 3.47.6.
- نجح `flutter pub get` ولم يتغير `pubspec.lock`.
- فشل أول اختبار Flutter ضمن Phase 13E أثناء تحميل ملف الاختبار، قبل بدء حالات الاختبار نفسها.
- تخطّت المراحل اللاحقة بناءً على فشل هذه الخطوة السابقة؛ لا تمثل حالات Skipped أخطاء مستقلة.

أبلغ المترجم عن ثلاثة أخطاء في ملفين:

1. `lib/core/services/runtime_profiles/runtime_profile_service.dart:474` — صياغة `$(...)` داخل نص Dart غير محمية من استيفاء علامة الدولار.
2. `lib/core/services/skills/skill_readiness.dart:238` — امتداد `..sort()` اتصل بسلسلة cascade الخاصة بخريطة النتائج، بدلاً من القائمة المسندة إلى المفتاح.
3. `lib/core/services/skills/skill_readiness.dart:239` — الخطأ نفسه في قائمة القدرات الإلزامية المتبقية.

## التغييرات

- حماية `$(` في نص أمر Shell باستخدام صياغة Dart interpolation التي تنتج علامة دولار حرفية، مع إبقاء command substitution في Shell كما هو.
- إنشاء قائمتَي القدرات المجتازة والمتبقية وفرزهما قبل إسنادهما إلى خريطة نتائج الجاهزية، لتجنب غموض الـcascade.
- إضافة اختبار انحدار يتحقق من ثبات الترتيب الأبجدي لقوائم القدرات المجتازة والمتبقية.

## الفحوص المنفذة في بيئة التحرير

- Android-only source audit: PASS.
- Phase 13E CI self-test: PASS.
- Phase 13L CI self-test: PASS.
- Phase 13M CI self-test: PASS.
- Phase 13N CI self-test: PASS.
- Phase 13O CI self-test: PASS.
- Phase 13P CI self-test: PASS.
- `bash -n` لجميع سكريبتات `.github/scripts`: PASS.
- تحليل YAML لملف GitHub Actions: PASS.
- اختبار Shell fragment المصحح لحساب حجم الأرشيف: PASS.

## ما لم يُنفّذ

لا تتوفر Flutter أو Dart أو Gradle في بيئة التحرير هذه. لذلك لم يُنفّذ `dart format` أو `dart analyze` أو `flutter test` أو Robolectric أو بناء APK بعد هذا الإصلاح. يجب إعادة تشغيل GitHub Actions لإثبات نجاح الترجمة والاختبارات والبناء.

## النطاق

هذا إصلاح محدود فوق `KELIVO-PHASE13P.0-CI-FIX1-SOURCE.zip`. لم تُعد المراحل السابقة من البداية ولم تُغيّر إعدادات الاعتماديات أو نسخ الحزم.
