import Link from "next/link";
import { CodeBlock } from "@/components/code-block";
import { C, Callout, H2, PageHeader, PropTable } from "@/components/content";
import { docsMetadata } from "@/lib/docs";

export const metadata = docsMetadata({
  title: "Windows",
  description: "Create an Astra window, switch between sidebar and collapsed-sidebar layouts, and drive it at runtime: Navigate, Notify, Popup, ChangeTheme, Save, Unload.",
  path: "/docs/windows/",
});

export default function Windows() {
  return (
    <>
      <PageHeader
        title="Windows"
        description="Create the window, then control it at runtime. Everything else in the library hangs off the window handle."
      />

      <H2 id="create">CreateWindow</H2>
      <div className="prose-docs">
        <p>
          <C>Astra:CreateWindow</C> takes one table and returns a window. Only <C>name</C> matters in
          practice; everything else has a working default.
        </p>
      </div>
      <CodeBlock
        code={`local window = Astra:CreateWindow({
    name = "Example Hub",
    subtitle = "Astra",
    icon = "house",          -- topbar icon: pack name or asset id
    theme = "amethyst",      -- a built-in name or a custom theme table
})`}
      />
      <div className="prose-docs">
        <p>
          The full prop list — including <C>showName</C>, <C>showIconOnly</C>,{" "}
          <C>fallbackFont</C> and the localization props — is on{" "}
          <Link href="/docs/api/window">CreateWindow props</Link>. Note that layout is deliberately
          not one of them.
        </p>
      </div>

      <H2 id="layout">Layouts</H2>
      <div className="prose-docs">
        <p>
          The window ships two layouts and the player picks one in{" "}
          <strong>Settings → Appearance → Bar Layout</strong>:
        </p>
        <ul>
          <li>
            <strong>Sidebar</strong> — tabs move into a rail down the side, where{" "}
            <C>window:CreateSection</C> headings group them.
          </li>
          <li>
            <strong>Collapsed sidebar</strong> — the rail shows icons only until it is expanded.
          </li>
        </ul>
        <p>
          The window can also be minimised to a capsule: <C>window:ToggleMinimise()</C> folds it into
          a small pill that keeps its icon and, unless <C>showIconOnly</C> is set, the{" "}
          <C>showName</C> label. Minimising is a lateral state change, so it moves through the{" "}
          <C>glide</C> motion spec.
        </p>
      </div>

      <H2 id="methods">Window methods</H2>
      <PropTable
        headers={["Method", "Description"]}
        rows={[
          ["CreateTab({ name, icon })", "Create a tab. Returns a Tab."],
          ["CreateSection({ name, icon })", "Top-level rail heading — a TabSection. Sidebar layout only."],
          ["Notify({ title, content, icon, duration })", "Classic notification, opened on the entrance queue."],
          ["Popup({ title, content, boxes, options, … })", "Modal popup. Returns Popup:Close()."],
          ["Navigate(tab)", "Select a tab by name or by Tab object."],
          ["Show() / Hide() / ToggleHide()", "Visibility."],
          ["ToggleMinimise()", "Collapse or expand the rail."],
          ["Close()", "Animated close; the topbar action adds the confirm popup. Unloads when the transition finishes."],
          ["Save(name?) / Load(name?)", "Save or restore flags, optionally under a named configuration."],
          ["ListConfigs()", "Array of saved configuration names."],
          ["DeleteConfig(name)", "Delete a saved configuration."],
          ["Get(flag) / Set(flag, value)", "Read and write values by flag."],
          ["ChangeTheme(theme)", "Swap the theme at runtime — a built-in name or a table."],
          ["SetLocale(id) / SetTranslator(fn) / RegisterTranslations(t)", "Localization."],
          ["ResolveIcon(value, pack?)", "Resolve an icon name to an asset, across packs or from one pack."],
          ["GetPath()", "Returns the (folder, file) persistence path."],
          ["Unload()", "Destroy the window."],
          ["window.Flags", "Not a method: a table of every registered flag's current value."],
        ]}
      />

      <H2 id="flags">Flags and lookup</H2>
      <div className="prose-docs">
        <p>
          Flags are how the rest of your script talks to the interface. A control that was given a
          flag joins save/load; a control without one gets a flag derived from its name.
        </p>
      </div>
      <CodeBlock
        code={`tab:CreateToggle({ name = "Auto Sprint", flag = "autoSprint", value = true })

window:Set("autoSprint", false)      -- writes the flag (and the control, if one owns it)
print(window:Get("autoSprint"))      -- false
print(window.Flags.autoSprint)       -- the same value, straight off the table

window:Navigate("Home")              -- by tab name …
window:Navigate(tab)                 -- … or by handle`}
      />
      <Callout type="note" title="Set is not a silent write">
        <p>
          Writing a flag updates anything bound to it, which is why{" "}
          <Link href="/docs/saving">Saving and flags</Link> recommends explicit flags for controls whose
          labels may change — the flag, not the title, is the stable key.
        </p>
      </Callout>

      <H2 id="profile">Profile card</H2>
      <div className="prose-docs">
        <p>
          The profile card is a compact panel that sits beside the window in one centred pair.
          <C>SetProfile</C> fills it with real data and invents nothing: pass a string, or{" "}
          <C>nil</C>, to set just the subtitle line, or a table for the whole payload.
        </p>
      </div>
      <CodeBlock
        code={`window:SetProfile({
    subtitle = "Beta tester",        -- replaces the @username line
    key = "ASTRA-XXXX-XXXX",         -- masked until "Reveal profile details"
    tier = "PREMIUM",                -- the header pill's word
    whitelist = { status = "Active", daysLeft = 14 },   -- or expiresAt = os.time() + n
})`}
      />
      <div className="prose-docs">
        <p>
          Fields you leave out read <C>—</C>, and the row set stays masked until the window&apos;s{" "}
          <strong>Reveal profile details</strong> setting is on. The masked rows always come from the
          player and the running server, never from this table.
        </p>
      </div>

      <H2 id="helpers">Runtime helpers</H2>
      <div className="prose-docs">
        <p>
          These are used by the library internals and are safe to call from extensions. They keep your
          additions consistent with the window&apos;s theme and locale bindings.
        </p>
      </div>
      <PropTable
        headers={["Helper", "What it is for"]}
        rows={[
          ["Create(className, props, themeBindings?)", "Instance factory that also applies theme and locale bindings."],
          ["Connect(signal, fn)", "Tracked connection, cleaned up with the window."],
          ["ConnectFor(element, signal, fn)", "The same, scoped to an element."],
          ["Disconnect(connection) / DisconnectMany(list)", "Explicit teardown."],
          ["DestroySubtree(instance) / DestroySubtrees(list)", "Destroy instances without leaving connections behind."],
          ["CreateGlow(parent, color, blurRadius, transparency)", "The glow used behind accents."],
          ["CreateHoverOverlay(parent)", "The standard hover surface."],
          ["StyleElementBody(frame) / StyleElementPanel(frame)", "Apply the element card and panel styling."],
          ["SaveSettings() / LoadSettings()", "Read and write this window's settings."],
        ]}
      />
    </>
  );
}
