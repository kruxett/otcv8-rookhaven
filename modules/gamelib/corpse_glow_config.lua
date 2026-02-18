-- =================================================================================
-- CORPSE GLOW SHADER CONFIGURATION
-- =================================================================================
-- This configuration controls the pulsing glow effect for unlooted corpses
-- All settings are easily customizable without modifying shader files

CorpseGlowConfig = {
  -- Enable/disable the shader effect
  enabled = true,
  
  -- GLOW COLOR (RGB values 0-255)
  glowColor = {
    r = 255,      -- Red (0-255)
    g = 215,      -- Green (0-255) - 215 gives gold/yellow tone
    b = 0,        -- Blue (0-255)
    a = 200,      -- Alpha/Opacity (0-255) - higher = more opaque
  },
  
  -- PULSE ANIMATION SETTINGS
  animation = {
    speed = 1.5,        -- Speed modifier (1.0 = normal, 2.0 = 2x faster, 0.5 = half speed)
    intensity = 0.6,    -- Brightness of glow (0.0 = invisible, 1.0 = bright, recommended 0.4-0.8)
    
    -- Direction of pulse wave
    -- 0 = left to right
    -- 1 = right to left
    -- 2 = top to bottom
    -- 3 = bottom to top
    direction = 0,      -- Default: left to right
  },
  
  -- DEBUG
  debug = false,
}

-- =================================================================================
-- COLOR PRESETS - Uncomment a preset to use it
-- =================================================================================

-- Golden Yellow (default unlooted look)
-- CorpseGlowConfig.glowColor = {r = 255, g = 215, b = 0, a = 200}

-- Bright Gold
-- CorpseGlowConfig.glowColor = {r = 255, g = 255, b = 0, a = 220}

-- Red (danger/warning)
-- CorpseGlowConfig.glowColor = {r = 255, g = 0, b = 0, a = 200}

-- Cyan (cool/tech)
-- CorpseGlowConfig.glowColor = {r = 0, g = 255, b = 255, a = 180}

-- Purple (mystical)
-- CorpseGlowConfig.glowColor = {r = 200, g = 0, b = 255, a = 190}

-- Green (nature/heal)
-- CorpseGlowConfig.glowColor = {r = 0, g = 200, b = 100, a = 180}

-- Orange (fire/energy)
-- CorpseGlowConfig.glowColor = {r = 255, g = 165, b = 0, a = 200}

-- White (holy/pure)
-- CorpseGlowConfig.glowColor = {r = 255, g = 255, b = 255, a = 180}

-- =================================================================================
-- ANIMATION PRESETS - Uncomment a preset to use it
-- =================================================================================

-- Slow, gentle pulse
-- CorpseGlowConfig.animation = {speed = 0.8, intensity = 0.4, direction = 0}

-- Fast, strong pulse
-- CorpseGlowConfig.animation = {speed = 2.5, intensity = 0.8, direction = 0}

-- Vertical pulse (top to bottom)
-- CorpseGlowConfig.animation = {speed = 1.5, intensity = 0.6, direction = 2}

-- Reverse horizontal (right to left)
-- CorpseGlowConfig.animation = {speed = 1.5, intensity = 0.6, direction = 1}

-- =================================================================================
-- FUNCTIONS
-- =================================================================================

function CorpseGlowConfig.getGlowColorVec4()
  local c = CorpseGlowConfig.glowColor
  return {
    r = c.r / 255.0,
    g = c.g / 255.0,
    b = c.b / 255.0,
    a = c.a / 255.0,
  }
end

function CorpseGlowConfig.getAnimationDirection()
  return CorpseGlowConfig.animation.direction or 0
end

function CorpseGlowConfig.getPulseSpeed()
  return CorpseGlowConfig.animation.speed or 1.5
end

function CorpseGlowConfig.getPulseIntensity()
  return CorpseGlowConfig.animation.intensity or 0.6
end

function CorpseGlowConfig.isEnabled()
  return CorpseGlowConfig.enabled ~= false
end
