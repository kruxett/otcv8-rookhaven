# Client Logging Inventory

Generated: 2026-03-20 17:50:04

## Scope
- Root: otcv8-rookhaven
- File types: .lua, .cpp, .h, .hpp
- Excluded paths: vc16, .git, build, out, bin

## Patterns Counted
- g_logger.debug/info/warning/error/fatal/trace*
- g_logger.log(...)
- print(...)
- pinfo(...), perror(...), pwarning(...), pdebug(...)

## Totals
- Files with log calls: 147
- Total matched log calls: 790

## Top 20 Hotspots
| File | Count |
|---|---:|
| src/framework/core/resourcemanager.cpp | 50 |
| modules/corelib/check_unlooted.lua | 41 |
| src/client/protocolgameparse.cpp | 36 |
| src/framework/platform/x11window.cpp | 25 |
| src/framework/ui/uiwidget.cpp | 24 |
| src/framework/platform/win32window.cpp | 22 |
| test_load_affixes.lua | 20 |
| modules/corelib/util.lua | 18 |
| tools/update_server_checksums.lua | 14 |
| modules/game_bot/default_configs/vBot_4.7/cavebot/supply_check.lua | 13 |
| modules/game_bot/default_configs/vBot_4.8/cavebot/supply_check.lua | 13 |
| modules/game_affixes/affixes.lua | 12 |
| src/client/item.cpp | 12 |
| modules/game_cyclopedia/tab/bestiary/bestiary.lua | 11 |
| modules/game_market/marketoffer.lua | 11 |
| tools/generate_checksums.lua | 11 |
| src/client/localplayer.cpp | 10 |
| src/client/thingtypemanager.cpp | 10 |
| tools/lua-binding-generator/generate_lua_bindings.lua | 10 |
| src/client/spritemanager.cpp | 9 |

## Full File Inventory
| File | Count |
|---|---:|
| src/framework/core/resourcemanager.cpp | 50 |
| modules/corelib/check_unlooted.lua | 41 |
| src/client/protocolgameparse.cpp | 36 |
| src/framework/platform/x11window.cpp | 25 |
| src/framework/ui/uiwidget.cpp | 24 |
| src/framework/platform/win32window.cpp | 22 |
| test_load_affixes.lua | 20 |
| modules/corelib/util.lua | 18 |
| tools/update_server_checksums.lua | 14 |
| modules/game_bot/default_configs/vBot_4.7/cavebot/supply_check.lua | 13 |
| modules/game_bot/default_configs/vBot_4.8/cavebot/supply_check.lua | 13 |
| modules/game_affixes/affixes.lua | 12 |
| src/client/item.cpp | 12 |
| modules/game_cyclopedia/tab/bestiary/bestiary.lua | 11 |
| modules/game_market/marketoffer.lua | 11 |
| tools/generate_checksums.lua | 11 |
| src/client/localplayer.cpp | 10 |
| src/client/thingtypemanager.cpp | 10 |
| tools/lua-binding-generator/generate_lua_bindings.lua | 10 |
| src/client/spritemanager.cpp | 9 |
| src/framework/platform/androidwindow.cpp | 9 |
| modules/client_entergame/characterlist.lua | 8 |
| modules/game_bot/default_configs/vBot_4.7/cavebot/tasker.lua | 8 |
| modules/game_bot/default_configs/vBot_4.8/cavebot/tasker.lua | 8 |
| modules/game_cyclopedia/game_cyclopedia.lua | 8 |
| src/client/creatures.cpp | 8 |
| src/framework/luaengine/luainterface.cpp | 8 |
| src/framework/sound/soundmanager.cpp | 8 |
| modules/client_locales/locales.lua | 7 |
| modules/game_bot/default_configs/vBot_4.7/cavebot/clear_tile.lua | 7 |
| modules/game_bot/default_configs/vBot_4.8/cavebot/clear_tile.lua | 7 |
| modules/game_market/offerstatistic.lua | 7 |
| src/client/mapio.cpp | 7 |
| src/framework/graphics/graphics.cpp | 7 |
| src/framework/net/protocol.cpp | 7 |
| src/framework/ui/uimanager.cpp | 7 |
| src/framework/util/crypt.cpp | 7 |
| modules/game_console/console.lua | 6 |
| src/client/map.cpp | 6 |
| src/client/tile.cpp | 6 |
| src/framework/core/module.cpp | 6 |
| src/framework/graphics/framebuffer.cpp | 6 |
| src/main.cpp | 6 |
| modules/game_bot/bot.lua | 5 |
| modules/game_bot/default_configs/vBot_4.7/cavebot/d_withdraw.lua | 5 |
| modules/game_bot/default_configs/vBot_4.7/cavebot/sell_all.lua | 5 |
| modules/game_bot/default_configs/vBot_4.8/cavebot/d_withdraw.lua | 5 |
| modules/game_bot/default_configs/vBot_4.8/cavebot/sell_all.lua | 5 |
| modules/game_market/marketprotocol.lua | 5 |
| modules/game_shop/shop.lua | 5 |
| src/client/game.cpp | 5 |
| src/framework/graphics/shaderprogram.cpp | 5 |
| init.lua | 4 |
| modules/client_entergame/entergame.lua | 4 |
| modules/client_terminal/terminal.lua | 4 |
| modules/game_bot/default_configs/vBot_4.7/cavebot/buy_supplies.lua | 4 |
| modules/game_bot/default_configs/vBot_4.7/cavebot/depositor.lua | 4 |
| modules/game_bot/default_configs/vBot_4.7/cavebot/pos_check.lua | 4 |
| modules/game_bot/default_configs/vBot_4.7/cavebot/withdraw.lua | 4 |
| modules/game_bot/default_configs/vBot_4.7/vBot/cavebot_control_panel.lua | 4 |
| modules/game_bot/default_configs/vBot_4.8/cavebot/buy_supplies.lua | 4 |
| modules/game_bot/default_configs/vBot_4.8/cavebot/depositor.lua | 4 |
| modules/game_bot/default_configs/vBot_4.8/cavebot/pos_check.lua | 4 |
| modules/game_bot/default_configs/vBot_4.8/cavebot/withdraw.lua | 4 |
| modules/game_bot/default_configs/vBot_4.8/vBot/cavebot_control_panel.lua | 4 |
| modules/game_cyclopedia/tab/charms/charms.lua | 4 |
| src/client/minimap.cpp | 4 |
| src/framework/platform/unixcrashhandler.cpp | 4 |
| modules/corelib/test.lua | 3 |
| modules/corelib/ui/uitable.lua | 3 |
| modules/game_actionbar/actionbar.lua | 3 |
| modules/game_bot/default_configs/vBot_4.7/cavebot/inbox_withdraw.lua | 3 |
| modules/game_bot/default_configs/vBot_4.7/cavebot/travel.lua | 3 |
| modules/game_bot/default_configs/vBot_4.8/cavebot/inbox_withdraw.lua | 3 |
| modules/game_bot/default_configs/vBot_4.8/cavebot/travel.lua | 3 |
| modules/game_cyclopedia/tab/items/items.lua | 3 |
| modules/game_outfit/outfit.lua | 3 |
| modules/game_questlog/questlog.lua | 3 |
| src/client/protocolgamesend.cpp | 3 |
| src/framework/core/application.cpp | 3 |
| src/framework/core/graphicalapplication.cpp | 3 |
| src/framework/core/modulemanager.cpp | 3 |
| src/framework/graphics/atlas.cpp | 3 |
| src/framework/graphics/texture.cpp | 3 |
| src/framework/graphics/texturemanager.cpp | 3 |
| src/framework/luaengine/luavaluecasts.h | 3 |
| src/framework/platform/platformwindow.cpp | 3 |
| src/framework/platform/win32crashhandler.cpp | 3 |
| src/framework/sound/soundbuffer.cpp | 3 |
| src/framework/sound/streamsoundsource.cpp | 3 |
| src/framework/util/extras.h | 3 |
| modules/client/client.lua | 2 |
| modules/client_profiles/profiles.lua | 2 |
| modules/corelib/table.lua | 2 |
| modules/game_bot/default_configs/vBot_4.7/cavebot/bank.lua | 2 |
| modules/game_bot/default_configs/vBot_4.7/cavebot/cavebot.lua | 2 |
| modules/game_bot/default_configs/vBot_4.7/cavebot/doors.lua | 2 |
| modules/game_bot/default_configs/vBot_4.8/cavebot/bank.lua | 2 |
| modules/game_bot/default_configs/vBot_4.8/cavebot/cavebot.lua | 2 |
| modules/game_bot/default_configs/vBot_4.8/cavebot/doors.lua | 2 |
| modules/game_spelllist/spelllist.lua | 2 |
| modules/modulelib/watchlist.lua | 2 |
| src/client/container.cpp | 2 |
| src/client/houses.cpp | 2 |
| src/client/mapview.cpp | 2 |
| src/framework/core/configmanager.cpp | 2 |
| src/framework/core/logger.cpp | 2 |
| src/framework/graphics/fontmanager.cpp | 2 |
| src/framework/graphics/shader.cpp | 2 |
| src/framework/input/mouse.cpp | 2 |
| src/framework/otml/otmlnode.cpp | 2 |
| modules/client_checksums/checksums.lua | 1 |
| modules/client_topmenu/topmenu.lua | 1 |
| modules/corelib/inputmessage.lua | 1 |
| modules/corelib/orderedtable.lua | 1 |
| modules/corelib/outputmessage.lua | 1 |
| modules/corelib/ui/uiminiwindowcontainer.lua | 1 |
| modules/crash_reporter/crash_reporter.lua | 1 |
| modules/game_bot/default_configs/vBot_4.7/cavebot/actions.lua | 1 |
| modules/game_bot/default_configs/vBot_4.7/vBot/analyzer.lua | 1 |
| modules/game_bot/default_configs/vBot_4.8/cavebot/actions.lua | 1 |
| modules/game_bot/default_configs/vBot_4.8/vBot/analyzer.lua | 1 |
| modules/game_cyclopedia/tab/character/character.lua | 1 |
| modules/game_cyclopedia/tab/house/house.lua | 1 |
| modules/game_cyclopedia/tab/map/map.lua | 1 |
| modules/game_minimap/minimap.lua | 1 |
| modules/game_walking/walking.lua | 1 |
| modules/gamelib/textmessages.lua | 1 |
| modules/gamelib/unlooted_corpses_config.lua | 1 |
| src/client/protocolgame.cpp | 1 |
| src/client/statictext.cpp | 1 |
| src/client/thing.cpp | 1 |
| src/client/thingtype.cpp | 1 |
| src/framework/core/config.cpp | 1 |
| src/framework/core/eventdispatcher.cpp | 1 |
| src/framework/graphics/graph.cpp | 1 |
| src/framework/graphics/hardwarebuffer.cpp | 1 |
| src/framework/graphics/image.cpp | 1 |
| src/framework/graphics/painter.cpp | 1 |
| src/framework/graphics/paintershaderprogram.cpp | 1 |
| src/framework/http/http.cpp | 1 |
| src/framework/net/connection.cpp | 1 |
| src/framework/net/server.cpp | 1 |
| src/framework/platform/sdlwindow.cpp | 1 |
| src/framework/sound/oggsoundfile.cpp | 1 |
| src/framework/stdext/format.h | 1 |
| src/framework/ui/uianchorlayout.cpp | 1 |
