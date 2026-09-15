
local managerModule = require(script.manager)
local registryModule = require(script.registry)
local defaultsModule = require(script.defaults)
local persistenceModule = require(script.persistence)

local settings = {
    manager = managerModule,
    registry = registryModule,
    defaults = defaultsModule,
    persistence = persistenceModule,
}

function settings.newManager(overrides: { [string]: any }?)
    return managerModule.new(overrides)
end

function settings.readPersisted(key: string, default: any): any
    return persistenceModule.read(key, default)
end

return settings
