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
		getClientId = function() return id == 12830 and 11867 or id + 100 end,
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

check(#config.catalog == 4 and config.catalog[4].name == "Utility", "Utility must append to existing categories")
local offer = shop.catalog[4].offers[1]
check(offer.id == 4001 and offer.cost == 150 and offer.item == 12830, "Magic Quiver offer identity/price changed")
check(offer.grant.itemId == 12830 and offer.grant.count == 1 and offer.grant.canDropOnMap == false,
	"Quiver must be delivered as one empty item without map overflow")
local shopper = player("Shopper")
shop.handleClientOpcode(shopper, {action = "init"})
local payload = shopper.replies[#shopper.replies]
check(payload.data[4].item == 11867 and payload.data[4].offers[1].item == 11867,
	"Shop visuals must use client IDs resolved from the server SID")
check(payload.data[4].offers[1].grant == nil and payload.status.points == 1000, "Private grants leaked into shop payload")
buy(shopper, 4, 1, true)
check(#shopper.deliveries == 1 and shopper.lastAdd.canDropOnMap == false, "Quiver purchase allowed a ground drop")
check(shopper.storage[910500] == 850 and #shop.historyByGuid[shopper.guid] == 1,
	"Purchase did not deduct the server price exactly once after delivery")
check(lastMessage(shopper):find("1x magic quiver", 1, true), "Purchase did not identify the delivered quiver")
shop.handleClientOpcode(shopper, {action = "history"})
check(shopper.replies[#shopper.replies].data[1].item == 11867, "History displayed the server SID instead of the CID")

local poor = player("Poor"); poor.storage[910500] = 149
buy(poor, 4, 1)
check(#poor.deliveries == 0 and poor.storage[910500] == 149 and shop.historyByGuid[poor.guid] == nil,
	"Insufficient points granted an item or changed points/history")
local full = player("Full"); full.rejectDelivery = true
buy(full, 4, 1)
check(full.lastAdd.canDropOnMap == false and #full.deliveries == 0 and full.storage[910500] == 1000
	and shop.historyByGuid[full.guid] == nil, "Failed inventory delivery consumed points or recorded a purchase")
check(lastMessage(full):find("capacity", 1, true), "Inventory failure did not explain capacity/space")
local invalid = player("Invalid")
buy(invalid, 99, 1)
check(invalid.lastAdd == nil and invalid.storage[910500] == 1000, "Invalid category changed inventory/balance")
local originalCount = offer.grant.count
offer.grant.count = 2
buy(invalid, 4, 1)
check(invalid.lastAdd == nil and invalid.storage[910500] == 1000,
	"No-drop multi-item grants could partially deliver before failure")
offer.grant.count = originalCount

local consumable = player("Consumable")
buy(consumable, 2, 1)
check(consumable.lastAdd.id == 7618 and consumable.lastAdd.count == 50 and consumable.lastAdd.canDropOnMap == true
	and consumable.storage[910500] == 920, "Existing consumable grant behavior changed")
local mage = player("Mage")
buy(mage, 1, 2)
check(mage.learned.Light == true and mage.storage[910500] == 880 and #shop.historyByGuid[mage.guid] == 1,
	"Existing spell offer no longer grants its spell/price/history")
buy(mage, 1, 2)
check(mage.storage[910500] == 880 and #shop.historyByGuid[mage.guid] == 1,
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
print("QUIVER_SHOP_ADMIN_CONTRACT_OK checks=" .. checks .. " pureSource=true native=false")
