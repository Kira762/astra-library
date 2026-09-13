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
export type ButtonProps = types.ButtonProps
export type ToggleProps = types.ToggleProps
export type SliderProps = types.SliderProps
export type DropdownProps = types.DropdownProps
export type InputProps = types.InputProps
export type KeybindProps = types.KeybindProps
export type StatProps = types.StatProps
export type ProgressProps = types.ProgressProps
export type ConsoleProps = types.ConsoleProps
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
export type Button = types.Button
export type Toggle = types.Toggle
export type Slider = types.Slider
export type Dropdown = types.Dropdown
export type Input = types.Input
export type Keybind = types.Keybind
export type Stat = types.Stat
export type Progress = types.Progress
export type Console = types.Console
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
				window:ChangeTheme({ Font = mediumFont, TitleFont = semiBoldFont })
			end
		end)
	end

	if not window.unloaded then
		-- Wait for a quiet frame. Construction may yield in large scripts;
		-- don't auto-show a half-populated window at one of those boundaries.
		task.defer(function()
			local revision
			repeat
				revision = window._constructionRevision
				task.wait()
				if window.unloaded or window._autoShowCancelled then
					return
				end
			until (window._constructionBusy or 0) == 0 and revision == window._constructionRevision
			window:Show()
		end)
	end

	return window
end

return Astra
