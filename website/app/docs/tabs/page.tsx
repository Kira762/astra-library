import Link from "next/link";
import { CodeBlock } from "@/components/code-block";
import { C, Callout, CardGrid, DocCard, H2, PageHeader, PropTable } from "@/components/content";
import { docsMetadata } from "@/lib/docs";

export const metadata = docsMetadata({
  title: "Tabs and groups",
  description: "Split an Astra window into tabs, create top-level sections, and lay controls out in rows and columns with groups.",
  path: "/docs/tabs/",
});

export default function Tabs() {
  return (
    <>
      <PageHeader
        title="Tabs and groups"
        description="Tabs are the pages of a window; groups are the rows and columns inside one."
      />

      <H2 id="tabs">Tabs</H2>
      <div className="prose-docs">
        <p>
          A tab is created from the window and owns its own scrolling. The first visible tab opens on
          its own, and <C>Select()</C> switches to a tab at any time.
        </p>
      </div>
      <CodeBlock
        code={`local tab = window:CreateTab({ name = "Home", icon = "house" })

tab:Select()      -- switch to it
tab:Deselect()    -- switch away
tab:Remove()      -- destroy it`}
      />
      <PropTable
        headers={["Tab method", "Description"]}
        rows={[
          ["CreateButton", "Run a function when clicked."],
          ["CreateToggle", "A boolean switch; Switch is accepted as an alias."],
          ["CreateSlider", "Pick a number inside a range."],
          ["CreateDropdown", "One option or several, searchable."],
          ["CreateInput", "A text field that commits on focus loss or Enter."],
          ["CreateStat", "A read-only value with a change readout."],
          ["CreateSection", "A section header inside the tab."],
          ["CreateText", "A title, a body, or both."],
          ["CreateDivider", "A rule across the tab, optionally with a word on it."],
          ["CreateGroup", "A row or column container."],
          ["CreateCollapsibleGroup", "Optional; groups controls under an animated header."],
          ["CreateChangelog", "Release history as an element."],
        ]}
      />

      <H2 id="locked">Locked tabs</H2>
      <div className="prose-docs">
        <p>
          <C>CreateTab(&#123; locked = true &#125;)</C> builds a tab that is visible in the sidebar but
          gated: the row draws a lock badge in its top-right corner, stays dimmed, and cannot be
          opened by the user. It is the library&apos;s answer to &quot;this section exists, but not for
          this user yet&quot; — premium gates, feature checks, staged reveals.
        </p>
      </div>
      <CodeBlock
        code={`local premium = window:CreateTab({ name = "Premium", icon = "star", locked = true })
premium:CreateButton({ name = "Enable ESP", callback = function() end })

-- later, from host code only — e.g. after a login or premium check:
premium:SetLocked(false)`}
      />
      <div className="prose-docs">
        <ul>
          <li>
            <strong>Host-only.</strong> No UI control changes the lock; <C>tab:SetLocked(bool)</C> is
            the single switch. The state is per-session — it is not a flag and is never written to
            settings or configs.
          </li>
          <li>
            <strong>While locked</strong>, tapping the row raises a short notification (&quot;This tab
            is locked&quot;, lock icon) instead of selecting it. The row has no hover state, and in
            the collapsed icon-only rail the badge still shows. When unlocked, no icon is drawn at
            all — the row is identical to a tab that never had the prop.
          </li>
          <li>
            <strong>Contents stay private.</strong> Elements of a locked tab are never built visible
            and search never indexes them; <C>tab:Select()</C>, <C>window:Navigate(tab)</C> and the
            auto-select of a new window all skip locked tabs.
          </li>
          <li>
            <strong>Locking the open tab</strong> moves the selection to another unlocked tab
            (same-rail preference); if every other tab is locked, the selection clears and the
            content is hidden until the tab is unlocked and opened again.
          </li>
        </ul>
      </div>
      <Callout type="info" title="A UI gate, not security">
        <p>
          It hides content from the player, not from an executor reading the client.
        </p>
      </Callout>

      <H2 id="groups">Groups</H2>
      <div className="prose-docs">
        <p>
          A group lays its children out horizontally by default and switches to a column automatically
          when it holds a control that cannot be compact. Pass{" "}
          <C>direction = &quot;column&quot;</C> to be explicit, and nest groups freely — ordinary groups
          may contain ordinary groups.
        </p>
      </div>
      <CodeBlock
        code={`local row = tab:CreateGroup()                          -- horizontal row
local col = row:CreateGroup({ direction = "column" }) -- nested column
col:CreateToggle({ name = "Left 1" })`}
      />
      <PropTable
        headers={["Group method", "Description"]}
        rows={[
          ["direction", "Not a method but the one prop that matters: \"row\" (default) or \"column\"."],
          ["CreateButton / CreateToggle / CreateSlider", "Compact controls fit a row side by side."],
          ["CreateDropdown / CreateStat", "Available inside groups as well."],
          ["CreateSection / CreateText / CreateDivider", "Section headers, text cards and rules."],
          ["CreateGroup", "Nest another group, any direction."],
        ]}
      />

      <Callout type="warning" title="Collapsible groups are tab-only">
        <p>
          <C>CreateCollapsibleGroup</C> can only be created directly on a tab. Groups cannot contain
          them, and a collapsible group cannot contain another one, directly or through a group. See{" "}
          <Link href="/docs/elements/collapsible-group">Collapsible group</Link>.
        </p>
      </Callout>

      <H2 id="sections">Sections</H2>
      <div className="prose-docs">
        <p>
          &quot;Section&quot; means two different things, and both are just headings.
        </p>
        <ul>
          <li>
            <C>window:CreateSection(&#123; name, icon &#125;)</C> adds a heading to the rail, above the
            tabs that follow it. The returned <C>TabSection</C> handle exposes only <C>Remove()</C>, because the
            tabs underneath it are the content.
          </li>
          <li>
            <C>tab:CreateSection</C> and <C>group:CreateSection</C> add an in-page section header
            between blocks of controls.
          </li>
        </ul>
      </div>
      <CodeBlock
        code={`-- Rail heading (sidebar layout), then the tabs it covers
window:CreateSection({ name = "Combat", icon = "sword" })
local combat = window:CreateTab({ name = "Aimbot", icon = "crosshair" })

-- In-page heading inside a tab
combat:CreateSection({ name = "Target" })
combat:CreateToggle({ name = "Aim assist" })`}
      />

      <CardGrid>
        <DocCard
          href="/docs/elements"
          icon="layers"
          title="Elements overview"
          description="What every element shares before you pick one."
        />
        <DocCard
          href="/docs/elements/collapsible-group"
          icon="chevron-down"
          title="Collapsible group"
          description="Declarative headers that fold a block of controls away."
        />
      </CardGrid>
    </>
  );
}
