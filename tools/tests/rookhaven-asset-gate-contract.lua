-- Actual catalog fixture is independently exported from the source DAT.
local source, fixture = assert(arg[1]), assert(arg[2])
local catalog = assert(loadfile(fixture))()
local count = catalog.maximum + 1
local overrides, reads, assertions = {}, 0, 0
UPDATER_CHANNEL, LOCAL_PASSIVES_TEST, ThingCategoryItem = 'dev', false, 0
tr = function(text) return text end
g_things = {
  getThingTypes = function() return setmetatable({}, {__len = function() return count end}) end,
  getThingType = function(id)
    reads = reads + 1
    local original = assert(catalog.items[id], 'Fixture lacks real DAT item ' .. id)
    local row = {}
    for key, value in pairs(original) do row[key] = value end
    for key, value in pairs(overrides[id] or {}) do row[key] = value end
    return {
      getId = function() return row.id end,
      isPickupable = function() return row.pickupable end,
      isContainer = function() return row.container end,
      isStackable = function() return row.stackable end,
      getWidth = function() return row.width end,
      getHeight = function() return row.height end,
      getAnimationPhases = function() return row.phases end,
    }
  end,
}
-- LuaJIT uses Lua 5.1's raw table length, so fill only the item-count vector.
g_things.getThingTypes = function()
  local rows = {}
  for index = 1, count do rows[index] = true end
  return rows
end
assert(loadfile(source))()
local function check(expected, label, version)
  local valid, message = validateRookhavenAssets(version or 860)
  assert(valid == expected, label)
  if not expected then assert(type(message) == 'string' and message:find('restart'), label .. ' has no useful error') end
  assertions = assertions + 1
end

check(true, 'current actual DAT rejected')
count = 11868
check(false, 'earlier quiver-only DAT accepted')
count = catalog.maximum + 1
overrides[11867] = {container = false}
check(false, 'quiver regression accepted')
overrides = {}
for _, id in ipairs({11868, 11877, 11882, 11886}) do
  overrides[id] = {id = 0}
  check(false, 'missing catalog ID ' .. id .. ' accepted')
  overrides = {}
end
overrides[11868] = {stackable = true}
check(false, 'stackable weapon accepted')
overrides = {[11878] = {stackable = false}}
check(false, 'non-stackable material accepted')
overrides = {[11883] = {pickupable = false}}
check(false, 'non-pickupable recipe page accepted')
overrides = {[11881] = {container = true}}
check(false, 'material mapped to container accepted')
overrides = {[11876] = {phases = 1}}
check(false, 'stale wand layout accepted')
overrides = {[11877] = {width = 2}}
check(false, 'wrong rod footprint accepted')
overrides, count = {}, 11868
UPDATER_CHANNEL = 'prod'
local before = reads
check(true, 'PROD catalog contract changed')
assert(reads == before, 'PROD unexpectedly inspected DEV item IDs')
LOCAL_PASSIVES_TEST = true
check(false, 'loopback catalog omitted DEV guard')
LOCAL_PASSIVES_TEST, UPDATER_CHANNEL = false, 'dev'
before = reads
check(true, 'other protocol version changed', 861)
assert(reads == before, 'other protocol version unexpectedly inspected DEV item IDs')
print('Rookhaven asset compatibility: ' .. assertions .. ' assertions passed')
