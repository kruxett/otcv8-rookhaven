-- Offline start-up smoke for a prepared release package: the published EXE must
-- load the new archive, report the DEV version and know the newest item IDs.
local done=false
scheduleEvent(function()
 local ok,e=pcall(function()
  assert(LOCAL_PASSIVES_TEST and Services.updater=='','Loopback-only smoke')
  g_game.setClientVersion(860);g_game.setProtocolVersion(860)
  local compatible,message=modules.game_features.validateRookhavenAssets(860)
  assert(compatible,'Asset gate refused the packaged item table: '..tostring(message))
  local newest=g_things.getThingType(11894,ThingCategoryItem)
  assert(newest and newest:getId()==11894,'Packaged item table lacks the newest client ID')
  print('RELEASE_PACKAGE_SMOKE_OK version='..tostring(APP_VERSION)..' items='..#g_things.getThingTypes(ThingCategoryItem)..' layout='..g_resources.getLayout())
 end)
 if not ok then print('RELEASE_PACKAGE_SMOKE_FAILED '..tostring(e))end
 done=true;g_app.exit()
end,1500)
scheduleEvent(function()if not done then print('RELEASE_PACKAGE_SMOKE_FAILED timeout');g_app.exit()end end,20000)
