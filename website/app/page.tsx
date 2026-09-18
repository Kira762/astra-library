import Link from "next/link";
import { CodeBlock, CommandLine } from "@/components/code-block";
import { CardGrid, DocCard } from "@/components/content";
import { Icon } from "@/components/icon";
import { WindowPreview } from "@/components/window-preview";
import { LOADER_LINE, REPO_URL, SITE_URL } from "@/lib/docs";

const HIGHLIGHTS = [
  {
    icon: "package" as const,
    title: "Built in code, not loaded as a model",
    body: "Astra constructs its interface from instances at runtime. There is no marketplace model to fetch and nothing that fingerprints the script, and the whole library is one file you can read.",
    href: "/docs/startup",
    linkLabel: "How it is built",
  },
  {
    icon: "star" as const,
    title: "State that saves itself",
    body: "Give a control a flag and it joins the save system. Auto Save and Auto Load are on by default, and named configurations let a hub keep more than one preset without writing a line of glue code.",
    href: "/docs/saving",
    linkLabel: "Saving and flags",
  },
  {
    icon: "sparkle" as const,
    title: "Ten themes and 13,715 icons",
    body: "Swap between ten built-in themes or hand over a table of your own colours. Seven icon packs resolve by bare name across packs, by pack:name when it has to be exact, or from your own custom_asset folder.",
    href: "/docs/themes",
    linkLabel: "Themes and icons",
  },
  {
    icon: "sliders" as const,
    title: "One motion service behind everything",
    body: "Hover, reveal, entrance, dismissal and the result flashes all run through the same tween vocabulary, so your own animations match the window and both follow the speed setting the player chose.",
    href: "/docs/motion",
    linkLabel: "Motion API",
  },
];

const ELEMENTS = [
  ["Button", "Run a function on click, with the built-in tap glyph.", "/docs/elements/button"],
  ["Toggle", "Switch a boolean on and off — Switch is a declarative alias.", "/docs/elements/toggle"],
  ["Slider", "Pick a number in a range, with suffix, increment and a minimal style.", "/docs/elements/slider"],
  ["Dropdown", "One option or many, searchable, with Refresh/Add/Remove.", "/docs/elements/dropdown"],
  ["Input", "A text field that commits when the player is done.", "/docs/elements/input"],
  ["Stat", "A value that rolls on change and reads out how far it moved.", "/docs/elements/stat"],
  ["Text", "A title, a body, or both, on a card of its own.", "/docs/elements/text"],
  ["Divider", "A rule across the page, with a word in the middle or nothing at all.", "/docs/elements/text#divider"],
  ["Group", "Rows and columns that nest, with compact children by default.", "/docs/elements/text#group"],
  ["Collapsible group", "Controls under an animated header, closed until opened.", "/docs/elements/collapsible-group"],
  ["Changelog", "Release history as a first-class element.", "/docs/elements/changelog"],
];

const STRUCTURED_DATA = {
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  name: "Astra v1",
  applicationCategory: "DeveloperApplication",
  operatingSystem: "Roblox",
  description:
    "Luau interface library for Roblox executor scripts: one loader line, windows with tabs and elements, saving, ten themes and seven icon packs.",
  url: SITE_URL,
  codeRepository: REPO_URL,
  license: "https://opensource.org/licenses/MIT",
  author: { "@type": "Person", name: "Kira762", url: "https://github.com/Kira762" },
  offers: { "@type": "Offer", price: "0", priceCurrency: "USD" },
};

export default function Home() {
  return (
    <main id="content">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(STRUCTURED_DATA) }}
      />
      {/* ---------------------------------------------------------------- */}
      <section className="starfield relative overflow-hidden border-b border-line">
        <div
          aria-hidden
          className="pointer-events-none absolute -top-40 left-1/2 h-[520px] w-[900px] -translate-x-1/2 rounded-full bg-accent/15 blur-[120px]"
        />
        <div className="relative mx-auto grid max-w-shell items-start gap-12 px-4 py-14 lg:grid-cols-[minmax(0,1fr)_minmax(0,470px)] lg:px-6 lg:py-20 xl:grid-cols-[minmax(0,1fr)_minmax(0,620px)]">
          <div className="lg:pt-6">
            <p className="pill">
              <Icon name="star" className="h-3 w-3 text-gold" />
              Luau interface library for Roblox executor scripts
            </p>

            <h1 className="mt-5 text-4xl font-semibold leading-[1.05] tracking-tight sm:text-5xl xl:text-6xl">
              One line to load.
              <span className="block text-muted">One call to build.</span>
            </h1>

            <p className="mt-5 max-w-xl text-lg leading-8 text-muted">
              Load the bundle, call <code className="icode">CreateWindow</code>, and fill it with tabs
              and elements. Saving, ten themes, seven icon packs and staged startup are already
              inside — no model to download, nothing to wire up twice.
            </p>

            <div className="mt-6 flex flex-wrap items-center gap-3">
              <Link href="/docs/getting-started" className="btn btn-primary">
                Start the guide
                <Icon name="arrow-right" className="h-4 w-4" />
              </Link>
              <Link href="/docs/elements" className="btn">
                Browse the elements
              </Link>
              <a href={REPO_URL} target="_blank" rel="noreferrer" className="btn">
                <Icon name="github" className="h-4 w-4" />
                GitHub
              </a>
            </div>

            <div className="mt-7 max-w-xl">
              <CommandLine command={LOADER_LINE} caption="loader line" />
              <p className="text-sm leading-6 text-subtle">
                Executors supply <code className="icode">loadstring</code> and{" "}
                <code className="icode">HttpService</code>. In Studio the same library is a
                ModuleScript: <code className="icode">require(ReplicatedStorage.Astra)</code>.
              </p>
            </div>
          </div>

          <WindowPreview />
        </div>
      </section>

      {/* ---------------------------------------------------------------- */}
      <section className="mx-auto max-w-shell px-4 py-14 lg:px-6">
        <div className="grid gap-10 lg:grid-cols-[220px_minmax(0,1fr)]">
          <div>
            <h2 className="text-xl font-semibold tracking-tight">Start here</h2>
            <p className="mt-2 text-sm leading-6 text-muted">
              Four pages cover the whole model: load it, open a window, add elements, keep what the
              player chose.
            </p>
          </div>
          <div>
            <CardGrid columns={3}>
              <DocCard
                href="/docs/getting-started"
                icon="zap"
                title="Getting started"
                description="The loader contract, the two reasons a load fails, and your first window."
              />
              <DocCard
                href="/docs/windows"
                icon="package"
                title="Windows"
                description="CreateWindow props, layouts, every runtime method, and the profile card."
              />
              <DocCard
                href="/docs/tabs"
                icon="grid"
                title="Tabs and groups"
                description="Split a window into tabs, then lay controls out in rows and columns."
              />
              <DocCard
                href="/docs/elements"
                icon="layers"
                title="Elements"
                description="What every element shares, plus a page for each of the eleven types."
              />
              <DocCard
                href="/docs/saving"
                icon="check"
                title="Saving and flags"
                description="Auto save, auto load, named configurations, and how flags are derived."
              />
              <DocCard
                href="/docs/api/methods"
                icon="book"
                title="Method index"
                description="Every window, tab, group and element-handle method on one page."
              />
            </CardGrid>
          </div>
        </div>
      </section>

      {/* ---------------------------------------------------------------- */}
      <section className="border-y border-line bg-surface/40">
        <div className="mx-auto max-w-shell px-4 py-14 lg:px-6">
          <h2 className="max-w-2xl text-2xl font-semibold tracking-tight sm:text-3xl">
            What makes it worth the loader line
          </h2>
          <div className="mt-8 grid gap-x-12 gap-y-8 md:grid-cols-2">
            {HIGHLIGHTS.map((item) => (
              <div key={item.title} className="border-t border-line pt-5">
                <div className="flex items-center gap-2.5">
                  <Icon name={item.icon} className="h-4 w-4 text-accent" />
                  <h3 className="text-base font-semibold">{item.title}</h3>
                </div>
                <p className="mt-2 max-w-prose text-sm leading-7 text-muted">{item.body}</p>
                <Link
                  href={item.href}
                  className="group mt-3 inline-flex items-center gap-1.5 text-sm font-medium text-accent"
                >
                  {item.linkLabel}
                  <Icon
                    name="arrow-right"
                    className="h-3.5 w-3.5 transition-transform group-hover:translate-x-0.5"
                  />
                </Link>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ---------------------------------------------------------------- */}
      <section className="mx-auto max-w-shell px-4 py-14 lg:px-6">
        <div className="grid gap-10 lg:grid-cols-[minmax(0,1fr)_minmax(0,560px)]">
          <div>
            <h2 className="text-2xl font-semibold tracking-tight">Your first window</h2>
            <p className="mt-2 max-w-prose text-sm leading-7 text-muted">
              A window is the entry point. Add a tab, fill it with elements, and the first visible tab
              opens on its own. Switch between the two load paths with the tabs above the code — the
              API below them is identical either way.
            </p>
            <ul className="mt-5 grid gap-3 text-sm text-muted">
              {[
                ["Layouts are built in.", "Topbar, sidebar or collapsed sidebar — the player changes it in Settings → Appearance, no code involved."],
                ["Controls know their flags.", "Pass a flag and the control joins save/load; leave it out and one is derived from the name."],
                ["Nothing is drawn twice.", "The window builds itself in staged batches so the opening tween keeps its frames."],
              ].map(([title, body]) => (
                <li key={title} className="flex gap-3">
                  <Icon name="check" className="mt-0.5 h-4 w-4 shrink-0 text-success" />
                  <span>
                    <strong className="font-medium text-ink">{title}</strong> {body}
                  </span>
                </li>
              ))}
            </ul>
          </div>

          <div className="lg:pt-12">
            <CodeBlock
              title="example.client.luau"
              tabs={[
                {
                  label: "Executor",
                  code: `local Astra = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Kira762/astra-version-1/main/version-1.luau"
))()

local window = Astra:CreateWindow({ name = "Example Hub", subtitle = "Astra" })
local tab = window:CreateTab({ name = "Home", icon = "house" })

tab:CreateToggle({
    name = "Auto Sprint",
    flag = "autoSprint",
    value = true,
    callback = function(on) print("Auto Sprint:", on) end,
})

tab:CreateSlider({
    name = "Sensitivity",
    range = { 1, 10 },
    value = 5,
    suffix = "x",
    minimal = true,
    callback = function(value, dragging) end,
})

tab:CreateButton({
    name = "Say hello",
    icon = "play",
    callback = function()
        window:Notify({ title = "Hello", content = "Your first element works." })
    end,
})

tab:Select()`,
                },
                {
                  label: "Studio / Rojo",
                  code: `local Astra = require(game:GetService("ReplicatedStorage").Astra)

local window = Astra:CreateWindow({ name = "Example Hub", subtitle = "Astra" })
local tab = window:CreateTab({ name = "Home", icon = "house" })

tab:CreateToggle({ name = "Auto Sprint", flag = "autoSprint", value = true })
tab:Select()`,
                },
              ]}
            />
            <p className="text-sm text-subtle">
              The full end-to-end example — every element type in one tab — is{" "}
              <a
                href={`${REPO_URL}/blob/main/example.client.luau`}
                target="_blank"
                rel="noreferrer"
                className="text-accent underline decoration-dotted underline-offset-2"
              >
                example.client.luau
              </a>
              .
            </p>
          </div>
        </div>
      </section>

      {/* ---------------------------------------------------------------- */}
      <section className="border-y border-line bg-surface/40">
        <div className="mx-auto max-w-shell px-4 py-14 lg:px-6">
          <h2 className="text-2xl font-semibold tracking-tight">Every element, one table</h2>
          <p className="mt-2 max-w-prose text-sm leading-7 text-muted">
            Each element has a page with its props, its handle methods and a copy-pasteable example.
          </p>
          <div className="mt-6 overflow-hidden rounded-xl border border-line">
            <div className="overflow-x-auto">
              <table className="data-table">
                <thead>
                  <tr>
                    <th className="w-[220px]">Element</th>
                    <th>What it does</th>
                  </tr>
                </thead>
                <tbody>
                  {ELEMENTS.map(([name, description, href]) => (
                    <tr key={name}>
                      <td>
                        <Link
                          href={href}
                          className="font-medium text-ink underline decoration-transparent underline-offset-2 transition-colors hover:text-accent hover:decoration-current"
                        >
                          {name}
                        </Link>
                      </td>
                      <td>{description}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </section>

      {/* ---------------------------------------------------------------- */}
      <section className="mx-auto max-w-shell px-4 py-14 lg:px-6">
        <div className="grid items-center gap-8 rounded-2xl border border-line bg-surface px-6 py-8 lg:grid-cols-[minmax(0,1fr)_minmax(0,420px)] lg:px-10">
          <div>
            <h2 className="text-xl font-semibold tracking-tight">
              Let a coding agent write the interface
            </h2>
            <p className="mt-2 max-w-prose text-sm leading-7 text-muted">
              This repository is also a published Agent Skill. Install it and Claude Code, Cursor or
              Codex gets the loader contract, the element cheat sheet and the module rules — so it
              stops guessing at the API and starts reading the same pages you are.
            </p>
            <p className="mt-3 text-sm">
              <Link href="/docs/skill" className="font-medium text-accent hover:underline">
                What is inside the skill
              </Link>
            </p>
          </div>
          <div>
            <CommandLine
              command="npx skills add Kira762/astra-version-1"
              caption="agent skill"
            />
            <p className="text-xs text-subtle">
              Installs <code className="icode">astra</code> into your agent&apos;s skills folder. Listed
              on{" "}
              <a
                href="https://skills.sh/Kira762/astra-version-1"
                target="_blank"
                rel="noreferrer"
                className="text-muted underline decoration-dotted underline-offset-2"
              >
                skills.sh
              </a>
              .
            </p>
          </div>
        </div>
      </section>
    </main>
  );
}
