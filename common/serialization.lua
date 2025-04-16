---luajit: serialization.lua

---Note: this function is also invoked in executeString() in state.lua

---Serialize its arguments to a JSON string
---Arguments are always wrapped into a table
---Note: this function is also invoked in executeString() in state.lua
---@return string serialized
function _SERIALIZE(...)
  local args = {...}

  return json:encode(args)
end

---Deserialize the argument 'obj'
---Unpack the results
---@param obj unknown
---@return ... values
function _DESERIALIZE(obj, packing)
  if packing == nil then
    packing = true
  end
  if packing then
    return unpack(json:decode(obj))  
  else
    return json:decode(obj)
  end
end