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
import { useFocusTrap } from "@/lib/focus-trap";
import { lockScroll } from "@/lib/scroll-lock";
import { Icon } from "./icon";

function NavList({ onNavigate }: { onNavigate?: () => void }) {
  const pathname = normalizePath(usePathname() ?? "/");

  return (
    <nav aria-label="Documentation" className="docs-nav-list grid gap-6">
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
                    className={`-ml-px block border-l py-2 pl-3 pr-2 text-sm transition-colors ${
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
                className="flex items-center gap-1.5 px-3 py-2 text-sm text-muted transition-colors hover:text-ink"
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
  const triggerRef = useRef<HTMLButtonElement>(null);
  const closeRef = useRef<HTMLButtonElement>(null);
  const drawerRef = useRef<HTMLDivElement>(null);

  useFocusTrap(drawerRef, open);

  useEffect(() => setOpen(false), [pathname]);

  useEffect(() => {
    if (!open) return;
    function onKey(event: KeyboardEvent) {
      if (event.key !== "Escape") return;
      setOpen(false);
      // Send focus back to the control that opened the drawer.
      triggerRef.current?.focus();
    }
    window.addEventListener("keydown", onKey);
    // A phone must not scroll the article behind the drawer.
    const release = lockScroll();
    closeRef.current?.focus();
    return () => {
      window.removeEventListener("keydown", onKey);
      release();
    };
  }, [open]);

  function dismiss() {
    setOpen(false);
    triggerRef.current?.focus();
  }

  return (
    <>
      {/* Narrow screens: a sticky bar that opens the full nav as a drawer. */}
      <div className="sticky top-14 z-40 -mx-4 mb-2 border-b border-line bg-base/90 px-4 py-2 backdrop-blur lg:hidden print:hidden">
        <button
          ref={triggerRef}
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
            className="absolute inset-0 bg-base/80 backdrop-blur-sm"
            onClick={dismiss}
            aria-hidden
          />
          <div
            id="docs-drawer"
            ref={drawerRef}
            className="absolute inset-y-0 left-0 w-[92%] max-w-sm overflow-y-auto overscroll-contain border-r border-line bg-base py-4 pl-[max(1rem,env(safe-area-inset-left))] pr-4 pb-[max(1rem,env(safe-area-inset-bottom))] sm:w-[86%]"
          >
            <div className="mb-4 flex items-center justify-between">
              <span className="font-display text-sm font-semibold">Documentation</span>
              <button
                ref={closeRef}
                type="button"
                onClick={dismiss}
                className="icon-btn"
                aria-label="Close documentation menu"
              >
                <Icon name="close" className="h-4 w-4" />
              </button>
            </div>
            <NavList onNavigate={() => setOpen(false)} />
          </div>
        </div>
      ) : null}

      {/* Wide screens: the nav sits beside the article. */}
      <aside className="hidden w-[248px] shrink-0 print:hidden lg:block">
        <div className="sticky-scroll sticky top-14 overflow-y-auto py-8 pr-4">
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
    <aside className="hidden w-[200px] shrink-0 print:hidden xl:block">
      <div className="sticky-scroll sticky top-14 overflow-y-auto py-8 pl-2">
        <p className="pb-2 font-display text-xs font-semibold text-subtle">On this page</p>
        <ul className="docs-toc grid gap-0.5">
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
    <nav aria-label="Pagination" className="mt-14 grid gap-3 border-t border-line pt-6 sm:grid-cols-2 print:hidden">
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
