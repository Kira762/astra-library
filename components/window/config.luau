local utilities = script.Parent.Parent.Parent.utilities
local persistence = require(utilities.persistence)

local Window = require(script.Parent.class)

function Window:GetPath()
    return persistence.getPath(self)
end

function Window:Save(name)
    if name ~= nil and (type(name) ~= "string" or name == "") then
        return false
    end
    return persistence.save(self, name)
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
    return persistence.delete(self, name)
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
