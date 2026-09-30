import 'package:flutter/material.dart';

import '../i18n/localized_text.dart';
import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';

class ProjectEngineerAllocationsScreen extends StatefulWidget {
  final int projectId;
  final String projectTitle;

  const ProjectEngineerAllocationsScreen({
    super.key,
    required this.projectId,
    required this.projectTitle,
  });

  @override
  State<ProjectEngineerAllocationsScreen> createState() => _ProjectEngineerAllocationsScreenState();
}

class _ProjectEngineerAllocationsScreenState extends State<ProjectEngineerAllocationsScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _busy = false;
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
      final data = await ApiService.fetchProjectEngineerAllocations(widget.projectId);
      if (!mounted) return;
      setState(() => _data = data);
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit({Map<String, dynamic>? allocation}) async {
    final engineers = List<dynamic>.from(_data?['engineers'] as List? ?? const []);
    if (engineers.isEmpty) {
      _snack('لا يوجد مهندسون فعالون داخل المكتب حاليًا.'.tr());
      return;
    }

    int? selectedEngineerId = allocation?['engineer_id'] is int
        ? allocation!['engineer_id'] as int
        : int.tryParse(allocation?['engineer_id']?.toString() ?? '');
    selectedEngineerId ??= int.tryParse(engineers.first['id'].toString());
    final pct = TextEditingController(text: allocation?['percentage']?.toString() ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(trUi(allocation == null ? 'تحديد نسبة مهندس' : 'تعديل نسبة المهندس')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: selectedEngineerId,
                  decoration: InputDecoration(labelText: 'المهندس'.tr()),
                  items: engineers.map((raw) {
                    final e = Map<String, dynamic>.from(raw as Map);
                    return DropdownMenuItem<int>(
                      value: int.tryParse(e['id'].toString()),
                      child: Text(trUi(e['name']?.toString() ?? '-')),
                    );
                  }).toList(),
                  onChanged: allocation == null ? (v) => setDialogState(() => selectedEngineerId = v) : null,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pct,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'النسبة %'.tr()),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TrText('المجموع الحالي: ${(_data?['total_percentage'] ?? 0)}%',
                    style: TextStyle(fontSize: 11, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const TrText('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const TrText('حفظ')),
            ],
          ),
        ),
      ),
    );

    final percentage = double.tryParse(pct.text.trim());
    Future<void>.delayed(const Duration(milliseconds: 600), pct.dispose);
    if (confirmed != true || selectedEngineerId == null || percentage == null) return;

    await _run(() => ApiService.saveProjectEngineerAllocation(
          projectId: widget.projectId,
          engineerId: selectedEngineerId!,
          percentage: percentage,
        ));
  }

  Future<void> _remove(Map<String, dynamic> allocation) async {
    final name = (allocation['engineer'] as Map?)?['name']?.toString() ?? 'المهندس'.tr();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: AlertDialog(
          title: const TrText('إلغاء نسبة المهندس'),
          content: TrText('هل تريد إلغاء نسبة $name من هذا المشروع؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const TrText('رجوع')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const TrText('إلغاء النسبة')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await _run(() => ApiService.deleteProjectEngineerAllocation(
          projectId: widget.projectId,
          allocationId: int.parse(allocation['id'].toString()),
        ));
  }

  Future<void> _run(Future<String> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final message = await action();
      if (!mounted) return;
      _snack(message);
      await _load();
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: const TrText('نسب مهندسي المشروع'),
          actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded))],
        ),
        floatingActionButton: _data?['can_manage'] == true
            ? FloatingActionButton.extended(
                onPressed: _busy ? null : () => _edit(),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const TrText('تحديد نسبة'),
              )
            : null,
        body: _body(),
      ),
    );
  }

  Widget _body() {
    if (_loading && _data == null) return const Center(child: CircularProgressIndicator());
    if (_error != null && _data == null) {
      return Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(trUi(_error!), textAlign: TextAlign.center)));
    }

    final allocations = List<dynamic>.from(_data?['allocations'] as List? ?? const []);
    final total = double.tryParse(_data?['total_percentage']?.toString() ?? '') ?? 0;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 95),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircleAvatar(child: Icon(Icons.engineering_outlined)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(trUi(widget.projectTitle), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        const SizedBox(height: 4),
                        TrText('إجمالي النسب: ${total.toStringAsFixed(2)}%', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
                      ],
                    ),
                  ),
                  if (total > 100.001) const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (allocations.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(20), child: TrText('لم يتم تحديد نسب مهندسي المشروع بعد.')))
          else
            ...allocations.map((raw) {
              final a = Map<String, dynamic>.from(raw as Map);
              final engineer = a['engineer'] is Map ? Map<String, dynamic>.from(a['engineer'] as Map) : <String, dynamic>{};
              return Card(
                margin: const EdgeInsets.only(bottom: 9),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person_outline_rounded)),
                  title: Text(trUi(engineer['name']?.toString() ?? '-'), style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(trUi(engineer['email']?.toString() ?? '')),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${a['percentage'] ?? 0}%', style: TextStyle(fontWeight: FontWeight.w900, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan))),
                      PopupMenuButton<String>(
                        enabled: !_busy,
                        onSelected: (value) {
                          if (value == 'edit') _edit(allocation: a);
                          if (value == 'remove') _remove(a);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: TrText('تعديل النسبة')),
                          PopupMenuItem(value: 'remove', child: TrText('إلغاء النسبة')),
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
