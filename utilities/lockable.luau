--[[
Lockable controls keep their value and callback intact while a lock source
blocks user input. This mixin also stamps the public usage tag used by the
window's cumulative element-lock modes:

    lockable:astra:<elementId>

`register` is called by interactive element constructors after their UI has
been built. Static presentation elements never call it, so they never get a
lock tag or enter the mode registry.
]]
local lockable = {}

local LOCK_USAGE_PREFIX = "lockable:astra:"

local defaultLockLevels = {
	Link = 2,
	Input = 2,
	Dropdown = 2,
	Keybind = 2,
	Toggle = 3,
	Slider = 3,
	Button = 3,
	AboutCard = 3,
	ModePicker = 3,
}

local lockGroupLevels = {
	minor = 1,
	low = 1,
	noncritical = 1,
	standard = 2,
	input = 2,
	selection = 2,
	action = 3,
	important = 3,
	advanced = 4,
	sensitive = 4,
	highimpact = 4,
	remaining = 5,
	all = 5,
}

local function read(properties, lower, upper)
	if type(properties) ~= "table" then
		return nil
	end
	local value = properties[lower]
	if value == nil then
		value = properties[upper]
	end
	return value
end

local function idFromWords(value)
	local words = {}
	for word in tostring(value or ""):gmatch("[%w]+") do
		if #words == 0 then
			table.insert(words, string.lower(word))
		else
			table.insert(words, string.upper(string.sub(word, 1, 1)) .. string.lower(string.sub(word, 2)))
		end
	end
	return table.concat(words)
end

local function normalizeId(value, fallback)
	local id = tostring(value or ""):gsub("[^%w_%-]", "")
	if id == "" then
		id = idFromWords(fallback)
	end
	if id == "" then
		id = "element"
	end
	return id
end

local function mergeUsages(first, second)
	local merged = {}
	local function append(value)
		if type(value) == "string" and value ~= "" then
			if not table.find(merged, value) then
				table.insert(merged, value)
			end
		elseif type(value) == "table" then
			for _, usage in ipairs(value) do
				if type(usage) == "string" and usage ~= "" and not table.find(merged, usage) then
					table.insert(merged, usage)
				end
			end
		end
	end
	append(first)
	append(second)
	if #merged == 0 then
		return nil
	end
	if #merged == 1 then
		return merged[1]
	end
	return merged
end

local function usageWithTag(existing, tag)
	local usages = mergeUsages(existing, tag)
	return usages or tag
end

local function requestedLevel(properties, options, element)
	local level = options.lockLevel
	if level == nil then
		level = options.lockGroup
	end
	if level == nil then
		level = read(properties, "lockLevel", "LockLevel")
	end
	if level == nil then
		level = read(properties, "lockGroup", "LockGroup")
	end
	if type(level) == "string" then
		local key = string.lower(level):gsub("[%s_%-]", "")
		level = lockGroupLevels[key]
	end

	local numeric = tonumber(level)
	if numeric then
		return math.clamp(math.round(numeric), 1, 5)
	end
	return defaultLockLevels[element.__type] or 5
end

local function uniqueId(window, baseId, element)
	if not window then
		return baseId
	end

	window._lockableElementIds = window._lockableElementIds or {}
	local candidate = baseId
	local suffix = 2
	while window._lockableElementIds[candidate] and window._lockableElementIds[candidate] ~= element do
		candidate = baseId .. suffix
		suffix += 1
	end
	return candidate
end

function lockable.register(element, properties, options)
	properties = if type(properties) == "table" then properties else {}
	options = if type(options) == "table" then options else {}

	local window = element.window
	local isController = options.exempt == true
		or element._lockSystemController == true
		or read(properties, "lockSystemController", "LockSystemController") == true
	local enabled = options.enabled
	if enabled == nil then
		enabled = true
	end

	if isController or not enabled then
		element._isLockable = false
		element._lockSystemController = isController
		return nil
	end

	local explicitId = options.id
	if explicitId == nil then
		explicitId = read(properties, "id", "Id")
	end
	if explicitId == nil then
		explicitId = read(properties, "elementId", "ElementId")
	end
	local name = element.name or element.__type or "Element"
	local baseId = normalizeId(explicitId, name)
	local elementId = uniqueId(window, baseId, element)
	local usageTag = LOCK_USAGE_PREFIX .. elementId
	local existingUsage = mergeUsages(
		read(properties, "usage", "Usage"),
		options.usage
	)

	element.id = elementId
	element.elementId = elementId
	element.usageTag = usageTag
	element.lockUsage = usageTag
	element.usage = usageWithTag(existingUsage, usageTag)
	element.lockLevel = requestedLevel(properties, options, element)
	element._isLockable = true
	element._lockSystemController = false

	if window and window._registerLockableElement then
		window:_registerLockableElement(element)
	end
	return usageTag
end

local function lockableMixin<T>(element: T): T
	local target = element :: any

	function target:Lock(reason: string?)
		if self._isLockable ~= true or self._lockSystemController then
			return false
		end
		return self.window:_setElementLocked(self, true, reason, "manual")
	end

	function target:Unlock()
		if self._isLockable ~= true or self._lockSystemController then
			return false
		end
		return self.window:_setElementLocked(self, false, nil, "manual")
	end

	function target:IsLocked(): boolean
		return self.locked == true
	end

	return element
end

setmetatable(lockable, {
	__call = function(_, element)
		return lockableMixin(element)
	end,
})

return lockable
