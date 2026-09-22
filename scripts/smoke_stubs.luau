
local function makeProxy(name)
	local proxy
	proxy = setmetatable({}, {
		__index = function(_, key)
			if key == "Name" then
				return name
			end
			return function(...)
				return makeProxy(name .. "." .. tostring(key))
			end
		end,
		__tostring = function()
			return name
		end
	})
	return proxy
end

local servicesByName = {}
local function getService(name)
	if servicesByName[name] == nil then
		servicesByName[name] = makeProxy("ServiceProvider." .. name)
	end
	return servicesByName[name]
end

servicesByName["Players"] = setmetatable({}, {
	__index = function(_, key)
		if key == "LocalPlayer" then
			return makeProxy("Player.LocalPlayer")
		end
		return function(...)
			return makeProxy("Players." .. tostring(key))
		end
	end
})

game = setmetatable({}, {
	__index = function(_, key)
		if key == "GetService" then
			return function(_, name)
				return getService(name)
			end
		end
		return makeProxy("game." .. tostring(key))
	end
})

local runService = setmetatable({}, {
	__index = function(_, key)
		if key == "IsStudio" then
			return function()
				return false
			end
		end
		return function(...)
			return makeProxy("RunService." .. tostring(key))
		end
	end
})
servicesByName["RunService"] = runService

--[[
`UserInputType` and `MembershipType` answer the way the engine does: a
member they do not know is an error, not a proxy. Modules name their members
while they load, so one invented member kills the require and every window
built after it - the `Pen` and `Free` members that shipped here have never
existed, and a permissive stub turned both crashes into a green test run.
]]
local strictEnumMembers = {
	UserInputType = {
		MouseButton1 = true, MouseButton2 = true, MouseButton3 = true, MouseWheel = true,
		MouseMovement = true, Touch = true, Keyboard = true, Focus = true,
		Accelerometer = true, Gyro = true, Gamepad1 = true, Gamepad2 = true,
		Gamepad3 = true, Gamepad4 = true, Gamepad5 = true, Gamepad6 = true,
		Gamepad7 = true, Gamepad8 = true, TextInput = true, InputMethod = true,
		None = true,
	},
	MembershipType = {
		None = true, BuildersClub = true, TurboBuildersClub = true,
		OutrageousBuildersClub = true, Premium = true,
	},
}
local enumMethods = { FromValue = true, GetEnumItems = true }

Enum = setmetatable({}, {
	__index = function(_, category)
		local known = strictEnumMembers[category]
		return setmetatable({}, {
			__index = function(_, item)
				if known and not enumMethods[item] and not known[item] then
					error(tostring(item) .. ' is not a valid member of "Enum.' .. tostring(category) .. '"', 2)
				end
				return makeProxy("EnumItem")
			end
		})
	end
})

local function fontFrom(family, weight)
	return { Family = family, Weight = weight }
end

Font = {
	fromEnum = function()
		return fontFrom("rbxasset://fonts/families/BuilderSans.json")
	end,
	new = function(family, weight)
		return fontFrom(family, weight)
	end,
}

local function color3(r, g, b)
	return {
		R = r / 255,
		G = g / 255,
		B = b / 255,
		Lerp = function(self, other, alpha)
			return color3(
				(self.R + (other.R - self.R) * alpha) * 255,
				(self.G + (other.G - self.G) * alpha) * 255,
				(self.B + (other.B - self.B) * alpha) * 255
			)
		end,
	}
end

Color3 = {
	fromRGB = function(r, g, b)
		return color3(r, g, b)
	end,
	new = function(r, g, b)
		return color3(r * 255, g * 255, b * 255)
	end,
}

ColorSequenceKeypoint = {
	new = function(time, value)
		return { Time = time, Value = value }
	end,
}

ColorSequence = {
	new = function(keypoints)
		return { Keypoints = keypoints }
	end,
}

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

local function udim(scale, offset)
	return { Scale = scale or 0, Offset = offset or 0 }
end

UDim = {
	new = udim,
}

UDim2 = {
	new = function(xs, xo, ys, yo)
		return { X = udim(xs, xo), Y = udim(ys, yo) }
	end,
	fromScale = function(xs, ys)
		return { X = udim(xs, 0), Y = udim(ys, 0) }
	end,
	fromOffset = function(xo, yo)
		return { X = udim(0, xo), Y = udim(0, yo) }
	end,
}

Vector2 = {
	new = function(x, y)
		return { X = x or 0, Y = y or 0 }
	end,
}

NumberSequenceKeypoint = {
	new = function(time, value)
		return { Time = time, Value = value }
	end,
}

NumberSequence = {
	new = function(points)
		return { Keypoints = points }
	end,
}

