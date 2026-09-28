<?php

namespace App\Support\Localization;

/**
 * Minimal JavaScript scanner: finds string literals (skipping comments and regex literals)
 * and decides which of them are "values" that must never be translated
 * (compared with ==/===/!=, switch cases, includes/indexOf, object keys, status fields...).
 */
final class JsLiterals
{
    private const REGEX_PREV_CHARS = '(,=:[!&|?{};+-*%<>~^';
    private const REGEX_PREV_WORDS = ['return', 'typeof', 'case', 'do', 'else', 'in', 'of', 'new', 'delete', 'void', 'throw', 'instanceof', 'yield', 'await'];

    /**
     * @return array<int, array{0:int,1:int,2:string}> list of [start, end(exclusive), quote]; start/end include the quotes
     */
    public static function scan(string $code): array
    {
        $out = [];
        $n = strlen($code);
        $i = 0;
        $prev = '';      // last significant character
        $prevWord = '';  // last identifier/keyword

        while ($i < $n) {
            $c = $code[$i];

            if ($c === '/' && $i + 1 < $n && $code[$i + 1] === '/') {
                $end = strpos($code, "\n", $i);
                $i = $end === false ? $n : $end;
                continue;
            }
            if ($c === '/' && $i + 1 < $n && $code[$i + 1] === '*') {
                $end = strpos($code, '*/', $i + 2);
                $i = $end === false ? $n : $end + 2;
                continue;
            }
            if ($c === '"' || $c === "'" || $c === '`') {
                $end = $c === '`' ? self::templateEnd($code, $i) : self::stringEnd($code, $i, $c);
                $out[] = [$i, $end, $c];
                $i = $end;
                $prev = $c;
                $prevWord = '';
                continue;
            }
            if ($c === '/') {
                $regexAllowed = $prev === '' || str_contains(self::REGEX_PREV_CHARS, $prev) || in_array($prevWord, self::REGEX_PREV_WORDS, true);
                if ($regexAllowed) {
                    $i = self::regexEnd($code, $i);
                    $prev = '/';
                    $prevWord = '';
                    continue;
                }
            }
            if (ctype_alpha($c) || $c === '_' || $c === '$') {
                $start = $i;
                while ($i < $n && (ctype_alnum($code[$i]) || $code[$i] === '_' || $code[$i] === '$')) {
                    $i++;
                }
                $prevWord = substr($code, $start, $i - $start);
                $prev = 'a';
                continue;
            }
            if (!ctype_space($c)) {
                $prev = $c;
                $prevWord = '';
            }
            $i++;
        }

        return $out;
    }

    /** Values of literals used as data (comparisons, keys, statuses): never translate these anywhere on the page. */
    public static function protectedValues(string $code, ?array $literals = null): array
    {
        $values = [];
        foreach ($literals ?? self::scan($code) as [$start, $end, $quote]) {
            if ($quote === '`') {
                continue;
            }
            if (self::isProtected($code, $start, $end)) {
                $values[Runs::norm(substr($code, $start + 1, $end - $start - 2))] = true;
            }
        }

        return $values;
    }

    public static function isProtected(string $code, int $start, int $end): bool
    {
        $before = rtrim(substr($code, max(0, $start - 160), min($start, 160)));
        $after = ltrim(substr($code, $end, 200));

        return (bool) (
            preg_match('/(?:[=!]==?|\bcase)$/', $before)                         // == 'x', === 'x', case 'x'
            || preg_match('/^(?:[=!]==?(?!>)|in\b|instanceof\b)/', $after)        // 'x' === a, 'x' in obj
            || (preg_match('/[{,]$/', $before) && preg_match('/^:(?!:)/', $after)) // { 'key': ... }
            || (str_ends_with($before, '[') && str_starts_with($after, ']'))      // obj['key']
            || preg_match('/(?:\.(?:includes|indexOf|lastIndexOf|startsWith|endsWith|split|has|get|getItem|setItem|removeItem|querySelector|querySelectorAll|getAttribute|hasAttribute|removeAttribute|closest|matches|localeCompare|replace|replaceAll|search|match|toggle|contains|add|remove)|\b(?:getElementById|getElementsByName|getElementsByClassName|RegExp))\s*\(\s*$/', $before)
            || preg_match('/\.(?:append|set|setAttribute)\s*\(\s*([\'"])[^\'"]*\1\s*,\s*$/', $before)
            || preg_match('/(?:^|[^\w$.])(?:status|state|type|value|action|role|kind|mode|filter|tab|key|name|id|code|category|method|currency|country|field|column|section|step|view|page)\s*(?:[:=]|===?|!==?)\s*$/i', $before)
            || preg_match('/\.(?:value|dataset\.\w+|name|id)\s*=\s*$/', $before)
            || preg_match('/^(?:\s*,\s*(?:\'[^\']*\'|"[^"]*"))*\s*\]\s*\.\s*(?:includes|indexOf|some|find)\s*\(/', $after)
        );
    }

    private static function stringEnd(string $code, int $i, string $q): int
    {
        $n = strlen($code);
        for ($j = $i + 1; $j < $n; $j++) {
            $ch = $code[$j];
            if ($ch === '\\') {
                $j++;
                continue;
            }
            if ($ch === $q) {
                return $j + 1;
            }
            if ($ch === "\n") {
                return $j; // unterminated: stop at line end
            }
        }

        return $n;
    }

    private static function templateEnd(string $code, int $i): int
    {
        $n = strlen($code);
        for ($j = $i + 1; $j < $n; $j++) {
            $ch = $code[$j];
            if ($ch === '\\') {
                $j++;
                continue;
            }
            if ($ch === '`') {
                return $j + 1;
            }
            if ($ch === '$' && $j + 1 < $n && $code[$j + 1] === '{') {
                $depth = 1;
                $j += 2;
                while ($j < $n && $depth > 0) {
                    $cj = $code[$j];
                    if ($cj === '"' || $cj === "'") {
                        $j = self::stringEnd($code, $j, $cj);
                        continue;
                    }
                    if ($cj === '`') {
                        $j = self::templateEnd($code, $j);
                        continue;
                    }
                    if ($cj === '{') {
                        $depth++;
                    } elseif ($cj === '}') {
                        $depth--;
                    }
                    $j++;
                }
                $j--;
            }
        }

        return $n;
    }

    private static function regexEnd(string $code, int $i): int
    {
        $n = strlen($code);
        $inClass = false;
        for ($j = $i + 1; $j < $n; $j++) {
            $ch = $code[$j];
            if ($ch === '\\') {
                $j++;
                continue;
            }
            if ($ch === "\n") {
                return $i + 1; // not a regex after all
            }
            if ($ch === '[') {
                $inClass = true;
            } elseif ($ch === ']') {
                $inClass = false;
            } elseif ($ch === '/' && !$inClass) {
                $j++;
                while ($j < $n && ctype_alpha($code[$j])) {
                    $j++;
                }

                return $j;
            }
        }

        return $i + 1;
    }

    /**
     * Split a template literal body into static text and ${...} expressions.
     * @return array<int, array{0:bool,1:string}> [isExpression, text]
     */
    public static function templateParts(string $body): array
    {
        $parts = [];
        $n = strlen($body);
        $buf = '';
        for ($j = 0; $j < $n; $j++) {
            $ch = $body[$j];
            if ($ch === '\\') {
                $buf .= substr($body, $j, 2);
                $j++;
                continue;
            }
            if ($ch === '$' && $j + 1 < $n && $body[$j + 1] === '{') {
                $parts[] = [false, $buf];
                $buf = '';
                $depth = 0;
                $start = $j;
                for (; $j < $n; $j++) {
                    if ($body[$j] === '{') {
                        $depth++;
                    } elseif ($body[$j] === '}') {
                        $depth--;
                        if ($depth === 0) {
                            break;
                        }
                    }
                }
                $parts[] = [true, substr($body, $start, $j - $start + 1)];
                continue;
            }
            $buf .= $ch;
        }
        $parts[] = [false, $buf];

        return $parts;
    }
}
