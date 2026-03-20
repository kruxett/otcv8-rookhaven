# Client Logging Control Guide

## Overview

The Rookhaven client has a centralized logging control system in `init.lua` that allows selective enabling/disabling of debug logging at runtime. By default, **all logging is disabled** to keep the console clean in production and normal gameplay.

---

## Logging Categories

All logging happens through the `ClientLog` system with these available channels:

| Channel | Description | Primary Module | Default |
|---------|-------------|-----------------|---------|
| `startup` | Client initialization and module loading | init.lua | **OFF** |
| `moduleLoad` | Individual module startup messages | init.lua | **OFF** |
| `rarity` | Item rarity detection (affixes) | game_affixes/, game_affixes/ground_rarity | **OFF** |
| `checksums` | Client-server file integrity checks | client_checksums/ | **OFF** |
| `cyclopedia` | Cyclopedia packet parsing and UI | game_cyclopedia/ | **OFF** |
| `unlooted` | Unlooted corpse tracking and glow system | gamelib/unlooted_corpses* | **OFF** |
| `interface` | Game UI startup and initialization | game_interface/ | **OFF** |

---

## How to Control Logging

### Via Lua Console (Runtime)

Open the Lua console with `/` then type any of these commands:

#### Enable All Logging
```lua
/lua ClientLog.enabled = true
```

#### Enable Specific Channels
```lua
/lua ClientLog.enabled = true; ClientLog.rarity = true
/lua ClientLog.enabled = true; ClientLog.unlooted = true
/lua ClientLog.enabled = true; ClientLog.checksums = true
/lua ClientLog.enabled = true; ClientLog.cyclopedia = true
```

#### Enable Multiple Channels
```lua
/lua ClientLog.enabled = true; ClientLog.rarity = true; ClientLog.unlooted = true; ClientLog.interface = true
```

#### Disable All Logging
```lua
/lua ClientLog.enabled = false
```

#### Check Current Status
```lua
/lua print(ClientLog.enabled, ClientLog.rarity, ClientLog.unlooted, ClientLog.checksums, ClientLog.cyclopedia, ClientLog.startup, ClientLog.interface)
```

---

## For Development/Install Scenarios

### DEV Client Configuration

If you always want logging enabled during development, add this to the **end of init.lua** (after the ClientLog table definition):

```lua
-- Development build: enable selective logging
if DEV_BUILD then
  ClientLog.enabled = true
  ClientLog.startup = true
  ClientLog.rarity = false  -- too noisy
  ClientLog.unlooted = true
  ClientLog.checksums = false  -- too noisy
  ClientLog.cyclopedia = false
  ClientLog.interface = true
end
```

Then set `DEV_BUILD = true` in your startup script.

### Production/Install Configuration

For Install builds, ensure at the **end of init.lua**:

```lua
-- Production/Install: all logging off
ClientLog.enabled = false
```

---

## Technical Details

### Where Logging Is Implemented

The `ClientLog` system lives in: `otcv8-rookhaven/init.lua`

Key functions:
```lua
ClientLog.isEnabled(channel)  -- Returns true if both enabled=true AND [channel]=true
ClientLog.info(channel, msg)  -- Logs msg via g_logger.info if channel is enabled
```

### How Each Module Uses It

| Module | Location | Pattern |
|--------|----------|---------|
| Rarity Detection | `modules/game_affixes/affixes.lua` | `ClientLog.info("rarity", msg)` |
| Ground Rarity | `modules/game_affixes/ground_rarity.lua` | `ClientLog.info("rarity", msg)` |
| Checksums | `modules/client_checksums/checksums.lua` | `logChecksum(msg)` helper → `ClientLog.isEnabled("checksums")` |
| Cyclopedia | `modules/game_cyclopedia/game_cyclopedia.lua` | `CYCLOPEDIA_DEBUG = ClientLog:isEnabled("cyclopedia")` |
| Unlooted Corpses Config | `modules/gamelib/unlooted_corpses_config.lua` | `logUnlooted(msg)` helper |
| Unlooted Corpses | `modules/gamelib/unlooted_corpses.lua` | `log(msg)` function → `ClientLog.isEnabled("unlooted")` |
| Game Interface | `modules/game_interface/gameinterface.lua` | `ClientLog.info("interface", msg)` |
| Init/Startup | `init.lua` | `ClientLog.info("startup"/"moduleLoad", msg)` |

---

## Current State Summary

**Default Configuration:**
- ✅ All logging channels are **OFF** by default
- ✅ Console is clean on first run (no noise from rarity, checksums, etc.)
- ✅ Runtime toggleable via Lua console
- ⚠️ You **must explicitly enable** channels to see debug output

**How to Verify Logging is Off:**
1. Run Install client
2. Open Lua console with `/`
3. Type: `print(ClientLog.enabled)`
4. Should print: `false`

**How to Verify Logging is Working:**
1. `/lua ClientLog.enabled = true; ClientLog.unlooted = true`
2. Move over a corpse with unlooted items
3. Console should show corpse glow debug messages

---

## Console Output Examples

### With unlooted logging enabled:
```
[Unlooted Corpses] Detected unlooted: Dragon Corpse (pos: 123, 456, 7)
[Unlooted Corpses] Applied glow effect: YELLOW
[Unlooted Corpses] Player opened corpse, glow removed
```

### With rarity logging enabled:
```
[Rarity] Item frame colors updated: sword → RARE (blue)
[Rarity] Boss loot detected: Golden Armor → EPIC (gold)
```

### With interface logging enabled:
```
[Interface] Game started, UI initialized
```

---

## Troubleshooting

**Q: I enable a channel but still don't see logs**
- Make sure `ClientLog.enabled = true` is set first
- Some events only log on specific conditions (e.g., unlooted only logs near corpses)
- Check that the module triggering the logs is actually running

**Q: Logging won't turn off**
- Run: `/lua ClientLog.enabled = false` again
- Restart the client

**Q: I want logging on by default for my custom build**
- Edit `init.lua` and add your config to the end (see "DEV Client Configuration" section above)
- Rebuild/repackage the client

---

## Built-in Logging Inventory

For a complete list of where all logging occurs in the codebase, see [CLIENT_LOGGING_INVENTORY.md](CLIENT_LOGGING_INVENTORY.md) which contains all 790 log call locations across 147 files and their frequency.

