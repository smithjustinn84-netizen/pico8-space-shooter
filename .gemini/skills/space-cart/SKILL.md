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

## Token-conservation conventions

The cart is token-constrained (a previous pass already dropped enemy types to stay under 8192). When adding code, use these existing helpers and table lookups rather than open-coding the patterns:

- **`add_e(e, list)`** — defined in tab 0. Adds `e` to `entities` and, if `list` is given, also to the typed sublist (`bullets` / `ebullets` / `enemies`). Always use this for spawns; never write `add(entities, x) add(list, x)` twice.
- **`W_OFF[btype][min(lv,3)]`** + **`W_VX[btype]`** — defined in tab 0 next to `WEAPONS`. Per-weapon per-level offset arrays. `fire_bullet` reads them in a single loop. Adding a new weapon type means adding a row to `WEAPONS`, a row to `W_OFF`, and (if the offset modifies velocity instead of position) a flag in `W_VX`. No new `if btype == ...` branches.
- **`tick_life(self)`** — defined in tab 3. Increments `self.h` and marks `self.dead` when `self.h > self.max_h`. Use as `e.move = tick_life` for any FX entity with `h`/`max_h` lifetime fields (explosions, shockwaves, particles can call it from inside a richer move closure).
- **`boss_fire[phase](e)`** — defined in tab 3 (above the boss `enemy_types` entry). Indexed by `combat_phase` (1/2/3). Add new phases by appending a function. Boss move calls `boss_fire[e.combat_phase](e); sfx(7)` — `sfx(7)` is hoisted out of each pattern.
- **`enemy_types` table** — adding an enemy is one new row (`sp`, `pts`, `move`, `mk_x`, `mk_vy`, `extra`, optional `draw_fn`). Never write a standalone `spawn_enemy_X()` function.
- **`burst_sparks` / `burst_smoke` / `burst_embers` / `burst_thruster`** — one-line wrappers around `emit_fx`. Random expressions in their option tables evaluate per *burst*, not per *particle*; the per-particle variation comes from `make_particle`'s own logic. If you need true per-particle randomness on a field, the wrapper has to be expanded inline.

## Deferred token-savings (known follow-ups)

These were identified during a token audit but not yet applied. If the budget tightens again, attack these next:
- **Data-driven `enemy_types` move dispatch.** The current table embeds long inline `move` closures per type. Lifting them to top-level `move_chaser` / `move_tank` / etc. with shared spawn-bullet helpers should save ~120 tokens.
- **String → int weapon and state IDs in hot paths.** Replace `btype == "basic"` comparisons with integer constants; cheaper per comparison.
- **Extract `check_collisions` handlers.** Three nested blocks (bullet vs enemy, enemy vs player, ebullet vs player) repeat `burst_sparks` / `make_hit_flash` / `add_e` patterns; per-type handler functions would collapse the duplication.
- **Multi-cart split.** `load("game.p8")` from a title cart, with `cartdata()` for hi-score persistence. Last resort — breaks one-cart BBS upload simplicity.

See the `pico8` skill's "Token economy" section for general PICO-8 techniques and the source links there.
