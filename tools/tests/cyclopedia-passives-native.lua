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
local wireChunks,chunkedReports= nil,0
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
local function widgetText(widget)
 local value=widget.getText and widget:getText()or''
 for _,child in ipairs(widget:getChildren())do value=value..'\n'..widgetText(child)end
 return value
end
local function selectPage(panel,id)
 local general=panel.OptionsBase:getChildByIndex(1)
 if not general.opened then signalcall(general.Button.onClick,general.Button)end
 for _,row in ipairs(general:getChildren())do if row.open==id then
  signalcall(row.Button.onClick,row.Button);assert(panel[id]:isVisible(),'Native category failed '..id);return
 end end
 error('Native category absent '..id)
end
local function verifyPresentation(passive,native)
 local p=assert(passive.presentation,'Server omitted accepted presentation schema')
 assert(p.version==1 and p.header.className==classes[tree] and p.header.weaponActive==native.weaponActive,'Presentation header disagrees with native class/weapon')
 assert(p.header.spent==native.spent and p.header.points==native.points,'Presentation changed allocation points')
 local fields={maxHealth='maxHealth',armor='armor',defense='defense',attackInterval='attackSpeed',
  normalMaxHit='ordinaryMaxHit',ordinaryDamage='ordinaryDamagePercent',spellDamage='eligibleSpellDamagePercent',
  criticalChance='criticalChance',physicalReduction='physicalReductionPercent',manaDiscount='manaDiscountPercent',
  manaRegen='currentManaPerSecond',healthRegen='currentHealthPerSecond',healingRemaining='healingOverTimeRemaining',incomingHealing='incomingHealingPercent',
  outgoingHealing='outgoingHealingPercent',ward='ward',spellPrimary='spellPrimaryExtraPercent',
  spellSecondary='spellSecondaryExtraPercent',criticalMultiplier='criticalMultiplier',
  damageRecovery='damageRecoveryPercent',killRecovery='killRecoveryPercent'}
 local overview={}
 for _,row in ipairs(p.overview)do
  assert(not overview[row.id],'Duplicate source row '..row.id);overview[row.id]=row
  assert(row.group=='offence'or row.group=='defence'or row.group=='recovery','Unknown stats group')
  assert(type(row.sources)=='table'and (type(row.description)=='string'or type(row.hint)=='string'),'Stat lacks server explanation '..row.id)
  local key=assert(fields[row.id],'Unverified presentation stat '..row.id)
  approx(row.value,native[key]or 0,'Authoritative presentation '..row.id)
 end
 for _,id in ipairs({'maxHealth','armor','defense','normalMaxHit'})do
  assert(overview[id],'Core stat omitted '..id)
 end
 assert((native.attackSpeed~=2000)==(overview.attackInterval~=nil),'Fixed attack interval must not occupy a stat row')
 local chosen={};for _,t in ipairs(passive.talents)do chosen[t.name]=t.rank end
 local seen={}
 for _,group in ipairs({'statBonuses','conditionalEffects','specialEffects'})do
  for _,row in ipairs(assert(p.talents[group]))do
   assert(not seen[row.id],'Duplicate talent effect ID '..row.id);seen[row.id]=true
   assert(chosen[row.label]==row.rank and row.rank>0,'Unchosen/stale talent displayed '..row.label)
   assert(type(row.status)=='string'and type(row.detail)=='string','Effect lacks activation/mechanics description')
  end
 end
 return p
end
local function verifyNativeUI(p,onComplete)
 local module=modules.game_cyclopedia
 local panel=assert(module.contentContainer:getChildById('Cat6'),'Actual Cyclopedia character UI missing')
 local function checkOverview()
  selectPage(panel,'CombatStats')
  local a=panel.CombatStats.Viewport;assert(a:isVisible()and a.Content.estDps:getHeight()==20,'Original compact view missing')
  assert(panel.CharacterBase.InfoLabel:getText():find('Ascension: Ascended',1,true),'Native progression missing under class')
  for _,item in ipairs(p.overview)do
   local row=module.Cyclopedia.getCombatStatRow(item.id)
   if item.id~='ward' or tonumber(item.value)>0 then
    assert(row or tonumber(item.value)==0,'Relevant native stat not rendered '..item.id)
   end
   if row and item.id=='criticalMultiplier'then assert(math.abs(tonumber(row.value:getText():match('[%d.]+'))-item.value)<.005,'Combined multiplier display wrong')end
  end
  local row=assert(module.Cyclopedia.getCombatStatRow('normalMaxHit'));signalcall(row.onClick,row)
  assert(panel.CombatSources.Content.Title:getText()=='Maximum normal hit','Actual source click failed')
  return a
 end
 -- Test-only stress viewport; keep the product's800x640 minimum unchanged.
 g_window.setMinimumSize({width=800,height=600})
 g_window.resize({width=1280,height=800})
 local a=checkOverview()
 later(250,function()
  local title=panel.CombatSources.Content.Title:getText()
  signalcall(panel.CombatSources.Close.onClick,panel.CombatSources.Close)
  later(120,function()
  g_app.doScreenshot('/cyclopedia-native-'..tree..'-stats-1280x800.png')
  later(120,function()
  signalcall(module.Cyclopedia.getCombatStatRow('normalMaxHit').onClick,module.Cyclopedia.getCombatStatRow('normalMaxHit'))
  -- Exercise the real response handler again; do not call a renderer with a mock.
  local old=packets['character.passives'];packets['character.passives']=nil
  g_game.getProtocolGame():sendExtendedOpcode(31,'cp|1|req|character.combatStats|')
  wait('real presentation refresh',function()return packets['character.passives']~=nil end,function()
   assert(panel.CombatSources.Content.Title:getText()==title,'Real refresh reset selected stat')
   selectPage(panel,'PassiveStats')
   assert(not panel.CombatSources:isVisible(),'Source dialog leaked onto talent page')
   assert(widgetText(panel.PassiveStats.Header):find(classes[tree],1,true),'Talent page lost class')
   for _,group in ipairs({'statBonuses','conditionalEffects','specialEffects'})do for _,item in ipairs(p.talents[group])do
    local row=assert(panel.PassiveStats.List:getChildById('talent_'..item.id),'Native talent effect missing '..item.id)
    signalcall(row.onClick,row);assert(widgetText(panel.PassiveStats.SourceDetails.Content):find(item.label,1,true),'Actual effect source click failed')
   end end
   later(200,function()
    g_app.doScreenshot('/cyclopedia-native-'..tree..'-talents-1280x800.png')
    g_window.resize({width=800,height=600})
    later(300,function()
     local r=module.controllerCyclopedia.ui:getRect();local root=g_ui.getRootWidget():getRect()
     assert(root.width==800 and root.height==600,'Native small viewport was not applied')
     assert(r.x>=0 and r.y>=0 and r.x+r.width<=800 and r.y+r.height<=600,'Native retro Cyclopedia clipped at800x600')
     g_app.doScreenshot('/cyclopedia-native-'..tree..'-talents-800x600.png');a=checkOverview()
     assert(a:getHeight()>300,'Native small stat viewport collapsed')
     later(200,function()
      signalcall(panel.CombatSources.Close.onClick,panel.CombatSources.Close)
      later(120,function()
      g_app.doScreenshot('/cyclopedia-native-'..tree..'-stats-800x600.png')
      later(120,function()
      module.hide();module.show('character');panel=assert(module.contentContainer:getChildById('Cat6'))
      later(300,function()
       selectPage(panel,'CombatStats');a=panel.CombatStats.Viewport
       local row=assert(module.Cyclopedia.getCombatStatRow('normalMaxHit'));signalcall(row.onClick,row)
       assert(panel.CombatSources.Content.Title:getText()==title,'Reopen source failed')
       print('CYCLOPEDIA_PASSIVES_NATIVE_UI_OK class='..tree..' sources=true refresh=true reopen=true sizes=1280x800,800x600 testMinimumHeight=600')
       print('CYCLOPEDIA_PASSIVES_NATIVE_SCREENSHOT_DIRECTORY '..g_resources.getWriteDir())
       onComplete()
      end)
      end)
      end)
     end)
    end)
   end)
  end)
  end)
  end)
 end)
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
 assert(#packets['character.passives']<32768,'Presentation exceeds bounded report budget')
 local presentation=verifyPresentation(passive,native)
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
 approx(tonumber(csv[1]),native.weaponAttack or 0,'Actual rolled weapon attack in existing stats')
 approx(tonumber(csv[5]),native.armor,'Native armor in existing stats')
 approx(tonumber(csv[6]),native.defense,'Native defense in existing stats')
 assert(math.abs(tonumber(csv[9])-native.criticalChance)<=.005,'Fractional critical chance lost in CSV')
 assert(math.abs(tonumber(csv[10])-native.criticalMultiplier)<=.005,'Critical damage lost in CSV')
 approx(tonumber(csv[15]),native.attackSpeed,'Native attack interval in existing stats')
 local c=modules.game_cyclopedia.Cyclopedia
 assert(c.characterPassiveStats and c.characterPassiveStats.className==classes[tree],'Actual Cyclopedia parser did not retain authoritative stats')
 verifyNativeUI(presentation,function()
 print('CYCLOPEDIA_PASSIVES_NATIVE_OK '..json.encode({tree=tree,guid=guid,appliedPoints=spent,weaponActive=native.weaponActive,
  maxHP=native.maxHealth,hpBonus=native.maxHealthBonus or 0,criticalChance=native.criticalChance,
  manaPerSecond=native.manaPerSecond or 0,physicalReduction=native.physicalReductionPercent or 0,
  selfLook=metrics.selfLook,otherLook=metrics.otherLook,ascension=identity.ascension,
  reportBytes=#packets['character.passives'],chunkedReports=chunkedReports,readonly=true}))
 intentional=true;g_game.safeLogout()
 wait('safe logout',function()return not g_game.isOnline()end,function()
  done=true;print('CYCLOPEDIA_PASSIVES_NATIVE_COMPLETE');g_app.exit()
 end)
 end)
end
later(150,function()
 assert(LOCAL_PASSIVES_TEST and Services.updater=='' and not g_game.isOnline(),'Owned local probe only')
 connect(ProtocolGame,{onExtendedOpcode=function(_,opcode,buffer)
  if opcode~=31 then return end
  assert(#buffer<=8192,'Actual extended opcode exceeded native string limit')
  local id,index,total,part=buffer:match('^cp|1|chunk|(%d+)|(%d+)|(%d+)|(.*)$')
  if id then
   index,total=tonumber(index),tonumber(total)
   assert(total>=2 and total<=8 and index>=1 and index<=total and #part>0,'Invalid actual chunk frame')
   if index==1 then wireChunks={id=id,total=total,next=1,bytes=0,parts={}}end
   assert(wireChunks and wireChunks.id==id and wireChunks.total==total and wireChunks.next==index,'Actual chunks reordered or interleaved')
   wireChunks.parts[index]=part;wireChunks.bytes=wireChunks.bytes+#part;wireChunks.next=index+1
   assert(wireChunks.bytes<=32768,'Actual report exceeded bounded reassembly')
   if index<total then return end
   buffer=table.concat(wireChunks.parts);wireChunks=nil;chunkedReports=chunkedReports+1
  end
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
