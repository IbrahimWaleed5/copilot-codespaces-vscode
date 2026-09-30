import 'package:flutter/material.dart';
import '../i18n/localized_text.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';

class EngineerEarningsScreen extends StatefulWidget {
  const EngineerEarningsScreen({super.key});

  @override
  State<EngineerEarningsScreen> createState() => _EngineerEarningsScreenState();
}

class _EngineerEarningsScreenState extends State<EngineerEarningsScreen> {
  final _search = TextEditingController();
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _status;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.fetchEngineerEarnings(
        search: _search.text,
        status: _status,
      );
      if (mounted) setState(() => _data = data);
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editPercentage(Map<String, dynamic> item) async {
    final controller = TextEditingController(
      text: item['engineer_percentage']?.toString() ?? '',
    );
    final value = await showDialog<double>(
      context: context,
      builder: (context) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: AlertDialog(
          title: const TrText('نسبة المهندس'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'النسبة %'.tr()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const TrText('إلغاء')),
            FilledButton(
              onPressed: () => Navigator.pop(context, double.tryParse(controller.text)),
              child: const TrText('حفظ'),
            ),
          ],
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 600), controller.dispose);
    if (value == null) return;

    try {
      final message = await ApiService.updateEngineerEarningPercentage(
        int.parse(item['id'].toString()),
        value,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    }
  }

  Future<void> _requestBankPayout(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: AlertDialog(
          title: const TrText('تحويل المستحق إلى البنك'),
          content: const TrText('سيتم إرسال المستحق إلى الحساب البنكي الموثّق للمهندس. لن تعتبر العملية مدفوعة إلا بعد تأكيد البنك. متابعة؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const TrText('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const TrText('إرسال التحويل')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    try {
      final message = await ApiService.markEngineerEarningPaid(
        int.parse(item['id'].toString()),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().user?.role ?? '';
    final isAdmin = role == 'admin';
    final summary = Map<String, dynamic>.from(
      _data?['summary'] as Map? ?? const <String, dynamic>{},
    );
    final items = List<dynamic>.from(_data?['data'] as List? ?? const []);

    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        appBar: AppBar(title: const TrText('مستحقات المهندسين')),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      decoration: InputDecoration(
                        hintText: 'بحث باسم المهندس أو رقم الاستشارة'.tr(),
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onSubmitted: (_) => _load(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String?>(
                    icon: const Icon(Icons.filter_alt_outlined),
                    onSelected: (value) {
                      setState(() => _status = value);
                      _load();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: null, child: TrText('الكل')),
                      PopupMenuItem(value: 'pending', child: TrText('جاهز للصرف')),
                      PopupMenuItem(value: 'processing', child: TrText('قيد التحويل البنكي')),
                      PopupMenuItem(value: 'paid', child: TrText('مدفوع')),
                      PopupMenuItem(value: 'cancelled', child: TrText('ملغي')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Center(child: Text(trUi(_error!)))
              else ...[
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _stat('الإجمالي', summary['gross']),
                    _stat('مستحق المهندسين', summary['engineer_due']),
                    _stat('المدفوع', summary['paid_to_engineers']),
                    _stat('جاهز للصرف', summary['pending_to_engineers']),
                    _stat('قيد التحويل', summary['processing_to_engineers']),
                    _stat('حصة المنصة', summary['platform_share']),
                  ],
                ),
                const SizedBox(height: 20),
                if (items.isEmpty)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(30),
                    child: TrText('لا توجد مستحقات مطابقة.'),
                  ))
                else
                  ...items.map((raw) {
                    final item = Map<String, dynamic>.from(raw as Map);
                    final engineer = item['engineer'] is Map
                        ? Map<String, dynamic>.from(item['engineer'] as Map)
                        : const <String, dynamic>{};
                    final consultation = item['consultation'] is Map
                        ? Map<String, dynamic>.from(item['consultation'] as Map)
                        : const <String, dynamic>{};
                    final status = item['status']?.toString() ?? '';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    engineer['name']?.toString() ?? 'مهندس'.tr(),
                                    style: const TextStyle(fontWeight: FontWeight.w900),
                                  ),
                                ),
                                _badge(status),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${consultation['consultation_number'] ?? ''} • ${consultation['title'] ?? ''}',
                              style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant)),
                            ),
                            const SizedBox(height: 10),
                            TrText('قيمة الدفع: ${item['payment_amount'] ?? 0} ₪'),
                            TrText('نسبة المهندس: ${item['engineer_percentage'] ?? 0}%'),
                            TrText('مستحق المهندس: ${item['engineer_amount'] ?? 0} ₪'),
                            TrText('حصة المنصة: ${item['platform_amount'] ?? 0} ₪'),
                            if (item['payout_reference']?.toString().isNotEmpty == true) ...[
                              const SizedBox(height: 7),
                              TrText('مرجع التحويل: ${item['payout_reference']}',
                                style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 10),
                              ),
                            ],
                            if (item['payout_failure_reason']?.toString().trim().isNotEmpty == true) ...[
                              const SizedBox(height: 7),
                              TrText('تعذر التحويل: ${item['payout_failure_reason']}',
                                style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 10, height: 1.5),
                              ),
                            ],
                            if (status == 'pending') ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _editPercentage(item),
                                      child: const TrText('تعديل النسبة'),
                                    ),
                                  ),
                                  if (isAdmin) ...[
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: () => _requestBankPayout(item),
                                        icon: const Icon(Icons.account_balance_rounded, size: 18),
                                        label: const TrText('تحويل بنكي'),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String title, dynamic value) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF0D1B31) : Theme.of(context).colorScheme.surface),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? Color(0x1AFFFFFF) : Theme.of(context).dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(trUi(title), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 12)),
          const SizedBox(height: 6),
          Text('${value ?? 0} ₪', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _badge(String status) {
    final label = switch (status) {
      'paid' => 'مدفوع'.tr(),
      'pending' => 'جاهز للصرف'.tr(),
      'processing' => 'قيد التحويل البنكي'.tr(),
      'cancelled' => 'ملغي'.tr(),
      _ => status,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.dark ? Color(0x0DFFFFFF) : Theme.of(context).colorScheme.surface),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(trUi(label), style: const TextStyle(fontSize: 11)),
    );
  }
}
