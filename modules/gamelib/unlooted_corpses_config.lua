-- Unlooted Corpse Configuration
-- Customize visual markers for unlooted corpses

UnlootedCorpseConfig = {
  -- Enable/disable the system
  enabled = true,
  
  -- Debug mode (show console messages)
  debug = false,
  
  -- Visual marker settings
  marker = {
    -- Marker style: "glow", "icon", "tint"
    style = "glow",
    
    -- Glow effect color (R, G, B, Alpha) - Gold by default
    glowColor = { r = 255, g = 215, b = 0, a = 200 },
    
    -- Alternative colors:
    -- Green: { r = 0, g = 255, b = 0, a = 200 }
    -- Blue: { r = 0, g = 150, b = 255, a = 200 }
    -- Purple: { r = 200, g = 0, b = 255, a = 200 }
    
    -- Icon overlay (if style = "icon")
    iconPath = "/images/game/loot_indicator",
    
    -- Pulsing animation
    pulse = true,
    pulseSpeed = 0.3  -- Slower pulse (0.3 = 30% speed, more subtle)
  },
  
  -- Cleanup settings
  clearOnMapChange = true,
  clearOnLogout = true,

  -- Prevent reapply shortly after clearing (milliseconds)
  clearReapplySuppressMs = 2000,

  -- Server-side item data used for corpse identification
  corpseItemDataPath = "itemsfromserver/items.txt",
  corpseItemKeywords = { "corpse", "dead", "slain", "remains", "body", "bones" }
}

function UnlootedCorpseConfig.isEnabled()
  return UnlootedCorpseConfig.enabled
end

function UnlootedCorpseConfig.setEnabled(enabled)
  UnlootedCorpseConfig.enabled = enabled
  print("[UnlootedCorpse] System " .. (enabled and "enabled" or "disabled"))
end

function UnlootedCorpseConfig.getGlowColor()
  local c = UnlootedCorpseConfig.marker.glowColor
  return c.r, c.g, c.b, c.a
end

function UnlootedCorpseConfig.setGlowColor(r, g, b, a)
  UnlootedCorpseConfig.marker.glowColor = { r = r, g = g, b = b, a = a or 200 }
  print(string.format("[UnlootedCorpse] Glow color set to RGB(%d,%d,%d,%d)", r, g, b, a or 200))
end

-- Console commands for easy configuration
function unlootedCorpseToggle()
  UnlootedCorpseConfig.setEnabled(not UnlootedCorpseConfig.enabled)
end

function unlootedCorpseDebug()
  UnlootedCorpseConfig.debug = not UnlootedCorpseConfig.debug
  print("[UnlootedCorpse] Debug mode: " .. tostring(UnlootedCorpseConfig.debug))
end

function unlootedCorpseColor(r, g, b, a)
  UnlootedCorpseConfig.setGlowColor(r, g, b, a)
end

-- Example usage:
-- /lua unlootedCorpseToggle()  -- Enable/disable
-- /lua unlootedCorpseDebug()   -- Toggle debug messages
-- /lua unlootedCorpseColor(0, 255, 0, 200)  -- Change to green
