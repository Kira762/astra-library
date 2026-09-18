import Link from "next/link";
import { NAV, REPO_URL } from "@/lib/docs";
import { Icon } from "./icon";

export function SiteFooter() {
  return (
    <footer className="mt-20 w-full max-w-[100vw] overflow-x-clip border-t border-line">
      <div className="mx-auto grid w-full max-w-shell gap-8 px-4 py-12 sm:grid-cols-2 lg:grid-cols-[1.3fr_1fr_1fr_1fr] lg:px-6">
        <div className="min-w-0 sm:col-span-2 lg:col-span-1">
          <p className="font-display text-sm font-semibold">Astra v1</p>
          <p className="mt-2 max-w-xs text-sm leading-6 text-muted">
            A Luau interface library for Roblox executor scripts — one loader line, windows with
            tabs and elements, saving, themes and icon packs built in.
          </p>
          <p className="mt-3 text-xs text-subtle">MIT licensed. Luau source in the repository root.</p>
        </div>

        <nav aria-label="Documentation" className="min-w-0">
          <p className="font-display text-xs font-semibold text-subtle">Documentation</p>
          <ul className="mt-3 grid gap-1.5 text-sm">
            {NAV[0].pages.map((page) => (
              <li key={page.href}>
                <Link href={page.href} className="text-muted transition-colors hover:text-ink">
                  {page.title}
                </Link>
              </li>
            ))}
            <li>
              <Link href="/docs/api/methods" className="text-muted transition-colors hover:text-ink">
                Method index
              </Link>
            </li>
          </ul>
        </nav>

        <nav aria-label="Repository" className="min-w-0">
          <p className="font-display text-xs font-semibold text-subtle">Repository</p>
          <ul className="mt-3 grid gap-1.5 text-sm">
            {[
              ["GitHub", REPO_URL],
              ["USAGE.md", `${REPO_URL}/blob/main/USAGE.md`],
              ["MODULES.md", `${REPO_URL}/blob/main/MODULES.md`],
              ["CHANGELOG.md", `${REPO_URL}/blob/main/CHANGELOG.md`],
              ["Icon catalog", `${REPO_URL}/blob/main/assets/icons/README.md`],
            ].map(([label, href]) => (
              <li key={href} className="min-w-0">
                <a
                  href={href}
                  target="_blank"
                  rel="noreferrer"
                  className="inline-flex max-w-full items-center gap-1.5 text-muted transition-colors hover:text-ink"
                >
                  <span className="truncate">{label}</span>
                  <Icon name="external" className="h-3 w-3 shrink-0 text-subtle" />
                </a>
              </li>
            ))}
          </ul>
        </nav>

        <div className="min-w-0">
          <p className="font-display text-xs font-semibold text-subtle">Also in this repo</p>
          <ul className="mt-3 grid gap-1.5 text-sm">
            <li>
              <Link href="/docs/skill" className="text-muted transition-colors hover:text-ink">
                Agent skill
              </Link>
            </li>
            <li className="min-w-0">
              <a
                href="https://skills.sh/Kira762/astra-version-1"
                target="_blank"
                rel="noreferrer"
                className="inline-flex max-w-full items-center gap-1.5 text-muted transition-colors hover:text-ink"
              >
                <span className="truncate">skills.sh listing</span>
                <Icon name="external" className="h-3 w-3 shrink-0 text-subtle" />
              </a>
            </li>
            <li>
              <Link href="/docs/repo" className="text-muted transition-colors hover:text-ink">
                How this site is published
              </Link>
            </li>
          </ul>
        </div>
      </div>

      <div className="border-t border-line">
        <div className="mx-auto flex w-full max-w-shell flex-col gap-2 px-4 py-5 text-xs text-subtle sm:flex-row sm:items-center sm:justify-between lg:px-6">
          <p className="min-w-0 break-words">
            Docs are a static export of <code className="font-mono text-muted">website/</code> — the Luau library is never part
            of the web build.
          </p>
          <p className="tnum shrink-0">Built from USAGE.md · published with GitHub Pages</p>
        </div>
      </div>
    </footer>
  );
}
