# ?? DEBUGGING UNLOOTED CORPSES - Step by Step

## ?? FULL DEBUG MODE ACTIVATED

The client now has **extensive logging** to diagnose exactly where the issue is.

---

## ?? TEST PROCEDURE

### Step 1: Launch Client and Connect

**Start the game and watch the console carefully.**

### Step 2: Check if Module is Loaded

Look for this message when client starts:
```
[UnlootedCorpse] Module initialized
```

**If you DON'T see it:** The module is not loading. Check `modules/gamelib/gamelib.otmod` to ensure `unlooted_corpses` is listed.

---

### Step 3: Kill a Monster

**Watch the console. You should see messages in this exact sequence:**

#### Expected Console Output:

```
[UnlootedCorpse] Extended opcode received: opcode=1, buffer=mark:1234,5678,7
[UnlootedCorpse] Subopcode 1 detected! Enabled=true
[UnlootedCorpse] Parsing message: 'mark:1234,5678,7'
[UnlootedCorpse] Parsed: cmd='mark' coords='1234,5678,7'
[UnlootedCorpse] Coordinates parsed: x=1234 y=5678 z=7
[UnlootedCorpse] Position object: x=1234 y=5678 z=7
[UnlootedCorpse] Calling g_game.markUnlootedCorpse...
[C++ markUnlootedCorpse] Added position Position(1234,5678,7) to map. Total tracked: 1
[UnlootedCorpse] ? MARKED corpse at 1234,5678,7
[C++ isCorpseUnlooted] Check position Position(1234,5678,7): TRUE (Total tracked: 1)
[CORPSE DRAW] Applying glow to corpse ID=XXXX at Position(1234,5678,7)
```

---

## ?? DIAGNOSIS SCENARIOS

### Scenario A: NO MESSAGES AT ALL

**Problem:** Server not sending opcodes OR client not receiving them

**Check:**
1. Is the server running the updated code?
2. Check server console when you kill monster - should see debug output there
3. Try manual test: `/lua g_game.markUnlootedCorpse({x=100,y=100,z=7})`
   - If this works ? Server issue
   - If this doesn't work ? Client issue

---

### Scenario B: Messages Stop at "Extended opcode received"

```
[UnlootedCorpse] Extended opcode received: opcode=1, buffer=mark:1234,5678,7
```
**But nothing after...**

**Problem:** `onExtendedOpcode` handler not calling `handleUnlootedCorpseMessage`

**Check:**
1. Is `UnlootedCorpseConfig` loaded? Type: `/lua print(UnlootedCorpseConfig)`
2. Is system enabled? Type: `/lua print(UnlootedCorpseConfig.enabled)`
3. If it says `nil` ? Config module not loading

---

### Scenario C: Messages Stop at "Parsing message"

```
[UnlootedCorpse] Parsing message: 'mark:1234,5678,7'
[UnlootedCorpse] ERROR: Failed to parse message!
```

**Problem:** Message format from server is wrong

**Check:** What does `buffer` contain? Copy the exact text and test:
```lua
/lua local buffer = "mark:1234,5678,7"; local cmd, coords = buffer:match("(%w+):(.+)"); print(cmd, coords)
```

---

### Scenario D: Messages Show "Calling g_game.markUnlootedCorpse..." But No C++ Message

```
[UnlootedCorpse] Calling g_game.markUnlootedCorpse...
[UnlootedCorpse] ? MARKED corpse at 1234,5678,7
```
**But NO `[C++ markUnlootedCorpse]` message**

**Problem:** C++ function not being called or logging broken

**Manual Test:**
```lua
/lua g_game.markUnlootedCorpse({x=100,y=100,z=7})
```

Should see:
```
[C++ markUnlootedCorpse] Added position Position(100,100,7) to map. Total tracked: 1
```

If you DON'T see it ? Rebuild client, C++ function might not be exported to Lua correctly.

---

### Scenario E: C++ Shows "Added position" But No "Check position" or "Applying glow"

```
[C++ markUnlootedCorpse] Added position Position(1234,5678,7) to map. Total tracked: 1
```
**But NO `[C++ isCorpseUnlooted]` or `[CORPSE DRAW]` messages**

**Problem:** `Item::draw()` is not checking for corpses or corpse is not at that position

**Check:**
1. Walk to the corpse location
2. The corpse must be a "lying corpse" (flat on ground, not standing container)
3. Position must match EXACTLY

**Manual Test:** Stand on the corpse and type:
```lua
/lua local pos = g_game.getLocalPlayer():getPosition(); print(pos.x, pos.y, pos.z); print(g_game.isCorpseUnlooted(pos))
```

---

### Scenario F: Shows "Check position: FALSE" When It Should Be TRUE

```
[C++ markUnlootedCorpse] Added position Position(1234,5678,7) to map. Total tracked: 1
[C++ isCorpseUnlooted] Check position Position(1234,5678,7): FALSE (Total tracked: 1)
```

**Problem:** Position comparison failing (hash collision or position mismatch)

**This is the likely issue!** The position being marked is different from the position being checked.

**Debug:** Compare the exact positions:
```lua
/lua local corpse = g_game.getLocalPlayer():getTile():getTopUseThing()
/lua if corpse then print("Corpse at:", corpse:getPosition().x, corpse:getPosition().y, corpse:getPosition().z) end
```

---

## ?? QUICK MANUAL TEST

**Type these commands in order:**

```lua
/lua print("=== MANUAL TEST START ===")
/lua local pos = {x=100, y=100, z=7}
/lua print("1. Marking position...")
/lua g_game.markUnlootedCorpse(pos)
/lua print("2. Checking if marked...")
/lua print("Result:", g_game.isCorpseUnlooted(pos))
/lua print("3. Clearing position...")
/lua g_game.clearUnlootedCorpse(pos)
/lua print("4. Checking after clear...")
/lua print("Result:", g_game.isCorpseUnlooted(pos))
/lua print("=== MANUAL TEST END ===")
```

**Expected output:**
```
=== MANUAL TEST START ===
1. Marking position...
[C++ markUnlootedCorpse] Added position Position(100,100,7) to map. Total tracked: 1
2. Checking if marked...
[C++ isCorpseUnlooted] Check position Position(100,100,7): TRUE (Total tracked: 1)
Result: true
3. Clearing position...
[C++ clearUnlootedCorpse] Removed position Position(100,100,7) from map. Total tracked: 0
4. Checking after clear...
[C++ isCorpseUnlooted] Check position Position(100,100,7): FALSE (Total tracked: 0)
Result: false
=== MANUAL TEST END ===
```

**If this works but corpses don't glow:** The issue is in `Item::draw()` not being called or corpse detection.

---

## ?? WHAT TO LOOK FOR

After killing a monster, count how many lines of output you see:

- **0 lines** = Server not sending OR extended opcode not registered
- **1-2 lines** = Message received but parsing failed
- **3-5 lines** = Parsing OK but C++ function not called
- **6-7 lines** = C++ function called but corpse not being checked
- **8+ lines** = Everything working, glow should appear

---

## ?? MOST LIKELY ISSUES

### Issue #1: Config Module Not Loading
```lua
/lua print(UnlootedCorpseConfig)
```
If it says `nil`, the config file isn't being loaded.

**Fix:** Check if `modules/gamelib/unlooted_corpses.lua` has this line:
```lua
dofile('unlooted_corpses_config')
```

### Issue #2: System Disabled
```lua
/lua print(UnlootedCorpseConfig.enabled)
```
If it says `false`, enable it:
```lua
/lua unlootedCorpseToggle()
```

### Issue #3: Extended Opcode Not Registered
The module needs to connect to the protocol. Check `init()` function has:
```lua
connect(ProtocolGame, { onExtendedOpcode = onExtendedOpcode })
```

### Issue #4: Wrong Position
Server sends position X,Y,Z but corpse is actually at different coordinates.

**Check:** Stand exactly on the corpse and compare positions.

---

## ? NEXT STEPS

1. Kill a monster
2. Copy ALL console output
3. Paste it here or analyze using the scenarios above
4. Identify which scenario matches your output
5. Follow the specific fix for that scenario

---

**After you've tested, report back with the EXACT console output and we'll fix it!**
