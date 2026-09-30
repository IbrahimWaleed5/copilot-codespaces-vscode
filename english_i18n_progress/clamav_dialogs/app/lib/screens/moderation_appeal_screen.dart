import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../i18n/localized_text.dart';
import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';

class ModerationAppealScreen extends StatefulWidget {
  const ModerationAppealScreen({super.key});

  @override
  State<ModerationAppealScreen> createState() => _ModerationAppealScreenState();
}

class _ModerationAppealScreenState extends State<ModerationAppealScreen> {
  bool _loading = true;
  Map<String, dynamic> _data = {};
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
      final data = await ApiService.fetchMyModerationAppeal();
      if (mounted) setState(() => _data = data);
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final controller = TextEditingController();
    File? attachment;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const TrText('إرسال طعن'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    minLines: 5,
                    maxLines: 9,
                    decoration: InputDecoration(labelText: 'رسالة الطعن - 20 حرفًا على الأقل'.tr()),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await FilePicker.pickFile(
                        type: FileType.custom,
                        allowedExtensions: const ['jpg','jpeg','png','pdf'],
                      );
                      if (picked?.path != null) {
                        setDialogState(() => attachment = File(picked!.path!));
                      }
                    },
                    icon: const Icon(Icons.attach_file),
                    label: Text(trUi(attachment == null ? 'إرفاق ملف اختياري' : 'تم اختيار المرفق')),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const TrText('إلغاء')),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, controller.text.trim().length >= 20),
                child: const TrText('إرسال'),
              ),
            ],
          ),
        ),
      ),
    );

    final text = controller.text.trim();
    Future<void>.delayed(const Duration(milliseconds: 600), controller.dispose);
    if (confirmed != true || text.length < 20) return;

    try {
      final message = await ApiService.submitModerationAppeal(message: text, attachment: attachment);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(message))));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    }
  }

  Future<void> _cancel(int id) async {
    try {
      final message = await ApiService.cancelModerationAppeal(id);
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
          appBar: AppBar(title: const TrText('حالة الحساب والطعن')),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(trUi(_error!)))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Card(
                          child: ListTile(
                            leading: Icon(Icons.shield_outlined, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan)),
                            title: const TrText('حالة الحساب'),
                            subtitle: Text(trUi(_data['account_status']?.toString() ?? '-')),
                          ),
                        ),
                        if (_data['latest_warning'] is Map) ...[
                          const SizedBox(height: 10),
                          _warningCard(Map<String, dynamic>.from(_data['latest_warning'] as Map)),
                        ],
                        if (_data['latest_appeal'] is Map) ...[
                          const SizedBox(height: 10),
                          _appealCard(Map<String, dynamic>.from(_data['latest_appeal'] as Map)),
                        ],
                        if (_data['can_appeal'] == true) ...[
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _submit,
                            icon: const Icon(Icons.gavel_outlined),
                            label: const TrText('إرسال طعن جديد'),
                          ),
                        ],
                      ],
                    ),
        ),
      );

  Widget _warningCard(Map<String, dynamic> warning) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TrText('آخر تحذير', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(trUi(warning['reason']?.toString() ?? '-')),
              const SizedBox(height: 4),
              TrText('الحالة: ${warning['status'] ?? '-'}', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : AppColors.textSecondary))),
            ],
          ),
        ),
      );

  Widget _appealCard(Map<String, dynamic> appeal) {
    final id = int.parse(appeal['id'].toString());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TrText('آخر طعن', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(trUi(appeal['message']?.toString() ?? '')),
            const SizedBox(height: 6),
            TrText('الحالة: ${appeal['status'] ?? '-'}', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan))),
            if ((appeal['admin_response']?.toString() ?? '').isNotEmpty) ...[
              const Divider(height: 22),
              const TrText('رد الإدارة', style: TextStyle(fontWeight: FontWeight.w800)),
              Text(trUi(appeal['admin_response'].toString())),
            ],
            if (appeal['status'] == 'pending')
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _cancel(id),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const TrText('إلغاء الطعن'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
