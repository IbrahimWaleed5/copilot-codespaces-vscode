#!/usr/bin/env python3
"""
Translate at the DISPLAY POINT instead of at the string literal.

  python3 tools/flutter_i18n_sinks.py <lib_dir> [--dry-run]

Wraps the value shown by:
  * Text(<x>) / SelectableText(<x>)                     -> Text(trUi(<x>))
  * labelText:/hintText:/helperText:/errorText:/counterText:/prefixText:/suffixText:/tooltip:
    Tooltip(message:), TextSpan(text:), Tab(text:)        -> label: trUiN(<x>)
so Arabic strings that live in lists, maps, switch expressions, models or custom-widget
parameters are translated too. trUi/trUiN only translate when English is selected and only
text fully covered by the dictionary, so user content (names, chat) normally stays unchanged.
Values used for logic are never touched (only what is displayed).
Removes enclosing `const`, skips constant contexts, adds the i18n import. Writes sinks_report.txt.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from flutter_i18n import tokenize, call_name_and_const, const_before, add_import, _is_declaration  # noqa: E402

ARABIC = re.compile(r'[ء-يٱ-ۓ]')
TEXT_WIDGETS = {'Text', 'SelectableText'}
NAMED_SINKS = {'labelText', 'hintText', 'helperText', 'errorText', 'counterText', 'prefixText', 'suffixText', 'tooltip',
               'helpText', 'cancelText', 'confirmText', 'fieldLabelText', 'fieldHintText', 'errorFormatText',
               'errorInvalidText', 'searchFieldLabel', 'barrierLabel'}
FRAME_NAMED_SINKS = {('Tooltip', 'message'), ('TextSpan', 'text'), ('Tab', 'text'), ('BottomNavigationBarItem', 'label'),
                     ('NavigationDestination', 'label'), ('SnackBarAction', 'label'), ('MaterialApp', 'title'),
                     ('Semantics', 'label'), ('SearchBar', 'hintText')}
NON_NULL_SINKS = {('NavigationDestination', 'label'), ('SnackBarAction', 'label'), ('MaterialApp', 'title')}
SKIP_EXPR = re.compile(r'(?i)(email|phone|mobile|\burl\b|link|token|iban|password|\botp\b|controller|\. text\b|\bcode\b)')
ALREADY = re.compile(r'(\.tr\(\)\s*$|^\s*trUiN?\(|translateUi|\.translate\(|AppLanguage)')
SIMPLE = re.compile(r"^[A-Za-z_$][\w$]*(?:(?:\.|\?\.)[A-Za-z_$][\w$]*|\[[^\[\]]*\]|!)*$")


def wrap_file(src):
    toks = tokenize(src)
    stack = []
    edits = []
    wrapped = []
    skipped = []

    def constant_context():
        for f in stack:
            before = toks[f['start'] - 1] if f['start'] > 0 else None
            if before is not None and before.text == '=' and (f['const'] is not None or _is_declaration(toks, f['start'] - 1)):
                return True
        return False

    def process(frame, s, e):
        """Argument tokens s..e (inclusive) of a '(' frame."""
        if s > e:
            return
        label = None
        if toks[s].kind == 'id' and s + 1 <= e and toks[s + 1].text == ':':
            label = toks[s].text
            s += 2
            if s > e:
                return
        name, ctor = frame['name'], frame['ctor']
        if label is None:
            if not (name in TEXT_WIDGETS and ctor is None and frame['pos'] == 0):
                return
            kind = 'text'
        elif label in NAMED_SINKS or (name, label) in FRAME_NAMED_SINKS:
            kind = 'named'
        else:
            return
        start, end = toks[s].start, toks[e].end
        expr = src[start:end]
        one_string = s == e and toks[s].kind == 'str'
        if one_string and not ARABIC.search(expr):
            return
        code_only = ' '.join(tk.text for tk in toks[s:e + 1] if tk.kind != 'str')
        if ALREADY.search(expr):
            return
        has_arabic_literal = any(tk.kind == 'str' and ARABIC.search(tk.text) for tk in toks[s:e + 1])
        if SKIP_EXPR.search(code_only) and not has_arabic_literal:
            skipped.append((expr, 'looks like data (email/phone/code/...)'))
            return
        if not one_string and s < e and toks[s].kind == 'num':
            return
        if constant_context():
            skipped.append((expr, 'constant context'))
            return
        if one_string:
            repl = expr + '.tr()'
        else:
            maybe_null = any(tk.text in ('null', '?.', '??') for tk in toks[s:e + 1]) or not has_arabic_literal
            non_null = kind == 'text' or (name, label) in NON_NULL_SINKS or not maybe_null
            repl = ('trUi(' if non_null else 'trUiN(') + expr + ')'
        edits.append((start, end, repl))
        for f in stack:
            if f['const'] is not None:
                c = toks[f['const']].start
                stop = c + 5
                while stop < len(src) and src[stop] in ' \t':
                    stop += 1
                edits.append((c, stop, ''))
        wrapped.append(repl)

    i = 0
    n = len(toks)
    while i < n:
        t = toks[i]
        if t.kind == 'op' and t.text in '([{':
            frame = {'open': t.text, 'name': None, 'ctor': None, 'const': None, 'start': i, 'arg': i + 1, 'pos': 0}
            if t.text == '(':
                name, const, start = call_name_and_const(toks, i)
                frame['name'], frame['const'], frame['start'] = name, const, start
                if name and i >= 3 and toks[i - 2].text == '.' and toks[i - 3].text == name:
                    frame['ctor'] = toks[i - 1].text  # Text.rich(
            else:
                frame['const'] = const_before(toks, i)
                frame['start'] = frame['const'] if frame['const'] is not None else i
            stack.append(frame)
        elif t.kind == 'op' and t.text in ')]}':
            if stack:
                frame = stack[-1]
                if frame['open'] == '(':
                    process_frame = frame
                    stack_top = stack.pop()
                    stack.append(stack_top)
                    process(process_frame, frame['arg'], i - 1)
                stack.pop()
        elif t.kind == 'op' and t.text == ',' and stack and stack[-1]['open'] == '(':
            frame = stack[-1]
            is_named = toks[frame['arg']].kind == 'id' and frame['arg'] + 1 < n and toks[frame['arg'] + 1].text == ':'
            process(frame, frame['arg'], i - 1)
            if not is_named:
                frame['pos'] += 1
            frame['arg'] = i + 1
        i += 1

    if not edits:
        return src, wrapped, skipped
    out = src
    seen = set()
    for start, end, repl in sorted(set(edits), key=lambda x: (x[0], -x[1]), reverse=True):
        if (start, end) in seen:
            continue
        seen.add((start, end))
        out = out[:start] + repl + out[end:]
    return out, wrapped, skipped


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    lib = sys.argv[1].rstrip('/')
    dry = '--dry-run' in sys.argv
    files = []
    for dp, _, fns in os.walk(lib):
        if os.sep + 'i18n' in dp[len(lib):]:
            continue
        files += [os.path.join(dp, f) for f in fns if f.endswith('.dart')]
    parents = {}
    for f in files:
        for m in re.finditer(r"^part\s+'([^']+)';", open(f, encoding='utf-8').read(), re.M):
            parents[os.path.normpath(os.path.join(os.path.dirname(f), m.group(1)))] = f
    report, total, need_import = [], 0, set()
    for f in sorted(files):
        src = open(f, encoding='utf-8').read()
        out, wrapped, skipped = wrap_file(src)
        if wrapped:
            total += len(wrapped)
            target = parents.get(os.path.normpath(f)) if re.search(r'^\s*part\s+of\b', src, re.M) else f
            if target:
                need_import.add(target)
            report.append(f'## {os.path.relpath(f, lib)}  (+{len(wrapped)})')
            report += [f'  - skipped: {s[:80]}  ({why})' for s, why in skipped]
        if out != src and not dry:
            open(f, 'w', encoding='utf-8').write(out)
    for f in need_import:
        src = open(f, encoding='utf-8').read()
        if re.search(r"import\s+'[^']*(i18n/i18n|i18n/localized_text|i18n/app_language)\.dart';", src):
            continue
        rel = os.path.relpath(os.path.join(lib, 'i18n', 'i18n.dart'), os.path.dirname(f)).replace('\\', '/')
        out = add_import(src, rel)
        if out != src and not dry:
            open(f, 'w', encoding='utf-8').write(out)
    open('sinks_report.txt', 'w', encoding='utf-8').write('\n'.join(report) + '\n')
    print(f'{len(files)} files, {total} display points now translated (see sinks_report.txt)')


if __name__ == '__main__':
    main()
