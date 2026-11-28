# KELIVO — فهرس المراحل والحالة

هذه الصفحة هي المدخل الحالي لخطة المشروع. تقارير التشغيل الأقدم أدناه محفوظة كسجلات تاريخية؛ لا تتقدم على حالة `main` الموثقة هنا أو في سجل Phase 14E.

## مشكلة تحديث APK فوق النسخة المثبتة — مانع إصدار حرج

تم تأكيد اختلاف شهادة التوقيع بين APK #211 وAPK #217؛ السبب أن Release يعود إلى مفتاح Debug عند غياب `android/key.properties`، بينما لا يضمن CI مفتاحاً ثابتاً. لذلك لا يُقبل APK كتحديث فوق النسخة المثبتة حتى يُنفّذ التوقيع الدائم واختبار الترقية دون إزالة التطبيق.

- **التقرير الملزم:** [ANDROID-APK-IN-PLACE-UPDATE-FAILURE-REPORT-AR.md](ANDROID-APK-IN-PLACE-UPDATE-FAILURE-REPORT-AR.md)
- **الحالة:** السبب مؤكد؛ الإصلاح لم يُنفّذ بعد؛ جميع معايير القبول في التقرير مطلوبة قبل إغلاق المشكلة.

## أحدث بناء ناجح — CI #227

[GitHub Actions #227](https://github.com/m5ham3ds/KELIVO/actions/runs/46109278842) اكتمل بنجاح على `main` commit `fc5f432b9f9251cd86b8d78fe4ae5860946b3434` بتاريخ 28 نوفمبر 2026.

- وظيفة البناء ووظيفة نشر التقرير: نجاح كامل.
- Android-only وRelease-hardening audit وFlutter 3.47.6 وFlutter Analyze: نجاح.
- Environment install lifecycle: نجاح.
- Phase 14A progressive Skill discovery: 34 اختباراً ناجحاً.
- Phase 14B Plugin manifest/component registry: 9 اختبارات ناجحة.
- Phase 14E.2 turn-scoped Tool Registry gateway: نجاح.
- Gemini schema وProvider OAuth وPhase 14C.4 Remote Skills: نجاح.
- Phase 13Q/14D Skill-owned MCP وSTDIO الحقيقي: نجاح.
- اختبارات الحزم المحلية الخمس: نجاح.
- Android JVM/Robolectric: نجاح.
- Phase 13P Android Emulator E2E: نجاح.
- بناء APK ARM64 وفحص ABI وSHA-256 ورفع APK: نجاح.
- نشر تقرير Markdown والسجلات: نجاح.

**APK — CI #208**
- الحجم: 41,943,583 bytes.
- ABI: `arm64-v8a` فقط.
- SHA-256: `29fa1b9db0223dd0b9c6d8f170af3b86f6d44f2f5dd88a992843bd09f907f6fa`.
- APK Artifact ID: `15167472926`.
- Build report Artifact ID: `15167378117`.
- Raw diagnostics Artifact ID: `15167717401`.
- [APK ARM64](https://github.com/m5ham3ds/KELIVO/actions/runs/45926843283/artifacts/15167472926).
- [Build report](https://github.com/m5ham3ds/KELIVO/actions/runs/45926843283/artifacts/15167378117).
- [Raw diagnostics](https://github.com/m5ham3ds/KELIVO/actions/runs/45926843283/artifacts/15167717401).

**حدود التحقق:** لا يشغّل هذا الـworkflow كامل Flutter root unit/widget suite ولا جميع runners التاريخية لـ13E–13O. محاكي Android لا يثبت Force Stop على هاتف فعلي أو عزل PRoot على مستوى Kernel. عند غياب `android/key.properties` يستخدم CI debug signing fallback؛ هذا APK للاختبار وليس مفتاح نشر متجر.

## الحالة الحالية للمراحل

- **Phase 14A–14D:** مقبولة عبر البوابات المستقلة: 14A #162، 14B #164، 14C #199، 14D #204.
- **Phase 14E.1:** اختبارات Registry/Toolsets الأساسية اجتازت CI #206.
- **Phase 14E.2:** تكامل جلسة Registry مع دورة المحادثة وGateway اجتاز CI #208.
- **Phase 14E — assistant Toolsets:** اختيار Toolsets على مستوى المساعد، واجهة Local Tools، والحفظ والنسخ اجتازت CI #227؛ كما نجحت جميع بوابات Android JVM والمحاكي وبناء ARM64.
- **Phase 14E — conversation Toolset binding:** أضيف ربط محادثة يضيّق قائمة المساعد ولا يوسّعها؛ هذا التغيير ينتظر CI بعد دمجه.
- **Phase 14E بالكامل ما زالت قيد التنفيذ**؛ يتبقى تكافؤ الأدوات الأصلية/المزوّدين، والتعريض المؤجل/المخفي على المسار الفعلي، وحدود الميزانيات.
- **Phase 14F–14H:** لم تبدأ.
- **Phase 13P:** Android Emulator E2E ناجح في CI #208؛ لا يعني اختبار Force Stop على هاتف المستخدم.
- **Phase 13Q:** Backend/lifecycle مقبولة في CI #199، ودليل STDIO الحقيقي والعدائي اجتاز CI #204 وأعيد التحقق في #208؛ لا يُستنتج اكتمال UX الموافقة المرئية من اختبارات Backend.
- **Phase 13R:** Environment lifecycle وRobolectric ومحاكي Android وبناء ARM64 اجتازت #208؛ اختبار دورة الحياة على هاتف Android فعلي لا يزال مطلوباً.
- **Phase 13A–13D و13E–13O:** تُحترم حالة كل تقرير قبول؛ نجاح Analyze أو بناء CI الحالي لا يمنح قبولاً رجعياً لاختبارات تاريخية لم يشغّلها الـworkflow.
- **Phases 03–12:** التنفيذ المصدري موجود بدرجات متفاوتة؛ بوابات القبول العملية المحددة في الخطة الرئيسية ما زالت مفتوحة، خصوصاً Render ومزودي الفيديو والجودة والأمان على Android ARM64.

## الحالة النشطة — Phase 14E

التقرير التفصيلي: [PHASE-14E-IMPLEMENTATION-STATUS-AR.md](PHASE-14E-IMPLEMENTATION-STATUS-AR.md).

- 14E.1: [CI #206](https://github.com/m5ham3ds/KELIVO/actions/runs/45915687173).
- 14E.2: [CI #208](https://github.com/m5ham3ds/KELIVO/actions/runs/45926843283).
- assistant Toolsets: [CI #227](https://github.com/m5ham3ds/KELIVO/actions/runs/46109278842)، نجاح 42/42 خطوة.
- conversation Toolset binding: التغيير الحالي مضاف إلى `main` وينتظر نتيجة بوابة CI.
- لا تُعلن Phase 14E مقبولة بالكامل ولا تبدأ 14F قبل إغلاق parity والتعريض المؤجل والميزانيات.

## حالة الفروع

- `main` هو الفرع النشط؛ آخر CI مكتمل موثق هو #227 على commit `fc5f432b9f9251cd86b8d78fe4ae5860946b3434`. أي تغييرات أحدث داخل Phase 14E تبقى غير مقبولة حتى ينجح CI الخاص بها.
- الفرع التاريخي `phase-14c5-mrtr-subscriptions` متأخر 13 commit عن `main` ولا يملك commits فريدة غير مدمجة؛ لا يُستخدم للعمل الحالي.
- لا توجد Pull Requests مفتوحة. لم يُنشأ فرع جديد لهذه المزامنة.

## وثائق المرجع الحالية

- [الخطة الهندسية الرئيسية](MASTER-DEVELOPMENT-PLAN-AR.md)
- [الخطة المعمارية Phase 14](PHASE-14-UNIVERSAL-SKILLS-PLUGINS-TOOLS-AND-AGENT-ORCHESTRATION-AR.md)
- [تقرير حالة Phase 14E](PHASE-14E-IMPLEMENTATION-STATUS-AR.md)
- [الخطة المعمارية Phase 13](PHASE-13-SKILLS-WORKSPACE-ARCHITECTURE-AND-IMPLEMENTATION-PLAN.md)
- [Phase 13Q — Skill-owned MCP](PHASE-13Q-SKILL-MCP-ADAPTER-INTEGRATION-AR.md)
- [Phase 13R — Environment lifecycle](PHASE-13R-ENVIRONMENT-INSTALL-LIFECYCLE-AR.md)
- [دليل Android Build](ANDROID_BUILD_AR.md)
- [تقرير CI Automation](BUILD_AUTOMATION_REPORT_AR.md)
- [وصف المنتج](../PRODUCT.md)

## دليل البناء الأحدث — CI #227

[GitHub Actions #227](https://github.com/m5ham3ds/KELIVO/actions/runs/46109278842) اكتمل بنجاح على commit `fc5f432b9f9251cd86b8d78fe4ae5860946b3434`.

- وظيفة البناء اجتازت **42/42 خطوة ناجحة** دون إخفاق.
- Flutter Analyze والتوطين وEnvironment وPhase 14A–14E وGemini/OAuth وMCP/STDIO والحزم المحلية: نجاح.
- Android JVM/Robolectric ومحاكي Phase 13P: نجاح.
- بناء APK ARM64 والتحقق من SHA-256 ورفع Artifact: نجاح.

**APK — CI #227**
- الاسم: `Kelivo-Android-arm64-v8a-1.3.4+84-release.apk`.
- الحجم: 41,953,323 bytes.
- ABI: `arm64-v8a` فقط.
- SHA-256: `c09153eeeffe4e59c8ff37dd8999cdab2fea70b0cd4e5e301ce90a46ed662c46`.
- APK Artifact ID: `15249920264`.
- [APK ARM64](https://github.com/m5ham3ds/KELIVO/actions/runs/46109278842/artifacts/15249920264).
- [Build report / diagnostics](https://github.com/m5ham3ds/KELIVO/actions/runs/46109278842).

**قيد مستقل:** نجاح البناء لا يثبت أن APK يحدّث نسخة مثبتة؛ مانع التوقيع الثابت واختبار `adb install -r` ما زالا مفتوحين في التقرير المخصص.

## سجل بناء سابق — CI #175

[GitHub Actions #175](https://github.com/m5ham3ds/KELIVO/actions/runs/45539996937) اكتمل بنجاح على commit `821744e04fbf6ef525a42a80a2a220aa5a4f4f2b`، المطابق لرأس `main` وقت التشغيل.

- Flutter Analyze وEnvironment lifecycle و14A و14B وGemini/OAuth و13Q: نجاح.
- اختبارات الحزم المحلية: 160 نجاحاً.
- Android JVM/Robolectric: 440 نجاحاً.
- اختبارات محاكي Android: نجاح.
- بناء APK ARM64 ورفع التقرير والسجلات: نجاح.

**APK — CI #175**
- الاسم: `Kelivo-Android-arm64-v8a-1.3.4+84-release.apk`.
- الحجم الفعلي: 41,894,251 bytes.
- ABI المتحقق من محتويات APK: `arm64-v8a` فقط.
- SHA-256 المتحقق محلياً: `a448f321903fa4bd871e96862f6ec6e18e480a85e6daf5bc43e72fd96a299f16`.
- Artifact ID: `14989478648`.
- [APK artifact](https://github.com/m5ham3ds/KELIVO/actions/runs/45539996937/artifacts/14989478648).
- [Build report](https://github.com/m5ham3ds/KELIVO/actions/runs/45539996937/artifacts/14990331011).
- [Raw logs](https://github.com/m5ham3ds/KELIVO/actions/runs/45539996937/artifacts/14990226810).

**ملاحظة نطاق:** هذا الـworkflow لا يشغّل Flutter root unit/widget suite كاملة ولا اختبارات Phase 13E–13O المركزة. نجاح #175 لا يغلق هذه البوابات بأثر رجعي.

**تدقيق ما بعد #175:** كشف تحسينات مطلوبة في أول stateless POST، SSE المرتبط بالطلب، `connectWithRetry`، وحفظ server capability extensions. هذه المتابعة تُختبر في CI مستقل؛ لا تُعلن 14C.1 مقبولة نهائياً قبل نجاح ذلك التشغيل.
## سجل بناء سابق — CI #164

[GitHub Actions #164](https://github.com/m5ham3ds/KELIVO/actions/runs/45517073229) اكتمل بنجاح في 25 نوفمبر 2026 على commit `0ef719649ff00f621a2fac62e801b15d41cc2239`، المطابق لرأس فرع `main`.

- Android-only source audit وFlutter 3.47.6 وJava/Gradle/NDK/CMake: نجاح.
- Arabic localization parity و`flutter gen-l10n`: نجاح.
- Flutter Analyze: نجاح.
- Environment installation lifecycle regression tests: نجاح.
- Phase 14A progressive Skill discovery tests: نجاح؛ وبذلك اجتازت 14A بوابة CI.
- Gemini schema وGoogle/Hugging Face OAuth regression tests: نجاح.
- Phase 13Q Skill MCP configuration discovery tests: نجاح (configuration discovery فقط، لا يغلق 13Q.5).\n- Phase 14B Plugin manifest/component registry tests: نجاح.
- vendored local package test suites: نجاح.
- Android JVM/Robolectric: نجاح.
- Phase 13P Android Emulator Skill lifecycle E2E: نجاح.
- Android ARM64 Release build، ABI verification، SHA-256 ورفع Artifact: نجاح.
- job جمع السجلات وتوليد تقرير Markdown: نجاح.

**APK — CI #164**
- الاسم: `Kelivo-Android-arm64-v8a-1.3.4+84-release.apk`.
- الحجم الفعلي للـAPK: 41,889,227 bytes.
- ABI المتحقق: `arm64-v8a` فقط.
- SHA-256 للـAPK: `ab8dd504fe45699dd64f80dea2962e7e87aaeb6f076d153ef992c7dd20ec4292`.
- Artifact ID: `14978959033`.
- [تنزيل APK artifact](https://github.com/m5ham3ds/KELIVO/actions/runs/45517073229/artifacts/14978959033).
- [تقرير البناء Markdown — Artifact 14979194691](https://github.com/m5ham3ds/KELIVO/actions/runs/45517073229/artifacts/14979194691).
- [سجلات التشخيص الخام — Artifact 14978639624](https://github.com/m5ham3ds/KELIVO/actions/runs/45517073229/artifacts/14978639624).

**قيد التوقيع:** لا يعني نجاح بناء Release أن APK موقّع بمفتاح نشر متجر؛ سجل CI يستخدم debug key عند غياب `android/key.properties`.

## حالة Phase 13 — مزامنة 27 نوفمبر 2026

- **13A–13D:** تقاريرها الأصلية تسجل checkpoints وبوابات قبول غير مغلقة بالكامل. لا تمنحها CI #208 قبولاً رجعياً.
- **13B/MCP:** فجوة Skill-owned MCP التي كانت موثقة في التقرير القديم عولجت لاحقاً عبر 13Q ثم اختُبرت في 14D؛ لا تزال بقية معايير 13B وتقارير A–D بحاجة إلى مراجعة حسب تقاريرها.
- **13E–13O:** لا تُعلن مقبولة لمجرد نجاح Flutter Analyze أو Android build؛ الـworkflow الحالي لا يشغّل جميع اختبارات هذه المراحل التاريخية.
- **13P:** Android Emulator E2E اجتازت CI #208. هذا ليس اختبار Force Stop على هاتف المستخدم.
- **13Q:** 13Q.1–13Q.5 Backend/lifecycle اجتازت CI #199، وشغّلت اختبارات STDIO الحقيقية والعدائية في CI #204 ثم أعيد التحقق منها في #208. لا يدعي ذلك اكتمال تجربة الموافقة المرئية على الهاتف.
- **13R:** اختبارات Environment install lifecycle اجتازت CI #208، وكذلك Android JVM/Robolectric ومحاكي 13P وبناء ARM64. اختبار هاتف حقيقي عند مغادرة التطبيق/Recents ومرحلة Stop بعد commit point يبقى مطلوباً.
- **حد الأمان:** PRoot Linux userland فقط؛ RootFS مشترك وقابل للكتابة، والشبكة غير مقيدة بالكامل. لا Kernel Sandbox claim.

## التدقيق والخطة — Phase 14

تم تدقيق المستودع عند baseline commit `9abb9dcc40881b005902265fdbd86d93248cb906` في 24 نوفمبر. ملف Git tree manifest المؤرخ بذلك اليوم لقطة تاريخية وليس جرداً حياً لرأس المشروع الحالي.

- [Phase 14 — تقرير تدقيق المستودع ومصفوفة OSS](PHASE-14-REPOSITORY-AUDIT-AND-OSS-REUSE-MATRIX-AR.md)
- [Phase 14 — الخطة المعمارية](PHASE-14-UNIVERSAL-SKILLS-PLUGINS-TOOLS-AND-AGENT-ORCHESTRATION-AR.md)
- [Phase 14B — تقرير Plugin Registry](PHASE-14B-PLUGIN-MANIFEST-COMPONENT-REGISTRY-AR.md)
- [Phase 14C — تقرير MCP Protocol](PHASE-14C-MCP-BASE-PROTOCOL-AND-SKILLS-OVER-MCP-AR.md)
- [Phase 14D — تقرير قبول Skill-owned MCP](PHASE-14D-SKILL-OWNED-MCP-LIFECYCLE-ACCEPTANCE-AR.md)
- [Phase 14E — تقرير حالة التنفيذ والبوابات](PHASE-14E-IMPLEMENTATION-STATUS-AR.md)
- [لقطة Git tree المؤرخة 24 نوفمبر](PHASE-14-REPOSITORY-TREE-MANIFEST-2026-11-24.json).

**الحالة الحالية — 27 نوفمبر 2026:**
- **14A مقبولة:** CI #162.
- **14B مقبولة:** CI #164.
- **14C مقبولة بالكامل:** CI #199، بما في ذلك MRTR و`subscriptions/listen`.
- **14D مقبولة بالكامل:** CI #204، real STDIO وhostile-server tests.
- **14E.1 اختبارات ناجحة:** CI #206 على commit `05fadf6db2371a68bfa02869dc2efc6f84543d03`.
- **14E.2 اختبارات ناجحة:** CI #208 على commit `77736b783d55752a35a3aeb3b66b6b6dce7e87f1`; أضاف التصحيح `toolRegistrySession` المفقود في fixture الخاص بـ`workspace_prompt_test.dart`. لم يكن هذا فشلاً في منطق Registry.
- **14E ككل قيد التنفيذ:** تحتاج تكامل Toolsets الإنتاجية وتكافؤ الأدوات الأصلية والتعريض المؤجل والميزانيات وبوابات القبول الكاملة.
- **14F–14H:** لم تبدأ.

## تشخيص فشل CI السابق

- CI #137 فشل في Flutter Analyze بسبب import مفقود وsyntax comma؛ عولجا في commit 80c95c66e2786f579af0fbcc25a0ff18ed295059.
- CI #138 كشف خطأ استمرار سطر Bash في .github/workflows/android-build.yml نتج عنه مسار اختبار وهمي \؛ أصلح في commit 9abb9dcc40881b005902265fdbd86d93248cb906.
- CI #139 هو التحقق الناجح على commit الإصلاح، وليس مجرد retry على الكود القديم.

## تاريخ بناء سابق

[CI #120](https://github.com/m5ham3ds/KELIVO/actions/runs/45217166038) كان آخر بناء ناجح قبل تغييرات دورة Environment 13R. APK #120: 41,842,583 bytes، SHA-256 5791a197b30bb3a160c41739a788a1c1b5053ca77599a9ba007de84acd632654، Artifact ID 14840756161. هذه بيانات تاريخية استبدلها CI #143 في أحدث baseline.

تشغيلات #116–#119 أُلغيت أثناء commits متتالية ولم تصل إلى اختبارات فاشلة؛ لا تصنفها كفشل اختبار.

## تشخيص Robolectric التاريخي

- CI #76 أثبت HTTP 429 من Maven Central عند تنزيل org.robolectric:nativeruntime-dist-compat:1.0.18.
- CI #77 اجتاز حل الاعتماديات لكنه فشل في بعض اختبارات Robolectric عند MavenArtifactFetcher.java:129 مع IOException؛ السجل لم يثبت رمز HTTP لهذه المحاولة.
- أضيفت مرآة Google Hosted Maven Central لمسار Robolectric، ثم تأكد الإصلاح في تشغيل لاحق. لا تعاد فتح المشكلة دون ظهور دليل جديد.

راجع PHASE-13Q-CI-MAVEN-429-FIX-AR.md وANDROID_BUILD_AR.md.

## وثائق المرجع

- [الخطة الهندسية الرئيسية](MASTER-DEVELOPMENT-PLAN-AR.md)
- [وصف المنتج](../PRODUCT.md)
- [دليل بناء Android](ANDROID_BUILD_AR.md)
- [تدقيق Android-only](ANDROID_ONLY_AUDIT.md)
- [تقرير التشغيل التلقائي](BUILD_AUTOMATION_REPORT_AR.md)
- [الخطة المعمارية Phase 13](PHASE-13-SKILLS-WORKSPACE-ARCHITECTURE-AND-IMPLEMENTATION-PLAN.md)
- [Phase 13Q — موائم MCP للمهارات](PHASE-13Q-SKILL-MCP-ADAPTER-INTEGRATION-AR.md)
- [Phase 13R — موثوقية دورة تثبيت البيئة](PHASE-13R-ENVIRONMENT-INSTALL-LIFECYCLE-AR.md)
- [تدقيق Phase 14](PHASE-14-REPOSITORY-AUDIT-AND-OSS-REUSE-MATRIX-AR.md)
- [خطة Phase 14](PHASE-14-UNIVERSAL-SKILLS-PLUGINS-TOOLS-AND-AGENT-ORCHESTRATION-AR.md)

## المراحل الأساسية

| المرحلة | ملفاتها المرجعية | الحالة الحالية |
|---|---|---|
| 00–02 | مواصفات وتقارير Phases 00–02 | خط الأساس والتنفيذ موثقان؛ راجع سجلات القبول التاريخية |
| 03 | PHASE-03-IMPLEMENTATION-REPORT.md | القبول الرسمي يحتاج مراجعة |
| 04 | PHASE-04-MULTI-SKILL-COMPOSITION-ENGINE.md | التخطيط موجود؛ تنفيذ Skills/Artifact handoff ما زال فجوة |
| 05 | PHASE-05-UNIVERSAL-DEPENDENCY-PACKAGE-MANAGER.md | مدير الحزم موجود؛ القبول الشامل وفق بوابات المرحلة |
| 06 | PHASE-06-RUNTIME-PROFILES-AND-EXECUTION-ISOLATION.md | Runtime Profiles موجودة؛ PRoot ليس sandbox |
| 07–12 | مواصفات وتقارير Phases 07–12 | بوابات Render ومزودي الفيديو والجودة والأمان/الهاتف لم تُغلق كلها |
| 13A–13D | تقارير PHASE-13A/B/C/D | checkpoints؛ القبول الكامل لكل تقرير غير مثبت |
| 13E–13O | مواصفات وتقارير Phases 13E–13O | لا يُعمم نجاح CI الحالي على runners تاريخية غير مشغلة |
| 13P | PHASE-13P-END-TO-END-SKILL-TESTING-AR.md | Android Emulator E2E اجتازت CI #208؛ لا Force Stop/هاتف فعلي |
| 13Q | PHASE-13Q-SKILL-MCP-ADAPTER-INTEGRATION-AR.md | Backend/lifecycle مقبول CI #199؛ real STDIO مدعوم بدليل CI #204 |
| 13R | PHASE-13R-ENVIRONMENT-INSTALL-LIFECYCLE-AR.md | CI #208 lifecycle/Robolectric/Emulator/ARM64 ناجحة؛ اختبار الهاتف مطلوب |
| 14A | الخطة المعمارية Phase 14 | مقبولة CI #162 |
| 14B | PHASE-14B-PLUGIN-MANIFEST-COMPONENT-REGISTRY-AR.md | مقبولة CI #164 |
| 14C | PHASE-14C-MCP-BASE-PROTOCOL-AND-SKILLS-OVER-MCP-AR.md | مقبولة CI #199 |
| 14D | PHASE-14D-SKILL-OWNED-MCP-LIFECYCLE-ACCEPTANCE-AR.md | مقبولة CI #204 |
| 14E | PHASE-14E-IMPLEMENTATION-STATUS-AR.md | 14E.1/#206 و14E.2/#208 اجتازتا الاختبارات؛ المرحلة ككل قيد التنفيذ |
| 14F–14H | الخطة المعمارية Phase 14 | لم تبدأ |
| Reel Studio | REEL-STUDIO-GAP-ANALYSIS-AR.md | Orchestrator والإنتاج المتزامن العام لا يزالان غير مكتملين |

## أرشيف CI

احتفظ بتقارير الفشل والإصلاح التاريخية. تقارير البناء الخام توجد في ../build-report/ عند توفرها.
