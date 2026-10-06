-- Actual ordinary Plipus purchase. Root seeds disposable GUID9004/group1 offline.
-- PASSIVES_PROBE_CAP=shop_insufficient:49 cash; shop_purchase:50 cash.
-- Both runs start within3 tiles of Plipus, bank0, empty left hand, no2182,
-- no passive ranks, and an ordinary backpack available for the bought item.
-- No fixture money/item grants, server writes, spell grants, RNG/counter changes.
-- Uses actual NPC trade events and ordinary buy/move packets; not OS input testing.
local phase=assert(PASSIVES_PROBE_CAP,'Explicit shop_insufficient/shop_purchase phase required')
assert(phase=='shop_insufficient'or phase=='shop_purchase','Unknown DEV access phase')
local expectedCash=phase=='shop_insufficient'and 49 or 50
local mod,trade,player,login,metrics,rodCid,hexCid
local seq,goodsSeq,npcSeq,openSeq=0,0,0,0
local failed,done,finishing=false,false,false
local npcMessages={}
local notices={}
local function fail(reason)
 if failed or done then return end;failed=true
 print('PASSIVES_DEV_ACCESS_FAILED '..tostring(reason))
 if g_game.isOnline()then g_game.cancelAttack();g_game.closeNpcTrade();g_game.safeLogout()else g_game.cancelLogin()end
 scheduleEvent(function()g_app.exit()end,700)
end
local function later(ms,fn)
 scheduleEvent(function()if failed or done then return end;local ok,e=pcall(fn);if not ok then fail(e)end end,ms)
end
local function wait(label,predicate,fn,timeout)
 local deadline=g_clock.millis()+(timeout or 12000)
 local function poll()if predicate()then fn();return end;assert(g_clock.millis()<deadline,label..' timeout');later(70,poll)end
 later(100,poll)
end
local function fixture(fn)
 local before=seq;g_game.talk('/passivepermanent state')
 wait('ordinary state',function()return seq>before and metrics.label=='state'end,function()fn(metrics)end)
end
local function assertOrdinary(m,cash)
 assert(m.group==1 and m.vocation==3 and m.profile.mode=='permanent'and m.profile.treeId=='lifekeeper','Ordinary Ascended Lifekeeper required')
 assert(m.money==cash,'Exact inventory cash mismatch: '..tostring(m.money))
 assert(m.bank==0,'Bank must be0: ordinary NPC shop accepts inventory+bank funds')
 assert(type(m.rodClientId)=='number'and type(m.hexClientId)=='number'and m.rodClientId>0 and m.hexClientId>0 and m.rodClientId~=m.hexClientId,'Authoritative ItemType client IDs required')
 assert(type(m.rodCount)=='number','Authoritative server2182 item count required')
 if rodCid then assert(rodCid==m.rodClientId and hexCid==m.hexClientId,'ItemType mapping changed during purchase')else rodCid=m.rodClientId;hexCid=m.hexClientId end
 local ranks=m.profile.ranks;assert(type(ranks)=='table','Missing permanent ranks')
 for _,rank in pairs(ranks)do assert(rank==0,'Purchase baseline must have zero passive ranks')end
end
local function finish(evidence)
 assert(not g_game.getAttackingCreature(),'Shop test must never attack')
 print('PASSIVES_DEV_ACCESS_OK '..json.encode(evidence));finishing=true
 g_game.closeNpcTrade();g_game.safeLogout()
 wait('clean logout',function()return not g_game.isOnline()end,function()done=true;g_app.exit()end)
end
local function findOwnedRod()
 for slot=1,10 do local item=player:getInventoryItem(slot);if item and item:getId()==rodCid then return item end end
 for _,container in pairs(g_game.getContainers())do for _,item in ipairs(container:getItems())do if item:getId()==rodCid then return item end end end
end
local function equipPurchased(before)
 local function equippedSlot()
  for _,slot in ipairs({InventorySlotLeft,InventorySlotRight})do local w=player:getInventoryItem(slot);if w and w:getId()==rodCid then return slot end end
 end
 local function confirmed()
  fixture(function(m)
   assertOrdinary(m,0)
   assert(m.rodCount==1,'Bought2182 missing from authoritative server inventory')
   finish({phase=phase,cashBefore=before.money,cashAfter=m.money,serverItemCountBefore=before.rodCount,serverItemCountAfter=m.rodCount,clientItemCount=trade.playerItems[rodCid],equippedServerItemId=2182,equippedClientId=rodCid,equippedSlot=equippedSlot(),
    bankBefore=before.bank,bankAfter=m.bank,npc='Plipus The Mage',price=50,scope='Actual purchase and inventory equip; damage/mana/range/spell gates require separate native combat evidence'})
  end)
 end
 -- Server item placement may itself equip an empty slot; that is a valid actual
 -- equip result. Otherwise use the bought instance's ordinary move packet.
 if equippedSlot()then confirmed();return end
 assert(not player:getInventoryItem(InventorySlotLeft),'Do not overwrite player gear')
 local function move()
  local rod=assert(findOwnedRod(),'Purchased rod not exposed in inventory/open backpack')
  g_game.move(rod,{x=65535,y=InventorySlotLeft,z=0},1)
  wait('ordinary purchased rod equip',function()return equippedSlot()~=nil end,confirmed)
 end
 if findOwnedRod()then move();return end
 local backpack=assert(player:getInventoryItem(InventorySlotBack),'Purchased rod needs a visible backpack or inventory slot')
 g_game.open(backpack)
 wait('backpack open',function()return findOwnedRod()~=nil end,move)
end
local function purchase(before)
 local rows={}
 for _,entry in ipairs(trade.tradeItems[1]or{})do rows[#rows+1]={name=entry.name,clientId=entry.ptr:getId(),price=entry.price}end
 print('PASSIVES_DEV_ACCESS_TRADE_ROWS '..json.encode(rows))
 local function byCid(cid,name)
  local found
  for _,entry in ipairs(trade.tradeItems[1]or{})do if entry.ptr:getId()==cid then assert(not found,'Duplicate actual NPC client item: '..cid);found=entry end end
  assert(found,'Missing actual NPC client item '..cid..' ('..name..')')
  local normalized=found.name:lower():gsub('%s+',' '):match('^%s*(.-)%s*$')
  assert(normalized==name,'Mapped NPC row has unexpected name: '..found.name)
  return found
 end
 local item=byCid(rodCid,'snakebite rod');local hex=byCid(hexCid,'hex wand')
 assert(item.ptr:getId()==rodCid and hex.ptr:getId()==hexCid,'NPC item client IDs differ from authoritative2182/12746 mapping')
 assert(item.price==50 and hex.price==50,'Starter wand/rod prices differ')
 assert(before.rodCount==0 and trade.playerMoney==expectedCash and(trade.playerItems[rodCid]or 0)==0,'Wrong actual trade goods baseline')
 assert(player:getFreeCapacity()>=item.weight,'Insufficient capacity would contaminate cash boundary')
 assert(not player:getInventoryItem(InventorySlotLeft)and not player:getInventoryItem(InventorySlotRight),'Both hands must start empty')
 trade.buyWithBackpack:setChecked(false);trade.ignoreCapacity:setChecked(false)
 if phase=='shop_insufficient'then
  assert(not trade.canTradeItem(item),'Ordinary trade UI allows49-gold purchase')
  local messageBefore=#notices
  -- Send the normal buy packet despite disabled UI, to independently test server
  -- money rejection. This is not presented as a successful player click.
  g_game.buyItem(item.ptr,1,false,false)
  wait('server insufficient-money reply',function()
   for n=messageBefore+1,#notices do if notices[n]:lower():find('enough money',1,true)then return true end end
   return false
  end,function()
   fixture(function(after)
    assertOrdinary(after,49)
    assert(after.rodCount==0 and(trade.playerItems[rodCid]or 0)==0 and not findOwnedRod(),'Rejected purchase produced a rod')
    assert(after.bank==before.bank,'Rejected purchase altered bank funds')
    finish({phase=phase,cashBefore=before.money,cashAfter=after.money,rodCount=0,price=item.price,npcReplies=npcMessages,serverNotices=notices,
     scope='UI affordability false and real buy-packet server rejection; no purchased item'})
   end)
  end)
 else
  assert(trade.canTradeItem(item),'Ordinary trade UI rejects50-gold purchase')
  local box
  for _,widget in ipairs(trade.itemsPanel:getChildren())do if widget.item==item then box=widget;break end end
  assert(box and box:isEnabled(),'Rod entry is not selectable in actual trade UI')
  trade.radioItems:selectWidget(box);box:setChecked(true);trade.onItemBoxChecked(box)
  trade.quantityScroll:setValue(1)
  assert(trade.selectedItem==item and trade.tradeButton:isEnabled(),'Actual Buy handler is not ready')
  local beforeGoods=goodsSeq;trade.onTradeClick()
  wait('actual purchased trade goods',function()return goodsSeq>beforeGoods and trade.playerMoney==0 and trade.playerItems[rodCid]==1 end,function()
   fixture(function(after)
    assertOrdinary(after,0);assert(after.bank==before.bank and after.rodCount==1,'Ordinary shop cash/2182 result mismatch')
    equipPurchased(before)
   end)
  end)
 end
end
local function openShop(before)
 local p=player:getPosition()
 assert(p.z==6 and math.abs(p.x-32094)<=3 and math.abs(p.y-32227)<=3,'Root must seed player within ordinary Plipus conversation range')
 local previous=npcSeq;g_game.talkChannel(MessageModes.NpcTo,0,'hi')
 wait('real Plipus greeting',function()return npcSeq>previous end,function()
  local shopBefore=openSeq
  g_game.talkChannel(MessageModes.NpcTo,0,'trade')
  wait('fresh real NPC shop',function()return openSeq>shopBefore and trade.npcWindow:isVisible()and #(trade.tradeItems[1]or{})>0 and goodsSeq>0 end,function()purchase(before)end,20000)
 end,20000)
end
local function online()
 EnterGame.hide();player=assert(g_game.getLocalPlayer())
 wait('ordinary catalog',function()local s=mod.getState();return s.ready and s.active and s.mode=='permanent'end,function()
  fixture(function(m)assertOrdinary(m,expectedCash);openShop(m)end)
 end)
end
later(200,function()
 assert(LOCAL_PASSIVES_TEST and Services.updater==''and g_resources.getLayout()=='retro','Isolated retro local runner required')
 mod=assert(modules.game_passives);trade=assert(modules.game_npctrade)
 connect(g_game,{onTextMessage=function(_,message)
  print('PASSIVES_DEV_ACCESS_MESSAGE '..message)
  notices[#notices+1]=message
  local payload=message:match('^PASSIVE_PERMANENT_STATE (.+)$')
  if payload then metrics=json.decode(payload);seq=seq+1 end
 end,onPlayerGoods=function()goodsSeq=goodsSeq+1 end,
 onOpenNpcTrade=function(items)
  openSeq=openSeq+1;local rows={}
  for _,item in ipairs(items)do rows[#rows+1]={name=item[2],clientId=item[1]:getId(),buyPrice=item[4],sellPrice=item[5]}end
  print('PASSIVES_DEV_ACCESS_OPEN_TRADE '..json.encode(rows))
 end,
 onTalk=function(name,_,_,message)if name=='Plipus The Mage'then npcSeq=npcSeq+1;npcMessages[#npcMessages+1]=message;print('PASSIVES_DEV_ACCESS_NPC '..message)end end,
 onGameStart=function()later(250,online)end,
 onConnectionError=function(e)if not finishing then fail(e)end end})
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 G.account='passivemagic';G.password=G.account
 login=ProtocolLogin.create();_G.devAccessLogin=login
 login.onLoginError=function(_,e)fail(e)end
 login.onCharacterList=function(_,list)
  for _,character in ipairs(list)do if character.name=='Passive Mystic'then
   g_game.loginWorld(G.account,G.password,character.worldName,character.worldIp,character.worldPort,character.name,'','');return
  end end
  fail('Disposable ordinary Passive Mystic missing')
 end
 login:login('127.0.0.1',7174,G.account,G.password,'',false)
end)
scheduleEvent(function()if not done then fail('65-second DEV access timeout')end end,65000)
