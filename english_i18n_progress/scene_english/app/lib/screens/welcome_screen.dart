import 'package:flutter/material.dart';
import '../i18n/localized_text.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../providers/auth_provider.dart';
import 'engineer_library_screen.dart';
import 'dashboard_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'projects_screen.dart';
import 'register_screen.dart';

/// صفحة الترحيب السينمائية.
///
/// أهم قرار أداء هنا: الـ WebView يملك التمرير بنفسه. لا يوجد ScrollController
/// في Flutter يرسل progress إلى JavaScript في كل بكسل، لذلك لا تحدث إعادة بناء
/// للشجرة ولا عبور متكرر فوق platform channel أثناء السحب.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late final WebViewController _controller;
  String _sceneLang = AppLanguage.instance.code;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.setBackgroundColor(
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0F2F4F)
          : const Color(0xFFE9F0FA),
    );
  }

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..enableZoom(false)
      ..setBackgroundColor(const Color(0xFFE9F0FA))
      ..setUserAgent('AlWaleedFlutter/1.0 AlWaleedLang/${AppLanguage.instance.code}')
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _handleNavigation,
          onPageFinished: (_) => _applyAuthVisibility(),
        ),
      )
      ..loadFlutterAsset('assets/web/building-scroll-hero/index.html');
    AppLanguage.instance.addListener(_onLanguageChanged);
  }

  // The scene HTML reads the language from the user agent, so a language
  // switch while this screen is open updates it and reloads the scene.
  Future<void> _onLanguageChanged() async {
    final code = AppLanguage.instance.code;
    if (!mounted || code == _sceneLang) return;
    _sceneLang = code;
    await _controller.setUserAgent('AlWaleedFlutter/1.0 AlWaleedLang/${AppLanguage.instance.code}');
    await _controller.reload();
  }

  @override
  void dispose() {
    AppLanguage.instance.removeListener(_onLanguageChanged);
    super.dispose();
  }


  Future<void> _applyAuthVisibility() async {
    if (!mounted) return;
    final authenticated = context.read<AuthProvider>().user != null;
    if (!authenticated) return;
    try {
      await _controller.runJavaScript("""
        document.querySelectorAll('a[href="app://login"], a[href="app://register"]').forEach(function(el){ el.style.display='none'; });
      """);
    } catch (_) {}
  }

  NavigationDecision _handleNavigation(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri?.scheme != 'app') return NavigationDecision.navigate;

    switch (uri?.host) {
      case 'home':
        _skipScene();
        break;
      case 'register':
        _open(context.read<AuthProvider>().user != null ? const DashboardScreen() : const RegisterScreen());
        break;
      case 'start-project':
        final authenticated = context.read<AuthProvider>().user != null;
        _open(authenticated ? const ProjectsScreen() : const RegisterScreen());
        break;
      case 'login':
        _open(context.read<AuthProvider>().user != null ? const DashboardScreen() : const LoginScreen());
        break;
      case 'works':
        _open(const EngineerLibraryScreen());
        break;
    }
    return NavigationDecision.prevent;
  }


  void _skipScene() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
    );
  }

  void _open(Widget screen) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 220),
          reverseTransitionDuration: const Duration(milliseconds: 180),
          pageBuilder: (_, animation, secondaryAnimation) => screen,
          transitionsBuilder: (_, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.018),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLanguage.instance.textDirection,
      child: Scaffold(
        backgroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0F2F4F) : const Color(0xFFE9F0FA)),
        body: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: WebViewWidget(controller: _controller),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 14, 0),
                child: Align(
                  alignment: AlignmentDirectional.topStart,
                  child: Material(
                    color: const Color(0xB30A1D31),
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: _skipScene,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_back_rounded, size: 17, color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF0F172A))),
                            SizedBox(width: 6),
                            TrText('تخطي المشهد',
                              style: TextStyle(
                                color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF0F172A)),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
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
}
