import 'package:flutter/material.dart';

import 'app_language.dart';

/// Settings row: "اللغة / Language" with a switch (on = English).
/// Put `const LanguageSwitchTile()` inside the settings or profile screen list.
class LanguageSwitchTile extends StatelessWidget {
  const LanguageSwitchTile({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguage.instance;
    return AnimatedBuilder(
      animation: lang,
      builder: (context, _) => ListTile(
        leading: const Icon(Icons.language),
        title: Text(lang.isEnglish ? 'Language' : 'اللغة'),
        subtitle: Text(lang.isEnglish ? 'English' : 'العربية'),
        trailing: Switch(
          value: lang.isEnglish,
          onChanged: (english) => lang.setLanguage(english ? 'en' : 'ar'),
        ),
        onTap: lang.toggle,
      ),
    );
  }
}

/// Small button (for an AppBar `actions:` list) that switches between Arabic and English.
class LanguageToggleButton extends StatelessWidget {
  const LanguageToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguage.instance;
    return AnimatedBuilder(
      animation: lang,
      builder: (context, _) => TextButton.icon(
        onPressed: lang.toggle,
        icon: const Icon(Icons.language),
        label: Text(lang.isEnglish ? 'العربية' : 'English'),
      ),
    );
  }
}
