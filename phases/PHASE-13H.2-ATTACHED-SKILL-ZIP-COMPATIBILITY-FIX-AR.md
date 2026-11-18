# Phase 13H.2 — إصلاح اختبار استيراد Skill ZIP وتشخيص عدم التوافق

## نتيجة CI التي استدعت التصحيح

- Repository: `m5ham3ds/KELIVO`
- Workflow run: `43658663851`
- Commit: `5ba9d4a8d348`
- Flutter: `3.47.6` · Java 17 · Android target: `arm64-v8a`
- النتيجة: فشل مرحلة Phase 13H فقط، قبل الترجمة وبناء APK.

نجحت مراجعة Android-only، إعداد Flutter، `flutter pub get`، اعتماديات Linux، اختبارات 13E و13F و13G، وسبعة اختبارات ZIP ضمن 13H. نجحت تحديداً اختبارات منع فك ZIP كنص، MIME، توجيه Skill ZIP، مزامنة `/chat`، mount المتداخل، Host file manifest، وWorkspace tool manifest.

فشل اختبار واحد:

`installs an attached Skill ZIP from the conversation chat mount`

والرسالة المسجلة:

```text
FormatException: No compatible Agent Skills were selected from this source.
conversational_extension_service.dart:401
```

## السبب الجذري

مساعد ZIP داخل `conversational_extension_service_test.dart` كان يكتب الملفات تحت مجلد ثابت `demo-main/` مهما كان اسم المهارة في frontmatter. اختبار التثبيت كان يمرر `name: animation-director`، فينتج: 

- Skill directory: `demo-main`
- `SKILL.md` frontmatter name: `animation-director`

يتطلب تنسيق Agent Skills أن يطابق `name` اسم مجلد المهارة. لذلك يصنّف `SkillCompatibilityAnalyzer` المرشح unsupported. ويختار مسار الاستيراد التلقائي المرشحين المتوافقين فقط؛ فكانت النتيجة قائمة فارغة ثم رسالة رفض عامة. لا يشير سجل CI إلى فشل في نقل الملف أو مسار `/chat` أو فك ZIP.

## الإصلاحات

1. جعل مساعد الاختبار ينشئ المجلد باسم المهارة (`directoryName ?? name`) ويحفظ `SKILL.md` والملف المرافق في ذلك المجلد.
2. إضافة اختبار سلبي يستخدم عمداً مجلداً لا يطابق frontmatter، ويتأكد من رفضه دون تثبيت أي مهارة.
3. تحسين رسالة رفض ZIP المحلي عندما تكون كل المرشحات غير متوافقة، لتتضمن اسم المرشح والمسار وأسباب التوافق، ومنها عدم تطابق اسم المجلد.
4. إضافة الاختبار السلبي إلى `run_phase13h_tests.sh` وإضافة فحوص إلى Preflight لمنع رجوع fixture الخاطئ أو إسقاط اختبار التشخيص من CI.

## ما لم يتغير

- لم نخفف متطلبات Agent Skills أو نتجاوز التحقق من `SKILL.md`.
- لم تتغير قواعد اختيار المهارات أو سياسة عدم تنفيذ السكريبتات وقت الاستيراد.
- لم تتغير ملفات PHASE13A–13D ولا يعاد تشغيل مجموعات اختبارها.
- لم يتغير منطق مسارات `/chat` أو فهرسة ZIP الذي اجتاز الاختبارات السابقة.

## التحقق والحالة

تم تحديث ملفات المصدر والاختبار وCI وPreflight. بيئة العمل الحالية لا تحتوي Flutter/Dart/Gradle، لذلك لم أستطع تشغيل اختبارات Flutter محلياً أو بناء APK. يلزم تشغيل GitHub Actions على هذه النسخة. إذا نجحت اختبارات 13H، يفترض أن تستكمل CI فحوص localization وAndroid runtime/Robolectric ثم بناء ARM64؛ وهذه المراحل كانت skipped في run `43658663851` لأنها جاءت بعد الاختبار الفاشل.

**حالة المرحلة: تصحيح المصدر جاهز؛ القبول النهائي ينتظر CI وبناء APK.**
