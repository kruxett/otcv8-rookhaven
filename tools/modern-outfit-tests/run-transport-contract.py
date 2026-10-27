"""Source-only transport check using the matching native engine LuaJIT DLL."""
from pathlib import Path
import argparse
import ctypes
import os

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--runtime', type=Path, required=True)
args = parser.parse_args()
runtime = args.runtime.resolve()
with os.add_dll_directory(str(runtime)):
    lua = ctypes.CDLL(str(runtime / 'lua51.dll'))
    lua.luaL_newstate.restype = ctypes.c_void_p
    lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
    lua.luaL_loadstring.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
    lua.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
    lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
    lua.lua_tolstring.restype = ctypes.c_char_p
    lua.lua_close.argtypes = [ctypes.c_void_p]
    state = lua.luaL_newstate()
    try:
        lua.luaL_openlibs(state)
        script = f'arg={{[[{(ROOT.parent / "Rookhaven").as_posix()}]],[[{ROOT.as_posix()}]]}}; dofile([[{(ROOT / "tools/modern-outfit-tests/shop-transport-contract.lua").as_posix()}]])'
        result = lua.luaL_loadstring(state, script.encode()) or lua.lua_pcall(state, 0, 0, 0)
        if result:
            raise AssertionError(lua.lua_tolstring(state, -1, None).decode())
    finally:
        lua.lua_close(state)
