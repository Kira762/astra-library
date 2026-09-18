import { CodeBlock } from "@/components/code-block";
import { Callout, H2, PageHeader, PropTable } from "@/components/content";
import { docsMetadata } from "@/lib/docs";

export const metadata = docsMetadata({
  title: "Changelog element",
  description: "Render release history inside an Astra window: entries with versions, dates, titles and symbol-coded changes, plus Set, Refresh, Add and Clear.",
  path: "/docs/elements/changelog/",
});

export default function ChangelogElement() {
  return (
    <>
      <PageHeader
        title="Changelog"
        description="Release history renders as a standalone element wherever it is declared."
        meta={<span className="pill">tab:CreateChangelog</span>}
      />

      <H2 id="usage">Usage</H2>
      <CodeBlock
        code={`local log = tab:CreateChangelog({
    name = "Release history",
    emptyText = "No entries yet.",
    entries = {
        {
            version = "0.0.35",
            date = "2026-09-11",
            title = "Settings highlight",
            changes = {
                { symbol = "~", category = "Fixed", text = "Settings stays highlighted while its tab is active." },
                { symbol = "+", text = "Added the changelog element." },
            },
        },
    },
})

log:Add({ version = "Live", date = "Today", changes = { { symbol = "+", text = "Runtime entry." } } })
log:Set({ ... })     -- replace every entry
log:Clear()          -- empty the panel`}
      />

      <H2 id="entries">Entry shape</H2>
      <PropTable
        headers={["Field", "Description"]}
        rows={[
          ["version", "The version label for the release."],
          ["date", "A date string, shown as written."],
          ["title", "The headline for the release."],
          ["game / gameId", "Optional game attribution for multi-game hubs."],
          ["changes", "A list of change rows."],
        ]}
      />
      <PropTable
        headers={["Change field", "Description"]}
        rows={[
          ["symbol", "\"+\", \"-\" or \"~\" — added, removed, changed."],
          ["text", "The change itself, in one sentence."],
          ["category", "Optional label, e.g. \"Fixed\"."],
        ]}
      />

      <H2 id="symbols">Symbols and colours</H2>
      <div className="prose-docs">
        <ul>
          <li>
            <strong>+ and added</strong> — green.
          </li>
          <li>
            <strong>− and removed</strong> — red.
          </li>
          <li>
            <strong>~ and changed</strong> — amber.
          </li>
        </ul>
        <p>
          The words <code className="icode">added</code>, <code className="icode">removed</code> and{" "}
          <code className="icode">changed</code> map to the same colours as the symbols, so a data file
          can use whichever reads better.
        </p>
      </div>

      <H2 id="handle">Handle</H2>
      <PropTable
        headers={["Method", "Description"]}
        rows={[
          ["Set(entries)", "Replace every entry."],
          ["Refresh(entries)", "Re-render with a new list."],
          ["Add(entry, prepend?)", "Add one release, optionally at the top."],
          ["Clear()", "Remove all entries — the emptyText shows instead."],
          ["MoveTo / MoveToTop / MoveToBottom / MoveUp / MoveDown", "Re-order the element."],
        ]}
      />
      <Callout type="tip" title="Keep the history in its own file">
        <p>
          The element takes plain tables, so the release history can live beside your script as data.
          The repository ships <code className="icode">changelog.example.luau</code> as the shape to
          copy.
        </p>
      </Callout>
    </>
  );
}
