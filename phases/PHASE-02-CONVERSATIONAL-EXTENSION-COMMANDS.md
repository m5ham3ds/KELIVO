# PHASE 2 — Conversational Extension Commands

**الحالة:** نُفذت التغييرات في المصدر؛ القبول النهائي ينتظر `dart format` و`dart analyze` و`flutter test` وبناء Android ARM64 عبر GitHub Actions.

## 1. الهدف

تمكين المستخدم من إدارة مهارات Agent Skills من المحادثة مباشرةً، دون الحاجة إلى فتح صفحات إعدادات Skills. تتحول طلبات النموذج إلى أوامر Typed مرتبطة بخدمات Kelivo الفعلية، ويظهر تقدم العمليات ونتائجها في بطاقة الأداة داخل المحادثة.

هذه المرحلة تنفذ دورة حياة **Skill** فقط. لا تدّعي تثبيت Engines أو Providers أو MCP Servers أو الحزم البرمجية العامة. لكل نوع من هذه الأنواع Adapter ومدير تبعيات في مراحل لاحقة.

## 2. أدوات المحادثة

| Tool | الوظيفة |
|---|---|
| `extension_search` | البحث في Skills المثبتة ومرشحات مستودعات GitHub العامة |
| `extension_inspect` | قراءة Skill مثبتة أو معاينة مصدر قبل التثبيت |
| `extension_install` | تثبيت Skill واحدة من GitHub عام أو Markdown أو ZIP أو مجلد داخل Workspace |
| `extension_update` | تحديث Skill من مصدر GitHub عام مع إنشاء Snapshot سابق |
| `extension_enable` | تفعيل Skill |
| `extension_disable` | تعطيل Skill دون حذفها |
| `extension_remove` | إزالة Skill وملفاتها ولقطات Rollback التابعة لها |
| `extension_rollback` | استرجاع Snapshot سابق |
| `extension_list` | عرض Skills وحالتها وسجل العمليات الأخير |

الأدوات معرفة عبر `ExtensionCommandToolCatalog`، وتُضاف إلى Tool Handler عند دعم النموذج لاستدعاء الأدوات. أُضيفت الأسماء إلى قائمة الأسماء المحجوزة لمنع MCP Server من حجز أسماء Kelivo الداخلية.

كما تتضمن تعليمات نواة Kelivo إرشادات محادثية صريحة: عند طلب المستخدم تثبيت/تحديث/تفعيل/تعطيل/إزالة Skill يستخدم النموذج الأداة المناسبة إذا كانت متاحة في الجولة الحالية، ويفحص المصدر غير المألوف قبل التثبيت، ويتحقق من النتيجة قبل إعلان النجاح. يمكن استخدام أكثر من Skill مثبتة في المهمة نفسها عندما تكون تعليماتها متوافقة. وتمنع التعليمات الادعاء بتثبيت حزم أو محركات أو مزودات لم تُنفذ بعد.

## 3. مصادر التثبيت المدعومة

### GitHub العام

- رابط مستودع/فرع/مجلد يحدد Skill واحدة.
- رابط `SKILL.md` متوافق مع محلل GitHub Skill الحالي.
- التحديث من المصدر المسجل أو من رابط بديل صريح.
- البحث العام في GitHub يعرض مستودعات مرشحة فقط. يجب فحص المرشح قبل تثبيته.

### الملفات المحلية

- ملف `SKILL.md` منفرد.
- ملف ZIP.
- مجلد Skill يحتوي `SKILL.md` في جذره.

تُحل المسارات من خلال Workspace binding الحالي، ولا يُسمح بالوصول إلى ملفات Android المضيفة خارج Workspace mounts.

### حدود الاستيراد الحالية

- يجب أن يحدد المصدر Skill root واحدة فقط.
- إذا احتوى أرشيف/مجلد المصدر على عدة ملفات `SKILL.md` محتملة، يرفض المستورد اختيار واحدة عشوائياً؛ يطلب مساراً فرعياً دقيقاً. دعم اكتشاف جميع Skills في مستودع واحد واختيارها أو تثبيتها دفعة واحدة موضوع Phase 3.
- لا يوجد دعم للمستودعات الخاصة في هذه المرحلة.
- معاينة المصدر لا تشغّل سكربتات.
- التثبيت ينزل الملفات ويفحص البنية وبيانات `SKILL.md` فقط. ملفات `scripts/` لا تُنفذ أثناء التثبيت.
- لا يتم تشغيل npm/pip/apt/Gradle أو تثبيت مكتبات المتطلبات تلقائياً هنا؛ ذلك من اختصاص Dependency Manager في مرحلة لاحقة.

## 4. دورة الحياة

### Install

1. التحقق من نوع الإضافة (`skill` فقط في هذه المرحلة).
2. التحقق من المصدر وحدود الثقة.
3. بدء سجل العملية.
4. تنزيل المصدر أو نسخه إلى مجلد مرحلي.
5. فحص الملفات والمسارات و`SKILL.md` والحدود الحجمية.
6. رفض مصادر Skill المتعددة أو غير الحاسمة.
7. تسجيل Skill في `SkillsService` وExtension Registry.
8. التفعيل افتراضياً ما لم يطلب المستخدم خلاف ذلك.
9. إظهار ملخص وPreview محدود من التعليمات.

### Update / Rollback

- التحديث متاح للمهارات التي تملك مصدر GitHub عام قابلاً لإعادة الاستخدام.
- يُنشأ Snapshot من النسخة الحالية قبل استبدال ملفاتها.
- عند نجاح التحديث تُحدث البيانات الوصفية والمصدر والـ Registry.
- `extension_rollback` يعيد آخر Snapshot، ويحتفظ أيضاً بنسخة من الإصدار الحالي قبل التبديل.

### Enable / Disable / Remove

- Enable/Disable يغيران حالة SkillsService ويزامنان Extension Registry.
- Remove يحذف Skill وسجلها ومجلدها وSnapshots التابعة لها.
- الإزالة دائمة داخل التثبيت الحالي ما لم يكن لدى المستخدم نسخة مستقلة.

## 5. سجل العمليات والتقدم

أُضيف `ExtensionOperationRepository` فوق جدول `extension_entity_rows` الحالي باستخدام النوع `extension_operation`، دون إضافة جدول Drift أو migration.

السجل يحتوي على:

- معرف العملية والأداة ونوع الإضافة والهدف.
- مصدر آمن بعد حذف query وfragment من روابط GitHub.
- معرف استدعاء الأداة عند توافره.
- الحالة: `running`, `succeeded`, `failed`, `cancelled`.
- المرحلة الحالية والبايتات المستلمة/الإجمالية.
- ملخص النتيجة ورمز خطأ غير حساس.
- أوقات البدء والتحديث.

يُحفظ سجل محدود إلى 80 عملية مكتملة كحد أقصى، مع عدم حذف العمليات الجارية أثناء التنظيف. يعرض `extension_list` آخر العمليات.

تُرسل المراحل الحالية إلى `ToolRunRegistry` لعرض تقدم حي داخل بطاقة المحادثة. يُربط إلغاء Tool Call بإشارة الإلغاء المتاحة في Kelivo ويُمرر إلى مسارات تنزيل/نسخ المهارة المدعومة. لا يُسمح لفشل telemetry أن يحوّل عملية تثبيت ناجحة إلى فشل.

## 6. الأمان والحدود

- قبول HTTPS لمضيفات GitHub المعتمدة فقط.
- رفض userinfo ومنافذ غير قياسية ومعاملات query التي تبدو كأسرار/رموز.
- رفض المسارات المحلية خارج Workspace mounts.
- رفض اجتياز المسار والروابط الرمزية في استيراد المجلدات.
- الحد الأقصى لملفات المجلد المستورد 2,048 ملفاً، وبحد إجمالي 500 MB وفق ثابت الاستيراد الحالي.
- الأرشيف الذي يحتوي أكثر من Skill root لا يثبت أول Skill اعتباطياً.
- لا تُشغل سكربتات المهارة ولا أوامر package managers أثناء الاستيراد.
- نتائج GitHub Search لا تعامل كمصدر موثوق حتى تُفحص.
- الأسرار وبيانات الاعتماد لا تُكتب في سجل العمليات.

## 7. الملفات الأساسية

### ملفات التطبيق

- `lib/core/services/extensions/extension_command_tools.dart` — تعريف أسماء وأوصاف وأشكال أدوات المحادثة.
- `lib/core/services/extensions/conversational_extension_service.dart` — توجيه الأوامر وتنفيذ دورة الحياة والتقدم والإلغاء.
- `lib/core/services/extensions/extension_operation_repository.dart` — سجل العمليات.
- `lib/core/services/extensions/extension_registry_repository.dart` — حفظ مصدر GitHub ومرجعه ومساره الفرعي ومراجعته عند مزامنة Skill.
- `lib/core/database/extension_entity_store.dart` — نوع تخزين سجل العمليات في الجدول العام.
- `lib/core/services/skills/skills_service.dart` — معاينة/بحث/تثبيت/تحديث/تراجع ونسخ الملفات محلياً مع الإلغاء والحدود.
- `lib/core/services/skills/skill_archive.dart` — رفض الأرشيف متعدد Skill roots بدلاً من اختيار أول Skill تلقائياً.
- `lib/features/home/services/tool_handler_service.dart` — ربط أدوات المحادثة بالخدمات.
- `lib/features/home/services/built_in_tool_names.dart` — حجز أسماء الأدوات.
- `lib/core/services/tools/built_in_tool_catalog.dart` — عرض الأدوات ضمن كتالوج الأدوات المدمجة.
- `lib/features/chat/widgets/workspace_tool_ui.dart` — بطاقات أدوات Extension وتقدمها الحي داخل المحادثة.
- `lib/main.dart` — توفير `ExtensionOperationRepository`.

### الاختبارات

- `test/core/services/extensions/conversational_extension_service_test.dart`
- `test/core/services/extensions/extension_operation_repository_test.dart`
- `test/core/services/skills/skills_service_test.dart`
- `test/core/services/skills/skill_archive_test.dart`
- `test/features/chat/widgets/workspace_tool_ui_test.dart`

## 8. معايير القبول

- [x] تعريف 9 أدوات محادثة Typed.
- [x] ربط أدوات التثبيت والتحديث والتفعيل والتعطيل والإزالة والتراجع بخدمات Skills.
- [x] دعم GitHub العام ومصادر ملفات/مجلدات Workspace.
- [x] فحص Skill قبل التثبيت وعدم تشغيل سكربتاتها.
- [x] رفض مصادر متعددة Skills roots بدلاً من اختيار عشوائي.
- [x] حفظ سجل العمليات والمرحلة ورمز الخطأ.
- [x] إظهار progress stream في بطاقة أداة المحادثة للعمليات طويلة المدة.
- [x] إضافة إلغاء التنزيل/النسخ للمسارات المدعومة.
- [x] عدم فرض محركات أو مكتبات فيديو ثابتة.
- [ ] `dart format --output=none --set-exit-if-changed` على الملفات المعدلة.
- [ ] `dart analyze --fatal-infos` على `lib` وملفات الاختبار المحددة في `.github/ci/android-phase2-test-manifest.txt` واختبار واجهة المحادثة المحدد فقط.
- [ ] تشغيل اختبارات Android المركزة في manifest واختباري واجهة أدوات المحادثة المحددين؛ لا تُشغّل مجموعات iOS أو macOS أو Windows أو Linux أو `integration_test` العامة في CI الخاص بهذه المرحلة.
- [ ] Android ARM64 Release build وتثبيت APK واختبار أوامر التثبيت على الجهاز.

### حدود اختبارات Phase 2 في CI

مصدر الحقيقة لقائمة الاختبارات هو `.github/ci/android-phase2-test-manifest.txt`. تضم القائمة اختبارات دورة حياة Skill، وسجل العمليات، وسجل الإضافات، وأرشيف الاستيراد، وحقن التعليمات وأسماء الأدوات. يُشغّل CI اختبارين مسمّيين فقط من `workspace_tool_ui_test.dart` للتحقق من كتالوج أدوات المحادثة والتقدم الحي للتثبيت. لا يُشغّل `flutter test` على كامل المستودع، ولا يحلل مجلدات الاختبار غير المرتبطة بهذه المرحلة، ولا ينفذ اختبارات markstream المستقلة أو اختبارات التكامل العامة. تبقى تبعية markstream محلولة ضمن `flutter pub get` لأنها تبعية runtime للتطبيق.

الهدف هو اختبار السلوك الذي تغير في Phase 2 فقط، وليس تعطيل فحوص التطبيق: يظل `dart analyze` يغطي جميع مصادر الإنتاج في `lib`، ثم يُبنى APK Release حقيقي لمعمارية Android ARM64.

## 9. قيود معروفة تنتقل إلى المراحل التالية

1. Phase 3: مطابقة Agent Skills بصورة أوسع، دعم multi-skill repositories واختيار skill subfolder تلقائياً، tags/commit pinning، private GitHub auth adapters، ومصادر Registry متعددة.
2. Phase 4: Multi-Skill Composition Engine لتخطيط/دمج أكثر من Skill في مهمة واحدة وترتيب تعارضات التعليمات.
3. Phase 5: Dependency Manager لتثبيت npm/pip/apt/Gradle وأدوات runtime بطريقة آمنة ومعلنة.
4. Phase 6: عزل وتنفيذ سكربتات Skills ومراقبة الموارد والصلاحيات.
5. بقية المراحل: Engine/Provider/Workflow installers وتشغيل محركات الفيديو.

لا تعتبر Phase 2 بديلاً عن Dependency Manager، ولا تسمح بتشغيل أي Skill script تلقائياً.


## Approval policy

State-changing Skill commands use Kelivo's existing conversation-level tool approval policy. Read-only search, inspect and list commands do not request mutation approval. A user's explicit chat request still initiates the operation; the existing permission mode determines whether the action requires a separate confirmation.
