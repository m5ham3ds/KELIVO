# PHASE 6 — Runtime Profiles & Execution Isolation

## الهدف

توفير بيئات Python وNode مستقلة منطقياً لكل مشروع أو Skill، وربطها بأوامر المحادثة ومدير الحزم، مع عزل ملفات TMP ومخرجات كل تشغيل، وتسجيل حالات العمليات واستعادتها تشغيلياً بعد انقطاع التطبيق.

## النطاق المنفذ في هذه الدفعة

1. **RuntimeProfile model**
   - نطاقات `project` و`extension` و`task` في النموذج.
   - حالات provisioning/ready/failed/disabled.
   - تخزين ملفات التعريف وسجل العمليات داخل `ExtensionEntityStore` من دون إضافة جداول أو migrations جديدة.
   - إعداد `defaultRuntimeProfileId` محفوظ على Workspace.

2. **بيئات Python وNode**
   - إنشاء Python `venv` داخل جذر ملف التعريف.
   - إنشاء جذر Node محلي مستقل لكل ملف تعريف، واستخدامه كـ package prefix.
   - مسارات مختلفة لكل ملف تعريف حتى داخل مساحة العمل نفسها.
   - يمكن لمشروع استخدام Python وNode معاً، ويمكن تحديد ملف تعريف صريح لتشغيل محدد.
   - يظل مفسر Python/Node الأساسي من PRoot مشتركاً؛ لا يوجد في هذه الدفعة مدير لإصدارات interpreters متعددة.

3. **PATH وEnvironment Variables**
   - ترتيب PATH يقدّم مجلدات venv وNode المحلية.
   - `shareBaseTools` يضيف مجلدات الأدوات الإدارية/المحلية إلى PATH؛ وتظل `/usr/bin` و`/bin` متاحة كحد أدنى للأدوات الضرورية.
   - رفض أسماء البيئة المحجوزة، ومفاتيح الأسرار، والقيم متعددة الأسطر أو NUL.
   - تمرير متغيرات التشغيل الداخلية مثل `VIRTUAL_ENV` و`NODE_PATH` و`TMPDIR` و`KELIVO_TASK_OUTPUT_DIR` من الخدمة، وليس من مدخل المستخدم.

4. **عزل كل تشغيل**
   - `TMPDIR` خاص بكل run ويُحذف بعد انتهاء الأمر.
   - `KELIVO_TASK_OUTPUT_DIR` خاص بكل run ويبقى بعد انتهائه لحفظ المخرجات.
   - يبلّغ shell tool بمساري TMP والمخرجات في نتيجة الأداة.
   - عند اكتشاف سجل تشغيل قديم بحالة running من جلسة تطبيق سابقة، يُعلّم `interrupted` مع `resumeHint`، وتُحذف محاولةً مجلدات TMP الخاصة بتلك التشغيلات مع الإبقاء على المخرجات الدائمة.

5. **العمليات والقيود**
   - حفظ سجل التشغيل والملف التعريفي ومعرّف جلسة التطبيق.
   - مشاركة عداد التزامن بين نسخ `RuntimeProfileService` في عملية Dart نفسها.
   - دعم الإلغاء عن طريق `WorkspaceRuntime.cancel`، وتسجيل الحالات: succeeded/failed/cancelled/timedOut/interrupted.
   - حد وقت فعلي عبر `CommandRequest.timeout`.
   - حدود `ulimit` best-effort لعدد العمليات والذاكرة الافتراضية وحجم الملف.
   - فحص حجم TMP بعد انتهاء الأمر ثم إرجاع `resource_limit_exceeded=temporary_storage` إذا تجاوز الحد.

6. **تكامل المحادثة ومدير الحزم**
   - أداة `runtime_profile` لإنشاء/عرض/فحص/تعيين/مسح الافتراضي/إزالة الملفات التعريفية، ومراجعة العمليات وإلغائها.
   - التغييرات التي تنشئ أو تزيل أو تغير الافتراضي أو تلغي عملية تتطلب موافقة المستخدم.
   - أمر `shell` يستخدم الملف الافتراضي للمشروع أو `runtime_profile_id` صريحاً.
   - عمليات Python/Node بنطاق المشروع في `package_manager` ترث الملف الافتراضي تلقائياً إذا لم يحدد المستخدم `profile_id`.
   - تبقى apt/apk على نطاق PRoot المشترك؛ لا تُحوّل إلى ملف Python/Node.
   - ملفات تعريف Skills تتطلب Android PRoot وتتحقق الخدمة من أن Skill المالك مثبتة. لا يعني ذلك أن Skill execution runner أصبح موجوداً.

## الملفات الرئيسية

- `lib/core/services/runtime_profiles/runtime_profile_models.dart`
- `lib/core/services/runtime_profiles/runtime_profile_service.dart`
- `lib/core/services/runtime_profiles/runtime_profile_tools.dart`
- `lib/core/models/workspace.dart`
- `lib/core/services/workspace/workspace_tools_service.dart`
- `lib/core/services/packages/package_manager_service.dart`
- `lib/features/home/services/tool_handler_service.dart`
- اختبارات `test/core/services/runtime_profiles/` واختبارات Workspace/Package Manager/Tool Catalog ذات الصلة.

## حدود معروفة لا تُخفى

هذه **عزلة منطقية لإدارة التبعيات والمسارات** وليست sandbox أمنياً مستقلاً:

- ملفات تعريف المشاريع تشارك نظام PRoot الأساسي ومكتبات النظام؛ apt/apk تعدّل البيئة المشتركة.
- `ulimit -u`, `ulimit -v`, و`ulimit -f` best-effort وتعتمد على shell/runtime؛ قد يتجاهلها PRoot أو بيئة Android. حد الذاكرة هو للذاكرة الافتراضية وليس ضماناً لحد RAM الفعلي.
- حجم TMP يُفحص بعد انتهاء الأمر وليس quota لحظياً أثناء التنفيذ. حدود التخزين لا تمنع كل كتابة خارج TMP.
- المخرجات تبقى داخل `outputs/<runId>` ولا يوجد Artifact Manager عام أو cleanup policy تلقائي لها في هذه المرحلة.
- إعادة تشغيل التطبيق لا تستطيع إحياء PID الأصلي. تحفظ الخدمة الحالة كـ interrupted، تنظف TMP المتروك حيث أمكن، وتوفر تلميح استئناف؛ ولا تدّعي استئنافاً تلقائياً.
- إدارة Runtime Profiles في هذه الدفعة مرتبطة بأوامر shell أحادية التشغيل. جلسات PTY/Terminal التفاعلية ليست مرتبطة بملف تعريف بعد.
- نطاق task موجود في النموذج ومسارات التخزين، لكن إنشاء/إدارة task profiles ليس مكشوفاً في أداة المحادثة بعد.
- ملفات تعريف extension قابلة للإدارة واستخدامها كهدف لمكتبات Python/Node، لكن مشغّل تنفيذ Skills الفعلي لم يُنجز بعد؛ فجوة Phase 4 لا تزال مستقلة.
- لا يوجد اتصال Runtime خارجي في هذه الدفعة؛ يظهر `runtime_engine` الحالي (مثل proot) ولا يوجد remote executor adapter.
- اختيار إصدارات متعددة من Python أو Node لم يُنفّذ؛ البيئات تعزل packages وتستخدم interpreters الموجودة في PRoot.

## الاختبارات وCI

تم إعداد manifest Android مركّز من 26 ملف اختبار، إضافة إلى أربعة اختبارات UI مسماة من ملف محادثة Android. يحلل CI كود `lib` الإنتاجي وهذه الملفات المحددة فقط، ثم يبني APK Release لـ Android ARM64. لا يشغل اختبارات iOS أو macOS أو Windows أو Linux أو Web أو sweep المستودع الكامل.

التحقق الساكن المحلي شمل YAML وShell وAndroid-only audit وسلامة الأرشيف. لم يتوفر Dart/Flutter SDK في بيئة إعداد الحزمة، لذلك لم يتم تنفيذ Dart Analyze أو Flutter Tests أو APK build محلياً.

## معايير القبول

- [x] إنشاء وحفظ Runtime Profiles للمشروع وSkill.
- [x] بيئات Python/Node ومسارات حزم مستقلة لكل ملف تعريف.
- [x] PATH وEnvironment Variables مقيدة ومدارة من الخدمة.
- [x] TMP ومخرجات منفصلة لكل تشغيل.
- [x] سجل دائم للعملية وحالة interrupted وتلميح استئناف بعد إعادة تشغيل التطبيق.
- [x] timeout/cancel/concurrency وحدود موارد best-effort موثقة.
- [x] دمج المشروع الافتراضي مع shell وPackage Manager.
- [ ] نجاح Dart Analyze و26 ملف اختبار و4 UI regressions في GitHub Actions.
- [ ] نجاح Android ARM64 Release ورفع APK من GitHub Actions.
- [ ] اختبار قبول فعلي على الهاتف يثبت مشروعين بمتطلبات Python/Node متعارضة دون تداخل.
- [ ] إغلاق فجوات PTY وtask profiles وremote runtime وruntime version selection، أو ترحيلها رسمياً إلى مراحل لاحقة مع اعتماد المستخدم.

**الحالة:** تغييرات المصدر جاهزة للمراجعة؛ القبول الرسمي ينتظر GitHub Actions واختبار الهاتف. Phase 6 نشطة بناءً على توجيه المستخدم، ولا تعني حالة المصدر الجاهز أن المرحلة مقبولة نهائياً.
