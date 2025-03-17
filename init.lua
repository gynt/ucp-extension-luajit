
local LuaJITState = require("luajitstate")

local luajit = {}

function luajit:enable(config)

  log(VERBOSE, "testing")
  -- testing
  local state = self:create({
    name = "ui",
    requireHandler = function(self, path)
      local handle, err = io.open(string.format("ucp/modules/luajit/%s.lua", path))
      if not handle then
        handle, err = io.open(string.format("ucp/modules/luajit/%s/init.lua", path))
      end
    
      if not handle then
        error( err)
      end
    
      local contents = handle:read("*all")
      handle:close()

      return contents
    end,
    globals = {
      addr_0x00613418 = 0x00613418,
      addr_0x0057bfc3 = 0x0057bfc3,
    },
  })

  state:executeFile("ucp/modules/luajit/ui/main.lua")

  -- local pSwitchToMenuView = core.exposeCode(core.AOBScan("55 8B 6C 24 08 83 FD 17"), 3, 1)
-- local _, pThis = utils.AOBExtract("A3 I( ? ? ? ? ) 89 5C 24 1C")

-- function uiInterface:switchToMenu(menuID, delay)
--   pSwitchToMenuView(pThis, menuID, delay or 0)
-- end
end

function luajit:disable(config)
end

function luajit:create(params)
  return LuaJITState:new(params)
end

return luajit, {
  proxy = {
    ignore = {
      'create'
    }
  }
}