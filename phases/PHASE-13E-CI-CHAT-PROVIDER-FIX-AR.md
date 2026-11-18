# Phase 13E — تصحيح اعتماد ChatService في اختبار ربط المحادثة

**التاريخ:** 2026-11-12  
**الحالة:** إصلاح إعداد الاختبار وتجهيز CI لإعادة التشغيل؛ لم يُنفّذ Flutter Test أو بناء APK بعد هذا التعديل.

## 1. ملخص تشغيل CI الذي فشل

- **GitHub Actions run:** `43136577076`
- **Commit:** `f5c7a66739f9a75432fa3d49d843d26173c8f9c5`
- **المستودع:** `m5ham3ds/KELIVO`
- **فرع البناء:** `main`
- **وضع البناء:** Release، Android ARM64
- **نطاق الاختبارات:** Phase 13E فقط؛ اختبارات 13A–13D التاريخية غير مدرجة.

اجتاز حل الاعتماديات دون تعديل `pubspec.lock`، واجتاز Android-only audit وPhase 13E Preflight. كما اجتازت جميع الحالات التسع في `environment_status_tool_test.dart`.

توقف مسار الاختبارات عند الحالة:

`ready conversation PRoot context exposes Shell and Skill execution`

والاستثناء:

`ProviderNotFoundException: Could not find the correct Provider<ChatService> above this SizedBox Widget`

وقع الاستثناء في `ToolHandlerService._buildMcpToolDefinitions()` عند استدعاء `contextProvider.read<ChatService>()` لأن الاختبار مرّر `conversationId` لكنه لم يضع `ChatService` في شجرة Provider الخاصة به.

## 2. تحديد طبيعة الخلل

هذا فشل في إعداد اختبار Widget، وليس دليلًا على فشل Runtime أو PRoot أو على غياب ChatService من التطبيق الفعلي.

تم التحقق من أن `MyApp` في `lib/main.dart` يسجل `ChatService` داخل `MultiProvider` الرئيسي باستخدام `ChangeNotifierProvider`، قبل استخدام `ToolHandlerService` في التطبيق.

كان اختبار `tool_handler_workspace_gating_test.dart` يوفّر `AssistantProvider` و`McpProvider` و`McpToolService`، لكنه أغفل `ChatService` رغم أن استدعاء `buildToolDefinitions` في الحالة الجديدة يمرر `conversationId` غير فارغ. لذلك وصل التنفيذ إلى قراءة Provider غير موجودة قبل الوصول إلى تأكيدات Shell وSkill.

## 3. التصحيح

تم تعديل `test/features/home/services/tool_handler_workspace_gating_test.dart` فقط على مستوى إعداد الاختبار:

- إضافة استيراد `ChatService` ونموذج `Conversation`.
- إضافة `_EmptyChatService extends ChatService` يعيد `null` من `getConversation`، لتفادي فتح قاعدة بيانات حقيقية في هذا الاختبار.
- تسجيله في شجرة الاختبار بواسطة `ChangeNotifierProvider<ChatService>.value`.
- تسجيل `dispose` عبر `addTearDown`.
- إبقاء `conversationId` موجودًا في الاستدعاء، حتى يظل الاختبار يغطي المسار الحقيقي الذي يقرأ المحادثة عند بناء قائمة أدوات MCP.

لم يتم تعطيل أو إزالة استدعاء MCP، ولم تتم إزالة `conversationId` لإخفاء المشكلة؛ أُكمل اعتماد الاختبار المطلوب بدل تجاوز فرع الكود.

## 4. منع تكرار الخطأ

تم توسيع `.github/scripts/preflight_phase13e_tests.sh` ليتأكد من أن اختبار Workspace gating يحتوي على:

- استيراد `ChatService`.
- نموذج `Conversation`.
- Fixture مستقل `_EmptyChatService`.
- تسجيل `ChangeNotifierProvider<ChatService>`.
- تنظيف الـFixture في نهاية الاختبار.

وبذلك لن يمر Preflight مستقبلًا إذا أُضيف اختبار محادثة يحمل `conversationId` دون توفير ChatService.

## 5. ما اجتاز وما لم يُشغّل في تشغيل CI السابق

**اجتاز في التشغيل السابق:**

- Android-only audit.
- Dependency resolution؛ وذكر السجل أن `pubspec.lock remained unchanged`.
- Phase 13E Preflight.
- جميع الحالات التسع في `environment_status_tool_test.dart`.

**فشل:**

- اختبار Workspace gating بسبب غياب Provider في شجرة الاختبار، قبل تنفيذ تأكيدات الاختبار.

**لم يُشغّل بسبب توقف المسار:**

- Package ledger test.
- Read-only Skill update test.
- Built-in tool registration test.
- Localization validation/generation.
- Java، NDK، CMake، وAndroid ARM64 Release APK build.
- رفع APK وحساب SHA-256.

رسالة `File modified during build. Build must be rerun.` ظهرت كتحذير قبل نتيجة الاختبار؛ لكنها لم تكن سبب خروج الأمر بالرمز 1. سبب التوقف الفعلي هو `ProviderNotFoundException`.

## 6. نطاق الاختبارات التاريخية

لم تتم إعادة أو تعديل اختبارات 13A أو 13B أو 13C أو 13D. بقيت ملفاتها التاريخية محفوظة خارج خط البناء النشط. مسار CI يستمر في تشغيل اختبارات Phase 13E المركزة فقط.

## 7. التحقق المحلي وحدوده

تمت مراجعة موضع القراءة في `ToolHandlerService`، ومقارنته بتسجيل `ChatService` في `lib/main.dart`، وإضافة Fixture وProvider إلى اختبار المحادثة، وتقوية Preflight للتحقق من وجود هذا الاعتماد.

بيئة تجهيز الأرشيف لا تحتوي على Flutter أو Dart؛ لذلك لم يمكن تشغيل `flutter test` أو `dart analyze` أو بناء APK محليًا بعد الإصلاح. يجب أن يعتمد القبول التالي على تشغيل GitHub Actions جديد.

## 8. معيار القبول التالي

1. نجاح Phase 13E Preflight بما في ذلك فحص ChatService fixture.
2. نجاح جميع اختبارات `environment_status_tool_test.dart`.
3. نجاح اختبار Workspace gating بعد إنشاء قائمة الأدوات مع `conversationId`.
4. نجاح Package ledger وSkill update وTool registration المحددة.
5. نجاح فحص الترجمة وتوليدها.
6. نجاح بناء Android ARM64 Release ورفع APK مع SHA-256.

لا تُعاد بوابات 13A–13D، ولا تعتبر Phase 13E مقبولة نهائيًا قبل اجتياز اختبار PRoot الفعلي على جهاز Android بعد تثبيت APK.
