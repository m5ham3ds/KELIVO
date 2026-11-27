# حالة تنفيذ Environment Presets وMedia tools — مزامنة 2026-11-27

**الحالة الحالية:** اجتازت اختبارات Environment install lifecycle في CI #208، إلى جانب Flutter Analyze وAndroid JVM/Robolectric وPhase 13P Android Emulator وبناء ARM64 ونشر التقرير. لا يزال اختبار دورة التثبيت على هاتف Android فعلي مطلوباً؛ نجاح CI/Emulator لا يثبت Force Stop أو عزل Kernel.


## ما تم حفظه على main
- تقليص `EnvironmentDependency` إلى Presets العامة وMedia tools وBrowser Renderer؛ لم تعد أدوات media utilities مفاتيح enum مستقلة.
- إضافة صفحة Media tools مجمعة تعرض الأدوات الست وتفصل FFmpeg وFFprobe كأمرين مع حزمة نظام واحدة.
- إضافة مسار تثبيت مجمّع للوسائط في `EnvironmentDependencies`، مع استدعاء `dpkg --configure -a` قبل apt، وفحص أوامر FFmpeg وFFprobe وyt-dlp وMediaInfo وFFmpegthumbnailer وImageMagick بعد التثبيت.
- توصيل `PackageManagerEnvironmentTools.resolve` بمسار تنفيذ `package_manager` قبل طلب الموافقة النظامية، مع دعم أسماء ImageMagick البديلة.
- إضافة اختبارات وحدة لمحلّل أسماء أدوات الوسائط واختبار تثبيت مجمّع.

## نقاط لم تعتبر مكتملة
- **حُلّت هذه الفجوة في تحديث 23 نوفمبر أدناه:** أضيف زر تثبيت منفصل لكل صف في صفحة Media tools مع الإبقاء على التثبيت الجماعي.
- لم تُنقل عملية APT إلى Android Foreground Service. `EnvironmentDependencies._run` ما زال يعتمد على `WorkspaceRuntime.run`، وخدمة الخلفية الأصلية الحالية مهيأة لمهام التوليد/المهام المجدولة، ولا تحمل نوعاً مستقلاً لتثبيت الحزم أو سجل استعادة دائم له. لا يُدّعى ضمان الاستمرار بعد مغادرة العملية أو Force Stop.
- إضافة إذن الإشعارات إلى Home تضيف شرحاً قبل الطلب وتخزن قرار عرض الشرح، لكنها لا تكفي وحدها لإشعارات تقدم APT؛ كما يلزم التحقق من سلوك الرفض الدائم واختبار دورة الحياة.
- **تحديث التحقق:** أدرجت اختبارات Environment lifecycle في الـworkflow الحالي واجتازت CI #208. لم يغلق ذلك اختبار الهاتف الفعلي؛ راجع PHASE-13R-ENVIRONMENT-INSTALL-LIFECYCLE-AR.md.

## تعليمات الاستكمال التاريخية — 23 نوفمبر
1. لا تُنشئ فرعاً آخر. تابع على `main` وفق `GIT-BRANCHING-POLICY-AR.md`.
2. كان CI #112 هو السياق وقت إعداد هذه التعليمات؛ CI الحالي الموثق هو #208.
3. أضف اختبارات UI لصفحة Media tools والـconfirmation والـstatus لكل أمر، وصحح أي lint/analyzer/test regressions.
4. نفّذ نوع BackgroundTask واضحاً مثل `environment_install` عبر خدمة Android foreground الحالية، مع فصل completion notification عن إشعارات المحادثة، snapshot persisted progress، cancellation يوقف العملية وأطفالها، ومنع إعادة الاستئناف بعد Force Stop/موت العملية. يجب اختبار task removal مقابل force stop.
5. اربط مثبت Environment مع coordinator/native service دون جعل عملية apt تعمل في Flutter Future عادي أو WorkManager.
6. اختبر permission rationale عند أول Home فعلي على Android 13+، واحترام الرفض/عدم التكرار، ثم تحقق من CI وAPK.
7. لا تعلن المرحلة مكتملة أو جاهزة للنشر حتى تكون اختبارات Dart وAndroid وCI ناجحة ومخرجات APK/التحقق موثقة.

## تحديث تنفيذ ملاحظات الجهاز — 2026-11-23

أضيفت التعديلات التالية إلى `main` بعد فحص مسارات التنفيذ الفعلية:

- أضيف زر تثبيت منفصل لكل صف في صفحة Media tools، مع الإبقاء على التثبيت الجماعي. تستخدم الأزرار قائمة سماح ثابتة لأسماء الأوامر والحزم؛ FFmpeg وFFprobe يثبتان حزمة `ffmpeg` المشتركة ويُتحقق من كل executable على حدة، كما يقبل فحص ImageMagick الاسمين `magick` و`convert`.
- أصبح تثبيت صورة النظام يبدأ من صفحة System image نفسها. تبقى الصفحة مفتوحة لعرض المرحلة والنسبة/البايتات، ويظل الرجوع إلى Environment ممكناً دون إلغاء العملية؛ ويمكن فتح صفحة System image مجدداً لمشاهدة حالة المثبت الجاري.
- رُبط تثبيت صورة النظام وجميع Environment dependency presets (مثل Python وNode وGit) والتثبيت الفردي والجماعي لأدوات الوسائط بمنسّق `MobileBackgroundCoordinator` وخدمة `GenerationForegroundService` القائمة. تُرسل مرحلة التثبيت والتقدم المتاح إلى إشعار المهمة، ويرسل إيقاف خدمة الخلفية طلب إلغاء إلى المثبت نفسه. لم تُنشأ خدمة Android موازية.
- استمرار العملية مشروط بإعداد تشغيل الخلفية الذي اختاره المستخدم وبقدرة Android على إبقاء الخدمة والعملية حيتين. السيناريو المستهدف هو الانتقال إلى تطبيق آخر أو إزالة Kelivo من Recents؛ لا يمكن ضمان إكمال stream جارٍ بعد Force stop أو قتل النظام للعملية أو إعادة تشغيل الجهاز. عند تشغيل التطبيق لاحقاً، يستعيد RootFS installer الحالة وفق منطق الاستعادة الموجود ويحافظ على التنزيل الجزئي القابل للاستئناف.

**التحقق السابق:** CI #115 على commit `7f6a925a03312479d4c313921fc1ec8e8230d944` نجح قبل هذه الإضافات، بما فيه Flutter Analyze وRobolectric وPhase 13P Android Emulator E2E وبناء APK ARM64. هذا لا يُعد دليلاً على نجاح التعديلات الحالية؛ يلزم CI جديد واختبار خلفية فعلي على الهاتف قبل اعتمادها.


## تحديث Phase 13R — إصلاح دورة حياة التثبيت (23 نوفمبر 2026)

هذا التحديث يتقدم على نقاط الاستكمال التاريخية أعلاه. مراجعة الكود وCI #120 أثبتت أن بناء النسخة السابقة نجح، لكنه لم يكن يتضمن الاختبارات المركزة لمشكلات دورة تثبيت البيئة الجديدة.

### الأسباب الجذرية

1. مدخل Media tools كان معطلاً بمجرد busy حتى عندما تكون المهمة النشطة هي تثبيت Media tools نفسه، ما يمنع العودة إلى صفحة المهمة وعرض حالتها.
2. صفحة System image لم تكن قابلة لإعادة الفتح دائماً لأن حالة busy المحلية في Environment pane كانت تمنع فتح صفحة التثبيت مرة أخرى.
3. بعد تثبيت Preset مفرد كان التطبيق يشغّل probe شاملاً لكل الحزم، بما فيه فحص Browser Renderer التجريبي الطويل؛ كان ذلك يمدد حالة busy دون علاقة بالحزمة المثبتة.
4. نافذة التحقق بعد نجاح APT/APK ظلت قابلة للإلغاء. بذلك يمكن تسجيل الإلغاء بعد أن أصبحت الحزمة مثبتة بالفعل.
5. زر Stop في إشعار Foreground كان قد يوقف الخدمة قبل وصول Dart إلى نهاية الإلغاء الفعلية أو أثناء مرحلة تحقق غير قابلة للتراجع.

### ما تغير في Phase 13R

- إعادة فتح صفحة System image وMedia tools تعرض المثبّت/الخدمة الجاريين نفسيهما دون إطلاق تثبيت ثانٍ.
- أصبح التحقق بعد كل Preset محدوداً بالأوامر الخاصة بذلك الـPreset؛ التثبيت الفردي لأداة Media يتحقق من أوامر Media tools، والتثبيت الجماعي يتحقق من الأدوات الست.
- يُعامل خروج مدير الحزم APT/APK برمز نجاح كحد commit. بعده يستمر فحص التنفيذيات والنسخ، لكن تتعطل خاصية الإلغاء وتعرض الواجهة مرحلة التحقق بدلاً من زر إلغاء.
- بعد استبدال RootFS ذرياً، لا يقبل المثبّت إلغاءً متأخراً.
- أضيف حقل cancellable إلى حالة المهمة المرسلة إلى Android. زر Stop لا يظهر للمهمة غير القابلة للإلغاء، وطلب إيقاف قديم لا ينهي Foreground Service قبل وصول snapshot نهائي من Dart.
- أضيفت اختبارات Regression لـtargeted probe، ورفض الإلغاء بعد commit، وإعادة فتح الصفحات، وبقاء الخدمة أثناء إنهاء الإلغاء.

### التحقق المطلوب

أضيف GitHub Actions step مستقل لتشغيل هذه الملفات:
- test/core/services/sandbox/environment_dependencies_test.dart
- test/features/workspace/environment/environment_presets_test.dart
- test/core/services/sandbox/environment_installer_test.dart
- test/core/services/mobile_background_test.dart

يلزم نجاح هذه الاختبارات، Flutter Analyze، Robolectric، Phase 13P E2E وبناء ARM64 قبل قبول Phase 13R. اختبار الانتقال إلى تطبيق آخر وإزالة KELIVO من Recents أثناء عملية حقيقية ما زال مطلوباً على هاتف Android. لا يدعي هذا التعديل استئناف stream حي بعد Force Stop أو قتل العملية أو إعادة تشغيل الجهاز.
