local persistence = {}

local configPersistence = require(script.Parent.persistenceConfig)
local settingsPersistence = require(script.Parent.persistenceSettings)

persistence.getPath = configPersistence.getPath
persistence.save = configPersistence.save
persistence.load = configPersistence.load
persistence.applyTo = configPersistence.applyTo
persistence.list = configPersistence.list
persistence.delete = configPersistence.delete
persistence.getSettingsPath = settingsPersistence.getSettingsPath
persistence.saveSettings = settingsPersistence.saveSettings
persistence.loadSettings = settingsPersistence.loadSettings

return persistence
