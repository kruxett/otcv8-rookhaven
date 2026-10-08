-- Execute the actual server response builder with isolated inventory snapshots.
-- Native combat is checked separately; these cases verify payload semantics.
local root=assert(arg[1]);local f=assert(io.open(root..'/data/creaturescripts/scripts/extendedopcode.lua','rb'))
local src=f:read('*a');f:close()
local chunk=assert(src:match('(local function handleCharacterCombatStats%(player%).-)local function handleCharacterRecentKills'))
local env=setmetatable({}, {__index=_G})
local names={'Physical','Fire','Earth','Energy','Ice','Holy','Death'}
local combat={1,8,4,2,512,1024,2048}
for i,name in ipairs(names)do env['COMBAT_'..name:upper()..'DAMAGE']=combat[i]end
for i,name in ipairs({'HEAD','NECKLACE','BACKPACK','ARMOR','RIGHT','LEFT','LEGS','FEET','RING','AMMO'})do env['CONST_SLOT_'..name]=i end
env.SKILL_FIST=0;env.SKILL_SHIELD=5;env.WEAPON_NONE=0;env.WEAPON_SHIELD=4
env.SPECIALSKILL_CRITICALHITCHANCE=0;env.SPECIALSKILL_CRITICALHITAMOUNT=1
env.SPECIALSKILL_LIFELEECHAMOUNT=2;env.SPECIALSKILL_MANALEECHAMOUNT=3;env.ITEM_ATTRIBUTE_DESCRIPTION=1
env.Game={getSkillType=function()return 3 end};env.PassiveTest={trees={}}
env.PassivePresentation={build=function()return{}end};env.json={encode=function()return '{}'end}
local replies={};env.cyclopediaSendResponse=function(_,action,_,value)replies[action]=value end
env.cyclopediaSendError=function(_,_,_,message)error(message)end;env.debugLog=function()end
local function item(description)
 return{getId=function()return 2428 end,getAttack=function()return 22 end,getDefense=function()return 8 end,
  getExtraDefense=function()return 1 end,getArmor=function()return 9 end,getAttribute=function()return description or ''end}
end
env.ItemType=function()return{getId=function()return 2428 end,getAttack=function()return 20 end,
 getDefense=function()return 7 end,getExtraDefense=function()return 0 end,getArmor=function()return 4 end,
 getWeaponType=function()return 1 end,getElementDamage=function()return 0 end}end
local native={armor=9,defense=8,weaponAttack=22,weaponElementAttack=4,weaponElementType=8,criticalChance=0,
 criticalMultiplier=200,weaponSkill=60,attackSpeed=2000}
for _,name in ipairs(names)do native['equipmentResistance'..name]=0 end
local inventory={};local player={getSlotItem=function(_,slot)return inventory[slot]end,
 getSkillLevel=function()return 60 end,getDefense=function()return 8 end,hasBlessing=function()return false end,
 getSpecialSkill=function()return 0 end,getPassiveCharacterStats=function()return native end}
local load=assert(loadstring(chunk..'\nreturn handleCharacterCombatStats','@actual-combat-response'));setfenv(load,env)
local handle=load();local checks=0
local function check(ok,message)assert(ok,message);checks=checks+1 end
local function run()
 replies={};handle(player);local csv={};for field in (assert(replies['character.combatStats'])..','):gmatch('(.-),')do csv[#csv+1]=field end
 check(#csv==18,'Legacy CSV shape changed');return csv
end
inventory[6]=item('');local csv=run()
check(tonumber(csv[1])==22,'Actual rolled weapon attack was replaced by static ItemType')
check(tonumber(csv[3])==4 and tonumber(csv[4])==1,'Actual item element was omitted')
check(csv[13]=='0:0.00','Ordinary armor became percent physical resistance or CSV padding lost')
native.equipmentResistancePhysical=10;inventory[4]=item('[Physical Resistance: +20%]')
inventory[3]=item('[Physical Resistance: +50%]');inventory[10]=item('[Physical Resistance: +50%]')
csv=run();check(csv[13]=='0:28.00','Native absorption and rarity must multiply; backpack/ammo rarity must not apply')
native.equipmentResistancePhysical=20;inventory[4]=item('[Physical Resistance: +60%]')
csv=run();check(csv[13]=='0:60.00','Only rarity is capped at50, not the combined resistance')
native.equipmentResistancePhysical=0;inventory[4]=item('[Physical Resistance: -20%]')
native.equipmentResistanceFire=-8;csv=run()
check(csv[13]=='1:-8.00','Native vulnerability lost or unsupported negative rarity counted')
native.equipmentResistanceFire=5;inventory[4]=item('[Fire Resistance: +10%]')
csv=run();check(csv[13]=='1:14.50','Element type/native index confused or stacked percent added')
local presentation=dofile(root..'/data/lib/passives/presentation.lua')
local p=presentation.build({armor=9,defense=8,maxHealth=735,attackSpeed=2000},nil)
local visible={};for _,entry in ipairs(p.overview)do visible[entry.id]=entry end
check(not visible.attackInterval and not visible.criticalChance and not visible.criticalMultiplier,'Fixed interval/unowned critical stats retained')
check(visible.armor and visible.defense and visible.normalMaxHit,'Influenceable core stats omitted')
local renewal=presentation.build({healingOverTimeRemaining=24,currentHealthPerSecond=0},nil)
local renewalRows={};for _,entry in ipairs(renewal.overview)do renewalRows[entry.id]=entry end
check(renewalRows.healingRemaining and renewalRows.healingRemaining.value==24 and not renewalRows.healthRegen,'Finite Renewal total mislabeled as continuous regeneration')
print('CYCLOPEDIA_EQUIPMENT_CONTRACT_OK checks='..checks..' actualResponseBuilder=true nativeCombat=false')
