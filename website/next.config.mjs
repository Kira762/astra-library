/** @type {import('next').NextConfig} */
// Deployed to GitHub Pages as a *project* site, i.e. under a sub-path:
//   https://kira762.github.io/astra-version-1/
// The Pages workflow (.github/workflows/deploy-pages.yml) sets
// NEXT_PUBLIC_BASE_PATH=/astra-version-1 before building, which makes every
// asset URL resolve under that sub-path.
// Local dev / `npm run build` without the variable builds for "/" as usual.
const basePath = process.env.NEXT_PUBLIC_BASE_PATH || "";

const nextConfig = {
  // Static HTML export → website/out/ (what GitHub Pages serves).
  // The site has no server features, so a plain export is correct.
  output: "export",
  images: {
    unoptimized: true,
  },
  // One folder per route (index.html inside) so Pages serves clean URLs
  // without any redirect/rewrite configuration.
  trailingSlash: true,
  basePath: basePath || undefined,
  assetPrefix: basePath || undefined,
};

export default nextConfig;
