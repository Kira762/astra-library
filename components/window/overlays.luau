local overlayQueue = require(script.Parent.Parent.overlayQueue)
local tooltip = require(script.Parent.Parent.tooltip)

local Window = require(script.Parent.class)

function Window:_copyOverlayProps(props)
    local copy = {}
    if typeof(props) == "table" then
        for key, value in props do
            copy[key] = value
        end
    end
    return copy
end

-- Public notification API. Keep the queueing implementation private so all
-- callers, including settings and secure-mode diagnostics, use the same
-- bounded entrance lane.

function Window:Notify(props)
    if self.unloaded then
        return
    end
    return self:_showNotification(props)
end

function Window:_showNotification(props)
    if not self.notifications then
        self.notifications = self:Create("Frame", {
            Name = "Notifications",
            Size = UDim2.new(0, 300, 0, 800),
            Position = UDim2.new(1, -20, 1, -20),
            AnchorPoint = Vector2.new(1, 1),
            BackgroundTransparency = 1,

            Parent = self.screenGui,
        })

        self:Create("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            VerticalAlignment = Enum.VerticalAlignment.Bottom,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 0),

            Parent = self.notifications,
        })
    end

    -- [[The card is built on the queue's turn rather than right here: a host
    -- that fires a notification for every module it loaded used to pay for
    -- twenty frames' worth of instances and tweens on one. The layer itself is
    -- created up front, so the first notification's own turn only builds the
    -- card. See `components/overlayQueue.luau`. The props are snapshotted for
    -- the same reason: a host that reuses one table between queued calls must
    -- not have its last write end up on every card.]]
    local snapshot = self:_copyOverlayProps(props)
    local notification = require(script.Parent.Parent.notification)

    -- Exact duplicates are replacements, not refreshes. Remove every matching
    -- card first, then send the new snapshot through the normal entrance queue
    -- so the replacement always gets its own reveal animation. The queue still
    -- coalesces a duplicate that has not been built yet; there is no old card to
    -- remove in that case, so replacing its pending snapshot avoids needless
    -- construction while keeping the newest request.
    notification.dismissMatching(self, snapshot)
    overlayQueue.request(self, function(release)
        notification.new(self, snapshot, release)
    end, notification.key(snapshot))
end

function Window:Popup(props)
    if self.unloaded then
        return
    end
    return require(script.Parent.Parent.popup).new(self, props)
end

-- [[Open the floating description over `anchor`. A programmatic open is
-- [[pinned: it stays until `HideTooltip` or any of
-- [[the window transitions that clear descriptions.]] 

function Window:ShowTooltip(anchor: any, text: string)
    tooltip.show(self, anchor, text, true)
end

function Window:HideTooltip()
    tooltip.hide(self)
end
