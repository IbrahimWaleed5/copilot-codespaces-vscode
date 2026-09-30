import 'package:flutter/material.dart';

import '../i18n/localized_text.dart';
import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';

class AdminModerationScreen extends StatefulWidget {
  const AdminModerationScreen({super.key});

  @override
  State<AdminModerationScreen> createState() => _AdminModerationScreenState();
}

class _AdminModerationScreenState extends State<AdminModerationScreen> with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = {};
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.fetchAdminModeration();
      if (mounted) setState(() => _data = data);
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _notes(String title, {bool required = true}) async {
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: AlertDialog(
          title: Text(trUi(title)),
          content: TextField(controller: controller, minLines: 3, maxLines: 6),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const TrText('إلغاء')),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (required && value.isEmpty) return;
                Navigator.pop(dialogContext, value);
              },
              child: const TrText('تأكيد'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 320));
    Future<void>.delayed(const Duration(milliseconds: 600), controller.dispose);
    return result;
  }

  Future<void> _warning(int id, String action) async {
    final notes = await _notes(action == 'confirm' ? 'تأكيد التحذير' : 'إلغاء التحذير', required: action == 'cancel');
    if (notes == null) return;
    try {
      final text = await ApiService.adminWarningAction(id, action, notes: notes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(text))));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    }
  }

  Future<void> _userAction(int userId, String action) async {
    final notes = await _notes(action == 'reactivate' ? 'سبب إعادة التفعيل' : 'سبب تثبيت التعليق');
    if (notes == null || notes.isEmpty) return;
    try {
      final text = await ApiService.adminSuspendedUserAction(userId, action, notes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(text))));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    }
  }

  Future<void> _appeal(int id, String action) async {
    String? response;
    if (action != 'start-review') {
      response = await _notes(action == 'approve' ? 'قبول الطعن' : 'رفض الطعن');
      if (response == null || response.length < 10) return;
    }
    try {
      final text = await ApiService.adminAppealAction(id, action, response: response);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(text))));
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final warnings = _data['warnings'] as List? ?? [];
    final appeals = _data['appeals'] as List? ?? [];
    final stats = Map<String, dynamic>.from(_data['stats'] as Map? ?? {});

    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: const TrText('الإشراف والمراجعة'),
          bottom: TabBar(controller: _tabs, tabs: [
            Tab(text: 'التحذيرات'.tr()),
            Tab(text: 'الطعون'.tr()),
          ]),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(trUi(_error!)))
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _stat('تحذيرات', stats['all_warnings']),
                            _stat('نشطة', stats['active_warnings']),
                            _stat('حسابات معلقة', stats['suspended_accounts']),
                            _stat('طعون معلقة', stats['pending_appeals']),
                          ],
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabs,
                          children: [
                            RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: warnings.length,
                                itemBuilder: (_, i) => _warningCard(Map<String, dynamic>.from(warnings[i] as Map)),
                              ),
                            ),
                            RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: appeals.length,
                                itemBuilder: (_, i) => _appealCard(Map<String, dynamic>.from(appeals[i] as Map)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _stat(String label, dynamic value) => Chip(label: Text('$label: ${value ?? 0}'));

  Widget _warningCard(Map<String, dynamic> warning) {
    final user = Map<String, dynamic>.from(warning['user'] as Map? ?? {});
    final id = int.parse(warning['id'].toString());
    final userId = user['id'] == null ? null : int.parse(user['id'].toString());
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(trUi(user['name']?.toString() ?? '-'), style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(trUi(user['email']?.toString() ?? '-'), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 11)),
            const SizedBox(height: 8),
            Text(trUi(warning['reason']?.toString() ?? '-')),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (warning['status'] != 'confirmed' && warning['status'] != 'cancelled')
                  OutlinedButton(onPressed: () => _warning(id, 'confirm'), child: const TrText('تأكيد')),
                if (warning['status'] != 'cancelled')
                  OutlinedButton(onPressed: () => _warning(id, 'cancel'), child: const TrText('إلغاء التحذير')),
                if (userId != null && user['status'] != 'active')
                  OutlinedButton(onPressed: () => _userAction(userId, 'reactivate'), child: const TrText('إعادة تفعيل')),
                if (userId != null && user['status'] == 'suspended_pending_review')
                  OutlinedButton(onPressed: () => _userAction(userId, 'keep-suspended'), child: const TrText('تثبيت التعليق')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _appealCard(Map<String, dynamic> appeal) {
    final user = Map<String, dynamic>.from(appeal['user'] as Map? ?? {});
    final id = int.parse(appeal['id'].toString());
    final status = appeal['status']?.toString().trim().toLowerCase() ?? '';
    final canStart = ['pending', 'open', 'submitted', 'pending_review', 'new', 'waiting_review']
        .contains(status);
    final underReview = ['under_review', 'in_review', 'reviewing'].contains(status);
    final canResolve = canStart || underReview;
    final statusLabel = switch (status) {
      'pending' || 'open' || 'submitted' || 'pending_review' || 'new' || 'waiting_review' => 'بانتظار المراجعة',
      'under_review' || 'in_review' || 'reviewing' => 'قيد المراجعة',
      'approved' => 'مقبول',
      'rejected' => 'مرفوض',
      'cancelled' => 'ملغي',
      _ => status.isEmpty ? '—' : status,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              trUi(user['name']?.toString() ?? '-'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            if ((user['email']?.toString().isNotEmpty ?? false))
              Text(
                trUi(user['email'].toString()),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant),
                  fontSize: 11,
                ),
              ),
            const SizedBox(height: 8),
            Text(trUi(appeal['message']?.toString() ?? '')),
            const SizedBox(height: 8),
            TrText('الحالة: $statusLabel',
              style: TextStyle(
                color: status == 'rejected'
                    ? AppColors.danger
                    : status == 'approved'
                        ? AppColors.success
                        : (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan),
                fontWeight: FontWeight.w700,
              ),
            ),
            if (underReview) ...[
              const SizedBox(height: 6),
              TrText('تم بدء المراجعة. اختر قبول أو رفض بعد مراجعة تفاصيل الطعن.',
                style: TextStyle(
                  color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant),
                  fontSize: 11,
                ),
              ),
            ],
            if (canResolve) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (canStart)
                    OutlinedButton.icon(
                      onPressed: () => _appeal(id, 'start-review'),
                      icon: const Icon(Icons.rate_review_outlined),
                      label: const TrText('بدء المراجعة'),
                    ),
                  FilledButton.icon(
                    onPressed: () => _appeal(id, 'approve'),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const TrText('قبول'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _appeal(id, 'reject'),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const TrText('رفض'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
