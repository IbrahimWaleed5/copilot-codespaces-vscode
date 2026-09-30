import 'dart:io';

import 'package:flutter/material.dart';
import '../i18n/localized_text.dart';
import 'package:file_picker/file_picker.dart' show FileType;
import 'package:open_filex/open_filex.dart';

import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';
import '../utils/app_file_picker.dart';

class ProjectHandoverScreen extends StatefulWidget {
  final int projectId;
  final String projectTitle;

  const ProjectHandoverScreen({
    super.key,
    required this.projectId,
    required this.projectTitle,
  });

  @override
  State<ProjectHandoverScreen> createState() => _ProjectHandoverScreenState();
}

class _ProjectHandoverScreenState extends State<ProjectHandoverScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  int? _busyPackage;
  int? _busyItem;

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
      final data = await ApiService.fetchProjectHandover(widget.projectId);
      if (!mounted) return;
      setState(() => _data = data);
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _canManage => ((_data?['permissions'] as Map?)?['can_manage'] == true);
  bool get _isCustomer => ((_data?['permissions'] as Map?)?['is_customer'] == true);

  Future<void> _createPackage() async {
    final title = TextEditingController();
    final summary = TextEditingController();
    final item1 = TextEditingController(text: 'ملفات التسليم المعتمدة'.tr());
    final item2 = TextEditingController(text: 'الملفات المصدرية المطلوبة'.tr());
    final item3 = TextEditingController(text: 'تقرير الإغلاق والملاحظات'.tr());
    String type = 'milestone';
    int? milestoneId;
    final milestones = List<Map<String, dynamic>>.from(
      (_data?['milestones'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)),
    );
    if (milestones.isNotEmpty) milestoneId = int.tryParse('${milestones.first['id']}');

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF0D1B31) : Theme.of(context).colorScheme.surface),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 18,
            bottom: MediaQuery.of(context).viewInsets.bottom + 18,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TrText('إنشاء حزمة تسليم', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: InputDecoration(labelText: 'نوع الحزمة'.tr()),
                  items: const [
                    DropdownMenuItem(value: 'milestone', child: TrText('تسليم مرحلة')),
                    DropdownMenuItem(value: 'final', child: TrText('التسليم النهائي')),
                  ],
                  onChanged: (v) => setSheetState(() => type = v ?? 'milestone'),
                ),
                if (type == 'milestone') ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    value: milestoneId,
                    decoration: InputDecoration(labelText: 'المرحلة'.tr()),
                    items: milestones
                        .map((m) => DropdownMenuItem<int>(
                              value: int.tryParse('${m['id']}'),
                              child: Text(m['title']?.toString() ?? 'مرحلة'.tr()),
                            ))
                        .toList(),
                    onChanged: (v) => setSheetState(() => milestoneId = v),
                  ),
                ],
                const SizedBox(height: 10),
                TextField(controller: title, decoration: InputDecoration(labelText: 'عنوان التسليم'.tr())),
                const SizedBox(height: 10),
                TextField(controller: summary, minLines: 2, maxLines: 4, decoration: InputDecoration(labelText: 'ملخص الحزمة'.tr())),
                const SizedBox(height: 14),
                const TrText('قائمة التحقق', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextField(controller: item1, decoration: InputDecoration(labelText: 'العنصر الأول'.tr())),
                const SizedBox(height: 8),
                TextField(controller: item2, decoration: InputDecoration(labelText: 'العنصر الثاني'.tr())),
                const SizedBox(height: 8),
                TextField(controller: item3, decoration: InputDecoration(labelText: 'العنصر الثالث'.tr())),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () async {
                    if (title.text.trim().isEmpty || (type == 'milestone' && milestoneId == null)) return;
                    try {
                      await ApiService.createProjectHandover(
                        projectId: widget.projectId,
                        packageType: type,
                        milestoneId: type == 'milestone' ? milestoneId : null,
                        title: title.text,
                        summary: summary.text,
                        items: [item1.text, item2.text, item3.text],
                      );
                      if (sheetContext.mounted) Navigator.pop(sheetContext, true);
                    } on ApiException catch (e) {
                      if (sheetContext.mounted) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(SnackBar(content: Text(trUi(e.message))));
                      }
                    }
                  },
                  icon: const Icon(Icons.add_box_outlined),
                  label: const TrText('إنشاء الحزمة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 600), title.dispose); Future<void>.delayed(const Duration(milliseconds: 600), summary.dispose); Future<void>.delayed(const Duration(milliseconds: 600), item1.dispose); Future<void>.delayed(const Duration(milliseconds: 600), item2.dispose); Future<void>.delayed(const Duration(milliseconds: 600), item3.dispose);
    if (result == true) await _load();
  }

  Future<void> _setItem(int packageId, int itemId, String status) async {
    setState(() => _busyItem = itemId);
    try {
      await ApiService.updateProjectHandoverItem(
        projectId: widget.projectId,
        handoverId: packageId,
        itemId: itemId,
        status: status,
      );
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    } finally {
      if (mounted) setState(() => _busyItem = null);
    }
  }

  Future<void> _upload(int packageId) async {
    final picked = await AppFilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf','jpg','jpeg','png','webp','doc','docx','xls','xlsx','dwg','dxf','zip'],
    );
    if (picked?.path == null) return;
    setState(() => _busyPackage = packageId);
    try {
      await ApiService.uploadProjectHandoverAttachment(
        projectId: widget.projectId,
        handoverId: packageId,
        file: File(picked!.path!),
        label: picked.name,
      );
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    } finally {
      if (mounted) setState(() => _busyPackage = null);
    }
  }

  Future<void> _deleteAttachment(int packageId, int attachmentId) async {
    setState(() => _busyPackage = packageId);
    try {
      final result = await ApiService.deleteProjectHandoverAttachment(
        projectId: widget.projectId,
        handoverId: packageId,
        attachmentId: attachmentId,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']?.toString() ?? 'تم حذف المرفق.'.tr())));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    } finally {
      if (mounted) setState(() => _busyPackage = null);
    }
  }

  Future<void> _cancelPackage(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const TrText('إلغاء حزمة التسليم'),
        content: const TrText('سيتم إلغاء الحزمة ولن تكون قابلة للإرسال أو الاعتماد.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const TrText('تراجع')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const TrText('تأكيد الإلغاء')),
        ],
      ),
    );
    if (ok != true) return;
    await _packageAction(id, () => ApiService.cancelProjectHandover(projectId: widget.projectId, handoverId: id));
  }

  Future<void> _download(int packageId, Map<String, dynamic> attachment) async {
    try {
      final file = await ApiService.downloadProjectHandoverAttachment(
        projectId: widget.projectId,
        handoverId: packageId,
        attachmentId: int.parse('${attachment['id']}'),
        fileName: attachment['original_name']?.toString() ?? 'handover-file',
      );
      await OpenFilex.open(file.path);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    }
  }

  Future<void> _downloadCertificate(int handoverId, Map<String, dynamic> certificate) async {
    try {
      final file = await ApiService.downloadProjectHandoverCertificate(
        projectId: widget.projectId,
        handoverId: handoverId,
        certificateNumber: certificate['certificate_number']?.toString() ?? 'acceptance-certificate',
      );
      await OpenFilex.open(file.path);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    }
  }

  Future<void> _submit(int id) => _packageAction(id, () => ApiService.submitProjectHandover(projectId: widget.projectId, handoverId: id));
  Future<void> _accept(int id) => _packageAction(id, () => ApiService.acceptProjectHandover(projectId: widget.projectId, handoverId: id));

  Future<void> _requestChanges(int id) async {
    final c = TextEditingController();
    final notes = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: AlertDialog(
          title: const TrText('طلب تعديلات على التسليم'),
          content: TextField(controller: c, minLines: 3, maxLines: 6, decoration: InputDecoration(hintText: 'اكتب النواقص أو الملاحظات المطلوبة'.tr())),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const TrText('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, c.text.trim()), child: const TrText('إرسال الملاحظات')),
          ],
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 600), c.dispose);
    if (notes == null || notes.length < 5) return;
    await _packageAction(id, () => ApiService.requestProjectHandoverChanges(projectId: widget.projectId, handoverId: id, notes: notes));
  }

  Future<void> _packageAction(int id, Future<Map<String, dynamic>> Function() action) async {
    setState(() => _busyPackage = id);
    try {
      final result = await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']?.toString() ?? 'تمت العملية.'.tr())));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    } finally {
      if (mounted) setState(() => _busyPackage = null);
    }
  }

  String _statusLabel(String status) {
    const labels = {
      'draft': 'مسودة',
      'submitted': 'بانتظار اعتماد العميل',
      'changes_requested': 'تعديلات مطلوبة',
      'accepted': 'معتمد',
      'cancelled': 'ملغي',
    };
    return labels[status] ?? status;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted': return AppColors.success;
      case 'changes_requested': return AppColors.danger;
      case 'submitted': return Colors.amber;
      default: return (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : AppColors.textSecondary);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: const TrText('التسليم والاعتماد'),
          actions: [
            if (_canManage) IconButton(onPressed: _createPackage, icon: const Icon(Icons.add_box_outlined), tooltip: 'حزمة جديدة'.tr()),
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
          ],
        ),
        floatingActionButton: _canManage ? FloatingActionButton.extended(onPressed: _createPackage, icon: const Icon(Icons.add), label: const TrText('حزمة تسليم')) : null,
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _data == null) return const Center(child: CircularProgressIndicator());
    if (_error != null && _data == null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(trUi(_error!), textAlign: TextAlign.center), const SizedBox(height: 12), ElevatedButton(onPressed: _load, child: const TrText('إعادة المحاولة'))])));
    }
    final project = Map<String, dynamic>.from((_data?['project'] as Map?) ?? const {});
    final packages = List<Map<String, dynamic>>.from((_data?['packages'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)));
    final accepted = packages.where((e) => e['status'] == 'accepted').length;
    final review = packages.where((e) => e['status'] == 'submitted').length;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(17),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('SaaS Phase 7', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan), fontWeight: FontWeight.w800, fontSize: 12)),
                const SizedBox(height: 6),
                const TrText('مركز التسليم والاعتماد النهائي', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text('${project['project_number'] ?? ''} — ${project['title'] ?? widget.projectTitle}', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 12)),
                const SizedBox(height: 14),
                Row(children: [Expanded(child: _metric('الحزم', '${packages.length}', Icons.inventory_2_outlined)), const SizedBox(width: 8), Expanded(child: _metric('للمراجعة', '$review', Icons.fact_check_outlined)), const SizedBox(width: 8), Expanded(child: _metric('معتمدة', '$accepted', Icons.verified_outlined))]),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          if (packages.isEmpty)
            Card(child: Padding(padding: EdgeInsets.all(28), child: Column(children: [Icon(Icons.inventory_2_outlined, size: 44, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant)), SizedBox(height: 10), TrText('لا توجد حزم تسليم بعد.', style: TextStyle(fontWeight: FontWeight.w700))])))
          else
            ...packages.map(_packageCard),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, IconData icon) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF0A172B) : AppColors.loginPanel), borderRadius: BorderRadius.circular(14)),
        child: Column(children: [Icon(icon, size: 19, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan)), const SizedBox(height: 5), Text(trUi(value), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), Text(trUi(label), style: TextStyle(fontSize: 10, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : AppColors.textSecondary)))]),
      );

  Widget _packageCard(Map<String, dynamic> p) {
    final id = int.parse('${p['id']}');
    final status = p['status']?.toString() ?? 'draft';
    final editable = status == 'draft' || status == 'changes_requested';
    final items = List<Map<String, dynamic>>.from((p['items'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)));
    final attachments = List<Map<String, dynamic>>.from((p['attachments'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)));
    final certificate = p['certificate'] is Map ? Map<String, dynamic>.from(p['certificate'] as Map) : null;
    final provided = items.where((e) => e['status'] == 'provided').length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(trUi(p['reference_number']?.toString() ?? ''), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan), fontWeight: FontWeight.w800, fontSize: 12)),
              const SizedBox(height: 4),
              Text(trUi(p['title']?.toString() ?? ''), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(trUi(p['milestone'] is Map ? (p['milestone']['title']?.toString() ?? '') : 'المشروع كاملًا'), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 11)),
            ])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: _statusColor(status).withValues(alpha: .12), borderRadius: BorderRadius.circular(20)), child: Text(trUi(_statusLabel(status)), style: TextStyle(color: _statusColor(status), fontSize: 10, fontWeight: FontWeight.w700))),
          ]),
          if ((p['summary']?.toString() ?? '').isNotEmpty) ...[const SizedBox(height: 10), Text(trUi(p['summary'].toString()), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), height: 1.5))],
          const SizedBox(height: 12),
          LinearProgressIndicator(value: items.isEmpty ? 0 : provided / items.length, minHeight: 6, borderRadius: BorderRadius.circular(20)),
          const SizedBox(height: 5),
          TrText('$provided من ${items.length} عناصر مكتملة • ${attachments.length} مرفق', style: TextStyle(fontSize: 10, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
          const SizedBox(height: 12),
          ...items.map((item) {
            final itemId = int.parse('${item['id']}');
            final itemStatus = item['status']?.toString() ?? 'pending';
            return Container(
              margin: const EdgeInsets.only(bottom: 7),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF0A172B) : Theme.of(context).colorScheme.surface), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Icon(itemStatus == 'provided' ? Icons.check_circle : (itemStatus == 'not_applicable' ? Icons.remove_circle_outline : Icons.radio_button_unchecked), size: 20, color: itemStatus == 'provided' ? AppColors.success : (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : AppColors.textSecondary)),
                const SizedBox(width: 8),
                Expanded(child: Text(trUi(item['label']?.toString() ?? ''), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                if (_canManage && editable)
                  PopupMenuButton<String>(
                    enabled: _busyItem != itemId,
                    onSelected: (v) => _setItem(id, itemId, v),
                    itemBuilder: (_) => const [PopupMenuItem(value: 'provided', child: TrText('تم توفيره')), PopupMenuItem(value: 'pending', child: TrText('ناقص')), PopupMenuItem(value: 'not_applicable', child: TrText('غير منطبق'))],
                  ),
              ]),
            );
          }),
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 4),
            const TrText('المرفقات', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            const SizedBox(height: 4),
            ...attachments.map((a) {
              final hash = a['sha256']?.toString() ?? '';
              final shortHash = hash.length <= 12 ? hash : hash.substring(0, 12);
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.attachment_outlined, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan)),
                title: Text(a['original_name']?.toString() ?? 'ملف'.tr(), maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('SHA256 $shortHash…', style: const TextStyle(fontSize: 9)),
                trailing: _canManage && editable
                    ? IconButton(
                        tooltip: 'حذف المرفق'.tr(),
                        icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                        onPressed: _busyPackage == id ? null : () => _deleteAttachment(id, int.parse('${a['id']}')),
                      )
                    : null,
                onTap: () => _download(id, a),
              );
            }),
          ],
          if ((p['review_notes']?.toString() ?? '').isNotEmpty) Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: .08), borderRadius: BorderRadius.circular(12)), child: TrText('ملاحظات العميل: ${p['review_notes']}', style: const TextStyle(fontSize: 11, color: AppColors.danger))),
          if (certificate != null) Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.success.withValues(alpha: .08), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.verified_outlined, color: AppColors.success),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(trUi(certificate['certificate_number']?.toString() ?? ''), style: const TextStyle(fontWeight: FontWeight.w800)),
                TrText('شهادة استلام رقمية موثقة', style: TextStyle(fontSize: 10, color: AppColors.success.withValues(alpha: .9))),
              ])),
              IconButton(onPressed: () => _downloadCertificate(id, certificate), icon: const Icon(Icons.picture_as_pdf_outlined), tooltip: 'تنزيل الشهادة'.tr()),
            ]),
          ),
          if (_busyPackage == id) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator()),
          if (_canManage && editable) ...[
            const SizedBox(height: 10),
            Row(children: [Expanded(child: OutlinedButton.icon(onPressed: _busyPackage == id ? null : () => _upload(id), icon: const Icon(Icons.upload_file_outlined), label: const TrText('رفع مرفق'))), const SizedBox(width: 8), Expanded(child: FilledButton(onPressed: _busyPackage == id ? null : () => _submit(id), child: const TrText('إرسال للعميل')))]),
            const SizedBox(height: 6),
            SizedBox(width: double.infinity, child: TextButton.icon(onPressed: _busyPackage == id ? null : () => _cancelPackage(id), icon: const Icon(Icons.cancel_outlined, color: AppColors.danger), label: const TrText('إلغاء الحزمة', style: TextStyle(color: AppColors.danger)))),
          ],
          if (_isCustomer && status == 'submitted') ...[
            const SizedBox(height: 10),
            Row(children: [Expanded(child: OutlinedButton(onPressed: _busyPackage == id ? null : () => _requestChanges(id), child: const TrText('طلب تعديلات'))), const SizedBox(width: 8), Expanded(child: FilledButton.icon(onPressed: _busyPackage == id ? null : () => _accept(id), icon: const Icon(Icons.verified_outlined), label: const TrText('اعتماد الاستلام')))]),
          ],
        ]),
      ),
    );
  }
}
