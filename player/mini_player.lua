return function(P, mod)
local Input=require('src.core.Input')
local Runtime=require('src.core.game3.runtime')
local Bag=require('src.core.game3.bag')
local Stack=require('src.ui.game3.stack')
local Game=require('src.core.Game3')
local Display=require('src.core.game3.display')
local font=assert(loadstring(assert(mod:read('pixel_font.lua'))))()
local pressed,down,step=Input.wasPressed,Input.isDown,Input.step
local blocked,releaseLatch={},{}
local buttons={'a','b','start','select','left','right','up','down','l','r'}
P.miniOpen=false; P.miniCursor=2
function P:miniAvailable(game)
  local s=game and game.session
  return game and game.phase~='boot' and s and s.registeredItem=='MP3_PLAYER'
    and s.bag and Bag.has(s.bag,'MP3_PLAYER',1)
end
function P:miniAction()
  if self.miniCursor==1 then self:next(-1)
  elseif self.miniCursor==3 then self:next(1)
  elseif self.source then self:pause()
  elseif self.queue and #self.queue>0 then self:play(self.queue,self.index or 1)
  elseif #self.tracks>0 then
    local pack=self.packs[1]
    for _,candidate in ipairs(self.packs) do if #candidate.tracks>0 then pack=candidate; break end end
    self:play(pack.tracks,1)
  end
end
-- Input is sampled once before field, menus AND battle input consumers. Mask
-- queries, not device state: closing never damages held-key/source bookkeeping.
Input.step=function(input,...)
  blocked={}
  step(input,...)
  local game=Runtime._game
  local eligible=P:miniAvailable(game)
  local wasOpen=P.miniOpen
  for key in pairs(releaseLatch) do
    if down(input,key) then blocked[key]=true else releaseLatch[key]=nil end
  end
  if not eligible then P.miniOpen=false
  elseif pressed(input,'select') and not blocked.select then
    P.miniOpen=not P.miniOpen; P.miniCursor=2
    if P.miniOpen and Stack.has(P.id) then P:close() end
  elseif P.miniOpen then
    if pressed(input,'b') or pressed(input,'start') then P.miniOpen=false
    elseif pressed(input,'left') then P.miniCursor=(P.miniCursor+1)%3+1
    elseif pressed(input,'right') then P.miniCursor=P.miniCursor%3+1
    elseif pressed(input,'a') then P:miniAction() end
  end
  if wasOpen or P.miniOpen then
    for _,key in ipairs(buttons) do
      blocked[key]=true
      if not P.miniOpen and down(input,key) then releaseLatch[key]=true end
    end
  end
end
Input.wasPressed=function(input,key)
  if blocked[key] then return false end
  return pressed(input,key)
end
Input.isDown=function(input,key)
  if blocked[key] then return false end
  return down(input,key)
end

local g=love.graphics
local function rect(x,y,w,h,c)
  g.setColor(c[1],c[2],c[3],1); g.rectangle('fill',x,y,w,h)
end
local cyan={.24,.92,.82}; local white={.92,.96,1}; local ink={.025,.045,.075}
local function label(s,x,y,c,size)
  g.setColor(c[1],c[2],c[3],1); font(size or 6):print(s,x,y)
end
local function fit(s,width)
  if font(6):getWidth(s)<=width then return s end
  while #s>0 and font(6):getWidth(s..'...')>width do s=s:sub(1,-2) end
  return s..'...'
end
function P:drawMini()
  if not self.miniOpen then return end
  g.push('all')
  rect(129,107,108,50,cyan); rect(130,108,106,48,ink)
  label('PULSE',134,111,cyan)
  label(self.paused and 'PAUSED' or self.playing and 'PLAYING' or 'READY',196,111,white)
  label(fit(self.error and 'AUDIO UNAVAILABLE' or self.track and self.track.title or (#self.tracks>0 and 'PRESS PLAY' or 'NO SOUNDTRACKS'),98),134,120,white)
  for i=1,3 do
    local x=134+(i-1)*33; local selected=i==self.miniCursor
    rect(x,130,30,15,selected and cyan or {.12,.18,.24})
    local c=selected and ink or white
    if i==2 and self.playing and not self.paused then
      rect(x+11,134,3,7,c); rect(x+17,134,3,7,c)
    else
      local direction=i==1 and -1 or 1
      for j=0,3 do rect(x+14+direction*j,134+j,1,7-2*j,c) end
      if i==1 then rect(x+9,134,2,7,c) elseif i==3 then rect(x+19,134,2,7,c) end
    end
  end
  label('L/R SELECT  A USE  B CLOSE',134,149,white)
  g.pop()
end
-- This HUD boundary runs after field, battle, and menu rendering, outside
-- the modal stack (which deliberately excludes ordinary menus in battles).
local drawHud=Game._drawHud
Game._drawHud=function(game,w,h)
  drawHud(game,w,h)
  if not P:miniAvailable(game) then P.miniOpen=false; return end
  if not P.miniOpen then return end
  local scale,x,y,_,_,scaleY=Display.fit(w,h)
  g.push('all'); g.translate(x,y); g.scale(scale,scaleY or scale)
  P:drawMini(); g.pop()
end
end
