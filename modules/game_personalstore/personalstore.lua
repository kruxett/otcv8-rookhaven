local allowedDistance = 2
local distanceCheckerEvent = nil

local MainWindow, MainButton, ItemStoreTooltip
local MainPanel, ItemEditPanel, BuyItemPanel, StartStorePanel
local ItemsPanel, EditStoreButton, StartStoreButton
local Key = "Menu"
local Opcode = 3

local editMode = true
local storeOpen = false
local pendingVisualSync = false

local CurrentStore = {}

local PersonalStoreModeOff = 0
local PersonalStoreModeOn = 1

local function isInProtectionZone()
    return modules.game_inventory and modules.game_inventory.checkPz and modules.game_inventory.checkPz() or false
end

local function updateRarityFrame(itemWidget, rarity)
	if g_game and g_game.updateRarityFrames then
		g_game.updateRarityFrames(itemWidget, rarity or 0)
	end
end

function init()
	MainWindow = g_ui.displayUI('personalstore')
	MainPanel = MainWindow:getChildById('mainPanel')
	ItemEditPanel = MainWindow:getChildById('itemEditPanel')
	BuyItemPanel = MainWindow:getChildById('buyItemPanel')
	StartStorePanel = MainWindow:getChildById('startStorePanel')
	ItemsPanel = MainPanel:getChildById('itemsFlatPanel')
	CountSelector = MainPanel:getChildById('countSelector')
	BuyButton = MainPanel:getChildById('buyButton')
	
	local PurchasePanel = MainPanel:getChildById('purchasePanel')
	if PurchasePanel then
		EditStoreButton = PurchasePanel:getChildById('editStoreButton')
		StartStoreButton = PurchasePanel:getChildById('startStoreButton')
		EditPriceButton = PurchasePanel:getChildById('editPriceButton')
		ContainerItemsPanel = PurchasePanel:getChildById('containerItemsPanel')
		
		if ContainerItemsPanel then
		else
		end
	else
	end
	
	ItemStoreTooltip = g_ui.displayUI('storetooltip')

	connect(g_game, {
		onGameStart = refresh,
		onGameEnd = refresh,
		onMapKnown = onMapKnown,
	})
	
	ProtocolGame.registerExtendedOpcode(Opcode, parsePersonalStore)
	MainWindow:hide()
	
	if EditPriceButton then
		EditPriceButton.onClick = function()
			openEditPricePanel()
		end
		EditPriceButton:setVisible(false)
	end
	setupDropFunctionality()
end


function terminate()
	disconnect(g_game, {
		onGameStart = refresh,
		onGameEnd = refresh,
		onMapKnown = onMapKnown,
	})
	
	ProtocolGame.unregisterExtendedOpcode(Opcode)
	ItemStoreTooltip:destroy()
	ItemStoreTooltip = nil
	MainWindow:destroy()
	MainWindow = nil
end

function toggle()
    if MainWindow:isVisible() then
        hide()
    else
		requestPersonalStore(g_game.getCharacterName())
    end
end


function refresh()
	pendingVisualSync = false
	MainWindow:hide()

	if g_game.isOnline() then
		scheduleEvent(function()
			if g_game.isOnline() and g_game.getProtocolGame() then
				requestPersonalStore(g_game.getCharacterName(), true)
			end
		end, 250)
	end
end

-- Called when the map is first loaded after any login (including reconnect to
-- an offline-vendor session where onGameStart is never fired).  Triggers a
-- silent store sync so the reconnecting owner's own client reflects the
-- correct ps_mode immediately after the map is ready.
function onMapKnown()
	if not g_game.isOnline() then return end
	scheduleEvent(function()
		if g_game.isOnline() and g_game.getProtocolGame() then
			requestPersonalStore(g_game.getCharacterName(), true)
		end
	end, 300)
end

function show()
	BuyItemPanel:hide()
	ItemEditPanel:hide()
	MainWindow:show()
	MainWindow:raise()
	MainWindow:focus()
end

function hide()
	if distanceCheckerEvent then
		removeEvent(distanceCheckerEvent)
		distanceCheckerEvent = nil
	end
	
	for _, child in ipairs(ItemsPanel:getChildren()) do
		if child.itemInfo then
			child.itemInfo.isSelected = false
			child:setBorderColor("alpha")
			
			local borderWidget = child:getChildById('border')
			if borderWidget then
				borderWidget:setOpacity(0)
			end
		end
	end
	resetMainPanel()
	MainWindow:hide()
end



function inEditMode()
	return editMode
end

function onPersonalStoreModeChange(creature, mode, name)
end

function removeItemFromPanel(slot)
	if not slot or not slot.itemInfo then
		return
	end
	
	local slotItemId = slot:getChildById('item'):getItemId()
	
	slot.itemInfo = nil
	slot:getChildById('item'):setItemId(0)
	slot:getChildById('item'):setItemCount(0)
	updateRarityFrame(slot:getChildById('item'), 0)
	slot:getChildById('buyOrEdit'):setText("")
	slot:getChildById('buyOrEdit'):disable()
	slot:getChildById('remove'):setVisible(false)
	
	local border = slot:getChildById('border')
	if border then
		border:setOpacity(0)
	end
	
	if EditStoreButton then
		EditStoreButton:setText("Edit Store")
	end
	if EditPriceButton then
		EditPriceButton:setVisible(false)
	end
	
	local purchasePanel = MainPanel:getChildById('purchasePanel')
	if purchasePanel then
		local selectedItem = purchasePanel:getChildById('selectedItem')
		local itemName = purchasePanel:getChildById('itemName')
		local itemPrice = purchasePanel:getChildById('itemPrice')
		local itemAmount = purchasePanel:getChildById('itemAmount')
		local itemWeight = purchasePanel:getChildById('itemWeight')
		local containerPanel = purchasePanel:getChildById('containerItemsPanel')
		
		if selectedItem and selectedItem:getItemId() ~= 0 and selectedItem:getItemId() == slotItemId then
			selectedItem:setItemId(0)
			selectedItem:setItemCount(0)
			updateRarityFrame(selectedItem, 0)
			
			if itemName then itemName:setText("No Item Selected") end
			if itemPrice then itemPrice:setText("Price: 0") end
			if itemAmount then itemAmount:setText("Amount: 0x") end
			if itemWeight then itemWeight:setText("Weight: 0 oz") end
		end
		
		if containerPanel then
			containerPanel:setVisible(false)
			containerPanel:destroyChildren()
		end
	end
end

function enableEditionModeOrOfflineMode()
	if CurrentStore.mode == PersonalStoreModeOn then
		g_game.getProtocolGame():sendExtendedOpcode(Opcode, json.encode({ protocol = 'ClosePersonalStore' }))
	elseif CurrentStore.mode == PersonalStoreModeOff then
		editMode = not editMode
		local color = editMode and "#00FF21" or "alpha"
		
		for _, child in ipairs(ItemsPanel:getChildren()) do
			child:setBackgroundColor(color)
			if child.itemInfo and child.itemInfo.itemid and child.itemInfo.itemid > 0 then
				child:getChildById('buyOrEdit'):setText(editMode and "Edit" or child.itemInfo.price)
				child:getChildById('buyOrEdit'):enable()
				child:getChildById('remove'):setVisible(editMode)
				child:getChildById('remove').onClick = function()
					g_game.getProtocolGame():sendExtendedOpcode(Opcode,
					json.encode({ protocol = 'RemoveItemFromPersonalStore', item_code = child.itemInfo.item_code }))
					removeItemFromPanel(child)
				end
			end
		end
		
		
		if EditStoreButton then
			EditStoreButton:setVisible(true)
			EditStoreButton:setText(editMode and "Finalize Edits" or "Edit Store")
		end
		
		if EditPriceButton then
			EditPriceButton:setVisible(editMode)
		end
		
		StartStoreButton:setText(editMode and "Select Item" or
		(CurrentStore.mode == PersonalStoreModeOff and "Start Store" or "Close Store"))
	end
end



function openEditPricePanel()
	local selectedItemInfo = nil
	
	for _, child in ipairs(ItemsPanel:getChildren()) do
		if child.itemInfo and child.itemInfo.isSelected then
			selectedItemInfo = child.itemInfo
			break
		end
	end
	
	if not selectedItemInfo then
		displayErrorBox("Erro", "Nenhum item selecionado para edi��o de pre�o.")
		return
	end
	
	showEditItemPanel(selectedItemInfo)
end


function selectItemToSell()
	if itemsFull() then
		return
	end

	if not isInProtectionZone() then
		displayErrorBox('Personal Store', 'You can only add items to the store while in a protection zone (PZ).')
		return
	end
	
	local gameInterface = modules.game_interface
	local mouseGrabberWidget = gameInterface.getMouseGrabberWidget()
	mouseGrabberWidget:grabMouse()
	g_mouse.pushCursor('target')
	
	mouseGrabberWidget.onMouseRelease = function(self, mousePosition, mouseButton)
		if mouseButton == MouseLeftButton then
			local clickedWidget = gameInterface.getRootPanel():recursiveGetChildByPos(mousePosition, false)
			
			if clickedWidget and clickedWidget:getClassName() == 'UIItem' and clickedWidget:getItem() and not clickedWidget:isVirtual() then
				local item = clickedWidget:getItem()
				
				if not item then
					return
				end
				
				local foundSlot = false
				for _, child in ipairs(ItemsPanel:getChildren()) do
					if not child.itemInfo or not child.itemInfo.itemid or child.itemInfo.itemid == 0 then
						child.itemInfo = {
							itemid = item:getId(),
							count = item:getCount(),
							isSelected = true
						}
						child:setBorderColor("#FFFFFF")
						foundSlot = true
						
						g_game.getProtocolGame():sendExtendedOpcode(Opcode, json.encode({
							protocol = 'SelectItemToSell',
							pos = item:getPosition()
						}))
						
						local purchasePanel = MainPanel:getChildById('purchasePanel')
						local itemCountScroll = purchasePanel:getChildById('itemCountScroll')
						itemCountScroll:setMinimum(1)
						itemCountScroll:setMaximum(item:getCount())
						itemCountScroll:setValue(1)
						break
					end
				end
				
				if not foundSlot then
				end
			else
			end
		end
		
		while g_mouse.isCursorChanged() do
			g_mouse.popCursor('target')
		end
		self:ungrabMouse()
		mouseGrabberWidget.onMouseRelease = nil
		mouseGrabberWidget.onMouseRelease = gameInterface.onMouseGrabberRelease
	end
end

function itemsFull()
	for i, child in ipairs(ItemsPanel:getChildren()) do
		if not child.itemInfo or not child.itemInfo.itemid or child.itemInfo.itemid == 0 then return false end
	end
	return true
end

local function doFormatMoney(money)
	local moneyMap = {
		10000,
		100,
		1,
	}
	
	local formatMoney = {}
	local tmpMoney = 0
	
	for i, value in pairs(moneyMap) do
		tmpMoney = math.floor(money / value)
		money = money - (tmpMoney * value)
		formatMoney[i] = tmpMoney
	end
	
	return formatMoney
end

function updatePrices(panel, price)
	if not price then price = 0 end
	for m, value in pairs(doFormatMoney(price)) do
		panel:getChildById(m):setText(value)
	end
end

function showEditItemPanel(itemInfo)
	MainPanel:hide()
	ItemEditPanel:getChildById('item'):setItemId(itemInfo.clientId)
	ItemEditPanel:getChildById('item').item_code = itemInfo.item_code
	updateRarityFrame(ItemEditPanel:getChildById('item'), itemInfo.rarity)
	ItemEditPanel:getChildById('item'):setItemCount(itemInfo.count)
	ItemEditPanel:getChildById('count'):setMaximum(itemInfo.count)
	ItemEditPanel:getChildById('count'):setMinimum(1)
	ItemEditPanel:getChildById('count'):setValue(itemInfo.count)
	ItemEditPanel:getChildById('price'):getChildById('value'):setText(itemInfo.price)
	updatePrices(ItemEditPanel:getChildById('price'):getChildById('moneyPanel'), itemInfo.price)
	ItemEditPanel:getChildById('count').onValueChange = function(self, value)
		ItemEditPanel:getChildById('item'):setItemCount(value)
	end
	ItemEditPanel:getChildById('price'):getChildById('value').onTextChange = function(self, text, oldText)
		if tonumber(text) then
			updatePrices(ItemEditPanel:getChildById('price'):getChildById('moneyPanel'), tonumber(text))
		end
	end
	ItemEditPanel:getChildById('confirm').onClick = function()
		local count = tonumber(ItemEditPanel:getChildById('count'):getValue())
		g_game.getProtocolGame():sendExtendedOpcode(Opcode,
		json.encode({ protocol = 'AddOrEditItemToPersonalStore', checking = itemInfo.checking, itemid = itemInfo.itemid, item_code =
			itemInfo.item_code, count = count, price = tonumber(ItemEditPanel:getChildById('price'):getChildById('value')
		:getText()) }))
	end
	ItemEditPanel:show()
end

function showBuyItemPanel(itemInfo)
	MainPanel:hide()
	BuyItemPanel:getChildById('item'):setItemId(itemInfo.clientId)
	BuyItemPanel:getChildById('item').item_code = itemInfo.item_code
	updateRarityFrame(BuyItemPanel:getChildById('item'), itemInfo.rarity)
	BuyItemPanel:getChildById('item'):setItemCount(itemInfo.count)
	BuyItemPanel:getChildById('count'):setMaximum(itemInfo.count)
	BuyItemPanel:getChildById('count'):setMinimum(1)
	BuyItemPanel:getChildById('count'):setValue(itemInfo.count)
	updatePrices(BuyItemPanel:getChildById('price'), (itemInfo.price * itemInfo.count))
	BuyItemPanel:getChildById('count').onValueChange = function(self, value)
		updatePrices(BuyItemPanel:getChildById('price'), (itemInfo.price * value))
		BuyItemPanel:getChildById('count'):setValue(value)
		BuyItemPanel:getChildById('item'):setItemCount(value)
	end
	BuyItemPanel:getChildById('confirm').onClick = function()
		g_game.getProtocolGame():sendExtendedOpcode(Opcode,
		json.encode({ protocol = 'BuyItemFromPersonalStore', name = CurrentStore.ownername, item_code = itemInfo.item_code, count =
		BuyItemPanel:getChildById('count'):getValue() }))
	end
	BuyItemPanel:show()
end

function showStartStorePanel()
	MainPanel:hide()
	StartStorePanel:getChildById('description'):setText(CurrentStore.name)
	StartStorePanel:getChildById('confirm').onClick = function()
		g_game.getProtocolGame():sendExtendedOpcode(Opcode,
		json.encode({ protocol = 'StartPersonalStore', name = StartStorePanel:getChildById('description'):getText() }))
	end
	StartStorePanel:show()
end

function showMainPanel()
	BuyItemPanel:hide()
	ItemEditPanel:hide()
	StartStorePanel:hide()
	MainPanel:show()
	local color = editMode and "#00FF21" or "alpha"
	for i, child in ipairs(ItemsPanel:getChildren()) do
		child:setBackgroundColor(color)
	end
end

function selectOrStartStore()
	if not CurrentStore or not CurrentStore.mode then
		return
	end
	
	if editMode then
		selectItemToSell()
	else
		if CurrentStore.mode == PersonalStoreModeOff then
			g_game.getProtocolGame():sendExtendedOpcode(Opcode, json.encode({ protocol = 'StartPersonalStore' }))
		else
			g_game.getProtocolGame():sendExtendedOpcode(Opcode, json.encode({ protocol = 'ClosePersonalStore' }))
		end
	end
end


function requestPersonalStore(name, silent)
	pendingVisualSync = silent == true
	g_game.getProtocolGame():sendExtendedOpcode(Opcode, json.encode({ protocol = 'RequestPersonalStore', name = name }))
end

local function checkDistance()
	local localPlayer = g_game.getLocalPlayer()
	if not localPlayer or not CurrentStore or not CurrentStore.ownerPosition then
		return
	end
	
	local playerPos = localPlayer:getPosition()
	local ownerPos = CurrentStore.ownerPosition
	
	if not playerPos or not ownerPos then
		hide()
		return
	end
	
	if playerPos.z ~= ownerPos.z or math.abs(playerPos.x - ownerPos.x) > allowedDistance or math.abs(playerPos.y - ownerPos.y) > allowedDistance then
		hide()
	else
		distanceCheckerEvent = scheduleEvent(checkDistance, 500)
	end
end


function parsePersonalStore(protocol, opcode, buffer)
	local personal_store = json.decode(buffer)
	local purchasePanel = MainPanel:getChildById('purchasePanel')
	
	if purchasePanel then
		EditStoreButton = purchasePanel:getChildById('editStoreButton')
		StartStoreButton = purchasePanel:getChildById('startStoreButton')
		if EditStoreButton then EditStoreButton:setVisible(false) end
		if StartStoreButton then StartStoreButton:setVisible(false) end
	end
	
	if personal_store.protocol == "Close" then
		hide()
		return
	end
	
	if personal_store.protocol == "item_checked" then
		showEditItemPanel(personal_store)
		return
	end
	
	if personal_store.protocol == "ps" then
		if personal_store.owner then
			local localPlayer = g_game.getLocalPlayer()
			if localPlayer then
				localPlayer:setPersonalStore(personal_store.mode or PersonalStoreModeOff, personal_store.name or personal_store.ownername or "")
			end
		end

		if pendingVisualSync then
			pendingVisualSync = false
			return
		end

		editMode = false
		
		for _, child in ipairs(ItemsPanel:getChildren()) do
			resetItemSlot(child)
		end
		
		MainWindow:setText(personal_store.name)
		CurrentStore = personal_store
		
		if distanceCheckerEvent then
			removeEvent(distanceCheckerEvent)
		end
		distanceCheckerEvent = scheduleEvent(checkDistance, 500)
		
		
		for i, itemInfo in ipairs(personal_store.items) do
			local slot = ItemsPanel:getChildById('item' .. i)
			
			if slot then
				slot.itemInfo = itemInfo
				slot:getChildById('item'):setItemId(itemInfo.clientId)
				slot:getChildById('item').item_code = itemInfo.item_code
				updateRarityFrame(slot:getChildById('item'), itemInfo.rarity)
				slot:getChildById('item'):setItemCount(itemInfo.count)
				slot:getChildById('buyOrEdit'):setText(personal_store.owner and itemInfo.price or "Buy")
				slot:getChildById('buyOrEdit'):enable()
				
				
				slot:getChildById('item').onClick = function()
					if not slot.itemInfo then
						return
					end
					
					for _, sibling in ipairs(ItemsPanel:getChildren()) do
						if sibling.itemInfo then
							sibling.itemInfo.isSelected = false
							sibling:setBorderColor("alpha")
							local siblingBorder = sibling:getChildById('border')
							if siblingBorder then
								siblingBorder:setOpacity(0)
							end
						end
					end
					
					slot.itemInfo.isSelected = true
					slot:setBorderColor("#FFFFFF")
					local borderWidget = slot:getChildById('border')
					if borderWidget then
						borderWidget:setOpacity(1)
					end
					
					updatePurchasePanel(slot.itemInfo)
					
					if slot.itemInfo.isContainer and slot.itemInfo.items then
						showContainerItems(slot.itemInfo)
					else
						local containerPanel = MainPanel:getChildById('containerItemsPanel')
						if containerPanel then
							containerPanel:setVisible(true)
							containerPanel:destroyChildren()
						end
					end
				end
			end
		end
		
		
		if personal_store.owner then
			if EditStoreButton then EditStoreButton:setVisible(true) end
			if StartStoreButton then
				StartStoreButton:setVisible(true)
				if personal_store.mode == PersonalStoreModeOn then
					StartStoreButton:setText("Close Store")
					if EditStoreButton then EditStoreButton:disable() end
				else
					StartStoreButton:setText("Start Store")
					if EditStoreButton then EditStoreButton:enable() end
				end
			end
		end
		
		
		showMainPanel()
		MainWindow:setText(personal_store.ownername .. " Shop")
		MainWindow:show()
	end
end


function showContainerItems(containerInfo)
	local purchasePanel = MainPanel:getChildById('purchasePanel')
	local containerPanel = purchasePanel:getChildById('containerItemsPanel')
	
	if not containerPanel then
		return
	end
	
	containerPanel:destroyChildren()
	
	if not containerInfo or not containerInfo.items then
		return
	end
	
	for i, itemInfo in ipairs(containerInfo.items) do
		local slot = g_ui.createWidget('PSItem', containerPanel)
		slot:getChildById('item'):setItemId(itemInfo.clientId)
		slot:getChildById('item'):setItemCount(itemInfo.count or 1)
		updateRarityFrame(slot:getChildById('item'), itemInfo.rarity or 0)
	end
	
	containerPanel:setVisible(true)
end

function setupDropFunctionality()
	ItemsPanel.onDrop = function(widget, droppedItem, mousePos)
		if not CurrentStore or CurrentStore.ownername ~= g_game.getCharacterName() then
			return
		end
		
		if not droppedItem or type(droppedItem.getItem) ~= "function" then
			return
		end
		
		local item = droppedItem:getItem()
		
		if not item then
			return
		end
		
		if itemsFull() then
			return
		end
		
		for _, child in ipairs(ItemsPanel:getChildren()) do
			if not child.itemInfo or not child.itemInfo.itemid or child.itemInfo.itemid == 0 then
				addItemToPanel(child, item)
				g_game.getProtocolGame():sendExtendedOpcode(Opcode, json.encode({
					protocol = 'SelectItemToSell',
					pos = item:getPosition()
				}))
				return
			end
		end
	end
end

function setupItemPanel(panel, itemInfo, mode)
	if not itemInfo then
		panel:getChildById('item'):setItemId(0)
		panel:getChildById('count'):setValue(0)
		panel:getChildById('price'):getChildById('value'):setText("0")
		return
	end
	
	panel:getChildById('item'):setItemId(itemInfo.clientId)
	panel:getChildById('item').item_code = itemInfo.item_code
	updateRarityFrame(panel:getChildById('item'), itemInfo.rarity)
	panel:getChildById('item'):setItemCount(itemInfo.count)
	
	if mode == "edit" then
		panel:getChildById('count'):setMaximum(itemInfo.count)
		panel:getChildById('count'):setMinimum(1)
		panel:getChildById('count'):setValue(itemInfo.count)
		panel:getChildById('price'):getChildById('value'):setText(itemInfo.price)
	elseif mode == "buy" then
		local price = (itemInfo.price * itemInfo.count)
		updatePrices(panel:getChildById('price'), price)
	end
end

function updatePriceUI(panel, price, count)
	count = count or 1
	local totalPrice = price * count
	
	if panel:getChildById('itemAmount') then
		panel:getChildById('itemAmount'):setText("Amount: " .. count .. "x")
	end
end

function addItemToPanel(slot, item)
	if not item or type(item.getId) ~= "function" or type(item.getCount) ~= "function" then
		return
	end
	
	if not slot then
		return
	end
	
	slot:setVisible(true)
	slot.itemInfo = {
		itemid = item:getId(),
		count = item:getCount(),
		clientId = item:getId(),
		rarity = 0,
		price = 0,
	}
	slot:getChildById('item'):setItemId(item:getId())
	slot:getChildById('item'):setItemCount(item:getCount())
	updateRarityFrame(slot:getChildById('item'), 0)
	slot:getChildById('buyOrEdit'):setText("Edit")
	slot:getChildById('buyOrEdit'):enable()
	slot:getChildById('remove'):setVisible(true)
	slot:getChildById('remove').onClick = function()
		removeItemFromPanel(slot)
	end
	slot:getChildById('buyOrEdit').onClick = function()
		showEditItemPanel(slot.itemInfo)
	end
	
	g_game.getProtocolGame():sendExtendedOpcode(Opcode, json.encode({
		protocol = 'AddItemToPersonalStore',
		itemid = item:getId(),
		count = item:getCount(),
		rarity = 0,
		price = 0,
		clientId = item:getId()
	}))
end


function buySelectedItem()
	local purchasePanel = MainPanel:getChildById('purchasePanel')
	local itemCountScroll = purchasePanel:getChildById('itemCountScroll')
	
	for _, child in ipairs(ItemsPanel:getChildren()) do
		if child.itemInfo and child.itemInfo.isSelected then
			local selectedCount = itemCountScroll:getValue() or 1
			
			g_game.getProtocolGame():sendExtendedOpcode(Opcode, json.encode({
				protocol = 'BuyItemFromPersonalStore',
				name = CurrentStore.ownername,
				item_code = child.itemInfo.item_code,
				count = selectedCount
			}))
			
			return
		end
	end
end


function resetItemSlot(slot)
	if not slot then return end
	
	slot:setBorderColor("alpha")
	slot:getChildById('item'):setItemId(0)
	slot:getChildById('item'):setItemCount(0)
	updateRarityFrame(slot:getChildById('item'), 0)
	slot:getChildById('buyOrEdit'):setText("")
	slot:getChildById('buyOrEdit'):disable()
	slot:getChildById('remove'):setVisible(false)
	
	local border = slot:getChildById('border')
	if border then
		border:setOpacity(0)
	end
	
	slot.itemInfo = nil
	
	slot:getChildById('item').onClick = function() end
end

function updatePurchasePanel(itemInfo)
	local purchasePanel = MainPanel:getChildById('purchasePanel')
	local selectedItem = purchasePanel:getChildById('selectedItem')
	local countScroll = purchasePanel:getChildById('itemCountScroll')
	local buyButton = purchasePanel:getChildById('buyButton')
	local containerPanel = purchasePanel:getChildById('containerItemsPanel')
	
	if not itemInfo then
		selectedItem:setItemId(0)
		updateRarityFrame(selectedItem, 0)
		purchasePanel:getChildById('itemName'):setText("No Item Selected")
		purchasePanel:getChildById('itemPrice'):setText("Price: 0")
		purchasePanel:getChildById('itemAmount'):setText("Amount: 0x")
		purchasePanel:getChildById('itemWeight'):setText("Weight: 0 oz")
		countScroll:setVisible(false)
		
		if containerPanel then
			containerPanel:setVisible(false)
			containerPanel:destroyChildren()
		end
		
		if buyButton then
			buyButton:setVisible(false)
			buyButton:disable()
		end
		return
	end
	
	local unitPrice = itemInfo.price or 0
	local weight = itemInfo.weight / 100
	local name = itemInfo.name or "Unknown Item"
	local rarity = itemInfo.rarity or 0
	local maxCount = itemInfo.count or 1
	
	selectedItem:setItemId(itemInfo.clientId)
	updateRarityFrame(selectedItem, rarity)
	
	purchasePanel:getChildById('itemName'):setText(name)
	purchasePanel:getChildById('itemPrice'):setText("Price: " .. unitPrice)
	purchasePanel:getChildById('itemAmount'):setText("Amount: 1x")
	purchasePanel:getChildById('itemWeight'):setText(string.format("Weight: %.2f oz", weight))
	
	countScroll:setVisible(true)
	countScroll:setMinimum(1)
	countScroll:setMaximum(maxCount)
	countScroll:setStep(1)
	countScroll:setValue(1)
	
	countScroll.onValueChange = function(_, value)
		purchasePanel:getChildById('itemAmount'):setText("Amount: " .. value .. "x")
		purchasePanel:getChildById('itemPrice'):setText("Price: " .. (unitPrice * value))
		purchasePanel:getChildById('itemWeight'):setText(string.format("Weight: %.2f oz", weight * value))
	end
	
	if buyButton then
		if CurrentStore and CurrentStore.ownername == g_game.getCharacterName() then
			buyButton:setVisible(false)
			buyButton:disable()
		else
			buyButton:setVisible(true)
			buyButton:enable()
		end
	end
	
	if itemInfo.isContainer and itemInfo.items then
		showContainerItems(itemInfo)
	elseif containerPanel then
		containerPanel:setVisible(false)
		containerPanel:destroyChildren()
	end
end


function resetMainPanel()
	local purchasePanel = MainPanel:getChildById('purchasePanel')
	if purchasePanel then
		local buyButton = purchasePanel:getChildById('buyButton')
		if buyButton then
			buyButton:setVisible(false)
			buyButton:disable()
			buyButton.selectedItem = nil
		end
		
		EditStoreButton = purchasePanel:getChildById('editStoreButton')
		StartStoreButton = purchasePanel:getChildById('startStoreButton')
		
		if EditStoreButton then EditStoreButton:setVisible(false) end
		if StartStoreButton then StartStoreButton:setVisible(false) end
	end
	
	updatePurchasePanel(nil)
end