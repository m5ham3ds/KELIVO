# PHASE 13K.5 — إصلاح ربط أدلة CLI والـ Runtime العام للمهارات

## ملخص التنفيذ

أُعد هذا الإصلاح استجابة لفشل GitHub Actions في التشغيل `43782785649`، على commit `56f6a367424c5d4f800eb687b6046b1ebe721d9b` بتاريخ 16 نوفمبر 2026.

نجحت اختبارات Phase 13E و13F و13G و13H و13I و13J في ذلك التشغيل. وصل CI إلى اختبارات Phase 13K الفعلية، وفشل في ثلاثة اختبارات من `skill_readiness_phase13k_test.dart`. لم يصل التشغيل إلى اختبارات Android الأصلية أو بناء APK لأن بوابة 13K أوقفت المسار.

## 1. الأخطاء التي ظهرت في التقرير

### أ. أمر CLI موجود في PRoot الأساسي لم يُكتشف ضمن أدلة القدرة

الاختبار:
`a CLI found in the base PRoot is not treated as profile-ready`

النتيجة المتوقعة:
`detected_in_base_environment_only`

النتيجة الفعلية:
`environment_not_verified`

كان سجل الأوامر يحتوي `ffmpeg`، كما أن `entryPoints` للقدرة `cli_binary` احتوى `ffmpeg`. لكن المطابقة السابقة كانت تستنتج الأمر المرتبط من امتداد ملف فقط (`.py` و`.sh` و`.js`)؛ ولم تطابق اسم أداة CLI نفسه مع سجل الأوامر. لذلك أصبحت قائمة `relatedCommands` فارغة رغم وجود الدليل.

### ب. تصريح local_script عام بلا entryPoints صُنّف كقدرة مجهولة

الاختبار:
`executable Skill requires an explicit passed validation record`

النتيجة المتوقعة دون سجل تحقق:
`dependencies_pending`

النتيجة الفعلية:
`unsupported_environment`

القدرة `local_script` كانت معلنة، لكن فهرسها لا يحتوي نقطة دخول أو امتداداً يسمح بتحديد Python أو Shell أو Node. لم يكن سجل القدرات يحتوي وصفاً عاماً لـ local scripts، فاعتبر عدم وجود descriptor قدرة مجهولة. الصحيح أن نوع القدرة معروف (سكريبت محلي) لكن Runtime الدقيق لم يُحدد بعد؛ لذلك يجب أن تبقى مشروطة بملف Runtime Profile والموافقة، لا مجهولة ولا جاهزة.

### ج. مهارة ذات Runtime Profile واختبار ناجح لم تصل إلى Ready

الاختبار:
`fully ready requires verified runtime profile plus passed self-test evidence`

النتيجة المتوقعة:
`ready`

النتيجة الفعلية:
`unsupported_environment`

هذا كان أثراً متسلسلاً للسبب السابق: تصريح `local_script` العام بلا `entryPoints` أنتج قدرة مجهولة، فحجبت الجاهزية رغم وجود أمر Python موثق داخل ملف التشغيل وسجل Runtime Profile صالح ونتيجة اختبار ناجحة.

## 2. الإصلاحات المنفذة

### Capability Registry

- إضافة قدرة عامة مستقلة `agent_skill.local_scripts`.
- وصفها بأنها `implemented_conditional`؛ فهي تعرف أن هناك سكريبتاً محلياً، لكنها لا تدّعي معرفة Runtime أو جاهزيته.
- عند وجود `entryPoints` معروفة الامتداد، يستمر اختيار قدرات Python أو Bash/Shell أو Node المحددة.
- عند وجود امتداد غير معروف، تظل نقطة الدخول `unknown` وتُحجب الجاهزية. لم يتم تخفيف سياسة unknown.

### ربط CLI بالأوامر المكتشفة

- مطابقة `entryPoints` في قدرات `cli_binary` مباشرة مع أسماء الأوامر المكتشفة.
- دعم أسماء الأوامر والمسارات المطلقة عبر مطابقة basename، مع توحيد فواصل المسار.
- الدليل الموجود في `base_proot_environment` يُعرض بوضوح كـ `detected_in_base_environment_only` ولا يُعتبر إثباتاً لوجود الأداة داخل Skill Runtime Profile.
- لا تُعتبر أدلة `skill_runtime_profile` موثقة إلا بوجود سجل تحقق ناجح يتضمن `profileId` و`validatedAt`.

## 3. اختبارات الانحدار المضافة أو المقواة

في `test/core/services/skills/skill_readiness_phase13k_test.dart`:

- التحقق من ظهور capability عامة للـ local scripts في التطبيق.
- تقوية اختبار CLI الموجود في PRoot الأساسي ليؤكد أيضاً أن `relatedCommands` يتضمن الأمر المكتشف.
- اختبار مطابقة مسار مثل `/usr/bin/ffmpeg` مع اسم الأمر `ffmpeg`.
- اختبار أن local_script بلا entryPoints يبقى مشروطاً ويتطلب Runtime Profile، ولا يصنف مجهولاً.
- اختبار أن دليل CLI داخل Runtime Profile لا يُقبل من دون هوية Profile ووقت تحقق.

تم ربط هذه الحالات بفحص Phase 13K Preflight وCI Self-Test. ويستمر مشغّل 13K في تشغيل ملف الاختبارات المركّز نفسه.

## 4. الملفات المعدلة

- `lib/core/services/skills/skill_capability_registry.dart`
- `test/core/services/skills/skill_readiness_phase13k_test.dart`
- `.github/scripts/preflight_phase13k_tests.sh`
- `.github/scripts/test_phase13k_ci.sh`
- `phases/PHASE-13-SKILLS-WORKSPACE-ARCHITECTURE-AND-IMPLEMENTATION-PLAN.md`
- `README.md`

## 5. نتائج الفحوص المتاحة في بيئة إعداد الإصلاح

نجحت الفحوص التالية فعلياً محلياً:

- Phase 13K CI Self-Test.
- Phase 13K Static Preflight.
- Android-only Audit، بما يتضمن بوابات 13H و13I و13J و13K.
- Release Hardening Audit.
- فحوص Bash وYAML المضمنة في هذه البوابات.

لم تكن أدوات Flutter وDart وGradle متاحة في بيئة إعداد الإصلاح، لذلك لم يتم تشغيل Flutter Widget/Unit Tests أو Dart Analysis أو بناء APK بعد هذا التغيير. كما أن الفشل السابق لم يكن قد وصل إلى Android Tests أو APK.

## 6. حدود الإصلاح

- لم يتم تثبيت أي أداة أو مكتبة.
- لم يتم تشغيل سكريبتات Skills.
- لم تتم إضافة محركات أو مزودات أو موائمات جديدة.
- لم يتم تعديل محتوى المهارات الأصلية أو Skill Packs.
- لم يتم تغيير قواعد الموافقة أو عزل التشغيل.
- لا تُعاد اختبارات 13A–13D.

## 7. المطلوب لاعتماد الإصلاح

ارفع محتويات مجلد `KELIVO/` إلى جذر مستودع `m5ham3ds/KELIVO` وشغّل GitHub Actions.

يجب تأكيد:
1. نجاح اختبارات Phase 13K الثلاثة التي فشلت سابقاً.
2. نجاح ملف اختبارات Phase 13K كاملاً.
3. نجاح اختبارات Android الخلفية والإشعارات.
4. نجاح بناء ARM64 وإنتاج APK غير فارغ.

لا تعتبر PHASE13K معتمدة نهائياً قبل نجاح اختبارات Flutter وبناء APK الفعليين.
