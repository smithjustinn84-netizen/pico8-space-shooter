pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
-- tab 0: core logic

S_ENEMY = 32
S_ENEMY2 = 36
S_ENEMY3 = 34
S_ENEMY4 = 38
S_BULLET = 19
S_BULLET_PLASMA = 21
S_BULLET_LASER = 23
S_EXPL_1 = 25
S_EXPL_2 = 26
S_EXPL_3 = 27
S_MUZZLE = 16
S_MUZZLE_PLASMA = 17
S_MUZZLE_LASER = 18
S_GEM = 28

ships = {
  { sp = 1, sp_l = 4, sp_r = 7, weapon = "basic", hp = 3, max_speed = 3, fire_delay = 10, plasma_lv = 3, laser_lv = 5, t_cols = { 8, 9, 10 } },
  { sp = 2, sp_l = 5, sp_r = 8, weapon = "plasma", hp = 2, max_speed = 4, fire_delay = 8, plasma_lv = 1, laser_lv = 3, t_cols = { 12, 13, 7 } },
  { sp = 3, sp_l = 6, sp_r = 9, weapon = "basic", hp = 4, max_speed = 2, fire_delay = 12, plasma_lv = 4, laser_lv = 7, t_cols = { 11, 3, 10 } }
}
selected_ship = 1

function _init()
  hi_score = 0
  level = 1
  level_kills = 0
  level_bonus = 0
  li_t = 0
  entities = {}
  init_stars()
  go_to_title()
end

function _update60()
  if state.update then state.update() end
end

function _draw()
  cls(1)
  if state.draw then state.draw() end
end

function go_to_title()
  entities = {}
  state = title_state
end

function go_to_game()
  game_state.init()
  go_to_level_intro()
end

function go_to_gameover()
  go_t = 0
  hi_score = max(hi_score, final_score)
  state = gameover_state
end

function go_to_level_intro()
  li_t = 0
  if level_bonus > 0 then play_sound(3) end
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
      play_sound(0)
    end
    if btnp(1) then
      selected_ship = (selected_ship % 3) + 1
      play_sound(0)
    end
    if btnp(4) or btnp(5) then
      go_to_game()
    end
  end,
  draw = function()
    draw_stars()
    print("space shooter", 38, 40, 7)

    local types = { "balanced", "assault", "heavy" }
    for i = 1, 3 do
      local sx = 46 + (i - 1) * 16
      local sy = 60
      if selected_ship == i then
        circfill(sx + 3, sy + 3, 8, 5)
        print(types[i], 64 - #types[i] * 2, 74, 6)
        local s = ships[i]
        -- hp
        print("hp:", 30, 82, 6)
        for h = 1, s.hp do
          spr(14, 46 + (h - 1) * 9, 81)
        end
        -- speed bars (max_speed 2-4 -> 1-3 bars)
        print("spd:", 30, 90, 6)
        local bars = s.max_speed - 1
        for b = 1, bars do
          rectfill(46 + (b - 1) * 6, 90, 50 + (b - 1) * 6, 95, 7)
        end
        -- starting weapon
        print("gun: " .. s.weapon, 30, 98, 6)
      end
      spr(ships[i].sp, sx, sy)
    end

    if flr(t() * 2) % 2 == 0 then
      print("press z to start", 32, 110, 6)
    end
  end
}

game_state = {
  init = function()
    score = 0
    level = 1
    level_kills = 0
    level_bonus = 0
    init_player()
    entities = {}
    shake_t = 0
    shake_mag = 0
    hit_flash_t = 0
    death_flash_t = 0
    death_timer = 0
  end,
  update = function()
    update_stars()
    if not p.dead then
      local scale = 1 + (level - 1) * 0.3
      if rnd(100) < 3 * scale then spawn_enemy("basic") end
      if rnd(100) < 1 * scale then spawn_enemy("zigzag") end
      -- level 2+: divers drop straight onto the player
      if level >= 2 and rnd(100) < 0.8 * scale then spawn_enemy("diver") end
      -- level 3+: chasers steer toward the player
      if level >= 3 and rnd(100) < 0.6 * scale then spawn_enemy("chaser") end
      -- level 2+: shooters fire bullets downward / at player
      if level >= 2 and rnd(100) < 0.7 * scale then spawn_enemy("shooter") end
      -- level 4+: tanks
      if level >= 4 and rnd(100) < 0.5 * scale then spawn_enemy("tank") end
      -- level 3+: spinners
      if level >= 3 and rnd(100) < 0.8 * scale then spawn_enemy("spinner") end
    end
    for e in all(entities) do
      e.update(e)
      if e.dead then del(entities, e) end
    end
    if not p.dead then
      update_player(p)
      check_collisions()
    else
      death_timer -= 1
      if death_timer > 0 and death_timer % 20 == 0 then
        add(entities, make_explosion(p.x + rnd(16) - 8, p.y + rnd(16) - 8))
        shake_screen(2, 6)
      end
      if death_timer <= 0 then go_to_gameover() end
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
    if p.dead then
      draw_player_death(p)
    else
      draw_player(p)
    end
    for e in all(entities) do
      e.draw(e)
    end
    camera()
    draw_hit_flash()
    if not p.dead then draw_hud() end
  end
}

gameover_state = {
  update = function()
    go_t += 1
    update_stars()
    for e in all(entities) do
      e.update(e)
      if e.dead then del(entities, e) end
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
    -- slide in from top with cubic ease-out
    local ty = 45
    if go_t < 30 then
      local pr = go_t / 30
      ty = -20 + (1 - (1 - pr) ^ 3) * 65
    end
    -- wobble + color cycle
    local wx = flr(sin(go_t * 0.07) * 1.5)
    local cc = ({ 8, 9, 10, 9 })[flr(go_t * 0.08) % 4 + 1]
    -- shadow + text
    print("game over", 38 + wx, ty + 1, 1)
    print("game over", 37 + wx, ty, cc)
    -- score fades in
    if go_t > 45 then
      print("score: " .. final_score, 42, ty + 16, go_t > 65 and 7 or 6)
    end
    if go_t > 60 then
      local hc = final_score >= hi_score and 10 or 6
      print("best:  " .. hi_score, 42, ty + 24, hc)
    end
    -- retry prompt blinks
    if go_t > 90 and flr(go_t / 8) % 2 == 0 then
      print("z:retry  x:title", 26, ty + 36, 6)
    end
  end
}

level_intro_state = {
  update = function()
    li_t += 1
    update_stars()
    if li_t >= 150 then go_to_game_resume() end
  end,
  draw = function()
    draw_stars()
    local ty = 50
    if li_t < 35 then
      local pr = li_t / 35
      ty = -12 + (1 - (1 - pr) ^ 3) * 62
    end
    local wx = li_t < 50 and flr(sin(li_t * 0.07) * 1.5) or 0
    local cc = ({ 8, 9, 10, 9 })[flr(li_t * 0.08) % 4 + 1]
    local txt = "level " .. level
    print(txt, 45 + wx, ty + 1, 1)
    print(txt, 44 + wx, ty, cc)
    if li_t > 45 and level_bonus > 0 then
      local bc = li_t < 55 and 6 or (li_t < 65 and 10 or 7)
      print("+" .. level_bonus .. " bonus!", 36, ty + 16, bc)
    end
    if li_t > 60 then
      local sc = li_t < 70 and 5 or 6
      print("score: " .. score, 38, ty + 24, sc)
    end
    if li_t > 75 then
      local rc = li_t < 85 and 5 or (li_t < 95 and 6 or 7)
      print("ready!", 47, ty + 36, rc)
    end
  end
}

-->8
-- tab 2: player logic

function init_player()
  local s = ships[selected_ship]
  p = {
    x = 60,
    y = 100,
    vx = 0,
    vy = 0,
    accel = 0.5,
    fric = 0.85,
    max_speed = s.max_speed,
    sp = s.sp,
    sp_l = s.sp_l,
    sp_r = s.sp_r,
    w = 8,
    h = 8,
    hx = 2, hy = 2, hw = 4, hh = 4,
    fire_delay = 0,
    base_fire_delay = s.fire_delay,
    flash_t = 0,
    hp = s.hp,
    max_hp = s.hp,
    iframes = 0,
    weapon = s.weapon,
    plasma_lv = s.plasma_lv,
    laser_lv = s.laser_lv,
    thrusting = false,
    t_cols = s.t_cols,
    resources = 0
  }
end

function update_player(obj)
  local ax, ay = 0, 0

  if btn(0) then ax -= obj.accel end
  if btn(1) then ax += obj.accel end
  if btn(2) then ay -= obj.accel end
  if btn(3) then ay += obj.accel end

  obj.thrusting = ax ~= 0 or ay ~= 0

  if level >= obj.laser_lv then
    obj.weapon = "laser"
  elseif level >= obj.plasma_lv then
    obj.weapon = "plasma"
  end

  -- shoot
  if (btn(4) or btn(5)) and obj.fire_delay <= 0 then
    fire_bullet(obj)
    obj.fire_delay = obj.base_fire_delay
    obj.flash_t = 3
  end
  if obj.fire_delay > 0 then obj.fire_delay -= 1 end
  if obj.flash_t > 0 then obj.flash_t -= 1 end
  if obj.iframes > 0 then obj.iframes -= 1 end

  -- apply acceleration + friction
  obj.vx = (obj.vx + ax) * obj.fric
  obj.vy = (obj.vy + ay) * obj.fric

  -- clamp to max speed
  local v = sqrt(obj.vx * obj.vx + obj.vy * obj.vy)
  if v > obj.max_speed then
    obj.vx = (obj.vx / v) * obj.max_speed
    obj.vy = (obj.vy / v) * obj.max_speed
  end

  obj.x += obj.vx
  obj.y += obj.vy

  -- clamp to screen bounds
  obj.x = mid(0, obj.x, 120)
  obj.y = mid(0, obj.y, 120)
end

function fire_bullet(obj)
  local btype = obj.weapon
  if btype == "basic" then
    add(entities, make_bullet(obj, "basic"))
    local d = make_debris(obj.x + 4, obj.y - 2)
    d.vx = rnd(1) - 0.5
    d.vy = -1 - rnd(1)
    d.col = ({ 9, 10 })[flr(rnd(2)) + 1]
    d.life = 10
    d.ml = d.life
    add(entities, d)
  elseif btype == "plasma" then
    local b1 = make_bullet(obj, "plasma")
    local b2 = make_bullet(obj, "plasma")
    b1.x -= 3
    b2.x += 3
    add(entities, b1)
    add(entities, b2)
    for i = 1, 2 do
      local d = make_debris(obj.x + 4, obj.y - 2)
      d.vx = rnd(1) - 0.5
      d.vy = -1 - rnd(1)
      d.col = ({ 11, 3 })[flr(rnd(2)) + 1]
      d.life = 10 + rnd(10)
      d.ml = d.life
      add(entities, d)
    end
  elseif btype == "laser" then
    add(entities, make_bullet(obj, "laser"))
    shake_screen(1, 4)
    for i = 1, 3 do
      local d = make_debris(obj.x + 4, obj.y - 4)
      d.vx = rnd(2) - 1
      d.vy = -2 - rnd(2)
      d.col = ({ 8, 9, 10 })[flr(rnd(3)) + 1]
      d.life = 15 + rnd(10)
      d.ml = d.life
      add(entities, d)
    end
  end
  if btype == "plasma" then
    play_sound(4)
  elseif btype == "laser" then
    play_sound(5)
  else
    play_sound(6)
  end
end

function draw_player(obj)
  local s = obj.sp
  local dx = 0
  if obj.vx < -0.2 then
    s = obj.sp_l
    dx = -1
  elseif obj.vx > 0.2 then
    s = obj.sp_r
    dx = 1
  end

  draw_thruster(obj, dx)

  local period = 2 + flr(obj.iframes / 15)
  if obj.iframes > 0 and obj.iframes % period < flr(period / 2) then
    for c = 0, 15 do
      pal(c, 7)
    end
    spr(s, obj.x, obj.y)
    pal()
  else
    spr(s, obj.x, obj.y)
  end

  if obj.flash_t > 0 then
    draw_muzzle_flash(obj, dx)
  end
end

function draw_thruster(obj, dx)
  local spd = sqrt(obj.vx * obj.vx + obj.vy * obj.vy)
  local fh = 4 + flr(spd * 4) + flr(t() * 16) % 2
  local fn = flr(t() * 16) % 4

  -- swap colors for unique thruster look
  pal(8, obj.t_cols[1])
  pal(9, obj.t_cols[2])
  pal(10, obj.t_cols[3])

  sspr(80 + fn * 8, 0, 8, 8, obj.x + dx, obj.y + 8, 8, fh)

  -- reset palette
  pal()
end

function draw_muzzle_flash(obj, dx)
  local m_sp = S_MUZZLE
  if obj.weapon == "plasma" then m_sp = S_MUZZLE_PLASMA end
  if obj.weapon == "laser" then m_sp = S_MUZZLE_LASER end

  local flip_x = obj.flash_t % 2 == 0
  local offset_y = flr(rnd(2))
  spr(m_sp, obj.x + dx, obj.y - 6 + offset_y, 1, 1, flip_x)
end

function draw_player_death(obj)
  if death_timer <= 0 then return end
  local prog = 1 - death_timer / 120
  local sep = flr(prog * prog * 18)
  local twist = flr(sin(prog * 2.5) * sep * 0.4)
  local hot = ({ 9, 10, 9, 8, 7 })[flr(t() * 14) % 5 + 1]
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
  p.hp -= 1
  p.iframes = frames
  if p.hp <= 0 then player_death() end
end

function player_death()
  p.dead = true
  final_score = score
  death_timer = 120
  death_flash_t = 15
  shake_screen(8, 50)
  for i = 1, 3 do
    add(entities, make_explosion(p.x + rnd(12) - 6, p.y + rnd(12) - 6))
  end
  for i = 1, 20 do
    add(entities, make_debris(p.x + 4, p.y + 4))
  end
  play_sound(2)
end

-->8
-- tab 3: entities

function move_straight(e)
  -- intentionally empty: vy alone moves enemy straight down
end

function move_zigzag(e)
  e.phase = (e.phase + 0.008) % 1
  e.x = mid(0, e.ox + 30 * sin(e.phase), 120)
end

-- chaser: nudge x toward the player each frame
function move_chase(e)
  local dx = p.x - e.x
  e.x += dx * 0.025
  e.x = mid(0, e.x, 120)
end

-- shooter: counts down and fires a bullet aimed at the player
function move_shooter(e)
  e.shoot_t -= 1
  if e.shoot_t <= 0 then
    e.shoot_t = 55
    add(entities, make_enemy_bullet(e))
    play_sound(7)
  end
end

enemy_types = {
  basic = {
    gem_tier = 1,
    sp = S_ENEMY, pts = 10, move = move_straight,
    mk_x = function() return rnd(120) end,
    mk_vy = function() return 1 + rnd(1) end,
    extra = function(e) end
  },
  zigzag = {
    gem_tier = 1,
    sp = S_ENEMY2, pts = 25, move = move_zigzag,
    mk_x = function() return 30 + rnd(60) end,
    mk_vy = function() return 0.8 + rnd(0.4) end,
    extra = function(e) e.ox = e.x e.phase = rnd(1) end
  },
  -- spawns directly above the player and dives fast
  -- red/fiery palette: aggressive, danger signal
  diver = {
    gem_tier = 1,
    sp = S_ENEMY, pts = 20, move = move_straight,
    mk_x = function() return p.x end,
    mk_vy = function() return 1.8 + rnd(0.8) end,
    extra = function(e) end,
    draw_fn = function(en)
      pal(3, 8)
      pal(11, 9)
      pal(12, 8)
      pal(7, 10)
      pal(6, 9)
      spr(S_ENEMY + flr(t() * 4) % 2, en.x, en.y)
      pal()
    end
  },
  -- steers toward the player horizontally
  -- purple/indigo palette: eerie, alien
  chaser = {
    gem_tier = 2,
    sp = S_ENEMY2, pts = 30, move = move_chase,
    mk_x = function() return rnd(120) end,
    mk_vy = function() return 0.6 + rnd(0.4) end,
    extra = function(e) end,
    draw_fn = function(en)
      pal(3, 2)
      pal(11, 14)
      pal(12, 13)
      pal(7, 14)
      pal(6, 13)
      spr(S_ENEMY2 + flr(t() * 4) % 2, en.x, en.y)
      pal()
    end
  },
  -- slow-moving enemy that fires aimed shots
  -- toxic green palette, pulses white when about to fire
  shooter = {
    gem_tier = 2,
    sp = S_ENEMY, pts = 40, move = move_shooter,
    mk_x = function() return 10 + rnd(100) end,
    mk_vy = function() return 0.4 + rnd(0.3) end,
    extra = function(e) e.shoot_t = 40 end,
    draw_fn = function(en)
      local charging = en.shoot_t < 18
      if charging then
        local f = flr(t() * 12) % 2 == 0
        pal(3, f and 7 or 10)
        pal(11, f and 7 or 10)
        pal(12, 10)
        pal(7, 7)
        pal(6, 10)
      else
        pal(3, 3)
        pal(11, 10)
        pal(12, 11)
        pal(7, 10)
        pal(6, 11)
      end
      spr(S_ENEMY + flr(t() * 4) % 2, en.x, en.y)
      pal()
      -- charge ring glows outward when near firing
      if charging then
        local r = 3 + flr(sin(t() * 6) * 1.5)
        circ(en.x + 4, en.y + 4, r, 10)
      end
    end
  },
  tank = {
    gem_tier = 3,
    sp = S_ENEMY3, pts = 50, move = move_straight,
    mk_x = function() return 20 + rnd(80) end,
    mk_vy = function() return 0.3 + rnd(0.2) end,
    extra = function(e) e.hp = 4 end,
    draw_fn = function(en)
      if en.flash and en.flash > 0 then
        for c = 0, 15 do
          pal(c, 7)
        end
        en.flash -= 1
      end
      spr(S_ENEMY3 + flr(t() * 4) % 2, en.x, en.y)
      pal()
    end
  },
  spinner = {
    gem_tier = 2,
    sp = S_ENEMY4, pts = 40, move = move_zigzag,
    mk_x = function() return rnd(120) end,
    mk_vy = function() return 1 + rnd(0.5) end,
    extra = function(e) e.ox = e.x e.phase = rnd(1) end,
    draw_fn = function(en)
      spr(S_ENEMY4 + flr(t() * 16) % 2, en.x, en.y)
    end
  }
}

function make_bullet(obj, btype)
  local s = S_BULLET
  local v = -4
  if btype == "plasma" then
    s = S_BULLET_PLASMA
    v = -5
  end
  if btype == "laser" then
    s = S_BULLET_LASER
    v = -6
  end
  return {
    tag = "bullet", x = obj.x, y = obj.y - 4,
    sp = s, vy = v, w = 8, h = 8, hx = 2, hw = 4, btype = btype,
    update = function(b)
      b.y += b.vy
      if b.y < -8 then b.dead = true end
    end,
    draw = function(b)
      spr(b.sp + flr(t() * 12) % 2, b.x, b.y)
    end
  }
end

-- enemy bullet aimed toward the player at time of firing
function make_enemy_bullet(src)
  local dx = (p.x + 4) - (src.x + 4)
  local dy = (p.y + 4) - (src.y + 4)
  local d = sqrt(dx * dx + dy * dy)
  if d == 0 then d = 1 end
  local spd = 2.2
  return {
    tag = "ebullet", x = src.x + 1, y = src.y + 8,
    vx = (dx / d) * spd, vy = (dy / d) * spd,
    w = 4, h = 4,
    update = function(b)
      b.x += b.vx
      b.y += b.vy
      if b.y > 136 or b.y < -16 or b.x < -16 or b.x > 144 then
        b.dead = true
      end
    end,
    draw = function(b)
      -- small red plasma bolt
      pset(b.x, b.y, 8)
      pset(b.x + 1, b.y, 9)
      pset(b.x, b.y + 1, 9)
      pset(b.x + 1, b.y + 1, 10)
    end
  }
end

function spawn_enemy(type_name)
  local td = enemy_types[type_name]
  local x = td.mk_x()
  local dfn = td.draw_fn
  local e = {
    tag = "enemy", x = x, y = -8,
    sp = td.sp, vy = td.mk_vy(),
    w = 8, h = 8, pts = td.pts, move = td.move,
    update = function(en)
      en.y += en.vy
      en.move(en)
      if en.y > 128 then en.dead = true end
    end,
    draw = function(en)
      if dfn then
        dfn(en)
      else
        spr(en.sp + flr(t() * 4) % 2, en.x, en.y)
      end
    end
  }
  td.extra(e)
  e.gem_tier = td.gem_tier or 1
  add(entities, e)
end

function make_explosion(x, y)
  return {
    tag = "explosion", x = x, y = y, t = 12,
    update = function(ex)
      ex.t -= 1
      if ex.t <= 0 then ex.dead = true end
    end,
    draw = function(ex)
      local s = S_EXPL_1
      if ex.t < 4 then
        s = S_EXPL_3
      elseif ex.t < 8 then
        s = S_EXPL_2
      end
      spr(s, ex.x, ex.y)
      if ex.t > 8 then
        local prog = (12 - ex.t) / 4
        local r = flr(prog * (2 - prog) * 6)
        circ(ex.x + 4, ex.y + 4, r, 10)
        circ(ex.x + 4, ex.y + 4, r + 2, 9)
      end
    end
  }
end

function make_popup(x, y, pts)
  return {
    tag = "popup", x = x, y = y, t = 20, pts = pts,
    update = function(pu)
      pu.y -= pu.t * 0.05
      pu.t -= 1
      if pu.t <= 0 then pu.dead = true end
    end,
    draw = function(pu)
      local c = pu.t > 13 and 7 or (pu.t > 6 and 6 or 5)
      print("+" .. pu.pts, pu.x, pu.y, c)
    end
  }
end

function make_gem(x, y, tier)
  local val = tier == 3 and 4 or (tier == 2 and 2 or 1)
  return {
    tag = "gem", x = x, y = y, w = 8, h = 8,
    hx = 1, hy = 1, hw = 6, hh = 6,
    vy = 0.5, tier = tier, value = val,
    update = function(g)
      g.y += g.vy
      if g.y > 136 then g.dead = true end
    end,
    draw = function(g)
      if g.tier == 2 then
        pal(3, 1) pal(6, 12) pal(11, 12)
      elseif g.tier == 3 then
        pal(3, 8) pal(6, 9) pal(11, 10)
      end
      spr(S_GEM + flr(t() * 4) % 2, g.x, g.y)
      pal()
    end
  }
end

function make_debris(x, y)
  local ang = rnd(1)
  local spd = 1 + rnd(3)
  local life = 30 + flr(rnd(40))
  local col = ({ 8, 9, 10, 7, 7, 5 })[flr(rnd(6)) + 1]
  return {
    tag = "debris", x = x, y = y,
    vx = cos(ang) * spd, vy = sin(ang) * spd - 0.5,
    life = life, ml = life, col = col,
    update = function(d)
      d.x += d.vx
      d.y += d.vy
      d.vy += 0.05
      d.vx *= 0.97
      d.life -= 1
      if d.life <= 0 then d.dead = true end
    end,
    draw = function(d)
      local f = d.life / d.ml
      local c = f > 0.5 and d.col or (f > 0.2 and 5 or 1)
      pset(d.x, d.y, c)
      if f > 0.5 then pset(d.x - d.vx * .4, d.y - d.vy * .4, 1) end
    end
  }
end

function check_collisions()
  for e in all(entities) do
    if e.tag == "enemy" and not e.dead then
      for b in all(entities) do
        if b.tag == "bullet" and not b.dead and collide(e, b) then
          b.dead = true
          if e.hp and e.hp > 1 then
            e.hp -= 1
            e.flash = 3
            play_sound(8)
          else
            play_sound(1)
            add(entities, make_explosion(e.x, e.y))
            add(entities, make_popup(e.x, e.y, e.pts))
            e.dead = true
            score += e.pts
            level_kills += 1
            if level_kills >= level * 8 then
              level += 1
              level_kills = 0
              entities = {}
              play_sound(3)
              go_to_level_intro()
              return
            end
            shake_screen(2, 8)
            local drop = e.gem_tier == 3 and 70 or (e.gem_tier == 2 and 50 or 30)
            if rnd(100) < drop then
              add(entities, make_gem(e.x, e.y, e.gem_tier))
            end
          end
        end
      end
      if p.iframes <= 0 and collide(p, e) then
        play_sound(2)
        add(entities, make_explosion(e.x, e.y))
        e.dead = true
        damage_player(60)
        shake_screen(3, 12)
        hit_flash_t = 8
      end
    end
    -- enemy bullets hit the player
    if e.tag == "ebullet" and not e.dead and p.iframes <= 0 then
      if collide(p, e) then
        e.dead = true
        damage_player(50)
        shake_screen(2, 8)
        hit_flash_t = 6
        play_sound(2)
      end
    end
    if e.tag == "gem" and not e.dead then
      if collide(p, e) then
        p.resources += e.value
        e.dead = true
        add(entities, make_popup(e.x, e.y, e.value))
        play_sound(9)
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

function play_sound(id) sfx(id) end

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
  print("score:" .. score, 2, 2, 7)

  local lvl_str = "lvl:" .. level
  print(lvl_str, 64 - (#lvl_str * 2), 2, 6)

  local h_width = p.max_hp * 9
  local start_x = 127 - h_width
  for i = 1, p.max_hp do
    spr(i <= p.hp and 14 or 15, start_x + (i - 1) * 9, 1)
  end
  spr(S_GEM, 79, 1)
  print(p.resources, 88, 2, 11)
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
00000000000880000008800000566500088000000080000000565000000008800000800000056500088008800080080000800800008008000880088008800880
000000000087780000e88e000567765008780000008e00000556600000008780000e800000066550899889980898898000899800089889808888888880088008
00000000008cc80000888800056cc65008c80000008e00000556600000008c80000e80000006655089aa9aa8089aa980008aa800089aa9808888888880000008
00000000058cc8500e8778e00056650052c850000278e0000056500000058c2500e872000005650008aaaa80089aa980008aa800008aa8008888888880000008
0000000058811885088cc880000660005218550002c8e000000600000055812500e8c20000006000008aa800008aa80000899800008998000888888008000080
0000000058588585e88cc88e006556000585250008c8e000005560000052525000e8c80000065500000880000008800000088000000880000088880000800800
000000000055550088855888056cc6500055000088588e0005556000000055000e88588000065550000000000008800000088000000000000008800000088000
00000000007007005550055505c00c50077000005605650005cc660000000770057507500066cc50000000000000000000088000000000000000000000000000
00000000000000000000000000080000000800000000000000000000000b00000030300000000000009a0a9005000050000000000000000000a6700000000000
0000000000000000000000000089800000898000001cc10000111100000b0000003b30000007700009a77a905006600500000000000000000a0670a000000000
000000000000000000000000089a98000897980001cddc10011cc110003b3000003b3000007aa7009a7887a9006006000000000000000000000670000000a000
000a0000000700000007000008a7a800087778000cddddc001cccc10003b3000000b0000007aa700a787787a0600006000073000000b70007777777700a07000
009aa90000c77c0000b77b00009a9000009790000cddddc001cccc10003b3000000b000000077000a787787a060000600076b300003b67000006700000077600
008aa800001cc100003bb300008980000089800001cddc10011cc110003b3000003b3000000000009a7887a90060060000b6b300003b6b000006700000076000
00899800001dd100003bb3000008000000080000001cc10000111100000b0000003b30000000000009a77a90500660050033b300003b63000a0670a000a60a00
00088000000110000003300000000000000000000000000000000000000b00000030300000000000009aa9000500005000033000000330000006700000000000
005333000053330000000000000000000530033005000030000e0000000000000000000000000000000000000000000000000000000000000000000000000000
053b3330053b3330055555500555555053b33b335b3003b3002e20000e000e000000000000000000000000000000000000000000000000000000000000000000
33bbbb3333bbbb3355655655565555653bbbbbb33bbb3bb302222200002220000000000000000000000000000000000000000000000000000000000000000000
3b8287b33be828b355555555555555553bb67bb33bb67bb3e22622e0022622000000000000000000000000000000000000000000000000000000000000000000
3bb33b333bb33b336666666666666666036717300361773002222200002220000000000000000000000000000000000000000000000000000000000000000000
033333300333333058855885058888500371173033711733002e20000e000e000000000000000000000000000000000000000000000000000000000000000000
00b00300030000b00550055005500550303bb303003bb300000e0000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000030330300003300000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
000500003005034050370503c0500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
