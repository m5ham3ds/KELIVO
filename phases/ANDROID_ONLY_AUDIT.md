# Android-only source audit

المستودع الحالي Android-only. PRoot هو Linux userland داخل Android وليس Linux desktop runner. لا توجد أهداف تشغيل أصلية مدعومة لـiOS أو Windows أو macOS أو Linux المكتبي أو Web.

## ABI
قد يحوي أرشيف PRoot المصدر مكتبات ARMv7 وARM64 وx86_64. نسخة الإنتاج يجب أن تحتوي arm64-v8a فقط، بينما x86_64 محصور في اختبار المحاكي المؤقت. يتحقق package_android_apk.sh من محتويات APK الفعلية.

## بوابات CI النشطة
Android-only/Release-hardening audit، Flutter 3.47.6 dependencies، Arabic localization parity وgen-l10n، Flutter Analyze، Environment lifecycle، Phase 14A و14B و14E.2، Gemini/OAuth، Phase 14C.4، Phase 13Q/14D real STDIO، خمس حزم محلية، Android JVM/Robolectric، Phase 13P Android Emulator E2E، ARM64 APK + ABI check + SHA-256، ونشر تقرير Markdown.

## غير مشمول في المسار الحالي
كامل Flutter root unit/widget suite، ومجموعات Phase 13E–13O المركزة. لا تسجل على أنها ناجحة اعتمادًا على التحليل الثابت.

## أحدث فحص مؤكد — CI #208
نجحت وظيفتا البناء ونشر التقرير على `main` commit `77736b783d55752a35a3aeb3b66b6b6dce7e87f1`. APK: 41,943,583 bytes، وABI `arm64-v8a` فقط، SHA-256 `29fa1b9db0223dd0b9c6d8f170af3b86f6d44f2f5dd88a992843bd09f907f6fa`. Artifact `15167472926`، تقرير البناء `15167378117`، السجلات الخام `15167717401`. استخدم GitHub Actions step conclusions لتحديد نجاح البوابات؛ لا تخلط التحليل الساكن مع تشغيل اختبارات غير مدرجة.

## سجل سابق — CI #72
نجحت كل خطوات workflow النشطة في ذلك التاريخ. فحص APK بعد تنزيله أثبت 18 ملف .so ضمن lib/arm64-v8a فقط. Java 21 وFlutter 3.47.6 وNDK 28.2.13676358 وCMake 3.22.1.

## حدود الأمان
PRoot ليس Kernel sandbox؛ RootFS مشترك وقابل للكتابة والشبكة غير مقيدة بالكامل. موافقة التطبيق ليست عزلًا يفرضه نظام التشغيل. اكتشاف MCP أو API أو Workflow لا يعني الاتصال أو التنفيذ.
