import { CommandLine } from "@/components/code-block";
import { C, Callout, H2, PageHeader, PropTable, TypeTable } from "@/components/content";
import { REPO_URL, docsMetadata } from "@/lib/docs";

export const metadata = docsMetadata({
  title: "Agent skill",
  description: "Install the astra Agent Skill so Claude Code, Cursor, Codex or any SKILL.md-aware agent knows the loader contract, the element cheat sheet and the repository rules.",
  path: "/docs/skill/",
});

export default function Skill() {
  return (
    <>
      <PageHeader
        title="Agent skill"
        description="This repository is an Agent Skill source as well as a library. The skill teaches a coding agent how to build Astra interfaces and how to work on the library itself."
        meta={<span className="pill">skills/astra/SKILL.md</span>}
      />

      <H2 id="install">Install</H2>
      <CommandLine command="npx skills add Kira762/astra-version-1" caption="agent skill" />
      <div className="prose-docs">
        <p>
          For a non-interactive install into a specific set of agents, name the skill and the agents
          explicitly:
        </p>
      </div>
      <CommandLine
        command="npx skills add Kira762/astra-version-1 --skill astra -a claude-code -a cursor -y"
        caption="non-interactive install"
      />
      <div className="prose-docs">
        <p>
          Skills are installed into the agent&apos;s skills folder — project-level by default,
          user-level with <C>-g</C> — and can be refreshed with <C>npx skills update</C>. The listing
          lives at{" "}
          <a href="https://skills.sh/Kira762/astra-version-1" target="_blank" rel="noreferrer">
            skills.sh/Kira762/astra-version-1
          </a>
          .
        </p>
      </div>

      <H2 id="contents">What the skill contains</H2>
      <PropTable
        headers={["File", "Contents"]}
        rows={[
          ["SKILL.md", "The loader contract, API rules and an element cheat sheet."],
          ["references/elements.md", "Every element's props and handle methods."],
          ["references/window.md", "Window methods, themes, icons, motion and persistence."],
          ["references/repo-workflow.md", "Bundle generation, the syntax gate, tests, and the documentation rules."],
          ["assets/example-window.luau", "A copy-paste starter covering every element type."],
        ]}
      />
      <Callout type="tip" title="Why it exists">
        <p>
          An agent without the skill will happily invent a <C>sidebarLayout</C> argument or call{" "}
          <C>tab:CreateColorPicker</C>. The skill is the same contract these pages describe, written
          for a reader that has to get it right the first time.
        </p>
      </Callout>

      <H2 id="repo-skills">Skills in this checkout</H2>
      <div className="prose-docs">
        <p>
          Working inside the repository, the following third-party skills are installed in{" "}
          <C>.agents/skills/</C> and symlinked into <C>.claude/skills/</C> (they keep their upstream
          authorship and are not published from here):
        </p>
      </div>
      <TypeTable
        headers={["Skill", "Source", "Why it is here"]}
        rows={[
          ["frontend-design", "anthropics/skills", "Visual-design judgement for element, theme and layout work."],
          ["web-design-guidelines", "vercel-labs/agent-skills", "Reviewing the docs site against web interface guidelines: accessibility, focus states, motion and copy."],
          ["vercel-react-best-practices", "vercel-labs/agent-skills", "React and Next.js performance patterns for the docs site itself."],
          ["writing-guidelines", "vercel-labs/agent-skills", "Prose quality for pages like the ones you are reading."],
          ["doc-coauthoring", "anthropics/skills", "A structured workflow for writing and revising long-form documentation."],
          ["skill-creator", "anthropics/skills", "Authoring and refining the astra skill."],
          ["diagnosing-bugs", "mattpocock/skills", "Reproduce-then-fix discipline for changelog entries."],
          ["codebase-design", "mattpocock/skills", "Architecture decisions across the modular tree."],
          ["find-skills", "vercel-labs/skills", "Discovering more skills when a task needs one."],
        ]}
      />
      <div className="prose-docs">
        <p>
          The full table, with links to each upstream repository, is in the{" "}
          <a href={`${REPO_URL}#third-party-skills-in-this-checkout`} target="_blank" rel="noreferrer">
            repository README
          </a>
          .
        </p>
      </div>
    </>
  );
}
