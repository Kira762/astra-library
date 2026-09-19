/**
 * The documentation map: navigation tree, page metadata, on-page contents and
 * the search index all derive from this one file, so a new page is added in a
 * single place and shows up in the sidebar, the search dialog and the
 * previous/next pager at once.
 */

export type TocItem = { id: string; label: string };

export type DocPage = {
  /** Route without a base path, e.g. "/docs/elements/toggle". */
  href: string;
  title: string;
  description: string;
  /** Section headings on the page, top to bottom. */
  toc: TocItem[];
  /** Extra words the search dialog should match beyond title/description. */
  keywords?: string[];
  kind?: "element" | "api";
};

export type NavGroup = { label: string; pages: DocPage[] };

/**
 * Page metadata for a docs route: the page's own title and description, a
 * canonical URL for the Pages sub-path, and a complete Open Graph block (Next
 * replaces, rather than merges, a nested metadata object).
 */
export function docsMetadata({
  title,
  description,
  path,
}: {
  title: string;
  description: string;
  path: string;
}) {
  const url = `${SITE_URL}${path}`;
  return {
    title,
    description,
    alternates: { canonical: path },
    openGraph: {
      type: "article" as const,
      url,
      siteName: "Astra v1",
      title: `${title} · Astra v1`,
      description,
    },
    twitter: {
      card: "summary_large_image" as const,
      title: `${title} · Astra v1`,
      description,
    },
  };
}

export const HOME: Omit<DocPage, "toc"> & { toc: TocItem[] } = {
  href: "/",
  title: "Astra v1",
  description: "Luau interface library for Roblox executor scripts.",
  toc: [],
};

export const NAV: NavGroup[] = [
  {
    label: "Get started",
    pages: [
      {
        href: "/docs",
        title: "Introduction",
        description: "What Astra is, what it needs, and what ships in the box.",
        toc: [
          { id: "what-it-is", label: "What Astra is" },
          { id: "requirements", label: "Requirements" },
          { id: "in-the-box", label: "What ships in the box" },
          { id: "next-steps", label: "Where to go next" },
          { id: "agent-skill", label: "Install the agent skill" },
        ],
        keywords: ["overview", "intro", "install", "features"],
      },
      {
        href: "/docs/getting-started",
        title: "Getting started",
        description: "Load the bundle and build your first window in a few lines.",
        toc: [
          { id: "load", label: "Load the library" },
          { id: "failed-load", label: "When the loader fails" },
          { id: "first-window", label: "Your first window" },
          { id: "next", label: "Where to go next" },
        ],
        keywords: ["loader", "loadstring", "HttpGet", "one-liner", "first window", "quickstart"],
      },
      {
        href: "/docs/startup",
        title: "Startup performance",
        description: "How the window is built across frames, and what stays lazy.",
        toc: [
          { id: "staged", label: "Staged construction" },
          { id: "auto-show", label: "Automatic show" },
          { id: "arrival", label: "The arrival" },
          { id: "notify-queue", label: "Notification queue" },
          { id: "lazy", label: "What stays lazy" },
        ],
        keywords: ["performance", "yield", "budget", "instances", "frames"],
      },
    ],
  },
  {
    label: "Building an interface",
    pages: [
      {
        href: "/docs/windows",
        title: "Windows",
        description: "Create the window, then control it at runtime.",
        toc: [
          { id: "create", label: "CreateWindow" },
          { id: "layout", label: "Layouts" },
          { id: "methods", label: "Window methods" },
          { id: "flags", label: "Flags and lookup" },
          { id: "profile", label: "Profile card" },
          { id: "helpers", label: "Runtime helpers" },
        ],
        keywords: ["CreateWindow", "topbar", "sidebar", "methods", "window", "SetProfile"],
      },
      {
        href: "/docs/tabs",
        title: "Tabs and groups",
        description: "Split a window into tabs, then lay controls out in groups.",
        toc: [
          { id: "tabs", label: "Tabs" },
          { id: "locked", label: "Locked tabs" },
          { id: "groups", label: "Groups" },
          { id: "sections", label: "Sections" },
        ],
        keywords: ["CreateTab", "CreateGroup", "row", "column", "section", "Select", "locked", "SetLocked"],
      },
      {
        href: "/docs/elements",
        title: "Elements overview",
        description: "What every element shares, and how their handles behave.",
        toc: [
          { id: "shared", label: "Shared behaviour" },
          { id: "handles", label: "Handles" },
          { id: "index", label: "Element index" },
          { id: "flags", label: "Flags and persistence" },
        ],
        keywords: ["elements", "Moveable", "Lockable", "icons", "description"],
      },
      {
        href: "/docs/elements/button",
        title: "Button",
        description: "Run a function when the player clicks.",
        toc: [
          { id: "usage", label: "Usage" },
          { id: "tap-glyph", label: "Tap glyph" },
          { id: "props", label: "Props" },
        ],
        kind: "element",
        keywords: ["CreateButton", "click", "tap", "callback", "action"],
      },
      {
        href: "/docs/elements/toggle",
        title: "Toggle",
        description: "Switch a boolean on and off.",
        toc: [
          { id: "usage", label: "Usage" },
          { id: "handle", label: "Handle" },
          { id: "props", label: "Props" },
        ],
        kind: "element",
        keywords: ["CreateToggle", "Switch", "boolean", "flag", "Set"],
      },
      {
        href: "/docs/elements/slider",
        title: "Slider",
        description: "Pick a number in a range by dragging.",
        toc: [
          { id: "usage", label: "Usage" },
          { id: "props", label: "Props" },
          { id: "handle", label: "Handle" },
        ],
        kind: "element",
        keywords: ["CreateSlider", "range", "increment", "minimal", "suffix", "dragging"],
      },
      {
        href: "/docs/elements/dropdown",
        title: "Dropdown",
        description: "Choose one option, or several. Filters as you type.",
        toc: [
          { id: "usage", label: "Usage" },
          { id: "props", label: "Props" },
          { id: "handle", label: "Handle" },
        ],
        kind: "element",
        keywords: ["CreateDropdown", "multiSelect", "options", "Refresh", "search"],
      },
      {
        href: "/docs/elements/input",
        title: "Input",
        description: "A text field that commits when the player is done.",
        toc: [
          { id: "usage", label: "Usage" },
          { id: "props", label: "Props" },
          { id: "handle", label: "Handle" },
        ],
        kind: "element",
        keywords: ["CreateInput", "numeric", "placeholder", "clearOnFocus", "text"],
      },
      {
        href: "/docs/elements/stat",
        title: "Stat",
        description: "A read-only value that rolls on change and shows how far it moved.",
        toc: [
          { id: "usage", label: "Usage" },
          { id: "display", label: "Display modes" },
          { id: "text-values", label: "Text values" },
          { id: "props", label: "Props" },
          { id: "handle", label: "Handle" },
        ],
        kind: "element",
        keywords: ["CreateStat", "change", "percentage", "delta", "baseline", "counter"],
      },
      {
        href: "/docs/elements/text",
        title: "Text, Divider and Group",
        description: "Titles, body copy, rules across the page, and nested rows.",
        toc: [
          { id: "text", label: "Text" },
          { id: "divider", label: "Divider" },
          { id: "group", label: "Group" },
        ],
        kind: "element",
        keywords: ["CreateText", "CreateDivider", "CreateGroup", "label", "paragraph", "row"],
      },
      {
        href: "/docs/elements/changelog",
        title: "Changelog",
        description: "Release history as a standalone element.",
        toc: [
          { id: "usage", label: "Usage" },
          { id: "entries", label: "Entry shape" },
          { id: "symbols", label: "Symbols and colours" },
          { id: "handle", label: "Handle" },
        ],
        kind: "element",
        keywords: ["CreateChangelog", "version", "release notes", "Add", "Clear"],
      },
      {
        href: "/docs/elements/collapsible-group",
        title: "Collapsible group",
        description: "Group controls under an animated header.",
        toc: [
          { id: "usage", label: "Usage" },
          { id: "types", label: "Supported types" },
          { id: "rules", label: "Rules" },
          { id: "behaviour", label: "Behaviour" },
        ],
        kind: "element",
        keywords: ["CreateCollapsibleGroup", "collapsed", "header", "accordion"],
      },
      {
        href: "/docs/notifications",
        title: "Notifications and popups",
        description: "Two ways to tell the player something happened.",
        toc: [
          { id: "notify", label: "Notify" },
          { id: "popup", label: "Popup" },
          { id: "options", label: "Popup options" },
        ],
        keywords: ["Notify", "Popup", "toast", "modal", "alert", "confirm"],
      },
    ],
  },
  {
    label: "Behaviour",
    pages: [
      {
        href: "/docs/saving",
        title: "Saving and flags",
        description: "State persists on its own. Read it, write it, keep more than one configuration.",
        toc: [
          { id: "settings", label: "The two toggles" },
          { id: "flags", label: "Flags" },
          { id: "configs", label: "Named configurations" },
          { id: "names", label: "Naming and sharing" },
        ],
        keywords: ["Save", "Load", "flags", "persistence", "Set", "Get", "ListConfigs", "forgetState"],
      },
      {
        href: "/docs/settings",
        title: "Built-in settings",
        description: "Every window ships a settings panel. Here is what is inside it.",
        toc: [
          { id: "how", label: "How it opens" },
          { id: "tabs", label: "The four tabs" },
          { id: "behaviour", label: "Window behaviour" },
          { id: "position", label: "Position and the profile card" },
        ],
        keywords: ["settings", "General", "Appearance", "Persistence", "About", "keybind", "gear"],
      },
      {
        href: "/docs/themes",
        title: "Themes",
        description: "Ten built-in themes, or bring your own. Swap it live.",
        toc: [
          { id: "built-in", label: "Built-in themes" },
          { id: "change", label: "Change at runtime" },
          { id: "custom", label: "Custom theme tables" },
          { id: "keys", label: "Theme keys" },
        ],
        keywords: ["ChangeTheme", "amethyst", "cobalt", "crimson", "ember", "emerald", "frost", "gold", "onyx", "rose", "palette"],
      },
      {
        href: "/docs/icons",
        title: "Icons",
        description: "Seven packs, 13,715 icons, and a folder of your own.",
        toc: [
          { id: "lookup", label: "Name-only lookup" },
          { id: "qualified", label: "Qualified names" },
          { id: "api", label: "Icons API" },
          { id: "values", label: "Passing a value through" },
          { id: "custom", label: "Custom assets" },
        ],
        keywords: ["Icons", "lucide", "material", "tabler", "phosphor", "heroicons", "feather", "remix", "ResolveIcon", "custom_asset"],
      },
      {
        href: "/docs/motion",
        title: "Motion",
        description: "One animation service behind every transition.",
        toc: [
          { id: "specs", label: "Specs" },
          { id: "api", label: "Motion API" },
          { id: "rules", label: "How it behaves" },
        ],
        keywords: ["Motion", "tween", "TweenInfo", "speed", "animation", "profile"],
      },
      {
        href: "/docs/localization",
        title: "Localization",
        description: "Translate every label at runtime, from a table or your own resolver.",
        toc: [
          { id: "usage", label: "Usage" },
          { id: "api", label: "API" },
        ],
        keywords: ["SetLocale", "SetTranslator", "RegisterTranslations", "translations", "locale", "i18n"],
      },
    ],
  },
  {
    label: "Reference",
    pages: [
      {
        href: "/docs/api/window",
        title: "CreateWindow props",
        description: "Every property the window constructor accepts.",
        toc: [
          { id: "props", label: "Props" },
          { id: "configuration", label: "The configuration override" },
          { id: "example", label: "Full example" },
        ],
        kind: "api",
        keywords: ["CreateWindow", "name", "subtitle", "icon", "theme", "showName", "translator", "fallbackFont"],
      },
      {
        href: "/docs/api/methods",
        title: "Method index",
        description: "Every window, tab, group and handle method on one page.",
        toc: [
          { id: "window", label: "Window" },
          { id: "tab", label: "Tab" },
          { id: "group", label: "Group" },
          { id: "handles", label: "Element handles" },
          { id: "shared", label: "Shared surface" },
        ],
        kind: "api",
        keywords: ["methods", "index", "reference", "MoveTo", "Lock", "Select", "Unload"],
      },
      {
        href: "/docs/repo",
        title: "Repository and deployment",
        description: "How the library, the bundle and this site are built and published.",
        toc: [
          { id: "layout", label: "Repository layout" },
          { id: "bundle", label: "The generated bundle" },
          { id: "pipeline", label: "Docs pipeline" },
          { id: "paths", label: "Why website/ cannot break Luau" },
          { id: "verify", label: "Verification commands" },
        ],
        keywords: ["monorepo", "GitHub Pages", "deploy", "Rojo", "bundle", "generate_bundle", "CI"],
      },
      {
        href: "/docs/skill",
        title: "Agent skill",
        description: "Teach a coding agent the Astra API so it stops guessing.",
        toc: [
          { id: "install", label: "Install" },
          { id: "contents", label: "What the skill contains" },
          { id: "repo-skills", label: "Skills in this checkout" },
        ],
        keywords: ["skills.sh", "agent", "SKILL.md", "claude", "cursor", "codex", "npx skills"],
      },
    ],
  },
];

export const ALL_PAGES: DocPage[] = NAV.flatMap((group) => group.pages);

/** Strip a deployment base path and any trailing slash. */
export function normalizePath(pathname: string): string {
  let path = pathname || "/";
  const base = process.env.NEXT_PUBLIC_BASE_PATH || "";
  if (base && path.startsWith(base)) path = path.slice(base.length);
  if (path.length > 1 && path.endsWith("/")) path = path.slice(0, -1);
  return path === "" ? "/" : path;
}

export function findPage(pathname: string): DocPage | undefined {
  const path = normalizePath(pathname);
  return ALL_PAGES.find((page) => page.href === path);
}

/** The group a page belongs to — used for breadcrumbs. */
export function findGroup(pathname: string): NavGroup | undefined {
  const path = normalizePath(pathname);
  return NAV.find((group) => group.pages.some((page) => page.href === path));
}

/** Previous/next in reading order, with the landing page first. */
export function neighbours(pathname: string): { prev?: DocPage; next?: DocPage } {
  const path = normalizePath(pathname);
  const chain: DocPage[] = [
    { href: "/", title: "Overview", description: HOME.description, toc: [] },
    ...ALL_PAGES,
  ];
  const index = chain.findIndex((page) => page.href === path);
  if (index === -1) return {};
  return { prev: chain[index - 1], next: chain[index + 1] };
}

export type SearchEntry = {
  href: string;
  title: string;
  description: string;
  breadcrumb: string;
  anchor?: string;
  anchorLabel?: string;
  haystack: string;
};

/**
 * A flat index for the search dialog: every page and every heading on it.
 * Small enough (a couple of hundred rows) to filter in one pass on keypress.
 */
export const SEARCH_INDEX: SearchEntry[] = [
  {
    href: "/",
    title: HOME.title,
    description: HOME.description,
    breadcrumb: "Overview",
    haystack: "astra v1 overview home landing robux executor ui library luau roblox",
  },
  ...NAV.flatMap((group) => [
    ...group.pages.map((page) => ({
      href: page.href,
      title: page.title,
      description: page.description,
      breadcrumb: group.label,
      haystack: [
        page.title,
        page.description,
        group.label,
        ...(page.keywords ?? []),
      ]
        .join(" ")
        .toLowerCase(),
    })),
    ...group.pages.flatMap((page) =>
      page.toc.map((item) => ({
        href: page.href,
        title: item.label,
        description: page.title,
        breadcrumb: group.label,
        anchor: item.id,
        anchorLabel: page.title,
        haystack: `${item.label} ${page.title} ${page.description} ${group.label} ${(page.keywords ?? []).join(" ")}`.toLowerCase(),
      })),
    ),
  ]),
];

/** Sidebar links that leave the docs for another site. */
export const SIDEBAR_LINKS = [
  { href: "https://github.com/Kira762/astra-version-1/blob/main/USAGE.md", label: "USAGE.md" },
  { href: "https://github.com/Kira762/astra-version-1/blob/main/MODULES.md", label: "MODULES.md" },
  { href: "https://github.com/Kira762/astra-version-1/blob/main/CHANGELOG.md", label: "CHANGELOG.md" },
  { href: "https://github.com/Kira762/astra-version-1/blob/main/PERFORMANCE_CHANGES.md", label: "PERFORMANCE_CHANGES.md" },
];

export const REPO_URL = "https://github.com/Kira762/astra-version-1";
/** Canonical site root — the GitHub Pages project URL for this repository. */
export const SITE_URL = "https://kira762.github.io/astra-version-1";
export const BUNDLE_URL =
  "https://raw.githubusercontent.com/Kira762/astra-version-1/main/version-1.luau";
export const LOADER_LINE = `local Astra = loadstring(game:HttpGet("${BUNDLE_URL}"))()`;
