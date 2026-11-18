# Phase 13E — إصلاح فشل Preflight بسبب تنسيق Dart

**التاريخ:** 2026-11-12  
**تشغيل CI:** `43140362011`  
**Commit الذي فشل:** `392e348d609ddac55a8a71c07ea5637b2aec379d`  
**الحالة:** تم تصحيح فحص Preflight؛ يلزم تشغيل GitHub Actions جديد للتحقق من الاختبارات والبناء.

## 1. سبب الفشل الدقيق

في التشغيل `43140362011` نجح:

- Android-only source audit.
- إعداد Flutter 3.47.6 وتسجيل إصدارات الأدوات.
- `flutter pub get` دون تغيير `pubspec.lock`.
- تجهيز اعتماديات Linux المطلوبة لاختبارات Flutter.

ثم فشل `Preflight focused Phase 13E regressions` قبل تشغيل اختبارات Flutter، عند التحقق من تسجيل `ChatService` في اختبار:

`test/features/home/services/tool_handler_workspace_gating_test.dart`

رسالة Preflight كانت:

`FAIL: workspace-gating test is missing Provider<ChatService> registration`

لكن فحص المصدر الفعلي يثبت أن الاختبار يحتوي بالفعل على:

```dart
ChangeNotifierProvider<ChatService>.value(
  value: chatService,
),
```

كما يحتوي على `_EmptyChatService`، واستيراد `ChatService` و`Conversation`، وتنظيف الـfixture عبر `addTearDown`.

إذًا لم يكن `ChatService` مفقودًا من الاختبار. الخطأ كان في Preflight نفسه: كان يستخدم مقارنة نصية حرفية تتوقع الاستدعاء كله في سطر واحد:

`ChangeNotifierProvider<ChatService>.value(value: chatService)`

بينما Dart formatter وزّع المعاملات على أسطر متعددة. هذا **فشل كاذب ناتج عن حساسية الفحص للمسافات والأسطر**، وليس خطأ ProviderNotFoundException جديدًا.

## 2. التصحيح المنفذ

عُدّل فقط:

`.github/scripts/preflight_phase13e_tests.sh`

استُبدل فحص العبارة الحرفية بتعبير منتظم يقبل توزيع الأسطر والمسافات بين:

- `ChangeNotifierProvider`
- النوع `ChatService`
- الاستدعاء `.value`
- الوسيط `value: chatService`

وأضيف self-check صغير يختبر matcher نفسه على صيغتين: صيغة مختصرة وصيغة Dart متعددة الأسطر. لم يتم تغيير اختبار Workspace gating نفسه لأن تسجيل `ChatService` فيه صحيح أصلًا.

## 3. ما الذي لم يتغير

- لم يتغير منطق التطبيق أو `ToolHandlerService`.
- لم تتغير قناة Android PRoot أو Shell أو Skill execution.
- لم تتغير صلاحيات الموافقة اليدوية.
- لم تتغير الاعتماديات أو `pubspec.lock`.
- لم تُحذف أو تُعدّل اختبارات 13A–13D التاريخية.
- بقيت اختبارات 13A–13D خارج Workflow النشط.
- بقي نطاق CI مقتصرًا على اختبارات Phase 13E المعتمدة.

## 4. نتيجة التشغيل الذي أرسل المستخدم سجلاته

| المرحلة | النتيجة |
|---|---|
| Android-only audit | نجح |
| Flutter setup | نجح |
| Dependency resolution | نجح، و`pubspec.lock` لم يتغير |
| Linux native test dependencies | نجح |
| Phase 13E Preflight | فشل كاذب بسبب مطابقة نصية حساسة للتنسيق |
| Flutter tests | لم تبدأ |
| Localization checks | لم تبدأ |
| Android ARM64 APK | لم يبدأ |

لم يكن هناك فشل Dart compile أو فشل لاختبار Flutter في هذا التشغيل؛ توقف CI قبل مرحلة الاختبارات.

## 5. الفحوص بعد تعديل Preflight

تم التحقق محليًا من أن:

- تسجيل `ChatService` موجود في اختبار Workspace gating.
- matcher الجديد يطابق الصيغة ذات السطر الواحد والصيغة متعددة الأسطر.
- سكريبت Preflight يحتفظ بفحوص استبعاد مراحل 13A–13D.
- لم يتغير أي ملف من ملفات الاختبار أو التطبيق أو الاعتماديات في هذه الرقعة.

تعذر تشغيل Flutter/Dart في بيئة تجهيز الأرشيف؛ لذلك لا يُدّعى أن Flutter Tests أو APK اجتازا. معيار القبول هو تشغيل CI جديد بنجاح.

## 6. معيار القبول التالي

1. ينجح Preflight، خصوصًا فحص `ChatService` متعدد الأسطر.
2. تبدأ اختبارات Phase 13E بدل تخطيها.
3. يجتاز Workspace gating مع `conversationId`.
4. تجتاز اختبارات Package Ledger وSkill Updates وTool Registration.
5. تنجح مطابقة الترجمة وتوليدها.
6. ينجح بناء Android ARM64 Release ويرتفع APK مع SHA-256.

لا تُعاد بوابات 13A–13D.
