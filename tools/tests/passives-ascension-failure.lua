-- Standalone LuaJIT only, from ../Rookhaven. No game, DB, network or process launch.
-- Executes the actual Nameless dialogue/helper/transaction with mocked engine
-- callbacks. Native NOLIMIT/stacking/save behavior is source-backed separately;
-- this is not a native item-serializer or real database rollback test.
assert(g_game==nil and Game==nil,'Run with standalone LuaJIT')
local client=arg[1]or'C:/GitRepos/kruxett/otcv8-rookhaven'
dofile(client..'/modules/corelib/json.lua')
local checks,cases=0,{}
local function check(value,reason)assert(value,reason);checks=checks+1 end
local function copy(value)
 if type(value)~='table'then return value end
 local out={};for k,v in pairs(value)do if type(v)~='function'then out[k]=copy(v)end end;return out
end
local function read(path)local f=assert(io.open(path,'rb'));local value=f:read('*a');f:close();return value end
function Position(x,y,z)
 return{x=x,y=y,z=z,getDistance=function(a,b)return math.max(math.abs(a.x-b.x),math.abs(a.y-b.y))end,
  isSightClear=function()return true end,sendMagicEffect=function()end}
end
CONST_SLOT_HEAD=1;CONST_SLOT_NECKLACE=2;CONST_SLOT_BACKPACK=3;CONST_SLOT_ARMOR=4;CONST_SLOT_RIGHT=5
CONST_SLOT_LEFT=6;CONST_SLOT_LEGS=7;CONST_SLOT_FEET=8;CONST_SLOT_RING=9;CONST_SLOT_AMMO=10
CONST_ME_TELEPORT=1;MESSAGE_EVENT_ADVANCE=1;CALLBACK_MESSAGE_DEFAULT=1;CALLBACK_ONRELEASEFOCUS=2
PS={Quest_TheAscent_Progress=100,Quest_TheAscent_SkillFocus=101,Player_TheAscent_AscentPopupShown=102,
 NPC_EldricBookOfArcanisInformed=103,Player_AscensionFirstLoginPopup=104,Player_SecondAscensionProgress=105}
local handler,callback,current,events,fixture
KeywordHandler={new=function()return{addGreetKeyword=function()end,addAliasKeyword=function()end,addFarewellKeyword=function()end}end}
NpcHandler={new=function()
 handler={topic={},talkRadius=4,say=function(_,message)fixture.dialogue[#fixture.dialogue+1]=message end,
  isFocused=function()return true end,isInRange=function()return true end,addModule=function()end,
  setCallback=function(_,kind,fn)if kind==CALLBACK_MESSAGE_DEFAULT then callback=fn end end}
 return handler
end}
NpcSystem={parseParameters=function()end};FocusModule={new=function()return{}end}
function msgcontains(message,part)return message:find(part,1,true)~=nil end
function Npc()return{getId=function()return 1 end,getPosition=function()return Position(32337,32208,4)end}end
function Vocation(id)return{getId=function()return id end,getRequiredSkillTries=function()return id==3 and 1000 or 100 end,
 getRequiredManaSpent=function()return id==3 and 1000 or 100 end}end
function Player(id)return current and current.online and(id==current.id or id==current.name)and current or nil end
function addEvent(fn,delay,...)events[#events+1]={fn=fn,args={...},delay=delay};return #events end
ClassChoice=nil
PassiveTest={nodeCount=29,classFocus={reaver=2},classAliases={},order={'reaver'},className=function()return'Reaver'end,
 progression={unlockLevel=1,startingPoints=3,levelsPerPoint=3,maxPoints=24},preparePermanent=function()return true end,
 state=function()return{active=false,capable=true,mode='permanent',classLocked=false}end}
ClassSpells={namesForClass=function(tree)check(tree=='reaver','Wrong starter class');return{'Cleaving Arc','Rend'}end}
AscensionAnnouncements={announce=function()fixture.announcements=fixture.announcements+1 end}
result={getNumber=function(row,key)return row[key]or 0 end,free=function()fixture.freed=fixture.freed+1 end}
local function activeRecord()return fixture.transaction or fixture.saved end
local function fails(stage)return fixture.fail==stage end
db={escapeString=function(value)return"'"..value.."'"end}
function db.storeQuery(sql)
 fixture.queries[#fixture.queries+1]=sql
 if sql:find('SELECT `save`',1,true)then if fails('saving-query')then return false end;return{save=fixture.saving}end
 if sql:find('FOR UPDATE',1,true)then if fails('locked-player')then return false end;return{vocation=activeRecord().vocation}end
 error('Unexpected SELECT '..sql)
end
function db.query(sql)
 fixture.queries[#fixture.queries+1]=sql
 if sql=='START TRANSACTION'then fixture.begin=fixture.begin+1;if fails('begin')then return false end;check(not fixture.transaction,'Nested transaction');fixture.transaction=copy(fixture.saved);return true end
 if sql=='ROLLBACK'then fixture.rollback=fixture.rollback+1;fixture.transaction=nil;return true end
 if sql=='COMMIT'then if fails('commit')then return false end;check(fixture.transaction,'COMMIT without transaction');fixture.saved=fixture.transaction;fixture.transaction=nil;fixture.commits=fixture.commits+1;return true end
 local row=assert(fixture.transaction,'Durable class writes outside transaction')
 if sql:find('UPDATE `players` SET',1,true)then
  if fails('update')then return false end
  check(sql:find('`vocation`=3,`level`=1,`experience`=0',1,true),'Wrong progression reset')
  check(sql:find('`skill_axe_tries`=500',1,true)and sql:find('`manaspent`=250',1,true),'Skill/magic progress conversion lost')
  row.vocation=3;row.level=1;row.experience=0;return true
 end
 if sql:find('INSERT INTO `player_passives`',1,true)then
  if fails('passives')then return false end
  check(not row.class,'Duplicate permanent class')
  local ranks=assert(sql:match(",'([0,]+)'%)$"),'Missing saved rank vector')
  local n=0;for rank in ranks:gmatch('[^,]+')do check(rank=='0','New class has allocated rank');n=n+1 end
  check(n==29 and #ranks<=128,'New class rank vector must have29 fields')
  row.class='reaver';row.ranks=ranks;row.points=3;row.respecCount=0;return true
 end
 if sql:find('INSERT INTO `player_storage`',1,true)then
  local key,value=sql:match('VALUES %(%d+,(%d+),(%d+)%)');key=tonumber(key);value=tonumber(value)
  local stage=({[100]='quest-storage',[101]='focus-storage',[102]='popup-storage'})[key]
  check(stage,'Unexpected storage key');if fails(stage)then return false end;row.storage[key]=value;return true
 end
 if sql:find('INSERT INTO `player_spells`',1,true)then
  local name=assert(sql:match("SELECT %d+,'([^']+)'"),'Missing starter name')
  fixture.starterWrites=fixture.starterWrites+1
  if fails('starter'..fixture.starterWrites)then return false end
  row.spells[name]=row.spells[name]or 1;return true
 end
 error('Unexpected SQL '..sql)
end
dofile('data/npc/scripts/The Nameless.lua')
check(type(callback)=='function','Actual NPC dialogue callback unavailable')
local function quantities(inventory,depot)
 local counts={}
 local function count(item)
  local key=item.kind;counts[key]=(counts[key]or 0)+(item.count or 1)
  for _,child in ipairs(item.children or{})do count(child)end
 end
 for _,item in pairs(inventory)do count(item)end
 for _,item in ipairs(depot)do count(item)end
 return counts
end
local function same(a,b,reason)
 for k,v in pairs(a)do check(b[k]==v,reason..' '..k)end
 for k,v in pairs(b)do check(a[k]==v,reason..' unexpected '..k)end
end
local function newFixture(options)
 options=options or{};events={}
 fixture={dialogue={},queries={},announcements=0,freed=0,begin=0,rollback=0,commits=0,starterWrites=0,
  saving=options.saving or 1,fail=options.fail,moves=0,saves=0,kicks=0,failMove=options.failMove,
  failSave=options.failSave,failLogoutSave=options.failLogoutSave,stayOnline=options.stayOnline,uiResults={},offerNo=1,offer=options.ui and'proof-offer-1'or nil}
 ClassChoice=options.ui and{supported=function()return true end,hasOffer=function()return fixture.offer end,
  offer=function()fixture.offerNo=fixture.offerNo+1;fixture.offer='proof-offer-'..fixture.offerNo;return true end,
  selected=function()end,consume=function()local offer=fixture.offer;fixture.offer=nil;return offer end,
  finish=function(_,offer,ok,message,reopen)fixture.uiResults[#fixture.uiResults+1]={offer=offer,ok=ok,message=message,reopen=reopen}end}or nil
 current={id=9003,guid=9003,name='Ascension Failure Proof',online=true,inventory={},depot={},
  vocation=2,level=40,experience=123456,pos=Position(32337,32208,4),storage={[100]=7,[101]=-1,[102]=-1}}
 current.depot={{kind='existing-gem',count=1},{kind='arrows',count=70}} -- nominal limit2: already full
 for slot=1,10 do
  local item={kind=slot==10 and'arrows'or'equipment-'..slot,count=slot==10 and 30 or 1,slot=slot}
  if slot==3 then item.children={{kind='nested-bag',children={{kind='nested-token',count=37}}},{kind='gold',count=99}}end
  function item:moveTo(depot,flags)
   check(depot==current.depot and flags==nil,'Existing moveTo default flags changed')
   fixture.moves=fixture.moves+1
   if fixture.moves==fixture.failMove then return false end
   check(current.inventory[self.slot]==self,'Source moved more than once')
   current.inventory[self.slot]=nil
   if self.kind=='arrows'then current.depot[2].count=current.depot[2].count+self.count;self.removedByMerge=true
   else current.depot[#current.depot+1]=self end
   return true
  end
  current.inventory[slot]=item
 end
 function current:getId()return self.id end
 function current:getGuid()return self.guid end
 function current:getName()return self.name end
 function current:getPosition()return self.pos end
 function current:getVocation()return Vocation(self.vocation)end
 function current:getStorageValue(key)return self.storage[key]or-1 end
 function current:setStorageValue(key,value)self.storage[key]=value end
 function current:passiveTest(command)if command=='available'then return true elseif command=='busy'then return false end;error('Unexpected native action '..command)end
 function current:getDepotChest(id,create)check(id==1 and create==true,'Depot selection changed');return self.depot end
 function current:getSlotItem(slot)return self.inventory[slot]end
 function current:getSkillLevel()return 20 end
 function current:getSkillTries()return 50 end
 function current:getMagicLevel()return 5 end
 function current:getManaSpent()return 25 end
 function current:save()
  fixture.saves=fixture.saves+1
  check(self.online,'Checked save after removal')
  fixture.lastSaveSucceeded=not fixture.failSave
  if fixture.failSave then return false end
  fixture.saved.inventory=copy(self.inventory);fixture.saved.depot=copy(self.depot);fixture.saved.storage=copy(self.storage)
  return true
 end
 function current:teleportTo(position)self.pos=position end
 function current:sendTextMessage()end
 function current:remove()
  fixture.kicks=fixture.kicks+1
  check(fixture.lastSaveSucceeded,'Kick before checked successful item save')
  if not fixture.failLogoutSave then fixture.saved.inventory=copy(self.inventory);fixture.saved.depot=copy(self.depot)end
  self.online=fixture.stayOnline==true;return true
 end
 fixture.saved={vocation=2,level=40,experience=123456,storage=copy(current.storage),spells={['Light Healing']=1},
  inventory=copy(current.inventory),depot=copy(current.depot)}
 fixture.original=copy(fixture.saved);fixture.before=quantities(current.inventory,current.depot)
 handler.topic[current.id]=5
 callback(current.id,1,'reaver');check(handler.topic[current.id]==6,'Actual class selection did not prepare confirmation')
 callback(current.id,1,'yes')
 return fixture,current
end
local function runEvents(count)
 local limit=count or 20;local n=0
 while #events>0 and n<limit do n=n+1;local event=table.remove(events,1);check(event.delay==200,'Offline write delay changed');event.fn(unpack(event.args))end
 if not count then check(#events==0,'Offline event failed to terminate')end
end
local function unchanged(record,original,label)
 check(record.vocation==original.vocation and record.level==original.level and record.experience==original.experience,label..' progression changed')
 check(record.class==nil and record.ranks==nil,label..' class granted')
 for _,key in ipairs({100,101,102})do check(record.storage[key]==original.storage[key],label..' quest/focus/popup changed')end
 check(record.spells['Light Healing']==1 and not record.spells['Cleaving Arc']and not record.spells.Rend,label..' spell entitlement changed')
end
for slot=1,10 do
 local f,p=newFixture({failMove=slot});same(f.before,quantities(p.inventory,p.depot),'Partial move ownership')
 check(p.online and f.moves==slot and f.saves==0 and f.kicks==0 and f.begin==0 and f.announcements==0,'Partial transfer proceeded to save/kick/commit')
 unchanged(f.saved,f.original,'Partial transfer');check(#events==0 and handler.topic[p.id]==0,'Failed transfer left pending confirmation/event')
 check(table.concat(f.dialogue,' '):find('the rest remain with you',1,true),'Partial transfer recovery not explained')
 cases[#cases+1]='slot'..slot..' transfer failure preserves all quantities and online owner'
end
for _,options in ipairs({{fail='saving-query'},{saving=0}})do
 local f,p=newFixture(options);same(f.before,quantities(p.inventory,p.depot),'Saving preflight ownership')
 check(p.online and f.moves==0 and f.saves==0 and f.kicks==0 and f.begin==0 and f.announcements==0,'Failed save preflight moved items')
 unchanged(f.saved,f.original,'Saving preflight');cases[#cases+1]=options.fail or'save0 rejects before transfer'
end
do local f,p=newFixture({failSave=true});same(f.before,quantities(p.inventory,p.depot),'Failed save live ownership');check(p.online and f.moves==10 and f.saves==1 and f.kicks==0 and f.begin==0 and f.announcements==0,'Failed checked save kicked/reset/granted');unchanged(f.saved,f.original,'Checked save failure');same(f.before,quantities(f.saved.inventory,f.saved.depot),'Checked save atomic prior ownership');check(#events==0 and handler.topic[p.id]==0,'Failed save retained pending mutation');cases[#cases+1]='checked save failure stays online with no class transaction'end
for _,stage in ipairs({'begin','locked-player','update','passives','quest-storage','focus-storage','popup-storage','starter1','starter2','commit'})do
 local f,p=newFixture({fail=stage,failLogoutSave=true});check(not p.online and f.saves==1 and f.kicks==1,'Transfer was not saved before logout')
 runEvents();same(f.before,quantities(p.inventory,p.depot),'Class failure live item ownership');same(f.before,quantities(f.saved.inventory,f.saved.depot),'Class failure durable item ownership')
 check(next(f.saved.inventory)==nil and f.saved.depot[2].count==100,'Durable depot or merged ammunition lost')
 unchanged(f.saved,f.original,'Class transaction '..stage);check(f.announcements==0 and f.commits==0 and not f.transaction,'Failed transaction announced/granted/remained open')
 check(f.rollback==(stage=='begin'and 0 or 1),'Failed class transaction did not roll back')
 cases[#cases+1]='class DB '..stage..' failure leaves durable depot and prior progression'
end
for _,saving in ipairs({1,2})do
 local f,p=newFixture({saving=saving,failLogoutSave=true});runEvents();same(f.before,quantities(f.saved.inventory,f.saved.depot),'Successful Ascension item ownership')
 check(next(f.saved.inventory)==nil and #f.saved.depot>2,'Full depot blocked unlimited original transfer')
 check(f.saved.vocation==3 and f.saved.class=='reaver'and f.saved.level==1 and f.saved.points==3 and f.saved.respecCount==0,'Successful class/progression incomplete')
 check(f.saved.storage[100]==8 and f.saved.storage[101]==2 and f.saved.storage[102]==1,'Successful quest/focus/popup incomplete')
 check(f.saved.spells['Light Healing']==1 and f.saved.spells['Cleaving Arc']==1 and f.saved.spells.Rend==1,'Starter grants lost or duplicated')
 check(f.announcements==1 and f.commits==1 and f.saves==1 and f.kicks==1,'Success must save/kick/commit/announce exactly once')
 cases[#cases+1]='full depot/nested backpack/merged ammo/save'..saving..' successful checked Ascension'
end
do local f,p=newFixture({stayOnline=true});runEvents(3);check(p.online and f.begin==0 and f.announcements==0 and #events==1,'Offline transaction ran while player remained online');cases[#cases+1]='offline transaction waits for actual absence'end
-- Re-entering the actual selection/confirmation callback after failure creates
-- a fresh offer and continues with the same objects; never manufacture copies.
for _,options in ipairs({{failMove=4,ui=true},{failSave=true,ui=true},{fail='passives',ui=true}})do
 local f,p=newFixture(options);if #events>0 then runEvents()end
 check(f.uiResults[1]and f.uiResults[1].ok==(options.fail~=nil),'UI did not report online failure/pending offline passage correctly')
 if not p.online then p.online=true;p.pos=Position(32337,32208,4)end
 f.fail=nil;f.failSave=false;f.failMove=nil
 handler.topic[p.id]=5;callback(p.id,1,'reaver');check(handler.topic[p.id]==6 and f.offerNo==2,'Retry did not use a new class offer')
 callback(p.id,1,'yes');runEvents()
 same(f.before,quantities(f.saved.inventory,f.saved.depot),'Retry item ownership')
 check(f.saved.vocation==3 and f.saved.class=='reaver'and f.commits==1 and f.announcements==1,'Failure retry did not commit once')
 check(f.uiResults[2]and f.uiResults[2].ok==true and f.uiResults[2].offer~=f.uiResults[1].offer,'Retry reused failed UI offer')
 cases[#cases+1]='fresh UI offer after '..(options.fail or(options.failSave and'checked-save'or'partial-transfer'))..' failure succeeds without duplicate items'
end
-- Actual DDL sources and actual migration callback: fresh records use29; no
-- SQL statement rewrites existing saved17 allocations.
for _,path in ipairs({'schema.sql','data/migrations/30.lua'})do
 local source=read(path);local ranks=assert(source:match("`ranks` VARCHAR%(128%) NOT NULL DEFAULT '([0,]+)'"));local n=0
 for rank in ranks:gmatch('[^,]+')do check(rank=='0','Nonzero rank default');n=n+1 end
 check(n==29 and #ranks==57,'Fresh SQL rank default must have29 ranks')
 check(not source:match('UPDATE%s+`?player_passives'),'DDL rewrites existing allocations')
end
local ddl;db.query=function(sql)ddl=sql;return true end;dofile('data/migrations/30.lua');check(onUpdateDatabase()==true and ddl:find('CREATE TABLE IF NOT EXISTS',1,true),'Actual schema migration failed')
db.query=function()return false end;check(onUpdateDatabase()==false,'Failed schema migration advances version')
local binding=read('src/luascript.cpp');check(binding:find('pushBoolean(L, IOLoginData::savePlayer(player))',1,true),'Checked save binding no longer returns native transaction result')
check(binding:find('FLAG_NOLIMIT | FLAG_IGNOREBLOCKITEM | FLAG_IGNOREBLOCKCREATURE | FLAG_IGNORENOTMOVEABLE',1,true),'moveTo unlimited default changed')
local native=read('src/passives.cpp');check(native:find('if(fields==LegacyNodeCount)',1,true),'Existing17 compatibility missing')
print('PASSIVES_ASCENSION_FAILURE_OK cases='..#cases..' checks='..checks..' nativeCallbacksMocked=true databaseMocked=true')
print(json.encode({status='PASS',cases=cases,checks=checks,scope='Actual NPC dialogue and offline transaction, mocked native moves/saves and SQL; no game/DB/network; source-backed defaults and native flag/boolean contracts'}))
