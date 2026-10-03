return function(mod)
local Audio = require('src.core.game3.audio')
local Stack = require('src.ui.game3.stack')
local P = {id='mp3_player', packs={}, packIds={}, tracks={}, loopMode='playlist', shuffle=false,
  playing=false, paused=false, cursor=1, elapsed=0, screen='library'}

local function safePath(path)
  return type(path)=='string' and path~='' and not path:find('..',1,true)
    and not path:find('[:\\]') and path:sub(1,1)~='/'
end
function P:registerPack(owner, data)
  if type(data)~='table' or type(data.id)~='string' or self.packIds[data.id] then return false,'Duplicate/invalid soundtrack' end
  if type(data.name)~='string' or type(data.tracks)~='table' or not safePath(data.icon) then return false,'Invalid soundtrack metadata' end
  local pack={id=data.id,name=data.name,icon=data.icon,bounds=data.bounds,owner=owner,tracks={}}
  local ids={}
  for _,row in ipairs(data.tracks) do
    if type(row)~='table' or type(row.id)~='string' or ids[row.id] or type(row.title)~='string' or not safePath(row.file) then return false,'Invalid song metadata' end
    ids[row.id]=true
    pack.tracks[#pack.tracks+1]={id=data.id..':'..row.id,title=row.title,file=row.file,duration=row.duration,pack=pack}
  end
  self.packIds[data.id]=pack; self.packs[#self.packs+1]=pack
  table.sort(self.packs,function(a,b) return a.name<b.name end)
  for _,t in ipairs(pack.tracks) do self.tracks[#self.tracks+1]=t end
  return true
end
local function release()
  if P.source then pcall(P.source.stop,P.source); pcall(P.source.release,P.source); P.source=nil end
end
function P:stop()
  self.playing=false; self.paused=false; release()
  pcall(Audio.resumeBgm); pcall(Audio.restoreMapSong)
end
function P:play(queue,index)
  local track=queue and queue[index]; if not track then return false end
  release(); self.queue=queue; self.index=index; self.track=track; self.paused=false; self.error=nil
  local assets=track.pack.owner.assets
  local ok,source=pcall(function()
    assert(assets:info(track.file),'Missing audio')
    local s=love.audio.newSource(assets:path(track.file),'stream')
    self.source=s
    s:setLooping(self.loopMode=='single'); s:setVolume(Audio._bgmVolume or 1); s:play()
    return s
  end)
  if not ok then self:stop(); self.error='Cannot play: '..track.title; return false end
  self.source=source; self.playing=true; pcall(Audio.pauseBgm); return true
end
function P:next(delta)
  if not self.queue or #self.queue==0 then return end
  local i=((self.index or 1)-1+delta)%#self.queue+1
  if self.shuffle and #self.queue>1 then
    i=math.random(#self.queue-1); if i>=self.index then i=i+1 end
  end
  self:play(self.queue,i)
end
function P:pause()
  if not self.source then return end
  if self.paused then self.source:play() else self.source:pause() end
  self.paused=not self.paused
end
function P:tickAudio()
  if self.source and self.playing and not self.paused and not self.source:isPlaying() then
    if self.loopMode=='single' then self:play(self.queue,self.index)
    elseif self.index<#self.queue or self.loopMode=='playlist' then self:next(1)
    else self:stop() end
  end
  if self.playing then
    Audio.pauseBgm()
    self.source:setVolume(Audio._bgmVolume or 1); self.source:setLooping(self.loopMode=='single')
  end
end
function P:go(screen,focus)
  self.screen=screen; self.cursor=1; self.elapsed=0; self.focus=focus or 'content'
end
function P:rows()
  if self.screen=='library' then
    local rows={}
    for _,pack in ipairs(self.packs) do
      local p=pack
      rows[#rows+1]={label=p.name,pack=p,action=function() self.selected=p; self:go('album') end}
    end
    return rows
  elseif self.screen=='album' then
    local rows={{label='Play album',action=function() self:play(self.selected.tracks,1); self:go('now') end},
      {label='View full cartridge',action=function() self:go('art') end}}
    for i,t in ipairs(self.selected.tracks) do
      local index=i
      rows[#rows+1]={label=t.title,action=function() self:play(self.selected.tracks,index); self:go('now') end}
    end
    return rows
  elseif self.screen=='now' then
    return {
      {label=self.paused and 'Resume' or 'Pause',action=function() self:pause() end},
      {label='Previous song',action=function() self:next(-1) end},
      {label='Next song',action=function() self:next(1) end},
      {label='Stop / restore game music',action=function() self:stop() end},
    }
  else
    return {
      {label='Shuffle: '..(self.shuffle and 'ON' or 'OFF'),action=function() self.shuffle=not self.shuffle end},
      {label='Repeat: '..self.loopMode,action=function() self.loopMode=self.loopMode=='playlist' and 'single' or self.loopMode=='single' and 'off' or 'playlist' end},
      {label='Game music: '..(self.gameMusic and 'ON' or 'OFF'),action=function() self.gameMusic=not self.gameMusic; self:applyGameAudio() end},
      {label='Game SFX: '..(self.gameSfx and 'ON' or 'OFF'),action=function() self.gameSfx=not self.gameSfx; self:applyGameAudio() end},
      {label='Stop / restore game music',action=function() self:stop() end},
    }
  end
end
function P:show(game)
  self.game=game; self.error=nil; self:go('library','tabs')
  self.layer=self.layer or {draw=function() self:draw() end,update=function(dt) self:update(dt) end,
    handleInput=function(input) self:handleInput(input) end}
  Stack.push(self.id,self.layer,{hideBelow=true,fullscreen=true})
end
function P:close() Stack.pop(self.id) end
function P:update(dt) self.elapsed=self.elapsed+(dt or 0) end
function P:handleInput(input)
  if not input then return end
  if input:wasPressed('start') then self:close(); return end
  if self.screen=='art' then
    if input:wasPressed('a') or input:wasPressed('b') then self:go('album') end
    return
  end
  if input:wasPressed('b') then
    if self.focus=='tabs' then self:close()
    elseif self.screen=='album' then self:go('library')
    else self.focus='tabs' end
    return
  end
  local rows=self:rows(); local count=#rows
  if self.focus=='tabs' then
    local tabs={'library','now','settings'}
    local tab=self.screen=='now' and 2 or self.screen=='settings' and 3 or 1
    local direction=input:wasPressed('left') and -1 or input:wasPressed('right') and 1 or 0
    if direction~=0 then self:go(tabs[(tab-1+direction)%3+1],'tabs')
    elseif (input:wasPressed('down') or input:wasPressed('a')) and count>0 then self.focus='content'; self.cursor=1 end
    return
  end
  if input:wasPressed('up') and self.cursor==1 then self.focus='tabs'; return end
  if count==0 then return end
  local delta=input:wasPressed('up') and -1 or input:wasPressed('down') and 1
    or self.screen=='album' and input:wasPressed('left') and -4 or self.screen=='album' and input:wasPressed('right') and 4 or 0
  if delta~=0 then self.cursor=math.max(1,math.min(count,self.cursor+delta)); self.elapsed=0 end
  if input:wasPressed('a') then rows[self.cursor].action() end
end

-- All coordinates use the game's 240x160 logical canvas. No native Pokemon windows.
local g=love.graphics
local C={bg={.025,.045,.075},panel={.055,.09,.135},line={.14,.21,.28},cyan={.24,.92,.82},
  white={.92,.96,1},muted={.48,.61,.70},ink={.025,.09,.11},orange={1,.63,.30}}
local font=assert(loadstring(assert(mod:read('pixel_font.lua'))))()
local function color(c) g.setColor(c[1],c[2],c[3],1) end
local function box(x,y,w,h,c,r) color(c); g.rectangle('fill',x,y,w,h,r or 0,r or 0) end
local function text(s,x,y,size,c) color(c or C.white); font(size or 7):print(tostring(s or ''),x,y) end
local function clipped(s,x,y,width,size,c,scroll)
  s=tostring(s or ''); local f=font(size); local w=f:getWidth(s)
  local offset=math.floor(scroll and w>width and math.min(w-width+5,math.max(0,(P.elapsed-1.2)*18)%(w-width+35)) or 0)
  -- Scissors are screen-space in LÖVE; transform to respect the host canvas scale.
  local ox,oy,ow,oh=g.getScissor()
  local sx,sy=g.transformPoint(x,y); local ex,ey=g.transformPoint(x+width,y+size+3)
  g.setScissor(sx,sy,ex-sx,ey-sy); text(s,x-offset,y,size,c); g.setScissor(ox,oy,ow,oh)
end
local function artwork(pack,x,y,w,h)
  if not pack then
    box(x+w/2-18,y+h/2-12,36,24,C.line,3); text('MP3',x+w/2-12,y+h/2-5,10,C.cyan); return
  end
  if not pack.image and not pack.artFailed then
    local ok,im=pcall(pack.owner.assets.image,pack.owner.assets,pack.icon)
    if ok then
      pack.image=im; im:setFilter('nearest','nearest')
      local iw,ih=im:getDimensions(); local b=pack.bounds or {0,0,iw,ih}
      pack.artW=b[3]-b[1]; pack.artH=b[4]-b[2]
      pack.quad=g.newQuad(b[1],b[2],pack.artW,pack.artH,iw,ih)
    else pack.artFailed=true end
  end
  if pack.image then
    local s=math.min(w/pack.artW,h/pack.artH)
    -- Keep the cartridge anchored to the logical pixel grid. Linear texture
    -- filtering softened the label before the game's canvas was enlarged.
    local px=math.floor(x+(w-pack.artW*s)/2+0.5)
    local py=math.floor(y+(h-pack.artH*s)/2+0.5)
    g.setColor(1,1,1,1); g.draw(pack.image,pack.quad,px,py,0,s,s)
  else text('No artwork',x+8,y+h/2,7,C.muted) end
end
local function time(v) v=math.max(0,v or 0); return string.format('%d:%02d',math.floor(v/60),math.floor(v%60)) end
function P:draw()
  if not g then return end
  g.push('all')
  box(0,0,240,160,C.bg); box(0,0,3,160,C.cyan)
  text('PULSE',10,5,11,C.white); text('MP3',75,10,6,C.cyan)
  text(self.playing and (self.paused and 'PAUSED' or 'PLAYING') or 'STANDBY',190,8,6,C.muted)
  if self.screen=='art' then
    clipped(self.selected.name,10,23,220,8,C.cyan,true)
    artwork(self.selected,10,39,220,101)
    text('A / B Back to album     START Close',10,150,6,C.muted)
    g.pop(); return
  end
  local tabs={{'library','LIBRARY'},{'now','PLAYING'},{'settings','SETTINGS'}}
  for i,t in ipairs(tabs) do
    local active=self.screen==t[1] or self.screen=='album' and i==1
    local focused=active and self.focus=='tabs'
    if focused then box(8+(i-1)*76,20,72,12,C.cyan,2) end
    text(t[2],10+(i-1)*76,23,7,focused and C.ink or active and C.cyan or C.muted)
    if active then box(10+(i-1)*76,34,64,1,C.cyan) end
  end
  local rows=self:rows()
  local pack=self.screen=='library' and rows[self.cursor] and rows[self.cursor].pack
    or self.screen=='album' and self.selected or self.track and self.track.pack
  box(9,41,100,75,C.panel,4)
  artwork(pack,13,47,92,62)
  clipped(pack and pack.name or 'YOUR MUSIC. YOUR MIX.',10,120,100,7,C.white,true)
  text(pack and #pack.tracks..' SONGS' or 'NO PACKS INSTALLED',10,132,6,C.muted)
  if self.screen=='now' then
    clipped(self.track and self.track.title or 'Nothing playing',117,41,114,8,C.cyan,true)
    local pos=self.source and self.source:tell() or 0
    local dur=self.track and self.track.duration or 0
    box(117,57,113,2,C.line); box(117,57,113*math.min(1,dur>0 and pos/dur or 0),2,C.cyan)
    text(time(pos)..' / '..time(dur),117,62,6,C.muted)
  else
    text(self.screen=='album' and 'ALBUM / SONGS' or self.screen=='settings' and 'PLAYBACK' or 'CARTRIDGE COLLECTION',117,42,6,C.muted)
  end
  local y=self.screen=='now' and 76 or 56
  local shown=self.screen=='now' and 4 or 5
  local first=math.max(1,self.cursor-shown+1)
  for i=first,math.min(#rows,first+shown-1) do
    local yy=y+(i-first)*15; local selected=i==self.cursor and self.focus~='tabs'
    if selected then box(115,yy-1,117,14,C.cyan,2) end
    clipped(rows[i].label,119,yy+1,109,7,selected and C.ink or C.white,selected)
  end
  if #rows==0 then
    text('Import a soundtrack',117,61,7,C.white)
    text('mod, enable it, then',117,74,7,C.muted)
    text('restart the game.',117,87,7,C.muted)
  elseif self.screen~='now' then text(self.cursor..' / '..#rows,202,134,6,C.muted) end
  if self.error then box(6,118,230,25,C.panel,3); clipped(self.error,10,124,222,7,C.orange,true) end
  box(6,146,230,1,C.line)
  text(self.focus=='tabs' and 'LEFT/RIGHT Tabs   DOWN Enter   B Close' or 'UP/DOWN Choose   A Use   UP at top: Tabs',10,150,6,C.muted)
  g.pop()
end
local update=Audio.update
if update then Audio.update=function(dt) update(dt); P:tickAudio() end end
local song=Audio.playSong
if song then Audio.playSong=function(...) local r=song(...); if P.playing then Audio.pauseBgm() end; return r end end
local endSession=Audio.endSession
if endSession then Audio.endSession=function(...) P.miniOpen=false; P.playing=false; P.paused=false; release(); return endSession(...) end end
assert(loadstring(assert(mod:read('mini_player.lua'))))()(P,mod)
assert(loadstring(assert(mod:read('game_audio.lua'))))()(P)
return P
end
