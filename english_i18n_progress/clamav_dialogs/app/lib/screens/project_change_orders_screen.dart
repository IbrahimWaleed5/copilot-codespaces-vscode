import 'package:flutter/material.dart';

import '../i18n/localized_text.dart';
import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';

class ProjectChangeOrdersScreen extends StatefulWidget {
  final int projectId;
  final String projectTitle;

  const ProjectChangeOrdersScreen({
    super.key,
    required this.projectId,
    required this.projectTitle,
  });

  @override
  State<ProjectChangeOrdersScreen> createState() => _ProjectChangeOrdersScreenState();
}

class _ProjectChangeOrdersScreenState extends State<ProjectChangeOrdersScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.fetchProjectChangeOrders(widget.projectId);
      if (mounted) setState(() => _data = data);
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _statusLabel(String? status) {
    const labels = {
      'pending_customer': 'بانتظار العميل',
      'approved': 'معتمد',
      'rejected': 'مرفوض',
    };
    return labels[status] ?? status ?? '-';
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.danger;
      default:
        return Colors.orangeAccent;
    }
  }

  Future<void> _create() async {
    final title = TextEditingController();
    final reason = TextEditingController();
    final scope = TextEditingController();
    final price = TextEditingController(text: '0');
    final days = TextEditingController(text: '0');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: AlertDialog(
          title: const TrText('أمر تغيير جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: title, decoration: InputDecoration(labelText: 'العنوان'.tr())),
                const SizedBox(height: 10),
                TextField(controller: reason, minLines: 3, maxLines: 6, decoration: InputDecoration(labelText: 'سبب التغيير'.tr())),
                const SizedBox(height: 10),
                TextField(controller: scope, minLines: 2, maxLines: 5, decoration: InputDecoration(labelText: 'تغيير نطاق العمل - اختياري'.tr())),
                const SizedBox(height: 10),
                TextField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: InputDecoration(labelText: 'فرق السعر (+/-)'.tr())),
                const SizedBox(height: 10),
                TextField(controller: days, keyboardType: const TextInputType.numberWithOptions(signed: true), decoration: InputDecoration(labelText: 'فرق المدة بالأيام (+/-)'.tr())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const TrText('إلغاء')),
            ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const TrText('إرسال للعميل')),
          ],
        ),
      ),
    );

    final titleText = title.text.trim();
    final reasonText = reason.text.trim();
    final scopeText = scope.text.trim();
    final priceValue = double.tryParse(price.text.trim());
    final daysValue = int.tryParse(days.text.trim());
    Future<void>.delayed(const Duration(milliseconds: 600), title.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), reason.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), scope.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), price.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), days.dispose);

    if (confirmed != true || titleText.isEmpty || reasonText.length < 10 || priceValue == null || daysValue == null) return;

    setState(() => _saving = true);
    try {
      final message = await ApiService.createProjectChangeOrder(
        projectId: widget.projectId,
        title: titleText,
        reason: reasonText,
        priceDelta: priceValue,
        durationDaysDelta: daysValue,
        scopeChange: scopeText.isEmpty ? null : scopeText,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _review(Map<String, dynamic> order, bool approve) async {
    String? reason;
    if (!approve) {
      final controller = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => Directionality(
          textDirection: AppLanguage.instance.textDirection,
          child: AlertDialog(
            title: const TrText('رفض أمر التغيير'),
            content: TextField(controller: controller, minLines: 3, maxLines: 6, decoration: InputDecoration(labelText: 'سبب الرفض'.tr())),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const TrText('إلغاء')),
              ElevatedButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const TrText('رفض')),
            ],
          ),
        ),
      );
      Future<void>.delayed(const Duration(milliseconds: 600), controller.dispose);
      if (reason == null || reason.length < 5) return;
    }

    setState(() => _saving = true);
    try {
      final message = await ApiService.reviewProjectChangeOrder(
        projectId: widget.projectId,
        changeOrderId: order['id'] as int,
        approve: approve,
        rejectionReason: reason,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        appBar: AppBar(title: TrText('أوامر التغيير — ${widget.projectTitle}')),
        floatingActionButton: _data?['can_create'] == true
            ? FloatingActionButton.extended(
                onPressed: _saving ? null : _create,
                icon: const Icon(Icons.add_rounded),
                label: const TrText('أمر تغيير'),
              )
            : null,
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: ElevatedButton(onPressed: _load, child: Text(trUi(_error!))));

    final data = _data ?? const <String, dynamic>{};
    final orders = (data['change_orders'] as List? ?? const []);
    final canReview = data['can_review'] == true;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        children: [
          if (orders.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(18), child: TrText('لا توجد أوامر تغيير بعد.')))
          else
            ...orders.map((raw) {
              final order = raw as Map<String, dynamic>;
              final status = order['status']?.toString();
              final color = _statusColor(status);
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(trUi(order['change_order_number']?.toString() ?? 'CO'), style: TextStyle(fontSize: 12, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
                                const SizedBox(height: 4),
                                Text(trUi(order['title']?.toString() ?? ''), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(999)),
                            child: Text(trUi(_statusLabel(status)), style: TextStyle(fontSize: 11, color: color)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(trUi(order['reason']?.toString() ?? ''), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), height: 1.5)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 14,
                        runSpacing: 8,
                        children: [
                          TrText('فرق السعر: ${order['price_delta'] ?? 0} ₪'),
                          TrText('فرق المدة: ${order['duration_days_delta'] ?? 0} يوم'),
                          TrText('السعر الجديد: ${order['new_project_price'] ?? '-'} ₪'),
                          TrText('المدة الجديدة: ${order['new_duration_days'] ?? '-'} يوم'),
                        ],
                      ),
                      if (canReview && status == 'pending_customer') ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(child: ElevatedButton(onPressed: _saving ? null : () => _review(order, true), child: const TrText('اعتماد'))),
                            const SizedBox(width: 8),
                            Expanded(child: OutlinedButton(onPressed: _saving ? null : () => _review(order, false), child: const TrText('رفض'))),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
