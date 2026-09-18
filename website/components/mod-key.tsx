"use client";

import { useEffect, useState } from "react";

/**
 * The search shortcut's modifier key, spelled the way the visitor's device
 * spells it: ⌘ on Apple hardware, Ctrl everywhere else. Server render (and the
 * first paint) shows ⌘; the effect corrects it before the reader can act on it.
 */
export function ModKey({ combo = "K" }: { combo?: string }) {
  const [mod, setMod] = useState("⌘");

  useEffect(() => {
    const nav = navigator as Navigator & { userAgentData?: { platform?: string } };
    const platform = nav.userAgentData?.platform || nav.platform || navigator.userAgent;
    if (!/Mac|iPhone|iPad|iPod/i.test(platform)) setMod("Ctrl");
  }, []);

  return (
    <kbd className="kbd">
      {mod}
      {mod === "⌘" ? "\u00a0" : "+"}
      {combo}
    </kbd>
  );
}
