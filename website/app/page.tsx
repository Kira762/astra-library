import Link from "next/link";

export default function Home() {
  return (
    <div className="min-h-screen bg-[#09090b] text-zinc-100">
      {/* Nav */}
      <header className="sticky top-0 z-40 border-b border-zinc-800 bg-[#09090b]/80 backdrop-blur">
        <div className="mx-auto flex max-w-6xl items-center justify-between px-6 py-4">
          <div className="flex items-center gap-3">
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-violet-600 font-bold text-white">
              A
            </div>
            <span className="text-sm font-semibold tracking-tight">
              Astra <span className="font-normal text-zinc-400">v1</span>
            </span>
            <span className="hidden rounded-full border border-zinc-800 bg-zinc-900 px-2.5 py-0.5 text-xs font-medium text-zinc-400 sm:inline-flex">
              Luau • Roblox • Executor
            </span>
          </div>
          <nav className="flex items-center gap-2">
            <Link
              href="https://github.com/Kira762/astra-version-1"
              target="_blank"
              className="rounded-full border border-zinc-800 px-4 py-2 text-sm font-medium text-zinc-300 hover:bg-zinc-900 hover:text-white transition"
            >
              GitHub
            </Link>
            <Link
              href="#install"
              className="rounded-full bg-white px-4 py-2 text-sm font-semibold text-black hover:bg-zinc-200 transition"
            >
              Get started
            </Link>
          </nav>
        </div>
      </header>

      {/* Hero */}
      <section className="mx-auto max-w-6xl px-6 pb-12 pt-16 sm:pt-24">
        <div className="inline-flex items-center gap-2 rounded-full border border-violet-500/30 bg-violet-500/10 px-3 py-1 text-xs font-medium text-violet-300">
          <span className="h-2 w-2 rounded-full bg-violet-400 animate-pulse" />
          Vercel Root Directory = <code className="rounded bg-violet-500/20 px-1.5 py-0.5 text-violet-200">website</code> — Luau source never deployed
        </div>

        <h1 className="mt-6 max-w-3xl text-4xl font-bold tracking-tight sm:text-6xl">
          One loader line.
          <br />
          <span className="bg-gradient-to-r from-violet-400 to-indigo-400 bg-clip-text text-transparent">
            A whole interface system.
          </span>
        </h1>
        <p className="mt-6 max-w-2xl text-lg leading-7 text-zinc-400">
          Astra is a Roblox/Luau UI library for executor scripts:{" "}
          <code className="rounded bg-zinc-900 px-1.5 py-0.5 text-sm text-zinc-200">
            CreateWindow
          </code>{" "}
          and tabs full of elements — buttons, toggles, sliders, dropdowns,
          inputs, stats, themes, 7 icon packs, saved configs and staged startup.
        </p>

        <div className="mt-8 flex flex-wrap gap-3">
          <Link
            href="#install"
            className="inline-flex items-center gap-2 rounded-full bg-violet-600 px-6 py-3 text-sm font-semibold text-white hover:bg-violet-500 transition"
          >
            Install the loader →
          </Link>
          <Link
            href="https://github.com/Kira762/astra-version-1/blob/main/USAGE.md"
            target="_blank"
            className="inline-flex items-center gap-2 rounded-full border border-zinc-800 bg-zinc-900 px-6 py-3 text-sm font-medium text-zinc-200 hover:bg-zinc-800 transition"
          >
            Read USAGE.md
          </Link>
          <Link
            href="https://github.com/Kira762/astra-version-1/blob/main/example.client.luau"
            target="_blank"
            className="inline-flex items-center gap-2 rounded-full border border-zinc-800 px-6 py-3 text-sm font-medium text-zinc-300 hover:bg-zinc-900 transition"
          >
            example.client.luau
          </Link>
        </div>

        {/* Code hero */}
        <div className="mt-12 grid gap-6 lg:grid-cols-[1.7fr_1fr]">
          <div className="overflow-hidden rounded-2xl border border-zinc-800 bg-zinc-900">
            <div className="flex items-center justify-between border-b border-zinc-800 bg-zinc-900/50 px-4 py-3">
              <div className="flex items-center gap-1.5">
                <span className="h-3 w-3 rounded-full bg-red-500/80" />
                <span className="h-3 w-3 rounded-full bg-yellow-500/80" />
                <span className="h-3 w-3 rounded-full bg-green-500/80" />
              </div>
              <span className="text-xs font-medium text-zinc-500">
                loader.luau
              </span>
              <span className="text-xs text-zinc-600">Luau</span>
            </div>
            <pre className="overflow-x-auto p-6 text-sm leading-6">
              <code className="font-mono text-zinc-300">
                <span className="text-zinc-500">-- one line to load</span>
                {"\n"}
                <span className="text-violet-400">local</span> Astra ={" "}
                <span className="text-emerald-400">loadstring</span>(
                <span className="text-emerald-400">game</span>:
                <span className="text-violet-300">HttpGet</span>(
                <span className="text-amber-300">
                  &quot;https://raw.githubusercontent.com/Kira762/astra-version-1/main/version-1.luau&quot;
                </span>
                ))()
                {"\n\n"}
                <span className="text-violet-400">local</span> window = Astra:
                <span className="text-violet-300">CreateWindow</span>({"{"}{" "}
                <span className="text-zinc-400">name</span> ={" "}
                <span className="text-amber-300">&quot;Example Hub&quot;</span>,{" "}
                <span className="text-zinc-400">subtitle</span> ={" "}
                <span className="text-amber-300">&quot;v1.0&quot;</span> {"}"})
                {"\n"}
                <span className="text-violet-400">local</span> tab = window:
                <span className="text-violet-300">CreateTab</span>({"{"}{" "}
                <span className="text-zinc-400">name</span> ={" "}
                <span className="text-amber-300">&quot;Home&quot;</span>,{" "}
                <span className="text-zinc-400">icon</span> ={" "}
                <span className="text-amber-300">&quot;house&quot;</span> {"}"})
                {"\n\n"}
                tab:<span className="text-violet-300">CreateButton</span>({"{"}
                {"\n"}
                {"    "}<span className="text-zinc-400">name</span> ={" "}
                <span className="text-amber-300">&quot;Say hello&quot;</span>,
                {"\n"}
                {"    "}<span className="text-zinc-400">icon</span> ={" "}
                <span className="text-amber-300">&quot;play&quot;</span>,
                {"\n"}
                {"    "}<span className="text-zinc-400">callback</span> ={" "}
                <span className="text-violet-400">function</span>() window:
                <span className="text-violet-300">Notify</span>({"{"}{" "}
                <span className="text-zinc-400">title</span> ={" "}
                <span className="text-amber-300">&quot;Hello&quot;</span> {"}"}){" "}
                <span className="text-violet-400">end</span>
                {"\n"}
                {"}"}){"\n"}tab:<span className="text-violet-300">Select</span>()
              </code>
            </pre>
          </div>

          <div className="flex flex-col gap-4">
            <div className="rounded-2xl border border-zinc-800 bg-zinc-900 p-6">
              <h3 className="text-sm font-semibold text-white">
                Monorepo safe
              </h3>
              <p className="mt-2 text-sm leading-6 text-zinc-400">
                Vercel&apos;s{" "}
                <code className="rounded bg-zinc-800 px-1 py-0.5 text-zinc-200">
                  Root Directory = website
                </code>{" "}
                means{" "}
                <code className="text-zinc-300">components/</code>,{" "}
                <code className="text-zinc-300">elements/</code>,{" "}
                <code className="text-zinc-300">version-1.luau</code> are
                outside the upload. No Luau is ever deployed.
              </p>
              <div className="mt-4 rounded-xl bg-zinc-950 p-4 font-mono text-xs leading-5 text-zinc-400">
                <div className="text-zinc-500"># website/vercel.json</div>
                <div>
                  <span className="text-violet-400">&quot;ignoreCommand&quot;</span>:{" "}
                  <span className="text-amber-300">
                    &quot;git diff --quiet HEAD^ HEAD -- ./&quot;
                  </span>
                </div>
                <div className="mt-2 text-zinc-500">
                  skips build if only library changed
                </div>
              </div>
            </div>

            <div className="rounded-2xl border border-emerald-900/50 bg-emerald-950/20 p-6">
              <h3 className="flex items-center gap-2 text-sm font-semibold text-emerald-300">
                <span className="h-2 w-2 rounded-full bg-emerald-500" /> Deploy
                ready
              </h3>
              <p className="mt-2 text-sm leading-6 text-zinc-400">
                This site is a Next.js placeholder. Replace it with your real
                design — pushes that only touch Luau files won&apos;t redeploy.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Features */}
      <section className="border-t border-zinc-800 bg-zinc-900/50">
        <div className="mx-auto max-w-6xl px-6 py-16">
          <h2 className="text-2xl font-bold tracking-tight">
            What&apos;s in the box
          </h2>
          <div className="mt-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {[
              {
                t: "Window",
                d: "Topbar / sidebar / collapsed-sidebar, draggable, minimise-to-capsule, notifications, popups, search, profile card.",
              },
              {
                t: "Elements",
                d: "Section, Text, Button, Toggle, Slider, Dropdown (multi + searchable), Input, Stat, Group, Collapsible, Changelog.",
              },
              {
                t: "State",
                d: "Flags with auto save/load, named configs, forgetState opt-out, writable-storage persistence.",
              },
              {
                t: "Look",
                d: "10 themes + custom tables, 7 icon packs (lucide, material, tabler, phosphor, heroicons, feather, remix).",
              },
            ].map((f) => (
              <div
                key={f.t}
                className="rounded-2xl border border-zinc-800 bg-zinc-900 p-6"
              >
                <h3 className="text-sm font-semibold text-white">{f.t}</h3>
                <p className="mt-2 text-sm leading-6 text-zinc-400">{f.d}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Install */}
      <section
        id="install"
        className="mx-auto max-w-6xl px-6 py-16 scroll-mt-20"
      >
        <div className="grid gap-8 lg:grid-cols-2">
          <div>
            <h2 className="text-2xl font-bold tracking-tight">
              Install &amp; use
            </h2>
            <p className="mt-3 text-zinc-400 leading-7">
              Always load the published bundle{" "}
              <code className="rounded bg-zinc-900 px-1.5 py-0.5 text-sm text-zinc-200">
                version-1.luau
              </code>
              . The modular folders are source, not a runtime entry point.
              Studio/Rojo uses{" "}
              <code className="rounded bg-zinc-900 px-1.5 py-0.5 text-sm text-zinc-200">
                require(ReplicatedStorage.Astra)
              </code>
              .
            </p>
            <div className="mt-6 flex flex-wrap gap-3">
              <Link
                href="https://github.com/Kira762/astra-version-1/blob/main/USAGE.md"
                target="_blank"
                className="rounded-full bg-white px-5 py-2.5 text-sm font-semibold text-black hover:bg-zinc-200 transition"
              >
                Read USAGE.md
              </Link>
              <Link
                href="https://github.com/Kira762/astra-version-1/blob/main/MODULES.md"
                target="_blank"
                className="rounded-full border border-zinc-800 bg-zinc-900 px-5 py-2.5 text-sm font-medium text-zinc-200 hover:bg-zinc-800 transition"
              >
                MODULES.md
              </Link>
            </div>
            <div className="mt-6 rounded-xl border border-zinc-800 bg-zinc-900 p-4">
              <div className="text-xs font-semibold tracking-widest text-zinc-500">
                AGENT SKILL
              </div>
              <div className="mt-2 font-mono text-sm text-zinc-300">
                npx skills add Kira762/astra-version-1
              </div>
              <p className="mt-2 text-xs leading-5 text-zinc-500">
                Teaches coding agents the Astra API so they stop guessing.
                Install with{" "}
                <code className="rounded bg-zinc-800 px-1 text-zinc-300">
                  -a claude-code -a cursor -y
                </code>{" "}
                for CI.
              </p>
            </div>
          </div>

          <div className="space-y-4">
            <div className="rounded-2xl border border-zinc-800 bg-zinc-900 p-6">
              <div className="text-xs font-semibold tracking-widest text-zinc-500">
                REQUIREMENTS
              </div>
              <ul className="mt-3 space-y-2 text-sm text-zinc-400">
                <li className="flex gap-2">
                  <span className="text-emerald-400">✓</span> Runtime must
                  provide <code className="text-zinc-300">loadstring</code>{" "}
                  (executors do, plain Studio does not)
                </li>
                <li className="flex gap-2">
                  <span className="text-emerald-400">✓</span>{" "}
                  <code className="text-zinc-300">HttpService</code> requests
                  enabled
                </li>
                <li className="flex gap-2">
                  <span className="text-zinc-600">•</span> Luau CLI for local
                  checks: <code className="text-zinc-300">luau-compile</code>
                </li>
              </ul>
            </div>

            <div className="rounded-2xl border border-zinc-800 bg-zinc-900 p-6">
              <div className="text-xs font-semibold tracking-widest text-zinc-500">
                DOCS
              </div>
              <div className="mt-3 grid grid-cols-2 gap-2 text-sm">
                {[
                  ["USAGE.md", "Author guide"],
                  ["MODULES.md", "Module reference"],
                  ["CHANGELOG.md", "Behaviour changes"],
                  ["example.client.luau", "Every element"],
                ].map(([f, d]) => (
                  <Link
                    key={f}
                    href={`https://github.com/Kira762/astra-version-1/blob/main/${f}`}
                    target="_blank"
                    className="rounded-xl border border-zinc-800 bg-zinc-950 px-4 py-3 hover:bg-zinc-900 transition"
                  >
                    <div className="font-medium text-zinc-200">{f}</div>
                    <div className="text-xs text-zinc-500">{d}</div>
                  </Link>
                ))}
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Repository layout */}
      <section className="border-t border-zinc-800 bg-zinc-950">
        <div className="mx-auto max-w-6xl px-6 py-16">
          <h2 className="text-xl font-bold tracking-tight">
            Repository layout
          </h2>
          <p className="mt-2 max-w-2xl text-sm leading-6 text-zinc-400">
            This repo is a monorepo: the Luau library at the root, your website
            in{" "}
            <code className="rounded bg-zinc-900 px-1 py-0.5 text-zinc-200">
              website/
            </code>
            . Vercel only sees <code>website/</code> when Root Directory is
            set.
          </p>
          <div className="mt-6 overflow-hidden rounded-2xl border border-zinc-800 bg-zinc-900">
            <pre className="overflow-x-auto p-6 font-mono text-xs leading-6 text-zinc-300">
              <span className="text-violet-400">website/</span>{" "}
              <span className="text-zinc-500">
                ← Vercel Root Directory (Next.js app lives here)
              </span>
              {"\n"}
              {"  "}app/page.tsx &nbsp;&nbsp;&nbsp;&nbsp; your pages
              {"\n"}
              {"  "}vercel.json &nbsp;&nbsp;&nbsp;&nbsp; ignoreCommand: skip if
              website/ unchanged
              {"\n"}
              {"  "}package.json &nbsp;&nbsp;&nbsp; next, react, tailwind
              {"\n"}
              <span className="text-zinc-600">
                components/ &nbsp;&nbsp;&nbsp; Luau window shell (ignored)
              </span>
              {"\n"}
              <span className="text-zinc-600">
                elements/ &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; Luau elements
                (ignored)
              </span>
              {"\n"}
              <span className="text-zinc-600">
                version-1.luau &nbsp;&nbsp; generated bundle (ignored)
              </span>
              {"\n"}
              <span className="text-zinc-600">skills/ &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; agent skill (ignored)</span>
            </pre>
          </div>
          <div className="mt-6 rounded-xl border border-amber-900/30 bg-amber-950/20 p-4 text-sm leading-6 text-amber-200/80">
            <strong className="text-amber-300">Vercel setup:</strong> Dashboard
            → Project → Settings → General → Root Directory →{" "}
            <code className="rounded bg-amber-950 px-1.5 py-0.5 text-amber-200">
              website
            </code>{" "}
            → Save &amp; redeploy. That&apos;s it — no extra config needed.
            The root{" "}
            <code className="rounded bg-zinc-900 px-1 py-0.5 text-zinc-300">
              .vercelignore
            </code>{" "}
            and{" "}
            <code className="rounded bg-zinc-900 px-1 py-0.5 text-zinc-300">
              vercel.json
            </code>{" "}
            are fallbacks if you deploy from repo root.
          </div>
        </div>
      </section>

      <footer className="border-t border-zinc-800">
        <div className="mx-auto flex max-w-6xl flex-col gap-2 px-6 py-8 text-sm text-zinc-500 sm:flex-row sm:items-center sm:justify-between">
          <div>
            Astra v1 • MIT •{" "}
            <Link
              href="https://github.com/Kira762/astra-version-1"
              className="text-zinc-300 hover:text-white"
            >
              Kira762/astra-version-1
            </Link>
          </div>
          <div className="text-xs">
            Built for Luau executors • Rojo compatible • Deployed from{" "}
            <code className="rounded bg-zinc-900 px-1 py-0.5 text-zinc-400">
              website/
            </code>
          </div>
        </div>
      </footer>
    </div>
  );
}
