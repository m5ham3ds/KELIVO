part of 'assistant_settings_edit_page.dart';

class _LocalToolsTab extends StatelessWidget {
  const _LocalToolsTab({required this.assistantId});
  final String assistantId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ap = context.watch<AssistantProvider>();
    final assistant = ap.getById(assistantId)!;
    final timeEnabled = assistant.localToolIds.contains(
      LocalToolNames.timeInfo,
    );
    final clipboardEnabled = assistant.localToolIds.contains(
      LocalToolNames.clipboard,
    );
    final textToSpeechEnabled = assistant.localToolIds.contains(
      LocalToolNames.textToSpeech,
    );
    final askUserEnabled = assistant.localToolIds.contains(
      LocalToolNames.askUser,
    );
    final calculateEnabled = assistant.localToolIds.contains(
      LocalToolNames.calculate,
    );
    final screenTimeEnabled = assistant.localToolIds.contains(
      LocalToolNames.screenTime,
    );
    final calendarQueryEnabled = assistant.localToolIds.contains(
      LocalToolNames.calendarQuery,
    );
    final calendarCreateEnabled = assistant.localToolIds.contains(
      LocalToolNames.calendarCreate,
    );
    final locationEnabled = assistant.localToolIds.contains(
      LocalToolNames.currentLocation,
    );
    final weatherEnabled = assistant.localToolIds.contains(
      LocalToolNames.weather,
    );
    final healthEnabled = assistant.localToolIds.contains(
      LocalToolNames.healthSummary,
    );
    final remindersQueryEnabled = assistant.localToolIds.contains(
      LocalToolNames.remindersQuery,
    );
    final remindersCreateEnabled = assistant.localToolIds.contains(
      LocalToolNames.remindersCreate,
    );
    final remindersCompleteEnabled = assistant.localToolIds.contains(
      LocalToolNames.remindersComplete,
    );

    Future<void> toggleTool(String toolId, bool value) {
      return setLocalToolEnabled(
        context,
        assistant: assistant,
        toolId: toolId,
        value: value,
      );
    }

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final selectedToolsets =
        assistant.toolsetIds?.toSet() ??
        Assistant.sourceToolsetIds.toSet();

    Future<void> updateToolset(String id, bool enabled) async {
      final next = Set<String>.of(selectedToolsets);
      if (enabled) {
        next.add(id);
      } else {
        next.remove(id);
      }
      final allSelected = Assistant.sourceToolsetIds.every(next.contains);
      await ap.updateAssistant(
        assistant.copyWith(
          toolsetIds: allSelected ? null : (next.toList()..sort()),
          clearToolsetIds: allSelected,
        ),
      );
    }

    final toolsetRows = <({
      String id,
      String title,
      String subtitle,
      IconData icon,
    })>[
      (
        id: 'search',
        title: isArabic ? 'البحث' : 'Search',
        subtitle: isArabic ? 'البحث على الويب وجلب المحتوى' : 'Web search and retrieval',
        icon: Lucide.Search,
      ),
      (
        id: 'memory',
        title: isArabic ? 'الذاكرة' : 'Memory',
        subtitle: isArabic ? 'استرجاع الذاكرة وإدارتها' : 'Conversation memory tools',
        icon: Lucide.Brain,
      ),
      (
        id: 'local',
        title: isArabic ? 'الأدوات المحلية والإضافات' : 'Local and extensions',
        subtitle: isArabic ? 'أدوات الجهاز والمهارات والإضافات' : 'Device, Skill and extension tools',
        icon: Lucide.Wrench,
      ),
      (
        id: 'workspace',
        title: isArabic ? 'مساحة العمل' : 'Workspace',
        subtitle: isArabic ? 'الملفات والطرفية وعمليات مساحة العمل' : 'Files, terminal and workspace operations',
        icon: Lucide.FileText,
      ),
      (
        id: 'mcp',
        title: isArabic ? 'خوادم MCP' : 'MCP servers',
        subtitle: isArabic ? 'الأدوات المتصلة عبر خوادم MCP' : 'Tools provided by connected MCP servers',
        icon: Lucide.Terminal,
      ),
      (
        id: 'video',
        title: isArabic ? 'إنتاج الفيديو' : 'Video production',
        subtitle: isArabic ? 'محركات الفيديو والمزودون وسير العمل' : 'Video engines, providers and workflows',
        icon: Lucide.Play,
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: [
        SectionCard(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic ? 'مجموعات الأدوات' : 'Toolsets',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: AppFontWeights.semibold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isArabic
                        ? 'مرشح إضافي للمساعد؛ تظل إعدادات وصلاحيات كل أداة سارية.'
                        : 'An additional assistant-level filter. Each tool setting and permission still applies.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62),
                    ),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < toolsetRows.length; i++) ...[
              if (i > 0) _iosDivider(context),
              _AssistantToolsetRow(
                id: toolsetRows[i].id,
                title: toolsetRows[i].title,
                subtitle: toolsetRows[i].subtitle,
                icon: toolsetRows[i].icon,
                enabled: selectedToolsets.contains(toolsetRows[i].id),
                onChanged: (enabled) => updateToolset(toolsetRows[i].id, enabled),
              ),
            ],
            if (assistant.toolsetIds != null) ...[
              _iosDivider(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: () => ap.updateAssistant(
                      assistant.copyWith(clearToolsetIds: true),
                    ),
                    child: Text(
                      isArabic ? 'استخدام الافتراضي' : 'Use defaults',
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        SectionCard(
          children: [
            if (LocalToolsService.isAvailableOnThisPlatform(
              LocalToolNames.browser,
            )) ...[
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                leading: const Icon(Lucide.Globe),
                title: Text(l10n.browserToolTitle),
                subtitle: Text(
                  '${l10n.browserToolSubtitle} · Managed globally in Browser settings.',
                ),
                trailing: const Icon(Icons.check_circle_outline),
                enabled: false,
              ),
              _iosDivider(context),
            ],
            _LocalToolRow(
              icon: Lucide.clock,
              title: l10n.assistantEditLocalToolTimeInfoTitle,
              subtitle: l10n.assistantEditLocalToolTimeInfoSubtitle,
              enabled: timeEnabled,
              onChanged: (value) => toggleTool(LocalToolNames.timeInfo, value),
            ),
            _iosDivider(context),
            _LocalToolRow(
              icon: Lucide.Clipboard,
              title: l10n.assistantEditLocalToolClipboardTitle,
              subtitle: l10n.assistantEditLocalToolClipboardSubtitle,
              enabled: clipboardEnabled,
              onChanged: (value) => toggleTool(LocalToolNames.clipboard, value),
            ),
            _iosDivider(context),
            _LocalToolRow(
              icon: Lucide.Volume2,
              title: l10n.assistantEditLocalToolTextToSpeechTitle,
              subtitle: l10n.assistantEditLocalToolTextToSpeechSubtitle,
              enabled: textToSpeechEnabled,
              onChanged: (value) =>
                  toggleTool(LocalToolNames.textToSpeech, value),
            ),
            _iosDivider(context),
            _LocalToolRow(
              icon: Lucide.MessageCircleQuestionMark,
              title: l10n.assistantEditLocalToolAskUserTitle,
              subtitle: l10n.assistantEditLocalToolAskUserSubtitle,
              enabled: askUserEnabled,
              onChanged: (value) => toggleTool(LocalToolNames.askUser, value),
            ),
            _iosDivider(context),
            _LocalToolRow(
              icon: Lucide.Calculator,
              title: l10n.assistantEditLocalToolCalculateTitle,
              subtitle: l10n.assistantEditLocalToolCalculateSubtitle,
              enabled: calculateEnabled,
              onChanged: (value) => toggleTool(LocalToolNames.calculate, value),
            ),
            if (DeviceLocalTools.screenTimeSupported) ...[
              _iosDivider(context),
              _LocalToolRow(
                icon: Lucide.Smartphone,
                title: l10n.assistantEditLocalToolScreenTimeTitle,
                subtitle: l10n.assistantEditLocalToolScreenTimeSubtitle,
                enabled: screenTimeEnabled,
                onChanged: (value) =>
                    toggleTool(LocalToolNames.screenTime, value),
              ),
            ],
            if (DeviceLocalTools.calendarSupported) ...[
              _iosDivider(context),
              _LocalToolRow(
                icon: Lucide.Calendar,
                title: l10n.assistantEditLocalToolCalendarQueryTitle,
                subtitle: l10n.assistantEditLocalToolCalendarQuerySubtitle,
                enabled: calendarQueryEnabled,
                onChanged: (value) =>
                    toggleTool(LocalToolNames.calendarQuery, value),
              ),
              _iosDivider(context),
              _LocalToolRow(
                icon: Lucide.CalendarPlus,
                title: l10n.assistantEditLocalToolCalendarCreateTitle,
                subtitle: l10n.assistantEditLocalToolCalendarCreateSubtitle,
                enabled: calendarCreateEnabled,
                onChanged: (value) =>
                    toggleTool(LocalToolNames.calendarCreate, value),
              ),
            ],
            if (DeviceLocalTools.locationSupported) ...[
              _iosDivider(context),
              _LocalToolRow(
                icon: Lucide.MapPin,
                title: l10n.assistantEditLocalToolLocationTitle,
                subtitle: l10n.assistantEditLocalToolLocationSubtitle,
                enabled: locationEnabled,
                onChanged: (value) =>
                    toggleTool(LocalToolNames.currentLocation, value),
              ),
            ],
            if (DeviceLocalTools.phoneControlSupported) ...[
              _iosDivider(context),
              _LocalToolRow(
                icon: Lucide.Smartphone,
                title: l10n.phoneControlTitle,
                subtitle: l10n.phoneControlSubtitle,
                enabled: assistant.localToolIds.contains(
                  LocalToolNames.phoneControl,
                ),
                onChanged: (value) =>
                    toggleTool(LocalToolNames.phoneControl, value),
                onOpenSettings: () => PhoneControlSettingsPage.open(context),
              ),
            ],
            if (DeviceLocalTools.iosDeviceToolsSupported)
              FutureBuilder<bool>(
                future: DeviceLocalTools.prefetchIosCapabilities(),
                builder: (context, snapshot) {
                  if (!DeviceLocalTools.weatherSupported) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _iosDivider(context),
                      _LocalToolRow(
                        icon: Lucide.CloudSun,
                        title: l10n.assistantEditLocalToolWeatherTitle,
                        subtitle: l10n.assistantEditLocalToolWeatherSubtitle,
                        enabled: weatherEnabled,
                        onChanged: (value) =>
                            toggleTool(LocalToolNames.weather, value),
                      ),
                    ],
                  );
                },
              ),
            if (DeviceLocalTools.remindersSupported) ...[
              _iosDivider(context),
              _LocalToolRow(
                icon: Lucide.ListTodo,
                title: l10n.assistantEditLocalToolRemindersQueryTitle,
                subtitle: l10n.assistantEditLocalToolRemindersQuerySubtitle,
                enabled: remindersQueryEnabled,
                onChanged: (value) =>
                    toggleTool(LocalToolNames.remindersQuery, value),
              ),
              _iosDivider(context),
              _LocalToolRow(
                icon: Lucide.ListPlus,
                title: l10n.assistantEditLocalToolRemindersCreateTitle,
                subtitle: l10n.assistantEditLocalToolRemindersCreateSubtitle,
                enabled: remindersCreateEnabled,
                onChanged: (value) =>
                    toggleTool(LocalToolNames.remindersCreate, value),
              ),
              _iosDivider(context),
              _LocalToolRow(
                icon: Lucide.CheckCircle,
                title: l10n.assistantEditLocalToolRemindersCompleteTitle,
                subtitle: l10n.assistantEditLocalToolRemindersCompleteSubtitle,
                enabled: remindersCompleteEnabled,
                onChanged: (value) =>
                    toggleTool(LocalToolNames.remindersComplete, value),
              ),
            ],
            if (DeviceLocalTools.iosDeviceToolsSupported)
              FutureBuilder<bool>(
                future: DeviceLocalTools.prefetchIosCapabilities(),
                builder: (context, snapshot) {
                  if (!DeviceLocalTools.healthSupported) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _iosDivider(context),
                      _HealthToolRow(
                        title: l10n.assistantEditLocalToolHealthTitle,
                        subtitle: l10n.assistantEditLocalToolHealthSubtitle,
                        selectedSummary: l10n
                            .assistantEditLocalToolHealthSelectedCount(
                              HealthDataTypeIds.intersectAvailable(
                                assistant.healthDataTypeIds,
                                DeviceLocalTools.availableHealthTypeIds,
                              ).length,
                              DeviceLocalTools.availableHealthTypeIds.length,
                            ),
                        enabled: healthEnabled,
                        onChanged: (value) =>
                            toggleTool(LocalToolNames.healthSummary, value),
                        onOpenSettings: () =>
                            HealthDataSettingsPage.open(context, assistantId),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _AssistantToolsetRow extends StatelessWidget {
  const _AssistantToolsetRow({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.enabled,
    required this.onChanged,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _TactileRow(
      onTap: () => onChanged(!enabled),
      builder: (pressed) {
        final color = cs.onSurface.withValues(alpha: pressed ? 0.68 : 0.9);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Icon(
                  icon,
                  size: 20,
                  color: enabled ? cs.primary : color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        color: color,
                        fontWeight: AppFontWeights.semibold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.25,
                        color: cs.onSurface.withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              IosSwitch(
                key: ValueKey('assistant-toolset-switch-$id'),
                value: enabled,
                onChanged: onChanged,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LocalToolRow extends StatelessWidget {
  const _LocalToolRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onChanged,
    this.onOpenSettings,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _TactileRow(
      onTap: () => onChanged(!enabled),
      builder: (pressed) {
        final baseColor = cs.onSurface.withValues(alpha: 0.9);
        return _AnimatedPressColor(
          pressed: pressed,
          base: baseColor,
          builder: (color) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 36,
                    child: Icon(
                      icon,
                      size: 20,
                      color: enabled ? cs.primary : color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            color: color,
                            fontWeight: AppFontWeights.semibold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.25,
                            color: cs.onSurface.withValues(alpha: 0.62),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (onOpenSettings != null)
                    IconButton(
                      icon: const Icon(Lucide.Settings, size: 18),
                      tooltip: AppLocalizations.of(context)!.phoneControlTitle,
                      onPressed: onOpenSettings,
                    ),
                  IosSwitch(value: enabled, onChanged: onChanged),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _HealthToolRow extends StatelessWidget {
  const _HealthToolRow({
    required this.title,
    required this.subtitle,
    required this.selectedSummary,
    required this.enabled,
    required this.onChanged,
    required this.onOpenSettings,
  });

  final String title;
  final String subtitle;
  final String selectedSummary;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: _TactileRow(
              onTap: onOpenSettings,
              builder: (pressed) {
                final baseColor = cs.onSurface.withValues(alpha: 0.9);
                return _AnimatedPressColor(
                  pressed: pressed,
                  base: baseColor,
                  builder: (color) {
                    return Row(
                      children: [
                        SizedBox(
                          width: 36,
                          child: Icon(
                            Lucide.HeartPulse,
                            size: 20,
                            color: enabled ? cs.primary : color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: color,
                                  fontWeight: AppFontWeights.semibold,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.25,
                                  color: cs.onSurface.withValues(alpha: 0.62),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                selectedSummary,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.25,
                                  color: cs.primary.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Lucide.ChevronRight,
                          size: 16,
                          color: cs.onSurface.withValues(alpha: 0.35),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          IosSwitch(value: enabled, onChanged: onChanged),
        ],
      ),
    );
  }
}
