local utilities = script.Parent.Parent.Parent.utilities
local persistence = require(utilities.persistence)

local Window = require(script.Parent.class)

function Window:GetPath()
    return persistence.getPath(self)
end

--[[
Subscribes to the window's saved-config list: the listener runs after
every successful `Save` (autosave included) and `DeleteConfig`, so a UI
that lists `ListConfigs()` cannot go stale while it is open. Returns an
unsubscribe function; listeners live and die with the window.
]]
function Window:OnConfigsChanged(listener)
    if type(listener) ~= "function" then
        return function() end
    end
    self._configListListeners = self._configListListeners or {}
    table.insert(self._configListListeners, listener)
    local subscribed = true
    return function()
        if not subscribed then
            return
        end
        subscribed = false
        local index = self._configListListeners and table.find(self._configListListeners, listener)
        if index then
            table.remove(self._configListListeners, index)
        end
    end
end

function Window:_emitConfigsChanged()
    local listeners = self._configListListeners
    if not listeners then
        return
    end
    for _, listener in table.clone(listeners) do
        pcall(listener)
    end
end

function Window:Save(name)
    if name ~= nil and (type(name) ~= "string" or name == "") then
        return false
    end
    local saved = persistence.save(self, name)
    if saved then
        self:_emitConfigsChanged()
    end
    return saved
end

function Window:Load(name)
    if name ~= nil and (type(name) ~= "string" or name == "") then
        return false
    end
    return persistence.load(self, name)
end

function Window:_applyNamedConfig(name)
    if not self:Load(name) then
        return false
    end
            local _, path = persistence.getPath(self)
    self._loadedConfigPath = path
    self:Save()
    return true
end

function Window:ListConfigs()
    return persistence.list(self)
end

function Window:DeleteConfig(name)
    local deleted = persistence.delete(self, name)
    if deleted then
        self:_emitConfigsChanged()
    end
    return deleted
end

function Window:Get(flag)
    local control = self.controls[flag]
    return control and control.value
end

function Window:Set(flag, value)
    local control = self.controls[flag]
    if not control then
        return false
    end
    control:Set(value)
    return true
end
