import Link from "next/link";
import { CodeBlock, CommandLine } from "@/components/code-block";
import { C, Callout, PageHeader, NextLinks } from "@/components/content";
import { BUNDLE_URL, LOADER_LINE, docsMetadata } from "@/lib/docs";

export const metadata = docsMetadata({
  title: "Getting started",
  description: "Load Astra's bundle with one line and build your first Roblox window: CreateWindow, CreateTab, and elements that respond to the player.",
  path: "/docs/getting-started/",
});

export default function GettingStarted() {
  return (
    <>
      <PageHeader
        title="Getting started"
        description="Load the bundle and build your first window in a few lines."
        lead={
          <p>
            Two things have to be right before Astra does anything: the runtime needs{" "}
            <C>loadstring</C>, and the URL has to be the raw file of the published bundle.
          </p>
        }
      />

      <h2 id="load" className="anchor-title text-2xl font-semibold tracking-tight">
        Load the library
      </h2>
      <div className="prose-docs mt-3">
        <p>One loader, one line — this is what example.client.luau does:</p>
      </div>
      <CommandLine command={LOADER_LINE} caption="loader line" />

      <div className="my-5 grid gap-3 sm:grid-cols-3">
        {[
          [
            "The URL is the raw bundle",
            "It points at version-1.luau in a public repository. That file is generated from the modular tree — load the bundle, never the tree, and never a per-file raw URL.",
          ],
          [
            "The runtime has loadstring",
            "Executors provide it. Plain Studio does not, so there the same library is a ModuleScript and you require it from ReplicatedStorage instead.",
          ],
          [
            "The trailing () is there",
            "loadstring(text) only compiles, it returns the chunk. Calling it runs Astra and hands back the module table. Without the call you get a function, and every later Astra:CreateWindow fails.",
          ],
        ].map(([title, body]) => (
          <div key={title} className="card p-4">
            <h3 className="font-display text-sm font-semibold text-ink">{title}</h3>
            <p className="mt-2 text-sm leading-6 text-muted">{body}</p>
          </div>
        ))}
      </div>

      <CodeBlock
        title="Studio / Rojo"
        lang="Luau"
        code={`-- Same library, loaded as a ModuleScript instead of fetched text.
local Astra = require(game:GetService("ReplicatedStorage").Astra)`}
      />

      <h2 id="failed-load" className="anchor-title mt-12 text-2xl font-semibold tracking-tight">
        When the loader fails
      </h2>
      <div className="prose-docs mt-3">
        <p>
          <C>loadstring</C> does not throw when the text will not compile — it returns{" "}
          <C>nil</C> plus the error. The one-liner therefore reports nothing more useful than this:
        </p>
      </div>
      <CodeBlock
        title="error"
        lang="Text"
        code={`rAnDoMcHuNkNaMe:1: attempt to call a nil value
Stack Begin
Script 'LocalScript', Line 1
Stack End`}
      />
      <div className="prose-docs">
        <p>
          Read that as “the text I fetched never compiled”. The random name is the executor&apos;s
          chunk and <C>Line 1</C> is the line holding the call; nothing here is a bug inside Astra.
          Check in order:
        </p>
        <ol>
          <li>
            <strong>The fetch returned something that is not Luau.</strong> A private repository, a
            wrong branch or file name, or a rate limit hands back an HTML error page, which never
            compiles. One line settles it:{" "}
            <C>print(game:HttpGet(url):sub(1, 120))</C>.
          </li>
          <li>
            <strong>The source really has a syntax error.</strong> Published files are compile-checked
            with <C>scripts/check_syntax.sh</C>; run it after editing anything in the tree, then{" "}
            <C>node scripts/generate_bundle.js</C>.
          </li>
        </ol>
        <p>
          Once the line returns a table the compile is fine, and a later{" "}
          <C>attempt to call a nil value</C> names an Astra line: a missing element method, a{" "}
          <C>Create…</C> on the wrong parent (Collapsible Groups live on a Tab, not on a Group), or
          props passed positionally instead of as one table.
        </p>
      </div>

      <Callout type="warning" title="Props are one table, always">
        <p>
          Every constructor takes a single table: <C>tab:CreateButton{"{ name = … }"}</C>. A second
          positional argument is ignored, and the failure shows up much later as a nil method call.
        </p>
      </Callout>

      <h2 id="first-window" className="anchor-title mt-12 text-2xl font-semibold tracking-tight">
        Your first window
      </h2>
      <div className="prose-docs mt-3">
        <p>
          A window is the entry point. Create one, add a tab, and fill it with elements. The first
          visible tab opens on its own, so there is nothing else to wire up.
        </p>
      </div>
      <CodeBlock
        title="window.luau"
        code={`local window = Astra:CreateWindow({
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
})`}
      />

      <div className="prose-docs">
        <p>
          Layout is not a constructor prop — the window ships all three and the player picks one in{" "}
          <strong>Settings → Appearance → Bar Layout</strong>. That is also where themes, persistence
          and the profile card are configured, so an author never has to build a settings screen.
        </p>
      </div>

      <Callout type="tip" title="Icons are optional everywhere">
        <p>
          Element props accept <C>icon</C> as a name (<C>&quot;play&quot;</C>), a qualified name (
          <C>&quot;feather:rotate-ccw&quot;</C>) or an asset id. Bare names are searched across all
          seven packs in a fixed order. See <Link href="/docs/icons">Icons</Link>.
        </p>
      </Callout>

      <h2 id="next" className="anchor-title mt-12 text-2xl font-semibold tracking-tight">
        Where to go next
      </h2>
      <NextLinks
        items={[
          { href: "/docs/windows", label: "Windows", description: "Every constructor prop and runtime method." },
          { href: "/docs/elements", label: "Elements", description: "The eleven types, with props and examples." },
          { href: "/docs/saving", label: "Saving and flags", description: "Make the interface remember the player's choices." },
          { href: "/docs/themes", label: "Themes", description: "Ten built-ins, or bring your own colours." },
        ]}
      />

      <Callout type="note" title="The bundle URL">
        <p>
          <a
            href={BUNDLE_URL}
            target="_blank"
            rel="noreferrer"
            className="break-all"
          >
            {BUNDLE_URL}
          </a>
        </p>
      </Callout>
    </>
  );
}
