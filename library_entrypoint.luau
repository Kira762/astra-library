local Core = require(script.Parent.core)
local State = require(script.Parent.core.state)
local Image = require(script.Parent.images.image)
local Locale = require(script.Parent.utilities.locale)
local Constants = require(script.Parent.utilities.constants)
local Icons = require(script.Parent.icons)
local Motion = require(script.Parent.utilities.motion)
local Settings = require(script.Parent.settings)
local TypesModule = require(script.Parent.Types)

export type Theme = types.Theme
export type Translator = types.Translator
export type Translations = types.Translations
export type WindowConfiguration = types.WindowConfiguration

export type WindowProps = types.WindowProps
export type TabProps = types.TabProps
export type TagProps = types.TagProps
export type SectionProps = types.SectionProps
export type GroupProps = types.GroupProps
export type CollapsibleGroupProps = types.CollapsibleGroupProps
export type CollapsibleElementProps = types.CollapsibleElementProps
export type ButtonProps = types.ButtonProps
export type ToggleProps = types.ToggleProps
export type SliderProps = types.SliderProps
export type DropdownProps = types.DropdownProps
export type InputProps = types.InputProps
export type KeybindProps = types.KeybindProps
export type StatProps = types.StatProps
export type ProgressProps = types.ProgressProps
export type TextProps = types.TextProps
export type DividerProps = types.DividerProps
export type NotifyProps = types.NotifyProps
export type ToastProps = types.ToastProps
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
export type Keybind = types.Keybind
export type Stat = types.Stat
export type Progress = types.Progress
export type Section = types.Section
export type TabSection = types.TabSection
export type Text = types.Text
export type Divider = types.Divider
export type Tag = types.Tag
export type Popup = types.Popup
export type Astra = types.Astra

type WindowModule = { new: (types.WindowProps) -> types.Window }

local Astra = {} :: Astra
local activeWindow: types.Window? = nil
local ACTIVE_WINDOW_KEY = "__ASTRA_ACTIVE_WINDOW_V1"
local STARTUP_REVEAL_DELAY = 1

-- [[Beats of the arrival sequence, in seconds: how long the window waits after
-- the host's build goes quiet before it shows itself, and how long a font
-- download waits for that entrance before it triggers its own full theme pass.
-- Both are cooldowns between *parts* of startup, not extra work: neither makes
-- the interface take longer to be usable, they stop several expensive steps
-- from all taking the same frame. The settle stays inside one or two frames on
-- purpose — the entrance and everything after it are where the slack belongs.]]
local STARTUP_SETTLE = 0.1
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
	-- Count module loading and shell construction toward the one-second reveal
	-- target. If either is slow, the shell opens on the next available frame
	-- rather than adding another full delay afterward.
	local creationStartedAt = os.clock()
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
	window._startupStartedAt = creationStartedAt
	activeWindow = window
	globalStore[ACTIVE_WINDOW_KEY] = window
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
	end
	if State.secureMode then
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
		-- Reveal on a predictable deadline instead of waiting for an arbitrarily
		-- large host script to finish. Checkpoints continue pacing the remaining
		-- constructors after this, so the opening tween keeps receiving frames.
		task.defer(function()
			local remaining = STARTUP_REVEAL_DELAY - (os.clock() - creationStartedAt)
			if remaining > 0 then
				task.wait(remaining)
			else
				-- The constructor already consumed the target interval. Still yield
				-- once so the caller can add its first tab before the shell appears.
				task.wait()
			end

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

			-- Keep post-reveal constructors at one completed control per frame
			-- until two consecutive frames observe no construction activity.
			local stableFrames = 0
			while not window.unloaded and not window._autoShowCancelled and stableFrames < 2 do
				local revision = window._constructionRevision
				task.wait()
				if (window._constructionBusy or 0) == 0 and revision == window._constructionRevision then
					stableFrames += 1
				else
					stableFrames = 0
				end
			until (window._constructionBusy or 0) == 0 and revision == window._constructionRevision

			-- [[One beat of slack between the last batch of the build and the
			-- entrance. The tail of a host's script — a configuration read, an
			-- image preloading, the first frames of layout settling — used to
			-- land on the same frame the window opened on, which is what made a
			-- long load end in a stutter instead of an arrival. The window is
			-- still handed the next frames to itself, and everything the script
			-- queued (toasts, notifications, the profile card) follows it.]]
			local settled = 0
			while settled < STARTUP_SETTLE do
				if window.unloaded or window._autoShowCancelled then
					return
				end
				settled += task.wait()
				-- [[A host that carries on building from a delayed callback
				-- keeps the entrance parked until it goes quiet again: showing
				-- mid-batch is exactly the thing this loop exists to avoid.]]
				while (window._constructionBusy or 0) > 0 do
					if window.unloaded or window._autoShowCancelled then
						return
					end
					settled += task.wait()
				end
			end

			window:Show()
		end)
	end

	return window
end

return Astra
