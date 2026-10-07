-- Connected read-only Cyclopedia/native identity probe. Owned loopback only.
-- No rank, class, combat, item, bank or progression mutations are requested.
local classes={reaver='Reaver',blademaster='Blademaster',earthshaker='Earthshaker',marksman='Marksman',arcanist='Arcanist',lifekeeper='Lifekeeper'}
local classIds={reaver=9006,blademaster=9007,earthshaker=9008,marksman=9009,arcanist=9010,lifekeeper=9011}
local tree=PASSIVES_PROBE_TREE or 'reaver'
local subject=PASSIVES_PROBE_CAP or 'berserker'
local account,name,guid='class'..tree,'Starter '..assert(classes[tree]),classIds[tree]
if subject=='initiate' then account,name,guid='passiveclass','Passive Initiate',9003
elseif subject=='veteran' then account,name,guid='passivelegacy','Passive Veteran',9004
elseif subject=='mystic' then account,name,guid='passivemagic','Passive Mystic',9005 end
local failed,done,intentional=false,false,false
local metrics,login
local packets={}
local function fail(reason)
 if failed or done then return end
 failed=true;print('CYCLOPEDIA_PASSIVES_NATIVE_FAILED '..tostring(reason))
 if g_game.isOnline() then intentional=true;g_game.safeLogout() end
 scheduleEvent(function()g_app.exit()end,400)
end
local function later(ms,fn)
 scheduleEvent(function()if failed or done then return end;local ok,reason=pcall(fn);if not ok then fail(reason)end end,ms)
end
local function wait(label,predicate,nextStep)
 local deadline=g_clock.millis()+12000
 local function poll()
  if predicate() then nextStep();return end
  assert(g_clock.millis()<deadline,label..' timeout');later(60,poll)
 end
 later(60,poll)
end
local function approx(actual,expected,label)
 assert(type(actual)=='number' and math.abs(actual-expected)<.000001,label..' actual='..tostring(actual)..' expected='..tostring(expected))
end
local function verify()
 local native,profile,cfg=metrics.native,metrics.profile,metrics.config
 assert(metrics.guid==guid and profile.mode=='permanent' and profile.treeId==tree,'Wrong disposable permanent subject')
 assert(native.active and native.permanent and native.classId==tree and native.className==classes[tree],'Native class identity disagrees')
 assert(metrics.selfLook:find(classes[tree],1,true) and metrics.otherLook:find(classes[tree],1,true),'Native self/other look retained Ascended as class')
 assert(metrics.ascension=='Ascended','Internal progression identity changed')
 assert(packets['character.baseInfo']==classes[tree],'Cyclopedia headline is not the chosen class')
 local identity=json.decode(packets['character.identity'])
 assert(identity.className==classes[tree] and identity.ascension=='Ascended','Class and Ascension were mixed in the actual protocol')
 local passive=json.decode(packets['character.passives'])
 assert(passive.stats.classId==tree and passive.stats.className==classes[tree],'Cyclopedia dropped native class identity')
 local r=native.ranks;local spent,count=0,0
 for _,rank in ipairs(r)do spent=spent+rank;if rank>0 then count=count+1 end end
 assert(spent==native.spent and #passive.talents==count,'Applied talent catalog has missing/stale ranks')
 local indexById={};for i,node in ipairs(modules.game_passives.getState().tree.nodes)do indexById[node.id]=i end
 for id,rank in pairs(profile.ranks)do assert(r[indexById[id]]==rank,'Native snapshot rank differs from saved profile: '..id)end
 for _,key in ipairs({'maxHealthBonus','ordinaryDamagePercent','ownOrdinaryDamagePercent','partyQuarryDamagePercent',
  'manaDiscountPercent','manaPerSecond','damageRecoveryPercent','physicalReductionPercent','criticalChance',
  'legacyCriticalThreshold','legacyCriticalChance','passiveCriticalChance','criticalMultiplier','armor','defense',
  'attackSpeed','routeReturnBudget','routeReturnMs'})do
  approx(passive.stats[key]or 0,native[key]or 0,'Cyclopedia native field '..key)
 end
 local player=g_game.getLocalPlayer()
 approx(player:getMaxHealth(),native.maxHealth,'Client actual maxHP vs native')
 approx(native.maxHealth,metrics.maxHP,'Native actual maxHP')
 if native.weaponActive then
  local hpPercent=r[5]*cfg.minorVitality+r[11]*cfg.majorGuardHp+r[28]*cfg.midHpPercent
  approx(native.maxHealthPercent,hpPercent,'HP talent accounting')
  approx(native.maxHealthBonus,math.floor(native.baseMaxHealth*hpPercent/100),'Actual HP modifier vs default base')
  approx(native.manaPerSecond,r[8]*cfg.minorFocus,'Fractional mana regeneration')
  approx(native.damageRecoveryPercent,r[7]*cfg.minorRecovery+r[12]*cfg.majorRecovery,'Actual-damage recovery accounting')
  approx(native.killRecoveryPercent,r[12]*cfg.majorKillHeal,'Kill recovery balance value')
  approx(native.incomingHealingPercent,r[14]*cfg.majorSteadyHealing,'Incoming direct healing')
  if tree~='lifekeeper' then
   local extra=math.min(100,(r[1]*cfg.minorPrecisionBps+r[9]*cfg.majorPrecisionBps+r[25]*cfg.midPrecisionBps)/100)
   approx(native.passiveCriticalChance,extra,'Passive ordinary critical chance')
   approx(native.criticalChance,native.legacyCriticalChance+(100-native.legacyCriticalChance)*extra/100,'Independent critical roll composition')
  end
  local manaBase=r[4]*cfg.minorEfficiency+r[13]*cfg.majorTacticalMana+r[27]*cfg.midManaPercent
  assert(native.manaDiscountPercent>=math.min(cfg.manaDiscountCapPercent,manaBase) and native.manaDiscountPercent<=cfg.manaDiscountCapPercent,'Current mana discount exceeds scope/cap')
 else
  assert((native.maxHealthBonus or 0)==0 and (native.manaPerSecond or 0)==0 and (native.physicalReductionPercent or 0)==0,'Incompatible weapon retained passive bonuses')
  approx(native.ordinaryDamagePercent or 0,native.partyQuarryDamagePercent or 0,'Inactive own tree retains external party mark only')
 end
 local csv=string.split(packets['character.combatStats'],',')
 approx(tonumber(csv[5]),native.armor,'Native armor in existing stats')
 approx(tonumber(csv[6]),native.defense,'Native defense in existing stats')
 assert(math.abs(tonumber(csv[9])-native.criticalChance)<=.005,'Fractional critical chance lost in CSV')
 assert(math.abs(tonumber(csv[10])-native.criticalMultiplier)<=.005,'Critical damage lost in CSV')
 approx(tonumber(csv[15]),native.attackSpeed,'Native attack interval in existing stats')
 local c=modules.game_cyclopedia.Cyclopedia
 assert(c.characterPassiveStats and c.characterPassiveStats.className==classes[tree],'Actual Cyclopedia parser did not retain authoritative stats')
 print('CYCLOPEDIA_PASSIVES_NATIVE_OK '..json.encode({tree=tree,guid=guid,appliedPoints=spent,weaponActive=native.weaponActive,
  maxHP=native.maxHealth,hpBonus=native.maxHealthBonus or 0,criticalChance=native.criticalChance,
  manaPerSecond=native.manaPerSecond or 0,physicalReduction=native.physicalReductionPercent or 0,
  selfLook=metrics.selfLook,otherLook=metrics.otherLook,ascension=identity.ascension,readonly=true}))
 intentional=true;g_game.safeLogout()
 wait('safe logout',function()return not g_game.isOnline()end,function()
  done=true;print('CYCLOPEDIA_PASSIVES_NATIVE_COMPLETE');g_app.exit()
 end)
end
later(150,function()
 assert(LOCAL_PASSIVES_TEST and Services.updater=='' and not g_game.isOnline(),'Owned local probe only')
 connect(ProtocolGame,{onExtendedOpcode=function(_,opcode,buffer)
  if opcode~=31 then return end
  local action,status,data=buffer:match('^cp|1|res|([^|]+)|([^|]+)|?(.*)$')
  if action and status=='ok' then packets[action]=data end
 end})
 connect(g_game,{onTextMessage=function(_,text)
  if text:find('PASSIVE_CHARACTER_STATS_FAILED',1,true)then fail(text);return end
  local raw=text:match('^PASSIVE_CHARACTER_STATS (.+)$');if raw then metrics=json.decode(raw)end
 end,onConnectionError=function(reason)if not intentional then fail(reason)end end})
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 G.account=account;G.password=account;login=ProtocolLogin.create();_G.cyclopediaPassiveLogin=login
 login.onLoginError=function(_,reason)fail(reason)end
 login.onCharacterList=function(_,chars)
  for _,character in ipairs(chars)do if character.name==name then
   g_game.loginWorld(account,account,character.worldName,character.worldIp,character.worldPort,name,'','');return
  end end
  fail('Missing disposable character')
 end
 login:login('127.0.0.1',7174,account,account,'',false)
 wait('world login',function()return g_game.isOnline() and modules.game_passives.getState().tree~=nil end,function()
  EnterGame.hide();g_game.talk('/passivecharacterstats')
  wait('read-only native evidence',function()return metrics~=nil end,function()
   modules.game_cyclopedia.show('character')
   later(400,function()
    g_game.getProtocolGame():sendExtendedOpcode(31,'cp|1|req|character.combatStats|')
    wait('actual Cyclopedia protocol',function()
     return packets['character.baseInfo'] and packets['character.identity'] and packets['character.passives'] and packets['character.combatStats']
    end,verify)
   end)
  end)
 end)
end)
scheduleEvent(function()if not done then fail('40-second read-only character deadline')end end,40000)
