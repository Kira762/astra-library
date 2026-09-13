-- ===== switch (toggle) preview dump =====
-- [[Walks a real Toggle element built by the bundle and prints it as JSON so
-- [[an offline renderer can draw it (scripts/render_toggle_preview.py).
-- [[Run through scripts/toggle_preview.sh; not part of the test suite.
-- [[Dumps the off and on states of one element behind the same element plate
-- [[the screenshot shows, so the track, the knob and the gaps between them can
-- [[be measured without launching Roblox.]]
local state = Astra.Core.state

local window = Astra:CreateWindow({ name = "Toggle Preview" })
TestPump(0.6)
window:Show()
TestPump(0.6)

local tab = window:CreateTab({ name = "Switch" })
local offToggle = tab:CreateToggle({
    name = "Switch Off",
    description = "The resting state.",
    value = false,
})
local onToggle = tab:CreateToggle({
    name = "Switch On",
    description = "The active state.",
    value = true,
})
TestPump(0.4)
window:Show()
TestPump(0.6)

local function num(value)
    return string.format("%.4f", value or 0)
end

local function color(value)
    if not value then
        return "null"
    end
    return string.format("[%s,%s,%s]", num(value.R), num(value.G), num(value.B))
end

local function esc(text)
    return '"' .. tostring(text):gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
end

local function dump(inst)
    local props = inst.__props or {}
    local parts = {}
    local anchor = props.AnchorPoint
    table.insert(parts, '"name":' .. esc(props.Name or "?"))
    table.insert(parts, '"class":' .. esc(props.ClassName or "?"))
    table.insert(parts, '"anchor":[' .. num(anchor and anchor.X) .. "," .. num(anchor and anchor.Y) .. "]")
    local px, py = props.Position and props.Position.X or {}, props.Position and props.Position.Y or {}
    local sx, sy = props.Size and props.Size.X or {}, props.Size and props.Size.Y or {}
    table.insert(parts, '"pos":[' .. num(px.Scale) .. "," .. num(px.Offset) .. "," .. num(py.Scale) .. "," .. num(py.Offset) .. "]")
    table.insert(parts, '"size":[' .. num(sx.Scale) .. "," .. num(sx.Offset) .. "," .. num(sy.Scale) .. "," .. num(sy.Offset) .. "]")
    table.insert(parts, '"visible":' .. tostring(props.Visible ~= false))
    table.insert(parts, '"x":' .. num(inst.AbsolutePosition and inst.AbsolutePosition.X))
    table.insert(parts, '"y":' .. num(inst.AbsolutePosition and inst.AbsolutePosition.Y))
    table.insert(parts, '"w":' .. num(inst.AbsoluteSize and inst.AbsoluteSize.X))
    table.insert(parts, '"h":' .. num(inst.AbsoluteSize and inst.AbsoluteSize.Y))
    table.insert(parts, '"color":' .. color(props.BackgroundColor3))
    table.insert(parts, '"backgroundTransparency":' .. num(props.BackgroundTransparency or 0))
    table.insert(parts, '"borderSizePixel":' .. num(props.BorderSizePixel or 0))
    table.insert(parts, '"z":' .. num(props.ZIndex or 1))

    local corner = "null"
    local stroke = "null"
    local shadow = "null"
    local gradients = {}
    for _, child in inst:GetChildren() do
        local childProps = child.__props or {}
        if childProps.ClassName == "UICorner" and childProps.CornerRadius then
            corner = string.format("[%s,%s]", num(childProps.CornerRadius.Scale), num(childProps.CornerRadius.Offset))
        elseif childProps.ClassName == "UIStroke" then
            local c = childProps.Color
            stroke = ("[%s,%s,%s,%s]"):format(num(c and c.R), num(c and c.G), num(c and c.B), num(childProps.Transparency or 0))
        elseif childProps.ClassName == "UIGradient" then
            -- [[One entry per gradient child, each carrying its own colour ramp
            -- [[*and* its own transparency ramp: elements stack more than one
            -- [[(the theme's body gradient plus a sheen), so mixing their
            -- [[properties would draw neither faithfully.]]
            local keypoints = childProps.Color and childProps.Color.Keypoints
            local ramp = childProps.Transparency and childProps.Transparency.Keypoints
            local first = keypoints and keypoints[1] or (ramp and ramp[1])
            local last = keypoints and keypoints[#keypoints] or (ramp and ramp[#ramp])
            if first and last then
                local a = keypoints and keypoints[1].Value or Color3.fromRGB(255, 255, 255)
                local b = keypoints and keypoints[#keypoints].Value or Color3.fromRGB(255, 255, 255)
                table.insert(
                    gradients,
                    ("[%s,%s,%s,%s,%s,%s,%s,%s]"):format(
                        num(a.R), num(a.G), num(a.B), num(b.R), num(b.G), num(b.B),
                        num(ramp and ramp[1].Value or 0), num(ramp and ramp[#ramp].Value or 0)
                    )
                )
            end
        elseif childProps.ClassName == "UIShadow" then
            local c = childProps.Color
            shadow = (
                "[%s,%s,%s,%s,%s]"
            ):format(
                num(c and c.R),
                num(c and c.G),
                num(c and c.B),
                num(childProps.Transparency or 0),
                num(childProps.BlurRadius and childProps.BlurRadius.Offset or 0)
            )
        end
    end
    table.insert(parts, '"corner":' .. corner)
    table.insert(parts, '"stroke":' .. stroke)
    table.insert(parts, '"gradients":[' .. table.concat(gradients, ",") .. "]")
    table.insert(parts, '"shadow":' .. shadow)

    local children = {}
    for _, child in inst:GetChildren() do
        local childProps = child.__props or {}
        if childProps.Size then
            table.insert(children, dump(child))
        end
    end
    table.insert(parts, '"children":[' .. table.concat(children, ",") .. "]")
    return "{" .. table.concat(parts, ",") .. "}"
end

print("OFF")
print(dump(offToggle.main))
print("ON")
print(dump(onToggle.main))
