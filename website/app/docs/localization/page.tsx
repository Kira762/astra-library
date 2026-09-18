import { CodeBlock } from "@/components/code-block";
import { C, Callout, H2, PageHeader, PropTable } from "@/components/content";
import { docsMetadata } from "@/lib/docs";

export const metadata = docsMetadata({
  title: "Localization",
  description: "Translate every Astra label at runtime: register translations, switch locale, or hand the window a resolver of your own.",
  path: "/docs/localization/",
});

export default function Localization() {
  return (
    <>
      <PageHeader
        title="Localization"
        description="Translate every label at runtime, from a table you register or a resolver you own."
        meta={
          <>
            <span className="pill">source strings are English</span>
            <span className="pill">per window</span>
          </>
        }
      />

      <H2 id="usage">Usage</H2>
      <CodeBlock
        code={`window:RegisterTranslations({
    en = { play = "Play" },
    de = { play = "Spielen" },
})

window:SetLocale("de")        -- retypes every label the window owns

-- or take over resolution entirely
window:SetTranslator(function(source, localeId)
    return myDictionary[localeId]?[source]
end)`}
      />
      <div className="prose-docs">
        <p>
          The source strings are the English labels you already wrote, which is why a translation table
          only lists what changes: any key you leave out falls back to the string as written.
        </p>
      </div>

      <H2 id="api">API</H2>
      <PropTable
        headers={["Method or prop", "Description"]}
        rows={[
          ["window:RegisterTranslations(t)", "Merge a table of { locale = { source = translation } } into the window."],
          ["window:SetLocale(id)", "Switch the language. Labels are retyped in place."],
          ["window:SetTranslator(fn)", "Set a custom resolver: (source, localeId) -> string. Return nil to fall back to the source string."],
          ["translations", "The constructor prop equivalent of RegisterTranslations."],
          ["locale", "The constructor prop equivalent of SetLocale."],
          ["translator", "The constructor prop equivalent of SetTranslator."],
        ]}
      />
      <Callout type="note" title="Translations reach measured layouts too">
        <p>
          Labels you set through the window are locale-bound: when the locale changes, a control whose
          card grew for a wrapped description re-measures rather than keeping the old height.
        </p>
      </Callout>
      <Callout type="tip" title="Keep the dictionary out of the window">
        <p>
          A hub with many languages is easier to keep tidy when the tables live next to the script and
          are handed over in one <C>RegisterTranslations</C> call at startup.
        </p>
      </Callout>
    </>
  );
}
