#!/bin/bash
set -e

# Default path to shrinko8.py
SHRINKO8_PATH="/Users/justinsmith/tools/shrinko8/shrinko8.py"

echo "============================================="
echo "Building PICO-8 space shooter cartridges..."
echo "============================================="

# Ensure shrinko8.py is accessible
if [ ! -f "$SHRINKO8_PATH" ]; then
    echo "Error: shrinko8.py not found at $SHRINKO8_PATH"
    echo "Searching for shrinko8.py on your system..."
    FOUND_PATH=$(find "$HOME" -name "shrinko8.py" 2>/dev/null | head -n 1)
    if [ -n "$FOUND_PATH" ]; then
        SHRINKO8_PATH="$FOUND_PATH"
        echo "Found shrinko8.py at: $SHRINKO8_PATH"
    else
        echo "Could not locate shrinko8.py. Please verify its path."
        exit 1
    fi
fi

echo "1. Minifying and exporting space.p8 -> space.p8.png..."
python3 "$SHRINKO8_PATH" space.p8 space.p8.png --minify-safe-only --count

echo ""
echo "2. Minifying and exporting boss.p8 -> boss.p8.png..."
python3 "$SHRINKO8_PATH" boss.p8 boss.p8.png --minify-safe-only --count

echo ""
echo "Build complete! Minified visual PNG cartridges are ready."
echo "============================================="
