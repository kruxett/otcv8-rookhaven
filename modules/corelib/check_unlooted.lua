-- Check Unlooted Items Script
-- Automatically runs every 100ms checking for unlooted items
-- Use stopUnlootedChecker() to stop it, startUnlootedChecker() to restart

-- CONFIGURATION
local ENABLE_LOGGING = false  -- Set to false to disable ALL logging output

-- Note: CorpseGlowConfig is loaded from corpse_glow_config.lua in corelib.otmod
-- If available, it will be used for color configuration
local USE_GLOW_CONFIG = (CorpseGlowConfig ~= nil)

-- Glow Color Configuration (RGB: 0-255 for each component)
-- These values are only used if CorpseGlowConfig is not available
local GLOW_COLOR_R = 255      -- Red component (0-255)
local GLOW_COLOR_G = 215      -- Green component (0-255) [215 = gold/yellow]
local GLOW_COLOR_B = 0        -- Blue component (0-255)

-- Glow Opacity Configuration (Alpha: 0-255)
-- 0 = completely invisible, 128 = half transparent, 255 = fully opaque
local GLOW_OPACITY = 80      -- Opacity/Alpha (0-255) - subtle visibility

-- Examples of color presets (uncomment to use):
-- Gold:    R=255, G=215, B=0    (default)
-- Red:     R=255, G=0,   B=0
-- Green:   R=0,   G=255, B=0
-- Blue:    R=0,   G=100, B=255
-- Cyan:    R=0,   G=255, B=255
-- Magenta: R=255, G=0,   B=255
-- Orange:  R=255, G=165, B=0
-- White:   R=255, G=255, B=255

-- Global variables to store the events so we can cancel them
_unlootedCheckerEvent = nil
_unlootedLoginCheckEvent = nil
_unlootedDebugMode = false  -- Set to true for verbose output
_unlootedGlowedItems = {}  -- Track all items we've glowed so we can clear them

-- Glow configuration (stolen from unlooted_corpses.lua)
local function getUnlootedGlowColor()
  -- If new config is available, use it
  if USE_GLOW_CONFIG and CorpseGlowConfig then
    local c = CorpseGlowConfig.glowColor
    return c.r or 255, c.g or 215, c.b or 0, c.a or 200
  end
  -- Otherwise fall back to hardcoded values
  return GLOW_COLOR_R, GLOW_COLOR_G, GLOW_COLOR_B, GLOW_OPACITY
end

-- Clear all previously glowed items
local function clearAllGlows()
  local clearedCount = 0
  for item, _ in pairs(_unlootedGlowedItems) do
    if item and item:isItem() then
      item:setMarked('')
      clearedCount = clearedCount + 1
    end
  end
  _unlootedGlowedItems = {}
  
  if ENABLE_LOGGING and _unlootedDebugMode and clearedCount > 0 then
    print("  [Glow] Cleared " .. clearedCount .. " previous glow(s)")
  end
end

-- Apply glow to an item
local function applyGlowToItem(item)
  if not item or not item:isItem() then
    return false
  end
  
  -- Try to apply shader if config is loaded
  local shaderApplied = false
  if USE_GLOW_CONFIG then
    shaderApplied = pcall(function()
      item:setShader("corpse_glow")
    end)
  end
  
  -- No color marking - shader only
  item:setMarked('')
  
  _unlootedGlowedItems[item] = true
  
  if ENABLE_LOGGING then
    print("[Glow] Applied glow to item ID: " .. item:getId() .. " | Shader: " .. (shaderApplied and "YES" or "NO"))
  end
  
  return true
end


function checkUnlootedItems()
  local player = g_game.getLocalPlayer()
  
  -- If player is not available, stop checker and wait for login again
  if not player or not g_game.isOnline() then
    if ENABLE_LOGGING and _unlootedDebugMode then
      print("Error: Player not found or logged out!")
    end
    if ENABLE_LOGGING then
      print("[UnlootedChecker] Player logged out, stopping checker and waiting for login...")
    end
    -- Clear all glows before stopping
    clearAllGlows()
    stopUnlootedCheckerInternal()
    -- Start waiting for login again
    if not _unlootedLoginCheckEvent then
      _unlootedLoginCheckEvent = cycleEvent(checkForLoginAndStart, 1000)
    end
    return
  end
  
  -- Clear all previous glows at the start of each check
  clearAllGlows()
  
  local playerPos = player:getPosition()
  local range = 8
  local unlootedCount = 0
  local unlootedItems = {}
  local tilesChecked = 0
  local itemsChecked = 0
  
  if ENABLE_LOGGING and _unlootedDebugMode then
    print("========================================")
    print("Starting unlooted item check...")
    print("Player position: x=" .. playerPos.x .. ", y=" .. playerPos.y .. ", z=" .. playerPos.z)
    print("Checking range: " .. range .. " tiles (5x5 grid)")
    print("========================================")
  end
  
  -- Iterate through all positions within range
  for dx = -range, range do
    for dy = -range, range do
      local tilePos = {
        x = playerPos.x + dx,
        y = playerPos.y + dy,
        z = playerPos.z
      }
      
      if ENABLE_LOGGING and _unlootedDebugMode then
        print("Checking tile at offset (" .. dx .. ", " .. dy .. ") - position (x=" .. tilePos.x .. ", y=" .. tilePos.y .. ", z=" .. tilePos.z .. ")")
      end
      
      -- Get the tile at this position
      local tile = g_map.getTile(tilePos)
      
      if tile then
        tilesChecked = tilesChecked + 1
        
        -- Get all items on this tile
        local items = tile:getItems()
        
        if items and #items > 0 then
          if ENABLE_LOGGING and _unlootedDebugMode then
            print("  -> Found " .. #items .. " item(s) on this tile")
          end
          
          for i, item in ipairs(items) do
            itemsChecked = itemsChecked + 1
            local itemId = item:getId()
            local isUnlooted = item:isUnlooted()
            
            if ENABLE_LOGGING and _unlootedDebugMode then
              print("    Item #" .. i .. ": ID=" .. itemId .. ", isUnlooted=" .. tostring(isUnlooted))
            end
            
            -- Check if item is unlooted
            if isUnlooted then
              unlootedCount = unlootedCount + 1
              
              -- Always reapply shader to keep it active (silent, no logging)
              -- Even if already glowed, the shader might have been lost
              pcall(function()
                item:setShader("corpse_glow")
              end)
              
              -- Only apply initial glow if we haven't already glowed this item
              -- (prevents spam logging)
              if not _unlootedGlowedItems[item] then
                applyGlowToItem(item)
              end
              
              if ENABLE_LOGGING then
                print("*** UNLOOTED ITEM FOUND! Item ID: " .. itemId .. " at (" .. tilePos.x .. ", " .. tilePos.y .. ", " .. tilePos.z .. ") ***")
              end
              table.insert(unlootedItems, {
                id = itemId,
                pos = tilePos,
                offsetX = dx,
                offsetY = dy,
                item = item
              })
            end
          end
        elseif ENABLE_LOGGING and _unlootedDebugMode then
          print("  -> No items on this tile")
        end
      elseif ENABLE_LOGGING and _unlootedDebugMode then
        print("  -> Tile not found (possibly out of range or invalid)")
      end
    end
  end
  
  -- Print summary only in debug mode or if items found
  if ENABLE_LOGGING and (_unlootedDebugMode or unlootedCount > 0) then
    if _unlootedDebugMode then
      print("========================================")
      print("Check complete!")
      print("Tiles checked: " .. tilesChecked)
      print("Items checked: " .. itemsChecked)
      print("========================================")
    end
    
    if unlootedCount == 0 then
      if _unlootedDebugMode then
        print("RESULT: No unlooted items found within " .. range .. " tiles.")
      end
    else
      print("RESULT: Found " .. unlootedCount .. " UNLOOTED item(s) (glowing gold):")
      for i, itemInfo in ipairs(unlootedItems) do
        print("  [" .. i .. "] Item ID: " .. itemInfo.id .. 
              " | Offset: (" .. itemInfo.offsetX .. ", " .. itemInfo.offsetY .. ")" ..
              " | Position: (x=" .. itemInfo.pos.x .. ", y=" .. itemInfo.pos.y .. ", z=" .. itemInfo.pos.z .. ")")
      end
    end
    
    if _unlootedDebugMode then
      print("========================================")
    end
  end
  
  return unlootedItems
end

-- Start periodic checking every 100ms
function startUnlootedChecker()
  if _unlootedCheckerEvent then
    if ENABLE_LOGGING then
      print("Unlooted checker is already running!")
    end
    return
  end
  
  if ENABLE_LOGGING then
    print("Starting periodic unlooted item checker (every 100ms)...")
  end
  _unlootedCheckerEvent = cycleEvent(function()
    checkUnlootedItems()
  end, 100)
  
  if ENABLE_LOGGING then
    print("Unlooted checker started! Use stopUnlootedChecker() to stop.")
  end
end

-- Stop the periodic checker (internal version without message)
function stopUnlootedCheckerInternal()
  if _unlootedCheckerEvent then
    removeEvent(_unlootedCheckerEvent)
    _unlootedCheckerEvent = nil
  end
  if _unlootedAnimationEvent then
    removeEvent(_unlootedAnimationEvent)
    _unlootedAnimationEvent = nil
  end
end

-- Stop the periodic checker
function stopUnlootedChecker()
  if not _unlootedCheckerEvent then
    if ENABLE_LOGGING then
      print("Unlooted checker is not running.")
    end
    return
  end
  
  -- Clear all glows when stopping
  clearAllGlows()
  stopUnlootedCheckerInternal()
  if ENABLE_LOGGING then
    print("Unlooted checker stopped.")
  end
end

-- Stop the login check
function stopUnlootedLoginCheck()
  if _unlootedLoginCheckEvent then
    removeEvent(_unlootedLoginCheckEvent)
    _unlootedLoginCheckEvent = nil
  end
end

-- Check if the checker is running
function isUnlootedCheckerRunning()
  return _unlootedCheckerEvent ~= nil
end

-- Enable/disable debug mode
function setUnlootedDebugMode(enabled)
  _unlootedDebugMode = enabled
  if ENABLE_LOGGING then
    print("Unlooted debug mode: " .. (enabled and "ENABLED" or "DISABLED"))
  end
end

-- Check for login and start checker when player logs in
function checkForLoginAndStart()
  if g_game.isOnline() and g_game.getLocalPlayer() then
    if ENABLE_LOGGING then
      print("[UnlootedChecker] Player logged in, delaying checker start by 3s to let map load...")
    end
    stopUnlootedLoginCheck()
    -- Delay starting the heavy tile scan by 3 seconds to avoid hitting the
    -- server's initial map-data burst right at login.
    scheduleEvent(function()
      if g_game.isOnline() then
        startUnlootedChecker()
      end
    end, 3000)
  end
end

-- Initialize the script
if ENABLE_LOGGING then
  print("========================================")
  print("Unlooted items checker loaded!")
  print("Commands:")
  print("  stopUnlootedChecker()           - Stop automatic checking")
  print("  startUnlootedChecker()          - Restart if stopped")
  print("  isUnlootedCheckerRunning()      - Check if automatic checking is active")
  print("  setUnlootedDebugMode(true/false) - Enable/disable verbose output")
  print("========================================")
end

-- Check if player is already logged in
if g_game.isOnline() and g_game.getLocalPlayer() then
  if ENABLE_LOGGING then
    print("[UnlootedChecker] Player is already logged in, starting checker...")
  end
  startUnlootedChecker()
else
  -- Start checking for login every 1000ms
  if ENABLE_LOGGING then
    print("[UnlootedChecker] Waiting for player to log in...")
  end
  _unlootedLoginCheckEvent = cycleEvent(checkForLoginAndStart, 1000)
end
