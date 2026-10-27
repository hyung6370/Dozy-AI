#!/usr/bin/env python3
"""Iconsax 24x24 path 들을 SF Symbols 템플릿(2.0) SVG 로 감싼다.
usage: make_symbol.py <name> <paths.json> <out.svg>
paths.json: ["M...","M..."] (fill 경로, 24x24 좌표계)
"""
import sys, json
name, paths_file, out = sys.argv[1:4]


import re as _re
_NUM = _re.compile(r'[-+]?(?:\d+\.\d*|\.\d+|\d+)(?:[eE][-+]?\d+)?')
def transform_path(d, s, tx, ty):
    """uniform scale s + translate 를 path 좌표에 직접 굽는다 (그룹 transform 을 못 읽는 파서 대비)."""
    out = []
    first = True
    for cmd, args in _re.findall(r'([MmLlHhVvCcSsQqTtAaZz])([^MmLlHhVvCcSsQqTtAaZz]*)', d):
        nums = [float(x) for x in _NUM.findall(args)]
        rel = cmd.islower()
        if cmd in 'Zz': out.append('Z'); continue
        if cmd in 'Hh': vals = [n*s + (0 if rel else tx) for n in nums]
        elif cmd in 'Vv': vals = [n*s + (0 if rel else ty) for n in nums]
        elif cmd in 'Aa':
            # 호 인자: rx ry rot large-arc sweep x y — 플래그는 "01.53" 처럼 붙어 나오므로 따로 토큰화
            n = r'[-+]?(?:\d+\.\d*|\.\d+|\d+)(?:[eE][-+]?\d+)?'
            arc = _re.compile(rf'({n})[ ,]*({n})[ ,]*({n})[ ,]*([01])[ ,]*([01])[ ,]*({n})[ ,]*({n})')
            vals = []
            for m in arc.finditer(args):
                rx, ry, rot, laf, sf, x, y = (float(v) for v in m.groups())
                vals += [rx*s, ry*s, rot, laf, sf, x*s + (0 if rel else tx), y*s + (0 if rel else ty)]
        elif cmd == 'm' and first:
            # 맨 앞의 소문자 m 은 절대 moveto (SVG 규칙). 첫 좌표쌍만 이동, 나머지는 상대 lineto.
            vals = [n*s + ((tx if i == 0 else ty) if i < 2 else 0) for i, n in enumerate(nums)]
        else:
            vals = [n*s + (0 if rel else (tx if i % 2 == 0 else ty)) for i, n in enumerate(nums)]
        first = False
        out.append(cmd + ' '.join((f'{int(v)}' if cmd in 'Aa' and j % 7 in (3, 4) else f'{v:.2f}') for j, v in enumerate(vals)))
    return ''.join(out)

W, H = 3300, 2200
spec = json.load(open(paths_file))
paths = spec["paths"] if isinstance(spec, dict) else spec
pre = spec.get("scale", 1.0) if isinstance(spec, dict) else 1.0
if pre != 1.0:   # 24x24 중심(12,12) 기준 확대
    paths = [transform_path(d, pre, 12 - 12 * pre, 12 - 12 * pre) for d in paths]
CAP = 140                      # Capline–Baseline 간격 (템플릿 고정)
ROWS = {"S": 1556, "M": 986, "L": 416}      # Capline y
COLS = {"Ultralight": 559.9, "Thin": 856.1, "Light": 1152.3, "Regular": 1448.6, "Medium": 1744.8,
        "Semibold": 2041, "Bold": 2337.2, "Heavy": 2633.4, "Black": 2929.6}
SCALE = {"S": 9.0 * 0.83, "M": 9.0, "L": 9.0 * 1.25}   # 24 단위 → 템플릿 단위


def variant(weight, scale):
    s = SCALE[scale]
    cx = COLS[weight]
    cy = ROWS[scale] + CAP / 2            # 캡라인·베이스라인 중앙에 아이콘 중심
    tx = cx - 12 * s
    ty = cy - 12 * s
    body = "".join(f'<path d="{transform_path(d, s, tx, ty)}"/>' for d in paths)
    g = f'<g id="{weight}-{scale}">{body}</g>'
    half = 12 * s
    lm = f'<line id="left-margin-{weight}-{scale}" fill="none" stroke="#00AEEF" stroke-width="0.5" x1="{cx-half:.2f}" y1="{ROWS[scale]-50}" x2="{cx-half:.2f}" y2="{ROWS[scale]+CAP+50}"/>'
    rm = f'<line id="right-margin-{weight}-{scale}" fill="none" stroke="#00AEEF" stroke-width="0.5" x1="{cx+half:.2f}" y1="{ROWS[scale]-50}" x2="{cx+half:.2f}" y2="{ROWS[scale]+CAP+50}"/>'
    return g, lm + rm

symbols, margins = [], []
for sc in ROWS:
    for w in COLS:
        g, m = variant(w, sc)
        symbols.append(g); margins.append(m)
guides = "".join(
    f'<line id="{k}-{sc}" fill="none" stroke="#27AAE1" stroke-width="0.5" x1="263" y1="{y}" x2="3036" y2="{y}"/>'
    for sc, cap in ROWS.items() for k, y in (("Capline", cap), ("Baseline", cap + CAP)))
svg = f'''<?xml version="1.0" encoding="UTF-8"?>
<svg version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 {W} {H}">
<g id="Notes">
<rect height="{H}" opacity="0" width="{W}" x="0" y="0"/>
<text style="font-family:'SFProText-Bold';font-size:100px" x="263" y="292">Weight/Scale Variations</text>
<text style="font-family:'SFProText-Regular';font-size:40px" x="263" y="2064">Generated from {name} (Iconsax)</text>
<text id="template-version" style="font-family:'SFProText-Regular';font-size:40px" x="3036" y="2064" text-anchor="end">Template v.2.0</text>
</g>
<g id="Guides">
<g id="H-reference" style="fill:#27AAE1;stroke:none;">
<path d="M85.4 1126 L85.4 986 L111.6 986 L111.6 1045 L170 1045 L170 986 L196.2 986 L196.2 1126 L170 1126 L170 1068 L111.6 1068 L111.6 1126 Z"/>
</g>
{guides}
{"".join(margins)}
</g>
<g id="Symbols">
{"".join(symbols)}
</g>
</svg>
'''
open(out, "w").write(svg)
