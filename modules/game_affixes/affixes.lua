--[[
  Game Affixes Module
  Provides rarity frame detection for items with affixes
  
  Detection method: Parse item article attribute for rarity keywords
  Usage: Called by inventory.lua and containers.lua to apply rarity frames
]]

-- Make affixSystem available to other sandboxed modules via _G
_G.affixSystem = _G.affixSystem or {}
local affixSystem = _G.affixSystem

-- Configuration
local ENABLED = true
local DEBUG = false  -- Set to true for debugging

-- Rarity frame configuration - using individual images
local AFFIX_STYLES = {
  rare = {
    imagePath = "/images/ui/rarity_blue"
  },
  epic = {
    imagePath = "/images/ui/rarity_purple"
  },
  legendary = {
    imagePath = "/images/ui/rarity_gold"
  }
}

function init()
  g_logger.info("[Affixes] Module loaded - providing rarity frame detection")
end

function terminate()
  g_logger.info("[Affixes] Module terminated")
end

-- Detect if item has rarity by checking article attribute
function affixSystem.detectAffix(item)
  if not item then 
    if DEBUG then
      g_logger.info("[Affixes] detectAffix: item is nil")
    end
    return nil 
  end
  
  local article = item:getArticle()
  
  if DEBUG then
    g_logger.info(string.format("[Affixes] detectAffix called - article='%s'", article or "nil"))
  end
  
  -- Check article attribute (server sets this to "a rare", "an epic", "a legendary")
  if article and article ~= "" then
    local articleLower = article:lower()
    
    if DEBUG then
      g_logger.info(string.format("[Affixes] Article lowercase: '%s'", articleLower))
    end
    
    if articleLower:find("legendary", 1, true) then
      if DEBUG then
        g_logger.info("[Affixes] *** DETECTED LEGENDARY ***")
      end
      return "legendary"
    elseif articleLower:find("epic", 1, true) then
      if DEBUG then
        g_logger.info("[Affixes] *** DETECTED EPIC ***")
      end
      return "epic"
    elseif articleLower:find("rare", 1, true) then
      if DEBUG then
        g_logger.info("[Affixes] *** DETECTED RARE ***")
      end
      return "rare"
    end
  end
  
  -- Fallback: check description
  local description = item:getDescription()
  if description and description ~= "" then
    local descLower = description:lower()
    
    if descLower:find("legendary", 1, true) then
      return "legendary"
    elseif descLower:find("epic", 1, true) then
      return "epic"
    elseif descLower:find("rare", 1, true) then
      return "rare"
    end
  end
  
  if DEBUG then
    g_logger.info("[Affixes] No rarity detected")
  end
  
  return nil
end

-- Public API: Get rarity frame path for an item
function affixSystem.getRarityFrame(item)
  if DEBUG then
    g_logger.info("[Affixes] getRarityFrame called")
  end
  
  if not ENABLED then
    if DEBUG then
      g_logger.info("[Affixes] System is DISABLED")
    end
    return nil
  end
  
  if not item then
    if DEBUG then
      g_logger.info("[Affixes] Item is nil")
    end
    return nil
  end
  
  local affixType = affixSystem.detectAffix(item)
  
  if DEBUG then
    g_logger.info(string.format("[Affixes] detectAffix returned: %s", affixType or "nil"))
  end
  
  if not affixType then return nil end
  
  local style = AFFIX_STYLES[affixType]
  if DEBUG and style then
    g_logger.info(string.format("[Affixes] Item has %s rarity, frame: %s", affixType, style.imagePath))
  end
  
  return style and style.imagePath or nil
end
