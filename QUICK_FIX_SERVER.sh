#!/bin/bash
# Quick fix: Update apply_patches_direct.sh to prioritize hiddify-panel-source
# Run this on the server if git pull doesn't work

FILE="/opt/hiddify-manager/hiddify-agent-traffic-manager/apply_patches_direct.sh"

if [ ! -f "$FILE" ]; then
    echo "Error: File not found: $FILE"
    exit 1
fi

# Backup
cp "$FILE" "${FILE}.backup.$(date +%Y%m%d_%H%M%S)"

# Replace the check order to prioritize hiddify-panel-source
sed -i 's|elif \[ -d "\$HIDDIFY_DIR/hiddify-panel/src" \]|# First check hiddify-panel-source\n    if [ -d "$HIDDIFY_DIR/hiddify-panel-source/src" ] \&\& [ "$(ls -A $HIDDIFY_DIR/hiddify-panel-source/src 2>/dev/null)" ]; then\n        SOURCE_DIR="$HIDDIFY_DIR/hiddify-panel-source/src"\n        echo -e "${GREEN}Found in hiddify-panel-source${NC}"\nelif [ -d "$HIDDIFY_DIR/hiddify-panel/src" ]|' "$FILE"

# Or simpler: just add the check before the existing ones
# Find the line with "If not found, check standard locations"
sed -i '/# If not found, check standard locations/i\
# First check hiddify-panel-source (most likely to be the cloned source)\
if [ -z "$SOURCE_DIR" ] && [ -d "$HIDDIFY_DIR/hiddify-panel-source/src" ] && [ "$(ls -A $HIDDIFY_DIR/hiddify-panel-source/src 2>/dev/null)" ]; then\
    SOURCE_DIR="$HIDDIFY_DIR/hiddify-panel-source/src"\
    echo -e "${GREEN}Found in hiddify-panel-source${NC}"\
fi\
' "$FILE"

echo "✓ File updated. Backup created."
echo "Now run: bash $FILE"

