-- Installed only into the runner's cold loopback copy. Never ordinary game data.
local function owned(p)
  return p:getGuid()==9001 and configManager.getString(configKeys.SERVER_NAME)=='Rookhaven Ancients QA'
    and (p:getIp()==0x0100007F or p:getIp()==0x7F000001) and p:getGroup():getId()==1
end
local function emit(p,label,extra)
  local r=extra or {};r.label=label;r.claim=p:getStorageValue(70078);r.choice=p:getStorageValue(70176);r.vocation=p:getVocation():getId()
  r.rods=p:getItemCount(12856);r.wands=p:getItemCount(12753)
  print('ANCIENTS_NATIVE '..json.encode(r));p:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,'ANCIENTS_NATIVE '..json.encode(r))
end
local function clear(p)
  AncientsReward.clearPlayer(p)
  for slot=CONST_SLOT_HEAD,CONST_SLOT_AMMO do local i=p:getSlotItem(slot);if i then i:remove()end end
  assert(p:addItem(1988,1,false,1,CONST_SLOT_BACKPACK),'backpack')
  p:setCapacity(10000)
end
local function beside(p,pos)
  for _,offset in ipairs({{-1,0},{1,0},{0,-1},{0,1}})do
    local dest=Position(pos.x+offset[1],pos.y+offset[2],pos.z);local tile=Tile(dest)
    if tile and tile:getGround()and (not tile:getTopCreature()or tile:getTopCreature()==p)and not tile:hasFlag(TILESTATE_BLOCKSOLID)then
      assert(p:teleportTo(dest));return
    end
  end
  error('No adjacent QA tile')
end
local command=TalkAction('/ancientsqa')
function command.onSay(p,words,param)
  if not owned(p)then return false end
  local ok,reason=pcall(function()
    if param=='reset'then
      clear(p);p:setStorageValue(70078,-1);p:setStorageValue(70176,-1)
      local chest=assert(Item(30157));beside(p,chest:getPosition())
      local pos=chest:getPosition();emit(p,'reset',{chest={x=pos.x,y=pos.y,z=pos.z}})
    elseif param=='capzero'then p:setCapacity(0);emit(p,'capzero')
    elseif param=='capok'then p:setCapacity(10000);emit(p,'capok')
    elseif param=='rest'then
      p:setTarget(nil);assert(p:teleportTo(Position(32097,32219,7)))
      p:removeCondition(CONDITION_INFIGHT)
      assert(not p:getTile():hasFlag(TILESTATE_NOLOGOUT),'QA logout tile')
      emit(p,'rest',{inFight=p:hasCondition(CONDITION_INFIGHT)})
    elseif param=='state'then
      local found=p:getItemById(12856,true)or p:getItemById(12753,true)
      emit(p,'state',{name=found and found:getName(),article=found and found:getArticle(),
        affixes=found and CorruptedUpgrade.readAffixState(found,'epic')})
    elseif param=='legacy'then
      clear(p);p:setStorageValue(70078,1);p:setStorageValue(70176,-1)
      local wand=assert(p:getSlotItem(CONST_SLOT_BACKPACK):addItem(12753,1))
      assert(RarityRolls.applyRarityWithFixedValues(wand,'epic',{{35,1},{14,6}})==1)
      wand:setAttribute(ITEM_ATTRIBUTE_NAME,'wand of the Ssythari')
      assert(CorruptedUpgrade.applyAffixState(wand,'epic',{count=2,totals={['14']=9,['35']=3},instances={['14']={9},['35']={3}}}))
      local npc=assert(Npc(PlipusNpcId),'Plipus not spawned');beside(p,npc:getPosition());emit(p,'legacy')
    elseif param=='levels'then
      clear(p)
      local tiers={[2182]=7,[12850]=13,[12851]=20,[12852]=7,[12853]=13,[12854]=20,[12855]=7,[12856]=13,[12857]=20}
      for _,tier in ipairs({{7,12741,12742,12743,12744,12746,12747,12748},{13,12745,12749,12750,12751,12752,12753},{20,12754,12755,12756,12757,12758,12759}})do
        for n=2,#tier do tiers[tier[n]]=tier[1]end
      end
      local checked=0
      for _,level in ipairs({20,19,13,12,7,6})do
        p:removeExperience(p:getExperience()-Game.getExperienceForLevel(level),false)
        assert(p:getLevel()==level,'fixture level')
        -- Level loss also subtracts vocation CAP. Isolate equip levels from
        -- that reset effect; CAP refusal is exercised separately above.
        p:setCapacity(1000000)
        for sid,required in pairs(tiers)do
          assert(ItemType(sid):getMinReqLevel()==required,'native tier metadata '..sid)
          for _,slot in ipairs({CONST_SLOT_LEFT,CONST_SLOT_RIGHT})do
            local equipped=p:addItem(sid,1,false,1,slot)
            if (equipped~=nil)~=(level>=required)then
              local sample=assert(Game.createItem(sid,1));local code=p:addItemEx(sample,false,slot)
              local other=p:getSlotItem(slot==CONST_SLOT_LEFT and CONST_SLOT_RIGHT or CONST_SLOT_LEFT)
              error(string.format('equip %d at %d in %d: %s; slotmask=%d other=%s',sid,level,slot,
                Game.getReturnMessage(code),ItemType(sid):getSlotPosition(),other and other:getId()or 'none'))
            end
            if equipped then equipped:remove()end
            checked=checked+1
          end
        end
        local ordinary=assert(p:addItem(2403,1,false,1,CONST_SLOT_LEFT),'ordinary knife regression');ordinary:remove()
      end
      p:setTarget(nil);p:removeCondition(CONDITION_INFIGHT)
      emit(p,'levels',{checked=checked,ordinaryKnifeChecks=6})
    else error('unknown command')end
  end)
  if not ok then emit(p,'FAILED',{reason=tostring(reason)})end
  return false
end
command:separator(' ');command:register()
local started=GlobalEvent('AncientsOwnedQaReady')
function started.onStartup()print('ANCIENTS_NATIVE_SERVER_READY');return true end
started:type('startup');started:register()
