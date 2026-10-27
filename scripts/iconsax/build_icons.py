#!/usr/bin/env python3
"""Iconsax 아이콘을 SF Symbols 템플릿 심볼셋으로 만들어 DozyIcons.xcassets 에 넣는다.

    python3 -I scripts/iconsax/build_icons.py            # 전체 재생성
    python3 -I scripts/iconsax/build_icons.py chevron.right bell.fill   # 일부만

- 아이콘 출처: Figma "5000+ Icon Set" = Iconsax (MIT). 경로 데이터는 같은 세트가 담긴 npm `iconsax-react` 에서 읽는다
  (처음 한 번 tarball 을 받아 `scripts/iconsax/.cache/` 에 둔다).
- SF 이름 → Iconsax 컴포넌트 매핑은 `mapping.py` 의 MAP. 새 아이콘은 거기에 한 줄 추가하고 이 스크립트를 돌린 뒤,
  `Dozy AI/Core/Utilities/DozyIcon.swift` 의 customNames 에도 이름을 넣는다 (스크립트가 목록을 출력해 준다).
- 채워진 SF 심볼(*.fill)은 "Bold", 나머지는 "Outline" 변형을 쓴다. "synth:" 는 mapping.py 의 합성 규칙.
"""
import glob, io, json, math, os, re, subprocess, sys, tarfile, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
CATALOG = os.path.join(ROOT, "Dozy AI", "Resources", "DozyIcons.xcassets")
CACHE = os.path.join(HERE, ".cache")
NPM = "https://registry.npmjs.org/iconsax-react/-/iconsax-react-0.0.8.tgz"
sys.path.insert(0, HERE)
from mapping import MAP, TICK, SLASH, DISC  # noqa: E402


def load_npm_icons():
    pkg = os.path.join(CACHE, "package")
    if not os.path.isdir(pkg):
        os.makedirs(CACHE, exist_ok=True)
        data = urllib.request.urlopen(NPM).read()
        tarfile.open(fileobj=io.BytesIO(data), mode="r:gz").extractall(CACHE)
    icons = {}
    for f in glob.glob(os.path.join(pkg, "dist", "esm", "*.js")):
        name = os.path.basename(f)[:-3]
        if name.startswith("_") or name == "index":
            continue
        src = open(f).read()
        variants = {}
        for m in re.finditer(r"var (Bold|Broken|Bulk|Linear|Outline|TwoTone) = function \1\(_ref\d*\) \{(.*?)\n\};", src, re.S):
            paths = []
            for pm in re.finditer(r'createElement\("path", \{(.*?)\}\)', m.group(2), re.S):
                attrs = dict(re.findall(r'(\w+): "([^"]*)"', pm.group(1)))
                paths.append(attrs.get("d", ""))
            variants[m.group(1)] = paths
        icons[name] = variants
    return icons


def star_path():
    pts = []
    for k in range(10):
        r = 10.3 if k % 2 == 0 else 4.6
        a = -math.pi / 2 + k * math.pi / 5
        pts.append((12 + r * math.cos(a), 12.6 + r * math.sin(a)))
    return "M" + " L".join(f"{x:.2f} {y:.2f}" for x, y in pts) + " Z"


def square_path(x0=3, y0=3, x1=21, y1=21, rr=4):
    return (f"M{x0+rr} {y0} H{x1-rr} A{rr} {rr} 0 0 1 {x1} {y0+rr} V{y1-rr} A{rr} {rr} 0 0 1 {x1-rr} {y1} "
            f"H{x0+rr} A{rr} {rr} 0 0 1 {x0} {y1-rr} V{y0+rr} A{rr} {rr} 0 0 1 {x0+rr} {y0} Z")


def spec_for(sf, icons):
    comp, var = MAP[sf]
    if comp.startswith("synth:"):
        kind = comp[6:]
        return {
            "tick": {"paths": [TICK], "scale": 1.9},
            "disc": {"paths": [DISC]},
            "star": {"paths": [star_path()]},
            "square": {"paths": [square_path()]},
            "bell-slash": {"paths": icons["NotificationBing"]["Outline"] + [SLASH]},
            "wifi-slash": {"paths": icons["Wifi"]["Outline"] + [SLASH]},
        }[kind]
    return {"paths": icons[comp][var]}


def main():
    wanted = sys.argv[1:] or list(MAP)
    icons = load_npm_icons()
    os.makedirs(CATALOG, exist_ok=True)
    root_json = os.path.join(CATALOG, "Contents.json")
    if not os.path.exists(root_json):
        open(root_json, "w").write('{\n  "info" : {\n    "author" : "xcode",\n    "version" : 1\n  }\n}\n')
    for sf in wanted:
        name = "ix-" + sf.replace(".", "-")
        d = os.path.join(CATALOG, name + ".symbolset")
        os.makedirs(d, exist_ok=True)
        spec_file = os.path.join(CACHE, "_spec.json")
        json.dump(spec_for(sf, icons), open(spec_file, "w"))
        subprocess.run([sys.executable, "-I", os.path.join(HERE, "make_symbol.py"), name, spec_file,
                        os.path.join(d, name + ".svg")], check=True)
        open(os.path.join(d, "Contents.json"), "w").write(
            '{\n  "info" : {\n    "author" : "xcode",\n    "version" : 1\n  },\n  "symbols" : [\n    {\n'
            f'      "filename" : "{name}.svg",\n      "idiom" : "universal"\n    }}\n  ]\n}}\n')
    print(f"{len(wanted)} symbolset(s) written to {CATALOG}")
    print("DozyIcon.customNames 에 있어야 할 이름:", ", ".join(sorted(MAP)))


if __name__ == "__main__":
    main()
