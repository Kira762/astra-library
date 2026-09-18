import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Astra Usage Guide — Load, Build Windows, Elements, Themes, Icons",
  description:
    "Complete Astra v1 Luau usage guide: loader, CreateWindow, tabs, groups, every element (Button/Toggle/Slider/Dropdown/Input/Stat/Changelog), saving, themes, 7 icon packs, motion, localisation and startup performance. Monorepo-safe with Vercel Root Directory = website.",
  openGraph: {
    title: "Astra v1 — Usage Guide",
    description:
      "Load Astra with one line, build windows with tabs & elements, themes & 7 icon packs. Full usage docs for the Luau UI library.",
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
