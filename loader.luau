--[[
Astra loader — fetches and executes the current version-1.luau bundle.

    loadstring(game:HttpGet("https://raw.githubusercontent.com/Kira762/astra-library/main/loader.luau"))()

The loader does not verify signatures or hashes. It fetches the bundle, compiles
it, and returns its API. Failures return a quiet no-op stub.

Set ASTRA_LOADER_NO_AUTORUN = true before running this file to receive the
loader internals table for tests instead of fetching the bundle.
]]

local BUNDLE_URL = "https://raw.githubusercontent.com/Kira762/astra-library/main/version-1.luau"

local function quietStub()
	local stub = {}
	return setmetatable(stub, {
		__index = function()
			return stub
		end,
		__call = function()
			return stub
		end,
		__newindex = function(t, k, v)
			rawset(t, k, v)
		end,
	})
end

local function tryFetch(url)
	if type(HttpGet) == "function" then
		local ok, res = pcall(HttpGet, url)
		if ok and type(res) == "string" and #res > 0 then
			return res
		end
	end
	if game ~= nil then
		local ok, res = pcall(function()
			return game:HttpGet(url)
		end)
		if ok and type(res) == "string" and #res > 0 then
			return res
		end
		ok, res = pcall(function()
			return game:GetService("HttpService"):GetAsync(url)
		end)
		if ok and type(res) == "string" and #res > 0 then
			return res
		end
	end
	return nil
end

local function main()
	local bundle = tryFetch(BUNDLE_URL)
	if type(bundle) ~= "string" or #bundle == 0 then
		return quietStub()
	end
	local compileOk, fn = pcall(loadstring, bundle, "AstraBundle")
	if not compileOk or type(fn) ~= "function" then
		return quietStub()
	end
	local runOk, api = pcall(fn)
	if not runOk or type(api) ~= "table" then
		return quietStub()
	end
	return api
end

local internals = {
	quietStub = quietStub,
	tryFetch = tryFetch,
	main = main,
	BUNDLE_URL = BUNDLE_URL,
}

local noAuto = false
pcall(function()
	noAuto = ASTRA_LOADER_NO_AUTORUN == true
end)
if noAuto then
	return internals
end

local ok, result = pcall(main)
if not ok or type(result) ~= "table" then
	return quietStub()
end
return result
