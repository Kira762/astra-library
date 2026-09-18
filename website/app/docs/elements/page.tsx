import Link from "next/link";
import { CodeBlock } from "@/components/code-block";
import { C, Callout, CardGrid, DocCard, H2, PageHeader, PropTable } from "@/components/content";
import { Icon } from "@/components/icon";
import { docsMetadata } from "@/lib/docs";

export const metadata = docsMetadata({
  title: "Elements overview",
  description: "What every Astra element shares: moveable and lockable handles, icons, the in-card description line, flags, and an index of all eleven element types.",
  path: "/docs/elements/",
});

const INDEX: { href: string; title: string; description: string; icon: Parameters<typeof DocCard>[0]["icon"] }[] = [
  { href: "/docs/elements/button", title: "Button", description: "Run a function when the player clicks.", icon: "zap" },
  { href: "/docs/elements/toggle", title: "Toggle", description: "Switch a boolean on and off.", icon: "check" },
  { href: "/docs/elements/slider", title: "Slider", description: "Pick a number in a range by dragging.", icon: "sliders" },
  { href: "/docs/elements/dropdown", title: "Dropdown", description: "Choose one option, or several.", icon: "layers" },
  { href: "/docs/elements/input", title: "Input", description: "A text field that commits when the player is done.", icon: "terminal" },
  { href: "/docs/elements/stat", title: "Stat", description: "A read-only value that rolls on change.", icon: "package" },
  { href: "/docs/elements/text", title: "Text", description: "A title, a body, or both.", icon: "book" },
  { href: "/docs/elements/text#divider", title: "Divider", description: "A rule, with a word on it or nothing at all.", icon: "menu" },
  { href: "/docs/elements/text#group", title: "Group", description: "Rows and columns that nest.", icon: "grid" },
  { href: "/docs/elements/collapsible-group", title: "Collapsible group", description: "Controls under an animated header.", icon: "chevron-down" },
  { href: "/docs/elements/changelog", title: "Changelog", description: "Release history as an element.", icon: "star" },
];

export default function Elements() {
  return (
    <>
      <PageHeader
        title="Elements overview"
        description="Every element is created from a tab or a group and returns a handle you can drive later."
        lead={
          <p>
            Constructors all take one table of props. Names and icons are optional,{" "}
            <C>callback</C> is where behaviour goes, and a <C>flag</C> is what makes a value survive a
            restart.
          </p>
        }
      />

      <H2 id="shared">Shared behaviour</H2>
      <PropTable
        headers={["Applies to", "What it means"]}
        rows={[
          [
            "Every element — Moveable",
            "MoveTo(index), MoveToTop(), MoveToBottom(), MoveUp() and MoveDown() re-order an element inside its tab or group at runtime.",
          ],
          [
            "Most elements — Lockable",
            "Lock(reason?), Unlock() and IsLocked() take a control out of the player's hands. The reason replaces the card's description line until it is unlocked, so a locked control explains itself.",
          ],
          [
            "Most props — icon",
            "Any icon field accepts a name (\"play\"), a qualified name (\"feather:rotate-ccw\") or an asset id. Bare names are searched across all seven packs.",
          ],
          [
            "Most elements — description",
            "A muted helper line inside the card. The card grows by the measured, wrapped height, so a long description never overlaps the control.",
          ],
          [
            "Value elements — flag",
            "The key the value saves under. Derived from the name when omitted, so pass one explicitly when labels may change.",
          ],
          [
            "Value elements — forgetState",
            "Set forgetState = true to keep a control out of save/load entirely.",
          ],
        ]}
      />

      <H2 id="handles">Handles</H2>
      <div className="prose-docs">
        <p>
          A constructor returns the element, not nothing — hold on to it and you can drive the control
          later without rebuilding the interface. The common shape across value elements is{" "}
          <C>Set(value, skipCallback?)</C>: the second argument makes the write silent, so restoring
          state does not re-run your callback. Reads are properties: <C>toggle.value</C>,{" "}
          <C>slider.value</C>, <C>input.value</C>.
        </p>
      </div>
      <CodeBlock
        code={`local toggle = tab:CreateToggle({ name = "Auto Sprint", value = true })

toggle:Set(false)          -- fires the callback
toggle:Set(false, true)    -- silent
print(toggle.value)        -- false

toggle:Lock("Premium only")   -- the description line explains why
toggle:Unlock()`}
      />

      <H2 id="index">Element index</H2>
      <CardGrid columns={3}>
        {INDEX.map((item) => (
          <DocCard key={item.href} {...item} />
        ))}
      </CardGrid>

      <H2 id="flags">Flags and persistence</H2>
      <div className="prose-docs">
        <p>
          Elements with flags participate in the same save system as everything else in the window —
          no configuration table, no glue code. That is covered in{" "}
          <Link href="/docs/saving">Saving and flags</Link>.
        </p>
      </div>
      <Callout type="note" title="Groups change what is available">
        <p>
          <C>CreateInput</C> and <C>CreateCollapsibleGroup</C> exist on tabs only. Compact controls
          (button, toggle, slider, divider, text, section, stat, dropdown) work inside groups, and
          groups nest.
        </p>
      </Callout>

      <p className="mt-6 text-sm text-muted">
        Looking for the whole surface in one list?{" "}
        <Link href="/docs/api/methods" className="text-accent hover:underline">
          Method index
        </Link>{" "}
        has every window, tab, group and handle method, with{" "}
        <Icon name="arrow-right" className="inline h-3 w-3 align-middle" /> links back to the page that
        explains each one.
      </p>
    </>
  );
}
