local test_require = require("tests/test-require")
for k, v in pairs(test_require) do
  log(VERBOSE, string.format("test: %s: starting", k))
  local status, msg = pcall(v)
  log(VERBOSE, string.format("test: %s: finished: %s (%s)", k, status, msg))
end