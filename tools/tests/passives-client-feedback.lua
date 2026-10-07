-- Native controller/UI regression with scripted transport, never a live player.
-- Verifies timeout/late-authority handling, visible modal feedback, cooldown
-- wording and actual 800x600 scrolling. Live combat retry is a separate probe.
assert(LOCAL_PASSIVES_TEST and Services.updater=='' and g_resources.getLayout()=='retro')
assert(not g_game.isOnline(),'Feedback preview must remain offline')
local mod, choice, spells, state, trees, protocol
local sent, original, freshCounter = {}, {}, 0
local failed, finished = false, false
local function restore()
  for name,value in pairs(original)do g_game[name]=value end
end
local function fail(reason)
  if failed or finished then return end
  failed=true;print('PASSIVES_PREVIEW_FAILED '..tostring(reason))
  restore();scheduleEvent(function()g_app.exit()end,100)
end
local function later(ms,fn)
  scheduleEvent(function()
    if failed or finished then return end
    local ok,error=pcall(fn);if not ok then fail(error)end
  end,ms)
end
local function copy(r)local out={};for id,rank in pairs(r or {})do out[id]=rank end;return out end
local function same(a,b)
  for id,rank in pairs(a)do if rank~=(b[id]or 0)then return false end end
  for id,rank in pairs(b)do if rank~=(a[id]or 0)then return false end end
  return true
end
local function packet(data)
  data.v=1;ProtocolGame.onExtendedOpcode(protocol,103,json.encode(data))
end
local function snapshot(values)
  local s={v=1,action='snapshot',session=state.session,revision=state.revision,
    ranks=copy(state.ranks),points=24,active=true,mode='test',
    schemaVersion=state.tree.schemaVersion or 1,catalogVersion=state.tree.catalogVersion or 1,nodeCount=#state.tree.nodes}
  for key,value in pairs(values or {})do s[key]=value end
  return s
end
local function result(id,ok,s,error)
  packet({action='result',session=state.session,requestId=id,ok=ok,snapshot=s,error=error})
end
local function catalogPacket(id,token)
  local encoded=json.encode({v=1,action='catalog',session=token,tree=trees[id]})
  local size=3500;local total=math.ceil(#encoded/size)
  for index=1,total do
    packet({action='catalog_part',session=token,transfer=token,total=total,index=index,
      data=encoded:sub((index-1)*size+1,index*size)})
  end
  assert(state.session==token and state.tree.id==id,'Catalog/transfer was rejected')
end
local function fresh(id)
  freshCounter=freshCounter+1
  local token='feedback-'..id..'-'..freshCounter
  catalogPacket(id,token)
  packet(snapshot({revision=1,ranks={}}))
  assert(mod.show())
end
local function visible(widget,viewport,label)
  local r=widget:getRect()
  assert(r.x>=viewport.x-1 and r.y>=viewport.y-1 and r.x+r.width<=viewport.x+viewport.width+1 and
    r.y+r.height<=viewport.y+viewport.height+1,label..' clipped')
end
local verifySpells,verifyChoice,verifyScroll,verifyDraft
local function verifyFirstPermanent()
  local token='feedback-first-permanent'
  catalogPacket('reaver',token)
  assert(not state.active and not mod.changeRank(1,'minor_vitality'),'Catalog without authoritative mode permits first allocation')
  packet(snapshot({revision=1,ranks={},mode='permanent',respecCost=0,respecCount=0,classLocked=true}))
  assert(not mod.getWindow()or not mod.getWindow():isVisible(),'Passive restoration opened the full tree without explicit Open')
  assert(mod.show()and mod.selectNode('minor_vitality'))
  assert(mod.changeRank(1,'minor_vitality')and mod.changeRank(-1,'minor_vitality'),'Unapplied first rank cannot be undone')
  assert(state.respecCount==0 and not next(state.ranks),'Draft undo changes saved state or consumes Respec')
  assert(mod.changeRank(1,'minor_vitality'))
  local rank=mod.getWindow():recursiveGetChildById('nodeRank'):getText()
  local description=mod.getWindow():recursiveGetChildById('nodeDescription'):getText()
  assert(rank:find('Draft',1,true)and rank:find('Saved: 0',1,true)and description:find('Preview only',1,true),'First draft falsely presented as active talent')
  assert(mod.apply());local id=state.pending
  packet(snapshot({mode='permanent',respecCost=0,respecCount=0,classLocked=true}))
  assert(state.pending==id and state.draft.minor_vitality==1 and not next(state.ranks),'Unchanged first snapshot lost pending draft')
  result(id,true,snapshot({revision=2,ranks={minor_vitality=1},mode='permanent',respecCost=0,respecCount=0,classLocked=true}))
  assert(state.ranks.minor_vitality==1 and not mod.changeRank(-1,'minor_vitality'),'First Apply reply allows saved-rank undo before free Respec')
  assert(state.respecCount==0 and state.respecCost==0,'First Apply consumes free Respec')
  local reset=mod.getWindow():recursiveGetChildById('resetButton')
  assert(reset:isEnabled()and reset:getText()=='Respec (free)','First saved tree does not offer explicit free Respec')
  local before=#sent;mod.hide()
  packet({action='refresh',session='feedback-after-death'})
  assert(#sent==before+1 and sent[#sent].action=='snapshot','Automatic restoration requests Open instead of silent synchronization')
  assert(not mod.getWindow():isVisible(),'Automatic refresh opened the full tree')
  print('PASSIVES_CLIENT_FIRST_APPLY_LOCK_OK permanentMode=true pendingSnapshot=true firstFreeRespec=true automaticRefreshSilent=true')
end
verifySpells=function()
  local mana,right,left,ammo=0,nil,nil,nil
  local player={getMana=function()return mana end,
    -- The ordinary battle-panel timer also reads these while the controller's
    -- scripted online gate is active. The real offline map remains empty.
    getPosition=function()return {x=32000,y=32000,z=7}end,getId=function()return 0 end,
    getInventoryItem=function(_,slot)
    if slot==InventorySlotRight then return right elseif slot==InventorySlotLeft then return left
    elseif slot==InventorySlotAmmo then return ammo end
  end}
  g_game.getLocalPlayer=function()return player end
  local entries={}
  for index,id in ipairs({'cleaving_arc','rend'})do
    entries[index]={id=id,name=index==1 and 'Cleaving Arc'or'Rend',words=index==1 and'exori sec arc'or'exori sec vul',
      mana=index==1 and 18 or 12,cooldown=4000,range=1,kind='combat',description='Controller feedback fixture.',
      icon='/images/game/passives/major_pressure'}
  end
  assert(spells.receive({v=1,action='class_spells',classId='reaver',className='Reaver',spells=entries},'reaver'))
  assert(spells.show())
  local card=spells.getCard('cleaving_arc')
  assert(card:getChildById('cooldown'):getText():find('Cooldown ready | No mana',1,true),'zero mana shown as Ready')
  assert(card:getChildById('gear'):getText():find('equipped axe',1,true),'class gear hint missing')
  assert(not card:getChildById('gear'):getText():find('right hand',1,true),'hint incorrectly restricts weapon hand')
  mana=100
  later(300,function()
    assert(card:getChildById('cooldown'):getText():find('Equip your class weapon',1,true),'empty hand feedback stale')
    left={}
    later(300,function()
    assert(card:getChildById('cooldown'):getText()=='Cooldown ready','valid left-hand equipment falsely marked missing')
    left=nil;right={};state.classId='reaver';state.runtime.weaponActive=false
    later(300,function()
      assert(card:getChildById('cooldown'):getText():find('Class weapon required',1,true),'server weapon hint ignored')
      state.runtime.weaponActive=true
      later(300,function()
        assert(card:getChildById('cooldown'):getText()=='Cooldown ready','cooldown incorrectly claims full eligibility')
        assert(spells.receive({v=1,action='class_spell_cooldown',id='cleaving_arc',kind='combat',duration=300},'reaver'))
        assert(not card:getChildById('cast'):isEnabled(),'authoritative exhaustion not enforced')
        later(500,function()
          assert(card:getChildById('cast'):isEnabled(),'cast did not recover after real timer expiry')
          print('PASSIVES_CLIENT_SPELL_FEEDBACK_OK')
          spells.reset();choice.reset();mod.terminate();restore();finished=true
          print('PASSIVES_CLIENT_FEEDBACK_OK');print('PASSIVES_NATIVE_PREVIEW_OK');g_app.exit()
        end)
      end)
    end)
    end)
  end)
end
verifyChoice=function()
  mod.hide()
  local ids={'reaver','blademaster','earthshaker','marksman','arcanist','lifekeeper'}
  local classes={}
  for _,id in ipairs(ids)do classes[#classes+1]={id=id,name=id,weapon='Class weapon',tagline='Playstyle',
    description='Controller feedback fixture.',allowed=true,reason='',outfit={type=128,head=0,body=0,legs=0,feet=0,addons=0}}end
  local offer='feedback-modal-offer'
  assert(choice.receive({v=1,action='class_choice_offer',offer=offer,ttlMs=30000,classes=classes,consequences='Your class is permanent.'}))
  assert(choice.selectLocal('reaver') and choice.choose())
  assert(choice.receive({v=1,action='class_choice_confirm',offer=offer,selectedId='reaver',revision=1,name='reaver',consequences='Your class is permanent.'}))
  local box=assert(choice.getConfirmation())
  local label=assert(box:getChildById('status'))
  visible(label,box:getRect(),'confirmation feedback')
  assert(choice.confirm())
  assert(label:getText():find('Waiting',1,true),'waiting hidden behind modal')
  assert(choice.receive({v=1,action='class_choice_result',offer=offer,ok=false,error='Leave combat before choosing your class.'}))
  assert(label:getText():find('Leave combat',1,true),'rejection hidden behind modal')
  assert(box:getChildById('confirmButton'):isEnabled(),'rejected confirmation cannot retry')
  later(200,function()
  g_app.doScreenshot('/class-choice-visible-error.png')
  assert(choice.confirm())
  later(8250,function()
    assert(label:getText():find('No response',1,true),'timeout hidden behind modal')
    assert(not box:getChildById('confirmButton'):isEnabled(),'timed-out confirm can resend')
    assert(box:getChildById('backButton'):getText()=='Close' and box:getChildById('backButton'):isEnabled(),'timeout recovery missing')
    g_app.doScreenshot('/class-choice-visible-timeout.png')
    assert(choice.back() and not choice.getConfirmation(),'timeout Close failed')
    assert(not choice.receive({v=1,action='class_choice_confirm',offer=offer,selectedId='reaver',revision=2,name='reaver',consequences='Your class is permanent.'}),'late modal reopened retired offer')
    print('PASSIVES_CLIENT_MODAL_FEEDBACK_OK');verifySpells()
  end)
  end)
end
verifyScroll=function()
  local order={'reaver','blademaster','earthshaker','marksman','arcanist','lifekeeper'}
  local function tree(index)
    if index>#order then verifyChoice();return end
    fresh(order[index])
    later(150,function()
      local w=mod.getWindow();local bar=w:recursiveGetChildById('treeVertical')
      local horizontal=w:recursiveGetChildById('treeHorizontal')
      local view=w:recursiveGetChildById('treeScroll')
      assert(g_ui.getRootWidget():getWidth()==800 and g_ui.getRootWidget():getHeight()==600,'not actual 800x600')
      assert(bar:getValue()==bar:getMaximum(),'empty upward tree did not start at bottom')
      for _,node in ipairs(state.tree.nodes)do if node.type=='minor'then
        visible(mod.getNodeWidget(node.id).nodeCaption,view:getPaddingRect(),'initial '..node.name)
      end end
      g_app.doScreenshot('/passives-'..order[index]..'-minimum-bottom.png')
      packet(snapshot({revision=2,ranks={minor_precision=1}}))
      bar:setValue(math.floor(bar:getMaximum()/2));horizontal:setValue(horizontal:getMinimum())
      local saved=bar:getValue()
      mod.hide();mod.show();packet({action='runtime',session=state.session,weaponActive=true})
      later(100,function()
        assert(bar:getValue()==saved,'reopen/runtime moved user scroll')
        catalogPacket(order[index],state.session);packet(snapshot());mod.show()
        later(100,function()
        assert(bar:getValue()==saved,'same-session open/catalog replay moved user scroll')
        local function node(n)
          if n>#state.tree.nodes then
            print('PASSIVES_CLIENT_SCROLL_OK '..order[index]);tree(index+1);return
          end
          local info=state.tree.nodes[n];assert(mod.selectNode(info.id))
          later(80,function()
            visible(mod.getNodeWidget(info.id),view:getPaddingRect(),'selected frame '..info.name)
            visible(mod.getNodeWidget(info.id).nodeCaption,view:getPaddingRect(),'selected name '..info.name)
            node(n+1)
          end)
        end
        node(1)
        end)
      end)
    end)
  end
  tree(1)
end
verifyDraft=function()
  verifyFirstPermanent()
  fresh('reaver')
  assert(mod.changeRank(1,'minor_vitality') and mod.changeRank(1,'minor_vitality'))
  local draft=copy(state.draft)
  assert(mod.apply());local id=state.pending
  result(id,false,snapshot(),'Leave combat before changing your test build.')
  assert(not state.pending and same(draft,state.draft) and not next(state.ranks),'rejection lost draft or changed saved ranks')
  assert(mod.apply());id=state.pending
  result(id,true,snapshot({revision=2,ranks=draft}))
  assert(same(draft,state.ranks) and same(draft,state.draft),'retry changed submitted ranks')
  packet(snapshot({revision=3,ranks={}}))
  assert(mod.changeRank(1,'minor_vitality') and mod.changeRank(1,'minor_vitality'))
  assert(mod.apply());id=state.pending
  packet(snapshot())
  assert(state.pending==id and same(draft,state.draft),'unsolicited unchanged snapshot discarded pending draft')
  later(5250,function()
    assert(not state.pending and same(draft,state.draft),'timeout discarded current draft')
    assert(mod.changeRank(1,'minor_precision'));local newer=copy(state.draft)
    result(id,false,snapshot(),'Delayed rejection')
    assert(same(newer,state.draft),'late rejection resurrected/replaced draft')
    result(id,true,snapshot({revision=4,ranks=draft}))
    assert(same(draft,state.ranks) and same(draft,state.draft),'late authoritative success did not win')
    assert(mod.changeRank(1,'minor_precision') and mod.apply());local current=state.pending
    result(id,false,snapshot(),'Older response')
    assert(state.pending==current and state.draft.minor_precision==1,'older unchanged reply killed newer request')
    result(id,true,snapshot({revision=5,ranks={minor_vitality=1}}))
    assert(not state.pending and state.ranks.minor_vitality==1 and not state.draft.minor_precision,'older reply with newer authority was lost')
    packet(snapshot({revision=6,ranks={}}))
    assert(mod.changeRank(1,'minor_vitality') and mod.changeRank(1,'minor_vitality') and mod.apply())
    result(state.pending,false,snapshot({points=1}),'Point budget changed')
    assert(not next(state.draft),'lower budget retained illegal draft')
    local old=state.session
    fresh('blademaster')
    packet({action='snapshot',session=old,revision=999,ranks={minor_vitality=5},points=24,active=true})
    assert(state.tree.id=='blademaster' and not next(state.ranks),'retired session regained authority')
    print('PASSIVES_CLIENT_DRAFT_AUTHORITY_OK');verifyScroll()
  end)
end
later(1000,function()
  mod=assert(modules.game_passives);mod.terminate();mod.init()
  state=mod.getState();state.ready=true
  choice=mod.getClassChoice();spells=mod.ClassSpells
  trees=json.decode(g_resources.readFileContents('/passives-preview-trees.txt'))
  -- Class portraits need the same 8.60 DAT/SPR load as a real login. This remains
  -- offline; an invalid asset load must fail the native gate, not hide portraits.
  g_game.setClientVersion(860);g_game.setProtocolVersion(860)
  assert(modules.game_things.isLoaded(),'Native 8.60 things/sprites not loaded')
  g_settings.set('passivesTestShowStatus',false);g_settings.set('window-maximized',false)
  g_window.setMinimumSize({width=800,height=600});g_window.resize({width=800,height=600})
  protocol={sendExtendedOpcode=function(_,opcode,buffer)assert(opcode==103);sent[#sent+1]=json.decode(buffer)end}
  for _,name in ipairs({'isOnline','getProtocolGame','getLocalPlayer','talk'})do original[name]=g_game[name]end
  g_game.isOnline=function()return true end;g_game.getProtocolGame=function()return protocol end
  g_game.talk=function()end
  later(400,verifyDraft)
end)
scheduleEvent(function()if not finished then fail('Feedback preview exceeded 40 seconds')end end,40000)
