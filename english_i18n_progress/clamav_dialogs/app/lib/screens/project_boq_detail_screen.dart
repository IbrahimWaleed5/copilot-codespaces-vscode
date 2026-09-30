import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../i18n/localized_text.dart';
import 'package:open_filex/open_filex.dart';

import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';
import '../utils/app_file_picker.dart';

class ProjectBoqDetailScreen extends StatefulWidget {
  final int projectId;
  final int boqId;

  const ProjectBoqDetailScreen({
    super.key,
    required this.projectId,
    required this.boqId,
  });

  @override
  State<ProjectBoqDetailScreen> createState() => _ProjectBoqDetailScreenState();
}

class _ProjectBoqDetailScreenState extends State<ProjectBoqDetailScreen> {
  bool _loading = true;
  bool _canManage = false;
  bool _canProgress = false;
  String? _error;
  Map<String, dynamic>? _boq;
  Map<String, dynamic> _summary = {};

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
      final data = await ApiService.fetchProjectBoqAdvanced(widget.projectId, widget.boqId);
      if (!mounted) return;
      setState(() {
        _boq = Map<String, dynamic>.from(data['boq'] as Map);
        _summary = Map<String, dynamic>.from(data['summary'] as Map? ?? {});
        _canManage = data['can_manage'] == true;
        _canProgress = data['can_record_progress'] == true;
      });
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _section([Map<String, dynamic>? section]) async {
    final code = TextEditingController(text: section?['code']?.toString() ?? '');
    final name = TextEditingController(text: section?['name']?.toString() ?? '');
    final description = TextEditingController(text: section?['description']?.toString() ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: AlertDialog(
          title: Text(trUi(section == null ? 'إضافة قسم' : 'تعديل القسم')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: code, decoration: InputDecoration(labelText: 'الكود'.tr())),
                const SizedBox(height: 8),
                TextField(controller: name, decoration: InputDecoration(labelText: 'الاسم'.tr())),
                const SizedBox(height: 8),
                TextField(controller: description, minLines: 2, maxLines: 4, decoration: InputDecoration(labelText: 'الوصف'.tr())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const TrText('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, code.text.trim().isNotEmpty && name.text.trim().isNotEmpty), child: const TrText('حفظ')),
          ],
        ),
      ),
    );

    final codeText = code.text.trim();
    final nameText = name.text.trim();
    final descriptionText = description.text.trim();
    Future<void>.delayed(const Duration(milliseconds: 600), code.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), name.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), description.dispose);
    if (ok != true) return;

    try {
      final message = await ApiService.saveProjectBoqSectionAdvanced(
        projectId: widget.projectId,
        boqId: widget.boqId,
        sectionId: section == null ? null : int.parse(section['id'].toString()),
        code: codeText,
        name: nameText,
        description: descriptionText.isEmpty ? null : descriptionText,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    }
  }

  Future<void> _item(Map<String, dynamic> section, [Map<String, dynamic>? item]) async {
    final code = TextEditingController(text: item?['item_code']?.toString() ?? '');
    final description = TextEditingController(text: item?['description']?.toString() ?? '');
    final unit = TextEditingController(text: item?['unit']?.toString() ?? '');
    final quantity = TextEditingController(text: item?['quantity']?.toString() ?? '0');
    final rate = TextEditingController(text: item?['unit_rate']?.toString() ?? '0');

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: AlertDialog(
          title: Text(trUi(item == null ? 'إضافة بند' : 'تعديل البند')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: code, decoration: InputDecoration(labelText: 'كود البند'.tr())),
                const SizedBox(height: 8),
                TextField(controller: description, minLines: 2, maxLines: 5, decoration: InputDecoration(labelText: 'الوصف'.tr())),
                const SizedBox(height: 8),
                TextField(controller: unit, decoration: InputDecoration(labelText: 'الوحدة'.tr())),
                const SizedBox(height: 8),
                TextField(controller: quantity, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'الكمية'.tr())),
                const SizedBox(height: 8),
                TextField(controller: rate, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'سعر الوحدة'.tr())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const TrText('إلغاء')),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, code.text.trim().isNotEmpty && description.text.trim().isNotEmpty && unit.text.trim().isNotEmpty),
              child: const TrText('حفظ'),
            ),
          ],
        ),
      ),
    );

    final codeText = code.text.trim();
    final descriptionText = description.text.trim();
    final unitText = unit.text.trim();
    final quantityValue = double.tryParse(quantity.text.trim()) ?? 0;
    final rateValue = double.tryParse(rate.text.trim()) ?? 0;
    Future<void>.delayed(const Duration(milliseconds: 600), code.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), description.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), unit.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), quantity.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), rate.dispose);
    if (ok != true) return;

    try {
      final message = await ApiService.saveProjectBoqItemAdvanced(
        projectId: widget.projectId,
        boqId: widget.boqId,
        itemId: item == null ? null : int.parse(item['id'].toString()),
        sectionId: int.parse(section['id'].toString()),
        itemCode: codeText,
        description: descriptionText,
        unit: unitText,
        quantity: quantityValue,
        unitRate: rateValue,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    }
  }

  Future<void> _progress(Map<String, dynamic> item) async {
    final executed = TextEditingController(text: item['executed_quantity']?.toString() ?? '0');
    final cost = TextEditingController(text: item['actual_cost']?.toString() ?? '0');
    final note = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: AlertDialog(
          title: const TrText('تسجيل التقدم'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: executed, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'الكمية المنفذة'.tr())),
              const SizedBox(height: 8),
              TextField(controller: cost, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'التكلفة الفعلية'.tr())),
              const SizedBox(height: 8),
              TextField(controller: note, decoration: InputDecoration(labelText: 'ملاحظة'.tr())),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const TrText('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const TrText('حفظ')),
          ],
        ),
      ),
    );

    final executedValue = double.tryParse(executed.text.trim()) ?? 0;
    final costValue = double.tryParse(cost.text.trim()) ?? 0;
    final noteText = note.text.trim();
    Future<void>.delayed(const Duration(milliseconds: 600), executed.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), cost.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), note.dispose);
    if (ok != true) return;

    try {
      final message = await ApiService.recordProjectBoqProgressAdvanced(
        projectId: widget.projectId,
        boqId: widget.boqId,
        itemId: int.parse(item['id'].toString()),
        executedQuantity: executedValue,
        actualCost: costValue,
        note: noteText.isEmpty ? null : noteText,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    }
  }

  Future<void> _deleteSection(int id) async {
    try {
      final message = await ApiService.deleteProjectBoqSectionAdvanced(widget.projectId, widget.boqId, id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    }
  }

  Future<void> _deleteItem(int id) async {
    try {
      final message = await ApiService.deleteProjectBoqItemAdvanced(widget.projectId, widget.boqId, id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    }
  }

  Future<void> _openExport(String format) async {
    try {
      final file = await ApiService.downloadProjectBoqExportAdvanced(
        projectId: widget.projectId,
        boqId: widget.boqId,
        format: format,
      );
      final result = await OpenFilex.open(file.path);
      if (!mounted) return;
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: TrText('تم تصدير BOQ بصيغة ${format.toUpperCase()} ولكن تعذر فتح الملف تلقائيًا.',
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TrText('تعذر تصدير BOQ.')),
      );
    }
  }

  Future<void> _downloadImportTemplate() async {
    try {
      final file = await ApiService.downloadProjectBoqImportTemplateAdvanced(
        widget.projectId,
      );
      final result = await OpenFilex.open(file.path);
      if (!mounted) return;
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: TrText('تم تنزيل قالب CSV ولكن تعذر فتحه تلقائيًا.'),
          ),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    }
  }

  Future<void> _importCsv() async {
    if (!_canManage) return;
    final picked = await AppFilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    final path = picked?.path;
    if (path == null || path.isEmpty) return;

    try {
      final message = await ApiService.importProjectBoqCsvAdvanced(
        projectId: widget.projectId,
        boqId: widget.boqId,
        file: File(path),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    }
  }

  Future<void> _handleTopAction(String action) async {
    switch (action) {
      case 'pdf':
        await _openExport('pdf');
        break;
      case 'csv':
        await _openExport('csv');
        break;
      case 'template':
        await _downloadImportTemplate();
        break;
      case 'import':
        await _importCsv();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final boq = _boq;
    final sections = boq == null ? <dynamic>[] : (boq['sections'] as List? ?? []);

    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: Text(trUi(boq?['title']?.toString() ?? 'BOQ')),
          actions: [
            if (_canManage)
              IconButton(
                onPressed: () => _section(),
                icon: const Icon(Icons.create_new_folder_outlined),
                tooltip: 'إضافة قسم'.tr(),
              ),
            PopupMenuButton<String>(
              tooltip: 'تصدير واستيراد BOQ'.tr(),
              onSelected: _handleTopAction,
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'pdf',
                  child: ListTile(
                    leading: Icon(Icons.picture_as_pdf_outlined),
                    title: TrText('تصدير PDF'),
                    dense: true,
                  ),
                ),
                const PopupMenuItem(
                  value: 'csv',
                  child: ListTile(
                    leading: Icon(Icons.table_view_outlined),
                    title: TrText('تصدير CSV'),
                    dense: true,
                  ),
                ),
                if (_canManage)
                  const PopupMenuItem(
                    value: 'template',
                    child: ListTile(
                      leading: Icon(Icons.download_for_offline_outlined),
                      title: TrText('تنزيل قالب الاستيراد'),
                      dense: true,
                    ),
                  ),
                if (_canManage)
                  const PopupMenuItem(
                    value: 'import',
                    child: ListTile(
                      leading: Icon(Icons.upload_file_outlined),
                      title: TrText('استيراد CSV'),
                      dense: true,
                    ),
                  ),
              ],
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(trUi(_error!)))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Wrap(
                              spacing: 14,
                              runSpacing: 10,
                              children: [
                                _summaryItem('الإجمالي الفرعي', _summary['subtotal']),
                                _summaryItem('الطوارئ', _summary['contingency_amount']),
                                _summaryItem('الخصم', _summary['discount_amount']),
                                _summaryItem('الضريبة', _summary['tax_amount']),
                                _summaryItem('الإجمالي الكلي', _summary['grand_total']),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...sections.map((raw) => _sectionCard(Map<String, dynamic>.from(raw as Map))),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _summaryItem(String label, dynamic value) => SizedBox(
        width: 145,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(trUi(label), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : AppColors.textSecondary), fontSize: 11)),
            const SizedBox(height: 2),
            Text(trUi(value?.toString() ?? '0'), style: TextStyle(fontWeight: FontWeight.w800, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan))),
          ],
        ),
      );

  Widget _sectionCard(Map<String, dynamic> section) {
    final items = section['items'] as List? ?? [];
    final sectionId = int.parse(section['id'].toString());
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text('${section['code'] ?? ''} — ${section['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: TrText('${items.length} بند'),
        trailing: _canManage
            ? PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') _section(section);
                  if (v == 'add') _item(section);
                  if (v == 'delete') _deleteSection(sectionId);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'add', child: TrText('إضافة بند')),
                  PopupMenuItem(value: 'edit', child: TrText('تعديل القسم')),
                  PopupMenuItem(value: 'delete', child: TrText('حذف القسم')),
                ],
              )
            : null,
        children: items.map((raw) {
          final item = Map<String, dynamic>.from(raw as Map);
          final itemId = int.parse(item['id'].toString());
          final quantity = (item['quantity'] as num?)?.toDouble() ?? 0;
          final executed = (item['executed_quantity'] as num?)?.toDouble() ?? 0;
          final progress = quantity <= 0 ? 0.0 : (executed / quantity).clamp(0.0, 1.0).toDouble();
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('${item['item_code'] ?? ''} — ${item['description'] ?? ''}')),
                    if (_canManage || _canProgress)
                      PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'edit') _item(section, item);
                          if (v == 'progress') _progress(item);
                          if (v == 'delete') _deleteItem(itemId);
                        },
                        itemBuilder: (_) => [
                          if (_canManage) const PopupMenuItem(value: 'edit', child: TrText('تعديل')),
                          if (_canProgress) const PopupMenuItem(value: 'progress', child: TrText('تسجيل تقدم')),
                          if (_canManage) const PopupMenuItem(value: 'delete', child: TrText('حذف')),
                        ],
                      ),
                  ],
                ),
                Text('${item['quantity'] ?? 0} ${item['unit'] ?? ''} × ${item['unit_rate'] ?? 0} = ${item['total_amount'] ?? 0}', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 11)),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: progress, minHeight: 7, borderRadius: BorderRadius.circular(7)),
                const SizedBox(height: 3),
                TrText('${(progress * 100).round()}% منفذ', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan), fontSize: 11)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
