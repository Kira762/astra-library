"use client";

import { useId, useMemo, useState } from "react";
import { tokenClass, tokenizeLuau } from "@/lib/highlight";
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

/** Colours the code with the tokeniser in lib/highlight — no dependency. */
function Highlighted({ code }: { code: string }) {
  const tokens = useMemo(() => tokenizeLuau(code), [code]);
  return (
    <>
      {tokens.map((token, index) => {
        const className = tokenClass(token.kind);
        return className ? (
          <span key={index} className={className}>
            {token.value}
          </span>
        ) : (
          token.value
        );
      })}
    </>
  );
}

export function CodeBlock({ code, tabs, title, lang = "Luau", className = "" }: CodeBlockProps) {
  const [active, setActive] = useState(0);
  const panelId = useId();
  const variants: CodeVariant[] = tabs?.length ? tabs : [{ label: lang, code: code ?? "" }];
  const current = variants[Math.min(active, variants.length - 1)];
  const hasTabs = variants.length > 1;

  return (
    <figure className={`code-frame my-4 ${className}`}>
      <figcaption className="code-head">
        <div className="code-meta min-w-0">
          {hasTabs ? (
            <div role="tablist" aria-label={title ?? "Code variants"} className="code-tabs">
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
                  className="code-tab"
                >
                  {variant.label}
                </button>
              ))}
            </div>
          ) : (
            <span className="shrink-0 rounded-md border border-line px-1.5 py-0.5 text-2xs leading-4 text-subtle">
              {lang}
            </span>
          )}
          {title ? <span className="truncate">{title}</span> : null}
        </div>
        <CopyButton text={current.code} showLabel />
      </figcaption>
      <pre id={panelId} role={hasTabs ? "tabpanel" : undefined} tabIndex={0}>
        <code className="font-mono whitespace-pre">
          <Highlighted code={current.code} />
        </code>
      </pre>
    </figure>
  );
}

/** One-line command strip for install instructions. */
export function CommandLine({ command, caption }: { command: string; caption?: string }) {
  return (
    <div className="code-frame my-4">
      <div className="flex items-center gap-3 px-3.5 py-3">
        <span aria-hidden className="select-none font-mono text-sm text-accent">
          $
        </span>
        <code className="scroll-x flex-1 whitespace-pre font-mono text-sm text-ink/90">
          {command}
        </code>
        <CopyButton text={command} label={`Copy ${caption ?? "command"}`} showLabel />
      </div>
    </div>
  );
}
