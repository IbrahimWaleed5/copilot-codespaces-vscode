<?php
// Collect every static Arabic phrase from the Laravel project into a key list.
require __DIR__ . '/../src/Runs.php';
use App\Support\Localization\Runs;

$root = $argv[1];
$out  = $argv[2];
$keys = [];   // key => [count, first_source]

function addText(string $text, string $src, array &$keys): void {
    if (!preg_match('/[\x{0600}-\x{06FF}]/u', $text)) return;
    if (preg_match_all(Runs::extended(), $text, $m)) {
        foreach ($m[0] as $run) {
            [$core] = Runs::trim($run);
            $k = Runs::norm($core);
            if ($k === '' || mb_strlen($k) < 2 && !preg_match('/[\x{0621}-\x{064A}]/u', $k)) continue;
            if (!isset($keys[$k])) $keys[$k] = [0, $src];
            $keys[$k][0]++;
        }
    }
}
function phpStrings(string $code): array {
    $out = [];
    foreach (@token_get_all($code) as $t) {
        if (is_array($t) && in_array($t[0], [T_CONSTANT_ENCAPSED_STRING, T_ENCAPSED_AND_WHITESPACE], true)) {
            $s = $t[1];
            if ($t[0] === T_CONSTANT_ENCAPSED_STRING) $s = substr($s, 1, -1);
            $out[] = stripcslashes($s);
        } elseif (is_array($t) && $t[0] === T_INLINE_HTML) {
            $out[] = $t[1];
        }
    }
    return $out;
}
function stripBladeNoise(string $s): string {
    $s = preg_replace('/\{\{--.*?--\}\}/s', ' ', $s);
    $s = preg_replace('/<!--.*?-->/s', ' ', $s);
    // PHP blocks: keep only string literals
    $s = preg_replace_callback('/@php\b(.*?)@endphp/s', fn($m) => ' ' . implode(' | ', phpStrings('<?php ' . $m[1])) . ' ', $s);
    $s = preg_replace_callback('/<\?php(.*?)\?>/s', fn($m) => ' ' . implode(' | ', phpStrings('<?php ' . $m[1])) . ' ', $s);
    // JS/CSS comments inside script/style blocks
    $s = preg_replace_callback('/<(script|style)\b[^>]*>(.*?)<\/\1>/is', function ($m) {
        $body = preg_replace('~/\*.*?\*/~s', ' ', $m[2]);
        $body = preg_replace('~(^|[\s;{}(),])//[^\n]*~', '$1 ', $body);
        return '<' . $m[1] . '>' . $body . '</' . $m[1] . '>';
    }, $s);
    return $s;
}
$it = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($root, FilesystemIterator::SKIP_DOTS));
$n = 0;
foreach ($it as $f) {
    $p = $f->getPathname();
    if (preg_match('/backup|\.zip$|\/vendor\/|\/node_modules\//', $p)) continue;
    $rel = substr($p, strlen($root) + 1);
    if (str_ends_with($p, '.blade.php')) {
        addText(stripBladeNoise(file_get_contents($p)), $rel, $keys); $n++;
    } elseif (str_ends_with($p, '.php')) {
        foreach (phpStrings(file_get_contents($p)) as $s) addText($s, $rel, $keys);
        $n++;
    } elseif (preg_match('/\.(js|json)$/', $p)) {
        $c = file_get_contents($p);
        $c = preg_replace('~/\*.*?\*/~s', ' ', $c);
        $c = preg_replace('~(^|[\s;{}(),])//[^\n]*~', '$1 ', $c);
        addText($c, $rel, $keys); $n++;
    }
}
uasort($keys, fn($a, $b) => $b[0] <=> $a[0]);
file_put_contents($out, json_encode($keys, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT));
$chars = array_sum(array_map('mb_strlen', array_keys($keys)));
fwrite(STDERR, "files=$n keys=" . count($keys) . " chars=$chars\n");
