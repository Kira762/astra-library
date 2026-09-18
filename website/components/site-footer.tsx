import Link from "next/link";
import { NAV, REPO_URL } from "@/lib/docs";
import { Icon } from "./icon";

export function SiteFooter() {
  return (
    <footer className="border-t border-line print:hidden">
      <div className="mx-auto grid max-w-shell gap-10 px-4 py-14 lg:grid-cols-[1.4fr_1fr_1fr_1fr] lg:gap-12 lg:px-6 lg:py-16">
        <div>
          <p className="font-display text-sm font-semibold">Astra v1</p>
          <p className="mt-3 max-w-xs text-sm text-muted">
            A Luau interface library for Roblox executor scripts — one loader line, windows with
            tabs and elements, saving, themes and icon packs built in.
          </p>
          <p className="mt-4 text-xs text-subtle">MIT licensed. Luau source in the repository root.</p>
        </div>

        <nav aria-label="Documentation">
          <p className="font-display text-xs font-semibold text-subtle">Documentation</p>
          <ul className="mt-4 grid gap-1.5 text-sm">
            {NAV[0].pages.map((page) => (
              <li key={page.href}>
                <Link href={page.href} className="text-muted transition-colors duration-150 ease-out hover:text-ink">
                  {page.title}
                </Link>
              </li>
            ))}
            <li>
              <Link href="/docs/api/methods" className="text-muted transition-colors duration-150 ease-out hover:text-ink">
                Method index
              </Link>
            </li>
          </ul>
        </nav>

        <nav aria-label="Repository">
          <p className="font-display text-xs font-semibold text-subtle">Repository</p>
          <ul className="mt-4 grid gap-1.5 text-sm">
            {[
              ["GitHub", REPO_URL],
              ["USAGE.md", `${REPO_URL}/blob/main/USAGE.md`],
              ["MODULES.md", `${REPO_URL}/blob/main/MODULES.md`],
              ["CHANGELOG.md", `${REPO_URL}/blob/main/CHANGELOG.md`],
              ["Icon catalog", `${REPO_URL}/blob/main/assets/icons/README.md`],
            ].map(([label, href]) => (
              <li key={href}>
                <a
                  href={href}
                  target="_blank"
                  rel="noreferrer"
                  className="inline-flex items-center gap-1.5 text-muted transition-colors duration-150 ease-out hover:text-ink"
                >
                  {label}
                  <Icon name="external" className="h-3 w-3 text-subtle" />
                </a>
              </li>
            ))}
          </ul>
        </nav>

        <div>
          <p className="font-display text-xs font-semibold text-subtle">Also in this repo</p>
          <ul className="mt-4 grid gap-1.5 text-sm">
            <li>
              <Link href="/docs/skill" className="text-muted transition-colors duration-150 ease-out hover:text-ink">
                Agent skill
              </Link>
            </li>
            <li>
              <a
                href="https://skills.sh/Kira762/astra-version-1"
                target="_blank"
                rel="noreferrer"
                className="inline-flex items-center gap-1.5 text-muted transition-colors duration-150 ease-out hover:text-ink"
              >
                skills.sh listing
                <Icon name="external" className="h-3 w-3 text-subtle" />
              </a>
            </li>
            <li>
              <Link href="/docs/repo" className="text-muted transition-colors duration-150 ease-out hover:text-ink">
                How this site is published
              </Link>
            </li>
          </ul>
        </div>
      </div>

      <div className="border-t border-line">
        <div className="mx-auto flex max-w-shell flex-col gap-2 px-4 py-6 pb-[max(1.5rem,env(safe-area-inset-bottom))] text-xs text-subtle sm:flex-row sm:items-center sm:justify-between lg:px-6">
          <p>
            Docs are a static export of{" "}
            <code className="font-mono text-muted">website/</code> — the Luau library is never part
            of the web build.
          </p>
          <p className="tnum">Built from USAGE.md · published with GitHub Pages</p>
        </div>
      </div>
    </footer>
  );
}
