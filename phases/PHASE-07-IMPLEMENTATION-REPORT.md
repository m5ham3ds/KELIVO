# Phase 7 Implementation Report — Generic Video Engine Adapter Layer

## Summary

تم إعداد البنية المصدرية العامة لمحولات محركات الفيديو الاختيارية وربطها بالمحادثة، دون إضافة محرك فيديو محدد إلى APK أو تثبيت أي dependencies تلقائياً. التثبيت يفحص البيان ويحفظ الملفات فقط؛ تشغيل أوامر المحرك يظل محمياً بموافقة المستخدم.

## Implementation

- `video_engine_manifest.dart`: محلل `kelivo.engine.yaml` للإصدار 1، مع تحقق من schema/id/compatibility/runtime/dependencies/commands/output extension. يتحقق من executable paths وargs وcontrol characters والـ placeholders المسموح بها، ويوسع كل argument دون دمج مدخل المستخدم في shell command.
- `video_engine_service.dart`: إدارة سجل محركات `engine` داخل `ExtensionRegistryRepository`، وربط كل سجل بـ Workspace محدد، وتثبيت من GitHub عام أو مجلد/ZIP محلي، staging، واستخراج ZIP بقيود الحجم وعدد الملفات ورفض traversal والروابط الرمزية والتكرار.
- يخزن المحرك ضمن `.kelivo/engines/<id>/`. لا تشغّل عملية التثبيت سكربتات الحزمة ولا تثبت تبعياتها.
- Preflight يتحقق من Android/PRoot/ARM64، واكتشاف أوامر التبعيات وRuntime Profile حسب ecosystems المعلنة، ثم ينفذ أوامر الإصدار/الفحص بعد موافقة المستخدم.
- أوامر create/render/inspect/cancel تنفذ عبر `WorkspaceRuntime`، مع Run IDs ووقت أقصى وبيئة Runtime Profile عند تحديدها، والتقاط محدود لحجم stdout/stderr.
- `renderVerified` لا يصبح true إلا بعد نجاح الأمر ووجود ملف خرج عادي غير فارغ داخل Workspace؛ ولا يعلن النظام الدعم لمجرد نجاح التثبيت أو Preflight. كما تتم مطابقة SHA-256 لملف manifest مع سجل الإضافة عند إعادة تحميل المحرك لمنع تغيير عقد الأوامر بعد التثبيت.
- أضيف `defaultVideoEngineId` و`videoEngineSettings` إلى Workspace مع قراءة متوافقة لبيانات JSON القديمة. الإعدادات غير السرية تمرر في متغيرات بيئة `KELIVO_ENGINE_SETTING_*`.
- أضيفت أداة محادثة `video_engine` مع أوامر list/install/inspect/preflight/default/configure/create/render/inspect_project/cancel/remove. طلب الموافقة مطلوب لكل تغيير أو تشغيل لكود المحرك.
- أضيف عرض موحد لبطاقة أداة المحرك في سجل المحادثة، وحجز الاسم في قائمة أسماء أدوات Kelivo المدمجة لمنع تعارض MCP.
- أضيف Phase 7 Android-focused CI manifest/scripts، وربط سير Android build وmanual quality workflow بها، وتحديث Android-only audit ليمنع إدخال اختبارات منصات غير Android.

## Tests added/updated

- `video_engine_manifest_test.dart`: قبول العقد الكامل وround-trip، ورفض schema غير مدعوم/غير صحيح النوع، والكائنات المتداخلة المشوهة، والأوامر الناقصة أو shell executable expressions، والمسارات المطلقة/المتجاوزة، والـ placeholders المجهولة وcontrol characters وcompatibility/output extension غير الصحيح.
- `video_engine_service_safety_test.dart`: قبول مسارات الحزم المتداخلة الآمنة ورفض absolute/drive-prefixed/traversal/dot-segment/null-byte archive paths.
- `workspace_test.dart`: تخزين واسترخاع محرك المشروع وإعداداته، copyWith/clear، والمساواة مع اختلاف ترتيب Map، والقراءة التوافقية لملفات Workspace القديمة.
- `built_in_tool_names_test.dart`: حجز الاسم والتحقق من مخطط الأداة والعمليات الأساسية.
- `workspace_tool_ui_test.dart`: إضافة محرك الفيديو إلى اختبار ظهور عنوان وأيقونة أدوات المشروع، مع حالة واجهة منفصلة.
- Android Phase 7 CI manifest يحوي 28 ملف اختبار مركزاً، إضافةً إلى خمسة اختبارات UI مسماة.

## Validation performed in this packaging environment

- فحص قائمة manifest للتأكد من وجود 28 ملف اختبار فعلياً، بالإضافة إلى ملف UI.
- فحص صياغة Bash scripts الجديدة باستخدام `bash -n`، واجتياز Android-only audit بعد تصحيح صلاحية تنفيذ سكربت تغليف APK الموجود في الأرشيف.
- مراجعة تكامل الاستدعاءات وأسماء الأداة وربطها بـ built-in reservations وworkspace UI.
- لم يتوفر Dart/Flutter SDK في بيئة إعداد الحزمة؛ لذلك لم يتم تشغيل `dart format` أو `dart analyze` أو `flutter test` أو بناء APK محلياً. GitHub Actions هي بوابة التحليل والاختبار وبناء ARM64 Release.

## Known limitations / acceptance still pending

- لم يختر المستخدم محركاً حقيقياً بعد، ولم يُرفق adapter package خاصاً بمحرك؛ لذلك لم يحدث Render واقعي على Android ARM64 ولم يُعلن أي محرك مدعوماً.
- GitHub source يدعم المستودعات العامة فقط في هذه الدفعة؛ private repository credentials غير مربوطة.
- اكتشاف التبعيات لا يثبتها؛ على المستخدم تثبيت ما يلزم عبر Package Manager/Runtime Profile ثم إعادة Preflight.
- الملف الناتج يفحص حالياً بأنه ملف غير فارغ داخل Workspace؛ لا يوجد ffprobe-based media validation في هذه المرحلة.
- Runtime Profiles وPRoot ليست sandbox أمنياً قوياً، ولا تمنع كل ما قد يفعله كود المحرك الذي وافق المستخدم على تشغيله.
- لا يوجد بعد update/rollback lifecycle للمحركات، أو remote runtime، أو PTY session طويلة.
- تبقى فجوات Phase 3–6 السابقة كما هي؛ Phase 4 ما زالت بلا Skills executor وartifact transfer فعلي.

## Acceptance

- [x] Generic engine manifest contract and parser.
- [x] Optional package install from public GitHub or workspace folder/ZIP.
- [x] ZIP traversal/symlink/duplicate/size/file-count validation.
- [x] Per-workspace engine registry and project settings.
- [x] ARM64/PRoot/dependency/runtime-profile preflight.
- [x] Conversational management and explicit approval for mutations/execution.
- [x] Runtime-backed create/render/inspect/cancel command routing.
- [x] Render verification only after a non-empty output is present in Workspace.
- [ ] Dart analyze and focused Phase 7 tests pass in GitHub Actions.
- [ ] Android ARM64 Release build and artifact upload pass in GitHub Actions.
- [ ] Selected engine renders a real artifact successfully on an ARM64 Android phone.
- [ ] Removal isolation is confirmed on-device across unrelated Skills/projects.

**Status:** Source implementation prepared; Phase 7 is not formally accepted. The engine-neutral foundation of Phase 8 was started at the user's direction, but real rendering and declaring any engine supported remain blocked until an actual ARM64 render test passes.

## Advancement note

بناءً على توجيه المستخدم بالانتقال مباشرة إلى المرحلة التالية، بدأ أساس Phase 8 المحايد للمحرك مع إبقاء جميع بوابات قبول Phase 7 غير المنجزة دون تغيير. لا يعني ذلك قبول هذه المرحلة أو إعلان دعم أي محرك؛ اختبار Render الفعلي على Android ARM64/PRoot وCI واختبار الإزالة ما زالت مطلوبة.
