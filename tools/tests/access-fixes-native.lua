local done,failed,finishing=false,false,false
local rows,opens,talks={},{},{}
local original
local function fail(reason)
 if done or failed then return end;failed=true;print('ACCESS_FIXES_NATIVE_FAILED '..tostring(reason))
 if g_game.isOnline()then g_game.talk('/accessfixesqa cleanup');g_game.safeLogout()end
 if original then ProtocolGame.onExtendedOpcode=original end
 scheduleEvent(function()g_app.exit()end,800)
end
local function later(ms,fn)scheduleEvent(function()if done or failed then return end;local ok,reason=xpcall(fn,debug.traceback);if not ok then fail(reason)end end,ms)end
local function row(label)for n=#rows,1,-1 do if rows[n].label==label then return rows[n]end end end
local function wait(label,test,nextStep)
 local deadline=g_clock.millis()+20000
 local function poll()local v=test();if v then nextStep(v);return end;assert(g_clock.millis()<deadline,label..' timeout');later(70,poll)end;later(70,poll)
end
local function command(verb)g_game.talk('/accessfixesqa '..verb)end
later(200,function()
 assert(LOCAL_PASSIVES_TEST and Services.updater=='' and g_resources.getLayout()=='retro','Owned local native package required')
 original=assert(ProtocolGame.onExtendedOpcode)
 ProtocolGame.onExtendedOpcode=function(protocol,opcode,buffer)
  original(protocol,opcode,buffer)
  if opcode==100 then local ok,data=pcall(json.decode,buffer);if ok and data.mode=='select'then opens[#opens+1]=data end end
 end
 connect(g_game,{
 onGameStart=function()later(350,function()
  EnterGame.hide();g_game.cancelAttack();command('prepare')
  wait('native fixture setup',function()return row('prepared')end,function()
   local p=assert(g_game.getLocalPlayer());g_game.move(assert(p:getInventoryItem(5)),{x=65535,y=6,z=0},1)
   later(220,function()command('moved');wait('actual native hand swap',function()return row('put_in_bag')end,function()
    g_game.move(assert(p:getInventoryItem(6)),{x=65535,y=3,z=0},1)
    later(220,function()command('services');wait('native store/essence',function()return row('bound_bag')end,function(receipt)
     g_game.move(assert(p:getInventoryItem(3)),receipt.ground,1)
     later(220,function()command('bag_denied');wait('native Varr fixture',function()return row('npc_ready')end,function(npc)
      local previous=#talks;g_game.talk('hi')
      wait('actual Varr greeting',function()for n=previous+1,#talks do if talks[n].name==npc.name and (talks[n].mode==MessageModes.NpcFrom or talks[n].mode==MessageModes.NpcFromStartBlock) then return true end end end,function()
       later(650,function()g_game.talkChannel(MessageModes.NpcTo,0,'tradepack')
        wait('actual Varr service window and complete dialogue',function()
         if #opens==0 then return end
         for _,speech in ipairs(talks)do if speech.name==npc.name and speech.text:find('Pick your size and destination',1,true)then return true end end
        end,function()command('pack_opened')
         wait('native access fixes completion',function()return row('complete')end,function(result)
          assert(result.checks>=20 and result.nativeEquipment and result.nativeDatabase and result.actualNpcDialogue,'Incomplete native evidence')
          assert(row('cleanup'),'Owned native cleanup receipt missing');finishing=true;g_game.safeLogout()
          wait('native fixture logout',function()return not g_game.isOnline()end,function()
           ProtocolGame.onExtendedOpcode=original;done=true;print('ACCESS_FIXES_NATIVE_OK '..json.encode(result));scheduleEvent(function()g_app.exit()end,400)
          end)
         end)
        end)
       end)
      end)
     end)end)
    end)end)
   end)end)
  end)
 end)end,
 onTalk=function(name,level,mode,text)talks[#talks+1]={name=name,mode=mode,text=text};if name=='Foreman Varr'then print('ACCESS_FIXES_NATIVE_TALK '..json.encode({name=name,mode=mode,text=text}))end end,
 onTextMessage=function(_,text)local raw=text:match('^ACCESS_FIXES_NATIVE (.+)$');if not raw then return end
  local ok,reason=xpcall(function()local receipt=json.decode(raw);print(text);if receipt.label=='FAILED'then error(receipt.error)end;rows[#rows+1]=receipt end,debug.traceback);if not ok then fail(reason)end
 end,
 onConnectionError=function(reason)if not finishing then fail(reason)end end,
 })
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA);G.account='passivetest';G.password='passivetest'
 local login=ProtocolLogin.create();_G.accessFixesNativeLogin=login
 login.onLoginError=function(_,reason)fail(reason)end
 login.onCharacterList=function(_,list)for _,c in ipairs(list)do if c.name=='Passive Tester'then
  assert(c.worldIp=='127.0.0.1'and c.worldPort==7175,'Non-loopback world');g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return
 end end;fail('Owned fixture character missing')end
 login:login('127.0.0.1',7174,G.account,G.password,'',false)
end)
scheduleEvent(function()if not done then fail('Access-fixes native probe timeout')end end,90000)
