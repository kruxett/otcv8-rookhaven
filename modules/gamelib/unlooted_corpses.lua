-- Unlooted Corpse System
-- Handles server notifications for unlooted corpses via extended opcode

-- Load configuration
dofile('unlooted_corpses_config')

-- Track marked tiles
local markedTiles = {}
local clearedTiles = {}
local checkEvent = nil

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
  if not containerItem:isLyingCorpse() and not markedTiles[key] then
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
  
  -- Stop the check event
  if checkEvent then
    removeEvent(checkEvent)
    checkEvent = nil
  end
  
  -- Clear all markers on module termination
  if UnlootedCorpseConfig.clearOnLogout then
    markedTiles = {}
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
  
  local corpse = tile:getTopUseThing()
  
  if not corpse or not corpse:isItem() then
    -- No corpse found, clear from tracking
    markedTiles[key] = nil
    
    -- Clear any marks on the tile
    local items = tile:getItems()
    for _, item in ipairs(items) do
      item:setMarked('')
    end
    
    if UnlootedCorpseConfig.debug then
      print("[UnlootedCorpse] ? Auto-cleared tile " .. pos.x .. "," .. pos.y .. "," .. pos.z .. " (corpse disappeared)")
    end
    return
  end
  
  -- Re-mark the corpse (handles decay when item ID changes)
  local r, g, b, a = UnlootedCorpseConfig.getGlowColor()
  local colorHex = string.format("#%02x%02x%02x%02x", r, g, b, a)
  corpse:setMarked(colorHex)
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
    local corpse = tile:getTopUseThing()
    
    if corpse and corpse:isItem() then
      -- Mark it with gold glow
      local r, g, b, a = UnlootedCorpseConfig.getGlowColor()
      local colorHex = string.format("#%02x%02x%02x%02x", r, g, b, a)
      corpse:setMarked(colorHex)
      print("[UnlootedCorpse] ? MARKED corpse ID=" .. corpse:getId() .. " at " .. pos.x .. "," .. pos.y .. "," .. pos.z)
    else
      print("[UnlootedCorpse] WARNING: No usable item found on tile " .. pos.x .. "," .. pos.y .. "," .. pos.z)
    end
    
  elseif cmd == "clear" then
    if UnlootedCorpseConfig.debug then
      print("[UnlootedCorpse] Received clear for " .. coords)
    end
    -- Untrack this tile
    local key = pos.x .. "," .. pos.y .. "," .. pos.z
    markedTiles[key] = nil
    clearedTiles[key] = g_clock.millis()
    
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
