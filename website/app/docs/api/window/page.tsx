import Link from "next/link";
import { CodeBlock } from "@/components/code-block";
import { C, Callout, H2, PageHeader, TypeTable } from "@/components/content";
import { docsMetadata } from "@/lib/docs";

export const metadata = docsMetadata({
  title: "CreateWindow props",
  description: "Every property Astra's window constructor accepts: title, subtitle, icon, theme, capsule name and icon, fallback font, translations and the legacy configuration override.",
  path: "/docs/api/window/",
});

export default function CreateWindowProps() {
  return (
    <>
      <PageHeader
        title="CreateWindow props"
        description="One table, every field optional, camelCase or PascalCase. Only name really matters."
      />

      <H2 id="props">Props</H2>
      <TypeTable
        rows={[
          ["name", "string", "The title on the left of the topbar. Defaults to \"Astra Window\"."],
          ["subtitle", "string", "Small text next to the title."],
          ["icon", "(string | number)", "Topbar icon: a pack name, a qualified name, or an asset id."],
          ["theme", "string | table", "A built-in theme name or a custom theme table. See Themes."],
          ["showName", "string", "The name shown when the window is minimised to the capsule. Default \"Astra\"."],
          ["showIcon", "(string | number)", "The capsule's icon. Defaults to the same icon the topbar uses."],
          ["showIconOnly", "boolean", "true makes the capsule show only its icon, with no name."],
          ["fallbackFont", "Font | Enum.Font", "The font used when the brand font cannot load."],
          ["locale", "string", "The active locale. Defaults to the runtime's detected locale."],
          ["translations", "{ [locale]: { [source]: string } }", "Translation tables to register at construction."],
          ["translator", "(source, localeId) -> string?", "A custom resolver, used instead of the registered tables."],
          ["configuration", "{ autoSave, autoLoad, fileName, customFolder }", "Legacy override for the persistence settings. Normal usage needs nothing here."],
        ]}
      />
      <Callout type="note" title="What is deliberately not a prop">
        <p>
          Layout. The window ships the sidebar and collapsed-sidebar layouts and the player
          chooses in <strong>Settings → Appearance → Bar Layout</strong>. There is no{" "}
          <C>sidebarLayout</C> argument. The theme is still a prop — it is the starting palette, and
          the player can change that too.
        </p>
      </Callout>

      <H2 id="configuration">The configuration override</H2>
      <div className="prose-docs">
        <p>
          Existing scripts that pass a <C>configuration</C> table keep working. The defaults are the
          same values the Persistence settings show:
        </p>
      </div>
      <TypeTable
        headers={["Field", "Type", "Description"]}
        rows={[
          ["autoSave", "boolean", "Save supported control values automatically. Default true."],
          ["autoLoad", "boolean", "Restore the default configuration on the next startup. Default true."],
          ["fileName", "string", "Name used for saved configurations. Default \"Astra-Hub\"."],
          ["customFolder", "string", "Folder the runtime writes into. Default \"AstraConfigs\"."],
        ]}
      />
      <div className="prose-docs">
        <p>
          Saved built-in save/load preferences take precedence over the override, so a player&apos;s
          choice in Settings is not silently replaced by a constructor argument.
        </p>
      </div>

      <H2 id="example">Full example</H2>
      <CodeBlock
        code={`local window = Astra:CreateWindow({
    name = "My UI",                   -- title (left side of the topbar)
    subtitle = "v1.0",                -- small text next to the title
    icon = "house",                   -- topbar icon (pack name or asset id)
    theme = "amethyst",               -- built-in name or a custom theme table
    showName = "Astra",               -- capsule label when minimised
    showIconOnly = false,             -- capsule shows only the icon
    fallbackFont = Enum.Font.Gotham,  -- font used when the brand font cannot load
    locale = "en",
    translations = {
        en = { play = "Play" },
        de = { play = "Spielen" },
    },
})

-- Everything else is a method on the window:
window:CreateTab({ name = "Home", icon = "house" })
window:SetProfile({ subtitle = "Beta tester", tier = "PREMIUM" })`}
      />
      <div className="prose-docs">
        <p>
          The runtime methods live on <Link href="/docs/windows">Windows</Link>, and{" "}
          <Link href="/docs/api/methods">Method index</Link> lists every method of every handle in one
          place.
        </p>
      </div>
    </>
  );
}
