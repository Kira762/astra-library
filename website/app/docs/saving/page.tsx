import Link from "next/link";
import { CodeBlock } from "@/components/code-block";
import { C, Callout, H2, PageHeader, PropTable } from "@/components/content";
import { docsMetadata } from "@/lib/docs";

export const metadata = docsMetadata({
  title: "Saving and flags",
  description: "Astra saves control values without a configuration table: auto save and auto load toggles, flags, forgetState, and named configurations you can switch at runtime.",
  path: "/docs/saving/",
});

export default function Saving() {
  return (
    <>
      <PageHeader
        title="Saving and flags"
        description="State persists on its own. Read it, write it, and keep more than one configuration."
        lead={
          <p>
            No <C>configuration</C> table is needed in normal window usage. The two toggles that decide
            what happens live in <strong>Settings → Persistence</strong>, and both default to on.
          </p>
        }
      />

      <H2 id="settings">The two toggles</H2>
      <PropTable
        headers={["Setting", "Behaviour"]}
        rows={[
          [
            "Auto Save Config",
            "Saves supported control values after a short coalescing delay, so a dragged slider writes once instead of once per frame.",
          ],
          [
            "Auto Load Config",
            "Restores the default configuration on the next startup. Turning it on does not replace values in the current session.",
          ],
        ]}
      />
      <div className="prose-docs">
        <ul>
          <li>Turning either off does not delete saved configurations.</li>
          <li>Your choices are stored separately from control values.</li>
          <li>Ordinary controls and controls inside collapsible groups use the same system.</li>
          <li>File persistence needs a runtime with writable storage; in-memory flags work regardless.</li>
        </ul>
        <p>
          Existing scripts that still pass a <C>configuration</C> table keep working, but the built-in
          save/load preferences take precedence over it.
        </p>
      </div>

      <H2 id="flags">Flags</H2>
      <div className="prose-docs">
        <p>
          A flag is the key a value saves under. Any value element takes one, and
          a control without a flag gets one derived from its name.
        </p>
      </div>
      <CodeBlock
        code={`tab:CreateToggle({ name = "Auto Sprint", flag = "autoSprint", value = true })

window:Set("autoSprint", false)      -- write it
print(window:Get("autoSprint"))      -- read it back
print(window.Flags.autoSprint)       -- or straight off the flags table`}
      />
      <Callout type="warning" title="Pass explicit flags for anything labelled">
        <p>
          A derived flag changes when the label changes, which silently orphans the saved value. Stable,
          unique flags survive rewording — that is the whole reason to write them out.
        </p>
      </Callout>
      <div className="prose-docs">
        <p>
          Elements created with <C>forgetState = true</C> are excluded from save and load entirely.
          That is the right choice for session-only or host-specific controls.
        </p>
      </div>

      <H2 id="configs">Named configurations</H2>
      <CodeBlock
        code={`window:Save("Slot2")          -- save the current values under a name
window:Load("Slot2")          -- restore them
window:ListConfigs()          -- {"Slot2", ...}
window:DeleteConfig("Slot2")  -- remove it

window:GetPath()              -- (folder, file) the window writes to`}
      />
      <div className="prose-docs">
        <p>
          The default configuration is used whenever no name is passed, which is what Auto Save
          writes to. Named configurations are how one hub keeps several presets — or how two unrelated
          hubs avoid sharing values.
        </p>
      </div>

      <H2 id="names">Naming and sharing</H2>
      <div className="prose-docs">
        <p>
          Default storage identifiers are internal and are not shown in Settings. The consequence is
          worth knowing: windows using the defaults share the default configuration, so unrelated hubs
          should either use separate named presets or the legacy configuration override. See{" "}
          <Link href="/docs/settings#tabs">Built-in settings</Link> for where the player manages
          them.
        </p>
      </div>
      <Callout type="note" title="Saving is per window, not global">
        <p>
          Each window owns its settings and its values, so a hub that opens a second window is not
          editing the first one&apos;s state.
        </p>
      </Callout>
    </>
  );
}
