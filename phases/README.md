# KELIVO — فهرس المراحل والحالة

هذه صفحة تنقل مختصرة. لا تعتبر المرحلة مكتملة لمجرد وجود ملفاتها؛ ارجع إلى معايير القبول والأدلة.

## أحدث بناء ناجح — CI #162

[GitHub Actions #162](https://github.com/m5ham3ds/KELIVO/actions/runs/45508226377) اكتمل بنجاح في 25 نوفمبر 2026 على commit `14c7938617ccaab7b38542caebb891f292c7ef18`، المطابق لرأس فرع `main`.

- Android-only source audit وFlutter 3.47.6 وJava/Gradle/NDK/CMake: نجاح.
- Arabic localization parity و`flutter gen-l10n`: نجاح.
- Flutter Analyze: نجاح.
- Environment installation lifecycle regression tests: نجاح.
- Phase 14A progressive Skill discovery tests: نجاح؛ وبذلك اجتازت 14A بوابة CI.
- Gemini schema وGoogle/Hugging Face OAuth regression tests: نجاح.
- Phase 13Q Skill MCP configuration discovery tests: نجاح.
- vendored local package test suites: نجاح.
- Android JVM/Robolectric: نجاح.
- Phase 13P Android Emulator Skill lifecycle E2E: نجاح.
- Android ARM64 Release build، ABI verification، SHA-256 ورفع Artifact: نجاح.
- job جمع السجلات وتوليد تقرير Markdown: نجاح.

**APK**
- الاسم: `Kelivo-Android-arm64-v8a-1.3.4+84-release.apk`.
- الحجم الفعلي للـAPK: 41,849,191 bytes.
- ABI المتحقق: `arm64-v8a` فقط.
- SHA-256 للـAPK: `cc9767860e9aa927cf6ab84d9be085335d78ef4bca00b83ecaa3522a76e680a2`.
- Artifact ID: `14975842089`.
- [تنزيل APK artifact](https://github.com/m5ham3ds/KELIVO/actions/runs/45508226377/artifacts/14975842089).
- [تقرير البناء Markdown — Artifact 14975990946](https://github.com/m5ham3ds/KELIVO/actions/runs/45508226377/artifacts/14975990946).
- [سجلات التشخيص الخام — Artifact 14975094936](https://github.com/m5ham3ds/KELIVO/actions/runs/45508226377/artifacts/14975094936).

**قيد التوقيع:** لا يعني نجاح بناء Release أن APK موقّع بمفتاح نشر متجر؛ سجل CI يستخدم debug key عند غياب `android/key.properties`.

## حالة Phase 13 بعد CI #162

- **13A–13D:** توجد checkpoints مصدرية واختبارات تاريخية؛ لا تحول نجاح البناء الحالي وحده إلى قبول رجعي لكل هذه المراحل.
- **13B:** ما زالت غير مكتملة حتى إغلاق تكامل MCP المملوك للمهارة وبوابات 13Q ذات الصلة.
- **13P:** Android Emulator E2E اجتازت في CI #162. هذا ليس اختبار Force Stop على هاتف المستخدم ولا إثبات عزل kernel.
- **13Q.1–13Q.3:** اجتازت CI #150؛ شملت الملكية والتحقق من digest والموافقة على اتصال stdio ونسخ Skill إلى مجلد جلسة خاص واكتشاف الأدوات.
- **13Q.4:** اجتازت CI #154؛ شملت tools/list وtools/call، namespace، موافقة منفصلة، فحص schema وحدود البيانات وتنقيح الأسرار وسجل التدقيق. لا يدعي اختبار الخدمة اكتمال نافذة الموافقة المرئية في واجهة المحادثة.
- **13Q.5:** أضيف مستمع دورة الحياة لقطع الاتصال وحذف نسخة الجلسة عند التعطيل أو الحذف أو تغير المصدر، لكن CI #162 لم يتضمن خطوة قبول مستقلة لهذه الحالات؛ تظل بوابة 13Q.5 معلقة حتى تشغيل الاختبارات المخصصة. نافذة الموافقة المرئية في واجهة المحادثة غير مثبتة كذلك.
- **13R:** اختبارات Environment lifecycle وRobolectric وPhase13P Emulator اجتازت في CI #162؛ اختبار الهاتف الفعلي عند مغادرة الصفحة وإزالة التطبيق من Recents وStop بعد commit point ما زال مطلوباً.
- **PRoot:** Linux userland فقط، RootFS نشط مشترك وقابل للكتابة، والشبكة غير مقيدة بالكامل. لا تصفه كـkernel sandbox.
- **HTTP/SSE:** ما زال مرفوضاً لخوادم Skills حتى اكتمال DNS pinning وحماية SSRF وموافقة المضيف.

## التدقيق والخطة الجديدة — Phase 14

تم تثبيت خط الأساس على commit 9abb9dcc40881b005902265fdbd86d93248cb906. Git tree snapshot غير مبتور ويحتوي 4,237 ملفاً و634 مجلداً (4,871 عنصراً) و60,883,091 بايت من blobs.

- [Phase 14 — تقرير تدقيق المستودع ومصفوفة الاستفادة من OSS](PHASE-14-REPOSITORY-AUDIT-AND-OSS-REUSE-MATRIX-AR.md)
- [Phase 14 — الخطة المعمارية والتنفيذية والقيود](PHASE-14-UNIVERSAL-SKILLS-PLUGINS-TOOLS-AND-AGENT-ORCHESTRATION-AR.md)
- [Phase 14B — تقرير تنفيذ Plugin Manifest & Component Registry](PHASE-14B-PLUGIN-MANIFEST-COMPONENT-REGISTRY-AR.md)
- [Phase 14 — فهرس كل مسارات Git عند baseline](PHASE-14-REPOSITORY-TREE-MANIFEST-2026-11-24.json)

**حالة التنفيذ — 25 نوفمبر 2026:**
- **14A مقبولة:** اجتازت اختبارات Progressive Skill discovery في CI #162، إلى جانب Flutter Analyze واختبارات البناء Android ARM64 الكاملة.
- **14B قيد التنفيذ:** أضيفت نماذج Plugin manifest/component، فحص directory وZIP للقراءة فقط، سجل Parent Plugin ضمن ExtensionRegistry، حفظ staged مع rollback، وصفحات عرض المكونات وإدارتها. اختبار CI لهذه التغييرات ما زال مطلوباً قبل قبول 14B.
- لا تشغل هذه المرحلة Commands أو Hooks أو Scripts أو MCP servers؛ جميع descriptors تبقى metadata-only، والخدمات غير المدعومة تظهر بتحذير.
- اختبارات الهاتف الفعلي ليست مستنتجة من نجاح محاكي Android.

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
| 13P | PHASE-13P-END-TO-END-SKILL-TESTING-AR.md | Emulator E2E اجتازت CI #162؛ الهاتف الحقيقي غير مفحوص هنا |
| 13Q | PHASE-13Q-SKILL-MCP-ADAPTER-INTEGRATION-AR.md | 13Q.1–13Q.4 backend مقبولة؛ 13Q.5 واختبار موافقة الواجهة المرئية ما زالا مفتوحين |
| 13R | PHASE-13R-ENVIRONMENT-INSTALL-LIFECYCLE-AR.md | اختبارات lifecycle/Robolectric في CI #162 نجحت؛ اختبار الهاتف مطلوب |
| 14A | PHASE-14-UNIVERSAL-SKILLS-PLUGINS-TOOLS-AND-AGENT-ORCHESTRATION-AR.md | مقبولة في CI #162 |
| 14B | PHASE-14B-PLUGIN-MANIFEST-COMPONENT-REGISTRY-AR.md | تنفيذ مبدئي قيد CI؛ القبول معلّق حتى نجاح البناء والاختبارات |
| Reel Studio | REEL-STUDIO-GAP-ANALYSIS-AR.md | Orchestrator والإنتاج المتزامن العام غير منفذين |

## أرشيف CI

احتفظ بتقارير الفشل والإصلاح التاريخية. تقارير البناء الخام توجد في ../build-report/ عند توفرها.
