# KELIVO — فهرس المراحل والحالة

هذه صفحة تنقل مختصرة. لا تعتبر المرحلة مكتملة لمجرد وجود ملفاتها؛ ارجع إلى معايير القبول والأدلة.

## آخر بناء ونتيجة معتمدة

آخر بناء كامل ناجح: CI #73  
https://github.com/m5ham3ds/KELIVO/actions/runs/45036728943  
Commit `8258af4ce3ed160919416a947abb06059d0e1f0a` · Flutter 3.47.6 · Java 21 · NDK 28.2.13676358 · CMake 3.22.1.  
APK Release 41,825,267 bytes؛ ABI `arm64-v8a` فقط؛ SHA-256 `1c05d9f3356af5c94d155b1f92be4a88fb5b1d372545f701455169066727f585`.

## آخر تشغيل وفشله

CI #76، المحاولة الثانية، فشل على commit `f68e792b771822b31522705720a2ecc82c2d5606`:  
https://github.com/m5ham3ds/KELIVO/actions/runs/45040545406

نجح Flutter Analyze واختبار 13Q.1 واختبارات الحزم المحلية، ثم تعذر حل Robolectric runtime dependency `org.robolectric:nativeruntime-dist-compat:1.0.18` بسبب HTTP 429 من Maven Central. لم يصل التشغيل إلى Android Emulator أو بناء APK، ولم ينتج APK. أضيفت مرآة Google Hosted Maven Central scoped لمجموعة `org.robolectric`؛ نجاح هذا الإصلاح ينتظر تشغيل CI لاحق.

**حدود آخر نجاح:** workflow لا يشغّل كامل Flutter root unit/widget suite ولا مجموعات Phase 13E–13O التاريخية؛ التحليل الثابت لا يعادل تنفيذ تلك الاختبارات. اجتازت في CI #73 اختبارات الحزم المستقلة وAndroid JVM/Robolectric واختبارات Android integration الأربعة بما فيها Phase 13P emulator E2E. 13Q.1 فقط اجتازت؛ دورة MCP الفعلية ما زالت مفتوحة.

## حالة الآن
- **13P:** اجتازت emulator E2E في CI #73، وليس هذا اختبار هاتف المستخدم أو عزل Kernel.
- **13B:** ما زالت مفتوحة؛ Skill local-script موجود لكن Skill-owned MCP adapter ودورة tools/list/tools/call غير مكتملة.
- **13Q:** 13Q.1 اجتازت في CI #73 و#76. 13Q.2–13Q.5 مفتوحة: ملكية الخادم، الاتصال وtools/list، tools/call بموافقة لكل أداة، والإلغاء عند تغير/حذف/تعطيل Skill.
- **Android CI repair:** مرآة Google Hosted Maven Central مضافة لمجموعة Robolectric؛ التحقق جارٍ عبر CI الجديد.
- **HTTP/API وWorkflow وnative tools:** تحتاج موائمات مستقلة؛ مجرد descriptor لا يجعلها قابلة للتشغيل.
- **PRoot:** Linux userland داخل Android وليس Kernel sandbox؛ RootFS مشترك والشبكة ليست مقيدة بالكامل.

## وثائق المرجع
- [الخطة الهندسية الرئيسية](MASTER-DEVELOPMENT-PLAN-AR.md)
- [وصف المنتج](../PRODUCT.md)
- [دليل بناء Android](ANDROID_BUILD_AR.md)
- [تدقيق Android-only](ANDROID_ONLY_AUDIT.md)
- [تقرير التشغيل التلقائي](BUILD_AUTOMATION_REPORT_AR.md)
- [الخطة المعمارية Phase 13](PHASE-13-SKILLS-WORKSPACE-ARCHITECTURE-AND-IMPLEMENTATION-PLAN.md)
- [Phase 13Q — موائم MCP للمهارات](PHASE-13Q-SKILL-MCP-ADAPTER-INTEGRATION-AR.md)

## المراحل الأساسية
| المرحلة | ملفاتها المرجعية | الحالة |
|---|---|---|
| 00 | PHASE-00-BASELINE-AND-SOURCE-CONTRACT.md | خط الأساس |
| 01 | PHASE-01-MODULAR-CORE-EXTENSION-REGISTRY.md · PHASE-01-IMPLEMENTATION-REPORT.md | تنفيذ موثق |
| 02 | PHASE-02-CONVERSATIONAL-EXTENSION-COMMANDS.md · PHASE-02-COMPLETION-AND-ACCEPTANCE.md | قبول CI سابق موثق |
| 03 | PHASE-03-IMPLEMENTATION-REPORT.md | مراجعة قبول مطلوبة |
| 04 | PHASE-04-MULTI-SKILL-COMPOSITION-ENGINE.md · PHASE-04-IMPLEMENTATION-REPORT.md | تنفيذ مرحلي |
| 05 | PHASE-05-UNIVERSAL-DEPENDENCY-PACKAGE-MANAGER.md · PHASE-05-IMPLEMENTATION-REPORT.md | قبول شامل معلّق |
| 06 | PHASE-06-RUNTIME-PROFILES-AND-EXECUTION-ISOLATION.md · PHASE-06-IMPLEMENTATION-REPORT.md | قبول الجهاز معلّق |
| 07–12 | مواصفات وتقارير Phase 07–12 في هذا المجلد | تحتاج اختبارات محرك/مزود فيديو، QA، قياسات جهاز ومراجعة أمن |
| 13A–13D | تقارير PHASE-13A/B/C/D-IMPLEMENTATION-REPORT.md | 13B مفتوحة حتى موائم MCP |
| 13E–13P | مواصفات وتقارير Phases 13E–13P | 13P emulator E2E مقبولة في CI؛ الباقي يخضع لأدلته |
| 13Q | PHASE-13Q-SKILL-MCP-ADAPTER-INTEGRATION-AR.md | قيد التنفيذ |

## أرشيف CI
أبقِ تقارير الفشل والإصلاح التاريخية للمراحل 02 و13E و13K.1–13K.5. هي سجل تشخيصي وليست الحالة الراهنة. تقارير البناء الخام موجودة في ../build-report/.
