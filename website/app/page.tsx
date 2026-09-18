import Link from "next/link";

// Astra Usage Guide — full USAGE.md as an interactive docs site
// Path-safety note: this site lives in /website, which is outside the Rojo tree
// (default.project.json / wax.project.json) and outside the bundle GENERATION
// TREE (scripts/generate_bundle.js). All Luau `script.Parent` requires are
// DataModel-relative, not filesystem-relative, so adding website/ cannot break them.

const TOC = [
  { id: "load", label: "Load the library" },
  { id: "window", label: "Build a window" },
  { id: "saving", label: "Saving & flags" },
  { id: "api-window", label: "Window API" },
  { id: "tabs", label: "Tabs & groups" },
  { id: "elements", label: "Elements" },
  { id: "button", label: "— Button" },
  { id: "toggle", label: "— Toggle" },
  { id: "slider", label: "— Slider" },
  { id: "dropdown", label: "— Dropdown" },
  { id: "input", label: "— Input" },
  { id: "stat", label: "— Stat" },
  { id: "text", label: "— Text / Divider / Group" },
  { id: "changelog", label: "— Changelog element" },
  { id: "settings", label: "Built-in Settings" },
  { id: "themes", label: "Themes" },
  { id: "icons", label: "Icons (7 packs)" },
  { id: "motion", label: "Motion" },
  { id: "locale", label: "Localisation" },
  { id: "startup", label: "Startup performance" },
  { id: "collapsible", label: "Collapsible Group" },
  { id: "props", label: "CreateWindow props" },
  { id: "repo", label: "Monorepo & Vercel" },
  { id: "verify", label: "Path verification" },
];

function Code({ children, title }: { children: string; title?: string }) {
  return (
    <div className="overflow-hidden rounded-xl border border-zinc-800 bg-zinc-900">
      {title && (
        <div className="flex items-center justify-between border-b border-zinc-800 bg-zinc-900 px-4 py-2">
          <span className="text-xs font-medium text-zinc-500">{title}</span>
          <span className="text-xs text-zinc-600">Luau</span>
        </div>
      )}
      <pre className="overflow-x-auto p-4 text-[13px] leading-6">
        <code className="font-mono text-zinc-300 whitespace-pre">{children}</code>
      </pre>
    </div>
  );
}

function Badge({ children }: { children: React.ReactNode }) {
  return (
    <span className="inline-flex items-center rounded-full border border-zinc-800 bg-zinc-900 px-2.5 py-0.5 text-xs font-medium text-zinc-400">
      {children}
    </span>
  );
}

export default function Home() {
  return (
    <div className="min-h-screen bg-[#09090b] text-zinc-100">
      {/* Top nav */}
      <header className="sticky top-0 z-40 border-b border-zinc-800 bg-[#09090b]/80 backdrop-blur">
        <div className="mx-auto flex max-w-[1400px] items-center justify-between px-6 py-3">
          <div className="flex items-center gap-3">
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-violet-600 font-bold text-white">A</div>
            <div>
              <div className="text-sm font-semibold tracking-tight leading-none">Astra <span className="font-normal text-zinc-400">v1</span> <span className="ml-2 hidden sm:inline text-xs font-normal text-zinc-500">— Usage Guide</span></div>
              <div className="text-xs text-zinc-500 hidden sm:block">Luau interface library for executor scripts</div>
            </div>
          </div>
          <nav className="flex items-center gap-2">
            <Link href="https://github.com/Kira762/astra-version-1/blob/main/USAGE.md" target="_blank" className="hidden sm:inline-flex rounded-full border border-zinc-800 px-4 py-2 text-sm font-medium text-zinc-300 hover:bg-zinc-900 transition">USAGE.md</Link>
            <Link href="https://github.com/Kira762/astra-version-1" target="_blank" className="rounded-full border border-zinc-800 px-4 py-2 text-sm font-medium text-zinc-300 hover:bg-zinc-900 transition">GitHub</Link>
            <Link href="#load" className="rounded-full bg-white px-4 py-2 text-sm font-semibold text-black hover:bg-zinc-200 transition">Start</Link>
          </nav>
        </div>
      </header>

      <div className="mx-auto max-w-[1400px] px-6">
        <div className="flex gap-8">
          {/* Sidebar TOC — desktop */}
          <aside className="hidden lg:block sticky top-[57px] h-[calc(100vh-57px)] w-[220px] shrink-0 overflow-y-auto py-8 pr-4">
            <div className="text-xs font-semibold tracking-widest text-zinc-500 mb-3">CONTENTS</div>
            <nav className="space-y-1">
              {TOC.map((i) => (
                <a key={i.id} href={`#${i.id}`} className={`block rounded-lg px-3 py-1.5 text-sm leading-5 hover:bg-zinc-900 hover:text-white transition ${i.label.startsWith("—") ? "ml-3 text-zinc-500 text-[13px]" : "text-zinc-400"}`}>
                  {i.label}
                </a>
              ))}
            </nav>
            <div className="mt-6 rounded-xl border border-emerald-900/30 bg-emerald-950/20 p-3">
              <div className="text-xs font-semibold text-emerald-300">✓ Paths verified</div>
              <p className="mt-1 text-xs leading-5 text-zinc-400">website/ is outside Rojo tree & bundle TREE. All <code className="text-zinc-300">script.Parent</code> requires still resolve. See <a href="#verify" className="underline text-emerald-300">verification</a>.</p>
            </div>
            <div className="mt-4 space-y-2 text-xs text-zinc-500">
              <Link href="https://github.com/Kira762/astra-version-1/blob/main/example.client.luau" target="_blank" className="block hover:text-zinc-300">→ example.client.luau</Link>
              <Link href="https://github.com/Kira762/astra-version-1/blob/main/MODULES.md" target="_blank" className="block hover:text-zinc-300">→ MODULES.md</Link>
              <Link href="https://github.com/Kira762/astra-version-1/blob/main/CHANGELOG.md" target="_blank" className="block hover:text-zinc-300">→ CHANGELOG.md</Link>
            </div>
          </aside>

          {/* Main */}
          <main className="min-w-0 flex-1 py-8 lg:py-10">
            {/* Hero */}
            <div className="mb-10">
              <div className="inline-flex items-center gap-2 rounded-full border border-violet-500/30 bg-violet-500/10 px-3 py-1 text-xs font-medium text-violet-300">
                <span className="h-2 w-2 rounded-full bg-violet-400 animate-pulse" />
                USAGE GUIDE • Deployed from <code className="rounded bg-violet-500/20 px-1.5 py-0.5 text-violet-200">website/</code> — Luau never deployed
              </div>
              <h1 className="mt-4 text-4xl font-bold tracking-tight sm:text-5xl">Astra v1 — Usage Guide</h1>
              <p className="mt-3 max-w-3xl text-lg leading-7 text-zinc-400">Load Astra and build your first window in a few lines. One loader line, one <code className="rounded bg-zinc-900 px-1.5 py-0.5 text-sm text-zinc-200">CreateWindow</code> call, tabs full of elements — with built-in saving, themes, 7 icon packs and staged startup. This site is the human version of <code className="rounded bg-zinc-900 px-1.5 py-0.5 text-sm text-zinc-200">USAGE.md</code>.</p>
              <div className="mt-6 flex flex-wrap gap-2">
                <Badge>Luau • Roblox • Executor</Badge>
                <Badge>7 icon packs</Badge>
                <Badge>10 themes + custom</Badge>
                <Badge>Auto save/load flags</Badge>
                <Badge>Staged startup</Badge>
              </div>
            </div>

            {/* Load */}
            <section id="load" className="scroll-mt-20 mb-12">
              <h2 className="text-2xl font-bold tracking-tight">Load the library</h2>
              <p className="mt-2 text-zinc-400 leading-7">One loader, one line — this is what <code className="rounded bg-zinc-900 px-1 py-0.5 text-sm text-zinc-200">example.client.luau</code> does:</p>
              <div className="mt-4">
                <Code title="loader.luau">{`local Astra = loadstring(game:HttpGet("https://raw.githubusercontent.com/Kira762/astra-version-1/main/version-1.luau"))()`}</Code>
              </div>
              <div className="mt-4 grid gap-4 sm:grid-cols-3">
                <div className="rounded-xl border border-zinc-800 bg-zinc-900 p-4">
                  <div className="text-xs font-semibold tracking-widest text-zinc-500">URL IS RAW BUNDLE</div>
                  <p className="mt-2 text-sm leading-6 text-zinc-400">Point at the published <code className="text-zinc-200">version-1.luau</code> bundle. It’s a generated artifact — never load the modular tree. Needs <code className="text-zinc-300">HttpService</code> enabled.</p>
                </div>
                <div className="rounded-xl border border-zinc-800 bg-zinc-900 p-4">
                  <div className="text-xs font-semibold tracking-widest text-zinc-500">NEEDS loadstring</div>
                  <p className="mt-2 text-sm leading-6 text-zinc-400">Executors provide <code className="text-zinc-300">loadstring</code>; plain Studio does not. In Studio/Rojo use <code className="text-zinc-300">require(ReplicatedStorage.Astra)</code>.</p>
                </div>
                <div className="rounded-xl border border-zinc-800 bg-zinc-900 p-4">
                  <div className="text-xs font-semibold tracking-widest text-zinc-500">TRAILING ()</div>
                  <p className="mt-2 text-sm leading-6 text-zinc-400"><code className="text-zinc-300">loadstring(text)</code> only compiles. The trailing <code className="text-zinc-300">()</code> runs it and returns the table. Without it you get <code className="text-zinc-300">attempt to index a function value</code>.</p>
                </div>
              </div>
              <div className="mt-4 rounded-xl border border-amber-900/30 bg-amber-950/20 p-4">
                <div className="text-sm font-semibold text-amber-300">What a failed load looks like</div>
                <Code title="error">{`rAnDoMcHuNkNaMe:1: attempt to call a nil value
Stack Begin
Script 'LocalScript', Line 1
Stack End`}</Code>
                <p className="mt-3 text-sm leading-6 text-amber-200/70">That message is about the <em>loader</em>, not Astra: the random name is the executor’s chunk, Line 1 is the call, “nil value” means the fetched text never compiled. Check:</p>
                <ol className="mt-2 list-decimal space-y-1 pl-5 text-sm leading-6 text-zinc-400">
                  <li><code className="text-zinc-300">print(game:HttpGet(url):sub(1,120))</code> — 404 HTML or rate-limit page never compiles (private repo / wrong branch).</li>
                  <li>Real syntax error — run <code className="text-zinc-300">sh scripts/check_syntax.sh</code> then <code className="text-zinc-300">node scripts/generate_bundle.js</code>.</li>
                </ol>
              </div>
            </section>

            {/* Build a window */}
            <section id="window" className="scroll-mt-20 mb-12">
              <h2 className="text-2xl font-bold tracking-tight">Build a window</h2>
              <p className="mt-2 text-zinc-400 leading-7">A window is the entry point. Create one, add a tab, fill it with elements. The first visible tab opens on its own.</p>
              <div className="mt-4">
                <Code title="window.luau">{`local window = Astra:CreateWindow({
    name = "Example Hub",
    subtitle = "Astra",
})

local tab = window:CreateTab({ name = "Home", icon = "house" })

tab:CreateButton({
    name = "Say hello",
    callback = function()
        window:Notify({ title = "Hello", content = "Your first element works." })
    end,
})

tab:CreateToggle({
    name = "Auto Sprint",
    callback = function(value)
        print("Auto Sprint:", value)
    end,
})`}</Code>
              </div>
              <p className="mt-3 text-sm text-zinc-500">Layout is built-in — switch it anytime in <strong className="text-zinc-300">Settings → Appearance → Bar Layout</strong>.</p>
            </section>

            {/* Saving */}
            <section id="saving" className="scroll-mt-20 mb-12">
              <h2 className="text-2xl font-bold tracking-tight">Built-in saving preferences</h2>
              <p className="mt-2 text-zinc-400 leading-7">No <code className="rounded bg-zinc-900 px-1 py-0.5 text-sm text-zinc-200">configuration</code> table needed in normal use. Open <strong className="text-zinc-200">Settings → Persistence</strong> to change <strong className="text-zinc-200">Auto Save Config</strong> and <strong className="text-zinc-200">Auto Load Config</strong>. Both default to on.</p>
              <ul className="mt-3 list-disc space-y-1 pl-5 text-sm leading-6 text-zinc-400">
                <li>Auto Save saves supported control values after a short coalescing delay.</li>
                <li>Auto Load restores the default configuration on next startup; turning it on doesn’t replace current session.</li>
                <li>Turning either off doesn’t delete saved configs.</li>
                <li>File persistence requires a runtime with writable storage.</li>
              </ul>
              <div className="mt-4">
                <Code title="flags.luau">{`-- any element with a flag participates in Save/Load
tab:CreateToggle({ name = "Auto Sprint", flag = "autoSprint", value = true })

window:Set("autoSprint", false)
print(window:Get("autoSprint"))
print(window.Flags.autoSprint)

window:Save("Slot2")
window:Load("Slot2")
window:ListConfigs()
window:DeleteConfig("Slot2")`}</Code>
              </div>
              <p className="mt-3 text-sm text-zinc-500">Elements with <code className="text-zinc-300">forgetState = true</code> are excluded. Use stable, unique flags for reliable restores.</p>
            </section>

            {/* Window API */}
            <section id="api-window" className="scroll-mt-20 mb-12">
              <h2 className="text-2xl font-bold tracking-tight">Window — every method</h2>
              <div className="mt-4 overflow-hidden rounded-xl border border-zinc-800">
                <div className="overflow-x-auto">
                  <table className="w-full text-sm">
                    <thead className="bg-zinc-900 text-left text-xs tracking-widest text-zinc-500">
                      <tr><th className="px-4 py-3">Method</th><th className="px-4 py-3">Description</th></tr>
                    </thead>
                    <tbody className="divide-y divide-zinc-800 bg-zinc-950 text-zinc-300">
                      {[
                        ["window:CreateTab({ name, icon })", "Create a tab. Returns Tab."],
                        ["window:CreateSection({ name, icon })", "Top-level section — TabSection."],
                        ["window:Notify({ title, content, icon, duration })", "Classic notification (entrance queue)."],
                        ["window:Popup({ title, content, boxes, options })", "Modal popup. Returns Popup:Close()."],
                        ["window:Navigate(tab)", "Select tab by name or object."],
                        ["window:Show() / Hide() / ToggleHide()", "Visibility."],
                        ["window:ToggleMinimise()", "Collapse/expand the rail."],
                        ["window:Close()", "Animated close (confirm popup); unloads when done."],
                        ["window:Save(name?) / Load(name?)", "Save/load flags."],
                        ["window:ListConfigs()", "Array of saved config names."],
                        ["window:DeleteConfig(name)", "Delete a saved config."],
                        ["window:Get(flag) / Set(flag, value)", "Read/write by flag."],
                        ["window:ChangeTheme(theme)", "Swap theme at runtime."],
                        ["window:SetLocale(id) / SetTranslator(fn) / RegisterTranslations(t)", "Localisation."],
                        ["window:ResolveIcon(value, pack?)", "Icon name → asset id."],
                        ["window:GetPath()", "Returns (folder, file) persistence path."],
                        ["window:Unload()", "Destroy the window."],
                        ["window.Flags", "Table of every flag’s current value."],
                      ].map(([k, v]) => (
                        <tr key={k}><td className="px-4 py-2.5 font-mono text-xs text-violet-300">{k}</td><td className="px-4 py-2.5 text-zinc-400">{v}</td></tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
              <div className="mt-4">
                <Code title="window:SetProfile">{`window:SetProfile({
    subtitle = "Beta tester",              -- replaces @username line
    key = "ASTRA-XXXX-XXXX",               -- masked until Reveal profile details
    tier = "PREMIUM",                      -- header pill word
    whitelist = { status = "Active", daysLeft = 14 },  -- or expiresAt = os.time() + n
})
-- nil subtitle falls back to @username; omitted fields show —; rows stay masked until Reveal.`}</Code>
              </div>
              <p className="mt-3 text-sm text-zinc-500">Popup: <code className="text-zinc-300">options = {"{ { text = \"Cancel\" }, { text = \"Confirm\", style = \"primary|danger|neutral\", callback = fn } }"}</code>. Also: <code className="text-zinc-300">Create / Connect / Disconnect / DestroySubtree / CreateGlow / StyleElementBody / SaveSettings / SetProfile</code> helpers.</p>
            </section>

            {/* Tabs */}
            <section id="tabs" className="scroll-mt-20 mb-12">
              <h2 className="text-2xl font-bold tracking-tight">Tabs and groups</h2>
              <Code title="tabs.luau">{`local tab = window:CreateTab({ name = "Home", icon = "house" })
tab:Select()
tab:Deselect()
tab:Remove()

local row = tab:CreateGroup()                       -- horizontal row
local col = row:CreateGroup({ direction = "column" }) -- nested column
col:CreateToggle({ name = "Left 1" })`}</Code>
              <p className="mt-3 text-sm leading-6 text-zinc-400">Tab methods: <code className="text-zinc-300">CreateButton, CreateToggle, CreateSlider, CreateDropdown, CreateInput, CreateStat, CreateSection, CreateText, CreateDivider, CreateGroup, CreateCollapsibleGroup</code>. Groups support row/column (auto-column if non-compact children). Collapsible Groups only on a tab.</p>
            </section>

            {/* Elements intro */}
            <section id="elements" className="scroll-mt-20 mb-8">
              <h2 className="text-2xl font-bold tracking-tight">Elements</h2>
              <p className="mt-2 text-zinc-400 leading-7">Every element supports <code className="rounded bg-zinc-900 px-1 py-0.5 text-sm text-zinc-200">Moveable</code> (<code className="text-zinc-300">:MoveTo, :MoveToTop, :MoveToBottom, :MoveUp, :MoveDown</code>) and most support <code className="rounded bg-zinc-900 px-1 py-0.5 text-sm text-zinc-200">Lockable</code> (<code className="text-zinc-300">:Lock, :Unlock, :IsLocked</code>). Most props accept <code className="text-zinc-300">icon</code>.</p>
              <Code title="elements quick">{`tab:CreateButton({ name = "Click Me", icon = "play", callback = function() end })
tab:CreateSlider({ name = "Sensitivity", range = { 1, 10 }, value = 5, suffix = "x", minimal = true, callback = function(v, dragging) end })
tab:CreateDropdown({ name = "Preset", options = { "Low", "Medium", "High" }, value = "Medium", multiSelect = true, placeholder = "Pick items", callback = function(s) end })
tab:CreateInput({ name = "Name", placeholder = "Type here", numeric = true, clearOnFocus = true, callback = function(t) end })`}</Code>
            </section>

            {/* Individual elements */}
            <div className="space-y-10">
              <section id="button" className="scroll-mt-20 rounded-2xl border border-zinc-800 bg-zinc-900/50 p-6">
                <h3 className="text-lg font-semibold">Button</h3>
                <p className="mt-2 text-sm leading-6 text-zinc-400">Built-in tap glyph (phosphor <code className="text-zinc-300">hand-tap</code>) on the right. Tapping the card or the glyph fires <code className="text-zinc-300">callback</code> and pulses.</p>
                <div className="mt-4">
                  <Code>{`tab:CreateButton({ name = "Click Me", icon = "play", callback = function() print("clicked") end })
-- hide or replace glyph:
tab:CreateButton({ name = "Silent", tapIcon = false, callback = function() end })
tab:CreateButton({ name = "Refresh", tapIcon = "refresh-cw", callback = function() end })`}</Code>
                </div>
              </section>

              <section id="toggle" className="scroll-mt-20 rounded-2xl border border-zinc-800 bg-zinc-900/50 p-6">
                <h3 className="text-lg font-semibold">Toggle</h3>
                <Code>{`local t = tab:CreateToggle({ name = "Auto Sprint", flag = "autoSprint", value = true, callback = function(on) print(on) end })
t:Set(false)          -- fires callback
t:Set(false, true)    -- silent`}</Code>
              </section>

              <section id="slider" className="scroll-mt-20 rounded-2xl border border-zinc-800 bg-zinc-900/50 p-6">
                <h3 className="text-lg font-semibold">Slider</h3>
                <Code>{`tab:CreateSlider({
    name = "Sensitivity", flag = "sens",
    range = { 1, 10 }, value = 5, increment = 1, suffix = "x",
    minimal = true,
    callback = function(value, dragging) end,
})`}</Code>
              </section>

              <section id="dropdown" className="scroll-mt-20 rounded-2xl border border-zinc-800 bg-zinc-900/50 p-6">
                <h3 className="text-lg font-semibold">Dropdown</h3>
                <Code>{`local d = tab:CreateDropdown({
    name = "Preset", options = { "Low", "Medium", "High" }, value = "Medium",
    multiSelect = true, placeholder = "Pick items",
    callback = function(selected) end,
})
d:Refresh({ "A", "B" })
d:Add("C")
d:Remove("A")`}</Code>
              </section>

              <section id="input" className="scroll-mt-20 rounded-2xl border border-zinc-800 bg-zinc-900/50 p-6">
                <h3 className="text-lg font-semibold">Input</h3>
                <Code>{`tab:CreateInput({
    name = "Name", placeholder = "Type here",
    value = "Initial", numeric = true, clearOnFocus = true,
    callback = function(text) end,
})`}</Code>
              </section>

              <section id="stat" className="scroll-mt-20 rounded-2xl border border-zinc-800 bg-zinc-900/50 p-6">
                <h3 className="text-lg font-semibold">Stat</h3>
                <Code>{`local s = tab:CreateStat({ name = "Kills", value = 128, prefix = "", suffix = " kills" })
s:Set(200)
s:ResetBaseline(0)
-- text mode:
local theme = tab:CreateStat({ name = "Current theme", value = "Default", letter = false })
theme:SetText("Emerald")  -- reads "Emerald", not "E"`}</Code>
                <p className="mt-3 text-xs leading-5 text-zinc-500">Props: <code className="text-zinc-300">display (value|change), compact, changeMode (percentage|delta), changeBaseline (previous|initial), numberEasing, letter</code>. String values render as badge by default; <code className="text-zinc-300">letter=false</code> reads full text.</p>
              </section>

              <section id="text" className="scroll-mt-20 rounded-2xl border border-zinc-800 bg-zinc-900/50 p-6">
                <h3 className="text-lg font-semibold">Text / Divider / Group</h3>
                <Code>{`local x = tab:CreateText({ name = "Title", text = "Body text", icon = "info" })
x:Set("New body") x:SetTitle("New title")

tab:CreateDivider()  tab:CreateDivider({ text = "or" })  tab:CreateDivider({ line = false, spacing = 8 })

local row = tab:CreateGroup()
local col = row:CreateGroup({ direction = "column" })
col:CreateToggle({ name = "Left 1" })`}</Code>
              </section>

              <section id="changelog" className="scroll-mt-20 rounded-2xl border border-zinc-800 bg-zinc-900/50 p-6">
                <h3 className="text-lg font-semibold">Changelog element</h3>
                <p className="mt-2 text-sm leading-6 text-zinc-400">Release history as a standalone element. Keep history in its own file (see <code className="text-zinc-300">changelog.example.luau</code>).</p>
                <Code>{`local log = tab:CreateChangelog({
    name = "Release history",
    emptyText = "No entries yet.",
    entries = {
        {
            version = "0.0.35",
            date = "2026-09-11",
            title = "Settings highlight",
            changes = {
                { symbol = "~", category = "Fixed", text = "Settings stays highlighted while its tab is active." },
                { symbol = "+", text = "Added the changelog element." },
            },
        },
    },
})

log:Add({ version = "Live", date = "Today", changes = { { symbol = "+", text = "Runtime entry." } } })
log:Set({ ... })
log:Clear()`}</Code>
                <p className="mt-3 text-xs text-zinc-500">Symbols: <code className="text-emerald-300">+</code> added (green), <code className="text-red-300">-</code> removed (red), <code className="text-amber-300">~</code> changed (amber); words added/removed/changed map too.</p>
              </section>
            </div>

            {/* Settings */}
            <section id="settings" className="scroll-mt-20 mt-12">
              <h2 className="text-2xl font-bold tracking-tight">Built-in Settings</h2>
              <p className="mt-2 text-zinc-400 leading-7">Every window ships a gear action in the topbar. It’s window-scoped — per-window behaviour, not global. It switches into settings mode (only settings tabs shown); clicking again returns to previous tab.</p>
              <div className="mt-4 overflow-hidden rounded-xl border border-zinc-800">
                <table className="w-full text-sm">
                  <thead className="bg-zinc-900 text-left text-xs tracking-widest text-zinc-500"><tr><th className="px-4 py-3">Tab</th><th className="px-4 py-3">Contents</th></tr></thead>
                  <tbody className="divide-y divide-zinc-800 bg-zinc-950 text-zinc-400">
                    <tr><td className="px-4 py-3 font-medium text-zinc-200">General</td><td className="px-4 py-3">Menu Toggle keybind (type key like <code className="text-zinc-300">K</code>, <code className="text-zinc-300">Space</code>, <code className="text-zinc-300">MB2</code>, <code className="text-zinc-300">none</code> to unbind), unlock-cursor, welcome toast, Window Behavior (prevent duplicate, keep on screen, draggable capsule, reset positions), Performance & Motion (haptics, animation speed).</td></tr>
                    <tr><td className="px-4 py-3 font-medium text-zinc-200">Appearance</td><td className="px-4 py-3">Theme dropdown + Apply (popup confirm), Bar Layout (Default Topbar / Sidebar / Collapsed Sidebar), Profile card (Show profile / side / Reveal details).</td></tr>
                    <tr><td className="px-4 py-3 font-medium text-zinc-200">Persistence</td><td className="px-4 py-3">Auto Save / Auto Load toggles; Saved-configurations dropdown + name input + Save/Load/Delete.</td></tr>
                    <tr><td className="px-4 py-3 font-medium text-zinc-200">About</td><td className="px-4 py-3">Library info and links.</td></tr>
                  </tbody>
                </table>
              </div>
              <p className="mt-3 text-sm leading-6 text-zinc-500">Window + profile card (260×420) are centred as one unit: window rests 136px off centre opposite the card so window + 12px gap + card are middle-aligned. Re-derived on first show, hide/show restore, card state changes, “Keep window on screen” clamps the pair.</p>
            </section>

            {/* Themes */}
            <section id="themes" className="scroll-mt-20 mt-12">
              <h2 className="text-2xl font-bold tracking-tight">Themes</h2>
              <p className="mt-2 text-zinc-400">Built-ins: <code className="text-zinc-300">default, amethyst, cobalt, ember, frost, rose</code> (10 total).</p>
              <div className="mt-4">
                <Code>{`window:ChangeTheme("amethyst")
window:ChangeTheme({
    ElementGradient = ColorSequence.new(Color3.fromRGB(20,20,30), Color3.fromRGB(30,30,45)),
    AccentColor = Color3.fromRGB(120, 90, 220),
})`}</Code>
              </div>
            </section>

            {/* Icons */}
            <section id="icons" className="scroll-mt-20 mt-12">
              <h2 className="text-2xl font-bold tracking-tight">Icons — 7 packs</h2>
              <p className="mt-2 text-zinc-400 leading-7">No window-wide <code className="text-zinc-300">iconPack</code> needed. Every icon lookup works everywhere.</p>
              <div className="mt-4">
                <Code>{`Astra.Icons.get("house")                -- searched in every pack, priority order
Astra.Icons.get("material:home")        -- exactly this pack (pack:name)
Astra.Icons.get("home", "tabler")       -- pack argument does the same
Astra.Icons.getByPack("tabler", "home")
Astra.Icons.resolve("house")            -- URL / asset id ready for an Image
window:ResolveIcon("house")             -- searches all packs
window:ResolveIcon("feather:home")      -- one exact icon`}</Code>
              </div>
              <div className="mt-4 rounded-xl border border-zinc-800 bg-zinc-900 p-4">
                <div className="text-xs font-semibold tracking-widest text-zinc-500">PRIORITY & LAZY LOAD</div>
                <p className="mt-2 text-sm leading-6 text-zinc-400">Bare names search in fixed order — lucide, material, tabler, phosphor, heroicons, feather, remix — first hit wins. Lazy: only packs up to the hit are read (<code className="text-zinc-300">Astra.Icons.loaded()</code> tells you which).</p>
                <p className="mt-2 text-sm leading-6 text-zinc-400">Qualified names (<code className="text-zinc-300">pack:name</code>) never fall back. Names & packs are exact; <code className="text-zinc-300">Home ≠ home</code>. Unknown pack warns once and returns nothing. Values already usable (<code className="text-zinc-300">rbxassetid://, http://</code>) pass through.</p>
                <p className="mt-2 text-sm leading-6 text-zinc-400">Custom <code className="text-zinc-300">custom_asset/</code> folder next to script wins at resolve: <code className="text-zinc-300">custom_asset/brand/house.png</code> → <code className="text-zinc-300">get("brand/house")</code>. See <Link href="https://github.com/Kira762/astra-version-1/blob/main/assets/icons/README.md" target="_blank" className="text-violet-400 hover:underline">visual icon catalog</Link>.</p>
              </div>
            </section>

            {/* Motion */}
            <section id="motion" className="scroll-mt-20 mt-12">
              <h2 className="text-2xl font-bold tracking-tight">Motion</h2>
              <p className="mt-2 text-zinc-400 leading-7">Every transition runs through one service so your own tweens can use the same specs and respect the user’s <strong className="text-zinc-300">Animation speed</strong>.</p>
              <div className="mt-4">
                <Code>{`-- Animate with the library's own specs
Astra.Motion.tween(frame, { BackgroundTransparency = 0.5 }, "snappy")
-- Specs: instant, fast, snappy, normal, smooth, emphasized, pop, glide, exit, spring, settle, spin, drift
Astra.Motion.tween(stroke, { Color = Color3.new(1,1,1) }, TweenInfo.new(0.3))
Astra.Motion.tween(panel, { Position = target }, "smooth", function() panel.Visible = false end)

Astra.Motion.setProfile("relaxed")     -- relaxed | normal | snappy | instant
Astra.Motion.setTimeScale(0.8)
Astra.Motion.setEnabled(false)
Astra.Motion.step(0.035)               -- cascade pacing, scaled
Astra.Motion.cancel(frame)`}</Code>
              </div>
              <p className="mt-3 text-sm leading-6 text-zinc-500">Never animates a property already at target; cancels a fighting in-flight tween so repeated handlers can’t stack.</p>
            </section>

            {/* Locale */}
            <section id="locale" className="scroll-mt-20 mt-12">
              <h2 className="text-2xl font-bold tracking-tight">Localisation</h2>
              <Code>{`window:RegisterTranslations({ en = { play = "Play" }, de = { play = "Spielen" } })
window:SetLocale("de")
window:SetTranslator(function(source, localeId) return ... end)`}</Code>
            </section>

            {/* Startup */}
            <section id="startup" className="scroll-mt-20 mt-12">
              <h2 className="text-2xl font-bold tracking-tight">Startup performance</h2>
              <p className="mt-2 text-zinc-400 leading-7">Construction is staged across frames. Large initial batches yield after ~4ms or 120 instances (cooperative, not a hard cap). Calls still return fully built objects but may yield.</p>
              <ul className="mt-3 list-disc space-y-1 pl-5 text-sm leading-6 text-zinc-400">
                <li>Auto-show on next frame (one defer + one heartbeat) so first <code className="text-zinc-300">CreateTab</code> calls land before the shell appears; remaining constructors stream in behind the visible window.</li>
                <li>Arrival is staged: shell → page controls (one per beat) → overlays. <code className="text-zinc-300">Notify</code> cards are queued (one entrance at a time, cooldown; past 6 waiting, oldest not-yet-built is dropped). With <code className="text-zinc-300">Instant</code> profile the queue keeps order but drops pauses.</li>
                <li>Search controls are created on first search open; settings tabs & controls are lazy until selected; inactive tabs wait before reveal animations.</li>
              </ul>
            </section>

            {/* Collapsible */}
            <section id="collapsible" className="scroll-mt-20 mt-12">
              <h2 className="text-2xl font-bold tracking-tight">Collapsible Group (optional)</h2>
              <p className="mt-2 text-zinc-400 leading-7">Group controls under an animated header. Nothing is auto-wrapped; existing elements & ordinary Groups are unchanged.</p>
              <div className="mt-4">
                <Code title="collapsible.luau">{`local playerControls = tab:CreateCollapsibleGroup({
    name = "LocalPlayer",
    icon = "user-round",
    elements = {
        { type = "Toggle", name = "Infinite Jump", flag = "infiniteJump", value = false, callback = function(enabled) print(enabled) end },
        { type = "Slider", name = "Walk Speed", flag = "walkSpeed", range = { 16, 100 }, value = 16, callback = function(v) print(v) end },
        { type = "Group", elements = {
            { type = "Button", name = "Reset Speed", icon = "feather:rotate-ccw", callback = function() window:Set("walkSpeed", 16) end },
            { type = "Button", name = "Show Speed", callback = function() print(window:Get("walkSpeed")) end },
        }},
    },
})`}</Code>
              </div>
              <ul className="mt-3 list-disc space-y-1 pl-5 text-sm leading-6 text-zinc-400">
                <li>Supported: <code className="text-zinc-300">Button, Toggle, Switch, Slider, Dropdown, Input, Stat, Section, Text, Divider, Group, Changelog</code>.</li>
                <li>Every group starts collapsed; no <code className="text-zinc-300">expanded</code> prop. Click header to toggle; multiple groups independent.</li>
                <li>Values/flags stay active when collapsed; closing doesn’t recreate/reset/rerun callbacks. Closing cancels uncommitted input edits & closes dropdowns.</li>
                <li>Search includes child names & temporarily expands matches; closing restores previous state.</li>
                <li>Cannot contain Collapsible Groups (direct or via Group); invalid/cyclic/nested ones are rejected before UI is created.</li>
                <li>Built in startup batches even while collapsed, so saved flags are usable before first expansion.</li>
              </ul>
            </section>

            {/* Props */}
            <section id="props" className="scroll-mt-20 mt-12">
              <h2 className="text-2xl font-bold tracking-tight">CreateWindow — all props</h2>
              <div className="mt-4">
                <Code>{`local window = Astra:CreateWindow({
    name = "My UI",              -- title (left side of topbar)
    subtitle = "v1.0",           -- small text next to title
    icon = "house",              -- topbar icon (pack name or asset id)
    theme = "default",           -- 10 built-ins or custom table
    showName = "Astra",          -- name when minimised to capsule (default "Astra")
    showIconOnly = false,        -- capsule shows only icon, no name
    fallbackFont = Enum.Font.Gotham,
    translator = function(source, localeId) return ... end,
    locale = "en",
    translations = { ... },
})`}</Code>
              </div>
              <p className="mt-3 text-sm text-zinc-500">Layout is not a prop — switch in <strong className="text-zinc-300">Settings → Appearance → Bar Layout</strong>. See <code className="text-zinc-300">example.client.luau</code> for a complete end-to-end example covering every element type.</p>
            </section>

            {/* Repo */}
            <section id="repo" className="scroll-mt-20 mt-12">
              <h2 className="text-2xl font-bold tracking-tight">Monorepo & Vercel — why website/ doesn’t break Luau</h2>
              <p className="mt-2 text-zinc-400 leading-7">This repo is a monorepo: Luau library at the root, Next.js site in <code className="rounded bg-zinc-900 px-1 py-0.5 text-zinc-200">website/</code>. Root <code className="rounded bg-zinc-900 px-1 py-0.5 text-zinc-200">vercel.json</code> builds and publishes <code className="rounded bg-zinc-900 px-1 py-0.5 text-zinc-200">website/out</code> — no dashboard Root Directory setting required.</p>
              <div className="mt-4 grid gap-4 lg:grid-cols-2">
                <div className="overflow-hidden rounded-xl border border-zinc-800 bg-zinc-900">
                  <div className="border-b border-zinc-800 bg-zinc-900 px-4 py-2 text-xs font-semibold tracking-widest text-zinc-500">REPOSITORY LAYOUT</div>
                  <pre className="p-4 font-mono text-xs leading-6 text-zinc-300">{`website/              ← Next.js docs (static export → out/)
  app/page.tsx       your docs (this page)
  package.json       next, react, tailwind
vercel.json          install/build website → output website/out
components/          Luau window shell (not in web build)
elements/            Luau elements (not in web build)
core/ settings/ ...  Luau runtime (not in web build)
version-1.luau       generated bundle (not in web build)
skills/              agent skill (not in web build)`}</pre>
                </div>
                <div className="space-y-4">
                  <div className="rounded-xl border border-zinc-800 bg-zinc-900 p-4">
                    <div className="text-xs font-semibold tracking-widest text-violet-400">ROOT vercel.json</div>
                    <p className="mt-2 text-sm leading-6 text-zinc-400">Builds from the monorepo root so production works without a dashboard Root Directory.</p>
                    <div className="mt-3 rounded-lg bg-zinc-950 p-3 font-mono text-xs leading-5 text-zinc-400">
                      <div><span className="text-violet-400">&quot;installCommand&quot;</span>: <span className="text-amber-300">&quot;cd website &amp;&amp; npm ci&quot;</span></div>
                      <div><span className="text-violet-400">&quot;buildCommand&quot;</span>: <span className="text-amber-300">&quot;cd website &amp;&amp; npm run build&quot;</span></div>
                      <div><span className="text-violet-400">&quot;outputDirectory&quot;</span>: <span className="text-amber-300">&quot;website/out&quot;</span></div>
                    </div>
                  </div>
                  <div className="rounded-xl border border-zinc-800 bg-zinc-900 p-4">
                    <div className="text-xs font-semibold tracking-widest text-zinc-500">OPTIONAL</div>
                    <p className="mt-2 text-sm leading-6 text-zinc-400">Dashboard Root Directory = <code className="text-zinc-300">website</code> is still fine — then <code className="text-zinc-300">website/vercel.json</code> uses <code className="text-zinc-300">outputDirectory: &quot;out&quot;</code>. <code className="text-zinc-300">ignoreCommand</code> skips redeploys when only Luau files change.</p>
                  </div>
                </div>
              </div>
            </section>

            {/* Verify */}
            <section id="verify" className="scroll-mt-20 mt-12">
              <h2 className="text-xl font-bold tracking-tight flex items-center gap-2"><span className="h-2 w-2 rounded-full bg-emerald-500" /> Path verification — Luau still works after adding website/</h2>
              <p className="mt-2 text-sm leading-6 text-zinc-400">Moving docs into <code className="rounded bg-zinc-900 px-1 py-0.5 text-zinc-200">website/</code> does not break file paths. Verified:</p>
              <div className="mt-4 overflow-hidden rounded-xl border border-zinc-800">
                <table className="w-full text-sm">
                  <thead className="bg-zinc-900 text-left text-xs tracking-widest text-zinc-500"><tr><th className="px-4 py-3">Check</th><th className="px-4 py-3">Result</th><th className="px-4 py-3">Why it’s safe</th></tr></thead>
                  <tbody className="divide-y divide-zinc-800 bg-zinc-950 text-zinc-300">
                    <tr><td className="px-4 py-3 font-mono text-xs text-violet-300">default.project.json / wax.project.json</td><td className="px-4 py-3 text-emerald-300">✓ no website/</td><td className="px-4 py-3 text-zinc-400">Rojo tree lists only <code className="text-zinc-300">library_entrypoint, core, components, elements, settings, cache, functions, layouts, images, icons, themes, utilities, Types</code> — website/ is never synced to Roblox, never appears as <code className="text-zinc-300">script.Parent</code>.</td></tr>
                    <tr><td className="px-4 py-3 font-mono text-xs text-violet-300">scripts/generate_bundle.js TREE</td><td className="px-4 py-3 text-emerald-300">✓ 101 modules</td><td className="px-4 py-3 text-zinc-400">Explicit <code className="text-zinc-300">TREE = ["{`{file: library_entrypoint}"`}, {`{dir: core}"`}, …]</code> — no website. Bundle still 101 modules, 25k lines, no <code className="text-zinc-300">website</code> string.</td></tr>
                    <tr><td className="px-4 py-3 font-mono text-xs text-violet-300">scripts/check_requires.py DIRS</td><td className="px-4 py-3 text-emerald-300">✓ 97 files, 292 edges, no cycles</td><td className="px-4 py-3 text-zinc-400">Explicit <code className="text-zinc-300">DIRS = ["core","components",…,"utilities"]</code> — website never scanned. All static <code className="text-zinc-300">require(script.Parent…)</code> still resolve; <code className="text-zinc-300">utilities = script.Parent.Parent.utilities</code> alias still works because parent chain unchanged.</td></tr>
                    <tr><td className="px-4 py-3 font-mono text-xs text-violet-300">scripts/check_syntax.sh</td><td className="px-4 py-3 text-emerald-300">✓ not broken</td><td className="px-4 py-3 text-zinc-400">Loops <code className="text-zinc-300">for dir in core components … utilities</code> — website omitted.</td></tr>
                    <tr><td className="px-4 py-3 font-mono text-xs text-violet-300">Luau script.Parent requires</td><td className="px-4 py-3 text-emerald-300">✓ intact</td><td className="px-4 py-3 text-zinc-400">All requires are <em>DataModel-relative</em> (<code className="text-zinc-300">script.Parent.Parent.utilities</code>), not filesystem-relative. Adding a sibling folder at filesystem root cannot change the parent chain inside the DataModel.</td></tr>
                    <tr><td className="px-4 py-3 font-mono text-xs text-violet-300">version-1.luau bundle</td><td className="px-4 py-3 text-emerald-300">✓ no website</td><td className="px-4 py-3 text-zinc-400"><code className="text-zinc-300">grep -c website version-1.luau == 0</code> — website never bundled.</td></tr>
                  </tbody>
                </table>
              </div>
              <p className="mt-3 text-xs leading-5 text-zinc-500">If you ever <code className="text-zinc-300">require</code> from inside <code className="text-zinc-300">website/</code> into Luau, that would be a new cross-boundary require — we avoid it. Website imports only from <code className="text-zinc-300">website/</code>; Luau imports only from the Rojo tree.</p>
            </section>

            {/* Full example */}
            <section className="mt-12 rounded-2xl border border-violet-900/30 bg-violet-950/20 p-6">
              <h3 className="text-sm font-semibold tracking-widest text-violet-300">FULL EXAMPLE</h3>
              <p className="mt-2 text-sm leading-6 text-zinc-400">See <Link href="https://github.com/Kira762/astra-version-1/blob/main/example.client.luau" target="_blank" className="text-violet-400 hover:underline">example.client.luau</Link> — single-tab, every element type including ordinary & Collapsible Groups and Changelog, end-to-end. Load via the one-liner above, or <code className="text-zinc-300">require(ReplicatedStorage.Astra)</code> in Studio.</p>
            </section>

            {/* Footer */}
            <footer className="mt-12 border-t border-zinc-800 pt-8">
              <div className="flex flex-col gap-2 text-sm text-zinc-500 sm:flex-row sm:items-center sm:justify-between">
                <div>Astra v1 • MIT • <Link href="https://github.com/Kira762/astra-version-1" target="_blank" className="text-zinc-300 hover:text-white">Kira762/astra-version-1</Link> • Docs from USAGE.md</div>
                <div className="text-xs">Deployed from <code className="rounded bg-zinc-900 px-1 py-0.5 text-zinc-400">website/</code> • Luau outside Root Directory never uploaded</div>
              </div>
            </footer>
          </main>
        </div>

        {/* Mobile TOC */}
        <div className="lg:hidden mt-8 border-t border-zinc-800 pt-6">
          <div className="text-xs font-semibold tracking-widest text-zinc-500">ON THIS PAGE</div>
          <div className="mt-3 flex flex-wrap gap-2">
            {TOC.filter(t=>!t.label.startsWith("—")).map(t=>(
              <a key={t.id} href={`#${t.id}`} className="rounded-full border border-zinc-800 bg-zinc-900 px-3 py-1.5 text-xs text-zinc-400 hover:text-white">{t.label}</a>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
