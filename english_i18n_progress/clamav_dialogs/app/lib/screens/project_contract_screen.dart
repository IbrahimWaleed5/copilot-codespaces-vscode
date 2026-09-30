import 'package:flutter/material.dart';
import '../i18n/localized_text.dart';
import 'package:open_filex/open_filex.dart';

import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';

class ProjectContractScreen extends StatefulWidget {
  final int projectId;

  const ProjectContractScreen({super.key, required this.projectId});

  @override
  State<ProjectContractScreen> createState() => _ProjectContractScreenState();
}

class _ProjectContractScreenState extends State<ProjectContractScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  bool _downloading = false;
  bool _signing = false;
  bool _declining = false;
  final _typedNameController = TextEditingController();
  bool _acceptedTerms = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _typedNameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.fetchProjectContract(widget.projectId);
      if (!mounted) return;
      setState(() => _data = data);
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _downloadPdf() async {
    final contract = _data?['contract'] as Map<String, dynamic>?;
    if (contract == null) return;

    setState(() => _downloading = true);
    try {
      final file = await ApiService.downloadProjectContract(
        widget.projectId,
        contract['contract_number']?.toString() ?? 'contract-${widget.projectId}',
      );
      await OpenFilex.open(file.path);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _sign() async {
    final typedName = _typedNameController.text.trim();
    if (typedName.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TrText('اكتب اسمك لتأكيد التوقيع الإلكتروني.')),
      );
      return;
    }
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TrText('يجب الموافقة على شروط العقد أولًا.')),
      );
      return;
    }

    setState(() => _signing = true);
    try {
      final result = await ApiService.signProjectContract(
        projectId: widget.projectId,
        typedName: typedName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'تم تسجيل التوقيع.'.tr())),
      );
      _typedNameController.clear();
      _acceptedTerms = false;
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
    } finally {
      if (mounted) setState(() => _signing = false);
    }
  }

  Future<void> _decline() async {
    final controller = TextEditingController();
    final reason = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: AlertDialog(
          title: const TrText('رفض عقد المشروع'),
          content: TextField(
            controller: controller,
            minLines: 3,
            maxLines: 7,
            decoration: InputDecoration(
              labelText: 'سبب الرفض'.tr(),
              hintText: 'اكتب سببًا واضحًا لا يقل عن 5 أحرف'.tr(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const TrText('إلغاء')),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
              child: const TrText('تأكيد الرفض'),
            ),
          ],
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 600), controller.dispose);
    if (reason == null || reason.length < 5) return;

    setState(() => _declining = true);
    try {
      final result = await ApiService.declineProjectContract(
        projectId: widget.projectId,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'تم رفض العقد.'.tr())),
      );
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trUi(e.message))));
      }
    } finally {
      if (mounted) setState(() => _declining = false);
    }
  }

  String _roleLabel(String role) {
    const labels = {
      'customer': 'العميل',
      'lead_engineer': 'المهندس الرئيسي',
      'office_representative': 'ممثل المكتب الهندسي',
    };
    return labels[role] ?? role;
  }

  String _statusLabel(String? status) {
    const labels = {
      'pending_signatures': 'بانتظار التوقيعات',
      'executed': 'العقد نافذ',
      'declined': 'مرفوض',
      'cancelled': 'ملغي',
    };
    return labels[status] ?? status ?? '';
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'executed':
        return AppColors.success;
      case 'declined':
      case 'cancelled':
        return AppColors.danger;
      default:
        return (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: const TrText('عقد المشروع'),
          actions: [
            IconButton(
              tooltip: 'تنزيل PDF'.tr(),
              onPressed: _downloading || _loading ? null : _downloadPdf,
              icon: _downloading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download_outlined),
            ),
          ],
        ),
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

    final contract = _data!['contract'] as Map<String, dynamic>;
    final canSign = _data!['can_sign'] == true;
    final canDecline = _data!['can_decline'] == true;
    final availableRoles = (_data!['available_roles'] as List? ?? []);
    final signatures = (contract['signatures'] as List? ?? []);
    final terms = (contract['terms_snapshot'] as List? ?? []);
    final status = contract['status']?.toString();
    final customer = contract['customer'] as Map<String, dynamic>?;
    final lead = contract['lead_engineer'] as Map<String, dynamic>?;
    final office = contract['office'] as Map<String, dynamic>?;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          trUi(contract['contract_number']?.toString() ?? ''),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(trUi(_statusLabel(status)), style: TextStyle(fontSize: 11, color: _statusColor(status))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(trUi(contract['title_snapshot']?.toString() ?? ''), style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 7),
                  Text(
                    trUi(contract['scope_snapshot']?.toString() ?? ''),
                    style: TextStyle(height: 1.55, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant)),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _metric('قيمة العقد', '${contract['agreed_price_snapshot'] ?? '-'} ${contract['currency'] ?? 'ILS'}')),
                      const SizedBox(width: 8),
                      Expanded(child: _metric('مدة التنفيذ', '${contract['duration_days_snapshot'] ?? '-'} يوم')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const TrText('الأطراف', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _partyTile('العميل', customer?['name']?.toString() ?? '-'),
                const Divider(height: 1),
                _partyTile('المهندس الرئيسي', lead?['name']?.toString() ?? '-'),
                if (office != null) ...[
                  const Divider(height: 1),
                  _partyTile('المكتب الهندسي', office['name']?.toString() ?? '-'),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const TrText('شروط العقد', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (terms.isEmpty)
            Card(child: Padding(padding: EdgeInsets.all(16), child: TrText('لا توجد شروط ظاهرة.', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant)))))
          else
            ...terms.asMap().entries.map((entry) {
              final term = entry.value as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary.withValues(alpha: .12),
                    child: Text('${entry.key + 1}', style: TextStyle(fontSize: 11, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan))),
                  ),
                  title: Text(term['title']?.toString() ?? 'بند ${entry.key + 1}'.tr()),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          trUi(term['body']?.toString() ?? ''),
                          style: TextStyle(height: 1.6, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 16),
          const TrText('التوقيعات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (signatures.isEmpty)
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: TrText('لم يتم تسجيل أي توقيع بعد.', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
              ),
            )
          else
            ...signatures.map((raw) {
              final sig = raw as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.verified_rounded, color: AppColors.success),
                  title: Text(trUi(sig['signer_name_snapshot']?.toString() ?? sig['user']?['name']?.toString() ?? '-')),
                  subtitle: Text(trUi(_roleLabel(sig['signer_role']?.toString() ?? ''))),
                  trailing: Text(
                    trUi(sig['signed_at']?.toString().split('T').first ?? ''),
                    style: TextStyle(fontSize: 10, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant)),
                  ),
                ),
              );
            }),
          if (status == 'declined' && (contract['decline_reason']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              color: AppColors.danger.withValues(alpha: .08),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TrText('سبب رفض العقد', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.danger)),
                    const SizedBox(height: 7),
                    Text(trUi(contract['decline_reason'].toString()), style: const TextStyle(height: 1.55)),
                  ],
                ),
              ),
            ),
          ],
          if (canSign) ...[
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TrText('التوقيع بصفتك: ${availableRoles.map((r) => _roleLabel(r.toString())).join('، ')}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _typedNameController,
                      decoration: InputDecoration(labelText: 'اكتب اسمك كما تريد ظهوره في التوقيع'.tr()),
                    ),
                    const SizedBox(height: 6),
                    CheckboxListTile(
                      value: _acceptedTerms,
                      onChanged: (value) => setState(() => _acceptedTerms = value ?? false),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const TrText('أقر بأنني قرأت العقد ووافقت على شروطه.', style: TextStyle(fontSize: 13)),
                    ),
                    const SizedBox(height: 6),
                    ElevatedButton.icon(
                      onPressed: _signing ? null : _sign,
                      icon: _signing
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.draw_outlined),
                      label: Text(trUi(_signing ? 'جاري التوقيع...' : 'توقيع إلكتروني')),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (canDecline) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _declining || _signing ? null : _decline,
              icon: _declining
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.cancel_outlined),
              label: Text(trUi(_declining ? 'جاري تسجيل الرفض...' : 'رفض العقد')),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: .035) : AppColors.lightPanelMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.transparent : AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(trUi(label), style: TextStyle(fontSize: 11, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
          const SizedBox(height: 3),
          Text(trUi(value), style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _partyTile(String role, String name) {
    return ListTile(
      leading: Icon(Icons.person_outline_rounded, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan)),
      title: Text(trUi(name)),
      subtitle: Text(trUi(role), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
    );
  }
}
