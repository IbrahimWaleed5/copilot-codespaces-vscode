import 'package:flutter/material.dart';
import '../i18n/localized_text.dart';
import 'package:open_filex/open_filex.dart';

import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';

class AdminKycScreen extends StatefulWidget {
  const AdminKycScreen({super.key});

  @override
  State<AdminKycScreen> createState() => _AdminKycScreenState();
}

class _AdminKycScreenState extends State<AdminKycScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.fetchAdminKyc();
      if (mounted) setState(() => _items = data);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Map<String, dynamic> row) async {
    final id = int.tryParse('${row['id']}');
    if (id == null) return;
    try {
      final data = await ApiService.fetchAdminKycProfile(id);
      if (!mounted) return;
      final profile = Map<String, dynamic>.from(data['profile'] as Map? ?? const {});
      final templates = List<Map<String, dynamic>>.from(
        (data['templates'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
      );
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => _KycReviewSheet(
          profile: profile,
          templates: templates,
          onSubmit: (status, note, subject) async {
            final msg = await ApiService.reviewAdminKyc(profileId: id, status: status, note: note, emailSubject: subject);
            AppFeedback.success(msg);
            if (sheetContext.mounted) Navigator.pop(sheetContext);
            await _load();
          },
        ),
      );
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        appBar: AppBar(title: const TrText('مركز مراجعة KYC')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(trUi(_error!)))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(14),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final row = _items[index];
                        return Card(
                          child: ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.badge_outlined)),
                            title: Text(trUi(row['subject_name']?.toString() ?? row['legal_name']?.toString() ?? '#${row['id']}'), style: const TextStyle(fontWeight: FontWeight.w900)),
                            subtitle: Text('${row['subject_type'] ?? ''} • ${row['subject_role'] ?? ''} • ${row['status'] ?? ''}'),
                            trailing: const Icon(Icons.chevron_left_rounded),
                            onTap: () => _open(row),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}

class _KycReviewSheet extends StatefulWidget {
  final Map<String, dynamic> profile;
  final List<Map<String, dynamic>> templates;
  final Future<void> Function(String status, String note, String subject) onSubmit;
  const _KycReviewSheet({required this.profile, required this.templates, required this.onSubmit});

  @override
  State<_KycReviewSheet> createState() => _KycReviewSheetState();
}

class _KycReviewSheetState extends State<_KycReviewSheet> {
  String _status = 'under_review';
  final _note = TextEditingController();
  final _subject = TextEditingController();
  bool _busy = false;

  @override
  void dispose() { _note.dispose(); _subject.dispose(); super.dispose(); }

  Future<void> _reviewDocument(Map<String, dynamic> document, String status) async {
    final id = int.tryParse('${document['id']}');
    if (id == null) return;
    String reason = '';
    if (status == 'rejected') {
      final controller = TextEditingController();
      final result = await showDialog<String>(
        context: context,
        builder: (dialogContext) => Directionality(
          textDirection: AppLanguage.instance.textDirection,
          child: AlertDialog(
            title: const TrText('رفض المستند'),
            content: TextField(
              controller: controller,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(labelText: 'سبب الرفض وإعادة الرفع'.tr()),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const TrText('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const TrText('رفض المستند')),
            ],
          ),
        ),
      );
      Future<void>.delayed(const Duration(milliseconds: 600), controller.dispose);
      if ((result ?? '').trim().isEmpty) return;
      reason = result!.trim();
    }
    try {
      final message = await ApiService.reviewAdminKycDocument(
        documentId: id,
        status: status,
        rejectionReason: reason,
      );
      if (!mounted) return;
      setState(() {
        document['status'] = status;
        document['rejection_reason'] = status == 'rejected' ? reason : null;
        final rawDocuments = widget.profile['documents'];
        if (rawDocuments is List) {
          for (final raw in rawDocuments) {
            if (raw is Map && int.tryParse('${raw['id']}') == id) {
              raw['status'] = status;
              raw['rejection_reason'] = status == 'rejected' ? reason : null;
              break;
            }
          }
        }
        if (status == 'rejected') widget.profile['status'] = 'needs_more_info';
      });
      AppFeedback.success(message);
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
    }
  }

  Future<void> _openDocument(Map<String, dynamic> document) async {
    final id = int.tryParse('${document['id']}');
    if (id == null) return;
    try {
      final rawName = document['original_name']?.toString() ?? 'kyc-$id';
      final safeName = rawName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = await ApiService.downloadAttachment(
        urlPath: 'admin/kyc/documents/$id',
        fileName: safeName,
      );
      await OpenFilex.open(file.path);
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final docs = List<Map<String, dynamic>>.from(
      (widget.profile['documents'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
    );
    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.profile['legal_name']?.toString() ?? 'طلب KYC'.tr(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                TrText('الحالة الحالية: ${widget.profile['status'] ?? ''}', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TrText('نوع الحساب: ${widget.profile['subject_type'] ?? ''} • ${widget.profile['subject_role'] ?? ''}'),
                        if ((widget.profile['identity_number']?.toString() ?? '').isNotEmpty)
                          SelectableText('رقم الهوية/التسجيل: ${widget.profile['.tr()identity_number']}'.tr()),
                        if ((widget.profile['date_of_birth']?.toString() ?? '').isNotEmpty)
                          TrText('تاريخ الميلاد: ${widget.profile['date_of_birth']}'),
                        if ((widget.profile['nationality']?.toString() ?? '').isNotEmpty)
                          TrText('الجنسية: ${widget.profile['nationality']}'),
                        if ((widget.profile['country_code']?.toString() ?? '').isNotEmpty)
                          TrText('الدولة: ${widget.profile['country_code']}'),
                        TrText('مستوى التحقق: ${widget.profile['level'] ?? ''} • المخاطر: ${widget.profile['risk_level'] ?? 'normal'}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const TrText('المستندات — اضغط لفتح الملف', style: TextStyle(fontWeight: FontWeight.w900)),
                ...docs.map((d) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.description_outlined),
                              title: Text(trUi(d['document_type']?.toString() ?? '')),
                              subtitle: Text('${d['original_name'] ?? ''} • ${d['status'] ?? ''}'),
                              trailing: IconButton(
                                tooltip: 'فتح المستند'.tr(),
                                onPressed: () => _openDocument(d),
                                icon: const Icon(Icons.open_in_new_rounded),
                              ),
                            ),
                            if ((d['rejection_reason']?.toString() ?? '').isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  trUi(d['rejection_reason'].toString()),
                                  style: const TextStyle(color: AppColors.red300, fontSize: 12),
                                ),
                              ),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _reviewDocument(d, 'verified'),
                                    icon: const Icon(Icons.check_circle_outline_rounded),
                                    label: const TrText('اعتماد المستند'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _reviewDocument(d, 'rejected'),
                                    icon: const Icon(Icons.cancel_outlined),
                                    label: const TrText('رفض'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: InputDecoration(labelText: 'القرار'.tr()),
                  items: const [
                    DropdownMenuItem(value: 'under_review', child: TrText('قيد المراجعة')),
                    DropdownMenuItem(value: 'needs_more_info', child: TrText('مطلوب معلومات إضافية')),
                    DropdownMenuItem(value: 'verified', child: TrText('اعتماد التوثيق')),
                    DropdownMenuItem(value: 'rejected', child: TrText('رفض')),
                    DropdownMenuItem(value: 'suspended', child: TrText('تعليق')),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? _status),
                ),
                const SizedBox(height: 10),
                if (widget.templates.isNotEmpty)
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    decoration: InputDecoration(labelText: 'قالب رسالة (اختياري)'.tr()),
                    items: widget.templates.map((t) => DropdownMenuItem<int>(
                      value: int.tryParse('${t['id']}'),
                      child: Text(trUi(t['title']?.toString() ?? ''), overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (id) {
                      Map<String, dynamic>? selectedTemplate;
                      for (final item in widget.templates) {
                        if (int.tryParse('${item['id']}') == id) {
                          selectedTemplate = item;
                          break;
                        }
                      }
                      if (selectedTemplate != null) {
                        _subject.text = selectedTemplate['email_subject']?.toString() ?? '';
                        _note.text = selectedTemplate['body']?.toString() ?? '';
                      }
                    },
                  ),
                const SizedBox(height: 10),
                TextField(controller: _subject, decoration: InputDecoration(labelText: 'عنوان الإيميل'.tr())),
                const SizedBox(height: 10),
                TextField(controller: _note, minLines: 4, maxLines: 7, decoration: InputDecoration(labelText: 'ملاحظة / رسالة للمستخدم'.tr())),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: _busy ? null : () async {
                    setState(() => _busy = true);
                    try { await widget.onSubmit(_status, _note.text.trim(), _subject.text.trim()); }
                    finally { if (mounted) setState(() => _busy = false); }
                  },
                  child: Text(trUi(_busy ? 'جاري الحفظ...' : 'حفظ القرار')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
