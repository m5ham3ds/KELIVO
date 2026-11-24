# KELIVO — فهرس المراحل والحالة

هذه صفحة تنقل مختصرة. لا تعتبر المرحلة مكتملة لمجرد وجود ملفاتها؛ ارجع إلى معايير القبول والأدلة.

## أحدث بناء ناجح — CI #143

[GitHub Actions #143](https://github.com/m5ham3ds/KELIVO/actions/runs/45419611471) على commit 30ce5099dfd80c4633430c186935daae41e3ac08 اكتمل بالنتيجة success في 24 نوفمبر 2026. نجح إصلاح تنزيل SQLite native hook باستخدام cache ثابت keyed by package version.

- Android-only source audit وFlutter 3.47.6 وJava 21 وGradle 8.14 وNDK 28.2.13676358 وCMake 3.22.1: نجاح.
- Resolve Flutter dependencies وLinux GTK/GLib native test dependencies وArabic localization parity وflutter gen-l10n: نجاح.
- Flutter Analyze: نجاح، بلا analyzer errors/warnings.
- Environment installation lifecycle regression tests: نجاح.
- Gemini schema + Google/Hugging Face OAuth regression tests: نجاح.
- Phase 13Q read-only MCP configuration discovery tests (13Q.1): نجاح.
- vendored local package test suites: نجاح.
- Android JVM/Robolectric: نجاح.
- Phase 13P Android Emulator Skill lifecycle E2E: نجاح في CI #143.
- جميع الخطوات الـ33 في job البناء اكتملت بنجاح، وكذلك job جمع السجلات وتوليد التقرير.
- Android ARM64 Release APK وABI verification وSHA-256 ورفع Artifact: نجاح.
- تقرير CI الخام والتقرير Markdown: رفع ناجح.

**APK**
- الاسم: Kelivo-Android-arm64-v8a-1.3.4+84-release.apk.
- الحجم: 40,654,555 bytes (artifact upload).
- ABI المتحقق: arm64-v8a فقط.
- SHA-256 للـAPK: 14f642d718f1f583720a85fa57871aa1751a282f6af33b892562f053082711dc.
- Artifact ID: 14936362079.
- [تنزيل artifact من GitHub Actions](https://github.com/m5ham3ds/KELIVO/actions/runs/45419611471/artifacts/14936362079).
- SHA-256 لحزمة ZIP المرفوعة: 3b961d6d746a743f8de2dfb1cb35c213722427d9e8fcb9ef682e4fe62cfc5e51.

**قيد التوقيع:** سجل CI يذكر أن غياب android/key.properties يجعل عملية البناء تستخدم debug key. هذا APK قابل للتثبيت والاختبار، وليس ادعاء توقيع نشر عام لمتجر التطبيقات.

## حالة Phase 13 بعد CI #139

- **13A–13D:** توجد checkpoints مصدرية واختبارات تاريخية؛ لا تحول نجاح البناء الحالي وحده إلى قبول رجعي لكل هذه المراحل. راجع تقاريرها وبوابات القبول الأصلية.
- **13B:** لم تكتمل بعد؛ Skill-owned MCP adapter ودورة tools/list/tools/call والاختبار الفعلي ما زالت مفتوحة.
- **13P:** Android Emulator E2E اجتازت في CI #139. هذا ليس اختبار Force Stop على هاتف المستخدم ولا إثبات عزل kernel.
- **13Q:** 13Q.1 parser/read-only اجتازت. أضيف checkpoint 13Q.2 لملكية التسجيلات والتحقق من digest والتعطيل الافتراضي ومخزن الأسرار المنفصل؛ ينتظر CI. 13Q.3–13Q.5 connect/tools-list/tools-call/cancellation ما زالت مفتوحة.
- **13R:** بوابات CI المتعلقة بدورة Environment اجتازت في #143، بما فيها Robolectric وPhase13P Emulator E2E. اختبار الهاتف الفعلي عند مغادرة الصفحة وإزالة التطبيق من Recents وStop بعد commit point ما زال مطلوباً قبل إعلان القبول التشغيلي الكامل.
- **PRoot:** Linux userland فقط، RootFS نشط مشترك وقابل للكتابة، والشبكة غير مقيدة بالكامل. لا تصفه كـkernel sandbox.
- **HTTP/API وgeneric workflow adapters:** اكتشاف descriptor لا يعني وجود adapter تشغيلي عام.

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
