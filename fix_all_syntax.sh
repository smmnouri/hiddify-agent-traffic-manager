#!/bin/bash
# Comprehensive fix for all syntax errors

set -e

echo "=========================================="
echo "Comprehensive Syntax Fix"
echo "=========================================="
echo ""

HIDDIFY_DIR="/opt/hiddify-manager"
ADMIN_FILE="$HIDDIFY_DIR/hiddify-panel-source/hiddifypanel/panel/admin/AdminstratorAdmin.py"
BASE_FILE="$HIDDIFY_DIR/hiddify-panel-source/hiddifypanel/base.py"

# 1. Fix AdminstratorAdmin.py
echo "1. Fixing AdminstratorAdmin.py..."
if [ -f "$ADMIN_FILE" ]; then
    cd "$HIDDIFY_DIR/hiddify-panel-source"
    git checkout -- hiddifypanel/panel/admin/AdminstratorAdmin.py
    echo "   ✓ Restored from git"
    
    cd "$HIDDIFY_DIR/hiddify-agent-traffic-manager"
    python3 patches/patch_adminstrator_admin.py "$ADMIN_FILE"
    echo "   ✓ Patched"
    
    # Verify syntax
    if python3 -m py_compile "$ADMIN_FILE" 2>&1; then
        echo "   ✓ Syntax OK"
    else
        echo "   ✗ Syntax error!"
        echo "   Checking form_overrides..."
        sed -n '49,55p' "$ADMIN_FILE"
        exit 1
    fi
else
    echo "   ✗ File not found"
    exit 1
fi

echo ""

# 2. Fix base.py
echo "2. Fixing base.py..."
if [ -f "$BASE_FILE" ]; then
    cd "$HIDDIFY_DIR/hiddify-panel-source"
    git checkout -- hiddifypanel/base.py
    echo "   ✓ Restored from git"
    
    cd "$HIDDIFY_DIR/hiddify-agent-traffic-manager"
    python3 patches/patch_base.py "$BASE_FILE"
    echo "   ✓ Patched"
    
    # Verify syntax
    if python3 -m py_compile "$BASE_FILE" 2>&1; then
        echo "   ✓ Syntax OK"
    else
        echo "   ✗ Syntax error!"
        exit 1
    fi
else
    echo "   ✗ File not found"
    exit 1
fi

echo ""

# 3. Install from source
echo "3. Installing from source..."
cd "$HIDDIFY_DIR/hiddify-panel-source"
python3 -m pip install -e . --quiet
echo "   ✓ Installed"

echo ""

# 4. Restart service
echo "4. Restarting service..."
systemctl restart hiddify-panel
sleep 3

if systemctl is-active --quiet hiddify-panel; then
    echo "   ✓ Service is running"
else
    echo "   ✗ Service failed to start"
    echo ""
    echo "   Recent logs:"
    journalctl -u hiddify-panel -n 30 --no-pager | tail -20
    exit 1
fi

echo ""
echo "=========================================="
echo "✓ All fixes applied successfully!"
echo "=========================================="

