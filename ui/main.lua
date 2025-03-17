
require("ui/headers")
require("ui/functions")
require("ui/changes")

require("ui/menu")


function prepare()
  log( VERBOSE, "prepare(): ")
end

-- PencilRenderCore* this
drawColorBox = ffi.cast("void (__thiscall *)(void *this,int left,int top,int right,int bottom, short color)", 0x00470e90)
drawColorBox_this = ffi.cast("void *", 0x0191d720)
pCOLOR_BLACK = ffi.cast("short *", 0x00df33d0)
function initial()
  log(VERBOSE, "initial(): ")
  drawColorBox(drawColorBox_this, 0, 0, 1280, 720, pCOLOR_BLACK[0])
end

function frame()
  
end

menu = Menu:createMenu({
  menuID = 99,
  menuItemsCount = 100,
  prepare = prepare,
  initial = initial,
  frame = frame,
})

mainMenuMenuItems = ffi.cast("MenuItem *", 0x005e81c8)
ffi.copy(menu.menuItems, mainMenuMenuItems, 99 * ffi.sizeof("MenuItem"))

events.receive('ping', function(key, value)
  events.send('pong', "well received!")
end)