import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'verified_name.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../screens/admin_faq_screen.dart';
import '../screens/admin_management_center_screen.dart';
import '../screens/public_support_ticket_screen.dart';
import '../screens/packages_offers_screen.dart';
import '../screens/faq_screen.dart';
import '../screens/admin_packages_offers_screen.dart';
import '../screens/account_settings_screen.dart';
import '../screens/admin_payout_accounts_screen.dart';
import '../screens/admin_platform_payment_methods_screen.dart';
import '../screens/admin_payout_queue_screen.dart';
import '../screens/admin_payments_screen.dart';
import '../screens/admin_conversation_reviews_screen.dart';
import '../screens/dispute_center_screen.dart';
import '../screens/financial_control_center_screen.dart';
import '../screens/financial_reports_screen.dart';
import '../screens/project_financial_management_screen.dart';
import '../screens/financial_manager_center_screen.dart';
import '../screens/financial_manager_feature_screen.dart';
import '../screens/invoices_screen.dart';
import '../screens/sla_center_screen.dart';
import '../screens/admin_engineering_screen.dart';
import '../screens/employees_screen.dart';
import '../screens/admin_offices_screen.dart';
import '../screens/conversations_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/engineer_library_screen.dart';
import '../screens/engineering_offices_screen.dart';
import '../screens/home_screen.dart';
import '../screens/website_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/office_application_screen.dart';
import '../screens/office_management_screen.dart';
import '../screens/office_workspace_screen.dart';
import '../screens/professional_verification_screen.dart';
import '../screens/ai_entry_screen.dart';
import '../screens/admin_ai_premium_screen.dart';
import '../screens/platform_feedback_screen.dart';
import '../screens/payout_account_screen.dart';
import '../screens/admin_feedback_screen.dart';
import '../screens/admin_moderation_screen.dart';
import '../screens/moderation_appeal_screen.dart';
import '../screens/security_center_screen.dart';
import '../screens/billing_center_screen.dart';
import '../screens/production_control_center_screen.dart';
import '../screens/admin_kyc_screen.dart';
import '../screens/account_recovery_support_screen.dart';
import '../screens/support_customer_search_screen.dart';
import '../screens/support_screen.dart';
import '../screens/support_operations_screen.dart';
import '../screens/support_trust_center_screen.dart';
import '../screens/support_center_screen.dart';
import '../screens/support_kyc_ai_screen.dart';
import '../screens/customer_email_center_screen.dart';
import '../screens/email_preferences_screen.dart';
import '../screens/admin_permissions_screen.dart';
import '../screens/admin_engineer_cloud_plans_screen.dart';
import '../screens/platform_commission_settings_screen.dart';
import '../screens/report_center_screen.dart';
import '../screens/report_archive_screen.dart';
import '../screens/alwaleed_wallet_screen.dart';
import '../screens/alwaleed_wallet_finance_screen.dart';

class AppAccountDrawer extends StatelessWidget {
  const AppAccountDrawer({super.key});

  String? _absoluteProfilePhotoUrl(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('//')) return 'https:$raw';

    var path = raw.startsWith('/') ? raw.substring(1) : raw;
    if (path.startsWith('profile-photos/')) {
      path = 'storage/$path';
    }

    return '${ApiService.siteBaseUrl}/$path';
  }

  ImageProvider? _profileImage(String? value) {
    final url = _absoluteProfilePhotoUrl(value);
    return url == null ? null : NetworkImage(url);
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }


  Future<void> _openExternal(BuildContext context, String url) async {
    Navigator.of(context).pop();
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _logout(BuildContext context) async {
    // أغلق الـDrawer فقط. الانتقال إلى شاشة الدخول مركزي في main.dart
    // عند تغيّر AuthProvider، وذلك يمنع تنفيذ pushAndRemoveUntil مرتين
    // وهو أحد أسباب أخطاء دورة حياة InheritedWidget/Provider.
    Navigator.of(context).pop();
    await context.read<AuthProvider>().logout();
  }


  Widget _buildSupportEmployeeDrawer(
    BuildContext context, {
    required String name,
    required String email,
    required ImageProvider? profileImage,
    required bool canTickets,
    required bool canCustomers,
    required bool canRecovery,
    required bool canTrust,
    required bool canAudit,
    required bool canRefunds,
    required Set<String> permissions,
  }) {
    bool supportCan(String key) => permissions.contains(key);

    return Drawer(
      width: MediaQuery.sizeOf(context).width * .88,
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Spacer(),
                      InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface.withValues(alpha: .05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.surface.withValues(alpha: .08),
                            ),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Container(
                    width: 68,
                    height: 68,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: const Color(0x334FC3F7),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x332563EB),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.architecture_rounded,
                        size: 34,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'منصة الوليد الهندسية',
                    style: TextStyle(
                      color: Color(0xFFB4C5FF),
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'نظام إدارة الدعم',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: .07),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 21,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      backgroundImage: profileImage,
                      child: profileImage == null
                          ? Text(
                              name.isEmpty ? 'د' : name.characters.first,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w900,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'موظف الدعم الفني',
                            style: TextStyle(
                              color: Color(0xFF0E7490),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (email.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4ADE80),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                children: [
                  const _SupportSectionLabel('مركز الدعم الموحّد'),
                  _SupportMenuTile(
                    icon: Icons.hub_rounded,
                    title: 'مركز الدعم الموحّد',
                    highlighted: true,
                    cyan: true,
                    onTap: () => _open(context, const SupportCenterScreen()),
                  ),
                  _SupportMenuTile(
                    icon: Icons.dashboard_outlined,
                    title: 'لوحة التحكم',
                    onTap: () => _open(context, const DashboardScreen()),
                  ),
                  _SupportMenuTile(
                    icon: Icons.public_rounded,
                    title: 'كل صفحات الموقع',
                    onTap: () => _open(context, const WebsiteScreen()),
                  ),

                  const _SupportSectionLabel('العمليات اليومية'),
                  if (supportCan('support.dashboard.view'))
                    _SupportMenuTile(
                      icon: Icons.space_dashboard_outlined,
                      title: 'مركز عمليات الدعم',
                      onTap: () => _open(context, const SupportOperationsScreen()),
                    ),
                  if (canTickets || supportCan('support.tickets.view'))
                    _SupportMenuTile(
                      icon: Icons.support_agent_rounded,
                      title: 'إدارة تذاكر الدعم',
                      onTap: () => _open(context, const SupportScreen()),
                    ),
                  if (canCustomers || supportCan('support.customers.search') || supportCan('support.customers.view'))
                    _SupportMenuTile(
                      icon: Icons.person_search_rounded,
                      title: 'ملف العميل الكامل',
                      onTap: () => _open(context, const SupportCustomerSearchScreen()),
                    ),
                  if (supportCan('support.tickets.assign'))
                    _SupportMenuTile(
                      icon: Icons.alt_route_rounded,
                      title: 'التوزيع التلقائي والسعة',
                      onTap: () => _open(context, const SupportOperationsScreen()),
                    ),
                  if (supportCan('support.tickets.escalate'))
                    _SupportMenuTile(
                      icon: Icons.trending_up_rounded,
                      title: 'التصعيدات والأولوية',
                      onTap: () => _open(context, const SupportScreen()),
                    ),

                  const _SupportSectionLabel('الحساب والأمان'),
                  if (canRecovery || supportCan('support.recovery.kyc') || supportCan('support.recovery.review'))
                    _SupportMenuTile(
                      icon: Icons.manage_accounts_rounded,
                      title: 'استرداد الحساب و KYC',
                      cyan: true,
                      onTap: () => _open(context, const AccountRecoverySupportScreen()),
                    ),
                  if (supportCan('kyc.review') || supportCan('support.recovery.review'))
                    _SupportMenuTile(
                      icon: Icons.psychology_alt_outlined,
                      title: 'طابور KYC AI',
                      cyan: true,
                      onTap: () => _open(context, const SupportKycAiScreen()),
                    ),
                  if (supportCan('support.security.view'))
                    _SupportMenuTile(
                      icon: Icons.security_rounded,
                      title: 'الأجهزة والجلسات والأمان',
                      onTap: () => _open(context, const SupportOperationsScreen(initialSection: 'security')),
                    ),
                  if (supportCan('support.accounts.reveal_sensitive'))
                    _SupportMenuTile(
                      icon: Icons.visibility_outlined,
                      title: 'كشف البيانات الحساسة',
                      onTap: () => _open(context, const SupportCustomerSearchScreen()),
                    ),
                  if (supportCan('support.accounts.view_as'))
                    _SupportMenuTile(
                      icon: Icons.preview_outlined,
                      title: 'View as User',
                      onTap: () => _open(context, const SupportCustomerSearchScreen()),
                    ),
                  if (supportCan('support.accounts.change_email'))
                    _SupportMenuTile(
                      icon: Icons.alternate_email_rounded,
                      title: 'تغيير البريد الآمن',
                      onTap: () => _open(context, const SupportCustomerSearchScreen()),
                    ),
                  if (supportCan('support.accounts.revoke_sessions'))
                    _SupportMenuTile(
                      icon: Icons.phonelink_erase_rounded,
                      title: 'إنهاء الجلسات والأجهزة',
                      onTap: () => _open(context, const SupportOperationsScreen(initialSection: 'security')),
                    ),

                  const _SupportSectionLabel('المالية والثقة'),
                  if (canRefunds || supportCan('support.payments.request_refund') || supportCan('support.payments.approve_refund'))
                    _SupportMenuTile(
                      icon: Icons.currency_exchange_rounded,
                      title: 'طلبات الاسترداد المالي',
                      onTap: () => _open(context, const SupportOperationsScreen(initialSection: 'refunds')),
                    ),
                  if (supportCan('support.disputes.view'))
                    _SupportMenuTile(
                      icon: Icons.gavel_rounded,
                      title: 'النزاعات وتجميد المستحقات',
                      onTap: () => _open(context, const SupportTrustCenterScreen()),
                    ),
                  if (supportCan('support.security_holds.release'))
                    _SupportMenuTile(
                      icon: Icons.lock_clock_outlined,
                      title: 'Security Hold للصرف',
                      onTap: () => _open(context, const SupportTrustCenterScreen()),
                    ),
                  if (canTrust || supportCan('support.reports.view'))
                    _SupportMenuTile(
                      icon: Icons.verified_user_outlined,
                      title: 'مركز الثقة والتشغيل',
                      cyan: true,
                      onTap: () => _open(context, const SupportTrustCenterScreen()),
                    ),

                  const _SupportSectionLabel('الإشراف والتدقيق'),
                  if (supportCan('support.approvals.review'))
                    _SupportMenuTile(
                      icon: Icons.approval_outlined,
                      title: 'اعتمادات الإجراءات الحساسة',
                      onTap: () => _open(context, const SupportOperationsScreen()),
                    ),
                  if (canAudit || supportCan('support.audit.view'))
                    _SupportMenuTile(
                      icon: Icons.fact_check_outlined,
                      title: 'سجل التدقيق Audit Log',
                      onTap: () => _open(context, const SupportOperationsScreen(initialSection: 'audit')),
                    ),
                  if (supportCan('support.moderation.recommend'))
                    _SupportMenuTile(
                      icon: Icons.flag_outlined,
                      title: 'التوصيات الرقابية',
                      onTap: () => _open(context, const SupportOperationsScreen()),
                    ),
                  if (supportCan('support.incidents.manage'))
                    _SupportMenuTile(
                      icon: Icons.warning_amber_rounded,
                      title: 'إدارة الحوادث العامة',
                      onTap: () => _open(context, const SupportTrustCenterScreen()),
                    ),
                  if (supportCan('support.holidays.manage'))
                    _SupportMenuTile(
                      icon: Icons.schedule_rounded,
                      title: 'SLA وساعات العمل والعطل',
                      onTap: () => _open(context, const SupportTrustCenterScreen()),
                    ),

                  const _SupportSectionLabel('التواصل والقنوات'),
                  if (supportCan('support.email.send'))
                    _SupportMenuTile(
                      icon: Icons.outgoing_mail,
                      title: 'البريد الصادر من الدعم',
                      onTap: () => _open(context, const SupportCustomerSearchScreen()),
                    ),
                  if (supportCan('support.email.send') || supportCan('support.audit.view') || supportCan('support.channels.manage'))
                    _SupportMenuTile(
                      icon: Icons.mark_email_read_outlined,
                      title: 'مركز إيميلات العميل',
                      cyan: true,
                      onTap: () => _open(context, const CustomerEmailCenterScreen()),
                    ),
                  if (supportCan('support.templates.use') || supportCan('support.templates'))
                    _SupportMenuTile(
                      icon: Icons.article_outlined,
                      title: 'قوالب الدعم',
                      onTap: () => _open(context, const SupportOperationsScreen(initialSection: 'templates')),
                    ),
                  if (supportCan('support.channels.manage'))
                    _SupportMenuTile(
                      icon: Icons.hub_outlined,
                      title: 'Inbound Email + WhatsApp',
                      onTap: () => _open(context, const SupportOperationsScreen(initialSection: 'templates')),
                    ),
                  if (supportCan('support.files.view'))
                    _SupportMenuTile(
                      icon: Icons.attach_file_rounded,
                      title: 'أمان وفحص المرفقات',
                      onTap: () => _open(context, const SupportScreen()),
                    ),
                  if (supportCan('support.tickets.spam') || supportCan('support.tickets.merge'))
                    _SupportMenuTile(
                      icon: Icons.block_rounded,
                      title: 'Spam / Abuse / Merge / Locks',
                      onTap: () => _open(context, const SupportScreen()),
                    ),

                  const _SupportSectionLabel('الخصوصية والتقارير'),
                  if (supportCan('support.data_requests.create') || supportCan('support.data_requests.review'))
                    _SupportMenuTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'طلبات تصدير/حذف البيانات',
                      onTap: () => _open(context, const SupportTrustCenterScreen()),
                    ),
                  if (supportCan('support.reports.view'))
                    _SupportMenuTile(
                      icon: Icons.repeat_rounded,
                      title: 'Repeat Contact Rate',
                      onTap: () => _open(context, const SupportTrustCenterScreen()),
                    ),
                  if (supportCan('support.professional.view'))
                    _SupportMenuTile(
                      icon: Icons.workspace_premium_outlined,
                      title: 'الوثائق المهنية والتنبيهات',
                      onTap: () => _open(context, const SupportTrustCenterScreen()),
                    ),
                  const _SupportSectionLabel('خدمات المنصة'),
                  _SupportMenuTile(
                    icon: Icons.workspace_premium_rounded,
                    title: 'الباقات والعروض',
                    onTap: () => _open(
                      context,
                      const PackagesOffersScreen(),
                    ),
                  ),
                  _SupportMenuTile(
                    icon: Icons.help_outline_rounded,
                    title: 'الأسئلة الشائعة',
                    onTap: () => _open(
                      context,
                      const FaqScreen(),
                    ),
                  ),
                  _SupportMenuTile(
                    icon: Icons.confirmation_number_outlined,
                    title: 'متابعة تذكرة برقمها',
                    onTap: () => _open(
                      context,
                      const PublicSupportTicketScreen(),
                    ),
                  ),
                  const _SupportSectionLabel('حسابي'),
                  _SupportMenuTile(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'المحفظة المالية',
                    onTap: () => _open(context, const AlwaleedWalletScreen()),
                  ),
                  _SupportMenuTile(
                    icon: Icons.email_outlined,
                    title: 'تفضيلات البريد',
                    onTap: () => _open(context, const EmailPreferencesScreen()),
                  ),
                  _SupportMenuTile(
                    icon: Icons.settings_outlined,
                    title: 'الإعدادات',
                    onTap: () => _open(
                      context,
                      const AccountSettingsScreen(),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _logout(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB91C1C),
                    side: const BorderSide(
                      color: Color(0x55EF4444),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(
                    Icons.logout_rounded,
                    size: 18,
                  ),
                  label: const Text(
                    'تسجيل الخروج',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final role = user?.role ?? '';
    final permissions = user?.permissions.toSet() ?? <String>{};
    bool can(String key) => role == 'admin' || permissions.contains(key);
    final profileImage = _profileImage(user?.profilePhoto);

    final isSupportEmployee =
        role == 'employee' &&
        (permissions.any((permission) => permission.startsWith('support.')) ||
            user?.canRecoverAccounts == true);

    if (isSupportEmployee) {
      return _buildSupportEmployeeDrawer(
        context,
        name: user?.name ?? '',
        email: user?.email ?? '',
        profileImage: profileImage,
        canTickets:
            permissions.contains('support.tickets') ||
            permissions.contains('support.tickets.view') ||
            permissions.contains('support.customers') ||
            permissions.contains('support.customers.view') ||
            permissions.contains('support.recovery') ||
            permissions.contains('support.recovery.review'),
        canCustomers: permissions.contains('support.customers') || permissions.contains('support.customers.search') || permissions.contains('support.customers.view'),
        canRecovery:
            permissions.contains('support.recovery') ||
            permissions.contains('support.recovery.kyc') ||
            permissions.contains('support.recovery.review') ||
            user?.canRecoverAccounts == true,
        canTrust: permissions.contains('support.reports.view'),
        canAudit: permissions.contains('support.audit.view'),
        canRefunds:
            permissions.contains('support.payments.request_refund') ||
            permissions.contains('support.payments.approve_refund'),
        permissions: permissions,
      );
    }

    return Drawer(
      width: MediaQuery.sizeOf(context).width * .92,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0x334FC3F7)),
                    ),
                    child: const Icon(Icons.architecture_rounded, color: Color(0xFF0E7490)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('منصة الوليد الهندسية', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                        SizedBox(height: 2),
                        Text('منصة الاستشارات الهندسية', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10)),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Icon(Icons.close_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      backgroundImage: profileImage,
                      child: profileImage == null
                          ? const Icon(Icons.person_rounded)
                          : null,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          VerifiedName(
                            name: user?.name ?? '',
                            verified: user?.professionalVerified == true,
                            iconSize: 16,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 3),
                          Text(user?.email ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10)),
                        ],
                      ),
                    ),
                    Container(width: 9, height: 9, decoration: const BoxDecoration(color: Color(0xFF4ADE80), shape: BoxShape.circle)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                children: [
                  _DrawerDropdown(
                    title: 'القائمة الرئيسية',
                    icon: Icons.grid_view_rounded,
                    initiallyExpanded: true,
                    children: [
                  _DrawerTile(icon: Icons.language_rounded, title: 'الصفحة الرئيسية', onTap: () => _open(context, const HomeScreen())),
                  _DrawerTile(icon: Icons.public_rounded, title: 'كل صفحات الموقع', highlighted: true, onTap: () => _open(context, const WebsiteScreen())),
                  _DrawerTile(
                    icon: Icons.auto_awesome_rounded,
                    title: 'المساعد الذكي',
                    highlighted: true,
                    onTap: () => _open(
                      context,
                      const AiEntryScreen(
                        sourceRoute: 'flutter_side_menu_assistant',
                        sourceTitle: 'المساعد الذكي من القائمة الجانبية',
                      ),
                    ),
                  ),
                  _DrawerTile(icon: Icons.photo_library_outlined, title: 'مكتبة الأعمال', onTap: () => _open(context, const EngineerLibraryScreen())),
                  _DrawerTile(icon: Icons.apartment_rounded, title: 'دليل المكاتب الهندسية', onTap: () => _open(context, const EngineeringOfficesScreen())),
                  _DrawerTile(icon: Icons.chat_bubble_outline_rounded, title: 'الآراء والملاحظات', onTap: () => _open(context, const PlatformFeedbackScreen())),
                  _DrawerTile(icon: Icons.workspace_premium_rounded, title: 'الباقات والعروض', highlighted: true, onTap: () => _open(context, const PackagesOffersScreen())),
                  _DrawerTile(icon: Icons.account_balance_wallet_outlined, title: 'المحفظة المالية', onTap: () => _open(context, const AlwaleedWalletScreen())),
                  if (role == 'admin' || role == 'financial_manager') _DrawerTile(icon: Icons.receipt_long_outlined, title: 'مراجعة المحفظة المالية', onTap: () => _open(context, const AlwaleedWalletFinanceScreen())),
                  _DrawerTile(icon: Icons.help_outline_rounded, title: 'الأسئلة الشائعة', onTap: () => _open(context, const FaqScreen())),
                  _DrawerTile(icon: Icons.confirmation_number_outlined, title: 'متابعة تذكرة برقمها', onTap: () => _open(context, const PublicSupportTicketScreen())),
                  if (role == 'customer' || role == 'engineer')
                    _DrawerTile(icon: Icons.add_business_rounded, title: 'تسجيل مكتب هندسي', onTap: () => _open(context, const OfficeApplicationScreen())),
                  if (role == 'engineer' || role == 'office_owner')
                    _DrawerTile(icon: Icons.verified_rounded, title: 'طلب توثيق الحساب', onTap: () => _open(context, const ProfessionalVerificationScreen())),
                  if (role == 'engineer')
                    _DrawerTile(icon: Icons.account_balance_rounded, title: 'حساب استلام المستحقات', highlighted: true, onTap: () => _open(context, const PayoutAccountScreen())),
                  if (role == 'office_owner')
                    _DrawerTile(icon: Icons.account_balance_rounded, title: 'حساب المكتب البنكي', highlighted: true, onTap: () => _open(context, const PayoutAccountScreen(officeAccount: true))),
                  if (role == 'office_owner')
                    _DrawerTile(icon: Icons.admin_panel_settings_rounded, title: 'إدارة صفحة المكتب', onTap: () => _open(context, const OfficeManagementScreen())),
                  _OfficeWorkspaceDrawerEntry(
                    role: role,
                    onTap: () => _open(context, const OfficeWorkspaceScreen()),
                  ),
                    ],
                  ),
                  if (role == 'admin') ...[
                    _DrawerDropdown(
                      title: 'الإدارة الشاملة',
                      icon: Icons.hub_rounded,
                      children: [
                    _DrawerTile(icon: Icons.hub_rounded, title: 'مركز الإدارة الشامل', highlighted: true, onTap: () => _open(context, const AdminManagementCenterScreen())),
                    _DrawerTile(icon: Icons.dashboard_outlined, title: 'لوحة التحكم', onTap: () => Navigator.of(context).pop()),
                      ],
                    ),
_DrawerDropdown(
                      title: 'الإدارة الأساسية',
                      icon: Icons.admin_panel_settings_outlined,
                      children: [
                    _DrawerTile(icon: Icons.group_add_outlined, title: 'إدارة المستخدمين والموظفين', onTap: () => _open(context, const EmployeesScreen())),
                    _DrawerTile(icon: Icons.admin_panel_settings_outlined, title: 'الإدارة الهندسية', onTap: () => _open(context, const AdminEngineeringScreen())),
                    _DrawerTile(icon: Icons.apartment_rounded, title: 'إدارة المكاتب', onTap: () => _open(context, const AdminOfficesScreen())),
                      ],
                    ),
_DrawerDropdown(
                      title: 'المالية',
                      icon: Icons.account_balance_wallet_outlined,
                      children: [
                    _DrawerTile(icon: Icons.account_balance_rounded, title: 'المركز المالي', highlighted: true, onTap: () => _open(context, const FinancialManagerCenterScreen())),
                    _DrawerTile(icon: Icons.payments_outlined, title: 'المدفوعات', onTap: () => _open(context, const AdminPaymentsScreen())),
                    _DrawerTile(icon: Icons.currency_exchange_rounded, title: 'الاستردادات والرقابة المالية', onTap: () => _open(context, const FinancialControlCenterScreen())),
                    _DrawerTile(icon: Icons.outbox_rounded, title: 'المستحقات الجاهزة للصرف', onTap: () => _open(context, const AdminPayoutQueueScreen())),
                    _DrawerTile(icon: Icons.account_balance_outlined, title: 'مراجعة الحسابات البنكية', onTap: () => _open(context, const AdminPayoutAccountsScreen())),
                    _DrawerTile(icon: Icons.credit_card_outlined, title: 'طرق دفع المنصة', onTap: () => _open(context, const AdminPlatformPaymentMethodsScreen())),
                    _DrawerTile(icon: Icons.percent_rounded, title: 'مالية المشاريع والعمولات', onTap: () => _open(context, const ProjectFinancialManagementScreen())),
                    _DrawerTile(icon: Icons.analytics_outlined, title: 'التقارير المالية', onTap: () => _open(context, const FinancialReportsScreen())),
                    _DrawerTile(icon: Icons.insights_rounded, title: 'مركز التقارير', highlighted: true, onTap: () => _open(context, const ReportCenterScreen())),
                    _DrawerTile(icon: Icons.archive_outlined, title: 'الأرشيف', onTap: () => _open(context, const ReportArchiveScreen())),
                    _DrawerTile(icon: Icons.gavel_outlined, title: 'مركز النزاعات', onTap: () => _open(context, const DisputeCenterScreen())),
                    _DrawerTile(icon: Icons.timer_outlined, title: 'مركز المتابعة و SLA', onTap: () => _open(context, const SlaCenterScreen())),
                      ],
                    ),
_DrawerDropdown(
                      title: 'الدعم والثقة',
                      icon: Icons.support_agent_rounded,
                      children: [
                    _DrawerTile(icon: Icons.hub_outlined, title: 'مركز الدعم الموحّد', highlighted: true, onTap: () => _open(context, const SupportCenterScreen())),
                    _DrawerTile(icon: Icons.space_dashboard_outlined, title: 'مركز عمليات الدعم', onTap: () => _open(context, const SupportOperationsScreen())),
                    _DrawerTile(icon: Icons.support_agent_rounded, title: 'تذاكر الدعم', onTap: () => _open(context, const SupportScreen())),
                    _DrawerTile(icon: Icons.person_search_rounded, title: 'ملف العميل والبحث', onTap: () => _open(context, const SupportCustomerSearchScreen())),
                    _DrawerTile(icon: Icons.manage_accounts_rounded, title: 'استرداد الحساب و KYC', onTap: () => _open(context, const AccountRecoverySupportScreen())),
                    _DrawerTile(icon: Icons.psychology_alt_outlined, title: 'KYC AI Review', onTap: () => _open(context, const SupportKycAiScreen())),
                    _DrawerTile(icon: Icons.mark_email_read_outlined, title: 'Email Center', onTap: () => _open(context, const CustomerEmailCenterScreen())),
                    _DrawerTile(icon: Icons.verified_user_outlined, title: 'مركز الثقة', onTap: () => _open(context, const SupportTrustCenterScreen())),
                    _DrawerTile(icon: Icons.manage_search_outlined, title: 'مراجعة المحادثات', onTap: () => _open(context, const AdminConversationReviewsScreen())),
                      ],
                    ),
_DrawerDropdown(
                      title: 'الحوكمة والمنصة',
                      icon: Icons.security_outlined,
                      children: [
                    _DrawerTile(icon: Icons.badge_outlined, title: 'مراجعة KYC', onTap: () => _open(context, const AdminKycScreen())),
                    _DrawerTile(icon: Icons.key_rounded, title: 'المسميات والصلاحيات', onTap: () => _open(context, const AdminPermissionsScreen())),
                    _DrawerTile(icon: Icons.shield_outlined, title: 'الإشراف والمراجعة', onTap: () => _open(context, const AdminModerationScreen())),
                    _DrawerTile(icon: Icons.local_offer_outlined, title: 'إدارة الباقات والعروض', onTap: () => _open(context, const AdminPackagesOffersScreen())),
                    _DrawerTile(icon: Icons.cloud_sync_outlined, title: 'طلبات باقات المهندسين', onTap: () => _open(context, const AdminEngineerCloudPlansScreen())),
                    _DrawerTile(icon: Icons.psychology_alt_rounded, title: 'AI Premium', onTap: () => _open(context, const AdminAiPremiumScreen())),
                    _DrawerTile(icon: Icons.reviews_outlined, title: 'إدارة الآراء والملاحظات', onTap: () => _open(context, const AdminFeedbackScreen())),
                    _DrawerTile(icon: Icons.menu_book_outlined, title: 'إدارة الأسئلة الشائعة', onTap: () => _open(context, const AdminFaqScreen())),
                    _DrawerTile(icon: Icons.rocket_launch_rounded, title: 'جاهزية الإنتاج', onTap: () => _open(context, const ProductionControlCenterScreen())),
                      ],
                    ),
                  ],                  if (role == 'financial_manager') ...[
                    _DrawerDropdown(
                      title: 'المركز المالي',
                      icon: Icons.account_balance_rounded,
                      initiallyExpanded: true,
                      children: [
                    _DrawerTile(icon: Icons.account_balance_rounded, title: 'المركز المالي', highlighted: true, onTap: () => _open(context, const FinancialManagerCenterScreen())),
                    _DrawerTile(icon: Icons.payments_outlined, title: 'المدفوعات', onTap: () => _open(context, const AdminPaymentsScreen())),
                    _DrawerTile(icon: Icons.receipt_long_outlined, title: 'الفواتير', onTap: () => _open(context, const InvoicesScreen())),
                    _DrawerTile(icon: Icons.currency_exchange_rounded, title: 'الاستردادات والرقابة المالية', onTap: () => _open(context, const FinancialControlCenterScreen())),
                    _DrawerTile(icon: Icons.outbox_rounded, title: 'مستحقات المهندسين والمكاتب', onTap: () => _open(context, const AdminPayoutQueueScreen())),
                    _DrawerTile(icon: Icons.account_balance_outlined, title: 'بيانات التحويل البنكي', onTap: () => _open(context, const FinancialManagerFeatureScreen(feature:'payout-accounts',title:'بيانات التحويل البنكي'))),
                    _DrawerTile(icon: Icons.lock_clock_outlined, title: 'Security / Payout Hold', onTap: () => _open(context, const FinancialManagerFeatureScreen(feature:'security-holds',title:'Security / Payout Hold'))),
                    _DrawerTile(icon: Icons.gavel_outlined, title: 'النزاعات المالية', onTap: () => _open(context, const DisputeCenterScreen())),
                    _DrawerTile(icon: Icons.workspace_premium_outlined, title: 'اشتراكات المنصة', onTap: () => _open(context, const FinancialManagerFeatureScreen(feature:'subscriptions',title:'اشتراكات المنصة'))),
                    _DrawerTile(icon: Icons.local_offer_outlined, title: 'الكوبونات والعروض', onTap: () => _open(context, const FinancialManagerFeatureScreen(feature:'coupons',title:'الكوبونات والعروض'))),
                    _DrawerTile(icon: Icons.percent_rounded, title: 'عمولات المنصة', onTap: () => _open(context, const ProjectFinancialManagementScreen())),
                    _DrawerTile(icon: Icons.analytics_outlined, title: 'التقارير المالية', onTap: () => _open(context, const FinancialReportsScreen())),
                    _DrawerTile(icon: Icons.insights_rounded, title: 'مركز التقارير', highlighted: true, onTap: () => _open(context, const ReportCenterScreen())),
                    _DrawerTile(icon: Icons.archive_outlined, title: 'الأرشيف', onTap: () => _open(context, const ReportArchiveScreen())),
                    _DrawerTile(icon: Icons.fact_check_outlined, title: 'سجل التدقيق المالي', onTap: () => _open(context, const FinancialManagerFeatureScreen(feature:'audit',title:'سجل التدقيق المالي'))),
                    _DrawerTile(icon: Icons.notifications_active_outlined, title: 'التنبيهات المالية', onTap: () => _open(context, const FinancialManagerFeatureScreen(feature:'alerts',title:'التنبيهات المالية'))),
                      ],
                    ),
                  ],                  if (role != 'admin' && role != 'financial_manager' && permissions.any((permission) => permission.startsWith('support.'))) ...[
                    _DrawerDropdown(
                      title: 'مركز الدعم الموحّد',
                      icon: Icons.support_agent_rounded,
                      initiallyExpanded: true,
                      children: [
                    _DrawerTile(icon: Icons.hub_rounded, title: 'مركز الدعم الموحّد', highlighted: true, onTap: () => _open(context, const SupportCenterScreen())),
                    if (can('support.dashboard.view'))
                      _DrawerTile(icon: Icons.space_dashboard_outlined, title: 'مركز عمليات الدعم', onTap: () => _open(context, const SupportOperationsScreen())),
                    if (can('support.tickets.view'))
                      _DrawerTile(icon: Icons.support_agent_rounded, title: 'إدارة تذاكر الدعم', onTap: () => _open(context, const SupportScreen())),
                    if (can('support.customers.search') || can('support.customers.view'))
                      _DrawerTile(icon: Icons.person_search_rounded, title: 'ملف العميل الكامل', onTap: () => _open(context, const SupportCustomerSearchScreen())),
                    if (can('support.recovery.kyc') || can('support.recovery.review'))
                      _DrawerTile(icon: Icons.manage_accounts_rounded, title: 'استرداد الحساب و KYC', onTap: () => _open(context, const AccountRecoverySupportScreen())),
                    if (can('kyc.review') || can('support.recovery.review'))
                      _DrawerTile(icon: Icons.psychology_alt_outlined, title: 'طابور KYC AI', onTap: () => _open(context, const SupportKycAiScreen())),
                    if (can('support.security.view'))
                      _DrawerTile(icon: Icons.security_rounded, title: 'الأجهزة والجلسات والأمان', onTap: () => _open(context, const SupportOperationsScreen(initialSection: 'security'))),
                    if (can('support.accounts.reveal_sensitive'))
                      _DrawerTile(icon: Icons.visibility_outlined, title: 'كشف البيانات الحساسة', onTap: () => _open(context, const SupportCustomerSearchScreen())),
                    if (can('support.accounts.view_as'))
                      _DrawerTile(icon: Icons.preview_outlined, title: 'View as User', onTap: () => _open(context, const SupportCustomerSearchScreen())),
                    if (can('support.accounts.change_email'))
                      _DrawerTile(icon: Icons.alternate_email_rounded, title: 'تغيير البريد الآمن', onTap: () => _open(context, const SupportCustomerSearchScreen())),
                    if (can('support.payments.request_refund') || can('support.payments.approve_refund'))
                      _DrawerTile(icon: Icons.currency_exchange_rounded, title: 'طلبات الاسترداد المالي', onTap: () => _open(context, const SupportOperationsScreen(initialSection: 'refunds'))),
                    if (can('support.disputes.view'))
                      _DrawerTile(icon: Icons.gavel_rounded, title: 'النزاعات وتجميد المستحقات', onTap: () => _open(context, const SupportTrustCenterScreen())),
                    if (can('support.security_holds.release'))
                      _DrawerTile(icon: Icons.lock_clock_outlined, title: 'Security Hold للصرف', onTap: () => _open(context, const SupportTrustCenterScreen())),
                    if (can('support.reports.view'))
                      _DrawerTile(icon: Icons.verified_user_outlined, title: 'مركز الثقة والتشغيل', onTap: () => _open(context, const SupportTrustCenterScreen())),
                    if (can('support.reports.view'))
                      _DrawerTile(icon: Icons.analytics_rounded, title: 'تقارير الدعم', onTap: () => _open(context, const ReportCenterScreen())),
                    if (can('support.reports.view'))
                      _DrawerTile(icon: Icons.archive_outlined, title: 'أرشيف الدعم', onTap: () => _open(context, const ReportArchiveScreen())),
                    if (can('support.approvals.review'))
                      _DrawerTile(icon: Icons.approval_outlined, title: 'اعتمادات الإجراءات الحساسة', onTap: () => _open(context, const SupportOperationsScreen())),
                    if (can('support.audit.view'))
                      _DrawerTile(icon: Icons.fact_check_outlined, title: 'Audit Log', onTap: () => _open(context, const SupportOperationsScreen(initialSection: 'audit'))),
                    if (can('support.moderation.recommend'))
                      _DrawerTile(icon: Icons.flag_outlined, title: 'التوصيات الرقابية', onTap: () => _open(context, const SupportOperationsScreen())),
                    if (can('support.incidents.manage'))
                      _DrawerTile(icon: Icons.warning_amber_rounded, title: 'إدارة الحوادث العامة', onTap: () => _open(context, const SupportTrustCenterScreen())),
                    if (can('support.holidays.manage'))
                      _DrawerTile(icon: Icons.schedule_rounded, title: 'SLA وساعات العمل والعطل', onTap: () => _open(context, const SupportTrustCenterScreen())),
                    if (can('support.email.send'))
                      _DrawerTile(icon: Icons.outgoing_mail, title: 'البريد الصادر من الدعم', onTap: () => _open(context, const SupportCustomerSearchScreen())),
                    if (can('support.email.send') || can('support.audit.view') || can('support.channels.manage'))
                      _DrawerTile(icon: Icons.mark_email_read_outlined, title: 'مركز إيميلات العميل', onTap: () => _open(context, const CustomerEmailCenterScreen())),
                    if (can('support.templates.use'))
                      _DrawerTile(icon: Icons.article_outlined, title: 'قوالب الدعم', onTap: () => _open(context, const SupportOperationsScreen(initialSection: 'templates'))),
                    if (can('support.channels.manage'))
                      _DrawerTile(icon: Icons.hub_outlined, title: 'Inbound Email + WhatsApp', onTap: () => _open(context, const SupportOperationsScreen(initialSection: 'templates'))),
                    if (can('support.files.view'))
                      _DrawerTile(icon: Icons.attach_file_rounded, title: 'أمان وفحص المرفقات', onTap: () => _open(context, const SupportScreen())),
                    if (can('support.tickets.spam') || can('support.tickets.merge'))
                      _DrawerTile(icon: Icons.block_rounded, title: 'Spam / Abuse / Merge / Locks', onTap: () => _open(context, const SupportScreen())),
                    if (can('support.data_requests.create') || can('support.data_requests.review'))
                      _DrawerTile(icon: Icons.privacy_tip_outlined, title: 'طلبات تصدير/حذف البيانات', onTap: () => _open(context, const SupportTrustCenterScreen())),
                    if (can('support.reports.view'))
                      _DrawerTile(icon: Icons.repeat_rounded, title: 'Repeat Contact Rate', onTap: () => _open(context, const SupportTrustCenterScreen())),
                    if (can('support.professional.view'))
                      _DrawerTile(icon: Icons.workspace_premium_outlined, title: 'الوثائق المهنية والتنبيهات', onTap: () => _open(context, const SupportTrustCenterScreen())),
                      ],
                    ),
                  ],
                  if (role != 'admin' && role != 'financial_manager') _DrawerTile(icon: Icons.gavel_rounded, title: 'النزاعات', highlighted: true, onTap: () => _open(context, const DisputeCenterScreen())),
                  if (role != 'admin' && role != 'financial_manager') _DrawerTile(icon: Icons.timer_outlined, title: 'المتابعة و SLA', highlighted: true, onTap: () => _open(context, const SlaCenterScreen())),
                  _DrawerDropdown(
                    title: 'حسابي',
                    icon: Icons.manage_accounts_rounded,
                    initiallyExpanded: true,
                    children: [
                  _DrawerTile(icon: Icons.receipt_long_rounded, title: 'الفواتير وكشف الحساب', onTap: () => _open(context, const BillingCenterScreen())),
                  _DrawerTile(icon: Icons.security_rounded, title: 'مركز الأمان والجلسات', onTap: () => _open(context, const SecurityCenterScreen())),
                  _DrawerTile(icon: Icons.email_outlined, title: 'تفضيلات البريد', onTap: () => _open(context, const EmailPreferencesScreen())),
                  _DrawerTile(icon: Icons.manage_accounts_rounded, title: 'إعدادات الحساب', onTap: () => _open(context, const AccountSettingsScreen())),
                  _DrawerTile(icon: Icons.gavel_outlined, title: 'حالة الحساب والطعن', onTap: () => _open(context, const ModerationAppealScreen())),
                  _DrawerTile(icon: Icons.notifications_active_outlined, title: 'الإشعارات', onTap: () => _open(context, const NotificationsScreen())),
                  _DrawerTile(icon: Icons.forum_outlined, title: 'المحادثات', onTap: () => _open(context, const ConversationsScreen())),
                  _DrawerTile(icon: Icons.privacy_tip_outlined, title: 'سياسة الخصوصية', onTap: () => _openExternal(context, 'https://alwaleedoffice.com/privacy-policy')),
                  _DrawerTile(icon: Icons.menu_book_outlined, title: 'شروط الاستخدام', onTap: () => _openExternal(context, 'https://alwaleedoffice.com/terms-and-conditions')),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _logout(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB91C1C),
                    side: const BorderSide(color: Color(0x55EF4444)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('تسجيل الخروج', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfficeWorkspaceDrawerEntry extends StatefulWidget {
  final String role;
  final VoidCallback onTap;

  const _OfficeWorkspaceDrawerEntry({
    required this.role,
    required this.onTap,
  });

  @override
  State<_OfficeWorkspaceDrawerEntry> createState() =>
      _OfficeWorkspaceDrawerEntryState();
}

class _OfficeWorkspaceDrawerEntryState
    extends State<_OfficeWorkspaceDrawerEntry> {
  late final Future<bool> _visibility;

  @override
  void initState() {
    super.initState();
    _visibility = _canSeeWorkspace();
  }

  Future<bool> _canSeeWorkspace() async {
    // توافق فوري مع الحسابات القديمة، مع الاعتماد الأساسي على عضوية المكتب
    // حتى يظهر الرابط لأي مستخدم يملك عضوية فعلية مهما كان global role.
    final roleFallback = widget.role == 'office_owner';

    try {
      final data = await ApiService.fetchOfficeContext();
      final offices = List<dynamic>.from(data['offices'] as List? ?? const []);
      return roleFallback && offices.isNotEmpty;
    } catch (_) {
      return roleFallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _visibility,
      builder: (context, snapshot) {
        if (snapshot.data != true) return const SizedBox.shrink();
        return _DrawerTile(
          icon: Icons.workspace_premium_rounded,
          title: 'الباقة والاشتراك',
          highlighted: true,
          onTap: widget.onTap,
        );
      },
    );
  }
}


class _SupportSectionLabel extends StatelessWidget {
  final String title;

  const _SupportSectionLabel(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SupportMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool highlighted;
  final bool cyan;

  const _SupportMenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.highlighted = false,
    this.cyan = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = highlighted
        ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8))
        : cyan
            ? (isDark ? const Color(0xFFBAE6FD) : const Color(0xFF0E7490))
            : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF24364F));

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: highlighted
            ? (isDark ? const Color(0x332563EB) : const Color(0xFFE8F1FF))
            : cyan
                ? const Color(0x1914B8A6)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            constraints: const BoxConstraints(minHeight: 51),
            padding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: highlighted
                  ? const Border(
                      right: BorderSide(
                        color: Color(0xFF3B82F6),
                        width: 4,
                      ),
                    )
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: foreground,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 13,
                      fontWeight: highlighted
                          ? FontWeight.w900
                          : FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_left_rounded,
                  size: 19,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _DrawerDropdown extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final bool initiallyExpanded;

  const _DrawerDropdown({
    required this.title,
    required this.icon,
    required this.children,
    this.initiallyExpanded = false,
  });

  @override
  State<_DrawerDropdown> createState() => _DrawerDropdownState();
}

class _DrawerDropdownState extends State<_DrawerDropdown> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
              child: Row(
                children: [
                  Icon(widget.icon, color: const Color(0xFF0E7490), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Column(children: widget.children),
            ),
            crossFadeState:
                _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 14, 6, 7),
        child: Text(
          title,
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF94A3B8)
                : AppColors.lightTextMuted,
            fontWeight: FontWeight.w800,
            fontSize: 10,
          ),
        ),
      );
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool highlighted;

  const _DrawerTile({required this.icon, required this.title, required this.onTap, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? const Color(0xFF0D1B31) : Colors.white;
    final foreground = dark ? const Color(0xFFEEF6FF) : const Color(0xFF17253C);
    final muted = dark ? const Color(0xFFB9CBE3) : const Color(0xFF475569);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: highlighted
            ? (dark ? const Color(0xFF11345D) : const Color(0xFFE8F1FF))
            : surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            constraints: const BoxConstraints(minHeight: 58),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: highlighted
                  ? const Color(0x884EA8FF)
                  : (dark ? const Color(0x1AFFFFFF) : AppColors.borderSoft)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: highlighted
                        ? (dark ? const Color(0x33F59E0B) : const Color(0xFFFFF3D6))
                        : (dark ? const Color(0x1438BDF8) : const Color(0xFFE0F2FE)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: highlighted
                      ? (dark ? const Color(0xFFFBBF24) : const Color(0xFF92400E))
                      : (dark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1))),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: TextStyle(color: foreground, fontWeight: FontWeight.w800, fontSize: 13))),
                Icon(Icons.arrow_back_ios_new_rounded, size: 13, color: muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
