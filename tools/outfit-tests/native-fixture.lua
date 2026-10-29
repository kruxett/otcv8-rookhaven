-- Current native server: real shop opcodes, sex locks, outfit packets and persistence.
assert(configManager.getString(configKeys.SERVER_NAME)=='Rookhaven Acolyte QA')
local checks,seq=0,0
local function check(ok,why)assert(ok,why);checks=checks+1 end
local function later(ms,fn)addEvent(function()local ok,e=pcall(fn);if not ok then print('ACOLYTE_NATIVE_FAILED '..tostring(e))end end,ms)end
local function wire(label,kind,values)
 seq=seq+1;values.sequence=seq;values.label=label;values.kind=kind;print('ACOLYTE_WIRE '..json.encode(values))
end
local function buy(p,id,label,nextStep)
 local ci,oi
 for c,category in ipairs(GameShop.catalog)do for o,offer in ipairs(category.offers)do if offer.id==id then ci,oi=c,o end end end
 assert(ci)
 wire(label,'buy',{category=ci,offer=oi,actor=p:getSex()==0 and 'peer' or nil})
 later(400,nextStep)
end
local function wear(p,look,label,nextStep)
 wire(label,'set_outfit',{look=look,addons=3,actor=p:getSex()==0 and 'peer' or nil})
 later(400,nextStep)
end
local function ownHistory(p)return #(GameShop.historyByGuid[p:getGuid()]or{})end
local function baseChecks(p,look,other)
 check(p:getGroup():getId()==1 and not p:isPremium(),'Fixture must be an ordinary free character')
 check(not p:hasOutfit(look,0) and not p:canWearOutfit(look,3),'Paid outfit already available without purchase')
 check(not p:canWearOutfit(other,0),'Wrong-sex outfit was available')
 GameShop.setPoints(p,1000)
end
local function doneFemale(p)
 check(p:getOutfit().lookType==373 and p:getOutfit().lookAddons==3,'Female outfit packet failed')
 check(p:canWearOutfit(373,3) and not p:canWearOutfit(374,3),'Female sex mapping failed')
 p:setStorageValue(950801,1);assert(p:save());print('ACOLYTE_PEER_READY checks='..checks)
end
local function female(p)
 if p:getStorageValue(950801)==1 then
  check(p:hasOutfit(373,3) and p:canWearOutfit(373,3) and GameShop.getPoints(p)==750,'Female unlock/balance lost on reconnect')
  check(p:getOutfit().lookType==373 and not p:canWearOutfit(374,3),'Female appearance/sex lock lost')
  print('ACOLYTE_PEER_RELOGIN_OK checks='..checks);return
 end
 baseChecks(p,373,374)
 buy(p,6002,'female-wrong-sex',function()
  check(GameShop.getPoints(p)==1000 and ownHistory(p)==0,'Wrong-sex female purchase charged')
  buy(p,6001,'female-buy',function()
   check(p:hasOutfit(373,3) and GameShop.getPoints(p)==750 and ownHistory(p)==1,'Female purchase failed')
   wear(p,373,'female-wear',function()doneFemale(p)end)
  end)
 end)
end
local function waitPeer(p)
 print('ACOLYTE_PEER_LOGIN_READY')
 local deadline=os.mtime()+20000
 local function poll()
  local peer=Player('Acolyte Female')
  if peer and peer:getStorageValue(950801)==1 then
   p:setStorageValue(950800,1);assert(p:save());print('ACOLYTE_NATIVE_READY_RELOGIN checks='..checks);return
  end
  assert(os.mtime()<deadline,'Female peer timed out');later(200,poll)
 end
 later(200,poll)
end
local function male(p)
 if p:getStorageValue(950800)==1 then
  check(p:hasOutfit(374,3) and p:canWearOutfit(374,3) and GameShop.getPoints(p)==600,'Male outfit/balance lost on reconnect')
  check(p:getOutfit().lookType==374 and p:getItemCount(12830)==1,'Equipped appearance or normal purchased item lost')
  check(not p:canWearOutfit(373,3),'Male sex lock lost on reconnect')
  print('ACOLYTE_MAIN_RELOGIN_OK checks='..checks);return
 end
 baseChecks(p,374,373);assert(p:addItem(1988,1,false));p:setCapacity(100000)
 -- Native failure must remove the new entry and retain previous addons.
 local offer=GameShop.catalog[3].offers[2];local old=offer.grant.lookType
 offer.grant.lookType=372;GameShop.handleClientOpcode(p,{action='buy',data={category=3,offer=2}});offer.grant.lookType=old
 check(GameShop.getPoints(p)==1000 and not p:removeOutfit(372),'Failed invalid outfit grant leaked state')
 assert(p:addOutfitAddon(335,1));offer.grant.lookType=335
 GameShop.handleClientOpcode(p,{action='buy',data={category=3,offer=2}});offer.grant.lookType=old
 check(GameShop.getPoints(p)==1000 and p:hasOutfit(335,1) and not p:hasOutfit(335,3),'Failed premium-gated grant damaged prior addon ownership')
 assert(p:removeOutfit(335))
 GameShop.setPoints(p,249)
 buy(p,6002,'male-insufficient',function()
  check(GameShop.getPoints(p)==249 and not p:hasOutfit(374,0) and ownHistory(p)==0,'Unaffordable outfit charged/granted')
  GameShop.setPoints(p,1000)
  buy(p,6001,'male-wrong-sex',function()
   check(GameShop.getPoints(p)==1000 and ownHistory(p)==0,'Wrong-sex male purchase charged')
   buy(p,6002,'male-buy',function()
    check(p:hasOutfit(374,3) and p:canWearOutfit(374,3) and GameShop.getPoints(p)==750 and ownHistory(p)==1,'Male purchase failed')
    wear(p,374,'male-wear',function()
     local out=p:getOutfit();check(out.lookType==374 and out.lookAddons==3 and out.lookHead==58 and out.lookBody==49 and out.lookLegs==2 and out.lookFeet==58,'Male outfit/colours packet failed')
     buy(p,6002,'male-duplicate',function()
      check(GameShop.getPoints(p)==750 and ownHistory(p)==1,'Duplicate purchase charged')
      wear(p,373,'male-wrong-sex-wear',function()
       check(p:getOutfit().lookType==374,'Wrong-sex outfit packet changed appearance')
       buy(p,4001,'normal-quiver-regression',function()
        check(p:getItemCount(12830)==1 and GameShop.getPoints(p)==600 and ownHistory(p)==2,'Ordinary item purchase regressed')
        waitPeer(p)
       end)
      end)
     end)
    end)
   end)
  end)
 end)
end
local login=CreatureEvent('AcolyteOwnedQA')
function login.onLogin(p)
 p:setGhostMode(true)
 if p:getName()=='Acolyte Female'then later(500,function()female(p)end)
 elseif p:getName()=='Passive Tester'then later(500,function()male(p)end)end
 return true
end
login:register()

