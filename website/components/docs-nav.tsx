"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import {
  NAV,
  SIDEBAR_LINKS,
  findPage,
  neighbours,
  normalizePath,
} from "@/lib/docs";
import { Icon } from "./icon";

function NavList({ onNavigate }: { onNavigate?: () => void }) {
  const pathname = normalizePath(usePathname() ?? "/");

  return (
    <nav aria-label="Documentation" className="grid min-w-0 gap-6">
      {NAV.map((group) => (
        <div key={group.label} className="min-w-0">
          <p className="px-3 pb-1.5 font-display text-xs font-semibold text-subtle">{group.label}</p>
          <ul className="grid min-w-0 gap-0.5 border-l border-line pl-0">
            {group.pages.map((page) => {
              const current = pathname === page.href;
              return (
                <li key={page.href} className="min-w-0">
                  <Link
                    href={page.href}
                    onClick={onNavigate}
                    aria-current={current ? "page" : undefined}
                    className={`-ml-px block min-w-0 truncate border-l py-2 pl-3 pr-2 text-sm transition-colors sm:py-1.5 ${
                      current
                        ? "border-accent font-medium text-accent"
                        : "border-transparent text-muted hover:border-line-strong hover:text-ink"
                    }`}
                  >
                    {page.title}
                  </Link>
                </li>
              );
            })}
          </ul>
        </div>
      ))}

      <div className="min-w-0">
        <p className="px-3 pb-1.5 font-display text-xs font-semibold text-subtle">Source files</p>
        <ul className="grid min-w-0 gap-0.5">
          {SIDEBAR_LINKS.map((link) => (
            <li key={link.href} className="min-w-0">
              <a
                href={link.href}
                target="_blank"
                rel="noreferrer"
                className="flex min-w-0 items-center gap-1.5 px-3 py-2 text-sm text-muted transition-colors hover:text-ink sm:py-1.5"
              >
                <span className="min-w-0 truncate">{link.label}</span>
                <Icon name="external" className="h-3 w-3 shrink-0 text-subtle" />
              </a>
            </li>
          ))}
        </ul>
      </div>
    </nav>
  );
}

export function DocsSidebar() {
  const pathname = normalizePath(usePathname() ?? "/");
  const [open, setOpen] = useState(false);
  const page = findPage(pathname);

  useEffect(() => setOpen(false), [pathname]);

  useEffect(() => {
    if (!open) return;
    function onKey(event: KeyboardEvent) {
      if (event.key === "Escape") setOpen(false);
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open]);

  // Prevent body scroll when drawer open
  useEffect(() => {
    if (!open) return;
    const prev = document.documentElement.style.overflow;
    document.documentElement.style.overflow = "hidden";
    return () => {
      document.documentElement.style.overflow = prev;
    };
  }, [open]);

  return (
    <>
      {/* Narrow screens: a sticky bar that opens the full nav as a drawer. */}
      <div className="sticky top-14 z-40 -mx-4 mb-2 w-[calc(100%+2rem)] border-b border-line bg-base/95 px-4 py-2 backdrop-blur-md sm:w-[calc(100%+2rem)] lg:hidden">
        <button
          type="button"
          onClick={() => setOpen(true)}
          className="btn w-full min-w-0 justify-between"
          aria-expanded={open}
          aria-controls="docs-drawer"
        >
          <span className="flex min-w-0 items-center gap-2 truncate">
            <Icon name="menu" className="h-4 w-4 shrink-0 text-accent" />
            <span className="min-w-0 truncate">{page?.title ?? "Documentation"}</span>
          </span>
          <Icon name="chevron-down" className="h-4 w-4 shrink-0 text-subtle" />
        </button>
      </div>

      {open ? (
        <div className="fixed inset-0 z-[65] w-full max-w-[100vw] overflow-hidden lg:hidden" role="dialog" aria-modal="true" aria-label="Documentation menu">
          <div
            className="absolute inset-0 bg-base/80 backdrop-blur-sm"
            onClick={() => setOpen(false)}
            aria-hidden
          />
          <div
            id="docs-drawer"
            className="absolute inset-y-0 left-0 w-[86%] max-w-[min(20rem,calc(100vw-2rem))] overflow-y-auto overflow-x-hidden overscroll-contain border-r border-line bg-base px-4 py-4"
          >
            <div className="mb-4 flex items-center justify-between gap-2">
              <span className="font-display text-sm font-semibold">Documentation</span>
              <button type="button" onClick={() => setOpen(false)} className="icon-btn" aria-label="Close menu">
                <Icon name="close" className="h-4 w-4" />
              </button>
            </div>
            <NavList onNavigate={() => setOpen(false)} />
          </div>
        </div>
      ) : null}

      {/* Wide screens: the nav sits beside the article. */}
      <aside className="hidden w-[248px] shrink-0 lg:block">
        <div className="sticky top-14 max-h-[calc(100vh-3.5rem)] overflow-y-auto overflow-x-hidden py-8 pr-4">
          <NavList />
        </div>
      </aside>
    </>
  );
}

/** Right-hand "on this page" list, highlighted as the reader scrolls. */
export function DocsToc() {
  const pathname = normalizePath(usePathname() ?? "/");
  const page = findPage(pathname);
  const ids = useMemo(() => page?.toc.map((item) => item.id) ?? [], [page]);
  const [activeId, setActiveId] = useState<string | null>(null);

  useEffect(() => {
    if (ids.length === 0) return;
    const headings = ids
      .map((id) => document.getElementById(id))
      .filter((element): element is HTMLElement => Boolean(element));
    if (headings.length === 0) return;

    const visible = new Map<string, boolean>();
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => visible.set(entry.target.id, entry.isIntersecting));
        const first = ids.find((id) => visible.get(id));
        if (first) {
          setActiveId(first);
        } else {
          // Nothing in the band: fall back to the last heading above the fold.
          const passed = headings.filter((element) => element.getBoundingClientRect().top < 96).pop();
          setActiveId(passed?.id ?? null);
        }
      },
      { rootMargin: "-88px 0px -62% 0px", threshold: [0, 1] },
    );

    headings.forEach((heading) => observer.observe(heading));
    return () => observer.disconnect();
  }, [ids]);

  if (!page || page.toc.length === 0) return null;

  return (
    <aside className="hidden w-[200px] shrink-0 xl:block">
      <div className="sticky top-14 max-h-[calc(100vh-3.5rem)] overflow-y-auto overflow-x-hidden py-8 pl-2">
        <p className="pb-2 font-display text-xs font-semibold text-subtle">On this page</p>
        <ul className="grid min-w-0 gap-0.5">
          {page.toc.map((item) => (
            <li key={item.id} className="min-w-0">
              <a
                href={`#${item.id}`}
                aria-current={activeId === item.id ? "location" : undefined}
                className={`block min-w-0 truncate py-1.5 pl-3 text-[0.8125rem] leading-5 transition-colors ${
                  activeId === item.id
                    ? "border-l border-accent text-accent"
                    : "border-l border-transparent text-subtle hover:text-ink"
                }`}
              >
                {item.label}
              </a>
            </li>
          ))}
        </ul>
      </div>
    </aside>
  );
}

/** Previous / next page in reading order. */
export function DocsPager() {
  const pathname = normalizePath(usePathname() ?? "/");
  const { prev, next } = neighbours(pathname);
  if (!prev && !next) return null;

  return (
    <nav aria-label="Pagination" className="mt-14 grid min-w-0 gap-3 border-t border-line pt-6 sm:grid-cols-2">
      {prev ? (
        <Link href={prev.href} className="card-link group min-w-0">
          <span className="flex items-center gap-2 text-2xs text-subtle">
            <Icon name="arrow-left" className="h-3 w-3 shrink-0" /> Previous
          </span>
          <span className="mt-1 block min-w-0 truncate font-display text-sm font-semibold group-hover:text-accent">
            {prev.title}
          </span>
        </Link>
      ) : (
        <span className="hidden sm:block" />
      )}
      {next ? (
        <Link href={next.href} className="card-link group min-w-0 text-right sm:col-start-2">
          <span className="flex items-center justify-end gap-2 text-2xs text-subtle">
            Next <Icon name="arrow-right" className="h-3 w-3 shrink-0" />
          </span>
          <span className="mt-1 block min-w-0 truncate font-display text-sm font-semibold group-hover:text-accent">
            {next.title}
          </span>
        </Link>
      ) : null}
    </nav>
  );
}
