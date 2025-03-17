
_RECEIVERS = {
  ['functions.AOBExtract.reply'] = {
    function(key, value)
      AOBExtract_reply = value
    end,
  }
}

_RECEIVE = function(key, value)
  local obj = json.decode(value)
  local a = _RECEIVERS[key]

  if a ~=  nil then
    for k, f in ipairs(a) do
      local result, err = pcall(f, key, obj)
      if not result then
        log(ERROR, err)
      end
    end  
  else
    log(WARNING, string.format("receive(): unknown key: %s", key))
  end

end

if _SEND == nil then
  _SEND = function(key, value)
    error("_SEND function wasn't overwritten by VM manager")
  end
end

events = {
  receive = function(key, func)
    if _RECEIVERS[key] == nil then
      _RECEIVERS[key] = {}
    end
    table.insert(_RECEIVERS[key], func)
  end,

  send = function(key, value)
    _SEND(key, json.encode(value))
  end,
}
