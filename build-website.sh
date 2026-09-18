#!/usr/bin/env bash
# Build the Next.js docs site (static export → website/out).
# Used by root vercel.json so the monorepo deploys without Dashboard Root Directory.
set -euo pipefail
cd "$(dirname "$0")/website"
if [ -f package-lock.json ]; then
  npm ci
else
  npm install
fi
npm run build
test -f out/index.html
echo "OK: website/out/index.html ready"
