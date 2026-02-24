# Lua Bytecode Compilation Guide for OTClient V8

## Overview
This process converts all Lua source files to bytecode (.luac) to prevent casual tampering with client files. Bytecode is binary and not human-readable, making it much harder to modify.

## Prerequisites
- Lua compiler (lua 5.1+ or separate luac binary)
- PowerShell 5.0+ or ability to run PowerShell scripts on Windows

## Installation Steps

### Step 1: Install Lua Compiler
**Option A: Add to PATH (Recommended)**
1. Download Lua from: https://www.lua.org/download.html
2. Extract to a folder (e.g., `C:\Lua`)
3. Add `C:\Lua` to your Windows PATH environment variable
4. Test: Open PowerShell and type `lua -v`

**Option B: Use provided path**
- Run the script with `-LuaCompilerPath` parameter pointing to lua.exe

### Step 2: Run Compilation Script
```powershell
# Navigate to otcv8-rookhaven directory
cd c:\RookhavenServerandClientCode\otcv8-rookhaven

# Run the compilation script
.\compile_lua_to_bytecode.ps1

# Or specify custom Lua path
.\compile_lua_to_bytecode.ps1 -LuaCompilerPath "C:\Path\To\lua.exe"
```

### Step 3: Replace Source with Bytecode
```powershell
# Navigate to otcv8-rookhaven
cd c:\RookhavenServerandClientCode\otcv8-rookhaven

# Remove all .lua files, keep only .luac
Get-ChildItem -Path "./modules", "./data" -Recurse -Filter "*.lua" | Remove-Item -Force
Get-ChildItem -Path "./data/styles", "./data/locales" -Recurse -Filter "*.lua" | Remove-Item -Force
```

### Step 4: Update data.zip
1. Create/update `data.zip` with:
   - All `.luac` bytecode files (NOT .lua)
   - All other assets (images, fonts, etc.)
   - Directory structure must match original

**Tools:**
- 7-Zip, WinRAR, or built-in Windows compression
- Or use PowerShell:
  ```powershell
  Compress-Archive -Path ./data, ./modules -DestinationPath data.zip -Force
  ```

### Step 5: Rebuild Client
1. Open Visual Studio or your build environment
2. Rebuild the client project
3. Ensure OTClient correctly loads `.luac` files from data.zip

### Step 6: Verify on Test Server
1. Launch the new client
2. Try to login
3. **Check server logs for checksum:**
   - If hash provided: `[Checksum] Hash mismatch. Client=XXXXX Server=YYYYY`
   - Copy the `Client=` value

### Step 7: Create checksum_expected.txt
Create file: `Rookhaven/data/checksum_expected.txt`

Content:
```
expectedHash=XXXXX
```

Replace `XXXXX` with the hash from Step 6.

### Step 8: Test Tampering Detection
1. Modify a `.luac` file (break it intentionally)
2. Rezip data.zip with modified bytecode
3. Rebuild and try to login
4. Should see: `[Checksum] Hash mismatch. Client=YYYYY Server=XXXXX`
5. Login should be rejected ✓

### Step 9: Deploy to Production
1. Upload new client to players
2. Update `checksum_expected.txt` on server
3. Restart server with `enforceClientChecksums = true`
4. Test with players

## Troubleshooting

**Error: "Lua compiler not found"**
- Install Lua and add to PATH
- Or use `-LuaCompilerPath` parameter with full path to lua.exe

**Client won't load .luac files**
- Check that OTClient supports Lua 5.1 bytecode
- Verify .luac files were created successfully
- Check that all dependencies are in data.zip

**Hash mismatch on login**
- Ensure ALL Lua files are compiled to bytecode
- No stray .lua files should exist
- Verify data.zip format is correct
- Clear any client cache

## Files Modified
- `otcv8-rookhaven/compile_lua_to_bytecode.ps1` - Compilation script
- `modules/**/*.lua` → `modules/**/*.luac`
- `data/**/*.lua` → `data/**/*.luac`
- `data.zip` - Rebuilds with bytecode only

## Security Notes
- This makes tampering harder but not impossible
- Determined cheaters could still decompile bytecode
- Combined with server-side validation, this is effective for most players
- Consider adding server-side logging of suspicious activity

## Reverting
If you need to revert:
1. Restore original .lua files from git
2. Recreate data.zip with .lua files
3. Rebuild client
4. Regenerate checksum_expected.txt

## Questions?
Refer to the compilation script's NEXT STEPS output for quick reference.
