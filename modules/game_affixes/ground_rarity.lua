--[[
  Ground Rarity Border Configuration
  
  This module provides configurable settings for rarity borders on ground items.
  All settings can be easily adjusted here to tweak the visual appearance.
]]

-- Make groundRarityConfig available globally
_G.groundRarityConfig = _G.groundRarityConfig or {}
local groundRarityConfig = _G.groundRarityConfig

-- Enable/disable ground rarity borders
groundRarityConfig.enabled = true

-- Border rendering configuration
groundRarityConfig.borderWidth = 2        -- Pixel width of the border (1-4 recommended)
groundRarityConfig.borderOpacity = 0.8    -- Opacity of the border (0.0-1.0)
groundRarityConfig.borderInset = 1        -- Inset from item edge in pixels (0-2 recommended)

-- Glow/shimmer effect configuration  
groundRarityConfig.enableGlow = true      -- Enable outer glow effect
groundRarityConfig.glowWidth = 3          -- Width of glow blur (2-5 recommended)
groundRarityConfig.glowOpacity = 0.4      -- Opacity of glow (0.0-0.5 recommended)
groundRarityConfig.glowIntensity = 1.0    -- Intensity multiplier (0.5-2.0)

-- Pulsing animation configuration
groundRarityConfig.enablePulse = true     -- Enable pulsing/shimmer animation
groundRarityConfig.pulseClub = 1        -- Pulse color intensity variant (subtle intensity variation)
groundRarityConfig.pulseDuration = 2000   -- Duration of pulse cycle in milliseconds (1000-4000)

-- Rarity filter - set to nil to show all rarities, or specify array of rarities to show
groundRarityConfig.rarityFilter = nil     -- Options: nil (show all), {"rare"}, {"epic"}, {"legendary"}, {"rare", "epic"}, etc.

-- Distance-based fade (optional) - reduce border visibility at far distances
groundRarityConfig.enableDistanceFade = false
groundRarityConfig.maxFadeDistance = 10   -- Tiles at this distance will start fading

function init()
  g_logger.info("[Ground Rarity] Configuration loaded")
end

function getConfig()
  return groundRarityConfig
end
