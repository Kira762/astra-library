import Link from "next/link";
import { CodeBlock } from "@/components/code-block";
import { C, Callout, H2, PageHeader, PropTable } from "@/components/content";
import { docsMetadata } from "@/lib/docs";

export const metadata = docsMetadata({
  title: "Collapsible group",
  description: "Group Astra controls under an animated header: declarative elements, supported types, nesting rules, and what happens to flags while collapsed.",
  path: "/docs/elements/collapsible-group/",
});

export default function CollapsibleGroup() {
  return (
    <>
      <PageHeader
        title="Collapsible group"
        description="Group controls under an animated header. Existing standalone elements and ordinary groups are unchanged — nothing is wrapped automatically."
        meta={<span className="pill">tab:CreateCollapsibleGroup</span>}
      />

      <H2 id="usage">Usage</H2>
      <CodeBlock
        code={`local playerControls = tab:CreateCollapsibleGroup({
    name = "LocalPlayer",
    icon = "user-round",          -- optional; any icon pack
    elements = {
        {
            type = "Toggle",
            name = "Infinite Jump",
            flag = "infiniteJump",
            value = false,
            callback = function(enabled) print("Infinite jump:", enabled) end,
        },
        {
            type = "Slider",
            name = "Walk Speed",
            flag = "walkSpeed",
            range = { 16, 100 },
            value = 16,
            callback = function(value) print("Walk speed:", value) end,
        },
        {
            type = "Group",
            elements = {
                { type = "Button", name = "Reset Speed", icon = "feather:rotate-ccw", callback = function() window:Set("walkSpeed", 16) end },
                { type = "Button", name = "Show Speed", callback = function() print(window:Get("walkSpeed")) end },
            },
        },
    },
})`}
      />

      <H2 id="types">Supported types</H2>
      <div className="prose-docs">
        <p>
          <C>Button</C>, <C>Toggle</C>, <C>Switch</C> (the declarative alias of the toggle control),{" "}
          <C>Slider</C>, <C>Dropdown</C>, <C>Input</C>, <C>Stat</C>, <C>Section</C>, <C>Text</C>,{" "}
          <C>Divider</C>, <C>Changelog</C> and ordinary <C>Group</C>. Each entry uses exactly the
          properties of its normal <C>Create…</C> method, including the optional{" "}
          <C>description</C> helper line. <C>elements</C> can be omitted for an empty header.
        </p>
      </div>
      <PropTable
        rows={[
          ["name", "The header label."],
          ["icon", "Optional header icon, from any pack."],
          ["elements", "The declarative list of controls. Omit it for an empty header."],
        ]}
      />

      <H2 id="rules">Rules</H2>
      <div className="prose-docs">
        <ul>
          <li>
            Every collapsible group starts collapsed; there is no <C>expanded</C> usage property.
          </li>
          <li>
            Collapsible groups cannot contain collapsible groups, directly or through a group.
          </li>
          <li>
            Invalid types, sparse lists and cyclic or nested definitions are rejected before any UI is
            created.
          </li>
          <li>
            An ordinary group keeps its compact row layout when its children support it. Use{" "}
            <C>direction = &quot;column&quot;</C> for a vertical group — the declarative builder also
            chooses a column automatically when the group contains non-compact controls, so no chosen
            element is silently discarded.
          </li>
        </ul>
      </div>

      <H2 id="behaviour">Behaviour</H2>
      <div className="prose-docs">
        <ul>
          <li>Click the header to open or close. Multiple groups operate independently.</li>
          <li>
            Expansion runs through Astra&apos;s <Link href="/docs/motion">motion service</Link>,
            including the instant-motion setting.
          </li>
          <li>
            Values, flags and running features stay active while collapsed. Closing and reopening never
            recreates controls, resets them or re-runs their value callbacks.
          </li>
          <li>
            Closing cancels an uncommitted input edit and closes open dropdowns; already committed
            values are unchanged.
          </li>
          <li>
            Search includes child names and temporarily expands matching groups, restoring their
            previous state when search closes.
          </li>
          <li>
            Children render at the same width as standalone elements, and the header matches the text
            element&apos;s card metrics.
          </li>
          <li>
            All three layouts are supported; the tab supplies scrolling for long contents.
          </li>
          <li>
            <C>MoveTo</C>, <C>MoveToTop</C>, <C>MoveToBottom</C>, <C>MoveUp</C>, <C>MoveDown</C>,{" "}
            <C>Lock</C> and <C>Unlock</C> work on the container, and the created child handles are in
            its <C>elements</C> array in definition order — exactly like an ordinary group.
          </li>
          <li>
            Controls are built in the startup batches even while collapsed, so saved flags are usable
            before the first expansion.
          </li>
        </ul>
      </div>
      <Callout type="warning" title="Declarative only">
        <p>
          There is no per-element <C>Create…</C> on a collapsible group: the controls arrive in the{" "}
          <C>elements</C> list at construction. The optional feature adds no container instances unless
          you explicitly create one.
        </p>
      </Callout>
    </>
  );
}
