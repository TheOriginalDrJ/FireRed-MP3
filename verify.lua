local Loader=require('src.mods.Loader')
local Manifest=require('src.mods.Manifest')
local loader=Loader.new({fs=love.filesystem,generation=3,version='firered'})
local function add(folder)
  local path=root..'/mods/'..folder
  local manifest=Manifest.validate(Json.decode(assert(read(path..'/manifest.json'))),path)
  local entry={manifest=manifest,path=path,enabled=true}
  loader.mods[manifest.id]=entry
  loader:_loadMod(entry)
  return entry
end
add('MP3Player')
local P=assert(loader.exports.mp3_player.player)
assert(#P.packs==0 and #P.tracks==0)
local canvas=love.graphics.newCanvas(720,480)
local logical=love.graphics.newCanvas(240,160)
logical:setFilter('nearest','nearest')
local function shot(name)
  -- Render at the game's actual logical resolution before enlarging, so
  -- screenshots do not overstate how much artwork detail is available in-game.
  love.graphics.setCanvas(logical); love.graphics.clear(); P:draw()
  love.graphics.setCanvas(canvas); love.graphics.clear(); love.graphics.setColor(1,1,1,1)
  love.graphics.draw(logical,0,0,0,3,3); love.graphics.setCanvas()
  love.filesystem.write(name,canvas:newImageData():encode('png'):getString())
end
local function key(k) P:handleInput({wasPressed=function(_,v) return v==k end}) end
P:show(game); shot('empty-player.png'); key('down'); assert(P.focus=='tabs')
key('right'); assert(P.screen=='now' and P.focus=='tabs')
key('right'); assert(P.screen=='settings' and P.focus=='tabs')
key('down'); assert(P.focus=='content'); shot('settings.png')
key('up'); assert(P.focus=='tabs'); key('left'); key('left')
key('select'); key('r'); assert(P.screen=='library' and P.focus=='tabs')
print('PASS arrow-key tab navigation, Down enters, Up returns, legacy tab shortcuts removed')
print('PASS standalone player opens without soundtracks through real loader/sandbox')
for _,id in ipairs({'sonic_advance_2','sonic_advance_3','pokemon_red_rescue_team','kingdom_hearts_com','pokemon_emerald'}) do
  local entry=add('Soundtrack-'..id)
  assert(entry.manifest.dependencySpecs[1].id=='mp3_player')
  assert(entry.manifest.dependencySpecs[1].range==nil)
  assert(#loader.errors==0)
end
assert(#P.packs==5 and #P.tracks==436)
assert(P.packIds.kingdom_hearts_com.tracks[6].title=='Dearly Beloved')
local isolated=Loader.new({fs=love.filesystem,generation=3,version='firered'})
local dependency=loader.mods.mp3_soundtrack_sonic_advance_2
local candidate={manifest=dependency.manifest,path=dependency.path,enabled=true}
isolated.mods[candidate.manifest.id]=candidate
isolated:_enforceDependencies(); assert(candidate.failed)
candidate.failed=nil; candidate.enabled=true
isolated.mods.mp3_player={manifest=loader.mods.mp3_player.manifest,enabled=false}
isolated:_enforceDependencies(); assert(candidate.failed)
print('PASS real loader blocks packs with missing or disabled player dependency')
for _,version in ipairs({'0.1.0','1.0.0','2.2.1','99.0.0'}) do
  candidate.failed=nil; candidate.enabled=true
  isolated.mods.mp3_player={manifest=Manifest.validate({id='mp3_player',name='Version fixture',version=version,entry='main.lua',api=2},'fixture'),enabled=true}
  isolated:_enforceDependencies(); assert(not candidate.failed,version)
end
print('PASS soundtrack dependency accepts all tested player versions')
print('PASS five independent packs register their own asset owners and all 436 tracks')
local owner=P.packs[1].owner
assert(not P:registerPack(owner,{id=P.packs[1].id}))
assert(not P:registerPack(owner,{id='invalid',name='Bad',icon='../escape.png',tracks={}}))
assert(#P.packs==5)
print('PASS duplicate and unsafe pack paths rejected without partial registration')
P:go('library'); P.cursor=4; shot('library.png'); key('a'); shot('album.png')
assert(P.selected.id=='sonic_advance_2')
key('down'); key('a'); assert(P.screen=='art'); shot('full-cartridge.png'); key('b')
key('a'); assert(P.playing and P.source:isPlaying()); shot('now-playing.png')
key('a'); assert(P.paused); key('a'); assert(not P.paused)
P:next(1); assert(P.index==2); P:next(-1); assert(P.index==1)
P.shuffle=true; P:next(1); assert(P.index~=1); P.shuffle=false
P.loopMode='single'; P:tickAudio(); assert(P.source:isLooping())
P.loopMode='off'; P:play(P.queue,#P.queue); P.source:stop(); P:tickAudio(); assert(not P.playing)
P.loopMode='playlist'; P:play(P.selected.tracks,#P.selected.tracks); P.source:stop(); P:tickAudio(); assert(P.index==1)
P:close(); P.source:stop(); require('src.core.game3.audio').update(1/60); assert(P.index==2)
print('PASS pause/resume, previous/next, shuffle, repeat-one/all/off, closed-menu advancement')
local missing={title='Missing test',file='missing.ogg',pack=P.packs[1]}
assert(not P:play({missing},1)); assert(P.error and not P.source and not P.playing)
P:show(game); P:go('now'); shot('missing-audio.png')
P.error=nil
for _,pack in ipairs(P.packs) do
  P.selected=pack; P:go('album'); shot(pack.id..'-album.png')
  assert(P:play(pack.tracks,1)); assert(P.source:isPlaying()); P:stop()
  for _,t in ipairs(pack.tracks) do assert(pack.owner.assets:info(t.file),'Missing '..t.file) end
end
print('PASS per-pack native audio decoding/playback and complete file resolution')
local Items=require('src.core.game3.items_data')
assert(Items.info('MP3_PLAYER').pocket=='KEY_ITEMS')
local stock=require('src.core.game3.marts').itemsFor(135707696)
local found=0; for _,id in ipairs(stock) do if id=='MP3_PLAYER' then found=found+1 end end
assert(found==1)
require('src.ui.game3.bag_chrome').iconImage('MP3_PLAYER')
print('PASS persistent item ID, Celadon stock and native bag icon')
P:play(P.packs[1].tracks,1); require('src.core.game3.audio').endSession(); assert(not P.source and not P.playing)
print('PASS session cleanup; native interface screenshots saved')
local Audio=require('src.core.game3.audio')
local sound=love.sound.newSoundData(44100,44100,16,1)
local function source(volume) local s=love.audio.newSource(sound,'static'); s:setVolume(volume); s:setLooping(true); s:play(); return s end
local bgm,fx,fanfare,cry=source(.7),source(.6),source(.5),source(.4)
Audio._bgmSource=bgm; Audio._seSources={fx,fanfare}; Audio._fanfareSource=fanfare; Audio._crySource=cry
assert(P:play(P.packs[1].tracks,1)); local mp3Volume=P.source:getVolume()
P:go('settings'); P.cursor=3; key('a')
assert(not P.gameMusic and bgm:getVolume()==0 and fanfare:getVolume()==0)
assert(math.abs(fx:getVolume()-.6)<.001 and P.source:getVolume()==mp3Volume)
P.cursor=4; key('a'); assert(not P.gameSfx and fx:getVolume()==0 and cry:getVolume()==0)
assert(fx:isPlaying() and fanfare:isPlaying() and cry:isPlaying(),'Muting stopped a timed source')
shot('settings-muted.png')
P.cursor=3; key('a'); assert(P.gameMusic and math.abs(bgm:getVolume()-.7)<.001 and math.abs(fanfare:getVolume()-.5)<.001)
assert(fx:getVolume()==0)
P.cursor=4; key('a'); assert(P.gameSfx and math.abs(fx:getVolume()-.6)<.001 and math.abs(cry:getVolume()-.4)<.001)
Audio._bgmSource=nil; Audio._seSources={}; Audio._fanfareSource=nil; Audio._crySource=nil
for _,s in ipairs({bgm,fx,fanfare,cry}) do s:stop(); s:release() end
P:stop()
print('PASS independent game music/fanfare and SFX/cry mute, exact volume restoration, MP3 unaffected and source timing retained')
P:close()
local Shop=require('src.ui.game3.shop_menu')
local Bag=require('src.core.game3.bag')
local Marts=require('src.core.game3.marts')
local Runtime=require('src.core.game3.runtime')
local function shopKey(k) Shop.handleInput({wasPressed=function(_,v) return v==k end}) end
local function listed(items)
  local n=0; for _,id in ipairs(items) do if id=='MP3_PLAYER' then n=n+1 end end; return n
end
local customer=require('src.core.game3.save_schema_firered').newGame({name='BUYER'})
customer.money=100000
game.session=customer; Runtime._game=game
local originalStock=Marts.itemsFor(135707696)
assert(listed(originalStock)==1)
Shop.show({session=customer,items=originalStock}); Shop.mode='buy'; Shop.cursor=#Shop._items
shopKey('a'); assert(Shop.mode=='buy_qty')
shopKey('up'); shopKey('right'); assert(Shop.qty==1)
shopKey('a'); assert(Shop.mode=='buy_confirm' and Shop.qty==1)
shopKey('a'); assert(customer.money==90200 and Bag.has(customer.bag,'MP3_PLAYER',1))
assert(not Bag.has(customer.bag,'MP3_PLAYER',2) and listed(Shop._items)==0)
assert(listed(originalStock)==1,'Shop mutated shared source stock')
assert(not Bag.add(customer.bag,'MP3_PLAYER',1) and not Bag.canAdd(customer.bag,'MP3_PLAYER',1))
shopKey('b'); assert(Shop.mode=='buy' and listed(Shop._items)==0)
Shop.close(); Shop.show({session=customer,items=originalStock}); assert(listed(Shop._items)==0); Shop.close()
assert(listed(Marts.itemsFor(135707696))==0)
local restored=Json.decode(Json.encode(customer))
Shop.show({session=restored,items=originalStock}); assert(listed(Shop._items)==0); Shop.close()
local fresh=require('src.core.game3.save_schema_firered').newGame({name='FRESH'})
assert(not Bag.add(fresh.bag,'MP3_PLAYER',2))
game.session=fresh
assert(listed(Marts.itemsFor(135707696))==1)
fresh.money=100000
Shop.show({session=fresh,items={80}}); Shop.mode='buy'; Shop.cursor=#Shop._items
shopKey('a'); shopKey('a'); shopKey('b')
assert(fresh.money==100000 and not Bag.has(fresh.bag,'MP3_PLAYER',1) and listed(Shop._items)==1)
Shop.close()
fresh.money=0
Shop.show({session=fresh,items=originalStock}); Shop.mode='buy'; Shop.cursor=#Shop._items; shopKey('a')
assert(not Bag.has(fresh.bag,'MP3_PLAYER',1) and listed(Shop._items)==1); Shop.close()
print('PASS native purchase charges once, quantity locked, immediate stock removal, reopen/save roundtrip, duplicate rejection, cancel/poor/new-save behavior')
local session=require('src.core.game3.save_schema_firered').newGame({name='VERIFY',start={map='FR_PALLET_TOWN',x=10,y=10}})
local Bag=require('src.core.game3.bag')
assert(Bag.add(session.bag,'MP3_PLAYER',1))
game:_enterField(session,'continue')
local input=game.input
local function press(button)
  input:reset(); input:step()
  input.pressQueue={button}; game:fixedUpdate(1/60)
end
session.registeredItem=nil; press('select'); assert(not P.miniOpen)
session.registeredItem='BICYCLE'; assert(not P:miniAvailable(game))
session.registeredItem='MP3_PLAYER'; press('select'); assert(P.miniOpen)
assert(not input:wasPressed('select') and not input:isDown('select'))
press('a'); assert(P.playing)
press('a'); assert(P.paused)
press('right'); assert(P.miniCursor==3); local index=P.index
press('a'); assert(P.index==index%#P.queue+1 and not P.paused)
press('left'); press('left'); assert(P.miniCursor==1); press('a'); assert(P.index==index)
local function nativeShot(name)
  game:draw()
  love.graphics.captureScreenshot(function(d) love.filesystem.write(name,d:encode('png'):getString()) end)
  love.graphics.present()
end
nativeShot('mini-field.png')
press('b'); assert(not P.miniOpen and not input:wasPressed('b') and not input:isDown('b'))
game:fixedUpdate(1/60); assert(not input:isDown('b'),'Closing held B leaked')
input:reset(); input:step(); assert(not P.miniOpen)
print('PASS registered-item-only SELECT, mini controls, input isolation and held-close suppression')
local Pokemon=require('src.core.game3.pokemon')
session.party={{species=6,level=50,moves={53,163,17,10},pp={15,20,35,35},ivs={hp=31,atk=31,def=31,spa=31,spd=31,spe=31},evs={},personality=1}}
Pokemon.applyStats(session.party[1]); session.party[1].hp=session.party[1].maxHp
assert(require('src.core.game3.battle_bridge').startWild(nil,game,{species=19,level=3}))
for i=1,180 do game:fixedUpdate(1/60); require('src.core.game3.audio').update(1/60) end
assert(require('src.core.game3.battle').isActive())
press('select'); assert(P.miniOpen)
press('a'); assert(P.paused)
press('right'); press('a'); assert(not P.paused)
assert(not input:wasPressed('a') and not input:isDown('a'))
nativeShot('mini-battle.png')
press('select'); assert(not P.miniOpen)
session.registeredItem=nil; press('select'); assert(not P.miniOpen)
print('PASS mini opens and controls audio in actual wild battle; unregistered SELECT remains native')
P:stop()
