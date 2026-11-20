// Arabic localization overrides. Unreviewed messages inherit the English fallback.
// Flutter gen-l10n regenerates the authoritative classes during CI/build.
import 'package:intl/intl.dart' as intl;
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

class AppLocalizationsAr extends AppLocalizationsEn {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get avatarInputInvalid => "أدخل اسم أيقونة صالحًا أو رابط صورة يبدأ بـ HTTP أو HTTPS.";

  @override
  String get modelAvatarTitle => "أيقونة النموذج";

  @override
  String get avatarColor => "ملوّن";

  @override
  String get avatarMonochrome => "أحادي اللون";

  @override
  String get settingsSearchHint => "البحث في الإعدادات";

  @override
  String get settingsSearchCancel => "إلغاء";

  @override
  String get settingsSearchClear => "مسح البحث";

  @override
  String get settingsSearchSuggestions => "وصول سريع";

  @override
  String get settingsSearchNoResults => "لم يتم العثور على إعدادات";

  @override
  String get settingsSearchNoResultsHint => "جرّب اسمًا مختلفًا أو كلمة أقصر.";

  @override
  String settingsSearchResultCount(int count) => (count == 0 ? "لا توجد نتائج" : (count == 1 ? "نتيجة واحدة" : intl.Intl.pluralLogic(count, locale: localeName, two: "نتيجتان", few: "${count} نتائج", many: "${count} نتيجة", other: "${count} نتيجة")));

  @override
  String get helloWorld => "مرحبًا بالعالم!";

  @override
  String get settingsPageBackButton => "رجوع";

  @override
  String get settingsPageTitle => "الإعدادات";

  @override
  String get settingsPageDarkMode => "داكن";

  @override
  String get settingsPageLightMode => "فاتح";

  @override
  String get settingsPageSystemMode => "اتباع إعدادات النظام";

  @override
  String get settingsPageWarningMessage => "بعض الخدمات غير مُعدّة، وقد تكون بعض الميزات محدودة.";

  @override
  String get settingsPageGeneralSection => "عام";

  @override
  String get settingsPageColorMode => "نمط الألوان";

  @override
  String get settingsPageDisplay => "التفضيلات";

  @override
  String get settingsPageDisplaySubtitle => "تفضيلات المظهر والسلوك والتفاعل";

  @override
  String get settingsPageAssistant => "المساعد";

  @override
  String get settingsPageAssistantSubtitle => "المساعد الافتراضي وأسلوبه";

  @override
  String get settingsPageModelsServicesSection => "النماذج والخدمات";

  @override
  String get settingsPageDefaultModel => "النموذج الافتراضي";

  @override
  String get settingsPageProviders => "مزوّدو الخدمة";

  @override
  String get settingsPageHotkeys => "اختصارات لوحة المفاتيح";

  @override
  String get settingsPageSearch => "البحث";

  @override
  String get settingsPageTts => "تحويل النص إلى كلام";

  @override
  String get settingsPageQuickPhrase => "العبارات السريعة";

  @override
  String get settingsPageInstructionInjection => "إدراج التعليمات";

  @override
  String get settingsPageDataSection => "البيانات";

  @override
  String get settingsPageBackup => "النسخ الاحتياطي";

  @override
  String get settingsPageChatStorage => "تخزين المحادثات";

  @override
  String get settingsPageCalculating => "جارٍ الحساب…";

  @override
  String get storageSpacePageTitle => "مساحة التخزين";

  @override
  String get storageSpaceRefreshTooltip => "تحديث";

  @override
  String get storageSpaceLoadFailed => "تعذّر تحميل الملفات أو التحقق من الصور المستخدمة. حدّث الصفحة ثم حاول مرة أخرى.";

  @override
  String get storageSpaceTotalLabel => "المستخدم";

  @override
  String storageSpaceClearableLabel(String size) => "قابل للحذف: ${size}";

  @override
  String storageSpaceClearableHint(String size) => "يمكن حذفه بأمان: ${size}";

  @override
  String get storageSpaceCategoryImages => "الصور";

  @override
  String get storageSpaceCategoryFiles => "الملفات";

  @override
  String get storageSpaceCategoryFonts => "الخطوط";

  @override
  String get storageSpaceCategoryLocalModels => "النماذج المحلية";

  @override
  String get storageSpaceOtherHint => "الخطوط والنماذج المحلية المنزّلة وملفات التطبيق الأخرى.";

  @override
  String get storageSpaceSubOtherApp => "ملفات التطبيق";

  @override
  String get storageSpaceCategoryChatData => "سجلات المحادثات";

  @override
  String get storageSpaceCategoryLegacyChatData => "سجلات المحادثات القديمة";

  @override
  String get storageSpaceCategoryRestoreTraces => "سجلات الاستعادة";

  @override
  String get storageSpaceCategoryDisplacedDatabases => "قواعد البيانات المحفوظة جانبًا";

  @override
  String get storageSpaceSubDisplacedDatabases => "حُفظت قبل إعادة بناء تلقائية";

  @override
  String get storageSpaceClearDisplacedDatabasesConfirmMessage => "هل تريد حذف قواعد البيانات المحفوظة جانبًا؟ احتفظ KELIVO بها عند إعادة بناء قاعدة البيانات، وقد تكون النسخ الوحيدة المتبقية من تلك المحادثات والإعدادات. لا يمكن التراجع عن هذا الإجراء.";

  @override
  String get storageSpaceRestoreTracesHint => "لقطات بيانات سابقة احتُفظ بها بعد اكتمال عمليات الاستعادة. حذفها لا يؤثر في بيانات التطبيق الحالية.";

  @override
  String get storageSpaceClearRestoreTracesButton => "مسح سجلات الاستعادة";

  @override
  String get storageSpaceClearDisplacedDatabasesButton => "حذف قواعد البيانات المحفوظة جانبًا";

  @override
  String get storageSpaceClearRestoreTracesConfirmMessage => "هل تريد مسح لقطات الاستعادة المكتملة؟ لن تتأثر قاعدة بياناتك الحالية أو إعداداتك أو ملفاتك.";

  @override
  String get storageSpaceSubCompletedRestoreRuns => "لقطات الاستعادة المكتملة";

  @override
  String get storageSpaceCategoryCache => "ذاكرة التخزين المؤقت";

  @override
  String get storageSpaceCategoryLogs => "السجلات";

  @override
  String get storageSpaceCategoryOther => "أخرى";

  @override
  String get storageSpaceSafeToClearHint => "يمكن حذفه بأمان، ولن يؤثر ذلك في سجل محادثاتك.";

  @override
  String get storageSpaceLegacyChatDataHint => "هذه ملفات Hive محفوظة من الفترة السابقة للانتقال إلى SQLite. حذفها لا يمس سجلات المحادثات الحالية.";

  @override
  String get storageSpaceNotSafeToClearHint => "قد يؤثر ذلك في سجل محادثاتك. احذف بحذر.";

  @override
  String get storageSpaceBreakdownTitle => "تفصيل الاستخدام";

  @override
  String get storageSpaceSubChatMessages => "الرسائل";

  @override
  String get storageSpaceSubChatConversations => "المحادثات";

  @override
  String get storageSpaceSubChatToolEvents => "أحداث الأدوات";

  @override
  String get storageSpaceSubChatDatabase => "قاعدة بيانات المحادثات";

  @override
  String get storageSpaceSubChatWriteAheadLog => "سجل الكتابة المسبقة";

  @override
  String get storageSpaceSubChatSharedMemory => "فهرس الذاكرة المشتركة";

  @override
  String get storageSpaceSubCacheAvatars => "ذاكرة التخزين المؤقت للأفاتار";

  @override
  String get storageSpaceSubCacheOther => "ذاكرة تخزين مؤقت أخرى";

  @override
  String get storageSpaceSubCacheSystem => "ذاكرة تخزين النظام المؤقتة";

  @override
  String get storageSpaceSubLogsContext => "سجلات السياق";

  @override
  String get storageSpaceSubLogsFlutter => "سجلات Flutter";

  @override
  String get storageSpaceSubLogsRequests => "سجلات الشبكة";

  @override
  String get storageSpaceSubLogsOther => "سجلات أخرى";

  @override
  String get storageSpaceClearConfirmTitle => "تأكيد المسح";

  @override
  String storageSpaceClearConfirmMessage(String targetName) => "هل تريد مسح ${targetName}؟";

  @override
  String get storageSpaceClearButton => "مسح";

  @override
  String storageSpaceClearDone(String targetName) => "تم مسح ${targetName}";

  @override
  String storageSpaceClearFailed(String error) => "تعذّر المسح: ${error}";

  @override
  String get storageSpaceClearAvatarCacheButton => "مسح ذاكرة التخزين المؤقت للأفاتار";

  @override
  String get storageSpaceClearCacheButton => "مسح ذاكرة التخزين المؤقت";

  @override
  String get storageSpaceClearLogsButton => "مسح السجلات";

  @override
  String get storageSpaceClearLegacyChatDataButton => "مسح سجلات المحادثات القديمة";

  @override
  String get storageSpaceExportLegacyChatFileButton => "تصدير";

  @override
  String storageSpaceExportDone(Object fileName) => "تم تصدير ${fileName}";

  @override
  String storageSpaceExportFailed(Object error) => "فشل التصدير: ${error}";

  @override
  String get storageSpaceClearLegacyChatDataConfirmMessage => "هل تريد مسح ملفات المحادثات القديمة المحتفظ بها؟ ستظل سجلات SQLite الحالية متاحة.";

  @override
  String get storageSpaceViewLogsButton => "عرض السجلات";

  @override
  String get storageSpaceDeleteConfirmTitle => "تأكيد الحذف";

  @override
  String storageSpaceDeleteUploadsConfirmMessage(int count) => "هل تريد حذف ${count} عنصرًا ونسخ مرفقاتها المرتبطة بالمحادثات؟ لن تعود هذه المرفقات متاحة في سجل المحادثات.";

  @override
  String storageSpaceDeletedUploadsDone(int count) => "تم حذف ${count} عنصرًا";

  @override
  String get storageSpaceNoUploads => "لا توجد عناصر";

  @override
  String get storageSpaceSelectAll => "تحديد الكل";

  @override
  String get storageSpaceClearSelection => "إلغاء التحديد";

  @override
  String storageSpaceSelectedCount(int count) => "تم تحديد ${count}";

  @override
  String storageSpaceUploadsCount(int count) => "${count} عنصر";

  @override
  String get storageSpaceSortLabel => "ترتيب حسب";

  @override
  String get storageSpaceSortNewest => "الأحدث";

  @override
  String get storageSpaceSortOldest => "الأقدم";

  @override
  String get storageSpaceSortLargest => "الأكبر حجمًا";

  @override
  String get storageSpaceSortSmallest => "الأصغر حجمًا";

  @override
  String get settingsPageAboutSection => "حول التطبيق";

  @override
  String get settingsPageAbout => "حول";

  @override
  String get settingsPageStatistics => "الإحصاءات";

  @override
  String get settingsPageDocs => "الوثائق";

  @override
  String get settingsPageLogs => "السجلات";

  @override
  String get settingsPageSponsor => "الدعم والرعاية";

  @override
  String get settingsPageShare => "مشاركة";

  @override
  String get statsPageTitle => "الإحصاءات";

  @override
  String get statsPageRangeAllTime => "كل الوقت";

  @override
  String get statsPageRangeLast30Days => "آخر 30 يومًا";

  @override
  String get statsPageRangePreviousMonth => "الشهر السابق";

  @override
  String get statsPageRangePreviousQuarter => "الربع السابق";

  @override
  String get statsPageRangeCustom => "نطاق مخصص";

  @override
  String get statsPageHeatmapTitle => "خريطة نشاط المحادثات";

  @override
  String get statsPageHeatmapLess => "أقل";

  @override
  String get statsPageHeatmapMore => "أكثر";

  @override
  String get statsPageSummaryTitle => "نظرة عامة";

  @override
  String get statsPageTotalConversations => "إجمالي المحادثات";

  @override
  String get statsPageTotalMessages => "إجمالي الرسائل";

  @override
  String get statsPageInputTokens => "رموز الإدخال";

  @override
  String get statsPageOutputTokens => "رموز الإخراج";

  @override
  String get statsPageCachedTokens => "الرموز المخزنة مؤقتًا";

  @override
  String get statsPageLaunchCount => "مرات تشغيل التطبيق";

  @override
  String statsPageCost(String currency) => "التكلفة (${currency})";

  @override
  String statsPageModelsWithoutPricing(int count) => intl.Intl.pluralLogic(count, locale: localeName, one: "${count} نموذج دون تسعير", two: "${count} نموذجان دون تسعير", few: "${count} نماذج دون تسعير", many: "${count} نموذجًا دون تسعير", other: "${count} نموذج دون تسعير");

  @override
  String get statsPageUsageTrendTitle => "اتجاه الاستخدام";

  @override
  String get statsPageModelUsageTitle => "استخدام النماذج";

  @override
  String get statsPageAssistantUsageTitle => "استخدام المساعدين";

  @override
  String get statsPageTopicVolumeTitle => "حجم الموضوعات";

  @override
  String get statsPageModelColumn => "النموذج";

  @override
  String get statsPageAssistantColumn => "المساعد";

  @override
  String get statsPageTopicColumn => "الموضوع";

  @override
  String get statsPageMessagesColumn => "الرسائل";

  @override
  String get statsPageTopicsColumn => "الموضوعات";

  @override
  String get statsPageEmptyTitle => "لا توجد إحصاءات بعد";

  @override
  String get statsPageShowAllTooltip => "عرض الكل";

  @override
  String get statsPageClose => "إغلاق";

  @override
  String get statsPageUnknownProvider => "مزوّد غير معروف";

  @override
  String get statsPageUnknownAssistant => "المساعد الافتراضي";

  @override
  String get statsPageUnknownModel => "نموذج غير معروف";

  @override
  String get statsPageUnknownTopic => "موضوع بلا عنوان";

  @override
  String get statsPageCustomRangeTitle => "نطاق زمني مخصص";

  @override
  String get statsPageCustomRangeStart => "البداية";

  @override
  String get statsPageCustomRangeEnd => "النهاية";

  @override
  String get statsPageCustomRangeCancel => "إلغاء";

  @override
  String get statsPageCustomRangeApply => "تطبيق";

  @override
  String get sponsorPageMethodsSectionTitle => "طرق الدعم";

  @override
  String get sponsorPageSponsorsSectionTitle => "الرعاة";

  @override
  String get sponsorPageEmpty => "لا يوجد رعاة بعد";

  @override
  String get sponsorPageWeChatTitle => "دعم عبر WeChat";

  @override
  String get sponsorPageWeChatSubtitle => "رمز دعم WeChat";

  @override
  String get sponsorPageScanQrHint => "امسح رمز QR لتقديم الدعم";

  @override
  String get languageDisplaySimplifiedChinese => "الصينية المبسطة";

  @override
  String get languageDisplayEnglish => "الإنجليزية";

  @override
  String get languageDisplayTraditionalChinese => "الصينية التقليدية";

  @override
  String get languageDisplayJapanese => "اليابانية";

  @override
  String get languageDisplayKorean => "الكورية";

  @override
  String get languageDisplayFrench => "الفرنسية";

  @override
  String get languageDisplayGerman => "الألمانية";

  @override
  String get languageDisplayItalian => "الإيطالية";

  @override
  String get languageDisplaySpanish => "الإسبانية";

  @override
  String get languageSelectSheetTitle => "اختيار لغة الترجمة";

  @override
  String get languageSelectSheetClearButton => "مسح الترجمة";

  @override
  String get homePageClearContext => "مسح السياق";

  @override
  String contextMessageCount(int count) => "${count} رسالة";

  @override
  String contextMessageCountLimited(int actual, int configured) => "${actual}/${configured} رسالة";

  @override
  String get homePageDefaultAssistant => "المساعد الافتراضي";

  @override
  String get mermaidExportPng => "تصدير PNG";

  @override
  String get mermaidExportFailed => "فشل التصدير";

  @override
  String get mermaidImageTab => "صورة";

  @override
  String get mermaidCodeTab => "رمز";

  @override
  String get mermaidFullScreen => "ملء الشاشة";

  @override
  String get mermaidGeneratingImage => "جارٍ إنشاء الصورة";

  @override
  String get mermaidGenerationFailedHint => "فشل الإنشاء. جرّب صياغة الطلب بطريقة أخرى.";

  @override
  String get mermaidPreviewOpen => "فتح المعاينة";

  @override
  String get mermaidPreviewOpenFailed => "تعذّر فتح المعاينة";

  @override
  String get assistantProviderDefaultAssistantName => "المساعد الافتراضي";

  @override
  String get assistantProviderSampleAssistantName => "مساعد تجريبي";

  @override
  String get assistantProviderNewAssistantName => "مساعد جديد";

  @override
  String assistantProviderSampleAssistantSystemPrompt(String model_name) => "أنت ${model_name}، مساعد ذكاء اصطناعي مفيد. أجب بدقة واختصار، وصرّح عندما لا تكون متأكدًا. استخدم بنية واضحة، مثل الفقرات القصيرة أو القوائم، عند الحاجة. أجب افتراضيًا بلغة المستخدم.";

  @override
  String get displaySettingsPageLanguageTitle => "لغة التطبيق";

  @override
  String get displaySettingsPageLanguageSubtitle => "اختر لغة واجهة التطبيق";

  @override
  String get assistantTagsManageTitle => "إدارة الوسوم";

  @override
  String get assistantTagsCreateButton => "إنشاء";

  @override
  String get assistantTagsCreateDialogTitle => "إنشاء وسم";

  @override
  String get assistantTagsCreateDialogOk => "إنشاء";

  @override
  String get assistantTagsCreateDialogCancel => "إلغاء";

  @override
  String get assistantTagsNameHint => "اسم الوسم";

  @override
  String get assistantTagsRenameButton => "إعادة تسمية";

  @override
  String get assistantTagsRenameDialogTitle => "إعادة تسمية الوسم";

  @override
  String get assistantTagsRenameDialogOk => "إعادة تسمية";

  @override
  String get assistantTagsDeleteButton => "حذف";

  @override
  String get assistantTagsDeleteConfirmTitle => "حذف الوسم";

  @override
  String get assistantTagsDeleteConfirmContent => "هل أنت متأكد من رغبتك في حذف هذا الوسم؟";

  @override
  String get assistantTagsDeleteConfirmOk => "حذف";

  @override
  String get assistantTagsDeleteConfirmCancel => "إلغاء";

  @override
  String get assistantTagsContextMenuEditAssistant => "تعديل المساعد";

  @override
  String get assistantTagsContextMenuManageTags => "إدارة الوسوم";

  @override
  String get mcpTransportTagInmemory => "مدمج";

  @override
  String get mcpServerEditSheetStdioCommandLabel => "الأمر";

  @override
  String get mcpServerEditSheetStdioArgumentsLabel => "المعاملات";

  @override
  String get mcpServerEditSheetStdioWorkingDirectoryLabel => "مجلد العمل (اختياري)";

  @override
  String get mcpWorkspaceBindingLabel => "ربط مساحة العمل (اختياري)";

  @override
  String get mcpWorkspaceBindingHint => "يمكن للخادم الوصول إلى مساحة العمل هذه عبر /workspace. اترك مجلد العمل فارغًا للبدء منها. يظل الربط ثابتًا عند تبديل المحادثات.";

  @override
  String get mcpWorkspaceBindingMobileOnly => "يتوفر ربط مساحة العمل في بيئة Linux على الهاتف. ألغِ الربط لتشغيل هذا الخادم على سطح المكتب.";

  @override
  String get mcpServerEditSheetStdioEnvironmentTitle => "متغيرات البيئة";

  @override
  String get mcpServerEditSheetStdioEnvNameLabel => "الاسم";

  @override
  String get mcpServerEditSheetStdioEnvValueLabel => "القيمة";

  @override
  String get mcpServerEditSheetStdioAddEnv => "إضافة متغير بيئة";

  @override
  String get mcpServerEditSheetStdioCommandRequired => "يلزم إدخال أمر لـ STDIO";

  @override
  String get assistantTagsContextMenuDeleteAssistant => "حذف المساعد";

  @override
  String get assistantTagsClearTag => "إزالة الوسم";

  @override
  String get displaySettingsPageLanguageChineseLabel => "الصينية المبسطة";

  @override
  String get displaySettingsPageLanguageEnglishLabel => "الإنجليزية";

  @override
  String get homePagePleaseSelectModel => "يرجى اختيار نموذج أولًا";

  @override
  String get homePagePleaseSetupTranslateModel => "يرجى إعداد نموذج الترجمة أولًا";

  @override
  String get homePageTranslating => "جارٍ الترجمة…";

  @override
  String homePageTranslateFailed(String error) => "فشلت الترجمة: ${error}";

  @override
  String get chatServiceDefaultConversationTitle => "محادثة جديدة";

  @override
  String get userProviderDefaultUserName => "مستخدم";

  @override
  String get homePageDeleteMessage => "حذف هذه النسخة";

  @override
  String get homePageDeleteMessageConfirm => "هل أنت متأكد من رغبتك في حذف هذه النسخة؟ لا يمكن التراجع عن هذا الإجراء.";

  @override
  String get homePageDeleteAllVersions => "حذف جميع النسخ";

  @override
  String get homePageDeleteAllVersionsConfirm => "هل أنت متأكد من رغبتك في حذف جميع نسخ هذه الرسالة؟ لا يمكن التراجع عن هذا الإجراء.";

  @override
  String get homePageCancel => "إلغاء";

  @override
  String get homePageDelete => "حذف";

  @override
  String get homePageSelectMessagesToShare => "يرجى تحديد الرسائل التي تريد مشاركتها";

  @override
  String get homePageDone => "تم";

  @override
  String get homePageDropToUpload => "أفلت الملفات هنا لرفعها";

  @override
  String get assistantEditPageTitle => "المساعد";

  @override
  String get assistantEditPageNotFound => "لم يتم العثور على المساعد";

  @override
  String get assistantEditPageBasicTab => "عام";

  @override
  String get assistantEditPagePromptsTab => "التعليمات";

  @override
  String get assistantEditPageQuickPhraseTab => "العبارات السريعة";

  @override
  String get assistantEditPageCustomTab => "مخصص";

  @override
  String get assistantEditPageRegexTab => "استبدال Regex";

  @override
  String get assistantEditPageLocalToolsTab => "الأدوات المحلية";

  @override
  String get assistantEditTabLayoutTooltip => "تخصيص علامات التبويب";

  @override
  String get assistantEditTabLayoutTitle => "تخصيص علامات التبويب";

  @override
  String get assistantEditTabLayoutSubtitle => "اسحب علامات التبويب لإعادة ترتيبها، وأوقف ما لا تحتاج إليه.";

  @override
  String get assistantEditOutlineModeTitle => "نمط قائمة الأقسام";

  @override
  String get assistantEditOutlineModeSubtitle => "اعرض نظرة عامة على المساعد أولًا، ثم افتح كل قسم إعدادات من القائمة.";

  @override
  String get assistantEditTabLayoutResetTooltip => "إعادة ضبط ترتيب علامات التبويب";

  @override
  String get assistantEditTabLayoutAtLeastOneVisible => "أبقِ علامة تبويب واحدة ظاهرة على الأقل";

  @override
  String assistantEditTabLayoutDragHandle(String tab) => "اسحب لإعادة ترتيب ${tab}";

  @override
  String get assistantEditRegexDescription => "أنشئ قواعد Regex لإعادة صياغة رسائل المستخدم أو المساعد أو تعديل طريقة عرضها.";

  @override
  String get assistantEditAddRegexButton => "إضافة قاعدة Regex";

  @override
  String get assistantRegexAddTitle => "إضافة قاعدة Regex";

  @override
  String get assistantRegexEditTitle => "تعديل قاعدة Regex";

  @override
  String get assistantRegexNameLabel => "اسم القاعدة";

  @override
  String get assistantRegexPatternLabel => "التعبير النمطي";

  @override
  String get assistantRegexReplacementLabel => "نص الاستبدال";

  @override
  String get assistantRegexScopeLabel => "نطاق التطبيق";

  @override
  String get assistantRegexScopeUser => "المستخدم";

  @override
  String get assistantRegexScopeAssistant => "المساعد";

  @override
  String get assistantRegexScopeVisualOnly => "للعرض فقط";

  @override
  String get assistantRegexScopeReplaceOnly => "للاستبدال فقط";

  @override
  String get assistantRegexAddAction => "إضافة";

  @override
  String get assistantRegexSaveAction => "حفظ";

  @override
  String get assistantRegexDeleteButton => "حذف";

  @override
  String get assistantRegexValidationError => "يرجى إدخال الاسم والتعبير النمطي وتحديد نطاق واحد على الأقل.";

  @override
  String get assistantRegexInvalidPattern => "التعبير النمطي غير صالح";

  @override
  String get assistantRegexCancelButton => "إلغاء";

  @override
  String get assistantRegexUntitled => "قاعدة بلا عنوان";

  @override
  String get assistantEditCustomHeadersTitle => "ترويسات مخصصة";

  @override
  String get assistantEditCustomHeadersAdd => "إضافة ترويسة";

  @override
  String get assistantEditCustomHeadersEmpty => "لم تتم إضافة ترويسات";

  @override
  String get assistantEditCustomBodyTitle => "محتوى مخصص";

  @override
  String get assistantEditCustomBodyAdd => "إضافة عنصر محتوى";

  @override
  String get assistantEditCustomBodyEmpty => "لم تتم إضافة عناصر محتوى";

  @override
  String get assistantEditHeaderNameLabel => "اسم الترويسة";

  @override
  String get assistantEditHeaderValueLabel => "قيمة الترويسة";

  @override
  String get assistantEditBodyKeyLabel => "مفتاح المحتوى";

  @override
  String get assistantEditBodyValueLabel => "قيمة المحتوى (JSON)";

  @override
  String get assistantEditDeleteTooltip => "حذف";

  @override
  String get assistantEditAssistantNameLabel => "اسم المساعد";

  @override
  String get assistantEditUseAssistantAvatarTitle => "استخدام صورة المساعد";

  @override
  String get assistantEditUseAssistantAvatarSubtitle => "استخدم صورة المساعد بدلًا من صورة النموذج";

  @override
  String get assistantEditUseAssistantNameTitle => "استخدام اسم المساعد";

  @override
  String get assistantEditChatModelTitle => "نموذج المحادثة";

  @override
  String get assistantEditChatModelSubtitle => "نموذج المحادثة الافتراضي لهذا المساعد (مع الرجوع إلى الإعداد العام عند الحاجة)";

  @override
  String get assistantEditTemperatureDescription => "يتحكم في العشوائية، ضمن النطاق من 0 إلى 2";

  @override
  String get assistantEditTopPDescription => "لا تغيّر هذا الإعداد ما لم تكن تعرف ما تفعله.";

  @override
  String get assistantEditParameterDisabled => "معطّل (استخدام إعدادات المزوّد الافتراضية)";

  @override
  String get assistantEditParameterDisabled2 => "معطّل (بلا قيود)";

  @override
  String get assistantEditContextMessagesTitle => "رسائل السياق";

  @override
  String get assistantEditContextMessagesDescription => "عدد الرسائل الأخيرة التي يجب الاحتفاظ بها في سياق المحادثة";

  @override
  String get assistantEditStreamOutputTitle => "الإخراج المتدفق";

  @override
  String get assistantEditStreamOutputDescription => "تفعيل عرض الاستجابة أثناء إنشائها";

  @override
  String get assistantEditThinkingBudgetTitle => "التفكير";

  @override
  String get assistantEditReasoningFollowDefault => "اتباع الإعداد الافتراضي للنموذج";

  @override
  String get assistantEditReasoningClampedSubtitle => "يُضبط المستوى الفعلي وفق ما يدعمه كل نموذج";

  @override
  String get assistantEditConfigureButton => "تهيئة";

  @override
  String get assistantEditMaxTokensTitle => "الحد الأقصى للرموز";

  @override
  String get assistantEditMaxTokensDescription => "اترك الحقل فارغًا للسماح بعدد غير محدود";

  @override
  String get assistantEditMaxTokensHint => "غير محدود";

  @override
  String get assistantEditChatBackgroundTitle => "خلفية المحادثة";

  @override
  String get assistantEditChatBackgroundDescription => "تعيين صورة خلفية لهذا المساعد";

  @override
  String get assistantEditChooseImageButton => "اختيار صورة";

  @override
  String get assistantEditClearButton => "مسح";

  @override
  String get desktopNavChatTooltip => "المحادثة";

  @override
  String get desktopNavTranslateTooltip => "الترجمة";

  @override
  String get desktopNavStorageTooltip => "التخزين";

  @override
  String get desktopNavGlobalSearchTooltip => "البحث العام";

  @override
  String get desktopNavThemeToggleTooltip => "السمة";

  @override
  String get desktopNavSettingsTooltip => "الإعدادات";

  @override
  String get desktopAvatarMenuUseEmoji => "استخدام رمز تعبيري";

  @override
  String get cameraPermissionDeniedMessage => "تعذّر استخدام الكاميرا: لم يتم منح الإذن.";

  @override
  String get openSystemSettings => "فتح الإعدادات";

  @override
  String get desktopAvatarMenuChangeFromImage => "التغيير من صورة…";

  @override
  String get desktopAvatarMenuReset => "إعادة تعيين الصورة الرمزية";

  @override
  String get assistantEditAvatarChooseImage => "اختيار صورة";

  @override
  String get assistantEditAvatarChooseEmoji => "اختيار رمز تعبيري";

  @override
  String get assistantEditAvatarEnterLink => "إدخال رابط";

  @override
  String get assistantEditAvatarImportQQ => "استيراد من QQ";

  @override
  String get assistantEditAvatarReset => "إعادة تعيين";

  @override
  String get displaySettingsPageChatMessageBackgroundTitle => "خلفية رسائل المحادثة";

  @override
  String get displaySettingsPageChatMessageBackgroundDefault => "افتراضية";

  @override
  String get displaySettingsPageChatMessageBackgroundFrosted => "زجاج مصنفر";

  @override
  String get displaySettingsPageChatMessageBackgroundSolid => "لون ثابت";

  @override
  String get displaySettingsPageAndroidBackgroundChatTitle => "التوليد في الخلفية (Android)";

  @override
  String get displaySettingsPageIosBackgroundChatTitle => "التوليد في الخلفية (iOS)";

  @override
  String get iosBackgroundStatusOn => "مفعّل";

  @override
  String get iosBackgroundStatusOff => "متوقف";

  @override
  String get iosLiveActivityTitle => "النشاط المباشر";

  @override
  String get iosLiveActivitySubtitle => "اعرض الردود التي تُولّد في الخلفية على شاشة القفل والجزيرة الديناميكية عند دعم الجهاز لذلك.";

  @override
  String get notificationChatCompletedTitle => "اكتمل التوليد";

  @override
  String get notificationChatCompletedBody => "تم إنشاء رد المساعد";

  @override
  String get assistantEditEmojiDialogTitle => "اختيار رمز تعبيري";

  @override
  String get assistantEditEmojiDialogHint => "اكتب أي رمز تعبيري أو الصقه";

  @override
  String get assistantEditEmojiDialogCancel => "إلغاء";

  @override
  String get assistantEditEmojiDialogSave => "حفظ";

  @override
  String get assistantEditImageUrlDialogTitle => "إدخال رابط الصورة";

  @override
  String get assistantEditImageUrlDialogHint => "مثال: https://example.com/avatar.png";

  @override
  String get assistantEditImageUrlDialogCancel => "إلغاء";

  @override
  String get assistantEditImageUrlDialogSave => "حفظ";

  @override
  String get assistantEditQQAvatarDialogTitle => "استيراد من QQ";

  @override
  String get assistantEditQQAvatarDialogHint => "أدخل رقم QQ (من 5 إلى 12 رقمًا)";

  @override
  String get assistantEditQQAvatarRandomButton => "اختيار عشوائي";

  @override
  String get assistantEditQQAvatarFailedMessage => "تعذّر جلب صورة رمزية عشوائية من QQ. حاول مرة أخرى.";

  @override
  String get assistantEditQQAvatarDialogCancel => "إلغاء";

  @override
  String get assistantEditQQAvatarDialogSave => "حفظ";

  @override
  String get assistantEditGalleryErrorMessage => "تعذّر فتح المعرض. جرّب إدخال رابط صورة.";

  @override
  String get assistantEditGeneralErrorMessage => "حدث خطأ ما. جرّب إدخال رابط صورة.";

  @override
  String get providerDetailPageMultiKeyModeTitle => "وضع المفاتيح المتعددة";

  @override
  String get providerDetailPageManageKeysButton => "إدارة المفاتيح";

  @override
  String get multiKeyPageTitle => "مدير المفاتيح المتعددة";

  @override
  String get multiKeyPageDetect => "اكتشاف";

  @override
  String get multiKeyPageAdd => "إضافة";

  @override
  String get multiKeyPageAddHint => "أدخل مفاتيح API مفصولة بفاصلة أو بمسافة";

  @override
  String multiKeyPageImportedSnackbar(int n) => "تم استيراد ${n} من المفاتيح";

  @override
  String get multiKeyPagePleaseAddModel => "أضف نموذجًا أولًا";

  @override
  String get multiKeyPageTotal => "الإجمالي";

  @override
  String get multiKeyPageNormal => "طبيعي";

  @override
  String get multiKeyPageError => "خطأ";

  @override
  String get multiKeyPageAccuracy => "الدقة";

  @override
  String get multiKeyPageStrategyTitle => "استراتيجية توزيع الحمل";

  @override
  String get multiKeyPageStrategyRoundRobin => "بالتناوب";

  @override
  String get multiKeyPageStrategyPriority => "حسب الأولوية";

  @override
  String get multiKeyPageStrategyLeastUsed => "الأقل استخدامًا";

  @override
  String get multiKeyPageStrategyRandom => "عشوائي";

  @override
  String get multiKeyPageNoKeys => "لا توجد مفاتيح API";

  @override
  String get multiKeyPageStatusActive => "نشط";

  @override
  String get multiKeyPageStatusDisabled => "معطّل";

  @override
  String get multiKeyPageStatusError => "خطأ";

  @override
  String get multiKeyPageStatusRateLimited => "تم بلوغ حد الطلبات";

  @override
  String get multiKeyPageEditAlias => "تعديل الاسم المستعار";

  @override
  String get multiKeyPageEdit => "تعديل";

  @override
  String get multiKeyPageKey => "مفتاح API";

  @override
  String get multiKeyPagePriority => "الأولوية (1–10)";

  @override
  String get multiKeyPageDuplicateKeyWarning => "هذا المفتاح موجود بالفعل";

  @override
  String get multiKeyPageAlias => "الاسم المستعار";

  @override
  String get multiKeyPageCancel => "إلغاء";

  @override
  String get multiKeyPageSave => "حفظ";

  @override
  String get multiKeyPageDelete => "حذف";

  @override
  String get assistantEditSystemPromptTitle => "تعليمات النظام";

  @override
  String get assistantEditSystemPromptHint => "أدخل تعليمات النظام…";

  @override
  String get assistantEditSystemPromptImportButton => "استيراد ملف";

  @override
  String get assistantEditSystemPromptImportSuccess => "تم تحديث تعليمات النظام من الملف";

  @override
  String get assistantEditSystemPromptImportFailed => "تعذّر استيراد الملف";

  @override
  String get assistantEditSystemPromptImportEmpty => "الملف فارغ";

  @override
  String get assistantEditAvailableVariables => "المتغيرات المتاحة:";

  @override
  String get assistantEditVariableDate => "التاريخ";

  @override
  String get assistantEditVariableTime => "الوقت";

  @override
  String get assistantEditVariableDatetime => "التاريخ والوقت";

  @override
  String get assistantEditVariableModelId => "معرّف النموذج";

  @override
  String get assistantEditVariableModelName => "اسم النموذج";

  @override
  String get assistantEditVariableLocale => "الإعدادات المحلية";

  @override
  String get assistantEditVariableTimezone => "المنطقة الزمنية";

  @override
  String get assistantEditVariableSystemVersion => "إصدار النظام";

  @override
  String get assistantEditVariableDeviceInfo => "معلومات الجهاز";

  @override
  String get assistantEditVariableBatteryLevel => "مستوى البطارية";

  @override
  String get assistantEditVariableNickname => "الاسم المستعار";

  @override
  String get assistantEditVariableAssistantName => "اسم المساعد";

  @override
  String get assistantEditMessageTemplateTitle => "قالب الرسالة";

  @override
  String get assistantEditVariableRole => "الدور";

  @override
  String get assistantEditVariableMessage => "الرسالة";

  @override
  String get assistantEditPreviewTitle => "معاينة";

  @override
  String get assistantEditPromptTimeVarWarning => "يؤدي استخدام متغيرات الوقت في تعليمات النظام إلى اختلاف بداية كل طلب، مما يمنع الاستفادة من تخزين التعليمات مؤقتًا ويرفع التكلفة ومدة انتظار أول رمز. إذا احتاج النموذج إلى معرفة الوقت الحالي، فاستخدم مفتاح «إلحاق الوقت الحالي» أدناه.";

  @override
  String get assistantEditPromptIso8601Title => "استخدام تنسيق ISO 8601";

  @override
  String get assistantEditPromptIso8601Subtitle => "تضمين فرق المنطقة الزمنية، مثال: 2026-08-08T14:30:05+08:00";

  @override
  String get assistantEditPromptAppendTimeTitle => "إلحاق الوقت الحالي";

  @override
  String get assistantEditPromptAppendTimeSubtitle => "إلحاق وقت الإرسال بنهاية كل رسالة من المستخدم. يبقى الوقت في نهاية الطلب، لذلك لا يتأثر التخزين المؤقت للتعليمات.";

  @override
  String get assistantEditPromptAppendTimeInfoTitle => "تنسيق الوقت المُضاف";

  @override
  String assistantEditPromptAppendTimeInfoBody(String example) => "عند التفعيل، يُضاف سطر فارغ ثم الوسم التالي في نهاية كل رسالة من المستخدم:\n\n${example}\n\nالطابع الزمني هو وقت إرسال تلك الرسالة نفسها، لذلك يظل ثابتًا عند إعادة المحاولة.";

  @override
  String get assistantEditPromptAppendTimeInfoClose => "فهمت";

  @override
  String get assistantEditPromptTimeVarDialogTitle => "تحتوي تعليمات النظام على متغيرات وقت";

  @override
  String assistantEditPromptTimeVarDialogBody(String variables) => "تستخدم تعليمات النظام متغيرات ${variables}. تُعاد معالجة تعليمات النظام عند كل طلب، لذا تجعل متغيرات الوقت بداية كل طلب مختلفة وتمنع الاستفادة من التخزين المؤقت للتعليمات. فكّر في إزالة هذه المتغيرات واستخدام «إلحاق الوقت الحالي» بدلًا منها؛ إذ يضيف الوقت في نهاية الطلب ولا يؤثر في بادئته.";

  @override
  String get assistantEditPromptTimeVarDialogRemove => "الانتقال للإزالة";

  @override
  String get assistantEditPromptTimeVarDialogKeep => "التفعيل على أي حال";

  @override
  String get codeBlockPreviewButton => "معاينة";

  @override
  String get codeBlockSaveAsButton => "حفظ باسم ملف";

  @override
  String get codeBlockCollapseButton => "طيّ";

  @override
  String get codeBlockExpandButton => "توسيع";

  @override
  String get markdownTableLabel => "جدول";

  @override
  String get markdownTableExportCsvTooltip => "تصدير CSV";

  @override
  String get markdownTableSaveImageTooltip => "حفظ في المعرض";

  @override
  String get markdownTableCopiedCsvSnackbar => "تم نسخ CSV. اضغط مطولًا على «نسخ» لنسخ الجدول كصورة.";

  @override
  String get markdownTableCopiedMarkdownSnackbar => "تم نسخ الجدول.";

  @override
  String codeBlockCollapsedLines(int n) => "تم طيّ ${n} من الأسطر";

  @override
  String get htmlPreviewNotSupportedOnLinux => "معاينة HTML غير مدعومة على Linux";

  @override
  String get assistantEditSampleUser => "المستخدم";

  @override
  String get assistantEditSampleMessage => "مرحبًا";

  @override
  String get assistantEditSampleReply => "مرحبًا، كيف يمكنني مساعدتك؟";

  @override
  String get assistantEditMcpNoServersMessage => "لا توجد خوادم MCP قيد التشغيل";

  @override
  String get assistantEditMcpConnectedTag => "متصل";

  @override
  String assistantEditMcpToolsCountTag(String enabled, String total) => "الأدوات: ${enabled}/${total}";

  @override
  String get assistantEditModelUseGlobalDefault => "استخدام الإعداد الافتراضي العام";

  @override
  String get assistantSettingsPageTitle => "إعدادات المساعد";

  @override
  String get assistantSettingsCopyButton => "نسخ";

  @override
  String get assistantSettingsCopySuccess => "تم نسخ المساعد";

  @override
  String get assistantSettingsCopySuffix => "نسخة";

  @override
  String get assistantCopyTitle => "نسخ المساعد";

  @override
  String get assistantCopyDefaultHint => "اختر ما تريد نسخه، أو انسخ كل شيء.";

  @override
  String get assistantCopyConfiguration => "إعدادات المساعد";

  @override
  String get assistantCopyConfigurationHint => "تُضمّن دائمًا: الاسم والصورة الرمزية والتعليمات والنموذج والمعلمات والرسائل المعدّة مسبقًا.";

  @override
  String get assistantCopyMemories => "ذكريات المساعد";

  @override
  String get assistantCopyMemoriesHint => "تشمل الذكريات الحالية والقديمة مع الاحتفاظ بحالة الأرشفة. وتظل الذكريات العامة مشتركة.";

  @override
  String get assistantCopyChooseMemories => "اختيار الذكريات";

  @override
  String get assistantCopyChooseEntries => "اختيار العناصر";

  @override
  String get assistantCopyPhrasesHint => "انسخ عبارات هذا المساعد. وتظل العبارات العامة مشتركة.";

  @override
  String get assistantCopyBindingsHint => "تعيد هذه الخيارات استخدام الموارد الموجودة؛ ولا تُنسخ ملفات مساحة العمل. وتستخدم دفاتر العالم وعمليات إدراج التعليمات غير المحددة الإعدادات العامة.";

  @override
  String get assistantCopyWorldBooks => "ارتباطات دفاتر العالم";

  @override
  String get assistantCopySkills => "اختيار المهارات";

  @override
  String get assistantCopyTools => "إعدادات الأدوات والبحث";

  @override
  String get assistantCopyWorkspace => "ربط مساحة العمل الافتراضية";

  @override
  String get assistantCopyAll => "نسخ الكل";

  @override
  String get assistantCopyInProgress => "جارٍ النسخ…";

  @override
  String get assistantCopyFailed => "تعذّر نسخ المساعد. لم تتغير بياناتك الأصلية. حاول مرة أخرى.";

  @override
  String get assistantCopyMemoryLoadFailed => "تعذّر تحميل الذكريات. حاول مرة أخرى.";

  @override
  String get assistantCopyRetry => "إعادة المحاولة";

  @override
  String get assistantCopyNoMemories => "لا توجد ذكريات شخصية لهذا المساعد لنسخها.";

  @override
  String get assistantCopySelectAll => "تحديد جميع الذكريات";

  @override
  String get assistantSettingsDeleteButton => "حذف";

  @override
  String get assistantSettingsEditButton => "تعديل";

  @override
  String get assistantSettingsAddSheetTitle => "اسم المساعد";

  @override
  String get assistantSettingsAddSheetHint => "أدخل اسمًا";

  @override
  String get assistantSettingsAddSheetCancel => "إلغاء";

  @override
  String get assistantSettingsAddSheetSave => "حفظ";

  @override
  String get desktopAssistantsListTitle => "المساعدون";

  @override
  String get desktopSidebarTabAssistants => "المساعدون";

  @override
  String get desktopSidebarTabTopics => "المواضيع";

  @override
  String get desktopTrayMenuShowWindow => "إظهار النافذة";

  @override
  String get desktopTrayMenuExit => "خروج";

  @override
  String get hotkeyToggleAppVisibility => "إظهار/إخفاء التطبيق";

  @override
  String get hotkeyCloseWindow => "إغلاق النافذة";

  @override
  String get hotkeyOpenSettings => "فتح الإعدادات";

  @override
  String get hotkeyNewTopic => "موضوع جديد";

  @override
  String get hotkeySwitchModel => "تبديل النموذج";

  @override
  String get hotkeyToggleAssistantPanel => "إظهار/إخفاء لوحة المساعدين";

  @override
  String get hotkeyToggleTopicPanel => "إظهار/إخفاء لوحة المواضيع";

  @override
  String get hotkeysPressShortcut => "اضغط اختصارًا";

  @override
  String get hotkeysResetDefault => "استعادة الإعداد الافتراضي";

  @override
  String get hotkeysClearShortcut => "مسح الاختصار";

  @override
  String get hotkeysResetAll => "إعادة تعيين جميع الاختصارات إلى الإعدادات الافتراضية";

  @override
  String get assistantEditTemperatureTitle => "درجة الحرارة";

  @override
  String get assistantSettingsDeleteDialogTitle => "حذف المساعد";

  @override
  String get assistantSettingsDeleteDialogContent => "هل تريد بالتأكيد حذف هذا المساعد؟ لا يمكن التراجع عن هذا الإجراء.";

  @override
  String get assistantSettingsDeleteDialogCancel => "إلغاء";

  @override
  String get assistantSettingsDeleteDialogConfirm => "حذف";

  @override
  String get assistantSettingsAtLeastOneAssistantRequired => "يجب الاحتفاظ بمساعد واحد على الأقل.";

  @override
  String get assistantConversationMcpTitle => "السماح بتخصيص MCP لكل محادثة";

  @override
  String get assistantConversationMcpHint => "اسمح للمحادثات باختيار خوادم MCP الخاصة بها. تستخدم المحادثة اختيار المساعد ما لم يتم تخصيصه.";

  @override
  String get mcpSelectionInherited => "استخدام إعدادات المساعد";

  @override
  String get mcpSelectionCustom => "مخصص لهذه المحادثة";

  @override
  String get mcpInheritAssistant => "استخدام إعدادات المساعد";

  @override
  String get mcpAssistantSheetTitle => "خوادم MCP";

  @override
  String get mcpAssistantSheetSubtitle => "الخوادم المفعّلة لهذا المساعد";

  @override
  String get mcpAssistantSheetSelectAll => "تحديد الكل";

  @override
  String get mcpAssistantSheetClearAll => "مسح التحديد";

  @override
  String get backupPageTitle => "النسخ الاحتياطي والاستعادة";

  @override
  String get backupPageImportExportTab => "استيراد وتصدير";

  @override
  String get backupPageWebDavServerUrl => "عنوان خادم WebDAV";

  @override
  String get backupPageUsername => "اسم المستخدم";

  @override
  String get backupPagePassword => "كلمة المرور";

  @override
  String get backupPagePath => "المسار";

  @override
  String get backupPageChatsLabel => "المحادثات";

  @override
  String get backupPageFilesLabel => "الملفات";

  @override
  String get backupPageScopeTitle => "محتويات النسخ الاحتياطي والاستيراد";

  @override
  String backupPageScopeSelectedCount(int selected, int total) => "${selected} من ${total}";

  @override
  String get backupPageBackupManagementDescription => "اختر العناصر المطلوب نسخها احتياطيًا أو استيرادها. ينطبق ذلك على النسخ المحلية وWebDAV وS3. تبقى العناصر غير المحددة دون تغيير عند الاستيراد. تتضمن المهارات ومساحات العمل ملفاتها الخاصة.";

  @override
  String get backupPageAssistantsLabel => "المساعدون";

  @override
  String get backupPageProvidersLabel => "مزوّدو الخدمة";

  @override
  String get backupPageMcpLabel => "خوادم MCP";

  @override
  String get backupPageEnvironmentVariablesLabel => "متغيرات البيئة";

  @override
  String get backupPageSkillsLabel => "المهارات";

  @override
  String get backupPageWorldBooksLabel => "الكتب المعرفية";

  @override
  String get backupPageMemoriesLabel => "الذكريات";

  @override
  String get backupPageQuickPhrasesLabel => "العبارات السريعة";

  @override
  String get backupPageInstructionsLabel => "تعليمات النظام";

  @override
  String get backupPageWorkspacesLabel => "مساحات العمل";

  @override
  String get backupPageSearchServicesLabel => "خدمات البحث";

  @override
  String get backupPageSpeechServicesLabel => "خدمات الكلام";

  @override
  String get backupPageSettingsLabel => "الإعدادات الأخرى";

  @override
  String get backupPageTestDone => "اكتمل الاختبار";

  @override
  String get backupPageTestConnection => "اختبار الاتصال";

  @override
  String get backupPageRestartRequired => "يلزم إعادة التشغيل";

  @override
  String get backupPageRestartContent => "تم الاستيراد بنجاح. أعد تشغيل Kelivo لتطبيق التغييرات بأمان.";

  @override
  String backupPageRestartContentWithSkipped(int count) => "اكتمل الاستيراد، ولكن تم تخطي ${count} محادثة بسبب ترتيب رسائل غير صالح. أعد تشغيل Kelivo لتطبيق البيانات المستوردة بأمان.";

  @override
  String get restartAppFailedMessage => "تعذّر على Kelivo إعادة التشغيل تلقائيًا. أغلق التطبيق بالكامل ثم افتحه مجددًا.";

  @override
  String get backupRestoreRolledBackTitle => "تم التراجع عن الاستعادة";

  @override
  String get backupRestoreRolledBackContent => "تعذّر إكمال الاستعادة. تحقّق Kelivo من بياناتك السابقة واحتفظ بها.";

  @override
  String get backupRestoreDirectoryBlockedTitle => "الاستعادة بانتظار إتاحة مجلد";

  @override
  String get backupRestoreDirectoryBlockedContent => "تعذّر على Windows نقل المجلد الموضح أدناه. أغلق الطرفيات أو المحررات أو البرامج الأخرى التي تستخدمه، ثم تابع الاستعادة. إذا استمر التعذّر، فتحقق من أن حسابك يملك صلاحية نقل المجلد. تم الاحتفاظ بتقدم الاستعادة.";

  @override
  String get backupRestoreContinueButton => "متابعة الاستعادة";

  @override
  String get backupRestoreFailureTitle => "الاستعادة تتطلب انتباهك";

  @override
  String get backupRestoreFailureContent => "تعذّر على Kelivo التحقق من اكتمال مجموعة البيانات القديمة أو الجديدة، لذلك لم تُفتح بيانات المحادثات. أغلق Kelivo وحاول مجددًا. إذا تكرر الأمر، احتفظ برمز التشخيص للتواصل مع الدعم.";

  @override
  String get backupRestoreBusinessLeaseUnavailableTitle => "Kelivo قيد التشغيل بالفعل";

  @override
  String get backupRestoreBusinessLeaseUnavailableContent => "لا تزال بيانات Kelivo قيد الاستخدام بواسطة عملية أخرى للتطبيق. أغلق أي نافذة أخرى لـ Kelivo ثم أعد التشغيل. لم تفتح هذه العملية بيانات محادثاتك.";

  @override
  String get restoreProgressTitle => "جارٍ استعادة النسخة الاحتياطية";

  @override
  String get restoreProgressWarning => "أبقِ Kelivo مفتوحًا حتى تكتمل العملية. إذا أغلقته الآن، فستبدأ العملية من جديد عند التشغيل التالي.";

  @override
  String get restoreProgressStageCheckingBackup => "فحص النسخة الاحتياطية";

  @override
  String get restoreProgressStagePreservingCurrentData => "حفظ بياناتك الحالية";

  @override
  String get restoreProgressStageInstallingBackup => "تثبيت النسخة الاحتياطية";

  @override
  String get restoreProgressStageVerifying => "التحقق";

  @override
  String get restoreProgressStageRollingBack => "استعادة بياناتك السابقة";

  @override
  String get restoreProgressStageFinishing => "إنهاء العملية";

  @override
  String get backupRestoreFailureRestartButton => "إعادة تشغيل Kelivo";

  @override
  String get backupRestoreFailureCopyButton => "نسخ رمز التشخيص";

  @override
  String get backupRestoreFailureCopied => "تم نسخ رمز التشخيص";

  @override
  String backupRestoreFailureDiagnostic(String code) => "رمز التشخيص: ${code}";

  @override
  String get startupRecoveryMoreOptions => "مزيد من خيارات الاسترداد";

  @override
  String get startupRecoveryRepairButton => "إصلاح وإعادة التشغيل";

  @override
  String get startupRecoveryExportButton => "تصدير نسخة من بياناتي";

  @override
  String get startupRecoveryResetButton => "البدء بقائمة محادثات فارغة";

  @override
  String get startupRecoveryBusy => "جارٍ التنفيذ…";

  @override
  String get startupRecoveryExportSucceeded => "تم حفظ نسخة من بياناتك.";

  @override
  String get startupRecoveryExportFailed => "تعذّر تصدير نسخة من بياناتك.";

  @override
  String get startupRecoveryRepairFailed => "تعذّر إكمال الإصلاح. بياناتك محفوظة؛ اختر نسخة تم التحقق منها أو صدّر بياناتك لمزيد من التشخيص.";

  @override
  String get startupRecoveryResetFailed => "تعذّرت إعادة الضبط. أغلق Kelivo بالكامل ثم افتحه مجددًا.";

  @override
  String get startupRecoveryResetDialogTitle => "البدء بقائمة محادثات فارغة؟";

  @override
  String get startupRecoveryResetDialogContent => "لن يؤدي هذا إلى استعادة محادثاتك السابقة. سيحتفظ Kelivo بقاعدة البيانات الحالية والنسخ الموجودة، ويبدأ بقائمة محادثات جديدة وفارغة. لاستعادة محادثاتك، ألغِ العملية واختر نسخة محلية.";

  @override
  String get startupRecoveryResetDialogConfirm => "الاحتفاظ بالنسخ والبدء من جديد";

  @override
  String get startupRecoveryResetDialogCancel => "إلغاء";

  @override
  String get startupRecoveryWhatFailed => "ما الذي تعذّر؟";

  @override
  String get startupRecoveryStageLabel => "المرحلة";

  @override
  String get startupRecoveryStageRestore => "بوابة الاستعادة";

  @override
  String get startupRecoveryStageDatabase => "بدء قاعدة البيانات";

  @override
  String get startupRecoveryDiagnosticLabel => "رمز التشخيص";

  @override
  String get startupRecoverySchemaLabel => "إصدار قاعدة البيانات";

  @override
  String startupRecoverySchemaValue(String installed, int expected) => "${installed} على القرص · المتوقع في هذا الإصدار ${expected}";

  @override
  String get startupRecoveryAppVersionLabel => "التطبيق";

  @override
  String get startupRecoveryUnknownValue => "غير معروف";

  @override
  String get startupRecoveryCollecting => "جارٍ جمع معلومات التشخيص…";

  @override
  String get startupRecoveryShowDetails => "عرض التفاصيل التقنية";

  @override
  String get startupRecoveryHideDetails => "إخفاء التفاصيل التقنية";

  @override
  String get startupRecoveryCopyReport => "نسخ التقرير الكامل";

  @override
  String get startupRecoveryReportCopied => "تم نسخ التقرير الكامل";

  @override
  String get startupRecoveryShareReport => "تصدير التقرير";

  @override
  String startupRecoveryReportStored(String path) => "تم حفظ نسخة من التقرير في ${path}";

  @override
  String startupRecoveryReportSaved(String path) => "تم حفظ التقرير في ${path}";

  @override
  String get startupRecoveryReportShared => "تم تصدير التقرير.";

  @override
  String get startupRecoveryReportSaveFailed => "تعذّر تصدير التقرير.";

  @override
  String get startupRecoverySectionDataTitle => "بياناتك";

  @override
  String get startupRecoverySectionDataBody => "يمكنك أيضًا تصدير البيانات المتبقية وحفظها في مكان آمن قبل المتابعة.";

  @override
  String startupRecoveryExportSavedTo(String path) => "تم حفظ نسخة من بياناتك في ${path}";

  @override
  String get startupRecoverySectionRepairTitle => "التشخيص والإصلاح";

  @override
  String get startupRecoverySectionRepairBody => "يفحص التحقق من السلامة قاعدة البيانات للقراءة فقط. يمسح الإصلاح البيانات الوصفية المتبقية من تحديث غير مكتمل ثم يعيد محاولة التشغيل؛ ولا يحذف المحادثات مطلقًا.";

  @override
  String get startupRecoveryIntegrityButton => "فحص سلامة قاعدة البيانات";

  @override
  String get startupRecoveryIntegrityHealthy => "لم يعثر SQLite على أي تلف في ملف قاعدة البيانات.";

  @override
  String startupRecoveryIntegrityDamaged(String detail) => "أبلغ SQLite عن مشكلات — ${detail}";

  @override
  String get startupRecoveryIntegrityMissing => "لم يُعثر على ملف قاعدة بيانات في مجلد البيانات.";

  @override
  String get startupRecoveryIntegrityFailed => "تعذّر تشغيل فحص السلامة.";

  @override
  String get startupRecoveryDangerZone => "خيارات أخرى";

  @override
  String get startupRecoveryDangerBody => "يؤدي البدء من جديد إلى إخفاء البيانات الحالية عن العرض. سيحتفظ Kelivo بقاعدة البيانات القديمة والنسخ الموجودة لاستعادتها لاحقًا. صدّر نسخة من بياناتك أولًا إن أمكن.";

  @override
  String get startupRecoveryResetAcknowledge => "أختار المتابعة بقائمة محادثات فارغة دون استعادة محادثاتي الآن.";

  @override
  String get startupDatabaseUpdateRequiredTitle => "حدّث Kelivo للمتابعة";

  @override
  String get startupDatabaseUpdateRequiredContent => "أُنشئت قاعدة بيانات المحادثات على هذا الجهاز بإصدار أحدث من Kelivo، ولا يمكن لهذا الإصدار فتحها. لم يتم تغيير بياناتك. ثبّت أحدث إصدار من Kelivo ثم افتحه مجددًا.";

  @override
  String get startupDatabaseUpdateRequiredDowngradeTitle => "إذا كنت بحاجة إلى إصدار أقدم";

  @override
  String get startupDatabaseUpdateRequiredDowngradeIntro => "لا يستطيع هذا الإصدار فتح قاعدة البيانات على جهازك. إذا كان لا بد من استخدام إصدار أقدم، فاتبع الخطوات أدناه. لا تحذف البيانات الموجودة هنا أو تستبدلها قبل إنشاء نسخة احتياطية.";

  @override
  String get startupDatabaseUpdateRequiredDowngradeStep1 => "ثبّت أحدث إصدار من Kelivo وافتحه، ثم صدّر نسخة احتياطية من الإعدادات ← النسخ الاحتياطي.";

  @override
  String startupDatabaseUpdateRequiredDowngradeStep2(String url) => "افتح ${url} وحوّل تلك النسخة الاحتياطية إلى الإصدار الأقدم الذي تريد استخدامه.";

  @override
  String get startupDatabaseUpdateRequiredDowngradeStep3 => "بعد التأكد من وجود نسخة احتياطية من بيانات هذا الجهاز، ثبّت الإصدار الأقدم واستورد النسخة المحوّلة.";

  @override
  String get startupDatabaseUpdateRequiredOpenTool => "فتح أداة التحويل";

  @override
  String backupPageRestoreFailedMessage(String error) => "فشلت الاستعادة: ${error}";

  @override
  String backupPageExportFailedMessage(String error) => "فشل التصدير: ${error}";

  @override
  String get backupPageOK => "موافق";

  @override
  String get backupPageCancel => "إلغاء";

  @override
  String get backupPageSelectImportMode => "اختيار وضع الاستيراد";

  @override
  String get backupPageSelectImportModeDescription => "اختر وضع الاستعادة. تنطبق مفاتيح إدارة النسخ الاحتياطية على عملية الاستيراد هذه.";

  @override
  String get backupPageOverwriteMode => "استبدال كامل";

  @override
  String get backupPageOverwriteModeDescription => "استبدل المكونات المحددة، واحتفظ بالمكونات غير المحددة والإعدادات المحلية غير المرتبطة. يؤدي استبدال المحادثات أيضًا إلى مسح المسودات المحلية غير المرسلة.";

  @override
  String get backupPageMergeMode => "دمج";

  @override
  String get backupPageMergeModeDescription => "احتفظ بالبيانات المحلية وأضف بيانات النسخة الاحتياطية. سيتم تخطي المحادثات المتطابقة وإسناد معرّفات جديدة للمحادثات المتعارضة.";

  @override
  String get backupPageRestore => "استعادة";

  @override
  String get backupPageForwardCompatTitle => "النسخة الاحتياطية من إصدار أحدث";

  @override
  String backupPageForwardCompatBody(int backupVersion, int currentVersion) => "أُنشئت هذه النسخة الاحتياطية بإصدار أحدث من Kelivo (تنسيق البيانات ${backupVersion}؛ بينما يدعم هذا الإصدار ${currentVersion})، ولا توضح ما إذا كانت الإصدارات الأقدم تستطيع قراءتها.\n\nيمكنك المتابعة: سيتم تخطي أي عناصر لا يتعرف عليها هذا الإصدار، ولن يتم تعديل ملف النسخة الاحتياطية نفسه. لكن إذا غيّر الإصدار الأحدث طريقة تخزين البيانات الحالية، فقد يُستورد بعض المحتوى بصورة غير صحيحة.\n\nتحديث Kelivo أولًا هو الخيار الأكثر أمانًا.";

  @override
  String get backupPageForwardCompatContinue => "استيراد على أي حال";

  @override
  String get backupPageForwardCompatCancel => "إلغاء";

  @override
  String get backupPageSchemaTooNewMessage => "أُنشئت هذه النسخة الاحتياطية بإصدار أحدث من Kelivo ولا يمكن قراءتها بهذا الإصدار. حدّث Kelivo ثم حاول مجددًا.";

  @override
  String get backupPageBackupUploaded => "تم رفع النسخة الاحتياطية";

  @override
  String get backupPageBackup => "نسخ احتياطي";

  @override
  String get backupPageExporting => "جارٍ التصدير…";

  @override
  String get backupProgressCancel => "إلغاء";

  @override
  String get backupProgressCancelled => "تم الإلغاء";

  @override
  String get backupProgressFailed => "فشلت العملية";

  @override
  String backupProgressFailedAt(String phase) => "حدث الفشل أثناء: ${phase}";

  @override
  String get backupProgressCopyError => "نسخ الخطأ";

  @override
  String get backupProgressErrorCopied => "تم نسخ الخطأ";

  @override
  String get backupProgressPreparing => "جارٍ التحضير";

  @override
  String get backupProgressSnapshotting => "إنشاء لقطة لقاعدة البيانات";

  @override
  String get backupProgressPacking => "جارٍ التجميع";

  @override
  String get backupProgressVerifying => "جارٍ التحقق";

  @override
  String get backupProgressUploading => "جارٍ الرفع";

  @override
  String get backupProgressDownloading => "جارٍ التنزيل";

  @override
  String get backupProgressExtracting => "جارٍ الاستخراج";

  @override
  String get backupProgressValidating => "جارٍ التحقق من الصحة";

  @override
  String get backupProgressReadingSettings => "جارٍ قراءة الإعدادات";

  @override
  String get backupProgressStaging => "جارٍ التجهيز";

  @override
  String get backupProgressCommitting => "جارٍ اعتماد التغييرات";

  @override
  String get backupProgressImportingSessions => "جارٍ استيراد الجلسات";

  @override
  String get backupProgressImportingMessages => "جارٍ استيراد الرسائل";

  @override
  String get backupProgressMaterializingFiles => "جارٍ كتابة الملفات";

  @override
  String get backupProgressListingRemote => "جارٍ عرض النسخ الاحتياطية البعيدة";

  @override
  String get backupProgressFinalizing => "جارٍ الإنهاء";

  @override
  String get backupPageExportToFile => "تصدير إلى ملف";

  @override
  String get backupPageExportToFileSubtitle => "تصدير بيانات التطبيق إلى ملف";

  @override
  String get backupPageImportBackupFile => "استيراد ملف نسخة احتياطية";

  @override
  String get backupPageImportBackupFileSubtitle => "استيراد ملف نسخة احتياطية محلي";

  @override
  String get backupPageImportFromOtherApps => "الاستيراد من تطبيقات أخرى";

  @override
  String get backupPageNotSupportedYet => "غير مدعوم حاليًا";

  @override
  String get backupPageRemoteBackups => "النسخ الاحتياطية البعيدة";

  @override
  String get backupPageNoBackups => "لا توجد نسخ احتياطية";

  @override
  String get backupPageRestoreTooltip => "استعادة";

  @override
  String get backupPageDeleteTooltip => "حذف";

  @override
  String get backupPageDeleteConfirmTitle => "تأكيد الحذف";

  @override
  String backupPageDeleteConfirmContent(Object name) => "هل تريد بالتأكيد حذف النسخة الاحتياطية البعيدة \"${name}\"؟ لا يمكن التراجع عن هذا الإجراء.";

  @override
  String get backupPageBackupManagement => "إدارة النسخ الاحتياطية";

  @override
  String get backupPageWebDavBackup => "نسخ WebDAV احتياطيًا";

  @override
  String get backupPageWebDavServerSettings => "إعدادات خادم WebDAV";

  @override
  String get backupPageS3Backup => "نسخ S3 احتياطيًا";

  @override
  String get backupPageS3ServerSettings => "إعدادات S3";

  @override
  String get backupPageS3Endpoint => "نقطة النهاية";

  @override
  String get backupPageS3Region => "المنطقة";

  @override
  String get backupPageS3Bucket => "حاوية التخزين";

  @override
  String get backupPageS3AccessKeyId => "معرّف مفتاح الوصول";

  @override
  String get backupPageS3SecretAccessKey => "مفتاح الوصول السري";

  @override
  String get backupPageS3SessionToken => "رمز الجلسة (اختياري)";

  @override
  String get backupPageS3Prefix => "البادئة";

  @override
  String get backupPageS3PathStyle => "استخدام نمط المسار للعناوين";

  @override
  String get backupPageUserAgent => "وكيل المستخدم (User-Agent)";

  @override
  String get backupPageUserAgentHint => "اختياري";

  @override
  String get backupPageSave => "حفظ";

  @override
  String get backupPageBackupNow => "إنشاء نسخة احتياطية الآن";

  @override
  String get backupPageLocalBackup => "نسخة احتياطية محلية";

  @override
  String get backupPageIosSystemBackupNote => "تم إعداد بيانات Kelivo المحلية لاستبعادها من نسخ iCloud الاحتياطية للجهاز. صدّر ملف نسخة احتياطية قبل تغيير الجهاز أو حذف التطبيق.";

  @override
  String get backupPageImportFromCherryStudio => "استيراد من Cherry Studio";

  @override
  String backupPageCherryStudioUnsupportedBackupVersion(String version) => "تستخدم هذه النسخة الاحتياطية تنسيق Cherry Studio بالإصدار ${version}، وهو غير مدعوم للاستيراد في Kelivo حاليًا. صدّر النسخة من Cherry Studio v1 أو انتظر تحديثًا من Kelivo يدعم النسخ الاحتياطية من Cherry Studio v2.";

  @override
  String get backupPageImportFromChatbox => "استيراد من Chatbox";

  @override
  String get backupReminderSectionTitle => "التذكير بالنسخ الاحتياطي";

  @override
  String get backupReminderEnableTitle => "تذكيري بإنشاء نسخة احتياطية";

  @override
  String get backupReminderFrequencyTitle => "التكرار";

  @override
  String get backupReminderTimeTitle => "وقت التذكير";

  @override
  String get backupReminderTimeInvalid => "أدخل وقتًا بين 00:00 و23:59.";

  @override
  String get backupReminderLastBackupTitle => "آخر نسخة احتياطية";

  @override
  String get backupReminderNextReminderTitle => "موعد التذكير التالي";

  @override
  String get backupReminderNever => "أبدًا";

  @override
  String get backupReminderDisabled => "متوقف";

  @override
  String get backupReminderDueNow => "حان الموعد الآن";

  @override
  String get backupReminderEveryDay => "كل يوم";

  @override
  String get backupReminderEveryThreeDays => "كل 3 أيام";

  @override
  String get backupReminderEveryWeek => "كل أسبوع";

  @override
  String get backupReminderEveryFourteenDays => "كل 14 يومًا";

  @override
  String get backupReminderEveryMonth => "كل شهر";

  @override
  String backupReminderCustomDays(int days) => "كل ${days} يومًا";

  @override
  String get backupReminderCustomOption => "مخصص…";

  @override
  String get backupReminderCustomDialogTitle => "تكرار مخصص";

  @override
  String get backupReminderCustomDialogDescription => "أدخل عدد الأيام بين تذكيرات النسخ الاحتياطي.";

  @override
  String get backupReminderCustomDaysLabel => "الأيام";

  @override
  String get backupReminderCustomDaysInvalid => "أدخل رقمًا من 1 إلى 365.";

  @override
  String get backupReminderSidebarTitle => "التذكير بالنسخ الاحتياطي";

  @override
  String get backupReminderSidebarSubtitle => "حان موعد النسخ الاحتياطي وفق الفاصل الزمني المحدد.";

  @override
  String get backupReminderSidebarAction => "الانتقال إلى النسخ الاحتياطي";

  @override
  String get backupReminderSnoozeTooltip => "ذكّرني لاحقًا";

  @override
  String get chatHistoryPageTitle => "سجل المحادثات";

  @override
  String get chatHistoryPageSearchTooltip => "بحث";

  @override
  String get chatHistoryPageDeleteAllTooltip => "حذف المحادثات غير المثبّتة";

  @override
  String get chatHistoryPageDeleteAllDialogTitle => "حذف المحادثات غير المثبّتة";

  @override
  String get chatHistoryPageDeleteAllDialogContent => "هل تريد حذف جميع محادثات هذا المساعد غير المثبّتة؟ ستظل المحادثات المثبّتة كما هي.";

  @override
  String get chatHistoryPageCancel => "إلغاء";

  @override
  String get chatHistoryPageDelete => "حذف";

  @override
  String get chatHistoryPageDeletedAllSnackbar => "تم حذف المحادثات غير المثبّتة";

  @override
  String get chatHistoryPageSearchHint => "البحث في المحادثات";

  @override
  String get chatHistoryPageNoConversations => "لا توجد محادثات";

  @override
  String get chatHistoryPagePinnedSection => "المثبتة";

  @override
  String get chatHistoryPagePin => "تثبيت";

  @override
  String get chatHistoryPagePinned => "مثبّتة";

  @override
  String get messageEditPageTitle => "تعديل الرسالة";

  @override
  String get messageEditPageSave => "حفظ";

  @override
  String get messageEditPageSaveAndSend => "حفظ وإرسال";

  @override
  String get messageEditPageHint => "أدخل الرسالة…";

  @override
  String get userMessageEditSaveOnly => "حفظ فقط";

  @override
  String get userMessageEditUnsupportedSnackbar => "لا يمكن تعديل هذا المحتوى";

  @override
  String get userMessageEditOverwriteTitle => "تنبيه";

  @override
  String get userMessageEditOverwriteContent => "سيؤدي التعديل إلى استبدال النص الحالي. هل تريد المتابعة؟";

  @override
  String get selectCopyPageTitle => "تحديد ونسخ";

  @override
  String get selectCopyPageCopyAll => "نسخ الكل";

  @override
  String get selectCopyPageCopiedAll => "تم نسخ الكل";

  @override
  String get bottomToolsSheetCamera => "الكاميرا";

  @override
  String get bottomToolsSheetPhotos => "الصور";

  @override
  String get bottomToolsSheetUpload => "رفع";

  @override
  String get bottomToolsSheetClearContext => "مسح السياق";

  @override
  String get compressContext => "ضغط السياق";

  @override
  String get compressContextDesc => "إنشاء ملخص يمكنك مراجعته والتراجع عنه";

  @override
  String get clearContextDesc => "تحديد حد فاصل للسياق";

  @override
  String get contextManagement => "إدارة السياق";

  @override
  String get compressContextFailed => "تعذّر ضغط السياق";

  @override
  String get compressContextNoMessages => "لا توجد رسائل لضغطها";

  @override
  String get compressContextNoConversation => "لا توجد محادثة لضغطها";

  @override
  String get compressContextNoModel => "لم يتم إعداد نموذج للضغط";

  @override
  String get compressContextEmptySummary => "أعاد الضغط ملخصًا فارغًا";

  @override
  String get compressContextOptionsTitle => "ضغط السياق";

  @override
  String get compressContextOptionsDesc => "أنشئ ملخصًا قابلًا للتحرير والتراجع داخل هذه المحادثة. ستظل الرسائل الأصلية محفوظة.";

  @override
  String get compressContextKeepStart => "عينة البداية";

  @override
  String get compressContextKeepRecent => "عينة النهاية";

  @override
  String get compressContextUnlimited => "كل المحتوى";

  @override
  String get compressContextMaxCharsLabel => "عدد الأحرف";

  @override
  String get compressContextInvalidLimit => "أدخل عددًا موجبًا من الأحرف";

  @override
  String get compressContextStartButton => "ضغط";

  @override
  String get compressContextModelLabel => "النموذج";

  @override
  String get compressContextModelUnset => "اختيار نموذج";

  @override
  String get compressContextKeepRecentMessages => "الاحتفاظ بعدد N";

  @override
  String get compressContextKeepCountLabel => "رسائل المستخدم الأخيرة";

  @override
  String get compressContextKeepAllMessages => "هذا العدد يشمل جميع الرسائل، لذلك لا يوجد محتوى لضغطه";

  @override
  String compressContextEstimatePreview(int summarized, int kept, int minTokens, int maxTokens, int totalTokens) => "تلخيص ${summarized} حرفًا، والاحتفاظ بـ${kept} حرفًا كما هي → نحو ${minTokens}–${maxTokens} رمزًا (الأصل نحو ${totalTokens} رمز)";

  @override
  String get bottomToolsSheetLearningMode => "وضع التعلّم";

  @override
  String get bottomToolsSheetLearningModeDescription => "ساعدني على التعلّم خطوة بخطوة";

  @override
  String get bottomToolsSheetConfigurePrompt => "تهيئة التعليمات";

  @override
  String get bottomToolsSheetPrompt => "التعليمات";

  @override
  String get bottomToolsSheetPromptHint => "أدخل نص التعليمات المراد إدراجه";

  @override
  String get bottomToolsSheetResetDefault => "استعادة الإعداد الافتراضي";

  @override
  String get bottomToolsSheetSave => "حفظ";

  @override
  String get bottomToolsSheetOcr => "استخراج النص من الصورة (OCR)";

  @override
  String get messageMoreSheetTitle => "إجراءات إضافية";

  @override
  String get messageMoreSheetSelectCopy => "تحديد ونسخ";

  @override
  String get messageMoreSheetRenderWebView => "عرض صفحة الويب";

  @override
  String get messageMoreSheetNotImplemented => "لم تُنفّذ هذه الميزة بعد";

  @override
  String get messageMoreSheetEdit => "تعديل";

  @override
  String get messageMoreSheetShare => "مشاركة";

  @override
  String get messageMoreSheetSelectMessages => "تحديد الرسائل";

  @override
  String get messageMoreSheetCreateBranch => "إنشاء فرع للمحادثة";

  @override
  String get messageMoreSheetDelete => "حذف هذا الإصدار";

  @override
  String get messageMoreSheetDeleteAllVersions => "حذف جميع الإصدارات";

  @override
  String get reasoningBudgetSheetTitle => "مستوى قوة الاستدلال";

  @override
  String get reasoningLevelSheetTitle => "الاستدلال";

  @override
  String get reasoningLevelAuto => "تلقائي";

  @override
  String get reasoningLevelAutoSubtitle => "استخدام الإعداد الافتراضي للنموذج أو مزوّد الخدمة";

  @override
  String get reasoningLevelOff => "إيقاف";

  @override
  String get reasoningLevelOffSubtitle => "إيقاف الاستدلال والإجابة مباشرة";

  @override
  String get reasoningLevelMinimal => "أدنى حد";

  @override
  String get reasoningLevelMinimalSubtitle => "استخدام أقل قدر من الاستدلال للإجابة عن الأسئلة";

  @override
  String get reasoningLevelLow => "منخفض";

  @override
  String get reasoningLevelLowSubtitle => "استخدام استدلال خفيف للإجابة عن الأسئلة";

  @override
  String get reasoningLevelMedium => "متوسط";

  @override
  String get reasoningLevelMediumSubtitle => "استخدام استدلال معتدل للإجابة عن الأسئلة";

  @override
  String get reasoningLevelHigh => "مرتفع";

  @override
  String get reasoningLevelHighSubtitle => "استخدام استدلال مكثف للمسائل المعقدة";

  @override
  String get reasoningLevelXhigh => "مرتفع جدًا";

  @override
  String get reasoningLevelXhighSubtitle => "استخدام عمق استدلال كبير جدًا للمسائل الأصعب";

  @override
  String get reasoningLevelMax => "أقصى حد";

  @override
  String get reasoningLevelMaxSubtitle => "استخدام أقصى عمق للاستدلال لأصعب المسائل";

  @override
  String get reasoningLevelFollowModelDefaultSubtitle => "استخدام الإعداد الافتراضي للنموذج عندما لا يحدد المساعد مستوى آخر";

  @override
  String get reasoningLevelNoReasoning => "هذا النموذج لا يدعم الاستدلال";

  @override
  String get reasoningLevelCustomBudget => "ميزانية استدلال مخصصة";

  @override
  String get reasoningLevelCustomBudgetHint => "ميزانية الرموز، مثال: 2048";

  @override
  String get reasoningLevelCompactMin => "أدنى";

  @override
  String get reasoningLevelCompactLow => "منخفض";

  @override
  String get reasoningLevelCompactMid => "متوسط";

  @override
  String get reasoningLevelCompactHigh => "مرتفع";

  @override
  String get reasoningLevelCompactXhigh => "مرتفع جدًا";

  @override
  String get reasoningLevelCompactMax => "أقصى حد";

  @override
  String reasoningLevelBudgetTokens(String budget) => "${budget} رمزًا";

  @override
  String chatMessageWidgetFileNotFound(String fileName) => "الملف غير موجود: ${fileName}";

  @override
  String chatMessageWidgetCannotOpenFile(String message) => "تعذّر فتح الملف: ${message}";

  @override
  String chatMessageWidgetOpenFileError(String error) => "فشل فتح الملف: ${error}";

  @override
  String get chatMessageWidgetCopiedToClipboard => "تم النسخ إلى الحافظة";

  @override
  String get chatMessageWidgetResendTooltip => "إعادة الإرسال";

  @override
  String get chatMessageWidgetMoreTooltip => "المزيد";

  @override
  String get chatMessageWidgetThinking => "جارٍ التفكير…";

  @override
  String get chatMessageWidgetTranslation => "الترجمة";

  @override
  String get chatMessageWidgetTranslating => "جارٍ الترجمة…";

  @override
  String get chatMessageWidgetCitationNotFound => "لم يتم العثور على مصدر الاستشهاد";

  @override
  String chatMessageWidgetCannotOpenUrl(String url) => "تعذّر فتح الرابط: ${url}";

  @override
  String get chatMessageWidgetOpenLinkError => "فشل فتح الرابط";

  @override
  String get chatMessageWidgetAttachmentUnavailable => "المرفق غير متاح";

  @override
  String chatMessageWidgetCitationsTitle(int count) => "الاستشهادات (${count})";

  @override
  String get chatMessageWidgetSearchResultsTitle => "نتائج البحث";

  @override
  String get chatMessageWidgetCitationSourcesTitle => "مصادر الاستشهاد";

  @override
  String get chatMessageWidgetRegenerateTooltip => "إعادة التوليد";

  @override
  String get chatMessageWidgetRegenerateConfirmTitle => "تأكيد إعادة التوليد";

  @override
  String get chatMessageWidgetRegenerateConfirmContent => "سيؤدي إنشاء الرد مجددًا إلى تحديث هذه الرسالة فقط مع الإبقاء على الرسائل التي تليها. هل تريد المتابعة؟";

  @override
  String get chatMessageWidgetRegenerateConfirmDeleteTrailingContent => "سيؤدي إنشاء الرد مجددًا إلى حذف جميع الرسائل التي تلي هذه الرسالة، ولا يمكن التراجع عن ذلك. هل تريد المتابعة؟";

  @override
  String get chatMessageWidgetRegenerateConfirmCancel => "إلغاء";

  @override
  String get chatMessageWidgetRegenerateConfirmOk => "إنشاء الرد مجددًا";

  @override
  String get chatMessageWidgetStopTooltip => "إيقاف";

  @override
  String get chatMessageWidgetSpeakTooltip => "قراءة صوتية";

  @override
  String get chatMessageWidgetTranslateTooltip => "ترجمة";

  @override
  String get chatMessageWidgetBuiltinSearchHideNote => "إخفاء بطاقات أداة البحث المدمجة";

  @override
  String get chatMessageWidgetDeepThinking => "التفكير المتعمق";

  @override
  String chatMessageWidgetWebSearch(String query) => "بحث الويب: ${query}";

  @override
  String chatMessageWidgetWebFetch(String target) => "قراءة الصفحة: ${target}";

  @override
  String get chatMessageWidgetBuiltinSearch => "البحث المدمج";

  @override
  String get chatMessageWidgetReadClipboard => "قراءة الحافظة";

  @override
  String get chatMessageWidgetWriteClipboard => "الكتابة إلى الحافظة";

  @override
  String get chatMessageWidgetSpeakingTitle => "جارٍ التحدث:";

  @override
  String chatMessageWidgetSpeakText(String text) => "جارٍ قراءة النص: ${text}";

  @override
  String get chatMessageWidgetMemoryRead => "قراءة الذاكرة";

  @override
  String get chatMessageWidgetMemoryUpdate => "تحديث الذاكرة";

  @override
  String get chatMessageWidgetMemorySearchProfile => "البحث في الذاكرة";

  @override
  String get chatMessageWidgetMemoryEdit => "تعديل الذاكرة";

  @override
  String get chatMessageWidgetMemoryDelete => "حذف الذاكرة";

  @override
  String get chatMessageWidgetUpdateUserProfile => "تحديث ملف المستخدم";

  @override
  String get chatMessageWidgetChatSearch => "البحث في المحادثات السابقة";

  @override
  String get chatMessageWidgetCreateMemory => "إنشاء ذكرى";

  @override
  String chatMessageWidgetToolCall(String name) => "استدعاء الأداة: ${name}";

  @override
  String chatMessageWidgetToolResult(String name) => "نتيجة الأداة: ${name}";

  @override
  String get chatMessageWidgetNoResultYet => "(لا توجد نتيجة حتى الآن)";

  @override
  String get chatMessageWidgetArguments => "المعاملات";

  @override
  String get chatMessageWidgetResult => "النتيجة";

  @override
  String get chatMessageWidgetImages => "الصور";

  @override
  String chatMessageWidgetCitationsCount(int count) => "عدد الاستشهادات: ${count}";

  @override
  String chatSelectionSelectedCountTitle(int count) => "تم تحديد ${count} رسالة";

  @override
  String get chatSelectionExportImage => "صورة";

  @override
  String get chatSelectionThinkingTools => "أدوات التفكير";

  @override
  String get chatSelectionThinkingContent => "محتوى التفكير";

  @override
  String get chatSelectionDeleteSelected => "حذف المحدد";

  @override
  String get chatSelectionSelectMessagesToDelete => "يرجى تحديد الرسائل المراد حذفها.";

  @override
  String chatSelectionDeleteSelectedConfirm(int count) => "هل تريد حذف ${count} من الإصدارات المحددة؟ لا يمكن التراجع عن ذلك.";

  @override
  String chatSelectionDeleteSelectedAllVersionsConfirm(int count) => "هل تريد حذف جميع إصدارات ${count} من الرسائل المحددة؟ لا يمكن التراجع عن ذلك.";

  @override
  String get messageExportSheetAssistant => "المساعد";

  @override
  String get messageExportSheetDefaultTitle => "محادثة جديدة";

  @override
  String get messageExportSheetExporting => "جارٍ التصدير…";

  @override
  String messageExportSheetExportFailed(String error) => "فشل التصدير: ${error}";

  @override
  String messageExportSheetExportedAs(String filename) => "تم التصدير باسم ${filename}";

  @override
  String get displaySettingsPageEnableDollarLatexTitle => "عرض صيغ \$...\$ المضمّنة";

  @override
  String get displaySettingsPageEnableDollarLatexSubtitle => "عرض الصيغ الرياضية المضمّنة داخل \$...\$";

  @override
  String get displaySettingsPageEnableMathTitle => "عرض الصيغ الرياضية";

  @override
  String get displaySettingsPageEnableMathSubtitle => "عرض صيغ LaTeX الرياضية المضمّنة والكتلية";

  @override
  String get displaySettingsPageUseLegacyInlineCodeStyleTitle => "نمط الشيفرة المضمّنة القديم";

  @override
  String get displaySettingsPageUseLegacyInlineCodeStyleSubtitle => "استخدام خلفية أفتح وحدود رفيعة وتباعد أسطر أكبر للشيفرة المضمّنة.";

  @override
  String get displaySettingsPageUseLegacyCodeBlockStyleTitle => "نمط كتل الشيفرة القديم";

  @override
  String get displaySettingsPageUseLegacyCodeBlockStyleSubtitle => "استعادة الألوان السابقة والزوايا المستديرة والتباعد لكتل الشيفرة.";

  @override
  String get displaySettingsPageEnableUserMarkdownTitle => "عرض رسائل المستخدم بتنسيق Markdown";

  @override
  String get displaySettingsPageEnableReasoningMarkdownTitle => "عرض التفكير بتنسيق Markdown";

  @override
  String get displaySettingsPageEnableAssistantMarkdownTitle => "عرض رسائل المساعد بتنسيق Markdown";

  @override
  String get displaySettingsPageMobileCodeBlockWrapTitle => "التفاف أسطر كتل الشيفرة على الهاتف";

  @override
  String get displaySettingsPageAutoCollapseCodeBlockTitle => "طي كتل الشيفرة تلقائيًا";

  @override
  String get displaySettingsPageAutoCollapseCodeBlockLinesTitle => "حد الطي التلقائي";

  @override
  String get displaySettingsPageAutoCollapseCodeBlockLinesUnit => "سطرًا";

  @override
  String get displaySettingsPageCollapseLongUserMessagesTitle => "طي الرسائل الطويلة";

  @override
  String get displaySettingsPageCollapseLongUserMessagesSubtitle => "طي رسائل المستخدم التي تتجاوز الحد وإظهار زر لتوسيعها.";

  @override
  String get displaySettingsPageCollapseLongUserMessagesCharsTitle => "حد الطي";

  @override
  String get displaySettingsPageCollapseLongUserMessagesCharsUnit => "حرفًا";

  @override
  String get chatMessageExpandLongText => "توسيع";

  @override
  String get chatMessageCollapseLongText => "طي";

  @override
  String get messageExportSheetFormatTitle => "تنسيق التصدير";

  @override
  String get messageExportSheetSingleMarkdownSubtitle => "تصدير هذه الرسالة كملف Markdown";

  @override
  String get messageExportSheetBatchMarkdownSubtitle => "تصدير الرسائل المحددة كملف Markdown";

  @override
  String get messageExportSheetPlainText => "نص عادي";

  @override
  String get messageExportSheetSingleTxtSubtitle => "تصدير هذه الرسالة كملف TXT";

  @override
  String get messageExportSheetBatchTxtSubtitle => "تصدير الرسائل المحددة كملف TXT";

  @override
  String get messageExportSheetExportImage => "تصدير كصورة";

  @override
  String get messageExportSheetSingleExportImageSubtitle => "تحويل هذه الرسالة إلى صورة PNG";

  @override
  String get messageExportSheetBatchExportImageSubtitle => "تحويل الرسائل المحددة إلى صورة PNG";

  @override
  String get messageExportSheetShowThinkingAndToolCards => "إظهار التفكير المتعمق وبطاقات الأدوات";

  @override
  String get messageExportSheetShowThinkingContent => "إظهار محتوى التفكير";

  @override
  String get messageExportThinkingContentLabel => "محتوى التفكير";

  @override
  String get exportDisclaimerAiGenerated => "محتوى مُنشأ بواسطة الذكاء الاصطناعي. يُرجى التحقق منه بعناية.";

  @override
  String get imagePreviewSheetSaveImage => "حفظ الصورة";

  @override
  String get imagePreviewSheetSaveSuccess => "تم الحفظ في المعرض";

  @override
  String imagePreviewSheetSaveFailed(String error) => "فشل الحفظ: ${error}";

  @override
  String get sideDrawerMenuRename => "إعادة تسمية";

  @override
  String get sideDrawerMenuPin => "تثبيت";

  @override
  String get sideDrawerMenuUnpin => "إلغاء التثبيت";

  @override
  String get sideDrawerMenuRegenerateTitle => "إعادة إنشاء العنوان";

  @override
  String get sideDrawerMenuCopy => "نسخ";

  @override
  String get sideDrawerMenuMoveTo => "نقل إلى";

  @override
  String get sideDrawerMenuDelete => "حذف";

  @override
  String get sideDrawerMenuSelect => "تحديد";

  @override
  String sideDrawerSelectionTitle(int count) => "تم تحديد ${count} عنصرًا";

  @override
  String get sideDrawerSelectionSelectAll => "تحديد الكل";

  @override
  String get sideDrawerSelectionDeselectAll => "إلغاء تحديد الكل";

  @override
  String get sideDrawerSelectionPin => "تثبيت";

  @override
  String get sideDrawerSelectionUnpin => "إلغاء التثبيت";

  @override
  String get sideDrawerSelectionMove => "نقل";

  @override
  String get sideDrawerSelectionDelete => "حذف";

  @override
  String get sideDrawerSelectionDeleteConfirmTitle => "حذف المحادثات";

  @override
  String sideDrawerSelectionDeleteConfirmContent(int count) => "هل تريد حذف ${count} من المحادثات؟";

  @override
  String sideDrawerDeleteSelectedSnackbar(int count) => "تم حذف ${count} من المحادثات";

  @override
  String sideDrawerMoveSelectedSnackbar(int count) => "تم نقل ${count} من المحادثات";

  @override
  String sideDrawerDeleteSnackbar(String title) => "تم حذف \"${title}\"";

  @override
  String get sideDrawerRenameHint => "أدخل اسمًا جديدًا";

  @override
  String get sideDrawerCancel => "إلغاء";

  @override
  String get sideDrawerOK => "موافق";

  @override
  String get sideDrawerSave => "حفظ";

  @override
  String get sideDrawerGreetingMorning => "صباح الخير 👋";

  @override
  String get sideDrawerGreetingNoon => "نهارك سعيد 👋";

  @override
  String get sideDrawerGreetingAfternoon => "مساء الخير 👋";

  @override
  String get sideDrawerGreetingEvening => "مساؤك سعيد 👋";

  @override
  String get sideDrawerDateToday => "اليوم";

  @override
  String get sideDrawerDateYesterday => "أمس";

  @override
  String get sideDrawerDateShortPattern => "d MMM";

  @override
  String get sideDrawerDateFullPattern => "d MMM yyyy";

  @override
  String get sideDrawerSearchHint => "البحث في المساعد الحالي";

  @override
  String get sideDrawerSearchAssistantsHint => "البحث عن المساعدين";

  @override
  String get sideDrawerTopicSearchModeLabel => "وضع الموضوع";

  @override
  String get sideDrawerGlobalSearchModeLabel => "الوضع الشامل";

  @override
  String get sideDrawerSearchModeSwipeToTopicHint => "اسحب شريط البحث للبحث حسب الموضوع";

  @override
  String get sideDrawerSearchModeSwipeToGlobalHint => "اسحب شريط البحث للبحث الشامل";

  @override
  String get sideDrawerGlobalSearchHint => "البحث في جميع الجلسات";

  @override
  String get sideDrawerGlobalSearchEmptyHint => "ابحث في العناوين والرسائل";

  @override
  String get sideDrawerGlobalSearchNoResults => "لا توجد جلسات مطابقة";

  @override
  String sideDrawerGlobalSearchResultCount(int count) => "عدد النتائج: ${count}";

  @override
  String sideDrawerUpdateTitle(String version) => "إصدار جديد: ${version}";

  @override
  String sideDrawerUpdateTitleWithBuild(String version, int build) => "إصدار جديد: ${version} (${build})";

  @override
  String get sideDrawerLinkCopied => "تم نسخ الرابط";

  @override
  String get sideDrawerPinnedLabel => "مثبّت";

  @override
  String get sideDrawerHistory => "السجل";

  @override
  String get sideDrawerSettings => "الإعدادات";

  @override
  String get sideDrawerChooseAssistantTitle => "اختيار مساعد";

  @override
  String get sideDrawerChooseImage => "اختيار صورة";

  @override
  String get sideDrawerChooseEmoji => "اختيار رمز تعبيري";

  @override
  String get sideDrawerEnterLink => "إدخال رابط";

  @override
  String get sideDrawerImportFromQQ => "استيراد من QQ";

  @override
  String get sideDrawerReset => "إعادة ضبط";

  @override
  String get providerAvatarChooseBuiltInIcon => "اختيار أيقونة مدمجة";

  @override
  String get providerAvatarIconDialogTitle => "اختيار أيقونة مدمجة";

  @override
  String get providerAvatarIconSearchHint => "البحث عن أيقونات";

  @override
  String get providerAvatarIconNoResults => "لم يتم العثور على أيقونات";

  @override
  String get providerAvatarInputLobehubIcon => "أدخل أيقونة LobeHub";

  @override
  String get providerAvatarChooseLobehubIcon => "أدخل أيقونة LobeHub";

  @override
  String get providerAvatarLobehubDialogTitle => "إدخال أيقونة LobeHub";

  @override
  String get providerAvatarLobehubDialogHint => "أدخل اسم أيقونة LobeHub، مثل openai";

  @override
  String get sideDrawerEmojiDialogTitle => "اختيار رمز تعبيري";

  @override
  String get sideDrawerEmojiDialogHint => "اكتب أي رمز تعبيري أو الصقه";

  @override
  String get sideDrawerImageUrlDialogTitle => "إدخال رابط الصورة";

  @override
  String get sideDrawerImageUrlDialogHint => "مثال: https://example.com/avatar.png";

  @override
  String get sideDrawerQQAvatarDialogTitle => "استيراد من QQ";

  @override
  String get sideDrawerQQAvatarInputHint => "أدخل رقم QQ (من 5 إلى 12 رقمًا)";

  @override
  String get sideDrawerQQAvatarFetchFailed => "تعذّر جلب صورة رمزية عشوائية من QQ. حاول مرة أخرى.";

  @override
  String get sideDrawerRandomQQ => "صورة عشوائية من QQ";

  @override
  String get sideDrawerGalleryOpenError => "تعذّر فتح المعرض. جرّب إدخال رابط صورة.";

  @override
  String get sideDrawerGeneralImageError => "حدث خطأ ما. جرّب إدخال رابط صورة.";

  @override
  String get sideDrawerSetNicknameTitle => "تعيين اسم مستعار";

  @override
  String get sideDrawerNicknameLabel => "الاسم المستعار";

  @override
  String get sideDrawerNicknameHint => "أدخل اسمًا مستعارًا جديدًا";

  @override
  String get sideDrawerRename => "إعادة تسمية";

  @override
  String get chatInputBarHint => "اكتب رسالة إلى الذكاء الاصطناعي";

  @override
  String get chatInputBarSelectModelTooltip => "اختيار النموذج";

  @override
  String get chatInputBarOnlineSearchTooltip => "البحث عبر الإنترنت";

  @override
  String get chatInputBarReasoningStrengthTooltip => "قوة الاستدلال";

  @override
  String get chatInputBarMcpServersTooltip => "خوادم MCP";

  @override
  String get chatInputBarToolsTooltip => "الأدوات";

  @override
  String get chatInputBarMoreTooltip => "إضافة";

  @override
  String get chatInputBarVoiceInputTooltip => "الإدخال الصوتي";

  @override
  String get chatInputBarVoiceCancelTooltip => "تجاهل التسجيل";

  @override
  String get chatInputBarVoiceStopTooltip => "إيقاف التسجيل وتحويله إلى نص في حقل الإدخال";

  @override
  String get chatInputBarVoiceSendTooltip => "تحويل التسجيل إلى نص وإرساله";

  @override
  String get chatInputBarVoiceTranscribing => "جارٍ التعرّف على الكلام…";

  @override
  String get chatInputBarVoiceAttachAudioTooltip => "إيقاف التسجيل وإرفاقه كملف صوتي";

  @override
  String get chatInputBarVoiceSendAudioTooltip => "إرسال التسجيل الصوتي";

  @override
  String get chatInputBarVoiceSavingAudio => "جارٍ حفظ الصوت…";

  @override
  String get audioClipPlayTooltip => "تشغيل الصوت";

  @override
  String get audioClipPauseTooltip => "إيقاف مؤقت";

  @override
  String get audioClipPlaybackFailed => "تعذّر تشغيل هذا الملف الصوتي";

  @override
  String get chatInputBarImageProcessing => "جارٍ معالجة الصورة";

  @override
  String get chatInputBarImageMode => "وضع الصور";

  @override
  String get chatInputBarDisableImageModeTooltip => "إيقاف وضع الصور";

  @override
  String get chatInputBarQueuedPending => "تمت إضافة الرسالة إلى قائمة الانتظار";

  @override
  String get chatInputBarQueuedCancel => "إلغاء قائمة الانتظار";

  @override
  String get chatInputBarInsertNewline => "إدراج سطر جديد";

  @override
  String get chatInputBarExpand => "توسيع";

  @override
  String get chatInputBarCollapse => "طيّ";

  @override
  String get contextUsageTitle => "نافذة السياق";

  @override
  String get contextUsageStateExact => "دقيق (من آخر استجابة)";

  @override
  String get contextUsageStateExactCalibrated => "دقيق (تم ضبط التفاصيل وفق التقدير)";

  @override
  String get contextUsageStateEstimated => "تقديري";

  @override
  String get contextUsageStateStale => "قديم، جارٍ التحديث…";

  @override
  String get contextUsageStateComputing => "جارٍ الحساب…";

  @override
  String get contextUsageStateFailed => "فشل الحساب";

  @override
  String get contextUsageStateFailedWithPrevious => "فشل التحديث · النتيجة السابقة قديمة";

  @override
  String get contextUsageUnavailable => "معلومات الاستخدام غير متاحة";

  @override
  String get contextUsageStateNone => "لا توجد بيانات بعد";

  @override
  String get contextUsageBucketSystem => "تعليمات النظام";

  @override
  String get contextUsageBucketInjections => "إدراجات التعليمات";

  @override
  String get contextUsageBucketHistory => "الرسائل";

  @override
  String get contextUsageBucketTools => "الأدوات المدمجة";

  @override
  String get contextUsageBucketMemory => "الذاكرة";

  @override
  String get contextUsageBucketWorldBook => "دفاتر العالم";

  @override
  String get contextUsageBucketSkills => "المهارات";

  @override
  String get contextUsageBucketWorkspace => "مساحة العمل";

  @override
  String get contextUsageBucketSearch => "تعليمات البحث";

  @override
  String get contextUsageBucketMcpTools => "أدوات MCP";

  @override
  String get contextUsageBucketAttachments => "المرفقات";

  @override
  String get contextUsageBucketDraft => "مسودة";

  @override
  String get contextUsageBucketUsed => "المستخدم";

  @override
  String get contextUsageFreeSpace => "المساحة المتاحة";

  @override
  String contextUsageUsedWindow(String used, String window, int percent) => "${used} / ${window} (${percent}٪)";

  @override
  String get contextUsageNoWindow => "لا توجد نافذة سياق";

  @override
  String get contextUsageSetWindow => "تعيين نافذة السياق";

  @override
  String get contextUsageRefresh => "تحديث";

  @override
  String get mcpPageBackTooltip => "رجوع";

  @override
  String get mcpPageAddMcpTooltip => "إضافة MCP";

  @override
  String get mcpPageNoServers => "لا توجد خوادم MCP";

  @override
  String get mcpPageErrorDialogTitle => "خطأ في الاتصال";

  @override
  String get mcpPageErrorNoDetails => "لا توجد تفاصيل";

  @override
  String get mcpPageClose => "إغلاق";

  @override
  String get mcpPageReconnect => "إعادة الاتصال";

  @override
  String get mcpPageStatusConnected => "متصل";

  @override
  String get mcpPageStatusConnecting => "جارٍ الاتصال…";

  @override
  String get mcpPageStatusDisconnected => "غير متصل";

  @override
  String get mcpPageStatusAuthorizationRequired => "مطلوب التفويض";

  @override
  String get mcpPageStatusAuthorizing => "جارٍ التفويض…";

  @override
  String get mcpPageStatusDisabled => "معطّل";

  @override
  String get mcpPageOAuthRequired => "يلزم تسجيل الدخول باستخدام OAuth";

  @override
  String get mcpPageOAuthSignIn => "تسجيل الدخول باستخدام OAuth";

  @override
  String mcpPageToolsCount(int enabled, int total) => "الأدوات: ${enabled}/${total}";

  @override
  String get mcpPageConnectionFailed => "فشل الاتصال";

  @override
  String get mcpPageDetails => "التفاصيل";

  @override
  String get mcpPageDelete => "حذف";

  @override
  String get mcpPageConfirmDeleteTitle => "تأكيد الحذف";

  @override
  String get mcpPageConfirmDeleteContent => "يمكن التراجع عن هذا الإجراء باستخدام «تراجع». هل تريد الحذف؟";

  @override
  String get mcpPageServerDeleted => "تم حذف الخادم";

  @override
  String get mcpPageUndo => "تراجع";

  @override
  String get mcpPageCancel => "إلغاء";

  @override
  String get mcpConversationSheetTitle => "خوادم MCP";

  @override
  String get mcpConversationSheetSubtitle => "اختر الخوادم المفعّلة لهذه المحادثة";

  @override
  String get mcpConversationSheetSelectAll => "تحديد الكل";

  @override
  String get mcpConversationSheetClearAll => "مسح";

  @override
  String get mcpConversationSheetNoRunning => "لا توجد خوادم MCP قيد التشغيل";

  @override
  String get mcpConversationSheetConnected => "متصل";

  @override
  String mcpConversationSheetToolsCount(int enabled, int total) => "الأدوات: ${enabled}/${total}";

  @override
  String get mcpServerEditSheetEnabledLabel => "مفعّل";

  @override
  String get mcpServerEditSheetNameLabel => "الاسم";

  @override
  String get mcpServerEditSheetTransportLabel => "وسيلة النقل";

  @override
  String get mcpServerEditSheetUrlLabel => "عنوان URL للخادم";

  @override
  String get mcpServerEditSheetCustomHeadersTitle => "ترويسات مخصصة";

  @override
  String get mcpServerEditSheetHeaderNameLabel => "اسم الترويسة";

  @override
  String get mcpServerEditSheetHeaderNameHint => "مثال: Authorization";

  @override
  String get mcpServerEditSheetHeaderValueLabel => "قيمة الترويسة";

  @override
  String get mcpServerEditSheetHeaderValueHint => "مثال: Bearer xxxxxx";

  @override
  String get mcpServerEditSheetRemoveHeaderTooltip => "إزالة";

  @override
  String get mcpServerEditSheetAddHeader => "إضافة ترويسة";

  @override
  String get mcpServerEditSheetTitleEdit => "تعديل MCP";

  @override
  String get mcpServerEditSheetTitleAdd => "إضافة MCP";

  @override
  String get mcpServerEditSheetSyncToolsTooltip => "مزامنة الأدوات";

  @override
  String get mcpServerEditSheetTabBasic => "أساسي";

  @override
  String get mcpServerEditSheetTabTools => "الأدوات";

  @override
  String get mcpServerEditSheetNoToolsHint => "لا توجد أدوات. اضغط على تحديث للمزامنة.";

  @override
  String get mcpServerEditSheetCancel => "إلغاء";

  @override
  String get mcpServerEditSheetSave => "حفظ";

  @override
  String get mcpServerEditSheetUrlRequired => "أدخل عنوان URL للخادم";

  @override
  String get defaultModelPageBackTooltip => "رجوع";

  @override
  String get defaultModelPageTitle => "النموذج الافتراضي";

  @override
  String get defaultModelPageChatModelTitle => "نموذج المحادثة";

  @override
  String get defaultModelPageChatModelSubtitle => "نموذج المحادثة الافتراضي العام";

  @override
  String get defaultModelPageTitleModelTitle => "نموذج تلخيص العنوان";

  @override
  String get defaultModelPageTitleModelSubtitle => "يُلخّص عناوين المحادثات باستخدام نموذج المحادثة الحالي افتراضيًا، أو باستخدام نموذج محدد.";

  @override
  String get titleModelThinkingTitle => "تفعيل التفكير";

  @override
  String get defaultModelPageSummaryModelTitle => "نموذج الملخص";

  @override
  String get defaultModelPageSummaryModelSubtitle => "يُستخدم لإنشاء ملخصات المحادثات؛ يُفضّل اختيار نماذج سريعة ومنخفضة التكلفة.";

  @override
  String get defaultModelPageSuggestionModelTitle => "نموذج اقتراحات المحادثة";

  @override
  String get defaultModelPageSuggestionModelSubtitle => "ينشئ اقتراحات المتابعة باستخدام نموذج المحادثة الحالي أو نموذج محدد. يكون معطّلًا افتراضيًا.";

  @override
  String get assistantEditRecentChatsSummaryFrequencyTitle => "وتيرة تحديث ملخص المحادثات الأخيرة";

  @override
  String get assistantEditRecentChatsSummaryFrequencyDescription => "حدّث ملخصات المحادثات الأخيرة بعد العدد المحدد من الرسائل الجديدة.";

  @override
  String assistantEditRecentChatsSummaryFrequencyOption(int count) => "كل ${count}";

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomButton => "مخصص";

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomTitle => "وتيرة مخصصة لتحديث الملخص";

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomDescription => "أدخل عدد الرسائل الجديدة التي يجب تجميعها قبل تحديث ملخص المحادثات الأخيرة.";

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomLabel => "عدد الرسائل الجديدة";

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomHint => "أدخل رقمًا أكبر من صفر";

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomInvalid => "أدخل عددًا صحيحًا أكبر من صفر";

  @override
  String get defaultModelPageTranslateModelTitle => "نموذج الترجمة";

  @override
  String get defaultModelPageTranslateModelSubtitle => "يُستخدم لترجمة محتوى الرسائل؛ يُفضّل اختيار نماذج سريعة ودقيقة.";

  @override
  String get defaultModelPageOcrModelTitle => "نموذج OCR";

  @override
  String backgroundTaskFailed(String task, String error) => "فشلت المهمة ${task}: ${error}";

  @override
  String get defaultModelPageOcrModelSubtitle => "يُستخدم لاستخراج النصوص والأوصاف من الصور.";

  @override
  String get defaultModelPageOcrModelRequiresImageInput => "اختر نموذجًا يدعم إدخال الصور لاستخدامه مع OCR";

  @override
  String get defaultModelPagePromptLabel => "التعليمات";

  @override
  String get defaultModelPageTitlePromptHint => "أدخل قالب التعليمات لتلخيص العناوين";

  @override
  String get defaultModelPageSummaryPromptHint => "أدخل قالب التعليمات لإنشاء الملخصات";

  @override
  String get defaultModelPageSuggestionPromptHint => "أدخل قالب التعليمات لاقتراحات المحادثة";

  @override
  String get defaultModelPageTranslatePromptHint => "أدخل قالب التعليمات للترجمة";

  @override
  String get defaultModelPageOcrPromptHint => "أدخل قالب التعليمات لفهم الصور عبر OCR";

  @override
  String get defaultModelPageResetDefault => "استعادة الإعداد الافتراضي";

  @override
  String get defaultModelPageDisable => "تعطيل";

  @override
  String get defaultModelPageSave => "حفظ";

  @override
  String defaultModelPageTitleVars(String contentVar, String localeVar) => "المتغيرات: المحتوى: ${contentVar}، اللغة: ${localeVar}";

  @override
  String defaultModelPageSummaryVars(String previousSummaryVar, String userMessagesVar) => "المتغيرات: الملخص السابق: ${previousSummaryVar}، الرسائل الجديدة: ${userMessagesVar}";

  @override
  String defaultModelPageSuggestionVars(String contentVar, String localeVar) => "المتغيرات: المحادثة: ${contentVar}، اللغة: ${localeVar}";

  @override
  String get defaultModelPageCompressModelTitle => "نموذج ضغط السياق";

  @override
  String get defaultModelPageCompressModelSubtitle => "يُستخدم لضغط سياق المحادثة؛ يُفضّل اختيار النماذج السريعة.";

  @override
  String get defaultModelPageCompressPromptHint => "أدخل قالب التعليمات لضغط سياق المحادثة";

  @override
  String defaultModelPageCompressVars(String contentVar, String localeVar) => "المتغيرات: المحادثة: ${contentVar}، اللغة: ${localeVar}";

  @override
  String defaultModelPageTranslateVars(String sourceVar, String targetVar) => "المتغيرات: النص المصدر: ${sourceVar}، اللغة المستهدفة: ${targetVar}";

  @override
  String get defaultModelPageUseCurrentModel => "استخدام نموذج المحادثة الحالي";

  @override
  String get defaultModelPageNotEnabled => "غير مفعّل";

  @override
  String get translatePagePasteButton => "لصق";

  @override
  String get translatePageCopyResult => "نسخ النتيجة";

  @override
  String get translatePageClearAll => "مسح الكل";

  @override
  String get translatePageInputHint => "أدخل النص المراد ترجمته…";

  @override
  String get translatePageOutputHint => "ستظهر الترجمة هنا…";

  @override
  String get modelDetailSheetAddModel => "إضافة نموذج";

  @override
  String get modelDetailSheetEditModel => "تعديل النموذج";

  @override
  String get modelDetailSheetBasicTab => "أساسي";

  @override
  String get modelDetailSheetAdvancedTab => "متقدم";

  @override
  String get modelDetailSheetBuiltinToolsTab => "الأدوات المدمجة";

  @override
  String get modelDetailSheetModelIdLabel => "معرّف النموذج";

  @override
  String get modelDetailSheetModelIdHint => "مطلوب؛ يُفضّل استخدام الأحرف الصغيرة والأرقام والشرطات.";

  @override
  String get modelDetailSheetModelNameLabel => "اسم النموذج";

  @override
  String get modelDetailSheetModelTypeLabel => "نوع النموذج";

  @override
  String get modelDetailSheetChatType => "محادثة";

  @override
  String get modelDetailSheetEmbeddingType => "تضمين";

  @override
  String get modelDetailSheetInputModesLabel => "أنماط الإدخال";

  @override
  String get modelDetailSheetOutputModesLabel => "أنماط الإخراج";

  @override
  String get modelDetailSheetAbilitiesLabel => "القدرات";

  @override
  String get modelDetailSheetTextMode => "نص";

  @override
  String get modelDetailSheetImageMode => "صورة";

  @override
  String get modelDetailSheetToolsAbility => "الأدوات";

  @override
  String get modelDetailSheetReasoningAbility => "الاستدلال";

  @override
  String get modelDetailSheetCustomHeadersTitle => "ترويسات مخصصة";

  @override
  String get modelDetailSheetAddHeader => "إضافة ترويسة";

  @override
  String get modelDetailSheetCustomBodyTitle => "محتوى طلب مخصص";

  @override
  String get modelFetchInvertTooltip => "عكس الترتيب";

  @override
  String get modelDetailSheetSaveFailedMessage => "تعذّر الحفظ. يُرجى المحاولة مرة أخرى.";

  @override
  String get modelDetailSheetAddBody => "إضافة محتوى";

  @override
  String get modelDetailSheetBuiltinToolsDescription => "تعتمد الأدوات المدمجة على مزوّد الخدمة ونمط API.";

  @override
  String get modelDetailSheetUrlContextTool => "سياق URL";

  @override
  String get modelDetailSheetUrlContextToolDescription => "تفعيل جلب محتوى عناوين URL";

  @override
  String get modelDetailSheetCodeExecutionTool => "تنفيذ الشيفرة";

  @override
  String get modelDetailSheetCodeExecutionToolDescription => "تفعيل أداة تنفيذ الشيفرة";

  @override
  String get modelDetailSheetYoutubeToolDescription => "تفعيل جلب محتوى روابط YouTube (مع اكتشاف الروابط تلقائيًا في التعليمات).";

  @override
  String get modelDetailSheetOpenaiBuiltinToolsResponsesOnlyHint => "يتطلب OpenAI Responses API.";

  @override
  String get modelDetailSheetWebFetchTool => "جلب صفحات الويب";

  @override
  String get modelDetailSheetOpenrouterWebFetchToolDescription => "تفعيل أداة جلب صفحات الويب من خادم OpenRouter.";

  @override
  String get modelDetailSheetClaudeWebFetchToolDescription => "السماح لـ Claude بجلب الصفحات وملفات PDF من عناوين URL الواردة في المحادثة.";

  @override
  String get modelDetailSheetClaudeCodeExecutionToolDescription => "السماح لـ Claude بتشغيل Python وBash في بيئة Anthropic المعزولة.";

  @override
  String get modelDetailSheetOpenrouterShellToolDescription => "تشغيل أوامر Shell في بيئة معزولة مستضافة.";

  @override
  String get modelDetailSheetOpenaiCodeInterpreterTool => "مفسّر الشيفرة";

  @override
  String get modelDetailSheetOpenaiCodeInterpreterToolDescription => "تفعيل أداة مفسّر الشيفرة (حاوية تلقائية، بحد ذاكرة 4g).";

  @override
  String get modelDetailSheetOpenaiImageGenerationTool => "توليد الصور";

  @override
  String get modelDetailSheetOpenaiImageGenerationToolDescription => "تفعيل أداة توليد الصور.";

  @override
  String get modelDetailSheetCancelButton => "إلغاء";

  @override
  String get modelDetailSheetAddButton => "إضافة";

  @override
  String get modelDetailSheetConfirmButton => "تأكيد";

  @override
  String get modelDetailSheetInvalidIdError => "أدخل معرّف نموذج صالحًا (حرفان على الأقل).";

  @override
  String get modelDetailSheetHeaderKeyHint => "مفتاح الترويسة";

  @override
  String get modelDetailSheetHeaderValueHint => "قيمة الترويسة";

  @override
  String get modelDetailSheetBodyKeyHint => "مفتاح المحتوى";

  @override
  String get modelDetailSheetBodyJsonHint => "محتوى JSON";

  @override
  String get modelSpecFormSourceCustom => "مخصص";

  @override
  String get modelSpecFormSourceCatalog => "الكتالوج";

  @override
  String get modelSpecFormSourceInferred => "مستنتج";

  @override
  String get modelSpecFormSourceDefault => "افتراضي";

  @override
  String get modelSpecFormReset => "استعادة الإعدادات الافتراضية";

  @override
  String get modelSpecFormModalitiesSection => "أنماط الإدخال والقدرات";

  @override
  String get modelSpecFormImageType => "صورة";

  @override
  String get modelSpecFormAudioMode => "صوت";

  @override
  String get modelSpecFormVideoMode => "فيديو";

  @override
  String get modelSpecFormStructuredOutputAbility => "إخراج منظّم";

  @override
  String get modelSpecFormReasoningSection => "الاستدلال";

  @override
  String get modelSpecFormDialect => "صيغة الإعداد";

  @override
  String get modelSpecFormDialectNone => "بدون";

  @override
  String get modelSpecFormDialectNoneSubtitle => "لا توجد حقول للاستدلال";

  @override
  String get modelSpecFormDialectOpenaiReasoningEffort => "مستوى جهد الاستدلال في OpenAI";

  @override
  String get modelSpecFormDialectOpenaiResponsesReasoning => "استدلال OpenAI Responses";

  @override
  String get modelSpecFormDialectOpenrouterReasoning => "استدلال OpenRouter";

  @override
  String get modelSpecFormDialectAnthropicBudget => "ميزانية Anthropic";

  @override
  String get modelSpecFormDialectAnthropicAdaptiveEffort => "الجهد التكيفي في Anthropic";

  @override
  String get modelSpecFormDialectAnthropicBetweenTools => "التفكير التكيفي / بين الأدوات في Anthropic";

  @override
  String get modelSpecFormDialectAnthropicBetweenToolsSubtitle => "تفكير تكيفي؛ يستخدم وضع الإيقاف between_tools.";

  @override
  String get modelSpecFormDialectAnthropicEffort => "جهد الاستدلال في Anthropic";

  @override
  String get modelSpecFormDialectGeminiThinkingBudget => "ميزانية التفكير في Gemini";

  @override
  String get modelSpecFormDialectGeminiThinkingLevel => "مستوى التفكير في Gemini";

  @override
  String get modelSpecFormDialectQwenEnableThinking => "تفعيل التفكير في Qwen";

  @override
  String get modelSpecFormDialectThinkingType => "نوع التفكير";

  @override
  String get modelSpecFormDialectSiliconflowEnableThinking => "تفعيل التفكير في SiliconFlow";

  @override
  String get modelSpecFormDialectInternThinkingMode => "وضع التفكير في Intern";

  @override
  String get modelSpecFormDialectChatTemplateKwargs => "معاملات قالب المحادثة";

  @override
  String get modelSpecFormDialectKimiThinking => "التفكير في Kimi";

  @override
  String get modelSpecFormDialectCustom => "JSON مخصص";

  @override
  String get modelSpecFormDialectCustomSubtitle => "تعديل JSON منفصل لكل مستوى";

  @override
  String get modelSpecFormLevels => "المستويات المدعومة";

  @override
  String get modelSpecFormCanDisable => "السماح بالتعطيل";

  @override
  String get modelSpecFormDefaultLevel => "المستوى الافتراضي";

  @override
  String get modelSpecFormBudgets => "ميزانيات الرموز";

  @override
  String modelSpecFormCustomPatch(String level) => "تعديل JSON (${level})";

  @override
  String get modelSpecFormCustomPatchHint => "مثلًا: reasoning_effort: high";

  @override
  String get modelSpecFormInvalidJson => "يجب أن يكون تعديل الاستدلال المخصص كائن JSON صالحًا.";

  @override
  String get modelSpecFormInvalidNumber => "يرجى إدخال رقم صالح.";

  @override
  String get modelSpecFormStrategySection => "الاستراتيجية";

  @override
  String get modelSpecFormSampling => "أخذ العينات";

  @override
  String get modelSpecFormRequestQuirks => "توافق الطلبات";

  @override
  String get modelSpecFormDynamicWebSearch => "أدوات بحث الويب ذات التصفية الديناميكية";

  @override
  String get modelSpecFormDynamicWebSearchSubtitle => "عند تفعيل التصفية الديناميكية، أرسل أدوات البحث والجلب المحدّثة بتاريخ 2026-03-18.";

  @override
  String get modelSpecFormRemoteImageUrls => "روابط الصور البعيدة";

  @override
  String get modelSpecFormRemoteImageUrlsSubtitle => "أرسل روابط الصور عبر http(s) كما هي؛ وعند التعطيل تُستبعد الروابط البعيدة ولا تُرسل إلا الصور المحلية.";

  @override
  String get modelSpecFormPromptCacheControl => "علامة تخزين التعليمات مؤقتًا";

  @override
  String get modelSpecFormPromptCacheControlSubtitle => "عند تفعيل تخزين التعليمات مؤقتًا، أضف cache_control إلى طلبات OpenRouter.";

  @override
  String get modelSpecFormSamplingAlways => "دائمًا";

  @override
  String get modelSpecFormSamplingAlwaysSubtitle => "الإبقاء على temperature وحقول أخذ العينات الأخرى.";

  @override
  String get modelSpecFormSamplingOnlyWhenReasoningOff => "فقط عند إيقاف الاستدلال";

  @override
  String get modelSpecFormSamplingOnlyWhenReasoningOffSubtitle => "إزالة حقول أخذ العينات أثناء تفكير النموذج.";

  @override
  String get modelSpecFormSamplingNever => "مطلقًا";

  @override
  String get modelSpecFormSamplingNeverSubtitle => "إزالة حقول أخذ العينات دائمًا.";

  @override
  String get modelSpecFormReplay => "إعادة تمرير الاستدلال";

  @override
  String get modelSpecFormReplayNone => "بدون";

  @override
  String get modelSpecFormReplayNoneSubtitle => "عدم إرسال الاستدلال السابق إلى النموذج مجددًا.";

  @override
  String get modelSpecFormReplayToolTurns => "في أدوار استدعاء الأدوات";

  @override
  String get modelSpecFormReplayToolTurnsSubtitle => "إعادة تمرير الاستدلال في الأدوار التي تستدعي الأدوات.";

  @override
  String get modelSpecFormReplayAll => "الكل";

  @override
  String get modelSpecFormReplayAllSubtitle => "إعادة تمرير الاستدلال في كل دور متابعة.";

  @override
  String get modelSpecFormReplayField => "حقل إعادة التمرير";

  @override
  String get modelSpecFormLimitsSection => "الحدود";

  @override
  String get modelSpecFormLimitsPricingSection => "الحدود والأسعار";

  @override
  String get modelSpecFormContextWindow => "نافذة السياق";

  @override
  String get modelSpecFormMaxOutput => "الحد الأقصى للإخراج";

  @override
  String get modelSpecFormPricingSection => "التكلفة لكل مليون رمز";

  @override
  String get modelSpecFormPricingInput => "الإدخال";

  @override
  String get modelSpecFormPricingOutput => "الإخراج";

  @override
  String get modelSpecFormPricingCacheRead => "قراءة ذاكرة التخزين المؤقت";

  @override
  String get modelSpecFormPricingCacheWrite => "الكتابة في ذاكرة التخزين المؤقت";

  @override
  String get modelSpecFormCurrency => "العملة";

  @override
  String get modelSpecFormAdvancedSection => "الطلب";

  @override
  String get modelSelectSheetSearchHint => "البحث عن النماذج أو مزوّدي الخدمة";

  @override
  String get modelSelectSheetFavoritesSection => "المفضّلة";

  @override
  String get modelSelectSheetFollowAssistant => "اتباع إعداد المساعد";

  @override
  String get modelSelectSheetFavoriteTooltip => "إضافة إلى المفضّلة";

  @override
  String get modelSelectSheetChatType => "محادثة";

  @override
  String get modelSelectSheetEmbeddingType => "تضمين المتجهات";

  @override
  String get providerDetailPageShareTooltip => "مشاركة";

  @override
  String get providerDetailPageDeleteProviderTooltip => "حذف مزوّد الخدمة";

  @override
  String get providerDetailPageDeleteProviderTitle => "حذف مزوّد الخدمة";

  @override
  String get providerDetailPageDeleteProviderContent => "هل أنت متأكد من حذف مزوّد الخدمة هذا؟ لا يمكن التراجع عن هذا الإجراء.";

  @override
  String get providerDetailPageCancelButton => "إلغاء";

  @override
  String get providerDetailPageDeleteButton => "حذف";

  @override
  String get providerDetailPageProviderDeletedSnackbar => "تم حذف مزوّد الخدمة";

  @override
  String get providerDetailPageConfigTab => "الإعدادات";

  @override
  String get providerDetailPageModelsTab => "النماذج";

  @override
  String get providerDetailPageCustomRequestTitle => "طلب مخصص";

  @override
  String get providerDetailPageCustomRequestDescription => "تُطبّق هذه الإعدادات على جميع نماذج مزوّد الخدمة. تتجاوز إعدادات النموذج هذه القيم، وتتجاوز هذه القيم إعدادات المساعد.";

  @override
  String get providerDetailPageNetworkTab => "الشبكة";

  @override
  String get providerDetailPageEnabledTitle => "مفعّل";

  @override
  String get providerDetailPageManageSectionTitle => "الإدارة";

  @override
  String get providerDetailPageNameLabel => "الاسم";

  @override
  String get providerDetailPageApiKeyHint => "اتركه فارغًا لاستخدام المفتاح الافتراضي";

  @override
  String get providerDetailPageHideTooltip => "إخفاء";

  @override
  String get providerDetailPageShowTooltip => "إظهار";

  @override
  String get providerDetailPageApiPathLabel => "مسار API";

  @override
  String get providerDetailPageResponseApiTitle => "واجهة Response API (/responses)";

  @override
  String get providerDetailPagePromptCacheKeyTitle => "إرسال مفتاح التخزين المؤقت للمحادثة";

  @override
  String get providerDetailPagePromptCacheKeyHelp => "يضيف قيمة ثابتة prompt_cache_key لكل محادثة في الطلبات المتوافقة مع OpenAI. فعّل هذا الخيار فقط إذا كان مزوّد الخدمة يدعمه. تكون لقيم Custom Body الأولوية، ولا يُضمن تحقق إصابة في ذاكرة التخزين المؤقت.";

  @override
  String get providerDetailPageAihubmixAppCodeLabel => "رمز التطبيق (خصم 10%)";

  @override
  String get providerDetailPageAihubmixAppCodeHelp => "يضيف ترويسة APP-Code إلى الطلبات للحصول على خصم 10%. يؤثر هذا الخيار في AIhubmix فقط.";

  @override
  String get providerDetailPageClaudePromptCachingTitle => "التخزين المؤقت لتعليمات Claude";

  @override
  String get providerDetailPageClaudePromptCachingHelp => "يضيف cache_control إلى طلبات Claude عبر Anthropic أو OpenRouter.";

  @override
  String get providerDetailPageClaudePromptCachingTtlTitle => "مدة الاحتفاظ بذاكرة التخزين المؤقت";

  @override
  String get providerDetailPageClaudePromptCachingTtlHelp => "الافتراضي 5 دقائق. تكلفة الكتابة لمدة ساعة أعلى، لكنها قد تقلل إعادة البناء في المحادثات الطويلة.";

  @override
  String get providerDetailPageClaudePromptCachingTtl5m => "5 دقائق";

  @override
  String get providerDetailPageClaudePromptCachingTtl1h => "ساعة واحدة";

  @override
  String get providerDetailPageBalanceTitle => "رصيد الحساب";

  @override
  String get providerDetailPageBalanceInfo => "الحصول على رصيد الحساب";

  @override
  String get providerDetailPageBalanceApiPathLabel => "مسار أو عنوان URL لواجهة الرصيد";

  @override
  String get providerDetailPageBalanceMethodLabel => "طريقة HTTP";

  @override
  String providerDetailPageBalanceRequestHint(String apiKeyPlaceholder) => "تنطبق هذه الإعدادات على الاستعلام عن الرصيد فقط. استخدم ${apiKeyPlaceholder} في الترويسات أو متن الطلب لإدراج مفتاح API الحالي. طريقة المصادقة الافتراضية هي Bearer؛ وتؤدي قيمة الترويسة الفارغة إلى إزالة تلك الترويسة.";

  @override
  String get providerDetailPageBalanceBodyLabel => "متن الطلب (اختياري)";

  @override
  String get providerDetailPageBalanceBodyHint => "يُرسل مع POST فقط. اتركه فارغًا لعدم إرسال متن. نوع المحتوى الافتراضي هو application/json؛ أضف ترويسة لاستخدام تنسيق آخر.";

  @override
  String get providerDetailPageBalanceResultPathLabel => "مسار نتيجة JSON";

  @override
  String get providerDetailPageBalanceQueryButton => "التحقق من الرصيد";

  @override
  String get providerDetailPageBalanceQuerying => "جارٍ التحقق…";

  @override
  String get providerDetailPageBalanceResetDefaultsButton => "إعادة تعيين";

  @override
  String get providerDetailPageBalanceResetDefaultsTooltip => "إعادة تعيين إعدادات الرصيد";

  @override
  String providerDetailPageBalanceResult(String value) => "الرصيد: ${value}";

  @override
  String providerDetailPageBalanceError(String message) => "فشل الاستعلام عن الرصيد: ${message}";

  @override
  String get providerDetailPageLocationLabel => "الموقع";

  @override
  String get providerDetailPageProjectIdLabel => "معرّف المشروع";

  @override
  String get providerDetailPageServiceAccountJsonLabel => "ملف JSON لحساب الخدمة (الصق المحتوى أو استورده)";

  @override
  String get providerDetailPageImportJsonButton => "استيراد JSON";

  @override
  String get providerDetailPageImportJsonReadFailedMessage => "تعذّرت قراءة الملف";

  @override
  String get providerDetailPageTestButton => "اختبار";

  @override
  String get providerDetailPageSaveButton => "حفظ";

  @override
  String get providerDetailPageProviderRemovedMessage => "تمت إزالة مزوّد الخدمة";

  @override
  String get providerDetailPageNoModelsTitle => "لا توجد نماذج";

  @override
  String get providerDetailPageNoModelsSubtitle => "اضغط على أحد الأزرار أدناه لإضافة نماذج";

  @override
  String get providerDetailPageDeleteModelButton => "حذف";

  @override
  String get providerDetailPageConfirmDeleteTitle => "تأكيد الحذف";

  @override
  String get providerDetailPageConfirmDeleteContent => "يمكن التراجع عن هذا الإجراء باستخدام «تراجع». هل تريد الحذف؟";

  @override
  String get providerDetailPageModelDeletedSnackbar => "تم حذف النموذج";

  @override
  String get providerDetailPageUndoButton => "تراجع";

  @override
  String get providerDetailPageAddNewModelButton => "إضافة نموذج";

  @override
  String get providerDetailPageFetchModelsButton => "جلب النماذج";

  @override
  String get providerDetailPageEnableProxyTitle => "تفعيل الوكيل";

  @override
  String get providerDetailPageHostLabel => "المضيف";

  @override
  String get providerDetailPagePortLabel => "المنفذ";

  @override
  String get providerDetailPageUsernameOptionalLabel => "اسم المستخدم (اختياري)";

  @override
  String get providerDetailPagePasswordOptionalLabel => "كلمة المرور (اختيارية)";

  @override
  String get providerDetailPageSavedSnackbar => "تم الحفظ";

  @override
  String get providerDetailPageEmbeddingsGroupTitle => "التضمينات";

  @override
  String get providerDetailPageOtherModelsGroupTitle => "أخرى";

  @override
  String get providerDetailPageRemoveGroupTooltip => "إزالة المجموعة";

  @override
  String get providerDetailPageAddGroupTooltip => "إضافة مجموعة";

  @override
  String get providerDetailPageFilterHint => "اكتب اسم النموذج للتصفية";

  @override
  String get providerDetailPageDeleteText => "حذف";

  @override
  String get providerDetailPageEditTooltip => "تعديل";

  @override
  String get providerDetailPageTestConnectionTitle => "اختبار الاتصال";

  @override
  String get providerDetailPageSelectModelButton => "اختيار نموذج";

  @override
  String get providerDetailPageChangeButton => "تغيير";

  @override
  String get providerDetailPageUseStreamingLabel => "استخدام الإخراج المتدفق";

  @override
  String get providerDetailPageTestingMessage => "جارٍ الاختبار…";

  @override
  String get providerDetailPageTestSuccessMessage => "نجح الاختبار";

  @override
  String get providersPageTitle => "مزوّدو الخدمة";

  @override
  String get providersPageImportTooltip => "استيراد";

  @override
  String get providersPageAddTooltip => "إضافة";

  @override
  String get providersPageSearchHint => "البحث عن مزوّدي الخدمة أو المجموعات";

  @override
  String get providersPageProviderAddedSnackbar => "تمت إضافة مزوّد الخدمة";

  @override
  String get modelCatalogTitle => "كتالوج النماذج";

  @override
  String modelCatalogSourceBundled(String date) => "نسخة مضمّنة · ${date}";

  @override
  String modelCatalogSourceRemote(String date) => "models.dev · تم التحديث ${date}";

  @override
  String get modelCatalogAutoUpdate => "التحديث التلقائي كل 24 ساعة";

  @override
  String get modelCatalogRefresh => "التحديث الآن";

  @override
  String get modelCatalogUpdated => "تم تحديث كتالوج النماذج";

  @override
  String modelCatalogRefreshFailed(String error) => "فشل التحديث: ${error}";

  @override
  String modelCatalogProviderCount(int count) => "${count} من مزوّدي الخدمة";

  @override
  String modelCatalogModelCount(int count) => "${count} من النماذج";

  @override
  String get providerGroupsGroupLabel => "المجموعة";

  @override
  String get providerGroupsOther => "أخرى";

  @override
  String get providerGroupsOtherUngroupedOption => "أخرى (غير مصنّفة)";

  @override
  String get providerGroupsPickerTitle => "اختيار مجموعة";

  @override
  String get providerGroupsManageTitle => "إدارة المجموعات";

  @override
  String get providerGroupsManageAction => "إدارة المجموعات";

  @override
  String get providerGroupsCreateNewGroupAction => "مجموعة جديدة…";

  @override
  String get providerGroupsCreateDialogTitle => "مجموعة جديدة";

  @override
  String get providerGroupsNameHint => "اسم المجموعة";

  @override
  String get providerGroupsCreateDialogCancel => "إلغاء";

  @override
  String get providerGroupsCreateDialogOk => "إنشاء";

  @override
  String get providerGroupsCreateFailedToast => "فشل إنشاء المجموعة";

  @override
  String get providerGroupsDeleteConfirmTitle => "هل تريد حذف المجموعة؟";

  @override
  String get providerGroupsDeleteConfirmContent => "سيتم نقل مزوّدي الخدمة في هذه المجموعة إلى «أخرى».";

  @override
  String get providerGroupsDeleteConfirmCancel => "إلغاء";

  @override
  String get providerGroupsDeleteConfirmOk => "حذف";

  @override
  String get providerGroupsDeletedToast => "تم حذف المجموعة";

  @override
  String get providerGroupsEmptyState => "لا توجد مجموعات بعد.";

  @override
  String get providerGroupsExpandToMoveToast => "وسّع المجموعة أولًا.";

  @override
  String get providersPageEnabledStatus => "مفعّل";

  @override
  String get providersPageDisabledStatus => "متوقف";

  @override
  String get providersPageModelsCountSuffix => " نماذج";

  @override
  String get providersPageModelsCountSingleSuffix => " نماذج";

  @override
  String get addProviderSheetTitle => "إضافة مزوّد خدمة";

  @override
  String get addProviderSheetEnabledLabel => "مفعّل";

  @override
  String get addProviderSheetNameLabel => "الاسم";

  @override
  String get addProviderSheetApiPathLabel => "مسار API";

  @override
  String get addProviderSheetVertexAiLocationLabel => "الموقع";

  @override
  String get addProviderSheetVertexAiProjectIdLabel => "معرّف المشروع";

  @override
  String get addProviderSheetVertexAiServiceAccountJsonLabel => "ملف JSON لحساب الخدمة (الصق المحتوى أو استورده)";

  @override
  String get addProviderSheetImportJsonButton => "استيراد JSON";

  @override
  String get addProviderSheetCancelButton => "إلغاء";

  @override
  String get addProviderSheetAddButton => "إضافة";

  @override
  String get importProviderSheetTitle => "استيراد مزوّد خدمة";

  @override
  String get importProviderSheetScanQrTooltip => "مسح رمز QR";

  @override
  String get importProviderSheetFromGalleryTooltip => "من المعرض";

  @override
  String importProviderSheetImportSuccessMessage(int count) => "تم استيراد ${count} من مزوّدي الخدمة.";

  @override
  String importProviderSheetImportFailedMessage(String error) => "فشل الاستيراد: ${error}";

  @override
  String get importProviderSheetDescription => "الصق نصوص المشاركة (يمكن استخدام عدة أسطر) أو بيانات ChatBox بصيغة JSON.";

  @override
  String get importProviderSheetInputHint => "ai-provider:v1:... أو JSON";

  @override
  String get importProviderSheetCancelButton => "إلغاء";

  @override
  String get importProviderSheetImportButton => "استيراد";

  @override
  String get shareProviderSheetTitle => "مشاركة مزوّد الخدمة";

  @override
  String get shareProviderSheetDescription => "انسخ رمز QR أو شاركه.";

  @override
  String get shareProviderSheetCopiedMessage => "تم النسخ";

  @override
  String get shareProviderSheetCopyButton => "نسخ";

  @override
  String get shareProviderSheetShareButton => "مشاركة";

  @override
  String get desktopProviderContextMenuShare => "مشاركة";

  @override
  String get desktopProviderShareCopyText => "نسخ الرمز";

  @override
  String get desktopProviderShareCopyQr => "نسخ رمز QR";

  @override
  String get providerDetailPageApiBaseUrlLabel => "عنوان API الأساسي";

  @override
  String get providerDetailPageModelsTitle => "النماذج";

  @override
  String get providerModelsGetButton => "جلب";

  @override
  String get providerDetailPageCapsVision => "الرؤية";

  @override
  String get providerDetailPageCapsImage => "الصور";

  @override
  String get providerDetailPageCapsTool => "الأدوات";

  @override
  String get providerDetailPageCapsReasoning => "الاستدلال";

  @override
  String get qrScanPageTitle => "مسح رمز QR";

  @override
  String get qrScanPageInstruction => "ضع رمز QR داخل الإطار";

  @override
  String get searchServicesPageBackTooltip => "رجوع";

  @override
  String get searchServicesPageTitle => "خدمات البحث";

  @override
  String get searchServicesPageDone => "تم";

  @override
  String get searchServicesPageEdit => "تعديل";

  @override
  String get searchServicesPageAddProvider => "إضافة مزوّد خدمة";

  @override
  String get searchServicesPageSearchProviders => "البحث عن مزوّدي الخدمة";

  @override
  String get searchServicesPageGeneralOptions => "خيارات عامة";

  @override
  String get searchServicesPageAutoTestTitle => "اختبار الاتصالات تلقائيًا عند التشغيل";

  @override
  String get searchServicesPageWebFetchSection => "قراءة صفحات الويب";

  @override
  String get searchServicesPageWebFetchModeTitle => "قراءة الصفحات باستخدام";

  @override
  String get searchServicesPageWebFetchFollow => "اتباع خدمة البحث";

  @override
  String searchServicesPageWebFetchFollowValue(String name) => "اتباع البحث · ${name}";

  @override
  String searchServicesPageWebFetchFollowSubtitle(String name) => "المحدد حاليًا: ${name}";

  @override
  String get searchServicesPageWebFetchLocal => "محلي";

  @override
  String get searchServicesPageWebFetchLocalSubtitle => "مجاني. يطلب هذا الجهاز الصفحة مباشرةً.";

  @override
  String get searchServicesPageWebFetchProviderSubtitle => "يستخدم مفتاح API وحصة الاستخدام الخاصة بهذه الخدمة.";

  @override
  String get searchServicesPageWebFetchOff => "إيقاف";

  @override
  String get searchServicesPageWebFetchOffSubtitle => "بحث فقط دون قراءة الصفحات";

  @override
  String get searchServicesPageWebFetchFooter => "عند تفعيل بحث الويب، يمكن للنموذج أيضًا قراءة الصفحات كاملةً. إذا تعذّر على خدمة البحث قراءة الصفحات، فستُستخدم القراءة المحلية، لكنها لا تتعامل مع الصفحات التي تتطلب JavaScript أو تحظر برامج الروبوت.\n\nإذا استخدمت قارئ الصفحات الذي تم ضبطه هنا، فعطّل الأداة المدمجة @kelivo/fetch من الإعدادات ← MCP لتجنب تداخل الأدوات. سيظل قارئ الصفحات المضبوط هنا يعمل.";

  @override
  String get searchServicesPageWebFetchSupported => "يمكنه قراءة صفحات الويب";

  @override
  String get searchServicesPageMaxResults => "الحد الأقصى للنتائج";

  @override
  String get searchServicesPageTimeoutSeconds => "مهلة الانتظار (بالثواني)";

  @override
  String get searchServicesPageAtLeastOneServiceRequired => "يجب إعداد خدمة بحث واحدة على الأقل.";

  @override
  String get searchServicesPageTestingStatus => "جارٍ الاختبار…";

  @override
  String get searchServicesPageConnectedStatus => "متصل";

  @override
  String get searchServicesPageFailedStatus => "فشل";

  @override
  String get searchServicesPageNotTestedStatus => "لم يُختبر";

  @override
  String get searchServicesPageEditServiceTooltip => "تعديل الخدمة";

  @override
  String get searchServicesPageTestConnectionTooltip => "اختبار الاتصال";

  @override
  String get searchServicesPageDeleteServiceTooltip => "حذف الخدمة";

  @override
  String get searchServicesPageConfiguredStatus => "تم الإعداد";

  @override
  String get miniMapTitle => "خريطة مصغّرة";

  @override
  String get miniMapTooltip => "الخريطة المصغّرة";

  @override
  String get miniMapScrollToBottomTooltip => "الانتقال إلى الأسفل";

  @override
  String miniMapSearchMatchCount(int count) => "عدد التطابقات: ${count}";

  @override
  String get miniMapSearchNoResults => "لا توجد رسائل مطابقة";

  @override
  String get searchServicesPageApiKeyRequiredStatus => "مطلوب مفتاح API";

  @override
  String get searchServicesPageUrlRequiredStatus => "الرابط مطلوب";

  @override
  String get searchServicesAddDialogTitle => "إضافة خدمة بحث";

  @override
  String get searchServicesAddDialogServiceType => "نوع الخدمة";

  @override
  String get searchServicesAddDialogBingLocal => "محلي";

  @override
  String get searchServicesAddDialogCancel => "إلغاء";

  @override
  String get searchServicesAddDialogAdd => "إضافة";

  @override
  String get searchServicesAddDialogApiKeyRequired => "مفتاح API مطلوب.";

  @override
  String get searchServicesFieldCustomUrlOptional => "رابط مخصص (اختياري)";

  @override
  String get searchServicesDialogApiKey => "مفتاح API";

  @override
  String get searchServicesDialogApiKeyOptional => "مفتاح API (اختياري)";

  @override
  String get searchServicesDialogModel => "النموذج";

  @override
  String get searchServicesDialogSystemPrompt => "تعليمات النظام";

  @override
  String get searchServicesAddDialogInstanceUrl => "رابط المثيل";

  @override
  String get searchServicesAddDialogUrlRequired => "الرابط مطلوب.";

  @override
  String get searchServicesAddDialogEnginesOptional => "محركات البحث (اختياري)";

  @override
  String get searchServicesAddDialogLanguageOptional => "اللغة (اختياري)";

  @override
  String get searchServicesAddDialogUsernameOptional => "اسم المستخدم (اختياري)";

  @override
  String get searchServicesAddDialogPasswordOptional => "كلمة المرور (اختياري)";

  @override
  String get searchServicesAddDialogRegionOptional => "المنطقة (اختياري، الافتراضي: us-en)";

  @override
  String get searchServicesEditDialogEdit => "تعديل";

  @override
  String get searchServicesEditDialogCancel => "إلغاء";

  @override
  String get searchServicesEditDialogSave => "حفظ";

  @override
  String get searchServicesEditDialogBingLocalNoConfig => "لا يتطلب بحث Bing المحلي أي إعدادات.";

  @override
  String get searchServicesEditDialogApiKeyRequired => "مفتاح API مطلوب.";

  @override
  String get searchServicesEditDialogInstanceUrl => "رابط المثيل";

  @override
  String get searchServicesEditDialogUrlRequired => "الرابط مطلوب.";

  @override
  String get searchServicesEditDialogEnginesOptional => "محركات البحث (اختياري)";

  @override
  String get searchServicesEditDialogLanguageOptional => "اللغة (اختياري)";

  @override
  String get searchServicesEditDialogUsernameOptional => "اسم المستخدم (اختياري)";

  @override
  String get searchServicesEditDialogPasswordOptional => "كلمة المرور (اختياري)";

  @override
  String get searchServicesEditDialogRegionOptional => "المنطقة (اختياري، الافتراضي: us-en)";

  @override
  String get searchServiceEditorProviderTypeTitle => "مزوّد البحث";

  @override
  String get searchServiceEditorConfigurationTitle => "الإعدادات";

  @override
  String get searchServiceEditorNoConfiguration => "لا يحتاج هذا المزوّد إلى إعدادات إضافية.";

  @override
  String get searchServiceEditorMultiKeyTitle => "تدوير المفاتيح المتعددة";

  @override
  String get searchServiceEditorMultiKeyNone => "لم يتم الإعداد";

  @override
  String get searchApiKeysPageDescription => "يتم تدوير المفاتيح حسب ترتيبها في القائمة؛ المفتاح الأول هو الأساسي. لا يتم الاستعلام عن الاستخدام لتجنب تجاوز حدود معدّل الطلبات لدى المزوّد.";

  @override
  String get searchApiKeysPagePrimaryBadge => "أساسي";

  @override
  String get searchApiKeysPageBatchHint => "الصق مفتاحًا واحدًا أو أكثر — مفتاح في كل سطر أو مفصولة بفواصل.";

  @override
  String searchApiKeysPageBatchResult(String added, String skipped) => "تمت إضافة ${added}، وتخطي ${skipped} من المفاتيح المكررة.";

  @override
  String get searchApiKeysPageAdd => "إضافة";

  @override
  String get searchApiKeysPageEmpty => "لم تتم إضافة أي مفاتيح بعد.";

  @override
  String searchServiceEditorMultiKeyCount(String count) => "عدد المفاتيح: ${count}";

  @override
  String get searchServiceEditorUsageTitle => "استخدام الحساب";

  @override
  String get searchServiceEditorUsageNotQueried => "لم يتم الاستعلام عن الاستخدام بعد.";

  @override
  String get searchServiceEditorUsageQuery => "التحقق من الاستخدام";

  @override
  String get searchServiceEditorUsageQuerying => "جارٍ التحقق…";

  @override
  String searchServiceEditorUsageRemaining(String remaining) => "الرصيد المتبقي: ${remaining}";

  @override
  String searchServiceEditorUsageBalance(String balance) => "الرصيد: ${balance}";

  @override
  String searchServiceEditorUsageUsed(String used, String limit) => "تم استخدام ${used} من أصل ${limit} رصيدًا.";

  @override
  String searchServiceEditorUsageFailed(String message) => "تعذّر الاستعلام عن الاستخدام: ${message}";

  @override
  String get searchServiceEditorTestTitle => "اختبار البحث";

  @override
  String get searchServiceEditorTestQueryHint => "أدخل عبارة البحث";

  @override
  String get searchServiceEditorTestRun => "تنفيذ بحث تجريبي";

  @override
  String get searchServiceEditorTestRunning => "جارٍ البحث…";

  @override
  String get searchServiceEditorTestNoResults => "لم يُرجع المزوّد أي نتائج.";

  @override
  String searchServiceEditorTestFailed(String message) => "فشل البحث: ${message}";

  @override
  String get searchServiceEditorTestModeSearch => "بحث";

  @override
  String get searchServiceEditorTestModeFetch => "قراءة صفحة";

  @override
  String get searchServiceEditorTestUrlHint => "أدخل رابطًا";

  @override
  String get searchServiceEditorTestFetchRun => "تنفيذ جلب تجريبي";

  @override
  String get searchServiceEditorTestFetchRunning => "جارٍ القراءة…";

  @override
  String searchServiceEditorTestFetchFailed(String message) => "فشل جلب الصفحة: ${message}";

  @override
  String searchServiceEditorTestFetchStats(String characters, String seconds) => "${characters} حرفًا · ${seconds} ث";

  @override
  String get searchServiceEditorResultOpenTooltip => "فتح النتيجة";

  @override
  String get searchServiceEditorDeleteTooltip => "حذف خدمة البحث";

  @override
  String get searchServiceEditorDeleteTitle => "حذف خدمة البحث؟";

  @override
  String searchServiceEditorDeleteMessage(String provider) => "هل تريد حذف ${provider}؟ لا يمكن التراجع عن هذا الإجراء.";

  @override
  String get searchServiceEditorDeleteConfirm => "حذف";

  @override
  String get searchServiceEditorDiscardTitle => "تجاهل التغييرات؟";

  @override
  String get searchServiceEditorDiscardMessage => "ستفقد إعدادات خدمة البحث التي لم تحفظها.";

  @override
  String get searchServiceEditorKeepEditing => "متابعة التعديل";

  @override
  String get searchServiceEditorDiscard => "تجاهل";

  @override
  String get searchSettingsSheetTitle => "إعدادات البحث";

  @override
  String get searchSettingsSheetBuiltinSearchTitle => "البحث المدمج";

  @override
  String get searchSettingsSheetBuiltinSearchDescription => "تفعيل البحث المدمج في النموذج";

  @override
  String get searchSettingsSheetClaudeDynamicSearchTitle => "التصفية الديناميكية";

  @override
  String get searchSettingsSheetClaudeDynamicSearchDescription => "تصفية النتائج لتوفير الرموز";

  @override
  String get searchSettingsSheetWebSearchTitle => "بحث الويب";

  @override
  String get searchSettingsSheetWebSearchDescription => "تفعيل البحث عبر الويب في المحادثة";

  @override
  String get searchSettingsSheetOpenSearchServicesTooltip => "فتح خدمات البحث";

  @override
  String get searchSettingsSheetNoServicesMessage => "لا توجد خدمات. أضف خدمة من صفحة خدمات البحث.";

  @override
  String get aboutPageEasterEggMessage => "شكرًا لاستكشافك التطبيق!\n (لا توجد مفاجأة بعد)";

  @override
  String get aboutPageEasterEggButton => "رائع!";

  @override
  String get aboutPageKelivoSearchUnlocked => "انفتح باب مجهول قليلًا. قد تجده في الإعدادات.";

  @override
  String get aboutPageKelivoSearchAlreadyUnlocked => "لقد مررت من هذا الباب من قبل.";

  @override
  String get aboutPageAppDescription => "مساعد ذكاء اصطناعي مفتوح المصدر";

  @override
  String get aboutPageNoQQGroup => "لا توجد مجموعة QQ بعد";

  @override
  String get aboutPageVersion => "الإصدار";

  @override
  String get aboutPageSystem => "النظام";

  @override
  String get aboutPageLoadingPlaceholder => "…";

  @override
  String get aboutPageUnknownPlaceholder => "—";

  @override
  String aboutPagePlatformOther(String os) => "أخرى (${os})";

  @override
  String get aboutPageWebsite => "الموقع الإلكتروني";

  @override
  String get aboutPageLicense => "الترخيص";

  @override
  String get aboutPageJoinQQGroup => "انضم إلى مجموعة QQ";

  @override
  String get aboutPageQQGroupOne => "مجموعة Kelivo الأولى";

  @override
  String get aboutPageQQGroupTwo => "مجموعة Kelivo الثانية";

  @override
  String get aboutPageQQGroupThree => "مجموعة Kelivo الثالثة";

  @override
  String get aboutPageJoinDiscord => "انضم إلينا على Discord";

  @override
  String get displaySettingsPageShowUserAvatarTitle => "إظهار الصورة الرمزية للمستخدم";

  @override
  String get displaySettingsPageShowUserAvatarSubtitle => "عرض الصورة الرمزية للمستخدم في رسائل المحادثة";

  @override
  String get displaySettingsPageShowUserNameTimestampTitle => "إظهار اسم المستخدم والطابع الزمني";

  @override
  String get displaySettingsPageShowUserNameTimestampSubtitle => "عرض اسم المستخدم والطابع الزمني أسفله في رسائل المحادثة";

  @override
  String get displaySettingsPageShowUserNameTitle => "إظهار اسم المستخدم";

  @override
  String get displaySettingsPageShowUserTimestampTitle => "إظهار وقت رسالة المستخدم";

  @override
  String get displaySettingsPageShowUserMessageActionsTitle => "إظهار إجراءات رسائل المستخدم";

  @override
  String get displaySettingsPageShowUserMessageActionsSubtitle => "عرض أزرار النسخ وإعادة الإرسال والمزيد أسفل رسائلك";

  @override
  String get displaySettingsPageShowModelNameTimestampTitle => "إظهار اسم النموذج والطابع الزمني";

  @override
  String get displaySettingsPageShowModelNameTimestampSubtitle => "عرض اسم النموذج والطابع الزمني أسفله في رسائل المحادثة";

  @override
  String get displaySettingsPageShowModelNameTitle => "إظهار اسم النموذج";

  @override
  String get displaySettingsPageShowModelTimestampTitle => "إظهار وقت استجابة النموذج";

  @override
  String get displaySettingsPageShowProviderInChatMessageTitle => "إظهار مزوّد الخدمة بعد اسم النموذج";

  @override
  String get displaySettingsPageShowProviderInChatMessageSubtitle => "عرض اسم مزوّد الخدمة بعد معرّف النموذج في رسائل المحادثة (مثال: model | provider)";

  @override
  String get displaySettingsPageChatModelIconTitle => "أيقونة نموذج المحادثة";

  @override
  String get displaySettingsPageChatModelIconSubtitle => "عرض أيقونة النموذج في رسائل المحادثة";

  @override
  String get displaySettingsPageShowTokenStatsTitle => "إظهار إحصاءات الرموز والسياق";

  @override
  String get displaySettingsPageShowTotalTokensTitle => "إظهار عدد الرموز للدور بأكمله";

  @override
  String get displaySettingsPageShowTotalTokensSubtitle => "جمع الاستخدام عبر جميع طلبات API في الرد. عند إيقاف الخيار، يُعرض الطلب الأخير فقط. تتضمن الإحصاءات جميع الطلبات دائمًا.";

  @override
  String get displaySettingsPageShowTokenStatsSubtitle => "عرض استخدام الرموز وعدد الرسائل";

  @override
  String get displaySettingsPageShowThinkingCardsTitle => "إظهار بطاقات التفكير";

  @override
  String get displaySettingsPageShowThinkingCardsSubtitle => "عند إيقاف الخيار، تُخفى بطاقات عملية التفكير في المحادثة.";

  @override
  String get displaySettingsPageShowToolCardsTitle => "إظهار بطاقات الأدوات";

  @override
  String get displaySettingsPageShowToolCardsSubtitle => "عند إيقاف الخيار، تُخفى بطاقات استخدام الأدوات في المحادثة.";

  @override
  String get displaySettingsShowReasoningLevelBadge => "إظهار مستوى الاستدلال على الزر";

  @override
  String get displaySettingsShowReasoningLevelBadgeSubtitle => "عرض المستوى الحالي بجوار أيقونة الاستدلال في شريط الإدخال";

  @override
  String get displaySettingsPageAutoCollapseThinkingTitle => "طيّ التفكير تلقائيًا";

  @override
  String get displaySettingsPageAutoCollapseThinkingSubtitle => "طيّ تفاصيل الاستدلال بعد الانتهاء";

  @override
  String get displaySettingsPageCollapseThinkingStepsTitle => "طيّ خطوات التفكير";

  @override
  String get displaySettingsPageCollapseThinkingStepsSubtitle => "عرض أحدث الخطوات فقط إلى أن يتم التوسيع";

  @override
  String get displaySettingsPageShowToolResultSummaryTitle => "إظهار ملخص نتائج الأدوات";

  @override
  String get displaySettingsPageInsertSuggestionOnlyTitle => "إدراج الاقتراحات دون إرسالها";

  @override
  String get displaySettingsPageShowToolResultSummarySubtitle => "عرض نص الملخص أسفل خطوات الأداة";

  @override
  String get displaySettingsPageHideToolResultImagesTitle => "إخفاء الصور في نتائج الأدوات";

  @override
  String get displaySettingsPageRegenerateDeleteTrailingMessagesTitle => "حذف الرسائل اللاحقة عند إعادة التوليد";

  @override
  String get displaySettingsPageShowRegenerateConfirmDialogTitle => "طلب التأكيد قبل إعادة التوليد";

  @override
  String get displaySettingsPageForkKeepMessageVersionsTitle => "الاحتفاظ بإصدارات الرسائل عند إنشاء فرع";

  @override
  String get displaySettingsPageEditAssistantKeepThinkingToolCardsTitle => "الاحتفاظ ببطاقات التفكير والأدوات عند تعديل المساعد";

  @override
  String get displaySettingsPageEditAssistantKeepThinkingToolCardsSubtitle => "عند إيقاف الخيار، يحتفظ الإصدار المعدّل بنص المساعد فقط. وعند العودة إلى الإصدار السابق، تظل بطاقات التفكير والأدوات السابقة ظاهرة.";

  @override
  String chainOfThoughtExpandSteps(Object count) => "إظهار ${count} خطوات إضافية";

  @override
  String get chainOfThoughtCollapse => "طيّ";

  @override
  String get displaySettingsPageShowChatListDateTitle => "إظهار تواريخ قائمة المحادثات";

  @override
  String get displaySettingsPageShowChatListDateSubtitle => "عرض تسميات مجموعات التاريخ في قائمة المحادثات";

  @override
  String get displaySettingsPageEnableImageCropperTitle => "تفعيل قص الصور";

  @override
  String get displaySettingsPageEnableImageCropperSubtitle => "قص الصور بعد اختيارها من المعرض أو الكاميرا";

  @override
  String get displaySettingsPageKeepSidebarOpenOnAssistantTapTitle => "إبقاء الشريط الجانبي مفتوحًا عند اختيار مساعد";

  @override
  String get displaySettingsPageKeepSidebarOpenOnTopicTapTitle => "إبقاء الشريط الجانبي مفتوحًا عند اختيار موضوع";

  @override
  String get displaySettingsPageKeepAssistantListExpandedOnSidebarCloseTitle => "عدم طي قائمة المساعدين عند إغلاق الشريط الجانبي";

  @override
  String get displaySettingsPageShowUpdatesTitle => "إظهار التحديثات";

  @override
  String get displaySettingsPageShowUpdatesSubtitle => "عرض إشعارات تحديث التطبيق";

  @override
  String get displaySettingsPageKeepScreenOnDuringGenerationTitle => "إبقاء الشاشة قيد التشغيل أثناء التوليد";

  @override
  String get displaySettingsPageKeepScreenOnDuringGenerationSubtitle => "يمنع شاشة القفل من مقاطعة التوليد، لكنه يزيد استهلاك البطارية.";

  @override
  String get displaySettingsPageMessageNavButtonsTitle => "أزرار التنقل بين الرسائل";

  @override
  String get displaySettingsPageMessageNavButtonsSubtitle => "اختر متى تظهر أزرار الانتقال السريع";

  @override
  String get displaySettingsPageMessageNavButtonsModeAlways => "إظهار دائمًا";

  @override
  String get displaySettingsPageMessageNavButtonsModeScroll => "الإظهار أثناء التمرير";

  @override
  String get displaySettingsPageMessageNavButtonsModeHover => "الإظهار عند تمرير مؤشر الفأرة";

  @override
  String get displaySettingsPageMessageNavButtonsModeScrollAndHover => "الإظهار أثناء التمرير أو تحريك المؤشر";

  @override
  String get displaySettingsPageMessageNavButtonsModeNever => "عدم الإظهار مطلقًا";

  @override
  String get displaySettingsPageUseNewAssistantAvatarUxTitle => "إظهار الصورة الرمزية للمساعد في شريط عنوان المحادثة";

  @override
  String get displaySettingsPageHapticsOnSidebarTitle => "الاهتزاز عند استخدام الشريط الجانبي";

  @override
  String get displaySettingsPageHapticsOnSidebarSubtitle => "تفعيل الاستجابة اللمسية عند فتح الشريط الجانبي أو إغلاقه";

  @override
  String get displaySettingsPageHapticsGlobalTitle => "الاستجابة اللمسية العامة";

  @override
  String get displaySettingsPageHapticsIosSwitchTitle => "الاهتزاز عند تبديل المفتاح";

  @override
  String get displaySettingsPageHapticsOnListItemTapTitle => "الاهتزاز عند الضغط على عناصر القائمة";

  @override
  String get displaySettingsPageHapticsOnCardTapTitle => "الاهتزاز عند الضغط على البطاقات";

  @override
  String get displaySettingsPageHapticsOnGenerateTitle => "الاهتزاز عند التوليد";

  @override
  String get displaySettingsPageHapticsOnGenerateSubtitle => "تفعيل الاستجابة اللمسية أثناء التوليد";

  @override
  String get displaySettingsPageNewChatAfterDeleteTitle => "بدء محادثة جديدة بعد حذف الموضوع";

  @override
  String get displaySettingsPageNewChatOnAssistantSwitchTitle => "بدء محادثة جديدة عند تبديل المساعد";

  @override
  String get displaySettingsPageNewChatOnLaunchTitle => "بدء محادثة جديدة عند التشغيل";

  @override
  String get displaySettingsPageEnterToSendTitle => "استخدام Enter للإرسال";

  @override
  String get displaySettingsPageLongPasteAsFileTitle => "لصق النصوص الطويلة كملف";

  @override
  String get displaySettingsPageLongPasteAsFileThresholdTitle => "حد التحويل";

  @override
  String get displaySettingsPageLongPasteAsFileThresholdUnit => "حرفًا";

  @override
  String get displaySettingsPageSendShortcutTitle => "اختصار الإرسال";

  @override
  String get displaySettingsPageAutoSwitchTopicsTitle => "التبديل تلقائيًا إلى المواضيع";

  @override
  String get desktopDisplaySettingsTopicPositionTitle => "موضع الموضوعات";

  @override
  String get desktopDisplaySettingsTopicPositionLeft => "اليسار";

  @override
  String get desktopDisplaySettingsTopicPositionRight => "اليمين";

  @override
  String get displaySettingsPageNewChatOnLaunchSubtitle => "إنشاء محادثة جديدة تلقائيًا عند تشغيل التطبيق";

  @override
  String get displaySettingsPageChatFontSizeTitle => "حجم خط المحادثة";

  @override
  String get displaySettingsPageAutoScrollEnableTitle => "المتابعة التلقائية لأسفل المحادثة";

  @override
  String get displaySettingsPageAutoScrollDisabledLabel => "متوقف";

  @override
  String get displaySettingsPageChatFontSampleText => "هذا نص تجريبي للمحادثة";

  @override
  String get displaySettingsPageChatBackgroundMaskTitle => "شفافية طبقة خلفية المحادثة";

  @override
  String get displaySettingsPageChatInputBackgroundOpacityTitle => "شفافية خلفية مربع الإدخال";

  @override
  String get displaySettingsPageThemeSettingsTitle => "إعدادات السمة";

  @override
  String get displaySettingsPageThemeColorTitle => "لون السمة";

  @override
  String get desktopSettingsFontsTitle => "الخطوط";

  @override
  String get linuxHideTitleBarTitle => "إخفاء شريط عنوان النظام";

  @override
  String get linuxHideTitleBarDescription => "يخفي أزرار النافذة أيضًا. استخدم مدير النوافذ لتحريك النافذة وتغيير حجمها وإغلاقها.";

  @override
  String get linuxHideTitleBarError => "تعذّر تغيير شريط العنوان. حاول مرة أخرى.";

  @override
  String get displaySettingsPageTrayTitle => "منطقة إشعارات النظام";

  @override
  String get displaySettingsPageTrayShowTrayTitle => "إظهار أيقونة منطقة الإشعارات";

  @override
  String get displaySettingsPageTrayMinimizeOnCloseTitle => "تصغير التطبيق إلى منطقة الإشعارات عند الإغلاق";

  @override
  String get desktopFontAppLabel => "خط التطبيق";

  @override
  String get desktopFontCodeLabel => "خط الأكواد";

  @override
  String get desktopFontFamilySystemDefault => "خط النظام الافتراضي";

  @override
  String get desktopFontFamilyMonospaceDefault => "خط أحادي المسافة";

  @override
  String get desktopFontFilterHint => "تصفية الخطوط…";

  @override
  String get displaySettingsPageAppFontTitle => "خط التطبيق";

  @override
  String get displaySettingsPageCodeFontTitle => "خط الأكواد";

  @override
  String get fontPickerChooseLocalFile => "اختيار ملف محلي";

  @override
  String get desktopFontLoading => "جارٍ تحميل الخطوط…";

  @override
  String get displaySettingsPageFontLocalFileLabel => "ملف محلي";

  @override
  String get displaySettingsPageFontResetLabel => "إعادة تعيين إعدادات الخط";

  @override
  String get displaySettingsPageOtherSettingsTitle => "إعدادات أخرى";

  @override
  String get themeSettingsPageDynamicColorSection => "الألوان الديناميكية";

  @override
  String get themeSettingsPageUseDynamicColorTitle => "ألوان النظام الديناميكية";

  @override
  String get themeSettingsPageUseDynamicColorSubtitle => "مطابقة لوحة ألوان النظام (Android 12 أو أحدث)";

  @override
  String get themeSettingsPageUsePureBackgroundTitle => "خلفية موحّدة";

  @override
  String get themeSettingsPageUsePureBackgroundSubtitle => "تتبع الفقاعات والعناصر المميزة ألوان السمة.";

  @override
  String get themeAdvancedSettingsPageTitle => "إعدادات السمة المتقدمة";

  @override
  String get themeAdvancedSettingsPageUseLayeredSurfacesTitle => "الأسطح متعددة الطبقات (تجريبي)";

  @override
  String get themeAdvancedSettingsPageUseLayeredSurfacesSubtitle => "صفحة داكنة وبطاقات أكثر سطوعًا، مع احتفاظ كليهما بدرجة لون السمة. أوقف الخيار لاستعادة المظهر السابق.";

  @override
  String get themeAdvancedSettingsPageUseLayeredSheetTilesTitle => "عناصر اللوحات متعددة الطبقات";

  @override
  String get themeAdvancedSettingsPageUseLayeredSheetTilesSubtitle => "تطابق العناصر خلفية اللوحة افتراضيًا.";

  @override
  String get themeSettingsPageColorPalettesSection => "لوحات الألوان";

  @override
  String get themeSettingsPageCustomPaletteName => "مخصص";

  @override
  String get themeSettingsPageCustomColorReset => "إعادة تعيين";

  @override
  String get themeSettingsPageCustomThemesSection => "سمات مخصصة";

  @override
  String get customThemeNewTheme => "سمة جديدة";

  @override
  String get customThemeEditTheme => "تعديل السمة";

  @override
  String get customThemeImportTheme => "استيراد سمة";

  @override
  String get customThemeNameLabel => "اسم السمة";

  @override
  String get customThemePrimaryColor => "اللون الأساسي";

  @override
  String get customThemeSecondaryColor => "اللون الثانوي";

  @override
  String get customThemeTertiaryColor => "اللون الثالثي";

  @override
  String get customThemeColorAuto => "تلقائي";

  @override
  String get customThemeSave => "حفظ";

  @override
  String get customThemeCancel => "إلغاء";

  @override
  String get customThemeDelete => "حذف";

  @override
  String get customThemeDeleteConfirm => "هل تريد حذف هذه السمة؟";

  @override
  String get customThemeCopied => "تم نسخ JSON الخاص بالسمة إلى الحافظة.";

  @override
  String get customThemeCopyAction => "نسخ";

  @override
  String get customThemeImportHint => "الصق JSON الخاص بالسمة هنا";

  @override
  String get customThemeImportInvalid => "JSON الخاص بالسمة غير صالح.";

  @override
  String get ttsServicesPageBackButton => "رجوع";

  @override
  String get ttsServicesPageTitle => "خدمات الصوت";

  @override
  String get ttsServicesSectionTitle => "تحويل النص إلى كلام";

  @override
  String get ttsServicesPageSettingsTooltip => "إعدادات تحويل النص إلى كلام";

  @override
  String get ttsServicesPageAddTooltip => "إضافة";

  @override
  String get asrServicesSectionTitle => "التعرّف على الكلام";

  @override
  String get asrServicesSectionDescription => "حوّل الكلام إلى نص باستخدام خدمة محلية على الجهاز أو خدمة النظام أو خدمة سحابية.";

  @override
  String get asrServicesAddTooltip => "إضافة خدمة للتعرّف على الكلام";

  @override
  String get asrServicesEmptyTitle => "لا توجد خدمة للتعرّف على الكلام";

  @override
  String get asrServicesEmptySubtitle => "أضف خدمة لإظهار زر الميكروفون في حقل المحادثة.";

  @override
  String get asrServicesOnDeviceGroup => "على الجهاز";

  @override
  String get asrServicesCloudGroup => "سحابي";

  @override
  String get asrServicesSystemTitle => "النظام";

  @override
  String get asrServicesSystemSubtitle => "يستخدم أداة التعرّف المدمجة في الجهاز.";

  @override
  String get asrServicesLocalTitle => "نموذج دون اتصال";

  @override
  String get asrServicesLocalSubtitle => "يعمل دون اتصال على هذا الجهاز بعد تنزيله.";

  @override
  String get asrServicesOpenAiSubtitle => "تحويل الكلام إلى نص بالبث مع زمن استجابة منخفض.";

  @override
  String get asrServicesGroqSubtitle => "تحويل Whisper إلى نص على دفعات.";

  @override
  String get asrServicesMistralSubtitle => "تحويل Voxtral إلى نص على دفعات.";

  @override
  String get asrServicesElevenLabsSubtitle => "تحويل Scribe إلى نص على دفعات.";

  @override
  String get asrServicesDashScopeSubtitle => "تحويل Qwen إلى نص في الوقت الفعلي.";

  @override
  String get asrServicesVolcengineSubtitle => "تحويل Doubao إلى نص بالبث المباشر.";

  @override
  String get asrServicesMimoSubtitle => "تحويل سحابي إلى نص على دفعات.";

  @override
  String get asrServicesStepSubtitle => "تحويل Step Audio إلى نص على دفعات.";

  @override
  String get asrServicesAddTitle => "إضافة خدمة للتعرّف على الكلام";

  @override
  String get asrServicesEditTitle => "تعديل خدمة التعرّف على الكلام";

  @override
  String get asrServicesSelectedLabel => "محدد";

  @override
  String get asrServicesUnavailableLabel => "غير متاح";

  @override
  String get asrServicesEditAction => "تعديل";

  @override
  String get asrServicesDeleteAction => "حذف";

  @override
  String get asrServicesCancelAction => "إلغاء";

  @override
  String get asrServicesAddAction => "إضافة";

  @override
  String get asrServicesSaveAction => "حفظ";

  @override
  String get asrServicesNameLabel => "الاسم";

  @override
  String get asrServicesApiKeyLabel => "مفتاح API";

  @override
  String get asrServicesEndpointLabel => "نقطة النهاية";

  @override
  String get asrServicesRecognitionModeLabel => "وضع التعرّف";

  @override
  String get asrServicesRealtimeMode => "في الوقت الفعلي";

  @override
  String get asrServicesRecordedMode => "صوت مسجّل";

  @override
  String get asrServicesQwenAudioSubtitle => "تحويل الصوت المباشر أو المسجّل إلى نص.";

  @override
  String get asrServicesQwenTokenPlanHint => "لاستخدام خطة Token Plan، اختر «صوت مسجّل»، وأدخل token-plan كمعرّف مساحة العمل، ثم اختر المنطقة الخاصة بمفتاحك.";

  @override
  String get asrServicesWorkspaceIdHint => "مثلًا: token-plan";

  @override
  String get asrServicesEndpointOverrideLabel => "نقطة نهاية مخصصة (اختياري)";

  @override
  String get asrServicesWorkspaceIdInvalid => "أدخل معرّف مساحة عمل، وليس رابط URL.";

  @override
  String get asrServicesWebSocketEndpointInvalid => "أدخل عنوان WebSocket كاملًا يبدأ بـ ws:// أو wss://، دون بيانات اعتماد أو جزء لاحق (#fragment).";

  @override
  String get asrServicesHttpEndpointInvalid => "أدخل عنوان HTTP كاملًا يبدأ بـ http:// أو https://، دون بيانات اعتماد أو جزء لاحق (#fragment).";

  @override
  String get asrServicesModelLabel => "النموذج";

  @override
  String get asrServicesResourceIdLabel => "معرّف المورد";

  @override
  String get asrServicesLanguageLabel => "اللغة";

  @override
  String get asrServicesAutomaticLabel => "تلقائي";

  @override
  String get asrServicesApiKeyRequired => "أدخل مفتاح API لاستخدام هذه الخدمة.";

  @override
  String get asrServicesChooseModelTitle => "النموذج";

  @override
  String get asrServicesModelDownloadAction => "تنزيل";

  @override
  String get asrServicesModelUseAction => "استخدام النموذج";

  @override
  String get asrServicesModelDeleteAction => "إزالة التنزيل";

  @override
  String get asrServicesModelDownloadedLabel => "تم التنزيل";

  @override
  String get asrServicesModelDownloadingLabel => "جارٍ التنزيل…";

  @override
  String get asrServicesModelNotDownloadedLabel => "لم يتم التنزيل";

  @override
  String asrServicesDownloadFailed(String error) => "فشل تنزيل النموذج: ${error}";

  @override
  String get asrServicesSystemChecking => "جارٍ التحقق…";

  @override
  String get asrServicesSystemAvailable => "متاح";

  @override
  String get asrServicesSystemCheckFailed => "التعرّف على الكلام عبر النظام غير متاح على هذا الجهاز.";

  @override
  String get asrServicesMicrophonePermissionDenied => "لم يتم منح إذن استخدام الميكروفون.";

  @override
  String get asrServicesNoSpeechDetected => "لم يتم اكتشاف أي كلام.";

  @override
  String asrServicesRecognitionFailed(String error) => "فشل التعرّف على الكلام: ${error}";

  @override
  String get ttsServicesPageAddNotImplemented => "إضافة خدمة تحويل النص إلى كلام غير متاحة حاليًا.";

  @override
  String get ttsServicesPageSystemTtsTitle => "تحويل النص إلى كلام عبر النظام";

  @override
  String get ttsServicesPageSystemTtsAvailableSubtitle => "استخدام خدمة تحويل النص إلى كلام المدمجة في النظام.";

  @override
  String ttsServicesPageSystemTtsUnavailableSubtitle(String error) => "غير متاح: ${error}";

  @override
  String get ttsServicesPageSystemTtsUnavailableNotInitialized => "لم تتم التهيئة";

  @override
  String get ttsServicesPageTestSpeechText => "مرحبًا، هذا اختبار للنطق الصوتي.";

  @override
  String get ttsServicesPageConfigureTooltip => "تهيئة";

  @override
  String get ttsServicesPageTestVoiceTooltip => "اختبار الصوت";

  @override
  String get ttsServicesPageStopTooltip => "إيقاف";

  @override
  String get ttsServicesPageDeleteTooltip => "حذف";

  @override
  String get ttsServicesPageSystemTtsSettingsTitle => "إعدادات تحويل النص إلى كلام في النظام";

  @override
  String get ttsServicesPageEngineLabel => "المحرّك";

  @override
  String get ttsServicesPageAutoLabel => "تلقائي";

  @override
  String get ttsServicesPageLanguageLabel => "اللغة";

  @override
  String get ttsServicesPageSpeechRateLabel => "سرعة النطق";

  @override
  String get ttsServicesPagePitchLabel => "حدة الصوت";

  @override
  String get ttsServicesPageSettingsSavedMessage => "تم حفظ الإعدادات.";

  @override
  String get ttsServicesPageDoneButton => "تم";

  @override
  String get ttsServicesPageNetworkSectionTitle => "تحويل النص إلى كلام عبر الشبكة";

  @override
  String get ttsServicesPageNoNetworkServices => "لا توجد خدمات لتحويل النص إلى كلام.";

  @override
  String get ttsServicesDialogAddTitle => "إضافة خدمة تحويل النص إلى كلام";

  @override
  String get ttsServicesDialogEditTitle => "تعديل خدمة تحويل النص إلى كلام";

  @override
  String get ttsServicesDialogProviderType => "المزوّد";

  @override
  String get ttsServicesDialogCancelButton => "إلغاء";

  @override
  String get ttsServicesDialogAddButton => "إضافة";

  @override
  String get ttsServicesDialogSaveButton => "حفظ";

  @override
  String get ttsServicesFieldNameLabel => "الاسم";

  @override
  String get ttsServicesFieldApiKeyLabel => "مفتاح API";

  @override
  String get ttsServicesFieldBaseUrlLabel => "عنوان API الأساسي";

  @override
  String get ttsServicesFieldModelLabel => "النموذج";

  @override
  String get ttsServicesFieldVoiceLabel => "الصوت";

  @override
  String get ttsServicesFieldVoiceIdLabel => "معرّف الصوت";

  @override
  String get ttsServicesFieldEmotionLabel => "العاطفة";

  @override
  String get ttsServicesFieldSpeedLabel => "السرعة";

  @override
  String get ttsServicesFieldLanguageTypeLabel => "نوع اللغة";

  @override
  String get ttsServicesFieldLanguageLabel => "اللغة";

  @override
  String get ttsServicesFieldWorkspaceIdLabel => "معرّف مساحة العمل";

  @override
  String get ttsServicesFieldRegionLabel => "المنطقة";

  @override
  String get ttsServicesFieldFormatLabel => "تنسيق الصوت";

  @override
  String get ttsServicesFieldOutputFormatLabel => "تنسيق الإخراج";

  @override
  String get ttsServicesFieldSampleRateLabel => "معدل أخذ العينات";

  @override
  String get ttsServicesFieldVolumeLabel => "مستوى الصوت";

  @override
  String get ttsServicesFieldPitchLabel => "حدة الصوت";

  @override
  String get ttsServicesFieldLanguageBoostLabel => "تعزيز اللغة";

  @override
  String get ttsServicesFieldBitrateLabel => "معدل البت";

  @override
  String get ttsServicesFieldChannelLabel => "القنوات";

  @override
  String get ttsServicesFieldSubtitlesLabel => "إنشاء ترجمة نصية";

  @override
  String get ttsServicesFieldPronunciationDictionaryLabel => "قاموس النطق (إدخال واحد في كل سطر)";

  @override
  String get ttsServicesFieldInstructionLabel => "وصف الأسلوب أو الصوت";

  @override
  String get ttsServicesFieldStreamingLabel => "البث المباشر";

  @override
  String get ttsServicesFieldOptimizeTextPreviewLabel => "تحسين معاينة النص";

  @override
  String get ttsServicesFieldReferenceAudioLabel => "صوت مرجعي (بيانات URI بصيغة WAV/MP3)";

  @override
  String get ttsServicesFieldChooseReferenceAudioButton => "اختيار صوت مرجعي";

  @override
  String get ttsServicesFieldTemperatureLabel => "درجة الحرارة";

  @override
  String get ttsServicesFieldLatencyLabel => "زمن الاستجابة";

  @override
  String get ttsServicesEmotionAutoLabel => "مطابقة تلقائية";

  @override
  String get ttsServicesValidationApiKeyRequired => "مفتاح API مطلوب";

  @override
  String get ttsServicesValidationReferenceIdRequired => "معرّف الصوت أو المرجع مطلوب";

  @override
  String get ttsServicesValidationInstructionRequired => "وصف الصوت مطلوب";

  @override
  String ttsServicesValidationSampleRate(String format, String rates) => "يتطلب ${format} معدل تردد ${rates} هرتز.";

  @override
  String get ttsServicesViewDetailsButton => "عرض التفاصيل";

  @override
  String get ttsServicesDialogErrorTitle => "تفاصيل الخطأ";

  @override
  String get ttsServicesCloseButton => "إغلاق";

  @override
  String get ttsSettingsPageTitle => "إعدادات تحويل النص إلى كلام";

  @override
  String get ttsSettingsPlaybackSection => "التشغيل";

  @override
  String get ttsSettingsAutoPlayTitle => "تشغيل ردود المساعد تلقائيًا";

  @override
  String get ttsSettingsAutoPlayDescription => "بدء تحويل النص إلى كلام تلقائيًا بعد اكتمال رد المساعد.";

  @override
  String get ttsSettingsCacheReplayTitle => "إعادة استخدام الصوت عند التشغيل مجددًا";

  @override
  String get ttsSettingsCacheReplayDescription => "إعادة تشغيل الصوت الناتج عبر الشبكة دون طلب خدمة تحويل النص إلى كلام مرة أخرى.";

  @override
  String get ttsSettingsTextSelectionSection => "تحديد النص";

  @override
  String get ttsSettingsTextSelectionFallbackDescription => "إذا لم يتم العثور على نص مطابق، فسيتم تشغيل الرد كاملًا.";

  @override
  String get ttsSettingsTextSelectionFullTextTitle => "النص كاملًا";

  @override
  String get ttsSettingsTextSelectionFullTextDescription => "تشغيل رد المساعد بالكامل.";

  @override
  String get ttsSettingsTextSelectionQuotedOnlyTitle => "النص المقتبس فقط";

  @override
  String get ttsSettingsTextSelectionQuotedOnlyDescription => "تشغيل النص الموجود داخل “”, ‘’, \"\", , 「」 أو 『』.";

  @override
  String get ttsSettingsTextSelectionOutsideParenthesesTitle => "النص خارج الأقواس";

  @override
  String get ttsSettingsTextSelectionOutsideParenthesesDescription => "تخطي النص الموجود داخل () و（）。";

  @override
  String get ttsSettingsTextSelectionItalicOnlyTitle => "النص المائل فقط";

  @override
  String get ttsSettingsTextSelectionItalicOnlyDescription => "تشغيل النص المائل بتنسيق Markdown أو HTML.";

  @override
  String get ttsSettingsTextSelectionNonItalicTitle => "النص غير المائل فقط";

  @override
  String get ttsSettingsTextSelectionNonItalicDescription => "تخطي النص المائل بتنسيق Markdown أو HTML.";

  @override
  String get ttsFloatingPlayerLabel => "مشغّل تحويل النص إلى كلام";

  @override
  String get ttsFloatingPauseTooltip => "إيقاف مؤقت";

  @override
  String get ttsFloatingResumeTooltip => "استئناف";

  @override
  String get ttsFloatingReplayTooltip => "إعادة التشغيل";

  @override
  String get ttsFloatingRewind15Tooltip => "الرجوع 15 ثانية";

  @override
  String get ttsFloatingForward15Tooltip => "التقديم 15 ثانية";

  @override
  String get ttsFloatingSpeedTooltip => "سرعة التشغيل";

  @override
  String get ttsFloatingCloseTooltip => "إغلاق المشغّل";

  @override
  String get ttsFloatingExpandTooltip => "توسيع عناصر التحكم بالتشغيل";

  @override
  String get ttsFloatingCollapseTooltip => "طيّ عناصر التحكم بالتشغيل";

  @override
  String get ttsFloatingSaveTooltip => "حفظ الصوت";

  @override
  String get ttsSaveDialogTitle => "حفظ صوت تحويل النص إلى كلام";

  @override
  String get ttsSaveSuccess => "تم حفظ الصوت بنجاح.";

  @override
  String get ttsSaveNothing => "لا يوجد صوت متاح للحفظ.";

  @override
  String ttsSaveFailed(String message) => "فشل حفظ الصوت: ${message}";

  @override
  String imageViewerPageShareFailedOpenFile(String message) => "تعذّرت المشاركة، وتمت محاولة فتح الملف: ${message}";

  @override
  String imageViewerPageShareFailed(String error) => "فشلت المشاركة: ${error}";

  @override
  String get imageViewerPageShareButton => "مشاركة الصورة";

  @override
  String get imageViewerPageCloseButton => "إغلاق المعاينة";

  @override
  String get imageViewerPageSaveButton => "حفظ الصورة";

  @override
  String get imageViewerPageCopyButton => "نسخ الصورة";

  @override
  String get imageViewerPagePreviousButton => "الصورة السابقة";

  @override
  String get imageViewerPageNextButton => "الصورة التالية";

  @override
  String get imageViewerPageZoomInButton => "تكبير";

  @override
  String get imageViewerPageZoomOutButton => "تصغير";

  @override
  String get imageViewerPageResetZoomButton => "إعادة ضبط التكبير";

  @override
  String get imageViewerPageFlipHorizontalButton => "قلب أفقي";

  @override
  String get imageViewerPageFlipVerticalButton => "قلب عمودي";

  @override
  String get imageViewerPageRotateLeftButton => "تدوير إلى اليسار";

  @override
  String get imageViewerPageRotateRightButton => "تدوير إلى اليمين";

  @override
  String imageViewerPageCounter(int index, int total) => "${index} / ${total}";

  @override
  String imageViewerPageImageLabel(int index, int total) => "الصورة ${index} من ${total}";

  @override
  String get imageViewerPageImageLoadFailed => "تعذّر تحميل الصورة";

  @override
  String get imageViewerPageSaveSuccess => "تم الحفظ في المعرض";

  @override
  String imageViewerPageSaveFailed(String error) => "فشل الحفظ: ${error}";

  @override
  String get settingsShare => "Kelivo - مساعد ذكاء اصطناعي مفتوح المصدر";

  @override
  String get searchProviderBingLocalDescription => "يستخدم استخراج بيانات الويب لجلب نتائج Bing. لا يتطلب مفتاح API، وقد يكون غير مستقر.";

  @override
  String get searchProviderDuckDuckGoDescription => "بحث DuckDuckGo يركّز على الخصوصية عبر DDGS. لا يتطلب مفتاح API ويدعم اختيار المنطقة.";

  @override
  String get searchProviderBraveDescription => "محرك بحث مستقل من Brave، يركّز على الخصوصية دون تتبّع أو إنشاء ملفات تعريف للمستخدمين.";

  @override
  String get searchProviderExaDescription => "بحث عصبي بفهم دلالي. مناسب للأبحاث والعثور على محتوى محدد.";

  @override
  String get searchProviderExaMcpDescription => "بحث Exa عبر MCP. مفتاح API اختياري للاستخدام المجاني المحدود.";

  @override
  String get searchProviderLinkUpDescription => "واجهة بحث API تقدم إجابات مدعومة بالمصادر، وتوفر النتائج والملخصات التي ينشئها الذكاء الاصطناعي.";

  @override
  String get searchProviderMetasoDescription => "محرك بحث صيني من Metaso، محسّن للمحتوى الصيني ويستخدم إمكانات الذكاء الاصطناعي.";

  @override
  String get searchProviderSearXNGDescription => "محرك بحث تجميعي يحترم الخصوصية. يتطلب مثيلًا مستضافًا ذاتيًا ولا يستخدم التتبع.";

  @override
  String get searchProviderTavilyDescription => "واجهة بحث API للذكاء الاصطناعي محسّنة لنماذج اللغة الكبيرة، وتوفر نتائج عالية الجودة وذات صلة.";

  @override
  String get searchProviderZhipuDescription => "بحث ذكاء اصطناعي صيني من Zhipu AI، محسّن للمحتوى والاستعلامات الصينية.";

  @override
  String get searchProviderOllamaDescription => "واجهة بحث الويب الخاصة بـ Ollama لإثراء النماذج بمعلومات محدّثة.";

  @override
  String get searchProviderDeepSeekDescription => "واجهات البحث الرسمية وجلب الصفحات من DeepSeek، وتستخدم مفتاح DeepSeek API.";

  @override
  String get searchProviderJinaDescription => "منصة بحث للذكاء الاصطناعي توفر التضمينات وإعادة الترتيب وقارئ الويب والبحث المتعمق ونماذج اللغة الصغيرة. تدعم تعدد اللغات والوسائط.";

  @override
  String get searchServiceNameBingLocal => "Bing (محلي)";

  @override
  String get searchProviderPerplexityDescription => "واجهة Perplexity Search API. توفر نتائج ويب مرتبة مع عوامل تصفية للمنطقة والنطاق.";

  @override
  String get searchProviderBochaDescription => "واجهة Bocha للبحث عبر الويب. تقدم نتائج دقيقة مع ملخصات اختيارية.";

  @override
  String get searchProviderDoubaoDescription => "واجهة Doubao للبحث عبر الويب من Volcano Engine.";

  @override
  String get searchProviderSerperDescription => "واجهة Serper لبحث Google. تقدم نتائج سريعة مع خيارات لتصفية الدولة واللغة والوقت ورقم الصفحة.";

  @override
  String get searchProviderQueritDescription => "واجهة Querit للبحث في تطبيقات النماذج اللغوية. تعيد نتائج ويب مباشرة وتدعم التصفية حسب الموقع والوقت والدولة.";

  @override
  String get searchProviderGrokDescription => "بحث Grok عبر واجهة xAI Responses API. يستخدم أدوات بحث الويب وX ويعيد مصادر موثّقة.";

  @override
  String get searchProviderStepFunDescription => "بحث StepFun عبر POST /v1/search.";

  @override
  String get searchProviderFirecrawlDescription => "واجهة Firecrawl Search API v2. مفتاح API اختياري، ولا يدعم هذا الموضع ميزة Scrape.";

  @override
  String get searchProviderTinyFishDescription => "واجهة TinyFish للبحث مع عوامل تصفية للمنطقة واللغة. تتطلب مفتاح API، ولا تدعم هنا ميزتي Fetch وScrape.";

  @override
  String get searchProviderAnySearchDescription => "بحث موحد لوكلاء الذكاء الاصطناعي مع توجيه تلقائي عبر مصادر الويب ومصادر البيانات المتخصصة. مفتاح API اختياري.";

  @override
  String get searchProviderKagiDescription => "واجهة Kagi Search API، وتوفر نتائج بحث ويب مميزة من Kagi.";

  @override
  String get searchProviderKimiDescription => "واجهة Kimi Search API. يعرض وضع Pro مقتطفات محتوى ويب ذات صلة، بينما يعرض Basic العناوين والروابط والمقتطفات.";

  @override
  String get searchProviderParallelDescription => "واجهة Parallel Search API. توفر مقتطفات ويب محسّنة لنماذج اللغة الكبيرة مع أوضاع turbo وfast وbasic وadvanced.";

  @override
  String get searchServicesDialogSearchMode => "وضع البحث";

  @override
  String get searchProviderYouDescription => "واجهة You.com Search API. تقدم نتائج الويب والأخبار مع أبرز النقاط أو المقتطفات.";

  @override
  String get searchServicesDialogContentMode => "وضع المحتوى";

  @override
  String get searchServicesDialogHighlights => "أبرز النقاط";

  @override
  String get searchServicesDialogSnippets => "المقتطفات";

  @override
  String get searchServicesDialogWebSearch => "بحث الويب";

  @override
  String get searchServicesDialogLlmContext => "سياق النموذج اللغوي";

  @override
  String get searchServicesDialogMaximumTokens => "الحد الأقصى للرموز";

  @override
  String get searchServicesDialogMaximumTokensInvalid => "يجب أن يكون الحد الأقصى للرموز بين 1024 و32768.";

  @override
  String get searchServicesDialogCountryOptional => "الدولة/المنطقة (اختياري)";

  @override
  String get searchServicesDialogLanguageOptional => "اللغة (اختيارية)";

  @override
  String get searchServicesDialogTimeFilterOptional => "مرشح الوقت (اختياري)";

  @override
  String get searchServicesDialogPageOptional => "الصفحة (اختياري)";

  @override
  String get searchServicesDialogPageInvalid => "يجب أن يكون رقم الصفحة عددًا صحيحًا موجبًا.";

  @override
  String get searchServicesDialogSitesIncludeOptional => "المواقع المطلوب تضمينها (اختياري)";

  @override
  String get searchServicesDialogSitesExcludeOptional => "المواقع المطلوب استبعادها (اختياري)";

  @override
  String get searchServicesDialogTimeRangeOptional => "النطاق الزمني (اختياري)";

  @override
  String get searchServicesDialogCountriesOptional => "الدول (اختيارية)";

  @override
  String get searchServicesDialogLanguagesOptional => "اللغات (اختيارية)";

  @override
  String get searchServicesDialogSitesHint => "example.com، docs.example.com";

  @override
  String get searchServicesDialogCountriesHint => "united states، japan";

  @override
  String get searchServicesDialogLanguagesHint => "english، japanese";

  @override
  String get generationInterrupted => "تمت مقاطعة التوليد";

  @override
  String get titleForLocale => "محادثة جديدة";

  @override
  String get temporaryChatTitle => "محادثة مؤقتة";

  @override
  String get temporaryChatEmptyMessage => "لا تظهر المحادثات المؤقتة في السجل، وسيتم حذفها بالكامل بعد مغادرتك.";

  @override
  String get temporaryChatToggleTooltip => "تبديل وضع المحادثة المؤقتة";

  @override
  String get quickPhraseBackTooltip => "رجوع";

  @override
  String get quickPhraseGlobalTitle => "العبارات السريعة";

  @override
  String get quickPhraseAssistantTitle => "العبارات السريعة للمساعد";

  @override
  String get quickPhraseAddTooltip => "إضافة عبارة سريعة";

  @override
  String get quickPhraseEmptyMessage => "لا توجد عبارات سريعة بعد.";

  @override
  String get quickPhraseAddTitle => "إضافة عبارة سريعة";

  @override
  String get quickPhraseEditTitle => "تعديل عبارة سريعة";

  @override
  String get quickPhraseTitleLabel => "العنوان";

  @override
  String get quickPhraseContentLabel => "المحتوى";

  @override
  String get quickPhraseCancelButton => "إلغاء";

  @override
  String get quickPhraseSaveButton => "حفظ";

  @override
  String get instructionInjectionTitle => "حقن التعليمات";

  @override
  String get instructionInjectionBackTooltip => "رجوع";

  @override
  String get instructionInjectionAddTooltip => "إضافة تعليمات";

  @override
  String get instructionInjectionImportTooltip => "استيراد من الملفات";

  @override
  String get instructionInjectionEmptyMessage => "لا توجد بطاقات لحقن التعليمات بعد.";

  @override
  String get instructionInjectionDefaultTitle => "وضع التعلّم";

  @override
  String get instructionInjectionAddTitle => "إضافة تعليمات";

  @override
  String get instructionInjectionEditTitle => "تعديل التعليمات";

  @override
  String get instructionInjectionNameLabel => "الاسم";

  @override
  String get instructionInjectionPromptLabel => "التعليمات";

  @override
  String get instructionInjectionUngroupedGroup => "غير مصنّف";

  @override
  String get instructionInjectionGroupLabel => "المجموعة";

  @override
  String get instructionInjectionGroupHint => "اختياري";

  @override
  String instructionInjectionImportSuccess(int count) => "تم استيراد ${count} من التعليمات.";

  @override
  String get instructionInjectionSheetSubtitle => "اختر تعليمات لتطبيقها قبل بدء المحادثة.";

  @override
  String get mcpJsonEditButtonTooltip => "تعديل JSON";

  @override
  String get mcpJsonEditTitle => "تعديل JSON";

  @override
  String get mcpJsonEditParseFailed => "فشل تحليل JSON.";

  @override
  String get mcpJsonEditSavedApplied => "تم الحفظ والتطبيق";

  @override
  String get mcpTimeoutSettingsTooltip => "تحديد مهلة استدعاء الأداة";

  @override
  String get mcpTimeoutDialogTitle => "مهلة استدعاء الأداة";

  @override
  String get mcpTimeoutSecondsLabel => "مهلة استدعاء الأداة (بالثواني)";

  @override
  String get mcpTimeoutInvalid => "أدخل عددًا موجبًا من الثواني.";

  @override
  String get quickPhraseEditButton => "تعديل";

  @override
  String get quickPhraseDeleteButton => "حذف";

  @override
  String get quickPhraseMenuTitle => "عبارة سريعة";

  @override
  String get chatInputBarQuickPhraseTooltip => "عبارة سريعة";

  @override
  String get assistantEditQuickPhraseDescription => "إدارة العبارات السريعة لهذا المساعد. اضغط على الزر أدناه لإضافة عبارات.";

  @override
  String get assistantEditManageQuickPhraseButton => "إدارة العبارات السريعة";

  @override
  String get assistantEditPageMemoryTab => "الذاكرة";

  @override
  String get assistantEditLocalToolTimeInfoTitle => "معلومات الوقت";

  @override
  String get assistantEditLocalToolTimeInfoSubtitle => "قراءة تاريخ الجهاز واليوم والوقت والمنطقة الزمنية وفارق UTC والطابع الزمني.";

  @override
  String get assistantEditLocalToolClipboardTitle => "الحافظة";

  @override
  String get assistantEditLocalToolClipboardSubtitle => "قراءة النص العادي من حافظة الجهاز أو الكتابة إليها عند الحاجة الصريحة.";

  @override
  String get assistantEditLocalToolTextToSpeechTitle => "تحويل النص إلى كلام";

  @override
  String get assistantEditLocalToolTextToSpeechSubtitle => "السماح للمساعد بقراءة النص بصوت مسموع باستخدام إعدادات تشغيل TTS.";

  @override
  String get assistantEditLocalToolAskUserTitle => "سؤال المستخدم";

  @override
  String get assistantEditLocalToolAskUserSubtitle => "السماح للمساعد بطرح أسئلة قصيرة ومتابعة العمل بعد إجابتك.";

  @override
  String get assistantEditLocalToolCalculateTitle => "الحاسبة";

  @override
  String get assistantEditLocalToolCalculateSubtitle => "حساب التعبيرات الرياضية، مع دعم + و- و* و/ والأسس والجذر التربيعي والجيب وجيب التمام وغيرها.";

  @override
  String get assistantEditLocalToolScreenTimeTitle => "وقت استخدام الشاشة";

  @override
  String get assistantEditLocalToolScreenTimeSubtitle => "الاستعلام عن وقت استخدام التطبيقات على هذا الجهاز. يتطلب إذن الوصول إلى بيانات الاستخدام.";

  @override
  String get chatMessageWidgetScreenTimeTotal => "إجمالي وقت استخدام الشاشة";

  @override
  String get chatMessageWidgetScreenTimePermissionRequired => "لم يتم منح إذن الوصول إلى بيانات الاستخدام. فعّله من إعدادات النظام ثم حاول مجددًا.";

  @override
  String get assistantEditLocalToolCalendarQueryTitle => "الاستعلام عن التقويم";

  @override
  String get assistantEditLocalToolCalendarQuerySubtitle => "قراءة أحداث التقويم على هذا الجهاز. يتطلب إذن التقويم.";

  @override
  String get assistantEditLocalToolCalendarCreateTitle => "إنشاء حدث";

  @override
  String get assistantEditLocalToolCalendarCreateSubtitle => "إنشاء أحداث في تقويم هذا الجهاز بعد تأكيدك. يتطلب إذن التقويم.";

  @override
  String get assistantEditLocalToolLocationTitle => "الموقع الحالي";

  @override
  String get assistantEditLocalToolLocationSubtitle => "قراءة الموقع مرة واحدة من هذا الجهاز. يتطلب إذن الموقع.";

  @override
  String get assistantEditLocalToolWeatherTitle => "الطقس";

  @override
  String get assistantEditLocalToolWeatherSubtitle => "الحصول على بيانات Apple Weather للموقع الحالي أو موقع تحدده. يظهر إسناد WeatherKit في النتيجة.";

  @override
  String get assistantEditLocalToolHealthTitle => "ملخص الصحة";

  @override
  String get assistantEditLocalToolHealthSubtitle => "قراءة ملخص نشاط يحافظ على الخصوصية من Apple Health. يتطلب الوصول إلى بيانات الصحة.";

  @override
  String assistantEditLocalToolHealthSelectedCount(int selected, int total) => "تم تحديد ${selected} من ${total}";

  @override
  String get healthDataSettingsTitle => "البيانات الصحية";

  @override
  String get healthDataSettingsDescription => "بيانات HealthKit المتاحة للمساعد الحالي أثناء المحادثات اليومية. تتحكم المفاتيح في البيانات التي يمكن لـ Kelivo محاولة قراءتها؛ بينما يدير iOS أذونات الوصول الفعلية.";

  @override
  String healthDataSettingsBadge(int selected, int total) => "مفعّل: ${selected} من ${total}";

  @override
  String get healthDataSettingsIosReadTitle => "قراءة بيانات الصحة في iOS";

  @override
  String get healthDataSettingsIosReadSubtitle => "الجهاز متاح؛ يدير iOS نطاق القراءة.";

  @override
  String get healthDataSettingsOpenSystemSettings => "فتح إعدادات النظام";

  @override
  String get healthDataSettingsEnableAll => "تفعيل الكل";

  @override
  String get healthDataSettingsDisableAll => "تعطيل الكل";

  @override
  String get healthDataSettingsCategoryActivity => "النشاط";

  @override
  String get healthDataSettingsCategoryRest => "الراحة";

  @override
  String get healthDataSettingsCategoryHeart => "القلب";

  @override
  String get healthDataSettingsCategoryBody => "الجسم";

  @override
  String get healthDataSettingsTypeStepsTitle => "الخطوات";

  @override
  String get healthDataSettingsTypeStepsSubtitle => "ملخص خطوات المشي";

  @override
  String get healthDataSettingsTypeDaylightTitle => "ضوء الشمس";

  @override
  String get healthDataSettingsTypeDaylightSubtitle => "مدة التعرض لضوء النهار في الخارج";

  @override
  String get healthDataSettingsTypeActiveEnergyTitle => "الطاقة النشطة";

  @override
  String get healthDataSettingsTypeActiveEnergySubtitle => "السعرات الحرارية المحروقة أثناء النشاط";

  @override
  String get healthDataSettingsTypeExerciseMinutesTitle => "التمرين";

  @override
  String get healthDataSettingsTypeExerciseMinutesSubtitle => "دقائق التمرين المسجلة في Apple";

  @override
  String get healthDataSettingsTypeStandTimeTitle => "الوقوف";

  @override
  String get healthDataSettingsTypeStandTimeSubtitle => "مدة الوقوف";

  @override
  String get healthDataSettingsTypeDistanceTitle => "المسافة";

  @override
  String get healthDataSettingsTypeDistanceSubtitle => "مسافة المشي والجري";

  @override
  String get healthDataSettingsTypeWorkoutsTitle => "التمارين الرياضية";

  @override
  String get healthDataSettingsTypeWorkoutsSubtitle => "سجلات التمارين: النوع والمدة والمسافة والطاقة";

  @override
  String get healthDataSettingsTypeSleepTitle => "النوم";

  @override
  String get healthDataSettingsTypeSleepSubtitle => "آخر 24 ساعة: النوم والوقت في السرير وفترات الاستيقاظ ومراحل النوم";

  @override
  String get healthDataSettingsTypeMindfulnessTitle => "الاسترخاء";

  @override
  String get healthDataSettingsTypeMindfulnessSubtitle => "فترات اليقظة الذهنية أو الاستراحة";

  @override
  String get healthDataSettingsTypeHeartRateTitle => "معدل ضربات القلب";

  @override
  String get healthDataSettingsTypeHeartRateSubtitle => "أحدث قراءة لمعدل ضربات القلب";

  @override
  String get healthDataSettingsTypeRestingHeartRateTitle => "معدل ضربات القلب أثناء الراحة";

  @override
  String get healthDataSettingsTypeRestingHeartRateSubtitle => "قراءة معدل ضربات القلب أثناء الراحة";

  @override
  String get healthDataSettingsTypeBloodOxygenTitle => "الأكسجين في الدم";

  @override
  String get healthDataSettingsTypeBloodOxygenSubtitle => "نسبة تشبع الدم بالأكسجين";

  @override
  String get healthDataSettingsTypeDietaryEnergyTitle => "الطاقة الغذائية";

  @override
  String get healthDataSettingsTypeDietaryEnergySubtitle => "سجل السعرات الحرارية المتناولة";

  @override
  String get healthDataSettingsTypeWaterTitle => "الماء";

  @override
  String get healthDataSettingsTypeWaterSubtitle => "سجل كمية الماء المتناولة";

  @override
  String get healthDataSettingsTypeWeightTitle => "الوزن";

  @override
  String get healthDataSettingsTypeWeightSubtitle => "قراءة وزن الجسم";

  @override
  String get healthDataSettingsTypeBmiTitle => "مؤشر كتلة الجسم";

  @override
  String get healthDataSettingsTypeBmiSubtitle => "مؤشر كتلة الجسم (BMI)";

  @override
  String get healthDataSettingsTypeBloodGlucoseTitle => "سكر الدم";

  @override
  String get healthDataSettingsTypeBloodGlucoseSubtitle => "قراءة مستوى سكر الدم";

  @override
  String get assistantEditLocalToolRemindersQueryTitle => "الاستعلام عن التذكيرات";

  @override
  String get assistantEditLocalToolRemindersQuerySubtitle => "قراءة التذكيرات على هذا الجهاز. يتطلب إذن الوصول الكامل إلى التذكيرات.";

  @override
  String get assistantEditLocalToolRemindersCreateTitle => "إنشاء تذكير";

  @override
  String get assistantEditLocalToolRemindersCreateSubtitle => "إنشاء تذكير على هذا الجهاز بعد تأكيدك. يتطلب إذن الوصول الكامل إلى التذكيرات.";

  @override
  String get assistantEditLocalToolRemindersCompleteTitle => "إكمال تذكير";

  @override
  String get assistantEditLocalToolRemindersCompleteSubtitle => "وضع علامة «مكتمل» على تذكير بعد تأكيدك. يتطلب إذن الوصول الكامل إلى التذكيرات.";

  @override
  String get assistantEditMemorySwitchDescription => "السماح للمساعد بإنشاء الذكريات واستخدامها عبر المحادثات.";

  @override
  String get assistantEditRecentChatsSwitchTitle => "الرجوع إلى المحادثات الأخيرة";

  @override
  String get assistantEditRecentChatsSwitchDescription => "تضمين عناوين المحادثات الأخيرة للمساعدة في توفير السياق.";

  @override
  String get assistantEditAddMemoryButton => "إضافة ذاكرة";

  @override
  String get assistantEditMemoryEmpty => "لا توجد ذكريات بعد";

  @override
  String get assistantEditMemoryDialogTitle => "الذاكرة";

  @override
  String get assistantEditMemoryDialogHint => "أدخل محتوى الذاكرة";

  @override
  String get assistantEditAddQuickPhraseButton => "إضافة عبارة سريعة";

  @override
  String get multiKeyPageDeleteSnackbarDeletedOne => "تم حذف مفتاح واحد";

  @override
  String get multiKeyPageUndo => "تراجع";

  @override
  String get multiKeyPageUndoRestored => "تمت الاستعادة";

  @override
  String get multiKeyPageDeleteErrorsTooltip => "حذف المفاتيح التي بها أخطاء";

  @override
  String get multiKeyPageDeleteErrorsConfirmTitle => "حذف جميع المفاتيح التي بها أخطاء؟";

  @override
  String get multiKeyPageDeleteErrorsConfirmContent => "سيؤدي هذا إلى إزالة جميع المفاتيح المحددة على أنها معطوبة.";

  @override
  String multiKeyPageDeletedErrorsSnackbar(int n) => "تم حذف ${n} من المفاتيح التي بها أخطاء";

  @override
  String get providerDetailPageProviderTypeTitle => "نوع مزوّد الخدمة";

  @override
  String get displaySettingsPageChatItemDisplayTitle => "عرض عناصر المحادثة";

  @override
  String get displaySettingsPageRenderingSettingsTitle => "إعدادات العرض";

  @override
  String get displaySettingsPageBehaviorStartupTitle => "السلوك وبدء التشغيل";

  @override
  String get displaySettingsPageHapticsSettingsTitle => "إعدادات الاستجابة اللمسية";

  @override
  String get assistantSettingsNoPromptPlaceholder => "لا توجد تعليمات بعد";

  @override
  String get providersPageMultiSelectTooltip => "تحديد متعدد";

  @override
  String get providersPageDeleteSelectedConfirmContent => "هل تريد حذف مزوّدي الخدمة المحددين؟ لا يمكن التراجع عن هذا الإجراء.";

  @override
  String get providersPageDeleteSelectedSnackbar => "تم حذف مزوّدي الخدمة المحددين";

  @override
  String providersPageExportSelectedTitle(int count) => "تصدير ${count} من مزوّدي الخدمة";

  @override
  String get providersPageExportCopyButton => "نسخ";

  @override
  String get providersPageExportShareButton => "مشاركة";

  @override
  String get providersPageExportCopiedSnackbar => "تم نسخ رمز التصدير";

  @override
  String get providersPageDeleteAction => "حذف";

  @override
  String get providersPageExportAction => "تصدير";

  @override
  String get assistantEditPresetTitle => "محادثة معدّة مسبقًا";

  @override
  String get assistantEditPresetAddUser => "إضافة رسالة مستخدم معدّة مسبقًا";

  @override
  String get assistantEditPresetAddAssistant => "إضافة رسالة مساعد معدّة مسبقًا";

  @override
  String get assistantEditPresetInputHintUser => "أدخل رسالة المستخدم…";

  @override
  String get assistantEditPresetInputHintAssistant => "أدخل رسالة المساعد…";

  @override
  String get assistantEditPresetEmpty => "لا توجد رسائل معدّة مسبقًا بعد";

  @override
  String get assistantEditPresetEditDialogTitle => "تعديل الرسالة المعدّة مسبقًا";

  @override
  String get assistantEditPresetRoleUser => "المستخدم";

  @override
  String get assistantEditPresetRoleAssistant => "المساعد";

  @override
  String get desktopTtsPleaseAddProvider => "أضف مزوّد تحويل النص إلى كلام أولًا";

  @override
  String get settingsPageNetworkProxy => "وكيل الشبكة";

  @override
  String get networkProxyEnableLabel => "تفعيل الوكيل";

  @override
  String get networkProxySettingsHeader => "إعدادات الوكيل";

  @override
  String get networkProxyType => "نوع الوكيل";

  @override
  String get networkProxyServerHost => "الخادم";

  @override
  String get networkProxyPort => "المنفذ";

  @override
  String get networkProxyUsername => "اسم المستخدم";

  @override
  String get networkProxyPassword => "كلمة المرور";

  @override
  String get networkProxyBypassLabel => "تجاوز الوكيل";

  @override
  String get networkProxyBypassHint => "مضيفون أو شبكات CIDR مفصولة بفواصل، مثال: localhost,127.0.0.1,192.168.0.0/16,*.local";

  @override
  String get networkProxyOptionalHint => "اختياري";

  @override
  String get networkProxyTestHeader => "اختبار الاتصال";

  @override
  String get networkProxyTestUrlHint => "عنوان URL للاختبار";

  @override
  String get networkProxyTestButton => "اختبار";

  @override
  String get networkProxyTesting => "جارٍ الاختبار…";

  @override
  String get networkProxyTestSuccess => "تم الاتصال بنجاح";

  @override
  String networkProxyTestFailed(String error) => "فشل الاختبار: ${error}";

  @override
  String get networkProxyNoUrl => "أدخل عنوان URL";

  @override
  String get networkProxyPriorityNote => "عند تفعيل الوكيل العام ووكيل مزوّد الخدمة معًا، تكون الأولوية لوكيل مزوّد الخدمة.";

  @override
  String get settingsPageAutoRetry => "إعادة المحاولة تلقائيًا";

  @override
  String get autoRetryEnableLabel => "تفعيل إعادة المحاولة تلقائيًا";

  @override
  String get autoRetryMaxRetries => "الحد الأقصى للمحاولات";

  @override
  String get autoRetryInitialDelay => "التأخير الأولي (مللي ثانية)";

  @override
  String get autoRetryMultiplier => "مضاعف التراجع";

  @override
  String get autoRetryMaxDelay => "الحد الأقصى للتأخير (مللي ثانية)";

  @override
  String get autoRetryJitter => "التفاوت العشوائي";

  @override
  String get autoRetryJitterSubtitle => "تغيير مدة الانتظار عشوائيًا بنسبة ±20%";

  @override
  String get autoRetryOnNetworkError => "إعادة المحاولة عند أخطاء الشبكة";

  @override
  String get autoRetryStatusCodes => "رموز حالات HTTP لإعادة المحاولة";

  @override
  String get autoRetryKeywords => "الكلمات المفتاحية لإعادة المحاولة";

  @override
  String get autoRetryStopKeywords => "الكلمات المفتاحية لإيقاف المحاولة";

  @override
  String get autoRetryAddHint => "إضافة";

  @override
  String get autoRetryRestoreDefaults => "استعادة الإعدادات الافتراضية";

  @override
  String get autoRetryFooter => "لا تعمل إعادة المحاولة التلقائية إلا إذا لم يُنتج رد النموذج الحالي أي مخرجات بعد.";

  @override
  String autoRetryCountdown(int seconds, int attempt, int maxRetries) => "إعادة المحاولة خلال ${seconds} ثانية (${attempt}/${maxRetries})";

  @override
  String get desktopShowProviderInModelCapsule => "إظهار مزوّد الخدمة في شارة النموذج";

  @override
  String get messageWebViewOpenInBrowser => "فتح في المتصفح";

  @override
  String get messageWebViewConsoleLogs => "سجلات وحدة التحكم";

  @override
  String get messageWebViewNoConsoleMessages => "لا توجد رسائل في وحدة التحكم";

  @override
  String get messageWebViewRefreshTooltip => "تحديث";

  @override
  String get messageWebViewForwardTooltip => "تقدم";

  @override
  String get chatInputBarOcrTooltip => "استخراج النص من الصورة (OCR)";

  @override
  String get providerDetailPageMultiSelectButton => "تحديد متعدد";

  @override
  String get providerDetailPageBatchDetectButton => "اكتشاف";

  @override
  String get providerDetailPageBatchDetecting => "جارٍ الاكتشاف…";

  @override
  String get providerDetailPageBatchDetectStart => "بدء الاكتشاف";

  @override
  String get providerDetailPageDetectSuccess => "نجح الاكتشاف";

  @override
  String get providerDetailPageDetectFailed => "فشل الاكتشاف";

  @override
  String get providerDetailPageDeleteSelectedModelsButton => "حذف";

  @override
  String get providerDetailPageDeleteSelectedModelsTooltip => "حذف النماذج المحددة";

  @override
  String providerDetailPageDeleteSelectedModelsConfirm(int count) => "هل تريد حذف ${count} من النماذج المحددة؟ لا يمكن التراجع عن هذا الإجراء.";

  @override
  String get providerDetailPageDeleteFailedDetectedModelsButton => "حذف غير المتاح";

  @override
  String get providerDetailPageDeleteFailedDetectedModelsTooltip => "حذف النماذج التي فشل اكتشافها";

  @override
  String providerDetailPageDeleteFailedDetectedModelsConfirm(int count) => "هل تريد حذف ${count} من النماذج التي فشل اكتشافها؟ لا يمكن التراجع عن هذا الإجراء.";

  @override
  String providerDetailPageSelectedModelsDeletedSnackbar(int count) => "تم حذف ${count} من النماذج";

  @override
  String get providerDetailPageDeleteAllModelsTooltip => "حذف جميع النماذج";

  @override
  String get providerDetailPageDeleteAllModelsWarning => "لا يمكن التراجع عن هذا الإجراء.";

  @override
  String get requestLogSettingTitle => "تسجيل الطلبات";

  @override
  String get requestLogSettingSubtitle => "عند التفعيل، تُكتب تفاصيل الطلبات والاستجابات في logs/logs.txt (مع تدوير السجل يوميًا).";

  @override
  String get flutterLogSettingTitle => "تسجيل Flutter";

  @override
  String get flutterLogSettingSubtitle => "عند التفعيل، تُكتب أخطاء Flutter ومخرجات print في logs/flutter_logs.txt (مع تدوير السجل يوميًا).";

  @override
  String get contextLogSettingTitle => "تسجيل السياق";

  @override
  String get contextLogSettingSubtitle => "عند التفعيل، تُكتب الرسائل الدقيقة المرسلة إلى النموذج في logs/context_logs.txt (مع تدوير السجل يوميًا).";

  @override
  String get contextLogViewerTitle => "السياق";

  @override
  String contextLogSnapshotMessages(int count) => "${count} من الرسائل";

  @override
  String contextLogSnapshotTokens(int count) => "${count} من الرموز";

  @override
  String get contextLogSourceSystemPrompt => "تعليمات النظام";

  @override
  String get contextLogSourceMemoryRules => "قواعد الذاكرة";

  @override
  String get contextLogSourceSearchPrompt => "تعليمات البحث";

  @override
  String get contextLogSourceInstructionInjection => "إدراج التعليمات";

  @override
  String get contextLogSourceWorldBook => "دفتر العالم";

  @override
  String get contextLogSourceMemorySnapshot => "لقطة الذاكرة";

  @override
  String get contextLogSourceChatHistory => "سجل المحادثة";

  @override
  String get contextLogSourceToolCall => "استدعاء الأداة";

  @override
  String get contextLogSourceToolResult => "نتيجة الأداة";

  @override
  String get contextLogTokensEstimateHint => "أعداد الرموز تقديرية فقط؛ اعتمد على الاستخدام الفعلي الذي يبلّغ عنه النموذج.";

  @override
  String contextLogSnapshotsCount(int count) => "${count} من اللقطات";

  @override
  String get contextLogSnapshotFallbackTitle => "لقطة";

  @override
  String get contextLogKindFull => "لقطة كاملة";

  @override
  String get contextLogKindUpdate => "تحديث تدريجي";

  @override
  String get contextLogSectionComposition => "التركيب";

  @override
  String get contextLogLoadOlder => "تحميل السجلات الأقدم";

  @override
  String get contextLogLoading => "جارٍ التحميل…";

  @override
  String get contextLogAllLoaded => "تم تحميل جميع السجلات";

  @override
  String get logViewerTitle => "سجلات الطلبات";

  @override
  String get logViewerEmpty => "لا توجد سجلات بعد";

  @override
  String get logViewerCurrentLog => "السجل الحالي";

  @override
  String get logViewerExport => "تصدير";

  @override
  String get logViewerOpenFolder => "فتح مجلد السجلات";

  @override
  String logViewerRequestsCount(int count) => "${count} من الطلبات";

  @override
  String get logViewerFieldId => "المعرّف";

  @override
  String get logViewerFieldMethod => "الطريقة";

  @override
  String get logViewerFieldStatus => "الحالة";

  @override
  String get logViewerFieldStarted => "وقت البدء";

  @override
  String get logViewerFieldEnded => "وقت الانتهاء";

  @override
  String get logViewerFieldDuration => "المدة";

  @override
  String get logViewerSectionSummary => "الملخص";

  @override
  String get logViewerSectionParameters => "المعلمات";

  @override
  String get logViewerSectionRequestHeaders => "ترويسات الطلب";

  @override
  String get logViewerSectionRequestBody => "متن الطلب";

  @override
  String get logViewerSectionResponseHeaders => "ترويسات الاستجابة";

  @override
  String get logViewerSectionResponseBody => "متن الاستجابة";

  @override
  String get logViewerSectionWarnings => "تحذيرات";

  @override
  String get logViewerErrorTitle => "خطأ";

  @override
  String logViewerMoreCount(int count) => "+${count} أخرى";

  @override
  String get logViewerSectionAttachments => "المرفقات";

  @override
  String get logViewerPayloadOmitted => "تم الاستبعاد";

  @override
  String get logViewerShowMore => "عرض المزيد";

  @override
  String get logSettingsTitle => "إعدادات السجلات";

  @override
  String get logSettingsSaveOutput => "حفظ مخرجات الاستجابة";

  @override
  String get logSettingsSaveOutputSubtitle => "تسجيل كل جزء من أجزاء البث (قد يؤدي ذلك إلى إبطاء التوليد). يتم دائمًا تسجيل نصوص استجابات أخطاء HTTP.";

  @override
  String get logSettingsElidePayloads => "إخفاء الحمولات الكبيرة";

  @override
  String get logSettingsElidePayloadsSubtitle => "استبدال الصور والملفات المضمّنة بترميز Base64 بعناصر نائبة. يحافظ ذلك على صغر السجلات وسرعة عرضها.";

  @override
  String get logSettingsAutoDelete => "الحذف التلقائي";

  @override
  String get logSettingsAutoDeleteSubtitle => "حذف السجلات الأقدم من عدد الأيام المحدد.";

  @override
  String get logSettingsAutoDeleteDisabled => "معطّل";

  @override
  String logSettingsAutoDeleteDays(int count) => "${count} يومًا";

  @override
  String get logSettingsMaxSize => "الحد الأقصى لحجم السجل";

  @override
  String get logSettingsMaxSizeSubtitle => "يتم حذف أقدم السجلات عند تجاوز الحد.";

  @override
  String get logSettingsMaxSizeUnlimited => "بلا حد";

  @override
  String get assistantEditManageSummariesTitle => "إدارة الملخصات";

  @override
  String get assistantEditSummaryEmpty => "لا توجد ملخصات بعد.";

  @override
  String get assistantEditSummaryDialogTitle => "تعديل الملخص";

  @override
  String get assistantEditSummaryDialogHint => "أدخل محتوى الملخص";

  @override
  String get assistantEditDeleteSummaryTitle => "مسح الملخص";

  @override
  String get assistantEditDeleteSummaryContent => "هل تريد بالتأكيد مسح هذا الملخص؟";

  @override
  String get homePageProcessingFiles => "جارٍ تجهيز الملفات…";

  @override
  String get settingsPageWorldBook => "الكتاب المعرفي";

  @override
  String get settingsPageMemory => "الذاكرة";

  @override
  String get memorySettingsPageTitle => "الذاكرة";

  @override
  String get memorySettingsGlobalSubtitle => "وضع الذاكرة والنموذج والتعليمات";

  @override
  String get memorySettingsModeSection => "وضع الذاكرة";

  @override
  String get memorySettingsModelSection => "نموذج الذاكرة";

  @override
  String get memorySettingsModelTitle => "نموذج المعالجة";

  @override
  String get memorySettingsModelUnset => "لم يتم الاختيار";

  @override
  String get memorySettingsModelTip => "بعد تفعيل التنظيم التلقائي للذاكرة، يُستدعى هذا النموذج كثيرًا في الخلفية. يُفضّل اختيار نموذج سريع ومنخفض التكلفة.";

  @override
  String get memorySettingsAboutTitle => "حول الذاكرة";

  @override
  String get memorySettingsAboutSubtitle => "كيفية عمل الذاكرة ومتى يتم تشغيلها";

  @override
  String get memoryAboutQuickstartTitle => "البدء";

  @override
  String get memoryAboutQuickstartBody => "1. من الإعدادات ← الذاكرة، اختر نموذج المعالجة.\n2. من علامة تبويب الذاكرة لدى المساعد، فعّل الذاكرة طويلة الأمد والتنظيم التلقائي.\n3. أجرِ بضع محادثات أو اضغط على «تنظيم»، ثم افتح «كل الذكريات» للاطلاع على ما تم حفظه.";

  @override
  String get memoryAboutTypesTitle => "أنواع الذاكرة";

  @override
  String get memoryAboutTypesBody => "الهوية: حقائق مستقرة عن المستخدم، مثل طريقة مخاطبته ودوره ولغته وتفضيلاته طويلة الأمد. صُغها في جمل كاملة بضمير الغائب.\n\nسير العمل: الطريقة التي يفضّل بها إنجاز المهام، مثل الأدوات والتنسيقات وعادات المراجعة.\n\nالصوت والأسلوب: النبرة والطول والأسلوب اللغوي الذي يفضّله المستخدم في ردود المساعد.\n\nالتعليمات: قواعد دائمة ينبغي للمساعد اتباعها، وليست مهامًا لمرة واحدة من هذه المحادثة.";

  @override
  String get memoryAboutScopeTitle => "الذاكرة العامة وذاكرة المساعد";

  @override
  String get memoryAboutScopeBody => "تُضاف الذكريات العامة إلى سياق كل مساعد. أما ذكريات المساعد فتكون مرئية لذلك المساعد وحده. استخدم الذاكرة العامة للحقائق التي ينبغي أن ترافق المستخدم في كل مكان، واستخدم نطاق المساعد للقواعد أو السياق المرتبط بشخصية معينة.";

  @override
  String get memoryAboutInjectionTitle => "كيفية إدراج الذكريات";

  @override
  String get memoryAboutInjectionBody => "في بداية المحادثة، تُضاف أحدث العناصر من كل نوع إلى سياق النموذج. إذا تجاوز أحد الأنواع حد الإدراج، تُعلّم الكتلة بوضع mode=\"summary\" مع إجمالي العناصر وعدد العناصر المعروضة؛ ويمكن جلب البقية باستخدام memory_search_profile. ارفع الحد من الإعدادات ← الذاكرة للحصول على سياق أشمل مقابل استهلاك عدد أكبر من الرموز.";

  @override
  String get memoryAboutPipelineTitle => "المعالجة في الخلفية";

  @override
  String get memoryAboutPipelineBody => "يعمل التنظيم التلقائي بعد المحادثات: يقرر النظام أولًا ما إذا كان هناك ما يستحق التذكر، ثم يستخرج العناصر المرشحة ويزيل التكرار ويدمج العناصر، وبعد ذلك يحوّل عناصر الهوية إلى حقول في ملف المستخدم عند الحاجة. ويمكنك أيضًا الضغط على «تنظيم» من علامة تبويب الذاكرة لدى المساعد. لذلك يُستدعى نموذج المعالجة بشكل متكرر.";

  @override
  String get memoryAboutCacheTitle => "الحفاظ على كفاءة التخزين المؤقت";

  @override
  String get memoryAboutCacheBody => "تظل بادئة الذاكرة التي تُدرج في السياق ثابتة، حتى تتمكن المحادثات التي لم تتغير من إعادة استخدام ذاكرة التعليمات المؤقتة، مما يقلل التكلفة وزمن الاستجابة. تجنّب التعديلات الجماعية أو إعادة الترتيب غير الضرورية. عادةً ما يكون تأثير تعديل عنصر واحد يوميًا محدودًا.";

  @override
  String get memoryAboutFaqTitle => "الأسئلة الشائعة";

  @override
  String get memoryAboutFaqWhyNotRememberedTitle => "لماذا لم يتم حفظ هذه المعلومة؟";

  @override
  String get memoryAboutFaqWhyNotRememberedBody => "يتم تخطي التنظيم عندما لا توجد رسائل جديدة كافية أو لا توجد رسائل جديدة لتنظيمها أو لم يتم اختيار نموذج لمعالجة الذاكرة. لا تُحفظ المحادثات المؤقتة في الذاكرة. ويمكنك أيضًا تعطيل الذاكرة أو التنظيم التلقائي لكل مساعد على حدة.";

  @override
  String get memorySettingsThinkingTitle => "تفعيل التفكير";

  @override
  String get memorySettingsThinkingSubtitle => "السماح لنموذج الذاكرة باستخدام الاستدلال عند توفر الدعم.";

  @override
  String get memorySettingsInjectionSection => "إدراج الذاكرة في السياق";

  @override
  String get memorySettingsInjectionMaxItemsTitle => "العناصر المدرجة لكل نوع";

  @override
  String get memorySettingsInjectionMaxItemsSubtitle => "ينطبق هذا الحد على الأنواع التي لم يتم اختيارها للإدراج الكامل. عند تجاوز النوع لهذا الحد، تُدرج أحدث العناصر فقط. ويمكن جلب البقية باستخدام memory_search_profile. يمنح العدد الأكبر سياقًا أشمل لكنه يستهلك رموزًا أكثر. إذا خصصت تعليمات القواعد، فحدّثها أو استعد الإعداد الافتراضي.";

  @override
  String get memorySettingsFullInjectionTypesTitle => "إدراج هذه الأنواع دائمًا";

  @override
  String get memorySettingsFullInjectionTypesSubtitle => "اختر نوعًا أو أكثر لإدراج جميع ذكرياته النشطة المرئية للمساعد الحالي. تتجاهل هذه الأنواع حد العناصر وتستهلك مساحة سياق ورموزًا أكثر.";

  @override
  String get memorySettingsInjectionMaxItemsCustomButton => "مخصص";

  @override
  String get memorySettingsInjectionMaxItemsCustomTitle => "عدد عناصر مخصص";

  @override
  String get memorySettingsInjectionMaxItemsCustomDescription => "أدخل رقمًا بين 1 و100.";

  @override
  String get memorySettingsInjectionMaxItemsCustomLabel => "العدد";

  @override
  String get memorySettingsInjectionMaxItemsCustomInvalid => "أدخل رقمًا بين 1 و100.";

  @override
  String get memorySettingsPromptLangSection => "لغة التعليمات";

  @override
  String get memorySettingsPromptLangAuto => "تلقائي";

  @override
  String get memorySettingsPromptLangAutoSubtitle => "اتباع لغة الواجهة (الصينية ← zh، وما عدا ذلك en).";

  @override
  String get memorySettingsPromptLangZh => "الصينية";

  @override
  String get memorySettingsPromptLangZhSubtitle => "استخدام تعليمات الذاكرة وأوصاف الأدوات باللغة الصينية دائمًا.";

  @override
  String get memorySettingsPromptLangEn => "الإنجليزية";

  @override
  String get memorySettingsPromptLangEnSubtitle => "استخدام تعليمات الذاكرة وأوصاف الأدوات باللغة الإنجليزية دائمًا.";

  @override
  String get memorySettingsPromptsSection => "قوالب التعليمات";

  @override
  String get memorySettingsLegacyPromptTitle => "قواعد الذاكرة القديمة";

  @override
  String get memoryPromptEditRulesTitle => "قواعد الذاكرة";

  @override
  String get memoryPromptEditRulesSubtitle => "تُضاف إلى تعليمات النظام الرئيسية للمحادثة.";

  @override
  String get memoryPromptEditGateTitle => "بوابة التقييم";

  @override
  String get memoryPromptEditGateSubtitle => "تحدد ما إذا كانت الرسالة تستحق الحفظ في الذاكرة.";

  @override
  String get memoryPromptEditExtractTitle => "الاستخراج";

  @override
  String get memoryPromptEditExtractSubtitle => "استخراج عناصر الذاكرة المرشحة من المحادثة.";

  @override
  String get memoryPromptEditSmartAddTitle => "الإضافة الذكية";

  @override
  String get memoryPromptEditSmartAddSubtitle => "تحديد ما إذا كان العنصر جديدًا أو يحتاج إلى دمج أو يتعارض أو يجب تخطيه (NEW / MERGE / CONFLICT / SKIP).";

  @override
  String get memoryPromptEditDistillTitle => "تلخيص ملف المستخدم";

  @override
  String get memoryPromptEditDistillSubtitle => "تحويل ذكريات الهوية إلى حقول في ملف المستخدم.";

  @override
  String get memoryPromptEditMigrateTitle => "الترحيل القديم";

  @override
  String get memoryPromptEditMigrateSubtitle => "يُستخدم عند إعادة صياغة نصوص الذاكرة أثناء الترحيل.";

  @override
  String get memoryPromptEditReset => "استعادة الإعداد الافتراضي";

  @override
  String get memoryPromptEditSave => "حفظ";

  @override
  String get memoryPromptEditSectionPerItem => "تعليمات لكل عنصر";

  @override
  String get memoryPromptEditSectionBatch => "تعليمات مجمّعة";

  @override
  String get memorySettingsEntriesSection => "كل الذكريات";

  @override
  String get memorySettingsLegacySection => "الذاكرة القديمة";

  @override
  String get memorySettingsEntriesTitle => "قائمة الذكريات";

  @override
  String get memorySettingsEntriesSubtitle => "استعراض الذكريات وتعديلها وأرشفتها وحذفها.";

  @override
  String get memorySettingsProfileTitle => "ملف المستخدم";

  @override
  String get memorySettingsProfileSubtitle => "حقول هوية منظّمة للنموذج.";

  @override
  String get memorySettingsLegacyTitle => "الذكريات القديمة (للقراءة فقط)";

  @override
  String get memorySettingsLegacySubtitle => "ذكريات من الإصدارات السابقة.";

  @override
  String get memoryEntryTypeIdentity => "الهوية";

  @override
  String get memoryEntryTypeWorkflow => "سير العمل";

  @override
  String get memoryEntryTypeVoice => "الأسلوب";

  @override
  String get memoryEntryTypeInstruction => "تعليمات";

  @override
  String get memoryEntryScopeGlobal => "عام";

  @override
  String get memoryEntryScopeAssistant => "هذا المساعد";

  @override
  String get memoryEntrySourceManual => "يدوي";

  @override
  String get memoryEntrySourceTool => "أداة";

  @override
  String get memoryEntrySourceExtracted => "مستخرج";

  @override
  String get memoryEntrySourceDistilled => "مستخلص";

  @override
  String get memoryEntryStatusActive => "نشط";

  @override
  String get memoryEntryStatusArchived => "مؤرشف";

  @override
  String memoryEntryUpdatedAt(String date) => "تم التحديث في ${date}";

  @override
  String get memoryEntryActionEdit => "تعديل";

  @override
  String get memoryEntryActionDelete => "حذف";

  @override
  String get memoryEntryActionArchive => "أرشفة";

  @override
  String get memoryEntryActionRestore => "استعادة";

  @override
  String get memoryEntryActionSwitchScope => "تغيير النطاق";

  @override
  String get memoryEntryActionBatchDelete => "حذف المحدد";

  @override
  String get memoryEntryActionAdd => "إضافة ذاكرة";

  @override
  String get memoryEntryDeleteConfirmTitle => "حذف الذاكرة؟";

  @override
  String get memoryEntryDeleteConfirmContent => "سيؤدي ذلك إلى حذف الذاكرة نهائيًا. لا يمكن التراجع عن هذا الإجراء.";

  @override
  String memoryEntryBatchDeleteConfirmTitle(int count) => "حذف ${count} من الذكريات؟";

  @override
  String get memoryEntryBatchDeleteConfirmContent => "سيتم حذف الذكريات المحددة نهائيًا.";

  @override
  String get memoryEntrySwitchScopeConfirmTitle => "تغيير نطاق الذاكرة؟";

  @override
  String get memoryEntrySwitchScopeToGlobal => "هل تريد جعل هذه الذاكرة عامة ومشتركة بين جميع المساعدين؟";

  @override
  String get memoryEntrySwitchScopeToAssistant => "هل تريد قصر هذه الذاكرة على المساعد الحالي؟";

  @override
  String get memoryEntryArchivedSection => "المؤرشفة";

  @override
  String get memoryEntryEmpty => "لا توجد ذكريات بعد.";

  @override
  String get memoryEntryEmptyDisabled => "الذاكرة طويلة الأمد معطّلة لهذا المساعد.";

  @override
  String get memoryEntryEditTitle => "تعديل الذاكرة";

  @override
  String get memoryEntryCreateTitle => "ذاكرة جديدة";

  @override
  String get memoryEntryContentHint => "أدخل محتوى الذاكرة";

  @override
  String get memoryEntryTypeLabel => "النوع";

  @override
  String get memoryEntryScopeLabel => "النطاق";

  @override
  String get memoryFilterScopeAll => "كل النطاقات";

  @override
  String get memoryFilterScopeGlobal => "العامة فقط";

  @override
  String get memoryFilterScopeAssistant => "المساعد";

  @override
  String get memoryFilterTypeAll => "كل الأنواع";

  @override
  String get memoryFilterStatusAll => "كل الحالات";

  @override
  String get memoryFilterStatusActive => "نشط";

  @override
  String get memoryFilterStatusArchived => "مؤرشف";

  @override
  String get memorySearchHint => "البحث في الذكريات";

  @override
  String get memorySearchEmpty => "لا توجد ذكريات مطابقة.";

  @override
  String memoryOrphanBanner(int count) => "${count} من ذكريات المساعدين اليتيمة (تم حذف المساعد)";

  @override
  String get memoryOrphanCleanupButton => "تنظيف";

  @override
  String get memoryOrphanConfirmTitle => "تنظيف الذكريات اليتيمة؟";

  @override
  String memoryOrphanConfirmContent(int count) => "سيتم حذف ${count} من الذكريات نهائيًا لعدم وجود المساعد المرتبط بها.";

  @override
  String get memoryOrganizeButton => "تنظيم";

  @override
  String get memoryOrganizeNeedsConversation => "افتح محادثة مع هذا المساعد لتنظيم الذكريات.";

  @override
  String get memoryOrganizeNeedsModel => "اختر أولًا نموذجًا لمعالجة الذاكرة من الإعدادات ← الذاكرة.";

  @override
  String get memoryOrganizeStatusNever => "لم يتم التنظيم بعد";

  @override
  String memoryOrganizeStatusLast(String when) => "آخر تنظيم: ${when}";

  @override
  String memoryOrganizeStatusExtracted(int count) => "تم استخراج ${count}";

  @override
  String get memoryOrganizeStatusSkipped => "لا توجد معلومات تستحق التذكر";

  @override
  String memoryOrganizeStatusFailed(String reason) => "فشل: ${reason}";

  @override
  String memoryOrganizeStatusSkippedReason(String reason) => "تم التخطي: ${reason}";

  @override
  String get memoryOutcomeTemporaryConversation => "لا تُحفظ المحادثات المؤقتة في الذاكرة";

  @override
  String get memoryOutcomeMemoryDisabled => "الذاكرة متوقفة لهذا المساعد";

  @override
  String get memoryOutcomeAutoOrganizeOff => "التنظيم التلقائي متوقف";

  @override
  String get memoryOutcomeStreaming => "تم التخطي لأن الرد لا يزال قيد التوليد";

  @override
  String get memoryOutcomeBelowThreshold => "عدد الرسائل الجديدة غير كافٍ للتنظيم";

  @override
  String get memoryOutcomeEmptyWindow => "لا توجد رسائل جديدة لتنظيمها";

  @override
  String get memoryOutcomeMemoryModelUnset => "لم يتم اختيار نموذج لمعالجة الذاكرة";

  @override
  String get memoryOutcomeMemoryModelMissing => "لم يعد نموذج الذاكرة المحدد متاحًا";

  @override
  String get memoryOutcomeAssistantMissing => "لم يتم العثور على المساعد";

  @override
  String get memoryOutcomeConversationMissing => "لم يتم العثور على المحادثة";

  @override
  String get memoryOutcomeQueueOverflow => "امتلأ طابور التنظيم، لذلك تم إسقاط هذه العملية";

  @override
  String get memoryOutcomeGateRequestFailed => "تعذّر الوصول إلى نموذج الذاكرة للتحقق مما إذا كان ينبغي التذكر أو التخطي";

  @override
  String get memoryOutcomeGateParseFailed => "تعذّر قراءة رد التحقق من التذكر أو التخطي";

  @override
  String get memoryOutcomeExtractRequestFailed => "تعذّر الوصول إلى نموذج الذاكرة لاستخراج الذكريات";

  @override
  String get memoryOutcomeExtractParseFailed => "تعذّر تحليل رد استخراج الذكريات";

  @override
  String get memoryOutcomeDistillFailed => "تعذّر استخلاص ملف المستخدم الشخصي";

  @override
  String get memoryOutcomeMemoryExecutionError => "فشل تشغيل إحدى أدوات الذاكرة";

  @override
  String get memoryOutcomeUnsupportedTool => "أداة ذاكرة غير مدعومة";

  @override
  String get memoryOutcomeInvalidMemoryType => "نوع ذاكرة غير صالح";

  @override
  String get memoryOutcomeInvalidMemoryContent => "محتوى ذاكرة غير صالح";

  @override
  String get memoryOutcomeInvalidQuery => "استعلام بحث غير صالح";

  @override
  String get memoryOutcomeInvalidMemoryId => "معرّف ذاكرة غير صالح";

  @override
  String get memoryOutcomeMemoryNotFound => "لم يتم العثور على الذاكرة";

  @override
  String get memoryOutcomeInvalidProfileFields => "حقول الملف الشخصي غير صالحة";

  @override
  String get memoryOutcomeChatSearchUnavailable => "البحث في المحادثات غير متاح";

  @override
  String get memoryOrganizeJustNow => "الآن";

  @override
  String memoryOrganizeMinutesAgo(int n) => "قبل ${n} دقيقة";

  @override
  String memoryOrganizeHoursAgo(int n) => "قبل ${n} ساعة";

  @override
  String memoryOrganizeDaysAgo(int n) => "قبل ${n} يوم";

  @override
  String get memoryModelMissingNotice => "اختر أولًا نموذجًا لمعالجة الذاكرة من الإعدادات ← الذاكرة.";

  @override
  String get memoryModelMissingGoSelect => "اختيار نموذج";

  @override
  String get memoryEntriesPageTitle => "جميع الذكريات";

  @override
  String get userProfilePageTitle => "ملف المستخدم الشخصي";

  @override
  String get userProfilePreferredName => "الاسم المفضّل";

  @override
  String get userProfilePreferredNameHint => "الاسم الذي ينبغي للنموذج مناداتك به، وهو مستقل عن اسم العرض في الشريط الجانبي";

  @override
  String get userProfileGender => "الجنس";

  @override
  String get userProfilePronouns => "الضمائر";

  @override
  String get userProfilePreferredLanguage => "اللغة المفضّلة";

  @override
  String get userProfileTimezone => "المنطقة الزمنية";

  @override
  String get userProfileOccupation => "المهنة";

  @override
  String get userProfileLocation => "الموقع";

  @override
  String get userProfileCustomSection => "حقول مخصصة";

  @override
  String get userProfileAddCustom => "إضافة حقل مخصص";

  @override
  String get userProfileCustomKeyHint => "المفتاح (custom.name)";

  @override
  String get userProfileCustomValueHint => "القيمة";

  @override
  String get userProfileInvalidKey => "يجب أن يبدأ المفتاح بـ custom. ثم يتبعه من 1 إلى 32 حرفًا أو رقمًا أو _ أو -";

  @override
  String get userProfileClear => "مسح";

  @override
  String get userProfileSave => "حفظ";

  @override
  String get userProfileEmptyValue => "غير محدد";

  @override
  String get legacyMemoryPageTitle => "الذكريات القديمة";

  @override
  String get legacyMemoryBanner => "هذه الذكريات من إصدار أقدم ولا تُستخدم في المحادثات. يمكنك ترحيلها إلى نظام الذاكرة الحالي.";

  @override
  String get legacyMemoryEmpty => "لا توجد ذكريات قديمة";

  @override
  String get legacyMemoryCopy => "نسخ";

  @override
  String get legacyMemoryCopied => "تم النسخ";

  @override
  String get legacyMemoryExport => "تصدير";

  @override
  String get legacyMemoryExportTitle => "تصدير ذكريات Kelivo القديمة";

  @override
  String legacyMemoryAssistantHeader(String name) => "المساعد: ${name}";

  @override
  String get legacyMemorySearchHint => "البحث في الذكريات القديمة";

  @override
  String get legacyMemoryMigrate => "ترحيل";

  @override
  String get legacyMemoryMigrationTitle => "ترحيل الذكريات القديمة";

  @override
  String legacyMemoryMigrationSubtitle(int count) => "استخدم نموذجًا لتصنيف وتنظيم ${count} من الذكريات القديمة. ستظل النسخ الأصلية دون تغيير.";

  @override
  String get legacyMemoryMigrationModel => "نموذج الترحيل";

  @override
  String get legacyMemoryMigrationChooseModel => "اختيار نموذج";

  @override
  String get legacyMemoryMigrationTarget => "الحفظ في";

  @override
  String get legacyMemoryMigrationTargetGlobal => "عام";

  @override
  String get legacyMemoryMigrationTargetAssistant => "المساعد الحالي";

  @override
  String get legacyMemoryMigrationTargetOriginalAssistants => "المساعدون الأصليون";

  @override
  String get legacyMemoryMigrationTargetGlobalDescription => "متاح لجميع المساعدين";

  @override
  String get legacyMemoryMigrationTargetAssistantDescription => "متاح لهذا المساعد فقط";

  @override
  String get legacyMemoryMigrationTargetOriginalDescription => "الاحتفاظ بكل ذاكرة مع المساعد الأصلي الخاص بها";

  @override
  String get legacyMemoryMigrationStart => "بدء الترحيل";

  @override
  String get legacyMemoryMigrationAnalyzing => "جارٍ التحليل باستخدام النموذج";

  @override
  String get legacyMemoryMigrationWriting => "جارٍ حفظ الذكريات";

  @override
  String legacyMemoryMigrationProgress(int current, int total) => "${current} من ${total}";

  @override
  String get legacyMemoryMigrationComplete => "اكتمل الترحيل";

  @override
  String legacyMemoryMigrationResult(int created, int skipped) => "تم ترحيل ${created} · وكان ${skipped} موجودًا بالفعل";

  @override
  String get legacyMemoryMigrationFailed => "توقف الترحيل. يمكنك إعادة المحاولة؛ وسيتم تخطي الذكريات التي سبق حفظها.";

  @override
  String get legacyMemoryMigrationRetry => "إعادة المحاولة";

  @override
  String get legacyMemoryMigrationClose => "تم";

  @override
  String get legacyMemoryMigrationContentMode => "المحتوى";

  @override
  String get legacyMemoryMigrationContentPreserve => "الاحتفاظ بالأصل";

  @override
  String get legacyMemoryMigrationContentOrganize => "إعادة الصياغة باستخدام النموذج";

  @override
  String get legacyMemoryMigrationContentPreserveDescription => "يحدد النموذج النوع فقط، ويُحفظ النص الأصلي كما هو.";

  @override
  String get legacyMemoryMigrationContentOrganizeDescription => "يصنّف النموذج كل ذاكرة ويعيد صياغتها باستخدام تعليمات الترحيل القابلة للتحرير.";

  @override
  String get legacyMemoryMigrationBatchSize => "حجم الدفعة";

  @override
  String legacyMemoryMigrationPartial(int created, int skipped, int failed) => "تم ترحيل ${created} · تم تخطي ${skipped} · فشل ${failed}";

  @override
  String get legacyMemoryMigrationContinue => "متابعة الترحيل";

  @override
  String get legacyMemoryMigrationErrorNetwork => "خطأ في الشبكة. تحقق من الاتصال وحاول مرة أخرى.";

  @override
  String get legacyMemoryMigrationErrorFormat => "أعاد النموذج استجابة غير صالحة.";

  @override
  String get legacyMemoryMigrationErrorAuth => "فشلت المصادقة. تحقق من مفتاح API.";

  @override
  String legacyMemoryMigrationErrorOther(String message) => "فشل الترحيل: ${message}";

  @override
  String get legacyMemoryModeTitle => "استخدام الذاكرة القديمة";

  @override
  String get legacyMemoryModeSubtitle => "إعداد عام لجميع المساعدين";

  @override
  String legacyMemoryModeCacheWarning(String token) => "يُدرج القالب الافتراضي الوقت الحالي عبر ${token}، مما يؤثر في معدل إصابة ذاكرة التخزين المؤقت. أزله إذا لم تكن بحاجة إليه.";

  @override
  String get memoryUiContentLabel => "المحتوى";

  @override
  String get memoryUiValueLabel => "القيمة";

  @override
  String get memoryUiCustomKeyLabel => "المفتاح";

  @override
  String get memoryUiStatusLabel => "الحالة";

  @override
  String get memoryUiAssistantLabel => "المساعد";

  @override
  String get memoryUiAssistantAll => "جميع المساعدين";

  @override
  String get memoryUiSearchClear => "مسح البحث";

  @override
  String get memoryUiAssistantLegacyTitle => "الذكريات القديمة (للقراءة فقط)";

  @override
  String get memoryUiAssistantLegacySubtitle => "الذكريات القديمة لهذا المساعد من الإصدارات السابقة";

  @override
  String get assistantEditMemorySwitchTitle => "استخدام الذاكرة طويلة الأمد";

  @override
  String get assistantEditMemorySwitchSubtitle => "إدراج الذكريات المحفوظة في المحادثات والسماح لهذا المساعد بإنشاء ذكريات جديدة";

  @override
  String get assistantEditAutoOrganizeTitle => "تنظيم الذاكرة تلقائيًا";

  @override
  String get assistantEditAutoOrganizeSubtitle => "تشغيل مسار معالجة الذاكرة بعد المحادثات";

  @override
  String get assistantEditAllowPastRecallTitle => "السماح باسترجاع المحادثات السابقة";

  @override
  String get assistantEditAllowPastRecallSubtitle => "تفعيل البحث في المحادثات السابقة";

  @override
  String get assistantEditGenerateSummaryTitle => "إنشاء ملخصات للمحادثات";

  @override
  String get assistantEditGenerateSummarySubtitle => "تُستخدم الملخصات في البحث داخل المحادثات فقط";

  @override
  String get assistantEditManageMemoryTitle => "الذكريات المرئية لهذا المساعد";

  @override
  String get assistantEditWriteScopeTitle => "نطاق كتابة الذاكرة";

  @override
  String get assistantEditWriteScopeSubtitle => "المكان الافتراضي لحفظ الذكريات الجديدة";

  @override
  String get assistantEditWriteScopeAlwaysGlobal => "عام دائمًا";

  @override
  String get assistantEditWriteScopeAlwaysGlobalSubtitle => "تُشارك الذكريات الجديدة مع جميع المساعدين";

  @override
  String get assistantEditWriteScopeAlwaysAssistant => "هذا المساعد دائمًا";

  @override
  String get assistantEditWriteScopeAlwaysAssistantSubtitle => "تظل الذكريات الجديدة خاصة بهذا المساعد";

  @override
  String get assistantEditWriteScopeToolDefaultGlobal => "اختيار النموذج (الافتراضي عام)";

  @override
  String get assistantEditWriteScopeToolDefaultGlobalSubtitle => "يمكن للنموذج اختيار العام أو هذا المساعد؛ والافتراضي هو العام";

  @override
  String get assistantEditWriteScopeToolDefaultAssistant => "اختيار النموذج (الافتراضي هذا المساعد)";

  @override
  String get assistantEditWriteScopeToolDefaultAssistantSubtitle => "يمكن للنموذج اختيار العام أو هذا المساعد؛ والافتراضي هو هذا المساعد";

  @override
  String get assistantEditDedupeModeTitle => "وضع إزالة التكرار";

  @override
  String get assistantEditDedupeModeSubtitle => "كيفية تقييم العناصر المرشحة مقارنة بالذكريات الموجودة";

  @override
  String get assistantEditDedupeModeBatched => "على دفعات";

  @override
  String get assistantEditDedupeModeBatchedSubtitle => "تقييم جميع العناصر الجديدة في طلب واحد. أسرع وأقل تكلفة، لكنه أقل دقة عند وصول عناصر كثيرة دفعة واحدة.";

  @override
  String get assistantEditDedupeModePerItem => "لكل عنصر";

  @override
  String get assistantEditDedupeModePerItemSubtitle => "تقييم كل عنصر مرشح في طلب مستقل. أدق، لكنه يستخدم عددًا أكبر من استدعاءات النموذج.";

  @override
  String get assistantEditOrganizeFrequencyTitle => "التنظيم كل N من الأدوار";

  @override
  String get assistantEditOrganizeFrequencySubtitle => "تشغيل التنظيم التلقائي بعد هذا العدد من ردود المساعد";

  @override
  String assistantEditOrganizeFrequencyOption(int n) => "كل ${n}";

  @override
  String get assistantEditOrganizeFrequencyCustomButton => "مخصص";

  @override
  String get assistantEditOrganizeFrequencyCustomTitle => "تكرار مخصص";

  @override
  String get assistantEditOrganizeFrequencyCustomDescription => "أدخل رقمًا بين 1 و20.";

  @override
  String get assistantEditOrganizeFrequencyCustomLabel => "الأدوار";

  @override
  String get assistantEditOrganizeFrequencyCustomInvalid => "أدخل رقمًا بين 1 و20";

  @override
  String get worldBookTitle => "دفتر العالم";

  @override
  String get worldBookAdd => "إضافة دفتر عالم";

  @override
  String get worldBookEmptyMessage => "لا توجد دفاتر عالم بعد";

  @override
  String get worldBookUnnamed => "دفتر عالم بلا اسم";

  @override
  String get worldBookDisabledTag => "معطّل";

  @override
  String get worldBookAlwaysOnTag => "مفعّل دائمًا";

  @override
  String get worldBookAddEntry => "إضافة مدخل";

  @override
  String get worldBookExport => "مشاركة / تصدير";

  @override
  String get worldBookConfig => "تهيئة";

  @override
  String get worldBookDeleteTitle => "حذف دفتر العالم";

  @override
  String worldBookDeleteMessage(String name) => "هل تريد حذف «${name}»؟ لا يمكن التراجع عن هذا الإجراء.";

  @override
  String get worldBookCancel => "إلغاء";

  @override
  String get worldBookDelete => "حذف";

  @override
  String worldBookExportFailed(String error) => "فشل التصدير: ${error}";

  @override
  String get worldBookNoEntriesHint => "لا توجد مدخلات";

  @override
  String get worldBookUnnamedEntry => "مدخل بلا اسم";

  @override
  String worldBookKeywordsLine(String keywords) => "الكلمات المفتاحية: ${keywords}";

  @override
  String get worldBookEditEntry => "تعديل المدخل";

  @override
  String get worldBookDeleteEntry => "حذف المدخل";

  @override
  String get worldBookNameLabel => "الاسم";

  @override
  String get worldBookDescriptionLabel => "الوصف";

  @override
  String get worldBookEnabledLabel => "مفعّل";

  @override
  String get worldBookSave => "حفظ";

  @override
  String get worldBookEntryNameLabel => "اسم المدخل";

  @override
  String get worldBookEntryEnabledLabel => "تفعيل المدخل";

  @override
  String get worldBookEntryPriorityLabel => "الأولوية";

  @override
  String get worldBookEntryKeywordsLabel => "الكلمات المفتاحية";

  @override
  String get worldBookEntryKeywordsHint => "اكتب كلمة مفتاحية ثم اضغط على + لإضافتها.";

  @override
  String get worldBookEntryKeywordInputHint => "اكتب كلمة مفتاحية";

  @override
  String get worldBookEntryKeywordAddTooltip => "إضافة كلمة مفتاحية";

  @override
  String get worldBookEntryUseRegexLabel => "استخدام التعبيرات النمطية (Regex)";

  @override
  String get worldBookEntryCaseSensitiveLabel => "مطابقة حالة الأحرف";

  @override
  String get worldBookEntryAlwaysOnLabel => "نشط دائمًا";

  @override
  String get worldBookEntryAlwaysOnHint => "إدراج المحتوى دائمًا دون الحاجة إلى مطابقة الكلمات المفتاحية.";

  @override
  String get worldBookEntryScanDepthLabel => "عمق الفحص";

  @override
  String get worldBookEntryContentLabel => "المحتوى";

  @override
  String get worldBookEntryInjectionPositionLabel => "موضع الإدراج";

  @override
  String get worldBookEntryInjectionRoleLabel => "دور الإدراج";

  @override
  String get worldBookEntryInjectDepthLabel => "عمق الإدراج";

  @override
  String get worldBookInjectionPositionBeforeSystemPrompt => "قبل تعليمات النظام";

  @override
  String get worldBookInjectionPositionAfterSystemPrompt => "بعد تعليمات النظام";

  @override
  String get worldBookInjectionPositionTopOfChat => "بداية المحادثة";

  @override
  String get worldBookInjectionPositionBottomOfChat => "نهاية المحادثة";

  @override
  String get worldBookInjectionPositionAtDepth => "عند عمق محدد";

  @override
  String worldBookImportUnsupportedEntries(int count) => "تم الاستيراد. يستخدم ${count} من المدخلات ميزات SillyTavern غير المدعومة (مثل وحدات الماكرو أو Regex أو التوقيت أو عوامل التصفية أو قواعد الإدراج). تم الاحتفاظ بمحتواها وتعطيلها. راجعها قبل تفعيلها.";

  @override
  String get worldBookInjectionRoleUser => "المستخدم";

  @override
  String get worldBookInjectionRoleAssistant => "المساعد";

  @override
  String get mcpToolNeedsApproval => "يتطلب موافقة";

  @override
  String get toolApprovalPending => "بانتظار الموافقة";

  @override
  String get toolApprovalDeny => "رفض";

  @override
  String get toolApprovalDenyTitle => "رفض استدعاء الأداة";

  @override
  String get toolApprovalDenyHint => "السبب (اختياري)";

  @override
  String toolApprovalDeniedMessage(Object reason, Object toolName) => "رفض المستخدم استدعاء الأداة \"${toolName}\". السبب: ${reason}";

  @override
  String get askUserCardSubmit => "إرسال الإجابة";

  @override
  String get askUserCardCustomHint => "اكتب إجابتك";

  @override
  String get askUserCardSomethingElse => "شيء آخر";

  @override
  String get askUserCardSkip => "تخطي";

  @override
  String get askUserCardSkipped => "تم التخطي";

  @override
  String get askUserCardAnswered => "تمت الإجابة";

  @override
  String get askUserCardInactive => "لم يعد هذا السؤال نشطًا. أنشئ الرد مجددًا أو تابع المحادثة.";

  @override
  String get askUserCardCancelled => "تم إلغاء السؤال";

  @override
  String askUserCardQuestionCount(int count) => (count == 0 ? "لا توجد أسئلة" : (count == 1 ? "اطرح سؤالًا واحدًا" : intl.Intl.pluralLogic(count, locale: localeName, two: "اطرح سؤالين", few: "اطرح ${count} أسئلة", many: "اطرح ${count} سؤالًا", other: "اطرح ${count} سؤال")));

  @override
  String tokenDetailPromptTokens(int count) => "${count} رمزًا";

  @override
  String tokenDetailPromptTokensWithCache(int count, int cached) => "${count} رمزًا (${cached} في الذاكرة المؤقتة)";

  @override
  String tokenDetailCompletionTokens(int count) => "${count} رمزًا";

  @override
  String tokenDetailSpeed(String value) => "${value} رمز/ث";

  @override
  String tokenDetailDuration(String value) => "${value} ث";

  @override
  String tokenDetailFirstToken(String value) => "${value} ث (الرمز الأول)";

  @override
  String tokenDetailTotalTokens(int count) => "إجمالي الرموز: ${count}";

  @override
  String tokenDetailReasoningTokens(int count) => "رموز الاستدلال: ${count}";

  @override
  String tokenDetailCacheWriteTokens(int count) => "رموز كتابة الذاكرة المؤقتة: ${count}";

  @override
  String get debugPageTitle => "التصحيح";

  @override
  String get debugPageConversationToolsTitle => "أدوات المحادثة";

  @override
  String get debugPageCreateOversizedConversationButton => "إنشاء محادثة كبيرة جدًا (30 MB)";

  @override
  String get debugPageCreateManyMessagesConversationButton => "إنشاء محادثة من 1024 رسالة";

  @override
  String get debugPageCreateDailyMixedMarkdownConversationButton => "إنشاء 3000 رسالة يومية بتنسيق Markdown متنوع";

  @override
  String get debugPageCreateLongReasoningConversationButton => "إنشاء محادثة بتفكير طويل (128 رسالة)";

  @override
  String get debugPageCreatingButton => "جارٍ الإنشاء…";

  @override
  String get debugPageCreatingOversizedConversation => "جارٍ إنشاء محادثة كبيرة جدًا بحجم 30 MB…";

  @override
  String get debugPageCreatingManyMessagesConversation => "جارٍ إنشاء محادثة من 1024 رسالة…";

  @override
  String get debugPageCreatingDailyMixedMarkdownConversation => "جارٍ إنشاء 3000 رسالة يومية بتنسيق Markdown متنوع…";

  @override
  String get debugPageCreatingLongReasoningConversation => "جارٍ إنشاء محادثة اختبار بتفكير طويل…";

  @override
  String get debugPageNoCurrentAssistant => "لا يوجد مساعد حالي. أنشئ مساعدًا أو اختر مساعدًا أولًا.";

  @override
  String debugPageConversationCreated(int count) => "تم إنشاء محادثة تصحيح تضم ${count} رسالة.";

  @override
  String debugPageCreateConversationFailed(String error) => "فشل إنشاء محادثة التصحيح: ${error}";

  @override
  String debugPageOversizedConversationTitle(int sizeMB) => "اختبار محادثة كبيرة جدًا (${sizeMB} MB)";

  @override
  String debugPageManyMessagesConversationTitle(int count) => "اختبار محادثة من ${count} رسالة";

  @override
  String debugPageDailyMixedMarkdownConversationTitle(int count) => "اختبار ${count} رسالة يومية بتنسيق Markdown متنوع";

  @override
  String debugPageLongReasoningConversationTitle(int count) => "اختبار تفكير طويل من ${count} رسالة";

  @override
  String get debugPageOversizedConversationSeedText => "هذا نص تصحيح طويل لإعادة إنتاج بطء العرض في المحادثات كبيرة الحجم. يتضمن نصًا شبيهًا بتنسيق Markdown وعلامات ترقيم ومحتوى صينيًا ويابانيًا وكوريًا وكلمات عادية، حتى يمكن قياس أداء عرض المحادثة والتخزين والتمرير.";

  @override
  String debugPageManyMessagesSeedText(String role, int index) => "رسالة ${role} رقم #${index}: عينة تصحيح عشوائية سريعة لاختبار عرض القوائم وثبات التمرير وتجميع الرسائل وأداء سجل المحادثة.";

  @override
  String get migrationIntroTitle => "ترقية تخزين المحادثات";

  @override
  String get migrationIntroSubtitle => "ينقل Kelivo سجل المحادثات إلى قاعدة بيانات SQLite أسرع. تتم الترقية قبل فتح التطبيق للحفاظ على اتساق بياناتك.";

  @override
  String get migrationBackupNote => "قبل بدء الترحيل، يصدر Kelivo نسخة احتياطية ZIP تحتوي على الإعدادات وسجل المحادثات والملفات المحلية.";

  @override
  String get migrationPerformanceNote => "بعد الترحيل، تستخدم عملية بدء التشغيل وتحميل السجل والبحث فهارس SQLite لتحسين الأداء في المحادثات الطويلة.";

  @override
  String get migrationChooseFolderButton => "اختيار مجلد وإنشاء نسخة احتياطية";

  @override
  String get migrationSaveBackupButton => "حفظ نسخة ZIP احتياطية";

  @override
  String get migrationStartWithoutBackupButton => "الترحيل دون إنشاء نسخة احتياطية";

  @override
  String get migrationSkipChatsJsonOption => "تخطي chats.json";

  @override
  String get migrationSkipChatsJsonDescription => "ستظل ملفات Hive الأصلية والإعدادات والملفات المحلية ضمن النسخة الاحتياطية. يُنصح بهذا الخيار لسجلات المحادثات الضخمة.";

  @override
  String get migrationSkipBackupOption => "تخطي هذه النسخة الاحتياطية";

  @override
  String get migrationSkipBackupDescription => "اختر هذا الخيار فقط إذا كان لديك بالفعل نسخة احتياطية تم التحقق منها. سيبدأ الترحيل فورًا.";

  @override
  String get migrationBackingUpTitle => "إنشاء نسخة احتياطية";

  @override
  String get migrationBackingUpSubtitle => "جارٍ تصدير الإعدادات وسجل المحادثات والملفات المرفوعة والصور والخطوط. أبقِ Kelivo مفتوحًا حتى اكتمال العملية.";

  @override
  String get migrationMigratingTitle => "الترحيل إلى SQLite";

  @override
  String get migrationMigratingSubtitle => "تتم كتابة المحادثات والرسائل على دفعات حتى لا تتسبب السجلات الكبيرة في استهلاك الذاكرة. أبقِ Kelivo في المقدمة حتى يكتمل الترحيل.";

  @override
  String migrationBackingUpDetail(String fileName) => "جارٍ نسخ ${fileName} احتياطيًا";

  @override
  String migrationMigratingDetail(int count) => "تم ترحيل ${count} رسالة";

  @override
  String get migrationMigratingPrepareDetail => "جارٍ تجهيز قاعدة بيانات SQLite";

  @override
  String get migrationMigratingToolEventsDetail => "جارٍ ترحيل سجلات الأدوات";

  @override
  String get migrationMigratingValidateDetail => "جارٍ التحقق من البيانات التي تم ترحيلها";

  @override
  String get migrationBackupReadyDetail => "ملف النسخة الاحتياطية ZIP جاهز";

  @override
  String get migrationSavingBackupZipDetail => "جارٍ حفظ النسخة الاحتياطية ZIP";

  @override
  String get migrationBackupFileSavedTitle => "تم حفظ ملف النسخة الاحتياطية ZIP";

  @override
  String get migrationChecklistBackupFiles => "تصدير نسخة Hive الاحتياطية ZIP";

  @override
  String get migrationChecklistPrepareSqlite => "تجهيز قاعدة بيانات SQLite";

  @override
  String get migrationChecklistMigrateMessages => "ترحيل المحادثات والرسائل";

  @override
  String get migrationChecklistMigrateToolEvents => "ترحيل سجلات الأدوات";

  @override
  String get migrationChecklistValidate => "التحقق من البيانات التي تم ترحيلها";

  @override
  String get migrationStepBackup => "نسخ احتياطي";

  @override
  String get migrationStepMigrate => "ترحيل";

  @override
  String get migrationStepComplete => "اكتمل";

  @override
  String get migrationCompleteTitle => "اكتملت الترقية";

  @override
  String get migrationCompleteSubtitle => "أصبح سجل محادثاتك محفوظًا في SQLite. أعد تشغيل Kelivo للدخول إلى التطبيق بعد الترقية.";

  @override
  String get migrationConversationCount => "المحادثات";

  @override
  String get migrationMessageCount => "الرسائل";

  @override
  String get migrationConvertedCount => "تم التحويل";

  @override
  String get migrationMalformedCount => "بيانات غير سليمة";

  @override
  String get migrationMissingFilesCount => "ملفات مفقودة";

  @override
  String get migrationRestartButton => "إعادة تشغيل Kelivo";

  @override
  String get migrationFailedTitle => "فشل الترحيل";

  @override
  String get migrationFailedSubtitle => "لا تزال بيانات Hive الأصلية سليمة. ولم تتغير أي نسخة احتياطية اكتمل إنشاؤها سابقًا. راجع سبب الفشل أدناه ثم حاول مجددًا.";

  @override
  String get migrationUnknownError => "خطأ غير معروف أثناء الترحيل.";

  @override
  String get migrationFailureLogTitle => "سجل الفشل";

  @override
  String get migrationRetryButton => "إعادة محاولة الترحيل";

  @override
  String get migrationSkipButton => "تخطي الترحيل والبدء من جديد";

  @override
  String get migrationSkipDialogTitle => "تخطي الترحيل؟";

  @override
  String get migrationSkipDialogMessage => "سيبدأ Kelivo بقاعدة بيانات محادثات فارغة. سيبقى سجل محادثاتك القديم على القرص (مع تغيير اسمه وإضافة اللاحقة .retired إليه)، لكنه لن يُرحّل ولن يظهر في التطبيق. استخدم ملف ZIP الاحتياطي إذا احتجت إلى استعادته لاحقًا.";

  @override
  String get migrationSkipDialogCancel => "إلغاء";

  @override
  String get migrationSkipDialogConfirm => "تخطّي والبدء من جديد";

  @override
  String get migrationChatsExportDegradedNote => "تم تخطي تصدير chats.json بسبب خطأ. لا يزال ملف ZIP الاحتياطي يحتوي على ملفات Hive الخام وسجل محادثاتك كاملًا.";

  @override
  String get timelineJumpToLatest => "الانتقال إلى الأحدث";

  @override
  String largeContentShowMore(int count) => "عرض ${count} إضافية";

  @override
  String get largeContentCollapse => "طي";

  @override
  String get imageSettingsPageTitle => "معالجة الصور";

  @override
  String get imageSettingsPageEditSectionTitle => "التحرير";

  @override
  String get imageSettingsPageQualitySectionTitle => "جودة الصور عند الرفع";

  @override
  String get imageSettingsPageQualityOriginal => "الأصلية";

  @override
  String get imageSettingsPageQualityOriginalSubtitle => "دون ضغط؛ ارفع الصورة كما هي.";

  @override
  String get imageSettingsPageQualityHigh => "جودة عالية";

  @override
  String get imageSettingsPageQualityHighSubtitle => "الضلع الأطول 2048 بكسل · الجودة 90";

  @override
  String get imageSettingsPageQualityBalanced => "متوازنة";

  @override
  String get imageSettingsPageQualityBalancedSubtitle => "الضلع الأطول 1568 بكسل · الجودة 85";

  @override
  String get imageSettingsPageQualitySaver => "توفير البيانات";

  @override
  String get imageSettingsPageQualitySaverSubtitle => "الضلع الأطول 1024 بكسل · الجودة 70";

  @override
  String get imageSettingsPageQualityCustom => "مخصص";

  @override
  String get imageSettingsPageQualityCustomSubtitle => "اختر جودة ضغط الصور";

  @override
  String get imageSettingsPageCustomQualityTitle => "جودة الضغط";

  @override
  String get imageSettingsPageCompressTransparentTitle => "ضغط الصور الشفافة والمتحركة";

  @override
  String get imageSettingsPageCompressTransparentSubtitle => "عند التفعيل، تُضغط ملفات PNG وGIF والتنسيقات المشابهة ذات الشفافية؛ وتتحول المناطق الشفافة إلى اللون الأبيض، ولا يُحتفظ في الصور المتحركة إلا بالإطار الأول.";

  @override
  String get imageSettingsPageFooter => "يحدث الضغط عند إضافة الصور. ولا تتأثر الصور المحفوظة أو المرسلة سابقًا. وتُرسل الصور المضغوطة بصيغة JPEG.";

  @override
  String get imageSettingsPageSendSectionTitle => "الإرسال";

  @override
  String get imageSettingsPageMarkdownImageLinksTitle => "إرسال روابط صور Markdown كصور";

  @override
  String get imageSettingsPageMarkdownImageLinksSubtitle => "عند التفعيل، يُرسل رابط من نمط ![alt](url) في نص رسالتك إلى نماذج الرؤية كصورة. وعند إيقاف الخيار يبقى نصًا عاديًا. أما الصور التي ترفقها بنفسك فتُرسل دائمًا كصور.";

  @override
  String get memoryTraceSettingsTitle => "تتبّع مسار الذاكرة";

  @override
  String get memoryTraceSettingsSubtitle => "فحص كل تشغيل خلفي لمعالجة الذاكرة خطوة بخطوة";

  @override
  String get memoryTracePageTitle => "سجلات مسار معالجة الذاكرة";

  @override
  String get memoryTraceRecordingSection => "التسجيل";

  @override
  String get memoryTraceToggleTitle => "تسجيل تتبّع المسار";

  @override
  String get memoryTraceToggleSubtitle => "الاحتفاظ مؤقتًا في الذاكرة فقط بالتعليمات والردود والتغييرات الخاصة بعمليات التشغيل الخلفية الأخيرة";

  @override
  String get memoryTraceRunsSection => "عمليات التشغيل الأخيرة";

  @override
  String get memoryTraceEmptyTitle => "لا توجد سجلات تتبّع بعد";

  @override
  String get memoryTraceEmptySubtitle => "ستظهر السجلات هنا بعد تشغيل مسار معالجة الذاكرة في الخلفية.";

  @override
  String get memoryTraceDisabledTitle => "التسجيل متوقف";

  @override
  String get memoryTraceDisabledSubtitle => "فعّل التسجيل لالتقاط عملية معالجة الذاكرة التالية في الخلفية.";

  @override
  String get memoryTraceClearAction => "مسح";

  @override
  String get memoryTraceClearSheetTitle => "مسح سجلات التتبّع";

  @override
  String get memoryTraceClearSheetMessage => "سيؤدي هذا إلى إزالة جميع سجلات التتبّع المسجلة. لا تُكتب هذه السجلات على القرص، لذلك لن يتأثر أي شيء آخر.";

  @override
  String get memoryTraceClearConfirm => "مسح سجلات التتبّع";

  @override
  String get memoryTraceCancel => "إلغاء";

  @override
  String get memoryTraceClearedToast => "تم مسح سجلات التتبّع";

  @override
  String get memoryTraceCopyAction => "نسخ";

  @override
  String get memoryTraceCopiedToast => "تم النسخ إلى الحافظة";

  @override
  String get memoryTraceTriggerAuto => "تلقائي";

  @override
  String get memoryTraceTriggerManual => "يدوي";

  @override
  String get memoryTraceTriggerTool => "استدعاء أداة";

  @override
  String get memoryTraceTriggerSummary => "ملخص";

  @override
  String get memoryTraceScopeAssistant => "المساعد";

  @override
  String get memoryTraceScopeGlobal => "عام";

  @override
  String get memoryTraceStepGatekeeper => "التحقق الأولي";

  @override
  String get memoryTraceStepExtract => "استخراج";

  @override
  String get memoryTraceStepSmartAdd => "إضافة ذكية";

  @override
  String get memoryTraceStepDistiller => "استخلاص الملف الشخصي";

  @override
  String get memoryTraceStepSummary => "ملخص المحادثة";

  @override
  String get memoryTraceStepChatSearch => "استرجاع المحادثات السابقة";

  @override
  String get memoryTraceStepTool => "أداة الذاكرة";

  @override
  String get memoryTraceStatusSuccess => "ناجح";

  @override
  String get memoryTraceStatusFailed => "فشل";

  @override
  String get memoryTraceStatusSkipped => "تم التخطي";

  @override
  String get memoryTraceStatusRunning => "قيد التشغيل";

  @override
  String get memoryTraceOutcomeAdvanced => "تم تقديم علامة التقدم";

  @override
  String get memoryTraceOutcomeHeld => "تم الاحتفاظ بعلامة التقدم";

  @override
  String get memoryTraceOutcomeForced => "تقديم إجباري";

  @override
  String get memoryTraceDetailTitle => "تفاصيل التتبّع";

  @override
  String get memoryTraceSectionOverview => "نظرة عامة";

  @override
  String get memoryTraceSectionPrompt => "التعليمات";

  @override
  String get memoryTraceSectionResponse => "الاستجابة الخام";

  @override
  String get memoryTraceSectionParsed => "النتيجة المحلّلة";

  @override
  String get memoryTraceSectionMutations => "التغييرات المطبّقة";

  @override
  String get memoryTraceFieldTime => "وقت البدء";

  @override
  String get memoryTraceFieldDuration => "المدة";

  @override
  String get memoryTraceFieldTrigger => "المحفّز";

  @override
  String get memoryTraceFieldScope => "النطاق";

  @override
  String get memoryTraceFieldConversation => "المحادثة";

  @override
  String get memoryTraceFieldAssistant => "المساعد";

  @override
  String get memoryTraceFieldWindow => "النافذة";

  @override
  String get memoryTraceFieldWatermark => "علامة التقدم";

  @override
  String get memoryTraceFieldOutcome => "النتيجة";

  @override
  String get memoryTraceFieldError => "الخطأ";

  @override
  String get memoryTraceMutationCreated => "تم الإنشاء";

  @override
  String get memoryTraceMutationMerged => "تم الدمج";

  @override
  String get memoryTraceMutationEdited => "تم التعديل";

  @override
  String get memoryTraceMutationArchived => "تمت الأرشفة";

  @override
  String get memoryTraceMutationLinked => "تم الربط";

  @override
  String get memoryTraceMutationProfileWritten => "تمت كتابة حقل في الملف الشخصي";

  @override
  String get memoryTraceMutationProfileCleared => "تم مسح حقل من الملف الشخصي";

  @override
  String get memoryTraceMutationSummary => "تم حفظ ملخص المحادثة";

  @override
  String get memoryTraceBefore => "قبل";

  @override
  String get memoryTraceAfter => "بعد";

  @override
  String get memoryTraceEmptyValue => "(فارغ)";

  @override
  String memoryTraceStepsCount(int count) => "${count} من الخطوات";

  @override
  String memoryTraceMutationsCount(int count) => "${count} من التغييرات";

  @override
  String memoryTraceRepeatCount(int count) => "مكرر ${count} مرة";

  @override
  String memoryTraceWindowValue(int size, int start, int end) => "${size} من الرسائل · #${start}–#${end}";

  @override
  String get memoryTraceShowMore => "عرض النص كاملًا";

  @override
  String get memoryTraceShowLess => "طيّ";

  @override
  String get messageStyleSettingsPageTitle => "نمط الرسائل";

  @override
  String get messageStyleSettingsPageReset => "إعادة تعيين";

  @override
  String get messageStyleSettingsPageResetConfirm => "هل تريد إعادة تعيين جميع تخصيصات نمط الرسائل؟";

  @override
  String get messageStyleSettingsPageCancel => "إلغاء";

  @override
  String get messageStyleSettingsPageLight => "فاتح";

  @override
  String get messageStyleSettingsPageDark => "داكن";

  @override
  String get messageStyleSettingsPageDefaultHint => "يتبع النمط الافتراضي السمة الحالية ولا يحتوي على عناصر تحكم إضافية.";

  @override
  String get messageStyleSettingsPageStyleDefaultSubtitle => "يتبع السمة ولا يقبل التخصيص";

  @override
  String get messageStyleSettingsPageAssistantFitContent => "ملاءمة فقاعة المساعد للمحتوى";

  @override
  String get messageStyleSettingsPageAssistantFitContentSubtitle => "تلتف فقاعات المساعد حول النص بدلًا من ملء الصف بالكامل";

  @override
  String get messageStyleSettingsPageAssistantSplitParagraphs => "تقسيم الفقرات إلى فقاعات";

  @override
  String get messageStyleSettingsPageAssistantSplitParagraphsSubtitle => "تفصل الأسطر الفارغة رد المساعد إلى فقاعة مستقلة لكل فقرة";

  @override
  String get messageStyleSettingsPageStyleFrostedSubtitle => "زجاج مصنفر شبه شفاف";

  @override
  String get messageStyleSettingsPageStyleSolidSubtitle => "تعبئة معتمة بلون ثابت";

  @override
  String get messageStyleSettingsPageBlur => "التمويه";

  @override
  String get messageStyleSettingsPageBlurHint => "يُطبّق التمويه على المحتوى خلف الفقاعة. ويكاد لا يظهر من دون خلفية للمحادثة.";

  @override
  String get messageStyleSettingsPageBackgroundColor => "الخلفية";

  @override
  String get messageStyleSettingsPageBackgroundOpacity => "شفافية الخلفية";

  @override
  String get messageStyleSettingsPageBorderColor => "الحدود";

  @override
  String get messageStyleSettingsPageBorderOpacity => "شفافية الحدود";

  @override
  String get messageStyleSettingsPageBorderWidth => "سُمك الحدود";

  @override
  String get messageStyleSettingsPageTextColor => "النص";

  @override
  String get messageStyleSettingsPageCornerRadius => "استدارة الزوايا";

  @override
  String get messageStyleSettingsPagePreviewUser => "هذه رسالة من المستخدم";

  @override
  String get messageStyleSettingsPagePreviewAssistant => "هذا رد من المساعد.";

  @override
  String get messageStyleSettingsPagePreviewThinking => "التفكير";

  @override
  String get messageStyleSettingsPageRoleUser => "المستخدم";

  @override
  String get messageStyleSettingsPageRoleAssistant => "المساعد";

  @override
  String get messageStyleSettingsPageRoleAssistantHint => "تنطبق إعدادات المساعد أيضًا على بطاقات التفكير واستدعاء الأدوات والترجمة.";

  @override
  String get localSnapshotSectionTitle => "النسخ المحلية";

  @override
  String get localSnapshotEnabledTitle => "الاحتفاظ بنسخ محلية";

  @override
  String get localSnapshotEnabledSubtitle => "يحفظ Kelivo نسخة من قاعدة بياناته دوريًا على هذا الجهاز، حتى لا تكون هذه النسخة الوحيدة.";

  @override
  String get localSnapshotIntervalTitle => "وتيرة الحفظ";

  @override
  String get localSnapshotIntervalAutomatic => "تلقائي";

  @override
  String get localSnapshotIntervalAutomaticDetail => "يوميًا، وبوتيرة أقل كلما كبرت قاعدة البيانات";

  @override
  String localSnapshotIntervalDays(int days) => (days == 1 ? "كل يوم" : intl.Intl.pluralLogic(days, locale: localeName, two: "كل يومين", few: "كل ${days} أيام", many: "كل ${days} يومًا", other: "كل ${days} يوم"));

  @override
  String get localSnapshotKeepTitle => "عدد النسخ التي سيتم الاحتفاظ بها";

  @override
  String localSnapshotKeepValue(int count) => (count == 0 ? "عدم الاحتفاظ بأي نسخة" : (count == 1 ? "نسخة واحدة" : intl.Intl.pluralLogic(count, locale: localeName, two: "نسختان", few: "${count} نسخ", many: "${count} نسخة", other: "${count} نسخة")));

  @override
  String get localSnapshotKeepSubtitle => "بالإضافة إلى نسخة من الأسبوع الماضي وأخرى من الشهر الماضي، حتى يمكن استعادة البيانات عند اكتشاف مشكلة متأخرة.";

  @override
  String get localSnapshotKeepWeekly => "الاحتفاظ بنسخة من الأسبوع الماضي";

  @override
  String get localSnapshotKeepMonthly => "الاحتفاظ بنسخة من الشهر الماضي";

  @override
  String get localSnapshotKeepProtectedNote => "لا تُحذف تلقائيًا أبدًا أحدث نسخة لا تزال تحتوي على بيانات، مهما كان هذا الإعداد.";

  @override
  String get localSnapshotMaximumTitle => "حد المساحة";

  @override
  String get localSnapshotMaximumUnlimited => "بلا حد";

  @override
  String get localSnapshotAnnounceTitle => "إشعار عند حفظ نسخة";

  @override
  String get localSnapshotAnnounceSubtitle => "يتم الإبلاغ عن حالات الفشل دائمًا. يضيف هذا الخيار رسالة موجزة عند النجاح فقط.";

  @override
  String get localSnapshotTakeNow => "حفظ نسخة الآن";

  @override
  String get localSnapshotManageCopies => "إدارة النسخ";

  @override
  String localSnapshotUsage(int count, String size) => (count == 0 ? "لا توجد نسخ" : (count == 1 ? "نسخة واحدة" : intl.Intl.pluralLogic(count, locale: localeName, two: "نسختان", few: "${count} نسخ", many: "${count} نسخة", other: "${count} نسخة"))) + " · ${size}";

  @override
  String get localSnapshotStatusNever => "لم تُحفظ أي نسخة بعد";

  @override
  String localSnapshotStatusSuccess(String when) => "آخر نسخة ${when}";

  @override
  String localSnapshotStatusFailure(String when, String reason) => "فشلت آخر محاولة ${when}: ${reason}";

  @override
  String get localSnapshotStatusSkippedSpace => "تم التخطي: لا توجد مساحة فارغة كافية على هذا الجهاز";

  @override
  String get localSnapshotStatusUnchanged => "لم يتغير شيء منذ النسخة الأخيرة";

  @override
  String get localSnapshotCopiesTitle => "النسخ المحلية";

  @override
  String get localSnapshotCopiesEmpty => "لا توجد نسخ محلية بعد";

  @override
  String get localSnapshotCopiesEmptyHint => "تُحفظ نسخة تلقائيًا عند تغيّر بياناتك، وتُحفظ نسخة دائمًا قبل الاستعادة.";

  @override
  String get localSnapshotCopiesScopeNote => "توجد النسخ المحلية على هذا الجهاز فقط. وهي تحمي من تلف بياناتك داخل التطبيق، لكنها لا تحمي من فقدان الجهاز أو إلغاء تثبيت Kelivo؛ استخدم WebDAV أو النسخ الاحتياطي عبر S3 لذلك.";

  @override
  String get localSnapshotOriginAutomatic => "تلقائي";

  @override
  String get localSnapshotOriginManual => "حفظتها يدويًا";

  @override
  String get localSnapshotOriginBeforeRestore => "قبل الاستعادة";

  @override
  String get localSnapshotKindRecovered => "تم عزلها بواسطة الاسترداد";

  @override
  String localSnapshotCopyContents(int conversations, int messages) => (conversations == 0 ? "لا توجد محادثات" : (conversations == 1 ? "محادثة واحدة" : intl.Intl.pluralLogic(conversations, locale: localeName, two: "محادثتان", few: "${conversations} محادثات", many: "${conversations} محادثة", other: "${conversations} محادثة"))) + " · " + (messages == 0 ? "لا توجد رسائل" : (messages == 1 ? "رسالة واحدة" : intl.Intl.pluralLogic(messages, locale: localeName, two: "رسالتان", few: "${messages} رسائل", many: "${messages} رسالة", other: "${messages} رسالة")));

  @override
  String get localSnapshotCopyContentsUnknown => "المحتويات غير معروفة حتى تتم الاستعادة";

  @override
  String get localSnapshotCopyPinned => "محتفظ بها";

  @override
  String get localSnapshotActionRestore => "استعادة";

  @override
  String get localSnapshotActionExport => "تصدير";

  @override
  String get localSnapshotActionDelete => "حذف";

  @override
  String get localSnapshotActionPin => "الاحتفاظ بهذه النسخة";

  @override
  String get localSnapshotActionUnpin => "إيقاف الاحتفاظ";

  @override
  String get localSnapshotRestoreTitle => "هل تريد استعادة هذه النسخة؟";

  @override
  String localSnapshotRestoreMessage(String when) => "سيتم استبدال محادثاتك وإعداداتك الحالية بهذه النسخة من ${when}. تُحفظ نسخة من المحادثات والإعدادات الحالية أولًا. ولا تُضمّن المسودات غير المرسلة في النسخ، وسيتم مسحها.";

  @override
  String get localSnapshotRestorePreparing => "جارٍ تجهيز النسخة للاستعادة";

  @override
  String get localSnapshotDeleteTitle => "حذف هذه النسخة؟";

  @override
  String get localSnapshotDeleteMessage => "ستتم إزالة هذه النسخة من الجهاز نهائيًا. وستُفقد أي بيانات تحتوي عليها وغير موجودة في قاعدة بياناتك الحالية.";

  @override
  String get localSnapshotDeleteLastWarning => "هذه هي النسخة الوحيدة التي لا تزال تحتوي على بيانات.";

  @override
  String get localSnapshotExportPreparing => "جارٍ تجهيز التصدير";

  @override
  String get localSnapshotExportDone => "تم تصدير النسخة";

  @override
  String localSnapshotExportFailed(String reason) => "تعذّر تصدير النسخة: ${reason}";

  @override
  String get localSnapshotTakeDone => "تم حفظ النسخة";

  @override
  String localSnapshotTakeFailed(String reason) => "تعذّر حفظ النسخة: ${reason}";

  @override
  String get localSnapshotDeleteDone => "تم حذف النسخة";

  @override
  String get localSnapshotBusyMessage => "توجد مهمة نسخ احتياطي أخرى قيد التشغيل بالفعل.";

  @override
  String get localSnapshotRunInBackground => "المتابعة في الخلفية";

  @override
  String get localSnapshotRunningInBackground => "جارٍ حفظ نسخة في الخلفية";

  @override
  String startupRecoveryLocalCopiesAvailable(int count, String when) => "يحتفظ هذا الجهاز بـ ${count} نسخة محلية؛ أحدثها بتاريخ ${when}. لن تؤدي إعادة الضبط إلى حذفها — ويمكنك بعد إعادة التشغيل استعادة نسخة من الإعدادات › النسخ الاحتياطي › النسخ المحلية.";

  @override
  String startupRecoveryRecoveredCopiesDeleted(int count) => "ما زال على هذا الجهاز عدد من نسخ قاعدة البيانات التي عزلها إصلاح سابق (${count}). ستؤدي إعادة الضبط إلى حذفها نهائيًا. صدّر بياناتك أولًا إذا أردت الاحتفاظ بها.";

  @override
  String get toolSchemaSettingsPageTitle => "أوصاف الأدوات";

  @override
  String get toolSchemaSettingsGroupSearch => "البحث";

  @override
  String get toolSchemaSettingsGroupMemory => "الذاكرة";

  @override
  String get toolSchemaSettingsGroupLocal => "أدوات الجهاز";

  @override
  String get toolSchemaSettingsModified => "معدّل";

  @override
  String get toolSchemaSettingsResetDefault => "استعادة الافتراضي";

  @override
  String get toolSchemaSettingsResetAll => "استعادة جميع الإعدادات الافتراضية";

  @override
  String get toolSchemaSettingsResetAllTitle => "استعادة جميع الإعدادات الافتراضية؟";

  @override
  String get toolSchemaSettingsResetAllMessage => "سيؤدي ذلك إلى استعادة أوصاف جميع الأدوات المدمجة إلى إعدادات التطبيق الافتراضية. ستفقد الصياغة المخصصة التي أدخلتها.";

  @override
  String get toolSchemaSettingsResetAllConfirm => "استعادة";

  @override
  String toolSchemaSettingsParamDescriptions(int count) => "أوصاف المعاملات (${count})";

  @override
  String get toolSchemaSettingsMemoryLangNote => "تتبع أوصاف أدوات الذاكرة الافتراضية لغة تعليمات الذاكرة. يُحفظ الوصف المخصص مرة واحدة لكل أداة، ولن يتغير عند تغيير تلك اللغة.";

  @override
  String get toolSchemaSettingsDescriptionLabel => "الوصف";

  @override
  String get toolSchemaSettingsToolName => "اسم الأداة";

  @override
  String get toolSchemaEditorPageTitle => "تعديل الوصف";

  @override
  String get toolSchemaSettingsCancel => "إلغاء";

  @override
  String get workspaceFileNotAvailable => "الملف غير متاح";

  @override
  String get workspaceTerminalNotAvailable => "الطرفية غير متاحة";

  @override
  String get workspacePreviewCopyPath => "نسخ المسار";

  @override
  String get workspacePreviewShare => "مشاركة";

  @override
  String get workspacePreviewOpenExternally => "فتح في تطبيق خارجي";

  @override
  String get workspacePreviewOpenWith => "فتح باستخدام…";

  @override
  String get workspacePreviewFileTooLarge => "هذا الملف كبير جدًا لمعاينته. افتحه باستخدام تطبيق خارجي بدلًا من ذلك.";

  @override
  String get workspacePreviewSource => "المصدر";

  @override
  String get workspacePreviewRendered => "المعاينة المنسّقة";

  @override
  String get workspacePreviewFileName => "الاسم";

  @override
  String get workspacePreviewFileSize => "الحجم";

  @override
  String get workspacePreviewFileModified => "آخر تعديل";

  @override
  String get workspacePreviewPathCopied => "تم نسخ المسار";

  @override
  String workspacePreviewLineCount(int count) => "${count} سطرًا";

  @override
  String get workspaceFilesSort => "ترتيب حسب";

  @override
  String get workspaceFilesSortName => "الاسم";

  @override
  String get workspaceFilesSortModified => "تاريخ التعديل";

  @override
  String get workspaceFilesSortSize => "الحجم";

  @override
  String get workspaceFilesSortAscending => "تصاعدي";

  @override
  String get workspaceFilesSortDescending => "تنازلي";

  @override
  String get workspaceFilesShowHidden => "إظهار الملفات المخفية";

  @override
  String get workspaceFilesHideHidden => "إخفاء الملفات المخفية";

  @override
  String get workspaceFilesRefresh => "تحديث";

  @override
  String get workspaceFilesNewFolder => "مجلد جديد";

  @override
  String get workspaceFilesNewFile => "ملف جديد";

  @override
  String get workspaceFilesImport => "استيراد";

  @override
  String get workspaceFilesExport => "تصدير";

  @override
  String get workspaceFilesExportFolder => "تصدير المجلد";

  @override
  String get workspaceFilesEmpty => "هذا المجلد فارغ";

  @override
  String get workspaceFilesError => "تعذّر تحميل هذه الملفات.";

  @override
  String get workspaceFilesRetry => "إعادة المحاولة";

  @override
  String get workspaceFilesPreview => "معاينة";

  @override
  String get workspaceFilesRename => "إعادة تسمية";

  @override
  String get workspaceFilesMove => "نقل";

  @override
  String get workspaceFilesDelete => "حذف";

  @override
  String get workspaceFilesShare => "مشاركة";

  @override
  String get workspaceFilesCopyPath => "نسخ المسار";

  @override
  String get workspaceFilesExportItem => "تصدير";

  @override
  String get workspaceFilesNameLabel => "الاسم";

  @override
  String get workspaceFilesNameHint => "أدخل اسمًا";

  @override
  String get workspaceFilesCreate => "إنشاء";

  @override
  String get workspaceFilesCancel => "إلغاء";

  @override
  String get workspaceFilesConfirm => "تأكيد";

  @override
  String get workspaceFilesSave => "حفظ";

  @override
  String get workspaceFilesDeleteTitle => "حذف هذا العنصر؟";

  @override
  String workspaceFilesDeleteMessage(String name) => "هل تريد حذف ${name}؟";

  @override
  String workspaceFilesDeleteFolderMessage(String name) => "هل تريد حذف المجلد ${name} وكل ما بداخله؟";

  @override
  String get workspaceFilesMoveTitle => "نقل إلى مجلد";

  @override
  String get workspaceFilesMoveHere => "النقل إلى هنا";

  @override
  String get workspaceFilesPathCopied => "تم نسخ المسار";

  @override
  String get workspaceFilesInvalidName => "هذا الاسم غير صالح.";

  @override
  String get workspaceFilesInvalidPath => "هذا المسار خارج هذا المجلد.";

  @override
  String workspaceFilesOperationFailed(String error) => "تعذّر إكمال هذا الإجراء: ${error}";

  @override
  String get workspaceFilesActions => "الإجراءات";

  @override
  String get workspaceFilesMore => "المزيد";

  @override
  String get workspaceFilesJustNow => "الآن";

  @override
  String workspaceFilesMinutesAgo(int count) => "قبل ${count} د";

  @override
  String workspaceFilesHoursAgo(int count) => "قبل ${count} س";

  @override
  String workspaceFilesDaysAgo(int count) => "قبل ${count} يوم";

  @override
  String get workspaceFilesPanelTitle => "ملفات المحادثة";

  @override
  String get workspaceFilesTabAttachments => "المرفقات";

  @override
  String get workspaceFilesTabOutputs => "المخرجات";

  @override
  String get workspaceFilesTabWorkspace => "مساحة العمل";

  @override
  String get workspaceFilesNoWorkspaceBound => "لا توجد مساحة عمل مرتبطة";

  @override
  String get workspaceFilesKindManaged => "مُدار";

  @override
  String get workspaceFilesKindLinked => "مرتبط";

  @override
  String get workspaceFilesMissingWorkspace => "لم يتم العثور على مساحة العمل";

  @override
  String get workspaceFilesClose => "إغلاق";

  @override
  String get workspacesTitle => "مساحات العمل";

  @override
  String get workspacesCreate => "إنشاء";

  @override
  String get workspacesCreateTitle => "مساحة عمل جديدة";

  @override
  String get workspacesNameLabel => "الاسم";

  @override
  String get workspacesNameHint => "اسم مساحة العمل";

  @override
  String get workspacesLinkFolder => "ربط مجلد";

  @override
  String get workspacesEmpty => "لا توجد مساحات عمل بعد.";

  @override
  String get workspacesEmptyCta => "إنشاء مساحة عمل";

  @override
  String get workspacesSettings => "الإعدادات";

  @override
  String get workspacesOpenFiles => "فتح الملفات";

  @override
  String get workspacesLastUsedNever => "لم تُستخدم من قبل";

  @override
  String workspacesLastUsed(String when) => "آخر استخدام: ${when}";

  @override
  String get workspacesDeleteTitle => "حذف مساحة العمل؟";

  @override
  String workspacesDeleteMessage(String name) => "هل تريد حذف مساحة العمل ${name}؟";

  @override
  String get workspacesDeleteAlsoFiles => "حذف الملفات أيضًا";

  @override
  String get workspacesUnlinkTitle => "إلغاء ربط مساحة العمل؟";

  @override
  String workspacesUnlinkMessage(String name) => "هل تريد إلغاء ربط ${name}؟ ستبقى الملفات على القرص.";

  @override
  String get workspacesSettingsTitle => "إعدادات مساحة العمل";

  @override
  String get workspacesShellNeedsApproval => "طلب الموافقة قبل تشغيل أوامر Shell";

  @override
  String get workspacesDefaultCwd => "مجلد العمل الافتراضي";

  @override
  String get workspacesDefaultCwdHint => "مسار نسبي، مثل src";

  @override
  String get workspacesDefaultCwdInvalid => "استخدم مسارًا نسبيًا لا يحتوي على ..";

  @override
  String get workspacesCreateManaged => "إنشاء مساحة عمل";

  @override
  String get workspacesLinkExisting => "ربط مجلد موجود";

  @override
  String get workspacesUnlink => "إلغاء الربط";

  @override
  String get workspacesItemMore => "إجراءات مساحة العمل";

  @override
  String get workspaceToolDenied => "مرفوض";

  @override
  String get workspaceToolTimeout => "انتهت المهلة";

  @override
  String get workspaceToolCancelled => "تم الإلغاء";

  @override
  String get workspaceToolInterrupted => "تمت المقاطعة";

  @override
  String get workspaceToolEnvironmentNotReady => "لم يتم تثبيت بيئة العزل";

  @override
  String get workspaceToolInstall => "تثبيت";

  @override
  String get workspaceToolFuzzy => "تقريبي";

  @override
  String get workspaceToolCreated => "تم الإنشاء";

  @override
  String get workspaceToolUpdated => "تم التحديث";

  @override
  String get workspaceToolTruncated => "تم الاقتطاع";

  @override
  String get workspaceToolImageTag => "صورة";

  @override
  String get workspaceToolStdout => "الإخراج القياسي (stdout)";

  @override
  String get workspaceToolStderr => "إخراج الأخطاء (stderr)";

  @override
  String get workspaceToolOpenFullOutput => "فتح الإخراج الكامل";

  @override
  String get workspaceToolChangedFiles => "الملفات المعدّلة";

  @override
  String get workspaceToolCancel => "إلغاء";

  @override
  String get workspaceToolCopyCommand => "نسخ الأمر";

  @override
  String get workspaceToolCopyOutput => "نسخ الإخراج";

  @override
  String get workspaceToolCopyDiff => "نسخ الفروقات";

  @override
  String get workspaceToolCopied => "تم النسخ";

  @override
  String get workspaceToolDiffTruncated => "تم اقتطاع الفرق";

  @override
  String get workspaceToolOpenPreview => "فتح المعاينة";

  @override
  String get workspaceToolNoOutput => "لا توجد مخرجات";

  @override
  String get workspaceToolNotAvailable => "غير متاح";

  @override
  String get workspaceToolClose => "إغلاق";

  @override
  String get workspaceToolTitleShell => "تنفيذ أمر";

  @override
  String get workspaceToolTitleReadFile => "قراءة ملف";

  @override
  String get workspaceToolTitleViewImage => "عرض صورة";

  @override
  String get workspaceToolTitleWriteFile => "كتابة ملف";

  @override
  String get workspaceToolTitleEditFile => "تعديل ملف";

  @override
  String get workspaceToolTitleListDir => "عرض محتويات المجلد";

  @override
  String get workspaceToolTitleGlob => "مطابقة أنماط الملفات";

  @override
  String get workspaceToolTitleGrep => "البحث داخل الملفات";

  @override
  String workspaceToolCount(int count) => "عدد الأدوات: ${count}";

  @override
  String workspaceToolMoreFiles(int count) => "+${count} ملفات أخرى";

  @override
  String workspaceToolDurationMs(int ms) => "${ms} مللي ثانية";

  @override
  String workspaceToolDurationSec(String sec) => "${sec} ثانية";

  @override
  String get workspaceEnvTitle => "البيئة";

  @override
  String workspaceEnvEngineUbuntu(String version) => "Ubuntu ${version} (بيئة PRoot)";

  @override
  String workspaceEnvEngineAlpine(String version) => "Alpine ${version} (بيئة iSH)";

  @override
  String get workspaceEnvEngineNative => "الطرفية الأصلية";

  @override
  String get workspaceEnvPhaseNotInstalled => "غير مثبّت";

  @override
  String get workspaceEnvPhaseDownloading => "جارٍ التنزيل";

  @override
  String get workspaceEnvPhaseVerifying => "جارٍ التحقق";

  @override
  String get workspaceEnvPhaseExtracting => "جارٍ الاستخراج";

  @override
  String get workspaceEnvPhasePatching => "جارٍ تطبيق التصحيحات";

  @override
  String get workspaceEnvPhaseReady => "جاهز";

  @override
  String get workspaceEnvPhaseError => "خطأ";

  @override
  String get workspaceEnvPhaseNeedsRestart => "تتطلب إعادة التشغيل";

  @override
  String workspaceEnvMetaLine(String version, String arch) => "الإصدار ${version} · البنية ${arch}";

  @override
  String workspaceEnvInstalledAt(String date) => "تاريخ التثبيت: ${date}";

  @override
  String workspaceEnvDiskUsage(String size) => "استخدام القرص: ${size}";

  @override
  String workspaceEnvRuntimeReason(String reason) => "السبب: ${reason}";

  @override
  String get workspaceEnvInstall => "تثبيت";

  @override
  String get workspaceEnvInstallSubtitleAndroid => "اختر Ubuntu أو Alpine أو Debian، أو استورد صورة rootfs محلية.";

  @override
  String get workspaceEnvInstallSubtitleIos => "مضمّن، ولا يتطلب تنزيلًا";

  @override
  String get workspaceEnvCancel => "إلغاء";

  @override
  String get workspaceEnvRetry => "إعادة المحاولة";

  @override
  String get workspaceEnvRepair => "إصلاح";

  @override
  String get workspaceEnvReset => "إعادة تعيين";

  @override
  String get workspaceEnvResetConfirmTitle => "هل تريد إعادة تعيين البيئة؟";

  @override
  String get workspaceEnvResetConfirmBody => "سيؤدي هذا إلى حذف الحزم المثبّتة ونظام ملفات البيئة المعزولة.";

  @override
  String get workspaceEnvCheckForUpdate => "التحقق من وجود تحديث";

  @override
  String get workspaceEnvUpdate => "تحديث";

  @override
  String workspaceEnvAvailableVersion(String version) => "الإصدار ${version} متاح";

  @override
  String get workspaceEnvUpToDate => "لديك أحدث إصدار";

  @override
  String get workspaceEnvRestartBanner => "أعد تشغيل Kelivo لإكمال العملية";

  @override
  String get workspaceEnvDetectingMirrors => "جارٍ اكتشاف أسرع المرايا…";

  @override
  String workspaceEnvApplyingMirror(String category) => "جارٍ تطبيق مرآة ${category}…";

  @override
  String get workspaceEnvMirrorsSection => "مرايا التنزيل";

  @override
  String get workspaceEnvUseMirror => "استخدام المرآة";

  @override
  String get workspaceEnvDetect => "اكتشاف";

  @override
  String get workspaceEnvOfficial => "رسمي";

  @override
  String get workspaceEnvMirrorsDisabled => "تُجرى تغييرات المرايا داخل البيئة المعزولة، ولا تتاح قبل أن تصبح جاهزة.";

  @override
  String workspaceEnvMirrorsDisabledReason(String reason) => "تُجرى تغييرات المرايا داخل البيئة المعزولة، وهي غير متاحة: ${reason}";

  @override
  String get workspaceEnvMirrorDetectTitle => "سرعة المرآة";

  @override
  String workspaceEnvMirrorLatency(int ms) => "${ms} مللي ثانية";

  @override
  String workspaceEnvMirrorFailed(String reason) => "تعذّر استخدام المرآة: ${reason}";

  @override
  String get workspaceEnvErrorUnsupportedAbi => "معمارية هذا الجهاز غير مدعومة.";

  @override
  String get workspaceEnvErrorArchitectureMismatch => "لا تتطابق معمارية البيئة المعزولة المثبّتة مع هذا التطبيق. أعد تثبيت البيئة للمتابعة. تم الاحتفاظ بملفات البيئة الحالية.";

  @override
  String get workspaceEnvErrorProotMissing => "ملف PRoot التنفيذي غير موجود.";

  @override
  String get workspaceEnvErrorInsufficientDisk => "لا توجد مساحة تخزين فارغة كافية لتثبيت البيئة المعزولة.";

  @override
  String get workspaceEnvErrorInsufficientDiskHint => "حرّر مساحة تخزين إضافية لصورة النظام المحددة ثم حاول مرة أخرى.";

  @override
  String get workspaceEnvErrorNetwork => "فشل التنزيل. تحقق من اتصالك وحاول مرة أخرى.";

  @override
  String get workspaceEnvErrorChecksumMismatch => "ملف التنزيل تالف. حاول مرة أخرى.";

  @override
  String get workspaceEnvErrorExtractFailed => "تعذّر استخراج صورة البيئة المعزولة.";

  @override
  String get workspaceEnvErrorCleanupFailed => "تعذّرت إزالة ملفات البيئة القديمة. حاول مرة أخرى.";

  @override
  String get workspaceEnvCleanupIncomplete => "البيئة المعزولة جاهزة، لكن تعذّرت إزالة بعض الملفات القديمة، وما زالت تشغل مساحة تخزين.";

  @override
  String get workspaceEnvErrorResetFailed => "تعذّر إكمال إعادة تعيين البيئة المعزولة. حاول مرة أخرى.";

  @override
  String get workspaceEnvErrorPatchFailed => "تعذّر إكمال إعداد البيئة المعزولة.";

  @override
  String get workspaceEnvErrorCancelled => "تم إلغاء التثبيت.";

  @override
  String get workspaceEnvErrorGeneric => "حدث خطأ ما أثناء تثبيت البيئة المعزولة.";

  @override
  String get workspaceEnvChipInstall => "تثبيت البيئة المعزولة";

  @override
  String workspaceEnvChipInstalling(int percent) => "جارٍ التثبيت… ${percent}٪";

  @override
  String get workspaceEnvChipInstallingIndeterminate => "جارٍ التثبيت…";

  @override
  String get workspaceEnvChipError => "خطأ في البيئة المعزولة";

  @override
  String get workspaceEnvChipRestart => "تتطلب إعادة التشغيل";

  @override
  String get workspaceEnvNativeExplanation => "يستخدم Kelivo على أجهزة سطح المكتب طرفية النظام بدلًا من بيئة Linux معزولة.";

  @override
  String workspaceEnvNativeShellPath(String path) => "الصدفة: ${path}";

  @override
  String get workspaceEnvNativeShellApproval => "تحتاج أداة الطرفية إلى موافقة عند اختيار وضع «طلب الموافقة».";

  @override
  String workspaceEnvDownloadProgress(String downloaded, String total, int percent) => "${downloaded} / ${total} ميجابايت (${percent}%)";

  @override
  String get workspaceEnvMirrorsFailed => "تعذّر اكتشاف المرايا";

  @override
  String get skillsTitle => "المهارات";

  @override
  String get skillsTab => "المهارات";

  @override
  String get skillsSearchHint => "البحث عن المهارات";

  @override
  String get skillsEmptyTitle => "لا توجد مهارات بعد";

  @override
  String get skillsEmptyBody => "المهارة مجلد يحتوي على ملف SKILL.md. استورد ملف Markdown أو ملف .md أو .zip أو رابط GitHub.";

  @override
  String get skillsImport => "استيراد";

  @override
  String get skillsImportPaste => "لصق Markdown";

  @override
  String get skillsImportFile => "من ملف";

  @override
  String get skillsImportGitHub => "من GitHub";

  @override
  String get skillsImportPasteHint => "الصق ملف SKILL.md يحتوي على ترويسة YAML أمامية";

  @override
  String get skillsImportGitHubLabel => "رابط GitHub";

  @override
  String get skillsImportGitHubHint => "github.com/owner/repo أو github.com/owner/repo/tree/ref/path";

  @override
  String get skillsImportConfirm => "استيراد";

  @override
  String get skillsCancel => "إلغاء";

  @override
  String get skillsSave => "حفظ";

  @override
  String skillsUsedCount(int count) => "استُخدمت ${count} مرة";

  @override
  String get skillsEnabled => "مفعّلة";

  @override
  String get skillsBrowseFiles => "استعراض الملفات";

  @override
  String get skillsEdit => "تعديل";

  @override
  String get skillsExport => "تصدير";

  @override
  String get skillsDelete => "حذف";

  @override
  String get skillsDeleteTitle => "هل تريد حذف هذه المهارة؟";

  @override
  String skillsDeleteMessage(String name) => "هل تريد حذف ${name}؟ لا يمكن التراجع عن هذا الإجراء.";

  @override
  String get skillsUseAll => "استخدام جميع المهارات";

  @override
  String get skillsUseAllSubtitle => "تكون كل مهارة مفعّلة متاحة لهذا المساعد.";

  @override
  String get skillsDisabledHint => "فعّل هذه المهارة من صفحة المهارات لاستخدامها هنا.";

  @override
  String get skillsOpenPage => "إدارة المهارات";

  @override
  String get skillsInheritAssistant => "الوراثة من المساعد";

  @override
  String get skillsInheritAssistantSubtitle => "استخدام المهارات نفسها الخاصة بمساعد هذه المحادثة.";

  @override
  String get skillsActiveLabel => "نشطة";

  @override
  String get skillsSessionTitle => "مهارات هذه المحادثة";

  @override
  String get skillsEditTitle => "تعديل المهارة";

  @override
  String get skillsDetailKindLabel => "مهارة";

  @override
  String get skillsNoEnabled => "لا توجد مهارات مفعّلة";

  @override
  String get terminalTitle => "الطرفية";

  @override
  String get terminalOpenInSystem => "فتح في طرفية النظام";

  @override
  String get terminalHostDirectory => "مجلد المضيف";

  @override
  String get terminalBindWorkspaceFirst => "اربط مساحة عمل أولًا";

  @override
  String get terminalNotAvailable => "غير متاح";

  @override
  String get terminalRuntimeUnavailable => "بيئة الطرفية غير جاهزة";

  @override
  String get terminalRename => "إعادة تسمية";

  @override
  String get terminalClose => "إغلاق";

  @override
  String get terminalClear => "مسح";

  @override
  String get terminalCloseSession => "إغلاق الجلسة";

  @override
  String get terminalCopy => "نسخ";

  @override
  String get terminalPaste => "لصق";

  @override
  String get terminalNewSession => "جلسة جديدة";

  @override
  String get terminalMore => "المزيد";

  @override
  String get terminalNameLabel => "الاسم";

  @override
  String get terminalCancel => "إلغاء";

  @override
  String get terminalSave => "حفظ";

  @override
  String get workspaceDeskMenuWorkspace => "مساحة العمل";

  @override
  String get workspaceDeskMenuSkills => "المهارات";

  @override
  String get workspaceDeskBarTitle => "مساحة العمل";

  @override
  String get workspaceDeskBarNoWorkspace => "لا توجد مساحة عمل";

  @override
  String get workspaceDeskBarEmptyHint => "اربط مساحة عمل من شريط الأدوات لاستعراض الملفات هنا";

  @override
  String get workspaceDeskBarToggle => "ملفات مساحة العمل";

  @override
  String get workspaceDeskOpenSystemTerminal => "فتح في طرفية النظام";

  @override
  String get workspaceDeskReveal => "إظهار في مدير الملفات";

  @override
  String get workspaceDeskBarClose => "إغلاق شريط مساحة العمل";

  @override
  String get workspaceEntryBind => "ربط مساحة عمل";

  @override
  String get workspaceEntryUnbind => "إلغاء الربط";

  @override
  String get workspaceEntryChange => "تغيير";

  @override
  String get workspaceEntrySetAssistantDefault => "تعيين كمساحة العمل الافتراضية للمساعد";

  @override
  String get workspaceEntryLocked => "مقفل";

  @override
  String get workspaceEntryChangeConfirmTitle => "تغيير مساحة العمل؟";

  @override
  String get workspaceEntryUnbindConfirmTitle => "إلغاء الربط؟";

  @override
  String get workspaceEntryChangeConfirmBody => "استخدمت هذه المحادثة أدوات مساحة العمل بالفعل. قد لا تعمل روابط الملفات في الرسائل السابقة بعد التغيير.";

  @override
  String get workspaceEntryCwd => "مجلد العمل";

  @override
  String get workspaceEntryCwdHint => "مسار نسبي إلى جذر مساحة العمل";

  @override
  String get workspaceEntryCwdInvalid => "هذا المسار غير صالح أو يخرج عن مساحة العمل.";

  @override
  String get workspaceEntryCwdMissing => "هذا المجلد غير موجود.";

  @override
  String get workspaceEntryCwdCreate => "إنشاؤه";

  @override
  String get workspaceEntryFiles => "الملفات";

  @override
  String get workspaceEntryTerminal => "الطرفية";

  @override
  String get workspaceEntryOpenSystemTerminal => "فتح في طرفية النظام";

  @override
  String get workspaceEntryReveal => "إظهار في مدير الملفات";

  @override
  String get workspaceEntrySessionSkills => "المهارات";

  @override
  String get workspaceEntryEnvironment => "البيئة";

  @override
  String get workspaceEntryManage => "إدارة مساحات العمل";

  @override
  String get workspaceEntryCreate => "إنشاء مساحة عمل جديدة…";

  @override
  String get workspaceEntryDefaultWorkspace => "مساحة العمل الافتراضية";

  @override
  String get workspaceEntryDefaultWorkspaceSubtitle => "ستستخدم المحادثات الجديدة مساحة العمل هذه. لن تتغير المحادثات الحالية.";

  @override
  String get workspaceEntryDefaultWorkspaceUnset => "غير محددة";

  @override
  String get workspaceEntryDefaultWorkspaceAutomaticSubtitle => "سيتم تذكر أول مساحة عمل تربطها بمحادثة لاستخدامها في المحادثات الجديدة.";

  @override
  String workspaceBindingRememberedDefault(String assistant) => "تم حفظها كمساحة العمل الافتراضية لـ \"${assistant}\". ستستخدمها المحادثات الجديدة.";

  @override
  String workspaceBindingSuggestDefault(String assistant) => "هل تريد استخدام مساحة العمل هذه أيضًا في المحادثات المستقبلية مع \"${assistant}\"؟";

  @override
  String get workspaceBindingUndoDefault => "تراجع";

  @override
  String get workspaceBindingUseAsDefault => "تعيين كافتراضية";

  @override
  String get workspaceEntryNone => "لا شيء";

  @override
  String get workspaceEntryStartConversationFirst => "ابدأ محادثة أولًا";

  @override
  String get workspaceEntryTooltip => "مساحة العمل";

  @override
  String get workspaceEntryPickerTitle => "اختيار مساحة عمل";

  @override
  String get settingsPageWorkspace => "مساحة العمل والبيئة";

  @override
  String get settingsPageSkills => "المهارات";

  @override
  String get commonClose => "إغلاق";

  @override
  String get terminalCopyAllOutput => "نسخ الإخراج بالكامل";

  @override
  String get terminalFontDecrease => "تصغير حجم الخط −";

  @override
  String get terminalFontIncrease => "تكبير حجم الخط +";

  @override
  String get terminalCloseSessionConfirmMessage => "لا تزال هذه الجلسة قيد التشغيل. سيؤدي إغلاقها إلى إنهاء العملية.";

  @override
  String get terminalCopiedAll => "تم نسخ الإخراج بالكامل";

  @override
  String get terminalConfirm => "تأكيد";

  @override
  String terminalExitCode(int code) => "رمز الخروج ${code}";

  @override
  String get workspaceMgmtNewWorkspace => "مساحة عمل جديدة";

  @override
  String get workspaceMgmtEmptyHint => "أنشئ مساحة عمل لجمع ملفات المشروع في مكان واحد.";

  @override
  String get workspaceMgmtKindManagedTitle => "مساحة عمل مُدارة";

  @override
  String get workspaceMgmtKindManagedSubtitle => "مجلد يديره التطبيق مع صلاحيات القراءة والكتابة في بيئة العزل.";

  @override
  String get workspaceMgmtKindLinkedTitle => "مجلد مرتبط";

  @override
  String get workspaceMgmtKindLinkedSubtitle => "استخدام مجلد موجود على هذا الكمبيوتر.";

  @override
  String get workspaceMgmtImportFromFolder => "استيراد من مجلد";

  @override
  String get workspaceMgmtImportFromFolderSubtitle => "نسخ مجلد إلى مساحة عمل مُدارة جديدة.";

  @override
  String get workspaceMgmtKindSection => "النوع";

  @override
  String get workspaceMgmtCreate => "إنشاء";

  @override
  String get workspaceMgmtShellApprovalSubtitle => "طلب الموافقة قبل كل أمر";

  @override
  String get workspaceMgmtPickCwdTitle => "مجلد العمل الافتراضي";

  @override
  String get workspaceMgmtFolderPickerUnavailable => "اختيار المجلدات غير متاح.";

  @override
  String get workspaceMgmtImportProgressTitle => "استيراد المجلد";

  @override
  String get workspaceMgmtImportProgressPhase => "جارٍ نسخ الملفات…";

  @override
  String get workspaceMgmtImportFailed => "تعذّر استيراد هذا المجلد.";

  @override
  String workspaceMgmtImportDone(String name) => "تم استيراد ${name}";

  @override
  String get workspaceMgmtLastUsedJustNow => "الآن";

  @override
  String workspaceMgmtLastUsedMinutesAgo(int n) => "قبل ${n} دقيقة";

  @override
  String workspaceMgmtLastUsedHoursAgo(int n) => "قبل ${n} ساعة";

  @override
  String workspaceMgmtLastUsedDaysAgo(int n) => "قبل ${n} يوم";

  @override
  String workspaceMgmtRowDetail(String kind, String when) => "${kind} · آخر استخدام: ${when}";

  @override
  String workspaceMgmtRowDetailNever(String kind) => "${kind} · لم يُستخدم من قبل";

  @override
  String get workspacePreviewBack => "رجوع";

  @override
  String get workspacePreviewWrap => "التفاف الأسطر";

  @override
  String get workspacePreviewFontDecrease => "تصغير النص";

  @override
  String get workspacePreviewFontIncrease => "تكبير النص";

  @override
  String get workspacePreviewCopy => "نسخ";

  @override
  String get workspacePreviewRetry => "إعادة المحاولة";

  @override
  String get workspacePreviewLoadError => "تعذّر تحميل هذا الملف.";

  @override
  String get workspacePreviewRevealInFinder => "إظهار في Finder";

  @override
  String get workspacePreviewOpenInSystemApp => "فتح باستخدام تطبيق النظام";

  @override
  String get workspacePreviewOpenInBrowser => "فتح في المتصفح";

  @override
  String get workspacePreviewTable => "جدول";

  @override
  String get workspacePreviewPlainLanguage => "شيفرة";

  @override
  String get workspacePreviewOpen => "فتح";

  @override
  String get workspacePreviewRevealFailed => "تعذّر إظهار هذا الملف في مدير الملفات.";

  @override
  String get workspacePreviewEmptyTable => "هذا الجدول فارغ.";

  @override
  String get workspaceFilesNew => "جديد";

  @override
  String get workspaceFilesFoldersFirst => "المجلدات أولًا";

  @override
  String get workspaceFilesSelectDirectory => "اختيار هذا المجلد";

  @override
  String get workspaceFilesEmptyHint => "استخدم «جديد» أو «استيراد» لإضافة ملفات.";

  @override
  String get workspaceFilesEmptyAttachments => "لا توجد مرفقات بعد.";

  @override
  String get workspaceFilesEmptyOutputs => "لم يُنشئ المساعد أي ملفات بعد.";

  @override
  String get workspaceFilesMoveTo => "نقل إلى…";

  @override
  String workspaceFilesItemCount(int count) => "عدد العناصر: ${count}";

  @override
  String get skillsImportTooltip => "استيراد مهارة";

  @override
  String get skillsImportPasteSubtitle => "الصق ملف SKILL.md مع ترويسة YAML";

  @override
  String get skillsImportFileSubtitle => "اختر ملف .md أو .zip";

  @override
  String get skillsImportGitHubSubtitle => "استيراد SKILL.md من مستودع";

  @override
  String get skillsImportResolving => "جارٍ تحديد المستودع…";

  @override
  String get skillsImportDownloading => "جارٍ التنزيل…";

  @override
  String get skillsImportExtracting => "جارٍ الاستخراج…";

  @override
  String get skillsImportInstalling => "جارٍ التثبيت…";

  @override
  String get skillsImportGitHubRepoLabel => "رابط المستودع";

  @override
  String get skillsImportGitHubUrlHint => "https://github.com/owner/repo أو owner/repo[/path]";

  @override
  String get skillsImportGitHubHelp => "يمكن استخدام ملف SKILL.md الموجود في جذر المستودع أو في مجلد فرعي.";

  @override
  String get skillsEmptyHint => "المهارة هي ملف SKILL.md يحتوي على ترويسة. بعد استيرادها، يمكن للمساعد استخدامها عند الحاجة.";

  @override
  String get skillsMoreActions => "المزيد من الإجراءات";

  @override
  String get skillsSearchClear => "مسح البحث";

  @override
  String get skillsSessionEmpty => "لا توجد مهارات مفعّلة بعد. فعّل المهارات من المكتبة أولًا.";

  @override
  String get workspaceToolRunning => "قيد التشغيل";

  @override
  String workspaceToolExitCode(int code) => "رمز الخروج ${code}";

  @override
  String get workspaceToolAwaitingApproval => "بانتظار الموافقة";

  @override
  String get workspaceToolCompleted => "مكتمل";

  @override
  String workspaceToolLines(int count) => "${count} سطرًا";

  @override
  String workspaceToolItems(int count) => "${count} عنصرًا";

  @override
  String workspaceToolFileMatches(int count) => "${count} تطابقات";

  @override
  String workspaceToolContentMatches(int count) => "${count} تطابقات";

  @override
  String get workspaceToolExpand => "توسيع";

  @override
  String get workspaceToolSectionCommand => "الأمر";

  @override
  String get workspaceToolSectionPath => "المسار";

  @override
  String get workspaceToolSectionPattern => "النمط";

  @override
  String get workspaceToolSectionOutput => "الإخراج";

  @override
  String get workspaceToolSectionDiff => "الفروقات";

  @override
  String get workspaceToolSectionError => "الخطأ";

  @override
  String get workspaceToolSavedOutput => "تم حفظ الإخراج الكامل";

  @override
  String get workspaceToolApprove => "سماح";

  @override
  String get workspaceToolDeny => "رفض";

  @override
  String get workspaceToolCopy => "نسخ";

  @override
  String get workspaceEnvEngineLocalShell => "طرفية محلية";

  @override
  String get workspaceEnvInstallEnvironment => "تثبيت بيئة";

  @override
  String get workspaceEnvInstallDescription => "تثبيت بيئة Linux لتشغيل الأدوات في مساحة معزولة.";

  @override
  String get workspaceEnvStatusLabel => "الحالة";

  @override
  String get workspaceEnvStatusInstalled => "مثبّت";

  @override
  String get workspaceEnvSizeLabel => "الحجم";

  @override
  String get workspaceEnvPathLabel => "المسار";

  @override
  String get workspaceEnvInstalledAtLabel => "تاريخ التثبيت";

  @override
  String get workspaceEnvArchLabel => "المعمارية";

  @override
  String workspaceEnvArchVersion(String arch, String version) => "البنية ${arch} · الإصدار ${version}";

  @override
  String get workspaceEnvBrowseSection => "استعراض";

  @override
  String get workspaceEnvBrowseFiles => "استعراض نظام الملفات";

  @override
  String get workspaceEnvBrowseFilesDetail => "عرض شجرة المجلدات كاملةً داخل البيئة المعزولة.";

  @override
  String get workspaceEnvDetectFastMirrors => "اكتشاف المرايا الأسرع";

  @override
  @override
  String get kelivoPublicStorageTitle => "مجلد KELIVO الدائم على الهاتف";
  @override
  String get kelivoPublicStorageSubtitle => "اختر مجلدًا مرة واحدة. سينشئ KELIVO داخله مجلدات Projects وResults وDownloads وSkills-Exports وReports وBackups. تُنسخ الملفات بين مساحة التطبيق وهذا المجلد، ولا يُركّب داخل Ubuntu.";
  @override
  String get kelivoPublicStorageChoose => "اختيار المجلد أو تغييره";
  @override
  String get kelivoPublicStorageNotConfigured => "لم يتم اختيار مجلد دائم بعد. اضغط هنا لاختياره.";
  @override
  String get kelivoPublicStorageLoading => "جارٍ التحقق من صلاحية المجلد المحفوظ…";
  @override
  String get kelivoPublicStorageActive => "الوصول متاح";
  @override
  String get kelivoPublicStoragePermissionLost => "انتهت صلاحية الوصول؛ أعد اختيار المجلد";
  @override
  String get kelivoPublicStorageSaved => "تم حفظ مجلد KELIVO وإنشاء المجلدات الأساسية.";
  @override
  String get kelivoPublicStorageFailed => "تعذر إعداد مجلد KELIVO";
  @override
  String get kelivoPublicStorageBackupCopied => "تم أيضًا نسخ النسخة الاحتياطية إلى KELIVO/Backups.";
  @override
  String get kelivoPublicStorageBackupCopyFailed => "تعذر نسخ النسخة الاحتياطية إلى مجلد KELIVO المحدد.";

  @override
  String get kelivoPublicStorageSkillExportCopied => 'تم أيضًا نسخ ملف المهارة إلى KELIVO/Skills-Exports.';

  @override
  String get kelivoPublicStorageSkillExportCopyFailed => 'تعذر نسخ ملف المهارة إلى مجلد KELIVO المحدد.';

  String get workspaceEnvActionsSection => "الإجراءات";

  @override
  String get workspaceEnvInfoSection => "معلومات";

  @override
  String get workspaceEnvInfoBody => "البيئة هي نظام ملفات جذر Linux تستخدمه البيئة المعزولة. تُخزّن مساحات العمل بشكل منفصل ولا تُحذف عند إعادة تعيين البيئة. توجد الملفات داخل نظام الملفات الجذر المستخرج على هذا الجهاز.";

  @override
  String get workspaceEnvRepairDetail => "إعادة التحقق من الملفات وتطبيق التصحيحات";

  @override
  String get workspaceEnvUpdateCurrent => "لديك أحدث إصدار";

  @override
  String workspaceEnvUpdateAvailableShort(String version) => "تحديث متاح: ${version}";

  @override
  String get workspaceEnvResetConfirmMessage => "سيؤدي هذا إلى حذف بيئة Linux بالكامل وأي حزم مثبّتة فيها. لن تتأثر ملفات مساحات العمل.";

  @override
  String get workspaceEnvRestartDoneBanner => "اكتملت إعادة التعيين. أعد تشغيل التطبيق لإكمال التثبيت.";

  @override
  String get workspaceEnvPathCopied => "تم نسخ المسار";

  @override
  String get workspaceEnvUseMirrorSubtitle => "كتابة المرآة المحددة داخل البيئة المعزولة";

  @override
  String get workspaceEnvRegionGlobal => "عالمي";

  @override
  String get workspaceEnvRegionChina => "الصين";

  @override
  String get workspaceEnvRegionEurope => "أوروبا";

  @override
  String get workspaceEnvRegionAsia => "آسيا";

  @override
  String get workspaceEnvMirrorTimeout => "انتهت مهلة الاتصال";

  @override
  String get workspaceEnvSpeedTest => "اختبار السرعة";

  @override
  String get workspaceEnvApplySuccess => "تم تطبيق المرآة";

  @override
  String get workspaceEnvApplyFailed => "تعذّر تطبيق المرآة";

  @override
  String get workspaceEnvRestoreSuccess => "تمت استعادة المصدر الرسمي";

  @override
  String get workspaceEnvMirrorsTested => "تم تطبيق أسرع المرايا";

  @override
  String get workspaceEnvRelativeJustNow => "الآن";

  @override
  String workspaceEnvRelativeMinutesAgo(int count) => "قبل ${count} دقيقة";

  @override
  String workspaceEnvRelativeHoursAgo(int count) => "قبل ${count} ساعة";

  @override
  String workspaceEnvRelativeDaysAgo(int count) => "قبل ${count} يوم";

  @override
  String workspaceEnvDownloadLine(String downloaded, String total, String phase) => "${downloaded} / ${total} · المرحلة: ${phase}";

  @override
  String get workspaceEnvNativeUnsandboxed => "تُنفّذ الأوامر على هذا الكمبيوتر دون بيئة معزولة، وتتطلب موافقة ما لم تكن هذه المحادثة تملك صلاحية وصول كاملة.";

  @override
  String get workspaceEnvBrowserUnavailable => "نظام ملفات البيئة المعزولة غير متاح.";

  @override
  String get workspaceEnvMirrorNameOfficial => "رسمي";

  @override
  String get workspaceEnvMirrorNameOfficialCdn => "شبكة توصيل المحتوى الرسمية";

  @override
  String get workspaceEnvMirrorNameOfficialPypi => "PyPI الرسمي";

  @override
  String get workspaceEnvMirrorNameOfficialNpm => "npm الرسمي";

  @override
  String get workspaceEnvMirrorNameTuna => "مرآة TUNA من جامعة تسينغهوا";

  @override
  String get workspaceEnvMirrorNameRwth => "RWTH ألمانيا";

  @override
  String get workspaceEnvMirrorNameJaist => "JAIST اليابان";

  @override
  String get workspaceEnvMirrorNameKakao => "Kakao كوريا";

  @override
  String workspaceEnvSelectionNamed(String name, String region) => "${name} · المنطقة: ${region}";

  @override
  String get workspaceFilesEmptyPickerHint => "استخدم «مجلد جديد» لإضافة مجلد فرعي";

  @override
  String get skillsDetailBodyEmpty => "لا يوجد محتوى للمهارة بعد";

  @override
  String skillsDetailBodyTooLarge(String size) => "هذا الملف كبير جدًا للمعاينة (${size}).";

  @override
  String get workspaceEnvSizeTimeout => "انتهت المهلة";

  @override
  String get workspaceEnvInfoCopied => "تم نسخ معلومات البيئة";

  @override
  String get workspacePreviewEmptyFile => "هذا الملف فارغ";

  @override
  String get workspacePreviewEmptyHint => "لا يوجد محتوى لمعاينته.";

  @override
  String get workspacePreviewRevealInExplorer => "إظهار في مستكشف الملفات";

  @override
  String get workspacePreviewRevealInFileManager => "إظهار في مدير الملفات";

  @override
  String workspaceBindingSetAssistantDefault(String assistant) => "تعيين مساحة العمل الافتراضية للمساعد «${assistant}»";

  @override
  String get storageSpaceCategoryWorkspaceFiles => "ملفات مساحات العمل";

  @override
  String get storageSpaceCategoryWorkspaceFilesHint => "الملفات المخزّنة في مساحات العمل المُدارة.";

  @override
  String get storageSpaceCategorySandboxEnvironment => "البيئة المعزولة";

  @override
  String get storageSpaceCategorySandboxEnvironmentHint => "تثبيت البيئة ونظام الملفات الجذر.";

  @override
  String get storageSpaceCategorySkills => "المهارات";

  @override
  String get storageSpaceCategorySkillsHint => "ملفات المهارات المثبّتة.";

  @override
  String get storageSpaceCategorySessionFiles => "ملفات المحادثات";

  @override
  String get storageSpaceCategorySessionFilesHint => "المرفقات والمخرجات الخاصة بكل محادثة.";

  @override
  String get storageSpaceManageSkills => "إدارة المهارات";

  @override
  String get storageSessionFilesCleanOrphans => "تنظيف ملفات المحادثات اليتيمة";

  @override
  String storageSessionFilesCleanOrphansHint(String size) => "حذف مجلدات الجلسات التي لم تعد مرتبطة بمحادثة. المساحة القابلة للاستعادة: ${size}.";

  @override
  String get workspaceDesktopFolderPath => "مسار المجلد";

  @override
  String get workspaceDesktopFolderMissing => "اختر مجلدًا موجودًا أو أدخل مساره المطلق.";

  @override
  String get workspaceDesktopManagedHint => "ينشئ Kelivo مجلدًا لهذا المشروع ويتولى إدارته.";

  @override
  String get workspaceDesktopHostHint => "تستخدم الملفات والأوامر هذا الكمبيوتر.";

  @override
  String get workspaceDesktopSearch => "البحث في مساحات العمل";

  @override
  String get workspaceDesktopNoResults => "لا توجد مساحات عمل مطابقة";

  @override
  String get workspaceEnvDependencies => "حزم أدوات البيئة";

  @override
  String get workspaceEnvDependenciesDetail => "تثبيت الأدوات في البيئة المعزولة المشتركة. ويمكن لجميع مساحات العمل استخدامها.";

  @override
  String get workspaceEnvDependencyPython => "Python وpip والبيئات الافتراضية";

  @override
  String get workspaceEnvDependencyNode => "Node.js وnpm";

  @override
  String get workspaceEnvDependencyGit => "استنساخ المستودعات وإدارة الإصدارات";

  @override
  String get workspaceEnvDependencySsh => "SSH وSCP وSFTP وإنشاء المفاتيح";

  @override
  String get workspaceEnvDependencyNetwork => "أدوات الشبكة";

  @override
  String get workspaceEnvDependencyArchive => "أدوات الأرشفة";

  @override
  String get workspaceEnvDependencyInstalled => "مثبّت";

  @override
  String get workspaceEnvDependencyUnknown => "لم يتم التحقق";

  @override
  String get workspaceEnvDependencyChecking => "جارٍ التحقق من الأدوات…";

  @override
  String get workspaceEnvDependencyInstalling => "جارٍ التثبيت…";

  @override
  String get workspaceEnvDependencyCheckFailed => "تعذّر التحقق من الأدوات. اضغط على تحديث للمحاولة مرة أخرى.";

  @override
  String get workspaceEnvDependencyInstallFailed => "لم يكتمل التثبيت. راجع السجل أو غيّر مصدر الحزم ثم أعد المحاولة.";

  @override
  String get workspaceEnvDependencyLog => "سجل التثبيت";

  @override
  String get workspaceEnvDependencyRefresh => "تحديث حالة الأدوات";

  @override
  String get workspaceEnvDependencyReadyFirst => "ثبّت البيئة المعزولة أولًا لإضافة هذه الأدوات.";

  @override
  String get workspaceEnvDependencySources => "مصادر الحزم";

  @override
  String get workspaceEnvDependencySourcesDetail => "يستخدم التثبيت مصدر apt/apk المحدد. وتنطبق مصادر pip وnpm على الحزم التي تثبّتها لاحقًا.";

  @override
  String get workspaceEnvDownloadSource => "مصدر تنزيل البيئة المعزولة";

  @override
  String get workspaceEnvDownloadAutomatic => "اختيار الأسرع تلقائيًا";

  @override
  String get workspaceEnvDownloadAutomaticDetail => "اختبر المصدر الرسمي والمرايا المضمّنة قبل التنزيل.";

  @override
  String get workspaceEnvDownloadCustom => "عنوان URL مخصص";

  @override
  String get workspaceEnvDownloadCustomDetail => "أدخل مجلد إصدار أو عنوان URL كاملًا للأرشيف. يجب أن يتوافق الأرشيف مع النظام والإصدار ومعمارية الجهاز المحددة.";

  @override
  String get workspaceEnvDownloadInvalidUrl => "أدخل عنوان URL صالحًا يبدأ بـ HTTP أو HTTPS.";

  @override
  String get workspaceEnvDownloadVerified => "يتم التحقق من التنزيلات باستخدام SHA-256 الرسمي للصورة المحددة. وتُضبط مصادر الحزم بشكل منفصل.";

  @override
  String get workspaceEnvDownloadStart => "تنزيل وتثبيت";

  @override
  String get workspaceEnvDownloadSave => "حفظ المصدر";

  @override
  String get workspaceToolsTitle => "الأدوات";

  @override
  String get workspaceToolsDescription => "اختر الأدوات التي يمكن للمحادثات استخدامها في مساحة العمل هذه. تُحفظ التغييرات تلقائيًا.";

  @override
  String get workspaceToolHelpShell => "تنفيذ الأوامر في بيئة مساحة العمل.";

  @override
  String get workspaceToolHelpRead => "قراءة الملفات مع أرقام الأسطر وتقسيم النتائج إلى صفحات.";

  @override
  String get workspaceToolHelpViewImage => "السماح للنموذج بفحص صورة من مساحة العمل.";

  @override
  String get workspaceToolHelpWrite => "إنشاء الملفات أو استبدال محتوياتها.";

  @override
  String get workspaceToolHelpEdit => "استبدال نص محدد داخل ملف موجود.";

  @override
  String get workspaceToolHelpList => "استعراض المجلدات والعناصر الموجودة فيها.";

  @override
  String get workspaceToolHelpGlob => "العثور على الملفات باستخدام اسم أو نمط مسار.";

  @override
  String get workspaceToolHelpGrep => "البحث عن نص داخل الملفات.";

  @override
  String get workspaceEnvVariablesTitle => "متغيرات البيئة";

  @override
  String get workspaceEnvVariablesEntryDetail => "متغيرات للأوامر مع عناصر للتحكم في خصوصية المخرجات";

  @override
  String get workspaceEnvVariablesEmpty => "لا توجد متغيرات بعد. أضف مفاتيح API أو إعدادات أخرى لأدواتك.";

  @override
  String get workspaceEnvVariablesScope => "تُشارك بين جميع مساحات العمل. تنطبق التغييرات على أوامر Agent الجديدة وجلسات الطرفية الجديدة داخل التطبيق؛ أعد فتح الجلسات الحالية لتطبيقها. تحتفظ الطرفيات الخارجية ببيئتها الخاصة.";

  @override
  String get workspaceEnvPrivacyMode => "وضع الخصوصية";

  @override
  String get workspaceEnvPrivacyDetail => "يمكن للأوامر استخدام القيم الحقيقية. قبل إرسال مخرجات أدوات مساحة العمل إلى النموذج، تُستبدل القيم المطابقة التي لا يقل طولها عن 5 أحرف بـ[REDACTED]. تظل السجلات المحلية كما هي. ولا تُخفى القيم الأقصر لتجنب استبدال الخيارات والأرقام الشائعة.";

  @override
  String get workspaceEnvVariableAdd => "إضافة متغير";

  @override
  String get workspaceEnvVariableEdit => "تعديل متغير";

  @override
  String get workspaceEnvVariableName => "الاسم";

  @override
  String get workspaceEnvVariableValue => "القيمة";

  @override
  String get workspaceEnvVariableNote => "ملاحظة (اختيارية)";

  @override
  String get workspaceEnvVariableNameHint => "استخدم الأحرف والأرقام والشرطة السفلية، ولا تبدأ برقم. الأسماء حساسة لحالة الأحرف. أشر إلى المتغيرات في الأوامر باستخدام \$NAME.";

  @override
  String get workspaceEnvVariableInvalidName => "أدخل اسم متغير صالحًا.";

  @override
  String get workspaceEnvVariableInvalidValue => "أدخل قيمة غير فارغة لا تحتوي على محارف NUL.";

  @override
  String get workspaceEnvVariableDuplicate => "يوجد متغير بهذا الاسم بالفعل.";

  @override
  String get workspaceEnvVariablesSaveFailed => "تعذّر حفظ إعدادات البيئة. حاول مرة أخرى.";

  @override
  String get incomingShareTitle => "محتوى تمت مشاركته";

  @override
  String get incomingShareReplaceDraft => "توجد محتويات غير مرسلة في مربع الإدخال. هل تريد استبدالها بالمحتوى الذي تمت مشاركته في محادثة جديدة؟";

  @override
  String get incomingShareFailed => "تعذّر استيراد بعض المحتويات التي تمت مشاركتها. تحقق من إمكانية الوصول إلى الملفات ومساحة التخزين المتاحة. يمكن مشاركة ما يصل إلى 32 ملفًا في المرة الواحدة.";

  @override
  String get incomingShareImporting => "جارٍ الاستيراد";

  @override
  String get incomingShareMoveTo => "نقل إلى…";

  @override
  String get incomingShareNewChat => "محادثة جديدة";

  @override
  String get incomingShareMoveHint => "انقل هذه المسودة ومرفقاتها إلى محادثة أخرى. لن يتم إرسال أي شيء تلقائيًا.";

  @override
  String get incomingShareNoConversations => "لا توجد محادثات مطابقة";

  @override
  @override
  String get chatAttachmentLibraryTitle => "الملفات المرفوعة سابقًا";

  @override
  String get chatAttachmentLibrarySearch => "البحث في الملفات";

  @override
  String get chatAttachmentLibraryEmpty => "لا توجد ملفات مرفوعة سابقًا. اختر «رفع من الملفات» لإضافة ملفات من هاتفك.";

  @override
  String get chatAttachmentLibraryNoResults => "لا توجد ملفات تطابق البحث.";

  @override
  String get chatAttachmentLibraryPreviouslyUploaded => "مرفوع مسبقًا";

  @override
  String get chatAttachmentLibraryFromDevice => "من هذا الجهاز";

  @override
  String get chatAttachmentLibraryUploadFromFiles => "رفع من الملفات";

  @override
  String get chatAttachmentLibraryOpeningFiles => "جارٍ فتح الملفات…";

  @override
  String get chatAttachmentLibraryAdd => "إضافة إلى الرسالة";

  @override
  String chatAttachmentLibrarySelectedCount(int count) => "تم تحديد $count";

  String get chatInputBarRemoveAttachment => "إزالة المرفق";

  @override
  String get incomingShareMoveFailed => "تعذّر تبديل المحادثات. تم الاحتفاظ بمسودتك.";

  @override
  String attachmentRequiresWorkspace(String name) => "لاستخدام «${name}»، اربط مساحة عمل وفعّل أدوات الملفات، أو انقل هذه المسودة إلى محادثة مرتبطة بمساحة عمل. لا يمكن قراءة هذا الملف مباشرةً من محادثة عادية.";

  @override
  String get storageSessionFilesUnlinked => "محادثة غير مرتبطة";

  @override
  String get workspaceExternalMount => "إرفاق مجلد خارجي";

  @override
  String get workspaceExternalMountSubtitle => "تُرفق المجلدات المحددة في /mounts/<name> وتُشارك بين مساحات العمل. يمكن لأدوات الذكاء الاصطناعي والطرفية ومتصفح الملفات الوصول إليها. الحد الأقصى 10 مجلدات.";

  @override
  String get workspaceExternalStorageTitle => "السماح بالوصول إلى الملفات";

  @override
  String get workspaceExternalStorageMessage => "لقراءة المجلدات الخارجية والكتابة فيها من مساحة العمل والطرفية، اسمح لـKelivo بإدارة الملفات من إعدادات Android. في Android 11 أو أحدث، فعّل إذن الوصول إلى جميع الملفات، ثم اختر مجلدًا على الجهاز لإرفاقه.";

  @override
  String get workspaceExternalGrantAccess => "منح الإذن";

  @override
  String get workspaceExternalLocalOnly => "يمكن لـAndroid إرفاق المجلدات الموجودة على الجهاز فقط. موفّر المستندات هذا لا يعرض مجلدًا محليًا يمكن للطرفية الوصول إليه.";

  @override
  String get workspaceExternalUnavailable => "المجلد الخارجي غير متاح. تحقق من اتصال وحدة التخزين والأذونات، ثم اختر المجلد مرة أخرى لاستعادة الوصول.";

  @override
  String get workspaceExternalReconnect => "اختيار المجلد مرة أخرى";

  @override
  String get workspaceMountAdd => "إضافة مجلد";

  @override
  String get workspaceMountEdit => "تعديل المجلد المرفق";

  @override
  String get workspaceMountEmpty => "لا توجد مجلدات مرفقة";

  @override
  String get workspaceMountReadOnly => "للقراءة فقط";

  @override
  String get workspaceMountReadWrite => "للقراءة والكتابة";

  @override
  String get workspaceMountAllowWrite => "السماح بالكتابة";

  @override
  String get workspaceMountPermissionsHint => "تلتزم أدوات الملفات في الذكاء الاصطناعي ومتصفح الملفات بهذا الإعداد. تحمي قيود Shell أوامر الملفات الشائعة، لكن قد تتجاوزها السكربتات المخصصة. يؤدي حفظ تغييرات الربط إلى إيقاف الأوامر وجلسات الطرفية قيد التشغيل.";

  @override
  String get workspaceMountBrowse => "استعراض الملفات";

  @override
  String get workspaceMountUnmount => "إلغاء الربط";

  @override
  String get workspaceMountUnmountMessage => "هل تريد إزالة هذا الربط؟ سيبقى المجلد الأصلي وملفاته دون تغيير.";

  @override
  String get workspaceMountInactive => "غير متاح — اختر المجلد مرة أخرى";

  @override
  String get workspaceMountInvalidName => "استخدم اسمًا لا يتجاوز 64 حرفًا، دون شرطات مائلة أو نقطتين أو محارف تحكم. لا تستخدم . أو ..";

  @override
  String get workspaceMountDuplicate => "يوجد بالفعل ربط بهذا الاسم.";

  @override
  String get workspaceMountLimit => "يمكن ربط ما يصل إلى 10 مجلدات. أزل أحد الروابط قبل إضافة مجلد آخر.";

  @override
  String get workspaceMountOverlap => "يتداخل هذا المجلد مع ربط موجود. اختر مجلدًا آخر حتى تبقى الصلاحيات واضحة.";

  @override
  String get workspaceMountTargetOccupied => "يحتوي هدف الربط داخل /mounts على ملفات محلية بالفعل. اختر اسم ربط آخر أو انقل تلك الملفات أولًا. لم تتم إزالة أي ملفات.";

  @override
  String get workspaceEnvSystemImage => "صورة النظام";

  @override
  String get workspaceEnvDistribution => "التوزيعة";

  @override
  String get workspaceEnvSystemVersion => "الإصدار";

  @override
  String get workspaceEnvLocalImage => "صورة محلية";

  @override
  String get workspaceEnvChooseImage => "اختيار أرشيف rootfs";

  @override
  String get workspaceEnvLocalImageHint => "استورد أرشيف نظام ملفات جذري (.tar.gz أو .tar.xz أو .tar)، وليس ملف ISO أو صورة قرص. يجب أن يتوافق مع معمارية معالج هذا الجهاز وأن يحتوي على /bin/sh. سيتم اكتشاف النظام وإصداره بعد الاستخراج.";

  @override
  String get workspaceEnvImportImage => "استيراد الصورة";

  @override
  String get workspaceEnvInvalidImage => "اختر أرشيف rootfs صالحًا لهذا الجهاز. يجب أن يحتوي على /bin/sh قابل للتنفيذ ومتوافق مع معمارية المعالج.";

  @override
  String get workspaceEnvReplaceSystem => "استبدال النظام";

  @override
  String get workspaceEnvReplaceSystemHint => "سيؤدي ذلك إلى استبدال الحزم والملفات المثبتة داخل البيئة الحالية، وإيقاف أوامرها وجلسات الطرفية. ستبقى مساحات العمل وملفات المحادثات والمجلدات الخارجية محفوظة. إذا فشل تجهيز الصورة الجديدة، فستبقى البيئة الحالية كما هي.";

  @override
  String get workspaceEnvProotOptions => "خيارات PRoot";

  @override
  String get workspaceEnvShellPath => "مسار Shell";

  @override
  String get workspaceEnvShellAutomatic => "تلقائي";

  @override
  String get workspaceEnvShellHint => "اتركه فارغًا لاستخدام /bin/bash إن كان متاحًا، وإلا فسيُستخدم /bin/sh. يجب أن يستخدم Shell المخصص مسارًا مطلقًا داخل البيئة.";

  @override
  String get workspaceEnvProotArguments => "وسائط PRoot إضافية";

  @override
  String get workspaceEnvProotArgumentsHint => "أدخل وسيطًا واحدًا في كل سطر، دون علامات اقتباس Shell. مثلًا، ضع -k و5.10.0 في سطرين منفصلين، أو استخدم --kernel-release=5.10.0. تنطبق التغييرات على الأوامر وجلسات الطرفية الجديدة.";

  @override
  String get workspaceEnvProotInvalid => "أدخل مسار Shell مطلقًا صالحًا ووسيطًا واحدًا لـ PRoot في كل سطر.";

  @override
  String get workspaceFileMissing => "لم يعد الملف موجودًا";

  @override
  String get workspaceFilePreviewUnavailable => "المعاينة غير متاحة";

  @override
  String get workspaceToolRelatedFiles => "ملفات ذات صلة";

  @override
  String get workspaceToolFilesTruncated => "تم عرض بعض الملفات فقط.";

  @override
  String get displaySettingsPageShowProducedFilesTitle => "إظهار الملفات أسفل الردود";

  @override
  String get displaySettingsPageShowProducedFilesSubtitle => "إظهار الملفات التي أنشأتها الأدوات أو عدّلتها أسفل الردود.";

  @override
  String get defaultModelPagePerChatModelTitle => "نموذج مستقل لكل محادثة";

  @override
  String get defaultModelPagePerChatModelSubtitle => "عند التفعيل: يؤدي اختيار نموذج داخل محادثة إلى تطبيقه على تلك المحادثة فقط. عند التعطيل: يصبح النموذج الحالي للمساعد، وبالتالي تتبعه كل المحادثات التي تستخدم ذلك المساعد.";

  @override
  String get googleFontsTitle => "خطوط Google";

  @override
  String get googleFontsRefresh => "تحديث قائمة الخطوط";

  @override
  String get googleFontsSearchHint => "ابحث عن الخطوط أو اللغات";

  @override
  String get googleFontsHint => "نزّل خطًا عاديًا لمعاينته وتطبيقه. تعمل الخطوط المثبّتة دون اتصال. الكتالوج: Expo Google Fonts؛ والتنزيلات: Google Fonts.";

  @override
  String get googleFontsNoResults => "لا توجد خطوط مطابقة";

  @override
  String get googleFontsFailed => "تعذّر تحميل الخط أو تنزيله أو تطبيقه. تحقق من الاتصال ثم حاول مجددًا.";

  @override
  String get googleFontsDownloading => "جارٍ تنزيل الخط…";

  @override
  String get googleFontsPreview => "نص تجريبي للخط 0123456789 · معاينة الخطوط";

  @override
  String get googleFontsLicense => "ترخيص الخط";

  @override
  String get assistantEditLocationPermissionSettingsMessage => "تم حظر إذن الموقع. اسمح بالوصول إلى الموقع من إعدادات النظام، ثم فعّل هذه الأداة مرة أخرى.";

  @override
  String get healthDataSettingsCategoryReproductive => "الصحة الإنجابية";

  @override
  String get healthDataSettingsTypeMenstrualFlowTitle => "تدفق الدورة الشهرية";

  @override
  String get healthDataSettingsTypeMenstrualFlowSubtitle => "سجلات تدفق الدورة وبداياتها خلال آخر 90 يومًا";

  @override
  String get assistantEditGradientBackgroundTitle => "خلفية متدرجة";

  @override
  String get assistantEditGradientStaticTitle => "الوضع الثابت";

  @override
  String get assistantEditGradientStaticDescription => "يوفر الطاقة أثناء المحادثات الطويلة والبث المباشر.";

  @override
  String get assistantEditGradientHorizontal => "الموضع الأفقي";

  @override
  String get assistantEditGradientVertical => "الموضع العمودي";

  @override
  String get assistantEditGradientPreview => "معاينة";

  @override
  String get assistantEditGradientNextFrame => "إطار آخر";

  @override
  String get backgroundSettingsTitle => "مهام الخلفية";

  @override
  String get backgroundTaskTitle => "مهمة Kelivo";

  @override
  String get backgroundCompleted => "اكتمل التوليد";

  @override
  String get backgroundFailed => "فشل التوليد. افتح المحادثة لمعرفة التفاصيل.";

  @override
  String get backgroundCancelled => "تم إلغاء التوليد";

  @override
  String get backgroundInterrupted => "تمت مقاطعة التوليد في الخلفية. افتح المحادثة للمتابعة.";

  @override
  String get backgroundRequesting => "جارٍ الاتصال";

  @override
  String get backgroundGenerating => "جارٍ إنشاء الرد";

  @override
  String get backgroundThinking => "جارٍ التفكير";

  @override
  String get backgroundToolRunning => "جارٍ تشغيل الأداة";

  @override
  String get backgroundRetrying => "بانتظار إعادة المحاولة";

  @override
  String get backgroundWorking => "جارٍ العمل";

  @override
  String get backgroundTasks => "المهام";

  @override
  String get backgroundStopTasks => "إيقاف المهام";

  @override
  String get backgroundOpenChat => "فتح المحادثة";

  @override
  String get backgroundAndroidEnabled => "التوليد في الخلفية";

  @override
  String get backgroundAndroidEnabledDetail => "إبقاء المهام الحالية قيد التشغيل عند قفل الجهاز أو الانتقال إلى الخلفية أو إزالة التطبيق من التطبيقات الأخيرة. يلزم وجود إشعار نظام أثناء تشغيل المهام.";

  @override
  String get backgroundIosEnabled => "تنفيذ محسّن في الخلفية";

  @override
  String get backgroundIosEnabledDetail => "طلب وقت إضافي لإكمال المهام الحالية. فعّل الموقع أو الصوت الصامت بشكل منفصل للحصول على دعم إضافي في الخلفية.";

  @override
  String get backgroundNotifications => "إشعارات المهام";

  @override
  String get backgroundNotificationsDetail => "إشعارك عند اكتمال مهمة أو فشلها خارج المحادثة التي تعرضها. لا يتحكم هذا في إشعار Android المستمر المطلوب.";

  @override
  String get backgroundPrivacy => "خصوصية حالة المهام";

  @override
  String get backgroundPrivacyDetail => "إخفاء عناوين المحادثات وتفاصيل الأدوات من الإشعارات والحالة المباشرة. لا يظهر سوى وصف عام للحالة وعدد المهام والوقت المنقضي.";

  @override
  String get backgroundLiveActivities => "الأنشطة المباشرة";

  @override
  String get backgroundLiveActivitiesDetail => "إظهار المهام الحالية على شاشة القفل وDynamic Island. يعتمد التوفر والظهور على النظام.";

  @override
  String get backgroundOverlay => "حالة المهام العائمة";

  @override
  String get backgroundOverlayDetail => "إظهار شارة مهام قابلة للسحب فوق التطبيقات الأخرى. اضغط عليها لفتح المحادثة؛ إغلاقها يخفي الشارة فقط.";

  @override
  String get backgroundLiveUpdates => "التحديثات المباشرة";

  @override
  String get backgroundLiveUpdatesDetail => "استخدام Live Updates في Android 16 على الأجهزة المدعومة. يحظى الإشعار المثبت بالأولوية على الشارة العائمة.";

  @override
  String get backgroundLocation => "التنفيذ بمساعدة الموقع";

  @override
  String get backgroundLocationDetail => "استخدام تحديثات الموقع التقريبية أثناء مهام الخلفية. لا يتم تخزين الإحداثيات أو إرسالها إلى خدمات الذكاء الاصطناعي. يتطلب التنفيذ المحسّن في الخلفية وإذن الموقع.";

  @override
  String get backgroundSilentAudio => "إبقاء التشغيل في الخلفية بصوت صامت";

  @override
  String get backgroundSilentAudioDetail => "تشغيل صوت صامت أثناء تنفيذ مهام الخلفية. يتوقف لصالح التسجيل وتشغيل الكلام. يتطلب التنفيذ المحسّن في الخلفية، ولا يحتاج إلى إذن الميكروفون.";

  @override
  String get backgroundSpeech => "القراءة الصوتية في الخلفية";

  @override
  String get backgroundSpeechDetail => "متابعة القراءة الصوتية عبر النظام والشبكة عند قفل الجهاز أو الانتقال إلى الخلفية. عند التعطيل، تتوقف القراءة مؤقتًا عند الانتقال إلى الخلفية.";

  @override
  String get backgroundFinishVisibility => "مدة عرض حالة الاكتمال";

  @override
  String get backgroundFinishImmediately => "إخفاء فورًا";

  @override
  String get backgroundFinishOneMinute => "دقيقة واحدة";

  @override
  String get backgroundFinishFiveMinutes => "خمس دقائق";

  @override
  String get backgroundFinishUntilForeground => "حتى العودة إلى التطبيق";

  @override
  String get backgroundFinishVisibilityDetail => "ينطبق على الشارة في Android وبطاقة الاكتمال على شاشة قفل iOS. تؤدي العودة إلى التطبيق إلى مسح حالة الاكتمال؛ والحد الأقصى 15 دقيقة. يؤدي الإلغاء إلى الإخفاء فورًا.";

  @override
  String get backgroundOverlayIcon => "أيقونة النافذة العائمة";

  @override
  String get backgroundIconDefault => "أيقونة Kelivo";

  @override
  String get backgroundIconImage => "اختيار صورة";

  @override
  String get backgroundIconEmoji => "اختيار رمز تعبيري";

  @override
  String get backgroundPermissionsTitle => "الأذونات وإعدادات النظام";

  @override
  String get backgroundNotificationsPermission => "إذن الإشعارات";

  @override
  String get backgroundBatteryOptimization => "تحسين البطارية";

  @override
  String get backgroundBatteryOptimizationDetail => "السماح بالاستخدام غير المقيّد للبطارية لتحسين موثوقية العمل في الخلفية.";

  @override
  String get backgroundAutostart => "التشغيل التلقائي والاستخدام في الخلفية";

  @override
  String get backgroundAutostartDetail => "تحقق يدويًا من إعدادات التشغيل التلقائي وقيود الخلفية على جهازك. لا يوفّر Android استعلامًا موثوقًا عن أذونات إعدادات الشركات المصنّعة هذه.";

  @override
  String get backgroundLocationPermission => "إذن الموقع";

  @override
  String get backgroundLocationAlways => "السماح بالوصول إلى الموقع في الخلفية";

  @override
  String get backgroundLocationAlwaysDetail => "يمكنك منح إذن الوصول الدائم للموقع في الخلفية. لن يُطلب الإذن إلا عند اختيارك هذا الإجراء.";

  @override
  String get backgroundSystemSettings => "إعدادات نظام التطبيق";

  @override
  String get backgroundPermissionGranted => "مسموح";

  @override
  String get backgroundPermissionDenied => "غير مسموح";

  @override
  String get backgroundPermissionLimited => "أثناء استخدام التطبيق";

  @override
  String get backgroundPermissionUnknown => "تحقق يدويًا";

  @override
  String get backgroundPermissionNotDetermined => "لم يُطلب";

  @override
  String get backgroundRuntimeTitle => "الحالة الحالية";

  @override
  String get backgroundRuntimeActive => "قيد التشغيل";

  @override
  String get backgroundRuntimeIdle => "غير نشط";

  @override
  String get backgroundLocationActive => "الموقع في الخلفية";

  @override
  String get backgroundAudioActive => "الصوت الصامت";

  @override
  String get backgroundActivityActive => "النشاط المباشر";

  @override
  String get backgroundOverlayActive => "النافذة العائمة";

  @override
  String get backgroundLastError => "آخر انقطاع أو خطأ";

  @override
  String get backgroundNoError => "لم يتم تسجيل أي خطأ";

  @override
  String get backgroundUnsupported => "غير متاح على هذا الجهاز أو معطّل في إعدادات النظام.";

  @override
  String get backgroundIosLimit => "يتحكم iOS في تنفيذ المهام بالخلفية. لا تُبقي الأنشطة المباشرة التطبيق قيد التشغيل بمفردها. قد يؤدي إغلاق التطبيق بالقوة إلى إيقاف التوليد وتأخير إزالة الحالة المباشرة حتى فتح التطبيق مجددًا.";

  @override
  String get backgroundAndroidLimit => "إذا توقفت المهام، فتحقق من إعدادات الإشعارات والبطارية وقيود الخلفية الخاصة بالشركة المصنّعة. قد يظل الإيقاف القسري أو إنهاء عملية النظام سببًا في مقاطعة التوليد.";

  @override
  String get backgroundStale => "لم يتم تحديث الحالة. افتح التطبيق للتحقق.";

  @override
  String get backgroundIconError => "تعذّر استيراد هذه الصورة. يُرجى اختيار صورة أخرى.";

  @override
  String get backgroundNotificationChannels => "قنوات الإشعارات";

  @override
  String get backgroundCompletionChannel => "قناة إشعار اكتمال المهمة";

  @override
  String get backgroundOngoingChannel => "قناة إشعار المهام قيد التشغيل";

  @override
  String get backgroundOverlayAppearance => "مظهر النافذة العائمة";

  @override
  String get backgroundOverlayAppearanceDetail => "الحجم والعمل الفني وحلقة التقدم والمحتوى الظاهر.";

  @override
  String get backgroundOverlayPreviewHint => "اسحب للتحريك · اضغط لفتح المحادثة · اضغط مطولًا للإخفاء";

  @override
  String get backgroundOverlayCard => "بطاقة";

  @override
  String get backgroundOverlayCircle => "أيقونة دائرية";

  @override
  String get backgroundOverlaySize => "الحجم والشكل";

  @override
  String get backgroundOverlayWidth => "العرض";

  @override
  String get backgroundOverlayHeight => "الارتفاع";

  @override
  String get backgroundOverlayCornerRadius => "استدارة الزوايا";

  @override
  String get backgroundOverlayIconSize => "حجم الأيقونة";

  @override
  String get backgroundOverlayProgressSize => "قطر حلقة التقدم";

  @override
  String get backgroundOverlayProgressStroke => "سُمك حلقة التقدم";

  @override
  String get backgroundOverlayContent => "المحتوى الظاهر";

  @override
  String get backgroundOverlayShowProgress => "إظهار حلقة التقدم";

  @override
  String get backgroundOverlayShowTitle => "إظهار العنوان";

  @override
  String get backgroundOverlayShowSubtitle => "إظهار العنوان الفرعي";

  @override
  String get backgroundOverlayShowTime => "إظهار الوقت المنقضي";

  @override
  String get backgroundOverlayShowClose => "إظهار زر الإغلاق";

  @override
  String get backgroundOverlayShowBackground => "إظهار الخلفية";

  @override
  String get backgroundOverlayShowBorder => "إظهار الحدود";

  @override
  String get backgroundOverlayReset => "استعادة المظهر الافتراضي";

  @override
  String get mcpStdioEnvironmentRequired => "ثبّت بيئة مساحة العمل لاستخدام STDIO على الهاتف.";

  @override
  String get mcpArgumentsHint => "افصل الوسائط بمسافات، وضع القيم التي تحتوي على مسافات بين علامتي اقتباس. استخدم علامتي اقتباس فارغتين  لتمرير وسيط فارغ.";

  @override
  String get mcpArgumentsInvalid => "تحقق من وجود علامة اقتباس غير مغلقة أو محرف هروب في نهاية الوسائط.";

  @override
  String get mcpImportEnvironment => "استيراد من البيئة";

  @override
  String get mcpEnvironmentEmpty => "لا توجد متغيرات بيئة. أضفها من إعدادات البيئة.";

  @override
  String get mcpEnvironmentHint => "يرث متغيرات البيئة. استورد متغيرًا لتخصيص قيمته لهذا الخادم.";

  @override
  String get mcpImportJson => "استيراد JSON";

  @override
  String get mcpImportJsonHint => "الصق إعدادات MCP من Claude Desktop أو Cursor. يمكنك معاينة الخوادم وإضافتها دون استبدال الخوادم الموجودة.";

  @override
  String get mcpImportPaste => "لصق من الحافظة";

  @override
  String get mcpImportPreview => "معاينة";

  @override
  String get mcpImportConfirm => "استيراد";

  @override
  String get startupRecoverySnapshotTitle => "الاسترداد من نسخة محلية";

  @override
  String get startupRecoverySnapshotBody => "اختر نسخة محفوظة على هذا الجهاز لاستعادة محادثاتك وإعداداتك، حتى عندما يتعذر فتح قاعدة البيانات. لا تُلغِ تثبيت Kelivo، لأن إلغاء التثبيت يزيل هذه النسخ أيضًا.";

  @override
  String get startupRecoverySnapshotEmpty => "لم يتم العثور على نسخ لقاعدة البيانات على هذا الجهاز. صدّر بياناتك قبل تجربة إجراءات استرداد أخرى.";

  @override
  String get startupRecoverySnapshotButton => "اختيار نسخة للاسترداد";

  @override
  String startupRecoverySnapshotConfirm(String when) => "هل تريد استعادة المحادثات والإعدادات من ${when}؟ لن تُضمّن التغييرات التي أُجريت بعد هذه النسخة. ستظل ملفات المرفقات الحالية والنسخة محفوظة. سيُعاد تشغيل Kelivo لإكمال الاستعادة.";

  @override
  String startupRecoverySnapshotFailed(String reason) => "تعذّر تجهيز استعادة النسخة: ${reason}";

  @override
  String get startupRecoverySnapshotReady => "النسخة جاهزة. أعد تشغيل Kelivo لإكمال الاستعادة.";

  @override
  String get scheduledTasksTitle => "المهام المجدولة";

  @override
  String get scheduledTasksDescription => "شغّل المهام تلقائيًا في الوقت الذي تختاره: ابدأ محادثة جديدة أو تابع محادثة أو أعد تشغيل سؤال.";

  @override
  String get scheduledTasksEmpty => "نظّم يومك وفق جدول";

  @override
  String get scheduledTasksEmptyDetail => "أضف مهمة لإحاطة صباحية أو مراجعة يومية أو أي إجراء تريد تشغيله بانتظام.";

  @override
  String get scheduledTasksAdd => "إضافة مهمة";

  @override
  String get scheduledTasksEdit => "تعديل المهمة";

  @override
  String get scheduledTasksName => "الاسم";

  @override
  String get scheduledTasksNameHint => "الإحاطة الصباحية";

  @override
  String get scheduledTasksPrompt => "التعليمات";

  @override
  String get scheduledTasksPromptHint => "ما الذي تريد من مساعدك تنفيذه؟";

  @override
  String get scheduledTasksAssistant => "المساعد";

  @override
  String get scheduledTasksChooseAssistant => "اختيار مساعد";

  @override
  String get scheduledTasksAssistantMissing => "المساعد غير متاح";

  @override
  String get scheduledTasksTime => "الوقت";

  @override
  String get scheduledTasksTimeHint => "تنسيق 24 ساعة، مثال: 08:00";

  @override
  String get scheduledTasksRepeat => "التكرار";

  @override
  String get scheduledTasksEveryDay => "كل يوم";

  @override
  String get scheduledTasksWeekdays => "أيام العمل";

  @override
  String get scheduledTasksEnabled => "مفعّلة";

  @override
  String get scheduledTasksPermission => "المنبّهات والتذكيرات";

  @override
  String get scheduledTasksPermissionDetail => "اسمح بالمنبّهات الدقيقة لتشغيل المهام في الوقت الذي اخترته. ستنتظر المهام المفعّلة حتى منح الإذن.";

  @override
  String get scheduledTasksPermissionAction => "السماح";

  @override
  String get scheduledTasksReliability => "أبقِ قيود البطارية عن Kelivo مرفوعة لضمان تنفيذ أكثر موثوقية. يؤدي فرض إيقاف التطبيق إلى إلغاء المنبّهات حتى تفتحه مجددًا. يتم تخطي مرات التشغيل الفائتة، وتتبع المهام المنطقة الزمنية للجهاز.";

  @override
  String get scheduledTasksExecutionDetail => "تُحفظ النتائج في المحادثات. يعرض إشعار الإكمال معاينة للرد ويفتح المحادثة عند الضغط عليه. يتوقف التشغيل بعد 10 دقائق أو عند الحاجة إلى إدخال المستخدم أو موافقته على أداة.";

  @override
  String get scheduledTasksRunNow => "تشغيل الآن";

  @override
  String get scheduledTasksHistory => "سجل التشغيل";

  @override
  String get scheduledTasksNoRuns => "لا توجد عمليات تشغيل بعد";

  @override
  String get scheduledTasksRunning => "قيد التشغيل";

  @override
  String get scheduledTasksCompleted => "مكتملة";

  @override
  String get scheduledTasksFailed => "فشلت";

  @override
  String get scheduledTasksInterrupted => "تمت مقاطعتها";

  @override
  String get scheduledTasksPaused => "متوقفة مؤقتًا";

  @override
  String get scheduledTasksWaitingPermission => "بانتظار الإذن";

  @override
  String scheduledTasksNextRun(String time) => "التالي: ${time}";

  @override
  String get scheduledTasksDelete => "حذف المهمة";

  @override
  String get scheduledTasksDeleteDetail => "هل تريد حذف هذا الجدول وسجل تشغيله؟ ستظل المحادثات التي أُنشئت بالفعل محفوظة.";

  @override
  String get scheduledTasksSave => "حفظ";

  @override
  String get scheduledTasksCancel => "إلغاء";

  @override
  String get scheduledTasksInvalid => "أدخل اسمًا وتعليمات ومساعدًا، وحدد يومًا واحدًا على الأقل للجدول المخصص.";

  @override
  String get scheduledTasksLoading => "جارٍ التحميل…";

  @override
  String get scheduledTasksOpenChat => "عرض المحادثة";

  @override
  String get scheduledTasksNeedsInput => "توقف التشغيل لأنه تطلب إدخال المستخدم أو موافقة على أداة. افتح المحادثة للمتابعة.";

  @override
  String get scheduledTasksTimeout => "تم بلوغ الحد الزمني للتنفيذ.";

  @override
  String get scheduledTasksProcessTerminated => "أوقف Android عملية التشغيل السابقة.";

  @override
  String get scheduledTasksOnce => "مرة واحدة";

  @override
  String get scheduledTasksCustom => "مخصص";

  @override
  String get scheduledTasksExecution => "المهمة";

  @override
  String get scheduledTasksMode => "الإجراء";

  @override
  String get scheduledTasksNewChat => "محادثة جديدة";

  @override
  String get scheduledTasksFollowUp => "متابعة";

  @override
  String get scheduledTasksRegenerate => "إعادة التشغيل";

  @override
  String get scheduledTasksChat => "المحادثة";

  @override
  String get scheduledTasksChooseChat => "اختيار محادثة";

  @override
  String get scheduledTasksMessage => "السؤال المراد تشغيله مجددًا";

  @override
  String get scheduledTasksChooseMessage => "اختيار سؤال";

  @override
  String get scheduledTasksAttachmentMessage => "رسالة تحتوي على مرفقات";

  @override
  String get scheduledTasksModel => "النموذج";

  @override
  String get scheduledTasksChooseModel => "اختيار نموذج";

  @override
  String get scheduledTasksModelDefault => "استخدام نموذج المحادثة أو المساعد";

  @override
  String get scheduledTasksSchedule => "الجدول";

  @override
  String get scheduledTasksActiveWindow => "تواريخ النشاط";

  @override
  String get scheduledTasksStartDate => "تاريخ البدء";

  @override
  String get scheduledTasksEndDate => "تاريخ الانتهاء";

  @override
  String get scheduledTasksActiveWindowDetail => "يعمل ضمن هذه التواريخ فقط، بما في ذلك تاريخ الانتهاء. اترك التاريخ فارغًا لإزالة الحد.";

  @override
  String get scheduledTasksDate => "التاريخ";

  @override
  String get scheduledTasksDateUnrestricted => "بلا حد";

  @override
  String get scheduledTasksClear => "مسح";

  @override
  String get scheduledTasksSearch => "بحث";

  @override
  String get scheduledTasksNoTargets => "لا توجد عناصر مطابقة لهذا المساعد";

  @override
  String get scheduledTasksFutureDate => "اختر تاريخًا ووقتًا مستقبليين للتنفيذ.";

  @override
  String get scheduledTasksDateRangeInvalid => "يجب أن يكون تاريخ الانتهاء مساويًا لتاريخ البدء أو لاحقًا له.";

  @override
  String get scheduledTasksRegenerateDetail => "ينشئ إجابة أخرى عن السؤال المحدد باستخدام سياقه الأصلي. وستظل الإجابات الحالية والرسائل اللاحقة محفوظة.";

  @override
  String get scheduledTasksSaving => "جارٍ الحفظ…";

  @override
  String get scheduledTasksFinished => "انتهى الجدول";

  @override
  String get scheduledTasksModelMissing => "النموذج المحدد غير متاح. عدّل هذه المهمة لاختيار نموذج آخر.";

  @override
  String get scheduledTasksChatMissing => "المحادثة غير متاحة أو أنها تتبع مساعدًا آخر.";

  @override
  String get scheduledTasksMessageMissing => "السؤال المحدد لم يعد متاحًا.";

  @override
  String get scheduledTasksChatBusy => "يجري إنشاء رد في هذه المحادثة. تم تخطي التشغيل المجدول.";

  @override
  String get scheduledTasksDesktopEmpty => "لا توجد مهام مجدولة";

  @override
  String get scheduledTasksDesktopReliability => "تعمل المهام ما دام Kelivo قيد التشغيل، حتى عند تصغيره أو نقله إلى منطقة الإشعارات. يتم تخطي الأوقات الفائتة بعد الخروج من التطبيق أو دخول الكمبيوتر في وضع السكون. لن يبدأ Kelivo تلقائيًا.";

  @override
  String get scheduledTasksDesktopExecutionDetail => "تُحفظ النتائج في المحادثات. افتحها من سجل تشغيل المهمة. يتوقف التشغيل بعد 10 دقائق أو عند الحاجة إلى إدخال المستخدم أو موافقته على أداة.";

  @override
  String get worldBookStickyLabel => "تثبيت (عدد الرسائل)";

  @override
  String get worldBookStickyHint => "إبقاء هذا المدخل نشطًا لمدة N من الرسائل بعد تفعيله. لا تؤدي المطابقات المتكررة إلى تمديد المدة. القيمة 0 تعطّل هذا التأثير.";

  @override
  String get worldBookCooldownLabel => "فترة التهدئة (عدد الرسائل)";

  @override
  String get worldBookCooldownHint => "منع إعادة التفعيل لمدة N من الرسائل بعد التفعيل أو انتهاء التثبيت. القيمة 0 تعطّل هذا التأثير.";

  @override
  String get worldBookDelayLabel => "التأخير (عدد الرسائل)";

  @override
  String get worldBookDelayHint => "السماح بالتفعيل فقط بعد وصول المحادثة إلى N من الرسائل. تُحتسب الرسائل الفردية لا التبادلات. القيمة 0 تعطّل هذا التأثير.";

  @override
  String get worldBookDragToReorder => "اسحب لإعادة الترتيب";

  @override
  String worldBookEnabledCount(int enabled, int total) => "مفعّل: ${enabled}/${total}";

  @override
  String get assistantConversationSystemPromptTitle => "تعليمات نظام خاصة بالمحادثة";

  @override
  String get assistantConversationSystemPromptHint => "السماح لكل محادثة باستخدام تعليمات النظام الخاصة بها.";

  @override
  String get assistantConversationInjectionTitle => "إدراجات تعليمات خاصة بالمحادثة";

  @override
  String get assistantConversationInjectionHint => "اختر إدراجات التعليمات ودفاتر العالم لكل محادثة. لا يتم تحديد أي منها افتراضيًا.";

  @override
  String get conversationSystemPromptTitle => "تعليمات نظام المحادثة";

  @override
  String get conversationSystemPromptHint => "تنطبق هذه التعليمات على هذه المحادثة فقط. اترك الحقل فارغًا لاستخدام تعليمات نظام المساعد.";

  @override
  String get conversationSystemPromptClear => "استخدام تعليمات المساعد";

  @override
  String get conversationSystemPromptPlaceholder => "اكتب تعليمات نظام لهذه المحادثة…";

  @override
  String get conversationPromptScope => "هذه المحادثة";

  @override
  String get oauthAccountsTab => "الحسابات";

  @override
  String get oauthLogin => "تسجيل الدخول";

  @override
  String oauthLoginTo(String provider) => "تسجيل الدخول إلى ${provider}";

  @override
  String get oauthConnected => "متصل";

  @override
  String get oauthNotConnected => "غير متصل";

  @override
  String oauthWaiting(String provider) => "بانتظار تفويض ${provider}";

  @override
  String get oauthCancel => "إلغاء التفويض";

  @override
  String get oauthOpenBrowser => "فتح صفحة التفويض";

  @override
  String get oauthCopyCode => "نسخ الرمز";

  @override
  String get oauthCodeHint => "أدخل هذا الرمز في صفحة التفويض";

  @override
  String get oauthDeviceHint => "فعّل أولًا تسجيل الدخول برمز الجهاز من إعدادات أمان ChatGPT أو أذونات مساحة العمل.";

  @override
  String get oauthDeviceLogin => "استخدام رمز الجهاز";

  @override
  String get oauthDetails => "عرض تفاصيل الحساب";

  @override
  String get oauthConnectAnother => "ربط حساب آخر";

  @override
  String get oauthRelogin => "تسجيل الدخول مجددًا";

  @override
  String get oauthNeedsLogin => "تسجيل الدخول مطلوب";

  @override
  String oauthExpired(String provider) => "انتهت صلاحية تسجيل الدخول إلى ${provider}";

  @override
  String get oauthLoginRestored => "تم تسجيل الدخول. استخدم زر إعادة المحاولة في الرسالة للإرسال مجددًا.";

  @override
  String get oauthLogout => "تسجيل الخروج";

  @override
  String get oauthLogoutDescription => "إزالة بيانات اعتماد هذا الحساب المحفوظة من هذا الجهاز.";

  @override
  String get oauthRefreshing => "جارٍ تحديث التفويض…";

  @override
  String get oauthRefreshUsage => "تحديث الاستخدام";

  @override
  String get oauthUsageDetails => "تفاصيل الاستخدام";

  @override
  String get oauthUsageUnavailable => "الاستخدام غير متاح حاليًا.";

  @override
  String oauthLastUpdated(String time) => "آخر تحديث: ${time}";

  @override
  String get oauthSyncModels => "مزامنة";

  @override
  String get oauthSyncing => "جارٍ مزامنة النماذج…";

  @override
  String get oauthModelsHint => "تتم مزامنة النماذج المتاحة من حسابك. اختر النماذج التي تريد إظهارها في قائمة اختيار النموذج. سيظل اختيارك محفوظًا عند المزامنة أو تسجيل الدخول مجددًا.";

  @override
  String get oauthNoModels => "زامن النماذج لبدء المحادثة.";

  @override
  String get oauthConnection => "الاتصال";

  @override
  String get oauthConnectionInfo => "تفاصيل الاتصال";

  @override
  String get oauthEndpoint => "نقطة النهاية";

  @override
  String get oauthScope => "نطاق التفويض";

  @override
  String get oauthAccountId => "معرّف الحساب";

  @override
  String get oauthTokenExpiry => "انتهاء صلاحية الرمز";

  @override
  String get oauthName => "اسم المزوّد";

  @override
  String get oauthEnabledHint => "إظهار هذه النماذج في قائمة اختيار النموذج.";

  @override
  String get oauthNetwork => "وكيل الشبكة";

  @override
  String get oauthFollowGlobal => "اتباع الإعدادات العامة";

  @override
  String get oauthCustomRequest => "طلب مخصص";

  @override
  String get oauthWeekly => "الفترة الأسبوعية";

  @override
  String get oauthMonthly => "الفترة الشهرية";

  @override
  String get oauthTotal => "إجمالي الحصة";

  @override
  String oauthHours(String count) => "نافذة ${count} ساعة";

  @override
  String oauthMinutes(String count) => "نافذة ${count} دقيقة";

  @override
  String oauthDays(String count) => "نافذة ${count} يوم";

  @override
  String get oauthWindow => "فترة الاستخدام";

  @override
  String oauthResetsAt(String time) => "إعادة التعيين في ${time}";

  @override
  String oauthUsedValue(String value) => "المستخدم: ${value}";

  @override
  String get oauthNetworkError => "تعذّر الاتصال. تحقق من الشبكة ثم حاول مجددًا.";

  @override
  String get oauthDnsError => "فشل البحث عن DNS. تحقق من الشبكة أو إعدادات DNS الخاصة بالوكيل.";

  @override
  String get oauthTlsError => "فشل اتصال TLS. تحقق من الشهادات المستخدمة في شبكتك أو وكيلك.";

  @override
  String get oauthProxyError => "فشل الاتصال بالوكيل. تحقق من عنوان الوكيل وإعدادات المصادقة.";

  @override
  String get oauthConnectionError => "فشل الاتصال أو انقطع. تحقق من الشبكة أو إعدادات الوكيل.";

  @override
  String get oauthConnectionTimeout => "انتهت مهلة الاتصال بالخادم. تحقق من الشبكة أو إعدادات الوكيل.";

  @override
  String get oauthSendTimeout => "انتهت مهلة إرسال الطلب. تحقق من الشبكة وحاول مجددًا.";

  @override
  String get oauthReceiveTimeout => "انتهت مهلة انتظار استجابة الخادم. يُرجى المحاولة مجددًا.";

  @override
  String get oauthRequestTimeout => "انتهت مهلة الطلب. تحقق من الشبكة أو إعدادات الوكيل ثم حاول مجددًا.";

  @override
  String oauthFailureStage(String stage) => "حدث الفشل عند: ${stage}";

  @override
  String get oauthStageRequestDeviceCode => "طلب رمز الجهاز";

  @override
  String get oauthStageWaitDeviceAuthorization => "انتظار تفويض الجهاز";

  @override
  String get oauthStagePrepareBrowser => "تجهيز تسجيل الدخول عبر المتصفح";

  @override
  String get oauthStageBrowserAuthorization => "التفويض عبر المتصفح واستقبال الرد";

  @override
  String get oauthStageExchangeToken => "تبادل رمز التفويض";

  @override
  String get oauthStageRefreshToken => "تحديث رمز تسجيل الدخول";

  @override
  String get oauthInvalidResponse => "لم يكتمل التفويض. يُرجى المحاولة مجددًا.";

  @override
  String get oauthTimeout => "انتهت مهلة التفويض. يُرجى المحاولة مجددًا.";

  @override
  String get oauthDenied => "لم تتم الموافقة على التفويض. يُرجى المحاولة مجددًا.";

  @override
  String get oauthSaving => "جارٍ ربط الحساب…";

  @override
  String get oauthQuotaExceeded => "لا توجد حصة استخدام متاحة لهذا الحساب.";

  @override
  String get oauthRateLimited => "عدد الطلبات كبير جدًا. يُرجى المحاولة لاحقًا.";

  @override
  String get oauthPermissionDenied => "لا يملك هذا الحساب صلاحية الوصول إلى هذا المورد.";

  @override
  String get oauthRequestFailed => "تعذّر على المزوّد إكمال الطلب.";

  @override
  String get oauthQuotaAvailable => "الحصة متاحة";

  @override
  String oauthSavedResets(String count) => "عدد مرات إعادة تعيين الاستخدام المتاحة: ${count}";

  @override
  String get oauthPrimaryWindow => "الفترة الأساسية";

  @override
  String get oauthSecondaryWindow => "الفترة الثانوية";

  @override
  String get oauthAuthorizationCode => "رمز التفويض أو رابط الاستجابة";

  @override
  String get oauthAuthorizationCodeHint => "إذا لم يعد المتصفح تلقائيًا، الصق رابط الاستجابة النهائي أو رمز التفويض هنا.";

  @override
  String get oauthInvalidAuthorizationCode => "أدخل الرمز أو رابط الاستجابة من محاولة تسجيل الدخول هذه.";

  @override
  String get oauthSubmitAuthorizationCode => "إكمال تسجيل الدخول";

  @override
  String get oauthExtraUsage => "استخدام إضافي";

  @override
  String get oauthMonthlyTotal => "الإجمالي الشهري";

  @override
  String get oauthMonthlyCode => "استخدام البرمجة الشهري";

  @override
  String get oauthSpendCap => "الحد الأقصى للإنفاق من الرصيد";

  @override
  String get oauthOnDemand => "الحصة عند الطلب";

  @override
  String get oauthQuotaAdvisory => "للاسترشاد فقط: قد يجعل تفعيل أرصدة الأسبوع تقدير هذا الحد الشهري غير مؤكد.";

  @override
  String oauthCreditsValue(String value) => "${value} رصيد";

  @override
  String oauthRemainingValue(String value) => "المتبقي: ${value}";

  @override
  String get oauthPromptCachingHelp => "إعادة استخدام السياق بين الرسائل واختيار مدة الاحتفاظ به في الذاكرة المؤقتة.";

  @override
  String get scheduledTasksPreparation => "التنفيذ والإشعارات";

  @override
  String get scheduledTasksAllowPreparation => "السماح بالتحضير المسبق";

  @override
  String get scheduledTasksPreparationDetail => "التحضير المسبق مخصص للمهام النصية التي لا تحتاج إلى معلومات آنية. لا يمكنه استخدام الأدوات أو المرفقات أو تنفيذ إجراءات خارجية.";

  @override
  String get scheduledTasksIOSDetail => "تمنع قيود الخلفية في iOS تطبيق Kelivo من الاستيقاظ في وقت محدد لتشغيل النموذج. بدلًا من ذلك، يتم تجهيز المحتوى أثناء إمكانية تشغيل التطبيق، ثم يعرض النظام إشعارًا في الموعد المحدد. يتم تجهيز التكرار التالي فقط. قد لا يكتمل التحضير بعد مغادرة التطبيق؛ أعد فتح Kelivo لتجهيز التكرارات اللاحقة.";

  @override
  String get scheduledTasksContextPolicy => "سياق المحادثة";

  @override
  String get scheduledTasksContextLatest => "اتباع أحدث محادثة";

  @override
  String get scheduledTasksContextSnapshot => "استخدام اللقطة المُجهّزة";

  @override
  String get scheduledTasksUnavailable => "عند تعذّر التنفيذ";

  @override
  String get scheduledTasksRemind => "إرسال تذكير فقط";

  @override
  String get scheduledTasksSkip => "تخطي هذا التكرار";

  @override
  String get scheduledTasksNotify => "إشعارات النتائج";

  @override
  String get scheduledTasksShowPreview => "إظهار نص النتيجة في الإشعارات";

  @override
  String get scheduledTasksPreparationWindow => "التحضير قبل الموعد بمدة تصل إلى";

  @override
  String get scheduledTasksPreparationAttempts => "الحد الأقصى للمحاولات التلقائية";

  @override
  String get scheduledTasksPreparationCooldown => "الحد الأدنى للفاصل (بالدقائق)";

  @override
  String get scheduledTasksPreparationBudget => "يُسمح بتحضير مهمة واحدة فقط في الوقت نفسه عبر جميع المهام. يتوقف التحضير التلقائي بعد ست محاولات إجمالًا في الساعة، بما في ذلك الطلبات الملغاة. لا يخضع خيار «التحضير الآن» لحد المحاولات.";

  @override
  String get scheduledTasksPreparing => "جارٍ تجهيز النتيجة";

  @override
  String get scheduledTasksPrepared => "تم تجهيز النتيجة";

  @override
  String get scheduledTasksPendingPreparation => "لم يتم تجهيز النتيجة بعد";

  @override
  String get scheduledTasksNotificationRegistered => "تمت جدولة الإشعار";

  @override
  String get scheduledTasksNotificationUnavailable => "لم تتم جدولة الإشعار";

  @override
  String get scheduledTasksReminded => "حان الموعد · تذكير فقط";

  @override
  String get scheduledTasksSkipped => "تم التخطي";

  @override
  String get scheduledTasksCancelled => "تم الإلغاء";

  @override
  String get scheduledTasksReminderBody => "حان موعد المهمة المجدولة. افتح Kelivo للمتابعة.";

  @override
  String get scheduledTasksResultBody => "نتيجة المهمة المجدولة جاهزة.";

  @override
  String get scheduledTasksNotificationPermission => "السماح بإشعارات المهام";

  @override
  String get scheduledTasksPreparationCost => "يستدعي التحضير النموذج وقد يضيف تكلفة. عند اختيار «اتباع أحدث محادثة»، قد تؤدي الرسائل الجديدة قبل الموعد إلى إبطال النتيجة المُجهّزة. قد تُحتسب تكلفة المخرجات غير المستخدمة أو الملغاة، كما أن إعادة التحضير ترسل طلبًا جديدًا إلى النموذج.";

  @override
  String get scheduledTasksAllowPreparationTip => "أنشئ النتيجة التالية قبل موعدها المحدد بينما يستطيع Kelivo العمل. تظل النتيجة خارج المحادثة حتى يحين موعدها. يستخدم التحضير النص فقط دون أدوات أو مرفقات أو أجسام طلب مخصصة، وقد يترتب عليه رسوم من المزوّد.";

  @override
  String get scheduledTasksContextPolicyTip => "اتباع أحدث محادثة: تؤدي الرسائل الجديدة أو التعديلات أو تغيير إصدار الرسالة قبل حلول الموعد إلى إبطال النتيجة المُجهّزة؛ وتحتاج إعادة التحضير إلى محاولة أخرى وقد تكلّف أكثر. عند حلول الموعد، تُضاف نتيجة الإشعار المحفوظة إلى المحادثة دون تغيير.\n\nاستخدام اللقطة المُجهّزة: الاحتفاظ بالنتيجة المُجهّزة حتى إذا تغيرت المحادثة. لن تعكس هذه النتيجة الرسائل اللاحقة.";

  @override
  String get scheduledTasksPreparationWindowTip => "المدة التي يمكن أن يبدأ خلالها التحضير قبل الموعد المحدد، بحد أقصى 24 ساعة. مثلًا، قد يؤدي فتح Kelivo ظهرًا إلى تجهيز تذكير صباح اليوم التالي. تمنح النافذة الأكبر فرصًا أكثر للتحضير، لكن النتيجة قد تكون أقل حداثة. لا تغيّر هذه المدة الموعد المحدد ولا تضمن التنفيذ في الخلفية. يتجاوز خيار «التحضير الآن» فترة الانتظار التلقائية وحدود المحاولات.";

  @override
  String get scheduledTasksPreparationAttemptsTip => "يتوقف التحضير التلقائي عندما يصل هذا التكرار إلى الحد الإجمالي للمحاولات. تُحتسب المحاولة الأولى والإخفاقات والإلغاءات والتحضير اليدوي ضمن السجل. يظل بإمكانك استخدام «التحضير الآن» بعد بلوغ هذا الحد. قد تؤدي المحاولات الإضافية إلى رسوم أعلى من المزوّد؛ وهذا ليس حدًا للإنفاق.";

  @override
  String get scheduledTasksPreparationCooldownTip => "الحد الأدنى للوقت بين بدء محاولات التحضير للتكرار نفسه. يقلل الانتظار الأطول من الطلبات المتكررة. لا تزال إعادة المحاولة تتطلب إمكانية تشغيل التطبيق؛ فهذا ليس مؤقتًا يعمل في الخلفية. يتجاوز «التحضير الآن» فترة الانتظار التلقائية وحدود المحاولات.";

  @override
  String get scheduledTasksUnavailableTip => "إذا لم تكن هناك نتيجة مُجهّزة وتعذّر تشغيل المهمة عند حلول موعدها، فأرسل تذكيرًا أو تخطَّ هذا التكرار. لا يتضمن التذكير إجابة مولّدة، ويتطلب تفعيل الإشعارات. إذا كان Kelivo مفتوحًا عند حلول الموعد، فيمكنه تشغيل المهمة حينها.";

  @override
  String get scheduledTasksNotifyTip => "السماح بإشعارات النتائج والتذكيرات البديلة. لا يؤدي إيقاف هذا الخيار إلى إيقاف المهمة أو استدعاءات النموذج، ولا يمنع رسوم التحضير. يلزم أيضًا منح إذن إشعارات النظام.";

  @override
  String get scheduledTasksShowPreviewTip => "إظهار نص النتيجة المُجهّزة في الإشعار، بما في ذلك شاشة القفل إذا سمحت إعدادات النظام. عطّل هذا الخيار لعرض إشعار عام؛ وستظل النتيجة الكاملة متاحة في المحادثة. تنطبق أيضًا إعدادات الخصوصية العامة للإشعارات.";

  @override
  String scheduledTasksHours(int count) => (count == 1 ? "ساعة واحدة" : intl.Intl.pluralLogic(count, locale: localeName, two: "ساعتان", few: "${count} ساعات", many: "${count} ساعة", other: "${count} ساعة"));

  @override
  String scheduledTasksMinutes(int count) => (count == 1 ? "دقيقة واحدة" : intl.Intl.pluralLogic(count, locale: localeName, two: "دقيقتان", few: "${count} دقائق", many: "${count} دقيقة", other: "${count} دقيقة"));

  @override
  String get scheduledTasksPreparationOff => "التحضير متوقف";

  @override
  String get scheduledTasksPreparationQueued => "في قائمة الانتظار";

  @override
  String get scheduledTasksPreparationQueuedDetail => "يتم حاليًا تحضير مهمة أخرى. وتتابع المهام المؤهلة حسب ترتيب مواعيد استحقاقها.";

  @override
  String get scheduledTasksPreparationIdle => "بانتظار المحادثة";

  @override
  String get scheduledTasksPreparationIdleDetail => "يُستأنف التحضير بعد انتهاء الردود النشطة واستقرار سياق هذه المهمة.";

  @override
  String get scheduledTasksPreparationWindowWaiting => "خارج نافذة التحضير";

  @override
  String get scheduledTasksPreparationCooldownWaiting => "بانتظار إعادة المحاولة";

  @override
  String scheduledTasksPreparationRetryAt(String time) => "يمكن إعادة المحاولة بعد ${time}";

  @override
  String get scheduledTasksPreparationLimitReached => "تم بلوغ الحد التلقائي للمحاولات";

  @override
  String scheduledTasksPreparationAttemptsUsed(int count, int limit) => "استخدم هذا التكرار ${count} محاولة؛ والحد التلقائي هو ${limit}. استخدم «التحضير الآن» للمتابعة يدويًا.";

  @override
  String get scheduledTasksPreparationHourlyLimit => "تم بلوغ الحد التلقائي للساعة";

  @override
  String get scheduledTasksPreparationHourlyLimitDetail => "تم إيقاف التحضير التلقائي مؤقتًا حتى تتوفر سعة خلال الساعة. لا يزال بإمكانك استخدام «التحضير الآن».";

  @override
  String get scheduledTasksPreparationUnavailable => "التحضير غير متاح";

  @override
  String get scheduledTasksPreparationReadFailed => "تعذّرت قراءة سياق المهمة. ستتم إعادة التحقق بعد قليل؛ راجع سجل التنفيذ لمعرفة التفاصيل.";

  @override
  String get scheduledTasksPreparationResultRetained => "تعذّر التحقق من السياق. تم الاحتفاظ بالنتيجة المُجهّزة وستتم إعادة التحقق لاحقًا.";

  @override
  String get scheduledTasksPreparationContextChanged => "تغيرت المحادثة أو سياق المهمة، لذلك تم تجاهل النتيجة السابقة.";

  @override
  String get scheduledTasksPreparationPublishing => "بانتظار الإضافة إلى المحادثة";

  @override
  String get scheduledTasksPreparationPublishingDetail => "ستُضاف النتيجة المحفوظة إلى المحادثة بعد انتهاء الرد الحالي.";

  @override
  String get scheduledTasksPreparationPrompt => "تعليمات التحضير";

  @override
  String get scheduledTasksPreparationPromptTip => "تعليمات نظام إضافية تُستخدم فقط عند تجهيز هذه المهمة مسبقًا، وهي منفصلة عن تعليمات المهمة نفسها. يمكنك تغيير الأسلوب أو إزالة هذه التعليمات بالكامل. تظل الأدوات والمعلومات الآنية غير متاحة. يؤدي تعديل هذه التعليمات إلى إبطال أي نتيجة تم تجهيزها قبل الموعد؛ وقد يترتب على إعادة التحضير رسم آخر من المزوّد.";

  @override
  String get scheduledTasksPreparationPromptEmpty => "اترك الحقل فارغًا لعدم إضافة تعليمات للتحضير.";

  @override
  String scheduledTasksPreparationPromptVariables(String timeVariable, String offsetVariable) => "المتغيرات: ${timeVariable} هو وقت التسليم المحلي المخطط؛ و${offsetVariable} هو فارق التوقيت عن UTC. يتم استبدالهما عند تجهيز النتيجة.";

  @override
  String get scheduledTasksPrepareNow => "التحضير الآن";

  @override
  String get scheduledTasksPrepareNowDetail => "جهّز النتيجة التالية الآن وقدّمها في موعدها المحدد. لا تنطبق فترات الانتظار التلقائية أو حدود المحاولات. قد يترتب على ذلك رسم من المزوّد. ستتم إعادة استخدام أي نتيجة مُجهّزة موجودة.";

  @override
  String get scheduledTasksPrepareNowReady => "النتيجة التالية مُجهّزة بالفعل. لم يتم إرسال طلب إضافي إلى النموذج.";

  @override
  String get scheduledTasksPrepareNowStarted => "جارٍ تجهيز النتيجة التالية لموعدها المحدد.";

  @override
  String get scheduledTasksPrepareNowBusy => "يتم تحضير مهمة أخرى حاليًا. يُرجى المحاولة بعد انتهائها.";

  @override
  String get scheduledTasksPrepareNowChatBusy => "انتظر حتى ينتهي الرد الحالي ثم حاول مجددًا.";

  @override
  String get scheduledTasksPrepareNowDisabled => "فعّل هذه المهمة والتحضير المسبق أولًا. لا يمكن تجهيز المهام التي تعيد إنشاء المحتوى مسبقًا.";

  @override
  String get scheduledTasksPrepareNowUnavailable => "التحضير غير متاح بعد. يُرجى المحاولة بعد قليل.";

  @override
  String get scheduledTasksPrepareNowNoUpcoming => "لا يوجد تكرار قادم للتحضير. تحقق من وقت المهمة وحالة تفعيلها.";

  @override
  String get phoneControlTitle => "التحكم بالهاتف";

  @override
  String get phoneControlSubtitle => "قراءة الشاشة وتنفيذ الإجراءات عبر خدمة إمكانية الوصول";

  @override
  String get phoneControlAccessibilityService => "خدمة إمكانية الوصول";

  @override
  String get phoneControlOpenSettings => "فتح إعدادات إمكانية الوصول";

  @override
  String get phoneControlRefresh => "تحديث الحالة";

  @override
  String get phoneControlChecking => "جارٍ التحقق من حالة الخدمة…";

  @override
  String get phoneControlReady => "مفعّلة ومتّصلة";

  @override
  String get phoneControlDisabled => "غير مفعّلة";

  @override
  String get phoneControlDisconnected => "مفعّلة ولكنها غير متصلة. جرّب إيقاف الخدمة وتشغيلها من إعدادات النظام ثم حدّث الحالة.";

  @override
  String get phoneControlStatusUnavailable => "تعذّرت قراءة حالة الخدمة. حدّث الحالة للمحاولة مجددًا.";

  @override
  String get phoneControlSettingsUnavailable => "تعذّر فتح الإعدادات. افتح إعدادات Android ← إمكانية الوصول يدويًا.";

  @override
  String get phoneControlUsageTitle => "طريقة العمل";

  @override
  String get phoneControlDisclosure => "عند طلب مهام التحكم بالهاتف في المحادثة، يمكن للمساعد قراءة الشاشة الحالية والنقر وإدخال النص والتمرير والتنقل وفتح التطبيقات. يُرسل محتوى الشاشة إلى مزوّد النموذج المحدد لهذه المحادثة، ويُحفظ ضمن نتائج الأدوات. يتم إخفاء حقول كلمات المرور. لا تسجل هذه الخدمة محتوى الشاشة باستمرار. يمكنك إيقاف هذه الأداة للمساعد أو تعطيل الخدمة من إعدادات النظام في أي وقت.";

  @override
  String get phoneControlAssistantTitle => "تفعيل الأداة للمساعد";

  @override
  String get phoneControlAssistantHint => "يلزم منح الإذنين معًا: فعّل التحكم بالهاتف لـ Kelivo من إعدادات إمكانية الوصول في النظام، ثم فعّل «التحكم بالهاتف» ضمن الأدوات المحلية للمساعد (وهي متاحة أيضًا في قائمة أدوات المحادثة). يتم ضبط كل مساعد بشكل منفصل. أبقِ الهاتف مفتوحًا أثناء تنفيذ المهمة.";

  @override
  String get phoneControlRestrictedTitle => "مفتاح إمكانية الوصول غير متاح؟";

  @override
  String get phoneControlRestrictedHint => "بالنسبة إلى بعض ملفات APK التي يتم تنزيلها، يشترط Android تفعيل «السماح بالإعدادات المقيّدة» من قائمة معلومات التطبيق أولًا. اضغط لفتح معلومات تطبيق Kelivo، ثم عُد إلى إعدادات إمكانية الوصول.";

  @override
  String get phoneControlEnableAssistant => "السماح لهذا المساعد بالتحكم بالهاتف";

  @override
  String get composerDraftLabel => "مسودة";

  @override
  String get composerDraftRecovered => "تم استرداد رسالة لم تُرسل.";

  @override
  String get composerDraftRestore => "متابعة التحرير";

  @override
  String get composerDraftDiscard => "تجاهل";

  @override
  String get composerDraftSaveFailed => "تعذّر حفظ أحدث مسودة. لكنها لا تزال مفتوحة في هذه النافذة.";

  @override
  String get composerDraftRetry => "إعادة محاولة الحفظ";

  @override
  String get composerDraftConflictTitle => "توجد مسودة لهذه المحادثة بالفعل";

  @override
  String get composerDraftConflictBody => "تؤدي الإضافة إلى الاحتفاظ بالنصين والمرفقات معًا. أما الاستبدال فيحذف المسودة الحالية. لن يتم إرسال أي شيء تلقائيًا.";

  @override
  String get composerDraftAppend => "إضافة إلى المسودة";

  @override
  String get composerDraftReplace => "استبدال المسودة";

  @override
  String get composerDraftMissingFile => "أحد المرفقات غير متاح. أزله أو اختر الملف مرة أخرى.";

  @override
  String get composerDraftMessageMissing => "لم تعد الرسالة التي يجري تعديلها موجودة. انسخ النص إلى رسالة جديدة أو تجاهل هذا التعديل.";

  @override
  String get composerDraftDeleteNotice => "سيتم أيضًا حذف المسودات غير المرسلة في هذه المحادثات.";

  @override
  String get mcpOAuthSettings => "إعدادات OAuth";

  @override
  String get mcpOAuthAutomatic => "تلقائي";

  @override
  String get mcpOAuthMetadataUrl => "رابط مستند بيانات تعريف العميل";

  @override
  String get mcpOAuthClientAuthentication => "مصادقة العميل";

  @override
  String get mcpOAuthPublicClient => "عميل عام";

  @override
  String get mcpOAuthRedirectUri => "رابط إعادة التوجيه المحلي (اختياري)";

  @override
  String get mcpOAuthFillRedirectExample => "إدراج مثال";

  @override
  String get mcpOAuthRedirectHint => "اتركه فارغًا لاستخدام الإعداد الافتراضي للمنصة. استخدم رابط HTTP محليًا إذا كانت الخدمة لا تسمح إلا بعمليات إعادة التوجيه إلى localhost. يختار المنفذ 0 منفذًا متاحًا؛ وقد يتطلب العميل المسجل مسبقًا منفذًا ثابتًا.";

  @override
  String get mcpOAuthClientIdRequired => "أدخل معرّف العميل أو اختر التسجيل التلقائي.";

  @override
  String get mcpOAuthMetadataUrlInvalid => "أدخل رابط HTTPS صالحًا لمستند بيانات التعريف مع مسار.";

  @override
  String get mcpOAuthSecretRequired => "تتطلب طريقة مصادقة العميل هذه سرّ العميل.";

  @override
  String get mcpOAuthRedirectInvalid => "استخدم رابط إعادة توجيه HTTP إلى localhost أو 127.0.0.1 أو [::1]، دون بيانات اعتماد أو معاملات استعلام أو جزء لاحق.";

  @override
  String get mcpOAuthDiscovering => "جارٍ اكتشاف خادم التفويض…";

  @override
  String get mcpOAuthRegistering => "جارٍ تجهيز التفويض…";

  @override
  String get mcpOAuthWaitingBrowser => "بانتظار التفويض عبر المتصفح…";

  @override
  String get mcpOAuthExchangingToken => "جارٍ إكمال تسجيل الدخول…";

  @override
  String get markdownPlaygroundTitle => "مساحة تجربة Markdown";

  @override
  String get markdownPlaygroundSource => "مصدر Markdown";

  @override
  String get markdownPlaygroundPreview => "معاينة";

  @override
  String get markdownPlaygroundPlay => "عرض الأحرف تدريجيًا";

  @override
  String get markdownPlaygroundPause => "إيقاف مؤقت";

  @override
  String get markdownPlaygroundResume => "استئناف";

  @override
  String get markdownPlaygroundShowAll => "إظهار الكل";

  @override
  String get markdownPlaygroundWidth => "عرض المعاينة";

  @override
  String get markdownPlaygroundTheme => "سمة المعاينة";

  @override
  String get markdownPlaygroundPlain => "النص العادي المحدد";

  @override
  String get markdownPlaygroundMarkdown => "Markdown المحدد";

  @override
  String get markdownPlaygroundSelectionHint => "حدد نصًا في المعاينة لفحص المحتوى الذي سيتم نسخه.";

  @override
  String get markdownPlaygroundEmpty => "أدخل نص Markdown لمعاينته.";

  @override
  String markdownPlaygroundProgress(int shown, int total) => "المدخل: ${shown} / ${total}";

  @override
  String get markdownCopyMarkdownAction => "نسخ Markdown";

  @override
  String get markdownCopyCsvAction => "نسخ CSV";

  @override
  String get markdownCopyImageAction => "نسخ الصورة";

  @override
  String get markdownCodeLabel => "شيفرة";

  @override
  String get markdownDetailsLabel => "تفاصيل";

  @override
  String markdownMoreRows(int count) => "عرض ${count} من الصفوف الإضافية";

  @override
  String get markdownNoteLabel => "ملاحظة";

  @override
  String get markdownTipLabel => "نصيحة";

  @override
  String get markdownImportantLabel => "مهم";

  @override
  String get markdownWarningLabel => "تحذير";

  @override
  String get markdownCautionLabel => "تنبيه";

  @override
  String get markdownDangerLabel => "خطر";

  @override
  String get markdownCopyRichTextAction => "نسخ النص المنسّق";

  @override
  String get markdownCopySelectionFailed => "تعذّر نسخ النص المحدد.";

  @override
  String get recoveryMissingDataTitle => "تم العثور على بيانات سابقة";

  @override
  String get recoveryMissingDataBody => "لم يتمكن Kelivo من العثور على قاعدة بيانات المحادثات الحالية. أوقف التحميل ولم ينشئ قاعدة بيانات فارغة. سنبحث أدناه عن نسخ سابقة، مع الاحتفاظ بالملفات الموجودة.";

  @override
  String get recoveryEmptyDataTitle => "سجل المحادثات الحالي فارغ";

  @override
  String get recoveryEmptyDataBody => "قائمة المحادثات الحالية فارغة، ولكن تم العثور على نسخ سابقة. اختر نسخة أدناه لاستعادة محادثاتك. ستبقى الملفات الموجودة محفوظة.";

  @override
  String get recoveryKeepCurrent => "المتابعة بقائمة محادثات فارغة";

  @override
  String get recoveryKeepCurrentConfirm => "سيؤدي ذلك إلى المتابعة دون استعادة محادثاتك السابقة. ستبقى قائمة المحادثات الحالية فارغة، وستُحفظ النسخ القديمة. إذا أردت استعادة محادثاتك، فألغِ العملية واختر نسخة محلية.";

  @override
  String get recoverySearchingCopies => "جارٍ البحث عن نسخ البيانات المحلية والتحقق منها…";

  @override
  String recoveryFoundCopies(int count) => "تم العثور على ${count} من النسخ التي اجتازت التحقق. اختر إحداها لاستعادة محادثاتك وإعداداتك. ستبقى الملفات الأصلية محفوظة.";

  @override
  String recoveryInvalidCopy(String name) => "${name}: فشل التحقق. تم الاحتفاظ بالملف الأصلي.";

  @override
  String get recoverySearchFailed => "تعذّرت قراءة بعض مواقع البيانات. تم الاحتفاظ بملفاتك؛ صدّر نسخة من البيانات قبل تجربة إجراءات استرداد أخرى.";

  @override
  String get recoveryDiscoveredCopyBody => "تم العثور على النسخة خارج مجلد النسخ المُدار. تم الاحتفاظ بالأصل، وسيتم التحقق منه بالكامل قبل الاستعادة.";

  @override
  String get recoveryStorageFailureTitle => "تخزين البيانات يحتاج إلى عناية";

  @override
  String get recoveryStorageFailureBody => "تعذّر إكمال تحديث البيانات. تم الاحتفاظ بالبيانات الأصلية. حاول فتح Kelivo مجددًا، أو اختر نسخة محلية أدناه للاستعادة.";

  @override
  String get recoveryProtectingTitle => "حماية قاعدة بيانات المحادثات";

  @override
  String get recoveryProtectingData => "جارٍ نسخ قاعدة البيانات والتحقق منها. ستبقى الصور والمرفقات واللقطات في Documents ولن تُنسخ مرة أخرى. سيتم الاحتفاظ بقاعدة البيانات الأصلية.";

  @override
  String get recoveryStorageReadyTitle => "تم نقل قاعدة بيانات المحادثات إلى التخزين الداخلي";

  @override
  String get recoveryStorageReadyBody => "أصبحت قاعدة البيانات التي تحتوي على المحادثات والمساعدين والإعدادات تستخدم مساحة التخزين الداخلية للتطبيق. ستظل اللقطات والصور والمرفقات متاحة في تطبيق الملفات ضمن Documents. تم الاحتفاظ بقاعدة البيانات الأصلية. إذا كانت بعض المحادثات القديمة مفقودة، فافتح الإعدادات ← النسخ الاحتياطي ← النسخ المحلية.";

  @override
  String get recoveryRetainedData => "البيانات الأصلية المحتفظ بها";

  @override
  String get recoveryNoValidCopies => "تم العثور على نسخ، لكن لم تجتز أي منها التحقق. تم الاحتفاظ بالنسخ الأصلية. يمكنك تصدير بياناتك لمزيد من التشخيص.";

  @override
  String get recoveryStorageInsufficientSpaceBody => "لا توجد مساحة تخزين كافية لتجهيز بياناتك بأمان. أفرغ مساحة من إعدادات النظام، ثم افتح Kelivo مجددًا أو أعد فحص النسخ أدناه. أبقِ Kelivo مثبتًا ولا تحذف بياناته أو نسخه المحلية.";

  @override
  String get migrationFreshStartTitle => "أصبح البدء من جديد جاهزًا";

  @override
  String get migrationFreshStartSubtitle => "أصبحت قاعدة بيانات فارغة جديدة جاهزة، وتم الاحتفاظ ببياناتك السابقة. أعد تشغيل التطبيق للمتابعة.";

  @override
  String get migrationFreshStartFailedTitle => "تعذّر إكمال البدء من جديد";

  @override
  String get migrationFreshStartFailedSubtitle => "تم الاحتفاظ ببياناتك السابقة. حاول بدء جلسة جديدة مرة أخرى، أو أغلق التطبيق وافتحه مجددًا.";

  @override
  String get imageExportPreparing => "جارٍ تجهيز الصورة…";

  @override
  String imageExportDiagrams(int completed, int total) => "جارٍ تجهيز المخططات ${completed}/${total}…";

  @override
  String imageExportCapturing(int completed, int total) => "جارٍ التقاط الصورة ${completed}/${total}…";

  @override
  String get imageExportProcessing => "جارٍ دمج الصورة وتجهيز المعاينة…";

  @override
  String get imageExportSaving => "جارٍ حفظ الصورة…";

  @override
  String get backupEncryptionTitle => "تشفير النسخ الاحتياطية";

  @override
  String get backupEncryptionOffHint => "يمكن لأي شخص يملك الملف قراءة النسخ الاحتياطية غير المشفّرة.";

  @override
  String get backupEncryptionOnHint => "النسخ الاحتياطية مشفّرة. أدخل كلمة المرور مرة أخرى بعد إعادة تشغيل التطبيق.";

  @override
  String get backupEncryptionPasswordHint => "احتفظ بكلمة المرور في مكان آمن. إذا فقدتها، فلن تتمكن من استعادة النسخة الاحتياطية. تُحفظ كلمة المرور في الذاكرة حتى الخروج من التطبيق.";

  @override
  String get backupEncryptionPassword => "كلمة المرور";

  @override
  String get backupEncryptionConfirmPassword => "تأكيد كلمة المرور";

  @override
  String get backupEncryptionMismatch => "كلمتا المرور غير متطابقتين.";

  @override
  String get backupEncryptionShowPassword => "إظهار كلمة المرور";

  @override
  String get backupEncryptionHidePassword => "إخفاء كلمة المرور";

  @override
  String get backupEncryptionUnlockTitle => "نسخة احتياطية مشفّرة";

  @override
  String get backupEncryptionUnlockHint => "أدخل كلمة المرور المستخدمة لإنشاء هذه النسخة الاحتياطية.";

  @override
  String get backupEncryptionUnlock => "إلغاء القفل";

  @override
  String get backupEncryptionFailed => "كلمة المرور غير صحيحة أو أن النسخة الاحتياطية تالفة. حاول مجددًا أو ألغِ العملية.";

  @override
  String get backupEncryptionInvalid => "النسخة الاحتياطية المشفّرة غير مكتملة أو غير صالحة.";

  @override
  String get backupEncryptionUnsupported => "تتطلب هذه النسخة الاحتياطية المشفّرة إصدارًا أحدث من Kelivo.";

  @override
  String get backupProgressEncrypting => "جارٍ تشفير النسخة الاحتياطية";

  @override
  String get backupProgressDecrypting => "جارٍ فك تشفير النسخة الاحتياطية";

  @override
  String get mcpPageStatusFailed => "فشل الاتصال";

  @override
  String mcpPageCardToolsShort(int enabled, int total) => "الأدوات ${enabled}/${total}";

  @override
  String mcpPageSelectServer(String name) => "اختيار ${name}";

  @override
  String get mcpIconTitle => "أيقونة الخادم";

  @override
  String get mcpIconInvalid => "تعذّر استخدام هذه الصورة. اختر صورة صالحة لا يتجاوز حجمها 10 MB.";

  @override
  String get mcpSelectServers => "تحديد الخوادم";

  @override
  String get mcpMoveToGroup => "نقل إلى مجموعة";

  @override
  String get mcpRenameGroup => "إعادة تسمية المجموعة";

  @override
  String get mcpDeleteGroupConfirm => "سيتم نقل الخوادم في هذه المجموعة إلى «أخرى». لن يتم حذف الخوادم.";

  @override
  String get mcpGroupNameInvalid => "استخدم اسم مجموعة غير فارغ وفريدًا.";

  @override
  String get mcpEnableSelected => "تفعيل";

  @override
  String get mcpDisableSelected => "تعطيل";

  @override
  String mcpDeleteSelectedConfirm(int count) => "هل تريد حذف ${count} من الخوادم المحددة؟";

  @override
  String get browserTitle => "المتصفح";

  @override
  String get browserSearchHint => "ابحث أو أدخل عنوان موقع";

  @override
  String get browserStartTitle => "إلى أين تريد الذهاب؟";

  @override
  String get browserStartSubtitle => "تصفّح بحرية، ودع وكيلك يساعدك عند الحاجة.";

  @override
  String get browserNewTab => "علامة تبويب جديدة";

  @override
  String get browserTabs => "علامات التبويب";

  @override
  String get browserCloseTab => "إغلاق علامة التبويب";

  @override
  String get browserClose => "إغلاق المتصفح";

  @override
  String get browserBack => "رجوع";

  @override
  String get browserForward => "تقدّم";

  @override
  String get browserReload => "إعادة تحميل";

  @override
  String get browserStop => "إيقاف التحميل";

  @override
  String get browserMore => "المزيد";

  @override
  String get browserBookmarks => "الإشارات المرجعية";

  @override
  String get browserHistory => "السجل";

  @override
  String get browserSettings => "إعدادات المتصفح";

  @override
  String get browserAddBookmark => "إضافة إشارة مرجعية";

  @override
  String get browserRemoveBookmark => "إزالة الإشارة المرجعية";

  @override
  String get browserNoBookmarks => "اجمع مواقعك المفضلة في مكان واحد.";

  @override
  String get browserNoHistory => "سيظهر سجل تصفحك هنا.";

  @override
  String get browserSearchLibrary => "البحث في الصفحات المحفوظة";

  @override
  String get browserClearHistory => "مسح سجل التصفح";

  @override
  String get browserClearHistoryConfirm => "هل تريد حذف سجل التصفح بالكامل؟ ستبقى الإشارات المرجعية محفوظة.";

  @override
  String get browserToday => "اليوم";

  @override
  String get browserYesterday => "أمس";

  @override
  String get browserDelete => "حذف";

  @override
  String get browserCancel => "إلغاء";

  @override
  String get browserDone => "تم";

  @override
  String get browserFind => "بحث في الصفحة";

  @override
  String get browserFindPreviousMatch => "التطابق السابق";

  @override
  String get browserFindNextMatch => "التطابق التالي";

  @override
  String get browserFindHint => "ابحث عن نص";

  @override
  String get browserSearchEngine => "محرك البحث";

  @override
  String get browserDesktopMode => "عرض موقع سطح المكتب";

  @override
  String get browserDesktopModeDescription => "إعادة تحميل الصفحات المفتوحة باستخدام وكيل مستخدم خاص بسطح المكتب.";

  @override
  String get browserRestoreTabs => "استعادة علامات التبويب";

  @override
  String get browserRestoreTabsDescription => "إعادة فتح علامات التبويب عند بدء Kelivo.";

  @override
  String get browserSaveHistory => "حفظ السجل";

  @override
  String get browserSaveHistoryDescription => "الاحتفاظ بسجل محلي للصفحات التي تزورها.";

  @override
  String get browserClearData => "مسح بيانات المواقع";

  @override
  String get browserClearDataConfirm => "هل تريد مسح ملفات تعريف الارتباط والتخزين وذاكرة التخزين المؤقت وإغلاق جميع علامات التبويب؟ سيتم تسجيل خروجك من المواقع.";

  @override
  String get browserDataCleared => "تم مسح بيانات المواقع";

  @override
  String get browserAgentControl => "التحكم بواسطة الوكيل";

  @override
  String get browserAgentWorking => "الذكاء الاصطناعي يعمل";

  @override
  String get browserTakeOver => "تولّي التحكم";

  @override
  String get browserAgentPaused => "تم إيقاف إجراءات الذكاء الاصطناعي مؤقتًا";

  @override
  String get browserAllowAgent => "السماح بالمتابعة";

  @override
  String get browserAgentDescription => "أرسل مهمة في المحادثة للسماح للذكاء الاصطناعي باستخدام المتصفح. السماح له بالمتابعة يزيل الإيقاف المؤقت فقط؛ ولا يرسل رسالة أو يبدأ مهمة.";

  @override
  String get browserOpenExternal => "فتح في المتصفح الافتراضي";

  @override
  String get browserCopyLink => "نسخ الرابط";

  @override
  String get browserLinkCopied => "تم نسخ الرابط";

  @override
  String get browserUnsupported => "المتصفح المضمّن غير متاح على هذه المنصة.";

  @override
  String get browserStorageUnsupported => "يتطلب تطبيق مساحة العمل هذا Android System WebView أو Microsoft Edge WebView2 Runtime بالإصدار 152 أو أحدث. حدّث محرك المتصفح ثم حاول مجددًا.";

  @override
  String get browserLoadFailed => "تعذّر تحميل هذه الصفحة.";

  @override
  String get browserRetry => "إعادة المحاولة";

  @override
  String get browserFavorites => "المفضلة";

  @override
  String get browserEditBookmark => "تعديل الإشارة المرجعية";

  @override
  String get browserBookmarkTitle => "العنوان";

  @override
  String get browserBookmarkUrl => "الموقع الإلكتروني";

  @override
  String get browserSave => "حفظ";

  @override
  String get browserDownloads => "التنزيلات";

  @override
  String get browserNoDownloads => "ستظهر الملفات التي تم تنزيلها هنا.";

  @override
  String get browserDownloadCancel => "إلغاء التنزيل";

  @override
  String get browserOpenDownload => "فتح الملف";

  @override
  String get browserDownloadFailed => "فشل التنزيل";

  @override
  String get browserAgentEnableHint => "فعّل السماح للمساعد بالوصول إلى المتصفح من إعدادات المتصفح. هذا الإذن عام على مستوى التطبيق.";

  @override
  String get browserSessionRequired => "افتح المتصفح من محادثة للسماح بالتحكم بواسطة الوكيل.";

  @override
  String get browserDownloadCancelled => "تم إلغاء التنزيل";

  @override
  String get browserAgentEnabled => "السماح للمساعد بالوصول إلى المتصفح";

  @override
  String get browserAgentEnabledDescription => "يمكن للمساعدين المفعّلين تصفح الصفحات والتفاعل معها في هذا المتصفح.";

  @override
  String get browserToolTitle => "التحكم بالمتصفح";

  @override
  String get browserToolSubtitle => "تصفّح الصفحات التي سجلت الدخول إليها وتفاعل معها. فعّل التحكم بواسطة الوكيل من إعدادات المتصفح أولًا.";

  @override
  String get browserOpen => "فتح المتصفح";

  @override
  String get browserInvalidUrl => "أدخل عنوان موقع صالحًا يبدأ بـ HTTP أو HTTPS.";

  @override
  String get browserClearDataUnavailable => "لا يدعم محرك متصفح Windows مسح جميع بيانات المواقع.";

  @override
  String get browserSurfaceStyle => "نمط المظهر";

  @override
  String get browserSurfaceLiquid => "زجاج سائل";

  @override
  String get browserSurfaceFrosted => "زجاج مصنفر";

  @override
  String get browserSurfaceSolid => "مصمت";

  @override
  String get browserPageOptions => "خيارات الصفحة";

  @override
  String get browserAskAi => "دع الذكاء الاصطناعي يعمل على هذه الصفحة";

  @override
  String get browserAskAiHint => "عُد إلى المحادثة وأضف طلبك ثم أرسله.";

  @override
  String get browserAskAiCurrentPage => "صفحة المتصفح الحالية";

  @override
  String get browserAskAiUnavailable => "هذه المحادثة غير متاحة. افتح المتصفح من محادثة أولًا.";

  @override
  String get browserAskAiEditing => "أنهِ تعديل الرسالة الحالية أو ألغِه قبل إضافة مهمة للصفحة.";

  @override
  String get browserAskAiAssistantDisabled => "فعّل التحكم بالمتصفح ضمن أدوات هذا المساعد أولًا.";

  @override
  String get browserAskAiBrowserDisabled => "اسمح للمساعدين باستخدام المتصفح من إعداداته أولًا.";

  @override
  String browserAskAiDraft(String page) => "استخدم المتصفح للعمل على هذه الصفحة:\n${page}\n\nطلبي:";

  @override
  String get browserOpenFullPage => "فتح في صفحة كاملة";

  @override
  String get browserClosePanel => "إغلاق لوحة المتصفح";

  @override
  String get browserSearchTabs => "البحث في علامات التبويب";

  @override
  String browserTabsCount(int count) => (count == 1 ? "علامة تبويب واحدة" : intl.Intl.pluralLogic(count, locale: localeName, two: "علامتا تبويب", few: "${count} علامات تبويب", many: "${count} علامة تبويب", other: "${count} علامة تبويب"));

  @override
  String get browserOpenInSidebar => "فتح في الشريط الجانبي";

  @override
  String get browserUserAgent => "وكيل المستخدم";

  @override
  String get browserUserAgentMobile => "الهاتف";

  @override
  String get browserUserAgentDesktop => "سطح المكتب";

  @override
  String get browserUserAgentCustom => "مخصص";

  @override
  String get browserUserAgentHint => "أدخل وكيل مستخدم مخصصًا (User-Agent)";

  @override
  String get browserUserAgentInvalid => "استخدم سطرًا واحدًا لا يتجاوز 2048 محرفًا قابلًا للطباعة من ASCII.";

  @override
  String get browserUserAgentDescription => "تؤدي التغييرات إلى إعادة تحميل صفحة الويب الحالية.";

  @override
  String browserStepsShowEarlier(int count) => "عرض ${count} من الخطوات السابقة";

  @override
  String get browserOpenThisPage => "فتح في المتصفح";

  @override
  String get browserGroupToggleSemantics => "إظهار خطوات المتصفح أو إخفاؤها";

  @override
  String get browserStepGroupTitle => "التصفح";

  @override
  String browserStepCount(int count) => "عدد الخطوات: ${count}";

  @override
  String browserStepCurrent(int count) => "الخطوة ${count}";

  @override
  String browserActionFailedCount(int count) => "· فشل ${count}";

  @override
  String browserActionFailed(String action) => "فشل الإجراء ${action}";

  @override
  String get browserCardOpen => "فتح";

  @override
  String get browserCardEnable => "تفعيل";

  @override
  String get browserCardLive => "مباشر";

  @override
  String get browserCardOpenFailed => "تعذّر فتح الصفحة";

  @override
  String get browserCardBlankPage => "صفحة فارغة";

  @override
  String browserCardTabCount(int count) => "عدد علامات التبويب: ${count}";

  @override
  String get browserActionOpen => "فتح الصفحة";

  @override
  String get browserActionNewTab => "علامة تبويب جديدة";

  @override
  String get browserActionRender => "عرض الصفحة";

  @override
  String get browserActionExtract => "استخراج النص";

  @override
  String get browserActionSnapshot => "قراءة بنية الصفحة";

  @override
  String get browserActionClick => "نقر";

  @override
  String get browserActionType => "كتابة";

  @override
  String get browserActionPress => "ضغط مفتاح";

  @override
  String get browserActionScroll => "تمرير";

  @override
  String get browserActionWait => "انتظار";

  @override
  String get browserActionBack => "رجوع";

  @override
  String get browserActionForward => "تقدّم";

  @override
  String get browserActionReload => "إعادة تحميل";

  @override
  String get browserActionEvaluate => "تشغيل سكربت";

  @override
  String get browserActionSwitchTab => "التبديل بين علامات التبويب";

  @override
  String get browserActionCloseTab => "إغلاق علامة التبويب";

  @override
  String get browserActionListTabs => "عرض علامات التبويب";

  @override
  String get browserActionUnknown => "إجراء متصفح";

  @override
  String browserMetaChars(String count) => "${count} محرفًا";

  @override
  String browserMetaElements(int count) => "${count} عنصرًا";

  @override
  String get browserErrAgentDisabled => "التحكم بالمتصفح متوقف";

  @override
  String get browserErrStaleRef => "العنصر قديم؛ يجب إعادة قراءة الصفحة";

  @override
  String get browserErrNotVisible => "العنصر مخفي أو محجوب";

  @override
  String get browserErrNotFound => "لم يتم العثور على العنصر";

  @override
  String get browserErrTimeout => "انتهت مهلة تحميل الصفحة";

  @override
  String get browserErrHumanControl => "أنت تتحكم بالمتصفح";

  @override
  String get browserErrTabClosed => "تم إغلاق علامة التبويب";

  @override
  String get browserErrGeneric => "فشل الإجراء";

  @override
  String get browserDirectionUp => "أعلى";

  @override
  String get browserDirectionDown => "أسفل";

  @override
  String get browserDirectionLeft => "يسار";

  @override
  String get browserDirectionRight => "يمين";

  @override
  String browserMetaTabs(int count) => "عدد علامات التبويب: ${count}";

  @override
  String get browserTabsCurrentConversation => "هذه المحادثة";

  @override
  String get browserTabsAll => "كل علامات التبويب";

  @override
  String get browserTabsUnassigned => "علامات التبويب الشخصية";

  @override
  String get browserTabsUnknownConversation => "محادثة أخرى";

  @override
  String get browserTabsEmptyConversation => "لا توجد علامات تبويب هنا بعد. افتح صفحة أو اختر علامة تبويب من «كل علامات التبويب».";

  @override
  String get browserTabsNoResults => "لا توجد علامات تبويب مطابقة.";

  @override
  String get browserMoveToConversation => "نقل إلى هذه المحادثة";

  @override
  String get browserReopenInConversation => "إعادة الفتح في هذه المحادثة";

  @override
  String get browserTabBusy => "لا يزال أحد المساعدين يستخدم هذه الصفحة. انتظر حتى ينتهي أو أوقف المهمة قبل نقلها.";

  @override
  String get browserLiveViewLimit => "جميع موارد المتصفح قيد الاستخدام. حاول مجددًا بعد انتهاء إحدى المهام أو أغلق صفحة غير مستخدمة.";

  @override
  String get browserAskAiInOwnerConversation => "اسأل الذكاء الاصطناعي في المحادثة المالكة";

  @override
  String get displaySettingsPageShowBrowserPageCardsTitle => "إظهار بطاقات صفحات الويب";

  @override
  String get browserObserverHint => "يستخدم الذكاء الاصطناعي هذه الصفحة. اختر «تولّي التحكم» للتفاعل معها.";

  @override
  String get genuiSurfaceTitle => "واجهة تفاعلية";

  @override
  String get genuiStatusStreaming => "جارٍ التوليد";

  @override
  String get genuiStatusInterrupted => "تمت المقاطعة";

  @override
  String get genuiStatusUnsaved => "غير محفوظ";

  @override
  String get genuiStatusUnsavedRetry => "اضغط لإعادة محاولة الحفظ";

  @override
  String get genuiReadOnlyUntilComplete => "ستصبح متاحة بعد اكتمال التوليد";

  @override
  String get genuiReadOnlySnapshot => "لقطة للقراءة فقط";

  @override
  String genuiPendingNode(String id) => "بانتظار ${id}";

  @override
  String get genuiViewSource => "عرض المصدر";

  @override
  String get genuiCopySource => "نسخ المصدر";

  @override
  String get genuiExpand => "توسيع";

  @override
  String get genuiExpandedStub => "قيد التحرير في العرض الموسّع";

  @override
  String get genuiMore => "المزيد";

  @override
  String get genuiReset => "استعادة الإعدادات الافتراضية";

  @override
  String get genuiRepair => "إصلاح الواجهة";

  @override
  String get genuiInvalidTitle => "تعذّر عرض هذه الواجهة";

  @override
  String genuiNodesFailed(int count) => (count == 1 ? "تعذّر عرض عقدة واحدة" : intl.Intl.pluralLogic(count, locale: localeName, two: "تعذّر عرض عقدتين", few: "تعذّر عرض ${count} عقد", many: "تعذّر عرض ${count} عقدة", other: "تعذّر عرض ${count} عقدة"));

  @override
  String genuiErrorLine(int line) => "السطر ${line}";

  @override
  String get genuiValueUnavailable => "لا توجد قيمة";

  @override
  String get genuiFormulaInvalid => "تعذّر عرض هذه الصيغة";

  @override
  String get genuiNodeUnavailable => "هذا المكوّن غير متاح";

  @override
  String get genuiErrorHeader => "ترويسة واجهة غير صالحة";

  @override
  String get genuiErrorVersion => "إصدار لغة الواجهة غير مدعوم";

  @override
  String get genuiErrorCatalog => "كتالوج المكوّنات غير مدعوم";

  @override
  String get genuiErrorRoot => "المكوّن الجذر مفقود أو غير صالح";

  @override
  String get genuiErrorSyntax => "صياغة تعريف غير صالحة";

  @override
  String get genuiErrorDuplicateSymbol => "تم تعريف الاسم أكثر من مرة";

  @override
  String get genuiErrorDuplicateProperty => "تم تعريف الخاصية أكثر من مرة";

  @override
  String get genuiErrorReservedName => "هذا الاسم محجوز";

  @override
  String genuiErrorUnknownComponent(String detail) => "مكوّن غير معروف: ${detail}";

  @override
  String genuiErrorUnknownProperty(String detail) => "خاصية غير معروفة: ${detail}";

  @override
  String genuiErrorMissingProperty(String detail) => "الخاصية المطلوبة ${detail} مفقودة";

  @override
  String get genuiErrorBinding => "ربط إدخال قابل للكتابة غير صالح";

  @override
  String get genuiErrorReference => "مرجع المكوّن غير صالح";

  @override
  String get genuiErrorMissingReference => "لم يتم تعريف المحتوى المشار إليه";

  @override
  String get genuiErrorDependency => "تعذّر عرض المحتوى المطلوب";

  @override
  String get genuiErrorCycle => "المراجع الدائرية غير مدعومة";

  @override
  String get genuiErrorDuplicateParent => "لا يمكن أن يكون للمكوّن أبوان";

  @override
  String get genuiErrorUnreachableNode => "هذا المكوّن خارج الشجرة الجذرية";

  @override
  String get genuiErrorType => "نوع القيمة غير متوافق";

  @override
  String get genuiErrorValue => "القيمة خارج الخيارات أو النطاق المدعوم";

  @override
  String get genuiErrorSourceBudget => "يتجاوز مصدر الواجهة حد الحجم";

  @override
  String get genuiErrorDeclarationBudget => "يتجاوز أحد التعريفات حد الحجم";

  @override
  String get genuiErrorDeclarationCount => "عدد التعريفات أكبر من المسموح";

  @override
  String get genuiErrorComponentCount => "عدد المكوّنات أكبر من المسموح";

  @override
  String get genuiErrorInputCount => "عدد المدخلات أكبر من المسموح";

  @override
  String get genuiErrorComponentDepth => "تداخل المكوّنات أعمق من المسموح";

  @override
  String get genuiErrorExpressionDepth => "تداخل العمليات الحسابية أعمق من المسموح";

  @override
  String get genuiErrorFunction => "دالة حسابية غير معروفة";

  @override
  String get genuiErrorAction => "إجراء غير مدعوم";

  @override
  String get genuiErrorNestedSample => "أخذ العينات المتداخل غير مدعوم";

  @override
  String get genuiErrorSample => "نطاق أو عدد العينات غير صالح";

  @override
  String get genuiErrorDataBudget => "تتجاوز البيانات الحجم المدعوم";

  @override
  String get genuiErrorRowKey => "يجب أن تحتوي الصفوف على مفاتيح فريدة وغير فارغة";

  @override
  String get genuiErrorDomain => "القيمة خارج نطاق الدالة";

  @override
  String get genuiErrorDivisionByZero => "القسمة على صفر غير معرّفة";

  @override
  String get genuiErrorNonFinite => "أنتج الحساب رقمًا غير منتهٍ";

  @override
  String get genuiErrorOperationsBudget => "تجاوز الحساب حد العمليات";

  @override
  String genuiMetricTrend(String value) => "التغيير ${value}";

  @override
  String genuiFormErrorsLeft(int count) => (count == 1 ? "هناك حقل واحد يحتاج إلى مراجعة" : intl.Intl.pluralLogic(count, locale: localeName, two: "هناك حقلان يحتاجان إلى مراجعة", few: "هناك ${count} حقول تحتاج إلى مراجعة", many: "هناك ${count} حقلًا يحتاج إلى مراجعة", other: "هناك ${count} حقل يحتاج إلى مراجعة"));

  @override
  String get genuiFieldRequired => "مطلوب";

  @override
  String genuiNumberRange(String min, String max) => "النطاق ${min}–${max}";

  @override
  String genuiNumberMinimum(String min) => "الحد الأدنى ${min}";

  @override
  String genuiNumberMaximum(String max) => "الحد الأقصى ${max}";

  @override
  String genuiFieldTooShort(int min) => "يجب ألا يقل عن ${min} حرفًا";

  @override
  String genuiFieldTooLong(int max) => "يجب ألا يزيد عن ${max} حرفًا";

  @override
  String get genuiInvalidNumber => "أدخل رقمًا كاملًا ومنتهيًا صالحًا";

  @override
  String get genuiChooseOption => "اختر خيارًا";

  @override
  String get genuiFinishComposing => "أكمل الكتابة قبل المتابعة";

  @override
  String genuiActionDisabledDep(String id) => "معطّل: يعتمد على ${id} الذي تعذّر عرضه";

  @override
  String get genuiActionUnavailable => "هذا الإجراء غير متاح في هذا العرض";

  @override
  String get genuiActionDisabled => "تم تعطيله بواسطة هذه الواجهة";

  @override
  String get genuiFormUnavailable => "يحتوي هذا النموذج على محتوى تعذّر عرضه";

  @override
  String genuiDecrease(String label) => "تقليل ${label}";

  @override
  String genuiIncrease(String label) => "زيادة ${label}";

  @override
  String genuiCharacterCount(int used, int max) => "${used} / ${max} حرفًا";

  @override
  String get genuiBlockLimit => "يُسمح بما يصل إلى 3 كتل واجهة في الرسالة؛ وتُعرض الكتل الأخرى كمصدر.";

  @override
  String get genuiChartLine => "مخطط خطي";

  @override
  String get genuiChartArea => "مخطط مساحي";

  @override
  String get genuiChartBar => "مخطط أعمدة";

  @override
  String get genuiChartScatter => "مخطط مبعثر";

  @override
  String get genuiChartPie => "مخطط دائري";

  @override
  String get genuiChartDonut => "مخطط حلقي";

  @override
  String get genuiChartEmpty => "لا توجد بيانات في هذا النطاق";

  @override
  String get genuiChartAllHidden => "جميع السلاسل مخفية. استخدم وسيلة الإيضاح لإظهار إحداها.";

  @override
  String genuiChartSummary(String kind, int series, int points, int missing) => "${kind}، سلاسل البيانات: ${series}، صفوف البيانات: ${points}، القيم المفقودة: ${missing} (غير متصلة أو استُبدلت بصفر).";

  @override
  String genuiChartPieSummary(String kind, int count, String total) => "${kind}، " + (count == 1 ? "عنصر واحد" : intl.Intl.pluralLogic(count, locale: localeName, two: "عنصران", few: "${count} عناصر", many: "${count} عنصرًا", other: "${count} عنصر")) + "، الإجمالي ${total}.";

  @override
  String get genuiChartDomainGap => "غير معرّف";

  @override
  String genuiChartDomainSummary(int count) => (count == 1 ? "نقطة واحدة مأخوذة من العينة غير معرّفة" : intl.Intl.pluralLogic(count, locale: localeName, two: "نقطتان مأخوذتان من العينة غير معرّفتين", few: "${count} نقاط مأخوذة من العينة غير معرّفة", many: "${count} نقطة مأخوذة من العينة غير معرّفة", other: "${count} نقطة مأخوذة من العينة غير معرّفة")) + "؛ لا يتم وصل الفجوات المظللة.";

  @override
  String genuiChartShowSeries(String name) => "إظهار ${name}";

  @override
  String genuiChartHideSeries(String name) => "إخفاء ${name}";

  @override
  String get genuiChartKeyboardHint => "يحدد السهمان الأيمن والأيسر صف بيانات. ويحدد السهمان الأعلى والأسفل سلسلة بيانات. يمسح Escape التحديد.";

  @override
  String get genuiChartTotal => "الإجمالي";

  @override
  String get genuiChartFieldsError => "اختر حقل X وحقلًا واحدًا إلى أربعة حقول Y مختلفة.";

  @override
  String get genuiChartRecordsError => "يجب أن تكون بيانات المخطط قائمة من السجلات.";

  @override
  String get genuiChartXError => "يجب أن تكون جميع قيم X أرقامًا أو نصوصًا. تتطلب المخططات المبعثرة قيمًا رقمية.";

  @override
  String get genuiChartYError => "يجب أن تكون حقول Y موجودة وأن تحتوي على أرقام أو قيم مفقودة.";

  @override
  String get genuiChartPieError => "يجب أن تكون قيم المخطط الدائري غير سالبة وأن يكون مجموعها النهائي أكبر من صفر.";

  @override
  String genuiChartMissingValues(int count) => (count == 1 ? "هناك قيمة واحدة مفقودة، ولا يتم استبدالها بصفر." : intl.Intl.pluralLogic(count, locale: localeName, two: "هناك قيمتان مفقودتان، ولا يتم استبدالهما بصفر.", few: "هناك ${count} قيم مفقودة، ولا يتم استبدالها بصفر.", many: "هناك ${count} قيمة مفقودة، ولا يتم استبدالها بصفر.", other: "هناك ${count} قيمة مفقودة، ولا يتم استبدالها بصفر."));

  @override
  String get genuiChartNoVisibleValues => "لا تحتوي السلاسل المحددة على قيم يمكن رسمها.";

  @override
  String genuiChartUnit(String unit) => "الوحدة: ${unit}";

  @override
  String get genuiSomeValuesUnavailable => "بعض القيم غير متاحة";

  @override
  String get genuiViewChart => "مخطط";

  @override
  String get genuiViewData => "بيانات";

  @override
  String get genuiTableFilterHint => "تصفية النص الظاهر";

  @override
  String genuiTableRows(int count) => (count == 1 ? "صف واحد" : intl.Intl.pluralLogic(count, locale: localeName, two: "صفّان", few: "${count} صفوف", many: "${count} صفًا", other: "${count} صف"));

  @override
  String genuiTablePageInfo(int from, int to, int total) => "الصفوف ${from}–${to} من ${total}";

  @override
  String genuiTablePerPage(int n) => "${n} / صفحة";

  @override
  String get genuiTableEmpty => "لا توجد صفوف مطابقة";

  @override
  String get genuiSortAsc => "مرتّب تصاعديًا";

  @override
  String get genuiSortDesc => "مرتّب تنازليًا";

  @override
  String get genuiSortNone => "غير مرتّب";

  @override
  String get genuiValueTrue => "صحيح";

  @override
  String get genuiValueFalse => "خطأ";

  @override
  String get genuiTablePreviousPage => "الصفحة السابقة";

  @override
  String get genuiTableNextPage => "الصفحة التالية";

  @override
  String get genuiTableCellsError => "يجب أن تحتوي بيانات الجدول على سجلات ذات قيم مفردة محدودة أو قيم مفقودة.";

  @override
  String get genuiTableColumnsError => "اختر من حقل إلى ثمانية حقول مختلفة بعناوين وأرقام اختيارية من 0 إلى 10.";

  @override
  String get genuiTableRowKeyError => "يجب أن يحتوي كل صف على مفتاح مفرد غير فارغ.";

  @override
  String get genuiViewStateFailed => "يتجاوز تغيير العرض حد الحالة المحفوظة. اختصر أحد الحقول أو أعد ضبط الواجهة ثم حاول مجددًا.";

  @override
  String get genuiAttachState => "إرفاق الحالة الحالية";

  @override
  String get genuiChipExactText => "النص الدقيق الذي سيتم إرساله (مجمّد)";

  @override
  String get genuiChipStale => "المصدر غير متاح — أزله أو أعد إرفاقه";

  @override
  String get genuiChipRemove => "إزالة الواجهة المرفقة";

  @override
  String get genuiReplaceTitle => "استبدال الواجهة المرفقة؟";

  @override
  String get genuiReplaceBody => "يمكن أن تحتوي المسودة على حالة واجهة واحدة فقط.";

  @override
  String get genuiReplaceCurrent => "الحالية";

  @override
  String get genuiReplaceNew => "استبدالها بـ";

  @override
  String get genuiReplaceConfirm => "استبدال";

  @override
  String get genuiMergeTitle => "إضافة إلى مسودتك؟";

  @override
  String get genuiMergeConfirm => "إضافة";

  @override
  String get genuiContextEmpty => "لم يتم إرفاق أي حقول للمعاملات أو النتائج.";

  @override
  String get genuiContextOmitted => "[تم إغفال بعض الحقول أو صفوف البيانات.]";

  @override
  String get genuiChipOmitted => "حالة الواجهة المرفقة سابقًا غير متاحة، ولم يتم تضمينها.";

  @override
  String get genuiDraftChanged => "تغيرت مسودتك. حاول إرفاقها مرة أخرى.";

  @override
  String get genuiRepairDraft => "يرجى إصلاح هذه الواجهة باستخدام التشخيص ومقتطفات المصدر أدناه.";

  @override
  String get genuiCopySourceMarkdown => "نسخ المصدر / Markdown";

  @override
  String get genuiTextFailed => "تعذّرت قراءة حالة الواجهة. حاول مجددًا.";

  @override
  String get genuiCopyLimit => "يتجاوز النص حد النسخ البالغ 64 KiB. حدد قسمًا أصغر.";

  @override
  String get genuiExportSnapshot => "تصدير لقطة للقراءة فقط";

  @override
  String get genuiExpandedSharedState => "تشارك الحالة نفسها مع الرسالة";

  @override
  String get genuiExportTooLarge => "تتجاوز هذه الصورة 16 ميغابكسل. حدد عددًا أقل من الرسائل أو صدّر واجهة أصغر.";

  @override
  String get genuiWebTitle => "معاينة الويب";

  @override
  String get genuiWebOpen => "فتح";

  @override
  String get genuiWebNotReady => "يمكن فتحها بعد اكتمال التوليد";

  @override
  String get genuiWebInvalidMeta => "ترويسة غير صالحة؛ لم يتم التحميل";

  @override
  String get genuiWebSandboxNote => "معاينة معزولة · يتم التخلص منها عند الإغلاق";

  @override
  String get genuiWebUnsupported => "معاينات الويب غير مدعومة على هذه المنصة. صدّرها لفتحها في متصفح.";

  @override
  String get genuiWebExportHtml => "تصدير HTML";

  @override
  String get genuiWebInfo => "معلومات المعاينة";

  @override
  String get genuiWebCspNote => "CSP: default-src none · وصول مقيّد إلى الشبكة · حالة صفحة معزولة";

  @override
  String get genuiWebFailed => "فشل تهيئة المعاينة أو تحميلها. اعرض المصدر أو انسخه.";

  @override
  String get genuiWebEmpty => "لا يوجد مستند HTML بعد الترويسة.";

  @override
  String get genuiWebBlockLimit => "يُسمح بما يصل إلى 3 معاينات ويب في الرسالة؛ وتُعرض المعاينات الأخرى كمصدر.";

  @override
  String get genuiWebCloseFailed => "تعذّر تأكيد إغلاق المعاينة السابقة. أعد تشغيل التطبيق قبل فتح معاينة أخرى.";

  @override
  String get displaySettingsShowGenUiHeader => "إظهار شريط عنوان الواجهة التفاعلية";

  @override
  String get displaySettingsShowGenUiHeaderSubtitle => "أخفِه للحصول على رسالة أكثر بساطة. سيظل المصدر والإجراءات متاحين في القائمة أسفل الواجهة.";

  @override
  String get genuiClearFilter => "مسح عامل التصفية";

  @override
  String get genuiClearSelection => "مسح التحديد";

  @override
  String get chatInputBarQueuedPausedReason => "لم يكتمل الضغط، لذلك سيظل الإرسال متوقفًا مؤقتًا.";

  @override
  String get contextChanged => "تم تغيير السجل. أعد فتح هذا الإجراء لمراجعة نطاقه الحالي.";

  @override
  String get contextOperationSuperseded => "تم تضمينه في ملخص لاحق";

  @override
  String get compressIncludeAttachments => "نص المرفقات ونتائج الأدوات";

  @override
  String contextEditCharacters(int count) => "${count} حرفًا";

  @override
  String get compressOverSnack => "سيتجاوز الملخص حد السياق، لذلك لم يتم تطبيقه.";

  @override
  String get contextSummaryHint => "هذا هو الملخص المستخدم في الطلبات اللاحقة. لا تؤدي التغييرات المحفوظة إلى إعادة كتابة الردود الموجودة. لا تسهم المرفقات إلا بالنص المتاح؛ ولا تتم إعادة تفسير الصور.";

  @override
  String get compressAdvanced => "متقدم";

  @override
  String get compressTaskWaiting => "بانتظار انتهاء الرد الحالي";

  @override
  String get contextBudgetExceeded => "يتجاوز السياق المقدّر حد هذا النموذج. اختصر الملخص أو أعد الضغط أو اختر نموذجًا ذا سياق أكبر.";

  @override
  String get contextManualSupplement => "تضمين الملخصات المعدّلة يدويًا كإضافات";

  @override
  String get contextDetailEdited => "معدّل يدويًا";

  @override
  String get contextSourceLabel => "مدخل الملخص";

  @override
  String get contextImpactSourceTitle => "تغيير الرسائل الأصلية التي تم ضغطها؟";

  @override
  String get chatInputBarQueuedCompressionFailed => "فشل الضغط، لذلك سيظل الإرسال متوقفًا مؤقتًا.";

  @override
  String contextTokenInfo(int before, int after) => "مدخل الملخص ≈ ${before} رمزًا ← الملخص ≈ ${after} رمزًا";

  @override
  String get worldBookTransferFailed => "تعذّر حفظ المدخلات. يُرجى المحاولة مرة أخرى.";

  @override
  String contextDetailKeptCount(int count) => "أحدث ${count} من رسائل المستخدم والردود والأدوات";

  @override
  String get toolPermissionRequestApproval => "طلب الموافقة";

  @override
  String get compressNothingNew => "لا يوجد محتوى جديد لضغطه منذ آخر ملخص.";

  @override
  String get browserActionScreenshot => "التقاط لقطة شاشة";

  @override
  String get displaySettingsPageIosNativeSelectionMenuSubtitle => "ينطبق على حقول الإدخال والرسائل. عطّله إذا كانت القوائم بطيئة.";

  @override
  String contextUndoneSnack(String from, String to) => "تم التراجع · ${from} ← ${to}";

  @override
  String get toolApprovalByFullAccess => "تم التشغيل تلقائيًا";

  @override
  String get displaySettingsPageAutoScrollSubtitle => "أثناء البث، تابع المحتوى الجديد عندما تكون في أسفل المحادثة. يؤدي التمرير إلى الأعلى إلى إيقاف المتابعة مؤقتًا حتى تعود إلى الأسفل. عند التعطيل، لن يتم التمرير تلقائيًا مع المحتوى الجديد.";

  @override
  String get toolApprovalRealTarget => "الهدف الفعلي";

  @override
  String get compressTaskRetry => "إعادة المحاولة";

  @override
  String get wsDeniedPathOutside => "الوجهة خارج النطاق المصرّح به. تم الرفض.";

  @override
  String contextImpactSaveConfirm(int count) => "حفظ التغييرات والتراجع عن ${count} من العقد";

  @override
  String get contextRestore => "استعادة";

  @override
  String compressUsageOriginal(String value) => "كانت ${value}";

  @override
  String toolApprovalPendingKind(String kind) => "بانتظار الموافقة · ${kind}";

  @override
  String get contextTaskApplying => "جارٍ تطبيق الملخص";

  @override
  String get storageSpaceImagesHint => "يؤثر حذف الصور في سجل المحادثات ونتائج الأدوات. تتم حماية الصور الرمزية والخلفيات المستخدمة.";

  @override
  String get displaySettingsPageIosNativeSelectionMenuTitle => "قائمة التحديد الأصلية في iOS 26+";

  @override
  String get worldBookMoveEntries => "نقل إلى…";

  @override
  String get compressReread => "إعادة قراءة المحتوى الأصلي المضغوط";

  @override
  String get chatInputBarQueuedPausedHold => "ما زال الإدخال متوقفًا مؤقتًا؛ ألغِ قائمة الانتظار لتتمكن من التعديل أو الإرسال.";

  @override
  String get contextSummaryTitle => "ملخص السياق";

  @override
  String get contextKeepInvalid => "أدخل عددًا موجبًا من رسائل المستخدم.";

  @override
  String get compressTaskAbandon => "تجاهل";

  @override
  String get browserAgentTimedOut => "انتهت مهلة العملية؛ تم إيقاف الذكاء الاصطناعي مؤقتًا.";

  @override
  String get compressCancelledSnack => "تم إلغاء ضغط السياق. لم يتغير السياق الحالي.";

  @override
  String get contextImpactClearTitle => "هل تريد التراجع عن المسح السابق؟";

  @override
  String get compressTaskWaitingApproval => "بانتظار الموافقة على الأداة";

  @override
  String get contextTaskFailed => "فشل ضغط السياق";

  @override
  String get wsDeniedSkillsReadonly => "مجلد Skills للقراءة فقط.";

  @override
  String get compressTaskMerging => "جارٍ دمج الملخصات";

  @override
  String get toolPermissionFullAccessDesc => "يسمح لهذه المحادثة بالوصول إلى الملفات على هذا الجهاز وتشغيل الأوامر واستخدام الأدوات المتصلة بالإنترنت دون طلب الموافقة في كل مرة.";

  @override
  String get compressStaleSnack => "تغيّر سجل المحادثة؛ لم يتم تطبيق الملخص.";

  @override
  String get worldBookCopyEntries => "نسخ إلى…";

  @override
  String get contextEditEmpty => "لا يمكن أن يكون الملخص فارغًا. استخدم «مسح السياق» لاستبعاد السجل السابق بالكامل.";

  @override
  String get toolApprovalDenyWithReason => "رفض مع ذكر السبب…";

  @override
  String get toolApprovalRequestedPath => "المسار المطلوب";

  @override
  String get toolApprovalScopeOnce => "ينطبق على هذا الاستدعاء فقط";

  @override
  String get storageSpaceImageTypeLabel => "النوع";

  @override
  String get contextImpactUndoTitle => "هل تريد التراجع عن الضغط السابق؟";

  @override
  String get contextOriginalMessages => "عرض الرسائل الأصلية";

  @override
  String storageSpaceDeleteImagesConfirmMessage(int count) => "هل تريد حذف ${count} صورة؟ لن تعود صور المحادثة المرتبطة ولقطات الأدوات ونسخ المحادثة متاحة. وستبقى الصور الرمزية والخلفيات المستخدمة حاليًا محفوظة.";

  @override
  String get chatInputBarQueuedAfterCompress => "سيتم الإرسال بعد الضغط";

  @override
  String get toolPermissionFullAccessDescMobile => "يسمح لهذه المحادثة بتشغيل الأدوات تلقائيًا داخل البيئة المعزولة والمجلدات المصرّح بها دون طلب الموافقة في كل مرة.";

  @override
  String get compressTaskAdjustRetry => "عدّل الخيارات ثم أعد المحاولة";

  @override
  String get contextDetailLegacy => "تم تحويله من عملية مسح قديمة";

  @override
  String get contextDetailCurrent => "السياق الحالي";

  @override
  String get toolPermissionUndo => "تراجع";

  @override
  String get contextDetailViewOriginals => "عرض النسخ الأصلية";

  @override
  String get contextTaskCompleted => "اكتمل ضغط السياق";

  @override
  String get chatInputBarQueuedPaused => "متوقف مؤقتًا";

  @override
  String get contextCompressMarker => "تم ضغط السياق";

  @override
  String contextDetailParts(int count) => "${count} مقاطع";

  @override
  String get contextEditPending => "تم الحفظ؛ سيُطبّق بعد الرد الحالي";

  @override
  String get contextTaskRetry => "إعادة محاولة الضغط";

  @override
  String get contextUndoCompressTooltip => "التراجع عن هذا الضغط";

  @override
  String get contextDividerCompressed => "تم ضغط السياق";

  @override
  String compressSuccessSnack(String from, String to) => "تم ضغط السياق · ${from} ← ${to}";

  @override
  String get contextEffectiveHistory => "الملخص الحالي والرسائل اللاحقة";

  @override
  String get compressRereadAll => "كل النسخ الأصلية في المقطع";

  @override
  String get contextDone => "تم";

  @override
  String get contextMore => "المزيد";

  @override
  String compressFailedSnack(String reason) => "فشل ضغط السياق: ${reason}";

  @override
  String get branchInheritNote => "يرث فقط عقد السياق النشطة قبل هذه النقطة";

  @override
  String get contextTaskInterrupted => "انقطع ضغط السياق؛ تم الاحتفاظ بالإدخال.";

  @override
  String get storageSpaceImageTypeAll => "الكل";

  @override
  String contextRangeInfo(int count, int keep) => "يستبدل ${count} رسالة، ويحتفظ بآخر ${keep} رسالة من المستخدم والردود المرتبطة بها.";

  @override
  String contextInputModeInfo(String mode, String source) => "الإدخال: ${mode} · المصدر: ${source}";

  @override
  String get contextDetailKept => "تم الاحتفاظ به";

  @override
  String worldBookEntriesCopied(int count) => (count == 1 ? "تم نسخ مدخل واحد" : intl.Intl.pluralLogic(count, locale: localeName, two: "تم نسخ مدخلين", few: "تم نسخ ${count} مدخلات", many: "تم نسخ ${count} مدخلًا", other: "تم نسخ ${count} مدخل"));

  @override
  String get toolPermissionSaveFailed => "تعذّر الحفظ. لم تتغير الأذونات.";

  @override
  String get compressDiscardedSnack => "تم مسح السياق والتخلّص من عملية الضغط الجارية.";

  @override
  String get browserActionSelect => "اختيار خيار";

  @override
  String get toolPermissionTitle => "الأذونات";

  @override
  String get contextDetailNext => "الطلب التالي";

  @override
  String get contextTaskCancel => "إلغاء الضغط";

  @override
  String get toolPermissionFullAccess => "وصول كامل";

  @override
  String get chatInputBarQueuedCompressionCancelled => "تم إلغاء الضغط؛ وسيظل الإرسال متوقفًا مؤقتًا.";

  @override
  String get toolPermissionResetSnack => "تغيّرت مساحة العمل · أُعيد ضبط الإذن إلى «طلب الموافقة»";

  @override
  String get contextImpactUndoOne => "تراجع";

  @override
  String get contextDetailContinueNewChat => "المتابعة في محادثة جديدة";

  @override
  String get contextTaskPaused => "الإرسال متوقف مؤقتًا — ألغِ قائمة الانتظار للتعديل";

  @override
  String get contextTaskReview => "راجع الملخص قبل تطبيقه";

  @override
  String compressApproxTokens(String value) => "نحو ${value} رمزًا";

  @override
  String get storageSpaceImageInUseHint => "غيّر هذه الصورة الرمزية أو الخلفية أو الأيقونة أو أزلها من إعداداتها قبل حذفها.";

  @override
  String get compressRereadLastLayer => "توسيع الطبقة الأخيرة";

  @override
  String get contextRestoreOperation => "استعادة العملية";

  @override
  String get contextOriginalHistory => "إعادة قراءة جميع الرسائل الأصلية في هذا المقطع";

  @override
  String get contextImpactEditTitle => "هل تريد حفظ الملخص السابق؟";

  @override
  String get contextOpenNewChat => "فتح محادثة جديدة";

  @override
  String get wsPathChanged => "تغيّرت الوجهة أثناء انتظار الموافقة.";

  @override
  String get contextEditUnknownPreview => "الاستخدام غير متاح حاليًا؛ سيُعاد التحقق منه قبل الحفظ.";

  @override
  String get contextTaskWait => "بانتظار انتهاء الرد الحالي والأدوات";

  @override
  String compressTaskElapsed(int i, int n, int seconds) => "الجزء ${i}/${n} · مضى ${seconds} ث";

  @override
  String get wsContextChanged => "تغيّر سياق المحادثة. انتهت صلاحية الطلب.";

  @override
  String contextChangeImpact(int count) => "سيؤدي هذا التغيير أيضًا إلى التراجع عن ${count} من عمليات السياق المتأثرة. ستبقى الرسائل الأصلية محفوظة. هل تريد المتابعة؟";

  @override
  String get contextImpactSave => "حفظ";

  @override
  String contextTaskProgress(int done, int total) => "جارٍ ضغط ${done}/${total} مقاطع";

  @override
  String get contextSummaryNotSmaller => "الملخص ليس أقصر من النص الأصلي. راجعه قبل تطبيقه.";

  @override
  String get storageSpaceImageTypeTool => "صور الأدوات";

  @override
  String get contextPreviousHistory => "إعادة قراءة طبقة الضغط الأخيرة";

  @override
  String get contextDetailRead => "تمت القراءة";

  @override
  String get contextViewGenerated => "عرض الملخص المُنشأ";

  @override
  String get contextImpactDeleteDescription => "احذف النسخ الأصلية وتراجع عن الملخصات المرتبطة بها حتى لا يُرسل المحتوى المحذوف مجددًا. ستبقى الرسائل الأخرى والعقد المستقلة دون تغيير.";

  @override
  String get storageSpaceImageTypeAvatar => "الصور الرمزية والخلفيات";

  @override
  String get contextDetailAfterUndo => "بعد التراجع";

  @override
  String get contextOperationUndo => "التراجع عن عملية السياق هذه";

  @override
  String contextHistoryWindowNote(int count) => "لا يزال السجل الحديث خاضعًا لنافذة الإرسال البالغة ${count} رسالة في المحادثة.";

  @override
  String get contextOverLimitWarning => "قد يؤدي التراجع إلى تجاوز حد السياق. لا يزال بإمكانك التراجع وإعادة الضغط؛ وسيُعاد فحص الحد عند الإرسال.";

  @override
  String get storageSpaceImageTypeChat => "صور المحادثة";

  @override
  String get worldBookSelectEntries => "تحديد الإدخالات";

  @override
  String get compressUsageSummary => "الملخص التقديري";

  @override
  String contextDetailRange(String from, String to, int count) => "الرسائل ${from}–${to} · ${count} رسائل من المستخدم";

  @override
  String get contextOperationHidden => "استُبعدت بواسطة عملية مسح لاحقة";

  @override
  String get contextUndoClearTooltip => "التراجع عن هذا المسح";

  @override
  String compressKeepDescription(int count) => "الاحتفاظ بأحدث ${count} رسالة من المستخدم مع ردودها وأدواتها. سيُلخّص السجل الأقدم؛ كما تُحتسب الرسائل التي تحتوي على مرفقات فقط.";

  @override
  String get contextOperationUndone => "تم التراجع";

  @override
  String contextEditPreview(String value) => "نحو ${value} رمزًا بعد الحفظ. لا يغيّر التعديل السياق النشط.";

  @override
  String get contextDetailExcluded => "السجل المستبعد";

  @override
  String get worldBookNoMoveTargets => "أنشئ كتاب عالم آخر لنقل الإدخالات إليه.";

  @override
  String worldBookSelectedEntries(int count) => "تم تحديد ${count}";

  @override
  String get contextDetailReplaced => "تم الاستبدال";

  @override
  String get displaySettingsPageAutoScrollEnabledLabel => "مفعّل";

  @override
  String get contextChangeTitle => "مراجعة السياق المتأثر";

  @override
  String get contextDetailTitle => "الملخص";

  @override
  String get compressModelGlobal => "إعداد عام · يتم تثبيته عند بدء العملية";

  @override
  String get wsDeniedMountReadonly => "نقطة الربط للقراءة فقط. لا يمكن الكتابة فيها.";

  @override
  String get compressRereadDesc => "استرجاع التفاصيل التي فُقدت عبر الملخصات. يستهلك عددًا أكبر من الرموز.";

  @override
  String get toolApprovalSwitchToFullAccess => "التبديل إلى الوصول الكامل";

  @override
  String get compressUsageInput => "مدخلات الملخص";

  @override
  String get contextDetailSummaryLabel => "الملخص المستخدم في الطلبات اللاحقة";

  @override
  String get contextImpactDeleteTitle => "هل تريد حذف النسخ الأصلية المضغوطة؟";

  @override
  String get compressAdvancedOff => "إعادة قراءة النسخ الأصلية متوقفة";

  @override
  String get contextOperationActive => "مطبّقة حاليًا";

  @override
  String get compressAdvancedOn => "إعادة قراءة النسخ الأصلية مفعّلة";

  @override
  String get contextTaskMerging => "جارٍ دمج الملخصات";

  @override
  String contextSampledInfo(int count) => "تمت قراءة الأحرف المحددة وعددها ${count} فقط؛ وسيستبدل الملخص نطاق السجل المحدد بالكامل.";

  @override
  String get contextDividerRunning => "جارٍ ضغط السياق";

  @override
  String get contextClearDetails => "سيُستبعد سجل المحادثة السابق من الطلبات المستقبلية. وستظل تعليمات النظام والذاكرة وتعريفات الأدوات سارية.";

  @override
  String get compressCopyResult => "نسخ النتيجة";

  @override
  String get contextDetailInUse => "قيد الاستخدام";

  @override
  String get contextImpactDescription => "سيتم التراجع عن الملخصات المرتبطة معًا. وستظل الرسائل الأصلية والعقد المستقلة محفوظة؛ ولن يتم استدعاء أي نموذج تلقائيًا.";

  @override
  String get compressIncludeAttachmentsDesc => "تضمين نصوص المرفقات المتاحة وسجلات الأدوات ضمن الحدود المحددة. سيُشار إلى النص المقتطع؛ ولن يُعاد تفسير الصور.";

  @override
  String worldBookEntriesMoved(int count) => (count == 1 ? "تم نقل مدخل واحد" : intl.Intl.pluralLogic(count, locale: localeName, two: "تم نقل مدخلين", few: "تم نقل ${count} مدخلات", many: "تم نقل ${count} مدخلًا", other: "تم نقل ${count} مدخل"));

  @override
  String get contextImpactSourceDescription => "غيّر النسخ الأصلية وتراجع عن ملخصاتها والعقد التابعة لها معًا. ستبقى الرسائل الأخرى والعقد المستقلة محفوظة؛ ولن يتم استدعاء أي نموذج.";

  @override
  String get contextEditTitle => "تعديل الملخص";

  @override
  String get compressUsageNext => "الطلب التالي";

  @override
  String get contextSummaryEmpty => "لا يمكن أن يكون الملخص فارغًا. استخدم «مسح السياق» لاستبعاد السجل.";

  @override
  String get toolApprovalDenied => "مرفوض";

  @override
  String get contextDetailModel => "النموذج · الوقت";

  @override
  String compressIncludeManual(int count) => "تضمين التعديلات اليدوية · ${count}";

  @override
  String contextBudgetInfo(int used, String limit) => "تقدير الطلب التالي (بما في ذلك مساحة الإخراج المحجوزة): ${used} / ${limit} رمزًا";

  @override
  String get contextTaskDismiss => "إخفاء الحالة";

  @override
  String contextUndoBudgetInfo(int used) => "بعد التراجع: نحو ${used} رمزًا بما في ذلك مساحة الإخراج المحجوزة";

  @override
  String get storageSpaceImageInUse => "قيد الاستخدام";

  @override
  String get worldBookSelectionDone => "تم";

  @override
  String get contextDividerFailed => "فشل ضغط السياق";

  @override
  String get toolPermissionUnboundHint => "لا توجد مساحة عمل مرتبطة؛ وهذا لا يفعّل أدوات الملفات أو Shell.";

  @override
  String get contextChangeWaiting => "بانتظار انتهاء الرد الحالي والأدوات قبل تطبيق هذا التغيير.";

  @override
  String storageSpaceDeletedUploadsPartial(int deleted, int kept) => "حُذف ${deleted} عنصرًا؛ وتم الاحتفاظ بـ ${kept} عناصر قيد الاستخدام أو تعذّر حذفها.";

  @override
  String get contextSourceScopeHint => "يُدرج السجل الذي يلي أحدث عملية مسح فقط. وقد يتضمن ذلك رسائل أقدم من نافذة الإرسال المعتادة.";

  @override
  String get contextTaskPreparing => "جارٍ إعداد الضغط";

  @override
  String contextImpactUsage(String from, String to) => "تقريبًا ${from} ← ${to} رمزًا";

  @override
  String contextImpactConfirm(int count) => "التراجع عن ${count} عقد";

  @override
  String get contextDividerEdited => "تم التعديل";

  @override
  String get compressAdjust => "ضبط";

  @override
  String get compressRegenerate => "إعادة الضغط";

  @override
  String get toolPermissionEnabledSnack => "تم تفعيل الوصول الكامل لهذه المحادثة";

  @override
  String get contextDetailSuperseded => "استُبدل بملخص أحدث";

  @override
  String get contextTaskQueued => "في قائمة الانتظار — بانتظار الضغط";

  @override
  String get contextNewConversation => "إنشاء محادثة جديدة باستخدام الملخص";

  @override
  String get contextUnknownLimit => "حد غير معروف";

  @override
  String get browserErrActionTimeout => "انتهت مهلة العملية، والنتيجة غير معروفة. افحص الصفحة قبل السماح للذكاء الاصطناعي بالمتابعة.";

  @override
  String get toolPermissionRequestApprovalDesc => "سيطلب Kelivo موافقتك قبل الوصول إلى الملفات خارج مساحة العمل أو تشغيل أوامر سطح المكتب أو استخدام أدوات أخرى تتطلب الإذن.";

  @override
  String get contextLimitedInputHint => "تتم قراءة نافذة الأحرف المحددة فقط. ولا يُدرج بقية السجل المستبدل في الملخص؛ وتظل الرسائل الأصلية متاحة.";

  @override
  String get contextTaskCancelled => "تم إلغاء ضغط السياق";

  @override
  String get contextDetailClearTitle => "تم مسح السياق";

  @override
  String get contextImpactKeep => "دون تغيير";

  @override
  String get contextImpactUndoAlso => "تم التراجع عنها أيضًا";

  @override
  String get contextClearMarker => "تم مسح السياق";

  @override
  String get toolPermissionScopeThisChat => "هذه المحادثة فقط";

  @override
  String get dataDirectoryTitle => "مجلد البيانات";

  @override
  String get dataDirectoryChange => "تغيير المجلد";

  @override
  String get dataDirectoryChoose => "اختر مجلدًا محليًا فارغًا";

  @override
  String get dataDirectoryHint => "اختر مجلدًا فارغًا على قرص محلي. سينقل سجل المحادثات والمرفقات والملفات التي يديرها التطبيق بعد إعادة التشغيل. ستبقى إعدادات الجهاز الصغيرة وذاكرة النظام المؤقتة في مواقعها الحالية.";

  @override
  String get dataDirectoryPendingHint => "تم جدولة النقل عند إعادة التشغيل التالية. ستبقى بياناتك الحالية في مكانها إلى أن يكتمل النسخ والتحقق. الوجهة:";

  @override
  String get dataDirectoryRestart => "أعد التشغيل وانقل البيانات";

  @override
  String get dataDirectoryCancelMove => "إلغاء النقل والإبقاء على المجلد الأصلي";

  @override
  String get dataDirectoryPreviousHint => "تم الاحتفاظ بالنسخة الأصلية. بعد تشغيل المجلد الجديد بنجاح، يمكنك حذف النسخة القديمة لتوفير مساحة. نظّفها قبل تغيير مجلد البيانات مرة أخرى.";

  @override
  String get dataDirectoryCleanPrevious => "تنظيف النسخة الأصلية";

  @override
  String get dataDirectoryCleanConfirm => "هل تريد إزالة النسخة المحتفظ بها من المجلد أدناه؟ ستظل البيانات الموجودة في المجلد الحالي محفوظة. ولن تُحذف الملفات التي تغيّرت منذ النقل.";

  @override
  String get dataDirectoryMoving => "جارٍ نقل البيانات والتحقق منها… يُرجى إبقاء Kelivo مفتوحًا.";

  @override
  String get dataDirectoryStartupFailed => "تعذّر فتح مجلد البيانات";

  @override
  String get dataDirectoryRetry => "إعادة المحاولة";

  @override
  String get dataDirectoryUnavailable => "مجلد البيانات غير متاح. أعد توصيل القرص أو أعد المجلد إلى موقعه الأصلي، ثم حاول مجددًا. لن يتم إنشاء قاعدة بيانات فارغة.";

  @override
  String get dataDirectoryIdentityMismatch => "هذا المجلد لا يطابق مجلد البيانات الذي تم ضبطه. أعد المجلد الأصلي وحاول مجددًا.";

  @override
  String get dataDirectoryNotEmpty => "اختر مجلدًا فارغًا. لن تتم الكتابة فوق الملفات الموجودة.";

  @override
  String get dataDirectoryOverlap => "اختر مجلدًا منفصلًا خارج مجلد البيانات الحالي. لا يمكن استخدام المجلدات الأب أو جذر القرص.";

  @override
  String get dataDirectoryLocalOnly => "اختر قرصًا محليًا بدلًا من مشاركة عبر الشبكة.";

  @override
  String get dataDirectoryFinishPrevious => "أكمل النقل المعلّق أو ألغِه، ونظّف النسخة المحتفظ بها قبل اختيار مجلد آخر.";

  @override
  String get dataDirectoryPendingRestore => "هناك استعادة نسخة احتياطية معلّقة. ألغِ نقل المجلد وأعد التشغيل لإكمال الاستعادة، ثم حاول النقل مجددًا.";

  @override
  String get dataDirectorySourceChanged => "تغيّرت البيانات الأصلية منذ إنشاء النسخة. تم الاحتفاظ بها. ألغِ النقل المعلّق قبل بدء نقل جديد؛ ويمكنك فحص النسخ المحتفظ بها يدويًا.";

  @override
  String get dataDirectoryCopyChanged => "تحتوي الوجهة على ملفات غير متوقعة أو تغيّرت. تم الاحتفاظ بالبيانات الأصلية. افحص الوجهة قبل إعادة المحاولة.";

  @override
  String get dataDirectoryGenericError => "تعذّر إكمال العملية. تحقق من مساحة القرص المتاحة وأذونات المجلد، ومن عدم تشغيل عملية أخرى لـ Kelivo، ثم حاول مجددًا. تم الاحتفاظ بالبيانات الحالية.";

  @override
  String get dataDirectoryCancelHint => "يُبقي الإلغاء أي ملفات نُسخت بالفعل إلى الوجهة. يمكنك فحص هذه النسخة الجزئية وإزالتها بنفسك.";

  @override
  String providerDetailPageBaseUrlExample(String url) => "مثال: ${url}";

  @override
  String get providerDetailPageApiKeyExample => "مثال: sk-…";

  @override
  String get providerDetailPageRequestUrlLabel => "عنوان URL للطلب";

  @override
  String providerDetailPageUrlWillAppendVersion(String v) => "لا يتضمن العنوان إصدارًا؛ ستتم إضافة ${v} عند مغادرة الحقل.";

  @override
  String providerDetailPageUrlAppendedVersion(String v) => "تمت إضافة ${v} تلقائيًا";

  @override
  String get providerDetailPageUrlTrimmedSlash => "تم حذف الشرطة المائلة الأخيرة /";

  @override
  String providerDetailPageUrlMovedPath(String path) => "تم اكتشاف نقطة نهاية كاملة؛ نُقل ${path} إلى مسار API.";

  @override
  String get providerDetailPageUrlEmptyError => "هذا الحقل مطلوب لإرسال الطلبات";

  @override
  String get providerDetailPageUrlInvalidError => "عنوان URL غير صالح؛ يجب أن يبدأ بـ http:// أو https://";

  @override
  String get providerDetailPageRestoreDefaultTooltip => "استعادة القيمة الافتراضية";

  @override
  String get providerDetailPageClearTooltip => "مسح";

  @override
  String providerDetailPageTestSuccessWithLatency(String ms) => "نجاح · ${ms} مللي ثانية";

  @override
  String providerDetailPageTestFailedWithCode(String code) => "فشل · ${code}";

  @override
  String providerDetailPageTestHintMissingVersion(String url) => "قد يكون الإصدار غير موجود في العنوان؛ جرّب ${url}";

  @override
  String providerAutoVersionAdded(String v) => "تمت إضافة ${v} تلقائيًا";

  @override
  String get providerUndo => "تراجع";

  @override
  String get sidePanelToggle => "إظهار/إخفاء اللوحة الجانبية";

  @override
  String get sidePanelFiles => "الملفات";

  @override
  String get sidePanelTopics => "المواضيع";

  @override
  String get sidePanelExpand => "توسيع اللوحة";

  @override
  String get sidePanelCollapse => "إنهاء وضع التوسيع";

  @override
  String get sidePanelAllTabs => "كل علامات التبويب";

  @override
  String sidePanelMoreTabs(int count) => "${count} علامات تبويب إضافية";

  @override
  String get sidePanelSearchTabs => "البحث في علامات التبويب";

  @override
  String get sidePanelOpenFile => "فتح ملف…";

  @override
  String get sidePanelCloseOthers => "إغلاق علامات التبويب الأخرى";

  @override
  String get sidePanelCloseRight => "إغلاق علامات التبويب إلى اليمين";

  @override
  String get sidePanelReopenTab => "إعادة فتح علامة تبويب مغلقة";

  @override
  String get sidePanelPinned => "مثبّتة · لا يمكن إغلاقها";

  @override
  String get sidePanelMoveTopicsLeft => "إعادة نقل المواضيع إلى اليسار…";

  @override
  String get sidePanelPinnedHint => "تبقى المواضيع مثبّتة عند وجودها على اليمين. غيّر موضعها من الإعدادات › العرض › موضع الموضوع.";

  @override
  String get sidePanelEvictedTitle => "تم إلغاء تحميل الصفحة";

  @override
  String sidePanelEvictedBody(int count) => "تم إلغاء تحميلها في الخلفية لتوفير الذاكرة (يتم الاحتفاظ بما يصل إلى ${count} صفحات في الخلفية). أعد التحميل لمتابعة التصفح.";

  @override
  String get sidePanelEvictedTooltip => "تم إلغاء التحميل · أعد التحميل للمتابعة";

  @override
  String get sidePanelFileMissing => "الملف غير متاح";

  @override
  String sidePanelFileMissingBody(String path) => "تم حذف ${path} أو نقله.";

  @override
  String get sidePanelRelocate => "البحث عنه مجددًا";

  @override
  String sidePanelBackgroundIn(String topic) => "يعمل في «${topic}»";

  @override
  String sidePanelWidth(int px) => "عرض اللوحة: ${px}px";

  @override
  String get sidePanelWidthMax => "الحد الأقصى";

  @override
  String get sidePanelWidthMin => "الحد الأدنى";

  @override
  String get sidePanelRecentFiles => "المخرجات والمرفقات الأخيرة";

  @override
  String get sidePanelOpenExternalUrl => "فتح عنوان URL في متصفح النظام…";

  @override
  String get sidePanelWebPages => "صفحات الويب";

  @override
  String get hotkeyToggleSidePanel => "إظهار/إخفاء اللوحة الجانبية";

  @override
  String get hotkeySidePanelNewWeb => "علامة تبويب ويب جديدة";

  @override
  String get hotkeySidePanelFiles => "إظهار الملفات";

  @override
  String get hotkeySidePanelExpand => "توسيع اللوحة الجانبية";

  @override
  String get hotkeySidePanelReopenTab => "إعادة فتح علامة تبويب مغلقة";

  @override
  String get hotkeySidePanelNextTab => "علامة التبويب التالية في اللوحة";

  @override
  String get hotkeySidePanelPreviousTab => "علامة التبويب السابقة في اللوحة";

  @override
  String get hotkeySidePanelAddress => "التركيز على عنوان الويب";

  @override
  String get hotkeySidePanelFocus => "التبديل بين تركيز المحادثة واللوحة";

  @override
  String get selectionQuote => "اقتباس";

  @override
  String selectionQuoteMarker(int index) => "[اقتباس ${index}]";

  @override
  String get selectionTranslate => "ترجمة";

  @override
  String get selectionAiTranslateIos => "ترجمة بالذكاء الاصطناعي";

  @override
  String get selectionCopyMarkdown => "نسخ بصيغة Markdown";

  @override
  String get selectionCopyRich => "نسخ النص المنسّق";

  @override
  String get quoteJumpToSource => "الانتقال إلى المصدر";

  @override
  String get quoteRemove => "إزالة الاقتباس";

  @override
  String get quoteDuplicate => "تم اقتباسه بالفعل";

  @override
  String get quoteLimit => "يسمح بما يصل إلى 10 اقتباسات لكل رسالة";

  @override
  String get quoteLocated => "تم الانتقال إلى النص المقتبس";

  @override
  String get quoteSourceMissing => "لم يعد المصدر موجودًا";

  @override
  String get selectionRegenerate => "إعادة الإنشاء";

  @override
  String get translating => "جارٍ الترجمة…";

  @override
  String get retry => "إعادة المحاولة";

  @override
  String get recoveryGuideTitle => "لنستعد محادثاتك";

  @override
  String get recoveryGuideBody => "أوقف Kelivo تحميل بياناتك مؤقتًا. سنبحث عن نسخ محلية لتختار ما تريد استعادته. ستظل الملفات الحالية محفوظة.";

  @override
  String get recoverySpaceTitle => "يلزم توفير بعض المساحة الحرة";

  @override
  String get recoveryChecksNeedSpace => "عُثر على نسخ محلية، لكن المساحة غير كافية لفحصها. هذا لا يعني أنها تالفة. حرّر بعض المساحة ثم أعد الفحص.";

  @override
  String get recoveryChecksUnavailable => "تعذّر فحص بعض النسخ المحلية حتى الآن، لكن ملفاتها لا تزال متاحة. أعد الفحص أو صدّر بياناتك لطلب المساعدة.";

  @override
  String get recoveryRecheckCopies => "إعادة فحص النسخ المحلية";

  @override
  String get recoveryCopyPreview => "معاينة النسخة";

  @override
  String get recoveryRestoreRetryBody => "تعذّر إكمال الاستعادة. تم الاحتفاظ بالنسخة المحددة. أعد فحص النسخ المحلية أو أعد فتح Kelivo للمتابعة.";

  @override
  String recoverySpaceAmount(String required, String available) => "آخر فحص: المساحة المتاحة ${available}؛ يلزم توفر ${required} على الأقل من المساحة الحرة لإعداد بياناتك بأمان.";

  @override
  String get recoveryCopiesNeedUpdate => "أُنشئت بعض النسخ بإصدار أحدث من Kelivo. حدّث Kelivo قبل استعادتها. تم الاحتفاظ بهذه النسخ.";

  @override
  String get imageContextAllowRecall => "السماح للنموذج باسترجاع الصور";

  @override
  String get imageContextAllowRecallDescription => "اسمح للنموذج باسترجاع الصور من هذه المحادثة عند الحاجة. إيقاف هذا الخيار لا يغيّر الإدارة التلقائية للصور.";

  @override
  String get imageContextTitle => "سياق الصور";

  @override
  String get imageContextAutomatic => "إدارة صور السجل تلقائيًا";

  @override
  String get imageContextDescription => "إدارة الصور المضمّنة في هذه الرسالة. ستبقى الصور الأصلية في محادثتك.";

  @override
  String get imageContextIncluded => "مضمّنة";

  @override
  String get imageContextOmitted => "غير مضمّنة";

  @override
  String get imageContextPin => "تثبيت الصورة";

  @override
  String get imageContextUnpin => "إلغاء تثبيت الصورة";

  @override
  String get imageContextAttachAgain => "إضافتها إلى محرر الرسائل مجددًا";

  @override
  String get imageContextEmpty => "لا توجد صور بعد";

  @override
  String get imageContextUnavailable => "هذه الصورة غير متاحة في السياق الحالي.";

  @override
  String get imageContextEntryDescription => "مراجعة الصور الخاصة بهذه الرسالة وإدارتها";

  @override
  String get imageContextAutomaticDescription => "الاحتفاظ بالمرفقات مدة أطول وإبعاد صور الأدوات الأقدم.";

  @override
  String get imageContextActionsHint => "ثبّت صورة لإعطائها الأولوية، أو أضفها إلى محرر الرسائل مجددًا.";

  @override
  String get imageContextEmptyDescription => "ستظهر هنا الصور التي ترسلها أو تقرؤها الأدوات.";

  @override
  String get imageContextUserImages => "صورك";

  @override
  String get imageContextToolImages => "صور الأدوات";

  @override
  String get imageContextAssistantImages => "الصور المُنشأة";

  @override
  String imageContextImageNumber(int index) => "الصورة ${index}";

  @override
  String imageContextIncludedCount(int included, int total) => "تم تضمين ${included} من أصل ${total} صورة";

  @override
  String get imageContextMissing => "غير متاحة";

  @override
  String get imageContextLoadFailed => "تعذّر تحميل الصور. حاول مجددًا.";

  @override
  String get imageContextUpdateFailed => "تعذّر حفظ تغييراتك. حاول مجددًا.";

  @override
  String get contextOperationsTitle => "عمليات السياق";

  @override
  String get contextOperationsDescription => "إدارة مهام الضغط والملخصات وحدود السياق";

  @override
  String get contextOperationsEmpty => "لا توجد عمليات سياق بعد.";

  @override
  String contextOperationsStored(int count) => "السجل المحفوظ: ${count} رسالة";

  @override
  String contextOperationsEffective(int summaries, int messages) => "السجل للطلب التالي: ${summaries} ملخصًا + ${messages} رسالة أصلية";

  @override
  String get contextOperationsScope => "يستخدم حد السجل الحالي. وتضيف تعليمات النظام والذاكرة والأدوات والمدخلات غير المرسلة إلى هذا السياق. افتح سجلًا لعرض ملخصه أو نطاقه الأصلي أو التراجع عنه.";

  @override
  String get contextOperationsLoadFailed => "تعذّر تحميل نظرة عامة على السياق. يُرجى إعادة المحاولة.";

  @override
  String get compressNewConversation => "الضغط في محادثة جديدة";

  @override
  String get compressNewConversationDescription => "إنشاء محادثة جديدة تحتوي على الملخص والرسائل المحتفظ بها، مع إبقاء المحادثة الأصلية دون تغيير. عطّل هذا الخيار للضغط داخل المحادثة نفسها.";

  @override
  String get contextViewBoundary => "الانتقال إلى الحد";

  @override
  String get contextFixedStart => "بداية سياق ثابتة";

  @override
  String get contextSetFixedStart => "بدء السياق من هنا";

  @override
  String get contextCancelFixedStart => "إلغاء بداية السياق الثابتة";

  @override
  String get contextFixedStartDescription => "إرسال السجل ابتداءً من هذه الرسالة، دون حد عدد الرسائل المتحرك.";

  @override
  String get contextBeforeFixedStart => "هذه الرسالة تسبق بداية السياق الثابتة. انقل نقطة البداية أو ألغها قبل إنشاء الرد مجددًا.";

  @override
  String get contextRegenerateFixedStart => "هذا الرد هو بداية السياق الثابتة، ولذلك لا يتم تضمين سؤاله. انقل نقطة البداية إلى رسالة أسبق أو ألغها قبل إنشاء الرد مجددًا.";

  @override
  String get responseSpeedLabel => "سرعة الاستجابة";

  @override
  String get responseSpeedStandard => "قياسية";

  @override
  String get responseSpeedUsageHint => "تستهلك الأوضاع الأسرع حصة أو أرصدة أكثر.";

  @override
  String get responseSpeedLoading => "جارٍ التحقق من التوفر…";

  @override
  String get responseSpeedUnavailable => "لا يتوفر مستوى تسريع لهذا النموذج.";

  @override
  String get responseSpeedSaveFailed => "تعذّر حفظ سرعة الاستجابة. حاول مجددًا.";

  @override
  String responseSpeedRequestFailed(String mode) => "فشل طلب ${mode}. تحقق من توفر النموذج والحساب، أو بدّل إلى «قياسية» ثم أعد المحاولة.";

  @override
  String get responseSpeedSelectionUnavailable => "لم تعد السرعة المحفوظة متاحة. ستستخدم هذه المحادثة الوضع القياسي.";

  @override
  String get responseSpeedProviderDependent => "يعتمد التوفر على مزوّد الخدمة.";

  @override
  String responseSpeedTapTo(String mode) => "اضغط للتبديل إلى ${mode}";

  @override
  String get responseSpeedUltrafastNeedsResponses => "يتطلب وضع UltraFast استخدام Responses API.";

  @override
  String get projectDefaultSkillsTitle => "المهارات الافتراضية للمشروع";

  @override
  String get languageDisplayArabic => "العربية";

  @override
  String get workspaceRuntimeNoRuntime => 'بيئة مساحة العمل غير جاهزة. ثبّت بيئة العزل أو شغّلها أولًا.';

  @override
  String get workspaceRuntimeAtLeastOneEcosystem => 'اختر بيئة تشغيل واحدة على الأقل.';
  @override
  String get workspaceRuntimeProfilesTitle => 'ملفات بيئة التشغيل';

  @override
  String get workspaceRuntimeProfilesSubtitle => 'اختر بيئات Python وNode.js وحصص التنفيذ الخاصة بكل مشروع.';

  @override
  String get workspaceRuntimeSelectWorkspace => 'مساحة عمل المشروع';

  @override
  String get workspaceRuntimeNoWorkspaces => 'أنشئ مساحة عمل أولًا لإعداد ملف بيئة التشغيل.';

  @override
  String get workspaceRuntimeNoProfiles => 'لا توجد ملفات بيئة تشغيل بعد.';

  @override
  String get workspaceRuntimeCreate => 'إنشاء ملف بيئة';

  @override
  String get workspaceRuntimeDefault => 'الافتراضي';

  @override
  String get workspaceRuntimeSetDefault => 'استخدامه كافتراضي للمشروع';

  @override
  String get workspaceRuntimeClearDefault => 'إلغاء البيئة الافتراضية للمشروع';

  @override
  String get workspaceRuntimeEdit => 'تعديل الحدود';

  @override
  String get workspaceRuntimeRemove => 'حذف';

  @override
  String get workspaceRuntimeProfileName => 'اسم ملف البيئة';

  @override
  String get workspaceRuntimeEcosystems => 'بيئات التشغيل المتاحة';

  @override
  String get workspaceRuntimeShell => 'أدوات Shell';

  @override
  String get workspaceRuntimePython => 'Python';

  @override
  String get workspaceRuntimeNode => 'Node.js';

  @override
  String get workspaceRuntimeMaxDuration => 'المهلة الزمنية (ثانية)';

  @override
  String get workspaceRuntimeMaxCpuSeconds => 'ميزانية وقت المعالج (ثانية)';

  @override
  String get workspaceRuntimeMaxConcurrentRuns => 'أقصى عدد من عمليات التشغيل المتزامنة';

  @override
  String get workspaceRuntimeMaxProcesses => 'أقصى عدد من العمليات';

  @override
  String get workspaceRuntimeMemoryLimit => 'حد الذاكرة الافتراضية (MB)';

  @override
  String get workspaceRuntimeTempLimit => 'ميزانية الملفات المؤقتة (MB)';

  @override
  String get workspaceRuntimeOutputLimit => 'ميزانية مخرجات التشغيل (MB)';

  @override
  String get workspaceRuntimeFileLimit => 'أقصى حجم لملف واحد (MB)';

  @override
  String get workspaceRuntimeShareBaseTools => 'استخدام الأدوات الأساسية المشتركة من البيئة النشطة';

  @override
  String get workspaceRuntimePlatformLimitsNote => 'حدود PRoot تقديرية: تعتمد قيود المعالج والذاكرة الافتراضية وعدد العمليات على صدفة Linux. يتم فحص حجم القرص بعد انتهاء المهمة وليست هناك حصة قرص لحظية.';

  @override
  String get workspaceRuntimeStorageScopeNote => 'حزم apt/apk تعدّل نظام الملفات النشط المشترك. يمكن عزل حزم Python وNode لكل ملف بيئة تشغيل خاص بالمشروع.';

  @override
  String get workspaceRuntimeThermalNote => 'يفحص KELIVO الضغط الحراري في Android قبل التصيير، وقد يحذر أو يمنع البدء عند القياسات الحرجة. يظل Android مسؤولًا عن خفض الأداء؛ وقد لا تتوفر القياسات ولا تتم مراقبتها باستمرار أثناء التصيير.';

  @override
  String get workspaceRuntimeRootfsNote => 'يوجد نظام ملفات جذري نشط واحد فقط. التبديل بين Ubuntu وAlpine وDebian يستبدل الصورة النشطة ولا ينشئ عدة أنظمة متزامنة.';

  @override
  String get workspaceRuntimeInterpreterNote => 'تعزل الملفات مسارات الحزم، لكنها تستخدم إصدارات Python وNode المثبتة في نظام الملفات الجذري النشط.';

  @override
  String get workspaceRuntimeSave => 'حفظ';

  @override
  String get workspaceRuntimeCancel => 'إلغاء';

  @override
  String get workspaceRuntimeRemoveConfirm => 'هل تريد حذف ملف البيئة ومجلد الحزم المعزول؟ ستبقى مخرجات التشغيل السابقة محفوظة.';

  @override
  String get workspaceRuntimeRunning => 'عمليات التشغيل النشطة';

  @override
  String get workspaceRuntimeNoRunning => 'لا توجد عمليات تشغيل نشطة.';

  @override
  String get workspaceRuntimeCancelRun => 'إلغاء التشغيل';

  @override
  String get workspaceRuntimeScopeNote => 'تدير هذه الصفحة ملفات المشاريع. تبقى ملفات المهارات مرتبطة بمهاراتها، ولا تُدار ملفات المهام من هذه الصفحة.';

  @override
  String get workspaceEnvDependencyMedia => 'أدوات الوسائط';

  @override
  String get workspaceEnvDependencyMediaDetail => 'FFmpeg وFFprobe';

  @override
  String get workspaceEnvOptionalMediaTools => 'أدوات وسائط اختيارية';

  @override
  String get workspaceEnvOptionalToolNotInstalledAutomatically => 'يتم التحقق من وجودها فقط؛ لا يثبتها هذا الإعداد تلقائيًا.';
  @override
  String get workspaceEnvMediaVersions => 'إصدارات أدوات الوسائط المكتشفة';

  @override
  String get workspaceEnvMediaVersionNotDetected => 'لم يتم اكتشاف الإصدار';
}
