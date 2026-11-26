# PHASE 13Q — موائم MCP المملوك للمهارات

**الحالة:** اجتازت 13Q.1–13Q.5 بوابات backend/lifecycle في CI #199 على `main`. اختبارات الملكية والموافقة و`tools/list` و`tools/call` وإبطال المصدر والتعطيل والحذف وإغلاق العملية ومحو الأسرار ناجحة. يجري توسيع دليل الخادم الفعلي والعدائي في Phase 14D؛ لا يعني هذا قبول عزل kernel أو تجربة Force Stop على هاتف فعلي.

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

أضيفت ملكية metadata ومخزن الأسرار والتحقق من المصدر، واجتازت مع اختبارات التكامل في CI #150:

- \`SkillMcpOwnerRegistry\` يحفظ سجلات مستقلة مرتبطة بـSkill ID وsource digest وcapability ID وServer ID.
- التسجيل يتطلب manifest صالحاً وبصمة مطابقة لكل ملف Skill؛ الملفات المضافة أو المعدلة أو المفقودة والروابط الرمزية تبطل التحقق.
- أسماء خوادم Skill لا تتكرر داخل المالك نفسه، وتسجل مجموعة descriptors كوحدة واحدة.
- كل التسجيلات disabled افتراضياً وmanual approval إلزامي.
- \`SecureSkillMcpSecretStore\` يستخدم flutter_secure_storage بمفاتيح مشتقة من هوية Skill/digest/server/variable؛ registry لا يخزن قيم الأسرار.
- استيراد Skill وقراءة manifest لا يبدأان أي خادم.

واجهة التسجيل: \`SkillsService.registerDeclaredSkillMcpConfig(skillId, configPath)\`. يتحقق المسار ونوع الملف ووجود capability معلنة قبل حفظ الملكية.

**دليل القبول:** CI #150، خطوة \`Run Phase 13Q Skill MCP configuration discovery tests\`، بما فيها استيراد Skill فعلي وتسجيل capability مع digest بصيغة manifest الحقيقية.

### 13Q.3 — اتصال واكتشاف

اجتازت بوابة الاتصال في CI #150:

- \`SkillMcpConnectionService.connect()\` لا يبدأ عملية stdio قبل موافقة صريحة تعرض الأمر والوسائط وأسماء متغيرات البيئة والبصمة ونطاق الملفات وتحذير PRoot.
- يعاد فحص المالك والبصمة وحالة Skill قبل النسخ وقبل التشغيل وبعد المصافحة.
- ينسخ فقط ملفات manifest من نوع Skill إلى مجلد جلسة مؤقت، ويتحقق من SHA-256 والحجم قبل النسخ وبعده.
- لا يربط مجلد Skills الأصلي ولا Workspace المستخدم؛ يربط نسخة الجلسة فقط عند \`/workspace\`.
- لا ترث العملية أسرار Environment العامة؛ تمرر فقط بيئة تشغيل أساسية وأسرار Skill المصرح بها، مع حظر أسماء البيئة المحجوزة.
- الجلسة لا تحفظ في \`mcp_servers_v1\` وتظل مخفية عن إعدادات MCP وتصديره.
- بعد الاتصال، تنفذ \`tools/list\` وتُحفظ أدوات الخادم في الذاكرة لجلسة Skill، دون تسجيل دائم.
- HTTP/SSE يظلان مرفوضين حتى تكتمل حماية DNS/SSRF وموافقة المضيف.

**قيد صريح:** PRoot ليس kernel sandbox؛ ما زال rootFS المشترك قابلاً للكتابة والشبكة غير مقيدة بالكامل. نجاح المحاكي لا يثبت عزل نظام التشغيل أو اختبار Force Stop على هاتف المستخدم.

### 13Q.4 — استدعاء الأدوات

أضيف مسار منفصل للأدوات التي تملكها Skill، ولا يفتح بوابة استدعاء MCP العامة:

- \`McpProvider.listSkillOwnedTools()\` يعيد الأدوات من جلسة Skill محددة بعد التحقق من Skill ID وowner Server ID وsource digest وحالة الاتصال.
- أسماء العرض namespaced على صورة \`skill_<tool>_<digest>\` ومشتقة من Skill ID وowner ID وdigest وtool name، لتجنب التصادم بين المهارات والخوادم.
- \`SkillMcpConnectionService.listTools()\` يعيد descriptors الخاصة بالجلسة وحدها.
- \`SkillMcpConnectionService.callTool()\` يتطلب callback موافقة صريحة لكل استدعاء؛ لا يتجاوز Full Access هذه الموافقة.
- يعاد التحقق من ملكية Skill والبصمة ومخطط الأداة بعد نافذة الموافقة وقبل التنفيذ، ثم من هوية الجلسة والمخطط مرة أخرى حول طلب MCP غير المتزامن.
- التحقق من JSON Schema يشمل الأنواع والحقول المطلوبة وenum/const وallOf/anyOf/oneOf والحدود الأساسية للقيم، مع رفض remote refs والمخططات المركبة أو الكبيرة.
- حدود صلبة: 128 أداة للخادم، 64 KiB للمخطط والمدخلات، 64 عنصر محتوى و256 KiB للمخرجات.
- تنقح معاينة الموافقة والمخرجات من أسماء الحقول الحساسة والقيم المحفوظة للأسرار.
- سجل JSONL محدود ومدوّر يسجل هوية الأداة وقرار الموافقة والنتيجة والمدة ونوع الخطأ فقط؛ لا يخزن الوسائط أو المخرجات أو الأسرار.
- \`McpProvider.callTool()\` العام يظل حاجباً لاستدعاءات Skill، ولا يمكن تجاوز البوابة الجديدة من شاشة MCP التقليدية.

**نطاق التنفيذ الحالي:** هذه واجهات backend جاهزة لمستهلك يقدّم نافذة الموافقة عبر callback. دمج الواجهة المرئية/اختيار Skills داخل تدفق محادثة المساعد واختبار تجربة المستخدم الفعلية لا يُعلن نجاحه بمجرد نجاح اختبار الخدمة.

**حالة القبول:** اجتازت واجهات الخلفية واختبارات namespace و`tools/list` و`tools/call` والموافقة المنفصلة والتحقق من schema وتنقيح الأسرار وسجل التدقيق بوابة CI #154. دمج نافذة موافقة مرئية في واجهة المحادثة ليس جزءاً من اختبار backend الحالي، ويظل عملاً واجهياً منفصلاً قبل ادعاء اكتمال تجربة المستخدم.

### 13Q.5 — الإلغاء

أضيف مستمع دورة حياة في \`SkillMcpConnectionService\` وينتظر بوابة CI:

- عند \`SkillsService.setEnabled(skillId, false)\` تُغلق كل جلسات MCP الحية التابعة للمهارة ويُنهى Workspace stdio process وتُحذف نسخة الجلسة؛ تبقى بيانات الدخول المشفرة مرتبطة ببصمة المصدر حتى إعادة التفعيل.
- عند \`SkillsService.delete(skillId)\` أو إزالة سجل الملكية أو بطلان manifest/source digest تُلغى الجلسة وتُحذف نسخة الجلسة وتُمسح بيانات الدخول القديمة المرتبطة بالبصمة.
- تعديل \`SKILL.md\` أو أي ملف من ملفات manifest يجعل \`registrationsForSkill\` يرفض البصمة القديمة؛ يكتشف المستمع ذلك ويغلق الاتصال. لا يعاد استخدام أسرار الإصدار القديم مع مصدر جديد.
- جميع مسارات الإغلاق اليدوي، والإغلاق التلقائي، و\`dispose()\` تستخدم teardown موحداً idempotent.
- التحقق يجري على snapshot المملوك في الذاكرة، ولا يسمح لخادم Skill بتحديد جلسة خادم آخر أو حذفها.
- يستمر تنظيف مجلدات الجلسات اليتيمة عند تشغيل الخدمة بعد إنهاء التطبيق بالقوة.

**حدود التحقق:** محاكي CI يختبر أحداث disable/update/delete وإيقاف العملية وحذف نسخة الجلسة. لا يثبت ذلك Force Stop على هاتف المستخدم أو عزل PRoot على مستوى kernel.

**حالة القبول:** التنفيذ والاختبارات مضافة إلى \`main\`؛ ينتظر نجاح Flutter Analyze وPhase 13Q وRobolectric ومحاكي Android وبناء ARM64 في CI.


## الأمان
لا بدء MCP عند import أو inspect أو requirements أو readiness أو compose. لا تنفيذ command/args من بيانات Skill قبل الموافقة والتحقق. لا استيراد env literals أو headers/tokens. PRoot ليس sandbox ولا تقيد شبكة الضيف تلقائيًا. لا يسمح لخادم Skill بالوصول إلى خوادم Skills الأخرى.

## القبول

- نجاح اختبارات parser والملكية والاتصال وtools/list وtools/call المرتبطة بهوية Skill/server/digest.
- لا إنشاء أو اتصال خادم عند الاستيراد أو الفحص أو compose.
- connect يتطلب موافقة يدوية؛ ونسخة الجلسة فقط هي التي تُربط بـWorkspace.
- tools/list يعرض فقط أدوات الجلسة المالكة، وبأسماء namespaced ثابتة.
- tools/call يتطلب موافقة منفصلة حتى عند Full Access؛ تغيير المصدر أو المخطط بعد الموافقة يمنع التنفيذ.
- مخططات ومدخلات ومخرجات محدودة الحجم والتعقيد، مع تنقيح أسرار وسجل تدقيق لا يحتوي الحمولة.
- تغير المصدر أو تعطيل/حذف Skill يبطل الاتصال فوراً، وقد اجتازت اختبارات هذا السلوك في CI #199.
- توثيق اختبار المحاكي وحدود التحقق على الجهاز الفعلي.



## سجل القبول — CI #154 (24 نوفمبر 2026)

نجح التشغيل [#154](https://github.com/m5ham3ds/KELIVO/actions/runs/45459799636) على commit \`b9b0c104f03db03f132ca137e8baf25ca6bc475e\`.

- جميع خطوات job البناء اكتملت بنجاح، وكذلك job إنشاء تقرير Markdown.
- Flutter Analyze، واختبارات Phase 13Q بما فيها tools/list وtools/call، وRobolectric، ومحاكي Phase 13P، وبناء ورفع APK ARM64: نجاح.
- APK Artifact: \`14954456167\`، الحجم 40,654,079 bytes، ABI واحد \`arm64-v8a\`.
- SHA-256: \`594ed705b5594c0c39abe7fa3960871f219f0c11de38aed5b74c03c2736459a9\`.
- النطاق المقبول: 13Q.1–13Q.4 من جهة backend والاختبارات. 13Q.5 قيد التنفيذ، كما أن نافذة الموافقة المرئية في واجهة المحادثة لم تثبت في هذا التشغيل.

## سجل القبول — CI #150 (24 نوفمبر 2026)

نجح التشغيل [#150](https://github.com/m5ham3ds/KELIVO/actions/runs/45446237776) على commit \`b4dcb3430743eeee6e6022a797bcc5e6a899bf5b\`.

- نجحت خطوات Phase 13Q، Android JVM/Robolectric، Phase 13P Android Emulator E2E وبناء ورفع ARM64 APK.
- اختبار 13Q شمل استيراد Skill ومطابقة manifest الحقيقي، رفض الاتصال دون موافقة، اتصال stdio بعد الموافقة، عزل أسرار Environment، ومجلد الجلسة الخاص.
- APK Artifact: \`14948111971\`; SHA-256: \`920d06177a307f2bdcda48d8c3f845231ce6b9903c4dcbad1459d2b993b548d1\`.
- **النطاق المقبول:** 13Q.1 و13Q.2 و13Q.3. لا يثبت CI #150 تطبيق موافقة الأدوات؛ هذا نطاق 13Q.4.


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
