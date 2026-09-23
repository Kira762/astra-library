local function lockable<T>(element: T): T
    local target = element :: any

    function target:Lock(reason: string?)
        self.window:_setElementLocked(self, true, reason)
    end

    function target:Unlock()
        self.window:_setElementLocked(self, false)
    end

    function target:IsLocked(): boolean
        return self.locked == true
    end

    return element
end

return lockable
