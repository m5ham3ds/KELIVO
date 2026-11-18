# PHASE13K.4 — مزامنة اختبار سياسة تثبيت المهارات مع نص المساعد

## ملخص فشل CI

تم تحليل تشغيل GitHub Actions التالي:

- المستودع: `m5ham3ds/KELIVO`
- Run: `43780091708`
- Commit: `93c38a495720ee5585b3e146e4910a5d1562103b`
- التاريخ: `2026-11-16`
- Flutter: `3.47.6`
- Dart: `3.13.5`

اجتازت بوابة Android-only، وإعداد Flutter، وحل الاعتماديات، وSyntax Preflight لـ13K، واختبارات 13E و13F و13G و13H و13I، كما اجتاز Phase 13J Preflight. توقف التشغيل عند اختبار Phase 13J:

`core capabilities are independent from installed Skills`

كان الاختبار يتوقع العبارة القديمة `never pretend it was installed`، بينما يحتوي prompt الفعلي على صياغة محدثة تؤدي المعنى نفسه وتفرض دليلاً أقوى قبل الادعاء بالتثبيت:

`Do not claim a Skill was installed until its files have been saved and verified.`

لم يكن هذا خطأ في سلوك المساعد أو في تثبيت Skill؛ بل عدم تزامن بين النص الحالي واختبار يعتمد على عبارة حرفية قديمة.

## الإصلاح

1. تحديث assertion في `skills_prompt_test.dart` ليختبر النص الفعلي الحالي كاملاً بدلاً من العبارة القديمة.
2. إضافة شرط إلى `preflight_phase13j_tests.sh` يقرأ prompt واختباره ويتأكد أن صياغة سياسة التثبيت متطابقة، حتى لا ينفصل الاختبار عن النص مستقبلاً.
3. الإبقاء على سياسة عدم ادعاء التثبيت قبل حفظ الملفات والتحقق منها؛ لم يتم تخفيف أي شرط أمني أو تغيير منطق الإنتاج.
4. إبقاء اختبار `core capabilities are independent from installed Skills` ضمن مسارات 13J و13K المركزة، كي يتحقق كلا المسارين من القاعدة نفسها.
5. تصحيح وصف وضع الاختبارات في مولّد تقرير CI ليذكر Phase 13E–13K بدلاً من Phase 13E وحدها.

## نتائج الفحوص المحلية

نجحت فحوص Bash وCI wiring وPreflight البنيوية وAndroid-only وRelease Hardening وفحص YAML وسلامة ZIP. لا تتوفر Flutter/Dart/Gradle في بيئة الإصلاح الحالية، لذلك لم تُشغّل اختبارات Flutter الفعلية ولا `dart analyze` ولا بناء APK. يجب تأكيدها في GitHub Actions.

## الاختبارات التي لم تصل إليها عملية CI السابقة

بسبب توقف 13J، لم تُنفذ اختبارات 13K، ولا التحقق من مفاتيح الترجمة وتوليد localization، ولا اختبارات Robolectric ولا بناء APK ARM64. هذه كلها ما زالت متطلبات قبول.

لم تُعد اختبارات 13A–13D، ولم يتغير مسارها.
