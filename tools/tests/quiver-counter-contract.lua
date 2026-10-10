-- Execute the actual inventory controller and JSON decoder with UI/transport
-- doubles. No client, native render, server, network or profile access.
local sourcePath = arg[1] or 'modules/game_inventory/quiver.lua'
local jsonPath = arg[2] or 'modules/corelib/json.lua'
dofile(jsonPath)

local checks, requests, events, sequence = 0, {}, {}, 0
local online, hovered = true, false
local firstProtocol, secondProtocol = {}, {}
local activeProtocol = firstProtocol
local callback, savedCallback
local tooltipVisible
local function check(value, message)
  assert(value, message)
  checks = checks + 1
end
local function item(id, count)
  return {getId=function()return id end, getCount=function()return count end}
end
local quiverA, quiverB, ordinaryArrow = item(11867,1), item(11867,1), item(2544,99)
local equipment = {[10]=quiverA}
local player = {getInventoryItem=function(_, slot)return equipment[slot]end}
local widget = {children={}, tooltip='Original slot hint'}
function widget:getChildById(id)return self.children[id]end
function widget:getTooltip()return self.tooltip end
function widget:setTooltip(text)self.tooltip=text end
function widget:isHovered()return hovered end
function widget:setItemCount()error('The quiver badge must not alter Item.count')end
function firstProtocol:sendExtendedOpcode(opcode, buffer)
  requests[#requests+1]={protocol=self,opcode=opcode,buffer=buffer}
end
secondProtocol.sendExtendedOpcode=firstProtocol.sendExtendedOpcode
local environment = {
  InventorySlotAmmo=10,InventorySlotLeft=6,InventorySlotRight=5,
  GameExtendedOpcode=80,AlignBottomRight=10,AnchorLeft=1,AnchorRight=2,AnchorBottom=3,
  inventoryPanel={getChildById=function(_,id)assert(id=='slot10');return widget end},
  g_game={isOnline=function()return online end,getLocalPlayer=function()return player end,
    getProtocolGame=function()return activeProtocol end,getFeature=function()return true end,
    getContainers=function()error('Closed quiver counts cannot use client container cache')end},
  ProtocolGame={
    registerExtendedOpcode=function(opcode,fn)assert(opcode==104 and not callback);callback=fn;savedCallback=fn end,
    unregisterExtendedOpcode=function(opcode)assert(opcode==104 and callback);callback=nil end},
  g_tooltip={display=function(text)tooltipVisible=text end,hide=function()tooltipVisible=nil end},
  tr=function(text,...)return string.format(text,...)end,
  scheduleEvent=function(fn,delay)
    assert(delay==100,'Status recovery must be coalesced, not periodic polling')
    sequence=sequence+1;events[sequence]=fn;return sequence
  end,
  removeEvent=function(id)events[id]=nil end,
  g_ui={createWidget=function(style,parent)
    assert(style=='Label' and parent==widget)
    local label={visible=false,anchors={}}
    function label:setId(id)self.id=id;parent.children[id]=self end
    function label:setPhantom(value)self.phantom=value end
    function label:setFocusable(value)self.focusable=value end
    function label:setFont(value)self.font=value end
    function label:setColor(value)self.color=value end
    function label:setTextAlign(value)self.align=value end
    function label:setHeight(value)self.height=value end
    function label:addAnchor(...)self.anchors[#self.anchors+1]={...}end
    function label:setMarginRight(value)self.marginRight=value end
    function label:setText(value)self.text=value end
    function label:show()self.visible=true end
    function label:hide()self.visible=false end
    return label
  end}
}
setmetatable(environment,{__index=_G})
local chunk=assert(loadfile(sourcePath));setfenv(chunk,environment);chunk()
local controller=environment.QuiverAmmo
local function runEvents()
  local ids={};for id in pairs(events)do ids[#ids+1]=id end;table.sort(ids)
  for _,id in ipairs(ids)do local fn=events[id];events[id]=nil;if fn then fn()end end
end
local function countEvents()
  local count=0;for _ in pairs(events)do count=count+1 end;return count
end
local function snapshot(arrows,bolts,required,other)
  required=required or 'arrow'
  return {schema=1,equipped=true,quiverCid=11867,total=arrows+bolts+(other or 0),arrows=arrows,
    bolts=bolts,compatible=required=='arrow' and arrows or required=='bolt' and bolts or 0,
    requiredAmmo=required,launcherReady=required~='none'}
end
local function receive(data,protocol)
  assert(callback,'Opcode handler missing')
  callback(protocol or activeProtocol,104,type(data)=='string' and data or json.encode(data))
end
local function badge()return widget.children.quiverAmmoCount end
local function shownCount()local b=badge();return b and b.visible and b.text or nil end
local function contains(text,part)return text and text:find(part,1,true)~=nil end

controller.init();controller.start()
check(shownCount()==nil,'A count was invented before the server snapshot')
runEvents()
check(#requests==1 and requests[1].opcode==104 and requests[1].buffer=='status','Login status recovery changed')
check(countEvents()==0,'Status request became periodic polling')

for _,count in ipairs({0,1,100,101,2000})do
  receive(snapshot(count,5))
  check(shownCount()==tostring(count),'Exact authoritative compatible count was not displayed: '..count)
  check(contains(widget.tooltip,'Arrows: '..count) and contains(widget.tooltip,'Bolts: 5'),'Ammo types were lost')
  check(not contains(widget.tooltip,'quiver is empty'),'Filled incompatible quiver was called empty')
  check(quiverA:getCount()==1,'Native quiver Item.count was overwritten')
end
check(badge().phantom and not badge().focusable,'Badge intercepts item interaction')
check(badge().font=='verdana-11px-rounded' and badge().marginRight==3,'Badge diverged from ordinary count style')

receive(snapshot(0,0))
check(shownCount()==nil and contains(widget.tooltip,'The quiver is empty.'),'Empty quiver artwork is obscured or lacks its tooltip')
receive(snapshot(100,12,'bolt'))
check(shownCount()=='12' and contains(widget.tooltip,'Usable with your crossbow: 12 bolts'),'Crossbow usable count did not switch type')
receive(snapshot(100,12,'none'))
check(shownCount()=='112' and contains(widget.tooltip,'number shown is the total ammunition'),'No-launcher total fallback is ambiguous')
check(contains(widget.tooltip,'Equip a bow or crossbow'),'No-launcher tooltip omitted how to use the ammo')
receive(snapshot(100,12,'none',7))
check(shownCount()=='119' and contains(widget.tooltip,'Other ammunition: 7'),'Future ammo type was discarded from total')

-- A closed quiver consumes across a 100-round boundary through server pushes.
receive(snapshot(101,5));receive(snapshot(100,5));receive(snapshot(99,5))
check(shownCount()=='99' and countEvents()==0,'Closed-container shot updates required local cache or polling')
hovered=true
receive(snapshot(98,5))
check(contains(tooltipVisible,'Arrows: 98'),'Visible hovered tooltip retained a former shot count')
hovered=false

-- Same-CID replacements must never inherit the former quiver's state.
equipment[10]=quiverB;controller.onInventoryChange(10)
check(controller.getState()==nil and shownCount()==nil,'Same-CID replacement retained old ammo')
check(widget.tooltip=='Original slot hint','Removing decoration retained old quiver tooltip')
controller.onInventoryChange(5);controller.onInventoryChange(6)
check(countEvents()==1,'Equipment changes did not coalesce recovery requests')
local before=#requests;runEvents()
check(#requests==before+1,'Same-CID replacement did not recover with one status request')
receive(snapshot(4,12,'bolt'))
check(shownCount()=='12','Replacement snapshot did not populate new quiver')
controller.onInventoryChange(5)
check(shownCount()==nil,'Hand change retained a former launcher count')
receive(snapshot(4,12,'arrow'))
check(shownCount()=='4' and countEvents()==0,'Native push failed to cancel redundant recovery')
controller.onInventoryChange(5)
local obsolete;for _,fn in pairs(events)do obsolete=fn end
controller.onInventoryChange(6)
obsolete()
check(countEvents()==1,'An obsolete callback discarded the newer recovery event')
receive(snapshot(4,12,'arrow'))
check(countEvents()==0,'An obsolete callback prevented cancellation of the newer recovery event')
local isolated=controller.getState();isolated.compatible=999
check(shownCount()=='4' and controller.getState().compatible==4,'Caller mutated accepted authoritative state')

local valid=snapshot(4,12,'arrow')
local function corrupt(field,value)
  local copy={};for key,data in pairs(valid)do copy[key]=data end;copy[field]=value;receive(copy)
  check(shownCount()=='4','Malformed field replaced accepted snapshot: '..field)
end
corrupt('schema',2);corrupt('equipped','true');corrupt('quiverCid',11469)
corrupt('arrows',-1);corrupt('total',3);corrupt('compatible',5)
corrupt('bolts',0.5);corrupt('requiredAmmo','stone');corrupt('launcherReady',false)
receive('{broken');receive(string.rep('x',4097))
check(shownCount()=='4','Bad JSON/oversized packet changed the display')
receive(snapshot(99,0),secondProtocol)
check(shownCount()=='4','Foreign protocol changed authoritative state')

receive({schema=1,equipped=false,quiverCid=0,total=0,arrows=0,bolts=0,compatible=0,requiredAmmo='none',launcherReady=false})
check(shownCount()==nil and widget.tooltip=='Original slot hint','Server clear retained old quiver decoration')
receive(snapshot(4,12))
equipment[10]=ordinaryArrow;controller.onInventoryChange(10);runEvents()
check(shownCount()==nil and ordinaryArrow:getCount()==99,'Ordinary ammo count was altered')
check(countEvents()==0,'Ordinary ammo caused repeated quiver status requests')
receive(snapshot(2000,0))
check(shownCount()==nil,'Quiver snapshot decorated ordinary ammunition')
equipment[10]=nil;controller.onInventoryChange(10)
check(shownCount()==nil and controller.getState()==nil,'Unequip retained authoritative contents')

equipment[10]=quiverA;controller.onInventoryChange(10)
local stale;for _,fn in pairs(events)do stale=fn end
online=false;controller.reset()
check(shownCount()==nil and countEvents()==0,'Logout retained decoration or recovery timer')
before=#requests;stale();receive(snapshot(88,0))
check(#requests==before and controller.getState()==nil,'Logout accepted stale request/packet')
activeProtocol=secondProtocol;online=true;controller.start()
receive(snapshot(88,0),firstProtocol)
check(controller.getState()==nil and shownCount()==nil,'Relog inherited old connection state')
receive(snapshot(7,2,'bolt'))
check(shownCount()=='2','New protocol snapshot failed after relog')
widget:setTooltip('External item hint');controller.reset()
check(widget.tooltip=='External item hint','Decoration removal overwrote another tooltip owner')
controller.start();controller.terminate()
check(callback==nil and countEvents()==0 and controller.getState()==nil,'Termination retained callback, timer or state')
savedCallback(activeProtocol,104,json.encode(snapshot(99,0)))
check(controller.getState()==nil and shownCount()==nil,'A captured callback wrote state after termination')
print('QUIVER_COUNTER_CONTRACT_OK checks='..checks..' pureSource=true native=false')
