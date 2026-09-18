local Core = require(script.Parent.core)
local State = require(script.Parent.core.state)
local Image = require(script.Parent.images.image)
local Locale = require(script.Parent.utilities.locale)
local Constants = require(script.Parent.utilities.constants)
local Icons = require(script.Parent.icons)
local Motion = require(script.Parent.utilities.motion)
local Settings = require(script.Parent.settings)

export type Theme = types.Theme
export type Translator = types.Translator
export type Translations = types.Translations
export type WindowConfiguration = types.WindowConfiguration

export type WindowProps = types.WindowProps
export type TabProps = types.TabProps
export type SectionProps = types.SectionProps
export type GroupProps = types.GroupProps
export type CollapsibleGroupProps = types.CollapsibleGroupProps
export type CollapsibleElementProps = types.CollapsibleElementProps
export type ButtonProps = types.ButtonProps
export type ToggleProps = types.ToggleProps
export type SliderProps = types.SliderProps
export type DropdownProps = types.DropdownProps
export type InputProps = types.InputProps
export type StatProps = types.StatProps
export type TextProps = types.TextProps
export type DividerProps = types.DividerProps
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
export type Button = types.Button
export type Toggle = types.Toggle
export type Slider = types.Slider
export type Dropdown = types.Dropdown
export type Input = types.Input
export type Stat = types.Stat
export type Section = types.Section
export type TabSection = types.TabSection
export type Text = types.Text
export type Divider = types.Divider
export type Popup = types.Popup
export type Astra = types.Astra

type WindowModule = { new: (types.WindowProps) -> types.Window }

local Astra = {} :: Astra
local activeWindow: types.Window? = nil
local ACTIVE_WINDOW_KEY = "__ASTRA_ACTIVE_WINDOW_V1"

-- [[How long a font download waits for the entrance before it triggers its own
-- full theme pass. It is a cooldown between *parts* of startup, not extra
-- work: a font swap walks every instance the window owns, so running it while
-- the window is still arriving would put that pass on the frames the entrance
-- needs. Bounded, because a host that never shows the window must still end
-- up with its font. There is deliberately no reveal gate beside it: the
-- window shows on the next frame and the remaining constructors stream in
-- behind it in small budget-limited batches.]]
local FONT_SETTLE_BUDGET = 3

local function getGlobalStore(): { [string]: any }
	local globalEnv = _G :: any
	local ok, genvResult = pcall(function()
		return (getgenv :: any)()
	end)
	return if ok and type(genvResult) == "table" then genvResult else globalEnv
end

local globalStore = getGlobalStore()

Astra.Icons = Icons

-- [[The motion service is public: hosts can animate with the library's own
-- specs (`Astra.Motion.tween(frame, props, "snappy")`) and steer the whole
-- interface's timing (`setProfile`, `setTimeScale`, `setEnabled`).]]
Astra.Motion = Motion

Astra.Core = Core
Astra.Settings = Settings

function Astra:CreateWindow(props: types.WindowProps): types.Window
	local existingWindow = activeWindow or globalStore[ACTIVE_WINDOW_KEY]
	activeWindow = existingWindow
	if existingWindow then
		local existingAny = existingWindow :: any
		if existingAny.unloaded then
			activeWindow = nil
			if globalStore[ACTIVE_WINDOW_KEY] == existingWindow then
				globalStore[ACTIVE_WINDOW_KEY] = nil
			end
		else
			local antiDuplicateEnabled = Settings.readPersisted("antiWindowDuplicate", true)
			if antiDuplicateEnabled and (not existingAny.settings or existingAny.settings.antiWindowDuplicate ~= false) then
				existingAny:Unload()
				activeWindow = nil
				if globalStore[ACTIVE_WINDOW_KEY] == existingWindow then
					globalStore[ACTIVE_WINDOW_KEY] = nil
				end
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
	activeWindow = window
	globalStore[ACTIVE_WINDOW_KEY] = window
	-- [[One secure-mode branch: the optional-icon preload and the brand-font
	-- swap are independent, so they run as sibling threads rather than in two
	-- separately-guarded blocks.]]
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
			local mediumFont = State.fontManager:loadFont(Constants.fontAsset, Enum.FontWeight.Medium)
			local semiBoldFont = State.fontManager:loadFont(Constants.fontAsset, Enum.FontWeight.SemiBold)
			if
				not window.unloaded
				and mediumFont
				and semiBoldFont
				and mediumFont ~= State.fallbackFont
			and semiBoldFont ~= State.fallbackFont
		then
			-- [[A font swap is a theme pass over every instance the window
			-- owns, so running it while the window is still arriving puts that
			-- pass on the frames the entrance needs. It waits for the window to
			-- land instead — bounded, because a host that never shows the
			-- window must still end up with its font.]]
			local waited = 0
			while
				waited < FONT_SETTLE_BUDGET
				and not window.unloaded
				and (not window.hasShownOnce or window.animating)
			do
				waited += task.wait()
			end
			if not window.unloaded then
				window:ChangeTheme({ Font = mediumFont, TitleFont = semiBoldFont })
			end
		end
	end)
	end

	if not window.unloaded then
		-- Reveal on the next frame instead of on a fixed one-second deadline.
		-- The old gate waited out the interval even for an empty window, which
		-- is the 1s of the reported startup lag that every script paid. The
		-- checkpoints below keep pacing the remaining constructors in small
		-- budget-limited batches until the build goes quiet, so the opening
		-- tween keeps receiving frames while late controls stream in behind
		-- the already-visible shell.
		task.defer(function()
			-- Still yield once so the caller can add its first tab before the
			-- shell appears.
			task.wait()

			if window.unloaded then
				return
			end
			if window._autoShowCancelled then
				window._startupComplete = true
				return
			end
			if window.hidden then
				window:Show()
			end

			-- Keep pacing post-reveal constructors until two consecutive frames
			-- observe no construction activity.
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

			-- [[Auto-load persisted control state once the host's constructors
			-- [[have gone quiet: that quiet point is the de-facto "startup
			-- [[finished" signal (the constructor itself returns before the
			-- [[host has added any tab). The load applies over the controls in
			-- [[small checkpoints, and controls registered even later are
			-- [[still covered by Window:_restoreLate. Runs once per window; a
			-- [[missing file or autoLoad turned off simply skips it.]]
			if window.configuration and window.configuration.autoLoad and not window._autoLoadDone then
				window._autoLoadDone = true
				window:Load()
			end
		end)
	end

	return window
end

return Astra
