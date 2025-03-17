
local LuaJITState = require("state")

local luajit = {}

function luajit:enable(config)

end

function luajit:disable(config)
end

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