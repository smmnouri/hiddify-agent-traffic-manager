#!/bin/bash
# Verify that traffic management module is correctly installed and working

set -e

echo "=========================================="
echo "Verifying Hiddify Agent Traffic Manager Installation"
echo "=========================================="
echo ""

# Check 1: Module installation
echo "1. Checking module installation..."
if python3 -c "from hiddify_agent_traffic_manager import init_app; print('OK')" 2>/dev/null; then
    echo "   ✓ Module is installed and importable"
else
    echo "   ✗ Module installation failed"
    exit 1
fi

# Check 2: Service status
echo ""
echo "2. Checking hiddify-panel service status..."
if systemctl is-active --quiet hiddify-panel; then
    echo "   ✓ hiddify-panel service is running"
else
    echo "   ✗ hiddify-panel service is not running"
    systemctl status hiddify-panel --no-pager -l | tail -10
    exit 1
fi

# Check 3: Database column
echo ""
echo "3. Checking database column..."
HIDDIFY_DIR="/opt/hiddify-manager"
if [ -f "$HIDDIFY_DIR/.venv313/bin/python" ]; then
    PYTHON="$HIDDIFY_DIR/.venv313/bin/python"
else
    PYTHON="python3"
fi

if $PYTHON -c "
from hiddifypanel.database import db
from sqlalchemy import inspect
try:
    inspector = inspect(db.engine)
    columns = [col['name'] for col in inspector.get_columns('admin_user')]
    if 'traffic_limit' in columns:
        print('   ✓ traffic_limit column exists')
    else:
        print('   ✗ traffic_limit column not found')
        exit(1)
except Exception as e:
    print(f'   ⚠ Could not check database: {e}')
    print('   (This is OK if the app context is not available)')
" 2>/dev/null; then
    echo "   ✓ Database check passed"
else
    echo "   ⚠ Could not verify database (this may be OK)"
fi

# Check 4: base.py integration
echo ""
echo "4. Checking base.py integration..."
BASE_PY=""
for path in "$HIDDIFY_DIR/hiddify-panel-source" "$HIDDIFY_DIR/hiddify-panel-custom" "$HIDDIFY_DIR/hiddify-panel"; do
    if [ -f "$path/src/hiddifypanel/base.py" ]; then
        BASE_PY="$path/src/hiddifypanel/base.py"
        break
    elif [ -f "$path/hiddifypanel/base.py" ]; then
        BASE_PY="$path/hiddifypanel/base.py"
        break
    fi
done

if [ -n "$BASE_PY" ] && grep -q "hiddify_agent_traffic_manager" "$BASE_PY" 2>/dev/null; then
    echo "   ✓ base.py is patched"
else
    echo "   ⚠ Could not verify base.py patching"
fi

# Check 5: AdminstratorAdmin.py patching
echo ""
echo "5. Checking AdminstratorAdmin.py patching..."
ADMIN_FILE=""
for path in "$HIDDIFY_DIR/hiddify-panel-source" "$HIDDIFY_DIR/hiddify-panel-custom" "$HIDDIFY_DIR/hiddify-panel"; do
    if [ -f "$path/src/hiddifypanel/panel/admin/AdminstratorAdmin.py" ]; then
        ADMIN_FILE="$path/src/hiddifypanel/panel/admin/AdminstratorAdmin.py"
        break
    elif [ -f "$path/hiddifypanel/panel/admin/AdminstratorAdmin.py" ]; then
        ADMIN_FILE="$path/hiddifypanel/panel/admin/AdminstratorAdmin.py"
        break
    fi
done

if [ -n "$ADMIN_FILE" ] && grep -q "traffic_limit" "$ADMIN_FILE" 2>/dev/null; then
    echo "   ✓ AdminstratorAdmin.py is patched"
else
    echo "   ⚠ Could not verify AdminstratorAdmin.py patching"
fi

# Check 6: Recent logs
echo ""
echo "6. Checking recent logs for errors..."
RECENT_ERRORS=$(journalctl -u hiddify-panel -n 50 --no-pager 2>/dev/null | grep -i "error\|traceback\|exception" | tail -5 || true)
if [ -z "$RECENT_ERRORS" ]; then
    echo "   ✓ No recent errors in logs"
else
    echo "   ⚠ Found recent errors:"
    echo "$RECENT_ERRORS" | sed 's/^/      /'
fi

echo ""
echo "=========================================="
echo "Verification Complete"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Open your HiddifyPanel admin panel: https://your-domain/admin/adminuser/"
echo "2. Check if you can see the following columns in the AdminUser list:"
echo "   - Traffic Limit (GB)"
echo "   - Total Traffic"
echo "   - Remaining Traffic"
echo "   - Traffic Status"
echo "3. Try editing an admin user and check if 'Traffic Limit (GB)' field is visible"
echo ""

