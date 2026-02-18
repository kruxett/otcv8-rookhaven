-- Unlooted Corpse System
-- Handles server notifications for unlooted corpses via extended opcode

-- Load configurations
dofile('unlooted_corpses_config')
dofile('corpse_glow_config')

-- Track marked tiles
local markedTiles = {}
local clearedTiles = {}
local markedThings = {}
local missingCorpseTiles = {}
local movedCorpses = {}
local movedCorpseSignatures = {}
local checkEvent = nil
local tileCallbackState = nil
local previousTileOnAddThing = nil
local previousTileOnRemoveThing = nil
local corpseItemServerIds = {}
local corpseItemIdsLoaded = false

local function posKey(pos)
  return pos.x .. "," .. pos.y .. "," .. pos.z
end

local function isCorpseName(name)
  if not name or name == '' then
    return false
  end
  name = name:lower()
  local keywords = UnlootedCorpseConfig.corpseItemKeywords or { "corpse", "dead", "slain", "remains", "body", "bones" }
  for _, keyword in ipairs(keywords) do
    if name:find(keyword, 1, true) then
      return true
    end
  end
  return false
end

local function loadCorpseItemIds()
  if corpseItemIdsLoaded then
    return
  end
  corpseItemIdsLoaded = true

  local dataPath = UnlootedCorpseConfig.corpseItemDataPath
  if not dataPath or dataPath == '' then
    return
  end
  if not g_resources.fileExists(dataPath) then
    if UnlootedCorpseConfig.debug then
      print("[UnlootedCorpse] Item data file not found: " .. dataPath)
    end
    return
  end

  local contents = g_resources.readFileContents(dataPath)
  if not contents or contents == '' then
    return
  end

  local added = 0
  for line in contents:gmatch("[^\r\n]+") do
    if line:find("<item") then
      local name = line:match('name="([^"]+)"')
      if isCorpseName(name) then
        local id = line:match('id="(%d+)"')
        if id then
          local num = tonumber(id)
          if num and not corpseItemServerIds[num] then
            corpseItemServerIds[num] = true
            added = added + 1
          end
        end

        local fromId = line:match('fromid="(%d+)"')
        local toId = line:match('toid="(%d+)"')
        if fromId and toId then
          local fromNum = tonumber(fromId)
          local toNum = tonumber(toId)
          if fromNum and toNum then
            for i = fromNum, toNum do
              if not corpseItemServerIds[i] then
                corpseItemServerIds[i] = true
                added = added + 1
              end
            end
          end
        end
      end
    end
  end

  if UnlootedCorpseConfig.debug then
    print("[UnlootedCorpse] Loaded " .. tostring(added) .. " corpse item ids from items.txt")
  end
end

local function corpseSignature(item)
  if not item then
    return ""
  end
  local name = item:getName() or ""
  local description = item:getDescription() or ""
  return string.format("%d:%s:%s", item:getId(), name, description)
end

local function markMissingCorpse(key)
  if not missingCorpseTiles[key] then
    missingCorpseTiles[key] = g_clock.millis()
  end
end

local function isCorpseItem(item)
  if not item or not item:isItem() then
    return false
  end
  if item:isLyingCorpse() then
    return true
  end

  loadCorpseItemIds()
  local serverId = item:getServerId()
  if serverId and corpseItemServerIds[serverId] then
    return true
  end

  local name = item:getName()
  if name and name ~= '' then
    name = name:lower()
    if name:find('corpse') or name:find('dead') or name:find('slain') or name:find('remains') or name:find('body') or name:find('bones') then
      return true
    end
  end

  local description = item:getDescription()
  if description and description ~= '' then
    description = description:lower()
    if description:find('unlooted') or description:find('corpse') or description:find('dead') or description:find('slain') or description:find('remains') or description:find('body') or description:find('bones') then
      return true
    end
  end

  return false
end

local function findCorpseOnTile(tile)
  if not tile then
    return nil
  end

  local corpse = tile:getTopUseThing()
  if corpse and corpse:isItem() then
    return corpse
  end

  local items = tile:getItems()
  if items and #items > 0 then
    return items[1]
  end

  if UnlootedCorpseConfig.debug then
    local names = {}
    for _, item in ipairs(items) do
      local name = item:getName() or ""
      if name ~= "" then
        table.insert(names, string.format("%s(%d)", name, item:getId()))
      else
        table.insert(names, string.format("<no name>(%d)", item:getId()))
      end
    end
    if #names > 0 then
      print("[UnlootedCorpse] Tile items: " .. table.concat(names, ", "))
    end
  end

  return nil
end

local function clearCorpseContainer(container)
  if UnlootedCorpseConfig.debug then
    print("[UnlootedCorpse] Checking container for clear, size=" .. tostring(container:getItemsCount()))
  end
  if not UnlootedCorpseConfig.isEnabled() then
    return
  end

  if container:getItemsCount() > 0 then
    if UnlootedCorpseConfig.debug then
      print("[UnlootedCorpse] Container not empty, skip clear")
    end
    return
  end

  local containerItem = container:getContainerItem()
  if not containerItem or not containerItem:isItem() or not containerItem:isContainer() then
    if UnlootedCorpseConfig.debug then
      print("[UnlootedCorpse] Container item invalid for clear")
    end
    return
  end

  local pos = containerItem:getPosition()
  if not pos or pos.x == 0xffff then
    if UnlootedCorpseConfig.debug then
      print("[UnlootedCorpse] Container has no valid position for clear")
    end
    return
  end

  local key = pos.x .. "," .. pos.y .. "," .. pos.z
  if not isCorpseItem(containerItem) and not markedTiles[key] then
    if UnlootedCorpseConfig.debug then
      print("[UnlootedCorpse] Container not tracked or not corpse, skip clear at " .. key)
    end
    return
  end
  markedTiles[key] = nil
  clearedTiles[key] = g_clock.millis()

  local tile = g_map.getTile(pos)
  if tile then
    local items = tile:getItems()
    for _, item in ipairs(items) do
      item:setMarked('')
    end
  else
    containerItem:setMarked('')
  end

  if UnlootedCorpseConfig.debug then
    print("[UnlootedCorpse] Cleared empty corpse at " .. pos.x .. "," .. pos.y .. "," .. pos.z)
  end
end

-- Initialize
function init()
  loadCorpseItemIds()
  tileCallbackState = g_game.isTileThingLuaCallbackEnabled()
  g_game.enableTileThingLuaCallback(true)

  previousTileOnAddThing = Tile.onAddThing
  previousTileOnRemoveThing = Tile.onRemoveThing

  function Tile:onAddThing(thing)
    if previousTileOnAddThing then
      previousTileOnAddThing(self, thing)
    end
    if not UnlootedCorpseConfig.isEnabled() or not thing or not thing:isItem() then
      return
    end

    local pos = self:getPosition()
    local key = posKey(pos)

    if markedTiles[key] and not markedThings[key] then
      local r, g, b, a = UnlootedCorpseConfig.getGlowColor()
      local colorHex = string.format("#%02x%02x%02x%02x", r, g, b, a)
      thing:setMarked(colorHex)
      markedThings[key] = thing
    end

    if movedCorpses[thing] then
      movedCorpses[thing] = nil
      local key = posKey(pos)
      markedTiles[key] = true
      markedThings[key] = thing

      local r, g, b, a = UnlootedCorpseConfig.getGlowColor()
      local colorHex = string.format("#%02x%02x%02x%02x", r, g, b, a)
      thing:setMarked(colorHex)
      movedCorpseSignatures[corpseSignature(thing)] = nil
      return
    end

    local signature = corpseSignature(thing)
    if movedCorpseSignatures[signature] then
      movedCorpseSignatures[signature] = nil
      local key = posKey(pos)
      markedTiles[key] = true
      markedThings[key] = thing

      local r, g, b, a = UnlootedCorpseConfig.getGlowColor()
      local colorHex = string.format("#%02x%02x%02x%02x", r, g, b, a)
      thing:setMarked(colorHex)
      return
    end
  end

  function Tile:onRemoveThing(thing)
    if previousTileOnRemoveThing then
      previousTileOnRemoveThing(self, thing)
    end
    if not UnlootedCorpseConfig.isEnabled() or not thing or not thing:isItem() then
      return
    end

    local pos = self:getPosition()
    local key = posKey(pos)
    if markedThings[key] == thing then
      markedTiles[key] = nil
      markedThings[key] = nil
      movedCorpses[thing] = true
      movedCorpseSignatures[corpseSignature(thing)] = true
    end
  end

  -- Server now sends unlooted corpse notifications only on extended opcode 1
  -- with a plain UTF-8 payload string "mark:x,y,z" or "clear:x,y,z".
  ProtocolGame.registerExtendedOpcode(1, onExtendedOpcode)
  connect(g_game, { onGameEnd = onGameEnd })
  connect(Container, { onClose = onContainerClose, onRemoveItem = onContainerRemoveItem })
  
  -- Periodically check and re-mark corpses (handles decay)
  local function checkMarkedTiles()
    for key, _ in pairs(markedTiles) do
      local x, y, z = key:match("(%d+),(%d+),(%d+)")
      if x and y and z then
        local pos = {x = tonumber(x), y = tonumber(y), z = tonumber(z)}
        remarkTile(pos)
      end
    end
    
    -- Schedule next check
    checkEvent = scheduleEvent(checkMarkedTiles, 500)
  end
  
  -- Start the periodic check
  checkEvent = scheduleEvent(checkMarkedTiles, 500)
  
  if UnlootedCorpseConfig.debug then
    print("[UnlootedCorpse] Module initialized")
  end
end

function terminate()
  ProtocolGame.unregisterExtendedOpcode(1)
  disconnect(g_game, { onGameEnd = onGameEnd })
  disconnect(Container, { onClose = onContainerClose, onRemoveItem = onContainerRemoveItem })

  if tileCallbackState ~= nil then
    g_game.enableTileThingLuaCallback(tileCallbackState)
    tileCallbackState = nil
  end

  Tile.onAddThing = previousTileOnAddThing
  Tile.onRemoveThing = previousTileOnRemoveThing
  previousTileOnAddThing = nil
  previousTileOnRemoveThing = nil
  
  -- Stop the check event
  if checkEvent then
    removeEvent(checkEvent)
    checkEvent = nil
  end
  
  -- Clear all markers on module termination
  if UnlootedCorpseConfig.clearOnLogout then
    markedTiles = {}
    missingCorpseTiles = {}
    movedCorpses = {}
  end
  
  if UnlootedCorpseConfig.debug then
    print("[UnlootedCorpse] Module terminated")
  end
end

-- Cleanup on game end
function onGameEnd()
  if UnlootedCorpseConfig.clearOnLogout then
    markedTiles = {}
    clearedTiles = {}
    missingCorpseTiles = {}
    movedCorpses = {}
    markedThings = {}
    movedCorpseSignatures = {}
  end
end

function onContainerClose(container)
  clearCorpseContainer(container)
end

function onContainerRemoveItem(container, slot, item)
  if UnlootedCorpseConfig.debug then
    print("[UnlootedCorpse] onContainerRemoveItem fired, slot=" .. tostring(slot))
  end
  clearCorpseContainer(container)
end

-- Helper function to re-mark a tile (for corpse decay handling)
function remarkTile(pos)
  local key = pos.x .. "," .. pos.y .. "," .. pos.z
  if not markedTiles[key] then
    return
  end

  local tile = g_map.getTile(pos)
  if not tile then 
    -- Tile no longer exists, clear it from tracking
    markedTiles[key] = nil
    return 
  end
  
  local corpse = findCorpseOnTile(tile)
  
  if not corpse then
    markMissingCorpse(key)
    local missingSince = missingCorpseTiles[key] or g_clock.millis()
    if g_clock.millis() - missingSince > 5000 then
      markedTiles[key] = nil
      missingCorpseTiles[key] = nil

      local items = tile:getItems()
      for _, item in ipairs(items) do
        item:setMarked('')
      end

      if UnlootedCorpseConfig.debug then
        print("[UnlootedCorpse] ? Auto-cleared tile " .. pos.x .. "," .. pos.y .. "," .. pos.z .. " (corpse missing)")
      end
    end
    return
  end
  
  -- Re-mark the corpse (handles decay when item ID changes)
  local corpse = findCorpseOnTile(tile)
  if corpse and corpse:isValid() then
    applyCorpseGlowShader(corpse)
  end
  missingCorpseTiles[key] = nil
end

-- Extended opcode handler
function onExtendedOpcode(protocol, opcode, buffer)
  if buffer and #buffer > 0 then
    buffer = buffer:match("^%s*(.-)%s*$") or buffer
  end

  local hasCorpsePayload = buffer and (buffer:find("^mark:") or buffer:find("^clear:"))
  -- Unlooted corpse system now uses only extended opcode 1
  if opcode == 1 and hasCorpsePayload then
    if UnlootedCorpseConfig.isEnabled() then
      handleUnlootedCorpseMessage(buffer)
    else
      if UnlootedCorpseConfig.debug then
        print("[UnlootedCorpse] WARNING: System is DISABLED!")
      end
    end
  end
end

-- Apply corpse glow shader with configuration
-- Pass the item (corpse) to be marked
function applyCorpseGlowShader(corpse)
  if not corpse or not corpse:isValid() then
    return false
  end
  
  -- Apply the shader first
  corpse:setShader("corpse_glow")
  
  -- Get glow configuration
  local glowColor = CorpseGlowConfig.glowColor
  local animation = CorpseGlowConfig.animation
  
  -- Convert color to hex string
  local r = glowColor.r or 255
  local g = glowColor.g or 215
  local b = glowColor.b or 0
  local a = glowColor.a or 200
  local colorHex = string.format("#%02x%02x%02x%02x", r, g, b, a)
  
  -- Apply the color (this also activates the shader effect)
  corpse:setMarked(colorHex)
  
  if CorpseGlowConfig.debug then
    print(string.format("[CorpseGlow] Applied shader to corpse ID=%d with color #%02x%02x%02x%02x, speed=%.2f, direction=%d",
      corpse:getId(), r, g, b, a, animation.speed or 1.5, animation.direction or 0))
  end
  
  return true
end

-- Parse and handle unlooted corpse messages
function handleUnlootedCorpseMessage(buffer)
  -- Message format: "mark:x,y,z" or "clear:x,y,z"
  local cmd, coords = buffer:match("(%w+):(.+)")
  
  if not cmd or not coords then
    print("[UnlootedCorpse] ERROR: Failed to parse message! cmd=" .. tostring(cmd) .. " coords=" .. tostring(coords))
    return
  end
  
  -- Parse coordinates
  local x, y, z = coords:match("(%d+),(%d+),(%d+)")
  
  if not x or not y or not z then
    print("[UnlootedCorpse] ERROR: Failed to parse coordinates! x=" .. tostring(x) .. " y=" .. tostring(y) .. " z=" .. tostring(z))
    return
  end

  -- Create position table
  local pos = {
    x = tonumber(x),
    y = tonumber(y),
    z = tonumber(z)
  }

  -- Execute command
  if cmd == "mark" then
    if UnlootedCorpseConfig.debug then
      print("[UnlootedCorpse] Received mark for " .. coords)
    end
    -- Get the tile at this position
    local tile = g_map.getTile(pos)
    if not tile then
      print("[UnlootedCorpse] ERROR: Tile not found at " .. pos.x .. "," .. pos.y .. "," .. pos.z)
      return
    end

    local key = pos.x .. "," .. pos.y .. "," .. pos.z
    local lastClear = clearedTiles[key]
    if lastClear and (g_clock.millis() - lastClear) < UnlootedCorpseConfig.clearReapplySuppressMs then
      if UnlootedCorpseConfig.debug then
        print("[UnlootedCorpse] Ignoring re-mark shortly after clear at " .. key)
      end
      return
    end
    
    -- Track this tile as marked
    markedTiles[key] = true
    
    -- Get the top usable item on the tile (like vBot does)
    local corpse = findCorpseOnTile(tile)

    if corpse then
      -- Mark it with configured pulsing glow shader
      applyCorpseGlowShader(corpse)
      missingCorpseTiles[key] = nil
      print("[UnlootedCorpse] ? MARKED corpse ID=" .. corpse:getId() .. " at " .. pos.x .. "," .. pos.y .. "," .. pos.z)
    else
      markMissingCorpse(key)
      print("[UnlootedCorpse] WARNING: No corpse found on tile " .. pos.x .. "," .. pos.y .. "," .. pos.z)
    end
    
  elseif cmd == "clear" then
    if UnlootedCorpseConfig.debug then
      print("[UnlootedCorpse] Received clear for " .. coords)
    end
    -- Untrack this tile
    local key = pos.x .. "," .. pos.y .. "," .. pos.z
    markedTiles[key] = nil
    clearedTiles[key] = g_clock.millis()
    missingCorpseTiles[key] = nil
    markedThings[key] = nil
    
    -- Get the tile and clear marks on all items
    local tile = g_map.getTile(pos)
    if tile then
      local items = tile:getItems()
      for _, item in ipairs(items) do
        item:setMarked('')
      end
      print("[UnlootedCorpse] ? CLEARED marks at " .. pos.x .. "," .. pos.y .. "," .. pos.z)
    end
  else
    print("[UnlootedCorpse] ERROR: Unknown command '" .. tostring(cmd) .. "'")
  end
end

-- Auto-initialize the module
init()
