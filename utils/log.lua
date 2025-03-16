local f = io.open("luajit.log", 'w')
function log(...) 
  local args = {...}
  for k, v in ipairs(args) do
    f:write(string.format("%s", v))
  end
  f:write("\n")
  f:flush()
end