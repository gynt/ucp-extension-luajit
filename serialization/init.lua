---Note: this function is also invoked in executeString() in state.lua
local function _SERIALIZE(...)
  local args = {...}

  local r
  if #args == 1 then
    r = json:encode(...)
  else
    r = json:encode(args)  
  end
  
  return r
end

local function _DESERIALIZE(obj, ...)
  local args = {...}
  if #args > 0 then
    error("_DESERIALIZE with more than 1 arg is deprecated")
  end

  return json:decode(obj)
end

return {
  serialize = _SERIALIZE,
  deserialize = _DESERIALIZE,
}