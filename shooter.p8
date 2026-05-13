pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
-- tab 0: globals + init + state machine

state = {}
p = nil
entities = {}
bullets = {}
enemies = {}
sublists = {}
stars = {}
score = 0
hi_score = 0
final_score = 0
lives = 3
shake_t = 0
shake_mag = 0
hit_flash_t = 0
spawn_timer = 0
spawn_interval = 90
go_t = 0
wave = 1
max_waves = 5
wave_total = 0
wave_spawned = 0
wave_pause = false
wave_pause_t = 0

function _init()
  hi_score = 0
  final_score = 0
  init_stars()
  go_to_title()
end

function _update60()
  state.update()
end

function _draw()
  cls(1)
  state.draw()
end

function go_to_title()
  entities = {}
  state = title_state
end

function go_to_game()
  game_state.init()
  state = game_state
end

function go_to_gameover()
  go_t = 0
  final_score = score
  if final_score > hi_score then hi_score = final_score end
  state = gameover_state
end

function go_to_win()
  go_t = 0
  final_score = score
  if final_score > hi_score then hi_score = final_score end
  state = win_state
end

-->8
-- tab 1: state tables

title_state = {
  update = function()
    update_stars()
    if btnp(4) or btnp(5) then
      go_to_game()
    end
  end,
  draw = function()
    draw_stars()
    print("space shooter", 38, 40, 7)
    if flr(t() * 2) % 2 == 0 then
      print("press z to start", 32, 80, 6)
    end
    if hi_score > 0 then
      print("best: " .. hi_score, 44, 96, 5)
    end
  end
}

game_state = {
  init = function()
    score = 0
    lives = 3
    entities = {}
    bullets = {}
    enemies = {}
    sublists = { bullet = bullets, enemy = enemies }
    wave         = 1
    wave_total   = 4 + wave * 2
    wave_spawned = 0
    wave_pause   = false
    wave_pause_t = 0
    spawn_timer  = 60
    shake_t = 0
    shake_mag = 0
    hit_flash_t = 0
    init_player()
  end,
  update = function()
    update_stars()
    if wave_pause then
      wave_pause_t -= 1
      if wave_pause_t <= 0 or btnp(4) or btnp(5) then
        wave += 1
        wave_total   = 4 + wave * 2
        wave_spawned = 0
        spawn_timer  = 60
        wave_pause   = false
      end
    elseif wave_spawned < wave_total then
      spawn_timer -= 1
      if spawn_timer <= 0 then
        if rnd(1) < (wave > 2 and 0.4 or 0.2) then
          spawn_enemy_b()
        else
          spawn_enemy_a()
        end
        wave_spawned += 1
        spawn_timer = max(30, 90 - (wave - 1) * 12)
      end
    elseif #enemies == 0 then
      if wave >= max_waves then
        go_to_win()
      else
        wave_pause   = true
        wave_pause_t = 120
      end
    end
    for e in all(entities) do
      e.update(e)
      if e.dead and e.tag ~= "player" then
        del(entities, e)
        if sublists[e.tag] then del(sublists[e.tag], e) end
      end
    end
    if not p.dead then check_collisions() end
    if shake_t > 0 then
      shake_t -= 1
      shake_mag *= 0.85
    end
    if hit_flash_t > 0 then hit_flash_t -= 1 end
  end,
  draw = function()
    apply_shake()
    draw_stars()
    for e in all(entities) do
      e.draw(e)
    end
    camera()
    if hit_flash_t > 0 then rect(0, 0, 127, 127, 8) end
    draw_hud()
    if wave_pause then
      local pct = 1 - wave_pause_t / 120
      print("wave " .. wave .. " clear!", 34, 54, 11)
      print("wave " .. (wave + 1) .. " incoming", 30, 66, 9)
      rectfill(20, 78, 20 + flr(pct * 88), 80, 10)
      rect(20, 78, 108, 80, 5)
    end
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
    if go_t > 90 and (btnp(4) or btnp(5)) then
      go_to_game()
    end
  end,
  draw = function()
    draw_stars()
    for e in all(entities) do
      e.draw(e)
    end
    camera()
    local ty = 45
    if go_t < 30 then
      local pr = go_t / 30
      ty = -20 + (1 - (1 - pr) ^ 3) * 65
    end
    print("game over", 38, ty, 8)
    if go_t > 45 then
      print("score: " .. final_score, 38, ty + 16, 7)
    end
    if go_t > 60 then
      local hc = final_score >= hi_score and 10 or 6
      print("best:  " .. hi_score, 38, ty + 24, hc)
    end
    if go_t > 90 and flr(go_t / 8) % 2 == 0 then
      print("z: play again", 34, ty + 40, 6)
    end
  end
}

win_state = {
  update = function()
    go_t += 1
    update_stars()
    for e in all(entities) do
      e.update(e)
      if e.dead then del(entities, e) end
    end
    if go_t > 90 and (btnp(4) or btnp(5)) then go_to_title() end
  end,
  draw = function()
    draw_stars()
    for e in all(entities) do e.draw(e) end
    camera()
    local ty = 45
    if go_t < 30 then
      local pr = go_t / 30
      ty = -20 + (1 - (1 - pr) ^ 3) * 65
    end
    print("you win!", 40, ty, 11)
    if go_t > 45 then
      print("score: " .. final_score, 38, ty + 16, 7)
    end
    if go_t > 60 then
      local hc = final_score >= hi_score and 10 or 6
      print("best:  " .. hi_score, 38, ty + 24, hc)
    end
    if go_t > 90 and flr(go_t / 8) % 2 == 0 then
      print("z: title", 40, ty + 40, 6)
    end
  end
}

-->8
-- tab 2: player

function init_player()
  p = {
    tag = "player",
    x = 60, y = 100,
    vx = 0, vy = 0,
    accel = 0.45,
    fric = 0.85,
    max_speed = 3,
    w = 8, h = 8,
    hx = 2, hy = 2, hw = 4, hh = 4,
    fire_delay = 0,
    iframes = 0,
    dead = false,
    update = function(self)
      if not self.dead then update_player(self) end
    end,
    draw = function(self)
      draw_player(self)
    end
  }
  add(entities, p, 1)
end

function update_player(obj)
  local ax, ay = 0, 0
  if btn(0) then ax -= obj.accel end
  if btn(1) then ax += obj.accel end
  if btn(2) then ay -= obj.accel end
  if btn(3) then ay += obj.accel end
  if ax ~= 0 and ay ~= 0 then
    ax *= 0.707
    ay *= 0.707
  end
  if (btn(4) or btn(5)) and obj.fire_delay <= 0 then
    fire_bullet(obj)
    obj.fire_delay = 8
  end
  if obj.fire_delay > 0 then obj.fire_delay -= 1 end
  if obj.iframes > 0 then obj.iframes -= 1 end
  obj.vx = obj.vx * obj.fric + ax
  obj.vy = obj.vy * obj.fric + ay
  local v = sqrt(obj.vx * obj.vx + obj.vy * obj.vy)
  if v > obj.max_speed then
    obj.vx = (obj.vx / v) * obj.max_speed
    obj.vy = (obj.vy / v) * obj.max_speed
  end
  if abs(obj.vx) < 0.05 then obj.vx = 0 end
  if abs(obj.vy) < 0.05 then obj.vy = 0 end
  obj.x += obj.vx
  obj.y += obj.vy
  if (ax ~= 0 or ay ~= 0) and flr(t() * 60) % 2 == 0 then
    burst_thruster(obj.x + 4, obj.y + 8, {8, 9, 10}, 1)
  end
  if obj.x < 4   then obj.x = 4;   obj.vx = 0 end
  if obj.x > 120 then obj.x = 120; obj.vx = 0 end
  if obj.y < 10  then obj.y = 10;  obj.vy = 0 end
  if obj.y > 120 then obj.y = 120; obj.vy = 0 end
end

function draw_player(obj)
  if obj.iframes > 0 then
    local ni = obj.iframes / 60
    local period = max(2, flr(ni * ni * 12) + 2)
    if (obj.iframes % period) < flr(period / 2) then return end
  end
  local cx = obj.x + 4
  local cy = obj.y + 4
  line(cx,     cy - 5, cx - 4, cy + 3, 7)
  line(cx,     cy - 5, cx + 4, cy + 3, 7)
  line(cx - 4, cy + 3, cx + 4, cy + 3, 7)
  pset(cx, cy + 3, 9)
end

function fire_bullet(obj)
  local b = make_bullet(obj.x + 4, obj.y - 2)
  add(entities, b)
  add(bullets, b)
  burst_thruster(obj.x + 4, obj.y - 2, {9, 10, 7}, -1)
  sfx(0)
end

-->8
-- tab 3: entities

function make_ent(tag, x, y)
  local e = {}
  e.tag = tag
  e.x = x
  e.y = y
  e.dead = false
  e.move = function(self) end
  e.render = function(self) end
  e.update = function(self)
    self:move()
    if self.dead then return end
  end
  e.draw = function(self)
    self:render()
  end
  return e
end

function make_bullet(x, y)
  local e = make_ent("bullet", x, y)
  e.vy = -6
  e.w = 2
  e.h = 5
  e.move = function(self)
    self.y += self.vy
    if self.y < -8 then self.dead = true end
  end
  e.render = function(self)
    line(self.x, self.y, self.x, self.y + 4, 10)
    pset(self.x, self.y, 7)
  end
  return e
end

function make_enemy_a()
  local e = make_ent("enemy", rnd(114) + 4, -8)
  e.vy = 0.8 + rnd(0.4)
  e.w = 6
  e.h = 6
  e.pts = 100
  e.move = function(self)
    self.y += self.vy
    if self.y > 136 then self.dead = true end
  end
  e.render = function(self)
    rectfill(self.x, self.y, self.x + 5, self.y + 5, 8)
    rect(self.x, self.y, self.x + 5, self.y + 5, 9)
  end
  return e
end

function make_enemy_b()
  local e = make_ent("enemy", 20 + rnd(88), -8)
  e.vy = 0.6 + rnd(0.4)
  e.w = 6
  e.h = 6
  e.pts = 200
  e.ox = e.x
  e.phase = rnd(1)
  e.move = function(self)
    self.phase = (self.phase + 0.008) % 1
    self.x = mid(4, self.ox + 28 * sin(self.phase), 118)
    self.y += self.vy
    if self.y > 136 then self.dead = true end
  end
  e.render = function(self)
    local cx = self.x + 3
    local cy = self.y + 3
    line(cx,     cy - 3, cx + 3, cy,     9)
    line(cx + 3, cy,     cx,     cy + 3, 9)
    line(cx,     cy + 3, cx - 3, cy,     9)
    line(cx - 3, cy,     cx,     cy - 3, 9)
    pset(cx, cy, 10)
  end
  return e
end

function spawn_enemy_a()
  local e = make_enemy_a()
  add(entities, e)
  add(enemies, e)
end

function spawn_enemy_b()
  local e = make_enemy_b()
  add(entities, e)
  add(enemies, e)
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
    print("+" .. self.pts, self.x, self.y, c)
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

function kill_enemy(en)
  en.dead = true
  score += en.pts
  make_explosion(en.x + 3, en.y + 3)
  add(entities, make_popup(en.x, en.y, en.pts))
  sfx(1)
end

function damage_player()
  if p.iframes > 0 then return end
  lives -= 1
  p.iframes = 60
  shake_screen(3, 12)
  hit_flash_t = 8
  burst_sparks(p.x + 4, p.y + 4, 6, {7, 8, 9})
  add(entities, make_shockwave(p.x + 4, p.y + 4, true))
  sfx(2)
  if lives <= 0 then
    p.dead = true
    go_to_gameover()
  end
end

function check_collisions()
  for en in all(enemies) do
    if not en.dead then
      for b in all(bullets) do
        if not b.dead and not en.dead and collide(en, b) then
          b.dead = true
          add(entities, make_hit_flash(en.x + 3, en.y + 3))
          kill_enemy(en)
        end
      end
      if p.iframes <= 0 and collide(p, en) then
        en.dead = true
        damage_player()
      end
    end
  end
end

-->8
-- tab 4: particles

function make_particle(x, y, opts)
  opts = opts or {}
  local cols  = opts.cols  or { 7 }
  local col   = cols[flr(rnd(#cols)) + 1]
  local ang   = opts.ang   ~= nil and opts.ang or rnd(1)
  local ar    = opts.ang_r ~= nil and opts.ang_r or 1
  local spd   = opts.spd   ~= nil and opts.spd  or (1 + rnd(2))
  local life  = opts.life  ~= nil and opts.life  or (20 + rnd(20))
  local grav  = opts.grav  or 0
  local drag  = opts.drag  ~= nil and opts.drag  or 0.98
  local fade  = opts.fade  ~= false
  local size  = opts.size  ~= nil and opts.size  or 1
  local trail = opts.trail or false
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
    local f = self.life / self.ml
    local c = self.col
    if fade then
      if f < 0.2 then c = 1
      elseif f < 0.4 then c = 5
      end
    end
    if trail and f > 0.4 then
      pset(self.x - self.vx * 0.5, self.y - self.vy * 0.5, 1)
    end
    if size == 2 then
      rectfill(self.x, self.y, self.x + 1, self.y + 1, c)
    elseif size == 1 then
      pset(self.x, self.y, c)
    end
  end
  return e
end

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

function burst_smoke(x, y, n, cols)
  n    = n    or 5
  cols = cols or { 5, 6, 13 }
  for i = 1, n do
    add(entities, make_particle(x, y, {
      cols = cols,
      spd  = 0.2 + rnd(0.6),
      life = 25 + rnd(20),
      grav = -0.01,
      drag = 0.96,
      fade = true,
      size = 2
    }))
  end
end

function burst_embers(x, y, n)
  n = n or 5
  for i = 1, n do
    add(entities, make_particle(x, y, {
      cols  = {8, 9, 10},
      ang   = 0.25,
      ang_r = 0.35,
      spd   = 0.2 + rnd(0.7),
      life  = 35 + rnd(30),
      grav  = -0.015,
      drag  = 0.97,
      fade  = true,
      size  = 1
    }))
  end
end

function burst_thruster(x, y, cols, dir)
  dir  = dir  or 1
  cols = cols or { 8, 9, 10 }
  local base_ang = dir == 1 and 0.25 or 0.75
  for i = 1, 2 do
    add(entities, make_particle(x, y, {
      cols  = cols,
      ang   = base_ang,
      ang_r = 0.12,
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

function make_explosion(x, y)
  burst_sparks(x, y, 8, {7, 9, 10})
  burst_smoke(x, y, 4)
  burst_embers(x, y, 3)
  shake_screen(2, 8)
  add(entities, make_shockwave(x, y))
end

function make_shockwave(x, y, big)
  local e = make_ent("shockwave", x, y)
  e.h     = 0
  e.max_h = big and 22 or 16
  e.max_r = big and 28 or 18
  e.move = function(self)
    self.h += 1
    if self.h > self.max_h then self.dead = true end
  end
  e.render = function(self)
    local f = self.h / self.max_h
    local r = flr(self.max_r * f)
    local c = 7
    if f > 0.3  then c = 10 end
    if f > 0.6  then c = 9  end
    if f > 0.85 then c = 4  end
    if r > 0 then
      circ(self.x, self.y, r, c)
      if f < 0.5 and r > 1 then
        circ(self.x, self.y, r - 1, c)
      end
    end
  end
  return e
end

-->8
-- tab 5: stars + utils

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

function shake_screen(mag, dur)
  shake_t = dur or mag * 4
  shake_mag = mag
end

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

function apply_shake()
  if shake_t > 0 then
    camera(rnd(shake_mag * 2) - shake_mag, rnd(shake_mag * 2) - shake_mag)
  else
    camera()
  end
end

function draw_hud()
  rectfill(0, 0, 127, 9, 0)
  print("score:" .. score, 2, 2, 7)
  print("w" .. wave .. "/" .. max_waves, 56, 2, 6)
  for i = 1, 3 do
    local c = i <= lives and 8 or 1
    rectfill(127 - (i * 8) + 2, 2, 127 - (i * 8) + 6, 6, c)
  end
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__sfx__
000200002c1502a150281402613024120221100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0005000028073000002607200000240710000022070000001e060000001a050000001505000000110400000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000800002c074000002a063000002806200000260510000024040000001e030000001803000000100200000008010000000000000000000000000000000000000000000000000000000000000000000000000000
0005000024570285702b5703057034570375703c5703c5703c5703c5603c5503c5403c5303c5203c5100000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__music__
01 41424344

