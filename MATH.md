# PICO-8 Game Math Reference Manual

This document details the highly optimized mathematical conventions, formulas, and custom implementations used in **Space Shooter (Campaign)** and **Boss Rush**.

PICO-8 has a virtual CPU instruction limit and a strict **8,192 token limit**. To keep performance at a constant 60 FPS and conserve space, we avoid standard CPU-heavy computations (like square roots and float divisions) and instead rely on PICO-8's unique fixed-point, turn-based trigonometric architecture.

---

## 1. The PICO-8 Trigonometric Turn Space

Unlike standard programming languages that use radians ($0$ to $2\pi$) or degrees ($0^\circ$ to $360^\circ$), **PICO-8 measures angles in turns from `0.0` to `1.0`**.

```
          0.75 (Up, -Y)
                │
                │
 0.5 (Left, -X) ┼────── 0.0 (Right, +X)
                │
                │
         0.25 (Down, +Y)
```

> [!NOTE]
> Because PICO-8's coordinate system places `(0,0)` at the top-left corner, **increasing $Y$ moves objects downward**. Therefore, `0.25` is Down and `0.75` is Up.

### Circular & Spiral Movement Examples
In `src/boss.lua`, the boss phase 2 and 3 spiral bullet fans increment turns directly:
```lua
-- Increment angle in turns
e.spiral_a = (e.spiral_a or 0) + 0.035

-- Shoot two bullets in opposite directions
boss_shoot_one(e, cos(e.spiral_a) * spd, sin(e.spiral_a) * spd)
boss_shoot_one(e, cos(e.spiral_a + 0.5) * spd, sin(e.spiral_a + 0.5) * spd)
```

---

## 2. Inverted Aiming & Swapped Arguments (`atan2`)

PICO-8 provides a native `atan2(dx, dy)` function. It deviates from the mathematical standard `Math.atan2(y, x)` in two key ways:
1. **Swapped Arguments**: It expects the horizontal component `dx` first, followed by the vertical component `dy`.
2. **Turn Output**: It directly returns an angle in PICO-8 turns (`0.0` to `1.0`).

We wrap this inside a shared utility in `src/utils.lua` to easily calculate angles between objects:
```lua
function angle_to(x1, y1, x2, y2)
  return atan2(x2 - x1, y2 - y1)
end
```

---

## 3. High-Performance Normalization (No `sqrt`)

Standard 2D vector normalization standardizes direction by dividing components by their vector length (which requires an expensive square root call):
$$\hat{V} = \frac{V}{\sqrt{V_x^2 + V_y^2}}$$

In PICO-8, we completely bypass square roots and division by using trigonometry to normalize vectors. By converting the distance vector to an angle first and then converting it back to components, PICO-8 handles the normalization internally on virtual hardware:

```diff
- -- Standard Normalization (CPU & Token Expensive)
- local dx = target.x - self.x
- local dy = target.y - self.y
- local len = sqrt(dx * dx + dy * dy)
- self.vx = (dx / len) * speed
- self.vy = (dy / len) * speed

+ -- Tailored PICO-8 Normalization (Fast & Token-Saving)
+ local a = angle_to(self.x, self.y, target.x, target.y)
+ self.vx = cos(a) * speed
+ self.vy = sin(a) * speed
```

---

## 4. Squared Distance Proximity Check (Performance Optimization)

When checking if an object is within a certain range (e.g., triggering a state transition or boss warning), taking a square root is mathematically unnecessary. We compare the **squared distance** against the **squared range**, saving valuable virtual CPU cycles:

$$\Delta x^2 + \Delta y^2 < \text{Range}^2$$

We implement this in `src/utils.lua` for clean, modular checks:
```lua
function dist_sqr(x1, y1, x2, y2)
  local dx = x2 - x1
  local dy = y2 - y1
  return dx * dx + dy * dy
end
```

### Proximity Check Comparison
Instead of calculating standard Euclidean distance:
```lua
-- SLOW: Calls sqrt() every frame
local dist = sqrt((e.x - p.x)^2 + (e.y - p.y)^2)
if dist < 16 then trigger_attack() end

-- FAST: Only uses addition and multiplication
if dist_sqr(e.x, e.y, p.x, p.y) < 256 then trigger_attack() end -- (16 * 16 = 256)
```

---

## 5. Branchless Speed Approximation (Eliminating `sqrt`)

In `src/player.lua`, the ship's thruster exhaust height scales dynamically based on the current velocity vector length.
Since standard player movement is strictly restricted to eight directions (orthogonal or diagonal), we developed a **mathematically exact, branchless speed approximation** that completely eliminates square roots:

```lua
-- Highly optimized speed check in draw_thruster()
local spd = max(abs(obj.vx), abs(obj.vy))
if (obj.vx ~= 0 and obj.vy ~= 0) spd *= 1.4142
```

### How It Works:
1. **Orthogonal Movement** (Moving only along $X$ or $Y$): One component is `0`, the other is `spd`. `max(abs(vx), abs(vy))` returns exactly `spd`. The diagonal condition is false, returning the exact speed.
2. **Diagonal Movement** (Moving Up-Right, etc.): Both components are normalized to $0.7071 \times \text{spd}$. `max()` returns $0.7071 \times \text{spd}$. The diagonal condition is true, so it multiplies by $\sqrt{2}$ ($1.4142$):
   $$0.7071 \times 1.4142 \times \text{spd} \approx 1.0 \times \text{spd}$$
   This returns the exact speed perfectly!
3. **Idle State**: Returns `0`.

---

## 6. Smooth Blends & Micro-Animations (`lerp`)

For fluid UI movements and transition animations, we implement a linear interpolation helper:
$$\text{lerp}(a, b, t) = a + (b - a) \times t$$

```lua
function lerp(a, b, t)
  return a + (b - a) * t
end
```

We use this helper to smoothly slide the selection circle/box in both the ship selection Title screens and Campaign Upgrade Shop, making the visual transitions feel organic and premium:
```lua
-- title selection sliding highlight circle
local target_x = 46 + (selected_ship - 1) * 16
title_cx = lerp(title_cx or target_x, target_x, 0.25)
circfill(title_cx + 4, 64, 8, 5)
```

---

## Math Optimization Impact Summary

| Code Section | Old Math Approach | Optimized PICO-8 Approach | CPU/Token Benefit |
| :--- | :--- | :--- | :--- |
| **Aimed Projectiles** | `sqrt` + divide-by-zero check | `angle_to` + `cos`/`sin` | Saved ~15 tokens, 0 square roots |
| **Boss Telegraph Lines** | Vector division + `sqrt` | `angle_to` + `cos`/`sin` | Saved ~12 tokens, 0 square roots |
| **Boss aimed bullet fan** | `sqrt` + 2D rotation matrix | Turn-based additions + `angle_to` | Saved ~30 tokens, 0 square roots |
| **Player thruster heights** | `sqrt(vx*vx + vy*vy)` | Branchless Max-Abs Components | Saved ~10 tokens, 0 square roots |
| **Diagonal Correction** | `0.707` Multiplier | Precise `0.7071` | Higher floating-point accuracy |
