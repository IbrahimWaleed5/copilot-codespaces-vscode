import 'package:flutter/material.dart';
import '../i18n/localized_text.dart';
import 'package:open_filex/open_filex.dart';

import '../i18n/i18n.dart';
import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';

class AdminOfficeSubscriptionsScreen extends StatefulWidget {
  const AdminOfficeSubscriptionsScreen({super.key});

  @override
  State<AdminOfficeSubscriptionsScreen> createState() =>
      _AdminOfficeSubscriptionsScreenState();
}

class _AdminOfficeSubscriptionsScreenState
    extends State<AdminOfficeSubscriptionsScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await ApiService.fetchAdminOfficeSubscriptions();
      if (mounted) setState(() => _data = data);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذر تحميل اشتراكات المكاتب.'.tr());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _items =>
      (_data?['data'] as List? ?? const <dynamic>[])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

  Map<String, dynamic> get _stats => Map<String, dynamic>.from(
        _data?['statistics'] as Map? ?? const <String, dynamic>{},
      );

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(trUi(message)),
        backgroundColor: error ? AppColors.danger : AppColors.success,
      ),
    );
  }

  Future<void> _openReceipt(int subscriptionId) async {
    try {
      final file = await ApiService.downloadAdminOfficeSubscriptionReceipt(
        subscriptionId: subscriptionId,
      );
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        _toast(
          result.message.isEmpty
              ? 'تعذر فتح إيصال الاشتراك.'.tr()
              : result.message,
          error: true,
        );
      }
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      _toast(e.message, error: true);
    } catch (_) {
      _toast('تعذر فتح إيصال الاشتراك.'.tr(), error: true);
    }
  }

  Future<String?> _askReason() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('سبب رفض الاشتراك'.tr()),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(labelText: 'سبب الرفض'.tr()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('إلغاء'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: Text('تأكيد'.tr()),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    Future<void>.delayed(const Duration(milliseconds: 600), controller.dispose);
    return value;
  }

  Future<void> _review(Map<String, dynamic> item, bool approve) async {
    final id = int.tryParse('${item['id']}');
    if (id == null) return;

    if (!approve) {
      final reason = await _askReason();
      if (reason == null || reason.isEmpty) return;
      try {
        final message = await ApiService.reviewAdminOfficeSubscription(
          subscriptionId: id,
          decision: 'reject',
          rejectionReason: reason,
        );
        _toast(message);
        await _load();
      } on ApiException catch (e) {
        _toast(e.message, error: true);
      }
      return;
    }

    var duration = 1;
    var unit = 'month';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('اعتماد الاشتراك'.tr()),
          content: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: duration,
                  decoration: InputDecoration(labelText: 'المدة'.tr()),
                  items: List.generate(
                    12,
                    (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text('${i + 1}'),
                    ),
                  ),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => duration = value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: unit,
                  decoration: InputDecoration(labelText: 'الوحدة'.tr()),
                  items: [
                    DropdownMenuItem(value: 'day', child: Text('يوم'.tr())),
                    DropdownMenuItem(value: 'month', child: Text('شهر'.tr())),
                    DropdownMenuItem(value: 'year', child: Text('سنة'.tr())),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => unit = value);
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('إلغاء'.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text('اعتماد'.tr()),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    try {
      final message = await ApiService.reviewAdminOfficeSubscription(
        subscriptionId: id,
        decision: 'approve',
        durationValue: duration,
        durationUnit: unit,
      );
      _toast(message);
      await _load();
    } on ApiException catch (e) {
      _toast(e.message, error: true);
    }
  }

  String _statusLabel(String? status) => switch (status) {
        'under_review' => 'قيد المراجعة'.tr(),
        'active' => 'فعال'.tr(),
        'rejected' => 'مرفوض'.tr(),
        'expired' => 'منتهي'.tr(),
        _ => status ?? '—',
      };

  String _paymentMethod(String? method) => switch (method) {
        'bank_transfer' => 'تحويل بنكي'.tr(),
        'cash' => 'نقدي'.tr(),
        'wallet' => 'المحفظة'.tr(),
        'online' => 'دفع إلكتروني'.tr(),
        _ => method ?? '—',
      };

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    return Scaffold(
      appBar: AppBar(title: Text('اشتراكات المكاتب'.tr())),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, retry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _StatCard(
                            label: 'قيد المراجعة'.tr(),
                            value: stats['under_review'],
                          ),
                          _StatCard(
                            label: 'فعال'.tr(),
                            value: stats['active'],
                          ),
                          _StatCard(
                            label: 'مرفوض'.tr(),
                            value: stats['rejected'],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (_items.isEmpty)
                        _EmptyState(text: 'لا توجد اشتراكات.'.tr())
                      else
                        ..._items.map((item) {
                          final office = item['office'] as Map?;
                          final status = item['status']?.toString();
                          final pending = status == 'under_review';
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
                                          office?['name']?.toString() ??
                                              'مكتب'.tr(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      _StatusBadge(
                                        text: _statusLabel(status),
                                        color: pending
                                            ? const Color(0xFFF59E0B)
                                            : status == 'active'
                                                ? AppColors.success
                                                : AppColors.danger,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${item['amount'] ?? 0} ${item['currency'] ?? ''} • ${_paymentMethod(item['payment_method']?.toString())}',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                  if ((item['receipt_path']?.toString() ?? '')
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    TextButton.icon(
                                      onPressed: () => _openReceipt(
                                        int.parse('${item['id']}'),
                                      ),
                                      icon: const Icon(
                                        Icons.receipt_long_outlined,
                                      ),
                                      label: Text('عرض إيصال الاشتراك'.tr()),
                                    ),
                                  ],
                                  if (pending) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: FilledButton(
                                            onPressed: () => _review(item, true),
                                            child: Text('اعتماد'.tr()),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: () => _review(item, false),
                                            child: Text('رفض'.tr()),
                                          ),
                                        ),
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
                ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});
  final String label;
  final dynamic value;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 105),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${value ?? 0}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            Text(
              trUi(label),
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          trUi(text),
          style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 56),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 10),
              Text(trUi(text)),
            ],
          ),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.retry});
  final String message;
  final Future<void> Function() retry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 44),
              const SizedBox(height: 10),
              Text(trUi(message), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: retry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text('إعادة المحاولة'.tr()),
              ),
            ],
          ),
        ),
      );
}
