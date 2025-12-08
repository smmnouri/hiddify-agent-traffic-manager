#!/bin/bash
# Fix base.py indentation error

set -e

HIDDIFY_DIR="/opt/hiddify-manager"
BASE_PY=""

# Find base.py
for path in "$HIDDIFY_DIR/hiddify-panel-source" "$HIDDIFY_DIR/hiddify-panel-custom" "$HIDDIFY_DIR/hiddify-panel"; do
    if [ -f "$path/src/hiddifypanel/base.py" ]; then
        BASE_PY="$path/src/hiddifypanel/base.py"
        break
    elif [ -f "$path/hiddifypanel/base.py" ]; then
        BASE_PY="$path/hiddifypanel/base.py"
        break
    fi
done

if [ -z "$BASE_PY" ] || [ ! -f "$BASE_PY" ]; then
    echo "✗ base.py not found"
    exit 1
fi

echo "Found base.py: $BASE_PY"
echo ""

# Check for backup
BACKUP=$(ls -t "${BASE_PY}.backup."* 2>/dev/null | head -n1)
if [ -n "$BACKUP" ] && [ -f "$BACKUP" ]; then
    echo "Restoring from backup: $BACKUP"
    cp "$BACKUP" "$BASE_PY"
    echo "✓ Restored"
else
    echo "⚠ No backup found, trying to remove patches..."
    cd "$HIDDIFY_DIR/hiddify-agent-traffic-manager"
    if [ -f "patches/unpatch_base.py" ]; then
        VENV_PYTHON=""
        if [ -f "$HIDDIFY_DIR/.venv313/bin/python" ]; then
            VENV_PYTHON="$HIDDIFY_DIR/.venv313/bin/python"
        else
            VENV_PYTHON="python3"
        fi
        "$VENV_PYTHON" patches/unpatch_base.py "$BASE_PY" 2>/dev/null || true
    fi
    
    # Check syntax
    python3 -m py_compile "$BASE_PY" 2>&1
    if [ $? -ne 0 ]; then
        echo "✗ File still has syntax errors"
        exit 1
    fi
fi

# Re-patch with corrected script
echo ""
echo "Re-patching with corrected script..."
cd "$HIDDIFY_DIR/hiddify-agent-traffic-manager"
VENV_PYTHON=""
if [ -f "$HIDDIFY_DIR/.venv313/bin/python" ]; then
    VENV_PYTHON="$HIDDIFY_DIR/.venv313/bin/python"
else
    VENV_PYTHON="python3"
fi

# Remove old patches first
if [ -f "patches/unpatch_base.py" ]; then
    "$VENV_PYTHON" patches/unpatch_base.py "$BASE_PY" 2>/dev/null || true
fi

# Apply new patch
"$VENV_PYTHON" patches/patch_base.py "$BASE_PY"

# Verify syntax
echo ""
echo "Verifying syntax..."
python3 -m py_compile "$BASE_PY" 2>&1
if [ $? -eq 0 ]; then
    echo "✓ Syntax is correct"
else
    echo "✗ Still has syntax errors"
    if [ -n "$BACKUP" ]; then
        echo "Restoring backup again..."
        cp "$BACKUP" "$BASE_PY"
    fi
    exit 1
fi

echo ""
echo "✓ base.py fixed successfully"

