-- Run from the server root with LuaJIT. Exercises the actual scripts with fake engine I/O.
local checks = 0
local function check(value, message)
  assert(value, message)
  checks = checks + 1
end
local names = {[0]='Unawakened', 'Awakened', 'Ascendant', 'Ascended'}
Vocation = function(id)
  if not names[id] then return nil end
  return {getName=function() return names[id] end,
    getRequiredSkillTries=function() return 100 end,
    getRequiredManaSpent=function() return 200 end}
end
MESSAGE_EVENT_ADVANCE = 19
MESSAGE_STATUS_CONSOLE_BLUE = 4
ACCOUNT_TYPE_GOD = 5
local broadcasts = {}
Game = {getPlayers=function() return {} end,
  broadcastMessage=function(text) broadcasts[#broadcasts+1]=text end}
dofile('data/lib/ascension_announcements.lua')
for stage=1,3 do
  check(AscensionAnnouncements.announce('Tester',stage-1,stage,true), 'stage announcement')
  check(broadcasts[#broadcasts]:find('[TEST] ',1,true)==1 and
    broadcasts[#broadcasts]:find(names[stage],1,true), 'test prefix and stage name')
end
AscensionAnnouncements.firstAscensionMaxOnline=2
check(not AscensionAnnouncements.buildMessage('Tester',0,1,3), 'first stage suppression')
check(AscensionAnnouncements.buildMessage('Tester',0,1,2), 'threshold is inclusive')
check(AscensionAnnouncements.buildMessage('Tester',1,2,100), 'higher stages always announce')
AscensionAnnouncements.enabled=false
check(not AscensionAnnouncements.announce('Tester',2,3), 'disabled announcements')
AscensionAnnouncements.enabled=true
AscensionAnnouncements.firstAscensionMaxOnline=0
check(not AscensionAnnouncements.buildMessage('Tester',0,3,0), 'reject nonadjacent transition')
dofile('data/talkactions/scripts/testascensionannouncement.lua')
local accountType=5
local admin={getGroup=function() return {getAccess=function() return true end} end,
  getAccountType=function() return accountType end, getName=function() return 'Tester' end,
  sendCancelMessage=function() end, sendTextMessage=function() end}
local before=#broadcasts
onSay(admin,'/testascensionannouncement','3')
check(#broadcasts==before+1,'admin test broadcasts')
accountType=1
onSay(admin,'/testascensionannouncement','3')
check(#broadcasts==before+1,'non-admin cannot test broadcast')
accountType=5
onSay(admin,'/testascensionannouncement','9')
check(#broadcasts==before+1,'invalid stage cannot broadcast')

-- Run the production persistence/kick helpers, including their delayed success/failure path.
local file=assert(io.open('data/npc/scripts/The Nameless.lua'))
local source=file:read('*a') file:close()
local helper=assert(source:match('(local function doDBResetAndAscend.-)\n%-%- Stores the pending'))
local prefix=[[
local config={resetLevel=1,resetExperience=0,resetHealthMax=150,resetHealthNow=150,
  resetManaMax=0,resetManaNow=0,resetCap=400,templePosition={x=1,y=2,z=7,sendMagicEffect=function()end},
  offlineCheckDelayMs=200,offlineCheckRetries=8}
local SKILL_IDS={0,1,2,3,4,5,6}
local SKILL_TRIES_COLUMNS={'skill_fist_tries','skill_club_tries','skill_sword_tries',
  'skill_axe_tries','skill_dist_tries','skill_shielding_tries','skill_fishing_tries'}
local function captureSkillProgress() return {{level=10,pct=0.5}} end
local function captureMagicLevelProgress() return {magLevel=5,pct=0.5} end
]]
local kick, persist=assert(loadstring(prefix..helper..'\nreturn kickThenWrite,doDBResetAndAscend'))()
local queryOk=true
local queries={}
db={query=function(sql) queries[#queries+1]=sql return queryOk end}
local callbacks={}
addEvent=function(fn) callbacks[#callbacks+1]=fn end
Player=function() return nil end
CONST_ME_TELEPORT=10
PS={Player_TheAscent_AscentPopupShown=1}
local fakePlayer={getId=function()return 1 end,getGuid=function()return 1 end,
  getName=function()return 'Tester' end,teleportTo=function()end,sendTextMessage=function()end,
  setStorageValue=function()end,remove=function()end}
before=#broadcasts
kick(fakePlayer,3,2)
check(#broadcasts==before,'no announcement before persistence')
callbacks[#callbacks]()
check(#broadcasts==before+1,'successful persistence announces once')
check(#queries==1 and queries[1]:find('`skill_fist_tries`=50',1,true) and
  queries[1]:find('`manaspent`=100',1,true),'one atomic update preserves fractional progress')
queryOk=false
before=#broadcasts
kick(fakePlayer,3,2)
callbacks[#callbacks]()
check(#broadcasts==before,'failed persistence never announces')

-- Sure Shot: real branch selection, both hands, ammo compatibility and consumption.
COMBAT_PARAM_TYPE=1 COMBAT_PHYSICALDAMAGE=2 COMBAT_PARAM_BLOCKARMOR=3
COMBAT_PARAM_USECHARGES=4 COMBAT_PARAM_EFFECT=5 CONST_ME_EXPLOSIONAREA=6
CALLBACK_PARAM_SKILLVALUE=7 CONST_SLOT_LEFT=6 CONST_SLOT_RIGHT=5 CONST_SLOT_AMMO=10
CONST_ANI_ARROW=1 CONST_ANI_NONE=0 CONST_ME_POFF=3 SKULL_BLACK=5
createCombatArea=function(area) return area end
local combats={} local executeOk=true local usedCombat
Combat=function()
  local c={setParameter=function()end,setCallback=function()end,
    setArea=function(self,area)self.area=area end,
    execute=function(self) usedCombat=self return executeOk end}
  combats[#combats+1]=c return c
end
Creature=function() return {getPosition=function()return {} end} end
dofile('data/spells/scripts/attack/sure_shot.lua')
local removed=0 local projectiles=0 local ammoId=2546 local ammoType=1 local skull=0
local slots={}
local bow={getType=function()return {isBow=function()return true end,getAmmoType=function()return 1 end} end}
local ammo={getId=function()return ammoId end,getType=function()return {
  getAmmoType=function()return ammoType end,getShootType=function()return 4 end} end,
  remove=function(_,n)removed=removed+n end}
slots[CONST_SLOT_RIGHT]=bow slots[CONST_SLOT_AMMO]=ammo
local selectedAmmunition=ammo
local player={getSlotItem=function(_,slot)return slots[slot] end,getSkull=function()return skull end,
  getAmmunition=function()return selectedAmmunition end,
  sendCancelMessage=function()end,getPosition=function()return {
    sendDistanceEffect=function()projectiles=projectiles+1 end,sendMagicEffect=function()end} end}
local caster={getPlayer=function()return player end}
local variant={getNumber=function()return 9 end}
check(onCastSpell(caster,variant) and usedCombat==combats[2] and removed==1,'burst uses area, right hand, one round')
check(usedCombat.area[2][2]==3 and usedCombat.area[1][1]==1,'burst centered 3x3')
ammoId=2544
check(onCastSpell(caster,variant) and usedCombat==combats[1] and removed==2,'normal arrow remains single target')
slots[CONST_SLOT_LEFT]=bow slots[CONST_SLOT_RIGHT]=nil
check(onCastSpell(caster,variant),'left hand bow works')
before=removed
executeOk=false
check(not onCastSpell(caster,variant) and removed==before,'failed combat consumes no ammo')
executeOk=true ammoType=2
check(not onCastSpell(caster,variant) and removed==before,'incompatible ammo is rejected')
ammoType=1 ammoId=2546 skull=SKULL_BLACK
before=projectiles
check(not onCastSpell(caster,variant) and projectiles==before,'black skull rejected before projectile')
skull=0
slots[CONST_SLOT_AMMO]={remove=function()error('Quiver itself must never be consumed')end}
before=removed
check(onCastSpell(caster,variant)and usedCombat==combats[2]and removed==before+1,
  'quiver-loaded burst uses the selected round metadata and consumes that round')
selectedAmmunition=nil
before=removed
check(not onCastSpell(caster,variant)and removed==before,'empty quiver resolver rejects without charging ammunition')
print('SERVER_FEATURE_CONTRACTS_OK checks='..checks)
