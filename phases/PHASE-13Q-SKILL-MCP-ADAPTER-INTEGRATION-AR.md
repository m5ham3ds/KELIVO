# PHASE 13Q — موائم MCP المملوك للمهارات

**الحالة:** 13Q.1 مقبولة سابقاً؛ أضيف تنفيذ 13Q.2 (ملكية metadata، تعطيل افتراضي، وتحقق digest ومخزن أسرار منفصل) على main، وينتظر بوابة CI الجديدة. 13Q.3–13Q.5 ما زالت مفتوحة.

## سبب المرحلة
يكتشف مستورد Skills ملفات MCP ويحفظ metadata، لكن Capability Registry يصنف agent_skill.mcp_server بأنه manual_adapter_required. البنية العامة لـMCP (McpProvider وMcpToolService) لا تربط وحدها خادم Skill بملكية Skill أو بصمة المصدر أو موافقات تشغيله. نجاح 13P لا يختبر MCP؛ بل يغطي دورة Skill script.

## 13Q.1 — ما أُضيف
- محلل Dart read-only لملفات JSON التي تتضمن mcpServers.
- التحقق من أسماء الخوادم، حجم الملف، نوع النقل، الأمر والوسائط.
- يسمح بقيم env الفارغة أو placeholders للمتغيرات، ويحتفظ بأسماء المتغيرات فقط؛ تُرفض القيم الحرفية المحتملة أن تكون أسرارًا.
- يقبل remote HTTPS descriptors فقط، ويرفض user-info وquery وfragment وheaders المضمنة.
- ينتج descriptor يتطلب موافقة يدوية ويعلن executionSupported=false.
- لا يسجل خادمًا ولا يتصل بالشبكة ولا يشغل عملية.

## الأعمال التالية
### 13Q.2 — ملكية الخادم

أضيف checkpoint تنفيذي أولي للبند 13Q.2:

- SkillMcpOwnerRegistry يحفظ سجلات مستقلة في skill-import-metadata/skill-mcp-owners-v1.json، ويربط كل سجل بـSkill ID وsource digest وagent_skill.mcp_server وServer ID.
- التسجيل لا يقبل Skill بلا manifest صالح أو digest حالي مطابق. يتحقق SkillsService من SHA-256 لكل ملف Skill مقابل manifest قبل قبول digest؛ الملفات المضافة/المعدلة/المفقودة أو الروابط الرمزية تجعل البصمة غير صالحة.
- لا تتكرر أسماء خوادم Skill داخل المالك نفسه، وتُسجل مجموعة descriptors كوحدة واحدة حتى لا يبقى جزء منها عند اكتشاف تكرار.
- جميع التسجيلات enabled=false وrequiresManualApproval=true. هذا السجل لا يستدعي McpProvider ولا ينشئ اتصالاً أو عملية.
- SecureSkillMcpSecretStore يستخدم flutter_secure_storage لحفظ قيم المتغيرات تحت مفاتيح مشتقة من هوية Skill/digest/server/variable. لا تقبل إلا أسماء المتغيرات المعلنة؛ registry لا يحفظ إلا الأسماء وليس القيم.
- registrationsForSkill وallCurrentRegistrations يزيلان السجلات ذات source digest القديم قبل إرجاعها. الإلغاء التشغيلي للاتصال ما زال ضمن 13Q.5.

واجهة التسجيل الحالية: SkillsService.registerDeclaredSkillMcpConfig(skillId, configPath)؛ تقرأ الملف من Skill المثبت فقط، وتطلب وجود capability معلنة في manifest، وتتحقق من المسار ونوع الملف قبل parsing. لا يوجد تشغيل تلقائي.

حدود هذا checkpoint: لم تُربط التسجيلات بعد بدورة MCP connect/tools/list/tools/call، ولم تضف هذه الخطوة واجهة موافقة أو إدخال أسرار. الكتابة إلى مخزن الأسرار تتطلب استدعاءً منفصلاً من واجهة موافق عليها لاحقاً. لا تعتبر 13Q.2 مقبولة نهائياً قبل CI واختبارات التكامل.

ربط server بـSkill ID وsource digest وcapability ID؛ إنشاء الخادم disabled افتراضيًا؛ رفض التكرار والبصمات القديمة؛ ربط الأسرار بمخزن آمن ولا تُستورد القيم الحرفية.

### 13Q.3 — اتصال واكتشاف
تشغيل stdio فقط عبر Workspace/PRoot بعد موافقة واضحة؛ لا يتم ربط مجلد Skills الأصلي القابل للكتابة. مراجعة مسارات الملفات والأوامر. HTTP/SSE يحتاج مراجعة DNS/SSRF وموافقة المضيف؛ HTTPS وحده ليس حماية SSRF كاملة. الاتصال يجب أن يتبعه tools/list بحدود زمنية وحدود لعدد الأدوات وأحجام Schema.

### 13Q.4 — استدعاء الأدوات
الهوية تشمل Skill ID وsource digest وserver ID وtool name. أسماء الأدوات تحمل namespace لتجنب التصادم. موافقة يدوية لكل tools/call حتى عند Full Access. يعاد فحص الملكية والبصمة والـschema قبل وبعد async gaps. حدود للمخرجات وتنقيح للأسرار وسجل تدقيق.

### 13Q.5 — الإلغاء
إيقاف اتصال Skill عند تعطيلها أو حذفها أو تغير بصمتها، ومنع الاتصالات اليتيمة، ثم اختبارات محاكي وجهاز Android.

## الأمان
لا بدء MCP عند import أو inspect أو requirements أو readiness أو compose. لا تنفيذ command/args من بيانات Skill قبل الموافقة والتحقق. لا استيراد env literals أو headers/tokens. PRoot ليس sandbox ولا تقيد شبكة الضيف تلقائيًا. لا يسمح لخادم Skill بالوصول إلى خوادم Skills الأخرى.

## القبول
- نجاح اختبار 13Q.1 والتحليل وAndroid build.
- اختبارات سالبة لـJSON تالف، transport غير مدعوم، اسم/مسار غير صالح، command fragments، args غير صحيحة، secrets literal، URL غير آمن، headers مضمنة.
- إثبات عدم إنشاء أو اتصال أي خادم عند الاستيراد.
- connect بموافقة يدوية مرتبطة بالبصمة.
- tools/list لا يكشف إلا أدوات Skill المملوكة.
- tools/call يحتاج موافقة مرتبطة بهوية Skill/server/tool.
- تغير المصدر أو حذف Skill يبطل الاتصال.
- توثيق اختبار المحاكي وحدود التحقق على الجهاز.

## سجل التحقق — CI #73 (22 نوفمبر 2026)

نجح التشغيل [#73](https://github.com/m5ham3ds/KELIVO/actions/runs/45036728943) على commit `8258af4ce3ed160919416a947abb06059d0e1f0a`.

- اجتازت خطوة `Run Phase 13Q Skill MCP configuration discovery tests` جميع الحالات الثماني: stdio metadata، رفض env literals، رفض shell fragments، التحقق من args/NUL، HTTPS descriptors، رفض credentials/query/fragment، رفض headers، ورفض JSON/path غير الصالح.
- نجح Flutter analysis، واختبارات الحزم المحلية، ومجموعة Android JVM/Robolectric، واختبارات Android integration الأربعة بما فيها Phase 13P Skill lifecycle.
- نجح Android ARM64 Release build ورفع APK.
- لم يشغل هذا CI دورة خادم MCP حقيقية، ولم ينفذ 13Q.2–13Q.5. كما لم يشغّل Flutter root unit/widget suite أو مجموعات 13E–13O التاريخية؛ لا تسجل على أنها ناجحة.

**النتيجة:** قبول 13Q.1 فقط. لا يوجد حتى الآن اختبار MCP server حقيقي مملوك لـSkill داخل التطبيق؛ 13Q لم تكتمل.


## سجل CI #76 — عطل تنزيل خارجي

في 22 نوفمبر 2026، نجحت اختبارات 13Q.1 في المحاولتين من تشغيل CI #76، وكذلك Flutter Analyze واختبارات الحزم المستقلة. تعثر Android JVM/Robolectric قبل قبول البناء:

- المحاولة الأولى: فشل اختبارا `AndroidSelectionMenuTest` و`HighRefreshRateControllerTest` داخل `MavenArtifactFetcher.java:129` بسبب `IOException` أثناء جلب runtime artifacts.
- المحاولة الثانية: فشل Gradle في حل `debugUnitTestRuntimeClasspath` عند تنزيل `org.robolectric:nativeruntime-dist-compat:1.0.18` من Maven Central بسبب HTTP 429.
- لم تعمل خطوات Android Emulator وRelease APK بعد بوابة الاختبارات، ولم ينتج APK للمحاولة الثانية.

أضيفت مرآة Google Hosted Maven Central لمجموعة `org.robolectric` في `android/build.gradle.kts` كإصلاح للبنية التحتية. هذا الإصلاح لا يغير سلوك MCP ولا يخفف اختبارات Robolectric. قبول البناء ينتظر CI التالي.


## تحقق CI #78 — تأكيد 13Q.1 وبوابات البناء (23 نوفمبر 2026)

نجح [CI #78](https://github.com/m5ham3ds/KELIVO/actions/runs/45080129832) على commit `64e51a52958b58f3d0ba83099bcc90fb4384855d`. اجتازت خطوة اختبارات اكتشاف إعداد MCP للقراءة فقط، كما اجتازت Android JVM/Robolectric وPhase 13P Emulator E2E وبناء Android ARM64 Release ورفع APK.

**النطاق المثبت:** يؤكد هذا التشغيل اختبارات 13Q.1 فقط. لا يثبت تشغيل خادم MCP مملوك لمهارة أو دورة connect/tools/list/tools/call؛ لذلك تبقى 13Q.2–13Q.5 مفتوحة وتبقى Phase 13B غير مكتملة.
