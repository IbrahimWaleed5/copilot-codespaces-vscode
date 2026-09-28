<?php

namespace App\View;

use App\Support\Localization\AutoTranslator;
use App\Support\Localization\UiLocale;
use Illuminate\View\Engines\CompilerEngine;

/**
 * Blade engine that translates the finished output to English when the visitor chose English.
 *
 * Only the outermost render is translated (layouts, @include and components are rendered inside it),
 * so every page, mail and PDF is processed exactly once. If translation fails, the original
 * Arabic output is returned.
 */
class TranslatingCompilerEngine extends CompilerEngine
{
    private static int $depth = 0;

    public function get($path, array $data = [])
    {
        self::$depth++;
        try {
            $output = parent::get($path, $data);
        } finally {
            self::$depth--;
        }

        if (self::$depth !== 0 || !is_string($output) || !UiLocale::isEnglish()) {
            return $output;
        }

        try {
            return app(AutoTranslator::class)->translateOutput($output);
        } catch (\Throwable $e) {
            report($e);

            return $output;
        }
    }
}
