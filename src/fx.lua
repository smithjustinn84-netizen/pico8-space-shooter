-- fx.lua
-- shared visual effects (explosions, particles, shockwaves, popups)

-- constructor for explosion entity
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

-- constructor for shockwave entity
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

-- constructor for hit flash hit marker
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

-- constructor for floating score popups
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

-- single particle builder
function make_particle(x, y, opts)
  opts = opts or {}
  local cols = opts.cols or { 7 }
  local col = cols[flr(rnd(#cols)) + 1]
  local ang = opts.ang or rnd(1)
  local ar = opts.ang_r or 1
  local spd = opts.spd or 1 + rnd(2)
  local life = opts.life or 20 + rnd(20)
  local grav = opts.grav or 0
  local drag = opts.drag or 0.98
  local fade = opts.fade ~= false
  local size = opts.size or 1
  local trail = opts.trail or false

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
    local c = self.col
    if fade then
      if f < 0.2 then
        c = 1
      elseif f < 0.4 then
        c = 5
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

-- ============================================================
-- FX burst wrappers: spawns entities directly into the list
-- ============================================================

-- generic particle emitter
function emit_fx(x, y, n, p_opts)
  for i = 1, n do
    add(entities, make_particle(x, y, p_opts))
  end
end

-- spark burst: sharp sparks flying outward
function burst_sparks(x, y, n, cols)
  emit_fx(x, y, n or 6, { cols = cols or SPARK_C, spd = 1.5 + rnd(2.5), life = 10 + rnd(12), grav = 0.04, drag = 0.94, trail = true })
end

-- smoke puff: slow, heavy, fades dark
function burst_smoke(x, y, n, cols)
  emit_fx(x, y, n or 7, { cols = cols or SMOKE_C, spd = 0.2 + rnd(0.6), life = 25 + rnd(20), grav = -0.01, drag = 0.96, fade = true, size = 2 })
end

-- slow hot embers drifting upward
function burst_embers(x, y, n)
  emit_fx(x, y, n or 5, { cols = EMBER_C, ang = 0.25, ang_r = 0.35, spd = 0.2 + rnd(0.7), life = 35 + rnd(30), grav = -0.015, drag = 0.97, fade = true, size = 1 })
end

-- thruster cone: dir determines upward (1) vs downward (-1)
function burst_thruster(x, y, cols, dir)
  local base_ang = (dir or 1) == 1 and 0.25 or 0.75
  emit_fx(x, y, 2, { cols = cols or EMBER_C, ang = base_ang, ang_r = 0.12, spd = 0.8 + rnd(1.2), life = 6 + rnd(8), drag = 0.9, fade = true })
end

-- standard "thing exploded" bundle
function make_boom(x, y, big, sn, smn, en)
  add(entities, make_explosion(big and x or x - 4, big and y or y - 4, big))
  add(entities, make_shockwave(x, y, big))
  burst_sparks(x, y, sn or 8, SPARK_C)
  burst_smoke(x, y, smn or 7)
  burst_embers(x, y, en or 5)
end
