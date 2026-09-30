import 'package:flutter/material.dart';

import '../i18n/localized_text.dart';
import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';

class PlatformFeedbackScreen extends StatefulWidget {
  const PlatformFeedbackScreen({super.key});

  @override
  State<PlatformFeedbackScreen> createState() => _PlatformFeedbackScreenState();
}

class _PlatformFeedbackScreenState extends State<PlatformFeedbackScreen> {
  bool _loading = true;
  bool _sending = false;
  String? _error;
  List<dynamic> _items = [];

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
      final data = await ApiService.fetchMyFeedback();
      if (!mounted) return;
      setState(() => _items = data['items'] as List? ?? []);
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final title = TextEditingController();
    final message = TextEditingController();
    String type = 'opinion';
    int rating = 5;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const TrText('الآراء والملاحظات'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<String>(
                    value: type,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'opinion', child: TrText('رأي')),
                      DropdownMenuItem(value: 'suggestion', child: TrText('اقتراح')),
                      DropdownMenuItem(value: 'note', child: TrText('ملاحظة')),
                      DropdownMenuItem(value: 'complaint', child: TrText('شكوى')),
                      DropdownMenuItem(value: 'technical_issue', child: TrText('مشكلة تقنية')),
                    ],
                    onChanged: (v) => setDialogState(() => type = v ?? type),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: title, decoration: InputDecoration(labelText: 'العنوان'.tr())),
                  const SizedBox(height: 10),
                  TextField(
                    controller: message,
                    minLines: 4,
                    maxLines: 7,
                    decoration: InputDecoration(labelText: 'المحتوى'.tr()),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const TrText('التقييم'),
                      Expanded(
                        child: Slider(
                          value: rating.toDouble(),
                          min: 1,
                          max: 5,
                          divisions: 4,
                          label: rating.toString(),
                          onChanged: (v) => setDialogState(() => rating = v.round()),
                        ),
                      ),
                      Text('$rating/5'),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const TrText('إلغاء')),
              FilledButton(
                onPressed: () {
                  if (title.text.trim().isEmpty || message.text.trim().length < 5) return;
                  Navigator.pop(dialogContext, {
                    'type': type,
                    'title': title.text.trim(),
                    'message': message.text.trim(),
                    'rating': rating,
                  });
                },
                child: const TrText('إرسال'),
              ),
            ],
          ),
        ),
      ),
    );

    Future<void>.delayed(const Duration(milliseconds: 600), title.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), message.dispose);
    if (result == null) return;

    setState(() => _sending = true);
    try {
      final text = await ApiService.submitPlatformFeedback(
        type: result['type'] as String,
        title: result['title'] as String,
        message: result['message'] as String,
        rating: result['rating'] as int,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(text))));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        appBar: AppBar(title: const TrText('الآراء والملاحظات')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _sending ? null : _create,
          icon: const Icon(Icons.add_comment_outlined),
          label: Text(trUi(_sending ? 'جارٍ الإرسال...' : 'إضافة ملاحظة')),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(trUi(_error!)))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _items.isEmpty
                        ? ListView(children: [
                            SizedBox(height: 180),
                            Center(child: TrText('لا توجد ملاحظات مرسلة بعد', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant)))),
                          ])
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = Map<String, dynamic>.from(_items[index] as Map);
                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(child: Text(trUi(item['title']?.toString() ?? ''), style: const TextStyle(fontWeight: FontWeight.w800))),
                                          Text(trUi(item['status']?.toString() ?? ''), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan), fontSize: 11)),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(trUi(item['message']?.toString() ?? ''), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
                                      if ((item['admin_reply']?.toString() ?? '').isNotEmpty) ...[
                                        const Divider(height: 22),
                                        const TrText('رد الإدارة', style: TextStyle(fontWeight: FontWeight.w800)),
                                        const SizedBox(height: 4),
                                        Text(trUi(item['admin_reply'].toString())),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
      ),
    );
  }
}
