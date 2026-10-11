-- Offline actual native widgets/DAT/resources; supplied rendering snapshots.
-- This is not evidence of server crafting, unlocks, payment or combat.
assert(LOCAL_PASSIVES_TEST and not g_game.isOnline())
if modules.client_discord then modules.client_discord.terminate() end
local realGame, realUI, root = g_game, g_ui, g_ui.getRootWidget()
local forgeWindow, equipmentHost, completed, overlay, forgeEnv, overlayEnv = nil, nil, false
local packagedOverlay, feedbackRegistered
local callback, requests, menuHooks, screenshots, notifications = nil, {}, {}, {}, {}
local function source(path, environment)
  local chunk = assert(loadstring(g_resources.readFileContents(path), '@' .. path))
  setfenv(chunk, environment); chunk()
end
local function fail(reason)
  if completed then return end
  completed = true
  print('LEGENDARY_CLIENT_NATIVE_FAILED ' .. tostring(reason))
  if overlay then
    if feedbackRegistered then pcall(overlay.terminate); feedbackRegistered = false else overlay.clear() end
  end
  if packagedOverlay then pcall(packagedOverlay.init); packagedOverlay = nil end
  if forgeEnv then pcall(forgeEnv.terminate) end
  if equipmentHost then equipmentHost:destroy() end
  scheduleEvent(function() g_app.exit() end, 100)
end
local function later(ms, callbackFn)
  scheduleEvent(function()
    if completed then return end
    local ok, reason = pcall(callbackFn)
    if not ok then fail(reason) end
  end, ms)
end
local function click(widget)
  assert(widget and widget:isVisible(), 'Native control is not visible')
  signalcall(widget.onClick, widget)
end
local function inside(widget, parent)
  local a, b = widget:getRect(), parent:getRect()
  return a.x >= b.x and a.y >= b.y and a.x + a.width <= b.x + b.width and a.y + a.height <= b.y + b.height
end
local function shot(name)
  g_app.doScreenshot('/' .. name .. '.png'); screenshots[#screenshots + 1] = name
end
local protocol = {}
function protocol:sendExtendedOpcode(opcode, buffer)
  assert(opcode == 98); requests[#requests + 1] = json.decode(buffer)
end
local function receive(data)
  if type(data) == 'table' then
    data = json.decode(json.encode(data))
    if data.action:match('^forgotten_') and data.clientSession == nil then
      local context = requests[#requests] or {}
      data.clientSession, data.requestId = context.clientSession, context.requestId
    end
  end
  assert(callback)(protocol, 98, type(data) == 'string' and data or json.encode(data))
end
local function rootBox(title)
  for _, child in ipairs(root:getChildren()) do
    if child:getText() == title and child:isVisible() then return child end
  end
end
local function boxButton(box, title)
  for _, button in ipairs(assert(box:getChildById('buttonHolder')):getChildren()) do
    if button:getText() == title then return button end
  end
end
local recipes = {}
local keys = {'deepwarden','oath','ashcleaver','elders_reckoning','forgeheart','mountains_verdict',
  'wayfarer','deepforge_arbalest','stonewake','ashen_requiem'}
local names = {'Deepwarden','Oath of the Deep','Ashcleaver','Elder\'s Reckoning','Forgeheart',
  'Mountain\'s Verdict','Wayfarer','Deepforge Arbalest','Stonewake','Ashen Requiem'}
local slugs = {'deepwarden','oath-of-the-deep','ashcleaver','elders-reckoning','forgeheart','mountains-verdict',
  'wayfarer','deepforge-arbalest','stonewake','ashen-requiem'}
for index, key in ipairs(keys) do
  recipes[#recipes + 1] = {key = key, name = names[index], clientId = 11867 + index, donorId = 3963, donorClientId = 3345, donorName = 'templar scytheblade'}
end
local core = {requiredMs = 13500000, regions = {}}
for _, label in ipairs({'Dwarven Depths','Barbarian Camps','Dragon Lairs','Lava Depths'}) do
  core.regions[#core.regions + 1] = {label = label, earnedMs = 13500000, neededMs = 13500000}
end
local preview = {action = 'forgotten_preview', success = true, recipeKey = 'deepwarden', name = 'Deepwarden',
  clientId = 11868, donorName = 'templar scytheblade', donor = {id = 3963, clientId = 3345, name = 'epic templar scytheblade',
    valid = true, affixes = {'Attack: +5', 'Sword skill: +2'}},
  resultStats = {summary = 'ATK 30  DEF 16 +1\nLevel 35  One-handed sword', details = 'ATK 30 includes the inherited Attack +5 roll.\nBase ATK 25; DEF 16; extra DEF +1.\nLevel 35. One-handed sword.',
    inheritedAffixes = {'Attack: +5', 'Sword skill: +2'}},
  signature = {name = 'Swordguard', text = 'Normal attacks have a 12% chance to ready Swordguard for 4 seconds. Your next ordinary melee physical hit taken is reduced by 50%, up to 16 damage against creatures or 8 against players. Cooldown: 12 seconds.'},
  signatureRule = 'Only paid normal weapon attacks trigger a signature. Cooldown is shared across Legendary weapons and survives swapping or logging out. Extra damage does not trigger another signature.',
  activityHelp = 'Effective personal forge activity. Hunt eligible creatures in each region. A real kill credits at most one minute, with up to five minutes between kills. More than 14 hours of stamina is required. Eligible unlocked party members share the credit; offline time does not count.',
  requirements = {{clientId=11878,name='Iron Echo',owned=300,required=300},{clientId=11879,name='Warbrand',owned=200,required=200},
    {clientId=11880,name='Scale Ash',owned=100,required=100},{clientId=11881,name='Cinder Glass',owned=200,required=200},
    {clientId=11831,name='light blue crystal fragment',owned=100,required=100},{clientId=11830,name='red crystal fragment',owned=100,required=100},
    {clientId=11834,name='pristine forging shard',owned=1,required=1}},
  goldRequired = 20000, goldOwned = 20000, core = core, canCraft = true, message = 'Ready to forge.'}
local function screenshotSizes(name, nextFn)
  g_window.resize({width = 1280, height = 800})
  later(150, function()
    assert(inside(forgeWindow, root), 'Forge outside 1280x800')
    shot(name .. '-1280x800')
    later(150, function()
    g_window.resize({width = 800, height = 640})
    later(150, function()
      assert(inside(forgeWindow, root), 'Forge outside supported 800x640')
      local close = forgeWindow:recursiveGetChildById('forgottenPanel'):isVisible()
        and forgeWindow:recursiveGetChildById('forgottenCloseButton') or forgeWindow:recursiveGetChildById('closeButton')
      assert(inside(close, forgeWindow), 'Forge action/footer clipped')
      if forgeWindow:recursiveGetChildById('forgottenPanel'):isVisible() then
        for _, id in ipairs({'forgottenDescription','forgottenStats','forgottenSignature','forgottenRule','forgottenStatus'}) do
          local label = forgeWindow:recursiveGetChildById(id)
          assert(label:getTextSize().height <= label:getHeight(), 'Forge text clipped: ' .. id)
          assert(inside(label, forgeWindow), 'Forge label outside window: ' .. id)
        end
      end
      shot(name .. '-800x640'); later(150, nextFn)
    end)
    end)
  end)
end
local function finish()
  forgeEnv.terminate()
  assert(not callback and not next(menuHooks), 'Opcode/menu hooks leaked on terminate')
  if feedbackRegistered then overlay.terminate(); feedbackRegistered = false else overlay.clear() end
  if packagedOverlay then packagedOverlay.init(); packagedOverlay = nil end
  equipmentHost:destroy()
  completed = true
  print('LEGENDARY_CLIENT_NATIVE_OK ' .. json.encode({renderingOnly = true, serverProof = false,
    syntheticOnlineContext = true, datItems = 10, sizes = {'1280x800','800x640'},
    screenshots = screenshots, requestsCaptured = #requests}))
  print('LEGENDARY_CLIENT_NATIVE_SCREENSHOT_DIRECTORY ' .. g_resources.getWriteDir())
  scheduleEvent(function() g_app.exit() end, 100)
end
local function feedbackChecks(hand, nextFn)
  local originalDrop = hand.onDrop
  local frameWidth, frameHeight = hand:getImageTextureWidth(), hand:getImageTextureHeight()
  local function apply(cid, fields)
    local item = Item.create(cid)
    hand:setItem(item)
    hand:setTooltip('Native weapon description\nEpic enchantments retained.')
    local itemTooltip = hand:getTooltip()
    overlay.update(InventorySlotRight, hand, item)
    local data = {v=1,clientId=cid,cooldown=0,charge=0,ward=0,hits=0,wind=0,procs=0}
    for key,value in pairs(fields) do data[key]=value end
    -- Exercise actual registered ProtocolGame dispatch. Only g_game's online
    -- state/protocol identity are supplied for this offline rendering fixture.
    ProtocolGame.onExtendedOpcode(protocol,105,json.encode(data))
    local badge = assert(hand:getChildById('legendarySignatureStatus'))
    assert(badge:isVisible() and badge:isPhantom() and not badge:isFocusable())
    assert(inside(badge,hand), 'Feedback badge escaped the weapon slot')
    assert(hand.onDrop == originalDrop and (itemTooltip == nil or (hand:getTooltip() or ''):sub(1,#itemTooltip) == itemTooltip)
      and hand:getImageTextureWidth() == frameWidth and hand:getImageTextureHeight() == frameHeight,
      'Feedback changed inventory drag/drop/look/rarity frame')
    assert(item:getShader() == '', 'Feedback changed the actual weapon shader')
    return badge
  end
  local badge = apply(11876,{charge=8,cooldown=12,ward=12,hits=2,procs=1})
  assert(badge:getText() == 'G8', 'Living Bark charge feedback missing')
  assert(hand:getTooltip():find('Living Bark ready: 8s.',1,true) and hand:getTooltip():find('Ward budget: 12 HP; 2 direct hits remaining.',1,true), 'Guard badge is not explained in the weapon tooltip')
  ProtocolGame.onExtendedOpcode({},105,json.encode({v=1,clientId=11876,cooldown=0,charge=0,ward=0,hits=0,wind=0,procs=0}))
  assert(badge:getText() == 'G8', 'Stale protocol changed feedback')
  later(150,function()
    shot('legendary-inventory-guard-feedback-1280x800')
    later(150,function()
      badge=apply(11874,{wind=3,cooldown=12,procs=2})
      assert(badge:getText() == 'M3', 'Windstride movement feedback missing')
      assert(hand:getTooltip():find('Windstride movement bonus: 3s (+40 speed).',1,true), 'Movement badge is not explained in the weapon tooltip')
      later(150,function()
        shot('legendary-inventory-wind-feedback-1280x800')
        later(150,function()
          badge=apply(11868,{cooldown=12,procs=3})
          assert(badge:getText() == '12', 'Shared cooldown feedback missing')
          assert(hand:getTooltip():find('Swordguard: shared cooldown 12s.',1,true), 'Cooldown badge is not explained in the weapon tooltip')
          ProtocolGame.onExtendedOpcode(protocol,105,'{malformed')
          assert(badge:getText() == '12', 'Malformed feedback changed state')
          later(150,function()
            shot('legendary-inventory-cooldown-feedback-1280x800')
            later(150,function()
              hand:setTooltip('Newer native weapon description.')
              ProtocolGame.onExtendedOpcode(protocol,105,json.encode({v=1,clientId=11868,cooldown=11,charge=0,ward=0,hits=0,wind=0,procs=3}))
              assert(hand:getTooltip():find('Newer native weapon description.',1,true) == 1, 'Feedback discarded an externally updated native tooltip')
              ProtocolGame.onExtendedOpcode(protocol,105,json.encode({v=1,clientId=0,cooldown=0,charge=0,ward=0,hits=0,wind=0,procs=3}))
              assert(not badge:isVisible(), 'Unequipped weapon kept status badge')
              assert(hand:getTooltip() == 'Newer native weapon description.', 'Inactive status failed to restore the current native tooltip')
              nextFn()
            end)
          end)
        end)
      end)
    end)
  end)
end
local function contextData(data, context)
  data.clientSession, data.requestId = context.clientSession, context.requestId
  return data
end
local function quote()
  click(forgeWindow:recursiveGetChildById('forgottenCraftButton'))
  assert(requests[#requests].action == 'forgotten_quote')
  receive({action='forgotten_quote',success=true,token='rendering-fixture-only',expiresIn=30,
    preview=preview,warning='The donor is replaced; its rolled affixes are retained.'})
  return assert(rootBox('Confirm Forgotten Work'))
end
local function orderingChecks(nextFn)
  local stalePreview = requests[#requests]
  local box = quote()
  receive(contextData(json.decode(json.encode(preview)), stalePreview))
  assert(rootBox('Confirm Forgotten Work') == box, 'Out-of-order preview cancelled a current quote')
  click(assert(boxButton(box, 'Forge')))
  local pending = requests[#requests]
  assert(pending.action == 'forgotten_confirm')
  local oldWindow = forgeWindow
  forgeEnv.close()
  local count = #notifications
  receive(contextData({action='forgotten_result',success=true,message='Closed-window forging complete.'},pending))
  assert(#notifications == count + 1 and notifications[#notifications] == 'Closed-window forging complete.', 'Closed craft result was not notified')
  assert(forgeWindow == oldWindow and oldWindow:isDestroyed(), 'Closed forge reopened for a result')
  receive(contextData(json.decode(json.encode(preview)), stalePreview))
  assert(forgeWindow == oldWindow, 'Closed forge reopened for a preview')
  receive({action='preview',entries={},totalCount=0,playerGold=20000})
  assert(forgeWindow == oldWindow, 'Closed forge reopened for an ordinary smelting preview')
  receive({action='open',preview={entries={},totalCount=0,playerGold=20000}})
  click(forgeWindow:recursiveGetChildById('forgottenTab'))
  receive({action='forgotten_snapshot',v=1,success=true,unlocked=true,recipes=recipes,core=core})
  local livePreview = requests[#requests]
  receive(contextData({action='forgotten_snapshot',v=1,success=true,unlocked=true,recipes={}},stalePreview))
  assert(#forgeWindow:recursiveGetChildById('forgottenRecipes'):getChildren() == 10, 'Old snapshot mutated reopened forge')
  receive(contextData({action='forgotten_quote',success=true,token='old-quote',expiresIn=30,preview=preview},stalePreview))
  assert(not rootBox('Confirm Forgotten Work'), 'Old quote opened in a new window')
  receive(contextData({action='forgotten_result',success=true,message='Closed-window forging complete.'},pending))
  assert(#notifications == count + 1, 'Result notification replayed')
  receive(contextData(json.decode(json.encode(preview)), livePreview))
  receive(contextData({action='forgotten_result',success=false,message='Return to the lava forge and open it again.'},livePreview))
  assert(forgeWindow:recursiveGetChildById('forgottenStatus'):getText():find('Return to the lava forge',1,true), 'Current session failure was ignored')
  receive(contextData(json.decode(json.encode(preview)), livePreview))
  local currentBox = quote()
  click(assert(boxButton(currentBox, 'Forge')))
  receive({action='forgotten_result',success=true,message='The lava yields Deepwarden. Its two enchantments remain bound to the new weapon.',
    snapshot={action='forgotten_snapshot',v=1,success=true,unlocked=true,recipes=recipes,core=core}})
  assert(requests[#requests].action == 'forgotten_preview' and requests[#requests].donor == nil, 'Successful craft retained consumed donor')
  local empty = json.decode(json.encode(preview)); empty.donor = nil; empty.canCraft = false
  empty.resultStats.inheritedAffixes = {}; empty.resultStats.summary='ATK 25  DEF 16 +1\nLevel 35  One-handed sword'
  empty.message = 'Place the required Epic weapon from your backpack into the forge.'
  receive(empty)
  assert(forgeWindow:recursiveGetChildById('forgottenStatus'):getText():find('Forged Deepwarden. Epic rolls preserved.',1,true), 'Next preview overwrote completion')
  assert(forgeWindow:recursiveGetChildById('forgottenDonor'):getItemId() == 0, 'Consumed donor remained visible')
  screenshotSizes('legendary-forge-empty-donor', nextFn)
end
local function forgeChecks()
  local widgets = forgeWindow
  click(widgets:recursiveGetChildById('forgottenTab'))
  assert(requests[#requests].action == 'forgotten_open')
  receive({action = 'forgotten_snapshot', v = 1, success = true, unlocked = false, recipes = {}})
  assert(widgets:recursiveGetChildById('forgottenName'):getText() == 'No discovered designs')
  screenshotSizes('legendary-forge-locked', function()
    receive({action = 'forgotten_snapshot', v = 1, success = true, unlocked = true, recipes = recipes, core = core})
    assert(#widgets:recursiveGetChildById('forgottenRecipes'):getChildren() == 10)
    local donorItem = {getId=function() return 3345 end,getPosition=function() return {x=65535,y=64,z=0} end}
    assert(widgets:recursiveGetChildById('forgottenDonor').onDrop(nil,{getItem=function() return donorItem end}))
    assert(requests[#requests].donor and requests[#requests].donor.id == 3963)
    receive(preview)
    assert(widgets:recursiveGetChildById('forgottenCraftButton'):isEnabled())
    assert(widgets:recursiveGetChildById('forgottenDonor'):getTooltip():find('Attack: +5', 1, true))
    assert(widgets:recursiveGetChildById('forgottenStats'):getText():find('ATK 30',1,true))
    assert(widgets:recursiveGetChildById('forgottenStats'):getText():find('Inherited: Attack: +5; Sword skill: +2',1,true))
    assert(widgets:recursiveGetChildById('forgottenSignature'):getTooltip():gsub('%s+',' '):find('shared across Legendary weapons',1,true))
    assert(widgets:recursiveGetChildById('forgottenStatus'):getTooltip():gsub('%s+',' '):find('14 hours',1,true))
    click(widgets:recursiveGetChildById('forgottenRefreshButton'))
    receive({action='forgotten_snapshot',v=1,success=true,unlocked=true,recipes=recipes,core=core})
    assert(requests[#requests].action == 'forgotten_preview' and requests[#requests].donor.id == 3963, 'Refresh discarded donor')
    receive(preview)
    click(widgets:recursiveGetChildById('forgottenCraftButton'))
    local rejectedContext = requests[#requests]
    local changed = json.decode(json.encode(preview))
    changed.requirements[1].owned = 299; changed.goldOwned = 19999; changed.canCraft = false
    changed.resultStats.summary = 'ATK 31  DEF 16 +1\nLevel 35  One-handed sword'
    changed.resultStats.inheritedAffixes = {'Attack: +6','Sword skill: +2'}
    changed.resultStats.details = 'Updated authoritative result includes Attack +6.'
    receive({action='forgotten_quote',success=false,preview=changed,message='Your materials changed. Inspect the current costs.'})
    assert(widgets:recursiveGetChildById('forgottenMaterials'):getChildren()[1]:getChildById('amountLabel'):getText() == '299 / 300', 'Failed quote kept outdated material counts')
    assert(widgets:recursiveGetChildById('forgottenMaterials'):getChildren()[8]:getChildById('amountLabel'):getText() == '19999 / 20000', 'Failed quote kept outdated gold')
    assert(widgets:recursiveGetChildById('forgottenStats'):getText():find('ATK 31',1,true), 'Failed quote kept outdated result stats')
    assert(not widgets:recursiveGetChildById('forgottenCraftButton'):isEnabled(), 'Rejected quote left crafting enabled')
    assert(widgets:recursiveGetChildById('forgottenStatus'):getText() == 'Your materials changed. Inspect the current costs.', 'Failed quote lost its rejection reason')
    click(widgets:recursiveGetChildById('forgottenRefreshButton'))
    receive({action='forgotten_snapshot',v=1,success=true,unlocked=true,recipes=recipes,core=core})
    receive(preview)
    receive(contextData({action='forgotten_quote',success=false,preview=changed,message='Old rejected quote.'},rejectedContext))
    assert(widgets:recursiveGetChildById('forgottenStats'):getText():find('ATK 30',1,true) and widgets:recursiveGetChildById('forgottenCraftButton'):isEnabled(), 'Stale rejected quote overwrote current preview')
    screenshotSizes('legendary-forge-discovered', function()
      g_tooltip.display(widgets:recursiveGetChildById('forgottenStatus'):getTooltip())
      local tooltip = assert(root:recursiveGetChildById('toolTip'))
      assert(tooltip:getWidth() <= 440 and tooltip:getHeight() < 400, 'Forge activity tooltip exceeds compact screen bounds')
      assert(inside(tooltip,root), 'Forge activity tooltip clipped at 800x640')
      later(150,function()
      assert(tooltip:isVisible() and tooltip:getOpacity() > 0.9, 'Native activity tooltip has not finished fading in')
      shot('legendary-forge-activity-tooltip-800x640')
      later(150,function()
      g_tooltip.hide()
      click(widgets:recursiveGetChildById('forgottenCraftButton'))
      assert(requests[#requests].action == 'forgotten_quote')
      receive({action = 'forgotten_quote', success = true, token = 'rendering-fixture-only', expiresIn = 30,
        preview = preview, warning = 'The donor is replaced; its rolled affixes are retained.'})
      local box = assert(rootBox('Confirm Forgotten Work'), 'Native quote dialog missing')
      g_window.resize({width = 1280, height = 800})
      later(100, function()
        shot('legendary-forge-quote-1280x800')
        later(150, function()
        g_window.resize({width = 800, height = 640})
        later(100, function()
          assert(inside(box, root), 'Native quote clipped at 800x640')
          shot('legendary-forge-quote-800x640')
          later(150, function()
          click(assert(boxButton(box, 'Cancel')))
          assert(requests[#requests - 1].action == 'forgotten_cancel')
          receive(preview)
          orderingChecks(function()
          widgets = forgeWindow
          click(widgets:recursiveGetChildById('smeltTab'))
          screenshotSizes('legendary-forge-smelting', function()
            assert(widgets:recursiveGetChildById('slot1').onDrop and widgets:recursiveGetChildById('slot6').onDrop)
            receive({action = 'reroll_prompt', materialName = 'Ember Dust', modeText = 'temper', targetName = 'longsword', tierLabel = 'rare'})
            local temper = assert(rootBox('Confirm Tempering'), 'Original tempering dialog missing')
            shot('legendary-forge-tempering-800x640')
            later(150, function()
            click(assert(boxButton(temper, 'Cancel')))
            assert(requests[#requests].action == 'reroll_cancel', 'Original tempering request changed')
            finish()
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
  end)
end
later(2500, function()
  if type(g_window.isVisible) == 'function' then
    assert(g_window.isVisible(), 'Native graphics startup window is not visible yet')
  end
  realGame.setClientVersion(860); realGame.setProtocolVersion(860)
  assert(g_things.loadDat('/things/860/Tibia'), 'Cannot load actual packaged 8.60 DAT')
  assert(g_sprites.loadSpr('/things/860/Tibia'), 'Cannot load actual packaged 8.60 SPR')
  g_window.resize({width = 1280, height = 800})
  overlayEnv = setmetatable({g_game = {isOnline = function() return true end,
    getProtocolGame = function() return protocol end}}, {__index = _G})
  source('/legendary-overlay-source.txt', overlayEnv)
  overlay = assert(overlayEnv.LegendaryInventoryOverlay)
  local existingOverlay = modules.game_inventory and modules.game_inventory.LegendaryInventoryOverlay
  if existingOverlay and existingOverlay.init and existingOverlay.terminate then
    existingOverlay.terminate(); packagedOverlay = existingOverlay
  end
  overlay.init(); feedbackRegistered = true
  assert(getfenv(overlay.update).g_game.isOnline(), 'Rendering fixture lost its explicit synthetic online context')
  equipmentHost = realUI.createWidget('MainWindow', root)
  equipmentHost:setText('Legendary inventory rendering fixture')
  equipmentHost:setSize({width = 400, height = 180})
  equipmentHost:show(); equipmentHost:raise()
  local row = realUI.createWidget('Panel', equipmentHost)
  row:setSize({width = 370, height = 38})
  row:addAnchor(AnchorTop, 'parent', AnchorTop); row:addAnchor(AnchorLeft, 'parent', AnchorLeft)
  local hand
  for index = 1, 10 do
    local cid = 11867 + index
    local stripPath = '/images/items/legendary/' .. slugs[index] .. '-frames.png'
    assert(g_resources.fileExists(stripPath), 'Missing packaged cosmetic strip for ' .. cid)
    -- PNG entries can contain ENC3 bytes. Exercise the real native texture
    -- loader rather than interpreting raw encrypted resource bytes as a PNG.
    local textureProbe = realUI.createWidget('UIWidget', row)
    textureProbe:setPhantom(true); textureProbe:setSize({width=32,height=32})
    textureProbe:setImageSource(stripPath)
    assert(textureProbe:getImageTextureWidth() == 128 and textureProbe:getImageTextureHeight() == 32,
      'Native packaged texture is not four native32 frames for ' .. cid)
    textureProbe:destroy()
    local item = Item.create(cid)
    assert(item:getId() == cid and g_things.getThingType(cid, ThingCategoryItem), 'Missing actual DAT item for ' .. cid)
    local slot = realUI.createWidget('InventoryItem', row)
    slot:addAnchor(AnchorTop, 'parent', AnchorTop)
    slot:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    slot:setMarginLeft((index - 1) * 36)
    slot:setImageSource('/images/ui/rarity_gold')
    slot:setItem(item); slot:setTooltip(names[index] .. ' — fixture item')
    assert(item:getShader() == '', 'Baseline fixture unexpectedly had a shader')
    if index == 1 then
      hand = slot
      local originalDrop = slot.onDrop
      overlay.update(InventorySlotRight, slot, item)
      local cosmetic = assert(slot:getChildById('legendaryInventoryOverlay'))
      assert(cosmetic:isPhantom() and not cosmetic:isFocusable() and cosmetic:getWidth() == 32)
      assert(slot.onDrop == originalDrop and item:getShader() == '' and slot:getTooltip():find('Deepwarden', 1, true))
    else
      overlay.update(InventorySlotAmmo, slot, item)
      assert(not slot:getChildById('legendaryInventoryOverlay'), 'Overlay escaped to a non-hand slot')
    end
  end
  feedbackChecks(hand,function()
  later(1100, function()
    assert(equipmentHost:isVisible() and inside(equipmentHost, root), 'Native inventory fixture window is hidden or clipped')
    local cosmetic = assert(hand:getChildById('legendaryInventoryOverlay'))
    assert(inside(cosmetic, hand), 'Inventory overlay escaped rarity border')
    local p, o = hand:getRect(), cosmetic:getRect()
    assert(o.x == p.x + 1 and o.y == p.y + 1, 'Native32 overlay does not match item padding')
    shot('legendary-inventory-frame1-1280x800')
    local firstClip = cosmetic:getImageClip().x
    local frameDeadline = g_clock.millis() + 850
    local function afterFrame()
      local currentClip = cosmetic:getImageClip().x
      if currentClip == firstClip and g_clock.millis() < frameDeadline then
        later(25, afterFrame); return
      end
      assert(currentClip == (firstClip + 32) % 128, 'Actual500ms overlay timer did not advance one native frame')
      assert(equipmentHost:isVisible(), 'Native inventory fixture hidden before frame2 capture')
      shot('legendary-inventory-frame2-1280x800')
      -- Screenshot is queued until the next render frame. Keep real native
      -- widgets visible before disposing them or preparing another scene.
      later(150, function()
      overlay.clear(); assert(not hand:getChildById('legendaryInventoryOverlay'))
      equipmentHost:hide()
      forgeEnv = {rootWidget = root, connect = function() end, disconnect = function() end,
        g_game = setmetatable({getProtocolGame = function() return protocol end}, {__index = realGame}),
        ProtocolGame = {registerExtendedOpcode = function(opcode, fn) assert(opcode == 98); callback = fn end,
          unregisterExtendedOpcode = function(opcode) assert(opcode == 98); callback = nil end},
        modules = {game_interface = {addMenuHook = function(_, name) menuHooks[name] = true end,
          removeMenuHook = function(_, name) menuHooks[name] = nil end},
          game_textmessage = {displayStatusMessage = function(message) notifications[#notifications+1]=message end,
            displayFailureMessage = function(message) notifications[#notifications+1]=message end}},
        g_ui = setmetatable({displayUI = function(name, parent)
          assert(name == 'lava_smelt')
          forgeWindow = realUI.loadUIFromString(g_resources.readFileContents('/legendary-forge-layout.txt'), parent)
          return forgeWindow
        end}, {__index = realUI})}
      setmetatable(forgeEnv, {__index = _G}); forgeEnv._G = forgeEnv
      forgeEnv.modules.game_lava_smelt = forgeEnv
      source('/legendary-forgotten-source.txt', forgeEnv)
      source('/legendary-lava-source.txt', forgeEnv)
      forgeEnv.init()
      receive('{malformed'); assert(not forgeWindow, 'Malformed opcode opened the native forge')
      local beforeOpen = #requests
      receive({action = 'open', preview = {entries = {}, totalCount = 0, playerGold = 20000},
        forgotten={action='forgotten_snapshot',v=1,success=true,unlocked=true,recipes=recipes,core=core}})
      assert(#requests == beforeOpen, 'Bootstrap preview sent before Forgotten window binding')
      assert(forgeWindow and #forgeWindow:recursiveGetChildById('slotsPanel'):getChildren() == 6)
      callback({}, 98, json.encode({action = 'result', success = true, message = 'stale packet'}))
      assert(forgeWindow:recursiveGetChildById('statusLabel'):getText() ~= 'stale packet', 'Stale protocol accepted')
      forgeChecks()
      end)
    end
    later(25, afterFrame)
  end)
  end)
end)
