# KELIVO — تقرير تنفيذ PHASE13P.0

## End-to-End Skill Testing

### ملخص التنفيذ

تمت متابعة التطوير من مصدر `KELIVO-PHASE13O.0-SOURCE.zip` دون إعادة تنفيذ المراحل السابقة. أضيف مسار اختبار عام لدورة حياة مهارة محلية داخل Android، باستخدام مهارة اختبار مؤقتة تُنشأ أثناء الاختبار؛ ولا يعتمد الاختبار على المهارات الست المرفقة أو على أسماء منتجات/مهارات بعينها.

تغطي دورة الاختبار المضافة:

1. إنشاء أرشيف ZIP مؤقت يحتوي `SKILL.md` وسكريبت Bash.
2. استيراد الأرشيف فعلياً عبر `SkillsService.importFromFile` والتحقق من تقرير الاستيراد وملفات المهارة وبصمة المصدر ونقطة الدخول المكتشفة.
3. إنشاء Runtime Profile من نوع Extension مرتبط بمعرّف المهارة وفحص ظهور `bash` في مسار ذلك الـProfile. عند مشاركة أدوات النظام، يوضح الاختبار أن Bash قد يكون من Base PRoot لا من ملفات Profile المعزولة.
4. إنشاء مراجعة صلاحيات ومنحة تنفيذ لمرة واحدة وفق سياسة KELIVO.
5. تشغيل السكريبت عبر `SkillExecutor` بخطة تركيب وبصمة مصدر مثبتتين.
6. إنشاء `result.json` والتحقق من رمز الخروج ونوع المحتوى والحجم وبصمة SHA-256 الفعلية للملف.
7. فتح الملف عبر أداة Workspace `read_file` والتحقق من بيانات JSON الناتجة.
8. التأكد من تسجيل التنفيذ بحالة `succeeded`.
9. متابعة مهمة Android في الخلفية، والتحقق من بقاء Foreground Service أثناء المهمة ثم توقفها بعد إكمالها.
10. تنظيف Profile والمهارة المؤقتة وموارد الاختبار.

### ملفات المرحلة المضافة أو المعدلة

- `integration_test/workspace/skill_execution_e2e_test.dart` — اختبار Android المتكامل.
- `.github/scripts/preflight_phase13p_tests.sh` — فحص تغطية الاختبار وحدود الأمان وربط CI.
- `.github/scripts/test_phase13p_ci.sh` — اختبار ربط المرحلة بمسار CI.
- `.github/scripts/run_phase13p_tests.sh` — تشغيل اختبارات Flutter الوحدوية المركزة المتعلقة بالاستيراد والتنفيذ والملفات الشخصية والخلفية.
- `.github/scripts/run_phase13p_android_e2e.sh` — تشغيل تجربة E2E على جهاز Android موصول عبر ADB.
- `.github/workflows/android-build.yml` — خطوات PHASE13P، ومدخل يدوي اختياري لتشغيل Android Emulator.
- `.github/scripts/record_skipped_build_stages.sh` و`.github/scripts/generate_build_report.py` — تسجيل حالة اختبار E2E الاختياري في تقرير البناء.
- `phases/PHASE-13P-END-TO-END-SKILL-TESTING-AR.md` — وصف المرحلة وطريقة تشغيلها وحدودها.

### نتائج الفحوص التي نُفذت في بيئة التحرير

| الفحص | النتيجة |
|---|---|
| PHASE13L CI self-test | PASS |
| PHASE13M CI self-test | PASS |
| PHASE13N CI self-test | PASS |
| PHASE13O CI self-test | PASS |
| PHASE13P static preflight | PASS |
| PHASE13P CI wiring self-test | PASS |
| Bash syntax لجميع سكريبتات CI | PASS |
| تحليل YAML لسير عمل Android | PASS |
| تفرد معرّفات خطوات Workflow وترتيب PHASE13P | PASS |

**لم تُنفذ** اختبارات Flutter/Dart الفعلية أو `dart format` أو Robolectric أو بناء APK أو اختبار Android E2E في بيئة التحرير هذه؛ لأن Flutter وDart وGradle وADB غير متوفرة فيها. لذلك لا يمثل نجاح الفحوص الساكنة دليلاً على نجاح تشغيل المهارة على جهاز أو محاكي.

### تشغيل الاختبارات في GitHub Actions

تشغّل كل عملية CI عادية فحوص Phase13P البنيوية والاختبارات الوحدوية المركزة. أما تجربة Android الحقيقية فاختيارية حتى لا تنزّل RootFS إلى محاكي جديد في كل Push:

1. افتح GitHub Actions.
2. اختر سير العمل `Android ARM64 Build & Essential Arabic Checks`.
3. اختر `Run workflow`.
4. فعّل `run_android_skill_e2e`.
5. ابدأ التشغيل وافتح سجل خطوة `phase13p_android_e2e`.

الخطوة تعمل على Android Emulator x86_64 وتستخدم Debug plugin registrant مؤقتاً، ثم يعيد Workflow تجهيز Plugin Registrant حسب وضع APK المحدد قبل بناء APK النهائي.

### التشغيل على جهاز Android موصول

```bash
adb devices
bash .github/scripts/run_phase13p_android_e2e.sh
```

### حدود ما تثبته المرحلة

- انتقال التطبيق إلى `paused` يحاكي الذهاب إلى الخلفية مع استمرار العملية والخدمة؛ لا يحاكي Android Force Stop، لأن Force Stop ينهي العملية.
- ظهور الإشعار يتوقف على صلاحية الإشعارات وإعدادات Android؛ يسجل الاختبار حالة الإذن ولا يعتبر غيابه دليلاً على فشل تشغيل Foreground Service.
- PRoot ليس عزلاً على مستوى Kernel. تبقى حدود RootFS المشترك والشبكة كما وثقتها PHASE13N.
- الاختبار يستخدم سكريبت Bash بسيطاً ولا يثبت حزم نظام أو Python/Node أثناء التجربة.
- لا يثبت هذا الاختبار اكتمال مشغلات MCP أو HTTP/API أو CLI أو Workflows. تظل تلك الأنواع خاضعة لعقود الموائمات واختباراتها الخاصة.

### بوابة القبول

تعد ملفات PHASE13P وربطها بـCI جاهزة، لكن لا تُعلن المرحلة مكتملة تشغيلياً إلا بعد نجاح سجل `phase13p_android_e2e` فعلياً على محاكي أو جهاز Android. يجب الحفاظ على هذه الحالة كاختبار لم يُشغّل إلى أن تتوفر نتيجة حقيقية.
