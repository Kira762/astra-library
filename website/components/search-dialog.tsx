"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { SEARCH_INDEX, type SearchEntry } from "@/lib/docs";
import { useFocusTrap } from "@/lib/focus-trap";
import { lockScroll } from "@/lib/scroll-lock";
import { Icon } from "./icon";

const POPULAR = ["/docs/getting-started", "/docs/windows", "/docs/elements", "/docs/themes", "/docs/icons", "/docs/saving"];

function score(entry: SearchEntry, query: string): number {
  const title = entry.title.toLowerCase();
  if (title === query) return 100;
  if (title.startsWith(query)) return 80;
  if (title.includes(query)) return 60;
  if (entry.haystack.includes(query)) return entry.anchor ? 25 : 40;
  return 0;
}

export function SearchDialog() {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState("");
  const [active, setActive] = useState(0);
  const inputRef = useRef<HTMLInputElement>(null);
  const triggerRef = useRef<HTMLButtonElement>(null);
  const panelRef = useRef<HTMLDivElement>(null);
  const router = useRouter();

  useFocusTrap(panelRef, open);

  const results = useMemo(() => {
    const trimmed = query.trim().toLowerCase();
    if (!trimmed) {
      return POPULAR.map((href) => SEARCH_INDEX.find((entry) => entry.href === href && !entry.anchor))
        .filter((entry): entry is SearchEntry => Boolean(entry))
        .slice(0, 6);
    }
    return SEARCH_INDEX.map((entry) => ({ entry, value: score(entry, trimmed) }))
      .filter((item) => item.value > 0)
      .sort((a, b) => b.value - a.value || a.entry.title.length - b.entry.title.length)
      .slice(0, 8)
      .map((item) => item.entry);
  }, [query]);

  const close = useCallback(() => {
    setOpen(false);
    setQuery("");
    setActive(0);
    triggerRef.current?.focus();
  }, []);

  const openWith = useCallback(() => {
    setOpen(true);
    setActive(0);
  }, []);

  // Global shortcuts: ⌘K / Ctrl+K anywhere, "/" when not typing in a field.
  useEffect(() => {
    function onKeyDown(event: KeyboardEvent) {
      const target = event.target as HTMLElement | null;
      const typing =
        target instanceof HTMLInputElement ||
        target instanceof HTMLTextAreaElement ||
        target?.isContentEditable;

      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
        event.preventDefault();
        setOpen((wasOpen) => {
          if (wasOpen) return false;
          setQuery("");
          setActive(0);
          return true;
        });
        return;
      }
      if (event.key === "/" && !typing && !event.metaKey && !event.ctrlKey) {
        event.preventDefault();
        openWith();
      }
      if (event.key === "Escape") {
        setOpen((wasOpen) => {
          if (wasOpen) close();
          return false;
        });
      }
    }
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [close, openWith]);

  // Focus the field when the dialog opens; keep the page still behind it.
  useEffect(() => {
    if (!open) return;
    inputRef.current?.focus();
    return lockScroll();
  }, [open]);

  function go(entry: SearchEntry) {
    const href = entry.anchor ? `${entry.href}#${entry.anchor}` : entry.href;
    setOpen(false);
    setQuery("");
    router.push(href);
  }

  return (
    <>
      <button
        ref={triggerRef}
        type="button"
        onClick={openWith}
        className="btn gap-2 text-subtle hover:text-ink"
        aria-haspopup="dialog"
        aria-expanded={open}
        aria-label="Search the documentation"
      >
        <Icon name="search" className="h-4 w-4" />
        <span className="hidden sm:inline">Search docs</span>
        <kbd className="kbd ml-1 hidden lg:inline">⌘&nbsp;K</kbd>
      </button>

      {open ? (
        <div
          className="fixed inset-0 z-[70] flex items-start justify-center bg-base/80 px-3 pb-[max(1rem,env(safe-area-inset-bottom))] pt-[max(6vh,env(safe-area-inset-top))] backdrop-blur-sm sm:px-4 sm:pt-[max(12vh,env(safe-area-inset-top))]"
          role="dialog"
          aria-modal="true"
          aria-label="Search the documentation"
          onPointerDown={(event) => {
            // Pointer events cover mouse, touch and pen, so the backdrop
            // dismisses on a phone tap as well as a desktop click.
            if (event.target === event.currentTarget) close();
          }}
        >
          <div
            ref={panelRef}
            className="flex max-h-full w-full max-w-xl flex-col overflow-hidden rounded-2xl border border-line bg-surface shadow-2xl"
          >
            <div className="flex items-center gap-3 border-b border-line px-4 py-3">
              <Icon name="search" className="h-4 w-4 shrink-0 text-subtle" />
              <input
                ref={inputRef}
                type="search"
                name="docs-search"
                value={query}
                onChange={(event) => {
                  setQuery(event.target.value);
                  setActive(0);
                }}
                onKeyDown={(event) => {
                  if (event.key === "ArrowDown") {
                    event.preventDefault();
                    setActive((index) => Math.min(index + 1, results.length - 1));
                  }
                  if (event.key === "ArrowUp") {
                    event.preventDefault();
                    setActive((index) => Math.max(index - 1, 0));
                  }
                  if (event.key === "Enter" && results[active]) {
                    event.preventDefault();
                    go(results[active]);
                  }
                }}
                placeholder="Search pages, elements, props…"
                aria-label="Search the documentation"
                autoComplete="off"
                spellCheck={false}
                // 16px on phones: anything smaller makes iOS Safari zoom the
                // whole page in when the field takes focus.
                className="w-full bg-transparent text-base text-ink placeholder:text-subtle sm:text-sm"
              />
              <button type="button" onClick={close} className="icon-btn h-7 w-7" aria-label="Close search">
                <Icon name="close" className="h-3.5 w-3.5" />
              </button>
            </div>

            <ul className="min-h-0 flex-1 overflow-y-auto overscroll-contain p-2">
              {results.length === 0 ? (
                <li className="px-3 py-6 text-center text-sm text-subtle">
                  Nothing matches “{query}”. Try “toggle”, “saving” or “themes”.
                </li>
              ) : (
                results.map((entry, index) => (
                  <li key={`${entry.href}${entry.anchor ?? ""}`}>
                    <button
                      type="button"
                      onMouseEnter={() => setActive(index)}
                      onClick={() => go(entry)}
                      className={`flex w-full items-start gap-3 rounded-xl px-3 py-2.5 text-left transition-colors ${
                        index === active ? "bg-accent/15" : "hover:bg-raised"
                      }`}
                    >
                      <Icon
                        name={entry.anchor ? "link" : "book"}
                        className="mt-0.5 h-4 w-4 shrink-0 text-accent"
                      />
                      <span className="min-w-0">
                        <span className="block truncate text-sm font-medium text-ink">
                          {entry.title}
                          {entry.anchorLabel ? (
                            <span className="ml-2 text-xs font-normal text-subtle">
                              in {entry.anchorLabel}
                            </span>
                          ) : null}
                        </span>
                        <span className="block truncate text-xs text-muted">
                          {entry.breadcrumb} · {entry.description}
                        </span>
                      </span>
                    </button>
                  </li>
                ))
              )}
            </ul>

            {/* Keyboard hints: pointless on a touch phone, where the list
                simply fills the dialog instead. */}
            <div className="hidden shrink-0 items-center gap-4 border-t border-line px-4 py-2 text-2xs text-subtle sm:flex">
              <span className="flex items-center gap-1">
                <kbd className="kbd">↑</kbd>
                <kbd className="kbd">↓</kbd> to move
              </span>
              <span className="flex items-center gap-1">
                <kbd className="kbd">↵</kbd> to open
              </span>
              <span className="flex items-center gap-1">
                <kbd className="kbd">esc</kbd> to close
              </span>
            </div>
          </div>
        </div>
      ) : null}
    </>
  );
}
