import 'package:flutter/material.dart';
import '../i18n/localized_text.dart';
import 'package:flutter/services.dart';

import '../i18n/i18n.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'engineer_library_screen.dart';

class AdminEngineerWorksReviewScreen extends StatefulWidget {
  const AdminEngineerWorksReviewScreen({super.key});

  @override
  State<AdminEngineerWorksReviewScreen> createState() =>
      _AdminEngineerWorksReviewScreenState();
}

class _AdminEngineerWorksReviewScreenState
    extends State<AdminEngineerWorksReviewScreen> {
  final TextEditingController _search = TextEditingController();
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String? _error;
  String _status = 'all';

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
      final data = await ApiService.fetchAdminEngineerWorks();
      final items = data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (mounted) setState(() => _items = items);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر تحميل أعمال المهندسين.'.tr());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _map(dynamic value) => value is Map
      ? Map<String, dynamic>.from(value)
      : const <String, dynamic>{};

  int _int(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

  String _str(dynamic value, [String fallback = '—']) {
    final s = value?.toString().trim() ?? '';
    return s.isEmpty ? fallback : s;
  }

  String _engineerName(Map<String, dynamic> item) =>
      _str(_map(item['engineer'])['name'], 'غير معروف'.tr());

  String _specialtyName(Map<String, dynamic> item) {
    final engineer = _map(item['engineer']);
    final profile = _map(engineer['employee_profile']);
    final specialty = _map(profile['specialty']);
    return _str(specialty['name'], 'غير محدد'.tr());
  }

  String? _coverUrl(Map<String, dynamic> item) {
    final cover = _map(item['cover_image']);
    final url = cover['url']?.toString().trim();
    return url == null || url.isEmpty ? null : url;
  }

  List<Map<String, dynamic>> get _visible {
    final q = _search.text.trim().toLowerCase();
    return _items.where((item) {
      final status = _str(item['status'], 'pending');
      if (_status != 'all' && status != _status) return false;
      if (q.isEmpty) return true;
      final haystack = [
        item['title'],
        item['description'],
        item['project_type'],
        item['location'],
        item['project_role'],
        _engineerName(item),
        _specialtyName(item),
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

  String _statusLabel(String value) => switch (value) {
        'approved' => 'مقبول'.tr(),
        'rejected' => 'مرفوض'.tr(),
        _ => 'قيد المراجعة'.tr(),
      };

  Color _statusColor(String value) => switch (value) {
        'approved' => AppColors.success,
        'rejected' => AppColors.danger,
        _ => const Color(0xFFF59E0B),
      };

  Future<String?> _rejectReason() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('رفض العمل'.tr()),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          maxLength: 1000,
          decoration: InputDecoration(labelText: 'سبب الرفض'.tr()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('إلغاء'.tr()),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(dialogContext, text);
            },
            child: Text('رفض'.tr()),
          ),
        ],
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 600), controller.dispose);
    return result;
  }

  Future<void> _review(Map<String, dynamic> item, bool approve) async {
    final id = _int(item['id']);
    if (id <= 0) return;
    String? note;
    if (!approve) {
      note = await _rejectReason();
      if (note == null || note.isEmpty) return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('اعتماد العمل؟'.tr()),
          content: Text('سيتم اعتماد العمل وإشعار المهندس.'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('إلغاء'.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text('اعتماد'.tr()),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    try {
      final message = await ApiService.reviewEngineerWork(
        id: id,
        approve: approve,
        note: note,
      );
      _toast(message);
      await _load();
    } on ApiException catch (e) {
      _toast(e.message, error: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('حذف العمل نهائيًا؟'.tr()),
        content: Text('سيتم حذف العمل وملفاته المرتبطة نهائيًا.'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('إلغاء'.tr()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('حذف'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final message = await ApiService.deleteAdminEngineerWork(_int(item['id']));
      _toast(message);
      await _load();
    } on ApiException catch (e) {
      _toast(e.message, error: true);
    }
  }

  Future<void> _exportVisible() async {
    final rows = <String>[
      [
        'العنوان'.tr(),
        'المهندس'.tr(),
        'التخصص'.tr(),
        'النوع'.tr(),
        'الموقع'.tr(),
        'الحالة'.tr(),
      ].join('\t'),
      ..._visible.map((item) => [
            _str(item['title']),
            _engineerName(item),
            _specialtyName(item),
            _str(item['project_type']),
            _str(item['location']),
            _statusLabel(_str(item['status'], 'pending')),
          ].join('\t')),
    ];
    await Clipboard.setData(ClipboardData(text: rows.join('\n')));
    _toast('تم نسخ التقرير ويمكن لصقه في Excel.'.tr());
  }

  void _showDetails(Map<String, dynamic> item) {
    final software = item['software_used'] is List
        ? List<dynamic>.from(item['software_used'] as List).join(', ')
        : _str(item['software_used'], '');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            4,
            18,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  trUi(_str(item['title'])),
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                _DetailRow('المهندس'.tr(), _engineerName(item)),
                _DetailRow('التخصص'.tr(), _specialtyName(item)),
                _DetailRow('نوع المشروع'.tr(), _str(item['project_type'])),
                _DetailRow('الموقع'.tr(), _str(item['location'])),
                _DetailRow('سنة الإنجاز'.tr(), _str(item['completion_year'])),
                _DetailRow('المساحة'.tr(), '${_str(item['area'])} ${_str(item['area_unit'], '')}'.trim()),
                _DetailRow('دور المهندس'.tr(), _str(item['project_role'])),
                if (software.isNotEmpty) _DetailRow('البرامج المستخدمة'.tr(), software),
                if (_str(item['description'], '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('الوصف'.tr(), style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(trUi(_str(item['description'], '')), style: const TextStyle(height: 1.6)),
                ],
                if (_str(item['admin_note'], '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('ملاحظة الإدارة'.tr(), style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(trUi(_str(item['admin_note'], '')), style: const TextStyle(height: 1.6)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
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
          title: Text('مراجعة أعمال المهندسين'.tr()),
          actions: [
            IconButton(onPressed: _load, tooltip: 'تحديث'.tr(), icon: const Icon(Icons.refresh_rounded)),
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('نظام مراجعة الجودة'.tr(), style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text('إجمالي الأعمال'.tr(), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        Text('${_items.length}', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: 'ابحث بالعنوان أو المهندس أو النوع أو الموقع...'.tr(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _status,
                            decoration: InputDecoration(labelText: 'حالة العمل'.tr()),
                            items: [
                              DropdownMenuItem(value: 'all', child: Text('كل الحالات'.tr())),
                              DropdownMenuItem(value: 'pending', child: Text('قيد المراجعة'.tr())),
                              DropdownMenuItem(value: 'approved', child: Text('مقبول'.tr())),
                              DropdownMenuItem(value: 'rejected', child: Text('مرفوض'.tr())),
                            ],
                            onChanged: (value) => setState(() => _status = value ?? 'all'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: 'تصدير التقرير'.tr(),
                          onPressed: _exportVisible,
                          icon: const Icon(Icons.download_outlined),
                        ),
                        const SizedBox(width: 6),
                        IconButton.filledTonal(
                          tooltip: 'المكتبة العامة'.tr(),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const EngineerLibraryScreen()),
                          ),
                          icon: const Icon(Icons.public_rounded),
                        ),
                      ],
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
                          ? Center(child: Text('لا توجد أعمال مطابقة.'.tr()))
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(14, 0, 14, 90),
                                itemCount: items.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  final status = _str(item['status'], 'pending');
                                  final image = _coverUrl(item);
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: surface,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(color: border),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Column(
                                      children: [
                                        if (image != null)
                                          AspectRatio(
                                            aspectRatio: 16 / 7,
                                            child: Image.network(
                                              image,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Container(
                                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                                child: const Icon(Icons.image_not_supported_outlined, size: 42),
                                              ),
                                            ),
                                          ),
                                        Padding(
                                          padding: const EdgeInsets.all(15),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: InkWell(
                                                      onTap: () => _showDetails(item),
                                                      child: Text(
                                                        trUi(_str(item['title'])),
                                                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                                                      ),
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                                    decoration: BoxDecoration(
                                                      color: _statusColor(status).withValues(alpha: .13),
                                                      borderRadius: BorderRadius.circular(999),
                                                    ),
                                                    child: Text(
                                                      trUi(_statusLabel(status)),
                                                      style: TextStyle(color: _statusColor(status), fontSize: 11, fontWeight: FontWeight.w900),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              Wrap(
                                                spacing: 12,
                                                runSpacing: 8,
                                                children: [
                                                  _Meta(Icons.engineering_outlined, _engineerName(item)),
                                                  _Meta(Icons.school_outlined, _specialtyName(item)),
                                                  _Meta(Icons.category_outlined, _str(item['project_type'], 'غير محدد'.tr())),
                                                  _Meta(Icons.location_on_outlined, _str(item['location'], 'الموقع غير محدد'.tr())),
                                                ],
                                              ),
                                              if (_str(item['admin_note'], '').isNotEmpty) ...[
                                                const SizedBox(height: 10),
                                                Text('${'ملاحظة الإدارة'.tr()}: ${item['admin_note']}'.tr(), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                              ],
                                              const SizedBox(height: 12),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: [
                                                  OutlinedButton.icon(
                                                    onPressed: () => _showDetails(item),
                                                    icon: const Icon(Icons.visibility_outlined),
                                                    label: Text('التفاصيل'.tr()),
                                                  ),
                                                  if (status != 'approved')
                                                    FilledButton.icon(
                                                      onPressed: () => _review(item, true),
                                                      icon: const Icon(Icons.check_rounded),
                                                      label: Text('اعتماد'.tr()),
                                                    ),
                                                  if (status != 'rejected')
                                                    FilledButton.tonalIcon(
                                                      onPressed: () => _review(item, false),
                                                      icon: const Icon(Icons.close_rounded),
                                                      label: Text('رفض'.tr()),
                                                    ),
                                                  OutlinedButton.icon(
                                                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                                                    onPressed: () => _delete(item),
                                                    icon: const Icon(Icons.delete_outline_rounded),
                                                    label: Text('حذف'.tr()),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
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

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta(this.icon, this.text);

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

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(trUi(label), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(trUi(value), style: const TextStyle(fontWeight: FontWeight.w800))),
          ],
        ),
      );
}
