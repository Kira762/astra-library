# Astra Website

The Next.js docs site, published to **GitHub Pages** at
<https://kira762.github.io/astra-version-1/>.

The Luau library lives at the repository root and is never part of the web build.

## What the site is

A multi-page documentation site rather than one long page:

| Piece | Where | Notes |
|---|---|---|
| Landing page with a live window preview | `app/page.tsx`, `components/window-preview.tsx` | The preview is a real, interactive HTML rebuild of an Astra window; the theme chips use the ten built-in themes' actual accent colours. |
| Documentation, grouped in the sidebar | `app/docs/**` | Get started, Building an interface, Behaviour, Reference. |
| The documentation map | `lib/docs.ts` | One tree drives the sidebar, breadcrumbs, search index, prev/next pager and `sitemap.xml`. |
| Search | `components/search-dialog.tsx` | ⌘K / Ctrl+K or `/`, filtering a static index of every page and heading. |
| Content primitives | `components/content.tsx` | Page headers, anchored headings, callouts, card grids, prop/type tables. |
| Code blocks | `components/code-block.tsx` | Copy button plus tabbed variants (for example Executor vs Studio). |
| Design tokens | `app/globals.css`, `tailwind.config.ts` | Dark and light palettes as CSS channel variables; self-hosted typefaces. |
| SEO | `app/layout.tsx`, `lib/docs.ts`, `app/sitemap.ts`, `app/robots.ts` | Per-page metadata and Open Graph, canonical URLs, sitemap and robots. |

Adding a page means adding it to `NAV` in `lib/docs.ts` and creating the route —
it then appears in the sidebar, the search dialog, the pager and the sitemap.

## Device support

The site is a plain responsive layout with no browser sniffing and no
device-specific build: one HTML/CSS/JS bundle serves every screen. What each
kind of device gets:

| Device / input | Behaviour |
|---|---|
| Phone (280–430px) | Single column everywhere. The header collapses to a hamburger menu, the docs sidebar becomes a full-height drawer, and tables and code blocks scroll inside their own box instead of widening the page. The live window preview keeps a 52px icon rail so the mock stays usable at 320px. |
| Tablet (640–1023px) | Two-column card grids, full-width content column, hamburger still in the header — five nav links plus a search field do not fit honestly at 768px. |
| Laptop / desktop (1024px+) | Sticky docs sidebar, top navigation, hover reveals for heading anchors, keyboard search (⌘K / Ctrl+K) with a focus trap inside the dialog. |
| Wide screens (1280px+) | "On this page" table of contents appears; the shell caps at 1500px so line length stays readable, and widens to 1680px past 1800px so a 4K monitor is not mostly margin. |
| Touch input | `@media (pointer: coarse)` raises buttons to 44px, navigation rows and footer links to 44px and slider thumbs to 20px; dropdowns, the drawer, the search dialog and the preview dismiss on outside **taps** (pointer events, not just `mousedown`). Nothing is hover-only. |
| Keyboard / switch access | Visible focus rings, a skip link, `aria-modal` overlays that trap Tab, Escape closes every overlay, tables are focusable scroll regions. |
| Reduced motion | `prefers-reduced-motion: reduce` removes transitions and smooth scrolling. |
| High-contrast / forced colours | `@media (forced-colors: active)` restores borders, the slider thumb and the heading anchors, which the system palette would otherwise flatten. |
| Printer / PDF | `@media print` swaps in the light palette, drops the sticky chrome (`print:hidden`), wraps long code lines instead of clipping them and keeps code blocks and table rows from splitting across pages. |
| Zoom / large text | Layout is in `rem` with a `device-width` viewport that never caps `maximum-scale`, so pinch-zoom and browser text scaling both work. Number-like text is not auto-linked to the dialler (`formatDetection` is off). |
| Notched phones / dynamic toolbars | `viewportFit: "cover"` plus `env(safe-area-inset-*)` keep the body, the drawer, the search dialog and the footer clear of the notch in landscape; sticky panes size themselves against `100dvh` (with a `100vh` fallback) so mobile browser chrome never cuts them off. |

Two things worth knowing when changing the site:

- **iOS zooms into inputs smaller than 16px.** The search field is `text-base`
  under `sm:` and `text-sm` above it — keep that if you touch it.
- **The preview's slider is styled in `app/globals.css`** (`.range`), not with
  Tailwind utilities: `appearance: none` alone removes the thumb in WebKit, so
  the track, the thumb and the touch hit area are defined for Blink, WebKit
  and Gecko there.

### Guarding device support

The guarantees above live in one stylesheet, one `viewport` export and a few
hand-written classes, so a single edit can undo one of them without the build
noticing. `scripts/check-device-support.mjs` reads the export back and fails if
a guarantee is gone — the viewport meta, the safe-area padding, `100dvh`, the
coarse-pointer block, the print and forced-colours styles, the horizontal
scrollers, and four source rules (every `<table>` in a scroller, no
`w-screen`/`100vw`, no stray `whitespace-nowrap`, no `overflow-x: hidden` on
the root, which would break every sticky pane):

```bash
npm run build          # writes out/
npm run check:devices  # 22 checks over out/ and the source that owns them
```

The Pages workflow runs the same script between the build and the upload, so a
regression is caught before it reaches a phone.

## One-time setup (repo owner)

GitHub Pages must be pointed at Actions once — the workflow cannot always flip it
by itself:

1. Open <https://github.com/Kira762/astra-version-1/settings/pages>
2. **Build and deployment → Source:** `GitHub Actions`

Nothing else to configure: no `CNAME`, no `gh-pages` branch, no build command.

## How it deploys

`.github/workflows/deploy-pages.yml` runs on every push to `main` that touches
`website/**` (and on demand via **Actions → Deploy website to GitHub Pages →
Run workflow**):

```
checkout → configure-pages → npm ci → npm run build → upload website/out → deploy
```

`next.config.mjs` sets `output: "export"`, so the build writes plain static HTML
to `website/out/`. The workflow exports `NEXT_PUBLIC_BASE_PATH` (taken from
`configure-pages`, falling back to the repo name) because a project site is served
from a sub-path — without it every `/_next/...` asset URL would 404.

Because the export writes a folder per route (`trailingSlash: true`), deep links
such as `/docs/elements/toggle/` work on Pages without any rewrite rules, and
`404.html` catches anything else.

## Local development

```bash
cd website
npm install
npm run dev     # http://localhost:3000
npm run build   # static export → website/out/
```

To reproduce the exact Pages build (assets under `/astra-version-1`) from the repo
root:

```bash
npm run build:pages     # = NEXT_PUBLIC_BASE_PATH=/astra-version-1 npm run build --prefix website
npx serve website/out   # or any static server
```

`website/out/` and `website/node_modules/` are git-ignored — GitHub Actions
rebuilds them on every deploy, so no build output is committed.

## Typefaces

Three variable faces are self-hosted through `@fontsource-variable` packages
(Archivo for display, Instrument Sans for body copy, JetBrains Mono for code), so
the build needs no network access to a font CDN — which also means the Pages
build cannot fail because a font host is unreachable.

## Structure

```
website/
  app/
    layout.tsx        # metadata, theme script, header/footer shell
    page.tsx          # landing page + live window preview
    globals.css       # design tokens, base styles, content primitives
    icon.svg          # favicon
    not-found.tsx     # 404 (exported as 404.html)
    robots.ts         # /robots.txt
    sitemap.ts        # /sitemap.xml
    docs/             # one route per documentation page
  components/         # header, nav, search, code blocks, content primitives, preview
  lib/docs.ts         # the documentation map (nav, TOC, search, metadata helper)
  next.config.mjs     # output: export, trailingSlash, basePath from env
  tailwind.config.ts  # tokens mapped onto the CSS variables
```

## Monorepo layout

```
/website/            <- this Next.js app (the only thing Pages publishes)
/components/         <- Luau window shell
/elements/           <- Luau elements
/core/ /settings/ …  <- Luau runtime
version-1.luau       <- generated bundle
skills/              <- agent skill
```

Because Pages only ever receives `website/out/`, edits to Luau files cannot affect
the site — and the path filter in the workflow means they do not even trigger a
redeploy.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `deploy` job fails: `Failed to create deployment (status: 404)` | Pages source is not `GitHub Actions` yet — see **One-time setup**. |
| `Resource not accessible by integration` on *Setup Pages* | The workflow token cannot enable Pages. Harmless (the step is `continue-on-error`); enable it by hand once. |
| Page loads but CSS/JS 404 | Built without `NEXT_PUBLIC_BASE_PATH`. Use the workflow (or `npm run build:pages`) — never a plain `npm run build` for Pages. |
| Site unchanged after a push | The path filter only watches `website/**`; use **Run workflow** for a manual redeploy. |
| A new page 404s on Pages | The route exists but the build was made before the folder was added, or the build failed — check the workflow log. |
