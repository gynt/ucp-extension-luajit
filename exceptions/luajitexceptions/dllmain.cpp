// dllmain.cpp : Defines the entry point for the DLL application.

#include "common.h"
#include <ucp3.hpp>
#include <lua.hpp>



BOOL APIENTRY DllMain( HMODULE hModule,
                       DWORD  ul_reason_for_call,
                       LPVOID lpReserved
                     )
{
    switch (ul_reason_for_call)
    {
    case DLL_PROCESS_ATTACH:
    case DLL_THREAD_ATTACH:
    case DLL_THREAD_DETACH:
    case DLL_PROCESS_DETACH:
        break;
    }
    return TRUE;
}


typedef int (*luajit_lua_CFunction) (void* L);
const char* (*luajit_lua_pushstring)(void* L, const char* s);
#define luajit_lua_pushliteral(L, s)	luajit_lua_pushstring(L, "" s)
int  (*luajit_lua_error)(void* L);

static int inner_wrap_exceptions(void* L, luajit_lua_CFunction f) {
    try {
        return f(L);  // Call wrapped function and return result.
    }
    catch (const char* s) {  // Catch and convert exceptions.
        luajit_lua_pushstring(L, s);
    }
    catch (std::exception& e) {
        luajit_lua_pushstring(L, e.what());
    }
    catch (...) {
        luajit_lua_pushliteral(L, "caught (...)");
    }
    return luajit_lua_error(L);  // Rethrow as a Lua error.
}

// Catch C++ exceptions and convert them to Lua error messages.
// Customize as needed for your own exception classes.
static int wrap_exceptions(void* L, luajit_lua_CFunction f)
{
    __try {
        return inner_wrap_exceptions(L, f);
    }
    __except (EXCEPTION_EXECUTE_HANDLER) {
        luajit_lua_pushliteral(L, "__except: low-level exception occurred");
        return luajit_lua_error(L);  // Rethrow as a Lua error.
    }

}

void  (*luajit_lua_pushlightuserdata)(void* L, void* p);
void  (*luajit_lua_settop)(void* L, int idx);
#define luajit_lua_pop(L,n)		luajit_lua_settop(L, -(n)-1)
int (*luaJIT_setmode)(void* L, int idx, int mode);
#define LUAJIT_MODE_WRAPCFUNC 0x10
#define LUAJIT_MODE_ON		0x0100

static int registerHandler(void* L)
{
    // Define wrapper function and enable it.
    luajit_lua_pushlightuserdata(L, (void*)wrap_exceptions);
    luaJIT_setmode(L, -1, LUAJIT_MODE_WRAPCFUNC | LUAJIT_MODE_ON);
    luajit_lua_pop(L, 1);

    return 0;
}

bool libraryLoaded = false;

static bool loadLibrary(std::string& errorMsg) {
    luajit_lua_pushstring = (const char* (*)(void* L, const char* s)) ucp_getProcAddressFromLibraryInModule("luajit", "lua51", "lua_pushstring", errorMsg);
    if (luajit_lua_pushstring == NULL) return false;

    luajit_lua_error = (int  (*)(void* L)) ucp_getProcAddressFromLibraryInModule("luajit", "lua51", "lua_error", errorMsg);
    if (luajit_lua_error == NULL) return false;

    luajit_lua_pushlightuserdata = (void  (*)(void* L, void* p)) ucp_getProcAddressFromLibraryInModule("luajit", "lua51", "lua_pushlightuserdata", errorMsg);
    if (luajit_lua_pushlightuserdata == NULL) return false;

    luajit_lua_settop = (void  (*)(void* L, int idx)) ucp_getProcAddressFromLibraryInModule("luajit", "lua51", "lua_settop", errorMsg);
    if (luajit_lua_settop == NULL) return false;

    luaJIT_setmode = (int (*)(void* L, int idx, int mode)) ucp_getProcAddressFromLibraryInModule("luajit", "lua51", "luaJIT_setmode", errorMsg);
    if (luaJIT_setmode == NULL) return false;

    libraryLoaded = true;
    return true;
}

extern "C" __declspec(dllexport) int luaopen_luajitexceptions(lua_State * L) {
    if (!libraryLoaded) {
        std::string errorMsg;
        bool loadResult = loadLibrary(errorMsg);
        if (!loadResult) {
            ucp_log(Verbosity_ERROR, errorMsg);
            return luaL_error(L, "could not load luajit dll: lua51.dll");
        }
    }

    lua_pushinteger(L, (DWORD) & registerHandler);
    return 1;
}