<?php
namespace App\Support\Localization;

/**
 * Shared definitions for finding translatable Arabic text "runs".
 * The same rules are used to build the dictionary and to translate pages at runtime,
 * so every static Arabic phrase in the code matches a dictionary key exactly.
 */
final class Runs
{
    public const LETTER = '\x{0621}-\x{063A}\x{0641}-\x{064A}\x{0660}-\x{0669}\x{066E}\x{066F}\x{0671}-\x{06D3}\x{06D5}\x{06FA}-\x{06FC}\x{06FF}\x{0750}-\x{077F}\x{FB50}-\x{FDFF}\x{FE70}-\x{FEFC}';
    public const MARK   = '\x{0610}-\x{061A}\x{064B}-\x{065F}\x{0670}\x{06D6}-\x{06ED}\x{0640}\x{200C}-\x{200F}';
    public const PUNCT  = '\x{060C}\x{061B}\x{061F}\x{066A}-\x{066D}\x{06D4}.,:;!?\-\x{2013}\x{2014}()\x{00AB}\x{00BB}\x{2026}\/%';
    public const SPACE  = ' \t\r\n\x{00A0}\x{202F}';

    private static ?string $ext = null;
    private static ?string $strict = null;

    /** Arabic run that may contain Latin words/numbers when more Arabic follows (e.g. "أرسل ملف PDF الآن"). */
    public static function extended(): string
    {
        if (self::$ext === null) {
            $L = self::LETTER; $M = self::MARK; $P = self::PUNCT; $S = self::SPACE;
            $latin = '[A-Za-z0-9][A-Za-z0-9_.@+\-\/:%]*';
            self::$ext = '/[' . $L . '](?:[' . $L . $M . $P . $S . ']|' . $latin . '(?=[' . $S . $P . ']*[' . $L . ']))*/u';
        }
        return self::$ext;
    }

    /** Arabic-only run (no Latin letters or western digits). */
    public static function strict(): string
    {
        if (self::$strict === null) {
            $L = self::LETTER; $M = self::MARK; $P = self::PUNCT; $S = self::SPACE;
            self::$strict = '/[' . $L . '][' . $L . $M . $P . $S . ']*/u';
        }
        return self::$strict;
    }

    /** Split a raw match into [core, trailing] so that trailing spaces / dangling openers stay outside the key. */
    public static function trim(string $run): array
    {
        $core = rtrim($run, " \t\r\n\u{00A0}\u{202F}");
        // drop dangling openers / separators at the end
        while ($core !== '' && preg_match('/[(\x{00AB}\-\x{2013}\x{2014}\/]$/u', $core)) {
            $core = rtrim(mb_substr($core, 0, -1), " \t\r\n\u{00A0}\u{202F}");
        }
        // unbalanced closing bracket / quote at the end belongs to the surrounding text
        foreach ([[')', '('], ["\u{00BB}", "\u{00AB}"]] as [$close, $open]) {
            while ($core !== '' && mb_substr($core, -1) === $close && substr_count($core, $close) > substr_count($core, $open)) {
                $core = rtrim(mb_substr($core, 0, -1), " \t\r\n\u{00A0}\u{202F}");
            }
        }
        return [$core, substr($run, strlen($core))];
    }

    public static function norm(string $s): string
    {
        return trim(preg_replace('/[\s\x{00A0}\x{202F}]+/u', ' ', $s));
    }
}
