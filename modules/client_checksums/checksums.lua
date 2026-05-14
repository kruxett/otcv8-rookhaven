-- Client Checksums Module
-- Handles file integrity verification with server

ClientChecksums = {}

local function logChecksum(msg)
  if ClientLog and ClientLog.isEnabled and ClientLog.isEnabled("checksums") then
    print(msg)
  end
end

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
  
  local resolvedPath = filepath
  if not g_resources.fileExists(filepath) then
    -- In release builds, .lua files are compiled to .luac bytecode
    -- Try to find the .luac variant if the .lua file doesn't exist
    local luacPath = filepath:gsub("%.lua$", ".luac")
    if luacPath ~= filepath and g_resources.fileExists(luacPath) then
      resolvedPath = luacPath
    else
      checksumCache[filepath] = "NOTFOUND"
      return "NOTFOUND"
    end
  end
  
  local checksum = g_resources.fileChecksum(resolvedPath)
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
  -- RSA login packet is size-limited. Send a compact fixed-size hash:
  -- Format: CS1:<hash>
  local function hashString(s)
    local h = 0
    for i = 1, #s do
      h = (h * 33 + s:byte(i)) % 4294967296
    end
    return string.format("%08x", h)
  end

  local combined = ""
  for _, filepath in ipairs(CRITICAL_FILES) do
    combined = combined .. getFileChecksum(filepath) .. "|"
  end

  local binaryChecksum = g_resources.selfChecksum()
  if binaryChecksum and #binaryChecksum > 0 then
    combined = combined .. binaryChecksum
  end

  local data = "CS1:" .. hashString(combined)

  if g_settings.getBoolean("enableChecksumDebug", false) then
    logChecksum("[ClientChecksums] Login data: " .. data)
  end

  return data
end

-- Handle periodic checksum challenge from server
function ClientChecksums.onChecksumChallenge(protocol, opcode, buffer)
  -- Parse challenge: format is "challengeId:file1,file2,file3"
  local separator = buffer:find(":")
  if not separator then
    logChecksum("[ClientChecksums] Invalid challenge format")
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
    logChecksum("[ClientChecksums] Challenge " .. challengeId .. " response sent for " .. #files .. " files")
  end
end

-- Initialize module
function ClientChecksums.init()
  -- Override ProtocolGame's getLoginExtendedData
  ProtocolGame.getLoginExtendedData = ClientChecksums.getLoginExtendedData
  
  -- Register handler for periodic challenges (opcode 2)
  ProtocolGame.registerExtendedOpcode(2, ClientChecksums.onChecksumChallenge)
  
  logChecksum("[ClientChecksums] Integrity verification system initialized")
end

function ClientChecksums.terminate()
  -- Restore original behavior
  ProtocolGame.getLoginExtendedData = nil
end

-- Auto-initialize
connect(g_app, { onRun = ClientChecksums.init })
