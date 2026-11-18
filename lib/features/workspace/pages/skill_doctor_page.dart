import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/database/extension_entity_store.dart';
import '../../../core/providers/environment_provider.dart';
import '../../../core/services/runtime_profiles/runtime_profile_service.dart';
import '../../../core/services/skills/skill_doctor_service.dart';
import '../../../core/services/skills/skills_service.dart';
import '../../../core/services/workspace/workspace_runtime.dart';

class SkillDoctorPage extends StatefulWidget {
  const SkillDoctorPage({super.key});

  @override
  State<SkillDoctorPage> createState() => _SkillDoctorPageState();
}

class _SkillDoctorPageState extends State<SkillDoctorPage> {
  Map<String, Object?>? _report;
  bool _scanning = false;
  String? _error;

  bool get _arabic => Localizations.localeOf(context).languageCode == 'ar';
  String _t(String ar, String en) => _arabic ? ar : en;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  Future<void> _scan() async {
    if (_scanning || !mounted) return;
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      final doctor = SkillDoctorService(
        skills: context.read<SkillsService>(),
        runtimeProfiles: RuntimeProfileService(
          store: context.read<ExtensionEntityStore>(),
          runtimeProvider: context.read<WorkspaceRuntimeProvider>(),
        ),
        runtimeProvider: context.read<WorkspaceRuntimeProvider>(),
        environment: context.read<EnvironmentProvider>(),
      );
      final report = await doctor.scan();
      if (!mounted) return;
      setState(() => _report = report);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final summary = _report?['summary'] is Map
        ? Map<String, Object?>.from(_report!['summary'] as Map)
        : const <String, Object?>{};
    final runtime = _report?['runtime'] is Map
        ? Map<String, Object?>.from(_report!['runtime'] as Map)
        : const <String, Object?>{};
    final skills = (_report?['skills'] as List? ?? const [])
        .whereType<Map>().map((item) => Map<String, Object?>.from(item)).toList();
    final globalIssues = (_report?['globalIssues'] as List? ?? const [])
        .whereType<Map>().map((item) => Map<String, Object?>.from(item)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('طبيب المهارات', 'Skill Doctor')),
        actions: [
          IconButton(
            tooltip: _t('إعادة الفحص', 'Scan again'),
            onPressed: _scanning ? null : _scan,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _scanning && _report == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _report == null
              ? _EmptyError(message: _error!, onRetry: _scan, label: _t('إعادة المحاولة', 'Retry'))
              : RefreshIndicator(
                  onRefresh: _scan,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    children: [
                      _RuntimeCard(runtime: runtime, arabic: _arabic),
                      const SizedBox(height: 12),
                      if (_error != null)
                        _IssueCard(
                          issue: <String, Object?>{
                            'severity': 'warning',
                            'title': _t('لم تكتمل إعادة الفحص', 'The latest scan did not complete'),
                            'detail': _error,
                            'suggestedFix': _t('أعد المحاولة وافحص سجل الخطأ.', 'Retry and review the error details.'),
                            'source': 'SkillDoctorService.scan()',
                          },
                          arabic: _arabic,
                        ),
                      _SummaryGrid(summary: summary, arabic: _arabic),
                      const SizedBox(height: 18),
                      if (globalIssues.isNotEmpty) ...[
                        _SectionTitle(_t('مشكلات البيئة العامة', 'Global environment findings')),
                        for (final issue in globalIssues)
                          _IssueCard(issue: issue, arabic: _arabic),
                        const SizedBox(height: 14),
                      ],
                      _SectionTitle(_t('المهارات المثبتة', 'Installed Skills')),
                      if (skills.isEmpty)
                        _EmptyCard(
                          icon: Icons.extension_off_outlined,
                          title: _t('لا توجد مهارات مثبتة', 'No installed Skills'),
                          detail: _t('استورد مهارة من مكتبة المهارات ثم أعد الفحص.', 'Import a Skill from the Skills library, then scan again.'),
                        ),
                      for (final skill in skills)
                        _SkillCard(skill: skill, arabic: _arabic),
                      const SizedBox(height: 12),
                      Card(
                        color: colors.surfaceContainerHighest,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline, color: colors.onSurfaceVariant),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _t(
                                    'الفحص تشخيصي فقط: لا يشغّل ملفات المهارات أو مديري الحزم أو خوادم MCP، ولا يثبت اعتماديات أو يقرأ قيم الأسرار. نجاح الفحص لا يثبت نجاح إنتاج ملف ناتج؛ يلزم اختبار تشغيل مستقل لكل قدرة.',
                                    'This is a diagnostic scan only: it does not run Skill files, package managers or MCP servers, install dependencies, or read secret values. A clean scan does not prove output production; each capability needs its own execution test.',
                                  ),
                                  style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_report?['scannedAt'] is String)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            '${_t('آخر فحص', 'Last scan')}: ${_report!['scannedAt']}',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _RuntimeCard extends StatelessWidget {
  const _RuntimeCard({required this.runtime, required this.arabic});
  final Map<String, Object?> runtime;
  final bool arabic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ready = runtime['ready'] == true && runtime['sandboxed'] == true && runtime['engine'] == 'proot';
    final color = ready ? theme.colorScheme.primary : theme.colorScheme.error;
    final t = (String ar, String en) => arabic ? ar : en;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(ready ? Icons.verified_user_outlined : Icons.warning_amber_rounded, color: color),
                const SizedBox(width: 10),
                Expanded(child: Text(t('حالة محرك التشغيل', 'Runtime engine status'), style: theme.textTheme.titleMedium)),
                _StatusPill(label: ready ? 'READY' : 'NOT READY', color: color),
              ],
            ),
            const SizedBox(height: 10),
            Text('${t('المحرك', 'Engine')}: ${runtime['engine'] ?? 'unknown'} · ${t('معزول', 'Sandboxed')}: ${runtime['sandboxed'] == true ? t('نعم', 'Yes') : t('لا', 'No')}'),
            Text('${t('RootFS', 'RootFS')}: ${runtime['rootfsPhase'] ?? 'unknown'} · ${runtime['distribution'] ?? '—'} ${runtime['version'] ?? ''}'),
            if (runtime['reason'] != null || runtime['error'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('${runtime['reason'] ?? runtime['error']}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
              ),
            const SizedBox(height: 6),
            Text(
              t('يتطلب تشغيل سكريبتات المهارات Android PRoot جاهزاً. وصف PRoot بأنه sandbox لا يعني وجود عزل أمني على مستوى Kernel.', 'Skill scripts require ready Android PRoot. Calling PRoot a sandbox does not mean kernel-level isolation.'),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary, required this.arabic});
  final Map<String, Object?> summary;
  final bool arabic;

  @override
  Widget build(BuildContext context) {
    final items = <(String, String, IconData)>[
      ('skillsScanned', arabic ? 'مهارات مفحوصة' : 'Skills scanned', Icons.extension_outlined),
      ('healthySkills', arabic ? 'دون مشكلات حرجة/تحذيرات' : 'No critical/warning findings', Icons.check_circle_outline),
      ('critical', arabic ? 'حرجة' : 'Critical', Icons.error_outline),
      ('warnings', arabic ? 'تحذيرات' : 'Warnings', Icons.warning_amber_outlined),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.3,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        final value = summary[item.$1] ?? 0;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(item.$3, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$value', style: Theme.of(context).textTheme.titleLarge),
                      Text(item.$2, style: Theme.of(context).textTheme.labelSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SkillCard extends StatelessWidget {
  const _SkillCard({required this.skill, required this.arabic});
  final Map<String, Object?> skill;
  final bool arabic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final issues = (skill['issues'] as List? ?? const [])
        .whereType<Map>().map((item) => Map<String, Object?>.from(item)).toList();
    final counts = skill['issueCounts'] is Map ? Map<String, Object?>.from(skill['issueCounts'] as Map) : const <String, Object?>{};
    final profile = skill['runtimeProfile'] is Map ? Map<String, Object?>.from(skill['runtimeProfile'] as Map) : null;
    final profileProbe = skill['profileProbe'] is Map
        ? Map<String, Object?>.from(skill['profileProbe'] as Map)
        : const <String, Object?>{};
    final probedCommands = (profileProbe['commands'] as List? ?? const [])
        .whereType<Map>().map((entry) => Map<String, Object?>.from(entry)).toList();
    final rawReadiness = skill['readinessLabel']?.toString() ?? 'Not Ready';
    final readiness = arabic ? switch (rawReadiness) {
      'Ready for Guidance' => 'جاهزة للإرشاد',
      'Ready for Execution' => 'جاهزة للتنفيذ',
      'Fully Ready' => 'جاهزة بالكامل',
      'Not Ready' => 'غير جاهزة',
      _ => rawReadiness,
    } : rawReadiness;
    final t = (String ar, String en) => arabic ? ar : en;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: Icon(Icons.extension_outlined, color: skill['enabled'] == true ? cs.primary : cs.onSurfaceVariant),
        title: Text(skill['name']?.toString() ?? skill['id']?.toString() ?? 'Skill', maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${t('الجاهزية', 'Readiness')}: $readiness · ${t('المشكلات', 'Findings')}: ${issues.length}'),
        trailing: _IssueCountPills(counts: counts),
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _StatusPill(label: skill['importCompleteness']?.toString() ?? 'unknown', color: skill['importCompleteness'] == 'complete' ? cs.primary : cs.error),
                if (profile != null)
                  _StatusPill(label: '${profile['name']} · ${profile['status']}', color: profile['status'] == 'ready' ? cs.primary : cs.error),
                if (skill['enabled'] != true)
                  _StatusPill(label: t('معطّلة', 'Disabled'), color: cs.tertiary),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _DetailRow(label: t('المعرّف', 'ID'), value: skill['id']?.toString() ?? '—'),
          _DetailRow(label: t('المصدر', 'Source'), value: skill['source']?.toString() ?? '—'),
          _DetailRow(label: t('سلامة الملفات', 'File integrity'), value: (skill['integrity'] as Map?)?['status']?.toString() ?? 'not_checked'),
          _DetailRow(label: t('فحص أوامر البيئة', 'Profile command probe'), value: profileProbe['status']?.toString() ?? 'not_run'),
          for (final command in probedCommands)
            _DetailRow(
              label: command['name']?.toString() ?? t('أمر', 'Command'),
              value: [
                command['status']?.toString() ?? 'unknown',
                if (command['verifiedIn'] != null) command['verifiedIn'].toString(),
                if (command['path'] != null) command['path'].toString(),
              ].join(' · '),
            ),
          if (profile == null && (skill['runtimeProfileCandidates'] as List? ?? const []).isNotEmpty)
            _DetailRow(label: t('ملفات مرشحة', 'Profile candidates'), value: '${(skill['runtimeProfileCandidates'] as List).length}'),
          const SizedBox(height: 8),
          if (issues.isEmpty)
            Text(t('لم تُسجل مشكلات لهذه المهارة.', 'No findings recorded for this Skill.'))
          else
            for (final issue in issues) _IssueCard(issue: issue, arabic: arabic),
        ],
      ),
    );
  }
}

class _IssueCard extends StatelessWidget {
  const _IssueCard({required this.issue, required this.arabic});
  final Map<String, Object?> issue;
  final bool arabic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final severity = issue['severity']?.toString() ?? 'info';
    final color = switch (severity) {
      'critical' => cs.error,
      'warning' => cs.tertiary,
      _ => cs.primary,
    };
    final issueId = issue['id']?.toString() ?? '';
    final title = _doctorArabicTitle(issueId, issue['title']?.toString() ?? 'Finding', arabic);
    final detail = issue['detail']?.toString() ?? '';
    final source = issue['source']?.toString() ?? '';
    final fix = _doctorArabicFix(issueId, issue['suggestedFix']?.toString() ?? '', arabic);
    final t = (String ar, String en) => arabic ? ar : en;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(switch (severity) { 'critical' => Icons.error_outline, 'warning' => Icons.warning_amber, _ => Icons.info_outline }, color: color, size: 19),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
              _StatusPill(label: severity.toUpperCase(), color: color),
            ],
          ),
          if (detail.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: SelectableText(detail, style: theme.textTheme.bodySmall)),
          if (source.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${t('مصدر الدليل', 'Evidence source')}: $source', style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant))),
          if (fix.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${t('الإجراء المقترح', 'Suggested action')}: $fix', style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _IssueCountPills extends StatelessWidget {
  const _IssueCountPills({required this.counts});
  final Map<String, Object?> counts;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 4,
        children: [
          if ((counts['critical'] as num? ?? 0) > 0) _StatusPill(label: '${counts['critical']}!', color: Theme.of(context).colorScheme.error),
          if ((counts['warning'] as num? ?? 0) > 0) _StatusPill(label: '${counts['warning']}!', color: Theme.of(context).colorScheme.tertiary),
          if ((counts['info'] as num? ?? 0) > 0) _StatusPill(label: '${counts['info']}', color: Theme.of(context).colorScheme.primary),
        ],
      );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 132, child: Text(label, style: Theme.of(context).textTheme.labelMedium)),
            Expanded(child: SelectableText(value, style: Theme.of(context).textTheme.bodySmall)),
          ],
        ),
      );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.title, required this.detail});
  final IconData icon;
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(20),
    child: Column(children: [Icon(icon, size: 32), const SizedBox(height: 8), Text(title), const SizedBox(height: 4), Text(detail, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall)]),
  ));
}

class _EmptyError extends StatelessWidget {
  const _EmptyError({required this.message, required this.onRetry, required this.label});
  final String message;
  final VoidCallback onRetry;
  final String label;
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.health_and_safety_outlined, size: 36),
      const SizedBox(height: 12),
      SelectableText(message, textAlign: TextAlign.center),
      const SizedBox(height: 12),
      FilledButton(onPressed: onRetry, child: Text(label)),
    ]),
  ));
}

String _doctorArabicTitle(String id, String fallback, bool arabic) {
  if (!arabic) return fallback;
  const titles = <String, String>{
    'runtime-unavailable': 'محرك PRoot غير متاح',
    'runtime-unsupported': 'محرك التشغيل الحالي غير مدعوم',
    'rootfs-not-ready': 'بيئة RootFS الأساسية ليست جاهزة',
    'manifest-missing': 'ملف استيراد المهارة غير موجود',
    'import-incomplete': 'لم يثبت اكتمال استيراد المهارة',
    'source-integrity-changed': 'تغيّرت ملفات المهارة عن النسخة المستوردة',
    'source-integrity-missing': 'توجد ملفات مفقودة من المهارة',
    'source-integrity-unsafe': 'اكتُشفت مسارات أو روابط ملفات غير آمنة',
    'source-integrity-inconclusive': 'تعذر إكمال فحص سلامة الملفات',
    'untracked-skill-files': 'توجد ملفات غير مسجلة في بيان الاستيراد',
    'requirements-not-analyzed': 'لم يُحلل سجل المتطلبات بعد',
    'selected-profile-missing': 'ملف Runtime Profile المحدد لم يعد موجوداً',
    'profile-selection-ambiguous': 'توجد عدة ملفات Runtime Profile لهذه المهارة',
    'runtime-profile-missing': 'لا يوجد Runtime Profile مملوك للمهارة',
    'runtime-profile-ecosystems-missing': 'ملف التشغيل لا يضم جميع البيئات المطلوبة',
    'commands-missing': 'بعض الأوامر المطلوبة غير موجودة',
    'commands-base-only': 'بعض الأوامر متاحة من RootFS المشترك فقط',
    'commands-invalid-name': 'اسم أمر غير آمن وتم تخطي فحصه',
    'profile-command-probe-not-completed': 'لم يكتمل فحص أوامر Runtime Profile',
    'skill-disabled': 'المهارة مثبتة لكنها معطّلة',
    'no-current-findings': 'لم تُكتشف مشكلات ضمن الفحوص الحالية',
  };
  if (titles.containsKey(id)) return titles[id]!;
  if (id.startsWith('runtime-profile-')) return 'ملف Runtime Profile غير جاهز';
  if (id.startsWith('package-')) return 'اعتمادية حزمة لم يتم التحقق منها';
  if (id.startsWith('credential-')) return 'مراجعة صلاحية بيانات الاعتماد';
  if (id.startsWith('external-service-')) return 'اتصال خدمة خارجية غير متحقق منه';
  if (id.startsWith('capability-')) return 'قدرة المهارة غير متاحة أو غير متحققة';
  if (id.startsWith('orphan-profile-')) return 'ملف تشغيل دون مهارة مالكة';
  if (id.startsWith('process-')) return 'عملية سابقة لم تكتمل بنجاح';
  return fallback;
}

String _doctorArabicFix(String id, String fallback, bool arabic) {
  if (!arabic) return fallback;
  if (id == 'runtime-unavailable' || id == 'runtime-unsupported') {
    return 'افتح إعدادات البيئة وأكمل إعداد PRoot المدعوم ثم أعد الفحص.';
  }
  if (id == 'rootfs-not-ready') {
    return 'أصلح إعداد RootFS أو أكمل تثبيته قبل التحقق من الاعتماديات.';
  }
  if (id.startsWith('source-integrity-')) {
    return 'راجع الملفات المتغيرة أو المفقودة، ثم أعد الاستيراد من مصدر موثوق. لن يستبدل الطبيب ملفاتك.';
  }
  if (id == 'runtime-profile-missing' || id == 'selected-profile-missing') {
    return 'أنشئ ملف Runtime Profile مملوكاً لهذه المهارة أو اختر ملفاً صحيحاً ثم أعد التحقق.';
  }
  if (id == 'commands-invalid-name') {
    return 'راجع اسم الأمر في مصدر المهارة وأزل الرموز أو المسارات غير المسموح بها.';
  }
  if (id == 'commands-missing' || id == 'commands-base-only') {
    return 'جهّز الأوامر داخل ملف Runtime Profile معتمد، ثم أعد الفحص.';
  }
  if (id.startsWith('capability-')) {
    return 'أضف موائم تنفيذ معتمداً لهذه القدرة، مع الصلاحيات والاختبارات المطلوبة.';
  }
  return fallback;
}

Future<void> openSkillDoctorPage(BuildContext context) => Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const SkillDoctorPage()),
    );
