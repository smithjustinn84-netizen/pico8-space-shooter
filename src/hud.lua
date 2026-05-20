-- hud.lua
-- unified heads up display (HUD) rendering

function draw_hud()
  -- top banner background
  rectfill(0, 0, 127, 9, 0)
  print("score:" .. score, 2, 2, 7)

  -- level progression indicator (optional, only in full space shooter cart)
  if level and MAX_LEVEL then
    local lvl_str = "lvl:" .. level .. "/" .. MAX_LEVEL
    print(lvl_str, 64 - (#lvl_str * 2), 2, 6)
  end

  -- player HP hearts
  local h_width = p.max_hp * 9
  local start_x = 127 - h_width
  for i = 1, p.max_hp do
    spr(i <= p.hp and 14 or 15, start_x + (i - 1) * 9, 1)
  end

  -- Heavy Archetype Shield Gauge
  if p.archetype == 3 and p.shield ~= nil then
    if p.shield > 0 then
      circfill(start_x - 8, 4, 2, 12)
    else
      local progress = flr((p.shield_timer / 600) * 8)
      rectfill(start_x - 12, 3, start_x - 12 + progress, 5, 8)
    end
  end

  -- boss health meter
  if boss_ent and not boss_ent.dead then
    local pct = boss_ent.hp / boss_ent.max_hp
    local bc = BPHC[boss_ent.combat_phase]
    print("boss", 10, 115, bc)
    rect(10, 122, 118, 126, 5)
    rectfill(10, 122, 10 + flr(pct * 108), 126, bc)
  end
end
