-- Offline actual native widgets, hit testing, 8.60 DAT/SPR and forge source.
-- The wrapper pins the supplied source files and preserves the owned profile.
-- Opcode responses are supplied snapshots: no server payment/gameplay proof.
-- Pointer checks use native hit testing plus the registered UIWidget hover
-- signal. This fixture does not move the operating-system mouse.
assert(LOCAL_PASSIVES_TEST and not g_game.isOnline())
if modules.client_discord then modules.client_discord.terminate() end

local realGame, realUI, root = g_game, g_ui, g_ui.getRootWidget()
local forgeWindow, forgeEnv, callback, completed
local requests, notifications, menuHooks, screenshots, checks, sourceSha1 = {}, {}, {}, {}, {}, {}
local currentStep = 'startup'
local function copy(value) return json.decode(json.encode(value)) end
local function normalize(value) return (value or ''):gsub('%s+', ' ') end
local function source(path, environment)
  local value = g_resources.readFileContents(path)
  sourceSha1[path] = g_crypt.sha1Encode(value)
  local chunk = assert(loadstring(value, '@' .. path))
  setfenv(chunk, environment); chunk()
end
local function fail(reason)
  if completed then return end
  completed = true
  print('FORGOTTEN_WORKS_UI_NATIVE_FAILED ' .. currentStep .. ': ' .. tostring(reason))
  if forgeEnv then pcall(forgeEnv.terminate) end
  pcall(g_tooltip.hide)
  scheduleEvent(function() g_app.exit() end, 100)
end
local function later(ms, fn)
  scheduleEvent(function()
    if completed then return end
    local ok, reason = pcall(fn)
    if not ok then fail(reason) end
  end, ms)
end
local function widget(id) return assert(forgeWindow:recursiveGetChildById(id), 'Missing native control ' .. id) end
local function click(control)
  assert(control and control:isVisible() and control:isEnabled(), 'Native control unavailable')
  signalcall(control.onClick, control)
end
local function inside(control, parent)
  local a, b = control:getRect(), parent:getRect()
  return a.x >= b.x and a.y >= b.y and a.x + a.width <= b.x + b.width and a.y + a.height <= b.y + b.height
end
local function ensureReachable(control)
  local parent = control:getParent()
  while parent do
    if type(parent.ensureChildVisible) == 'function' then parent:ensureChildVisible(control) end
    parent = parent:getParent()
  end
end
local function shot(name)
  g_app.doScreenshot('/' .. name .. '.png'); screenshots[#screenshots + 1] = name
end
local function box(title)
  for _, child in ipairs(root:getChildren()) do
    if child:isVisible() and child:getText() == title then return child end
  end
end
local function boxButton(dialog, title)
  for _, button in ipairs(assert(dialog:getChildById('buttonHolder')):getChildren()) do
    if button:getText() == title then return button end
  end
end
local function dialogText(dialog)
  local values = {}
  local function collect(control)
    values[#values + 1] = control:getText() or ''
    for _, child in ipairs(control:getChildren()) do collect(child) end
  end
  collect(dialog)
  return normalize(table.concat(values, '\n'))
end
local function closeInfo(dialog)
  local button = boxButton(dialog, 'Close') or boxButton(dialog, 'Ok') or boxButton(dialog, 'OK')
  click(assert(button, 'Details dialog has no close control'))
  assert(dialog:isDestroyed() or not dialog:isVisible(), 'Details dialog did not close')
end
local protocol = {}
function protocol:sendExtendedOpcode(opcode, buffer)
  assert(opcode == 98); requests[#requests + 1] = json.decode(buffer)
end
local function receive(data, context)
  if type(data) == 'table' then
    data = copy(data)
    if data.action:match('^forgotten_') and data.clientSession == nil then
      context = context or requests[#requests] or {}
      data.clientSession, data.requestId = context.clientSession, context.requestId
    end
  end
  assert(callback)(protocol, 98, type(data) == 'string' and data or json.encode(data))
end
local function last(action)
  local request = assert(requests[#requests], 'No forge request captured')
  assert(request.action == action, 'Expected ' .. action .. ', got ' .. tostring(request.action))
  return request
end
local function assertNoConfirm(since)
  for index = since + 1, #requests do
    assert(requests[index].action ~= 'forgotten_confirm' and requests[index].action ~= 'smelt'
      and requests[index].action ~= 'reroll_confirm', 'Inspection/cancellation sent a consuming action')
  end
end

local keys = {'deepwarden','oath','ashcleaver','elders_reckoning','forgeheart','mountains_verdict',
  'wayfarer','deepforge_arbalest','stonewake','ashen_requiem'}
local names = {'Deepwarden','Oath of the Deep','Ashcleaver',"Elder's Reckoning",'Forgeheart',
  "Mountain's Verdict",'Wayfarer','Deepforge Arbalest','Stonewake','Ashen Requiem'}
local recipes = {}
for index, key in ipairs(keys) do
  recipes[index] = {key=key,name=names[index],clientId=11867+index,donorId=3963,donorClientId=3345,
    donorName='templar scytheblade'}
end
local core = {requiredMs=13500000,regions={}}
for _, label in ipairs({'Dwarven Depths','Barbarian Camps','Dragon Lairs','Lava Depths'}) do
  core.regions[#core.regions+1] = {label=label,earnedMs=13500000,neededMs=13500000}
end
local preview = {action='forgotten_preview',success=true,recipeKey='deepwarden',name='Deepwarden',clientId=11868,
  donorName='templar scytheblade',donor={id=3963,clientId=3345,name='epic templar scytheblade',
    valid=true,affixes={'Attack: +5','Sword skill: +2'}},
  resultStats={summary='ATK 30  DEF 16 +1\nLevel 35  One-handed sword',
    details='ATK 30 includes the inherited Attack +5 roll.\nBase ATK 25; DEF 16; extra DEF +1.\nLevel 35. One-handed sword.',
    inheritedAffixes={'Attack: +5','Sword skill: +2'}},
  signature={name='Swordguard',text='Normal attacks have a 12% chance to ready Swordguard for 4 seconds. Your next ordinary melee physical hit taken is reduced by 50%, up to 16 damage against creatures or 8 against players. Cooldown: 12 seconds.'},
  signatureRule='Only paid normal weapon attacks trigger a signature. Cooldown is shared across Legendary weapons and survives swapping or logging out. Extra damage does not trigger another signature.',
  activityHelp='Effective personal forge activity. Hunt eligible creatures in each region. A real kill credits at most one minute, with up to five minutes between kills. More than 14 hours of stamina is required. Eligible unlocked party members share the credit; offline time does not count.',
  requirements={{clientId=11878,name='Iron Echo',owned=300,required=300},{clientId=11879,name='Warbrand',owned=200,required=200},
    {clientId=11880,name='Scale Ash',owned=100,required=100},{clientId=11881,name='Cinder Glass',owned=200,required=200},
    {clientId=11831,name='light blue crystal fragment',owned=100,required=100},
    {clientId=11830,name='red crystal fragment',owned=100,required=100},
    {clientId=11834,name='pristine forging shard',owned=1,required=1}},
  goldRequired=20000,goldOwned=20000,core=core,canCraft=true,message='Ready to forge.'}
-- Exact player-facing strings from server data/lib/core/forgotten_works_config.lua.
-- These exercise the longest real paragraphs without running their combat logic.
local longSignatures = {
  {index=9,key='stonewake',name='Stonewake',donorName='jade wand',signature={name='Living Bark',
    text='Normal attacks have a 12% chance to ready Living Bark for 8 seconds. Each of the next two direct hits absorbs up to 6 HP damage against creatures or 3 against players, within the shared ward limit. Total protection is capped at 12 or 6 HP; unused protection expires. Cooldown: 12 seconds.'}},
  {index=10,key='ashen_requiem',name='Ashen Requiem',donorName='necrotic rod',signature={name='Soul Draw',
    text='Normal attacks have a 12% chance to deal 30% extra death damage before critical bonuses, up to 12, and restore 20% of the actual HP damage dealt by the main hit and Soul Draw, up to 8 health. Damage absorbed by a mana shield does not heal you. Cooldown: 12 seconds.'}}
}
local function snapshot(extra)
  local data = {action='forgotten_snapshot',v=1,success=true,unlocked=true,questStage=2,recipes=recipes,core=core}
  for key, value in pairs(extra or {}) do data[key] = value end
  return data
end
local function emptyPreview()
  local data = copy(preview); data.donor=nil; data.canCraft=false
  data.resultStats.inheritedAffixes={}; data.resultStats.summary='ATK 25  DEF 16 +1\nLevel 35  One-handed sword'
  data.message='Place the required Epic weapon from your backpack into the forge.'
  return data
end
local function dropDonor()
  local item = {getId=function() return 3345 end,getPosition=function() return {x=65535,y=64,z=0} end}
  assert(widget('forgottenDonor').onDrop(nil,{getItem=function() return item end}), 'Matching donor refused by UI')
  assert(last('forgotten_preview').donor.id == 3963)
  assert(not widget('forgottenCraftButton'):isEnabled(), 'Pending donor preview retained crafting readiness')
  for _, id in ipairs({'forgottenWeaponDetailsButton','forgottenEffectDetailsButton','forgottenActivityDetailsButton'}) do
    assert(not widget(id):isEnabled(), 'Pending donor preview retained obsolete details: ' .. id)
  end
  assert(widget('forgottenStats'):getText():find('Inspecting',1,true), 'Pending donor preview displayed previous weapon rolls')
  assert(widget('forgottenStatus'):getText():find('Inspecting',1,true), 'Pending donor preview displayed previous readiness')
  assert(not widget('forgottenStats'):getTooltip() or widget('forgottenStats'):getTooltip() == '', 'Pending donor retained previous roll tooltip')
  receive(preview)
end
local function selection(expectedKey)
  local selected = 0
  -- Native Color's byte conversion truncates one unit (setRed uses 0.003921).
  -- Compare getter channels directly; colortostring adds another conversion.
  local function tint(actual,r,g,b)
    return math.abs(actual.r-r)<=1 and math.abs(actual.g-g)<=1 and math.abs(actual.b-b)<=1 and math.abs(actual.a-255)<=1
  end
  for _, row in ipairs(widget('forgottenRecipes'):getChildren()) do
    local actual = row:getImageColor()
    local color = json.encode(actual)
    if row.recipeKey == expectedKey then
      selected=selected+1
      assert(row:isOn(), 'Current design lost OnState')
      assert(tint(actual,225,211,161), 'Current design lost selected tint: ' .. color)
      assert(row:getChildById('stateLabel'):getText() == 'Selected', 'Selected design has no textual indicator')
    else
      assert(not row:isOn(), 'Another design retained OnState')
      local neutral = tint(actual,180,180,180)
      local hover = row:isHovered() and tint(actual,208,208,208)
      assert(neutral or hover, 'Deselected design retained rendered tint: ' .. row.recipeKey .. ' ' .. color)
      assert(row:getChildById('stateLabel'):getText() == '', 'Deselected design retained selected indicator')
    end
  end
  assert(selected == 1, 'Exactly one design must be selected')
end
local function selectedRowVisible(expectedKey)
  for _, row in ipairs(widget('forgottenRecipes'):getChildren()) do
    if row.recipeKey == expectedKey then
      assert(inside(row,widget('forgottenRecipes')), 'Selected design scrolled outside browser: ' .. expectedKey)
      return
    end
  end
  error('Selected design is absent from browser: ' .. expectedKey)
end
local function layoutChecks()
  assert(inside(forgeWindow, root), 'Forge outside supported native viewport')
  local forgotten = widget('forgottenPanel'):isVisible()
  local ids = forgotten and {'forgottenRefreshButton','forgottenCraftButton','forgottenCloseButton'}
    or {'clearButton','smeltButton','closeButton'}
  for _, id in ipairs(ids) do assert(inside(widget(id),forgeWindow), 'Footer clipped: ' .. id) end
  if forgotten then
    for _, id in ipairs({'forgottenName','forgottenDescription','forgottenStats','forgottenSignature',
      'forgottenEffect','forgottenRule','forgottenStatus'}) do
      local label=widget(id)
      assert(label:getTextSize().height <= label:getHeight(), 'Wrapped native text clipped: ' .. id)
      assert(not normalize(label:getText()):lower():find('hover for',1,true), 'Essential information still requires unexplained hover')
    end
    local costs=widget('forgottenMaterials')
    assert(type(costs.ensureChildVisible) ~= 'function', 'Materials still have a nested scroll area')
    for _, row in ipairs(costs:getChildren()) do assert(inside(row,costs), 'Material row outside grown cost panel') end
  elseif widget('resultLabel'):getText() ~= '' then
    local result=widget('resultLabel')
    local footerTop=math.min(widget('clearButton'):getY(),widget('smeltButton'):getY(),widget('closeButton'):getY())
    assert(result:getTextSize().height <= result:getHeight(), 'Smelting yield text is clipped')
    assert(result:getY()+result:getHeight() <= footerTop, 'Smelting yield text overlaps footer controls')
  end
end
local function screenshotSizes(name, done, target)
  g_window.resize({width=1280,height=800})
  later(150,function()
    if target then ensureReachable(target) end
    later(150,function()
      layoutChecks(); shot(name .. '-1280x800')
      later(150,function()
        g_window.resize({width=800,height=640})
        later(150,function()
          if target then ensureReachable(target) end
          later(150,function() layoutChecks(); shot(name .. '-800x640'); later(150,done) end)
        end)
      end)
    end)
  end)
end
local function detailsCheck(id,title,required,name,done)
  local before=#requests
  ensureReachable(widget(id))
  later(120,function()
    click(widget(id)); local dialog=assert(box(title),'Details dialog missing: ' .. title)
    local body=dialogText(dialog)
    for _, needle in ipairs(required) do
      assert(body:find(normalize(needle),1,true),'Current details missing: ' .. needle)
    end
    assert(#requests == before,'Reading details sent a forge request')
    assert(inside(dialog,root),'Details dialog clipped at supported compact viewport')
    later(150,function()
      assert(dialog:isVisible() and not dialog:isDestroyed(), 'Details dialog disappeared before native render')
      shot(name .. '-800x640')
      later(150,function()
        closeInfo(dialog); assert(#requests == before,'Closing details sent a forge request'); done()
      end)
    end)
  end)
end
local function quote(expires)
  click(widget('forgottenCraftButton')); last('forgotten_quote')
  receive({action='forgotten_quote',success=true,token='offline-ui-fixture-only',expiresIn=expires or 30,
    preview=preview,warning='The donor is replaced; its rolled affixes are retained.'})
  return assert(box('Confirm Forgotten Work'),'Native quote missing')
end

local steps={}
local function step(name,run) steps[#steps+1]={name=name,run=run} end
step('locked forge and quest guidance',function(done)
  click(widget('forgottenTab')); last('forgotten_open')
  receive(snapshot({unlocked=false,questStage=0,recipes={}}))
  assert(widget('forgottenName'):getText() == 'No discovered designs')
  assert(not widget('forgottenCraftButton'):isEnabled())
  screenshotSizes('forgotten-works-locked',done)
end)
step('unlock help is explicit and non-consuming',function(done)
  receive(snapshot({unlocked=false,questStage=1,recipes={}}))
  assert(widget('forgottenStatus'):getText():find('Old Forging Mould',1,true), 'Started quest has no current mould guidance')
  detailsCheck('forgottenUnlockButton','Unlock designs',{'Bolgrim'},'forgotten-works-unlock-guide',done)
end)
step('unlocked forge without a design',function(done)
  receive(snapshot({recipes={}}))
  assert(widget('forgottenDonor'):getItemId() == 0 and not widget('forgottenCraftButton'):isEnabled())
  assert(widget('forgottenStatus'):getText():find('Forging Page',1,true), 'Unlocked empty forge has no design-discovery guidance')
  assert(not widget('forgottenEffect'):getText():find('Swordguard',1,true), 'Empty snapshot retained old signature effect')
  assert(not widget('forgottenEffectDetailsButton'):isEnabled(), 'Empty snapshot retained signature details')
  screenshotSizes('forgotten-works-no-designs',done)
end)
step('all ten designs restore actual native tint',function(done)
  receive(snapshot()); assert(#widget('forgottenRecipes'):getChildren() == 10)
  local index=1
  local function nextRow()
    local row=widget('forgottenRecipes'):getChildren()[index]
    if not row then
      click(widget('forgottenRecipes'):getChildren()[1]); receive(emptyPreview())
      later(150,function() selection('deepwarden'); selectedRowVisible('deepwarden'); done() end); return
    end
    ensureReachable(row)
    later(80,function()
      click(row)
      later(80,function() selection(keys[index]); selectedRowVisible(keys[index]); index=index+1; nextRow() end)
    end)
  end
  nextRow()
end)
step('donor validation and active-design repeated click',function(done)
  local before=#requests
  local wrong={getId=function() return 3346 end,getPosition=function() return {x=65535,y=64,z=1} end}
  assert(not widget('forgottenDonor').onDrop(nil,{getItem=function() return wrong end}),'Wrong base weapon accepted by UI')
  assert(#requests == before,'Wrong base weapon sent a preview')
  dropDonor(); local bound=copy(last('forgotten_preview')); before=#requests
  click(widget('forgottenRecipes'):getChildren()[1])
  assert(#requests == before,'Clicking current design sent a new request')
  assert(widget('forgottenDonor'):getItemId() == 3345 and widget('forgottenCraftButton'):isEnabled(),'Clicking current design discarded donor/readiness')
  assert(bound.donor.pos.y == 64)
  assert(widget('forgottenEffect'):getText() == preview.signature.text,'Full signature effect is not visible in selected design')
  screenshotSizes('forgotten-works-ready',done,widget('forgottenSignature'))
end)
step('design change resets scrollbar and content offset together',function(done)
  local area,bar=widget('forgottenDetails'),widget('forgottenDetailsScrollbar')
  assert(bar:getMaximum() > bar:getMinimum(), 'Ready design has no scrollable detail content for regression')
  bar:setValue(bar:getMaximum())
  later(150,function()
    assert(area:getVirtualOffset().y == bar:getValue(), 'Bottom scroll content and thumb disagree')
    assert(bar:getValue() > bar:getMinimum(), 'Fixture did not reach bottom before design change')
    click(widget('forgottenRecipes'):getChildren()[2]); last('forgotten_preview')
    local other=emptyPreview(); other.recipeKey='oath'; other.name='Oath of the Deep'
    receive(other)
    later(150,function()
      local minimum=bar:getMinimum()
      assert(bar:getValue() == minimum, 'New design retained old scrollbar position')
      assert(area:getVirtualOffset().y == minimum, 'New design retained old content offset')
      assert(bar:getMaximum() >= minimum+bar:getStep(), 'Design content cannot exercise one complete wheel step')
      local rect=area:getRect()
      assert(signalcall(area.onMouseWheel,area,{x=rect.x+5,y=rect.y+5},MouseWheelDown), 'Detail wheel event was not handled')
      later(100,function()
        assert(bar:getValue() == minimum+bar:getStep(), 'One downward wheel event moved more than one step')
        assert(area:getVirtualOffset().y == bar:getValue(), 'Wheel event desynchronized thumb and content')
        click(widget('forgottenRecipes'):getChildren()[1]); receive(emptyPreview()); dropDonor()
        later(150,function() selectedRowVisible('deepwarden'); done() end)
      end)
    end)
  end)
end)
step('weapon detail disclosure',function(done)
  detailsCheck('forgottenWeaponDetailsButton','Weapon details',{'Attack +5','Level 35'},'forgotten-works-weapon-details',done)
end)
step('signature detail disclosure',function(done)
  detailsCheck('forgottenEffectDetailsButton','Signature details',{'12%','50%','shared across Legendary weapons','survives swapping'},'forgotten-works-signature-details',done)
end)
step('activity detail disclosure',function(done)
  detailsCheck('forgottenActivityDetailsButton','Forge activity',{'Dwarven Depths','14 hours','offline time does not count'},'forgotten-works-activity-details',done)
end)
step('longest real signature paragraphs and disclosures',function(done)
  local index=1
  local function nextSignature()
    local entry=longSignatures[index]
    if not entry then
      click(widget('forgottenRecipes'):getChildren()[1]); receive(emptyPreview()); dropDonor()
      later(150,function() selectedRowVisible('deepwarden'); done() end); return
    end
    click(widget('forgottenRecipes'):getChildren()[entry.index]); last('forgotten_preview')
    local data=emptyPreview(); data.recipeKey=entry.key; data.name=entry.name; data.clientId=11867+entry.index
    data.donorName=entry.donorName; data.signature=entry.signature
    data.resultStats.summary='Level 35  One-handed wand'; data.resultStats.details='Level 35. One-handed wand.'
    receive(data)
    assert(widget('forgottenEffect'):getText() == entry.signature.text, 'Real signature paragraph was truncated')
    later(150,function()
      selection(entry.key); selectedRowVisible(entry.key)
      screenshotSizes('forgotten-works-' .. entry.key .. '-effect',function()
        detailsCheck('forgottenEffectDetailsButton','Signature details',{entry.signature.text},
          'forgotten-works-' .. entry.key .. '-details',function() index=index+1; nextSignature() end)
      end,widget('forgottenEffect'))
    end)
  end
  nextSignature()
end)
step('native hover hit testing and registered hover handler',function(done)
  local target=widget('forgottenStats')
  assert(not target:isPhantom(),'Stats hover target is still phantom')
  ensureReachable(target)
  later(150,function()
    local rect=target:getRect(); local pos={x=rect.x+math.floor(rect.width/2),y=rect.y+math.floor(rect.height/2)}
    assert(root:recursiveGetChildByPos(pos,false) == target,'Native pointer hit test cannot reach stats label')
    local tip=target:getTooltip(); assert(tip and tip:find('Attack +5',1,true),'Current hover details missing')
    assert(not g_mouse.isPressed(),'External mouse button press prevents isolated hover check')
    signalcall(UIWidget.onHoverChange,target,true)
    later(150,function()
      local tooltip=assert(root:recursiveGetChildById('toolTip'))
      assert(tooltip:isVisible() and tooltip:getOpacity() > 0.9,'Registered widget hover handler did not show tooltip')
      assert(normalize(tooltip:getText()) == normalize(tip),'Hover showed obsolete or unrelated information')
      assert(inside(tooltip,root),'Actual hover tooltip clipped at compact viewport')
      shot('forgotten-works-native-hover-800x640')
      later(150,function() signalcall(UIWidget.onHoverChange,target,false); later(150,done) end)
    end)
  end)
end)
step('refresh retains donor and rejected quote replaces authoritative values',function(done)
  click(widget('forgottenRefreshButton')); last('forgotten_refresh'); receive(snapshot())
  assert(last('forgotten_preview').donor.id == 3963,'Refresh discarded bound donor'); receive(preview)
  click(widget('forgottenCraftButton')); local rejected=copy(last('forgotten_quote'))
  local changed=copy(preview); changed.requirements[1].owned=299; changed.goldOwned=19999; changed.canCraft=false
  changed.resultStats.summary='ATK 31  DEF 16 +1\nLevel 35  One-handed sword'
  changed.resultStats.inheritedAffixes={'Attack: +6','Sword skill: +2'}
  changed.resultStats.details='Updated authoritative result includes Attack +6.'
  receive({action='forgotten_quote',success=false,preview=changed,message='Your materials changed. Inspect the current costs.'})
  local rows=widget('forgottenMaterials'):getChildren()
  assert(rows[1]:getChildById('amountLabel'):getText() == '299 / 300','Failed quote retained outdated material count')
  assert(rows[8]:getChildById('amountLabel'):getText() == '19999 / 20000','Failed quote retained outdated gold count')
  assert(widget('forgottenStats'):getText():find('ATK 31',1,true) and not widget('forgottenCraftButton'):isEnabled())
  assert(widget('forgottenStatus'):getText():find('Your materials changed.',1,true),'Failed quote lost visible refusal reason')
  click(widget('forgottenRefreshButton')); receive(snapshot()); receive(preview)
  receive({action='forgotten_quote',success=false,preview=changed,message='Old rejected quote.'},rejected)
  assert(widget('forgottenStats'):getText():find('ATK 30',1,true) and widget('forgottenCraftButton'):isEnabled(),'Stale rejected quote overwrote current preview')
  done()
end)
step('quote, stale preview and cancellation preserve request semantics',function(done)
  local stale=copy(last('forgotten_preview')); local before=#requests; local dialog=quote()
  receive(preview,stale); assert(box('Confirm Forgotten Work') == dialog,'Stale preview closed current quote')
  g_window.resize({width=1280,height=800})
  later(150,function()
    assert(inside(dialog,root)); shot('forgotten-works-quote-1280x800')
    later(150,function()
      g_window.resize({width=800,height=640})
      later(150,function()
        assert(inside(dialog,root),'Quote clipped at compact viewport'); shot('forgotten-works-quote-800x640')
        later(150,function()
          click(assert(boxButton(dialog,'Cancel')))
          assert(requests[#requests-1].action == 'forgotten_cancel'); last('forgotten_preview')
          assertNoConfirm(before); receive(preview); assert(widget('forgottenDonor'):getItemId() == 3345); done()
        end)
      end)
    end)
  end)
end)
step('recipe changes invalidate quote, donor and obsolete details',function(done)
  local before=#requests; local dialog=quote()
  click(widget('forgottenRecipes'):getChildren()[2]); local selected=last('forgotten_preview')
  assert(selected.recipeKey == 'oath' and selected.donor == nil,'Different design retained incompatible donor')
  assert(dialog:isDestroyed() and not widget('forgottenCraftButton'):isEnabled(),'Different design retained old quote')
  assert(widget('forgottenEffect'):getText() == '' and not widget('forgottenEffectDetailsButton'):isEnabled(),'Loading design retained old effect/details')
  assert(not widget('forgottenStats'):getTooltip() or widget('forgottenStats'):getTooltip() == '','Loading design retained old stats tooltip')
  local other=emptyPreview(); other.recipeKey='oath'; other.name='Oath of the Deep'; other.signature={name='Oathguard',text='Current Oath effect fixture.'}
  receive(other); assert(widget('forgottenEffect'):getText() == 'Current Oath effect fixture.')
  selection('oath'); assertNoConfirm(before)
  click(widget('forgottenRecipes'):getChildren()[1]); receive(emptyPreview()); dropDonor(); done()
end)
step('donor right-click removal and real quote expiry',function(done)
  assert(widget('forgottenDonor').onMouseRelease(widget('forgottenDonor'),{x=0,y=0},MouseRightButton))
  assert(last('forgotten_preview').donor == nil and widget('forgottenDonor'):getItemId() == 0)
  assert(not widget('forgottenCraftButton'):isEnabled() and not widget('forgottenWeaponDetailsButton'):isEnabled(), 'Pending removal retained donor readiness/details')
  assert(widget('forgottenStats'):getText():find('Inspecting',1,true), 'Pending removal retained donor roll values')
  receive(emptyPreview()); assert(not widget('forgottenCraftButton'):isEnabled()); dropDonor()
  local before=#requests; local dialog=quote(1)
  later(1250,function()
    assert(dialog:isDestroyed(),'Expired quote remained interactive'); last('forgotten_preview')
    assertNoConfirm(before); receive(preview); done()
  end)
end)
step('closed craft result notification, reopen and response ordering',function(done)
  local stale=copy(last('forgotten_preview')); local dialog=quote(); click(assert(boxButton(dialog,'Forge')))
  local pending=copy(last('forgotten_confirm')); local old=forgeWindow; local count=#notifications
  forgeEnv.close(); assert(old:isDestroyed())
  receive({action='forgotten_result',success=true,message='Closed-window forging complete.'},pending)
  assert(#notifications == count+1 and notifications[#notifications] == 'Closed-window forging complete.')
  receive(preview,stale); receive({action='preview',entries={},totalCount=0,playerGold=20000})
  assert(forgeWindow == old,'Late preview reopened closed forge')
  receive({action='open',preview={entries={},totalCount=0,playerGold=20000}})
  click(widget('forgottenTab')); receive(snapshot()); local live=copy(last('forgotten_preview'))
  receive(snapshot({recipes={}}),stale); assert(#widget('forgottenRecipes'):getChildren() == 10,'Old snapshot changed reopened forge')
  receive({action='forgotten_quote',success=true,token='old-window-token',expiresIn=30,preview=preview},stale)
  assert(not box('Confirm Forgotten Work'),'Old quote opened in a new window')
  receive({action='forgotten_result',success=true,message='Closed-window forging complete.'},pending)
  assert(#notifications == count+1,'Closed result notification replayed')
  receive(emptyPreview(),live)
  receive({action='forgotten_result',success=false,message='Return to the lava forge and open it again.'},live)
  assert(widget('forgottenStatus'):getText():find('Return to the lava forge',1,true),'Current session failure ignored')
  assert(not widget('forgottenCraftButton'):isEnabled()); receive(emptyPreview(),live); dropDonor(); done()
end)
step('completed craft clears consumed donor without reopening quote',function(done)
  local dialog=quote(); click(assert(boxButton(dialog,'Forge'))); local confirmation=last('forgotten_confirm')
  assert(confirmation.token == 'offline-ui-fixture-only')
  receive({action='forgotten_result',success=true,message='The lava yields Deepwarden. Epic rolls preserved.',snapshot=snapshot()})
  assert(last('forgotten_preview').donor == nil,'Successful craft retained consumed donor')
  receive(emptyPreview())
  assert(widget('forgottenDonor'):getItemId() == 0 and not widget('forgottenCraftButton'):isEnabled())
  assert(widget('forgottenStatus'):getText():find('Forged Deepwarden. Epic rolls preserved.',1,true),'Follow-up preview discarded completion feedback')
  assert(not box('Confirm Forgotten Work'),'Completed craft reopened confirmation')
  screenshotSizes('forgotten-works-completed',done)
end)
step('original Smelting slot, clear and tempering cancellation paths',function(done)
  click(widget('smeltTab'))
  assert(#widget('slotsPanel'):getChildren() == 6,'Original six smelting slots changed')
  local before=#requests
  local offering={getId=function() return 3345 end,getPosition=function() return {x=65535,y=65,z=0} end}
  local dropped={getItem=function() return offering end}
  widget('slot1').onDrop(widget('slot1'),dropped); last('preview')
  assert(#requests[#requests].positions == 1 and requests[#requests].positions[1].itemId == 3345)
  local count=#requests; widget('slot2').onDrop(widget('slot2'),dropped)
  assert(#requests == count,'Duplicate Smelting offering sent another preview')
  receive({action='preview',entries={{pos={x=65535,y=65,z=0},itemId=3345,clientId=3345,name='epic templar scytheblade',tier='epic',tierLabel='Epic',fee=100}},
    totalCount=1,totalFee=100,playerGold=20000,counts={epic=1}})
  assert(widget('smeltButton'):isEnabled() and widget('slot1'):getChildById('item'):getItemId() == 3345)
  assert(widget('slot1').onMouseRelease(widget('slot1'),{x=0,y=0},MouseRightButton)); assert(#last('preview').positions == 0)
  widget('slot6').onDrop(widget('slot6'),dropped); last('preview'); click(widget('clearButton'))
  assert(#last('preview').positions == 0,'Clear Offerings retained a selected item')
  receive({action='preview',entries={},totalCount=0,totalFee=0,playerGold=20000})
  assert(not widget('smeltButton'):isEnabled()); assertNoConfirm(before)
  screenshotSizes('forgotten-works-smelting',function()
    local count=#requests
    local yields={{name='chaos ember',count=3},{name='primal tempering core',count=1},{name='legendary reforging stone',count=1}}
    receive({action='result',success=true,message='Smelting rite complete.',yields=yields,
      preview={entries={},totalCount=0,totalFee=0,playerGold=19900}})
    assert(#requests == count, 'Smelting result sent a new consuming request')
    for _, entry in ipairs(yields) do
      assert(widget('resultLabel'):getText():find(entry.name,1,true), 'Smelting result lost material yield: ' .. entry.name)
    end
    screenshotSizes('forgotten-works-smelting-yield',function()
      receive({action='reroll_prompt',materialName='Ember Dust',modeText='temper',targetName='longsword',tierLabel='rare'})
      local temper=assert(box('Confirm Tempering'))
      assert(inside(temper,root))
      later(150,function()
        shot('forgotten-works-tempering-800x640')
        later(150,function() click(assert(boxButton(temper,'Cancel'))); last('reroll_cancel'); assertNoConfirm(before); done() end)
      end)
    end)
  end)
end)

local index=0
local function nextStep()
  index=index+1
  local selected=steps[index]
  if not selected then
    forgeEnv.terminate(); assert(not callback and not next(menuHooks),'Forge opcode/menu hooks leaked')
    completed=true
    print('FORGOTTEN_WORKS_UI_NATIVE_OK ' .. json.encode({renderingOnly=true,serverProof=false,serverPaymentProof=false,
      noGameplayLogin=true,nativeHitTestAndDispatchedHover=true,operatingSystemMouseInput=false,
      sourceSha1=sourceSha1,checks=checks,screenshots=screenshots,requestsCaptured=#requests,sizes={'1280x800','800x640'}}))
    print('FORGOTTEN_WORKS_UI_NATIVE_SCREENSHOT_DIRECTORY ' .. g_resources.getWriteDir())
    scheduleEvent(function() g_app.exit() end,100); return
  end
  currentStep=selected.name
  local ok,reason=pcall(selected.run,function() checks[#checks+1]=selected.name; later(100,nextStep) end)
  if not ok then fail(reason) end
end
later(2500,function()
  if type(g_window.isVisible) == 'function' then assert(g_window.isVisible(),'Native graphics startup window hidden') end
  realGame.setClientVersion(860); realGame.setProtocolVersion(860)
  assert(g_things.loadDat('/things/860/Tibia'),'Cannot load actual packaged 8.60 DAT')
  assert(g_sprites.loadSpr('/things/860/Tibia'),'Cannot load actual packaged 8.60 SPR')
  for cid=11868,11877 do assert(g_things.getThingType(cid,ThingCategoryItem),'Missing native design item ' .. cid) end
  g_window.resize({width=1280,height=800})
  forgeEnv={rootWidget=root,connect=function() end,disconnect=function() end,
    g_game=setmetatable({getProtocolGame=function() return protocol end},{__index=realGame}),
    ProtocolGame={registerExtendedOpcode=function(opcode,fn) assert(opcode == 98); callback=fn end,
      unregisterExtendedOpcode=function(opcode) assert(opcode == 98); callback=nil end},
    modules={game_interface={addMenuHook=function(_,name) menuHooks[name]=true end,
      removeMenuHook=function(_,name) menuHooks[name]=nil end},
      game_textmessage={displayStatusMessage=function(message) notifications[#notifications+1]=message end,
        displayFailureMessage=function(message) notifications[#notifications+1]=message end}},
    g_ui=setmetatable({displayUI=function(name,parent)
      assert(name == 'lava_smelt')
      local layout=g_resources.readFileContents('/forgotten-works-layout.txt')
      sourceSha1['/forgotten-works-layout.txt']=g_crypt.sha1Encode(layout)
      forgeWindow=realUI.loadUIFromString(layout,parent); return forgeWindow
    end},{__index=realUI})}
  setmetatable(forgeEnv,{__index=_G}); forgeEnv._G=forgeEnv; forgeEnv.modules.game_lava_smelt=forgeEnv
  source('/forgotten-works-source.txt',forgeEnv); source('/lava-smelt-source.txt',forgeEnv)
  forgeEnv.init()
  receive('{malformed'); assert(not forgeWindow,'Malformed opcode opened forge')
  local before=#requests
  receive({action='open',preview={entries={},totalCount=0,playerGold=20000},forgotten=snapshot()})
  assert(#requests == before,'Bootstrap sent a request before window binding')
  callback({},98,json.encode({action='result',success=true,message='stale protocol packet'}))
  assert(widget('statusLabel'):getText() ~= 'stale protocol packet','Foreign protocol mutated forge')
  nextStep()
end)
