import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../i18n/localized_text.dart';
import 'package:open_filex/open_filex.dart';

import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';

class MilestoneSubmissionsScreen extends StatefulWidget {
  final int projectId;
  final int milestoneId;
  final String milestoneTitle;

  const MilestoneSubmissionsScreen({
    super.key,
    required this.projectId,
    required this.milestoneId,
    required this.milestoneTitle,
  });

  @override
  State<MilestoneSubmissionsScreen> createState() => _MilestoneSubmissionsScreenState();
}

class _MilestoneSubmissionsScreenState extends State<MilestoneSubmissionsScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _saving = false;
  int? _downloadingId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.fetchMilestoneSubmissions(
        projectId: widget.projectId,
        milestoneId: widget.milestoneId,
      );
      if (mounted) setState(() => _data = data);
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _statusLabel(String? status) {
    const labels = {
      'pending': 'بانتظار المراجعة',
      'approved': 'معتمد',
      'rejected': 'مرفوض',
    };
    return labels[status] ?? status ?? '-';
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.danger;
      default:
        return Colors.orangeAccent;
    }
  }

  Future<void> _submit() async {
    final installments = (_data?['held_installments'] as List? ?? const []);
    if (installments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TrText('لا توجد دفعة محتجزة في Escrow مرتبطة بتسليم جديد.')),
      );
      return;
    }

    int installmentId = (installments.first as Map<String, dynamic>)['id'] as int;
    final title = TextEditingController(text: widget.milestoneTitle);
    final notes = TextEditingController();
    File? selectedFile;
    String? selectedName;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: AppLanguage.instance.textDirection,
          child: AlertDialog(
            title: const TrText('تسليم المرحلة'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: installmentId,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: 'دفعة الضمان'.tr()),
                    items: installments.map((raw) {
                      final item = raw as Map<String, dynamic>;
                      return DropdownMenuItem<int>(
                        value: item['id'] as int,
                        child: Text('${item['title'] ?? 'دفعة'.tr()} — ${item['amount'] ?? 0} ₪'.tr(), overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (value) => setDialogState(() => installmentId = value ?? installmentId),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: title, decoration: InputDecoration(labelText: 'عنوان التسليم'.tr())),
                  const SizedBox(height: 10),
                  TextField(controller: notes, minLines: 2, maxLines: 5, decoration: InputDecoration(labelText: 'ملاحظات - اختياري'.tr())),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await FilePicker.pickFile(
                        type: FileType.custom,
                        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'dwg', 'dxf', 'zip', 'rar'],
                      );
                      if (picked?.path == null) return;
                      setDialogState(() {
                        selectedFile = File(picked!.path!);
                        selectedName = picked.name;
                      });
                    },
                    icon: const Icon(Icons.attach_file_rounded),
                    label: Text(selectedName ?? 'إرفاق ملف - اختياري'.tr()),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const TrText('إلغاء')),
              ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const TrText('إرسال')),
            ],
          ),
        ),
      ),
    );

    final titleText = title.text.trim();
    final notesText = notes.text.trim();
    Future<void>.delayed(const Duration(milliseconds: 600), title.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), notes.dispose);
    if (confirmed != true || titleText.isEmpty) return;

    setState(() => _saving = true);
    try {
      final message = await ApiService.submitMilestoneSubmission(
        projectId: widget.projectId,
        milestoneId: widget.milestoneId,
        installmentId: installmentId,
        title: titleText,
        notes: notesText.isEmpty ? null : notesText,
        file: selectedFile,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _review(Map<String, dynamic> submission, bool approve) async {
    final controller = TextEditingController();
    final notes = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: AlertDialog(
          title: Text(trUi(approve ? 'اعتماد التسليم' : 'رفض التسليم')),
          content: TextField(
            controller: controller,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(labelText: trUi(approve ? 'ملاحظات - اختياري' : 'سبب الرفض')),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const TrText('إلغاء')),
            ElevatedButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: Text(trUi(approve ? 'اعتماد' : 'رفض'))),
          ],
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 600), controller.dispose);
    if (notes == null || (!approve && notes.isEmpty)) return;

    setState(() => _saving = true);
    try {
      final message = await ApiService.reviewMilestoneSubmission(
        projectId: widget.projectId,
        milestoneId: widget.milestoneId,
        submissionId: submission['id'] as int,
        approve: approve,
        notes: notes.isEmpty ? null : notes,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _download(Map<String, dynamic> submission) async {
    final id = submission['id'] as int;
    setState(() => _downloadingId = id);
    try {
      final file = await ApiService.downloadMilestoneSubmission(
        projectId: widget.projectId,
        milestoneId: widget.milestoneId,
        submissionId: id,
        fileName: 'milestone-${widget.milestoneId}-revision-${submission['revision_number'] ?? id}',
      );
      await OpenFilex.open(file.path);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    } finally {
      if (mounted) setState(() => _downloadingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        appBar: AppBar(title: TrText('تسليمات — ${widget.milestoneTitle}')),
        floatingActionButton: _data?['can_submit'] == true
            ? FloatingActionButton.extended(
                onPressed: _saving ? null : _submit,
                icon: const Icon(Icons.upload_file_outlined),
                label: const TrText('تسليم جديد'),
              )
            : null,
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: ElevatedButton(onPressed: _load, child: Text(trUi(_error!))));
    final submissions = (_data?['submissions'] as List? ?? const []);
    final canReview = _data?['can_review'] == true;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        children: [
          if (submissions.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(18), child: TrText('لا توجد تسليمات لهذه المرحلة بعد.')))
          else
            ...submissions.map((raw) {
              final submission = raw as Map<String, dynamic>;
              final status = submission['status']?.toString();
              final color = _statusColor(status);
              final submitter = submission['submitter'] as Map<String, dynamic>?;
              final hasFile = submission['file_path'] != null;
              return Card(
                margin: const EdgeInsets.only(bottom: 11),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Revision ${submission['revision_number'] ?? '-'} — ${submission['title'] ?? ''}',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(999)),
                            child: Text(trUi(_statusLabel(status)), style: TextStyle(fontSize: 11, color: color)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TrText('بواسطة: ${submitter?['name'] ?? '-'}', style: TextStyle(fontSize: 11, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
                      if ((submission['notes']?.toString() ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(trUi(submission['notes'].toString()), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), height: 1.5)),
                      ],
                      if ((submission['review_notes']?.toString() ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        TrText('ملاحظات المراجعة: ${submission['review_notes']}', style: TextStyle(fontSize: 12, color: color)),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (hasFile)
                            OutlinedButton.icon(
                              onPressed: _downloadingId == submission['id'] ? null : () => _download(submission),
                              icon: const Icon(Icons.download_outlined),
                              label: const TrText('تنزيل الملف'),
                            ),
                          if (canReview && status == 'pending')
                            ElevatedButton(onPressed: _saving ? null : () => _review(submission, true), child: const TrText('اعتماد')),
                          if (canReview && status == 'pending')
                            OutlinedButton(onPressed: _saving ? null : () => _review(submission, false), child: const TrText('رفض')),
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
