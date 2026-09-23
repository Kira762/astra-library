
local registry = {}

export type SettingDefinition = {
    key: string,
    kind: "boolean" | "keybind" | "enum",
    domain: "appearance" | "behavior" | "performance",
    description: string?,
}

registry.definitions = {
    autoSaveConfig = {
        key = "autoSaveConfig", kind = "boolean", domain = "behavior",
        description = "Automatically saves control values when they change.",
    },
    autoLoadConfig = {
        key = "autoLoadConfig", kind = "boolean", domain = "behavior",
        description = "Restores saved control values on the next startup.",
    },
    toggleKeybind = {
        key = "toggleKeybind",
        kind = "keybind",
        domain = "behavior",
        description = "Required single letter (A–Z) used to show/hide the window.",
    },
    mouseOverride = {
        key = "mouseOverride",
        kind = "boolean",
        domain = "behavior",
        description = "Unlocks the cursor while the window is open.",
    },
    keepOnScreen = {
        key = "keepOnScreen",
        kind = "boolean",
        domain = "appearance",
        description = "Keeps the window clamped inside the viewport.",
    },
    haptics = {
        key = "haptics",
        kind = "boolean",
        domain = "performance",
        description = "Toggles haptic feedback on supported devices.",
    },
    antiWindowDuplicate = {
        key = "antiWindowDuplicate",
        kind = "boolean",
        domain = "behavior",
        description = "Prevents creating another window while one is active.",
    },
    layoutMode = {
        key = "layoutMode",
        kind = "enum",
        domain = "appearance",
        description = "Bar layout mode: sidebar or collapsedSidebar.",
    },
    motionSpeed = {
        key = "motionSpeed",
        kind = "enum",
        domain = "performance",
        --[[
        Backed by utilities/motion.luau: relaxed/normal/snappy rescale
        every transition routed through the motion service (the window's
        entrance, the element reveals and hovers, the result flashes), and
        instant switches that animation off - targets are applied on the
        spot - for accessibility and for machines where the UI is competing
        with the game for frame time.
        ]]
        description = "Animation speed: relaxed, normal, snappy, or instant (no animation).",
    },
    fontChoice = {
        key = "fontChoice",
        kind = "enum",
        domain = "appearance",
        description = "Text font: default (the original Roblox look) or brand (Astra's custom family).",
    },
}

function registry.definition(definitions: string): SettingDefinition?
    return registry.definitions[definitions]
end

function registry.keys(): { string }
    local list = {}
    for key in registry.definitions do
        table.insert(list, key)
    end
    table.sort(list)
    return list
end

return registry
