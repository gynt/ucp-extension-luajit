local luajitdll = ucp.internal.loadLibraryA(io.resolveAliasedPath("ucp/modules/luajit/luajit.dll"))

local luaL_newstate = core.exposeCode(ucp.internal.getProcAddress(luajitdll, "luaL_newstate"), 0, 0)
local luaL_openlibs = core.exposeCode(ucp.internal.getProcAddress(luajitdll, "luaL_openlibs"), 1, 0)
local luaL_loadstring = core.exposeCode(ucp.internal.getProcAddress(luajitdll, "luaL_loadstring"), 2, 0)
local lua_pcall = core.exposeCode(ucp.internal.getProcAddress(luajitdll, "lua_pcall"), 4, 0)
local lua_tolstring = core.exposeCode(ucp.internal.getProcAddress(luajitdll, "lua_tolstring"), 3, 0)
local lua_settop = core.exposeCode(ucp.internal.getProcAddress(luajitdll, "lua_settop"), 2, 0)

local luajit = {}
local L

function luajit:enable(config)
  log(2, string.format("lib: %X", luajitdll))

  log(2, "creating state")
  L = luaL_newstate()
  luaL_openlibs(L)

  log(2, "running main.lua")
  local f = io.open("ucp/modules/luajit/main.lua", 'r')
  local contents = f:read("*all")
  f:close()
  luaL_loadstring(L, ucp.internal.registerString(contents))
  local ret = lua_pcall(L, 0, -1, 0)

  if ret ~= 0 then
    log(-1, string.format("Fail: %s", core.readString(lua_tolstring(L, -1, 0))))
    lua_settop(L, -2)
  else
    log(2, "succesfull")
  end

  log(2, "ran main.lua")
end

function luajit:disable(config)
end

function luajit:getState()
  return L
end

return luajit