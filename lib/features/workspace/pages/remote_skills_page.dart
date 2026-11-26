import 'dart:async';

import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/services/mcp/remote_skill_discovery_service.dart';
import 'package:flutter/material.dart';
import 'package:mcp_client/mcp_client.dart' as mcp;
import 'package:provider/provider.dart';

class RemoteSkillsPage extends StatefulWidget {
  const RemoteSkillsPage({super.key});

  @override
  State<RemoteSkillsPage> createState() => _RemoteSkillsPageState();
}

class _RemoteSkillsPageState extends State<RemoteSkillsPage> {
  late final McpProvider _provider;
  final RemoteSkillDiscoveryService _service = RemoteSkillDiscoveryService();
  List<McpServerConfig> _sources = const [];
  RemoteSkillDiscoverySession? _session;
  final List<_RemoteSkillItem> _skills = [];
  String? _nextCursor;
  String? _openedContent;
  String? _openedContentUri;
  bool _loadingSources = true;
  bool _connecting = false;
  bool _loadingMore = false;
  bool _reading = false;
  String? _error;

  bool get _isArabic =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
  String _copy(String ar, String en) => _isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _provider = context.read<McpProvider>();
    unawaited(_loadConfiguredSources());
  }

  Future<void> _loadConfiguredSources() async {
    try {
      await _provider.loaded;
      if (!mounted) return;
      final available = _provider.servers.where((server) {
        if (!server.enabled || server.transport != McpTransportType.http) {
          return false;
        }
        final uri = Uri.tryParse(server.url);
        return uri != null &&
            uri.scheme == 'https' &&
            uri.hasAuthority &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty &&
            !uri.hasFragment;
      }).toList(growable: false);
      setState(() {
        _sources = available;
        _loadingSources = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingSources = false;
        _error = _copy(
          'تعذر قراءة مصادر MCP المحفوظة.',
          'Could not load configured MCP sources.',
        );
      });
    }
  }

  String _endpointLabel(McpServerConfig source) {
    final uri = Uri.tryParse(source.url);
    if (uri == null) return '';
    // Endpoint query parameters may contain API keys or bearer credentials.
    return uri.replace(query: '', fragment: '').toString();
  }

  mcp.McpSkillResource? _skillDocument(_RemoteSkillItem item) {
    for (final resource in item.skill.resources) {
      if (resource.uri == item.skill.uri) return resource;
    }
    return null;
  }

  Future<bool> _confirmMetadataDiscovery(McpServerConfig source) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(_copy(
              'السماح باستكشاف Skills البعيدة؟',
              'Allow remote Skill discovery?',
            )),
            content: Text(_copy(
              'سيتم الاتصال بالمصدر المحدد وإرسال server/discover وskills/list لعرض الأسماء والأوصاف وبيانات الموارد فقط. لن تُقرأ أي ملفات Skill، ولن تُستورد أو تُنفّذ أي مهارة، ولن تُستدعَ الأدوات. هل تسمح بهذه العملية؟\n\nالمصدر: ${source.name}\n${_endpointLabel(source)}',
              'KELIVO will contact this configured source and send server/discover and skills/list to retrieve names, descriptions and resource metadata only. No Skill file will be read, imported or executed, and no tools will be called. Continue?\n\nSource: ${source.name}\n${_endpointLabel(source)}',
            )),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(_copy('إلغاء', 'Cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(_copy('السماح بالبيانات الوصفية', 'Allow metadata only')),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _confirmResourceRead(_RemoteSkillItem item) async {
    final declared = _skillDocument(item);
    if (declared == null) return false;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(_copy('قراءة ملف Skill؟', 'Read this Skill file?')),
            content: SelectableText(_copy(
              'هذه موافقة منفصلة لقراءة المورد المعلن SKILL.md فقط. سيتحقق KELIVO من الحجم وSHA-256 وبيانات Frontmatter قبل عرض النص. سيظل المحتوى غير موثوق ولن يُنفّذ أو يُستورد.\n\nURI: ${declared.uri}\nالحجم المعلن: ${declared.size} bytes\nSHA-256: ${declared.digest}',
              'This is a separate approval to read only the declared SKILL.md resource. KELIVO will verify size, SHA-256 and frontmatter before showing the text. The content remains untrusted and will not be executed or imported.\n\nURI: ${declared.uri}\nDeclared size: ${declared.size} bytes\nSHA-256: ${declared.digest}',
            )),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(_copy('إلغاء', 'Cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(_copy('قراءة هذا المورد', 'Read this resource')),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _connect(McpServerConfig source) async {
    if (_connecting || _session != null) return;
    if (!await _confirmMetadataDiscovery(source) || !mounted) return;
    setState(() {
      _connecting = true;
      _error = null;
      _skills.clear();
      _nextCursor = null;
      _openedContent = null;
      _openedContentUri = null;
    });
    RemoteSkillDiscoverySession? session;
    try {
      session = await _service.connect(source);
      if (!mounted) {
        await session.dispose();
        return;
      }
      final listing = await session.listSkills();
      if (!mounted) {
        await session.dispose();
        return;
      }
      setState(() {
        _session = session;
        _appendListing(listing);
        _connecting = false;
      });
    } catch (error) {
      await session?.dispose();
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _error = _safeError(error);
      });
    }
  }

  void _appendListing(mcp.McpSkillsListResult listing) {
    for (var index = 0; index < listing.skills.length; index++) {
      _skills.add(_RemoteSkillItem(
        skill: listing.skills[index],
        snapshot: listing.snapshots[index],
      ));
    }
    _nextCursor = listing.paginationTruncated ? listing.nextCursor : null;
  }

  Future<void> _loadMore() async {
    final session = _session;
    final cursor = _nextCursor;
    if (session == null || cursor == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final listing = await session.listSkills(cursor: cursor);
      if (!mounted) return;
      setState(() {
        _appendListing(listing);
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _error = _safeError(error);
      });
    }
  }

  Future<void> _read(_RemoteSkillItem item) async {
    final session = _session;
    if (session == null || _reading || item.skill.isDynamic) return;
    if (_skillDocument(item) == null) return;
    if (!await _confirmResourceRead(item) || !mounted) return;
    setState(() {
      _reading = true;
      _error = null;
    });
    try {
      final verified = await session.readSkillResource(
        snapshot: item.snapshot,
        uri: item.skill.uri,
      );
      if (!mounted) return;
      setState(() {
        _openedContent = verified.text;
        _openedContentUri = verified.uri;
        _reading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _reading = false;
        _error = _safeError(error);
      });
    }
  }

  String _safeError(Object error) {
    if (error is UnsupportedError) {
      return _copy(
        'المصدر لا يعلن امتداد MCP Skills المطلوب أو أن وسيلة النقل غير مدعومة.',
        'The source does not advertise the required MCP Skills extension or transport.',
      );
    }
    if (error is FormatException) {
      return _copy(
        'عنوان المصدر أو بياناته غير صالحة أو تخالف سياسة الأمان.',
        'The source endpoint or metadata is invalid or violates security policy.',
      );
    }
    if (error is StateError) {
      return _copy(
        'تعذر فتح المصدر. قد تكون بيانات OAuth منتهية أو أن المصدر معطّل.',
        'Could not open the source. OAuth credentials may have expired or the source may be disabled.',
      );
    }
    return _copy(
      'فشلت العملية. لم تُعرض تفاصيل الاتصال حفاظاً على سرية بيانات الاعتماد.',
      'The operation failed. Connection details are hidden to protect credentials.',
    );
  }

  Future<void> _closeSession() async {
    final current = _session;
    setState(() {
      _session = null;
      _skills.clear();
      _nextCursor = null;
      _openedContent = null;
      _openedContentUri = null;
    });
    await current?.dispose();
  }

  @override
  void dispose() {
    final current = _session;
    if (current != null) unawaited(current.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_copy('اكتشاف Skills البعيدة', 'Remote Skills discovery')),
        actions: [
          if (_session != null)
            IconButton(
              tooltip: _copy('إنهاء الاتصال', 'Close session'),
              onPressed: () => unawaited(_closeSession()),
              icon: const Icon(Icons.link_off),
            ),
        ],
      ),
      body: _loadingSources
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.verified_user_outlined, color: colors.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _copy('استكشاف آمن وبموافقتك', 'Secure, consent-based discovery'),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(_copy(
                          'تُعرض البيانات الوصفية أولاً. قراءة كل ملف تتطلب موافقة منفصلة. المحتوى البعيد غير موثوق ولا يُثبّت أو يُنفّذ تلقائياً.',
                          'Metadata is shown first. Each file read needs separate approval. Remote content is untrusted and is never installed or executed automatically.',
                        )),
                      ],
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _MessageCard(message: _error!, isError: true),
                ],
                if (_session == null) ...[
                  const SizedBox(height: 18),
                  Text(
                    _copy('مصادر HTTPS المحفوظة والمفعّلة', 'Saved and enabled HTTPS sources'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (_sources.isEmpty)
                    _MessageCard(message: _copy(
                      'لا توجد مصادر Streamable HTTP مفعّلة بعنوان HTTPS. أضف مصدراً من إعدادات MCP أولاً.',
                      'No enabled HTTPS Streamable HTTP source is configured. Add a source in MCP settings first.',
                    ))
                  else
                    ..._sources.map((source) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.cloud_outlined),
                        title: Text(source.name),
                        subtitle: Text(
                          _endpointLabel(source),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: _connecting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: _connecting ? null : () => unawaited(_connect(source)),
                      ),
                    )),
                ] else ...[
                  const SizedBox(height: 12),
                  Text(
                    _copy('المهارات المكتشفة', 'Discovered Skills'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_session!.server.name} · ${_skills.length}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_skills.isEmpty)
                    _MessageCard(message: _copy('لم يُعلن المصدر عن أي Skills.', 'The source did not advertise any Skills.')),
                  ..._skills.map(_skillCard),
                  if (_nextCursor != null)
                    OutlinedButton.icon(
                      onPressed: _loadingMore ? null : () => unawaited(_loadMore()),
                      icon: _loadingMore
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.expand_more),
                      label: Text(_copy('تحميل المزيد من البيانات الوصفية', 'Load more metadata')),
                    ),
                  if (_openedContent != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _copy('محتوى بعيد تم التحقق منه — غير موثوق', 'Verified remote content — untrusted'),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            SelectableText(_openedContentUri ?? ''),
                            const Divider(),
                            SelectableText(
                              _openedContent!,
                              style: const TextStyle(fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
    );
  }

  Widget _skillCard(_RemoteSkillItem item) {
    final colors = Theme.of(context).colorScheme;
    final skill = item.skill;
    final hasDocument = _skillDocument(item) != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(skill.name, style: Theme.of(context).textTheme.titleMedium),
                ),
                if (skill.isDynamic)
                  Chip(label: Text(_copy('ديناميكي', 'Dynamic'))),
              ],
            ),
            const SizedBox(height: 6),
            Text(skill.description),
            const SizedBox(height: 10),
            Text(skill.uri, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            if (skill.isDynamic)
              Text(
                _copy('موارد ديناميكية: لا يمكن التحقق من بصمتها، لذلك لن تتم قراءتها.', 'Dynamic resources cannot be integrity-verified and will not be read.'),
                style: TextStyle(color: colors.error),
              )
            else if (!hasDocument)
              Text(
                _copy('لم يعلن المصدر عن مورد SKILL.md قابل للتحقق.', 'No verifiable SKILL.md resource was declared.'),
                style: TextStyle(color: colors.error),
              )
            else
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: OutlinedButton.icon(
                  onPressed: _reading ? null : () => unawaited(_read(item)),
                  icon: const Icon(Icons.description_outlined),
                  label: Text(_copy('مراجعة الملف', 'Review file')),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

final class _RemoteSkillItem {
  const _RemoteSkillItem({required this.skill, required this.snapshot});
  final mcp.McpSkillEntry skill;
  final mcp.McpSkillSnapshot snapshot;
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          message,
          style: TextStyle(color: isError ? colors.error : colors.onSurfaceVariant),
        ),
      ),
    );
  }
}
