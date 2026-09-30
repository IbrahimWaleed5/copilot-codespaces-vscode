import 'package:flutter/material.dart';

import '../i18n/localized_text.dart';
import '../services/api_service.dart';
import '../services/app_feedback.dart';
import 'dispute_center_screen.dart';

class FinancialControlCenterScreen extends StatefulWidget {
  const FinancialControlCenterScreen({super.key});

  @override
  State<FinancialControlCenterScreen> createState() => _FinancialControlCenterScreenState();
}

class _FinancialControlCenterScreenState extends State<FinancialControlCenterScreen> {
  bool _loading = true;
  Map<String, dynamic> _data = <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final data = await ApiService.fetchFinancialControl();
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

  int _id(dynamic v) => int.tryParse('$v') ?? 0;

  Future<void> _completeRefund(Map<String, dynamic> refund) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        title: TrText('تأكيد ${refund['reference_number'] ?? 'الاسترداد'.tr()}'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: 'مرجع تحويل الاسترداد للعميل'.tr()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dc, false), child: const TrText('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dc, true), child: const TrText('تأكيد')), 
        ],
      ),
    );
    if (ok == true && controller.text.trim().isNotEmpty) {
      try {
        await ApiService.completeRefund(_id(refund['id']), controller.text.trim());
        AppFeedback.success('تم تأكيد الاسترداد وإعادة احتساب المستحق.'.tr());
        await _load();
      } on ApiException catch (e) {
        AppFeedback.error(e.message);
      }
    }
    Future<void>.delayed(const Duration(milliseconds: 600), controller.dispose);
  }

  Future<void> _rejectRefund(Map<String, dynamic> refund) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        title: const TrText('رفض طلب الاسترداد'),
        content: TextField(controller: controller, maxLines: 3, decoration: InputDecoration(labelText: 'سبب الرفض'.tr())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dc, false), child: const TrText('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dc, true), child: const TrText('رفض')),
        ],
      ),
    );
    if (ok == true && controller.text.trim().length >= 5) {
      try {
        await ApiService.rejectRefund(_id(refund['id']), controller.text.trim());
        AppFeedback.success('تم رفض الاسترداد وإرجاع النزاع للمراجعة.'.tr());
        await _load();
      } on ApiException catch (e) {
        AppFeedback.error(e.message);
      }
    }
    Future<void>.delayed(const Duration(milliseconds: 600), controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final stats = _data['stats'] is Map ? Map<String, dynamic>.from(_data['stats'] as Map) : <String, dynamic>{};
    final ledger = _maps(_data['ledger']);
    final disputes = _maps(_data['disputes']);
    final refunds = _maps(_data['refunds']);
    final payouts = _maps(_data['payouts']);

    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: const TrText('مركز الرقابة المالية'),
          actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded))],
        ),
        body: _loading && _data.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.45,
                      children: [
                        _stat('إجمالي التحصيل', stats['gross_collected'], Icons.account_balance_wallet_outlined),
                        _stat('صافي التحصيل', stats['net_collected'], Icons.savings_outlined),
                        _stat('إيراد الاشتراكات', stats['subscription_revenue'], Icons.workspace_premium_outlined),
                        _stat('عمولات الخدمات', stats['platform_commission'], Icons.percent_rounded),
                        _stat('إيراد المنصة', stats['platform_revenue'], Icons.trending_up_rounded),
                        _stat('تم صرفه', stats['paid_payouts'], Icons.outbox_outlined),
                        _stat('تم استرداده', stats['completed_refunds'], Icons.replay_rounded),
                        _stat('مستحقات محجوزة', stats['held_payouts'], Icons.lock_clock_outlined),
                        _stat('Escrow محتجز', stats['escrow_held'], Icons.shield_outlined),
                        _stat('نزاعات مفتوحة', stats['open_disputes'], Icons.gavel_outlined, money: false),
                        _stat('استردادات معلقة', stats['refunds_pending'], Icons.pending_actions_outlined, money: false),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _title('السجل المالي الموحد'),
                    const TrText('الاستشارات والمشاريع والباقات والاستردادات والصرف في خط زمني واحد.'),
                    const SizedBox(height: 8),
                    if (ledger.isEmpty) const Card(child: ListTile(title: TrText('لا توجد حركات مالية حتى الآن.'))),
                    ...ledger.take(30).map((row) {
                      final type = row['type']?.toString() ?? '';
                      final negative = type == 'refund' || type == 'payout';
                      final icon = switch (type) {
                        'consultation_payment' => Icons.support_agent_outlined,
                        'project_payment' => Icons.engineering_outlined,
                        'subscription_payment' => Icons.workspace_premium_outlined,
                        'refund' => Icons.replay_rounded,
                        'payout' => Icons.outbox_outlined,
                        _ => Icons.receipt_long_outlined,
                      };
                      return Card(
                        child: ListTile(
                          leading: Icon(icon),
                          title: Text(row['title']?.toString() ?? row['reference']?.toString() ?? 'حركة مالية'.tr()),
                          subtitle: Text("${row['reference'] ?? ''}\n${row['status'] ?? ''} — ${row['occurred_at'] ?? ''}"),
                          isThreeLine: true,
                          trailing: Text(
                            '${negative ? '' : '+'}${row['net_amount'] ?? 0} ${row['currency'] ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 22),
                    _title('نزاعات تحتاج متابعة'),
                    if (disputes.isEmpty) const Card(child: ListTile(title: TrText('لا توجد نزاعات مفتوحة.'))),
                    ...disputes.map((d) => Card(
                          child: ListTile(
                            onTap: () async {
                              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DisputeDetailScreen(disputeId: _id(d['id']))));
                              await _load();
                            },
                            leading: const Icon(Icons.gavel_outlined),
                            title: Text(d['reference_number']?.toString() ?? 'نزاع'.tr()),
                            subtitle: Text('${d['title'] ?? ''}\n${d['status'] ?? ''}'),
                            isThreeLine: true,
                            trailing: const Icon(Icons.chevron_left_rounded),
                          ),
                        )),
                    const SizedBox(height: 22),
                    _title('استردادات تحتاج تنفيذ'),
                    if (refunds.isEmpty) const Card(child: ListTile(title: TrText('لا توجد استردادات معلقة.'))),
                    ...refunds.map((r) {
                      final customer = r['customer'] is Map ? Map<String, dynamic>.from(r['customer'] as Map) : <String, dynamic>{};
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r['reference_number']?.toString() ?? 'استرداد'.tr(), style: const TextStyle(fontWeight: FontWeight.w900)),
                              Text('${customer['name'] ?? ''} — ${r['amount'] ?? 0} ${r['currency'] ?? ''}'),
                              TrText('الحالة: ${r['status'] ?? ''}'),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilledButton.icon(onPressed: () => _completeRefund(r), icon: const Icon(Icons.check_circle_outline), label: const TrText('تأكيد الاسترداد')),
                                  OutlinedButton.icon(onPressed: () => _rejectRefund(r), icon: const Icon(Icons.close_rounded), label: const TrText('رفض')),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 22),
                    _title('أحدث عمليات الصرف'),
                    if (payouts.isEmpty) const Card(child: ListTile(title: TrText('لا توجد عمليات صرف.'))),
                    ...payouts.take(10).map((p) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.payments_outlined),
                            title: Text(p['reference']?.toString() ?? 'عملية صرف'.tr()),
                            subtitle: Text('${p['gateway'] ?? ''} — ${p['net_amount'] ?? 0} ${p['currency'] ?? ''} — ${p['status'] ?? ''}'),
                          ),
                        )),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _title(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(trUi(text), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      );

  Widget _stat(String title, dynamic value, IconData icon, {bool money = true}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon),
            const SizedBox(height: 8),
            Text(trUi(title), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text('${value ?? 0}${money ? ' ₪' : ''}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          ],
        ),
      ),
    );
  }
}
