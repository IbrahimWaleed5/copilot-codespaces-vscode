import 'package:flutter/material.dart';

import '../i18n/localized_text.dart';
import '../i18n/i18n.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class AdminConsultationOfficeAssignmentScreen extends StatefulWidget {
  const AdminConsultationOfficeAssignmentScreen({super.key});

  @override
  State<AdminConsultationOfficeAssignmentScreen> createState() =>
      _AdminConsultationOfficeAssignmentScreenState();
}

class _AdminConsultationOfficeAssignmentScreenState
    extends State<AdminConsultationOfficeAssignmentScreen> {
  final TextEditingController _search = TextEditingController();
  List<Map<String, dynamic>> _consultations = const [];
  List<Map<String, dynamic>> _offices = const [];
  bool _loading = true;
  String? _error;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
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
      final data = await ApiService.fetchAdminConsultationOfficeAssignments();
      final consultations = (data['consultations'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final offices = (data['offices'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (mounted) {
        setState(() {
          _consultations = consultations;
          _offices = offices;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذر تحميل تحويلات الاستشارات.'.tr());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _asInt(dynamic value, [int fallback = 0]) =>
      int.tryParse(value?.toString() ?? '') ?? fallback;

  String _str(dynamic value, [String fallback = '—']) {
    final s = value?.toString().trim() ?? '';
    return s.isEmpty ? fallback : s;
  }

  Map<String, dynamic> _map(dynamic value) => value is Map
      ? Map<String, dynamic>.from(value)
      : const <String, dynamic>{};

  List<Map<String, dynamic>> get _visible {
    final q = _search.text.trim().toLowerCase();
    return _consultations.where((item) {
      final assigned = item['assigned_office_id'] != null ||
          _map(item['assigned_office']).isNotEmpty;
      if (_filter == 'assigned' && !assigned) return false;
      if (_filter == 'unassigned' && assigned) return false;
      if (q.isEmpty) return true;
      final customer = _map(item['customer']);
      final office = _map(item['assigned_office']);
      final type = _map(item['consultation_type']);
      final haystack = [
        item['consultation_number'],
        item['number'],
        item['title'],
        item['description'],
        item['status'],
        customer['name'],
        customer['email'],
        office['name'],
        type['name'],
      ].where((e) => e != null).join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
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
        'pending' => 'قيد الانتظار'.tr(),
        'in_progress' => 'قيد التنفيذ'.tr(),
        'completed' => 'مكتملة'.tr(),
        'cancelled' => 'ملغاة'.tr(),
        _ => status,
      };

  Future<void> _openAssignment(Map<String, dynamic> consultation) async {
    final currentOffice = _map(consultation['assigned_office']);
    int? selectedOfficeId = int.tryParse(
      consultation['assigned_office_id']?.toString() ??
          currentOffice['id']?.toString() ??
          '',
    );
    final notes = TextEditingController();

    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Map<String, dynamic>? selectedOffice;
          for (final office in _offices) {
            if (_asInt(office['id']) == selectedOfficeId) {
              selectedOffice = office;
              break;
            }
          }
          final customer = _map(consultation['customer']);
          final engineer = _map(consultation['engineer']);
          final type = _map(consultation['consultation_type']);
          final hasCurrent = currentOffice.isNotEmpty ||
              consultation['assigned_office_id'] != null;

          return AlertDialog(
            title: Text('تحويل الاستشارة إلى مكتب هندسي'.tr()),
            content: SizedBox(
              width: 720,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _InfoGrid(
                      items: [
                        _InfoItem(
                          'رقم الاستشارة'.tr(),
                          _str(consultation['consultation_number'] ?? consultation['number']),
                        ),
                        _InfoItem('العنوان'.tr(), _str(consultation['title'])),
                        _InfoItem('العميل'.tr(), _str(customer['name'], 'غير معروف'.tr())),
                        _InfoItem('نوع الاستشارة'.tr(), _str(type['name'], 'غير محدد'.tr())),
                        _InfoItem('المهندس الحالي'.tr(), _str(engineer['name'], 'غير معين'.tr())),
                        _InfoItem('المكتب الحالي'.tr(), _str(currentOffice['name'], 'غير محولة إلى مكتب'.tr())),
                      ],
                    ),
                    if (_str(consultation['description'], '').isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('وصف الاستشارة'.tr(), style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Text(trUi(_str(consultation['description'], ''))),
                    ],
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: selectedOfficeId != null &&
                              _offices.any((e) => _asInt(e['id']) == selectedOfficeId)
                          ? selectedOfficeId
                          : null,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: 'المكتب'.tr()),
                      hint: Text('اختر المكتب...'.tr()),
                      items: _offices.map((office) {
                        final name = _str(office['name']);
                        final city = _str(office['city'], 'مدينة غير محددة'.tr());
                        final members = _asInt(office['active_members_count']);
                        final count = _asInt(office['consultations_count']);
                        return DropdownMenuItem<int>(
                          value: _asInt(office['id']),
                          child: Text(
                            '$name — $city — $members ${'عضو'.tr()} — $count ${'استشارة'.tr()}'.tr(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: _offices.isEmpty
                          ? null
                          : (value) => setDialogState(() => selectedOfficeId = value),
                    ),
                    if (_offices.isEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'لا توجد مكاتب فعالة باشتراك ساري حاليًا.'.tr(),
                        style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700),
                      ),
                    ],
                    if (selectedOffice != null) ...[
                      const SizedBox(height: 10),
                      _OfficePreview(office: selectedOffice),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: notes,
                      minLines: 3,
                      maxLines: 5,
                      maxLength: 3000,
                      decoration: InputDecoration(
                        labelText: 'ملاحظات التحويل'.tr(),
                        hintText: 'أضف أي ملاحظات لمدير المكتب...'.tr(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0x19F59E0B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x55F59E0B)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'عند التحويل إلى مكتب جديد سيتم إزالة المهندس الحالي من الاستشارة، ثم يستطيع مدير المكتب تعيين مهندس من فريقه.'.tr(),
                              style: const TextStyle(height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasCurrent) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => Navigator.pop(dialogContext, 'unassign'),
                        icon: const Icon(Icons.link_off_rounded),
                        label: Text('إلغاء تحويل الاستشارة من المكتب'.tr()),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text('إلغاء'.tr()),
              ),
              FilledButton.icon(
                onPressed: selectedOfficeId == null
                    ? null
                    : () => Navigator.pop(dialogContext, 'assign'),
                icon: const Icon(Icons.check_rounded),
                label: Text('تأكيد تحويل الاستشارة'.tr()),
              ),
            ],
          );
        },
      ),
    );

    if (action == null) {
      Future<void>.delayed(const Duration(milliseconds: 600), notes.dispose);
      return;
    }

    final consultationId = _asInt(consultation['id']);
    try {
      if (action == 'unassign') {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('إلغاء التحويل؟'.tr()),
            content: Text('سيتم فك ارتباط الاستشارة بالمكتب الحالي.'.tr()),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text('إلغاء'.tr())),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: Text('تأكيد'.tr())),
            ],
          ),
        );
        if (confirm == true) {
          final message = await ApiService.unassignConsultationFromOffice(consultationId);
          _toast(message);
          await _load();
        }
      } else if (selectedOfficeId != null) {
        final message = await ApiService.assignConsultationToOffice(
          consultationId: consultationId,
          officeId: selectedOfficeId!,
          notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
        );
        _toast(message);
        await _load();
      }
    } on ApiException catch (e) {
      _toast(e.message, error: true);
    } finally {
      notes.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? const Color(0xFF0B1930) : Colors.white;
    final border = dark ? const Color(0xFF18375F) : const Color(0xFFD9E5F3);
    final items = _visible;

    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        backgroundColor: dark ? const Color(0xFF061226) : const Color(0xFFF4F8FF),
        appBar: AppBar(
          title: Text('إسناد الاستشارات للمكاتب'.tr()),
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded), tooltip: 'تحديث'.tr()),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: border),
                ),
                child: Column(
                  children: [
                    Text(
                      'اختر مكتبًا فعالًا باشتراك ساري، وسيتم إلغاء تعيين المهندس الحالي عند تحويل الاستشارة إلى المكتب.'.tr(),
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: 'ابحث برقم الاستشارة أو العنوان أو العميل أو المكتب...'.tr(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(value: 'all', label: Text('الكل'.tr()), icon: const Icon(Icons.list_alt_rounded)),
                        ButtonSegment(value: 'unassigned', label: Text('غير محولة'.tr()), icon: const Icon(Icons.link_off_rounded)),
                        ButtonSegment(value: 'assigned', label: Text('محولة'.tr()), icon: const Icon(Icons.apartment_rounded)),
                      ],
                      selected: {_filter},
                      onSelectionChanged: (values) => setState(() => _filter = values.first),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(trUi(_error!)))
                      : items.isEmpty
                          ? Center(child: Text('لا توجد استشارات مطابقة.'.tr()))
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(14, 0, 14, 90),
                                itemCount: items.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  final customer = _map(item['customer']);
                                  final office = _map(item['assigned_office']);
                                  final type = _map(item['consultation_type']);
                                  final engineer = _map(item['engineer']);
                                  final status = _str(item['status'], 'pending');
                                  return InkWell(
                                    onTap: () => _openAssignment(item),
                                    borderRadius: BorderRadius.circular(18),
                                    child: Container(
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
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  trUi(_str(item['title'])),
                                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                                                ),
                                              ),
                                              _StatusChip(label: _statusLabel(status)),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '${'رقم الاستشارة'.tr()}: ${_str(item['consultation_number'] ?? item['number'])}'.tr(),
                                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                          ),
                                          const SizedBox(height: 10),
                                          Wrap(
                                            spacing: 12,
                                            runSpacing: 8,
                                            children: [
                                              _Meta(icon: Icons.person_outline, text: _str(customer['name'], 'غير معروف'.tr())),
                                              _Meta(icon: Icons.category_outlined, text: _str(type['name'], 'غير محدد'.tr())),
                                              _Meta(icon: Icons.engineering_outlined, text: _str(engineer['name'], 'غير معين'.tr())),
                                              _Meta(icon: Icons.apartment_outlined, text: _str(office['name'], 'غير محولة إلى مكتب'.tr())),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Align(
                                            alignment: AlignmentDirectional.centerEnd,
                                            child: FilledButton.tonalIcon(
                                              onPressed: () => _openAssignment(item),
                                              icon: const Icon(Icons.swap_horiz_rounded),
                                              label: Text(
                                                office.isEmpty ? 'تحويل إلى مكتب'.tr() : 'تغيير المكتب'.tr(),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
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

class _InfoItem {
  final String label;
  final String value;
  const _InfoItem(this.label, this.value);
}

class _InfoGrid extends StatelessWidget {
  final List<_InfoItem> items;
  const _InfoGrid({required this.items});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 10,
        runSpacing: 10,
        children: items
            .map(
              (item) => SizedBox(
                width: 250,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .45),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(trUi(item.label), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text(trUi(item.value), style: const TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      );
}

class _OfficePreview extends StatelessWidget {
  final Map<String, dynamic> office;
  const _OfficePreview({required this.office});

  int _int(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

  @override
  Widget build(BuildContext context) {
    final date = office['subscription_ends_at']?.toString().split('T').first ?? 'غير محدد'.tr();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(trUi(office['name']?.toString() ?? '—'), style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text('${office['city'] ?? 'مدينة غير محددة'.tr()}'.tr()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Tag(label: '${_int(office['active_members_count'])} ${'عضو'.tr()}'),
              _Tag(label: '${_int(office['consultations_count'])} ${'استشارة'.tr()}'),
              _Tag(label: '${'الاشتراك حتى'.tr()}: $date'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  const _StatusChip({required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .25),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(trUi(label), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
      );
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(trUi(text), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
        ],
      );
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(trUi(label), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      );
}
