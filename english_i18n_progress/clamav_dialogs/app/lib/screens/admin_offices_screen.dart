import 'package:flutter/material.dart';
import '../i18n/localized_text.dart';
import 'package:open_filex/open_filex.dart';

import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';
import 'engineering_offices_screen.dart';

class AdminOfficesScreen extends StatefulWidget {
  const AdminOfficesScreen({super.key});

  @override
  State<AdminOfficesScreen> createState() => _AdminOfficesScreenState();
}

class _AdminOfficesScreenState extends State<AdminOfficesScreen> {
  Map<String, dynamic>? _applications;
  Map<String, dynamic>? _subscriptions;
  List<dynamic> _offices = const [];
  Map<String, dynamic>? _assignments;
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
      final applications = await ApiService.fetchAdminOfficeApplications();
      final subscriptions = await ApiService.fetchAdminOfficeSubscriptions();
      final offices = await ApiService.fetchAdminOffices();
      final assignments = await ApiService.fetchAdminConsultationOfficeAssignments();
      if (!mounted) return;
      setState(() {
        _applications = applications;
        _subscriptions = subscriptions;
        _offices = offices;
        _assignments = assignments;
      });
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    AppFeedback.auto(message);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            title: const TrText('إدارة المكاتب الهندسية'),
            bottom: TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'طلبات المكاتب'.tr()),
                Tab(text: 'الاشتراكات'.tr()),
                Tab(text: 'المكاتب'.tr()),
                Tab(text: 'تحويل الاستشارات'.tr()),
              ],
            ),
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(trUi(_error!), textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const TrText('إعادة المحاولة')),
                          ],
                        ),
                      ),
                    )
                  : TabBarView(
                      children: [
                        _ApplicationsTab(data: _applications!, reload: _load, toast: _toast),
                        _SubscriptionsTab(data: _subscriptions!, reload: _load, toast: _toast),
                        _OfficesTab(offices: _offices, reload: _load, toast: _toast),
                        _AssignmentsTab(data: _assignments!, reload: _load, toast: _toast),
                      ],
                    ),
        ),
      ),
    );
  }
}

class _ApplicationsTab extends StatelessWidget {
  final Map<String, dynamic> data;
  final Future<void> Function() reload;
  final void Function(String) toast;

  const _ApplicationsTab({required this.data, required this.reload, required this.toast});

  @override
  Widget build(BuildContext context) {
    final items = List<dynamic>.from(data['data'] as List? ?? const []);
    final stats = Map<String, dynamic>.from(data['statistics'] as Map? ?? const {});
    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _StatsRow(values: [('معلق', stats['pending']), ('مقبول', stats['approved']), ('مرفوض', stats['rejected'])]),
          const SizedBox(height: 12),
          if (items.isEmpty)
            _Empty(text: 'لا توجد طلبات مكاتب.'.tr())
          else
            ...items.map((raw) {
              final item = Map<String, dynamic>.from(raw as Map);
              final applicant = item['applicant'] as Map?;
              final pending = item['status']?.toString() == 'pending';
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(trUi(item['office_name']?.toString() ?? 'مكتب'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
                          _Badge(text: _status(item['status']?.toString()), color: pending ? const Color(0xFFF59E0B) : item['status'] == 'approved' ? AppColors.success : AppColors.danger),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(trUi([
                        applicant?['name']?.toString(),
                        item['city']?.toString(),
                        item['country']?.toString(),
                        item['commercial_registration']?.toString(),
                      ].where((e) => e != null && e.isNotEmpty).join(' • ')), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 11)),
                      if (pending) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => _approveApplication(context, item, reload, toast),
                                icon: const Icon(Icons.check_rounded),
                                label: const TrText('اعتماد'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _rejectApplication(context, item, reload, toast),
                                icon: const Icon(Icons.close_rounded),
                                label: const TrText('رفض'),
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
    );
  }

  Future<void> _approveApplication(
    BuildContext context,
    Map<String, dynamic> item,
    Future<void> Function() reload,
    void Function(String) toast,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: AlertDialog(
          title: TrText('اعتماد ${item['office_name'] ?? 'المكتب'}'),
          content: const TrText('عند اعتماد المكتب سيتم تفعيله وبدء تجربة مجانية لمدة 10 أيام تلقائيًا. لا يلزم تحديد قيمة أو مدة اشتراك عند الموافقة.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const TrText('إلغاء'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.verified_outlined),
              label: const TrText('اعتماد وبدء التجربة'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      final message = await ApiService.reviewAdminOfficeApplication(
        applicationId: int.parse(item['id'].toString()),
        decision: 'approve',
      );
      toast(message);
      await reload();
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      toast(e.message);
    }
  }

  Future<void> _rejectApplication(BuildContext context, Map<String, dynamic> item, Future<void> Function() reload, void Function(String) toast) async {
    final reason = await _askText(context, 'سبب رفض طلب المكتب', maxLines: 3);
    if (reason == null || reason.trim().isEmpty) return;
    try {
      final message = await ApiService.reviewAdminOfficeApplication(
        applicationId: int.parse(item['id'].toString()),
        decision: 'reject',
        rejectionReason: reason.trim(),
      );
      toast(message);
      await reload();
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      toast(e.message);
    }
  }
}

class _SubscriptionsTab extends StatelessWidget {
  final Map<String, dynamic> data;
  final Future<void> Function() reload;
  final void Function(String) toast;

  const _SubscriptionsTab({required this.data, required this.reload, required this.toast});

  @override
  Widget build(BuildContext context) {
    final items = List<dynamic>.from(data['data'] as List? ?? const []);
    final stats = Map<String, dynamic>.from(data['statistics'] as Map? ?? const {});
    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _StatsRow(values: [('مراجعة', stats['under_review']), ('فعال', stats['active']), ('مرفوض', stats['rejected'])]),
          const SizedBox(height: 12),
          if (items.isEmpty)
            _Empty(text: 'لا توجد اشتراكات.'.tr())
          else
            ...items.map((raw) {
              final item = Map<String, dynamic>.from(raw as Map);
              final office = item['office'] as Map?;
              final pending = item['status']?.toString() == 'under_review';
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(trUi(office?['name']?.toString() ?? 'مكتب'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15))),
                          _Badge(text: _subscriptionStatus(item['status']?.toString()), color: pending ? const Color(0xFFF59E0B) : item['status'] == 'active' ? AppColors.success : AppColors.danger),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('${item['amount'] ?? 0} ${item['currency'] ?? ''} • ${_officePaymentMethodLabel(item['payment_method']?.toString())}', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
                      if ((item['receipt_path']?.toString() ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _openReceipt(context, int.parse(item['id'].toString()), toast),
                            icon: const Icon(Icons.receipt_long_outlined),
                            label: const TrText('عرض إيصال الاشتراك'),
                          ),
                        ),
                      ],
                      if (pending) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: () => _review(context, item, true, reload, toast),
                                child: const TrText('اعتماد'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _review(context, item, false, reload, toast),
                                child: const TrText('رفض'),
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
    );
  }

  Future<void> _openReceipt(BuildContext context, int subscriptionId, void Function(String) toast) async {
    try {
      final file = await ApiService.downloadAdminOfficeSubscriptionReceipt(subscriptionId: subscriptionId);
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        toast(result.message.isEmpty ? 'تعذر فتح إيصال الاشتراك.' : result.message);
      }
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      toast(e.message);
    } catch (_) {
      toast('تعذر فتح إيصال الاشتراك.');
    }
  }

  Future<void> _review(BuildContext context, Map<String, dynamic> item, bool approve, Future<void> Function() reload, void Function(String) toast) async {
    if (!approve) {
      final reason = await _askText(context, 'سبب رفض الاشتراك', maxLines: 3);
      if (reason == null || reason.trim().isEmpty) return;
      try {
        final message = await ApiService.reviewAdminOfficeSubscription(
          subscriptionId: int.parse(item['id'].toString()),
          decision: 'reject',
          rejectionReason: reason.trim(),
        );
        toast(message);
        await reload();
      } on ApiException catch (e) {
        AppFeedback.error(e.message);
        toast(e.message);
      }
      return;
    }

    int duration = 1;
    String unit = 'month';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => Directionality(
          textDirection: AppLanguage.instance.textDirection,
          child: AlertDialog(
            title: const TrText('اعتماد الاشتراك'),
            content: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: duration,
                    decoration: InputDecoration(labelText: 'المدة'.tr()),
                    items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
                    onChanged: (value) {
                      if (value != null) setState(() => duration = value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: unit,
                    decoration: InputDecoration(labelText: 'الوحدة'.tr()),
                    items: const [
                      DropdownMenuItem(value: 'day', child: TrText('يوم')),
                      DropdownMenuItem(value: 'month', child: TrText('شهر')),
                      DropdownMenuItem(value: 'year', child: TrText('سنة')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => unit = value);
                    },
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const TrText('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const TrText('اعتماد')),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true) {
      try {
        final message = await ApiService.reviewAdminOfficeSubscription(
          subscriptionId: int.parse(item['id'].toString()),
          decision: 'approve',
          durationValue: duration,
          durationUnit: unit,
        );
        toast(message);
        await reload();
      } on ApiException catch (e) {
        AppFeedback.error(e.message);
        toast(e.message);
      }
    }
  }
}

class _OfficesTab extends StatelessWidget {
  final List<dynamic> offices;
  final Future<void> Function() reload;
  final void Function(String) toast;

  const _OfficesTab({required this.offices, required this.reload, required this.toast});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: offices.isEmpty
            ? [_Empty(text: 'لا توجد مكاتب مسجلة.'.tr())]
            : offices.map((raw) {
                final office = Map<String, dynamic>.from(raw as Map);
                final owner = office['owner'] as Map?;
                final plan = office['saas_plan'] as Map?;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    onTap: () {
                      final slug = office['slug']?.toString() ?? '';
                      if (slug.isEmpty) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => OfficeDetailScreen(slug: slug),
                        ),
                      );
                    },
                    leading: const CircleAvatar(child: Icon(Icons.apartment_rounded)),
                    title: Text(trUi(office['name']?.toString() ?? 'مكتب'), style: const TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text(trUi([
                      owner?['name']?.toString(),
                      office['city']?.toString(),
                      'الباقة: ${plan?['name'] ?? 'غير محددة'}',
                      '${office['members_count'] ?? 0} عضو',
                      '${office['consultations_count'] ?? 0} استشارة',
                    ].where((e) => e != null && e.isNotEmpty).join(' • '))),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'plan') {
                          _changePlan(context, office, reload, toast);
                          return;
                        }
                        _changeStatus(context, office, value, reload, toast);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'plan', child: TrText('تغيير الباقة')),
                        PopupMenuDivider(),
                        PopupMenuItem(value: 'active', child: TrText('تفعيل')),
                        PopupMenuItem(value: 'suspended', child: TrText('إيقاف')),
                        PopupMenuItem(value: 'closed', child: TrText('إغلاق')),
                      ],
                    ),
                  ),
                );
              }).toList(),
      ),
    );
  }

  Future<void> _changePlan(BuildContext context, Map<String, dynamic> office, Future<void> Function() reload, void Function(String) toast) async {
    List<dynamic> plans;
    try {
      plans = await ApiService.fetchSaasPlans();
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      toast(e.message);
      return;
    }

    if (!context.mounted) return;
    if (plans.isEmpty) {
      toast('لا توجد باقات فعالة متاحة.');
      return;
    }

    final currentPlan = office['saas_plan'] as Map?;
    int? selectedId = int.tryParse(currentPlan?['id']?.toString() ?? '');
    selectedId ??= int.tryParse((plans.first as Map)['id']?.toString() ?? '');

    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => Directionality(
          textDirection: AppLanguage.instance.textDirection,
          child: AlertDialog(
            title: TrText('تغيير باقة ${office['name'] ?? 'المكتب'}'),
            content: SizedBox(
              width: 430,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TrText('يتم تطبيق حدود الباقة على المكتب مباشرة بعد الحفظ.',
                    style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 11),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    initialValue: selectedId,
                    decoration: InputDecoration(labelText: 'الباقة'.tr()),
                    items: plans.map((raw) {
                      final plan = Map<String, dynamic>.from(raw as Map);
                      final id = int.parse(plan['id'].toString());
                      final price = plan['is_custom'] == true
                          ? 'سعر مخصص'
                          : '\$${_formatPlanPrice(plan['monthly_price'])}/شهر';
                      return DropdownMenuItem<int>(
                        value: id,
                        child: Text('${plan['name'] ?? 'باقة'} — $price'.tr()),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => selectedId = value),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const TrText('إلغاء')),
              FilledButton(
                onPressed: selectedId == null ? null : () => Navigator.pop(dialogContext, selectedId),
                child: const TrText('حفظ الباقة'),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected == null) return;
    try {
      final officeSlug = office['slug']?.toString() ?? '';
      if (officeSlug.isEmpty) {
        toast('تعذر تحديد المكتب.');
        return;
      }
      final message = await ApiService.assignAdminOfficeSaasPlan(officeSlug: officeSlug, planId: selected);
      toast(message);
      await reload();
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      toast(e.message);
    }
  }

  static String _formatPlanPrice(dynamic value) {
    final number = num.tryParse(value?.toString() ?? '');
    if (number == null) return '—';
    return number % 1 == 0 ? number.toInt().toString() : number.toStringAsFixed(2);
  }

  Future<void> _changeStatus(BuildContext context, Map<String, dynamic> office, String status, Future<void> Function() reload, void Function(String) toast) async {
    String? reason;
    if (status != 'active') {
      reason = await _askText(context, status == 'suspended' ? 'سبب إيقاف المكتب' : 'سبب إغلاق المكتب', maxLines: 3);
      if (reason == null || reason.trim().isEmpty) return;
    }
    try {
      final message = await ApiService.updateAdminOfficeStatus(
        officeSlug: office['slug']?.toString() ?? '',
        status: status,
        reason: reason?.trim(),
      );
      toast(message);
      await reload();
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      toast(e.message);
    }
  }
}

class _AssignmentsTab extends StatelessWidget {
  final Map<String, dynamic> data;
  final Future<void> Function() reload;
  final void Function(String) toast;

  const _AssignmentsTab({required this.data, required this.reload, required this.toast});

  @override
  Widget build(BuildContext context) {
    final consultations = List<dynamic>.from(data['consultations'] as List? ?? const []);
    final offices = List<dynamic>.from(data['offices'] as List? ?? const []);
    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: consultations.isEmpty
            ? [_Empty(text: 'لا توجد استشارات قابلة للتحويل.'.tr())]
            : consultations.map((raw) {
                final item = Map<String, dynamic>.from(raw as Map);
                final assigned = item['assigned_office'] as Map?;
                final customer = item['customer'] as Map?;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(trUi(item['title']?.toString() ?? 'استشارة'), style: const TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 5),
                        Text(trUi([
                          item['consultation_number']?.toString(),
                          customer?['name']?.toString(),
                          assigned != null ? 'المكتب: ${assigned['name']}' : 'غير محولة',
                        ].where((e) => e != null && e.isNotEmpty).join(' • ')), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 11)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.tonalIcon(
                                onPressed: offices.isEmpty ? null : () => _assign(context, item, offices, reload, toast),
                                icon: const Icon(Icons.apartment_rounded),
                                label: Text(trUi(assigned == null ? 'تحويل لمكتب' : 'تغيير المكتب')),
                              ),
                            ),
                            if (assigned != null) ...[
                              const SizedBox(width: 8),
                              IconButton.filledTonal(
                                onPressed: () async {
                                  try {
                                    final message = await ApiService.unassignConsultationFromOffice(int.parse(item['id'].toString()));
                                    toast(message);
                                    await reload();
                                  } on ApiException catch (e) {
                                    AppFeedback.error(e.message);
                                    toast(e.message);
                                  }
                                },
                                icon: const Icon(Icons.link_off_rounded),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
      ),
    );
  }

  Future<void> _assign(BuildContext context, Map<String, dynamic> item, List<dynamic> offices, Future<void> Function() reload, void Function(String) toast) async {
    int selected = int.parse((offices.first as Map)['id'].toString());
    final notes = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => Directionality(
          textDirection: AppLanguage.instance.textDirection,
          child: AlertDialog(
            title: const TrText('تحويل الاستشارة إلى مكتب'),
            content: SizedBox(
              width: 430,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: selected,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: 'المكتب الهندسي'.tr()),
                    items: offices.map((raw) {
                      final office = Map<String, dynamic>.from(raw as Map);
                      return DropdownMenuItem<int>(
                        value: int.parse(office['id'].toString()),
                        child: Text(trUi(office['name']?.toString() ?? 'مكتب')),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => selected = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: notes, maxLines: 2, decoration: InputDecoration(labelText: 'ملاحظات التحويل'.tr())),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const TrText('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const TrText('تحويل')),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      try {
        final message = await ApiService.assignConsultationToOffice(
          consultationId: int.parse(item['id'].toString()),
          officeId: selected,
          notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
        );
        toast(message);
        await reload();
      } on ApiException catch (e) {
        AppFeedback.error(e.message);
        toast(e.message);
      }
    }
    Future<void>.delayed(const Duration(milliseconds: 600), notes.dispose);
  }
}

class _StatsRow extends StatelessWidget {
  final List<(String, dynamic)> values;

  const _StatsRow({required this.values});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: values.asMap().entries.map((entry) {
        final pair = entry.value;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(left: entry.key == values.length - 1 ? 0 : 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              color: (Theme.of(context).brightness == Brightness.dark ? Color(0x0DFFFFFF) : Theme.of(context).colorScheme.surface),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? Color(0x1AFFFFFF) : Theme.of(context).dividerColor)),
            ),
            child: Column(
              children: [
                Text('${pair.$2 ?? 0}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19)),
                Text(trUi(pair.$1), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 9)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(99)),
      child: Text(trUi(text), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800)),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;

  const _Empty({required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: const EdgeInsets.all(28), child: Center(child: Text(trUi(text), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))))));
  }
}

Future<String?> _askText(BuildContext context, String title, {int maxLines = 1}) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: AlertDialog(
        title: Text(trUi(title)),
        content: TextField(controller: controller, maxLines: maxLines, autofocus: true, decoration: InputDecoration(labelText: trUiN(title))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const TrText('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text), child: const TrText('تأكيد')),
        ],
      ),
    ),
  );
  Future<void>.delayed(const Duration(milliseconds: 600), controller.dispose);
  return result;
}

String _status(String? status) => switch (status) {
      'pending' => 'قيد المراجعة',
      'approved' => 'مقبول',
      'rejected' => 'مرفوض',
      _ => status ?? '—',
    };

String _subscriptionStatus(String? status) => switch (status) {
      'under_review' => 'قيد المراجعة',
      'active' => 'فعال',
      'rejected' => 'مرفوض',
      'expired' => 'منتهي',
      'pending' => 'بانتظار الدفع',
      _ => status ?? '—',
    };

String _officePaymentMethodLabel(String? method) => switch (method) {
  'bank_transfer' => 'تحويل بنكي',
  'wallet' => 'محفظة إلكترونية',
  'debit_card' => 'بطاقة Debit / Credit',
  'cash' => 'نقدي',
  'other' => 'أخرى',
  _ => method?.trim().isNotEmpty == true ? method! : '—',
};
