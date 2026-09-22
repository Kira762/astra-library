
local registry = require(script.Parent.registry)
local defaults = require(script.Parent.defaults)
local persistence = require(script.Parent.persistence)
local appearance = require(script.Parent.appearance)
local behavior = require(script.Parent.behavior)
local performance = require(script.Parent.performance)

local SettingsManager = {}

SettingsManager.__index = SettingsManager

export type SettingsManager = {
    defaults: { [string]: any },
    persistence: { [any]: (string, any, any) -> () },
    get: (self: SettingsManager, key: string) -> any,
    set: (self: SettingsManager, key: string, value: any) -> boolean,
    reset: (self: SettingsManager, key: string?) -> boolean,
    onChange: (self: SettingsManager, listener: (string, any, any) -> ()) -> (),
    save: (self: SettingsManager) -> boolean,
    load: (self: SettingsManager) -> boolean,
}

local domains = {
    appearance = appearance,
    behavior = behavior,
    performance = performance,
}

function SettingsManager.new(overrides: { [string]: any }?): SettingsManager
    --[[
    `values` and `listeners` were never created here, so every method that
    touches them (:get, :set, :save, :load, :onChange) raised "attempt to
    index nil" the first time a host used a manager directly. The window
    keeps its own plain settings table, which is why this went unnoticed.
    ]]
    local self = setmetatable({
        defaults = defaults.clone(overrides),
        values = defaults.clone(overrides),
        listeners = {},
        persistence = {},
    }, SettingsManager)
    return self
end

function SettingsManager:get(key: string): any
    return self.values[key]
end

function SettingsManager:set(key: string, value: any): boolean
    local definition = registry.definition(key)
    if not definition then
        return false
    end

    local domainValidator = domains[definition.domain]
    local ok, validated
    if domainValidator then
        ok, validated = domainValidator.validate(key, value)
    else
        ok, validated = true, value
    end
    if not ok then
        return false
    end

    local oldValue = self.values[key]
    if oldValue == validated then
        return true
    end

    self.values[key] = validated
    for _, listener in self.listeners do
        task.spawn(listener, key, validated, oldValue)
    end
    return true
end

function SettingsManager:reset(key: string?): boolean
    if key then
        if not registry.definition(key) then
            return false
        end
        return self:set(key, defaults.values[key])
    end
    for _, key in registry.keys() do
        self:reset(key)
    end
    return true
end

function SettingsManager:onChange(listener: (string, any, any) -> ())
    table.insert(self.listeners, listener)
end

function SettingsManager:save(): boolean
    return persistence.save(self.values)
end

function SettingsManager:load(): boolean
    local snapshot = table.clone(self.values)
    local ok = persistence.load(self.values)
    if not ok then
        return ok
    end

    --[[
    Notify listeners only for values that actually changed, matching the
    (key, newValue, oldValue) contract of :set(). Persisted values are
    written into self.values first; callbacks fire afterwards.
    ]]
    for _, key in registry.keys() do
        local newValue = self.values[key]
        if snapshot[key] ~= newValue then
            for _, listener in self.listeners do
                task.spawn(listener, key, newValue, snapshot[key])
            end
        end
    end
    return ok
end

return SettingsManager
