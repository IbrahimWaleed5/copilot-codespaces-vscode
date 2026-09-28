import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'en_dictionary.dart';
import 'translator.dart';

/// The app language (Arabic by default, English optional), saved on the device.
///
///   await AppLanguage.instance.load();          // in main(), before runApp
///   AppLanguage.instance.setLanguage('en');     // from the settings screen
///   Text('الإشعارات'.tr())                      // any display string
class AppLanguage extends ChangeNotifier {
  AppLanguage._();

  static final AppLanguage instance = AppLanguage._();

  static const String _prefsKey = 'app_language';
  static const List<Locale> supportedLocales = [Locale('ar'), Locale('en')];

  String _code = 'ar';
  ArabicTranslator? _translator;

  String get code => _code;
  bool get isEnglish => _code == 'en';
  bool get isArabic => !isEnglish;
  Locale get locale => Locale(_code);
  TextDirection get textDirection =>
      isEnglish ? TextDirection.ltr : TextDirection.rtl;

  /// Headers to send with every API request so the server answers in the same language.
  Map<String, String> get headers => {
    'Accept-Language': _code,
    'X-Locale': _code,
  };

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      _code = saved == 'en' ? 'en' : 'ar';
    } catch (_) {
      _code = 'ar';
    }
  }

  Future<void> setLanguage(String code) async {
    final next = code == 'en' ? 'en' : 'ar';
    if (next == _code) return;
    _code = next;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, next);
    } catch (_) {
      // not saved: the choice still applies until the app is closed
    }
  }

  Future<void> toggle() => setLanguage(isEnglish ? 'ar' : 'en');

  /// Translates [text] when English is selected; returns it unchanged otherwise or on any error.
  String translate(String text) {
    if (!isEnglish) return text;
    try {
      return (_translator ??= ArabicTranslator(
        kEnglishDictionary,
      )).translate(text);
    } catch (_) {
      return text;
    }
  }
}

/// Rebuilds the whole app when the language changes, without losing the open screens.
///
///   runApp(AppLanguageBuilder(builder: (context, lang) => MaterialApp(
///     locale: lang.locale,
///     supportedLocales: AppLanguage.supportedLocales,
///     ...
///   )));
class AppLanguageBuilder extends StatefulWidget {
  const AppLanguageBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, AppLanguage language) builder;

  @override
  State<AppLanguageBuilder> createState() => _AppLanguageBuilderState();
}

class _AppLanguageBuilderState extends State<AppLanguageBuilder> {
  @override
  void initState() {
    super.initState();
    AppLanguage.instance.addListener(_changed);
  }

  @override
  void dispose() {
    AppLanguage.instance.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    // Texts are translated inside build methods, so every screen (also the ones
    // under the current page) must build again to pick up the new language.
    void mark(Element element) {
      element.markNeedsBuild();
      element.visitChildren(mark);
    }

    (context as Element).visitChildren(mark);
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, AppLanguage.instance);
}

extension AppTranslate on String {
  /// Display text in the current app language: `Text('الإشعارات'.tr())`.
  /// Use ONLY for text shown to the user, never for values that are compared or sent to the API.
  String tr() => AppLanguage.instance.translate(this);
}
