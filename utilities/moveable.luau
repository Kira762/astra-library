local function moveable<T>(dragState: T): T
    local target = dragState :: any

    function target:MoveTo(index: number)
        self.tab:_moveElement(self, index)
    end

    function target:MoveToTop()
        self.tab:_moveElement(self, 1)
    end

    function target:MoveToBottom()
        self.tab:_moveElement(self, #self.tab.elements)
    end

    function target:MoveUp()
        local upPosition = table.find(self.tab.elements, self)
        if upPosition then
            self.tab:_moveElement(self, upPosition - 1)
        end
    end

    function target:MoveDown()
        local downPosition = table.find(self.tab.elements, self)
        if downPosition then
            self.tab:_moveElement(self, downPosition + 1)
        end
    end

    return dragState
end

return moveable
