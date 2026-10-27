"""Run source preview contracts and load current Lua with matching engine LuaJIT."""
from pathlib import Path
import argparse, ctypes, os

ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--runtime',type=Path,required=True);a=p.parse_args()
with os.add_dll_directory(str(a.runtime.resolve())):
    lua=ctypes.CDLL(str(a.runtime.resolve()/'lua51.dll'))
    lua.luaL_newstate.restype=ctypes.c_void_p
    lua.luaL_openlibs.argtypes=[ctypes.c_void_p]
    lua.luaL_loadstring.argtypes=[ctypes.c_void_p,ctypes.c_char_p]
    lua.lua_pcall.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int]
    lua.lua_tolstring.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_void_p]
    lua.lua_tolstring.restype=ctypes.c_char_p
    lua.lua_close.argtypes=[ctypes.c_void_p]
    state=lua.luaL_newstate()
    try:
        lua.luaL_openlibs(state)
        outfit=(ROOT/'modules/game_outfit/outfit.lua').as_posix()
        contract=(ROOT/'tools/modern-outfit-tests/tryon-contract.lua').as_posix()
        files=[ROOT/'modules/game_shop/shop.lua',ROOT/'tools/modern-outfit-tests/shop-visual.lua',ROOT/'tools/modern-outfit-tests/shop-server.lua']
        source=';'.join('assert(loadfile([['+f.as_posix()+']]))' for f in files)
        source+='; arg={[[%s]]}; dofile([[%s]])'%(outfit,contract)
        result=lua.luaL_loadstring(state,source.encode()) or lua.lua_pcall(state,0,0,0)
        if result:raise AssertionError(lua.lua_tolstring(state,-1,None).decode())
    finally:lua.lua_close(state)
