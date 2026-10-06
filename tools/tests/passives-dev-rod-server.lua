-- Copy/register ONLY in the disposable local runtime. Never release this helper.
local owned
local function weapon(p)
 for _,slot in ipairs({CONST_SLOT_LEFT,CONST_SLOT_RIGHT})do local w=p:getSlotItem(slot);if w and w:getId()==2182 then return w end end
end
local function gate(p)
 return p:getGuid()==9004 and p:getGroup():getId()==1
  and configManager.getString(configKeys.SERVER_NAME)=='Rookhaven Local Passives Test'
  and configManager.getBoolean(configKeys.BIND_ONLY_GLOBAL_ADDRESS)
  and (p:getIp()==0x0100007F or p:getIp()==0x7F000001)
end
local function valid(pos)
 local t=Tile(pos);return t and t:getGround()and not t:hasFlag(TILESTATE_BLOCKSOLID)and not t:hasFlag(TILESTATE_PROTECTIONZONE)and not t:getTopCreature()
end
local function cleanup(p)
 p:setTarget(nil);local m=owned and Monster(owned);if m and m:getName()=='Class Spell Dummy'then m:remove()end;owned=nil
 local w=weapon(p);if w then w:removeAttribute(ITEM_ATTRIBUTE_ATTACK_SPEED)end
 p:removeCondition(CONDITION_INFIGHT,CONDITIONID_DEFAULT,0,true);p:removeCondition(CONDITION_INFIGHT,CONDITIONID_COMBAT,0,true)
end
local function report(p,label)
 local m=owned and Monster(owned);local w=weapon(p);local s=json.decode(p:passiveTest('snapshot'))
 local data={label=label,targetId=m and m:getId(),hp=m and m:getHealth()or 0,mana=p:getMana(),weaponId=w and w:getId(),money=p:getMoney(),group=p:getGroup():getId(),classId=s.treeId}
 local text='PASSIVE_DEV_ROD '..json.encode(data);print(text);p:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,text)
end
function onSay(p,words,param)
 if not gate(p)then return false end
 local ok,e=pcall(function()
  if param=='prepare'then
   assert(weapon(p),'Actual purchased rod must already be equipped')
   assert(p:hasLearnedSpell('Essence Lash'),'Existing ordinary entitlement required')
   cleanup(p);local origin;local base=Position(32097,32219,7)
   for radius=3,30 do for dx=-radius,radius do for dy=-radius,radius do
    if not origin and(math.abs(dx)==radius or math.abs(dy)==radius)then
     local c=Position(base.x+dx,base.y+dy,base.z)
     if valid(c)and valid(Position(c.x-3,c.y,c.z))then origin=c end
    end
   end end;if origin then break end end
   assert(origin,'No clear ordinary combat tiles');local m=assert(Game.createMonster('Class Spell Dummy',origin,false,false));m:setDropLoot(false);owned=m:getId()
   p:teleportTo(Position(origin.x-3,origin.y,origin.z))
   p:removeCondition(CONDITION_REGENERATION,CONDITIONID_DEFAULT,0,true);p:addMana(40-p:getMana())
  elseif param=='zero'then p:setTarget(nil);p:addMana(1-p:getMana())
  elseif param=='spell'then
   local m=assert(owned and Monster(owned));local w=assert(weapon(p));w:setAttribute(ITEM_ATTRIBUTE_ATTACK_SPEED,600000)
   p:addMana(40-p:getMana());p:setTarget(m)
  elseif param=='cleanup'then cleanup(p)
  elseif param~='state'then error('Unknown isolated rod proof command')end
  report(p,param)
 end)
 if not ok then local text='PASSIVE_DEV_ROD_FAILED '..tostring(e);print(text);p:sendCancelMessage(text)end
 return false
end
