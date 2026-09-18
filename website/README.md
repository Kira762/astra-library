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
| Device support | `app/manifest.ts`, `app/apple-icon.png`, `app/icon.png`, `scripts/render-icons.py` | Installable on phones and desktops (web manifest + touch icons). Touch-friendly targets, scroll-locked drawers with focus traps, dvh-aware sticky panes and no-zoom form fields. |

Icons are rasterised from the header mark by `scripts/render-icons.py`
(pure standard library, no image tooling) — rerun it after changing the mark.

Adding a page means adding it to `NAV` in `lib/docs.ts` and creating the route —
it then appears in the sidebar, the search dialog, the pager and the sitemap.

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
