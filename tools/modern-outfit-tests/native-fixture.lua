-- Actual shop packets, native rights, addon masks and save/relogin for all four variants.
assert(configManager.getString(configKeys.SERVER_NAME)=='Rookhaven Modern Outfit QA')
local checks,sequence=0,0
local function check(ok,why)assert(ok,why);checks=checks+1 end
local function later(ms,fn)addEvent(function()local ok,e=pcall(fn);if not ok then print('MODERN_NATIVE_FAILED '..tostring(e))end end,ms)end
local function history(p)return #(GameShop.historyByGuid[p:getGuid()]or{})end
local function wire(p,label,kind,data,nextStep)
 sequence=sequence+1;data.sequence=sequence;data.label=label;data.kind=kind
 data.actor=p:getSex()==0 and 'peer' or nil
 print('MODERN_WIRE '..json.encode(data));later(600,nextStep)
end
local function buy(p,id,label,nextStep)
 for ci,category in ipairs(GameShop.catalog)do for oi,offer in ipairs(category.offers)do
  if offer.id==id then wire(p,label,'buy',{category=ci,offer=oi},nextStep);return end
 end end
 error('Missing offer '..id)
end
local function wear(p,look,addons,label,nextStep)
 wire(p,label,'set_outfit',{look=look,addons=addons},nextStep)
end
local function variants(p)
 return p:getSex()==0 and {{373,374,6001,6002},{375,376,6003,6004}}
  or {{374,373,6002,6001},{376,375,6004,6003}}
end
local function base(p)
 check(p:getGroup():getId()==1 and not p:isPremium(),'Must use ordinary free characters')
 for _,v in ipairs(variants(p))do
  p:removeOutfit(v[1]);p:removeOutfit(v[2])
  check(not p:hasOutfit(v[1],0) and not p:canWearOutfit(v[1],3),'Paid outfit available before purchase')
  check(not p:canWearOutfit(v[2],0),'Wrong-sex outfit initially available')
 end
 GameShop.setPoints(p,1000)
end
local function verifyReconnect(p)
 for _,v in ipairs(variants(p))do
  check(p:hasOutfit(v[1],3) and p:canWearOutfit(v[1],3),'Purchased outfit lost on relog')
  check(not p:canWearOutfit(v[2],3),'Sex restriction lost on relog')
 end
 check(GameShop.getPoints(p)==(p:getSex()==0 and 500 or 350) and p:getOutfit().lookType==variants(p)[2][1]
  and p:getOutfit().lookAddons==3,'Balance or equipped outfit lost on relog')
 if p:getSex()==1 then check(p:getItemCount(12830)==1,'Normal Quiver purchase lost on relog')end
 print((p:getSex()==0 and 'MODERN_PEER_RELOGIN_OK' or 'MODERN_MAIN_RELOGIN_OK')..' checks='..checks)
end
local function family(p,index,nextStep)
 local v=variants(p)[index]
 if not v then nextStep();return end
 local starting=GameShop.getPoints(p);local oldHistory=history(p)
 buy(p,v[4],'wrong-sex-'..v[1],function()
  check(GameShop.getPoints(p)==starting and history(p)==oldHistory,'Wrong-sex offer charged')
  buy(p,v[3],'buy-'..v[1],function()
   check(p:hasOutfit(v[1],3) and p:canWearOutfit(v[1],3) and GameShop.getPoints(p)==starting-250
    and history(p)==oldHistory+1,'Purchase did not unlock/debit exactly once')
   local function addon(bits)
    if bits<=3 then
     wear(p,v[1],bits,'wear-'..v[1]..'-'..bits,function()
      local o=p:getOutfit()
      check(o.lookType==v[1] and o.lookAddons==bits and o.lookHead==58 and o.lookBody==49
       and o.lookLegs==2 and o.lookFeet==58,'Native appearance/addon/colour packet failed')
      addon(bits+1)
     end)
    else
     buy(p,v[3],'duplicate-'..v[1],function()
      check(GameShop.getPoints(p)==starting-250 and history(p)==oldHistory+1,'Duplicate charged again')
      wear(p,v[2],3,'wrong-sex-wear-'..v[1],function()
       check(p:getOutfit().lookType==v[1],'Wrong-sex appearance accepted')
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
  p:setStorageValue(950801,1);assert(p:save());print('MODERN_PEER_READY checks='..checks)
 end)
end
local function waitPeer(p)
 print('MODERN_PEER_LOGIN_READY');local deadline=os.mtime()+30000
 local function poll()
  local peer=Player('Modern Female')
  if peer and peer:getStorageValue(950801)==1 then
   p:setStorageValue(950800,1);assert(p:save());print('MODERN_NATIVE_READY_RELOGIN checks='..checks);return
  end
  assert(os.mtime()<deadline,'Female peer timed out');later(200,poll)
 end
 later(200,poll)
end
local function male(p)
 if p:getStorageValue(950800)==1 then verifyReconnect(p);return end
 base(p);assert(p:addItem(1988,1,false));p:setCapacity(100000)
 local offer=GameShop.catalog[3].offers[2];local old=offer.grant.lookType
 offer.grant.lookType=372;GameShop.handleClientOpcode(p,{action='buy',data={category=3,offer=2}});offer.grant.lookType=old
 check(GameShop.getPoints(p)==1000 and not p:removeOutfit(372),'Invalid native grant left ownership or charged')
 assert(p:addOutfitAddon(335,1));offer.grant.lookType=335
 GameShop.handleClientOpcode(p,{action='buy',data={category=3,offer=2}});offer.grant.lookType=old
 check(GameShop.getPoints(p)==1000 and p:hasOutfit(335,1) and not p:hasOutfit(335,3),'Failed native grant damaged existing addons')
 assert(p:removeOutfit(335));GameShop.setPoints(p,249)
 buy(p,6002,'insufficient',function()
  check(GameShop.getPoints(p)==249 and not p:hasOutfit(374,0) and history(p)==0,'Unaffordable purchase changed state')
  GameShop.setPoints(p,1000)
  family(p,1,function()
   buy(p,4001,'existing-quiver-purchase',function()
    check(p:getItemCount(12830)==1 and GameShop.getPoints(p)==350 and history(p)==3,'Existing item purchase regressed')
    waitPeer(p)
   end)
  end)
 end)
end
local login=CreatureEvent('ModernOutfitOwnedQA')
function login.onLogin(p)
 p:setGhostMode(true)
 if p:getName()=='Modern Female'then later(500,function()female(p)end)
 elseif p:getName()=='Passive Tester'then later(500,function()male(p)end)end
 return true
end
login:register()
