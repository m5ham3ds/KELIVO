# Phase 14E — Implementation Status & CI Evidence

**تاريخ المزامنة:** 27 نوفمبر 2026  
**المستودع:** `m5ham3ds/KELIVO`  
**الفرع:** `main`  
**آخر commit موثق:** `77736b783d55752a35a3aeb3b66b6b6dce7e87f1`  
**الحالة:** 14E.1 و14E.2 اجتازتا الاختبارات المخصصة؛ Phase 14E ككل لا تزال قيد التنفيذ وغير مقبولة نهائياً.

## 1. خط الأساس والبوابات السابقة

- Phase 14A: مقبولة عبر CI #162.
- Phase 14B: مقبولة عبر CI #164.
- Phase 14C: مقبولة بالكامل عبر CI #199، بما فيها MRTR و`subscriptions/listen`.
- Phase 14D: مقبولة بالكامل عبر CI #204؛ تضمنت اختبار Skill-owned MCP STDIO الحقيقي والحالات العدائية.
- لا تُعاد هذه المراحل إلا إذا غيّر تعديل لاحق عقداً مشتركاً يخصها.

## 2. Phase 14E.1 — Registry foundation

اجتازت الاختبارات المخصصة في [CI #206](https://github.com/m5ham3ds/KELIVO/actions/runs/45915687173) على commit `05fadf6db2371a68bfa02869dc2efc6f84543d03`.

التغطية شملت Registry وToolsets، تعارض الأسماء عبر namespaces، direct/deferred/hidden exposure، التحميل المؤجل وإخفاء schema قبل الحاجة، حدود عدد الأدوات وحجم schema والمخرجات، تجميد التعريفات، الإلغاء وفحوص مسارات MCP القائمة.

## 3. Phase 14E.2 — Turn-scoped conversation integration

بدأ تكامل جلسة Registry مع دورة توليد المحادثة على commit `a3994d346944bc3b778bee2e5207d0b4fd6ed53c`، لكنه تعثر في CI #207 عند Flutter Analyze بسبب fixture اختبار لا يمرر الوسيط الإلزامي `toolRegistrySession` إلى `UnprocessedRequestContext`.

أصلح commit `77736b783d55752a35a3aeb3b66b6b6dce7e87f1` الاختبار بإضافة جلسة Registry للـfixture في `test/features/home/services/workspace_prompt_test.dart`. لم يتطلب التصحيح إنشاء dispatcher أو approval gateway موازٍ، وبقي التنفيذ والموافقة في مسار KELIVO الأصلي.

اجتازت خطوة `phase14e_tool_registry_tests` في CI #208، وشغّلت الملفات التالية:

- `test/core/services/tools/tool_registry_test.dart`
- `test/core/services/tools/built_in_tool_catalog_test.dart`
- `test/core/services/mcp/mcp_tool_service_test.dart`
- `test/features/home/services/tool_handler_service_test.dart`
- `test/features/home/services/message_generation_protocol_test.dart`
- `test/core/services/api/generation/tool_loop_runner_test.dart`

تثبت هذه البوابة تكامل الجلسة والـGateway مع اختبارات Registry وTool Handler وMCP ودورة طلبات الأدوات. لا تثبت إكمال كل متطلبات Toolsets/Deferred exposure في Phase 14E.

## 4. CI #208 — نتيجة البناء الشاملة

[GitHub Actions #208](https://github.com/m5ham3ds/KELIVO/actions/runs/45926843283) اكتمل بنجاح على `main` commit `77736b783d55752a35a3aeb3b66b6b6dce7e87f1`.

**وظيفة البناء:**
- Android-only audit وRelease hardening: نجاح.
- Flutter 3.47.6 dependency resolution وArabic parity وgen-l10n: نجاح.
- Flutter Analyze: نجاح.
- Environment lifecycle: نجاح.
- Phase 14A: نجاح (34 اختباراً).
- Phase 14B: نجاح (9 اختبارات).
- Phase 14E.2 Registry gateway: نجاح.
- Gemini/OAuth وPhase 14C.4: نجاح.
- Phase 13Q/14D real STDIO: نجاح.
- الحزم المحلية الخمس: نجاح.
- Android JVM/Robolectric: نجاح.
- Phase 13P Android Emulator E2E: نجاح.
- APK ARM64 وABI/SHA-256 ورفع Artifact: نجاح.

**وظيفة التقرير:** تنزيل السجلات، توليد تقرير Markdown ورفعه: نجاح.

## 5. APK المعتمد من CI #208

- الاسم: `Kelivo-Android-arm64-v8a-release.apk`.
- الحجم: 41,943,583 bytes.
- ABI: `arm64-v8a` فقط.
- SHA-256: `29fa1b9db0223dd0b9c6d8f170af3b86f6d44f2f5dd88a992843bd09f907f6fa`.
- APK Artifact ID: `15167472926`.
- Build report Artifact ID: `15167378117`.
- Raw diagnostics Artifact ID: `15167717401`.

الأدلة:
- [CI #208](https://github.com/m5ham3ds/KELIVO/actions/runs/45926843283)
- [APK ARM64](https://github.com/m5ham3ds/KELIVO/actions/runs/45926843283/artifacts/15167472926)
- [Build report](https://github.com/m5ham3ds/KELIVO/actions/runs/45926843283/artifacts/15167378117)
- [Raw diagnostics](https://github.com/m5ham3ds/KELIVO/actions/runs/45926843283/artifacts/15167717401)

## 6. حدود الإثبات

- الـworkflow لا يشغّل كامل Flutter root unit/widget suite.
- لا يشغّل جميع اختبارات Phases 13E–13O التاريخية؛ Analyze لا يعوضها.
- Android Emulator لا يثبت Force Stop على هاتف فعلي.
- APK CI يستخدم debug signing fallback عند غياب `android/key.properties`، ولا يمثل توقيع متجر.
- لا يثبت نجاح #208 أن جميع Toolsets الفعلية قد صُنفت أو أن كل أدوات التطبيق اختبرت parity مع كل مزود.

## 7. ما تبقى لإغلاق Phase 14E

1. ربط built-in tool catalogs وMCP وWorkspace بمجموعات Toolsets ذات namespaces فعلية بدلاً من الاعتماد العام على `core`.
2. إجراء parity للتحقق من أن تعريفات الأدوات الحالية لم تتغير بعد provider schema translation وschema overrides.
3. جعل اختيار Toolsets يتبع سياق assistant/task/workspace/Skill مع المحافظة على السلوك الافتراضي.
4. تفعيل direct/deferred/hidden exposure في طلبات النموذج الفعلية، مع deferred loading عند الحاجة.
5. فرض حدود عدد الأدوات وحجم schema وtoken budgets على المسار الفعلي.
6. الحفاظ على هوية MCP route snapshot والموافقات والإلغاء وoutput caps، وعدم إنشاء handler أو permission gateway موازٍ.
7. تشغيل بوابة Phase 14E المجمعة ثم مراجعة كل job وstep والتقرير وAPK hash قبل إعلان القبول.

**قرار التسلسل:** تبقى 14F و14G و14H متوقفة حتى إغلاق Phase 14E بالكامل. لا يوجد تعريف معتمد لشريحة فرعية 14E.3 في الوثيقة؛ لذلك لا يضيف هذا التقرير ترقيم مرحلة جديداً، بل يسجل الأعمال المتبقية داخل 14E.
