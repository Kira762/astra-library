local Core = require(script.Parent.core)
local State = require(script.Parent.core.state)
local Image = require(script.Parent.images.image)
local Locale = require(script.Parent.utilities.locale)
local Constants = require(script.Parent.utilities.constants)
local Icons = require(script.Parent.icons)
local Motion = require(script.Parent.utilities.motion)
local Settings = require(script.Parent.settings)
local HardwarePerformance = require(script.Parent.utilities.hardwarePerformance)
--[[
Binds the `types` name used by every `types.X` annotation below. Types.luau
is a sibling of the entrypoint in both mounts (`script.Parent.Types` in the
Rojo/wax tree and in the generated bundle), and it returns an empty table,
so this require exists only to give the type checker a name to resolve.
]]
local types = require(script.Parent.Types)

export type Theme = types.Theme
export type Translator = types.Translator
export type Translations = types.Translations
export type WindowConfiguration = types.WindowConfiguration

export type WindowProps = types.WindowProps
export type TabProps = types.TabProps
export type SectionProps = types.SectionProps
export type GroupProps = types.GroupProps
export type CollapsibleGroupProps = types.CollapsibleGroupProps
export type IsolatedProps = types.IsolatedProps
export type IsolatedElementProps = types.IsolatedElementProps
export type CollapsibleElementProps = types.CollapsibleElementProps
export type ButtonProps = types.ButtonProps
export type ToggleProps = types.ToggleProps
export type SliderProps = types.SliderProps
export type ModePickerProps = types.ModePickerProps
export type ModeDefinition = types.ModeDefinition
export type DropdownProps = types.DropdownProps
export type InputProps = types.InputProps
export type StatProps = types.StatProps
export type TextProps = types.TextProps
export type DividerProps = types.DividerProps
export type AboutCardRow = types.AboutCardRow
export type AboutCardAction = types.AboutCardAction
export type AboutCardProps = types.AboutCardProps
export type NotifyProps = types.NotifyProps
export type PopupBox = types.PopupBox
export type PopupOption = types.PopupOption
export type PopupProps = types.PopupProps

export type Moveable = types.Moveable
export type Lockable = types.Lockable
export type Window = types.Window
export type Tab = types.Tab
export type Group = types.Group
export type CollapsibleGroup = types.CollapsibleGroup
export type Isolated = types.Isolated
export type Button = types.Button
export type Toggle = types.Toggle
export type Slider = types.Slider
export type ModePicker = types.ModePicker
export type Dropdown = types.Dropdown
export type Input = types.Input
export type Stat = types.Stat
export type Section = types.Section
export type TabSection = types.TabSection
export type Text = types.Text
export type Divider = types.Divider
export type AboutCard = types.AboutCard
export type Popup = types.Popup
export type KeySystem = types.KeySystem
export type Astra = types.Astra

type WindowModule = { new: (types.WindowProps) -> types.Window }

local Astra = {} :: Astra
local activeWindow: types.Window? = nil
local ACTIVE_WINDOW_KEY = "__ASTRA_ACTIVE_WINDOW_V1"
local LIVE_WINDOWS_KEY = "__ASTRA_LIVE_WINDOWS_V1"
local GENERATION_KEY = "__ASTRA_WINDOW_GENERATION_V1"

--[[
How long a font download waits for the entrance before it triggers its own
full theme pass. It is a cooldown between *parts* of startup, not extra
work: a font swap walks every instance the window owns, so running it while
the window is still arriving would put that pass on the frames the entrance
needs. Bounded, because a host that never shows the window must still end
up with its font. There is deliberately no reveal gate beside it: the
window shows on the next frame and the remaining constructors stream in
behind it in small budget-limited batches.
]]
local FONT_SETTLE_BUDGET = 3

local function getGlobalStore(): { [string]: any }
	local globalEnv = _G :: any
	local ok, genvResult = pcall(function()
		return (getgenv :: any)()
	end)
	return if ok and type(genvResult) == "table" then genvResult else globalEnv
end

local globalStore = getGlobalStore()

local function getLiveWindows(): { types.Window }
	local live = globalStore[LIVE_WINDOWS_KEY]
	if type(live) ~= "table" then
		live = {}
		globalStore[LIVE_WINDOWS_KEY] = live
	end
	return live
end

local function trackedWindows(): { types.Window }
	local seen: { [types.Window]: boolean } = {}
	local list: { types.Window } = {}

	local function add(value: any)
		if type(value) ~= "table" then
			return
		end
		local window = value :: types.Window
		if seen[window] then
			return
		end
		seen[window] = true
		table.insert(list, window)
	end

	add(activeWindow)
	add(globalStore[ACTIVE_WINDOW_KEY])
	local live = globalStore[LIVE_WINDOWS_KEY]
	if type(live) == "table" then
		for _, window in live do
			add(window)
		end
	end
	return list
end

local function forgetWindow(window: types.Window)
	if activeWindow == window then
		activeWindow = nil
	end
	if globalStore[ACTIVE_WINDOW_KEY] == window then
		globalStore[ACTIVE_WINDOW_KEY] = nil
	end
	local live = globalStore[LIVE_WINDOWS_KEY]
	if type(live) ~= "table" then
		return
	end
	for index = #live, 1, -1 do
		if live[index] == window then
			table.remove(live, index)
		end
	end
end

local function rememberWindow(window: types.Window)
	activeWindow = window
	globalStore[ACTIVE_WINDOW_KEY] = window
	local live = getLiveWindows()
	for _, existing in live do
		if existing == window then
			return
		end
	end
	table.insert(live, window)
end

local function isReplaceableWindow(window: types.Window): boolean
	local anyWindow = window :: any
	if anyWindow.unloaded then
		return false
	end
	local settings = anyWindow.settings
	return not (type(settings) == "table" and settings.antiWindowDuplicate == false)
end

local function unloadWindow(window: types.Window)
	local anyWindow = window :: any
	if type(anyWindow.Unload) == "function" and not anyWindow.unloaded then
		pcall(anyWindow.Unload, anyWindow)
	end
	forgetWindow(window)
end

local function unloadReplaceableWindows(except: types.Window?)
	for _, window in trackedWindows() do
		if window ~= except and isReplaceableWindow(window) then
			unloadWindow(window)
		elseif (window :: any).unloaded then
			forgetWindow(window)
		end
	end
end

Astra.Icons = Icons

--[[
The motion service is public: hosts can animate with the library's own
specs (`Astra.Motion.tween(frame, props, "snappy")`) and steer the whole
interface's timing (`setProfile`, `setTimeScale`, `setEnabled`).
]]
Astra.Motion = Motion

Astra.Core = Core
Astra.Settings = Settings
Astra.Performance = HardwarePerformance

function Astra:CreateWindow(props: types.WindowProps): types.Window
	--[[
	Anti-duplicate has to claim the slot *before* `Window.new` can yield.
	Construction checkpoints with `task.wait`, so a second `loadstring` can
	start while the first window is still being built. Storing only the
	finished window (and only one of them) is what left orphans behind when
	the script was spam-executed: the later call saw an empty store, built
	another shell, and the earlier one was never unloaded.
	]]
	local antiDuplicateEnabled = Settings.readPersisted("antiWindowDuplicate", true)
	local claimedGeneration: number? = nil
	if antiDuplicateEnabled then
		claimedGeneration = (tonumber(globalStore[GENERATION_KEY]) or 0) + 1
		globalStore[GENERATION_KEY] = claimedGeneration
		unloadReplaceableWindows(nil)
	else
		for _, existing in trackedWindows() do
			if (existing :: any).unloaded then
				forgetWindow(existing)
			end
		end
	end

	local ok, result = pcall(function()
		return (require(script.Parent.components.window) :: WindowModule).new(props)
	end)
	if not ok then
		error(result, 0)
	end

	local window = result :: types.Window
	if antiDuplicateEnabled then
		if globalStore[GENERATION_KEY] ~= claimedGeneration then
			--[[
			A later CreateWindow claimed the slot while this one was
			still constructing. Do not unload here: the host that called
			us keeps running and is about to add tabs and elements to
			the window we return, so destroying it now would interrupt
			that construction (the "Window unloaded during
			construction" crash). Mark it superseded instead — the
			reveal thread below never shows it and unloads it as soon
			as its construction has gone quiet, and the checkpoints
			plus `Window:Create` keep any tail that outlives even that
			moment detached instead of crashed.
			]]
			(window :: any)._superseded = true
		else
			unloadReplaceableWindows(window)
			if not (window :: any).unloaded then
				rememberWindow(window)
			end
		end
	else
		rememberWindow(window)
	end
	--[[
	One secure-mode branch: the optional-icon preload and the brand-font
	swap are independent, so they run as sibling threads rather than in two
	separately-guarded blocks.
	]]
	if State.secureMode then
		task.defer(function()
			Image.preload(function(failedCount, failedRoles)
				if failedCount <= 0 or window.unloaded then
					return
				end
				local failedLabel = if #failedRoles > 0
					then table.concat(failedRoles, ", ")
					else "optional window icon"
				window:Notify({
					title = Locale.resolve("Optional icon warning"),
					content = Locale.resolve("Failed to load: ") .. failedLabel,
				})
			end)
		end)
		task.spawn(function()
			--[[
			Startup brand-font swap — only for the `brand` selection
			(Settings → Appearance → Font); the stock default is already
			what the startup theme resolve painted. A font swap is a theme
			pass over every instance the window owns, so it waits for the
			window to land before applying — bounded, because a host that
			never shows the window must still end up with its font.
			]]
			if window.settings.fontChoice ~= "brand" then
				return
			end
			local waited = 0
			while
				waited < FONT_SETTLE_BUDGET
				and not window.unloaded
				and (not window.hasShownOnce or window.animating)
			do
				waited += task.wait()
			end
			if not window.unloaded then
				window:_applyFontSetting()
			end
		end)
	end

	if not window.unloaded then
		--[[
		Reveal on the next frame instead of on a fixed one-second deadline.
		The old gate waited out the interval even for an empty window, which
		is the 1s of the reported startup lag that every script paid. The
		checkpoints below keep pacing the remaining constructors in small
		budget-limited batches until the build goes quiet, so the opening
		tween keeps receiving frames while late controls stream in behind
		the already-visible shell.
		]]
		task.defer(function()
			--[[
			Still yield once so the caller can add its first tab before the
			shell appears.
			]]
			task.wait()

			if window.unloaded then
				return
			end
			if (window :: any)._superseded then
				--[[
				A later CreateWindow overtook this one mid-construction.
				The host already received the window and keeps adding
				controls to it, so wait for that construction to go
				quiet (the same two-stable-frames signal used below)
				before unloading — never show it. Unloading any earlier
				could land between two of the host's constructors; the
				checkpoint and `Window:Create` detach paths keep even
				that tail harmless.
				]]
				local stableFrames = 0
				while not window.unloaded and stableFrames < 2 do
					local revision = window._constructionRevision
					task.wait()
					if (window._constructionBusy or 0) == 0 and revision == window._constructionRevision then
						stableFrames += 1
					else
						stableFrames = 0
					end
				end
				if not window.unloaded then
					unloadWindow(window)
				end
				return
			end
			if window._autoShowCancelled then
				window._startupComplete = true
				return
			end
			if window.hidden then
				window:Show()
			end

			--[[
			Keep pacing post-reveal constructors until two consecutive frames
			observe no construction activity.
			]]
			local stableFrames = 0
			while not window.unloaded and not window._autoShowCancelled and stableFrames < 2 do
				local revision = window._constructionRevision
				task.wait()
				if (window._constructionBusy or 0) == 0 and revision == window._constructionRevision then
					stableFrames += 1
				else
					stableFrames = 0
				end
			end

			if window.unloaded or window._autoShowCancelled then
				return
			end
			window:Show()

			--[[
			Auto-load persisted control state once the host's constructors
			have gone quiet: that quiet point is the de-facto "startup
			finished" signal (the constructor itself returns before the
			host has added any tab). The load applies over the controls in
			small checkpoints, and controls registered even later are
			still covered by Window:_restoreLate. Runs once per window; a
			missing file or autoLoad turned off simply skips it.
			]]
			if window.configuration and window.configuration.autoLoad and not window._autoLoadDone then
				window._autoLoadDone = true
				window:Load()
			end
		end)
	end

	return window
end

--[[
Standalone key gate. The module is required lazily, like the window, so
hosts that never gate pay nothing at startup; the constructor either shows
the card or passes straight through to `onSuccess` (no keys configured, or
a saved key already matches).
]]
function Astra:CreateKeySystem(props: types.KeySystemProps): types.KeySystem
	local ok, result = pcall(function()
		return (require(script.Parent.components.keySystem) :: any).new(props)
	end)
	if not ok then
		error(result, 0)
	end
	return result
end

return Astra
