# Generates app/lib/i18n/en_dictionary.dart from the merged dictionary (+ optional app-only keys).
import json, os
d = json.load(open('merged.json'))
extra = 'app_extra.json'
if os.path.exists(extra):
    d.update(json.load(open(extra)))
def q(s):
    return "'" + s.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$').replace('\n', '\\n').replace('\r', '\\r') + "'"
lines = ['// GENERATED - Arabic phrase => English. Do not edit by hand.', '// ignore_for_file: lines_longer_than_80_chars', '',
         'const Map<String, String> kEnglishDictionary = <String, String>{']
for k in sorted(d):
    lines.append(f'  {q(k)}: {q(d[k])},')
lines.append('};')
open('app/lib/i18n/en_dictionary.dart', 'w').write('\n'.join(lines) + '\n')
print(len(d), 'entries')
