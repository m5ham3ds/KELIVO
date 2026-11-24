# KELIVO — فهرس المراحل والحالة

هذه صفحة تنقل مختصرة. لا تعتبر المرحلة مكتملة لمجرد وجود ملفاتها؛ ارجع إلى معايير القبول والأدلة.

## أحدث بناء ناجح — CI #150

[GitHub Actions #150](https://github.com/m5ham3ds/KELIVO/actions/runs/45446237776) اكتمل بنجاح في 24 نوفمبر 2026 على commit \`b4dcb3430743eeee6e6022a797bcc5e6a899bf5b\`. اجتازت بوابات التحليل والاختبارات والبناء كاملة.

- Android-only source audit وFlutter 3.47.6 وJava 21 وGradle وNDK 28.2.13676358 وCMake: نجاح.
- Flutter dependencies وLinux native test dependencies وArabic localization parity وflutter gen-l10n: نجاح.
- Flutter Analyze: نجاح، بلا analyzer errors/warnings.
- Environment installation lifecycle regression tests: نجاح.
- Phase 14A progressive Skill discovery tests: نجاح.
- Gemini schema وGoogle/Hugging Face OAuth tests: نجاح.
- Phase 13Q Skill MCP discovery + owner/stdio connection integration tests: نجاح.
- vendored local package test suites: نجاح.
- Android JVM/Robolectric: نجاح.
- Phase 13P Android Emulator Skill lifecycle E2E: نجاح.
- Android ARM64 Release APK، ABI verification، SHA-256 ورفع Artifact: نجاح.
- job جمع السجلات وتوليد تقرير Markdown: نجاح.

**APK**
- الاسم: \`Kelivo-Android-arm64-v8a-1.3.4+84-release.apk\`.
- الحجم: 40,656,449 bytes (artifact upload).
- ABI المتحقق: \`arm64-v8a\` فقط.
- SHA-256 للـAPK: \`920d06177a307f2bdcda48d8c3f845231ce6b9903c4dcbad1459d2b993b548d1\`.
- Artifact ID: \`14948111971\`.
- [تنزيل APK artifact من GitHub Actions](https://github.com/m5ham3ds/KELIVO/actions/runs/45446237776/artifacts/14948111971).
- [تقرير البناء Markdown — Artifact 14947152560](https://github.com/m5ham3ds/KELIVO/actions/runs/45446237776/artifacts/14947152560).
- SHA-256 لحزمة Artifact ZIP: \`b8e5da79c65eba84a35b75aba171777b2b0c7a2ffdbe2fb3c1f354764f0d872d\`.

**قيد التوقيع:** غياب \`android/key.properties\` يجعل CI يستخدم debug key. هذا APK قابل للتثبيت والاختبار، وليس ادعاء توقيع نشر عام لمتجر التطبيقات.

## حالة Phase 13 بعد CI #150

- **13A–13D:** توجد checkpoints مصدرية واختبارات تاريخية؛ لا تحول نجاح البناء الحالي وحده إلى قبول رجعي لكل هذه المراحل.
- **13B:** ما زالت غير مكتملة حتى إغلاق تكامل MCP المملوك للمهارة وبوابات 13Q ذات الصلة.
- **13P:** Android Emulator E2E اجتازت في CI #150. هذا ليس اختبار Force Stop على هاتف المستخدم ولا إثبات عزل kernel.
- **13Q.1–13Q.3:** اجتازت اختبارات CI #150؛ شمل ذلك تسجيل الملكية، والتحقق من digest، والموافقة على اتصال stdio، ونسخ Skill إلى مجلد جلسة خاص، واكتشاف الأدوات بعد الاتصال.
- **13Q.4:** أضيفت واجهات Skill-owned tools/list وtools/call، namespace، موافقة منفصلة لكل استدعاء، فحص المخطط، حدود البيانات، تنقيح الأسرار وسجل التدقيق. قبولها ينتظر CI الخاص بالتغيير الحالي.
- **13Q.5:** إلغاء الاتصال تلقائياً عند تعطيل Skill أو حذفها أو تغير بصمتها ما زال مفتوحاً.
- **13R:** بوابات Environment وRobolectric وPhase13P Emulator اجتازت؛ اختبار الهاتف الفعلي عند مغادرة الصفحة وإزالة التطبيق من Recents وStop بعد commit point ما زال مطلوباً.
- **PRoot:** Linux userland فقط، RootFS نشط مشترك وقابل للكتابة، والشبكة غير مقيدة بالكامل. لا تصفه كـkernel sandbox.
- **HTTP/SSE:** ما زال مرفوضاً لخوادم Skills حتى اكتمال DNS pinning وحماية SSRF وموافقة المضيف.

## التدقيق والخطة الجديدة — Phase 14

تم تثبيت خط الأساس على commit 9abb9dcc40881b005902265fdbd86d93248cb906. Git tree snapshot غير مبتور ويحتوي 4,237 ملفاً و634 مجلداً (4,871 عنصراً) و60,883,091 بايت من blobs.

- [Phase 14 — تقرير تدقيق المستودع ومصفوفة الاستفادة من OSS](PHASE-14-REPOSITORY-AUDIT-AND-OSS-REUSE-MATRIX-AR.md)
- [Phase 14 — الخطة المعمارية والتنفيذية والقيود](PHASE-14-UNIVERSAL-SKILLS-PLUGINS-TOOLS-AND-AGENT-ORCHESTRATION-AR.md)
- [Phase 14 — فهرس كل مسارات Git عند baseline](PHASE-14-REPOSITORY-TREE-MANIFEST-2026-11-24.json)

**المرحلة التنفيذية الأولى المقترحة:** 14A Progressive Skill Discovery & Lazy Instruction Loading. سبب الاختيار أن skills_prompt.dart يعرض أول 20 Skill افتراضياً، وskill_composition_service.dart يقرأ أجسام كل المرشحين حتى 64 قبل تحديد المختار، مع أن planner scoring يعتمد على metadata. المطلوب تحسين الموجود دون إنشاء مستورد أو منفذ مهارات آخر.

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

| المرحلة | ملفاتها المرجعية | الحالة |
|---|---|---|
| 00–02 | مواصفات وتقارير Phases 00–02 | خط أساس/تنفيذ موثق |
| 03 | PHASE-03-IMPLEMENTATION-REPORT.md | مراجعة قبول مطلوبة |
| 04 | PHASE-04-MULTI-SKILL-COMPOSITION-ENGINE.md | التخطيط موجود؛ تنفيذ المهارات له Phase 13B |
| 05 | PHASE-05-UNIVERSAL-DEPENDENCY-PACKAGE-MANAGER.md | manager موجود؛ القبول الشامل وفق تقرير المرحلة |
| 06 | PHASE-06-RUNTIME-PROFILES-AND-EXECUTION-ISOLATION.md | Runtime Profiles موجودة؛ PRoot ليس sandbox |
| 07–12 | مواصفات وتقارير Phases 07–12 | تخضع لأدلة اختبارات المحرك/المزود والجودة والهاتف |
| 13A–13D | تقارير PHASE-13A/B/C/D-IMPLEMENTATION-REPORT.md | checkpoints موجودة؛ بوابات القبول بحسب تقاريرها، و13B مفتوحة حتى MCP |
| 13E–13O | مواصفات وتقارير Phases 13E–13O | لا تعمم قبول CI على runners التاريخية غير المشغلة |
| 13P | PHASE-13P-END-TO-END-SKILL-TESTING-AR.md | Emulator E2E اجتازت CI #139؛ الهاتف الحقيقي غير مفحوص هنا |
| 13Q | PHASE-13Q-SKILL-MCP-ADAPTER-INTEGRATION-AR.md | 13Q.1 فقط مقبولة؛ 13Q.2–13Q.5 مفتوحة |
| 13R | PHASE-13R-ENVIRONMENT-INSTALL-LIFECYCLE-AR.md | CI #139 نجح؛ اختبار الهاتف مطلوب |
| 14 | PHASE-14-UNIVERSAL-SKILLS-PLUGINS-TOOLS-AND-AGENT-ORCHESTRATION-AR.md | خطة موثقة؛ يبدأ التنفيذ بـ14A بعد هذا التوثيق |
| Reel Studio | REEL-STUDIO-GAP-ANALYSIS-AR.md | Orchestrator والإنتاج المتزامن العام غير منفذين |

## أرشيف CI

احتفظ بتقارير الفشل والإصلاح التاريخية. تقارير البناء الخام توجد في ../build-report/ عند توفرها.
