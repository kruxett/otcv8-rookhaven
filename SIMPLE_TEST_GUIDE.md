# ?? SIMPLE TEST PROCEDURE

## ?? IMPORTANT: Correct Console Usage

### Opening Console
- Press **CTRL+T** to open Lua console
- Console opens at bottom of screen

### Running Commands

**IN THE LUA CONSOLE (after CTRL+T):**
Type commands **WITHOUT** `/lua`:
```lua
print("Hello")
```

**IN GAME CHAT (normal chat window):**
Type commands **WITH** `/lua`:
```
/lua print("Hello")
```

---

## ?? STEP 1: Check Module Loaded

**Open console (CTRL+T) and type:**

```lua
print("Config exists:", UnlootedCorpseConfig ~= nil)
```

**Expected:** `Config exists: true`

**If you see `nil`:** Config not loading, there's an issue with the module.

---

## ?? STEP 2: Check Initialization

**Look for this message in console when client starts:**
```
[UnlootedCorpse] Script loaded, calling init()...
[UnlootedCorpse] Module initialized
```

**If you DON'T see these messages:** Module is not being loaded at all.

---

## ?? STEP 3: Manual Test (Without Server)

**In console (CTRL+T), type each line:**

```lua
print("=== MANUAL TEST ===")
g_game.markUnlootedCorpse({x=100, y=100, z=7})
print("Position marked, checking...")
print(g_game.isCorpseUnlooted({x=100, y=100, z=7}))
g_game.clearUnlootedCorpse({x=100, y=100, z=7})
print("Position cleared, checking...")
print(g_game.isCorpseUnlooted({x=100, y=100, z=7}))
```

**Expected output:**
```
=== MANUAL TEST ===
[C++ markUnlootedCorpse] Added position Position(100,100,7) to map. Total tracked: 1
Position marked, checking...
[C++ isCorpseUnlooted] Check position Position(100,100,7): TRUE (Total tracked: 1)
true
[C++ clearUnlootedCorpse] Removed position Position(100,100,7) from map. Total tracked: 0
Position cleared, checking...
[C++ isCorpseUnlooted] Check position Position(100,100,7): FALSE (Total tracked: 0)
false
```

**If this works:** C++ functions are OK, problem is with receiving server messages.

---

## ?? STEP 4: Test with Monster

1. **Open console (CTRL+T)**
2. **Keep console OPEN**
3. **Kill a monster**
4. **Watch for messages**

**Expected messages (8-10 lines):**
```
[UnlootedCorpse] Extended opcode received: opcode=1, buffer=mark:X,Y,Z
[UnlootedCorpse] Subopcode 1 detected! Enabled=true
[UnlootedCorpse] Parsing message: 'mark:X,Y,Z'
... (more lines)
[CORPSE DRAW] Applying glow to corpse...
```

**If you see NO messages:** Server is not sending extended opcodes.

---

## ?? WHAT TO CHECK IF NO MESSAGES

### Issue 1: Module Not Loading

**Check console when client starts. Should see:**
```
[UnlootedCorpse] Script loaded, calling init()...
[UnlootedCorpse] Module initialized
```

**If missing:** Module is not in gamelib.otmod or there's a Lua error.

**Check for errors:** Look for red text in console mentioning `unlooted_corpses`.

### Issue 2: Server Not Sending Messages

**If module loads but no messages when killing monster:**
- Server is not implemented
- Server code has errors
- Extended opcodes not enabled on server

**Ask server admin to add debug output on server side.**

---

## ? SUCCESS = You Should See

When you kill a monster:
1. Console shows 8-10 debug messages
2. Corpse has a golden glow
3. When you loot, glow disappears
4. More console messages when looting

---

## ?? REPORT BACK

After testing, tell me:

1. Do you see "[UnlootedCorpse] Module initialized" when client starts?
2. Does the manual test (Step 3) work?
3. Do you see ANY messages when you kill a monster?
4. Copy the EXACT console output and paste it

This will tell us exactly where the problem is!
