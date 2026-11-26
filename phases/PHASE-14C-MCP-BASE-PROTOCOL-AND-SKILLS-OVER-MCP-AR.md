# PHASE 14C — MCP Base Protocol Compatibility & Skills over MCP

**الحالة:** 14C.1 transport-hardening slice و14C.2 typed Skills adapter و14C.3 lazy resource integrity اجتازت بوابات CI حتى #187. Phase 14C.4 Secure Remote Skills discovery integration قيد التنفيذ. هذا لا يعني اكتمال full MCP 2026-07-28؛ MRTR وsubscriptions/listen semantics ما زالت خارج الدعم الكامل.
**تاريخ البدء:** 25 نوفمبر 2026.
**آخر تحقق شامل:** CI #187 على `main` commit `cfd749429083b42b9228f594ed9992c5fd68507a`.
**المرحلة السابقة:** Phase 14B مقبولة في CI #164.
**المبدأ:** توسيع عميل MCP المحلي تدريجياً مع إبقاء النقل والإصدارات القديمة؛ لا ترقية قسرية ولا تشغيل خادم أو Skill تلقائياً. Remote discovery منفصل عن Skill-owned local MCP lifecycle في 14D.

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
4. يجري الآن إضافة typed DTOs وmethods لـ`io.modelcontextprotocol/skills` في 14C.2.
5. تمثيل server capabilities الحالي يغطي أدوات وموارد وprompts وغيرها، لكنه لا يحتفظ بصورة عامة خام للـcapabilities/experimental extensions بشكل يكفي وحده لاكتشاف امتداد Skills بسلامة.
6. تحتاج عملية remote Skill إلى manifest/resource model مستقل؛ لا يجوز استخدام Skill local registry أو URI وحده كهوية.

هذه فجوات محددة من ملفات المصدر المذكورة، وليست ادعاءً أن بقية MCP transport غير صالح.

## 2. تحديث مهم بعد تدقيق المواصفة الرسمية 2026-07-28

المراجعة الرسمية للـbase protocol أكدت أن revision `2026-07-28` ليس تحديثاً سطحياً لـ2025-11-25؛ فهو stateless ويزيل initialize/initialized وprotocol-level session ID، وينقل protocol version وclient capabilities إلى `_meta` في كل طلب، ويضيف `server/discover` لاختيار النسخة والقدرات، ويستبدل موارد/إشعارات HTTP السابقة بمسار subscriptions الجديد. لذلك لا يمكن اعتبار client الحالي المتوافق مع 2025-11-25 متوافقاً مع 2026-07-28 بمجرد إضافة version constant.

كما تؤكد مواصفة Skills Beta الحالية أن `skills/list` قد يرجع قائمة فارغة أو جزئية، وأن skill URI يمكن أن يقرأ مباشرة عبر `resources/read` حتى إذا لم يرد في القائمة، وأن `skills/get` يعيد metadata/digests لمهارة واحدة، و`resources/directory/read` اختياري. وعليه، discovery لا يجوز أن يعتمد على استنفاد القائمة وحدها، ولا أن يحمّل كل الموارد مبكراً.

المراجع في القسم 7 هي مصدر الحقيقة؛ أما SEP التاريخي فيوثق التصميم وليس بديلاً عن النص المستقر الحالي.

## 2.1 CI #187 — اعتماد طبقة النقل والـSkills integrity

اجتاز CI #187 (run `45730072596`) على commit `cfd749429083b42b9228f594ed9992c5fd68507a` جميع بوابات الوظيفة الرئيسية 40/40 ووظيفة التقرير 9/9. شمل ذلك Flutter Analyze، Environment lifecycle، Phase 14A/14B/13Q، Gemini/OAuth، كل الحزم المحلية، Android JVM/Robolectric، Phase 13P Emulator E2E، وبناء Release ARM64.

اختبارات `dependencies/mcp_client` التي اجتازت تضمنت:
- lazy resource integrity والتحقق من SHA-256/frontmatter وحالات digest mismatch.
- حد الأجسام المتدفقة لاستجابات JSON وSSE قبل تجميعها بالذاكرة.
- رفض استجابة HTTP 202 كبيرة أثناء التصريف، ورفض جسم redirect 307 كبير قبل اتباعه.
- منع إعادة توجيه cross-origin مع حماية الترويسات السرية.

**APK:** `Kelivo-Android-arm64-v8a-1.3.4+84-release.apk`؛ 41,900,015 bytes؛ ABI `arm64-v8a`؛ SHA-256 `cc6c39f8022e193a6fdf893d3d401bcc96f181293c8e9cd4e7fe96ea6710a2be`؛ Artifact ID `15077442763`. تقرير البناء: Artifact `15076853823`.

**نطاق القبول:** هذا CI يغلق 14C.3 lazy resource integrity/response bounds، ويثبت اختبارات الـadapter الموجودة؛ لا يشغّل كامل Flutter root unit/widget suite، ولا يثبت دعم MRTR أو subscriptions/listen في base protocol 2026-07-28، ولا يثبت تجربة هاتف فعلي أو Force Stop.

## 2. CI #177 — إغلاق 14C.1 hardening

اجتاز الالتزام `2ea38c430dd67e5675aaee83488b8ff84fc3b2d3` جميع وظائف CI #177، وكان رأس `main` مطابقاً للالتزام المختبَر. نجحت Flutter Analyze، Environment lifecycle، Phase 14A/14B/13Q، Gemini/OAuth، اختبارات الحزم المحلية (140)، Android JVM/Robolectric (325)، محاكي Android (بما فيه Phase 13P)، وبناء ورفع ARM64.

APK release: `Kelivo-Android-arm64-v8a-1.3.4+84-release.apk`; الحجم `41,894,427` bytes؛ ABI `arm64-v8a` فقط؛ SHA-256 `5ad3659620bae5d85c660144a1ca52ba4518dac32746f5674f54929bd30a6641`. Artifact ID: `15029793958`. Report: `15029442954`; raw logs: `15029349291`.

**حدود workflow:** لا يشغّل Flutter root unit/widget suite كاملة ولا مجموعات Phase 13E–13O المركزة. التقرير سجل 117 تطابقاً لتحذيرات وإهمالات deprecated، دون فشل في التحليل أو البناء.

### نتيجة تدقيق ما بعد CI
- أول stateless HTTP POST يحمل protocol/method metadata قبل `server/discover`.
- SSE المرتبط بالطلب مدعوم دون GET resumption/session.
- `connectWithRetry` يستخدم اكتشاف stateless.
- `ServerCapabilities.extensions` يحفظ امتدادات الخادم.
- اختبارات HTTP integration للـheaders/SSE اجتازت الحزم المحلية.
- MRTR (`input_required`/إعادة الطلب) و`subscriptions/listen` لم يكتمل دعمهما بعد؛ لا يُعلن full 2026-07-28 base protocol compliance بعد.

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
- عدد صفحات `skills/list`: 32 صفحة كحد محلي افتراضي؛ إذا بقي `nextCursor` بعدها ترجع النتيجة مقطوعة مع cursor الاستكمال. هذا حد سياسة للمضيف وليس حداً تضعه المواصفة للخادم.
- موارد المهارة الواحدة: 512 مدخلاً كحد أقصى، شاملاً `SKILL.md`.
- الحجم الكلي لموارد المهارة الواحدة: 16 MiB (16,777,216 bytes)، وهو مجموع `size` لكل موارد manifest.
- هذان الحدان يخصان **كل Skill على حدة**؛ مواصفة الامتداد لا تحد عدد Skills الذي يمكن للخادم نشره أو عدد عناصر الفهرس الكلي.
- مهلة كل request مرتبطة بمهلة MCP، مع حد تراكمي لعملية pagination.
- حد response/body/redirect يجب أن يبقى محدوداً وقابلاً للاختبار؛ لا تُحمّل ملفات Skill خلال list/get.
- `resources: "dynamic"` مسموح في manifest لكنه بلا digest ثابت، ويظل غير قابل للتحقق بالمحتوى في هذه المرحلة.
- القيم مأخوذة من Skills extension Beta الحالية وتُراجع عند ترقية المواصفة.

## 5. خطة التنفيذ المقسمة

### 14C.1 — MCP protocol compatibility core
- إبقاء revisions الأربعة التاريخية مع سلوكها الحالي، وإضافة مسار مستقل للـ2026-07-28 دون كسر العميل القديم.
- `server/discover` أولاً حيث يدعمه الخادم؛ ثم تحديد revision/capabilities قبل توجيه الطلبات.
- إضافة stateless request envelope يحمل protocolVersion وclientCapabilities وclientInfo في `_meta` لكل طلب.
- فصل transport/session strategy حتى لا يضيف أو يطلب `Mcp-Session-Id` في 2026-07-28، مع الإبقاء عليه للنسخ الأقدم.
- اختبار Streamable HTTP stateless وSTDIO compatibility probe، وresultType/default compatibility.
- لا تضف skills methods قبل ثبوت هذه الطبقة.

### 14C.2 — Skills-over-MCP typed adapter
- `McpSkillEntry` و`McpSkillResource` ونتائج list/get typed، مع تمرير frontmatter الإضافي.
- لا تُستدعى `skills/list` أو `skills/get` إلا بعد إعلان `io.modelcontextprotocol/skills` داخل capabilities في `server/discover`، ومع `resources` capability والتفاوض على 2026-07-28.
- `skills/list` يتبع cursor حتى النهاية أو حد 32 صفحة، ويكشف cursor المكرر ويُظهر عند قطع pagination. القائمة الفارغة أو المنتهية لا تثبت عدم وجود مهارة لأن الخادم قد يعرض قائمة جزئية.
- `skills/get` يقبل URI صريحاً حتى لو لم يظهر في القائمة.
- هوية السجل المركبة = host-assigned server identity + Skill URI؛ الاسم ليس معرفاً ولا يجوز إسقاط تعارض أسماء بين خادمين أو مع Local Skill.
- تحقق parsing من frontmatter/URI/manifest؛ 512 resource entries و16 MiB لكل Skill، مع قبول `resources: "dynamic"` بوصفه غير قابل للتحقق.
- لا `resources/read` ولا تحميل ملفات ولا تفعيل أثناء list/get. لا caching دائم قبل اكتمال integrity في 14C.3.

### 14C.3 — Resource integrity and lazy fetch — مقبولة في CI #187
- manifest validation؛ size/digest verification؛ lazy `resources/read` للموارد المعلنة فقط.
- cache keyed by composite identity and complete digest set، مع invalidation on listChanged/TTL/source change.
- response-byte caps تطبق قبل buffering على JSON وSSE، وعلى أجسام 202 وredirect التي يجري تصريفها.
- اختبارات هذه الطبقة اجتازت ضمن الحزمة المحلية في CI #187. لا يعني ذلك أن النص remote content صار موثوقاً أو قابلاً للتنفيذ.

### 14C.4 — Secure Remote Skills discovery integration — قيد التنفيذ
- اختيار مصدر من ملفات MCP HTTP التي أعدّها المستخدم مسبقاً؛ لا URL حر أو اتصال تلقائي عند فتح الصفحة.
- HTTPS فقط، رفض userinfo/fragments/unsupported schemes، DNS resolve + رفض أي عنوان non-public، وتثبيت الاتصال على عنوان IP الذي اجتاز الفحص مع بقاء TLS hostname verification على اسم المضيف.
- منع proxy/redirect غير المنضبطين ومنع cross-origin credential forwarding؛ جميع استجابات discovery/resource تخضع لحدود body/time/redirect.
- الموافقة الأولى منفصلة قبل `server/discover` و`skills/list` لعرض metadata فقط.
- موافقة ثانية صريحة لكل URI/resource قبل `resources/read`; الموافقة مرتبطة بهوية الخادم وURI ومجموعة digests الكاملة، وأي تغيير يبطلها.
- عرض النص المسترجع كنص غير موثوق (لا Markdown rendering، ولا prompt execution، ولا shell/MCP tool calls).
- dynamic resources بلا digest ثابت تبقى غير قابلة للتحقق، وتُعرض كغير مدعومة للقراءة الموثوقة.
- لا تثبيت في Skills registry المحلي تلقائياً؛ import صريح مستقل مع provenance يأتي لاحقاً.
- لا خلط مع Phase 14D؛ لا server lifecycle أو tools/list أو tools/call في 14C.4.

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
- CI #187 يقبل 14C.3 lazy resource integrity وresponse-size hardening على main commit `cfd74942`.
- Phase 14C ما زالت مفتوحة حتى دمج Secure Remote Skills UI (14C.4) واستكمال دعم base-protocol gaps المعلنة؛ لا يُدعى full MCP 2026-07-28 compliance.
- التنفيذ التالي هو 14C.4 فقط، مع عدم تعديل مسار اتصال MCP القديم وعدم إدخال Skill-owned server lifecycle من 14D.
