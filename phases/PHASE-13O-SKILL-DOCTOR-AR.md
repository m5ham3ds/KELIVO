# PHASE13O — Skill Doctor & Evidence-Based Diagnostics

## الهدف

إضافة مركز تشخيص عام (generic) وموحد داخل KELIVO يفحص المهارات المثبتة وملفات الاستيراد والاعتماديات وملفات Runtime Profiles والقدرات وسجل عمليات التشغيل، مع بقائه عاماً لكل أنواع المهارات. لا توجد أي قائمة مسموحة بأسماء المهارات، ولا تعتمد قواعد الفحص على المهارات الست المستخدمة سابقاً في اختبارات إنتاج الفيديو.

يعتمد Skill Doctor على سجلات Skill Import Manifest وRequirement Inventory وRuntime Profiles وSkill Capability Registry وSkill Readiness الموجودة بالفعل؛ ولا ينشئ سجلاً موازياً أو يعيد تحليل الملفات بطريقة تغيّر مصدر المهارة.

## ما أضيف

### 1. فحص سلامة حزمة المهارة

- التحقق من وجود مجلد المهارة وملف `SKILL.md` وبيان الاستيراد.
- مقارنة كل ملف مسجل بالحجم وبصمة SHA-256 الفعلية.
- إعادة حساب `sourceDigest` وفق الترتيب القانوني نفسه المستخدم عند الاستيراد.
- فحص الموارد المشتركة الموجودة تحت مجلد repository shared resource باستخدام `sourcePath` الموثق.
- كشف الملفات المفقودة أو المعدلة أو غير المسجلة، والمسارات غير الآمنة والروابط الرمزية داخل مجلد المهارة. ويستمر في إظهار الملفات غير المسجلة حتى عند وجود ملفات معدلة أو مفقودة في الفحص نفسه.
- تحديد سقوف للفحص: 8,192 ملفاً، و500 MiB إجمالاً، و200 MiB للملف الواحد. عند تجاوز السقف يعاد `inconclusive` بدلاً من إعلان السلامة.

### 2. فحص Runtime Profiles

- مطابقة `scope=extension` و`ownerId` مع معرف المهارة.
- كشف Profile اليتيم الذي لا تملك مهارته موجودة.
- كشف Profile المفقود أو غير الجاهز أو الذي لا يضم البيئات المطلوبة.
- كشف تعدد ملفات Profile وعدم وجود اختيار صريح.
- التحقق من حالة محرك Android PRoot، مع التذكير بأن PRoot ليس عزلاً أمنياً على مستوى Kernel.
- استعراض أحدث 50 نتيجة من سجلات التشغيل التي انتهت بفشل أو انقطاع أو مهلة زمنية، مع إخفاء نص الخطأ الخام لتقليل احتمال عرض بيانات حساسة؛ ويُشار إلى وجود سجل أطول.

### 3. فحص الأوامر والاعتماديات

أضيف `RuntimeProfileService.inspectSkillProfileCommands`، وتظهر أسماء الأوامر غير الآمنة كتحذير أمني ولا تُمرر إلى الصدفة لفحص أسماء أوامر تم التحقق من صحتها فقط داخل PATH الخاص بالـProfile المملوك للمهارة. الفحص محدود إلى 64 اسماً، ومهلة بحد أقصى 30 ثانية، ومخرجات بحد 16 KiB، ويستخدم builtin `command -v` فقط.

يصنف الأمر الذي وجد داخل مجلد Python/Node الخاص بالـProfile على أنه Profile-level؛ أما الأمر الذي وجد في `/usr/bin` أو `/bin` فيصنف على أنه من RootFS المشترك، ولا يحتسب دليلاً على عزل الحزمة.

لا يشغل الفحص سكريبت المهارة أو lifecycle hooks أو مديري الحزم، ولا يثبت أو يحدّث أية مكتبة. أسماء الحزم تظل غير مثبتة إلى أن يقدم مدير الحزم أو Adapter دليلاً خاصاً بها.

### 4. التهيئة والأسرار والقدرات

- فحص وجود اسم متغير البيئة المطلوب فقط، دون قراءة قيمة السر أو تمريرها إلى المهارة.
- وجود متغير باسم API في إعدادات KELIVO لا يعني أن المهارة حصلت على منحة سرية scoped؛ لذلك يبقى التهيئة غير مكتملة للتنفيذ.
- لا يعيد استخدام نتائج فحص أوامر محفوظة من تشغيل سابق، كما يستبعد التحقق السابق من Runtime Profile عند حساب الجاهزية التشخيصية.
- الاعتماد على Capability Registry العام لتصنيف Python وShell وNode وCLI وMCP وHTTP وWorkflow وNative Tools.
- وجود تعريف MCP/API/Workflow لا يثبت أن Adapter أو مشغّلها متوفر؛ يعرض Doctor الحالة كما هي.

### 5. عدم رفع مستوى الجاهزية بالتخمين

يستخدم Doctor محرك `SkillReadinessEngine` القائم، لكنه لا ينشئ Validation Evidence جديداً. كما أنه يستبعد `runtimeProfileVerification` المحفوظ من تقييم Doctor دائماً؛ فقد يكون قديماً، ولا تكفي نتيجة `command -v` لإثبات نجاح القدرة. كما يمسح حالات الأوامر القديمة قبل بدء الفحص، ولا يستخدم إلا نتائج الفحص الحالي. لا تتحول نتيجة فحص `command -v` وحدها إلى إثبات نجاح قدرة أو إنتاج ملف.

### 6. واجهة Skill Doctor

أضيفت صفحة عربية/إنجليزية يمكن فتحها من:

- شريط أدوات صفحة Skills على Android والواجهات العريضة.
- قسم Skill diagnostics في إعدادات مساحة العمل على الهاتف.

تعرض الصفحة حالة المحرك وRootFS وملخص المهارات والمشكلات الحرجة والتحذيرات، ثم تفاصيل كل مهارة وبصمة الملفات وحالة Profile ونتائج فحص الأوامر ومصدر الدليل والإجراء المقترح.

## حدود الأمان الصريحة

Skill Doctor تشخيصي للقراءة فقط. لا يشغل سكريبتات المهارات أو مديري الحزم أو خوادم MCP، ولا يتصل بخدمات API، ولا يقرأ قيم الأسرار ولا يصلح الملفات آلياً. فحص الأمر هو تشغيل قصير لـ`command -v` داخل Profile، وليس اختبار تشغيل وظيفة المهارة.

PRoot يظل حداً تشغيلياً Best-effort وليس عزل Kernel؛ لذلك لا يقدم Doctor وصفاً مضللاً بأن فحصه يثبت عزلاً أمنياً كاملاً.

## الاختبارات وربط CI

أضيفت اختبارات لسياسة الاحتياج إلى Runtime Profile، واستنتاج بيئات Python/Node/Shell من نقاط الدخول المعلنة، وعدم افتراض بيئات لـMCP/HTTP، وارتباط فحص الأوامر بمالك Profile الصحيح، ورفض أسماء الأوامر غير الآمنة، وتصنيف نتائج Profile مقابل RootFS.

أضيف إلى GitHub Actions بعد PHASE13N وقبل فحوص التوطين:

1. `phase13o_syntax_preflight`
2. `phase13o_ci_self_test`
3. `phase13o_preflight`
4. `phase13o_tests`

يشمل المشغل اختبارات Skill Doctor policy وSkill readiness وSkill import manifest وRuntime Profile service. لم تتم إعادة تشغيل مجموعات الاختبارات التاريخية 13A–13D.

## ما لم يُثبت بعد

بيئة التحرير لا تحتوي على Flutter أو Dart أو Gradle، ولذلك لم تُنفذ اختبارات Flutter/Dart فعلياً ولا Android Robolectric ولا بناء APK ولا تجربة على جهاز فعلي. خطوات هذه الاختبارات مرتبطة بـGitHub Actions، ويجب انتظار سجل CI حقيقي قبل اعتبارها ناجحة أو اعتماد المرحلة نهائياً.

كما أن PHASE13O لا تنشئ بعد موائمات تشغيل جديدة لـMCP أو HTTP API أو CLI formats أو Workflow؛ وظيفتها تشخيص ما يدعمه التطبيق وما ينقصه، لا الادعاء بدعم تنفيذي غير موجود.

## CI test scope and recovery mode

The Android workflow supports two manual Phase 13 test scopes:

- `full` (default): runs the focused PHASE13E–PHASE13P regression lanes.
- `skill_doctor_recovery`: skips PHASE13E–PHASE13N only when those lanes passed on the parent commit and the current changes are isolated to the PHASE13O Skill Doctor repair. It still runs PHASE13O and PHASE13P diagnostics, Android prerequisite setup and the normal success-gated release build.

Push and pull-request runs default to `full`. Do not use recovery mode after changes to shared execution, Runtime Profile, import, permission, package, background-service or CI infrastructure files. Historical PHASE13A–PHASE13D test suites remain excluded by the established project decision; their test files are not deleted.

## نطاق اختبارات CI ووضع الاسترداد

يدعم Workflow خيارين لنطاق اختبارات PHASE13:

- `full` (الافتراضي): تشغيل مجموعات الانحدار المركزة من PHASE13E إلى PHASE13P. ويُستخدم تلقائياً في Push وPull Request، وكذلك عند التشغيل اليدوي ما لم يُغيّر الاختيار.
- `skill_doctor_recovery`: خيار يدوي لإصلاح معزول في PHASE13O فقط. يتخطى مجموعات PHASE13E–13N عندما تكون قد اجتازت الاختبارات على Commit الأب ولا تشمل التغييرات تعديلات على المحرك المشترك أو Runtime Profiles أو الاستيراد أو الصلاحيات أو الحزم أو الخدمات الخلفية. ويستمر في تشغيل PHASE13O وPHASE13P وإعداد متطلبات اختبارات Flutter، مع إبقاء بناء APK مشروطاً بنجاح جميع البوابات المطلوبة.

في وضع `full`، تستمر مجموعات PHASE13E–13P التشخيصية بصورة مستقلة بعد فشل مجموعة سابقة، ما دامت تبعيات Flutter وLinux المطلوبة جاهزة؛ وهذا يساعد على جمع أكثر من عطل في تشغيل واحد. أما بناء APK والتغليف والرفع فتظل متوقفة عند وجود أي فشل. لا تُحذف ملفات الاختبارات التاريخية PHASE13A–13D؛ يظل عدم تكرارها قراراً منفصلاً كما كان سابقاً.
