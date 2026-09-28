<?php

namespace App\Support\Localization;

/**
 * The interface language chosen by the visitor ("ar" = default, "en" = English).
 *
 * This is intentionally separate from app()->getLocale(): the Laravel locale stays
 * Arabic so validation, dates and existing lang/ar files behave exactly as before,
 * and English is produced by translating the finished output.
 */
final class UiLocale
{
    public const DEFAULT = 'ar';
    public const SUPPORTED = ['ar', 'en'];
    public const SESSION_KEY = 'ui_locale';
    public const COOKIE = 'ui_locale';

    private static string $current = self::DEFAULT;

    public static function normalize(mixed $value): ?string
    {
        if (!is_string($value) || $value === '') {
            return null;
        }
        $value = strtolower(substr(trim($value), 0, 2));

        return in_array($value, self::SUPPORTED, true) ? $value : null;
    }

    public static function set(?string $locale): void
    {
        self::$current = self::normalize($locale) ?? self::DEFAULT;
    }

    public static function current(): string
    {
        return self::$current;
    }

    public static function isEnglish(): bool
    {
        return self::$current === 'en';
    }

    public static function enabled(): bool
    {
        $flag = function_exists('env') ? env('UI_I18N_ENABLED', true) : true;

        return !in_array($flag, [false, 0, '0', 'false', 'off', 'no'], true);
    }
}
