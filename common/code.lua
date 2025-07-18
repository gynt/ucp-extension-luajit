
-- ffi.cdef[[

-- typedef size_t SIZE_T;
-- typedef dword DWORD;
-- typedef void* LPVOID;
-- typedef dword* PDWORD;
-- typedef int BOOL;

-- BOOL VirtualProtect(
--   LPVOID lpAddress,
--   SIZE_T dwSize,
--   DWORD  flNewProtect,
--   PDWORD lpflOldProtect
-- );

-- ]]

function itob(i)
  return {
    [0] = bit.band(bit.rshift(i, 0), 0xFF),
    [1] = bit.band(bit.rshift(i, 8), 0xFF),
    [2] = bit.band(bit.rshift(i, 16), 0xFF),
    [3] = bit.band(bit.rshift(i, 24), 0xFF)
  }
end

-- local pOldProtect = ffi.new("DWORD[1]", {[0] = 0})
-- local pOldOldProtect = ffi.new("DWORD[1]", {[0] = 0})
-- local rweProtect = ffi.cast("DWORD", 0x40)

-- function writeCodeInteger(address, integer)
--   pOldProtect[0] = 0
--   pOldOldProtect[0] = 0

--   ffi.C.VirtualProtect(ffi.cast("void*", address), 4, rweProtect, pOldProtect)

--   local pT = ffi.cast("unsigned char *", address)
--   local v = itob(integer)
--   for i=0,3 do
--     pT[i] = v[i]
--   end

--   ffi.C.VirtualProtect(ffi.cast("void*", address), 4, pOldProtect[0], pOldOldProtect)
-- end


if _G._LUAJIT_REGISTRY == nil then
  _G._LUAJIT_REGISTRY = {}
end

-- Avoid garbage collection
function registerObject(obj)
  

  _G._LUAJIT_REGISTRY[obj] = true

  return obj
end

function deregisterObject(obj)

  if _G._LUAJIT_REGISTRY[obj] == true then
    _G._LUAJIT_REGISTRY[obj] = nil
  end
  
  return obj
end