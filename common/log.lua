--luajit: log.lua
local f = io.open("ucp/.cache/luajit.log", 'w')

if f == nil then
  f = io.open("ucp-luajit.log", 'w')
end


FATAL = -3
ERROR = -2
WARNING = -1
INFO = 0
DEBUG = 1
VERBOSE = 2

function log(logLevel, ...) 
  local args = {...}
  local msg = "VM: "
  for k, v in ipairs(args) do
    local vs = string.format("%s", v)
    msg = msg .. vs
  end
  msg = msg .. "\n"
  f:write(msg)
  f:flush()

  remote.events.send('log', {
    logLevel = logLevel,
    message = msg,
  })
end