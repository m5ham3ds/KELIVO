# PHASE 14 — تدقيق مستودع KELIVO ومصفوفة الاستفادة من المشاريع المفتوحة المصدر

**تاريخ التدقيق:** 24 نوفمبر 2026  
**المستودع:** https://github.com/m5ham3ds/KELIVO  
**الفرع:** main  
**Commit خط الأساس:** 9abb9dcc40881b005902265fdbd86d93248cb906  
**حالة التغييرات أثناء التدقيق:** لم تُعدّل ملفات التطبيق أو الاختبارات. هذا التسليم يضيف وثائق التدقيق والخطة وفهرس الشجرة فقط.

## 1. الملخص التنفيذي

KELIVO لا يبدأ من الصفر في موضوع Skills أو Tools. لديه مستورد Agent Skills، ومانيفست وبصمات للمصدر، وتحليل متطلبات، وCapability Registry، ومحرك جاهزية، ومخطط تركيب DAG، ومنفّذ Python/Bash/Node، وRuntime Profiles، وPackage Manager، وWorkspace tools، وMCP Client/Provider، وBrowser tools، وموصلات فيديو وWorkflow خاصة بالإنتاج.

الفجوة الرئيسية ليست عدم وجود نظام مهارات، بل أن بعض طبقات النظام ما زالت منفصلة أو لا تغطي كل أنواع القدرات: Plugin bundles، وSkill-owned MCP lifecycle، وHTTP/API adapters العامة، وtool discovery/dispatch الموحدة، وHooks وAgents/Subagents، وإدارة عرض تعريفات الأدوات بصورة مؤجلة، وتوافق MCP Skills over MCP الأحدث.

القرار الهندسي: **تطوير المكونات الحالية وتوصيلها، لا استبدال KELIVO بمنصة OpenCode أو Codex كاملة، ولا إضافة Runtime إلزامي مكتوب بـTypeScript أو Rust أو Python إلى APK.** نستفيد من المواصفات والأفكار، ونقتبس كوداً فقط بعد مراجعة الملف والترخيص والاعتماديات وملاءمته لـDart/Android.

## 2. خط الأساس وجرد الملفات

مصدر الأرقام هو Git Trees API للـcommit المثبت أعلاه، مع truncated=false. جميع المسارات ممثلة في ملف الفهرس الآلي:

[PHASE-14-REPOSITORY-TREE-MANIFEST-2026-11-24.json](PHASE-14-REPOSITORY-TREE-MANIFEST-2026-11-24.json)

| المؤشر | العدد |
|---|---:|
| الملفات (blob) | 4,237 |
| المجلدات (tree) | 634 |
| مجموع العناصر | 4,871 |
| مجموع أحجام الملفات المسجلة في Git | 60,883,091 بايت |
| ملفات Dart | 3,127 |
| ملفات Markdown | 224 |
| ملفات Java | 159 |
| ملفات Kotlin | 74 |
| ملفات JSON | 126 |
| ملفات YAML | 30 |
| ملفات Shell | 85 |
| ملفات Python | 11 |

توزيع الملفات حسب الجذر الأعلى:

| المسار | الملفات |
|---|---:|
| lib/ | 1,240 |
| test/ | 1,228 |
| dependencies/ | 1,123 |
| android/ | 139 |
| assets/ | 101 |
| .github/ | 100 |
| phases/ | 89 |
| integration_test/ | 55 |
| test_goldens/ | 54 |
| tool/ | 43 |
| docs/ | 40 |
| drift_schemas/ | 4 |
| test_driver/ | 2 |

**طريقة قراءة الجرد:** كل ملف ومجلد له مسار ونوع وGit object SHA في manifest؛ ملفات blob معها الحجم. هذا فهرس كامل للشجرة عند commit الأساس، وليس ادعاء أن محتويات كل أصل صورة أو خط أو كل سطر في كل ملف غير ذي صلة قد تمت مراجعته يدوياً. القراءة العميقة في هذا التقرير تغطي الأنظمة المؤثرة في Skills/Plugins/Tools/Agents/MCP/Runtime/Browser والاختبارات والـCI، وتربط النتائج بمسارات فعلية.

## 3. خريطة الأنظمة الحالية

### 3.1 Skills import/catalog/lifecycle

**الملفات المحورية**
- lib/core/services/skills/skills_service.dart — 4,558 سطراً في لقطة التدقيق؛ استيراد نصوص وملفات ومجلدات وZIP وGitHub repositories/subfolders وskills.sh، البحث والفحص والتحديث والrollback والتصدير والحذف والتفعيل، Skill Packs والموارد المشتركة، تقارير الاستيراد والـsidecars.
- lib/core/services/skills/skill_archive.dart — فك الأرشيف مع حدود للمسارات والحجم والروابط الرمزية.
- lib/core/services/skills/skill_frontmatter.dart — تحليل Agent Skills frontmatter والحقول القياسية وغير المعروفة.
- lib/core/services/skills/skill_import_manifest.dart — Manifest كامل للمسارات والأحجام والأنواع والبصمات ومصدر الإصدار، مع Capability descriptors وإعلانات التبعيات.
- lib/core/services/skills/skills_catalog_adapter.dart — موائم skills.sh.
- lib/core/services/skills/skill_compatibility.dart — كشف التوافق والتحذيرات.
- lib/core/services/extensions/extension_command_tools.dart — أدوات المحادثة extension_search/inspect/install/update/checkUpdates/enable/disable/remove/rollback/list.

**الموجود فعلاً**
- استيراد من GitHub/ZIP ومجلد محلي وملفات Skills ومصادر skills.sh.
- الحفاظ على الملفات الداعمة، بما فيها scripts/references/assets والملفات الثنائية في مسارات ZIP/المجلد.
- source provenance وcommit/ref وSHA/manifest وتقارير ما تم حفظه أو تخطيه.
- تحديث وrollback وSkill Packs منفصلة عن هوية كل Skill.
- فحص المتطلبات بقراءة فقط؛ لا يشغل السكربتات ولا يثبت التبعيات ولا يبدأ MCP خلال import/inspect.

**حدود يجب ألا نكرر تطويرها**
- لا نحتاج مستورداً ثانياً للمهارات من GitHub.
- Skill Pack ليس Plugin bundle متعدد الأنواع؛ هو تنظيم لمجموعة Skills.
- دعم skills.sh ليس مساوياً لقراءة كل الأصول الثنائية في أي مستودع.
- لا تتحول ملفات tools/ أو إعداد MCP إلى أدوات قابلة للتشغيل لمجرد وجودها.

### 3.2 Capability registry/readiness/doctor

**الملفات**
- lib/core/services/skills/skill_capability_registry.dart
- lib/core/services/skills/skill_readiness.dart
- lib/core/services/skills/skill_requirements.dart
- lib/core/services/skills/skill_doctor_service.dart
- lib/core/services/skills/skill_import_manifest.dart

**الموجود**
- تصنيف instruction_only وlocal_script وcli_binary وmcp_server وhttp_api_connector وnative_kelivo_tool وworkflow.
- تحليل متطلبات runtimes/CLI/package manifests وأسماء env variables والمضيفين دون استخراج قيمة سر أو الاتصال بالخدمات.
- readiness stages وحالات صريحة وأدلة مرتبطة ببصمة المصدر.
- Skill Doctor لفحص اكتمال الاستيراد والتبعيات وملفات التشغيل وسجلات Runtime Profiles.

**الفجوة**
- أنواع mcp_server وhttp_api_connector وworkflow وnative_kelivo_tool تحتاج موائمات أو تطويراً مستقلاً؛ descriptor وحده لا يضيف مشغلاً.
- يجب أن يظل Capability Registry مستقلاً عن تعريفات الأدوات التي يرسلها كل مزود نموذج.

### 3.3 Composition وSkill execution

**الملفات**
- lib/core/services/skills/skill_composition_planner.dart
- lib/core/services/skills/skill_composition_service.dart
- lib/core/services/extensions/skill_composition_tools.dart
- lib/core/services/skills/skill_executor.dart
- lib/core/services/extensions/skill_execution_tools.dart
- lib/core/services/skills/skill_execution_permissions.dart
- lib/core/services/skills/skill_execution_security.dart

**الموجود**
- Planner يحدد Skills المطلوبة ويحل dependencies/conflicts وartifact contracts وDAG stages، ويدعم parallel stages.
- الحد الحالي للمرشحين 64، والـcontext budget الافتراضي 6,000 token وبحد أعلى 32,000.
- Executor يشغل entry points المعلنة فقط لامتدادات Python/Bash/Node، ويعيد execution record وexit code والمخرجات وبصماتها.
- staged source/input/output/temp paths، تحقق manifest/digests وعقود المخرجات، limits وtimeout/cancellation.
- موافقة يدوية لكل Skill run حتى في Full Access، مع إخفاء أسرار Android وبيئة المستخدم من عملية الضيف.

**ملاحظة أداء واضحة**
- skill_composition_service.dart يقرأ حالياً محتوى SKILL.md لكل مرشح (حتى 64 مرشحاً وبحد قراءة 64,000 حرف لكل مرشح) قبل اختيار المجموعة. لكن scoring في skill_composition_planner.dart يعتمد على الاسم/ID/الوصف وkelivo.tags الموجودة في frontmatter. هذه نقطة تكرار تحميل يمكن تحويلها إلى metadata-first selection ثم جلب التعليمات للـSkills المختارة فقط، مع حساب budget بعد جلب المحتوى.
- skills_prompt.dart يعرض افتراضياً أول 20 Skill فقط بالاسم والوصف المختصر؛ يمكن البحث عن المثبت عبر extension_search حتى إن لم يظهر في القائمة. الاختيار الصريح لما بعد الحد له مسار خاص. ينبغي جعل الاكتشاف المؤجل واضحاً للنموذج دون تحميل 1000 وصف في prompt.
- لا يجوز إسقاط فحص اكتمال manifest أو source digest أو تعارضات الـfrontmatter/contract أثناء تحسين التحميل المؤجل.

### 3.4 Runtime Profiles/package/environment

**الملفات**
- lib/core/services/runtime_profiles/runtime_profile_service.dart
- lib/core/services/runtime_profiles/runtime_profile_models.dart
- lib/core/services/runtime_profiles/runtime_profile_tools.dart
- lib/core/services/packages/package_manager_service.dart
- lib/core/services/packages/package_manager_models.dart
- lib/core/services/packages/dependency_manifest_parser.dart
- lib/core/services/packages/dependency_resolver.dart
- lib/core/services/sandbox/*
- lib/core/services/workspace/workspace_runtime.dart

**الموجود**
- Runtime Profiles بنطاق project/extension/task، وبيئات Python/Node منفصلة على مستوى package roots، وحفظ snapshots وسجل عمليات وإلغاء.
- Package Manager يدعم apt/apk وpip/uv وnpm/pnpm/yarn/bun، ويدعم plan/check/install/upgrade/remove/pin/unpin/list.
- Media tools وFFmpeg/FFprobe وبيانات الموارد موجودة ضمن امتدادات البيئة/العمليات كما هو موثق في Phase 13C و13R.
- Android PRoot يوفر Linux userland؛ لا يساوي Docker ولا عزل kernel.

**الحدود**
- في Android الحالي يوجد RootFS واحد نشط مشترك؛ اختيار التوزيعة يبدله، ولا ينشئ Ubuntu/Alpine/Debian متوازية.
- تعدد Runtime Profiles لا يعني تعدد إصدارات Python/Node binaries.
- حدود CPU/memory/output بعضها best-effort أو فحوص بعد التنفيذ، لا حصص kernel مضمونة.
- PRoot RootFS مشترك وقابل للكتابة، واتصال الشبكة ليس مقيداً بالكامل. لا توصف البيئة بأنها Sandbox آمنة لسكربت غير موثوق.

### 3.5 Native tools/dispatcher/model loop

**الملفات**
- lib/core/services/tools/built_in_tool_catalog.dart
- lib/core/services/api/builtin_tools.dart
- lib/features/home/services/tool_handler_service.dart
- lib/core/services/api/generation/tool_loop_runner.dart
- lib/core/services/workspace/workspace_tools_service.dart
- lib/core/services/extensions/extension_command_tools.dart
- lib/core/services/extensions/skill_execution_tools.dart

**الموجود**
- كتالوج مركزي يربط Search/Web Fetch/Memory/Local/Workspace/Extensions/Skill composition/Skill execution/Package Manager/Environment/Video tools.
- Provider-specific schemas وتحويل/تنقية التعريفات حسب مزود النموذج.
- Tool handler يوجّه MCP وWorkspace وBrowser وSkills وPackages وVideo tools والخدمات الأصلية.
- دورة tool calls تفك الاستدعاءات المنظمة ثم تنفذ handler وتعطي نتائج منظمة وتكرر الجولة. مسار تنفيذ client tool الحالي في tool_loop_runner.dart يمر على الاستدعاءات بالتتابع، وليس نظام Toolset عام أو event plugin system.

**الفجوة**
- لا يوجد بعد سجل موحد لامتدادات Plugin متعددة المكونات (command/agent/hook/mcp/skill) يملك دورة lifecycle الخاصة بها.
- لا تزال تعريفات native tools مبنية في كتالوجات مميزة؛ يجب تجنب refactor شامل قبل وضع واجهة Registry موحدة واختبارات تطابق provider schemas.
- أدوات MCP ديناميكية ومُستثناة من overrides الثابتة عمداً؛ يجب إبقاء route snapshot وnamespace حتى لا تتغير أداة منشورة خلال جولة النموذج.

### 3.6 MCP

**الملفات**
- lib/core/providers/mcp_provider.dart
- lib/core/services/mcp/mcp_tool_service.dart
- lib/core/services/mcp/workspace_stdio_transport.dart
- lib/core/services/mcp/stdio_command_resolver.dart
- lib/core/services/skills/skill_mcp_config.dart
- dependencies/mcp_client/

**الموجود**
- transports: stdio وHTTP/SSE/inmemory بحسب الإعداد.
- OAuth، connection/session handling، اكتشاف tools/list، واستدعاء tools/call.
- tool routing للمساعد/المحادثة مع namespacing لتعارض الأسماء وموافقات الأداة.
- stdio يمر عبر Workspace runtime ويستخدم قنوات stdin/stdout خاماً.

**الفجوة المحددة**
- skill_mcp_config.dart محلل metadata للقراءة فقط، وليس Skill-owned server adapter.
- Phase 13Q.1 فقط لديها اختبار parser؛ 13Q.2–13Q.5 مفتوحة: ownership/digest، connection وtools/list، tools/call وموافقات مستقلة، الإلغاء عند التغيير/الحذف/التعطيل.
- dependencies/mcp_client محلي ومثبت عبر path dependency، والإصدارات المدعومة فيه حتى 2025-11-25. لا يوجد فيه حالياً skills/list أو skills/get أو تفاوض على Skills extension.
- إضافة MCP Skills extension تحتاج أولاً مراجعة base protocol revision 2026-07-28 لأن التغيير ليس مجرد إضافة method؛ يجب اختبار طريقة initialize/session/transport لكل إصدار مدعوم وعدم كسر servers القديمة.
- هوية Skill مصدرها MCP يجب أن تكون هوية الخادم + URI؛ لا يجوز الاعتماد على URI منفردة.

### 3.7 Browser/API/Workflow

- KELIVO لديه lib/core/services/browser/browser_service.dart وbrowser_tools_service.dart وواجهات Browser، مع عدد كبير من الاختبارات. لذلك Playwright لا يُضاف باعتباره Browser جديداً قبل تحديد ما إذا كانت هناك فجوة حقيقية؛ يمكن دراسة Playwright MCP كموائم اختياري لاحتياجات Playwright محددة.
- KELIVO لديه موصلات فيديو وREST خاصة بمزودي الفيديو في video_providers، وWorkflow hybrid في video_hybrid، وطبقة engines/production/quality. هذه ليست موائم HTTP/API أو workflow عاماً لأي Skill.
- HTTP/API connector وSkill declared workflow ما زالا نوعين يحتاجان adapter عام بعقد واضح، أو يظلان adapter_required.
- Composio خدمة تكامل خارجية اختيارية، وليست متطلباً أساسياً؛ يجب تقييم مفاتيح الربط ومكان معالجة OAuth والخصوصية والاعتماد على الخدمة.

### 3.8 الاختبارات وCI

- توجد 83 ملفات اختبار تطابق مباشرة مجالات Skills/Extensions/MCP وفق مسارات أسماء الاختبارات في Git tree.
- توجد أيضاً مجموعة أوسع من اختبارات MCP/Browser/Workspace/Runtime/Package Manager، وهي ليست كلها مكررة مع المجموعة السابقة.
- يوجد اختبار E2E للمسار الحقيقي على Android: ZIP Skill -> manifest -> Runtime Profile -> approval -> Bash execution -> output digest/readback -> background service؛ CI #139 شغّل بوابة Phase 13P emulator ونجحت.
- .github/workflows/android-build.yml يشغّل Flutter Analyze، اختبارات البيئة، Gemini/OAuth، Phase 13Q parser، الحزم المورّدة، Android JVM/Robolectric، Phase 13P Emulator E2E، وARM64 Release. لا يشغّل كل Flutter root unit/widget suite ولا كل runners التاريخية 13A–13O في كل Push.
- يجب ألا نصف tests غير المنفذة على أنها مقبولة بمجرد وجود ملفاتها.

## 4. أحدث بناء مثبت

[CI #139](https://github.com/m5ham3ds/KELIVO/actions/runs/45324592200) على commit 9abb9dcc40881b005902265fdbd86d93248cb906 مكتمل بالنتيجة success.

| المرحلة | النتيجة |
|---|---|
| Android-only audit وتهيئة Flutter وحل الاعتماديات | نجاح |
| فحوص الترجمة العربية وتوليد l10n | نجاح |
| Flutter Analyze | نجاح |
| Environment install lifecycle regressions | نجاح |
| Gemini schema + Google/Hugging Face OAuth regression | نجاح |
| Phase 13Q read-only MCP configuration discovery | نجاح |
| اختبارات الحزم المحلية المورّدة | نجاح |
| Android JVM/Robolectric | نجاح |
| Phase 13P Android Emulator Skill E2E | نجاح |
| ARM64 APK + checksum + upload | نجاح |
| تقرير CI ورفع السجلات | نجاح |

- APK: Kelivo-Android-arm64-v8a-1.3.4+84-release.apk
- حجم APK: 40,654,046 bytes.
- SHA-256 للـAPK: 87c7af532a481441523ca9e83f1b57807ec606706ae1ef327ee1a98e2e8cb51c.
- Artifact ID: 14890431605.
- APK واحد arm64-v8a فقط بحسب خطوة التحقق.
- سجل البناء يذكر أن غياب android/key.properties يعني استخدام debug key؛ هذا artifact قابل للتثبيت والاختبار وليس ادعاء توقيع متجر عام.
- اجتياز CI لا يعادل اختبار الهاتف الفعلي أو Force Stop، ولا يغلق 13Q.2–13Q.5.

## 5. مقارنة المشاريع المفتوحة المصدر

المستودعات التالية فُحصت على فروعها الفعلية وملفات المصدر/المواصفات ذات الصلة بتاريخ 24 نوفمبر 2026. رؤوس الفروع المتحركة المثبتة وقت الفحص موضحة أدناه؛ يجب تحديثها وإعادة فحص الترخيص قبل نسخ أي كود.

| المشروع/المصدر | الإصدار المثبت وقت المراجعة | الترخيص المعلن على GitHub | قيمة الاستفادة لـKELIVO | القرار |
|---|---|---|---|---|
| [OpenCode](https://github.com/anomalyco/opencode) | dev @ 30ef864fe7202a5d85e112cdd3eb7af0e064db42 | MIT | Skill discovery tool وlazy load، Tool Registry/permissions/hooks/MCP | مرجع معماري أساسي؛ كود TypeScript/Effect/Bun لا يدمج كحزمة Flutter كاملة |
| [OpenAI Codex](https://github.com/openai/codex) | main @ 96681d86f08f880ed12ba29044e855002809e0d1 | Apache-2.0 | Tool Router direct/deferred/hidden، tool budgets، Plugin manager، Skills watcher، MCP dependency approval، app-server events | مرجع لمحرك الوكيل؛ Rust CLI كامل غير مناسب كاعتماد إلزامي |
| [Claude Plugins Official](https://github.com/anthropics/claude-plugins-official) | main @ 5cec6716767283f4675a05f5f8855b5b49c81783 | Apache-2.0 على مستوى المستودع؛ تحقق من كل Plugin فرعي | manifest وحزمة commands/agents/skills/hooks/MCP ومكونات plugin-dev toolkit | التوافق مع manifest واستخراج الأفكار؛ لا تشغل hooks أو MCP تلقائياً |
| [Agent Skills](https://github.com/agentskills/agentskills) | main @ 83021e2be457a9b6679148719c1f6074f0ad975e | Apache-2.0 | المواصفة المرجعية وvalidator وprogressive disclosure وأفضل ممارسات SKILL.md | KELIVO يدعم أجزاء واسعة؛ استكمال توافق واختبارات دون إضافة Python validator إلزامي |
| [MCP Skills over MCP](https://github.com/modelcontextprotocol/ext-skills) | main @ 0daf88cf65b3ce45b75a8c76e05564561d758a62 | Apache-2.0 | Skills موزعة عبر MCP skills/list/get وresources/read وdigests | دعم بعد ترقية/توافق base MCP؛ المواصفة حالياً Beta |
| [MCP Protocol repository](https://github.com/modelcontextprotocol/modelcontextprotocol) | main | GitHub لا يعرض ترخيصاً موثقاً (NOASSERTION) | قراءة المواصفة وتغيرات النقل والقدرات | مرجع مواصفة فقط؛ لا تنسخ كود المستودع حتى يثبت الترخيص |
| [Vercel Skills CLI](https://github.com/vercel-labs/skills) | main @ 57217cf86ba38148a57af9e90d14a4c049558330 | MIT | lockfile، commit pinning، folder hash، update/sync/rollback | نقل نموذج lockfile إلى Dart؛ لا تضف Node CLI كشرط للتطبيق |
| [PydanticAI](https://github.com/pydantic/pydantic-ai) | main @ 853cb5901a3566f47f3d483a8a7f49dff4d41e86 | MIT | Toolsets composition، deferred tools، approvals وresult contracts | نقل الأنماط المفيدة؛ لا تضف Python agent stack داخل APK |
| [smolagents](https://github.com/huggingface/smolagents) | main @ 5107d3aec21d26ed808aabd95d93a63d4244226f | Apache-2.0 | الفصل بين ToolCallingAgent وCodeAgent والتخطيط والتنفيذ المركب | مرجع تجريبي؛ أي Python runtime يبقى optional في PRoot |
| [Playwright](https://github.com/microsoft/playwright) | main | Apache-2.0 | Browser automation وPlaywright MCP | لا تكرر Browser الموجود؛ قيّم كخادم MCP اختياري فقط عند حاجة واضحة |
| [Composio](https://github.com/ComposioHQ/composio) | next | MIT | تكاملات خدمات طرف ثالث ومصادقة عبر موائمات | تكامل خارجي اختياري، ليس أساساً ولا شرطاً |
| [Anthropic Skills](https://github.com/anthropics/skills) و[OpenAI Skills](https://github.com/openai/skills) | فروع main | GitHub لا يعرض ترخيصاً عاماً للمستودعين | عينات محتوى وطرق بناء Skills | لا تنسخ أو تعيد توزيع محتواها قبل التحقق من ترخيص كل Skill ومصدره |
| [obra/superpowers](https://github.com/obra/superpowers) | main | راجع ترخيص الإصدار قبل التوزيع | منهجيات planning/TDD/debugging وتفويض المهام | محتوى/منهجية مرجعية اختيارية، ليست محرك تنفيذ |

### 5.1 نتائج عملية من OpenCode

- يعرض قائمة مهارات صغيرة بالـID/name/description، ويحمّل جسم Skill عند استدعاء أداة Skill، لا يحقن كل ملفات الدعم تلقائياً.
- يفصل تعريف الأداة وschema عن تنفيذها وpermission policy.
- لديه طبقات سماح/طلب/منع ومفهوم Hooks للأحداث.
- هذا يناسب تحسين KELIVO دون إعادة كتابة خادم Flutter؛ يجب إعادة استخدام SkillsService وTool handler الحاليين وإضافة القراءة المؤجلة والـpolicy المشتركة.

### 5.2 نتائج عملية من Codex

- يفصل بين الأداة المسجلة والأداة المعروضة للنموذج: direct/deferred/hidden وما شابه.
- يحافظ على ميزانية أدوات وسياق، ويعرض مساحة أسماء الأدوات المؤجلة عند الحاجة.
- Plugin manager يملك lifecycle ومصادر متعددة، وSkills watcher يحدث Skill state ويصدر events.
- MCP dependencies تُحل وفق policy-aware catalog مع طلب موافقة قبل التثبيت أو OAuth.
- أفضل ما يُنقل هو تصميم ToolRouter/visibility والـapp-server events، وليس كامل Rust workspace.

### 5.3 نتائج عملية من Claude Plugins

- Plugin package يجمع manifest وcommands وagents وskills وhooks وMCP configuration في حزمة واحدة.
- plugin.json يعرّف الهوية والمسارات؛ وتظل المكونات في مساراتها المتفق عليها.
- Hooks تغطي أحداث Session/Prompt/ToolUse/Stop/Subagent؛ وهذه قدرات ذات تأثير جانبي، لذلك KELIVO يحتاج تعطيلها افتراضياً وموافقة عند التفعيل والتنفيذ.
- لا يجوز مساواة مجرد الاحتفاظ بـ.mcp.json بتشغيل الخادم.

### 5.4 نتائج عملية من Agent Skills وVercel

- لا نغير تنسيق SKILL.md القياسي أو نمسح حقولاً غير معروفة.
- metadata أولاً، تعليمات عند التفعيل، وreferences/assets عند الحاجة.
- Vercel lockfile يلهم مخططاً ثابتاً للمصدر/ref/commit/skillPath/hash/update time بحيث يمكن reproducible reinstall/rollback بدون تشغيل Node CLI.

### 5.5 نتائج عملية من MCP Skills over MCP

الامتداد io.modelcontextprotocol/skills يضيف skills/list وskills/get ويستخدم resources/read لنقل محتوى ملفات المهارة. المراجعة الحالية للامتداد تشير إلى Beta مبنية على revision 2026-07-28، وليس مجرد امتداد إلى عميل MCP 2025 الحالي.

متطلبات يجب تصميمها في adapter:
- التفاوض على الإصدار والإعلان عن extension capability قبل استدعاء methods.
- هوية المهارة = هوية خادم MCP + URI؛ لا تستخدم URI بمفردها.
- الموارد manifest كاملة، وتشمل SKILL.md والملفات الداعمة، ولكل ملف size وsha256.
- حدود المواصفة المذكورة: 512 resource entries و16 MiB إجمالي حجم لكل Skill.
- lazy retrieval؛ لا تجلب الملفات قبل الحاجة.
- تحقق digest/size وfrontmatter قبل التحميل.
- resources/read بمفرده ليس تفعيل Skill ولا يمنح موافقة.
- cache/TTL وpagination ولا تفترض أن listing فارغ يعني عدم وجود Skills.
- الموارد dynamic لا تقدم ضمان سلامة المحتوى، ويجوز رفضها وفق سياسة المضيف.

## 6. مصفوفة القدرات الحالية والفجوات

| القدرة | الحالة في KELIVO | الإجراء المقترح |
|---|---|---|
| Agent Skills folders + frontmatter | موجودة | اختبار توافق أوسع وتحسين metadata loading |
| GitHub/local/ZIP/skills.sh install | موجود | لا تستبدل المستورد؛ زد موائمات المصدر فقط عند وجود فجوة |
| Source hashes/manifests/rollback | موجود | ضم lockfile/reproducible source fields دون حذف metadata الحالية |
| Skill search/inspect/list | موجودة كأدوات محادثة | تحسين discoverability وpagination/limits |
| Skill composition DAG/contracts | موجود | تحسين الأداء والتحقق من المحتوى الفعلي |
| Local script execution Python/Bash/Node | موجود | لا توسع الامتدادات التنفيذية قبل اختبار كل Runtime |
| CLI standalone descriptor | اكتشاف/بيئة جزئية | adapter صريح بمدخلات ومخرجات وموافقة |
| Tool registry/dispatch | موزع بين catalog/handlers | طبقة توافق موحدة تدريجياً، لا refactor واسع دفعة واحدة |
| Deferred tools/Toolsets visibility | جزئي | تبنّي direct/deferred/hidden مع قيود provider schemas |
| MCP tools/list + tools/call العامة | موجود | حافظ على النقل/OAuth/name routing |
| Skill-owned MCP lifecycle | parser فقط؛ دورة التشغيل مفتوحة | إكمال ownership/connect/list/call/revoke/cancel |
| MCP Skills over MCP | غير موجود | بعد دعم base revision 2026-07-28 والتحقق من integrity |
| Plugin bundle manifest/components | غير موجود كـloader موحد | دعم metadata/read-only أولاً |
| Commands ضمن Plugin | غير موجود كـmanifest component عام | adapter لاحق فوق command registry والموافقة |
| Agents/Subagents | لا يوجد loader عام لحزم Plugin | orchestration متدرج بعد تعريف tool contract والـbudget |
| Hooks/events للـplugins | غير موجودة كدورة plugin | event bus بسياسة disabled-by-default |
| Generic HTTP/API Skill adapters | اكتشاف فقط / adapter required | موائم موحد، credentials منفصلة، SSRF review |
| Generic Skill workflow adapters | اكتشاف فقط / adapter required | reuse DAG/artifact ledger مع adapter declarative |
| Browser tools | موجودة | لا تكرر Browser عبر Playwright؛ ضف Playwright MCP optional عند الحاجة |

## 7. قرارات إعادة الاستخدام

1. لا تستبدل SkillsService أو SkillExecutor أو RuntimeProfileService أو McpProvider أو WorkspaceToolsService.
2. لا تضف Rust Codex أو OpenCode TypeScript/Bun كخدمة إلزامية في APK.
3. لا تضف PydanticAI أو smolagents كاعتماد Python دائم للنواة.
4. حافظ على Agent Skills SKILL.md بلا تعديل؛ أضف metadata جانبية لـKELIVO أو manifests مستقلة للـPlugin.
5. خادم MCP هو مصدر Tools/Resources، بينما Skill هو تعليمات/موارد/قدرة عمل؛ الفصل بينهما أساسي.
6. كل Tool له schema وexecutor وpermission definition وtimeout/cancellation/output bound وaudit record.
7. جميع المصادر الخارجية غير موثوقة إلى أن يتم تثبيت provenance والتحقق من البصمات والموافقة.
8. لا بدء hooks/MCP servers/HTTP connectors ولا تثبيت packages أثناء import/inspect/compose.
9. لا تعرض credentials في logs أو prompts أو pending approvals.
10. يمكن إضافة adapters كامتدادات اختيارية بدون توسيع APK بمكتبات native غير مطلوبة.

## 8. الترخيص والاعتماديات

- KELIVO مرخّص AGPL-3.0.
- مشاريع MIT/Apache-2.0 في الجدول لديها ترخيص معلن على مستوى GitHub repository، لكن يجب الاحتفاظ بنص الترخيص والإشعارات ومراجعة الملفات/المكونات الفرعية عند نسخ كود.
- تصريح Claude Plugins الرسمي لا يعني أن كل Plugin منشور داخله لا يملك شروطاً إضافية؛ راجع كل مكون.
- GitHub metadata لمستودع MCP Protocol تعرض NOASSERTION؛ يُستخدم كمرجع مواصفة، ولا يُنسخ كود منه قبل إثبات الترخيص.
- GitHub metadata لمستودعات anthropics/skills وopenai/skills لا تعرض ترخيصاً عاماً؛ لا إعادة توزيع للمحتوى حتى مراجعة ترخيص كل عنصر.
- الأفضل في هذه المرحلة نقل الأنماط والمعايير إلى Dart مع إحالة المصادر، وعدم نسخ ملفات runtime كبيرة لا تلائم منصة Android.
- هذه ملاحظات تقنية للامتثال وليست استشارة قانونية.

## 9. حدود هذا التدقيق

- جرد Git الكامل موثق في JSON لكل المسارات والـobject IDs والأحجام.
- جرت مراجعة مباشرة لملفات المصدر المحورية، وثائق Phase 13، مجموعة tests ذات الصلة، CI workflow، ومراجع OSS المثبتة.
- لم تُفحص بصرياً كل ملفات PNG/TTF/SVG ولا كل ملف ثنائي؛ لا تحمل هذه الملفات دلالات تنفيذ Skills.
- لم يتم تشغيل root full Flutter test suite في CI #139؛ CI يشغّل المسارات المحددة في workflow.
- لا يُعد نجاح CI إثباتاً لاختبار هاتف المستخدم أو Force Stop أو عزل kernel.
- أسماء الفروع الخارجية mutable؛ SHA لكل مرجع مستخدم أعلاه هو نقطة المراجعة الحالية وليس وعداً بآخر إصدار مستقبلي.

## 10. حالة هذه المرحلة

Audit + plan documented. لا توجد تغييرات تطبيق في هذا commit. يبدأ تنفيذ Phase 14A فقط بعد تثبيت هذه الوثائق على main؛ وتظل بوابات Phase 13 غير المقبولة مفتوحة ولا تُعتبر مقفلة بالتغيير الجديد.
