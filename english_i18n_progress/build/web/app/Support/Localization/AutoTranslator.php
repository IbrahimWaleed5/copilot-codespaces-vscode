<?php

namespace App\Support\Localization;

/**
 * Translates rendered output (HTML pages, fragments, mails, JSON) from Arabic to English
 * using the generated dictionary, and mirrors the layout to left-to-right.
 *
 * Rules:
 *  - text nodes + the attributes placeholder, title, alt, aria-label, label, content are translated;
 *  - value, name, data-*, href, id ... are NEVER translated (they are data sent to the server);
 *  - in JavaScript only string literals are translated, except values used in comparisons,
 *    switch cases, includes()/indexOf(), object keys or status-like fields (see JsLiterals);
 *  - unknown text stays as it is. Any failure returns the original output unchanged.
 */
final class AutoTranslator
{
    private const TEXT_ATTRS = ['placeholder', 'title', 'alt', 'aria-label', 'label', 'content', 'aria-placeholder', 'aria-description', 'aria-roledescription', 'aria-valuetext', 'wire:confirm'];
    private const DATA_ATTRS = ['value', 'name', 'id', 'for', 'href', 'src', 'action'];
    private const RAW_TEXT_TAGS = ['script', 'style', 'textarea'];
    private const VOID_TAGS = ['area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input', 'link', 'meta', 'source', 'track', 'wbr'];
    private const JSON_KEYS = ['message', 'error', 'errors', 'title', 'body', 'label', 'text', 'description', 'hint', 'note'];
    private const MARK = 'data-i18n-ltr';
    private const TAG_RE = '/\G<(\/?)([a-zA-Z][a-zA-Z0-9:._-]*)((?:\s+[^\s"\'>\/=]+(?:\s*=\s*(?:"[^"]*"|\'[^\']*\'|[^\s"\'=<>`]+))?|\s*\/(?!>))*)\s*(\/?)>/';

    /** @var array<string,string>|null */
    private ?array $dict = null;
    /** @var \Closure|null */
    private $loader;
    /** @var array<string,bool> */
    private array $protected = [];

    /**
     * @param array<string,string>|\Closure $dictionary Arabic => English map, or a closure returning it (lazy)
     */
    public function __construct(array|\Closure $dictionary, private bool $flip = true)
    {
        if ($dictionary instanceof \Closure) {
            $this->loader = $dictionary;
        } else {
            $this->dict = $dictionary;
        }
    }

    /* ------------------------------------------------------------------ public API */

    /** Translate any rendered view output. Never throws. */
    public function translateOutput(string $output): string
    {
        if ($output === '') {
            return $output;
        }
        try {
            $trim = ltrim($output);
            if (str_starts_with($trim, '<?xml') || !str_contains($output, '<')) {
                return $this->translateText($output);
            }

            return $this->translateHtml($output);
        } catch (\Throwable $e) {
            self::report($e);

            return $output;
        }
    }

    public function translateHtml(string $html): string
    {
        $hasArabic = self::hasArabic($html);
        if (!$hasArabic && !$this->flip) {
            return $html;
        }
        $this->protected = $hasArabic ? $this->collectProtected($html) : [];

        $out = '';
        $n = strlen($html);
        $pos = 0;
        $skip = null; // [tagName, depth] while inside translate="no"

        while ($pos < $n) {
            $lt = strpos($html, '<', $pos);
            if ($lt === false) {
                $out .= $this->text(substr($html, $pos), $skip);
                break;
            }
            if ($lt > $pos) {
                $out .= $this->text(substr($html, $pos, $lt - $pos), $skip);
            }
            if (substr_compare($html, '<!--', $lt, 4) === 0) {
                $end = strpos($html, '-->', $lt + 4);
                $end = $end === false ? $n : $end + 3;
                $out .= substr($html, $lt, $end - $lt);
                $pos = $end;
                continue;
            }
            if (substr_compare($html, '<!', $lt, 2) === 0 || substr_compare($html, '<?', $lt, 2) === 0) {
                $end = strpos($html, '>', $lt);
                $end = $end === false ? $n : $end + 1;
                $out .= substr($html, $lt, $end - $lt);
                $pos = $end;
                continue;
            }
            if (!preg_match(self::TAG_RE, $html, $m, 0, $lt)) {
                $out .= '<';
                $pos = $lt + 1;
                continue;
            }
            $tag = $m[0];
            $closing = $m[1] === '/';
            $name = strtolower($m[2]);
            $selfClosing = $m[4] === '/' || in_array($name, self::VOID_TAGS, true);
            $pos = $lt + strlen($tag);

            // translate="no" / class="notranslate" regions
            if ($skip !== null && $name === $skip[0] && !$selfClosing) {
                $skip[1] += $closing ? -1 : 1;
                if ($skip[1] <= 0) {
                    $skip = null;
                }
            } elseif ($skip === null && !$closing && !$selfClosing && preg_match('/\stranslate\s*=\s*["\']?no\b|\sclass\s*=\s*["\'][^"\']*\bnotranslate\b|\scontenteditable\b/i', $m[3])) {
                $skip = [$name, 1];
            }

            $rendered = $closing ? $tag : $this->tag($tag, $name, $m[3], $m[4] === '/', $skip !== null);
            if (!$closing && $name === 'style' && $this->flip && !preg_match('/\s' . self::MARK . '\b/', $m[3])) {
                $rendered = substr($rendered, 0, -1) . ' ' . self::MARK . '>';
            }
            $out .= $rendered;

            if (!$closing && in_array($name, self::RAW_TEXT_TAGS, true)) {
                $close = stripos($html, '</' . $name, $pos);
                $close = $close === false ? $n : $close;
                $body = substr($html, $pos, $close - $pos);
                $out .= $this->rawText($name, $m[3], $body, $skip !== null);
                $pos = $close;
            }
        }

        return $out;
    }

    /** Translate plain text (a text node, an attribute value, a JSON message...). */
    public function translateText(string $text): string
    {
        if (!self::hasArabic($text)) {
            return $text;
        }
        $dict = $this->dict();

        $result = preg_replace_callback(Runs::extended(), function ($m) use ($dict) {
            [$core, $trail] = Runs::trim($m[0]);
            if ($core === '') {
                return $m[0];
            }
            $en = $this->lookup($core, $dict);
            if ($en !== null) {
                return $en . $trail;
            }

            return $this->translatePieces($core, $dict) . $trail;
        }, $text);

        return $result ?? $text;
    }

    /** Translate the display strings of a JavaScript snippet. */
    public function translateJs(string $code): string
    {
        if (!self::hasArabic($code)) {
            return $code;
        }
        $literals = JsLiterals::scan($code);
        $protected = $this->protected + JsLiterals::protectedValues($code, $literals);
        $out = '';
        $last = 0;
        foreach ($literals as [$start, $end, $quote]) {
            $raw = substr($code, $start, $end - $start);
            if (!self::hasArabic($raw)) {
                continue;
            }
            $closed = strlen($raw) >= 2 && substr($raw, -1) === $quote;
            $body = $closed ? substr($raw, 1, -1) : substr($raw, 1);
            if ($quote !== '`' && (isset($protected[Runs::norm($body)]) || JsLiterals::isProtected($code, $start, $end))) {
                continue;
            }
            if ($quote === '`') {
                $new = '';
                foreach (JsLiterals::templateParts($body) as [$isExpr, $part]) {
                    $new .= $isExpr ? $part : $this->translateText($part);
                }
            } else {
                $new = $this->translateText($body);
            }
            if ($new === $body) {
                continue;
            }
            $out .= substr($code, $last, $start - $last) . $quote . $new . ($closed ? $quote : '');
            $last = $end;
        }

        return $last === 0 ? $code : $out . substr($code, $last);
    }

    /** Translate user-facing keys of a decoded JSON payload (message, errors, title...). */
    public function translateJson(mixed $data): mixed
    {
        try {
            return $this->jsonWalk($data, false);
        } catch (\Throwable $e) {
            self::report($e);

            return $data;
        }
    }

    public static function hasArabic(string $s): bool
    {
        return (bool) preg_match('/[\x{0621}-\x{064A}\x{0671}-\x{06D3}]/u', $s);
    }

    /* ------------------------------------------------------------------ HTML pieces */

    private function text(string $text, ?array $skip): string
    {
        return $skip === null ? $this->translateText($text) : $text;
    }

    private function tag(string $tag, string $name, string $attrs, bool $selfClose, bool $noTranslate): string
    {
        if ($attrs === '' || trim($attrs) === '') {
            return $tag;
        }
        $alreadyFlipped = (bool) preg_match('/\s' . self::MARK . '(?:[\s=>\/]|$)/', $attrs);
        $isButtonInput = $name === 'input'
            && preg_match('/\stype\s*=\s*["\']?(?:submit|button|reset)\b/i', $attrs)
            && !preg_match('/\sname\s*=/i', $attrs);
        $flipped = false;

        $newAttrs = preg_replace_callback(
            '/(\s+)([^\s"\'>\/=]+)(?:(\s*=\s*)("([^"]*)"|\'([^\']*)\'|([^\s"\'=<>`]+)))?/',
            function ($m) use ($name, $noTranslate, $alreadyFlipped, $isButtonInput, &$flipped) {
                if (!isset($m[3]) || $m[3] === '') {
                    return $m[0];
                }
                $attr = strtolower($m[2]);
                $q = $m[4][0] === '"' || $m[4][0] === "'" ? $m[4][0] : '';
                $value = $q === '' ? $m[4] : substr($m[4], 1, -1);
                $new = $value;

                if (!$noTranslate && self::hasArabic($value)) {
                    if (in_array($attr, self::TEXT_ATTRS, true) || ($attr === 'value' && $isButtonInput)) {
                        $new = $this->translateText($value);
                    } elseif (self::isJsAttribute($attr)) {
                        $new = $this->translateJs($value);
                    }
                }
                if ($this->flip) {
                    if ($attr === 'dir' && strtolower(trim($value)) === 'rtl') {
                        $new = 'ltr';
                    } elseif ($attr === 'lang' && $name === 'html') {
                        $new = 'en';
                    } elseif (!$alreadyFlipped && $attr === 'class') {
                        $new = LtrFlipper::flipClasses($new);
                    } elseif (!$alreadyFlipped && $attr === 'style') {
                        $new = LtrFlipper::flipDeclarations($new);
                    } elseif (!$alreadyFlipped && ($attr === ':class' || $attr === 'x-bind:class')) {
                        $new = preg_replace_callback('/([\'"])([^\'"]*)\1/', fn ($c) => $c[1] . LtrFlipper::flipClasses($c[2]) . $c[1], $new) ?? $new;
                    }
                    if (in_array($attr, ['class', 'style', ':class', 'x-bind:class'], true) && $new !== $value) {
                        $flipped = true;
                    }
                }
                if ($new === $value) {
                    return $m[0];
                }
                if ($q === '') {
                    $q = '"';
                }

                return $m[1] . $m[2] . $m[3] . $q . $new . $q;
            },
            $attrs
        );
        if ($newAttrs === null) {
            return $tag;
        }
        if ($flipped) {
            $newAttrs .= ' ' . self::MARK;
        }
        if ($newAttrs === $attrs) {
            return $tag;
        }
        $head = '<' . substr($tag, 1, strlen($name));

        return $head . $newAttrs . ($selfClose ? ' />' : '>');
    }

    private function rawText(string $name, string $attrs, string $body, bool $noTranslate): string
    {
        if ($name === 'textarea') {
            return $body; // user-editable content: leave untouched
        }
        if ($name === 'style') {
            return ($this->flip && !preg_match('/\s' . self::MARK . '\b/', $attrs)) ? $this->flipStyleBlock($body) : $body;
        }
        // script
        if ($noTranslate) {
            return $body;
        }
        $type = preg_match('/\stype\s*=\s*["\']?([^"\'\s>]+)/i', $attrs, $t) ? strtolower($t[1]) : '';
        if ($type === '' || in_array($type, ['text/javascript', 'module', 'application/javascript', 'text/babel'], true)) {
            return $this->translateJs($body);
        }
        if (in_array($type, ['text/template', 'text/x-template', 'text/html', 'text/x-handlebars-template', 'text/ng-template'], true)) {
            $saved = $this->protected;
            try {
                return $this->translateHtml($body);
            } finally {
                $this->protected = $saved;
            }
        }

        return $body; // application/json, ld+json, importmap, ... are data
    }

    private function flipStyleBlock(string $css): string
    {
        // keep rules written specifically for rtl/ltr untouched
        return LtrFlipper::flipStylesheet($css);
    }

    private static function isJsAttribute(string $attr): bool
    {
        return str_starts_with($attr, 'on')
            || str_starts_with($attr, '@')
            || str_starts_with($attr, 'x-on:')
            || str_starts_with($attr, 'x-bind:')
            || (str_starts_with($attr, ':') && !str_starts_with($attr, '::'))
            || in_array($attr, ['x-data', 'x-text', 'x-html', 'x-init', 'x-show', 'x-effect', 'x-if'], true);
    }

    /** Arabic values that are data somewhere on the page (form values, data-*, JS comparisons). */
    private function collectProtected(string $html): array
    {
        $values = [];
        if (preg_match_all('/\s(?:value|name|id|for|data-[\w-]+|x-model[\w.-]*|wire:model[\w.-]*)\s*=\s*(?:"([^"]*)"|\'([^\']*)\')/i', $html, $mm, PREG_SET_ORDER)) {
            foreach ($mm as $m) {
                $v = $m[1] !== '' ? $m[1] : ($m[2] ?? '');
                if ($v !== '' && self::hasArabic($v)) {
                    $values[Runs::norm(html_entity_decode($v, ENT_QUOTES | ENT_HTML5, 'UTF-8'))] = true;
                }
            }
        }
        if (preg_match_all('/<script\b([^>]*)>(.*?)<\/script\s*>/is', $html, $mm, PREG_SET_ORDER)) {
            foreach ($mm as $m) {
                if (self::hasArabic($m[2])) {
                    $values += JsLiterals::protectedValues($m[2]);
                }
            }
        }
        if (preg_match_all('/\s(?:on\w+|@[\w.:-]+|x-[\w.:-]+|:[\w.-]+)\s*=\s*"([^"]*)"/i', $html, $mm)) {
            foreach ($mm[1] as $code) {
                if (self::hasArabic($code)) {
                    $values += JsLiterals::protectedValues($code);
                }
            }
        }
        // Never protect plain display words that are also stored as values somewhere else
        // than the current page: nothing else to do here.
        return $values;
    }

    /* ------------------------------------------------------------------ JSON */

    private function jsonWalk(mixed $data, bool $translate): mixed
    {
        if (is_string($data)) {
            return $translate ? $this->translateText($data) : $data;
        }
        if (is_array($data)) {
            foreach ($data as $k => $v) {
                $data[$k] = $this->jsonWalk($v, $translate || (is_string($k) && in_array(strtolower($k), self::JSON_KEYS, true)));
            }

            return $data;
        }
        if (is_object($data)) {
            foreach (get_object_vars($data) as $k => $v) {
                $data->$k = $this->jsonWalk($v, $translate || in_array(strtolower((string) $k), self::JSON_KEYS, true));
            }

            return $data;
        }

        return $data;
    }

    /* ------------------------------------------------------------------ dictionary */

    private function dict(): array
    {
        if ($this->dict === null) {
            try {
                $this->dict = ($this->loader)();
            } catch (\Throwable $e) {
                self::report($e);
                $this->dict = [];
            }
        }

        return $this->dict;
    }

    private function lookup(string $core, array $dict): ?string
    {
        $key = Runs::norm($core);
        if ($key === '') {
            return null;
        }
        if (isset($dict[$key])) {
            return $dict[$key];
        }
        // same phrase with a different final punctuation (e.g. "الحالة:" vs "الحالة")
        if (preg_match('/^(.*?)\s*([:.!?\x{061F}\x{060C}\x{061B}\x{2026}]+)$/u', $key, $m) && isset($dict[$m[1]])) {
            return rtrim($dict[$m[1]], ' ') . strtr($m[2], ["\u{061F}" => '?', "\u{060C}" => ',', "\u{061B}" => ';']);
        }

        return null;
    }

    /** Fallback for a run that is not in the dictionary as a whole: translate its parts. */
    private function translatePieces(string $core, array $dict): string
    {
        // 1) Arabic-only sub-runs (the run contained Latin words / numbers)
        $changed = false;
        $res = preg_replace_callback(Runs::strict(), function ($s) use ($dict, &$changed) {
            [$c, $t] = Runs::trim($s[0]);
            $en = $c === '' ? null : $this->lookup($c, $dict);
            if ($en === null) {
                return $s[0];
            }
            $changed = true;

            return $en . $t;
        }, $core) ?? $core;
        if ($changed && !self::hasArabic($res)) {
            return self::latinPunctuation($res);
        }
        // 1b) the whole run is a sequence of known phrases ("تم تحويل طلبك إلى استشارة رقم" + "55")
        $seq = $this->segment($core, $dict);
        if ($seq !== null) {
            return self::latinPunctuation($seq);
        }

        // 2) pieces separated by punctuation or line breaks ("الحالة، التاريخ", "أ - ب")
        $pieces = preg_split('/(\s*[\x{060C}\x{061B}\x{061F}!?;,()\x{00AB}\x{00BB}|\/\x{2013}\x{2014}]+\s*|\s+-\s+|\s*\n\s*|\s{2,}|(?<=[.:])\s+)/u', $core, -1, PREG_SPLIT_DELIM_CAPTURE);
        if ($pieces === false || count($pieces) < 2) {
            return $changed ? $res : $core;
        }
        $any = false;
        foreach ($pieces as $i => $piece) {
            if ($i % 2 === 1 || trim($piece) === '') {
                continue;
            }
            $en = $this->lookup($piece, $dict) ?? $this->segment($piece, $dict);
            if ($en === null) {
                $sub = preg_replace_callback(Runs::strict(), function ($s) use ($dict) {
                    [$c, $t] = Runs::trim($s[0]);
                    $e = $c === '' ? null : $this->lookup($c, $dict);

                    return $e === null ? $s[0] : $e . $t;
                }, $piece) ?? $piece;
                if ($sub !== $piece) {
                    $pieces[$i] = $sub;
                    $any = true;
                }
                continue;
            }
            $pieces[$i] = $en;
            $any = true;
        }
        if (!$any) {
            return $changed ? $res : $core;
        }
        $joined = implode('', $pieces);

        return self::hasArabic($joined) ? $joined : self::latinPunctuation($joined);
    }

    /**
     * All-or-nothing split of a run into known phrases (fewest pieces wins).
     * Returns null unless EVERY word is covered, so free text written by users is never
     * turned into a mix of English and Arabic words.
     */
    private function segment(string $core, array $dict): ?string
    {
        $tokens = preg_split('/(\s+)/u', trim($core), -1, PREG_SPLIT_DELIM_CAPTURE) ?: [];
        $words = [];
        $seps = [];
        foreach ($tokens as $k => $tok) {
            if ($k % 2 === 0) {
                $words[] = $tok;
            } else {
                $seps[] = $tok;
            }
        }
        $n = count($words);
        if ($n < 2 || $n > 60) {
            return null;
        }
        $best = array_fill(0, $n + 1, null); // best[i] = [pieces, text] for words[0..i)
        $best[0] = [0, '', 0]; // [pieces, text, longest Arabic piece in words]
        for ($i = 1; $i <= $n; $i++) {
            for ($j = max(0, $i - 14); $j < $i; $j++) {
                if ($best[$j] === null) {
                    continue;
                }
                $phrase = implode(' ', array_slice($words, $j, $i - $j));
                $en = $this->lookup($phrase, $dict);
                if ($en === null && $i - $j === 1 && !self::hasArabic($phrase)) {
                    $en = $phrase; // numbers / Latin tokens between phrases
                }
                if ($en === null) {
                    continue;
                }
                $pieces = $best[$j][0] + 1;
                $longest = max($best[$j][2], self::hasArabic($phrase) ? $i - $j : 0);
                if ($best[$i] === null || $pieces < $best[$i][0] || ($pieces === $best[$i][0] && $longest > $best[$i][2])) {
                    $sep = $j === 0 ? '' : (str_contains($seps[$j - 1], "\n") ? $seps[$j - 1] : ' ');
                    $best[$i] = [$pieces, ($j === 0 ? '' : rtrim($best[$j][1], ' ') . $sep) . $en, $longest];
                }
            }
        }

        if ($best[$n] === null) {
            return null;
        }
        // Accept only when it looks like known phrases around a value, not word-by-word guessing:
        // at most 3 pieces, and the longest Arabic piece has 3+ words.
        return $best[$n][0] <= 3 && $best[$n][2] >= 3 ? $best[$n][1] : null;
    }

    private static function latinPunctuation(string $s): string
    {
        return strtr($s, ["\u{060C}" => ',', "\u{061B}" => ';', "\u{061F}" => '?']);
    }

    private static function report(\Throwable $e): void
    {
        if (function_exists('report')) {
            try {
                report($e);
            } catch (\Throwable) {
            }
        }
    }
}
