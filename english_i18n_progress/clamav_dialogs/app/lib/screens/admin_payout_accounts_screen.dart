import 'package:flutter/material.dart';

import '../i18n/localized_text.dart';
import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';

class AdminPayoutAccountsScreen extends StatefulWidget {
  const AdminPayoutAccountsScreen({super.key});

  @override
  State<AdminPayoutAccountsScreen> createState() =>
      _AdminPayoutAccountsScreenState();
}

class _AdminPayoutAccountsScreenState
    extends State<AdminPayoutAccountsScreen> {
  bool _loading = true;
  String? _error;
  String _filter = 'pending';
  List<dynamic> _items = const [];
  final Set<int> _busy = <int>{};

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
      final items = await ApiService.fetchAdminPayoutAccounts();
      if (mounted) setState(() => _items = items);
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify(Map<String, dynamic> account) async {
    final id = int.tryParse(account['id']?.toString() ?? '');
    if (id == null) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: AlertDialog(
          title: const TrText('توثيق الحساب البنكي'),
          content: const TrText('هل راجعت بيانات المستفيد وتريد اعتماد هذا الحساب لاستلام التحويلات؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const TrText('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const TrText('توثيق الحساب'),
            ),
          ],
        ),
      ),
    );
    if (approved != true) return;

    setState(() => _busy.add(id));
    try {
      final message = await ApiService.verifyAdminPayoutAccount(id);
      AppFeedback.success(message);
      await _load();
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _reject(Map<String, dynamic> account) async {
    final id = int.tryParse(account['id']?.toString() ?? '');
    if (id == null) return;
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: AlertDialog(
          title: const TrText('رفض الحساب البنكي'),
          content: TextField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: 'سبب الرفض'.tr(),
              hintText: 'مثال: اسم المستفيد لا يطابق بيانات البنك.'.tr(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const TrText('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isNotEmpty) Navigator.pop(context, value);
              },
              child: const TrText('رفض'),
            ),
          ],
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 600), controller.dispose);
    if (reason == null || reason.isEmpty) return;

    setState(() => _busy.add(id));
    try {
      final message = await ApiService.rejectAdminPayoutAccount(id, reason);
      AppFeedback.success(message);
      await _load();
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _items.where((raw) {
      final item = Map<String, dynamic>.from(raw as Map);
      final status = item['verification_status']?.toString() ?? 'pending';
      return _filter == 'all' || status == _filter;
    }).toList();

    final pendingCount = _items.where((raw) {
      final item = Map<String, dynamic>.from(raw as Map);
      return (item['verification_status']?.toString() ?? 'pending') == 'pending';
    }).length;

    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        appBar: AppBar(title: const TrText('الحسابات البنكية للمستفيدين')),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: Theme.of(context).brightness == Brightness.dark
                        ? const [Color(0xFF12325A), Color(0xFF071426)]
                        : const [Color(0xFFE5F0FF), Color(0xFFFFFFFF)],
                  ),
                  border: Border.all(color: const Color(0x334EA8FF)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: const Color(0x222563EB),
                      child: Icon(
                        Icons.account_balance_rounded,
                        color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const TrText('مراجعة حسابات صرف المستحقات',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TrText('$pendingCount حساب بانتظار المراجعة',
                            style: TextStyle(
                              color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _filterChip('pending', 'قيد المراجعة'),
                  _filterChip('verified', 'موثّق'),
                  _filterChip('rejected', 'مرفوض'),
                  _filterChip('all', 'الكل'),
                ],
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Center(child: Text(trUi(_error!)))
              else if (filtered.isEmpty)
                const _EmptyAccounts()
              else
                ...filtered.map((raw) {
                  final item = Map<String, dynamic>.from(raw as Map);
                  return _accountCard(item);
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    return ChoiceChip(
      selected: _filter == value,
      label: Text(trUi(label)),
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  Widget _accountCard(Map<String, dynamic> item) {
    final id = int.tryParse(item['id']?.toString() ?? '') ?? 0;
    final status = item['verification_status']?.toString() ?? 'pending';
    final beneficiary = item['beneficiary'] is Map
        ? Map<String, dynamic>.from(item['beneficiary'] as Map)
        : const <String, dynamic>{};
    final isEngineer = item['beneficiary_type']?.toString() == 'engineer';
    final statusColor = switch (status) {
      'verified' => const Color(0xFF22C55E),
      'rejected' => const Color(0xFFEF4444),
      _ => const Color(0xFFF59E0B),
    };
    final statusLabel = switch (status) {
      'verified' => 'موثّق'.tr(),
      'rejected' => 'مرفوض'.tr(),
      _ => 'قيد المراجعة'.tr(),
    };
    final busy = _busy.contains(id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF0D1B31) : Theme.of(context).colorScheme.surface),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? Color(0x1AFFFFFF) : Theme.of(context).dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0x221D4ED8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isEngineer ? Icons.engineering_rounded : Icons.apartment_rounded,
                  color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      beneficiary['name']?.toString() ??
                          item['beneficiary_name']?.toString() ??
                          'مستفيد'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      trUi(isEngineer ? 'مهندس' : 'مكتب هندسي'),
                      style: TextStyle(
                        color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  trUi(statusLabel),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _detail('البنك', item['bank_name']),
          _detail('الفرع', item['branch_name']),
          _detail(
            'رقم الحساب',
            item['masked_account_number'] ?? item['account_number_masked'],
          ),
          _detail('IBAN', item['masked_iban'] ?? item['iban_masked']),
          _detail('SWIFT', item['swift_code']),
          _detail('العملة', item['currency']),
          if ((item['rejection_reason']?.toString().trim().isNotEmpty ?? false)) ...[
            const SizedBox(height: 8),
            TrText('سبب الرفض: ${item['rejection_reason']}',
              style: const TextStyle(
                color: Color(0xFFFCA5A5),
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
              children: [
                if (status != 'verified')
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy ? null : () => _verify(item),
                      icon: const Icon(Icons.verified_rounded),
                      label: const TrText('توثيق'),
                    ),
                  ),
                if (status != 'verified') const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : () => _reject(item),
                    icon: const Icon(Icons.close_rounded),
                    label: const TrText('رفض'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFCA5A5),
                      side: const BorderSide(color: Color(0x55EF4444)),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _detail(String title, dynamic value) {
    final text = value?.toString().trim() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              trUi(title),
              style: TextStyle(
                color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant),
                fontSize: 10,
              ),
            ),
          ),
          Expanded(
            child: Text(
              trUi(text.isEmpty ? '—' : text),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAccounts extends StatelessWidget {
  const _EmptyAccounts();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF0D1B31) : Theme.of(context).colorScheme.surface),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? Color(0x1AFFFFFF) : Theme.of(context).dividerColor)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 44,
            color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          SizedBox(height: 10),
          TrText('لا توجد حسابات في هذا التصنيف.'),
        ],
      ),
    );
  }
}
