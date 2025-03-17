
local p_require = ucp.internal.registerString("_require")

local function createState()
  local L = luaL_newstate()
  luaL_openlibs(L)

  return L
end

local function setHookedGlobalFunction(L, name, func)
  local pHook = core.allocateCode({0x90, 0x90, 0x90, 0x90, 0x90, 0xC3})
  core.hookCode(func, pHook, 1, 0, 5)

  lua_pushcclosure(L, pHook, 0)
  lua_setfield(L, LUA_GLOBALSINDEX, ucp.internal.registerString(name))
end

local LuaJITState = {}

function LuaJITState:new(params)
  local o = {}

  o.name = string.format("%s", o)
  if params.name then
    o.name = params.name
  end

  o.L = createState()

  o.requireHandler = function(s, path)
    error("no require handler specified")
  end

  if params.requireHandler then
    o.requireHandler = params.requireHandler
  end

  setHookedGlobalFunction(o.L, "_require", function(L)
    local pPath = lua_tolstring(L, 1, 0)
    local path = core.readString(pPath)
    log(VERBOSE, string.format("onRequire(): %s", path))

    local status, error_or_nresults = pcall(o.requireHandler, o, path, L)

    if status == false or status == nil then
      log(ERROR, error_or_nresults)
      return 0
    end

    return error_or_nresults
  end)

  o.eventHandlers = {
    ['log'] = {
      function(key, value)
        log(value.logLevel, value.message)
      end,
    },
  }

  setHookedGlobalFunction(o.L, "_SEND", function(L)
    local key = core.readString(lua_tolstring(L, 1, 0))
    local value = core.readString(lua_tolstring(L, 2, 0))

    log(VERBOSE, string.format("receive(): key = %s", key))

    local obj = yaml.parse(value)

    log(VERBOSE, string.format("receive(): parsed object: %s", obj))

    if o.eventHandlers[key] ~= nil then
      for k, f in ipairs(o.eventHandlers[key]) do
        log(VERBOSE, string.format("receive(): firing function"))
        local result, err_or_ret = pcall(f, key, obj)
        if not result then 
          log(ERROR, err_or_ret)
        end
      end
    else
      log(WARNING, string.format("No callbacks for %s", key))
    end

    return 0
  end)
  
  setmetatable(o, self)
  self.__index = self

  return o
end

function LuaJITState:executeString(string, path, cleanup)
  local L = self.L

  if cleanup == nil then
    cleanup = true
  end
  local stack = lua_gettop(L)
  -- TODO: optimize with deallocate()
  luaL_loadstring(L, ucp.internal.registerString(string))
  local ret = lua_pcall(L, 0, -1, 0)

  if ret ~= 0 then
    log(ERROR, string.format("Fail: %s", core.readString(lua_tolstring(L, -1, 0))))
    lua_settop(L, stack)
    return 0
  end

  local returns = lua_gettop(L) - stack

  log(VERBOSE, string.format("executed: %s", path))

  if cleanup then
    lua_settop(L, stack)
    return self
  end

  -- TODO: invent a way to return the results, in json form?
  -- Otherwise leave it here for convenience usage...
  return returns
end

function LuaJITState:setRequireHandler(func)
  self.requireHandler = func
end

function LuaJITState:sendEvent(key, obj)
  log(VERBOSE, string.format("sendEvent(): key = %s", key))

  local value = json:encode(obj)

  local pKey = core.allocate(key:len() + 1, true)
  local pValue = core.allocate(value:len() + 1, true)

  core.writeString(pKey, key)
  core.writeString(pValue, value)

  local stack = lua_gettop(L)

  lua_getfield(L, LUA_GLOBALSINDEX, p_RECEIVE)
  lua_pushstring(L, pKey)
  lua_pushstring(L, pValue)

  if lua_pcall(L, 2, 0, 0) ~= 0 then
    log(ERROR, string.format("error in _RECEIVE(): %s", lua_tolstring(L, -1, 0)))
    lua_settop(L, -2)
  end

  lua_settop(L, stack)
  
  core.deallocate(pKey)
  core.deallocate(pValue)

  return self
end

function LuaJITState:registerEventHandler(key, func)
  if self.eventHandlers[key] == nil then
    self.eventHandlers[key] = {}
  end
  table.insert(self.eventHandlers[key], func)

  return self
end

function LuaJITState:setGlobal(name, value)
  self:executeString(string.format([[name = %s]], value))

  return self
end

function LuaJITState:getState()
  return self.L
end