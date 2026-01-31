-- CONFIG
APP_NAME = "Rookhaven"  -- important, change it, it's name for config dir and files in appdata
APP_VERSION = 1341       -- client version for updater and login to identify outdated client
DEFAULT_LAYOUT = "retro" -- on android it's forced to "mobile", check code bellow

-- If you don't use updater or other service, set it to updater = ""
Services = {
  website = "", -- currently not used
  updater = "",
  stats = "",
  crash = "",
  feedback = "",
  status = ""
}

-- Servers accept http login url, websocket login url or ip:port:version
-- The default is baked into the executable via DEFAULT_SERVER_ENDPOINT (see CMake DEFAULT_SERVER_ENDPOINT)
Servers = {}
if DEFAULT_SERVER_ENDPOINT then
  Servers.Default = DEFAULT_SERVER_ENDPOINT
end

--Server = "ws://otclient.ovh:3000/"
--Server = "ws://127.0.0.1:88/"
--USE_NEW_ENERGAME = true -- uses entergamev2 based on websockets instead of entergame
ALLOW_CUSTOM_SERVERS = false -- if true it shows option ANOTHER on server list

g_app.setName("Rookhaven Client")
-- CONFIG END

-- print first terminal message
g_logger.info(os.date("== application started at %b %d %Y %X"))
g_logger.info(g_app.getName() .. ' ' .. g_app.getVersion() .. ' rev ' .. g_app.getBuildRevision() .. ' (' .. g_app.getBuildCommit() .. ') made for ' .. g_app.getAuthor() .. ' built on ' .. g_app.getBuildDate() .. ' for arch ' .. g_app.getBuildArch())

if not g_resources.directoryExists("/data") then
  g_logger.fatal("Data dir doesn't exist.")
end

if not g_resources.directoryExists("/modules") then
  g_logger.fatal("Modules dir doesn't exist.")
end

-- settings
g_configs.loadSettings("/config.otml")

-- Seed default settings so first run has a valid server/host (after settings are initialized)
if Servers.Default and g_settings then
  g_settings.setDefault('server', 'Default')
  g_settings.setDefault('host', Servers.Default)
end

-- set layout (forced to retro)
local layout = "retro"
if g_app.isMobile() then
  layout = "mobile"
end
g_resources.setLayout(layout)

-- load mods
g_modules.discoverModules()
g_modules.ensureModuleLoaded("corelib")
  
local function loadModules()
  -- libraries modules 0-99
  g_modules.autoLoadModules(99)
  g_modules.ensureModuleLoaded("gamelib")

  -- client modules 100-499
  g_modules.autoLoadModules(499)
  g_modules.ensureModuleLoaded("client")

  -- game modules 500-999
  g_modules.autoLoadModules(999)
  g_modules.ensureModuleLoaded("game_interface")
  
  -- Explicitly load game_affixes module
  g_logger.info("Attempting to load game_affixes module...")
  local affixModule = g_modules.getModule("game_affixes")
  if affixModule then
    g_logger.info("Found game_affixes module, loading...")
    g_modules.ensureModuleLoaded("game_affixes")
  else
    g_logger.warning("game_affixes module not found!")
  end

  -- mods 1000-9999
  g_modules.autoLoadModules(9999)
end

-- report crash
if type(Services.crash) == 'string' and Services.crash:len() > 4 and g_modules.getModule("crash_reporter") then
  g_modules.ensureModuleLoaded("crash_reporter")
end

-- run updater, must use data.zip
if type(Services.updater) == 'string' and Services.updater:len() > 4 
  and g_resources.isLoadedFromArchive() and g_modules.getModule("updater") then
  g_modules.ensureModuleLoaded("updater")
  return Updater.init(loadModules)
end
loadModules()
