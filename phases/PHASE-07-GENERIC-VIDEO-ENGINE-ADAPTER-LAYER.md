# PHASE 7 — Generic Video Engine Adapter Layer

## الهدف

تمكين Kelivo من تثبيت محركات إنتاج الفيديو كإضافات اختيارية داخل مساحة المشروع، ثم فحص توافقها واستدعاء واجهات CLI موحدة منها عبر المحادثة، دون ربط النواة بمحرك محدد أو إدراج محرك فيديو في APK.

هذه الطبقة هي عقد تكامل فقط. لا تعني أن كل محرك معلن متوافق مع Android، ولا أن تثبيته يكفي لإنتاج فيديو. لا يُعد المحرك مجرّباً أو مدعوماً إلا بعد نجاح Render فعلي على بيئة Android ARM64/PRoot.

## عقد الإضافة `kelivo.engine.yaml`

يحتوي جذر حزمة المحرك على `kelivo.engine.yaml` بإصدار مخطط `schemaVersion: 1`، ويعرّف:

- `id`, `name`, `version`, `description`.
- `compatibility.platforms` و`compatibility.architectures`؛ القيم المدعومة حالياً Android/All وARM64/All.
- `runtime.ecosystems`؛ اختيارياً `node` و/أو `python` لطلب Runtime Profile مشروع متوافق.
- `dependencies.commands`؛ أوامر النظام التي يجب اكتشافها على PATH قبل التنفيذ.
- `commands.version` اختيارياً، و`preflight`, `create`, `render`, `inspect`, `cancel` كأوامر مطلوبة.
- `outputExtension` بامتداد قصير آمن، والافتراضي `mp4`.
- `capabilities.sceneRendering` و`capabilities.hybridAssembly` و`capabilities.acceptsMp4Assets` كقيم Boolean اختيارية؛ جميعها `false` افتراضياً. لا تُقبل قدرة `hybridAssembly: true` ما لم يعلن المحرك أيضاً `acceptsMp4Assets: true`.

كل أمر يحدد `executable` و`args` منفصلين. لا يقبل محلل البيان shell expressions أو مسارات تنفيذ مطلقة/متجاوزة لجذر المحرك أو placeholders غير معروفة. تُستبدل placeholders المصرح بها داخل كل argument فقط:

- `{{workspace}}`
- `{{project_dir}}`
- `{{project_name}}`
- `{{output_path}}`
- `{{output_dir}}`
- `{{engine_root}}`
- `{{run_id}}`

كل executable وكل argument يُمرر إلى Shell بعد quoting مستقل؛ لا تُركّب arguments في نص command من مدخلات المستخدم.

## مثال توضيحي لعقد محرك

المثال التالي يوضح شكل العقد فقط؛ ليس محركاً مضمناً ولا حزمة قابلة للتصوير بذاتها:

```yaml
schemaVersion: 1
id: sample-motion-cli
name: Sample Motion CLI
version: 1.0.0
description: Example manifest for an optional Node-based renderer.
compatibility:
  platforms: [android]
  architectures: [arm64-v8a, aarch64]
runtime:
  ecosystems: [node]
dependencies:
  commands: [node, ffmpeg]
commands:
  version:
    executable: node
    args: [--version]
  preflight:
    executable: node
    args: ["{{engine_root}}/scripts/preflight.js"]
  create:
    executable: node
    args: ["{{engine_root}}/scripts/create.js", "{{project_dir}}", "{{project_name}}"]
  render:
    executable: node
    args: ["{{engine_root}}/scripts/render.js", "{{project_dir}}", "{{output_path}}"]
  inspect:
    executable: node
    args: ["{{engine_root}}/scripts/inspect.js", "{{project_dir}}"]
  cancel:
    executable: node
    args: ["{{engine_root}}/scripts/cancel.js", "{{run_id}}"]
outputExtension: mp4
```

إذا أعلن المحرك عن `runtime.ecosystems: [node]` أو `[python]` فيلزم اختيار Runtime Profile مشروع يدعم تلك البيئة. أما `dependencies.commands` فيكتشف وجود الأوامر ولا يثبتها تلقائياً.

## التثبيت والتخزين

1. يقبل المصدر رابط GitHub عامّاً مدعوماً بواسطة GitHub repository/tree reference، أو مجلداً/ZIP محلياً ضمن Workspace الحالي.
2. تُنسخ الحزمة إلى مجلد staging مؤقت داخل `.kelivo/engine-staging/`.
3. يرفض الاستخراج مسارات zip traversal، والتكرار، والروابط الرمزية، والأرشيفات/الحزم التي تتجاوز حدود الحجم أو عدد الملفات.
4. يُقرأ البيان ويُتحقق منه دون تشغيل أي سكربت أو تثبيت أي dependency.
5. تُحفظ الحزمة النهائية في `.kelivo/engines/<engine-id>/`، وتسجل بياناتها في `ExtensionRegistryRepository` مع ربطها بمعرّف Workspace.
6. الإزالة تحذف ملفات المحرك وسجله وإعداداته الخاصة بالمشروع، ولا تحذف ملفات المشروع أو Skills أو محركات Workspace آخر.

دعم تنزيل GitHub في هذه الدفعة للمستودعات العامة فقط. لا تُخزن رموز وصول GitHub داخل البيان أو سجل الإضافة.

## دورة الحياة عبر المحادثة

الأداة الوحيدة هي `video_engine`، وتدعم:

- `list`, `inspect`: عرض المحركات المثبتة وبيانات عقدها وحالتها.
- `install`, `remove`: تثبيت الحزمة وإزالتها.
- `preflight`: اكتشاف معمارية PRoot، وفحص Android/ARM64، والتبعيات المطلوبة، وRuntime Profile، ثم تشغيل أوامر version/preflight بعد موافقة المستخدم.
- `set_default`, `clear_default`: اختيار المحرك الافتراضي للمشروع أو إلغاء الاختيار.
- `configure`: تخزين إعدادات نصية غير سرية على مستوى المشروع وتمريرها إلى أوامر المحرك كمتغيرات `KELIVO_ENGINE_SETTING_*`.
- `create`, `render`, `inspect_project`, `cancel`: تنفيذ أوامر المحرك عبر `WorkspaceRuntime` مع Run ID وtimeout وسجل Runtime Profile عند استخدامه.

تطلب كل عملية تغيّر حالة أو تشغّل كود المحرك موافقة المستخدم. لا تنفذ مرحلة التثبيت سكربتات الحزمة، ولا يثبت النظام تبعياتها تلقائياً. إذا غابت تبعية، يعرض Preflight النقص بدلاً من إجراء تثبيت صامت.

## قدرات Phase 10 الاختيارية

- `sceneRendering: true`: يلتزم المحرك بقراءة مشروع Kelivo مرحلي يحتوي مشهداً إنتاجياً واحداً فقط وإخراج MP4 لهذا المشهد.
- `hybridAssembly: true`: يلتزم المحرك بقراءة مشروع Kelivo كاملاً مع أصول MP4 مرتبطة بكل مشهد وتجميعه في MP4 نهائي.
- `acceptsMp4Assets: true`: يلتزم المحرك باستهلاك أصول MP4 المحلية داخل `scene.assetPaths` كمدخلات للمشهد/التجميع.
- هذه الإعلانات تعاقدية ولا تثبت الجودة أو التوافق التشغيلي؛ لا تُقبل إلا بعد اختبار Render فعلي. انظر [Phase 10](PHASE-10-HYBRID-WORKFLOW-COMPOSER.md).

## حالات التوافق والدعم

- `installed`: الحزمة مثبتة فقط؛ لم يُثبت توافقها بالتنفيذ.
- `preflightPassed`: أوامر ومتطلبات المحرك اجتازت الفحص المسبق، لكن هذا لا يثبت نجاح التصيير.
- `renderVerified`: لا يصبح true إلا بعد نجاح أمر Render وخروج ملف غير فارغ داخل مجلد مخرجات Workspace.
- لا يختار النظام محركاً افتراضياً قبل نجاح Preflight.
- لا يُعلن دعم المنتج لمحرك قبل نجاح Render فعلي على جهاز Android ARM64/PRoot.

فحص الملف الحالي للتحقق من Render يثبت وجود ملف غير فارغ ومساره داخل Workspace؛ لا ينفذ حتى الآن فحصاً معيارياً كاملاً لترميز الفيديو أو سلامة الصورة والصوت بواسطة ffprobe. يبقى ذلك ضمن Phase 11/اختبارات المحرك.

## حدود الأمان والتشغيل

- PRoot وRuntime Profiles يقدمان عزل مسارات/تبعيات منطقياً ولا يشكلان kernel sandbox أو حاجزاً أمنياً قوياً. أوامر المحرك المعتمدة من المستخدم قد تصل إلى ما تسمح به بيئة PRoot.
- تنزيل الحزمة وفحصها لا ينفذان محتواها؛ لكن `preflight/create/render/inspect/cancel` ينفذون أوامر يعرّفها ناشر المحرك بعد موافقة المستخدم.
- لا تُمرر الأسرار ضمن Engine Settings، وتُرفض أسماء الإعدادات التي تشير إلى token/secret/password/credential/authorization/API key. هذه الإعدادات النصية ليست مخزناً للأسرار.
- لا يضمّن APK محركاً أو Node/Python package خاصة بمحرك معين.
- لا يوجد حالياً تشغيل Remote Runtime، ولا PTY/Terminal engine session مستقلة، ولا واجهة تحديث/rollback للمحرك.

## معايير القبول

- [x] بيان موحد بإصدار schema واضح وأوامر CLI محددة.
- [x] تحقق صارم من البيان والأوامر والـ placeholders.
- [x] تثبيت اختياري من GitHub العام أو مجلد/ZIP محلي ضمن Workspace.
- [x] فحص ZIP ضد traversal/الروابط الرمزية/التكرار/الحجم/عدد الملفات.
- [x] تخزين الحزم وسجلاتها وإعداداتها لكل Workspace.
- [x] Preflight للمعمارية والمنصة والتبعيات وRuntime Profile.
- [x] أداة محادثة مع موافقة لكل عملية تنفيذ/تغيير.
- [x] ربط create/render/inspect/cancel بـ Android PRoot وRuntime Profile عند اختياره.
- [x] لا يتحول `renderVerified` إلى true إلا بعد خروج ملف غير فارغ ضمن Workspace.
- [ ] اختيار محرك حقيقي من المستخدم أو مشروع اختبار مستقل، وتثبيته على Android ARM64.
- [ ] نجاح Render فعلي والتحقق من الناتج على الهاتف؛ قبل ذلك لا يُعلن أي محرك مدعوماً.
- [ ] نجاح Android Phase 7 Dart analysis والاختبارات المركزة وبناء ARM64 Release في GitHub Actions.
- [ ] إثبات قدرات `sceneRendering` و`hybridAssembly` و`acceptsMp4Assets` عند اختيار محرك لمرحلة Phase 10، مع اختبار فعلي لكل قدرة مطلوبة.
- [ ] اختبار إزالة محرك دون التأثير على Skills أو مشاريع/Workspaces أخرى.

**الحالة:** طبقة العقد والتثبيت والإدارة والتنفيذ المصدرية جاهزة للمراجعة. المرحلة لم تُقبل بعد؛ اختبار المحرك الحقيقي وCI والهاتف ما زالت بوابات إلزامية. بناءً على توجيه المستخدم يمكن تنفيذ أساسات Phase 8 وPhase 9 وPhase 10 المحايدة للمحرك، لكن التصيير الفعلي واعتماد أي محرك يظلان محجوبين حتى نجاح Render على Android ARM64.

## Advancement note

بناءً على توجيه المستخدم بالانتقال مباشرة إلى المرحلة التالية، بدأت أساسات Phase 8 وPhase 9 وPhase 10 مع إبقاء جميع بوابات قبول Phase 7 غير المنجزة دون تغيير. لا يعني ذلك قبول هذه المرحلة أو إعلان دعم أي محرك؛ اختبار Render الفعلي على Android ARM64/PRoot وCI واختبار الإزالة ما زالت مطلوبة.
