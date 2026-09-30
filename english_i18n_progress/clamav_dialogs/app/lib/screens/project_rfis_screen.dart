import 'dart:io';

import 'package:file_picker/file_picker.dart';
import '../utils/app_file_picker.dart';
import 'package:flutter/material.dart';
import '../i18n/localized_text.dart';
import 'package:open_filex/open_filex.dart';

import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';

class ProjectRfisScreen extends StatefulWidget {
  final int projectId;
  final String projectTitle;

  const ProjectRfisScreen({
    super.key,
    required this.projectId,
    required this.projectTitle,
  });

  @override
  State<ProjectRfisScreen> createState() => _ProjectRfisScreenState();
}

class _ProjectRfisScreenState extends State<ProjectRfisScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(trUi(message))),
    );
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.fetchProjectRfis(projectId: widget.projectId);
      if (mounted) setState(() => _data = data);
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _statusLabel(String? value) {
    const labels = {
      'open': 'مفتوح',
      'reopened': 'أعيد فتحه',
      'answered': 'تمت الإجابة',
      'closed': 'مغلق',
      'cancelled': 'ملغي',
    };
    return labels[value] ?? value ?? '-';
  }

  String _priorityLabel(String? value) {
    const labels = {
      'low': 'منخفض',
      'normal': 'عادي',
      'high': 'مرتفع',
      'urgent': 'عاجل',
    };
    return labels[value] ?? value ?? '-';
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'answered':
      case 'closed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.danger;
      case 'reopened':
        return Colors.orangeAccent;
      default:
        return (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan);
    }
  }

  Future<void> _create() async {
    final subject = TextEditingController();
    final question = TextEditingController();
    String priority = 'normal';
    List<File> attachments = [];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: AppLanguage.instance.textDirection,
          child: AlertDialog(
            title: const TrText('RFI جديد'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: subject, decoration: InputDecoration(labelText: 'الموضوع'.tr())),
                  const SizedBox(height: 10),
                  TextField(
                    controller: question,
                    minLines: 4,
                    maxLines: 8,
                    decoration: InputDecoration(labelText: 'السؤال / طلب التوضيح'.tr()),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: priority,
                    decoration: InputDecoration(labelText: 'الأولوية'.tr()),
                    items: const [
                      DropdownMenuItem(value: 'low', child: TrText('منخفض')),
                      DropdownMenuItem(value: 'normal', child: TrText('عادي')),
                      DropdownMenuItem(value: 'high', child: TrText('مرتفع')),
                      DropdownMenuItem(value: 'urgent', child: TrText('عاجل')),
                    ],
                    onChanged: (value) => setDialogState(() => priority = value ?? 'normal'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await AppFilePicker.pickFiles(
                        allowMultiple: true,
                        type: FileType.custom,
                        allowedExtensions: const ['pdf','jpg','jpeg','png','dwg','dxf','doc','docx','xls','xlsx','zip','rar'],
                      );
                      if (picked.isEmpty) return;
                      setDialogState(() {
                        attachments = picked.where((e) => e.path != null).take(10).map((e) => File(e.path!)).toList();
                      });
                    },
                    icon: const Icon(Icons.attach_file_rounded),
                    label: Text(trUi(attachments.isEmpty ? 'إضافة مرفقات' : '${attachments.length} مرفق')),
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

    final subjectText = subject.text.trim();
    final questionText = question.text.trim();
    Future<void>.delayed(const Duration(milliseconds: 600), subject.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), question.dispose);
    if (confirmed != true || subjectText.length < 3 || questionText.length < 10) return;

    setState(() => _saving = true);
    try {
      final message = await ApiService.createProjectRfi(
        projectId: widget.projectId,
        subject: subjectText,
        question: questionText,
        priority: priority,
        attachments: attachments,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _ask(String title, String label, {int min = 2}) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: AlertDialog(
          title: Text(trUi(title)),
          content: TextField(
            controller: controller,
            minLines: 3,
            maxLines: 7,
            decoration: InputDecoration(labelText: trUiN(label)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const TrText('إلغاء')),
            ElevatedButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const TrText('حفظ')),
          ],
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 600), controller.dispose);
    if (result == null || result.length < min) return null;
    return result;
  }

  Future<_RfiMessageDraft?> _askWithAttachments(String title, String label, {int min = 2}) async {
    final controller = TextEditingController();
    List<File> attachments = [];
    final result = await showDialog<_RfiMessageDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: AppLanguage.instance.textDirection,
          child: AlertDialog(
            title: Text(trUi(title)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    minLines: 3,
                    maxLines: 7,
                    decoration: InputDecoration(labelText: trUiN(label)),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await AppFilePicker.pickFiles(
                        allowMultiple: true,
                        type: FileType.custom,
                        allowedExtensions: const ['pdf','jpg','jpeg','png','dwg','dxf','doc','docx','xls','xlsx','zip','rar'],
                      );
                      if (picked.isEmpty) return;
                      setDialogState(() {
                        attachments = picked.where((e) => e.path != null).take(10).map((e) => File(e.path!)).toList();
                      });
                    },
                    icon: const Icon(Icons.attach_file_rounded),
                    label: Text(trUi(attachments.isEmpty ? 'إضافة مرفقات' : '${attachments.length} مرفق')),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const TrText('إلغاء')),
              ElevatedButton(
                onPressed: () {
                  final text = controller.text.trim();
                  if (text.length < min) return;
                  Navigator.pop(dialogContext, _RfiMessageDraft(text, attachments));
                },
                child: const TrText('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 600), controller.dispose);
    return result;
  }

  Future<void> _openAttachment(int rfiId, Map<String, dynamic> attachment) async {
    final attachmentId = int.tryParse(attachment['id']?.toString() ?? '') ?? 0;
    if (attachmentId <= 0) return;
    final name = attachment['original_name']?.toString() ?? 'rfi-attachment';
    try {
      final file = await ApiService.downloadProjectRfiAttachment(
        projectId: widget.projectId,
        rfiId: rfiId,
        attachmentId: attachmentId,
        fileName: name,
      );
      final result = await OpenFilex.open(file.path);
      if (mounted && result.type != ResultType.done) {
        _snack('تم تنزيل المرفق لكن تعذر فتحه تلقائيًا.'.tr());
      }
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    }
  }

  Widget _attachmentTile(int rfiId, Map<String, dynamic> attachment) {
    return Card(
      margin: const EdgeInsets.only(top: 6),
      child: ListTile(
        dense: true,
        leading: Icon(Icons.attach_file_rounded, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan)),
        title: Text(attachment['original_name']?.toString() ?? 'مرفق'.tr()),
        subtitle: Text(trUi(attachment['mime_type']?.toString() ?? ''), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 11)),
        trailing: const Icon(Icons.open_in_new_rounded, size: 18),
        onTap: () => _openAttachment(rfiId, attachment),
      ),
    );
  }

  Future<void> _openRfi(int rfiId) async {
    Map<String, dynamic>? detail;
    try {
      detail = await ApiService.fetchProjectRfi(projectId: widget.projectId, rfiId: rfiId);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
      return;
    }
    if (!mounted) return;

    final rfi = (detail['rfi'] as Map<String, dynamic>?) ?? const {};
    final permissions = (detail['permissions'] as Map<String, dynamic>?) ?? const {};
    final activities = (rfi['activities'] as List? ?? const []);
    final rfiIdValue = int.tryParse(rfi['id']?.toString() ?? '') ?? rfiId;
    final rootAttachments = (rfi['attachments'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => e['project_rfi_activity_id'] == null)
        .toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF0D1B31) : Theme.of(context).colorScheme.surface),
      builder: (sheetContext) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: .86,
          minChildSize: .55,
          maxChildSize: .96,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      trUi(rfi['rfi_number']?.toString() ?? 'RFI'),
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                    ),
                  ),
                  _badge(_statusLabel(rfi['status']?.toString()), _statusColor(rfi['status']?.toString())),
                ],
              ),
              const SizedBox(height: 10),
              Text(trUi(rfi['subject']?.toString() ?? ''), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              Text(trUi(rfi['question']?.toString() ?? ''), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), height: 1.6)),
              if (rootAttachments.isNotEmpty) ...[
                const SizedBox(height: 12),
                const TrText('المرفقات', style: TextStyle(fontWeight: FontWeight.w800)),
                ...rootAttachments.map((attachment) => _attachmentTile(rfiIdValue, attachment)),
              ],
              if ((rfi['answer']?.toString() ?? '').isNotEmpty) ...[
                const SizedBox(height: 16),
                const TrText('الإجابة الرسمية', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(trUi(rfi['answer'].toString()), style: const TextStyle(height: 1.55)),
                ),
              ],
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (permissions['can_answer'] == true)
                    OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(sheetContext);
                        final draft = await _askWithAttachments('إجابة RFI', 'الإجابة الرسمية', min: 3);
                        if (draft != null) await _answer(rfiId, draft.text, draft.attachments);
                      },
                      icon: const Icon(Icons.reply_outlined),
                      label: const TrText('إجابة'),
                    ),
                  if (permissions['can_comment'] == true)
                    OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(sheetContext);
                        final draft = await _askWithAttachments('تعليق', 'التعليق');
                        if (draft != null) await _comment(rfiId, draft.text, draft.attachments);
                      },
                      icon: const Icon(Icons.comment_outlined),
                      label: const TrText('تعليق'),
                    ),
                  if (permissions['can_close'] == true)
                    OutlinedButton(onPressed: () async { Navigator.pop(sheetContext); await _status(rfiId, 'close'); }, child: const TrText('إغلاق')),
                  if (permissions['can_reopen'] == true)
                    OutlinedButton(onPressed: () async { Navigator.pop(sheetContext); await _status(rfiId, 'reopen', needsReason: true); }, child: const TrText('إعادة فتح')),
                  if (permissions['can_cancel'] == true)
                    OutlinedButton(onPressed: () async { Navigator.pop(sheetContext); await _status(rfiId, 'cancel', needsReason: true); }, child: const TrText('إلغاء')),
                ],
              ),
              const SizedBox(height: 20),
              const TrText('سجل النشاط', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (activities.isEmpty)
                TrText('لا يوجد نشاط إضافي.', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant)))
              else
                ...activities.map((raw) {
                  final activity = raw as Map<String, dynamic>;
                  final user = activity['user'] as Map<String, dynamic>?;
                  final activityAttachments = (activity['attachments'] as List? ?? const [])
                      .whereType<Map>()
                      .map((e) => Map<String, dynamic>.from(e))
                      .toList();
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(trUi(activity['body']?.toString() ?? activity['type']?.toString() ?? '')),
                          const SizedBox(height: 4),
                          Text(trUi(user?['name']?.toString() ?? '-'), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 11)),
                          if (activityAttachments.isNotEmpty)
                            ...activityAttachments.map((attachment) => _attachmentTile(rfiIdValue, attachment)),
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
  }

  Future<void> _answer(int id, String text, List<File> attachments) async {
    setState(() => _saving = true);
    try {
      final message = await ApiService.answerProjectRfi(projectId: widget.projectId, rfiId: id, answer: text, attachments: attachments);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _comment(int id, String text, List<File> attachments) async {
    setState(() => _saving = true);
    try {
      final message = await ApiService.commentProjectRfi(projectId: widget.projectId, rfiId: id, bodyText: text, attachments: attachments);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _status(int id, String action, {bool needsReason = false}) async {
    String? reason;
    if (needsReason) {
      reason = await _ask(action == 'reopen' ? 'إعادة فتح RFI' : 'إلغاء RFI', 'السبب', min: 3);
      if (reason == null) return;
    }
    setState(() => _saving = true);
    try {
      final message = await ApiService.changeProjectRfiStatus(
        projectId: widget.projectId,
        rfiId: id,
        action: action,
        reason: reason,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        appBar: AppBar(title: Text('RFI — ${widget.projectTitle}')),
        floatingActionButton: _data?['can_create'] == true
            ? FloatingActionButton.extended(
                onPressed: _saving ? null : _create,
                icon: const Icon(Icons.add_comment_outlined),
                label: const TrText('RFI جديد'),
              )
            : null,
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: ElevatedButton(onPressed: _load, child: Text(trUi(_error!))));
    }
    final data = _data ?? const <String, dynamic>{};
    final stats = (data['stats'] as Map<String, dynamic>?) ?? const {};
    final rfis = (data['rfis'] as List? ?? const []);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _stat('الكل', stats['total']),
              _stat('مفتوح', stats['open']),
              _stat('مجاب', stats['answered']),
              _stat('مغلق', stats['closed']),
              _stat('متأخر', stats['overdue']),
            ],
          ),
          const SizedBox(height: 14),
          if (rfis.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(18), child: TrText('لا توجد RFIs بعد.')))
          else
            ...rfis.map((raw) {
              final rfi = raw as Map<String, dynamic>;
              final color = _statusColor(rfi['status']?.toString());
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _openRfi(rfi['id'] as int),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: color.withValues(alpha: .12),
                          child: Icon(Icons.help_outline_rounded, color: color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(trUi(rfi['rfi_number']?.toString() ?? 'RFI'), style: const TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text(trUi(rfi['subject']?.toString() ?? '')),
                              const SizedBox(height: 6),
                              Text(
                                '${_priorityLabel(rfi['priority']?.toString())} • ${_statusLabel(rfi['status']?.toString())}',
                                style: TextStyle(fontSize: 11, color: color),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_left_rounded, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _stat(String label, dynamic value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.dark ? Color(0x0DFFFFFF) : Theme.of(context).colorScheme.surface),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? Color(0x1AFFFFFF) : Theme.of(context).dividerColor)),
      ),
      child: Text('$label ${value ?? 0}', style: const TextStyle(fontSize: 11)),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(999)),
      child: Text(trUi(text), style: TextStyle(color: color, fontSize: 11)),
    );
  }
}

class _RfiMessageDraft {
  final String text;
  final List<File> attachments;

  const _RfiMessageDraft(this.text, this.attachments);
}
