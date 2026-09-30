import 'dart:io';

import 'package:flutter/material.dart';
import '../i18n/localized_text.dart';
import 'package:open_filex/open_filex.dart';

import '../i18n/i18n.dart';
import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';

class AdminProfessionalVerificationScreen extends StatefulWidget {
  const AdminProfessionalVerificationScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<AdminProfessionalVerificationScreen> createState() =>
      _AdminProfessionalVerificationScreenState();
}

class _AdminProfessionalVerificationScreenState
    extends State<AdminProfessionalVerificationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchController = TextEditingController();
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _savingSettings = false;
  String? _error;
  String _status = '';
  String _subjectType = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this, initialIndex: widget.initialTab.clamp(0, 2));
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final result = await ApiService.fetchAdminProfessionalVerification(
        applicationStatus: _status,
        subjectType: _subjectType,
        query: _searchController.text,
      );
      if (!mounted) return;
      setState(() => _data = result);
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'تعذر تحميل إدارة التوثيق.'.tr());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _applications {
    final paginator = _data?['applications'];
    if (paginator is Map && paginator['data'] is List) {
      return (paginator['data'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  List<Map<String, dynamic>> get _subscriptions =>
      (_data?['subscriptions'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

  Map<String, dynamic> get _stats => Map<String, dynamic>.from(
        _data?['statistics'] as Map? ?? const <String, dynamic>{},
      );

  Map<String, dynamic> get _settings => Map<String, dynamic>.from(
        _data?['settings'] as Map? ?? const <String, dynamic>{},
      );

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(trUi(message)),
        backgroundColor: error ? AppColors.danger : AppColors.success,
      ),
    );
  }

  String _statusLabel(String? status) => (switch (status) {
        'pending' => 'بانتظار المراجعة',
        'under_review' => 'قيد المراجعة',
        'approved_for_payment' => 'معتمد للدفع',
        'approved' => 'معتمد',
        'verified' => 'موثق',
        'rejected' => 'مرفوض',
        'expired' => 'منتهي',
        _ => status ?? '—',
      }).tr();

  Color _statusColor(String? status) => switch (status) {
        'approved_for_payment' || 'approved' || 'verified' => AppColors.success,
        'rejected' || 'expired' => AppColors.danger,
        'pending' || 'under_review' => const Color(0xFFF59E0B),
        _ => (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : AppColors.textSecondary),
      };

  String _subjectName(Map<String, dynamic> item) {
    final office = item['office'];
    if (office is Map && office['name'] != null) return office['name'].toString();
    final user = item['user'];
    if (user is Map && user['name'] != null) return user['name'].toString();
    final payer = item['payer'];
    if (payer is Map && payer['name'] != null) return payer['name'].toString();
    final app = item['application'];
    if (app is Map) {
      final appOffice = app['office'];
      if (appOffice is Map && appOffice['name'] != null) {
        return appOffice['name'].toString();
      }
      final appUser = app['user'];
      if (appUser is Map && appUser['name'] != null) {
        return appUser['name'].toString();
      }
    }
    return item['subject_type']?.toString() == 'office' ? 'مكتب هندسي' : 'مهندس';
  }

  Future<void> _openApplicationFile(int applicationId, String type) async {
    try {
      _snack('جاري تنزيل المستند...');
      final file = await ApiService.downloadAdminProfessionalVerificationApplicationFile(
        applicationId: applicationId,
        type: type,
      );
      if (!mounted) return;
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        _snack('تم تنزيل المستند لكن تعذر فتحه على الجهاز.', error: true);
      }
    } on ApiException catch (e) {
      _snack(e.message, error: true);
    }
  }

  Future<void> _openReceipt(int subscriptionId) async {
    try {
      _snack('جاري تنزيل إيصال الدفع...');
      final File file = await ApiService.downloadAdminProfessionalVerificationReceipt(
        subscriptionId: subscriptionId,
      );
      if (!mounted) return;
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        _snack('تم تنزيل الإيصال لكن تعذر فتحه على الجهاز.', error: true);
      }
    } on ApiException catch (e) {
      _snack(e.message, error: true);
    }
  }

  Future<String?> _askText({
    required String title,
    required String label,
    bool mustFill = false,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: AlertDialog(
          title: Text(trUi(title)),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: InputDecoration(labelText: trUiN(label)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const TrText('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (mustFill && value.isEmpty) return;
                Navigator.pop(context, value);
              },
              child: const TrText('تأكيد'),
            ),
          ],
        ),
      ),
    );
    // ننتظر انتهاء حركة إغلاق الـDialog قبل التخلص من Controller.
    await Future<void>.delayed(const Duration(milliseconds: 320));
    Future<void>.delayed(const Duration(milliseconds: 600), controller.dispose);
    return result;
  }

  Future<void> _reviewApplication(
    Map<String, dynamic> application,
    String decision,
  ) async {
    final id = (application['id'] as num?)?.toInt();
    if (id == null) return;
    String? reason;
    String? note;
    if (decision == 'reject') {
      reason = await _askText(
        title: 'رفض طلب التوثيق',
        label: 'سبب الرفض *',
        mustFill: true,
      );
      if (reason == null || reason.isEmpty) return;
    } else {
      note = await _askText(
        title: 'اعتماد المستندات',
        label: 'ملاحظة للإدارة/المستخدم (اختياري)',
      );
      if (note == null) return;
    }
    try {
      final message = await ApiService.reviewAdminProfessionalVerificationApplication(
        applicationId: id,
        decision: decision,
        adminNote: note,
        rejectionReason: reason,
      );
      _snack(message);
      await _load();
    } on ApiException catch (e) {
      _snack(e.message, error: true);
    }
  }

  Future<void> _reviewSubscription(
    Map<String, dynamic> subscription,
    String decision,
  ) async {
    final id = (subscription['id'] as num?)?.toInt();
    if (id == null) return;
    String? reason;
    if (decision == 'reject') {
      reason = await _askText(
        title: 'رفض دفعة التوثيق',
        label: 'سبب الرفض *',
        mustFill: true,
      );
      if (reason == null || reason.isEmpty) return;
    }
    try {
      final message = await ApiService.reviewAdminProfessionalVerificationSubscription(
        subscriptionId: id,
        decision: decision,
        rejectionReason: reason,
      );
      _snack(message);
      await _load();
    } on ApiException catch (e) {
      _snack(e.message, error: true);
    }
  }

  Future<void> _editSettings() async {
    final settings = _settings;
    if (settings.isEmpty) return;

    final minRating = TextEditingController(text: '${settings['engineer_min_rating'] ?? 0}');
    final maxRating = TextEditingController(text: '${settings['engineer_max_rating'] ?? 5}');
    final minReviews = TextEditingController(text: '${settings['engineer_min_reviews'] ?? 0}');
    final minWorks = TextEditingController(text: '${settings['engineer_min_portfolio_works'] ?? 0}');
    final minYears = TextEditingController(text: '${settings['engineer_min_experience_years'] ?? 0}');
    final engineerFee = TextEditingController(text: '${settings['engineer_monthly_fee'] ?? 0}');
    final officeFee = TextEditingController(text: '${settings['office_monthly_fee'] ?? 0}');
    final currency = TextEditingController(text: '${settings['currency'] ?? 'USD'}');
    final gateway = TextEditingController(text: '${settings['online_gateway_name'] ?? ''}');
    bool bank = settings['bank_transfer_enabled'] == true || settings['bank_transfer_enabled'] == 1;
    bool wallet = settings['wallet_enabled'] == true || settings['wallet_enabled'] == 1;
    bool online = settings['online_gateway_enabled'] == true || settings['online_gateway_enabled'] == 1;

    final shouldSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF0D1B31) : Theme.of(context).colorScheme.surface),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Directionality(
          textDirection: AppLanguage.instance.textDirection,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                18,
                16,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const TrText('إعدادات التوثيق الاحترافي', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 16),
                    _responsivePair(
                      TextField(controller: minRating, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'أقل تقييم'.tr())),
                      TextField(controller: maxRating, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'أعلى تقييم'.tr())),
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: minReviews, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'الحد الأدنى للتقييمات'.tr())),
                    const SizedBox(height: 10),
                    TextField(controller: minWorks, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'الحد الأدنى للأعمال المعتمدة'.tr())),
                    const SizedBox(height: 10),
                    TextField(controller: minYears, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'الحد الأدنى لسنوات الخبرة'.tr())),
                    const SizedBox(height: 10),
                    _responsivePair(
                      TextField(controller: engineerFee, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'اشتراك المهندس'.tr())),
                      TextField(controller: officeFee, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'اشتراك المكتب'.tr())),
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: currency, decoration: InputDecoration(labelText: 'العملة'.tr())),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(title: const TrText('تحويل بنكي'), value: bank, onChanged: (v) => setSheetState(() => bank = v)),
                    SwitchListTile.adaptive(title: const TrText('محفظة إلكترونية'), value: wallet, onChanged: (v) => setSheetState(() => wallet = v)),
                    SwitchListTile.adaptive(title: const TrText('بوابة دفع إلكترونية'), value: online, onChanged: (v) => setSheetState(() => online = v)),
                    if (online) ...[
                      const SizedBox(height: 8),
                      TextField(controller: gateway, decoration: InputDecoration(labelText: 'اسم بوابة الدفع'.tr())),
                    ],
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      icon: const Icon(Icons.save_outlined),
                      label: const TrText('حفظ الإعدادات'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (shouldSave == true) {
      final parsedMinRating = double.tryParse(minRating.text);
      final parsedMaxRating = double.tryParse(maxRating.text);
      final parsedReviews = int.tryParse(minReviews.text);
      final parsedWorks = int.tryParse(minWorks.text);
      final parsedYears = int.tryParse(minYears.text);
      final parsedEngineerFee = double.tryParse(engineerFee.text);
      final parsedOfficeFee = double.tryParse(officeFee.text);
      if ([parsedMinRating, parsedMaxRating, parsedReviews, parsedWorks, parsedYears, parsedEngineerFee, parsedOfficeFee].any((e) => e == null)) {
        _snack('تحقق من القيم الرقمية في إعدادات التوثيق.', error: true);
      } else if (parsedMinRating! > parsedMaxRating!) {
        _snack('الحد الأدنى للتقييم يجب أن يكون أقل من أو يساوي الحد الأعلى.', error: true);
      } else {
        setState(() => _savingSettings = true);
        try {
          final message = await ApiService.updateAdminProfessionalVerificationSettings(
            engineerMinRating: parsedMinRating!,
            engineerMaxRating: parsedMaxRating!,
            engineerMinReviews: parsedReviews!,
            engineerMinPortfolioWorks: parsedWorks!,
            engineerMinExperienceYears: parsedYears!,
            engineerMonthlyFee: parsedEngineerFee!,
            officeMonthlyFee: parsedOfficeFee!,
            currency: currency.text.trim().isEmpty ? 'USD' : currency.text.trim(),
            bankTransferEnabled: bank,
            walletEnabled: wallet,
            onlineGatewayEnabled: online,
            onlineGatewayName: gateway.text,
          );
          _snack(message);
          await _load();
        } on ApiException catch (e) {
          _snack(e.message, error: true);
        } finally {
          if (mounted) setState(() => _savingSettings = false);
        }
      }
    }

    final controllers = [minRating, maxRating, minReviews, minWorks, minYears, engineerFee, officeFee, currency, gateway];
    await Future<void>.delayed(const Duration(milliseconds: 380));
    for (final controller in controllers) {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: Text('إدارة التوثيق الاحترافي'.tr()),
          actions: [
            IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
          ],
          bottom: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabs: [
              Tab(text: 'الطلبات'.tr(), icon: const Icon(Icons.fact_check_outlined)),
              Tab(text: 'الدفعات'.tr(), icon: const Icon(Icons.payments_outlined)),
              Tab(text: 'الإعدادات'.tr(), icon: const Icon(Icons.tune_rounded)),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : Column(
                    children: [
                      _buildStats(),
                      Expanded(
                        child: TabBarView(
                          controller: _tabs,
                          children: [
                            _buildApplications(),
                            _buildSubscriptions(),
                            _buildSettings(),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildStats() {
    final items = [
      ('طلبات معلقة', _stats['pending_applications'], Icons.pending_actions_rounded),
      ('بانتظار الدفع', _stats['approved_for_payment'], Icons.payments_outlined),
      ('دفعات معلقة', _stats['pending_subscriptions'], Icons.receipt_long_outlined),
      ('مهندسون موثقون', _stats['verified_engineers'], Icons.engineering_rounded),
      ('مكاتب موثقة', _stats['verified_offices'], Icons.apartment_rounded),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final available = constraints.maxWidth;
          final columns = available < 360 ? 2 : (available < 650 ? 3 : 5);
          final spacing = 8.0;
          final width = (available - (spacing * (columns - 1))) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final item in items)
                SizedBox(
                  width: width,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 94),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF0D1B31) : Theme.of(context).colorScheme.surface),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(item.$3, size: 18, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan)),
                        const SizedBox(height: 6),
                        Text(
                          '${item.$2 ?? 0}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          trUi(item.$1),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9.5,
                            height: 1.2,
                            color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildApplications() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _load(),
            decoration: InputDecoration(
              labelText: 'بحث بالاسم أو البريد'.tr(),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _load),
            ),
          ),
          const SizedBox(height: 10),
          _responsivePair(
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _subjectType,
              decoration: InputDecoration(labelText: 'النوع'.tr()),
              items: const [
                DropdownMenuItem(value: '', child: TrText('الكل')),
                DropdownMenuItem(value: 'engineer', child: TrText('مهندس')),
                DropdownMenuItem(value: 'office', child: TrText('مكتب')),
              ],
              onChanged: (v) {
                setState(() => _subjectType = v ?? '');
                _load();
              },
            ),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _status,
              decoration: InputDecoration(labelText: 'الحالة'.tr()),
              items: const [
                DropdownMenuItem(value: '', child: TrText('الكل')),
                DropdownMenuItem(value: 'pending', child: TrText('معلق')),
                DropdownMenuItem(value: 'under_review', child: TrText('قيد المراجعة')),
                DropdownMenuItem(value: 'approved_for_payment', child: TrText('معتمد للدفع')),
                DropdownMenuItem(value: 'rejected', child: TrText('مرفوض')),
              ],
              onChanged: (v) {
                setState(() => _status = v ?? '');
                _load();
              },
            ),
          ),
          const SizedBox(height: 14),
          if (_applications.isEmpty)
            _EmptyState(text: 'لا توجد طلبات توثيق مطابقة.'.tr())
          else
            ..._applications.map(_applicationCard),
        ],
      ),
    );
  }

  Widget _applicationCard(Map<String, dynamic> item) {
    final id = (item['id'] as num?)?.toInt();
    final status = item['status']?.toString();
    final type = item['subject_type']?.toString();
    final files = Map<String, dynamic>.from(item['files'] as Map? ?? const {});
    final canReview = status == 'pending' || status == 'under_review';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan).withValues(alpha: .12),
                  child: Icon(type == 'office' ? Icons.apartment_rounded : Icons.engineering_rounded, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(trUi(_subjectName(item)), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                    Text(trUi(type == 'office' ? 'توثيق مكتب هندسي' : 'توثيق مهندس'), style: TextStyle(fontSize: 11, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
                  ]),
                ),
                _StatusChip(text: _statusLabel(status), color: _statusColor(status)),
              ],
            ),
            const SizedBox(height: 12),
            if (type == 'engineer')
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _MetaChip('التقييم', '${item['rating_snapshot'] ?? '—'}'),
                  _MetaChip('التقييمات', '${item['reviews_count_snapshot'] ?? 0}'),
                  _MetaChip('الأعمال', '${item['approved_works_snapshot'] ?? 0}'),
                  _MetaChip('الخبرة', '${item['experience_years'] ?? 0} سنة'),
                ],
              ),
            if ((item['applicant_note']?.toString().trim().isNotEmpty ?? false)) ...[
              const SizedBox(height: 10),
              TrText('ملاحظة مقدم الطلب: ${item['applicant_note']}', style: TextStyle(fontSize: 11, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
            ],
            if ((item['rejection_reason']?.toString().trim().isNotEmpty ?? false)) ...[
              const SizedBox(height: 8),
              TrText('سبب الرفض: ${item['rejection_reason']}', style: const TextStyle(fontSize: 11, color: AppColors.danger)),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final entry in files.entries)
                  if (entry.value == true && id != null)
                    OutlinedButton.icon(
                      onPressed: () => _openApplicationFile(id, entry.key),
                      icon: const Icon(Icons.description_outlined, size: 17),
                      label: Text(trUi(_fileLabel(entry.key))),
                    ),
              ],
            ),
            if (canReview) ...[
              const Divider(height: 24),
              _responsivePair(
                FilledButton.icon(
                  onPressed: () => _reviewApplication(item, 'approve'),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const TrText('اعتماد للدفع'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _reviewApplication(item, 'reject'),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const TrText('رفض'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fileLabel(String key) => switch (key) {
        'identity' => 'الهوية',
        'degree' => 'الشهادة',
        'syndicate' => 'النقابة',
        'experience' => 'الخبرة',
        'registration' => 'السجل',
        'license' => 'الترخيص',
        _ => 'المستند',
      };

  Widget _buildSubscriptions() {
    final pending = _subscriptions.where((e) => e['status']?.toString() == 'pending').toList();
    final reviewed = _subscriptions.where((e) => e['status']?.toString() != 'pending').toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          const TrText('دفعات بانتظار المراجعة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          if (pending.isEmpty)
            _EmptyState(text: 'لا توجد دفعات توثيق معلقة.'.tr())
          else
            ...pending.map(_subscriptionCard),
          if (reviewed.isNotEmpty) ...[
            const SizedBox(height: 20),
            const TrText('السجل الأخير', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            ...reviewed.take(30).map(_subscriptionCard),
          ],
        ],
      ),
    );
  }

  Widget _subscriptionCard(Map<String, dynamic> item) {
    final id = (item['id'] as num?)?.toInt();
    final status = item['status']?.toString();
    final pending = status == 'pending';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(trUi(_subjectName(item)), style: const TextStyle(fontWeight: FontWeight.w900))),
              _StatusChip(text: _statusLabel(status), color: _statusColor(status)),
            ]),
            const SizedBox(height: 8),
            Text(
              '${item['amount'] ?? 0} ${item['currency'] ?? ''} • ${item['payment_method'] ?? '—'}',
              style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            if ((item['payment_reference']?.toString().isNotEmpty ?? false))
              TrText('مرجع الدفع: ${item['payment_reference']}', style: TextStyle(fontSize: 11, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
            const SizedBox(height: 10),
            if (item['has_receipt'] == true && id != null)
              OutlinedButton.icon(
                onPressed: () => _openReceipt(id),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const TrText('فتح إيصال الدفع'),
              ),
            if (pending) ...[
              const SizedBox(height: 8),
              _responsivePair(
                FilledButton(
                  onPressed: () => _reviewSubscription(item, 'approve'),
                  child: const TrText('اعتماد وتفعيل الشارة'),
                ),
                OutlinedButton(
                  onPressed: () => _reviewSubscription(item, 'reject'),
                  child: const TrText('رفض الدفعة'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _responsivePair(Widget first, Widget second) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 430) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              first,
              const SizedBox(height: 10),
              second,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 8),
            Expanded(child: second),
          ],
        );
      },
    );
  }

  Widget _buildSettings() {
    final s = _settings;
    if (s.isEmpty) return _EmptyState(text: 'إعدادات التوثيق غير متاحة.'.tr());
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.verified_user_rounded, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan)),
                  SizedBox(width: 8),
                  Text('شروط توثيق المهندس'.tr(), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                ]),
                const SizedBox(height: 14),
                _SettingRow('نطاق التقييم', '${s['engineer_min_rating'] ?? 0} – ${s['engineer_max_rating'] ?? 5}'),
                _SettingRow('أقل عدد تقييمات', '${s['engineer_min_reviews'] ?? 0}'),
                _SettingRow('أقل أعمال معتمدة', '${s['engineer_min_portfolio_works'] ?? 0}'),
                _SettingRow('أقل خبرة', '${s['engineer_min_experience_years'] ?? 0} سنوات'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الاشتراكات وطرق الدفع'.tr(), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 14),
                _SettingRow('اشتراك المهندس الشهري', '${s['engineer_monthly_fee'] ?? 0} ${s['currency'] ?? ''}'),
                _SettingRow('اشتراك المكتب الشهري', '${s['office_monthly_fee'] ?? 0} ${s['currency'] ?? ''}'),
                _SettingRow('تحويل بنكي', _yesNo(s['bank_transfer_enabled'])),
                _SettingRow('محفظة', _yesNo(s['wallet_enabled'])),
                _SettingRow('بوابة إلكترونية', _yesNo(s['online_gateway_enabled'])),
                if ((s['online_gateway_name']?.toString().isNotEmpty ?? false))
                  _SettingRow('اسم البوابة', s['online_gateway_name'].toString()),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _savingSettings ? null : _editSettings,
          icon: _savingSettings
              ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.tune_rounded),
          label: Text('تعديل الشروط والأسعار'.tr()),
        ),
      ],
    );
  }

  String _yesNo(dynamic value) => (value == true || value == 1 ? 'مفعّل' : 'غير مفعّل').tr();
}

class _StatusChip extends StatelessWidget {
  final String text;
  final Color color;
  const _StatusChip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
        child: Text(trUi(text), style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: color)),
      );
}

class _MetaChip extends StatelessWidget {
  final String label;
  final String value;
  const _MetaChip(this.label, this.value);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .04), borderRadius: BorderRadius.circular(10)),
        child: Text('$label: $value', style: TextStyle(fontSize: 10.5, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : AppColors.textSecondary))),
      );
}

class _SettingRow extends StatelessWidget {
  final String label;
  final String value;
  const _SettingRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                trUi(label),
                style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : AppColors.textSecondary)),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                trUi(value),
                textAlign: TextAlign.left,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );
}

class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 34),
        child: Center(child: Text(text.tr(), textAlign: TextAlign.center, style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : AppColors.textSecondary)))),
      );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded, size: 42, color: AppColors.danger),
            const SizedBox(height: 10),
            Text(trUi(message), textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: const TrText('إعادة المحاولة')),
          ]),
        ),
      );
}
