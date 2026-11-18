# تقرير تنفيذ Phase 5 — Universal Dependency & Package Manager

## الحالة

تم تجهيز تغييرات المصدر والاختبارات المركزة لهذه المرحلة. **لم تُعتمد المرحلة بعد**: يلزم تشغيل Dart analysis والاختبارات المعلنة وبناء Android ARM64 Release عبر GitHub Actions. لم يكن Dart/Flutter SDK متاحاً في بيئة التحرير، لذلك لا أدّعي نجاح هذه الخطوات محلياً.

وبحسب طلب المستخدم، بدأ تنفيذ Phase 5 مباشرة بعد Phase 4. لا يغيّر ذلك حالة الاعتماد الرسمية للمراحل السابقة: Phase 3 وPhase 4 تظلان بانتظار CI وقبول معايير التسليم الخاصة بهما.

## ما تم تنفيذه

- إضافة `PackageManagerAdapter` وعائلة adapters لـ apt/apk وpip/uv وnpm/pnpm/yarn/bun.
- اكتشاف الأدوات المتاحة داخل PRoot، والتوزيعة ومعمارية التشغيل، مع اختيار مدير الحزم بحسب النظام البيئي وملفات قفل Node.
- إضافة محلل read-only لملفات `requirements.txt` و`pyproject.toml` الأساسي و`package.json`، مع الإبلاغ عن المراجع غير المدعومة ومجالات الإصدارات غير المقفلة.
- قراءة اعتماديات Skill من مفاتيح `metadata` القياسية دون تثبيتها تلقائياً أو أثناء استيراد Skill.
- إضافة أداة المحادثة المحلية `package_manager` لدعم plan/check/install/upgrade/remove/pin/unpin/list.
- فرض الموافقة لكل عملية معدِّلة، بما فيها pin/unpin، وإبقاء plan/check/list للقراءة فقط.
- رفض URL وGit والمراجع المحلية وخيارات shell؛ وإيقاف Python source builds وNode lifecycle scripts افتراضياً؛ ويُستخدم إعداد بيئي متوافق مع Yarn Classic وYarn Berry بدلاً من تمرير خيار غير مدعوم في Berry.
- تقسيم تخزين Python وNode إلى نطاقات runtime/project/extension/task، وفصل lockfiles وفق النطاق والنظام البيئي. apt/apk محصوران في runtime المشترك داخل PRoot.
- حفظ سجل الإصدارات والعمليات في BusinessPreferences/SQLite الحالي، دون إضافة تغيير مخطط قاعدة البيانات.
- التقاط نسخة حالة الحزم قبل التعديل ومحاولة rollback عند فشل العملية أو التحقق.
- إضافة فحص binaries عبر PATH الخاص بالنطاق عند طلب ذلك، ورسائل توافق للتوزيعة ومعمارية ARM64.
- ربط الأداة بكتالوج الأدوات ومعالج استدعاء المحادثة وواجهة بطاقة نتائج أدوات مساحة العمل.

## ملفات المصدر الرئيسية

- `lib/core/services/packages/package_manager_models.dart`
- `lib/core/services/packages/package_manager_adapters.dart`
- `lib/core/services/packages/dependency_manifest_parser.dart`
- `lib/core/services/packages/package_ledger_store.dart`
- `lib/core/services/packages/package_manager_service.dart`
- `lib/core/services/packages/package_manager_tools.dart`
- `lib/features/home/services/tool_handler_service.dart`
- `lib/features/home/services/built_in_tool_names.dart`
- `lib/features/chat/widgets/workspace_tool_ui.dart`

## الاختبارات المضافة/المحدثة

تتضمن قائمة `.github/ci/android-phase5-test-manifest.txt` **24 ملف اختبار محدداً**، تشمل:

- اختبارات توافق واستيراد Skills ودورة حياة الإضافات.
- اختبارات محلل manifests وبيانات Skill.
- اختبارات أوامر adapters والتوافق مع التوزيعات وإيقاف scripts افتراضياً.
- اختبارات عزل النطاقات والمفاتيح وملفات القفل.
- اختبارات ledger وتاريخ العمليات.
- اختبار تكامل لخدمة package manager يحاكي دورة plan/install/check/remove لحزمة apt بإصدار محدد.

ويشغّل سكربت الاختبارات كذلك **أربع حالات UI مسماة فقط** داخل `workspace_tool_ui_test.dart`. لا يشغّل مجموعة الاختبارات الكاملة أو اختبارات iOS/macOS/Windows/Linux/Web أو `integration_test` عموماً أو markstream مستقلاً.

## التحقق الذي تم في بيئة التحرير

- `bash -n` لسكربتات تحليل واختبار Phase 5 وتدقيق Android-only وتنسيق الملفات وتجهيز APK: نجح.
- Android-only audit: نجح، بما يشمل Android target وARM64 ABI وتحقق checksums لمكتبات PRoot الأربعة.
- YAML parsing لسير العمل `android-build.yml` و`pr-check.yml`: نجح.
- فحص manifest: توجد ملفات الاختبار الـ24 جميعها، ولا يوجد مسار مفقود؛ وأُضيف تحقق خاص لإعدادات منع lifecycle scripts في Yarn Classic وBerry.
- سكربت CI يستخدم manifest Phase 5 وأربع حالات UI مسماة فقط.
- لا يتوفر `dart` أو `flutter` في بيئة التحرير؛ لذلك لم تُشغّل Dart format أو Dart analyzer أو Flutter tests أو APK build محلياً.
- تم التحقق من سلامة أرشيف التسليم بعد إنشائه.

## قيود معروفة

1. قائمة adapters الحالية محددة بالموجة الأولى. دعم أي مدير آخر يتطلب Adapter جديداً واختبارات، ولا ينفذ Kelivo أوامر package managers مجهولة.
2. `pyproject.toml` parser يغطي `[project].dependencies` الأساسي فقط، ولا يحل كل صيغ Poetry/PDM/uv groups أو TOML المعقد.
3. محلل requirements/package.json لا ينفذ include files أو scripts أو Git/URL references؛ يعرض التحذيرات/يرفض التثبيت عند عدم وجود exact pins.
4. استعادة الفشل تعمل على الحزم المسجلة في العملية، وليست نسخة كاملة من نظام PRoot أو ضماناً لاستعادة كل اعتماد انتقالي قد يغيره مدير النظام.
5. apt/apk يغيران بيئة PRoot المشتركة ولا يمكن عزلهما لكل مشروع؛ عزل Runtime Profiles الكامل يقع في Phase 6.
6. توافق ARM64 يعرض التحذيرات ويتحقق من الأوامر؛ لا يمكنه ضمان أن كل مكتبة Native متوافقة مع Android/PRoot/libc قبل تنفيذ اختبار خاص بها.
7. لا يتضمن هذا التسليم تنفيذ Skills أو تشغيل سكربتاتها أو إدارة محركات الفيديو.

## مصدر المشروع

بُنيت هذه النسخة على آخر أرشيف مصدر كامل كان متاحاً في المحادثة: `KELIVO-PHASE4-MULTI-SKILL-COMPOSITION.zip`. لم يرفق المستخدم أرشيفاً أحدث من مستودع GitHub في هذا الطلب؛ لذلك لا تشمل الحزمة أي تغييرات موجودة حصراً في المستودع ولم تكن ضمن ذلك الأرشيف.

## الخطوة التالية

ارفع هذه النسخة وشغّل GitHub Actions. لا تُعلن Phase 5 مكتملة حتى تنجح خطوات Dart analysis والاختبارات الـ24 وأربع حالات UI وبناء Android ARM64 Release. عالج أخطاء التقرير الفعلية فقط، دون توسيع قائمة الاختبارات عشوائياً.
