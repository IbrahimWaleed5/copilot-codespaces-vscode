<?php

namespace App\Support\Localization;

/**
 * Loads the Arabic => English dictionary once per request.
 *
 * lang/auto/en.php        generated dictionary (do not edit by hand)
 * lang/auto/en_custom.php optional manual fixes / additions, same format, wins over en.php
 */
final class Dictionary
{
    private static ?array $map = null;

    public static function load(): array
    {
        if (self::$map !== null) {
            return self::$map;
        }

        $map = [];
        foreach (['en.php', 'en_custom.php'] as $file) {
            $path = self::directory() . DIRECTORY_SEPARATOR . $file;
            if (!is_file($path)) {
                continue;
            }
            try {
                $data = require $path;
                if (!is_array($data)) {
                    continue;
                }
                if ($file === 'en.php') {
                    // generated keys are already normalised
                    $map = $data;
                    continue;
                }
                foreach ($data as $ar => $en) {
                    if (is_string($ar) && is_string($en) && $en !== '') {
                        $map[Runs::norm($ar)] = $en;
                    }
                }
            } catch (\Throwable $e) {
                // A broken file must never break the site: keep what we have.
                if (function_exists('report')) {
                    report($e);
                }
            }
        }

        return self::$map = $map;
    }

    public static function directory(): string
    {
        if (function_exists('base_path')) {
            try {
                return base_path('lang' . DIRECTORY_SEPARATOR . 'auto');
            } catch (\Throwable) {
                // not inside a Laravel app (unit tests)
            }
        }

        return dirname(__DIR__, 3) . DIRECTORY_SEPARATOR . 'lang' . DIRECTORY_SEPARATOR . 'auto';
    }

    /** For tests. */
    public static function set(?array $map): void
    {
        self::$map = $map;
    }
}
