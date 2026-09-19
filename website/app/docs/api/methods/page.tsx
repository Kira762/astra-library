import Link from "next/link";
import { C, H2, PageHeader, PropTable } from "@/components/content";
import { docsMetadata } from "@/lib/docs";

export const metadata = docsMetadata({
  title: "Method index",
  description: "Every Astra method in one place: window, tab, group and element handles, including the shared Moveable and Lockable surface.",
  path: "/docs/api/methods/",
});

export default function Methods() {
  return (
    <>
      <PageHeader
        title="Method index"
        description="The whole runtime surface, by handle. Each entry links to the page that explains it."
      />

      <H2 id="window">Window</H2>
      <PropTable
        headers={["Method", "Notes"]}
        rows={[
          ["CreateTab({ name, icon, locked })", "Returns a Tab; locked = true builds it gated (lock badge, unopenable by the user)."],
          ["CreateSection({ name, icon })", "Rail heading — sidebar layout only; returns a TabSection with Remove()."],
          ["Notify({ title, content, icon, duration })", "Queued arrival; dismisses on click or timeout."],
          ["Popup(props)", "Modal card; returns a Popup with Close()."],
          ["Navigate(tab)", "By name or by Tab object."],
          ["Show() / Hide() / ToggleHide()", "Visibility."],
          ["ToggleMinimise()", "Fold into the capsule and back."],
          ["Close()", "Confirm popup, animated close, unload when done."],
          ["Save(name?) / Load(name?)", "Flags, optionally as a named configuration."],
          ["ListConfigs() / DeleteConfig(name)", "Manage saved configurations."],
          ["Get(flag) / Set(flag, value)", "Read a value; Set returns false when no control owns the flag."],
          ["ChangeTheme(theme)", "Built-in name or a table."],
          ["SetLocale(id) / SetTranslator(fn) / RegisterTranslations(t)", "Localization."],
          ["ResolveIcon(value, pack?)", "Icon lookup across all packs, or within one."],
          ["GetPath()", "(folder, file) that persistence writes to."],
          ["SetProfile(profile)", "String or table; returns the subtitle line."],
          ["SaveSettings() / LoadSettings()", "This window's settings."],
          ["Unload()", "Destroy the window and its connections."],
          ["Flags (property)", "Table of registered flags, readable and iterable."],
        ]}
      />

      <H2 id="tab">Tab</H2>
      <PropTable
        headers={["Method", "Notes"]}
        rows={[
          ["Select(noAnimation?) / Deselect(noAnimation?)", "Switch tabs."],
          ["SetLocked(locked)", "Lock or unlock the tab — host-only, per-session. Locking the open tab moves the selection away; see Tabs and groups."],
          ["Remove()", "Destroy the tab."],
          ["CreateButton / CreateToggle / CreateSlider", "Compact controls."],
          ["CreateDropdown / CreateInput / CreateStat", "Tab-level controls."],
          ["CreateSection / CreateText / CreateDivider", "Headings, copy and rules."],
          ["CreateGroup(props?)", "Row (default) or column with direction = \"column\"."],
          ["CreateCollapsibleGroup(props)", "Declarative; tab-only."],
          ["CreateChangelog(props)", "Release history element."],
        ]}
      />

      <H2 id="group">Group</H2>
      <PropTable
        headers={["Method", "Notes"]}
        rows={[
          ["CreateButton / CreateToggle / CreateSlider / CreateStat", "Compact controls, side by side or stacked."],
          ["CreateDropdown", "Available inside groups."],
          ["CreateSection / CreateText / CreateDivider", "Headings, copy and rules inside the group."],
          ["CreateGroup(props?)", "Nest another group, any direction."],
          ["MoveTo / MoveToTop / MoveToBottom / MoveUp / MoveDown", "Re-order the group in its parent."],
        ]}
      />
      <div className="prose-docs">
        <p>
          A collapsible group is declarative only: its controls arrive in the constructor&apos;s{" "}
          <C>elements</C> list, and the created handles are readable afterwards from the same{" "}
          <C>elements</C> array in definition order.
        </p>
      </div>

      <H2 id="handles">Element handles</H2>
      <PropTable
        headers={["Handle", "Specific members"]}
        rows={[
          ["Button", "callback only — plus Moveable and Lockable."],
          ["Toggle", "value; Set(value, skipCallback?)"],
          ["Slider", "value; Set(value, skipCallback?)"],
          ["Dropdown", "value; Set(value, skipCallback?); Refresh(options); Add(option); Remove(option)"],
          ["Input", "value; Set(value, skipCallback?)"],
          ["Stat", "value; Set(value); SetText(text); ResetBaseline(value?)"],
          ["Text", "name; text; Set(text); SetTitle(title)"],
          ["Divider", "text; Set(text?)"],
          ["Changelog", "Set(entries); Refresh(entries); Add(entry, prepend?); Clear()"],
          ["Section", "Moveable only."],
          ["CollapsibleGroup", "elements ({ handle } in definition order); Moveable; Lockable."],
          ["Popup", "Close()"],
          ["TabSection", "Remove()"],
        ]}
      />

      <H2 id="shared">Shared surface</H2>
      <PropTable
        headers={["Surface", "Methods"]}
        rows={[
          ["Moveable (every element)", "MoveTo(index); MoveToTop(); MoveToBottom(); MoveUp(); MoveDown()"],
          ["Lockable (most elements)", "Lock(reason?); Unlock(); IsLocked() — the reason takes over the description line."],
        ]}
      />
      <div className="prose-docs">
        <p>
          Not sure which control fits? <Link href="/docs/elements">Elements overview</Link> lists all
          eleven with a page each, and <Link href="/docs/tabs#groups">Tabs and groups</Link> covers what
          each container can hold.
        </p>
      </div>
    </>
  );
}
