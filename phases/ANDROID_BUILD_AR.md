# دليل بناء Kelivo لنظام Android

المستودع يستهدف Android حاليًا؛ APK الإنتاج arm64-v8a فقط.

## أحداث التشغيل
- push إلى main.
- فتح Pull Request أو تحديثه.
- تشغيل يدوي مع اختيار release أو debug وإمكانية طلب اختبارات Skill E2E.

## تسلسل CI الفعلي
1. Checkout وتهيئة التقرير.
2. Android-only وRelease hardening audit، بما فيها فحص ABI داخل APK النهائي.
3. Flutter 3.47.6 وحل dependencies وإعداد GTK/GLib على Linux runner.
4. Arabic ARB key/placeholder parity ثم flutter gen-l10n.
5. Flutter Analyze على lib وtest وintegration_test.
6. اختبارات Flutter المركزة لدورة Environment install lifecycle (Image وPresets وMedia tools وحالة الإشعار) التي أضيفت في Phase 13R.
7. اختبارات Phase 13Q للقراءة فقط لإعداد MCP المعلن من Skill، دون تشغيل الخادم.
8. اختبارات الحزم المحلية: mcp_client وdownsize وflutter_math_fork وmarkstream وterminal_view.
9. Java 21 وGradle 8.14؛ توجيه Kotlin plugin marker عبر `pluginManagement.resolutionStrategy.eachPlugin/useModule` مباشرة إلى `org.jetbrains.kotlin:kotlin-gradle-plugin`، مع Google Maven ومرآة Maven Central؛ لا Plugin Portal fallback لمعرّف Kotlin.
10. NDK 28.2.13676358 وCMake 3.22.1.
11. Android JVM/Robolectric عبر :app:testDebugUnitTest.
12. أربعة Android emulator integration tests على main، ومنها skill_execution_e2e_test.dart.
13. إعداد plugin registrant لوضع البناء وتعطيل ABI التجريبي.
14. بناء ARM64 APK والتحقق من ZIP وحساب SHA-256 ورفع artifact.

## ما لا يشغله workflow
- لا يشغّل كامل Flutter root unit/widget test suite.
- لا يشغّل الاختبارات المركزة التاريخية للمراحل 13E–13O.
- التحليل الثابت لا يعادل تنفيذ الاختبارات.
- Phase 13P emulator E2E لا يثبت اختبارات Force Stop على هاتف المستخدم أو عزل PRoot على مستوى Kernel.

## معالجة Maven Central HTTP 429

يوجد مساران يجب ضبطهما معاً:

1. في `android/build.gradle.kts`، مرآة Google Hosted Maven Central قبل Maven Central، ومقيدة بمجموعة `org.robolectric` لحل مكتبات Gradle فقط.
2. في `android/app/build.gradle.kts`، تمرير `robolectric.dependency.repo.url` و`robolectric.dependency.repo.id` إلى كل JVM لاختبارات Android عبر `testOptions.unitTests.all`. هاتان الخاصيتان تخصان `MavenArtifactFetcher` الذي يجلب Android runtime jars وقت تنفيذ الاختبارات، ولا تُستمدان من قائمة مستودعات Gradle.

القيمة الافتراضية للمسارين هي `https://maven-central.storage-download.googleapis.com/maven2/`، ويمكن override لمسار runtime عبر `-ProbolectricDependencyRepoUrl=...` و`-ProbolectricDependencyRepoId=...` أو Environment Variables `ROBOLECTRIC_DEPENDENCY_REPO_URL/ID`.

CI #77 أثبت أن إضافة Gradle mirror وحدها لم تكن كافية: نجح حل Gradle dependencies، لكن 9 اختبارات فشلت عند `MavenArtifactFetcher.java:129` مع `IOException`. لا يسجل هذا التقرير HTTP 429 لـ#77 لأن السجل لم يحدد رمز الاستجابة. أما CI #78 فقد طبع عنوان مرآة Google الفعلي في سجل Gradle، ثم اجتازت `:app:testDebugUnitTest` بنجاح. اجتازت Phase 13P E2E وبناء ARM64 ورفع Artifact أيضاً؛ لذلك يُقبل الإصلاح.

## إصدارات الأدوات
Flutter 3.47.6 · Java 21 · Gradle 8.14 · NDK 28.2.13676358 · CMake 3.22.1 · production ABI arm64-v8a.

إذا غاب android/key.properties يستخدم Release مفتاح Debug الافتراضي؛ هذا APK للاختبار وليس مفتاح نشر Google Play.

CI #72 (22 November 2026) نجح: https://github.com/m5ham3ds/KELIVO/actions/runs/44969006889  
APK 41,825,267 bytes · 18 .so ضمن arm64-v8a فقط · SHA-256 a6271844472413909fa927b5220601dc2825b86e1b01386ef3bc2cce6a56a3a3.


## أحدث تحقق — CI #187

- التشغيل: https://github.com/m5ham3ds/KELIVO/actions/runs/45730072596
- commit: `cfd749429083b42b9228f594ed9992c5fd68507a`؛ مطابق لرأس `main`.
- جميع وظائف CI: build job 40/40 وreport job 9/9، بلا إخفاقات.
- Android JVM/Robolectric: نجاح؛ `BUILD SUCCESSFUL in 4m 40s`.
- Phase 13P Android Emulator E2E: نجاح.
- Android ARM64 Release وABI verification وArtifact upload: نجاح.
- APK: `Kelivo-Android-arm64-v8a-1.3.4+84-release.apk`، 41,900,015 bytes، `arm64-v8a` فقط.
- SHA-256: `cc6c39f8022e193a6fdf893d3d401bcc96f181293c8e9cd4e7fe96ea6710a2be`.
- APK artifact: `15077442763`.
- Build report artifact: `15076853823`؛ Raw report input: `15077413003`.

**إغلاق مشكلة Kotlin Plugin HTTP 429:** فشل #186 قبل تشغيل Robolectric بسبب تنزيل Kotlin Gradle plugin dependencies من Maven Central بعد تحويل Plugin Portal لطلبات إلى `repo.maven.apache.org` وإرجاع 429. أزال commit `cfd74942` الاعتماد على Plugin Portal لمعرّف `org.jetbrains.kotlin` وربط plugin marker مباشرة بوحدة `org.jetbrains.kotlin:kotlin-gradle-plugin` عبر `resolutionStrategy.eachPlugin/useModule`، مع mirror قبل Maven Central. اجتازت خطوة تحقق الإعداد ثم Gradle/Robolectric في #187 نجاحاً فعلياً؛ `BUILD SUCCESSFUL in 4m 40s`.

**نطاق الاختبارات:** #187 لم يشغل كامل Flutter root unit/widget suite ولا اختبارات Phase 13E–13O. كما أن نجاح Release لا يعني توقيع متجر؛ عند غياب `android/key.properties` يستخدم Debug key. سجل التقرير 117 warning/deprecation matches دون أن تفشل بوابة.



## تحقق البناء النهائي — CI #78

- التشغيل: https://github.com/m5ham3ds/KELIVO/actions/runs/45080129832
- commit: `64e51a52958b58f3d0ba83099bcc90fb4384855d`
- Android JVM/Robolectric: نجاح. سجل التنفيذ أظهر مرآة Google Hosted Maven Central ثم `BUILD SUCCESSFUL in 3m 34s`.
- Phase 13P Emulator E2E: نجاح.
- Android ARM64 Release + checksum + artifact upload: نجاح.
- APK: `Kelivo-Android-arm64-v8a-1.3.4+84-release.apk`، 41,825,267 bytes.
- ABI: `arm64-v8a` فقط، 18 native libraries ولا توجد ABI أخرى.
- SHA-256: `136bdfbdb97a64e92cabdf50c7d94e370d255305dd67412a173338bbf26288f0`.
- Artifact ID: `14777311841`.

نجاح #78 يثبت إصلاح Robolectric runtime repository، لكنه لا يعني أن workflow شغّل كامل Flutter root test suite أو مجموعات الاختبارات التاريخية 13E–13O.


## آخر بناء كامل ناجح قبل إصلاح Phase 13R — CI #120

- التشغيل: https://github.com/m5ham3ds/KELIVO/actions/runs/45217166038
- commit: 85e4653674916ecc65e3d30daa417e29547245a6
- Flutter Analyze: نجاح دون أخطاء أو تحذيرات analyzer.
- Android JVM/Robolectric: نجاح؛ BUILD SUCCESSFUL in 5m 16s.
- Phase 13P Android Emulator E2E: نجاح.
- Android ARM64 Release: نجاح، APK bytes 41,842,583.
- SHA-256: 5791a197b30bb3a160c41739a788a1c1b5053ca77599a9ba007de84acd632654.
- Artifact ID: 14840756161.

CI #120 لا يحتوي بعد على Regression tests التي أضيفت في Phase 13R. كما أن workflow لا يشغّل كامل Flutter root unit/widget suite أو مجموعات 13E–13O التاريخية.


## أحدث تحقق شامل — CI #204 (27 نوفمبر 2026)

- التشغيل: https://github.com/m5ham3ds/KELIVO/actions/runs/45899864988
- commit: `e1e543d77f38c6de15ad16aea972afa6bd06e8aa`؛ مطابق لرأس `main`.
- Flutter Analyze وEnvironment lifecycle وPhase 14A و14B وGemini/OAuth و14C.4 وPhase 13Q/14D STDIO وlocal packages: نجاح.
- Phase 14D real STDIO: 48 اختباراً ناجحاً.
- Android JVM/Robolectric: `BUILD SUCCESSFUL in 5m 29s`.
- Phase 13P Android Emulator: جميع الاختبارات الأربعة نجحت.
- Android ARM64 Release build وفحص ABI الفعلي وSHA-256 ورفع Artifact: نجاح.
- APK: `Kelivo-Android-arm64-v8a-1.3.4+84-release.apk`، 41,930,839 bytes.
- ABI: `arm64-v8a` فقط.
- SHA-256: `4f38e0c520386f43427eee822811dd02c42393de4f4037a7ae32a6bc995ae8dd`.
- APK artifact: `15156492027`.
- Build report artifact: `15155673161`.
- Raw diagnostics artifact: `15156601647`.

**حدود:** لا يشغّل workflow كامل Flutter root unit/widget test suite أو جميع مجموعات Phase 13E–13O التاريخية. Android Emulator لا يثبت Force Stop على هاتف المستخدم ولا عزل PRoot على مستوى kernel. غياب `android/key.properties` يعني استخدام debug key في CI Release APK.
