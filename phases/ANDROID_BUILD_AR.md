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
5. flutter analyze --no-pub lib test integration_test.
6. اختبارات Phase 13Q للقراءة فقط لإعداد MCP المعلن من Skill، دون تشغيل الخادم.
7. اختبارات الحزم المحلية: mcp_client وdownsize وflutter_math_fork وmarkstream وterminal_view.
8. Java 21 وGradle 8.14 وNDK 28.2.13676358 وCMake 3.22.1.
9. Android JVM/Robolectric عبر :app:testDebugUnitTest.
10. أربعة Android emulator integration tests على main، ومنها skill_execution_e2e_test.dart.
11. إعداد plugin registrant لوضع البناء وتعطيل ABI التجريبي.
12. بناء ARM64 APK والتحقق من ZIP وحساب SHA-256 ورفع artifact.

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

CI #77 أثبت أن إضافة Gradle mirror وحدها لم تكن كافية: نجح حل Gradle dependencies، لكن 9 اختبارات فشلت عند `MavenArtifactFetcher.java:129` مع `IOException`. لا يسجل هذا التقرير HTTP 429 لـ#77 لأن السجل لم يحدد رمز الاستجابة. التعديل الحالي يعالج مسار runtime المنفصل؛ ولا يعتبر الإصلاح مقبولاً حتى يثبت CI تنزيل runtime واكتمال كل الاختبارات فعلياً.

## إصدارات الأدوات
Flutter 3.47.6 · Java 21 · Gradle 8.14 · NDK 28.2.13676358 · CMake 3.22.1 · production ABI arm64-v8a.

إذا غاب android/key.properties يستخدم Release مفتاح Debug الافتراضي؛ هذا APK للاختبار وليس مفتاح نشر Google Play.

CI #72 (22 November 2026) نجح: https://github.com/m5ham3ds/KELIVO/actions/runs/44969006889  
APK 41,825,267 bytes · 18 .so ضمن arm64-v8a فقط · SHA-256 a6271844472413909fa927b5220601dc2825b86e1b01386ef3bc2cce6a56a3a3.


## سجل CI الأحدث

CI #76 على commit `f68e792b771822b31522705720a2ecc82c2d5606` فشل في المحاولة الثانية أثناء `:app:testDebugUnitTest`: لم يستطع Gradle تنزيل `org.robolectric:nativeruntime-dist-compat:1.0.18` لأن Maven Central أعاد HTTP 429. لم يتم إنشاء APK في ذلك التشغيل. أضيفت مرآة Google scoped لمجموعة Robolectric؛ يظل الإصلاح بانتظار إثباته في CI لاحق.
