-- entities.lua
-- base entity constructor, standard enemies, bullets, spawner, and collisions

-- base entity constructor
function make_ent(tag, x, y)
  return {
    tag = tag, x = x, y = y, dead = false,
    update = function(s) if s.move then s:move() end end,
    draw = function(s) if s.render then s:render() end end
  }
end

-- zigzag trajectory steering motion helper
function move_zigzag(e)
  e.phase = (e.phase + 0.008) % 1
  e.x = mid(0, e.ox + 30 * sin(e.phase), 120)
end

-- standard ticking of an effect lifetime
function tick_life(s)
  s.h += 1
  if s.h > s.max_h then s.dead = true end
end

-- build a player projectile bullet
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
  e.move = function(self)
    self.x += self.vx
    self.y += self.vy
    if self.btype == "plasma" and flr(self.y) % 2 == 0 then
      add(entities, make_particle(self.x + 3, self.y + 4, { cols = { 12, 13, 7 }, ang = 0.75, ang_r = 0.1, spd = 0.5 + rnd(0.5), life = 6 }))
    elseif self.btype == "laser" and flr(self.y) % 2 == 0 then
      add(entities, make_particle(self.x + 3, self.y + 4, { cols = { 7, 10, 9 }, ang = 0.75, ang_r = 0.1, spd = 1 + rnd(0.5), life = 8, trail = true }))
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
      local bx, by = self.x + 3, self.y
      rectfill(bx, by,     bx + 1, by,     7)
      rectfill(bx, by + 1, bx + 1, by + 1, 10)
      rectfill(bx, by + 2, bx + 1, by + 2, 9)
      rectfill(bx, by + 3, bx + 1, by + 3, 8)
    end
  else
    e.render = function(self)
      spr(self.sp + tf(12, 2), self.x, self.y)
    end
  end

  -- Apply Archetype Weapon Modifications
  if obj.tag == "player" then
    if obj.spray_variance then
      e.vx += rnd(obj.spray_variance) - (obj.spray_variance * 0.5)
    end
    if obj.always_pierce then
      e.pierce = true
      e.hp_left = dmg + 1
    end
  end

  return e
end

-- build aimed enemy projectile bullet
function make_enemy_bullet(src, spd)
  local a = angle_to(src.x + 4, src.y + 4, p.x + 4, p.y + 4)
  spd = spd or 1.4
  local e = make_ent("ebullet", src.x + 1, src.y + 8)
  e.vx = cos(a) * spd
  e.vy = sin(a) * spd
  e.w = 6
  e.h = 6
  e.hx = 1
  e.hy = 1
  e.hw = 4
  e.hh = 4
  e.is_boss = src.is_boss
  e.move = function(self)
    self.x += self.vx
    self.y += self.vy
    add(entities, make_particle(self.x + 2, self.y + 2, { cols = { 10, 9, 8 }, ang = 0.75, ang_r = 0.25, spd = 0.6, life = 8 }))
    if self.y > 136 or self.y < -16 or self.x < -16 or self.x > 144 then
      self.dead = true
    end
  end
  e.render = function(self)
    if self.is_boss then
      spr(17 + tf(4, 2), self.x, self.y)
    else
      local cx, cy = self.x + 3, self.y + 3
      circfill(cx, cy, 2, 9)
      circfill(cx, cy, 1, 10)
      pset(cx, cy, 7)
    end
  end
  return e
end

-- standard enemies definitions table
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
  shooter = {
    sp = S_ENEMY, pts = 40,
    move = function(e)
      e.shoot_t -= 1
      if e.shoot_t <= 0 then
        e.shoot_t = 55
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
    extra = function(e) e.hp = 7 e.shoot_t = 60 end
  },
  spinner = {
    sp = S_ENEMY4, pts = 40,
    move = function(e)
      move_zigzag(e)
      e.shoot_t -= 1
      if e.shoot_t <= 0 then
        e.shoot_t = 50
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
  }
}

-- load a sequence of enemy spawns into the queue
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

-- spawn an enemy of specified type
function spawn_enemy(type_name, ox)
  local td = enemy_types[type_name]
  local dfn = td.draw_fn
  local e = make_ent("enemy", (ox and ox > 0) and ox or td.mk_x(), -8)
  e.sp = td.sp
  e.vy = td.mk_vy()
  e.w = 8
  e.h = 8
  e.pts = td.pts
  e.move = function(self)
    self.y += self.vy
    if td.move then td.move(self) end
    if self.y > 128 then self.y = -8 end
  end
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

-- destroy enemy and trigger explosion score rewards
function kill_enemy(en)
  sfx(1)
  local cx, cy = en.x + 4, en.y + 4
  make_boom(cx, cy)
  add(entities, make_popup(en.x, en.y, en.pts))
  en.dead = true
  if en.is_boss then
    boss_ent = nil
    hit_stop_t = 3
    go_to_win()
    return true
  end

  score += en.pts
  if level then
    level_kills += 1
  end
  shake_screen(2, 8)
end

-- draw pure white flash overlay when taking hit
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

-- collision checker
function check_collisions()
  -- 1. player bullets vs enemies
  for en in all(enemies) do
    if not en.dead then
      local ecx, ecy = en.x + 4, en.y + 4
      for b in all(bullets) do
        if not b.dead and collide(en, b) then
          local dmg = b.dmg or 1
          if en.armor then dmg = max(1, dmg - en.armor) end
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
      -- 2. enemy body vs player
      if p.iframes <= 0 and collide(p, en) then
        hit_player("heavy", ecx, ecy)
        if not en.is_boss then
          en.dead = true
        end
      end
    end
  end
  -- 3. enemy bullets vs player
  for eb in all(ebullets) do
    if not eb.dead then
      if p.iframes <= 0 and collide(p, eb) then
        eb.dead = true
        hit_player("light")
      -- graze detection
      elseif not eb.grazed then
        local gx, gy = p.x + 1, p.y + 1
        local bx, by = eb.x + (eb.hx or 0), eb.y + (eb.hy or 0)
        local bw, bh = eb.hw or eb.w, eb.hh or eb.h
        if not (gx >= bx + bw or gx + 6 <= bx or gy >= by + bh or gy + 6 <= by) then
          eb.grazed = true
          score += 1
          add(entities, make_particle(p.x + 4, p.y + 4, { cols = { 7, 12 }, spd = 0.5, life = 5 }))
        end
      end
    end
  end
end
