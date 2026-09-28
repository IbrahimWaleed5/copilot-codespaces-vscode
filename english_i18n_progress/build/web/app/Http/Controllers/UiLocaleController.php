<?php

namespace App\Http\Controllers;

use App\Support\Localization\AutoTranslator;
use App\Support\Localization\UiLocale;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Cookie;

class UiLocaleController
{
    /** GET /lang/{locale} : remember the language and go back to the same page. */
    public function switch(Request $request, string $locale)
    {
        $locale = UiLocale::normalize($locale) ?? UiLocale::DEFAULT;

        try {
            if ($request->hasSession()) {
                $request->session()->put(UiLocale::SESSION_KEY, $locale);
            }
        } catch (\Throwable $e) {
            report($e);
        }

        $back = $this->safeBackUrl($request);

        return redirect()->to($back)->withCookie(
            Cookie::create(UiLocale::COOKIE, $locale, time() + 5 * 365 * 86400, '/', null, $request->isSecure(), false, false, 'lax')
        );
    }

    /**
     * POST /lang/translate {"texts": ["...", ...]} -> {"translations": {"...": "..."}}
     * Used by public/js/ui-i18n.js for text added by JavaScript after the page loaded.
     */
    public function translate(Request $request): JsonResponse
    {
        $texts = $request->input('texts');
        $result = [];
        if (is_array($texts)) {
            $translator = app(AutoTranslator::class);
            foreach (array_slice($texts, 0, 150) as $text) {
                if (!is_string($text) || $text === '' || mb_strlen($text) > 3000) {
                    continue;
                }
                try {
                    $result[$text] = $translator->translateText($text);
                } catch (\Throwable $e) {
                    $result[$text] = $text;
                }
            }
        }

        return response()->json(['translations' => (object) $result]);
    }

    private function safeBackUrl(Request $request): string
    {
        $home = url('/');
        $previous = (string) $request->headers->get('referer', '');
        if ($previous === '') {
            return $home;
        }
        $host = parse_url($previous, PHP_URL_HOST);
        if ($host !== null && $host !== $request->getHost()) {
            return $home;
        }
        // drop an old ?lang= so it does not override the new choice
        $parts = parse_url($previous);
        if (!empty($parts['query'])) {
            parse_str($parts['query'], $query);
            unset($query['lang']);
            $previous = strtok($previous, '?') . ($query ? '?' . http_build_query($query) : '') . (isset($parts['fragment']) ? '#' . $parts['fragment'] : '');
        }
        if (str_contains($previous, '/lang/')) {
            return $home;
        }

        return $previous;
    }
}
