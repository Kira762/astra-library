import type { Metadata, Viewport } from "next";
import "./globals.css";
import { SiteHeader } from "@/components/site-header";
import { SiteFooter } from "@/components/site-footer";
import { SITE_URL } from "@/lib/docs";

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: {
    default: "Astra v1 — the Luau interface library for Roblox executor scripts",
    template: "%s · Astra v1",
  },
  description:
    "Astra builds Roblox interfaces in code: one loader line, a CreateWindow call, and tabs full of elements with saving, ten themes, seven icon packs and one motion service behind every animation.",
  applicationName: "Astra v1",
  authors: [{ name: "Kira762", url: "https://github.com/Kira762" }],
  alternates: { canonical: "/" },
  openGraph: {
    type: "website",
    url: SITE_URL,
    siteName: "Astra v1",
    title: "Astra v1 — a Roblox interface in one loader line",
    description:
      "Windows, tabs, eleven element types, auto-saving flags, ten themes and 13,715 icons. Usage guide, reference and live window preview.",
  },
  twitter: {
    card: "summary_large_image",
    title: "Astra v1 — a Roblox interface in one loader line",
    description:
      "Luau interface library for Roblox executor scripts: windows, elements, saving, themes and icon packs.",
  },
  robots: { index: true, follow: true },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  // Let the page extend under the status bar / notch; components pad
  // themselves with env(safe-area-inset-*) where content must stay clear.
  viewportFit: "cover",
  colorScheme: "dark light",
  themeColor: [
    { media: "(prefers-color-scheme: dark)", color: "#0A0913" },
    { media: "(prefers-color-scheme: light)", color: "#FBFAFF" },
  ],
};

/**
 * Applied before paint so the stored theme wins over the dark default and the
 * page never flashes the wrong palette.
 */
const THEME_SCRIPT = `(function(){try{var t=localStorage.getItem("astra-theme");var dark=t?t==="dark":true;var r=document.documentElement;r.classList.toggle("dark",dark);r.classList.toggle("light",!dark);}catch(e){}})();`;

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className="dark" suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: THEME_SCRIPT }} />
      </head>
      <body className="min-h-screen antialiased">
        <a href="#content" className="skip-link btn">
          Skip to content
        </a>
        <SiteHeader />
        {children}
        <SiteFooter />
      </body>
    </html>
  );
}
