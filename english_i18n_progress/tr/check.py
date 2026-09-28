#!/usr/bin/env python3
"""Validate a translated chunk.  usage: python3 check.py chunk_07.json out_07.json"""
import json, re, sys
chunk = json.load(open(sys.argv[1], encoding='utf-8'))
try:
    out = json.load(open(sys.argv[2], encoding='utf-8'))
except Exception as e:
    print('INVALID JSON:', e); sys.exit(1)
ids = {str(i['id']): i['ar'] for i in chunk}
problems = []
missing = [i for i in ids if i not in out]
extra = [i for i in out if i not in ids]
if missing: problems.append(f'missing ids: {missing[:30]}{"..." if len(missing)>30 else ""} ({len(missing)})')
if extra: problems.append(f'unknown ids: {extra[:20]}')
bad = re.compile(r"['\"`\\<>&\n\r]")
ar = re.compile(r'[؀-ۿ]')
tok = re.compile(r'(?<![A-Za-z0-9])(:[a-z_]+|[A-Za-z]*[A-Z0-9][A-Za-z0-9_.\-/%@]*)(?![A-Za-z0-9])')
for i, en in out.items():
    if i not in ids: continue
    if not isinstance(en, str) or not en.strip():
        problems.append(f'{i}: empty'); continue
    if bad.search(en): problems.append(f'{i}: forbidden character in {en!r}')
    if ar.search(en): problems.append(f'{i}: Arabic left in {en!r}')
    src = ids[i]
    for t in set(re.findall(r':[a-z_]+', src)):
        if t not in en: problems.append(f'{i}: placeholder {t} missing')
    for t in set(re.findall(r'[A-Za-z0-9][A-Za-z0-9_.\-/%@]*', src)):
        if t not in en and not t.isdigit(): problems.append(f'{i}: token {t!r} missing -> {en!r}')
print('OK' if not problems else '\n'.join(problems[:80]))
print(f'{len(out)}/{len(ids)} translated, {len(problems)} problems')
