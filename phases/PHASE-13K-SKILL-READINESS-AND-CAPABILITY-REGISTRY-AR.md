# PHASE 13K — محرك جاهزية المهارات وسجل قدرات KELIVO

## الهدف

تحويل تقرير متطلبات PHASE13J من قائمة اكتشاف فقط إلى نظام يحدد بوضوح ما إذا كانت المهارة مثبتة أو محللة أو قابلة للتجهيز أو مهيأة أو مختبرة أو جاهزة فعلياً. وبالتوازي، توفير سجل مركزي لقدرات التطبيق نفسه، مستقل عن المهارات وSkill Packs المثبتة.

**القاعدة الأساسية:** تثبيت Skill أو نجاح تحليل ملفاتها لا يساوي جاهزيتها للتنفيذ. ولا يجوز أن تضيف ملفات Skill قدرة أصلية إلى تطبيق KELIVO بمجرد إعلانها عنها.

## 1. Skill Readiness Engine

أُضيف `lib/core/services/skills/skill_readiness.dart` ليحسب حالة الجاهزية من بيانات الاستيراد والمتطلبات وأدلة التحقق.

### مراحل الجاهزية

1. `installed` — ملفات المهارة وسجل الاستيراد كاملان.
2. `analyzed` — تم إنشاء فهرس متطلبات صالح.
3. `dependenciesResolved` — تم التحقق من الحزم والأوامر داخل ملف تشغيل المهارة نفسه.
4. `configured` — أسماء الإعدادات المطلوبة موجودة وتم التحقق من الخدمات الخارجية عبر مسار موثوق.
5. `validated` — يوجد سجل اختبار خاص بالمهارة ناجح، مع وقت تحقق وأدلة.
6. `ready` — لا تُمنح إلا بعد اجتياز جميع البوابات السابقة.

### حالات الجاهزية

- `blocked_incomplete_import`
- `analysis_required`
- `requirements_missing`
- `unsupported_environment`
- `dependencies_pending`
- `configuration_required`
- `validation_required`
- `ready_for_instructions`
- `ready`

`ready_for_instructions` يسمح للمساعد باستخدام تعليمات `SKILL.md` النصية فقط، ولا يعني أن سكريبتات المهارة أو الأدوات الخارجية قابلة للتنفيذ.

### قواعد منع الجاهزية الزائفة

- وجود الأمر في PRoot الأساسي لا يثبت وجوده داخل Skill Runtime Profile.
- وجود اسم حزمة في manifest لا يثبت تثبيتها أو توافق إصدارها.
- وجود اسم متغير API في الإعداد لا يثبت صلاحية قيمة السر؛ ولا تُقرأ القيم أو تُسجل.
- وجود موصف MCP أو HTTP API أو Workflow لا يعني أنه تم تسجيله أو تشغيله.
- القدرة غير المصنفة في سجل KELIVO تُعامل كغير مدعومة حتى يضاف لها عقد صريح.
- لا تكفي نتيجة validation وحدها لتجاوز نقص ملف التشغيل أو الإعداد أو الاعتماديات.

## 2. Capability Registry — سجل قدرات التطبيق

أُضيف `lib/core/services/skills/skill_capability_registry.dart` بسجل مركزي معرفه `kelivo.skill-capabilities` ومستقل عن قائمة Skills.

يشمل السجل حالياً:

- تعليمات Agent Skills النصية.
- سكريبتات Python.
- سكريبتات Bash/Shell.
- سكريبتات Node.js.
- أدوات CLI التابعة للمهارات.
- خوادم MCP التي تصرح بها المهارات.
- موائمات HTTP/API.
- تعريفات Workflow.
- الأدوات الأصلية التي تتطلب تطويراً داخل KELIVO.

ويصنف كل قدرة بحسب مستوى التنفيذ: مدمجة، مدمجة بشروط، تعتمد على البيئة، تحتاج موائماً يدوياً، تحتاج تطوير موائم، أو تتطلب تطويراً داخل KELIVO. سجل المهارات لا يستطيع إضافة قدرة أصلية للتطبيق.

## 3. واجهة المستخدم

أُضيف قسم **جاهزية المهارة وقدرات KELIVO** في صفحة تفاصيل كل Skill، ويعرض:

- الحالة الحالية للجاهزية.
- تقدم المراحل الخمس.
- الخطوات التالية المطلوبة.
- زر فحص الجاهزية الآن.
- تقرير الجاهزية الكامل.
- زر مستقل لعرض سجل قدرات KELIVO العام مع تعريف مستوى دعم كل قدرة.

لا يُخفي التقرير الفجوات أو يحول حالة غير معروفة إلى نجاح.

## 4. حفظ الأدلة ومنع استخدام تقارير قديمة

يُحفظ تقييم البيئة في sidecar استيراد المهارة تحت `environmentAssessment`، ويرتبط ببصمة `sourceDigest` للمهارة. عند تغير ملفات المهارة أو إعادة بناء فهرس متطلباتها، يتم حذف التقييم القديم حتى لا تستمر حالة Ready بعد تغير المحتوى.

يعرض Skill Composition `selectedSkillRequirements` و`selectedSkillReadiness` وسجل قدرات التطبيق. ويصرح دائماً بأن التقييم المحفوظ لقطة سابقة لا تغني عن `extension_inspect` حديث قبل الاعتماد على القدرة التنفيذية.

## 5. سلوك المساعد

تم تحديث تعليمات المساعد لتُلزمه بما يلي:

- التمييز بين الإرشادات النصية والتنفيذ الحقيقي.
- مراجعة متطلبات كل Skill مختارة.
- عدم وصف المهارة بأنها جاهزة بالكامل دون `readinessState=ready` وسجل validation ناجح.
- شرح المتطلبات المفقودة أو موائمات KELIVO اللازمة بدلاً من محاولة تخمين أداة غير موجودة.
- الحفاظ على استقلال المهارات الأصلية عن Skill Packs.

## 6. حدود النطاق والسلامة

PHASE13K لا تثبّت حزمًا، ولا تشغل سكريبتات مهارات، ولا تبدأ خوادم MCP، ولا تتصل بمزودي API أثناء الفحص. لا يُضاف محرك جديد ولا يُعدل محتوى المهارات الأصلية. تبقى عمليات الإعداد والتثبيت والاتصال مرحلة منفصلة تتطلب طلب المستخدم والموافقة المناسبة.

هذه المرحلة توفر محرك تقييم وسياسة جاهزية وسجل قدرات؛ لا تدّعي أنها أنشأت بعد جميع Skill Runtime Profiles أو مشغلات MCP/Workflow أو اختبارات ذاتية تلقائية لكل مهارة. إذا لم يوجد دليل تحقق صريح، تبقى الحالة معلقة ولا تُمنح Ready.

## 7. الملفات والتكاملات الرئيسية

- `lib/core/services/skills/skill_readiness.dart`
- `lib/core/services/skills/skill_capability_registry.dart`
- `lib/core/services/skills/skill_requirements.dart`
- `lib/core/services/skills/skills_service.dart`
- `lib/core/services/skills/skill_composition_service.dart`
- `lib/core/services/skills/skills_prompt.dart`
- `lib/core/services/extensions/conversational_extension_service.dart`
- `lib/features/workspace/widgets/skills/skill_detail.dart`
- `lib/features/workspace/widgets/skills/skill_import.dart`

## 8. الاختبارات ونتائج التحقق

أُضيفت اختبارات مركزة لـ:

- استقلال Capability Registry عن Skills المثبتة.
- مطابقة Python/Shell/Node وMCP وHTTP وWorkflow وNative capabilities.
- عدم اعتبار أوامر PRoot الأساسية دليلاً على ملف تشغيل المهارة.
- حجب المهارات ذات الاستيراد غير المكتمل.
- تمييز instruction-only عن الجاهزية التنفيذية.
- حجب المتطلبات المفقودة والموائمات غير المدعومة والقدرات المجهولة.
- اشتراط هوية ملف التشغيل ووقت التحقق.
- اشتراط سجل اختبار ناجح قبل Ready.
- رفض لقطة جاهزية قديمة عند اختلاف source digest.
- حفظ التقييم واستبعاده بعد تغير بصمة المصدر.
- تعليمات المساعد وواجهة سجل القدرات.

تم توصيل الاختبارات المركزة إلى GitHub Actions عبر:

- `.github/scripts/preflight_phase13k_tests.sh`
- `.github/scripts/test_phase13k_ci.sh`
- `.github/scripts/run_phase13k_tests.sh`

نجحت 23 assertions بنيوية محلية، وPhase 13K CI self-test، وتحليل YAML، كما نجح Android-only Audit وRelease Hardening بعد تحديثهما للتحقق من بوابات 13J و13K. **لم تتوفر Flutter أو Dart أو Gradle محلياً**؛ لذلك لم تُنفذ اختبارات Flutter الفعلية أو Dart analysis أو بناء APK. يجب تأكيدها في GitHub Actions، ثم التحقق من واجهة الجاهزية على Android ARM64 قبل اعتماد المرحلة. لا تُعاد اختبارات 13A–13D.

## 9. قرار القبول

تُقبل PHASE13K بعد نجاح اختبارات Flutter المركزة، وتحليل Dart، وبناء APK ARM64، وتجربة عرض وفحص الجاهزية على هاتف Android. وحتى ذلك الحين تعتبر الشيفرة والفحوص البنيوية جاهزة للمراجعة وCI، وليست المرحلة معتمدة نهائياً.
