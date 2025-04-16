_PINVOKE = function(funcName, serializedArgs)
    local f = _G[funcName]

    if _G[funcName] == nil then
        error(string.format("Function does not exist: %s", funcName))
    end

    if serializedArgs ~= nil then  -- todo: check if serializedArgs as an empty list is correctly forwarded
        local deserializedArgs = _DESERIALIZE(serializedArgs, false)
        return _SERIALIZE(pcall(f, unpack(deserializedArgs)))
    end

    return _SERIALIZE(pcall(f))
end

_INVOKE = function(funcName, serializedArgs)
    local f = _G[funcName]

    if _G[funcName] == nil then
        error(string.format("Function does not exist: %s", funcName))
    end

    if serializedArgs ~= nil then  -- todo: check if serializedArgs as an empty list is correctly forwarded
        local deserializedArgs = _DESERIALIZE(serializedArgs, false)
        return _SERIALIZE(f(unpack(deserializedArgs)))
    end

    return _SERIALIZE(f())
end

if _RINVOKE == nil then
  _RINVOKE = function(funcName, serializedArgs)
    error("this function should have been substituted by the VM manager")
  end  
end

if remote == nil then remote = {} end

remote.invoke = function(funcName, ...)
  local serializedArgs = _SERIALIZE(...)
  local status, serializedResult = _RINVOKE(funcName, serializedArgs)
  if status ~= true then
    error(serializedResult)
  end

  return _DESERIALIZE(serializedResult)
end


function _CREATE_RF_INTERFACE(key)
  return setmetatable({}, {
    __index = function(self, k)
      if key == nil then
        return _CREATE_RF_INTERFACE(k)
      end

      return _CREATE_RF_INTERFACE(string.format("%s.%s", key, k))
    end,
    __call = function(self, ...)
      return remote.invoke(key, ...)
    end,
    __newindex = function(self, key, value)
      error('illegal')
    end,
  })
end

remote.interface = _CREATE_RF_INTERFACE()