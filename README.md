# Space Shooter SHMUP

A fast-paced, classic shoot 'em up (SHMUP) built for the **PICO-8** fantasy console. Pilot your ship through a dangerous starfield, blast waves of enemies, and strive for the highest score!

![Space Shooter Gameplay](SpaceShooterAssets/preview.gif) *(Note: Add a preview gif if available)*

## Features

- **Smooth Arcade Movement**: responsive controls with acceleration and friction for a premium "feel."
- **Dynamic Visuals**: Animated thrusters, muzzle flashes, and a multi-layered parallax starfield.
- **Combat System**: 
  - Rapid-fire laser cannon.
  - Challenging enemy waves with varying speeds.
  - Explosion effects with expanding shockwave rings.
  - Score popups (+10) that float up from each kill.
- **HUD & Health**: Keep track of your score and your 3 HP. Includes invincibility frames (iframes) to give you a fighting chance after taking damage. Taking a hit triggers screen shake and a red border flash.
- **Retro Audio**: Custom sound effects for firing, enemy destruction, and player collisions.

## Controls

| Action | Control |
| :--- | :--- |
| **Move Ship** | Arrow Keys |
| **Fire Laser** | `Z` or `X` (Button 4/5) |
| **Start Game** | `Z` or `X` |

## How to Play

1. **Launch**: Open `space.p8` in PICO-8.
2. **Start**: Press `Z` or `X` on the title screen.
3. **Survive**: Navigate your ship to avoid colliding with enemies.
4. **Destroy**: Blast enemies to earn **10 points** each.
5. **HP**: You have 3 lives. If you hit an enemy, you'll lose one and gain temporary invincibility. Lose all three, and it's game over!

## Technical Details

- **Language**: Lua (PICO-8 variant)
- **Resolution**: 128x128 pixels
- **Palette**: 16 colors (Standard PICO-8 palette)
- **Architecture**: Modular state-based structure (Title, Game) for easy expansion.

## Development

This project follows PICO-8 best practices for performance and organization:
- **State Management**: Uses a `state` table to toggle between title and gameplay logic.
- **Physics**: Implements vector-based movement with clamping to ensure consistent speed.
- **AABB Collisions**: Efficient Axis-Aligned Bounding Box checks for entity interactions.

---
*Created by [Justin Smith](https://github.com/justinsmith)*
