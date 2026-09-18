# Astra Website

This folder is the Next.js docs site. The Luau library lives outside it and is never part of the web build.

## How Vercel deploys (no dashboard setup required)

Root `vercel.json` builds this folder from the **repo root**:

```json
{
  "installCommand": "cd website && npm ci",
  "buildCommand": "cd website && npm run build",
  "outputDirectory": "website/out"
}
```

`next.config.mjs` uses `output: "export"` so the build emits static HTML into `website/out/`. That works whether or not Dashboard → Root Directory is set.

Optional (slightly faster uploads): Dashboard → Settings → General → Root Directory → `website`. Then `website/vercel.json` takes over (`outputDirectory: "out"`).

`ignoreCommand` skips redeploys when only Luau/library files change.

## This scaffold — Next.js (recommended for Vercel)

This is a minimal Next.js 15 + Tailwind site (App Router). Replace `app/page.tsx` with your real design.

```bash
cd website
npm install
npm run dev    # http://localhost:3000
npm run build  # production build
```

### Structure

```
website/
  app/
    layout.tsx   # metadata + globals
    page.tsx     # landing page (replace with your design)
    globals.css  # tailwind directives
  vercel.json    # ignoreCommand for monorepo
  package.json   # next, react, tailwind
  tailwind.config.ts
  next.config.mjs
```

### If you prefer Vite or Astro

You can replace this scaffold. Examples (run inside `website/`):

```bash
# Vite
rm -rf app package.json && npm create vite@latest . -- --template react-ts
# then update website/vercel.json:
# { "ignoreCommand": "git diff --quiet HEAD^ HEAD -- ./", "buildCommand": "npm run build", "outputDirectory": "dist", "framework": "vite" }

# Astro
rm -rf app package.json && npm create astro@latest . -- --template minimal
```

For Next.js you don't need `buildCommand`/`outputDirectory` — Vercel auto-detects it.

## Monorepo layout reminder

```
/website/          <- Vercel Root Directory (this Next.js app)
  app/  package.json  vercel.json
/components/       <- Luau library (ignored via Root Directory)
/elements/
version-1.luau
skills/
```

Edits to Luau files won't trigger a website deploy when ignoreCommand is active.

## Alternatives already configured

- **Option 2: `.vercelignore` at repo root** — if you deploy from root *without* Root Directory, it excludes `components/`, `elements/`, `*.luau`, etc. and keeps `!website/`. You don't need it when using Root Directory, but it's kept as safety net.

- **Option 3: `vercel.json` build config from root** — e.g. `{ "buildCommand": "cd website && npm run build", "outputDirectory": "website/dist" }`. Prefer Root Directory instead; only use this if you must deploy from repo root.
