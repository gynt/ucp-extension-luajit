
DAT_MenuViewIDMenuMapping = ffi.cast("MenuIDMenuElementAddressPair*", 0x00613418)

newMenusList = ffi.new("MenuIDMenuElementAddressPair[100]", {[0] = {}})
log(ffi.sizeof("MenuIDMenuElementAddressPair") * 51)
ffi.copy(newMenusList, DAT_MenuViewIDMenuMapping, ffi.sizeof("MenuIDMenuElementAddressPair") * 51)

log("newMenusList[50]", newMenusList[50].menuID)
log("newMenusList[50]", newMenusList[50].menuAddress)

for i=51,99 do
  newMenusList[i].menuID = -1 -- mark as end element for all empty entries
end

writeCodeInteger(0x0057bfc3 + 1, tonumber(ffi.cast("unsigned int", newMenusList)))
