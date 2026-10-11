-- Admin observer/controller for the actual ordinary-peer Bolgrim conversation.
local account=LEGENDARY_NATIVE_ACCOUNT or 'passivetest'
local password=LEGENDARY_NATIVE_PASSWORD or account
local done,failed,finishing,started=false,false,false,false
local ready,peerDone=false,false
local rows,milestones={},{}
local login
local function fail(reason)
 if done or failed then return end;failed=true
 print('FORGOTTEN_QUEST_NATIVE_FAILED '..tostring(reason))
 if g_game.isOnline()then
  if started then g_game.talk('/forgottenquestqa cleanup')end
  scheduleEvent(function()if g_game.isOnline()then g_game.safeLogout()end end,700)
 else g_game.cancelLogin()end
 scheduleEvent(function()g_app.exit()end,1500)
end
local function guarded(fn)if done or failed then return end;local ok,why=pcall(fn);if not ok then fail(why)end end
local function later(ms,fn)scheduleEvent(function()guarded(fn)end,ms)end
local function wait(label,predicate,nextStep,timeout)
 local deadline=g_clock.millis()+(timeout or 25000)
 local function poll()
  if predicate()then nextStep();return end
  assert(g_clock.millis()<deadline,label..' timeout');later(80,poll)
 end
 later(80,poll)
end
local function latest(label,after)
 for index=#rows,(after or 0)+1,-1 do if rows[index].label==label then return rows[index]end end
end
local function command(verb,label,nextStep)
 local after=#rows;g_game.talk('/forgottenquestqa '..verb)
 wait(verb,function()return latest(label,after)end,function()later(150,function()nextStep(latest(label,after))end)end)
end
local function milestone(name,nextStep,timeout)
 wait('actual NPC/page milestone '..name,function()return milestones[name]end,nextStep,timeout)
end
local function finish()
 command('cleanup','cleanup',function(row)
  assert(row.ordinaryPeerRestored and row.seededOwnedItemsRemoved,'Cleanup was not confirmed')
  started=false
  wait('ordinary peer clean logout',function()return peerDone end,function()
   finishing=true;g_game.safeLogout()
   wait('controller clean logout',function()return not g_game.isOnline()end,function()
    done=true
    print('FORGOTTEN_QUEST_NATIVE_OK '..json.encode({actualBolgrimDialogue=true,ordinaryCharacter=true,
     unascendedDenied=true,ascendedAccepted=true,foreignMouldDenied=true,naturalWorldDwarfMould=true,
     personalMouldReturned=true,actualPageUse=true,dwarfRecipes=4,temperingHelp=true,
     unmeasured='page RNG frequency and full material/core farming; native skill gain retained in disposable QA character'}))
    scheduleEvent(function()g_app.exit()end,400)
   end)
  end)
 end)
end
local function run()
 command('prepare Passive Peer','prepared',function(row)
  started=true;assert(row.ordinaryGroup==1 and row.questStage==0,'Unascended ordinary setup differs')
  milestone('unascended',function()
   command('verify unascended','verified',function()
    command('ascend','ascended_setup',function()
     milestone('accepted',function()
      command('verify accepted','verified',function()
       command('foreign','foreign_setup',function()
        milestone('foreign',function()
         command('verify foreign','verified',function()
          command('hunt','hunt_ready',function(hunt)
           assert(hunt.actualNativeWorldSpawn and hunt.syntheticDamage==false and hunt.targetName=='Dwarf Guard','World-spawn or paid-attack evidence differs')
           wait('natural world dwarf death',function()return latest('natural_drop')end,function()
            local drop=latest('natural_drop');assert(drop.actualNativeWorldSpawn and drop.actualPaidAttackReceipt and drop.mouldOwner==9002,'Natural native mould provenance absent')
            command('collect','collected',function()
             milestone('returned',function()
              command('verify returned','verified',function()
               command('page','page_ready',function(page)
                assert(page.seededActualPage,'Page seeding not labelled')
                milestone('read',function()
                 command('verify read','verified',function()
                  g_game.talkPrivate(MessageModes.PrivateTo,'Passive Peer','FORGOTTEN_QUEST_TEMPERING')
                  milestone('tempering',function()command('verify tempering','verified',finish)end,35000)
                 end)
                end)
               end)
              end)
             end)
            end)
           end,90000)
          end)
         end)
        end)
       end)
      end)
     end)
    end)
   end)
  end)
 end)
end
later(300,function()
 assert(LOCAL_PASSIVES_TEST==true and Services.updater=='' and DEFAULT_SERVER_ENDPOINT=='127.0.0.1:7174:860'
  and g_resources.getLayout()=='retro','Requires isolated local retro controller profile')
 connect(g_game,{
  onGameStart=function()later(250,function()
   assert(g_game.getLocalPlayer():getName()=='Passive Tester','Wrong controller')
   EnterGame.hide();wait('ordinary peer',function()return ready end,function()
    g_game.talkPrivate(MessageModes.PrivateTo,'Passive Peer','FORGOTTEN_QUEST_CONTROLLER_READY');run()
   end,60000)
  end)end,
  onGameEnd=function()if not finishing and not failed then fail('Unexpected controller logout')end end,
  onConnectionError=function(e)if not finishing then fail(e)end end,onLoginError=fail,
  onTalk=function(name,_,mode,text)
   if name~='Passive Peer' or mode~=MessageModes.PrivateFrom then return end
   if text=='FORGOTTEN_QUEST_PEER_READY'then ready=true
   elseif text=='FORGOTTEN_QUEST_PEER_CLEAN'then peerDone=true
   elseif text:match('^FORGOTTEN_QUEST_PEER_FAILED ')then fail(text)
   else local name=text:match('^FORGOTTEN_QUEST_MILESTONE (.+)$');if name then milestones[name]=true;print(text)end end
  end,
  onTextMessage=function(_,text)guarded(function()
   local raw=text:match('^FORGOTTEN_QUEST_QA (.+)$');if not raw then return end
   local row=json.decode(raw);print(text)
   if row.label=='FAILED' or row.label=='RESTORE_UNCONFIRMED'then error(row.error or row.label)end
   rows[#rows+1]=row
  end)end,
 })
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 G.account,G.password=account,password
 login=ProtocolLogin.create();_G.forgottenQuestLogin=login
 login.onLoginError=function(_,e)fail(e)end
 login.onCharacterList=function(_,list)guarded(function()
  for _,c in ipairs(list)do if c.name=='Passive Tester'then
   assert(c.worldIp=='127.0.0.1'and c.worldPort==7175,'Non-loopback world')
   g_game.loginWorld(account,password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return
  end end;error('Disposable controller absent')
 end)end
 login:login('127.0.0.1',7174,account,password,'',false)
end)
scheduleEvent(function()if not done then fail('240-second quest controller timeout')end end,240000)
