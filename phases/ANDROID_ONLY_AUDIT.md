# Android-only source audit

المستودع الحالي Android-only. PRoot هو Linux userland داخل Android وليس Linux desktop runner. لا توجد أهداف تشغيل أصلية مدعومة لـiOS أو Windows أو macOS أو Linux المكتبي أو Web.

## ABI
قد يحوي أرشيف PRoot المصدر مكتبات ARMv7 وARM64 وx86_64. نسخة الإنتاج يجب أن تحتوي arm64-v8a فقط، بينما x86_64 محصور في اختبار المحاكي المؤقت. يتحقق package_android_apk.sh من محتويات APK الفعلية.

## بوابات CI النشطة
Android-only/Release audit، dependencies، توطين Arabic، gen-l10n، تحليل Flutter static، Phase 13Q parser test، خمس حزم محلية، Android JVM/Robolectric، أربع emulator integration tests، ARM64 APK + ZIP ABI check + SHA-256.

## غير مشمول في المسار الحالي
كامل Flutter root unit/widget suite، ومجموعات Phase 13E–13O المركزة. لا تسجل على أنها ناجحة اعتمادًا على التحليل الثابت.

## CI #72
نجحت كل خطوات workflow النشطة. فحص APK بعد تنزيله أثبت 18 ملف .so ضمن lib/arm64-v8a فقط. Java 21 وFlutter 3.47.6 وNDK 28.2.13676358 وCMake 3.22.1.

## حدود الأمان
PRoot ليس Kernel sandbox؛ RootFS مشترك وقابل للكتابة والشبكة غير مقيدة بالكامل. موافقة التطبيق ليست عزلًا يفرضه نظام التشغيل. اكتشاف MCP أو API أو Workflow لا يعني الاتصال أو التنفيذ.
