<?php

namespace App\Support\Localization;

/**
 * Mirrors right-to-left styling for the English (left-to-right) interface:
 * CSS declarations (<style> blocks and style="" attributes) and Tailwind physical classes.
 */
final class LtrFlipper
{
    /** Properties whose value is a single left/right keyword (or a list containing them). */
    private const KEYWORD_PROPS = ['float', 'clear', 'text-align', 'text-align-last', 'background-position', 'background-position-x', 'transform-origin', 'object-position'];

    /** top right bottom left shorthands. */
    private const BOX_PROPS = ['margin', 'padding', 'inset', 'border-width', 'border-style', 'border-color', 'scroll-margin', 'scroll-padding'];

    /** Flip every declaration block of a stylesheet (selectors are left untouched). */
    public static function flipStylesheet(string $css): string
    {
        $out = preg_replace_callback('/\{([^{}]*)\}/', fn ($m) => '{' . self::flipDeclarations($m[1]) . '}', $css);

        return $out ?? $css;
    }

    /** Flip a list of declarations such as "margin-left:4px; float:right". */
    public static function flipDeclarations(string $decls): string
    {
        if (!preg_match('/left|right|rtl|margin|padding|inset|border|radius/i', $decls)) {
            return $decls;
        }
        // "left: 50%; transform: translateX(-50%)" centring must keep its side.
        $centred = (bool) preg_match('/translate(?:X|3d)?\(\s*-50%/i', $decls);

        $out = preg_replace_callback(
            '/(^|[;{\s])([a-zA-Z-]+)(\s*:\s*)((?:[^;"\'()]|\([^()]*(?:\([^()]*\)[^()]*)*\)|"[^"]*"|\'[^\']*\')*)/',
            function ($m) use ($centred) {
                [$all, $lead, $prop, $colon, $value] = $m;
                $lower = strtolower($prop);

                if (($lower === 'left' || $lower === 'right') && $centred && preg_match('/^\s*50%/', $value)) {
                    return $all;
                }
                if ($lower === 'direction') {
                    return $lead . $prop . $colon . preg_replace('/\brtl\b/i', 'ltr', $value);
                }
                $newProp = preg_match('/(^|-)(left|right)(-|$)/', $lower) ? self::swapWords($prop) : $prop;

                if (in_array($lower, self::KEYWORD_PROPS, true)) {
                    $value = self::swapWords($value);
                } elseif (in_array($lower, self::BOX_PROPS, true)) {
                    $value = self::swapBox($value);
                } elseif ($lower === 'border-radius') {
                    $value = self::swapRadius($value);
                }

                return $lead . $newProp . $colon . $value;
            },
            $decls
        );

        return $out ?? $decls;
    }

    /** Swap Tailwind physical utility classes (ml-4 <-> mr-4, text-right -> text-left, ...). */
    public static function flipClasses(string $classes): string
    {
        if (!preg_match('/(?:^|[\s:!-])(?:m[lr]|p[lr]|scroll-[mp][lr]|left|right|text-(?:left|right)|float-(?:left|right)|clear-(?:left|right)|border-[lr]|rounded-(?:[lr]|[tb][lr])|bg-gradient-to-|space-x-reverse|divide-x-reverse)/', $classes)) {
            return $classes;
        }
        $centred = (bool) preg_match('/(?:^|\s)-?translate-x-1\/2(?:\s|$)/', $classes);
        $parts = preg_split('/(\s+)/', $classes, -1, PREG_SPLIT_DELIM_CAPTURE) ?: [$classes];

        foreach ($parts as $i => $token) {
            if ($token === '' || ctype_space($token)) {
                continue;
            }
            if (!preg_match('/^((?:[^\s:]+:)*)(!?)(-?)(.+)$/', $token, $m)) {
                continue;
            }
            [, $variants, $important, $neg, $core] = $m;

            if ($core === 'space-x-reverse' || $core === 'divide-x-reverse') {
                $parts[$i] = '';
                continue;
            }
            if ($centred && preg_match('/^(left|right)-1\/2$/', $core)) {
                continue;
            }
            $new = $core;
            if (preg_match('/^(m|p|scroll-m|scroll-p)([lr])(-.+)$/', $core, $c)) {
                $new = $c[1] . ($c[2] === 'l' ? 'r' : 'l') . $c[3];
            } elseif (preg_match('/^(left|right)(-.+)$/', $core, $c)) {
                $new = ($c[1] === 'left' ? 'right' : 'left') . $c[2];
            } elseif (preg_match('/^(text|float|clear)-(left|right)$/', $core, $c)) {
                $new = $c[1] . '-' . ($c[2] === 'left' ? 'right' : 'left');
            } elseif (preg_match('/^(border|rounded)-([lr])((?:-.+)?)$/', $core, $c)) {
                $new = $c[1] . '-' . ($c[2] === 'l' ? 'r' : 'l') . $c[3];
            } elseif (preg_match('/^rounded-([tb])([lr])((?:-.+)?)$/', $core, $c)) {
                $new = 'rounded-' . $c[1] . ($c[2] === 'l' ? 'r' : 'l') . $c[3];
            } elseif (preg_match('/^bg-gradient-to-([tb]?)([lr])$/', $core, $c)) {
                $new = 'bg-gradient-to-' . $c[1] . ($c[2] === 'l' ? 'r' : 'l');
            }
            $parts[$i] = $variants . $important . $neg . $new;
        }

        $result = trim(preg_replace('/\s{2,}/', ' ', implode('', $parts)) ?? $classes);
        preg_match('/^\s*/', $classes, $lead);
        preg_match('/\s*$/', $classes, $tail);

        return $lead[0] . $result . $tail[0];
    }

    private static function swapWords(string $s): string
    {
        return strtr($s, ['left' => 'right', 'right' => 'left', 'Left' => 'Right', 'Right' => 'Left']);
    }

    /** "1px 2px 3px 4px" -> "1px 4px 3px 2px" (only the 4-value form is asymmetric). */
    private static function swapBox(string $value): string
    {
        [$body, $tail] = self::splitImportant($value);
        $tokens = self::tokens($body);
        if (count($tokens) !== 4) {
            return $value;
        }
        [$t, $r, $b, $l] = $tokens;

        return self::leading($value) . "$t $l $b $r" . $tail;
    }

    private static function swapRadius(string $value): string
    {
        [$body, $tail] = self::splitImportant($value);
        if (str_contains($body, '/')) {
            return $value;
        }
        $v = self::tokens($body);
        $new = match (count($v)) {
            2 => [$v[1], $v[0]],
            3 => [$v[1], $v[0], $v[1], $v[2]],
            4 => [$v[1], $v[0], $v[3], $v[2]],
            default => null,
        };

        return $new === null ? $value : self::leading($value) . implode(' ', $new) . $tail;
    }

    private static function splitImportant(string $value): array
    {
        if (preg_match('/^(.*?)(\s*!important\s*)$/is', $value, $m)) {
            return [$m[1], $m[2]];
        }
        $trimmed = rtrim($value);

        return [$trimmed, substr($value, strlen($trimmed))];
    }

    private static function leading(string $value): string
    {
        return substr($value, 0, strlen($value) - strlen(ltrim($value)));
    }

    private static function tokens(string $value): array
    {
        preg_match_all('/(?:[^\s()]+(?:\([^()]*\))?)+/', trim($value), $m);

        return $m[0];
    }
}
