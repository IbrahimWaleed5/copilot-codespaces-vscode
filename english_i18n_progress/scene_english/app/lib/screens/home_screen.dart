import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../i18n/localized_text.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../services/push_notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/verified_name.dart';
import 'create_consultation_screen.dart';
import 'consultations_screen.dart';
import 'account_center_screen.dart';
import 'engineer_library_screen.dart';
import 'engineer_directory_screen.dart';
import 'engineer_profile_screen.dart';
import 'engineer_work_detail_screen.dart';
import 'engineering_offices_screen.dart';
import 'marketplace_projects_screen.dart';
import 'login_screen.dart';
import 'notifications_screen.dart';
import 'office_application_screen.dart';
import 'office_management_screen.dart';
import 'platform_feedback_screen.dart';
import 'professional_verification_screen.dart';
import 'projects_screen.dart';
import 'register_screen.dart';
import 'ai_entry_screen.dart';
import 'welcome_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onOpenProjects;
  final Map<String, dynamic>? initialData;
  final String? initialError;

  const HomeScreen({
    super.key,
    this.onOpenProjects,
    this.initialData,
    this.initialError,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  final ScrollController _scrollController = ScrollController();
  int _standaloneTabIndex = 0;

  static const _services = <_ServiceData>[
    _ServiceData('التصميم المعماري', 'تصاميم عصرية تجمع بين الجمال والوظيفة.', Icons.architecture_outlined),
    _ServiceData('التصميم الإنشائي', 'دراسات إنشائية دقيقة تدعم أمان واستدامة المبنى.', Icons.apartment_outlined),
    _ServiceData('التصميم الكهربائي', 'أنظمة كهربائية ذكية وآمنة تدعم كفاءة الطاقة.', Icons.electric_bolt_outlined),
    _ServiceData('الهندسة الميكانيكية', 'التكييف والتهوية والصرف الصحي ومكافحة الحريق.', Icons.settings_outlined),
    _ServiceData('الحلول البرمجية', 'تطوير أنظمة إدارة وربط العمليات التقنية بالعمل الميداني.', Icons.code_outlined),
    _ServiceData('التصميم الداخلي', 'ابتكار مساحات داخلية جميلة وعملية.', Icons.chair_outlined),
    _ServiceData('استشارات تقنية', 'مراجعة المخططات وحل المشكلات التخصصية.', Icons.support_agent_outlined),
    _ServiceData('تصميم الواجهات', 'واجهات حديثة تجمع الهوية الجمالية والوظيفة.', Icons.view_quilt_outlined),
    _ServiceData('تصميم اللاند سكيب', 'حدائق ومساحات خارجية وممرات وجلسات تحقق الراحة والاستدامة.', Icons.park_outlined),
  ];

  @override
  void initState() {
    super.initState();

    if (widget.initialData != null) {
      _data = Map<String, dynamic>.from(widget.initialData!);
      _error = widget.initialError;
      _loading = false;

      // البيانات الأساسية جُهزت داخل Splash. نكمل القوائم الاختيارية
      // بهدوء بعد أول Frame من دون إعادة الصفحة إلى شاشة تحميل.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _hydrateInitialDataSilently();
      });
    } else if (widget.initialError != null) {
      _error = widget.initialError;
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _hydrateInitialDataSilently() async {
    final current = _data;
    if (current == null) return;

    final data = Map<String, dynamic>.from(current);
    await _hydratePublicHomeCollections(data);

    if (!mounted) return;
    setState(() => _data = data);
  }

  Future<void> _load() async {
    final hasVisibleData = _data != null;

    if (mounted) {
      setState(() {
        // عند وجود محتوى معروض، التحديث يكون صامتًا ولا نستبدل
        // الصفحة كلها بـ CircularProgressIndicator.
        _loading = !hasVisibleData;
        _error = null;
      });
    }

    try {
      final data = Map<String, dynamic>.from(await ApiService.fetchHome());

      // /api/home used to hide engineers/offices unless their professional
      // verification was active. The public directory itself contains the
      // active records, so use it as a safe fallback instead of showing an
      // empty section while data exists on the platform.
      await _hydratePublicHomeCollections(data);

      if (!mounted) return;
      setState(() => _data = data);
    } on ApiException catch (e) {
      AppFeedback.error(e.message);
      if (!mounted) return;
      if (_data == null) {
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (!mounted) return;
      if (_data == null) {
        setState(() => _error = 'تعذر تحميل الصفحة الرئيسية.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _hydratePublicHomeCollections(
    Map<String, dynamic> data,
  ) async {
    final engineers = List<dynamic>.from(
      data['featured_engineers'] as List? ?? const [],
    );
    if (engineers.isEmpty) {
      try {
        final payload = await ApiService.fetchEngineers(
          page: 1,
          verified: false,
          sort: 'rating',
        );
        final items = _responseDataList(payload);
        if (items.isNotEmpty) {
          data['featured_engineers'] = items.take(6).toList();
        }
      } catch (_) {
        // Keep the home response usable if one optional public endpoint fails.
      }
    }

    final offices = List<dynamic>.from(
      data['featured_offices'] as List? ?? const [],
    );
    if (offices.isEmpty) {
      try {
        final payload = await ApiService.fetchOffices(
          status: 'active',
          verified: false,
          sort: 'rating',
        );
        final items = _responseDataList(payload);
        if (items.isNotEmpty) {
          data['featured_offices'] = items.take(6).toList();
        }
      } catch (_) {
        // Do not turn the whole home page into an error for an optional list.
      }
    }

    final engineerWorks = List<dynamic>.from(
      data['latest_works'] as List? ?? const [],
    );
    if (engineerWorks.isEmpty) {
      try {
        final payload = await ApiService.fetchWorkLibrary(
          provider: 'engineers',
          verified: false,
        );
        final items = _responseDataList(payload)
            .map((item) => _normalizePublicWork(item, providerType: 'engineer'))
            .whereType<Map<String, dynamic>>()
            .take(6)
            .toList();
        if (items.isNotEmpty) data['latest_works'] = items;
      } catch (_) {
        // Same graceful fallback as the other public sections.
      }
    }

    final officeWorks = List<dynamic>.from(
      data['latest_office_works'] as List? ?? const [],
    );
    if (officeWorks.isEmpty) {
      try {
        final payload = await ApiService.fetchWorkLibrary(
          provider: 'offices',
          verified: false,
        );
        final items = _responseDataList(payload)
            .map((item) => _normalizePublicWork(item, providerType: 'office'))
            .whereType<Map<String, dynamic>>()
            .take(6)
            .toList();
        if (items.isNotEmpty) data['latest_office_works'] = items;
      } catch (_) {
        // An empty office portfolio must not hide the other home content.
      }
    }
  }

  List<dynamic> _responseDataList(Map<String, dynamic> payload) {
    final value = payload['data'];
    if (value is List) return List<dynamic>.from(value);
    if (value is Map && value['data'] is List) {
      return List<dynamic>.from(value['data'] as List);
    }
    return const <dynamic>[];
  }

  Map<String, dynamic>? _normalizePublicWork(
    dynamic raw, {
    required String providerType,
  }) {
    if (raw is! Map) return null;
    final item = Map<String, dynamic>.from(raw);
    final provider = item['provider'];
    final providerMap = provider is Map
        ? Map<String, dynamic>.from(provider)
        : <String, dynamic>{};

    item['provider_type'] = providerType;
    if (providerType == 'office') {
      item['office'] ??= providerMap;
    } else {
      item['engineer'] ??= providerMap;
    }
    return item;
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool get _embeddedInDashboard => widget.onOpenProjects != null;

  void _selectStandaloneTab(int index) {
    if (_embeddedInDashboard || !mounted) return;
    setState(() => _standaloneTabIndex = index);
  }

  void _openProjectsFromHome() {
    if (_embeddedInDashboard) {
      widget.onOpenProjects?.call();
      return;
    }

    _selectStandaloneTab(3);

    if (context.read<AuthProvider>().user == null) {
      AppFeedback.info(
        'سجّل الدخول أولًا لإنشاء مشروع أو متابعة مشاريعك.',
      );
    }
  }

  void _openNotificationsSafely() {
    if (context.read<AuthProvider>().user == null) {
      _selectStandaloneTab(4);
      AppFeedback.info(
        'الإشعارات مرتبطة بحسابك. سجّل الدخول أولًا.',
      );
      return;
    }

    _open(const NotificationsScreen());
  }

  Widget _loginRequiredPanel({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Scaffold(
      backgroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF071426) : Theme.of(context).scaffoldBackgroundColor),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0A172B) : Theme.of(context).colorScheme.surface),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: const Color(0x223B82F6),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: const Color(0x143B82F6),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      icon,
                      color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF67E8F9) : const Color(0xFF0E7490)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    trUi(title),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    trUi(message),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant),
                      height: 1.7,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _open(const LoginScreen()),
                      icon: const Icon(Icons.login_rounded),
                      label: const TrText('تسجيل الدخول',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _open(const RegisterScreen()),
                      child: const TrText('إنشاء حساب جديد'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeScaffold(String? role) {
    return Scaffold(
      backgroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF071426) : Theme.of(context).scaffoldBackgroundColor),
      body: Stack(
        children: [
          const Positioned.fill(
            child: _HomeBackground(),
          ),
          SafeArea(
            child: RefreshIndicator(
              color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8)),
              backgroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0A172B) : Theme.of(context).colorScheme.surface),
              onRefresh: _load,
              child: _loading
                  ? const _LoadingHome()
                  : _error != null
                      ? _HomeError(
                          message: _error!,
                          onRetry: _load,
                        )
                      : _buildContent(role),
            ),
          ),
        ],
      ),
    );
  }

  Widget _standaloneBody(String? role) {
    final user = context.watch<AuthProvider>().user;

    return IndexedStack(
      index: _standaloneTabIndex,
      children: [
        _buildHomeScaffold(role),
        const EngineerLibraryScreen(),
        user != null
            ? const ConsultationsScreen()
            : _loginRequiredPanel(
                icon: Icons.description_outlined,
                title: 'الاستشارات مرتبطة بحسابك',
                message:
                    'سجّل الدخول لعرض استشاراتك وإنشاء استشارة جديدة.',
              ),
        user != null
            ? const ProjectsScreen()
            : _loginRequiredPanel(
                icon: Icons.architecture_outlined,
                title: 'ابدأ مشروعك من قائمة المشاريع',
                message:
                    'بعد تسجيل الدخول ستفتح قائمة مشاريعك، ومن داخلها زر إنشاء مشروع جديد. لن يتم تحويلك إلى سوق المشاريع.',
              ),
        user != null
            ? const AccountCenterScreen()
            : _loginRequiredPanel(
                icon: Icons.person_outline_rounded,
                title: 'حسابك',
                message:
                    'سجّل الدخول للوصول إلى الحساب والإشعارات والأمان والباقات.',
              ),
      ],
    );
  }

  Widget _standaloneBottomNavigationBar() {
    return SafeArea(
      top: false,
      maintainBottomViewPadding: true,
      child: Container(
        decoration: BoxDecoration(
          color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF081326) : Theme.of(context).scaffoldBackgroundColor),
          border: Border(
            top: BorderSide(
              color: Color(0x243B82F6),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 18,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _standaloneTabIndex,
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          backgroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF081326) : Theme.of(context).scaffoldBackgroundColor),
          selectedItemColor: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF38BDF8) : AppColors.accentCyan),
          unselectedItemColor: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : AppColors.textSecondary),
          selectedLabelStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
          onTap: _selectStandaloneTab,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              activeIcon: const Icon(Icons.home_rounded),
              label: 'الرئيسية'.tr(),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.grid_view_outlined),
              activeIcon: const Icon(Icons.grid_view_rounded),
              label: 'الأعمال'.tr(),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.description_outlined),
              activeIcon: const Icon(Icons.description_rounded),
              label: 'الاستشارات'.tr(),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.architecture_outlined),
              activeIcon: const Icon(Icons.architecture_rounded),
              label: 'المشاريع'.tr(),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person_outline_rounded),
              activeIcon: const Icon(Icons.person_rounded),
              label: 'حسابي'.tr(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final role = user?.role;

    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: _embeddedInDashboard
          ? _buildHomeScaffold(role)
          : Scaffold(
              backgroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF071426) : Theme.of(context).scaffoldBackgroundColor),
              body: _standaloneBody(role),
              bottomNavigationBar:
                  _standaloneBottomNavigationBar(),
            ),
    );
  }

  Widget _buildContent(String? role) {
    final stats = Map<String, dynamic>.from(
      _data?['statistics'] as Map? ?? const <String, dynamic>{},
    );
    final works = <dynamic>[
      ...List<dynamic>.from(_data?['latest_works'] as List? ?? const []),
      ...List<dynamic>.from(_data?['latest_office_works'] as List? ?? const []),
    ];
    final engineers = List<dynamic>.from(_data?['featured_engineers'] as List? ?? const []);
    final offices = List<dynamic>.from(_data?['featured_offices'] as List? ?? const []);

    final sections = <Widget>[
      _BrandBar(
        onAssistant: () => _open(
          const AiEntryScreen(
            sourceRoute: 'flutter_home_assistant',
            sourceTitle: 'المساعد الذكي من الصفحة الرئيسية',
          ),
        ),
        onNotifications: _openNotificationsSafely,
      ),
      _WelcomeJourneyCard(
        onOpenJourney: () => _open(const WelcomeScreen()),
        onPrimary: _openProjectsFromHome,
        onSecondary: () => _open(const EngineerLibraryScreen()),
      ),
      _PublicStats(stats: stats),
      _ActionShowcase(
        onConsultation: () => _open(const CreateConsultationScreen()),
        onLibrary: () => _open(const EngineerLibraryScreen()),
        onMarketplace: () => _open(const MarketplaceProjectsScreen()),
      ),
      if (role != null)
        _ProfessionalAccountActions(
          role: role,
          onEngineers: () => _open(const EngineerDirectoryScreen()),
          onOffices: () => _open(const EngineeringOfficesScreen()),
          onOfficeApplication: () => _open(const OfficeApplicationScreen()),
          onOfficeManagement: () => _open(const OfficeManagementScreen()),
          onVerification: () => _open(const ProfessionalVerificationScreen()),
        ),
      const _WhyUsSection(),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HomeSectionTitle(
            title: 'خدماتنا الهندسية المتكاملة'.tr(),
            subtitle: 'حلول هندسية تغطي احتياجات مشروعك من التخطيط إلى التنفيذ.'.tr(),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 182,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _services.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, index) => _ServiceCard(data: _services[index]),
            ),
          ),
        ],
      ),
      const _JourneySection(),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HomeSectionTitle(
            title: 'أحدث الأعمال',
            subtitle: 'نماذج من الأعمال الهندسية المعتمدة على المنصة.',
            actionLabel: 'عرض الجميع',
            onAction: () => _open(const EngineerLibraryScreen()),
          ),
          const SizedBox(height: 14),
          if (works.isEmpty)
            _HomeEmpty(text: 'لا توجد أعمال منشورة حاليًا.'.tr())
          else
            SizedBox(
              height: 258,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: works.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, index) {
                  final work = Map<String, dynamic>.from(works[index] as Map);
                  return _WorkCard(
                    work: work,
                    onTap: () {
                      if (work['provider_type']?.toString() == 'office') {
                        final office = work['office'] as Map?;
                        final slug = office?['slug']?.toString();
                        if (slug != null && slug.isNotEmpty) {
                          _open(OfficeDetailScreen(slug: slug));
                        }
                        return;
                      }
                      final id = work['id'];
                      if (id is int) {
                        _open(EngineerWorkDetailScreen(workId: id));
                      }
                    },
                  );
                },
              ),
            ),
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HomeSectionTitle(
            title: 'نخبة المهندسين',
            subtitle: 'تعاون مع مهندسين معتمدين وخبرات متنوعة.',
            actionLabel: 'عرض الجميع',
            onAction: () => _open(const EngineerDirectoryScreen()),
          ),
          const SizedBox(height: 14),
          if (engineers.isEmpty)
            _HomeEmpty(text: 'لا يوجد مهندسون ظاهرون حاليًا.'.tr())
          else
            ...engineers.map((item) {
              final engineer = Map<String, dynamic>.from(item as Map);
              return _EngineerCard(
                engineer: engineer,
                onTap: () {
                  final id = engineer['id'];
                  if (id is int) {
                    _open(EngineerProfileScreen(engineerId: id));
                  }
                },
              );
            }),
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HomeSectionTitle(
            title: 'المكاتب الهندسية',
            subtitle: 'مكاتب نشطة على المنصة، مع إبراز المكاتب الموثقة أولًا.',
            actionLabel: 'عرض الدليل',
            onAction: () => _open(const EngineeringOfficesScreen()),
          ),
          const SizedBox(height: 14),
          if (offices.isEmpty)
            _HomeEmpty(text: 'لا توجد مكاتب معتمدة ظاهرة حاليًا.'.tr())
          else
            SizedBox(
              height: 220,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: offices.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, index) {
                  final office = Map<String, dynamic>.from(offices[index] as Map);
                  return _FeaturedOfficeCard(
                    office: office,
                    onTap: () {
                      final slug = office['slug']?.toString();
                      if (slug != null && slug.isNotEmpty) {
                        _open(OfficeDetailScreen(slug: slug));
                      }
                    },
                  );
                },
              ),
            ),
        ],
      ),
      _FeedbackShowcase(onTap: () => _open(const PlatformFeedbackScreen())),
      _MarketClosingBanner(onTap: () => _open(const MarketplaceProjectsScreen())),
    ];

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
      cacheExtent: 900,
      padding: const EdgeInsets.only(top: 10, bottom: 34),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final isHero = index == 1;
        final content = isHero
            ? sections[index]
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: sections[index],
              );

        return RepaintBoundary(
          child: Padding(
            padding: EdgeInsets.only(bottom: index == sections.length - 1 ? 0 : 28),
            child: content,
          ),
        );
      },
    );
  }
}

class _HomeBackground extends StatelessWidget {
  const _HomeBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [(Theme.of(context).brightness == Brightness.dark ? Color(0xFF040B16) : Color(0xFFF5F8FE)), (Theme.of(context).brightness == Brightness.dark ? Color(0xFF071426) : Color(0xFFF5F8FE)), (Theme.of(context).brightness == Brightness.dark ? Color(0xFF09172B) : Color(0xFFFFFFFF))],
            ),
          ),
          child: SizedBox.expand(),
        ),
        Positioned(
          top: -90,
          right: -90,
          child: _GlowOrb(size: 260, color: Color(0x332563EB)),
        ),
        Positioned(
          top: 420,
          left: -120,
          child: _GlowOrb(size: 300, color: Color(0x203B82F6)),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, Colors.transparent]),
        ),
      ),
    );
  }
}

class _BrandBar extends StatelessWidget {
  final VoidCallback onAssistant;
  final VoidCallback onNotifications;

  const _BrandBar({
    required this.onAssistant,
    required this.onNotifications,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xF0040B16) : const Color(0xFFFFFFFF)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x333B82F6)),
            boxShadow: const [
              BoxShadow(color: Color(0x26001946), blurRadius: 18, offset: Offset(0, 8)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0x292563EB),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: const Color(0x3D60A5FA)),
                ),
                child: Icon(Icons.home_work_outlined, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF93C5FD) : Color(0xFF1D4ED8))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TrText('منصة الوليد الهندسية',
                      style: TextStyle(
                        color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFEEF6FF) : Theme.of(context).colorScheme.onSurface),
                        fontWeight: FontWeight.w900,
                        fontSize: 15.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    TrText('حلول هندسية متكاملة',
                      style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF8FAECC) : const Color(0xFF475569)), fontSize: 9.5),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0x1F10B981),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x3310B981)),
                ),
                child: IconButton(
                  onPressed: onAssistant,
                  icon: Icon(Icons.auto_awesome_rounded, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF6EE7B7) : Color(0xFF047857))),
                  tooltip: 'المساعد الذكي'.tr(),
                ),
              ),
              const SizedBox(width: 7),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0x1F2563EB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x2E60A5FA)),
                ),
                child: ValueListenableBuilder<int>(
                  valueListenable: PushNotificationService.unreadCountNotifier,
                  builder: (context, unreadCount, _) {
                    final icon = Icon(
                      Icons.notifications_none_rounded,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFBFDBFE)
                          : const Color(0xFF1D4ED8),
                    );
                    return IconButton(
                      onPressed: onNotifications,
                      icon: unreadCount > 0
                          ? Badge.count(
                              count: unreadCount,
                              child: icon,
                            )
                          : icon,
                      tooltip: 'الإشعارات'.tr(),
                    );
                  },
                ),
              ),
            ],
          ),
    );
  }
}

class _WelcomeJourneyCard extends StatelessWidget {
  final VoidCallback onOpenJourney;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  const _WelcomeJourneyCard({
    required this.onOpenJourney,
    required this.onPrimary,
    required this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14),
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [(Theme.of(context).brightness == Brightness.dark ? Color(0xFF0F2F4F) : Color(0xFFE9F0FA)), (Theme.of(context).brightness == Brightness.dark ? Color(0xFF132F49) : Color(0xFFE9F0FA)), (Theme.of(context).brightness == Brightness.dark ? Color(0xFF071426) : Color(0xFFF5F8FE))],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? const Color(0x55F3EEE4) : const Color(0xFFCBD5E1))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TrText('نرافق مبناك من المخطط إلى الحديقة',
              style: TextStyle(
                color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFF3EEE4) : const Color(0xFF0F172A)),
                fontSize: 28,
                height: 1.25,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            TrText('شاهد رحلة المشروع السينمائية الكاملة بسلاسة، ثم اختر المهندس المناسب لكل مرحلة.',
              style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xDDF3EEE4) : const Color(0xFF475569)), height: 1.7, fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onOpenJourney,
                    style: FilledButton.styleFrom(
                      backgroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFF3EEE4) : const Color(0xFF2563EB)),
                      foregroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0F2F4F) : Colors.white),
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const TrText('مشاهدة رحلة المشروع', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onPrimary,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFF3EEE4) : const Color(0xFF1D4ED8)),
                      side: const BorderSide(color: Color(0x88F3EEE4)),
                      minimumSize: const Size.fromHeight(42),
                    ),
                    child: const TrText('ابدأ مشروعك'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSecondary,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFF3EEE4) : const Color(0xFF1D4ED8)),
                      side: const BorderSide(color: Color(0x55F3EEE4)),
                      minimumSize: const Size.fromHeight(42),
                    ),
                    child: const TrText('مكتبة الأعمال'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroSection extends StatefulWidget {
  final String? role;
  final ScrollController scrollController;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  const _HeroSection({
    required this.role,
    required this.scrollController,
    required this.onPrimary,
    required this.onSecondary,
  });

  @override
  State<_HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<_HeroSection> {

  final GlobalKey _trackKey = GlobalKey();
  WebViewController? _webController;
  String _sceneLang = AppLanguage.instance.code;

  double _progress = 0;
  double _stageShift = 0;
  double _lastSentProgress = -1;
  bool _pageReady = false;
  bool _webGlReady = false;

  bool get _supportsEmbeddedWebView =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_handleParentScroll);
    AppLanguage.instance.addListener(_onLanguageChanged);
    _prepareWebView();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleParentScroll());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _webController?.setBackgroundColor(
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0F2F4F)
          : const Color(0xFFE9F0FA),
    );
  }

  @override
  void didUpdateWidget(covariant _HeroSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_handleParentScroll);
      widget.scrollController.addListener(_handleParentScroll);
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleParentScroll());
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_handleParentScroll);
    AppLanguage.instance.removeListener(_onLanguageChanged);
    super.dispose();
  }

  // The scene HTML reads the language from the user agent, so a language
  // switch while this screen is open updates it and reloads the scene.
  Future<void> _onLanguageChanged() async {
    final code = AppLanguage.instance.code;
    final controller = _webController;
    if (!mounted || controller == null || code == _sceneLang) return;
    _sceneLang = code;
    await controller.setUserAgent('AlWaleedFlutter/1.0 AlWaleedLang/${AppLanguage.instance.code}');
    await controller.reload();
  }

  void _prepareWebView() {
    if (!_supportsEmbeddedWebView) return;

    final controller = WebViewController();
    controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    controller.setBackgroundColor(const Color(0xFFE9F0FA));
    controller.setUserAgent('AlWaleedFlutter/1.0 AlWaleedLang/${AppLanguage.instance.code}');
    controller.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (_) async {
          var webGlReady = false;
          try {
            final result = await controller.runJavaScriptReturningResult(
              'typeof THREE !== "undefined"',
            );
            webGlReady = result.toString().toLowerCase().contains('true');
          } catch (_) {
            webGlReady = false;
          }

          if (!mounted) return;
          setState(() {
            _pageReady = true;
            _webGlReady = webGlReady;
          });
          _syncWebProgress(force: true);
        },
      ),
    );
    _webController = controller;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      controller.setBackgroundColor(
        Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF0F2F4F)
            : const Color(0xFFE9F0FA),
      );
    });
    controller.loadFlutterAsset(
      'assets/web/building-scroll-hero/index.html',
    );
  }

  double _stageHeight(BuildContext context) {
    final media = MediaQuery.of(context);
    return math.max(
      420.0,
      media.size.height - media.padding.top - media.padding.bottom,
    ).toDouble();
  }

  static double _range(double value, double start, double end) {
    if (end <= start) return value >= end ? 1 : 0;
    return ((value - start) / (end - start)).clamp(0.0, 1.0).toDouble();
  }

  void _handleParentScroll() {
    if (!mounted) return;
    final trackContext = _trackKey.currentContext;
    if (trackContext == null) return;
    final renderObject = trackContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;

    final media = MediaQuery.of(trackContext);
    final stageHeight = _stageHeight(trackContext);
    final maxTravel = math.max(1.0, renderObject.size.height - stageHeight);
    final top = renderObject.localToGlobal(Offset.zero).dy;
    final stickyTop = media.padding.top;
    final shift = (stickyTop - top).clamp(0.0, maxTravel).toDouble();
    final progress = (shift / maxTravel).clamp(0.0, 1.0).toDouble();

    final needsRebuild =
        (progress - _progress).abs() > .00035 ||
        (shift - _stageShift).abs() > .35;
    if (!needsRebuild) return;

    setState(() {
      _progress = progress;
      _stageShift = shift;
    });
    _syncWebProgress();
  }

  void _syncWebProgress({bool force = false}) async {
    final controller = _webController;
    if (controller == null || !_pageReady || !_webGlReady) return;
    if (!force && (_progress - _lastSentProgress).abs() < .0012) return;

    _lastSentProgress = _progress;
    try {
      await controller.runJavaScript(
        'window.flutterSetProgress && window.flutterSetProgress(${_progress.toStringAsFixed(6)});',
      );
    } catch (_) {
      // The native fallback remains visible if the embedded scene becomes unavailable.
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final stageHeight = _stageHeight(context);
    final trackHeight = stageHeight * 9;
    final compact = screen.width < 720;
    // أثناء رحلة البناء لا يظهر أي نص؛ النص والأزرار يظهران فقط عند النهاية.
    final heroOpacity = _range(_progress, .955, .985);

    return SizedBox(
      key: _trackKey,
      height: trackHeight,
      child: ClipRect(
        child: Stack(
          children: [
            Transform.translate(
              offset: Offset(0, _stageShift),
              child: SizedBox(
                width: double.infinity,
                height: stageHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _BuildingSceneSurface(
                      progress: _progress,
                      controller: _webController,
                      pageReady: _pageReady,
                      webGlReady: _webGlReady,
                    ),
                    _BuildingHeroCopy(
                      opacity: heroOpacity,
                      compact: compact,
                      role: widget.role,
                      onPrimary: widget.onPrimary,
                      onSecondary: widget.onSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BuildingSceneSurface extends StatelessWidget {
  final double progress;
  final WebViewController? controller;
  final bool pageReady;
  final bool webGlReady;

  const _BuildingSceneSurface({
    required this.progress,
    required this.controller,
    required this.pageReady,
    required this.webGlReady,
  });

  @override
  Widget build(BuildContext context) {
    final showWeb = controller != null && pageReady && webGlReady;

    return Stack(
      fit: StackFit.expand,
      children: [
        _NativeBuildingFallback(progress: progress),
        if (showWeb)
          IgnorePointer(
            child: WebViewWidget(controller: controller!),
          ),
        if (controller != null && !pageReady)
          const Positioned(
            left: 16,
            bottom: 16,
            child: _BuildingLoadingBadge(),
          ),
      ],
    );
  }
}

class _BuildingLoadingBadge extends StatelessWidget {
  const _BuildingLoadingBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xB30F2F4F),
        border: Border.all(color: const Color(0x55F3EEE4)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.6,
              color: Color(0xFFF3EEE4),
            ),
          ),
          SizedBox(width: 7),
          TrText('تجهيز المشهد الهندسي…',
            style: TextStyle(
              color: Color(0xFFF3EEE4),
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _NativeBuildingFallback extends StatelessWidget {
  final double progress;

  const _NativeBuildingFallback({required this.progress});

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0).toDouble();

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                (Theme.of(context).brightness == Brightness.dark ? Color(0xFF0F2F4F) : Color(0xFFE9F0FA)),
                (Theme.of(context).brightness == Brightness.dark ? Color(0xFF153A5D) : Color(0xFFE9F0FA)),
                (Theme.of(context).brightness == Brightness.dark ? Color(0xFF0B223B) : Color(0xFFFFFFFF)),
              ],
            ),
          ),
        ),
        CustomPaint(
          painter: _BlueprintFallbackPainter(progress: p),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              stops: [0, .45, 1],
              colors: [
                Color(0x660F2F4F),
                Color(0x220F2F4F),
                Color(0x000F2F4F),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BlueprintFallbackPainter extends CustomPainter {
  final double progress;

  const _BlueprintFallbackPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0x285A88B3)
      ..strokeWidth = 1;

    final majorPaint = Paint()
      ..color = const Color(0x55DCEBF7)
      ..strokeWidth = 1.2;

    final buildPaint = Paint()
      ..color = Color.lerp(
        const Color(0x00D9CBAE),
        const Color(0xFFD9CBAE),
        (progress / .48).clamp(0.0, 1.0),
      )!
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const gap = 34.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final center = Offset(size.width * .53, size.height * .58);
    final w = size.width * .42;
    final h = size.height * .38;
    final rect = Rect.fromCenter(center: center, width: w, height: h);

    canvas.drawRect(rect, majorPaint);

    for (var i = 1; i < 4; i++) {
      final y = rect.top + rect.height * i / 4;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), majorPaint);
    }
    for (var i = 1; i < 4; i++) {
      final x = rect.left + rect.width * i / 4;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), majorPaint);
    }

    final build = (progress / .48).clamp(0.0, 1.0);
    if (build > .02) {
      final visibleHeight = rect.height * build;
      final builtRect = Rect.fromLTWH(
        rect.left,
        rect.bottom - visibleHeight,
        rect.width,
        visibleHeight,
      );
      canvas.drawRect(builtRect, buildPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BlueprintFallbackPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _BuildingHeroCopy extends StatelessWidget {
  final double opacity;
  final bool compact;
  final String? role;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  const _BuildingHeroCopy({
    required this.opacity,
    required this.compact,
    required this.role,
    required this.onPrimary,
    required this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final primaryLabel = role == 'customer'
        ? 'اطلب استشارتك الآن'
        : 'استكشف أعمال المهندسين';

    return IgnorePointer(
      ignoring: opacity < .12,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0).toDouble(),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            compact ? 20 : 72,
            compact ? 82 : 40,
            compact ? 20 : 72,
            34,
          ),
          decoration: BoxDecoration(
            gradient: compact
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, .50, .82],
                    colors: [
                      Color(0xF00F2F4F),
                      Color(0xB80F2F4F),
                      Color(0x000F2F4F),
                    ],
                  )
                : const LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    stops: [0, .40, .67],
                    colors: [
                      Color(0xF00F2F4F),
                      Color(0xB80F2F4F),
                      Color(0x000F2F4F),
                    ],
                  ),
          ),
          child: Align(
            alignment: compact ? Alignment.topRight : Alignment.centerRight,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: compact ? 520 : 650),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x1AF3EEE4),
                      border: Border.all(color: const Color(0x55F3EEE4)),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const TrText('＋  منصة هندسية متكاملة',
                      style: TextStyle(
                        color: Color(0xFFF3EEE4),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 18 : 24),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'حوّل فكرتك\n'.tr(),
                          style: TextStyle(color: Color(0xFFBCD2DE)),
                        ),
                        TextSpan(text: 'إلى مشروع هندسي ناجح'.tr()),
                      ],
                    ),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: const Color(0xFFF3EEE4),
                      fontSize: compact ? 38 : 66,
                      height: 1.18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.8,
                    ),
                  ),
                  SizedBox(height: compact ? 15 : 22),
                  TrText('نحن نوفر لك أفضل الخبرات الهندسية في جميع التخصصات، وتستطيع متابعة مراحل مشروعك والحصول على استشارات احترافية من مهندسين معتمدين.',
                    style: TextStyle(
                      color: const Color(0xDCF3EEE4),
                      fontSize: compact ? 13 : 17,
                      height: 1.8,
                    ),
                  ),
                  SizedBox(height: compact ? 16 : 24),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _BlueprintActionButton(
                        label: primaryLabel,
                        primary: true,
                        onTap: onPrimary,
                      ),
                      _BlueprintActionButton(
                        label: 'تصفح مكتبة الأعمال',
                        onTap: onSecondary,
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 18 : 34),
                  const _BuildingScrollHint(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BuildingScrollHint extends StatefulWidget {
  const _BuildingScrollHint();

  @override
  State<_BuildingScrollHint> createState() => _BuildingScrollHintState();
}

class _BuildingScrollHintState extends State<_BuildingScrollHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 2,
          height: 42,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Stack(
                children: [
                  const Positioned.fill(
                    child: ColoredBox(color: Color(0x55F3EEE4)),
                  ),
                  Positioned(
                    top: (_controller.value * 52) - 12,
                    left: 0,
                    right: 0,
                    height: 12,
                    child: const ColoredBox(color: Color(0xFFF3EEE4)),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        const TrText('مرّر لتتابع بناء المبنى',
          style: TextStyle(
            color: Color(0xB8F3EEE4),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _BlueprintActionButton extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback onTap;

  const _BlueprintActionButton({
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = primary
        ? const Color(0xFFF3EEE4)
        : const Color(0xFFF3EEE4);
    return SizedBox(
      height: 44,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: foreground,
          backgroundColor:
              primary ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0F2F4F) : const Color(0xFFE9F0FA)) : const Color(0x220F2F4F),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(2),
            side: const BorderSide(color: Color(0x99F3EEE4)),
          ),
        ),
        child: Text(
          trUi(label),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _RevealOnBuild extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const _RevealOnBuild({required this.child, this.delay = Duration.zero});

  @override
  State<_RevealOnBuild> createState() => _RevealOnBuildState();
}

class _RevealOnBuildState extends State<_RevealOnBuild> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 680));
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(begin: const Offset(0, .055), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class _PublicStats extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _PublicStats({required this.stats});

  @override
  Widget build(BuildContext context) {
    final data = [
      _PublicStat('مهندس فعّال', stats['engineers'], Icons.engineering_outlined, (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8))),
      _PublicStat('استشارة مدفوعة', stats['consultations'], Icons.forum_outlined, (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8))),
      _PublicStat('مشروع مكتمل', stats['completed'], Icons.task_alt_outlined, (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8))),
      _PublicStat('عمل منشور', stats['works'], Icons.image_outlined, (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8))),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 150,
      ),
      itemCount: data.length,
      itemBuilder: (_, index) => _PublicStatCard(data: data[index]),
    );
  }
}

class _PublicStat {
  final String label;
  final dynamic value;
  final IconData icon;
  final Color accent;

  const _PublicStat(this.label, this.value, this.icon, this.accent);
}

class _PublicStatCard extends StatelessWidget {
  final _PublicStat data;

  const _PublicStatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xCC0F223E) : const Color(0xFFFFFFFF)),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? const Color(0x0DFFFFFF) : AppColors.borderSoft),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: data.accent.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(data.icon, color: data.accent),
          ),
          const SizedBox(height: 9),
          _CountUpText(
            value: data.value,
            color: data.accent,
          ),
          const SizedBox(height: 2),
          Text(
            trUi(data.label),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant),
              fontSize: 10,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountUpText extends StatelessWidget {
  final dynamic value;
  final Color color;

  const _CountUpText({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final parsed = double.tryParse(value?.toString() ?? '') ?? 0;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: parsed),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, current, _) {
        final display = parsed % 1 == 0 ? current.round().toString() : current.toStringAsFixed(1);
        return Text(
          trUi(display),
          style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900),
        );
      },
    );
  }
}

class _HomeSectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _HomeSectionTitle({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(trUi(title), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                trUi(subtitle),
                style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 11, height: 1.55),
              ),
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(trUi(actionLabel!))),
      ],
    );
  }
}

class _ServiceData {
  final String title;
  final String description;
  final IconData icon;

  const _ServiceData(this.title, this.description, this.icon);
}

class _ServiceCard extends StatelessWidget {
  final _ServiceData data;

  const _ServiceCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 196,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xCC0F223E) : const Color(0xFFFFFFFF)),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? const Color(0x0DFFFFFF) : AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0x1A60A5FA),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(data.icon, color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8))),
          ),
          const SizedBox(height: 12),
          Text(trUi(data.title), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
          const SizedBox(height: 5),
          Text(
            trUi(data.description),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 10, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _WorkCard extends StatelessWidget {
  final Map<String, dynamic> work;
  final VoidCallback onTap;

  const _WorkCard({required this.work, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isOffice = work['provider_type']?.toString() == 'office';
    final engineer = work['engineer'] as Map?;
    final office = work['office'] as Map?;
    final cover = work['cover_image'] as Map? ?? work['coverImage'] as Map?;
    final imagePath = cover == null ? null : cover['image_path']?.toString();
    final directCoverUrl = work['cover_url']?.toString();
    final imageUrl = directCoverUrl != null && directCoverUrl.trim().isNotEmpty
        ? _storageUrl(directCoverUrl)
        : _storageUrl(imagePath);
    final officeName = office == null ? null : office['name']?.toString();
    final engineerName = engineer == null ? null : engineer['name']?.toString();
    final providerName = isOffice
        ? (officeName == null || officeName.trim().isEmpty
              ? 'مكتب هندسي'
              : officeName)
        : (engineerName == null || engineerName.trim().isEmpty
              ? 'مهندس منصة الوليد'
              : engineerName);
    final providerInitial = _firstLetter(providerName);
    final String? rawProviderImage = isOffice
        ? (office == null
            ? null
            : (office['logo_url']?.toString() ?? office['logo']?.toString()))
        : (engineer == null
            ? null
            : (engineer['profile_photo_url']?.toString() ??
                engineer['profile_photo']?.toString()));
    final String? providerImageUrl = _storageUrl(rawProviderImage);
    final dynamic rawVerifiedValue = isOffice
        ? (office == null ? null : office['verified'])
        : (engineer == null ? null : engineer['verified']);
    final String? verifiedText = rawVerifiedValue?.toString().toLowerCase();
    final bool providerVerified =
        rawVerifiedValue == true ||
        rawVerifiedValue == 1 ||
        verifiedText == '1' ||
        verifiedText == 'true';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        width: 236,
        decoration: BoxDecoration(
          color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xCC0F223E) : const Color(0xFFFFFFFF)),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? const Color(0x0DFFFFFF) : AppColors.borderSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: SizedBox(
                width: double.infinity,
                height: 135,
                child: imageUrl == null
                    ? const _ImagePlaceholder()
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const _ImagePlaceholder(),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trUi(work['title']?.toString() ?? 'عمل هندسي'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0x332563EB),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: providerImageUrl == null
                            ? Center(
                                child: Text(
                                  trUi(providerInitial),
                                  style: TextStyle(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFF93C5FD)
                                        : const Color(0xFF1D4ED8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              )
                            : Image.network(
                                providerImageUrl,
                                width: 28,
                                height: 28,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Text(
                                    trUi(providerInitial),
                                    style: TextStyle(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? const Color(0xFF93C5FD)
                                          : const Color(0xFF1D4ED8),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: VerifiedName(
                          name: providerName,
                          verified: providerVerified,
                          iconSize: 15,
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFF8FAFC)
                                : Theme.of(context).colorScheme.onSurface,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (isOffice) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.apartment_rounded, size: 14, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF93C5FD) : Color(0xFF1D4ED8))),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          trUi(work['location']?.toString() ?? 'الموقع غير محدد'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 9),
                        ),
                      ),
                    ],
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

class _EngineerCard extends StatelessWidget {
  final Map<String, dynamic> engineer;
  final VoidCallback onTap;

  const _EngineerCard({required this.engineer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final works = engineer['engineer_works'] as List? ?? engineer['engineerWorks'] as List? ?? const [];
    final workCount = (engineer['approved_works_count'] as num?)?.toInt() ?? works.length;
    final verified = engineer['verified'] == true;
    final rating = (engineer['rating_average'] as num?)?.toDouble() ??
        (engineer['rating_avg'] as num?)?.toDouble() ??
        0;
    final reviews = (engineer['reviews_count'] as num?)?.toInt() ??
        (engineer['rating_count'] as num?)?.toInt() ??
        0;
    final specialty = engineer['specialty'] is Map
        ? (engineer['specialty'] as Map)['name']?.toString()
        : engineer['specialty']?.toString();
    final photoUrl = _storageUrl(
      engineer['profile_photo_url']?.toString() ?? engineer['profile_photo']?.toString(),
    );
    final name = engineer['name']?.toString() ?? 'مهندس';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xCC0F223E) : const Color(0xFFFFFFFF)),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? const Color(0x0DFFFFFF) : AppColors.borderSoft),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          leading: CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0x332563EB),
            backgroundImage: photoUrl == null ? null : NetworkImage(photoUrl),
            child: photoUrl == null
                ? Text(
                    trUi(_firstLetter(name)),
                    style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF93C5FD) : Color(0xFF1D4ED8)), fontWeight: FontWeight.w900),
                  )
                : null,
          ),
          title: VerifiedName(
            name: name,
            verified: verified,
            iconSize: 17,
            tooltip: 'مهندس موثق احترافيًا على منصة الوليد الهندسية'.tr(),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            '${specialty ?? 'مهندس'} • $workCount أعمال${reviews > 0 ? ' • ${rating.toStringAsFixed(1)} ★ ($reviews)' : ''}'.tr(),
            style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 10),
          ),
          trailing: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF93C5FD) : Color(0xFF1D4ED8))),
        ),
      ),
    );

  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0A172B) : Theme.of(context).colorScheme.surface),
      alignment: Alignment.center,
      child: Icon(Icons.home_work_outlined, size: 54, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF93C5FD) : Color(0xFF1D4ED8))),
    );
  }
}

class _HomeEmpty extends StatelessWidget {
  final String text;

  const _HomeEmpty({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xCC0F223E) : const Color(0xFFFFFFFF)),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? const Color(0x0DFFFFFF) : AppColors.borderSoft),
      ),
      child: Text(trUi(text), textAlign: TextAlign.center, style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant))),
    );
  }
}

class _LoadingHome extends StatelessWidget {
  const _LoadingHome();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = dark ? const Color(0xFF10233E) : const Color(0xFFE8EEF7);
    final strong = dark ? const Color(0xFF183457) : const Color(0xFFD8E2F0);

    Widget bar(double width, double height) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(height / 2),
          ),
        );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 30),
      children: [
        Container(
          height: 210,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: strong,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              bar(190, 18),
              const SizedBox(height: 12),
              bar(260, 12),
              const SizedBox(height: 8),
              bar(220, 12),
            ],
          ),
        ),
        const SizedBox(height: 24),
        bar(140, 18),
        const SizedBox(height: 16),
        Row(
          children: List.generate(3, (index) => Expanded(
            child: Container(
              height: 104,
              margin: EdgeInsets.only(left: index == 2 ? 0 : 10),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          )),
        ),
        const SizedBox(height: 24),
        bar(170, 18),
        const SizedBox(height: 14),
        ...List.generate(3, (_) => Container(
          height: 82,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(20),
          ),
        )),
      ],
    );
  }
}

class _HomeError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _HomeError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 180),
        Icon(Icons.wifi_off_rounded, size: 52, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 14),
        Text(trUi(message), textAlign: TextAlign.center),
        const SizedBox(height: 14),
        Center(
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const TrText('إعادة المحاولة'),
          ),
        ),
      ],
    );
  }
}




class _JourneySection extends StatelessWidget {
  const _JourneySection();

  @override
  Widget build(BuildContext context) {
    final steps = const [
      ('١', 'اختر تخصصك', 'حدد المجال الهندسي الذي يتناسب مع احتياجات مشروعك.'),
      ('٢', 'أرسل التفاصيل', 'أضف المعلومات والمخططات والملفات الأولية للبدء بالدراسة.'),
      ('٣', 'الدفع الإلكتروني', 'ارفع إيصال الدفع وتابع الاعتماد والتنفيذ من داخل التطبيق.'),
      ('٤', 'استلم مشروعك', 'تابع الملفات والمراحل والاجتماعات حتى التسليم النهائي.'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HomeSectionTitle(
          title: 'رحلتك نحو التميز'.tr(),
          subtitle: 'أربع خطوات واضحة تفصلك عن بدء مشروعك ومتابعته باحترافية.'.tr(),
        ),
        const SizedBox(height: 14),
        ...List.generate(steps.length, (index) {
          final step = steps[index];
          return Container(
            margin: EdgeInsets.only(bottom: index == steps.length - 1 ? 0 : 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xCC0F223E) : const Color(0xFFFFFFFF)),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? const Color(0x0DFFFFFF) : AppColors.borderSoft),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: index == 0
                        ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8))
                        : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF112A4D) : const Color(0xFFE9F0FA)),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: const Color(0x5260A5FA)),
                  ),
                  child: Text(
                    trUi(step.$1),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: index == 0 ? const Color(0xFF2563EB) : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(trUi(step.$2), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                      const SizedBox(height: 5),
                      Text(trUi(step.$3), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), height: 1.7, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _FeedbackShowcase extends StatelessWidget {
  final VoidCallback onTap;

  const _FeedbackShowcase({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xCC0D1B31) : const Color(0xFFFFFFFF)),
        border: Border.all(color: const Color(0x263B82F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0x263B82F6),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.forum_outlined, size: 15, color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF60A5FA) : Color(0xFF1D4ED8))),
                SizedBox(width: 6),
                TrText('صوتك يهمنا', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF60A5FA) : Color(0xFF1D4ED8)), fontWeight: FontWeight.w800, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const TrText('الآراء والملاحظات', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          TrText('شاركنا رأيك أو اقتراحك أو أي ملاحظة تساعدنا على تطوير تجربة العملاء والمهندسين والمكاتب.',
            style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), height: 1.8),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.rate_review_outlined),
            label: const TrText('أرسل رأيك الآن'),
          ),
        ],
      ),
    );
  }
}

class _ActionShowcase extends StatelessWidget {
  final VoidCallback onConsultation;
  final VoidCallback onLibrary;
  final VoidCallback onMarketplace;

  const _ActionShowcase({
    required this.onConsultation,
    required this.onLibrary,
    required this.onMarketplace,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HomeSectionTitle(
          title: 'ابدأ من المكان المناسب'.tr(),
          subtitle: 'وصول سريع لأهم مسارات المنصة مثل الموقع الرئيسي باحترافية عالية.'.tr(),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 214,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _entryCard(
                context: context,
                title: 'استشارة فورية',
                subtitle: 'ابدأ مباشرة مع فريق المنصة وحدد احتياجك الهندسي.',
                icon: Icons.add_comment_outlined,
                accent: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8)),
                onTap: onConsultation,
              ),
              const SizedBox(width: 12),
              _entryCard(
                context: context,
                title: 'مكتبة الأعمال',
                subtitle: 'استعرض أعمال المهندسين والمكاتب وقيّم الجودة قبل التعاقد.',
                icon: Icons.photo_library_outlined,
                accent: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8)),
                onTap: onLibrary,
              ),
              const SizedBox(width: 12),
              _entryCard(
                context: context,
                title: 'سوق المشاريع',
                subtitle: 'انشر مشروعك أو قدّم عرضك من السوق المفتوح داخل التطبيق.',
                icon: Icons.storefront_outlined,
                accent: const Color(0xFF3B82F6),
                onTap: onMarketplace,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _entryCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 230,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xCC0F223E) : const Color(0xFFFFFFFF)),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0x12FFFFFF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(height: 14),
              Text(
                trUi(title),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, height: 1.35),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  trUi(subtitle),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : AppColors.textSecondary), height: 1.55, fontSize: 11.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _ProfessionalAccountActions extends StatelessWidget {
  final String role;
  final VoidCallback onEngineers;
  final VoidCallback onOffices;
  final VoidCallback onOfficeApplication;
  final VoidCallback onOfficeManagement;
  final VoidCallback onVerification;

  const _ProfessionalAccountActions({
    required this.role,
    required this.onEngineers,
    required this.onOffices,
    required this.onOfficeApplication,
    required this.onOfficeManagement,
    required this.onVerification,
  });

  @override
  Widget build(BuildContext context) {
    final items = <({String title, String subtitle, IconData icon, Color color, VoidCallback onTap})>[];

    items.add((
      title: 'دليل المهندسين',
      subtitle: 'ابحث بالتخصص والتقييم واعرض الموثقين فقط.',
      icon: Icons.engineering_rounded,
      color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8)),
      onTap: onEngineers,
    ));

    items.add((
      title: 'دليل المكاتب',
      subtitle: 'استعرض المكاتب وأعمالها وتقييماتها الموثقة.',
      icon: Icons.apartment_rounded,
      color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8)),
      onTap: onOffices,
    ));

    if (role == 'customer' || role == 'engineer') {
      items.add((
        title: 'تسجيل مكتب هندسي',
        subtitle: 'قدّم طلب إنشاء مكتب وتابع الاشتراك من التطبيق.',
        icon: Icons.add_business_rounded,
        color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8)),
        onTap: onOfficeApplication,
      ));
    }

    if (role == 'engineer' || role == 'office_owner') {
      items.add((
        title: 'طلب توثيق الحساب',
        subtitle: role == 'office_owner'
            ? 'قدّم طلب توثيق المكتب واشتراك الشارة.'
            : 'قدّم طلب توثيق المهندس واشتراك الشارة.',
        icon: Icons.verified_user_rounded,
        color: const Color(0xFF3B82F6),
        onTap: onVerification,
      ));
    }

    if (role == 'office_owner') {
      items.add((
        title: 'إدارة صفحة المكتب',
        subtitle: 'الأعضاء والاشتراكات والاستشارات ومكتبة الأعمال.',
        icon: Icons.admin_panel_settings_rounded,
        color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8)),
        onTap: onOfficeManagement,
      ));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HomeSectionTitle(
          title: 'الحساب المهني والمكاتب'.tr(),
          subtitle: 'نفس مسارات الموقع أصبحت متاحة مباشرة من التطبيق.'.tr(),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 178,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, index) {
              final item = items[index];
              return SizedBox(
                width: 220,
                child: InkWell(
                  onTap: item.onTap,
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xCC0F223E) : const Color(0xFFFFFFFF)),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? const Color(0x0DFFFFFF) : AppColors.borderSoft),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: item.color.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(item.icon, color: item.color),
                        ),
                        const Spacer(),
                        Text(trUi(item.title), style: const TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 5),
                        Text(
                          trUi(item.subtitle),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 10.5, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FeaturedOfficeCard extends StatelessWidget {
  final Map<String, dynamic> office;
  final VoidCallback onTap;

  const _FeaturedOfficeCard({required this.office, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = office['name']?.toString() ?? 'مكتب هندسي';
    final logo = office['logo_url']?.toString();
    final location = [office['city'], office['country']]
        .where((e) => e != null && e.toString().trim().isNotEmpty)
        .join(' • ');

    return SizedBox(
      width: 250,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xCC0F223E) : const Color(0xFFFFFFFF)),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0x293B82F6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: const Color(0x332563EB),
                    backgroundImage: logo != null && logo.isNotEmpty ? NetworkImage(logo) : null,
                    child: logo == null || logo.isEmpty
                        ? Text(
                            trUi(_firstLetter(name)),
                            style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFF93C5FD) : Color(0xFF1D4ED8)), fontWeight: FontWeight.w900),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        VerifiedName(
                          name: name,
                          verified: office['verified'] == true,
                          iconSize: 17,
                          tooltip: 'مكتب موثق احترافيًا على منصة الوليد الهندسية'.tr(),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        if (location.isNotEmpty)
                          Text(
                            trUi(location),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 9.5),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                trUi(office['description']?.toString() ?? 'مكتب هندسي موثق على المنصة.'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), fontSize: 10.5, height: 1.6),
              ),
              const Spacer(),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _OfficeMetric(icon: Icons.star_rounded, text: '${office['rating_average'] ?? 0} (${office['reviews_count'] ?? 0})'),
                  _OfficeMetric(icon: Icons.photo_library_outlined, text: '${office['portfolio_works_count'] ?? 0} أعمال'),
                  _OfficeMetric(icon: Icons.task_alt_rounded, text: '${office['completed_projects_count'] ?? 0} مشاريع'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfficeMetric extends StatelessWidget {
  final IconData icon;
  final String text;

  const _OfficeMetric({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF102847) : Theme.of(context).colorScheme.surface),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8))),
          const SizedBox(width: 4),
          Text(trUi(text), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _WhyUsSection extends StatelessWidget {
  const _WhyUsSection();

  @override
  Widget build(BuildContext context) {
    final items = const [
      ('إدارة كاملة للمشروع', 'من الاستشارة إلى العقد والدفعات والتسليمات من شاشة واحدة.', Icons.hub_outlined),
      ('نخبة تخصصات هندسية', 'معماري، إنشائي، كهرباء، ميكانيك، داخلي، وتقنيات مساندة.', Icons.engineering_outlined),
      ('تجربة احترافية مثل الموقع', 'تصميم رئيسي غني بالبطاقات والمؤشرات والدعوات الواضحة للإجراء.', Icons.verified_outlined),
      ('سوق مشاريع متكامل', 'استقبال عروض أسعار ومقارنة المهندسين والمكاتب ثم تحويل العرض لمشروع.', Icons.compare_arrows_outlined),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HomeSectionTitle(
          title: 'لماذا تختار المنصة؟'.tr(),
          subtitle: 'واجهة رئيسية قوية تعكس قيمة الخدمات وتعرض أهم المسارات بوضوح.'.tr(),
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 205,
          ),
          itemCount: items.length,
          itemBuilder: (_, index) {
            final item = items[index];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xCC0F223E) : const Color(0xFFFFFFFF)),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? const Color(0x0DFFFFFF) : AppColors.borderSoft),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  Icon(item.$3, color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8))),
                  const SizedBox(height: 10),
                  Text(trUi(item.$1), style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(trUi(item.$2), style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), height: 1.7, fontSize: 11)),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _MarketClosingBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _MarketClosingBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [(Theme.of(context).brightness == Brightness.dark ? Color(0xFF0E2747) : Color(0xFFFFFFFF)), (Theme.of(context).brightness == Brightness.dark ? Color(0xFF071426) : Color(0xFFF5F8FE))],
        ),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TrText('هل تريد طرح مشروعك للمنافسة؟', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          TrText('أضف مشروعك إلى سوق المشاريع وحدد الميزانية والمدة ونطاق العمل ليستقبل عروضًا احترافية من المهندسين والمكاتب.',
            style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Color(0xFFB9CBE3) : Theme.of(context).colorScheme.onSurfaceVariant), height: 1.8),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.storefront_outlined),
            label: const TrText('افتح سوق المشاريع'),
          ),
        ],
      ),
    );
  }
}

String _firstLetter(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'م';
  return text.characters.first;
}

String? _storageUrl(String? path) {
  if (path == null || path.trim().isEmpty) return null;
  final clean = path.trim();
  if (clean.startsWith('http://') || clean.startsWith('https://')) return clean;
  if (clean.startsWith('/')) return 'https://alwaleedoffice.com$clean';
  if (clean.startsWith('media/') ||
      clean.startsWith('images/') ||
      clean.startsWith('build/') ||
      clean.startsWith('storage/')) {
    return 'https://alwaleedoffice.com/$clean';
  }
  return 'https://alwaleedoffice.com/storage/$clean';
}
