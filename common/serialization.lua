function _SERIALIZE(...)
  local args = {...}

  local r
  if #args == 1 then
    r = json.encode(...)
  else
    r = json.encode(args)  
  end
  
  return r
end

function _DESERIALIZE(...)
  local args = {...}
  if #args == 1 then
    return json.decode(...)
  end

  return json.decode(args)
end