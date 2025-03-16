local loadLibraryA = ucp.internal.loadLibraryA
local getProcAddress = ucp.internal.getProcAddress

local luajitdll = loadLibraryA(io.resolveAliasedPath("ucp/modules/luajit/luajit.dll"))

local luaL_newstate = core.exposeCode(getProcAddress(luajitdll, "luaL_newstate"), 0, 0)
local luaL_openlibs = core.exposeCode(getProcAddress(luajitdll, "luaL_openlibs"), 1, 0)
local luaL_loadstring = core.exposeCode(getProcAddress(luajitdll, "luaL_loadstring"), 2, 0)
local lua_pcall = core.exposeCode(getProcAddress(luajitdll, "lua_pcall"), 4, 0)
local lua_tolstring = core.exposeCode(getProcAddress(luajitdll, "lua_tolstring"), 3, 0)
local lua_settop = core.exposeCode(getProcAddress(luajitdll, "lua_settop"), 2, 0)
local lua_gettop = core.exposeCode(getProcAddress(luajitdll, "lua_gettop"), 1,  0)


local luajit = {}
local L


local lua_pushstring = core.exposeCode(getProcAddress(luajitdll, "lua_pushstring"), 2, 0)
local lua_pushcclosure = core.exposeCode(getProcAddress(luajitdll, "lua_pushcclosure"), 3, 0)
local lua_setfield = core.exposeCode(getProcAddress(luajitdll, "lua_setfield"), 3, 0)

local required = {}

local function specialRequire(L)
  local pPath = lua_tolstring(L, 1, 0)
  local path = core.readString(pPath)
  log(2, string.format("specialRequire(): %s", path))

  local handle, err = io.open(string.format("ucp/modules/luajit/%s.lua", path))
  if not handle then
    handle, err = io.open(string.format("ucp/modules/luajit/%s/init.lua", path))
  end

  if not handle then
    log(ERROR, err)
    return 0
  end

  local contents = handle:read("*all")
  handle:close()

  if required[contents] ~= nil then
    return 0
  end

  -- lua_pushstring(L, ucp.internal.registerString(contents))
  local stack = lua_gettop(L)
  luaL_loadstring(L, ucp.internal.registerString(contents))
  local ret = lua_pcall(L, 0, -1, 0)

  if ret ~= 0 then
    log(ERROR, string.format("Fail: %s", core.readString(lua_tolstring(L, -1, 0))))
    lua_settop(L, stack)
    return 0
  end

  local returns = lua_gettop(L) - stack
  if returns > 0 then log(ERROR, string.format([[_require("%s") had return values which are not supported]], path)) end

  log(VERBOSE, string.format("loaded: %s", path))

  lua_settop(L, stack)
  return 0 -- we return nothing because that isn't supported.
end

local function run()
  log(VERBOSE, "running main.lua")
  local f = io.open("ucp/modules/luajit/main.lua", 'r')
  local contents = f:read("*all")
  f:close()
  luaL_loadstring(L, ucp.internal.registerString(contents))
  local ret = lua_pcall(L, 0, -1, 0)

  if ret ~= 0 then
    log(ERROR, string.format("Fail: %s", core.readString(lua_tolstring(L, -1, 0))))
    lua_settop(L, -2)
  else
    log(VERBOSE, "succesfull")
  end

  log(VERBOSE, "ran main.lua")
end

function luajit:enable(config)
  log(VERBOSE, string.format("lib: %X", luajitdll))

  log(VERBOSE, "creating state")
  L = luaL_newstate()
  luaL_openlibs(L)

  local pHook = core.allocateCode({0x90, 0x90, 0x90, 0x90, 0x90, 0xC3})
  core.hookCode(specialRequire, pHook, 1, 0, 5)

  lua_pushcclosure(L, pHook, 0)
  lua_setfield(L, -10002, ucp.internal.registerString("_require"))

  -- hooks.registerHookCallback('afterInit', run)
  run()

end

function luajit:disable(config)
end

function luajit:getState()
  return L
end

return luajit