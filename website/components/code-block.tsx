"use client";

import { useId, useState } from "react";
import { CopyButton } from "./copy-button";

export type CodeVariant = {
  /** Tab label, e.g. "Luau" or "Studio". */
  label: string;
  code: string;
};

type CodeBlockProps = {
  /** The code to show. Pass `tabs` instead to offer more than one variant. */
  code?: string;
  tabs?: CodeVariant[];
  /** Left-hand caption above the code, e.g. a file name. */
  title?: string;
  /** Right-hand language note, shown when there are no tabs. */
  lang?: string;
  className?: string;
};

export function CodeBlock({ code, tabs, title, lang = "Luau", className = "" }: CodeBlockProps) {
  const [active, setActive] = useState(0);
  const panelId = useId();
  const variants: CodeVariant[] = tabs?.length ? tabs : [{ label: lang, code: code ?? "" }];
  const current = variants[Math.min(active, variants.length - 1)];
  const hasTabs = variants.length > 1;

  return (
    <figure className={`code-frame my-4 ${className}`}>
      <figcaption className="flex items-center justify-between gap-3 border-b border-line bg-raised/50 px-3 py-1.5">
        <div className="flex min-w-0 items-center gap-2">
          {hasTabs ? (
            <div role="tablist" aria-label={title ?? "Code variants"} className="flex items-center gap-1">
              {variants.map((variant, index) => (
                <button
                  key={variant.label}
                  type="button"
                  role="tab"
                  id={`${panelId}-tab-${index}`}
                  aria-selected={index === active}
                  aria-controls={panelId}
                  tabIndex={index === active ? 0 : -1}
                  onClick={() => setActive(index)}
                  onKeyDown={(event) => {
                    if (event.key !== "ArrowRight" && event.key !== "ArrowLeft") return;
                    event.preventDefault();
                    const next =
                      event.key === "ArrowRight"
                        ? (index + 1) % variants.length
                        : (index - 1 + variants.length) % variants.length;
                    setActive(next);
                    document.getElementById(`${panelId}-tab-${next}`)?.focus();
                  }}
                  className={`rounded-md px-2 py-1 text-xs font-medium transition-colors ${
                    index === active
                      ? "bg-accent/15 text-accent"
                      : "text-subtle hover:bg-raised hover:text-ink"
                  }`}
                >
                  {variant.label}
                </button>
              ))}
            </div>
          ) : (
            <span className="truncate font-mono text-2xs text-subtle">{title ?? lang}</span>
          )}
          {hasTabs && title ? (
            <span className="hidden truncate font-mono text-2xs text-subtle sm:inline">{title}</span>
          ) : null}
        </div>
        <CopyButton text={current.code} />
      </figcaption>
      <pre id={panelId} role={hasTabs ? "tabpanel" : undefined} tabIndex={0}>
        <code className="font-mono whitespace-pre">{current.code}</code>
      </pre>
    </figure>
  );
}

/** One-line command strip for install instructions. */
export function CommandLine({ command, caption }: { command: string; caption?: string }) {
  return (
    <div className="code-frame my-4">
      <div className="flex items-center gap-3 px-3 py-2.5">
        <span aria-hidden className="select-none font-mono text-sm text-accent">
          $
        </span>
        <code className="scroll-x flex-1 whitespace-pre font-mono text-sm text-ink/90">
          {command}
        </code>
        <CopyButton text={command} label={`Copy ${caption ?? "command"}`} />
      </div>
    </div>
  );
}
