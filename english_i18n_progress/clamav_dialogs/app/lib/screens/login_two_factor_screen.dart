import 'package:flutter/material.dart';
import '../i18n/localized_text.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'email_verification_screen.dart';
import 'login_account_recovery_screen.dart';
import 'login_screen.dart';

class LoginTwoFactorScreen extends StatefulWidget {
  const LoginTwoFactorScreen({super.key});

  @override
  State<LoginTwoFactorScreen> createState() => _LoginTwoFactorScreenState();
}

class _LoginTwoFactorScreenState extends State<LoginTwoFactorScreen> {
  final _codeController = TextEditingController();
  bool _resending = false;
  bool _loadingMethods = true;
  Map<String, dynamic> _methods = const {};
  String? _localError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMethods());
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadMethods() async {
    final challenge = context.read<AuthProvider>().twoFactorChallenge;
    if (challenge == null) {
      if (mounted) setState(() => _loadingMethods = false);
      return;
    }
    try {
      final data = await ApiService.fetchLoginAlternativeMethods(challenge);
      if (!mounted) return;
      setState(() {
        _methods = Map<String, dynamic>.from(data['methods'] as Map? ?? const {});
        _loadingMethods = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMethods = false);
    }
  }

  Future<void> _finish(Map<String, dynamic> result) async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.acceptExternalLoginResult(result);
    if (!mounted || !ok) return;
    final destination = auth.needsEmailVerification
        ? const EmailVerificationScreen()
        : const DashboardScreen();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => destination), (_) => false,
    );
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _localError = 'أدخل رمز التحقق المكون من 6 أرقام.'.tr());
      return;
    }
    final auth = context.read<AuthProvider>();
    final ok = await auth.verifyLoginTwoFactor(code);
    if (!mounted || !ok) return;
    final destination = auth.needsEmailVerification
        ? const EmailVerificationScreen()
        : const DashboardScreen();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => destination), (_) => false,
    );
  }

  Future<void> _verifyAuthenticator() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const TrText('رمز تطبيق المصادقة'),
        content: TextField(
          controller: controller,
          maxLength: 6,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(hintText: '000000', counterText: ''),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const TrText('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const TrText('تحقق')),
        ],
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 600), controller.dispose);
    if (code == null || code.isEmpty || !mounted) return;
    final challenge = context.read<AuthProvider>().twoFactorChallenge;
    if (challenge == null) return;
    try {
      final result = await ApiService.completeLoginAuthenticator(challengeToken: challenge, code: code);
      AppFeedback.success(result['message']?.toString() ?? 'تم التحقق وتسجيل الدخول بنجاح.'.tr());
      if (mounted) await _finish(result);
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (mounted) setState(() => _localError = e.message);
    }
  }

  Future<void> _verifyRecoveryCode() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const TrText('رمز الاسترداد'),
        content: TextField(controller: controller, autofocus: true, decoration: InputDecoration(hintText: 'أدخل رمز الاسترداد غير المستخدم'.tr())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const TrText('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const TrText('استخدام الرمز')),
        ],
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 600), controller.dispose);
    if (code == null || code.isEmpty || !mounted) return;
    final challenge = context.read<AuthProvider>().twoFactorChallenge;
    if (challenge == null) return;
    try {
      final result = await ApiService.completeLoginRecoveryCode(challengeToken: challenge, recoveryCode: code);
      AppFeedback.success(result['message']?.toString() ?? 'تم التحقق وتسجيل الدخول بنجاح.'.tr());
      if (mounted) await _finish(result);
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (mounted) setState(() => _localError = e.message);
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      final message = await context.read<AuthProvider>().resendLoginTwoFactor();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (mounted) setState(() => _localError = e.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _backToLogin() {
    context.read<AuthProvider>().cancelTwoFactorChallenge();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final challenge = auth.twoFactorChallenge;
    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: _backToLogin), title: const TrText('التحقق بخطوتين')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF0D1B31) : Theme.of(context).colorScheme.surface), borderRadius: BorderRadius.circular(24), border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? Color(0x1AFFFFFF) : Theme.of(context).dividerColor))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Icon(Icons.verified_user_outlined, size: 54, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan)),
                  const SizedBox(height: 16),
                  const TrText('أكمل التحقق من الهوية', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  TrText('يمكنك استخدام الرمز المرسل إلى ${auth.twoFactorEmailHint ?? 'بريدك الإلكتروني'} أو إحدى وسائل الأمان البديلة.', textAlign: TextAlign.center, style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), height: 1.6)),
                  const SizedBox(height: 22),
                  TextField(controller: _codeController, keyboardType: TextInputType.number, textAlign: TextAlign.center, maxLength: 6, decoration: InputDecoration(labelText: 'رمز البريد الإلكتروني'.tr(), hintText: '000000', counterText: ''), onSubmitted: (_) { if (!auth.isLoading) _verify(); }),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: auth.isLoading ? null : _verify, child: auth.isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const TrText('تأكيد الدخول')),
                  TextButton(onPressed: _resending ? null : _resend, child: Text(trUi(_resending ? 'جارٍ الإرسال...' : 'إعادة إرسال رمز البريد'))),
                  const Divider(height: 30),
                  const TrText('طرق بديلة', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  if (_loadingMethods) const Center(child: CircularProgressIndicator()) else ...[
                    if (_methods['authenticator'] == true)
                      OutlinedButton.icon(onPressed: _verifyAuthenticator, icon: const Icon(Icons.phonelink_lock_rounded), label: const TrText('استخدام تطبيق المصادقة')),
                    if (_methods['recovery_code'] == true)
                      OutlinedButton.icon(onPressed: _verifyRecoveryCode, icon: const Icon(Icons.vpn_key_outlined), label: const TrText('استخدام رمز استرداد')),
                    if (_methods['support'] == true && challenge != null)
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LoginAccountRecoveryScreen(challengeToken: challenge))),
                        icon: const Icon(Icons.support_agent_rounded),
                        label: const TrText('فقدت وسائل التحقق — طلب استرداد الحساب'),
                      ),
                  ],
                  if ((_localError ?? auth.errorMessage) != null) ...[
                    const SizedBox(height: 12),
                    Text(trUi((_localError ?? auth.errorMessage)!), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger)),
                  ],
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
