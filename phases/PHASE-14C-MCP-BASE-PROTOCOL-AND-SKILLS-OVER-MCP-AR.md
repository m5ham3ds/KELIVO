# PHASE 14C — MCP Base Protocol Compatibility & Skills over MCP

**الحالة:** 14C.1 initial slice passed CI #175; post-CI protocol hardening is in progress. Remote Skills stay disabled until the Skills adapter, integrity checks, approval binding, and security gates pass.
**تاريخ البدء:** 25 نوفمبر 2026.
**الفرع:** `main` — first runtime slice `821744e04fbf6ef525a42a80a2a220aa5a4f4f2b`; hardening follow-up is recorded below.
**المرحلة السابقة:** Phase 14B مقبولة في CI #164.
**المبدأ:** توسيع عميل MCP المحلي تدريجياً مع إبقاء النقل والإصدارات القديمة؛ لا ترقية قسرية ولا تشغيل خادم أو Skill تلقائياً.

## 1. نتيجة مراجعة الوضع الحالي

جرى فحص الكود في:
- `dependencies/mcp_client/lib/src/client/client.dart`
- `dependencies/mcp_client/lib/src/protocol/protocol.dart`
- `dependencies/mcp_client/lib/src/models/models.dart`
- `dependencies/mcp_client/lib/src/transport/streamable_http_transport.dart`
- اختبارات `dependencies/mcp_client/test/per_version_compliance_test.dart` و`deferred_loading_test.dart`
- `lib/core/services/skills/skill_mcp_config.dart` و`skill_mcp_registry.dart` و`skill_mcp_connection_service.dart`
- `lib/core/providers/mcp_provider.dart` و`lib/core/services/mcp/mcp_tool_service.dart`

### ما هو موجود بالفعل
- يدعم عميل MCP المحلي revisions: `2024-11-05` و`2025-03-26` و`2025-06-18` و`2025-11-25` في جدول الإصدارات.
- Streamable HTTP transport يتعامل مع session ID وHTTP version header وSSE، ولديه cancellation على مستوى إرسال POST.
- توجد typed models لـResources وResource templates وResource reads.
- يوجد Deferred Tool metadata/schema registry في حزمة MCP المحلية.
- يوجد Skill MCP config parser للقراءة فقط، وowner registry، وخدمة دورة اتصال Skill-owned stdio مع approval وdigest revalidation.
- توجد route snapshots في MCP tool service لتثبيت هوية مسار الأدوات أثناء الجولة.

### فجوات مؤكدة في المراجعة
1. يرسل `Client.initialize()` قيمة `McpProtocol.defaultVersion` وحدها؛ لا يرسل قائمة versions ولا يفاوض قائمة capabilities المتقاطعة.
2. إذا أعاد الخادم revision مختلفاً، يستدعي العميل تحذيراً فقط؛ لا يرفض revision غير معروف ولا يضمن أن الإصدار الذي استقر عليه هو تقاطع مدعوم.
3. resource list/read APIs الحالية لا تعرض cursor pagination؛ `listResources()` يطلب الصفحة الأولى فقط.
4. لا توجد نماذج typed أو methods لـ`io.modelcontextprotocol/skills` في عميل MCP الحالي.
5. تمثيل server capabilities الحالي يغطي أدوات وموارد وprompts وغيرها، لكنه لا يحتفظ بصورة عامة خام للـcapabilities/experimental extensions بشكل يكفي وحده لاكتشاف امتداد Skills بسلامة.
6. تحتاج عملية remote Skill إلى manifest/resource model مستقل؛ لا يجوز استخدام Skill local registry أو URI وحده كهوية.

هذه فجوات محددة من ملفات المصدر المذكورة، وليست ادعاءً أن بقية MCP transport غير صالح.

## 2. تحديث مهم بعد تدقيق المواصفة الرسمية 2026-07-28

المراجعة الرسمية للـbase protocol أكدت أن revision `2026-07-28` ليس تحديثاً سطحياً لـ2025-11-25؛ فهو stateless ويزيل initialize/initialized وprotocol-level session ID، وينقل protocol version وclient capabilities إلى `_meta` في كل طلب، ويضيف `server/discover` لاختيار النسخة والقدرات، ويستبدل موارد/إشعارات HTTP السابقة بمسار subscriptions الجديد. لذلك لا يمكن اعتبار client الحالي المتوافق مع 2025-11-25 متوافقاً مع 2026-07-28 بمجرد إضافة version constant.

كما تؤكد مواصفة Skills Beta الحالية أن `skills/list` قد يرجع قائمة فارغة أو جزئية، وأن skill URI يمكن أن يقرأ مباشرة عبر `resources/read` حتى إذا لم يرد في القائمة، وأن `skills/get` يعيد metadata/digests لمهارة واحدة، و`resources/directory/read` اختياري. وعليه، discovery لا يجوز أن يعتمد على استنفاد القائمة وحدها، ولا أن يحمّل كل الموارد مبكراً.

المراجع في القسم 7 هي مصدر الحقيقة؛ أما SEP التاريخي فيوثق التصميم وليس بديلاً عن النص المستقر الحالي.

## 2. CI #175 — نتيجة التنفيذ الأولي

CI #175 نجح على commit `821744e04fbf6ef525a42a80a2a220aa5a4f4f2b`، مع 160 اختباراً في الحزم المحلية و440 اختبار Android JVM/Robolectric ونجاح محاكي Android وبناء ARM64. تم التحقق من APK المستخرج نفسه: `41,894,251` bytes، ABI `arm64-v8a` فقط، SHA-256 `a448f321903fa4bd871e96862f6ec6e18e480a85e6daf5bc43e72fd96a299f16`.

**تدقيق ما بعد CI:** كشف أن stateless mode كان يُفعّل بعد `server/discover` بدلاً من قبله، وأن `connectWithRetry` لا يستخدم discovery، وأن SSE المرتبط بالطلب كان مرفوضاً، وأن ServerCapabilities لا تحفظ `extensions`. لذلك CI #175 يثبت سلامة الـslice الأولي فقط؛ لا تُقبل 14C.1 نهائياً قبل نجاح hardening follow-up واختبار HTTP الفعلي.

## 3. حدود هذا checkpoint


يقتصر هذا التغيير على:
- تسجيل تقرير هذه الفجوات والعقود المستهدفة.
- تثبيت أن 14B مقبولة وتحديث سجل المراحل.
- عدم تغيير بروتوكول MCP أو بدء اتصال جديد أو تشغيل أدوات/خوادم أثناء import/inspect.
- إبقاء remote Skills غير مدعومة/غير متاحة حتى وصول التنفيذ واختبارات التوافق.

**لا يدّعي هذا slice** اكتمال 14C runtime أو دعم Skills-over-MCP؛ أضيف اكتشاف stateless أولي قابل للاختبار، لكن دعم كامل 2026-07-28 (subscriptions/MRTR/result semantics) لم يكتمل بعد.

## 3. عقد التوافق الذي يجب تنفيذه

### 3.1 Version negotiation
- يجب إرسال النسخ المدعومة التي يعلنها العميل وفق طريقة التفاوض المعتمدة في كل revision؛ لا تخلط بين client preference list وserver selected version.
- عند الاستجابة، تحقق من أن القيمة نص معروف ومدعوم ومتفق عليه حسب protocol revision.
- الرفض الصريح للنسخة غير المعروفة أو غير المدعومة أفضل من الاستمرار بتحذير صامت.
- لا تكسر سلوك الخوادم القديمة؛ ضع compatibility tests لكل revision قديم ومدعوم.
- لا تحدث الـHTTP header إلا باستخدام النسخة التي تم الاتفاق عليها بالفعل.

### 3.2 Capability discovery
- احتفظ بخريطة server capabilities الأصلية، بما فيها المجالات غير المعروفة، بدلاً من إسقاط مفاتيح الامتدادات.
- اكتشف `io.modelcontextprotocol/skills` من الموضع والصيغة المحددين في مواصفة الامتداد المثبتة، لا بالتخمين ولا من وجود resources عامة.
- لا تستدعِ `skills/list` إلا بعد إعلان الخادم عن الامتداد، وبعد version negotiation ناجح، وبعد موافقة المستخدم على فحص المصدر البعيد.
- أي عدم إعلان أو malformed capability يعني عدم إتاحة الامتداد.

### 3.3 Skills list/get and resources
- أضف DTOs typed لمدخلات ومخرجات `skills/list` و`skills/get` كما تحددها النسخة المثبتة من مواصفة الامتداد.
- pagination: اتبع cursor حتى النهاية بحد أقصى صريح للصفحات والمهارات وحجم البيانات؛ لا تفسر الصفحة الأولى الفارغة على أنها لا توجد مهارات قبل استنفاد cursor.
- Resource manifest: خزّن URI وname/title/description ومعلومات كل ملف وحجمه وdigest وفق schema الرسمي.
- لا تحمل محتوى Skill أو الملفات الداعمة أثناء list. اجلب ملفاً محدداً عند الطلب فقط.
- أي resource يتجاوز الحدود أو يفتقد digest مطلوباً أو يحمل digest غير صالح يُرفض ولا يُفعّل.
- اقصر عمليات resources/read على الموارد التي أعلنها manifest لنفس Skill/source، ولا تسمح URI حر من المستخدم أو بيانات خارجة عن الخادم المحدد.

### 3.4 Identity, trust and approval
- الهوية المركبة = MCP server identity + skill URI + server endpoint/transport identity + resource digest set.
- اسم Skill أو URI وحده لا يحدد الملكية. يجب ألا تحل Remote Skill محل Local Skill أو Skill من خادم آخر حتى لو تساوى الاسم أو URI.
- اربط موافقة المستخدم بمجموعة digests كاملة؛ أي تغيير في manifest أو digest يبطل الموافقة وcache الموثوق.
- metadata وSKILL.md والملفات الخارجية untrusted instructions/data. التحميل لا يمنح execution permissions.
- الموارد الديناميكية أو القابلة للتبدل لا تعامل كنسخة ثابتة موثوقة؛ تتطلب revalidation أو رفضاً وفق سياسة الثقة.
- لا اتصال ولا read ولا تفعيل افتراضي عند import/inspect؛ كل عملية شبكة تحتاج consent flow صريح.

## 4. حدود الحجم والوقت
القيم النهائية يجب أن تتطابق أو تكون أشد من مواصفة الامتداد، وتوضع مركزياً كسياسة قابلة للاختبار:
- عدد صفحات list: 32 كحد افتراضي أولي.
- عدد Skills: 512 كحد أعلى لكل مصدر.
- مجموع محتوى Skill: 16 MiB كحد أعلى، مع حد لكل مورد أصغر.
- مهلة كل request: مرتبطة بمهلة MCP، مع حد تراكمي لعملية discovery.
- حد redirect/response/body: لا تقبل response بلا سقف.
- هذه القيم لا تعتمد نهائياً قبل مطابقتها مع مواصفة الامتداد الرسمية عند تنفيذ البروتوكول.

## 5. خطة التنفيذ المقسمة

### 14C.1 — MCP protocol compatibility core
- إبقاء revisions الأربعة التاريخية مع سلوكها الحالي، وإضافة مسار مستقل للـ2026-07-28 دون كسر العميل القديم.
- `server/discover` أولاً حيث يدعمه الخادم؛ ثم تحديد revision/capabilities قبل توجيه الطلبات.
- إضافة stateless request envelope يحمل protocolVersion وclientCapabilities وclientInfo في `_meta` لكل طلب.
- فصل transport/session strategy حتى لا يضيف أو يطلب `Mcp-Session-Id` في 2026-07-28، مع الإبقاء عليه للنسخ الأقدم.
- اختبار Streamable HTTP stateless وSTDIO compatibility probe، وresultType/default compatibility.
- لا تضف skills methods قبل ثبوت هذه الطبقة.

### 14C.2 — Skills-over-MCP typed adapter
- DTOs/schema للامتداد وmethods بعد تثبيت النسخة الرسمية.
- capability-gated list/get.
- pagination/partial-list semantics.
- لا caching دائم حتى اكتمال integrity.

### 14C.3 — Resource integrity and lazy fetch
- manifest validation.
- size/digest verification.
- lazy `resources/read` للملفات المطلوبة فقط.
- cache keyed by composite identity and complete digest set.
- invalidation on listChanged/TTL/source change.

### 14C.4 — Secure discovery integration
- صفحة/واجهة عرض remote Skill source مع origin/server identity والتحذيرات.
- preview metadata أولاً، ثم consent منفصل لجلب التعليمات/الموارد.
- لا تثبيت في Skills registry المحلي تلقائياً؛ يتطلب import صريح وخطوة provenance مستقلة.
- لا تنفيذ أوامر أو Scripts أو MCP tools نتيجة مجرد اكتشاف Skill.

## 6. بوابة القبول

لا تقبل 14C قبل:
1. مصفوفة توافق لكل revisions مدعومة، بما يشمل version mismatch/unsupported version.
2. mock servers لكل revision، مع extension advertised/not advertised/malformed.
3. pagination كاملة، cursor متكرر، cursor malformed، حد الصفحات، empty partial list.
4. stale digest وdigest mismatch وmissing resource وsize overflow وbody overflow.
5. collision في URI بين خادمين وتطابق اسم Remote Skill مع Local Skill.
6. invalidation عند server identity أو manifest أو digest change.
7. إثبات عدم الاتصال/التحميل أثناء import أو inspect أو مجرد list محلي.
8. اختبار Android JVM/Robolectric وFlutter Analyze وARM64 APK مع سجل CI.
9. عدم تفعيل Skills أو منحها صلاحيات تنفيذ بمجرد تنزيل الملفات.

## 7. الأدلة والمراجع

- المصدر الرسمي للمواصفة الأساسية 2026-07-28: https://github.com/modelcontextprotocol/modelcontextprotocol/tree/main/docs/specification/2026-07-28
- سجل التغييرات 2026-07-28: https://github.com/modelcontextprotocol/modelcontextprotocol/blob/main/docs/specification/2026-07-28/changelog.mdx
- Skills extension Beta: https://github.com/modelcontextprotocol/ext-skills/blob/main/specification/beta/skills.mdx
- SEP-2640 (سجل قرار تاريخي؛ عند تعارضه مع النسخة Beta الحالية يجب اتباع المواصفة الحالية): https://github.com/modelcontextprotocol/modelcontextprotocol/blob/main/docs/seps/2640-skills-extension.mdx
- سجل قرارات مجموعة العمل: https://github.com/modelcontextprotocol/ext-skills/blob/main/docs/decisions.md
- مصدر عميل MCP وموصلاته محلي داخل `dependencies/mcp_client`.
- سجل الفجوات مبني على رأس `0ef719649ff00f621a2fac62e801b15d41cc2239`.
- تم تثبيت المصدر الرسمي: base protocol 2026-07-28 وBeta Skills extension المبني عليه. يجب توليد DTOs واختبارها من النصين الرسميين، وعدم الاستناد إلى SEP التاريخي وحده.
- تراخيص الكود الخارجي يجب مراجعتها منفصلاً قبل أي نسخ.

## 8. القرار
هذه الوثيقة checkpoint تنفيذية لـ14C، وليست إعلان اكتمال. أول تعديل runtime يجب أن يبدأ بـ14C.1 ويضيف اختبارات regression قبل إدخال أي Skills extension methods.
