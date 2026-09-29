import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../i18n/localized_text.dart';

import 'smart_assistant_screen.dart';

/// بوابة المساعد الذكي.
///
/// التصميم مرسوم كـ SVG متجاوب داخل WebView محلي، وليس لقطة شاشة موبايل؛
/// لذلك لا يحتوي على بطارية/وقت وهميين ويأخذ كامل مساحة الجوال أو التابلت.
class AiEntryScreen extends StatefulWidget {
  final String sourceRoute;
  final String sourceTitle;

  const AiEntryScreen({
    super.key,
    this.sourceRoute = 'flutter_ai_entry',
    this.sourceTitle = 'واجهة دخول المساعد الذكي',
  });

  @override
  State<AiEntryScreen> createState() => _AiEntryScreenState();
}

class _AiEntryScreenState extends State<AiEntryScreen> {
  late final WebViewController _controller;
  String _sceneLang = AppLanguage.instance.code;
  bool _ready = false;
  bool _pageFinished = false;
  bool? _lastAppliedLight;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // This registers the Theme dependency, so switching appearance re-applies
    // to the already-open WebView (including ThemeMode.system changes).
    final light = Theme.of(context).brightness == Brightness.light;
    if (_pageFinished && _lastAppliedLight != light) {
      _applyAppearance(light);
    }
  }

  Future<void> _applyAppearance(bool light) async {
    if (!_pageFinished || !mounted) return;
    try {
      await _controller.runJavaScript(
        "document.documentElement.classList.toggle('aw-light', ${light ? 'true' : 'false'});",
      );
      _lastAppliedLight = light;
    } catch (_) {
      // Local page may still be loading; retry after onPageFinished.
    }
  }

  Future<void> _onPageFinished() async {
    if (!mounted) return;
    _pageFinished = true;
    await _applyAppearance(Theme.of(context).brightness == Brightness.light);
    if (mounted) setState(() => _ready = true);
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF030712))
      ..setUserAgent('AlWaleedFlutter/1.0 AlWaleedLang/${AppLanguage.instance.code}')
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => _onPageFinished(),
          onNavigationRequest: _handleNavigation,
        ),
      )
      ..loadFlutterAsset('assets/web/ai-entry/index.html');
    AppLanguage.instance.addListener(_onLanguageChanged);
  }

  // The scene HTML reads the language from the user agent, so a language
  // switch while this screen is open updates it and reloads the scene.
  Future<void> _onLanguageChanged() async {
    final code = AppLanguage.instance.code;
    if (!mounted || code == _sceneLang) return;
    _sceneLang = code;
    _pageFinished = false;
    await _controller.setUserAgent('AlWaleedFlutter/1.0 AlWaleedLang/${AppLanguage.instance.code}');
    await _controller.reload();
  }

  @override
  void dispose() {
    AppLanguage.instance.removeListener(_onLanguageChanged);
    super.dispose();
  }

  NavigationDecision _handleNavigation(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri?.scheme != 'app') return NavigationDecision.navigate;

    switch (uri?.host) {
      case 'back':
        _goBack();
        break;
      case 'chat':
        _openChat();
        break;
    }
    return NavigationDecision.prevent;
  }

  void _goBack() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Navigator.of(context).maybePop();
    });
  }

  void _openChat() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SmartAssistantScreen(
            sourceRoute: widget.sourceRoute,
            sourceTitle: widget.sourceTitle,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final pageBackground = light ? const Color(0xFFF5F8FE) : const Color(0xFF030712);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: light ? Brightness.dark : Brightness.light,
        statusBarBrightness: light ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: pageBackground,
        systemNavigationBarIconBrightness: light ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
      backgroundColor: pageBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(child: WebViewWidget(controller: _controller)),
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _ready ? 0 : 1,
              duration: const Duration(milliseconds: 180),
              child: ColoredBox(
                color: pageBackground,
                child: const Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Color(0xFF0284C7),
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
