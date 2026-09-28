#!/usr/bin/env python3
"""
Flutter helper for the English interface (used by the maintainer, not by the end user).

  python3 tools/flutter_i18n.py extract <lib_dir> <dictionary.json> <out_missing.json>
      Lists Arabic display strings of the app that are not in the dictionary yet
      (same run rules as the website), ready to be translated like tr/chunk_NN.json.

  python3 tools/flutter_i18n.py wrap <lib_dir> [--dry-run]
      Adds .tr() to Arabic DISPLAY strings only:
        * the text of Text(...), SelectableText(...), TextSpan(text: ...), Tab(text: ...)
        * named arguments such as labelText:, hintText:, helperText:, errorText:, tooltip:,
          message:, title:, subtitle:, label:, content:, semanticLabel:, ...
      Never touches: comparisons (== / !=), switch cases, map keys, default parameter values,
      const/final declarations, strings already followed by .tr().
      Removes every `const` that encloses a wrapped string and adds the i18n import.
      Writes a report of what it changed and what it skipped (wrap_report.txt).
"""
import json
import os
import re
import sys

ARABIC = re.compile(r'[ء-يٱ-ۓ]')
TEXT_CALLS = {'Text', 'SelectableText', 'AutoSizeText', 'Tooltip'}
TEXT_LABELS = {
    'text', 'labelText', 'hintText', 'helperText', 'errorText', 'counterText', 'prefixText', 'suffixText',
    'tooltip', 'message', 'semanticLabel', 'semanticsLabel', 'title', 'subtitle', 'label', 'content',
    'confirmText', 'cancelText', 'helpText', 'fieldLabelText', 'fieldHintText', 'errorFormatText',
    'errorInvalidText', 'placeholder', 'hint', 'description', 'buttonText', 'actionLabel', 'barrierLabel',
    'emptyText', 'loadingText', 'errorMessage', 'successMessage', 'body', 'heading', 'caption', 'note',
}


# ----------------------------------------------------------------------------- tokenizer
class Tok:
    __slots__ = ('kind', 'text', 'start', 'end')

    def __init__(self, kind, text, start, end):
        self.kind, self.text, self.start, self.end = kind, text, start, end

    def __repr__(self):
        return f'{self.kind}:{self.text!r}'


def string_end(src, i):
    """i points at the opening quote (or r prefix). Returns end index (exclusive)."""
    raw = False
    if src[i] in 'rR':
        raw = True
        i += 1
    q = src[i]
    triple = src.startswith(q * 3, i)
    delim = q * 3 if triple else q
    j = i + len(delim)
    n = len(src)
    while j < n:
        if not raw and src[j] == '\\':
            j += 2
            continue
        if not raw and src[j] == '$' and j + 1 < n and src[j + 1] == '{':
            depth = 1
            j += 2
            while j < n and depth:
                c = src[j]
                if c in '\'"' or (c in 'rR' and j + 1 < n and src[j + 1] in '\'"' and not src[j - 1].isalnum()):
                    j = string_end(src, j)
                    continue
                if c == '{':
                    depth += 1
                elif c == '}':
                    depth -= 1
                j += 1
            continue
        if src.startswith(delim, j):
            return j + len(delim)
        if not triple and src[j] == '\n':
            return j
        j += 1
    return n


def tokenize(src):
    toks = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c.isspace():
            i += 1
            continue
        if src.startswith('//', i):
            j = src.find('\n', i)
            i = n if j < 0 else j
            continue
        if src.startswith('/*', i):
            depth, j = 1, i + 2
            while j < n and depth:
                if src.startswith('/*', j):
                    depth += 1
                    j += 2
                elif src.startswith('*/', j):
                    depth -= 1
                    j += 2
                else:
                    j += 1
            i = j
            continue
        if c in '\'"' or (c in 'rR' and i + 1 < n and src[i + 1] in '\'"' and (i == 0 or not (src[i - 1].isalnum() or src[i - 1] == '_'))):
            j = string_end(src, i)
            toks.append(Tok('str', src[i:j], i, j))
            i = j
            continue
        if c.isalpha() or c == '_' or c == '$':
            j = i
            while j < n and (src[j].isalnum() or src[j] in '_$'):
                j += 1
            toks.append(Tok('id', src[i:j], i, j))
            i = j
            continue
        if c.isdigit():
            j = i
            while j < n and (src[j].isalnum() or src[j] == '.'):
                j += 1
            toks.append(Tok('num', src[i:j], i, j))
            i = j
            continue
        for op in ('...?', '...', '??=', '==', '!=', '=>', '?.', '??', '&&', '||', '<=', '>='):
            if src.startswith(op, i):
                toks.append(Tok('op', op, i, i + len(op)))
                i += len(op)
                break
        else:
            toks.append(Tok('op', c, i, i + 1))
            i += 1
    return toks


# ----------------------------------------------------------------------------- analysis
def const_before(toks, k):
    """Index of a `const` keyword that makes the construct starting at token k constant, else None.
    Handles: const Foo(, const Foo.named(, const Foo<T>(, const [, const <T>[, const {."""
    j = k - 1
    # skip generic type arguments <...>
    if j >= 0 and toks[j].text == '>':
        depth = 0
        while j >= 0:
            if toks[j].text == '>':
                depth += 1
            elif toks[j].text == '<':
                depth -= 1
                if depth == 0:
                    j -= 1
                    break
            j -= 1
    if j >= 0 and toks[j].text == 'const':
        return j
    return None


def call_name_and_const(toks, k):
    """toks[k] is '('. Returns (name, const_index) for Foo( / Foo.bar( / Foo<T>( / const Foo(."""
    j = k - 1
    if j >= 0 and toks[j].text == '>':  # generic call Foo<T>(
        depth = 0
        while j >= 0:
            if toks[j].text == '>':
                depth += 1
            elif toks[j].text == '<':
                depth -= 1
                if depth == 0:
                    j -= 1
                    break
            j -= 1
    if j < 0 or toks[j].kind != 'id':
        return None, None, k
    name = toks[j].text
    start = j
    if j >= 2 and toks[j - 1].text == '.' and toks[j - 2].kind == 'id':  # Foo.named(
        name = toks[j - 2].text if toks[j - 2].text[:1].isupper() else toks[j].text
        start = j - 2
    const = const_before(toks, start)
    return name, const, const if const is not None else start


def analyse(src):
    toks = tokenize(src)
    stack = []  # frames: dict(open, name, const, label, tok_index)
    results = []
    i = 0
    while i < len(toks):
        t = toks[i]
        if t.text in '([{' and t.kind == 'op':
            frame = {'open': t.text, 'name': None, 'const': None, 'label': None, 'idx': i, 'start': i}
            if t.text == '(':
                frame['name'], frame['const'], frame['start'] = call_name_and_const(toks, i)
            else:
                frame['const'] = const_before(toks, i)
                frame['start'] = frame['const'] if frame['const'] is not None else i
            stack.append(frame)
        elif t.text in ')]}' and t.kind == 'op':
            if stack:
                stack.pop()
        elif t.text == ',' and stack:
            stack[-1]['label'] = None
        elif t.kind == 'id' and i + 1 < len(toks) and toks[i + 1].text == ':' and stack and stack[-1]['open'] in '({':
            prev = toks[i - 1].text if i else ''
            if prev in ('(', ',', '{'):
                stack[-1]['label'] = t.text
        elif t.kind == 'str':
            # group adjacent string literals: 'a' 'b'
            j = i
            while j + 1 < len(toks) and toks[j + 1].kind == 'str':
                j += 1
            group = toks[i:j + 1]
            text = ''.join(g.text for g in group)
            if ARABIC.search(text):
                results.append(decide(toks, i, j, stack, src))
            i = j + 1
            continue
        i += 1
    return toks, results


def decide(toks, i, j, stack, src):
    first, last = toks[i], toks[j]
    prev = toks[i - 1] if i > 0 else None
    nxt = toks[j + 1] if j + 1 < len(toks) else None
    nxt2 = toks[j + 2] if j + 2 < len(toks) else None
    info = {'start': first.start, 'end': last.end, 'text': src[first.start:last.end], 'wrap': False, 'why': '',
            'consts': [], 'group': j > i}
    frame = stack[-1] if stack else None

    def skip(why):
        info['why'] = why
        return info

    if nxt and nxt.text == '.' and nxt2 and nxt2.text in ('tr', 'tr_'):
        return skip('already translated')
    if nxt and nxt.text == '.':
        return skip('method called on the string')
    if prev and prev.text in ('==', '!=', 'case', '=>', 'import', 'export', 'part', '@'):
        return skip(f'used with {prev.text}')
    if nxt and nxt.text in ('==', '!=', '=>'):
        return skip(f'used with {nxt.text}')
    if prev and prev.text == '=':
        return skip('assigned / default value')
    if nxt and nxt.text == ':' and not (prev and prev.text == '?'):
        return skip('map key')
    if prev and prev.text == '(' and frame and frame['name'] in ('contains', 'startsWith', 'endsWith', 'indexOf', 'split', 'replaceAll', 'where', 'firstWhere', 'containsKey', 'remove'):
        return skip('argument of ' + frame['name'])
    if frame is None:
        return skip('top level')
    if frame['open'] == '[' or frame['open'] == '{':
        return skip('inside a list/map/set literal')
    ok = (frame['name'] in TEXT_CALLS and frame['label'] is None) or (frame['label'] in TEXT_LABELS)
    if frame['name'] == 'TextSpan' and frame['label'] == 'text':
        ok = True
    if not ok:
        return skip(f"not a display argument ({frame['name']}{'.' + frame['label'] if frame['label'] else ''})")
    # a constant that must stay constant (const declaration, default parameter value, ...)
    for f in stack:
        before = toks[f['start'] - 1] if f['start'] > 0 else None
        if before is not None and before.text == '=':
            if f['const'] is not None or _is_declaration(toks, f['start'] - 1):
                return skip('inside a constant value (const declaration / default value)')
    info['wrap'] = True
    info['consts'] = sorted({toks[f['const']].start for f in stack if f['const'] is not None})
    return info


def _is_declaration(toks, k):
    """toks[k] is '='. True when it belongs to a `const ... name =` declaration."""
    j = k - 1
    while j >= 0 and (toks[j].kind == 'id' or toks[j].text in ('<', '>', ',', '?', '.')):
        if toks[j].text == 'const':
            return True
        j -= 1
    return False


def enclosing_const_decl(src, pos):
    """True if pos is inside the initializer of a `const x = ...;` or default parameter."""
    line_start = src.rfind('\n', 0, pos) + 1
    head = src[line_start:pos]
    return bool(re.match(r'\s*(static\s+)?const\s+[\w<>?, ]+\s*=', head))


def wrap_source(src, rel_import):
    toks, results = analyse(src)
    edits = []  # (start, end, replacement)
    changed, skipped = [], []
    for r in results:
        if r['wrap'] and enclosing_const_decl(src, r['start']):
            r['wrap'], r['why'] = False, 'inside a const declaration'
        if not r['wrap']:
            skipped.append(r)
            continue
        text = r['text']
        repl = f'({text}).tr()' if r['group'] else f'{text}.tr()'
        edits.append((r['start'], r['end'], repl))
        for c in r['consts']:
            end = c + len('const')
            while end < len(src) and src[end] in ' \t':
                end += 1
            edits.append((c, end, ''))
        changed.append(r)
    if not edits:
        return src, changed, skipped
    # apply edits from the end, de-duplicated
    seen = set()
    out = src
    for start, end, repl in sorted(set(edits), key=lambda e: (e[0], e[1]), reverse=True):
        if (start, end) in seen:
            continue
        seen.add((start, end))
        out = out[:start] + repl + out[end:]
    out = add_import(out, rel_import)
    return out, changed, skipped


def add_import(src, rel_import):
    line = f"import '{rel_import}';"
    if line in src or re.search(r"import\s+'[^']*i18n/i18n\.dart';", src):
        return src
    if re.search(r'^\s*part\s+of\b', src, re.M):
        return src  # imports go to the library file
    imports = list(re.finditer(r'^import\s+[^;]+;\s*$', src, re.M))
    if imports:
        pos = imports[-1].end()
        return src[:pos] + '\n' + line + src[pos:]
    lib = re.search(r'^library\b[^;]*;\s*$', src, re.M)
    if lib:
        return src[:lib.end()] + '\n' + line + '\n' + src[lib.end():]
    return line + '\n' + src


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    cmd, lib = sys.argv[1], sys.argv[2].rstrip('/')
    files = []
    for dp, _, fns in os.walk(lib):
        for fn in fns:
            if fn.endswith('.dart') and '/i18n' not in dp.replace('\\', '/')[len(lib):]:
                files.append(os.path.join(dp, fn))
    files.sort()

    if cmd == 'extract':
        sys.path.insert(0, os.path.dirname(__file__))
        dictionary = json.load(open(sys.argv[3], encoding='utf-8'))
        from runs import runs_of  # noqa
        missing = {}
        for f in files:
            src = open(f, encoding='utf-8').read()
            _, results = analyse(src)
            for r in results:
                if not r['wrap']:
                    continue
                body = re.sub(r"(['\"])\s+[rR]?\1", '', r['text'])  # 'a' 'b' -> 'ab'
                for key in runs_of(body):
                    if key not in dictionary and key not in missing:
                        missing[key] = os.path.relpath(f, lib)
        items = [{'id': i, 'f': src_f, 'ar': k} for i, (k, src_f) in enumerate(sorted(missing.items()))]
        json.dump(items, open(sys.argv[4], 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
        print(f'{len(files)} files, {len(items)} phrases missing from the dictionary -> {sys.argv[4]}')
        return

    if cmd == 'wrap':
        dry = '--dry-run' in sys.argv
        report = []
        total_changed = total_skipped = 0
        part_parents = {}
        for f in files:
            src = open(f, encoding='utf-8').read()
            for m in re.finditer(r"^part\s+'([^']+)';", src, re.M):
                part_parents[os.path.normpath(os.path.join(os.path.dirname(f), m.group(1)))] = f
        needs_import = set()
        for f in files:
            src = open(f, encoding='utf-8').read()
            rel = os.path.relpath(os.path.join(lib, 'i18n', 'i18n.dart'), os.path.dirname(f)).replace('\\', '/')
            out, changed, skipped = wrap_source(src, rel)
            if changed and re.search(r'^\s*part\s+of\b', src, re.M):
                parent = part_parents.get(os.path.normpath(f))
                if parent:
                    needs_import.add(parent)
            total_changed += len(changed)
            total_skipped += len(skipped)
            if changed or skipped:
                report.append(f'## {os.path.relpath(f, lib)}')
                report += [f'  + {c["text"][:90]}' for c in changed]
                report += [f'  - {s["text"][:70]}   ({s["why"]})' for s in skipped]
            if out != src and not dry:
                open(f, 'w', encoding='utf-8').write(out)
        for parent in needs_import:
            src = open(parent, encoding='utf-8').read()
            rel = os.path.relpath(os.path.join(lib, 'i18n', 'i18n.dart'), os.path.dirname(parent)).replace('\\', '/')
            out = add_import(src, rel)
            if out != src and not dry:
                open(parent, 'w', encoding='utf-8').write(out)
        open('wrap_report.txt', 'w', encoding='utf-8').write('\n'.join(report) + '\n')
        print(f'{len(files)} files: {total_changed} strings wrapped, {total_skipped} Arabic strings left as they are (see wrap_report.txt)')
        return

    print(__doc__)
    sys.exit(1)


if __name__ == '__main__':
    main()
