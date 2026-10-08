-- Fresh source, real retro widgets, authoritative supplied snapshots.
-- Offline fixtures exercise rendering only; native.lua checks the real server.
assert(LOCAL_PASSIVES_TEST and not g_game.isOnline())
if modules.client_discord then modules.client_discord.terminate() end
local realGame, realUI, mod = g_game, g_ui, assert(modules.game_cyclopedia)
local finished, host, controls, panel, env, cyclopedia = false
local requests = 0
local function fail(reason)
  if finished then return end
  finished=true;print('CYCLOPEDIA_PASSIVES_FAILED '..tostring(reason))
  if host then host:destroy() end;if controls then controls:destroy() end
  scheduleEvent(function()g_app.exit()end,100)
end
local function later(ms,fn)
  scheduleEvent(function()if not finished then local ok,e=pcall(fn);if not ok then fail(e)end end end,ms)
end
local player={getName=function()return 'Cyclopedia QA'end,getLevel=function()return 40 end,
  getVocation=function()return 3 end,getOutfit=function()return{type=0}end,
  getInventoryItem=function()return nil end,getMoney=function()return 0 end,
  getBankBalance=function()return 950 end,getSkillLevel=function()return 10 end,
  getSkillBaseLevel=function()return 10 end,getSkillLevelPercent=function()return 0 end}
local function text(widget)
  local value=widget.getText and widget:getText()or''
  for _,child in ipairs(widget:getChildren())do value=value..'\n'..text(child)end
  return value
end
local function selectPage(id)
  local general=panel.OptionsBase:getChildByIndex(1)
  if not general.opened then signalcall(general.Button.onClick,general.Button)end
  for _,child in ipairs(general:getChildren())do if child.open==id then
    signalcall(child.Button.onClick,child.Button);assert(panel[id]:isVisible(),'Category did not select '..id);return
  end end
  error('Missing character category '..id)
end
local function click(list,id)
  local row=assert(list:getChildById(id),'Missing actual row '..id)
  signalcall(row.onClick,row);return row
end
local function screenshot(name)
  if CYCLOPEDIA_PASSIVES_SCREENSHOTS~=false then g_app.doScreenshot('/'..name..'.png')end
end
local stats={active=true,permanent=true,weaponActive=true,className='Reaver',weaponName='Axe',spent=5,points=24,
  maxHealth=1401,baseMaxHealth=1335,maxHealthBonus=66,maxHealthPercent=5,armor=9,defense=10,
  ordinaryDamagePercent=2.5,eligibleSpellDamagePercent=2.5,legacyCriticalThreshold=10,
  legacyCriticalChance=3.027955566444207,passiveCriticalChance=2.5,criticalChance=5.452256677283102,
  criticalMultiplier=210,manaDiscountPercent=3,manaPerSecond=.075,currentManaPerSecond=.075,
  damageRecoveryPercent=.4,killRecoveryPercent=.2,incomingHealingPercent=2,physicalReductionPercent=1.5,
  baseMaxHit=20,baseElementMaxHit=0,ordinaryMaxHit=21,ward=3,routeReturnBudget=.75,routeReturnMs=1500}
local talents={{name='Vitality',rank=3,benefit='+3% max HP',description='Requires an axe.'},
  {name='Steady Nerves',rank=1,benefit='+2% healing received; protection below half health',description='Requires an axe.'}}
local presentation={version=1,header={className='Reaver',weaponName='Axe',weaponActive=true,reason='Talent bonuses active',spent=5,points=24},
  overview={
    {id='normalMaxHit',group='offence',label='Maximum normal hit',value=21,unit='HP',hint='Before target protection',sources={{label='Base',value=20,unit='HP'},{label='Talents',value=1,unit='HP'}}},
    {id='criticalChance',group='offence',label='Critical hit chance',value=stats.criticalChance,unit='%',hint='Against monsters',sources={{label='Equipment',value=stats.legacyCriticalChance,unit='%'},{label='Extra talent roll',value=2.5,unit='%'}},description='Equipment and talent rolls are separate; the total is not their sum.'},
    {id='maxHealth',group='defence',label='Maximum HP',value=1401,unit='HP',sources={{label='Base',value=1335,unit='HP'},{label='Talents',value=66,unit='HP'},{label='Other effects',value=0,unit='HP'}}},
    {id='manaRegen',group='recovery',label='Mana regeneration',value=.075,unit='mana / s',sources={{label='Talents',value=.075,unit='mana / s'}}},
    {id='incomingHealing',group='recovery',label='Healing received',value=2,unit='%',sources={{label='Steady Nerves',value=2,unit='%'}}}
  },talents={statBonuses={
    {id='vitality_stat',label='Vitality',rank=3,value=66,unit='HP',status='Active',detail='Maximum HP from saved talents.'},
    {id='steady_healing',label='Steady Nerves',rank=1,value=2,unit='%',status='Active',detail='Healing received while using an axe.'}},
    conditionalEffects={{id='steady_guard',label='Steady Nerves',rank=1,value=0,unit='%',status='Inactive',hint='Requires below half health',detail='Damage protection below half health.'}},
    specialEffects={{id='bloodletting_special',label='Bloodletting',rank=1,status='Active',detail='Normal axe attacks can cause bleeding.'}}}}
local function payload(p,s,t)return{stats=s or stats,talents=t or talents,presentation=p}end
local function checkGrouped()
  local a=panel.CombatStats.Viewport.Content
  assert(a.offensiveHit and a.criticalHit and a.separator,'Original two-column structure missing')
  assert(a.attack:getHeight()==20 and a.atkSpeed:getHeight()==20,'Original compact rows changed')
  assert(not panel.CombatStats:getChildById('CurrentOverview'),'Replacement overview still covers original stats')
  assert(not panel.CombatSources:isVisible(),'Source window consumes space before a click')
  local function source(id)
    local row=assert(cyclopedia.getCombatStatRow(id),'Missing relevant stat '..id)
    signalcall(row.onClick,row)
    assert(panel.CombatSources:isVisible(),'Source click did not open native window')
    return row
  end
  source('maxHealth')
  local hp=text(panel.CombatSources.Content)
  assert(hp:find('1335',1,true)and hp:find('66',1,true),'Actual HP sources lost')
  local row=source('criticalChance')
  assert(row.value:getText():find('5.45',1,true),'Combined critical rolls were summed or rounded')
  assert(text(panel.CombatSources.Content):find('not their sum',1,true),'Critical roll explanation absent')
  cyclopedia.loadCharacterPassives(payload(presentation))
  assert(text(panel.CombatSources.Content):find('not their sum',1,true),'Refresh lost selected source')
  source('manaRegen')
  assert(text(panel.CombatSources.Content):find('0.075',1,true),'Fractional regeneration lost precision')
  selectPage('PassiveStats')
  assert(not panel.CombatSources:isVisible(),'Sources leaked onto a different page')
  selectPage('CharacterStats')
  source('maxHealth')
  assert(panel.CharacterStats:isVisible(),'Health sources not available in General Stats')
  signalcall(panel.CombatSources.Close.onClick,panel.CombatSources.Close)
  assert(not panel.CombatSources:isVisible(),'Optional sources cannot be closed')
  selectPage('PassiveStats')
  local b=panel.PassiveStats
  for _,group in ipairs({'statBonuses','conditionalEffects','specialEffects'})do assert(b.List:getChildById('section_'..group),'Missing talent group '..group)end
  assert(#b.List:getChildren()<15,'Generic zero-row dump retained')
  local constant=click(b.List,'talent_steady_healing')
  assert(constant.Hint:getText():find('Active',1,true),'Constant healing marked inactive above half health')
  local condition=click(b.List,'talent_steady_guard')
  assert(condition.Hint:getText():find('Inactive',1,true),'Low-health-only protection marked universally active')
  cyclopedia.loadCharacterPassives(payload(presentation))
  assert(text(b.SourceDetails.Content):find('below half health',1,true),'Talent selection lost on refresh')
  assert(b.List:getChildById('talent_bloodletting_special'),'Chosen special effect omitted')
  print('CYCLOPEDIA_PASSIVES_UI_OK groups=true sourceClick=true fractionalResources=true independentCritical=true mixedSteadyNerves=true selectedRefresh=true')
end
local function checksFallback()
  local inactive={active=true,permanent=true,weaponActive=false,className='Reaver',weaponName='Axe',spent=5,points=24,
    maxHealth=1335,baseMaxHealth=1335,baseMaxHit=20,ordinaryMaxHit=21,criticalChance=0,criticalMultiplier=200,
    partyQuarryDamagePercent=5,ordinaryDamagePercent=5,rankManaPerSecond=.075}
  local p={version=1,header={className='Reaver',weaponName='Axe',weaponActive=false,
    reason='Equip an axe to activate talent bonuses.',spent=5,points=24},overview={{id='manaRegen',group='recovery',label='Mana regeneration',value=0,unit='mana / s',sources={}}},
    talents={statBonuses={{id='vitality_stat',label='Vitality',rank=3,value=0,unit='HP',status='Inactive',detail='Requires an axe.'}},conditionalEffects={},specialEffects={}}}
  cyclopedia.loadCharacterPassives(payload(p,inactive))
  local mana=assert(cyclopedia.getCombatStatRow('manaRegen'),'Learned inactive regeneration was hidden')
  assert(mana.Value:getText():find('0',1,true),'Wrong weapon retained regeneration')
  assert(text(panel.PassiveStats.Header):find('Equip an axe',1,true),'Missing weapon activation reason')
  local row=assert(panel.PassiveStats.List:getChildById('talent_vitality_stat'))
  assert(row.Hint:getText():find('Inactive',1,true),'Weapon-off status retained bonuses')
  signalcall(row.onClick,row)
  assert(text(panel.PassiveStats.SourceDetails.Content):find('3',1,true),'Weapon-off state lost saved rank')
  cyclopedia.loadCharacterPassives({stats=inactive,talents=talents})
  local fallback=text(panel.PassiveStats)
  assert(fallback:find('Vitality',1,true)and fallback:find('Steady Nerves',1,true),'Old server fallback lost saved catalog benefits')
  assert(#panel.CombatStats.Viewport.Content.OffenceExtras:getChildren()==0 and not panel.CombatSources:isVisible(),'Old server fallback retained unsupported source amounts')
  cyclopedia.loadCharacterPassives({stats={active=false,permanent=false,weaponActive=false,spent=0,points=0},talents={}})
  assert(#panel.PassiveStats.List:getChildren()<8,'Unclassed empty profile retained stale talents/zero dump')
  assert(not text(panel.PassiveStats.List):find('Vitality',1,true),'Logout/unclassed snapshot retained another character talents')
  print('CYCLOPEDIA_PASSIVES_COMPATIBILITY_OK incompatibleWeapon=true savedRanks=true oldServer=true unclassed=true')
end
local function checkIdentity()
  for _,class in ipairs({'Reaver','Blademaster','Earthshaker','Marksman','Arcanist','Lifekeeper'})do
    cyclopedia.setCharacterIdentity({className=class,ascension='Ascended'})
    local header=panel.CharacterBase.InfoLabel:getText()
    assert(header:find('\n'..class..'\nAscension: Ascended',1,true),'Class and progression mixed '..class)
  end
  cyclopedia.setCharacterIdentity({className='',ascension='Ascended'})
  assert(panel.CharacterBase.InfoLabel:getText():find('Class not chosen\nAscension: Ascended',1,true),'Unchosen class treated as chosen')
  for _,stage in ipairs({'None','Apprentice','Adept','God'})do
    cyclopedia.setCharacterIdentity({className='',ascension=stage})
    assert(panel.CharacterBase.InfoLabel:getText():find('Ascension: '..stage,1,true),'Progression stage lost '..stage)
  end
  cyclopedia.setCharacterIdentity({className='Reaver',ascension='Ascended'})
  print('CYCLOPEDIA_IDENTITY_HEADER_OK classes=6 unchosen=true authoritativeStages=true')
end
later(100,function()
  realUI.importStyle('/modules/game_cyclopedia/cyclopedia_widgets.otui')
  -- Stress the views below the normal desktop minimum (800x640), test only.
  g_window.setMinimumSize({width=800,height=600})
  g_window.resize({width=1280,height=800})
  host=realUI.createWidget('Panel',realUI.getRootWidget());host:setBackgroundColor('#303030')
  host:setSize({width=720,height=480});host:addAnchor(AnchorHorizontalCenter,'parent',AnchorHorizontalCenter);host:addAnchor(AnchorVerticalCenter,'parent',AnchorVerticalCenter)
  controls=realUI.createWidget('Panel',realUI.getRootWidget())
  for _,id in ipairs({'CharmsBase','GoldBase','BestiaryTrackerButton'})do realUI.createWidget('UIWidget',controls):setId(id)end
  cyclopedia={clientCombat=mod.Cyclopedia.clientCombat,InventorySlotStyles=mod.Cyclopedia.InventorySlotStyles}
  cyclopedia.sendCyclopediaRequest=function()requests=requests+1;return true,true end
  env={Cyclopedia=cyclopedia,contentContainer=host,controllerCyclopedia={ui=controls},connect=function()end,disconnect=function()end,
    g_game=setmetatable({isOnline=function()return true end,getLocalPlayer=function()return player end,
      getClientVersion=function()return 860 end,getFightMode=function()return FightOffensive end,
      requestCharacterInfo=function()requests=requests+1 end},{__index=realGame}),
    g_ui=setmetatable({loadUI=function(name,parent)assert(name=='character');return realUI.loadUIFromString(g_resources.readFileContents('/cyclopedia-character-layout.txt'),parent)end},{__index=realUI})}
  env._G=env;setmetatable(env,{__index=mod})
  local chunk=assert(loadstring(g_resources.readFileContents('/cyclopedia-character-source.txt'),'@fresh-character.lua'))
  setfenv(chunk,env);chunk();env.showCharacter();panel=assert(host:getChildById('Cat6'))
  cyclopedia.setServerCharacterTitle('Reaver');cyclopedia.setCharacterIdentity({className='Reaver',ascension='Ascended'})
  checkIdentity()
  local profile=text(panel.InfoBase.DetailsBase.List)
  assert(profile:find('Class: Reaver',1,true)and profile:find('Ascension: Ascended',1,true),'Class/progression identity mixed')
  cyclopedia.loadCharacterPassives(payload(presentation))
  cyclopedia.loadCharacterCombatStats({weaponElement=0,weaponMaxHitChance=21,weaponElementDamage=4,weaponSkillId=3,
    armor=9,defense=10,attackSpeed=2000,passiveStats=stats},0,
    {{Skill.CriticalChance,stats.criticalChance},{Skill.CriticalDamage,stats.criticalMultiplier}},{},{},{},{})
  local original=panel.CombatStats.Viewport.Content
  assert(original.defence.value:getText()=='5.45%'and original.dps.value:getText()=='5.3','Legacy critical/DPS estimate regressed')
  assert(original.passiveReduction.value:getText()=='1.50%','Legacy passive reduction disappeared')
  assert(original.converted.value:getText()=='4','Element attack damage mislabeled as percent')
  selectPage('CombatStats');assert(panel.CombatStats.Viewport:isVisible(),'Original combat view not primary')
  assert(panel.CharacterBase.InfoLabel:getText():find('Ascension: Ascended',1,true),'Ascension is not visible under class')
  checkGrouped()
  later(350,function()
    screenshot('cyclopedia-talents-1280x800');selectPage('CombatStats')
    later(250,function()
      screenshot('cyclopedia-stats-1280x800');g_window.resize({width=800,height=600})
      later(350,function()
        local r=host:getRect();local viewport=realUI.getRootWidget():getRect()
        print('CYCLOPEDIA_PASSIVES_SMALL_GEOMETRY '..json.encode({host=r,viewport=viewport,window=g_window.getSize()}))
        screenshot('cyclopedia-stats-800x600')
        assert(r.x>=0 and r.y>=0 and r.x+r.width<=viewport.width and r.y+r.height<=viewport.height,'Character UI exceeds small viewport')
        assert(viewport.width==800 and viewport.height==600,'Requested small viewport was not applied')
        assert(panel.CombatStats.Viewport:getHeight()>300,'Compact viewport has no useful combat area')
        screenshot('cyclopedia-stats-800x600');selectPage('PassiveStats')
        later(250,function()
          screenshot('cyclopedia-talents-800x600');checksFallback()
          host:destroy();host=nil;controls:destroy();controls=nil;finished=true
          print('CYCLOPEDIA_PASSIVES_PRESENTATION_OK offline=true network=false sizes=1280x800,800x600 testMinimumHeight=600 compactOriginal=true ascensionHeader=true')
          print('CYCLOPEDIA_PASSIVES_SCREENSHOT_DIRECTORY '..g_resources.getWriteDir())
          scheduleEvent(function()g_app.exit()end,150)
        end)
      end)
    end)
  end)
end)
