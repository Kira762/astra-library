import Link from "next/link";
import type { ReactNode } from "react";
import { Icon, type IconName } from "./icon";

/* ------------------------------------------------------------------ *
 * Docs content primitives
 * ------------------------------------------------------------------ */

/** Page title block — every docs page starts with one. */
export function PageHeader({
  title,
  description,
  lead,
  meta,
}: {
  title: string;
  description: string;
  lead?: ReactNode;
  meta?: ReactNode;
}) {
  return (
    <header className="mb-8 min-w-0 border-b border-line pb-6">
      <h1 className="min-w-0 text-3xl font-semibold tracking-tight sm:text-4xl">{title}</h1>
      <p className="mt-2 min-w-0 max-w-prose text-base leading-7 text-muted">{description}</p>
      {lead ? <div className="prose-docs mt-4 min-w-0">{lead}</div> : null}
      {meta ? <div className="mt-4 flex min-w-0 flex-wrap items-center gap-2">{meta}</div> : null}
    </header>
  );
}

function Anchor({ id }: { id: string }) {
  return (
    <a href={`#${id}`} className="anchor-link" aria-label="Link to this section">
      <Icon name="link" className="h-4 w-4" />
    </a>
  );
}

export function H2({ id, children }: { id: string; children: ReactNode }) {
  return (
    <h2 id={id} className="anchor-title mt-12 min-w-0 text-2xl font-semibold tracking-tight first:mt-0">
      <span className="min-w-0">{children}</span>
      <Anchor id={id} />
    </h2>
  );
}

export function H3({ id, children }: { id: string; children: ReactNode }) {
  return (
    <h3 id={id} className="anchor-title mt-8 min-w-0 text-lg font-semibold tracking-tight">
      <span className="min-w-0">{children}</span>
      <Anchor id={id} />
    </h3>
  );
}

export function Lead({ children }: { children: ReactNode }) {
  return <p className="prose-docs -mt-1 mb-2 min-w-0">{children}</p>;
}

const CALLOUTS: Record<string, { icon: IconName; tone: string; title: string }> = {
  note: { icon: "info", tone: "text-info", title: "Note" },
  tip: { icon: "tip", tone: "text-success", title: "Tip" },
  warning: { icon: "alert", tone: "text-warning", title: "Warning" },
  danger: { icon: "alert", tone: "text-danger", title: "Careful" },
};

export function Callout({
  type = "note",
  title,
  children,
}: {
  type?: keyof typeof CALLOUTS | string;
  title?: string;
  children: ReactNode;
}) {
  const config = CALLOUTS[type] ?? CALLOUTS.note;
  return (
    <aside className="callout my-4 flex min-w-0 gap-3">
      <Icon name={config.icon} className={`mt-0.5 h-4 w-4 shrink-0 ${config.tone}`} />
      <div className="min-w-0 flex-1">
        <p className={`callout-title ${config.tone}`}>{title ?? config.title}</p>
        <div className="prose-docs mt-1 min-w-0 text-sm leading-6 [&>p:last-child]:mb-0">{children}</div>
      </div>
    </aside>
  );
}

/** A grid of linked cards — the "Start here" pattern from the docs home. */
export function CardGrid({
  columns = 2,
  children,
}: {
  columns?: 2 | 3;
  children: ReactNode;
}) {
  return (
    <div
      className={`my-5 grid min-w-0 gap-3 ${columns === 3 ? "grid-cols-1 sm:grid-cols-2 lg:grid-cols-3" : "grid-cols-1 sm:grid-cols-2"}`}
    >
      {children}
    </div>
  );
}

export function DocCard({
  href,
  title,
  description,
  icon,
  external,
}: {
  href: string;
  title: string;
  description: string;
  icon?: IconName;
  external?: boolean;
}) {
  const body = (
    <>
      <div className="flex min-w-0 items-center gap-2">
        {icon ? <Icon name={icon} className="h-4 w-4 shrink-0 text-accent" /> : null}
        <span className="min-w-0 truncate font-display text-sm font-semibold text-ink">{title}</span>
        {external ? <Icon name="external" className="h-3.5 w-3.5 shrink-0 text-subtle" /> : null}
      </div>
      <p className="mt-1.5 min-w-0 text-sm leading-6 text-muted">{description}</p>
    </>
  );

  if (external) {
    return (
      <a href={href} target="_blank" rel="noreferrer" className="card-link min-w-0">
        {body}
      </a>
    );
  }
  return (
    <Link href={href} className="card-link min-w-0">
      {body}
    </Link>
  );
}

type Row = [string, string] | [string, string, string];

/** Two-column prop table: name → description. */
export function PropTable({ rows, headers = ["Prop", "Description"] }: { rows: Row[]; headers?: [string, string] }) {
  return (
    <div className="my-4 w-full min-w-0 max-w-full overflow-hidden rounded-xl border border-line">
      <div className="data-table-wrapper w-full overflow-x-auto">
        <table className="data-table">
          <thead>
            <tr>
              <th className="w-[38%] min-w-[120px]">{headers[0]}</th>
              <th className="min-w-[200px]">{headers[1]}</th>
            </tr>
          </thead>
          <tbody>
            {rows.map(([name, description, extra]) => (
              <tr key={name}>
                <td className="min-w-0">
                  <code className="icode break-words">{name}</code>
                  {extra ? (
                    <span className="ml-2 inline-block rounded-full bg-accent/15 px-2 py-0.5 text-2xs text-accent">
                      {extra}
                    </span>
                  ) : null}
                </td>
                <td className="min-w-0">{description}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

/** Three-column reference table: name → type → description. */
export function TypeTable({
  rows,
  headers = ["Prop", "Type", "Description"],
}: {
  rows: [string, string, string][];
  headers?: [string, string, string];
}) {
  return (
    <div className="my-4 w-full min-w-0 max-w-full overflow-hidden rounded-xl border border-line">
      <div className="data-table-wrapper w-full overflow-x-auto">
        <table className="data-table">
          <thead>
            <tr>
              <th className="w-[26%] min-w-[100px]">{headers[0]}</th>
              <th className="w-[22%] min-w-[80px]">{headers[1]}</th>
              <th className="min-w-[180px]">{headers[2]}</th>
            </tr>
          </thead>
          <tbody>
            {rows.map(([name, type, description]) => (
              <tr key={name}>
                <td className="min-w-0">
                  <code className="icode break-words">{name}</code>
                </td>
                <td className="min-w-0">
                  <span className="break-words font-mono text-xs text-subtle">{type}</span>
                </td>
                <td className="min-w-0">{description}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

/** Inline code that is not inside a prose block. */
export function C({ children }: { children: ReactNode }) {
  return <code className="icode break-words">{children}</code>;
}

/** A sentence-list used for "where to go next" blocks. */
export function NextLinks({ items }: { items: { href: string; label: string; description: string }[] }) {
  return (
    <ul className="my-4 grid min-w-0 gap-2 sm:grid-cols-2">
      {items.map((item) => (
        <li key={item.href} className="min-w-0">
          <Link href={item.href} className="group flex min-w-0 items-start gap-2 text-sm">
            <Icon
              name="arrow-right"
              className="mt-1 h-3.5 w-3.5 shrink-0 text-accent transition-transform group-hover:translate-x-0.5"
            />
            <span className="min-w-0 flex-1">
              <span className="block font-medium text-ink group-hover:text-accent">{item.label}</span>
              <span className="block min-w-0 text-muted">{item.description}</span>
            </span>
          </Link>
        </li>
      ))}
    </ul>
  );
}
