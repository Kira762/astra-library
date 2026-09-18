"use client";

import { useEffect, useState } from "react";
import { Icon } from "./icon";

/**
 * Copies text to the clipboard and confirms it, without stealing focus.
 *
 * `showLabel` puts the word next to the glyph on pointer-width screens. The
 * icon is still the only thing a phone shows, so the accessible name never
 * depends on the label being visible.
 */
export function CopyButton({
  text,
  label = "Copy code",
  showLabel = false,
}: {
  text: string;
  label?: string;
  showLabel?: boolean;
}) {
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    if (!copied) return;
    const timer = window.setTimeout(() => setCopied(false), 1800);
    return () => window.clearTimeout(timer);
  }, [copied]);

  async function copy() {
    try {
      if (navigator.clipboard?.writeText) {
        await navigator.clipboard.writeText(text);
      } else {
        // Fallback for runtimes without the async clipboard API.
        const area = document.createElement("textarea");
        area.value = text;
        area.setAttribute("readonly", "");
        area.style.position = "fixed";
        area.style.opacity = "0";
        document.body.appendChild(area);
        area.select();
        document.execCommand("copy");
        document.body.removeChild(area);
      }
      setCopied(true);
    } catch {
      setCopied(false);
    }
  }

  return (
    <button
      type="button"
      onClick={copy}
      className={`icon-btn h-8 shrink-0 gap-1.5 ${
        showLabel ? "w-auto px-2 sm:px-2.5" : "w-8"
      }`}
      aria-label={copied ? "Copied" : label}
      title={copied ? "Copied" : label}
    >
      <Icon
        name={copied ? "check" : "copy"}
        className={`h-4 w-4 shrink-0 ${copied ? "text-success" : ""}`}
      />
      {showLabel ? (
        <span className="hidden text-xs font-medium sm:inline">
          {copied ? "Copied" : "Copy"}
        </span>
      ) : null}
      <span aria-live="polite" className="sr-only">
        {copied ? "Copied to clipboard" : ""}
      </span>
    </button>
  );
}
