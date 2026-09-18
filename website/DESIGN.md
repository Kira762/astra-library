# Astra docs — design system

What the site's visual language is, why each value is what it is, and what was
changed in the polish pass. Everything here is implemented in
[`app/globals.css`](app/globals.css) and [`tailwind.config.ts`](tailwind.config.ts);
this file is the reference for keeping future work consistent with it.

Two rules govern everything else:

1. **One design system, no local overrides.** A page states intent
   (`class="card-link"`, `text-2xl`, `section`) and the system decides what that
   looks like. Nothing hard-codes a colour, a shadow or a duration.
2. **Motion answers an action.** Hover, press, focus and theme changes animate,
   because they respond to the reader. Nothing animates on its own as the page
   scrolls — a page where every section fades up is a page where none of them
   means anything.

---

## 1. Audit — what changed and why

Severity is per the review scale: **HIGH** makes content unreadable or
misleading, **MEDIUM** is a visible system failure, **LOW** is isolated polish.
Locations are `file · selector`.

| Severity | Location | Before | After | Why |
| --- | --- | --- | --- | --- |
| HIGH | `globals.css · .light --c-subtle` | 3.84:1 on the raised surface | 4.72:1 | Captions, table headers and footer meta failed WCAG AA (4.5:1) — the worst pair on the site. Lightness moved, hue held. |
| HIGH | `globals.css · .light --c-gold/-success/-warning/-info` | 3.33–4.23:1 on the page | 4.89–4.95:1 | Callout titles ("Tip", "Warning", "Note") and icon labels are real text at 13px, not decoration; all four missed AA. |
| HIGH | `globals.css · .dark --c-subtle` | 4.01:1 on raised | 4.71:1 | Same failure in the default theme, where most readers see the docs. |
| MEDIUM | `code-block.tsx` | every sample rendered as one flat `<code>` span | five-token Luau palette | The samples are the product; unhighlighted code made the page's most important content its least legible. |
| MEDIUM | `globals.css · .data-table` | a rule under every row, nothing else | zebra tint + hover / focus-within band, 13px header, 1rem cell padding | An eleven-row reference table read as a wall. Alternating tint and a tracking band are what make a column scannable. |
| MEDIUM | `tailwind.config.ts · fontSize` | sizes set per component, leading per component | one scale by role, unitless leading | `text-2xl` headings inherited 1.5 leading while the hero set `leading-[1.05]` by hand. Scale now tightens as it grows. |
| MEDIUM | `site-header.tsx · ThemeToggle` | theme flip cross-faded the entire page | `.theme-swap` mutes transitions for the frame the swap paints in | Every colour, border and shadow transition fired at once; the switch smeared. It now snaps. |
| MEDIUM | `tailwind.config.ts · maxWidth.prose` | 72ch | 65ch | 72 characters is past the comfortable measure and the eye loses the line return on a wide screen. |
| LOW | `globals.css · .btn`, `.icon-btn`, `.card-link` | 140ms `ease`, border colour only on hover | 200ms on the house curve, lift + ring on hover, `scale(0.98)` / `(0.96)` on press | Controls now feel like objects rather than coloured rectangles. |
| LOW | `globals.css · .starfield` | six dots, hard-edged section end | dots fade out by mask, one soft wash behind the hero | The decoration now belongs to the section instead of stopping at its edge. |
| LOW | `window-preview.tsx` | 11px labels, 1.7 stroke glyphs | 12px floor, 2px strokes, glass top edge | The hero's centrepiece is the one image people zoom into. |
| LOW | `globals.css · .code-frame` | `px-3 py-1.5` caption, no language chip | 44px chrome row, language chip, labelled copy button | Cramped chrome is the fastest way to make good code look cheap. |

### Verification

- **Measured.** Every text/background pair in both themes was computed from the
  declared token values, including the effective backgrounds: the `bg-surface/40`
  bands, the `surface/60` callouts, the `accent/15` chips, the zebra tint and the
  hover band. All pass 4.5:1, and the five-token syntax palette passes on the
  code surface in both themes (4.73:1 worst case, light-theme numbers).
- **Not verified in a browser.** No browser was available in the environment that
  produced this pass, so rendering, wrapping at real content lengths, and the
  feel of the motion were not inspected on screen. `npm run build` succeeds and
  the static export was checked for the expected markup.
- **Not verified.** Zoom to 200%, RTL mirroring, and Safari/Firefox rendering.

---

## 2. Colour

Channel triples (`R G B`) on the theme class, so any colour takes an opacity
modifier and one switching mechanism (`.dark` / `.light` on `<html>`) drives
every palette. Dark is the default because it is the theme the library ships in.

| Role | Dark | Light | Use |
| --- | --- | --- | --- |
| `--c-base` | `10 9 19` | `251 250 255` | The page. Never pure black or white. |
| `--c-surface` | `18 16 34` | `255 255 255` | Cards, code frames, panels. |
| `--c-raised` | `25 22 48` | `244 241 252` | Nested surfaces, hover, inline code. |
| `--c-line` / `--c-line-soft` / `--c-line-strong` | `38 32 70` / `29 25 53` / `53 45 92` | `228 223 245` / `236 232 249` / `205 197 236` | Structure: dividers, card edges, table rules. |
| `--c-ink` | `238 235 250` | `23 20 42` | Body-strong text, headings. |
| `--c-muted` | `163 157 196` | `89 82 125` | Body copy. |
| `--c-subtle` | `134 128 166` | `110 104 134` | Captions, table headers, meta. AA on `raised`. |
| `--c-accent` | `155 123 247` | `109 63 224` | Links, primary action, keywords. One meaning. |
| `--c-success` / `--c-warning` / `--c-danger` / `--c-info` / `--c-gold` | see `:root` | see `.light` | Status only, never as decoration. |

The syntax palette is a second, smaller scale: five tones for five jobs
(`keyword`, `string`, `number`, `function`, `comment`). It is separate from the
UI palette so a link colour and a keyword colour can move independently.

## 3. Type

Three typefaces, each with one job: **Archivo** for display and headings,
**Instrument Sans** for body and interface, **JetBrains Mono** for code,
identifiers and metadata. All self-hosted — no request leaves the page.

| Token | Size / leading | Role |
| --- | --- | --- |
| `text-2xs` | 12px / 1.0625rem | The floor. Keycaps, chips, metadata. |
| `text-xs` | 13px / 1.3125rem | Captions, table headers, tab labels. |
| `text-sm` | 14px / 1.5rem | Interface text: nav, cards, tables, buttons. |
| `text-base` | 16px / 1.65 | Long-form reading (`.prose-docs`). |
| `text-lg` … `text-6xl` | 1.125 → 3.5rem, leading 1.55 → 1.03 | Headings. Leading tightens as size grows. |

- Reading measure is `65ch` (`max-w-prose`, `.prose-docs`).
- Weight carries as much hierarchy as size: headings are 600, body 400, and
  `font-weight` never drops below 400 at text sizes.
- Numbers are `tabular-nums` in every table, stat and version list.
- Underlines come from the font's own metrics
  (`text-underline-position/decoration-thickness: from-font`).

## 4. Space and shape

- **Rhythm.** Landing sections share one class, `.section`: 56px → 72px → 96px
  of block padding as the viewport grows. A section's padding is the only thing
  separating it from its neighbour.
- **Grouping.** Within a group, 8–12px; between groups, 16–24px and never less
  than twice the inner gap.
- **Radius.** 16px for surfaces (`rounded-card`), 10px for controls
  (`rounded-control`), 8px inside them (`rounded-inner`). Nested radii are
  concentric where the inset is even.
- **Elevation.** A card is a 1px border plus `--shadow-card`: a hairline ring, a
  1px lift, and one long, low-opacity throw. Hover swaps to `--shadow-lift`
  (border to `line-strong`, 2px more throw, `translateY(-2px)`). No grey smears.
- **Borders vs shadows.** Borders carry structure — dividers, table cells, card
  edges. Shadows carry depth.

## 5. Motion

| Token | Value | Use |
| --- | --- | --- |
| `--ease-out` | `cubic-bezier(0.22, 1, 0.36, 1)` | The house curve. Hover, lift, colour. |
| `--ease-swift` | `cubic-bezier(0.2, 0, 0, 1)` | Symmetric swaps, state changes. |
| `--dur-fast` | 140ms | Press, focus, colour on a small element. |
| `--dur` | 200ms | Hover, lift, panel state. |

- Transition **named properties**, never `all`: a hover that animates a shadow
  should not also repaint the layout.
- Press states are `scale(0.98)` on buttons and `scale(0.96)` on icon buttons.
  Always those values.
- Focus is a 2px accent ring at 2px offset. Inside a clipped frame (code sample,
  scrolling table) the ring is drawn inside rather than being cut off.
- Theme switching mutes transitions for one frame via `.theme-swap`; otherwise
  the whole page cross-fades.
- `prefers-reduced-motion: reduce` collapses every transition and animation to
  an instant, in one place.

## 6. Component notes

**`.prose-docs`** — one measure, one leading, one link treatment for every docs
page. First paragraph is one step brighter and larger: it is the lead.

**`.code-frame`** — chrome row (language or variant tabs + copy), then the
sample. Colouring comes from `lib/highlight.ts`, a ~120-line Luau tokeniser, so
there is no highlighting dependency and no client-side work beyond the render.
Copy buttons show the word on pointer widths and stay icon-only on phones.

**`.data-table`** — a rule under every row, an alternating tint, a hover band,
and `focus-within` so keyboard readers see the row they are tabbing through.

**`.starfield`** — the brand moment, and the only decoration on the site. Stars
fade out by mask so the hero does not end on a hard line.

## 7. Adding something new

- Reach for a token first. If a role is missing, add the token — do not borrow
  a value that happens to look right today.
- Anything interactive is a `.btn`, `.icon-btn`, `.card-link` or `.code-tab`, so
  it inherits the hover, press and focus behaviour.
- If you change a text colour, re-measure it against the surface it actually
  renders on (including tints) rather than assuming.
- Add an entrance animation only if it answers something the reader did.
