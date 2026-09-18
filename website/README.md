# Website

This folder is the Vercel deploy root. Everything outside it (`/components`, `/elements`, `*.luau`, `/skills`, etc.) is the Luau library and is automatically ignored by Vercel.

## Vercel Setup (do this once)

### 1. Set Root Directory (recommended)

Vercel Dashboard → Your Project → **Settings → General → Root Directory → `website`** → Save

Vercel will then only upload & build this folder. No extra config needed - the Luau source is outside the root so it's never deployed.

> The `vercel.json` in this folder contains `ignoreCommand` to skip builds when only library files changed outside `website/`.
> The root `vercel.json` and `.vercelignore` are fallbacks if you deploy from repo root without Root Directory.

### 2. Create your site in this folder

Pick a framework and scaffold inside `website/`:

```bash
# Next.js (recommended)
cd website
npx create-next-app@latest . --typescript --tailwind --eslint --app --no-src-dir --import-alias "@/*"

# or Vite
npm create vite@latest . -- --template react-ts

# or Astro
npm create astro@latest . -- --template minimal
```

Then `git add` and push - Vercel will build only `website/`.

### 3. Framework-specific `vercel.json` (optional)

If you need to customize build output, edit `website/vercel.json`. Example for Vite:

```json
{
  "ignoreCommand": "git diff --quiet HEAD^ HEAD -- ./",
  "buildCommand": "npm run build",
  "outputDirectory": "dist",
  "framework": "vite"
}
```

For Next.js you don't need `buildCommand`/`outputDirectory` - Vercel auto-detects it.

## How the ignore works

- **With Root Directory = `website`**: `website/vercel.json` → `git diff --quiet HEAD^ HEAD -- ./` skips the build if nothing in `website/` changed. Library changes (`components/`, `version-1.luau`, etc.) don't trigger a deploy.

- **Without Root Directory** (fallback): root `vercel.json` → `git diff --quiet HEAD^ HEAD -- ./website/` does the same, and root `.vercelignore` prevents Luau files from being uploaded.

## Structure

```
/website/          <- Vercel Root Directory (your site lives here)
  vercel.json      <- ignoreCommand for monorepo
  package.json     <- your site's deps
  next.config.js / vite.config.ts / astro.config.mjs
  src/ / app/ / pages/
/components/       <- Luau library (ignored by Vercel via Root Directory)
/elements/
version-1.luau
skills/
```
