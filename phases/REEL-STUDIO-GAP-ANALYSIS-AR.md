# Reel Studio — تحليل الفجوات وخطة التكامل مع KELIVO

**الحالة:** تحليل معماري ومطابقة مع المصدر الحالي فقط. لا توجد في هذا التحديث مطالبة بأن Reel Studio نُفّذ أو أن مرحلة الإنتاج المتزامن للفيديو أصبحت جاهزة.

## 1. الخلاصة التنفيذية

المقالة تصف خط إنتاج متكاملاً، لا مجرد prompt أو مهارة واحدة. Claude/الموديل مسؤول عن التخطيط والكتابة والمراجعة؛ الصوت والتوقيت والتصيير والجمع تقوم بها خدمات متخصصة قابلة للاستبدال.

KELIVO يملك بالفعل بعض الأساسات العامة التي يمكن البناء عليها:
- مشروع فيديو محايد عن المحرك عبر `video_production`، وملفات مشروع/Storyboard ومشاهد ذات مدد وسرد ووصف بصري وأصول.
- موائمات CLI اختيارية عبر `video_engine` تعمل بموافقة المستخدم داخل Android PRoot وRuntime Profile.
- موصلات لمزودي توليد الفيديو، و`video_hybrid_workflow` لتوجيه المشاهد بين محرك محلي ومزود خارجي وتجميع MP4.
- `video_quality` وffprobe/ffmpeg لفحص حاوية الوسائط والترميز والدقة وFPS والمدة والصوت، وتوقيت SRT/VTT، وblackdetect/silencedetect وcontact sheets والتشخيص.

لكن هذا لا يساوي Reel Studio جاهزاً. لا يوجد حالياً دليل على Orchestrator يربط Script → TTS/Uploaded Voice → Word Alignment → Storyboard Motion → Frame Rendering → Audio Mix → QA، ولا موائم صوت/محاذاة كلام مدمج أو واجهة مراجعة لكل مرحلة. كما لا يوجد renderer من نوع Playwright/Chromium مثبت ومختبر على Android ARM64 PRoot.

## 2. مطابقة المتطلبات مع المصدر

| عنصر المقالة | ما هو موجود الآن | الفجوة الفعلية |
|---|---|---|
| كتابة السكريبت والـStoryboard بنموذج LLM | KELIVO يملك تكاملات نماذج ومحادثة، ومشروع فيديو يقبل brief ومشاهد؛ وFreeLLMAPI يعلن واجهة OpenAI-compatible | لا يوجد قالب Reel pipeline موحد، ولا تدفق كتابة/مراجعة/اعتماد السكريبت والـStoryboard على مراحل |
| FreeLLMAPI | خدمة محلية مستقلة متوافقة مع OpenAI API؛ ليست حزمة CLI مطلوبة داخل PRoot بالضرورة | إضافة موائم LLM endpoint اختياري بعنوان قابل للتحرير وتحقق اتصال، دون افتراض منفذ ثابت أو حفظ المفتاح في ملفات Skill |
| ElevenLabs TTS | لا يوجد موائم TTS/Voice متخصص في منظومة video providers الحالية | موائم صوت: قائمة الأصوات، توليد صوت، تنزيل آمن، metadata، توقيت character alignment، إلغاء وإعادة المحاولة |
| صوت المستخدم المرفوع | مشروع الإنتاج يدعم ملفات أصول، لكن لا يوجد في pipeline الحالي مسار voice import ثم alignment | استيراد صوت مع فحص codec/مدة/حجم، ثم إرساله لمحاذاة التوقيت |
| Deepgram STT | لا يوجد موائم Speech-to-Text موثق في خدمات الفيديو | موائم ASR يدعم Arabic، word start/end/confidence، التحقق من الاستجابة وحدود الحجم والمهلة |
| مزامنة كل كلمة مع النص | `video_quality` يتحقق من توقيت SRT/VTT فقط | tokenizer عربي/إنجليزي + LCS/forced alignment، علامات الثقة، مراجعة الكلمات الضعيفة، تصدير VTT/SRT/JSON |
| Storyboard مشهدي | `video_production` يقبل مشاهد ونصوصاً ومدداً وانتقالات وأصولاً | أنواع مشاهد وقوالب رسم motion محددة بعقد schema، توزيع زمني مرتبط بفهرس الكلمات، إصلاح JSON ومراجعة ذاتية LLM |
| Motion Graphics بالكود | محرك الفيديو الخارجي يستطيع تنفيذ أوامر CLI معلنة | لا توجد مكتبة مشاهد/keyframes/interpolation/easing/camera/line draw/icon pop مدمجة في KELIVO |
| التصيير frame-by-frame | يمكن لمحرك CLI تنفيذ render ثم إرجاع output؛ لا يوجد renderer ويب مثبت | adapter موثوق يولد frames/يفتح معاينة حيّة، مع قيود ذاكرة وتخزين وFPS ودقة |
| FFmpeg mux/audio mix | FFmpeg/ffprobe مدعومان في فحوص الجودة، وتجميع MP4 يفوض لمحرك يعلن assembly | وصفة إنتاج لتجميع frame sequence + narration + SFX، وloudness normalization، ومزامنة وعقد output موثق |
| progress / SSE / live preview / stage approval | أداة المحرك تقدم أوامر render/cancel وحالة تشغيل عامة، والمهام الخلفية والموافقات موجودة | حالة مستقلة لكل مرحلة، سجلات حية، حدث تقدم، آخر frame preview، pause/review/retry/cancel |
| E2E offline mocks | توجد مجموعات اختبارات ومشغلات محلية منفصلة | Mock LLM/TTS/STT/renderer، fixture timings، golden contact sheets، اختبار reel تجريبي كامل |
| أسلوب عربي موحد | `language` و`narrationDirection` و`visualStyle` في brief | ملف مرجعي قابل للتخصيص، dialect/voice profile، قواعد hook/story/recap، عدد كلمات/ثانية مع تحقق طول السكريبت |

## 3. أدوات البيئة: ما يجب إضافته وما هو موجود بالفعل

لا ينبغي إنشاء أزرار مكررة. فحصت `EnvironmentDependency` وواجهة Environment:

### موجودة وقابلة للتثبيت بالفعل
- **Node.js + npm:** عنصر `Node.js` في قسم البيئة، وتثبيته عبر حزم النظام (`nodejs npm`). يوجد أيضاً Package Manager يدعم npm/pnpm/yarn/bun ضمن Runtime Profile.
- **FFmpeg + ffprobe:** عنصر `Media tools` يثبت `ffmpeg` ويتحقق من الأمرين `ffmpeg` و`ffprobe`. لا يتم تضمينهما في APK ولا يثبتان تلقائياً.
- **Python/pip/venv، Git، SSH، curl/wget، zip/unzip:** موجودة أيضاً كعناصر مستقلة في Environment.

لذلك لا أضيف Node أو FFmpeg مرة ثانية. التغيير الصحيح هنا هو ربط Preflight الخاص بـReel Studio بهذه الأدوات الموجودة، وإظهارها كمتطلبات مع حالة Installed/Missing وفتح مسار التثبيت الحالي.

### ليس أداة نظام جاهزة للإضافة كزر الآن
- **FreeLLMAPI:** خادم API محلي/خارجي اختياري، وليس مجرد package apt. يوصل كـLLM endpoint قابل للتكوين، ويمكن أن يكون خارج جهاز Android عند توفر الشبكة.
- **ElevenLabs وDeepgram:** خدمات API؛ مفاتيحها وإعداداتها تدار في مخزن أسرار scoped ومشفّر، لا عبر تثبيت نظام ولا داخل `SKILL.md` أو ملفات المشروع.
- **IBM Plex Sans Arabic:** أصل خط مرخص OFL يضمّن مع المشروع مع ملف الترخيص؛ لا يحتاج زر apt افتراضي. نضيف اختيار مجلد خطوط للمستخدم ضمن إعدادات renderer.
- **Tabler Icons وHealth Icons:** مكتبات أصول مع تسجيل ترخيص لكل مصدر وأيقونة، تُحزم انتقائياً حسب استخدام المشروع؛ ليست خدمة قابلة للتثبيت في PRoot.
- **Playwright + Chromium:** أضيف كخيار تجريبي اختياري في Environment: Node.js 26.13.1 داخل مجلد خاص بـKELIVO، Playwright 1.65.1، تنزيل Chromium ومكتباته، ثم smoke test يفتح المتصفح headless ويلتقط صفحة عربية RTL. المثبّت يقيد نفسه بـUbuntu/Debian ARM64/x64 ويكتب علامة `.verified` بعد نجاح الاختبار فقط. Playwright يوثق توزيعات Linux المذكورة؛ Android PRoot ليس منصة معلنة الدعم، لذا لا نضمن عمله على الهاتف قبل التثبيت والاختبار الفعلي.

## 4. تصحيح معلومات المقالة قبل التنفيذ

- لا نثبّت FreeLLMAPI على المنفذ `31415` كقيمة عامة. الوثائق الحالية تذكر `http://localhost:3001/v1` لواجهة OpenAI-compatible على الخادم؛ و`127.0.0.1:31415` حالة Desktop/Claude Gateway محددة. لذلك Base URL يجب أن يكون قابلاً للتحرير والتحقق، ولا يربط KELIVO بمثال واحد.
- ElevenLabs stream-with-timestamps يعيد audio chunks ومعها character alignment؛ نحتاج تحويل character timings إلى word timings ثم فحصها أو اختيار forced-alignment عند إدخال صوت مسجل.
- Deepgram prerecorded `/v1/listen` يعيد `words` مع start/end/confidence، ويمكن ضبط اللغة العربية؛ يجب أن يعامل ASR كاقتراح زمني يحتاج مقارنة بالنص، لا استبدال النص المعتمد تلقائياً.
- لا تعتبر أرصدة “مجانية” ثابتة أو مضمونة. التسعير والحصص وسياسات الخدمات تتغير؛ تظهر في إعداد المزود الحالي ولا تُكتب كقيد معماري.

## 5. التصميم المقترح داخل KELIVO

إنشاء طبقة مستقلة قابلة للاستبدال، لا ربطها بـClaude أو مزود بعينه:

1. **Reel Project Contract:** إعدادات 9:16 و1080×1920 (مع 720×1280 design canvas)، FPS ومدة وخط ولغة/لهجة وSeries Style Guide، إضافة إلى versioned manifest.
2. **Script Stage:** يطلب LLM عنواناً وhook وسؤال/قصة/تشبيه/خلاصة ومصادر. تحقق كلمات/ثانية وطول، وحفظ draft، تحرير المستخدم والموافقة.
3. **Voice Stage:** إعادة استخدام `NetworkTtsService` ومزوّد ElevenLabs الحالي، مع إضافة مسار `with-timestamps` جديد كـReel adapter؛ أو استيراد تسجيل المستخدم. تخزين الصوت في مساحة المشروع، وحفظ provider/job IDs فقط. انقل مفاتيح TTS/ASR من `SharedPreferences` إلى `FlutterSecureStorage` قبل توصيلها بمشاريع الفيديو.
4. **Timing Stage:** توحيد character alignment من ElevenLabs أو word timings من Deepgram/ASR إلى `word/start/end/confidence/scriptTokenIndex`; ASR الحالي يعيد transcript دون توقيت كلمة موحد، فلا يكفي كما هو. المطابقة LCS بعد تطبيع عربي غير هدّام، مع إبقاء النص الأصلي للعرض ورفع الكلمات غير المطابقة إلى قائمة مراجعة.
5. **Storyboard Stage:** JSON schema versioned مع scene types: intro/question/concept/process/compare/stat/recap، templates: body/zoom/flow/cycle/timeline/chart/layers/cards/meter؛ التوقيت يرتبط بفهرس كلمة/زمن. يمر بمصحح بنيوي ثم self-review، ولا ينتقل تلقائياً إن كانت هناك حقول غير آمنة أو غير صالحة.
6. **Motion Renderer Adapter:** keyframes حتمية تعتمد على `t`، easing وcamera moves وline-draw وicon pop، caption word highlighting، empty-frame checks، وإعادة استخدام أصول الخطوط والأيقونات المرخصة. Playwright/Chromium متاح كـrenderer اختياري تجريبي، لكن خيار التثبيت لا يثبت بعد وجود frame renderer متكامل أو أداء ثابت على Android.
7. **Audio Mix Stage:** FFmpeg لدمج narration وSFX، ducking/normalization، scene-cut ticks/whooshes، ومقياس loudness configurable لا hard-code لـ-14 LUFS لكل المنصات.
8. **Render/QA Stage:** frame batches، preview frame، ffprobe profile، black/silence scans، subtitle validation، contact sheet وملف QA. الفشل يعيد مرحلة محددة ويحفظ المراحل الناجحة.
9. **Execution model:** state machine `idle/running/review/done/error/cancelled`، approval لكل مرحلة، checkpoints، live logs/progress، background notifications، no secrets in logs، safe cancellation، واستعادة الحالة عند إعادة فتح التطبيق.

## 6. ترتيب التنفيذ المقترح

- **A — Contracts & offline mocks:** project schema، stage state machine، mock endpoints، deterministic fixture، acceptance tests.
- **B — Arabic script & style guide:** prompt templates، user-editable reference, dialect/tempo, source metadata.
- **C — Voice and transcript adapters:** ElevenLabs + uploaded voice + Deepgram; credentials stored securely; word alignment regression fixtures.
- **D — Storyboard and motion templates:** scene DSL and licensed icon/font catalog; visual snapshot tests.
- **E — Renderer compatibility spike:** test Android ARM64 PRoot options first; choose Playwright only after it passes hardware and stability gates.
- **F — FFmpeg composition and quality gates:** actual audio mix, subtitles, loudness, codecs, preview and full E2E.
- **G — Optional publishing:** YouTube OAuth/upload only as a separate consent-gated stage; not part of V1 and never implied by the article prompt.

## 7. معايير قبول لا يمكن تجاوزها

- Produce a 10-second vertical Arabic reel completely offline through mock services, with every stage status and approval recorded.
- The real provider path generates speech and verified word timings; script-token mismatch and low-confidence words are surfaced.
- Captions highlight at actual word onset, all scenes have valid timing and frame snapshots, no missing/empty frames.
- Rendered MP4 inspected by ffprobe, has expected video/audio streams, resolution/FPS/duration/codec; sound and captions reviewed.
- E2E cancels and resumes safely; secrets are absent from project files, logs, artifacts and Skill metadata.
- Run on a real Android ARM64 phone/PRoot within measured memory/storage/thermal thresholds before advertising renderer support.

## 8. مصدر المقالة مقابل ما تحقق منه في KELIVO

المقالة والبرومت المرفقان هما مصدر المتطلبات. تمت مطابقة الحالة مع `video_production` و`video_engines` و`video_hybrid` و`video_providers` و`video_quality` و`NetworkTtsService` وموائمات ASR و`SettingsProvider` وEnvironment. تمت إضافة أدوات الوسائط وخيار Playwright الاختياري إلى المصدر في هذا التحديث، لكن Orchestrator ومحاذاة الكلمات وReel end-to-end لا تزال غير منفذة ولا تُسجل كمرحلة مكتملة.
