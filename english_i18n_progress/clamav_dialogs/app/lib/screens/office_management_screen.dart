import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../i18n/localized_text.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../theme/app_theme.dart';

import 'crm_screen.dart';
import 'engineering_offices_screen.dart';
import 'enterprise_integrations_screen.dart';
import 'finance_expenses_screen.dart';
import 'financial_reports_screen.dart';
import 'marketplace_projects_screen.dart';
import 'office_finance_screen.dart';
import 'office_workspace_screen.dart';
import 'office_field_management_screen.dart';
import 'office_drawing_reviews_screen.dart';
import 'payment_information_screen.dart';
import 'professional_verification_screen.dart';
import 'projects_screen.dart';
import 'support_screen.dart';

// Palette scoped to the office dashboard and work-library cards only.
// The existing dark appearance is intentionally preserved pixel-for-pixel.
Color _officeCardColor(BuildContext context, {Color dark = const Color(0xFF101A31)}) =>
    Theme.of(context).brightness == Brightness.dark
        ? dark
        : Theme.of(context).colorScheme.surface;

Color _officeInsetColor(BuildContext context, {Color dark = const Color(0xFF0A1223)}) =>
    Theme.of(context).brightness == Brightness.dark
        ? dark
        : const Color(0xFFE8F0FB);

Color _officeBorderColor(BuildContext context, {Color dark = const Color(0xFF263650)}) =>
    Theme.of(context).brightness == Brightness.dark
        ? dark
        : const Color(0xFFC6D5E8);

Color _officeAccentColor(BuildContext context, Color darkColor) =>
    Theme.of(context).brightness == Brightness.dark
        ? darkColor
        : HSLColor.fromColor(darkColor).withLightness(0.33).toColor();

class OfficeManagementScreen extends StatefulWidget {
  const OfficeManagementScreen({super.key});

  @override
  State<OfficeManagementScreen> createState() => _OfficeManagementScreenState();
}

class _OfficeManagementScreenState extends State<OfficeManagementScreen> {
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
      final data = await ApiService.fetchOfficeDashboard();
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

  void _toast(String message) {
    if (!mounted) return;
    AppFeedback.auto(message);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: Scaffold(
          appBar: AppBar(title: const TrText('إدارة المكتب')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(trUi(_error!), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const TrText('إعادة المحاولة')),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final office = Map<String, dynamic>.from(_data?['office'] as Map? ?? const {});
    final stats = Map<String, dynamic>.from(_data?['statistics'] as Map? ?? const {});

    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: DefaultTabController(
        length: 6,
        child: Scaffold(
          appBar: AppBar(
            title: Text(trUi(office['name']?.toString() ?? 'إدارة المكتب')),
            bottom: TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'الرئيسية'.tr()),
                Tab(text: 'الأعضاء'.tr()),
                Tab(text: 'طلبات الانضمام'.tr()),
                Tab(text: 'الاستشارات'.tr()),
                Tab(text: 'مكتبة الأعمال'.tr()),
                Tab(text: 'الاشتراك والملف'.tr()),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _OverviewTab(data: _data!, office: office, stats: stats, onRefresh: _load),
              _MembersTab(data: _data!, onChanged: _load, toast: _toast),
              _ApplicationsTab(data: _data!, onChanged: _load, toast: _toast),
              _ConsultationsTab(data: _data!, onChanged: _load, toast: _toast),
              _PortfolioTab(data: _data!, onChanged: _load, toast: _toast),
              _SubscriptionProfileTab(data: _data!, onChanged: _load, toast: _toast),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final Map<String, dynamic> data;
  final Map<String, dynamic> office;
  final Map<String, dynamic> stats;
  final Future<void> Function() onRefresh;

  const _OverviewTab({
    required this.data,
    required this.office,
    required this.stats,
    required this.onRefresh,
  });

  bool get _isOwner =>
      (data['permissions'] as Map?)?['office_role']?.toString() == 'owner';

  @override
  Widget build(BuildContext context) {
    final operational = data['is_operational'] == true;
    final latestProjects = List<dynamic>.from(
      data['latest_projects'] as List? ?? const [],
    );
    final latestConsultations = List<dynamic>.from(
      data['consultations'] as List? ?? const [],
    );
    final applications = List<dynamic>.from(
      data['membership_applications'] as List? ?? const [],
    );

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 34),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _officeHero(context, operational),
          if (!operational) ...[
            const SizedBox(height: 12),
            _operationalWarning(context),
          ],
          const SizedBox(height: 18),
          _sectionTitle(context, 
            'إدارة المكتب',
            'كل وظائف المكتب في مكان واحد',
            Icons.dashboard_customize_outlined,
          ),
          const SizedBox(height: 10),
          _quickActions(context),
          const SizedBox(height: 20),
          _sectionTitle(context, 
            'نظرة سريعة',
            'الأرقام الحالية للمكتب',
            Icons.insights_outlined,
          ),
          const SizedBox(height: 10),
          _coreStats(),
          const SizedBox(height: 10),
          _digitalStats(),
          const SizedBox(height: 18),
          _financialSummary(context),
          const SizedBox(height: 18),
          _sectionTitle(context, 
            'مراكز المكتب المتقدمة',
            'إدارة الموقع والرسومات وBIM والتكاملات',
            Icons.hub_outlined,
          ),
          const SizedBox(height: 10),
          _advancedCenters(context),
          if (latestProjects.isNotEmpty) ...[
            const SizedBox(height: 20),
            _sectionTitle(context, 
              'أحدث مشاريع المكتب',
              'مع مؤشرات الموقع والرسومات وBIM',
              Icons.architecture_outlined,
            ),
            const SizedBox(height: 10),
            _latestProjects(context, latestProjects),
          ],
          if (latestConsultations.isNotEmpty) ...[
            const SizedBox(height: 20),
            _sectionTitle(context, 
              'أحدث الاستشارات',
              'آخر الاستشارات المرتبطة بالمكتب',
              Icons.description_outlined,
            ),
            const SizedBox(height: 10),
            _latestConsultations(context, latestConsultations),
          ],
          if (applications.isNotEmpty) ...[
            const SizedBox(height: 20),
            _sectionTitle(context, 
              'طلبات الانضمام الأخيرة',
              'مراجعة طلبات المهندسين',
              Icons.person_add_alt_1_outlined,
            ),
            const SizedBox(height: 10),
            _latestApplications(context, applications),
          ],
          const SizedBox(height: 20),
          _officeInfo(context),
        ],
      ),
    );
  }

  Widget _officeHero(BuildContext context, bool operational) {
    final status = office['status']?.toString() ?? 'pending';
    final subscription = office['subscription_status']?.toString() ?? 'pending';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _officeCardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _officeBorderColor(context)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF60A5FA).withValues(alpha: .25),
                  ),
                ),
                child: Icon(
                  Icons.apartment_rounded,
                  color: _officeAccentColor(context, const Color(0xFF93C5FD)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TrText('لوحة المكتب',
                      style: TextStyle(
                        color: _officeAccentColor(context, const Color(0xFF93C5FD)),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      trUi(office['name']?.toString() ?? 'المكتب الهندسي'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    TrText('إدارة الاستشارات والمشاريع والأعضاء والمستحقات والأنظمة الهندسية من مكان واحد.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.55,
                        color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _statusPill(
                operational ? 'مكتب فعال' : _officeStatusLabel(status),
                operational ? AppColors.success : const Color(0xFFF59E0B),
              ),
              _statusPill(
                _subscriptionStatus(subscription),
                subscription == 'active'
                    ? AppColors.success
                    : const Color(0xFFF59E0B),
              ),
              if ((office['professional_verification_status']?.toString() ?? '') ==
                  'verified')
                _statusPill('موثق', const Color(0xFF60A5FA)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: color.withValues(alpha: .28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              trUi(text),
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );

  Widget _operationalWarning(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF97316).withValues(alpha: .09),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFF97316).withValues(alpha: .35),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFF97316)),
            const SizedBox(width: 10),
            const Expanded(
              child: TrText('اشتراك المكتب أو حالة المكتب غير فعالة حاليًا. راجع الاشتراك والملف لإعادة التشغيل الكامل.',
                style: TextStyle(fontSize: 11, height: 1.45),
              ),
            ),
            TextButton(
              onPressed: () => DefaultTabController.of(context).animateTo(5),
              child: const TrText('إدارة'),
            ),
          ],
        ),
      );

  Widget _sectionTitle(BuildContext context, String title, String subtitle, IconData icon) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.blue500_10,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan)),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trUi(title),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  trUi(subtitle),
                  style: TextStyle(
                    fontSize: 9,
                    color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _quickActions(BuildContext context) {
    final slug = office['slug']?.toString() ?? '';
    final actions = <_OfficeDashboardAction>[
      _OfficeDashboardAction(
        'استشارات المكتب',
        'المتابعة والتعيين',
        Icons.design_services_outlined,
        const Color(0xFF60A5FA),
        () => DefaultTabController.of(context).animateTo(3),
      ),
      _OfficeDashboardAction(
        'أعضاء المكتب',
        'الأدوار والصلاحيات',
        Icons.groups_outlined,
        const Color(0xFF22D3EE),
        () => DefaultTabController.of(context).animateTo(1),
      ),
      _OfficeDashboardAction(
        'طلبات الانضمام',
        'قبول ورفض الطلبات',
        Icons.person_add_alt_1_outlined,
        const Color(0xFFF59E0B),
        () => DefaultTabController.of(context).animateTo(2),
        badge: _int(stats['pending_applications']),
      ),
      _OfficeDashboardAction(
        'اشتراك المكتب',
        'الحالة والإيصال',
        Icons.credit_card_outlined,
        const Color(0xFF34D399),
        () => DefaultTabController.of(context).animateTo(5),
      ),
      _OfficeDashboardAction(
        'مشاريع المكتب',
        'التنفيذ والفريق والملفات',
        Icons.architecture_outlined,
        const Color(0xFF818CF8),
        () => _push(context, const ProjectsScreen()),
        badge: _int(stats['active_projects']),
      ),
      _OfficeDashboardAction(
        'إدارة الموقع',
        'IR / NCR / Punch / Safety',
        Icons.home_work_outlined,
        const Color(0xFF10B981),
        () => _push(context, const OfficeFieldManagementScreen()),
        badge: _int(stats['field_open']),
      ),
      _OfficeDashboardAction(
        'الرسومات والمراجعات',
        'Markup + Compare',
        Icons.draw_outlined,
        const Color(0xFFA78BFA),
        () => _push(context, const OfficeDrawingReviewsScreen()),
        badge: _int(stats['drawing_markups_open']),
      ),
      _OfficeDashboardAction(
        'BIM & Clash',
        'IFC / RVT / Clash',
        Icons.view_in_ar_outlined,
        const Color(0xFF06B6D4),
        () => _push(context, const ProjectsScreen()),
        badge: _int(stats['bim_clashes_open']),
      ),
      _OfficeDashboardAction(
        'سوق المشاريع',
        'العروض والفرص',
        Icons.storefront_outlined,
        const Color(0xFFE879F9),
        () => _push(context, const MarketplaceProjectsScreen()),
      ),
      _OfficeDashboardAction(
        'CRM المكتب',
        'العملاء والفرص',
        Icons.hub_outlined,
        const Color(0xFFC084FC),
        () => _push(context, const CrmScreen()),
      ),
      if (_isOwner)
        _OfficeDashboardAction(
          'مالية المكتب',
          'المستحقات والأرباح',
          Icons.account_balance_wallet_outlined,
          const Color(0xFF34D399),
          () => _push(context, const OfficeFinanceScreen()),
        ),
      if (_isOwner)
        _OfficeDashboardAction(
          'المصروفات',
          'الموردون والميزانيات',
          Icons.receipt_long_outlined,
          const Color(0xFF38BDF8),
          () => _push(context, const FinanceExpensesScreen()),
        ),
      if (_isOwner)
        _OfficeDashboardAction(
          'التقارير المالية',
          'الأرباح والتقارير',
          Icons.query_stats_outlined,
          const Color(0xFF67E8F9),
          () => _push(context, const FinancialReportsScreen()),
        ),
      _OfficeDashboardAction(
        'Enterprise API',
        'Tokens + Webhooks',
        Icons.integration_instructions_outlined,
        const Color(0xFF38BDF8),
        () => _push(context, const EnterpriseIntegrationsScreen()),
      ),
      _OfficeDashboardAction(
        'مكتبة الأعمال',
        'أعمال المكتب المنشورة',
        Icons.photo_library_outlined,
        const Color(0xFFF472B6),
        () => DefaultTabController.of(context).animateTo(4),
      ),
      _OfficeDashboardAction(
        'معلومات الدفع',
        'طرق الدفع والتحويل',
        Icons.payments_outlined,
        const Color(0xFF2DD4BF),
        () => _push(context, const PaymentInformationScreen()),
      ),
      _OfficeDashboardAction(
        'توثيق المكتب',
        'حالة التوثيق المهني',
        Icons.verified_outlined,
        const Color(0xFF60A5FA),
        () => _push(context, const ProfessionalVerificationScreen()),
      ),
      _OfficeDashboardAction(
        'الدعم الفني',
        'التذاكر والمساعدة',
        Icons.support_agent_outlined,
        const Color(0xFFFB7185),
        () => _push(context, const SupportScreen()),
      ),
      if (slug.isNotEmpty)
        _OfficeDashboardAction(
          'صفحة المكتب العامة',
          'الملف والأعمال والتقييمات',
          Icons.public_rounded,
          const Color(0xFF22D3EE),
          () => _push(context, OfficeDetailScreen(slug: slug)),
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 820
            ? 4
            : constraints.maxWidth >= 560
                ? 3
                : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: columns >= 3 ? 1.35 : 1.12,
          ),
          itemBuilder: (context, index) => _OfficeDashboardActionCard(
            action: actions[index],
          ),
        );
      },
    );
  }

  Widget _coreStats() {
    final items = <({String label, dynamic value, IconData icon, Color color})>[
      (label: 'أعضاء فعالون', value: stats['active_members'], icon: Icons.groups_outlined, color: const Color(0xFF22D3EE)),
      (label: 'طلبات معلقة', value: stats['pending_applications'], icon: Icons.pending_actions_outlined, color: const Color(0xFFF59E0B)),
      (label: 'استشارات جارية', value: stats['in_progress_consultations'], icon: Icons.sync_outlined, color: const Color(0xFF60A5FA)),
      (label: 'مشاريع نشطة', value: stats['active_projects'], icon: Icons.architecture_outlined, color: const Color(0xFF818CF8)),
      (label: 'مشاريع مكتملة', value: stats['completed_projects'], icon: Icons.task_alt_outlined, color: const Color(0xFF34D399)),
      (label: 'إجمالي المشاريع', value: stats['projects'], icon: Icons.folder_copy_outlined, color: const Color(0xFF94A3B8)),
    ];
    return _statsWrap(items);
  }

  Widget _digitalStats() {
    final items = <({String label, dynamic value, IconData icon, Color color})>[
      (label: 'سجلات موقع مفتوحة', value: stats['field_open'], icon: Icons.home_work_outlined, color: const Color(0xFF10B981)),
      (label: 'NCR مفتوحة', value: stats['ncr_open'], icon: Icons.report_problem_outlined, color: const Color(0xFFFB7185)),
      (label: 'Markup مفتوحة', value: stats['drawing_markups_open'], icon: Icons.draw_outlined, color: const Color(0xFFA78BFA)),
      (label: 'نماذج BIM', value: stats['bim_models'], icon: Icons.view_in_ar_outlined, color: const Color(0xFF22D3EE)),
      (label: 'Clash مفتوحة', value: stats['bim_clashes_open'], icon: Icons.warning_amber_rounded, color: const Color(0xFFF59E0B)),
      (label: 'Webhooks فعالة', value: stats['enterprise_webhooks'], icon: Icons.webhook_outlined, color: const Color(0xFF38BDF8)),
    ];
    return _statsWrap(items);
  }

  Widget _statsWrap(
    List<({String label, dynamic value, IconData icon, Color color})> items,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 720
            ? (constraints.maxWidth - 20) / 3
            : (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: _OfficeMetricTile(
                    label: item.label,
                    value: item.value,
                    icon: item.icon,
                    color: item.color,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _financialSummary(BuildContext context) {
    if (!_isOwner) return const SizedBox.shrink();
    final values = [
      ('قيمة المشاريع', stats['total_projects_value'], const Color(0xFF60A5FA)),
      ('المستحق المتوقع', stats['office_expected_earnings'], const Color(0xFF22D3EE)),
      ('المدفوع', stats['office_paid_earnings'], const Color(0xFF34D399)),
      ('المعلق', stats['office_pending_earnings'], const Color(0xFFF59E0B)),
    ];
    return _officePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: TrText('الملخص المالي للمكتب',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ),
              TextButton.icon(
                onPressed: () => _push(context, const OfficeFinanceScreen()),
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const TrText('التفاصيل'),
              ),
            ],
          ),
          const SizedBox(height: 9),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: values.map((item) {
                  final amount = _double(item.$2);
                  return Container(
                    width: width,
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: _officeInsetColor(context),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: _officeBorderColor(context, dark: const Color(0xFF22314A))),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trUi(item.$1),
                          style: TextStyle(
                            fontSize: 9,
                            color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${amount.toStringAsFixed(2)} ₪',
                          style: TextStyle(
                            color: _officeAccentColor(context, item.$3),
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _advancedCenters(BuildContext context) {
    final centers = <_OfficeCenterCardData>[
      _OfficeCenterCardData(
        title: 'إدارة الموقع',
        subtitle: 'Daily Report • IR • ITP • NCR • Punch • Safety • MIR',
        icon: Icons.home_work_outlined,
        color: const Color(0xFF10B981),
        firstLabel: 'مفتوحة',
        firstValue: _int(stats['field_open']),
        secondLabel: 'NCR',
        secondValue: _int(stats['ncr_open']),
        onTap: () => _push(context, const OfficeFieldManagementScreen()),
      ),
      _OfficeCenterCardData(
        title: 'الرسومات والمراجعات',
        subtitle: 'Drawing Markup + Visual Version Compare + مراجعات الملفات',
        icon: Icons.draw_outlined,
        color: const Color(0xFFA78BFA),
        firstLabel: 'Markup',
        firstValue: _int(stats['drawing_markups']),
        secondLabel: 'مفتوحة',
        secondValue: _int(stats['drawing_markups_open']),
        onTap: () => _push(context, const OfficeDrawingReviewsScreen()),
      ),
      _OfficeCenterCardData(
        title: 'BIM & Clash Detection',
        subtitle: 'GLB/GLTF Viewer • IFC Geometry • Clash Runs • Assign/Resolve',
        icon: Icons.view_in_ar_outlined,
        color: const Color(0xFF22D3EE),
        firstLabel: 'نماذج',
        firstValue: _int(stats['bim_models']),
        secondLabel: 'Clash مفتوحة',
        secondValue: _int(stats['bim_clashes_open']),
        warning: _int(stats['bim_clashes_critical']),
        onTap: () => _push(context, const ProjectsScreen()),
      ),
      _OfficeCenterCardData(
        title: 'Enterprise API & Webhooks',
        subtitle: 'Tenant isolation • API Tokens • HMAC Webhooks • Delivery Logs',
        icon: Icons.integration_instructions_outlined,
        color: const Color(0xFF38BDF8),
        firstLabel: 'API Tokens',
        firstValue: _int(stats['enterprise_api_tokens']),
        secondLabel: 'Webhooks',
        secondValue: _int(stats['enterprise_webhooks']),
        onTap: () => _push(context, const EnterpriseIntegrationsScreen()),
      ),
    ];
    if (_isOwner) {
      centers.add(
        _OfficeCenterCardData(
          title: 'المالية والتقارير',
          subtitle: 'المستحقات • المصروفات • الميزانيات • التقارير المالية',
          icon: Icons.account_balance_wallet_outlined,
          color: const Color(0xFF34D399),
          firstLabel: 'مدفوع',
          firstValue: _double(stats['office_paid_earnings']).round(),
          secondLabel: 'معلق',
          secondValue: _double(stats['office_pending_earnings']).round(),
          onTap: () => _push(context, const OfficeFinanceScreen()),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 760
            ? (constraints.maxWidth - 10) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: centers
              .map(
                (center) => SizedBox(
                  width: width,
                  child: _OfficeCenterCard(data: center),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _latestProjects(BuildContext context, List<dynamic> projects) {
    return _officePanel(
      child: Column(
        children: projects.take(6).map((raw) {
          final project = Map<String, dynamic>.from(raw as Map);
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _push(context, const ProjectsScreen()),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.blue500_10,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      Icons.architecture_rounded,
                      size: 19,
                      color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trUi(project['title']?.toString() ?? 'مشروع'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${project['project_number'] ?? ''} • ${_projectStatus(project['status']?.toString())}',
                          style: TextStyle(
                            fontSize: 9,
                            color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 5,
                          runSpacing: 5,
                          children: [
                            if (_int(project['field_open']) > 0)
                              _tinyModuleBadge('موقع ${_int(project['field_open'])}', const Color(0xFF10B981)),
                            if (_int(project['markup_open']) > 0)
                              _tinyModuleBadge('Markup ${_int(project['markup_open'])}', const Color(0xFFA78BFA)),
                            if (_int(project['bim_clashes_open']) > 0)
                              _tinyModuleBadge('Clash ${_int(project['bim_clashes_open'])}', const Color(0xFFF59E0B)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_double(project['agreed_price']).toStringAsFixed(0)} ₪',
                    style: const TextStyle(
                      color: Color(0xFF93C5FD),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _latestConsultations(
    BuildContext context,
    List<dynamic> consultations,
  ) {
    return _officePanel(
      child: Column(
        children: consultations.take(4).map((raw) {
          final item = Map<String, dynamic>.from(raw as Map);
          final customer = item['customer'] as Map?;
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.description_outlined,
              color: Color(0xFF60A5FA),
            ),
            title: Text(
              trUi(item['title']?.toString() ?? 'استشارة'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '${customer?['name'] ?? 'عميل'} • ${item['status'] ?? '—'}'.tr(),
              style: const TextStyle(fontSize: 9),
            ),
            onTap: () => DefaultTabController.of(context).animateTo(3),
          );
        }).toList(),
      ),
    );
  }

  Widget _latestApplications(BuildContext context, List<dynamic> applications) {
    return _officePanel(
      child: Column(
        children: applications.take(4).map((raw) {
          final item = Map<String, dynamic>.from(raw as Map);
          final engineer = item['engineer'] as Map?;
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.person_add_alt_1_outlined,
              color: Color(0xFFF59E0B),
            ),
            title: Text(
              trUi(engineer?['name']?.toString() ?? 'مهندس'),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              trUi(_appStatus(item['status']?.toString())),
              style: const TextStyle(fontSize: 9),
            ),
            onTap: () => DefaultTabController.of(context).animateTo(2),
          );
        }).toList(),
      ),
    );
  }

  Widget _officeInfo(BuildContext context) {
    final latestSubscription = data['latest_subscription'] as Map?;
    return _officePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: TrText('بيانات المكتب والاشتراك',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ),
              TextButton(
                onPressed: () => DefaultTabController.of(context).animateTo(5),
                child: const TrText('إدارة'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _infoLine(context, Icons.email_outlined, office['email']?.toString() ?? '—'),
          _infoLine(context, Icons.phone_outlined, office['phone']?.toString() ?? '—'),
          _infoLine(context, Icons.location_on_outlined, office['address']?.toString() ?? '—'),
          _infoLine(context, 
            Icons.event_available_outlined,
            'نهاية الاشتراك: ${_dateOnly(office['subscription_ends_at'] ?? latestSubscription?['ends_at'])}',
          ),
        ],
      ),
    );
  }

  Widget _infoLine(BuildContext context, IconData icon, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Icon(icon, size: 17, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                trUi(value),
                style: TextStyle(fontSize: 10, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : AppColors.textSecondary)),
              ),
            ),
          ],
        ),
      );

  Widget _officePanel({required Widget child}) => Builder(
        builder: (context) => Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _officeCardColor(context),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: _officeBorderColor(context)),
          ),
          child: child,
        ),
      );

  Widget _tinyModuleBadge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: color.withValues(alpha: .20)),
        ),
        child: Text(
          trUi(text),
          style: TextStyle(
            color: color,
            fontSize: 8,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  int _int(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;
  double _double(dynamic value) =>
      double.tryParse(value?.toString() ?? '') ?? 0;

  String _officeStatusLabel(String status) => switch (status) {
        'active' => 'مكتب فعال',
        'suspended' => 'مكتب موقوف',
        'closed' => 'مكتب مغلق',
        _ => 'قيد المراجعة',
      };

  String _projectStatus(String? status) => switch (status) {
        'approved' => 'معتمد',
        'in_progress' => 'قيد التنفيذ',
        'completed' => 'مكتمل',
        'cancelled' => 'ملغي',
        _ => status ?? '—',
      };
}

class _OfficeDashboardAction {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int badge;

  const _OfficeDashboardAction(
    this.title,
    this.subtitle,
    this.icon,
    this.color,
    this.onTap, {
    this.badge = 0,
  });
}

class _OfficeDashboardActionCard extends StatelessWidget {
  final _OfficeDashboardAction action;

  const _OfficeDashboardActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: action.onTap,
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: _officeCardColor(context),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: _officeBorderColor(context)),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: action.color.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(action.icon, size: 18, color: _officeAccentColor(context, action.color)),
                ),
                const Spacer(),
                Text(
                  trUi(action.title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  trUi(action.subtitle),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 8,
                    height: 1.35,
                    color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            if (action.badge > 0)
              Positioned(
                left: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: action.color.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${action.badge}',
                    style: TextStyle(
                      color: _officeAccentColor(context, action.color),
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OfficeMetricTile extends StatelessWidget {
  final String label;
  final dynamic value;
  final IconData icon;
  final Color color;

  const _OfficeMetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: _officeCardColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _officeBorderColor(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: _officeAccentColor(context, color)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${value ?? 0}',
                  style: TextStyle(
                    color: _officeAccentColor(context, color),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  trUi(label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 8,
                    color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OfficeCenterCardData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String firstLabel;
  final int firstValue;
  final String secondLabel;
  final int secondValue;
  final int warning;
  final VoidCallback onTap;

  const _OfficeCenterCardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.firstLabel,
    required this.firstValue,
    required this.secondLabel,
    required this.secondValue,
    required this.onTap,
    this.warning = 0,
  });
}

class _OfficeCenterCard extends StatelessWidget {
  final _OfficeCenterCardData data;

  const _OfficeCenterCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _officeCardColor(context),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: data.color.withValues(alpha: .22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(data.icon, size: 19, color: _officeAccentColor(context, data.color)),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trUi(data.title),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      trUi(data.subtitle),
                      style: TextStyle(
                        fontSize: 8,
                        height: 1.45,
                        color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
              if (data.warning > 0)
                _Badge(text: '${data.warning} حرجة', color: const Color(0xFFFB7185)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _centerMetric(context, data.firstLabel, data.firstValue, data.color),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _centerMetric(context, data.secondLabel, data.secondValue, data.color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: data.onTap,
              icon: const Icon(Icons.arrow_back_rounded, size: 15),
              label: const TrText('فتح المركز'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _centerMetric(BuildContext context, String label, int value, Color color) => Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: _officeInsetColor(context),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: _officeBorderColor(context, dark: const Color(0xFF22314A))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              trUi(label),
              style: TextStyle(fontSize: 8, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : AppColors.textSecondary)),
            ),
            const SizedBox(height: 3),
            Text(
              '$value',
              style: TextStyle(
                color: _officeAccentColor(context, color),
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
}

class _MembersTab extends StatelessWidget {
  final Map<String, dynamic> data;
  final Future<void> Function() onChanged;
  final void Function(String) toast;

  const _MembersTab({required this.data, required this.onChanged, required this.toast});

  @override
  Widget build(BuildContext context) {
    final members = List<dynamic>.from(data['members'] as List? ?? const []);
    final specialties = List<dynamic>.from(data['specialties'] as List? ?? const []);
    final manager = data['manager_membership'] as Map?;
    final isOwner = manager?['office_role']?.toString() == 'owner';

    return RefreshIndicator(
      onRefresh: onChanged,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: members.isEmpty
            ? [const Center(child: Padding(padding: EdgeInsets.all(50), child: TrText('لا يوجد أعضاء.')))]
            : members.map((raw) {
                final member = Map<String, dynamic>.from(raw as Map);
                final user = member['user'] as Map?;
                final specialty = member['specialty'] as Map?;
                final owner = member['office_role']?.toString() == 'owner';
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(child: Text(trUi(_initial(user?['name']?.toString())))),
                    title: Text(trUi(user?['name']?.toString() ?? 'عضو'), style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(trUi([
                      member['position']?.toString(),
                      specialty?['name']?.toString(),
                      _roleLabel(member['office_role']?.toString()),
                      member['status']?.toString() == 'active' ? 'فعال' : 'غير فعال',
                    ].where((e) => e != null && e.isNotEmpty).join(' • '))),
                    trailing: owner
                        ? const Icon(Icons.workspace_premium_rounded, color: Color(0xFFF59E0B))
                        : PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'edit') {
                                await _editMember(context, member, specialties, isOwner, toast);
                                await onChanged();
                              } else if (value == 'remove') {
                                try {
                                  final message = await ApiService.removeOfficeMember(int.parse(member['id'].toString()));
                                  toast(message);
                                  await onChanged();
                                } on ApiException catch (e) {
                                  AppFeedback.error(e.message);
                                  toast(e.message);
                                }
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: TrText('تعديل العضو')),
                              PopupMenuItem(value: 'remove', child: TrText('إزالة من المكتب')),
                            ],
                          ),
                  ),
                );
              }).toList(),
      ),
    );
  }

  Future<void> _editMember(
    BuildContext context,
    Map<String, dynamic> member,
    List<dynamic> specialties,
    bool isOwner,
    void Function(String) toast,
  ) async {
    final position = TextEditingController(text: member['position']?.toString() ?? '');
    String role = member['office_role']?.toString() ?? 'engineer';
    String status = member['status']?.toString() ?? 'active';
    int? specialtyId = int.tryParse(member['specialty_id']?.toString() ?? '');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => Directionality(
          textDirection: AppLanguage.instance.textDirection,
          child: AlertDialog(
            title: const TrText('تعديل عضو المكتب'),
            content: SizedBox(
              width: 430,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: position, decoration: InputDecoration(labelText: 'المسمى الوظيفي'.tr())),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: role,
                      decoration: InputDecoration(labelText: 'دور العضو'.tr()),
                      items: [
                        if (isOwner) const DropdownMenuItem(value: 'manager', child: TrText('مدير')),
                        const DropdownMenuItem(value: 'engineer', child: TrText('مهندس')),
                        const DropdownMenuItem(value: 'employee', child: TrText('موظف')),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => role = value);
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int?>(
                      initialValue: specialtyId,
                      decoration: InputDecoration(labelText: 'التخصص'.tr()),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: TrText('بدون تخصص')),
                        ...specialties.map((raw) {
                          final item = Map<String, dynamic>.from(raw as Map);
                          return DropdownMenuItem<int?>(
                            value: int.parse(item['id'].toString()),
                            child: Text(trUi(item['name']?.toString() ?? '')),
                          );
                        }),
                      ],
                      onChanged: (value) => setState(() => specialtyId = value),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: InputDecoration(labelText: 'الحالة'.tr()),
                      items: const [
                        DropdownMenuItem(value: 'active', child: TrText('فعال')),
                        DropdownMenuItem(value: 'inactive', child: TrText('غير فعال')),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => status = value);
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const TrText('إلغاء')),
              FilledButton(
                onPressed: () async {
                  try {
                    final message = await ApiService.updateOfficeMember(
                      memberId: int.parse(member['id'].toString()),
                      officeRole: role,
                      status: status,
                      position: position.text.trim().isEmpty ? null : position.text.trim(),
                      specialtyId: specialtyId,
                    );
                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                    toast(message);
                  } on ApiException catch (e) {
                    AppFeedback.error(e.message);
                    toast(e.message);
                  }
                },
                child: const TrText('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 600), position.dispose);
  }
}

class _ApplicationsTab extends StatelessWidget {
  final Map<String, dynamic> data;
  final Future<void> Function() onChanged;
  final void Function(String) toast;

  const _ApplicationsTab({required this.data, required this.onChanged, required this.toast});

  Future<void> _openApplicationFile({
    required int applicationId,
    required String type,
    required void Function(String) toast,
  }) async {
    try {
      final file = await ApiService.downloadOfficeMembershipApplicationFile(
        applicationId: applicationId,
        type: type,
      );
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        toast(result.message.isEmpty ? 'تعذر فتح الملف.' : result.message);
      }
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      toast(e.message);
    } catch (_) {
      toast('تعذر فتح الملف.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = List<dynamic>.from(data['membership_applications'] as List? ?? const []);
    return RefreshIndicator(
      onRefresh: onChanged,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: items.isEmpty
            ? [const Center(child: Padding(padding: EdgeInsets.all(50), child: TrText('لا توجد طلبات انضمام.')))]
            : items.map((raw) {
                final item = Map<String, dynamic>.from(raw as Map);
                final engineer = item['engineer'] as Map?;
                final specialty = item['specialty'] as Map?;
                final pending = item['status']?.toString() == 'pending';
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(trUi(engineer?['name']?.toString() ?? 'مهندس'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                            _Badge(text: _appStatus(item['status']?.toString()), color: pending ? const Color(0xFFF59E0B) : item['status'] == 'approved' ? AppColors.success : AppColors.danger),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(trUi([
                          specialty?['name']?.toString(),
                          item['requested_position']?.toString(),
                          item['years_of_experience'] != null ? '${item['years_of_experience']} سنوات خبرة' : null,
                        ].where((e) => e != null && e.isNotEmpty).join(' • ')), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
                        if ((item['message']?.toString() ?? '').isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(trUi(item['message'].toString())),
                        ],
                        if ((item['cv_path']?.toString() ?? '').isNotEmpty ||
                            (item['certificate_path']?.toString() ?? '').isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if ((item['cv_path']?.toString() ?? '').isNotEmpty)
                                OutlinedButton.icon(
                                  onPressed: () => _openApplicationFile(
                                    applicationId: int.parse(item['id'].toString()),
                                    type: 'cv',
                                    toast: toast,
                                  ),
                                  icon: const Icon(Icons.description_outlined),
                                  label: const TrText('السيرة الذاتية'),
                                ),
                              if ((item['certificate_path']?.toString() ?? '').isNotEmpty)
                                OutlinedButton.icon(
                                  onPressed: () => _openApplicationFile(
                                    applicationId: int.parse(item['id'].toString()),
                                    type: 'certificate',
                                    toast: toast,
                                  ),
                                  icon: const Icon(Icons.workspace_premium_outlined),
                                  label: const TrText('الشهادة'),
                                ),
                            ],
                          ),
                        ],
                        if (pending) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () async {
                                    final position = await _askText(context, 'المسمى الوظيفي', initial: item['requested_position']?.toString() ?? 'مهندس');
                                    if (position == null || position.trim().isEmpty) return;
                                    try {
                                      final message = await ApiService.reviewOfficeMembershipApplication(
                                        applicationId: int.parse(item['id'].toString()),
                                        decision: 'approve',
                                        position: position.trim(),
                                      );
                                      toast(message);
                                      await onChanged();
                                    } on ApiException catch (e) {
                                      AppFeedback.error(e.message);
                                      toast(e.message);
                                    }
                                  },
                                  icon: const Icon(Icons.check_rounded),
                                  label: const TrText('قبول'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final reason = await _askText(context, 'سبب الرفض', maxLines: 3);
                                    if (reason == null || reason.trim().isEmpty) return;
                                    try {
                                      final message = await ApiService.reviewOfficeMembershipApplication(
                                        applicationId: int.parse(item['id'].toString()),
                                        decision: 'reject',
                                        rejectionReason: reason.trim(),
                                      );
                                      toast(message);
                                      await onChanged();
                                    } on ApiException catch (e) {
                                      AppFeedback.error(e.message);
                                      toast(e.message);
                                    }
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                  label: const TrText('رفض'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
      ),
    );
  }
}

class _ConsultationsTab extends StatelessWidget {
  final Map<String, dynamic> data;
  final Future<void> Function() onChanged;
  final void Function(String) toast;

  const _ConsultationsTab({required this.data, required this.onChanged, required this.toast});

  @override
  Widget build(BuildContext context) {
    final items = List<dynamic>.from(data['consultations'] as List? ?? const []);
    final engineers = List<dynamic>.from(data['engineers'] as List? ?? const []);
    return RefreshIndicator(
      onRefresh: onChanged,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: items.isEmpty
            ? [const Center(child: Padding(padding: EdgeInsets.all(50), child: TrText('لا توجد استشارات محولة إلى المكتب.')))]
            : items.map((raw) {
                final item = Map<String, dynamic>.from(raw as Map);
                final engineer = item['engineer'] as Map?;
                final type = item['consultation_type'] as Map?;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(trUi(item['title']?.toString() ?? 'استشارة'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                        const SizedBox(height: 5),
                        Text(trUi([
                          item['consultation_number']?.toString(),
                          type?['name']?.toString(),
                          engineer?['name'] != null ? 'المهندس: ${engineer?['name']}' : 'غير مسندة لمهندس',
                        ].where((e) => e != null && e.isNotEmpty).join(' • ')), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 11)),
                        if (engineers.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final engineerId = await _chooseEngineer(context, engineers, int.tryParse(engineer?['id']?.toString() ?? ''));
                                if (engineerId == null) return;
                                try {
                                  final message = await ApiService.assignOfficeConsultationEngineer(int.parse(item['id'].toString()), engineerId);
                                  toast(message);
                                  await onChanged();
                                } on ApiException catch (e) {
                                  AppFeedback.error(e.message);
                                  toast(e.message);
                                }
                              },
                              icon: const Icon(Icons.engineering_outlined),
                              label: const TrText('تعيين مهندس'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
      ),
    );
  }
}

class _SubscriptionProfileTab extends StatelessWidget {
  final Map<String, dynamic> data;
  final Future<void> Function() onChanged;
  final void Function(String) toast;

  const _SubscriptionProfileTab({required this.data, required this.onChanged, required this.toast});

  @override
  Widget build(BuildContext context) {
    final office = Map<String, dynamic>.from(data['office'] as Map? ?? const {});
    final subscriptions = List<dynamic>.from(data['subscriptions'] as List? ?? const []);
    final role = context.read<AuthProvider>().user?.role ?? '';

    return RefreshIndicator(
      onRefresh: onChanged,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TrText('اشتراك المكتب', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 8),
                  TrText('الحالة: ${office['subscription_status'] ?? '—'}'),
                  TrText('القيمة: ${office['monthly_subscription_amount'] ?? 0} ${office['subscription_currency'] ?? ''}'),
                  TrText('ينتهي: ${_dateOnly(office['subscription_ends_at'])}'),
                  if (role == 'office_owner') ...[
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const OfficeWorkspaceScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.workspace_premium_rounded),
                      label: const TrText('الباقة والاشتراك'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () => _editProfile(context, office, toast, onChanged),
            icon: const Icon(Icons.edit_outlined),
            label: const TrText('تعديل الملف الشخصي للمكتب'),
          ),
          const SizedBox(height: 16),
          const TrText('سجل الاشتراكات', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          const SizedBox(height: 8),
          ...subscriptions.map((raw) {
            final sub = Map<String, dynamic>.from(raw as Map);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.credit_card_rounded),
                title: Text('${sub['amount'] ?? 0} ${sub['currency'] ?? ''}'),
                subtitle: Text('${_subscriptionStatus(sub['status']?.toString())} • ${_dateOnly(sub['ends_at'])}'),
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _editProfile(BuildContext context, Map<String, dynamic> office, void Function(String) toast, Future<void> Function() onChanged) async {
    final name = TextEditingController(text: office['name']?.toString() ?? '');
    final email = TextEditingController(text: office['email']?.toString() ?? '');
    final phone = TextEditingController(text: office['phone']?.toString() ?? '');
    final country = TextEditingController(text: office['country']?.toString() ?? '');
    final city = TextEditingController(text: office['city']?.toString() ?? '');
    final address = TextEditingController(text: office['address']?.toString() ?? '');
    final description = TextEditingController(text: office['description']?.toString() ?? '');
    final commercial = TextEditingController(text: office['commercial_registration']?.toString() ?? '');
    final license = TextEditingController(text: office['license_number']?.toString() ?? '');
    File? logo;
    File? cover;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => Directionality(
          textDirection: AppLanguage.instance.textDirection,
          child: AlertDialog(
            title: const TrText('تعديل ملف المكتب'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dialogField(name, 'اسم المكتب'),
                    _dialogField(email, 'البريد الإلكتروني'),
                    _dialogField(phone, 'الهاتف'),
                    _dialogField(commercial, 'السجل التجاري'),
                    _dialogField(license, 'رقم الترخيص'),
                    _dialogField(country, 'الدولة'),
                    _dialogField(city, 'المدينة'),
                    _dialogField(address, 'العنوان', maxLines: 2),
                    _dialogField(description, 'نبذة المكتب', maxLines: 3),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await FilePicker.pickFile(type: FileType.image);
                        if (picked?.path != null) setState(() => logo = File(picked!.path!));
                      },
                      icon: const Icon(Icons.image_outlined),
                      label: Text(trUi(logo == null ? 'اختيار شعار جديد' : 'تم اختيار الشعار')),
                    ),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await FilePicker.pickFile(type: FileType.image);
                        if (picked?.path != null) setState(() => cover = File(picked!.path!));
                      },
                      icon: const Icon(Icons.panorama_outlined),
                      label: Text(trUi(cover == null ? 'اختيار غلاف جديد' : 'تم اختيار الغلاف')),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const TrText('إلغاء')),
              FilledButton(
                onPressed: () async {
                  try {
                    final message = await ApiService.updateOfficeProfile(
                      fields: {
                        'name': name.text.trim(),
                        'email': email.text.trim(),
                        'phone': phone.text.trim(),
                        'commercial_registration': commercial.text.trim(),
                        'license_number': license.text.trim(),
                        'country': country.text.trim(),
                        'city': city.text.trim(),
                        'address': address.text.trim(),
                        'description': description.text.trim(),
                      },
                      logo: logo,
                      cover: cover,
                    );
                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                    toast(message);
                    await onChanged();
                  } on ApiException catch (e) {
                    AppFeedback.error(e.message);
                    toast(e.message);
                  }
                },
                child: const TrText('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );

    for (final controller in [name, email, phone, commercial, license, country, city, address, description]) {
      controller.dispose();
    }
  }

  Widget _dialogField(TextEditingController controller, String label, {int maxLines = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(controller: controller, maxLines: maxLines, decoration: InputDecoration(labelText: trUiN(label))),
      );
}


class _PortfolioTab extends StatefulWidget {
  final Map<String, dynamic> data;
  final Future<void> Function() onChanged;
  final void Function(String) toast;

  const _PortfolioTab({
    required this.data,
    required this.onChanged,
    required this.toast,
  });

  @override
  State<_PortfolioTab> createState() => _PortfolioTabState();
}

class _PortfolioTabState extends State<_PortfolioTab> {
  bool _showForm = true;

  @override
  Widget build(BuildContext context) {
    final office = Map<String, dynamic>.from(
      widget.data['office'] as Map? ?? const {},
    );
    final works = List<dynamic>.from(
      widget.data['portfolio_works'] as List? ?? const [],
    );
    final reviews = List<dynamic>.from(
      widget.data['reviews'] as List? ?? const [],
    );
    final reviewerNames = List<dynamic>.from(
      office['reviewer_names'] as List? ?? const [],
    );
    final avg = (office['rating_average'] as num?)?.toDouble() ?? 0;
    final reviewsCount =
        (office['reviews_count'] as num?)?.toInt() ?? reviews.length;

    return RefreshIndicator(
      onRefresh: widget.onChanged,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _portfolioHeader(
            office: office,
            worksCount: works.length,
            average: avg,
            reviewsCount: reviewsCount,
            reviewerNames: reviewerNames,
          ),
          const SizedBox(height: 14),
          _viewSwitcher(works.length),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _showForm
                ? _newWorkPanel(key: const ValueKey('form'))
                : _worksPanel(
                    key: const ValueKey('list'),
                    works: works,
                    average: avg,
                    reviewsCount: reviewsCount,
                  ),
          ),
          if (_showForm) ...[
            const SizedBox(height: 16),
            _worksPanel(
              works: works,
              average: avg,
              reviewsCount: reviewsCount,
              compact: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _portfolioHeader({
    required Map<String, dynamic> office,
    required int worksCount,
    required double average,
    required int reviewsCount,
    required List<dynamic> reviewerNames,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: Theme.of(context).brightness == Brightness.dark
              ? const [Color(0xFF1A202C), Color(0xFF0B1322)]
              : const [Color(0xFFFFFFFF), Color(0xFFEAF3FF)],
        ),
        border: Border.all(color: const Color(0x2638BDF8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3300DCE6),
            blurRadius: 34,
            offset: Offset(0, 16),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF00F2FE),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Color(0x9900F2FE), blurRadius: 10),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TrText('OFFICE PORTFOLIO · البورتفوليو الهندسي',
                  style: TextStyle(
                    color: _officeAccentColor(context, const Color(0xFF67E8F9)),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .4,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF080E1A) : Theme.of(context).colorScheme.surface),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: const Color(0x3338BDF8)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, size: 13, color: _officeAccentColor(context, const Color(0xFF00F2FE))),
                    const SizedBox(width: 4),
                    Text(
                      'VERIFIED STUDIO',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFBFFBFF)
                            : const Color(0xFF155E75),
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          TrText('مكتبة أعمال المكتب',
            style: TextStyle(
              color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFEEF6FF) : Theme.of(context).colorScheme.onSurface),
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            trUi(office['name']?.toString().trim().isNotEmpty == true
                ? '${office['name']} · الأعمال المنشورة تظهر في الملف العام للمكتب.'
                : 'الأعمال المنشورة تظهر في الملف العام للمكتب وتخضع للفحص قبل النشر.'),
            style: TextStyle(
              color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant),
              fontSize: 11,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _metricTile(
                  icon: Icons.apartment_rounded,
                  iconColor: _officeAccentColor(context, const Color(0xFF00F2FE)),
                  value: '$worksCount عملاً',
                  label: 'منشور ومعتمد',
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _metricTile(
                  icon: Icons.star_rounded,
                  iconColor: _officeAccentColor(context, const Color(0xFFFFB95F)),
                  value: reviewsCount == 0 ? '—' : average.toStringAsFixed(1),
                  label: '$reviewsCount تقييماً موثقاً',
                ),
              ),
            ],
          ),
          if (reviewerNames.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: reviewerNames.take(8).map((name) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0x1410B981),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: const Color(0x3322C55E)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_rounded, size: 13, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text(
                        trUi(name.toString()),
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metricTile({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: _officeInsetColor(context, dark: const Color(0xD9080E1A)),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0x14FFFFFF)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(28),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: iconColor, size: 21),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trUi(value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                Text(
                  trUi(label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewSwitcher(int worksCount) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF080E1A) : Theme.of(context).colorScheme.surface),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? Color(0x1AFFFFFF) : Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _switchButton(
              active: _showForm,
              icon: Icons.add_circle_outline_rounded,
              label: 'إضافة عمل جديد',
              onTap: () => setState(() => _showForm = true),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _switchButton(
              active: !_showForm,
              icon: Icons.view_agenda_outlined,
              label: 'الأعمال المنشورة ($worksCount)',
              onTap: () => setState(() => _showForm = false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _switchButton({
    required bool active,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF0566D9) : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: active ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : AppColors.textSecondary)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                trUi(label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : AppColors.textSecondary),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _newWorkPanel({Key? key}) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _officeCardColor(context, dark: const Color(0xE6151C28)),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? Color(0x1AFFFFFF) : Theme.of(context).dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.diamond_outlined, color: Color(0xFF00F2FE), size: 18),
              SizedBox(width: 7),
              Expanded(
                child: TrText('إدراج مشروع هندسي جديد',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                'PORTFOLIO',
                style: TextStyle(fontSize: 9, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TrText('أضف الغلاف، تفاصيل العمل والمخططات أو ملفات BIM/CAD. سيُعرض العمل في الملف العام للمكتب بعد الحفظ.',
            style: TextStyle(fontSize: 11, height: 1.6, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () => _editWork(),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: _officeInsetColor(context, dark: const Color(0x99080E1A)),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x3338BDF8)),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: Color(0x2200F2FE),
                    child: Icon(Icons.add_a_photo_outlined, color: Color(0xFF00F2FE), size: 25),
                  ),
                  SizedBox(height: 10),
                  TrText('إضافة عمل جديد إلى مكتبة المكتب', style: TextStyle(fontWeight: FontWeight.w900)),
                  SizedBox(height: 5),
                  TrText('غلاف 16:9 · حتى 12 مرفقاً · JPG / PNG / PDF / DWG / DXF / IFC / RVT',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _editWork(),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0566D9), Color(0xFF00DCE6), Color(0xFFADC6FF)],
                ),
                boxShadow: const [
                  BoxShadow(color: Color(0x4400F2FE), blurRadius: 18, offset: Offset(0, 8)),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.publish_rounded, color: Color(0xFF080E1A)),
                  SizedBox(width: 7),
                  TrText('نشر عمل في مكتبة المكتب الرسمية',
                    style: TextStyle(color: Color(0xFF080E1A), fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _worksPanel({
    Key? key,
    required List<dynamic> works,
    required double average,
    required int reviewsCount,
    bool compact = false,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.circle, size: 8, color: Color(0xFF00F2FE)),
              const SizedBox(width: 7),
              const Expanded(
                child: TrText('الأعمال المعمارية المعتمدة',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ),
              TrText('${works.length} عمل',
                style: const TextStyle(color: Color(0xFF67E8F9), fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (works.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF0D1B31) : Theme.of(context).colorScheme.surface),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? Color(0x1AFFFFFF) : Theme.of(context).dividerColor)),
              ),
              child: Column(
                children: [
                  Icon(Icons.photo_library_outlined, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), size: 34),
                  SizedBox(height: 8),
                  TrText('لم يتم نشر أعمال للمكتب حتى الآن.', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
                ],
              ),
            )
          else
            ...works.map((raw) {
              final work = Map<String, dynamic>.from(raw as Map);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _managementWorkCard(
                  work: work,
                  average: average,
                  reviewsCount: reviewsCount,
                  compact: compact,
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _managementWorkCard({
    required Map<String, dynamic> work,
    required double average,
    required int reviewsCount,
    required bool compact,
  }) {
    final cover = work['cover_url']?.toString();
    final media = List<dynamic>.from(work['media'] as List? ?? const []);
    final location = work['location']?.toString() ?? '';
    final completedAt = work['completed_at']?.toString() ?? '';
    final description = work['description']?.toString() ?? '';

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _officeCardColor(context, dark: const Color(0xE6242A37)),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? Color(0x1AFFFFFF) : Theme.of(context).dividerColor)),
        boxShadow: const [
          BoxShadow(color: Color(0x2200F2FE), blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (cover?.isNotEmpty == true)
                  Image.network(
                    cover!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _workPlaceholder(),
                  )
                else
                  _workPlaceholder(),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xE6080E1A)],
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: _imageBadge(
                    icon: Icons.circle,
                    label: 'عمل منشور',
                    color: const Color(0xFF00F2FE),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: _imageBadge(
                    icon: Icons.star_rounded,
                    label: reviewsCount == 0 ? 'بدون تقييم' : average.toStringAsFixed(1),
                    color: const Color(0xFFFFB95F),
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: _imageBadge(
                    icon: Icons.folder_zip_outlined,
                    label: '${media.length} مرفق',
                    color: const Color(0xFFBFFBFF),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trUi(work['title']?.toString() ?? 'عمل'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                if (location.isNotEmpty || completedAt.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 12,
                    runSpacing: 5,
                    children: [
                      if (location.isNotEmpty)
                        _meta(Icons.location_on_outlined, location),
                      if (completedAt.isNotEmpty)
                        _meta(Icons.event_available_outlined, 'إنجاز: $completedAt'),
                    ],
                  ),
                ],
                if (description.isNotEmpty && !compact) ...[
                  const SizedBox(height: 9),
                  Text(
                    trUi(description),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), height: 1.5, fontSize: 11),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showWork(context, work),
                        icon: const Icon(Icons.visibility_outlined, size: 17),
                        label: const TrText('استعراض'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _editWork(work: work),
                        icon: const Icon(Icons.edit_outlined, size: 17),
                        label: const TrText('تعديل'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'حذف'.tr(),
                      onPressed: () => _deleteWork(
                        context,
                        int.parse(work['id'].toString()),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _workPlaceholder() {
    return ColoredBox(
      color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF080E1A) : Theme.of(context).scaffoldBackgroundColor),
      child: Center(
        child: Icon(Icons.architecture_rounded, size: 54, color: Color(0xFF3A494B)),
      ),
    );
  }

  Widget _imageBadge({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xE6080E1A),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(trUi(label), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 1),
        Icon(icon, size: 14, color: const Color(0xFF67E8F9)),
        const SizedBox(width: 4),
        Text(trUi(text), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 9)),
      ],
    );
  }

  Future<void> _showWork(BuildContext context, Map<String, dynamic> work) async {
    final media = List<dynamic>.from(work['media'] as List? ?? const []);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF0D1B31) : Theme.of(context).colorScheme.surface),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF58718F) : Theme.of(context).colorScheme.onSurfaceVariant), borderRadius: BorderRadius.circular(99)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(trUi(work['title']?.toString() ?? 'عمل'), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  if ((work['description']?.toString() ?? '').isNotEmpty)
                    Text(trUi(work['description'].toString()), style: TextStyle(height: 1.7, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
                  const SizedBox(height: 14),
                  TrText('${media.length} مرفق هندسي', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF67E8F9))),
                  if (media.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...media.map((raw) {
                      final item = Map<String, dynamic>.from(raw as Map);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.description_outlined),
                        title: Text(trUi(item['original_name']?.toString() ?? item['name']?.toString() ?? item['file_name']?.toString() ?? 'مرفق')),
                        subtitle: Text(trUi(item['mime_type']?.toString() ?? '')),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editWork({Map<String, dynamic>? work}) async {
    final isEditing = work != null;
    final title = TextEditingController(text: work?['title']?.toString() ?? '');
    final description = TextEditingController(text: work?['description']?.toString() ?? '');
    final location = TextEditingController(text: work?['location']?.toString() ?? '');
    final completedAt = TextEditingController(text: work?['completed_at']?.toString() ?? '');
    File? cover;
    final newMedia = <File>[];
    final existingMedia = List<dynamic>.from(work?['media'] as List? ?? const []);
    final removeMediaIds = <int>{};
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _officeCardColor(context, dark: const Color(0xFF151C28)),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Directionality(
            textDirection: AppLanguage.instance.textDirection,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 18,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF58718F) : Theme.of(context).colorScheme.onSurfaceVariant), borderRadius: BorderRadius.circular(99)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        trUi(isEditing ? 'تعديل العمل الهندسي' : 'إدراج مشروع هندسي جديد'),
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: title,
                        decoration: InputDecoration(labelText: 'عنوان المشروع / العمل الهيكلي *'.tr()),
                      ),
                      const SizedBox(height: 10),
                      TextField(controller: location, decoration: InputDecoration(labelText: 'الموقع الجغرافي للمشروع'.tr())),
                      const SizedBox(height: 10),
                      TextField(
                        controller: completedAt,
                        readOnly: true,
                        onTap: () async {
                          final initial = DateTime.tryParse(completedAt.text) ?? DateTime.now();
                          final picked = await showDatePicker(
                            context: sheetContext,
                            initialDate: initial,
                            firstDate: DateTime(1950),
                            lastDate: DateTime.now().add(const Duration(days: 3650)),
                          );
                          if (picked != null) {
                            setSheetState(() {
                              completedAt.text = '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                            });
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'تاريخ الإنجاز والاعتماد'.tr(),
                          suffixIcon: Icon(Icons.calendar_month_outlined),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: description,
                        maxLines: 4,
                        decoration: InputDecoration(labelText: 'الوصف المعماري والحلول الإنشائية'.tr()),
                      ),
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: () async {
                          final picked = await FilePicker.pickFile(type: FileType.image);
                          if (picked?.path != null) {
                            setSheetState(() => cover = File(picked!.path!));
                          }
                        },
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
                          decoration: BoxDecoration(
                            color: _officeInsetColor(context, dark: const Color(0x99080E1A)),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0x3338BDF8)),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.add_a_photo_outlined, color: Color(0xFF00F2FE), size: 30),
                              const SizedBox(height: 7),
                              Text(
                                trUi(cover != null ? 'تم اختيار صورة غلاف جديدة' : 'الغلاف المعماري الرئيسي (Hero View)'),
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 3),
                              TrText('JPG / PNG / WEBP · حتى 15MB · النسبة المثالية 16:9', style: TextStyle(fontSize: 9, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await FilePicker.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf', 'dwg', 'dxf', 'ifc', 'rvt'],
                          );
                          if (picked.isEmpty) return;
                          setSheetState(() {
                            newMedia
                              ..clear()
                              ..addAll(
                                picked
                                    .where((file) => file.path != null)
                                    .take(12)
                                    .map((file) => File(file.path!)),
                              );
                          });
                        },
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: Text(trUi(newMedia.isEmpty ? 'إرفاق CAD / BIM / PDF / صور' : '${newMedia.length} مرفق جديد مختار')),
                      ),
                      if (existingMedia.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const TrText('المرفقات الحالية — حدد ما تريد حذفه', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 5),
                        ...existingMedia.map((raw) {
                          final item = Map<String, dynamic>.from(raw as Map);
                          final id = int.tryParse(item['id']?.toString() ?? '');
                          if (id == null) return const SizedBox.shrink();
                          return CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: removeMediaIds.contains(id),
                            onChanged: (value) {
                              setSheetState(() {
                                if (value == true) {
                                  removeMediaIds.add(id);
                                } else {
                                  removeMediaIds.remove(id);
                                }
                              });
                            },
                            title: Text(trUi(item['original_name']?.toString() ?? item['name']?.toString() ?? item['file_name']?.toString() ?? 'مرفق #$id'), style: const TextStyle(fontSize: 11)),
                            secondary: const Icon(Icons.description_outlined, size: 18),
                          );
                        }),
                      ],
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: saving
                            ? null
                            : () async {
                                if (title.text.trim().isEmpty) {
                                  widget.toast('اكتب عنوان العمل.');
                                  return;
                                }
                                setSheetState(() => saving = true);
                                try {
                                  final message = isEditing
                                      ? await ApiService.updateOfficePortfolioWork(
                                          workId: int.parse(work['id'].toString()),
                                          title: title.text,
                                          description: description.text,
                                          location: location.text,
                                          completedAt: completedAt.text,
                                          cover: cover,
                                          media: newMedia,
                                          removeMediaIds: removeMediaIds.toList(),
                                        )
                                      : await ApiService.createOfficePortfolioWork(
                                          title: title.text,
                                          description: description.text,
                                          location: location.text,
                                          completedAt: completedAt.text,
                                          cover: cover,
                                          media: newMedia,
                                        );
                                  if (!sheetContext.mounted) return;
                                  Navigator.pop(sheetContext);
                                  widget.toast(message);
                                  await widget.onChanged();
                                } on ApiException catch (e) {
                                  widget.toast(e.message);
                                  if (sheetContext.mounted) setSheetState(() => saving = false);
                                } catch (_) {
                                  widget.toast('تعذر حفظ العمل. حاول مرة أخرى.');
                                  if (sheetContext.mounted) setSheetState(() => saving = false);
                                }
                              },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(colors: [Color(0xFF0566D9), Color(0xFF00DCE6), Color(0xFFADC6FF)]),
                          ),
                          child: Center(
                            child: saving
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF080E1A)))
                                : Text(
                                    trUi(isEditing ? 'حفظ تعديلات العمل' : 'نشر العمل في مكتبة المكتب الرسمية'),
                                    style: const TextStyle(color: Color(0xFF080E1A), fontWeight: FontWeight.w900),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TrText('يخضع النص والمرفقات لفحص المنصة قبل الحفظ والنشر.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 9, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    title.dispose();
    description.dispose();
    location.dispose();
    completedAt.dispose();
  }

  Future<void> _deleteWork(BuildContext context, int workId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: AlertDialog(
          title: const TrText('حذف العمل'),
          content: const TrText('هل تريد حذف هذا العمل من مكتبة المكتب؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const TrText('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const TrText('حذف')),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    try {
      final message = await ApiService.deleteOfficePortfolioWork(workId);
      widget.toast(message);
      await widget.onChanged();
    } on ApiException catch (e) {
      widget.toast(e.message);
    }
  }
}


class _MiniStat extends StatelessWidget {
  final String label;
  final dynamic value;
  final IconData icon;

  const _MiniStat(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.dark ? Color(0x0DFFFFFF) : Theme.of(context).colorScheme.surface),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? Color(0x1AFFFFFF) : Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Icon(icon, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${value ?? 0}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                Text(trUi(label), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(99)),
      child: Text(trUi(text), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800)),
    );
  }
}

Future<String?> _askText(BuildContext context, String title, {String initial = '', int maxLines = 1}) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: AlertDialog(
        title: Text(trUi(title)),
        content: TextField(controller: controller, maxLines: maxLines, autofocus: true, decoration: InputDecoration(labelText: trUiN(title))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const TrText('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text), child: const TrText('تأكيد')),
        ],
      ),
    ),
  );
  Future<void>.delayed(const Duration(milliseconds: 600), controller.dispose);
  return result;
}

Future<int?> _chooseEngineer(BuildContext context, List<dynamic> engineers, int? currentId) async {
  int? selected = currentId ?? (engineers.isNotEmpty ? int.tryParse((engineers.first as Map)['id'].toString()) : null);
  return showDialog<int>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => Directionality(
        textDirection: AppLanguage.instance.textDirection,
        child: AlertDialog(
          title: const TrText('تعيين مهندس'),
          content: DropdownButtonFormField<int>(
            initialValue: selected,
            decoration: InputDecoration(labelText: 'المهندس'.tr()),
            items: engineers.map((raw) {
              final engineer = Map<String, dynamic>.from(raw as Map);
              return DropdownMenuItem<int>(
                value: int.parse(engineer['id'].toString()),
                child: Text(trUi(engineer['name']?.toString() ?? 'مهندس')),
              );
            }).toList(),
            onChanged: (value) => setState(() => selected = value),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const TrText('إلغاء')),
            FilledButton(onPressed: selected == null ? null : () => Navigator.pop(dialogContext, selected), child: const TrText('تعيين')),
          ],
        ),
      ),
    ),
  );
}

String _initial(String? value) {
  final text = value?.trim() ?? '';
  return text.isEmpty ? '?' : text.substring(0, 1);
}

String _roleLabel(String? role) => switch (role) {
      'owner' => 'مالك',
      'manager' => 'مدير',
      'engineer' => 'مهندس',
      'employee' => 'موظف',
      _ => role ?? '',
    };

String _appStatus(String? status) => switch (status) {
      'pending' => 'قيد المراجعة',
      'approved' => 'مقبول',
      'rejected' => 'مرفوض',
      _ => status ?? '—',
    };

String _subscriptionStatus(String? status) => switch (status) {
      'under_review' => 'قيد المراجعة',
      'active' => 'فعال',
      'rejected' => 'مرفوض',
      'expired' => 'منتهي',
      'pending' => 'بانتظار الدفع',
      _ => status ?? '—',
    };

String _dateOnly(dynamic value) {
  if (value == null) return '—';
  final text = value.toString();
  return text.length >= 10 ? text.substring(0, 10) : text;
}
