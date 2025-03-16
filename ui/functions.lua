
fMenu = ffi.cast("Menu * (__thiscall *)(Menu *this, MenuItem *menuItemArrayAddress)", 0x004f4100)
fMenuView = ffi.cast([[
  struct MenuView * 
  (__thiscall *)
  (
    struct MenuView * this, 
    MenuViewType menuID,
    pCdeclVoidFunc prepareMenuView, 
    pCdeclVoidFunc doInitial,
    pCdeclVoidFunc doEveryFrame
  )
]], 0x004f4020)