_PINVOKE = function(funcName, serializedArgs)
    local f = _G[funcName]

    if _G[funcName] == nil then
        error(string.format("Function does not exist: %s", funcName))
    end

    if serializedArgs ~= nil then  -- todo: check if serializedArgs as an empty list is correctly forwarded
        local deserializedArgs = _DESERIALIZE(serializedArgs)
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
        local deserializedArgs = _DESERIALIZE(serializedArgs)
        return _SERIALIZE(f(unpack(deserializedArgs)))
    end

    return _SERIALIZE(f())
end