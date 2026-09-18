import Link from "next/link";
import { CodeBlock } from "@/components/code-block";
import { C, Callout, H2, PageHeader, PropTable } from "@/components/content";
import { REPO_URL, docsMetadata } from "@/lib/docs";

export const metadata = docsMetadata({
  title: "Icons",
  description: "Seven icon packs, 13,715 icons, name-only lookup with a fixed pack order, qualified pack:name lookups, pass-through asset ids and a custom_asset override folder.",
  path: "/docs/icons/",
});

const PACKS = [
  ["lucide", "1,776"],
  ["material", "1,133"],
  ["tabler", "5,130"],
  ["phosphor", "1,512"],
  ["heroicons", "648"],
  ["feather", "287"],
  ["remix", "3,229"],
];

export default function Icons() {
  return (
    <>
      <PageHeader
        title="Icons"
        description="Seven packs, 13,715 icons, and a folder of your own that takes precedence over all of them."
        meta={
          <>
            <span className="pill">no iconPack option</span>
            <span className="pill">case-sensitive</span>
            <span className="pill">lazy pack loading</span>
          </>
        }
      />

      <div className="my-4 grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
        {PACKS.map(([pack, count]) => (
          <div key={pack} className="card flex items-center justify-between px-3 py-2.5">
            <span className="font-mono text-sm text-ink">{pack}</span>
            <span className="text-xs text-subtle tabular-nums">{count} icons</span>
          </div>
        ))}
      </div>

      <H2 id="lookup">Name-only lookup</H2>
      <div className="prose-docs">
        <p>
          A bare name is searched in every pack, in a fixed order —{" "}
          <strong>lucide, material, tabler, phosphor, heroicons, feather, remix</strong> — and the first
          pack that has it wins. Nothing to pick, nothing to configure: lucide spells the home glyph{" "}
          <C>house</C> and material has no <C>house</C> but has <C>home</C>, so both{" "}
          <C>get(&quot;house&quot;)</C> and <C>get(&quot;home&quot;)</C> work, the latter from material.
        </p>
        <p>
          A name that exists in several packs always answers from the earlier pack. The search is lazy:
          a pack&apos;s table is read on first lookup, and only the packs up to the hit are read, so a
          lucide name costs one pack. <C>Astra.Icons.loaded()</C> tells you which packs a session has
          read.
        </p>
      </div>

      <H2 id="qualified">Qualified names</H2>
      <div className="prose-docs">
        <p>
          When it has to be a specific pack, qualify it — <C>get(&quot;tabler:home&quot;)</C>,{" "}
          <C>resolve(&quot;lucide:house&quot;)</C>, <C>window:ResolveIcon(&quot;material:home&quot;)</C>{" "}
          — or pass the pack as the second argument.
        </p>
        <ul>
          <li>
            An explicit pack is never overruled by the order. If that pack has no such icon the request
            resolves to nothing, and <C>resolve</C> hands back the value it was given.
          </li>
          <li>
            Names, pack names and the <C>pack:</C> prefix are matched exactly as written.{" "}
            <C>Home</C>, <C>HOME</C> and <C>Lucide:house</C> are not <C>home</C>, and no lookup is
            lowercased, corrected or fuzzed.
          </li>
          <li>
            An unknown pack name warns once per pack and answers nothing, rather than substituting a
            pack you did not ask for.
          </li>
        </ul>
        <p>
          Window and element icons can mix packs freely; there is no window-wide <C>iconPack</C>{" "}
          property to set.
        </p>
      </div>

      <H2 id="api">Icons API</H2>
      <CodeBlock
        code={`Astra.Icons.get("house")                -- searched in every pack, priority order
Astra.Icons.get("material:home")        -- exactly this pack
Astra.Icons.get("home", "tabler")       -- the optional pack argument does the same
Astra.Icons.getByPack("tabler", "home")
Astra.Icons.resolve("house")            -- a URL / asset id, ready for an Image
Astra.Icons.list("lucide")
Astra.Icons.packs()  Astra.Icons.count()  Astra.Icons.isPack("feather")
Astra.Icons.priority()                   -- the search order
Astra.Icons.loaded()                     -- the packs read so far
Astra.Icons.refreshCustom()              -- re-read custom_asset/

window:ResolveIcon("house")              -- searches all packs
window:ResolveIcon("feather:home")       -- selects one exact icon`}
      />

      <H2 id="values">Passing a value through</H2>
      <div className="prose-docs">
        <p>
          Icon names resolve to 48×48 PNGs that ship in this repository under{" "}
          <C>assets/icons/&lt;pack&gt;-pack/</C>. The resolver maps them onto the repository&apos;s
          raw-GitHub URL — or your executor&apos;s <C>getcustomasset</C> override when one is provided —
          so no <C>rbxassetid</C> lookups are needed.
        </p>
        <p>
          Values that are already usable pass through untouched: numbers, <C>rbxassetid://…</C>,{" "}
          <C>rbxasset://…</C>, <C>rbxthumb://…</C> and <C>http(s)://…</C>. An unresolved value comes
          back unchanged, which makes it safe to pass a name you are not sure about.
        </p>
      </div>
      <PropTable
        headers={["Accepted value", "Example"]}
        rows={[
          ["Bare icon name", "\"play\" — first pack in priority order that has it"],
          ["Qualified name", "\"feather:rotate-ccw\""],
          ["Name plus pack argument", "get(\"home\", \"tabler\")"],
          ["Asset id number", "93364949241311"],
          ["Asset URL", "\"rbxassetid://123\" or an https URL"],
        ]}
      />

      <H2 id="custom">Custom assets</H2>
      <div className="prose-docs">
        <p>
          A <C>custom_asset/</C> folder next to your script takes precedence over the packs at resolve
          time. One file per icon name, in <C>.png</C>, <C>.jpg</C>, <C>.jpeg</C>, <C>.webp</C> (tried
          in that order) or with no extension at all; subfolders are allowed, so{" "}
          <C>custom_asset/brand/house.png</C> is asked for as <C>get(&quot;brand/house&quot;)</C>.
        </p>
        <ul>
          <li>
            With an executor that provides <C>listfiles</C> the folder is indexed once and looked up by
            name, so names you have no file for cost nothing.
          </li>
          <li>Without it, the resolver keeps the historic extension probe.</li>
          <li>
            Either way a file is imported at most once per runtime, misses are remembered, and{" "}
            <C>Astra.Icons.refreshCustom()</C> re-reads the folder after you add or remove files.
          </li>
          <li>Qualified names are never shadowed by the folder.</li>
        </ul>
      </div>

      <Callout type="tip" title="All seven catalogs are visual">
        <p>
          <a href={`${REPO_URL}/blob/main/assets/icons/README.md`} target="_blank" rel="noreferrer">
            assets/icons/README.md
          </a>{" "}
          renders previews with copyable names for every pack — the fastest way to find the exact
          spelling, since names are case-sensitive.
        </p>
      </Callout>
      <Callout type="note" title="Where icons are accepted">
        <p>
          Anywhere a prop takes an <C>icon</C>: the window, tabs, sections, elements, notifications,
          popups and boxes. See the <Link href="/docs/elements">element pages</Link> for the exact
          props.
        </p>
      </Callout>
    </>
  );
}
