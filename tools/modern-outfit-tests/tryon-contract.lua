local path=assert(arg[1])
local env=setmetatable({}, {__index=_G})
local source=assert(loadfile(path));setfenv(source,env);source()
local checks=0
local function check(ok,why)assert(ok,why);checks=checks+1 end
local function upvalue(fn,name,value)
 for index=1,100 do
  local key=debug.getupvalue(fn,index)
  if not key then break end
  if key==name then debug.setupvalue(fn,index,value);return end
 end
 error('Missing source upvalue '..name)
end
local worn={type=128,addons=0,head=0,body=49,legs=2,feet=58,mount=0}
local changed,writes,closed=0,0,0
local actualCreate=env.create
local actualDestroy=env.destroy
local actualSave=env.saveSettings
local captured
local marker={}
env.g_game={getLocalPlayer=function()return {getOutfit=function()return worn end}end,
 getFeature=function()return false end,changeOutfit=function()changed=changed+1 end}
env.tr=function(s)return s end
env.table=setmetatable({copy=function(t)local o={}for k,v in pairs(t)do o[k]=v end return o end},{__index=table})
env.g_resources=setmetatable({}, {__index=function(_,key)return function()writes=writes+1;error('Unexpected profile access: '..key)end end})
env.create=function(...)captured={...};return marker end
local requested={type=374,addons=3,head=99,body=98,legs=97,feet=96,mount=12}
local close=function()closed=closed+1 end
check(env.previewOutfit(requested,'Rune Master',close)==marker,'Preview did not return its native window')
check(captured[1].type==374 and captured[1].addons==3,'Wrong preview appearance/addons')
check(captured[1].head==0 and captured[1].body==49 and captured[1].legs==2 and captured[1].feet==58,'Current player colours not retained')
check(captured[1].mount==0 and captured[1].shader=='outfit_default','Unrelated cosmetics leaked into preview')
check(captured[2][1][1]==374 and captured[2][1][2]=='Rune Master' and captured[2][1][3]==3,'Wrong preview selection list')
check(captured[9].title=='Rune Master' and captured[9].onClose==close,'Preview context lost')
check(requested.head==99 and requested.mount==12 and worn.type==128 and worn.addons==0,'Input or real equipped appearance was mutated')
check(changed==0 and writes==0,'Opening preview performed side effects')
for _,request in ipairs({{type=0},{type=-1},{type=65536},{type=1.5},{type='bad'},{type=374,addons=4}})do
 check(env.previewOutfit(request,'Invalid')==nil,'Malformed preview accepted')
end
local oldPlayer=env.g_game.getLocalPlayer;env.g_game.getLocalPlayer=function()return nil end
check(env.previewOutfit(requested,'Offline')==nil,'Offline preview accepted');env.g_game.getLocalPlayer=oldPlayer
env.create=actualCreate
env.destroy=function()closed=closed+1 end
upvalue(env.accept,'window',marker)
upvalue(env.accept,'previewMode',true)
check(env.getPreviewWindow()==marker,'Preview window lookup failed')
env.accept()
check(changed==0 and closed==1,'Preview Enter/accept sent an outfit change')
actualSave()
check(writes==0,'Preview settings were persisted')
upvalue(env.accept,'previewMode',false)
check(env.getPreviewWindow()==nil,'Normal dialog reported as preview')
env.accept()
check(changed==1 and closed==2,'Normal outfit accept path no longer sends its change')
check(requested.type==374 and worn.type==128,'Real player or source offer mutated')

-- Scheduled floor callbacks must belong to the window/generation that created
-- them, even if another trial opens before the old callback gets its next tick.
local timers={}
env.periodicalEvent=function(callback,predicate,delay,interval)
 check(delay==50 and interval==50,'Floor animation scheduling changed')
 timers[#timers+1]={callback=callback,predicate=predicate}
end
env.Directions={North=0,East=1,South=2,West=3}
env.previewCreature={getDirection=function()return env.Directions.East end}
local function fakeFloor()
 local object={moves=0,margin=0,visible=false}
 function object:show()self.visible=true end
 function object:hide()self.visible=false end
 function object:getMarginRight()return self.margin end
 function object:setMarginRight(value)self.margin=value;self.moves=self.moves+1 end
 return object
end
local checked={isChecked=function()return true end}
local ownerA={destroy=function()end}
local floorA=fakeFloor()
upvalue(env.onShowFloorChange,'window',ownerA)
upvalue(env.onShowFloorChange,'floor',floorA)
upvalue(env.onShowFloorChange,'movementCheck',checked)
upvalue(env.onShowFloorChange,'showFloorCheck',checked)
upvalue(env.onShowFloorChange,'settings',{})
env.onShowFloorChange(nil,true)
check(timers[1].predicate() and floorA.visible,'Initial floor timer did not start')
timers[1].callback()
check(floorA.moves==1,'Current floor timer did not animate')
env.onShowFloorChange(nil,false)
env.onShowFloorChange(nil,true)
check(not timers[1].predicate() and timers[2].predicate(),'Rapid off/on revived an old timer')
timers[1].callback()
check(floorA.moves==1,'Obsolete generation still changed the floor')
timers[2].callback()
check(floorA.moves==2,'Replacement generation did not animate')

local ownerB={destroy=function()end}
local floorB=fakeFloor()
upvalue(env.onShowFloorChange,'window',ownerB)
upvalue(env.onShowFloorChange,'floor',floorB)
check(not timers[2].predicate(),'Old timer adopted a newly opened window')
timers[2].callback()
check(floorB.moves==0,'Old owner callback changed the replacement floor')
env.onShowFloorChange(nil,true)
check(timers[3].predicate(),'New window did not obtain its own timer')
timers[3].callback()
check(floorB.moves==1,'New owner callback did not animate')

local group={destroy=function()end}
for _,name in ipairs({'appearanceGroup','colorModeGroup','colorBoxGroup'})do
 upvalue(actualDestroy,name,group)
end
upvalue(env.accept,'previewMode',true)
actualDestroy(true,true)
check(not timers[3].predicate(),'Destroy left its timer enabled')
timers[3].callback()
check(floorB.moves==1,'Destroyed timer still changed its old floor')

local ownerC={destroy=function()end}
local floorC=fakeFloor()
upvalue(env.onShowFloorChange,'window',ownerC)
upvalue(env.onShowFloorChange,'floor',floorC)
upvalue(env.onShowFloorChange,'movementCheck',checked)
upvalue(env.onShowFloorChange,'showFloorCheck',checked)
env.onShowFloorChange(nil,true)
for i=1,3 do
 check(not timers[i].predicate(),'Immediate reopening revived an obsolete timer')
 timers[i].callback()
end
check(floorC.moves==0 and timers[4].predicate(),'Old timers affected the immediately reopened trial')
timers[4].callback()
check(floorC.moves==1,'Latest trial timer did not animate')
check(changed==1 and writes==0,'Floor lifecycle checks mutated equipped appearance or profile')
print('OUTFIT_PREVIEW_CONTRACT_OK checks='..checks..' source=true nativeUI=false')
