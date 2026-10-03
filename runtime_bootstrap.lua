-- Isolated native engine run; existing generated game cache is READ ONLY.
local root, engine = argRoot, argEngineRoot
local old = engine:match('^(.*)/inspection$')
assert(old, 'Expected inspection engine directory')
local cache = old .. '/work/firered-cache/'
package.path = engine .. '/?.lua;' .. old .. '/tests/underground-native/?.lua;' .. package.path
package.loaded.love = love
for _, name in ipairs({'data','image','filesystem','system','timer','math','window','font','graphics','event','keyboard','joystick','sound','audio'}) do require('love.' .. name) end
local function read(path)
  local f=io.open(path,'rb'); if not f then return nil end
  local bytes=f:read('*a'); f:close(); return bytes
end
local function resolve(path)
  if path:match('^%a:/') then return path end
  for _, base in ipairs({cache, engine..'/', old..'/tests/underground-native/'}) do
    if read(base..path) then return base..path end
  end
  return cache..path
end
love.filesystem.read=function(path) return read(resolve(path)) end
love.filesystem.getInfo=function(path) local b=read(resolve(path)); return b and {type='file',size=#b} or nil end
love.filesystem.load=function(path) return loadstring(assert(love.filesystem.read(path)),path) end
love.filesystem.write=function(path, bytes)
  assert(not path:find('..',1,true) and not path:find('[/:\\]'), 'Unexpected test write '..path)
  local f=assert(io.open(root..'/outputs/'..path,'wb')); f:write(bytes); f:close(); return true
end
love.filesystem.createDirectory=function() return true end
love.filesystem.getSaveDirectory=function() return root..'/outputs' end
love.filesystem.getSource=function() return engine end
love.filesystem.getSourceBaseDirectory=love.filesystem.getSource
love.filesystem.getRealDirectory=love.filesystem.getSource
love.filesystem.isFused=function() return false end
love.filesystem.getDirectoryItems=function() return {} end
assert(love.window.setMode(720,480,{x=-10000,y=-10000,vsync=0}))
love.window.setTitle('MP3 isolated verification')
local ffi=require('ffi')
ffi.cdef('void *FindWindowA(const char*, const char*); int ShowWindow(void*, int);')
local hwnd=ffi.C.FindWindowA(nil,'MP3 isolated verification'); if hwnd~=nil then ffi.C.ShowWindow(hwnd,0) end
for _, entry in ipairs({{love.graphics,'newImage'},{love.graphics,'newFont'},{love.image,'newImageData'},{love.audio,'newSource'}}) do
  local obj,key=entry[1],entry[2]; local native=obj[key]
  obj[key]=function(p,...) if type(p)=='string' then p=love.filesystem.newFileData(assert(love.filesystem.read(p),'Missing '..p),p) end; return native(p,...) end
end
require('src.core.GameVersion').set('firered')
package.loaded['src.import.CacheFs']={readActive=function(p) return read(cache..p) end,
  read=function(p) return read(cache..p) end, write=function() return false end,
  exists=function(p) return read(cache..p)~=nil end}
local Dataset=require('src.core.game3.dataset'); Dataset.cacheRootOverride=cache..'data/generated/gba'
local game=require('src.core.Game3').new(); Dataset.hydrate(game); game.input:init()
game.options={}
game.saveGame=function() error('No player save writes permitted') end
local Json=require('src.link.Json')
game.writeOptions=function() love.filesystem.write('native-options.json',Json.encode(game.options)) end
