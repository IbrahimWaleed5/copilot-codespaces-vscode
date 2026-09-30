import 'package:flutter/material.dart';

import '../i18n/localized_text.dart';
import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';

class ProjectCalendarScreen extends StatefulWidget {
  final int projectId;
  final String projectTitle;

  const ProjectCalendarScreen({
    super.key,
    required this.projectId,
    required this.projectTitle,
  });

  @override
  State<ProjectCalendarScreen> createState() => _ProjectCalendarScreenState();
}

class _ProjectCalendarScreenState extends State<ProjectCalendarScreen> {
  bool _loading = true;
  bool _canManage = false;
  List<dynamic> _events = [];
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
      final data = await ApiService.fetchProjectCalendarAdvanced(widget.projectId);
      if (!mounted) return;
      setState(() {
        _events = data['events'] as List? ?? [];
        _canManage = data['can_manage'] == true;
      });
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final title = TextEditingController();
    final start = TextEditingController();
    final end = TextEditingController();
    final location = TextEditingController();
    String type = 'custom';
    String priority = 'normal';

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const TrText('إضافة موعد'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: title, decoration: InputDecoration(labelText: 'العنوان'.tr())),
                  const SizedBox(height: 8),
                  TextField(controller: start, decoration: InputDecoration(labelText: 'البداية YYYY-MM-DD HH:mm'.tr())),
                  const SizedBox(height: 8),
                  TextField(controller: end, decoration: InputDecoration(labelText: 'النهاية - اختياري'.tr())),
                  const SizedBox(height: 8),
                  TextField(controller: location, decoration: InputDecoration(labelText: 'المكان - اختياري'.tr())),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    value: type,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'custom', child: TrText('موعد')),
                      DropdownMenuItem(value: 'deadline', child: TrText('موعد نهائي')),
                      DropdownMenuItem(value: 'site_visit', child: TrText('زيارة موقع')),
                      DropdownMenuItem(value: 'review', child: TrText('مراجعة')),
                      DropdownMenuItem(value: 'delivery', child: TrText('تسليم')),
                      DropdownMenuItem(value: 'client', child: TrText('عميل')),
                      DropdownMenuItem(value: 'internal', child: TrText('داخلي')),
                      DropdownMenuItem(value: 'other', child: TrText('أخرى')),
                    ],
                    onChanged: (v) => setDialogState(() => type = v ?? type),
                  ),
                  DropdownButton<String>(
                    value: priority,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'low', child: TrText('منخفض')),
                      DropdownMenuItem(value: 'normal', child: TrText('عادي')),
                      DropdownMenuItem(value: 'high', child: TrText('مرتفع')),
                      DropdownMenuItem(value: 'urgent', child: TrText('عاجل')),
                    ],
                    onChanged: (v) => setDialogState(() => priority = v ?? priority),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const TrText('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, title.text.trim().isNotEmpty && start.text.trim().isNotEmpty), child: const TrText('حفظ')),
            ],
          ),
        ),
      ),
    );

    final titleText = title.text.trim();
    final startText = start.text.trim();
    final endText = end.text.trim();
    final locationText = location.text.trim();
    Future<void>.delayed(const Duration(milliseconds: 600), title.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), start.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), end.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), location.dispose);
    if (ok != true) return;

    try {
      final message = await ApiService.saveProjectCalendarEventAdvanced(
        projectId: widget.projectId,
        title: titleText,
        type: type,
        priority: priority,
        startAt: startText,
        endAt: endText.isEmpty ? null : endText,
        location: locationText.isEmpty ? null : locationText,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    }
  }

  Future<void> _action(int id, String action) async {
    String? reason;
    if (action == 'cancel') {
      final c = TextEditingController();
      reason = await showDialog<String?>(
        context: context,
        builder: (dialogContext) => Directionality(
          textDirection: AppLanguage.instance.textDirection,
          child: AlertDialog(
            title: const TrText('سبب الإلغاء'),
            content: TextField(controller: c, minLines: 2, maxLines: 5),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const TrText('رجوع')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, c.text.trim()), child: const TrText('إلغاء الموعد')),
            ],
          ),
        ),
      );
      Future<void>.delayed(const Duration(milliseconds: 600), c.dispose);
      if (reason == null || reason.isEmpty) return;
    }
    try {
      final message = await ApiService.projectCalendarActionAdvanced(widget.projectId, id, action, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    }
  }

  Future<void> _delete(int id) async {
    try {
      final message = await ApiService.deleteProjectCalendarEventAdvanced(widget.projectId, id);
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
          appBar: AppBar(title: TrText('تقويم المشروع — ${widget.projectTitle}')),
          floatingActionButton: _canManage
              ? FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.add), label: const TrText('موعد'))
              : null,
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(trUi(_error!)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: _events.isEmpty
                          ? ListView(children: [
                              SizedBox(height: 180),
                              Center(child: TrText('لا توجد مواعيد', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : AppColors.textSecondary)))),
                            ])
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _events.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (_, i) {
                                final event = Map<String, dynamic>.from(_events[i] as Map);
                                final id = int.parse(event['id'].toString());
                                return Card(
                                  child: ListTile(
                                    leading: Icon(Icons.event_outlined, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan)),
                                    title: Text(trUi(event['title']?.toString() ?? '')),
                                    subtitle: Text('${event['start_at'] ?? ''}\n${event['location'] ?? ''}'),
                                    isThreeLine: true,
                                    trailing: _canManage
                                        ? PopupMenuButton<String>(
                                            onSelected: (v) {
                                              if (v == 'delete') {
                                                _delete(id);
                                              } else {
                                                _action(id, v);
                                              }
                                            },
                                            itemBuilder: (_) => const [
                                              PopupMenuItem(value: 'complete', child: TrText('إكمال')),
                                              PopupMenuItem(value: 'cancel', child: TrText('إلغاء')),
                                              PopupMenuItem(value: 'delete', child: TrText('حذف')),
                                            ],
                                          )
                                        : null,
                                  ),
                                );
                              },
                            ),
                    ),
        ),
      );
}
