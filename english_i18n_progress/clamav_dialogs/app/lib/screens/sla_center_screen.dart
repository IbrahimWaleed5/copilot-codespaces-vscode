import 'package:flutter/material.dart';
import '../i18n/localized_text.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';

class SlaCenterScreen extends StatefulWidget {
  const SlaCenterScreen({super.key});

  @override
  State<SlaCenterScreen> createState() => _SlaCenterScreenState();
}

class _SlaCenterScreenState extends State<SlaCenterScreen> {
  bool _loading = true;
  Map<String, dynamic> _data = <String, dynamic>{};
  String _status = 'active';
  String _category = '';
  String _priority = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final data = await ApiService.fetchSlaCenter(
        status: _status,
        category: _category.isEmpty ? null : _category,
        priority: _priority.isEmpty ? null : _priority,
      );
      if (mounted) setState(() => _data = data);
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _maps(dynamic raw) => (raw as List? ?? const <dynamic>[])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  Map<String, dynamic> _map(dynamic raw) => raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

  String _statusLabel(String value) => switch (value) {
        'open' => 'ضمن الوقت'.tr(),
        'overdue' => 'متأخر'.tr(),
        'escalated' => 'مصعّد'.tr(),
        'resolved' => 'مغلق تلقائيًا'.tr(),
        _ => value,
      };

  String _categoryLabel(String value) => switch (value) {
        'payments' => 'دفعات العملاء'.tr(),
        'projects' => 'تنفيذ المشاريع'.tr(),
        'disputes' => 'النزاعات'.tr(),
        'financial' => 'العمليات المالية'.tr(),
        'handover' => 'التسليم والاعتماد'.tr(),
        _ => value,
      };

  String _priorityLabel(String value) => switch (value) {
        'critical' => 'حرج'.tr(),
        'high' => 'مرتفع'.tr(),
        _ => 'عادي'.tr(),
      };

  Color _statusColor(String value) => switch (value) {
        'escalated' => (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFB7185) : const Color(0xFFBE123C)),
        'overdue' => (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFBBF24) : const Color(0xFF92400E)),
        'resolved' => (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF34D399) : const Color(0xFF047857)),
        _ => (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF22D3EE) : const Color(0xFF0E7490)),
      };

  Future<void> _acknowledge(Map<String, dynamic> item) async {
    final id = int.tryParse('${item['id']}') ?? 0;
    if (id <= 0) return;
    try {
      await ApiService.acknowledgeSlaItem(id);
      AppFeedback.success('تم تسجيل الاطلاع على الإجراء.'.tr());
      await _load();
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
    }
  }

  Future<void> _openSource(String? raw) async {
    final path = raw?.trim() ?? '';
    if (path.isEmpty) return;
    final url = path.startsWith('http://') || path.startsWith('https://')
        ? path
        : '${ApiService.siteBaseUrl}${path.startsWith('/') ? path : '/$path'}';
    final uri = Uri.tryParse(url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      AppFeedback.error('تعذر فتح المصدر.'.tr());
    }
  }

  Future<void> _editRule(Map<String, dynamic> rule) async {
    final warning = TextEditingController(text: '${rule['warning_minutes'] ?? 0}');
    final due = TextEditingController(text: rule['due_minutes'] == null ? '' : '${rule['due_minutes']}');
    final escalation = TextEditingController(text: '${rule['escalation_minutes'] ?? 0}');
    var active = rule['is_active'] == true;
    var notifyOwner = rule['notify_owner'] == true;
    var notifyAdmin = rule['notify_admin'] == true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(rule['name']?.toString() ?? 'قاعدة SLA'.tr()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: warning, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'التنبيه قبل الموعد — دقيقة'.tr())),
                const SizedBox(height: 10),
                TextField(controller: due, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'مدة الاستحقاق — دقيقة (اتركها فارغة لموعد المصدر)'.tr())),
                const SizedBox(height: 10),
                TextField(controller: escalation, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'التصعيد بعد التأخير — دقيقة'.tr())),
                SwitchListTile(value: active, onChanged: (v) => setLocal(() => active = v), title: const TrText('القاعدة مفعلة')),
                SwitchListTile(value: notifyOwner, onChanged: (v) => setLocal(() => notifyOwner = v), title: const TrText('إشعار المسؤول')),
                SwitchListTile(value: notifyAdmin, onChanged: (v) => setLocal(() => notifyAdmin = v), title: const TrText('تصعيد للإدارة')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const TrText('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const TrText('حفظ')),
          ],
        ),
      ),
    );

    if (saved == true) {
      final id = int.tryParse('${rule['id']}') ?? 0;
      final warningMinutes = int.tryParse(warning.text.trim());
      final escalationMinutes = int.tryParse(escalation.text.trim());
      final dueMinutes = due.text.trim().isEmpty ? null : int.tryParse(due.text.trim());
      if (id <= 0 || warningMinutes == null || escalationMinutes == null || (due.text.trim().isNotEmpty && dueMinutes == null)) {
        AppFeedback.error('تحقق من قيم الدقائق المدخلة.'.tr());
      } else {
        try {
          await ApiService.updateSlaRule(
            id,
            warningMinutes: warningMinutes,
            dueMinutes: dueMinutes,
            escalationMinutes: escalationMinutes,
            notifyOwner: notifyOwner,
            notifyAdmin: notifyAdmin,
            isActive: active,
          );
          AppFeedback.success('تم تحديث قاعدة SLA.'.tr());
          await _load();
        } on ApiException catch (e) {
          AppFeedback.error(e.message);
        }
      }
    }

    Future<void>.delayed(const Duration(milliseconds: 600), warning.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), due.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), escalation.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final stats = _map(_data['stats']);
    final items = _maps(_data['items']);
    final rules = _maps(_data['rules']);
    final categories = ( _data['categories'] as List? ?? const <dynamic>[]).map((e) => e.toString()).toList();

    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        backgroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF050B16) : Theme.of(context).scaffoldBackgroundColor),
        appBar: AppBar(
          title: const TrText('مركز المتابعة و SLA'),
          actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded))],
        ),
        body: _loading && _data.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [(Theme.of(context).brightness == Brightness.dark ? Color(0xFF10213E) : Color(0xFFFFFFFF)), (Theme.of(context).brightness == Brightness.dark ? Color(0xFF0A1427) : Color(0xFFFFFFFF))]),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0x334FC3F7)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SaaS Phase 6 • SLA Automation', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF67E8F9) : Color(0xFF0E7490)), fontWeight: FontWeight.w900, fontSize: 11)),
                          SizedBox(height: 6),
                          TrText('محرك المواعيد والتصعيد', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                          SizedBox(height: 4),
                          TrText('يجمع الإجراءات الحرجة ويصعّد المتأخر تلقائيًا، بينما يُغلق الإجراء فقط عند إكمال العملية الأصلية.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.8,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      children: [
                        _metric('نشطة الآن', stats['active'], Icons.bolt_rounded),
                        _metric('مستحقة اليوم', stats['due_today'], Icons.event_rounded),
                        _metric('متأخرة', stats['overdue'], Icons.timer_off_outlined),
                        _metric('مصعّدة', stats['escalated'], Icons.crisis_alert_rounded),
                        _metric('تم الاطلاع', stats['acknowledged'], Icons.visibility_outlined),
                        _metric('أغلقت خلال 7 أيام', stats['resolved_7d'], Icons.task_alt_rounded),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        DropdownButton<String>(
                          value: _status,
                          items: const [
                            DropdownMenuItem(value: 'active', child: TrText('النشطة')),
                            DropdownMenuItem(value: 'open', child: TrText('ضمن الوقت')),
                            DropdownMenuItem(value: 'overdue', child: TrText('المتأخرة')),
                            DropdownMenuItem(value: 'escalated', child: TrText('المصعّدة')),
                            DropdownMenuItem(value: 'resolved', child: TrText('المغلقة')),
                          ],
                          onChanged: (v) async { if (v != null) { setState(() => _status = v); await _load(); } },
                        ),
                        DropdownButton<String>(
                          value: _category,
                          items: [const DropdownMenuItem(value: '', child: TrText('كل الأقسام')), ...categories.map((v) => DropdownMenuItem(value: v, child: Text(trUi(_categoryLabel(v)))))],
                          onChanged: (v) async { if (v != null) { setState(() => _category = v); await _load(); } },
                        ),
                        DropdownButton<String>(
                          value: _priority,
                          items: const [
                            DropdownMenuItem(value: '', child: TrText('كل الأولويات')),
                            DropdownMenuItem(value: 'normal', child: TrText('عادي')),
                            DropdownMenuItem(value: 'high', child: TrText('مرتفع')),
                            DropdownMenuItem(value: 'critical', child: TrText('حرج')),
                          ],
                          onChanged: (v) async { if (v != null) { setState(() => _priority = v); await _load(); } },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (items.isEmpty)
                      const Card(child: ListTile(title: TrText('لا توجد إجراءات مطابقة للفلاتر الحالية.'))),
                    ...items.map((item) => _itemCard(item)),
                    if (rules.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      const TrText('قواعد SLA — إدارة المنصة', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                      const SizedBox(height: 8),
                      ...rules.map((rule) => Card(
                            child: ListTile(
                              leading: Icon(rule['is_active'] == true ? Icons.toggle_on_rounded : Icons.toggle_off_rounded),
                              title: Text(rule['name']?.toString() ?? 'قاعدة'.tr()),
                              subtitle: Text('${rule['rule_key'] ?? ''}\nتنبيه: ${rule['warning_minutes'] ?? 0} د • استحقاق: ${rule['due_minutes'] ?? 'من المصدر'.tr()} • تصعيد: ${rule['escalation_minutes'] ?? 0} د'.tr()),
                              isThreeLine: true,
                              trailing: const Icon(Icons.edit_outlined),
                              onTap: () => _editRule(rule),
                            ),
                          )),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _metric(String title, dynamic value, IconData icon) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0E1A30) : const Color(0xFFFFFFFF)), borderRadius: BorderRadius.circular(16), border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? const Color(0x22FFFFFF) : AppColors.borderSoft)),
        child: Row(
          children: [
            Icon(icon, color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF67E8F9) : const Color(0xFF0E7490)), size: 20),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(trUi(title), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10)), Text('${value ?? 0}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))])),
          ],
        ),
      );

  Widget _itemCard(Map<String, dynamic> item) {
    final owner = _map(item['owner']);
    final project = _map(item['project']);
    final status = item['status']?.toString() ?? 'open';
    final priority = item['priority']?.toString() ?? 'normal';
    final acknowledged = item['acknowledged_at'] != null;
    final color = _statusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(item['title']?.toString() ?? 'إجراء'.tr(), style: const TextStyle(fontWeight: FontWeight.w900))),
                Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withValues(alpha: .35))), child: Text(trUi(_statusLabel(status)), style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 10))),
              ],
            ),
            const SizedBox(height: 5),
            Text(trUi(item['reference_number']?.toString() ?? ''), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF67E8F9) : Color(0xFF0E7490)), fontWeight: FontWeight.w800, fontSize: 11)),
            if ((item['description']?.toString() ?? '').isNotEmpty) ...[const SizedBox(height: 4), Text(trUi(item['description'].toString()), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11))],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 5,
              children: [
                _pill(_categoryLabel(item['category']?.toString() ?? '')),
                _pill('الأولوية: ${_priorityLabel(priority)}'),
                if (project.isNotEmpty) _pill(project['project_number']?.toString() ?? 'مشروع'.tr()),
                if (owner.isNotEmpty) _pill(owner['name']?.toString() ?? 'مسؤول'.tr()),
                if (item['due_at'] != null) _pill('الموعد: ${item['due_at']}'),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if ((item['source_url']?.toString() ?? '').isNotEmpty)
                  FilledButton.icon(onPressed: () => _openSource(item['source_url']?.toString()), icon: const Icon(Icons.open_in_new_rounded, size: 16), label: const TrText('فتح المصدر')),
                if (status != 'resolved' && !acknowledged)
                  OutlinedButton.icon(onPressed: () => _acknowledge(item), icon: const Icon(Icons.visibility_outlined, size: 16), label: const TrText('تم الاطلاع')),
                if (acknowledged) const Chip(label: TrText('تم تسجيل الاطلاع')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF13213A) : const Color(0xFFFFFFFF)), borderRadius: BorderRadius.circular(8), border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? const Color(0x22FFFFFF) : AppColors.borderSoft)),
        child: Text(trUi(text), style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}
