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
    r = 0,        -- Red (0-255)
    g = 150,      -- Green (0-255) - subtle green
    b = 100,      -- Blue (0-255) - slight teal undertone
    a = 80,       -- Alpha/Opacity (0-255) - subtle visibility (80 = very subtle)
  },
  
  -- PULSE ANIMATION SETTINGS
  animation = {
    speed = 0.8,        -- Speed modifier (1.0 = normal, 2.0 = 2x faster, 0.5 = half speed)
    intensity = 0.4,    -- Brightness of glow (0.0 = invisible, 1.0 = bright, recommended 0.4-0.8)
    
    -- Direction of pulse wave
    -- 0 = left to right
    -- 1 = right to left
    -- 2 = top to bottom
    -- 3 = bottom to top
    direction = 3,      -- Bottom to top pulse (subtle)
  },
  
  -- DEBUG
  debug = false,
}

-- =================================================================================
-- COLOR PRESETS - Uncomment a preset to use it
-- =================================================================================

-- Subtle Green (current default - bottom to top pulse)
-- CorpseGlowConfig.glowColor = {r = 0, g = 150, b = 100, a = 80}  -- Very subtle teal-green

-- Light Green (more visible)
-- CorpseGlowConfig.glowColor = {r = 50, g = 180, b = 80, a = 100}

-- Bright Green (very visible)
-- CorpseGlowConfig.glowColor = {r = 0, g = 255, b = 0, a = 150}

-- Golden Yellow (original)
-- CorpseGlowConfig.glowColor = {r = 255, g = 215, b = 0, a = 150}

-- =================================================================================
-- ANIMATION PRESETS - Uncomment a preset to use it
-- =================================================================================

-- Subtle bottom-up pulse (current default)
-- CorpseGlowConfig.animation = {speed = 0.8, intensity = 0.4, direction = 3}

-- Slow gentle pulse (left to right)
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
