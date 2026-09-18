import type { MetadataRoute } from "next";

// This site is a plain static export — the manifest is the same for everyone.
export const dynamic = "force-static";

// Deployed under /astra-version-1 on GitHub Pages; the Pages workflow sets
// NEXT_PUBLIC_BASE_PATH before building (see next.config.mjs).
const basePath = process.env.NEXT_PUBLIC_BASE_PATH || "";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "Astra v1 — Luau interface library for Roblox",
    short_name: "Astra v1",
    description:
      "Usage guide, reference and live window preview for the Astra Luau UI library.",
    id: `${basePath}/`,
    start_url: `${basePath}/`,
    scope: `${basePath}/`,
    display: "standalone",
    background_color: "#0A0913",
    theme_color: "#0A0913",
    icons: [
      {
        src: `${basePath}/icons/icon-192.png`,
        sizes: "192x192",
        type: "image/png",
      },
      {
        src: `${basePath}/icons/icon-512.png`,
        sizes: "512x512",
        type: "image/png",
      },
    ],
  };
}
