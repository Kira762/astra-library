import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Astra v1 — Roblox Luau UI Library",
  description:
    "A Roblox/Luau interface library for executor scripts: one loader line, one CreateWindow call, and tabs full of elements with built-in themes, icon packs and persistence.",
  openGraph: {
    title: "Astra v1 — Roblox Luau UI Library",
    description:
      "One loader line, one CreateWindow call. Buttons, toggles, sliders, dropdowns, themes, 7 icon packs and staged startup.",
    type: "website",
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className="dark">
      <body className="antialiased">{children}</body>
    </html>
  );
}
