import { CodeBlock } from "@/components/code-block";
import { C, Callout, H2, PageHeader, PropTable } from "@/components/content";
import { docsMetadata } from "@/lib/docs";

export const metadata = docsMetadata({
  title: "Dropdown",
  description: "Create an Astra dropdown element: one option or multi-select, searchable as you type, with Refresh, Add and Remove on the handle.",
  path: "/docs/elements/dropdown/",
});

export default function Dropdown() {
  return (
    <>
      <PageHeader
        title="Dropdown"
        description="Choose one option, or several. Filters as you type."
        meta={<span className="pill">tab:CreateDropdown</span>}
      />

      <H2 id="usage">Usage</H2>
      <CodeBlock
        code={`local dropdown = tab:CreateDropdown({
    name = "Preset",
    flag = "preset",
    options = { "Low", "Medium", "High" },
    value = "Medium",
    multiSelect = true,
    placeholder = "Pick items",
    callback = function(selected) print(selected) end,
})

dropdown:Refresh({ "A", "B" })   -- replace the option list
dropdown:Add("C")                -- append one option
dropdown:Remove("A")             -- remove one option`}
      />

      <H2 id="props">Props</H2>
      <PropTable
        rows={[
          ["name", "The label on the card."],
          ["icon", "Left-hand icon: pack name, qualified name, or asset id."],
          ["flag", "Save key. Derived from the name when omitted."],
          ["options", "Array of strings."],
          ["value", "A string for single-select, or a table of strings for multiSelect."],
          ["multiSelect", "true lets the player pick more than one option; the callback receives a table."],
          ["placeholder", "Text shown while nothing is selected."],
          ["forgetState", "true keeps this control out of save/load."],
          ["callback", "Runs with the selection — a string, or a table when multiSelect is on."],
          ["info", "Optional (!) description: a badge right after the name reveals a floating description on hover, tap (tap again to close) or press-and-hold. Omitted or empty draws no badge."],
          ["infoIcon", "Replaces the (!) badge glyph. Defaults to circle-alert."],
        ]}
      />

      <H2 id="handle">Handle</H2>
      <PropTable
        headers={["Method", "Description"]}
        rows={[
          ["Set(value, skipCallback?)", "Select a string, or a table of strings, without firing the callback when the second argument is true."],
          ["Refresh(options)", "Replace the whole option list."],
          ["Add(option)", "Append a single option."],
          ["Remove(option)", "Remove a single option."],
          ["MoveTo / MoveToTop / MoveToBottom / MoveUp / MoveDown", "Re-order the control."],
          ["SetInfo(text)", "Add, retarget or remove the (!) badge at runtime — an empty text removes it."],
          ["Lock(reason?) / Unlock() / IsLocked()", "Disable the control and show why."],
        ]}
      />
      <Callout type="note" title="Multi-select always hands back a table">
        <p>
          With <C>multiSelect = true</C> the callback&apos;s argument is a list even when one option is
          chosen, so branching on the type never surprises you.
        </p>
      </Callout>
    </>
  );
}
