-- Presentation contracts only. Server catalogs own every effect and prerequisite.
PassivesTree = {}
local T = PassivesTree
local schemas = {
  [1] = {nodes=17,minor=8,major=6,capstone=3,maxY=400},
  [2] = {nodes=29,minor=14,major=12,capstone=3,maxY=734}
}
function T.schema(tree)
  local version=tree.schemaVersion or 1
  if tree.catalogVersion~=nil and tree.catalogVersion~=version or version==2 and tree.catalogVersion~=2 then return nil end
  local schema=schemas[version];if not schema then return nil end
  if tree.nodeCount~=nil and tree.nodeCount~=schema.nodes or version==2 and tree.nodeCount~=schema.nodes then return nil end
  return schema,version
end
local function exactAll(actual,expected)
  local count=0;for _ in pairs(expected)do count=count+1 end
  if #(actual or{})~=count then return false end
  local seen={};for _,r in ipairs(actual or{})do if seen[r.id]or expected[r.id]~=(r.rank or 1)then return false end;seen[r.id]=true end
  return true
end
function T.validate(tree,nodes)
  local schema,version=T.schema(tree);if not schema then return false end
  if version==1 then return true end
  local topology=tree.topology;if type(topology)~='table'then return false end
  if type(tree.branchGroups)~='table'or #tree.branchGroups~=4 then return false end
  local tierSpecs={
    {'foundationMinorIds',8,'foundationMinor','minor',1}, {'coreMajorIds',4,'coreMajor','major'},
    {'optionalMajorIds',2,'optionalMajor','major'}, {'advancedMajorIds',6,'advancedMajor','major',18},
    {'midMinorIds',6,'routeMinor','minor',24}, {'capstoneIds',3,'capstone','capstone',15}
  }
  local seen={}
  for _,spec in ipairs(tierSpecs)do
    local ids=topology[spec[1]];if type(ids)~='table'or #ids~=spec[2]then return false end
    for index,id in ipairs(ids)do
      local node=nodes[id];if not node or seen[id]or node.role~=spec[3]or node.type~=spec[4]then return false end
      seen[id]=true
    end
  end
  for i,node in ipairs(tree.nodes)do
    local role=i<=8 and'foundationMinor'or i<=12 and'coreMajor'or i<=14 and'optionalMajor'or i<=17 and'capstone'or i<=23 and'advancedMajor'or'routeMinor'
    if node.role~=role then return false end
  end
  local branches={};for _,branch in ipairs(tree.branchGroups)do branches[branch.id]=branch end
  if type(topology.coreOrder)~='table'or #topology.coreOrder~=4 or type(topology.branchOrder)~='table'or #topology.branchOrder~=4 then return false end
  local visualSeen={};for i,id in ipairs(topology.coreOrder)do local branch=branches[topology.branchOrder[i]];if visualSeen[id]or not nodes[id]or nodes[id].role~='coreMajor'or not branch or branch.majorId~=id then return false end;visualSeen[id]=true end
  if type(topology.routeOrder)~='table'or #topology.routeOrder~=6 or type(topology.capstoneOrder)~='table'or #topology.capstoneOrder~=3 then return false end
  local routeOrder,capOrder={},{}
  for _,id in ipairs(topology.routeOrder)do if not nodes[id]or nodes[id].role~='advancedMajor'or routeOrder[id]then return false end;routeOrder[id]=true end
  for _,id in ipairs(topology.capstoneOrder)do if not nodes[id]or nodes[id].role~='capstone'or capOrder[id]then return false end;capOrder[id]=true end
  if type(topology.paths)~='table'or #topology.paths~=6 then return false end
  local paths,minors={},{}
  local expectedEdges={}
  local function edge(a,b)expectedEdges[a..':'..b]=true end
  for _,branch in ipairs(tree.branchGroups or{})do for _,id in ipairs(branch.minorIds)do edge(id,branch.majorId)end end
  if type(topology.optionalPaths)~='table'or #topology.optionalPaths~=2 then return false end
  local optionalSeen={}
  for _,path in ipairs(topology.optionalPaths)do
    local node=nodes[path.optionalId];if not node or node.role~='optionalMajor'or optionalSeen[node.id]or type(path.coreIds)~='table'or #path.coreIds~=2 or path.coreIds[1]==path.coreIds[2]then return false end
    local actual={};for _,group in ipairs((node.requires or{}).any or{})do for _,r in ipairs(group.all or{})do if nodes[r.id].role=='coreMajor'then actual[r.id]=true end end end
    for _,id in ipairs(path.coreIds)do if not actual[id]or nodes[id].role~='coreMajor'then return false end;actual[id]=nil;edge(id,node.id)end
    if next(actual)then return false end;optionalSeen[node.id]=true
  end
  for _,path in ipairs(topology.paths)do
    local advanced,minor,own,secondary,cap=nodes[path.advancedId],nodes[path.minorId],nodes[path.ownCoreId],nodes[path.secondaryCoreId],nodes[path.capstoneId]
    if not advanced or not minor or not own or not secondary or not cap or paths[path.advancedId]or minors[path.minorId]or advanced.role~='advancedMajor'or minor.role~='routeMinor'or own.role~='coreMajor'or secondary.role~='coreMajor'or own==secondary or cap.role~='capstone'then return false end
    if not exactAll((minor.requires or{}).all,{[own.id]=2})or (minor.requires or{}).any or (minor.requires or{}).spent then return false end
    if not exactAll((advanced.requires or{}).all,{[minor.id]=2,[secondary.id]=1})or (advanced.requires or{}).any or (advanced.requires or{}).spent then return false end
    paths[path.advancedId]=path;minors[path.minorId]=true
    edge(own.id,minor.id);edge(minor.id,advanced.id);edge(secondary.id,advanced.id);edge(advanced.id,cap.id)
  end
  for i,id in ipairs(topology.routeOrder)do
    local ownIndices={1,2,2,3,3,4};local path=paths[id];if not path or path.capstoneId~=topology.capstoneOrder[math.floor((i-1)/2)+1]or path.ownCoreId~=topology.coreOrder[ownIndices[i]]then return false end
  end
  for index,id in ipairs(topology.capstoneOrder)do
    local requires=nodes[id].requires or{};local pair={topology.routeOrder[index*2-1],topology.routeOrder[index*2]}
    if requires.spent~=15 or #(requires.all or{})~=0 or type(requires.any)~='table'or #requires.any~=2 then return false end
    local found={};for _,group in ipairs(requires.any)do if #(group.all or{})~=1 then return false end;local r=group.all[1];if (r.id~=pair[1]and r.id~=pair[2])or r.rank~=1 or found[r.id]then return false end;found[r.id]=true end
  end
  if type(tree.edges)~='table'or #tree.edges~=36 then return false end
  for _,e in ipairs(tree.edges)do local key=e.from..':'..e.to;if not expectedEdges[key]then return false end;expectedEdges[key]=nil end
  if next(expectedEdges)then return false end
  return true
end
function T.render(tree)
  local topology=tree.topology;local positions,names,edges,headings={},{},{},{}
  local paths={};for _,path in ipairs(topology.paths)do paths[path.advancedId]=path end
  local function place(id,cx,y,width,height,nameWidth)
    positions[id]={x=cx-width/2,y=y,width=width,height=height};names[id]={x=cx-nameWidth/2,y=y+height,width=nameWidth,height=30}
  end
  local branchMap={};for _,branch in ipairs(tree.branchGroups)do branchMap[branch.id]=branch end
  local visualBranches={};for i,id in ipairs(topology.branchOrder)do visualBranches[i]=branchMap[id]end
  for i,branch in ipairs(visualBranches)do
    for j,id in ipairs(branch.minorIds)do place(id,30+(i-1)*120+(j-1)*60,646,44,44,58)end
    headings[#headings+1]={id='area_'..branch.id,text=branch.label,x=31+(i-1)*120,y=628,width=58,height=16}
  end
  local cores={{4,72,76},{152,96,100},{256,72,76},{404,72,76}}
  for i,id in ipairs(topology.coreOrder)do local p=cores[i];place(id,p[1]+p[2]/2,484,p[2],52,p[3])end
  for i,id in ipairs(topology.optionalMajorIds)do place(id,i==1 and 114 or 366,484,60,52,68)end
  for i,id in ipairs(topology.routeOrder)do local cx=40+(i-1)*80;place(id,cx,162,68,52,76);place(paths[id].minorId,cx,310,44,44,68)end
  for i,id in ipairs(topology.capstoneOrder)do place(id,80+(i-1)*160,24,64,64,108)end
  local function edge(a,b,points,kind)edges[#edges+1]={from=a,to=b,waypoints=points,kind=kind or'required',segments={}}end
  local foundationPorts={{30,68},{164,224},{272,310},{416,450}}
  for i,branch in ipairs(visualBranches)do for j,id in ipairs(branch.minorIds)do
    local cx=30+(i-1)*120+(j-1)*60;local port=foundationPorts[i][j];local bus=604+(j-1)*12
    edge(id,branch.majorId,cx==port and{{cx,646},{cx,566}}or{{cx,646},{cx,bus},{port,bus},{port,566}})
  end end
  local coreIndices={};for i,id in ipairs(topology.coreOrder)do coreIndices[id]=i end
  for i,path in ipairs(topology.optionalPaths)do local id=path.optionalId;local p=positions[id]
    -- Keep an adjacent OR choice visible; reveal a long cross-column choice only
    -- while its optional target is inspected. Both inputs use the same policy.
    local contextual=math.abs(coreIndices[path.coreIds[1]]-coreIndices[path.coreIds[2]])>1
    local kind=contextual and'contextualAlternative'or'alternative'
    for _,source in ipairs(path.coreIds)do
    local cp=positions[source];local left=cp.x+cp.width/2<p.x+p.width/2;local sourceX=left and cp.x+cp.width or cp.x;local targetX=left and p.x or p.x+p.width
    if math.abs(sourceX-targetX)<=12 then edge(source,id,{{sourceX,510},{targetX,510}},kind)
    else
      local port=cp.x+20;local target=p.x+20;local bus=i==1 and 458 or 446
      edge(source,id,{{port,484},{port,bus},{target,bus},{target,484}},kind)
    end
  end end
  local ports,buses={40,176,224,276,308,440},{400,412,400,412,424,400}
  local supportPorts={[topology.coreOrder[1]]=64,[topology.coreOrder[2]]=160,[topology.coreOrder[3]]=320,[topology.coreOrder[4]]=416}
  for i,id in ipairs(topology.routeOrder)do
    local p=paths[id];local cx=40+(i-1)*80;local port,bus=ports[i],buses[i]
    edge(p.ownCoreId,p.minorId,port==cx and{{port,484},{cx,384}}or{{port,484},{port,bus},{cx,bus},{cx,384}})
    edge(p.minorId,id,{{cx,310},{cx,244}})
    local source=supportPorts[p.secondaryCoreId];local gutter=i<=3 and 1 or 479;local target=i<=3 and cx+18 or cx-18
    edge(p.secondaryCoreId,id,{{source,484},{source,476},{gutter,476},{gutter,270},{target,270},{target,244}},'support')
    edge(id,p.capstoneId,{{cx,162},{cx,118}},'alternative')
  end
  local main={};for _,e in ipairs(edges)do if e.kind~='support'and e.kind~='contextualAlternative'then for i=2,#e.waypoints do main[#main+1]={e.waypoints[i-1],e.waypoints[i]}end end end
  for _,e in ipairs(edges)do
    local alternative=e.kind=='alternative'or e.kind=='contextualAlternative'
    local function stroke(a,b)
      local vertical=a[1]==b[1];local lo=math.min(vertical and a[2]or a[1],vertical and b[2]or b[1]);local hi=math.max(vertical and a[2]or a[1],vertical and b[2]or b[1]);local intervals={{lo,hi}}
      if (e.kind=='support'or alternative)and not vertical then
        local cuts={};for _,s in ipairs(main)do local c,d=s[1],s[2];if c[1]==d[1]and c[1]>lo and c[1]<hi and a[2]>=math.min(c[2],d[2])-1 and a[2]<=math.max(c[2],d[2])+1 then cuts[#cuts+1]={c[1]-6,c[1]+6}end end
        table.sort(cuts,function(c,d)return c[1]<d[1]end);local cursor=lo;intervals={};for _,cut in ipairs(cuts)do if cut[1]>cursor then intervals[#intervals+1]={cursor,math.min(cut[1],hi)}end;cursor=math.max(cursor,cut[2])end;if cursor<hi then intervals[#intervals+1]={cursor,hi}end
      end
      local function piece(start,finish)if finish>start then e.segments[#e.segments+1]={x=vertical and a[1]-1 or start-1,y=vertical and start-1 or a[2]-1,width=vertical and 2 or finish-start+2,height=vertical and finish-start+2 or 2}end end
      for _,interval in ipairs(intervals)do if alternative then for start=interval[1],interval[2]-1,8 do piece(start,math.min(start+4,interval[2]))end else piece(interval[1],interval[2])end end
    end
    for i=2,#e.waypoints do stroke(e.waypoints[i-1],e.waypoints[i])end
    local last,previous=e.waypoints[#e.waypoints],e.waypoints[#e.waypoints-1];local dx=last[1]==previous[1]and 0 or last[1]>previous[1]and 1 or -1;local dy=last[2]==previous[2]and 0 or last[2]>previous[2]and 1 or -1
    for _,side in ipairs({-1,1})do e.segments[#e.segments+1]={x=last[1]-dx*3+(dy~=0 and side*2 or 0)-1,y=last[2]-dy*3+(dx~=0 and side*2 or 0)-1,width=2,height=2,arrow=true}end
  end
  return {positions=positions,nameplates=names,edges=edges,areaHeadings=headings,canvas={width=480,height=734}}
end
function T.connectorState(edge,selected,draft,saved,nodes,conditions)
  local node=nodes[edge.to];local met=false;local neutral=false
  for _,c in ipairs(conditions or{})do
    local member,total,count=false,0,0;for _,id in ipairs(c.ids or{})do member=member or id==edge.from;total=total+(draft[id]or 0);if(draft[id]or 0)>=(c.rank or 1)then count=count+1 end end
    if member and c.kind=='sum'then met=total>=c.required;neutral=met and(draft[edge.from]or 0)==0
    elseif member and c.kind=='any_rank'then met=(draft[edge.from]or 0)>=c.rank;neutral=count>=c.required and not met end
  end
  local requires=node.requires or{}
  for _,r in ipairs(requires.all or{})do if r.id==edge.from then met=(draft[edge.from]or 0)>=(r.rank or 1)end end
  local anyReady=false
  for _,route in ipairs(requires.any or{})do
    local ready=true;for _,r in ipairs(route.all or{})do if(draft[r.id]or 0)<(r.rank or 1)then ready=false end;if r.id==edge.from and(draft[r.id]or 0)>=(r.rank or 1)then met=true end end
    anyReady=anyReady or ready
  end
  if anyReady and not met then neutral=true end
  local inspected=edge.to==selected and not neutral;local learned=(saved[edge.from]or 0)>0 and(saved[edge.to]or 0)>0 and met
  return {visible=(edge.kind~='support'and edge.kind~='contextualAlternative')or edge.to==selected,met=met,neutral=neutral,color=inspected and met and'#a8c4cc'or learned and'#c5ad70'or inspected and'#a18a74'or'#938b7b',priority=inspected and met and 3 or learned and 2 or inspected and 1 or 0}
end
