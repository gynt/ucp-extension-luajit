---Note: this function is also invoked in executeString() in state.lua
function _SERIALIZE(...)
  local args = {...}

  local r
  if #args == 1 then
    r = json:encode(...)
  else
    r = json:encode(args)  
  end
  
  return r
end

function _DESERIALIZE(obj, ...)
  local args = {...}
  if #args > 0 then
    error("_DESERIALIZE with more than 1 arg is deprecated")
  end

  return json:decode(obj)
end