# Continue: add English to Alwaleed Engineering Platform (Laravel web first, then Flutter app)

Give this whole folder + the project zips (resources.zip = app/config/database/resources/routes, lib.zip = Flutter)
to a new Claude session and say: "Read CONTINUE.md and continue from the next step."

## Status
- keys_web.json: 12,656 unique Arabic phrases extracted from the web project (tools/extract.php, rules in src/Runs.php).
- tr/chunk_NN.json (35 chunks) -> tr/out_NN.json translations {"id": "English"}. tr/id2key.json maps id -> Arabic key.
- DONE (all pass tr/check.py): 01-14, 16-24, 26-35.
- TODO: translate chunk_15, chunk_25 following tr/GUIDE.md, then validate:
  `cd tr && python3 check.py chunk_10.json out_10.json` (must print 0 problems).
- Notes from translators:
  * Some values end with a trailing space on purpose (ids 5788, 5859, 6269, 6930, 11318, 11721, 12145) - do NOT trim values when merging.
  * id 6961 ("٠-٩") is part of a JS regex -> EXCLUDE it from the dictionary.

## Next steps (plan)
1. Merge: build lang/auto/en.php = PHP array [Arabic key => English] from id2key.json + all out_*.json (skip id 6961, keep spaces).
2. Web runtime translation layer (no need to edit the 358 Blade views):
   - app/Support/Localization/Runs.php (copy src/Runs.php) - same run rules used for extraction.
   - AutoTranslator: for locale "en": find Arabic runs (Runs::extended()), normalise (Runs::norm), look up dictionary;
     fallback: translate each Runs::strict() sub-run; unknown text stays as is.
     Only translate text nodes + attributes placeholder,title,alt,aria-label,label,content; NEVER value/name/data-*/href.
     In <script>: translate string literals except ones compared with ==/===/!=/case or used in includes/indexOf.
     Also for en: <html lang="en" dir="ltr">, dir="rtl"->ltr, flip left/right in <style> and style="" (margin/padding/left/right/float/text-align/border),
     swap Tailwind physical classes (ml<->mr, pl<->pr, left-<->right-, text-left<->text-right, border-l<->border-r, rounded-l<->rounded-r, remove space-x-reverse)
     and ship public/css/ltr.css defining the swapped classes (some pages use compiled Tailwind).
   - Hook: decorate Blade engine (TranslatingCompilerEngine extends CompilerEngine, translate only at outermost render depth) -> covers pages, mails, PDFs.
   - Middleware SetLocale (session/cookie 'locale', ?lang=en, header Accept-Language/X-Locale for API) pushed to web + api groups from AppServiceProvider::boot
     (bootstrap/app.php was not uploaded; register via app('router')->pushMiddlewareToGroup).
   - JSON responses (API/AJAX): translate only keys like message,error,errors,title,body,label,text,description,hint,note - never status/value fields.
   - Route /lang/{locale} registered from AppServiceProvider; floating switcher button (English / العربية) injected before </body>.
   - resources/js/phone-input.js & profile-photo-cropper.js: use Arabic strings only when document.documentElement.lang==='ar'.
   - Deliver to the user as a zip of complete files + very simple step-by-step install (test on XAMPP, php artisan optimize:clear, then push to GitHub/Railway).
3. Flutter app (lib.zip, 186 files, ~4,600 Arabic literals): extract missing keys, translate, add String extension `.tr`
   (same run-based lookup), language toggle saved in SharedPreferences, MaterialApp locale + key rebuild,
   send Accept-Language header to API. Only wrap display strings (Text, labels, hints, SnackBars) - never comparisons/status values; remove `const` where needed.

## User preferences
Palestinian Arabic replies, complete copy-paste files, very detailed steps for a non-technical user, one step at a time and wait for "تم"/"كمل".
