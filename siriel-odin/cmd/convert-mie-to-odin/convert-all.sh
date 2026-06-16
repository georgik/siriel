#!/bin/bash
# Batch convert MIE files to Odin format

set -e

# Paths
CONVERT="./convert-mie"
MIE_DIR="../siriel-levels"
OUTPUT_DIR="assets/levels"

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "Converting MIE files to Odin format..."
echo "Source: $MIE_DIR"
echo "Output: $OUTPUT_DIR"
echo

# Convert FMIS levels
for mie in "$MIE_DIR"/FMIS*.MIE; do
    if [ -f "$mie" ]; then
        name=$(basename "$mie" .MIE)
        echo "Converting: $name"
        $CONVERT "$mie" "$OUTPUT_DIR/${name}.odin"
    fi
done

# Convert main levels
for mie in "$MIE_DIR"/[0-9]*.MIE; do
    if [ -f "$mie" ]; then
        name=$(basename "$mie" .MIE)
        echo "Converting: $name"
        $CONVERT "$mie" "$OUTPUT_DIR/${name}.odin"
    fi
done

echo
echo "Conversion complete!"
echo "Converted files: $(ls -1 "$OUTPUT_DIR"/*.odin 2>/dev/null | wc -l)"
