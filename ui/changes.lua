DAT_MenuViewIDMenuMapping = ffi.cast("MenuIDMenuElementAddressPair*", addr_0x00613418)

newMenusList = ffi.new("MenuIDMenuElementAddressPair[100]", {[0] = {}})

ffi.copy(newMenusList, DAT_MenuViewIDMenuMapping, ffi.sizeof("MenuIDMenuElementAddressPair") * 51)

for i=51,99 do
  newMenusList[i].menuID = -1 -- mark as end element for all empty entries
end

writeCodeInteger(addr_0x0057bfc3 + 1, tonumber(ffi.cast("unsigned int", newMenusList)))
