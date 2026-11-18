# KELIVO — Phase 13A Implementation Report

**المرحلة:** 13A — Universal Skill Import & Capability Discovery
**خط الأساس:** KELIVO `1.3.4+84`
**تاريخ التنفيذ:** 2026-11-10
**الحالة:** تغييرات المصدر والاختبارات المركزة أُضيفت؛ القبول النهائي **معلّق** حتى اجتياز GitHub Actions وبناء Android ARM64 واختبارات الهاتف.
**النطاق:** 13A فقط. لم يبدأ تنفيذ 13B أو 13C أو 13D.

## 1. الخلاصة التنفيذية

تمت مراجعة شجرة `phases/` ومقارنة مواصفات وتقارير Phase 0–12 بمصدر الأرشيف الحالي قبل تعديل الملفات. لم يُعامل أي تقرير سابق كدليل على وجود التنفيذ في النسخة الحالية.

أظهرت المقارنة أن مستورد المجلد المحلي كان ينسخ الملفات المتداخلة والبايتات، وأن مستورد ZIP متعدد المهارات كان يحفظ الملفات الواقعة داخل مجلدات `SKILL.md` لكنه لا يحتفظ بملفات المستودع الواقعة خارج تلك المجلدات. كما كان موصل `skills.sh` يفترض أن كل عنصر ملف يملك `contents` نصية، ما لا يمثل الأصول الثنائية. ولم يكن هناك Capability Descriptor مستقل أو manifest موحّد يحوي بصمات جميع الملفات.

تعالج هذه الدفعة الفجوات ضمن عقد استيراد وصفي: يظل `SKILL.md` وثيقة التعليمات، وتبقى البرامج والأصول والموصلات وملفات workflow كيانات مستقلة داخل حزمة المصدر. يحتفظ كل مستودع بملفاته المشتركة في مساحة بيانات تطبيق خاصة منفصلة، وتربط بها المهارات صراحة بمرجع للقراءة فقط. لا يسمح هذا الربط بتنفيذ تلك الملفات أو تركيبها في PRoot.

## 2. خريطة الاعتماد التي راجعتها

| المجال | مسارات المصدر الأساسية | قرار 13A |
|---|---|---|
| Skills والاستيراد | `lib/core/services/skills/skills_service.dart`, `skill_archive.dart`, `skills_catalog_adapter.dart`, `skill_import_candidate.dart`, `skill.dart`, `skill_frontmatter.dart` | تعديلات محصورة هنا مع إضافة manifest مستقل |
| Extensions/Registry | `lib/core/models/extension_record.dart`, `lib/core/services/extensions/extension_registry_repository.dart`, `lib/core/database/extension_entity_store.dart` | الإبقاء على التسجيل الحالي؛ إضافة sidecar metadata دون تغيير schema قاعدة البيانات |
| Workspace | `lib/core/services/workspace/*`, `lib/core/providers/workspace*`, `lib/features/workspace/*` | لا تغيير لمسارات Workspace ولا منح وصول جديد |
| Environment | `lib/core/services/environment/*`, `lib/core/providers/environment*` | لا تثبيت ولا تغيير بيئة |
| PRoot | `lib/core/services/runtime/android_proot_runtime.dart`, `lib/core/services/workspace/workspace_paths.dart`, `android/app/src/main/kotlin/*/ProotCommand.kt`, `WorkspacePlugin.kt`, `MountWriteGuards.kt` | لم تُعدّل؛ لا Mount إضافي ولا فتح شجرة Skills للكتابة |
| Runtime Profiles | `lib/core/services/runtime_profiles/*` | تُترك كما هي؛ لا إنشاء منفّذ أو تبديل profile |
| Package Manager | `lib/core/services/packages/*` | الاعتماديات تُقرأ فقط؛ لا تثبيت أو lifecycle scripts |
| MCP | `lib/core/providers/mcp_provider.dart`, `lib/core/services/mcp/*` | لا تشغيل ولا `tools/list` أو `tools/call` عند الاستيراد؛ اكتشاف MCP يحتاج تعريفًا صريحًا |

## 3. ما نُفّذ

### 3.1 Capability Descriptor وملف manifest

أُضيف `lib/core/services/skills/skill_import_manifest.dart` ويعرّف:

- `SkillCapabilityDescriptor` منفصلًا عن `SKILL.md`.
- الأنواع: `instruction_only`, `local_script`, `cli_binary`, `mcp_server`, `http_api_connector`, `native_kelivo_tool`, `workflow`.
- `executionEnabled` ثابت على `false` في هذه المرحلة.
- manifest بإصدار schema مستقل، يحفظ source URL/repository/ref/commit، بصمة المصدر، حالة الاكتمال وملاحظاتها، الملفات، القدرات، الاعتماديات والعناصر المتخطاة.
- لكل ملف: relative path، الحجم، media type المكتشف، SHA-256، scope، executable bit عندما تتوفر دلالة مصدر موثوقة، ومسار المصدر عند ارتباطه بمورد مشترك.

تُكتشف ملفات MCP من ملفات إعداد معروفة وبمحتوى يصرّح بنقل وخادم فعليين؛ لا يكفي وجود `mcpServers` فارغ أو اسم `mcp.json` وحده، ولا يصنّف مجلد `tools/` خادم MCP. ويتطلب تعريف MCP المعلن transport ونقطة دخول Server صريحة. ملف MCP المشوه أو الأكبر من حد الفحص يبقى محفوظًا ويظهر كتحذير بدل إسقاط Skill كاملة. تُكتشف OpenAPI/Swagger أو ملفات connector وworkflow المعروفة دون تشغيلها.

تُخزّن manifests في مجلد بيانات التطبيق `skill-import-metadata/` خارج شجرة Skills وPRoot، ويُتاح التقرير عبر `SkillsService.getImportReport()`.

### 3.2 حفظ المستودعات متعددة المهارات ومواردها المشتركة

أُضيف `extractSkillRepositoryArchive()` إلى `skill_archive.dart`:

- يبقي كل Skill في مجلد مستقل، ويُسنِد الملفات إلى أعمق مجلد يحتوي `SKILL.md` عند وجود مهارات متداخلة.
- لا يسقط ملفات المستودع المشتركة الواقعة خارج جميع مجلدات Skills؛ يحفظها مرة واحدة تحت `shared/` منفصلًا.
- يحافظ على الملفات المخفية والمتداخلة والنصية والثنائية والملفات الأصلية بايتًا ببايت.
- يرجع خريطة صلاحيات التنفيذ من بيانات ZIP Unix عند توفرها؛ إذا كانت معلومات المصدر صفرية/غير معروفة تبقى `null` بدل استنتاجها من صلاحيات ملف staging.
- يرجع مسارات الروابط الرمزية المتخطاة وأسبابها.

في `SkillsService` تُحفظ الموارد المشتركة في `skill-import-metadata/repositories/<setId>/shared/` مع `bundle.json`. تتضمن تقارير المهارات `sharedResources` مرجعًا صريحًا `read_only_reference` و`runtimeAccessEnabled:false`. لا تُنسخ الموارد المشتركة عشوائيًا إلى Skill مجاورة ولا تُركّب في PRoot. حذف Skill لا يحذف مجموعة مشتركة قد تستخدمها Skills أخرى.

### 3.3 skills.sh والفجوة النصية/الثنائية

راجعت مرجع API الرسمي الحالي: تفصيل Skill يعيد `files` كقائمة `{path, contents}`، حيث `contents` هو النص الكامل للملف، ويمكن أن تكون `files` نفسها `null` عندما لا توجد snapshot. لا يوثق العقد نقلًا ثنائيًا عامًا. لذلك لا يُعامل وصول قائمة الملفات النصية على أنه ضمان لاكتمال الأصول. <https://www.skills.sh/docs/api>

تغيّر `SkillsShAdapter` بحيث يسجل مسارات الملفات التي تفتقد نصًا، واللقطات الغائبة والملاحظات بدل الرفض الصامت أو اعتبار الملف موجودًا. ويحاول مستورد `skills.sh` استخدام GitHub repository ZIP أولًا لحفظ الأصول الكاملة والملفات المشتركة. عند فشل ذلك، يمكنه الرجوع إلى snapshot النصية بوصفها `unverified_text_snapshot` مع تحذير نقص الأصول؛ لا يُعلن اكتمال الاستيراد. أما تحديث skills.sh النصي فيُرفض عندما تكون بياناته غير مكتملة أو سيؤدي إلى إسقاط ملفات Skill سبق حفظها، حمايةً من فقد الأصول.

### 3.4 قراءة الاعتماديات دون تنفيذ

يفهرس المحلل `requirements*.txt` و`pyproject.toml` و`Pipfile`/`Pipfile.lock` و`package.json` وملفات npm/pnpm/yarn/bun lock و`poetry.lock` و`uv.lock` و`Cargo.toml`/`Cargo.lock` و`Gemfile`/`Gemfile.lock` و`go.mod` و`composer.lock`، ضمن حد قراءة 2 MiB لكل manifest. تُحفظ الملفات الأكبر وتُسجل كعناصر لم تُحلل بسبب الحد بدل إسقاطها. يسجل أسماء الاعتماديات وملفات القفل وحقول lifecycle المعروفة في `package.json`، مع بيان صريح أن `installationPerformed:false` و`lifecycleScriptsExecuted:false`.

لا يثبت الاستيراد أي حزمة، ولا يستدعي مدير الحزم، ولا يشغّل أوامر أو نصوصًا أو hooks.

### 3.5 حدود الأمان

تُطبق الحدود في محل فك ZIP والتحليل:

- archive compressed size: حتى 200 MiB.
- عدد مدخلات ZIP: حتى 8192، وعدد الملفات: حتى 8192، وحد اكتشاف مهارات المستودع: 128.
- الملف المفرد: حتى 200 MiB؛ إجمالي الملفات المفكوكة: حتى 500 MiB.
- رفض absolute paths وWindows drive paths و`..` والمسارات غير الآمنة والتكرار وzip-slip.
- لا تُتبع الروابط الرمزية؛ تسجل كعناصر متخطاة في extractor الجديد. لا يتجاوز أي ملف حدود المساحة المؤقتة بعد canonical path validation.
- يحد analyzer عدد الملفات والأحجام ويفحص عدم خروج الملفات العادية من مجلدها الحقيقي.
- لا يتم تشغيل الملفات أو تفسير محتوياتها.

## 4. المحافظة على التوافق والتحديث والتراجع

- لم يتغير نموذج Skill الأساسي أو مخطط قاعدة البيانات. manifests بيانات جانبية منفصلة، لذا يمكن للمهارات القديمة أن تظل صالحة دون تقرير (وتظهر على أنها legacy عند عدم وجود manifest).
- استمر مسار `/youtube` واكتشاف GitHub والاختيار متعدد المهارات وSkill Packs في الخدمات القائمة؛ لا يوجد dispatcher جديد.
- قبل تحديثات GitHub/Skill Pack تؤخذ snapshots؛ يحفظ snapshot أيضًا ملف import manifest الجانبي كي يعيد rollback وصف المصدر السابق. بعد التحديث يعاد حساب manifest مع commit عندما يكون متاحًا.
- التحديثات النصية المحدودة أو التحديثات التي لم تُحدّث الموارد المشتركة تضع `completeness` وnotes صريحة بدل إخفاء الحد. ملفات shared السابقة تبقى pinned snapshot ولا يدّعي النظام مزامنتها.
- عُدلت واجهة الاستيراد لعرض ملخص الشفافية: حالة الاكتمال، أسماء أول 40 ملفًا محفوظًا مع النوع والحجم (والقائمة كاملة في manifest)، الأنواع المكتشفة، ملفات الاعتماديات وأسمائها المعروفة وlifecycle scripts، العناصر المتخطاة وأسبابها، المصدر وبصمة المصدر، مع بيان أن لا scripts أو MCP أو APIs أو تثبيت حزم يبدأ أثناء الاستيراد.

## 5. الملفات المعدلة والجديدة

**مصدر:**
- `lib/core/services/skills/skill_import_manifest.dart` (جديد)
- `lib/core/services/skills/skill_archive.dart`
- `lib/core/services/skills/skills_service.dart`
- `lib/core/services/skills/skills_catalog_adapter.dart`
- `lib/core/services/skills/skill_import_candidate.dart`
- `lib/utils/app_directories.dart`
- `lib/features/workspace/widgets/skills/skill_import.dart`

**اختبارات:**
- `test/core/services/skills/skill_import_manifest_test.dart` (جديد)
- `test/core/services/skills/skill_archive_test.dart`
- `test/core/services/skills/skills_catalog_adapter_test.dart` (جديد)
- `test/core/services/skills/skills_service_test.dart`

**CI والتوثيق:**
- `.github/scripts/run_phase13a_import_tests.sh` (جديد)
- `.github/scripts/audit_android_only.sh`
- `.github/workflows/android-build.yml`
- `phases/README.md`
- `phases/MASTER-DEVELOPMENT-PLAN-AR.md`
- `phases/PHASE-13-SKILLS-WORKSPACE-ARCHITECTURE-AND-IMPLEMENTATION-PLAN.md`
- هذا التقرير `phases/PHASE-13A-IMPLEMENTATION-REPORT.md`
- `build-report/PHASE-13A-LOCAL-DIAGNOSTICS.md`

لم تتغير إصدارات Dependencies أو Gradle/AGP/Kotlin/NDK. بقي `pubspec.yaml` على `1.3.4+84`.

## 6. الاختبارات والتحقق

أُضيف CI step واحد بعد `flutter pub get` لتشغيل أربع ملفات مباشرة الصلة بالاستيراد عبر runner صغير:

1. `skill_import_manifest_test.dart`
2. `skill_archive_test.dart`
3. `skills_catalog_adapter_test.dart`
4. `skills_service_test.dart`

وتغطي الاختبارات: مطابقة SHA-256 لقيمة معروفة ومحتوى ثنائي/PNG وملفات مخفية ومتداخلة، حفظ ملفات المستودع المشتركة، فصل Skills، كشف أنواع القدرات وقراءة manifests، عدم تشغيل scripts أو lifecycle hooks أو MCP، غياب الاستدلال من `tools/` ومن تعريف MCP الفارغ/المشوه، فقد الحقول النصية من skills.sh، رفض absolute/traversal، الروابط الرمزية، حد عدد المدخلات وحد الملف المفرد والإجمالي بعد فك الضغط، والتحديثات وحفظ manifests عبر rollback.

**نتيجة التشغيل المحلي:** اجتاز `bash -n` للسكريبتين، ونجح `audit_android_only.sh` بما يشمل Release-hardening وAndroid-only وARM64/PRoot/localization gates، كما نجح تحليل YAML للـworkflow وفحص Arabic ARB parity (`4733` رسائل، `4614` ترجمة عربية، و`119` fallback إنجليزي). لم يمكن تشغيل Dart analyzer أو Flutter tests أو APK build في بيئة التنفيذ الحالية، لأن Flutter SDK وDart SDK وGradle غير موجودة. المتاح: Java `21.0.12.1` وPython `3.13.5`. لذلك ملفات الاختبار أضيفت إلى CI لكن لم تُنفذ بعد في هذه الجلسة. لا يوجد ادعاء بنجاح CI أو Dart analysis أو APK.

يجب أن يجتاز CI: Android-only audit، الاختبارات الأربعة الجديدة، localization parity/generation الحالية، وبناء Android ARM64 كما هو مضبوط أصلًا. لم تُعد الاختبارات الشاملة أو مجموعة اختبارات المراحل التاريخية إلى CI.

## 7. القيود المتبقية / نقاط تتطلب الانتباه

1. لا تنقل واجهة skills.sh النصية ملفات ثنائية. fallback GitHub ZIP مشروط بكون المصدر مستودع GitHub عامًا أو بصلاحية GitHub القائمة؛ عندما لا يمكن الوصول إليه لا يمكن استرجاع أصول غير موجودة في snapshot، ولذلك يوسم التقرير اللقطة بأنها غير متحققة بدل الاكتمال.
2. GitHub ZIP قد لا يوفر commit metadata داخل ZIP مباشرة؛ يحاول التطبيق حل commit بشكل منفصل، وقد يبقى null إذا تعذر ذلك.
3. تحليل بعض lockfiles نصي/تقريبي ولا يفسر كل قواعد كل ecosystem؛ الملفات الثنائية مثل `bun.lockb` تحفظ وتبصم مع إظهار أن تحليلها لم يتم.
4. روابط ZIP الرمزية لا تُستورد، بل تُسجل كـ skipped. هذا متعمد لتجنب تفسير وجهتها أو اتباعها.
5. تحديثات الموارد المشتركة في مسارات التحديث القديمة ليست مزامنة كاملة دائمًا؛ يحتفظ النظام snapshot السابق ويضع حالة محدودة في التقرير. إعادة تصميم تحديث shared bundles بالكامل ليست ادعاءً ضمن هذا الجزء.
6. كشف القدرات وصفي فقط، لا يمثل اعتمادًا أمنيًا أو موافقة تشغيل. يجب أن يعيد 13B/13D التحقق من المصدر والقدرات والصلاحيات مستقلاً.

## 8. قائمة اختبار الهاتف قبل 13B

- استيراد مستودع GitHub متعدد المهارات يحوي `README` و`LICENSE` وملفات مشتركة خارج مجلدات Skills؛ تحقق من بقاء كل Skill مستقلة ومن ظهور مرجع shared منفصل في تقرير كل Skill.
- استيراد Skill فيها `.py` و`.sh` و`.js` وملفات مخفية وصور/قوالب/ملفات ثنائية متداخلة؛ تحقق من الأعداد والأحجام وبصمة SHA-256 دون تشغيل أي ملف.
- استيراد من skills.sh لمصدر به أصول؛ تحقق من استخدام أرشيف GitHub، ثم اختبر حالة تعذر الأرشيف وتأكد أن النتيجة تظهر غير مكتملة ولا تسقط الملفات بصمت.
- تجربة ZIP يحتوي `../` أو مسارًا مطلقًا أو symlink أو عدد/حجمًا يتجاوز الحد؛ يجب رفضه أو تسجيل العنصر المتخطى دون كتابة خارج مجلد staging.
- راجع manifests الاعتماديات وتأكد من عدم ظهور تثبيت تلقائي أو postinstall أو تشغيل scripts أو بدء MCP/API.
- حدّث Skill ضمن Skill Pack ثم نفذ rollback؛ تحقق من بقاء ملفات المهارة وتقرير المصدر وبصمة النسخة المرتجعة، ثم اختبر اختصار `/youtube` كما كان قبل المرحلة.

## 9. بوابات القبول

لا تُعلن 13A مقبولة حتى تتحقق جميع الآتي: نجاح الأربع مجموعات المركزة في CI، نجاح Android ARM64 Release، تثبيت APK وتجربة سيناريوهات الهاتف أعلاه، وعدم وجود فقد صامت أو تنفيذ أثناء الاستيراد. تظل 13B و13C و13D غير منفذة في هذا التسليم.
