import sys
import os

def main():
    """
    Example script for programmatically modifying the __gfx__ section of a PICO-8 cart.
    This script demonstrates how to define 8x8 sprites as hex strings, assemble them into rows,
    and replace the existing graphics data in space.p8.
    """
    cart_path = 'space.p8'
    if not os.path.exists(cart_path):
        print(f"Error: Could not find {cart_path}")
        sys.exit(1)

    # Example of defining a sprite (8x8 pixels, where each character is a hex color 0-f)
    # This is a sample muzzle flash sprite
    sample_sprite = [
        "00000000",
        "00000000",
        "00000000",
        "000a0000",
        "009aa900",
        "008aa800",
        "00899800",
        "00088000"
    ]

    # Create a 2D array representing the full 16x16 sprite sheet (256 sprites)
    # Each cell in the grid contains an 8-line list of hex strings
    empty_sprite = ["0" * 8] * 8
    grid = [[empty_sprite for _ in range(16)] for _ in range(16)]
    
    # Place our sample sprite at index 16 (Row 1, Col 0)
    grid[1][0] = sample_sprite

    # Generate the 128 lines of hex data for the __gfx__ section
    # Each row contains 8 lines of 128 characters
    new_gfx_lines = []
    for r in range(16): # 16 rows
        # If the row is completely empty, and we want to truncate like PICO-8 does,
        # we could break early, but it's safe to write all 128 lines.
        for y in range(8): # 8 pixel lines per row
            line_hex = ""
            for c in range(16): # 16 columns
                line_hex += grid[r][c][y]
            new_gfx_lines.append(line_hex)

    # Read the cartridge
    with open(cart_path, 'r') as f:
        lines = f.read().split('\n')

    try:
        gfx_start = lines.index('__gfx__') + 1
        sfx_start = lines.index('__sfx__')
    except ValueError:
        print("Could not find __gfx__ or __sfx__ markers.")
        sys.exit(1)

    # Remove old gfx lines and insert the new ones
    lines = lines[:gfx_start] + new_gfx_lines + lines[sfx_start:]

    # Uncomment to actually apply changes:
    # with open(cart_path, 'w') as f:
    #     f.write('\n'.join(lines))
    # print("Gfx section updated successfully.")
    print("Dry run complete. Uncomment file writing to apply changes.")

if __name__ == '__main__':
    main()
