# Astra design system

The rules the interface is built from, and the tokens that carry them
(`utilities/tokens.luau`). Anything that adds a number, a size or a surface to
the UI should come from here rather than from a literal in one element.

## 1. One surface per view

A view has **one** surface: the band it already sits on. Sections separate with
whitespace or a 1px hairline — never with a nested box.

| Composition | Treatment |
|---|---|
| Page heading, metadata, prose | flat — `CreatePageHeader`, `CreateText({ plain = true })` |
| Section labels | flat — `CreateSection` (13px, muted) |
| Expandable information | flat row — `CreateIsolated({ plain = true })`, hairline above |
| Controls | one card each — Buttons, Toggles, Sliders, Inputs, … |

A card exists to say "this is a control". Information does not get one. Elements
that own no surface set the internal `_plain` flag, which is what stops a reveal
from painting a card onto them (`Window:_elementBackgroundTransparency`).

## 2. Type

Five sizes, two weights.

| Role | Size | Weight | Used by |
|---|---|---|---|
| Page title | 20 | 600 | `CreatePageHeader` title |
| Title | 16 | 600 | card and row titles, `CreateText` heading |
| Body | 14 | 400 | body copy, nav labels, row subtitles |
| Label | 13 | 400 | section labels |
| Caption | 12 | 400 | metadata lines |

Muted tints are alphas, not colours: `tokens.alpha.meta` (0.55) for metadata and
section labels, `tokens.alpha.muted` (0.45) for body copy and prose.

The font is neutral (`Enum.Font.BuilderSans` by default; `Font.fromName("Inter")`
for the `brand` selection) — no display face, so emphasis comes from weight and
colour instead of from a novelty typeface.

## 3. Spacing

Everything sits on an 8pt grid: 8 / 12 / 16 / 24, plus a single 4px half-step
for the gap between an icon and its label inside one row.

| Token | Value | Used by |
|---|---|---|
| `space.half` | 4 | icon → label gap, heading → metadata gap |
| `space.sm` | 8 | paragraph step, plain-row icon gap |
| `space.md` | 12 | card padding |
| `space.lg` | 16 | section step, plain-row leading inset |
| `space.xl` | 24 | page-level separation |

Page inset is 10px each side (the `1, -20` width recipe every element keeps) and
is deliberately not card padding.

## 4. Icons

16px inside a nav row or inline with text (`icon.nav`, `icon.inline`); 20px when
a glyph carries a row or a page on its own (`icon.standalone`). One stroke
weight and one colour token per context — icons never introduce a size of their
own.

## 5. Emphasis

One primary action per view. Everything else stays muted grey; colour
(`AccentColor`, `TabSelected`) is reserved for state, not decoration:

* the sidebar's selection bar — a 3px accent pill on the selected row,
* a control's own on-state (toggle fill, slider progress, stat accent),
* nothing else.

Nav rows specifically: no outline, no shadow, no gradient. Resting is the rail's
surface, hover is a subtle fill, selection is the elements-area fill plus the
accent bar.

## 6. Reading measure

Prose stops widening at `tokens.measure.prose` (468px ≈ 65 characters at body
size) via a `UISizeConstraint`. A wider window adds words to a line, never
characters — which is also what stops the old one-line-box truncation
("Astra…") from coming back.

## Checking a change

```sh
sh scripts/check_all.sh          # static gates + every runtime test
sh scripts/page_header_test.sh   # the flat composition rules above
sh scripts/sidebar_tab_sizing_test.sh
sh scripts/surface_hierarchy_test.sh
```
