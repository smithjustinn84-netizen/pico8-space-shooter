-- player.lua
-- player ship mechanics, movement, weapon shooting, and damage

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
    p.iframe_mod = 20 -- Balanced: added to standard iframes on hit
  elseif p.archetype == 2 then
    p.base_fire_delay = 4 -- Assault: hyper-fast firing rate
    p.spray_variance = 0.5 -- Assault: chaotic firing cone accuracy offset
  elseif p.archetype == 3 then
    p.always_pierce = true -- Heavy: forces weaponry to pass through enemies
  end

  -- insert at front so player draws beneath enemies/bullets
  add(entities, p, 1)
end

function update_player(obj)
  if state == win_state then
    obj.vx = 0
    obj.vy = -0.6
    obj.x += obj.vx
    obj.y += obj.vy
    if tf(60, 2) == 0 then
      burst_thruster(obj.x + 4, obj.y + 8, obj.t_cols, 1)
    end
    return
  end

  local dx, dy = 0, 0
  if btn(0) then dx -= 1 end
  if btn(1) then dx += 1 end
  if btn(2) then dy -= 1 end
  if btn(3) then dy += 1 end

  -- normalise diagonal speed
  if dx ~= 0 and dy ~= 0 then
    dx *= 0.7071
    dy *= 0.7071
  end

  -- precision focused movement
  local spd = obj.max_speed
  if btn(4) or btn(5) then spd *= 0.5 end

  obj.vx = dx * spd
  obj.vy = dy * spd

  -- auto-fire
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

  -- thruster exhaust
  if (dx ~= 0 or dy ~= 0) and tf(60, 2) == 0 then
    burst_thruster(obj.x + 4, obj.y + 8, obj.t_cols, 1)
  end

  -- clamp to screen boundary
  if obj.x < 0 then obj.x = 0 obj.vx = 0 end
  if obj.x > 120 then obj.x = 120 obj.vx = 0 end
  if obj.y < 10 then obj.y = 10 obj.vy = 0 end
  if obj.y > 120 then obj.y = 120 obj.vy = 0 end

  if obj.shield_flash_t and obj.shield_flash_t > 0 then obj.shield_flash_t -= 1 end

  -- Heavy Shield recharge cooldown loop
  if obj.archetype == 3 and obj.shield == 0 then
    obj.shield_timer += 1
    if obj.shield_timer >= 600 then
      obj.shield = 1
      obj.shield_timer = 0
      sfx(3)
    end
  end
end

function burst_muzzle(x, y)
  emit_fx(x, y, 2, { cols = { 9, 10, 7 }, ang = 0.25, ang_r = 0.3, spd = 1 + rnd(1.5), life = 8, drag = 0.92 })
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
    period = max(2, flr(ni * ni * 12) + 2)
    if (obj.iframes % period) < flr(period / 2) then
      return
    end
  end

  draw_thruster(obj, dx)
  spr(s, obj.x, obj.y)

  -- hitbox core focus guide
  if btn(4) or btn(5) then
    local cx = obj.x + 4
    local cy = obj.y + 4
    local pulse = flr(t() * 8) % 2 == 0 and 10 or 7
    pset(cx, cy, pulse)
    pset(cx - 1, cy, 6)
    pset(cx + 1, cy, 6)
    pset(cx, cy - 1, 6)
    pset(cx, cy + 1, 6)
  end

  if obj.flash_t > 0 then
    draw_muzzle_flash(obj, dx)
  end

  -- Render Heavy Shield Aura
  if obj.archetype == 3 and obj.shield and obj.shield > 0 then
    local rad = 6 + flr(sin(t() * 3) * 1.5)
    circ(obj.x + 3 + dx, obj.y + 4, rad, 12)
    circ(obj.x + 4 + dx, obj.y + 4, rad, 12)
  elseif obj.archetype == 3 and obj.shield_flash_t and obj.shield_flash_t > 0 then
    spr(30, obj.x + dx, obj.y)
  end
end

function draw_thruster(obj, dx)
  local spd = max(abs(obj.vx), abs(obj.vy))
  if (obj.vx ~= 0 and obj.vy ~= 0) spd *= 1.4142
  t16 = flr(t() * 16)
  fh = 4 + flr(spd * 4) + t16 % 2
  fn = t16 % 4

  pal(8, obj.t_cols[1])
  pal(9, obj.t_cols[2])
  pal(10, obj.t_cols[3])

  sspr(80 + fn * 8, 0, 8, 8, obj.x + dx, obj.y + 8, 8, fh)
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
  sspr(sx, sy, 8, 4, obj.x - twist, obj.y - sep, 8, 4)
  sspr(sx, sy + 4, 8, 4, obj.x + twist, obj.y + 4 + flr(sep * 0.5), 8, 4)
  pal()
end

function damage_player(frames)
  if p.archetype == 3 and p.shield and p.shield > 0 then
    p.shield = 0
    p.shield_timer = 0
    p.shield_flash_t = 15
    sfx(3)
    burst_sparks(p.x + 4, p.y + 4, 12, PLASMA_C)
  else
    p.hp -= 1
    frames = frames + (p.iframe_mod or 0)
    if p.hp <= 0 then player_death() end
  end
  p.iframes = frames
  p.max_iframes = frames
end

function player_death()
  p.dead = true
  final_score = score
  death_timer = 120
  death_flash_t = 15
  shake_screen(8, 50)
  local cx, cy = p.x + 4, p.y + 4
  make_boom(cx, cy, true, 24, 14, 10)
  for i = 1, 3 do
    add(entities, make_explosion(cx + rnd(20) - 10, cy + rnd(20) - 10))
  end
  sfx(2)
  hit_stop_t = 3
end

-- unified damage controller interface
function hit_player(lvl, fx, fy)
  local h = HL[lvl]
  fx, fy = fx or p.x + 4, fy or p.y + 4
  sfx(2)
  damage_player(h[1])
  shake_screen(h[2], h[3])
  hit_flash_t = h[4]
  hit_stop_t = h[5]
  burst_sparks(fx, fy, h[6], h[7])
  if h[8] then
    add(entities, make_explosion(fx - 4, fy - 4))
    add(entities, make_shockwave(fx, fy))
    add(entities, make_hit_flash(fx, fy))
  end
end

-- player damage levels (shared mapping)
HL = {
  light = { 50, 2, 8, 6, 2, 8, { 8, 9, 10 }, false },
  heavy = { 60, 3, 12, 8, 3, 6, { 8, 9, 7 }, true }
}
