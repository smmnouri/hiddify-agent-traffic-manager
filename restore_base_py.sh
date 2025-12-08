#!/bin/bash
# Restore base.py from backup or git

set -e

HIDDIFY_DIR="/opt/hiddify-manager"
BASE_PY=""

# Find base.py
for path in "$HIDDIFY_DIR/hiddify-panel-source" "$HIDDIFY_DIR/hiddify-panel-custom" "$HIDDIFY_DIR/hiddify-panel"; do
    if [ -f "$path/src/hiddifypanel/base.py" ]; then
        BASE_PY="$path/src/hiddifypanel/base.py"
        SOURCE_DIR="$path"
        break
    elif [ -f "$path/hiddifypanel/base.py" ]; then
        BASE_PY="$path/hiddifypanel/base.py"
        SOURCE_DIR="$path"
        break
    fi
done

if [ -z "$BASE_PY" ] || [ ! -f "$BASE_PY" ]; then
    echo "✗ base.py not found"
    exit 1
fi

echo "Found base.py: $BASE_PY"
echo "Source directory: $SOURCE_DIR"
echo ""

# Method 1: Try backup file
BACKUP=$(ls -t "${BASE_PY}.backup."* 2>/dev/null | head -n1)
if [ -n "$BACKUP" ] && [ -f "$BACKUP" ]; then
    echo "Restoring from backup: $BACKUP"
    cp "$BACKUP" "$BASE_PY"
    echo "✓ Restored from backup"
    
    # Verify syntax
    python3 -m py_compile "$BASE_PY" 2>&1
    if [ $? -eq 0 ]; then
        echo "✓ Syntax verified"
        exit 0
    else
        echo "⚠ Backup has syntax errors, trying git restore..."
    fi
fi

# Method 2: Try git restore
if [ -d "$SOURCE_DIR/.git" ]; then
    echo "Restoring from git..."
    cd "$SOURCE_DIR"
    git checkout -- hiddifypanel/base.py 2>/dev/null || git checkout -- src/hiddifypanel/base.py 2>/dev/null || true
    
    # Verify syntax
    python3 -m py_compile "$BASE_PY" 2>&1
    if [ $? -eq 0 ]; then
        echo "✓ Restored from git and syntax verified"
        exit 0
    else
        echo "⚠ Git restore has syntax errors"
    fi
fi

# Method 3: Re-clone if all else fails
echo "⚠ All restore methods failed. You may need to re-clone the repository."
exit 1

