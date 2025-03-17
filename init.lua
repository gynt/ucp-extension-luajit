
local LuaJITState = require("state")

---@class luajit
local luajit = {}

function luajit:enable(config)

end

function luajit:disable(config)
end

---Create a new luajit state
---@return LuaJITState
function luajit:create(params)
  return LuaJITState:new(params)
end

return luajit, {
  proxy = {
    ignored = {
      'create',
    }
  }
}