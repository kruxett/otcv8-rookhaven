-- Presentation and requests only. Discovery, materials, personal progress,
-- distance, donor validity and the one-use craft token remain server authority.
ForgottenWorks = {}
local ui, send, recipes, selectedKey, donor, confirmBox, expiryEvent, quoteToken
local clientSession, latestRequest, completionMessage
local detailBox, detailMessages, questStage
local windowSerial, requestSerial, pendingResults = 0, 0, {}
local function text(value, limit)
  if type(value) ~= 'string' then return '' end
  return value:sub(1, limit or 320)
end
local function number(value)
  return math.max(0, math.floor(tonumber(value) or 0))
end
local function wrappedMessage(message)
  local lines = {}
  for line in (message .. '\n'):gmatch('(.-)\n') do
    local current = ''
    for word in line:gmatch('%S+') do
      if #current > 0 and #current + #word + 1 > 68 then lines[#lines + 1] = current; current = '' end
      current = current == '' and word or (current .. ' ' .. word)
    end
    lines[#lines + 1] = current
  end
  return table.concat(lines, '\n')
end
local function clearQuote()
  if expiryEvent then removeEvent(expiryEvent); expiryEvent = nil end
  if confirmBox then confirmBox:destroy(); confirmBox = nil end
  quoteToken = nil
end
local function closeDetails()
  if detailBox then detailBox:destroy(); detailBox = nil end
end
local function clearDetails()
  closeDetails()
  detailMessages = {}
  for _, id in ipairs({'forgottenWeaponDetailsButton', 'forgottenEffectDetailsButton', 'forgottenActivityDetailsButton'}) do
    ui[id]:setEnabled(false)
  end
  for _, id in ipairs({'forgottenStats', 'forgottenSignature', 'forgottenRule', 'forgottenStatus', 'forgottenDonor'}) do
    ui[id]:setTooltip(nil)
  end
end
local function showDetails(title, message)
  if not message or message == '' then return end
  closeDetails()
  detailBox = displayGeneralBox(tr(title), wrappedMessage(message), {{text = tr('Close'), callback = closeDetails}}, closeDetails, closeDetails)
end
local function status(message, success)
  ui.forgottenStatus:setText(text(message, 700))
  ui.forgottenStatus:setHeight(math.max(28, ui.forgottenStatus:getTextSize().height))
  ui.forgottenStatus:setColor(success and '#7fd992' or '#9e9080')
  ui.forgottenStatus:setTooltip(nil)
end
local function request(payload)
  if not send or not clientSession then return end
  requestSerial = requestSerial + 1
  latestRequest = requestSerial
  payload.clientSession, payload.requestId = clientSession, latestRequest
  if payload.action == 'forgotten_confirm' then
    pendingResults[clientSession .. ':' .. latestRequest] = true
  end
  send(payload)
end
local function requestPreview()
  if selectedKey then request({action = 'forgotten_preview', recipeKey = selectedKey, donor = donor}) end
end
local function selectedRecipe()
  for _, recipe in ipairs(recipes or {}) do if recipe.key == selectedKey then return recipe end end
end
local function showPreviewControls(visible)
  for _, id in ipairs({'forgottenDonor','forgottenStats','forgottenSignature','forgottenEffect','forgottenMaterialsLabel',
    'forgottenMaterials','forgottenRule','forgottenWeaponSeparator','forgottenWeaponDetailsButton','forgottenEffectDetailsButton','forgottenActivityDetailsButton'}) do
    ui[id]:setVisible(visible)
  end
end
local function selectRecipe(key, preserveDonor, skipPreview)
  clearQuote()
  clearDetails()
  showPreviewControls(true)
  if not preserveDonor or selectedKey ~= key then donor, completionMessage = nil, nil end
  selectedKey = key
  ui.forgottenDonor:setItemId(donor and number(donor.clientId) or 0)
  ui.forgottenCraftButton:setEnabled(false)
  local selectedRow
  for _, row in ipairs(ui.forgottenRecipes:getChildren()) do
    local selected = row.recipeKey == key
    if selected then selectedRow = row end
    row:setOn(selected)
    row:getChildById('stateLabel'):setText(selected and 'Selected' or '')
  end
  local currentUi = ui
  addEvent(function()
    if ui == currentUi and selectedKey == key and selectedRow and not selectedRow:isDestroyed() then
      ui.forgottenRecipes:ensureChildVisible(selectedRow)
    end
  end)
  ui.forgottenDetailsScrollbar:setValue(ui.forgottenDetailsScrollbar:getMinimum())
  local recipe = selectedRecipe()
  ui.forgottenName:setText(recipe and text(recipe.name, 90) or 'No discovered designs')
  ui.forgottenDescription:setText(recipe and ('Epic ' .. text(recipe.donorName, 90) .. '\nDrop here; its two rolls are kept.') or '')
  ui.forgottenStats:setText('')
  ui.forgottenSignature:setText('')
  ui.forgottenEffect:setText('')
  ui.forgottenRule:setText('')
  ui.forgottenMaterials:destroyChildren()
  ui.forgottenMaterials:setHeight(0)
  status('Inspecting the design...')
  if not skipPreview then requestPreview() end
end
local function coreLines(core)
  local result, details = {}, {}
  if type(core) ~= 'table' then return result, details end
  for index, region in ipairs(type(core.regions) == 'table' and core.regions or {}) do
    if index > 8 then break end
    local banked = number(region.earnedMs)
    local needed = number(core.requiredMs)
    local earned = math.min(banked, needed)
    result[#result + 1] = string.format('%s: %dh %02dm / %dh %02dm', text(region.label, 60),
      math.floor(earned / 3600000), math.floor(earned / 60000) % 60,
      math.floor(needed / 3600000), math.floor(needed / 60000) % 60)
    details[#details + 1] = result[#result] .. string.format(' (banked: %dh %02dm; remaining: %dh %02dm)',
      math.floor(banked / 3600000), math.floor(banked / 60000) % 60,
      math.floor(math.max(0, needed - banked) / 3600000), math.floor(math.max(0, needed - banked) / 60000) % 60)
  end
  return result, details
end
local function materialRow(name, clientId, owned, required)
  local row = g_ui.createWidget('ForgottenMaterialRow', ui.forgottenMaterials)
  row:getChildById('item'):setItemId(number(clientId))
  row:getChildById('nameLabel'):setText(text(name, 90))
  local amount = row:getChildById('amountLabel')
  amount:setText(string.format('%d / %d', number(owned), number(required)))
  amount:setColor(number(owned) >= number(required) and '#c0c0c0' or '#e05050')
end
local function applySnapshot(data, preserveDonor, bootstrap)
  clearQuote()
  questStage = number(data.questStage)
  recipes = {}
  local seen = {}
  for index, recipe in ipairs(type(data.recipes) == 'table' and data.recipes or {}) do
    if index > 10 then break end
    if type(recipe.key) == 'string' and recipe.key:match('^[a-z_]+$') and not seen[recipe.key] then
      recipes[#recipes + 1], seen[recipe.key] = recipe, true
    end
  end
  ui.forgottenRecipes:destroyChildren()
  ui.forgottenDesignsLabel:setText('Designs (' .. #recipes .. ')')
  for _, recipe in ipairs(recipes) do
    local row = g_ui.createWidget('ForgottenRecipeButton', ui.forgottenRecipes)
    row.recipeKey = recipe.key
    row:getChildById('item'):setItemId(number(recipe.clientId))
    row:getChildById('nameLabel'):setText(text(recipe.name, 90))
    row.onClick = function() if selectedKey ~= recipe.key then selectRecipe(recipe.key) end end
  end
  if #recipes == 0 then
    clearDetails()
    showPreviewControls(false)
    selectedKey, donor = nil, nil
    ui.forgottenDonor:setItemId(0)
    ui.forgottenName:setText('No discovered designs')
    ui.forgottenDescription:setText('')
    ui.forgottenStats:setText('')
    ui.forgottenSignature:setText('')
    ui.forgottenEffect:setText('')
    ui.forgottenDescription:setText('Select Unlock designs to see the steps and page sources.')
    ui.forgottenRule:setText('')
    ui.forgottenMaterials:destroyChildren()
    ui.forgottenMaterials:setHeight(0)
    ui.forgottenCraftButton:setEnabled(false)
    status(data.unlocked == true and 'Use a Forging Page to discover a design.'
      or (questStage == 1 and 'Find your Old Forging Mould and return it to Bolgrim.' or 'After The Ascent, ask Bolgrim about forgotten works.'))
  else
    selectRecipe(selectedRecipe() and selectedKey or recipes[1].key, preserveDonor, bootstrap)
  end
end
local function resultDetails(data)
  local result = type(data.resultStats) == 'table' and data.resultStats or {}
  local summary, details = text(result.summary, 400), text(result.details, 1600)
  local affixes = {}
  for index, affix in ipairs(type(result.inheritedAffixes) == 'table' and result.inheritedAffixes or {}) do
    if index > 2 then break end
    affixes[#affixes + 1] = text(affix, 100)
  end
  if #affixes > 0 then
    summary = summary .. '\nInherited: ' .. table.concat(affixes, '; ')
  elseif summary ~= '' then
    summary = summary .. '\nBase values; choose an Epic weapon to preview its rolls.'
  end
  if details == '' then details = summary end
  return summary, details
end
local function applyPreview(data)
  if data.recipeKey ~= selectedKey then return end
  clearQuote()
  clearDetails()
  ui.forgottenName:setText(text(data.name, 90))
  ui.forgottenDescription:setText('Epic ' .. text(data.donorName, 90) .. '\nDrop here; right-click to clear.')
  local summary, details = resultDetails(data)
  ui.forgottenStats:setText(summary)
  ui.forgottenStats:setTooltip(wrappedMessage(details))
  detailMessages.weapon = details
  ui.forgottenWeaponDetailsButton:setEnabled(details ~= '')
  local signature = type(data.signature) == 'table' and data.signature or {}
  ui.forgottenSignature:setText('Signature: ' .. text(signature.name, 60))
  ui.forgottenEffect:setText(text(signature.text, 1100))
  detailMessages.signature = text(signature.name, 60) .. '\n' .. text(signature.text, 1100) .. '\n\n' .. text(data.signatureRule, 700)
  ui.forgottenSignature:setTooltip('Normal weapon attacks trigger signatures.\nSelect Signature details for all combat rules.')
  ui.forgottenEffectDetailsButton:setEnabled(text(signature.text, 1100) ~= '')
  ui.forgottenMaterials:destroyChildren()
  for index, requirement in ipairs(type(data.requirements) == 'table' and data.requirements or {}) do
    if index > 24 then break end
    materialRow(requirement.name, requirement.clientId, requirement.owned, requirement.required)
  end
  materialRow('Gold', 0, data.goldOwned, data.goldRequired)
  ui.forgottenMaterials:setHeight(#ui.forgottenMaterials:getChildren() * 23)
  local selected = type(data.donor) == 'table' and data.donor or nil
  ui.forgottenDonor:setItemId(selected and number(selected.clientId) or 0)
  local tip = 'Epic base weapon: ' .. text(data.donorName, 90) .. '\nDrop it here. Right-click to remove it.'
  if selected then
    tip = text(selected.name, 100) .. '\n' .. tip
    for index, affix in ipairs(type(selected.affixes) == 'table' and selected.affixes or {}) do
      if index > 12 then break end
      tip = tip .. '\n' .. text(affix, 100)
    end
  end
  ui.forgottenDonor:setTooltip(wrappedMessage(tip))
  ui.forgottenCraftButton:setEnabled(data.success == true and data.canCraft == true and not quoteToken)
  local lines, activityDetails = coreLines(data.core)
  ui.forgottenRule:setText('Personal forge activity\n' .. table.concat(lines, '\n'))
  if text(data.activityHelp) ~= '' then activityDetails[#activityDetails + 1] = '\n' .. text(data.activityHelp, 1600) end
  detailMessages.activity = table.concat(activityDetails, '\n')
  ui.forgottenRule:setTooltip('Each forge consumes activity from all four regions.\nSelect Forge activity for banked time and earning rules.')
  ui.forgottenActivityDetailsButton:setEnabled(detailMessages.activity ~= '')
  local readiness = data.canCraft == true and 'Ready to forge. Review the costs before confirming.'
    or (selected and 'Requirements incomplete. Check costs and forge activity.' or 'Add the matching Epic weapon to preview its rolls.')
  status(completionMessage or (text(data.message) ~= '' and text(data.message, 700) or readiness), completionMessage ~= nil or data.canCraft == true)
  ui.forgottenMaterialsLabel:setTooltip('All listed costs and the selected Epic weapon are consumed.\nThe finished weapon replaces it in its bag.')
end
local function showQuote(data)
  clearQuote()
  if data.success ~= true or type(data.preview) ~= 'table' or data.preview.recipeKey ~= selectedKey
    or type(data.token) ~= 'string' or #data.token == 0 or #data.token > 128 then
    ui.forgottenCraftButton:setEnabled(false)
    status(data.message or 'The forge could not prepare this design.')
    return
  end
  applyPreview(data.preview)
  quoteToken = data.token
  ui.forgottenCraftButton:setEnabled(false)
  local message = 'Forge ' .. text(data.preview.name, 90) .. '?\n\n' .. text(data.warning, 600)
  local stats = type(data.preview.resultStats) == 'table' and data.preview.resultStats or {}
  if text(stats.summary) ~= '' then message = message .. '\n\n' .. text(stats.summary, 400) end
  for index, affix in ipairs(type(stats.inheritedAffixes) == 'table' and stats.inheritedAffixes or {}) do
    if index > 2 then break end
    message = message .. '\nInherited: ' .. text(affix, 100)
  end
  message = message .. '\n\nThe listed materials, gold and base weapon will be consumed.'
  message = message .. '\nThe finished weapon replaces the selected weapon in its bag.'
  local function confirm()
      local token = quoteToken
      clearQuote()
      if token then request({action = 'forgotten_confirm', token = token}); status('Forging...') end
  end
  local function cancel()
    clearQuote(); request({action = 'forgotten_cancel'}); requestPreview()
  end
  confirmBox = displayGeneralBox(tr('Confirm Forgotten Work'), wrappedMessage(message), {
    {text = tr('Forge'), callback = confirm}, {text = tr('Cancel'), callback = cancel}
  }, confirm, cancel)
  expiryEvent = scheduleEvent(function()
    clearQuote(); status('The forge offer expired. Inspect the design again.'); requestPreview()
  end, math.min(30, math.max(1, number(data.expiresIn))) * 1000)
end
function ForgottenWorks.init(window, sender)
  ForgottenWorks.destroy()
  ui, send, recipes = {}, sender, {}
  windowSerial = windowSerial + 1
  clientSession = tostring(g_clock.millis()) .. '-' .. tostring(windowSerial)
  completionMessage = nil
  questStage, detailMessages = 0, {}
  for _, id in ipairs({'smeltPanel','forgottenPanel','smeltTab','forgottenTab','forgottenRecipes','forgottenName',
    'forgottenDescription','forgottenStats','forgottenSignature','forgottenRule','forgottenMaterials',
    'forgottenMaterialsLabel','forgottenDonor','forgottenStatus',
    'forgottenCraftButton','forgottenRefreshButton','forgottenEffect','forgottenDetails','forgottenDetailsScrollbar','forgottenDesignsLabel',
    'forgottenWeaponSeparator','forgottenWeaponDetailsButton','forgottenEffectDetailsButton','forgottenActivityDetailsButton','forgottenUnlockButton'}) do ui[id] = window:recursiveGetChildById(id) end
  ui.forgottenWeaponDetailsButton.onClick = function() showDetails('Weapon details', detailMessages.weapon) end
  ui.forgottenEffectDetailsButton.onClick = function() showDetails('Signature details', detailMessages.signature) end
  ui.forgottenActivityDetailsButton.onClick = function() showDetails('Forge activity', detailMessages.activity) end
  ui.forgottenUnlockButton.onClick = function()
    showDetails('Unlock designs', '1. Complete The Ascent and ask Bolgrim about forgotten works.\n'
      .. '2. Defeat Dwarf Guards or Dwarf Geomancers and loot your Old Forging Mould from the corpse. Return it to Bolgrim.\n'
      .. '3. Use a Forging Page to permanently learn that family of designs.\n\n'
      .. 'Page sources in their normal hunting regions:\n'
      .. 'Dwarf: Dwarf Guard, Dwarf Geomancer.\n'
      .. 'Barbarian: Bloodwalker, Brutetamer, Headsplitter, Skullhunter.\n'
      .. 'Dragon: Dragon, Dragon Hatchling.\n'
      .. 'Lava: Fire Devil, Fire Elemental.\n\n'
      .. 'Pages have a 2% chance per eligible regional kill. Keep more than 14 hours of stamina remaining and take part in the fight.\n'
      .. 'Designs stay learned. Crafting costs and personal forge activity are separate requirements.')
  end
  local function selectTab(forgotten)
    clearQuote()
    closeDetails()
    ui.smeltPanel:setVisible(not forgotten); ui.forgottenPanel:setVisible(forgotten)
    ui.smeltTab:setOn(not forgotten); ui.forgottenTab:setOn(forgotten)
    if forgotten then
      ui.forgottenCraftButton:setEnabled(false)
      status('Inspecting your discovered works...')
      request({action = 'forgotten_open'})
    end
  end
  ui.smeltTab.onClick = function() selectTab(false) end
  ui.forgottenTab.onClick = function() selectTab(true) end
  ui.forgottenRefreshButton.onClick = function()
    clearQuote(); clearDetails(); status('Refreshing your discovered works...')
    ui.forgottenCraftButton:setEnabled(false); request({action = 'forgotten_refresh'})
  end
  ui.forgottenCraftButton.onClick = function()
    if selectedKey then
      ui.forgottenCraftButton:setEnabled(false)
      request({action = 'forgotten_quote', recipeKey = selectedKey, donor = donor})
    end
  end
  ui.forgottenDonor.onDrop = function(widget, droppedWidget)
    local item = droppedWidget and droppedWidget.getItem and droppedWidget:getItem()
    local pos = item and item:getPosition()
    if not selectedKey or type(pos) ~= 'table' then return false end
    local recipe = selectedRecipe()
    if not recipe or item:getId() ~= number(recipe.donorClientId) then
      status('This design requires ' .. text(recipe and recipe.donorName or 'the matching base weapon', 90) .. '.')
      return false
    end
    clearQuote()
    clearDetails()
    completionMessage = nil
    donor = {id = number(recipe.donorId), clientId = item:getId(), pos = {x = pos.x, y = pos.y, z = pos.z}}
    ui.forgottenCraftButton:setEnabled(false)
    ui.forgottenStats:setText('Inspecting weapon rolls...')
    status('Inspecting the selected Epic weapon...')
    requestPreview()
    return true
  end
  ui.forgottenDonor.onMouseRelease = function(widget, mousePos, button)
    if button ~= MouseRightButton then return false end
    clearQuote(); clearDetails(); donor, completionMessage = nil, nil; ui.forgottenDonor:setItemId(0)
    ui.forgottenCraftButton:setEnabled(false); ui.forgottenStats:setText('Inspecting base values...')
    status('Inspecting the design without a donor weapon...'); requestPreview()
    return true
  end
end
function ForgottenWorks.handles(action)
  return type(action) == 'string' and action:match('^forgotten_') ~= nil
end
function ForgottenWorks.handle(data, bootstrap)
  if data.action == 'forgotten_result' then
    local key = tostring(data.clientSession) .. ':' .. tostring(data.requestId)
    if not pendingResults[key] then
      -- Session/distance errors can use the result envelope even when the
      -- request was a preview. Only the current window may display them.
      if ui and data.success == false and data.clientSession == clientSession and data.requestId == latestRequest then
        clearQuote(); ui.forgottenCraftButton:setEnabled(false)
        status(data.message or 'Return to the lava forge and open it again.')
      end
      return
    end
    pendingResults[key] = nil
    local message = text(data.message, 700)
    if message == '' then message = data.success and 'Forging complete.' or 'Forging failed.' end
    if data.success then modules.game_textmessage.displayStatusMessage(message)
    else modules.game_textmessage.displayFailureMessage(message) end
    if not ui or data.clientSession ~= clientSession or data.requestId ~= latestRequest then return end
    clearQuote()
    if data.success then
      local recipe = selectedRecipe()
      donor, completionMessage = nil, 'Forged ' .. text(recipe and recipe.name or 'the weapon', 90) .. '. Epic rolls preserved.'
      ui.forgottenDonor:setItemId(0)
    end
    if type(data.snapshot) == 'table' then applySnapshot(data.snapshot, true) end
    status(message, data.success == true)
    return
  end
  if not ui or (not bootstrap and (data.clientSession ~= clientSession or data.requestId ~= latestRequest)) then return end
  if data.success == false and data.action ~= 'forgotten_result' then
    if data.action == 'forgotten_quote' and type(data.preview) == 'table' and data.preview.recipeKey == selectedKey then
      -- The server revalidates immediately before quoting. Show those current
      -- counts/stats even when the changed selection cannot be forged.
      applyPreview(data.preview)
    end
    clearQuote(); ui.forgottenCraftButton:setEnabled(false); status(data.message or 'The forge is unavailable.')
    return
  end
  if data.action == 'forgotten_snapshot' and data.v == 1 and data.success == true then applySnapshot(data, true, bootstrap)
  elseif data.action == 'forgotten_preview' then applyPreview(data)
  elseif data.action == 'forgotten_quote' then showQuote(data)
  elseif data.success == false then
    clearQuote(); ui.forgottenCraftButton:setEnabled(false); status(data.message or 'The forge is unavailable.')
  end
end
function ForgottenWorks.destroy(clearPending)
  clearQuote()
  closeDetails()
  if ui and send and clientSession and not clearPending then request({action = 'forgotten_close'}) end
  ui, send, recipes, selectedKey, donor = nil, nil, nil, nil, nil
  clientSession, latestRequest, completionMessage = nil, nil, nil
  detailMessages, questStage = nil, nil
  if clearPending then pendingResults = {} end
end
