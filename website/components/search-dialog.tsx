"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { SEARCH_INDEX, type SearchEntry } from "@/lib/docs";
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
  const router = useRouter();

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
    const previous = document.documentElement.style.overflow;
    document.documentElement.style.overflow = "hidden";
    return () => {
      document.documentElement.style.overflow = previous;
    };
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
        className="btn gap-1.5 text-subtle hover:text-ink sm:gap-2"
        aria-haspopup="dialog"
        aria-expanded={open}
      >
        <Icon name="search" className="h-4 w-4 shrink-0" />
        <span className="hidden sm:inline">Search docs</span>
        <span className="sm:hidden">Search</span>
        <kbd className="kbd ml-1 hidden md:inline">⌘ K</kbd>
      </button>

      {open ? (
        <div
          className="fixed inset-0 z-[70] flex w-full max-w-[100vw] items-start justify-center overflow-hidden bg-base/80 px-3 pt-[8vh] backdrop-blur-sm sm:px-4 sm:pt-[12vh]"
          role="dialog"
          aria-modal="true"
          aria-label="Search the documentation"
          onMouseDown={(event) => {
            if (event.target === event.currentTarget) close();
          }}
        >
          <div className="flex max-h-[85vh] w-full min-w-0 max-w-xl flex-col overflow-hidden rounded-2xl border border-line bg-surface shadow-2xl sm:max-h-[70vh]">
            <div className="flex min-w-0 items-center gap-2 border-b border-line px-3 py-3 sm:gap-3 sm:px-4">
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
                className="min-w-0 flex-1 bg-transparent text-sm text-ink placeholder:text-subtle"
              />
              <button type="button" onClick={close} className="icon-btn h-8 w-8 shrink-0" aria-label="Close search">
                <Icon name="close" className="h-3.5 w-3.5" />
              </button>
            </div>

            <ul className="max-h-[50vh] min-w-0 overflow-y-auto overflow-x-hidden overscroll-contain p-2 sm:max-h-[52vh]">
              {results.length === 0 ? (
                <li className="px-3 py-6 text-center text-sm text-subtle">
                  Nothing matches &ldquo;{query}&rdquo;. Try &ldquo;toggle&rdquo;, &ldquo;saving&rdquo; or &ldquo;themes&rdquo;.
                </li>
              ) : (
                results.map((entry, index) => (
                  <li key={`${entry.href}${entry.anchor ?? ""}`} className="min-w-0">
                    <button
                      type="button"
                      onMouseEnter={() => setActive(index)}
                      onClick={() => go(entry)}
                      className={`flex w-full min-w-0 items-start gap-3 rounded-xl px-3 py-2.5 text-left transition-colors ${
                        index === active ? "bg-accent/15" : "hover:bg-raised"
                      }`}
                    >
                      <Icon
                        name={entry.anchor ? "link" : "book"}
                        className="mt-0.5 h-4 w-4 shrink-0 text-accent"
                      />
                      <span className="min-w-0 flex-1">
                        <span className="block min-w-0 truncate text-sm font-medium text-ink">
                          {entry.title}
                          {entry.anchorLabel ? (
                            <span className="ml-2 hidden text-xs font-normal text-subtle sm:inline">
                              in {entry.anchorLabel}
                            </span>
                          ) : null}
                        </span>
                        <span className="block min-w-0 truncate text-xs text-muted">
                          {entry.breadcrumb} · {entry.description}
                        </span>
                      </span>
                    </button>
                  </li>
                ))
              )}
            </ul>

            <div className="flex min-w-0 items-center gap-2 border-t border-line px-3 py-2 text-2xs text-subtle sm:gap-4 sm:px-4">
              <span className="flex items-center gap-1">
                <kbd className="kbd">↑</kbd>
                <kbd className="kbd">↓</kbd> <span className="hidden sm:inline">to move</span>
              </span>
              <span className="flex items-center gap-1">
                <kbd className="kbd">↵</kbd> <span className="hidden sm:inline">to open</span>
              </span>
              <span className="flex items-center gap-1">
                <kbd className="kbd">esc</kbd> <span className="hidden sm:inline">to close</span>
              </span>
            </div>
          </div>
        </div>
      ) : null}
    </>
  );
}
