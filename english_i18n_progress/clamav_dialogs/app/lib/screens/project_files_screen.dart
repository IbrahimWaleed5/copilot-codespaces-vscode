import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../i18n/localized_text.dart';
import 'package:open_filex/open_filex.dart';

import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';
import 'project_file_versions_screen.dart';

class ProjectFilesScreen extends StatefulWidget {
  final int projectId;
  final String projectTitle;
  final bool autoUpload;

  const ProjectFilesScreen({
    super.key,
    required this.projectId,
    required this.projectTitle,
    this.autoUpload = false,
  });

  @override
  State<ProjectFilesScreen> createState() => _ProjectFilesScreenState();
}

class _ProjectFilesScreenState extends State<ProjectFilesScreen> {
  List<dynamic> _files = [];
  bool _loading = true;
  String? _error;
  int? _downloadingId;
  bool _uploading = false;
  int? _busyActionFileId;
  bool _canUpload = false;
  bool _autoUploadTriggered = false;

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
      final results = await Future.wait([
        ApiService.fetchProjectFiles(widget.projectId),
        ApiService.fetchProjectDetail(widget.projectId),
      ]);

      if (!mounted) return;
      final detail = results[1] as Map<String, dynamic>;
      final permissions = (detail['permissions'] as Map<String, dynamic>?) ?? {};

      setState(() {
        _files = results[0] as List<dynamic>;
        _canUpload = permissions['can_upload_project_files'] == true;
      });
      if (widget.autoUpload && !_autoUploadTriggered) {
        _autoUploadTriggered = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_canUpload) {
            _uploadFile();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: TrText('لا تملك صلاحية رفع ملفات في هذا المشروع.')),
            );
          }
        });
      }
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openFile(Map<String, dynamic> file) async {
    final id = file['id'] as int;
    setState(() => _downloadingId = id);

    try {
      final currentVersion = file['current_version'] as Map<String, dynamic>?;
      final customerVersion = file['customer_version'] as Map<String, dynamic>?;
      final version = customerVersion ?? currentVersion;
      final name = version?['original_name']?.toString() ?? file['original_name']?.toString() ?? 'file-$id';

      final localFile = await ApiService.downloadProjectFile(
        projectId: widget.projectId,
        fileId: id,
        fileName: name,
      );
      await OpenFilex.open(localFile.path);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    } finally {
      if (mounted) setState(() => _downloadingId = null);
    }
  }

  Future<void> _uploadFile() async {
    final PlatformFile? selected = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const [
        'pdf', 'dwg', 'dxf', 'jpg', 'jpeg', 'png', 'webp',
        'doc', 'docx', 'xls', 'xlsx', 'zip', 'rar',
      ],
    );

    if (selected == null) return;
    if (selected.path == null || selected.path!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: TrText('تعذر الوصول إلى الملف المختار.')),
        );
      }
      return;
    }

    final selectedSize = await selected.length();
    if (!mounted) return;

    if (selectedSize > 50 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TrText('حجم الملف أكبر من 50MB.')),
      );
      return;
    }

    final titleController = TextEditingController(text: selected.name);
    final descriptionController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: AlertDialog(
          title: const TrText('رفع ملف للمشروع'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(labelText: 'عنوان الملف'.tr()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(labelText: 'وصف اختياري'.tr()),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${selected.name} • ${(selectedSize / 1024 / 1024).toStringAsFixed(2)} MB',
                    style: TextStyle(fontSize: 11, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const TrText('إلغاء')),
            ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const TrText('رفع')),
          ],
        ),
      ),
    );

    final title = titleController.text.trim();
    final description = descriptionController.text.trim();
    Future<void>.delayed(const Duration(milliseconds: 600), titleController.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), descriptionController.dispose);

    if (confirmed != true) return;
    if (title.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: TrText('اكتب عنوان الملف.')));
      return;
    }

    setState(() => _uploading = true);
    try {
      final response = await ApiService.uploadProjectFile(
        projectId: widget.projectId,
        title: title,
        description: description.isEmpty ? null : description,
        file: File(selected.path!),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message']?.toString() ?? 'تم رفع الملف.'.tr())),
      );
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _revokeCustomerAccess(Map<String, dynamic> file) async {
    final controller = TextEditingController();
    final notes = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: AlertDialog(
          title: const TrText('سحب إتاحة الملف من العميل'),
          content: TextField(
            controller: controller,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(labelText: 'ملاحظة اختيارية'.tr()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const TrText('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const TrText('سحب الإتاحة')),
          ],
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 600), controller.dispose);
    if (notes == null) return;
    final fileId = int.parse(file['id'].toString());
    setState(() => _busyActionFileId = fileId);
    try {
      final message = await ApiService.revokeProjectFileCustomerAccess(
        projectId: widget.projectId,
        fileId: fileId,
        notes: notes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    } finally {
      if (mounted) setState(() => _busyActionFileId = null);
    }
  }

  Future<void> _deleteFile(Map<String, dynamic> file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: AlertDialog(
          title: const TrText('حذف ملف المشروع'),
          content: TrText('هل تريد حذف "${file['title'] ?? 'الملف'.tr()}" من قائمة المشروع؟ سيبقى سجل التدقيق محفوظًا.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const TrText('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const TrText('حذف')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    final fileId = int.parse(file['id'].toString());
    setState(() => _busyActionFileId = fileId);
    try {
      final message = await ApiService.deleteProjectFile(projectId: widget.projectId, fileId: fileId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    } finally {
      if (mounted) setState(() => _busyActionFileId = null);
    }
  }

  String _reviewStatusLabel(String? status) {
    const labels = {
      'pending': 'بانتظار المراجعة',
      'approved': 'معتمد',
      'rejected': 'مرفوض',
      'changes_requested': 'مطلوب تعديل',
    };
    return labels[status] ?? status ?? 'بدون حالة'.tr();
  }

  Color _reviewColor(String? status) {
    switch (status) {
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.danger;
      case 'changes_requested':
        return Colors.orangeAccent;
      default:
        return (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : AppColors.textSecondary);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        appBar: AppBar(title: TrText('ملفات المشروع — ${widget.projectTitle}')),
        floatingActionButton: _canUpload
            ? FloatingActionButton.extended(
                onPressed: _uploading ? null : _uploadFile,
                icon: _uploading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload_file_outlined),
                label: Text(trUi(_uploading ? 'جاري الرفع...' : 'رفع ملف')),
              )
            : null,
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(trUi(_error!), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const TrText('إعادة المحاولة')),
            ],
          ),
        ),
      );
    }

    if (_files.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            SizedBox(height: 180),
            Icon(Icons.folder_open_rounded, size: 54, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant)),
            SizedBox(height: 12),
            Center(child: TrText('لا توجد ملفات ظاهرة لك بعد', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant)))),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 95),
        itemCount: _files.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final file = _files[index] as Map<String, dynamic>;
          final currentVersion = file['current_version'] as Map<String, dynamic>?;
          final customerVersion = file['customer_version'] as Map<String, dynamic>?;
          final version = customerVersion ?? currentVersion;
          final uploader = file['uploader'] as Map<String, dynamic>?;
          final reviewStatus = version?['review_status']?.toString();
          final isDownloading = _downloadingId == file['id'];

          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: isDownloading ? null : () => _openFile(file),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(Icons.insert_drive_file_outlined, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(file['title']?.toString() ?? 'ملف'.tr(), style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(
                            '${uploader?['name'] ?? 'غير معروف'.tr()} • V${version?['version_number'] ?? file['versions_count'] ?? 1}'.tr(),
                            style: TextStyle(fontSize: 11, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant)),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            trUi(_reviewStatusLabel(reviewStatus)),
                            style: TextStyle(fontSize: 11, color: _reviewColor(reviewStatus)),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'إصدارات الملف'.tr(),
                          onPressed: _busyActionFileId == file['id'] ? null : () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ProjectFileVersionsScreen(
                                  projectId: widget.projectId,
                                  fileId: int.parse(file['id'].toString()),
                                  fileTitle: file['title']?.toString() ?? 'الملف'.tr(),
                                ),
                              ),
                            );
                            if (mounted) await _load();
                          },
                          icon: Icon(Icons.history_rounded, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan)),
                        ),
                        if (file['can_review'] == true && file['has_customer_access'] == true)
                          PopupMenuButton<String>(
                            tooltip: 'إدارة الملف'.tr(),
                            enabled: _busyActionFileId != file['id'],
                            onSelected: (value) {
                              if (value == 'revoke') _revokeCustomerAccess(file);
                              if (value == 'delete') _deleteFile(file);
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'revoke', child: TrText('سحب الإتاحة من العميل')),
                              if (file['can_delete'] == true)
                                const PopupMenuItem(value: 'delete', child: TrText('حذف الملف')),
                            ],
                          )
                        else if (file['can_delete'] == true)
                          PopupMenuButton<String>(
                            tooltip: 'إدارة الملف'.tr(),
                            enabled: _busyActionFileId != file['id'],
                            onSelected: (value) { if (value == 'delete') _deleteFile(file); },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'delete', child: TrText('حذف الملف')),
                            ],
                          ),
                        if (_busyActionFileId == file['id'])
                          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        else if (isDownloading)
                          const SizedBox(width: 21, height: 21, child: CircularProgressIndicator(strokeWidth: 2))
                        else
                          Icon(Icons.download_outlined, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
