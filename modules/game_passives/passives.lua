-- Retro DEV/local clients negotiate support; the server owns class and effects.
local OPCODE = 103
local VERSION = 1
local MAX_PACKET = 7900
local MAX_CATALOG = 100 * 1024
local MAX_PARTS = 32
local window, statusWindow, confirmation, reopenButton
local ui, nodeWidgets, edgeWidgets, branchWidgets, edgeGroups = {}, {}, {}, {}, {}
local helloEvent, runtimeEvent, pendingEvent, transferEvent, scrollEvent
local requestCounter = 0
local transfer
local state = {}
local registered = false
local offline
local settingUpStatus = false
local retiredSessions, retiredSessionOrder = {}, {}
local treeCaps = {
  reaver = {'cap_berserker','cap_bloodletting','cap_bloodguard'},
  blademaster = {'cap_duelist','cap_riposte','cap_bladestorm'},
  earthshaker = {'cap_aftershock','cap_stoneguard','cap_stonebond'},
  marksman = {'cap_deadeye','cap_skirmisher','cap_quarry'},
  arcanist = {'cap_conduit','cap_resonance','cap_spellweaver'},
  lifekeeper = {'cap_renewal','cap_aegis','cap_concord'}
}

local function profileEnabled()
  return (LOCAL_PASSIVES_TEST == true or UPDATER_CHANNEL == 'dev') and g_resources.getLayout() == 'retro'
end

local function featureEnabled()
  return registered and profileEnabled() and state.ready == true
end

-- Presentation only: the catalog and the server still own prerequisites.
local branches = {
  { name = 'Precision', minors = { 'minor_precision', 'minor_critical' }, major = 'major_precision' },
  { name = 'Pressure', minors = { 'minor_power', 'minor_efficiency' }, major = 'major_pressure' },
  { name = 'Sustain', minors = { 'minor_recovery', 'minor_focus' }, major = 'major_recovery' },
  { name = 'Guard', minors = { 'minor_vitality', 'minor_resilience' }, major = 'major_guard' }
}
local renderTree
local treeLayout = {}
for index, branch in ipairs(branches) do
  local offset = (index - 1) * 120
  treeLayout[branch.minors[1]] = { x = offset + 8, y = 360, width = 44, height = 44 }
  treeLayout[branch.minors[2]] = { x = offset + 68, y = 360, width = 44, height = 44 }
  treeLayout[branch.major] = { x = offset + 8, y = 244, width = 104, height = 52 }
end
treeLayout.major_tactical = { x = 68, y = 142, width = 104, height = 52 }
treeLayout.major_steady = { x = 308, y = 142, width = 104, height = 52 }
for index, id in ipairs({ 'cap_berserker', 'cap_bloodletting', 'cap_bloodguard' }) do
  treeLayout[id] = { x = 48 + (index - 1) * 160, y = 30, width = 64, height = 64 }
end
local function capstoneIds()
  return state.tree and state.tree.topology and state.tree.topology.capstoneOrder or treeCaps[state.tree and state.tree.id or 'reaver'] or treeCaps.reaver
end

local function routeDestination(id)
  for index, reaverId in ipairs(treeCaps.reaver) do
    if id == reaverId then return capstoneIds()[index] end
  end
  return id
end

local function clearEvent(event)
  if event then removeEvent(event) end
end

local function copyRanks(ranks)
  local copy = {}
  for id, rank in pairs(ranks or {}) do copy[id] = rank end
  return copy
end

local function resetState()
  state = { tree = nil, nodes = {}, ranks = {}, draft = {}, revision = 0,
    points = 0, active = false, ready = false, session = nil, selected = nil,
    pending = nil, pendingRequest = nil, openRequested = false, runtime = {}, mode = 'test',
    initialTreeScroll = true,
    respecCost = nil, respecCount = 0, classLocked = false, classId = nil,
    classCatalog = {}, classHint = 'Visit The Nameless to choose your class.' }
  retiredSessions, retiredSessionOrder = {}, {}
end

local function isPermanent() return state.mode == 'permanent' end

local function retireSession(session)
  if not session or retiredSessions[session] then return end
  retiredSessions[session] = true
  retiredSessionOrder[#retiredSessionOrder + 1] = session
  if #retiredSessionOrder > 32 then
    retiredSessions[table.remove(retiredSessionOrder, 1)] = nil
  end
end

local function setStatus(text, errorState)
  if ui.statusLabel then
    ui.statusLabel:setText(text or '')
    ui.statusLabel:setColor(errorState and '#e08b75' or '#c7c1b2')
  end
end

local function send(payload)
  if not registered or not profileEnabled() or (payload.action ~= 'hello' and not state.ready) then return false end
  local protocol = g_game.getProtocolGame()
  if not protocol or not g_game.isOnline() then return false end
  payload.v = VERSION
  if payload.action ~= 'hello' and not payload.action:find('^class_choice_') then
    payload.session = state.session
    payload.revision = state.revision
  end
  local ok, encoded = pcall(json.encode, payload)
  if not ok or #encoded > MAX_PACKET then return false end
  protocol:sendExtendedOpcode(OPCODE, encoded)
  return true
end

local function spent(ranks)
  local total = 0
  for _, rank in pairs(ranks or {}) do total = total + rank end
  return total
end

local function removeReopenButton()
  if not reopenButton then return end
  reopenButton:destroy(); reopenButton = nil
  if modules.game_buttons and modules.game_buttons.updateOrder then modules.game_buttons.updateOrder() end
end

local function updateReopenButton()
  local available = state.ready and state.active and isPermanent() and state.tree ~= nil
  if not available then
    removeReopenButton()
    return
  end
  if not reopenButton and modules.client_topmenu then
    reopenButton = modules.client_topmenu.addRightGameToggleButton('passivesButton',
      'Passive talents', '/images/topbuttons/skills', function()
        if window and window:isVisible() then hide() else send({action = 'open'}) end
      end, false, 7)
  end
  if reopenButton then
    reopenButton:setOn(window ~= nil and window:isVisible())
    reopenButton:setTooltip((state.tree.name or 'Class') .. ' - passive talents')
  end
end

local function nameFor(id)
  return state.nodes[id] and state.nodes[id].name or tostring(id)
end

local function groupMet(group, ranks)
  local all = group.all or {}
  for _, requirement in ipairs(all) do
    if (ranks[requirement.id] or 0) < (requirement.rank or 1) then return false end
  end
  return true
end

local function requirementsMet(node, ranks)
  local requires = node.requires or {}
  if spent(ranks) - (ranks[node.id] or 0) < (requires.spent or 0) then return false end
  if requires.all and not groupMet({ all = requires.all }, ranks) then return false end
  if requires.any and #requires.any > 0 then
    for _, group in ipairs(requires.any) do
      if groupMet(group, ranks) then return true end
    end
    return false
  end
  return true
end

local function validationError(ranks)
  local capstones = 0
  if spent(ranks) > state.points then return isPermanent() and 'Not enough passive points.' or 'Not enough test points.' end
  if isPermanent() then
    for id, saved in pairs(state.ranks) do
      if (ranks[id] or 0) < saved then return 'Saved ranks require a respec. Only undo new draft ranks.' end
    end
  end
  for id, rank in pairs(ranks) do
    local node = state.nodes[id]
    if not node or type(rank) ~= 'number' or rank < 0 or rank > node.maxRank or rank ~= math.floor(rank) then
      return 'Invalid rank in the draft.'
    end
    if rank > 0 then
      if not requirementsMet(node, ranks) then return nameFor(id) .. ': prerequisites are not met.' end
      if node.type == 'capstone' then capstones = capstones + 1 end
    end
  end
  if capstones > 1 then return 'Choose only one capstone. Remove the other from your draft first.' end
end

local function draftChanged()
  for id in pairs(state.nodes) do
    if (state.ranks[id] or 0) ~= (state.draft[id] or 0) then return true end
  end
  return false
end

local function capstoneSources(node)
  local sources = {}
  if node and node.type == 'capstone' then
    for _, group in ipairs((node.requires or {}).any or {}) do
      for _, requirement in ipairs(group.all or {}) do sources[requirement.id] = true end
    end
  end
  return sources
end

local function routeTaken(from, node, ranks)
  if not requirementsMet(node,ranks)then return false end
  local requires=node.requires or {}
  for _,r in ipairs(requires.all or {})do
    if r.id==from and(ranks[from]or 0)>=(r.rank or 1)then return true end
  end
  for _,group in ipairs(requires.any or {})do
    if groupMet(group,ranks)then
      for _,r in ipairs(group.all or {})do
        if r.id==from and(ranks[from]or 0)>=(r.rank or 1)then return true end
      end
    end
  end
  return false
end

local function groupSignature(all)
  local ranks, parts = {}, {}
  for _, requirement in ipairs(all or {}) do
    ranks[requirement.id] = math.max(ranks[requirement.id] or 0, requirement.rank or 1)
  end
  for id, rank in pairs(ranks) do if rank > 0 then parts[#parts + 1] = id .. ':' .. rank end end
  table.sort(parts); return table.concat(parts, ',')
end

-- A compact summary is accepted only when its expanded AND/OR rules match
-- the authoritative prerequisites. Missing metadata uses the literal server
-- rules; present but contradictory metadata is rejected by acceptCatalog.
local function summaryConditions(node, catalogNodes)
  if not node then return nil end
  local nodeMap=catalogNodes or state.nodes
  local summary = node.requirementSummary
  if type(summary) ~= 'table' or type(summary.conditions) ~= 'table' or #summary.conditions > 8 then return nil end
  local expanded, spentRequired, spentSeen = {{all={}}}, 0, false
  for _, condition in ipairs(summary.conditions) do
    if type(condition) ~= 'table' or type(condition.label) ~= 'string' or #condition.label > 96 or
      type(condition.required) ~= 'number' or condition.required < 0 or condition.required > 1000 or
      condition.required ~= math.floor(condition.required) then return nil end
    if condition.kind == 'spent' then
      if spentSeen then return nil end
      spentSeen=true
      spentRequired = condition.required
    elseif condition.kind == 'sum' or condition.kind == 'any_rank' then
      if type(condition.ids) ~= 'table' or #condition.ids < 1 or #condition.ids > 6 then return nil end
      local seen = {}
      for _, id in ipairs(condition.ids) do
        if not nodeMap[id] or seen[id] then return nil end
        seen[id] = true
      end
      if condition.kind == 'sum' and condition.required > 10 then return nil end
      if condition.kind == 'any_rank' and (condition.required > #condition.ids or
        type(condition.rank) ~= 'number' or condition.rank < 1 or condition.rank > 5 or condition.rank ~= math.floor(condition.rank)) then return nil end
      local alternatives, path = {}, {}
      local function enumerate(index, remaining)
        if #alternatives > 128 then return end
        if index > #condition.ids then
          if remaining == 0 then
            local all = {}; for _, requirement in ipairs(path) do all[#all+1] = requirement end
            alternatives[#alternatives+1] = {all=all}
          end
          return
        end
        local id = condition.ids[index]
        local maximum = condition.kind == 'sum' and math.min(nodeMap[id].maxRank, remaining) or math.min(1, remaining)
        if condition.kind == 'any_rank' and condition.rank > nodeMap[id].maxRank then return end
        for amount = 0, maximum do
          if amount > 0 then path[#path+1] = {id=id,rank=condition.kind=='sum' and amount or condition.rank} end
          enumerate(index+1, remaining-amount)
          if amount > 0 then path[#path] = nil end
        end
      end
      enumerate(1, condition.required)
      if #alternatives == 0 or #alternatives > 128 or #expanded * #alternatives > 128 then return nil end
      local product = {}
      for _, existing in ipairs(expanded) do for _, alternative in ipairs(alternatives) do
        local all = {}; for _, r in ipairs(existing.all) do all[#all+1]=r end
        for _, r in ipairs(alternative.all) do all[#all+1]=r end
        product[#product+1]={all=all}
      end end
      expanded = product
    else return nil end
  end
  local requires, actual, expected = node.requires or {}, {}, {}
  if spentRequired ~= (requires.spent or 0) then return nil end
  local alternatives = requires.any and #requires.any>0 and requires.any or {{all={}}}
  for _, group in ipairs(alternatives) do
    local all = {}; for _, r in ipairs(requires.all or {}) do all[#all+1]=r end
    for _, r in ipairs(group.all or {}) do all[#all+1]=r end
    actual[groupSignature(all)] = true
  end
  for _, group in ipairs(expanded) do expected[groupSignature(group.all)] = true end
  for key in pairs(actual) do if not expected[key] then return nil end end
  for key in pairs(expected) do if not actual[key] then return nil end end
  return summary.conditions
end

local function branchInfo(index)
  local branch = branches[index]
  local ids = {'precision','pressure','sustain','guard'}
  if state.tree and state.tree.schemaVersion==2 then
    local id=state.tree.topology.branchOrder[index];local group
    for _,entry in ipairs(state.tree.branchGroups)do if entry.id==id then group=entry end end
    local threshold=0;for _,condition in ipairs(summaryConditions(state.nodes[group.majorId])or{})do if condition.kind=='sum'then threshold=condition.required end end
    return{id=id,label=group.label,threshold=threshold,minors=group.minorIds,major=group.majorId}
  end
  local label = state.tree and state.tree.branches and state.tree.branches[index] or branch.name
  if index == 1 and state.tree and state.tree.id == 'lifekeeper' then label = 'Healing' end
  local threshold
  for _, condition in ipairs(summaryConditions(state.nodes[branch.major]) or {}) do
    if condition.kind == 'sum' and #condition.ids == 2 and
      ((condition.ids[1]==branch.minors[1] and condition.ids[2]==branch.minors[2]) or
       (condition.ids[2]==branch.minors[1] and condition.ids[1]==branch.minors[2])) then threshold=condition.required end
  end
  if not threshold then
    local groups = (state.nodes[branch.major].requires or {}).any or {}
    local first = groups[1] and groups[1].all or {}
    threshold = 0; for _, requirement in ipairs(first) do threshold=threshold+(requirement.rank or 1) end
  end
  local metadata = state.tree and state.tree.branchGroups and state.tree.branchGroups[index]
  if type(metadata)=='table' and metadata.id==ids[index] and metadata.majorId==branch.major and
    type(metadata.label)=='string' and #metadata.label<=24 then label=metadata.label end
  return {id=ids[index],label=label,threshold=threshold,minors=branch.minors,major=branch.major}
end

local function branchText(node)
  local labels = {}
  local membership = {}
  for index, branch in ipairs(branches) do
    membership[branch.major] = index
    for _, id in ipairs(branch.minors) do membership[id] = index end
  end
  local indices = {}
  if membership[node.id] then indices[membership[node.id]]=true
  elseif node.id=='major_tactical' then indices[1]=true;indices[2]=true
  elseif node.id=='major_steady' then indices[3]=true;indices[4]=true
  elseif node.type=='capstone' then
    for id in pairs(capstoneSources(node)) do
      if membership[id] then indices[membership[id]]=true
      elseif id=='major_tactical' then indices[1]=true;indices[2]=true
      elseif id=='major_steady' then indices[3]=true;indices[4]=true end
    end
  end
  for index=1,4 do if indices[index] then labels[#labels+1]=branchInfo(index).label end end
  return table.concat(labels, ' / ')
end

local function requirementText(node)
  local lines = {}
  local requires = node.requires or {}
  if requires.spent then lines[#lines + 1] = 'Spend ' .. requires.spent .. ' points before this node; major ranks count.' end
  for _, branch in ipairs(branches) do
    if node.id == branch.major and requires.any then
      local total, simple = nil, true
      for _, group in ipairs(requires.any) do
        local sum = 0
        for _, requirement in ipairs(group.all or {}) do
          if requirement.id ~= branch.minors[1] and requirement.id ~= branch.minors[2] then simple = false end
          sum = sum + (requirement.rank or 1)
        end
        if total and total ~= sum then simple = false end
        total = sum
      end
      if simple and total then
        return 'Spend ' .. total .. ' ranks across ' .. nameFor(branch.minors[1]) .. ' and ' .. nameFor(branch.minors[2]) .. ' combined.'
      end
    end
  end
  if node.id == 'major_tactical' or node.id == 'major_steady' then
    local first = node.id == 'major_tactical' and branches[1] or branches[3]
    local second = node.id == 'major_tactical' and branches[2] or branches[4]
    return 'At least 2 combined ranks in each pair:\n- ' .. nameFor(first.minors[1]) .. ' + ' .. nameFor(first.minors[2]) ..
      '\n- ' .. nameFor(second.minors[1]) .. ' + ' .. nameFor(second.minors[2]) ..
      '\nAnd either ' .. nameFor(first.major) .. ' or ' .. nameFor(second.major) .. ' at rank 1.'
  end
  if node.type == 'capstone' and requires.any and #requires.any == 3 then
    local sources, names, requiredRank = capstoneSources(node), {}, nil
    local pairsOnly = true
    for _, group in ipairs(requires.any) do
      if #(group.all or {}) ~= 2 then pairsOnly = false end
      for _, requirement in ipairs(group.all or {}) do
        if requiredRank and requiredRank ~= (requirement.rank or 1) then pairsOnly = false end
        requiredRank = requirement.rank or 1
      end
    end
    for _, candidate in ipairs(state.tree.nodes) do
      if sources[candidate.id] then names[#names + 1] = candidate.name end
    end
    if pairsOnly and #names == 3 then
      if requires.all and #requires.all>0 then
        for _,requirement in ipairs(requires.all)do
          lines[#lines+1]=nameFor(requirement.id)..' at rank '..tostring(requirement.rank or 1)..' is required.'
        end
      end
      lines[#lines + 1] = 'Any TWO of these majors at rank ' .. requiredRank .. ':'
      for _, name in ipairs(names) do lines[#lines + 1] = '- ' .. name end
      lines[#lines + 1] = 'Choose only ONE capstone.'
      return table.concat(lines, '\n')
    end
  end
  local function formatGroup(group)
    local parts = {}
    for _, requirement in ipairs(group.all or {}) do
      parts[#parts + 1] = nameFor(requirement.id) .. ' ' .. tostring(requirement.rank or 1)
    end
    return table.concat(parts, ' + ')
  end
  if requires.all then lines[#lines + 1] = formatGroup({ all = requires.all }) end
  if requires.any and #requires.any > 0 then
    lines[#lines + 1] = 'Any one of these routes:'
    for _, group in ipairs(requires.any) do lines[#lines + 1] = '- ' .. formatGroup(group) end
  end
  if #lines == 0 then return 'No prerequisite.' end
  return table.concat(lines, '\n')
end

local function rankError(node, delta)
  if not state.active then return isPermanent() and 'The passive tree is inactive.' or 'The test is inactive.' end
  if state.pending then return 'Updating talents.' end
  local rank = state.draft[node.id] or 0
  if delta > 0 and rank >= node.maxRank then return 'Maximum rank reached.' end
  if delta < 0 and rank == 0 then return 'No ranks to remove.' end
  if delta < 0 and isPermanent() and rank <= (state.ranks[node.id] or 0) then
    return 'Saved ranks require a respec. Only undo new draft ranks.'
  end
  local candidate = copyRanks(state.draft)
  candidate[node.id] = rank + delta
  local errorText = validationError(candidate)
  if errorText and delta < 0 then return 'Remove dependent talent ranks first.' end
  return errorText
end

-- Compact contextual requirements preserve the catalog's authoritative rules.
local function updateRequirements(node)
  local box=ui.nodeRequirements
  if not box then return end
  box:destroyChildren()
  local width=math.max(140,box:getWidth())
  local y=0
  local function label(parent,id,text,x,top,w,color,font)
    local item=g_ui.createWidget('PassiveRequirement',parent)
    item:setId(id);item:addAnchor(AnchorLeft,'parent',AnchorLeft);item:addAnchor(AnchorTop,'parent',AnchorTop)
    item:setMarginLeft(x);item:setMarginTop(top);item:setWidth(w)
    if font then item:setFont(font)end
    item:setText(text);item:setColor(color or '#c7c1b2')
    item:setHeight(math.max(font=='verdana-9px'and 12 or 14,item:getTextSize().height))
    return item
  end
  local groupCount=0
  local function group(title,subtitle)
    groupCount=groupCount+1
    local frame=g_ui.createWidget('FlatPanel',box)
    frame:setId('requirementGroup_'..groupCount)
    frame:addAnchor(AnchorLeft,'parent',AnchorLeft);frame:addAnchor(AnchorTop,'parent',AnchorTop)
    frame:setMarginLeft(0);frame:setMarginTop(y);frame:setWidth(width)
    frame:setBorderWidth(1);frame:setBorderColor('#655e51')
    local heading=label(frame,'groupHeading',title,8,7,width-16,'#e1d3a1')
    local rule=label(frame,'groupRule',subtitle,8,heading:getY()-frame:getY()+heading:getHeight()+3,width-16,'#c7c1b2')
    local cursor=7+heading:getHeight()+3+rule:getHeight()+8
    local api={}
    function api.row(id,current,required,allocation,neutral)
      local name=nameFor(id)
      local text=label(frame,'talent_'..id,name,allocation and 8 or 20,cursor,width-64,'#d0c9b6')
      local height=math.max(26,text:getHeight()+6)
      local marker=g_ui.createWidget('PassiveLegendFrame',frame)
      marker:addAnchor(AnchorLeft,'parent',AnchorLeft);marker:addAnchor(AnchorTop,'parent',AnchorTop)
      marker:setMarginLeft(8);marker:setMarginTop(cursor+7);marker:setSize({width=6,height=6})
      local met=current>=required
      marker:setBorderColor(met and '#a8b997'or neutral and'#817d72'or'#8e7e69')
      marker:setBackgroundColor(met and '#687954'or'#342f28');if allocation then marker:hide()end
      local badge=g_ui.createWidget('PassiveTalentName',frame)
      badge:setId('progress_'..id);badge:addAnchor(AnchorRight,'parent',AnchorRight);badge:addAnchor(AnchorTop,'parent',AnchorTop)
      badge:setMarginRight(7);badge:setMarginTop(cursor+2);badge:setSize({width=32,height=22});badge:setText(allocation and tostring(current)or current..'/'..required)
      badge:mergeStyle({['color']=(allocation or neutral)and '#d0c9b6'or met and '#c4d0b3'or'#d1b19a',['border-color']=(allocation or neutral)and '#655e51'or met and '#7d886a'or'#7c6852'});badge:setPhantom(true)
      local link=g_ui.createWidget('UIButton',frame)
      link:setId('inspect_'..id);link:addAnchor(AnchorLeft,'parent',AnchorLeft);link:addAnchor(AnchorTop,'parent',AnchorTop)
      link:setMarginLeft(5);link:setMarginTop(cursor-2);link:setSize({width=width-10,height=height});link:setFocusable(true)
      link:setTooltip('Inspect '..name..'. Click or press Enter.')
      link.onClick=function()selectNode(id)end
      link.onKeyPress=function(_,key,mods)return requirementKey(id,key,mods)end
      link.onHoverChange=function(_,hovered)link:setBackgroundColor(hovered and'#81766030'or'#00000000')end
      link.onFocusChange=function(_,focused)link:setBorderWidth(focused and 1 or 0);link:setBorderColor('#a8c4cc')end
      text:raise();marker:raise();badge:raise()
      frame:setTooltip('Requirements: '..subtitle)
      cursor=cursor+height+3
    end
    function api.orSeparator()
      local item=label(frame,'or_'..cursor,'OR',8,cursor,width-16,'#c7c1b2')
      item:setTextAlign(AlignCenter);cursor=cursor+item:getHeight()+4
    end
    function api.text(text,met)
      local item=label(frame,'note_'..cursor,text,8,cursor,width-16,met and '#bcc9ad'or'#d1b19a')
      cursor=cursor+item:getHeight()+6
    end
    function api.finish()
      frame:setHeight(cursor+5);y=y+frame:getHeight()+8
    end
    return api
  end
  if not node then box:setHeight(1);return end
  local conditions=(node.role~='routeMinor'and node.role~='advancedMajor')and summaryConditions(node)or nil
  if conditions then
    if #conditions==0 then local card=group('Requirements','Available from the start');card.text('No prerequisite.',true);card.finish()end
    for _,condition in ipairs(conditions)do
      if condition.kind=='sum' then
        local total=0;for _,id in ipairs(condition.ids)do total=total+(state.draft[id]or 0)end
        local card=group(condition.label:gsub(' minor points$',''),condition.required..' points across these talents')
        for _,id in ipairs(condition.ids)do card.row(id,state.draft[id]or 0,state.nodes[id].maxRank,true)end
        card.text('Combined: '..total..'/'..condition.required..' - any split counts.',total>=condition.required);card.finish()
      elseif condition.kind=='any_rank' then
        local count=0;for _,id in ipairs(condition.ids)do if(state.draft[id]or 0)>=condition.rank then count=count+1 end end
        local groupMet=count>=condition.required
        local card=group('Supporting talents',condition.required..' linked talent'..(condition.required>1 and 's'or'')..' at rank '..condition.rank..(groupMet and' - met'or''))
        for index,id in ipairs(condition.ids)do if index>1 and condition.required==1 then card.orSeparator()end;card.row(id,state.draft[id]or 0,condition.rank,false,groupMet and(state.draft[id]or 0)<condition.rank)end
        card.finish()
      elseif condition.kind=='spent' then
        local current=spent(state.draft)-(state.draft[node.id]or 0)
        local card=group('Investment','Points spent in other talents');card.text(current..'/'..condition.required..' points',current>=condition.required);card.finish()
      end
    end
  else
    local requires=node.requires or {}
    if requires.all and #requires.all>0 then
      local card=group(#requires.all>1 and'Required talents'or'Required talent',#requires.all>1 and'Both are required'or'Required to unlock this talent')
      for _,r in ipairs(requires.all)do card.row(r.id,state.draft[r.id]or 0,r.rank or 1)end
      card.finish()
    end
    if requires.any and #requires.any>0 then
      local groupMet=false
      for _,route in ipairs(requires.any)do local ready=true;for _,r in ipairs(route.all)do if(state.draft[r.id]or 0)<(r.rank or 1)then ready=false end end;if ready then groupMet=true end end
      local title=node.type=='capstone'and'Capstone route'or groupMet and'Supporting talent - met'or'Supporting talent'
      local card=group(title,#requires.any>1 and(node.type=='capstone'and'Either named talent is required'or'One required, plus Foundations')or'Required to unlock this path')
      for index,route in ipairs(requires.any)do
        if index>1 then card.orSeparator()end
        if #route.all>1 then card.text('All talents in this route:',true)end
        for _,r in ipairs(route.all)do card.row(r.id,state.draft[r.id]or 0,r.rank or 1,false,groupMet and(state.draft[r.id]or 0)<(r.rank or 1))end
      end
      card.finish()
    end
    if requires.spent then
      local current=spent(state.draft)-(state.draft[node.id]or 0)
      local card=group('Investment','Points spent in other talents');card.text(current..'/'..requires.spent..' points',current>=requires.spent);card.finish()
    end
  end
  if node.type=='capstone' then
    local selectedCap,appliedCap
    for id,r in pairs(state.draft)do if r>0 and state.nodes[id].type=='capstone'then selectedCap=id end end
    for id,r in pairs(state.ranks)do if r>0 and state.nodes[id].type=='capstone'then appliedCap=id end end
    local met=not selectedCap or selectedCap==node.id
    local card=group('Capstone choice','Choose one capstone')
    card.text(appliedCap and('Applied: '..nameFor(appliedCap))or'No applied capstone.',met)
    if selectedCap~=appliedCap then card.text(selectedCap and('Draft: '..nameFor(selectedCap)..' (not applied)')or'Draft removes the capstone.',met)end
    card.finish()
  end
  box:setHeight(math.max(1,y))
end


local detailTab,inspected='talent',nil
local function resetDetailScroll()
  if not window then return end
  local scroll=window:recursiveGetChildById('detailScroll');local bar=window:recursiveGetChildById('detailVertical')
  if scroll and bar then scroll:updateScrollBars();bar:setValue(bar:getMinimum())end
end
local function updateDetails()
  if not ui.nodeName then return end
  local changed=inspected~=state.selected
  if changed then inspected=state.selected;detailTab='talent'end
  local node=state.nodes[state.selected];local rank=node and(state.draft[node.id]or 0)or 0;local saved=node and(state.ranks[node.id]or 0)or 0
  ui.nodeName:setText(node and node.name or'Choose a talent')
  local tier=node and(node.type=='capstone'and'Capstone'or node.type=='major'and'Major'or'Minor')or''
  ui.nodeRank:setText(node and(tier..' | '..(rank~=saved and'Draft'or isPermanent()and'Saved'or'Applied')..' '..rank..'/'..node.maxRank..(rank~=saved and(' | '..(isPermanent()and'Saved'or'Applied')..': '..saved)or''))or'')
  local text='Add ranks, then Apply to activate them. Undo draft returns unsaved ranks.'
  if node then
    local effects=node.benefits or node.ranks or{}
    text=(rank>0 and((rank~=saved and'Draft rank'or'Current rank')..' ('..rank..'/'..node.maxRank..')\n'..(effects[rank]or''))or'Current\nNot trained.')
    if rank~=saved then text=text..'\n\nPreview only. Apply to save and activate. Undo draft returns unsaved points for free.'
    elseif isPermanent()and saved>0 then text=text..'\n\nSaved ranks are locked. Use Respec to return these points.'end
    if effects[rank+1]then text=text..'\n\n'..(rank==0 and'First rank'or'Next rank ('..(rank+1)..'/'..node.maxRank..')')..'\n'..effects[rank+1]
    end
    if node.role=='advancedMajor'then
      text=text..'\n\nBoth required';for _,r in ipairs(node.requires.all)do text=text..'\n'..nameFor(r.id)..' '..(state.draft[r.id]or 0)..'/'..r.rank end
    end
    if node.description and node.description~=''then text=text..'\n\nHow it works\n'..node.description end
    local rankText=node.benefits and node.ranks and node.ranks[math.max(1,rank)]
    if rankText and node.role~='advancedMajor' and node.role~='routeMinor' and not text:find(rankText,1,true)then text=text..'\n\n'..rankText end
  end
  ui.nodeDescription:setText(text);updateRequirements(node)
  ui.nodeDescription:setVisible(detailTab=='talent');ui.nodeRequirements:setVisible(detailTab=='requirements')
  ui.talentTab:setOn(detailTab=='talent');ui.requirementsTab:setOn(detailTab=='requirements')
  local addError,removeError='Choose a talent.','Choose a talent.'
  if node then addError=rankError(node,1);removeError=rankError(node,-1)end
  ui.addRank:setEnabled(not addError);ui.removeRank:setEnabled(not removeError)
  ui.addRank:setTooltip(addError or'Add one draft rank. Apply to activate it.')
  ui.removeRank:setTooltip(removeError or(isPermanent()and'Undo one new draft rank.'or'Return one draft point. Apply to confirm.'))
  local availability=addError or('Prerequisites met | '..math.max(0,state.points-spent(state.draft))..' unspent points')
  if addError and addError:find('prerequisites')then availability='Locked - view Requirements.'end
  if rank~=saved then availability='Unsaved change - Apply to activate.'end
  if state.pending then availability='Updating talents.'end
  ui.nodeAvailability:setText(availability);ui.nodeAvailability:setColor(addError and rank==saved and'#d1b19a'or'#d8c08b')
  if changed then resetDetailScroll();scheduleEvent(resetDetailScroll,20)end
end
function setDetailTab(tab)
  if tab~='talent'and tab~='requirements'then return false end
  detailTab=tab;updateDetails();resetDetailScroll();return true
end
function requirementKey(id,key,mods)
  if mods==KeyboardNoModifier and(key==KeyEnter or key==KeySpace)then return selectNode(id)end
  return false
end
local function refreshConnectors()
  for _,edge in ipairs(edgeGroups)do
    local view=PassivesTree.connectorState(edge,state.selected,state.draft,state.ranks,state.nodes,summaryConditions(state.nodes[edge.to]))
    edge.view,edge.visible,edge.highlighted,edge.active=view,view.visible,edge.to==state.selected,view.priority==2
    for _,widget in ipairs(edge.widgets)do widget:setVisible(view.visible);widget:setBackgroundColor(view.color)end
  end
  for _,widget in pairs(nodeWidgets)do widget:raise();widget.nodeCaption:raise()end
end
local function updateView()
  if not window then return end
  local used = spent(state.draft)
  local className = (state.tree and (state.tree.name or state.tree.id) or 'Passives'):gsub(' %- TEST$', '')
  window:setText(className .. (isPermanent() and ' - Passives' or ' - LOCAL TEST'))
  ui.testLabel:setText(isPermanent() and (className .. ' - class locked; respec changes talents only') or
    'TEMPORARY TEST TREE - your class and progression are unchanged')
  ui.pointsLabel:setText(string.format('Points: %d available / %d total',
    math.max(0,state.points-used),state.points)..(draftChanged() and ' | Unsaved changes' or ''))
  local selected = state.nodes[state.selected]
  local related={}
  for _,edge in ipairs(edgeGroups)do if edge.to==state.selected and PassivesTree.connectorState(edge,state.selected,state.draft,state.ranks,state.nodes,summaryConditions(selected)).met then related[edge.from]=true end end
  for index=1,4 do
    local info=branchInfo(index);local widget=branchWidgets[info.id]
    if widget then
      local total=(state.draft[info.minors[1]]or 0)+(state.draft[info.minors[2]]or 0)
      widget.label:setText(renderTree and info.label or info.label..' '..total..'/'..info.threshold)
      widget.points,widget.required=total,info.threshold
      widget.label:setColor(total>=info.threshold and '#a8b997'or'#c7c1b2')
      local explanation=info.label..': '..total..' minor ranks toward '..info.threshold..' required.\nAny split across '..nameFor(info.minors[1])..' and '..nameFor(info.minors[2])..'.\nMajor ranks do not count toward this gate.'
      widget:setTooltip(explanation);widget.label:setTooltip(explanation)
    end
  end
  local otherCap
  for id,rank in pairs(state.draft)do if rank>0 and state.nodes[id].type=='capstone'then otherCap=id end end
  for id, widget in pairs(nodeWidgets) do
    local node = state.nodes[id]
    local rank = state.draft[id] or 0
    local applied = state.ranks[id] or 0
    local available = requirementsMet(node, state.draft)
    local locked=not available or(node.type=='capstone'and otherCap and otherCap~=id)
    widget.rank:setText(rank .. '/' .. node.maxRank)
    widget.rank:setColor(rank~=applied and'#9bb6c0'or applied>0 and'#e9dcc0'or'#c7c1b2')
    widget:getChildById('nodeLock'):setVisible(locked and rank==0 or false)
    widget:getChildById('nodeDraft'):setVisible(rank~=applied)
    widget.locked,widget.changed=locked and true or false,rank~=applied
    local color = locked and '#5b5650' or '#817660'
    if related[id]then color='#81979d'end
    if applied > 0 then color = '#b7a471' end
    if rank ~= applied then color = '#9bb6c0' end
    if id == state.selected then color = '#a8c4cc' end
    widget:setBorderWidth((node.type ~= 'minor' or id==state.selected) and 2 or 1)
    widget.previewBorderColor=color;widget:mergeStyle({['border-color']=color,['$focus']={['border-color']=color}})
    local frame=widget:getChildById('tierFrame')
    if frame then frame:setBorderColor(applied>0 and'#b7a471'or related[id]and'#81979d'or'#817660')end
    local title = widget.nodeCaption
    if title then
      title:setColor(id==state.selected and'#a8c4cc'or applied>0 and'#e4c98e'or related[id]and'#9bb6c0'or'#c5bea9')
      title:setBorderColor(color)
    end
    widget.glyph:setOpacity((available or rank > 0) and 1 or 0.65)
    widget:getChildById('inspectionFrame'):setVisible(id==state.selected)
    local reason=rankError(node,1)or'Next rank costs 1 point.'
    widget:setTooltip(node.name .. '\n' .. node.type .. ' - rank ' .. rank .. '/' .. node.maxRank ..
      (rank ~= applied and (' ('..(isPermanent()and'saved'or'applied')..': '..applied..')\nUnsaved rank change.') or '') ..'\n'..reason..'\nClick for effects and requirements.')
    if title then title:setTooltip(widget:getTooltip())end
  end
  refreshConnectors()
  local errorText = validationError(state.draft)
  ui.applyButton:setEnabled(state.active and state.tree ~= nil and not state.pending and draftChanged() and not errorText)
  ui.applyButton:setTooltip(isPermanent()and'Save and activate the draft. Saved ranks can only be removed with Respec.'or'Apply this temporary draft.')
  ui.discardButton:setEnabled(not state.pending and draftChanged())
  ui.resetButton:setWidth(isPermanent() and 148 or 100)
  ui.resetButton:setText(isPermanent() and (state.respecCost == 0 and 'Respec (free)' or
    state.respecCost and 'Respec (' .. state.respecCost .. ' gp)' or 'Respec') or 'Reset (free)')
  ui.resetButton:setTooltip(isPermanent() and (state.respecCost and ('Cost: ' .. state.respecCost .. ' gp. Your class stays locked.') or 'Checking respec cost.') or 'Reset this temporary test for free.')
  ui.resetButton:setEnabled(state.active and not state.pending and
    (not isPermanent() or (state.respecCost ~= nil and spent(state.ranks) > 0)))
  ui.endButton:setVisible(not isPermanent())
  ui.endButton:setEnabled(state.active and not state.pending and not isPermanent())
  ui.removeRank:setText(isPermanent() and 'Undo rank' or 'Remove rank')
  updateReopenButton()
  updateDetails()
end

local function closeConfirmation()
  if confirmation then confirmation:destroy(); confirmation = nil end
end

local function clearTransfer()
  clearEvent(transferEvent)
  transferEvent = nil
  transfer = nil
end

local function destroyWindows()
  clearEvent(scrollEvent); scrollEvent = nil
  closeConfirmation()
  if window then window:destroy(); window = nil end
  if statusWindow then statusWindow:destroy(); statusWindow = nil end
  ui, nodeWidgets, edgeWidgets, branchWidgets, edgeGroups = {}, {}, {}, {}, {}
end

local function clampWindow()
  ClassSpells.clamp()
  ClassChoice.clamp()
  if not window then return end
  local size = g_ui.getRootWidget():getSize()
  window:setSize({ width = math.min(800, math.max(560, size.width - 24)), height = math.min(616, math.max(400, size.height - 24)) })
  window:setPosition({ x = math.max(0, math.floor((size.width - window:getWidth()) / 2)), y = math.max(0, math.floor((size.height - window:getHeight()) / 2)) })
end

local function line(parent, x, y, width, height)
  local widget = g_ui.createWidget('PassiveConnector', parent)
  widget:setPosition({ x = parent:getX() + x, y = parent:getY() + y })
  widget:addAnchor(AnchorLeft, 'parent', AnchorLeft)
  widget:addAnchor(AnchorTop, 'parent', AnchorTop)
  widget:setMarginLeft(x)
  widget:setMarginTop(y)
  widget:setSize({ width = math.max(2, width), height = math.max(2, height) })
  return widget
end

local function buildLegacyConnectors()
  local segments = {}
  edgeWidgets, edgeGroups = {}, {}
  -- Each class has its own authoritative capstone families. Dedicated side
  -- corridors keep their three routes off node frames and nameplates, regardless
  -- of which core/bridge majors the catalog links. Never infer a prerequisite
  -- from a fixed class-agnostic picture.
  local sourceOrder, busTracks = {}, {}
  local coreBus, bridgeBus = 0, 0
  local coreBuses={242,240,236,234,232,230,228,226}
  for _,id in ipairs(capstoneIds())do
    local sources={}
    for _,edge in ipairs(state.tree.edges or {})do if edge.to==id then sources[#sources+1]=edge.from end end
    table.sort(sources,function(a,b)
      local ax,bx=treeLayout[a].x,treeLayout[b].x
      return ax==bx and a<b or ax<bx
    end)
    sourceOrder[id],busTracks[id]={},{}
    for index,source in ipairs(sources)do
      sourceOrder[id][source]=index
      if treeLayout[source].y==244 then
        coreBus=coreBus+1;busTracks[id][source]=coreBuses[coreBus]
      else
        bridgeBus=bridgeBus+1;busTracks[id][source]=138-bridgeBus*4
      end
    end
  end
  local function pointsFor(edge)
    local source, destination=treeLayout[edge.from],treeLayout[edge.to]
    if not source or not destination then return nil end
    for index,branch in ipairs(branches)do
      if edge.to==branch.major then
        local left=edge.from==branch.minors[1]
        local center=source.x+22
        local lane=left and destination.x-4 or destination.x+destination.width+4
        local entry=left and destination.x or destination.x+destination.width
        return {{center,source.y},{center,354},{lane,354},{lane,282},{entry,282}}
      end
    end
    if edge.to=='major_tactical'or edge.to=='major_steady'then
      local center=source.x+source.width/2
      local left=center<destination.x+destination.width/2
      local entry=left and destination.x or destination.x+destination.width
      local lane=left and entry-4 or entry+4
      return {{center,source.y},{center,238},{lane,238},{lane,182},{entry,182}}
    end
    for index,id in ipairs(capstoneIds())do
      if edge.to==id then
        local order=sourceOrder[id][edge.from]
        if not order or order>3 then return nil end
        local left=index==1 or index==2 and source.x+source.width/2<240
        local lane=index==1 and (6+order*6) or index==3 and (452+order*6) or
          left and (172+order*4) or (292+order*4)
        local exitX=source.x+20+index*16
        local bus=busTracks[id][edge.from]
        if not bus then return nil end
        local entry=left and destination.x or destination.x+destination.width
        local targetY=destination.y+16+order*12
        return {{exitX,source.y},{exitX,bus},{lane,bus},{lane,targetY},{entry,targetY}}
      end
    end
    local x1,x2=source.x+source.width/2,destination.x+destination.width/2
    local bus=math.floor((source.y+destination.y+destination.height)/2)
    return {{x1,source.y},{x1,bus},{destination.x-4,bus},{destination.x-4,destination.y+destination.height/2},{destination.x,destination.y+destination.height/2}}
  end
  for _,edge in ipairs(state.tree.edges or {})do
    local points=pointsFor(edge)
    if points then
      local group={from=edge.from,to=edge.to,widgets={},segments={},points=points,capstone=state.nodes[edge.to].type=='capstone'}
      edgeGroups[#edgeGroups+1]=group
      for index=2,#points do
        local a,b=points[index-1],points[index]
        if a[1]~=b[1]or a[2]~=b[2]then
          segments[#segments+1]={x1=math.min(a[1],b[1]),x2=math.max(a[1],b[1]),y1=math.min(a[2],b[2]),y2=math.max(a[2],b[2]),group=group}
        end
      end
    end
  end
  local function draw(group,x,y,width,height)
    local widget=line(ui.canvas,x-1,y-1,width,height)
    widget:setId('passiveLink_'..(#edgeWidgets+1))
    edgeWidgets[#edgeWidgets+1]={widget=widget,from=group.from,to=group.to,routes={group}}
    group.widgets[#group.widgets+1]=widget
    group.segments[#group.segments+1]={x=x-1,y=y-1,width=width,height=height}
    return widget
  end
  for _,segment in ipairs(segments)do
    if segment.y1~=segment.y2 then
      draw(segment.group,segment.x1,segment.y1,2,segment.y2-segment.y1+2)
    else
      local gaps={}
      for _,other in ipairs(segments)do
        if other.group~=segment.group and other.x1==other.x2 and other.x1>segment.x1 and other.x1<segment.x2 and segment.y1>=other.y1 and segment.y1<=other.y2 then
          gaps[#gaps+1]={math.max(segment.x1,other.x1-3),math.min(segment.x2,other.x1+3)}
        end
      end
      table.sort(gaps,function(a,b)return a[1]<b[1]end)
      local cursor=segment.x1
      for _,gap in ipairs(gaps)do
        if gap[1]>cursor then draw(segment.group,cursor,segment.y1,gap[1]-cursor,2)end
        cursor=math.max(cursor,gap[2])
      end
      if cursor<segment.x2 then draw(segment.group,cursor,segment.y1,segment.x2-cursor+2,2)end
    end
  end
  -- Pixel arrows enter the side of the destination, never through its caption.
  for _,group in ipairs(edgeGroups)do
    local points=group.points;local last,previous=points[#points],points[#points-1]
    local direction=last[1]>previous[1]and 1 or -1
    local tip=draw(group,last[1]-direction*2,last[2],2,2)
    if group.capstone then tip:setId('capstoneLink_'..group.to)end
    for _,sign in ipairs({-1,1})do draw(group,last[1]-direction*4,last[2]+sign*2,2,2)end
  end
end

local function buildConnectors()
  if not renderTree then return buildLegacyConnectors()end
  edgeWidgets,edgeGroups={},{}
  for _,edge in ipairs(renderTree.edges)do
    local group={from=edge.from,to=edge.to,kind=edge.kind,points=edge.waypoints,segments=edge.segments,widgets={},capstone=state.nodes[edge.to].type=='capstone'}
    edgeGroups[#edgeGroups+1]=group
    for _,rect in ipairs(edge.segments)do
      local widget=line(ui.canvas,rect.x,rect.y,rect.width,rect.height);widget:setId('passiveLink_'..(#edgeWidgets+1))
      group.widgets[#group.widgets+1]=widget;edgeWidgets[#edgeWidgets+1]={widget=widget,from=edge.from,to=edge.to,kind=edge.kind,routes={group}}
    end
  end
end
local function setTalentName(label,node)
  local text=node.shortName or node.name
  local words={};for word in text:gmatch('%S+')do words[#words+1]=word end
  if #words<2 or text:find('\n',1,true)then label:setText(text);return end
  local best,bestWidth
  for i=1,#words-1 do
    local candidate=table.concat(words,' ',1,i)..'\n'..table.concat(words,' ',i+1,#words)
    label:setText(candidate);local width=label:getTextSize().width
    if not bestWidth or width<bestWidth then best,bestWidth=candidate,width end
  end
  label:setText(best)
end
local function buildTree()
  if not window or not state.tree then return end
  ui.canvas:destroyChildren()
  nodeWidgets,edgeWidgets,edgeGroups,branchWidgets={},{},{},{}
  window:setText((state.tree.name or state.tree.id):gsub(' %- TEST$', '') .. (isPermanent() and ' - Passives' or ' - LOCAL TEST'))
  renderTree=state.tree.schemaVersion==2 and PassivesTree.render(state.tree)or nil
  if renderTree then treeLayout=renderTree.positions;ui.canvas:setSize(renderTree.canvas)
  else
    treeLayout={}
    for index,branch in ipairs(branches)do local offset=(index-1)*120;treeLayout[branch.minors[1]]={x=offset+8,y=360,width=44,height=44};treeLayout[branch.minors[2]]={x=offset+68,y=360,width=44,height=44};treeLayout[branch.major]={x=offset+8,y=244,width=104,height=52}end
    treeLayout.major_tactical={x=68,y=142,width=104,height=52};treeLayout.major_steady={x=308,y=142,width=104,height=52}
    for index,id in ipairs(capstoneIds())do treeLayout[id]={x=48+(index-1)*160,y=30,width=64,height=64}end;ui.canvas:setSize({width=480,height=450})
  end
  local function caption(parent,id,x,y,width,height,text,color)
    local label=g_ui.createWidget('PassiveCaption',parent)
    if id then label:setId(id)end
    label:addAnchor(AnchorLeft,'parent',AnchorLeft);label:addAnchor(AnchorTop,'parent',AnchorTop)
    label:setMarginLeft(x);label:setMarginTop(y);label:setSize({width=width,height=height});label:setText(text)
    if color then label:setColor(color)end
    return label
  end
  for index=1,4 do
    local info=branchInfo(index)
    local pane=g_ui.createWidget('PassiveBranch',ui.canvas)
    pane:setId('branch_'..info.id);pane:addAnchor(AnchorLeft,'parent',AnchorLeft);pane:addAnchor(AnchorTop,'parent',AnchorTop)
    pane:setMarginLeft((index-1)*120);pane:setMarginTop(renderTree and 628 or 330)
    if renderTree then pane:setSize({width=120,height=16});pane:setBorderWidth(0);pane:setBackgroundColor('#00000000')end
    pane.label=caption(pane,'branchLabel',renderTree and 31 or 8,renderTree and 0 or 2,renderTree and 58 or 104,16,'', '#c7c1b2');pane.label:setTextAlign(AlignCenter)
    pane.label:setPhantom(false)
    pane.minorIds,pane.majorId=info.minors,info.major
    branchWidgets[info.id]=pane
  end
  buildConnectors()
  for _,node in ipairs(state.tree.nodes)do
    local nodeId=node.id
    local position=treeLayout[node.id]or{x=node.x,y=node.y,width=44,height=44}
    local style=node.type=='capstone'and'PassiveCapstone'or node.type=='major'and'PassiveMajor'or'PassiveNode'
    local widget=g_ui.createWidget(style,ui.canvas)
    widget:setId(node.id);widget:addAnchor(AnchorLeft,'parent',AnchorLeft);widget:addAnchor(AnchorTop,'parent',AnchorTop)
    widget:setMarginLeft(position.x);widget:setMarginTop(position.y);widget:setSize({width=position.width,height=position.height})
    if node.type=='minor'then widget.nodeLock:setMarginRight(0)end
    widget.glyph:setMarginTop(node.type=='capstone'and 8 or node.type=='major'and 4 or 0)
    widget.rank:setMarginBottom(node.type=='capstone'and 7 or node.type=='major'and 3 or 0)
    -- The name is attached to its frame, with a centered two-line text band.
    -- Split authored names at word boundaries instead of wrapping one major
    -- differently from its neighbors. Icons and graph endpoints stay unchanged.
    local width=renderTree and renderTree.nameplates[node.id].width or node.type=='minor'and 58 or node.type=='major'and 104 or 108
    local nameplate=g_ui.createWidget('PassiveTalentName',ui.canvas)
    nameplate:setId('nodeCaption_'..node.id)
    nameplate:addAnchor(AnchorLeft,'parent',AnchorLeft);nameplate:addAnchor(AnchorTop,'parent',AnchorTop)
    nameplate:setMarginLeft(position.x+(position.width-width)/2)
    nameplate:setMarginTop(position.y+position.height)
    nameplate:setSize({width=width,height=30})
    setTalentName(nameplate,node)
    nameplate.onClick=function()selectNode(nodeId)end
    widget.nodeCaption=nameplate
    widget.glyph:setImageSource(node.icon or'/images/topbuttons/skills')
    widget.onClick=function()selectNode(nodeId)end
    widget.onFocusChange=function(_,focused,reason)if focused and reason==KeyboardFocusReason then selectNode(nodeId)end end
    local marker=g_ui.createWidget('PassiveLegendFrame',widget);marker:setId('inspectionFrame');marker:addAnchor(AnchorLeft,'parent',AnchorLeft);marker:addAnchor(AnchorTop,'parent',AnchorTop);marker:setMarginLeft(-3);marker:setMarginTop(-3);marker:setSize({width=position.width+6,height=position.height+6});marker:setBorderColor('#a8c4cc');marker:hide()
    nodeWidgets[node.id]=widget
  end
  updateView()
end

-- Layout/scrollbars settle on the next UI tick. Only explicit node selection or
-- a fresh empty tree moves the viewport; runtime updates and reopening do not.
local function scrollToSelection(initial)
  if not window then return end
  local scroll = window:recursiveGetChildById('treeScroll')
  local vertical = window:recursiveGetChildById('treeVertical')
  local horizontal = window:recursiveGetChildById('treeHorizontal')
  if not scroll or not vertical or not horizontal then return end
  scroll:updateScrollBars()
  -- The first settled pass also covers deferred scrollbar binding with an
  -- unchanged width, which does not emit onScrollWidthChange.
  if scroll.onScrollWidthChange then scroll:onScrollWidthChange() end
  if initial and spent(state.ranks) == 0 and spent(state.draft) == 0 then
    vertical:setValue(vertical:getMaximum())
    horizontal:setValue(horizontal:getMinimum())
    return
  end
  local widget = nodeWidgets[state.selected]
  if not widget then return end
  local rect, view = widget:getRect(), scroll:getPaddingRect()
  local name = widget.nodeCaption and widget.nodeCaption:getRect() or rect
  local left, right = math.min(rect.x,name.x), math.max(rect.x+rect.width,name.x+name.width)
  local top, bottom = rect.y, math.max(rect.y+rect.height,name.y+name.height)
  local dx = left < view.x and left-view.x or right > view.x+view.width and right-view.x-view.width or 0
  local dy = top < view.y and top-view.y or bottom > view.y+view.height and bottom-view.y-view.height or 0
  if dx ~= 0 then horizontal:setValue(horizontal:getValue()+dx) end
  if dy ~= 0 then vertical:setValue(vertical:getValue()+dy) end
end

local function scheduleTreeScroll(initial)
  clearEvent(scrollEvent)
  scrollEvent = scheduleEvent(function()
    scrollEvent = nil
    scrollToSelection(initial)
  end, 50)
end
local function ensureWindow()
  if window then return true end
  window = g_ui.displayUI('passives', g_ui.getRootWidget())
  if not window then return false end
  for _, id in ipairs({ 'testLabel', 'pointsLabel', 'statusToggle', 'canvas', 'nodeName', 'nodeRank', 'nodeAvailability', 'nodeDescription','nodeRequirements',
    'talentTab','requirementsTab','addRank', 'removeRank', 'statusLabel', 'applyButton', 'discardButton', 'resetButton', 'endButton', 'closeButton' }) do
    ui[id] = window:recursiveGetChildById(id)
  end
  -- Range changes follow layout updates, including a resize without selection.
  local treeScroll = window:recursiveGetChildById('treeScroll')
  local treeHorizontal = window:recursiveGetChildById('treeHorizontal')
  local treeVertical = window:recursiveGetChildById('treeVertical')
  treeScroll.onScrollWidthChange = function()
    local overflow = treeHorizontal:getMaximum() > treeHorizontal:getMinimum()
    treeHorizontal:setVisible(overflow)
    treeVertical:setMarginBottom(overflow and 12 or 0)
    treeScroll:addAnchor(AnchorBottom, overflow and 'treeHorizontal' or 'parent', overflow and AnchorTop or AnchorBottom)
  end
  treeScroll.onScrollWidthChange()
  ui.talentTab.onClick=function()setDetailTab('talent')end;ui.requirementsTab.onClick=function()setDetailTab('requirements')end
  ui.addRank.onClick = function() changeRank(1) end
  ui.removeRank.onClick = function() changeRank(-1) end
  ui.applyButton.onClick = apply
  ui.discardButton.onClick = discard
  ui.resetButton.onClick = reset
  ui.endButton.onClick = endTest
  ui.closeButton.onClick = hide
  ui.statusToggle:setChecked(g_settings.getBoolean('passivesTestShowStatus', true))
  ui.statusToggle.onCheckChange = function(_, checked) setStatusVisible(checked) end
  clampWindow()
  buildTree()
  return true
end

local function getCapstone()
  for id, rank in pairs(state.ranks) do
    if rank > 0 and state.nodes[id] and state.nodes[id].type == 'capstone' then return state.nodes[id] end
  end
end

local function updateRuntime()
  runtimeEvent = nil
  if not state.active then return end
  local showStatus = g_settings.getBoolean('passivesTestShowStatus', true)
  if not showStatus then
    if statusWindow then statusWindow:hide() end
    return
  end
  if not statusWindow then
    local parent = modules.game_interface and modules.game_interface.getRightPanel()
    if not parent then return end
    statusWindow = g_ui.loadUI('passives_status', parent)
    if not statusWindow then return end
    -- MiniWindow setup may restore an old closed state. That is not a user
    -- request to disable combat status in this session.
    settingUpStatus = true
    statusWindow:setup()
    settingUpStatus = false
    statusWindow:recursiveGetChildById('treeButton').onClick = show
  end
  statusWindow:open(true)
  statusWindow:setText(isPermanent() and 'Passives' or 'Passives - TEST')
  local cap = getCapstone()
  local runtime = state.runtime or {}
  local now = g_clock.millis()
  local berserkMs = math.max(0, (runtime.berserkUntil or 0) - now)
  local wardMs = math.max(0, (runtime.wardUntil or 0) - now)
  local attacking = g_game.getAttackingCreature()
  local targetId = attacking and attacking:getId() or 0
  local capstoneText = 'No capstone selected'
  if cap then
    capstoneText = runtime.weaponActive == false and
      (state.tree and state.tree.weaponName or 'Axe') .. ' required' or cap.name
  end
  statusWindow:recursiveGetChildById('capstoneLabel'):setText(capstoneText)
  -- No charging mechanic exists before a saved capstone has been chosen.
  -- Restore these rows on the same window when an allocation adds a capstone.
  local hasCapstone = cap ~= nil
  if statusWindow.passiveCapstoneSelected ~= hasCapstone then
    statusWindow.passiveCapstoneSelected = hasCapstone
    local height = hasCapstone and 150 or 72
    statusWindow.maximizedHeight = height
    if not statusWindow:isOn() then statusWindow:setHeight(height) end
  end
  for _, id in ipairs({'berserkLabel','wardLabel','bleedLabel'}) do
    statusWindow:recursiveGetChildById(id):setVisible(hasCapstone)
  end
  if not hasCapstone then
    statusWindow:recursiveGetChildById('rageBar'):hide()
    return
  end
  if state.tree and state.tree.id ~= 'reaver' then
    local maximum = math.max(1, runtime.progressMax or 1)
    local progress = math.max(0, math.min(maximum, runtime.progress or 0))
    local reactive = cap and ({cap_bladestorm='On critical hit', cap_stonebond='On shield block',
      cap_renewal='On effective healing', cap_aegis='On effective healing', cap_concord='On dealing damage'})[cap.id]
    local bar = statusWindow:recursiveGetChildById('rageBar')
    bar:setVisible(not reactive)
    bar:setPercent(progress / maximum * 100)
    bar:setText((runtime.progressLabel or 'Charge') .. ': ' .. progress .. ' / ' .. maximum)
    -- Anchor the trigger directly below the title when no charging mechanic exists.
    local firstStatus = statusWindow:recursiveGetChildById('berserkLabel')
    firstStatus:addAnchor(AnchorTop, reactive and 'capstoneLabel' or 'rageBar', AnchorBottom)
    for index, id in ipairs({'berserkLabel','wardLabel','bleedLabel'}) do
      local widget = statusWindow:recursiveGetChildById(id)
      local text = runtime['status' .. index] or (index == 2 and 'Shield: ' .. (runtime.ward or 0) or '')
      if index == 1 and reactive then text = reactive end
      -- Catalog names preserve spacing/capitalization in the player-facing HUD.
      if cap and cap.id then text = text:gsub(':%s*' .. cap.id:sub(5) .. '$', ': ' .. cap.name) end
      widget:setText(text); widget:setTooltip(text)
    end
    return
  end
  statusWindow:recursiveGetChildById('rageBar'):setVisible(true)
  statusWindow:recursiveGetChildById('berserkLabel'):addAnchor(AnchorTop, 'rageBar', AnchorBottom)
  local rageMax = math.max(1, runtime.rageMax or 100)
  statusWindow:recursiveGetChildById('rageBar'):setPercent(math.max(0, math.min(100, (runtime.rage or 0) / rageMax * 100)))
  statusWindow:recursiveGetChildById('rageBar'):setText('Rage: ' .. tostring(runtime.rage or 0) .. ' / ' .. tostring(rageMax))
  statusWindow:recursiveGetChildById('berserkLabel'):setText(berserkMs > 0 and string.format('BERSERK: %.1f s', berserkMs / 1000) or 'Berserk: inactive')
  statusWindow:recursiveGetChildById('wardLabel'):setText(wardMs > 0 and string.format('Shield: %d  (%.1f s)', runtime.ward or 0, wardMs / 1000) or 'Shield: 0')
  statusWindow:recursiveGetChildById('bleedLabel'):setText('Own target bleeds: ' .. tostring(targetId == runtime.targetId and (runtime.bleedStacks or 0) or 0) .. ' / 3')
  if berserkMs > 0 or wardMs > 0 then runtimeEvent = scheduleEvent(updateRuntime, 200) end
end

local function finishPending()
  clearEvent(pendingEvent); pendingEvent = nil; state.pending, state.pendingRequest = nil, nil
end

local function request(action, extra)
  if not state.active or state.pending then return false end
  requestCounter = requestCounter + 1
  local id = tostring(g_clock.millis()) .. ':' .. requestCounter
  local payload = extra or {}
  payload.action, payload.requestId = action, id
  state.pending = id
  state.pendingRequest = {id=id,action=action,session=state.session,revision=state.revision,ranks=copyRanks(state.ranks)}
  if not send(payload) then finishPending(); setStatus('Request could not be sent.', true); return false end
  pendingEvent = scheduleEvent(function()
    pendingEvent = nil
    if state.pending == id then
      state.pending, state.pendingRequest = nil, nil
      send({ action = 'snapshot' })
      setStatus('No reply yet. Checking your saved talents...', true)
      updateView()
    end
  end, 5000)
  setStatus('Updating talents...')
  updateView()
  return true
end

function selectNode(id)
  if not state.nodes[id] then return false end
  state.selected = id
  updateView()
  local detailScroll = window and window:recursiveGetChildById('detailScroll')
  local detailVertical = window and window:recursiveGetChildById('detailVertical')
  if detailScroll and detailVertical then
    detailScroll:updateScrollBars()
    detailVertical:setValue(detailVertical:getMinimum())
  end
  scheduleTreeScroll(false)
  if nodeWidgets[id]then nodeWidgets[id]:focus()end
  return true
end

function changeRank(delta, id)
  id = id or state.selected
  local node = state.nodes[id]
  if not node or state.pending or not state.active then return false end
  if delta ~= 1 and delta ~= -1 then return false end
  local reason = rankError(node, delta)
  if reason then setStatus(reason, true); return false end
  local rank = (state.draft[id] or 0) + delta
  local candidate = copyRanks(state.draft)
  candidate[id] = rank
  local errorText = validationError(candidate)
  if delta > 0 and errorText then setStatus(errorText, true); return false end
  state.draft = candidate
  updateView()
  setStatus(errorText or 'Draft changed. Apply to activate these ranks.', errorText ~= nil)
  return true
end

function apply()
  if not state.tree or not draftChanged() then return false end
  local errorText = validationError(state.draft)
  if errorText then setStatus(errorText, true); return false end
  return request('apply', { ranks = copyRanks(state.draft) })
end

function discard()
  if state.pending then return false end
  state.draft = copyRanks(state.ranks)
  updateView()
  setStatus('Draft discarded. Applied effects are unchanged.')
  return true
end

function reset()
  if not state.active or state.pending then return end
  closeConfirmation()
  if isPermanent() then
    if state.respecCost == nil then setStatus('Checking respec cost.', true); send({action = 'snapshot'}); return end
    local session, revision, cost, count = state.session, state.revision, state.respecCost, state.respecCount
    local price = cost == 0 and (count == 0 and 'Your first respec is free.' or 'This respec is free.') or 'Cost: ' .. cost .. ' gp from your bank.'
    confirmation = displayGeneralBox('Respec talents',
      'Return all spent points and clear the draft?\n\n' .. price .. '\nYour class stays locked.', {
        {text = 'Respec', callback = function()
          closeConfirmation()
          if not state.active or not isPermanent() or session ~= state.session or revision ~= state.revision or
            cost ~= state.respecCost or count ~= state.respecCount then
            setStatus('The respec quote changed. Reopen the confirmation.', true); return
          end
          request('reset', {quotedCost = cost, respecCount = count})
        end},
        {text = 'Cancel', callback = closeConfirmation}
      })
    return
  end
  confirmation = displayGeneralBox('Reset test tree', 'Return all test points and clear active passive effects?\n\nThis reset is free and does not change your real progression.', {
    { text = 'Reset', callback = function() closeConfirmation(); request('reset') end },
    { text = 'Cancel', callback = closeConfirmation }
  })
end

function endTest()
  if not state.active or state.pending or isPermanent() then return end
  closeConfirmation()
  confirmation = displayGeneralBox('End passive test', 'Clear this temporary tree and its effects?\n\nYour real class and progression are unchanged.', {
    { text = 'End test', callback = function() closeConfirmation(); request('end') end },
    { text = 'Cancel', callback = closeConfirmation }
  })
end

function hide()
  if window then window:hide() end
  if reopenButton then reopenButton:setOn(false) end
end

function show()
  if not state.active or not state.tree then return false end
  if not ensureWindow() then return false end
  window:show(); window:raise(); window:focus()
  updateView()
  if state.initialTreeScroll then
    state.initialTreeScroll = false
    scheduleTreeScroll(true)
  end
  if reopenButton then reopenButton:setOn(true) end
  return true
end

function setStatusVisible(visible)
  g_settings.set('passivesTestShowStatus', visible == true)
  if ui.statusToggle and ui.statusToggle:isChecked() ~= visible then ui.statusToggle:setChecked(visible) end
  clearEvent(runtimeEvent); runtimeEvent = nil
  updateRuntime()
end

function hideStatus()
  if settingUpStatus then return end
  setStatusVisible(false)
end

local function acceptCatalog(data)
  local tree = data.tree
  if type(data.session) ~= 'string' or #data.session > 128 then return false end
  if retiredSessions[data.session] then return false end
  if data.session == nil or type(tree) ~= 'table' or not treeCaps[tree.id] or type(tree.nodes) ~= 'table' then return false end
  local schema,schemaVersion=PassivesTree.schema(tree)
  if not schema or #tree.nodes~=schema.nodes then return false end
  if(data.schemaVersion~=nil and data.schemaVersion~=schemaVersion)or
    (data.catalogVersion~=nil and data.catalogVersion~=schemaVersion)or
    (data.nodeCount~=nil and data.nodeCount~=schema.nodes)then return false end
  if tree.name and (type(tree.name) ~= 'string' or #tree.name > 60) then return false end
  if tree.weaponName and (type(tree.weaponName) ~= 'string' or #tree.weaponName > 30) then return false end
  if tree.branches then
    if type(tree.branches) ~= 'table' or #tree.branches ~= 4 then return false end
    for _, name in ipairs(tree.branches) do if type(name) ~= 'string' or #name > 24 then return false end end
  end
  local nodes, counts = {}, { minor = 0, major = 0, capstone = 0 }
  for _, node in ipairs(tree.nodes) do
    if type(node.id) ~= 'string' or nodes[node.id] or not counts[node.type] or type(node.name) ~= 'string' or
      type(node.maxRank) ~= 'number' or node.maxRank ~= ({ minor = 5, major = 3, capstone = 1 })[node.type] or
      (schemaVersion==1 and(type(node.x)~='number'or type(node.y)~='number'))or
      (node.x~=nil and(type(node.x)~='number'or node.x~=node.x or node.x<0 or node.x>480))or
      (node.y~=nil and(type(node.y)~='number'or node.y~=node.y or node.y<0 or node.y>schema.maxY))then return false end
    if node.shortName and (type(node.shortName) ~= 'string' or #node.shortName > 60) then return false end
    if node.icon and (type(node.icon)~='string'or not node.icon:match('^/images/game/passives/[%w_%-]+$'))then return false end
    if node.description and type(node.description) ~= 'string' then return false end
    if node.ranks then
      if type(node.ranks) ~= 'table' then return false end
      for _, text in ipairs(node.ranks) do if type(text) ~= 'string' then return false end end
    end
    if node.benefits~=nil then
      if type(node.benefits)~='table'or #node.benefits~=node.maxRank then return false end
      for _,text in ipairs(node.benefits)do if type(text)~='string'or #text>400 then return false end end
    end
    if node.requires and type(node.requires) ~= 'table' then return false end
    nodes[node.id] = node
    counts[node.type] = counts[node.type] + 1
  end
  if counts.minor~=schema.minor or counts.major~=schema.major or counts.capstone~=schema.capstone then return false end
  for _, branch in ipairs(branches) do
    if not nodes[branch.major] or not nodes[branch.minors[1]] or not nodes[branch.minors[2]] then return false end
  end
  if not nodes.major_tactical or not nodes.major_steady then return false end
  for _, id in ipairs(treeCaps[tree.id]) do if not nodes[id] or nodes[id].type ~= 'capstone' then return false end end
  local function validGroup(group)
    if type(group) ~= 'table' or type(group.all) ~= 'table' or #group.all > schema.nodes then return false end
    for _, requirement in ipairs(group.all) do
      if type(requirement) ~= 'table' or not nodes[requirement.id] or type(requirement.rank) ~= 'number' or
        requirement.rank < 0 or requirement.rank > nodes[requirement.id].maxRank or requirement.rank ~= math.floor(requirement.rank) then return false end
    end
    return true
  end
  for _, node in ipairs(tree.nodes) do
    local requires = node.requires or {}
    if requires.spent and (type(requires.spent) ~= 'number' or requires.spent < 0 or requires.spent > 1000) then return false end
    if requires.all and not validGroup({ all = requires.all }) then return false end
    if requires.any then
      if type(requires.any) ~= 'table' or #requires.any > 128 then return false end
      for _, group in ipairs(requires.any) do if not validGroup(group) then return false end end
    end
    if node.requirementSummary~=nil and not summaryConditions(node,nodes)then return false end
    if node.branchIds~=nil then
      if type(node.branchIds)~='table'or #node.branchIds>4 then return false end
      local seen={}
      for _,id in ipairs(node.branchIds)do
        if not({precision=true,pressure=true,sustain=true,guard=true})[id]or seen[id]then return false end
        seen[id]=true
      end
      if node.branchId~=nil and(type(node.branchId)~='string'or #node.branchIds~=1 or node.branchIds[1]~=node.branchId)then return false end
    elseif node.branchId~=nil then return false end
  end
  if tree.branchGroups~=nil then
    if type(tree.branchGroups)~='table'or #tree.branchGroups~=4 then return false end
    local ids={'precision','pressure','sustain','guard'}
    for index,group in ipairs(tree.branchGroups)do
      local branch=branches[index]
      if schemaVersion==2 then
        branch=nil;for i,id in ipairs(ids)do if type(group)=='table'and group.id==id then branch=branches[i]end end
      end
      if not branch or type(group)~='table'or(schemaVersion==1 and group.id~=ids[index])or group.majorId~=branch.major or
        type(group.label)~='string'or #group.label==0 or #group.label>24 or
        (group.name~=nil and(type(group.name)~='string'or #group.name>24))or
        type(group.minorIds)~='table'or #group.minorIds~=2 or
        group.minorIds[1]~=branch.minors[1]or group.minorIds[2]~=branch.minors[2]then return false end
      local expected
      for _,condition in ipairs(summaryConditions(nodes[branch.major],nodes)or {})do
        if condition.kind=='sum'then expected=condition.required end
      end
      if not expected then
        local first=((nodes[branch.major].requires or {}).any or {})[1]
        if first then expected=0;for _,r in ipairs(first.all)do expected=expected+(r.rank or 1)end end
      end
      for _,key in ipairs({'requiredMinorPoints','unlockPoints'})do
        if group[key]~=nil and(type(group[key])~='number'or group[key]~=expected)then return false end
      end
    end
  end
  if tree.edges and (type(tree.edges) ~= 'table' or #tree.edges > 150) then return false end
  local seenEdges={}
  for _,edge in ipairs(tree.edges or {})do
    if type(edge)~='table'or not nodes[edge.from]or not nodes[edge.to]or edge.from==edge.to then return false end
    local key=edge.from..':'..edge.to
    if seenEdges[key]then return false end;seenEdges[key]=true
  end
  if not PassivesTree.validate(tree,nodes)then return false end
  if data.session ~= state.session then
    -- The catalog does not identify test/permanent mode. Hide the old UI
    -- until the matching snapshot supplies the authoritative mode.
    if window then
      state.openRequested = state.openRequested or window:isVisible()
      window:hide()
    end
    if statusWindow then statusWindow:hide() end
    clearEvent(runtimeEvent); runtimeEvent = nil
    retireSession(state.session)
    closeConfirmation()
    finishPending()
    state.ranks, state.draft, state.runtime = {}, {}, {}
    state.revision, state.points, state.active = 0, 0, false
    state.mode, state.respecCost, state.respecCount, state.classLocked = 'test', nil, 0, false
    state.session = data.session
    state.newSession = true
    state.initialTreeScroll = true
  end
  state.tree, state.nodes = tree, nodes
  if window then buildTree() end
  updateReopenButton()
  return true
end

local function acceptSnapshot(data, reply)
  if not state.tree then return false end
  local schema,version=PassivesTree.schema(state.tree)
  if not schema or(version==2 and(data.schemaVersion~=2 or data.catalogVersion~=2 or data.nodeCount~=29))or
    (version==1 and((data.schemaVersion~=nil and data.schemaVersion~=1)or(data.catalogVersion~=nil and data.catalogVersion~=1)or(data.nodeCount~=nil and data.nodeCount~=17)))then return false end
  if data.session ~= state.session or type(data.revision) ~= 'number' or data.revision < state.revision or
    type(data.ranks) ~= 'table' or type(data.points) ~= 'number' or data.points < 0 or data.points > 1000 or
    data.points ~= math.floor(data.points) then return false end
  local mode = data.mode or 'test'
  if mode ~= 'test' and mode ~= 'permanent' then return false end
  if mode == 'permanent' and (type(data.respecCost) ~= 'number' or data.respecCost < 0 or
    data.respecCost > 1000000000 or data.respecCost ~= math.floor(data.respecCost) or
    type(data.respecCount) ~= 'number' or data.respecCount < 0 or data.respecCount > 1000000 or
    data.respecCount ~= math.floor(data.respecCount)) then return false end
  local ranks = {}
  for id, rank in pairs(data.ranks) do
    if not state.nodes[id] or type(rank) ~= 'number' or rank < 0 or rank > state.nodes[id].maxRank or rank ~= math.floor(rank) then return false end
    ranks[id] = rank
  end
  local changed = state.newSession == true or data.revision > state.revision or state.mode ~= mode
  if changed or state.respecCost ~= data.respecCost or state.respecCount ~= data.respecCount then closeConfirmation() end
  local sameSaved = true
  for id in pairs(state.nodes) do
    if (state.ranks[id] or 0) ~= (ranks[id] or 0) then sameSaved = false; break end
  end
  local pending = state.pendingRequest
  local failedApply = reply and reply.ok == false and pending and pending.action == 'apply' and
    reply.requestId == pending.id and pending.session == state.session and pending.revision == state.revision
  if failedApply then
    for id in pairs(state.nodes) do
      if (pending.ranks[id] or 0) ~= (ranks[id] or 0) then failedApply = false; break end
    end
  end
  local unsolicitedApplySnapshot = not reply and pending and pending.action == 'apply'
  local preserveDraft = not changed and sameSaved and data.active == true and draftChanged() and
    (not state.pending or failedApply or unsolicitedApplySnapshot)
  state.revision, state.points, state.active = data.revision, data.points, data.active == true
  state.mode, state.respecCost, state.respecCount = mode, data.respecCost, data.respecCount or 0
  state.classLocked = mode == 'permanent' and data.classLocked ~= false
  if mode == 'permanent' then state.classId = state.tree and state.tree.id end
  state.newSession = false
  state.ranks = ranks
  -- A lower point budget or changed catalog may invalidate even an unchanged
  -- base. Never retain an illegal draft. Late replies never resurrect a copy.
  if preserveDraft and validationError(state.draft) then preserveDraft = false end
  if not preserveDraft then state.draft = copyRanks(ranks) end
  if reply or changed or not sameSaved or not state.active then finishPending() end
  updateView()
  if changed then setStatus(isPermanent() and 'Talents loaded.' or 'Test build loaded.') end
  updateRuntime()
  if state.openRequested and state.active then show(); state.openRequested = false end
  if not state.active then destroyWindows() end
  updateReopenButton()
  return true
end

local function handleMessage(data)
  if type(data) ~= 'table' or data.v ~= VERSION or type(data.action) ~= 'string' then return false end
  if data.action:find('^class_choice_') then
    if not state.ready then return false end
    return ClassChoice.receive(data)
  end
  if data.action == 'class_spells' or data.action == 'class_spell_cooldown' then
    if not state.ready or not state.active or not isPermanent() or
      (data.session and (data.session ~= state.session or retiredSessions[data.session])) then return false end
    return ClassSpells.receive(data, state.classId)
  end
  if data.action == 'hello' or data.action == 'capabilities' then
    if data.enabled == false then offline(); return false end
    if data.enabled ~= true or data.capable == false then return false end
    -- The isolated runner retains its legacy hello fixtures. Remote DEV must
    -- explicitly acknowledge the current catalog contract before opening UI.
    if LOCAL_PASSIVES_TEST ~= true and (data.capable ~= true or data.schemaVersion ~= 2 or
      data.catalogVersion ~= 2 or data.nodeCount ~= 29) then return false end
    state.ready = true
    if type(data.classId) == 'string' and (#data.classId == 0 or treeCaps[data.classId]) then state.classId = data.classId end
    if type(data.classHint) == 'string' and #data.classHint <= 160 then state.classHint = data.classHint end
    if type(data.classCatalog) == 'table' and #data.classCatalog <= 6 then
      local classes = {}
      for _, entry in ipairs(data.classCatalog) do
        if type(entry) == 'table' and treeCaps[entry.id] and type(entry.name) == 'string' and #entry.name <= 60 then
          classes[#classes + 1] = {id = entry.id, name = entry.name}
        end
      end
      state.classCatalog = classes
    end
    clearEvent(helloEvent); helloEvent = nil
    updateReopenButton()
    return true
  end
  if not state.ready then return false end
  if data.action == 'refresh' then
    -- Automatic permanent restoration creates a new session after death.
    -- Its snapshot needs a matching catalog before it can be accepted.
    if not state.ready or not g_game.isOnline() or type(data.session) ~= 'string' or
      #data.session == 0 or #data.session > 128 or retiredSessions[data.session] then return false end
    return send({action = 'snapshot'})
  end
  if data.action == 'catalog' then
    clearTransfer()
    return acceptCatalog(data)
  end
  if data.action == 'catalog_part' then
    if retiredSessions[data.session] then return false end
    if type(data.transfer) ~= 'string' or type(data.total) ~= 'number' or data.total < 1 or data.total > MAX_PARTS or
      data.total ~= math.floor(data.total) or type(data.index) ~= 'number' or data.index < 1 or data.index > data.total or
      data.index ~= math.floor(data.index) or type(data.data) ~= 'string' or #data.data > 7000 then return false end
    if not transfer or transfer.id ~= data.transfer or transfer.session ~= data.session then
      clearTransfer()
      transfer = { id = data.transfer, session = data.session, total = data.total, parts = {}, size = 0 }
      transferEvent = scheduleEvent(function() clearTransfer(); setStatus('Talents could not load. Reopen the talent window.', true) end, 10000)
    end
    if transfer.total ~= data.total then clearTransfer(); return false end
    if transfer.parts[data.index] then
      if transfer.parts[data.index] ~= data.data then clearTransfer(); return false end
      return true
    end
    transfer.parts[data.index] = data.data
    transfer.size = transfer.size + #data.data
    if transfer.size > MAX_CATALOG then clearTransfer(); return false end
    for index = 1, transfer.total do if not transfer.parts[index] then return true end end
    local session = transfer.session
    local ok, catalog = pcall(json.decode, table.concat(transfer.parts))
    clearTransfer()
    if not ok or type(catalog) ~= 'table' or catalog.session ~= session then return false end
    return acceptCatalog(catalog)
  end
  if data.action == 'snapshot' then return acceptSnapshot(data) end
  if data.session ~= state.session then return false end
  if data.action == 'open' then
    state.openRequested = true
    if state.active and state.tree then show(); state.openRequested = false end
    return true
  end
  if data.action == 'result' then
    if type(data.ok) ~= 'boolean' then return false end
    if data.requestId and state.pending and data.requestId ~= state.pending and
      not (data.snapshot and type(data.snapshot.revision)=='number' and data.snapshot.revision>state.revision) then return false end
    if data.snapshot and type(data.snapshot.revision) == 'number' and data.snapshot.revision < state.revision then return false end
    if data.snapshot then
      if not acceptSnapshot(data.snapshot,data) then return false end
    else finishPending(); updateView() end
    setStatus(data.ok and (isPermanent() and 'Talents saved.' or 'Test build applied.') or tostring(data.error or 'The change could not be applied.'), not data.ok)
    return true
  end
  if data.action == 'runtime' then
    if not state.active then return false end
    local now = g_clock.millis()
    local rageMax = math.max(1, math.min(1000, tonumber(data.rageMax) or 100))
    state.runtime = { rage = math.max(0, math.min(rageMax, tonumber(data.rage) or 0)), rageMax = rageMax,
      berserkUntil = now + math.max(0, tonumber(data.berserkMs) or 0),
      ward = math.max(0, tonumber(data.ward) or 0), wardUntil = now + math.max(0, tonumber(data.wardMs) or 0),
      bleedStacks = math.max(0, math.min(3, tonumber(data.bleedStacks) or 0)), targetId = tonumber(data.targetId) or 0,
      weaponActive = data.weaponActive ~= false }
    state.runtime.progress = math.max(0, math.min(1000, tonumber(data.progress) or 0))
    state.runtime.progressMax = math.max(1, math.min(1000, tonumber(data.progressMax) or 1))
    for _, key in ipairs({'progressLabel','status1','status2','status3'}) do
      if type(data[key]) == 'string' then state.runtime[key] = data[key]:sub(1, 100) end
    end
    clearEvent(runtimeEvent); runtimeEvent = nil
    updateRuntime()
    return true
  end
  if data.action == 'end' then
    ClassSpells.reset()
    retireSession(state.session)
    finishPending(); clearEvent(runtimeEvent); runtimeEvent = nil
    state.active, state.ranks, state.draft, state.runtime = false, {}, {}, {}
    destroyWindows()
    updateReopenButton()
    return true
  end
  return false
end

local function onOpcode(protocol, opcode, buffer)
  if not registered or not profileEnabled() or not g_game.isOnline() or opcode ~= OPCODE or #buffer > MAX_PACKET then return end
  local ok, data = pcall(json.decode, buffer)
  if not ok then return end
  local handled, errorText = pcall(handleMessage, data)
  if not handled then
    g_logger.warning('[Passives] Invalid server payload: ' .. tostring(errorText))
    setStatus('Talents could not load. Reopen the talent window.', true)
  end
end

local function online()
  clearEvent(helloEvent)
  local attempts = 0
  local function hello()
    helloEvent = nil
    if not g_game.isOnline() or state.ready then return end
    attempts = attempts + 1
    send({ action = 'hello', client = LOCAL_PASSIVES_TEST == true and 'local-passives' or 'dev-passives',
      schemaVersion = 2, catalogVersion = 2, nodeCount = 29, maxCatalogPart = 7000, classChoice = true })
    if attempts < 5 then helloEvent = scheduleEvent(hello, 2000) end
  end
  helloEvent = scheduleEvent(hello, 500)
end

offline = function()
  ClassSpells.reset()
  ClassChoice.reset()
  clearEvent(helloEvent); helloEvent = nil
  clearEvent(runtimeEvent); runtimeEvent = nil
  finishPending(); clearTransfer(); destroyWindows(); resetState()
  removeReopenButton()
end

local function targetChanged()
  clearEvent(runtimeEvent); runtimeEvent = nil
  updateRuntime()
end

function init()
  resetState()
  if not profileEnabled() then return end
  ClassChoice.init(send, featureEnabled)
  ClassSpells.init(featureEnabled)
  ProtocolGame.registerExtendedOpcode(OPCODE, onOpcode)
  registered = true
  connect(g_game, { onGameStart = online, onGameEnd = offline, onAttackingCreatureChange = targetChanged })
  connect(g_ui.getRootWidget(), { onGeometryChange = clampWindow })
  if g_game.isOnline() then online() end
end

function terminate()
  if not registered then return end
  disconnect(g_game, { onGameStart = online, onGameEnd = offline, onAttackingCreatureChange = targetChanged })
  disconnect(g_ui.getRootWidget(), { onGeometryChange = clampWindow })
  offline()
  ProtocolGame.unregisterExtendedOpcode(OPCODE)
  registered = false
end

-- Inspection hooks used by real-client local integration probes.
function getState() return state end
function getDebugState() return state end
function getWindow() return window end
function getNodeWidget(id) return nodeWidgets[id] end
function getBranchWidget(id) return branchWidgets[id] end
function getEdgeWidgets() return edgeGroups end
function getRenderedTree() return renderTree end
function getStatusWindow() return statusWindow end
function getReopenButton() return reopenButton end
function getClassChoice() return ClassChoice end
function validateDraft(ranks) return validationError(ranks) end
