"""Isolated real LuaJIT/LÖVE and Recomp loader verification; no player saves."""
import ctypes, json, os
from pathlib import Path

ROOT=Path(__file__).resolve().parent
import argparse
parser=argparse.ArgumentParser()
parser.add_argument('--engine', type=Path, required=True, help='Extracted engine inspection directory')
parser.add_argument('--runtime', type=Path, required=True, help='LÖVE directory containing lua51.dll and love.dll')
args=parser.parse_args()
ENGINE=args.engine.resolve()
RUNTIME=args.runtime.resolve()
(ROOT/'outputs').mkdir(exist_ok=True)
# Reuse the existing workspace's isolated native runtime bootstrap.
bootstrap=(ROOT/'runtime_bootstrap.lua').read_text()
bootstrap=bootstrap.replace('Sora isolated verification','MP3 isolated verification')
source='argRoot='+json.dumps(ROOT.as_posix())+';argEngineRoot='+json.dumps(ENGINE.as_posix())+';\n'+bootstrap+(ROOT/'verify.lua').read_text()
with os.add_dll_directory(str(RUNTIME)):
    lua=ctypes.CDLL(str(RUNTIME/'lua51.dll'))
    lua.luaL_newstate.restype=ctypes.c_void_p
    for name,args in [('luaL_openlibs',[ctypes.c_void_p]),('luaL_loadstring',[ctypes.c_void_p,ctypes.c_char_p]),('lua_pcall',[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int]),('lua_tolstring',[ctypes.c_void_p,ctypes.c_int,ctypes.c_void_p]),('lua_setfield',[ctypes.c_void_p,ctypes.c_int,ctypes.c_char_p]),('lua_close',[ctypes.c_void_p])]:
        getattr(lua,name).argtypes=args
    lua.lua_tolstring.restype=ctypes.c_char_p
    state=lua.luaL_newstate(); lua.luaL_openlibs(state)
    love=ctypes.CDLL(str(RUNTIME/'love.dll')); love.luaopen_love.argtypes=[ctypes.c_void_p]
    love.luaopen_love(state); lua.lua_setfield(state,-10002,b'love')
    try:
        result=lua.luaL_loadstring(state,source.encode())
        if result==0: result=lua.lua_pcall(state,0,0,0)
        if result: raise RuntimeError(lua.lua_tolstring(state,-1,None).decode('utf-8','replace'))
    finally: lua.lua_close(state)
