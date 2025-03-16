
log(VERBOSE, string.format("%s", addr_0x0057bfc3))
log(VERBOSE, string.format("%s", addr_0x00613418))
DAT_MenuViewIDMenuMapping = ffi.cast("MenuIDMenuElementAddressPair*", addr_0x00613418)

newMenusList = ffi.new("MenuIDMenuElementAddressPair[100]", {[0] = {}})
log(VERBOSE, ffi.sizeof("MenuIDMenuElementAddressPair") * 51)

ffi.copy(newMenusList, DAT_MenuViewIDMenuMapping, ffi.sizeof("MenuIDMenuElementAddressPair") * 51)

log(VERBOSE, "newMenusList[50]", newMenusList[50].menuID)
log(VERBOSE, "newMenusList[50]", newMenusList[50].menuAddress)

for i=51,99 do
  newMenusList[i].menuID = -1 -- mark as end element for all empty entries
end

writeCodeInteger(addr_0x0057bfc3 + 1, tonumber(ffi.cast("unsigned int", newMenusList)))
