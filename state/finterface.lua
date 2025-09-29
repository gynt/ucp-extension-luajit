---@class ProxyInterface
---@field env table
---@field extra table
local ProxyInterface = {}

---@class ProxyInterfaceOptions
---@field env table
---@field extra table
local ProxyInterfaceOptions = {}

---@param options ProxyInterfaceOptions
---@return ProxyInterface interface
function ProxyInterface:new(options)
  local o = {
    env = options.env or {},
    extra = options.extra or {},
  }

  o = setmetatable(o, self)
  self.__index = self

  return o
end

local function resolve(key, env)
  local env = env

  for str in string.gmatch(key, "([^.]+)") do
    if env == nil then
      return nil
    end

    env = env[str]
  end
  if type(env) ~= "function" then
    return nil
  end

  return env
end

function ProxyInterface:resolve(key)
  -- local global = resolve(key, _ENV)
  local env = resolve(key, self.env)
  local extra = resolve(key, self.extra)

  if env == nil and extra == nil then
    log(WARNING, string.format("ProxyInterface: cannot find function with key: %s", key))
    log(VERBOSE, json:encode(self.env))
    log(VERBOSE, json:encode(self.extra))
    return nil -- error(string.format("cannot find function with key: %s", key))  
  end
  
  if extra ~= nil then return extra end
  if env ~= nil then return env end
end

return ProxyInterface