import 'package:flutter/material.dart';

import '../i18n/localized_text.dart';
import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';

class AdminFeedbackScreen extends StatefulWidget {
  const AdminFeedbackScreen({super.key});

  @override
  State<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends State<AdminFeedbackScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _items = [];
  Map<String, dynamic> _summary = {};

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
      final data = await ApiService.fetchAdminFeedback();
      if (!mounted) return;
      setState(() {
        _items = data['items'] as List? ?? [];
        _summary = Map<String, dynamic>.from(data['summary'] as Map? ?? {});
      });
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _action(int id, String action) async {
    try {
      final message = await ApiService.adminFeedbackAction(id, action);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    }
  }

  Future<void> _reply(int id, String oldReply) async {
    final controller = TextEditingController(text: oldReply);
    final text = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: AlertDialog(
          title: const TrText('رد الإدارة'),
          content: TextField(controller: controller, minLines: 3, maxLines: 7),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const TrText('إلغاء')),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
              child: const TrText('حفظ'),
            ),
          ],
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 600), controller.dispose);
    if (text == null || text.length < 2) return;
    try {
      final message = await ApiService.adminFeedbackReply(id, text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: Scaffold(
          appBar: AppBar(title: const TrText('إدارة الآراء والملاحظات')),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(trUi(_error!)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _stat('الكل', _summary['total']),
                              _stat('قيد المراجعة', _summary['pending']),
                              _stat('معتمد', _summary['approved']),
                              _stat('مميز', _summary['featured']),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ..._items.map((raw) {
                            final item = Map<String, dynamic>.from(raw as Map);
                            final id = int.parse(item['id'].toString());
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: Text(trUi(item['title']?.toString() ?? ''), style: const TextStyle(fontWeight: FontWeight.w800))),
                                        PopupMenuButton<String>(
                                          onSelected: (value) {
                                            if (value == 'reply') {
                                              _reply(id, item['admin_reply']?.toString() ?? '');
                                            } else {
                                              _action(id, value);
                                            }
                                          },
                                          itemBuilder: (_) => const [
                                            PopupMenuItem(value: 'approve', child: TrText('اعتماد')),
                                            PopupMenuItem(value: 'reject', child: TrText('رفض')),
                                            PopupMenuItem(value: 'archive', child: TrText('أرشفة')),
                                            PopupMenuItem(value: 'featured', child: TrText('تمييز/إلغاء التمييز')),
                                            PopupMenuItem(value: 'reply', child: TrText('رد الإدارة')),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Text('${item['name'] ?? '-'} • ${item['email'] ?? '-'}', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 11)),
                                    const SizedBox(height: 8),
                                    Text(trUi(item['message']?.toString() ?? '')),
                                    const SizedBox(height: 8),
                                    TrText('الحالة: ${item['status'] ?? '-'} • التقييم: ${item['rating'] ?? '-'}', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan), fontSize: 11)),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
        ),
      );

  Widget _stat(String title, dynamic value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF0D1B31) : AppColors.surface),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? Color(0x1AFFFFFF) : AppColors.borderSoft)),
        ),
        child: Text('$title: ${value ?? 0}', style: const TextStyle(fontWeight: FontWeight.w700)),
      );
}
