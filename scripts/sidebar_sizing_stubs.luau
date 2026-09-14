-- [[Mini Roblox environment for the sidebar tab-sizing test.]]
-- [[Extends the smoke stubs with a working Instance model (properties,]]
-- [[signals, parenting, destroy semantics) and service implementations]]
-- [[with deterministic behavior, so Astra:CreateWindow can run for real]]
-- [[and row sizes can be asserted.]]

-- The Luau CLI locks _G, so provide the executor's getgenv() store that the
-- entrypoint prefers for its active-window guard.
local genvStore = {}
getgenv = function()
	return genvStore
end

-- ===== value types =====

local function udim(scale, offset)
	return { Scale = scale or 0, Offset = offset or 0 }
end

UDim = { new = function(xs, xo) return udim(xs, xo) end }

UDim2 = {
	new = function(xs, xo, ys, yo) return { X = udim(xs, xo), Y = udim(ys, yo) } end,
	fromScale = function(xs, ys) return { X = udim(xs, 0), Y = udim(ys, 0) } end,
	fromOffset = function(xo, yo) return { X = udim(0, xo), Y = udim(0, yo) } end,
}

Vector2 = {
	new = function(x, y) return { X = x or 0, Y = y or 0 } end,
	zero = { X = 0, Y = 0 },
}

Vector3 = { new = function(x, y, z) return { X = x or 0, Y = y or 0, Z = z or 0 } end }

local function color3(r, g, b)
	return { R = r / 255, G = g / 255, B = b / 255 }
end

Color3 = {
	fromRGB = function(r, g, b) return color3(r, g, b) end,
	new = function(r, g, b) return color3(r * 255, g * 255, b * 255) end,
}

ColorSequenceKeypoint = { new = function(time, value) return { Time = time, Value = value } end }
ColorSequence = {
	new = function(...)
		local args = table.pack(...)
		-- [[ColorSequence.new(colorA, colorB) gradient form.]]
		if args.n == 2 and type(args[1]) == "table" and args[1].R ~= nil and type(args[2]) == "table" and args[2].R ~= nil then
			return {
				Keypoints = {
					ColorSequenceKeypoint.new(0, args[1]),
					ColorSequenceKeypoint.new(1, args[2]),
				},
			}
		end
		local keypoints = args.n >= 1 and args[1] or nil
		-- [[Already a ColorSequence (the stub's sequences are plain tables,]]
		-- [[so toColorSequence's typeof check re-wraps them; stay idempotent).]]
		if type(keypoints) == "table" and type(keypoints.Keypoints) == "table" then
			return { Keypoints = keypoints.Keypoints }
		end
		-- [[ColorSequence.new(color) vs ColorSequence.new(keypointArray).]]
		if type(keypoints) == "table" and keypoints.Time == nil and keypoints.R ~= nil then
			return {
				Keypoints = {
					ColorSequenceKeypoint.new(0, keypoints),
					ColorSequenceKeypoint.new(1, keypoints),
				},
			}
		end
		return { Keypoints = type(keypoints) == "table" and keypoints or {} }
	end,
}

NumberSequenceKeypoint = { new = function(time, value) return { Time = time, Value = value } end }
NumberSequence = { new = function(points) return { Keypoints = points or {} } end }

TweenInfo = {
	new = function(time, easingStyle, easingDirection, repeatCount, reverses, delayTime)
		return {
			Time = time,
			EasingStyle = easingStyle,
			EasingDirection = easingDirection,
			RepeatCount = repeatCount,
			Reverses = reverses,
			DelayTime = delayTime,
		}
	end,
}

Font = {
	fromEnum = function()
		return { Family = "rbxasset://fonts/families/BuilderSans.json", Weight = "Medium", Style = "Normal" }
	end,
	new = function(family, weight)
		return { Family = family, Weight = weight and weight.Name or "Medium", Style = "Normal" }
	end,
}

-- Memoized Enum so EnumItem identity is stable (== comparisons work).
local enumCategories = {}
Enum = setmetatable({}, {
	__index = function(_, category)
		local cat = enumCategories[category]
		if not cat then
			cat = setmetatable({}, {
				-- [[An Enum category is an Enum, not a table: typeof() below reads
				-- [[this marker so the library sees the engine's answer.]]
				__type = "Enum",
				__index = function(self, item)
					local entry = rawget(self, item)
					if not entry then
						entry = setmetatable({ Name = tostring(item), Category = tostring(category) }, {
							__type = "EnumItem",
						})
						rawset(self, item, entry)
					end
					return entry
				end,
			})
			enumCategories[category] = cat
		end
		return cat
	end,
})

-- [[The standalone Luau CLI has no Roblox datatypes, so teach typeof() about
-- [[the EnumItem marker the table above carries - the same answer the engine
-- [[gives, which is what the library's EnumItem checks expect.]]
local rawTypeof = typeof
function typeof(value)
	if type(value) == "table" then
		local mt = getmetatable(value)
		local marker = mt and rawget(mt, "__type")
		if marker == "EnumItem" or marker == "Enum" then
			return marker
		end
	end
	return rawTypeof(value)
end

-- ===== signals =====

local function newSignal()
	local connections = {}
	local firedOnce = false
	local waiters = {}
	local signal = {}

	local function makeConnection(fn)
	local connection = {
		_fn = fn,
		connected = true,
		Disconnect = function(self)
			self.connected = false
		end,
	}
	return connection
end

	function signal:Connect(fn)
		local connection = makeConnection(fn)
		table.insert(connections, connection)
		return connection
	end

	function signal:Once(fn)
		local connection
		connection = makeConnection(function(...)
			local inner = connection._fn
			connection._fn = nil
			inner(...)
		end)
		table.insert(connections, connection)
		return connection
	end

	function signal:Disconnect(connection)
		if type(connection) == "table" and connection.connected ~= nil then
			connection.connected = false
		end
	end

	function signal:Fire(...)
		firedOnce = true
		local snapshot = {}
		for i = 1, #connections do
			snapshot[i] = connections[i]
		end
		for _, connection in snapshot do
			if connection.connected and connection._fn then
				local ok, err = pcall(connection._fn, ...)
				if not ok then
					error(err, 0)
				end
			end
		end
		local pending = waiters
		table.clear(waiters)
		for _, co in pending do
			if coroutine.status(co) == "suspended" then
				coroutine.resume(co)
			end
		end
	end

	function signal:Wait()
		if firedOnce then
			return
		end
		table.insert(waiters, coroutine.running())
		coroutine.yield()
	end

	return signal
end

-- ===== instance model =====

local viewportSize = { X = 1920, Y = 1080 }

local HIERARCHY = {
	Instance = {},
	GuiObject = { "Instance" },
	ScreenGui = { "GuiObject" },
	Frame = { "GuiObject" },
	ScrollingFrame = { "Frame" },
	TextLabel = { "GuiObject" },
	TextButton = { "GuiObject" },
	ImageButton = { "TextButton" },
	ImageLabel = { "GuiObject" },
	TextBox = { "TextButton" },
	Folder = { "Instance" },
}

local SIGNAL_NAMES = {
	Changed = true,
	MouseButton1Click = true,
	MouseButton2Click = true,
	MouseButton1Down = true,
	MouseEnter = true,
	MouseLeave = true,
	InputBegan = true,
	InputEnded = true,
	Activated = true,
	FocusLost = true,
	Focused = true,
	Touched = true,
}

local function isAncestorOf(className, ancestor)
	local cursor = HIERARCHY[className]
	while cursor do
		if cursor[ancestor] then
			return true
		end
		cursor = HIERARCHY[cursor[1] or ""]
	end
	return false
end

local function isA(className, target)
	return className == target or isAncestorOf(className, target)
end

-- [[Engine property defaults. A real GuiObject answers every property it has,
-- [[assigned or not: a Frame's Position reads (0, 0, 0, 0) until a layout or a
-- [[tween moves it, its ZIndex reads 1, a TextLabel's Text reads "". The
-- [[library leans on that on instances it only ever places through a layout —
-- [[the topbar pill whose Position the strip scrolls past, the element bodies
-- [[whose AnchorPoint drives a centring tween — so unassigned members read
-- [[their engine default here instead of nil, which is what used to take
-- [[whole suites down with "attempt to index nil with 'X'" before any
-- [[assertion ran. Values are built lazily: the datatype tables above are
-- [[shared and a default must never be mutated by a test.]]
local propertyDefaults = {
	Instance = {
		Archivable = true,
	},
	GuiObject = {
		Active = true,
		AnchorPoint = function() return Vector2.new(0, 0) end,
		AutomaticSize = "None",
		BackgroundColor3 = function() return Color3.fromRGB(163, 162, 165) end,
		BackgroundTransparency = 0,
		BorderSizePixel = 1,
		ClipsDescendants = false,
		LayoutOrder = 0,
		Position = function() return UDim2.new(0, 0, 0, 0) end,
		Rotation = 0,
		Size = function() return UDim2.new(0, 0, 0, 0) end,
		Visible = true,
		ZIndex = 1,
	},
	ScreenGui = {
		DisplayOrder = 0,
		Enabled = true,
		IgnoreGuiInset = false,
		ResetOnSpawn = true,
	},
	Frame = {},
	TextLabel = {
		RichText = false,
		Text = "",
		TextColor3 = function() return Color3.fromRGB(0, 0, 0) end,
		TextScaled = false,
		TextSize = 8,
		TextTransparency = 0,
		TextWrapped = false,
		TextXAlignment = "Center",
		TextYAlignment = "Center",
	},
	TextButton = {
		AutoButtonColor = true,
	},
	TextBox = {
		ClearTextOnFocus = true,
		MultiLine = false,
		PlaceholderText = "",
		TextEditable = true,
	},
	ImageLabel = {
		Image = "",
		ImageColor3 = function() return Color3.fromRGB(255, 255, 255) end,
		ImageTransparency = 0,
		ScaleType = "Stretch",
	},
	ImageButton = {
		AutoButtonColor = true,
	},
	ScrollingFrame = {
		AutomaticCanvasSize = "None",
		CanvasPosition = function() return Vector2.new(0, 0) end,
		CanvasSize = function() return UDim2.new(0, 0, 0, 0) end,
		ElasticBehavior = "WhenScrollable",
		ScrollBarImageTransparency = 0,
		ScrollBarThickness = 12,
		ScrollingDirection = "XY",
	},
}

-- [[EnumItem-valued defaults are read from Enum so identity comparison works;
-- [[a raw string would not equal Enum.AutomaticSize.None under typeof/marker
-- [[rules. Keep the mapping tiny and explicit.]]
local enumDefaults = {
	AutomaticSize = { "AutomaticSize", "None" },
	ScrollingDirection = { "ScrollingDirection", "XY" },
	TextXAlignment = { "TextXAlignment", "Center" },
	TextYAlignment = { "TextYAlignment", "Center" },
	ScaleType = { "ScaleType", "Stretch" },
	AutomaticCanvasSize = { "AutomaticCanvasSize", "None" },
	ElasticBehavior = { "ElasticBehavior", "WhenScrollable" },
}

local function defaultValue(className, key)
	local cursor = className
	while cursor do
		local defaults = propertyDefaults[cursor]
		if defaults and defaults[key] ~= nil then
			local value = defaults[key]
			return if type(value) == "function" then value() else value
		end
		local hierarchy = HIERARCHY[cursor]
		cursor = hierarchy and (hierarchy[1] or "") or nil
		if cursor == "" then
			cursor = nil
		end
	end
	local mapping = enumDefaults[key]
	if mapping then
		return Enum[mapping[1]][mapping[2]]
	end
	return nil
end

local function absoluteSize(inst)
	if not inst then
		return { X = viewportSize.X, Y = viewportSize.Y }
	end
	local class = inst.__props and inst.__props.ClassName
	if class == "ScreenGui" or class == "CoreGui" then
		return { X = viewportSize.X, Y = viewportSize.Y }
	end
	local parent = inst.__props and inst.__props.Parent
	local parentSize = absoluteSize(parent)
	local size = (inst.__props and inst.__props.Size) or { X = udim(0, 0), Y = udim(0, 0) }
	return {
		X = size.X.Scale * parentSize.X + size.X.Offset,
		Y = size.Y.Scale * parentSize.Y + size.Y.Offset,
	}
end

local function absolutePosition(inst)
	if not inst then
		return { X = 0, Y = 0 }
	end
	local parent = inst.__props and inst.__props.Parent
	local parentPos = absolutePosition(parent)
	local parentSize = absoluteSize(parent)
	local pos = (inst.__props and inst.__props.Position) or { X = udim(0, 0), Y = udim(0, 0) }
	return {
		X = parentPos.X + pos.X.Scale * parentSize.X + pos.X.Offset,
		Y = parentPos.Y + pos.Y.Scale * parentSize.Y + pos.Y.Offset,
	}
end

local instanceMethods = {}

function instanceMethods:Destroy()
	if self.__destroyed then
		return
	end
	self.__destroyed = true
	local parent = self.__props.Parent
	if type(parent) == "table" and parent.__children then
		for i = #parent.__children, 1, -1 do
			if parent.__children[i] == self then
				table.remove(parent.__children, i)
				break
			end
		end
	end
	self.__props.Parent = nil
end

function instanceMethods:GetChildren()
	local result = {}
	for i = 1, #self.__children do
		result[i] = self.__children[i]
	end
	return result
end

function instanceMethods:GetDescendants()
	local result = {}
	local stack = { self }
	while #stack > 0 do
		local current = table.remove(stack)
		for _, child in current:GetChildren() do
			table.insert(result, child)
			table.insert(stack, child)
		end
	end
	return result
end

function instanceMethods:FindFirstChild(name)
	for _, child in self.__children do
		if child.__props.Name == name then
			return child
		end
	end
	return nil
end

function instanceMethods:IsA(className)
	return isA(self.__props.ClassName, className)
end

function instanceMethods:GetPropertyChangedSignal(propName)
	local cache = self.__propSignals
	if not cache[propName] then
		cache[propName] = newSignal()
	end
	return cache[propName]
end

-- [[TextBox focus is a no-op in the harness: the library only uses it to put
-- [[the caret in the search field, which has no visual state here.]]
function instanceMethods:CaptureFocus() end

function instanceMethods:ReleaseFocus() end

function instanceMethods:JumpTo(page)
	-- [[Emulates UIPageLayout: the page must be a visible sibling of the]]
	-- [[layout (a GuiObject child of the layout's parent). Anything else]]
	-- [[throws, like the real layout.]]
	local parent = self.Parent
	if parent == nil then
		return
	end
	local managed = false
	for _, child in parent:GetChildren() do
		if child == page and child.__props.Visible ~= false then
			managed = true
		end
	end
	if not managed then
		error(
			"UIPageLayout:JumpTo: page is not a visible sibling managed by the layout: " .. tostring(page and page.Name),
			0
		)
	end
	self.__currentPage = page
	self.__jumps = self.__jumps or {}
	table.insert(self.__jumps, page.Name or "?")
end

local function newInstance(className)
	local instance = {
		-- [[Roblox defaults a new instance's Name to its class name.]]
		__props = { ClassName = className, Name = className },
		__children = {},
		__signals = {},
		__propSignals = {},
		__destroyed = false,
	}
	if not instance.__signals.Changed then
		instance.__signals.Changed = newSignal()
	end

	local metatable = {
		__index = function(self, key)
			local props = rawget(self, "__props")
			if props[key] ~= nil then
				return props[key]
			end
			if instanceMethods[key] then
				return instanceMethods[key]
			end
			if key == "AbsoluteSize" then
				return absoluteSize(self)
			end
			-- [[ScrollingFrame-only members. The engine raises "X is not a]]
			-- [[valid member of Frame" when anything else is indexed for]]
			-- [[them; modelling that keeps a group body (a plain Frame) or]]
			-- [[any other non-scroll surface from silently reading like a]]
			-- [[scroll page in tests, which is how the dropdown's]]
			-- [[_bringIntoView crash reached a real session unnoticed.]]
			if key == "AbsoluteWindowSize" or key == "CanvasPosition" or key == "AbsoluteCanvasSize" then
				if props.ClassName ~= "ScrollingFrame" then
					error(key .. " is not a valid member of " .. tostring(props.ClassName), 2)
				end
				if key == "AbsoluteWindowSize" then
					return absoluteSize(self)
				end
				if key == "CanvasPosition" then
					-- [[The engine always answers a Vector2 here: a frame that
					-- [[has never been scrolled reads (0, 0), never nil. The
					-- [[topbar's fade logic compares against it before any
					-- [[scroll has happened, so nil used to take every suite
					-- [[down with "attempt to index nil with 'X'".]]
					local position = props.CanvasPosition
					return { X = position and position.X or 0, Y = position and position.Y or 0 }
				end
				-- [[AbsoluteCanvasSize follows CanvasSize, resolved against
				-- [[the viewport the same way the engine resolves a UDim2.
				-- [[CanvasSize is left untouched (the suites assert on it).]]
				local canvas = props.CanvasSize
				if canvas then
					local viewport = absoluteSize(self)
					return {
						X = canvas.X.Scale * viewport.X + canvas.X.Offset,
						Y = canvas.Y.Scale * viewport.Y + canvas.Y.Offset,
					}
				end
				return { X = 0, Y = 0 }
			end
			if key == "AbsolutePosition" then
				return absolutePosition(self)
			end
		if SIGNAL_NAMES[key] then
			local signals = rawget(self, "__signals")
			if not signals[key] then
				signals[key] = newSignal()
			end
			return signals[key]
		end
		-- [[Roblox semantics: instance.ChildName finds a child by Name.]]
		local children = rawget(self, "__children")
		if children then
			for i = 1, #children do
				local child = children[i]
				local childProps = rawget(child, "__props")
				if childProps and childProps.Name == key then
					return child
				end
			end
		end
		-- [[Nothing assigned: answer the engine's default for the member (see
		-- [[propertyDefaults above) instead of nil.]]
		return defaultValue(props.ClassName, key)
	end,
		__newindex = function(self, key, value)
			if rawget(self, "__destroyed") then
				error("The property '" .. tostring(key) .. "' cannot be assigned to because the instance has been destroyed.", 2)
			end
			local props = rawget(self, "__props")
			if key == "Parent" then
				local oldParent = props.Parent
				if type(oldParent) == "table" and oldParent.__children then
					for i = #oldParent.__children, 1, -1 do
						if oldParent.__children[i] == self then
							table.remove(oldParent.__children, i)
							break
						end
					end
				end
				props.Parent = value
				if type(value) == "table" and value.__children then
					table.insert(value.__children, self)
				end
			else
				props[key] = value
			end
			local signals = rawget(self, "__signals")
			if signals.Changed then
				signals.Changed:Fire(key)
			end
			local propSignal = rawget(self, "__propSignals")[key]
			if propSignal then
				propSignal:Fire()
			end
		end,
		__tostring = function(self)
			return self.__props.ClassName .. "." .. tostring(self.__props.Name)
		end,
	}
	return setmetatable(instance, metatable)
end

Instance = {
	new = function(className)
		return newInstance(tostring(className))
	end,
}

-- ===== services =====

local guidCounter = 0

local services = {}

services.TweenService = {
	Create = function(_, target, _, props)
		local done = false
		local completed = newSignal()
		return {
			Completed = completed,
			Play = function()
				if done then
					return
				end
				done = true
				for key, value in props do
					local ok, err = pcall(function()
						target[key] = value
					end)
					if not ok then
						error(err, 0)
					end
				end
				completed:Fire()
			end,
			Cancel = function()
				done = true
			end,
			Wait = function()
				completed:Wait()
			end,
		}
	end,
}

do
	local run = {
		IsStudio = function()
			return false
		end,
	}
	run.Heartbeat = newSignal()
	run.RenderStepped = newSignal()
	run.Stepped = newSignal()
	run.BindToClose = newSignal()
	services.RunService = run
end

do
	local input = {
		TouchEnabled = false,
		KeyboardEnabled = true,
		MouseBehavior = "Default",
		MouseIconEnabled = true,
		_propSignals = {},
	}
	input.InputBegan = newSignal()
	input.InputEnded = newSignal()
	input.WindowFocusReleased = newSignal()
	input.GetMouseLocation = function()
		return { X = viewportSize.X / 2, Y = viewportSize.Y / 2 }
	end
	input.IsMouseButtonPressed = function()
		return false
	end
	input.GetPropertyChangedSignal = function(_, key)
		if not input._propSignals[key] then
			input._propSignals[key] = newSignal()
		end
		return input._propSignals[key]
	end
	services.UserInputService = input
end

services.GuiService = {
	GetGuiInset = function()
		return { X = 0, Y = 0, Z = 0, W = 0 }
	end,
}

services.HttpService = {
	GenerateGUID = function()
		guidCounter += 1
		return "GUID-" .. guidCounter
	end,
	JSONEncode = function(_, value)
		local function encode(v, depth)
			if depth > 8 then
				error("too deep")
			end
			local tv = type(v)
			if tv == "string" then
				return string.format(
					"%q",
					v:gsub([[\n]], "\\n"):gsub([[\t]], "\\t")
				)
			elseif tv == "number" or tv == "boolean" then
				return tostring(v)
			elseif tv == "table" then
				if v.Name and v.Category then
					return string.format("%q", v.Name)
				end
				local isArray = true
				local count = 0
				for k in v do
					count += 1
					if type(k) ~= "number" then
						isArray = false
						break
					end
				end
				local parts = {}
				if isArray then
					for i = 1, count do
						parts[i] = encode(v[i], depth + 1)
					end
					return "[" .. table.concat(parts, ",") .. "]"
				else
					for k, val in v do
						table.insert(parts, string.format("%q:%s", tostring(k), encode(val, depth + 1)))
					end
					return "{" .. table.concat(parts, ",") .. "}"
				end
			end
			error("unsupported json value: " .. tv)
		end
		return encode(value, 0)
	end,
	JSONDecode = function(_, text)
		local pos = 1

		local function skipSpace()
			while pos <= #text do
				local c = text:sub(pos, pos)
				if c == " " or c == "\t" or c == "\n" or c == "\r" then
					pos += 1
				else
					break
				end
			end
		end

		local parseValue

		local function parseString()
			assert(text:sub(pos, pos) == '"')
			pos += 1
			local out = {}
			while pos <= #text do
				local c = text:sub(pos, pos)
				if c == '"' then
					pos += 1
					return table.concat(out)
				elseif c == "\\" then
					local esc = text:sub(pos + 1, pos + 1)
					local map = { n = "\n", t = "\t", r = "\r", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
					table.insert(out, map[esc] or esc)
					pos += 2
				else
					table.insert(out, c)
					pos += 1
				end
			end
			error("unterminated string")
		end

		local function parseNumber()
			local start = pos
			while pos <= #text and text:sub(pos, pos):match("[%d%-%+.eE]") do
				pos += 1
			end
			return tonumber(text:sub(start, pos - 1))
		end

		local function parseObject()
			pos += 1
			skipSpace()
			local out = {}
			if text:sub(pos, pos) == "}" then
				pos += 1
				return out
			end
			while true do
				skipSpace()
				local key = parseString()
				skipSpace()
				assert(text:sub(pos, pos) == ":")
				pos += 1
				skipSpace()
				out[key] = parseValue()
				skipSpace()
				local c = text:sub(pos, pos)
				if c == "," then
					pos += 1
				elseif c == "}" then
					pos += 1
					return out
				else
					error("expected , or } at " .. pos)
				end
			end
		end

		local function parseArray()
			pos += 1
			skipSpace()
			local out = {}
			if text:sub(pos, pos) == "]" then
				pos += 1
				return out
			end
			while true do
				skipSpace()
				table.insert(out, parseValue())
				skipSpace()
				local c = text:sub(pos, pos)
				if c == "," then
					pos += 1
				elseif c == "]" then
					pos += 1
					return out
				else
					error("expected , or ] at " .. pos)
				end
			end
		end

		parseValue = function()
			skipSpace()
			local c = text:sub(pos, pos)
			if c == "{" then
				return parseObject()
			elseif c == "[" then
				return parseArray()
			elseif c == '"' then
				return parseString()
			elseif c == "t" and text:sub(pos, pos + 3) == "true" then
				pos += 4
				return true
			elseif c == "f" and text:sub(pos, pos + 4) == "false" then
				pos += 5
				return false
			elseif c == "n" and text:sub(pos, pos + 3) == "null" then
				pos += 4
				return nil
			else
				return parseNumber()
			end
		end

		local result = parseValue()
		return result
	end,
}

services.TextService = {
	-- [[Deterministic metrics: 0.6 * size per character. The test computes]]
	-- [[its expected widths from this same formula.]]
	GetTextBoundsAsync = function(_, params)
		local text = tostring(params.Text or "")
		local size = params.Size or 16
		local width = math.ceil(#text * size * 0.6)
		local limit = params.Width or math.huge
		local lines = 1
		if limit > 0 and width > limit then
			lines = math.ceil(width / limit)
		end
		return { X = width, Y = size * 1.2 * lines }
	end,
}

local camera = {
	ViewportSize = { X = viewportSize.X, Y = viewportSize.Y },
	_propSignals = {},
}
camera.GetPropertyChangedSignal = function(_, key)
	if not camera._propSignals[key] then
		camera._propSignals[key] = newSignal()
	end
	return camera._propSignals[key]
end

services.Workspace = {
	CurrentCamera = camera,
	_propSignals = {},
}
services.Workspace.GetPropertyChangedSignal = function(_, key)
	if not services.Workspace._propSignals[key] then
		services.Workspace._propSignals[key] = newSignal()
	end
	return services.Workspace._propSignals[key]
end

local localPlayer = {
	Name = "TestUser",
	UserId = 42,
	DisplayName = "TestUser",
	-- [[Membership: the profile card's premium pill reads this. Premium by
	-- [[default so the pill's layout is testable; tests set it to None to
	-- [[check it disappears again.]]
	MembershipType = Enum.MembershipType.Premium,
	PlayerGui = newInstance("ScreenGui"),
}

services.Players = {
	LocalPlayer = localPlayer,
	-- [[Player capacity/roster: the profile card reads these for its SERVER
	-- [[section. Tests overwrite them to exercise the "no data" placeholders.]]
	MaxPlayers = 50,
	GetPlayers = function()
		return { localPlayer }
	end,
}

services.LocalizationService = {}
services.ReplicatedStorage = newInstance("Folder")
services.CoreGui = newInstance("CoreGui")

game = {
	GetService = function(_, name)
		return services[name]
	end,
}

-- ===== virtual-time task scheduler (the Luau CLI has no `task` library) =====

local virtualNow = 0.0
local mainThread = coroutine.running()
local scheduleQueue = {}
local scheduleOrder = 0

local function enqueue(time, entry)
	scheduleOrder += 1
	entry.time = time
	entry.order = scheduleOrder
	entry.done = false
	entry.origin = debug.traceback("", 2)
	table.insert(scheduleQueue, entry)
end

local function pumpQueue(target)
	local iterations = 0
	while true do
		iterations += 1
		if iterations > 20000 then
			local histogram = {}
			local pendingCount = 0
			for _, entry in scheduleQueue do
				if not entry.done then
					pendingCount += 1
					local firstLine = string.match(tostring(entry.origin), "[^\n]+") or "?"
					histogram[firstLine] = (histogram[firstLine] or 0) + 1
				end
			end
			local parts = {}
			for line, count in histogram do
				table.insert(parts, count .. " x " .. line)
			end
			table.sort(parts, function(a, b)
				return a > b
			end)
			error(
				"harness: pumpQueue exceeded its iteration budget (infinite rescheduling?)\npending="
					.. pendingCount
					.. " virtualNow="
					.. tostring(virtualNow)
					.. " target="
					.. tostring(target)
					.. "\n"
					.. table.concat(parts, "\n"),
				0
			)
		end
		local best = nil
		for _, entry in scheduleQueue do
			if not entry.done and entry.time <= target then
				if not best then
					best = entry
				else
					local b = best :: any
					local e = entry :: any
					if e.time < b.time or (e.time == b.time and e.order < b.order) then
						best = entry
					end
				end
			end
		end
		if not best then
			return
		end
		if best.time > virtualNow then
			virtualNow = best.time
		end
		best.done = true
		if best.co then
			if coroutine.status(best.co) == "suspended" then
				local ok, err = coroutine.resume(best.co)
				if not ok then
					error(err, 0)
				end
			end
		elseif best.fn then
			best.fn(table.unpack(best.args, 1, best.args.n))
		end
	end
end

task = {}

function task.spawn(fn, ...)
	local args = table.pack(...)
	enqueue(virtualNow, { co = coroutine.create(function()
		fn(table.unpack(args, 1, args.n))
	end) })
end

function task.defer(fn, ...)
	task.spawn(fn, ...)
end

function task.delay(seconds, fn, ...)
	local args = table.pack(...)
	enqueue(virtualNow + (seconds or 0), { fn = fn, args = args })
end

local FRAME_DT = 0.05

function task.wait(seconds)
	local co = coroutine.running()
	if co == mainThread then
		-- [[The CLI main thread cannot yield; the test body never waits,]]
		-- [[so treat a stray wait as a no-op pump of due work.]]
		pumpQueue(virtualNow)
		return FRAME_DT
	end
	-- [[Roblox: task.wait() with no argument yields for one frame and]]
	-- [[returns the frame's elapsed time; task.wait(t) yields for t.]]
	local wakeAt
	if seconds == nil then
		-- [[Tolerance: floating-point drift must not make the "next frame"]]
		-- [[boundary collapse onto the current time (infinite requeue).]]
		wakeAt = (math.floor(virtualNow / FRAME_DT + 1e-9) + 1) * FRAME_DT
	else
		wakeAt = virtualNow + seconds
	end
	local waitedFrom = virtualNow
	enqueue(wakeAt, { co = co, wakeAt = wakeAt, waitedFrom = waitedFrom })
	coroutine.yield()
	return virtualNow - waitedFrom
end

-- ===== test helpers (exposed to the test body) =====

TestViewport = {
	set = function(w, h)
		viewportSize.X = w
		viewportSize.Y = h
		camera.ViewportSize = { X = w, Y = h }
		camera._propSignals.ViewportSize:Fire()
	end,
	get = function()
		return { X = viewportSize.X, Y = viewportSize.Y }
	end,
}

TestPump = function(seconds)
	local target = virtualNow + (seconds or 0)
	local steps = math.ceil((seconds or 0) / FRAME_DT)
	for _ = 1, steps do
		virtualNow += FRAME_DT
		services.RunService.Heartbeat:Fire(FRAME_DT)
		services.RunService.RenderStepped:Fire(FRAME_DT)
		pumpQueue(target)
	end
end
