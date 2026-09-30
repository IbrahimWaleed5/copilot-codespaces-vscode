import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../i18n/localized_text.dart';
import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';
import 'payment_information_screen.dart';

class ProfessionalVerificationScreen extends StatefulWidget {
  const ProfessionalVerificationScreen({super.key});

  @override
  State<ProfessionalVerificationScreen> createState() =>
      _ProfessionalVerificationScreenState();
}

class _ProfessionalVerificationScreenState
    extends State<ProfessionalVerificationScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
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
      final data = await ApiService.fetchProfessionalVerification();
      if (!mounted) return;
      setState(() => _data = data);
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<File?> _pickDocument() async {
    final selected = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );
    if (selected?.path == null) return null;
    return File(selected!.path!);
  }

  Future<void> _openApplicationForm() async {
    final subjectType = _data?['subject_type']?.toString() ?? '';
    if (!['engineer', 'office'].contains(subjectType)) return;

    final experience = TextEditingController();
    final note = TextEditingController();
    File? identity;
    File? degree;
    File? syndicate;
    File? experienceProof;
    File? registration;
    File? license;
    bool saving = false;

    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF0D1B31) : Theme.of(context).colorScheme.surface),
      builder: (sheetContext) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          Widget fileButton(
            String label,
            File? file,
            Future<void> Function() onTap,
          ) {
            return SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: saving ? null : onTap,
                icon: Icon(file == null
                    ? Icons.upload_file_outlined
                    : Icons.check_circle_outline_rounded),
                label: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    trUi(file == null
                        ? label
                        : file.path.split(Platform.pathSeparator).last),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            );
          }

          Future<void> choose(void Function(File value) assign) async {
            final file = await _pickDocument();
            if (file == null || !modalContext.mounted) return;
            setModalState(() => assign(file));
          }

          Future<void> submit() async {
            if (saving) return;
            if (subjectType == 'engineer') {
              final years = int.tryParse(experience.text.trim());
              if (years == null || years < 0) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(content: TrText('أدخل عدد سنوات الخبرة بشكل صحيح.')),
                );
                return;
              }
              if (identity == null || degree == null || syndicate == null) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(content: TrText('الهوية والشهادة الجامعية وإثبات النقابة مطلوبة.')),
                );
                return;
              }
            } else if (registration == null || license == null) {
              ScaffoldMessenger.of(sheetContext).showSnackBar(
                const SnackBar(content: TrText('السجل والترخيص مطلوبان لطلب توثيق المكتب.')),
              );
              return;
            }

            setModalState(() => saving = true);
            try {
              final result = await ApiService.submitProfessionalVerificationApplication(
                subjectType: subjectType,
                experienceYears: subjectType == 'engineer'
                    ? int.tryParse(experience.text.trim())
                    : null,
                identity: identity,
                degree: degree,
                syndicate: syndicate,
                experienceProof: experienceProof,
                registrationDocument: registration,
                licenseDocument: license,
                applicantNote: note.text,
              );
              if (!sheetContext.mounted) return;
              // نعيد النتيجة أولاً، وبعد إغلاق الـBottomSheet بالكامل يقوم الأب
              // بالتحديث. هذا يمنع assertion _dependents.isEmpty أثناء تفكيك المسار.
              Navigator.of(sheetContext).pop(result);
            } on ApiException catch (e) {
              if (!sheetContext.mounted) return;
              ScaffoldMessenger.of(sheetContext).showSnackBar(
                SnackBar(content: Text(trUi(e.message))),
              );
              setModalState(() => saving = false);
            } catch (_) {
              if (!sheetContext.mounted) return;
              ScaffoldMessenger.of(sheetContext).showSnackBar(
                const SnackBar(content: TrText('تعذر إرسال طلب التوثيق. حاول مرة أخرى.')),
              );
              setModalState(() => saving = false);
            }
          }

          return Directionality(
            textDirection: AppLanguage.instance.textDirection,
            child: FractionallySizedBox(
              heightFactor: .94,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 18,
                  bottom: MediaQuery.of(modalContext).viewInsets.bottom + 18,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              trUi(subjectType == 'office'
                                  ? 'طلب توثيق المكتب'
                                  : 'طلب توثيق المهندس'),
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: saving ? null : () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TrText('ترسل المستندات إلى إدارة المنصة للمراجعة، وبعد الاعتماد يظهر اشتراك التوثيق.',
                        style: TextStyle(
                          color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant),
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (subjectType == 'engineer') ...[
                        TextField(
                          controller: experience,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: 'سنوات الخبرة *'.tr()),
                        ),
                        const SizedBox(height: 10),
                        fileButton('الهوية الشخصية *', identity, () => choose((file) => identity = file)),
                        const SizedBox(height: 8),
                        fileButton('الشهادة الجامعية *', degree, () => choose((file) => degree = file)),
                        const SizedBox(height: 8),
                        fileButton('إثبات النقابة / الاعتماد *', syndicate, () => choose((file) => syndicate = file)),
                        const SizedBox(height: 8),
                        fileButton('إثبات الخبرة (اختياري)', experienceProof, () => choose((file) => experienceProof = file)),
                      ] else ...[
                        fileButton('السجل التجاري / تسجيل المكتب *', registration, () => choose((file) => registration = file)),
                        const SizedBox(height: 8),
                        fileButton('ترخيص المكتب *', license, () => choose((file) => license = file)),
                      ],
                      const SizedBox(height: 10),
                      TextField(
                        controller: note,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'ملاحظة للإدارة (اختياري)'.tr(),
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: saving ? null : submit,
                        icon: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.verified_user_outlined),
                        label: Text(trUi(saving ? 'جاري الإرسال...' : 'إرسال طلب التوثيق')),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    // showModalBottomSheet يكمل Future عند pop قبل انتهاء حركة الإغلاق.
    // ننتظر انتهاء الـroute transition قبل التخلص من الـcontrollers أو إعادة بناء الأب.
    await Future<void>.delayed(const Duration(milliseconds: 380));
    experience.dispose();
    note.dispose();

    if (!mounted || message == null || message.trim().isEmpty) return;
    _snack(message);
    await _load();
  }

  Future<void> _openSubscriptionForm() async {
    final settings =
        Map<String, dynamic>.from(_data?['settings'] as Map? ?? const {});
    final subjectType = _data?['subject_type']?.toString();
    final amount = subjectType == 'office'
        ? settings['office_monthly_fee']
        : settings['engineer_monthly_fee'];
    final currency = settings['currency']?.toString() ?? '';
    final methods = <String>[];
    if (settings['bank_transfer_enabled'] == true) methods.add('bank_transfer');
    if (settings['wallet_enabled'] == true) methods.add('wallet');
    if (methods.isEmpty) {
      _snack('لا توجد طريقة دفع مفعلة حاليًا.'.tr());
      return;
    }

    String method = methods.first;
    final reference = TextEditingController();
    File? receipt;
    bool saving = false;

    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF0D1B31) : Theme.of(context).colorScheme.surface),
      builder: (sheetContext) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          Future<void> submit() async {
            if (saving) return;
            if (receipt == null) {
              ScaffoldMessenger.of(sheetContext).showSnackBar(
                const SnackBar(content: TrText('ارفع إيصال الدفع أولًا.')),
              );
              return;
            }
            setModalState(() => saving = true);
            try {
              final result =
                  await ApiService.submitProfessionalVerificationSubscription(
                paymentMethod: method,
                paymentReference: reference.text,
                receipt: receipt!,
              );
              if (!sheetContext.mounted) return;
              Navigator.of(sheetContext).pop(result);
            } on ApiException catch (e) {
              if (!sheetContext.mounted) return;
              ScaffoldMessenger.of(sheetContext).showSnackBar(
                SnackBar(content: Text(trUi(e.message))),
              );
              setModalState(() => saving = false);
            } catch (_) {
              if (!sheetContext.mounted) return;
              ScaffoldMessenger.of(sheetContext).showSnackBar(
                const SnackBar(content: TrText('تعذر إرسال إيصال التوثيق. حاول مرة أخرى.')),
              );
              setModalState(() => saving = false);
            }
          }

          return Directionality(
            textDirection: AppLanguage.instance.textDirection,
            child: FractionallySizedBox(
              heightFactor: .88,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 18,
                  bottom: MediaQuery.of(modalContext).viewInsets.bottom + 18,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: TrText('اشتراك شارة التوثيق',
                              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                            ),
                          ),
                          IconButton(
                            onPressed: saving ? null : () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TrText('القيمة الشهرية: ${amount ?? '—'} $currency',
                        style: TextStyle(
                          color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF67E8F9) : AppColors.cyan300),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: method,
                        decoration: InputDecoration(labelText: 'طريقة الدفع'.tr()),
                        items: methods
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(trUi(value == 'bank_transfer'
                                    ? 'تحويل بنكي'
                                    : 'محفظة إلكترونية')),
                              ),
                            )
                            .toList(),
                        onChanged: saving
                            ? null
                            : (value) => setModalState(
                                  () => method = value ?? methods.first,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: saving
                              ? null
                              : () => Navigator.of(sheetContext).pop('__OPEN_PAYMENT_INFO__'),
                          icon: const Icon(Icons.info_outline_rounded),
                          label: const TrText('عرض بيانات الدفع الرسمية'),
                        ),
                      ),
                      TextField(
                        controller: reference,
                        decoration: InputDecoration(
                          labelText: 'رقم/مرجع التحويل (اختياري)'.tr(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: saving
                            ? null
                            : () async {
                                final file = await _pickDocument();
                                if (file != null && modalContext.mounted) {
                                  setModalState(() => receipt = file);
                                }
                              },
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: Text(
                          trUi(receipt == null
                              ? 'رفع إيصال الدفع *'
                              : receipt!.path.split(Platform.pathSeparator).last),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: saving ? null : submit,
                        icon: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded),
                        label: Text(trUi(saving ? 'جاري الإرسال...' : 'إرسال الإيصال للمراجعة')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    // نفس حماية دورة حياة الـBottomSheet المستخدمة في نموذج طلب التوثيق.
    await Future<void>.delayed(const Duration(milliseconds: 380));
    Future<void>.delayed(const Duration(milliseconds: 600), reference.dispose);

    if (!mounted || message == null) return;
    if (message == '__OPEN_PAYMENT_INFO__') {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PaymentInformationScreen()),
      );
      return;
    }
    if (message.trim().isEmpty) return;
    _snack(message);
    await _load();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
  }

  @override
  Widget build(BuildContext context) {
    final verified = _data?['verified'] == true;
    final app = _data?['latest_application'] as Map?;
    final subs = List<dynamic>.from(_data?['subscriptions'] as List? ?? const []);
    final eligibility =
        Map<String, dynamic>.from(_data?['eligibility'] as Map? ?? const {});
    final checks =
        Map<String, dynamic>.from(eligibility['checks'] as Map? ?? const {});
    final canApply = _data?['can_apply'] == true;
    final canSubscribe = _data?['can_subscribe'] == true;
    final subjectType = _data?['subject_type']?.toString();

    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: Text(trUi(subjectType == 'office'
              ? 'توثيق المكتب'
              : 'توثيق الحساب المهني')),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(trUi(_error!)))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF0D1B31) : Theme.of(context).colorScheme.surface),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: verified
                                  ? const Color(0x5534D399)
                                  : (Theme.of(context).brightness == Brightness.dark ? Color(0x1AFFFFFF) : AppColors.borderSoft),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                verified
                                    ? Icons.verified_rounded
                                    : Icons.verified_outlined,
                                color: verified
                                    ? const Color(0xFF34D399)
                                    : const Color(0xFFA78BFA),
                                size: 40,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      trUi(verified
                                          ? 'حساب موثّق احترافيًا'
                                          : 'طلب شارة التوثيق'),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    TrText('الحالة: ${_statusLabel(_data?['status']?.toString())}',
                                      style: TextStyle(
                                        color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant),
                                      ),
                                    ),
                                    if (_data?['expires_at'] != null)
                                      TrText('ينتهي: ${_data!['expires_at']}',
                                        style: TextStyle(
                                          color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant),
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (subjectType == null) ...[
                          const SizedBox(height: 14),
                          _card(
                            'غير متاح لهذا الحساب',
                            _data?['message']?.toString() ??
                                'التوثيق متاح للمهندسين وملاك المكاتب.'.tr(),
                          ),
                        ],
                        if (checks.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF0D1B31) : Theme.of(context).colorScheme.surface),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? Color(0x1AFFFFFF) : Theme.of(context).dividerColor)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const TrText('شروط الأهلية',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 10),
                                ...checks.entries.map(
                                  (entry) => Padding(
                                    padding: const EdgeInsets.only(bottom: 7),
                                    child: Row(
                                      children: [
                                        Icon(
                                          entry.value == true
                                              ? Icons.check_circle_rounded
                                              : entry.value == false
                                                  ? Icons.cancel_rounded
                                                  : Icons.info_outline_rounded,
                                          size: 18,
                                          color: entry.value == true
                                              ? AppColors.success
                                              : entry.value == false
                                                  ? AppColors.danger
                                                  : (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : AppColors.textSecondary),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            trUi(_checkLabel(entry.key)),
                                            style:
                                                const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (canApply) ...[
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: _openApplicationForm,
                            icon: const Icon(Icons.verified_user_outlined),
                            label: Text(trUi(subjectType == 'office'
                                ? 'طلب توثيق المكتب'
                                : 'طلب توثيق الحساب')),
                          ),
                        ],
                        if (canSubscribe) ...[
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            onPressed: _openSubscriptionForm,
                            icon: const Icon(Icons.workspace_premium_outlined),
                            label: const TrText('دفع اشتراك التوثيق'),
                          ),
                        ],
                        if (app != null) ...[
                          const SizedBox(height: 14),
                          _card(
                            'آخر طلب',
                            'الحالة: ${_statusLabel(app['status']?.toString())}\n'
                                'ملاحظة الإدارة: ${app['admin_note'] ?? '-'}',
                          ),
                        ],
                        if (subs.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _card(
                            'آخر اشتراكات التوثيق',
                            subs.take(5).map((e) {
                              final item =
                                  Map<String, dynamic>.from(e as Map);
                              return '${_statusLabel(item['status']?.toString())} • ${item['amount'] ?? '-'} ${item['currency'] ?? ''}';
                            }).join('\n'),
                          ),
                        ],
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _card(String title, String text) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF0D1B31) : AppColors.surface),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? Color(0x1AFFFFFF) : AppColors.borderSoft)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(trUi(title), style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(
              trUi(text),
              style: TextStyle(
                color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : AppColors.textSecondary),
                height: 1.7,
              ),
            ),
          ],
        ),
      );

  String _statusLabel(String? value) => switch (value) {
        'verified' => 'موثق'.tr(),
        'pending' => 'قيد المراجعة'.tr(),
        'under_review' => 'تحت المراجعة'.tr(),
        'approved_for_payment' => 'معتمد بانتظار الدفع'.tr(),
        'approved' => 'معتمد'.tr(),
        'rejected' => 'مرفوض'.tr(),
        'expired' => 'منتهي'.tr(),
        'not_available' => 'غير متاح'.tr(),
        'unverified' => 'غير موثق'.tr(),
        _ => value ?? '—',
      };

  String _checkLabel(String key) => switch (key) {
        'role' => 'نوع الحساب مهندس'.tr(),
        'rating' => 'التقييم المطلوب'.tr(),
        'reviews' => 'الحد الأدنى للتقييمات'.tr(),
        'portfolio' => 'الحد الأدنى للأعمال المنشورة'.tr(),
        'experience' => 'سنوات الخبرة المطلوبة'.tr(),
        'active' => 'المكتب فعال'.tr(),
        'operational_subscription' => 'اشتراك تشغيل المكتب ساري'.tr(),
        _ => key,
      };
}
