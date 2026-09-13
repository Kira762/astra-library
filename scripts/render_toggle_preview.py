"""Render the switch (toggle) preview from scripts/toggle_preview.luau.

Usage: python3 scripts/render_toggle_preview.py [dump.json] [out-dir]
Needs Pillow.

Draws the same geometry the client lays out: element plate (body gradient),
track (with the theme's sheen overlay), knob and the knob's UIShadow as a soft
halo, at 3x scale so a 1px gap is visible.

Two known limits of this offline approximation: Pillow's shape masks leave a
~2px seam at the element plate's own outer edge, and it cannot reproduce
Roblox's stroke-inset/AA behaviour. The switch geometry it measured — the
clearance on each side, printed per state — is also written to a rectangle
report next to the dump (outside the repository);
`scripts/toggle_switch_test.sh` pins the geometry itself.
"""
import json, glob, os, sys
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

DUMP = sys.argv[1] if len(sys.argv) > 1 else '/tmp/toggle_dumps.txt'
OUT_DIR = sys.argv[2] if len(sys.argv) > 2 else '.'

TTF = sorted(glob.glob('/usr/share/fonts/**/*.ttf', recursive=True))
PLAIN = [c for c in TTF if 'Mono' not in c and 'Serif' not in c and 'Bold' not in c]
_fonts = {}
def font(size):
    if size not in _fonts:
        _fonts[size] = ImageFont.truetype(PLAIN[0], size) if PLAIN else ImageFont.load_default()
    return _fonts[size]

SCALE = 3
PAD = 24


def geometry(n, px, py, pw, ph):
    sx, ox, sy, oy = n['pos']
    w = n['size'][0] * pw + n['size'][1]
    h = n['size'][2] * ph + n['size'][3]
    ax, ay = n['anchor']
    x = px + sx * pw + ox - ax * w
    y = py + sy * ph + oy - ay * h
    return x, y, w, h


def rgba(color, alpha):
    return (int(color[0] * 255), int(color[1] * 255), int(color[2] * 255), int(max(0.0, min(1.0, alpha)) * 255))


def collect(n, px, py, pw, ph, out, root=False):
    if not n['visible']:
        return
    # [[Roblox paints equal-ZIndex siblings in child order; sorting by ZIndex
    # [[reproduces what the client actually shows (the track's sheen must land
    # [[under the knob).]]
    n['children'] = sorted(n['children'], key=lambda c: c.get('z', 1))
    if root:
        # [[The dumped root is laid out against the tab page, which is not part
        # [[of the dump: trust the absolute rect it reports.]]
        x, y, w, h = n['x'], n['y'], n['w'], n['h']
    else:
        x, y, w, h = geometry(n, px, py, pw, ph)
    out.append((n, x, y, w, h))
    for c in n['children']:
        collect(c, x, y, w, h, out)


def render(payload, path_out):
    nodes = []
    collect(payload, payload['x'], payload['y'], payload['w'], payload['h'], nodes, root=True)
    xs = [n[1] for n in nodes] + [n[1] + n[3] for n in nodes]
    ys = [n[2] for n in nodes] + [n[2] + n[4] for n in nodes]
    x0, y0 = min(xs), min(ys)
    W = int((max(xs) - x0) * SCALE) + PAD * 2
    H = int((max(ys) - y0) * SCALE) + PAD * 2
    img = Image.new('RGB', (W, H), (28, 26, 36))
    draw = ImageDraw.Draw(img, 'RGBA')

    def px(v, axis):
        return (v - (x0 if axis == 0 else y0)) * SCALE + PAD

    # first pass: halos, so bodies draw over them
    for n, x, y, w, h in nodes:
        if not n['shadow']:
            continue
        sr, sg, sb, st, blur = n['shadow']
        if st >= 1:
            continue
        layer = Image.new('RGBA', img.size, (0, 0, 0, 0))
        ld = ImageDraw.Draw(layer)
        r = min(w, h) * SCALE / 2
        box = [px(x, 0), px(y, 1), px(x + w, 0), px(y + h, 1)]
        ld.rounded_rectangle(box, radius=r, fill=(int(sr * 255), int(sg * 255), int(sb * 255), int((1 - st) * 255)))
        layer = layer.filter(ImageFilter.GaussianBlur(max(1.0, blur * SCALE * 0.5)))
        img.paste(Image.alpha_composite(img.convert('RGBA'), layer).convert('RGB'), (0, 0))

    for n, x, y, w, h in nodes:
        if n['class'] in ('UIShadow', 'UICorner', 'UIStroke', 'UIGradient', 'UIListLayout'):
            continue
        sx, sy = px(x, 0), px(y, 1)
        sw, sh = w * SCALE, h * SCALE
        r = 0
        if n['corner']:
            scale, offset = n['corner']
            r = min(sw, sh) / 2 if scale >= 1 else offset * SCALE
        alpha = 1 - n['backgroundTransparency']
        if n['color'] and alpha > 0:
            col = rgba(n['color'], alpha)
            if r > 0:
                draw.rounded_rectangle([sx, sy, sx + sw, sy + sh], radius=r, fill=col)
            else:
                draw.rectangle([sx, sy, sx + sw, sy + sh], fill=col)
        # [[Each gradient child is drawn as its own vertical ramp, clipped to
        # [[the node's shape: colour from its Colour keypoints, alpha from its
        # [[Transparency keypoints (a sheen is white at partial alpha).]]
        for g in n.get('gradients', []):
            c1 = (int(g[0] * 255), int(g[1] * 255), int(g[2] * 255))
            c2 = (int(g[3] * 255), int(g[4] * 255), int(g[5] * 255))
            a0, a1 = (1 - g[6]) * alpha, (1 - g[7]) * alpha
            if a0 <= 0.002 and a1 <= 0.002:
                continue
            layer = Image.new('RGBA', img.size, (0, 0, 0, 0))
            ld = ImageDraw.Draw(layer)
            steps = max(1, int(sh))
            for i in range(steps):
                t = i / max(1, steps - 1)
                col = tuple(int(c1[k] + (c2[k] - c1[k]) * t) for k in range(3))
                ld.line([(sx, sy + i), (sx + sw, sy + i)],
                        fill=col + (int((a0 + (a1 - a0) * t) * 255),))
            mask = Image.new('L', img.size, 0)
            md = ImageDraw.Draw(mask)
            bounds = [sx, sy, sx + sw + 1, sy + sh + 1]
            if r > 0:
                md.rounded_rectangle(bounds, radius=r, fill=255)
            else:
                md.rectangle(bounds, fill=255)
            base = img.convert('RGBA')
            base.paste(layer, (0, 0), ImageChops.multiply(layer.split()[3], mask))
            img.paste(base.convert('RGB'), (0, 0))
            draw = ImageDraw.Draw(img, 'RGBA')
        if n['stroke']:
            sr, sg, sb, st = n['stroke']
            col = (int(sr * 255), int(sg * 255), int(sb * 255), int((1 - st) * 255))
            if r > 0:
                draw.rounded_rectangle([sx, sy, sx + sw, sy + sh], radius=max(1, r), outline=col, width=SCALE)
            else:
                draw.rectangle([sx, sy, sx + sw, sy + sh], outline=col, width=SCALE)

    img.save(path_out)
    print('rendered', path_out, img.size)

    # report the numbers the screenshot is about, without assuming a size:
    # a track is a pill that contains another pill.
    report = {}
    for n, x, y, w, h in nodes:
        if n['class'] != 'Frame' or not n['corner']:
            continue
        scale, offset = n['corner']
        radius = min(w, h) / 2 if scale >= 1 else offset
        if radius < h / 2 - 0.01:
            continue
        for c, cx, cy, cw, ch in nodes:
            if c is n or not c['corner'] or c['class'] != 'Frame':
                continue
            inside = cx >= x - 0.5 and cx + cw <= x + w + 0.5 and cy >= y - 0.5 and cy + ch <= y + h + 0.5
            if not inside or cw >= w:
                continue
            gaps = dict(
                left=cx - x, right=(x + w) - (cx + cw),
                top=cy - y, bottom=(y + h) - (cy + ch),
            )
            tag = 'active' if gaps['right'] < gaps['left'] else 'rest'
            print(
                f"  track {w:.0f}x{h:.0f}  knob {cw:.0f}x{ch:.0f}  [{tag}] "
                + "  ".join(f"{k}={v:.1f}" for k, v in gaps.items())
            )
            report[tag] = dict(
                track=[x, y, w, h], knob=[cx, cy, cw, ch],
                image=[min(x, cx), min(y, cy), max(x + w, cx + cw), max(y + h, cy + ch)],
            )
    # [[The measured rectangles go next to the dump (a temp file), not next to
    # [[the PNG: rendering a preview must not leave generated files behind in
    # [[the repository.
    with open(DUMP + '.rect.json', 'w') as fh:
        json.dump({'origin': [x0, y0], 'scale': SCALE, 'pad': PAD, 'switches': report}, fh)

dumps = {}
label = None
for line in open(DUMP, encoding='utf-8'):
    line = line.strip()
    if line in ('OFF', 'ON'):
        label = line.lower()
    elif label and line.startswith('{'):
        dumps[label] = json.loads(line)
        label = None

for name, payload in dumps.items():
    render(payload, os.path.join(OUT_DIR, f'toggle-preview-{name}.png'))
