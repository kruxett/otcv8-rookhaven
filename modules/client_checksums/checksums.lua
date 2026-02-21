-- Client Checksums Module
-- Handles file integrity verification with server

ClientChecksums = {}

-- Files to check on login
local CRITICAL_FILES = {
  "/modules/corelib/corelib.otmod",
  "/modules/corelib/util.lua",
  "/modules/corelib/globals.lua",
  "/modules/gamelib/gamelib.otmod",
  "/modules/gamelib/game.lua",
  "/modules/gamelib/protocolgame.lua",
  "/modules/game_protocol/protocol.lua",
  "/modules/game_features/features.lua",
}

-- Cache for file checksums (to avoid recalculating)
local checksumCache = {}

-- Generate checksum for a single file
local function getFileChecksum(filepath)
  if checksumCache[filepath] then
    return checksumCache[filepath]
  end
  
  if not g_resources.fileExists(filepath) then
    return "NOTFOUND"
  end
  
  local checksum = g_resources.fileChecksum(filepath)
  checksumCache[filepath] = checksum
  return checksum
end

-- Generate checksums for multiple files
local function generateChecksums(files)
  local checksums = {}
  for _, filepath in ipairs(files) do
    checksums[filepath] = getFileChecksum(filepath)
  end
  return checksums
end

-- Encode checksums as JSON string
local function encodeChecksums(checksums)
  local parts = {}
  for filepath, checksum in pairs(checksums) do
    table.insert(parts, string.format('"%s":"%s"', filepath, checksum))
  end
  return "{" .. table.concat(parts, ",") .. "}"
end

-- Generate login extended data with checksums
function ClientChecksums.getLoginExtendedData()
  -- RSA login packet is size-limited. Send a compact payload:
  -- Format: CS1:<chk1>,<chk2>,...,<binary>
  local parts = {}
  for _, filepath in ipairs(CRITICAL_FILES) do
    table.insert(parts, getFileChecksum(filepath))
  end
	
  local binaryChecksum = g_resources.selfChecksum()
  if binaryChecksum and #binaryChecksum > 0 then
    table.insert(parts, binaryChecksum)
  end
	
  local data = "CS1:" .. table.concat(parts, ",")
	
  if g_settings.getBoolean("enableChecksumDebug", false) then
    print("[ClientChecksums] Login data: " .. data)
  end
	
  return data
end

-- Handle periodic checksum challenge from server
function ClientChecksums.onChecksumChallenge(protocol, opcode, buffer)
  -- Parse challenge: format is "challengeId:file1,file2,file3"
  local separator = buffer:find(":")
  if not separator then
    print("[ClientChecksums] Invalid challenge format")
    return
  end
  
  local challengeId = buffer:sub(1, separator - 1)
  local filesString = buffer:sub(separator + 1)
  
  -- Split file list
  local files = {}
  for filepath in filesString:gmatch("[^,]+") do
    table.insert(files, filepath)
  end
  
  -- Generate checksums
  local checksums = generateChecksums(files)
  checksums["_challengeId"] = challengeId
  checksums["_timestamp"] = os.time()
  
  -- Send response
  local response = encodeChecksums(checksums)
  if protocol.sendExtendedOpcode then
    protocol:sendExtendedOpcode(2, response)
  end
  
  -- Debug log
  if g_settings.getBoolean("enableChecksumDebug", false) then
    print("[ClientChecksums] Challenge " .. challengeId .. " response sent for " .. #files .. " files")
  end
end

-- Initialize module
function ClientChecksums.init()
  -- Override ProtocolGame's getLoginExtendedData
  ProtocolGame.getLoginExtendedData = ClientChecksums.getLoginExtendedData
  
  -- Register handler for periodic challenges (opcode 2)
  ProtocolGame.registerExtendedOpcode(2, ClientChecksums.onChecksumChallenge)
  
  print("[ClientChecksums] Integrity verification system initialized")
end

function ClientChecksums.terminate()
  -- Restore original behavior
  ProtocolGame.getLoginExtendedData = nil
end

-- Auto-initialize
connect(g_app, { onRun = ClientChecksums.init })
