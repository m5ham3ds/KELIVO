# تقرير المرحلة 13E — جرد البيئة، الموافقات اليدوية والتخزين الدائم

**تاريخ إعداد نقطة المصدر:** 11 نوفمبر 2026  
**خط الأساس:** `1.3.4+84`  
**الحالة:** تم إعداد تعديلات المصدر واختبارات مركزة؛ **القبول النهائي معلّق** حتى نجاح CI وبناء ARM64 وتجارب الهاتف.

## 1. الحفاظ على نهج المشروع

راجعت ملفات `phases/` وتقارير 13A–13D قبل التعديل. حافظت على النهج المعماري: خدمات منفصلة، أدوات المساعد مسجلة في Built-in Tool Catalog وTool Handler، موافقات مركزية عبر `ToolCallPermission`، وتخزين Runtime داخلي. أكد المستخدم أن اختبارات 13A–13D وبناء Android نجحت بالفعل في تشغيل سابق؛ لذلك بقيت ملفاتها وسجلاتها التاريخية في المشروع، لكن أزيلت بواباتها من Workflow النشط. أُضيفت 13E كمرحلة مستقلة لها preflight واختبارات مركزة فقط، ولا تعيد تشغيل اختبارات A–D.

## 2. أداة `environment_status` — جرد أوسع من PRoot وPython

أضيفت أداة قراءة فقط للمساعد، وتعرض الحالات التالية كلٌّ على حدة:

1. **Ubuntu / RootFS:** حالة التثبيت والتوزيعة والإصدار والمعمارية ومسار RootFS ووجود المجلد.
2. **PRoot المضيف على Android:** تستعلم من `WorkspaceRuntime.status()` الذي يصل إلى فحص قناة PRoot الأصلية والتحقق من مكتبات التشغيل والمعمارية وتوافق RootFS. لا تبحث داخل Ubuntu عن حزمة APT باسم `proot` ولا تستخدم `command -v proot` كاختبار لمشغّل Android.
3. **جلسة PRoot فعلية:** بعد جاهزية المضيف، تشغّل أمرًا ثابتًا قصيرًا بعلامة تحقق داخل الجلسة. وجود RootFS وحده لا يكفي للإبلاغ بأن الجلسة تعمل.
4. **مديرو الحزم داخل Ubuntu:** فحص APT/dpkg وAPK وRPM/DNF/YUM وPacman وSnap وFlatpak وNix، إضافة إلى pip/pipx/uv/Poetry/PDM/Conda، ومديري Node مثل npm/pnpm/Yarn/Bun، وأدوات Cargo وRubyGems وComposer و.NET وغيرها.
5. **الحزم والأدوات المثبتة داخل Ubuntu:** جرد مجموعات APT/dpkg وAPK وRPM/DNF/YUM وZypper وGentoo/Portage وXBPS وPacman وSnap وFlatpak وNix وGuix وHomebrew؛ وبيئات Python مثل pip/pipx/pipenv/uv/Rye/Hatch/Poetry/PDM/Conda/Mamba؛ وNode مثل npm/npx/pnpm/Yarn/Bun/Deno/Volta/Corepack؛ إضافة إلى Cargo/Rustup وRubyGems وComposer و.NET وR وLuaRocks وElixir/Mix عند توفرها. كما يفحص مسارات وإصدارات Git وSSH وcurl/wget وأدوات الأرشفة وFFmpeg/FFprobe وyt-dlp وMediaInfo وImageMagick وSQLite وjq/yq والمترجمات وأدوات البناء وأدوات الحاويات. بعض مديري البيئات يُعرض إصدار أداتهم بدل قائمة حزم عالمية إذا لم يكن لذلك المدير مفهوم حزم عام مناسب.
6. **سجل حزم KELIVO المنفصل:** أضيف جرد لسجل Package Manager الذي يحفظ الحزم في نطاقات runtime/project/extension/task المعزولة. يعرض أسماء الحزم والإصدارات والمدير والنطاق والحالة. ويُوسم صراحةً بأنه **سجل متتبع وليس إعادة فحص حيّة لكل مجلد حزم**؛ لذلك يظهر بجانب جرد Ubuntu الفعلي ولا يحل محله.

تقبل الأداة `detail=summary` لعرض الحالات والأعداد، و`detail=full` لإظهار قوائم محدودة حتى 500 عنصر. يوجد حد أقصى 2 MiB للمخرجات النصية حتى لا يؤدي جرد كبير إلى استهلاك ذاكرة التطبيق.

**حدود الوصول:** لا يمكن لجلسة Ubuntu أن تسرد كل حزم Termux المضيف أو Python مستقلًا مثبتًا في Termux؛ فهما بيئتان منفصلتان. يوضح التقرير ذلك بدل خلطهما. حالة PRoot المضيف تُفحص من طبقة Android، أما حزم الضيف فتُفحص من داخل Ubuntu.

## 3. الموافقات اليدوية حتى في Full Access

أصبح كل استدعاء مساعد يغيّر حالة Skill يطلب موافقة يدوية جديدة:

- `extension_install`
- `extension_update`
- `extension_enable`
- `extension_disable`
- `extension_remove`
- `extension_rollback`

كما أصبحت عمليات Package Manager التالية تتطلب موافقة جديدة:

- `install` و`upgrade` و`remove`
- `pin` و`unpin` لتغيير سجل الإصدارات المثبتة

يُمرر `requireManualApproval: true` في Tool Handler؛ لا تتجاوز هذه السياسة وضع Full Access ولا موافقة سابقة. أما البحث والفحص والقوائم والخطط وفحص التحديثات فهي للقراءة فقط ولا تطلب موافقة تعديل. مسارات التأكيد المباشر داخل واجهة التطبيق لم تُستبدل؛ هذا التغيير يستهدف استدعاءات المساعد.

## 4. فحص التحديثات دون تثبيتها

أضيفت أداة `extension_check_updates`:

- تفحص Skill واحدة بواسطة `id` أو كل المهارات بواسطة `all=true`.
- تقارن GitHub revision للفرع المتتبع مع Commit المثبت، وتتعامل مع Commit المثبت صراحةً على أنه pinned.
- تقارن نسخة مصدر `skills.sh` مع revision المسجل.
- تعرض المصادر المحلية أو القديمة غير القابلة للتتبع كـ`unknown` أو `unsupported` بدل تخمين أنها محدثة.
- لا تفك ملفات إلى مجلد Skills ولا تستبدل `SKILL.md` ولا تعدل Metadata ولا تنشئ Rollback.
- تعيد `readOnly=true` و`filesChanged=false`. عند العثور على تحديث، يجب تنفيذ `extension_update` كعملية منفصلة بموافقة جديدة.

## 5. مجلد KELIVO الظاهر على الهاتف

أضيف ربط Android Storage Access Framework (SAF). يختار المستخدم مجلد KELIVO الموجود أو موقعًا أبًا مثل Documents مرة واحدة، ويحفظ Android إذن الوصول الدائم. إن اختار المستخدم موقعًا أبًا، ينشئ التطبيق داخله `KELIVO/` ثم:

```text
KELIVO/
├── Projects/
├── Results/
├── Downloads/
├── Skills-Exports/
├── Reports/
└── Backups/
```

تبقى Ubuntu وRootFS وملفات Skills الأصلية وقواعد البيانات وبيانات التشغيل في مساحة التطبيق الخاصة. لا يُحوّل SAF URI إلى مسار Linux ولا يُركّب داخل PRoot. يتم التصدير من ملفات خاصة موثوقة عبر `DocumentsContract` وStreams، مع التحقق من أن مصدر الملف داخل مساحة التطبيق، ورفض مسارات الوجهة المطلقة أو التي تتضمن `..` أو أحرف تحكم. تُستخدم وثيقة مؤقتة قبل تثبيت ملف التصدير النهائي للمحافظة قدر الإمكان على النسخة السابقة عند فشل النسخ.

التكامل المنفذ حاليًا:

- نسخ مخرجات Skill الناجحة إلى `Results/<workspace>/<run>/` عند إعداد المجلد العام.
- نسخ ZIP المهارة المصدّر أيضًا إلى `Skills-Exports/`، مع الاحتفاظ بخيار الحفظ الحالي.
- نسخ ملف النسخة الاحتياطية أيضًا إلى `Backups/`، مع الاحتفاظ بتدفق الحفظ الحالي.

`Projects/` و`Downloads/` و`Reports/` جرى إنشاؤها كبنية جاهزة، لكن لم يُدّعَ أن جميع مسارات استيراد المشاريع أو التنزيلات الحالية أصبحت متزامنة معها.

**ملاحظة صلاحيات مهمة:** لم تضف 13E إذن وصول شامل جديدًا ولم تستخدم `MANAGE_EXTERNAL_STORAGE` في مسار SAF. لكن هذا الإذن موجود أصلًا في `AndroidManifest.xml` في النسخة المرسلة، مع تدفق قديم منفصل هو `WorkspaceDirectoryAccess` لتركيب مجلدات Workspace خارجية. أبقيت ذلك السلوك خارج نطاق هذه المرحلة كي لا أكسر ميزة موجودة؛ لذلك لا يعني استخدام SAF هنا أن تصريح المشروع القديم قد أزيل من التطبيق.

## 6. الملفات الأساسية المضافة أو المعدلة

- `lib/core/services/sandbox/environment_status_tool.dart`
- `lib/core/services/packages/package_manager_service.dart`
- `lib/core/services/extensions/extension_command_tools.dart`
- `lib/core/services/extensions/conversational_extension_service.dart`
- `lib/core/services/skills/skills_service.dart`
- `lib/features/home/services/tool_handler_service.dart`
- `lib/core/services/storage/kelivo_public_storage.dart`
- `android/app/src/main/kotlin/com/psyche/kelivo/MainActivity.kt`
- `lib/features/workspace/widgets/environment/environment_public_storage_section.dart`
- `lib/features/workspace/widgets/environment/environment_pane.dart`
- `lib/features/workspace/widgets/skills/skill_detail.dart`
- `lib/features/backup/pages/backup_page.dart`
- ملفات ARB ومخرجات الترجمة للإنجليزية والعربية والصينية المبسطة والتقليدية.
- اختبارات مركزة لأداة حالة البيئة وسجل حزم KELIVO وفحص التحديثات وسياسة الموافقات.
- ربط الاختبارات الجديدة بمشغّل 13E مستقل؛ لا تُربط باختبارات 13C أو13D ولا تُضاف إلى runners التاريخية.

لم تتغير إصدارات Flutter/Dart/Gradle/Kotlin/AGP/NDK أو dependencies أو رقم إصدار التطبيق.

## 7. الفحوص التي أمكن إجراؤها

- اجتاز `bash -n` لسكريبتات جرد البيئة وبوابات Phase 13 المعدلة، وشُغّل جرد summary وfull في حاوية التطوير؛ جرى التحقق من أقسام مديري الحزم والأدوات وحد اقتطاع النتائج.
- نُفّذ سكريبت جرد الحزم في بيئة التطوير المتاحة بنجاح في وضع summary وfull؛ جرى اختبار حد العناصر وإظهار علامات الاقتطاع. كانت بيئة الاختبار Debian x86_64، وليست Ubuntu PRoot على هاتف Android.
- اجتاز اختبار تنسيق CI الذي يتحقق من وجود بوابتي Phase 13E فقط (preflight ثم الاختبارات)، ومن غياب جميع runners القديمة 13A–13D من Workflow النشط.
- تحتوي مجموعة Flutter المركزة على أربع استدعاءات: ملف اختبارات `environment_status` الجديد، واختبار سجل الحزم المعزول وحده، واختبار فحص Skill update الجديد وحده، واختبار تسجيل أدوات 13E وسياسات الموافقة وحده. فحص dispatch ساكن داخل preflight يتحقق من تمرير `requireManualApproval: true` في فرعي تعديلات Skills والحزم. لا يعاد تشغيل ملف `conversation_tool_permissions_test.dart` التاريخي.
- اجتاز Android-only audit وتدقيق Release hardening.
- اجتاز فحص ARB: عدد 4791 رسالة، منها 4670 ترجمة عربية مراجعة (97.47%) و121 قيمة fallback إنجليزية. كما تحققت مفاتيح الترجمة الجديدة في ملفات ARB ومخرجات Dart.

**ما لم يمكن اختباره محليًا:** لا تتوفر أوامر `flutter` أو `dart` أو `gradle` أو Android SDK/`android.jar` في بيئة التجهيز. لذلك لم يُشغّل Dart analyzer ولا Flutter tests فعليًا، ولم يُترجم Kotlin على Android، ولم يُبنَ APK، ولم تُختبر SAF أو الموافقات على الهاتف. نجاح اختبارات shell والتدقيق لا يعني نجاح بناء التطبيق.

## 8. بوابات القبول التالية

1. تشغيل GitHub Actions الحالي: Phase 13E preflight ثم اختبارات 13E المركزة فقط؛ يجب ألا تظهر بوابات 13A أو13B أو13C أو13D في التنفيذ.
2. بعد نجاح اختبارات 13E، بناء APK Release لـAndroid ARM64 وتثبيته على الهاتف.
3. تشغيل `environment_status` مع summary وfull والتحقق من Ubuntu 24.04 وPRoot host probe وعلامة الجلسة الفعلية وتعداد الحزم والأدوات وسجل الحزم المعزولة.
4. اختبار كل من Skill mutations وPackage mutations في Full Access: يجب أن تظهر موافقة يدوية جديدة في كل مرة، وأن يؤدي الرفض إلى عدم تغيير الملفات أو السجل.
5. تثبيت GitHub Skill تجريبية، ثم فحص تحديثها والتحقق من عدم تعديل ملفاتها أو metadata أو rollback قبل الموافقة على التحديث المنفصل.
6. اختبار اختيار مجلد أب واختيار مجلد KELIVO موجود، وبقاء الإذن بعد إعادة تشغيل التطبيق.
7. تصدير مخرج Skill وZIP مهارة ونسخة احتياطية، والتحقق من أماكنها، ثم إلغاء إذن المجلد والتأكد من طلب إعادة الاختيار مع بقاء الملفات الخاصة.
8. مراجعة تصريح `MANAGE_EXTERNAL_STORAGE` القديم كعمل منفصل، وتحديد هل لا تزال ميزة تركيب Workspace الخارجي تحتاجه أم يمكن نقلها مستقبلًا إلى SAF.

## 9. الحدود الأمنية والمعمارية الباقية

PRoot ليس Kernel Sandbox: RootFS مشترك وقابل للكتابة، والشبكة غير مقيدة، والمهارات التي تمت الموافقة على تشغيلها قد تؤثر في RootFS وتشغيلات لاحقة. كما أن هذه المرحلة لا تكمل بعد MCP `tools/list` و`tools/call`، أو كل أشكال API/Binary، أو مزامنة كل مجلدات Projects/Downloads. تبقى هذه نقاطًا موثقة ولا يصح اعتبارها مكتملة.
