function _COMPILE_FUNCTION(name, signature, body)
  log(VERBOSE, string.format("_COMPILE_FUNCTION: compiling '%s' with signature: '%s'", name, signature))

  -- Check against overrides
  local pName = string.format("p%s", name)
  if _G[name] ~= nil then
    error(string.format("an object with name '%s' has already been registered and can't be overridden", name))
  end

  if _G[pName] ~= nil then
    error(string.format("an object with pointer name '%s' was already been registered and can't be overridden", pName))
  end

  -- Body sanitization
  local body = body
  local firstword = body:match("[^%s(]+")
  if firstword ~= "return" then
    if firstword ~= "function" then
      error(string.format("invalid function body format: %s", body))
    end
    body = "return " .. body
  end

  -- Body compilation
  local compile,err = loadstring(body, name)
  if compile == nil then
    error(err)
  end

  local f = compile()

  -- Body assigning
  _G[name] = f

  -- Pointer assigning
  local p = ffi.cast(signature, _G[name])
  _G[pName] = p

  --- Return the pointer
  return tonumber(ffi.cast("unsigned long", p)), pName
end

_COMPILE_FUNCTION_TEST = _COMPILE_FUNCTION("_COMPILE_FUNCTION_TEST_FUNCTION1", "int (__stdcall *)(int a, int b, int c)", [[
  function (a, b, c)
    return (a - 100) + b * c
  end
]])

log(VERBOSE, string.format("_COMPILE_FUNCTION_TEST: 0x%X", _COMPILE_FUNCTION_TEST))