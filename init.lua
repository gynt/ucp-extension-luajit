
local LuaJITState = require("state")

---@class luajit
local luajit = {}

function luajit:enable(config)
  local cTests = config.tests or {}
  if cTests.test == nil or cTests.test == true then
    log(WARNING, "running tests")
    local state = self:createState()
    state:executeFile("ucp/modules/luajit/tests/test.lua", true, false)
  end
end

function luajit:disable(config)
end

---Create a new luajit state
---@param params LuaJITStateParameters|nil
---@see LuaJITStateParameters
---@return LuaJITState state
function luajit:createState(params)
  return LuaJITState:new(params)
end

return luajit, {
  proxy = {
    ignored = {
      'createState',
    }
  }
}