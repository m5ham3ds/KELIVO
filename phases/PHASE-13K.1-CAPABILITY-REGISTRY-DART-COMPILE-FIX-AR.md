# Phase 13K.1 — إصلاح ترجمة Capability Registry قبل اختبارات المهارات

## ملخص فشل CI المرسل

- المستودع: `m5ham3ds/KELIVO`
- Workflow: `Android ARM64 Build & Comprehensive Report`
- التشغيل: `43740122097`، المحاولة `1`
- الفرع: `main`
- Commit الذي بُني: `fe26943d4e5cfabc7fe40d34def59441d1dcc9ff`
- وقت البدء: `2026-11-15 17:16:06 UTC`
- Flutter: `3.47.6`، Dart: `3.13.5`

نجح Checkout وAndroid-only audit وإعداد Flutter و`flutter pub get` وتجهيز Linux GTK/GLib وPhase 13E preflight. ثم فشل تحميل أول ملف اختبار في مجموعة Phase 13E، قبل تنفيذ assertions الاختبار.

## السبب الجذري

الخطأ في:

`lib/core/services/skills/skill_capability_registry.dart:151-153`

كان حساب `title` يستخدم conditional expression يتضمن الوصول null-aware إلى Map داخل فرع الشرط:

```dart
condition
    ? descriptor?['title'] ?? kind
    : descriptors.map(...).join(', ')
```

أدى ذلك إلى تحليل Dart غير صحيح في هذا السياق، وظهرت رسائل:

- `Expected ':' before this.`
- `Expected an identifier, but got ','.`
- `A value of type 'Map<String, Object?>?' can't be assigned to a variable of type 'bool'.`

هذا خطأ ترجمة في ملف Capability Registry أضيف في 13K، وليس خللاً في اختبار PRoot أو البيئة أو الحزم. لم تُنفذ assertions ملف `environment_status_tool_test.dart`، وتخطّت GitHub Actions بقية مجموعات 13E–13K والتوطين واختبارات Android وبناء APK.

## الإصلاح

- نقل حساب عنوان القدرة إلى متغيرات محلية واضحة:
  - `descriptorTitles`
  - `descriptorTitle`
  - `resolvedTitle`
- اختيار العناوين المعروفة مجتمعة عند وجود أكثر من Runtime/Capability، واستخدام اسم النوع كقيمة احتياطية عندما لا يوجد Descriptor معروف.
- تجنب التعبير الشرطي المتداخل مع null-aware Map indexing في موضع إنشاء سجل التقييم.
- إضافة اختبار يجمع عناوين Python وShell عند اكتشاف سكريبتين مختلفين.
- إضافة اختبار يؤكد أن القدرة غير المسجلة تستخدم اسم نوعها وتظل حالتها `unknown`.
- إضافة خطوة مبكرة في GitHub Actions باسم `phase13k_syntax_preflight` تستخدم `dart format --output=none` لفحص نحو ملف السجل واختبار 13K قبل تشغيل أول مجموعة اختبارات، حتى لا يتكرر اكتشاف خطأ نحو متأخر داخل اختبار أقدم.
- تصحيح وصف وضع الاختبار في `run-metadata.txt` المولد ليقول إن المسار يشمل 13E–13K، مع استمرار استبعاد 13A–13D.

## التحقق المنفذ محلياً

نجحت الفحوص التي لا تحتاج إلى Flutter/Dart:

- `test_phase13e_ci.sh` إلى `test_phase13k_ci.sh`.
- `preflight_phase13k_tests.sh`.
- `test_phase13k_ci.sh` بعد إضافة فحص النحو المبكر.
- `audit_android_only.sh`، ويتضمن `release_hardening_audit.sh`.
- `bash -n` لسكريبتات CI المتأثرة.
- سلامة ملفات ZIP بعد إعادة الحزم.

## ما لم يُنفذ

بيئة الإصلاح لا تحتوي `flutter` أو `dart` أو `gradle`، ومحاولة الوصول إلى مستودع تنزيل Dart غير متاحة من هذه البيئة. لذلك لم يتم تشغيل `dart format` الفعلي محلياً، ولا `flutter test`، ولا Dart analyzer، ولا Android Robolectric، ولا بناء APK. خطوة syntax preflight الجديدة ستنفذ بأداة Dart الفعلية في GitHub Actions.

## نطاق التغيير والمحافظة على السابق

- لم تُغيّر منطق Skill Readiness أو حالات الجاهزية أو قواعد منع الادعاء بالدعم.
- لم تُضف اعتماديات أو أدوات جديدة.
- بقيت المهارات الأصلية مستقلة عن Skill Packs.
- لم تُفعّل اختبارات 13A–13D ولم تُعد تشغيلها.
- بقي استهداف Android ARM64 وإعدادات الخلفية وZIP ومكتبة المرفقات دون تغيير في هذه الرقعة.

## القبول المطلوب

1. نجاح `phase13k_syntax_preflight`.
2. نجاح مجموعات اختبارات 13E و13F و13G و13H و13I و13J و13K.
3. نجاح توطين العربية وتوليد ملفات l10n.
4. نجاح Android Robolectric tests.
5. بناء APK release لمعمارية ARM64 ورفع Artifact.
6. اختبار واجهة الجاهزية وسجل القدرات على هاتف Android.

لا تُعتبر PHASE13K.1 مقبولة نهائياً قبل تحقق هذه الشروط في GitHub Actions والجهاز.
