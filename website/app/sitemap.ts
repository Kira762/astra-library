import type { MetadataRoute } from "next";

// Static export: both files are generated once at build time.
export const dynamic = "force-static";
import { ALL_PAGES, SITE_URL } from "@/lib/docs";

/**
 * Written at build time by the static export, so GitHub Pages serves a real
 * sitemap.xml next to the pages it lists.
 */
export default function sitemap(): MetadataRoute.Sitemap {
  const lastModified = new Date();
  return [
    {
      url: `${SITE_URL}/`,
      lastModified,
      changeFrequency: "weekly",
      priority: 1,
    },
    ...ALL_PAGES.map((page) => ({
      url: `${SITE_URL}${page.href}/`,
      lastModified,
      changeFrequency: "monthly" as const,
      priority: page.href === "/docs/getting-started" ? 0.9 : 0.7,
    })),
  ];
}
