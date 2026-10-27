-- Real native shop/equip packets for the 22 new variants and four existing ones.
assert(configManager.getString(configKeys.SERVER_NAME)=='Rookhaven Batch Outfit QA')
local families={'Rune Master','Lion of War','Afflicted','Arbalester','Arena Champion','Armoured Archer',
 'Discoverer','Entrepreneur','Formal Dress','Golden','Nordic Chieftain','Poltergeist','Veteran Paladin'}
local checks,sequence=0,0
local initialPoints=10000
local function check(ok,why)assert(ok,why);checks=checks+1 end
local function later(ms,fn)addEvent(function()local ok,e=pcall(fn);if not ok then print('BATCH_NATIVE_FAILED '..tostring(e))end end,ms)end
local function history(p)return #(GameShop.historyByGuid[p:getGuid()]or{})end
local function variant(p,index)
 if not families[index]then return nil end
 local first=373+(index-1)*2;local firstOffer=6001+(index-1)*2;local sex=p:getSex()
 return {look=first+sex,other=first+1-sex,offer=firstOffer+sex,otherOffer=firstOffer+1-sex,name=families[index]}
end
local function wire(p,label,kind,data,nextStep)
 sequence=sequence+1;data.sequence=sequence;data.label=label;data.kind=kind
 data.actor=p:getSex()==0 and 'peer' or nil
 print('BATCH_WIRE '..json.encode(data));later(450,nextStep)
end
local function buy(p,id,label,nextStep)
 for ci,category in ipairs(GameShop.catalog)do for oi,offer in ipairs(category.offers)do
  if offer.id==id then wire(p,label,'buy',{category=ci,offer=oi},nextStep);return end
 end end
 error('Missing offer '..id)
end
local function wear(p,look,addons,label,nextStep)
 wire(p,label,'set_outfit',{look=look,addons=addons,head=58,body=49+addons,legs=2+addons,feet=58},nextStep)
end
local function base(p)
 check(p:getGroup():getId()==1 and not p:isPremium(),'Must use ordinary free characters')
 for look=373,398 do p:removeOutfit(look)end
 for index=1,#families do
  local v=variant(p,index)
  check(not p:hasOutfit(v.look,0) and not p:canWearOutfit(v.look,3),'Outfit available before purchase: '..v.name)
  check(not p:canWearOutfit(v.other,0),'Wrong-sex outfit initially available: '..v.name)
 end
 GameShop.setPoints(p,initialPoints)
end
local function verifyReconnect(p)
 for index=1,#families do
  local v=variant(p,index)
  check(p:hasOutfit(v.look,3) and p:canWearOutfit(v.look,3),'Purchased outfit lost: '..v.name)
  check(not p:canWearOutfit(v.other,3),'Sex restriction lost: '..v.name)
 end
 local o=p:getOutfit()
 check(GameShop.getPoints(p)==(p:getSex()==0 and 6750 or 6350),'Points lost on reconnect')
 check(o.lookType==variant(p,#families).look and o.lookAddons==3 and o.lookHead==58
  and o.lookBody==52 and o.lookLegs==5 and o.lookFeet==58,'Equipped appearance/addons/colours lost')
 if p:getSex()==1 then
  check(p:getItemCount(12830)==1,'Quiver purchase lost')
  check(p:hasLearnedSpell('Keychain Consume') and p:hasLearnedSpell('Keychain Unlock')
   and p:hasLearnedSpell('Keychain List'),'Keyring unlocks lost')
 end
 print((p:getSex()==0 and 'BATCH_PEER_RELOGIN_OK' or 'BATCH_MAIN_RELOGIN_OK')..' checks='..checks)
end
local function family(p,index,nextStep)
 local v=variant(p,index)
 if not v then nextStep();return end
 local starting=GameShop.getPoints(p);local oldHistory=history(p)
 buy(p,v.otherOffer,'wrong-sex-'..v.look,function()
  check(GameShop.getPoints(p)==starting and history(p)==oldHistory,'Wrong-sex offer charged: '..v.name)
  buy(p,v.offer,'buy-'..v.look,function()
   check(p:hasOutfit(v.look,3) and p:canWearOutfit(v.look,3) and GameShop.getPoints(p)==starting-250
    and history(p)==oldHistory+1,'Purchase did not unlock/debit once: '..v.name)
   local function addon(bits)
    if bits<=3 then
     wear(p,v.look,bits,'wear-'..v.look..'-'..bits,function()
      local o=p:getOutfit()
      check(o.lookType==v.look and o.lookAddons==bits and o.lookHead==58 and o.lookBody==49+bits
       and o.lookLegs==2+bits and o.lookFeet==58,'Native appearance/addon/colour failed: '..v.name..'/'..bits)
      addon(bits+1)
     end)
    else
     buy(p,v.offer,'duplicate-'..v.look,function()
      check(GameShop.getPoints(p)==starting-250 and history(p)==oldHistory+1,'Duplicate charged: '..v.name)
      wear(p,v.other,3,'wrong-sex-wear-'..v.look,function()
       check(p:getOutfit().lookType==v.look,'Wrong-sex appearance accepted: '..v.name)
       family(p,index+1,nextStep)
      end)
     end)
    end
   end
   addon(0)
  end)
 end)
end
local function female(p)
 if p:getStorageValue(950801)==1 then verifyReconnect(p);return end
 base(p)
 family(p,1,function()
  p:setStorageValue(950801,1);assert(p:save());print('BATCH_PEER_READY checks='..checks)
 end)
end
local function waitPeer(p)
 print('BATCH_PEER_LOGIN_READY');local deadline=os.mtime()+180000
 local function poll()
  local peer=Player('Batch Female')
  if peer and peer:getStorageValue(950801)==1 then
   p:setStorageValue(950800,1);assert(p:save());print('BATCH_NATIVE_READY_RELOGIN checks='..checks);return
  end
  assert(os.mtime()<deadline,'Female peer timed out');later(200,poll)
 end
 later(200,poll)
end
local function regressions(p)
 buy(p,4001,'existing-quiver',function()
  check(p:getItemCount(12830)==1 and GameShop.getPoints(p)==6600 and history(p)==14,'Existing Quiver purchase regressed')
  buy(p,1001,'existing-keyring',function()
   check(GameShop.getPoints(p)==6350 and history(p)==15 and p:hasLearnedSpell('Keychain Consume')
    and p:hasLearnedSpell('Keychain Unlock') and p:hasLearnedSpell('Keychain List'),'Existing Keyring purchase regressed')
   buy(p,1001,'existing-keyring-duplicate',function()
    check(GameShop.getPoints(p)==6350 and history(p)==15,'Duplicate Keyring charged')
    waitPeer(p)
   end)
  end)
 end)
end
local function male(p)
 if p:getStorageValue(950800)==1 then verifyReconnect(p);return end
 base(p);assert(p:addItem(1988,1,false));p:setCapacity(100000)
 local offer=GameShop.catalog[3].offers[2];local old=offer.grant.lookType
 offer.grant.lookType=372;GameShop.handleClientOpcode(p,{action='buy',data={category=3,offer=2}});offer.grant.lookType=old
 check(GameShop.getPoints(p)==initialPoints and not p:removeOutfit(372),'Invalid native grant left ownership or charged')
 assert(p:addOutfitAddon(335,1));offer.grant.lookType=335
 GameShop.handleClientOpcode(p,{action='buy',data={category=3,offer=2}});offer.grant.lookType=old
 check(GameShop.getPoints(p)==initialPoints and p:hasOutfit(335,1) and not p:hasOutfit(335,3),'Failed native grant damaged existing addons')
 assert(p:removeOutfit(335));GameShop.setPoints(p,249)
 buy(p,6006,'insufficient-new-outfit',function()
  check(GameShop.getPoints(p)==249 and not p:hasOutfit(378,0) and history(p)==0,'Unaffordable new purchase changed state')
  GameShop.setPoints(p,initialPoints);family(p,1,function()regressions(p)end)
 end)
end
local login=CreatureEvent('BatchOutfitOwnedQA')
function login.onLogin(p)
 p:setGhostMode(true)
 if p:getName()=='Batch Female'then later(500,function()female(p)end)
 elseif p:getName()=='Passive Tester'then later(500,function()male(p)end)end
 return true
end
login:register()
