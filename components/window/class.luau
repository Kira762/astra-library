-- [[The Window class table, on its own so every window module can attach
-- methods to the same table without a require cycle. Requiring this module
-- gives you the bare class; components/window/init.luau is what pulls in the
-- method modules and hands back the finished class.]]

local Window = {}
Window.__index = Window

return Window
