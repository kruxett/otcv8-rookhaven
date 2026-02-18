function init()
  -- add manually your shaders from /data/shaders

  -- map shaders
  g_shaders.createShader("map_default", "/shaders/map_default_vertex", "/shaders/map_default_fragment")  

  g_shaders.createShader("map_rainbow", "/shaders/map_rainbow_vertex", "/shaders/map_rainbow_fragment")
  g_shaders.addTexture("map_rainbow", "/images/shaders/rainbow.png")

  -- use modules.game_interface.gameMapPanel:setShader("map_rainbow") to set shader

  -- outfit shaders
  g_shaders.createOutfitShader("outfit_default", "/shaders/outfit_default_vertex", "/shaders/outfit_default_fragment")

  g_shaders.createOutfitShader("outfit_rainbow", "/shaders/outfit_rainbow_vertex", "/shaders/outfit_rainbow_fragment")
  g_shaders.addTexture("outfit_rainbow", "/images/shaders/rainbow.png")

  -- you can use creature:setOutfitShader("outfit_rainbow") to set shader

  -- item rarity outline shaders
  g_shaders.createShader("item_rare", "/shaders/item_outline_vertex", "/shaders/item_rare_fragment")
  g_shaders.createShader("item_epic", "/shaders/item_outline_vertex", "/shaders/item_epic_fragment")
  g_shaders.createShader("item_legendary", "/shaders/item_outline_vertex", "/shaders/item_legendary_fragment")

  -- corpse glow shader (subtle pulsing glow for unlooted corpses)
  g_shaders.createShader("corpse_glow", "/shaders/corpse_glow_vertex", "/shaders/corpse_glow_fragment")

end

function terminate()
end


