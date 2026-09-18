"use client";

import { useEffect, useState } from "react";

/**
 * The modifier key that opens search on this device. Renders ⌘ on Apple
 * hardware and Ctrl everywhere else — the shortcut listens for both, the hint
 * should only advertise the one a person actually has.
 */
export function ShortcutKey() {
  const [key, setKey] = useState<"⌘" | "Ctrl">("⌘");

  useEffect(() => {
    const platform = navigator.userAgent + " " + (navigator as { userAgentData?: { platform?: string } }).userAgentData?.platform;
    if (!/mac|iphone|ipad|ipod/i.test(platform)) setKey("Ctrl");
  }, []);

  return (
    <>
      {key}
      {key === "⌘" ? "\u00a0" : " "}K
    </>
  );
}
