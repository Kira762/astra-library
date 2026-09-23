#!/usr/bin/env python3
"""Draw the in-card description layout from the real bundle's geometry.

Runs ``scripts/description_geometry_probe.luau`` through the Luau stubs and the
generated bundle, then draws one panel per element off the reported rects: the
card, the title rows, the control surfaces and the in-card description line.
The line's band is highlighted and every intersection with a control, track,
readout or label inside the same card is listed, so the "description text
overlaps the element UI" question is answered from measured rectangles.

Usage::

    python3 scripts/render_description_preview.py [out.png] [out.html]

Defaults to ``/tmp/astra-description-preview.png`` and
``/tmp/astra-description-preview.html``. Needs Pillow and a Luau CLI (PATH or
/tmp/luau).
"""

import html
import os
import shutil
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROBE = os.path.join(ROOT, "scripts", "description_geometry_probe.luau")
STUBS = os.path.join(ROOT, "scripts", "sidebar_sizing_stubs.luau")
BUNDLE = os.path.join(ROOT, "version-1.luau")
ASSEMBLED = "/tmp/astra_description_geometry.luau"

# ---- palette (matches the library's default theme surfaces) ----------------
S = 1.5                              # card render scale
WIDTH, MARGIN = 1160, 60
BG = (10, 25, 35)
CARD = (21, 29, 40)
STROKE = (42, 54, 70)
ACCENT = (23, 153, 110)
BAND_FILL = (21, 49, 51)             # accent 16% over the card
SURFACE = (34, 41, 52)               # white 5.5% over the card
SURFACE_STROKE = (44, 52, 61)        # white 10% over the card
TITLE = (255, 255, 255)
BODY = (185, 198, 212)
MUTED = (127, 147, 166)
GOOD = (126, 224, 184)
BAD = (255, 140, 140)

FONTS = {
    False: "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    True: "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
}
_fonts = {}


def font(size, bold=False):
    key = (round(size), bold)
    if key not in _fonts:
        _fonts[key] = ImageFont.truetype(FONTS[bold], max(1, round(size * S)))
    return _fonts[key]


def luau_binary():
    found = shutil.which("luau")
    if found:
        return found
    for candidate in ("/tmp/luau", "/usr/local/bin/luau"):
        if os.access(candidate, os.X_OK):
            return candidate
    raise SystemExit("luau CLI not found (looked in PATH, /tmp, /usr/local/bin)")


def assemble():
    with open(ASSEMBLED, "w") as out:
        with open(STUBS) as stubs:
            out.write(stubs.read())
        out.write('\nAstra = (function()\n')
        with open(BUNDLE) as bundle:
            out.write(bundle.read())
        out.write('\nend)()\n')
        with open(PROBE) as probe:
            out.write(probe.read())


def probe_records():
    assemble()
    result = subprocess.run([luau_binary(), ASSEMBLED], capture_output=True, text=True)
    if result.returncode != 0:
        raise SystemExit(result.stdout + result.stderr)
    elements = []
    for line in result.stdout.splitlines():
        fields = line.split("|")
        if fields[0] == "ELEMENT":
            _, kind, name, width, height, described = fields
            elements.append({"kind": kind, "name": name, "w": float(width), "h": float(height),
                             "described": described == "true", "parts": []})
        elif fields[0] == "PART":
            _, name, kind, x, y, w, h, _cls, _bg, text, text_size = fields
            elements[-1]["parts"].append({"name": name, "kind": kind, "x": float(x), "y": float(y),
                                          "w": float(w), "h": float(h), "text": text,
                                          "size": float(text_size)})
    return elements


def overlaps(a, b):
    return not (a["x"] + a["w"] <= b["x"] or b["x"] + b["w"] <= a["x"]
                or a["y"] + a["h"] <= b["y"] or b["y"] + b["h"] <= a["y"])


def content_parts(element):
    """Parts that draw something the description line has to keep clear of."""
    for part in element["parts"]:
        if part["kind"] not in ("Label", "Surface"):
            continue
        if part["kind"] == "Surface" and part["w"] >= element["w"] - 4 and part["h"] >= element["h"] - 4:
            continue  # the card's own background / hover overlay / click target
        yield part


def line_of(element):
    return next((part for part in element["parts"] if part["kind"] == "Description"), None)


def hits_of(element):
    line = line_of(element)
    return [part for part in content_parts(element) if line and overlaps(line, part)]


# ---- PNG -------------------------------------------------------------------

def stamp(draw, x, y, value, size, fill, anchor="la", bold=False):
    draw.text((x, y), value, font=font(size, bold), fill=fill, anchor=anchor)


def draw_card(page, element, top):
    draw = ImageDraw.Draw(page)
    width, height = element["w"] * S, element["h"] * S
    draw.rounded_rectangle([MARGIN, top, MARGIN + width, top + height], radius=12 * S,
                           fill=CARD, outline=STROKE, width=max(1, round(1.5 * S)))

    line = line_of(element)
    hits = hits_of(element)

    def box(part):
        return (MARGIN + part["x"] * S, top + part["y"] * S,
                MARGIN + (part["x"] + part["w"]) * S, top + (part["y"] + part["h"]) * S)

    if line:
        x0, y0, x1, y1 = box(line)
        draw.rounded_rectangle([x0 - 2 * S, y0 - 2 * S, x1 + 2 * S, y1 + 2 * S],
                               radius=4 * S, fill=BAND_FILL, outline=ACCENT, width=1)

    for part in content_parts(element):
        if part["kind"] != "Surface":
            continue
        x0, y0, x1, y1 = box(part)
        draw.rounded_rectangle([x0, y0, x1, y1], radius=min(12 * S, (y1 - y0) / 2),
                               fill=SURFACE, outline=SURFACE_STROKE, width=1)

    for part in element["parts"]:
        if part["kind"] not in ("Label", "Description") or not part["text"]:
            continue
        x0, y0, x1, y1 = box(part)
        right = part["w"] <= 220 and part["x"] + part["w"] >= element["w"] - 60
        stamp(draw, x1 if right else x0, (y0 + y1) / 2 - 1, part["text"], part["size"],
              BODY if part["kind"] == "Description" else TITLE,
              anchor="rm" if right else "lm", bold=part["kind"] == "Label")

    caption = top + height + 16 * S
    label = "{0} · {1} · card {2:.0f}×{3:.0f}px".format(element["name"], element["kind"],
                                                          element["w"], element["h"])
    if line:
        label += " · line y {0:.0f}–{1:.0f}".format(line["y"], line["y"] + line["h"])
    verdict = ("no description prop — card unchanged" if not element["described"]
               else "{0} intersections with the card UI".format(len(hits)))
    stamp(draw, MARGIN, caption, label, 8.4, MUTED, bold=True)
    stamp(draw, WIDTH - MARGIN, caption, verdict, 8.4, GOOD if not hits else BAD,
          anchor="ra", bold=not hits)
    return caption + 30


def write_png(elements, path):
    described = [element for element in elements if element["described"]]
    body = sum(element["h"] * S + 62 for element in elements)
    page = Image.new("RGB", (WIDTH, int(200 + body + 60)), BG)
    draw = ImageDraw.Draw(page)
    stamp(draw, MARGIN, 44, "Astra v1 — element descriptions render inside the card", 14, TITLE, bold=True)
    stamp(draw, MARGIN, 84,
          "Every card below is drawn from the bundle's measured geometry: card rects, title rows, controls and description",
          8.7, MUTED)
    stamp(draw, MARGIN, 104,
          "lines are the rects elements/description.luau lays out. The teal band is the description line the element attaches.",
          8.7, MUTED)
    stamp(draw, MARGIN, 142, "described elements: {0}".format(len(described)), 9, BODY, bold=True)
    total = sum(len(hits_of(element)) for element in described)
    stamp(draw, WIDTH - MARGIN, 142,
          "description ∩ element UI: {0} intersections".format(total), 9,
          GOOD if not total else BAD, anchor="ra", bold=True)

    top = 200
    for element in elements:
        top = draw_card(page, element, top)
    stamp(draw, MARGIN, top + 4,
          "Pinned by scripts/inline_description_test.sh · diagram of measured geometry, not a Roblox screenshot.",
          8.4, MUTED)
    page.crop((0, 0, WIDTH, int(top + 40))).save(path)
    return total


# ---- HTML ------------------------------------------------------------------

def svg_for(element):
    width, height, pad = element["w"], element["h"], 8
    body = ['<rect x="0.5" y="0.5" width="{0:.1f}" height="{1:.1f}" rx="12" fill="#151d28" '
            'stroke="#2a3646"/>'.format(width - 1, height - 1)]
    line = line_of(element)
    if line:
        body.append('<rect x="{0:.1f}" y="{1:.1f}" width="{2:.1f}" height="{3:.1f}" rx="4" '
                    'fill="{4}" fill-opacity="0.16" stroke="{4}" stroke-opacity="0.5"/>'.format(
                        line["x"] - 2, line["y"] - 2, line["w"] + 4, line["h"] + 4, "#17996e"))
    for part in content_parts(element):
        if part["kind"] != "Surface":
            continue
        radius = min(12, part["h"] / 2)
        body.append('<rect x="{0:.1f}" y="{1:.1f}" width="{2:.1f}" height="{3:.1f}" rx="{4:.1f}" '
                    'fill="rgba(255,255,255,0.055)" stroke="rgba(255,255,255,0.10)"/>'.format(
                        part["x"], part["y"], part["w"], part["h"], radius))
    for part in element["parts"]:
        if part["kind"] not in ("Label", "Description") or not part["text"]:
            continue
        right = part["w"] <= 220 and part["x"] + part["w"] >= element["w"] - 60
        colour = "#b9c6d4" if part["kind"] == "Description" else "#ffffff"
        weight = 400 if part["kind"] == "Description" else 500
        x = part["x"] + part["w"] if right else part["x"]
        y = part["y"] + part["h"] / 2 + part["size"] * 0.36
        body.append('<text x="{0:.1f}" y="{1:.1f}" fill="{2}" font-size="{3:.0f}" font-weight="{4}" '
                    'text-anchor="{5}" font-family="Inter, Segoe UI, Helvetica, Arial, sans-serif">{6}</text>'.format(
                        x, y, colour, part["size"], weight, "end" if right else "start",
                        html.escape(part["text"])))
    return ('<svg viewBox="-{0} -{0} {1:.0f} {2:.0f}" width="{3:.0f}" height="{4:.0f}">'.format(
        pad, width + pad * 2, height + pad * 2, width + pad * 2, height + pad * 2)
        + "".join(body) + "</svg>")


def write_html(elements, path):
    described = [element for element in elements if element["described"]]
    total = sum(len(hits_of(element)) for element in described)
    panels = []
    for element in elements:
        line = line_of(element)
        hits = hits_of(element)
        detail = ("no description prop · card unchanged" if not element["described"]
                  else "line y {0:.0f}–{1:.0f} · {2} intersections with the card UI".format(
                      line["y"], line["y"] + line["h"], len(hits)))
        rows = "".join("<li>{0} ({1}) at y {2:.0f}–{3:.0f}</li>".format(
            html.escape(part["name"]), part["kind"], part["y"], part["y"] + part["h"]) for part in hits)
        panels.append(
            '<section class="panel"><header><h2>{0}</h2><span class="badge">{1}</span>'
            '<span class="detail">{2:.0f} × {3:.0f}px · {4}</span></header>'
            '<div class="card {5}">{6}</div>{7}</section>'.format(
                html.escape(element["name"]), element["kind"], element["w"], element["h"], detail,
                "bad" if hits else "ok", svg_for(element),
                '<ul class="hits">{0}</ul>'.format(rows) if rows else ""))
    page = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Astra v1 — in-card element descriptions</title>
<style>
  :root {{ color-scheme: dark; }}
  body {{ margin: 0; padding: 40px 28px 72px; background: #0a1923; color: #dfe8f1;
         font-family: Inter, "Segoe UI", Helvetica, Arial, sans-serif; }}
  .wrap {{ max-width: 760px; margin: 0 auto; }}
  h1 {{ font-size: 26px; margin: 0 0 6px; }}
  .lede {{ color: #93a6b8; font-size: 15px; line-height: 1.6; margin: 0 0 22px; }}
  .summary {{ display: flex; gap: 10px; flex-wrap: wrap; margin: 0 0 30px; }}
  .pill {{ border: 1px solid #2a3646; background: #121b25; border-radius: 999px;
          padding: 7px 14px; font-size: 13px; color: #b9c6d4; }}
  .pill.good {{ border-color: #17996e; color: #7ee0b8; }}
  .panel {{ margin: 0 0 26px; }}
  .panel header {{ display: flex; align-items: baseline; gap: 10px; margin: 0 0 8px; flex-wrap: wrap; }}
  .panel h2 {{ font-size: 15px; margin: 0; font-weight: 600; }}
  .badge {{ font-size: 11px; letter-spacing: .06em; text-transform: uppercase; color: #7f93a6;
           border: 1px solid #2a3646; border-radius: 6px; padding: 2px 6px; }}
  .detail {{ font-size: 12px; color: #7f93a6; }}
  .card {{ overflow-x: auto; padding: 8px; background: #0d1620; border: 1px solid #1b2530; border-radius: 14px; }}
  .card.bad {{ border-color: #d9534f; }}
  .hits {{ color: #ffb4b0; font-size: 13px; margin: 8px 0 0 20px; }}
  footer {{ color: #7f93a6; font-size: 13px; line-height: 1.7; border-top: 1px solid #1b2530; padding-top: 18px; }}
  code {{ background: #121b25; border: 1px solid #1b2530; border-radius: 5px; padding: 1px 5px; font-size: 12px; }}
</style>
</head>
<body>
<div class="wrap">
  <h1>Element descriptions render inside the card</h1>
  <p class="lede">Drawn from the bundle's measured geometry: the card rects, title rows, controls and
  description lines are the rects <code>elements/description.luau</code> lays out. The teal band is the
  description line the element attaches inside its own card; the card grows by the measured wrapped
  height, so the line gets its own band under the controls and the UI keeps the space it always had.</p>
  <div class="summary">
    <span class="pill">described elements: {0}</span>
    <span class="pill good">description ∩ element UI: {1} intersections</span>
  </div>
  {2}
  <footer>Pinned by <code>scripts/inline_description_test.sh</code>: the line is a child of the
  element's own card, the one-line recipe is 41 → 61px with a 14px line at <code>y 37</code>, controls
  stay centred in the base region, a wrapped line grows the card by <code>lines × 17 + 3</code>, and no
  described element's line intersects its title row, control surface, track, readout, group body or card
  edge. Diagram of measured geometry, not a screenshot of the Roblox renderer.</footer>
</div>
</body>
</html>
""".format(len(described), total, "".join(panels))
    with open(path, "w") as handle:
        handle.write(page)


def main(argv):
    png = argv[1] if len(argv) > 1 else "/tmp/astra-description-preview.png"
    page = argv[2] if len(argv) > 2 else "/tmp/astra-description-preview.html"
    elements = probe_records()
    total = write_png(elements, png)
    write_html(elements, page)
    print("wrote {0} and {1}: {2} cards, {3} intersections".format(png, page, len(elements), total))
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
