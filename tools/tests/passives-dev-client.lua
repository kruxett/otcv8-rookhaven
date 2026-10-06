-- Run with LuaJIT and repository path, or offline in the packaged client.
-- Actual module chunks + scripted protocol/UI boundaries; no login or deployment.
local native = g_resources ~= nil and g_game ~= nil
local repository = not native and (arg[1] or '.') or nil
if not json then dofile(repository .. '/modules/corelib/json.lua') end
local cases = 0
local function check(value, reason) cases = cases + 1; assert(value, reason) end
local function loadModule(env, name)
  local path = (native and '/modules/game_passives/' or repository .. '/modules/game_passives/') .. name .. '.lua'
  local chunk = assert(loadfile(path), 'Cannot load actual module ' .. path)
  setfenv(chunk, env); chunk()
end
local function fresh(localProfile, channel, layout, online)
  local trace = {registered=0,unregistered=0,connected=0,disconnected=0,ui=0,sent={},talk={},events={},warnings={}}
  local function widget()
    local w = {children={},visible=true,width=1280,height=800,x=0,y=0,text=''}
    function w:getChildById(id) if not self.children[id] then self.children[id]=widget() end; return self.children[id] end
    w.recursiveGetChildById=w.getChildById
    function w:getRect()return {x=self.x,y=self.y,width=self.width,height=self.height}end
    function w:getSize()return {width=self.width,height=self.height}end
    function w:getWidth()return self.width end;function w:getHeight()return self.height end
    function w:getX()return self.x end;function w:getY()return self.y end
    function w:setSize(s)self.width=s.width;self.height=s.height end
    function w:setPosition(p)self.x=p.x;self.y=p.y end
    function w:setText(s)self.text=s end;function w:getText()return self.text end
    function w:isVisible()return self.visible end
    function w:hide()self.visible=false end;function w:show()self.visible=true end
    function w:destroy()self.destroyed=true;self.visible=false end
    return setmetatable(w,{__index=function()return function()end end})
  end
  local root=widget()
  local env={LOCAL_PASSIVES_TEST=localProfile,UPDATER_CHANNEL=channel or false,
    Services={updater=localProfile and '' or 'http://updater2.rookhaven-ot.com/api/updater'},
    json=json,g_clock={millis=function()return 1000 end},
    g_resources={getLayout=function()return layout end},
    g_ui={getRootWidget=function()return root end},
    g_settings={getBoolean=function()return false end,set=function()error('Guard changed settings')end},
    g_logger={warning=function(message)trace.warnings[#trace.warnings+1]=message end},
    g_things={getThingType=function(id)return {getId=function()return id end}end},
    modules={game_buttons={updateOrder=function()end}},ProtocolGame={},
    connect=function(object,handlers)trace.connected=trace.connected+1;if object~=root then trace.gameEvents=handlers end end,
    disconnect=function()trace.disconnected=trace.disconnected+1 end,
    scheduleEvent=function(fn,ms)local e={fn=fn,ms=ms};trace.events[#trace.events+1]=e;return e end,
    removeEvent=function(e)e.cancelled=true end}
  local protocol={sendExtendedOpcode=function(_,opcode,encoded)
    check(opcode==103,'Wrong protocol opcode');trace.sent[#trace.sent+1]=json.decode(encoded)
  end}
  env.g_game={isOnline=function()return online end,getProtocolGame=function()return protocol end,
    talk=function(words)trace.talk[#trace.talk+1]=words end,getLocalPlayer=function()return nil end}
  function env.g_ui.displayUI()trace.ui=trace.ui+1;return widget()end
  env.g_ui.createWidget=env.g_ui.displayUI;env.g_ui.loadUI=env.g_ui.displayUI
  env.modules.client_topmenu={addRightGameToggleButton=function()trace.ui=trace.ui+1;return widget()end}
  function env.ProtocolGame.registerExtendedOpcode(opcode,fn)
    check(opcode==103,'Wrong registered opcode');trace.registered=trace.registered+1;trace.callback=fn
  end
  function env.ProtocolGame.unregisterExtendedOpcode(opcode)
    check(opcode==103,'Wrong unregistered opcode');trace.unregistered=trace.unregistered+1;trace.callback=nil
  end
  env._G=env;setmetatable(env,{__index=_G})
  for _,name in ipairs({'classspells','classchoice','passivetree','passives'})do loadModule(env,name)end
  env.init()
  function trace.packet(data)
    data.v=1;assert(trace.callback,'Inactive profile has no protocol receiver');trace.callback(protocol,103,json.encode(data))
  end
  function trace.runHello()
    for _,e in ipairs(trace.events)do if e.ms==500 and not e.cancelled then e.cancelled=true;e.fn();return end end
    error('Missing scheduled hello')
  end
  return env,trace
end
local function hello()
  return {action='hello',enabled=true,capable=true,schemaVersion=2,catalogVersion=2,nodeCount=29,
    classId='',classCatalog={},classHint='Visit The Nameless.'}
end
local function choiceOffer()
  local classes={}
  for _,id in ipairs({'reaver','blademaster','earthshaker','marksman','arcanist','lifekeeper'})do
    classes[#classes+1]={id=id,name=id,weapon='Class weapon',tagline='Your path',description='Class description.',allowed=true,reason='',
      outfit={type=128,head=0,body=0,legs=0,feet=0,addons=0}}
  end
  return {v=1,action='class_choice_offer',offer='dev-offer',ttlMs=30000,classes=classes,consequences='Your class is permanent.'}
end
local function spellCatalog()
  local spells={}
  for _,id in ipairs({'cleaving_arc','rend'})do
    spells[#spells+1]={id=id,name=id,words=id=='rend' and 'rend words' or 'cleaving words',mana=20,cooldown=2000,
      range=5,kind='combat',description='Class spell.',icon='/images/game/passives/minor_power'}
  end
  return {v=1,action='class_spells',classId='reaver',className='Reaver',spells=spells}
end
local function run()
  if native then
    check(not g_game.isOnline() and not g_game.isLogging(),'Packaged guard test must remain offline')
    check(g_resources.isLoadedFromArchive(),'Packaged guard test must read archive modules')
  end
  for _,profile in ipairs({
    {false,'prod','retro',false},{false,false,'retro',false},
    {false,'dev','mobile',false},{true,'local-passives','mobile',false}
  })do
    local env,trace=fresh(unpack(profile))
    env.terminate()
    check(trace.registered==0 and trace.connected==0 and #trace.events==0 and trace.ui==0,'Inactive profile touched handlers/UI')
    check(not env.getState().ready and not env.getState().active,'Inactive profile retained state')
  end
  local offline,offlineTrace=fresh(false,'dev','retro',false)
  check(offlineTrace.registered==1 and offlineTrace.connected==2 and #offlineTrace.events==0,'Offline DEV did not register only required events')
  check(offlineTrace.ui==0 and #offlineTrace.sent==0,'Offline DEV opened UI/sent hello')
  offline.terminate();check(offlineTrace.unregistered==1 and offlineTrace.disconnected==2,'DEV unload leaked registrations')
  local env,trace=fresh(false,'dev','retro',true)
  trace.runHello()
  local outgoing=trace.sent[1]
  check(outgoing.action=='hello' and outgoing.client=='dev-passives' and outgoing.v==1 and outgoing.classChoice==true,
    'DEV hello identity/capability advertisement wrong')
  check(outgoing.schemaVersion==2 and outgoing.catalogVersion==2 and outgoing.nodeCount==29,'DEV hello version contract wrong')
  check(trace.ui==0 and not env.getState().ready,'DEV opened UI before server acknowledgement')
  trace.packet({action='catalog_part',session='early',transfer='early',total=1,index=1,data='{}'})
  trace.packet(choiceOffer());trace.packet(spellCatalog());trace.packet({action='open',session='early'})
  check(trace.ui==0 and not env.getState().tree and not env.getState().openRequested,'Unconfirmed server packet opened UI/state')
  check(not env.ClassChoice.receive(choiceOffer()) and not env.ClassSpells.receive(spellCatalog(),'reaver'),
    'Submodule bypassed handshake')
  for _,bad in ipairs({{enabled=false},{capable=false},{schemaVersion=1},{catalogVersion=1},{nodeCount=17}})do
    local message=hello();for key,value in pairs(bad)do message[key]=value end
    trace.packet(message);check(not env.getState().ready and trace.ui==0,'Unsupported/disabled hello opened feature')
  end
  local missing=hello();missing.capable=nil;trace.packet(missing)
  check(not env.getState().ready,'Missing capability accepted in DEV')
  missing=hello();missing.enabled=nil;trace.packet(missing)
  check(not env.getState().ready,'Missing enabled flag accepted in DEV')
  trace.packet(hello())
  check(env.getState().ready and trace.ui==0,'Ordinary no-class capability hello did not stay UI-free')
  local updater=env.Services.updater
  check(env.ClassChoice.receive(choiceOffer())==true and env.ClassChoice.getWindow(),'DEV class choice still requires local flag')
  check(env.ClassChoice.selectLocal('reaver') and env.ClassChoice.choose(),'DEV choice handler disabled')
  check(trace.sent[#trace.sent].action=='class_choice_select' and trace.sent[#trace.sent].offer=='dev-offer','Choice did not send real offer-bound request')
  env.ClassChoice.reset()
  check(env.ClassSpells.receive(spellCatalog(),'reaver')==true and env.ClassSpells.getButton(),'DEV learned-spell catalog disabled')
  check(env.ClassSpells.cast('rend') and trace.talk[#trace.talk]=='rend words','DEV actual spell handler did not invoke words')
  -- A rejected version message must not erase a current, unsaved draft.
  local state=env.getState();state.draft={minor_power=1};local draft=state.draft
  local bad=hello();bad.schemaVersion=1;trace.packet(bad)
  check(env.getState().ready and env.getState().draft==draft and draft.minor_power==1,'Rejected schema hello erased draft')
  trace.packet({action='hello',enabled=false,capable=false,schemaVersion=2,catalogVersion=2,nodeCount=29})
  check(not env.getState().ready and not env.getState().active and not env.ClassSpells.getButton(),'Disabled server retained capability/spell UI')
  check(not env.ClassSpells.cast('rend') and not env.ClassChoice.receive(choiceOffer()),'Disabled server retained actionable submodule')
  trace.packet(choiceOffer());check(not env.ClassChoice.getWindow(),'Delayed offer reopened disabled feature')
  check(env.Services.updater==updater and updater~='','DEV guard altered updater')
  env.terminate()
  local localEnv,localTrace=fresh(true,'local-passives','retro',true)
  localTrace.runHello();check(localTrace.sent[1].client=='local-passives','Local profile identity changed')
  localTrace.packet({action='hello',enabled=true})
  check(localEnv.getState().ready and localEnv.Services.updater=='','Legacy local/no-updater profile changed')
  localTrace.gameEvents.onGameEnd();check(not localEnv.getState().ready,'Logout retained server capability')
  localTrace.packet(choiceOffer());check(localTrace.ui==0,'Prior-session offer bypassed fresh handshake')
  localEnv.terminate()
  check(#trace.warnings==0 and #localTrace.warnings==0,'Actual module payload callback threw')
  print('PASSIVES_DEV_CLIENT_OK cases='..cases..' actualModules=true transport=scripted productionInactive=true')
end
local function execute()
  local ok,reason=pcall(run)
  if not ok then print('PASSIVES_DEV_CLIENT_FAILED '..tostring(reason))end
  if native then g_app.exit()elseif not ok then error(reason)end
end
if native then scheduleEvent(execute,300)else execute()end
