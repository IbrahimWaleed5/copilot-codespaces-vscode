"""Python copy of src/Runs.php (same rules), used by the Flutter extraction tool."""
import re

LETTER = 'ء-غف-ي٠-٩ٮٯٱ-ۓەۺ-ۼۿݐ-ݿﭐ-﷿ﹰ-ﻼ'
MARK = 'ؐ-ًؚ-ٰٟۖ-ۭـ‌-‏'
PUNCT = '،؛؟٪-٭۔.,:;!?\\-–—()«»…/%'
SPACE = ' \t\r\n  '
LATIN = r'[A-Za-z0-9][A-Za-z0-9_.@+\-/:%]*'
EXTENDED = re.compile(f'[{LETTER}](?:[{LETTER}{MARK}{PUNCT}{SPACE}]|{LATIN}(?=[{SPACE}{PUNCT}]*[{LETTER}]))*')
_TRAIL = re.compile(f'[{SPACE}]+$')
_OPENER = re.compile('[(«\\-–—/]$')


def norm(s):
    return re.sub(r'[\s  ]+', ' ', s).strip()


def trim(run):
    core = _TRAIL.sub('', run)
    while core and _OPENER.search(core):
        core = _TRAIL.sub('', core[:-1])
    for close, open_ in ((')', '('), ('»', '«')):
        while core and core.endswith(close) and core.count(close) > core.count(open_):
            core = _TRAIL.sub('', core[:-1])
    return core, run[len(core):]


def runs_of(text):
    """Dictionary keys found in a piece of source text (a Dart string literal with its quotes)."""
    body = re.sub(r'\$\{[^}]*\}|\$[A-Za-z_]\w*', ' {} ', text)  # interpolations split runs, like Blade {{ }}
    keys = []
    for m in EXTENDED.finditer(body):
        core, _ = trim(m.group(0))
        k = norm(core)
        if k and (len(k) >= 2 or re.search('[ء-ي]', k)):
            keys.append(k)
    return keys
