--[[
===== default window icon (topbar + collapsed capsule) regression =====
Runs the real Astra bundle (loaded as global `Astra` above) against the
mini Roblox environment from sidebar_sizing_stubs.luau.

The centralize-icons change dropped the `sirius` named asset and moved
assets/window-icons/sirius.png away, so the default window icon resolved
to the bare string "sirius": the topbar window icon and the collapsed
capsule (pill) icon both rendered blank. This suite pins the chain back:
  * W1  "sirius" (and the legacy "Sirius" spelling) resolves to the
         loadable assets/window-icons/sirius.png source - never the
         bare name, which no Image property can load,
  * W2  a window built with no icon carries that loadable value on
         both `icon` (topbar) and `showIcon` (capsule), and both
         labels exist,
  * W3  a user file at custom_asset/sirius.png wins over the named
         asset, and dropping it restores the named source,
  * W4  an explicit CreateWindow icon still resolves from the packs.
]]

local function expect(cond, message)
	if not cond then
		error("WINDOW ICON FAIL: " .. tostring(message), 0)
	end
end

local function eq(actual, wanted, message)
	if actual ~= wanted then
		error(
			"WINDOW ICON FAIL: "
				.. tostring(message)
				.. " (got "
				.. tostring(actual)
				.. ", wanted "
				.. tostring(wanted)
				.. ")"
		)
	end
end

local Icons = Astra.Icons
local ASSET_BASE = "https://raw.githubusercontent.com/Kira762/astra-version-1/main/"
local SIRIUS_URL = ASSET_BASE .. "assets/window-icons/sirius.png"

local function isLoadable(value)
	return type(value) == "string"
		and (value:match("^https?://") ~= nil or value:match("^rbxasset") ~= nil)
end

-- ===== W1: the default window icon name resolves to a loadable source =====

eq(Icons.resolve("sirius"), SIRIUS_URL, "W1 sirius resolves to the window-icons source")
expect(isLoadable(Icons.resolve("sirius")), "W1 the answer is a loadable image value")
eq(Icons.resolve("Sirius"), SIRIUS_URL, "W1 the legacy Sirius spelling resolves too")

-- ===== W2: a default window carries it on topbar and capsule ===============

local window = Astra:CreateWindow({ name = "WindowIcon" })
TestPump(0.6)

eq(window.icon, SIRIUS_URL, "W2 the topbar icon is the loadable source")
eq(window.showIcon, SIRIUS_URL, "W2 the capsule (pill) icon is the loadable source")
expect(window.topbarIcon ~= nil, "W2 the topbar label exists")
expect(window.collapsedIcon ~= nil, "W2 the collapsed capsule label exists")

-- ===== W3: a custom file wins over the named asset =========================

getcustomasset = function(path)
	if path == "custom_asset/sirius.png" then
		return "rbxasset://custom/sirius"
	end
	error("no such custom asset: " .. tostring(path))
end
listfiles = function()
	return { "custom_asset/sirius.png" }
end

Icons.refreshCustom()
eq(Icons.resolve("sirius"), "rbxasset://custom/sirius", "W3 a custom sirius.png wins")

listfiles = function()
	return {}
end
Icons.refreshCustom()
eq(Icons.resolve("sirius"), SIRIUS_URL, "W3 dropping the custom file restores the named source")

getcustomasset = nil
listfiles = nil
Icons.refreshCustom()

-- ===== W4: an explicit icon still resolves from the packs ==================

local explicit = Astra:CreateWindow({ name = "ExplicitIcon", icon = "house" })
TestPump(0.3)

eq(explicit.icon, Icons.resolve("house"), "W4 an explicit pack icon resolves")
expect(isLoadable(explicit.icon), "W4 the explicit answer is loadable")
eq(explicit.showIcon, explicit.icon, "W4 the capsule follows the explicit icon")
