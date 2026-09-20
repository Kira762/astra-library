-- [[Lazy icon-pack builder.
-- [[]]
-- [[A pack is a compact newline-separated list of kebab names plus the shared
-- [[URL prefix. Nothing is expanded up front:
-- [[]]
-- [[]  * `data[name]` computes the PNG URL on the first lookup and caches it,
-- [[    so a startup that shows twenty icons builds twenty strings instead of
-- [[    1,700-5,100 strings for a pack's full catalog;
-- [[]  * names that are not in the pack resolve to nil without being cached,
-- [[    so the resolver's "try the next pack" search keeps working;
-- [[]  * `__iter` enumerates the catalog (Icons.list / Icons.count), building
-- [[    each URL as it is asked for;
-- [[]  * the pack's table is a plain table with a metatable, so it behaves
-- [[    exactly like the old eagerly expanded table to every caller.
-- [[]]
-- [[The PNG file base is the kebab name converted to PascalCase, splitting on
-- [["-" and "_" (material uses underscores, heroicons mixes both). Every one
-- [[of the catalog's entries is machine-verified to follow this rule, so the
-- [[value column the old tables carried is derived instead of stored, which
-- [[removes thousands of table constructors from the bundle's compile path.
-- ]]

local PackBuilder = {}

local sub = string.sub
local lower = string.lower
local gmatch = string.gmatch
local gsub = string.gsub
local upper = string.upper

-- [[kebab/snake name -> PascalCase file base: "a-b-2" -> "AB2",
-- [["x-mark_solid" -> "XMarkSolid". Only ASCII icon names are catalogued.]]
local function pascalCase(name: string): string
	-- [[Each "-x"/"_x" segment loses its separator and capitalises the letter.]]
	local base = gsub(name, "[-_](%w)", function(letter)
		return upper(letter)
	end)
	-- [[A leading lowercase letter is the first Pascal segment.]]
	local first = sub(base, 1, 1)
	local lowered = lower(first)
	if first ~= lowered then
		return base
	end
	return upper(first) .. sub(base, 2)
end

-- [[Build a lazy pack table. `prefix` ends in "/", `packName` is the segment
-- [[used in the URL layout (`.../<pack><Name>.png`) — flat per-pack folders,
-- [[no a/b/c sharding.]]
function PackBuilder.create(prefix: string, packName: string, keyList: string): { [string]: string }
	-- [[Membership + stable enumeration order, built once when the pack module
	-- [[is first required. These are short string inserts only - the long URL
	-- [[concatenations the old expand() did per entry happen lazily below.]]
	local keys = {}
	local known = {}
	for key in gmatch(keyList, "%S+") do
		if not known[key] then
			known[key] = true
			keys[#keys + 1] = key
		end
	end

	local data = {}

	return setmetatable(data, {
		__index = function(_, key: string)
			if not known[key] then
				return nil
			end
			local fileBase = pascalCase(key)
			local url = prefix .. packName .. fileBase .. ".png"
			-- [[Cache the answer so repeated lookups skip this closure.]]
			rawset(data, key, url)
			return url
		end,
		__iter = function()
			local index = 0
			return function()
				index += 1
				local key = keys[index]
				if key == nil then
					return nil
				end
				-- [[Second value is the resolved URL, matching a normal
				-- [[key/value traversal of the old expanded table.]]
				return key, data[key]
			end
		end,
	}) :: { [string]: string }
end

return PackBuilder
