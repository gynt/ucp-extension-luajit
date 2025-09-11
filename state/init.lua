local yaml = yaml
local registerString = core.registerString

local luajitdll, err = core.openLibraryHandle("ucp/modules/luajit/lua51.dll")

if luajitdll == false or luajitdll == nil then
  error(err)
end

local luajitexceptionsAddress = require("luajitexceptions.dll")
local init_exceptionsHandler = core.exposeCode(luajitexceptionsAddress, 1, 0)

local function getProcAddress(funcName)
  return luajitdll:getProcAddress(funcName)
end

local LUA_GLOBALSINDEX = -10002


local lua_load = core.exposeCode(getProcAddress("lua_load"), 4, 0)
local luaL_newstate = core.exposeCode(getProcAddress("luaL_newstate"), 0, 0)
local luaL_openlibs = core.exposeCode(getProcAddress("luaL_openlibs"), 1, 0)
local luaL_loadstring = core.exposeCode(getProcAddress("luaL_loadstring"), 2, 0)
local lua_pcall = core.exposeCode(getProcAddress("lua_pcall"), 4, 0)
local lua_tolstring = core.exposeCode(getProcAddress("lua_tolstring"), 3, 0)
local lua_settop = core.exposeCode(getProcAddress("lua_settop"), 2, 0)
local lua_gettop = core.exposeCode(getProcAddress("lua_gettop"), 1,  0)
local lua_pushboolean = core.exposeCode(getProcAddress("lua_pushboolean"), 2, 0)
local lua_pushstring = core.exposeCode(getProcAddress("lua_pushstring"), 2, 0)
local lua_pushcclosure = core.exposeCode(getProcAddress("lua_pushcclosure"), 3, 0)
local lua_setfield = core.exposeCode(getProcAddress("lua_setfield"), 3, 0)
local lua_getfield = core.exposeCode(getProcAddress("lua_getfield"), 3, 0)
local lua_objlen = core.exposeCode(getProcAddress("lua_objlen"), 2, 0)
local lua_rawgeti = core.exposeCode(getProcAddress("lua_rawgeti"), 3, 0)
local lua_pushnil = core.exposeCode(getProcAddress("lua_pushnil"), 1, 0)
local lua_rawseti = core.exposeCode(getProcAddress("lua_rawseti"), 3, 0)
-- local LUA_REGISTRYINDEX	= -10000 -- special LUAJIT value
-- local luaL_ref = core.exposeCode(getProcAddress("luaL_ref"), 2, 0)
-- local luaL_unref = core.exposeCode(getProcAddress("luaL_unref"), 3, 0)
-- local lua_pushvalue = core.exposeCode(getProcAddress("lua_pushvalue"), 2, 0)
local p_RECEIVE_EVENT = registerString("_RECEIVE_EVENT")

local serialization = require("state/serialization")

local function createState()
  local L = luaL_newstate()
  luaL_openlibs(L)
  --fixme: reenable
  -- init_exceptionsHandler(L)

  log(VERBOSE, string.format("VM: createState: lua_gettop() = %s", lua_gettop(L)))
  
  return L
end

local function createLuaFunctionHook(func)
  local pHook = core.allocateCode({0x90, 0x90, 0x90, 0x90, 0x90, 0xC3})
  core.hookCode(func, pHook, 1, 0, 5)

  return pHook
end

local function setHookedGlobalFunction(L, name, func)
  log(VERBOSE, string.format("VM: setHookedGlobalFunction: lua_gettop(0x%X) = %s", L, lua_gettop(L)))

  local pHook = core.allocateCode({0x90, 0x90, 0x90, 0x90, 0x90, 0xC3})
  log(VERBOSE, string.format("VM: setHookedGlobalFunction: hook @ 0x%X", pHook))
  core.hookCode(func, pHook, 1, 0, 5)

  lua_pushcclosure(L, pHook, 0)
  lua_setfield(L, LUA_GLOBALSINDEX, registerString(name))
end

local function registerPreloader(L, preloader)
  log(VERBOSE, string.format("VM: registerPreLoader: lua_gettop() = %s", lua_gettop(L)))

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

local ProxyInterface = require("state/finterface")

---@class LuaJITState
---@field requireHandlers table<fun(self: LuaJITState, path: string): string>
---@private L number pointer to the lua state
local LuaJITState = {}


---@class LuaJITStateParameters
---@field name string
---@field requireHandler nil|fun(self: LuaJITState, path: string): string
---@field eventHandlers nil|table<string,table<fun(key: string, obj: any):void>>
---@field globals nil|table<string, string|number> table of globals to apply
---@field interface nil|table<string, fun(...):unknown> table of functions that provide an interface, nested in 'env' and 'extra'
local LuaJITStateParameters = {}

---Create a new LuaJIT state
---@param params LuaJITStateParameters|nil parameters for the new state.
---@see LuaJITStateParameters
---@return LuaJITState
function LuaJITState:new(params)
  local o = {}
  local params = params or {}
  o.interface = ProxyInterface:new(params.interface or {})
    
  setmetatable(o, self)
  self.__index = self

  o.name = string.format("%s", o)
  if params.name then
    o.name = params.name
  end

  o.L = createState()

  o.requireHandlers = {
    function(s, path)
      local err2
      local handle, err1 = io.open(string.format("ucp/modules/luajit/%s.lua", path))
      if not handle then
        handle, err2 = io.open(string.format("ucp/modules/luajit/%s/init.lua", path))
      end
    
      if not handle then
        error( string.format("%s\n%s", err1, err2))
      end
    
      log(VERBOSE, string.format("require: reading contents of: %s", handle))
      local contents = handle:read("*all")
      handle:close()
      log(VERBOSE, string.format("require: finished reading contents of: %s", handle))

      return contents
    end,
  }

  if params.requireHandler then
    table.insert(o.requireHandlers, 1, params.requireHandler)
  end

  o.loaded = {} -- contains the loaded modules

  ---TODO: improve this situation because it now doesn't realize if the same is loaded if the path is
  ---only slightly different, and clashes if modules that share state require the same file accidentally
  local loader = function(L)
    log(VERBOSE, string.format("VM: loader: lua_gettop() = %s", lua_gettop(L)))

    log(VERBOSE, "VM: loader: getting path string")
    local pPath = lua_tolstring(L, 1, 0)
    local path = core.readString(pPath)
    log(VERBOSE, string.format("loader(): %s", path))

    local contents = o.loaded[path] -- filled from the preloader() call
    log(VERBOSE, string.format("loader(): executing prefilled data (length: %d)", string.len(contents)))
    local returnValues = o:executeString(contents, path, false)

    log(VERBOSE, string.format("VM: loader: end: lua_gettop() = %s", lua_gettop(L)))
    return returnValues -- just return whatever the execute gave us
  end

  local pLoader = createLuaFunctionHook(loader)

  local preloader = function(L)
    log(VERBOSE, string.format("VM: preloader: lua_gettop() = %s", lua_gettop(L)))

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
        log(value.logLevel, value.message)
      end,
    },
  }

  setHookedGlobalFunction(o.L, "_SEND_EVENT", function(L)
    log(VERBOSE, string.format("VM: _SEND_EVENT: lua_gettop() = %s", lua_gettop(L)))

    local key = core.readString(lua_tolstring(L, 1, 0))
    local value = core.readString(lua_tolstring(L, 2, 0))

    log(VERBOSE, string.format("_SEND_EVENT(%s): %s", key, value:sub(1, 50)))
    local obj = serialization.deserialize(value)
    log(VERBOSE, string.format("_SEND_EVENT: deserialized obj"))

    if o.eventHandlers[key] ~= nil then
      log(VERBOSE, string.format("_SEND_EVENT: has handler"))
      for k, f in ipairs(o.eventHandlers[key]) do
        log(VERBOSE, string.format("receive(): firing function for: %s", key))
        local result, err_or_ret = pcall(f, key, obj)
        log(VERBOSE, string.format("receive(): fired function for: %s", key))
        if not result then 
          log(ERROR, err_or_ret)
        end
        log(VERBOSE, string.format("receive(): fired function for: %s succesfully", key))
      end
    else
      log(WARNING, string.format("No callbacks for %s", key))
    end

    return 0
  end)

  
  setHookedGlobalFunction(o.L, "_RINVOKE", function(L)
    log(VERBOSE, string.format("VM: _RINVOKE: lua_gettop() = %s", lua_gettop(L)))

    local funcName = core.readString(lua_tolstring(L, 1, 0))
    local serializedArgs = core.readString(lua_tolstring(L, 2, 0))

    log(VERBOSE, string.format("_RINVOKE(%s): %s", funcName, serializedArgs:sub(1, 50)))
    local deserializedArgs = serialization.deserialize(serializedArgs, false)
    log(VERBOSE, string.format("_RINVOKE: deserialized: %s", deserializedArgs))

    log(VERBOSE, string.format("_RINVOKE: resolving: %s", funcName))
    local f = o.interface:resolve(funcName)
    if f == nil then
      log(VERBOSE, string.format("_RINVOKE: resolving failed for: %s", funcName))
      lua_pushboolean(o.L, 0)
      local errString = core.CString(string.format("Function with name '%s' does not exist in interface", funcName))
      lua_pushstring(o.L, errString.address)
      return 2
    end

    log(VERBOSE, string.format("_RINVOKE: pcall: %s with n args: %s", f, #deserializedArgs))
    local results = table.pack(pcall(f, table.unpack(deserializedArgs)))
    log(VERBOSE, string.format("_RINVOKE: pcall: results count: %s", #results))
    local status = results[1]
    if status == false then
      log(VERBOSE, string.format("_RINVOKE: pcall: failed"))
      local err = results[2] or "error message is missing"
      local errMsg = string.format("Function with name '%s' failed: %s", tostring(funcName), tostring(err))
      log(VERBOSE, string.format("_RINVOKE: pcall: failed: reason:\n%s", errMsg))
      local errString = core.CString(errMsg)
      lua_pushboolean(o.L, 0)
      lua_pushstring(o.L, errString.address)
      return 2
    end

    log(VERBOSE, string.format("_RINVOKE: serializing results"))
    local serializedResults = serialization.serialize(select(2, table.unpack(results)))
    log(VERBOSE, string.format("_RINVOKE: serialized results: %s", serializedResults:sub(1, 50)))
    local pSerializedResults = core.CString(serializedResults)

    lua_pushboolean(o.L, 1)
    lua_pushstring(o.L, pSerializedResults.address)

    return 2
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
  o:executeFile("ucp/modules/luajit/common/compile.lua")

  log(VERBOSE, string.format("VM: new (end): lua_gettop() = %s", lua_gettop(o.L)))

  return o
end

--TODO: use lua_load with a lua_Reader to use the name of the path in error messages
-- local ptrLuaReader = core.allocateCode({0x90, 0x90, 0x90, 0x90, 0x90, 0xC3})
-- local sizeMapping = {}
-- core.hookCode(function(ptrL, pData, pSize)
--   log(VERBOSE, string.format("luaReader: %s, size: %s", pData, pSize))
--   local size = sizeMapping[pData]
--   if size ~= nil and size > 0 then
--     sizeMapping[pData] = size - size
--     core.writeInteger(pSize, size)
--     return pData
--   end
--   core.writeInteger(pSize, 0)
--   return 0
-- end, ptrLuaReader, 3, 0, 5)

---Execute a file (lua script) in the context of this state
---@param str string the script to execute
---@param path string|nil the path associated with the script. Is reported in case of errors
---@param cleanup boolean|nil whether to cleanup the lua stack (default)
---@param convert boolean|nil if cleanup, whether to return a serialized and deserialized return value (default)
---@return LuaJITState|number|nil returns depending on cleanup returns self, a lua object, or a number indicating how many stack values to return
function LuaJITState:executeString(str, path, cleanup, convert)
  local L = self.L
  log(VERBOSE, string.format("VM: executeString: lua_gettop() = %s", lua_gettop(L)))

  local path = path or str:sub(1, 20)

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

  -- stack: 
  local cleanstack = lua_gettop(L)  -- get the amount of values on the stack so we can exit cleanly

  if convert then
    local f = core.CString("_SERIALIZE")
    -- stack: 
    lua_getfield(L, LUA_GLOBALSINDEX, f.address)
    -- stack: [_SERIALIZE]
  end
  
  local stack = lua_gettop(L)  -- get the amount of values on the stack so we know the amount of returns

  
  -- stack: [_SERIALIZE]
  --TODO: use lua_load with a lua_Reader to use the name of the path in error messages
  -- sizeMapping[cstr.address] = str:len() + 1
  -- local pPath = core.CString(path)
  --Issue: fixme: Doesn't seem to work nice with the setGlobal() functionality
  -- local loadRet = lua_load(L, ptrLuaReader, cstr.address, pPath.address)
  local loadRet = luaL_loadstring(L, cstr.address)
  if loadRet ~= 0 then
    -- stack: [_SERIALIZE], error message
    log(WARNING, string.format(str))
    log(ERROR, string.format("Fail: %s", core.readString(lua_tolstring(L, -1, 0))))
    lua_settop(L, cleanstack) -- exit cleanly
    return 0
  end

  -- stack: [_SERIALIZE], string
  local ret = lua_pcall(L, 0, -1, 0)
  -- stack: [_SERIALIZE], return values ...

  if ret ~= 0 then
    -- stack: [_SERIALIZE], error message
    log(ERROR, string.format("Fail: %s", core.readString(lua_tolstring(L, -1, 0))))
    lua_settop(L, cleanstack) -- exit cleanly
    return 0
  end

  -- stack: [_SERIALIZE], return values ...
  local returns = lua_gettop(L) - stack

  log(VERBOSE, string.format("executed: %s, returned %s values", path, returns))

  if cleanup then
    if convert then
      if returns > 0 then
        -- Imagine returns was 2, then the _SERIALIZE is at -3
        -- local nargs = -1 * (returns + 1)

        log(VERBOSE, string.format("Serializing %s return values", returns))
        -- stack: [_SERIALIZE], return values ...
        local serRet = lua_pcall(L, returns, 1, 0) -- only allow 1 return value (the serialized object)
        
        if serRet ~= 0 then
          -- stack: errorMsg, 
          log(ERROR, string.format("Fail: Failed to serialize: %s", core.readString(lua_tolstring(L, -1, 0))))
          lua_settop(L, cleanstack)
          return nil
        end
        -- stack: serialized return values, 
        local result = core.readString(lua_tolstring(L, -1, 0))
        lua_settop(L, cleanstack)
        return serialization.deserialize(result)
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

function LuaJITState:compileFunction(name, signature, body)
  return self:invoke("_COMPILE_FUNCTION", name, signature, body)
end

function LuaJITState:compileFunctionFromFile(name, signature, path)
  local f, err = io.open(path, 'r')
  if f == nil then
    error(err)
  end
  local body = f:read("*all")
  f:close()

  return self:invoke("_COMPILE_FUNCTION", name, signature, body)
end

---Invoke a function with arguments
---@param funcName string the name of the function, should be global
---@param ... any arguments to the function
---@return any value the return values of the function
function LuaJITState:invoke(funcName, ...)
  log(VERBOSE, string.format("invoke(%s)", funcName))

  local args = {...}

  local L = self.L

  log(VERBOSE, string.format("VM: invoke: lua_gettop() = %s", lua_gettop(L)))

  local serializedArgs = serialization.serialize(args) -- todo: check if no arguments is correctly forwarded here!
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
  local result = serialization.deserialize(serializedRet, false)

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

  log(VERBOSE, string.format("VM: pinvoke: lua_gettop() = %s", lua_gettop(L)))

  local serializedArgs = serialization.serialize(args) -- todo: check if no arguments is correctly forwarded here!

  local funcStr = core.CString(funcName)
  local argsStr = core.CString(serializedArgs)

  local stack = lua_gettop(L)

  local invokeStr = core.CString("_PINVOKE")
  lua_getfield(L, LUA_GLOBALSINDEX, invokeStr.address)
  lua_pushstring(L, funcStr.address)
  lua_pushstring(L, argsStr.address)

  if lua_pcall(L, 2, 1, 0) ~= 0 then -- expect a single value
    -- Since this means an implementation error, we should reraise the error instead of feeding it to the caller
    local errorMsg = string.format("error in _PINVOKE(%s,): %s", funcName, core.readString(lua_tolstring(L, -1, 0)))
    log(ERROR, errorMsg)
    lua_settop(L, -2) -- pop one value (the error)
    error(errorMsg)
  end

  local result = serialization.deserialize(core.readString(lua_tolstring(L, -1, 0)), false)

  lua_settop(L, stack)

  return table.unpack(result) 
end

---Register require handler. When this state calls require(), this function will be invoked.
---@param func fun(self: LuaJITState, path: string): string
function LuaJITState:registerRequireHandler(func)
  table.insert(self.requireHandlers, 1, func)
end

---Trigger or send an event to the state
---@param key string
---@param obj any JSON serialize object to send to the state
function LuaJITState:sendEvent(key, obj)
  log(VERBOSE, string.format("sendEvent(): key = %s", key))

  local L = self.L

  log(VERBOSE, string.format("VM: sendEvent: lua_gettop() = %s", lua_gettop(L)))

  local value = serialization.serialize(obj)

  local keyStr = core.CString(key)
  local valueStr = core.CString(value)

  local stack = lua_gettop(L)

  lua_getfield(L, LUA_GLOBALSINDEX, p_RECEIVE_EVENT)
  lua_pushstring(L, keyStr.address)
  lua_pushstring(L, valueStr.address)

  if lua_pcall(L, 2, 0, 0) ~= 0 then
    log(ERROR, string.format("error in _RECEIVE_EVENT(): %s", core.readString(lua_tolstring(L, -1, 0))))
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

function LuaJITState:getLuaGetTop()
  return lua_gettop(self.L)
end

function LuaJITState:importHeaderString(str, path)
  local str = string.format("ffi.cdef([[\n%s\n]])", str)
  self:executeString(str, path)
end

function LuaJITState:importHeaderFile(path)
  local handle, err = io.open(path, 'r')
  if not handle then error(err) end
  local contents = handle:read("*all")
  self:importHeaderString(contents, path)
end

return LuaJITState