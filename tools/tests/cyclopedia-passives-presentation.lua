-- Fresh Cyclopedia source and real retro widgets; no network/game mutation.
assert(LOCAL_PASSIVES_TEST and not g_game.isOnline())
-- This offline widget harness does not need Discord's native IPC lifecycle.
if modules.client_discord then modules.client_discord.terminate() end
local realGame, realUI = g_game, g_ui
local mod = assert(modules.game_cyclopedia)
local finished = false
local host, controls, panel
local function fail(reason)
  if finished then return end
  finished = true
  print('CYCLOPEDIA_PASSIVES_FAILED ' .. tostring(reason))
  if host then host:destroy() end
  if controls then controls:destroy() end
  scheduleEvent(function() g_app.exit() end, 100)
end
local function later(ms, fn)
  scheduleEvent(function()
    if finished then return end
    local ok, reason = pcall(fn)
    if not ok then fail(reason) end
  end, ms)
end
local player = {
  getName=function() return 'Cyclopedia QA' end,
  getLevel=function() return 40 end,
  getVocation=function() return 3 end,
  -- The offline client has not loaded a game's thing/sprite catalog.
  getOutfit=function() return {type=0} end,
  getInventoryItem=function() return nil end,
  getMoney=function() return 0 end,
  getBankBalance=function() return 950 end,
  getSkillLevel=function() return 10 end,
  getSkillBaseLevel=function() return 10 end,
  getSkillLevelPercent=function() return 0 end,
}
local env, cyclopedia, requests = nil, nil, 0
local function text(widget)
  local out = widget.getText and widget:getText() or ''
  for _, child in ipairs(widget:getChildren()) do out = out .. '\n' .. text(child) end
  return out
end
later(100, function()
  realUI.importStyle('/modules/game_cyclopedia/cyclopedia_widgets.otui')
  g_window.resize({width=1280,height=800})
  host = realUI.createWidget('Panel', realUI.getRootWidget())
  host:setBackgroundColor('#303030')
  host:setSize({width=720,height=480});host:addAnchor(AnchorHorizontalCenter,'parent',AnchorHorizontalCenter);host:addAnchor(AnchorVerticalCenter,'parent',AnchorVerticalCenter)
  controls = realUI.createWidget('Panel', realUI.getRootWidget())
  for _, id in ipairs({'CharmsBase','GoldBase','BestiaryTrackerButton'}) do
    local widget=realUI.createWidget('UIWidget',controls);widget:setId(id)
  end
  cyclopedia = {clientCombat=mod.Cyclopedia.clientCombat, InventorySlotStyles=mod.Cyclopedia.InventorySlotStyles}
  cyclopedia.sendCyclopediaRequest=function() requests=requests+1;return true,true end
  env = {
    Cyclopedia=cyclopedia, contentContainer=host,
    controllerCyclopedia={ui=controls}, connect=function()end, disconnect=function()end,
    g_game=setmetatable({isOnline=function()return true end,getLocalPlayer=function()return player end,
      getClientVersion=function()return 860 end,getFightMode=function()return FightOffensive end,
      requestCharacterInfo=function()requests=requests+1 end},{__index=realGame}),
    g_ui=setmetatable({loadUI=function(name,parent)
      assert(name=='character')
      return realUI.loadUIFromString(g_resources.readFileContents('/cyclopedia-character-layout.txt'),parent)
    end},{__index=realUI})
  }
  env._G=env;setmetatable(env,{__index=mod})
  local chunk=assert(loadstring(g_resources.readFileContents('/cyclopedia-character-source.txt'),'@fresh-character.lua'))
  setfenv(chunk,env);chunk();env.showCharacter()
  panel=host:getChildById('Cat6');assert(panel and panel.PassiveStats,'Fresh passive page failed to load')
  assert(host:recursiveGetChildById('Cat6')==panel,'Real-widget recursive character-panel lookup failed')
  cyclopedia.setServerCharacterTitle('Reaver')
  cyclopedia.setCharacterIdentity({className='Reaver',ascension='Ascended'})
  local profile=text(panel.InfoBase.DetailsBase.List)
  assert(profile:find('Class: Reaver',1,true) and profile:find('Ascension: Ascended',1,true),'Class and Ascension identity mixed')
  assert(panel.CharacterBase.InfoLabel:getText():find('Reaver',1,true),'Profile headline retained Ascended')
  local stats={active=true,permanent=true,weaponActive=true,className='Reaver',weaponName='Axe',spent=5,points=24,
    maxHealthBonus=66,maxHealthPercent=5,ordinaryDamagePercent=2.5,eligibleSpellDamagePercent=2.5,
    legacyCriticalThreshold=10,legacyCriticalChance=3.027955566444207,passiveCriticalChance=2.5,
    criticalChance=5.452256677283102,criticalMultiplier=210,manaDiscountPercent=3,manaPerSecond=.075,
    damageRecoveryPercent=.4,killRecoveryPercent=.2,incomingHealingPercent=2,physicalReductionPercent=1.5,
    baseMaxHit=20,baseElementMaxHit=0,ordinaryMaxHit=21,ward=3,routeReturnBudget=.75,routeReturnMs=1500}
  cyclopedia.loadCharacterPassives({stats=stats,talents={{name='Vitality',rank=3,benefit='+3% max HP',description='Requires an axe.'}}})
  assert(cyclopedia.characterPassiveStats==stats,'Native stat snapshot was dropped')
  local passiveText=text(panel.PassiveStats.List)
  assert(passiveText:find('+66 (5.00%)',1,true) and passiveText:find('+0.075 / second',1,true),'Fractional/resource bonuses lost')
  assert(passiveText:find('Vitality',1,true) and passiveText:find('Rank 3',1,true),'Applied ranks missing')
  assert(passiveText:find('Gear critical threshold',1,true) and passiveText:find('3.03%',1,true),
    'Legacy gear threshold was treated as a uniform chance')
  assert(passiveText:find('0.75 HP (1.5s)',1,true),'Prepared return healing budget or expiry was lost')
  cyclopedia.loadCharacterCombatStats({weaponElement=0,weaponMaxHitChance=21,weaponElementDamage=0,
    weaponSkillId=3,armor=9,defense=10,attackSpeed=2000,passiveStats=stats},0,
    {{Skill.CriticalChance,stats.criticalChance},{Skill.CriticalDamage,stats.criticalMultiplier}}, {}, {}, {}, {})
  assert(panel.CombatStats.defence.value:getText()=='5.45%' and panel.CombatStats.dps.value:getText()=='5.3',
    'Combined critical probability or DPS estimate was dropped')
  assert(panel.CombatStats.passiveReduction.value:getText()=='1.50%','Passive reduction was omitted from combat summary')
  panel.InfoBase:hide();panel.PassiveStats:show()
  local general=panel.OptionsBase:getChildByIndex(1)
  general.Button.onClick(general.Button)
  local category
  for _, child in ipairs(general:getChildren()) do if child.open=='PassiveStats' then category=child end end
  assert(category,'Passive Talents category is absent')
  category.Button.onClick(category.Button)
  assert(panel.PassiveStats:isVisible(),'Category did not select real passive page')
  for _, row in ipairs(panel.PassiveStats.List:getChildren()) do
    assert(row:getHeight()>0 and row:getWidth()>0,'Passive row has empty geometry')
    assert(row:getTooltip()~='' or row:getId()~=nil,'Passive row unavailable')
  end
  print('CYCLOPEDIA_PASSIVES_UI_OK identity=true nativeStats=true fractionalResources=true appliedRanks=true category=true criticalProbability=true returnBudget=true combatSummary=true')
  later(600,function()
    if CYCLOPEDIA_PASSIVES_SCREENSHOTS ~= false then g_app.doScreenshot('/cyclopedia-passives-1280x800.png') end
    later(300,function()
    local inactiveStats={active=true,permanent=true,weaponActive=false,className='Reaver',weaponName='Axe',spent=5,points=24,
      baseMaxHit=20,ordinaryMaxHit=21,criticalChance=0,criticalMultiplier=200,ward=3,
      partyQuarryDamagePercent=5,ordinaryDamagePercent=5}
    cyclopedia.loadCharacterPassives({stats=inactiveStats,talents={{name='Vitality',rank=3,benefit='+3% max HP',description='Requires an axe.'}}})
    local inactive=text(panel.PassiveStats.List)
    assert(inactive:find('Inactive',1,true) and inactive:find('+0 (0.00%)',1,true) and inactive:find('Rank 3',1,true),'Weapon-off state lost ranks or retained HP bonus')
    assert(not inactive:find('2.50%',1,true) and not inactive:find('1.50%',1,true),'Weapon-off state retained damage or reduction')
    assert(inactive:find('Party Quarry bonus',1,true) and inactive:find('5.00%',1,true),'Party Quarry was incorrectly hidden by incompatible own weapon')
    print('CYCLOPEDIA_PASSIVES_WEAPON_GATE_UI_OK')
    g_window.resize({width=800,height=640})
    later(600,function()
      if CYCLOPEDIA_PASSIVES_SCREENSHOTS ~= false then g_app.doScreenshot('/cyclopedia-passives-800x640.png') end
      cyclopedia.loadCharacterPassives({stats={active=false,permanent=true,weaponActive=false,className='Reaver',
        weaponName='Axe',spent=5,points=24},talents={{name='Vitality',rank=3}}})
      local dormant=text(panel.PassiveStats.List)
      assert(dormant:find('Reaver',1,true) and dormant:find('Inactive',1,true)
        and dormant:find('Rank 3',1,true) and dormant:find('+0 (0.00%)',1,true),
        'Inactive permanent class lost identity/ranks or retained own effects')
      print('CYCLOPEDIA_PASSIVES_DORMANT_PERMANENT_UI_OK')
      host:destroy();host=nil;controls:destroy();controls=nil
      finished=true
      print('CYCLOPEDIA_PASSIVES_PRESENTATION_OK offline=true network=false')
      print('CYCLOPEDIA_PASSIVES_SCREENSHOT_DIRECTORY '..g_resources.getWriteDir())
      scheduleEvent(function()g_app.exit()end,150)
    end)
    end)
  end)
end)
