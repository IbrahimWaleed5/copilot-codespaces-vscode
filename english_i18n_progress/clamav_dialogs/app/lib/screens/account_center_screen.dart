import 'package:flutter/material.dart';
import '../i18n/localized_text.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'account_delete_screen.dart';
import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';

class AccountCenterScreen extends StatefulWidget {
  const AccountCenterScreen({super.key});

  @override
  State<AccountCenterScreen> createState() => _AccountCenterScreenState();
}

class _AccountCenterScreenState extends State<AccountCenterScreen> {
  Map<String, dynamic>? _security;
  Map<String, dynamic>? _status;
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
      final results = await Future.wait([
        ApiService.fetchSecurityStatus(),
        ApiService.fetchAccountStatus(),
      ]);
      if (!mounted) return;
      setState(() {
        _security = results[0];
        _status = results[1];
      });
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _askPassword(String title) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: AlertDialog(
          title: Text(trUi(title)),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: InputDecoration(hintText: 'كلمة المرور الحالية'.tr()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const TrText('إلغاء')),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const TrText('متابعة'),
            ),
          ],
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 600), controller.dispose);
    return value;
  }

  Future<void> _enable2fa() async {
    final password = await _askPassword('تفعيل التحقق بخطوتين');
    if (password == null || password.isEmpty) return;
    try {
      final message = await ApiService.enableEmailTwoFactor(password);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
      await _confirm2fa();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    }
  }

  Future<void> _confirm2fa() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: AlertDialog(
          title: const TrText('رمز التحقق'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(hintText: '000000', counterText: ''),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const TrText('لاحقًا')),
            FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const TrText('تأكيد')),
          ],
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 600), controller.dispose);
    if (code == null || code.length != 6) return;
    try {
      final message = await ApiService.confirmEmailTwoFactor(code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
      await context.read<AuthProvider>().refreshCurrentUser();
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    }
  }

  Future<void> _disable2fa() async {
    final password = await _askPassword('تعطيل التحقق بخطوتين');
    if (password == null || password.isEmpty) return;
    try {
      final message = await ApiService.disableEmailTwoFactor(password);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
      await context.read<AuthProvider>().refreshCurrentUser();
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    }
  }

  Future<void> _deleteAccount() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AccountDeleteScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        appBar: AppBar(title: const TrText('الأمان وحالة الحساب')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(trUi(_error!)))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _card(
                          icon: Icons.shield_outlined,
                          title: 'التحقق بخطوتين عبر البريد'.tr(),
                          subtitle: _security?['email_two_factor_enabled'] == true
                              ? 'مفعّل على الحساب'
                              : 'غير مفعّل',
                          trailing: FilledButton(
                            onPressed: _security?['email_two_factor_enabled'] == true ? _disable2fa : _enable2fa,
                            child: Text(trUi(_security?['email_two_factor_enabled'] == true ? 'تعطيل' : 'تفعيل')),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _card(
                          icon: Icons.verified_user_outlined,
                          title: 'حالة الحساب'.tr(),
                          subtitle: '${_status?['status_label'] ?? '-'} • التحذيرات ${_status?['warnings_count'] ?? 0}/${_status?['warning_limit'] ?? 3}',
                        ),
                        const SizedBox(height: 14),
                        _card(
                          icon: Icons.report_problem_outlined,
                          title: 'سجل الحماية'.tr(),
                          subtitle: 'إجمالي التحذيرات: ${_status?['.tr()total_warnings'] ?? 0}\nالمخالفات المرفوضة: ${_status?['rejected_violations'] ?? 0}\nالمتبقي قبل الحد: ${_status?['warnings_remaining'] ?? 0}',
                        ),
                        if ((_status?['suspension_reason']?.toString().isNotEmpty ?? false)) ...[
                          const SizedBox(height: 14),
                          _card(
                            icon: Icons.info_outline,
                            title: 'سبب التعليق'.tr(),
                            subtitle: _status!['suspension_reason'].toString(),
                          ),
                        ],
                        const SizedBox(height: 24),
                        OutlinedButton.icon(
                          onPressed: _deleteAccount,
                          icon: const Icon(Icons.delete_forever_outlined, color: AppColors.danger),
                          label: const TrText('حذف الحساب نهائيًا', style: TextStyle(color: AppColors.danger)),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _card({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF0D1B31) : Theme.of(context).colorScheme.surface),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? Color(0x1AFFFFFF) : Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Icon(icon, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(trUi(title), style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text(trUi(subtitle), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), height: 1.6)),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing],
        ],
      ),
    );
  }
}
