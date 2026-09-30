import 'package:flutter/material.dart';

import '../i18n/localized_text.dart';
import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';
import 'milestone_submissions_screen.dart';

class ProjectMilestonesScreen extends StatefulWidget {
  final int projectId;
  final String projectTitle;

  const ProjectMilestonesScreen({
    super.key,
    required this.projectId,
    required this.projectTitle,
  });

  @override
  State<ProjectMilestonesScreen> createState() => _ProjectMilestonesScreenState();
}

class _ProjectMilestonesScreenState extends State<ProjectMilestonesScreen> {
  List<dynamic> _milestones = [];
  List<dynamic> _teamMembers = [];
  bool _canManage = false;
  bool _loading = true;
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
      final data = await ApiService.fetchProjectMilestones(widget.projectId);
      if (!mounted) return;
      setState(() {
        _milestones = List<dynamic>.from(data['items'] as List? ?? const []);
        _teamMembers = List<dynamic>.from(data['team_members'] as List? ?? const []);
        _canManage = data['can_manage'] == true;
      });
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _statusLabel(String? status) {
    const labels = {
      'pending': 'لم تبدأ',
      'in_progress': 'قيد التنفيذ',
      'completed': 'مكتملة',
      'on_hold': 'متوقفة',
      'blocked': 'معطّلة',
    };
    return labels[status] ?? status ?? '';
  }

  String _priorityLabel(String? priority) {
    const labels = {
      'low': 'منخفضة',
      'medium': 'متوسطة',
      'high': 'مرتفعة',
      'urgent': 'عاجلة',
    };
    return labels[priority] ?? priority ?? '';
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'completed':
        return AppColors.success;
      case 'in_progress':
        return (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan);
      case 'blocked':
        return AppColors.danger;
      case 'on_hold':
        return Colors.orangeAccent;
      default:
        return (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : AppColors.textSecondary);
    }
  }

  String? _dateOnly(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return null;
    return raw.length >= 10 ? raw.substring(0, 10) : raw;
  }

  Future<void> _showMessage(String message) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
  }

  Future<bool> _confirm(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => Directionality(
            textDirection: AppLanguage.instance.textDirection,
            child: AlertDialog(
              title: Text(trUi(title)),
              content: Text(trUi(message)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const TrText('إلغاء')),
                FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const TrText('تأكيد')),
              ],
            ),
          ),
        ) ??
        false;
  }

  Future<void> _editMilestone([Map<String, dynamic>? milestone]) async {
    if (!_canManage) return;
    final title = TextEditingController(text: milestone?['title']?.toString() ?? '');
    final description = TextEditingController(text: milestone?['description']?.toString() ?? '');
    final startDate = TextEditingController(text: _dateOnly(milestone?['start_date']) ?? '');
    final endDate = TextEditingController(text: _dateOnly(milestone?['end_date']) ?? '');
    var status = milestone?['status']?.toString() ?? 'pending';
    var progress = ((milestone?['progress'] as num?)?.toDouble() ?? 0).clamp(0, 100).toDouble();
    var saving = false;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: !saving,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => Directionality(
          textDirection: AppLanguage.instance.textDirection,
          child: AlertDialog(
            title: Text(trUi(milestone == null ? 'إضافة مرحلة' : 'تعديل المرحلة')),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: title, decoration: InputDecoration(labelText: 'عنوان المرحلة *'.tr())),
                    const SizedBox(height: 10),
                    TextField(controller: description, maxLines: 3, decoration: InputDecoration(labelText: 'الوصف'.tr())),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: TextField(controller: startDate, decoration: InputDecoration(labelText: 'تاريخ البداية'.tr(), hintText: 'YYYY-MM-DD'))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: endDate, decoration: InputDecoration(labelText: 'تاريخ النهاية'.tr(), hintText: 'YYYY-MM-DD'))),
                    ]),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: InputDecoration(labelText: 'الحالة'.tr()),
                      items: const [
                        DropdownMenuItem(value: 'pending', child: TrText('لم تبدأ')),
                        DropdownMenuItem(value: 'in_progress', child: TrText('قيد التنفيذ')),
                        DropdownMenuItem(value: 'completed', child: TrText('مكتملة')),
                        DropdownMenuItem(value: 'on_hold', child: TrText('متوقفة')),
                      ],
                      onChanged: saving
                          ? null
                          : (value) => setLocal(() {
                                status = value ?? status;
                                if (status == 'completed') progress = 100;
                              }),
                    ),
                    const SizedBox(height: 14),
                    Row(children: [
                      const TrText('نسبة الإنجاز'),
                      const Spacer(),
                      TrText('${progress.round()}٪', style: TextStyle(fontWeight: FontWeight.w800, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan))),
                    ]),
                    Slider(
                      value: progress,
                      min: 0,
                      max: 100,
                      divisions: 20,
                      onChanged: saving || status == 'completed' ? null : (v) => setLocal(() => progress = v),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext, false), child: const TrText('إلغاء')),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (title.text.trim().isEmpty) return;
                        setLocal(() => saving = true);
                        try {
                          final message = milestone == null
                              ? await ApiService.createProjectMilestone(
                                  projectId: widget.projectId,
                                  title: title.text.trim(),
                                  description: description.text.trim().isEmpty ? null : description.text.trim(),
                                  startDate: startDate.text.trim().isEmpty ? null : startDate.text.trim(),
                                  endDate: endDate.text.trim().isEmpty ? null : endDate.text.trim(),
                                  status: status,
                                  progress: progress.round(),
                                )
                              : await ApiService.updateProjectMilestone(
                                  projectId: widget.projectId,
                                  milestoneId: int.parse(milestone['id'].toString()),
                                  title: title.text.trim(),
                                  description: description.text.trim().isEmpty ? null : description.text.trim(),
                                  startDate: startDate.text.trim().isEmpty ? null : startDate.text.trim(),
                                  endDate: endDate.text.trim().isEmpty ? null : endDate.text.trim(),
                                  status: status,
                                  progress: progress.round(),
                                );
                          if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                          await _showMessage(message);
                        } on ApiException catch (e) {
                          setLocal(() => saving = false);
                          if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text(trUi(e.message))));
                        }
                      },
                child: saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const TrText('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 600), title.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), description.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), startDate.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), endDate.dispose);
    if (saved == true) await _load();
  }

  Future<void> _deleteMilestone(Map<String, dynamic> milestone) async {
    if (!_canManage) return;
    final ok = await _confirm('حذف المرحلة', 'سيتم حذف المرحلة وجميع مهامها. هل تريد المتابعة؟');
    if (!ok) return;
    try {
      final message = await ApiService.deleteProjectMilestone(
        projectId: widget.projectId,
        milestoneId: int.parse(milestone['id'].toString()),
      );
      await _showMessage(message);
      await _load();
    } on ApiException catch (e) {
      await _showMessage(e.message);
    }
  }

  Future<void> _editTask(Map<String, dynamic> milestone, [Map<String, dynamic>? task]) async {
    if (!_canManage) return;
    final title = TextEditingController(text: task?['title']?.toString() ?? '');
    final description = TextEditingController(text: task?['description']?.toString() ?? '');
    final startDate = TextEditingController(text: _dateOnly(task?['start_date']) ?? '');
    final dueDate = TextEditingController(text: _dateOnly(task?['due_date']) ?? '');
    int? assignedTo = task?['assigned_to'] is num ? (task!['assigned_to'] as num).toInt() : int.tryParse(task?['assigned_to']?.toString() ?? '');
    var priority = task?['priority']?.toString() ?? 'medium';
    var saving = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => Directionality(
          textDirection: AppLanguage.instance.textDirection,
          child: AlertDialog(
            title: Text(trUi(task == null ? 'إضافة مهمة' : 'تعديل المهمة')),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(controller: title, decoration: InputDecoration(labelText: 'عنوان المهمة *'.tr())),
                  const SizedBox(height: 10),
                  TextField(controller: description, maxLines: 3, decoration: InputDecoration(labelText: 'الوصف'.tr())),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int?>(
                    initialValue: assignedTo,
                    decoration: InputDecoration(labelText: 'المهندس المسؤول'.tr()),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: TrText('غير مسند')),
                      ..._teamMembers.map((raw) {
                        final member = Map<String, dynamic>.from(raw as Map);
                        return DropdownMenuItem<int?>(
                          value: int.parse(member['id'].toString()),
                          child: Text(trUi(member['name']?.toString() ?? '-')),
                        );
                      }),
                    ],
                    onChanged: saving ? null : (value) => setLocal(() => assignedTo = value),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextField(controller: startDate, decoration: InputDecoration(labelText: 'تاريخ البداية'.tr(), hintText: 'YYYY-MM-DD'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: dueDate, decoration: InputDecoration(labelText: 'تاريخ الاستحقاق'.tr(), hintText: 'YYYY-MM-DD'))),
                  ]),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: priority,
                    decoration: InputDecoration(labelText: 'الأولوية'.tr()),
                    items: const [
                      DropdownMenuItem(value: 'low', child: TrText('منخفضة')),
                      DropdownMenuItem(value: 'medium', child: TrText('متوسطة')),
                      DropdownMenuItem(value: 'high', child: TrText('مرتفعة')),
                      DropdownMenuItem(value: 'urgent', child: TrText('عاجلة')),
                    ],
                    onChanged: saving ? null : (value) => setLocal(() => priority = value ?? priority),
                  ),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext, false), child: const TrText('إلغاء')),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (title.text.trim().isEmpty) return;
                        setLocal(() => saving = true);
                        try {
                          final message = task == null
                              ? await ApiService.createProjectTask(
                                  projectId: widget.projectId,
                                  milestoneId: int.parse(milestone['id'].toString()),
                                  title: title.text.trim(),
                                  description: description.text.trim().isEmpty ? null : description.text.trim(),
                                  assignedTo: assignedTo,
                                  startDate: startDate.text.trim().isEmpty ? null : startDate.text.trim(),
                                  dueDate: dueDate.text.trim().isEmpty ? null : dueDate.text.trim(),
                                  priority: priority,
                                )
                              : await ApiService.updateProjectTask(
                                  projectId: widget.projectId,
                                  taskId: int.parse(task['id'].toString()),
                                  title: title.text.trim(),
                                  description: description.text.trim().isEmpty ? null : description.text.trim(),
                                  assignedTo: assignedTo,
                                  startDate: startDate.text.trim().isEmpty ? null : startDate.text.trim(),
                                  dueDate: dueDate.text.trim().isEmpty ? null : dueDate.text.trim(),
                                  priority: priority,
                                );
                          if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                          await _showMessage(message);
                        } on ApiException catch (e) {
                          setLocal(() => saving = false);
                          if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text(trUi(e.message))));
                        }
                      },
                child: saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const TrText('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 600), title.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), description.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), startDate.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), dueDate.dispose);
    if (saved == true) await _load();
  }

  Future<void> _deleteTask(Map<String, dynamic> task) async {
    if (!_canManage) return;
    final ok = await _confirm('حذف المهمة', 'هل تريد حذف هذه المهمة نهائيًا؟');
    if (!ok) return;
    try {
      final message = await ApiService.deleteProjectTask(
        projectId: widget.projectId,
        taskId: int.parse(task['id'].toString()),
      );
      await _showMessage(message);
      await _load();
    } on ApiException catch (e) {
      await _showMessage(e.message);
    }
  }

  Future<void> _updateTaskStatus(Map<String, dynamic> task) async {
    if (task['can_update_status'] != true) return;
    String status = task['status']?.toString() ?? 'pending';
    double progress = (task['progress'] as num?)?.toDouble() ?? 0;
    bool saving = false;

    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF0D1B31) : Theme.of(context).colorScheme.surface),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) => Directionality(
          textDirection: AppLanguage.instance.textDirection,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(task['title']?.toString() ?? 'تحديث المهمة'.tr(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: ['pending', 'in_progress', 'blocked', 'completed'].map((itemStatus) {
                    final selected = status == itemStatus;
                    return ChoiceChip(
                      label: Text(trUi(_statusLabel(itemStatus))),
                      selected: selected,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(color: selected ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : AppColors.textSecondary)),
                      onSelected: saving
                          ? null
                          : (_) => setModalState(() {
                                status = itemStatus;
                                if (itemStatus == 'completed') progress = 100;
                              }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                Row(children: [const TrText('نسبة الإنجاز'), const Spacer(), TrText('${progress.round()}٪')]),
                Slider(value: progress.clamp(0, 100), min: 0, max: 100, divisions: 20, onChanged: saving || status == 'completed' ? null : (v) => setModalState(() => progress = v)),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          setModalState(() => saving = true);
                          try {
                            await ApiService.updateTaskStatus(
                              projectId: widget.projectId,
                              taskId: int.parse(task['id'].toString()),
                              status: status,
                              progress: progress.round(),
                            );
                            if (sheetContext.mounted) Navigator.pop(sheetContext, true);
                          } on ApiException catch (e) {
                            setModalState(() => saving = false);
                            if (sheetContext.mounted) ScaffoldMessenger.of(sheetContext).showSnackBar(SnackBar(content: Text(trUi(e.message))));
                          }
                        },
                  child: saving ? const CircularProgressIndicator() : const TrText('حفظ التحديث'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
    if (updated == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: TrText('المراحل والمهام — ${widget.projectTitle}'),
          actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
        ),
        floatingActionButton: _canManage
            ? FloatingActionButton.extended(onPressed: () => _editMilestone(), icon: const Icon(Icons.add), label: const TrText('مرحلة جديدة'))
            : null,
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(trUi(_error!), textAlign: TextAlign.center), const SizedBox(height: 12), ElevatedButton(onPressed: _load, child: const TrText('إعادة المحاولة'))])));
    }
    if (_milestones.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: [
          const SizedBox(height: 190),
          Icon(Icons.flag_outlined, size: 52, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          Center(child: TrText('لا توجد مراحل بعد', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant)))),
          if (_canManage) ...[
            const SizedBox(height: 16),
            Center(child: FilledButton.icon(onPressed: () => _editMilestone(), icon: const Icon(Icons.add), label: const TrText('إضافة أول مرحلة'))),
          ],
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
        itemCount: _milestones.length,
        itemBuilder: (context, index) {
          final milestone = Map<String, dynamic>.from(_milestones[index] as Map);
          final tasks = List<dynamic>.from(milestone['tasks'] as List? ?? const []);
          final taskCount = milestone['tasks_count'] ?? tasks.length;
          final progress = (milestone['progress'] as num?)?.toDouble() ?? 0;
          final status = milestone['status']?.toString();

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              leading: CircleAvatar(backgroundColor: _statusColor(status).withValues(alpha: .12), child: Text('${index + 1}', style: TextStyle(color: _statusColor(status)))),
              title: Row(children: [
                Expanded(child: Text(milestone['title']?.toString() ?? 'مرحلة'.tr(), style: const TextStyle(fontWeight: FontWeight.w700))),
                if (_canManage)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') _editMilestone(milestone);
                      if (value == 'delete') _deleteMilestone(milestone);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: TrText('تعديل المرحلة')),
                      PopupMenuItem(value: 'delete', child: TrText('حذف المرحلة')),
                    ],
                  ),
              ]),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 4),
                TrText('${_statusLabel(status)} • $taskCount مهمة', style: TextStyle(fontSize: 11, color: _statusColor(status))),
                if ((_dateOnly(milestone['start_date']) ?? '').isNotEmpty || (_dateOnly(milestone['end_date']) ?? '').isNotEmpty)
                  Text('${_dateOnly(milestone['start_date']) ?? '-'} ← ${_dateOnly(milestone['end_date']) ?? '-'}', style: TextStyle(fontSize: 11, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
                const SizedBox(height: 8),
                ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: (progress / 100).clamp(0, 1), minHeight: 5, backgroundColor: Colors.white10, color: _statusColor(status))),
              ]),
              children: [
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => MilestoneSubmissionsScreen(
                          projectId: widget.projectId,
                          milestoneId: int.parse(milestone['id'].toString()),
                          milestoneTitle: milestone['title']?.toString() ?? 'المرحلة'.tr(),
                        )));
                        if (mounted) await _load();
                      },
                      icon: const Icon(Icons.task_alt_outlined),
                      label: const TrText('التسليمات'),
                    ),
                  ),
                  if (_canManage) ...[
                    const SizedBox(width: 8),
                    Expanded(child: FilledButton.tonalIcon(onPressed: () => _editTask(milestone), icon: const Icon(Icons.add_task), label: const TrText('مهمة جديدة'))),
                  ],
                ]),
                const SizedBox(height: 8),
                if (tasks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(trUi(taskCount is num && taskCount > 0 ? 'تفاصيل مهام هذه المرحلة غير ظاهرة حسب صلاحية حسابك.' : 'لا توجد مهام في هذه المرحلة.'), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
                  )
                else
                  ...tasks.map((raw) => _taskTile(milestone, Map<String, dynamic>.from(raw as Map))),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _taskTile(Map<String, dynamic> milestone, Map<String, dynamic> task) {
    final assignee = task['assignee'] is Map ? Map<String, dynamic>.from(task['assignee'] as Map) : null;
    final status = task['status']?.toString();
    final progress = (task['progress'] as num?)?.toDouble() ?? 0;
    final canUpdate = task['can_update_status'] == true;

    return Card(
      color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: .025) : AppColors.surface,
      margin: const EdgeInsets.only(bottom: 7),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: canUpdate ? () => _updateTaskStatus(task) : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(trUi(task['title']?.toString() ?? ''), style: const TextStyle(fontWeight: FontWeight.w600))),
              Text(trUi(_statusLabel(status)), style: TextStyle(fontSize: 11, color: _statusColor(status))),
              if (_canManage)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') _editTask(milestone, task);
                    if (value == 'delete') _deleteTask(task);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: TrText('تعديل المهمة')),
                    PopupMenuItem(value: 'delete', child: TrText('حذف المهمة')),
                  ],
                ),
            ]),
            const SizedBox(height: 5),
            Wrap(spacing: 10, runSpacing: 4, children: [
              Text(assignee?['name']?.toString() ?? 'غير مسند'.tr(), style: TextStyle(fontSize: 11, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
              TrText('الأولوية: ${_priorityLabel(task['priority']?.toString())}', style: TextStyle(fontSize: 11, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
              if ((_dateOnly(task['due_date']) ?? '').isNotEmpty) TrText('الاستحقاق: ${_dateOnly(task['due_date'])}', style: TextStyle(fontSize: 11, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: (progress / 100).clamp(0, 1), minHeight: 5, backgroundColor: Colors.white10, color: _statusColor(status)))),
              const SizedBox(width: 8),
              TrText('${progress.round()}٪', style: TextStyle(fontSize: 11, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
              if (canUpdate) ...[const SizedBox(width: 7), Icon(Icons.edit_outlined, size: 15, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan))],
            ]),
          ]),
        ),
      ),
    );
  }
}
