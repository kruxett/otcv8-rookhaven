--[[
  Game Affixes Module
  Provides visual indicators for items with affixes
  
  Detection method: Parse item description for rarity keywords
  Visual method: Colored border overlay on UIItem widgets
  
  Server sets article attribute (e.g., "a rare") which appears in item description
]]

affixSystem = {}

-- Configuration
local ENABLED = true
local DEBUG = true  -- ENABLED FOR TROUBLESHOOTING

-- Rarity colors and images (using existing rarity graphics)
local AFFIX_STYLES = {
  rare = {
    image = "images/ui/rarity_blue",  -- Path without leading /
    color = "#3498DB"
  },
  epic = {
    image = "images/ui/rarity_purple", 
    color = "#9B59B6"
  },
  legendary = {
    image = "images/ui/rarity_gold",
    color = "#FFD700"
  },
  default = {
    image = "images/ui/rarity_green",
    color = "#2ECC71"
  }
}

-- Overlay cache to avoid recreating widgets
local overlayCache = {}

function init()
  g_logger.info("========================================")
  g_logger.info("[Affixes] MODULE IS LOADING NOW!!!")
  g_logger.info("========================================")
  
  if DEBUG then
    g_logger.info("[Affixes] Module initializing...")
  end
  
  -- Connect to item events
  connect(g_game, {
    onGameStart = affixSystem.onGameStart,
    onGameEnd = affixSystem.onGameEnd
  })
  
  -- If already in game, start immediately
  if g_game.isOnline() then
    g_logger.info("[Affixes] Already online, starting immediately")
    affixSystem.onGameStart()
  else
    g_logger.info("[Affixes] Not online yet, waiting for game start")
  end
  
  g_logger.info("[Affixes] init() completed")
end

function terminate()
  if DEBUG then
    g_logger.info("[Affixes] Module terminating...")
  end
  
  disconnect(g_game, {
    onGameStart = affixSystem.onGameStart,
    onGameEnd = affixSystem.onGameEnd
  })
  
  affixSystem.cleanup()
end

function affixSystem.onGameStart()
  g_logger.info("========================================")
  g_logger.info("[Affixes] onGameStart() CALLED!")
  g_logger.info("========================================")
  
  if not ENABLED then 
    g_logger.warning("[Affixes] System is DISABLED!")
    return 
  end
  
  g_logger.info("[Affixes] System is ENABLED, starting hooks...")
  
  -- Hook into inventory slots
  affixSystem.hookInventory()
  
  -- Hook into containers
  affixSystem.hookContainers()
  
  g_logger.info("[Affixes] onGameStart() completed")
end

function affixSystem.onGameEnd()
  affixSystem.cleanup()
end

function affixSystem.cleanup()
  -- Clear all overlays
  for widget, overlay in pairs(overlayCache) do
    if overlay and not overlay:isDestroyed() then
      overlay:destroy()
    end
  end
  overlayCache = {}
end

-- Detect if item has rarity by checking article attribute
function affixSystem.detectAffix(item)
  if not item then 
    if DEBUG then
      g_logger.info("[Affixes] detectAffix: item is nil")
    end
    return nil 
  end
  
  -- Get all available info for debugging
  local itemId = item:getId()
  local serverId = item:getServerId()
  local name = item:getName()
  local article = item:getArticle()
  local description = item:getDescription()
  
  if DEBUG then
    g_logger.info(string.format("[Affixes] Item check - ID: %d, ServerID: %d, Name: '%s', Article: '%s', Desc: '%s'", 
      itemId or 0, serverId or 0, name or "nil", article or "nil", description or "nil"))
  end
  
  -- Check article attribute (server sets this to "a rare", "an epic", "a legendary")
  if article and article ~= "" then
    local articleLower = article:lower()
    
    -- Check for rarity keywords in article
    if articleLower:find("legendary", 1, true) then
      if DEBUG then
        g_logger.info(string.format("[Affixes] *** FOUND LEGENDARY *** Article: '%s'", article))
      end
      return "legendary"
    elseif articleLower:find("epic", 1, true) then
      if DEBUG then
        g_logger.info(string.format("[Affixes] *** FOUND EPIC *** Article: '%s'", article))
      end
      return "epic"
    elseif articleLower:find("rare", 1, true) then
      if DEBUG then
        g_logger.info(string.format("[Affixes] *** FOUND RARE *** Article: '%s'", article))
      end
      return "rare"
    end
  end
  
  -- Also check description as fallback (in case article is in description)
  if description and description ~= "" then
    local descLower = description:lower()
    
    if descLower:find("legendary", 1, true) then
      if DEBUG then
        g_logger.info("[Affixes] *** FOUND LEGENDARY in description ***")
      end
      return "legendary"
    elseif descLower:find("epic", 1, true) then
      if DEBUG then
        g_logger.info("[Affixes] *** FOUND EPIC in description ***")
      end
      return "epic"
    elseif descLower:find("rare", 1, true) then
      if DEBUG then
        g_logger.info("[Affixes] *** FOUND RARE in description ***")
      end
      return "rare"
    end
  end
  
  return nil
end

-- Create visual overlay for item widget
function affixSystem.createOverlay(itemWidget, affixType)
  if not itemWidget or itemWidget:isDestroyed() then return end
  
  -- Remove old overlay if exists
  if overlayCache[itemWidget] then
    overlayCache[itemWidget]:destroy()
    overlayCache[itemWidget] = nil
  end
  
  -- Get style for this affix type
  local style = AFFIX_STYLES[affixType] or AFFIX_STYLES.default
  
  -- Create overlay using vanilla UIWidget (no OTUI dependency)
  local overlay = g_ui.createWidget('UIWidget', itemWidget)
  overlay:setId('affixOverlay')
  overlay:fill('parent')
  overlay:setPhantom(true)
  
  -- Try to use rarity image
  local imagePath = style.image .. '.png'
  if g_resources.fileExists(imagePath) then
    overlay:setImageSource(imagePath)
    overlay:setImageColor(style.color)
    overlay:setOpacity(0.9)
    if DEBUG then
      g_logger.info(string.format("[Affixes] Created IMAGE overlay (type: %s, image: %s)", affixType, imagePath))
    end
  else
    -- Fallback to solid border if image not found
    overlay:setBorderWidth(3)
    overlay:setBorderColor(style.color)
    overlay:setBackgroundColor('#00000000')
    overlay:setOpacity(1.0)
    if DEBUG then
      g_logger.warning(string.format("[Affixes] Image not found, using SOLID border (type: %s)", affixType))
    end
  end
  
  overlayCache[itemWidget] = overlay
end

-- Remove overlay from widget
function affixSystem.removeOverlay(itemWidget)
  if overlayCache[itemWidget] then
    overlayCache[itemWidget]:destroy()
    overlayCache[itemWidget] = nil
  end
end

-- Update item widget visuals
function affixSystem.updateItemWidget(itemWidget)
  if not itemWidget or itemWidget:isDestroyed() then return end
  
  local item = itemWidget:getItem()
  if not item then
    affixSystem.removeOverlay(itemWidget)
    return
  end
  
  local affixType = affixSystem.detectAffix(item)
  
  if affixType then
    affixSystem.createOverlay(itemWidget, affixType)
  else
    affixSystem.removeOverlay(itemWidget)
  end
end

-- Hook inventory slots
function affixSystem.hookInventory()
  g_logger.info("[Affixes] hookInventory() START")
  
  -- Access inventory window directly from game_inventory module
  local inventoryWindow = g_ui.getRootWidget():recursiveGetChildById('inventoryWindow')
  if not inventoryWindow then
    g_logger.error("[Affixes] ERROR: Inventory window not found!")
    return
  end
  
  g_logger.info("[Affixes] Found inventory window")
  
  -- Get inventory panel
  local inventoryPanel = inventoryWindow:recursiveGetChildById('inventoryPanel')
  if not inventoryPanel then
    g_logger.error("[Affixes] ERROR: Inventory panel not found!")
    return
  end
  
  g_logger.info("[Affixes] Found inventory panel")
  
  -- Hook all item slots in inventory panel
  local slotCount = 0
  for _, slot in ipairs(inventoryPanel:getChildren()) do
    if slot:getClassName() == 'UIItem' then
      slotCount = slotCount + 1
      
      -- Initial update
      affixSystem.updateItemWidget(slot)
      
      -- Hook onChange
      slot.onItemChange = function(self, item)
        g_logger.info("[Affixes] onItemChange triggered!")
        affixSystem.updateItemWidget(self)
      end
    end
  end
  
  g_logger.info(string.format("[Affixes] Hooked %d inventory slots", slotCount))
end

-- Hook container slots
function affixSystem.hookContainers()
  -- Listen for container open events
  connect(Container, {
    onOpen = affixSystem.onContainerOpen,
    onUpdateItem = affixSystem.onContainerUpdateItem
  })
  
  -- Update existing open containers
  for _, container in pairs(g_game.getContainers()) do
    affixSystem.updateContainerSlots(container)
  end
  
  if DEBUG then
    g_logger.info("[Affixes] Containers hooked")
  end
end

function affixSystem.onContainerOpen(container, previousContainer)
  if DEBUG then
    g_logger.info("[Affixes] Container opened")
  end
  
  -- Wait a bit for items to load, then update
  scheduleEvent(function()
    affixSystem.updateContainerSlots(container)
  end, 50)
end

function affixSystem.onContainerUpdateItem(container, slot, item, oldItem)
  -- Find container window by ID
  local containerWindow = g_ui.getRootWidget():recursiveGetChildById('container_' .. container:getId())
  if containerWindow then
    -- Find items panel in container
    local itemsPanel = containerWindow:recursiveGetChildById('itemsPanel') or 
                       containerWindow:recursiveGetChildById('contentsPanel')
    
    if itemsPanel then
      -- Update the specific slot
      local children = itemsPanel:getChildren()
      if children[slot + 1] then  -- Lua is 1-indexed
        affixSystem.updateItemWidget(children[slot + 1])
      end
    end
  end
end

function affixSystem.updateContainerSlots(container)
  if not container then return end
  
  -- Find container window by ID
  local containerWindow = g_ui.getRootWidget():recursiveGetChildById('container_' .. container:getId())
  if not containerWindow then
    if DEBUG then
      g_logger.warning("[Affixes] Container window not found for container " .. container:getId())
    end
    return
  end
  
  -- Find content panel with items
  local itemsPanel = containerWindow:recursiveGetChildById('itemsPanel') or
                     containerWindow:recursiveGetChildById('contentsPanel')
  
  if not itemsPanel then
    if DEBUG then
      g_logger.warning("[Affixes] Container items panel not found")
    end
    return
  end
  
  -- Update all item widgets
  local count = 0
  for _, itemWidget in ipairs(itemsPanel:getChildren()) do
    if itemWidget:getClassName() == 'UIItem' then
      affixSystem.updateItemWidget(itemWidget)
      count = count + 1
    end
  end
  
  if DEBUG then
    g_logger.info(string.format("[Affixes] Updated %d container slots", count))
  end
end

-- Toggle system on/off
function affixSystem.toggle()
  ENABLED = not ENABLED
  
  if ENABLED then
    affixSystem.onGameStart()
    g_logger.info("[Affixes] System enabled")
  else
    affixSystem.cleanup()
    g_logger.info("[Affixes] System disabled")
  end
end

-- Public API
function affixSystem.isEnabled()
  return ENABLED
end

function affixSystem.setEnabled(enabled)
  if ENABLED ~= enabled then
    affixSystem.toggle()
  end
end
