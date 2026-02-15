--[[
  Ground Rarity Indicator Configuration
  
  This module provides configurable settings for rarity indicators on ground items.
  The indicator uses a colored glow effect that follows the actual item sprite shape.
]]

-- Make groundRarityConfig available globally
_G.groundRarityConfig = _G.groundRarityConfig or {}
local groundRarityConfig = _G.groundRarityConfig

-- Enable/disable ground rarity indicators
groundRarityConfig.enabled = true

-- Style is now always "glow" (colored outline following the item sprite)
groundRarityConfig.style = "glow"

-- Rarity colors (RGB format - customize to your preference)
groundRarityConfig.colors = {
  rare = {r = 0, g = 150, b = 255},        -- Bright Blue
  epic = {r = 200, g = 0, b = 255},        -- Bright Purple
  legendary = {r = 255, g = 200, b = 0}    -- Bright Gold
}

-- Rarity filter - set to nil to show all rarities, or filter specific ones
-- Examples: {"rare"}, {"epic", "legendary"}, etc.
groundRarityConfig.rarityFilter = nil

function init()
  g_logger.info("[Ground Rarity] Configuration loaded with style: " .. groundRarityConfig.style)
end

function terminate()
end

-- Get configuration for C++ (converts to format C++ can use)
function getGroundRarityConfig()
  return groundRarityConfig
end
