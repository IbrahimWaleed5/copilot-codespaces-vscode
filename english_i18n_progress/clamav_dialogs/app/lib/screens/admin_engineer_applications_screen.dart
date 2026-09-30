import 'package:flutter/material.dart';
import '../i18n/localized_text.dart';
import 'package:open_filex/open_filex.dart';

import '../i18n/i18n.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class AdminEngineerApplicationsScreen extends StatefulWidget {
  const AdminEngineerApplicationsScreen({super.key});

  @override
  State<AdminEngineerApplicationsScreen> createState() =>
      _AdminEngineerApplicationsScreenState();
}

class _AdminEngineerApplicationsScreenState
    extends State<AdminEngineerApplicationsScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _openingFile = false;
  String? _error;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int? page}) async {
    final target = page ?? _page;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await ApiService.fetchAdminEngineerApplications(page: target);
      if (mounted) {
        setState(() {
          _data = data;
          _page = int.tryParse('${data['current_page']}') ?? target;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر تحميل طلبات المهندسين.'.tr());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _items =>
      (_data?['data'] as List? ?? const <dynamic>[])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

  int get _total => int.tryParse('${_data?['total'] ?? 0}') ?? 0;
  int get _lastPage => int.tryParse('${_data?['last_page'] ?? 1}') ?? 1;

  Map<String, dynamic> _map(dynamic value) => value is Map
      ? Map<String, dynamic>.from(value)
      : const <String, dynamic>{};

  int _int(dynamic value, [int fallback = 0]) =>
      int.tryParse(value?.toString() ?? '') ?? fallback;

  double _double(dynamic value) => double.tryParse(value?.toString() ?? '') ?? 0;

  String _str(dynamic value, [String fallback = '—']) {
    final s = value?.toString().trim() ?? '';
    return s.isEmpty ? fallback : s;
  }

  String _date(dynamic value) {
    final s = value?.toString().trim() ?? '';
    if (s.isEmpty) return '—';
    return s.contains('T') ? s.split('T').first : s;
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(trUi(message)),
        backgroundColor: error ? AppColors.danger : AppColors.success,
      ),
    );
  }

  String _statusLabel(String status) => switch (status) {
        'approved' => 'مقبول'.tr(),
        'rejected' => 'مرفوض'.tr(),
        _ => 'قيد المراجعة'.tr(),
      };

  String _paymentLabel(String status) => switch (status) {
        'paid' => 'تم تأكيد الدفع'.tr(),
        'rejected' => 'الدفع مرفوض'.tr(),
        _ => 'الدفع قيد الفحص'.tr(),
      };

  Color _statusColor(String status) => switch (status) {
        'approved' || 'paid' => AppColors.success,
        'rejected' => AppColors.danger,
        _ => const Color(0xFFF59E0B),
      };

  Future<void> _openPublicPath(String path, String fallbackName) async {
    if (_openingFile || path.trim().isEmpty) return;
    setState(() => _openingFile = true);
    try {
      final url = Uri.parse('${ApiService.siteBaseUrl}/media/storage')
          .replace(queryParameters: {'path': path.trim()})
          .toString();
      final file = await ApiService.downloadPublicUrl(url: url, fileName: fallbackName);
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        _toast(result.message.isEmpty ? 'تعذر فتح الملف.'.tr() : result.message, error: true);
      }
    } on ApiException catch (e) {
      _toast(e.message, error: true);
    } catch (_) {
      _toast('تعذر فتح الملف.'.tr(), error: true);
    } finally {
      if (mounted) setState(() => _openingFile = false);
    }
  }

  Future<void> _approve(Map<String, dynamic> item) async {
    final days = TextEditingController(text: '${_int(item['membership_days'], 30).clamp(1, 3650)}');
    final note = TextEditingController(text: item['admin_note']?.toString() ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('قبول الطلب وتفعيل المهندس'.tr()),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: days,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'عدد أيام التفعيل'.tr(),
                  helperText: 'من 1 إلى 3650 يومًا'.tr(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: note,
                minLines: 3,
                maxLines: 5,
                maxLength: 2000,
                decoration: InputDecoration(labelText: 'ملاحظة الإدارة'.tr()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text('إلغاء'.tr())),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text('قبول وتفعيل'.tr())),
        ],
      ),
    );

    if (confirmed == true) {
      final membershipDays = int.tryParse(days.text.trim()) ?? 0;
      if (membershipDays < 1 || membershipDays > 3650) {
        _toast('عدد أيام التفعيل غير صالح.'.tr(), error: true);
      } else {
        try {
          final message = await ApiService.approveEngineerApplication(
            id: _int(item['id']),
            membershipDays: membershipDays,
            note: note.text.trim().isEmpty ? null : note.text.trim(),
          );
          _toast(message);
          await _load();
        } on ApiException catch (e) {
          _toast(e.message, error: true);
        }
      }
    }
    Future<void>.delayed(const Duration(milliseconds: 600), days.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), note.dispose);
  }

  Future<void> _reject(Map<String, dynamic> item) async {
    final note = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('رفض طلب المهندس'.tr()),
        content: TextField(
          controller: note,
          minLines: 3,
          maxLines: 6,
          maxLength: 2000,
          decoration: InputDecoration(labelText: 'سبب الرفض'.tr()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('إلغاء'.tr())),
          FilledButton(
            onPressed: () {
              final value = note.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: Text('رفض'.tr()),
          ),
        ],
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 600), note.dispose);
    if (reason == null || reason.isEmpty) return;
    try {
      final message = await ApiService.rejectEngineerApplication(_int(item['id']), reason);
      _toast(message);
      await _load();
    } on ApiException catch (e) {
      _toast(e.message, error: true);
    }
  }

  Widget _fileButton(String label, String? path, IconData icon, String fallbackName) {
    final available = path != null && path.trim().isNotEmpty;
    return OutlinedButton.icon(
      onPressed: available ? () => _openPublicPath(path, fallbackName) : null,
      icon: Icon(icon),
      label: Text(trUi(label)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? const Color(0xFF0B1930) : Colors.white;
    final border = dark ? const Color(0xFF18375F) : const Color(0xFFD9E5F3);
    final pending = _items.where((e) => _str(e['status'], 'pending') == 'pending').length;
    final renewals = _items.where((e) => _str(e['application_type']) == 'renewal').length;

    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        backgroundColor: dark ? const Color(0xFF061226) : const Color(0xFFF4F8FF),
        appBar: AppBar(
          title: Text('طلبات واشتراكات المهندسين'.tr()),
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded), tooltip: 'تحديث'.tr()),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: border),
                    ),
                    child: Text(
                      'مراجعة طلبات الانضمام ودفعات التجديد، وتحديد عدد أيام تفعيل حساب المهندس.'.tr(),
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.6),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _StatCard(label: 'إجمالي الطلبات'.tr(), value: '$_total')),
                      const SizedBox(width: 8),
                      Expanded(child: _StatCard(label: 'طلبات الصفحة'.tr(), value: '${_items.length}')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _StatCard(label: 'قيد المراجعة'.tr(), value: '$pending')),
                      const SizedBox(width: 8),
                      Expanded(child: _StatCard(label: 'دفعات تجديد'.tr(), value: '$renewals')),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(trUi(_error!)))
                      : _items.isEmpty
                          ? Center(child: Text('لا توجد طلبات.'.tr()))
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                                itemCount: _items.length + 1,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  if (index == _items.length) {
                                    return _Pagination(
                                      page: _page,
                                      lastPage: _lastPage,
                                      onPrevious: _page > 1 ? () => _load(page: _page - 1) : null,
                                      onNext: _page < _lastPage ? () => _load(page: _page + 1) : null,
                                    );
                                  }
                                  final item = _items[index];
                                  final user = _map(item['user']);
                                  final profile = _map(user['employee_profile']);
                                  final specialty = _map(item['specialty']);
                                  final plan = _map(item['plan']);
                                  final status = _str(item['status'], 'pending');
                                  final payment = _str(item['payment_status'], 'pending');
                                  final renewal = _str(item['application_type']) == 'renewal';
                                  final currency = _str(item['currency'], 'USD');
                                  final amount = _double(item['amount']).toStringAsFixed(2);
                                  return Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: surface,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(color: border),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            CircleAvatar(
                                              radius: 24,
                                              child: Text(trUi(_str(user['name'], 'م').substring(0, 1))),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(trUi(_str(user['name'], 'مستخدم غير معروف'.tr())), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                                                  const SizedBox(height: 3),
                                                  Text('${'طلب رقم'.tr()}: #${_int(item['id'])}'.tr(), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                                ],
                                              ),
                                            ),
                                            _Pill(
                                              label: renewal ? 'تجديد اشتراك'.tr() : 'انضمام جديد'.tr(),
                                              color: renewal ? const Color(0xFF8B5CF6) : const Color(0xFF2563EB),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            _Pill(label: _statusLabel(status), color: _statusColor(status)),
                                            _Pill(label: _paymentLabel(payment), color: _statusColor(payment)),
                                            _Pill(label: '${'المبلغ'.tr()}: $amount $currency', color: const Color(0xFF0EA5E9)),
                                          ],
                                        ),
                                        const SizedBox(height: 14),
                                        _InfoLine('البريد الإلكتروني'.tr(), _str(user['email'])),
                                        _InfoLine('رقم الهاتف'.tr(), _str(user['phone'])),
                                        _InfoLine('التخصص'.tr(), _str(specialty['name'] ?? _map(profile['specialty'])['name'], 'غير محدد'.tr())),
                                        _InfoLine('الباقة'.tr(), _str(plan['name'], 'غير محدد'.tr())),
                                        _InfoLine('تاريخ الطلب'.tr(), _date(item['created_at'])),
                                        if (_str(item['coupon_code'], '').isNotEmpty)
                                          _InfoLine('الكوبون'.tr(), _str(item['coupon_code'])),
                                        const SizedBox(height: 12),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            _fileButton('الشهادة'.tr(), item['certificate_file']?.toString(), Icons.workspace_premium_outlined, 'certificate_${_int(item['id'])}'),
                                            _fileButton('السيرة الذاتية'.tr(), item['cv_file']?.toString(), Icons.description_outlined, 'cv_${_int(item['id'])}'),
                                            _fileButton('إيصال الدفع'.tr(), item['payment_receipt']?.toString(), Icons.receipt_long_outlined, 'receipt_${_int(item['id'])}'),
                                          ],
                                        ),
                                        if (status == 'pending') ...[
                                          const SizedBox(height: 14),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              FilledButton.icon(
                                                onPressed: () => _approve(item),
                                                icon: const Icon(Icons.check_circle_outline),
                                                label: Text('قبول وتفعيل'.tr()),
                                              ),
                                              FilledButton.tonalIcon(
                                                onPressed: () => _reject(item),
                                                icon: const Icon(Icons.cancel_outlined),
                                                label: Text('رفض'.tr()),
                                              ),
                                            ],
                                          ),
                                        ] else ...[
                                          const SizedBox(height: 12),
                                          _InfoLine('مدة التفعيل'.tr(), item['membership_days'] == null ? '—' : '${item['membership_days']} ${'يوم'.tr()}'),
                                          _InfoLine('بداية العضوية'.tr(), _date(item['membership_started_at'])),
                                          _InfoLine('نهاية العضوية'.tr(), _date(item['membership_expires_at'])),
                                          if (_str(item['admin_note'], '').isNotEmpty)
                                            _InfoLine('ملاحظة الإدارة'.tr(), _str(item['admin_note'])),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(trUi(label), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11)),
            const SizedBox(height: 6),
            Text(trUi(value), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          ],
        ),
      );
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(trUi(label), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
      );
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  const _InfoLine(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 125,
              child: Text(trUi(label), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
            ),
            const SizedBox(width: 6),
            Expanded(child: Text(trUi(value), style: const TextStyle(fontWeight: FontWeight.w700))),
          ],
        ),
      );
}

class _Pagination extends StatelessWidget {
  final int page;
  final int lastPage;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _Pagination({
    required this.page,
    required this.lastPage,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton.filledTonal(onPressed: onPrevious, icon: const Icon(Icons.chevron_right_rounded)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('${'صفحة'.tr()} $page / $lastPage'.tr(), style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          IconButton.filledTonal(onPressed: onNext, icon: const Icon(Icons.chevron_left_rounded)),
        ],
      );
}
