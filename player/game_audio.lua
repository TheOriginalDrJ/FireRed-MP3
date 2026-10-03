return function(P)
local Audio=require('src.core.game3.audio')
P.gameMusic=true; P.gameSfx=true
-- Silence native sources without skipping playback, fanfare/cry timers or
-- completion callbacks. Do not change master volume or the MP3 stream.
local muted=setmetatable({},{__mode='k'})
local function apply(source,off)
  if not source then return end
  if off then
    local volume=source:getVolume()
    if muted[source]==nil or volume>0 then muted[source]=volume end
    source:setVolume(0)
  elseif muted[source]~=nil then
    source:setVolume(muted[source]); muted[source]=nil
  end
end
function P:applyGameAudio()
  apply(Audio._bgmSource,not self.gameMusic)
  apply(Audio._fanfareSource,not self.gameMusic)
  apply(Audio._crySource,not self.gameSfx)
  for _,source in ipairs(Audio._seSources or {}) do
    if source~=Audio._fanfareSource then apply(source,not self.gameSfx) end
  end
end
for _,name in ipairs({'playSong','resumeBgm','playSe','playCry','playFanfare',
    'pumpFanfares','pumpBgm','update','applyGain','applyEngineOptions',
    'setHelpActive','onFocusGained','rebuildPlayback','setSePan'}) do
  local original=Audio[name]
  if original then
    Audio[name]=function(...)
      local result=original(...)
      P:applyGameAudio()
      return result
    end
  end
end
end
