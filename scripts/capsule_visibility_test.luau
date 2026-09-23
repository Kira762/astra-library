--[[
Hold the real main-frame tween to inspect the fold BEFORE Completed. Ordinary
harness tweens finish synchronously and cannot catch the behind-window flash.
]]
local window = Astra:CreateWindow({ name = "Capsule visibility" })
local tab = window:CreateTab({ name = "Home" })
tab:CreateButton({ name = "Action" })
TestPump(1)
local tweenService = Astra.Core.state.tweenService
local createTween = tweenService.Create
local finishFold, completeFold
local function holdShellTween()
    tweenService.Create = function(service, target, info, props)
        local tween = createTween(service, target, info, props)
        if target == window.main and props.Size then
            completeFold = function() tween.Completed:Fire(Enum.PlaybackState.Completed) end
            local play = tween.Play
            tween.Play = function()
                finishFold = function() play(tween) end
            end
        end
        return tween
    end
end
local function invisible(message)
    assert(window.collapsedIcon.Visible == false, message .. ": icon")
    assert(window.collapsedTextFrame.Visible == false, message .. ": text")
    assert(window.collapsedInteract.Visible == false, message .. ": hit target")
end
for _, iconOnly in { false, true } do
    window.showIconOnly = iconOnly
    invisible("Expanded window has no capsule")
    holdShellTween()
    window:Hide()
    assert(finishFold and window.animating and window.hidden, "Inspect an unfinished fold")
    invisible("Capsule must not show behind the folding window")
    finishFold()
    tweenService.Create = createTween
    assert(window._collapsedShown and not window.animating, "Fold completed")
    assert(window.collapsedIcon.Visible and window.collapsedInteract.Visible, "Hidden window exposes restore capsule")
    assert(window.collapsedTextFrame.Visible == not iconOnly, "Text respects capsule style")
    window:Show()
    invisible("Capsule is removed as soon as restore begins")
    TestPump(0.8)
    invisible("No capsule after restore")
    window:ToggleMinimise()
    TestPump(0.8)
    invisible("Topbar-only minimisation is not a hidden-window capsule")
    window:ToggleMinimise()
    TestPump(0.8)
    invisible("No capsule after maximisation")
end
Astra.Motion.setProfile("instant")
window:Hide()
assert(window.collapsedIcon.Visible and not window.animating, "Instant hide reveals the capsule after settling")
window:Show()
TestPump(0.8)
invisible("Instant restore hides capsule")
Astra.Motion.setProfile("normal")
holdShellTween()
window:Hide()
local staleFinish = completeFold
window:Unload()
staleFinish()
tweenService.Create = createTween
assert(window.unloaded, "An unloaded fold cannot restore its capsule")
print("CAPSULE VISIBILITY: in-flight folds, both styles, restore, minimise, instant motion and unload passed")
