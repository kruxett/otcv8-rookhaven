--[[
  Ground Rarity Indicator Configuration
  
  This module provides configurable settings for rarity indicators on ground items.
  All settings can be easily adjusted here to tweak the visual appearance.
  
  Style recommendations:
  - "corner" - Best for showing off items in houses (clean, professional look)
  - "dot" - Minimal, subtle indicator (good for gameplay)
]]

-- Make groundRarityConfig available globally
_G.groundRarityConfig = _G.groundRarityConfig or {}
local groundRarityConfig = _G.groundRarityConfig

-- Enable/disable ground rarity indicators
groundRarityConfig.enabled = true

-- Indicator style: "dot" or "corner"
-- "corner" = L-shaped brackets in opposite corners (recommended for houses)
-- "dot" = Small colored square indicator
groundRarityConfig.style = "corner"

-- Dot indicator configuration (when style = "dot")
groundRarityConfig.dot = {
  size = 4,              -- Size in pixels (3-7 recommended)
  position = "bottom-right",  -- "top-left", "top-right", "bottom-left", "bottom-right"
  offsetX = 2,           -- Padding from edge (pixels)
  offsetY = 2            -- Padding from edge (pixels)
}

-- Corner indicator configuration (when style = "corner")
groundRarityConfig.corner = {
  length = 6,            -- Length of corner brackets (pixels) - adjust to frame items nicely
  thickness = 2,         -- Thickness of corner lines (pixels) - 1-2 recommended
  inset = 4              -- Distance from tile edge (pixels) - smaller = closer to item
}

-- Rarity colors (RGB format - customize to your preference)
groundRarityConfig.colors = {
  rare = {r = 0, g = 102, b = 255},        -- Blue
  epic = {r = 153, g = 51, b = 255},       -- Purple
  legendary = {r = 255, g = 170, b = 0}    -- Gold
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
