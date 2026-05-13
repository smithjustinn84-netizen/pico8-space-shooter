import sys

def N(pitch, wave, vol, effect):
    if pitch == -1: return "00000"
    return f"{max(0,min(63,int(pitch))):02x}{max(0,min(7,int(wave))):x}{max(0,min(7,int(vol))):x}{max(0,min(7,int(effect))):x}"

def sfx(speed, notes, ls=0, le=0):
    header = f"00{speed:02x}{ls:02x}{le:02x}"
    body = "".join(N(*n) for n in notes)
    body += "00000" * (32 - len(notes))
    return header + body

SPEED = 6

def make_bass(chord_root):
    # intense gallop: 8th, 16th, 16th
    seq = []
    for _ in range(8):
        seq.extend([chord_root, -1, chord_root, chord_root])
    return sfx(SPEED, [(p, 3, 5, 0) if p != -1 else (-1,0,0,0) for p in seq])

def make_arp(chord_notes):
    # fast 16th note arp
    seq = []
    for _ in range(8):
        seq.extend(chord_notes)
    return sfx(SPEED, [(p, 4, 3, 0) for p in seq])

def make_lead(notes, v=6):
    # intense melody
    return sfx(SPEED, [(p, 1, v, 1) if p != -1 else (-1,0,0,0) for p in notes])

def make_drums():
    notes = []
    for i in range(32):
        if i % 8 == 0:
            notes.append((8, 6, 6, 5)) # kick
        elif i % 8 == 4:
            notes.append((24, 6, 5, 5)) # snare
        elif i % 2 == 0:
            notes.append((38, 6, 4, 5)) # hi-hat
        else:
            notes.append((-1,0,0,0))
    return sfx(SPEED, notes)

def make_drums_fill():
    notes = []
    for i in range(32):
        if i < 24:
            if i % 8 == 0:
                notes.append((8, 6, 6, 5))
            elif i % 8 == 4:
                notes.append((24, 6, 5, 5))
            elif i % 2 == 0:
                notes.append((38, 6, 4, 5))
            else:
                notes.append((-1,0,0,0))
        else:
            # 16th note snare roll
            notes.append((24, 6, 5+(i%2), 5))
    return sfx(SPEED, notes)

# Cm = 12, Ab = 8, Bb = 10, G = 19
# Lead melodies
lead1 = [24,-1,24,-1, 27,-1,27,-1, 31,-1,-1,-1, 27,-1,-1,-1] * 2
lead2 = [20,-1,20,-1, 24,-1,24,-1, 27,-1,-1,-1, 24,-1,-1,-1] * 2
lead3 = [22,-1,22,-1, 26,-1,26,-1, 29,-1,-1,-1, 26,-1,-1,-1] * 2
lead4 = [19,20,21,22, 23,24,25,26, 27,-1,-1,-1, 31,-1,31,-1, 31,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1]

tracks = []
idx = 46 # SFX 46 (0x2e)

d1 = make_drums()
tracks.append((idx, d1)); dA = idx; idx += 1
d2 = make_drums_fill()
tracks.append((idx, d2)); dB = idx; idx += 1

# P1: Cm
tracks.append((idx, make_bass(12))); b1 = idx; idx += 1
tracks.append((idx, make_arp([24,27,31,27]))); a1 = idx; idx += 1
tracks.append((idx, make_lead(lead1))); l1 = idx; idx += 1

# P2: Ab
tracks.append((idx, make_bass(8))); b2 = idx; idx += 1
tracks.append((idx, make_arp([20,24,27,24]))); a2 = idx; idx += 1
tracks.append((idx, make_lead(lead2))); l2 = idx; idx += 1

# P3: Bb
tracks.append((idx, make_bass(10))); b3 = idx; idx += 1
tracks.append((idx, make_arp([22,26,29,26]))); a3 = idx; idx += 1
tracks.append((idx, make_lead(lead3))); l3 = idx; idx += 1

# P4: G (tension before loop)
tracks.append((idx, make_bass(19))); b4 = idx; idx += 1
tracks.append((idx, make_arp([19,23,26,23]))); a4 = idx; idx += 1
tracks.append((idx, make_lead(lead4))); l4 = idx; idx += 1

patterns = [
    f"01 {b1:02x}{l1:02x}{a1:02x}{dA:02x}",
    f"00 {b2:02x}{l2:02x}{a2:02x}{dA:02x}",
    f"00 {b3:02x}{l3:02x}{a3:02x}{dA:02x}",
    f"02 {b4:02x}{l4:02x}{a4:02x}{dB:02x}",
]

with open("space.p8", "r") as f:
    lines = f.read().split("\n")

sfx_idx = -1
for i, l in enumerate(lines):
    if l == "__sfx__":
        sfx_idx = i
        break

music_idx = -1
for i, l in enumerate(lines):
    if l == "__music__":
        music_idx = i
        break

sfx_lines = lines[sfx_idx+1:music_idx]
# Ensure we have at least 64 sfx lines
while len(sfx_lines) < 64:
    sfx_lines.append("00010000" + "00000"*32)

for t_idx, hex_str in tracks:
    sfx_lines[t_idx] = hex_str

lines = lines[:sfx_idx+1] + sfx_lines + lines[music_idx:]

# Update music
music_idx = -1
for i, l in enumerate(lines):
    if l == "__music__":
        music_idx = i
        break

music_end = -1
for i, l in enumerate(lines[music_idx+1:]):
    if l.startswith("__") or l.strip() == "":
        music_end = music_idx + 1 + i
        break
if music_end == -1: music_end = len(lines)

music_lines = lines[music_idx+1:music_end]
# Ensure we have at least 14 music lines
while len(music_lines) < 14:
    music_lines.append("00 00000000")

# Write to patterns 10, 11, 12, 13
music_lines[10] = patterns[0]
music_lines[11] = patterns[1]
music_lines[12] = patterns[2]
music_lines[13] = patterns[3]

# In space.p8, the boss music starts at pattern 10, which loops through 13 due to our flags!
lines = lines[:music_idx+1] + music_lines + lines[music_end:]

with open("space.p8", "w") as f:
    f.write("\n".join(lines))

