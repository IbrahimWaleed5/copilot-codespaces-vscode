import 'package:flutter/material.dart';

import '../i18n/localized_text.dart';
import '../i18n/i18n.dart';
import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';

class OfficeFinanceScreen extends StatefulWidget {
  final bool adminMode;
  const OfficeFinanceScreen({super.key, this.adminMode = false});

  @override
  State<OfficeFinanceScreen> createState() => _OfficeFinanceScreenState();
}

class _OfficeFinanceScreenState extends State<OfficeFinanceScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  int _tab = 0;

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = widget.adminMode ? await ApiService.fetchAdminOfficeFinance() : await ApiService.fetchOfficeFinance();
      if (mounted) setState(() => _data = d);
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() { super.initState(); _load(); }

  double _n(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
  String _money(dynamic v) => _n(v).toStringAsFixed(2);

  Future<double?> _askPercentage(String title, double current) async {
    final c = TextEditingController(text: current.toStringAsFixed(2));
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(trUi(title)),
        content: TextField(controller: c, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'النسبة %'.tr())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء'.tr())),
          FilledButton(onPressed: () => Navigator.pop(context, double.tryParse(c.text.trim())), child: Text('حفظ'.tr())),
        ],
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 600), c.dispose);
    return value;
  }

  Future<void> _run(Future<String> Function() fn) async {
    try {
      final msg = await fn();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(msg))));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    }
  }

  Widget _metric(String title, dynamic value, IconData icon) => Container(
    constraints: const BoxConstraints(minHeight: 118),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    decoration: BoxDecoration(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF0D1B31) : AppColors.surface), borderRadius: BorderRadius.circular(18), border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? Color(0x1AFFFFFF) : AppColors.borderSoft))),
    child: Row(children: [
      CircleAvatar(backgroundColor: AppColors.blue500_10, child: Icon(icon, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan))),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title.tr(), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : AppColors.textSecondary), fontSize: 12, height: 1.35)),
        const SizedBox(height: 4),
        FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(trUi(_money(value)), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900))),
      ])),
    ]),
  );

  Widget _summary() {
    final s = Map<String, dynamic>.from(_data?['summary'] as Map? ?? const {});
    final items = widget.adminMode
        ? [
            ['إجمالي الاستشارات', s['consultation_gross'], Icons.forum_outlined],
            ['مستحق المكاتب', s['consultation_office_due'], Icons.apartment_outlined],
            ['المدفوع للمكاتب', s['consultation_office_paid'], Icons.payments_outlined],
            ['مستحق المهندسين', s['consultation_engineer_due'], Icons.engineering_outlined],
            ['إجمالي المشاريع', s['project_gross'], Icons.architecture_outlined],
            ['مستحق مشاريع مدفوع', s['project_office_paid'], Icons.account_balance_wallet_outlined],
            ['مستحق مشاريع معلق', s['project_office_pending'], Icons.pending_actions_outlined],
          ]
        : [
            ['إجمالي الاستشارات', s['consultation_gross'], Icons.forum_outlined],
            ['إجمالي المشاريع', s['project_gross'], Icons.architecture_outlined],
            ['إجمالي حصة المكتب', s['office_total_due'], Icons.apartment_outlined],
            ['المستلم للمكتب', s['office_received'], Icons.payments_outlined],
            ['المتبقي للمكتب', s['office_remaining'], Icons.hourglass_bottom_rounded],
            ['مستحق المهندسين', s['engineers_due'], Icons.engineering_outlined],
            ['المدفوع للمهندسين', s['engineers_paid'], Icons.price_check_outlined],
            ['صافي المكتب', s['office_net'], Icons.savings_outlined],
          ];
    return GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisExtent: 124, crossAxisSpacing: 10, mainAxisSpacing: 10),
      itemBuilder: (_, i) => _metric(items[i][0] as String, items[i][1], items[i][2] as IconData),
    );
  }

  Widget _consultations() {
    final list = List<dynamic>.from(_data?['consultations'] as List? ?? const []);
    final canSet = _data?['can_set_percentages'] == true;
    if (list.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(30), child: Text('لا توجد استشارات مالية.'.tr())));
    return Column(children: list.map((raw) {
      final x = Map<String, dynamic>.from(raw as Map);
      final financial = x['financial'] is Map ? Map<String, dynamic>.from(x['financial'] as Map) : <String, dynamic>{};
      final earnings = List<dynamic>.from(x['engineer_earnings'] as List? ?? const []);
      final percentage = widget.adminMode ? _n(financial['office_percentage']) : _n(x['office_percentage']);
      return Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${x['number'] ?? ''} · ${x['title'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('${'المكتب'.tr()}: ${x['office'] ?? _data?['office']?['name'] ?? '-'} · ${'العميل'.tr()}: ${x['customer'] ?? '-'}'.tr(), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
          Text('${'القيمة'.tr()}: ${_money(widget.adminMode ? x['final_price'] : x['gross'])} · ${'نسبة المكتب'.tr()}: ${percentage.toStringAsFixed(2)}%'.tr()),
          if (widget.adminMode && financial.isNotEmpty)
            Text('${'حصة المكتب'.tr()}: ${_money(financial['office_amount'])} · ${'الحالة'.tr()}: ${financial['status'] ?? '-'}'.tr()),
          if (!widget.adminMode)
            Text('${'حصة المكتب'.tr()}: ${_money(x['office_amount'])} · ${'الحالة'.tr()}: ${x['status'] ?? '-'}'.tr()),
          if (earnings.isNotEmpty) ...[
            const Divider(),
            Text('مستحقات المهندسين'.tr(), style: TextStyle(fontWeight: FontWeight.w800)),
            ...earnings.map((eRaw) {
              final e = Map<String, dynamic>.from(eRaw as Map);
              return ListTile(
                dense: true, contentPadding: EdgeInsets.zero,
                title: Text('${e['engineer'] ?? '-'} · ${_money(e['amount'])}'),
                subtitle: Text('${_n(e['percentage']).toStringAsFixed(2)}% · ${e['status'] ?? '-'}'),
                trailing: !widget.adminMode && e['status'] != 'paid' && e['id'] != null
                    ? TextButton(onPressed: () => _run(() => ApiService.markOfficeConsultationEngineerPaid(int.parse(e['id'].toString()))), child: Text('تسجيل دفع'.tr()))
                    : null,
              );
            }),
          ],
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (widget.adminMode && canSet)
              OutlinedButton.icon(
                onPressed: () async {
                  final v = await _askPercentage('نسبة المكتب من الاستشارة'.tr(), percentage);
                  if (v != null) _run(() => ApiService.setAdminOfficeConsultationPercentage(consultationId: int.parse(x['id'].toString()), percentage: v));
                },
                icon: const Icon(Icons.percent), label: Text('نسبة المكتب'.tr()),
              ),
            if (widget.adminMode && financial.isNotEmpty && financial['status'] != 'paid' && financial['id'] != null)
              FilledButton.tonalIcon(onPressed: () => _run(() => ApiService.markAdminConsultationOfficePaid(int.parse(financial['id'].toString()))), icon: const Icon(Icons.price_check), label: Text('دفع حصة المكتب'.tr())),
            if (!widget.adminMode && x['consultation_id'] != null && (x['engineer']?.toString() ?? '').isNotEmpty)
              OutlinedButton.icon(
                onPressed: () async {
                  final current = earnings.isNotEmpty ? _n((earnings.first as Map)['percentage']) : 0.0;
                  final v = await _askPercentage('نسبة المهندس من حصة المكتب'.tr(), current);
                  if (v != null) _run(() => ApiService.setOfficeConsultationEngineerPercentage(consultationId: int.parse(x['consultation_id'].toString()), percentage: v));
                },
                icon: const Icon(Icons.engineering), label: Text('نسبة المهندس'.tr()),
              ),
          ]),
        ])),
      );
    }).toList());
  }

  Widget _projects() {
    final list = List<dynamic>.from(_data?['projects'] as List? ?? const []);
    final canSet = _data?['can_set_percentages'] == true;
    if (list.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(30), child: Text('لا توجد مشاريع مالية.'.tr())));
    return Column(children: list.map((raw) {
      final x = Map<String, dynamic>.from(raw as Map);
      final earnings = List<dynamic>.from(x['office_earnings'] as List? ?? const []);
      return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${x['project_number'] ?? ''} · ${x['title'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('${'المكتب'.tr()}: ${x['office'] ?? _data?['office']?['name'] ?? '-'} · ${'العميل'.tr()}: ${x['customer'] ?? '-'}'.tr(), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
        Text('${'قيمة المشروع'.tr()}: ${_money(x['agreed_price'])} · ${'نسبة المكتب'.tr()}: ${_n(x['office_percentage']).toStringAsFixed(2)}%'.tr()),
        Text('${'الأقساط المدفوعة'.tr()}: ${_money(x['paid_installments'])} · ${'الحالة'.tr()}: ${x['status'] ?? '-'}'.tr()),
        if (earnings.isNotEmpty) ...[
          const Divider(),
          ...earnings.map((eRaw) {
            final e = Map<String, dynamic>.from(eRaw as Map);
            return Text('${'حصة مكتب'.tr()}: ${_money(e['office_amount'])} ${'من دفعة'.tr()} ${_money(e['payment_amount'])} · ${e['status'] ?? '-'}'.tr());
          }),
        ],
        if (widget.adminMode && canSet) ...[
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight, child: OutlinedButton.icon(
            onPressed: () async {
              final v = await _askPercentage('نسبة المكتب من المشروع'.tr(), _n(x['office_percentage']));
              if (v != null) _run(() => ApiService.setAdminOfficeProjectPercentage(projectId: int.parse(x['id'].toString()), percentage: v));
            }, icon: const Icon(Icons.percent), label: Text('تعديل نسبة المكتب'.tr()),
          )),
        ],
      ])));
    }).toList());
  }

  Widget _engineerEarnings() {
    final consultation = List<dynamic>.from(_data?['consultation_engineer_earnings'] as List? ?? const []);
    final projects = List<dynamic>.from(_data?['project_engineer_earnings'] as List? ?? const []);
    final List<Map<String, dynamic>> all = [
      ...consultation.map((e) => <String, dynamic>{'kind': 'consultation', 'data': e}),
      ...projects.map((e) => <String, dynamic>{'kind': 'project', 'data': e}),
    ];
    if (all.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(30), child: Text('لا توجد مستحقات مهندسين.'.tr())));
    return Column(children: all.map((row) {
      final kind = row['kind'] as String;
      final x = Map<String, dynamic>.from(row['data'] as Map);
      final title = kind == 'consultation' ? (x['consultation']?['title'] ?? '-') : (x['project']?['title'] ?? '-');
      return Card(child: ListTile(
        title: Text('${x['engineer']?['name'] ?? '-'} · $title'),
        subtitle: Text('${_money(x['amount'])} · ${x['status'] ?? '-'}'),
        trailing: x['status'] != 'paid' && x['id'] != null ? TextButton(
          onPressed: () => _run(() => kind == 'consultation'
              ? ApiService.markOfficeConsultationEngineerPaid(int.parse(x['id'].toString()))
              : ApiService.markOfficeProjectEngineerPaid(int.parse(x['id'].toString()))),
          child: Text('دفع'.tr()),
        ) : null,
      ));
    }).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        appBar: AppBar(title: Text((widget.adminMode ? 'مالية المكاتب' : 'مالية المكتب').tr()), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(trUi(_error!))))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(padding: const EdgeInsets.all(14), children: [
                      if (!widget.adminMode && _data?['office'] is Map)
                        Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(trUi(_data!['office']['name']?.toString() ?? ''), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
                      _summary(),
                      const SizedBox(height: 18),
                      SegmentedButton<int>(
                        segments: [
                          ButtonSegment(value: 0, icon: const Icon(Icons.forum_outlined), label: Text('الاستشارات'.tr())),
                          ButtonSegment(value: 1, icon: const Icon(Icons.architecture_outlined), label: Text('المشاريع'.tr())),
                          if (!widget.adminMode) ButtonSegment(value: 2, icon: const Icon(Icons.engineering_outlined), label: Text('المهندسون'.tr())),
                        ],
                        selected: {_tab},
                        onSelectionChanged: (s) => setState(() => _tab = s.first),
                      ),
                      const SizedBox(height: 14),
                      if (_tab == 0) _consultations() else if (_tab == 1) _projects() else _engineerEarnings(),
                    ]),
                  ),
      ),
    );
  }
}
