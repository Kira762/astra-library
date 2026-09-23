local utilities = script.Parent.Parent.Parent.utilities
local motion = require(utilities.motion)
local persistence = require(utilities.persistence)
local settingsComponent = require(script.Parent.Parent.settings)

local Window = require(script.Parent.class)

function Window:_buildSettingsUI()
    settingsComponent.buildUI(self)
end

function Window:_buildSettingsContent(tab)
    settingsComponent.buildContent(self, tab)
end

function Window:SaveSettings()
    return persistence.saveSettings(self)
end

function Window:LoadSettings()
    local loaded, migrated = persistence.loadSettings(self)
    self.configuration.autoSave = self.settings.autoSaveConfig
    self.configuration.autoLoad = self.settings.autoLoadConfig
    --[[
    The animation-speed setting lives in the same file, and the motion
    service is a library-wide singleton, so it is re-applied here rather
    than only when the settings control is touched — otherwise a window
    that loaded settings would animate at whatever the last one used.
    ]]
    self:_applyMotionSetting()
    --[[
    The font choice lives in the same file and resolves through
    library-wide state on the next theme pass, so sync it here —
    `ChangeTheme(self.settings.theme)` at startup reads it. A `brand`
    choice is swapped in after the entrance by the entrypoint's
    settled apply.
    ]]
    local coreState = require(script.Parent.Parent.Parent.core.state)
    coreState.setFontChoice(self.settings.fontChoice)
    if migrated then
        self:SaveSettings()
    end
    return loaded
end

--[[
`token` is the theme key the rounded corners read; it defaults to the
window's own roundness, but callers inside an element pass that element's
radius token so an inner surface can share the container's arcs.
]]

function Window:_toggleSettingsMode()
    settingsComponent.toggleSettingsMode(self)
end

function Window:_setSettingsMode(active)
    settingsComponent.setSettingsMode(self, active)
    self:_updateWindowTitle()
end
