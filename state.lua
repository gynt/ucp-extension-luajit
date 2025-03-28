local yaml = yaml
local registerString = core.registerString

local luajitdll, err = core.openLibraryHandle("ucp/modules/luajit/luajit.dll")

if luajitdll == false or luajitdll == nil then
  error(err)
end

local function getProcAddress(funcName)
  return luajitdll:getProcAddress(funcName)
end

local LUA_GLOBALSINDEX = -10002



local luaL_newstate = core.exposeCode(getProcAddress("luaL_newstate"), 0, 0)
local luaL_openlibs = core.exposeCode(getProcAddress("luaL_openlibs"), 1, 0)
local luaL_loadstring = core.exposeCode(getProcAddress("luaL_loadstring"), 2, 0)
local lua_pcall = core.exposeCode(getProcAddress("lua_pcall"), 4, 0)
local lua_tolstring = core.exposeCode(getProcAddress("lua_tolstring"), 3, 0)
local lua_settop = core.exposeCode(getProcAddress("lua_settop"), 2, 0)
local lua_gettop = core.exposeCode(getProcAddress("lua_gettop"), 1,  0)
local lua_pushstring = core.exposeCode(getProcAddress("lua_pushstring"), 2, 0)
local lua_pushcclosure = core.exposeCode(getProcAddress("lua_pushcclosure"), 3, 0)
local lua_setfield = core.exposeCode(getProcAddress("lua_setfield"), 3, 0)
local lua_getfield = core.exposeCode(getProcAddress("lua_getfield"), 3, 0)
local lua_objlen = core.exposeCode(getProcAddress("lua_objlen"), 2, 0)
local lua_rawgeti = core.exposeCode(getProcAddress("lua_rawgeti"), 3, 0)
local lua_pushnil = core.exposeCode(getProcAddress("lua_pushnil"), 1, 0)
local lua_rawseti = core.exposeCode(getProcAddress("lua_rawseti"), 3, 0)
local p_RECEIVE_EVENT = registerString("_RECEIVE_EVENT")

local function createState()
  local L = luaL_newstate()
  luaL_openlibs(L)

  return L
end

local function createLuaFunctionHook(func)
  local pHook = core.allocateCode({0x90, 0x90, 0x90, 0x90, 0x90, 0xC3})
  core.hookCode(func, pHook, 1, 0, 5)

  return pHook
end

local function setHookedGlobalFunction(L, name, func)
  local pHook = core.allocateCode({0x90, 0x90, 0x90, 0x90, 0x90, 0xC3})
  core.hookCode(func, pHook, 1, 0, 5)

  lua_pushcclosure(L, pHook, 0)
  lua_setfield(L, LUA_GLOBALSINDEX, registerString(name))
end

local function registerPreloader(L, preloader)
  local pPreloader = createLuaFunctionHook(preloader)

  -- stack:
  lua_getfield(L, LUA_GLOBALSINDEX, registerString("package"))
  -- stack: package
  lua_getfield(L, -1, registerString("loaders"))
  -- stack: package, loaders
  local n = lua_objlen(L, -1)
  
  if n ~= 4 then log(WARNING, "expected 4 loaders, received: ", n) end

  for i=(n+1),2,-1 do
    lua_rawgeti(L, -1, i-1) -- get the last entry
    -- stack: package, loaders, last
    lua_rawseti(L, -2, i) -- set it one spot further away
  end
  -- stack: package, loaders
  lua_pushcclosure(L, pPreloader, 0)
  -- stack: package, loaders, preloader
  lua_rawseti(L, -2, 1) -- set to position 1
  -- stack: package, loaders
  lua_settop(L, -1 -2)
  -- stack: 
end

---@class LuaJITState
---@field requireHandlers table<fun(self: LuaJITState, path: string): string>
---@private L number pointer to the lua state
local LuaJITState = {}


---@class LuaJITStateParameters
---@field name string
---@field requireHandler fun(self: LuaJITState, path: string): string
---@field eventHandlers table<string,table<fun(key: string, obj: any):void>>
---@field globals table<string, string|number> table of globals to apply
local LuaJITStateParameters = {}

---Create a new LuaJIT state
---@param params LuaJITStateParameters parameters for the new state.
---@see LuaJITStateParameters
---@return LuaJITState
function LuaJITState:new(params)
  local o = {}
    
  setmetatable(o, self)
  self.__index = self

  o.name = string.format("%s", o)
  if params.name then
    o.name = params.name
  end

  o.L = createState()

  o.requireHandlers = {
    function(s, path)
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
  }

  if params.requireHandler then
    table.insert(o.requireHandlers, 1, params.requireHandler)
  end

  o.loaded = {} -- contains the loaded modules

  local loader = function(L)
    local pPath = lua_tolstring(L, 1, 0)
    local path = core.readString(pPath)
    log(VERBOSE, string.format("loader(): %s", path))

    local contents = o.loaded[path] -- filled from the preloader() call
    local returnValues = o:executeString(contents, path, false)

    return returnValues -- just return whatever the execute gave us
  end

  local pLoader = createLuaFunctionHook(loader)

  local preloader = function(L)
    local stack = lua_gettop(L)
    -- This is called when the module isn't loaded yet
    local pPath = lua_tolstring(L, 1, 0)
    local path = core.readString(pPath)
    log(VERBOSE, string.format("preloader(): %s", path))

    local result = ""
    
    -- Technically we need a loader, but we fetch the contents immediately
    for _, handler in ipairs(o.requireHandlers) do
      local status, error_or_contents = pcall(handler, o, path)

      if status == false or status == nil then
        result = result .. "\n" .. error_or_contents
        log(VERBOSE, error_or_contents)

      else
        -- store contents for later
        o.loaded[path] = error_or_contents
  
        lua_pushcclosure(L, pLoader, 0)
    
        return 1 -- return the loader function   
      end

    end

    local str = core.CString(result)
    lua_pushstring(L, str.address)
    -- lua_settop(L, stack)
    -- lua_pushnil(L)
    -- log(VERBOSE, "returning nil")
    return 1 -- return error, alternatively we can return a nil
  end

  registerPreloader(o.L, preloader)

  o.eventHandlers = {
    ['log'] = {
      function(key, value)
        for k,v  in pairs(value) do print(k, v) end
        log(value.logLevel, value.message)
      end,
    },
  }

  setHookedGlobalFunction(o.L, "_SEND_EVENT", function(L)
    local key = core.readString(lua_tolstring(L, 1, 0))
    local value = core.readString(lua_tolstring(L, 2, 0))

    log(VERBOSE, string.format("_SEND_EVENT(%s): %s", key, value))
    local obj = yaml.parse(value)

    if o.eventHandlers[key] ~= nil then
      for k, f in ipairs(o.eventHandlers[key]) do
        log(VERBOSE, string.format("receive(): firing function for: %s", key))
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

  for name, value in pairs(params.globals or {}) do
    o:setGlobal(name, value)
  end

  --o:executeFile("ucp/modules/luajit/vendor/json/json.lua", false)
  --lua_setfield(o.L, LUA_GLOBALSINDEX, registerString("json"))
  o:executeFile("ucp/modules/luajit/common/packages.lua")
  o:executeFile("ucp/modules/luajit/common/serialization.lua")
  o:executeFile("ucp/modules/luajit/common/events.lua")
  o:executeFile("ucp/modules/luajit/common/invoke.lua")
  o:executeFile("ucp/modules/luajit/common/log.lua")
  o:executeFile("ucp/modules/luajit/common/code.lua")

  return o
end

---Execute a file (lua script) in the context of this state
---@param str string the script to execute
---@param path string the path associated with the script. Is reported in case of errors
---@param cleanup boolean|nil whether to cleanup the lua stack (default)
---@param convert boolean|nil if cleanup, whether to return a serialized and deserialized return value (default)
---@return LuaJITState|number|nil returns depending on cleanup returns self, a lua object, or a number indicating how many stack values to return
function LuaJITState:executeString(str, path, cleanup, convert)
  local L = self.L

  if cleanup == nil or cleanup == true then
    cleanup = true
  else
    cleanup = false
  end
  if convert == nil or convert == true then
    convert = cleanup -- or should we raise an error if cleanup is false, and convert is true?
  else
    convert = false
  end

  local cstr = core.CString(str)

  local cleanstack = lua_gettop(L)

  if convert then
    local f = core.CString("_SERIALIZE")
    lua_getfield(L, LUA_GLOBALSINDEX, f.address)
  end
  
  local stack = lua_gettop(L) -- store the amount of values on the stack so we can exit cleanly

  -- stack: [_SERIALIZE]
  luaL_loadstring(L, cstr.address)
  -- stack: [_SERIALIZE], string
  local ret = lua_pcall(L, 0, -1, 0)
  -- stack: [_SERIALIZE], return values ...

  if ret ~= 0 then
    -- stack: [_SERIALIZE], error message
    log(ERROR, string.format("Fail: %s", core.readString(lua_tolstring(L, -1, 0))))
    lua_settop(L, stack) -- exit cleanly
    return 0
  end

  -- stack: [_SERIALIZE], return values ...
  local returns = lua_gettop(L) - stack

  log(VERBOSE, string.format("executed: %s, returned %s values", path, returns))

  if cleanup then
    if convert then
      if returns > 0 then
        -- Imagine returns was 2, then the _SERIALIZE is at -3
        local nargs = -1 * (returns + 1)

        -- stack: [_SERIALIZE], return values ...
        local serRet = lua_pcall(L, nargs, 1, 0) -- only allow 1 return value (the serialized object)
        
        if serRet ~= 0 then
          -- stack: errorMsg, 
          log(ERROR, string.format("Fail: Failed to serialize %s", core.readString(lua_tolstring(L, -1, 0))))
          lua_settop(L, cleanstack)
          return nil
        end
        -- stack: serialized return values, 
        local result = core.readString(lua_tolstring(L, -1, 0))
        lua_settop(L, cleanstack)
        return yaml.parse(result)
      else
        lua_settop(L, cleanstack)
        return nil
      end
    end
    lua_settop(L, cleanstack) -- exit cleanly
    return self
  end

  return returns -- exit dirty, meant for raw access to lua C api
end

---Execute a file (lua script) in the context of this state
---@param path string
---@param cleanup boolean|nil whether to cleanup the lua stack (default)
---@param convert boolean|nil if cleanup, whether to return a serialized and deserialized return value (default)
---@return LuaJITState|number|nil returns depending on cleanup returns self, a lua object, or a number indicating how many stack values to return
function LuaJITState:executeFile(path, cleanup, convert)
  local f, err = io.open(io.resolveAliasedPath(path), 'r')
  if f == nil then
    error(err)
  end
  local contents = f:read("*all")
  f:close()

  return self:executeString(contents, path, cleanup, convert)
end

---Invoke a function with arguments
---@param funcName string the name of the function, should be global
---@param ... any arguments to the function
---@return any value the return values of the function
function LuaJITState:invoke(funcName, ...)
  log(VERBOSE, string.format("invoke(%s)", funcName))

  local args = {...}

  local L = self.L

  local serializedArgs = json:encode(args) -- todo: check if no arguments is correctly forwarded here!
  log(VERBOSE, string.format("invoke: %s(%s)", funcName, serializedArgs))

  local funcStr = core.CString(funcName)
  local argsStr = core.CString(serializedArgs)

  local stack = lua_gettop(L)

  local invokeStr = core.CString("_INVOKE")
  lua_getfield(L, LUA_GLOBALSINDEX, invokeStr.address)
  lua_pushstring(L, funcStr.address)
  lua_pushstring(L, argsStr.address)

  if lua_pcall(L, 2, 1, 0) ~= 0 then -- expect a single value
    -- Note: the error could be an implementation error (serialization) or an user error
    local errorMsg = string.format("error in _INVOKE(%s,): %s", funcName, core.readString(lua_tolstring(L, -1, 0)))
    log(ERROR, errorMsg)
    lua_settop(L, -2) -- pop one value (the error)
    error(errorMsg)
  end

  local serializedRet = core.readString(lua_tolstring(L, -1, 0))
  log(VERBOSE, string.format("invoke: %s() => %s", funcName, serializedRet))
  local result = yaml.parse(serializedRet)

  lua_settop(L, stack)

  return table.unpack(result)  
end

---Invoke a function with arguments wrapped in a pcall()
---@param funcName string the name of the function, should be global
---@param ... any arguments to the function
---@return bool,any value boolean indicating success and the return values
function LuaJITState:pinvoke(funcName, ...)
  log(VERBOSE, string.format("invoke(%s)", funcName))

  local args = {...}

  local L = self.L

  local serializedArgs = json:encode(args) -- todo: check if no arguments is correctly forwarded here!

  local funcStr = core.CString(funcName)
  local argsStr = core.CString(serializedArgs)

  local stack = lua_gettop(L)

  local invokeStr = core.CString("_PINVOKE")
  lua_getfield(L, LUA_GLOBALSINDEX, invokeStr.address)
  lua_pushstring(L, funcStr.address)
  lua_pushstring(L, argsStr.address)

  if lua_pcall(L, 2, 1, 0) ~= 0 then -- expect a single value
    -- Since this means an implementation error, we should reraise the error instead of feeding it to the caller
    local errorMsg = string.format("error in _INVOKE(%s,): %s", funcName, core.readString(lua_tolstring(L, -1, 0)))
    log(ERROR, errorMsg)
    lua_settop(L, -2) -- pop one value (the error)
    error(errorMsg)
  end

  local result = yaml.parse(core.readString(lua_tolstring(L, -1, 0)))

  lua_settop(L, stack)

  return table.unpack(result) 
end

---Register require handler. When this state calls require(), this function will be invoked.
---@param func fun(path: string): string
function LuaJITState:registerRequireHandler(func)
  table.insert(self.requireHandlers, 1, func)
end

---Trigger or send an event to the state
---@param key string
---@param obj any JSON serialize object to send to the state
function LuaJITState:sendEvent(key, obj)
  log(VERBOSE, string.format("sendEvent(): key = %s", key))

  local L = self.L

  local value = json:encode(obj)

  local keyStr = core.CString(key)
  local valueStr = core.CString(value)

  local stack = lua_gettop(L)

  lua_getfield(L, LUA_GLOBALSINDEX, p_RECEIVE_EVENT)
  lua_pushstring(L, keyStr.address)
  lua_pushstring(L, valueStr.address)

  if lua_pcall(L, 2, 0, 0) ~= 0 then
    log(ERROR, string.format("error in _RECEIVE_EVENT(): %s", lua_tolstring(L, -1, 0)))
    lua_settop(L, -2) -- pop one value (the error)
  end

  lua_settop(L, stack)

  return self
end

---Register an event handler function
---@param key string key to identify the event type
---@param func fun(key: string, obj: any): void callback function
---@return LuaJITState
function LuaJITState:registerEventHandler(key, func)
  if self.eventHandlers[key] == nil then
    self.eventHandlers[key] = {}
  end
  table.insert(self.eventHandlers[key], func)

  return self
end

---Set a global in the state to a string or number
---@param name string
---@param value string|number
---@return LuaJITState state
function LuaJITState:setGlobal(name, value)
  self:executeString(string.format([[%s = %s]], name, value))

  return self
end


---Set a global in the state to a string or number
---@param globals table<string, any> map of variable names and values to be set globally
---@return LuaJITState state
function LuaJITState:setGlobals(globals)
  for name, value in pairs(globals) do
    self:setGlobal(name, value)
  end
  
  return self
end

---Get the internal lua state pointer associated with this luajit state
---@return number
function LuaJITState:getState()
  return self.L
end

return LuaJITState