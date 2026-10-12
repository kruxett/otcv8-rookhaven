-- Actual 8.60 client on the disposable loopback GUID9001: the Lifekeeper rods'
-- definitions, class recognition, real attacks, rod spells and level rules.
local RODS={ -- sid, name, element, mana, min, max
 {12850,'bramble rod','earth',3,6,12},{12851,'mossheart rod','earth',6,13,25},
 {12852,'rime rod','ice',2,4,9},{12853,'sleet rod','ice',4,8,16},{12854,'winterbough rod','ice',6,15,27},
 {12855,'bone rod','death',2,3,7},{12856,'gravebloom rod','death',4,8,15},{12857,'wither rod','death',5,11,19}}
local SPELL={earth={'exori tera con',14},ice={'exori frigo lux',13},death={'exori mort lux',14}}
local WRONG={earth='ice',ice='death',death='earth'}
local failed,finished,finishing=false,false,false
local receipts,texts,evidence={},{},{classes={},attacks={},spells={},wrongElement={}}
local function fail(reason)
 if failed or finished then return end;failed=true;print('RODS_NATIVE_FAILED '..tostring(reason))
 if g_game.isOnline()then g_game.talk('/rodqa cleanup')end
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
local function each(list,step,done)
 local index=0
 local function advance()index=index+1;if index>#list then done()else step(list[index],advance)end end
 advance()
end
local function channelRefusal(after)
 for i=after+1,#texts do if texts[i]:find('equipped to channel this spell',1,true)then return true end end
end
local function cast(rod,element,nextStep)
 command('equip '..rod[1],'equipped',function(equipped)
  assert(equipped.equipped,'Could not equip '..rod[2])
  command('mark','marked',function()
   local before=#texts;g_game.talk(SPELL[element][1])
   later(550,function()
    command('damage','damage',function(result)nextStep(result,channelRefusal(before))end)
   end)
  end)
 end)
end
local function finish()
 command('cleanup','cleaned',function(receipt)
  assert(receipt.restored);finishing=true;g_game.safeLogout()
  wait('clean logout',function()return not g_game.isOnline()end,function()
   finished=true;print('RODS_NATIVE_OK '..json.encode(evidence));g_app.exit()
  end)
 end)
end
local function levels()
 command('levels','levels',function(result)evidence.levels=result.checked;finish()end)
end
local function arcanist()
 command('class arcanist','class',function()
  each(RODS,function(rod,nextRod)
   command('equip '..rod[1],'equipped',function(r)
    assert(r.equipped and not r.weaponActive,'Arcanist treats '..rod[2]..' as its class weapon');nextRod()
   end)
  end,function()
   command('equip 12746','equipped',function(r)
    assert(r.equipped and r.weaponActive,'Arcanist lost its existing hex wand');evidence.classes.arcanist='rods rejected, hex wand accepted';levels()
   end)
  end)
 end)
end
local function essenceLash()
 command('equip 12857','equipped',function()
  command('mark','marked',function()
   local before=#texts;g_game.talk('exori vita')
   later(550,function()
    command('damage','damage',function(result)
     for i=before+1,#texts do assert(not texts[i]:find('class weapon',1,true),'Essence Lash refused the wither rod')end
     assert(result.manaSpent>=9 and result.damage>0,'Essence Lash did not cast with the wither rod: '..json.encode(result))
     evidence.essenceLash={damage=result.damage,manaSpent=result.manaSpent};later(6000,arcanist)
    end)
   end)
  end)
 end)
end
local function wrongSpells()
 each({RODS[1],RODS[3],RODS[6]},function(rod,nextRod)
  local element=WRONG[rod[3]]
  cast(rod,element,function(result,refused)
   assert(refused and result.manaSpent<SPELL[element][2]-4,rod[2]..' channelled a '..element..' spell: '..json.encode(result))
   evidence.wrongElement[#evidence.wrongElement+1]=rod[2]..' / '..element;later(2300,nextRod)
  end)
 end,essenceLash)
end
local function spells()
 each(RODS,function(rod,nextRod)
  cast(rod,rod[3],function(result,refused)
   assert(not refused and result.damage>0 and result.manaSpent>=SPELL[rod[3]][2]-4,rod[2]..' did not channel its '..rod[3]..' spell: '..json.encode(result))
   evidence.spells[#evidence.spells+1]=rod[2];later(2300,nextRod)
  end)
 end,wrongSpells)
end
local function attacks()
 each(RODS,function(rod,nextRod)
  command('equip '..rod[1],'equipped',function()
   command('attack','attacking',function()
    later(2700,function()
     command('stop','stopped',function(result)
      -- One or two ordinary attacks fit in the window; each must be within the rod's range.
      local hits=result.damage>rod[6]and 2 or 1
      assert(result.damage>=rod[5]*hits and result.damage<=rod[6]*hits,rod[2]..' damage outside its range: '..json.encode(result))
      assert(result.manaSpent>0,rod[2]..' attacked without spending mana')
      evidence.attacks[#evidence.attacks+1]={rod=rod[2],damage=result.damage,hits=hits,manaSpent=result.manaSpent};later(400,nextRod)
     end)
    end)
   end)
  end)
 end,spells)
end
local function lifekeeper()
 command('class lifekeeper','class',function()
  each(RODS,function(rod,nextRod)
   command('equip '..rod[1],'equipped',function(r)
    assert(r.equipped and r.weaponActive,'Lifekeeper does not accept '..rod[2]);nextRod()
   end)
  end,function()
   command('equip 12746','equipped',function(wand)
    assert(wand.equipped and not wand.weaponActive,'Lifekeeper accepts a wand')
    command('equip 2182','equipped',function(snake)
     assert(snake.equipped and snake.weaponActive,'Lifekeeper lost its existing snakebite rod')
     evidence.classes.lifekeeper='all rods accepted, hex wand rejected';attacks()
    end)
   end)
  end)
 end)
end
later(200,function()
 assert(LOCAL_PASSIVES_TEST and Services.updater==''and g_resources.getLayout()=='retro')
 connect(g_game,{onGameStart=function()
  EnterGame.hide();wait('passive handshake',function()return modules.game_passives.getState().ready end,function()
   later(500,function()
    -- The client must know every new item, with its own sprite.
    for _,rod in ipairs(RODS)do
     local cid=11887+rod[1]-12850;local thing=g_things.getThingType(cid,ThingCategoryItem)
     assert(thing and thing:getId()==cid,'Client has no definition for '..rod[2])
    end
    evidence.clientDefinitions=#RODS
    command('static','static',function(static)
     evidence.loot=static.lootChances;evidence.ashenRequiemDonor=static.ashenRequiemDonor
     command('setup','ready',function(ready)evidence.level=ready.level;lifekeeper()end)
    end)
   end)
  end)
 end,onTextMessage=function(_,text)
  local raw=text:match('^RODS_QA (.+)$')
  if not raw then texts[#texts+1]=text;return end
  local r=json.decode(raw);if r.label=='FAILED'then print(text);fail(r.reason)else receipts[r.label]=r end
 end,onLoginError=function(e)fail(e)end,onConnectionError=function(e)if not finishing and not finished then fail(e)end end})
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 G.account,G.password='passivetest','passivetest'
 local login=ProtocolLogin.create();_G.rodsNativeLogin=login
 login.onLoginError=function(_,e)fail(e)end
 login.onCharacterList=function(_,characters)
  for _,c in ipairs(characters)do if c.name=='Passive Tester'then
   assert(c.worldIp=='127.0.0.1'and c.worldPort==7175,'Unexpected rods test world')
   g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return
  end end
  fail('Owned Passive Tester absent')
 end
 login:login('127.0.0.1',7174,G.account,G.password,'',false)
end)
scheduleEvent(function()if not finished then fail('Rods native 170s timeout')end end,170000)
