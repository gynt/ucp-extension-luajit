# ucp-extension-luajit
Provides luajit for ucp3

## Example
```lua

function prepare()
  log(VERBOSE, "prepare(): ")
end

function initial()
  log(VERBOSE, "initial(): ")
end

function frame()
  log(VERBOSE, "frame(): ")
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
  log(VERBOSE, value) -- is json.decoded, can be a table...
  log(VERBOSE, json.encode(value)) --
  events.send('pong', "well received!")
end)
```