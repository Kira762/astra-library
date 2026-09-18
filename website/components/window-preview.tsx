"use client";

import { useEffect, useRef, useState } from "react";

/**
 * A live mock of an Astra window, rebuilt in HTML so the landing page opens
 * with the thing the library actually makes. Every colour here comes from the
 * real theme modules in themes/ — see /docs/themes.
 */
const THEMES = [
  { name: "default", bg: "#0A0A0A", accent: "#17996E" },
  { name: "amethyst", bg: "#100D18", accent: "#B17EE6" },
  { name: "cobalt", bg: "#0B1019", accent: "#4E9DEB" },
  { name: "crimson", bg: "#130C0D", accent: "#E04E54" },
  { name: "ember", bg: "#161210", accent: "#E2913A" },
  { name: "emerald", bg: "#0C110D", accent: "#48C774" },
  { name: "frost", bg: "#0A0E13", accent: "#56C5EB" },
  { name: "gold", bg: "#13100A", accent: "#E9C44A" },
  { name: "onyx", bg: "#080809", accent: "#CDD2DC" },
  { name: "rose", bg: "#170F13", accent: "#DA6991" },
] as const;

type Theme = (typeof THEMES)[number];

function hexToRgb(hex: string) {
  const value = hex.replace("#", "");
  return [
    parseInt(value.slice(0, 2), 16),
    parseInt(value.slice(2, 4), 16),
    parseInt(value.slice(4, 6), 16),
  ];
}

/** Channel-wise mix of two hex colours, as "r g b". */
function channels(from: string, to: string, amount: number) {
  const a = hexToRgb(from);
  const b = hexToRgb(to);
  const channel = (index: number) => Math.round(a[index] + (b[index] - a[index]) * amount);
  return `${channel(0)} ${channel(1)} ${channel(2)}`;
}

function mix(from: string, to: string, amount: number) {
  return `rgb(${channels(from, to, amount)})`;
}

function mixAlpha(from: string, to: string, amount: number, alpha: number) {
  return `rgb(${channels(from, to, amount)} / ${alpha})`;
}

const TABS = [
  { id: "home", label: "Home" },
  { id: "player", label: "Player" },
  { id: "settings", label: "Settings" },
] as const;

const PRESETS = ["Low", "Medium", "High"];

export function WindowPreview() {
  const [theme, setTheme] = useState<Theme>(THEMES[1]);
  const [tab, setTab] = useState<(typeof TABS)[number]["id"]>("home");
  const [autoSprint, setAutoSprint] = useState(true);
  const [sensitivity, setSensitivity] = useState(5);
  const [preset, setPreset] = useState("Medium");
  const [dropdownOpen, setDropdownOpen] = useState(false);
  const [kills, setKills] = useState(128);
  const [previousKills, setPreviousKills] = useState(128);
  const [toast, setToast] = useState<{ title: string; content: string } | null>(null);
  const [settingsMode, setSettingsMode] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  const onAccent = hexToRgb(theme.accent).reduce((sum, c) => sum + c, 0) > 430 ? "#0A0A0A" : "#FFFFFF";

  const style = {
    "--w-bg": theme.bg,
    "--w-surface": mix(theme.bg, theme.accent, 0.09),
    "--w-raised": mix(theme.bg, theme.accent, 0.16),
    "--w-raised-soft": mixAlpha(theme.bg, theme.accent, 0.16, 0.7),
    "--w-accent-soft": mixAlpha(theme.accent, theme.accent, 0, 0.28),
    "--w-line": mix(theme.bg, theme.accent, 0.24),
    "--w-accent": theme.accent,
    "--w-ink": mix("#FFFFFF", theme.accent, 0.12),
    "--w-muted": mix(theme.bg, "#FFFFFF", 0.62),
    "--w-on-accent": onAccent,
  } as React.CSSProperties;

  // The toast dismisses itself, like Notify does on its timeout.
  useEffect(() => {
    if (!toast) return;
    const timer = window.setTimeout(() => setToast(null), 4200);
    return () => window.clearTimeout(timer);
  }, [toast]);

  // Clicking anywhere else closes the dropdown.
  useEffect(() => {
    if (!dropdownOpen) return;
    function onPointerDown(event: Event) {
      if (!dropdownRef.current?.contains(event.target as Node)) setDropdownOpen(false);
    }
    function onKey(event: KeyboardEvent) {
      if (event.key === "Escape") setDropdownOpen(false);
    }
    // pointerdown covers mouse, touch and pen, so a tap elsewhere closes it too.
    document.addEventListener("pointerdown", onPointerDown);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("pointerdown", onPointerDown);
      document.removeEventListener("keydown", onKey);
    };
  }, [dropdownOpen]);

  const delta = kills - previousKills;

  return (
    <div className="w-full">
      <div
        style={style}
        className="relative mx-auto w-full max-w-[600px] overflow-hidden rounded-[16px] border border-[var(--w-line)] bg-[var(--w-bg)] shadow-[0_40px_80px_-50px_rgba(0,0,0,0.95)] transition-colors duration-300"
        role="group"
        aria-label="Interactive preview of an Astra window"
      >
        {/* topbar */}
        <div className="flex items-center gap-3 border-b border-[var(--w-line)] bg-[var(--w-surface)] px-3.5 py-2.5">
          <div className="min-w-0 flex-1">
            <p className="truncate font-display text-sm font-semibold text-[var(--w-ink)]">
              Example Hub
            </p>
            <p className="truncate text-[0.6875rem] text-[var(--w-muted)]">Astra · theme {theme.name}</p>
          </div>
          <div className="ml-auto flex items-center gap-1">
            {(
              [
                ["search", "Search"],
                ["sliders", settingsMode ? "Leave settings" : "Settings"],
                ["chevron-down", "Minimise"],
                ["close", "Close"],
              ] as const
            ).map(([glyph, label]) => (
              <button
                key={label}
                type="button"
                aria-label={label}
                aria-pressed={label === "Settings" ? settingsMode : undefined}
                onClick={() => {
                  if (label === "Settings") {
                    setSettingsMode((on) => !on);
                    setTab("settings");
                  }
                  if (label === "Search") {
                    setToast({ title: "Search", content: "Search opens over the tab, lazily." });
                  }
                }}
                className={`grid h-7 w-7 place-items-center rounded-[7px] text-[var(--w-muted)] transition-colors hover:bg-[var(--w-raised)] hover:text-[var(--w-ink)] ${
                  label === "Settings" && settingsMode ? "bg-[var(--w-raised)] text-[var(--w-accent)]" : ""
                }`}
              >
                <Glyph name={glyph} />
              </button>
            ))}
          </div>
        </div>

        <div className="flex min-h-[292px]">
          {/* tab rail */}
          <div className="flex w-[52px] shrink-0 flex-col gap-1 border-r border-[var(--w-line)] bg-[var(--w-surface)] p-2 sm:w-[124px]">
            {(settingsMode ? TABS.filter((item) => item.id === "settings") : TABS).map((item) => {
              const current = tab === item.id;
              return (
                <button
                  key={item.id}
                  type="button"
                  onClick={() => setTab(item.id)}
                  aria-label={item.label}
                  aria-current={current ? "true" : undefined}
                  className={`flex items-center gap-2 rounded-[9px] px-2 py-2 text-left text-[0.78125rem] transition-colors ${
                    current
                      ? "bg-[var(--w-raised)] text-[var(--w-ink)]"
                      : "text-[var(--w-muted)] hover:bg-[var(--w-raised-soft)] hover:text-[var(--w-ink)]"
                  }`}
                >
                  <span
                    aria-hidden
                    className={`h-3.5 w-3.5 shrink-0 rounded-[4px] border ${
                      current
                        ? "border-[var(--w-accent)] bg-[var(--w-accent-soft)]"
                        : "border-[var(--w-line)]"
                    }`}
                  />
                  <span className="hidden truncate sm:inline">{item.label}</span>
                </button>
              );
            })}
            <p className="mt-auto hidden px-2 text-[0.625rem] leading-4 text-[var(--w-muted)] sm:block">
              {settingsMode ? "Settings mode — gear again to leave" : "Layout: default topbar"}
            </p>
          </div>

          {/* tab body */}
          <div className="min-w-0 flex-1 space-y-2.5 p-3">
            {tab === "home" || settingsMode ? (
              <>
                <Card>
                  <Row icon="zap" title="Auto Sprint" hint="Toggle">
                    <button
                      type="button"
                      role="switch"
                      aria-checked={autoSprint}
                      aria-label="Auto Sprint"
                      onClick={() => setAutoSprint((on) => !on)}
                      className="relative h-[22px] w-[40px] shrink-0 rounded-full border transition-colors duration-200"
                      style={{
                        background: autoSprint ? theme.accent : mix(theme.bg, theme.accent, 0.14),
                        borderColor: autoSprint ? theme.accent : mix(theme.bg, theme.accent, 0.3),
                      }}
                    >
                      <span
                        className="absolute left-[3px] top-[3px] h-[16px] w-[16px] rounded-full bg-white transition-transform duration-200"
                        style={{ transform: `translateX(${autoSprint ? 18 : 0}px)` }}
                      />
                    </button>
                  </Row>
                </Card>

                <Card>
                  <div className="flex items-center justify-between gap-2">
                    <span className="text-[0.8125rem] text-[var(--w-ink)]">Sensitivity</span>
                    <span className="font-mono text-[0.75rem] text-[var(--w-muted)] tabular-nums">
                      {sensitivity}x
                    </span>
                  </div>
                  {/* A real range input, styled in globals.css (.range) so the
                      track, the thumb and the hit area work in Blink, WebKit
                      and Gecko — and on a finger, not just a mouse. */}
                  <input
                    type="range"
                    name="sensitivity"
                    min={1}
                    max={10}
                    step={1}
                    value={sensitivity}
                    aria-label="Sensitivity"
                    aria-valuetext={`${sensitivity}x`}
                    onChange={(event) => setSensitivity(Number(event.target.value))}
                    className="range mt-1.5 w-full"
                    style={
                      {
                        "--range-fill": `linear-gradient(to right, ${theme.accent} ${((sensitivity - 1) / 9) * 100}%, ${mix(theme.bg, theme.accent, 0.22)} ${((sensitivity - 1) / 9) * 100}%)`,
                        "--range-accent": theme.accent,
                      } as React.CSSProperties
                    }
                  />
                </Card>

                <Card>
                  <div className="flex items-center justify-between gap-2">
                    <span className="text-[0.8125rem] text-[var(--w-ink)]">Preset</span>
                    <div ref={dropdownRef} className="relative">
                      <button
                        type="button"
                        aria-haspopup="listbox"
                        aria-expanded={dropdownOpen}
                        onClick={() => setDropdownOpen((open) => !open)}
                        className="flex items-center gap-1.5 rounded-[8px] border border-[var(--w-line)] bg-[var(--w-raised)] px-2 py-1 text-[0.75rem] text-[var(--w-ink)]"
                      >
                        {preset}
                        <Glyph name="chevron" />
                      </button>
                      {dropdownOpen ? (
                        <ul
                          role="listbox"
                          aria-label="Preset"
                          className="absolute right-0 z-10 mt-1 w-28 overflow-hidden rounded-[10px] border border-[var(--w-line)] bg-[var(--w-surface)] py-1 shadow-xl"
                        >
                          {PRESETS.map((option) => (
                            <li key={option}>
                              <button
                                type="button"
                                role="option"
                                aria-selected={option === preset}
                                onClick={() => {
                                  setPreset(option);
                                  setDropdownOpen(false);
                                }}
                                className="block w-full px-2.5 py-2 text-left text-[0.75rem] text-[var(--w-muted)] hover:bg-[var(--w-raised)] hover:text-[var(--w-ink)] sm:py-1.5"
                              >
                                {option}
                              </button>
                            </li>
                          ))}
                        </ul>
                      ) : null}
                    </div>
                  </div>
                </Card>

                <Card>
                  <div className="flex flex-wrap items-center gap-x-3 gap-y-2">
                    <div className="min-w-0">
                      <p className="text-[0.75rem] text-[var(--w-muted)]">Kills</p>
                      <p className="font-display text-xl font-semibold text-[var(--w-ink)] tabular-nums">
                        {kills}
                        <span className="ml-2 align-middle font-mono text-[0.6875rem] text-[var(--w-accent)]">
                          {delta >= 0 ? "+" : ""}
                          {delta}
                        </span>
                      </p>
                    </div>
                    <button
                      type="button"
                      onClick={() => {
                        const next = kills + 1 + Math.floor(Math.random() * 6);
                        setPreviousKills(kills);
                        setKills(next);
                        setToast({ title: "Stat updated", content: `Kills is now ${next}.` });
                      }}
                      className="ml-auto flex items-center gap-2 rounded-[10px] px-3 py-2 text-[0.75rem] font-medium transition-opacity hover:opacity-90 sm:py-1.5"
                      style={{ background: theme.accent, color: onAccent }}
                    >
                      Say hello
                      <Glyph name="tap" />
                    </button>
                  </div>
                </Card>
              </>
            ) : null}

            {tab === "player" && !settingsMode ? (
              <>
                <Card>
                  <Row icon="layers" title="LocalPlayer" hint="Collapsible group · closed">
                    <span className="text-[0.6875rem] text-[var(--w-muted)]">3 controls</span>
                  </Row>
                </Card>
                <Card>
                  <Row icon="zap" title="Infinite Jump" hint="Toggle inside a group">
                    <span className="font-mono text-[0.6875rem] text-[var(--w-accent)]">flag: infiniteJump</span>
                  </Row>
                </Card>
                <Card>
                  <Row icon="sliders" title="Walk Speed" hint="Slider 16 – 100">
                    <span className="font-mono text-[0.6875rem] text-[var(--w-muted)]">16</span>
                  </Row>
                </Card>
              </>
            ) : null}

            {tab === "settings" ? (
              <>
                <Card>
                  <Row icon="package" title="Auto Save Config" hint="Persistence">
                    <span className="text-[0.6875rem] text-[var(--w-accent)]">on</span>
                  </Row>
                </Card>
                <Card>
                  <Row icon="package" title="Auto Load Config" hint="Persistence">
                    <span className="text-[0.6875rem] text-[var(--w-accent)]">on</span>
                  </Row>
                </Card>
                <Card>
                  <Row icon="sliders" title="Animation speed" hint="Performance & motion">
                    <span className="font-mono text-[0.6875rem] text-[var(--w-muted)]">normal</span>
                  </Row>
                </Card>
                <Card>
                  <Row icon="star" title="Bar layout" hint="Appearance">
                    <span className="text-[0.6875rem] text-[var(--w-muted)]">Topbar</span>
                  </Row>
                </Card>
              </>
            ) : null}
          </div>
        </div>

        {/* notification, the way window:Notify draws one */}
        <div className="pointer-events-none absolute bottom-3 left-3 right-3 flex flex-col gap-2 sm:left-auto sm:w-[248px]">
          {toast ? (
            <div
              role="status"
              className="pointer-events-auto rounded-[12px] border border-[var(--w-line)] bg-[var(--w-surface)] p-3 shadow-xl"
            >
              <p className="font-display text-[0.8125rem] font-semibold text-[var(--w-ink)]">
                {toast.title}
              </p>
              <p className="mt-0.5 text-[0.75rem] leading-5 text-[var(--w-muted)]">{toast.content}</p>
            </div>
          ) : null}
        </div>
      </div>

      {/* theme picker — the ten built-ins, by their real accent colours */}
      <fieldset className="mx-auto mt-4 max-w-[600px]">
        <legend className="mb-2 text-xs text-subtle">
          Built-in themes — pick one and the window restyles live
        </legend>
        <div className="flex flex-wrap gap-1.5">
          {THEMES.map((item) => {
            const current = item.name === theme.name;
            return (
              <button
                key={item.name}
                type="button"
                onClick={() => setTheme(item)}
                aria-pressed={current}
                className={`flex items-center gap-1.5 rounded-full border px-3 py-2 text-xs transition-colors sm:py-1.5 ${
                  current
                    ? "border-accent bg-accent/15 text-ink"
                    : "border-line text-muted hover:border-line-strong hover:text-ink"
                }`}
              >
                <span
                  aria-hidden
                  className="h-2.5 w-2.5 rounded-full"
                  style={{ background: item.accent }}
                />
                {item.name}
              </button>
            );
          })}
        </div>
      </fieldset>
    </div>
  );
}

function Card({ children }: { children: React.ReactNode }) {
  return (
    <div className="rounded-[11px] border border-[var(--w-line)] bg-[var(--w-surface)] px-3 py-2.5 transition-colors duration-300">
      {children}
    </div>
  );
}

function Row({
  icon,
  title,
  hint,
  children,
}: {
  icon: "zap" | "layers" | "sliders" | "package" | "star";
  title: string;
  hint: string;
  children: React.ReactNode;
}) {
  return (
    <div className="flex items-center gap-2.5">
      <span className="grid h-6 w-6 shrink-0 place-items-center rounded-[7px] bg-[var(--w-raised)] text-[var(--w-accent)]">
        <Glyph name={icon} />
      </span>
      <span className="min-w-0">
        <span className="block truncate text-[0.8125rem] text-[var(--w-ink)]">{title}</span>
        <span className="block truncate text-[0.6875rem] text-[var(--w-muted)]">{hint}</span>
      </span>
      <span className="ml-auto flex items-center">{children}</span>
    </div>
  );
}

const GLYPHS: Record<string, React.ReactNode> = {
  search: (
    <>
      <circle cx="11" cy="11" r="6.5" />
      <path d="m20 20-3.8-3.8" />
    </>
  ),
  sliders: (
    <>
      <path d="M5 7h14M5 12h14M5 17h14" />
      <circle cx="9" cy="7" r="1.6" />
      <circle cx="15" cy="12" r="1.6" />
      <circle cx="8" cy="17" r="1.6" />
    </>
  ),
  chevron: <path d="m6 9 6 6 6-6" />,
  close: <path d="M6 6l12 12M18 6 6 18" />,
  zap: <path d="M13 4 6 13h4.5L10 20l7-9.5h-4.5L13 4Z" />,
  layers: (
    <>
      <path d="m12 4 8 4.2-8 4.2-8-4.2L12 4Z" />
      <path d="m4 13 8 4.2 8-4.2" />
    </>
  ),
  package: (
    <>
      <path d="M20 8v8l-8 4-8-4V8l8-4 8 4Z" />
      <path d="M12 12v8M4 8l8 4 8-4" />
    </>
  ),
  star: <path d="m12 4 2.4 5.2 5.6.8-4.1 3.9 1 5.6-4.9-2.8-4.9 2.8 1-5.6L4 10l5.6-.8L12 4Z" />,
  tap: (
    <>
      <path d="M9 13V7.5a1.5 1.5 0 0 1 3 0V12" />
      <path d="M12 12V10a1.5 1.5 0 0 1 3 0v2" />
      <path d="M15 12v-.5a1.5 1.5 0 0 1 3 0V15a5 5 0 0 1-5 5h-1.6a4 4 0 0 1-3-1.4L5 15" />
    </>
  ),
};

function Glyph({ name }: { name: string }) {
  return (
    <svg
      viewBox="0 0 24 24"
      className="h-3.5 w-3.5"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.7}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden
    >
      {GLYPHS[name]}
    </svg>
  );
}
