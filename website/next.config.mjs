/** @type {import('next').NextConfig} */
// GitHub Pages project sites are served from a sub-path:
//   https://kira762.github.io/astra-version-1/
// so CI sets NEXT_PUBLIC_BASE_PATH=/astra-version-1 before building.
// Local dev (and Vercel, if ever used again) leave it unset.
const basePath = process.env.NEXT_PUBLIC_BASE_PATH || "";

const nextConfig = {
  // Static HTML export → website/out/
  // The site is fully static (no server features), so export is correct.
  output: "export",
  images: {
    unoptimized: true,
  },
  trailingSlash: true,
  basePath: basePath || undefined,
  assetPrefix: basePath || undefined,
};

export default nextConfig;
