function _SERIALIZE(...)
    local args = {...}

    local r
    if #args == 1 then
        r = json.encode(...)
    end

    r = json.encode(args)

    -- log(VERBOSE, string.format("_SERIALIZE(%s)", r))

    return r
end

function _DESERIALIZE(...)
    local args = {...}
    if #args == 1 then
      -- log(VERBOSE, string.format("_DESERIALIZE(%s)", args[1]))
      return json.decode(...)
    end

    -- log(VERBOSE, string.format("_DESERIALIZE(%s)", args))
    return json.decode(args)
end