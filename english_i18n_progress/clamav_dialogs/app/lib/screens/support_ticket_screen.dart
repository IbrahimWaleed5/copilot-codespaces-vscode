import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../i18n/localized_text.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../utils/app_file_picker.dart';

class SupportTicketScreen extends StatefulWidget {
  final int ticketId;

  const SupportTicketScreen({super.key, required this.ticketId});

  @override
  State<SupportTicketScreen> createState() => _SupportTicketScreenState();
}

class _SupportTicketScreenState extends State<SupportTicketScreen> {
  final _message = TextEditingController();
  final _emailSubject = TextEditingController();
  bool _internal = false;
  bool _detailsOpen = true;
  int? _templateId;
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  File? _attachment;
  bool _lockOwned = false;
  String? _lockOwner;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    if(_lockOwned){ApiService.releaseSupportTicketLock(widget.ticketId);}
    _message.dispose();
    _emailSubject.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.fetchSupportTicket(widget.ticketId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
        _error = null;
      });
      final perms=(data['permissions'] as List? ?? const []).map((e)=>e.toString()).toSet();
      if(perms.contains('support.tickets.reply')){try{final lock=await ApiService.acquireSupportTicketLock(widget.ticketId);if(mounted)setState((){_lockOwned=lock['owned']==true;_lockOwner=lock['by']?.toString();});}catch(_){}}
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty && _attachment == null) return;
    setState(() => _sending = true);
    try {
      await ApiService.sendSupportMessage(
        ticketId: widget.ticketId,
        message: text,
        attachment: _attachment,
        isInternal: _internal,
        emailSubject: _emailSubject.text.trim(),
        templateId: _templateId,
      );
      _message.clear();
      _emailSubject.clear();
      _templateId = null;
      _internal = false;
      _attachment = null;
      await _load();
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pick() async {
    final result = await AppFilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'doc', 'docx', 'zip'],
    );
    if (result?.path != null && mounted) setState(() => _attachment = File(result!.path!));
  }

  Future<void> _openAttachment(Map<String, dynamic> item) async {
    final path = item['attachment_api_path']?.toString();
    if (path == null) return;
    final file = await ApiService.downloadAttachment(
      urlPath: path,
      fileName: item['attachment_name']?.toString() ?? 'attachment',
    );
    await OpenFilex.open(file.path);
  }

  Future<void> _changeStatus(String status) async {
    try {
      final message = await ApiService.updateSupportStatus(widget.ticketId, status);
      AppFeedback.success(message);
      await _load();
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
    }
  }

  Future<void> _escalate() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: AlertDialog(
          title: const TrText('تحويل إلى المدير'),
          content: TextField(controller: controller, maxLines: 4, decoration: InputDecoration(labelText: 'سبب التحويل'.tr())),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const TrText('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const TrText('تحويل')),
          ],
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 600), controller.dispose);
    if (reason == null || reason.isEmpty) return;
    try {
      final message = await ApiService.escalateSupportTicket(widget.ticketId, reason);
      AppFeedback.success(message);
      await _load();
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
    }
  }

  Set<String> get _ticketPermissions {
    return (_data?['permissions'] as List? ?? const [])
        .map((item) => item.toString())
        .toSet();
  }

  bool _canTicket(String permission) {
    final role = context.read<AuthProvider>().user?.role ?? '';
    return role == 'admin' || _ticketPermissions.contains(permission);
  }

  Future<String?> _askReason(
    String title, {
    int minLength = 5,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: AlertDialog(
          title: Text(trUi(title)),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: InputDecoration(labelText: 'السبب'.tr()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const TrText('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                controller.text.trim(),
              ),
              child: const TrText('تأكيد'),
            ),
          ],
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 600), controller.dispose);
    if ((result ?? '').trim().length < minLength) return null;
    return result!.trim();
  }

  Future<void> _reopenTicket() async {
    final reason = await _askReason('إعادة فتح التذكرة');
    if (reason == null) return;
    try {
      final message = await ApiService.reopenSupportTicket(
        widget.ticketId,
        reason: reason,
      );
      AppFeedback.success(message);
      await _load();
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
    }
  }

  Future<void> _changePriorityAdvanced() async {
    String priority = 'medium';
    final reasonController = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Directionality(
          textDirection: AppLanguage.instance.textDirection,
          child: AlertDialog(
            title: const TrText('تغيير أولوية التذكرة'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  items: const [
                    DropdownMenuItem(value: 'low', child: TrText('منخفضة')),
                    DropdownMenuItem(value: 'medium', child: TrText('متوسطة')),
                    DropdownMenuItem(value: 'high', child: TrText('مرتفعة')),
                    DropdownMenuItem(value: 'urgent', child: TrText('عاجلة جدًا')),
                  ],
                  onChanged: (value) => setDialogState(
                    () => priority = value ?? priority,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: InputDecoration(labelText: 'سبب التغيير'.tr()),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const TrText('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(
                  dialogContext,
                  {
                    'priority': priority,
                    'reason': reasonController.text.trim(),
                  },
                ),
                child: const TrText('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 600), reasonController.dispose);
    if (result == null || (result['reason'] ?? '').length < 5) return;
    try {
      final message = await ApiService.changeSupportTicketPriority(
        widget.ticketId,
        priority: result['priority']!,
        reason: result['reason']!,
      );
      AppFeedback.success(message);
      await _load();
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
    }
  }

  Future<void> _assignToMe() async {
    try {
      final message = await ApiService.assignSupportTicket(widget.ticketId);
      AppFeedback.success(message);
      await _load();
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
    }
  }

  Future<void> _escalateAdvanced() async {
    String target = 'technical';
    final reasonController = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Directionality(
          textDirection: AppLanguage.instance.textDirection,
          child: AlertDialog(
            title: const TrText('تصعيد التذكرة'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: target,
                  items: const [
                    DropdownMenuItem(value: 'technical', child: TrText('تقني')),
                    DropdownMenuItem(value: 'financial', child: TrText('مالي')),
                    DropdownMenuItem(value: 'manager', child: TrText('مدير')),
                    DropdownMenuItem(value: 'kyc', child: TrText('KYC / أمان')),
                  ],
                  onChanged: (value) => setDialogState(
                    () => target = value ?? target,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reasonController,
                  maxLines: 4,
                  decoration: InputDecoration(labelText: 'سبب التصعيد'.tr()),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const TrText('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(
                  dialogContext,
                  {
                    'target': target,
                    'reason': reasonController.text.trim(),
                  },
                ),
                child: const TrText('تصعيد'),
              ),
            ],
          ),
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 600), reasonController.dispose);
    if (result == null || (result['reason'] ?? '').length < 10) return;
    try {
      final message = await ApiService.escalateSupportTicketTarget(
        widget.ticketId,
        target: result['target']!,
        reason: result['reason']!,
      );
      AppFeedback.success(message);
      await _load();
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
    }
  }

  Future<void> _showTicketManagement() async {
    final ticket = Map<String, dynamic>.from(
      _data?['ticket'] as Map? ?? const <String, dynamic>{},
    );
    final closed = ticket['status'] == 'closed' || ticket['status'] == 'resolved';

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF111936) : Theme.of(context).colorScheme.surface),
      showDragHandle: true,
      builder: (sheetContext) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  title: TrText('إدارة التذكرة',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: TrText('الإجراءات تظهر حسب صلاحيات موظف الدعم.'),
                ),
                if (_canTicket('support.tickets.assign'))
                  ListTile(
                    leading: const Icon(Icons.person_add_alt_1_outlined),
                    title: const TrText('استلام / تعيين التذكرة لي'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _assignToMe();
                    },
                  ),
                if (_canTicket('support.tickets.change_priority'))
                  ListTile(
                    leading: const Icon(Icons.priority_high_rounded),
                    title: const TrText('تغيير الأولوية'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _changePriorityAdvanced();
                    },
                  ),
                if (_canTicket('support.tickets.escalate'))
                  ListTile(
                    leading: const Icon(Icons.alt_route_rounded),
                    title: const TrText('تصعيد: مالي / تقني / مدير / KYC'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _escalateAdvanced();
                    },
                  ),
                if (closed && _canTicket('support.tickets.reopen'))
                  ListTile(
                    leading: const Icon(Icons.replay_circle_filled_outlined),
                    title: const TrText('إعادة فتح التذكرة'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _reopenTicket();
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _statusLabel(String value) => switch (value) {
        'open' => 'مفتوحة'.tr(),
        'in_progress' => 'قيد المعالجة'.tr(),
        'waiting_customer' || 'pending_customer' => 'بانتظار العميل'.tr(),
        'resolved' => 'محلولة'.tr(),
        'closed' => 'مغلقة'.tr(),
        _ => value,
      };

  @override
  Widget build(BuildContext context) {
    final ticket = Map<String, dynamic>.from(_data?['ticket'] as Map? ?? const <String, dynamic>{});
    final messages = List<Map<String, dynamic>>.from(
      (_data?['messages'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
    );
    final templates = List<Map<String, dynamic>>.from(
      (_data?['templates'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
    );
    final role = context.watch<AuthProvider>().user?.role ?? '';
    final isStaff = role == 'admin' || role == 'employee';
    final closed = ticket['status'] == 'closed' || ticket['status'] == 'resolved';
    final user = Map<String, dynamic>.from(ticket['user'] as Map? ?? const {});
    final assigned = Map<String, dynamic>.from(ticket['assigned_employee'] as Map? ?? const {});

    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        backgroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF070B19) : Theme.of(context).scaffoldBackgroundColor),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
              : _error != null
                  ? _ErrorView(message: _error!, onRetry: _load)
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final desktop = constraints.maxWidth >= 900;
                        if (desktop) {
                          return _DesktopTicketLayout(
                            ticket: ticket,
                            messages: messages,
                            templates: templates,
                            user: user,
                            assigned: assigned,
                            isStaff: isStaff,
                            closed: closed,
                            internal: _internal,
                            templateId: _templateId,
                            emailSubject: _emailSubject,
                            messageController: _message,
                            attachment: _attachment,
                            sending: _sending,
                            onInternalChanged: (v) => setState(() => _internal = v),
                            onTemplateChanged: (value) => _applyTemplate(value, templates),
                            onPick: _pick,
                            onSend: _send,
                            onAttachmentOpen: _openAttachment,
                            onStatusChange: _changeStatus,
                            onEscalate: role == 'employee' && ticket['is_escalated'] != true ? _escalate : null,
                            onManage: isStaff ? _showTicketManagement : null,
                            statusLabel: _statusLabel,
                          );
                        }
                        return _buildMobileTicket(
                          ticket: ticket,
                          messages: messages,
                          templates: templates,
                          user: user,
                          assigned: assigned,
                          isStaff: isStaff,
                          closed: closed,
                        );
                      },
                    ),
        ),
      ),
    );
  }

  void _applyTemplate(int? value, List<Map<String, dynamic>> templates) {
    setState(() => _templateId = value);
    final chosen = templates.where((t) => int.tryParse('${t['id']}') == value).toList();
    if (chosen.isNotEmpty) {
      _message.text = chosen.first['body']?.toString() ?? '';
      _emailSubject.text = chosen.first['email_subject']?.toString() ?? '';
    }
  }

  Widget _buildMobileTicket({
    required Map<String, dynamic> ticket,
    required List<Map<String, dynamic>> messages,
    required List<Map<String, dynamic>> templates,
    required Map<String, dynamic> user,
    required Map<String, dynamic> assigned,
    required bool isStaff,
    required bool closed,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 10),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xEA070B19)
                : Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0x223B82F6)
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: Column(
            children: [
              Row(children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFCBD5E1)
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    side: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0x33475569)
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                  label: const TrText('العودة', style: TextStyle(fontSize: 10)),
                ),
                const Spacer(),
                _TicketBadge(text: _statusLabel(ticket['status']?.toString() ?? ''), color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFBBF24) : const Color(0xFF92400E))),
                const SizedBox(width: 6),
                _TicketBadge(text: ticket['priority']?.toString().toUpperCase() ?? '', color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFB7185) : const Color(0xFFBE123C))),
              ]),
              const SizedBox(height: 9),
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    TrText('رقم التذكرة المرجعي', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF64748B) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 8)),
                    const SizedBox(height: 2),
                    Text(trUi(ticket['ticket_number']?.toString() ?? ''), textDirection: TextDirection.ltr, style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF60A5FA) : Color(0xFF1D4ED8)), fontSize: 10, fontWeight: FontWeight.w900)),
                  ]),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _detailsOpen = !_detailsOpen),
                  icon: Icon(_detailsOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 16),
                  label: const TrText('البيانات', style: TextStyle(fontSize: 9)),
                ),
              ]),
            ],
          ),
        ),
        if (_detailsOpen)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xB30C1228)
                : const Color(0xFFF8FAFC),
            child: _CustomerDetailsCard(user: user, assigned: assigned, ticket: ticket, compact: true),
          ),
        if (isStaff && (_canTicket('support.tickets.assign') || _canTicket('support.tickets.change_priority') || _canTicket('support.tickets.escalate') || _canTicket('support.tickets.reopen')))
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 7, 14, 2),
            child: OutlinedButton.icon(
              onPressed: _showTicketManagement,
              icon: const Icon(Icons.tune_rounded),
              label: const TrText('إدارة التذكرة'),
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
            itemCount: messages.length,
            itemBuilder: (context, index) => _TicketMessageBubble(item: messages[index], onAttachmentOpen: _openAttachment),
          ),
        ),
        if (isStaff && !closed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            child: Row(children: [
              Expanded(child: _MiniActionButton(label: 'تحديد كمحلولة'.tr(), color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF34D399) : const Color(0xFF047857)), onTap: () => _changeStatus('resolved'))),
              const SizedBox(width: 8),
              Expanded(child: _MiniActionButton(label: 'إغلاق التذكرة'.tr(), color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFB7185) : const Color(0xFFBE123C)), onTap: () => _changeStatus('closed'))),
            ]),
          ),
        if (!closed)
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xF2070B19)
                  : Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0x223B82F6)
                      : Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            child: _ReplyComposer(
              isStaff: isStaff,
              templates: templates,
              templateId: _templateId,
              emailSubject: _emailSubject,
              messageController: _message,
              internal: _internal,
              attachment: _attachment,
              sending: _sending,
              onInternalChanged: (v) => setState(() => _internal = v),
              onTemplateChanged: (value) => _applyTemplate(value, templates),
              onPick: _pick,
              onClearAttachment: () => setState(() => _attachment = null),
              onSend: _send,
            ),
          ),
      ],
    );
  }
}

class _DesktopTicketLayout extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final List<Map<String, dynamic>> messages;
  final List<Map<String, dynamic>> templates;
  final Map<String, dynamic> user;
  final Map<String, dynamic> assigned;
  final bool isStaff;
  final bool closed;
  final bool internal;
  final int? templateId;
  final TextEditingController emailSubject;
  final TextEditingController messageController;
  final File? attachment;
  final bool sending;
  final ValueChanged<bool> onInternalChanged;
  final ValueChanged<int?> onTemplateChanged;
  final VoidCallback onPick;
  final VoidCallback onSend;
  final Future<void> Function(Map<String, dynamic>) onAttachmentOpen;
  final Future<void> Function(String) onStatusChange;
  final VoidCallback? onEscalate;
  final VoidCallback? onManage;
  final String Function(String) statusLabel;

  const _DesktopTicketLayout({
    required this.ticket,
    required this.messages,
    required this.templates,
    required this.user,
    required this.assigned,
    required this.isStaff,
    required this.closed,
    required this.internal,
    required this.templateId,
    required this.emailSubject,
    required this.messageController,
    required this.attachment,
    required this.sending,
    required this.onInternalChanged,
    required this.onTemplateChanged,
    required this.onPick,
    required this.onSend,
    required this.onAttachmentOpen,
    required this.onStatusChange,
    required this.onEscalate,
    required this.onManage,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(22),
        child: Column(children: [
          Row(children: [
            OutlinedButton.icon(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_forward_rounded), label: const TrText('العودة للتذاكر')),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(trUi(ticket['ticket_number']?.toString() ?? ''), textDirection: TextDirection.ltr, style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF0F172A)), fontSize: 17, fontWeight: FontWeight.w900)),
              Text(trUi(ticket['subject']?.toString() ?? ''), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF94A3B8) : Color(0xFF475569)), fontSize: 10)),
            ]),
          ]),
          const SizedBox(height: 18),
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: Container(
                  decoration: _panelDecoration(context),
                  child: Column(children: [
                    Expanded(child: ListView.builder(padding: const EdgeInsets.all(18), itemCount: messages.length, itemBuilder: (context, index) => _TicketMessageBubble(item: messages[index], onAttachmentOpen: onAttachmentOpen))),
                    if (!closed)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: _ReplyComposer(
                          isStaff: isStaff,
                          templates: templates,
                          templateId: templateId,
                          emailSubject: emailSubject,
                          messageController: messageController,
                          internal: internal,
                          attachment: attachment,
                          sending: sending,
                          onInternalChanged: onInternalChanged,
                          onTemplateChanged: onTemplateChanged,
                          onPick: onPick,
                          onClearAttachment: () {},
                          onSend: onSend,
                        ),
                      ),
                  ]),
                ),
              ),
              const SizedBox(width: 20),
              SizedBox(
                width: 310,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: _panelDecoration(context),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    TrText('بيانات التذكرة', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF0F172A)), fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 16),
                    _CustomerDetailsCard(user: user, assigned: assigned, ticket: ticket, compact: false),
                    const Spacer(),
                    if (isStaff && !closed) ...[
                      _MiniActionButton(label: 'تحديد كمحلولة'.tr(), color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF34D399) : const Color(0xFF047857)), onTap: () => onStatusChange('resolved')),
                      const SizedBox(height: 8),
                      _MiniActionButton(label: 'إغلاق التذكرة'.tr(), color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFB7185) : const Color(0xFFBE123C)), onTap: () => onStatusChange('closed')),
                      if (onEscalate != null) ...[const SizedBox(height: 8), _MiniActionButton(label: 'تحويل للمدير'.tr(), color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8)), onTap: onEscalate!)],
                      if (onManage != null) ...[const SizedBox(height: 8), _MiniActionButton(label: 'إدارة متقدمة'.tr(), color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFA78BFA) : const Color(0xFF6D28D9)), onTap: onManage!)],
                    ],
                  ]),
                ),
              ),
            ]),
          ),
        ]),
      );
}

class _CustomerDetailsCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final Map<String, dynamic> assigned;
  final Map<String, dynamic> ticket;
  final bool compact;
  const _CustomerDetailsCard({required this.user, required this.assigned, required this.ticket, required this.compact});
  @override
  Widget build(BuildContext context) {
    final rows = [
      ('العميل', user['name']?.toString() ?? '—'),
      ('البريد', user['email']?.toString() ?? '—'),
      ('الحالة', ticket['status']?.toString() ?? '—'),
      ('الأولوية', ticket['priority']?.toString() ?? '—'),
      ('الموظف', assigned['name']?.toString() ?? 'لم يتم التعيين'.tr()),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Container(width: 32, height: 32, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF4F46E5)])), alignment: Alignment.center, child: Text(trUi((user['name']?.toString() ?? 'U').characters.first.toUpperCase()), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(user['name']?.toString() ?? 'العميل'.tr(), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface), fontSize: 11, fontWeight: FontWeight.w900)), Text(trUi(user['email']?.toString() ?? ''), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 8))])),
      ]),
      SizedBox(height: compact ? 9 : 14),
      if (compact)
        Wrap(spacing: 7, runSpacing: 7, children: rows.map((r) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7), decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0x66070B19)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0x143B82F6)
                : Theme.of(context).colorScheme.outlineVariant,
          ),
        ), child: Text('${r.$1}: ${r.$2}', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFCBD5E1) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 8.5)))).toList())
      else
        ...rows.map((r) => Padding(padding: const EdgeInsets.only(bottom: 11), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(trUi(r.$1), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF64748B) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 8)), const SizedBox(height: 2), Text(trUi(r.$2), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFE2E8F0) : Theme.of(context).colorScheme.onSurface), fontSize: 10, fontWeight: FontWeight.w800))]))),
    ]);
  }
}

class _TicketMessageBubble extends StatelessWidget {
  final Map<String, dynamic> item;
  final Future<void> Function(Map<String, dynamic>) onAttachmentOpen;
  const _TicketMessageBubble({required this.item, required this.onAttachmentOpen});
  @override
  Widget build(BuildContext context) {
    final internal = item['is_internal'] == true;
    final customer = item['sender_type']?.toString() == 'customer';
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = internal
        ? (dark ? const Color(0x331A1300) : const Color(0xFFFFF7ED))
        : customer
            ? const Color(0xFF2F67E9)
            : (dark ? const Color(0xFF111936) : Theme.of(context).colorScheme.surface);
    return Align(
      alignment: customer ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15),
            topRight: const Radius.circular(15),
            bottomLeft: Radius.circular(customer ? 15 : 5),
            bottomRight: Radius.circular(customer ? 5 : 15),
          ),
          border: Border.all(
            color: internal
                ? (dark ? const Color(0x55F59E0B) : const Color(0x66D97706))
                : (dark ? const Color(0x153B82F6) : Theme.of(context).colorScheme.outlineVariant),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            trUi(internal
                ? 'ملاحظة داخلية • ${item['sender_name'] ?? 'الدعم'.tr()}'
                : (item['sender_name']?.toString() ?? item['sender_type']?.toString() ?? '')),
            style: TextStyle(
              color: internal
                  ? (dark ? const Color(0xFFFCD34D) : const Color(0xFF92400E))
                  : customer
                      ? const Color(0xFFDBEAFE)
                      : (dark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)),
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
          if ((item['message']?.toString() ?? '').isNotEmpty) ...[const SizedBox(height: 5), Text(
              trUi(item['message'].toString()),
              style: TextStyle(
                color: customer ? Colors.white : Theme.of(context).colorScheme.onSurface,
                fontSize: 11,
                height: 1.65,
              ),
            )],
          if (item['attachment_api_path'] != null) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => onAttachmentOpen(item),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.attach_file_rounded,
                    size: 15,
                    color: customer
                        ? const Color(0xFFDBEAFE)
                        : (dark ? const Color(0xFF7DD3FC) : const Color(0xFF1D4ED8)),
                  ),
                  Text(
                    item['attachment_name']?.toString() ?? 'مرفق'.tr(),
                    style: TextStyle(
                      color: customer
                          ? const Color(0xFFDBEAFE)
                          : (dark ? const Color(0xFF7DD3FC) : const Color(0xFF1D4ED8)),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (item['created_at'] != null) ...[const SizedBox(height: 5), Text(trUi(_time(item['created_at']?.toString())), textDirection: TextDirection.ltr, style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 7.5))],
        ]),
      ),
    );
  }

  static String _time(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _ReplyComposer extends StatelessWidget {
  final bool isStaff;
  final List<Map<String, dynamic>> templates;
  final int? templateId;
  final TextEditingController emailSubject;
  final TextEditingController messageController;
  final bool internal;
  final File? attachment;
  final bool sending;
  final ValueChanged<bool> onInternalChanged;
  final ValueChanged<int?> onTemplateChanged;
  final VoidCallback onPick;
  final VoidCallback onClearAttachment;
  final VoidCallback onSend;

  const _ReplyComposer({required this.isStaff, required this.templates, required this.templateId, required this.emailSubject, required this.messageController, required this.internal, required this.attachment, required this.sending, required this.onInternalChanged, required this.onTemplateChanged, required this.onPick, required this.onClearAttachment, required this.onSend});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF0C1228)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0x223B82F6)
                : Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Column(children: [
          if (isStaff) ...[
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: templates.any((t) => int.tryParse('${t['id']}') == templateId) ? templateId : null,
                  decoration: InputDecoration(labelText: 'قالب جاهز'.tr(), isDense: true),
                  items: [const DropdownMenuItem<int>(value: null, child: TrText('بدون قالب — اكتب بحرية')), ...templates.map((t) => DropdownMenuItem<int>(value: int.tryParse('${t['id']}'), child: Text(trUi(t['title']?.toString() ?? ''), overflow: TextOverflow.ellipsis)))],
                  onChanged: onTemplateChanged,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: emailSubject, decoration: InputDecoration(labelText: 'عنوان الإيميل'.tr(), isDense: true))),
            ]),
            const SizedBox(height: 8),
          ],
          TextField(controller: messageController, minLines: 2, maxLines: 5, style: const TextStyle(fontSize: 11), decoration: InputDecoration(hintText: trUi(isStaff ? 'اكتب أي رسالة تريد إرسالها للعميل...' : 'اكتب رسالتك...'))),
          if (isStaff) ...[
            const SizedBox(height: 7),
            InkWell(
              onTap: () => onInternalChanged(!internal),
              borderRadius: BorderRadius.circular(9),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: internal
                      ? (Theme.of(context).brightness == Brightness.dark
                          ? const Color(0x221F1600)
                          : const Color(0xFFFFF7ED))
                      : (Theme.of(context).brightness == Brightness.dark
                          ? const Color(0x66070B19)
                          : const Color(0xFFF8FAFC)),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: internal
                        ? (Theme.of(context).brightness == Brightness.dark
                            ? const Color(0x44F59E0B)
                            : const Color(0x66D97706))
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Row(children: [
                  Checkbox(
                    value: internal,
                    onChanged: (v) => onInternalChanged(v ?? false),
                    visualDensity: VisualDensity.compact,
                  ),
                  Expanded(
                    child: TrText(
                      'ملاحظة داخلية لا تظهر للعميل ولا ترسل بالإيميل',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFFCD34D)
                            : const Color(0xFF92400E),
                        fontSize: 8.5,
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ],
          const SizedBox(height: 7),
          Row(children: [
            OutlinedButton.icon(onPressed: sending ? null : onPick, icon: const Icon(Icons.attach_file_rounded, size: 15), label: const TrText('اختيار ملف', style: TextStyle(fontSize: 9))),
            if (attachment != null) ...[
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  trUi(attachment!.path.split(Platform.pathSeparator).last),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF7DD3FC)
                        : const Color(0xFF1D4ED8),
                    fontSize: 8.5,
                  ),
                ),
              ),
              IconButton(onPressed: onClearAttachment, icon: const Icon(Icons.close_rounded, size: 16)),
            ] else
              const Spacer(),
            const SizedBox(width: 6),
            FilledButton.icon(onPressed: sending ? null : onSend, icon: sending ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded, size: 15), label: Text(trUi(sending ? 'جاري الإرسال...' : 'إرسال'), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900))),
          ]),
        ]),
      );
}

class _TicketBadge extends StatelessWidget {
  final String text;
  final Color color;
  const _TicketBadge({required this.text, required this.color});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withValues(alpha: .08), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withValues(alpha: .24))), child: Text(trUi(text), style: TextStyle(color: color, fontSize: 8.5, fontWeight: FontWeight.w900)));
}

class _MiniActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MiniActionButton({required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10), child: Container(height: 36, alignment: Alignment.center, decoration: BoxDecoration(color: color.withValues(alpha: .08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: .22))), child: Text(trUi(label), style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w900))));
}

class _ErrorView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(22), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.support_agent_rounded, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF60A5FA) : Color(0xFF1D4ED8)), size: 40), const SizedBox(height: 10), Text(trUi(message), textAlign: TextAlign.center, style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFCBD5E1) : Color(0xFF475569)))), const SizedBox(height: 12), FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const TrText('إعادة المحاولة'))])));
}

BoxDecoration _panelDecoration(BuildContext context) => BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0C1228)
          : Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0x223B82F6)
            : Theme.of(context).colorScheme.outlineVariant,
      ),
      boxShadow: [
        BoxShadow(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0x22000000)
              : const Color(0x120F2747),
          blurRadius: 26,
          offset: const Offset(0, 14),
        ),
      ],
    );
