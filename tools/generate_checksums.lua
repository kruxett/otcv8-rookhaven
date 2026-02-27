-- Tool to generate checksums for client files
-- Run this from the OTCv8 client console with: dofile('tools/generate_checksums.lua')
-- Output will be written to checksums_output.txt

local files_to_check = {
  -- Core libraries
  "/modules/corelib/corelib.otmod",
  "/modules/corelib/util.lua",
  "/modules/corelib/globals.lua",
  "/modules/corelib/string.lua",
  "/modules/corelib/table.lua",
  "/modules/corelib/math.lua",
  "/modules/corelib/const.lua",
  
  -- Game library
  "/modules/gamelib/gamelib.otmod",
  "/modules/gamelib/game.lua",
  "/modules/gamelib/protocolgame.lua",
  "/modules/gamelib/protocollogin.lua",
  
  -- Game protocol
  "/modules/game_protocol/protocol.lua",
  "/modules/game_protocol/opcodes.lua",
  
  -- Game features (disable exploits)
  "/modules/game_features/features.lua",
  
  -- Critical game modules
  "/modules/game_interface/interface.lua",
  "/modules/game_bot/bot.lua",
  "/modules/game_walking/walking.lua",
  "/modules/game_hotkeys/hotkeys_manager.lua",
  
  -- Things loader
  "/modules/game_things/things.lua",
}

local function generateChecksums()
  local output = {}
  local simple = {}
  table.insert(output, "// Generated checksums - " .. os.date())
  table.insert(output, "// Copy these into server's data/checksum_config.json under 'expected_checksums'")
  table.insert(output, "")
  table.insert(simple, "# Generated checksums - " .. os.date())
  
  for _, filepath in ipairs(files_to_check) do
    if g_resources.fileExists(filepath) then
      local checksum = g_resources.fileChecksum(filepath)
      table.insert(output, string.format('  "%s": "%s",', filepath, checksum))
      table.insert(simple, string.format('%s=%s', filepath, checksum))
      print(string.format("[Checksum] %s: %s", filepath, checksum))
    else
      table.insert(output, string.format('  // "%s": "FILE_NOT_FOUND",', filepath))
      table.insert(simple, string.format('# %s=FILE_NOT_FOUND', filepath))
      print(string.format("[Warning] File not found: %s", filepath))
    end
  end
  
  -- Also get binary checksum
  local binaryChecksum = g_resources.selfChecksum()
  if binaryChecksum and #binaryChecksum > 0 then
    table.insert(output, string.format('  "_binary": "%s"', binaryChecksum))
    table.insert(simple, string.format('_binary=%s', binaryChecksum))
    print(string.format("[Checksum] Binary: %s", binaryChecksum))
  end
  
  local outputText = table.concat(output, "\n")
  local simpleText = table.concat(simple, "\n")
  
  -- Write to file
  if g_resources.writeFileContents then
    local writeDir = g_resources.getWriteDir()
    print("[Info] Write directory: " .. writeDir)
    
    g_resources.writeFileContents("/checksums_output.txt", outputText)
    g_resources.writeFileContents("/checksums_expected.txt", simpleText)
    
    print("[Success] Checksums written to:")
    print("  " .. writeDir .. "checksums_output.txt")
    print("[Success] Copy this file to your server:")
    print("  " .. writeDir .. "checksums_expected.txt")
  end
  
  return outputText
end

print("=== Client Checksum Generator ===")
print("Generating checksums for verification system...")
local result = generateChecksums()
print("Done!")
