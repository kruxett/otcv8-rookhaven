-- Automatic checksum generator for server
-- Run this after building client to update server's checksum_expected.txt
-- Usage: Launch client, Ctrl+T, then: dofile('tools/update_server_checksums.lua')

print("=== Checksum Generator ===")
print("Generating checksums for server validation...")
print("")

local criticalFiles = {
    "/modules/corelib/corelib.otmod",
    "/modules/corelib/util.lua",
    "/modules/corelib/globals.lua",
    "/modules/corelib/string.lua",
    "/modules/corelib/table.lua",
    "/modules/corelib/math.lua",
    "/modules/corelib/const.lua",
    "/modules/gamelib/gamelib.otmod",
    "/modules/gamelib/game.lua",
    "/modules/gamelib/protocolgame.lua",
    "/modules/gamelib/protocollogin.lua",
    "/modules/game_protocol/protocol.lua",
    "/modules/game_features/features.lua",
    "/modules/game_bot/bot.lua",
    "/modules/game_walking/walking.lua",
    "/modules/game_hotkeys/hotkeys_manager.lua",
    "/modules/game_things/things.lua"
}

local output = {}
table.insert(output, "# Client file checksums for verification")
table.insert(output, "# Format: /path/to/file=checksum")
table.insert(output, "# Auto-generated: " .. os.date("%Y-%m-%d %H:%M:%S"))
table.insert(output, "")

for _, filepath in ipairs(criticalFiles) do
    local checksum = g_resources.fileChecksum(filepath)
    if checksum and checksum ~= "" then
        table.insert(output, filepath .. "=" .. checksum)
        print(filepath .. " = " .. checksum)
    else
        print("WARNING: Could not get checksum for " .. filepath)
    end
end

local fullOutput = table.concat(output, "\n")

print("")
print("=== Copy this to Rookhaven/data/checksum_expected.txt ===")
print("")
print(fullOutput)
print("")
print("=== End ===")

-- Try to write to file if write directory is accessible
local writeDir = g_resources.getWriteDir()
if writeDir and writeDir ~= "" then
    local outputFile = "/checksum_expected.txt"
    g_resources.writeFileContents(outputFile, fullOutput)
    print("")
    print("Also saved to: " .. (writeDir .. outputFile))
    print("Copy this file to your server's data/ folder")
end
