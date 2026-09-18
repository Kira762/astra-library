"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useMemo, useRef, useState } from "react";
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
    <nav aria-label="Documentation" className="grid gap-6">
      {NAV.map((group) => (
        <div key={group.label}>
          <p className="px-3 pb-1.5 font-display text-xs font-semibold text-subtle">{group.label}</p>
          <ul className="grid gap-0.5 border-l border-line pl-0">
            {group.pages.map((page) => {
              const current = pathname === page.href;
              return (
                <li key={page.href}>
                  <Link
                    href={page.href}
                    onClick={onNavigate}
                    aria-current={current ? "page" : undefined}
                    className={`-ml-px block border-l py-2 pl-3 pr-2 text-sm transition-colors lg:py-1.5 ${
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

      <div>
        <p className="px-3 pb-1.5 font-display text-xs font-semibold text-subtle">Source files</p>
        <ul className="grid gap-0.5">
          {SIDEBAR_LINKS.map((link) => (
            <li key={link.href}>
              <a
                href={link.href}
                target="_blank"
                rel="noreferrer"
                className="flex items-center gap-1.5 px-3 py-1.5 text-sm text-muted transition-colors hover:text-ink"
              >
                {link.label}
                <Icon name="external" className="h-3 w-3 text-subtle" />
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
  const closeButtonRef = useRef<HTMLButtonElement>(null);
  const triggerButtonRef = useRef<HTMLButtonElement>(null);
  const drawerRef = useRef<HTMLDivElement>(null);

  useEffect(() => setOpen(false), [pathname]);

  // While the drawer is up: Escape closes it, the page behind it cannot
  // scroll, focus moves to the close button (and back when it closes), and
  // Tab cycles inside the panel instead of reaching the page behind it.
  useEffect(() => {
    if (!open) return;
    closeButtonRef.current?.focus();
    function onKey(event: KeyboardEvent) {
      if (event.key === "Escape") {
        setOpen(false);
        return;
      }
      if (event.key !== "Tab" || !drawerRef.current) return;
      const focusable = drawerRef.current.querySelectorAll<HTMLElement>(
        'a[href], button:not([disabled])',
      );
      if (focusable.length === 0) return;
      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    }
    const previous = document.documentElement.style.overflow;
    document.documentElement.style.overflow = "hidden";
    window.addEventListener("keydown", onKey);
    return () => {
      document.documentElement.style.overflow = previous;
      window.removeEventListener("keydown", onKey);
      triggerButtonRef.current?.focus();
    };
  }, [open]);

  return (
    <>
      {/* Narrow screens: a sticky bar that opens the full nav as a drawer. */}
      <div className="sticky top-[calc(3.5rem+env(safe-area-inset-top,0px))] z-40 -mx-4 mb-2 border-b border-line bg-base/90 px-4 py-2 backdrop-blur lg:hidden">
        <button
          ref={triggerButtonRef}
          type="button"
          onClick={() => setOpen(true)}
          className="btn w-full justify-between"
          aria-expanded={open}
          aria-controls="docs-drawer"
        >
          <span className="flex items-center gap-2 truncate">
            <Icon name="menu" className="h-4 w-4 text-accent" />
            <span className="truncate">{page?.title ?? "Documentation"}</span>
          </span>
          <Icon name="chevron-down" className="h-4 w-4 text-subtle" />
        </button>
      </div>

      {open ? (
        <div className="fixed inset-0 z-[65] lg:hidden" role="dialog" aria-modal="true" aria-label="Documentation menu">
          <div
            className="fade-in absolute inset-0 bg-base/80 backdrop-blur-sm"
            onClick={() => setOpen(false)}
            aria-hidden
          />
          <div
            id="docs-drawer"
            ref={drawerRef}
            className="drawer-in absolute inset-y-0 left-0 w-[86%] max-w-sm overflow-y-auto overscroll-contain border-r border-line bg-base py-4 pl-[max(1rem,env(safe-area-inset-left,0px))] pr-4 pt-[max(1rem,env(safe-area-inset-top,0px))]"
          >
            <div className="mb-4 flex items-center justify-between">
              <span className="font-display text-sm font-semibold">Documentation</span>
              <button
                ref={closeButtonRef}
                type="button"
                onClick={() => setOpen(false)}
                className="icon-btn"
                aria-label="Close menu"
              >
                <Icon name="close" className="h-4 w-4" />
              </button>
            </div>
            <NavList onNavigate={() => setOpen(false)} />

            {/* Small screens lose the right-hand "on this page" rail, so the
                current page's sections join the drawer instead. */}
            {page && page.toc.length > 0 ? (
              <div className="mt-6 border-t border-line pt-4">
                <p className="px-3 pb-1.5 font-display text-xs font-semibold text-subtle">
                  On this page
                </p>
                <ul className="grid gap-0.5">
                  {page.toc.map((item) => (
                    <li key={item.id}>
                      <a
                        href={`#${item.id}`}
                        onClick={() => setOpen(false)}
                        className="block px-3 py-2 text-sm text-muted transition-colors hover:text-ink"
                      >
                        {item.label}
                      </a>
                    </li>
                  ))}
                </ul>
              </div>
            ) : null}
          </div>
        </div>
      ) : null}

      {/* Wide screens: the nav sits beside the article. */}
      <aside className="hidden w-[248px] shrink-0 lg:block">
        <div className="sticky-under-header sticky overflow-y-auto py-8 pr-4">
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
      <div className="sticky-under-header sticky overflow-y-auto py-8 pl-2">
        <p className="pb-2 font-display text-xs font-semibold text-subtle">On this page</p>
        <ul className="grid gap-0.5">
          {page.toc.map((item) => (
            <li key={item.id}>
              <a
                href={`#${item.id}`}
                aria-current={activeId === item.id ? "location" : undefined}
                className={`block py-1 pl-3 text-[0.8125rem] leading-5 transition-colors ${
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
    <nav aria-label="Pagination" className="mt-14 grid gap-3 border-t border-line pt-6 sm:grid-cols-2">
      {prev ? (
        <Link href={prev.href} className="card-link group">
          <span className="flex items-center gap-2 text-2xs text-subtle">
            <Icon name="arrow-left" className="h-3 w-3" /> Previous
          </span>
          <span className="mt-1 block font-display text-sm font-semibold group-hover:text-accent">
            {prev.title}
          </span>
        </Link>
      ) : (
        <span />
      )}
      {next ? (
        <Link href={next.href} className="card-link group text-right sm:col-start-2">
          <span className="flex items-center justify-end gap-2 text-2xs text-subtle">
            Next <Icon name="arrow-right" className="h-3 w-3" />
          </span>
          <span className="mt-1 block font-display text-sm font-semibold group-hover:text-accent">
            {next.title}
          </span>
        </Link>
      ) : null}
    </nav>
  );
}
