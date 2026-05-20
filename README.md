# Space Shooter SHMUP

A fast-paced, vertical-scrolling space shooter (SHMUP) built for the **PICO-8** fantasy console. Pilot your ship through a dangerous starfield, choose from three distinct ship archetypes, battle waves of enemies, and face down the ultimate alien boss!

![Space Shooter Gameplay](SpaceShooterAssets/preview.gif) *(Note: Add a preview gif if available)*

---

## Features

- **Modular Campaign & Boss Rush**: Play the progressive campaign (`space.p8`) or jump straight into the intense Boss Rush (`boss.p8`).
- **Ship Archetypes**: Choose your style—Balanced, Assault (high fire rate), or Heavy (slow, powerful double shots).
- **Highly Optimized Fixed-Point Game Math**: Completely custom trig-based vector normalization, squared-distance proximity checks, and branchless diagonal speed approximations designed for PICO-8's 60 FPS constraint.
- **Premium UI Micro-Animations**: Interative menus, ship selection screens, and the campaign Upgrade Shop feature organic sliding selection boxes driven by smooth linear interpolation (`lerp`).
- **Responsive Controls**: Physics-based flight controls with precise diagonal speed normalization (`0.7071`).
- **Dynamic Visuals**: Animated thrusters, muzzle flashes, custom shockwaves, particles, and floating score popups.
- **Invincibility & Screen Shake**: Action-packed feedback with screen-shake, red border damage flashes, and iframes.
- **Parallax Starfield**: Multi-layered background stars that scale speed relative to ship motion.

---

## Codebase Architecture

The project has been refactored into a modular structure where core gameplay files are shared between both cartridges. 

```
.
├── space.p8            # Campaign Cartridge (entry point)
├── boss.p8             # Boss Rush Cartridge (entry point)
├── build.sh            # Automated compilation and minification script
└── src/                # Shared Lua modules
    ├── constants.lua   # Palettes, ship configurations, weapon tables
    ├── utils.lua       # Bounding box collision, shake patterns, lerp, angle_to, dist_sqr
    ├── stars.lua       # Starfield update & rendering
    ├── fx.lua          # Particles, shockwaves, score popups
    ├── player.lua      # Ship controls, firing logic, archetype adjustments
    ├── entities.lua    # Enemy spawning, bullets, hit detection
    ├── boss.lua        # Boss attack sequences, state machine
    └── hud.lua         # Level wave progress, shield, HP, boss life indicators
```

Each cartridge uses relative `#include` statements to load these modules dynamically.

---

## Development & Minification Pipeline

PICO-8 has a strict budget of **8,192 tokens**. Combining all shared modules unminified pushes the campaign cartridge slightly over this limit (~8,213 tokens). 

To solve this while keeping the source code human-readable (with long variable names and detailed comments), we use a minification and compilation step utilizing `shrinko8`.

### Building Minified Carts
An automated script, `build.sh`, is included in the project root. Running it searches for your local `shrinko8.py` installation, runs safe-only minification, and outputs fully playable visual `.png` cartridges:

```bash
# Run the automated build script
./build.sh
```

This compiles:
* **`space.p8.png`** (Campaign): ~8,051 tokens (98.28% of limit, safely under budget)
* **`boss.p8.png`** (Boss Rush): ~7,344 tokens (89.65% of limit)

---

## How to Play

### Controls

| Action | Keyboard Control | PICO-8 Button |
| :--- | :--- | :--- |
| **Move Ship** | Arrow Keys | D-Pad |
| **Fire Laser** | `Z` / `C` | Button 🅾️ (Button 4) |
| **Slow down / Focus** | `X` / `V` | Button ❎ (Button 5) |
| **Start / Select** | `Z` / `C` | Button 🅾️ (Button 4) |

### Game Modes

1. **Campaign (`space.p8.png`)**: Survive incoming enemy waves, accumulate score (+10 points per kill), and progress through stages.
2. **Boss Rush (`boss.p8.png`)**: Skip straight to the climax! Dodge intense bullet-hell patterns and take down the final boss.

### Launching in PICO-8

You can run the minified, compiled cartridges directly using the CLI:

```bash
# Run the Campaign
/Applications/PICO-8.app/Contents/MacOS/pico8 -run space.p8.png

# Run the Boss Rush
/Applications/PICO-8.app/Contents/MacOS/pico8 -run boss.p8.png
```

Alternatively, open PICO-8 and type `load space.p8.png` or `load boss.p8.png` followed by `run`.

---
*Created by [Justin Smith](https://github.com/justinsmith)*
