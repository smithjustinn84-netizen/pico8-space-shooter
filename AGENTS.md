# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## Project

Single-cart PICO-8 game (`space.p8`). Vertical-scrolling space shooter. No build system — PICO-8 loads the cart directly.

## Running

- `pico8 space.p8`, or `/Applications/PICO-8.app/Contents/MacOS/pico8 -run space.p8` on macOS.
- `CTRL+R` inside PICO-8 hot-reloads after external edits.
- Controls: arrows = move, A (Z) = Fire, B (X) = Focus (slow-down).

## Where the rest of the documentation lives

Progressive disclosure — keep this file tiny; load detail only when needed:

- **Engine knowledge** → the `pico8` skill (auto-loads on `.p8` files): cart sections, `__gfx__` hex layout, color palette, PICO-8 Lua dialect quirks, run/reload commands, common pitfalls.
- **Project conventions** → the `space-cart` skill (auto-loads when working with `space.p8`): state-machine dispatch, entity array pattern, base+frame sprite anim, globals policy, movement model, asset-pack note.
- **Sprite sheet** → the `space-sprites` skill: detailed documentation on the `__gfx__` layout, rows, and animation frames for all game objects.
- **Anything else** (tab purposes, sprite slot allocations, sound IDs) — read it from the cart. Don't trust snapshots; the source is authoritative.
