local persistence = {}

local configPersistence = require(script.Parent.persistenceConfig)
local settingsPersistence = require(script.Parent.persistenceSettings)
local changelogPersistence = require(script.Parent.persistenceChangelog)

persistence.getPath = configPersistence.getPath
persistence.save = configPersistence.save
persistence.load = configPersistence.load
persistence.applyTo = configPersistence.applyTo
persistence.list = configPersistence.list
persistence.delete = configPersistence.delete
persistence.getSettingsPath = settingsPersistence.getSettingsPath
persistence.saveSettings = settingsPersistence.saveSettings
persistence.loadSettings = settingsPersistence.loadSettings
persistence.getChangelogPath = changelogPersistence.getChangelogPath
persistence.windowChangelogKey = changelogPersistence.windowKey
persistence.loadChangelogSeen = changelogPersistence.loadSeen
persistence.saveChangelogSeen = changelogPersistence.saveSeen

return persistence
