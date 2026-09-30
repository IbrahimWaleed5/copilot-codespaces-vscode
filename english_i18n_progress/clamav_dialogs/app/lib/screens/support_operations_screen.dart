import 'package:flutter/material.dart';

import '../i18n/localized_text.dart';
import '../services/api_service.dart';
import 'account_recovery_support_screen.dart';
import 'support_customer_search_screen.dart';
import 'support_screen.dart';
import 'support_trust_center_screen.dart';

class SupportOperationsScreen extends StatefulWidget {
  final String initialSection;

  const SupportOperationsScreen({
    super.key,
    this.initialSection = 'dashboard',
  });

  @override
  State<SupportOperationsScreen> createState() =>
      _SupportOperationsScreenState();
}

class _SupportOperationsScreenState extends State<SupportOperationsScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await ApiService.fetchSupportOperationsDashboard();
      if (mounted) {
        setState(() => _data = data);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Map<String, dynamic> _map(Object? value) {
    return Map<String, dynamic>.from(value as Map? ?? const {});
  }

  List<dynamic> _list(Object? value) {
    return List<dynamic>.from(value as List? ?? const []);
  }

  Set<String> get _permissions =>
      _list(_data?['permissions']).map((item) => item.toString()).toSet();

  bool _can(String permission) => _permissions.contains(permission);

  String get _sectionTitle {
    return switch (widget.initialSection) {
      'security' => 'الأمان والجلسات'.tr(),
      'templates' => 'قوالب الدعم'.tr(),
      'refunds' => 'طلبات الاسترداد المالي'.tr(),
      'audit' => 'سجل التدقيق'.tr(),
      _ => 'مركز عمليات الدعم'.tr(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        backgroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF060B18) : Theme.of(context).scaffoldBackgroundColor),
        appBar: AppBar(
          backgroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0B132B) : Theme.of(context).scaffoldBackgroundColor),
          title: Text(trUi(_sectionTitle)),
          actions: [
            IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _errorView()
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _sectionBody(),
                  ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? 'حدث خطأ'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const TrText('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionBody() {
    return switch (widget.initialSection) {
      'security' => _securitySection(),
      'templates' => _templatesSection(),
      'refunds' => _refundsSection(),
      'audit' => _auditSection(),
      _ => _dashboardSection(),
    };
  }

  Widget _dashboardSection() {
    final stats = _map(_data?['stats']);
    final approvals = _list(_data?['approvals']);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Text(
          trUi(_data?['support_level_label']?.toString() ?? 'Support'),
          style: TextStyle(
            color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF67E8F9) : Color(0xFF0E7490)),
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 4 : 2,
          childAspectRatio: 1.45,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: [
            _stat(
              'مفتوحة',
              stats['open_tickets'],
              Icons.support_agent_rounded,
            ),
            _stat(
              'عاجلة',
              stats['urgent_tickets'],
              Icons.priority_high_rounded,
            ),
            _stat(
              'SLA متأخرة',
              stats['overdue_tickets'],
              Icons.timer_off_outlined,
            ),
            _stat(
              'بانتظار العميل',
              stats['waiting_customer'],
              Icons.hourglass_bottom_rounded,
            ),
            _stat(
              'KYC/استرداد',
              stats['pending_recoveries'],
              Icons.verified_user_outlined,
            ),
            _stat(
              'اعتمادات',
              stats['pending_approvals'],
              Icons.approval_outlined,
            ),
            _stat(
              'استردادات مالية',
              stats['pending_refunds'],
              Icons.currency_exchange_rounded,
            ),
            _stat(
              'متوسط أول رد',
              '${stats['avg_first_response_minutes'] ?? 0} د',
              Icons.speed_rounded,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _card(
          'وصول سريع',
          [
            _menuTile(
              Icons.support_agent_rounded,
              'تذاكر الدعم',
              () => _open(const SupportScreen()),
            ),
            _menuTile(
              Icons.person_search_rounded,
              'البحث والحسابات والبريد',
              () => _open(const SupportCustomerSearchScreen()),
            ),
            if (_can('support.recovery.review'))
              _menuTile(
                Icons.manage_accounts_rounded,
                'استرداد الحساب و KYC',
                () => _open(const AccountRecoverySupportScreen()),
              ),
            if (_can('support.security.view'))
              _menuTile(
                Icons.shield_outlined,
                'الأمان والجلسات',
                () => _open(const SupportOperationsScreen(initialSection: 'security')),
              ),
            if (_can('support.templates.use'))
              _menuTile(
                Icons.mark_email_read_outlined,
                'قوالب الدعم',
                () => _open(const SupportOperationsScreen(initialSection: 'templates')),
              ),
            if (_can('support.payments.request_refund') ||
                _can('support.payments.approve_refund'))
              _menuTile(
                Icons.currency_exchange_rounded,
                'طلبات الاسترداد المالي',
                () => _open(const SupportOperationsScreen(initialSection: 'refunds')),
              ),
            if (_can('support.audit.view'))
              _menuTile(
                Icons.fact_check_outlined,
                'سجل التدقيق',
                () => _open(const SupportOperationsScreen(initialSection: 'audit')),
              ),
            if (_can('support.reports.view'))
              _menuTile(
                Icons.shield_outlined,
                'مركز الثقة والتشغيل',
                () => _open(const SupportTrustCenterScreen()),
              ),
          ],
        ),
        if (_can('support.approvals.review')) ...[
          const SizedBox(height: 14),
          _approvalCard(approvals),
        ],
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _securitySection() {
    final stats = _map(_data?['stats']);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _hero(
          Icons.shield_outlined,
          'مركز الأمان والاسترداد',
          'افتح ملف العميل لرؤية مؤشر Risk، محاولات الدخول، الأجهزة والجلسات النشطة، الحسابات المرتبطة وآخر تغييرات الحساب.',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _stat(
                'KYC/استرداد',
                stats['pending_recoveries'],
                Icons.verified_user_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _stat(
                'اعتمادات حساسة',
                stats['pending_approvals'],
                Icons.approval_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _card(
          'أدوات الأمان',
          [
            _menuTile(
              Icons.person_search_rounded,
              'بحث عن حساب وفحص الأمان',
              () => _open(const SupportCustomerSearchScreen()),
            ),
            _menuTile(
              Icons.manage_accounts_rounded,
              'طلبات استرداد الحساب و KYC',
              () => _open(const AccountRecoverySupportScreen()),
            ),
          ],
        ),
        const SizedBox(height: 18),
        TrText('لا يعرض النظام كلمة المرور الحالية أو OTP أو Recovery Codes أو أسرار 2FA/Passkeys لموظف الدعم.',
          style: TextStyle(
            color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurfaceVariant),
            fontSize: 11,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _templatesSection() {
    final templates = _list(_data?['templates']);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _hero(
          Icons.mark_email_read_outlined,
          'قوالب الدعم',
          'ردود جاهزة للمواقف المتكررة. يمكن استخدامها في التذاكر والبريد حسب صلاحيات الموظف.',
        ),
        const SizedBox(height: 12),
        if (templates.isEmpty)
          _empty('لا توجد قوالب مفعّلة حاليًا.')
        else
          ...templates.map((raw) {
            final item = _map(raw);
            final body = item['body'] ?? item['message'] ?? item['content'];
            return Container(
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.all(14),
              decoration: _boxDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title']?.toString() ?? 'قالب دعم'.tr(),
                    style: TextStyle(
                      color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (item['category'] != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      trUi(item['category'].toString()),
                      style: TextStyle(
                        color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF67E8F9) : Color(0xFF0E7490)),
                        fontSize: 10,
                      ),
                    ),
                  ],
                  const SizedBox(height: 7),
                  Text(
                    trUi(body?.toString() ?? '—'),
                    style: TextStyle(
                      color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFCBD5E1) : Theme.of(context).colorScheme.onSurfaceVariant),
                      fontSize: 12,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _refundsSection() {
    final refunds = _list(_data?['refunds']);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _hero(
          Icons.currency_exchange_rounded,
          'طلبات الاسترداد المالي',
          'L1 يشاهد المدفوعات، L2 يرفع طلب Refund، والاعتماد النهائي داخل الدعم متاح فقط للصلاحية المخولة قبل التنفيذ المالي.',
        ),
        const SizedBox(height: 12),
        if (refunds.isEmpty)
          _empty('لا توجد طلبات استرداد معلقة.')
        else
          ...refunds.map((raw) {
            final item = _map(raw);
            final customer = _map(item['customer']);
            return Container(
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.all(14),
              decoration: _boxDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trUi(item['reference_number']?.toString() ??
                        'Refund #${item['id'] ?? '—'}'),
                    style: TextStyle(
                      color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF93C5FD) : Color(0xFF1D4ED8)),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    trUi('${customer['name'] ?? customer['email'] ?? '—'} · '
                    '${item['amount'] ?? 0} ${item['currency'] ?? ''}'),
                    style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFCBD5E1) : Theme.of(context).colorScheme.onSurfaceVariant)),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    trUi(item['reason']?.toString() ?? '—'),
                    style: TextStyle(
                      color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurfaceVariant),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _auditSection() {
    final logs = _list(_data?['recent_audit']);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _hero(
          Icons.fact_check_outlined,
          'سجل تدقيق الدعم',
          'يعرض العمليات الحساسة المسجلة: الموظف، الإجراء، الوصف، عنوان IP والوقت.',
        ),
        const SizedBox(height: 12),
        if (!_can('support.audit.view'))
          _empty('لا تملك صلاحية عرض سجل التدقيق.')
        else if (logs.isEmpty)
          _empty('لا توجد عمليات دعم مسجلة حديثًا.')
        else
          ...logs.map((raw) {
            final item = _map(raw);
            final user = _map(item['user']);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(13),
              decoration: _boxDecoration(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.history_rounded,
                    color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF60A5FA) : Color(0xFF1D4ED8)),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trUi(item['action']?.toString() ?? '—'),
                          style: TextStyle(
                            color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          trUi(item['description']?.toString() ?? '—'),
                          style: TextStyle(
                            color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFCBD5E1) : Theme.of(context).colorScheme.onSurfaceVariant),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          trUi('${user['name'] ?? 'System'} · '
                          '${item['ip_address'] ?? '—'} · '
                          '${item['created_at'] ?? '—'}'),
                          style: TextStyle(
                            color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF64748B) : Theme.of(context).colorScheme.onSurfaceVariant),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _approvalCard(List<dynamic> approvals) {
    return _card(
      'اعتمادات الإجراءات الحساسة',
      approvals.isEmpty
          ? [const TrText('لا توجد طلبات معلقة.')]
          : approvals.map((raw) {
              final item = _map(raw);
              final requester = _map(item['requester']);
              final target = _map(item['target_user']);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0B132B) : Theme.of(context).colorScheme.surface),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trUi('${item['action_type'] ?? '—'} · '
                      '${target['email'] ?? target['name'] ?? '—'}'),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    TrText('طلبه ${requester['name'] ?? '—'} · '
                      'Risk ${item['risk_level'] ?? '—'}',
                      style: TextStyle(
                        color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurfaceVariant),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(trUi(item['reason']?.toString() ?? '—')),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: () => _review(item, 'approve'),
                            child: const TrText('اعتماد'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _review(item, 'reject'),
                            child: const TrText('رفض'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
    );
  }

  Future<void> _review(
    Map<String, dynamic> item,
    String decision,
  ) async {
    final controller = TextEditingController();
    final notes = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            trUi(decision == 'approve' ? 'اعتماد الإجراء' : 'رفض الإجراء'),
          ),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'ملاحظة المراجعة'.tr(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const TrText('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                controller.text,
              ),
              child: const TrText('حفظ'),
            ),
          ],
        );
      },
    );
    Future<void>.delayed(const Duration(milliseconds: 600), controller.dispose);

    if ((notes ?? '').trim().length < 5) {
      return;
    }

    try {
      final message = await ApiService.reviewSupportApproval(
        int.parse(item['id'].toString()),
        decision: decision,
        notes: notes!.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(trUi(message))),
        );
      }
      await _load();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(trUi(error.message))),
        );
      }
    }
  }

  void _open(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Widget _hero(
    IconData icon,
    String title,
    String description,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF111C38) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2B4568) : const Color(0xFFD9E4F2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0x222563EB),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trUi(title),
                  style: TextStyle(
                    color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  trUi(description),
                  style: TextStyle(
                    color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurfaceVariant),
                    fontSize: 11,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(
    String title,
    Object? value,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8)), size: 20),
          const SizedBox(height: 7),
          Text(
            '${value ?? 0}',
            style: TextStyle(
              color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            trUi(title),
            style: TextStyle(
              color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurfaceVariant),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(
    String title,
    List<Widget> children,
  ) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            trUi(title),
            style: TextStyle(
              color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface),
              fontWeight: FontWeight.w900,
            ),
          ),
          Divider(color: Theme.of(context).dividerColor),
          ...children,
        ],
      ),
    );
  }

  Widget _menuTile(
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8))),
      title: Text(
        trUi(title),
        style: TextStyle(
          color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFCBD5E1) : Theme.of(context).colorScheme.onSurfaceVariant),
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing: Icon(
        Icons.chevron_left_rounded,
        color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF64748B) : Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      onTap: onTap,
    );
  }

  Widget _empty(String message) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _boxDecoration(),
      child: Center(
        child: Text(
          trUi(message),
          textAlign: TextAlign.center,
          style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      ),
    );
  }

  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF111C38) : const Color(0xFFFFFFFF),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2B4568) : const Color(0xFFD9E4F2)),
    );
  }
}
