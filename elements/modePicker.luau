local state = {}
state.__index = state
state.__type = "ModePicker"

local constants = script.Parent.Parent.utilities

local ModePicker = require(constants.Parent.core.state)
local locale = require(constants.locale)
local haptic = require(constants.HapticEngine)
local lockable = require(constants.lockable)
--[[
The Mode Picker rides the shared motion vocabulary: the knob travels on
`normal` (the same beat as a slider value change), a drag chase would need
`fast` but the picker snaps instead of chasing, hover steps use `snappy`,
and the reset/icon colour shifts drift on the delayed accent beat so a
mode change reads as one gesture: knob first, colour after.
]]
local motion = require(constants.motion)
local travel = "normal"
local hover = "snappy"
local accentBase = TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out, 0, false, 0.35)
local function accentTween()
	return motion.spec(accentBase)
end

--[[
One set of metrics, in one place. The track borrows the toggle's switch
height and the knob is the toggle's own knob (26x18 pill, radius half its
height), stretched onto a multi-stop track: the picker must read as the
library's switch with more resting places, not as a foreign control.
The knob keeps the toggle's clearance too — `knobGap` of track on every
side it can see — which is what makes the two pills concentric at the end
stops (the track's 11px cap and the knob's 9px cap share a centre) instead
of the knob jamming flush against the track's silhouette. Dots sit on the
track's centre line at the knob's centres, so the first and last stops park
the knob exactly over them.
]]
local trackHeight = 22
local trackRadius = UDim.new(0, trackHeight / 2)
local knobWidth = 26
local knobHeight = 18
local knobRadius = UDim.new(0, knobHeight / 2)
local dotSize = 4
local knobGap = 2 -- the toggle's switchInset: clearance all the way round
local stopInset = knobWidth / 2 + knobGap -- end stops keep the knob inside the track
local sidePad = 14

local titleY = 19
local subtitleY = 37
local headerCenter = 28
local trackY = 62
local baseHeight = 84

local MIN_MODES = 3
local MAX_MODES = 5

local function colorFromTable(value, fallback)
	if typeof(value) == "Color3" then
		return value
	end
	if typeof(value) == "table" and value.r then
		return Color3.fromRGB(value.r or 255, value.g or 255, value.b or 255)
	end
	return fallback
end

--[[
Modes arrive as a map (`[1] = {...}`) or an array; both normalize to a
dot_position-sorted list so gaps or out-of-order positions in a config
still lay out left to right.
]]
local function normalizeModes(raw)
	local list = {}
	if typeof(raw) == "table" then
		for key, mode in pairs(raw) do
			if typeof(mode) == "table" then
				table.insert(list, {
					label = tostring(mode.label or mode.Label or ("Mode " .. tostring(key))),
					type = mode.type or mode.Type or "dot",
					dot_position = tonumber(mode.dot_position or mode.DotPosition or key) or #list + 1,
					onEnable = mode.onEnable or mode.OnEnable,
					optional = mode.optional or mode.Optional or false,
					icon_color = mode.icon_color or mode.IconColor,
				})
			end
		end
	end
	table.sort(list, function(a, b)
		return a.dot_position < b.dot_position
	end)
	for index, mode in ipairs(list) do
		mode.dot_position = index
	end
	return list
end

function state.new(tab, element)
	element = if typeof(element) == "table" then element else {}

	local rawModes = element.modes or element.Modes or {}
	local modes = normalizeModes(rawModes)

	local minModes = math.clamp(tonumber(element.min_modes or element.MinModes or MIN_MODES) or MIN_MODES, MIN_MODES, MAX_MODES)
	local maxModes = math.clamp(tonumber(element.max_modes or element.MaxModes or MAX_MODES) or MAX_MODES, MIN_MODES, MAX_MODES)
	if maxModes < minModes then
		maxModes = minModes
	end
	if #modes < minModes or #modes > maxModes then
		error(`Astra:CreateModePicker — modes must be between {minModes} and {maxModes}, got {#modes}`, 0)
	end

	local forgetState = element.forgetState
	if forgetState == nil then
		forgetState = element.ForgetState
	end
	if forgetState == nil then
		forgetState = tab.forgetState
	end
	local titleText = tostring(element.title or element.Title or "Mode Picker")
	local isLockSystemController = element.lockSystemController == true or element.LockSystemController == true

	local self = setmetatable({
		tab = assert(tab, "Missing argument #1 (Tab expected)"),
		window = tab.window,
		titleText = titleText,
		subtitle = tostring(element.subtitle or element.Subtitle or ""),
		forgetState = forgetState == true,
		flag = element.flag
			or element.Flag
			or (
				not forgetState and tab.deriveFlagFromName(titleText)
				or nil
			),
		_lockSystemController = isLockSystemController,

		left_icon = tab.window:ResolveIcon(element.left_icon or element.LeftIcon or "zap"),
		right_icon = tab.window:ResolveIcon(element.right_icon or element.RightIcon or "rotate-ccw"),
		left_icon_color = colorFromTable(element.left_icon_color or element.LeftIconColor, Color3.fromRGB(255, 255, 255)),
		title_color_same_as_left_icon = (element.title_color_same_as_left_icon ~= false and element.TitleColorSameAsLeftIcon ~= false),
		reset_on_right_icon_press = (element.reset_on_right_icon_press ~= false and element.ResetOnRightIconPress ~= false),
		allow_mode_add_remove = (element.allow_mode_add_remove ~= false and element.AllowModeAddRemove ~= false),
		accent = element.accent or element.Accent or "theme",

		minModes = minModes,
		maxModes = maxModes,
		modes = modes,
		configModes = table.clone(modes),
		defaultMode = math.clamp(tonumber(element.mode or element.Mode or 1) or 1, 1, #modes),
		onReset = element.onReset or element.OnReset,
		callback = element.callback or element.Callback,

		dots = {},
	}, state)

	self.name = self.titleText
	self.mode = self.defaultMode

	self.window:_registerControl(self)
	self:_build()
	self._serialize = function(picker)
		return picker.mode
	end
	self._deserialize = function(picker, value)
		picker:Set(value, true)
	end
	lockable.register(self, element, { exempt = isLockSystemController })
	if isLockSystemController then
		self:_syncLockSystemMode()
	end

	return self
end

function state:_build()
	local window = self.window

	self.main = window:Create("Frame", {
		Size = UDim2.new(1, -20, 0, baseHeight),
		BorderSizePixel = 0,
		Name = "ModePicker",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		Parent = self.tab.tabPage,
	}, { BackgroundTransparency = "ElementTransparency" })

	self.stroke = window:StyleElementBody(self.main)
	self.hoverOverlay = window:CreateHoverOverlay(self.main)

	-- Header: display-only icon, centred title/subtitle stack, reset button.
	self.iconLabel = window:Create("ImageLabel", {
		Image = self.left_icon or "",
		Visible = self.left_icon ~= nil,
		Size = UDim2.fromOffset(18, 18),
		Position = UDim2.new(0, sidePad + 4, 0, headerCenter),
		AnchorPoint = Vector2.new(0, 0.5),
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		ImageTransparency = 1,
		ZIndex = 2,
		Parent = self.main,
	})
	self.iconLabel.ImageColor3 = self:_iconColor()

	self.title = window:Create("TextLabel", {
		Text = locale.t(self.titleText),
		Size = UDim2.new(1, -120, 0, 18),
		Position = UDim2.new(0.5, 0, 0, titleY),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextTransparency = 1,
		ZIndex = 2,
		Parent = self.main,
	}, self:_titleBinding())
	self.title.TextColor3 = self:_titleColor()

	self.subtitleLabel = window:Create("TextLabel", {
		Text = locale.t(self.subtitle),
		Visible = self.subtitle ~= "",
		Size = UDim2.new(1, -120, 0, 14),
		Position = UDim2.new(0.5, 0, 0, subtitleY),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextTransparency = 1,
		ZIndex = 2,
		Parent = self.main,
	}, { TextColor3 = "ContentColor", FontFace = "Font" })

	self.resetButton = window:Create("TextButton", {
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.new(1, -sidePad, 0, headerCenter),
		AnchorPoint = Vector2.new(1, 0.5),
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		Text = "",
		TextTransparency = 1,
		ZIndex = 3,
		Parent = self.main,
	})
	window:Create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = self.resetButton })
	self.resetGlyph = window:Create("ImageLabel", {
		Image = self.right_icon or "",
		Visible = self.right_icon ~= nil,
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		ImageTransparency = 1,
		Parent = self.resetButton,
	}, { ImageColor3 = "ContentColor" })

	window:ConnectFor(self, self.resetButton.MouseEnter, function()
		if not window:_interactive() or self:IsLocked() then
			return
		end
		motion.tween(self.resetButton, { BackgroundTransparency = 0.92 }, hover)
	end)
	window:ConnectFor(self, self.resetButton.MouseLeave, function()
		motion.tween(self.resetButton, { BackgroundTransparency = 1 }, hover)
	end)
	window:ConnectFor(self, self.resetButton.MouseButton1Click, function()
		if self:IsLocked() then
			return
		end
		haptic.click()
		if self.reset_on_right_icon_press then
			self:Reset()
		end
	end)

	self:_buildTrack()
	self:_applyMode(self.mode, true)

	window:_wireElementHover(self)
end

function state:_buildTrack()
	local window = self.window

	self.track = window:Create("Frame", {
		Size = UDim2.new(1, -sidePad * 2, 0, trackHeight),
		Position = UDim2.new(0, sidePad, 0, trackY),
		AnchorPoint = Vector2.new(0, 0.5),
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = self.main,
	}, { BackgroundColor3 = "SliderBackground" })
	self.track.BackgroundColor3 = window.theme.SliderBackground
	window:Create("UICorner", { CornerRadius = trackRadius, Parent = self.track })

	--[[
	The fill wears the knob's own pill: the same height, the same radius and
	the same clearance inside the track. A full-height fill under a shorter
	knob used to bleed accent above and below it and around its rounded
	corners (the fill's 11px cap is a bigger arc than the knob's 9px), so
	the knob read as half-painted at every stop.
	]]
	self.fill = window:Create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, knobGap, 0.5, 0),
		Size = UDim2.new(0, 0, 0, knobHeight),
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		ZIndex = 3,
		Parent = self.track,
	}, self:_fillBinding())
	window:Create("UICorner", { CornerRadius = knobRadius, Parent = self.fill })
	window:Create("UIGradient", {
		Color = ColorSequence.new(Color3.new(0.72, 0.72, 0.72), Color3.new(1, 1, 1)),
		Parent = self.fill,
	})

	-- Create applies explicit properties after theme bindings; paint the initial fill
	-- explicitly so the first frame does not flash white.
	self.fill.BackgroundColor3 = self:_accentColor()
	self.fillGlow = window:CreateGlow(self.fill, self:_accentColor(), 20, 1)

	self.knob = window:Create("Frame", {
		Size = UDim2.fromOffset(knobWidth, knobHeight),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, stopInset, 0.5, 0),
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = self.track,
	})
	window:Create("UICorner", { CornerRadius = knobRadius, Parent = self.knob })
	self.knobStroke = window:Create("UIStroke", {
		Transparency = 1,
		Color = Color3.fromRGB(255, 255, 255),
		Parent = self.knob,
	})
	self.knobGlow = window:CreateGlow(self.knob, Color3.fromRGB(255, 255, 255), 10, 1)

	self:_buildDots()

	self.interact = window:Create("TextButton", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 8),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Text = "",
		TextTransparency = 1,
		ZIndex = 10,
		Parent = self.track,
	})

	window:ConnectFor(self, self.interact.InputBegan, function(input)
		if
			not window:_interactive()
			or self:IsLocked()
			or not (
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			return
		end
		haptic.click()
		self.dragging = true
		self:_setHeld(true)
		self:_updateFromMouse()

		if self._dragConnection then
			self._dragConnection:Disconnect()
			self._dragConnection = nil
		end
		self._dragConnection = ModePicker.runService.RenderStepped:Connect(function()
			if self.window.unloaded or not self.dragging then
				if self._dragConnection then
					self._dragConnection:Disconnect()
					self._dragConnection = nil
				end
				return
			end
			self:_updateFromMouse()
		end)
	end)

	window:ConnectFor(self, ModePicker.userInputService.InputEnded, function(input)
		if
			self.dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			self:_endDrag()
		end
	end)
end

function state:_buildDots()
	local window = self.window
	for _, dot in ipairs(self.dots) do
		window:DestroySubtree(dot)
	end
	self.dots = {}

	local count = #self.modes
	for index = 1, count do
		local fraction = if count > 1 then (index - 1) / (count - 1) else 0.5
		local dot = window:Create("Frame", {
			Size = UDim2.fromOffset(dotSize, dotSize),
			Position = UDim2.new(fraction, stopInset - fraction * stopInset * 2, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BorderSizePixel = 0,
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 1,
			ZIndex = 4,
			Parent = self.track,
		})
		window:Create("UICorner", { CornerRadius = UDim.new(0, dotSize / 2), Parent = dot })
		table.insert(self.dots, dot)
	end
	self:_paintDots()
end

--[[
The fill follows the accent source: the theme accent by default (the
picker inherits the library's colours), or the left icon's RGB when the
config asks for it, in which case mode icon colours retint the fill too.
]]
function state:_fillBinding()
	if self.accent == "left_icon" then
		return {}
	end
	return { BackgroundColor3 = "AccentColor" }
end

function state:_accentColor()
	if self.accent == "left_icon" then
		return self:_iconColor()
	end
	return self.window.theme.AccentColor
end

function state:_iconColor()
	local mode = self.modes[self.mode]
	local override = mode and mode.icon_color
	if override then
		return colorFromTable(override, self.left_icon_color)
	end
	return self.left_icon_color
end

function state:_titleColor()
	if self.title_color_same_as_left_icon then
		return self:_iconColor()
	end
	return self.window.theme.ContentColor
end

--[[
While the title wears the icon's colour it carries no TextColor3 theme
binding — the window's own theme pass would paint a theme token over the
mode's colour. With the icon link off the title rests on ContentColor like
every other control title, so it binds to the token and a theme change
flows through the window's pass as well as `_refreshTheme`.
]]
function state:_titleBinding()
	if self.title_color_same_as_left_icon then
		return { FontFace = "Font" }
	end
	return { TextColor3 = "ContentColor", FontFace = "Font" }
end

--[[
`Window:_wireElementHover` reads this on every pointer event: the title's
rest colour belongs to the element (the icon's RGB, which the selected mode
can override), so the hover wiring must not settle it back onto a theme
token — that is what took the colour off the title after the first hover.
Nil hands the title back to the theme language when the icon link is off.
]]
function state:_titleRestColor()
	if self.title_color_same_as_left_icon then
		return self:_titleColor()
	end
	return nil
end

function state:_paintDots()
	local theme = self.window.theme
	for index, dot in ipairs(self.dots) do
		if index <= self.mode then
			dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			dot.BackgroundTransparency = 0.15
		else
			dot.BackgroundColor3 = theme.ContentColor
			dot.BackgroundTransparency = 0.6
		end
	end
end

function state:_stopFraction(index)
	local count = #self.modes
	if count <= 1 then
		return 0.5
	end
	return (index - 1) / (count - 1)
end

function state:_knobPosition(fraction)
	return UDim2.new(fraction, stopInset - fraction * stopInset * 2, 0.5, 0)
end

function state:_setHeld(held)
	local target = held and 0.25 or 0.55
	ModePicker.tweenService:Create(self.knobGlow, motion.spec("fast"), { Transparency = target }):Play()
	ModePicker.tweenService:Create(self.knobStroke, motion.spec("fast"), { Transparency = held and 0.55 or 0.85 }):Play()
end

function state:_updateFromMouse()
	local mouse = ModePicker.userInputService:GetMouseLocation()
	local track = self.track.AbsolutePosition
	local width = self.track.AbsoluteSize.X
	if width <= 0 then
		return
	end
	local usable = width - stopInset * 2
	if usable <= 0 then
		return
	end
	local fraction = math.clamp((mouse.X - track.X - stopInset) / usable, 0, 1)
	local nearest = math.round(fraction * (#self.modes - 1)) + 1
	if nearest ~= self.mode then
		haptic.click()
		self:Set(nearest)
	end
end

function state:_endDrag()
	self.dragging = false
	self:_setHeld(false)
	if self._dragConnection then
		self._dragConnection:Disconnect()
		self._dragConnection = nil
	end
	self.window:_persist(self)
end

--[[
One path for every mode change (drag, tap, Set, Reset): knob and fill
travel on the shared beat, dots repaint, and the icon/title/fill colours
drift if the mode carries an icon colour.
]]
function state:_applyMode(index, instant)
	local fraction = self:_stopFraction(index)
	local spec = if instant then nil else motion.spec(travel)

	if spec then
		ModePicker.tweenService:Create(self.knob, spec, { Position = self:_knobPosition(fraction) }):Play()
	else
		self.knob.Position = self:_knobPosition(fraction)
	end
	self:_renderFill(instant)
	self:_paintDots()
	self:_applyColors(instant)
end

--[[
The fill runs from the first stop's clearance to the knob's *trailing*
edge, on the same scale/offset pair the dots and the knob use — so all
four agree at every stop and at every track width without a resize
handler, and the last stop fills the track end to end instead of leaving
an unpainted tail behind the knob.
]]
function state:_fillSize(fraction)
	return UDim2.new(fraction, stopInset - fraction * stopInset * 2 + knobWidth / 2 - knobGap, 0, knobHeight)
end

function state:_renderFill(instant)
	local target = self:_fillSize(self:_stopFraction(self.mode))
	if instant then
		self.fill.Size = target
		return
	end
	ModePicker.tweenService:Create(self.fill, motion.spec(travel), { Size = target }):Play()
end

function state:_applyColors(instant)
	local icon = self:_iconColor()
	local spec = if instant then nil else accentTween()
	if spec then
		ModePicker.tweenService:Create(self.iconLabel, spec, { ImageColor3 = icon }):Play()
		if self.title_color_same_as_left_icon then
			ModePicker.tweenService:Create(self.title, spec, { TextColor3 = icon }):Play()
		end
		if self.accent == "left_icon" then
			ModePicker.tweenService:Create(self.fill, spec, { BackgroundColor3 = icon }):Play()
			ModePicker.tweenService:Create(self.fillGlow, spec, { Color = icon }):Play()
		end
	else
		self.iconLabel.ImageColor3 = icon
		if self.title_color_same_as_left_icon then
			self.title.TextColor3 = icon
		end
		if self.accent == "left_icon" then
			self.fill.BackgroundColor3 = icon
			self.fillGlow.Color = icon
		end
	end
end

local lockModeSubtitles = {
	[1] = "Mode 1 — all controls unlocked",
	[2] = "Mode 2 — inputs and selections locked",
	[3] = "Mode 3 — important actions locked",
	[4] = "Mode 4 — sensitive controls locked",
	[5] = "Mode 5 — all lockable controls locked",
}

function state:_syncLockSystemMode()
	if not self._lockSystemController then
		return
	end
	self.window:SetElementLockMode(self.mode)
	self:SetSubtitle(lockModeSubtitles[self.mode])
end

--[[
Mode changes commit through here: clamp, animate, fire the mode's own
onEnable plus the picker-level callback, and persist. `silent` skips
callbacks for restore paths, but the built-in lock controller still applies
the selected tier so restores and programmatic Set calls stay in sync.
]]
function state:Set(index, silent)
	index = math.clamp(math.round(tonumber(index) or self.mode), 1, #self.modes)
	local changed = index ~= self.mode
	self.mode = index
	self:_applyMode(index, false)
	self:_syncLockSystemMode()

	if changed and not silent then
		local mode = self.modes[index]
		if mode.onEnable then
			self.window:_runGuarded(self, mode.onEnable, index, mode.label)
		end
		if self.callback then
			self.window:_runGuarded(self, self.callback, index, mode.label)
		end
	end
	if not silent then
		self.window:_persist(self)
	end
	return self.mode
end

function state:Get()
	return self.mode, self.modes[self.mode].label
end

--[[
Reset restores the original state: Mode 1, the configured mode set (any
runtime additions/removals rolled back) and the configured icon colour,
then hands the config its onReset hook.
]]
function state:Reset()
	if #self.modes ~= #self.configModes then
		self.modes = table.clone(self.configModes)
		self:_buildDots()
	end
	self:Set(1, true)
	self.window:_persist(self)
	if self.onReset then
		self.window:_runGuarded(self, self.onReset, self)
	end
	return self.mode
end

function state:AddMode(mode)
	if not self.allow_mode_add_remove then
		return false, "mode add/remove is disabled"
	end
	if #self.modes >= self.maxModes then
		return false, `Astra:ModePicker — at most {self.maxModes} modes are supported, got {#self.modes + 1}`
	end
	local normalized = normalizeModes({ [#self.modes + 1] = mode })[1]
	if not normalized then
		return false, "Astra:ModePicker — AddMode expects a mode table"
	end
	table.insert(self.modes, normalized)
	table.sort(self.modes, function(a, b)
		return a.dot_position < b.dot_position
	end)
	for index, entry in ipairs(self.modes) do
		entry.dot_position = index
	end
	self:_buildDots()
	self:_applyMode(self.mode, true)
	return true
end

function state:RemoveMode(index)
	if not self.allow_mode_add_remove then
		return false, "mode add/remove is disabled"
	end
	local mode = self.modes[index]
	if not mode then
		return false, "Astra:ModePicker — unknown mode index"
	end
	if #self.modes <= self.minModes then
		return false, `Astra:ModePicker — at least {self.minModes} modes are required, got {#self.modes - 1}`
	end
	if not mode.optional then
		return false, "Astra:ModePicker — only optional modes can be removed"
	end
	table.remove(self.modes, index)
	for position, entry in ipairs(self.modes) do
		entry.dot_position = position
	end
	self:_buildDots()
	self:Set(math.min(self.mode, #self.modes), true)
	return true
end

function state:SetLeftIconColor(color)
	self.left_icon_color = colorFromTable(color, self.left_icon_color)
	self:_applyColors(false)
end

function state:SetSubtitle(text)
	self.subtitle = tostring(text or "")
	self.window:_bindLocale(self.subtitleLabel, "Text", self.subtitle)
	self.subtitleLabel.Visible = self.subtitle ~= ""
end

function state:_minWidth()
	return sidePad * 2 + 120 + 26
end

function state:_setShown(show, animate)
	local w = self.window
	--[[
	stroke, title, main and iconLabel are revealed by
	_revealCommon/_hideCommon; this list carries only the picker's own
	surfaces.
	]]
	local parts = {
		{ self.subtitleLabel, { TextTransparency = 0.35 } },
		{ self.resetGlyph, { ImageTransparency = 0.25 } },
		{ self.track, { BackgroundTransparency = 0 } },
		{ self.fill, { BackgroundTransparency = 0 } },
		{ self.knob, { BackgroundTransparency = 0 } },
		{ self.knobStroke, { Transparency = 0.85 } },
	}
	if show then
		w:_revealCommon(self, animate)
		for _, part in ipairs(parts) do
			w:_reveal(part[1], part[2], animate, travel)
		end
		for index, dot in ipairs(self.dots) do
			w:_reveal(dot, { BackgroundTransparency = if index <= self.mode then 0.15 else 0.6 }, animate, travel)
		end
		w:_reveal(self.fillGlow, { Transparency = math.max(0.55, w.theme.AccentGlow) }, animate, accentTween)
		w:_reveal(self.knobGlow, { Transparency = 0.55 }, animate, accentTween)
	else
		w:_hideCommon(self, animate)
		for _, part in ipairs(parts) do
			local hidden = {}
			for property in pairs(part[2]) do
				hidden[property] = 1
			end
			w:_reveal(part[1], hidden, animate, travel)
		end
		for _, dot in ipairs(self.dots) do
			w:_reveal(dot, { BackgroundTransparency = 1 }, animate, travel)
		end
		w:_reveal(self.fillGlow, { Transparency = 1 }, animate, accentTween)
		w:_reveal(self.knobGlow, { Transparency = 1 }, animate, accentTween)
	end
end

function state:_refreshTheme()
	local t = self.window.theme
	self:_paintDots()
	if self.accent ~= "left_icon" then
		self.fill.BackgroundColor3 = t.AccentColor
		self.fillGlow.Color = t.AccentColor
	else
		self.fill.BackgroundColor3 = self:_iconColor()
		self.fillGlow.Color = self:_iconColor()
	end
	if not self.title_color_same_as_left_icon then
		self.title.TextColor3 = t.ContentColor
	end
	ModePicker.tweenService:Create(self.fillGlow, motion.spec("smooth"), {
		Transparency = math.max(0.55, t.AccentGlow),
	}):Play()
end

local moveable = require(constants.moveable)
moveable(state)
lockable(state)

return state
