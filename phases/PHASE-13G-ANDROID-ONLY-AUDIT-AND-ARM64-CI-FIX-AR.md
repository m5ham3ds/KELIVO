# إصلاح فشل بناء KELIVO — Android-only Audit و ARM64

## نتيجة فحص GitHub Actions

- المستودع: `m5ham3ds/KELIVO`
- Commit: `a4140dbfbd4f9c833cd625a78f1700572ea77517`
- Workflow: `Android ARM64 Build & Comprehensive Report`
- الفشل وقع في الخطوة الرابعة: `Android-only source audit`.
- رسالة السجل: `grep: android/app/build.gradle.kts: No such file or directory`.
- النتيجة: لم يبدأ Flutter setup أو `flutter pub get` أو أي اختبار Phase 13E/13F/13G أو بناء APK.

## السبب الجذري

ملف `android/app/build.gradle.kts` غير موجود في شجرة الملفات التي استلمها GitHub Actions في الـ commit المذكور. الملف موجود في أرشيف PHASE13G الذي تمت مراجعته محلياً؛ لذلك توجد فجوة بين الأرشيف المحلي وما تم دفعه فعلياً إلى `main`. هذا ليس دليلاً على أن قيمة ABI داخل الملف كانت خاطئة؛ بل لم يكن الملف موجوداً في checkout حتى يقرأه فاحص ABI.

يجب دفع مجلد `android/` ومحتوياته المطلوبة إلى جذر المستودع، وليس وضع مجلد `KELIVO/` داخل مجلد آخر أو دفع ملفات `.github/` وحدها.

## التصحيحات

1. أضيف فحص صريح لوجود `android/app/build.gradle.kts` و`android/app/src/main/AndroidManifest.xml` قبل التحقق من ABI، كي تظهر رسالة واضحة إذا لم تصل ملفات Android إلى GitHub.
2. أضيف `defaultConfig.ndk.abiFilters += listOf("arm64-v8a")` لتقييد المكتبات الأصلية التي يضمّنها APK.
3. أبقي قيد CMake الحالي `externalNativeBuild.cmake.abiFilters` حتى لا تتغير معمارية مكتبات PRoot المبنية عبر CMake.
4. حدث فحص Android-only وفحص Release Hardening للتحقق من قيد ABI على مستوى التطبيق، ورفض أي ABI غير ARM64.
5. لم تتغير اختبارات 13A–13D، ولم تُضف أدوات أو اعتماديات جديدة.

## التحقق المحلي

- `bash .github/scripts/audit_android_only.sh`: نجح على شجرة المشروع المحلية بعد التعديل.
- Phase 13E CI self-test: نجح.
- Phase 13F CI self-test: نجح.
- Phase 13G static preflight وCI wiring: نجحا.
- Release hardening audit: نجح.

لم يتم تشغيل Flutter/Dart أو Gradle أو إنتاج APK في بيئة العمل الحالية؛ لذلك يحتاج commit المصحح إلى GitHub Actions لتأكيد الاختبارات والبناء الفعلي.

## قائمة التحقق قبل الدفع

من جذر المشروع، يجب أن تظهر الملفات التالية في GitHub بعد الدفع:

- `android/app/build.gradle.kts`
- `android/app/src/main/AndroidManifest.xml`
- `android/settings.gradle.kts`
- `android/gradle/wrapper/gradle-wrapper.properties`
- `.github/scripts/audit_android_only.sh`
- `.github/scripts/release_hardening_audit.sh`

في واجهة GitHub تأكد أن `android/` موجود على المستوى نفسه من `lib/` و`pubspec.yaml` و`.github/`. إذا لم يظهر هذا المجلد، فلا تشغّل البناء بعد؛ أصلح رفع ملفات المشروع أولاً.
