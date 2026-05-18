---
name: space-cart
description: Project-specific conventions for editing `space.p8`, the single-cart vertical-scrolling space shooter in this directory. Triggers when editing or discussing space.p8, adding screens/entities/sprites/sounds/movement to this game, or asking about its state machine, entity system, or sprite layout. Defer engine-level PICO-8 questions (cart format, hex layout, Lua dialect) to the `pico8` skill. Skip for any other PICO-8 project.
---

# space-cart

Conventions specific to `space.p8` in this directory. The cart itself is authoritative — these notes describe the architectural choices that aren't obvious from a quick skim, so new code matches the existing style.

## Source-of-truth pointers

Read these from the cart, not from any markdown:

- **Tab purposes** — commented at the top of each `-->8` tab as `-- tab N: ...`.
- **Sprite slot allocations** — see the `S_*` constants at the top of tab 0, plus the first 16 columns of `__gfx__`. Decode the sheet with the awk one-liner in the `pico8` skill before redrawing anything.
- **Sound IDs** — grep `sfx(` in the source.
- **Entity shapes** — see the `make_*` / `spawn_*` factory functions; each entity carries its own `x,y,w,h,sp,vy,tag` etc.

## Architectural patterns to follow

- **State machine via a `state` global** with `update`/`draw` fields. `_update60`/`_draw` only dispatch to `state.update()` / `state.draw()`. New screens: define another `{ update=, draw= }` table plus a `go_to_*` helper.
- **Entity manager pattern**: all live game objects live in one flat `entities` list. Each entity carries its own `update(e)` and `draw(e)` closures, a `tag` string (`"bullet"`, `"enemy"`, `"explosion"`, `"popup"`), and a `dead` boolean. `game_state.update` iterates `entities`, calls `e.update(e)`, and removes `e.dead`; `game_state.draw` iterates and calls `e.draw(e)`. Never call `del()` inside `check_collisions` — set `e.dead=true` and let the manager loop clean up.
- **Stars use closure-style objects but live in a separate `stars` global** (not `entities`). They persist across state transitions — `game_state.init` resets `entities={}` but not `stars`, and `title_state.draw` calls `draw_stars()` directly. Each star object carries `update`/`draw` closures consistent with the entity pattern; `update_stars()`/`draw_stars()` are thin dispatch loops.
- **Player `p` stays outside `entities`** — correct by design. It is a complex singleton that never gets removed mid-loop, requires direct access for collision checks, and has input-driven behavior that does not benefit from closure style. `update_player(p)` and `draw_player(p)` are called explicitly.
- **Factory functions, not standalone update/draw pairs**: spawn entities via `make_*(…)` factories that return tables with inline closures (e.g. `make_bullet`, `make_explosion`, `make_popup`). `spawn_enemy(type_name)` creates and adds the entity directly. Add a new entity type by writing one factory function — no separate update fn, draw fn, or entity list required.
- **Data-driven enemy types via `enemy_types` table**: fields are `sp`, `pts`, `move`, `mk_x`, `mk_vy`, `extra`. Add new variants as new keys. Spawn via `spawn_enemy("type_name")`. Never add a `spawn_enemy_N()` variant function.
- **Global service wrappers**: play sounds via `play_sound(id)`, trigger camera shake via `shake_screen(mag, dur)`. Never call `sfx()` or assign `shake_t`/`shake_mag` directly from entity logic.
- **Animated sprites use base+frame**: store the base index on the entity, draw via `spr(base + flr(t()*N) % frames, x, y)`. New animations should reserve a contiguous run of sprite slots and reference the first via a `S_*` constant in tab 0.
- **Player movement is direct 1:1** with diagonal normalisation, focus mode (half-speed while holding fire), and hard boundary clamping. No inertia, no drift — instant stop when input ceases. Match that model for any new movement so feel stays consistent.
- **Globals stay global** (`state`, `p`, `entities`, `stars`, `score`, `shake_t`, `shake_mag`, `hit_flash_t`). Don't introduce module-scope `local`s — PICO-8 idiom and the 8192-token budget both prefer globals here.

## Asset pack

`SpaceShooterAssets/` is a reference PNG pack (top-down ships / projectiles / backgrounds) included for visual reference only. Sprites used at runtime are hand-translated into the `__gfx__` block of the cart. Nothing on disk loads PNGs at runtime — don't write code that tries.
