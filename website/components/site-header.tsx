"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import { REPO_URL, normalizePath } from "@/lib/docs";
import { Icon } from "./icon";
import { SearchDialog } from "./search-dialog";

const LINKS = [
  { href: "/docs", label: "Docs" },
  { href: "/docs/elements", label: "Elements" },
  { href: "/docs/themes", label: "Themes" },
  { href: "/docs/icons", label: "Icons" },
  { href: "/docs/skill", label: "Agent skill" },
];

function AstraMark() {
  return (
    <span
      aria-hidden
      className="grid h-8 w-8 place-items-center rounded-[10px] border border-accent/40 bg-accent/15 text-accent"
    >
      <svg viewBox="0 0 24 24" className="h-4 w-4" fill="currentColor" aria-hidden>
        <path d="M12 2.6l2.05 6.6 6.6 2.05-6.6 2.05L12 19.9l-2.05-6.6L3.35 11.25l6.6-2.05L12 2.6z" />
        <circle cx="19" cy="18.4" r="1.5" opacity="0.65" />
      </svg>
    </span>
  );
}

function ThemeToggle() {
  const [ready, setReady] = useState(false);

  useEffect(() => setReady(true), []);

  function toggle() {
    const root = document.documentElement;
    const nextDark = !root.classList.contains("dark");
    root.classList.toggle("dark", nextDark);
    root.classList.toggle("light", !nextDark);
    try {
      window.localStorage.setItem("astra-theme", nextDark ? "dark" : "light");
    } catch {
      /* storage may be unavailable — the toggle still works for this page view */
    }
  }

  return (
    <button type="button" onClick={toggle} className="icon-btn" aria-label="Switch colour theme">
      {/* Both glyphs ship in the markup; the active theme decides which one shows. */}
      <Icon name="moon" className={`h-4 w-4 ${ready ? "hidden dark:block" : ""}`} />
      <Icon name="sun" className={`h-4 w-4 ${ready ? "block dark:hidden" : "hidden"}`} />
    </button>
  );
}

export function SiteHeader() {
  const pathname = normalizePath(usePathname() ?? "/");
  const [menuOpen, setMenuOpen] = useState(false);
  const isDocs = pathname.startsWith("/docs");

  useEffect(() => setMenuOpen(false), [pathname]);

  return (
    <header className="sticky top-0 z-50 border-b border-line bg-base/85 backdrop-blur-md">
      <div className="mx-auto flex h-14 max-w-shell items-center gap-3 px-4 lg:px-6">
        <Link href="/" className="flex items-center gap-2.5" aria-label="Astra v1 — home">
          <AstraMark />
          <span className="flex items-baseline gap-1.5">
            <span className="font-display text-[0.95rem] font-semibold tracking-tight">Astra</span>
            <span className="rounded-full border border-line px-1.5 py-px text-2xs text-subtle">v1</span>
          </span>
        </Link>

        <nav aria-label="Sections" className="ml-4 hidden items-center gap-1 md:flex">
          {LINKS.map((link) => {
            const current = pathname === link.href || pathname.startsWith(`${link.href}/`);
            return (
              <Link
                key={link.href}
                href={link.href}
                aria-current={current ? "page" : undefined}
                className={`rounded-lg px-2.5 py-1.5 text-sm transition-colors ${
                  current ? "bg-raised text-ink" : "text-muted hover:bg-raised/60 hover:text-ink"
                }`}
              >
                {link.label}
              </Link>
            );
          })}
        </nav>

        <div className="ml-auto flex items-center gap-2">
          <SearchDialog />
          <ThemeToggle />
          <a
            href={REPO_URL}
            target="_blank"
            rel="noreferrer"
            className="icon-btn hidden sm:inline-flex"
            aria-label="Astra on GitHub"
          >
            <Icon name="github" className="h-4 w-4" />
          </a>
          <button
            type="button"
            onClick={() => setMenuOpen((open) => !open)}
            className="icon-btn md:hidden"
            aria-expanded={menuOpen}
            aria-controls="site-menu"
            aria-label={menuOpen ? "Close menu" : "Open menu"}
          >
            <Icon name={menuOpen ? "close" : "menu"} className="h-4 w-4" />
          </button>
        </div>
      </div>

      {menuOpen ? (
        <nav
          id="site-menu"
          aria-label="Sections"
          className="border-t border-line bg-base px-4 py-3 md:hidden"
        >
          <ul className="grid gap-1">
            {LINKS.map((link) => (
              <li key={link.href}>
                <Link
                  href={link.href}
                  className="block rounded-lg px-3 py-2 text-sm text-muted hover:bg-raised hover:text-ink"
                >
                  {link.label}
                </Link>
              </li>
            ))}
            <li>
              <a
                href={REPO_URL}
                target="_blank"
                rel="noreferrer"
                className="block rounded-lg px-3 py-2 text-sm text-muted hover:bg-raised hover:text-ink"
              >
                GitHub
              </a>
            </li>
          </ul>
        </nav>
      ) : null}

      {/* Breadcrumb bar on narrow screens: the docs sidebar is a drawer there. */}
      {isDocs ? <span className="sr-only">Documentation</span> : null}
    </header>
  );
}
