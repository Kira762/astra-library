--[[
The window, split by responsibility. Every module below attaches its
methods to the shared class table in `class.luau`, so `self` behaves exactly
as it did when all 111 methods lived in one 3,098-line file. The requires
are for their side effects and the order does not matter: nothing here runs
window code, it only defines methods.
]]

local Window = require(script.class)

require(script.startup)
require(script.theme)
require(script.tabs)
require(script.elements)
require(script.overlays)
require(script.layout)
require(script.visibility)
require(script.input)
require(script.settings)
require(script.config)
require(script.teardown)

return Window
