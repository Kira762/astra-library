local coreState = require(script.Parent.Parent.core.state)

local hapticService = {}

hapticService.enabled = false
type HapticTypes = {
    click: Enum.HapticEffectType?,
    notify: Enum.HapticEffectType?,
}

local effectTypes: HapticTypes = {}
local probeOk, probeResult = pcall(function()
    Instance.new("HapticEffect"):Destroy()     return {
        click = Enum.HapticEffectType.UIHover,         notify = Enum.HapticEffectType.UIClick,     }
end)
if probeOk then
    effectTypes = probeResult
end

local effectInstances: { [Enum.HapticEffectType]: Instance } = {}
local containerInstance: Instance? = nil

function hapticService.setContainer(newContainer: Instance?)
    containerInstance = newContainer
end

function hapticService.releaseContainer(releasedContainer: Instance?)
    if releasedContainer == nil or containerInstance == releasedContainer then
        containerInstance = nil
    end
end

local function resolveContainer(): Instance
    if containerInstance and containerInstance.Parent then
        return containerInstance
    end
    return coreState.guiContainer
end

local function getEffect(effectType: Enum.HapticEffectType): Instance?
    local cached = effectInstances[effectType]
        if cached and cached.Parent then
        return cached
    end
    local ok, instance = pcall(Instance.new, "HapticEffect")
    if not ok then
        return nil
    end
    local typed = instance :: any
    typed.Type = effectType
    local parentOk = pcall(function()
        instance.Parent = resolveContainer()
    end)
    if not parentOk then
        instance:Destroy()
        return nil
    end
    effectInstances[effectType] = instance
    return instance
end

local function play(requestedType: Enum.HapticEffectType?)
    if not requestedType or not hapticService.enabled then
        return
    end
    local effect = getEffect(requestedType)
    if effect then
        local playable = effect :: any
        pcall(playable.Play, effect)
    end
end

function hapticService.click()
    play(effectTypes.click)
end

function hapticService.notify()
    play(effectTypes.notify)
end

function hapticService.setEnabled(isEnabled: boolean?)
    hapticService.enabled = isEnabled and true or false
    if not hapticService.enabled then
        hapticService.teardown()
    end
end

function hapticService.teardown()
    for cachedType, cachedInstance in effectInstances do
        pcall(cachedInstance.Destroy, cachedInstance)
        effectInstances[cachedType] = nil
    end
end

return hapticService
