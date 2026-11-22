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


---

## نتيجة CI #77 — فشل runtime fetch بعد نجاح Gradle dependency resolution

**التشغيل:** [CI #77](https://github.com/m5ham3ds/KELIVO/actions/runs/45068500503)  
**Commit:** `526a38435470ee825053669db84e220e2d23aa3a`  
**النتيجة:** فشل في بوابة Android JVM/Robolectric؛ لم ينتج APK.

### ما أثبته السجل

- نجحت خطوات Android-only audit وFlutter Analyze وPhase 13Q.1 والحزم المحلية وإعداد Java/Gradle/NDK/CMake.
- وصل Gradle إلى تنفيذ `:app:testDebugUnitTest` واكتمل 136 اختباراً، وفشلت 9 اختبارات في تهيئة Robolectric.
- جميع الحالات التسع انتهت إلى `MavenArtifactFetcher.java:129` ثم `ExecutionException` و`IOException`.
- لم يثبت ملخص #77 أن الاستجابة كانت HTTP 429 تحديداً؛ 429 مؤكد في محاولة CI #76 الثانية عند Gradle dependency resolution فقط.
- لم تبدأ Phase 13P أو مرحلة Release ARM64 لأن بوابة JVM فشلت. لا يوجد APK #77.

### السبب الجذري

هناك مساران منفصلان لتنزيل ملفات Robolectric:

1. Gradle repository declarations تحل مكتبات `org.robolectric` (مثل `robolectric-4.16.1` و`nativeruntime-dist-compat`).
2. Robolectric `MavenArtifactFetcher` يجلب Android SDK runtime jars أثناء تنفيذ الاختبارات. هذا المسار لا يقرأ مستودعات Gradle؛ ويستخدم افتراضياً `https://repo1.maven.org/maven2`.

إضافة مرآة Google إلى `allprojects.repositories` أصلحت المسار الأول فقط، ولم تضبط المسار الثاني. وهذا يفسر استمرار `IOException` في جميع اختبارات Robolectric رغم نجاح Gradle dependency resolution.

### الإصلاح الحالي المطبق في المصدر

في `android/app/build.gradle.kts`:
- ضبط `robolectric.dependency.repo.url` على مرآة Google Hosted Maven Central.
- ضبط `robolectric.dependency.repo.id` بمعرّف متوافق مع عنوان المرآة.
- تمرير الخاصيتين عبر `testOptions.unitTests.all` إلى كل Android unit-test JVM.
- السماح بالتخصيص عبر Gradle properties `robolectricDependencyRepoUrl/Id` أو Environment Variables `ROBOLECTRIC_DEPENDENCY_REPO_URL/ID`.
- طباعة عنوان ومستودع التنزيل الفعليين في سجل Gradle؛ حتى يمكن التحقق من أن Robolectric لا يعود بصمت إلى `repo1.maven.org`.

هذا إصلاح مصدر تم إعداده، وليس نتيجة اختبار ناجحة بعد. يبقى القبول مشروطاً بـ:
1. ظهور مرآة Google الفعلية في log خلال خطوة Android tests.
2. اكتمال جميع Android JVM/Robolectric tests دون `MavenArtifactFetcher` IOException.
3. نجاح Phase 13P emulator E2E.
4. نجاح بناء ARM64 Release والتحقق من ABI ورفع APK فعلي.

### مرجع الإعداد

Robolectric يعرّف `robolectric.dependency.repo.url` و`robolectric.dependency.repo.id` كخصائص نظام منفصلة، ويشرح ضبطهما من `android.testOptions.unitTests.all`: https://robolectric.org/configuring/ .


---

## القبول النهائي للإصلاح — CI #78 (23 نوفمبر 2026)

**التشغيل:** [CI #78](https://github.com/m5ham3ds/KELIVO/actions/runs/45080129832)  
**Commit:** `64e51a52958b58f3d0ba83099bcc90fb4384855d`  
**النتيجة:** Success؛ APK ARM64 Release مرفوع.

سجل Android job أكد قبل تشغيل الاختبارات:

```
Robolectric runtime dependency repository: GoogleHostedMavenCentralMirror (https://maven-central.storage-download.googleapis.com/maven2/)
> Task :app:testDebugUnitTest
BUILD SUCCESSFUL in 3m 34s
```

كما نجحت Phase 13P Android Emulator E2E، وبناء Release، وفحص checksum ورفع APK. لذلك **يُقبل إصلاح مرآة Robolectric** بناءً على تشغيل فعلي، وليس بمجرد وجود إعداد في Gradle. لم يظهر في سجل #78 تكرار لخطأ `MavenArtifactFetcher` أو HTTP 429.

APK الناتج: 41,825,267 bytes، ARM64 فقط (18 native libraries)، SHA-256: `136bdfbdb97a64e92cabdf50c7d94e370d255305dd67412a173338bbf26288f0`.

يظل سجل CI #76/#77 التاريخي محفوظاً كما هو، ولا يلغي قبول #78 أن #76/#77 كانا فاشلين. لا توجد حاجة لإعادة تشغيلهما.
