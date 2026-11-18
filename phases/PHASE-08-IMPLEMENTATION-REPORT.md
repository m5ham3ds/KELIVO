# Phase 8 Implementation Report — Code-Generated Video Workflow

## Summary

بدأ تنفيذ Phase 8 بطبقة تخطيط ومشروع مستقلة عن محركات الفيديو. تم ربطها بالمحادثة كأداة `video_production`، وتتكامل مع `VideoEngineService` الحالي عند التصيير دون تضمين محرك أو تثبيت dependencies في APK.

## Files added

- `lib/core/services/video_production/video_production_spec.dart`
  - `VideoProductionSpec` لعقد الإنتاج المحايد للمحرك.
  - `VideoProductionScene` لعقد المشاهد.
  - تحقق من الدقة ومعدل الإطارات والمدة وصيغة MP4 وتفرّد معرفات المشاهد ومدة Storyboard.
  - تحقق صارم من المسارات النسبية لملفات المصدر والأصول، ورفض المقاطع المخفية، والتحقق من تطابق أبعاد الفيديو مع نسبة الأبعاد.
- `lib/core/services/video_production/video_production_service.dart`
  - `plan`, `create`, `update`, `status`, `render`, `export`.
  - حفظ JSON وMarkdown للـ Storyboard وملفات المصدر داخل Workspace.
  - إنشاء ذري عبر staging ثم rename، ورفض symlink/traversal.
  - نسخ احتياطية قبل استبدال source files، وإبطال آخر Render/Export عند التعديل.
  - تصدير ملف MP4 بعد Render موثق مع ZIP للمصدر. قُيّد مصدر المخرج بمجلد المحرك الخاص داخل `.kelivo/engine-output/<engineId>/`، ويُعاد التحقق من عدم وجود symlink ووجود ملف غير فارغ؛ لا يفحص ذلك سلامة الحاوية أو codecs حتى Phase 11.
- `lib/core/services/video_production/video_production_tools.dart`
  - JSON Schema لأداة المحادثة `video_production`.
- أضيفت الأداة إلى `ToolHandlerService`، و`BuiltInToolNames`، وWorkspace Tool UI، وCI test manifest.
- أضيفت اختبارات عقد المواصفات والمشاهد ومسارات المصدر في `test/core/services/video_production/video_production_spec_test.dart`، واختبار حجز الأداة في `built_in_tool_names_test.dart`، واختبار بطاقة Workspace في `workspace_tool_ui_test.dart`.

## Approval and execution boundaries

- `plan` و`status` عمليات قراءة/تحقق فقط.
- `create`, `update`, `render`, `export` تحتاج موافقة صريحة.
- لا تُشغّل كتابة ملفات المصدر أي script.
- `render` يمر عبر Phase 7 adapter ويتطلب Preflight ناجحاً وموافقة التنفيذ.
- لا يتم تثبيت Skills أو Packages تلقائياً؛ يمكن استخدام Package Manager كعملية منفصلة بموافقة المستخدم.

## Validation performed in this packaging environment

- تمت مراجعة مسارات الاستدعاء وربط الأداة في أداة المحادثة وأسماء الأدوات المحجوزة وواجهة Workspace.
- أُضيف منع التصيير/التصدير عند غياب source files أو scene assets، وحُصر مسار مخرج المحرك في مجلد محركه المسجل.
- اجتاز تدقيق Android-only الذي يتحقق من نطاق ARM64 وملفات PRoot و29 ملف اختبار مركّزاً و6 اختبارات واجهة مسماة.
- تمت إضافة اختبارات مركزة إلى Android CI manifest.
- تم فحص ملفات التعديل وYAML/Bash بشكل ثابت عند إعداد الحزمة.
- لم يتوفر Dart/Flutter SDK في بيئة التغليف؛ لذلك لم يتم تشغيل `dart format` أو `dart analyze` أو `flutter test` أو بناء APK. لا تُسجل أي من هذه البوابات كناجحة.

## Known limitations

- الحزمة الحالية تنقل ملفات مصدر نصية فقط؛ رفع الصور/الصوت/الفيديو كأصول ثنائية وربطها بالمشاهد يأتي لاحقاً.
- لا توجد معاينات قصيرة أو تقارير تقدم الإطارات؛ عقد Phase 7 لا يوفر بعد preview/progress APIs.
- لا يوجد تصيير جزئي للمشهد؛ update يحدّث المشروع ويستوجب إعادة التصيير بحسب قدرة المحرك.
- لا يتم تنفيذ Skills تلقائياً بسبب فجوة Phase 4 السابقة، ولا تثبيت تبعيات دون استخدام أداة Package Manager بموافقة مستقلة.
- تحقق MP4 يكتفي حالياً بملف غير فارغ وفق Phase 7؛ فحص codec ومدة الفيديو والصوت/الصورة مؤجل إلى Phase 11.
- Phase 7 ما زالت غير معتمدة رسمياً حتى CI وبناء ARM64 وإثبات Render وإزالة المحرك على الهاتف. بدء أساس Phase 8 جاء بتوجيه مباشر من المستخدم ولا يغيّر حالة قبول Phase 7.

## Acceptance

- [x] Engine-neutral Production Spec and Storyboard contracts.
- [x] Workspace project create/update/status operations.
- [x] Source path/size validation, hidden-path rejection, aspect-ratio consistency and overwrite backups.
- [x] Render/export preflight for missing project assets and engine-output path containment.
- [x] Phase 7 engine render delegation with explicit tool approval.
- [x] MP4 and source ZIP export after a verified render.
- [ ] Dart analysis and focused Phase 8 tests pass in GitHub Actions.
- [ ] Android ARM64 Release build passes.
- [ ] Real phone workflow from prompt to MP4/source passes.
- [ ] Partial scene update/re-render passes with an engine that supports it.

**Status:** Initial Phase 8 foundation implemented; formal acceptance pending CI and on-device integration validation.
