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
local LUA_GLOBALSINDEX = -10002


local lua_pushstring = core.exposeCode(getProcAddress(luajitdll, "lua_pushstring"), 2, 0)
local lua_pushinteger = core.exposeCode(getProcAddress(luajitdll, "lua_pushinteger"), 2, 0)
local lua_pushnumber = core.exposeCode(getProcAddress(luajitdll, "lua_pushnumber"), 2, 0)
local lua_pushcclosure = core.exposeCode(getProcAddress(luajitdll, "lua_pushcclosure"), 3, 0)
local lua_setfield = core.exposeCode(getProcAddress(luajitdll, "lua_setfield"), 3, 0)
local lua_getfield = core.exposeCode(getProcAddress(luajitdll, "lua_getfield"), 3, 0)

local required = {}

local function executeString(L, s, path, cleanup)
  local cleanup = cleanup or false
  -- lua_pushstring(L, ucp.internal.registerString(contents))
  local stack = lua_gettop(L)
  luaL_loadstring(L, ucp.internal.registerString(s))
  local ret = lua_pcall(L, 0, -1, 0)

  if ret ~= 0 then
    log(ERROR, string.format("Fail: %s", core.readString(lua_tolstring(L, -1, 0))))
    lua_settop(L, stack)
    return 0
  end

  local returns = lua_gettop(L) - stack
  -- if returns > 0 then
  --   log(ERROR, string.format([[_require("%s") had return values which are not supported]], path))
  -- end

  log(VERBOSE, string.format("executed: %s", path))

  if cleanup then
    lua_settop(L, stack)
    return 0
  end
  -- lua_settop(L, stack)
  return returns
end

local function specialRequire(L)
  local pPath = lua_tolstring(L, 1, 0)
  local path = core.readString(pPath)
  log(VERBOSE, string.format("specialRequire(): %s", path))

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
    return executeString(L, string.format([[ return package.loaded['%s'] ]], path), path)
  end

  return executeString(L, contents, path)
end

local function run()
  log(VERBOSE, "running main.lua")
  local f = io.open("ucp/modules/luajit/main.lua", 'r')
  local contents = f:read("*all")
  f:close()

  return executeString(L, contents, "main.lua", true)
end


local RECEIVERS = {
  ['log'] = {
    function(key, value)
      log(value.logLevel, value.message)
    end,
  },
  ['functions.AOBExtract'] = {
    function(key, value)
      -- Does not work :/
      local returns = table.pack(utils.AOBExtract(value.target, value.start or nil, value.stop or nil, value.unpacked or nil))
      log(VERBOSE, 'AOBExtract(): %s', value.target)
      luajit:sendMenuEvent('functions.AOBExtract.reply', returns)
    end,
  }
}
local p_RECEIVE = ucp.internal.registerString("_RECEIVE")

local function receiveFromLuaJIT(L)
  local key = core.readString(lua_tolstring(L, 1, 0))
  local value = core.readString(lua_tolstring(L, 2, 0))

  log(VERBOSE, string.format("receive(): key = %s", key))

  local obj = yaml.parse(value)

  log(VERBOSE, string.format("receive(): parsed object: %s", obj))

  if RECEIVERS[key] ~= nil then
    for k, f in ipairs(RECEIVERS[key]) do
      log(VERBOSE, string.format("receive(): firing function"))
      local result, err = pcall(f, key, obj)
      if not result then 
        log(ERROR, err)
      end
    end
  else
    log(WARNING, string.format("receive(): unknown key: %s", key))
  end

  return 0
end

local function registerSend()
  local pHook = core.allocateCode({0x90, 0x90, 0x90, 0x90, 0x90, 0xC3})
  core.hookCode(receiveFromLuaJIT, pHook, 1, 0, 5)

  lua_pushcclosure(L, pHook, 0)
  lua_setfield(L, LUA_GLOBALSINDEX, ucp.internal.registerString("_SEND"))
end


function luajit:sendMenuEvent(key, obj)
  log(VERBOSE, string.format("sendMenuEvent(): key = %s", key))

  local pKey = core.allocate(key:len() + 1, true)
  local value = json:encode(obj)
  local pValue = core.allocate(value:len() + 1, true)

  core.writeString(pKey, key)
  core.writeString(pValue, value)

  local stack = lua_gettop(L)
  log(VERBOSE, string.format("stack: %s", stack))

  lua_getfield(L, LUA_GLOBALSINDEX, p_RECEIVE)
  lua_pushstring(L, pKey)
  lua_pushstring(L, pValue)

  if lua_pcall(L, 2, 0, 0) ~= 0 then
    log(ERROR, string.format("ERROR in send(): %s", lua_tolstring(L, -1, 0)))
    lua_settop(L, -2)
  end

  lua_settop(L, stack)
  log(VERBOSE, string.format("stack: %s", stack))

  
  core.deallocate(pKey)
  core.deallocate(pValue)
end


function luajit:receiveMenuEvent(key, func)
  if RECEIVERS[key] == nil then
    RECEIVERS[key] = {}
  end

  table.insert(RECEIVERS[key], func)
end

--- Create a menu by passing script string for luajit vm
function luajit:createMenu(caller, data)
  executeString(L, data, caller)
end

local function resolveAOBS()
  local addr_0x0057bfc3, addr_0x00613418 = utils.AOBExtract("68 I( ? ? ? ? ) B9 ? ? ? ? 89 ? ? ? ? ? E8 ? ? ? ? 68 04 02 00 00")
  log(VERBOSE, string.format("resolveAOBS(): %X, %X", addr_0x0057bfc3, addr_0x00613418))
  lua_pushinteger(L, addr_0x0057bfc3)
  lua_setfield(L, LUA_GLOBALSINDEX, ucp.internal.registerString("addr_0x0057bfc3"))

  lua_pushinteger(L, addr_0x00613418)
  lua_setfield(L, LUA_GLOBALSINDEX, ucp.internal.registerString("addr_0x00613418"))
end

function luajit:enable(config)

  log(VERBOSE, string.format("lib: %X", luajitdll))

  log(VERBOSE, "creating state")
  L = luaL_newstate()
  luaL_openlibs(L)

  resolveAOBS()

  registerSend()

  local pHook = core.allocateCode({0x90, 0x90, 0x90, 0x90, 0x90, 0xC3})
  core.hookCode(specialRequire, pHook, 1, 0, 5)

  lua_pushcclosure(L, pHook, 0)
  lua_setfield(L, LUA_GLOBALSINDEX, ucp.internal.registerString("_require"))

  -- hooks.registerHookCallback('afterInit', run)
  run()
 
end

function luajit:disable(config)
end

local pSwitchToMenuView = core.exposeCode(core.AOBScan("55 8B 6C 24 08 83 FD 17"), 3, 1)
local _, pThis = utils.AOBExtract("A3 I( ? ? ? ? ) 89 5C 24 1C")

function luajit:switchToMenu(menuID, delay)
  pSwitchToMenuView(pThis, menuID, delay or 0)
end

function luajit:getState()
  return L
end


return luajit