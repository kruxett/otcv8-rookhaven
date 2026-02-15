--[[
  Ground Rarity Indicator Configuration
  
  This module provides configurable settings for rarity indicators on ground items.
  All settings can be easily adjusted here to tweak the visual appearance.
]]

-- Make groundRarityConfig available globally
_G.groundRarityConfig = _G.groundRarityConfig or {}
local groundRarityConfig = _G.groundRarityConfig

-- Enable/disable ground rarity indicators
groundRarityConfig.enabled = true

-- Indicator style: "dot", "corner", "outline", "glow"
groundRarityConfig.style = "dot"

-- Dot indicator configuration (when style = "dot")
groundRarityConfig.dot = {
  size = 5,              -- Size in pixels (3-7 recommended)
  position = "bottom-right",  -- "top-left", "top-right", "bottom-left", "bottom-right"
  offsetX = 2,           -- Padding from edge (pixels)
  offsetY = 2            -- Padding from edge (pixels)
}

-- Corner indicator configuration (when style = "corner")
groundRarityConfig.corner = {
  length = 4,            -- Length of corner brackets (pixels)
  width = 2,             -- Thickness of corner lines (pixels)
  inset = 2              -- Distance from tile edge (pixels)
}

-- Outline configuration (when style = "outline")
groundRarityConfig.outline = {
  width = 1,             -- Line width (pixels)
  inset = 8,             -- Inset from tile edges (pixels, 0 = full tile)
  opacity = 60           -- Opacity 0-255
}

-- Glow configuration (when style = "glow")
groundRarityConfig.glow = {
  radius = 12,           -- Glow radius (pixels)
  opacity = 80           -- Opacity 0-255
}

-- Rarity colors (RGB format)
groundRarityConfig.colors = {
  rare = {r = 0, g = 102, b = 255},        -- Blue
  epic = {r = 153, g = 51, b = 255},       -- Purple
  legendary = {r = 255, g = 170, b = 0}    -- Gold
}

-- Rarity filter - set to nil to show all rarities
groundRarityConfig.rarityFilter = nil     -- Options: nil, {"rare"}, {"epic"}, {"legendary"}, etc.

function init()
  g_logger.info("[Ground Rarity] Configuration loaded with style: " .. groundRarityConfig.style)
end

function terminate()
end

-- Get configuration for C++ (converts to format C++ can use)
function getGroundRarityConfig()
  return groundRarityConfig
end
