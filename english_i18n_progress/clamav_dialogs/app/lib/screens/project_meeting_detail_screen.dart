import 'package:flutter/material.dart';
import '../i18n/localized_text.dart';
import 'package:open_filex/open_filex.dart';

import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';
import 'project_live_meeting_screen.dart';

class ProjectMeetingDetailScreen extends StatefulWidget {
  final int projectId;
  final int meetingId;

  const ProjectMeetingDetailScreen({
    super.key,
    required this.projectId,
    required this.meetingId,
  });

  @override
  State<ProjectMeetingDetailScreen> createState() => _ProjectMeetingDetailScreenState();
}

class _ProjectMeetingDetailScreenState extends State<ProjectMeetingDetailScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _liveBusy = false;
  String? _error;

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
      final data = await ApiService.fetchProjectMeetingAdvanced(
        widget.projectId,
        widget.meetingId,
      );
      if (mounted) setState(() => _data = data);
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> get _meeting =>
      Map<String, dynamic>.from(_data?['meeting'] as Map? ?? const {});

  Future<String?> _textDialog(String title, String label, {String initial = ''}) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: AlertDialog(
          title: Text(trUi(title)),
          content: TextField(
            controller: controller,
            maxLines: 5,
            decoration: InputDecoration(labelText: trUiN(label)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const TrText('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
              child: const TrText('حفظ'),
            ),
          ],
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 600), controller.dispose);
    return result;
  }

  Future<void> _minutes() async {
    final meeting = _meeting;
    final summary = await _textDialog(
      'محضر الاجتماع',
      'ملخص المحضر *',
      initial: meeting['minutes_summary']?.toString() ?? '',
    );
    if (summary == null || summary.isEmpty) return;
    final decisions = await _textDialog(
      'قرارات الاجتماع',
      'القرارات - اختياري',
      initial: meeting['minutes_decisions']?.toString() ?? '',
    );
    await _run(() => ApiService.saveProjectMeetingMinutesAdvanced(
          projectId: widget.projectId,
          meetingId: widget.meetingId,
          summary: summary,
          decisions: decisions,
        ));
  }

  Future<void> _cancel() async {
    final reason = await _textDialog('إلغاء الاجتماع', 'سبب الإلغاء *');
    if (reason == null || reason.isEmpty) return;
    await _run(() => ApiService.cancelProjectMeetingAdvanced(
          widget.projectId,
          widget.meetingId,
          reason,
        ));
  }

  Future<void> _addAction() async {
    final title = TextEditingController();
    var priority = 'normal';
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => Directionality(
          textDirection: AppLanguage.instance.textDirection,
          child: AlertDialog(
            title: const TrText('Action Item جديد'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: InputDecoration(labelText: 'العنوان *'.tr()),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: InputDecoration(labelText: 'الأولوية'.tr()),
                  items: const [
                    DropdownMenuItem(value: 'low', child: TrText('منخفضة')),
                    DropdownMenuItem(value: 'normal', child: TrText('عادية')),
                    DropdownMenuItem(value: 'high', child: TrText('عالية')),
                    DropdownMenuItem(value: 'urgent', child: TrText('عاجلة')),
                  ],
                  onChanged: (value) => setLocal(() => priority = value ?? priority),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const TrText('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const TrText('إضافة'),
              ),
            ],
          ),
        ),
      ),
    );
    final value = title.text.trim();
    Future<void>.delayed(const Duration(milliseconds: 600), title.dispose);
    if (ok != true || value.isEmpty) return;
    await _run(() => ApiService.addMeetingActionAdvanced(
          projectId: widget.projectId,
          meetingId: widget.meetingId,
          title: value,
          priority: priority,
        ));
  }

  Future<void> _updateAction(int id, String status) =>
      _run(() => ApiService.updateMeetingActionAdvanced(
            projectId: widget.projectId,
            meetingId: widget.meetingId,
            actionId: id,
            status: status,
          ));

  Future<void> _run(Future<String> Function() fn) async {
    try {
      final message = await fn();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
      }
    }
  }

  Future<void> _startOrJoinLive() async {
    if (_liveBusy) return;
    setState(() => _liveBusy = true);
    try {
      var meeting = _meeting;
      var status = meeting['live_status']?.toString() ?? 'idle';
      final canStart = _data?['can_start_live'] == true;

      if (status != 'live') {
        if (!canStart) {
          throw ApiException('الاجتماع المباشر لم يبدأ بعد. انتظر مدير الاجتماع.'.tr());
        }
        final startResult = await ApiService.startProjectMeetingLive(widget.projectId, widget.meetingId);
        AppFeedback.success(startResult['message']?.toString() ?? 'تم بدء الاجتماع المباشر بنجاح.'.tr());
        await _load();
        meeting = _meeting;
        status = meeting['live_status']?.toString() ?? 'idle';
      }

      if (status != 'live' || _data?['can_join_live'] != true) {
        throw ApiException('لا يمكن الدخول إلى الاجتماع المباشر حاليًا.'.tr());
      }

      if (!mounted) return;
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ProjectLiveMeetingScreen(
            projectId: widget.projectId,
            meetingId: widget.meetingId,
            meetingTitle: meeting['title']?.toString() ?? 'اجتماع مباشر'.tr(),
            canModerate: _data?['can_moderate_live'] == true,
          ),
        ),
      );
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
      }
    } finally {
      if (mounted) setState(() => _liveBusy = false);
    }
  }

  Future<void> _inviteLiveUser() async {
    try {
      final users = await ApiService.fetchProjectMeetingLiveInvitees(
        widget.projectId,
        widget.meetingId,
      );
      if (!mounted) return;
      if (users.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: TrText('لا يوجد مستخدمون متاحون للدعوة.')),
        );
        return;
      }

      final selected = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => Directionality(
          textDirection: AppLanguage.instance.textDirection,
          child: SafeArea(
            child: SizedBox(
              height: MediaQuery.of(sheetContext).size.height * .65,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: TrText('دعوة مستخدم للاجتماع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (_, index) {
                        final user = Map<String, dynamic>.from(users[index] as Map);
                        return ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person_outline_rounded)),
                          title: Text(user['name']?.toString() ?? 'مستخدم'.tr()),
                          subtitle: Text('${user['role'] ?? ''}${(user['email']?.toString() ?? '').isNotEmpty ? ' • ${user['email']}' : ''}'),
                          onTap: () => Navigator.pop(sheetContext, user),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      if (selected == null) return;
      final userId = int.tryParse(selected['id']?.toString() ?? '') ?? 0;
      if (userId <= 0) return;
      final message = await ApiService.inviteProjectMeetingLiveUser(
        projectId: widget.projectId,
        meetingId: widget.meetingId,
        userId: userId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
      }
    }
  }

  Future<void> _downloadAttachment(Map<String, dynamic> attachment) async {
    final id = int.tryParse(attachment['id']?.toString() ?? '') ?? 0;
    final name = attachment['original_name']?.toString() ?? 'meeting-file';
    try {
      final file = await ApiService.downloadAttachment(
        urlPath: 'projects/${widget.projectId}/meetings/${widget.meetingId}/attachments/$id/download',
        fileName: name,
      );
      await OpenFilex.open(file.path);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
      }
    }
  }

  Future<void> _downloadMinutesPdf() async {
    try {
      final file = await ApiService.downloadAttachment(
        urlPath: 'projects/${widget.projectId}/meetings/${widget.meetingId}/minutes/pdf',
        fileName: 'meeting-${widget.meetingId}-minutes.pdf',
      );
      await OpenFilex.open(file.path);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: Scaffold(
          appBar: AppBar(title: const TrText('تفاصيل الاجتماع')),
          body: _body(),
        ),
      );

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: FilledButton(onPressed: _load, child: Text(trUi(_error!))),
      );
    }

    final meeting = _meeting;
    final actions = List<dynamic>.from(meeting['action_items'] as List? ?? const []);
    final attachments = List<dynamic>.from(meeting['attachments'] as List? ?? const []);
    final agenda = List<dynamic>.from(meeting['agenda_items'] as List? ?? const []);
    final liveStatus = meeting['live_status']?.toString() ?? 'idle';
    final canStart = _data?['can_start_live'] == true;
    final canJoin = _data?['can_join_live'] == true;
    final canInvite = _data?['can_invite_live'] == true;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _box(meeting['title']?.toString() ?? 'اجتماع'.tr(), [
            'الحالة: ${meeting['status'] ?? '-'}',
            'النوع: ${meeting['type'] ?? '-'}',
            'الموعد: ${meeting['scheduled_at'] ?? '-'}',
            'Live: ${_liveLabel(liveStatus)}',
            if (meeting['location'] != null) 'المكان: ${meeting['location']}',
            if (meeting['meeting_link'] != null) 'الرابط: ${meeting['meeting_link']}',
            if (meeting['description'] != null) '${meeting['description']}',
          ]),
          const SizedBox(height: 12),
          _liveCard(liveStatus, canStart: canStart, canJoin: canJoin, canInvite: canInvite),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_data?['can_manage'] == true)
                FilledButton.icon(
                  onPressed: _minutes,
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const TrText('حفظ المحضر'),
                ),
              if (_data?['can_publish_minutes'] == true)
                OutlinedButton.icon(
                  onPressed: () => _run(() => ApiService.publishProjectMeetingMinutesAdvanced(widget.projectId, widget.meetingId)),
                  icon: const Icon(Icons.publish_rounded),
                  label: const TrText('نشر المحضر'),
                ),
              OutlinedButton.icon(
                onPressed: _downloadMinutesPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('PDF'),
              ),
              if (_data?['can_manage'] == true)
                OutlinedButton.icon(
                  onPressed: _addAction,
                  icon: const Icon(Icons.playlist_add_rounded),
                  label: const TrText('إجراء'),
                ),
              if (_data?['can_manage'] == true)
                OutlinedButton(onPressed: _cancel, child: const TrText('إلغاء الاجتماع')),
            ],
          ),
          if (meeting['minutes_summary'] != null) ...[
            const SizedBox(height: 16),
            _box('محضر الاجتماع', [
              meeting['minutes_summary'].toString(),
              if (meeting['minutes_decisions'] != null) 'القرارات: ${meeting['minutes_decisions']}',
            ]),
          ],
          if (agenda.isNotEmpty) ...[
            const SizedBox(height: 18),
            const TrText('جدول الأعمال', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            ...agenda.map((raw) {
              final item = Map<String, dynamic>.from(raw as Map);
              return Card(
                child: ListTile(
                  title: Text(trUi(item['title']?.toString() ?? '-')),
                  subtitle: Text('${item['status'] ?? ''}${item['notes'] != null ? '\n${item['notes']}' : ''}'),
                ),
              );
            }),
          ],
          const SizedBox(height: 18),
          const Text('Action Items', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (actions.isEmpty)
            TrText('لا يوجد إجراءات.', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant)))
          else
            ...actions.map((raw) {
              final item = Map<String, dynamic>.from(raw as Map);
              final id = int.tryParse(item['id']?.toString() ?? '') ?? 0;
              return Card(
                child: ListTile(
                  title: Text(trUi(item['title']?.toString() ?? '-')),
                  subtitle: Text('${item['priority'] ?? '-'} • ${item['status'] ?? '-'}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) => _updateAction(id, value),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'open', child: TrText('مفتوح')),
                      PopupMenuItem(value: 'in_progress', child: TrText('قيد التنفيذ')),
                      PopupMenuItem(value: 'completed', child: TrText('مكتمل')),
                      PopupMenuItem(value: 'cancelled', child: TrText('ملغي')),
                    ],
                  ),
                ),
              );
            }),
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 18),
            const TrText('المرفقات', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            ...attachments.map((raw) {
              final attachment = Map<String, dynamic>.from(raw as Map);
              return Card(
                child: ListTile(
                  title: Text(attachment['original_name']?.toString() ?? 'ملف'.tr()),
                  leading: const Icon(Icons.attach_file_rounded),
                  trailing: IconButton(
                    onPressed: () => _downloadAttachment(attachment),
                    icon: const Icon(Icons.download_rounded),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _liveCard(
    String status, {
    required bool canStart,
    required bool canJoin,
    required bool canInvite,
  }) {
    final isLive = status == 'live';
    final ended = status == 'ended';
    final buttonEnabled = !ended && (isLive ? canJoin : canStart);
    final label = isLive
        ? 'انضمام للاجتماع المباشر'
        : canStart
            ? 'بدء الاجتماع المباشر'
            : 'بانتظار بدء الاجتماع';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF0D1B31) : Theme.of(context).colorScheme.surface),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? Color(0x1AFFFFFF) : Theme.of(context).dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isLive ? Icons.videocam_rounded : Icons.video_call_outlined),
              const SizedBox(width: 8),
              TrText('الاجتماع المباشر • ${_liveLabel(status)}', style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: buttonEnabled && !_liveBusy ? _startOrJoinLive : null,
                icon: _liveBusy
                    ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(isLive ? Icons.login_rounded : Icons.play_arrow_rounded),
                label: Text(trUi(label)),
              ),
              if (canInvite && !ended)
                OutlinedButton.icon(
                  onPressed: _inviteLiveUser,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const TrText('دعوة مشارك'),
                ),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const TrText('تحديث الحالة'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _liveLabel(String status) {
    switch (status) {
      case 'live':
        return 'مباشر الآن';
      case 'ended':
        return 'انتهى';
      default:
        return 'لم يبدأ';
    }
  }

  Widget _box(String title, List<String> lines) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF0D1B31) : AppColors.surface),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? Color(0x1AFFFFFF) : AppColors.borderSoft)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(trUi(title), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            const SizedBox(height: 8),
            ...lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(trUi(line), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : AppColors.textSecondary), height: 1.5)),
              ),
            ),
          ],
        ),
      );
}
