#!/usr/bin/env python3
"""
pico8-sfx tool — generate, validate, and patch SFX lines in .p8 carts.

Usage (examples):
  python3 sfx_tool.py design                   # interactive designer
  python3 sfx_tool.py validate space.p8        # check all sfx line lengths
  python3 sfx_tool.py patch space.p8 4 <line>  # write a line to slot 4
  python3 sfx_tool.py dump space.p8            # print all non-empty slots
"""

import sys, re

# ── Format constants ──────────────────────────────────────────────────────────
HEADER_LEN  = 8    # speed(2) + loopstart(2) + loopend(2) + flags(2)
NOTES       = 32
NOTE_LEN    = 5    # pitch(2) + wave(1) + vol(1) + effect(1)
LINE_LEN    = HEADER_LEN + NOTES * NOTE_LEN  # 168

WAVEFORMS = {
    0: "triangle",
    1: "tilt-sawtooth",
    2: "sawtooth",
    3: "square",
    4: "pulse",
    5: "organ",
    6: "noise",
    7: "phaser",
}

EFFECTS = {
    0: "none",
    1: "slide",
    2: "vibrato",
    3: "drop",
    4: "fade-in",
    5: "fade-out",
    6: "arp-fast",
    7: "arp-slow",
}

# Pitch 0=C0, 1=C#0 … 63=D#5  (max valid pitch)
NOTE_NAMES = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
def pitch_name(p):
    return f"{NOTE_NAMES[p % 12]}{p // 12}"


# ── Encoding helpers ──────────────────────────────────────────────────────────
def encode_header(speed=2, loop_start=0, loop_end=0, flags=0):
    """Return 8-char header string."""
    return f"{flags:02x}{speed:02x}{loop_start:02x}{loop_end:02x}"

def encode_note(pitch=0, wave=0, vol=0, effect=0):
    """Return 5-char note string. pitch 0-63, wave 0-7, vol 0-7, effect 0-7."""
    assert 0 <= pitch <= 63, f"pitch {pitch} out of range 0-63"
    assert 0 <= wave  <= 7,  f"wave {wave} out of range 0-7"
    assert 0 <= vol   <= 7,  f"vol {vol} out of range 0-7"
    assert 0 <= effect<= 7,  f"effect {effect} out of range 0-7"
    return f"{pitch:02x}{wave}{vol}{effect}"

REST = "00000"

def build_sfx(notes, speed=2, loop_start=0, loop_end=0):
    """
    Build a validated 168-char sfx line.

    notes: list of up to 32 encoded note strings (each 5 chars).
           Shorter lists are padded with rests automatically.
    """
    assert len(notes) <= NOTES, f"too many notes ({len(notes)} > {NOTES})"
    padded = notes + [REST] * (NOTES - len(notes))
    line = encode_header(speed=speed, loop_start=loop_start, loop_end=loop_end) + "".join(padded)
    assert len(line) == LINE_LEN, f"bad line length {len(line)} (expected {LINE_LEN})"
    return line


# ── Preset builders ───────────────────────────────────────────────────────────
def preset_basic_gun(pitch_start=0x2c, wave=1, speed=2):
    """Short descending burst — default basic weapon pew."""
    notes = []
    for i in range(6):
        p = max(0, pitch_start - i * 2)
        v = max(1, 5 - i)
        notes.append(encode_note(p, wave, v))
    return build_sfx(notes, speed=speed)

def preset_plasma(pitch=0x38, wave=3, speed=2):
    """Double burst — plasma / charge weapon."""
    burst = [
        encode_note(pitch,     wave, 5),
        encode_note(pitch + 2, wave, 5),
        encode_note(pitch + 4, wave, 4),
        encode_note(pitch,     wave, 3),
        REST,
    ]
    return build_sfx(burst + burst[:4] + [REST], speed=speed)

def preset_laser(pitch_start=0x3c, wave=0, speed=1):
    """Fast high-to-low sweep — laser / beam weapon."""
    notes = []
    for i in range(9):
        p = max(0, pitch_start - i * 2)
        v = max(1, 5 - i // 2)
        notes.append(encode_note(p, wave, v))
    return build_sfx(notes, speed=speed)

def preset_explosion(pitch_start=0x2c, wave=6, speed=8):
    """Noise rumble — explosion / death."""
    notes = []
    for i in range(9):
        p = max(0, pitch_start - i * 2)
        v = max(0, 7 - i)
        notes.append(encode_note(p, wave, v))
    return build_sfx(notes, speed=speed)

def preset_pickup(pitch=0x24, wave=5, speed=5):
    """Rising tone — item / level-up."""
    pitches = [pitch, pitch+4, pitch+7, pitch+12, pitch+12, pitch+16, pitch+16, pitch+16]
    notes = [encode_note(min(63, p), wave, 7) for p in pitches]
    return build_sfx(notes, speed=speed)

PRESETS = {
    "basic":     preset_basic_gun,
    "plasma":    preset_plasma,
    "laser":     preset_laser,
    "explosion": preset_explosion,
    "pickup":    preset_pickup,
}


# ── Validation ────────────────────────────────────────────────────────────────
def parse_sfx_section(cart_path):
    """Return list of (slot_index, line_str) for all sfx lines."""
    with open(cart_path) as f:
        text = f.read()
    m = re.search(r"__sfx__\n(.*?)(\n__|$)", text, re.DOTALL)
    if not m:
        return []
    lines = m.group(1).rstrip("\n").split("\n")
    return [(i, l) for i, l in enumerate(lines) if l.strip()]

def validate(cart_path):
    slots = parse_sfx_section(cart_path)
    ok = True
    for slot, line in slots:
        if len(line) != LINE_LEN:
            print(f"FAIL slot {slot}: length {len(line)} (expected {LINE_LEN})")
            ok = False
        else:
            print(f"ok   slot {slot}")
    if ok:
        print("All slots valid.")
    return ok

def dump(cart_path):
    slots = parse_sfx_section(cart_path)
    for slot, line in slots:
        speed = int(line[2:4], 16)
        print(f"\nSlot {slot}  speed={speed}")
        for i in range(NOTES):
            n = line[HEADER_LEN + i*NOTE_LEN : HEADER_LEN + (i+1)*NOTE_LEN]
            pitch = int(n[0:2], 16)
            wave  = int(n[2], 16)
            vol   = int(n[3], 16)
            fx    = int(n[4], 16)
            if vol == 0 and pitch == 0:
                continue  # skip silent rests
            print(f"  note {i:2d}: {pitch_name(pitch):4s} ({pitch:#04x}) "
                  f"wave={WAVEFORMS.get(wave, wave)} vol={vol} fx={EFFECTS.get(fx, fx)}")


def patch(cart_path, slot, sfx_line):
    assert len(sfx_line) == LINE_LEN, f"line must be {LINE_LEN} chars, got {len(sfx_line)}"
    with open(cart_path) as f:
        text = f.read()
    m = re.search(r"(__sfx__\n)", text)
    if not m:
        raise ValueError("no __sfx__ section found")
    start = m.end()
    lines = text[start:].split("\n")
    # pad with empty lines if slot > current count
    while len(lines) <= slot or (lines[slot].startswith("__") or lines[slot] == ""):
        if slot >= len(lines):
            lines.append("0" * LINE_LEN)
        elif lines[slot].startswith("__") or not lines[slot]:
            lines.insert(slot, "0" * LINE_LEN)
        else:
            break
    if slot < len(lines) and not lines[slot].startswith("__"):
        lines[slot] = sfx_line
    else:
        lines.insert(slot, sfx_line)
    new_text = text[:start] + "\n".join(lines)
    with open(cart_path, "w") as f:
        f.write(new_text)
    print(f"Patched slot {slot} in {cart_path}")


# ── CLI ───────────────────────────────────────────────────────────────────────
def main():
    args = sys.argv[1:]
    if not args or args[0] == "design":
        print("=== PICO-8 SFX Designer ===\n")
        print("Presets:")
        for name, fn in PRESETS.items():
            line = fn()
            print(f"  {name:10s}: {line}")
        print(f"\nAll lines are {LINE_LEN} chars.")
        print("\nExample: build a custom sound")
        notes = [
            encode_note(0x30, wave=2, vol=7, effect=0),
            encode_note(0x2e, wave=2, vol=6),
            encode_note(0x2c, wave=2, vol=5),
            encode_note(0x2a, wave=2, vol=3),
        ]
        print("  " + build_sfx(notes, speed=3))

    elif args[0] == "validate" and len(args) >= 2:
        validate(args[1])

    elif args[0] == "dump" and len(args) >= 2:
        dump(args[1])

    elif args[0] == "patch" and len(args) >= 4:
        patch(args[1], int(args[2]), args[3])

    elif args[0] == "preset" and len(args) >= 2:
        name = args[1]
        if name not in PRESETS:
            print(f"Unknown preset '{name}'. Available: {list(PRESETS)}")
            sys.exit(1)
        print(PRESETS[name]())

    else:
        print(__doc__)


if __name__ == "__main__":
    main()
