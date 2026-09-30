import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../i18n/localized_text.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';
import 'ai_entry_screen.dart';
import 'account_recovery_support_screen.dart';
import 'support_ticket_screen.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
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
      final data = await ApiService.fetchSupportTickets();
      if (mounted) setState(() => _data = data);
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createTicket() async {
    final subject = TextEditingController();
    final message = TextEditingController();
    String priority = 'medium';
    File? attachment;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const TrText('فتح تذكرة دعم'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: subject, decoration: InputDecoration(labelText: 'الموضوع'.tr())),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: priority,
                    decoration: InputDecoration(labelText: 'الأولوية'.tr()),
                    items: const [
                      DropdownMenuItem(value: 'low', child: TrText('منخفضة')),
                      DropdownMenuItem(value: 'medium', child: TrText('متوسطة')),
                      DropdownMenuItem(value: 'high', child: TrText('عالية')),
                      DropdownMenuItem(value: 'urgent', child: TrText('عاجلة')),
                    ],
                    onChanged: (value) => setDialogState(() => priority = value ?? 'medium'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: message,
                    maxLines: 5,
                    decoration: InputDecoration(labelText: 'الرسالة'.tr(), alignLabelWithHint: true),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final result = await FilePicker.pickFile();
                      if (result?.path != null) {
                        setDialogState(() => attachment = File(result!.path!));
                      }
                    },
                    icon: const Icon(Icons.attach_file_rounded),
                    label: Text(trUi(attachment == null ? 'إرفاق ملف' : attachment!.path.split(Platform.pathSeparator).last)),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const TrText('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const TrText('فتح التذكرة')),
            ],
          ),
        ),
      ),
    );

    if (ok != true) {
      Future<void>.delayed(const Duration(milliseconds: 600), subject.dispose);
      Future<void>.delayed(const Duration(milliseconds: 600), message.dispose);
      return;
    }

    try {
      final id = await ApiService.createSupportTicket(
        subject: subject.text.trim(),
        priority: priority,
        message: message.text.trim(),
        attachment: attachment,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SupportTicketScreen(ticketId: id)),
      );
      _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    } finally {
      subject.dispose();
      message.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = List<dynamic>.from(_data?['data'] as List? ?? const []);
    final available = _data?['support_available'] == true;
    final authUser = context.watch<AuthProvider>().user;
    final canRecoverAccounts =
        _data?['can_recover_accounts'] == true ||
        _data?['is_support_employee'] == true ||
        authUser?.canRecoverAccounts == true;

    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        appBar: AppBar(title: const TrText('مركز الدعم')),
        floatingActionButton: available
            ? FloatingActionButton.extended(
                onPressed: _createTicket,
                icon: const Icon(Icons.add_rounded),
                label: const TrText('تذكرة جديدة'),
              )
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
                        if (canRecoverAccounts) ...[
                          Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: Color(0x5538BDF8)),
                            ),
                            child: ListTile(
                              leading: Icon(Icons.history_rounded, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF67E8F9) : Color(0xFF0E7490))),
                              title: const TrText('فقد الوصول للحسابات', style: TextStyle(fontWeight: FontWeight.w900)),
                              subtitle: const TrText('راجع إثبات الهوية وأعد الوصول للحساب عند فقد البريد أو كلمة المرور أو 2FA.'),
                              trailing: const Icon(Icons.chevron_left_rounded),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const AccountRecoverySupportScreen()),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Card(
                          child: ListTile(
                            leading: Icon(Icons.smart_toy_outlined, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan)),
                            title: const TrText('المساعد الذكي', style: TextStyle(fontWeight: FontWeight.w900)),
                            subtitle: const TrText('اسأل مساعد المنصة أو اطلب التحويل لموظف دعم.'),
                            trailing: const Icon(Icons.chevron_left_rounded),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const AiEntryScreen()),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (!available)
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: TrText('خدمة الدعم البشري غير متاحة حاليًا.'),
                            ),
                          ),
                        const SizedBox(height: 12),
                        const TrText('تذاكري', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                        const SizedBox(height: 10),
                        if (items.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(30),
                            child: Center(child: TrText('لا توجد تذاكر دعم.')),
                          )
                        else
                          ...items.map((raw) {
                            final item = Map<String, dynamic>.from(raw as Map);
                            return Card(
                              child: ListTile(
                                leading: const Icon(Icons.support_agent_rounded),
                                title: Text(trUi(item['subject']?.toString() ?? '-')),
                                subtitle: Text('${item['ticket_number'] ?? ''} • ${_statusLabel(item['status']?.toString() ?? '')}'),
                                trailing: const Icon(Icons.chevron_left_rounded),
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => SupportTicketScreen(
                                        ticketId: int.parse(item['id'].toString()),
                                      ),
                                    ),
                                  );
                                  _load();
                                },
                              ),
                            );
                          }),
                        const SizedBox(height: 90),
                      ],
                    ),
                  ),
      ),
    );
  }

  String _statusLabel(String status) => switch (status) {
        'open' => 'مفتوحة'.tr(),
        'in_progress' => 'قيد المعالجة'.tr(),
        'waiting_customer' => 'بانتظارك'.tr(),
        'resolved' => 'محلولة'.tr(),
        'closed' => 'مغلقة'.tr(),
        _ => status,
      };
}
