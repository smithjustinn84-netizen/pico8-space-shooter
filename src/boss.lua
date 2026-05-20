-- boss.lua
-- boss AI behavior patterns, movement tracking, and firing routines

-- telegraph line indicator
function boss_telegraph(e)
  local dx = (p.x + 4) - (e.x + 8)
  local dy = (p.y + 4) - (e.y + 8)
  local d = sqrt(dx * dx + dy * dy)
  local tx = e.x + 8 + dx / d * 16
  local ty = e.y + 8 + dy / d * 16
  local tg = make_ent("fx", tx - 1, ty - 1)
  tg.h, tg.max_h = 0, 10
  tg.render = function(s) circfill(s.x + 1, s.y + 1, 1, 8) pset(s.x + 1, s.y + 1, 7) end
  tg.move = tick_life
  add(entities, tg)
end

-- spawn one enemy bullet from boss center
function boss_shoot_one(e, vx, vy)
  local eb = make_enemy_bullet(e, 1)
  eb.x = e.x + 6
  eb.y = e.y + 6
  eb.vx = vx
  eb.vy = vy
  add_e(eb, ebullets)
end

-- spawn spread aimed fan of bullets
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

-- boss fire patterns by phase: 1 (sweeper), 2 (spiral), 3 (storm)
boss_fire = {
  function(e)
    e.p1_step = (e.p1_step or 0) + 1
    if e.p1_step % 2 == 1 then
      boss_aimed_fan(e, 5, 0.06, 1.3)
      e.shoot_t = 25
    else
      boss_aimed_fan(e, 2, 0.10, 1.1)
      boss_telegraph(e)
      e.shoot_t = 20
    end
  end,
  function(e)
    local spd = 1.5
    e.spiral_a = (e.spiral_a or 0) + 0.035
    boss_shoot_one(e, cos(e.spiral_a) * spd, sin(e.spiral_a) * spd)
    boss_shoot_one(e, cos(e.spiral_a + 0.5) * spd, sin(e.spiral_a + 0.5) * spd)
    e.p2_step = (e.p2_step or 0) + 1
    if e.p2_step % 6 == 0 then
      boss_aimed_fan(e, 1, 0, 1.7)
    end
    e.shoot_t = 10
  end,
  function(e)
    e.fire_count = (e.fire_count or 0) + 1
    local m = e.fire_count % 3
    if m == 1 then
      local off = (e.fire_count * 0.07) % 1
      for i = 0, 15 do
        local a = i / 16 + off
        boss_shoot_one(e, cos(a) * 1.4, sin(a) * 1.4)
      end
    elseif m == 2 then
      boss_telegraph(e)
      boss_aimed_fan(e, 9, 0.06, 1.8)
    else
      e.spiral_a = (e.spiral_a or 0) + 0.04
      for i = 0, 3 do
        local a = e.spiral_a + i * 0.25
        boss_shoot_one(e, cos(a) * 1.5, sin(a) * 1.5)
        boss_shoot_one(e, cos(-a) * 1.5, sin(-a) * 1.5)
      end
    end
    e.shoot_t = 22
  end
}

-- inject the boss definition into standard enemy types
enemy_types.boss = {
  sp = 64, pts = 500,
  mk_x = function() return 56 end,
  mk_vy = function() return 0.2 end,
  extra = function(e)
    e.hp = 250
    e.max_hp = 250
    e.is_boss = true
    e.w = 16
    e.h = 16
    e.hx = 2
    e.hy = 2
    e.hw = 12
    e.hh = 12
    e.cx_anchor = 56
    e.cy_anchor = 30
    e.t = 0
    e.attack_t = 0
    e.combat_phase = 1
    e.armor = 1
    e.shoot_t = 50
    boss_ent = e
  end,
  move = function(e)
    -- combat phase transitions
    if e.combat_phase < 2 and e.hp <= 170 then
      e.combat_phase = 2
      e.armor = 1
      shake_screen(4, 15)
      e.flash = 8
      for eb in all(ebullets) do eb.dead = true end
      hit_stop_t = 6
      e.shoot_t = 25
    end
    if e.combat_phase < 3 and e.hp <= 80 then
      e.combat_phase = 3
      e.armor = 0
      shake_screen(6, 20)
      e.flash = 8
      for eb in all(ebullets) do eb.dead = true end
      hit_stop_t = 6
      e.shoot_t = 25
    end

    -- Lissajous hover movement
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

    if e.attack_t > 0 then e.attack_t -= 1 end
    e.shoot_t -= 1
    if e.shoot_t <= 0 then
      boss_fire[e.combat_phase](e)
      sfx(7)
      e.attack_t = 10
    end
  end,
  draw_fn = function(en)
    local do_flash = en.flash and en.flash > 0
    if do_flash then
      for c = 0, 15 do
        pal(c, 7)
      end
      en.flash -= 1
    elseif en.combat_phase == 3 then
      pal(11, 8) pal(14, 8) pal(12, 8) pal(3, 2)
      if tf(10, 2) == 0 then pal(8, 7) end
    elseif en.combat_phase == 2 then
      pal(11, 9) pal(14, 9) pal(12, 10)
    end
    local sx = (en.attack_t > 0) and 16 or 0
    sspr(sx, 32, 16, 16, en.x, en.y)
    pal()
  end
}
