# PHASE 13Q — موائم MCP المملوك للمهارات

**الحالة:** 13Q.1 محلل قراءة فقط مضاف واجتاز CI #73؛ المرحلة غير مقبولة حتى تكتمل دورة lifecycle.

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
