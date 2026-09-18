# Astra Website

The Next.js docs site, published to **GitHub Pages** at
<https://kira762.github.io/astra-version-1/>.

The Luau library lives at the repository root and is never part of the web build.

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

## Local development

```bash
cd website
npm install
npm run dev     # http://localhost:3000  (no base path, like GitHub Actions dev previews)
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

## Structure

```
website/
  app/
    layout.tsx       # metadata + globals
    page.tsx         # the docs page (all sections, TOC anchors)
    globals.css      # tailwind directives
  public/
    .nojekyll        # keeps /_next/ intact if out/ is ever served from a branch
  next.config.mjs    # output: export, trailingSlash, basePath from env
  package.json       # next, react, tailwind
  tailwind.config.ts
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
| Blank 404 for deep links | Expected — the site is a single page plus `404.html`; anchors (`#icons`) are on that page. |
