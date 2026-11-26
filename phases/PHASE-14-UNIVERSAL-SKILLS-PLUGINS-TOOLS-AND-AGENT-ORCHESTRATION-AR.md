# PHASE 14 — Universal Skills, Plugins, Tools & Agent Orchestration

**الحالة — 26 نوفمبر 2026:** Phase 14A مقبولة بعد CI #162 وPhase 14B مقبولة بعد CI #164. Phase 14C.4 Secure Remote Skills discovery UI اجتازت 19 اختباراً مخصصاً في CI #193 على main commit `924ea5a2`. ما زالت Phase 14C مفتوحة لاستكمال MRTR و`subscriptions/listen` في slice 14C.5 على الفرع `phase-14c5-mrtr-subscriptions`. لا يبدأ 14D قبل قبول 14C على CI؛ ولا تعني هذه الحالة قبول Phase 13 أو تشغيل مكونات Plugin.
**خط الأساس:** 9abb9dcc40881b005902265fdbd86d93248cb906 — KELIVO 1.3.4+84، Flutter 3.47.6، Android ARM64.
**المبدأ:** تطوير الأنظمة القائمة وإضافة adapters مستقلة؛ لا استبدال النواة ولا إدخال Runtime إلزامي غير مناسب لـAndroid.

## 1. الهدف العام

تحويل KELIVO من منظومة قادرة على استيراد Skill وتشخيصها وتشغيل بعض local scripts إلى منصة قابلة للتوسعة تتعامل بوضوح مع:
- Skills: تعليمات وملفات وprocedures قابلة للتحميل عند الحاجة.
- Plugins: حزم تجمع Skills وCommands وAgents وHooks وMCP server declarations.
- Tools: أدوات native وCLI وMCP وBrowser وHTTP/API مع schemas وexecutors وصلاحيات.
- Agents/Subagents: وحدات متخصصة مع حدود سياق وميزانية تنفيذ وتفويض آمن.
- Workflows: DAGs وعقود ملفات ونتائج قابلة للتحقق.
- Runtime: تهيئة الاعتماديات وملفات التشغيل والموافقات والإلغاء وتسجيل النتائج.

يجب أن يتعامل النظام مع القدرة المعلنة والقدرة القابلة للتنفيذ كحالتين مختلفتين. لا يعني وجود ملف أو manifest أن KELIVO يستطيع تشغيله.

## 2. نموذج الكيانات والعقود

### 2.1 Skill
المحتوى القياسي: SKILL.md + supporting files. يجب أن يحافظ KELIVO على الأصل كما هو، ويخزن مصدره وبصمة الملفات وحالة التوافق. تعليمات Skill لا تمنح صلاحيات ولا تشغل سكربتاً تلقائياً.

### 2.2 Plugin
حزمة ذات plugin.json أو manifest متوافق، وقد تضم:
- skills/ أو Agent Skills folders.
- commands/ وslash commands.
- agents/ وSubagent descriptors.
- hooks/ وأحداث دورة الحياة.
- .mcp.json أو MCP server declarations.
- scripts/ وassets/references.

يتم حفظ unknown fields وملفات المصدر؛ ويكون التحليل read-only أولاً. لا يبدأ Hook أو خادم أو سكربت لمجرد تثبيت Plugin.

### 2.3 Tool
لكل Tool:
- ID ثابت وnamespace يحدد مصدره/الـPlugin/الخادم.
- input/output schema وإصدارها.
- capability kind وexecutor adapter.
- declared permissions وحدود الحدث/النطاق.
- timeout/cancellation وoutput limit.
- provenance digest وlifecycle.
- سياسة model exposure: direct/deferred/hidden، وليست هي نفسها صلاحية التنفيذ.

### 2.4 Agent / Subagent
ملف تعريفي يحدد المهمة والتعليمات والأدوات المسموحة ومصادر السياق وميزانية tokens/وقت/استدعاءات. الوكيل الفرعي لا يرث كل صلاحيات الوكيل الأب تلقائياً؛ يجب أن تكون capabilities مفوضة وصريحة.

### 2.5 Hook
مستمع لأحداث محددة مثل SessionStart وBeforeTool/AfterTool وStop وSubagent lifecycle. لا تُفعّل Hooks الخارجية تلقائياً، ويجب أن تكون disabled-by-default إلى أن يراجع المستخدم مصدرها وأحداثها وصلاحياتها.

## 3. ترتيب المراحل التنفيذية

### PHASE 14A — Progressive Skill Discovery & Lazy Instruction Loading

**الأولوية الأولى؛ تحسين الموجود بدلاً من إضافة مدير جديد.**

النطاق:
1. بناء فهرس metadata خفيف للمهارات المثبتة: ID/name/description/tags/source digest/readiness/lifecycle.
2. الاعتماد على extension_search الموجودة في البحث عن المهارات المخفية خلف حد العرض، وإظهار طريقة استخدامها للنموذج بوضوح.
3. تحويل skill_compose إلى مرحلتين: metadata/frontmatter أولاً، ثم قراءة تعليمات SKILL.md للمرشحين الذين اختيروا فقط.
4. بقاء frontmatter contracts/dependencies/conflicts/platforms/permissions وmanifest completeness وsource digest متاحة أثناء التخطيط.
5. بعد التحميل الفعلي، إعادة حساب instruction token estimate؛ إذا تجاوز السياق budget، يكون الناتج blocked ولا تُحقن تعليمات مبتورة أو غير متحققة.
6. تحميل references/ وassets/ فقط عندما يطلبها workflow أو أداة الملف؛ لا تُحمل سكربتات/أصول إلى prompt بلا حاجة.
7. عدم تغيير نتائج explicit/all_enabled/default modes أو ترتيب dependency DAG بدون اختبارات تكافؤ.

**المخرجات:** metadata index، progressive planner، lazy load contract، اختبارات performance/selection parity.
**بوابة القبول:** إثبات أن عدد القراءات الكاملة يساوي Skills المختارة لا جميع المرشحين؛ اختيار Skill رقم 21+ عبر البحث؛ الحفاظ على النتائج/الصلاحيات/DAG؛ رفض stale digest؛ احترام context budget؛ لا script/network/package/MCP action أثناء compose.

### PHASE 14B — Plugin Manifest & Component Registry

النطاق:
1. تعريف Dart model/validator لـPlugin manifest مع إصدار schema وsource provenance.
2. توافق قراءة Claude plugin directory structure: .claude-plugin/plugin.json، commands/، agents/، skills/، hooks/hooks.json، .mcp.json، وscripts/.
3. تحويل component paths إلى relative safe paths تحت Plugin root فقط؛ منع absolute paths وtraversal/symlinks.
4. دمج سجل المكونات في ExtensionRecord وExtensionRegistryRepository دون إزالة سجلات Skills الحالية.
5. إبقاء مكونات Plugin كـdescriptors بعد import/inspect. يدعم UI عرض كل Component وحالته.
6. تحذيرات واضحة للـmanifest غير المدعوم، وليس silent dropping.
7. تثبيت/تحديث/حذف Parent Plugin بشكل transaction-safe، مع الاحتفاظ بمحتوى كل Skill/Component الأصلي وبـrollback.

**ما لا يدخل:** لا تشغيل Commands/Hooks أو تشغيل MCP تلقائي عند تثبيت/تفعيل Plugin.
**بوابة القبول:** fixtures من أمثلة Plugin حقيقية، مسارات خبيثة، duplicate names، unknown fields، paths غير موجودة، إلغاء التثبيت/rollback، عدم تنفيذ أي أمر خلال import/inspect.

### PHASE 14C — MCP Base Protocol Compatibility & Skills over MCP

النطاق:
1. تدقيق التغييرات بين revisions 2025-11-25 و2026-07-28: initialize/session semantics، stateless transport، capability discovery، cancellation، HTTP headers، OAuth، resource reads.
2. دعم عدة revisions مع version negotiation واختبارات per-version؛ لا حذف دعم السيرفرات القديمة.
3. إضافة discovery للامتداد io.modelcontextprotocol/skills فقط عند إعلانه من الخادم.
4. إضافة typed skills/list وskills/get، pagination، TTL/cache scope، وresource manifest.
5. قراءة resources/read lazily والتحقق من size وSHA-256 وfrontmatter قبل تحميل Skill.
6. الهوية تكون pair(server identity, skill URI)، لا URI فقط. يجب ألا تطغى remote Skill على local Skill باسم مماثل.
7. approval binding إلى server identity + URI + complete resource digest set؛ تغير manifest يبطل الموافقة.
8. رفض/تحذير resources: dynamic حسب سياسة الثقة؛ وعدم معاملتها كمحتوى مضمون السلامة.
9. واجهة Remote Skills discovery metadata-first (14C.4) مع مصدر مُعرّف مسبقاً، HTTPS/DNS/IP pinning، موافقة منفصلة قبل list وقبل كل resource read، وعدم عرض المحتوى remote كـMarkdown أو تنفيذه. اجتازت 19 اختباراً مخصصاً في CI #193.
10. دعم MRTR / `InputRequiredResult` في 14C.5 للطلبات الثلاثة المسموح بها فقط (`prompts/get` و`resources/read` و`tools/call`)، مع capability-gated input handlers و`inputResponses` وrequest IDs جديدة وecho حرفي لـ`requestState` وحدود anti-loop.
11. دعم `subscriptions/listen` في 14C.5 بفلتر object محدد الحقول، وإقرار مرتبط بـ`_meta.subscriptionId`، وعزل الإشعارات حسب الفلتر والمعرّف، وإغلاق منظم؛ HTTP يلغي stream بإغلاق POST، وSTDIO يرسل `notifications/cancelled`. لا GET stream ولا Last-Event-ID resume. رفض server-initiated JSON-RPC requests في 2026 مع إبقاء التوافق القديم؛ log level يصبح per-request metadata، و`ping` و`logging/setLevel` و`roots/list_changed` القديمة لا تُرسل في 2026.
12. إبقاء استيراد Remote Skill إلى Local Registry وSkill-owned MCP lifecycle خارج Phase 14C؛ import/provenance وSkill-owned servers تتبع 14D.

**بوابة القبول:** compatibility matrix لكل إصدار؛ mock servers مطابقة للمواصفة؛ pagination/partial lists/cache invalidation؛ stale digest/frontmatter mismatch؛ URI collision بين خادمين؛ nested skills؛ رفض الموارد الزائدة؛ no connection/list/read without explicit consent؛ SSRF/DNS rebinding/redirect/cross-origin credential tests؛ no automatic install or execution؛ MRTR positive/negative and retry-state tests؛ subscriptions/listen ack/filter/stream/cancel tests؛ legacy revision regression suite.

### PHASE 14D — Skill-owned MCP Lifecycle (إغلاق 13Q.2–13Q.5)

هذه المرحلة تكمل الفجوة القائمة في Phase 13Q، ولا تعيد كتابة MCP Provider.

النطاق:
1. server owner = skill ID + source digest + capability ID + server ID.
2. server disabled افتراضياً؛ تسجيل credentials في secure store فقط، ولا تستورد env literals/headers/tokens من manifest.
3. اتصال stdio أولاً عبر Workspace/PRoot بعد موافقة؛ remote HTTP يحتاج SSRF/DNS/IP policy وموافقة host منفصلة.
4. tools/list ضمن count/schema/time bounds، وحفظ route namespaced تحت هوية المالك.
5. tools/call يحتاج approval مرتبط بهوية skill/server/tool/schema/digest لكل استدعاء حساس، حتى في Full Access.
6. إعادة التحقق من owner/digest/schema قبل وبعد async gaps.
7. إلغاء الاتصال وإيقاف العملية عند حذف Skill/تعطيلها/تحديثها/تغير digest أو revoke.
8. no orphan servers؛ لا تتصل خوادم Skills ببعضها تلقائياً.

**بوابة القبول:** integration test server حقيقي benign عبر stdio، plus hostile server cases؛ tools/list/call؛ approval/denial؛ update invalidates grant؛ delete cancels; process closed; secret redaction.

### PHASE 14E — Universal Tool Registry, Toolsets & Deferred Tool Exposure

النطاق:
1. إضافة واجهة Registry/Adapter موحدة فوق catalog/handlers الحاليين تدريجياً.
2. توحيد تعريفات metadata/schema/executor/permission policy/output/cancellation.
3. مستويات model exposure مستوحاة من Codex: direct/deferred/hidden، وإمكانية تحميل Toolset عند الحاجة دون تمرير كل schemas إلى النموذج.
4. Toolsets منطقية يمكن تركيبها حسب task/assistant/workspace/Skill، مع منع duplicate names عبر namespaces.
5. dynamic tools (MCP/Plugin/API) ترتبط بsnapshot ثابت أثناء دورة model turn؛ لا تبديل route في منتصف التنفيذ.
6. preserve provider-specific schema translators: OpenAI/Anthropic/Gemini/OpenRouter وغيرها. Registry لا يرسل schema غير صالح إلى مزود.
7. structured execution results موحدة: status/code, structuredContent, safe text, output refs, duration, retryability, error class.

**بوابة القبول:** parity tests لكل native tool موجود، collision tests، deferred loading token budgets، route snapshot consistency، approval policy tests، cancellation/output caps، no duplicate tool handlers.

### PHASE 14F — Agents, Commands, Hooks & Multi-Agent Orchestration

النطاق:
1. parse Agent/Command descriptors من Plugin.
2. بناء Agent executor فوق Tool Registry الموجود، وليس فوق shell مفتوح.
3. subagent scopes ومخرجات structured handoff وسياق محدود وbudget/timeout.
4. إسناد أدوات وصلاحيات لكل agent، والوكيل الأب يمنح least privilege فقط.
5. Hook registry للأحداث الداخلية المحددة، مع ordering وtimeouts وfailure policy.
6. Hook command execution يمر عبر نفس Runtime/approval/manifest/permissions؛ لا arbitrary code injection.
7. منع recursion/unbounded spawn وعدد subagents وتكلفة tokens.

**بوابة القبول:** agent handoff test، tool allowlist، deny privilege escalation، hook disabled by default، timeout/cancel، failure isolation، nested/recursive spawn blocked.

### PHASE 14G — Generic HTTP/API Connectors & Skill Workflows

النطاق:
1. Adapter declarative لـREST/HTTP method/url/headers/auth/input/output/retry/timeouts.
2. Credentials منفصلة لكل connector/provider/Skill scope، بلا نقل token إلى prompt أو log أو child process.
3. SSRF protection: scheme/host/IP/DNS/redirect policy، loopback/private/local-link rejection حسب الحالة، allowlisted host أو موافقة.
4. Workflow adapter يربط DAG الحالي وartifact ledger بعقود typed inputs/outputs.
5. تنفيذ خطوات workflow عبر Tool adapters الحالية، لا shell string حر من manifest.
6. دعم resumable stage state، idempotency, bounded parallelism, cancellation.

**بوابة القبول:** mock HTTP server، SSRF negatives، OAuth/secret handling، timeouts/retries، input/output schema, digest/artifact handoff، retry only failed stage، no duplicate side effects.

### PHASE 14H — Android Hardening, Compatibility & Release Acceptance

النطاق:
- قياس وقت/ذاكرة/قراءة الملفات/عدد schemas/token payload وحجم runtime.
- اختبار ARM64 device paths، PRoot profile وdisk pressure، killed app/Force Stop truthfully, notifications, cancellation.
- تثبيت تراخيص كل dependency وSBOM/provenance وsource pins.
- اختبارات CI محددة لكل مرحلة مع تشغيل Android JVM/Robolectric وEmulator وARM64 release حسب تأثير التغيير.
- سجل phase وREADME وMaster Plan وتقرير acceptance.

**بوابة القبول:** لا assertions متروكة، جميع حالات الفشل fail-closed، no automatic third-party process start، CI كامل ناجح، artifact hash، اختبار هاتف حقيقي للميزات التي تحتاج lifecycle Android، security review.

## 4. قيود واجبة طوال Phase 14

### Android/architecture
- Flutter/Dart أولاً؛ لا شرط وجود PC أو Docker أو Root على الهاتف.
- ARM64 هو APK الإنتاج؛ x86_64 يظل لمحاكي CI عند الحاجة.
- PRoot optional execution environment وليس kernel sandbox.
- لا ترفع حجم APK/native dependencies لأجل وظيفة اختيارية يمكن تشغيلها في PRoot أو عبر MCP.
- لا تدخل Node/Rust/Python agent host إلزامي في التطبيق.

### Security/trust
- لا تنفيذ عند import/inspect/compose/doctor/preview.
- عدم اتساع صلاحيات Plugin من خلال manifest أو أسماء الملفات.
- الموافقة منفصلة لكل عملية ذات side-effect؛ Full Access لا يتجاوز موافقة Skill execution الحرجة.
- عدم وضع secrets في prompts/logs/pending approvals/child environment.
- لكل Skill/Plugin/MCP/Tool source digest and provenance.
- HTTP requires SSRF defenses; remote MCP HTTPS alone is not sufficient.
- no promise that PRoot is full sandbox.

### Compatibility/data
- عدم إعادة كتابة SKILL.md أو خسارة الملفات الثنائية/المشتركة.
- لا حذف Skill Packs أو تغيير ملكية أعضاءها.
- schema migrations backward-compatible؛ preserve unknown fields.
- دعم إصدارات MCP القديمة خلال migration؛ لا breaking upgrade.
- أي مصدر أو capability غير مدعوم يظل inspectable ولا يعلن جاهزاً للتنفيذ.

### Licensing
- لا نسخ كود قبل فحص الترخيص الفعلي والملفات الفرعية.
- عدم نسخ من MCP protocol repo ما دام GitHub لا يعرض license assertion.
- لا إعادة توزيع anthropics/skills/openai/skills المحتوى دون التحقق من licenses لكل عنصر.
- توثيق third-party notices عند نسخ الملفات مع مراجعة AGPL compatibility.

## 5. خطة التنفيذ في أول تغيير برمجي

### قبول 14A وبدء 14B

اجتازت Phase 14A بوابة CI #162 في 25 نوفمبر 2026. الاختبارات المستهدفة Progressive Skill discovery، وFlutter Analyze، والحزم المحلية، واختبارات Android JVM/Robolectric ومحاكي 13P وبناء ARM64 كلها اكتملت بنجاح. سجل التشغيل التفصيلي في `phases/README.md`.

بدأت Phase 14B بعد إغلاق بوابة 14A، والنطاق الحالي:
1. `PluginManifest` و`PluginComponentDescriptor` بإصدار schema وتحقق من حقول manifest والمسارات.
2. قراءة Claude Plugin directory وZIP؛ حفظ unknown/unsupported fields كبيانات وتحذيرات بدلاً من إسقاطها.
3. رفض المسارات المطلقة وtraversal والروابط الرمزية والملفات الخاصة، مع حدود لحجم/عدد الملفات.
4. استخدام `ExtensionRegistryRepository` الحالي وسجل Parent Plugin واحد يحتوي descriptors؛ لا قاعدة بيانات أو سجل موازٍ للـSkills.
5. staging ثم إعادة فحص SHA-256 قبل cutover، مع backup/rollback عند فشل تحديث السجل أو الاستبدال.
6. عرض Plugins ومكوناتها من واجهة Workspace؛ حالات المكونات metadata-only.
7. اختبارات لملفات fixture، والمكونات المكررة، والحقول غير المدعومة، والمسارات الخبيثة/المفقودة، وZIP، وrollback، وعدم تشغيل Scripts.

**حدود 14B:** لا تنفيذ Commands أو Hooks أو Scripts ولا تشغيل MCP server عند الفحص أو الاستيراد أو التحديث. لا تعتبر المرحلة مقبولة قبل نجاح CI الجديد على التغييرات وفحص Android ARM64.

## 6. تعريف Done لكل مرحلة

لا تعتبر المرحلة مكتملة بإنشاء ملفاتها أو بنجاح تحليل الكود فقط. يجب أن يحتوي سجل المرحلة على:
- مصدر الفكرة والمراجع المثبتة والنسخة/الترخيص.
- الملفات التي تغيرت وما لم يتغير.
- اختبارات إيجابية وسلبية.
- سجلات CI IDs ونتيجة كل job.
- APK artifact/ABI/SHA عند وجود بناء.
- قيود Android/PRoot والتجارب غير المنفذة.
- قرار قبول صريح أو قائمة بنود معلقة.

## 7. سجل قرارات التدقيق

- 2026-11-24: اختيار main commit 9abb9dcc40881b005902265fdbd86d93248cb906 baseline بعد CI #139 نجاحاً كاملاً.
- لا دمج تطبيقات OpenCode/Codex أو Python agent frameworks كخدمات إلزامية.
- بدء Phase 14A أولاً لأنه يحسن performance/discovery في نظام قائم، ولا يضيف Runtime جديداً.
- MCP Skills over MCP لا يبدأ قبل base protocol compatibility.
- Plugin manifest parsing يأتي قبل تنفيذ hooks/commands/agents.
- كل مراحل 14B–14H تعتمد على نتائج بوابات المراحل السابقة؛ لا تنفذ بالتوازي إذا كان بينها dependency.
- 2026-11-25: اجتازت Phase 14A بوابة CI #162 بنجاح على commit `14c7938617ccaab7b38542caebb891f292c7ef18`; أصبح الانتقال إلى 14B مسموحاً بعد مراجعة run/jobs/steps وAPK artifact وSHA-256.
- 2026-11-25: بدأ تنفيذ Phase 14B فوق ExtensionRegistry الحالي. ملفات التنفيذ والاختبارات الأولية مسجلة في `PHASE-14B-PLUGIN-MANIFEST-COMPONENT-REGISTRY-AR.md`; القبول النهائي ينتظر CI بعد commit التنفيذ.

- 2026-11-26: اجتازت Phase 14C.3 integrity/lazy resource وHTTP response-body limits بوابة CI #187 على `cfd74942`. لم يكن ذلك قبولاً لـfull MCP 2026-07-28 compliance.
- 2026-11-26: اجتازت Phase 14C.4 Secure Remote Skills discovery UI بوابة CI #193 على main commit `924ea5a2`؛ 19 اختباراً مخصصاً، مع Android JVM/Robolectric وPhase13P Emulator وARM64 release artifact. لم يُثبت هذا الاختبار تشغيل هاتف ARM64 فعلي.
- 2026-11-26: بدأ استكمال 14C.5 MRTR و`subscriptions/listen` على فرع `phase-14c5-mrtr-subscriptions`; يتضمن تغيير protocol/client واختبارات package جديدة للـMRTR وحدود الإشعارات والاشتراك. لم يُشغّل CI على هذه التغييرات بعد؛ لا يبدأ Phase 14D ولا يدمج العمل إلى main قبل نجاح CI ومراجعة النتائج.
