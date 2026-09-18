"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useRef, useState } from "react";
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

    /* A theme flip rewrites colour, border and shadow on nearly every element
       at once. With transitions live they all fire together and the page
       cross-fades into the new palette instead of snapping to it; `.theme-swap`
       mutes them for the frame the swap is painted in. */
    root.classList.add("theme-swap");
    root.classList.toggle("dark", nextDark);
    root.classList.toggle("light", !nextDark);
    void root.offsetHeight; // force a reflow so the swap paints untransitioned
    window.requestAnimationFrame(() =>
      window.requestAnimationFrame(() => root.classList.remove("theme-swap")),
    );

    try {
      window.localStorage.setItem("astra-theme", nextDark ? "dark" : "light");
    } catch {
      /* storage may be unavailable — the toggle still works for this page view */
    }
    // On a phone the browser draws its own chrome around the page: keep the
    // status bar / address bar in step with the theme the reader picked.
    document
      .querySelector('meta[name="theme-color"]')
      ?.setAttribute("content", nextDark ? "#0A0913" : "#FBFAFF");
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
  const menuRef = useRef<HTMLDivElement>(null);
  const toggleRef = useRef<HTMLButtonElement>(null);

  useEffect(() => setMenuOpen(false), [pathname]);

  // Dismiss the phone menu the three ways people expect: Escape, a tap
  // outside it, or picking a link (handled by the pathname effect above).
  useEffect(() => {
    if (!menuOpen) return;
    function onKey(event: KeyboardEvent) {
      if (event.key !== "Escape") return;
      setMenuOpen(false);
      toggleRef.current?.focus();
    }
    function onPointerDown(event: PointerEvent) {
      const target = event.target as Node;
      if (menuRef.current?.contains(target) || toggleRef.current?.contains(target)) return;
      setMenuOpen(false);
    }
    window.addEventListener("keydown", onKey);
    document.addEventListener("pointerdown", onPointerDown);
    return () => {
      window.removeEventListener("keydown", onKey);
      document.removeEventListener("pointerdown", onPointerDown);
    };
  }, [menuOpen]);

  return (
    <header className="sticky top-0 z-50 border-b border-line bg-base/80 backdrop-blur-md print:hidden">
      <div className="mx-auto flex h-16 max-w-shell items-center gap-2 px-3 sm:px-4 lg:gap-3 lg:px-6">
        <Link
          href="/"
          className="flex min-w-0 items-center gap-2.5"
          aria-label="Astra v1 — home"
        >
          <AstraMark />
          <span className="flex items-baseline gap-1.5">
            <span className="font-display text-[0.95rem] font-semibold tracking-tight">Astra</span>
            {/* The version chip is decoration; below 360px the logo needs the room. */}
            <span className="hidden rounded-full border border-line px-1.5 py-px text-2xs leading-none text-subtle min-[360px]:inline">
              v1
            </span>
          </span>
        </Link>

        {/* Full navigation from 1024px up. Between a phone and that width a
            hamburger is more honest than five links squeezed into a row. */}
        <nav aria-label="Sections" className="ml-4 hidden items-center gap-1 lg:flex">
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

        <div className="ml-auto flex shrink-0 items-center gap-1 sm:gap-2">
          <SearchDialog />
          <ThemeToggle />
          <a
            href={REPO_URL}
            target="_blank"
            rel="noreferrer"
            className="icon-btn hidden lg:inline-flex"
            aria-label="Astra on GitHub"
          >
            <Icon name="github" className="h-4 w-4" />
          </a>
          <button
            ref={toggleRef}
            type="button"
            onClick={() => setMenuOpen((open) => !open)}
            className="icon-btn lg:hidden"
            aria-expanded={menuOpen}
            aria-controls="site-menu"
            aria-label={menuOpen ? "Close menu" : "Open menu"}
          >
            <Icon name={menuOpen ? "close" : "menu"} className="h-4 w-4" />
          </button>
        </div>
      </div>

      {menuOpen ? (
        <div
          ref={menuRef}
          className="sticky-scroll overflow-y-auto overscroll-contain border-t border-line bg-base px-3 py-3 sm:px-4 lg:hidden"
        >
          <nav id="site-menu" aria-label="Sections">
            <ul className="grid gap-1">
              {LINKS.map((link) => {
                const current = pathname === link.href || pathname.startsWith(`${link.href}/`);
                return (
                  <li key={link.href}>
                    <Link
                      href={link.href}
                      aria-current={current ? "page" : undefined}
                      className={`block rounded-lg px-3 py-2.5 text-sm transition-colors ${
                        current ? "bg-raised text-ink" : "text-muted hover:bg-raised hover:text-ink"
                      }`}
                    >
                      {link.label}
                    </Link>
                  </li>
                );
              })}
              <li>
                <a
                  href={REPO_URL}
                  target="_blank"
                  rel="noreferrer"
                  className="block rounded-lg px-3 py-2.5 text-sm text-muted hover:bg-raised hover:text-ink"
                >
                  GitHub
                </a>
              </li>
            </ul>
          </nav>
        </div>
      ) : null}

      {/* Breadcrumb bar on narrow screens: the docs sidebar is a drawer there. */}
      {isDocs ? <span className="sr-only">Documentation</span> : null}
    </header>
  );
}
