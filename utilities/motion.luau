--[[
Astra motion service.

Every animation in the library used to build its own TweenInfo and call
TweenService:Create directly. That has three costs:

  1. TweenInfo values are re-created per call, including in hot paths such
     as element hover, where the same 0.25s Quint/Out spec is allocated on
     every pointer enter and leave.
  2. Nothing tracks the tween a component already started on an instance,
     so a fast hover in/out leaves two tweens interpolating the same
     property. The newer one wins per frame, which is wasted work and the
     usual source of "the stroke flickers" jitter.
  3. Hosts had no way to slow the interface down or switch animation off
     for accessibility or low-end devices.

This module is the one place that answers all three: named specs are
created once, `motion.tween` cancels an in-flight tween when it would fight
over the same property, and everything animated through it answers to a
single time scale (`motion.setProfile`). Sites that still call
`TweenService:Create` directly (component-local flourishes such as the
notification queue) keep their own timing until they are moved over.

Behaviour contract, deliberately conservative:
  * `motion.tween` is a drop-in for `TweenService:Create(instance, info,
    props):Play()` — same target values, same easing, and the spec's own
    duration at the `normal` profile (the active time scale rescales it).
  * Properties already equal to their target are dropped from the tween; a
    call whose properties all match does not create a tween at all (this is
    the same "skip unchanged" rule the window's reveal path already used).
  * With motion disabled, or the time scale at zero, the target properties
    are assigned directly and no tween is created. Cancelling the previous
    tween first keeps a disabled interface from being overwritten by an
    animation that was already running.
]]
local coreState = require(script.Parent.Parent.core.state)

local motion = {}

export type MotionSpec = string | TweenInfo

--[[
Named specs: the library's motion vocabulary. Each one is a fixed,
shared TweenInfo, so a site that animates at 0.25s Quint/Out no longer
allocates a new TweenInfo every time it runs. Names are stable API: a host
can use them through `Astra.Motion.tween` to match the window's timing.

The vocabulary follows one system, so unrelated components still read as
the same interface:
  * entrances decelerate (Out) — things arrive fast and settle gently;
  * exits accelerate (In) — things leaving should not linger;
  * lateral state moves ease InOut — a bar that slides between states
    reads as deliberate, not reactive;
  * playful surfaces (the window shell, the capsule, oversized feedback)
    get a small Back overshoot; everything else stays honest.
Durations step up with the size of what moves: 0.16 for a press, 0.25 for
hover, 0.4 for an element, 0.5–0.6 for surfaces, 0.55 for the shell.
]]
local SPECS: { [string]: TweenInfo } = {
	--[[
	One frame's worth of movement: the "no animation" target for hosts
	that want the tween-completed path without a visible transition.
	]]
	instant = TweenInfo.new(0.01, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),

	-- Press/lift feedback: the shortest readable transition.
	fast = TweenInfo.new(0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),

	-- Hover feedback and dropdown rows: the most-used spec in the library.
	snappy = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),

	-- Element reveal: what `Window:_reveal` plays when an element appears.
	normal = TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),

	-- Surface moves: window open/restore, panel reveal.
	smooth = TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),

	-- The window's own entrance and other hero transitions.
	emphasized = TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),

	--[[
	Window entrance scale and corner. Long enough to read as a deliberate
	load transition, with a small overshoot so the shell settles softly.
	]]
	pop = TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out),

	--[[
	Lateral state moves: the window folding into its capsule and back,
	a bar sliding between resting places. InOut because the surface is
	neither arriving nor leaving — it is moving house.
	]]
	glide = TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut),

	--[[
	Dismissals: quicker than the entrances that created them, and
	accelerating (In) so a card that is leaving gains pace instead of
	lingering at the end of its curve.
	]]
	exit = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In),

	-- Overshoot for drag/pop feedback (the capsule settling back).
	spring = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),

	--[[
	Short overshoot for small surfaces: the collapsed capsule appearing,
	a pill landing back after a press. Same family as `spring`, scaled
	down so small elements never read bouncy.
	]]
	settle = TweenInfo.new(0.34, Enum.EasingStyle.Back, Enum.EasingDirection.Out),

	-- Tab selection gradient spin.
	spin = TweenInfo.new(0.7, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),

	-- The slow ambient drift of a theme's LiveAnimation gradient.
	drift = TweenInfo.new(10, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),

	--[[
	Modern canvas-inspired and UI-tailored aesthetic specs:
	Decelerating Circular & Cubic curves provide fluid physical weight and organic
	motion that elevates the UI aesthetic beyond mechanical linear/exponential ramps.
	]]
	canvasEntrance = TweenInfo.new(0.45, Enum.EasingStyle.Circular, Enum.EasingDirection.Out),
	canvasPop = TweenInfo.new(0.48, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	canvasCard = TweenInfo.new(0.36, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
	fluid = TweenInfo.new(0.38, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
	tabSwitch = TweenInfo.new(0.32, Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut),
	modal = TweenInfo.new(0.42, Enum.EasingStyle.Circular, Enum.EasingDirection.Out),
	control = TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	micro = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	dropdownOpen = TweenInfo.new(0.32, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
	dropdownClose = TweenInfo.new(0.22, Enum.EasingStyle.Cubic, Enum.EasingDirection.In),
	toast = TweenInfo.new(0.46, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
}

local DEFAULT_SPEC = "normal"

--[[
Profiles map named speeds onto the time scale. The library ships on
`snappy` — the normal motion language, played faster — deliberately not
`instant`, which is an explicit opt-out of animation rather than a
speed. `instant` remains the reduced-motion / lowest-cost option for
hosts that want it: nothing tweens, every target is applied on the spot.
]]
motion.profiles = {
	relaxed = { timeScale = 1.35 },
	normal = { timeScale = 1 },
	snappy = { timeScale = 0.7 },
	instant = { timeScale = 0, enabled = false },
}

--[[
The built-in default: normal, but faster — never instant. The old
"Animation speed" setting is gone, so this is what the interface plays;
hosts can still rescale everything through `motion.setProfile`.
]]
local DEFAULT_PROFILE = "snappy"

motion.specNames = {
	"instant",
	"fast",
	"snappy",
	"normal",
	"smooth",
	"emphasized",
	"pop",
	"glide",
	"exit",
	"spring",
	"settle",
	"spin",
	"drift",
	"canvasEntrance",
	"canvasPop",
	"canvasCard",
	"fluid",
	"tabSwitch",
	"modal",
	"control",
	"micro",
	"dropdownOpen",
	"dropdownClose",
	"toast",
}

motion.enabled = true
motion.profile = DEFAULT_PROFILE
motion.timeScale = (motion.profiles[DEFAULT_PROFILE] :: any).timeScale or 1

--[[
Scaled specs are cached per input (a name or a TweenInfo) and dropped
whenever the time scale changes, so the hot paths never allocate.
]]
local scaled: { [any]: TweenInfo } = setmetatable({}, { __mode = "k" })

--[[
The tween this service last started on an instance, with the property set
it targets. Weak keys: a destroyed instance must not be kept alive.
]]
local active: { [any]: { tween: Tween, props: { [string]: any } } } = setmetatable({}, { __mode = "k" })

local function scaleInfo(info: TweenInfo, timeScale: number): TweenInfo
	return TweenInfo.new(
		info.Time * timeScale,
		info.EasingStyle,
		info.EasingDirection,
		info.RepeatCount,
		info.Reverses,
		info.DelayTime
	)
end

--[[
A TweenInfo, recognised structurally rather than through
`typeof(x) == "TweenInfo"`: the library's own test stubs build TweenInfo
values as plain tables, and a spec passed in from a caller must survive
both environments instead of silently collapsing to the default.
]]
local function isInfo(value): boolean
	return type(value) == "table" and type(value.Time) == "number" and value.EasingStyle ~= nil
end

--[[
Resolves a spec (name or TweenInfo) to the TweenInfo that should be played
right now, applying the active time scale. At the default scale a named spec
returns the shared table itself, so the common path allocates nothing.
]]
function motion.spec(spec: MotionSpec?): TweenInfo
	local resolved = spec or DEFAULT_SPEC
	if type(resolved) == "string" then
		resolved = SPECS[resolved] or SPECS[DEFAULT_SPEC]
	elseif not isInfo(resolved) then
		resolved = SPECS[DEFAULT_SPEC]
	end

	if motion.timeScale == 1 then
		return resolved :: TweenInfo
	end

	local cached = scaled[resolved]
	if not cached then
		cached = scaleInfo(resolved :: TweenInfo, motion.timeScale)
		scaled[resolved] = cached
	end
	return cached
end

-- Drops the cached scaled specs. Called whenever the time scale changes.
local function invalidate()
	scaled = setmetatable({}, { __mode = "k" })
end

--[[
Seconds between cascade steps, scaled like everything else: a relaxed
profile reveals a page more slowly, `instant` reveals it in one go.
]]
function motion.step(base: number): number
	if not motion.enabled then
		return 0
	end
	return base * motion.timeScale
end

function motion.setTimeScale(scale: number): number
	local previous = motion.timeScale
	scale = math.max(0, math.min(4, scale or 1))
	if scale ~= previous then
		motion.timeScale = scale
		invalidate()
	end
	return previous
end

function motion.getTimeScale(): number
	return motion.timeScale
end

function motion.setEnabled(enabled: boolean): boolean
	local previous = motion.enabled
	motion.enabled = enabled ~= false
	return previous
end

function motion.isEnabled(): boolean
	return motion.enabled
end

--[[
Selects the most aesthetic, tailored animation spec based on the UI
component and its interaction context. Allows animations to depend on the UI.
]]
function motion.uiSpec(componentType: string?, action: string?): TweenInfo
	local comp = string.lower(tostring(componentType or ""))
	local act = string.lower(tostring(action or ""))

	if comp == "window" or comp == "shell" then
		if act == "close" or act == "exit" then
			return motion.spec("exit")
		elseif act == "collapse" or act == "fold" or act == "minimise" then
			return motion.spec("glide")
		end
		return motion.spec("pop")
	elseif comp == "popup" or comp == "modal" or comp == "dialog" then
		if act == "close" or act == "exit" then
			return motion.spec("dropdownClose")
		end
		return motion.spec("modal")
	elseif comp == "tab" or comp == "tabswitch" or comp == "nav" then
		return motion.spec("tabSwitch")
	elseif comp == "toggle" or comp == "switch" or comp == "knob" then
		return motion.spec("settle")
	elseif comp == "button" or comp == "click" or comp == "press" then
		if act == "press" or act == "tap" or act == "down" then
			return motion.spec("micro")
		end
		return motion.spec("fast")
	elseif comp == "dropdown" or comp == "menu" then
		if act == "close" or act == "collapse" then
			return motion.spec("dropdownClose")
		end
		return motion.spec("dropdownOpen")
	elseif comp == "notification" or comp == "toast" then
		if act == "dismiss" or act == "exit" then
			return motion.spec("exit")
		end
		return motion.spec("toast")
	elseif comp == "element" or comp == "card" or comp == "row" then
		if act == "hover" then
			return motion.spec("snappy")
		end
		return motion.spec("canvasCard")
	elseif comp == "tooltip" then
		return motion.spec("fast")
	end

	return motion.spec(action or componentType or DEFAULT_SPEC)
end

motion.forUI = motion.uiSpec

--[[
Applies a named profile. Unknown names are ignored (returns false) so a
stale persisted value can never leave the library in a half-configured
state.
]]
function motion.setProfile(name: string): boolean
	local profile = motion.profiles[name] :: { timeScale: number?, enabled: boolean? }?
	if not profile then
		return false
	end
	motion.setTimeScale(profile.timeScale or 1)
	motion.setEnabled(profile.enabled ~= false)
	motion.profile = name
	return true
end

function motion.getProfile(): string
	return motion.profile
end

--[[
Stops the tween this service started on the instance, if any. The slot is
cleared so a later call does not try to cancel it twice.
]]
function motion.cancel(instance: Instance?): boolean
	if not instance then
		return false
	end
	local entry = active[instance]
	if not entry then
		return false
	end
	active[instance] = nil
	local ok = pcall(function()
		entry.tween:Cancel()
	end)
	return ok
end

local function overlaps(entry, props): boolean
	for key in props do
		if entry.props[key] ~= nil then
			return true
		end
	end
	return false
end

local function assign(instance, props)
	for key, value in props do
		instance[key] = value
	end
end

--[[
Animate `props` on `instance` with `spec` (a spec name or TweenInfo).

Drops properties that already hold their target value, and skips the tween
entirely when nothing would change. When the new tween would animate a
property the instance is already animating through this service, the older
tween is cancelled first — one writer per property, which is what removes
the double-tween churn on rapid hover in/out.

`onCompleted`, when given, is connected *before* the tween is played, so a
caller that has to run a settle path cannot miss a completion that happens
on the same tick (which is exactly what a test stub's synchronous Play
does). Callers that need that path should treat a nil return as "the work
is already done" and run it themselves.

Returns the tween, or nil when nothing was animated (already at target, or
motion is disabled).
]]
function motion.tween(
	instance: Instance?,
	props: { [string]: any },
	spec: MotionSpec?,
	onCompleted: (() -> ())?
): Tween?
	if not instance or not props then
		return nil
	end

	local entry = active[instance]
	if entry and overlaps(entry, props) then
		motion.cancel(instance)
		entry = nil
	end

	if not motion.enabled or motion.timeScale == 0 then
		assign(instance, props)
		return nil
	end

	--[[
	Skip the tween when every property is already where it should be.
	Comparisons are per property, so a partially-satisfied call still
	animates the properties that need it.
	]]
	local pending: { [string]: any }? = nil
	for key, value in props do
		if instance[key] ~= value then
			pending = pending or {}
			pending[key] = value
		end
	end
	if not pending then
		return nil
	end

	local info = motion.spec(spec)
	local tween = coreState.tweenService:Create(instance :: Instance, info, pending)
	active[instance] = { tween = tween, props = pending } :: any
	if onCompleted then
		tween.Completed:Connect(onCompleted)
	end
	tween:Play()
	return tween
end

--[[
Applies `props` on the spot (cancelling anything this service is running
on the instance) - the state a tween would have settled on, with no
animation. The same target the caller would pass to `motion.tween`.
]]
function motion.set(instance: Instance?, props: { [string]: any }): ()
	if instance and props then
		motion.cancel(instance)
		assign(instance, props)
	end
end

return motion