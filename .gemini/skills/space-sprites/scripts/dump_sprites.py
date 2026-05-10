import sys
import os

def main():
    cart_path = 'space.p8'
    if len(sys.argv) > 1:
        cart_path = sys.argv[1]
        
    if not os.path.exists(cart_path):
        print(f"Error: Could not find {cart_path}")
        sys.exit(1)

    try:
        with open(cart_path, 'r') as f:
            lines = f.read().split('\n')
        
        gfx_start = lines.index('__gfx__') + 1
        
        for sprite_idx in range(256):
            r = sprite_idx // 16
            c = sprite_idx % 16
            
            sprite_hex = []
            is_empty = True
            for y in range(8):
                line_idx = gfx_start + r * 8 + y
                if line_idx < len(lines) and lines[line_idx].strip() != '' and not lines[line_idx].startswith('__'):
                    # Pad lines if they are too short
                    line_data = lines[line_idx].ljust(128, '0')
                    row_data = line_data[c*8:(c+1)*8]
                    sprite_hex.append(row_data)
                    if row_data != '00000000':
                        is_empty = False
                else:
                    sprite_hex.append('00000000')
                    
            if not is_empty:
                print(f"Sprite {sprite_idx}:")
                for row in sprite_hex:
                    # Replace '0' with space for better visualization
                    print("".join([ch if ch != '0' else ' ' for ch in row]))
                print()
                
    except Exception as e:
        print(f"Error reading {cart_path}:", e)

if __name__ == '__main__':
    main()
