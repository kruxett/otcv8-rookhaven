-- Execute the actual shop configuration, shop handlers and admin command.
-- Isolated API doubles verify contracts; native shooting is tested separately.
local serverRoot = assert(arg[1], "Supply the Rookhaven server root")
local checks = 0
local function check(condition, message)
	assert(condition, message)
	checks = checks + 1
end

local pendingPayload, players = nil, {}
local env = setmetatable({}, {__index = _G})
env.Opcodes = {GameShop = 201}
env.MESSAGE_STATUS_CONSOLE_BLUE = 1
env.CONST_SLOT_AMMO = 10
env.WEAPON_AMMO = 7
local function itemType(id)
	return {
		getId = function() return id end,
		getName = function() return id == 12830 and "magic quiver" or "fixture item" end,
		getClientId = function()
			if id >= 12858 and id <= 12867 then return id - 963 end
			return id == 12830 and 11867 or id + 100
		end,
		isContainer = function() return id == 12830 end,
		getCapacity = function() return id == 12830 and 20 or 0 end,
		getWeaponType = function() return (id == 2544 or id == 2543) and env.WEAPON_AMMO or 0 end,
	}
end
env.ItemType = itemType
env.Player = function(name) return players[name] end
env.json = {encode = function(value) pendingPayload = value; return "{}" end}
local function loadActual(relative)
	local chunk = assert(loadfile(serverRoot .. "/" .. relative))
	setfenv(chunk, env)
	return chunk()
end
env.dofile = function(relative) return loadActual(relative) end
local config = loadActual("data/lib/game_shop_config.lua")
loadActual("data/lib/core/game_shop.lua")
loadActual("data/talkactions/scripts/quiver.lua")
local shop, command = env.GameShop, env.onSay

local nextGuid = 100
local function player(name, groupId, access)
	nextGuid = nextGuid + 1
	local object = {
		name = name, guid = nextGuid, storage = {[910500] = 1000}, replies = {},
		messages = {}, cancels = {}, deliveries = {}, learned = {}, groupId = groupId or 1,
		access = access == nil and ((groupId or 1) >= 4) or access,
	}
	function object:getName() return self.name end
	function object:getGuid() return self.guid end
	function object:getStorageValue(key) return self.storage[key] or -1 end
	function object:setStorageValue(key, value) self.storage[key] = value end
	function object:sendExtendedOpcode(opcode, encoded)
		check(opcode == 201 and encoded == "{}", "Shop changed its opcode/encoding contract")
		self.replies[#self.replies + 1] = pendingPayload
		return true
	end
	function object:sendTextMessage(kind, message) self.messages[#self.messages + 1] = message end
	function object:sendCancelMessage(message) self.cancels[#self.cancels + 1] = message end
	function object:getGroup()
		return {getId = function() return self.groupId end, getAccess = function() return self.access end}
	end
	function object:getAccountType() error("Character group authority must not inspect account type") end
	function object:addItem(id, count, canDropOnMap)
		self.lastAdd = {id = id, count = count, canDropOnMap = canDropOnMap}
		if self.rejectDelivery then return nil end
		local item = {getId = function() return id end}
		self.deliveries[#self.deliveries + 1] = item
		return item
	end
	function object:hasLearnedSpell(spell) return self.learned[spell] == true end
	object.sex, object.outfits = 1, {}
	function object:getSex() return self.sex end
	function object:hasOutfit(look, addons)
		if look < 373 or look > 398 or (look - 373) % 2 ~= self.sex then return false end
		local owned = self.outfits[look]
		return owned ~= nil and (addons == 0 or owned == addons or owned == 3)
	end
	function object:addOutfitAddon(look, addons)
		local owned = self.outfits[look] or 0
		if owned == 3 or addons == 3 or (owned ~= 0 and owned ~= addons) then
			self.outfits[look] = 3
		else
			self.outfits[look] = addons
		end
		return not self.rejectOutfitGrant
	end
	function object:canWearOutfit(look, addons) return not self.rejectOutfitWear and self:hasOutfit(look, addons) end
	function object:removeOutfit(look) self.outfits[look] = nil; return true end
	function object:removeOutfitAddon(look, addon)
		local owned = self.outfits[look]
		if owned and math.floor(owned / addon) % 2 == 1 then self.outfits[look] = owned - addon end
		return true
	end
	function object:learnSpell(spell) self.learned[spell] = true end
	function object:getSlotItem(slot)
		check(slot == env.CONST_SLOT_AMMO, "Status looked outside the equipped ammo slot")
		return self.equipped
	end
	players[name] = object
	return object
end
local function lastMessage(object)
	local reply = object.replies[#object.replies]
	return reply and reply.data.msg or ""
end
local function buy(object, category, offer, spoof)
	shop.handleClientOpcode(object, {action = "buy", data = {
		category = category, offer = offer, cost = spoof and 0 or nil, id = spoof and 2001 or nil,
	}})
end

local function findOffer(id)
	for categoryIndex, category in ipairs(shop.catalog) do
		for offerIndex, entry in ipairs(category.offers) do
			if entry.id == id then return categoryIndex, offerIndex, entry end
		end
	end
end
check(#config.catalog == 3 and config.catalog[3].name == "Outfits", "Premium, Utility and Outfits categories expected")
local totalOffers, seenIds = 0, {}
for _, category in ipairs(config.catalog) do
	totalOffers = totalOffers + #category.offers
	for _, entry in ipairs(category.offers) do
		check(not seenIds[entry.id], "Duplicate offer ID: " .. tostring(entry.id))
		seenIds[entry.id] = true
	end
end
check(totalOffers == 36, "Expected ten existing offers plus twenty-six approved modern cosmetics")
check(#config.catalog[3].offers == 26, "Expected thirteen approved male/female outfit families")
local approvedFamilies = {"Rune Master", "Lion of War", "Afflicted", "Arbalester", "Arena Champion", "Armoured Archer",
	"Discoverer", "Entrepreneur", "Formal Dress", "Golden", "Nordic Chieftain", "Poltergeist", "Veteran Paladin"}
local expectedOutfits = {}
for familyIndex, name in ipairs(approvedFamilies) do
	for sex = 0, 1 do
		local index = (familyIndex - 1) * 2 + sex
		expectedOutfits[#expectedOutfits + 1] = {6001 + index, 373 + index, sex, name .. (sex == 0 and " (Female)" or " (Male)")}
	end
end
for _, entry in ipairs(expectedOutfits) do
	local category, row, outfit = findOffer(entry[1])
	check(outfit and outfit.type == "outfit" and outfit.cost == 250 and outfit.outfit.type == entry[2] and outfit.outfit.addons == 3
		and outfit.grant.type == "outfit" and outfit.grant.lookType == entry[2] and outfit.grant.sex == entry[3]
		and outfit.grant.addons == 3 and outfit.title == entry[4], "Outfit offer identity/price/sex/art/grant mismatch: " .. entry[4])
	local customer = player("Outfit" .. entry[1]); customer.sex = entry[3]
	shop.handleClientOpcode(customer, {action = "init"})
	check(customer.replies[#customer.replies].data[category].offers[row].grant == nil, "Private outfit grant leaked")
	buy(customer, category, row, true)
	check(customer:hasOutfit(entry[2], 3) and customer.storage[910500] == 1000 - outfit.cost
		and #shop.historyByGuid[customer.guid] == 1, "Outfit grant/debit/history failed")
	buy(customer, category, row)
	check(customer.storage[910500] == 1000 - outfit.cost and #shop.historyByGuid[customer.guid] == 1,
		"Duplicate outfit purchase charged again")
	local wrong = player("WrongSex" .. entry[1]); wrong.sex = 1 - entry[3]
	buy(wrong, category, row)
	check(next(wrong.outfits) == nil and wrong.storage[910500] == 1000 and shop.historyByGuid[wrong.guid] == nil,
		"Wrong-sex purchase changed state")
	local poor = player("PoorOutfit" .. entry[1]); poor.sex = entry[3]; poor.storage[910500] = outfit.cost - 1
	buy(poor, category, row)
	check(next(poor.outfits) == nil and poor.storage[910500] == outfit.cost - 1, "Unaffordable outfit granted or charged")
	for _, partial in ipairs({false, true}) do
		local denied = player("DeniedOutfit" .. entry[1] .. tostring(partial)); denied.sex = entry[3]
		if partial then denied.outfits[entry[2]] = 1 end
		denied.rejectOutfitWear = true
		buy(denied, category, row)
		check(denied.outfits[entry[2]] == (partial and 1 or nil) and denied.storage[910500] == 1000
			and shop.historyByGuid[denied.guid] == nil, "Failed outfit grant did not restore prior ownership/balance")
	end
	local invalid = player("BadOutfit" .. entry[1]); invalid.sex = entry[3]
	local saved = outfit.grant.lookType; outfit.grant.lookType = 65536
	buy(invalid, category, row); outfit.grant.lookType = saved
	check(next(invalid.outfits) == nil and invalid.storage[910500] == 1000, "Malformed outfit config charged or granted")
end
for _, id in ipairs({1002, 2001, 2002, 3001, 3002}) do
	check(findOffer(id) == nil, "Removed offer remains purchasable: " .. id)
end
local utilityIndex, quiverIndex, offer = findOffer(4001)
check(offer.id == 4001 and offer.cost == 150 and offer.item == 12830, "Magic Quiver offer identity/price changed")
check(offer.grant.itemId == 12830 and offer.grant.count == 1 and offer.grant.canDropOnMap == false,
	"Quiver must be delivered as one empty item without map overflow")
local shopper = player("Shopper")
shop.handleClientOpcode(shopper, {action = "init"})
local payload = shopper.replies[#shopper.replies]
check(payload.data[utilityIndex].item == 11867 and payload.data[utilityIndex].offers[quiverIndex].item == 11867,
	"Shop visuals must use client IDs resolved from the server SID")
check(payload.data[utilityIndex].offers[quiverIndex].grant == nil and payload.status.points == 1000, "Private grants leaked into shop payload")
buy(shopper, utilityIndex, quiverIndex, true)
check(#shopper.deliveries == 1 and shopper.lastAdd.canDropOnMap == false, "Quiver purchase allowed a ground drop")
check(shopper.storage[910500] == 850 and #shop.historyByGuid[shopper.guid] == 1,
	"Purchase did not deduct the server price exactly once after delivery")
check(lastMessage(shopper):find("1x magic quiver", 1, true), "Purchase did not identify the delivered quiver")
shop.handleClientOpcode(shopper, {action = "history"})
check(shopper.replies[#shopper.replies].data[1].item == 11867, "History displayed the server SID instead of the CID")

local poor = player("Poor"); poor.storage[910500] = 149
buy(poor, utilityIndex, quiverIndex)
check(#poor.deliveries == 0 and poor.storage[910500] == 149 and shop.historyByGuid[poor.guid] == nil,
	"Insufficient points granted an item or changed points/history")
local full = player("Full"); full.rejectDelivery = true
buy(full, utilityIndex, quiverIndex)
check(full.lastAdd.canDropOnMap == false and #full.deliveries == 0 and full.storage[910500] == 1000
	and shop.historyByGuid[full.guid] == nil, "Failed inventory delivery consumed points or recorded a purchase")
check(lastMessage(full):find("capacity", 1, true), "Inventory failure did not explain capacity/space")
local invalid = player("Invalid")
buy(invalid, 99, 1)
check(invalid.lastAdd == nil and invalid.storage[910500] == 1000, "Invalid category changed inventory/balance")
local originalCount = offer.grant.count
offer.grant.count = 2
buy(invalid, utilityIndex, quiverIndex)
check(invalid.lastAdd == nil and invalid.storage[910500] == 1000,
	"No-drop multi-item grants could partially deliver before failure")
offer.grant.count = originalCount

for index, expected in ipairs({{12858, 250}, {12859, 450}, {12860, 600}}) do
	local category, row, scroll = findOffer(5000 + index)
	check(scroll.item == expected[1] and scroll.cost == expected[2] and scroll.grant.itemId == expected[1],
		"Premium scroll visual/price/grant mismatch")
	local customer = player("Premium" .. index)
	shop.handleClientOpcode(customer, {action = "init"})
	local entry = customer.replies[#customer.replies].data[category].offers[row]
	check(entry.item == expected[1] - 963 and entry.grant == nil, "Premium CID/private grant contract failed")
	buy(customer, category, row, true)
	check(customer.lastAdd.id == expected[1] and customer.lastAdd.count == 1 and customer.lastAdd.canDropOnMap == false
		and customer.storage[910500] == 1000 - expected[2] and #shop.historyByGuid[customer.guid] == 1,
		"Premium purchase did not deliver/debit/record exactly once at the server price")
	local noPoints = player("PremiumPoor" .. index); noPoints.storage[910500] = expected[2] - 1
	buy(noPoints, category, row)
	check(noPoints.lastAdd == nil and noPoints.storage[910500] == expected[2] - 1 and shop.historyByGuid[noPoints.guid] == nil,
		"Rejected premium purchase changed items, points or history")
	local noSpace = player("PremiumFull" .. index); noSpace.rejectDelivery = true
	buy(noSpace, category, row)
	check(noSpace.lastAdd.canDropOnMap == false and noSpace.storage[910500] == 1000 and #noSpace.deliveries == 0
		and shop.historyByGuid[noSpace.guid] == nil, "Failed premium delivery changed points/history or dropped on the map")
end
local lightCategory, lightIndex, lightOffer = findOffer(4002)
check(lightOffer.title == "Light Ring" and lightOffer.cost == 10 and lightOffer.item == 12861
	and lightOffer.grant.itemId == 12861 and lightOffer.grant.canDropOnMap == false,
	"Light Ring must be a cheap, unlit inventory grant")
local lightCustomer = player("LightCustomer")
shop.handleClientOpcode(lightCustomer, {action = "init"})
local lightVisual = lightCustomer.replies[#lightCustomer.replies].data[lightCategory].offers[lightIndex]
check(lightVisual.item == 11898 and lightVisual.grant == nil, "Light Ring shop icon/private-grant contract failed")
buy(lightCustomer, lightCategory, lightIndex, true)
check(lightCustomer.lastAdd.id == 12861 and lightCustomer.lastAdd.count == 1 and lightCustomer.lastAdd.canDropOnMap == false
	and lightCustomer.storage[910500] == 990 and #shop.historyByGuid[lightCustomer.guid] == 1,
	"Light Ring purchase did not charge10 points after safe delivery")
local lightPoor = player("LightPoor"); lightPoor.storage[910500] = 9
buy(lightPoor, lightCategory, lightIndex)
check(lightPoor.lastAdd == nil and lightPoor.storage[910500] == 9, "Rejected cheap-ring purchase granted or charged")
local lightFull = player("LightFull"); lightFull.rejectDelivery = true
buy(lightFull, lightCategory, lightIndex)
check(lightFull.storage[910500] == 1000 and #lightFull.deliveries == 0 and shop.historyByGuid[lightFull.guid] == nil,
	"Failed Light Ring delivery charged points or recorded history")
local keyringCategory, keyringIndex, keyring = findOffer(1001)
local toolkitCategory, toolkitIndex, toolkitOffer = findOffer(4004)
check(toolkitOffer.title == "Toolkit" and toolkitOffer.cost == 50 and toolkitOffer.item == 12865
	and toolkitOffer.grant.itemId == 12865 and toolkitOffer.grant.canDropOnMap == false,
	"Toolkit must grant one reusable item without map overflow")
local toolCustomer = player("ToolkitCustomer")
shop.handleClientOpcode(toolCustomer, {action = "init"})
check(toolCustomer.replies[#toolCustomer.replies].data[toolkitCategory].offers[toolkitIndex].item == 11902,
	"Toolkit shop CID is wrong")
buy(toolCustomer, toolkitCategory, toolkitIndex, true)
check(toolCustomer.lastAdd.id == 12865 and toolCustomer.lastAdd.count == 1 and toolCustomer.storage[910500] == 950,
	"Toolkit grant/charge mismatch")
local toolPoor = player("ToolkitPoor"); toolPoor.storage[910500] = 49
buy(toolPoor, toolkitCategory, toolkitIndex)
check(toolPoor.lastAdd == nil and toolPoor.storage[910500] == 49, "Poor toolkit purchase mutated state")
local toolFull = player("ToolkitFull"); toolFull.rejectDelivery = true
buy(toolFull, toolkitCategory, toolkitIndex)
check(toolFull.storage[910500] == 1000 and #toolFull.deliveries == 0 and shop.historyByGuid[toolFull.guid] == nil,
	"Failed Toolkit delivery consumed points or history")
local boatCategory, boatIndex, boatOffer = findOffer(4005)
check(boatOffer.title == "Boat Pass (30 days)" and boatOffer.cost == 100 and boatOffer.item == 12866
	and boatOffer.grant.itemId == 12866 and boatOffer.grant.canDropOnMap == false, "Boat Pass offer/grant failed")
local boatCustomer = player("Boat customer")
shop.handleClientOpcode(boatCustomer, {action = "init"})
check(boatCustomer.replies[#boatCustomer.replies].data[boatCategory].offers[boatIndex].item == 11903,
	"Boat Pass catalog did not resolve the native CID")
buy(boatCustomer, boatCategory, boatIndex, true)
check(boatCustomer.lastAdd.id == 12866 and boatCustomer.lastAdd.count == 1 and boatCustomer.storage[910500] == 900,
	"Boat Pass purchase trusted client-supplied price or grant")
local boatPoor = player("Boat poor"); boatPoor.storage[910500] = 99
buy(boatPoor, boatCategory, boatIndex)
check(boatPoor.lastAdd == nil and boatPoor.storage[910500] == 99, "Poor Boat Pass purchase mutated state")
local boatFull = player("Boat full"); boatFull.rejectDelivery = true
buy(boatFull, boatCategory, boatIndex)
check(boatFull.storage[910500] == 1000 and #boatFull.deliveries == 0, "Failed Boat Pass delivery charged points")

local converterCategory, converterIndex, converterOffer = findOffer(4006)
check(converterOffer.title == "Magic Gold Converter" and converterOffer.cost == 100 and converterOffer.item == 12867
	and converterOffer.grant.itemId == 12867 and converterOffer.grant.canDropOnMap == false, "Converter offer/grant failed")
local converterCustomer = player("Converter customer")
shop.handleClientOpcode(converterCustomer, {action = "init"})
check(converterCustomer.replies[#converterCustomer.replies].data[converterCategory].offers[converterIndex].item == 11904,
	"Converter catalog did not resolve its native CID")
buy(converterCustomer, converterCategory, converterIndex, true)
check(converterCustomer.lastAdd.id == 12867 and converterCustomer.lastAdd.count == 1 and converterCustomer.storage[910500] == 900,
	"Converter purchase trusted client-supplied price or grant")
local converterPoor = player("Converter poor"); converterPoor.storage[910500] = 99
buy(converterPoor, converterCategory, converterIndex)
check(converterPoor.lastAdd == nil and converterPoor.storage[910500] == 99, "Poor converter purchase mutated state")
local converterFull = player("Converter full"); converterFull.rejectDelivery = true
buy(converterFull, converterCategory, converterIndex)
check(converterFull.storage[910500] == 1000 and #converterFull.deliveries == 0 and shop.historyByGuid[converterFull.guid] == nil,
	"Failed converter delivery charged points or wrote history")

local foodCategory, foodIndex, foodOffer = findOffer(4003)
check(foodOffer.title == "Food Ring" and foodOffer.cost == 10 and foodOffer.item == 12863
	and foodOffer.grant.itemId == 12863 and foodOffer.grant.canDropOnMap == false,
	"Food Ring must deliver a single inactive ring without map overflow")
local foodCustomer = player("FoodCustomer")
shop.handleClientOpcode(foodCustomer, {action = "init"})
check(foodCustomer.replies[#foodCustomer.replies].data[foodCategory].offers[foodIndex].item == 11900,
	"Food Ring shop CID is wrong")
buy(foodCustomer, foodCategory, foodIndex, true)
check(foodCustomer.lastAdd.id == 12863 and foodCustomer.lastAdd.count == 1 and foodCustomer.storage[910500] == 990,
	"Food Ring purchase must charge10 points and grant one ring")
local foodPoor = player("FoodPoor"); foodPoor.storage[910500] = 9
buy(foodPoor, foodCategory, foodIndex)
check(foodPoor.lastAdd == nil and foodPoor.storage[910500] == 9, "Poor Food Ring purchase granted or charged")
local foodFull = player("FoodFull"); foodFull.rejectDelivery = true
buy(foodFull, foodCategory, foodIndex)
check(foodFull.storage[910500] == 1000 and #foodFull.deliveries == 0 and shop.historyByGuid[foodFull.guid] == nil,
	"Failed Food Ring delivery consumed points or history")
check(keyring.title == "Keyring" and keyring.cost == 250, "Existing Keyring identity/price changed")
local mage = player("Mage")
buy(mage, keyringCategory, keyringIndex)
check(mage.learned["Keychain Consume"] and mage.learned["Keychain Unlock"] and mage.learned["Keychain List"]
	and mage.storage[910500] == 750 and #shop.historyByGuid[mage.guid] == 1,
	"Existing Keyring no longer grants its spells/price/history")
buy(mage, keyringCategory, keyringIndex)
check(mage.storage[910500] == 750 and #shop.historyByGuid[mage.guid] == 1,
	"Already-known spells were charged twice")

for _, groupId in ipairs({1, 2, 3, 4, 7}) do
	local actor = player("Denied" .. groupId, groupId, true)
	check(command(actor, "/quiver", "give") == false and #actor.deliveries == 0 and #actor.cancels == 1,
		"Non Admin/God character group granted a quiver: " .. groupId)
end
for _, groupId in ipairs({5, 6}) do
	local actor = player("Allowed" .. groupId, groupId)
	check(command(actor, "/quiver", "give") == false and #actor.deliveries == 1
		and actor.lastAdd.id == 12830 and actor.lastAdd.count == 1 and actor.lastAdd.canDropOnMap == false,
		"Admin/God character could not receive a safe single quiver: " .. groupId)
end
local noAccess = player("NoAccess", 5, false)
command(noAccess, "/quiver", "give")
check(#noAccess.deliveries == 0 and #noAccess.cancels == 1, "Admin group without access bypassed permission")
local god, target = player("God", 6), player("Target With Spaces")
command(god, "/quiver", "give Target With Spaces")
check(#target.deliveries == 1 and #target.messages == 1 and #god.deliveries == 0,
	"Named online target was not granted/notified separately")
command(god, "/quiver", "give Offline")
check(#god.cancels == 1 and #target.deliveries == 1, "Offline target caused a mutation")
target.rejectDelivery = true
command(god, "/quiver", "give Target With Spaces")
check(#target.deliveries == 1 and #god.cancels == 2 and target.lastAdd.canDropOnMap == false,
	"Failed admin grant dropped/duplicated or removed an existing item")
command(god, "/quiver", "status Target With Spaces")
check(god.messages[#god.messages]:find("no Magic Quiver equipped", 1, true), "Status ignored the equipped slot")

local contents = {
	{getId = function() return 2544 end, getCount = function() return 100 end},
	{getId = function() return 2543 end, getCount = function() return 35 end},
}
target.equipped = {
	getId = function() return 12830 end, isContainer = function() return true end,
	getSize = function() return #contents end, getCapacity = function() return 20 end,
	getItem = function(_, index) return contents[index + 1] end,
}
command(god, "/quiver", "status Target With Spaces")
check(god.messages[#god.messages]:find("2/20 slots, 135 ammunition", 1, true), "Equipped content status is incorrect")
check(#target.deliveries == 1 and target.storage[910500] == 1000, "Status mutated inventory/points")
command(god, "/quiver", "nonsense Target With Spaces")
check(#god.cancels == 3 and #target.deliveries == 1, "Unknown command mutated the target")
env.ItemType = function() return itemType(0) end
command(god, "/quiver", "give")
check(#god.cancels == 4 and #god.deliveries == 0, "Missing/misconfigured native item could be granted")
env.ItemType = itemType
command(god, "/quiver", "")
check(god.messages[#god.messages]:find("/quiver give", 1, true), "Empty command did not show help")

local xml = assert(io.open(serverRoot .. "/data/talkactions/talkactions.xml", "rb"))
local registration = xml:read("*a"); xml:close()
local _, count = registration:gsub('words="/quiver" separator=" " script="quiver.lua"', "")
check(count == 1, "Quiver command must be registered once")
env.GameShop = nil
env.dofile = function() error("fixture: shop config unavailable") end
loadActual("data/lib/core/game_shop.lua")
check(#env.GameShop.catalog == 0, "Missing config revived removed fallback offers")
print("QUIVER_SHOP_ADMIN_CONTRACT_OK checks=" .. checks .. " pureSource=true native=false")
