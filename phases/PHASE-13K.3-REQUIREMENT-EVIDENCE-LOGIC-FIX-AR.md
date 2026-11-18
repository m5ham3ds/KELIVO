# PHASE13K.3 — تصحيح منطق أدلة متطلبات المهارات

**الحالة:** إصلاح مصدر + اختبارات انحدار مضافة؛ قبول Flutter وAPK ما زال بانتظار CI.

## 1. تشخيص فشل البناء

تم تحليل التقرير المنسق والسجلات الخام لتشغيل GitHub Actions:

- المستودع: `m5ham3ds/KELIVO`
- Run: `43774290731`
- Commit: `4c001a164c7e`
- Flutter: `3.47.6`
- وضع البناء: `release`

اجتازت عملية التشغيل Android-only Audit، وإعداد Flutter، وحل اعتماديات Flutter، وتجهيز GTK/GLib، واختبارات Phase 13E و13F و13G و13H و13I، وكذلك Phase 13K Syntax Preflight.

توقف المسار عند اختبار Phase 13J التالي:

`reports when no requirement evidence was found without claiming operational readiness`

والتوقع الذي فشل كان:

```text
Expected: contains 'not proof'
Actual: '[]'
```

لم يكن هذا خطأ ترجمة أو مشكلة Android. كان خطأ منطق في شرط إضافة الملاحظة داخل `SkillRequirementsAnalyzer` في:

`lib/core/services/skills/skill_requirements.dart`

الشرط السابق كان يمنع إضافة ملاحظة غياب أدلة المتطلبات متى احتوى `capabilityAssessment` على أي عنصر. وهذا جعل قدرة `instruction_only`، وهي وصف لطريقة الاستفادة من التعليمات وليست اعتماداً بيئياً، تمنع التحذير المحافظ. كذلك لم يكن الشرط السابق يحتسب `externalServices` ضمن الأدلة.

## 2. الإصلاح

استُبدل الشرط بحساب صريح `hasRequirementEvidence` يعتمد على الأدلة الفعلية:

- أوامر Runtime/CLI المكتشفة.
- الحزم واعتمادياتها.
- أسماء بيانات الاعتماد ومتغيرات البيئة المطلوبة.
- الخدمات الخارجية المعلنة.

وبذلك:

- وجود `instruction_only` وحده لا يمنع إظهار التنبيه.
- غياب الدليل لا يتحول إلى ادعاء بأن المهارة لا تحتاج شيئاً؛ تبقى الملاحظة واضحة بأن عدم الاكتشاف ليس دليلاً على عدم وجود متطلبات.
- وجود خدمة خارجية معلنة يُعد دليلاً على وجود متطلب، لذلك لا يظهر تنبيه «لم تُكتشف متطلبات» عندما تكون الخدمة معروفة.
- لم تتم إضافة أي تثبيت حزم أو تنفيذ سكريبتات أو اتصال خارجي أثناء الاكتشاف.

## 3. اختبارات الانحدار

أضيف اختبار ثانٍ إلى `skill_requirements_test.dart`:

`does not claim no requirements when an external service is declared`

ويتحقق من أن المهارة ذات القدرة النصية وخدمة خارجية معلنة تُظهر الخدمة ولا تعرض ملاحظة غياب الأدلة.

أما الاختبار الذي فشل في CI فيتحقق الآن من أن `instruction_only` لا يمنع ظهور ملاحظة `not proof`.

كما تم تحديث:

- `.github/scripts/preflight_phase13j_tests.sh`
- `.github/scripts/test_phase13j_ci.sh`

ليتحققا من منطق الأدلة الجديد ومن وجود اختبار الخدمة الخارجية.

## 4. الفحوص المحلية التي نُفذت

نجحت محلياً:

- Phase 13J Preflight وCI Self-Test.
- Phase 13K Preflight وCI Self-Test.
- Phase 13F و13G و13H و13I Preflight/CI wiring.
- Android-only Audit.
- Release Hardening Audit.
- Bash syntax للسكريبتات المعدلة.
- قراءة ملف GitHub Actions YAML والتحقق من صلاحيته.
- فحوص وجود التغيير واختبارات الانحدار في المصدر.

**لم يتم تشغيل Flutter/Dart tests أو Dart analysis أو Gradle أو بناء APK محلياً** لأن Flutter/Dart/Gradle غير متاحة في بيئة الإصلاح. لذلك لا تُعد هذه المرحلة مقبولة نهائياً قبل تشغيل GitHub Actions بنجاح.

## 5. نطاق التغيير

- لم تُعد اختبارات 13A–13D.
- لم تُغير سياسة التحقق من الجاهزية أو سجل القدرات.
- لم يُسمح بتنفيذ أي Skill أثناء التحليل.
- لم تُثبت حزم أو أدوات جديدة.
- بقي ترتيب CI: 13E ثم 13F ثم 13G ثم 13H ثم 13I ثم 13J ثم 13K ثم Arabic localization وAndroid runtime tests وبناء ARM64.

## 6. القبول المتبقي

بعد رفع محتويات المشروع إلى جذر المستودع وتشغيل Actions، يجب التحقق من:

1. نجاح ملف `skill_requirements_test.dart` كاملاً، بما فيه الحالتان الجديدتان.
2. نجاح اختبارات Phase 13J المتبقية.
3. نجاح اختبارات Phase 13K والواجهة العربية.
4. نجاح فحوص الترجمة العربية واختبارات Android الخلفية.
5. إنتاج APK ARM64 ورفعه كـ Artifact.

لا يُعلن نجاح بناء APK قبل ظهور نتيجة فعلية ناجحة من GitHub Actions.
