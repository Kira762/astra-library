import Link from "next/link";
import { CommandLine } from "@/components/code-block";
import { C, Callout, CardGrid, DocCard, H2, PageHeader, PropTable } from "@/components/content";
import { Icon } from "@/components/icon";
import { docsMetadata } from "@/lib/docs";

export const metadata = docsMetadata({
  title: "Introduction",
  description: "Astra v1 is a Luau interface library for Roblox executor scripts: one loader line, a CreateWindow call, and tabs full of elements with saving, themes and icon packs built in.",
  path: "/docs/",
});

export default function Introduction() {
  return (
    <>
      <PageHeader
        title="Introduction"
        description="A windowed interface library for Roblox executor scripts, built in code and published as a single Luau bundle."
        meta={[
          { label: "Library", value: "Astra v1" },
          { label: "Language", value: "Luau" },
          { label: "Runtime", value: "Executor or Studio" },
          { label: "Licence", value: "MIT" },
        ].map((item) => (
          <span key={item.label} className="pill">
            <span className="text-subtle">{item.label}</span>
            <span className="text-ink">{item.value}</span>
          </span>
        ))}
      />

      <h2 id="what-it-is" className="anchor-title text-2xl">
        What Astra is
      </h2>
      <div className="prose-docs mt-3">
        <p>
          Astra draws a Roblox interface for a script: a draggable window with a topbar or sidebar,
          tabs, and controls that behave the way players expect. Everything is built from instances at
          runtime — there is no model to download and nothing to preload — so the loader line has
          nothing to do but return the library table.
        </p>
        <p>
          The whole authoring model is three calls: load the bundle, <C>CreateWindow</C>, and{" "}
          <C>CreateTab</C>. Elements hang off the tab. Saving, the settings panel, themes, icons and
          animation are already inside the window, so an interface that remembers what the player
          chose needs a <C>flag</C> and nothing else.
        </p>
      </div>

      <H2 id="requirements">Requirements</H2>
      <PropTable
        headers={["Needs", "Why"]}
        rows={[
          ["loadstring", "The published artifact is a Luau bundle, compiled at load time. Executors provide loadstring; plain Studio does not — there the library is a ModuleScript you require."],
          ["HttpService enabled", "The one-liner fetches version-1.luau over HttpGet. Without requests enabled the load fails before any Astra code runs."],
          ["A writable runtime (optional)", "File persistence — the saved configurations behind Auto Save and Auto Load — needs storage the runtime is allowed to write to. Without it, flags still work for the session."],
        ]}
      />

      <Callout type="note" title="Load the bundle, never the tree">
        <p>
          The repository holds both the modular source and <C>version-1.luau</C>, the generated
          single-file bundle. Scripts load the bundle. Every example in these docs, and{" "}
          <C>example.client.luau</C>, uses the same URL.
        </p>
      </Callout>

      <H2 id="in-the-box">What ships in the box</H2>
      <div className="prose-docs">
        <p>
          These are the parts of the library you interact with as an author. Each one has its own page
          in the sidebar.
        </p>
      </div>
      <div className="my-4 overflow-hidden rounded-xl border border-line">
        <div className="scroll-x" tabIndex={0} role="region" aria-label="What ships in the box">
          <table className="data-table">
            <thead>
              <tr>
                <th className="w-[30%]">Area</th>
                <th>What it covers</th>
              </tr>
            </thead>
            <tbody>
              {[
                ["Window", "Topbar, sidebar and collapsed-sidebar layouts, minimise to a capsule, notifications, popups, search, the profile card and per-window settings."],
                ["Elements", "Eleven types: Section, Text, Button, Toggle, Slider, Dropdown, Input, Stat, Divider, Group, Collapsible Group and Changelog."],
                ["State", "Flags with auto save and auto load, named configurations, forgetState opt-outs, and persistence through the runtime's writable storage."],
                ["Look", "Ten built-in themes plus custom theme tables, seven icon packs with 13,715 icons, and a custom_asset folder that overrides them."],
                ["Motion", "One service behind every transition, following the player's animation-speed setting."],
                ["Startup", "Staged construction in budgeted batches so the window appears immediately and fills in behind itself."],
              ].map(([area, covers]) => (
                <tr key={area}>
                  <td className="font-medium text-ink">{area}</td>
                  <td>{covers}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      <H2 id="next-steps">Where to go next</H2>
      <CardGrid>
        <DocCard
          href="/docs/getting-started"
          icon="zap"
          title="Getting started"
          description="Load the bundle and build the first window, in the two load paths."
        />
        <DocCard
          href="/docs/elements"
          icon="layers"
          title="Elements overview"
          description="Shared behaviour, handles, and an index of every element page."
        />
      </CardGrid>

      <H2 id="agent-skill">Install the agent skill</H2>
      <div className="prose-docs">
        <p>
          The repository also publishes an Agent Skill called <C>astra</C>. It teaches a coding agent
          the loader contract, the element cheat sheet and the repository rules, which is usually the
          difference between a plausible-looking snippet and one that compiles.
        </p>
      </div>
      <CommandLine command="npx skills add Kira762/astra-version-1" caption="agent skill" />
      <p className="text-sm text-muted">
        Read <Link href="/docs/skill" className="text-accent hover:underline">what the skill contains</Link>{" "}
        and how it is versioned, or browse{" "}
        <a
          href="https://skills.sh/Kira762/astra-version-1"
          target="_blank"
          rel="noreferrer"
          className="inline-flex items-center gap-1 text-accent hover:underline"
        >
          the listing <Icon name="external" className="h-3 w-3" />
        </a>
        .
      </p>
    </>
  );
}
