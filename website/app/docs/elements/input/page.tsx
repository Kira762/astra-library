import Link from "next/link";
import { CodeBlock } from "@/components/code-block";
import { C, Callout, H2, PageHeader, PropTable } from "@/components/content";
import { docsMetadata } from "@/lib/docs";

export const metadata = docsMetadata({
  title: "Input",
  description: "Create an Astra input element: a text field that commits when the player is done, with numeric and clear-on-focus options.",
  path: "/docs/elements/input/",
});

export default function Input() {
  return (
    <>
      <PageHeader
        title="Input"
        description="A text field that commits when the player is done."
        meta={<span className="pill">tab:CreateInput</span>}
      />

      <H2 id="usage">Usage</H2>
      <CodeBlock
        code={`local input = tab:CreateInput({
    name = "Name",
    flag = "playerName",
    placeholder = "Type here",
    value = "Initial",
    numeric = true,
    clearOnFocus = true,
    callback = function(text) print(text) end,
})

input:Set("Astra")        -- fires the callback
input:Set("Astra", true)  -- silent`}
      />

      <H2 id="props">Props</H2>
      <PropTable
        rows={[
          ["name", "The label on the card."],
          ["icon", "Left-hand icon: pack name, qualified name, or asset id."],
          ["flag", "Save key. Derived from the name when omitted."],
          ["value", "Starting text."],
          ["placeholder", "Text shown while the field is empty."],
          ["numeric", "true accepts digits only — the right choice for an amount or an id."],
          ["clearOnFocus", "true empties the field when the player taps it, so typing replaces instead of appending."],
          ["forgetState", "true keeps this control out of save/load."],
          ["callback", "Runs with the committed string."],
          ["info", "Optional (!) description: a badge right after the name reveals a floating description on hover, tap (tap again to close) or press-and-hold. Omitted or empty draws no badge."],
          ["infoIcon", "Replaces the (!) badge glyph. Defaults to circle-alert."],
        ]}
      />

      <H2 id="handle">Handle</H2>
      <PropTable
        headers={["Member", "Description"]}
        rows={[
          ["value", "The committed string."],
          ["Set(value, skipCallback?)", "Write the field programmatically."],
          ["MoveTo / MoveToTop / MoveToBottom / MoveUp / MoveDown", "Re-order the control."],
          ["SetInfo(text)", "Add, retarget or remove the (!) badge at runtime — an empty text removes it."],
          ["Lock(reason?) / Unlock() / IsLocked()", "Disable the field and show why — a locked input cannot be edited."],
        ]}
      />
      <Callout type="note" title="Editing versus committing">
        <p>
          The callback belongs to the committed value, not to each keystroke, so it is safe to treat it
          as a finished edit. A pending edit is discarded when its card is folded away by a{" "}
          <Link href="/docs/elements/collapsible-group" className="text-accent hover:underline">
            collapsible group
          </Link>
          .
        </p>
      </Callout>
      <Callout type="tip" title="Inputs are tab-only">
        <p>
          <C>CreateInput</C> exists on tabs. Groups can hold compact controls — see{" "}
          <Link href="/docs/tabs#groups" className="text-accent hover:underline">
            Tabs and groups
          </Link>
          .
        </p>
      </Callout>
    </>
  );
}
