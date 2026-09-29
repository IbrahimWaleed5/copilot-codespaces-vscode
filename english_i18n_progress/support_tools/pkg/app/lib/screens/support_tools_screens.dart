import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../i18n/localized_text.dart';
import '../services/api_service.dart';

/// أدوات الدعم: التوزيع التلقائي، Email + WhatsApp، فحص المرفقات.
/// تعتمد على /api/support-tools/* (SupportToolsApiController).

// ---------------------------------------------------------------- shared look

class _Look {
  _Look(this.context);
  final BuildContext context;
  bool get dark => Theme.of(context).brightness == Brightness.dark;
  Color get bg => dark ? const Color(0xFF060D1B) : const Color(0xFFF3F6FB);
  Color get card => dark ? const Color(0xFF0E1A31) : Colors.white;
  Color get border => dark ? const Color(0xFF1B2D4D) : const Color(0xFFE2E8F0);
  Color get text => dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  Color get muted => dark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
  Color get soft => dark ? const Color(0xFF16233D) : const Color(0xFFF1F5F9);
  Color c(Color darkColor, Color lightColor) => dark ? darkColor : lightColor;
  Color get green => c(const Color(0xFF34D399), const Color(0xFF059669));
  Color get red => c(const Color(0xFFFB7185), const Color(0xFFE11D48));
  Color get amber => c(const Color(0xFFFBBF24), const Color(0xFFD97706));
  Color get blue => c(const Color(0xFF60A5FA), const Color(0xFF2563EB));
  Color get cyan => c(const Color(0xFF22D3EE), const Color(0xFF0891B2));
  Color get violet => c(const Color(0xFFC4B5FD), const Color(0xFF7C3AED));

  BoxDecoration box({double radius = 18}) => BoxDecoration(
    color: card,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: border),
  );

  Widget header({
    required IconData icon,
    required String title,
    required String subtitle,
    List<Color>? colors,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors:
              colors ??
              (dark
                  ? const [Color(0xFF0B2A4A), Color(0xFF0E1A31)]
                  : const [Color(0xFF1D4ED8), Color(0xFF0891B2)]),
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
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trUi(title),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  trUi(subtitle),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .86),
                    fontSize: 11.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget stat(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: box(radius: 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  trUi(label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: color.withValues(alpha: .35)),
    ),
    child: Text(
      trUi(label),
      style: TextStyle(
        color: color,
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  Widget sectionTitle(
    IconData icon,
    String title,
    Color color, {
    Widget? trailing,
  }) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
    child: Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            trUi(title),
            style: TextStyle(
              color: text,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    ),
  );

  Widget empty(String message) => Container(
    padding: const EdgeInsets.all(16),
    decoration: box(),
    child: Row(
      children: [
        Icon(Icons.check_circle_outline_rounded, color: green, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            trUi(message),
            style: TextStyle(
              color: muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget errorView(String message, VoidCallback retry) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 44, color: muted),
          const SizedBox(height: 10),
          Text(
            trUi(message),
            textAlign: TextAlign.center,
            style: TextStyle(color: text),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(trUi('إعادة المحاولة')),
          ),
        ],
      ),
    ),
  );

  PreferredSizeWidget appBar(String title, VoidCallback refresh) => AppBar(
    backgroundColor: bg,
    surfaceTintColor: Colors.transparent,
    foregroundColor: text,
    elevation: 0,
    title: Text(
      trUi(title),
      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
    ),
    actions: [
      IconButton(
        onPressed: refresh,
        icon: const Icon(Icons.refresh_rounded),
        tooltip: trUi('تحديث'),
      ),
    ],
  );
}

List<dynamic> _list(Object? v) => List<dynamic>.from(v as List? ?? const []);
Map<String, dynamic> _map(Object? v) =>
    Map<String, dynamic>.from(v as Map? ?? const {});
int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
String _date(Object? v) {
  final s = v?.toString() ?? '';
  if (s.isEmpty) return '—';
  return s.length >= 16 ? s.substring(0, 16).replaceFirst('T', ' ') : s;
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(trUi(message))));
}

mixin _Loader<T extends StatefulWidget> on State<T> {
  Map<String, dynamic>? data;
  bool busy = true;
  String? error;

  Future<Map<String, dynamic>> fetch();

  Future<void> load() async {
    try {
      final d = await fetch();
      if (!mounted) return;
      setState(() {
        data = d;
        error = null;
        busy = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.message;
        busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        error = 'تعذر تنفيذ العملية. تحقق من اتصالك وحاول مرة أخرى.';
        busy = false;
      });
    }
  }
}

// ================================================================ التوزيع التلقائي

class SupportAutoAssignmentScreen extends StatefulWidget {
  const SupportAutoAssignmentScreen({super.key, this.initialData});
  final Map<String, dynamic>? initialData;
  @override
  State<SupportAutoAssignmentScreen> createState() =>
      _SupportAutoAssignmentScreenState();
}

class _SupportAutoAssignmentScreenState
    extends State<SupportAutoAssignmentScreen>
    with _Loader {
  bool running = false;
  final Set<int> saving = {};

  static const _departmentLabels = {
    'general': 'عام',
    'financial': 'مالي',
    'kyc': 'التحقق والاسترداد',
    'technical': 'تقني',
  };

  @override
  Future<Map<String, dynamic>> fetch() =>
      ApiService.supportToolsJson('GET', 'assignment');

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

  Future<void> _run() async {
    setState(() => running = true);
    try {
      final r = await ApiService.supportToolsJson('POST', 'assignment/run');
      if (mounted) _toast(context, '${r['message'] ?? 'تم.'}');
      await load();
    } on ApiException catch (e) {
      if (mounted) _toast(context, e.message);
    } finally {
      if (mounted) setState(() => running = false);
    }
  }

  Future<void> _update(
    Map<String, dynamic> staff,
    Map<String, dynamic> changes,
  ) async {
    final id = _int(staff['id']);
    final before = Map<String, dynamic>.from(staff);
    setState(() {
      staff.addAll(changes);
      saving.add(id);
    });
    try {
      await ApiService.supportToolsJson(
        'PATCH',
        'assignment/staff/$id',
        body: changes,
      );
    } on ApiException catch (e) {
      if (mounted) {
        setState(
          () => staff
            ..clear()
            ..addAll(before),
        );
        _toast(context, e.message);
      }
    } finally {
      if (mounted) setState(() => saving.remove(id));
    }
  }

  Future<void> _editCapacity(Map<String, dynamic> staff) async {
    var value = _int(staff['max_open_tickets']).clamp(1, 500);
    final result = await showDialog<int>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          title: Text(trUi('الحد الأقصى للتذاكر المفتوحة')),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: value > 1 ? () => set(() => value--) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              IconButton(
                onPressed: value < 500 ? () => set(() => value++) : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d),
              child: Text(trUi('إلغاء')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(d, value),
              child: Text(trUi('حفظ')),
            ),
          ],
        ),
      ),
    );
    if (result != null && result != _int(staff['max_open_tickets'])) {
      await _update(staff, {'max_open_tickets': result});
    }
  }

  Widget _staffCard(_Look l, Map<String, dynamic> s) {
    final open = _int(s['open_tickets']);
    final max = _int(s['max_open_tickets']).clamp(1, 1 << 30);
    final ratio = (open / max).clamp(0.0, 1.0);
    final full = open >= max;
    final active = s['is_active'] == true && s['user_status'] == 'active';
    final auto = s['auto_assign_enabled'] == true;
    final id = _int(s['id']);
    final dept = '${s['department'] ?? 'general'}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: l.box(),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: l.cyan.withValues(alpha: .15),
                  child: Text(
                    ('${s['name'] ?? '?'}').trim().isEmpty
                        ? '?'
                        : ('${s['name']}').trim().substring(0, 1),
                    style: TextStyle(
                      color: l.cyan,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trUi('${s['name'] ?? ''}'),
                        style: TextStyle(
                          color: l.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${s['email'] ?? ''}',
                        style: TextStyle(color: l.muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (saving.contains(id))
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 8,
                      backgroundColor: l.soft,
                      color: full ? l.red : (ratio > .7 ? l.amber : l.green),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                InkWell(
                  onTap: () => _editCapacity(s),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Text(
                      '$open / $max',
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        color: l.text,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              trUi(
                full
                    ? 'وصل للحد الأقصى — لن تُسند له تذاكر جديدة'
                    : 'تذاكر مفتوحة / الحد الأقصى (اضغط للتعديل)',
              ),
              style: TextStyle(
                color: full ? l.red : l.muted,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _departmentLabels.containsKey(dept)
                        ? dept
                        : 'general',
                    isDense: true,
                    decoration: InputDecoration(
                      labelText: trUi('القسم'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    items: _departmentLabels.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(trUi(e.value)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null && v != dept) _update(s, {'department': v});
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: auto,
              title: Text(
                trUi('ضمن التوزيع التلقائي'),
                style: TextStyle(
                  color: l.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              onChanged: (v) => _update(s, {'auto_assign_enabled': v}),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: s['is_active'] == true,
              title: Text(
                trUi('متاح لاستلام التذاكر'),
                style: TextStyle(
                  color: l.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              subtitle: s['user_status'] == 'active'
                  ? null
                  : Text(
                      trUi('حساب الموظف غير نشط'),
                      style: TextStyle(color: l.red, fontSize: 11),
                    ),
              onChanged: (v) => _update(s, {'is_active': v}),
            ),
            if (!active || !auto)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: l.chip(
                  !active ? 'غير متاح' : 'مستثنى من التوزيع',
                  l.amber,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = _Look(context);
    final staff = _list(data?['staff']).map(_map).toList();
    final fallback = data?['fallback_employee'] is Map
        ? _map(data?['fallback_employee'])
        : null;

    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        backgroundColor: l.bg,
        appBar: l.appBar('التوزيع التلقائي', load),
        body: busy
            ? const Center(child: CircularProgressIndicator())
            : error != null
            ? l.errorView(error!, load)
            : RefreshIndicator(
                onRefresh: load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 40),
                  children: [
                    l.header(
                      icon: Icons.alt_route_rounded,
                      title: 'التوزيع التلقائي',
                      subtitle: 'توزيع التذاكر حسب القسم وسعة كل موظف، مع موظف احتياطي عند امتلاء الجميع.',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: l.stat(
                            Icons.hourglass_top_rounded,
                            'بانتظار موظف',
                            '${_int(data?['waiting_count'])}',
                            l.amber,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: l.stat(
                            Icons.groups_rounded,
                            'موظفون ضمن التوزيع',
                            '${_int(data?['eligible_count'])}',
                            l.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: l.box(radius: 16),
                      child: Row(
                        children: [
                          Icon(Icons.support_agent_rounded, color: l.blue),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              fallback == null
                                  ? trUi(
                                      'لا يوجد موظف احتياطي. التذاكر تنتظر عند امتلاء الجميع.',
                                    )
                                  : '${trUi('الموظف الاحتياطي:')} ${fallback['name'] ?? ''}',
                              style: TextStyle(
                                color: l.text,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: running || _int(data?['waiting_count']) == 0
                            ? null
                            : _run,
                        icon: running
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.bolt_rounded),
                        label: Text(trUi('توزيع التذاكر المنتظرة الآن')),
                      ),
                    ),
                    l.sectionTitle(
                      Icons.badge_outlined,
                      'موظفو الدعم',
                      l.cyan,
                      trailing: l.chip('${staff.length}', l.cyan),
                    ),
                    if (staff.isEmpty)
                      l.empty('لا يوجد موظفو دعم بملفات توزيع بعد.')
                    else
                      ...staff.map((s) => _staffCard(l, s)),
                  ],
                ),
              ),
      ),
    );
  }
}

// ================================================================ Email + WhatsApp

class SupportChannelsScreen extends StatefulWidget {
  const SupportChannelsScreen({super.key, this.initialData});
  final Map<String, dynamic>? initialData;
  @override
  State<SupportChannelsScreen> createState() => _SupportChannelsScreenState();
}

class _SupportChannelsScreenState extends State<SupportChannelsScreen>
    with _Loader {
  final Set<int> retrying = {};

  @override
  Future<Map<String, dynamic>> fetch() =>
      ApiService.supportToolsJson('GET', 'channels');

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

  Future<void> _retry(int id) async {
    setState(() => retrying.add(id));
    try {
      final r = await ApiService.supportToolsJson(
        'POST',
        'channels/inbound/$id/retry',
      );
      if (mounted) _toast(context, '${r['message'] ?? 'تم.'}');
      await load();
    } on ApiException catch (e) {
      if (mounted) _toast(context, e.message);
    } finally {
      if (mounted) setState(() => retrying.remove(id));
    }
  }

  int _sum(Object? stats) =>
      _map(stats).values.fold<int>(0, (a, b) => a + _int(b));

  Widget _status(_Look l, bool ok, String yes, String no, {String? hint}) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            size: 17,
            color: ok ? l.green : l.amber,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trUi(ok ? yes : no),
                  style: TextStyle(
                    color: l.text,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!ok && hint != null)
                  Text(
                    hint,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(color: l.muted, fontSize: 10.5),
                  ),
              ],
            ),
          ),
        ],
      );

  Widget _url(_Look l, String label, String url) => Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
    decoration: BoxDecoration(
      color: l.soft,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: l.border),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trUi(label),
                style: TextStyle(
                  color: l.muted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                url,
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  color: l.text,
                  fontSize: 11.5,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: trUi('نسخ'),
          icon: Icon(Icons.copy_rounded, size: 18, color: l.cyan),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: url));
            _toast(context, 'تم النسخ');
          },
        ),
      ],
    ),
  );

  Widget _channel(
    _Look l, {
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
    required Object? stats,
  }) {
    final s = _map(stats);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: l.box(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  trUi(title),
                  style: TextStyle(
                    color: l.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              l.chip('${trUi('آخر 30 يومًا:')} ${_sum(s)}', color),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
          if (s.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: s.entries
                  .map((e) => l.chip('${e.key}: ${e.value}', l.muted))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Color _msgColor(_Look l, String status) {
    switch (status) {
      case 'failed':
      case 'error':
        return l.red;
      case 'received':
        return l.amber;
      default:
        return l.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _Look(context);
    final email = _map(data?['email']);
    final wa = _map(data?['whatsapp']);
    final recent = _list(data?['recent']).map(_map).toList();

    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        backgroundColor: l.bg,
        appBar: l.appBar('Email + WhatsApp', load),
        body: busy
            ? const Center(child: CircularProgressIndicator())
            : error != null
            ? l.errorView(error!, load)
            : RefreshIndicator(
                onRefresh: load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 40),
                  children: [
                    l.header(
                      icon: Icons.hub_outlined,
                      title: 'قنوات الدعم الواردة',
                      subtitle: 'الرسائل الواردة من البريد وWhatsApp تتحول تلقائيًا إلى تذاكر بدون تكرار.',
                      colors: l.dark
                          ? null
                          : const [Color(0xFF047857), Color(0xFF0891B2)],
                    ),
                    _channel(
                      l,
                      icon: Icons.alternate_email_rounded,
                      title: 'البريد الوارد',
                      color: l.blue,
                      stats: email['last_30_days'],
                      children: [
                        _status(
                          l,
                          email['configured'] == true,
                          'استقبال البريد عبر Webhook مفعّل',
                          'استقبال البريد عبر Webhook غير مضبوط',
                          hint: 'SUPPORT_INBOUND_SECRET',
                        ),
                        _url(
                          l,
                          'رابط Webhook',
                          '${email['webhook_url'] ?? ''}',
                        ),
                        _url(
                          l,
                          'الهيدر المطلوب',
                          '${email['header'] ?? 'X-Support-Webhook-Secret'}',
                        ),
                      ],
                    ),
                    _channel(
                      l,
                      icon: Icons.chat_rounded,
                      title: 'WhatsApp',
                      color: l.green,
                      stats: wa['last_30_days'],
                      children: [
                        _status(
                          l,
                          wa['webhook_configured'] == true,
                          'استقبال الرسائل مفعّل',
                          'استقبال الرسائل غير مضبوط',
                          hint: 'WhatsApp App Secret / Verify Token',
                        ),
                        const SizedBox(height: 6),
                        _status(
                          l,
                          wa['sending_enabled'] == true,
                          'الرد عبر WhatsApp مفعّل',
                          'الرد عبر WhatsApp غير مضبوط',
                          hint: 'WhatsApp Access Token / Phone Number ID',
                        ),
                        _url(l, 'رابط Webhook', '${wa['webhook_url'] ?? ''}'),
                      ],
                    ),
                    l.sectionTitle(
                      Icons.inbox_rounded,
                      'آخر الرسائل الواردة',
                      l.cyan,
                      trailing: l.chip('${recent.length}', l.cyan),
                    ),
                    if (recent.isEmpty)
                      l.empty('لا توجد رسائل واردة بعد.')
                    else
                      ...recent.map((m) {
                        final id = _int(m['id']);
                        final status = '${m['status'] ?? ''}';
                        final isWa = m['channel'] == 'whatsapp';
                        final canRetry =
                            m['support_ticket_id'] == null &&
                            (status == 'failed' || status == 'error');
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: l.box(radius: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                isWa
                                    ? Icons.chat_rounded
                                    : Icons.mail_outline_rounded,
                                color: isWa ? l.green : l.blue,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      trUi(
                                        '${(m['subject'] ?? '').toString().isEmpty ? (m['from'] ?? '') : m['subject']}',
                                      ),
                                      style: TextStyle(
                                        color: l.text,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if ('${m['excerpt'] ?? ''}'.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 3),
                                        child: Text(
                                          '${m['excerpt']}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: l.muted,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ),
                                    if ('${m['error'] ?? ''}'.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 3),
                                        child: Text(
                                          trUi('${m['error']}'),
                                          style: TextStyle(
                                            color: l.red,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        l.chip(status, _msgColor(l, status)),
                                        if (m['ticket_number'] != null)
                                          l.chip(
                                            '${m['ticket_number']}',
                                            l.cyan,
                                          ),
                                        l.chip('${m['from'] ?? ''}', l.muted),
                                        l.chip(_date(m['created_at']), l.muted),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (canRetry)
                                IconButton(
                                  tooltip: trUi('إعادة المعالجة'),
                                  onPressed: retrying.contains(id)
                                      ? null
                                      : () => _retry(id),
                                  icon: retrying.contains(id)
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Icon(
                                          Icons.replay_rounded,
                                          color: l.amber,
                                        ),
                                ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
      ),
    );
  }
}

// ================================================================ فحص المرفقات

class SupportAttachmentsScreen extends StatefulWidget {
  const SupportAttachmentsScreen({super.key, this.initialData});
  final Map<String, dynamic>? initialData;
  @override
  State<SupportAttachmentsScreen> createState() =>
      _SupportAttachmentsScreenState();
}

class _SupportAttachmentsScreenState extends State<SupportAttachmentsScreen>
    with _Loader {
  String filter = '';
  final Set<int> scanning = {};

  static const _statusLabels = {
    'clean': 'سليم',
    'infected': 'غير آمن',
    'error': 'خطأ بالفحص',
    'not_available': 'بدون فحص',
    'unknown': 'غير معروف',
  };

  @override
  Future<Map<String, dynamic>> fetch() => ApiService.supportToolsJson(
    'GET',
    filter.isEmpty ? 'attachments' : 'attachments?status=$filter',
  );

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

  Color _color(_Look l, String s) {
    switch (s) {
      case 'clean':
        return l.green;
      case 'infected':
        return l.red;
      case 'error':
        return l.amber;
      default:
        return l.muted;
    }
  }

  IconData _icon(String s) {
    switch (s) {
      case 'clean':
        return Icons.verified_user_rounded;
      case 'infected':
        return Icons.gpp_bad_rounded;
      case 'error':
        return Icons.report_problem_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String _size(int bytes) {
    if (bytes <= 0) return '—';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  Future<void> _rescan(int id) async {
    setState(() => scanning.add(id));
    try {
      final r = await ApiService.supportToolsJson(
        'POST',
        'attachments/$id/rescan',
      );
      if (mounted) _toast(context, '${r['message'] ?? 'تم.'}');
      await load();
    } on ApiException catch (e) {
      if (mounted) _toast(context, e.message);
    } finally {
      if (mounted) setState(() => scanning.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _Look(context);
    final scanner = _map(data?['scanner']);
    final stats = _map(data?['stats']);
    final items = _list(data?['items']).map(_map).toList();
    final available = scanner['available'] == true;

    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        backgroundColor: l.bg,
        appBar: l.appBar('فحص المرفقات', load),
        body: busy
            ? const Center(child: CircularProgressIndicator())
            : error != null
            ? l.errorView(error!, load)
            : RefreshIndicator(
                onRefresh: load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 40),
                  children: [
                    l.header(
                      icon: Icons.shield_outlined,
                      title: 'فحص المرفقات',
                      subtitle: 'كل مرفق بالتذاكر يُفحص أمنيًا قبل حفظه. من هنا تتابع النتائج وتعيد الفحص.',
                      colors: l.dark
                          ? null
                          : const [Color(0xFF7C3AED), Color(0xFF2563EB)],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: l.box(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                available
                                    ? Icons.check_circle_rounded
                                    : Icons.error_outline_rounded,
                                color: available ? l.green : l.amber,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  trUi(
                                    available
                                        ? 'فاحص الفيروسات (ClamAV) يعمل على الخادم'
                                        : 'فاحص الفيروسات (ClamAV) غير مثبّت على الخادم',
                                  ),
                                  style: TextStyle(
                                    color: l.text,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              l.chip(
                                '${scanner['binary'] ?? 'clamscan'}',
                                l.muted,
                              ),
                              l.chip(
                                scanner['strict'] == true
                                    ? 'وضع صارم: يرفض إذا تعذر الفحص'
                                    : 'وضع مرن',
                                scanner['strict'] == true ? l.violet : l.muted,
                              ),
                              l.chip(
                                '${trUi('الحد الأقصى:')} ${scanner['max_mb'] ?? 10} MB',
                                l.blue,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${trUi('الأنواع المسموحة:')} ${_list(scanner['allowed']).join(', ')}',
                            style: TextStyle(color: l.muted, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 6),
                            child: ChoiceChip(
                              label: Text(
                                '${trUi('الكل')} (${stats.values.fold<int>(0, (a, b) => a + _int(b))})',
                              ),
                              selected: filter.isEmpty,
                              onSelected: (_) {
                                setState(() => filter = '');
                                load();
                              },
                            ),
                          ),
                          ..._statusLabels.entries.map(
                            (e) => Padding(
                              padding: const EdgeInsetsDirectional.only(end: 6),
                              child: ChoiceChip(
                                label: Text(
                                  '${trUi(e.value)} (${_int(stats[e.key])})',
                                ),
                                selected: filter == e.key,
                                onSelected: (_) {
                                  setState(() => filter = e.key);
                                  load();
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    l.sectionTitle(
                      Icons.attach_file_rounded,
                      'المرفقات',
                      l.cyan,
                      trailing: l.chip('${items.length}', l.cyan),
                    ),
                    if (items.isEmpty)
                      l.empty('لا توجد مرفقات ضمن هذا الفلتر.')
                    else
                      ...items.map((a) {
                        final id = _int(a['id']);
                        final s = '${a['scan_status'] ?? 'unknown'}';
                        final color = _color(l, s);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: l.box(radius: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: .13),
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Icon(_icon(s), color: color, size: 19),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${a['name'] ?? '—'}',
                                      style: TextStyle(
                                        color: l.text,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        l.chip(_statusLabels[s] ?? s, color),
                                        if (a['ticket_number'] != null)
                                          l.chip(
                                            '${a['ticket_number']}',
                                            l.cyan,
                                          ),
                                        l.chip(_size(_int(a['size'])), l.muted),
                                        l.chip(
                                          _date(
                                            a['scanned_at'] ?? a['created_at'],
                                          ),
                                          l.muted,
                                        ),
                                      ],
                                    ),
                                    if ('${a['signature'] ?? ''}'.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          '${a['signature']}',
                                          style: TextStyle(
                                            color: l.red,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    if ('${a['details'] ?? ''}'.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          '${a['details']}',
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: l.muted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: trUi('إعادة الفحص'),
                                onPressed: scanning.contains(id)
                                    ? null
                                    : () => _rescan(id),
                                icon: scanning.contains(id)
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(Icons.radar_rounded, color: l.cyan),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
      ),
    );
  }
}
