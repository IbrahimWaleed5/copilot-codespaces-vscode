# Generates public/css/ui-ltr.css: Tailwind (v3/v4 default scale) definitions of the physical
# classes produced by LtrFlipper (ml<->mr, pl<->pr, left<->right, ...), so they exist even when
# the compiled Tailwind file was purged of them.
sp = {'0':'0px','px':'1px','0.5':'0.125rem','1':'0.25rem','1.5':'0.375rem','2':'0.5rem','2.5':'0.625rem','3':'0.75rem','3.5':'0.875rem',
      '4':'1rem','5':'1.25rem','6':'1.5rem','7':'1.75rem','8':'2rem','9':'2.25rem','10':'2.5rem','11':'2.75rem','12':'3rem','14':'3.5rem',
      '16':'4rem','20':'5rem','24':'6rem','28':'7rem','32':'8rem','36':'9rem','40':'10rem','44':'11rem','48':'12rem','52':'13rem','56':'14rem',
      '60':'15rem','64':'16rem','72':'18rem','80':'20rem','96':'24rem'}
frac = {'1/2':'50%','1/3':'33.333333%','2/3':'66.666667%','1/4':'25%','3/4':'75%','full':'100%'}
def esc(c): return c.replace('.', r'\.').replace('/', r'\/').replace(':', r'\:')
rules = []
def add(cls, decl): rules.append((cls, decl))
for side, prop in (('l','left'),('r','right')):
    for k, v in sp.items():
        add(f'm{side}-{k}', f'margin-{prop}:{v}')
        add(f'p{side}-{k}', f'padding-{prop}:{v}')
        if k != '0':
            add(f'-m{side}-{k}', f'margin-{prop}:-{v}')
    add(f'm{side}-auto', f'margin-{prop}:auto')
for prop in ('left','right'):
    for k, v in {**sp, **frac}.items():
        add(f'{prop}-{k}', f'{prop}:{v}')
        if k not in ('0',):
            add(f'-{prop}-{k}', f'{prop}:-{v}')
    add(f'{prop}-auto', f'{prop}:auto')
    add(f'text-{prop}', f'text-align:{prop}')
    add(f'float-{prop}', f'float:{prop}')
    add(f'clear-{prop}', f'clear:{prop}')
for side, prop in (('l','left'),('r','right')):
    add(f'border-{side}', f'border-{prop}-width:1px')
    for w in ('0','2','4','8'):
        add(f'border-{side}-{w}', f'border-{prop}-width:{w}px')
radius = {'none':'0px','sm':'0.125rem','':'0.25rem','md':'0.375rem','lg':'0.5rem','xl':'0.75rem','2xl':'1rem','3xl':'1.5rem','full':'9999px'}
for k, v in radius.items():
    sfx = f'-{k}' if k else ''
    add(f'rounded-l{sfx}', f'border-top-left-radius:{v};border-bottom-left-radius:{v}')
    add(f'rounded-r{sfx}', f'border-top-right-radius:{v};border-bottom-right-radius:{v}')
    add(f'rounded-tl{sfx}', f'border-top-left-radius:{v}')
    add(f'rounded-tr{sfx}', f'border-top-right-radius:{v}')
    add(f'rounded-bl{sfx}', f'border-bottom-left-radius:{v}')
    add(f'rounded-br{sfx}', f'border-bottom-right-radius:{v}')
bps = [('sm','640px'),('md','768px'),('lg','1024px'),('xl','1280px'),('2xl','1536px')]
out = ['/* LTR helpers for the English interface (loaded only when the page is in English). Generated - do not edit. */']
out += [f'.{esc(c)}{{{d}}}' for c, d in rules]
for bp, w in bps:
    out.append(f'@media (min-width:{w}){{')
    out += [f'.{esc(bp + ":" + c)}{{{d}}}' for c, d in rules]
    out.append('}')
open('web/public/css/ui-ltr.css', 'w').write('\n'.join(out) + '\n')
print(len(rules), 'rules')
