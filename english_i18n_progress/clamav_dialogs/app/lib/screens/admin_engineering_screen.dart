import 'package:flutter/material.dart';

import '../i18n/localized_text.dart';
import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';

class AdminEngineeringScreen extends StatelessWidget {
  final int initialTab;

  const AdminEngineeringScreen({super.key, this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: DefaultTabController(
        length: 4,
        initialIndex: initialTab < 0 ? 0 : (initialTab > 3 ? 3 : initialTab),
        child: Scaffold(
          appBar: AppBar(
            title: TrText('الإدارة الهندسية'),
            bottom: TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'طلبات المهندسين'.tr(), icon: Icon(Icons.engineering_outlined)),
                Tab(text: 'الاشتراكات'.tr(), icon: Icon(Icons.workspace_premium_outlined)),
                Tab(text: 'معرض الأعمال'.tr(), icon: Icon(Icons.work_outline_rounded)),
                Tab(text: 'التقييمات'.tr(), icon: Icon(Icons.star_outline_rounded)),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _ApplicationsTab(),
              _SubscriptionsTab(),
              _WorksTab(),
              _ReviewsTab(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApplicationsTab extends StatefulWidget {
  const _ApplicationsTab();

  @override
  State<_ApplicationsTab> createState() => _ApplicationsTabState();
}

class _ApplicationsTabState extends State<_ApplicationsTab> {
  List<Map<String, dynamic>> _items = [];
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
      final data = await ApiService.fetchAdminEngineerApplications();
      final raw = List<dynamic>.from(data['data'] as List? ?? const []);
      if (mounted) {
        setState(() {
          _items = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        });
      }
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(Map<String, dynamic> item) async {
    final days = TextEditingController(text: '365');
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: AlertDialog(
          title: const TrText('اعتماد المهندس'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: days,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'مدة العضوية بالأيام'.tr()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: note,
                maxLines: 3,
                decoration: InputDecoration(labelText: 'ملاحظة الإدارة - اختياري'.tr()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const TrText('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const TrText('اعتماد')),
          ],
        ),
      ),
    );
    if (ok != true) {
      Future<void>.delayed(const Duration(milliseconds: 600), days.dispose);
      Future<void>.delayed(const Duration(milliseconds: 600), note.dispose);
      return;
    }
    try {
      final message = await ApiService.approveEngineerApplication(
        id: _id(item),
        membershipDays: int.tryParse(days.text.trim()) ?? 365,
        note: note.text.trim().isEmpty ? null : note.text.trim(),
      );
      if (mounted) _snack(message);
      await _load();
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      days.dispose();
      note.dispose();
    }
  }

  Future<void> _reject(Map<String, dynamic> item) async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: AlertDialog(
          title: const TrText('رفض الطلب'),
          content: TextField(
            controller: note,
            maxLines: 4,
            decoration: InputDecoration(labelText: 'سبب الرفض'.tr()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const TrText('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const TrText('رفض')),
          ],
        ),
      ),
    );
    if (ok != true) {
      Future<void>.delayed(const Duration(milliseconds: 600), note.dispose);
      return;
    }
    try {
      final message = await ApiService.rejectEngineerApplication(_id(item), note.text.trim());
      if (mounted) _snack(message);
      await _load();
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      note.dispose();
    }
  }

  void _snack(String message) => AppFeedback.auto(message);

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _LoadError(message: _error!, onRetry: _load);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(14),
        children: [
          _SummaryHeader(
            title: 'طلبات اعتماد المهندسين',
            subtitle: 'مراجعة الدفع والتخصص وتفعيل عضوية المهندس.',
            count: _items.length,
          ),
          const SizedBox(height: 12),
          if (_items.isEmpty)
            _Empty(text: 'لا توجد طلبات مهندسين.'.tr())
          else
            ..._items.map((item) {
              final user = _map(item['user']);
              final specialty = _map(item['specialty']);
              final status = item['status']?.toString() ?? '';
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(child: Icon(Icons.engineering_outlined)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(trUi(user['name']?.toString() ?? 'مهندس'), style: const TextStyle(fontWeight: FontWeight.w900)),
                                Text(trUi(user['email']?.toString() ?? ''), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 12)),
                              ],
                            ),
                          ),
                          _StatusChip(status: status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _MetaLine(icon: Icons.category_outlined, text: 'التخصص: ${specialty['name'] ?? item['specialty_name'] ?? '-'}'),
                      _MetaLine(icon: Icons.payments_outlined, text: 'الدفع: ${item['payment_status'] ?? '-'}'),
                      if (item['created_at'] != null)
                        _MetaLine(icon: Icons.schedule_rounded, text: 'تاريخ الطلب: ${_date(item['created_at'])}'),
                      if (status == 'pending') ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: () => _approve(item),
                              icon: const Icon(Icons.check_rounded),
                              label: const TrText('اعتماد'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _reject(item),
                              icon: const Icon(Icons.close_rounded),
                              label: const TrText('رفض'),
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
}

class _SubscriptionsTab extends StatefulWidget {
  const _SubscriptionsTab();

  @override
  State<_SubscriptionsTab> createState() => _SubscriptionsTabState();
}

class _SubscriptionsTabState extends State<_SubscriptionsTab> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  String _filter = 'all';

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
      final data = await ApiService.fetchAdminEngineerSubscriptions();
      if (!mounted) return;
      setState(() => _data = data);
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر تحميل اشتراكات المهندسين.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _items {
    final raw = _data?['subscriptions'];
    final items = raw is List
        ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];
    if (_filter == 'all') return items;
    return items.where((item) {
      if (_filter == 'renewal') {
        return item['application_type']?.toString() == 'renewal';
      }
      if (_filter == 'pending') {
        return item['status']?.toString() == 'pending';
      }
      final user = _map(item['user']);
      final expiryRaw = item['membership_expires_at'] ?? user['engineer_active_until'];
      final until = DateTime.tryParse(expiryRaw?.toString() ?? '');
      final active = item['status']?.toString() == 'approved' &&
          until != null &&
          until.isAfter(DateTime.now());
      return _filter == 'active' ? active : !active && item['status']?.toString() == 'approved';
    }).toList();
  }

  Map<String, dynamic> get _stats => _map(_data?['statistics']);

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _LoadError(message: _error!, onRetry: _load);
    final items = _items;
    final stats = _stats;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(14),
        children: [
          _SummaryHeader(
            title: 'اشتراكات المهندسين',
            subtitle: 'متابعة الاشتراكات الفعالة والمنتهية وطلبات التجديد ودفعاتها.',
            count: int.tryParse((stats['total'] ?? 0).toString()) ?? 0,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth < 370 ? 1 : 2;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: cols == 1 ? 4.0 : 2.2,
                children: [
                  _SubscriptionStatCard(label: 'فعالة', value: stats['active'] ?? 0, icon: Icons.verified_rounded),
                  _SubscriptionStatCard(label: 'تنتهي خلال 30 يوم', value: stats['expiring_soon'] ?? 0, icon: Icons.event_busy_outlined),
                  _SubscriptionStatCard(label: 'منتهية', value: stats['expired'] ?? 0, icon: Icons.history_toggle_off_rounded),
                  _SubscriptionStatCard(label: 'طلبات معلقة', value: stats['pending'] ?? 0, icon: Icons.hourglass_top_rounded),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _subscriptionFilterChip('الكل', 'all'),
                _subscriptionFilterChip('فعالة', 'active'),
                _subscriptionFilterChip('منتهية', 'expired'),
                _subscriptionFilterChip('قيد المراجعة', 'pending'),
                _subscriptionFilterChip('تجديدات', 'renewal'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            _Empty(text: 'لا توجد اشتراكات مطابقة.'.tr())
          else
            ...items.map(_subscriptionCard),
        ],
      ),
    );
  }

  Widget _subscriptionFilterChip(String label, String value) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 7),
      child: FilterChip(
        selected: _filter == value,
        label: Text(trUi(label)),
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }

  Widget _subscriptionCard(Map<String, dynamic> item) {
    final user = _map(item['user']);
    final specialty = _map(item['specialty']);
    final applicationType = item['application_type']?.toString() == 'renewal' ? 'تجديد' : 'اشتراك أول';
    final status = item['status']?.toString() ?? '';
    final untilRaw = item['membership_expires_at'] ?? user['engineer_active_until'];
    final until = DateTime.tryParse(untilRaw?.toString() ?? '');
    final active = status == 'approved' &&
        until != null &&
        until.isAfter(DateTime.now());
    final membershipLabel = status == 'pending'
        ? 'قيد المراجعة'
        : active
            ? 'فعال'
            : status == 'approved'
                ? 'منتهي'
                : (status.isEmpty ? 'غير محدد' : status);

    final membershipColor = status == 'pending'
        ? const Color(0xFFFFD166)
        : active
            ? AppColors.success
            : AppColors.danger;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(child: Icon(Icons.engineering_outlined)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(trUi(user['name']?.toString() ?? 'مهندس'), style: const TextStyle(fontWeight: FontWeight.w900)),
                      Text(trUi(user['email']?.toString() ?? ''), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: membershipColor.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(trUi(membershipLabel), style: TextStyle(color: membershipColor, fontWeight: FontWeight.w900, fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _MetaLine(icon: Icons.workspace_premium_outlined, text: 'النوع: $applicationType'),
            _MetaLine(icon: Icons.category_outlined, text: 'التخصص: ${specialty['name'] ?? '-'}'),
            _MetaLine(icon: Icons.payments_outlined, text: 'حالة الدفع: ${_paymentLabel(item['payment_status']?.toString())}'),
            if (item['amount'] != null)
              _MetaLine(icon: Icons.account_balance_wallet_outlined, text: 'القيمة: ${item['amount']}'),
            if (item['membership_started_at'] != null)
              _MetaLine(icon: Icons.play_circle_outline_rounded, text: 'بداية الاشتراك: ${_date(item['membership_started_at'])}'),
            if (untilRaw != null)
              _MetaLine(icon: Icons.event_outlined, text: 'نهاية الاشتراك: ${_date(untilRaw)}'),
            if (item['membership_days'] != null)
              _MetaLine(icon: Icons.timelapse_rounded, text: 'مدة التفعيل: ${item['membership_days']} يوم'),
            if (status == 'pending') ...[
              const SizedBox(height: 10),
              TrText('هذا الطلب يظهر أيضًا في تبويب «طلبات المهندسين» لاعتماده أو رفضه.', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }

  String _paymentLabel(String? status) => switch (status) {
        'paid' => 'مدفوع',
        'pending' => 'قيد الفحص',
        'rejected' => 'مرفوض',
        _ => status ?? '—',
      };
}

class _SubscriptionStatCard extends StatelessWidget {
  final String label;
  final dynamic value;
  final IconData icon;

  const _SubscriptionStatCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF0D1B31) : Theme.of(context).colorScheme.surface),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? Color(0x1AFFFFFF) : Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Icon(icon, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan)),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$value', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                Text(trUi(label), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorksTab extends StatefulWidget {
  const _WorksTab();

  @override
  State<_WorksTab> createState() => _WorksTabState();
}

class _WorksTabState extends State<_WorksTab> {
  List<Map<String, dynamic>> _items = [];
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
      final data = await ApiService.fetchAdminEngineerWorks();
      if (mounted) {
        setState(() => _items = data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList());
      }
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(Map<String, dynamic> item) => _review(item, true);

  Future<void> _reject(Map<String, dynamic> item) async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: AlertDialog(
          title: const TrText('رفض العمل'),
          content: TextField(
            controller: note,
            maxLines: 4,
            decoration: InputDecoration(labelText: 'سبب الرفض'.tr()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const TrText('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const TrText('رفض')),
          ],
        ),
      ),
    );
    if (ok == true) await _review(item, false, note: note.text.trim());
    Future<void>.delayed(const Duration(milliseconds: 600), note.dispose);
  }

  Future<void> _review(Map<String, dynamic> item, bool approve, {String? note}) async {
    try {
      final message = await ApiService.reviewEngineerWork(id: _id(item), approve: approve, note: note);
      if (mounted) _snack(message);
      await _load();
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    if (!await _confirm(context, 'حذف العمل', 'سيتم حذف العمل وملفاته نهائيًا. هل تريد المتابعة؟')) return;
    try {
      final message = await ApiService.deleteAdminEngineerWork(_id(item));
      if (mounted) _snack(message);
      await _load();
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    }
  }

  void _snack(String message) => AppFeedback.auto(message);

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _LoadError(message: _error!, onRetry: _load);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(14),
        children: [
          _SummaryHeader(
            title: 'مراجعة أعمال المهندسين',
            subtitle: 'اعتماد الأعمال المنشورة أو رفضها أو حذفها.',
            count: _items.length,
          ),
          const SizedBox(height: 12),
          if (_items.isEmpty)
            _Empty(text: 'لا توجد أعمال للمراجعة.'.tr())
          else
            ..._items.map((item) {
              final engineer = _map(item['engineer']);
              final status = item['status']?.toString() ?? '';
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(trUi(item['title']?.toString() ?? 'عمل هندسي'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                          ),
                          _StatusChip(status: status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TrText('المهندس: ${engineer['name'] ?? '-'}', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
                      if (item['description'] != null) ...[
                        const SizedBox(height: 8),
                        Text(trUi(item['description'].toString()), maxLines: 4, overflow: TextOverflow.ellipsis),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (status != 'approved')
                            FilledButton.icon(onPressed: () => _approve(item), icon: const Icon(Icons.check_rounded), label: const TrText('اعتماد')),
                          OutlinedButton.icon(onPressed: () => _reject(item), icon: const Icon(Icons.close_rounded), label: const TrText('رفض')),
                          TextButton.icon(onPressed: () => _delete(item), icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger), label: const TrText('حذف')),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _ReviewsTab extends StatefulWidget {
  const _ReviewsTab();

  @override
  State<_ReviewsTab> createState() => _ReviewsTabState();
}

class _ReviewsTabState extends State<_ReviewsTab> {
  List<Map<String, dynamic>> _items = [];
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
      final data = await ApiService.fetchAdminReviews();
      final raw = List<dynamic>.from(data['data'] as List? ?? const []);
      if (mounted) {
        setState(() => _items = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList());
      }
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _action(Map<String, dynamic> item, String action) async {
    try {
      final message = await ApiService.updateAdminReview(_id(item), action);
      if (mounted) _snack(message);
      await _load();
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    if (!await _confirm(context, 'حذف التقييم', 'هل تريد حذف هذا التقييم نهائيًا؟')) return;
    try {
      final message = await ApiService.deleteAdminReview(_id(item));
      if (mounted) _snack(message);
      await _load();
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    }
  }

  void _snack(String message) => AppFeedback.auto(message);

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _LoadError(message: _error!, onRetry: _load);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(14),
        children: [
          _SummaryHeader(
            title: 'مراجعات العملاء',
            subtitle: 'اعتماد التقييمات وإبرازها على الموقع أو رفضها.',
            count: _items.length,
          ),
          const SizedBox(height: 12),
          if (_items.isEmpty)
            _Empty(text: 'لا توجد تقييمات.'.tr())
          else
            ..._items.map((item) {
              final customer = _map(item['customer']);
              final consultation = _map(item['consultation']);
              final status = item['status']?.toString() ?? '';
              final rating = int.tryParse(item['rating']?.toString() ?? '') ?? 0;
              final featured = item['is_featured'] == true || item['is_featured']?.toString() == '1';
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(trUi(customer['name']?.toString() ?? 'عميل'), style: const TextStyle(fontWeight: FontWeight.w900))),
                          _StatusChip(status: status),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: List.generate(5, (index) => Icon(index < rating ? Icons.star_rounded : Icons.star_border_rounded, color: const Color(0xFFFFD166), size: 19)),
                      ),
                      if (consultation.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        TrText('الاستشارة: ${consultation['title'] ?? consultation['consultation_number'] ?? '-'}', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 12)),
                      ],
                      if (item['comment'] != null && item['comment'].toString().trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(trUi(item['comment'].toString())),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (status != 'approved')
                            FilledButton.icon(onPressed: () => _action(item, 'approve'), icon: const Icon(Icons.check_rounded), label: const TrText('اعتماد')),
                          if (status != 'rejected')
                            OutlinedButton.icon(onPressed: () => _action(item, 'reject'), icon: const Icon(Icons.close_rounded), label: const TrText('رفض')),
                          if (status == 'approved')
                            OutlinedButton.icon(
                              onPressed: () => _action(item, 'featured'),
                              icon: Icon(featured ? Icons.visibility_off_outlined : Icons.campaign_outlined),
                              label: Text(trUi(featured ? 'إخفاء من الموقع' : 'إبراز بالموقع')),
                            ),
                          TextButton.icon(onPressed: () => _delete(item), icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger), label: const TrText('حذف')),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final int count;

  const _SummaryHeader({required this.title, required this.subtitle, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF0D1B31) : Theme.of(context).colorScheme.surface),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? Color(0x1AFFFFFF) : Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(trUi(title), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(trUi(subtitle), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: AppColors.blue500_10, borderRadius: BorderRadius.circular(99)),
            child: Text('$count', style: TextStyle(fontWeight: FontWeight.w900, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan))),
          ),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(width: 6),
          Expanded(child: Text(trUi(text), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 12))),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'approved' => ('معتمد', AppColors.success),
      'pending' => ('معلّق', const Color(0xFFFFD166)),
      'rejected' => ('مرفوض', AppColors.danger),
      _ => (status.isEmpty ? '-' : status, (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : AppColors.textSecondary)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(trUi(label), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
    );
  }
}

class _LoadError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _LoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 42),
            const SizedBox(height: 10),
            Text(trUi(message), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const TrText('إعادة المحاولة')),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;

  const _Empty({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 50),
      child: Center(child: Text(trUi(text), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant)))),
    );
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

int _id(Map<String, dynamic> value) => int.parse(value['id'].toString());

String _date(dynamic value) {
  final raw = value?.toString() ?? '';
  if (raw.isEmpty) return '-';
  return raw.length >= 10 ? raw.substring(0, 10) : raw;
}

Future<bool> _confirm(BuildContext context, String title, String message) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => Directionality(
          textDirection: AppLanguage.instance.textDirection,
          child: AlertDialog(
            title: Text(trUi(title)),
            content: Text(trUi(message)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const TrText('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const TrText('تأكيد')),
            ],
          ),
        ),
      ) ??
      false;
}
