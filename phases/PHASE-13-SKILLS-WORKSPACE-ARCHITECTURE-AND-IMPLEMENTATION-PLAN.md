# PHASE 13 — Skills & Workspace/Environment Architecture and Implementation Plan

**الحالة المرجعية — 27 نوفمبر 2026 بعد CI #208:** هذه الخطة تضم checkpoints تاريخية ومراحل متابعة أضيفت لاحقاً. تقارير 13A–13D الأصلية لا تزال تتطلب مراجعة قبول مستقلة؛ لا يمنحها CI #208 قبولاً رجعياً. فجوة Skill-owned MCP التي كانت مفتوحة في 13B عولجت لاحقاً عبر 13Q، ثم اجتازت دورة STDIO الفعلية والعدائية بوابة Phase 14D في CI #204. اجتازت Phase 13P Android Emulator E2E في CI #208. اجتازت 13Q.1–13Q.5 Backend/lifecycle في CI #199، مع تأكيد real STDIO في #204 و#208. اجتازت اختبارات Environment lifecycle لـ13R في CI #208، لكن اختبار الهاتف الفعلي لا يزال مطلوباً.

**حدود القبول المتبقية:** الـworkflow الحالي لا يشغّل جميع runners التاريخية لـ13E–13O ولا كامل Flutter root unit/widget suite. لا تعتبر التحليل الساكن أو بناء APK بديلاً عن تلك الاختبارات. PRoot Linux userland وليس Kernel Sandbox؛ RootFS مشترك وقابل للكتابة، والشبكة غير مقيدة بالكامل. نجاح Android Emulator لا يثبت Force Stop على هاتف المستخدم.

**خط الأساس الذي تمت مراجعته:** `KELIVO 1.3.4+84` من نسخة المشروع `KELIVO-BUILD-FIX.zip`.

**تاريخ المراجعة:** 2026-11-10.

**سجل CI تاريخي — 2026-11-11:** التشغيل `42911673756` اجتاز تجهيز GTK/GLib ثم أوقفته بوابة Dart الشاملة بسبب 54 خطأ ترجمة/صياغة في خمس ملفات من خدمات 13B/13C/13D والاختبارات؛ لم يبدأ أي اختبار مرحلة. أُعد إصلاح مصدر جديد يتضمن استيراد path المفقود، escaping لمعامل shell substitution، إصلاح `SkillExecutor` ومساراته، نقل مساعدات الاختبار قبل استعمالها، وإضافة import مفقود لاختبار UI. كما صُححت RegExp flags غير المدعومة في Dart، وأضيفت اختبارات انحدار، وأُصلحت catch paths غير المتزامنة. الفحوصات المحلية المتاحة اجتازت، لكن Dart/Flutter وAPK لم تُشغّل محليًا؛ الإصلاح ينتظر CI جديدًا، وجميع بوابات قبول 13A–13D ما زالت مفتوحة. انظر `../build-report/PHASE-13-ALL-PHASES-ANALYZER-FAILURE-AND-REPAIR-2.md`.


## الملخص التنفيذي بالعربية

أكدت مراجعة المصدر أن KELIVO لا يقتصر في كل مساراته على تنزيل `SKILL.md`: مستورد GitHub ZIP ومجلدات المهارات المحلية يستطيعان حفظ شجرة الملفات الداعمة، بينما مسار `skills.sh` يعتمد على `contents` النصية وقد لا يستطيع نقل الأصول الثنائية. هذا توصيف فجوات المصدر وقت التدقيق الأصلي في 10 نوفمبر 2026؛ عولجت لاحقاً أجزاء من دورة تنفيذ Skills وSkill-owned MCP في 13P/13Q/14D، بينما تبقى حدود القبول العملية المذكورة في التقارير ذات الصلة.

لذلك تقسم المرحلة 13 إلى أربع مراحل متتابعة، مع منع تنفيذ سكربتات الطرف الثالث أثناء الاستيراد:

| المرحلة | النطاق | ما لا يجوز افتراضه |
|---|---|---|
| **13A — Universal Skill Import & Capability Discovery** | استيراد شجرة المهارة كاملة، اكتشاف أنواع القدرات، حفظ manifest وبصمات المصدر، ودعم ملفات المستودع المشتركة | لا تشغّل سكربتات ولا تثبّت تبعيات ولا تبدأ خوادم MCP |
| **13B — Skill Executor & Tool Dispatch** | منفّذ معتمد لسكربتات محددة، توجيه الأدوات، إدارة الموافقات والمدخلات والمخرجات | لا تعتبر مجلد `tools/` خادم MCP تلقائيًا |
| **13C — Workspace & Environment Runtime Integration** | ربط PRoot وRuntime Profiles وPython/Node وFFmpeg/FFprobe وسائر الأدوات الاختيارية | لا تدّعِ وجود عدة RootFS متزامنة أو إصدارات مفسرات متعددة ما لم تنفذ فعليًا |
| **13D — Secure Execution & Acceptance** | عزل ملفات التشغيل والصلاحيات والأسرار والعمليات الطويلة، والتحقق على الجهاز | لا تعتبر PRoot حدًا أمنيًا مكافئًا للحاويات أو العزل على مستوى النواة |

## Phase 13A — نطاق التنفيذ الأصلي (تم إعداد المصدر؛ القبول معلّق)

كان هذا هو نطاق التسليم الأولي قبل بدء التنفيذ. القيود أدناه تخص الاستيراد نفسه وتظل سارية دائمًا؛ تشغيل السكربتات لا يحدث إلا من بوابة 13B المنفصلة وبموافقة صريحة. تشمل 13A:

1. تعريف عقد Capability Descriptor مستقل عن `SKILL.md` يصنف المحتوى إلى: instruction، local script، CLI/binary، MCP server، HTTP/API connector، native KELIVO tool، وworkflow.
2. حفظ شجرة الملفات المتداخلة كاملةً، بما فيها الملفات النصية والثنائية والمخفية وملفات الإعداد والموارد، مع سجل لكل مسار نسبي وحجم ونوع/امتداد وبصمة SHA-256 والمصدر/commit/ref، وبتّ التنفيذ عند توفره بصورة موثوقة.
3. دعم مهارات المستودعات متعددة المجلدات والملفات المشتركة على مستوى المستودع، مع الحفاظ على حدود كل Skill وعدم نسخ الموارد المشتركة عشوائيًا أو إسقاطها بصمت.
4. تحسين `skills.sh` adapter: استخدام API النصي عندما يكون كافيًا، والرجوع إلى مصدر GitHub/أرشيف موثوق عندما يتطلب المحتوى ملفات ثنائية أو بيانات لا ينقلها `contents`، أو عرض تقرير صريح بما لا يمكن استيراده.
5. فحص manifests الشائعة مثل `requirements.txt`, `pyproject.toml`, `package.json`, lockfiles وملفات إعداد الأدوات **قراءة فقط**؛ لا يحدث تثبيت أو lifecycle scripts أثناء الاستيراد.
6. التحقق من archive traversal وabsolute paths وsymlink escapes والملفات المفرطة الحجم وعدد الملفات وحدود فك الضغط، مع عدم تنفيذ أي محتوى من المستودع.
7. إنتاج تقرير استيراد شفاف يوضح الملفات المحفوظة والمتجاهلة وسبب التجاهل، ومصدر النسخة وبصمتها، وأي متطلبات مكتشفة.
8. تحديث الوثائق وسجل المرحلة واختبارات الاستيراد المركزة، مع المحافظة على CI خفيف وعدم إعادة الاختبارات الشاملة التي سبق استبعادها دون مبرر.

### بوابات قبول Phase 13A

- استيراد مستودع يحوي عدة Skills وملفات `scripts/` و`tools/` و`references/` و`assets/` وملفات ثنائية، ثم إثبات أن كل مسار محفوظ وبصمته صحيحة.
- الحفاظ على الملفات المشتركة خارج مجلدات `SKILL.md` وفق عقد صريح، لا عن طريق نسخ عشوائي.
- دعم `skills.sh` حيث تسمح واجهته، مع مسار fallback موثق للأصول الثنائية، وعدم الإبلاغ عن اكتمال الاستيراد عند فقد ملفات.
- رفض المسارات الخبيثة والروابط الرمزية الهاربة والأرشيفات المخالفة للحدود.
- قراءة manifests دون تثبيت حزم أو تشغيل أوامر أو سكربتات.
- عدم تغيير سلوك Skill composition أو تشغيل سكربتات المهارات في 13A؛ التنفيذ الحقيقي يبدأ في 13B بعد مراجعة مستقلة للأمان.
- نجاح اختبارات Dart المركزة ذات الصلة، ونجاح Android ARM64 Release عبر GitHub Actions قبل اعتبار 13A جاهزة للتسليم.

### ما يجب تأجيله صراحةً

لا تبدأ `SkillExecutor` أو تشغيل Bash/Python/Node أو `MCP tools/call` التلقائي في هذه المرحلة. لا تربط مجلد `/skills` القابل للكتابة بعمليات طرف ثالث، ولا تثبّت Ubuntu أو FFmpeg تلقائيًا. هذه موضوعات المراحل 13B–13D، ويجب أن تُبنى فوق manifest الاستيراد والتحقق الذي تنجزه 13A.

## قواعد الاستمرار

- اعتبر شجرة `phases/` هي سجل الحقيقة للمراحل. افحص README والخطة الرئيسية وكل مواصفات وتقارير Phase 0–12 قبل تعديل الكود.
- قارن الوثائق بالمصدر الفعلي؛ لا تفترض أن تقرير التنفيذ يصف النسخة الحالية بدقة دون التحقق.
- نفّذ المرحلة النشطة فقط. أُجيز إعداد checkpoints المصدر لـ13B و13C ثم 13D بناءً على طلب المستخدم المباشر، رغم بقاء بوابات القبول السابقة مفتوحة. هذا إذن لإعداد المصدر فقط: لا تُعلن قبولًا بأثر رجعي، ولا تبدأ أي مرحلة لاحقة بعد 13D قبل تشغيل CI وتجارب الهاتف وإغلاق مراجعة الأمان للمراحل 13A–13D.
- حافظ على اسم جذر الأرشيف `KELIVO/`، ولا تفقد الملفات أو تغيّر مساراتها الأصلية.
- حافظ على إصدار البناء الحالي `1.3.4+84` كخط أساس ما لم يوجد سبب موثق لتغييره.
- لا تغيّر إصدارات المكتبات أو Gradle/AGP/Kotlin/NDK لمجرد التنظيف؛ كل تغيير يجب أن يكون مرتبطًا بمتطلب واضح واختبار.
- لا تعِد الاختبارات الموسعة التي أزيلت من CI؛ أضف فقط اختبارات مركزة ضرورية للمرحلة الجديدة مع الحفاظ على فحوص البناء الأساسية.
- لا تدّعِ نجاح `dart analyze` أو Flutter tests أو APK إلا إذا شُغلت فعليًا. سجّل بدقة ما اجتاز وما لم يُنفّذ.
- بعد التنفيذ، أضف مواصفة 13A وتقرير التنفيذ والقيود ونتائج CI إلى `phases/`، وحدّث README والخطة الرئيسية، ثم سلّم ZIP كاملًا جذره `KELIVO/`.

---

## Full source audit (preserved from the architecture review)

# KELIVO — Skills & Workspace/Environment Architecture Audit

**Audit scope:** `/mnt/data/KELIVO-BUILD-FIX.zip` (archive root: `KELIVO/`)
**Audit date:** 2026-11-10
**Mode:** Source inspection only. No source files were changed in this audit.
**Important:** This report describes the supplied ZIP snapshot. Any commits pushed to GitHub after that archive was created are not included.

---

## Executive summary

The project already contains several real foundations:

- Agent Skill import from GitHub ZIPs, local folders, local ZIPs and the GitHub-backed `skills.sh` catalog.
- Preservation of scripts, references, assets and other files for GitHub ZIP and local-folder imports.
- Multi-Skill selection/composition planning with dependencies, conflicts, artifact contracts and context budgeting.
- A general Workspace shell/file tool system.
- An Android PRoot runtime, environment installer, package manager, Python/Node Runtime Profiles and a separate MCP client/server integration.

However, these pieces are not yet connected into an end-to-end Skill execution system. The current `skill_compose` tool is explicitly a **read-only planner**. It selects Skills and returns their `SKILL.md` instructions; it does not dispatch a Skill's scripts, provision its dependencies, run a tool manifest, move artifacts between stages or verify an output file.

This explains the apparent contradiction seen in the app: KELIVO can discover and select `yt-script`, `yt-edit`, `yt-package`, and similar Skills, yet selection alone does not cause their scripts or tools to run. A Skill being installed, enabled, selected, and executable are four separate states; the present model primarily represents the first three.

## 1. What is actually imported today?

### 1.1 GitHub ZIP/repository and local-folder imports

The source does **not** limit all Skill imports to Markdown:

- `lib/core/services/skills/skills_service.dart:188-233` — a single `.md` file is imported as instruction-only content; a `.zip` is sent to the archive importer.
- `lib/core/services/skills/skills_service.dart:237-338` — local folder import walks the directory recursively, copies files as bytes, skips symlinks, and enforces file-count and size limits.
- `lib/core/services/skills/skills_service.dart:501-675` — GitHub repository import discovers Skills by `SKILL.md`, then installs selected folders.
- `lib/core/services/skills/skill_archive.dart:205-355` — multi-Skill ZIP extraction preserves arbitrary files under each Skill root, not just `.md`; it skips symlinks and validates archive paths.

Therefore a GitHub/local-folder Skill can retain, for example, `scripts/*.py`, `scripts/*.sh`, `references/*`, `assets/*`, JSON/YAML files, templates, and binary files, subject to limits and path-safety rules.

### 1.2 Important multi-Skill repository limitation

`skill_archive.dart` assigns an archive file to the deepest `SKILL.md` root that contains it. Files outside every discovered Skill directory are skipped. A repository-level shared helper such as `shared/tool.py`, root `package.json`, or a common `tools/` folder will not automatically be copied into each selected Skill. This can break Skills whose instructions refer to shared repository files outside their own directory.

Recommended import model: keep each Skill self-contained where possible; otherwise import an explicit repository-level dependency bundle and record a safe, version-pinned relationship instead of silently dropping it.

### 1.3 `skills.sh` catalog limitation

`lib/core/services/skills/skills_catalog_adapter.dart:47-158` resolves a catalog entry using the skills.sh API. Each returned file must have a `path` and a string `contents`; KELIVO UTF-8 encodes that string. The official endpoint describes its file list as full text contents of the Skill folder. This path can retain additional text files and script source, but it cannot faithfully transport arbitrary binary assets unless the API supplies a separate binary/base64 representation. The adapter also filters search results to `sourceType == github`; well-known sources are not yet supported by a dedicated adapter.

### 1.4 What is not a Skill import

- A lone `.md` file is instruction-only by design.
- An MCP server configuration is not equivalent to a directory named `tools/` inside a Skill.
- Claude/Cursor/Codex/other host-specific plugin manifests may be preserved and compatibility-reported, but preservation does not mean KELIVO interprets or executes those host-specific plugins.

The Agent Skills format itself defines a Skill as a folder with required `SKILL.md` and optional `scripts/`, `references/`, `assets/`, and other supporting files. Scripts are executable code only when the host agent implements an execution path for them; their presence does not automatically execute them. See the official specification: https://github.com/agentskills/agentskills/blob/main/docs/specification.mdx

## 2. The actual Skill execution gap

### 2.1 Skill model is metadata-oriented

`lib/core/services/skills/skill.dart` stores the record, display name, description, directory and `SKILL.md` path. It does not currently expose a normalized executable manifest, entry-point list, interpreter requirements, tool bindings, input/output schemas or per-script permissions.

### 2.2 Composition is planning, not execution

- `lib/core/services/skills/skill_composition_service.dart:31-79` reads each candidate's `SKILL.md`, builds planner candidates and returns JSON for the plan.
- `lib/core/services/extensions/skill_composition_tools.dart:7-14` explicitly describes `skill_compose` as a planning tool that never executes scripts or installs dependencies.
- `lib/core/services/skills/skills_prompt.dart:23-27` instructs the model to read selected `SKILL.md` instructions progressively and explicitly says scripts are files, not commands to run automatically.
- `phases/PHASE-04-MULTI-SKILL-COMPOSITION-ENGINE.md` and `phases/PHASE-04-IMPLEMENTATION-REPORT.md` list the runtime executor, actual artifact handoff, parallel execution and Skill-script execution as deferred acceptance gaps.

This is the main architecture gap. KELIVO needs a `SkillExecutor` and an orchestrator that can turn a ready plan into approved, deterministic actions.

### 2.3 Context pressure

`SkillCompositionService.compose()` loads up to 64 candidate `SKILL.md` files (up to 64,000 characters each) before the planner selects a smaller subset. The planner then applies its token budget, but the candidate scan itself can still be expensive. The screenshot's approximately 5,851/6,000-token plan indicates that selected instructions are also close to the configured context ceiling.

Recommendation: index only name/description/frontmatter/digest first; rank candidates; load full `SKILL.md` only for selected candidates; load references on demand; never load scripts/assets into prompt context unless a tool specifically needs to inspect them.

## 3. Skill scripts, native tools and MCP are three different execution types

### A. Skill-local scripts

Examples: `scripts/analyze.py`, `scripts/render.sh`, `scripts/make_thumbnail.py`.

Required KELIVO path: resolve a declared relative path inside the installed Skill, validate it, resolve its runtime/profile and exact interpreter, request permission, stage required inputs, execute through `WorkspaceRuntime`, capture stdout/stderr/exit code, verify declared outputs, and return structured results to the model.

### B. Native KELIVO tools / CLI capabilities

Examples: `shell`, `read_file`, `write_file`, `package_manager`, video-engine/provider operations. These are registered tools with KELIVO-owned schemas and handlers. A Skill may describe when to use them, but the Skill folder does not create a new native KELIVO tool merely by containing a `tools/` directory.

### C. MCP servers

KELIVO already has a separate MCP subsystem:

- `lib/core/providers/mcp_provider.dart` handles server configuration, connection, `tools/list` and `tools/call`.
- `lib/core/services/mcp/workspace_stdio_transport.dart` can start an MCP stdio process through `WorkspaceStdioRuntime` using raw stdin/stdout pipes.
- `lib/core/services/mcp/mcp_tool_service.dart` routes exposed MCP tools to selected servers.

This is real MCP infrastructure, but it is configured through MCP server records and conversation/assistant server selections. It is not automatically discovered or installed from a Skill's arbitrary `tools/` folder. A future Skill adapter should be able to declare an MCP dependency, validate the server config and executable, ask for approval, register the server, discover its tools and link them to the Skill without confusing the server's tool calls with shell scripts.

## 4. Workspace & environment: complete current layout

### 4.1 User-facing screens

The `Workspace & environment` area is spread across:

- `pages/workspace_settings_page.dart` — mobile settings hub, environment shortcut, video-provider credentials and Workspaces area. Desktop routes directly to Workspaces.
- `pages/environment_page.dart`, mobile/desktop layouts and `widgets/environment/environment_pane.dart` — environment status, install/repair/update/reset, disk usage, mirrors, dependency presets, environment variables, PRoot options and rootfs browsing.
- `pages/environment_download_page.dart` — distro/version/source selection and custom/local rootfs archive selection.
- `pages/mirror_page.dart` — apt/apk, pip and npm mirror settings/speed checks.
- `pages/environment_variables_page.dart` — guest environment variables and privacy-related configuration.
- `pages/proot_options_page.dart` — PRoot shell and extra arguments.
- `pages/external_mounts_page.dart` — selected host directories exposed into the guest.
- `pages/rootfs_browser_page.dart` — browse the active Linux root filesystem.
- `pages/workspaces_page.dart`, workspace settings/files/tools panes — project/workspace binding, files, permissions and enabled tools.
- `features/workspace/terminal/*` — terminal/PTY presentation and process interaction.

### 4.2 What the environment dependency presets install

`lib/core/services/sandbox/environment_dependencies.dart:11-40` currently defines only six Environment presets:

- Python (`python3`, pip, venv/virtualenv)
- Node.js (`nodejs`, `npm`)
- Git
- SSH/OpenSSH
- Network tools (`curl`, `wget`)
- Archive tools (`zip`, `unzip`)

There is no built-in multimedia preset for FFmpeg/FFprobe, ImageMagick, or yt-dlp in this Environment presets enum/UI. KELIVO does have a separate `package_manager` tool for apt/apk, pip/uv and npm/pnpm/yarn/bun, and it can request approved package changes. OS packages modify the shared PRoot system; Python/Node package installs can be directed into scoped roots. Cargo, RubyGems and arbitrary Git/URL install sources are not part of the listed supported package managers.

For video-editing Skills, the Environment page should have a clear optional **Media tools** preset (at minimum FFmpeg + FFprobe), with optional ImageMagick and yt-dlp support, version checks and explicit install approval. This is a UX/setup improvement, not a substitute for implementing the SkillExecutor.

### 4.3 PRoot state

On Android, `MobileWorkspaceStack._android()` builds one `EnvironmentInstaller` and one `AndroidProotRuntime` using the same environment directory. The active rootfs path is `environmentDir/rootfs` (`environment_installer.dart:119`). PRoot is not installed automatically with the APK; the user must install the environment from the Environment screen. Before that, shell execution can report `environment_not_installed`.

Installing PRoot only supplies a Linux userland and shell/runtime environment. It does not automatically install Python, Node, FFmpeg, yt-dlp or a Skill's Python/Node packages; those are separate dependency actions.

### 4.4 Multiple distro/version choices are not multiple active environments

The current catalog contains eight rootfs images in this source snapshot:

- Ubuntu 24.04.4, 24.04.3, 22.04.5
- Alpine 3.24.1, 3.23.5, 3.22.5
- Debian 13, 12

`RootfsCatalog.defaultImage` is pinned to Ubuntu 24.04.3 even though Ubuntu 24.04.4 is listed. This is an explicit default pin in the source, not an automatic latest selection.

The installer uses one active `rootfs` directory. Reinstalling/changing the selected distribution or version replaces that active directory and temporarily retains a `previous-rootfs` for rollback/recovery; it does not keep Ubuntu, Alpine and Debian all installed side-by-side as independently selectable live environments.

### 4.5 Workspaces vs Runtime Profiles vs operating-system instances

These should not be conflated:

- **Workspaces:** multiple project folders/settings and default Skill/tool selections. They still use the shared device PRoot runtime.
- **Runtime Profiles:** logical package/output/temp scopes. Python profiles create venvs; Node profiles create separate package roots. They use the same base Python and Node executables installed in the shared PRoot.
- **Rootfs:** one active Linux root filesystem in the current Android implementation.
- **Interpreter versions:** the current source does not manage multiple Python or Node interpreter versions. The Phase 6 report explicitly defers multiple interpreter versions.
- **Extension/task profile execution:** profile records can be created/provisioned for these scopes under PRoot, but `RuntimeProfileService.resolveExecution()` currently accepts only `project` scope for Workspace shell execution. Direct Skill/task execution is not wired yet.

There is no dedicated, comprehensive Runtime Profile manager page under Workspace in this snapshot; the profile model/services are principally exposed through conversation tools and package manager/runtime tooling.

## 5. High-priority safety and isolation finding

The Skills host directory is exposed to PRoot at `/skills` by `WorkspacePaths.mounts` (`workspace_paths.dart:88-96`), but the mount is created with the default `readOnly: false`. File-tool APIs separately reject writes to the Skills zone, and skills-only mode exposes only `read_file`; however that protection does not constrain arbitrary shell programs.

The Android native layer confirms the limitation:

- `ProotCommand.kt` documents that PRoot bind mappings are writable and arbitrary shell programs are not isolated by the file-tool policy.
- `WorkspacePlugin.kt` calls `MountWriteGuards.install(rootfs, externalMounts)` only for external mounts. `/skills` is not in that list.
- `MountWriteGuards.kt` itself describes its wrappers as best-effort guards for common commands, not a sandbox; redirection, interpreters, absolute paths and other programs can bypass them.

Do **not** enable arbitrary third-party Skill scripts against the installed `/skills` host mount until this is addressed. PRoot is a user-space chroot/bind tool, not a strong container boundary. The immediate design should avoid exposing the live installed Skills directory to a script process; use immutable source snapshots or disposable per-run staged copies and narrow writable output mounts, and still treat the shared rootfs as a shared trust boundary. Untrusted Skill scripts need explicit approval and provenance/hash review. Do not claim a copy-only strategy provides a full OS sandbox.

## 6. Why the screenshots can show selected Skills but no actual execution

The UI can render a successful Skill composition plan after `skill_compose`; that means selection and instruction planning succeeded. It does not mean an executable file was launched.

The screenshot's plain-text JSON-like `"arguments": {...}` is not visibly represented as a KELIVO tool-call card. From the screenshot alone we cannot conclusively identify whether the model emitted ordinary text, a malformed tool protocol response, or a Skill instruction asking for a structured payload. The stream tool loop executes only decoded structured function/tool calls. A literal JSON snippet in message content will not execute. A focused trace with the selected model and raw response/tool-call events is required to determine which layer is at fault.

Recommended validation: first test a built-in deterministic tool call (for example `read_file` or a benign `package_manager` plan), then an MCP `tools/list` + `tools/call`, then one controlled Skill script. Capture provider request capability flags, response `finish_reason`, decoded tool-call name/ID/arguments, dispatcher result, process exit code and output verification. Do not infer successful execution from model narration.

## 7. Recommended implementation sequence (proposed next phase)

### Phase 13A — Import and capability discovery

1. Define an extension capability descriptor independent of `SKILL.md`: instruction-only, local script, CLI adapter, MCP server, HTTP/API connector, native tool binding, workflow.
2. Keep the complete Skill folder tree and a manifest of every relative path, byte size, MIME/type, executable bit where available, digest and source commit/ref.
3. Extend `skills.sh` handling or add a GitHub ZIP fallback for binary assets; report exactly what was omitted rather than silently claiming a complete import.
4. Preserve or explicitly package repository-level shared dependencies in multi-Skill repositories.
5. Parse common dependency declarations (requirements.txt, pyproject.toml, package.json, lockfiles) in read-only mode; never execute package scripts during import.

### Phase 13B — SkillExecutor and tool dispatch

1. Add a `SkillExecutor` that receives a ready composition plan, selected Skill IDs, allowed entry points, inputs and a Runtime Profile.
2. Support exact script types initially: Python, Bash and Node.js. Treat unsupported extensions as inspectable data, not executable commands.
3. Validate real paths under the selected Skill snapshot; reject path traversal, symlinks, undeclared executable paths and repository scripts outside approved roots.
4. Require per-Skill permission review and per-run approval for shell, network, package installation, workspace writes and external services.
5. Return structured execution records: tool/script, arguments, status, exit code, stdout/stderr, output file list, duration, runtime profile and digest.
6. Verify declared outputs exist and match expected type/size before the next DAG stage consumes them.
7. Add explicit adapters for MCP servers rather than auto-running an arbitrary `tools/` directory.

### Phase 13C — Workspace & Environment integration

1. Add a Media tools preset with FFmpeg/FFprobe and checks for other optional video tools.
2. Expose Runtime Profile selection in Workspace UI (project/extension/task where each scope is genuinely supported).
3. Distinguish shared OS packages from per-project/per-Skill Python and Node packages.
4. Add optional multi-rootfs support only if the user truly needs simultaneous Ubuntu/Alpine/Debian instances; the current selection UI is a version switcher, not a multi-instance manager.
5. Add interpreter version management (e.g. per-profile Python/Node version installations) as a separate, explicit feature; do not imply current Runtime Profiles already do this.
6. Add disk budget, CPU/thermal, timeout, output-size and cancellation controls for long FFmpeg/video jobs; report best-effort limits accurately on Android/PRoot.

**Phase 13C source checkpoint (2026-11-10; not accepted):** The Android Workspace settings route now exposes project-owned Runtime Profiles (create/edit/remove, workspace default, active-process view/cancel and resource settings). The media preset installs only the user-requested FFmpeg package and probes both FFmpeg/FFprobe version strings plus optional yt-dlp, MediaInfo, ffmpegthumbnailer and ImageMagick command names; optional tools are detect-only. apt/apk remains scoped to the single active shared rootfs, while pip/npm-style dependencies retain per-scope/profile roots. Resource controls include wall-clock timeout, best-effort `RLIMIT_CPU`, process/virtual-memory/file limits, post-run TMP/output-directory checks, a post-render primary-file size check, run cancellation and Android resource preflight sampling. They are not kernel quotas or continuous thermal enforcement. No simultaneous multi-rootfs or per-profile interpreter-version manager was added; current profiles share the active rootfs's Python/Node interpreter binaries. The UI currently exposes project scope only; Skill/extension profiles remain owner-managed by their separate flow and task profile selection is not exposed. Focused tests are registered in CI but were not run locally because Flutter/Dart/Gradle are unavailable. See `PHASE-13C-IMPLEMENTATION-REPORT.md`.

### Phase 13D — Security and acceptance

1. Remove writable access from the live installed Skills tree before launching third-party code. PRoot's bind behavior is not a security sandbox; use a carefully bounded staged execution model and state the remaining trust limitations.
2. Ensure credentials are not inherited by Skill processes unless explicitly granted; redact command/environment output.
3. Run tests for archive traversal, oversized files, binary preservation, nested Skills/shared files, path validation, script exit codes, cancellations, timeout, missing dependencies, output verification and permission denial.
4. Phone acceptance tests: install a script-bearing Skill; inspect its full tree; execute a harmless script; install FFmpeg after approval; trim a short local test clip; verify output playable; interrupt/retry; uninstall the Skill without losing project outputs.

**Phase 13D source checkpoint (2026-11-10; not accepted):** `skill_execute` now forces a new manual approval for every invocation even in Full Access mode and adds `runtime.rootfs.write` as a critical permission in every review. Its approval card explicitly warns in Arabic that the active PRoot RootFS is shared/writable, that network access is unrestricted, and that PRoot is not a kernel sandbox; the card does not offer a Full Access shortcut. `resolveSkillExecution()` omits user-defined Runtime Profile environment variables, and the guest process receives only a small interpreter/bootstrap allowlist. Captured stdout/stderr is scrubbed for known argv values, sensitive input-key values, common credential assignment names and Bearer/provider token patterns; raw argv is represented only by count and digest in reports. Pending approval data contains execution identity and counts only, not task text, raw argv, input values or file paths. The pre-existing per-run source snapshot and single staging bind remain the only mounted host data; the live Skills tree, Workspace root, chat and external mounts are not attached. This still does **not** isolate the shared PRoot RootFS or restrict network access. No read-only/disposable RootFS, kernel sandbox, MCP adapter, or automatic secret-grant mechanism is included. A focused CI runner is registered but its Flutter tests, ARM64 APK build and phone validation have not run locally; see `PHASE-13D-IMPLEMENTATION-REPORT.md` and `../build-report/PHASE-13D-LOCAL-DIAGNOSTICS.md`.

**Phase ordering note:** The user directly requested source checkpoints for 13B, 13C and 13D while previous acceptance gates remained open, and later explicitly authorized the Phase 13E environment/approval/storage hardening follow-up. These are source-preparation authorizations only; they do not accept 13A–13D. Phase 13E adds a read-only environment inventory and real-session probe, update availability checks, mandatory manual approval for assistant mutations, and an SAF export boundary. All earlier and new acceptance gates remain open until CI, ARM64 build, phone tests and security review pass. Do not describe PRoot as a kernel-level sandbox. See `PHASE-13E-ENVIRONMENT-APPROVAL-AND-STORAGE-HARDENING.md`.

## 8. Files reviewed (principal set)

- `phases/README.md`, `phases/PHASE-03-IMPLEMENTATION-REPORT.md`
- `phases/PHASE-04-MULTI-SKILL-COMPOSITION-ENGINE.md`, `phases/PHASE-04-IMPLEMENTATION-REPORT.md`
- `phases/PHASE-05-UNIVERSAL-DEPENDENCY-PACKAGE-MANAGER.md`, `phases/PHASE-05-IMPLEMENTATION-REPORT.md`
- `phases/PHASE-06-RUNTIME-PROFILES-AND-EXECUTION-ISOLATION.md`, `phases/PHASE-06-IMPLEMENTATION-REPORT.md`
- `lib/core/services/skills/*`
- `lib/core/services/extensions/*`
- `lib/core/services/packages/*`
- `lib/core/services/workspace/*`
- `lib/core/services/runtime_profiles/*`
- `lib/core/services/sandbox/*`
- `lib/core/services/mcp/*`, `lib/core/providers/mcp_provider.dart`
- `lib/core/providers/environment_provider.dart`
- `lib/core/models/environment_state.dart`, `lib/core/models/workspace.dart`
- `lib/features/workspace/pages/*`, `lib/features/workspace/widgets/environment/*`, `lib/features/workspace/widgets/skills/*`
- `android/app/src/main/kotlin/com/psyche/kelivo/workspace/ProotCommand.kt`
- `android/app/src/main/kotlin/com/psyche/kelivo/workspace/WorkspacePlugin.kt`
- `android/app/src/main/kotlin/com/psyche/kelivo/workspace/MountWriteGuards.kt`

## External format/runtime references

- Agent Skills specification: https://github.com/agentskills/agentskills/blob/main/docs/specification.mdx
- skills.sh API: https://www.skills.sh/docs/api
- OpenAI Build Skills guide: https://learn.chatgpt.com/docs/build-skills
- PRoot manual: https://github.com/termux/proot/blob/master/doc/proot/man.1

---

## Audit conclusion

KELIVO is not limited to importing `.md` in every source path. GitHub ZIP and local-folder paths preserve the supporting file tree. The real missing capability is a secure, typed execution bridge from Skill composition to the Workspace runtime, package manager, MCP server manager and artifact store. `skills.sh` has a narrower text-file transport contract, and arbitrary repository-level shared files need explicit treatment.

PRoot should be enabled for Linux-dependent Skill workflows, but merely installing Ubuntu is insufficient. KELIVO must install/probe the required tools, bind the correct Workspace/Runtime Profile, dispatch the declared script or MCP tool, collect and validate outputs, and keep untrusted Skill code away from the live Skills host directory and sensitive host mounts.

## Follow-up record — PHASE13K.3 requirement evidence logic

The later CI run `43774290731` showed that the Phase 13J analyzer's no-evidence warning was suppressed by an `instruction_only` capability record. The analyzer now emits the conservative warning whenever no actual command, package, credential, or external-service requirement evidence was found; instruction-only metadata is not dependency evidence, while a declared external service is. A focused positive regression covers external-service-only requirements. See `PHASE-13K.3-REQUIREMENT-EVIDENCE-LOGIC-FIX-AR.md`. Flutter tests and ARM64 APK acceptance remain pending a fresh CI run.


## Follow-up record — PHASE13K.4 prompt policy test synchronization

CI run `43780091708` passed Phase 13E–13I and Phase 13J preflight, then failed one literal-string assertion in `skills_prompt_test.dart`: the test expected older wording although the production prompt already required saving and verifying Skill files before claiming installation. The assertion now checks the current complete policy sentence, and Phase 13J preflight verifies that the prompt and test remain aligned. No production behavior or safety restriction was relaxed. See `PHASE-13K.4-PROMPT-POLICY-TEST-SYNC-AR.md`.


## PHASE 13K.5 — متابعة CI: مطابقة CLI والقدرات العامة للسكريبتات (2026-11-16)

أظهر التشغيل `43782785649` نجاح اختبارات 13E–13J، ثم كشف ثلاثة إخفاقات في 13K بسبب فجوتين في تفسير أدلة القدرات، لا بسبب Dart compile failure:

1. لم تطابق `SkillCapabilityRegistry` قيمة `entryPoints` لعنصر `cli_binary` (مثل `ffmpeg`) مع سجل الأوامر؛ كانت المطابقة تستنتج المفسر من امتداد السكريبت فقط، ولذلك أعادت `environment_not_verified` بدلاً من `detected_in_base_environment_only`.
2. `local_script` بلا `entryPoints` لم يكن يملك descriptor عاماً، فصُنّف `unknown` وحجب الجاهزية حتى عندما كان المقصود حالة Runtime Profile pending.
3. أدى السبب الثاني بالتبعية إلى فشل حالة Ready ذات ملف Python Runtime Profile موثق وسجل self-test ناجح.

عولج ذلك بإضافة capability عامة `agent_skill.local_scripts` ذات تنفيذ مشروط، وبمطابقة CLI بالاسم التنفيذي (basename) مع الحفاظ على أن وجود الأداة في PRoot الأساسي لا يثبت توفرها داخل ملف تشغيل المهارة. وتظل الامتدادات غير المعروفة للسكريبتات مجهولة ومحجوبة، كما لا يُقبل دليل Runtime Profile دون `profileId` و`validatedAt`.

تضيف 13K.5 اختبارات لهذه الحالات وتوصلها إلى `preflight_phase13k_tests.sh` و`test_phase13k_ci.sh`. نجحت الفحوص الساكنة المحلية وAndroid-only وRelease Hardening. لم تتوفر Flutter/Dart/Gradle محلياً، لذلك يبقى تشغيل اختبارات Flutter وبناء APK عبر GitHub Actions شرطاً لاعتماد الإصلاح. لم تُعد اختبارات 13A–13D.
