return function(mod)
local Player = assert(loadstring(assert(mod:read("mp3_player.lua")), "@mp3_player/mp3_player.lua"))()(mod)

-- A string ID keeps the item safely outside FireRed's ROM item-ID range.
local ITEM_ID = "MP3_PLAYER"
local ITEM = {
  id = ITEM_ID, name = "MP3 Player", pocket = "KEY_ITEMS", fieldUse = "mp3_player",
  price = 9800, importance = 1, registrability = 1, battleUsage = 0,
  description = "A portable music player.\nPlay imported soundtracks.",
}

local function install()
  local Items = require("src.core.game3.items_data")
  local Bag = require("src.core.game3.bag")
  local BagChrome = require("src.ui.game3.bag_chrome")
  local ItemUse = require("src.core.game3.item_use")
  local Runtime = require("src.core.game3.runtime")
  local Shop = require("src.ui.game3.shop_menu")
  local Marts = require("src.core.game3.marts")
  local function owned(session)
    return session and session.bag and Bag.has(session.bag, ITEM_ID, 1)
  end
  -- Enforce uniqueness at the inventory boundary as well as in the shop UI.
  local canAdd, add = Bag.canAdd, Bag.add
  Bag.canAdd = function(bag,id,qty)
    if id==ITEM_ID and ((tonumber(qty) or 1)~=1 or Bag.has(bag,id,1)) then return false end
    return canAdd(bag,id,qty)
  end
  Bag.add = function(bag,id,qty)
    if id==ITEM_ID and ((tonumber(qty) or 1)~=1 or Bag.has(bag,id,1)) then return false,0 end
    return add(bag,id,qty)
  end

  local info = Items.info
  Items.info = function(id)
    if id == ITEM_ID then return ITEM end
    return info(id)
  end

  -- Reuse the supplied device art consistently in the Bag and shop preview.
  local iconImage = BagChrome.iconImage
  BagChrome.iconImage = function(id)
    if id ~= ITEM_ID then return iconImage(id) end
    local image = mod.assets:image("assets/player.png")
    image:setFilter("nearest", "nearest")
    return image
  end
  local drawItemIcon = BagChrome.drawItemIcon
  BagChrome.drawItemIcon = function(id, x, y, scale)
    if id ~= ITEM_ID then return drawItemIcon(id, x, y, scale) end
    local image = BagChrome.iconImage(id)
    local w, h = image:getDimensions(); local side = 24 * (scale or 1)
    local fit = side / math.max(w, h)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, (x or 0) + (side - w * fit) / 2, (y or 0) + (side - h * fit) / 2, 0, fit, fit)
    return true
  end

  local useField = ItemUse.useField
  ItemUse.useField = function(session, bag, id, ...)
    if id ~= ITEM_ID then return useField(session, bag, id, ...) end
    if not bag or not Bag.has(bag, ITEM_ID, 1) then return false, "none", "You do not have an MP3 Player." end
    local game = Runtime._game
    if not game then return false, "none", "The MP3 Player is unavailable right now." end
    local open = function() Player:show(game) end
    if ItemUse.setUpOnFieldCallback(open) then return true, "escape" end
    open(); return true, "mp3_player"
  end

  -- FireRed's Celadon PokÃ© Doll / stone counter.  This exact mart pointer is
  -- extracted from the user's FireRed cache (g3:0816bc30); adding to the mart
  -- data is earlier and more reliable than patching an already-open UI.
  local POKE_DOLL_COUNTER = 135707696
  local itemsFor = Marts.itemsFor
  Marts.itemsFor = function(key)
    local items, entry = itemsFor(key)
    local matches = key == POKE_DOLL_COUNTER or tostring(key):lower() == "g3:0816bc30"
    if matches and items then
      local copy = {}; for _, id in ipairs(items) do if id~=ITEM_ID then copy[#copy + 1] = id end end
      if not owned(Runtime._game and Runtime._game.session) then copy[#copy + 1] = ITEM_ID end
      return copy, entry
    end
    return items, entry
  end

  -- Compatibility fallback for a Recomp version that opens the shop with a
  -- stock table directly instead of resolving through Marts.itemsFor.
  local function hasPokeDoll(stock)
    for _, id in ipairs(stock or {}) do
      if id == "POKE_DOLL" or tonumber(id) == 80 or Items.toNumericId(id) == 80 then return true end
    end
    return false
  end
  local show = Shop.show
  Shop.show = function(opts)
    opts = opts or {}
    local copy = {}; for k,v in pairs(opts) do copy[k]=v end
    copy.items={}; local offered=hasPokeDoll(opts.items)
    for _,id in ipairs(opts.items or {}) do
      if id==ITEM_ID then offered=true else copy.items[#copy.items+1]=id end
    end
    if offered and not owned(opts.session) then copy.items[#copy.items+1]=ITEM_ID end
    return show(copy)
  end
  local handleInput=Shop.handleInput
  Shop.handleInput=function(input)
    if Shop._pending and Shop._pending.id==ITEM_ID then
      Shop.qty=1
      -- Quantity arrows cannot increase the count or alter the quoted cost.
      if Shop.mode=='buy_qty' then
        local original=input
        input=setmetatable({wasPressed=function(_,key)
          if key=='up' or key=='down' or key=='left' or key=='right' then return false end
          return original:wasPressed(key)
        end},{__index=original})
      end
    end
    local result=handleInput(input)
    if Shop.open and owned(Shop._session) then
      local filtered={}; local changed=false
      for _,id in ipairs(Shop._items or {}) do
        if id==ITEM_ID then changed=true else filtered[#filtered+1]=id end
      end
      if changed then
        Shop._items=filtered; Shop._rowsGen=(Shop._rowsGen or 0)+1
        Shop.cursor=math.max(1,math.min(Shop.cursor or 1,#filtered+1))
        Shop.scroll=math.max(0,math.min(Shop.scroll or 0,Shop.cursor-1))
      end
    end
    return result
  end
end

install()
mod.exports.registerPack = function(owner, data) return Player:registerPack(owner, data) end
mod.exports.player = Player
mod.log:info("MP3 Player: item and Celadon merchant hooks installed")
end
