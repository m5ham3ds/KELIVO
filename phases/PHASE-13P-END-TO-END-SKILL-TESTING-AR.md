# PHASE13P — End-to-End Skill Testing

## الهدف

إثبات دورة تشغيل مهارة عامة داخل KELIVO على Android من البداية إلى النهاية، دون ربط المحرك بأسماء المهارات الست المرفقة أو بنوع واحد من السكريبتات.

## دورة الاختبار

1. إنشاء ZIP اختباري صغير يحتوي `SKILL.md` وسكريبت Bash مستقل.
2. استيراد ZIP عبر `SkillsService.importFromFile` والتحقق من تقرير الاستيراد وملف Capability Descriptor ونقطة الدخول المعلنة.
3. إنشاء Runtime Profile من نوع Extension مملوك لمعرّف المهارة المستوردة.
4. فحص أمر `bash` بواسطة `inspectSkillProfileCommands` والتحقق من أنه ظاهر في PATH الخاص بالـProfile. الفحص لا يثبت عزل أداة Bash عن RootFS الأساسي عندما تكون أدوات النظام المشتركة مفعّلة.
5. إنشاء مراجعة الصلاحيات ومنحة موافقة لمرة واحدة بواسطة سياسة KELIVO.
6. تشغيل السكريبت عبر `SkillExecutor` فقط، مع تثبيت Source Digest وخطة تركيب المهارة وعقد الناتج.
7. إنشاء `result.json` داخل مجلد مخرجات التشغيل، والتحقق من نوع الملف وحجمه وSHA-256 الفعلي للبايتات على الجهاز.
8. فتح الملف من خلال أداة Workspace `read_file`، ثم التحقق من محتوى JSON الذي أنتجته المهارة.
9. التحقق من سجل التنفيذ بأن الحالة `succeeded`.
10. تشغيل مهمة خلفية عبر `MobileBackgroundCoordinator`، والتحقق من حالة Foreground Service أثناء تنفيذ المهارة، ثم التأكد من توقف الخدمة بعد إغلاق المهمة.
11. استعادة حالة واجهة التطبيق وتنظيف المهارة والـRuntime Profile وقاعدة بيانات الاختبار.

## حدود الاختبار

- الاختبار مخصص لـAndroid لأن تشغيل المهارات المحلية يتطلب Android PRoot. على المنصات الأخرى يتم تخطيه صراحةً.
- عند غياب RootFS المثبت، يحاول الاختبار تثبيت بيئة PRoot بواسطة `EnvironmentInstaller`. لذلك يحتاج الجهاز إلى اتصال إنترنت ومساحة تخزين حرة كافية، وقد يستغرق تثبيت الصورة وقتاً.
- انتقال التطبيق إلى `paused` يحاكي مغادرة الواجهة إلى الخلفية مع بقاء العملية والخدمة. الاختبار لا ينفذ Force Stop؛ لأن Android ينهي العملية عند Force Stop، وهذا سلوك مختلف عن الانتقال العادي للخلفية.
- وجود صلاحية الإشعارات يختلف بحسب الجهاز وإعدادات المستخدم. فحص استمرار Foreground Service إلزامي، لكن اختبار ظهور إشعار للمستخدم لا يفشل عند رفض إذن الإشعارات؛ تسجل نتيجة الإذن في سجل الاختبار. اختبارات Android الأصلية السابقة تتحقق من منطق الخدمة والإشعارات.
- لا يُثبت الاختبار أن PRoot عزل Kernel؛ يبقى RootFS مشتركاً وقابلاً للكتابة والاتصال الخارجي غير مقيّد بالكامل كما هو موثق في PHASE13N.
- سكريبت الاختبار لا يثبت حزم نظام أو Python/Node من الإنترنت. هو يختبر اعتماداً أساسياً لا يحتاج تثبيتاً إضافياً (`bash`, `cat`, `sleep`) كي تبقى النتيجة حتمية وقابلة للتكرار. تختبر اختبارات Dependency Resolver وPackage Manager إدارة الاعتماديات على نحو منفصل.
- الاختبار لا يثبت بعد تشغيل MCP أو HTTP/API أو Standalone CLI أو Workflow adapters؛ اكتشاف هذه الأنواع لا يعني اكتمال مشغلاتها.

## التشغيل على Android فعلي

بعد توصيل جهاز Android وتفعيل USB debugging وقبول تفويض ADB:

```bash
adb devices
bash .github/scripts/run_phase13p_android_e2e.sh
```

أو تشغيل الاختبار مباشرةً بعد تحضير Android Debug plugin registrant:

```bash
flutter build apk --debug --config-only
flutter test --no-pub -d <ANDROID_DEVICE_ID> \
  integration_test/workspace/skill_execution_e2e_test.dart \
  --reporter expanded
```

## تشغيله من GitHub Actions

أضيف إلى `workflow_dispatch` خيار اختياري باسم `run_android_skill_e2e`.

- يظل الخيار الافتراضي `false` حتى لا يفرض تنزيل RootFS وتشغيل محاكي Android على كل Push أو Pull Request.
- لتشغيله يدوياً، افتح GitHub Actions، اختر سير عمل Android ARM64، ثم اختر `Run workflow` واجعل `run_android_skill_e2e` مفعّلاً.
- يعمل الاختبار على Android Emulator x86_64 ويستخدم مسار التحضير Debug. بعد انتهاء الاختبار يعيد الـWorkflow إعداد Plugin Registrant وفق وضع APK المختار قبل البناء النهائي.
- نتيجة `phase13p_android_e2e` المنفصلة هي الدليل المطلوب لإثبات نجاح دورة Android. نجاح اختبارات Flutter الوحدوية أو فحوص CI البنيوية وحدها لا يثبت نجاح E2E.

## بوابة القبول

لا تُعلن PHASE13P مكتملة تشغيلّياً إلا بعد ظهور نتيجة نجاح فعلية لخطوة `phase13p_android_e2e` على محاكي أو جهاز Android. تجهيز الاختبار وربطه بـCI لا يعني أن الاختبار شُغّل بالفعل.
