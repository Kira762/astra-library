import { CodeBlock, CommandLine } from "@/components/code-block";
import { C, Callout, H2, PageHeader, PropTable } from "@/components/content";
import { REPO_URL, docsMetadata } from "@/lib/docs";

export const metadata = docsMetadata({
  title: "Repository and deployment",
  description: "How the Astra repository is laid out, how version-1.luau is generated, and how this documentation site is built and published to GitHub Pages.",
  path: "/docs/repo/",
});

export default function Repo() {
  return (
    <>
      <PageHeader
        title="Repository and deployment"
        description="Two things ship from one repository: the Luau library and this site. Neither can break the other."
      />

      <H2 id="layout">Repository layout</H2>
      <CodeBlock
        title="repository root"
        lang="Text"
        code={`version-1.luau            generated bundle — what scripts load (never edit by hand)
library_entrypoint.luau   public API singleton (CreateWindow, Icons, Core, Settings, Motion)
Types.luau                typed public surface
core/                     state (runtime singletons, secureMode), registry, loader
components/               window, sidebar, chrome, drag, notification, popup, search, settings
elements/                 one module per element plus tab, group, section, tabSection
settings/                 defaults, manager, registry, appearance, behavior, performance
themes/                   resolver + one module per built-in theme
icons/                    seven icon packs, packBuilder, custom-asset resolution
utilities/                motion, persistence, icons, locale, layouts, diagnostics
scripts/                  bundle generator, static checkers, runtime tests
skills/astra/             the published Agent Skill
website/                  this site — Next.js static export, outside the Rojo tree`}
      />

      <H2 id="bundle">The generated bundle</H2>
      <div className="prose-docs">
        <p>
          The modular tree is the source of truth; <C>version-1.luau</C> is generated from it by{" "}
          <C>scripts/generate_bundle.js</C>, which refuses to write if it finds fewer than about sixty
          modules. The generator emits a Wax-style bundle — object tree, closure bindings, line offsets
          — which is why the artifact is one file and why scripts load it rather than the tree.
        </p>
        <p>
          A behaviour change is only live for users once the regenerated bundle is committed to{" "}
          <C>main</C>: the raw URL in every example points at that branch. A syntax error in the bundle
          shows up for users as <C>attempt to call a nil value</C> at line&nbsp;1 rather than as a
          syntax error, which is exactly why the syntax gate exists.
        </p>
      </div>

      <H2 id="pipeline">Docs pipeline</H2>
      <div className="prose-docs">
        <p>
          This site is a Next.js app in <C>website/</C> that exports to plain HTML via{" "}
          <C>output: &quot;export&quot;</C>, and{" "}
          <a href={`${REPO_URL}/blob/main/.github/workflows/deploy-pages.yml`} target="_blank" rel="noreferrer">
            .github/workflows/deploy-pages.yml
          </a>{" "}
          publishes it to GitHub Pages on every push to <C>main</C> that touches <C>website/**</C> — so a
          Luau-only commit never redeploys the docs.
        </p>
      </div>
      <CommandLine
        command="npm run build:pages    # = NEXT_PUBLIC_BASE_PATH=/astra-version-1 npm run build --prefix website"
        caption="local Pages build"
      />
      <div className="prose-docs">
        <p>
          The workflow sets <C>NEXT_PUBLIC_BASE_PATH</C> because a project site is served from{" "}
          <C>/astra-version-1</C>; without it every <C>/_next/…</C> asset URL would 404 and the page
          would load unstyled. The build output is never committed, and Pages only ever receives{" "}
          <C>website/out/</C>.
        </p>
      </div>

      <H2 id="paths">Why website/ cannot break Luau</H2>
      <PropTable
        headers={["Check", "Result"]}
        rows={[
          ["default.project.json / wax.project.json", "No website/ entry — the Rojo tree lists only Luau folders, so the site is never synced to Roblox."],
          ["scripts/generate_bundle.js", "An explicit TREE list — website/ is not in it, so the bundle is unchanged by docs work."],
          ["scripts/check_requires.py", "An explicit DIRS list — the site is never scanned, and every static require still resolves."],
          ["scripts/check_syntax.sh", "Loops the published Luau folders, which do not include website/."],
          ["website/ imports", "Site code imports only from website/. There is no Luau require across the boundary."],
        ]}
      />
      <Callout type="note" title="DataModel paths, not filesystem paths">
        <p>
          Every Luau require is DataModel-relative (<C>script.Parent.Parent.utilities</C>), so adding a
          sibling folder at the filesystem root cannot change the parent chain inside Roblox.
        </p>
      </Callout>

      <H2 id="verify">Verification commands</H2>
      <div className="prose-docs">
        <p>Run from the repository root after touching the Luau tree, in this order:</p>
      </div>
      <CodeBlock
        title="before publishing"
        lang="Shell"
        code={`node scripts/generate_bundle.js     # rebuild version-1.luau from the modular tree
sh scripts/check_syntax.sh          # compile every published .luau file
python3 scripts/check_requires.py   # require paths exist, no cycles
python3 scripts/check_instance_fields.py
sh scripts/smoke_test_bundle.sh     # runtime smoke test of the bundle
sh scripts/<feature>_test.sh        # per-feature runtime tests`}
      />
      <div className="prose-docs">
        <p>
          The syntax gate and the runtime tests need the Luau CLI in <C>PATH</C>. Without it the gate
          exits 2 with &quot;not checked&quot; rather than passing silently — a skipped gate is never
          reported as a pass.
        </p>
      </div>
    </>
  );
}
