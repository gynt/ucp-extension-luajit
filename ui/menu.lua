
Menu = {}

function Menu:createMenu(params)
  local o = {}

  if params.menuID == nil then
    error("no menu id")
  end

  o.menuID = params.menuID

  o.menu = ffi.new("Menu", {})
  o.menuView = ffi.new("struct MenuView", {})

  -- Adding the + 1 so the user doesn't need to know about the LAST_ENTRY
  o.menuItemsCount = (params.menuItemsCount + 1) or 100
  o.menuItemsIndex = 0

  o.menuItems = ffi.new(string.format("MenuItem[%s]", o.menuItemsCount), {[0] = {menuItemType = 0x66}})

  for i=0,(o.menuItemsCount-1) do
    o.menuItems[i].menuItemType = 0x66 -- LAST_ENTRY  
  end
  
  if params.pPrepare then
    o.pPrepare = params.pPrepare
  else
    o.prepare = params.prepare or function() end
    o.pPrepare = ffi.cast("cdeclVoidFunc *", o.prepare)
  end
  
  if params.pInitial then
    o.pInitial = params.pInitial
  else
    o.initial = params.initial or function() end
    o.pInitial = ffi.cast("cdeclVoidFunc *", o.initial)
  end
  
  if params.pFrame then
    o.pFrame = params.pFrame
  else
    o.frame = params.frame or function() end
    o.pFrame = ffi.cast("cdeclVoidFunc *", o.frame)
  end
  
  fMenu(o.menu, o.menuItems)
  fMenuView(o.menuView, o.menuID, o.pPrepare, o.pInitial, o.pFrame)

  o = setmetatable(o, self)

  self.__index = self

  return o
end

function Menu:addMenuItem(params)
  if self.menuItemsIndex >= self.menuItemsCount then
    error("reached menu item limit")
  end

  local menuItem = self.menuItemsIndex[self.menuItemsIndex]

  for k, v in pairs(params) do
    menuItem[k] = v
  end

  self.menuItemsIndex = self.menuItemsIndex + 1

  -- return self for chaining
  return self
end