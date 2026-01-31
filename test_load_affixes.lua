-- Test script to load affixes module manually
print("========================================")
print("Testing affixes module loading...")
print("========================================")

-- Check if module exists
local module = g_modules.getModule('game_affixes')
if module then
    print("Module 'game_affixes' found!")
    print("Module info:")
    print("  Name: " .. module:getName())
    print("  Description: " .. module:getDescription())
    print("  Loaded: " .. tostring(module:isLoaded()))
else
    print("Module 'game_affixes' NOT FOUND!")
    print("Trying to discover modules...")
    g_modules.discoverModules()
    
    module = g_modules.getModule('game_affixes')
    if module then
        print("Module found after discovery!")
    else
        print("Still not found. Checking available modules:")
        local allModules = g_modules.getModules()
        for _, mod in ipairs(allModules) do
            if mod:getName():find("game") then
                print("  - " .. mod:getName())
            end
        end
    end
end

print("")
print("Attempting to load module...")
local success = g_modules.ensureModuleLoaded('game_affixes')
print("Load result: " .. tostring(success))

if not success then
    print("ERROR: Could not load module!")
    print("Trying to load script directly...")
    
    local ok, err = pcall(function()
        dofile('modules/game_affixes/affixes.lua')
        init()
    end)
    
    if ok then
        print("SUCCESS: Loaded script directly!")
    else
        print("ERROR loading script: " .. tostring(err))
    end
end
