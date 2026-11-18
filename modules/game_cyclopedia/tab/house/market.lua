-- Transport for the existing Cyclopedia house views/forms in house.otui.
-- View state stays in house.lua; money and permission decisions stay on server.
HouseMarketUI = {}
local H=HouseMarketUI
local OPCODE=118
local root,timeout,pending,data,selected
local enabled,requestId=false,0
local filters={page=1,townId=0,filter='all',status=0,sort='name',search=''}
local function status(message,failed)
  if Cyclopedia.setHouseStatus then Cyclopedia.setHouseStatus(message or '',failed) end
end
local function clearPending()
  if timeout then removeEvent(timeout);timeout=nil end
  pending=nil
  if Cyclopedia.setHouseBusy then Cyclopedia.setHouseBusy(false) end
end
local function send(action,fields)
  if pending then return false end
  local protocol=g_game.getProtocolGame()
  if not protocol then return false end
  requestId=requestId%2147483647+1
  local message={action=action,requestId=requestId}
  for key,value in pairs(fields or {})do message[key]=value end
  pending={id=requestId,action=action}
  if Cyclopedia.setHouseBusy then Cyclopedia.setHouseBusy(true) end
  status('Loading...')
  protocol:sendExtendedOpcode(OPCODE,json.encode(message))
  local expected=requestId
  timeout=scheduleEvent(function()
    timeout=nil
    if not pending or pending.id~=expected then return end
    clearPending();data=nil
    if Cyclopedia.clearHouseActions then Cyclopedia.clearHouseActions()end
    status('No reply. Refresh the house before retrying a transaction.',true)
  end,10000)
  return true
end
function H.attach(widget)
  clearPending();root=widget;data=nil;selected=nil
end
function H.detach(widget)
  if root~=widget then return end
  root=nil;data=nil;selected=nil;clearPending()
end
function H.getData()return data end
function H.isBusy()return pending~=nil end
function H.getFilters()return filters end
function H.isEnabled()return enabled end
function H.list(changes)
  if not root or pending then return false end
  for key,value in pairs(changes or {})do filters[key]=value end
  data=nil;selected=nil
  return send('list',filters)
end
function H.select(id)
  if not root or pending then return false end
  selected=id;data=nil
  return send('detail',{houseId=id})
end
function H.refresh()
  if not root or pending then return false end
  if selected and Cyclopedia.isHouseFormOpen and Cyclopedia.isHouseFormOpen() then
    return send('detail',{houseId=selected})
  end
  return H.list()
end
function H.action(action,fields,quote)
  if not root or pending or not data then return false end
  quote=quote or {houseId=data.id,revision=data.revision}
  if quote.houseId~=data.id then status('The selected house changed. Reopen its action form.',true);return false end
  local values={houseId=quote.houseId,revision=quote.revision}
  for key,value in pairs(fields or {})do values[key]=value end
  return send(action,values)
end
function H.show()
  if enabled and g_game.isOnline()then modules.game_cyclopedia.show('houses')end
end
function H.hide()
  if controllerCyclopedia.ui then controllerCyclopedia.ui:hide()end
end
local function onOpcode(protocol,opcode,buffer)
  if type(buffer)~='string' or #buffer>32768 then return end
  local ok,message=pcall(json.decode,buffer)
  if not ok or type(message)~='table' or not pending or message.requestId~=pending.id or type(message.success)~='boolean' then return end
  local action=pending.action;clearPending()
  if message.type=='capabilities' then
    enabled=message.enabled==true;Cyclopedia.setHouseMarketCapability(enabled);return
  end
  if not root then return end
  if message.type=='list' and type(message.data)=='table' then
    filters.page=message.data.page
    Cyclopedia.applyNativeHouseList(message.data)
  elseif message.type=='detail' and type(message.data)=='table' then
    data=message.data;selected=data.id
    Cyclopedia.applyNativeHouseDetail(data,action~='detail')
  end
  status(message.message or '',not message.success)
  if not message.success and Cyclopedia.showHouseError then Cyclopedia.showHouseError(message.message)end
end
local function onStart()
  clearPending();enabled=false;send('capabilities')
end
local function onEnd()
  clearPending();enabled=false;data=nil;selected=nil;root=nil
  filters={page=1,townId=0,filter='all',status=0,sort='name',search=''}
  if Cyclopedia.closeHouseDialogs then Cyclopedia.closeHouseDialogs()end
  Cyclopedia.setHouseMarketCapability(false)
end
function H.init()
  ProtocolGame.registerExtendedOpcode(OPCODE,onOpcode)
  connect(g_game,{onGameStart=onStart,onGameEnd=onEnd})
  if g_game.isOnline()then onStart()end
end
function H.terminate()
  onEnd();disconnect(g_game,{onGameStart=onStart,onGameEnd=onEnd})
  ProtocolGame.unregisterExtendedOpcode(OPCODE)
end
