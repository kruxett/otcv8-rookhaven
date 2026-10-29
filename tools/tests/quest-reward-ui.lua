-- Actual client module with modeled widgets/protocol. Native rendering is separate.
dofile(CLIENT..'/modules/corelib/json.lua')
local sent,windows,handler,gameEnd={},{},nil,nil
local checks=0
local function check(value,label)checks=checks+1;assert(value,label)end
local function widget()
  local w={children={},enabled=true}
  function w:getChildById(id)if not self.children[id]then self.children[id]=widget()end;return self.children[id]end
  w.recursiveGetChildById=w.getChildById
  function w:setEnabled(v)self.enabled=v end
  function w:setText(v)self.text=v end
  function w:setBorderColor(v)self.border=v end
  function w:setItemId(v)self.itemId=v end
  function w:show()end;function w:raise()end;function w:focus()end
  function w:grabKeyboard()self.grabbed=true end
  function w:ungrabKeyboard()self.grabbed=false end
  function w:destroy()self.destroyed=true end
  return w
end
rootWidget=widget()
g_ui={displayUI=function(name,parent)check(name=='questreward'and parent==rootWidget,'UI target');local w=widget();windows[#windows+1]=w;return w end}
g_ui.createWidget=function()error('No extra inspection window should be created')end
local protocol={sendExtendedOpcode=function(_,op,s)check(op==106,'client opcode');sent[#sent+1]=json.decode(s)end}
g_game={isOnline=function()return true end,getProtocolGame=function()return protocol end}
ProtocolGame={registerExtendedOpcode=function(op,fn)check(op==106,'register');handler=fn end,unregisterExtendedOpcode=function()handler=nil end}
connect=function(_,events)gameEnd=events.onGameEnd end
disconnect=function()gameEnd=nil end
tr=function(s)return s end
displayInfoBox=function()end
dofile(CLIENT..'/modules/game_questreward/questreward.lua')
init()
local function offer(token)
  handler(protocol,106,json.encode({action='offer',token=token,message='One Epic reward.',
    choices={{key='wand',name='Dusk Wand',clientId=10992,role='Wand',element='Death',summary='8-15 death',bonuses='Epic: +6 death damage | +1 Mana Regen'},
      {key='rod',name='Gravebloom Rod',clientId=11893,role='Rod',element='Earth',summary='6-12 earth',bonuses='Epic: +6 earth damage | +1 Mana Regen'}}}))
  return windows[#windows]
end
local first=offer('one')
check(first.grabbed and not first:getChildById('confirm').enabled,'no implicit choice')
first.onEnter();check(#sent==0,'enter without selection')
first:getChildById('wand').onClick()
check(first:getChildById('confirm').enabled and first:getChildById('wand').border=='#c8a456','wand selected')
check(first:getChildById('wand'):getChildById('summary').text=='8-15 death','inline weapon details')
check(first:getChildById('wand'):getChildById('bonuses').text:find('+6 death damage',1,true),'inline wand bonus')
first:getChildById('rod').onClick()
check(first:getChildById('rod'):getChildById('role').text:find('Earth'),'individual element shown')
check(first:getChildById('rod'):getChildById('bonuses').text:find('+6 earth damage',1,true)and #sent==0,'inline rod bonus without claiming')
first:getChildById('rod').onClick();first:getChildById('confirm').onClick()
check(sent[#sent].action=='choose'and sent[#sent].choice=='rod'and sent[#sent].token=='one','selected rod payload')
local count=#sent;confirm();check(#sent==count and not first:getChildById('confirm').enabled,'double click disabled')
handler(protocol,106,json.encode({action='result',token='stale',success=true,closed=true}))
check(not first.destroyed,'stale result ignored')
handler(protocol,106,json.encode({action='result',token='one',success=false,message='Make room.'}))
check(not first.destroyed and first:getChildById('confirm').enabled and first:getChildById('status').text=='Make room.','refusal permits retry')
confirm();check(#sent==count+1,'retry')
handler(protocol,106,json.encode({action='result',token='one',success=true,closed=true}))
check(first.destroyed and not first.grabbed,'successful claim closes')
local second=offer('two');second.onEscape()
check(second.destroyed and sent[#sent].action=='cancel'and sent[#sent].token=='two','escape cancels')
second=offer('three');local third=offer('four')
check(second.destroyed and not third.destroyed,'new offer replaces UI')
handler(protocol,106,json.encode({action='close',token='three'}));check(not third.destroyed,'old expiry ignored')
handler(protocol,106,json.encode({action='close',token='four'}));check(third.destroyed,'current expiry closes')
local n=#windows
handler(protocol,106,'not json');handler(protocol,106,json.encode({action='offer',token='bad',message='',choices={}}))
check(#windows==n,'malformed offers ignored')
local fourth=offer('five');gameEnd();check(fourth.destroyed,'logout closes')
terminate();check(handler==nil and gameEnd==nil,'module cleanup')
print('QUEST_REWARD_UI_CONTRACT_OK checks='..checks..' nativeRendering=false')
