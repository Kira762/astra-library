-- ===== motion service assertions: shared specs, time scale, profiles, =====
-- ===== tween ownership, and the window's Animation speed setting      =====
-- [[Runs the real Astra bundle (loaded as global `Astra` above) against the]]
-- [[mini Roblox environment from sidebar_sizing_stubs.luau.]]
--
-- Expected behavior under test:
--   * M1 the service is public (Astra.Motion) and its vocabulary covers the
--        specs the window actually asks for,
--   * M2 named specs are shared values, not rebuilt per call,
--   * M3 the time scale rescales every spec and is dropped from the cache
--        when it changes, so the next lookup returns the new duration,
--   * M4 profiles drive the library's speed, unknown profile names are
--        rejected instead of half-applying, and "instant" switches animation
--        off,
--   * M5 two tweens that would fight over the same property never both run:
--        the newer call cancels the older one, while tweens on unrelated
--        properties are left alone,
--   * M6 a property already at its target is never animated, and a call whose
--        properties are all satisfied creates no tween at all,
--   * M7 with animation off the targets are applied immediately and no tween
--        is created,
--   * M8 the window's "Animation speed" setting reaches the service (both
--        when it is applied and when a bad value has to fall back),
--   * M9 element hover is wired through the service: a hover animates, a
--        rapid leave cancels the enter tween on the same property, and with
--        animation off a hover creates nothing,
--   * M10 the cascade step scales with the profile and collapses to zero
--        when animation is off,
--   * M11 with animation off the window's show/hide/restore/close still settle
--        their state machines: no tween is created, so `animating`/`hidden`
--        must be resolved on the spot instead of waiting for a completion
--        that will never fire.

local function expect(cond, message)
	if not cond then
		error("MOTION FAIL: " .. tostring(message), 0)
	end
end

local function eq(actual, wanted, message)
	if actual ~= wanted then
		error(
			"MOTION FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")",
			0
		)
	end
end

local function near(actual, wanted, message)
	if type(actual) ~= "number" or math.abs(actual - wanted) > 1e-6 then
		error(
			"MOTION FAIL: " .. message .. " (got " .. tostring(actual) .. ", want " .. tostring(wanted) .. ")",
			0
		)
	end
end

local state = Astra.Core.state
local motion = Astra.Motion

-- ===== M1: public surface and vocabulary =====

expect(type(motion) == "table", "M1 Astra.Motion is exposed")
expect(type(motion.tween) == "function", "M1 motion.tween is callable")
expect(type(motion.spec) == "function", "M1 motion.spec is callable")
expect(type(motion.setProfile) == "function", "M1 motion.setProfile is callable")

local specNames = {}
for _, name in motion.specNames do
	specNames[name] = true
end
for _, name in { "instant", "fast", "snappy", "normal", "smooth", "emphasized", "pop", "glide", "exit", "spring", "settle", "spin", "drift" } do
	expect(specNames[name] == true, "M1 spec '" .. name .. "' is registered")
	-- [[Checked structurally: the test stubs model TweenInfo as a plain table,
	-- so `typeof(...) == "TweenInfo"` would only hold in a real client.]]
	local resolved = motion.spec(name)
	expect(type(resolved) == "table" and type(resolved.Time) == "number", "M1 spec '" .. name .. "' resolves to a TweenInfo")
	expect(resolved.EasingStyle ~= nil and resolved.EasingDirection ~= nil, "M1 spec '" .. name .. "' carries easing")
end

-- ===== M2: named specs are shared =====

motion.setProfile("normal")

local snappy = motion.spec("snappy")
expect(snappy == motion.spec("snappy"), "M2 the same spec name returns the same shared TweenInfo")
eq(snappy.Time, 0.25, "M2 the snappy spec keeps its 0.25s duration")
eq(snappy.EasingStyle, Enum.EasingStyle.Quint, "M2 the snappy spec keeps Quint easing")
eq(snappy.EasingDirection, Enum.EasingDirection.Out, "M2 the snappy spec keeps Out direction")
eq(motion.spec().Time, motion.spec("normal").Time, "M2 a missing spec falls back to normal")
eq(motion.spec("not-a-spec").Time, motion.spec("normal").Time, "M2 an unknown spec falls back to normal")
eq(motion.spec("pop").EasingStyle, Enum.EasingStyle.Back, "M2 the window entrance spec overshoots (Back)")
eq(motion.spec("settle").EasingStyle, Enum.EasingStyle.Back, "M2 the small-surface spec overshoots too (Back)")
eq(motion.spec("glide").EasingDirection, Enum.EasingDirection.InOut, "M2 lateral state moves ease InOut")
eq(motion.spec("exit").EasingDirection, Enum.EasingDirection.In, "M2 dismissals accelerate out (In direction)")
expect(motion.spec("exit").Time < motion.spec("emphasized").Time, "M2 a dismissal is quicker than a hero entrance")

-- ===== M3: the time scale rescales specs =====

motion.setTimeScale(2)
near(motion.spec("snappy").Time, 0.5, "M3 a 2x time scale doubles the spec duration")
near(motion.spec(snappy).Time, 0.5, "M3 a TweenInfo input is scaled too")
motion.setTimeScale(1)
near(motion.spec("snappy").Time, 0.25, "M3 returning to 1x restores the original duration")
expect(motion.spec("snappy") == snappy, "M3 at 1x the shared spec is handed back again")

-- ===== M4: profiles =====

eq(motion.setProfile("nope"), false, "M4 an unknown profile is rejected")
eq(motion.getProfile(), "normal", "M4 a rejected profile leaves the active one alone")

eq(motion.setProfile("relaxed"), true, "M4 relaxed applies")
near(motion.getTimeScale(), 1.35, "M4 relaxed slows the library down")
near(motion.spec("normal").Time, 0.54, "M4 relaxed stretches a normal spec")

eq(motion.setProfile("snappy"), true, "M4 snappy applies")
near(motion.spec("normal").Time, 0.28, "M4 snappy shortens a normal spec")

eq(motion.setProfile("instant"), true, "M4 instant applies")
eq(motion.isEnabled(), false, "M4 instant switches animation off")
eq(motion.getTimeScale(), 0, "M4 instant parks the time scale at zero")
eq(motion.step(0.035), 0, "M10 a cascade step is zero while animation is off")

eq(motion.setProfile("normal"), true, "M4 back to normal")
eq(motion.isEnabled(), true, "M4 normal restores animation")
near(motion.step(0.035), 0.035, "M10 the cascade step is unchanged at 1x")
motion.setProfile("relaxed")
near(motion.step(0.035), 0.04725, "M10 the cascade step stretches with a relaxed profile")
motion.setProfile("snappy")
near(motion.step(0.035), 0.0245, "M10 the cascade step shortens with a snappy profile")

-- ===== tween accounting =====
--
-- The stub TweenService applies its properties on Play, so every assertion
-- below can read the target instance directly; the wrapper counts what the
-- service asked for and how many tweens were cancelled.

local tweenService = state.tweenService
local created = 0
local cancelled = 0
local originalCreate = tweenService.Create
tweenService.Create = function(self, target, info, props)
	created += 1
	local tween = originalCreate(self, target, info, props)
	local originalCancel = tween.Cancel
	tween.Cancel = function(...)
		cancelled += 1
		return originalCancel(...)
	end
	return tween
end

-- ===== M5/M6/M7: ownership, no-op calls, animation off =====

motion.setProfile("normal")

local frame = Instance.new("Frame")
frame.BackgroundTransparency = 1

eq(motion.tween(frame, { BackgroundTransparency = 1 }, "normal"), nil,
	"M6 an already-satisfied target creates no tween")
eq(created, 0, "M6 ... and nothing reaches TweenService")

motion.tween(frame, { BackgroundTransparency = 0.5 }, "normal")
eq(created, 1, "M5 the first tween is created")
eq(frame.BackgroundTransparency, 0.5, "M5 the tween's target is applied")

motion.tween(frame, { BackgroundTransparency = 0.25 }, "normal")
eq(created, 2, "M5 a second tween on the same property is created")
eq(cancelled, 1, "M5 ... and it cancels the tween it would fight with")

motion.tween(frame, { Position = UDim2.fromOffset(40, 40) }, "normal")
eq(cancelled, 1, "M5 a tween on an unrelated property leaves the first one alone")

-- [[Half-satisfied calls still animate the properties that need it.]]
local sizeFrame = Instance.new("Frame")
sizeFrame.BackgroundTransparency = 0.5
local beforePartial = created
motion.tween(sizeFrame, { BackgroundTransparency = 0.5, Rotation = 15 }, "normal")
eq(created, beforePartial + 1, "M6 a partially-satisfied call still animates the pending property")
eq(sizeFrame.Rotation, 15, "M6 ... and applies only that property's target")

-- [[motion.cancel stops the tracked tween and forgets it.]]
eq(motion.cancel(frame), true, "M5motion.cancel stops the tracked tween")
eq(motion.cancel(frame), false, "M5 ... and the slot is cleared")

motion.setProfile("instant")
local beforeInstant = created
local instantFrame = Instance.new("Frame")
instantFrame.BackgroundTransparency = 1
eq(motion.tween(instantFrame, { BackgroundTransparency = 0.2 }, "normal"), nil,
	"M7 with animation off no tween is returned")
eq(created, beforeInstant, "M7 ... and none is created")
eq(instantFrame.BackgroundTransparency, 0.2, "M7 the target is applied immediately")
motion.setProfile("normal")

-- ===== M8: the window's Animation speed setting =====

local window = Astra:CreateWindow({ name = "Motion Test" })
TestPump(1.2)

window.settings.motionSpeed = "relaxed"
window:_applyMotionSetting()
eq(motion.getProfile(), "relaxed", "M8 the window setting reaches the motion service")

window.settings.motionSpeed = "not-a-profile"
window:_applyMotionSetting()
eq(motion.getProfile(), "normal", "M8 a bad value falls back to normal")
eq(window.settings.motionSpeed, "normal", "M8 ... and the setting is corrected in place")

local manager = Astra.Settings.newManager()
eq(manager:set("motionSpeed", "snappy"), true, "M8 the settings manager accepts a known profile")
eq(manager:set("motionSpeed", "not-a-profile"), false, "M8 the settings manager rejects an unknown profile")

-- ===== M9: element hover runs through the service =====

local tab = window:CreateTab({ name = "Motion" })
local button = tab:CreateButton({ name = "Test", callback = function() end })
TestPump(0.2)

motion.setProfile("normal")
created, cancelled = 0, 0
button.main.MouseEnter:Fire()
expect(created > 0, "M9 a hover animates through the motion service")
local beforeLeave = cancelled
button.main.MouseLeave:Fire()
expect(cancelled > beforeLeave, "M9 a hover leave cancels the enter tween on the same property")

motion.setProfile("instant")
created = 0
button.main.MouseEnter:Fire()
eq(created, 0, "M9 with animation off a hover creates no tween")

motion.setProfile("normal")
window:Unload()
TestPump(0.1)

-- ===== M11: the no-tween settle paths (animation off) =====

local instantWindow = Astra:CreateWindow({ name = "Motion Instant" })
instantWindow.settings.motionSpeed = "instant"
instantWindow:_applyMotionSetting()
TestPump(1.2)

eq(instantWindow.main.Visible, true, "M11 the window is up with animation off")
eq(instantWindow.animating, false, "M11 the first show settles without waiting for a tween")
eq(instantWindow.hidden, false, "M11 ... and the window is not left hidden")

instantWindow:Hide()
TestPump(0.2)
eq(instantWindow.hidden, true, "M11 hide marks the window hidden")
eq(instantWindow.animating, false, "M11 ... and settles immediately with no tween to wait for")

instantWindow:Show()
TestPump(0.2)
eq(instantWindow.hidden, false, "M11 show restores the window")
eq(instantWindow.animating, false, "M11 ... and settles immediately too")

instantWindow:Close()
TestPump(0.2)
eq(instantWindow.unloaded, true, "M11 close tears the window down with animation off")

motion.setProfile("normal")
tweenService.Create = originalCreate

print("MOTION: all assertions passed")
