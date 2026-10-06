-- Load into the disposable native probe. Root owns transport, fixtures and launch.
-- Real widget/handler checks; no OS-input, combat or migration claim.
PassivesConnectedUI={}
function PassivesConnectedUI.verify(mod,selectionCases)
  local state=mod.getState();local window=assert(mod.getWindow());local root=g_ui.getRootWidget():getRect()
  local geometry=assert(mod.getRenderedTree());local groups=mod.getEdgeWidgets()
  assert(state.tree.schemaVersion==2 and #state.tree.nodes==29 and #groups==36,'Catalog/geometry mismatch')
  local wr=window:getRect();assert(wr.x>=0 and wr.y>=0 and wr.x+wr.width<=root.width and wr.y+wr.height<=root.height,'Window outside viewport')
  local function overlap(a,b)return a.x<b.x+b.width and b.x<a.x+a.width and a.y<b.y+b.height and b.y<a.y+a.height end
  local function boundary(a,b)return a.x+a.width<=b.x+1 or a.x>=b.x+b.width-1 or a.y+a.height<=b.y+1 or a.y>=b.y+b.height-1 end
  local coreIndices,contextualOptional={},{}
  for i,id in ipairs(state.tree.topology.coreOrder)do coreIndices[id]=i end
  local overview=#groups-#state.tree.topology.paths
  for _,path in ipairs(state.tree.topology.optionalPaths)do
    if math.abs(coreIndices[path.coreIds[1]]-coreIndices[path.coreIds[2]])>1 then contextualOptional[path.optionalId]=true;overview=overview-#path.coreIds end
  end
  local function expectedVisible(selected)
    local count=overview
    if state.nodes[selected]and state.nodes[selected].role=='advancedMajor'then count=count+1 end
    for _,path in ipairs(state.tree.topology.optionalPaths)do if path.optionalId==selected and contextualOptional[selected]then count=count+#path.coreIds end end
    return count
  end
  local cards,headings,rects={},{},{}
  for _,node in ipairs(state.tree.nodes)do
    local widget=assert(mod.getNodeWidget(node.id));local p=geometry.positions[node.id]
    assert(widget:getWidth()==p.width and widget:getHeight()==p.height,'Frame size '..node.id)
    assert(widget.glyph:getWidth()==32 and widget.glyph:getHeight()==32,'Glyph scaled '..node.id)
    assert(widget.glyph:getY()+32<=widget.rank:getY(),'Glyph/rank overlap '..node.id)
    local name=widget.nodeCaption;assert(name:getTextSize().width<=name:getWidth()-2 and name:getTextSize().height<=name:getHeight()-2,'Name clipped '..node.name)
    assert(name:getY()==widget:getY()+widget:getHeight(),'Detached nameplate')
    cards[#cards+1]={id=node.id,rect=widget:getRect()};cards[#cards+1]={id=node.id,rect=name:getRect()}
  end
  for _,branch in ipairs(state.tree.branchGroups)do local widget=assert(mod.getBranchWidget(branch.id));assert(widget.label:getText()==branch.label,'Branch heading lost/misleading numeric strip');headings[#headings+1]=widget.label:getRect()end
  for _,edge in ipairs(groups)do rects[edge]={};for _,widget in ipairs(edge.widgets)do rects[edge][#rects[edge]+1]=widget:getRect()end end
  local function visible(expected,pixels)
    local shown={}
    for _,edge in ipairs(groups)do
      for _,widget in ipairs(edge.widgets)do assert(widget:isVisible()==edge.visible,'Stale contextual support')end
      if edge.visible then shown[#shown+1]=edge end
    end
    assert(#shown==expected,'Wrong metadata-derived connector visibility')
    if not pixels then return end
    for i,edge in ipairs(shown)do for _,a in ipairs(rects[edge])do
      assert(a.width==2 or a.height==2,'Stroke not2px')
      for _,card in ipairs(cards)do if overlap(a,card.rect)then assert((card.id==edge.from or card.id==edge.to)and boundary(a,card.rect),'Stroke crosses card/name '..edge.from..' -> '..edge.to..' / '..card.id)end end
      for _,heading in ipairs(headings)do assert(not overlap(a,heading),'Stroke crosses heading')end
      for j=i+1,#shown do for _,b in ipairs(rects[shown[j]])do assert(not overlap(a,b),'Unrelated emitted strokes overlap '..edge.from..' -> '..edge.to..' / '..shown[j].from..' -> '..shown[j].to)end end
    end end
  end
  local function borders()
    for _,node in ipairs(state.tree.nodes)do local widget=mod.getNodeWidget(node.id)
      assert(colortostring(widget:getBorderTopColor())==colortostring(tocolor(widget.previewBorderColor)),'Focus changed semantic border '..node.id)
      if node.type=='capstone'and(state.ranks[node.id]or 0)==0 and node.id~=state.selected then assert(widget.previewBorderColor~='#b7a471'and widget.previewBorderColor~='#b39255','Untrained cap has learned gold')end
    end
  end
  local selected=state.selected;local savedRanks,savedDraft={},{}
  for id,rank in pairs(state.ranks)do savedRanks[id]=rank end;for id,rank in pairs(state.draft)do savedDraft[id]=rank end
  local function restore()
    state.ranks={};state.draft={};for id,rank in pairs(savedRanks)do state.ranks[id]=rank end;for id,rank in pairs(savedDraft)do state.draft[id]=rank end
  end
  -- Exercise real widget callbacks. Pure changeRank calls cannot catch an
  -- enabled-state/nil-fallback error in the inspector's Add/Remove controls.
  local buttonCases=0
  local function equalFixture()
    for id,rank in pairs(savedRanks)do assert(state.ranks[id]==rank,'UI button changed saved ranks '..id)end
    for id,rank in pairs(savedDraft)do assert(state.draft[id]==rank,'UI button failed to restore draft '..id)end
    assert(not state.pending,'Draft button unexpectedly sent a request')
  end
  local function button(id)return assert(window:recursiveGetChildById(id),'Missing actual UI button '..id)end
  local function click(id)local widget=button(id);assert(widget:isEnabled(),'Actual UI button disabled '..id);signalcall(widget.onClick,widget)end
  local function editable(role)
    for _,node in ipairs(state.tree.nodes)do if node.role==role and(state.draft[node.id]or 0)<node.maxRank then
      local candidate={};for id,rank in pairs(state.draft)do candidate[id]=rank end;candidate[node.id]=(candidate[node.id]or 0)+1
      if not mod.validateDraft(candidate)then return node end
    end end
  end
  assert(state.points>0 and not state.pending,'Active editable native fixture required')
  for _,role in ipairs({'foundationMinor','coreMajor'})do
    local node=assert(editable(role),'No editable '..role..' in native fixture');mod.selectNode(node.id)
    local original=state.draft[node.id]or 0
    assert(button('addRank'):isEnabled(),'Eligible '..role..' has disabled Add rank')
    assert(not window:recursiveGetChildById('nodeAvailability'):getText():find('Choose a talent',1,true),'Selected talent shown as unselected')
    click('addRank');assert(state.draft[node.id]==original+1,'Actual Add callback did not add one draft rank')
    assert(button('removeRank'):isEnabled()and button('applyButton'):isEnabled()and button('discardButton'):isEnabled(),'Changed draft lacks Remove/Apply/Undo affordances')
    click('removeRank');equalFixture()
    click('addRank');click('discardButton');equalFixture()
    assert(not button('applyButton'):isEnabled()and not button('discardButton'):isEnabled(),'Undo left unsaved controls enabled')
    buttonCases=buttonCases+2
  end
  local locked
  for _,node in ipairs(state.tree.nodes)do if node.role=='advancedMajor'and(state.draft[node.id]or 0)<node.maxRank then
    local candidate={};for id,rank in pairs(state.draft)do candidate[id]=rank end;candidate[node.id]=(candidate[node.id]or 0)+1
    local reason=mod.validateDraft(candidate);if reason and reason:find('prerequisites',1,true)then locked=node;break end
  end end
  assert(locked,'Missing locked advanced fixture');mod.selectNode(locked.id)
  assert(not button('addRank'):isEnabled(),'Locked talent exposes enabled Add rank')
  equalFixture();buttonCases=buttonCases+1
  local cases=0
  if selectionCases then
    for _,node in ipairs(state.tree.nodes)do mod.selectNode(node.id);visible(expectedVisible(node.id),false);borders();cases=cases+1 end
    mod.selectNode(state.tree.topology.coreOrder[1]);visible(expectedVisible(state.selected),true)
    for _,path in ipairs(state.tree.topology.paths)do
      for _,rank in ipairs({0,1})do
        state.draft[path.minorId]=2;state.draft[path.secondaryCoreId]=rank;mod.selectNode(path.advancedId);visible(expectedVisible(state.selected),rank==0)
        local support;for _,edge in ipairs(groups)do if edge.kind=='support'and edge.to==path.advancedId then support=edge end end
        assert(support and support.visible and support.view.met==(rank==1)and support.view.color==(rank==1 and'#a8c4cc'or'#a18a74'),'Mandatory support contrast')
        cases=cases+1
      end
      restore()
    end
  end
  restore()
  for _,path in ipairs(state.tree.topology.paths)do
    mod.selectNode(path.advancedId);mod.setDetailTab('talent');visible(expectedVisible(state.selected),false);borders()
    local node=state.nodes[path.advancedId];local rank=state.draft[node.id]or 0;local text=window:recursiveGetChildById('nodeDescription'):getText()
    assert(text:find('Both required',1,true),'AND summary absent')
    for _,r in ipairs(node.requires.all)do assert(text:find(state.nodes[r.id].name..' '..(state.draft[r.id]or 0)..'/'..r.rank,1,true),'Required current/rank absent')end
    local effects=node.benefits or node.ranks;if rank>0 then assert(text:find(effects[rank],1,true),'Current effect stale')end;if rank<node.maxRank then assert(text:find(effects[rank+1],1,true),'Next effect stale')end
    local mechanics=text:find('\n\nHow it works',1,true);local prefix=mechanics and text:sub(1,mechanics-1)or text
    local description=window:recursiveGetChildById('nodeDescription');local measure=g_ui.createWidget('PassiveRequirement',window);measure:setWidth(description:getWidth());measure:setText(prefix);measure:hide()
    local view=window:recursiveGetChildById('detailScroll'):getPaddingRect();assert(description:getY()+measure:getTextSize().height<=view.y+view.height,'Initial current/next/AND clipped '..node.name);measure:destroy()
    mod.setDetailTab('requirements');local box=window:recursiveGetChildById('nodeRequirements')
    for _,r in ipairs(node.requires.all)do local row=assert(box:recursiveGetChildById('progress_'..r.id));assert(row:getText()==(state.draft[r.id]or 0)..'/'..r.rank,'AND badge mismatch');local link=assert(box:recursiveGetChildById('inspect_'..r.id));signalcall(link.onClick,link);assert(state.selected==r.id,'Requirement row navigation failed');mod.selectNode(path.advancedId);mod.setDetailTab('requirements')end
  end
  for _,path in ipairs(state.tree.topology.optionalPaths)do
    if contextualOptional[path.optionalId]then
      mod.selectNode(path.optionalId);visible(expectedVisible(state.selected),true)
      mod.setDetailTab('requirements');local box=window:recursiveGetChildById('nodeRequirements')
      for _,source in ipairs(path.coreIds)do
        local incoming;for _,edge in ipairs(groups)do if edge.from==source and edge.to==path.optionalId then incoming=edge end end
        assert(incoming and incoming.kind=='contextualAlternative'and incoming.visible,'Inspected optional OR input absent')
        local link=assert(box:recursiveGetChildById('inspect_'..source),'Named optional prerequisite missing');assert(link:isVisible(),'Optional core row hidden')
        signalcall(link.onClick,link);assert(state.selected==source,'Optional prerequisite navigation failed');visible(expectedVisible(state.selected),false)
        for _,edge in ipairs(groups)do if edge.kind=='contextualAlternative'then assert(not edge.visible,'Long optional path leaked after navigation')end end
        mod.selectNode(path.optionalId);mod.setDetailTab('requirements')
      end
    end
  end
  for _,id in ipairs({'typeLegendMinor','typeLegendMajor','typeLegendCapstone','capstoneHint'})do assert(not window:recursiveGetChildById(id),'Legend/hint leaked')end
  if state.mode=='permanent'then assert(not window:recursiveGetChildById('endButton'):isVisible(),'End test leaked to permanent');local header=window:recursiveGetChildById('testLabel'):getText();assert(not header:find('TEST',1,true)and not header:find('preview',1,true),'Test copy leaked to permanent')end
  restore();mod.selectNode(selected or state.tree.topology.routeOrder[1]);mod.setDetailTab('talent');borders()
  for id,rank in pairs(savedRanks)do assert(state.ranks[id]==rank,'Saved fixture leaked')end;for id,rank in pairs(savedDraft)do assert(state.draft[id]==rank,'Draft fixture leaked')end
  print('PASSIVES_CONNECTED_UI_OK class='..state.tree.id..' size='..root.width..'x'..root.height..' logical=36 overview='..overview..' inspectedAdvanced='..(overview+1)..' actualRankButtonCases='..buttonCases..' glyphs=32 names=true strokeIntersections=0 strokeOverlaps=0 bothRequiredVisible=true currentNext=true focusBorders=true fixtureRestored=true selectionCases='..cases)
  return true
end
