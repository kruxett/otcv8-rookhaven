-- Offline sprite-render check using the existing pre-integrity QA renderer.
-- No connection or distributed-package certification is performed here.
APP_NAME = 'Rookhaven Premium Scroll Render QA'
APP_VERSION = 1
Services = {}
g_app.setName(APP_NAME)
g_resources.setLayout('retro')
g_modules.discoverModules()
for _, name in ipairs({'corelib', 'gamelib', 'client_styles'}) do g_modules.ensureModuleLoaded(name) end
g_game.setClientVersion(860)
g_game.setProtocolVersion(860)
assert(g_things.loadDat('/things/860/Tibia'))
assert(g_sprites.loadSpr('/things/860/Tibia'))
g_window.resize({width=320,height=160})
scheduleEvent(function()
    local root = g_ui.getRootWidget()
    root:setBackgroundColor('#3b3b3b')
    local panel = g_ui.createWidget('UIWidget', root)
    panel:setRect({x=12,y=12,width=196,height=64})
    panel:setBackgroundColor('#292929')
    for index, cid in ipairs({11895,11896,11897}) do
        local slot = g_ui.createWidget('InventoryItem', panel)
        slot:setRect({x=28+(index-1)*54,y=26,width=34,height=34})
        slot:setItemId(cid)
        assert(slot:getItemId()==cid)
    end
    scheduleEvent(function()
        g_app.doScreenshot('/premium-scroll-owned-render.png')
        print('PREMIUM_SCROLL_RENDER_OK writeDir=' .. g_resources.getWriteDir())
        scheduleEvent(function()g_app.exit()end,600)
    end,700)
end,300)
