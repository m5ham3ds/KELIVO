# حالة تنفيذ Environment Presets وMedia tools — 2026-11-23

## ما تم حفظه على main
- تقليص `EnvironmentDependency` إلى Presets العامة وMedia tools وBrowser Renderer؛ لم تعد أدوات media utilities مفاتيح enum مستقلة.
- إضافة صفحة Media tools مجمعة تعرض الأدوات الست وتفصل FFmpeg وFFprobe كأمرين مع حزمة نظام واحدة.
- إضافة مسار تثبيت مجمّع للوسائط في `EnvironmentDependencies`، مع استدعاء `dpkg --configure -a` قبل apt، وفحص أوامر FFmpeg وFFprobe وyt-dlp وMediaInfo وFFmpegthumbnailer وImageMagick بعد التثبيت.
- توصيل `PackageManagerEnvironmentTools.resolve` بمسار تنفيذ `package_manager` قبل طلب الموافقة النظامية، مع دعم أسماء ImageMagick البديلة.
- إضافة اختبارات وحدة لمحلّل أسماء أدوات الوسائط واختبار تثبيت مجمّع.

## نقاط لم تعتبر مكتملة
- لم يُنفذ تثبيت فردي لكل أداة من صفحة Media tools؛ الصفحة توفر إجراء تثبيت جماعي موحداً، ولم يُربط كل صف بزر تثبيت فردي.
- لم تُنقل عملية APT إلى Android Foreground Service. `EnvironmentDependencies._run` ما زال يعتمد على `WorkspaceRuntime.run`، وخدمة الخلفية الأصلية الحالية مهيأة لمهام التوليد/المهام المجدولة، ولا تحمل نوعاً مستقلاً لتثبيت الحزم أو سجل استعادة دائم له. لا يُدّعى ضمان الاستمرار بعد مغادرة العملية أو Force Stop.
- إضافة إذن الإشعارات إلى Home تضيف شرحاً قبل الطلب وتخزن قرار عرض الشرح، لكنها لا تكفي وحدها لإشعارات تقدم APT؛ كما يلزم التحقق من سلوك الرفض الدائم واختبار دورة الحياة.
- لم تُثبت نتيجة نجاح CI النهائي لهذه المجموعة في وقت إعداد التقرير؛ تشغيل Android ARM64 Build رقم 112 كان قيد التنفيذ أثناء الفحص.

## تعليمات الاستكمال
1. لا تُنشئ فرعاً آخر. تابع على `main` وفق `GIT-BRANCHING-POLICY-AR.md`.
2. افحص التغييرات المسجلة وCI #112، وعالج أي فشل قبل مواصلة التحرير.
3. أضف اختبارات UI لصفحة Media tools والـconfirmation والـstatus لكل أمر، وصحح أي lint/analyzer/test regressions.
4. نفّذ نوع BackgroundTask واضحاً مثل `environment_install` عبر خدمة Android foreground الحالية، مع فصل completion notification عن إشعارات المحادثة، snapshot persisted progress، cancellation يوقف العملية وأطفالها، ومنع إعادة الاستئناف بعد Force Stop/موت العملية. يجب اختبار task removal مقابل force stop.
5. اربط مثبت Environment مع coordinator/native service دون جعل عملية apt تعمل في Flutter Future عادي أو WorkManager.
6. اختبر permission rationale عند أول Home فعلي على Android 13+، واحترام الرفض/عدم التكرار، ثم تحقق من CI وAPK.
7. لا تعلن المرحلة مكتملة أو جاهزة للنشر حتى تكون اختبارات Dart وAndroid وCI ناجحة ومخرجات APK/التحقق موثقة.
