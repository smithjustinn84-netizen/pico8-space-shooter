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
  final_score = 0
  level = 1
  level_kills = 0
  level_bonus = 0
  li_t = 0
  stage_completing = false
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
  play_sound(3)
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
    entities = {}
    -- layer-filtered sub-lists: avoid O(n²) full entity scans
    bullets = {}
    enemies = {}
    ebullets = {}
    gems = {}
    init_player()
    shake_t = 0
    shake_mag = 0
    hit_flash_t = 0
    death_flash_t = 0
    death_timer = 0
    stage_completing = false
  end,
  update = function()
    update_stars()
    if not p.dead and not stage_completing then
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
      -- level 4+: hunters patrol then dive (state-machine enemy)
      if level >= 4 and rnd(100) < 0.5 * scale then spawn_hunter() end
    end
    -- unified entity loop: player + all enemies/bullets/fx
    for e in all(entities) do
      e.update(e)
      if e.dead and e.tag ~= "player" then
        del(entities, e)
        -- keep typed sub-lists in sync
        if e.tag == "bullet" then del(bullets, e) end
        if e.tag == "enemy" then del(enemies, e) end
        if e.tag == "ebullet" then del(ebullets, e) end
        if e.tag == "gem" then del(gems, e) end
      end
    end
    if not p.dead then
      check_collisions()
    end
    if stage_completing then
      local any = false
      for e in all(entities) do
        if e.tag == "gem" then
          any = true break
        end
      end
      if not any then
        stage_completing = false
        entities = {}
        -- re-insert player so it survives the wipe
        add(entities, p, 1)
        go_to_level_intro()
        return
      end
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
    tag = "player",
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
    max_iframes = 0,
    weapon = s.weapon,
    plasma_lv = s.plasma_lv,
    laser_lv = s.laser_lv,
    thrusting = false,
    t_cols = s.t_cols,
    resources = 0,
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
  -- insert at front so player draws beneath enemies/bullets
  add(entities, p, 1)
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

  -- thruster particles: spawn every few frames when moving
  if obj.thrusting and flr(t() * 60) % 2 == 0 then
    burst_thruster(obj.x + 4, obj.y + 8, obj.t_cols, 1)
  end

  -- clamp to screen bounds
  obj.x = mid(0, obj.x, 120)
  obj.y = mid(0, obj.y, 120)
end

function fire_bullet(obj)
  local btype = obj.weapon
  if btype == "basic" then
    local b = make_bullet(obj, "basic")
    add(entities, b)
    add(bullets, b)
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
    add(entities, b1) add(bullets, b1)
    add(entities, b2) add(bullets, b2)
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
    local b = make_bullet(obj, "laser")
    add(entities, b) add(bullets, b)
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

  if obj.iframes > 0 then
    local ni = obj.iframes / max(1, obj.max_iframes)
    -- quadratic ease-in: slow blink at start, fast blink near end
    local period = max(2, flr(ni * ni * 12) + 2)
    if (obj.iframes % period) < flr(period / 2) then
      return
    end
  end

  draw_thruster(obj, dx)
  spr(s, obj.x, obj.y)

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
  p.max_iframes = frames
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

-- base entity constructor: creates a table with shared fields
-- and default update/draw stubs that call self:move() / self:render().
-- specialized constructors call this, then override what they need.
function make_ent(tag, x, y)
  local e = {}
  e.tag = tag
  e.x = x
  e.y = y
  e.dead = false
  -- default stubs (overridden per-type)
  e.move = function(self) end
  e.render = function(self) end
  -- colon-style dispatch: self is the entity table
  e.update = function(self)
    self:move()
    if self.dead then return end
  end
  e.draw = function(self)
    self:render()
  end
  return e
end

function move_straight(e)
  -- intentionally empty: vy alone moves enemy straight down
end

function move_diver(e)
  if flr(t() * 60) % 4 == 0 then
    burst_thruster(e.x + 4, e.y, { 8, 9, 7 }, -1)
  end
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
    local eb = make_enemy_bullet(e)
    add(entities, eb)
    add(ebullets, eb)
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
    sp = S_ENEMY, pts = 20, move = move_diver,
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
      spr(S_ENEMY3 + flr(t() * 4) % 2, en.x, en.y)
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

-- hunter: a state-machine enemy.
-- state patrol: slides sideways at fixed depth, watching the player.
-- state dive:   drops straight toward the player at high speed.
-- 'e.state' holds whichever function is currently active;
-- e.update calls self:state() each frame to run it.
function make_hunter()
  local e = make_ent("enemy", 10 + rnd(100), -8)
  e.sp = S_ENEMY3
  e.dx = (rnd(1) > 0.5) and 0.8 or -0.8
  -- patrol direction
  e.vy = 0
  e.w = 8
  e.h = 8
  e.pts = 60
  e.gem_tier = 3
  e.patrol_y = 10 + rnd(20)
  -- Y to hold during patrol

  -- state 1: slide sideways until x is within 8px of the player
  e.patrol = function(self)
    self.x += self.dx
    -- bounce off screen edges
    if self.x < 4 then
      self.x = 4
      self.dx = 0.8
    elseif self.x > 118 then
      self.x = 118
      self.dx = -0.8
    end
    -- approach the patrol depth
    local dy = self.patrol_y - self.y
    self.y += dy * 0.05
    -- switch to dive when roughly aligned with player
    if abs(self.x - p.x) < 10 then
      self.state = self.dive
    end
  end

  -- state 2: drop straight down fast
  e.dive = function(self)
    self.vy += 0.15
    -- accelerate downward
    if self.vy > 4 then self.vy = 4 end
    self.y += self.vy
    if flr(t() * 60) % 3 == 0 then
      burst_thruster(self.x + 4, self.y, { 10, 9, 8 }, -1)
    end
    if self.y > 128 then self.dead = true end
  end

  -- start in patrol state
  e.state = e.patrol

  -- override move: just dispatch to whichever state is current
  e.move = function(self)
    self:state()
  end

  -- yellow/gold palette: distinct from other enemy types
  e.render = function(self)
    local diving = (self.state == self.dive)
    if diving then
      pal(3, 9) pal(11, 10) pal(12, 9)
      pal(7, 10) pal(6, 9)
    else
      pal(3, 4) pal(11, 14) pal(12, 4)
      pal(7, 14) pal(6, 4)
    end
    spr(S_ENEMY3 + flr(t() * 4) % 2, self.x, self.y)
    pal()
    -- draw a targeting reticle while patrolling
    if not diving then
      local blink = flr(t() * 6) % 2 == 0
      if blink then
        line(self.x + 4, self.y + 9, self.x + 4, self.y + 14, 14)
      end
    end
    if self.flash and self.flash > 0 then
      for c = 0, 15 do pal(c, 7) end
      spr(S_ENEMY3 + flr(t() * 4) % 2, self.x, self.y)
      pal()
      self.flash -= 1
    end
  end

  return e
end

function spawn_hunter()
  local e = make_hunter()
  add(entities, e)
  add(enemies, e)
end

function make_bullet(obj, btype)
  local s = S_BULLET
  local v = -4
  if btype == "plasma" then
    s = S_BULLET_PLASMA v = -5
  end
  if btype == "laser" then
    s = S_BULLET_LASER v = -6
  end
  local e = make_ent("bullet", obj.x, obj.y - 4)
  e.sp = s
  e.vy = v
  e.w = 8
  e.h = 8
  e.hx = 2
  e.hw = 4
  e.btype = btype
  -- move: fly upward, expire when off-screen
  e.move = function(self)
    self.y += self.vy
    if self.y < -8 then self.dead = true end
  end
  -- render: two-frame animation driven by t()
  e.render = function(self)
    spr(self.sp + flr(t() * 12) % 2, self.x, self.y)
  end
  return e
end

-- enemy bullet aimed toward the player at time of firing
function make_enemy_bullet(src)
  local dx = (p.x + 4) - (src.x + 4)
  local dy = (p.y + 4) - (src.y + 4)
  local d = sqrt(dx * dx + dy * dy)
  if d == 0 then d = 1 end
  local spd = 2.2
  local e = make_ent("ebullet", src.x + 1, src.y + 8)
  e.vx = (dx / d) * spd
  e.vy = (dy / d) * spd
  e.w = 4
  e.h = 4
  -- move: travel in aimed direction, expire when off-screen
  e.move = function(self)
    self.x += self.vx
    self.y += self.vy
    if self.y > 136 or self.y < -16
        or self.x < -16 or self.x > 144 then
      self.dead = true
    end
  end
  -- render: 2x2 pixel bolt, hot-core color ramp
  e.render = function(self)
    pset(self.x, self.y, 8)
    pset(self.x + 1, self.y, 9)
    pset(self.x, self.y + 1, 9)
    pset(self.x + 1, self.y + 1, 10)
  end
  return e
end

function spawn_enemy(type_name)
  local td = enemy_types[type_name]
  local dfn = td.draw_fn
  local e = make_ent("enemy", td.mk_x(), -8)
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
    td.move(self)
    -- delegates to the enemy_types steering fn
    if self.y > 128 then self.dead = true end
  end
  -- render: use the type's custom draw_fn if present, else
  -- fall back to the animated sprite default.
  e.render = function(self)
    if dfn then
      dfn(self)
    else
      spr(self.sp + flr(t() * 4) % 2, self.x, self.y)
    end
    if self.flash and self.flash > 0 then
      for c = 0, 15 do pal(c, 7) end
      spr(self.sp + flr(t() * 4) % 2, self.x, self.y)
      pal()
      self.flash -= 1
    end
  end
  td.extra(e)
  e.gem_tier = td.gem_tier or 1
  add(entities, e)
  add(enemies, e)
end

function make_explosion(x, y)
  local e = make_ent("explosion", x, y)
  e.t = 12
  -- move: count down the timer, mark dead when done
  -- 'self' here refers to the explosion table (e)
  e.move = function(self)
    self.t -= 1
    if self.t <= 0 then self.dead = true end
  end
  -- render: pick the right explosion frame and draw a ring
  e.render = function(self)
    local s = S_EXPL_1
    if self.t < 4 then
      s = S_EXPL_3
    elseif self.t < 8 then
      s = S_EXPL_2
    end
    spr(s, self.x, self.y)
    if self.t > 8 then
      local prog = (12 - self.t) / 4
      local r = flr(prog * (2 - prog) * 6)
      circ(self.x + 4, self.y + 4, r, 10)
      circ(self.x + 4, self.y + 4, r + 2, 9)
    end
  end
  return e
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

-- helper: add a gem to both entity list and gems sub-list
function spawn_gem(x, y, tier)
  local g = make_gem(x, y, tier)
  add(entities, g)
  add(gems, g)
end

function make_gem(x, y, tier)
  local val = tier == 3 and 4 or (tier == 2 and 2 or 1)
  return {
    tag = "gem", x = x, y = y, w = 8, h = 8,
    hx = 1, hy = 1, hw = 6, hh = 6,
    vy = 0.5, tier = tier, value = val,
    update = function(g)
      local dx = p.x + 4 - g.x
      local dy = p.y + 4 - g.y
      local dist = sqrt(dx * dx + dy * dy)
      if stage_completing or dist < 24 then
        local spd = stage_completing and 3 or (24 - dist) / 24 * 2
        g.x += dx / dist * spd
        g.y += dy / dist * spd
      else
        g.y += g.vy
      end
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
  local e = make_ent("debris", x, y)
  e.vx = cos(ang) * spd
  e.vy = sin(ang) * spd - 0.5
  e.life = life
  e.ml = life
  e.col = col
  -- move: physics step ヌ█⬆️ gravity drag and lifetime countdown
  e.move = function(self)
    self.x += self.vx
    self.y += self.vy
    self.vy += 0.05
    -- gravity
    self.vx *= 0.97
    -- drag
    self.life -= 1
    if self.life <= 0 then self.dead = true end
  end
  -- render: fade from bright to dark as lifetime expires
  e.render = function(self)
    local f = self.life / self.ml
    local c = f > 0.5 and self.col or (f > 0.2 and 5 or 1)
    pset(self.x, self.y, c)
    if f > 0.5 then pset(self.x - self.vx * .4, self.y - self.vy * .4, 1) end
  end
  return e
end

-- ============================================================
-- particle system
-- ============================================================
-- make_particle(x, y, opts) -- core constructor
--
-- opts fields (all optional, defaults shown):
--   cols   = {7}       palette of PICO-8 colour indices to pick from
--   ang    = rnd(1)    launch angle in PICO-8 turns (0-1)
--   ang_r  = 1         if >0, angle is fully random; if <1 it narrows
--                      the arc (0 = shoot exactly at ang)
--   spd    = 1+rnd(2)  launch speed in px/frame
--   life   = 20+rnd(20) frames the particle lives
--   grav   = 0         gravity added to vy each frame
--   drag   = 0.98      multiplier applied to vx,vy each frame
--   fade   = true      colour shifts dark as life expires
--   size   = 1         1=single pixel, 2=2れ❎2 block, 0=trail only
--   trail  = false     draw a short 1-px tail behind the particle
-- ============================================================
function make_particle(x, y, opts)
  opts = opts or {}

  -- resolve options with defaults
  local cols  = opts.cols  or { 7 }
  local col   = cols[flr(rnd(#cols)) + 1]
  local ang   = opts.ang   ~= nil and opts.ang or rnd(1)
  local ar    = opts.ang_r ~= nil and opts.ang_r or 1
  local spd   = opts.spd   ~= nil and opts.spd  or (1 + rnd(2))
  local life  = opts.life  ~= nil and opts.life  or (20 + rnd(20))
  local grav  = opts.grav  or 0
  local drag  = opts.drag  ~= nil and opts.drag  or 0.98
  local fade  = opts.fade  ~= false  -- default true
  local size  = opts.size  ~= nil and opts.size  or 1
  local trail = opts.trail or false

  -- arc spread: ar=1 ヌ●★ fully random; ar=0 ヌ●★ exact angle
  local a = ang + (rnd(ar) - ar * 0.5)

  local e = make_ent("particle", x, y)
  e.vx   = cos(a) * spd
  e.vy   = sin(a) * spd
  e.life = life
  e.ml   = life
  e.col  = col

  e.move = function(self)
    self.x  += self.vx
    self.y  += self.vy
    self.vy += grav
    self.vx *= drag
    self.vy *= drag
    self.life -= 1
    if self.life <= 0 then self.dead = true end
  end

  e.render = function(self)
    local f = self.life / self.ml   -- 1ヌ●★0 as particle ages
    -- colour fade: bright ヌ●★ mid ヌ●★ dark
    local c = self.col
    if fade then
      if f < 0.25 then c = 1
      elseif f < 0.5 then c = 5
      end
    end
    -- draw trail behind motion vector
    if trail and f > 0.4 then
      pset(self.x - self.vx * 0.5,
           self.y - self.vy * 0.5, 1)
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
-- burst helpers ヌ█⬆️ call these at an event site, they spawn
-- several particles and add them to entities automatically.
-- ============================================================

-- spark burst: sharp bright sparks flying outward
-- use for: bullet impact, ship hit, explosion accent
function burst_sparks(x, y, n, cols)
  n    = n    or 6
  cols = cols or { 7, 9, 10 }
  for i = 1, n do
    add(entities, make_particle(x, y, {
      cols  = cols,
      spd   = 1.5 + rnd(2.5),
      life  = 10 + rnd(12),
      grav  = 0.04,
      drag  = 0.94,
      trail = true,
      size  = 1
    }))
  end
end

-- smoke puff: slow, heavy, fades dark ヌ█⬆️ use for: enemy death,
-- engine exhaust, big explosions
function burst_smoke(x, y, n, cols)
  n    = n    or 5
  cols = cols or { 5, 6, 13 }
  for i = 1, n do
    add(entities, make_particle(x, y, {
      cols = cols,
      spd  = 0.2 + rnd(0.6),
      life = 25 + rnd(20),
      grav = -0.01,   -- slight upward drift
      drag = 0.96,
      fade = true,
      size = 2
    }))
  end
end

-- thruster glow: tight upward cone ヌ█⬆️ use for: player/enemy
-- engines, boost pickups
-- dir: 1=upward (player), -1=downward (enemy)
function burst_thruster(x, y, cols, dir)
  dir  = dir  or 1
  cols = cols or { 8, 9, 10 }
  -- cone faces "up" in screen space (negative y = up)
  -- PICO-8 sin/cos: 0.25 = up, 0.75 = down
  local base_ang = dir == 1 and 0.25 or 0.75
  for i = 1, 3 do
    add(entities, make_particle(x, y, {
      cols  = cols,
      ang   = base_ang,
      ang_r = 0.12,     -- narrow 43るぬ cone
      spd   = 0.8 + rnd(1.2),
      life  = 6 + rnd(8),
      grav  = 0,
      drag  = 0.9,
      fade  = true,
      trail = false,
      size  = 1
    }))
  end
end

-- optimized collision: uses typed sub-lists so we only check
-- bulletsれ❎enemies (layer filtering) instead of entitiesれ❎entities.
function check_collisions()
  -- 1. player bullets vs enemies
  for en in all(enemies) do
    if not en.dead then
      for b in all(bullets) do
        if not b.dead and collide(en, b) then
          b.dead = true
          if en.hp and en.hp > 1 then
            en.hp -= 1
            en.flash = 3
            play_sound(8)
          else
            play_sound(1)
            add(entities, make_explosion(en.x, en.y))
            add(entities, make_popup(en.x, en.y, en.pts))
            burst_sparks(en.x + 4, en.y + 4, 8, { 7, 9, 10 })
            burst_smoke(en.x + 4, en.y + 4, 4)
            en.dead = true
            score += en.pts
            level_kills += 1
            if level_kills >= level * 8 then
              level += 1
              level_kills = 0
              stage_completing = true
              for e in all(entities) do
                if e.tag ~= "gem" and e.tag ~= "player" then e.dead = true end
              end
              -- sub-lists will be cleaned up in the main update loop
              return
            end
            shake_screen(2, 8)
            local drop = en.gem_tier == 3 and 70 or (en.gem_tier == 2 and 50 or 30)
            if rnd(100) < drop then
              spawn_gem(en.x, en.y, en.gem_tier)
            end
          end
        end
      end
      -- 2. enemy body vs player (no iframes needed on enemy bullets)
      if p.iframes <= 0 and collide(p, en) then
        play_sound(2)
        add(entities, make_explosion(en.x, en.y))
        burst_sparks(en.x + 4, en.y + 4, 6, { 8, 9, 7 })
        en.dead = true
        damage_player(60)
        shake_screen(3, 12)
        hit_flash_t = 8
      end
    end
  end
  -- 3. enemy bullets vs player
  if p.iframes <= 0 then
    for eb in all(ebullets) do
      if not eb.dead and collide(p, eb) then
        eb.dead = true
        damage_player(50)
        shake_screen(2, 8)
        hit_flash_t = 6
        play_sound(2)
      end
    end
  end
  -- 4. gems vs player
  for g in all(gems) do
    if not g.dead and collide(p, g) then
      p.resources += g.value
      g.dead = true
      add(entities, make_popup(g.x, g.y, g.value))
      play_sound(9)
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
000000000008800000e00e0000566500088000000080000000565000000008800000800000056500088008800080080000800800008008000880088008800880
000000000087780000e00e000567765008780000008e00000556600000008780000e800000066550899889980898898000899800089889808888888880088008
00000000008cc80000e88e00056cc65008c80000008e00000556600000008c80000e80000006655089aa9aa8089aa980008aa800089aa9808888888880000008
00000000058cc8500e8888e00056650052c850000278e0000056500000058c2500e872000005650008aaaa80089aa980008aa800008aa8008888888880000008
000000005881188508877880000660005218550002c8e000000600000055812500e8c20000006000008aa800008aa80000899800008998000888888008000080
0000000058588585888cc888006556000585250008c8e000005560000052525000e8c80000065500000880000008800000088000000880000088880000800800
000000000055550088800888056cc6500055000088588e0005556000000055000e88588000065550000000000008800000088000000000000008800000088000
00000000007007005500005505c00c50077000005605650005cc660000000770057507500066cc50000000000000000000088000000000000000000000000000
00000000000000000000000000080000000800000000000000000000000b00000030300000000000009a0a900500005000000000000000000000000000000000
0000000000000000000000000089800000898000001cc10000111100000b0000003b30000007700009a77a905006600500000000000000000000000000000000
000000000000000000000000089a98000897980001cddc10011cc110003b3000003b3000007aa7009a7887a90060060000000000000000000000000000000000
000a0000000700000007000008a7a800087778000cddddc001cccc10003b3000000b0000007aa700a787787a0600006000073000000b70000000000000000000
009aa90000c77c0000b77b00009a9000009790000cddddc001cccc10003b3000000b000000077000a787787a060000600076b300003b67000000000000000000
008aa800001cc100003bb300008980000089800001cddc10011cc110003b3000003b3000000000009a7887a90060060000b6b300003b6b000000000000000000
00899800001dd100003bb3000008000000080000001cc10000111100000b0000003b30000000000009a77a90500660050033b300003b63000000000000000000
00088000000110000003300000000000000000000000000000000000000b00000030300000000000009aa9000500005000033000000330000000000000000000
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
000500003005034050370503c05000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
