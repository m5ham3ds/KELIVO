# Phase 13H.1 — إصلاح أولوية مسار مرفقات المحادثة

**السبب:** فشل GitHub Actions run `43652841623` في اختبار واحد ضمن اختبارات Phase 13H، وليس في تصنيف ZIP أو استخراج محتوياته.

## الدليل من تقرير البناء

اجتازت الخطوات التالية: Android-only audit، إعداد Flutter 3.47.6 / Dart 3.13.5، `flutter pub get`، إعداد اعتماديات Linux لاختبارات Flutter، واختبارات Phase 13E و13F و13G، وPhase 13H CI self-test وPreflight.

فشل اختبار واحد فقط:

`ZIP attachment sync exposes a real /chat file path`

وكانت النتيجة:

- Expected: `/chat/attachments/animation-director.zip`
- Actual: `/workspace/session/attachments/animation-director.zip`

وجاء التوقف عند `workspace_session_sync_test.dart:135`. لذلك تخطت CI خطوات الترجمة المحلية وJava/Gradle وRobolectric وبناء APK ARM64 والتعبئة. لا توجد في هذا التشغيل نتيجة بناء APK ناجحة أو فاشلة؛ لم تبدأ مرحلة APK أصلاً.

## السبب الجذري

في `WorkspacePaths.toModelPath()` كان تحويل المسار يختبر جذر مساحة العمل (`workspaceHostRoot`) قبل مجلد المحادثة (`sessionHostDir`). عندما يكون مجلد المحادثة فعلياً داخل جذر مساحة العمل — كما في مسار الاختبار `/workspace/session` — يطابق الجذر العام أولاً، فينتج `/workspace/session/...` بدلاً من المسار المنطقي المخصص `/chat/...`.

هذا خلل في أولوية تحويل المسارات، وليس خللاً في أرشيف ZIP أو رفعه أو مزامنته.

## الإصلاح

1. نقل فحص `sessionHostDir` ليكون قبل فحص `workspaceHostRoot` في `toModelPath()`.
2. الإبقاء على أولوية `/skills` وعمليات mount الخارجية و`/tmp` قبل `/chat`، لأن هذه المسارات أكثر تخصيصاً أو تمثل mounts مستقلة.
3. إضافة اختبار في `workspace_paths_test.dart` يثبت أن ملفاً داخل مجلد جلسة متداخل فعلياً مع جذر مساحة العمل يتحول إلى `/chat/attachments/...`.
4. إضافة اختبار المسار المتداخل إلى `run_phase13h_tests.sh` و`preflight_phase13h_tests.sh` حتى لا يقتصر التحقق على اختبار مزامنة ZIP فقط.

## نطاق التغيير

- تعديل ترتيب التعرف على المسارات في `workspace_paths.dart`.
- إضافة regression test لاختبار mount المحادثة المتداخل.
- تحديث Phase 13H runner وPreflight لإدراج الاختبار.
- لا تغيير في منطق MIME أو فك الأرشيف أو أمان أعضاء ZIP أو تثبيت المهارات.
- لا تغيير في استقلال Skills عن Skill Packs.
- لا يعاد تشغيل اختبارات 13A–13D أو مجموعات 13E–13G المعتمدة إلا ضمن مراحل CI الحالية ذات النطاق المركّز.

## حالة التحقق

تم فحص مصدر الفشل الخام وربطه بالسطر والـ assertion المحددين، وتم تطبيق تصحيح الأولوية وإضافة الاختبار. يلزم تشغيل GitHub Actions جديد لإثبات نجاح Flutter tests، ثم استمرار الخطوات اللاحقة بما فيها اختبارات Android وبناء APK ARM64. لا يُعلن نجاح الاختبار أو البناء قبل ظهور نتيجة CI الجديدة.
