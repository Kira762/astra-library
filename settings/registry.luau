
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
        description = "Keybind used to show/hide the window.",
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
    welcomeToast = {
        key = "welcomeToast",
        kind = "boolean",
        domain = "behavior",
        description = "Shows a 'Signed in as' toast on first open of a new account.",
    },
    haptics = {
        key = "haptics",
        kind = "boolean",
        domain = "performance",
        description = "Toggles haptic feedback on supported devices.",
    },
    showProfile = {
        key = "showProfile",
        kind = "boolean",
        domain = "appearance",
        description = "Shows the account profile in a panel beside the window.",
    },
    showFullUsername = {
        key = "showFullUsername",
        kind = "boolean",
        domain = "appearance",
        -- [[Depends on showProfile: it unmasks values that live on the]]
        -- [[profile card, so it can only be on while the card is. The rule]]
        -- [[is enforced by profilePanel.revealAllowed/setReveal.]]
        description = "Reveals the display name, username, user ID, place ID, job ID and license key on the profile card instead of the masked versions. Requires showProfile to be on.",
    },
    profileSide = {
        key = "profileSide",
        kind = "enum",
        domain = "appearance",
        description = "Which side of the window the profile panel sits on (right or left).",
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
        description = "Bar layout mode: top, sidebar, or collapsedSidebar.",
    },
    activeSubTab = {
        key = "activeSubTab",
        kind = "enum",
        domain = "appearance",
        description = "Index of the currently selected settings sub-tab.",
    },
    motionSpeed = {
        key = "motionSpeed",
        kind = "enum",
        domain = "performance",
        -- [[Backed by utilities/motion.luau: relaxed/normal/snappy rescale
        -- every transition routed through the motion service (the window's
        -- entrance, the element reveals and hovers, the result flashes), and
        -- instant switches that animation off - targets are applied on the
        -- spot - for accessibility and for machines where the UI is competing
        -- with the game for frame time.]]
        description = "Animation speed: relaxed, normal, snappy, or instant (no animation).",
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
