local test_require = {}

function test_require.test_require()
  local a = require("tests/test-require-target")
  table.insert(a.array, 1)
  if a.array[1] ~= 0 then error(string.format("%s not equal to %s", a.array[1], 0)) end
  local b = require("tests/test-require-target")
  b.array[2] = 2
  if a.array[2] ~= 2 then error(string.format("%s not equal to %s", a.array[2], 2)) end
end


return test_require