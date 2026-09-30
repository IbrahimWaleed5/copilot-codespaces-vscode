import 'package:flutter/material.dart';

import '../i18n/localized_text.dart';
import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';
import 'project_boq_detail_screen.dart';

class ProjectBoqListScreen extends StatefulWidget {
  final int projectId;
  final String projectTitle;

  const ProjectBoqListScreen({
    super.key,
    required this.projectId,
    required this.projectTitle,
  });

  @override
  State<ProjectBoqListScreen> createState() => _ProjectBoqListScreenState();
}

class _ProjectBoqListScreenState extends State<ProjectBoqListScreen> {
  bool _loading = true;
  bool _canManage = false;
  bool _canApprove = false;
  String? _error;
  List<dynamic> _boqs = [];

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
      final data = await ApiService.fetchProjectBoqsAdvanced(widget.projectId);
      if (!mounted) return;
      setState(() {
        _boqs = data['boqs'] as List? ?? [];
        _canManage = data['can_manage'] == true;
        _canApprove = data['can_approve'] == true;
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
    final currency = TextEditingController(text: 'USD');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: AlertDialog(
          title: const TrText('إنشاء BOQ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: title, decoration: InputDecoration(labelText: 'العنوان'.tr())),
              const SizedBox(height: 8),
              TextField(controller: currency, decoration: InputDecoration(labelText: 'العملة'.tr())),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const TrText('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, title.text.trim().isNotEmpty), child: const TrText('إنشاء')),
          ],
        ),
      ),
    );
    final titleText = title.text.trim();
    final currencyText = currency.text.trim().isEmpty ? 'USD' : currency.text.trim();
    Future<void>.delayed(const Duration(milliseconds: 600), title.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), currency.dispose);
    if (ok != true) return;

    try {
      final message = await ApiService.createProjectBoqAdvanced(
        projectId: widget.projectId,
        title: titleText,
        currency: currencyText,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    }
  }

  Future<void> _action(int id, String action) async {
    String? note;
    if (['submit-review','return-draft','approve'].contains(action)) {
      final c = TextEditingController();
      note = await showDialog<String?>(
        context: context,
        builder: (dialogContext) => Directionality(
          textDirection: AppLanguage.instance.textDirection,
          child: AlertDialog(
            title: const TrText('ملاحظة - اختياري'),
            content: TextField(controller: c, minLines: 2, maxLines: 5),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const TrText('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, c.text.trim()), child: const TrText('متابعة')),
            ],
          ),
        ),
      );
      Future<void>.delayed(const Duration(milliseconds: 600), c.dispose);
      if (note == null) return;
    }
    try {
      final message = await ApiService.projectBoqActionAdvanced(widget.projectId, id, action, note: note);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    }
  }

  Future<void> _delete(int id) async {
    try {
      final message = await ApiService.deleteProjectBoqAdvanced(widget.projectId, id);
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
          appBar: AppBar(title: Text('BOQ — ${widget.projectTitle}')),
          floatingActionButton: _canManage
              ? FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.add), label: const Text('BOQ'))
              : null,
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(trUi(_error!)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: _boqs.isEmpty
                          ? ListView(children: [
                              SizedBox(height: 180),
                              Center(child: TrText('لا توجد جداول كميات', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : AppColors.textSecondary)))),
                            ])
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _boqs.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (_, i) {
                                final boq = Map<String, dynamic>.from(_boqs[i] as Map);
                                final id = int.parse(boq['id'].toString());
                                return Card(
                                  child: ListTile(
                                    onTap: () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => ProjectBoqDetailScreen(
                                            projectId: widget.projectId,
                                            boqId: id,
                                          ),
                                        ),
                                      );
                                      _load();
                                    },
                                    title: Text('${boq['boq_number'] ?? ''} / R${boq['revision_number'] ?? 1}'),
                                    subtitle: Text('${boq['title'] ?? ''}\n${boq['sections_count'] ?? 0} قسم • ${boq['items_count'] ?? 0} بند'.tr()),
                                    isThreeLine: true,
                                    trailing: (_canManage || _canApprove)
                                        ? PopupMenuButton<String>(
                                            onSelected: (v) {
                                              if (v == 'delete') {
                                                _delete(id);
                                              } else {
                                                _action(id, v);
                                              }
                                            },
                                            itemBuilder: (_) => [
                                              if (_canManage) const PopupMenuItem(value: 'submit-review', child: TrText('إرسال للمراجعة')),
                                              if (_canApprove) const PopupMenuItem(value: 'return-draft', child: TrText('إرجاع مسودة')),
                                              if (_canApprove) const PopupMenuItem(value: 'approve', child: TrText('اعتماد')),
                                              if (_canApprove) const PopupMenuItem(value: 'lock', child: TrText('قفل')),
                                              if (_canManage) const PopupMenuItem(value: 'revision', child: TrText('Revision جديد')),
                                              if (_canManage) const PopupMenuItem(value: 'delete', child: TrText('حذف Draft')),
                                            ],
                                          )
                                        : Text(trUi(boq['status']?.toString() ?? ''), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan), fontSize: 11)),
                                  ),
                                );
                              },
                            ),
                    ),
        ),
      );
}
