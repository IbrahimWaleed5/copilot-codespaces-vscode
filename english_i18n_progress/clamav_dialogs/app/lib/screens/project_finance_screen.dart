import 'dart:io';
import 'package:file_picker/file_picker.dart';

import 'package:flutter/material.dart';
import '../i18n/localized_text.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../services/app_feedback.dart';
import 'kyc_verification_screen.dart';
import '../theme/app_theme.dart';
import 'project_budget_screen.dart';
import 'project_engineer_allocations_screen.dart';

class ProjectFinanceScreen extends StatefulWidget {
  final int projectId;
  final String projectTitle;

  const ProjectFinanceScreen({
    super.key,
    required this.projectId,
    required this.projectTitle,
  });

  @override
  State<ProjectFinanceScreen> createState() => _ProjectFinanceScreenState();
}

class _ProjectFinanceScreenState extends State<ProjectFinanceScreen> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _detail;
  Map<String, dynamic>? _escrow;

  Map<String, dynamic> get _project => _map(_detail?['project']) ?? const {};
  Map<String, dynamic> get _permissions => _map(_detail?['permissions']) ?? const {};
  List<dynamic> get _installments => _project['installments'] is List ? List<dynamic>.from(_project['installments'] as List) : const [];

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
      final detail = await ApiService.fetchProjectDetail(widget.projectId);
      Map<String, dynamic>? escrow;
      try {
        escrow = await ApiService.fetchProjectEscrow(widget.projectId);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _escrow = escrow;
      });
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addInstallment() async {
    final draft = await _showInstallmentEditor();
    if (draft == null) return;

    await _run(() => ApiService.addProjectInstallment(
          projectId: widget.projectId,
          title: draft.title,
          percentage: draft.percentage,
          dueDate: _date(draft.dueDate),
        ));
  }

  Future<void> _editInstallment(Map<String, dynamic> installment) async {
    final dueDate = DateTime.tryParse(installment['due_date']?.toString() ?? '') ?? DateTime.now();
    final initialPercentage = double.tryParse(installment['percentage']?.toString() ?? '');

    final draft = await _showInstallmentEditor(
      editing: true,
      initialTitle: installment['title']?.toString() ?? '',
      initialPercentage: initialPercentage,
      initialDueDate: dueDate,
    );
    if (draft == null) return;

    await _run(() => ApiService.updateProjectInstallment(
          projectId: widget.projectId,
          installmentId: _int(installment['id']),
          title: draft.title,
          percentage: draft.percentage,
          dueDate: _date(draft.dueDate),
        ));
  }

  Future<_InstallmentDraft?> _showInstallmentEditor({
    bool editing = false,
    String initialTitle = '',
    double? initialPercentage,
    DateTime? initialDueDate,
  }) async {
    final title = TextEditingController(text: initialTitle);
    final percentage = TextEditingController(
      text: initialPercentage == null
          ? ''
          : initialPercentage.toStringAsFixed(
              initialPercentage.truncateToDouble() == initialPercentage ? 0 : 2,
            ),
    );
    DateTime due = initialDueDate ?? DateTime.now().add(const Duration(days: 7));
    String? validationError;

    final scheduledPercentage = _installments
        .where((raw) => raw is Map && (raw['status']?.toString() ?? '') != 'cancelled')
        .fold<double>(0, (sum, raw) => sum + (double.tryParse('${(raw as Map)['percentage']}') ?? 0));
    final remainingBeforeCurrent = editing && initialPercentage != null
        ? 100 - (scheduledPercentage - initialPercentage)
        : 100 - scheduledPercentage;

    final result = await showDialog<_InstallmentDraft>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: TrText(editing ? 'تعديل دفعة المشروع' : 'إضافة دفعة للمشروع'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (remainingBeforeCurrent >= 0) ...[
                      Text(
                        'النسبة المتاحة: ${remainingBeforeCurrent.clamp(0, 100).toStringAsFixed(2)}%'.tr(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    TextField(
                      controller: title,
                      maxLength: 255,
                      decoration: InputDecoration(labelText: 'عنوان الدفعة'.tr()),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: percentage,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'النسبة %'.tr(),
                        helperText: 'يتم احتساب مبلغ الدفعة تلقائيًا من قيمة المشروع.'.tr(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const TrText('تاريخ الاستحقاق'),
                      subtitle: Text(trUi(_date(due))),
                      trailing: const Icon(Icons.calendar_month_outlined),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: due,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (picked != null) setDialogState(() => due = picked);
                      },
                    ),
                    if (validationError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        trUi(validationError!),
                        style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const TrText('إلغاء'),
                ),
                FilledButton(
                  onPressed: () {
                    final pct = double.tryParse(percentage.text.trim().replaceAll(',', '.'));
                    if (title.text.trim().isEmpty) {
                      setDialogState(() => validationError = 'أدخل عنوان الدفعة.');
                      return;
                    }
                    if (pct == null || pct <= 0 || pct > 100) {
                      setDialogState(() => validationError = 'أدخل نسبة صحيحة بين 0.01 و100.');
                      return;
                    }
                    if (pct > remainingBeforeCurrent + 0.001) {
                      setDialogState(() => validationError = 'النسبة تتجاوز النسبة المتاحة في جدول المشروع.');
                      return;
                    }
                    Navigator.pop(
                      dialogContext,
                      _InstallmentDraft(
                        title: title.text.trim(),
                        percentage: pct,
                        dueDate: due,
                      ),
                    );
                  },
                  child: TrText(editing ? 'حفظ التعديلات' : 'إضافة'),
                ),
              ],
            );
          },
        ),
      ),
    );

    Future<void>.delayed(const Duration(milliseconds: 600), title.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), percentage.dispose);
    return result;
  }

  Future<void> _payInstallment(Map<String, dynamic> installment) async {
    setState(() => _busy = true);
    try {
      final info = await ApiService.fetchProjectInstallmentPaymentInfo(
        projectId: widget.projectId,
        installmentId: _int(installment['id']),
      );
      if (!mounted) return;

      final countries = List<Map<String, dynamic>>.from(
        (info['countries'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)),
      );
      if (countries.isEmpty) throw ApiException('لا توجد طرق دفع مفعلة.');

      String country = countries.any((c) => c['code'] == 'PS') ? 'PS' : countries.first['code'].toString();
      int? methodId;
      File? receipt;
      String? error;

      List<Map<String, dynamic>> methods() {
        final c = countries.firstWhere((e) => e['code'] == country, orElse: () => const {});
        return List<Map<String, dynamic>>.from(
          (c['methods'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)),
        );
      }

      String label(Map<String, dynamic> m) {
        final prefix = switch (m['type']?.toString()) {
          'wallet' => 'محفظة — ',
          'bank_transfer' => 'بنك — ',
          'debit_card' => 'بطاقة — ',
          _ => 'بوابة — ',
        };
        return '$prefix${m['label'] ?? ''}${m['enabled'] == false ? ' — غير متاح حاليًا' : ''}';
      }

      Map<String, dynamic>? selected() {
        for (final m in methods()) {
          if (int.tryParse('${m['id']}') == methodId) return m;
        }
        return null;
      }

      final enabledInitial = methods().where((m) => m['enabled'] != false).toList();
      methodId = enabledInitial.isEmpty ? null : int.tryParse('${enabledInitial.first['id']}');

      final ok = await showDialog<bool>(
        context: context,
        builder: (dc) => StatefulBuilder(
          builder: (context, setD) => AlertDialog(
            title: const TrText('دفع مستحق المشروع'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText('مرجع الدفع: ${installment['payment_reference'] ?? '-'}'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: country,
                    decoration: InputDecoration(labelText: 'الدولة / فئة الدفع'.tr()),
                    items: countries
                        .map((c) => DropdownMenuItem(value: c['code'].toString(), child: Text(trUi(c['name']?.toString() ?? c['code'].toString()))))
                        .toList(),
                    onChanged: (v) => setD(() {
                      country = v ?? country;
                      final enabled = methods().where((m) => m['enabled'] != false).toList();
                      methodId = enabled.isEmpty ? null : int.tryParse('${enabled.first['id']}');
                      receipt = null;
                      error = null;
                    }),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    value: methods().any((m) => int.tryParse('${m['id']}') == methodId) ? methodId : null,
                    decoration: InputDecoration(labelText: 'طريقة الدفع'.tr()),
                    items: methods()
                        .map((m) => DropdownMenuItem<int>(
                              value: int.tryParse('${m['id']}'),
                              enabled: m['enabled'] != false,
                              child: Text(trUi(label(m))),
                            ))
                        .toList(),
                    onChanged: (v) => setD(() {
                      methodId = v;
                      receipt = null;
                      error = null;
                    }),
                  ),
                  Builder(builder: (_) {
                    final m = selected();
                    if (m == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((m['provider_name']?.toString() ?? '').isNotEmpty) TrText('الجهة: ${m['provider_name']}'),
                          if ((m['account_name']?.toString() ?? '').isNotEmpty) TrText('المستفيد: ${m['account_name']}'),
                          if ((m['account_number']?.toString() ?? '').isNotEmpty) SelectableText('الحساب: ${m['account_number']}'.tr()),
                          if ((m['iban']?.toString() ?? '').isNotEmpty) SelectableText('IBAN: ${m['iban']}'),
                          if ((m['phone']?.toString() ?? '').isNotEmpty) SelectableText('رقم المحفظة: ${m['phone']}'.tr()),
                          TrText('العملة: ${m['currency'] ?? '-'}'),
                          if ((m['instructions']?.toString() ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(trUi(m['instructions'].toString()), style: TextStyle(fontSize: 12, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
                            ),
                        ],
                      ),
                    );
                  }),
                  if (selected()?['requires_receipt'] == true) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await FilePicker.pickFile(
                          type: FileType.custom,
                          allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
                        );
                        if (picked?.path != null) {
                          setD(() {
                            receipt = File(picked!.path!);
                            error = null;
                          });
                        }
                      },
                      icon: const Icon(Icons.receipt_long_rounded),
                      label: Text(trUi(receipt == null ? 'إرفاق الإيصال' : 'تغيير الإيصال')),
                    ),
                    if (receipt != null)
                      Text(trUi(receipt!.path.split(Platform.pathSeparator).last), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF67E8F9) : AppColors.cyan300))),
                  ],
                  if (country == 'SA')
                    Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: TrText('السعودية: بنك أو محفظة + إيصال إلزامي للمراجعة.', style: TextStyle(fontSize: 12, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
                    ),
                  if (country == 'PS')
                    Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: TrText('فلسطين: تظهر طرق الدفع القديمة التابعة لفلسطين كما كانت.', style: TextStyle(fontSize: 12, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
                    ),
                  if (country == 'GL')
                    Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: TrText('منصات دفع عالمية: تظهر البطاقات والمنصات التي تفعّلها الإدارة.', style: TextStyle(fontSize: 12, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
                    ),
                  if (error != null) Text(trUi(error!), style: const TextStyle(color: AppColors.red200)),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dc, false), child: const TrText('إلغاء')),
              FilledButton(
                onPressed: () {
                  final m = selected();
                  if (methodId == null || m == null) {
                    setD(() => error = 'اختر طريقة دفع مفعلة.');
                    return;
                  }
                  if (m['requires_receipt'] == true && receipt == null) {
                    setD(() => error = 'أرفق إيصال الدفع.');
                    return;
                  }
                  Navigator.pop(dc, true);
                },
                child: Text(trUi(selected()?['requires_receipt'] == true ? 'إرسال للمراجعة' : 'متابعة الدفع')),
              ),
            ],
          ),
        ),
      );

      if (ok != true || methodId == null) return;
      final result = await ApiService.initiateProjectInstallmentPayment(
        projectId: widget.projectId,
        installmentId: _int(installment['id']),
        countryCode: country,
        platformPaymentMethodId: methodId!,
        receipt: selected()?['requires_receipt'] == true ? receipt : null,
      );
      final checkoutUrl = result['checkout_url']?.toString() ?? '';
      if (result['mode']?.toString() == 'checkout' && checkoutUrl.isNotEmpty) {
        final uri = Uri.parse(checkoutUrl);
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          throw ApiException('تعذر فتح بوابة الدفع.');
        }
      } else if (mounted) {
        _snack(result['message']?.toString() ?? 'تم إرسال الدفعة للمراجعة.');
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
      if (mounted && e.message.contains('توثيق الهوية')) {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const KycVerificationScreen()));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadReceipt(Map<String, dynamic> installment) async {
    setState(() => _busy = true);
    try {
      final file = await ApiService.downloadProjectInstallmentReceipt(
        projectId: widget.projectId,
        installmentId: _int(installment['id']),
      );
      await OpenFilex.open(file.path);
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm(Map<String, dynamic> installment) => _run(
        () => ApiService.confirmProjectInstallment(
          projectId: widget.projectId,
          installmentId: _int(installment['id']),
        ),
      );

  Future<void> _reject(Map<String, dynamic> installment) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const TrText('رفض إيصال الدفعة'),
        content: TextField(controller: reason, minLines: 2, maxLines: 5, decoration: InputDecoration(labelText: 'سبب الرفض'.tr())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const TrText('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const TrText('رفض')),
        ],
      ),
    );
    if (ok != true || reason.text.trim().isEmpty) return;
    await _run(() => ApiService.rejectProjectInstallment(
          projectId: widget.projectId,
          installmentId: _int(installment['id']),
          reason: reason.text.trim(),
        ));
  }

  Future<void> _fundEscrow(Map<String, dynamic> installment) => _run(
        () => ApiService.fundProjectEscrow(
          projectId: widget.projectId,
          installmentId: _int(installment['id']),
        ),
      );

  Future<void> _releaseEscrow(Map<String, dynamic> escrow) async {
    final reason = TextEditingController(text: 'تم اعتماد التسليم وإطلاق المستحقات.');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const TrText('الإفراج عن الضمان'),
        content: TextField(controller: reason, minLines: 2, maxLines: 5, decoration: InputDecoration(labelText: 'سبب الإفراج'.tr())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const TrText('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const TrText('إفراج وتوزيع المستحقات')),
        ],
      ),
    );
    if (ok != true || reason.text.trim().length < 5) return;
    await _run(() => ApiService.releaseProjectEscrow(
          projectId: widget.projectId,
          escrowId: _int(escrow['id']),
          reason: reason.text.trim(),
        ));
  }

  Future<void> _setOfficePercentage() async {
    final controller = TextEditingController(text: _project['office_percentage']?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const TrText('نسبة المكتب من المشروع'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'نسبة المكتب %'.tr()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const TrText('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const TrText('حفظ')),
        ],
      ),
    );
    final pct = double.tryParse(controller.text.trim());
    if (ok != true || pct == null) return;
    await _run(() => ApiService.setProjectOfficePercentage(projectId: widget.projectId, percentage: pct));
  }

  Future<void> _run(Future<String> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final message = await action();
      if (!mounted) return;
      _snack(message);
      await _load();
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message) => AppFeedback.auto(message);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: const TrText('مالية المشروع'),
          actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded))],
        ),
        floatingActionButton: _permissions['can_manage_installments'] == true
            ? FloatingActionButton.extended(
                onPressed: _busy ? null : _addInstallment,
                icon: const Icon(Icons.add_rounded),
                label: const TrText('دفعة جديدة'),
              )
            : null,
        body: _body(),
      ),
    );
  }

  Widget _body() {
    if (_loading && _detail == null) return const Center(child: CircularProgressIndicator());
    if (_error != null && _detail == null) return Center(child: Text(trUi(_error!)));

    final isFinancial = _permissions['is_admin'] == true || _permissions['is_financial_manager'] == true;
    final isCustomer = _permissions['is_customer'] == true;
    final canManageInstallments = _permissions['can_manage_installments'] == true;
    final escrows = _escrow?['escrows'] is List ? List<dynamic>.from(_escrow!['escrows'] as List) : const <dynamic>[];
    final summary = _map(_escrow?['summary']) ?? const {};

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 95),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(17),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(trUi(_project['project_number']?.toString() ?? ''), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF67E8F9) : AppColors.cyan300), fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text(trUi(widget.projectTitle.isEmpty ? _project['title']?.toString() ?? 'المشروع' : widget.projectTitle), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                const SizedBox(height: 13),
                Wrap(spacing: 9, runSpacing: 9, children: [
                  _metric('قيمة المشروع', '${_project['agreed_price'] ?? '-'} ₪'),
                  _metric('الإغلاق المالي', _project['financial_status']?.toString() ?? 'open'),
                  if (_project['office_id'] != null) _metric('نسبة المكتب', '${_project['office_percentage'] ?? 0}%'),
                ]),
                if (_permissions['is_admin'] == true && _project['office_id'] != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(onPressed: _busy ? null : _setOfficePercentage, icon: const Icon(Icons.percent_rounded), label: const TrText('تحديد نسبة المكتب')),
                ],
                if (_permissions['can_manage_financials'] == true || _permissions['is_admin'] == true || _permissions['is_financial_manager'] == true) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ProjectBudgetScreen(projectId: widget.projectId, projectTitle: widget.projectTitle),
                    )),
                    icon: const Icon(Icons.account_balance_wallet_outlined),
                    label: const TrText('ميزانية المشروع والمصروفات'),
                  ),
                ],
                if (_permissions['is_admin'] == true || _permissions['is_office_manager'] == true) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ProjectEngineerAllocationsScreen(
                        projectId: widget.projectId,
                        projectTitle: widget.projectTitle,
                      ),
                    )),
                    icon: const Icon(Icons.engineering_outlined),
                    label: const TrText('نسب مهندسي المشروع'),
                  ),
                ],
              ]),
            ),
          ),
          const SizedBox(height: 18),
          _heading('جدول الدفعات', Icons.payments_outlined),
          const SizedBox(height: 8),
          if (_installments.isEmpty)
            Card(child: Padding(padding: EdgeInsets.all(18), child: TrText('لا توجد دفعات مسجلة بعد.', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant)))))
          else
            ..._installments.map((raw) => _installmentCard(
                  Map<String, dynamic>.from(raw as Map),
                  isCustomer,
                  isFinancial,
                  canManageInstallments,
                )),
          const SizedBox(height: 20),
          _heading('Escrow — حساب الضمان', Icons.shield_outlined),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 8, children: [
            _metric('محتجز', '${summary['held'] ?? 0} ₪'),
            _metric('تم الإفراج', '${summary['released'] ?? 0} ₪'),
          ]),
          const SizedBox(height: 9),
          if (escrows.isEmpty)
            Card(child: Padding(padding: EdgeInsets.all(18), child: TrText('لا توجد عمليات ضمان حتى الآن.', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant)))))
          else
            ...escrows.map((raw) => _escrowCard(Map<String, dynamic>.from(raw as Map), isFinancial)),
        ],
      ),
    );
  }

  Widget _installmentCard(
    Map<String, dynamic> item,
    bool isCustomer,
    bool isFinancial,
    bool canManageInstallments,
  ) {
    final status = item['status']?.toString() ?? '';
    final effective = _effectiveStatus(item);
    final hasReceipt = item['receipt_path']?.toString().isNotEmpty == true;
    final canPay = isCustomer && !['paid', 'escrow_funded', 'cancelled'].contains(status) && effective != 'upcoming';
    final canEdit = canManageInstallments && status == 'upcoming';

    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${item['installment_number'] ?? '-'} — ${item['title'] ?? 'دفعة'}'.tr(), style: const TextStyle(fontWeight: FontWeight.w800))),
            _statusBadge(effective),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 9, runSpacing: 8, children: [
            _metric('النسبة', '${item['percentage'] ?? '-'}%'),
            _metric('المبلغ', '${item['amount'] ?? '-'} ₪'),
            _metric('الاستحقاق', item['due_date']?.toString() ?? '-'),
          ]),
          if (item['rejection_reason']?.toString().isNotEmpty == true) ...[
            const SizedBox(height: 9),
            TrText('سبب الرفض: ${item['rejection_reason']}', style: const TextStyle(color: AppColors.red300, fontSize: 12)),
          ],
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (canEdit)
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _editInstallment(item),
                icon: const Icon(Icons.edit_outlined),
                label: const TrText('تعديل الدفعة'),
              ),
            if (canPay)
              OutlinedButton.icon(onPressed: _busy ? null : () => _payInstallment(item), icon: const Icon(Icons.payment_rounded), label: const TrText('دفع الدفعة')), 
            if (hasReceipt)
              OutlinedButton.icon(onPressed: _busy ? null : () => _downloadReceipt(item), icon: const Icon(Icons.visibility_outlined), label: const TrText('عرض الإيصال')),
            if (isFinancial && status == 'pending_verification') ...[
              FilledButton.icon(onPressed: _busy ? null : () => _confirm(item), icon: const Icon(Icons.check_rounded), label: const TrText('تأكيد مباشر')),
              OutlinedButton.icon(onPressed: _busy ? null : () => _fundEscrow(item), icon: const Icon(Icons.shield_outlined), label: const TrText('إيداع في Escrow')),
              TextButton.icon(onPressed: _busy ? null : () => _reject(item), icon: const Icon(Icons.close_rounded), label: const TrText('رفض')),
            ],
          ]),
        ]),
      ),
    );
  }

  Widget _escrowCard(Map<String, dynamic> item, bool isFinancial) {
    final installment = _map(item['installment']);
    final held = item['status']?.toString() == 'held';
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: TrText('ضمان #${item['id']} — دفعة ${installment?['installment_number'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w800))),
            _statusBadge(item['status']?.toString() ?? ''),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 9, runSpacing: 8, children: [
            _metric('المبلغ', '${item['amount'] ?? '-'} ₪'),
            _metric('المتبقي', '${item['remaining_amount'] ?? '-'} ₪'),
            _metric('العمولة', '${item['platform_commission_amount'] ?? 0} ₪'),
          ]),
          if (isFinancial && held) ...[
            const SizedBox(height: 10),
            FilledButton.icon(onPressed: _busy ? null : () => _releaseEscrow(item), icon: const Icon(Icons.lock_open_rounded), label: const TrText('الإفراج وتوزيع المستحقات')),
          ],
        ]),
      ),
    );
  }

  Widget _heading(String title, IconData icon) => Row(children: [
        Icon(icon, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan), size: 21),
        const SizedBox(width: 8),
        Text(trUi(title), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ]);

  Widget _metric(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: (Theme.of(context).brightness == Brightness.dark ? Color(0x0DFFFFFF) : AppColors.white05), borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(trUi(label), style: TextStyle(fontSize: 10, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : AppColors.textSecondary))),
          const SizedBox(height: 2),
          Text(trUi(value), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _statusBadge(String status) {
    final color = status == 'paid' || status == 'released'
        ? AppColors.success
        : status == 'pending_verification' || status == 'held'
            ? Colors.amber
            : status == 'cancelled'
                ? AppColors.danger
                : (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(30)),
      child: Text(trUi(_statusLabel(status)), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }

  String _statusLabel(String value) => switch (value) {
        'upcoming' => 'قادمة',
        'due' => 'مستحقة',
        'overdue' => 'متأخرة',
        'pending_verification' => 'قيد المراجعة',
        'paid' => 'مدفوعة',
        'escrow_funded' => 'في الضمان',
        'held' => 'محتجز',
        'released' => 'تم الإفراج',
        'cancelled' => 'ملغاة',
        _ => value,
      };

  String _effectiveStatus(Map<String, dynamic> item) {
    final status = item['status']?.toString() ?? '';
    if (['paid', 'escrow_funded', 'pending_verification', 'cancelled'].contains(status)) return status;
    final due = DateTime.tryParse(item['due_date']?.toString() ?? '');
    if (due == null) return 'upcoming';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(due.year, due.month, due.day);
    if (date.isBefore(today)) return 'overdue';
    if (date.isAtSameMomentAs(today)) return 'due';
    return 'upcoming';
  }

  String _date(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  Map<String, dynamic>? _map(dynamic value) => value is Map ? Map<String, dynamic>.from(value) : null;
  int _int(dynamic value) => value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;
}


class _InstallmentDraft {
  final String title;
  final double percentage;
  final DateTime dueDate;

  const _InstallmentDraft({
    required this.title,
    required this.percentage,
    required this.dueDate,
  });
}
