---
name: space-sprites
description: Sprite documentation and conventions for the space.p8 game. Triggers when modifying or referencing sprites, animations, or weapons in the space shooter project.
---

# space-sprites

Documentation of the `space.p8` sprite sheet (`__gfx__` block). The sprite sheet is densely packed to avoid fragmentation.

## Sprite Layout (Rows 0-2)

### Row 0 (Sprites 0-15): Player & UI
- **0**: Empty
- **1, 2, 3**: Ships (Straight)
- **4, 5, 6**: Ships (Bank Left)
- **7, 8, 9**: Ships (Bank Right)
- **10, 11, 12, 13**: Thruster Flames (Squash-and-stretch heart shape)
- **14, 15**: HUD Health Hearts

### Row 1 (Sprites 16-31): Weapons & Effects
- **16**: Basic Weapon Muzzle Flash
- **17**: Plasma Weapon Muzzle Flash
- **18**: Laser Weapon Muzzle Flash
- **19, 20**: Basic Bullet (Red)
- **21, 22**: Plasma Bullet (Blue/White)
- **23, 24**: Laser Bullet (Green)
- **25, 26, 27**: Explosions
- **28-31**: Empty

### Row 2 (Sprites 32-47): Enemies
- **32, 33**: Basic Enemy
- **34, 35**: Tank/Diver Enemy
- **36, 37**: Zigzag Enemy
- **38, 39**: Spinner Enemy
- **40-47**: Empty

## Working with Sprites
- Sprites are drawn using `spr()` or `sspr()`. 
- Animations are mostly 2-frame, calculated using `base_sprite + flr(t() * speed) % frames`.
- Muzzle flashes are 8x8 sprites drawn above the ship (e.g., `obj.y - 6`) depending on `obj.weapon`.
- Thrusters are drawn below the ship using `sspr()` to grab 8x8 regions from x-coordinates 80, 88, 96, 104 (Sprites 10-13) and stretch them with `fh`.

## Helper Scripts
This skill includes Python utility scripts in the `scripts/` directory to help manipulate the `__gfx__` block without manual hex editing:
- **`scripts/dump_sprites.py [cart.p8]`**: Extracts the PICO-8 sprite sheet and prints every non-empty sprite to the console as an ASCII-art grid, making it easy to identify sprite indices and see their shapes and colors.
- **`scripts/modify_sprites_example.py`**: A reference script demonstrating how to programmatically replace or rearrange sprites in the `.p8` file by writing hex arrays directly into the `__gfx__` block.
