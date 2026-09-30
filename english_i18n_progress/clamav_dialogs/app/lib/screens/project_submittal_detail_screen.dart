import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../i18n/localized_text.dart';
import 'package:open_filex/open_filex.dart';

import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';

class ProjectSubmittalDetailScreen extends StatefulWidget {
  final int projectId;
  final int submittalId;
  const ProjectSubmittalDetailScreen({super.key, required this.projectId, required this.submittalId});

  @override
  State<ProjectSubmittalDetailScreen> createState() => _ProjectSubmittalDetailScreenState();
}

class _ProjectSubmittalDetailScreenState extends State<ProjectSubmittalDetailScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.fetchProjectSubmittalAdvanced(widget.projectId, widget.submittalId);
      if (mounted) setState(() => _data = data);
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (mounted) setState(() => _error = e.message);
    } finally { if (mounted) setState(() => _loading = false); }
  }

  Future<String?> _ask(String title, {String label = 'ملاحظات'}) async {
    final c = TextEditingController();
    final result = await showDialog<String>(context: context, builder: (d) => Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: AlertDialog(title: Text(title.tr()), content: TextField(controller: c, maxLines: 4, decoration: InputDecoration(labelText: label.tr())), actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const TrText('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: const TrText('حفظ')),
      ]),
    ));
    Future<void>.delayed(const Duration(milliseconds: 600), c.dispose);
    return result;
  }

  Future<void> _review() async {
    var decision = 'approved';
    final comment = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (d) => StatefulBuilder(builder: (context, setLocal) => Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: AlertDialog(title: const TrText('نتيجة المراجعة'), content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(initialValue: decision, decoration: InputDecoration(labelText: 'القرار'.tr()), items: const [
          DropdownMenuItem(value: 'approved', child: TrText('معتمد')),
          DropdownMenuItem(value: 'approved_as_noted', child: TrText('معتمد بملاحظات')),
          DropdownMenuItem(value: 'revise_resubmit', child: TrText('تعديل وإعادة تقديم')),
          DropdownMenuItem(value: 'rejected', child: TrText('مرفوض')),
        ], onChanged: (v) => setLocal(() => decision = v ?? decision)),
        const SizedBox(height: 10),
        TextField(controller: comment, maxLines: 4, decoration: InputDecoration(labelText: 'ملاحظة المراجعة *'.tr())),
      ]), actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const TrText('إلغاء')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const TrText('اعتماد القرار'))]),
    )));
    if (ok != true || comment.text.trim().isEmpty) return;
    await _run(() => ApiService.reviewProjectSubmittalAdvanced(projectId: widget.projectId, submittalId: widget.submittalId, decision: decision, comment: comment.text.trim()));
    Future<void>.delayed(const Duration(milliseconds: 600), comment.dispose);
  }

  Future<void> _revision() async {
    final picked = await FilePicker.pickFiles();
    final files = picked.where((e) => e.path != null).take(10).map((e) => File(e.path!)).toList();
    if (files.isEmpty) return;
    final description = await _ask('Revision جديد', label: 'وصف التعديل *');
    if (description == null || description.isEmpty) return;
    await _run(() => ApiService.addProjectSubmittalRevisionAdvanced(projectId: widget.projectId, submittalId: widget.submittalId, description: description, attachments: files));
  }

  Future<void> _action(String action, String title) async {
    String? reason;
    if (action != 'reopen') {
      reason = await _ask(title, label: action == 'cancel' ? 'سبب الإلغاء' : 'ملاحظات الإغلاق');
      if (reason == null) return;
    }
    await _run(() => ApiService.projectSubmittalActionAdvanced(projectId: widget.projectId, submittalId: widget.submittalId, action: action, reason: reason));
  }

  Future<void> _run(Future<String> Function() action) async {
    try {
      final msg = await action();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(msg))));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    }
  }

  Future<void> _download(Map<String, dynamic> attachment) async {
    final id = int.tryParse(attachment['id']?.toString() ?? '') ?? 0;
    final name = attachment['original_name']?.toString() ?? attachment['name']?.toString() ?? 'attachment';
    try {
      final file = await ApiService.downloadAttachment(urlPath: 'projects/${widget.projectId}/submittals/${widget.submittalId}/attachments/$id/download', fileName: name);
      await OpenFilex.open(file.path);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(textDirection: AppLanguage.instance.textDirection, child: Scaffold(
    appBar: AppBar(title: const TrText('تفاصيل Submittal')),
    body: _body(),
  ));

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(trUi(_error!)));
    final s = Map<String, dynamic>.from(_data?['submittal'] as Map? ?? const {});
    final attachments = List<dynamic>.from(s['attachments'] as List? ?? const []);
    final revisions = List<dynamic>.from(s['revisions'] as List? ?? const []);
    return RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: [
      _Card(title: '${s['submittal_number'] ?? ''} — ${s['title'] ?? ''}', lines: [
        'الحالة: ${s['status'] ?? '-'}',
        'النوع: ${s['type'] ?? '-'}',
        'الأولوية: ${s['priority'] ?? '-'}',
        if (s['specification_section'] != null) 'قسم المواصفات: ${s['specification_section']}',
        if (s['due_at'] != null) 'الاستحقاق: ${s['due_at']}',
        '',
        s['description']?.toString() ?? '',
      ]),
      if (s['review_comment'] != null) ...[const SizedBox(height: 10), _Card(title: 'ملاحظات المراجعة', lines: [s['review_comment'].toString()])],
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (_data?['can_review'] == true) FilledButton.icon(onPressed: _review, icon: const Icon(Icons.fact_check_rounded), label: const TrText('مراجعة')),
        if (_data?['can_revision'] == true) OutlinedButton.icon(onPressed: _revision, icon: const Icon(Icons.upload_file_rounded), label: const Text('Revision')),
        if (_data?['can_close'] == true) OutlinedButton(onPressed: () => _action('close', 'إغلاق Submittal'), child: const TrText('إغلاق')),
        if (_data?['can_reopen'] == true) OutlinedButton(onPressed: () => _action('reopen', 'إعادة فتح'), child: const TrText('إعادة فتح')),
        if (_data?['can_cancel'] == true) OutlinedButton(onPressed: () => _action('cancel', 'إلغاء Submittal'), child: const TrText('إلغاء')),
      ]),
      const SizedBox(height: 18),
      const TrText('المرفقات', style: TextStyle(fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      if (attachments.isEmpty) TrText('لا يوجد مرفقات', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))) else ...attachments.map((raw) {
        final a = Map<String, dynamic>.from(raw as Map);
        return Card(child: ListTile(leading: const Icon(Icons.attach_file_rounded), title: Text(trUi(a['original_name']?.toString() ?? 'ملف')), trailing: IconButton(onPressed: () => _download(a), icon: const Icon(Icons.download_rounded))));
      }),
      if (revisions.isNotEmpty) ...[
        const SizedBox(height: 18),
        const TrText('الإصدارات / Revisions', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        ...revisions.map((raw) { final r = Map<String, dynamic>.from(raw as Map); return Card(child: ListTile(title: Text('R${r['revision_number'] ?? '-'}'), subtitle: Text('${r['description'] ?? ''}\n${r['status'] ?? ''}'))); }),
      ],
    ]));
  }
}

class _Card extends StatelessWidget {
  final String title;
  final List<String> lines;
  const _Card({required this.title, required this.lines});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF0D1B31) : AppColors.surface), borderRadius: BorderRadius.circular(18), border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? Color(0x1AFFFFFF) : AppColors.borderSoft))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(trUi(title), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)), const SizedBox(height: 10), ...lines.where((e) => e.isNotEmpty).map((e) => Padding(padding: const EdgeInsets.only(bottom: 5), child: Text(trUi(e), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : AppColors.textSecondary), height: 1.5))))]));
}
