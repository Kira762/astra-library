/**
 * Page scroll lock for overlays (the search dialog, the docs drawer).
 *
 * On phones an open overlay must not scroll the article behind it. The
 * document is locked by pinning the root element's overflow, and a counter
 * makes nesting safe: two overlays opening and closing in any order always
 * leave the page exactly as they found it.
 */

let holders = 0;
let previousOverflow: string | null = null;

export function lockScroll(): () => void {
  if (typeof document === "undefined") return () => {};

  const root = document.documentElement;
  if (holders === 0) {
    previousOverflow = root.style.overflow;
    root.style.overflow = "hidden";
  }
  holders += 1;

  let released = false;
  return () => {
    if (released) return;
    released = true;
    holders = Math.max(0, holders - 1);
    if (holders === 0) {
      root.style.overflow = previousOverflow ?? "";
      previousOverflow = null;
    }
  };
}
