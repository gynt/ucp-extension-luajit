require("luajitstate")

uiInterface = LuaJITState:new({
    name = "ui",
    requireHandler = function(ui, path)

        -- Don't do a cleanup because we want to inspect the results.
        local testresult = ui:executeString(string.format([[ return package.loaded['%s'] ]], path), path, false)
        if o:lua_isnil(-1) ~= 1 then -- not nil, so exists
            return 1 -- return the cached result
        end

        local handle, err = io.open(string.format("ucp/modules/luajit/%s.lua", path))
        if not handle then
          handle, err = io.open(string.format("ucp/modules/luajit/%s/init.lua", path))
        end
      
        if not handle then
          log(ERROR, err)
          return 0 -- return nothing to luajit
        end
      
        local contents = handle:read("*all")
        handle:close()
      
        local result = o:executeString(contents, path, false) -- don't cleanup
        if result ~= nil and result ~= 0 then
            -- TODO: fetch the package.loaded table and set the value
            -- involves some stack swapping magic...
        end

        return result
    end,
})