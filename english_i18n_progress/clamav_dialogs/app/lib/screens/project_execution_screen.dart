import 'package:flutter/material.dart';

import '../i18n/localized_text.dart';
import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';
import 'project_bim_screen.dart';
import 'project_change_orders_screen.dart';
import 'project_final_report_screen.dart';
import 'project_field_management_screen.dart';
import 'project_rfis_screen.dart';
import 'project_team_chat_screen.dart';

class ProjectExecutionScreen extends StatefulWidget {
  final int projectId;
  final String projectTitle;

  const ProjectExecutionScreen({
    super.key,
    required this.projectId,
    required this.projectTitle,
  });

  @override
  State<ProjectExecutionScreen> createState() => _ProjectExecutionScreenState();
}

class _ProjectExecutionScreenState extends State<ProjectExecutionScreen> {
  Map<String, dynamic>? _data;
  Map<String, dynamic>? _lifecycle;
  bool _loading = true;
  bool _acting = false;
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
      final results = await Future.wait([
        ApiService.fetchProjectExecutionDashboard(widget.projectId),
        ApiService.fetchProjectLifecycle(widget.projectId),
      ]);
      if (!mounted) return;
      setState(() {
        _data = results[0];
        _lifecycle = results[1];
      });
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _statusLabel(String? status) {
    const labels = {
      'approved': 'معتمد',
      'in_progress': 'قيد التنفيذ',
      'on_hold': 'متوقف مؤقتًا',
      'pending_customer_completion': 'بانتظار اعتماد الإنهاء',
      'completed': 'مكتمل',
      'cancelled': 'ملغي',
    };
    return labels[status] ?? status ?? 'غير محدد'.tr();
  }

  Future<String?> _askText(String title, String label) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: AlertDialog(
          title: Text(trUi(title)),
          content: TextField(
            controller: controller,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(labelText: trUiN(label)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const TrText('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
              child: const TrText('متابعة'),
            ),
          ],
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 600), controller.dispose);
    return result;
  }

  Future<void> _act(String action) async {
    if (_acting) return;
    String? reason;
    if (action == 'pause') {
      reason = await _askText('إيقاف المشروع مؤقتًا', 'سبب الإيقاف');
      if (reason == null || reason.length < 5) return;
    } else if (action == 'reject-completion') {
      reason = await _askText('رفض طلب الإنهاء', 'سبب الرفض');
      if (reason == null || reason.length < 5) return;
    }

    setState(() => _acting = true);
    try {
      final message = await ApiService.projectLifecycleAction(
        projectId: widget.projectId,
        action: action,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        appBar: AppBar(title: TrText('تنفيذ المشروع — ${widget.projectTitle}')),
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

    final data = _data ?? const <String, dynamic>{};
    final project = (data['project'] as Map<String, dynamic>?) ?? const {};
    final counts = (data['counts'] as Map<String, dynamic>?) ?? const {};
    final progress = (data['progress'] as Map<String, dynamic>?) ?? const {};
    final finance = (data['finance'] as Map<String, dynamic>?) ?? const {};
    final lifecycle = _lifecycle ?? const <String, dynamic>{};
    final permissions = (lifecycle['permissions'] as Map<String, dynamic>?) ?? const {};
    final checks = (lifecycle['checks'] as Map<String, dynamic>?) ?? const {};
    final status = project['status']?.toString();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trUi(project['project_number']?.toString() ?? ''),
                    style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 12),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    trUi(project['title']?.toString() ?? widget.projectTitle),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _pill(_statusLabel(status), (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan)),
                      _pill('المراحل ${progress['milestones'] ?? 0}٪', AppColors.primaryLight),
                      _pill('المهام ${progress['tasks'] ?? 0}٪', AppColors.success),
                      _pill('التحصيل ${progress['collection'] ?? 0}٪', Colors.amberAccent),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _sectionTitle('مؤشرات التنفيذ'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _metric('RFI مفتوح', '${counts['rfis_open'] ?? 0}', Icons.help_outline_rounded),
              _metric('RFI متأخر', '${counts['rfis_overdue'] ?? 0}', Icons.warning_amber_rounded),
              _metric('أوامر تغيير', '${counts['change_orders_pending'] ?? 0}', Icons.change_circle_outlined),
              _metric('ملفات', '${counts['files'] ?? 0}', Icons.folder_copy_outlined),
              _metric('سجلات موقع مفتوحة', '${counts['field_open'] ?? 0}', Icons.engineering_outlined),
              _metric('سجلات موقع متأخرة', '${counts['field_overdue'] ?? 0}', Icons.timer_off_outlined),
              _metric('نماذج BIM', '${counts['bim_models'] ?? 0}', Icons.view_in_ar_outlined),
              _metric('Clash مفتوح', '${counts['bim_open_clashes'] ?? 0}', Icons.hub_outlined),
            ],
          ),
          const SizedBox(height: 18),
          _sectionTitle('الوحدات التنفيذية'),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.28,
            children: [
              _module(
                Icons.help_center_outlined,
                'RFI',
                'الاستفسارات والإجابات والتعليقات',
                () => _open(ProjectRfisScreen(projectId: widget.projectId, projectTitle: widget.projectTitle)),
              ),
              _module(
                Icons.engineering_outlined,
                'إدارة الموقع',
                'Daily Reports • IR • ITP • NCR • Snag • Safety',
                () => _open(ProjectFieldManagementScreen(
                  projectId: widget.projectId,
                  projectTitle: widget.projectTitle,
                )),
              ),
              _module(
                Icons.view_in_ar_rounded,
                'BIM + Clash',
                'نماذج BIM • الإصدارات • Clash Detection',
                () => _open(ProjectBimScreen(
                  projectId: widget.projectId,
                  projectTitle: widget.projectTitle,
                )),
              ),
              _module(
                Icons.change_circle_outlined,
                'أوامر التغيير',
                'تغيير النطاق والقيمة والمدة',
                () => _open(ProjectChangeOrdersScreen(projectId: widget.projectId, projectTitle: widget.projectTitle)),
              ),
              _module(
                Icons.forum_outlined,
                'محادثة الفريق',
                'رسائل ومرفقات فريق المشروع',
                () => _open(ProjectTeamChatScreen(projectId: widget.projectId, projectTitle: widget.projectTitle)),
              ),
              _module(
                Icons.description_outlined,
                'التقرير النهائي',
                'يظهر بعد اكتمال المشروع',
                () => _open(ProjectFinalReportScreen(projectId: widget.projectId, projectTitle: widget.projectTitle)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _sectionTitle('دورة حياة المشروع'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TrText('الحالة الحالية: ${_statusLabel(status)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  TrText('مهام غير مكتملة: ${checks['unfinished_tasks'] ?? 0} • دفعات غير مسوّاة: ${checks['unsettled_installments'] ?? 0}',
                    style: TextStyle(fontSize: 12, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant)),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (permissions['can_start'] == true) _actionButton('بدء المشروع', 'start', Icons.play_arrow_rounded),
                      if (permissions['can_pause'] == true) _actionButton('إيقاف مؤقت', 'pause', Icons.pause_rounded),
                      if (permissions['can_resume'] == true) _actionButton('استئناف', 'resume', Icons.play_circle_outline_rounded),
                      if (permissions['can_request_completion'] == true) _actionButton('طلب الإنهاء', 'request-completion', Icons.task_alt_rounded),
                      if (permissions['can_approve_completion'] == true) _actionButton('اعتماد الإنهاء', 'approve-completion', Icons.verified_outlined),
                      if (permissions['can_reject_completion'] == true) _actionButton('رفض الإنهاء', 'reject-completion', Icons.cancel_outlined),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          _sectionTitle('ملخص مالي'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 18,
                runSpacing: 10,
                children: [
                  _money('مدفوع', finance['paid_amount']),
                  _money('قيد المراجعة', finance['pending_amount']),
                  _money('متبقي', finance['remaining_amount']),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(trUi(text), style: TextStyle(fontSize: 11, color: color)),
    );
  }

  Widget _metric(String label, String value, IconData icon) {
    return SizedBox(
      width: (MediaQuery.sizeOf(context).width - 42) / 2,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan)),
              const SizedBox(height: 9),
              Text(trUi(value), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
              Text(trUi(label), style: TextStyle(fontSize: 11, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _module(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan)),
              const Spacer(),
              Text(trUi(title), style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                trUi(subtitle),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), height: 1.35),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton(String title, String action, IconData icon) {
    return OutlinedButton.icon(
      onPressed: _acting ? null : () => _act(action),
      icon: Icon(icon, size: 18),
      label: Text(trUi(title)),
    );
  }

  Widget _money(String label, dynamic value) {
    return SizedBox(
      width: 95,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(trUi(label), style: TextStyle(fontSize: 11, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
          const SizedBox(height: 3),
          Text('${value ?? 0} ₪', style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(trUi(text), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800));
}
