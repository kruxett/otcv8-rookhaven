# Blood Pool / Decay Stage Fix for Unlooted Corpse System

## Problem
Blood pools and corpse decay stages were getting the gold glow marker intended only for lootable corpses.

## Root Cause
The corpse detection logic was marking ALL items in the corpse ID range (2806-5767), including:
- Lootable corpse containers (SHOULD be marked ?)
- Corpse decay stages / non-container corpses (should NOT be marked ?)
- Blood/slime pools (should NOT be marked ?)
- Blood splatter visuals (should NOT be marked ?)

## Solution
Updated `src\client\tile.cpp` in the `updateUnlootedCorpseMarks()` function:

### Change 1: Only Mark Container Corpses
**Line 1006:**
```cpp
// OLD:
if (isCorpse && !isBloodPool) {

// NEW:
if (isCorpse && !isBloodPool && isContainer) {
```

This ensures only corpse **containers** (lootable corpses) get marked. Non-container corpse items (decay stages, blood visuals) are skipped.

### Change 2: Expand Blood Pool Detection
**Line 979-981:**
```cpp
// OLD:
bool isBloodPool = (itemId >= 2016 && itemId <= 2030);

// NEW:
bool isBloodPool = (itemId >= 2016 && itemId <= 2030) || (itemId >= 1900 && itemId <= 1905);
```

Now also excludes bloodspot items (1900-1905), which are visual blood splatter effects.

### Change 3: Better Logging
Added specific log message for skipped non-container corpses:
```cpp
} else if (isCorpse && !isContainer) {
    // This is a non-container corpse item (likely a decay stage or blood visual)
    g_logger.info(stdext::format("[CORPSE DEBUG] ? SKIPPING non-container corpse item ID=%d (likely decay stage or blood graphic)", itemId));
}
```

## Testing
When you see corpses decay, the logs should now show:
```
[CORPSE DEBUG] Item ID=2886, ... isContainer=NO ...
[CORPSE DEBUG] ? SKIPPING non-container corpse item ID=2886 (likely decay stage or blood graphic)
```

Only the initial corpse container (with loot) should have the gold glow. As it decays into non-container items, those items should NOT be marked.

## Item ID Ranges Reference
- **Blood pools**: 2016-2030
- **Bloodspots** (visual splatter): 1900-1905
- **Corpses (main)**: 2806-3134
- **Corpses (extended)**: 4251-4327
- **Corpses (additional)**: 5522-5767

## Files Modified
- `src\client\tile.cpp` - updateUnlootedCorpseMarks() function

## Build Status
? Build successful with no compilation errors
