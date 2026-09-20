-- [[The `core` service surface. `state` is the only module anything consumes:
-- [[the entrypoint and `components/*` read `core.state` for the shared runtime
-- [[singletons. The generic registry/loader pair that used to sit beside it had
-- [[no readers (`registry.get` was never called, so `loader.service` registered
-- [[overrides nothing could look up) and was removed.]]
local state = require(script.state)

local core = {
    state = state,
}

return core
