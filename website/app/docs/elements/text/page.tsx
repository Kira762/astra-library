import { CodeBlock } from "@/components/code-block";
import { C, Callout, H2, PageHeader, PropTable } from "@/components/content";
import { docsMetadata } from "@/lib/docs";

export const metadata = docsMetadata({
  title: "Text, Divider and Group",
  description: "Create Astra text, divider and group elements: titles and body copy on a card, rules with an optional word, and nested rows and columns.",
  path: "/docs/elements/text/",
});

export default function TextDividerGroup() {
  return (
    <>
      <PageHeader
        title="Text, Divider and Group"
        description="Titles, body copy, rules across the page, and the containers that lay other elements out."
      />

      <H2 id="text">Text</H2>
      <div className="prose-docs">
        <p>
          A text element is a card with an optional title and an optional body, and both are writable
          after the fact.
        </p>
      </div>
      <CodeBlock
        code={`local text = tab:CreateText({ name = "Title", text = "Body text", icon = "info" })

text:Set("New body")        -- replace the body
text:SetTitle("New title")  -- replace the title`}
      />
      <PropTable
        headers={["Prop", "Description"]}
        rows={[
          ["name", "The card title."],
          ["text", "The body copy."],
          ["icon", "Left-hand icon next to the title."],
        ]}
      />

      <H2 id="divider">Divider</H2>
      <div className="prose-docs">
        <p>
          A divider is a horizontal rule with an optional word in the middle. Both the word, the
          spacing and the line itself can be turned off.
        </p>
      </div>
      <CodeBlock
        code={`tab:CreateDivider()                          -- a plain rule
tab:CreateDivider({ text = "or" })           -- a word in the middle
tab:CreateDivider({ line = false, spacing = 8 })  -- space only

local divider = tab:CreateDivider({ text = "or" })
divider:Set("and")   -- replace the word; Set(nil) clears it`}
      />
      <PropTable
        headers={["Prop", "Description"]}
        rows={[
          ["text", "The word rendered in the middle of the rule."],
          ["line", "false draws nothing and leaves only the gap."],
          ["spacing", "Extra vertical space around the divider."],
        ]}
      />

      <H2 id="group">Group</H2>
      <div className="prose-docs">
        <p>
          A group lays elements out side by side as a row, or stacked as a column with{" "}
          <C>direction = &quot;column&quot;</C>. Groups nest, and a group that holds something
          non-compact switches to a column on its own so nothing is silently dropped.
        </p>
      </div>
      <CodeBlock
        code={`local row = tab:CreateGroup()                            -- row
local col = row:CreateGroup({ direction = "column" })    -- nested column

col:CreateToggle({ name = "Left 1" })
col:CreateSlider({ name = "Left 2", range = { 0, 100 }, value = 50 })

-- a group can hold: Button, Toggle, Slider, Dropdown, Stat,
-- Section, Text, Divider and other Groups`}
      />
      <PropTable
        headers={["Group member", "Description"]}
        rows={[
          ["direction", "The one prop: \"row\" (default) or \"column\"."],
          ["CreateButton / CreateToggle / CreateSlider", "Compact controls, made for rows."],
          ["CreateDropdown / CreateStat", "Also available inside groups."],
          ["CreateSection / CreateText / CreateDivider", "Headings, copy and rules inside the group."],
          ["CreateGroup", "Nest another group, any direction."],
          ["MoveTo / MoveToTop / MoveToBottom / MoveUp / MoveDown", "Re-order the group inside its parent."],
        ]}
      />
      <Callout type="warning" title="Inputs and collapsible groups stay on the tab">
        <p>
          <C>CreateInput</C> and <C>CreateCollapsibleGroup</C> are tab-only. A group can hold every
          compact control plus groups of its own.
        </p>
      </Callout>
      <Callout type="tip" title="Descriptions work here too">
        <p>
          Elements in this family accept the shared <C>description</C> line, which also doubles as the
          lock message on lockable controls.
        </p>
      </Callout>
    </>
  );
}
