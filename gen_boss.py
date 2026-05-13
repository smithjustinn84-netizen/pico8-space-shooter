import sys
import math

# Load space.p8
with open("space.p8", "r") as f:
    lines = f.read().split("\n")

gfx_idx = -1
for i, l in enumerate(lines):
    if l == "__gfx__":
        gfx_idx = i
        break

if gfx_idx == -1:
    print("Could not find __gfx__")
    sys.exit(1)

# Read existing gfx into a 128x128 array
gfx = [['0' for _ in range(128)] for _ in range(128)]
curr_idx = gfx_idx + 1
y = 0
while curr_idx < len(lines) and lines[curr_idx].strip() != "" and not lines[curr_idx].startswith("__"):
    row_str = lines[curr_idx].strip()
    for x, ch in enumerate(row_str):
        if x < 128:
            gfx[y][x] = ch
    y += 1
    curr_idx += 1

end_gfx_idx = curr_idx

# Procedural generation of a 32x32 boss sprite with 4 frames.
# Sharp angular mothership: V-prow, swept wings, cannon pods, glowing core.

def draw_boss_frame(frame, base_x, base_y):
    # Use bilateral symmetry: compute left half (px 0..15), mirror to right (31..16).
    for py in range(32):
        for px in range(16):
            c = '0'

            dx = 15.5 - px
            dy = 15.5 - py
            dist = math.sqrt(dx*dx + dy*dy)

            # --- Core: layered glow rings ---
            core_rad = 7 + math.sin(frame * math.pi / 2) * 2
            if dist < core_rad:
                if dist < 2:
                    c = '7'   # white-hot center
                elif dist < 3.5:
                    c = 'a'   # yellow inner
                elif dist < 5.5:
                    c = '9'   # orange mid
                else:
                    c = '8'   # red outer rim

            # --- Mechanical shell ring around core ---
            if dist >= core_rad and dist < core_rad + 1.5 and py < 22:
                c = '5'
                if (px + py) % 2 == 0:
                    c = '6'

            # --- V-shaped prow armor (top of ship) ---
            if py >= 0 and py < 8:
                armor_w = 8 - py  # narrows toward top
                if px >= 15 - armor_w:
                    c = '6' if px >= 13 else '5'

            # --- Sharp swept wings ---
            # Inner boundary: linear wedge widening toward bottom
            wing_inner = max(0, 14 - int(py * 0.3))
            wing_active = py > 6 and py < 27
            if wing_active and px >= wing_inner:
                c = '1'   # dark blue base
                if px <= wing_inner + 2:
                    c = 'd'   # indigo inner highlight strip
                if py % 4 == 0 and px > wing_inner + 2:
                    c = '5'   # rib lines

            # --- Cannon pods: two symmetric pods on the lower wings ---
            if py >= 20 and py <= 28 and px >= 1 and px <= 4:
                c = '5'   # pod body
                if px == 3:
                    c = '6'   # pod highlight edge
            # Barrel tips with firing glow
            if py == 29 and px == 2:
                c = '9' if frame % 2 == 0 else '8'

            # --- Thrusters: two nozzles near center-bottom ---
            if py >= 22 and py < 28 and px >= 9 and px <= 12:
                c = '5'   # nozzle housing
                if px == 10 or px == 11:
                    c = '6'

            # --- Thruster flames ---
            if py >= 28 and px >= 10 and px <= 11:
                flame_pos = py - 28
                flame_len = 3 + (frame % 2) * 2
                if flame_pos < flame_len:
                    if flame_pos == 0:
                        c = 'c'   # cyan inner (hottest)
                    elif flame_pos % 2 == 0:
                        c = '9'   # orange
                    else:
                        c = 'a'   # yellow

            if c != '0':
                gfx[base_y + py][base_x + px] = c
                gfx[base_y + py][base_x + 31 - px] = c

# Clear the four frame areas first
for py in range(32):
    for px in range(32):
        gfx[16 + py][96 + px] = '0'  # Clear old Frame 0 location
        gfx[32 + py][0  + px] = '0'
        gfx[32 + py][32 + px] = '0'
        gfx[32 + py][64 + px] = '0'
        gfx[32 + py][96 + px] = '0'

draw_boss_frame(0, 0, 32)
draw_boss_frame(1, 32, 32)
draw_boss_frame(2, 64, 32)
draw_boss_frame(3, 96, 32)

# Find max non-empty row to prune __gfx__
max_y = 0
for y in range(128):
    if any(c != '0' for c in gfx[y]):
        max_y = y

new_gfx_lines = []
for y in range(max_y + 1):
    new_gfx_lines.append("".join(gfx[y]))

# Reassemble lines
out_lines = lines[:gfx_idx+1] + new_gfx_lines + lines[end_gfx_idx:]

with open("space.p8", "w") as f:
    f.write("\n".join(out_lines))

print("Updated space.p8 with improved 4-frame 32x32 boss sprite!")
