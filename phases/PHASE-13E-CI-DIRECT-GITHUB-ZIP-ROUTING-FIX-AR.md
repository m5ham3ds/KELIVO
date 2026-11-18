# Phase 13E — إصلاح اختبار توجيه ZIP المباشر من GitHub

**الحالة:** تم تصحيح الاختبارات وحواجز CI بنيويًا. يجب إعادة تشغيل GitHub Actions لاختبارات Flutter الفعلية وبناء Android ARM64 Release؛ هذا التصحيح لم يُقبل بعد من CI ولم ينتج APK.

## تشغيل CI محل التشخيص

- Run: `43322392152`
- Commit: `3004a176936f`
- Workflow: `Android ARM64 Build & Comprehensive Report`
- Branch: `main`
- Build mode: `release`
- Target: `arm64-v8a`

## ملخص النتيجة

نجحت مراحل Android-only audit وFlutter setup وحل الاعتماديات وتجهيز Linux native test dependencies وPhase 13E Preflight. كما اجتازت الاختبارات المركزة السابقة ملف Skill bundle حتى حالة الاختبار الأخيرة التالية:

```text
FormatException: nested_skill_bundle_no_nested_zip_files
package:Kelivo/core/services/skills/skill_archive.dart:821
 test/core/services/skills/skill_bundle_import_phase13e_test.dart:235
```

لم تبدأ مراحل localization أو Java/NDK أو بناء APK بسبب فشل اختبار Flutter. لا توجد دلالة في هذا السجل على عطل في PRoot أو Android أو حزم ZIP داخل Ubuntu.

## السبب الجذري

كان اختبار `extracts the exact direct GitHub ZIP file before Skill bundle import` ينشئ GitHub repository snapshot يحتوي ملف ZIP مباشرًا. محتوى ذلك الملف كان ZIP عاديًا لمهارة واحدة ويحتوي `SKILL.md` مع ملفاتها المصاحبة.

بعد استخراج الملف الدقيق من GitHub snapshot، استدعى الاختبار `extractNestedSkillBundleArchive()` مباشرةً. هذه الدالة مخصصة لحزمة خارجية تحوي ZIPs داخلية؛ ولذلك فإن ZIP المهارة الواحدة لا يحتوي أي ملفات ZIP متداخلة، وتعيد الدالة على نحو صحيح:

`nested_skill_bundle_no_nested_zip_files`

كان الاختبار يتجاوز مسار التوجيه الذي يستخدمه التطبيق فعليًا.

## التحقق من مسار الإنتاج

`SkillsService.importSkillsFromFile()` و`inspectLocalSource()` يطبقان ترتيبًا قائمًا على محتوى الأرشيف:

1. محاولة `extractSkillRepositoryArchive()` أولًا. هذا المسار يتعامل مع ZIP عادي يحتوي `SKILL.md` وملفات المهارة المصاحبة.
2. إذا لم يوجد `SKILL.md` في الأرشيف الخارجي، ينتقلان إلى `extractNestedSkillBundleArchive()` للتعامل مع حزمة ZIP رئيسية تحتوي ZIPs داخلية متعددة.

مسار GitHub المباشر يستخرج ملف `.zip` المحدد من repository snapshot، ثم يمرر الملف الناتج إلى `importSkillsFromFile()` أو `inspectLocalSource()`. وبذلك كان اختيار المعالج صحيحًا في الإنتاج؛ أما الاختبار فكان يستدعي الدالة المتخصصة الخطأ مباشرة.

## التغييرات

- استبدال اختبار الاستخراج المنفرد باختبار تكاملي يستخدم `extractGitHubRepositoryFile()` ثم `SkillsService.inspectLocalSource()` و`SkillsService.importSkillsFromFile()`.
- اختبار ZIP المهارة الواحدة والتحقق من بقاء `SKILL.md` و`scripts/run.py` و`references/guide.md` و`assets/config.json` بعد التثبيت.
- إضافة تغطية منفصلة لرابط GitHub ZIP مباشر يحتوي حزمة متعددة المهارات: `Skills/alpha.zip` و`Skills/beta.zip` وملف موارد مشترك `Prompts.txt`.
- التحقق من أن مسار الحزمة المتعددة يعرض مهارتين ويثبت الملفات المصاحبة لكل منهما ويحفظ مورد الحزمة المشترك في بيانات الاستيراد.
- تحديث Preflight ليتأكد من أن الاختبارين يمران عبر `SkillsService` ولا يستدعيان extractor المتداخل مباشرةً.
- تحديث CI self-test حتى يطلب اسمي الاختبارين الجديدين بدل اسم الاختبار القديم.
- لم تتغير خوارزمية ZIP في التطبيق، ولا سياسات الأمان أو حدود الحجم أو مسارات التخزين أو اعتماديات Flutter.

## الفحوص المنفذة محليًا

- `bash -n` لسكريبتات Preflight وrunner وCI self-test: اجتاز.
- Phase 13E structural Preflight: اجتاز في محاكاة باستخدام أدوات Flutter/Dart شكلية وملف package-config مؤقت. هذا يتحقق من فحوص المصدر والبنية فقط، وليس تشغيل Flutter.
- `test_phase13e_ci.sh`: اجتاز.
- فحص استبعاد بوابات 13A–13D: اجتاز؛ لا تزال خارج المسار النشط.

## ما لم ينفذ

لا تتوفر Flutter/Dart في بيئة التجهيز؛ لذلك لم تُشغّل حالات `flutter test` الجديدة، ولم يُشغّل Dart Analyzer أو formatter، ولم يُبنَ APK. يجب أن يؤكد GitHub Actions الاختبارين الجديدين وبقية Phase 13E، ثم localization، ثم Android ARM64 Release APK.

## حدود النطاق

- لم يُعد تشغيل أي اختبار من Phase 13A أو 13B أو 13C أو 13D.
- لم تُحذف ملفات الاختبارات التاريخية.
- لم يُغيّر كود `SkillsService` لأن التوجيه القائم على المحتوى في الإنتاج كان موجودًا وصحيحًا بالفعل.
- لا يُعتبر Phase 13E مقبولًا حتى تجتاز اختبارات CI وبناء APK واختبار استيراد ZIP على الهاتف.
