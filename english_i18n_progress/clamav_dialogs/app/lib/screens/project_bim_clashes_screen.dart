import 'package:flutter/material.dart';

import '../i18n/localized_text.dart';
import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';

class ProjectBimClashesScreen extends StatefulWidget {
  final int projectId;
  final int runId;
  final String title;

  const ProjectBimClashesScreen({super.key, required this.projectId, required this.runId, required this.title});

  @override
  State<ProjectBimClashesScreen> createState() => _ProjectBimClashesScreenState();
}

class _ProjectBimClashesScreenState extends State<ProjectBimClashesScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _status;
  String? _severity;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.fetchProjectBimClashRun(projectId: widget.projectId, runId: widget.runId, status: _status, severity: _severity);
      if (mounted) setState(() => _data = data);
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _clashes => ((_data?['clashes'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  List<Map<String, dynamic>> get _users => ((_data?['project_users'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  bool get _canManage => ((_data?['permissions'] as Map?)?['can_manage'] == true);

  Future<void> _edit(Map<String, dynamic> clash) async {
    String status = clash['status']?.toString() ?? 'open';
    String severity = clash['severity']?.toString() ?? 'medium';
    int? assignedTo = int.tryParse(clash['assigned_to']?.toString() ?? '');
    final resolutionController = TextEditingController(text: clash['resolution']?.toString() ?? '');
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, setLocal) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: AlertDialog(
          title: Text('Clash #${clash['clash_number']}'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButton<String>(isExpanded: true, value: status, items: const ['open','assigned','in_review','resolved','accepted'].map((s) => DropdownMenuItem(value: s, child: Text(trUi(s)))).toList(), onChanged: (v) { if (v != null) setLocal(() => status = v); }),
            DropdownButton<String>(isExpanded: true, value: severity, items: const ['low','medium','high','critical'].map((s) => DropdownMenuItem(value: s, child: Text(trUi(s)))).toList(), onChanged: (v) { if (v != null) setLocal(() => severity = v); }),
            if (_canManage) DropdownButton<int?>(isExpanded: true, value: assignedTo, items: [const DropdownMenuItem<int?>(value: null, child: TrText('غير مسند')), ..._users.map((u) => DropdownMenuItem<int?>(value: int.tryParse(u['id'].toString()), child: Text(trUi(u['name']?.toString() ?? ''))))], onChanged: (v) => setLocal(() => assignedTo = v)),
            TextField(controller: resolutionController, minLines: 2, maxLines: 5, decoration: InputDecoration(labelText: 'الحل / الملاحظة'.tr())),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const TrText('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, {'status': status, 'severity': severity, 'assigned_to': assignedTo, 'resolution': resolutionController.text.trim()}), child: const TrText('حفظ')),
          ],
        ),
      )),
    );
    Future<void>.delayed(const Duration(milliseconds: 600), resolutionController.dispose);
    if (result == null) return;
    setState(() => _busy = true);
    try {
      await ApiService.updateProjectBimClash(projectId: widget.projectId, runId: widget.runId, clashId: int.parse(clash['id'].toString()), status: result['status'] as String, severity: result['severity'] as String, assignedTo: result['assigned_to'] as int?, clearAssignee: result['assigned_to'] == null, resolution: result['resolution']?.toString());
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: AppLanguage.instance.textDirection, child: Scaffold(
      appBar: AppBar(title: Text(trUi(widget.title)), actions: [if (_busy) const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))]),
      body: _buildBody(),
    ));
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: FilledButton(onPressed: _load, child: Text(trUi(_error!))));
    final run = Map<String, dynamic>.from((_data?['run'] as Map?) ?? const {});
    return RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(trUi(run['title']?.toString() ?? widget.title), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('${run['mode'] ?? ''} • إجمالي ${run['total_clashes'] ?? 0} • مفتوح ${run['open_clashes'] ?? 0}'.tr(), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          DropdownButton<String?>(value: _status, hint: const TrText('كل الحالات'), items: const [DropdownMenuItem<String?>(value: null, child: TrText('كل الحالات')), DropdownMenuItem(value: 'open', child: Text('open')), DropdownMenuItem(value: 'assigned', child: Text('assigned')), DropdownMenuItem(value: 'in_review', child: Text('in_review')), DropdownMenuItem(value: 'resolved', child: Text('resolved')), DropdownMenuItem(value: 'accepted', child: Text('accepted'))], onChanged: (v) { setState(() => _status = v); _load(); }),
          DropdownButton<String?>(value: _severity, hint: const TrText('كل الدرجات'), items: const [DropdownMenuItem<String?>(value: null, child: TrText('كل الدرجات')), DropdownMenuItem(value: 'low', child: Text('low')), DropdownMenuItem(value: 'medium', child: Text('medium')), DropdownMenuItem(value: 'high', child: Text('high')), DropdownMenuItem(value: 'critical', child: Text('critical'))], onChanged: (v) { setState(() => _severity = v); _load(); }),
        ]),
      ]))),
      const SizedBox(height: 12),
      if (_clashes.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: TrText('لا توجد تعارضات مطابقة.')))) else ..._clashes.map((c) => Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
        leading: CircleAvatar(child: Text('${c['clash_number']}')),
        title: Text(trUi(c['title']?.toString() ?? 'Clash'), style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${c['element_a_name'] ?? c['element_a_ref']} ↔ ${c['element_b_name'] ?? c['element_b_ref']}\n${c['severity']} • ${c['status']}${c['assignee'] is Map ? ' • ${(c['assignee'] as Map)['name']}' : ''}'),
        isThreeLine: true,
        trailing: const Icon(Icons.edit_outlined),
        onTap: _busy ? null : () => _edit(c),
      ))),
    ]));
  }
}
