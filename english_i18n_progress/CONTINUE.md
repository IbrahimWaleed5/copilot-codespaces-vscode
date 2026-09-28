# Continue: add English to Alwaleed Engineering Platform (Laravel web first, then Flutter app)

Give this whole folder + the project zips (resources.zip = app/config/database/resources/routes, lib.zip = Flutter)
to a new Claude session and say: "Read CONTINUE.md and continue from the next step."

## Status (updated)
- ALL 35 chunks translated and validated (tr/check.py: 0 problems each). tr/out_NN.json complete.
- build/merged.json = {Arabic key: English} (12,655 entries, id 6961 excluded, trailing spaces kept).
- WEBSITE: DONE and tested -> build/web/ (mirrors project paths) and deliverables/alwaleed_web_english.zip
  * app/Support/Localization/{Runs,UiLocale,Dictionary,JsLiterals,LtrFlipper,AutoTranslator}.php
  * app/View/TranslatingCompilerEngine.php (outermost Blade render only; failure -> original output)
  * app/Http/Middleware/UiLanguageMiddleware.php (?lang, X-Locale, session/cookie ui_locale, Accept-Language only
    for API/app clients without session cookie; JSON keys message/error/errors/title/body/label/text/description/hint/note;
    injects switcher + css/ui-ltr.css + js/ui-i18n.js on HTML pages). Registered global + web + api groups.
  * app/Http/Controllers/UiLocaleController.php: GET /lang/{ar|en} (session+cookie, redirect back),
    POST /lang/translate (used by public/js/ui-i18n.js MutationObserver for text added later by JS files,
    e.g. phone-input.js / profile-photo-cropper.js - those two files were NOT edited because resources.zip never arrived).
  * app/Providers/UiLanguageServiceProvider.php - user adds ONE line in AppServiceProvider::register():
    $this->app->register(\App\Providers\UiLanguageServiceProvider::class);   Kill switch: UI_I18N_ENABLED=false
  * lang/auto/en.php (+ optional lang/auto/en_custom.php for manual fixes), public/css/ui-ltr.css (build/gen_ltr_css.py)
  * Laravel app locale is NOT changed (stays ar) - English is produced by translating output. Safer for existing code.
  * Tests: php tests/i18n/AutoTranslatorTest.php -> 76 passed. Also verified end-to-end on fresh Laravel 11 and 13 apps
    (pages, components, JSON, API Accept-Language, 404, route/config/view cache, kill switch) + Chromium check of ui-i18n.js.
- FLUTTER: kit DONE and tested -> build/app/lib/i18n + deliverables/alwaleed_app_english.zip
  * AppLanguage (SharedPreferences key app_language), String.tr(), AppLanguageBuilder (rebuilds every open screen),
    LanguageSwitchTile / LanguageToggleButton, AppLanguage.instance.headers (Accept-Language + X-Locale).
  * translator.dart = Dart port of AutoTranslator.translateText (test/translator_check.dart via `dart run`).
  * build/app/test/language_switch_test.dart: widget test (passed on Flutter 3.47) - package name fapp in the sample.
  * tools/flutter_i18n.py: `wrap <lib>` adds .tr() to display strings only, removes enclosing const, adds import,
    writes wrap_report.txt; `extract <lib> build/merged.json out.json` lists phrases missing from the dictionary.
    Tested on build/app/test_sample_lib_before -> test_sample_lib_after (flutter analyze clean).
- NOT DONE because lib.zip and resources.zip were NOT uploaded in that session:
  * wrapping the real app (186 files) + translating app-only phrases + settings screen + API headers wiring;
  * editing resources/js/phone-input.js & profile-photo-cropper.js (covered at runtime by ui-i18n.js anyway).

## Next steps
1. Ask the user to upload lib.zip + pubspec.yaml (and resources.zip if they want the two JS files edited).
2. Flutter: unzip lib, `python3 tools/flutter_i18n.py extract lib build/merged.json tr/app_missing.json`,
   translate it per tr/GUIDE.md into build/app_extra.json {Arabic: English}, `python3 build/gen_dart_dict.py`,
   copy build/app/lib/i18n into lib, `python3 tools/flutter_i18n.py wrap lib`, review wrap_report.txt
   (skipped items: const declarations / default values shown to users -> handle by hand), wire main.dart
   (see build/app/EXAMPLE_main.dart), add LanguageSwitchTile to the settings/profile screen, add
   AppLanguage.instance.headers to the HTTP client (dio interceptor or http headers).
   If the app uses GetX or easy_localization, rename the extension method (tr conflicts).
   Verify with Flutter SDK: flutter pub get && flutter analyze (download SDK from storage.googleapis.com works).
3. Deliver the full lib as alwaleed_app_english.zip + update INSTALL_AR.txt.

## User preferences
Palestinian Arabic replies, complete copy-paste files, very detailed steps for a non-technical user, one step at a time and wait for "تم"/"كمل".
