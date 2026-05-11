---
name: pico8-sfx
description: PICO-8 SFX authoring — format spec, sound design patterns, and Python automation for generating, validating, and patching __sfx__ lines in .p8 carts. Triggers on questions about sfx slots, silent sounds, SFX hex format, designing weapon/UI/ambient sounds, or using sfx_tool.py. Complements pico8 skill (cart format) and space-cart skill (play_sound wrapper). Skip for sprite or map work.
---

# pico8-sfx

Tools and patterns for authoring PICO-8 sound effects directly in the `__sfx__` section of `.p8` carts.

## Format spec — one sfx line = 168 hex chars

```
[header 8 chars][32 notes × 5 chars = 160 chars]
```

### Header (8 chars)
| Chars | Field       | Notes                         |
|-------|-------------|-------------------------------|
| 0-1   | flags       | usually `00`                  |
| 2-3   | speed       | `01`=fastest … `ff`=slowest   |
| 4-5   | loop_start  | note index to loop back to    |
| 6-7   | loop_end    | note index where loop fires   |

No loop = `00020000` (speed=2, no loop).

### Note (5 chars each)
| Chars | Field  | Range  | Notes                                 |
|-------|--------|--------|---------------------------------------|
| 0-1   | pitch  | 00-3f  | 0=C0, 12=C1 … 60=C5, 63=D#5          |
| 2     | wave   | 0-7    | see waveform table below              |
| 3     | vol    | 0-7    | 0=silent, 7=loudest                   |
| 4     | effect | 0-7    | see effect table below                |

Rest = `00000` (pitch=0, wave=0, vol=0, effect=0).

### Waveforms
| Value | Name           | Character                   |
|-------|----------------|-----------------------------|
| 0     | triangle       | pure, smooth                |
| 1     | tilt-sawtooth  | slightly harder than tri    |
| 2     | sawtooth       | bright, buzzy               |
| 3     | square         | hollow, retro               |
| 4     | pulse          | nasal, thin                 |
| 5     | organ          | warm, full                  |
| 6     | noise          | static, explosions          |
| 7     | phaser         | swooshy, sci-fi             |

### Effects
| Value | Name      | Behavior                          |
|-------|-----------|-----------------------------------|
| 0     | none      | —                                 |
| 1     | slide     | pitch slides from previous note   |
| 2     | vibrato   | oscillates pitch                  |
| 3     | drop      | pitch drops rapidly               |
| 4     | fade-in   | volume rises from 0               |
| 5     | fade-out  | volume decays to 0                |
| 6     | arp-fast  | fast arpeggiation                 |
| 7     | arp-slow  | slow arpeggiation                 |

## Common pitfall — misaligned header causes silence

**Symptom**: sfx line plays completely silent despite having note data.

**Cause**: line has 12-char header (`000200000000...`) instead of 8-char (`00020000...`). The extra 4 bytes push all note data 4 chars right, so every `vol` field lands on `0`.

**Diagnosis**: `python3 sfx_tool.py validate space.p8` — any line ≠ 168 chars is broken.

**Fix**: rewrite from scratch using `sfx_tool.py` presets or `build_sfx()`.

## Python automation — sfx_tool.py

Located at `.claude/skills/pico8-sfx/sfx_tool.py`. Copy to the cart directory before running.

```bash
# Show all preset sounds
python3 sfx_tool.py design

# Validate all sfx slots in a cart
python3 sfx_tool.py validate space.p8

# Print note-by-note dump of all non-empty slots
python3 sfx_tool.py dump space.p8

# Write a preset directly to a slot
python3 sfx_tool.py preset laser
python3 sfx_tool.py patch space.p8 5 <line>

# One-liner: generate and immediately patch
python3 -c "
import sys; sys.path.insert(0, '.claude/skills/pico8-sfx')
from sfx_tool import preset_laser, patch
patch('space.p8', 5, preset_laser())
"
```

## Sound design patterns

### Weapon fire — general recipe
- **Speed**: 1-3 (fast — weapon fire is brief)
- **Wave**: 1-2 (sawtooth family for attack) or 3-7 (energy weapons)
- **Shape**: high pitch → descend, vol 5-7 → fade to 0-1
- **Length**: 4-8 active notes, rest are `00000`

### Weapon tiers
| Tier   | Wave | Pitch range | Speed | Character            |
|--------|------|-------------|-------|----------------------|
| Basic  | 1    | 0x20-0x2c   | 2     | punchy pew           |
| Plasma | 3    | 0x38-0x3c   | 2     | double burst, hollow |
| Laser  | 0    | 0x2c-0x3c   | 1     | fast sweep, clean    |

### UI / feedback
| Use case  | Wave | Speed | Tip                            |
|-----------|------|-------|--------------------------------|
| Menu nav  | 0    | 2     | single short note              |
| Level up  | 5    | 5     | ascending arpeggio, long       |
| Hit flash | 6    | 3     | noise burst, 2-3 notes         |
| Explosion | 6    | 8     | noise, long fade, low pitch    |
| Pickup    | 5    | 5     | rising chord 2-3 notes         |

## In-game wiring (space.p8 pattern)

```lua
-- global service wrapper — always use this, never sfx() directly
function play_sound(id) sfx(id) end

-- slot assignments in space.p8
-- 0: menu navigation
-- 1: bullet hit
-- 2: explosion / player death
-- 3: level up
-- 4: plasma fire
-- 5: laser fire
-- 6: basic fire
```

Add new sounds to the next empty slot (7+) and call `play_sound(slot)`.

## Adding a new sound — checklist

1. Design the sfx line with `sfx_tool.py` (use a preset or `build_sfx()`)
2. Verify it is exactly 168 chars
3. Append the line to `__sfx__` in the cart (slot = line count after `__sfx__` header)
4. Call `play_sound(slot_id)` at the right point in Lua
5. `CTRL+R` in PICO-8 to hot-reload and test
