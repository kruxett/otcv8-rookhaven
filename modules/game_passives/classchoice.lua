-- Server-owned Nameless interaction. Preview never changes class or player outfit.
ClassChoice = {}
local sender, featureEnabled, window, confirmation, expiryEvent, pendingEvent
local cards, retired, retiredOrder = {}, {}, {}
local order = {'reaver','blademaster','earthshaker','marksman','arcanist','lifekeeper'}
local known = {}; for _, id in ipairs(order) do known[id] = true end
local state = {classes={}, pending=false, selectedId=nil, revision=0, stage='closed'}
local function enabled()
  return featureEnabled and featureEnabled() and g_resources.getLayout() == 'retro' and g_game.isOnline()
end
local function integer(value, maximum)
  return type(value)=='number' and value>=0 and value<=maximum and value==math.floor(value)
end
local function text(value, maximum, empty)
  return type(value)=='string' and (empty or #value>0) and #value<=maximum and
    not value:find('[%z\1-\8\11\12\14-\31]')
end
local function clearEvent(event) if event then removeEvent(event) end end
local function retire(offer)
  if not offer or retired[offer] then return end
  retired[offer]=true;retiredOrder[#retiredOrder+1]=offer
  -- Keep tokens until logout: a delayed packet must never reopen a cancelled offer.
end
local function status(message, error)
  state.status=message
  if window then
    local label=window:getChildById('footer'):getChildById('status')
    label:setText(message);label:setColor(error and '#dca065' or '#c7c1b2')
  end
  if confirmation then
    local label=confirmation:getChildById('status')
    label:setText(message);label:setColor(error and '#dca065' or '#c7c1b2')
  end
end
local function active()
  return enabled() and state.offer and not retired[state.offer] and
    state.expiresAt and g_clock.millis()<state.expiresAt
end
local function send(action, values)
  if not active() or not sender then return false end
  local payload={v=1,action=action,offer=state.offer}
  for key,value in pairs(values or {})do payload[key]=value end
  local ok,result=pcall(sender,payload)
  return ok and result~=false
end
local function updateButtons()
  if window then
    local selected=state.classes[state.selectedId]
    window:getChildById('footer'):getChildById('chooseButton'):setEnabled(
      active() and not state.pending and not state.timedOut and not confirmation and selected and selected.allowed or false)
    window:getChildById('footer'):getChildById('cancelButton'):setEnabled(not state.pendingReset)
    for id,card in pairs(cards)do
      card:setChecked(id==state.selectedId)
      local info=state.classes[id]
      card:getChildById('availability'):setText(info.allowed and(id==state.selectedId and 'Selected' or 'Available')or info.reason)
      card:setEnabled(state.classes[id].allowed and not state.pending and not confirmation and not state.timedOut)
    end
  end
  if confirmation then
    confirmation:getChildById('confirmButton'):setEnabled(active() and not state.pending and not state.timedOut)
    confirmation:getChildById('backButton'):setEnabled(not state.pending)
    confirmation:getChildById('backButton'):setText(state.timedOut and 'Close' or 'Go back')
    if state.timedOut then
      state.confirmFocus='back';confirmation:getChildById('backButton'):focus()
    end
  end
end
local function clearPending()
  clearEvent(pendingEvent);pendingEvent=nil;state.pending=false
end
local function closeConfirmation()
  if confirmation then confirmation:ungrabKeyboard();confirmation:destroy();confirmation=nil end
  state.confirmFocus=nil
  if window then window:grabKeyboard();window:focus()end
end
local function destroy()
  closeConfirmation()
  if window then window:ungrabKeyboard();window:destroy();window=nil end
  clearEvent(expiryEvent);expiryEvent=nil;clearPending();cards={}
end
local function close(reason)
  local offer=state.offer
  destroy();retire(offer)
  state={classes={},pending=false,selectedId=nil,revision=0,stage='closed',closedReason=reason}
end
local function pending(action)
  clearPending();state.pending=action;state.stage='waiting_'..action;updateButtons()
  status('Waiting for The Nameless...')
  pendingEvent=scheduleEvent(function()
    pendingEvent=nil;state.pending=false;state.timedOut=true;state.stage='timeout'
    status('No response. Close this window and speak to The Nameless again.',true)
    updateButtons()
  end,8000)
end
function ClassChoice.cancel()
  if state.pendingReset then return false end
  if state.offer then send('class_choice_cancel')end
  close('cancelled')
end
function ClassChoice.back()
  if not confirmation or state.pending then return false end
  if state.timedOut then ClassChoice.cancel();return true end
  local revision=state.revision
  if not send('class_choice_back',{revision=revision})then
    status('Could not reach The Nameless. Try again or close this window.',true);return false
  end
  closeConfirmation();pending('back');return true
end
function ClassChoice.confirm()
  if not confirmation or state.pending or state.timedOut or not active()then return false end
  if not send('class_choice_confirm',{revision=state.revision})then
    status('Could not reach The Nameless. Try again or close this window.',true);return false
  end
  pending('confirm');return true
end
function ClassChoice.choose()
  local selected=state.classes[state.selectedId]
  if not selected or not selected.allowed or state.pending or confirmation or state.timedOut then return false end
  if not send('class_choice_select',{classId=state.selectedId})then
    status('Could not reach The Nameless. Try again or close this window.',true);return false
  end
  pending('select');return true
end
function ClassChoice.selectLocal(id)
  local selected=state.classes[id]
  if not window or not selected or not selected.allowed or state.pending or confirmation or state.timedOut then return false end
  state.selectedId=id
  local detail=window:getChildById('details')
  detail:getChildById('title'):setText(selected.name..' - '..selected.weapon)
  local description=selected.description
  if #state.consequences>0 then description=description..'\n\n'..state.consequences end
  detail:getChildById('descriptionScroll'):getChildById('description'):setText(description)
  detail:getChildById('detailBar'):setValue(0)
  updateButtons();return true
end
local function moveSelection(delta)
  local current=0
  for index,id in ipairs(order)do if id==state.selectedId then current=index end end
  for attempt=1,6 do
    local index=((current+(attempt==1 and delta or (delta<0 and -1 or 1))-1)%6)+1
    current=index
    if state.classes[order[index]] and state.classes[order[index]].allowed then
      return ClassChoice.selectLocal(order[index])
    end
  end
end
local function keyboard(_,key,modifiers)
  if key==KeyEscape then ClassChoice.cancel();return true end
  if state.pending or confirmation then return true end
  if key==KeyTab then moveSelection(modifiers==KeyboardShiftModifier and -1 or 1)
  elseif key==KeyLeft then moveSelection(-1)
  elseif key==KeyRight then moveSelection(1)
  elseif key==KeyUp then moveSelection(-3)
  elseif key==KeyDown then moveSelection(3)
  elseif key==KeyEnter or key==KeySpace then ClassChoice.choose()end
  return true
end
local function confirmationKeyboard(_,key)
  if key==KeyEscape then ClassChoice.back();return true end
  if state.pending then return true end
  if key==KeyTab or key==KeyLeft or key==KeyRight then
    state.confirmFocus=state.confirmFocus=='confirm'and'back'or'confirm'
    confirmation:getChildById(state.confirmFocus=='confirm'and'confirmButton'or'backButton'):focus()
  elseif key==KeyEnter or key==KeySpace then
    if state.confirmFocus=='confirm'then ClassChoice.confirm()else ClassChoice.back()end
  end
  return true
end
local function portrait(widget,outfit)
  -- Invalid data IDs render a verified default rather than dereference bad data.
  local ok,thing=pcall(function()return g_things.getThingType(outfit.type,ThingCategoryCreature)end)
  if not ok or not thing or thing:getId()~=outfit.type then
    ok,thing=pcall(function()return g_things.getThingType(128,ThingCategoryCreature)end)
    if not ok or not thing or thing:getId()~=128 then widget:hide();return end
    outfit={type=128,head=0,body=0,legs=0,feet=0,addons=0}
  end
  widget:setOutfit(outfit);widget:setCenter(true);widget:setOldScaling(false)
  widget:setDirection(South);widget:setAnimate(false);widget:setFixedCreatureSize(true)
end
function ClassChoice.clamp()
  local root=g_ui.getRootWidget():getRect()
  if window then
    window:setSize({width=math.min(736,root.width-16),height=math.min(576,root.height-16)})
    window:setPosition({x=root.x+math.floor((root.width-window:getWidth())/2),y=root.y+math.floor((root.height-window:getHeight())/2)})
    local holder=window:getChildById('cards')
    local width=math.floor((holder:getWidth()-16)/3)
    for index,id in ipairs(order)do
      local card=cards[id]
      if card then
        card:setSize({width=width,height=146})
        card:setPosition({x=holder:getX()+((index-1)%3)*(width+8),y=holder:getY()+math.floor((index-1)/3)*154})
      end
    end
  end
  if confirmation then
    confirmation:setSize({width=math.min(464,root.width-24),height=math.min(296,root.height-24)})
    confirmation:setPosition({x=root.x+math.floor((root.width-confirmation:getWidth())/2),y=root.y+math.floor((root.height-confirmation:getHeight())/2)})
  end
end
local function showOffer()
  if not window then
    window=g_ui.displayUI('classchoice',g_ui.getRootWidget())
    window.onKeyDown=keyboard;window.onEscape=ClassChoice.cancel
    window:getChildById('footer'):getChildById('chooseButton').onClick=ClassChoice.choose
    window:getChildById('footer'):getChildById('cancelButton').onClick=ClassChoice.cancel
  end
  local holder=window:getChildById('cards')
  for _,id in ipairs(order)do
    local classId=id
    local info=state.classes[id]
    local card=cards[id]or g_ui.createWidget('ClassChoiceCard',holder);cards[id]=card
    card:setId('class_'..id);card:getChildById('name'):setText(info.name)
    card:getChildById('weapon'):setText(info.weapon)
    card:getChildById('tagline'):setText(info.tagline)
    card:getChildById('availability'):setText(info.allowed and'Available'or info.reason)
    card:setTooltip(info.allowed and info.description or info.reason)
    portrait(card:getChildById('portrait'),info.outfit)
    card.onClick=function()ClassChoice.selectLocal(classId)end
  end
  window:show();window:raise();window:focus();window:grabKeyboard();ClassChoice.clamp()
  local selected=state.selectedId
  if selected then ClassChoice.selectLocal(selected)else
    window:getChildById('details'):getChildById('title'):setText('Your permanent path')
    window:getChildById('details'):getChildById('descriptionScroll'):getChildById('description'):setText(
      'Select an available class to read about its playstyle.\n\n'..state.consequences)
  end
  status('Class choice is permanent. Talent points can still be reset.');updateButtons()
end
local function validateOffer(data)
  if not text(data.offer,128)or retired[data.offer]or not integer(data.ttlMs,120000)or data.ttlMs<1 or
    not text(data.consequences,1200,true)or type(data.classes)~='table'or #data.classes~=6 then return end
  local classes={}
  for _,info in ipairs(data.classes)do
    if type(info)~='table'or not known[info.id]or classes[info.id]or
      not text(info.name,40)or not text(info.weapon,40)or not text(info.tagline,110)or
      not text(info.description,1600)or type(info.allowed)~='boolean'or
      not text(info.reason,180,true)or(not info.allowed and #info.reason==0)or type(info.outfit)~='table'then return end
    local outfit={}
    for _,key in ipairs({'type','head','body','legs','feet','addons'})do
      local value=info.outfit[key]
      if not integer(value,key=='type'and 65535 or key=='addons'and 0 or 132)or(key=='type'and value==0)then return end
      outfit[key]=value
    end
    classes[info.id]={id=info.id,name=info.name,weapon=info.weapon,tagline=info.tagline,
      description=info.description,allowed=info.allowed,reason=info.reason,outfit=outfit}
  end
  return classes
end
function ClassChoice.receive(data)
  if not enabled()or not sender or type(data)~='table'or data.v~=1 then return false end
  if data.action=='class_choice_offer'then
    local classes=validateOffer(data);if not classes then return false end
    local same=data.offer==state.offer
    if same and confirmation and state.pending~='back'then return false end
    if not same then close('replaced');state.offer=data.offer;state.revision=0 end
    closeConfirmation();clearPending();state.timedOut=false;state.stage='offer'
    state.classes=classes;state.consequences=data.consequences
    state.expiresAt=same and math.min(state.expiresAt,g_clock.millis()+data.ttlMs)or(g_clock.millis()+data.ttlMs)
    if state.selectedId and not classes[state.selectedId].allowed then state.selectedId=nil end
    clearEvent(expiryEvent)
    expiryEvent=scheduleEvent(function()expiryEvent=nil;ClassChoice.cancel()end,math.max(1,state.expiresAt-g_clock.millis()))
    showOffer();return true
  end
  if not text(data.offer,128)or data.offer~=state.offer or retired[data.offer]then return false end
  if data.action=='class_choice_close'then
    if data.reason~=nil and not text(data.reason,240,true)then return false end
    close(data.reason or'closed');return true
  end
  if data.action=='class_choice_result'then
    if type(data.ok)~='boolean'or(data.completed~=nil and type(data.completed)~='boolean')or
      (data.pendingReset~=nil and type(data.pendingReset)~='boolean')or
      (data.error~=nil and not text(data.error,320,true))then return false end
    clearPending()
    if data.ok and data.pendingReset then
      state.pendingReset=true;state.pending='reconnect';state.stage='reconnecting'
      status('Reconnecting after Ascension...')
      updateButtons()
    elseif data.ok and data.completed then close('completed')else
      state.stage=confirmation and 'confirmation' or 'offer'
      status(data.ok and'Choose your path.'or(data.error or'The Nameless could not accept this choice.'),not data.ok)
      updateButtons()
    end
    return true
  end
  if data.action=='class_choice_confirm'then
    local selected=state.classes[data.selectedId]
    if not active()or state.timedOut or state.pending~='select' or data.selectedId~=state.selectedId or not selected or not selected.allowed or
      not integer(data.revision,1000000)or data.revision<=state.revision or
      not text(data.name,40)or data.name~=selected.name or not text(data.consequences,1200,true)then return false end
    clearPending();closeConfirmation();state.revision=data.revision;state.selectedId=data.selectedId;state.stage='confirmation'
    status('Review your choice before confirming.')
    confirmation=g_ui.createWidget('ClassChoiceConfirm',g_ui.getRootWidget())
    confirmation:getChildById('className'):setText('Become '..data.name)
    confirmation:getChildById('consequenceScroll'):getChildById('consequences'):setText(data.consequences)
    status('Review your choice before confirming.')
    confirmation:getChildById('confirmButton').onClick=ClassChoice.confirm
    confirmation:getChildById('backButton').onClick=ClassChoice.back
    confirmation.onKeyDown=confirmationKeyboard;confirmation.onEscape=ClassChoice.back
    state.confirmFocus='back';confirmation:show();confirmation:raise();confirmation:focus()
    confirmation:getChildById('backButton'):focus();confirmation:grabKeyboard()
    ClassChoice.clamp();updateButtons();return true
  end
  return false
end
function ClassChoice.init(sendCallback, capabilityCallback)
  sender=sendCallback;featureEnabled=capabilityCallback
end
function ClassChoice.reset()
  destroy();retired={};retiredOrder={};state={classes={},pending=false,selectedId=nil,revision=0,stage='closed'}
end
function ClassChoice.getWindow()return window end
function ClassChoice.getConfirmation()return confirmation end
function ClassChoice.getCard(id)return cards[id]end
function ClassChoice.getDebugState()return state end
