import 'package:flutter/material.dart';
import '../i18n/localized_text.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';
import 'account_security_screen.dart';
import 'dashboard_screen.dart';
import 'support_screen.dart';
import 'support_customer_search_screen.dart';

class AccountRecoverySupportScreen extends StatefulWidget {
  const AccountRecoverySupportScreen({super.key});

  @override
  State<AccountRecoverySupportScreen> createState() =>
      _AccountRecoverySupportScreenState();
}

class _AccountRecoverySupportScreenState
    extends State<AccountRecoverySupportScreen> {
  static Color get _bg => _RP.c(const Color(0xFF060A14), const Color(0xFFF4F7FC));
  static Color get _card => _RP.c(const Color(0xFF121E36), const Color(0xFFFFFFFF));
  static Color get _elevated => _RP.c(const Color(0xFF1A2948), const Color(0xFFEFF4FB));
  static const Color _cyan = Color(0xFF00F2FE);
  static Color get _cyanSoft => _RP.c(const Color(0xFF22D3EE), const Color(0xFF0891B2));

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  String _status = '';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await ApiService.fetchSupportAccountRecoveries(
        status: _status.isEmpty ? null : _status,
      );
      if (mounted) setState(() => _data = d);
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _statusLabel(String s) => switch (s) {
        'pending' => 'بانتظار الدعم'.tr(),
        'in_review' => 'قيد المراجعة'.tr(),
        'identity_verified' => 'تم التحقق من الهوية'.tr(),
        'recovered' => 'تم الاسترداد'.tr(),
        'rejected' => 'مرفوض'.tr(),
        _ => s,
      };

  Future<void> _setStatus(String value) async {
    if (_status == value) return;
    setState(() => _status = value);
    await _load();
  }

  Future<void> _action(
    int id,
    String action, {
    String? method,
    String? notes,
    String? password,
    String? reason,
  }) async {
    try {
      final msg = await ApiService.supportAccountRecoveryAction(
        id,
        action,
        verificationMethod: method,
        notes: notes,
        currentPassword: password,
        rejectionReason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(msg))));
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(trUi(e.message))));
      }
    }
  }

  Future<void> _issueTemporaryPassword(int id) async {
    final controller = TextEditingController();
    final currentPassword = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _card,
        title: const TrText('إصدار كلمة مرور مؤقتة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TrText('لن يتم تنفيذ العملية إلا بعد توثيق الهوية. سيتم إبطال الجلسات ووسائل التحقق القديمة، ويُجبر صاحب الحساب على تغيير كلمة المرور عند أول دخول.',
              style: TextStyle(height: 1.55),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'كلمة مرور موظف الدعم الحالية'.tr(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const TrText('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const TrText('إصدار'),
          ),
        ],
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 600), controller.dispose);
    if (currentPassword == null || currentPassword.isEmpty) return;

    try {
      final data = await ApiService.issueSupportTemporaryPassword(
        recoveryId: id,
        currentPassword: currentPassword,
      );
      if (!mounted) return;
      final password = data['temporary_password']?.toString() ?? '';
      final expiresAt = data['expires_at']?.toString() ?? '-';
      final method = data['delivery_method']?.toString() ?? '-';
      final value = data['delivery_value']?.toString() ?? '-';
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: _card,
          title: const TrText('كلمة المرور المؤقتة — تظهر مرة واحدة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _RP.c(const Color(0xFF020617), const Color(0xFFF8FAFC)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _RP.c(const Color(0x3386EFAC), const Color(0x3316A34A))),
                ),
                child: SelectableText(
                  password,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: _RP.c(Color(0xFF86EFAC), Color(0xFF16A34A)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TrText('الإرسال عبر: $method · $value'),
              TrText('تنتهي: $expiresAt'),
              const SizedBox(height: 8),
              TrText('انسخها وأرسلها فقط عبر وسيلة التواصل التي تم التحقق منها. لا يتم حفظ نص كلمة المرور في سجل النظام.',
                style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), height: 1.5),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: password));
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: TrText('تم نسخ كلمة المرور المؤقتة.')),
                  );
                }
              },
              child: const TrText('نسخ كلمة المرور'),
            ),
            TextButton(
              onPressed: () async {
                final message =
                    'تم استرجاع حسابك.\nكلمة المرور المؤقتة: $password\nصالحة حتى: $expiresAt\nسجّل الدخول ثم غيّر كلمة المرور فورًا.'.tr();
                await Clipboard.setData(ClipboardData(text: message));
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: TrText('تم نسخ رسالة الاسترداد.')),
                  );
                }
              },
              child: const TrText('نسخ رسالة كاملة'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const TrText('تم'),
            ),
          ],
        ),
      );
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(trUi(e.message))));
      }
    }
  }


  Future<void> _startRecoveryFace3d(int id) async {
    try {
      final data = await ApiService.startSupportRecoveryFaceVerification(id);
      final verification = Map<String, dynamic>.from(data['verification'] as Map? ?? const {});
      final url = verification['verification_url']?.toString() ?? '';
      if (url.isEmpty) throw ApiException('لم يتم إنشاء رابط تحقق صالح.'.tr());
      await Clipboard.setData(ClipboardData(text: url));
      final uri = Uri.tryParse(url);
      if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: TrText('تم إنشاء رابط التحقق 3D ونسخه. أرسله لصاحب الحساب ثم حدّث الطلب بعد إكمال الفحص.')));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    }
  }

  Future<void> _open(int id) async {
    try {
      final d = await ApiService.fetchSupportAccountRecovery(id);
      if (!mounted) return;
      final r = Map<String, dynamic>.from(d['recovery'] as Map? ?? const {});
      try {
        final face = await ApiService.fetchSupportRecoveryFaceVerificationStatus(id);
        final raw = face['verification'];
        if (raw is Map) r['face_verification'] = Map<String, dynamic>.from(raw);
      } catch (_) {}
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => _RecoveryDetail(
          recovery: r,
          onClaim: () async {
            Navigator.pop(sheetContext);
            await _action(id, 'claim');
          },
          onFaceVerification: () async {
            if (sheetContext.mounted) Navigator.pop(sheetContext);
            await _startRecoveryFace3d(id);
          },
          onVerify: () async {
            final result = await _verifyDialog(context);
            if (result == null || !mounted) return;
            if (sheetContext.mounted) Navigator.pop(sheetContext);
            await _action(
              id,
              'verify-identity',
              method: result.$1,
              notes: result.$2,
            );
          },
          onIssueTemporaryPassword: () async {
            Navigator.pop(sheetContext);
            await _issueTemporaryPassword(id);
          },
          onRestore: () async {
            final c = TextEditingController();
            final pw = await showDialog<String>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                backgroundColor: _card,
                title: const TrText('تأكيد استرجاع الحساب'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const TrText('سيتم تعطيل وسائل 2FA القديمة وإبطال الجلسات والتوكنات. كلمة مرور وحالة الحساب لا تتغير.',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: c,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'كلمة مرور موظف الدعم الحالية'.tr(),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const TrText('إلغاء'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, c.text),
                    child: const TrText('استرجاع'),
                  ),
                ],
              ),
            );
            Future<void>.delayed(const Duration(milliseconds: 600), c.dispose);
            if (pw == null || pw.isEmpty || !mounted) return;
            if (sheetContext.mounted) Navigator.pop(sheetContext);
            await _action(id, 'restore', password: pw);
          },
          onReject: () async {
            final c = TextEditingController();
            final reason = await showDialog<String>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                backgroundColor: _card,
                title: const TrText('رفض طلب الاسترداد'),
                content: TextField(
                  controller: c,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(labelText: 'سبب الرفض'.tr()),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const TrText('إلغاء'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, c.text.trim()),
                    child: const TrText('رفض'),
                  ),
                ],
              ),
            );
            Future<void>.delayed(const Duration(milliseconds: 600), c.dispose);
            if (reason == null || reason.length < 10 || !mounted) return;
            if (sheetContext.mounted) Navigator.pop(sheetContext);
            await _action(id, 'reject', reason: reason);
          },
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(trUi(e.message))));
      }
    }
  }

  Future<(String, String)?> _verifyDialog(BuildContext context) async {
    String method = 'phone';
    final notes = TextEditingController();
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _card,
          title: const TrText('توثيق التحقق من الهوية'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: method,
                items: const [
                  DropdownMenuItem(value: 'phone', child: TrText('هاتف')),
                  DropdownMenuItem(value: 'video', child: TrText('مكالمة فيديو')),
                  DropdownMenuItem(value: 'documents', child: TrText('مستندات')),
                  DropdownMenuItem(
                    value: 'known_information',
                    child: TrText('معلومات معروفة'),
                  ),
                  DropdownMenuItem(value: 'in_person', child: TrText('حضوري')),
                  DropdownMenuItem(value: 'other', child: TrText('أخرى')),
                ],
                onChanged: (v) =>
                    setDialogState(() => method = v ?? 'phone'),
                decoration: InputDecoration(labelText: 'طريقة التحقق'.tr()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notes,
                minLines: 4,
                maxLines: 7,
                decoration: InputDecoration(
                  labelText: 'ملاحظات التحقق (20 حرفًا على الأقل)'.tr(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const TrText('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                if (notes.text.trim().length >= 20) {
                  Navigator.pop(dialogContext, (method, notes.text.trim()));
                }
              },
              child: const TrText('توثيق'),
            ),
          ],
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 600), notes.dispose);
    return result;
  }

  Future<void> _toggleAgent(Map<String, dynamic> employee) async {
    final id = int.parse(employee['id'].toString());
    final enabled = employee['can_recover_accounts'] == true;
    try {
      final msg = await ApiService.updateRecoveryAgentPermission(
        userId: id,
        enabled: !enabled,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(msg))));
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(trUi(e.message))));
      }
    }
  }

  List<Map<String, dynamic>> _visibleItems() {
    final items = List<dynamic>.from(_data?['items'] as List? ?? const []);
    if (_query.trim().isEmpty) {
      return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    final q = _query.trim().toLowerCase();
    return items.map((e) => Map<String, dynamic>.from(e as Map)).where((r) {
      final user = Map<String, dynamic>.from(r['user'] as Map? ?? const {});
      final haystack = [
        r['reference'],
        r['account_identifier'],
        r['identity_claim_name'],
        r['contact_value'],
        user['name'],
        user['email'],
        user['phone'],
      ].whereType<Object>().map((e) => e.toString().toLowerCase()).join(' ');
      return haystack.contains(q);
    }).toList();
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts.first.characters.first}${parts[1].characters.first}'.toUpperCase();
    }
    final value = parts.isEmpty ? '?' : parts.first;
    return value.characters.take(2).toString().toUpperCase();
  }

  Color _statusColor(String status) => switch (status) {
        'recovered' => _RP.c(const Color(0xFF34D399), const Color(0xFF059669)),
        'rejected' => _RP.c(const Color(0xFFFB7185), const Color(0xFFE11D48)),
        'identity_verified' => _RP.c(const Color(0xFF93C5FD), const Color(0xFF2563EB)),
        _ => _RP.c(const Color(0xFFFBBF24), const Color(0xFFD97706)),
      };

  Widget _metric(String label, Object? value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: .25)),
        ),
        child: Column(
          children: [
            Text(
              trUi(label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color.withValues(alpha: .85),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${value ?? 0}',
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String value, String text, int count, Color color) {
    final selected = _status == value;
    return InkWell(
      onTap: () => _setStatus(value),
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _cyan : _card,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected ? _cyan : color.withValues(alpha: .35),
          ),
          boxShadow: selected
              ? [BoxShadow(color: _cyan.withValues(alpha: .18), blurRadius: 12)]
              : null,
        ),
        child: Text(
          '$text ($count)',
          style: TextStyle(
            color: selected ? const Color(0xFF082032) : color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> r, int index) {
    final user = Map<String, dynamic>.from(r['user'] as Map? ?? const {});
    final assigned =
        Map<String, dynamic>.from(r['assigned_to'] as Map? ?? const {});
    final status = r['status']?.toString() ?? '';
    final recovered = status == 'recovered';
    final rejected = status == 'rejected';
    final verified = status == 'identity_verified';
    final open = !recovered && !rejected;
    final accent = _statusColor(status);
    final name = user['name']?.toString().trim().isNotEmpty == true
        ? user['name'].toString()
        : (r['identity_claim_name']?.toString() ?? 'مستخدم غير معروف'.tr());
    final identifier = user['email']?.toString().trim().isNotEmpty == true
        ? user['email'].toString()
        : (r['account_identifier']?.toString() ?? '—');
    final createdAt = DateTime.tryParse(r['created_at']?.toString() ?? '');
    final actionText = recovered
        ? 'فتح الطلب وتفاصيله'
        : rejected
            ? 'عرض سبب الرفض والتقرير'
            : verified
                ? 'إصدار كلمة المرور المؤقتة'
                : 'مراجعة الهوية ومستند الإثبات';

    return Opacity(
      opacity: rejected ? .84 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: open
              ? LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [_RP.c(Color(0xD9231A0F), Color(0xFFFFFBEB)), _RP.c(const Color(0xF214100C), const Color(0xFFFEF3C7))],
                )
              : LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [_RP.c(Color(0xE0121E36), Color(0xFFFFFFFF)), _RP.c(const Color(0xF20D1527), const Color(0xFFF8FAFC))],
                ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: .28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .22),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 7,
                        runSpacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: accent.withValues(alpha: .28),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  trUi(_statusLabel(status)),
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '#${(index + 1).toString().padLeft(3, '0')}',
                            style: TextStyle(
                              color: accent.withValues(alpha: .58),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      InkWell(
                        onTap: () async {
                          await Clipboard.setData(
                            ClipboardData(text: r['reference']?.toString() ?? ''),
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: TrText('تم نسخ معرف الطلب.')),
                            );
                          }
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                trUi(r['reference']?.toString() ?? '-'),
                                style: TextStyle(
                                  color: open ? _RP.c(const Color(0xFFFCD34D), const Color(0xFFB45309)) : _cyanSoft,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Icon(Icons.copy_rounded, size: 14, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      trUi(createdAt == null
                          ? '--:--'
                          : '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}'),
                      style: TextStyle(
                        color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFCBD5E1) : Theme.of(context).colorScheme.onSurfaceVariant),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      trUi(createdAt == null
                          ? '----/--/--'
                          : '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}'),
                      style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF64748B) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 9),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 11),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .28),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _RP.c(Colors.white.withValues(alpha: .05), Colors.black.withValues(alpha: .07))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: open
                          ? _RP.c(const Color(0x55451A03), const Color(0x33FDE68A))
                          : _RP.c(const Color(0xFF1E293B), const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent.withValues(alpha: .22)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      trUi(_initials(name)),
                      style: TextStyle(
                        color: open ? _RP.c(const Color(0xFFFCD34D), const Color(0xFFB45309)) : _RP.c(const Color(0xFFE2E8F0), const Color(0xFF0F172A)),
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trUi(name),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _RP.c(Colors.white, Color(0xFF0F172A)),
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          trUi(identifier),
                          textDirection: TextDirection.ltr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: open
                                ? _RP.c(const Color(0xFFD6D3D1), const Color(0xFF57534E))
                                : _RP.c(const Color(0xFF94A3B8), const Color(0xFF64748B)),
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      TrText('الموظف المعين:',
                        style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 9.5),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: accent.withValues(alpha: .22)),
                        ),
                        child: Text(
                          assigned['name']?.toString() ?? 'غير معين'.tr(),
                          style: TextStyle(
                            color: accent,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: open
                            ? _RP.c(const Color(0xFFFBBF24), const Color(0xFFD97706))
                            : recovered
                                ? _cyan
                                : _elevated,
                        foregroundColor: open || recovered
                            ? const Color(0xFF082032)
                            : _RP.c(const Color(0xFFE2E8F0), const Color(0xFF0F172A)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _open(int.parse(r['id'].toString())),
                      icon: Icon(open ? Icons.verified_user_outlined : Icons.open_in_new, size: 17),
                      label: Text(
                        trUi(actionText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: _elevated,
                      foregroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFCBD5E1) : Theme.of(context).colorScheme.onSurfaceVariant),
                      side: BorderSide(color: _RP.c(Colors.white.withValues(alpha: .10), Colors.black.withValues(alpha: .12))),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _open(int.parse(r['id'].toString())),
                    child: const Icon(Icons.history_rounded, size: 18),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomNavItem({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (active)
                Container(
                  width: 32,
                  height: 3,
                  margin: const EdgeInsets.only(bottom: 5),
                  decoration: BoxDecoration(
                    color: _cyanSoft,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: _cyan.withValues(alpha: .45),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                )
              else
                const SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(active ? 6 : 4),
                decoration: BoxDecoration(
                  color: active ? _cyan.withValues(alpha: .12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: active
                      ? Border.all(color: _cyanSoft.withValues(alpha: .28))
                      : null,
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: active ? _cyanSoft : _RP.c(const Color(0xFF94A3B8), const Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                trUi(label),
                style: TextStyle(
                  color: active ? _RP.c(Colors.white, const Color(0xFF0F172A)) : _RP.c(const Color(0xFF94A3B8), const Color(0xFF64748B)),
                  fontSize: active ? 10.5 : 9.5,
                  fontWeight: active ? FontWeight.w900 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _RP.dark = Theme.of(context).brightness == Brightness.dark;
    final items = _visibleItems();
    final employees = List<dynamic>.from(_data?['employees'] as List? ?? const []);
    final isAdmin = _data?['is_admin'] == true;
    final stats = Map<String, dynamic>.from(_data?['stats'] as Map? ?? const {});
    final auth = context.watch<AuthProvider>();
    final userName = auth.user?.name ?? 'موظف الدعم'.tr();

    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        backgroundColor: _bg,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: _RP.c(const Color(0xF2080E1C), const Color(0xF2FFFFFF)),
            border: Border(
              top: BorderSide(color: _cyanSoft.withValues(alpha: .10)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                _bottomNavItem(
                  icon: Icons.grid_view_rounded,
                  label: 'لوحة التحكم'.tr(),
                  active: false,
                  onTap: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const DashboardScreen()),
                  ),
                ),
                _bottomNavItem(
                  icon: Icons.history_rounded,
                  label: 'استرجاع الحسابات'.tr(),
                  active: true,
                  onTap: () {},
                ),
                _bottomNavItem(
                  icon: Icons.shield_outlined,
                  label: 'إعدادات الأمان'.tr(),
                  active: false,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AccountSecurityScreen()),
                  ),
                ),
                _bottomNavItem(
                  icon: Icons.support_agent_rounded,
                  label: 'الدعم الفني'.tr(),
                  active: false,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SupportScreen()),
                  ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _searchFocusNode.requestFocus(),
          backgroundColor: _cyan,
          foregroundColor: const Color(0xFF082032),
          child: const Icon(Icons.search_rounded),
        ),
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _load,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 11),
                    decoration: BoxDecoration(
                      color: _RP.c(const Color(0xDD0D1527), const Color(0xF0FFFFFF)),
                      border: Border(
                        bottom: BorderSide(color: _RP.c(Colors.white.withValues(alpha: .05), Colors.black.withValues(alpha: .07))),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _cyan.withValues(alpha: .08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _cyanSoft.withValues(alpha: .28)),
                              ),
                              child: Icon(Icons.shield_outlined, color: _cyanSoft, size: 21),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _RP.c(const Color(0xFF083344), const Color(0xFFE0F7FB)),
                                          borderRadius: BorderRadius.circular(5),
                                          border: Border.all(color: _cyanSoft.withValues(alpha: .28)),
                                        ),
                                        child: TrText('بوابة الأمان',
                                          style: TextStyle(
                                            color: _cyanSoft,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: _RP.c(Color(0xFF34D399), Color(0xFF059669)),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ),
                                  TrText('استعادة الحسابات',
                                    style: TextStyle(
                                      color: _RP.c(Colors.white, Color(0xFF0F172A)),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'بحث شامل عن حساب'.tr(),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const SupportCustomerSearchScreen()),
                              ),
                              icon: Icon(Icons.manage_search_rounded, color: _cyanSoft),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                              decoration: BoxDecoration(
                                color: _card,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: _cyanSoft.withValues(alpha: .13)),
                              ),
                              child: Row(
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        trUi(userName),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: _RP.c(Colors.white, Color(0xFF0F172A)),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      TrText('مستوى أمني عالي',
                                        style: TextStyle(color: _cyanSoft, fontSize: 9),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 7),
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: const Color(0xFF0891B2),
                                    child: Text(
                                      trUi(_initials(userName)),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _RP.c(const Color(0x339F1239), const Color(0x1AE11D48)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _RP.c(const Color(0x667F1D1D), const Color(0x66FCA5A5))),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.warning_amber_rounded, color: _RP.c(Color(0xFFFB7185), Color(0xFFE11D48)), size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: TrText('تنبيه أمني مشدد: تحتوي هذه الشاشة على بيانات تعريفية حساسة. يحظر استرجاع أو إعادة تعيين أي حساب قبل مطابقة الهوية والمستندات المرفقة وتوثيق نتيجة التحقق.',
                                  style: TextStyle(
                                    color: _RP.c(const Color(0xFFFECACA), const Color(0xFF9F1239)),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 50),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_error != null)
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: _RP.c(const Color(0x339F1239), const Color(0x1AE11D48)),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _RP.c(const Color(0x667F1D1D), const Color(0x66FCA5A5))),
                          ),
                          child: Column(
                            children: [
                              Text(trUi(_error!), style: TextStyle(color: _RP.c(Color(0xFFFCA5A5), Color(0xFFB91C1C)))),
                              const SizedBox(height: 8),
                              FilledButton(onPressed: _load, child: const TrText('إعادة المحاولة')),
                            ],
                          ),
                        )
                      else ...[
                        Row(
                          children: [
                            _metric('الإجمالي', stats['total'] ?? 0, _RP.c(Colors.white, const Color(0xFF0F172A))),
                            const SizedBox(width: 7),
                            _metric('بالانتظار', stats['open'] ?? 0, _RP.c(const Color(0xFFFBBF24), const Color(0xFFD97706))),
                            const SizedBox(width: 7),
                            _metric('مكتمل', stats['recovered'] ?? 0, _RP.c(const Color(0xFF34D399), const Color(0xFF059669))),
                            const SizedBox(width: 7),
                            _metric('مرفوض', stats['rejected'] ?? 0, _RP.c(const Color(0xFFFB7185), const Color(0xFFE11D48))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onChanged: (value) => setState(() => _query = value),
                          style: TextStyle(color: _RP.c(Colors.white, Color(0xFF0F172A)), fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'ابحث برقم الطلب، البريد، أو الاسم...'.tr(),
                            hintStyle: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 11.5),
                            prefixIcon: Icon(Icons.search_rounded, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurfaceVariant), size: 20),
                            suffixIcon: _query.isNotEmpty
                                ? IconButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _query = '');
                                    },
                                    icon: Icon(Icons.close_rounded, color: _cyanSoft, size: 18),
                                  )
                                : Icon(Icons.filter_alt_outlined, color: _cyanSoft, size: 18),
                            filled: true,
                            fillColor: _card,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: _cyanSoft.withValues(alpha: .14)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: _cyanSoft.withValues(alpha: .14)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: _cyanSoft),
                            ),
                          ),
                        ),
                        const SizedBox(height: 9),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _filterChip('', 'الكل', int.tryParse('${stats['total'] ?? 0}') ?? 0, _cyanSoft),
                              const SizedBox(width: 7),
                              _filterChip('open', 'بانتظار التحقق', int.tryParse('${stats['open'] ?? 0}') ?? 0, _RP.c(const Color(0xFFFBBF24), const Color(0xFFD97706))),
                              const SizedBox(width: 7),
                              _filterChip('recovered', 'تم الاسترجاع', int.tryParse('${stats['recovered'] ?? 0}') ?? 0, _RP.c(const Color(0xFF34D399), const Color(0xFF059669))),
                              const SizedBox(width: 7),
                              _filterChip('rejected', 'مرفوض', int.tryParse('${stats['rejected'] ?? 0}') ?? 0, _RP.c(const Color(0xFFFB7185), const Color(0xFFE11D48))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(color: _cyanSoft, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: TrText('طلبات استرداد الحسابات الحديثة',
                                style: TextStyle(
                                  color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFCBD5E1) : Theme.of(context).colorScheme.onSurfaceVariant),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            TrText('${items.length} طلب',
                              style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF64748B) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 10),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (items.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: _card,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _RP.c(Colors.white.withValues(alpha: .05), Colors.black.withValues(alpha: .07))),
                            ),
                            child: const Center(
                              child: TrText('لا توجد طلبات استرداد تطابق البحث الحالي.'),
                            ),
                          )
                        else
                          ...List.generate(items.length, (index) => _requestCard(items[index], index)),
                        if (isAdmin) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(Icons.admin_panel_settings_outlined, color: _RP.c(const Color(0xFFC4B5FD), const Color(0xFF7C3AED)), size: 18),
                              SizedBox(width: 7),
                              TrText('موظفو الاسترداد المصرّح لهم',
                                style: TextStyle(
                                  color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFE2E8F0) : Theme.of(context).colorScheme.onSurface),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...employees.map((raw) {
                            final e = Map<String, dynamic>.from(raw as Map);
                            final enabled = e['can_recover_accounts'] == true;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _RP.c(Colors.white.withValues(alpha: .06), Colors.black.withValues(alpha: .08))),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          trUi(e['name']?.toString() ?? '-'),
                                          style: const TextStyle(fontWeight: FontWeight.w800),
                                        ),
                                        Text(
                                          trUi(e['email']?.toString() ?? ''),
                                          textDirection: TextDirection.ltr,
                                          style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 10.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: enabled,
                                    onChanged: (_) => _toggleAgent(e),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecoveryDetail extends StatelessWidget {
  static Color get _bg => _RP.c(const Color(0xFF060A14), const Color(0xFFF4F7FC));
  static Color get _card => _RP.c(const Color(0xFF121E36), const Color(0xFFFFFFFF));
  static Color get _cyan => _RP.c(const Color(0xFF22D3EE), const Color(0xFF0891B2));

  final Map<String, dynamic> recovery;
  final VoidCallback onClaim;
  final VoidCallback onVerify;
  final VoidCallback onFaceVerification;
  final VoidCallback onRestore;
  final VoidCallback onIssueTemporaryPassword;
  final VoidCallback onReject;

  const _RecoveryDetail({
    required this.recovery,
    required this.onClaim,
    required this.onVerify,
    required this.onFaceVerification,
    required this.onRestore,
    required this.onIssueTemporaryPassword,
    required this.onReject,
  });

  String _label(String status) => switch (status) {
        'pending' => 'بانتظار الدعم'.tr(),
        'in_review' => 'قيد المراجعة'.tr(),
        'identity_verified' => 'تم التحقق من الهوية'.tr(),
        'recovered' => 'تم الاسترجاع'.tr(),
        'rejected' => 'مرفوض'.tr(),
        _ => status,
      };

  Color _accent(String status) => switch (status) {
        'recovered' => _RP.c(const Color(0xFF34D399), const Color(0xFF059669)),
        'rejected' => _RP.c(const Color(0xFFFB7185), const Color(0xFFE11D48)),
        'identity_verified' => _RP.c(const Color(0xFF93C5FD), const Color(0xFF2563EB)),
        _ => _RP.c(const Color(0xFFFBBF24), const Color(0xFFD97706)),
      };

  Widget _panel({required Widget child, EdgeInsets padding = const EdgeInsets.all(14)}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _card.withValues(alpha: .88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _RP.c(Colors.white.withValues(alpha: .07), Colors.black.withValues(alpha: .08))),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(IconData icon, String text, {Color? color}) {
    color ??= _cyan;
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 7),
        Text(
          trUi(text),
          style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    _RP.dark = Theme.of(context).brightness == Brightness.dark;
    final user = Map<String, dynamic>.from(recovery['user'] as Map? ?? const {});
    final status = recovery['status']?.toString() ?? '';
    final accent = _accent(status);
    final events = List<dynamic>.from(recovery['events'] as List? ?? const []);
    final evidence = List<dynamic>.from(recovery['evidence'] as List? ?? const []);
    final faceVerification = Map<String, dynamic>.from(recovery['face_verification'] as Map? ?? const {});

    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: .92,
          minChildSize: .58,
          maxChildSize: .98,
          builder: (context, scroll) => Container(
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 26),
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF475569) : Theme.of(context).colorScheme.onSurfaceVariant),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                _panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              trUi(recovery['reference']?.toString() ?? ''),
                              textDirection: TextDirection.ltr,
                              style: TextStyle(
                                color: _cyan,
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .5,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: .10),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: accent.withValues(alpha: .25)),
                            ),
                            child: Text(
                              trUi(_label(status)),
                              style: TextStyle(
                                color: accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Divider(height: 24, color: _RP.c(Color(0x223F4B5A), Color(0x22334155))),
                      Text(
                        trUi(user['name']?.toString() ?? '-'),
                        style: TextStyle(
                          color: _RP.c(Colors.white, Color(0xFF0F172A)),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        trUi(user['email']?.toString() ?? '-'),
                        textDirection: TextDirection.ltr,
                        style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 11),
                      ),
                      const SizedBox(height: 5),
                      TrText('الدور: ${user['role'] ?? '-'} · حالة الحساب: ${user['status'] ?? '-'}',
                        style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFCBD5E1) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(Icons.info_outline_rounded, 'سبب الطلب'),
                      const SizedBox(height: 10),
                      Text(
                        trUi(recovery['reason']?.toString() ?? '-'),
                        style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFCBD5E1) : Theme.of(context).colorScheme.onSurfaceVariant), height: 1.65, fontSize: 11.5),
                      ),
                      const SizedBox(height: 9),
                      TrText('التواصل: ${recovery['contact_method'] ?? '-'} · ${recovery['contact_value'] ?? '-'}',
                        style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
                if ((recovery['identity_check_notes']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(Icons.verified_user_outlined, 'التحقق من الهوية', color: _RP.c(const Color(0xFFA5B4FC), const Color(0xFF4F46E5))),
                        const SizedBox(height: 9),
                        Text(
                          '${recovery['identity_verification_method'] ?? '-'}\n${recovery['identity_check_notes']}',
                          style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFCBD5E1) : Theme.of(context).colorScheme.onSurfaceVariant), height: 1.65, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ],
                if (faceVerification.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(Icons.psychology_alt_outlined, 'قرار التحقق بالذكاء الاصطناعي', color: _RP.c(const Color(0xFF67E8F9), const Color(0xFF0891B2))),
                        const SizedBox(height: 9),
                        Builder(builder: (context) {
                          final vStatus = faceVerification['status']?.toString() ?? '-';
                          final match = (((faceVerification['match_score'] as num?)?.toDouble() ?? 0) * 100).round();
                          final live = (((faceVerification['liveness_score'] as num?)?.toDouble() ?? 0) * 100).round();
                          final quality = (((faceVerification['identity_quality_score'] as num?)?.toDouble() ?? 0) * 100).round();
                          final consistency = (((faceVerification['session_consistency_score'] as num?)?.toDouble() ?? 0) * 100).round();
                          final risk = faceVerification['risk_level']?.toString() ?? '-';
                          final label = vStatus == 'matched'
                              ? 'متطابق تلقائيًا'
                              : vStatus == 'review_required'
                                  ? 'يحتاج مراجعة بشرية'
                                  : vStatus == 'failed'
                                      ? 'غير متطابق / فشل أمني'
                                      : vStatus;
                          return TrText('$label\nمطابقة الوجه: $match% · الحيوية: $live% · جودة المرجع: $quality% · اتساق الجلسة: $consistency% · المخاطر: $risk',
                            style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFCBD5E1) : Theme.of(context).colorScheme.onSurfaceVariant), height: 1.7, fontSize: 11.5),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
                if ((recovery['rejection_reason']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _panel(
                    child: TrText('سبب الرفض: ${recovery['rejection_reason']}',
                      style: TextStyle(color: _RP.c(Color(0xFFFB7185), Color(0xFFE11D48)), height: 1.6),
                    ),
                  ),
                ],
                if (evidence.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(Icons.attach_file_rounded, 'مرفقات وإثباتات الهوية', color: _RP.c(const Color(0xFFA5B4FC), const Color(0xFF4F46E5))),
                        const SizedBox(height: 8),
                        ...evidence.map((raw) {
                          final file = Map<String, dynamic>.from(raw as Map);
                          return Material(
                            color: Colors.transparent,
                            child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.verified_user_outlined, color: _RP.c(Color(0xFFA5B4FC), Color(0xFF4F46E5))),
                            title: Text(
                              file['original_name']?.toString() ?? 'مرفق'.tr(),
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              '${file['mime_type'] ?? ''} · ${file['size_bytes'] ?? 0} bytes',
                              style: TextStyle(fontSize: 9.5, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurfaceVariant)),
                            ),
                            trailing: Icon(Icons.open_in_new, size: 17, color: _cyan),
                            onTap: () async {
                              try {
                                final local = await ApiService.downloadSupportRecoveryEvidence(
                                  recoveryId: int.parse(recovery['id'].toString()),
                                  evidenceId: int.parse(file['id'].toString()),
                                  fileName: file['original_name']?.toString() ?? 'evidence',
                                );
                                await OpenFilex.open(local.path);
                              } on ApiException catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(trUi(e.message))),
                                  );
                                }
                              }
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                _panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(Icons.security_rounded, 'إجراءات موظف الدعم', color: _RP.c(const Color(0xFFFBBF24), const Color(0xFFD97706))),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (status == 'pending' || status == 'in_review')
                            OutlinedButton.icon(
                              onPressed: onClaim,
                              icon: const Icon(Icons.person_add_alt),
                              label: const TrText('استلام الطلب'),
                            ),
                          if (status == 'pending' || status == 'in_review')
                            FilledButton.icon(
                              onPressed: onFaceVerification,
                              icon: const Icon(Icons.face_retouching_natural),
                              label: const TrText('إرسال رابط تحقق 3D'),
                            ),
                          if (status == 'pending' || status == 'in_review')
                            FilledButton.tonalIcon(
                              onPressed: onVerify,
                              icon: const Icon(Icons.badge_outlined),
                              label: const TrText('توثيق الهوية'),
                            ),
                          if (status == 'identity_verified')
                            FilledButton.icon(
                              onPressed: onIssueTemporaryPassword,
                              icon: const Icon(Icons.password_rounded),
                              label: const TrText('إصدار كلمة مرور مؤقتة'),
                            ),
                          if (status == 'identity_verified')
                            OutlinedButton.icon(
                              onPressed: onRestore,
                              icon: const Icon(Icons.lock_open_rounded),
                              label: const TrText('استرجاع بدون تغيير كلمة المرور'),
                            ),
                          if (status != 'recovered' && status != 'rejected')
                            OutlinedButton.icon(
                              onPressed: onReject,
                              icon: const Icon(Icons.block),
                              label: const TrText('رفض'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(Icons.history_rounded, 'سجل التدقيق الأمني'),
                      const SizedBox(height: 10),
                      if (events.isEmpty)
                        TrText('لا توجد أحداث مسجلة.',
                          style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 11),
                        )
                      else
                        ...events.map((raw) {
                          final e = Map<String, dynamic>.from(raw as Map);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(color: _cyan, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        trUi(e['event']?.toString() ?? ''),
                                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5),
                                      ),
                                      if ((e['notes']?.toString() ?? '').isNotEmpty)
                                        Text(
                                          trUi(e['notes'].toString()),
                                          style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFCBD5E1) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 10.5, height: 1.5),
                                        ),
                                      Text(
                                        '${e['actor'] ?? '-'} · ${e['created_at'] ?? ''}',
                                        style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF64748B) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 9.5),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Day/night palette for the account recovery screens (set at the start of every build).
class _RP {
  static bool dark = true;
  static Color c(Color darkColor, Color lightColor) => dark ? darkColor : lightColor;
}
