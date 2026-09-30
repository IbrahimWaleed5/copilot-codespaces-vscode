import 'package:flutter/material.dart';

import '../i18n/localized_text.dart';
import '../i18n/i18n.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'crm_lead_form_screen.dart';

class CrmLeadDetailScreen extends StatefulWidget {
  const CrmLeadDetailScreen({super.key, required this.leadId});

  final int leadId;

  @override
  State<CrmLeadDetailScreen> createState() => _CrmLeadDetailScreenState();
}

class _CrmLeadDetailScreenState extends State<CrmLeadDetailScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, dynamic> _map(dynamic value) => value is Map
      ? Map<String, dynamic>.from(value)
      : const <String, dynamic>{};
  List<Map<String, dynamic>> _maps(dynamic value) =>
      (value as List? ?? const <dynamic>[])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
  int _id(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;
  String _str(dynamic value, [String fallback = '—']) {
    final s = value?.toString().trim() ?? '';
    return s.isEmpty ? fallback : s;
  }

  Map<String, dynamic> get _lead => _map(_data?['lead']);
  Map<String, dynamic> get _meta => _map(_data?['meta']);
  List<Map<String, dynamic>> get _opportunities => _maps(_lead['opportunities']);
  List<Map<String, dynamic>> get _activities => _maps(_lead['activities']);
  List<Map<String, dynamic>> get _followUps => _maps(_lead['follow_ups']);
  List<Map<String, dynamic>> get _assignees => _maps(_data?['assignees']);
  List<Map<String, dynamic>> get _customers => _maps(_data?['customers']);
  List<Map<String, dynamic>> get _engineers => _maps(_data?['engineers']);
  List<Map<String, dynamic>> get _consultationTypes => _maps(_data?['consultation_types']);

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await ApiService.fetchCrmLead(widget.leadId);
      if (mounted) setState(() => _data = data);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر تحميل العميل المحتمل.'.tr());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(trUi(message)),
        backgroundColor: error ? AppColors.danger : AppColors.success,
      ),
    );
  }

  String _stageLabel(String value) => switch (value) {
        'new' => 'جديد'.tr(),
        'contacted' => 'تم التواصل'.tr(),
        'qualified' => 'مؤهل'.tr(),
        'proposal_sent' => 'تم إرسال العرض'.tr(),
        'negotiation' => 'مرحلة التفاوض'.tr(),
        'won' => 'تم الفوز'.tr(),
        'converted' => 'تم التحويل'.tr(),
        'lost' => 'مفقود'.tr(),
        _ => value,
      };

  String _sourceLabel(String value) => switch (value) {
        'website' => 'الموقع الإلكتروني'.tr(),
        'referral' => 'إحالة'.tr(),
        'whatsapp' => 'واتساب'.tr(),
        'instagram' => 'إنستغرام'.tr(),
        'linkedin' => 'لينكدإن'.tr(),
        'phone' => 'اتصال هاتفي'.tr(),
        'walk_in' => 'زيارة مباشرة'.tr(),
        'existing_client' => 'عميل سابق'.tr(),
        'other' => 'أخرى'.tr(),
        _ => value,
      };

  String _channelLabel(String value) => switch (value) {
        'call' => 'اتصال'.tr(),
        'whatsapp' => 'واتساب'.tr(),
        'email' => 'بريد إلكتروني'.tr(),
        'meeting' => 'اجتماع'.tr(),
        'other' => 'أخرى'.tr(),
        _ => value,
      };

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<int?>(
      MaterialPageRoute(builder: (_) => CrmLeadFormScreen(leadId: widget.leadId)),
    );
    if (saved != null) await _load();
  }

  Future<void> _addActivity() async {
    final body = TextEditingController();
    String type = 'note';
    int? opportunityId;
    final types = (_meta['activity_types'] as List? ?? const <dynamic>[])
        .map((e) => e.toString())
        .toList();
    if (types.isNotEmpty && !types.contains(type)) type = types.first;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('تسجيل نشاط'.tr()),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: InputDecoration(labelText: 'نوع النشاط'.tr()),
                    items: types
                        .map((value) => DropdownMenuItem(value: value, child: Text(trUi(_activityLabel(value)))))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setLocal(() => type = value);
                    },
                  ),
                  if (_opportunities.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int?>(
                      initialValue: opportunityId,
                      decoration: InputDecoration(labelText: 'الفرصة المرتبطة'.tr()),
                      items: [
                        DropdownMenuItem<int?>(value: null, child: Text('بدون فرصة'.tr())),
                        ..._opportunities.map(
                          (item) => DropdownMenuItem<int?>(
                            value: _id(item['id']),
                            child: Text(trUi(_str(item['title']))),
                          ),
                        ),
                      ],
                      onChanged: (value) => setLocal(() => opportunityId = value),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: body,
                    minLines: 3,
                    maxLines: 6,
                    decoration: InputDecoration(labelText: 'التفاصيل *'.tr()),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text('إلغاء'.tr())),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text('إضافة'.tr())),
          ],
        ),
      ),
    );

    if (ok == true && body.text.trim().isNotEmpty) {
      try {
        final message = await ApiService.addCrmActivity(
          widget.leadId,
          {
            'type': type,
            'body': body.text.trim(),
            if (opportunityId != null) 'opportunity_id': opportunityId,
          },
        );
        _toast(message);
        await _load();
      } on ApiException catch (e) {
        _toast(e.message, error: true);
      }
    }
    Future<void>.delayed(const Duration(milliseconds: 600), body.dispose);
  }

  String _activityLabel(String value) => switch (value) {
        'note' => 'ملاحظة'.tr(),
        'call' => 'اتصال'.tr(),
        'whatsapp' => 'واتساب'.tr(),
        'email' => 'بريد إلكتروني'.tr(),
        'meeting' => 'اجتماع'.tr(),
        'status_change' => 'تغيير مرحلة'.tr(),
        'assignment' => 'إسناد'.tr(),
        'opportunity' => 'فرصة'.tr(),
        'follow_up' => 'متابعة'.tr(),
        'conversion' => 'تحويل'.tr(),
        'system' => 'النظام'.tr(),
        _ => value,
      };

  Future<void> _addFollowUp() async {
    final title = TextEditingController();
    final notes = TextEditingController();
    String channel = 'call';
    DateTime dueAt = DateTime.now().add(const Duration(days: 1));
    final leadAssignee = _map(_lead['assignee']);
    int? assignedTo = _id(leadAssignee['id']) == 0 ? null : _id(leadAssignee['id']);
    int? opportunityId;
    final channels = (_meta['follow_up_channels'] as List? ?? const <dynamic>[])
        .map((e) => e.toString())
        .toList();
    if (channels.isNotEmpty && !channels.contains(channel)) channel = channels.first;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('متابعة جديدة'.tr()),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: title, decoration: InputDecoration(labelText: 'عنوان المتابعة *'.tr())),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: channel,
                    decoration: InputDecoration(labelText: 'القناة'.tr()),
                    items: channels.map((value) => DropdownMenuItem(value: value, child: Text(trUi(_channelLabel(value))))).toList(),
                    onChanged: (value) {
                      if (value != null) setLocal(() => channel = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int?>(
                    initialValue: assignedTo,
                    decoration: InputDecoration(labelText: 'المسؤول'.tr()),
                    items: [
                      DropdownMenuItem<int?>(value: null, child: Text('غير مسند'.tr())),
                      ..._assignees.map((item) => DropdownMenuItem<int?>(value: _id(item['id']), child: Text(trUi(_str(item['name']))))),
                    ],
                    onChanged: (value) => setLocal(() => assignedTo = value),
                  ),
                  if (_opportunities.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int?>(
                      initialValue: opportunityId,
                      decoration: InputDecoration(labelText: 'الفرصة'.tr()),
                      items: [
                        DropdownMenuItem<int?>(value: null, child: Text('بدون فرصة'.tr())),
                        ..._opportunities.map((item) => DropdownMenuItem<int?>(value: _id(item['id']), child: Text(trUi(_str(item['title']))))),
                      ],
                      onChanged: (value) => setLocal(() => opportunityId = value),
                    ),
                  ],
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: dueAt,
                        firstDate: DateTime.now().subtract(const Duration(days: 30)),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (date == null || !context.mounted) return;
                      final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(dueAt));
                      if (time == null) return;
                      setLocal(() => dueAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                    },
                    icon: const Icon(Icons.event_rounded),
                    label: Text(trUi(_shortDateTime(dueAt.toIso8601String()))),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: notes, minLines: 2, maxLines: 5, decoration: InputDecoration(labelText: 'ملاحظات'.tr())),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text('إلغاء'.tr())),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text('إضافة'.tr())),
          ],
        ),
      ),
    );

    if (ok == true && title.text.trim().isNotEmpty) {
      try {
        final message = await ApiService.addCrmFollowUp(
          widget.leadId,
          {
            'title': title.text.trim(),
            'channel': channel,
            'due_at': dueAt.toIso8601String(),
            'notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
            'assigned_to': assignedTo,
            if (opportunityId != null) 'opportunity_id': opportunityId,
          },
        );
        _toast(message);
        await _load();
      } on ApiException catch (e) {
        _toast(e.message, error: true);
      }
    }
    Future<void>.delayed(const Duration(milliseconds: 600), title.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), notes.dispose);
  }

  Future<void> _addOpportunity() async {
    final title = TextEditingController(text: _lead['requested_service']?.toString() ?? '');
    final value = TextEditingController(text: _lead['estimated_budget']?.toString() ?? '');
    final probability = TextEditingController(text: '50');
    final notes = TextEditingController();
    String currency = _lead['currency']?.toString() ?? 'ILS';
    String stage = 'qualified';
    final leadAssignee = _map(_lead['assignee']);
    int? assignedTo = _id(leadAssignee['id']) == 0 ? null : _id(leadAssignee['id']);
    DateTime? expectedCloseDate;
    final stages = (_meta['opportunity_stages'] as List? ?? const <dynamic>[])
        .map((e) => e.toString())
        .toList();
    if (stages.isNotEmpty && !stages.contains(stage)) stage = stages.first;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('فرصة بيعية جديدة'.tr()),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: title, decoration: InputDecoration(labelText: 'عنوان الفرصة *'.tr())),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: value, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'القيمة'.tr()))),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 100,
                        child: DropdownButtonFormField<String>(
                          initialValue: currency,
                          items: const ['USD', 'ILS', 'JOD', 'SAR', 'EUR'].map((item) => DropdownMenuItem(value: item, child: Text(trUi(item)))).toList(),
                          onChanged: (item) {
                            if (item != null) setLocal(() => currency = item);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: probability, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'الاحتمال %'.tr())),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: stage,
                    decoration: InputDecoration(labelText: 'المرحلة'.tr()),
                    items: stages.map((item) => DropdownMenuItem(value: item, child: Text(trUi(_stageLabel(item))))).toList(),
                    onChanged: (item) {
                      if (item != null) setLocal(() => stage = item);
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int?>(
                    initialValue: assignedTo,
                    decoration: InputDecoration(labelText: 'المسؤول'.tr()),
                    items: [
                      DropdownMenuItem<int?>(value: null, child: Text('غير مسند'.tr())),
                      ..._assignees.map((item) => DropdownMenuItem<int?>(value: _id(item['id']), child: Text(trUi(_str(item['name']))))),
                    ],
                    onChanged: (value) => setLocal(() => assignedTo = value),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: expectedCloseDate ?? DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (date != null) setLocal(() => expectedCloseDate = date);
                    },
                    icon: const Icon(Icons.event_available_outlined),
                    label: Text(trUi(expectedCloseDate == null ? 'تاريخ الإغلاق المتوقع'.tr() : _dateOnly(expectedCloseDate!.toIso8601String()))),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: notes, minLines: 2, maxLines: 5, decoration: InputDecoration(labelText: 'ملاحظات'.tr())),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text('إلغاء'.tr())),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text('إنشاء'.tr())),
          ],
        ),
      ),
    );

    if (ok == true && title.text.trim().isNotEmpty) {
      try {
        final message = await ApiService.addCrmOpportunity(
          widget.leadId,
          {
            'title': title.text.trim(),
            'value': double.tryParse(value.text.trim()),
            'currency': currency,
            'probability': int.tryParse(probability.text.trim()) ?? 0,
            'stage': stage,
            'expected_close_date': expectedCloseDate == null ? null : _dateOnly(expectedCloseDate!.toIso8601String()),
            'assigned_to': assignedTo,
            'notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
          },
        );
        _toast(message);
        await _load();
      } on ApiException catch (e) {
        _toast(e.message, error: true);
      }
    }
    Future<void>.delayed(const Duration(milliseconds: 600), title.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), value.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), probability.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), notes.dispose);
  }

  Future<void> _followUpAction(Map<String, dynamic> item, String action) async {
    try {
      final message = await ApiService.crmFollowUpAction(_id(item['id']), action);
      _toast(message);
      await _load();
    } on ApiException catch (e) {
      _toast(e.message, error: true);
    }
  }

  Future<void> _convert() async {
    final linkedUser = _map(_lead['linked_user']);
    int? customerId = _id(linkedUser['id']) == 0 ? null : _id(linkedUser['id']);
    int? consultationTypeId;
    int? engineerId;
    int? opportunityId;
    final title = TextEditingController(text: _lead['requested_service']?.toString() ?? '');
    final description = TextEditingController(text: _lead['notes']?.toString() ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('تحويل إلى استشارة'.tr()),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int?>(
                    initialValue: customerId,
                    decoration: InputDecoration(labelText: 'حساب العميل *'.tr()),
                    items: _customers.map((item) => DropdownMenuItem<int?>(value: _id(item['id']), child: Text('${_str(item['name'])} — ${_str(item['email'], '')}'))).toList(),
                    onChanged: (value) => setLocal(() => customerId = value),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int?>(
                    initialValue: consultationTypeId,
                    decoration: InputDecoration(labelText: 'نوع الاستشارة *'.tr()),
                    items: _consultationTypes.map((item) => DropdownMenuItem<int?>(value: _id(item['id']), child: Text('${_str(item['name'])} — ${item['price'] ?? 0}'))).toList(),
                    onChanged: (value) => setLocal(() => consultationTypeId = value),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int?>(
                    initialValue: engineerId,
                    decoration: InputDecoration(labelText: 'المهندس'.tr()),
                    items: [
                      DropdownMenuItem<int?>(value: null, child: Text('بدون مهندس محدد'.tr())),
                      ..._engineers.map((item) => DropdownMenuItem<int?>(value: _id(item['id']), child: Text(trUi(_str(item['name']))))),
                    ],
                    onChanged: (value) => setLocal(() => engineerId = value),
                  ),
                  if (_opportunities.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int?>(
                      initialValue: opportunityId,
                      decoration: InputDecoration(labelText: 'الفرصة المرتبطة'.tr()),
                      items: [
                        DropdownMenuItem<int?>(value: null, child: Text('بدون فرصة'.tr())),
                        ..._opportunities.map((item) => DropdownMenuItem<int?>(value: _id(item['id']), child: Text(trUi(_str(item['title']))))),
                      ],
                      onChanged: (value) => setLocal(() => opportunityId = value),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(controller: title, decoration: InputDecoration(labelText: 'عنوان الاستشارة'.tr())),
                  const SizedBox(height: 10),
                  TextField(controller: description, minLines: 3, maxLines: 6, decoration: InputDecoration(labelText: 'الوصف'.tr())),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text('إلغاء'.tr())),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text('تأكيد التحويل'.tr())),
          ],
        ),
      ),
    );

    if (ok == true) {
      if (customerId == null || consultationTypeId == null) {
        _toast('اختر حساب العميل ونوع الاستشارة.'.tr(), error: true);
      } else {
        try {
          final result = await ApiService.convertCrmLead(
            widget.leadId,
            {
              'linked_user_id': customerId,
              'consultation_type_id': consultationTypeId,
              'engineer_id': engineerId,
              'opportunity_id': opportunityId,
              'title': title.text.trim().isEmpty ? null : title.text.trim(),
              'description': description.text.trim().isEmpty ? null : description.text.trim(),
            },
          );
          _toast(result['message']?.toString() ?? 'تم التحويل إلى استشارة.'.tr());
          await _load();
        } on ApiException catch (e) {
          _toast(e.message, error: true);
        }
      }
    }
    Future<void>.delayed(const Duration(milliseconds: 600), title.dispose);
    Future<void>.delayed(const Duration(milliseconds: 600), description.dispose);
  }

  String _dateOnly(String value) => value.contains('T') ? value.split('T').first : value;
  String _shortDateTime(String value) {
    if (value.isEmpty) return '—';
    return value.replaceFirst('T', ' ').split('.').first;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        backgroundColor: dark ? const Color(0xFF061226) : const Color(0xFFF4F8FF),
        appBar: AppBar(
          title: Text(trUi(_loading ? 'CRM' : _str(_lead['name'], 'CRM'))),
          actions: [
            IconButton(onPressed: _edit, tooltip: 'تعديل'.tr(), icon: const Icon(Icons.edit_outlined)),
            IconButton(onPressed: _load, tooltip: 'تحديث'.tr(), icon: const Icon(Icons.refresh_rounded)),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 90),
                      children: [
                        _LeadHeader(lead: _lead, stageLabel: _stageLabel),
                        const SizedBox(height: 12),
                        _Overview(lead: _lead, sourceLabel: _sourceLabel),
                        const SizedBox(height: 12),
                        _ActionBar(
                          onActivity: _addActivity,
                          onFollowUp: _addFollowUp,
                          onOpportunity: _addOpportunity,
                          onConvert: _lead['converted_consultation'] == null ? _convert : null,
                        ),
                        const SizedBox(height: 12),
                        _SectionList(
                          title: 'الفرص البيعية'.tr(),
                          icon: Icons.lightbulb_outline_rounded,
                          emptyText: 'لا توجد فرصة حتى الآن.'.tr(),
                          children: _opportunities.map((item) => _OpportunityCard(item: item, stageLabel: _stageLabel)).toList(),
                        ),
                        const SizedBox(height: 12),
                        _SectionList(
                          title: 'المتابعات'.tr(),
                          icon: Icons.schedule_rounded,
                          emptyText: 'لا توجد متابعات.'.tr(),
                          children: _followUps.map((item) => _FollowUpCard(item: item, channelLabel: _channelLabel, onAction: _followUpAction)).toList(),
                        ),
                        const SizedBox(height: 12),
                        _SectionList(
                          title: 'سجل النشاطات'.tr(),
                          icon: Icons.history_rounded,
                          emptyText: 'لا يوجد نشاط مسجل.'.tr(),
                          children: _activities.map((item) => _ActivityCard(item: item, typeLabel: _activityLabel)).toList(),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _LeadHeader extends StatelessWidget {
  const _LeadHeader({required this.lead, required this.stageLabel});
  final Map<String, dynamic> lead;
  final String Function(String) stageLabel;

  @override
  Widget build(BuildContext context) {
    final score = int.tryParse(lead['score']?.toString() ?? '') ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(radius: 26, child: Text(trUi('${lead['name'] ?? 'L'}'.substring(0, 1)))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${lead['name'] ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19)),
                  const SizedBox(height: 3),
                  Text('${lead['lead_number'] ?? '—'} • ${stageLabel('${lead['stage'] ?? ''}')}', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Column(
              children: [
                Text('$score/100', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                Text('Lead Score', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.lead, required this.sourceLabel});
  final Map<String, dynamic> lead;
  final String Function(String) sourceLabel;

  Map<String, dynamic> _map(dynamic value) => value is Map ? Map<String, dynamic>.from(value) : const {};
  String _str(dynamic value, [String fallback = '—']) {
    final s = value?.toString().trim() ?? '';
    return s.isEmpty ? fallback : s;
  }

  @override
  Widget build(BuildContext context) {
    final office = _map(lead['office']);
    final assignee = _map(lead['assignee']);
    final linked = _map(lead['linked_user']);
    final converted = _map(lead['converted_consultation']);
    final rows = <(String, String)>[
      ('الشركة / المؤسسة'.tr(), _str(lead['company'])),
      ('الهاتف'.tr(), _str(lead['phone'])),
      ('البريد الإلكتروني'.tr(), _str(lead['email'])),
      ('المصدر'.tr(), sourceLabel(_str(lead['source'], 'other'))),
      ('الخدمة المطلوبة'.tr(), _str(lead['requested_service'])),
      ('الميزانية التقديرية'.tr(), lead['estimated_budget'] == null ? '—' : '${lead['estimated_budget']} ${lead['currency'] ?? ''}'),
      ('المكتب'.tr(), _str(office['name'], 'Lead تابع للمنصة'.tr())),
      ('المسؤول'.tr(), _str(assignee['name'], 'غير مسند'.tr())),
      ('الموقع'.tr(), [lead['country'], lead['city']].where((e) => e != null && e.toString().trim().isNotEmpty).join(' • ').isEmpty ? '—' : [lead['country'], lead['city']].where((e) => e != null && e.toString().trim().isNotEmpty).join(' • ')),
      ('آخر تواصل'.tr(), _str(lead['last_contacted_at'], 'لم يتم'.tr())),
      if (linked.isNotEmpty) ('المستخدم المرتبط'.tr(), '${_str(linked['name'])} — ${_str(linked['email'], '')}'),
      if (converted.isNotEmpty) ('الاستشارة المحولة'.tr(), _str(converted['consultation_number'])),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('ملخص العميل'.tr(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 10),
            ...rows.map((row) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 145, child: Text(trUi(row.$1), style: Theme.of(context).textTheme.bodySmall)),
                      Expanded(child: Text(trUi(row.$2), style: const TextStyle(fontWeight: FontWeight.w700))),
                    ],
                  ),
                )),
            if (_str(lead['notes'], '').isNotEmpty) ...[
              const Divider(height: 22),
              Text('ملاحظات'.tr(), style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(trUi(_str(lead['notes'], ''))),
            ],
            if (_str(lead['lost_reason'], '').isNotEmpty) ...[
              const Divider(height: 22),
              Text('سبب الخسارة'.tr(), style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.danger)),
              const SizedBox(height: 6),
              Text(trUi(_str(lead['lost_reason'], ''))),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.onActivity, required this.onFollowUp, required this.onOpportunity, required this.onConvert});
  final VoidCallback onActivity;
  final VoidCallback onFollowUp;
  final VoidCallback onOpportunity;
  final VoidCallback? onConvert;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(onPressed: onActivity, icon: const Icon(Icons.add_comment_outlined), label: Text('تسجيل نشاط'.tr())),
              OutlinedButton.icon(onPressed: onFollowUp, icon: const Icon(Icons.schedule_rounded), label: Text('إضافة متابعة'.tr())),
              OutlinedButton.icon(onPressed: onOpportunity, icon: const Icon(Icons.lightbulb_outline_rounded), label: Text('إضافة فرصة'.tr())),
              if (onConvert != null) FilledButton.icon(onPressed: onConvert, icon: const Icon(Icons.transform_rounded), label: Text('تحويل إلى استشارة'.tr())),
            ],
          ),
        ),
      );
}

class _SectionList extends StatelessWidget {
  const _SectionList({required this.title, required this.icon, required this.emptyText, required this.children});
  final String title;
  final IconData icon;
  final String emptyText;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [Icon(icon, size: 20), const SizedBox(width: 8), Text(trUi(title), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))]),
              const SizedBox(height: 10),
              if (children.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Center(child: Text(trUi(emptyText)))) else ...children,
            ],
          ),
        ),
      );
}

class _OpportunityCard extends StatelessWidget {
  const _OpportunityCard({required this.item, required this.stageLabel});
  final Map<String, dynamic> item;
  final String Function(String) stageLabel;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(child: Icon(Icons.lightbulb_outline_rounded)),
        title: Text('${item['title'] ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${stageLabel('${item['stage'] ?? ''}')} • ${item['value'] ?? 0} ${item['currency'] ?? ''} • ${'احتمالية'.tr()} ${item['probability'] ?? 0}%\n${'الإغلاق المتوقع'.tr()}: ${item['expected_close_date'] ?? '—'}'.tr()),
        isThreeLine: true,
      );
}

class _FollowUpCard extends StatelessWidget {
  const _FollowUpCard({required this.item, required this.channelLabel, required this.onAction});
  final Map<String, dynamic> item;
  final String Function(String) channelLabel;
  final Future<void> Function(Map<String, dynamic>, String) onAction;

  @override
  Widget build(BuildContext context) {
    final pending = item['status']?.toString() == 'pending';
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(child: Icon(Icons.schedule_outlined)),
          title: Text('${item['title'] ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('${channelLabel('${item['channel'] ?? ''}')} • ${item['due_at'] ?? '—'}\n${item['assignee'] is Map ? (item['assignee'] as Map)['name'] ?? '' : ''}'),
          isThreeLine: true,
          trailing: Text('${item['status'] ?? ''}'.tr()),
        ),
        if (pending)
          Row(
            children: [
              Expanded(child: FilledButton(onPressed: () => onAction(item, 'complete'), child: Text('إكمال'.tr()))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(onPressed: () => onAction(item, 'cancel'), child: Text('إلغاء'.tr()))),
            ],
          ),
        const Divider(height: 20),
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.item, required this.typeLabel});
  final Map<String, dynamic> item;
  final String Function(String) typeLabel;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(child: Icon(Icons.history_rounded)),
        title: Text(trUi(typeLabel('${item['type'] ?? ''}')), style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${item['body'] ?? ''}\n${item['occurred_at'] ?? '—'}'),
        isThreeLine: true,
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(trUi(message), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: Text('إعادة المحاولة'.tr())),
            ],
          ),
        ),
      );
}
