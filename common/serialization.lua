function _SERIALIZE(...)
    local args = {...}
    if #args == 1 then
        return json.encode(args[1])
    end

    return json.encode(args)
end

function _DESERIALIZE(...)
    local args = {...}
    if #args == 1 then
        return json.decode(args[1])
    end

    return json.decode(args)
end