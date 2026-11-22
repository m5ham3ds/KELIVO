# تحليل وإصلاح فشل CI #76 — Maven Central HTTP 429

**المستودع:** `m5ham3ds/KELIVO`  
**الفرع:** `main`  
**Commit المتأثر:** `f68e792b771822b31522705720a2ecc82c2d5606`  
**Workflow:** [CI #76](https://github.com/m5ham3ds/KELIVO/actions/runs/45040545406)  
**تاريخ المراجعة:** 22 نوفمبر 2026

## النتيجة

فشل التشغيل في بوابة `:app:testDebugUnitTest`، ولذلك تم تخطي Android Emulator وRelease APK ورفع الـAPK. لا يوجد APK صادر عن CI #76 attempt 2.

## التشخيص حسب المحاولة

### المحاولة الأولى

- نجح التدقيق وFlutter/dependency/local package stages.
- ظهر فشل في `AndroidSelectionMenuTest` و`HighRefreshRateControllerTest`.
- المكدس انتهى عند `MavenArtifactFetcher.java:129` مع `IOException` أثناء جلب Robolectric runtime artifact.
- لم يسجل هذا كفشل assertion في منطق التطبيق.

### المحاولة الثانية

- نجحت خطوات Android-only audit وFlutter setup/dependency resolution وLinux native dependencies وArabic localization وFlutter Analyze واختبارات 13Q.1 واختبارات الحزم المحلية.
- فشل Gradle أثناء حل `debugUnitTestRuntimeClasspath`:
  ```
  Could not download nativeruntime-dist-compat-1.0.18.jar
  https://repo.maven.apache.org/maven2/org/robolectric/nativeruntime-dist-compat/1.0.18/...
  Received status code 429: Too Many Requests
  ```
- لم يبدأ تنفيذ اختبارات Android/JVM نفسها في هذه المحاولة؛ كان الفشل أثناء تنزيل dependency.
- تم تخطي Android Emulator وRelease build وAPK upload.

## السبب الجذري

رفض Maven Central طلب تنزيل artifact كبير من مجموعة Robolectric بسبب rate limiting (HTTP 429). يتوافق ذلك مع إرشادات Sonatype لتجنب طلبات التنزيل المتكررة للملفات التشغيلية الكبيرة، ومع استخدام مرآة Maven Central المستضافة على Google Cloud Storage.

## الإصلاح المطبق

في `android/build.gradle.kts` أضيف مستودع:

`https://maven-central.storage-download.googleapis.com/maven2/`

قبل Maven Central، مع قيد محتوى ضيق:

`includeGroup("org.robolectric")`

وبذلك:
- تُحل ملفات مجموعة Robolectric من مرآة Google أولًا.
- تبقى `google()` و`mavenCentral()` متاحتين لبقية الاعتماديات.
- لا يتغير إصدار Robolectric ولا تُعطل أي اختبارات.
- لا تُخفى أخطاء الاختبارات الحقيقية، ولا يجري تخطي بوابة Android.

## بوابة التحقق

لا يعتبر الإصلاح مقبولًا حتى يثبت CI التالي:
1. حل `debugUnitTestRuntimeClasspath` دون HTTP 429.
2. اجتياز كامل مجموعة Android JVM/Robolectric (لا مجرد بدء الخطوة).
3. نجاح Phase 13P Emulator E2E.
4. نجاح Android ARM64 Release ومرحلة packaging والتحقق من ABI ورفع APK.
5. ظهور Artifact APK حقيقي في التشغيل.

**الحالة بعد التعديل:** الإصلاح committed إلى `main`، ونتيجته في CI التالي هي الدليل المطلوب. Phase 13Q.1 تبقى منفذة؛ لم يبدأ 13Q.2 أثناء وجود بوابة بناء غير ناجحة.

## مراجع تقنية

- Sonatype — [429 operational and runtime artifacts](https://central.sonatype.org/faq/429-operational-dependencies/)
- Google Cloud — [Hosted Maven Central mirror](https://docs.cloud.google.com/docs/buildpacks/java)
- Android/Robolectric upstream — توثيق استخدام Google mirror لتجنب 429 للملفات الكبيرة من Robolectric.
