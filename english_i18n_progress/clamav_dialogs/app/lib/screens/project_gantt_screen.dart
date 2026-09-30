import 'package:flutter/material.dart';

import '../i18n/localized_text.dart';
import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';

class ProjectGanttScreen extends StatefulWidget {
  final int projectId;
  final String projectTitle;

  const ProjectGanttScreen({
    super.key,
    required this.projectId,
    required this.projectTitle,
  });

  @override
  State<ProjectGanttScreen> createState() => _ProjectGanttScreenState();
}

class _ProjectGanttScreenState extends State<ProjectGanttScreen> {
  bool _loading = true;
  bool _canManage = false;
  String? _error;
  List<dynamic> _items = [];
  List<dynamic> _dependencies = [];
  List<dynamic> _baselines = [];
  Map<String, dynamic> _stats = {};

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
      final data = await ApiService.fetchProjectGanttAdvanced(widget.projectId);
      if (!mounted) return;
      setState(() {
        _items = data['items'] as List? ?? [];
        _dependencies = data['dependencies'] as List? ?? [];
        _baselines = data['baselines'] as List? ?? [];
        _stats = Map<String, dynamic>.from(data['stats'] as Map? ?? {});
        _canManage = data['can_manage'] == true;
      });
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editItem([Map<String, dynamic>? item]) async {
    final title = TextEditingController(text: item?['title']?.toString() ?? '');
    final start = TextEditingController(text: item?['start_date']?.toString().split('T').first ?? '');
    final end = TextEditingController(text: item?['end_date']?.toString().split('T').first ?? '');
    final description = TextEditingController(text: item?['description']?.toString() ?? '');
    final progress = TextEditingController(text: (item?['progress'] ?? 0).toString());

    String type = item?['type']?.toString() ?? 'task';
    String status = item?['status']?.toString() ?? 'not_started';
    String priority = item?['priority']?.toString() ?? 'normal';

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(trUi(item == null ? 'إضافة بند Gantt' : 'تعديل بند Gantt')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: title, decoration: InputDecoration(labelText: 'العنوان'.tr())),
                  const SizedBox(height: 8),
                  TextField(controller: description, minLines: 2, maxLines: 4, decoration: InputDecoration(labelText: 'الوصف'.tr())),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: start, decoration: InputDecoration(labelText: 'البداية YYYY-MM-DD'.tr()))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: end, decoration: InputDecoration(labelText: 'النهاية YYYY-MM-DD'.tr()))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: progress, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'الإنجاز %'.tr())),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    value: type,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'task', child: TrText('مهمة')),
                      DropdownMenuItem(value: 'milestone', child: Text('Milestone')),
                      DropdownMenuItem(value: 'phase', child: TrText('مرحلة')),
                      DropdownMenuItem(value: 'deliverable', child: TrText('تسليم')),
                    ],
                    onChanged: (v) => setDialogState(() => type = v ?? type),
                  ),
                  DropdownButton<String>(
                    value: status,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'not_started', child: TrText('لم يبدأ')),
                      DropdownMenuItem(value: 'in_progress', child: TrText('قيد التنفيذ')),
                      DropdownMenuItem(value: 'completed', child: TrText('مكتمل')),
                      DropdownMenuItem(value: 'on_hold', child: TrText('معلّق')),
                      DropdownMenuItem(value: 'cancelled', child: TrText('ملغي')),
                    ],
                    onChanged: (v) => setDialogState(() => status = v ?? status),
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
              FilledButton(
                onPressed: () => Navigator.pop(
                  dialogContext,
                  title.text.trim().isNotEmpty && start.text.trim().isNotEmpty && end.text.trim().isNotEmpty,
                ),
                child: const TrText('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );

    final titleText = title.text.trim();
    final startText = start.text.trim();
    final endText = end.text.trim();
    final descriptionText = description.text.trim();
    final progressValue = int.tryParse(progress.text.trim()) ?? 0;
    Future<void>.delayed(const Duration(milliseconds: 600), title.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), start.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), end.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), description.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), progress.dispose);

    if (ok != true) return;

    try {
      final message = await ApiService.saveProjectGanttItemAdvanced(
        projectId: widget.projectId,
        itemId: item == null ? null : int.parse(item['id'].toString()),
        title: titleText,
        type: type,
        status: status,
        priority: priority,
        startDate: startText,
        endDate: endText,
        progress: progressValue < 0 ? 0 : (progressValue > 100 ? 100 : progressValue),
        description: descriptionText.isEmpty ? null : descriptionText,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    }
  }

  Future<void> _progress(Map<String, dynamic> item) async {
    double value = ((item['progress'] as num?)?.toDouble() ?? 0).clamp(0.0, 100.0).toDouble();
    final result = await showDialog<int?>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const TrText('تحديث نسبة الإنجاز'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Slider(
                  value: value,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  label: '${value.round()}%',
                  onChanged: (v) => setDialogState(() => value = v),
                ),
                Text('${value.round()}%'),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const TrText('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, value.round()), child: const TrText('حفظ')),
            ],
          ),
        ),
      ),
    );
    if (result == null) return;
    try {
      final message = await ApiService.updateProjectGanttProgressAdvanced(
        widget.projectId,
        int.parse(item['id'].toString()),
        result,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    }
  }

  Future<void> _delete(int id) async {
    try {
      final message = await ApiService.deleteProjectGanttItemAdvanced(widget.projectId, id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    }
  }

  Future<void> _baseline() async {
    final c = TextEditingController();
    final name = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: AlertDialog(
          title: const TrText('حفظ Baseline'),
          content: TextField(controller: c, decoration: InputDecoration(labelText: 'اسم Baseline'.tr())),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const TrText('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, c.text.trim()), child: const TrText('حفظ')),
          ],
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 600), c.dispose);
    if (name == null || name.isEmpty) return;
    try {
      final message = await ApiService.createProjectGanttBaselineAdvanced(widget.projectId, name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    }
  }

  Future<void> _dependency() async {
    if (_items.length < 2) return;
    int predecessorId = int.parse((_items.first as Map)['id'].toString());
    int successorId = int.parse((_items[1] as Map)['id'].toString());
    String type = 'FS';
    int lag = 0;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const TrText('إضافة Dependency'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<int>(
                  value: predecessorId,
                  isExpanded: true,
                  items: _items.map((raw) {
                    final item = Map<String, dynamic>.from(raw as Map);
                    return DropdownMenuItem(
                      value: int.parse(item['id'].toString()),
                      child: TrText('السابق: ${item['title'] ?? ''}', overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (v) => setDialogState(() => predecessorId = v ?? predecessorId),
                ),
                DropdownButton<int>(
                  value: successorId,
                  isExpanded: true,
                  items: _items.map((raw) {
                    final item = Map<String, dynamic>.from(raw as Map);
                    return DropdownMenuItem(
                      value: int.parse(item['id'].toString()),
                      child: TrText('اللاحق: ${item['title'] ?? ''}', overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (v) => setDialogState(() => successorId = v ?? successorId),
                ),
                DropdownButton<String>(
                  value: type,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'FS', child: Text('Finish → Start')),
                    DropdownMenuItem(value: 'SS', child: Text('Start → Start')),
                    DropdownMenuItem(value: 'FF', child: Text('Finish → Finish')),
                    DropdownMenuItem(value: 'SF', child: Text('Start → Finish')),
                  ],
                  onChanged: (v) => setDialogState(() => type = v ?? type),
                ),
                TextFormField(
                  initialValue: '0',
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Lag days'),
                  onChanged: (v) => lag = int.tryParse(v) ?? 0,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const TrText('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, predecessorId != successorId), child: const TrText('إضافة')),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;

    try {
      final message = await ApiService.createProjectGanttDependencyAdvanced(
        projectId: widget.projectId,
        predecessorId: predecessorId,
        successorId: successorId,
        dependencyType: type,
        lagDays: lag,
      );
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
          appBar: AppBar(
            title: Text('Gantt — ${widget.projectTitle}'),
            actions: _canManage
                ? [
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'baseline') _baseline();
                        if (v == 'dependency') _dependency();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'baseline', child: TrText('حفظ Baseline')),
                        PopupMenuItem(value: 'dependency', child: TrText('إضافة Dependency')),
                      ],
                    ),
                  ]
                : null,
          ),
          floatingActionButton: _canManage
              ? FloatingActionButton.extended(onPressed: () => _editItem(), icon: const Icon(Icons.add), label: const TrText('بند'))
              : null,
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(trUi(_error!)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _stat('الإجمالي', _stats['total']),
                              _stat('مكتمل', _stats['completed']),
                              _stat('قيد التنفيذ', _stats['in_progress']),
                              _stat('متأخر', _stats['overdue']),
                              _stat('حرج', _stats['critical']),
                              _stat('الإنجاز', '${_stats['progress'] ?? 0}%'),
                            ],
                          ),
                          if (_baselines.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text('Baselines: ${_baselines.length}', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : AppColors.textSecondary))),
                          ],
                          const SizedBox(height: 12),
                          ..._items.map((raw) => _itemCard(Map<String, dynamic>.from(raw as Map))),
                          if (_dependencies.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            const Text('Dependencies', style: TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            ..._dependencies.map((raw) {
                              final d = Map<String, dynamic>.from(raw as Map);
                              return Card(
                                child: ListTile(
                                  title: Text('${(d['predecessor'] as Map?)?['title'] ?? '-'} → ${(d['successor'] as Map?)?['title'] ?? '-'}'),
                                  subtitle: Text('${d['dependency_type'] ?? ''} • lag ${d['lag_days'] ?? 0} days'),
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
        ),
      );

  Widget _stat(String label, dynamic value) => Chip(label: Text('$label: ${value ?? 0}'));

  Widget _itemCard(Map<String, dynamic> item) {
    final progress = ((item['progress'] as num?)?.toDouble() ?? 0).clamp(0.0, 100.0).toDouble();
    final id = int.parse(item['id'].toString());
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('${item['item_number'] ?? ''} ${item['title'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800))),
                if (_canManage)
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') _editItem(item);
                      if (v == 'progress') _progress(item);
                      if (v == 'delete') _delete(id);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: TrText('تعديل')),
                      PopupMenuItem(value: 'progress', child: TrText('تحديث الإنجاز')),
                      PopupMenuItem(value: 'delete', child: TrText('حذف')),
                    ],
                  ),
              ],
            ),
            Text('${item['start_date'] ?? ''} → ${item['end_date'] ?? ''}', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 11)),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress / 100, minHeight: 8, borderRadius: BorderRadius.circular(8)),
            const SizedBox(height: 4),
            Text('${progress.round()}% • ${item['status'] ?? ''}', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
