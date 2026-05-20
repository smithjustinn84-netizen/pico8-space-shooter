-- constants.lua
-- shared global configurations and maps

S_ENEMY, S_ENEMY2, S_ENEMY3, S_ENEMY4, S_BULLET, S_BULLET_PLASMA, S_BULLET_LASER, S_MUZZLE, S_MUZZLE_PLASMA, S_MUZZLE_LASER = 32, 36, 34, 38, 19, 21, 23, 16, 17, 18

-- particle palettes
SPARK_C = { 7, 9, 10 }
EMBER_C = { 8, 9, 10 }
SMOKE_C = { 5, 6, 13 }
PLASMA_C = { 12, 13, 14 }

-- playable ships definitions
-- format: { sp, sp_l, sp_r, weapon, max_hp, max_speed, fire_cooldown(dummy), fire_cooldown(dummy), base_fire_delay, no_spread, thruster_colors }
ships = {
  { 1, 4, 7, "basic", 3, 3, 0, 0, 10, false, EMBER_C },
  { 2, 5, 8, "plasma", 2, 4, 0, 0, 8, true, { 12, 13, 7 } },
  { 3, 6, 9, "basic", 4, 2, 0, 0, 12, false, { 11, 3, 10 } }
}

-- weapon blueprints
WEAPONS = {
  basic = { w_sp = 49, b_sp = S_BULLET, sfx = 6, muz = S_MUZZLE, dmg = 1, v = -4 },
  spread = { w_sp = 50, b_sp = S_BULLET, sfx = 6, muz = S_MUZZLE, dmg = 1, v = -4 },
  plasma = { w_sp = 51, b_sp = S_BULLET_PLASMA, sfx = 4, muz = S_MUZZLE_PLASMA, dmg = 2, v = -5 },
  laser = { w_sp = 52, b_sp = S_BULLET_LASER, sfx = 5, muz = S_MUZZLE_LASER, dmg = 3, v = -6 }
}

-- weapon leveling offsets: W_OFF[weapon_type][min(level, 3)]
W_OFF = {
  basic = { { 0 }, { -3, 3 }, { -4, 0, 4 } },
  spread = { { -2.5, 0, 2.5 }, { -3.5, 0, 3.5 }, { -4, -2, 0, 2, 4 } },
  plasma = { { -4, 4 }, { -4, 0, 4 }, { -6, -2, 2, 6 } },
  laser = { { 0 }, { 0 }, { -4, 4 } }
}
W_VX = { spread = true }

-- boss health bar colors per stage
BPHC = { 11, 9, 8 }
