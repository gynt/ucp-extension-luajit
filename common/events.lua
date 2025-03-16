
json = _require("json/json")

_RECEIVERS = {}

_RECEIVE = function(key, value)
  local obj = json.decode(value)
  local a = _RECEIVERS[key] or {}
  for k, f in ipairs(a) do
    f(key, obj)
  end
end

_SEND = function(key, value)
  error("_SEND function wasn't overwritten by VM manager")
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