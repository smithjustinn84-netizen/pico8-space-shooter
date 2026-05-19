pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
-- tab 0: core logic

MAX_LEVEL = 5

level_waves = {
  {
    "basic:20,basic:60,basic:100",
    "basic:15,zigzag:45,basic:75,zigzag:105",
    "basic:10,basic:40,zigzag:55,basic:80,basic:110,zigzag:25"
  },
  {
    "chaser:15,chaser:105",
    "chaser:30,chaser:90,basic:20,basic:100",
    "chaser:10,chaser:110,zigzag:20,zigzag:60,zigzag:100"
  },
  {
    "shooter:20,shooter:100",
    "shooter:30,shooter:90,basic:10,basic:60,basic:110",
    "shooter:15,shooter:105,chaser:45,chaser:75,chaser:30,chaser:90"
  },
  {
    "tank:60,basic:20,basic:100",
    "spinner:15,spinner:48,spinner:81,spinner:113",
    "tank:35,tank:85,spinner:15,spinner:60,spinner:105,shooter:8"
  },
  {
    "shooter:20,chaser:60,chaser:100",
    "tank:30,tank:90,shooter:10,shooter:60,shooter:110",
    "chaser:20,chaser:100,shooter:10,shooter:110,spinner:45,spinner:75"
  }
}

S_ENEMY, S_ENEMY2, S_ENEMY3, S_ENEMY4, S_BULLET, S_BULLET_PLASMA, S_BULLET_LASER, S_MUZZLE, S_MUZZLE_PLASMA, S_MUZZLE_LASER = 32, 36, 34, 38, 19, 21, 23, 16, 17, 18

SPARK_C = { 7, 9, 10 }
EMBER_C = { 8, 9, 10 }
SMOKE_C = { 5, 6, 13 }
PLASMA_C = { 12, 13, 14 }
ships = {
  { 1, 4, 7, "basic", 3, 3, 0, 0, 10, false, EMBER_C },
  { 2, 5, 8, "plasma", 2, 4, 0, 0, 8, true, { 12, 13, 7 } },
  { 3, 6, 9, "basic", 4, 2, 0, 0, 12, false, { 11, 3, 10 } }
}

WEAPONS = {
  basic = { w_sp = 49, b_sp = S_BULLET, sfx = 6, muz = S_MUZZLE, dmg = 1, v = -4 },
  spread = { w_sp = 50, b_sp = S_BULLET, sfx = 6, muz = S_MUZZLE, dmg = 1, v = -4 },
  plasma = { w_sp = 51, b_sp = S_BULLET_PLASMA, sfx = 4, muz = S_MUZZLE_PLASMA, dmg = 2, v = -5 },
  laser = { w_sp = 52, b_sp = S_BULLET_LASER, sfx = 5, muz = S_MUZZLE_LASER, dmg = 3, v = -6 }
}
-- per-weapon level offsets: W_OFF[btype][min(lv,3)] -> array applied to b.x (or b.vx if W_VX[btype])
W_OFF = {
  basic  = { { 0 }, { -3, 3 }, { -4, 0, 4 } },
  spread = { { -2.5, 0, 2.5 }, { -3.5, 0, 3.5 }, { -4, -2, 0, 2, 4 } },
  plasma = { { -4, 4 }, { -4, 0, 4 }, { -6, -2, 2, 6 } },
  laser  = { { 0 }, { 0 }, { -4, 4 } }
}
W_VX = { spread = true }
function tf(n, m) return flr(t() * n) % m end
-- spawn helper: add to entities + optional typed sublist
function add_e(e, list)
  add(entities, e)
  if list then add(list, e) end
end
shop_choices = {}
shop_cursor = 1
selected_ship = 1
hit_stop_t = 0

function _init()
  music(0)
  hi_score, final_score, level, level_kills, li_t, stage_completing, entities = 0, 0, 1, 0, 0, false, {}
  init_stars()
  go_to_title()
end

function _update60()
  if hit_stop_t > 0 then
    hit_stop_t -= 1
    return
  end
  if state.update then state.update() end
end

function _draw()
  cls(1)
  if state.draw then state.draw() end
end

function go_to_title()
  entities = {}
  music(4)
  state = title_state
end

function go_to_game()
  music(0)
  game_state.init()
  go_to_level_intro()
end

function go_to_gameover()
  music(8)
  go_t = 0
  hi_score = max(hi_score, final_score)
  for e in all(entities) do
    if e.tag == "enemy" or e.tag == "ebullet" then e.dead = true end
  end
  state = gameover_state
end

function go_to_win()
  music(9)
  go_t = 0
  final_score = score
  hi_score = max(hi_score, final_score)
  entities = {}
  add(entities, p, 1)
  state = win_state
end

function go_to_level_intro()
  li_t = 0
  sfx(3)
  state = level_intro_state
end

function go_to_game_resume()
  state = game_state
end

-->8
-- tab 1: game states

title_state = {
  update = function()
    if btnp(0) then
      selected_ship = ((selected_ship - 2) % 3) + 1
      sfx(0)
    end
    if btnp(1) then
      selected_ship = (selected_ship % 3) + 1
      sfx(0)
    end
    if btnp(4) or btnp(5) then
      go_to_game()
    end
  end,
  draw = function()
    draw_stars()
    ?"space shooter", 38, 40, 7
    types = { "balanced", "assault", "heavy" }
    for i = 1, 3 do
      sx, sy = 46 + (i - 1) * 16, 60
      if selected_ship == i then
        circfill(sx + 3, sy + 3, 8, 5)
        ?types[i], 64 - #types[i] * 2, 74, 6
        s = ships[i]
        ?"hp:", 30, 82, 6
        for h = 1, s[5] do
          spr(14, 46 + (h - 1) * 9, 81)
        end
        ?"spd:", 30, 90, 6
        for b = 1, s[6] - 1 do
          rectfill(46 + (b - 1) * 6, 90, 50 + (b - 1) * 6, 95, 7)
        end
        ?"gun: " .. s[4], 30, 98, 6
      end
      spr(ships[i][1], sx, sy)
    end

    if tf(2, 2) == 0 then
      ?"press a to start", 32, 110, 6
    end
  end
}

game_state = {
  init = function()
    score, level, level_kills, entities, bullets, enemies, ebullets = 0, 1, 0, {}, {}, {}, {}
    sublists = { bullet = bullets, enemy = enemies, ebullet = ebullets }
    init_player()
    shake_t, shake_mag, hit_flash_t, death_flash_t, death_timer, stage_completing, boss_spawned, boss_ent, current_wave, wave_spawned, hit_stop_t, reached_hi_score_this_run = 0, 0, 0, 0, 0, false, false, nil, 1, false, 0, false
    spawn_queue = {}
  end,
  update = function()
    update_stars()
    if not p.dead and not stage_completing then
      if level <= MAX_LEVEL then
        local wl = level_waves[level]
        if #enemies == 0 and wave_spawned and #spawn_queue == 0 then
          if current_wave < #wl then
            current_wave += 1
            wave_spawned = false
          else
            level += 1
            current_wave = 1
            wave_spawned = false
            level_kills = 0
            stage_completing = true
          end
        end
        for q in all(spawn_queue) do
          if q.d <= 0 then
            trigger_spawn(q.t, q.x)
            del(spawn_queue, q)
          else
            q.d -= 1
          end
        end
        if not wave_spawned and not stage_completing then
          wave_spawned = true
          load_wave(wl[current_wave])
        end
      else
        -- boss stage: spawn boss once
        if not boss_spawned then
          spawn_enemy("boss")
          boss_spawned = true
          music(10)
        end
      end
    end
    -- unified entity loop: player + all enemies/bullets/fx
    for e in all(entities) do
      e.update(e)
      if e.dead and e.tag ~= "player" then
        del(entities, e)
        -- keep typed sub-lists in sync
        if sublists[e.tag] then del(sublists[e.tag], e) end
      end
    end
    if not p.dead then
      check_collisions()
      if hi_score > 0 and score > hi_score and not reached_hi_score_this_run then
        reached_hi_score_this_run = true
        sfx(60)
        add(entities, make_popup(p.x - 16, p.y - 8, "high score!"))
        for i = 1, 20 do
          add(
            entities, make_particle(
              p.x + 4, p.y + 4, {
                cols = { 10, 9, 7 }, spd = 1 + rnd(3), life = 30 + rnd(20),
                grav = 0.03, drag = 0.96, trail = true
              }
            )
          )
        end
      end
    end
    if stage_completing then
      stage_completing = false
      entities, bullets, enemies, ebullets = {}, {}, {}, {}
      sublists = { bullet = bullets, enemy = enemies, ebullet = ebullets }
      -- re-insert player so it survives the wipe
      add(entities, p, 1)
      go_to_shop()
      return
    end
    if shake_t > 0 then
      shake_t -= 1
      shake_mag *= 0.75
    end
    if hit_flash_t > 0 then hit_flash_t -= 1 end
    if death_flash_t > 0 then death_flash_t -= 1 end
  end,
  draw = function()
    apply_shake()
    draw_stars()
    -- player is entity[1]; all entities draw in insertion order
    for e in all(entities) do
      e.draw(e)
    end
    camera()
    draw_hit_flash()
    if not p.dead then draw_hud() end
  end
}

function make_end_state(win)
  local txt = win and "you win!" or "game over"
  local cols = win and { 11, 3, 11, 3 } or { 8, 9, 10, 9 }
  local sx = win and 39 or 38
  local mx = win and 38 or 37
  return {
    update = function()
      go_t += 1
      update_stars()
      if win and go_t > 0 and go_t % 30 == 0 then
        sfx(61)
        local fx, fy = 10 + rnd(108), 10 + rnd(80)
        local c1 = 8 + flr(rnd(7))
        local c2 = 8 + flr(rnd(7))
        for i=1, 25 do
          add(entities, make_particle(fx, fy, {cols={7, c1, c2}, spd=1+rnd(3), life=20+rnd(30), grav=0.03, drag=0.95, trail=true}))
        end
        add(entities, make_shockwave(fx, fy))
      end
      for e in all(entities) do
        e.update(e)
        if e.dead then
          del(entities, e)
          if sublists[e.tag] then del(sublists[e.tag], e) end
        end
      end
      if go_t > 90 then
        if btnp(4) then go_to_game() end
        if btnp(5) then go_to_title() end
      end
    end,
    draw = function()
      draw_stars()
      for e in all(entities) do
        e.draw(e)
      end
      camera()
      ty = 45
      if go_t < 30 then
        ty = -20 + (1 - (1 - go_t / 30) ^ 3) * 65
      end
      wx = flr(sin(go_t * 0.07) * 1.5)
      cc = cols[flr(go_t * 0.08) % 4 + 1]
      ?txt, sx + wx, ty + 1, 1
      ?txt, mx + wx, ty, cc
      if go_t > 45 then
        ?"score: " .. final_score, 42, ty + 16, go_t > 65 and 7 or 6
      end
      if go_t > 60 then
        hc = final_score >= hi_score and 10 or 6
        ?"best:  " .. hi_score, 42, ty + 24, hc
      end
      if go_t > 90 and flr(go_t / 8) % 2 == 0 then
        ?"a:retry  b:title", 26, ty + 36, 6
      end
      if win and go_t > 120 then
        ?"by justin smith", 32, ty + 44, 10
      end
    end
  }
end
gameover_state = make_end_state(false)
win_state = make_end_state(true)

level_intro_state = {
  update = function()
    li_t += 1
    update_stars()
    if li_t >= 150 then go_to_game_resume() end
  end,
  draw = function()
    draw_stars()
    ty = 50
    if li_t < 35 then
      ty = -12 + (1 - (1 - li_t / 35) ^ 3) * 62
    end
    wx = li_t < 50 and flr(sin(li_t * 0.07) * 1.5) or 0
    cc = ({ 8, 9, 10, 9 })[flr(li_t * 0.08) % 4 + 1]

    if level > MAX_LEVEL then
      wx2 = flr(sin(li_t * 0.2) * 2)
      ?"warning!", 45 + wx2, ty - 6, 8
      ?"warning!", 44 + wx2, ty - 7, 7
      ?"boss stage", 42 + wx, ty + 4, 1
      ?"boss stage", 41 + wx, ty + 3, cc
    else
      txt = "level " .. level
      ?txt, 45 + wx, ty + 1, 1
      ?txt, 44 + wx, ty, cc
    end
    if li_t > 60 then
      sc = li_t < 70 and 5 or 6
      ?"score: " .. score, 38, ty + 24, sc
    end
    if li_t > 75 then
      rc = li_t < 85 and 5 or (li_t < 95 and 6 or 7)
      ?"ready!", 47, ty + 36, rc
    end
  end
}

function build_shop_pool(pl)
  local pool = {}
  -- Heavy-only: offer shield upgrade once, starting after level 1
  local has_shield = pl.archetype == 3 and pl.shield == nil and level >= 2
  local has_upgrade = pl.weapon_lv < 3

  alts = { "basic", "spread", "plasma", "laser" }
  for _, w in ipairs(alts) do
    skip = w == pl.weapon
        or (w == "spread" and pl.no_spread)
        or (w == "basic" and not pl.no_spread)
    if not skip then
      add(pool, { id = w, sp = WEAPONS[w].w_sp, name = w })
    end
  end
  if pl.hp < pl.max_hp then
    add(pool, { id = "health", sp = 48, name = "repair" })
  end

  -- Shuffle alternative items
  for i = #pool, 2, -1 do
    local j = flr(rnd(i)) + 1
    pool[i], pool[j] = pool[j], pool[i]
  end

  -- Build final list prioritizing upgrade and shield at the very front
  local result = {}
  if has_upgrade then
    add(result, { id = "upgrade", sp = WEAPONS[pl.weapon].w_sp, name = "upg. " .. pl.weapon })
  end
  if has_shield then
    add(result, { id = "shield", sp = 57, name = "shield" })
  end
  for item in all(pool) do
    add(result, item)
  end

  return result
end

function apply_shop_item(item)
  if item.id == "health" then
    p.hp = min(p.hp + 1, p.max_hp)
  elseif item.id == "shield" then
    p.shield = 1
    p.shield_timer = 0
    p.shield_flash_t = 0
  elseif item.id == "upgrade" then
    p.weapon_lv += 1
  else
    p.weapon = item.id
    p.weapon_lv = 1
  end
end

function go_to_shop()
  shop_cursor, shop_t = 1, 0
  local pool = build_shop_pool(p)
  shop_choices = {}
  for i = 1, min(2, #pool) do
    add(shop_choices, pool[i])
  end
  state = shop_state
end

shop_state = {
  update = function()
    update_stars()
    shop_t += 1
    if btnp(0) or btnp(2) then shop_cursor = 1 end
    if btnp(1) or btnp(3) then shop_cursor = #shop_choices end
    if shop_t > 25 then
      if btnp(4) then
        item = shop_choices[shop_cursor]
        if item then
          apply_shop_item(item)
          go_to_level_intro()
        end
      end
      if btnp(5) then go_to_level_intro() end
    end
  end,
  draw = function()
    cls(0)
    draw_stars()
    ?"shop", 54, 4, 7
    for i, item in ipairs(shop_choices) do
      cx = i == 1 and 4 or 68
      col = shop_cursor == i and 7 or 5
      rectfill(cx, 35, cx + 56, 90, 1)
      rect(cx, 35, cx + 56, 90, col)
      if shop_cursor == i then
        rect(cx - 1, 34, cx + 57, 91, 6)
      end
      spr(item.sp, cx + 24, 44)
      ?item.name, cx + 28 - #item.name * 2, 58, 7
      cc = 11
      txt = "free"
      ?txt, cx + 28 - #txt * 2, 68, cc
    end
    if #shop_choices == 0 then
      ?"nothing", 44, 55, 5
      ?"available", 40, 63, 5
    end
    if shop_t > 25 and flr(t() * 2) % 2 == 0 then
      ?"a:buy  b:skip", 32, 100, 6
    end
  end
}

-->8
-- tab 2: player logic

function init_player()
  s = ships[selected_ship]
  p = {
    tag = "player",
    x = 60,
    y = 100,
    vx = 0,
    vy = 0,
    max_speed = s[6],
    sp = s[1],
    sp_l = s[2],
    sp_r = s[3],
    w = 8,
    h = 8,
    hx = 3, hy = 3, hw = 2, hh = 2,
    fire_delay = 0,
    base_fire_delay = s[9],
    flash_t = 0,
    hp = s[5],
    max_hp = s[5],
    iframes = 0,
    max_iframes = 0,
    weapon = s[4],
    weapon_lv = 1,
    no_spread = s[10],
    t_cols = s[11],
    dead = false,
    -- entity update: runs movement/input, or ticks the death timer
    update = function(self)
      if not self.dead then
        update_player(self)
      else
        death_timer -= 1
        if death_timer > 0 and death_timer % 20 == 0 then
          add(entities, make_explosion(self.x + rnd(16) - 8, self.y + rnd(16) - 8))
          shake_screen(2, 6)
        end
        if death_timer <= 0 then go_to_gameover() end
      end
    end,
    -- entity draw: renders ship or death animation
    draw = function(self)
      if self.dead then
        draw_player_death(self)
      else
        draw_player(self)
      end
    end
  }

  -- Inject Archetype Hooks
  p.archetype = selected_ship
  if p.archetype == 1 then
    p.iframe_mod = 20 -- Added to standard iframes on hit
  elseif p.archetype == 2 then
    p.base_fire_delay = 4 -- Hyper-fast firing rate
    p.spray_variance = 0.5 -- Chaotic firing cone accuracy offset
  elseif p.archetype == 3 then
    -- shield starts nil; unlocked via shop after level 1
    p.always_pierce = true -- Forces weaponry to pass through enemies
  end

  -- insert at front so player draws beneath enemies/bullets
  add(entities, p, 1)
end

function update_player(obj)
  local dx, dy = 0, 0

  if btn(0) then dx -= 1 end
  if btn(1) then dx += 1 end
  if btn(2) then dy -= 1 end
  if btn(3) then dy += 1 end

  -- normalise diagonal so speed is equal in all directions
  if dx ~= 0 and dy ~= 0 then
    dx *= 0.707
    dy *= 0.707
  end

  -- focused movement: hold fire for half-speed precision dodging
  local spd = obj.max_speed
  if btn(4) or btn(5) then spd *= 0.5 end

  -- 1:1 direct movement ヌ█⬆️ no inertia, no drift
  obj.vx = dx * spd
  obj.vy = dy * spd

  -- shoot (auto-fire while holding Z)
  if btn(4) and obj.fire_delay <= 0 then
    fire_bullet(obj)
    obj.fire_delay = obj.base_fire_delay
    obj.flash_t = 3
  end
  if obj.fire_delay > 0 then obj.fire_delay -= 1 end
  if obj.flash_t > 0 then obj.flash_t -= 1 end
  if obj.iframes > 0 then obj.iframes -= 1 end

  obj.x += obj.vx
  obj.y += obj.vy

  -- thruster particles: spawn every few frames when moving
  if (dx ~= 0 or dy ~= 0) and tf(60, 2) == 0 then
    burst_thruster(obj.x + 4, obj.y + 8, obj.t_cols, 1)
  end

  -- clamp to playfield ヌ█⬆️ zero velocity on wall hit
  if obj.x < 0 then
    obj.x = 0 obj.vx = 0
  end
  if obj.x > 120 then
    obj.x = 120 obj.vx = 0
  end
  if obj.y < 10 then
    obj.y = 10 obj.vy = 0
  end
  if obj.y > 120 then
    obj.y = 120 obj.vy = 0
  end

  if obj.shield_flash_t and obj.shield_flash_t > 0 then obj.shield_flash_t -= 1 end

  -- Heavy Shield Regeneration Cooldown Loop
  if obj.archetype == 3 and obj.shield == 0 then
    obj.shield_timer += 1
    if obj.shield_timer >= 600 then
      -- 10 seconds at 60fps
      obj.shield = 1
      obj.shield_timer = 0
      sfx(3) -- Play structural charge audio feedback
    end
  end
end

function burst_muzzle(x, y)
  emit_fx(x, y, 2, { cols = { 9, 10, 7 }, ang = 0.25, ang_r = 0.3, spd = 1 + rnd(1.5), life = 8, drag = 0.92, fade = true })
end

function fire_bullet(obj)
  local btype, lv = obj.weapon, obj.weapon_lv
  for _, ox in ipairs(W_OFF[btype][min(lv, 3)]) do
    local b = make_bullet(obj, btype)
    if W_VX[btype] then b.vx = ox else b.x += ox end
    add_e(b, bullets)
  end
  if btype == "laser" then
    shake_screen(lv >= 2 and 2 or 1, lv >= 2 and 6 or 4)
  end
  burst_muzzle(obj.x + 4, obj.y - 2)
  sfx(WEAPONS[btype].sfx)
end

function draw_player(obj)
  s = obj.sp
  dx = 0
  if obj.vx < 0 then
    s = obj.sp_l
    dx = -1
  elseif obj.vx > 0 then
    s = obj.sp_r
    dx = 1
  end

  if obj.iframes > 0 then
    ni = obj.iframes / max(1, obj.max_iframes)
    -- quadratic ease-in: slow blink at start, fast blink near end
    period = max(2, flr(ni * ni * 12) + 2)
    if (obj.iframes % period) < flr(period / 2) then
      return
    end
  end

  draw_thruster(obj, dx)
  spr(s, obj.x, obj.y)

  -- visible hitbox core when focused (bullet hell convention)
  if btn(4) or btn(5) then
    local cx = obj.x + 4
    local cy = obj.y + 4
    local pulse = flr(t()*8)%2==0 and 10 or 7
    pset(cx, cy, pulse)
    pset(cx-1, cy, 6)
    pset(cx+1, cy, 6)
    pset(cx, cy-1, 6)
    pset(cx, cy+1, 6)
  end

  if obj.flash_t > 0 then
    draw_muzzle_flash(obj, dx)
  end

  -- Render Heavy Shield Aura Bubble (only once upgrade is unlocked)
  if obj.archetype == 3 and obj.shield and obj.shield > 0 then
    -- Pulsates slightly using time functions
    local rad = 6 + flr(sin(t() * 3) * 1.5)
    circ(obj.x + 3 + dx, obj.y + 4, rad, 12) -- Left half sub-pixel composite
    circ(obj.x + 4 + dx, obj.y + 4, rad, 12) -- Right half sub-pixel composite
  elseif obj.archetype == 3 and obj.shield_flash_t and obj.shield_flash_t > 0 then
    spr(30, obj.x + dx, obj.y)
  end
end

function draw_thruster(obj, dx)
  spd = sqrt(obj.vx * obj.vx + obj.vy * obj.vy)
  t16 = flr(t() * 16)
  fh = 4 + flr(spd * 4) + t16 % 2
  fn = t16 % 4

  -- swap colors for unique thruster look
  pal(8, obj.t_cols[1])
  pal(9, obj.t_cols[2])
  pal(10, obj.t_cols[3])

  sspr(80 + fn * 8, 0, 8, 8, obj.x + dx, obj.y + 8, 8, fh)

  -- reset palette
  pal()
end

function draw_muzzle_flash(obj, dx)
  m_sp = WEAPONS[obj.weapon].muz

  flip_x = obj.flash_t % 2 == 0
  offset_y = flr(rnd(2))
  spr(m_sp, obj.x + dx, obj.y - 6 + offset_y, 1, 1, flip_x)
end

function draw_player_death(obj)
  if death_timer <= 0 then return end
  prog = 1 - death_timer / 120
  sep = flr(prog * prog * 18)
  twist = flr(sin(prog * 2.5) * sep * 0.4)
  hot = ({ 9, 10, 9, 8, 7 })[tf(14, 5) + 1]
  for c = 0, 15 do
    pal(c, hot)
  end
  local sx = (obj.sp % 16) * 8
  local sy = flr(obj.sp / 16) * 8
  -- top half drifts up + twists
  sspr(sx, sy, 8, 4, obj.x - twist, obj.y - sep, 8, 4)
  -- bottom half drifts down + twists opposite
  sspr(sx, sy + 4, 8, 4, obj.x + twist, obj.y + 4 + flr(sep * 0.5), 8, 4)
  pal()
end

function damage_player(frames)
  -- Heavy Shield Block Interception (only when upgrade is active)
  if p.archetype == 3 and p.shield and p.shield > 0 then
    p.shield = 0
    p.shield_timer = 0
    p.iframes = frames -- Grant standard hit invulnerability duration
    p.max_iframes = frames
    p.shield_flash_t = 15
    sfx(3) -- Play distinct impact audio
    burst_sparks(p.x + 4, p.y + 4, 12, PLASMA_C) -- Visual energy ring pop
    return
  end

  -- Standard Damage Path
  p.hp -= 1
  -- Balanced Ship Extended Iframe Buff
  p.iframes = frames + (p.iframe_mod or 0)
  p.max_iframes = frames + (p.iframe_mod or 0)

  if p.hp <= 0 then player_death() end
end

function player_death()
  p.dead = true
  final_score = score
  death_timer = 120
  death_flash_t = 15
  shake_screen(8, 50)
  local cx, cy = p.x + 4, p.y + 4
  add(entities, make_explosion(cx, cy, true))
  add(entities, make_shockwave(cx, cy, true))
  for i = 1, 3 do
    add(entities, make_explosion(cx + rnd(20) - 10, cy + rnd(20) - 10))
  end
  burst_sparks(cx, cy, 24, SPARK_C)
  burst_smoke(cx, cy, 14, SMOKE_C)
  burst_embers(cx, cy, 10)
  sfx(2)
  hit_stop_t = 3
end

-->8
-- tab 3: entities
-- boss hp-bar color per stage (1=cyan,2=orange,3=red)
BPHC = {11, 9, 8}

-- base entity constructor: creates a table with shared fields
-- and default update/draw stubs that call self:move() / self:render().
-- specialized constructors call this, then override what they need.
function make_ent(tag, x, y)
  return {
    tag = tag, x = x, y = y, dead = false,
    -- Just check if they exist before calling
    update = function(s) if s.move then s:move() end end,
    draw = function(s) if s.render then s:render() end end
  }
end

function move_zigzag(e)
  e.phase = (e.phase + 0.008) % 1
  e.x = mid(0, e.ox + 30 * sin(e.phase), 120)
end

-- shared lifetime tick: increment h, mark dead when expired.
-- used by particles/explosions/shockwaves; pattern matches their h/max_h fields.
function tick_life(s)
  s.h += 1
  if s.h > s.max_h then s.dead = true end
end

-- spawn one enemy bullet from boss center with given velocity
function boss_shoot_one(e, vx, vy)
  local eb = make_enemy_bullet(e, 1)
  eb.x = e.x + 6
  eb.y = e.y + 6
  eb.vx = vx
  eb.vy = vy
  add_e(eb, ebullets)
end

-- shared aimed fan: n bullets, angular spread, speed; centered on aim vector
function boss_aimed_fan(e, n, spread, spd)
  local bx = (p.x + 4) - (e.x + 8)
  local by = (p.y + 4) - (e.y + 8)
  local d = sqrt(bx * bx + by * by)
  if d == 0 then d = 1 end
  bx = bx / d * spd
  by = by / d * spd
  local half = (n - 1) / 2
  for i = 0, n - 1 do
    local off = (i - half) * spread
    local cs = cos(off)
    local sn = sin(off)
    boss_shoot_one(e, bx * cs - by * sn, bx * sn + by * cs)
  end
end

-- boss fire patterns indexed by combat_phase
-- [1] sweeper: telegraphed 5-bullet aimed fan
-- [2] spiral: rotating dual-stream
-- [3] storm: round-robin ring / fan / counter-spiral
boss_fire = {
  function(e)
    boss_aimed_fan(e, 5, 0.06, 1.1)
    e.shoot_t = 70
  end,
  function(e)
    local spd = 1.3
    e.spiral_a = (e.spiral_a or 0) + 0.025
    boss_shoot_one(e, cos(e.spiral_a) * spd, sin(e.spiral_a) * spd)
    boss_shoot_one(e, cos(e.spiral_a + 0.5) * spd, sin(e.spiral_a + 0.5) * spd)
    e.shoot_t = 14
  end,
  function(e)
    e.fire_count = (e.fire_count or 0) + 1
    local m = e.fire_count % 3
    if m == 1 then
      for i = 0, 13 do
        local a = i / 14
        boss_shoot_one(e, cos(a) * 1.2, sin(a) * 1.2)
      end
    elseif m == 2 then
      boss_aimed_fan(e, 7, 0.07, 1.6)
    else
      e.spiral_a = (e.spiral_a or 0) + 0.03
      for i = 0, 3 do
        local a = e.spiral_a + i * 0.25
        boss_shoot_one(e, cos(a) * 1.3, sin(a) * 1.3)
        boss_shoot_one(e, cos(-a) * 1.3, sin(-a) * 1.3)
      end
    end
    e.shoot_t = 32
  end
}

function apply_pal(c3, c11, c12, c7, c6)
  pal(3, c3)
  pal(11, c11)
  pal(12, c12)
  pal(7, c7)
  pal(6, c6)
end

function draw_flash(e)
  if e.flash and e.flash > 0 then
    for c = 0, 15 do
      pal(c, 7)
    end
    spr(e.sp + tf(4, 2), e.x, e.y)
    pal()
    e.flash -= 1
  end
end

enemy_types = {
  basic = {
    sp = S_ENEMY, pts = 10,
    mk_x = function() return rnd(120) end,
    mk_vy = function() return 1 + rnd(1) end
  },
  zigzag = {
    sp = S_ENEMY2, pts = 25, move = move_zigzag,
    mk_x = function() return 30 + rnd(60) end,
    mk_vy = function() return 0.8 + rnd(0.4) end,
    extra = function(e) e.hp = 2 e.ox = e.x e.phase = rnd(1) end
  },
  -- steers toward the player horizontally
  -- purple/indigo palette: eerie, alien
  chaser = {
    sp = S_ENEMY2, pts = 30,
    move = function(e)
      local dx = p.x - e.x
      e.x += dx * 0.025
      e.x = mid(0, e.x, 120)
      e.shoot_t -= 1
      if e.shoot_t <= 0 then
        e.shoot_t = 70
        local eb = make_enemy_bullet(e, 0.9)
        add_e(eb, ebullets)
        sfx(7)
      end
    end,
    mk_x = function() return rnd(120) end,
    mk_vy = function() return 0.6 + rnd(0.4) end,
    extra = function(e) e.hp = 2 e.shoot_t = 50 end,
    draw_fn = function(en)
      apply_pal(2, 14, 13, 14, 13)
      spr(S_ENEMY2 + tf(4, 2), en.x, en.y)
      pal()
    end
  },
  -- slow-moving enemy that fires aimed shots
  -- toxic green palette, pulses white when about to fire
  shooter = {
    sp = S_ENEMY, pts = 40,
    move = function(e)
      e.shoot_t -= 1
      if e.shoot_t <= 0 then
        e.shoot_t = 55
        -- 3-bullet aimed fan for bullet-hell density
        for i = -1, 1 do
          local eb = make_enemy_bullet(e, 1.2)
          eb.vx += i * 0.35
          add_e(eb, ebullets)
        end
        sfx(7)
      end
    end,
    mk_x = function() return 10 + rnd(100) end,
    mk_vy = function() return 0.4 + rnd(0.3) end,
    extra = function(e) e.hp = 3 e.shoot_t = 40 end,
    draw_fn = function(en)
      local charging = en.shoot_t < 18
      if charging then
        local f = tf(12, 2) == 0
        apply_pal(f and 7 or 10, f and 7 or 10, 10, 7, 10)
      else
        apply_pal(3, 10, 11, 10, 11)
      end
      spr(S_ENEMY + tf(4, 2), en.x, en.y)
      pal()
      -- charge ring glows outward when near firing
      if charging then
        local r = 3 + flr(sin(t() * 6) * 1.5)
        circ(en.x + 4, en.y + 4, r, 10)
      end
    end
  },
  tank = {
    sp = S_ENEMY3, pts = 50,
    move = function(e)
      e.shoot_t -= 1
      if e.shoot_t <= 0 then
        e.shoot_t = 90
        -- slow radial burst: 5 bullets in a ring
        for i = 0, 4 do
          local a = i / 5
          local eb = make_enemy_bullet(e, 0.8)
          eb.vx = cos(a) * 0.8
          eb.vy = sin(a) * 0.8
          add_e(eb, ebullets)
        end
        sfx(7)
      end
    end,
    mk_x = function() return 20 + rnd(80) end,
    mk_vy = function() return 0.3 + rnd(0.2) end,
    extra = function(e) e.hp = 7 e.shoot_t = 60 end,
    draw_fn = function(en)
      spr(S_ENEMY3 + tf(4, 2), en.x, en.y)
    end
  },
  spinner = {
    sp = S_ENEMY4, pts = 40, move = function(e)
      move_zigzag(e)
      e.shoot_t -= 1
      if e.shoot_t <= 0 then
        e.shoot_t = 50
        -- fires 2 bullets at its current zigzag angle
        for i = -1, 1, 2 do
          local eb = make_enemy_bullet(e, 1.0)
          local a = e.phase + i * 0.05
          eb.vx = cos(a) * 1.0
          eb.vy = sin(a) * 1.0
          add_e(eb, ebullets)
        end
        sfx(7)
      end
    end,
    mk_x = function() return rnd(120) end,
    mk_vy = function() return 1 + rnd(0.5) end,
    extra = function(e) e.hp = 2 e.ox = e.x e.phase = rnd(1) e.shoot_t = 35 end,
    draw_fn = function(en)
      spr(S_ENEMY4 + tf(16, 2), en.x, en.y)
    end
  },

  boss = {
    sp = 64, pts = 500,
    mk_x = function() return 56 end,
    mk_vy = function() return 0.2 end,
    extra = function(e)
      e.hp = 150
      e.max_hp = 150
      e.is_boss = true
      -- 16x16 sprite (sheet 0,32 idle / 16,32 attack), tight hitbox
      e.w = 16
      e.h = 16
      e.hx = 2
      e.hy = 2
      e.hw = 12
      e.hh = 12
      -- upper-center anchor, Lissajous drift
      e.cx_anchor = 56
      e.cy_anchor = 30
      e.t = 0
      e.attack_t = 0
      e.combat_phase = 1
      e.shoot_t = 60
      boss_ent = e
    end,
    move = function(e)
      -- stage transitions: shake, flash, clear bullets, brief pause
      if e.combat_phase < 2 and e.hp <= 100 then
        e.combat_phase = 2
        shake_screen(4, 15)
        e.flash = 8
        for eb in all(ebullets) do eb.dead = true end
        hit_stop_t = 6
        e.shoot_t = 30
      end
      if e.combat_phase < 3 and e.hp <= 50 then
        e.combat_phase = 3
        shake_screen(6, 20)
        e.flash = 8
        for eb in all(ebullets) do eb.dead = true end
        hit_stop_t = 6
        e.shoot_t = 30
      end
      -- descend to anchor, then slow Lissajous around upper-center
      if e.vy > 0 then
        if e.y >= e.cy_anchor then
          e.y = e.cy_anchor
          e.vy = 0
        end
      else
        e.t += 1
        e.x = e.cx_anchor + sin(e.t * 0.003) * 24
        e.y = e.cy_anchor + sin(e.t * 0.0045) * 8
      end
      -- attack pose timer
      if e.attack_t > 0 then e.attack_t -= 1 end
      -- fire: dispatch by phase (each pattern sets its own shoot_t cooldown)
      e.shoot_t -= 1
      if e.shoot_t <= 0 then
        boss_fire[e.combat_phase](e)
        sfx(7)
        e.attack_t = 10
      end
    end,
    draw_fn = function(en)
      -- handle flash here: draw_flash() uses 8x8 spr, wrong for 16x16 boss
      local do_flash = en.flash and en.flash > 0
      local cx, cy = en.x + 8, en.y + 8
      -- aura drawn first so the sprite sits on top
      if not do_flash then
        if en.combat_phase == 1 then
          -- calm cyan halo
          circ(cx, cy, 11 + flr(sin(t()) * 1.5), 12)
        elseif en.combat_phase == 3 then
          -- inferno red pulse
          circ(cx, cy, 11 + flr(sin(t() * 4) * 2), 8)
        end
      end
      -- palette swaps per phase: shift body colors to phase signature
      if do_flash then
        for c = 0, 15 do
          pal(c, 7)
        end
        en.flash -= 1
      elseif en.combat_phase == 3 then
        -- raging red: green outline + pink/blue body → red, white-hot flicker
        pal(11, 8) pal(14, 8) pal(12, 8) pal(3, 2)
        if tf(10, 2) == 0 then pal(8, 7) end
      elseif en.combat_phase == 2 then
        -- agitated orange: green/pink/blue → orange/yellow
        pal(11, 9) pal(14, 9) pal(12, 10)
      end
      -- sprite x on sheet: idle (0,32) when calm, attack (16,32) when firing
      local sx = (en.attack_t > 0) and 16 or 0
      sspr(sx, 32, 16, 16, en.x, en.y)
      pal()
    end
  }
}

function load_wave(ws)
  spawn_queue = {}
  local delay = 0
  for e in all(split(ws)) do
    local s = split(e, ":")
    add(spawn_queue, { t = s[1], x = tonum(s[2]), d = delay })
    delay += 30
  end
end

function trigger_spawn(t, x)
  spawn_enemy(t, x)
end

function make_bullet(obj, btype)
  local w = WEAPONS[btype]
  local s = w.b_sp
  local v = w.v
  local dmg = w.dmg
  local e = make_ent("bullet", obj.x, obj.y - 4)
  e.sp = s
  e.vy = v
  e.vx = 0
  e.w = 8
  e.h = 8
  e.hx = 2
  e.hw = 4
  e.btype = btype
  e.dmg = dmg
  e.hp_left = dmg
  e.pierce = btype == "laser"
  -- move: fly upward, apply vx spread, trail particles, expire when off-screen
  e.move = function(self)
    self.x += self.vx
    self.y += self.vy
    if self.btype == "plasma" and flr(self.y) % 2 == 0 then
      add(
        entities, make_particle(
          self.x + 3, self.y + 4, {
            cols = { 12, 13, 7 }, ang = 0.75, ang_r = 0.1,
            spd = 0.5 + rnd(0.5), life = 6, fade = true
          }
        )
      )
    elseif self.btype == "laser" and flr(self.y) % 2 == 0 then
      add(
        entities, make_particle(
          self.x + 3, self.y + 4, {
            cols = { 7, 10, 9 }, ang = 0.75, ang_r = 0.1,
            spd = 1 + rnd(0.5), life = 8, fade = true, trail = true
          }
        )
      )
    end
    if self.y < -8 then self.dead = true end
  end
  if btype == "plasma" then
    e.render = function(self)
      local cx = self.x + 4
      local cy = self.y + 4
      local r = 2 + tf(12, 2)
      circfill(cx, cy, r, 12)
      circfill(cx, cy, 1, 13)
      pset(cx, cy, 7)
    end
  elseif btype == "spread" then
    e.render = function(self)
      pset(self.x + 3, self.y, 7)
      pset(self.x + 4, self.y, 7)
      pset(self.x + 3, self.y + 1, 10)
      pset(self.x + 4, self.y + 1, 10)
      pset(self.x + 3, self.y + 2, 9)
      pset(self.x + 4, self.y + 2, 9)
      pset(self.x + 3, self.y + 3, 8)
      pset(self.x + 4, self.y + 3, 8)
    end
  else
    e.render = function(self)
      spr(self.sp + tf(12, 2), self.x, self.y)
    end
  end

  -- Apply Archetype Weapon Modifications
  if obj.tag == "player" then
    -- Inject Assault ship firing spread inaccuracy
    if obj.spray_variance then
      e.vx += rnd(obj.spray_variance) - (obj.spray_variance * 0.5)
    end
    -- Inject Heavy ship persistent ammunition piercing traits
    if obj.always_pierce then
      e.pierce = true
      e.hp_left = dmg + 1 -- Allows baseline projectiles to slide through multiple small targets
    end
  end

  return e
end

-- enemy bullet aimed toward the player at time of firing
-- spd param allows per-enemy/phase speed variation
function make_enemy_bullet(src, spd)
  local dx = (p.x + 4) - (src.x + 4)
  local dy = (p.y + 4) - (src.y + 4)
  local d = sqrt(dx * dx + dy * dy)
  if d == 0 then d = 1 end
  spd = spd or 1.4
  local e = make_ent("ebullet", src.x + 1, src.y + 8)
  e.vx = (dx / d) * spd
  e.vy = (dy / d) * spd
  e.w = 6
  e.h = 6
  e.hx = 1
  e.hy = 1
  e.hw = 4
  e.hh = 4
  -- move: travel in aimed direction, leave bright trail, expire when off-screen
  e.move = function(self)
    self.x += self.vx
    self.y += self.vy
    add(
      entities, make_particle(
        self.x + 2, self.y + 2, {
          cols = { 10, 9, 8 }, ang = 0.75, ang_r = 0.25,
          spd = 0.6, life = 8, fade = true
        }
      )
    )
    if self.y > 136 or self.y < -16
        or self.x < -16 or self.x > 144 then
      self.dead = true
    end
  end
  -- render: bright 3x3 cross with hot-white core
  e.render = function(self)
    local cx = self.x + 2
    local cy = self.y + 2
    -- outer arms (orange)
    pset(cx, cy - 2, 9)
    pset(cx, cy + 2, 9)
    pset(cx - 2, cy, 9)
    pset(cx + 2, cy, 9)
    -- inner ring (yellow)
    pset(cx, cy - 1, 10)
    pset(cx, cy + 1, 10)
    pset(cx - 1, cy, 10)
    pset(cx + 1, cy, 10)
    -- hot white core
    pset(cx, cy, 7)
  end
  return e
end

function spawn_enemy(type_name, ox)
  local td = enemy_types[type_name]
  local dfn = td.draw_fn
  local e = make_ent("enemy", (ox and ox > 0) and ox or td.mk_x(), -8)
  e.sp = td.sp
  e.vy = td.mk_vy()
  e.w = 8
  e.h = 8
  e.pts = td.pts
  -- move: scroll down + run the type-specific steering function.
  -- td.move (e.g. move_zigzag, move_chase) is called as a plain
  -- function here because it was authored for the old dot style.
  e.move = function(self)
    self.y += self.vy
    if td.move then td.move(self) end
    if self.y > 128 then self.y = -8 end
  end
  -- render: use the type's custom draw_fn if present, else
  -- fall back to the animated sprite default.
  e.render = function(self)
    if dfn then
      dfn(self)
    else
      spr(self.sp + tf(4, 2), self.x, self.y)
    end
    draw_flash(self)
  end
  if td.extra then td.extra(e) end
  add(entities, e)
  add(enemies, e)
end

function make_explosion(x, y, big)
  local sc, cx, cy, nc, mh, rb, rr, t1, t2 = big and 1.5 or 1, big and x or x + 4, big and y or y + 4, big and 30 or 12, big and 16 or 10, big and 10 or 5, big and 4 or 3, big and 0.2 or 0.3, big and 0.5 or 0.6
  for i = 1, nc do
    local p = make_ent("particle", cx, cy)
    local mult = (3 + rnd(4)) * sc
    p.sx = (rnd(1) - 0.5) * mult
    p.sy = (rnd(1) - 0.5) * mult
    p.h = 0
    p.max_h = (10 + rnd(20)) * sc
    p.r = 1 + rnd(3)
    p.move = function(self)
      self.x += self.sx
      self.y += self.sy
      self.sx *= 0.9
      self.sy *= 0.9
      tick_life(self)
    end
    p.render = function(self)
      local f = self.h / self.max_h
      local c = 7
      if f > 0.2 then c = 10 end
      if f > 0.5 then c = 9 end
      if f > 0.8 then c = 5 end
      local curr_r = self.r * (1 - f)
      if curr_r > 0 then
        circfill(self.x, self.y, curr_r, c)
      end
    end
    add(entities, p)
  end
  local e = make_ent("explosion", cx, cy)
  e.h = 0
  e.max_h = mh
  e.r = rb + rnd(rr)
  e.move = tick_life
  e.render = function(self)
    local f = self.h / self.max_h
    local c = 7
    if f > t1 then c = 10 end
    if f > t2 then c = 9 end
    local curr_r = self.r * (1 - f)
    if curr_r > 0 then
      circfill(self.x, self.y, curr_r, c)
    end
  end
  return e
end

function make_shockwave(x, y, big)
  local e = make_ent("shockwave", x, y)
  e.h = 0
  e.max_h = big and 22 or 16
  e.max_r = big and 28 or 18
  e.move = tick_life
  e.render = function(self)
    local f = self.h / self.max_h
    local r = flr(self.max_r * f)
    local c = 7
    if f > 0.3 then c = 10 end
    if f > 0.6 then c = 9 end
    if f > 0.85 then c = 4 end
    if r > 0 then
      circ(self.x, self.y, r, c)
      if f < 0.5 and r > 1 then
        circ(self.x, self.y, r - 1, c)
      end
    end
  end
  return e
end

function make_hit_flash(x, y)
  local e = make_ent("fx", x, y)
  e.t = 4
  e.move = function(self)
    self.t -= 1
    if self.t <= 0 then self.dead = true end
  end
  e.render = function(self)
    local c = self.t > 2 and 7 or 10
    rectfill(self.x - 2, self.y - 2, self.x + 2, self.y + 2, c)
  end
  return e
end

function make_popup(x, y, pts)
  local e = make_ent("popup", x, y)
  e.t = 20
  e.pts = pts
  e.move = function(self)
    self.y -= self.t * 0.05
    self.t -= 1
    if self.t <= 0 then self.dead = true end
  end
  e.render = function(self)
    local c = self.t > 13 and 7 or (self.t > 6 and 6 or 5)
    local str = type(self.pts) == "number" and ("+" .. self.pts) or self.pts
    ?str, self.x, self.y, c
  end
  return e
end




function make_particle(x, y, opts)
  opts = opts or {}
  -- resolve options with defaults
  local cols = opts.cols or { 7 }
  local col = cols[flr(rnd(#cols)) + 1]
  local ang = opts.ang or rnd(1)
  local ar = opts.ang_r or 1
  local spd = opts.spd or 1 + rnd(2)
  local life = opts.life or 20 + rnd(20)
  local grav = opts.grav or 0
  local drag = opts.drag or 0.98
  local fade = opts.fade ~= false
  -- default true
  local size = opts.size or 1
  local trail = opts.trail or false

  -- arc spread: ar=1 ヌ●★ fully random; ar=0 ヌ●★ exact angle
  local a = ang + (rnd(ar) - ar * 0.5)

  local e = make_ent("particle", x, y)
  e.vx = cos(a) * spd
  e.vy = sin(a) * spd
  e.life = life
  e.ml = life
  e.col = col

  e.move = function(self)
    self.x += self.vx
    self.y += self.vy
    self.vy += grav
    self.vx *= drag
    self.vy *= drag
    self.life -= 1
    if self.life <= 0 then self.dead = true end
  end

  e.render = function(self)
    local f = self.life / self.ml
    -- 1->0 as particle ages
    -- colour fade: bright -> mid -> dark
    local c = self.col
    if fade then
      if f < 0.2 then
        c = 1
      elseif f < 0.4 then
        c = 5
      end
    end
    -- draw trail behind motion vector
    if trail and f > 0.4 then
      pset(
        self.x - self.vx * 0.5,
        self.y - self.vy * 0.5, 1
      )
    end
    -- draw body
    if size == 2 then
      rectfill(self.x, self.y, self.x + 1, self.y + 1, c)
    elseif size == 1 then
      pset(self.x, self.y, c)
    end
  end

  return e
end

-- ============================================================
-- burst helpers -- call these at an event site, they spawn
-- several particles and add them to entities automatically.
-- ============================================================

function emit_fx(x, y, n, p_opts)
  for i = 1, n do
    add(entities, make_particle(x, y, p_opts))
  end
end

-- spark burst: sharp bright sparks flying outward
-- use for: bullet impact, ship hit, explosion accent
function burst_sparks(x, y, n, cols)
  emit_fx(x, y, n or 6, { cols = cols or SPARK_C, spd = 1.5 + rnd(2.5), life = 10 + rnd(12), grav = 0.04, drag = 0.94, trail = true })
end

-- smoke puff: slow, heavy, fades dark -- use for: enemy death,
-- engine exhaust, big explosions
function burst_smoke(x, y, n, cols)
  emit_fx(x, y, n or 5, { cols = cols or SMOKE_C, spd = 0.2 + rnd(0.6), life = 25 + rnd(20), grav = -0.01, drag = 0.96, fade = true, size = 2 })
end

-- slow hot embers drifting upward -- use for: explosion aftermath
function burst_embers(x, y, n)
  emit_fx(x, y, n or 5, { cols = EMBER_C, ang = 0.25, ang_r = 0.35, spd = 0.2 + rnd(0.7), life = 35 + rnd(30), grav = -0.015, drag = 0.97, fade = true, size = 1 })
end

-- thruster glow: tight upward cone -- use for: player/enemy
-- engines, boost pickups
-- dir: 1=upward (player), -1=downward (enemy)
function burst_thruster(x, y, cols, dir)
  local base_ang = (dir or 1) == 1 and 0.25 or 0.75
  emit_fx(x, y, 2, { cols = cols or EMBER_C, ang = base_ang, ang_r = 0.12, spd = 0.8 + rnd(1.2), life = 6 + rnd(8), drag = 0.9, fade = true })
end

function kill_enemy(en)
  sfx(1)
  add(entities, make_explosion(en.x, en.y))
  add(entities, make_shockwave(en.x + 4, en.y + 4))
  add(entities, make_popup(en.x, en.y, en.pts))
  burst_sparks(en.x + 4, en.y + 4, 8, SPARK_C)
  burst_smoke(en.x + 4, en.y + 4, 7)
  burst_embers(en.x + 4, en.y + 4, 5)
  en.dead = true
  if en.is_boss then
    boss_ent = nil
    hit_stop_t = 3
    go_to_win()
    return true
  end

  score += en.pts
  if level <= MAX_LEVEL then
    level_kills += 1
  end
  shake_screen(2, 8)
end

-- optimized collision: uses typed sub-lists so we only check
-- bulletsれ❎enemies (layer filtering) instead of entitiesれ❎entities.
function check_collisions()
  -- 1. player bullets vs enemies
  for en in all(enemies) do
    if not en.dead then
      local ecx, ecy = en.x + 4, en.y + 4
      for b in all(bullets) do
        if not b.dead and collide(en, b) then
          local dmg = b.dmg or 1
          if not b.pierce then b.dead = true end
          if en.hp and en.hp > dmg then
            en.hp -= dmg
            if b.pierce then
              b.hp_left -= dmg
              if b.hp_left <= 0 then b.dead = true end
            end
            en.flash = 3
            sfx(8)
            burst_sparks(ecx, ecy, 3, SPARK_C)
            add(entities, make_hit_flash(ecx, ecy))
            -- hit-stop reserved for phase transitions & kills only
          else
            if b.pierce then
              b.hp_left -= (en.hp or 1)
              if b.hp_left <= 0 then b.dead = true end
            end
            add(entities, make_hit_flash(ecx, ecy))
            if kill_enemy(en) then return end
          end
        end
      end
      -- 2. enemy body vs player (no iframes needed on enemy bullets)
      if p.iframes <= 0 and collide(p, en) then
        sfx(2)
        add(entities, make_explosion(en.x, en.y))
        add(entities, make_shockwave(ecx, ecy))
        add(entities, make_hit_flash(ecx, ecy))
        burst_sparks(ecx, ecy, 6, { 8, 9, 7 })
        if not en.is_boss then
          en.dead = true
        end
        damage_player(60)
        shake_screen(3, 12)
        hit_flash_t = 8
        hit_stop_t = 3
      end
    end
  end
  -- 3. enemy bullets vs player
  for eb in all(ebullets) do
    if not eb.dead then
      if p.iframes <= 0 and collide(p, eb) then
        eb.dead = true
        damage_player(50)
        shake_screen(2, 8)
        hit_flash_t = 6
        hit_stop_t = 2
        burst_sparks(p.x+4, p.y+4, 8, {8,9,10})
        sfx(2)
      -- graze: near-miss detection (wider 6れ❎6 zone vs 2れ❎2 hitbox)
      elseif not eb.grazed then
        local gx, gy = p.x+1, p.y+1
        local bx, by = eb.x+(eb.hx or 0), eb.y+(eb.hy or 0)
        local bw, bh = eb.hw or eb.w, eb.hh or eb.h
        if not (gx >= bx+bw or gx+6 <= bx or gy >= by+bh or gy+6 <= by) then
          eb.grazed = true
          score += 1
          add(entities, make_particle(p.x+4, p.y+4, {
            cols={7,12}, spd=0.5, life=5, fade=true
          }))
        end
      end
    end
  end
end

-->8
-- tab 4: starfield

function init_stars()
  stars = {}
  for i = 1, 20 do
    local r = rnd(1)
    local spd, col
    if r > 0.9 then
      spd, col = 1.2 + rnd(0.5), 7
    elseif r > 0.6 then
      spd, col = 0.6 + rnd(0.4), 6
    else
      spd, col = 0.2 + rnd(0.3), 5
    end
    add(
      stars, {
        x = rnd(128), y = rnd(128), speed = spd, col = col,
        update = function(s)
          s.y += s.speed
          if s.y > 128 then
            s.y = 0
            s.x = rnd(128)
          end
        end,
        draw = function(s) pset(s.x, s.y, s.col) end
      }
    )
  end
end

function update_stars()
  for s in all(stars) do
    s.update(s)
  end
end

function draw_stars()
  for s in all(stars) do
    s.draw(s)
  end
end

-->8
-- tab 5: system / hud

function shake_screen(mag, dur)
  shake_t = dur or mag * 4
  shake_mag = mag
end

-- returns true when AABB boxes a and b overlap
-- entities may carry hx/hy/hw/hh for a centered sub-hitbox
function collide(a, b)
  local ax, ay = a.x + (a.hx or 0), a.y + (a.hy or 0)
  local aw, ah = a.hw or a.w, a.hh or a.h
  local bx, by = b.x + (b.hx or 0), b.y + (b.hy or 0)
  local bw, bh = b.hw or b.w, b.hh or b.h
  return not (ax >= bx + bw
        or ax + aw <= bx
        or ay >= by + bh
        or ay + ah <= by)
end

function draw_hud()
  rectfill(0, 0, 127, 9, 0)
  ?"score:" .. score, 2, 2, 7
  lvl_str = "lvl:" .. level .. "/" .. MAX_LEVEL
  ?lvl_str, 64 - (#lvl_str * 2), 2, 6
  h_width = p.max_hp * 9
  start_x = 127 - h_width
  for i = 1, p.max_hp do
    spr(i <= p.hp and 14 or 15, start_x + (i - 1) * 9, 1)
  end

  -- Heavy Archetype Shield Gauge Rendering (only once upgrade is unlocked)
  if p.archetype == 3 and p.shield ~= nil then
    if p.shield > 0 then
      -- Draw an active blue status marker
      circfill(start_x - 8, 4, 2, 12)
    else
      -- Draw a filling indicator line representing recharge rate
      local progress = flr((p.shield_timer / 600) * 8)
      rectfill(start_x - 12, 3, start_x - 12 + progress, 5, 8)
    end
  end

  -- boss health bar
  if boss_ent and not boss_ent.dead then
    pct = boss_ent.hp / boss_ent.max_hp
    bc = BPHC[boss_ent.combat_phase]
    ?"boss", 10, 115, bc
    rect(10, 122, 118, 126, 5)
    rectfill(10, 122, 10 + flr(pct * 108), 126, bc)
  end
end

function apply_shake()
  if shake_t > 0 then
    camera(rnd(shake_mag * 2) - shake_mag, rnd(shake_mag * 2) - shake_mag)
  else
    camera()
  end
end

function draw_hit_flash()
  if death_flash_t > 0 then
    local c = death_flash_t > 10 and 7 or (death_flash_t > 5 and 10 or 9)
    rectfill(0, 0, 127, 127, c)
  elseif hit_flash_t > 0 then
    rect(0, 0, 127, 127, 8)
  end
end

__gfx__
000000000008800000e00e0000566500088000000080000000565000000008800000800000056500088008800080080000800800008008000880088008800880
000000000087780000e00e000567765008780000008e00000556600000008780000e800000066550899889980898898000899800089889808888888880088008
00000000008cc80000e88e00056cc65008c80000008e00000556600000008c80000e80000006655089aa9aa8089aa980008aa800089aa9808888888880000008
00000000058cc8500e8888e00056650052c850000278e0000056500000058c2500e872000005650008aaaa80089aa980008aa800008aa8008888888880000008
000000005881188508877880000660005218550002c8e000000600000055812500e8c20000006000008aa800008aa80000899800008998000888888008000080
0000000058588585888cc888006556000585250008c8e000005560000052525000e8c80000065500000880000008800000088000000880000088880000800800
000000000055550088800888056cc6500055000088588e0005556000000055000e88588000065550000000000008800000088000000000000008800000088000
00000000007007005500005505c00c50077000005605650005cc660000000770057507500066cc50000000000000000000088000000000000000000000000000
00000000000000000000000000080000000800000000000000000000000b00000030300000000000009a0a900500005000000000000000000000000000000000
0000000000088000000990000089800000898000001cc10000111100000b0000003b30000007700009a77a905006600500000000000000000000000000000000
000000000082280000822800089a98000897980001cddc10011cc110003b3000003b3000007aa7009a7887a90060060000000000000000000000000000000000
000a00000828e2800927a29008a7a800087778000cddddc001cccc10003b3000000b0000007aa700a787787a0600006000073000000b70000000000000000000
009aa9000828828009277290009a9000009790000cddddc001cccc10003b3000000b000000077000a787787a060000600076b300003b67000000000000000000
008aa8000082280000822800008980000089800001cddc10011cc110003b3000003b3000000000009a7887a90060060000b6b300003b6b000000000000000000
0089980000088000000990000008000000080000001cc10000111100000b0000003b30000000000009a77a90500660050033b300003b63000000000000000000
00088000000000000000000000000000000000000000000000000000000b00000030300000000000009aa9000500005000033000000330000000000000000000
005333000053330000000000000000000530033005000030000e0000000000002004400240044004a004400aa004400a00000000000000000000000000000000
053b3330053b3330055555500555555053b33b335b3003b3002e20000e000e00042222400a2222a0042442400024420000000000000000000000000000000000
33bbbb3333bbbb3355655655565555653bbbbbb33bbb3bb302222200002220000242242002422420024224200242242000000000000000000000000000000000
3b8287b33be828b355555555555555553bb67bb33bb67bb3e22622e00226220042266224422662244428a2444428a24400000000000000000000000000000000
3bb33b333bb33b33666666666666666603671730036177300222220000222000422662244226622444268244442a824400000000000000000000000000000000
033333300333333058855885058888500371173033711733002e20000e000e000242242002422420024224200242242000000000000000000000000000000000
00b00300030000b00550055005500550303bb303003bb300000e000000000000042222400a2222a0042442400024420000000000000000000000000000000000
00000000000000000000000000000000030330300003300000000000000000002004400240044004a004400aa004400a00000000000000000000000000000000
0677776000088000000000000cccccc033333333000880000cccccc033333333000000000cc66cc0000000000000000000000000000000000000000000000000
077887700008800009900990cc1111cc3bbbbbb300088000cc1111cc3bbbbbb309900990c166661c000000000000000000000000000000000000000000000000
07888870000000000998a990c11cc11c3bb33bb300000000c11cc11c3bb33bb30998a990c166661c000000000000000000000000000000000000000000000000
078888708808808800800a00c1cccc1c3b3003b388088088c1cccc1c3b3003b300800a00c116611c000000000000000000000000000000000000000000000000
077887708808808800a00800c1cccc1c3b3003b388088088c1cccc1c3b3003b300a00800c116611c000000000000000000000000000000000000000000000000
0677776000000000099a8990c11cc11c3bb33bb300000000c11cc11c3bb33bb3099a8990c165561c000000000000000000000000000000000000000000000000
05dddd500008800009900990cc1111cc3bbbbbb300088000cc1111cc3bbbbbb309900990c161161c000000000000000000000000000000000000000000000000
0000000000088000000000000cccccc033333333000880000cccccc033333333000000000cccccc0000000000000000000000000000000000000000000000000
00b0000000000c0000b0000000000c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0bb3000e8000ccd00bb3000e8000ccd00000000e8000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbb330ee880cccddbb8330ee880cc8dd000000ee8800000000000000000000000000000000000000000000000000000000000000000000000000000000000000
03330eee8880ddd003330eee8880ddd000000eee8880000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0030eeee88880d000030eeee88880d000000eeee8888000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000eeeecc8888000000eeeecc8888000000eeeecc888800000000000000000000000000000000000000000000000000000000000000000000000000000000000
00eee2c11c28880000eee2caac28880000eee2c11c28880000000000000000000000000000000000000000000000000000000000000000000000000000000000
0eeeee25528888800eeeee25528888800eeeee255288888000000000000000000000000000000000000000000000000000000000000000000000000000000000
0deeeeee888888200deeeeee888888200deeeeee8888882000000000000000000000000000000000000000000000000000000000000000000000000000000000
00dddeee8882220000dddeee8882220000dddeee8882220000000000000000000000000000000000000000000000000000000000000000000000000000000000
000ddddd22222000000ddddd22222000000ddddd2222200000000000000000000000000000000000000000000000000000000000000000000000000000000000
0090dddd22220a000090dddd22220a000000dddd2222000000000000000000000000000000000000000000000000000000000000000000000000000000000000
09980ddd2220aa9009980ddd2220aa9000000ddd2220000000000000000000000000000000000000000000000000000000000000000000000000000000000000
999880dd220aaa99998880dd220aa899000000dd2200000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0882000d200099400882000d200099400000000d2000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00800000000009000080000000000900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000200002c054000002c053000002c052000002c051000002c050000002c040000002c03000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0005000028073000002607200000240710000022070000001e060000001a050000001505000000110400000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000800002c074000002a063000002806200000260510000024040000001e030000001803000000100200000008010000000000000000000000000000000000000000000000000000000000000000000000000000
0005000024570285702b5703057034570375703c5703c5703c5703c5603c5503c5403c5303c5203c5100000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000383503a3503c3403833000000383503a3403c330383200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100003c0503a04038040360303403032020300202e0102c0100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200002c1502a150281402613024120221100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0003000028360263502434022330203201e3100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0002000022670206501e6301c6201a610000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000500003005034050370503c05000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000001461500000000000000023615000000000000000146150000000000000002361500000000000000014615000000000000000236150000000000000001461500000000000000023615000000000000000
001000000c3100000000000000000c3100000000000000000c3100000000000000000c3100000000000000000c3100000000000000000c3100000000000000000c3100000000000000000c310000000000000000
001000000000018510000001b510000001f5100000018510000001b510000001f5100000018510000001b510000001f5100000018510000001b510000001f5100000018510000001b510000001f5100000018510
001000002402100000000000000000000000000000000000000000000000000000000000000000000000000027021000000000000000000000000000000000000000000000000000000000000000000000000000
001000000831000000000000000008310000000000000000083100000000000000000831000000000000000008310000000000000000083100000000000000000831000000000000000008310000000000000000
0010000000000145100000017510000001b51000000145100000017510000001b51000000145100000017510000001b51000000145100000017510000001b51000000145100000017510000001b5100000014510
001000002002100000000000000000000000000000000000000000000000000000000000000000000000000023021000000000000000000000000000000000000000000000000000000000000000000000000000
001000000531000000000000000005310000000000000000053100000000000000000531000000000000000005310000000000000000053100000000000000000531000000000000000005310000000000000000
001000000000011510000001451000000195100000011510000001451000000195100000011510000001451000000195100000011510000001451000000195100000011510000001451000000195100000011510
001000001d02100000000000000000000000000000000000000000000000000000000000000000000000000019021000000000000000000000000000000000000000000000000000000000000000000000000000
001000000731000000000000000007310000000000000000073100000000000000000731000000000000000007310000000000000000073100000000000000000731000000000000000007310000000000000000
0010000000000135100000016510000001a51000000135100000016510000001a51000000135100000016510000001a51000000135100000016510000001a51000000135100000016510000001a5100000013510
001000001f02100000000000000000000000000000000000000000000000000000000000000000000000000021021000000000000000000000000000000000000000000000000000000000000000000000000000
00080000164201a4201d4201a420164201a4201d4201a420164201a4201d4201a420164201a4201d4201a420164201a4201d4201a420164201a4201d4201a420164201a4201d4201a420164201a4201d4201a420
001800002152024520285202451021520245202852024510215202452028520245102152024520285202451021520245202852024510215202452028520245102152024520285202451021520245202852024510
001800000912000000000000000010110000000000000000091200000000000000001011000000000000000009120000000000000000101100000000000000000912000000000000000010110000000000000000
001800000012500000000000000000125000000000000000001250000000000000000012500000000000000000125000000000000000001250000000000000000012500000000000000000125000000000000000
0018000000000000000f015000000000000000130150000000000000000f015000000000000000130150000000000000000f015000000000000000130150000000000000000f0150000000000000001301500000
001800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001800000512500000000000000005125000000000000000051250000000000000000512500000000000000005125000000000000000051250000000000000000512500000000000000005125000000000000000
001800000000000000140150000000000000001801500000000000000014015000000000000000180150000000000000001401500000000000000018015000000000000000140150000000000000001801500000
001800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001800000012500000000000000000125000000000000000001250000000000000000012500000000000000000125000000000000000001250000000000000000012500000000000000000125000000000000000
0018000000000000000f015000000000000000130150000000000000000f015000000000000000130150000000000000000f015000000000000000130150000000000000000f0150000000000000001301500000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000001804116041130410f0410c0410a0410704103041000410000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000c3500c3400c3300c32007350073400733007320003500034000330003200031000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00080000180411c0411f041240411f04124041280512b0612b0512b0412b031000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000800000c35010350133501835013350183501c3501f3501f3401f3301f320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000600000866500000266450000018655000002664500000086650000026645000001865500000266450000008665000002664500000186550000026645000000866500000266450000018655000002664500000
000600000866500000266450000018655000002664500000086650000026645000001865500000266450000008665000002664500000186550000026645000001865518665186551866518655186651865518665
000600000c350000000c3500c3500c350000000c3500c3500c350000000c3500c3500c350000000c3500c3500c350000000c3500c3500c350000000c3500c3500c350000000c3500c3500c350000000c3500c350
00060000184301b4301f4301b430184301b4301f4301b430184301b4301f4301b430184301b4301f4301b430184301b4301f4301b430184301b4301f4301b430184301b4301f4301b430184301b4301f4301b430
00060000181610000018161000001b161000001b161000001f1610000000000000001b161000000000000000181610000018161000001b161000001b161000001f1610000000000000001b161000000000000000
000600000835000000083500835008350000000835008350083500000008350083500835000000083500835008350000000835008350083500000008350083500835000000083500835008350000000835008350
0006000014430184301b4301843014430184301b4301843014430184301b4301843014430184301b4301843014430184301b4301843014430184301b4301843014430184301b4301843014430184301b43018430
0006000014161000001416100000181610000018161000001b1610000000000000001816100000000000000014161000001416100000181610000018161000001b16100000000000000018161000000000000000
000600000a350000000a3500a3500a350000000a3500a3500a350000000a3500a3500a350000000a3500a3500a350000000a3500a3500a350000000a3500a3500a350000000a3500a3500a350000000a3500a350
00060000164301a4301d4301a430164301a4301d4301a430164301a4301d4301a430164301a4301d4301a430164301a4301d4301a430164301a4301d4301a430164301a4301d4301a430164301a4301d4301a430
00060000161610000016161000001a161000001a161000001d1610000000000000001a161000000000000000161610000016161000001a161000001a161000001d1610000000000000001a161000000000000000
000600001335000000133501335013350000001335013350133500000013350133501335000000133501335013350000001335013350133500000013350133501335000000133501335013350000001335013350
0006000013430174301a4301743013430174301a4301743013430174301a4301743013430174301a4301743013430174301a4301743013430174301a4301743013430174301a4301743013430174301a43017430
00060000131611416115161161611716118161191611a1611b1610000000000000001f161000001f161000001f161000000000000000000000000000000000000000000000000000000000000000000000000000
000300001e15022150251502a1502e150311500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00030000143511e351233500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
01 0b0c0a0d
00 0e0f0a10
00 11120a13
02 14150a16
01 1a1b1c1d
00 1e1f2021
00 22232425
02 26272829
00 2a2b4040
04 2c2d4040
01 3032312e
00 3335342e
00 3638372e
02 393b3a2f

