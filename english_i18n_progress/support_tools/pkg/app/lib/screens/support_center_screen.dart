import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../i18n/i18n.dart';
import 'account_recovery_support_screen.dart';
import 'admin_permissions_screen.dart';
import 'customer_email_center_screen.dart';
import 'support_customer_search_screen.dart';
import 'support_kyc_ai_screen.dart';
import 'support_operations_screen.dart';
import 'support_screen.dart';
import 'support_feature_screen.dart';
import 'support_trust_center_screen.dart';
import 'support_tools_screens.dart';

class SupportCenterScreen extends StatelessWidget {
  const SupportCenterScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final role = user?.role ?? '';
    final permissions = user?.permissions.toSet() ?? <String>{};
    final isAdmin = role == 'admin';

    bool can(String permission) => isAdmin || permissions.contains(permission);
    bool canAny(Iterable<String> values) =>
        isAdmin || values.any(permissions.contains);

    final tools = <_QuickTool>[
      if (can('support.dashboard.view'))
        _QuickTool(
          icon: Icons.space_dashboard_outlined,
          title: 'عمليات الدعم'.tr(),
          onTap: () => _open(context, const SupportOperationsScreen()),
        ),
      if (can('support.tickets.view'))
        _QuickTool(
          icon: Icons.support_agent_rounded,
          title: 'التذاكر'.tr(),
          onTap: () => _open(context, const SupportScreen()),
        ),
      if (canAny(['support.customers.search', 'support.customers.view']))
        _QuickTool(
          icon: Icons.person_search_rounded,
          title: 'ملف العميل'.tr(),
          onTap: () => _open(context, const SupportCustomerSearchScreen()),
        ),
      if (can('support.tickets.assign'))
        _QuickTool(
          icon: Icons.alt_route_rounded,
          title: 'التوزيع التلقائي'.tr(),
          onTap: () => _open(context, const SupportAutoAssignmentScreen()),
        ),
      if (canAny([
        'support.recovery.kyc',
        'support.recovery.review',
        'support.recovery.issue_password',
        'support.recovery.disable_2fa',
        'support.recovery',
      ]))
        _QuickTool(
          icon: Icons.manage_accounts_rounded,
          title: 'الاسترداد و KYC'.tr(),
          onTap: () => _open(context, const AccountRecoverySupportScreen()),
        ),
      if (canAny(['kyc.review', 'support.recovery.review']))
        _QuickTool(
          icon: Icons.psychology_alt_outlined,
          title: 'KYC AI Review',
          onTap: () => _open(context, const SupportKycAiScreen()),
        ),
      if (canAny([
        'support.email.send',
        'support.audit.view',
        'support.channels.manage',
      ]))
        _QuickTool(
          icon: Icons.mark_email_read_outlined,
          title: 'Email Center',
          onTap: () => _open(context, const CustomerEmailCenterScreen()),
        ),
      if (can('support.security.view'))
        _QuickTool(
          icon: Icons.devices_other_rounded,
          title: 'الأجهزة والجلسات'.tr(),
          onTap: () => _open(context, const SupportFeatureScreen(kind: SupportFeatureKind.devicesSessions)),
        ),
      if (can('support.accounts.reveal_sensitive'))
        _QuickTool(
          icon: Icons.visibility_outlined,
          title: 'البيانات الحساسة'.tr(),
          onTap: () => _open(context, const SupportFeatureScreen(kind: SupportFeatureKind.sensitiveData)),
        ),
      if (can('support.accounts.view_as'))
        _QuickTool(
          icon: Icons.preview_outlined,
          title: 'View as User',
          onTap: () => _open(context, const SupportFeatureScreen(kind: SupportFeatureKind.viewAsUser)),
        ),
      if (can('support.accounts.change_email'))
        _QuickTool(
          icon: Icons.alternate_email_rounded,
          title: 'البريد الآمن'.tr(),
          onTap: () => _open(context, const SupportFeatureScreen(kind: SupportFeatureKind.secureEmail)),
        ),
      if (canAny([
        'support.payments.request_refund',
        'support.payments.approve_refund',
      ]))
        _QuickTool(
          icon: Icons.currency_exchange_rounded,
          title: 'Refunds',
          onTap: () => _open(
            context,
            const SupportOperationsScreen(initialSection: 'refunds'),
          ),
        ),
      if (can('support.disputes.view'))
        _QuickTool(
          icon: Icons.gavel_rounded,
          title: 'النزاعات'.tr(),
          onTap: () => _open(context, const SupportFeatureScreen(kind: SupportFeatureKind.disputes)),
        ),
      if (canAny(['support.disputes.hold', 'support.disputes.release']))
        _QuickTool(
          icon: Icons.account_balance_wallet_outlined,
          title: 'تجميد المستحقات'.tr(),
          onTap: () => _open(context, const SupportFeatureScreen(kind: SupportFeatureKind.payoutHold)),
        ),
      if (can('support.security_holds.release'))
        _QuickTool(
          icon: Icons.lock_clock_outlined,
          title: 'Security Hold',
          onTap: () => _open(context, const SupportFeatureScreen(kind: SupportFeatureKind.securityHold)),
        ),
      if (can('support.reports.view'))
        _QuickTool(
          icon: Icons.verified_user_outlined,
          title: 'مركز الثقة'.tr(),
          onTap: () => _open(context, const SupportTrustCenterScreen()),
        ),
      if (can('support.approvals.review'))
        _QuickTool(
          icon: Icons.approval_outlined,
          title: 'الاعتمادات الحساسة'.tr(),
          onTap: () => _open(context, const SupportFeatureScreen(kind: SupportFeatureKind.approvals)),
        ),
      if (can('support.audit.view'))
        _QuickTool(
          icon: Icons.fact_check_outlined,
          title: 'Audit Log',
          onTap: () => _open(
            context,
            const SupportOperationsScreen(initialSection: 'audit'),
          ),
        ),
      if (can('support.moderation.recommend'))
        _QuickTool(
          icon: Icons.flag_outlined,
          title: 'التوصيات الرقابية'.tr(),
          onTap: () => _open(context, const SupportFeatureScreen(kind: SupportFeatureKind.moderation)),
        ),
      if (can('support.incidents.manage'))
        _QuickTool(
          icon: Icons.warning_amber_rounded,
          title: 'الحوادث العامة'.tr(),
          onTap: () => _open(context, const SupportFeatureScreen(kind: SupportFeatureKind.incidents)),
        ),
      if (can('support.holidays.manage'))
        _QuickTool(
          icon: Icons.schedule_rounded,
          title: 'SLA والتعطيل'.tr(),
          onTap: () => _open(context, const SupportFeatureScreen(kind: SupportFeatureKind.sla)),
        ),
      if (can('support.email.send'))
        _QuickTool(
          icon: Icons.outgoing_mail,
          title: 'بريد الدعم'.tr(),
          onTap: () => _open(context, const SupportFeatureScreen(kind: SupportFeatureKind.supportEmail)),
        ),
      if (canAny(['support.templates.use', 'support.templates']))
        _QuickTool(
          icon: Icons.article_outlined,
          title: 'القوالب'.tr(),
          onTap: () => _open(
            context,
            const SupportOperationsScreen(initialSection: 'templates'),
          ),
        ),
      if (can('support.channels.manage'))
        _QuickTool(
          icon: Icons.hub_outlined,
          title: 'Email + WhatsApp',
          onTap: () => _open(context, const SupportChannelsScreen()),
        ),
      if (can('support.files.view'))
        _QuickTool(
          icon: Icons.attach_file_rounded,
          title: 'فحص المرفقات'.tr(),
          onTap: () => _open(context, const SupportAttachmentsScreen()),
        ),
      if (canAny(['support.tickets.spam', 'support.tickets.merge']))
        _QuickTool(
          icon: Icons.block_rounded,
          title: 'Spam / Merge / Locks',
          onTap: () => _open(context, const SupportFeatureScreen(kind: SupportFeatureKind.ticketControls)),
        ),
      if (canAny([
        'support.data_requests.create',
        'support.data_requests.review',
      ]))
        _QuickTool(
          icon: Icons.privacy_tip_outlined,
          title: 'تصدير/حذف البيانات'.tr(),
          onTap: () => _open(context, const SupportFeatureScreen(kind: SupportFeatureKind.dataRequests)),
        ),
      if (can('support.reports.view'))
        _QuickTool(
          icon: Icons.repeat_rounded,
          title: 'Repeat Contact',
          onTap: () => _open(context, const SupportFeatureScreen(kind: SupportFeatureKind.repeatContact)),
        ),
      if (canAny(['support.professional.view', 'support.professional.review']))
        _QuickTool(
          icon: Icons.workspace_premium_outlined,
          title: 'الوثائق المهنية'.tr(),
          onTap: () => _open(context, const SupportFeatureScreen(kind: SupportFeatureKind.professionalDocs)),
        ),
      if (isAdmin || can('permissions.manage'))
        _QuickTool(
          icon: Icons.admin_panel_settings_outlined,
          title: 'صلاحيات الدعم'.tr(),
          onTap: () => _open(context, const AdminPermissionsScreen()),
        ),
    ];

    final supportPermissionCount = permissions
        .where((permission) =>
            permission.startsWith('support.') || permission == 'kyc.review')
        .length;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF061226) : const Color(0xFFF4F8FF),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: isDark ? const Color(0xFF061226) : const Color(0xFFF4F8FF),
          foregroundColor: isDark ? Colors.white : const Color(0xFF15243D),
          centerTitle: true,
          title: Text(
            'لوحة الدعم'.tr(),
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 90),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 15, 14, 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0A1B35) : Colors.white,
                borderRadius: BorderRadius.circular(19),
                border: Border.all(color: isDark ? const Color(0xFF16345C) : const Color(0xFFD8E4F3)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 26,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF102A50) : const Color(0xFFE9F2FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF1C467B) : const Color(0xFFC3D9F9),
                                ),
                              ),
                              child: Icon(
                                Icons.hub_rounded,
                                color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                                size: 23,
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'مركز الدعم الموحّد'.tr(),
                                    style: TextStyle(
                                      color: isDark ? Colors.white : const Color(0xFF12243F),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    isAdmin
                                        ? 'كل أدوات الدعم للمدير في لوحة مستقلة'.tr()
                                        : 'كل أدوات الدعم ظاهرة حسب صلاحية الموظف'.tr(),
                                    style: TextStyle(
                                      color: isDark ? const Color(0xFF7386A6) : const Color(0xFF53647C),
                                      fontSize: isDark ? 9.5 : 11,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_left_rounded,
                        color: isDark ? const Color(0xFF5EE7F2) : const Color(0xFF2563EB),
                        size: 22,
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0C2443) : const Color(0xFFEAF2FF),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: isDark ? const Color(0xFF173A66) : const Color(0xFFC9DCF7)),
                        ),
                        child: Text(
                          trUi(isAdmin
                              ? 'ADMIN'
                              : '$supportPermissionCount ${'صلاحية فعّالة'.tr()}'),
                          style: TextStyle(
                            color: isDark ? const Color(0xFF91A9CC) : const Color(0xFF24558F),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${tools.length} ${'أداة متاحة'.tr()}'.tr(),
                        style: TextStyle(
                          color: isDark ? const Color(0xFF5F789C) : const Color(0xFF475569),
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 7,
                    runSpacing: 7,
                    children: tools
                        .map((tool) => _QuickToolChip(tool: tool))
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: isDark ? const Color(0x99101B31) : const Color(0xFFEAF2FC),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: isDark ? const Color(0x221B365F) : const Color(0xFFCDDFF4)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    color: isDark ? const Color(0xFF6F88AC) : const Color(0xFF2563EB),
                    size: 17,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ظهور الأدوات مرتبط بنفس صلاحيات الـBackend؛ لن يظهر زر لموظف لا يملك صلاحية فتحه.'.tr(),
                      style: TextStyle(
                        color: isDark ? const Color(0xFF6F829F) : const Color(0xFF475569),
                        fontSize: isDark ? 9 : 11,
                        height: 1.55,
                      ),
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
}

class _QuickTool {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _QuickTool({
    required this.icon,
    required this.title,
    required this.onTap,
  });
}

class _QuickToolChip extends StatelessWidget {
  final _QuickTool tool;

  const _QuickToolChip({required this.tool});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: tool.onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0C203C) : const Color(0xFFF0F6FF),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: isDark ? const Color(0xFF17385F) : const Color(0xFFCBDDF5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                tool.icon,
                color: isDark ? const Color(0xFF63D7E9) : const Color(0xFF1769B7),
                size: 13.5,
              ),
              const SizedBox(width: 5),
              Text(
                tool.title.tr(),
                style: TextStyle(
                  color: isDark ? const Color(0xFFB8C8DF) : const Color(0xFF24374F),
                  fontSize: isDark ? 9 : 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
