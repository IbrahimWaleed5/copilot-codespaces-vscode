<?php

namespace App\Http\Middleware;

use App\Support\Localization\AutoTranslator;
use App\Support\Localization\UiLocale;
use Closure;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\BinaryFileResponse;
use Symfony\Component\HttpFoundation\Cookie;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpFoundation\StreamedResponse;

/**
 * Chooses the interface language (Arabic by default) and finishes English responses.
 *
 * Order: ?lang=en|ar  >  X-Locale header  >  session  >  cookie  >  Accept-Language (apps/API only)  >  Arabic.
 * After the response: translates JSON messages, adds the language switcher, the LTR stylesheet
 * and the dynamic-content translator on HTML pages. Any failure leaves the response untouched.
 *
 * It is registered globally and in the web/api groups; running twice is harmless.
 */
class UiLanguageMiddleware
{
    public function handle(Request $request, Closure $next)
    {
        if (!UiLocale::enabled()) {
            return $next($request);
        }

        $fromQuery = null;
        try {
            [$locale, $fromQuery] = $this->detect($request);
            UiLocale::set($locale);
            if ($fromQuery !== null && $request->hasSession()) {
                $request->session()->put(UiLocale::SESSION_KEY, $fromQuery);
            }
        } catch (\Throwable $e) {
            report($e);
            UiLocale::set(UiLocale::DEFAULT);
        }

        $response = $next($request);

        try {
            if ($response instanceof Response) {
                $this->finish($request, $response, $fromQuery);
            }
        } catch (\Throwable $e) {
            report($e);
        }

        return $response;
    }

    /** @return array{0:string,1:?string} [locale, locale explicitly chosen by ?lang=] */
    private function detect(Request $request): array
    {
        if ($lang = UiLocale::normalize($request->query('lang'))) {
            return [$lang, $lang];
        }
        if ($lang = UiLocale::normalize($request->header('X-Locale'))) {
            return [$lang, null];
        }
        if ($request->hasSession() && ($lang = UiLocale::normalize($request->session()->get(UiLocale::SESSION_KEY)))) {
            return [$lang, null];
        }
        if ($lang = UiLocale::normalize($request->cookies->get(UiLocale::COOKIE))) {
            return [$lang, null];
        }
        // Mobile app / API clients (no browser session): follow Accept-Language.
        $sessionCookie = (string) config('session.cookie');
        if (($sessionCookie === '' || !$request->cookies->has($sessionCookie))
            && ($request->is('api/*') || $request->expectsJson() || $request->bearerToken())) {
            $lang = UiLocale::normalize((string) $request->getPreferredLanguage(UiLocale::SUPPORTED));
            if ($lang) {
                return [$lang, null];
            }
        }

        return [UiLocale::DEFAULT, null];
    }

    private function finish(Request $request, Response $response, ?string $fromQuery): void
    {
        if ($fromQuery !== null) {
            $response->headers->setCookie(Cookie::create(UiLocale::COOKIE, $fromQuery, time() + 5 * 365 * 86400, '/', null, $request->isSecure(), false, false, 'lax'));
        }
        if ($response instanceof StreamedResponse || $response instanceof BinaryFileResponse) {
            return;
        }

        if (UiLocale::isEnglish() && $response instanceof JsonResponse) {
            $data = $response->getData(true);
            $translated = app(AutoTranslator::class)->translateJson($data);
            if ($translated !== $data) {
                $response->setData($translated);
            }

            return;
        }

        $type = (string) $response->headers->get('Content-Type', '');
        if ($type !== '' && !str_contains($type, 'text/html')) {
            return;
        }
        if (!$request->isMethod('GET') || $request->ajax() || $request->headers->has('X-Livewire') || $request->pjax()) {
            return;
        }
        $content = $response->getContent();
        if (!is_string($content) || !str_contains($content, '</body>') || str_contains($content, 'id="ui-lang-switch"')) {
            return;
        }

        $response->setContent($this->injectAssets($content));
    }

    private function injectAssets(string $html): string
    {
        $english = UiLocale::isEnglish();

        if ($english) {
            $css = '<link rel="stylesheet" href="' . e(asset('css/ui-ltr.css')) . '" id="ui-ltr-css">';
            $pos = stripos($html, '</head>');
            $html = $pos === false ? $css . $html : substr_replace($html, $css, $pos, 0);
        }

        $html = $this->insertBeforeBodyEnd($html, $this->switcher($english));

        return $html;
    }

    private function switcher(bool $english): string
    {
        $target = $english ? 'ar' : 'en';
        $label = $english ? 'العربية' : 'English';
        $href = e(url('/lang/' . $target));
        $side = strtolower((string) env('UI_LANG_SWITCHER_SIDE', 'left')) === 'right' ? 'right' : 'left';
        $extra = '';
        if ($english) {
            $extra = '<script src="' . e(asset('js/ui-i18n.js')) . '" data-endpoint="' . e(url('/lang/translate')) . '" defer></script>';
        }
        if (in_array(env('UI_LANG_SWITCHER', true), [false, 0, '0', 'false', 'off', 'no'], true)) {
            return $extra . '<span id="ui-lang-switch" hidden></span>';
        }

        return $extra
            . '<a id="ui-lang-switch" href="' . $href . '" translate="no" lang="' . $target . '" dir="' . ($english ? 'rtl' : 'ltr') . '"'
            . ' style="position:fixed;bottom:18px;' . $side . ':18px;z-index:2147483000;display:inline-flex;align-items:center;gap:6px;'
            . 'padding:8px 14px;border-radius:999px;background:#0f172a;color:#fff;font:600 13px/1.2 system-ui,-apple-system,Segoe UI,Tahoma,sans-serif;'
            . 'text-decoration:none;box-shadow:0 6px 18px rgba(0,0,0,.25);opacity:.92" aria-label="' . ($english ? 'تغيير اللغة إلى العربية' : 'Switch language to English') . '">'
            . '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><circle cx="12" cy="12" r="10"/><path d="M2 12h20M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/></svg>'
            . '<span>' . $label . '</span></a>';
    }

    private function insertBeforeBodyEnd(string $html, string $snippet): string
    {
        $pos = strripos($html, '</body>');

        return $pos === false ? $html . $snippet : substr_replace($html, $snippet, $pos, 0);
    }
}
