import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../i18n/i18n.dart';
import '../services/api_service.dart';
import '../utils/app_file_picker.dart';

/// يفتح الموقع الحقيقي (كل صفحاته) داخل التطبيق، بنفس التصميم 100%.
/// أي صفحة موجودة على الموقع ومش موجودة كشاشة في التطبيق بتنفتح من هون.
///
///   Navigator.push(context, MaterialPageRoute(builder: (_) => const WebsiteScreen()));
///   const WebsiteScreen(path: '/wallet')   // صفحة معيّنة
class WebsiteScreen extends StatefulWidget {
  const WebsiteScreen({super.key, this.path = '/dashboard', this.title});

  /// مسار الصفحة داخل الموقع، مثل '/dashboard' أو '/projects'.
  final String path;

  /// عنوان ثابت (اختياري). بدونه بنستعمل عنوان الصفحة نفسها.
  final String? title;

  @override
  State<WebsiteScreen> createState() => _WebsiteScreenState();
}

class _WebsiteScreenState extends State<WebsiteScreen> {
  late final WebViewController _controller;
  final Uri _site = Uri.parse(ApiService.siteBaseUrl);

  int _progress = 0;
  bool _failed = false;
  String _pageTitle = '';

  static const _downloadExtensions = {
    'pdf', 'zip', 'rar', 'doc', 'docx', 'xls', 'xlsx', 'csv', 'ppt', 'pptx',
    'dwg', 'dxf', 'ifc', 'rvt', 'skp', 'apk', 'mp4', 'mov',
  };

  @override
  void initState() {
    super.initState();

    final PlatformWebViewControllerCreationParams params = Platform.isIOS
        ? WebKitWebViewControllerCreationParams(
            allowsInlineMediaPlayback: true,
            mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
          )
        : const PlatformWebViewControllerCreationParams();

    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _failed = false);
          },
          onPageFinished: (_) async {
            final title = await _controller.getTitle();
            if (mounted && title != null) setState(() => _pageTitle = title);
          },
          onWebResourceError: (error) {
            // خطأ بالصفحة الرئيسية بس (مش صورة أو ملف صغير فشل)
            if (error.isForMainFrame == true && mounted) {
              setState(() => _failed = true);
            }
          },
          onNavigationRequest: _handleNavigation,
        ),
      );

    if (_controller.platform is AndroidWebViewController) {
      final android = _controller.platform as AndroidWebViewController;
      android.setMediaPlaybackRequiresUserGesture(false);
      // رفع الملفات من فورمات الموقع (صور، PDF، مخططات...)
      android.setOnShowFileSelector(_pickFilesForAndroid);
    }

    _controller.loadRequest(_startUri(), headers: AppLanguage.instance.headers);
  }

  Uri _startUri() {
    final path = widget.path.startsWith('/') ? widget.path : '/${widget.path}';
    final uri = _site.resolve(path);
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      'lang': AppLanguage.instance.code,
      'app': '1',
    });
  }

  Future<NavigationDecision> _handleNavigation(NavigationRequest request) async {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;

    final isWeb = uri.scheme == 'http' || uri.scheme == 'https';
    final sameSite = isWeb && (uri.host == _site.host || uri.host.endsWith('.${_site.host}'));
    final ext = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last.split('.').last.toLowerCase();
    final isDownload = sameSite && _downloadExtensions.contains(ext) ||
        uri.path.contains('/download');

    // روابط خارجية (واتساب، اتصال، إيميل، مواقع ثانية) وتنزيل الملفات: بتنفتح برا
    if (!isWeb || !sameSite || isDownload) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  Future<List<String>> _pickFilesForAndroid(FileSelectorParams params) async {
    try {
      final files = await AppFilePicker.pickFiles(
        allowMultiple: params.mode == FileSelectorMode.openMultiple,
      );
      return files
          .where((f) => f.path != null)
          .map((f) => Uri.file(f.path!).toString())
          .toList();
    } catch (_) {
      return <String>[];
    }
  }

  Future<void> _reload() async {
    setState(() => _failed = false);
    final current = await _controller.currentUrl();
    if (current == null || current == 'about:blank') {
      await _controller.loadRequest(_startUri(), headers: AppLanguage.instance.headers);
    } else {
      await _controller.reload();
    }
  }

  Future<void> _openInBrowser() async {
    final current = await _controller.currentUrl();
    final uri = Uri.tryParse(current ?? '') ?? _startUri();
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title ?? (_pageTitle.isNotEmpty ? _pageTitle : 'منصة الوليد الهندسية'.tr());

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // زر الرجوع بيرجع صفحة لورا بالموقع، ولما يخلصوا بيسكّر الشاشة
        if (await _controller.canGoBack()) {
          await _controller.goBack();
        } else if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              tooltip: 'تحديث'.tr(),
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _reload,
            ),
            IconButton(
              tooltip: 'فتح في المتصفح'.tr(),
              icon: const Icon(Icons.open_in_browser_rounded),
              onPressed: _openInBrowser,
            ),
          ],
          bottom: _progress < 100
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(value: _progress / 100, minHeight: 3),
                )
              : null,
        ),
        body: _failed
            ? _OfflineView(onRetry: _reload)
            : WebViewWidget(controller: _controller),
      ),
    );
  }
}

class _OfflineView extends StatelessWidget {
  const _OfflineView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 56),
            const SizedBox(height: 12),
            Text(
              'تعذر فتح الصفحة. تأكد من اتصال الإنترنت وحاول مرة أخرى.'.tr(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text('إعادة المحاولة'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
