# PHASE 14C — MCP Base Protocol Compatibility & Skills over MCP

**الحالة:** **مقبولة بالكامل** — اجتازت Phase 14C.1–14C.5 بوابات القبول في CI #199 على `main`. يشمل ذلك transport hardening، typed Skills adapter، resource integrity/lazy fetch، Secure Remote Skills UI، MRTR وstateless `subscriptions/listen`، واختبارات HTTP request-scoped cancellation.
**تاريخ البدء:** 25 نوفمبر 2026.
**آخر تحقق شامل:** CI #199 على commit `1b5bbbee69d51e96d1fda1526bac141f6ea5a33c`.
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

## 2.2 CI #193 — اعتماد واجهة Remote Skills (14C.4)

اجتاز GitHub Actions #193 (run `45734199313`) على رأس `main` المطابق للالتزام `924ea5a2bfcfd1f18c62b56e4e165836cb592095`. اكتملت وظيفة البناء ذات 41 خطوة ووظيفة التقرير بنجاح، بما في ذلك Flutter Analyze وEnvironment lifecycle و14A/14B وGemini/OAuth واختبارات الحزم المحلية وAndroid JVM/Robolectric وPhase 13P Emulator E2E وبناء ورفع ARM64 APK.

اجتازت مجموعة اختبارات Remote Skills المخصصة 19 اختباراً، وتثبت أن شاشة الاكتشاف تستخدم مصادر MCP HTTPS المفعلة والمعدة مسبقاً، وأن فحص metadata وقراءة كل resource موافقتان منفصلتان، وأن الاتصالات لا تستخدم DNS غير عام أو proxy غير مضبوط أو redirect عابر للنطاق، وأن النص البعيد يبقى غير موثوق ولا يُثبت أو يُنفذ تلقائياً. تم التحقق من نقطة الوصول داخل SkillsPane.

**APK — CI #193**
- الاسم: `Kelivo-Android-arm64-v8a-1.3.4+84-release.apk`.
- الحجم الفعلي: 41,928,799 bytes.
- ABI: `arm64-v8a` فقط.
- SHA-256: `faeee49e9ddb52c53f252aca9bb59499f0569c04b73f26ae862fe162ad66e039`.
- APK artifact: [15078658903](https://github.com/m5ham3ds/KELIVO/actions/runs/45734199313/artifacts/15078658903).
- Build report: [15078988516](https://github.com/m5ham3ds/KELIVO/actions/runs/45734199313/artifacts/15078988516).
- Raw diagnostics: [15078748783](https://github.com/m5ham3ds/KELIVO/actions/runs/45734199313/artifacts/15078748783).

**حدود القبول:** #193 يقبل تكامل 14C.4 واختباراته، لكنه لا يغلق فجوات MCP 2026-07-28 protocol semantics المتعلقة بـMRTR و`subscriptions/listen`. ولا يشغّل Flutter root unit/widget suite كاملة أو اختبارات Phase 13E–13O التاريخية، ولا يمثل اختبار هاتف ARM64 فعلياً.

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

### 14C.4 — Secure Remote Skills discovery integration — مقبولة في CI #193
- تم دمج `RemoteSkillsPage` في إجراء داخل `SkillsPane`؛ ليست شاشة غير مستخدمة.
- مصدر الاكتشاف يقتصر على MCP Streamable HTTP HTTPS المصادر المعدة والمفعلة مسبقاً؛ لا URL حر ولا اتصال عند فتح الشاشة وحدها.
- HTTPS فقط، رفض userinfo/fragments/unsupported schemes، DNS resolve + رفض أي عنوان non-public، وتثبيت الاتصال على IP الذي اجتاز الفحص مع TLS hostname verification على اسم المضيف.
- منع proxy وcross-origin redirects؛ body/time/redirect limits مطبقة.
- الموافقة الأولى منفصلة قبل `server/discover` و`skills/list` لعرض metadata فقط.
- موافقة ثانية صريحة لكل URI/resource قبل `resources/read`؛ الموافقة مرتبطة بهوية الخادم وURI ومجموعة digests الكاملة.
- المحتوى المسترجع يظهر كنص plain untrusted (لا Markdown rendering، ولا prompt execution، ولا shell/MCP tool calls).
- dynamic resources بلا digest ثابت لا تُقرأ كموارد موثوقة.
- لا تثبيت في Skills registry المحلي تلقائياً؛ import صريح مستقل مع provenance يأتي لاحقاً.
- 19 اختباراً مخصصاً اجتازت CI #193. قبول هذه الشريحة لا يعني أن كامل base protocol 2026 قد اكتمل.

### 14C.5 — MRTR and stateless notification subscriptions — مقبولة في CI #199
- إضافة `InputRequiredResult` / MRTR loop محدود إلى الطلبات الثلاثة المسموح بها فقط: `prompts/get` و`resources/read` و`tools/call`.
- معالجة `inputRequests` عبر handlers المعلنة في client capabilities فقط: `roots/list` و`sampling/createMessage` و`elicitation/create`; رفض الطريقة غير المعلنة أو غير المدعومة fail-closed.
- retry للطلب الأصلي بمعرّف JSON-RPC جديد، وإرفاق `inputResponses` المقابلة؛ تمرير `requestState` كقيمة opaque دون تحليل أو تعديل أو تخزين جانبي.
- حد محلي أقصى 5 جولات و16 input request في الجولة، مع رفض shapes غير الصالحة، resultType المفقود أو غير المعروف، InputRequiredResult على method غير مسموح.
- في 2026 stateless، رفض server-initiated JSON-RPC requests؛ الإصدارات القديمة تحتفظ بسلوكها.
- دعم `subscriptions/listen` بفلتر كائن محدد الحقول: `toolsListChanged` و`promptsListChanged` و`resourcesListChanged` و`resourceSubscriptions`؛ رفض الفلتر الفارغ أو غير الصالح.
- مطابقة acknowledgement عبر `_meta.subscriptionId` والتحقق من أن الفلتر المعتمد subset من المطلوب؛ تمرير الإشعارات فقط إلى الاشتراك الذي يحمل المعرف نفسه ويطابق الفلتر، مع عزل عدة streams مستقلة.
- `listenForNotifications` يعيد مقبض `McpSubscription` بعد الإقرار، ويعرض `done` لإغلاق stream المنظم؛ الإغلاق النهائي يتطلب `resultType=complete` ومعرف الاشتراك ذاته. لا GET stream ولا Last-Event-ID/resume.
- إلغاء HTTP يغلق POST SSE response stream فقط؛ إلغاء STDIO يرسل `notifications/cancelled` مع request ID. legacy SSE غير مدعوم مع subscriptions في إصدار 2026.
- تعطيل `resources/subscribe` و`resources/unsubscribe` و`ping` و`logging/setLevel` و`notifications/roots/list_changed` القديمة عند استخدام 2026، مع إبقاء APIs للإصدارات التاريخية؛ مستوى السجل ينتقل إلى `_meta/io.modelcontextprotocol/logLevel` لكل طلب.
- اختبارات MRTR الإيجابية والسلبية: handler/capability gating، opaque requestState، missing/unknown resultType، malformed requests، round-trip cap، وعدم تنفيذ server-initiated requests؛ واختبارات subscription ack/filter/demultiplexing/HTTP وSTDIO cancellation/closure، مع legacy regression.


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
10. MRTR: السماح فقط بالطلبات الثلاثة المحددة؛ رفض الطلبات التي تتطلب capability غير معلنة أو handler غير موجود؛ round-trip cap؛ replay للطلب الأصلي بمعرّف جديد؛ echo حرفي لـrequestState؛ قبول legacy results دون resultType؛ ورفض stateless results ذات resultType المفقود/غير المعروف.
11. subscriptions/listen: اختبار request metadata/headers وfilter validation وacknowledgement وnotification delivery وlong-lived response وdisconnect cancellation، مع عدم استخدام GET أو Last-Event-ID.
12. اختبار أن server-initiated JSON-RPC request لا يتم تنفيذه في stateless 2026، مع المحافظة على السلوك التاريخي لكل revision قديم.

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

## 8. القرار النهائي — CI #199

**Phase 14C مقبولة بالكامل على `main`.** اجتاز التشغيل [CI #199](https://github.com/m5ham3ds/KELIVO/actions/runs/45856311571) على commit `1b5bbbee69d51e96d1fda1526bac141f6ea5a33c` جميع بوابات البناء والتقرير:

- Flutter Analyze وEnvironment lifecycle و14A و14B وGemini/OAuth و14C.4 و13Q: نجاح.
- جميع اختبارات الحزم المحلية، بما فيها `mcp_client`: نجاح.
- اختبارات HTTP subscription integration: real request-scoped SSE acknowledgement/notification/completion، وإلغاء POST subscription منفرداً مع الحفاظ على عميل MCP صالحاً لطلب آخر.
- Android JVM/Robolectric وPhase 13P Android Emulator E2E: نجاح.
- بناء APK ARM64، فحص ABI، SHA-256، رفع APK والتقرير والتشخيص: نجاح.

APK: `Kelivo-Android-arm64-v8a-1.3.4+84-release.apk`; الحجم `40,735,865` bytes؛ ABI `arm64-v8a` فقط؛ SHA-256 `1df6812133b68a55a262331b9dc37615c78ba8cb635352923cf4aae86823d7ca`؛ APK Artifact `15136693255`.

**قرار التسلسل المحدث — 27 نوفمبر 2026:** Phase 14C مغلقة بعد CI #199. اجتازت Phase 14D بعدها بوابة الخادم الحقيقي والعدائي عبر STDIO في CI #204، وأعيد التحقق ضمن CI #208. المرحلة النشطة الآن Phase 14E؛ انظر الخطة المعمارية وتقرير `PHASE-14E-IMPLEMENTATION-STATUS-AR.md`.

**حدود الادعاء:** هذا التشغيل لا يدعي عزل PRoot على مستوى kernel أو اختبار Force Stop على جهاز المستخدم؛ Android Emulator يثبت تدفق E2E في بيئة المحاكي فقط.
