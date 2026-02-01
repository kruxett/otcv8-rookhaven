# Rarity Border Implementation - Sprite Sheet Approach

## Overview
The rarity border system now uses the `rarity_frames.png` sprite sheet to render borders **behind** item sprites, creating the proper visual layering.

## Technical Implementation

### Sprite Sheet Structure
- **File**: `/data/images/ui/rarity_frames.png`
- **Dimensions**: 160x32 pixels
- **Layout**: 5 frames of 32x32 pixels each (horizontal strip)
- **Frame Order**: Rare (0,0), Epic (32,0), Legendary (64,0), Plus 2 more frames

### How It Works

#### Rendering Order (UIItem::drawSelf):
1. Background
2. **Image (image-source)** ? Rarity border renders here
3. **Item sprite** (m_item->draw)
4. Count text
5. Border
6. Icon
7. Text

By setting the `image-source` property on the UIItem widget, the rarity border renders at step 2, **before** the item sprite (step 3), placing it behind the item.

### Code Changes

#### 1. Configuration (AFFIX_STYLES)
```lua
local AFFIX_STYLES = {
  rare = {
    imageClip = {x = 0, y = 0, width = 32, height = 32}  -- First frame
  },
  epic = {
    imageClip = {x = 32, y = 0, width = 32, height = 32}  -- Second frame
  },
  legendary = {
    imageClip = {x = 64, y = 0, width = 32, height = 32}  -- Third frame
  }
}
```

#### 2. createOverlay Function
- Sets `image-source` to `/images/ui/rarity_frames`
- Sets `image-clip` to select the appropriate frame coordinates
- Caches original image properties for restoration

#### 3. removeOverlay Function
- Restores original `image-source` and `image-clip` values
- Removes the rarity border when item changes

### Advantages Over Previous Approach

? **Correct Z-Order**: Border renders behind item sprite automatically  
? **No Child Widgets**: Cleaner, more performant (no extra widget hierarchy)  
? **Native Rendering**: Uses built-in UIItem image rendering  
? **Sprite Sheet Efficient**: Single texture with multiple frames  
? **Easy Maintenance**: Change sprite sheet to update all borders  

### Frame Mapping

| Rarity | X Position | Y Position | Width | Height |
|--------|-----------|------------|-------|--------|
| Rare | 0 | 0 | 32 | 32 |
| Epic | 32 | 0 | 32 | 32 |
| Legendary | 64 | 0 | 32 | 32 |
| (Reserved) | 96 | 0 | 32 | 32 |
| (Reserved) | 128 | 0 | 32 | 32 |

### Adding New Rarities

To add new rarity tiers:
1. Update `rarity_frames.png` with new frames (extend width by 32px per frame)
2. Add new entry to `AFFIX_STYLES` with correct `imageClip` coordinates
3. Add detection logic in `detectAffix()` function

Example for "mythic" rarity:
```lua
mythic = {
  imageClip = {x = 96, y = 0, width = 32, height = 32}  -- Fourth frame
}
```

## Testing

The borders will now:
- Appear behind item sprites (not on top)
- Use the gradient design from `rarity_frames.png`
- Work in inventory, containers, equipment slots, etc.
- Automatically restore original images when items change

## Compatibility

This implementation is compatible with:
- All UIItem widgets (inventory, containers, ground)
- Existing item styles (slot backgrounds, blessed items)
- Custom layouts (retro, mobile)
