-- Native art review on the disposable loopback GUID9001: all rods in an open bag.
local failed,finished,finishing=false,false,false
local receipts={}
local function fail(reason)
 if failed or finished then return end;failed=true;print('RODS_VISUAL_FAILED '..tostring(reason))
 if g_game.isOnline()then g_game.talk('/rodqa unshow')end
 scheduleEvent(function()g_app.exit()end,1000)
end
local function later(ms,fn)
 scheduleEvent(function()if failed or finished then return end;local ok,e=xpcall(fn,debug.traceback);if not ok then fail(e)end end,ms)
end
local function wait(label,predicate,nextStep)
 local deadline=g_clock.millis()+10000
 local function poll()local result=predicate();if result then nextStep(result);return end;assert(g_clock.millis()<deadline,label..' timed out');later(70,poll)end
 later(70,poll)
end
local function command(text,label,nextStep)
 local previous=receipts[label];g_game.talk('/rodqa '..text)
 wait(text,function()return receipts[label]~=previous and receipts[label]end,nextStep)
end
later(200,function()
 assert(LOCAL_PASSIVES_TEST and Services.updater==''and g_resources.getLayout()=='retro')
 connect(g_game,{onGameStart=function()
  EnterGame.hide();later(1500,function()
   command('show','shown',function(shown)
    later(600,function()
     local pos=shown.position;local tile=assert(g_map.getTile({x=pos.x,y=pos.y,z=pos.z}),'Review tile not visible')
     local bag
     for _,thing in ipairs(tile:getThings())do if thing:isItem()and thing:getId()==shown.bagClientId then bag=thing end end
     g_game.use(assert(bag,'Review bag not visible'))
     wait('review bag opened',function()for _,c in pairs(g_game.getContainers())do if c:getItemsCount()==8 then return true end end end,function()
      later(900,function()
       g_app.doScreenshot('/rods-native-review.png')
       later(700,function()
        command('unshow','unshown',function()
         finishing=true;g_game.safeLogout()
         wait('clean logout',function()return not g_game.isOnline()end,function()finished=true;print('RODS_VISUAL_OK screenshot=/rods-native-review.png');g_app.exit()end)
        end)
       end)
      end)
     end)
    end)
   end)
  end)
 end,onTextMessage=function(_,text)
  local raw=text:match('^RODS_QA (.+)$');if not raw then return end
  local r=json.decode(raw);if r.label=='FAILED'then fail(r.reason)else receipts[r.label]=r end
 end,onLoginError=function(e)fail(e)end,onConnectionError=function(e)if not finishing and not finished then fail(e)end end})
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 G.account,G.password='passivetest','passivetest'
 local login=ProtocolLogin.create();_G.rodsVisualLogin=login
 login.onLoginError=function(_,e)fail(e)end
 login.onCharacterList=function(_,characters)
  for _,c in ipairs(characters)do if c.name=='Passive Tester'then g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return end end
  fail('Owned Passive Tester absent')
 end
 login:login('127.0.0.1',7174,G.account,G.password,'',false)
end)
scheduleEvent(function()if not finished then fail('Rods visual 40s timeout')end end,40000)
