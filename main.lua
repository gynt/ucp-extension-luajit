-- This code is running in luajit

if _G._require == nil then
  _require = require
end

_require("common/events")
_require("common/packages")
_require("utils/log")
_require("utils/code")

_require("ui/headers")
_require("ui/functions")
_require("ui/changes")

_require("ui/menu")

function prepare()
  log("prepare(): ")
end

function initial()
  log("initial(): ")
end

function frame()
  log("frame(): ")
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

events.receive('test', function(key, value)
  log("test!")
  log(value)
  log(json.encode(value))
end) 