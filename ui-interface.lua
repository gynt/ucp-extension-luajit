local LuaJITState = require("luajitstate")

local uiInterface = LuaJITState:new({
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
})

uiInterface:executeFile("ui/main.lua")
