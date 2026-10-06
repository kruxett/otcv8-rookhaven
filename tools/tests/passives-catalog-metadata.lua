-- Standalone LuaJIT from the sibling server root. No DB/game mutations.
Game={configurePassiveClasses=function()return true end}
dofile('../otcv8-rookhaven/modules/corelib/json.lua')
dofile('data/lib/passives/test.lua')
dofile('../otcv8-rookhaven/modules/game_passives/passivetree.lua')
local function read(path)local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s:gsub('\r\n','\n')end
local source=read('../otcv8-rookhaven/modules/game_passives/passives.lua')
local exact=assert(source:match('(local function groupMet.-)\nlocal function draftChanged'),'Client validator extraction failed')
local summary=assert(source:match('(local function groupSignature.-)\nlocal function branchInfo'),'Client summary extraction failed')
local factory=assert(loadstring([[local state=...
local function spent(r)local n=0;for _,v in pairs(r)do n=n+v end;return n end
local function isPermanent()return false end
local function nameFor(id)return state.nodes[id].name end
]]..exact..summary..[[
return {validate=validationError,met=requirementsMet,summary=summaryConditions}
]],'@actual-client-catalog-proof'))
local function sum(r)local n=0;for _,v in pairs(r)do n=n+v end;return n end
local function copy(r)local n={};for id,v in pairs(r)do n[id]=v end;return n end
local function put(r,id,v)r[id]=math.max(r[id]or 0,v)end
local report={trees={},cases=0,prefixes=0,rejections=0}
for _,treeId in ipairs(PassiveTest.order)do
 local tree=assert(PassiveTest.trees[treeId]);assert(tree.schemaVersion==2 and tree.catalogVersion==2)
 local nodes={};for _,n in ipairs(tree.nodes)do assert(not nodes[n.id]);nodes[n.id]=n end
 assert(#tree.nodes==29 and #tree.edges==36,treeId..' wrong topology size')
 assert(PassivesTree.validate(tree,nodes),treeId..' client topology contract rejected')
 local state={nodes=nodes,ranks={},points=24};local client=factory(state)
 local counts={minor=0,major=0,capstone=0}
 for _,n in ipairs(tree.nodes)do
  counts[n.type]=counts[n.type]+1
  assert(client.summary(n,nodes),treeId..' '..n.id..' summary disagrees with literal prerequisites')
  assert(#n.ranks==n.maxRank and n.maxRank==({minor=5,major=3,capstone=1})[n.type])
 end
 assert(counts.minor==14 and counts.major==12 and counts.capstone==3)
 local topology=tree.topology;local groups={}
 for _,g in ipairs(tree.branchGroups)do groups[g.majorId]=g;assert(g.unlockPoints==4 and g.requiredMinorPoints==4)end
 -- Independent arithmetic evaluator; does not read node.requires or UI summaries.
 local paths,capPaths={},{}
 for _,p in ipairs(topology.paths)do
  paths[p.minorId]=p;paths[p.advancedId]=p
  capPaths[p.capstoneId]=capPaths[p.capstoneId]or{};table.insert(capPaths[p.capstoneId],p)
 end
 local function independent(r,budget)
  if sum(r)>budget then return false end
  local capCount=0
  for id,v in pairs(r)do
   local n=nodes[id];if not n or type(v)~='number'or v<0 or v>n.maxRank or v~=math.floor(v)then return false end
   if v>0 then
    if n.role=='coreMajor'then local g=groups[id];if(r[g.minorIds[1]]or 0)+(r[g.minorIds[2]]or 0)<4 then return false end
    elseif n.role=='optionalMajor'then
     local a,b=id=='major_tactical'and groups.major_precision or groups.major_guard,id=='major_tactical'and groups.major_pressure or groups.major_recovery
     if(r[a.minorIds[1]]or 0)+(r[a.minorIds[2]]or 0)<2 or(r[b.minorIds[1]]or 0)+(r[b.minorIds[2]]or 0)<2 or math.max(r[a.majorId]or 0,r[b.majorId]or 0)<1 then return false end
    elseif n.role=='routeMinor'then if(r[paths[id].ownCoreId]or 0)<2 then return false end
    elseif n.role=='advancedMajor'then local p=paths[id];if(r[p.minorId]or 0)<2 or(r[p.secondaryCoreId]or 0)<1 then return false end
    elseif n.role=='capstone'then
     capCount=capCount+1;if sum(r)-v<15 then return false end
     local met=false;for _,p in ipairs(capPaths[id])do if(r[p.advancedId]or 0)>=1 then met=true end end;if not met then return false end
    elseif n.role~='foundationMinor'then error('Unknown role '..tostring(n.role))end
   end
  end
  return capCount<=1
 end
 local function check(r,budget,legal,label)
  report.cases=report.cases+1;state.points=budget
  assert(independent(r,budget)==legal,treeId..' independent expectation '..label)
  local err=client.validate(r);assert((err==nil)==legal,treeId..' UI parity '..label..': '..tostring(err))
  if not legal then report.rejections=report.rejections+1 end
 end
 local function foundation(r,style)
  for id,g in pairs(groups)do if(r[id]or 0)>0 then local a=style or 3;put(r,g.minorIds[1],a);put(r,g.minorIds[2],4-a)end end
 end
 local function closure(mask,style)
  local r={}
  for i,p in ipairs(topology.paths)do if math.floor(mask/2^(i-1))%2==1 then put(r,p.ownCoreId,2);put(r,p.secondaryCoreId,1);put(r,p.minorId,2);put(r,p.advancedId,1)end end
  foundation(r,style);return r
 end
 local function pad(r,total)
  r=copy(r);for _,id in ipairs(topology.foundationMinorIds)do local add=math.min(nodes[id].maxRank-(r[id]or 0),total-sum(r));if add>0 then r[id]=(r[id]or 0)+add end end
  assert(sum(r)==total);return r
 end
 local record={id=treeId,witnesses={},readiness={}}
 for i,p in ipairs(topology.paths)do
  for split=0,4 do
   local r=closure(2^(i-1),split);assert(sum(r)==14)
   r=pad(r,15);r[p.capstoneId]=1;check(r,16,true,'route '..i..' split '..split)
   local prefix={};local purchaseOrder={}
   for _,field in ipairs({'foundationMinorIds','coreMajorIds','midMinorIds','advancedMajorIds','optionalMajorIds','capstoneIds'})do for _,id in ipairs(topology[field])do purchaseOrder[#purchaseOrder+1]=id end end
   for _,id in ipairs(purchaseOrder)do for rank=1,r[id]or 0 do prefix[id]=rank;check(prefix,16,true,'purchase prefix '..id);report.prefixes=report.prefixes+1 end end
   if split==3 then record.witnesses[#record.witnesses+1]={path=i,cap=p.capstoneId,ranks=r,spent=sum(r)}end
  end
  local r=record.witnesses[i].ranks
  local short=copy(r);short[p.minorId]=1;check(short,24,false,'route minor below two')
  short=copy(r);short[p.ownCoreId]=1;check(short,24,false,'own core below two')
  short=copy(r);short[p.secondaryCoreId]=0;check(short,24,false,'secondary core absent')
  short=copy(r);short[p.advancedId]=0;check(short,24,false,'cap bypass')
  short=closure(2^(i-1),3);short[p.capstoneId]=1;check(short,24,false,'cap total below sixteen')
  check(r,15,false,'ordinary budget fifteen')
  short=copy(r);short[topology.capstoneIds[i%3+1]]=1;if topology.capstoneIds[i%3+1]==p.capstoneId then short[topology.capstoneIds[(i+1)%3+1]]=1 end;check(short,24,false,'second active cap')
  short=copy(r);short[p.advancedId]=4;check(short,24,false,'major above three')
  short=copy(r);short['unknown_node']=1;check(short,24,false,'unknown node')
 end
 for _,g in ipairs(tree.branchGroups)do for a=0,5 do for b=0,5 do
  local r={[g.minorIds[1]]=a,[g.minorIds[2]]=b,[g.majorId]=1};check(r,24,a+b>=4,'foundation '..a..'+'..b)
 end end end
 -- Exhaustive endpoint subsets, with closures derived from the path registry.
 -- Determine simultaneous eligibility, keeping exactly one selected Capstone.
 for wanted=1,7 do
  local best,bestRanks
  for mask=0,63 do
   local r=closure(mask);check(r,1000,true,'closure '..mask)
   r=pad(r,math.max(15,sum(r)));local met=true
   for index,cap in ipairs(topology.capstoneIds)do if math.floor(wanted/2^(index-1))%2==1 then local trial=copy(r);trial[cap]=1;if not independent(trial,1000)then met=false end end end
   if met and(not best or sum(r)<best)then best,bestRanks=sum(r),r end
  end
  assert(best,'no closure for cap set')
  local active;for index,cap in ipairs(topology.capstoneIds)do if math.floor(wanted/2^(index-1))%2==1 then active=active or cap end end
  bestRanks[active]=1;check(bestRanks,1000,true,'hybrid minimum')
  if wanted==1 or wanted==2 or wanted==4 then assert(best+1==16,'first cap no longer level40')end
  if wanted==7 then assert(best+1>24,'all three cap lineages fit maximum budget')end
  record.readiness[#record.readiness+1]={mask=wanted,totalWithOneCap=best+1,ranks=bestRanks}
 end
 report.trees[#report.trees+1]=record
 print('PASSIVES_CONNECTED_CATALOG_TREE_OK '..treeId)
end
local out=arg[1]or'../otcv8-rookhaven/out/passives-connected/catalog-proof.json'
local f=assert(io.open(out,'wb'));f:write(json.encode(report));f:close()
print('PASSIVES_CATALOG_METADATA_OK trees=6 nodes=174 logicalEdges=216 cases='..report.cases..' purchasePrefixes='..report.prefixes..' rejections='..report.rejections)