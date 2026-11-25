# PHASE 14B — Plugin Manifest & Component Registry

**الحالة:** تنفيذ أولي مضاف إلى المصدر؛ القبول النهائي معلّق حتى نجاح GitHub Actions على commit التنفيذ ومراجعة كل job/step.
**تاريخ نقطة البدء:** 25 نوفمبر 2026.
**بوابة المرحلة السابقة:** Phase 14A اجتازت CI #162 بنجاح على commit `14c7938617ccaab7b38542caebb891f292c7ef18`.
**المستودع:** https://github.com/m5ham3ds/KELIVO — الفرع `main`.

## 1. الهدف وحدود التنفيذ

إضافة قارئ Manifest وسجل لمكونات Claude-compatible Plugin فوق `ExtensionRecord` و`ExtensionRegistryRepository` الموجودين، من دون استبدال نظام Skills أو إنشاء Registry/Database ثانٍ.

هذه المرحلة تحفظ Plugin كحزمة وبيانات وصفية. وجود Command أو Hook أو Script أو MCP server في Plugin لا يمنح صلاحية تشغيله.

**ما لا تنفذه 14B:**
- لا تشغيل Commands أو Agents أو Hooks أو Scripts.
- لا إطلاق أو اتصال MCP server عند import/inspect/install/update.
- لا منح صلاحيات من بيانات manifest.
- لا ادعاء أن PRoot sandbox على مستوى Kernel.

## 2. ما أضيف في المصدر

### نماذج البيانات

- `lib/core/models/plugin_manifest.dart`: محلل Manifest بإصدار schema 1؛ يقرأ الاسم والإصدار والوصف والمؤلف والرابط والترخيص والكلمات المفتاحية والمسارات المعلنة. يحتفظ بالحقول المجهولة وغير المدعومة ويصدر تحذيرات واضحة.
- `lib/core/models/plugin_component.dart`: descriptor لكل مكون مع النوع والاسم والمسار النسبي والحالة وبصمة SHA-256 والحجم. الحالات هي `inspect_only` و`disabled_by_default` و`unsupported`.

### الفحص والاستيراد

- `lib/core/services/extensions/plugin_manifest_service.dart`: فحص directory وZIP للقراءة فقط، وتوليد inventory وبصمة شجرة مستقرة من المسارات ومحتوى الملفات.
- يتوافق مع `.claude-plugin/plugin.json`، ويفحص `commands/` و`agents/` و`skills/` و`hooks/hooks.json` و`.mcp.json` و`scripts/`.
- يقبل ZIP بجذر مستودع واحد ويعيد توجيه المسارات إلى جذر الحزمة الفعلي.
- يرفض absolute paths وtraversal وsymlinks والملفات الخاصة والتكرارات، ويضع حدوداً: 4096 ملفاً، و8192 مدخلاً/مجلداً، وعمق 16 مستوى، و200 MiB إجمالاً، و32 MiB للملف، و64 KiB للـmanifest، و128 descriptor.
- Commands وAgents وSkills تبقى inspect-only؛ Hooks وMCP disabled-by-default؛ Scripts والأنواع غير المدعومة تبقى descriptors غير قابلة للتنفيذ.

### السجل والتخزين والمعاملة

- `lib/core/services/extensions/extension_registry_repository.dart`: أضيف استرجاع ومراقبة مكونات Plugin من السجل الأب نفسه.
- `lib/utils/app_directories.dart`: أضيف جذر `plugins/` الخاص ببيانات التطبيق.
- لا توجد migration لقاعدة SQLite: يتم حفظ Plugin كسجل أب واحد من النوع `plugin`، وتخزن descriptors ضمن metadata. محتويات الحزمة تحفظ كاملة تحت مجلد Plugin، بما فيها الموارد والملفات الثنائية غير المعلنة.
- عند install/update: stage ثم نسخ ثم إعادة فحص digest ثم rename/backup ثم upsert واحد لسجل الأب؛ عند فشل cutover أو upsert يجري rollback إلى المجلد والسجل السابقين.
- عند uninstall: ينقل المجلد إلى backup أولاً، ثم يحذف سجل الأب، ويعيد المجلد عند فشل الحذف.

### واجهة المستخدم

- `lib/features/workspace/pages/plugins_page.dart`: واجهة لعرض Plugins ومكوناتها وحالاتها وتحذيرات manifest وإزالتها.
- تدعم الاستيراد من مجلد أو ZIP. إضافة زر إدارة Plugins إلى `SkillsPageActions` يربط الصفحة بواجهة Workspace.
- لا يوجد زر لتشغيل أي component.

## 3. الاختبارات المضافة

`test/core/services/extensions/plugin_manifest_service_test.dart` يغطي:
1. فحص fixture Claude Plugin يضم Command وAgent وSkill وHook وMCP configuration وScript، مع حفظ unknown-field warning.
2. التعامل الصحيح مع ملفات references داخل Skill وعدم عدّها مهارات مستقلة.
3. رفض traversal في manifest paths.
4. رفض symlink داخل شجرة Plugin.
5. رفض المكونات المعلنة المفقودة.
6. رفض أسماء المكونات المكررة داخل النوع نفسه.
7. install ثم update، وإجبار فشل registry write لإثبات rollback إلى المحتوى والسجل السابقين، ثم uninstall.
8. رفض traversal في ZIP.
9. استيراد ZIP بمجلد جذر واحد.
10. إثبات عدم تشغيل Script خلال inspect أو install عبر marker خارجي.

**حالة التحقق:** أضيفت خطوة CI باسم `phase14b_plugin_manifest_tests` لتشغيل مجموعة الاختبارات أعلاه. هذه اختبارات مصدرية معدة للتشغيل في CI الجديد؛ لم تعتبر ناجحة قبل ظهور النتائج. يجب أن تشمل المراجعة Flutter Analyze ومرحلة اختبارات الخدمة وAndroid JVM/Robolectric وPhase 13P Emulator E2E وبناء ARM64 ورفع APK.

## 4. القيود والقرارات

- `ExtensionRecord.metadata` يبقى خاضعاً لحدوده الحالية؛ إذا تجاوز manifest/metadata الحد الآمن يفشل install بدلاً من إسقاط الحقول بصمت.
- الروابط العامة للـhomepage/repository تخضع لتنقية credentials وquery/fragment الحساسة.
- بيانات author والحقول المجهولة تنظف من مفاتيح الأسرار قبل حفظ سجل Plugin.
- وجود `.mcp.json` أو `mcpServers` لا ينشئ اتصالاً ولا يسجل خادماً للتشغيل.
- لا يدّعي فحص ZIP أو directory إثبات سلامة السلوك البرمجي؛ إنه inventory وبصمة وتحقق مسار فقط.
- لم يجر اختبار Android على هاتف فعلي في هذا checkpoint.

## 5. قرار القبول

**14A:** مقبولة بعد CI #162، بما يشمل اختبارات Progressive Skill Discovery وFlutter Analyze وRobolectric ومحاكي Android وبناء ARM64.

**14B:** لم تقبل بعد. معيار القبول هو نجاح CI على تغييرات هذا التقرير، ثم فحص logs/artifacts والتأكد من عدم تشغيل أي مكون أثناء الاستيراد والفحص. تسجل بصمة APK وABI ونتيجة كل job في هذا الملف بعد اكتمال CI.
