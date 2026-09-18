/** @type {import('next').NextConfig} */
const nextConfig = {
  // Static HTML export so the monorepo can deploy from the repo root
  // without requiring Vercel Dashboard → Root Directory = website.
  // The site is fully static (no server features), so export is correct.
  output: "export",
  images: {
    unoptimized: true,
  },
  trailingSlash: true,
};

export default nextConfig;
