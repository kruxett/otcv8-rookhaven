-- Pure-source transport contract. No game client, UI, network or profile access.
-- Extract the current product function rather than maintain a second decoder.
local sourcePath = assert(arg[1], 'Expected current game_cyclopedia.lua path')
local file = assert(io.open(sourcePath, 'rb'))
local source = file:read('*a')
file:close()
local chunk = assert(source:match('(local characterChunkProtocol, characterChunkTransfer.-)local function getPendingRequestKey'),
    'Current Cyclopedia transport extraction anchors changed')

local firstProtocol, secondProtocol = {}, {}
local currentProtocol, now, eventSequence = firstProtocol, 0, 0
local events = {}
local environment = {
    g_game = { getProtocolGame = function() return currentProtocol end },
    g_clock = { millis = function() return now end },
    scheduleEvent = function(callback)
        eventSequence = eventSequence + 1
        events[eventSequence] = callback
        return eventSequence
    end,
    removeEvent = function(id) events[id] = nil end
}
setmetatable(environment, { __index = _G })
local loadTransport = assert(loadstring(chunk .. '\nreturn receiveCharacterChunk, clearCharacterChunks', '@current-cyclopedia-transport'))
setfenv(loadTransport, environment)
local receive, clear = loadTransport()
local responsePrefix = 'cp|1|res|character.passives|ok|'
local payload = responsePrefix .. string.rep('x', 19000)
local function packet(id, index, total, segment)
    return 'cp|1|chunk|' .. id .. '|' .. index .. '|' .. total .. '|' .. segment
end
local function begin(id, total)
    assert(receive(currentProtocol, packet(id, 1, total, payload:sub(1, 7900))) == nil,
        'First partial frame was exposed')
end
local checks = 0
local function check(condition, description)
    assert(condition, description)
    checks = checks + 1
end

begin('1', 3)
check(receive(firstProtocol, packet('1', 2, 3, payload:sub(7901, 15800))) == nil, 'Partial response leaked')
check(receive(firstProtocol, packet('1', 3, 3, payload:sub(15801))) == payload, 'Full response changed')
local raw = 'cp|1|res|character.baseInfo|ok|Reaver'
check(receive(firstProtocol, raw) == raw, 'Ordinary response changed')

begin('2', 3)
check(receive(firstProtocol, packet('3', 2, 3, 'x')) == nil, 'Wrong transfer ID accepted')
check(receive(firstProtocol, packet('2', 2, 3, 'x')) == nil, 'Wrong ID failed to reset transfer')
begin('4', 3)
check(receive(firstProtocol, packet('4', 3, 3, 'x')) == nil, 'Out-of-order frame accepted')
check(receive(firstProtocol, packet('4', 2, 3, 'x')) == nil, 'Wrong order failed to reset transfer')
check(receive(firstProtocol, packet('5', 1, 9, 'x')) == nil, 'Too many frames accepted')
check(receive(firstProtocol, packet('6', 1, 1, string.rep('x', 7901))) == nil, 'Oversized segment accepted')

begin('7', 5)
for index = 2, 4 do
    check(receive(firstProtocol, packet('7', index, 5, string.rep('x', 7900))) == nil, 'Large partial response leaked')
end
check(receive(firstProtocol, packet('7', 5, 5, string.rep('x', 7900))) == nil, 'Response above 32768 bytes accepted')
begin('8', 2)
now = 10000
check(receive(firstProtocol, packet('8', 2, 2, 'x')) == nil, 'Deadline accepted a late frame')

now = 20000
begin('9', 2)
currentProtocol = secondProtocol
check(receive(secondProtocol, packet('9', 2, 2, 'x')) == nil, 'New connection inherited pending frames')
check(receive(firstProtocol, packet('9', 1, 1, responsePrefix .. 'old')) == nil, 'Old connection accepted')
begin('10', 2)
clear()
check(receive(secondProtocol, packet('10', 2, 2, 'x')) == nil, 'Session reset retained pending frames')
check(receive(secondProtocol, packet('11', 1, 1, 'cp|1|res|houses.list|ok|{}')) == nil, 'Chunked foreign action accepted')
check(receive(secondProtocol, 'cp|2|chunk|12|1|1|' .. responsePrefix) == nil, 'Wrong protocol version accepted')
check(receive(secondProtocol, packet('2147483648', 1, 1, responsePrefix)) == nil, 'Transfer ID outside native range accepted')

assert(checks == 20, 'Contract case count changed')
assert(next(events) == nil, 'Completed or rejected transfer retained a timeout event')
print('CYCLOPEDIA_TRANSPORT_CONTRACT_OK checks=20 pureSource=true native=false')
