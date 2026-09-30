import 'package:flutter/material.dart';

import '../i18n/localized_text.dart';
import '../services/api_service.dart';

/// مركز الثقة والتشغيل — نفس البيانات السابقة بتصميم جديد (نهاري وليلي).
class SupportTrustCenterScreen extends StatefulWidget {
  const SupportTrustCenterScreen({super.key, this.initialData});

  /// Optional preloaded data (used for previews/tests); normally loaded from the API.
  final Map<String, dynamic>? initialData;
  @override
  State<SupportTrustCenterScreen> createState() => _SupportTrustCenterScreenState();
}

class _SupportTrustCenterScreenState extends State<SupportTrustCenterScreen> {
  Map<String, dynamic>? data;
  bool busy = true;
  String? error;

  List<dynamic> _list(Object? value) => List<dynamic>.from(value as List? ?? const []);
  Map<String, dynamic> _map(Object? value) => Map<String, dynamic>.from(value as Map? ?? const {});
  Set<String> get permissions => _list(data?['permissions']).map((e) => e.toString()).toSet();

  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _dark ? const Color(0xFF060D1B) : const Color(0xFFF3F6FB);
  Color get _card => _dark ? const Color(0xFF0E1A31) : Colors.white;
  Color get _border => _dark ? const Color(0xFF1B2D4D) : const Color(0xFFE2E8F0);
  Color get _text => _dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  Color get _muted => _dark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
  Color _accent(Color darkColor, Color lightColor) => _dark ? darkColor : lightColor;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      data = widget.initialData;
      busy = false;
    } else {
      load();
    }
  }

  Future<void> load() async {
    try {
      final d = await ApiService.fetchSupportTrustDashboard();
      data = d;
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'تعذر تنفيذ العملية. تحقق من اتصالك وحاول مرة أخرى.';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> createIncident() async {
    final title = TextEditingController();
    final message = TextEditingController();
    String severity = 'major';
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setDialog) => AlertDialog(
          title: const TrText('حادثة عامة جديدة'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: title, decoration: InputDecoration(labelText: 'العنوان'.tr())),
              const SizedBox(height: 8),
              TextField(controller: message, maxLines: 4, decoration: InputDecoration(labelText: 'رسالة البانر'.tr())),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: severity,
                items: const [
                  DropdownMenuItem(value: 'minor', child: Text('Minor')),
                  DropdownMenuItem(value: 'major', child: Text('Major')),
                  DropdownMenuItem(value: 'critical', child: Text('Critical')),
                ],
                onChanged: (v) => setDialog(() => severity = v ?? 'major'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const TrText('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: const TrText('إنشاء')),
          ],
        ),
      ),
    );
    if (ok == true && title.text.trim().isNotEmpty && message.text.trim().isNotEmpty) {
      try {
        await ApiService.createSupportIncidentV25({
          'title': title.text.trim(),
          'message': message.text.trim(),
          'severity': severity,
          'status': 'investigating',
          'banner_enabled': true,
        });
        await load();
      } on ApiException catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
      }
    }
    Future<void>.delayed(const Duration(milliseconds: 600), title.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), message.dispose);
  }

  // ------------------------------------------------------------------ pieces

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: _dark
              ? const [Color(0xFF0B2A4A), Color(0xFF0E1A31)]
              : const [Color(0xFF1D4ED8), Color(0xFF0891B2)],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(trUi('مركز الثقة والتشغيل'),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  trUi('الحوادث العامة وتعليق الصرف والتوثيق المهني وطلبات الخصوصية في مكان واحد.'),
                  style: TextStyle(color: Colors.white.withValues(alpha: .85), fontSize: 11.5, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat({required IconData icon, required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: _dark ? .16 : .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(color: _text, fontSize: 20, fontWeight: FontWeight.w900)),
                Text(trUi(label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> items,
    required String empty,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(trUi(title), style: TextStyle(color: _text, fontSize: 15, fontWeight: FontWeight.w900)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text('${items.length}', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12)),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: _border),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, color: _accent(const Color(0xFF34D399), const Color(0xFF059669)), size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(trUi(empty), style: TextStyle(color: _muted, fontSize: 12.5, fontWeight: FontWeight.w600))),
                ],
              ),
            )
          else
            ...items,
        ],
      ),
    );
  }

  Widget _row({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    List<String> chips = const [],
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _border.withValues(alpha: .6)))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(trUi(title), style: TextStyle(color: _text, fontSize: 13.5, fontWeight: FontWeight.w800)),
                if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(trUi(subtitle), style: TextStyle(color: _muted, fontSize: 11.5, height: 1.5)),
                ],
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: chips
                        .where((c) => c.trim().isNotEmpty)
                        .map((c) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _dark ? const Color(0xFF16233D) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(color: _border),
                              ),
                              child: Text(trUi(c), style: TextStyle(color: _muted, fontSize: 10.5, fontWeight: FontWeight.w700)),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _severityColor(String s) {
    switch (s) {
      case 'critical':
        return _accent(const Color(0xFFFB7185), const Color(0xFFE11D48));
      case 'major':
        return _accent(const Color(0xFFFBBF24), const Color(0xFFD97706));
      default:
        return _accent(const Color(0xFF60A5FA), const Color(0xFF2563EB));
    }
  }

  String _date(Object? v) {
    final s = v?.toString() ?? '';
    if (s.isEmpty) return '—';
    return s.length >= 10 ? s.substring(0, 10) : s;
  }

  @override
  Widget build(BuildContext context) {
    final holds = _list(data?['holds']);
    final professional = _list(data?['expiring_professional']);
    final requests = _list(data?['data_requests']);
    final incidents = _list(data?['incidents']);
    final canIncident = permissions.contains('support.incidents.manage');

    final red = _accent(const Color(0xFFFB7185), const Color(0xFFE11D48));
    final amber = _accent(const Color(0xFFFBBF24), const Color(0xFFD97706));
    final blue = _accent(const Color(0xFF60A5FA), const Color(0xFF2563EB));
    final violet = _accent(const Color(0xFFC4B5FD), const Color(0xFF7C3AED));
    final cyan = _accent(const Color(0xFF22D3EE), const Color(0xFF0891B2));

    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          surfaceTintColor: Colors.transparent,
          foregroundColor: _text,
          elevation: 0,
          title: Text(trUi('مركز الثقة والتشغيل'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          actions: [
            IconButton(onPressed: () { setState(() => busy = true); load(); }, icon: const Icon(Icons.refresh_rounded), tooltip: trUi('تحديث')),
          ],
        ),
        floatingActionButton: canIncident && !busy && error == null
            ? FloatingActionButton.extended(
                onPressed: createIncident,
                icon: const Icon(Icons.add_alert_outlined),
                label: Text(trUi('حادثة عامة')),
              )
            : null,
        body: busy
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.cloud_off_rounded, size: 44, color: _muted),
                        const SizedBox(height: 10),
                        Text(trUi(error!), textAlign: TextAlign.center, style: TextStyle(color: _text)),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () { setState(() => busy = true); load(); },
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(trUi('إعادة المحاولة')),
                        ),
                      ]),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 96),
                      children: [
                        _header(),
                        const SizedBox(height: 14),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 2.15,
                          children: [
                            _stat(icon: Icons.warning_amber_rounded, label: 'حوادث مفتوحة', value: '${data?['open_incidents'] ?? 0}', color: red),
                            _stat(icon: Icons.repeat_rounded, label: 'Repeat Contact', value: '${data?['repeat_rate'] ?? 0}%', color: cyan),
                            _stat(icon: Icons.lock_clock_outlined, label: 'تعليق صرف', value: '${holds.length}', color: amber),
                            _stat(icon: Icons.workspace_premium_outlined, label: 'توثيق ينتهي', value: '${professional.length}', color: blue),
                            _stat(icon: Icons.privacy_tip_outlined, label: 'طلبات الخصوصية', value: '${requests.length}', color: violet),
                          ],
                        ),
                        _section(
                          icon: Icons.warning_amber_rounded,
                          title: 'الحوادث العامة',
                          color: red,
                          empty: 'لا توجد حوادث عامة حاليًا.',
                          items: incidents.map((x) {
                            final i = _map(x);
                            final sev = '${i['severity'] ?? ''}';
                            return _row(
                              icon: Icons.campaign_outlined,
                              color: _severityColor(sev),
                              title: '${i['title'] ?? 'حادثة'}',
                              subtitle: '${i['message'] ?? ''}',
                              chips: [sev, '${i['status'] ?? ''}', _date(i['created_at'])],
                            );
                          }).toList(),
                        ),
                        _section(
                          icon: Icons.lock_clock_outlined,
                          title: 'تعليق الصرف الأمني',
                          color: amber,
                          empty: 'لا توجد حجوزات أمنية مسجلة.',
                          items: holds.map((x) {
                            final h = _map(x);
                            return _row(
                              icon: Icons.person_outline_rounded,
                              color: amber,
                              title: '${h['user_name'] ?? 'User #${h['user_id'] ?? '—'}'}',
                              subtitle: '${h['reason'] ?? ''}',
                              chips: ['#${h['user_id'] ?? '—'}', '${trUi('حتى')} ${_date(h['ends_at'])}'],
                            );
                          }).toList(),
                        ),
                        _section(
                          icon: Icons.workspace_premium_outlined,
                          title: 'التوثيق المهني القريب من الانتهاء',
                          color: blue,
                          empty: 'لا يوجد توثيق مهني قريب من الانتهاء.',
                          items: professional.map((x) {
                            final p = _map(x);
                            return _row(
                              icon: Icons.engineering_outlined,
                              color: blue,
                              title: '${p['user_name'] ?? 'مهندس'}',
                              subtitle: '${p['user_email'] ?? ''}',
                              chips: [
                                '${trUi('ترخيص:')} ${_date(p['license_expires_at'])}',
                                '${trUi('نقابة:')} ${_date(p['syndicate_expires_at'])}',
                              ],
                            );
                          }).toList(),
                        ),
                        _section(
                          icon: Icons.privacy_tip_outlined,
                          title: 'طلبات الخصوصية',
                          color: violet,
                          empty: 'لا توجد طلبات خصوصية حاليًا.',
                          items: requests.map((x) {
                            final r = _map(x);
                            return _row(
                              icon: Icons.folder_shared_outlined,
                              color: violet,
                              title: '#${r['id'] ?? ''} • ${r['request_type'] ?? ''}',
                              subtitle: 'User #${r['user_id'] ?? '—'}',
                              chips: ['${r['status'] ?? ''}', '${trUi('التنفيذ بعد')} ${_date(r['execute_after'])}'],
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
