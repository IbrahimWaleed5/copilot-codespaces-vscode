import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../i18n/localized_text.dart';
import 'package:open_filex/open_filex.dart';

import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';
import 'project_drawing_compare_screen.dart';
import 'project_drawing_markup_screen.dart';

class ProjectFileVersionsScreen extends StatefulWidget {
  final int projectId;
  final int fileId;
  final String fileTitle;

  const ProjectFileVersionsScreen({
    super.key,
    required this.projectId,
    required this.fileId,
    required this.fileTitle,
  });

  @override
  State<ProjectFileVersionsScreen> createState() => _ProjectFileVersionsScreenState();
}

class _ProjectFileVersionsScreenState extends State<ProjectFileVersionsScreen> {
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
      final data = await ApiService.fetchProjectFileVersions(
        projectId: widget.projectId,
        fileId: widget.fileId,
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

  Future<void> _upload() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const [
        'pdf', 'dwg', 'dxf', 'jpg', 'jpeg', 'png', 'webp',
        'doc', 'docx', 'xls', 'xlsx', 'zip', 'rar',
      ],
    );
    final pickedPath = picked?.path;
    if (pickedPath == null || !mounted) return;

    final notes = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: AlertDialog(
          title: const TrText('رفع Version جديد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(trUi(picked!.name), style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              TextField(controller: notes, minLines: 2, maxLines: 5, decoration: InputDecoration(labelText: 'ما الذي تغير؟ - اختياري'.tr())),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const TrText('إلغاء')),
            ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const TrText('رفع')),
          ],
        ),
      ),
    );
    final notesText = notes.text.trim();
    Future<void>.delayed(const Duration(milliseconds: 600), notes.dispose);
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      final message = await ApiService.uploadProjectFileVersion(
        projectId: widget.projectId,
        fileId: widget.fileId,
        file: File(pickedPath),
        changeNotes: notesText.isEmpty ? null : notesText,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _review(Map<String, dynamic> version, bool approve) async {
    final controller = TextEditingController();
    final notes = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: AlertDialog(
          title: Text(trUi(approve ? 'اعتماد Version' : 'رفض Version')),
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
      final message = await ApiService.reviewProjectFileVersion(
        projectId: widget.projectId,
        fileId: widget.fileId,
        versionId: version['id'] as int,
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

  Future<void> _download(Map<String, dynamic> version) async {
    final id = version['id'] as int;
    setState(() => _downloadingId = id);
    try {
      final file = await ApiService.downloadProjectFileVersion(
        projectId: widget.projectId,
        fileId: widget.fileId,
        versionId: id,
        fileName: version['original_name']?.toString() ?? 'file-version-$id',
      );
      await OpenFilex.open(file.path);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    } finally {
      if (mounted) setState(() => _downloadingId = null);
    }
  }

  Future<void> _openMarkup(Map<String, dynamic> version) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProjectDrawingMarkupScreen(
          projectId: widget.projectId,
          fileId: widget.fileId,
          versionId: int.parse(version['id'].toString()),
          fileTitle: widget.fileTitle,
          versionNumber: int.tryParse(version['version_number']?.toString() ?? '') ?? 1,
          originalName: version['original_name']?.toString() ?? 'project-file',
        ),
      ),
    );
  }

  Future<void> _openCompare() async {
    final rawVersions = (_data?['versions'] as List? ?? const []);
    final versions = rawVersions
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
    if (versions.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TrText('تحتاج نسختين على الأقل لإجراء المقارنة.')),
      );
      return;
    }

    var aId = int.parse(versions.first['id'].toString());
    var bId = int.parse(versions[1]['id'].toString());
    final selected = await showDialog<List<int>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: AppLanguage.instance.textDirection,
          child: AlertDialog(
            title: const TrText('مقارنة نسختين'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: aId,
                  decoration: InputDecoration(labelText: 'النسخة الأولى'.tr()),
                  items: versions
                      .map(
                        (version) => DropdownMenuItem(
                          value: int.parse(version['id'].toString()),
                          child: Text('V${version['version_number']}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => aId = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: bId,
                  decoration: InputDecoration(labelText: 'النسخة الثانية'.tr()),
                  items: versions
                      .map(
                        (version) => DropdownMenuItem(
                          value: int.parse(version['id'].toString()),
                          child: Text('V${version['version_number']}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => bId = value);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const TrText('إلغاء'),
              ),
              ElevatedButton(
                onPressed: aId == bId
                    ? null
                    : () => Navigator.pop(dialogContext, [aId, bId]),
                child: const TrText('مقارنة'),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    final a = versions.firstWhere((v) => int.parse(v['id'].toString()) == selected[0]);
    final b = versions.firstWhere((v) => int.parse(v['id'].toString()) == selected[1]);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProjectDrawingCompareScreen(
          projectId: widget.projectId,
          fileId: widget.fileId,
          fileTitle: widget.fileTitle,
          versionA: a,
          versionB: b,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: TrText('الإصدارات — ${widget.fileTitle}'),
          actions: [
            IconButton(
              tooltip: 'Visual Compare',
              onPressed: _openCompare,
              icon: const Icon(Icons.compare_rounded),
            ),
          ],
        ),
        floatingActionButton: _data?['can_upload_version'] == true
            ? FloatingActionButton.extended(
                onPressed: _saving ? null : _upload,
                icon: const Icon(Icons.upload_file_outlined),
                label: const TrText('Version جديد'),
              )
            : null,
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: ElevatedButton(onPressed: _load, child: Text(trUi(_error!))));

    final data = _data ?? const <String, dynamic>{};
    final file = (data['file'] as Map<String, dynamic>?) ?? const {};
    final versions = (data['versions'] as List? ?? const []);
    final canReview = data['can_review'] == true;
    final currentId = file['current_version_id'];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trUi(file['title']?.toString() ?? widget.fileTitle), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                  if ((file['description']?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(trUi(file['description'].toString()), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), height: 1.5)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (versions.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(15), child: TrText('لا توجد إصدارات.')))
          else
            ...versions.map((raw) {
              final version = raw as Map<String, dynamic>;
              final status = version['review_status']?.toString();
              final color = _statusColor(status);
              final uploader = version['uploader'] as Map<String, dynamic>?;
              final isCurrent = currentId == version['id'];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('V${version['version_number'] ?? '-'} • ${version['original_name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
                          ),
                          if (isCurrent)
                            Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: TrText('الأحدث', style: TextStyle(fontSize: 10, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan))),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(999)),
                            child: Text(trUi(_statusLabel(status)), style: TextStyle(fontSize: 10.5, color: color)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TrText('رفع بواسطة: ${uploader?['name'] ?? '-'}', style: TextStyle(fontSize: 11, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
                      if ((version['markups_count'] ?? 0) != 0)
                        Text(
                          '${version['markups_count']} طبقة Markup'.tr(),
                          style: TextStyle(fontSize: 11, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan)),
                        ),
                      if ((version['change_notes']?.toString() ?? '').isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Text(trUi(version['change_notes'].toString()), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), height: 1.45)),
                      ],
                      if ((version['review_notes']?.toString() ?? '').isNotEmpty) ...[
                        const SizedBox(height: 7),
                        TrText('ملاحظات المراجعة: ${version['review_notes']}', style: TextStyle(fontSize: 11, color: color)),
                      ],
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _downloadingId == version['id'] ? null : () => _download(version),
                            icon: const Icon(Icons.download_outlined),
                            label: const TrText('تنزيل'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _openMarkup(version),
                            icon: const Icon(Icons.draw_outlined),
                            label: const Text('Markup'),
                          ),
                          if (canReview && isCurrent && status == 'pending')
                            ElevatedButton(onPressed: _saving ? null : () => _review(version, true), child: const TrText('اعتماد')),
                          if (canReview && isCurrent && status == 'pending')
                            OutlinedButton(onPressed: _saving ? null : () => _review(version, false), child: const TrText('رفض')),
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
