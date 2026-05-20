-- utils.lua
-- shared helper functions and systems

-- frame animation tick helper
function tf(n, m)
  return flr(t() * n) % m
end

-- spawn helper: add to entities list and optionally a typed sub-list
function add_e(e, list)
  add(entities, e)
  if list then
    add(list, e)
  end
end

-- standard AABB bounding box collision helper
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

-- trigger a screen shake
function shake_screen(mag, dur)
  shake_t = dur or mag * 4
  shake_mag = mag
end

-- apply camera offset based on active screen shake
function apply_shake()
  if shake_t > 0 then
    camera(rnd(shake_mag * 2) - shake_mag, rnd(shake_mag * 2) - shake_mag)
  else
    camera()
  end
end

-- render full-screen hit flashes or death flashes
function draw_hit_flash()
  if death_flash_t > 0 then
    local c = death_flash_t > 10 and 7 or (death_flash_t > 5 and 10 or 9)
    rectfill(0, 0, 127, 127, c)
  elseif hit_flash_t > 0 then
    rect(0, 0, 127, 127, 8)
  end
end

-- apply a multi-color palette swap map
function apply_pal(c3, c11, c12, c7, c6)
  pal(3, c3)
  pal(11, c11)
  pal(12, c12)
  pal(7, c7)
  pal(6, c6)
end

-- smooth linear interpolation helper
function lerp(a, b, t)
  return a + (b - a) * t
end

-- calculate angle between two points using PICO-8's atan2 (dx, dy)
function angle_to(x1, y1, x2, y2)
  return atan2(x2 - x1, y2 - y1)
end

-- optimized squared distance helper for proximity checking
function dist_sqr(x1, y1, x2, y2)
  local dx = x2 - x1
  local dy = y2 - y1
  return dx * dx + dy * dy
end


