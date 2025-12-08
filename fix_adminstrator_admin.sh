#!/bin/bash
# Fix AdminstratorAdmin.py syntax error

set -e

ADMIN_FILE="/opt/hiddify-manager/hiddify-panel-source/hiddifypanel/panel/admin/AdminstratorAdmin.py"

echo "=========================================="
echo "Fixing AdminstratorAdmin.py"
echo "=========================================="
echo ""

if [ ! -f "$ADMIN_FILE" ]; then
    echo "✗ File not found: $ADMIN_FILE"
    exit 1
fi

# Backup
BACKUP="${ADMIN_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$ADMIN_FILE" "$BACKUP"
echo "✓ Backup created: $BACKUP"
echo ""

# Check current syntax
echo "Checking syntax before fix..."
python3 -m py_compile "$ADMIN_FILE" 2>&1 || true
echo ""

# Restore from git first
cd /opt/hiddify-manager/hiddify-panel-source
git checkout -- hiddifypanel/panel/admin/AdminstratorAdmin.py
echo "✓ Restored from git"
echo ""

# Re-patch
cd /opt/hiddify-manager/hiddify-agent-traffic-manager
python3 patches/patch_adminstrator_admin.py "$ADMIN_FILE"
echo ""

# Check syntax after patch
echo "Checking syntax after patch..."
if python3 -m py_compile "$ADMIN_FILE" 2>&1; then
    echo "✓ Syntax is correct"
else
    echo "✗ Syntax error still exists"
    echo ""
    echo "Checking import location..."
    grep -n "TrafficLimitField" "$ADMIN_FILE" | head -10
    echo ""
    echo "Checking form_overrides..."
    sed -n '49,60p' "$ADMIN_FILE"
    exit 1
fi

echo ""
echo "✓ AdminstratorAdmin.py fixed successfully"

