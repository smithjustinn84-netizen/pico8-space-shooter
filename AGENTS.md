# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## Project Structure & Architecture

- **Shared Modular Libraries**: Core logic is split into separate Lua modules under `src/` (`constants.lua`, `utils.lua`, `stars.lua`, `fx.lua`, `player.lua`, `entities.lua`, `boss.lua`, `hud.lua`).
- **Two Entry Carts**: `space.p8` (Campaign) and `boss.p8` (Boss Rush). Both use relative `#include` statements to import modules from `src/`.
- **Edit Policy**: Always edit files under `src/*.lua`. Avoid modifying `space.p8` or `boss.p8` code blocks directly unless adding a cartridge-specific global init or section.

## Build System & Token Constraints

- Combined unminified code exceeds PICO-8's **8,192 token limit** (~8,213 tokens for the campaign).
- We use an automated build script `build.sh` to compile, minify, and export playable visual cartridges (`space.p8.png` and `boss.p8.png`) using `shrinko8.py`.
- **Minifier**: `shrinko8` safely minifies variable names/comments down to ~8,115 tokens without touching your clean development modules in `src/`.
- **Always run `./build.sh`** after making changes to verify token counts and update build artifacts.

## Running & Testing

- Run the minified, compiled visual cartridges on macOS using:
  - `/Applications/PICO-8.app/Contents/MacOS/pico8 -run space.p8.png` (Campaign)
  - `/Applications/PICO-8.app/Contents/MacOS/pico8 -run boss.p8.png` (Boss Rush)
- Controls: arrows = move, `Z` / `C` = Fire (🅾️), `X` / `V` = Focus slow-down (❎).

## Where the rest of the documentation lives

Progressive disclosure — keep this file tiny; load detail only when needed:

- **Engine knowledge** → the `pico8` skill (auto-loads on `.p8` files): cart sections, `__gfx__` hex layout, color palette, PICO-8 Lua dialect quirks, run/reload commands, common pitfalls.
- **Project conventions** → the `space-cart` skill (auto-loads when working with `space.p8`): state-machine dispatch, entity array pattern, base+frame sprite anim, globals policy, movement model, asset-pack note.
- **Sprite sheet** → the `space-sprites` skill: detailed documentation on the `__gfx__` layout, rows, and animation frames for all game objects.
- **Anything else** (tab purposes, sprite slot allocations, sound IDs) — read it from the cart. Don't trust snapshots; the source is authoritative.
