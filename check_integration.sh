#!/bin/bash
# Check if traffic management is integrated

set -e

HIDDIFY_DIR="/opt/hiddify-manager"

echo "=========================================="
echo "Checking Traffic Management Integration"
echo "=========================================="
echo ""

# Check 1: Is module installed?
echo "1. Checking if module is installed..."
if python3 -c "import hiddify_agent_traffic_manager" 2>/dev/null; then
    echo "✓ Module is installed"
else
    echo "✗ Module is NOT installed"
    echo "  Run: cd $HIDDIFY_DIR/hiddify-agent-traffic-manager && pip install -e ."
fi
echo ""

# Check 2: Is AdminstratorAdmin.py patched?
echo "2. Checking if AdminstratorAdmin.py is patched..."
ADMIN_PY=""
for path in "$HIDDIFY_DIR/hiddify-panel-source" "$HIDDIFY_DIR/hiddify-panel-custom" "$HIDDIFY_DIR/hiddify-panel"; do
    if [ -f "$path/src/hiddifypanel/panel/admin/AdminstratorAdmin.py" ]; then
        ADMIN_PY="$path/src/hiddifypanel/panel/admin/AdminstratorAdmin.py"
        break
    elif [ -f "$path/hiddifypanel/panel/admin/AdminstratorAdmin.py" ]; then
        ADMIN_PY="$path/hiddifypanel/panel/admin/AdminstratorAdmin.py"
        break
    fi
done

if [ -z "$ADMIN_PY" ]; then
    # Check in site-packages
    VENV_PYTHON=""
    if [ -f "$HIDDIFY_DIR/.venv313/bin/python" ]; then
        VENV_PYTHON="$HIDDIFY_DIR/.venv313/bin/python"
    fi
    if [ -n "$VENV_PYTHON" ]; then
        SITE_PACKAGES=$("$VENV_PYTHON" -c "import site; print(site.getsitepackages()[0])" 2>/dev/null)
        if [ -f "$SITE_PACKAGES/hiddifypanel/panel/admin/AdminstratorAdmin.py" ]; then
            ADMIN_PY="$SITE_PACKAGES/hiddifypanel/panel/admin/AdminstratorAdmin.py"
        fi
    fi
fi

if [ -n "$ADMIN_PY" ] && [ -f "$ADMIN_PY" ]; then
    if grep -q "traffic_limit_GB" "$ADMIN_PY"; then
        echo "✓ AdminstratorAdmin.py is patched"
        echo "  Location: $ADMIN_PY"
    else
        echo "✗ AdminstratorAdmin.py is NOT patched"
        echo "  Location: $ADMIN_PY"
        echo "  Run: bash $HIDDIFY_DIR/hiddify-agent-traffic-manager/run_on_server.sh"
    fi
else
    echo "⚠ AdminstratorAdmin.py not found"
fi
echo ""

# Check 3: Is database column added?
echo "3. Checking if traffic_limit column exists..."
cd /opt/hiddify-manager
source .venv313/bin/activate 2>/dev/null || true

if python3 -c "
from hiddifypanel.database import db
from sqlalchemy import inspect
try:
    inspector = inspect(db.engine)
    columns = [col['name'] for col in inspector.get_columns('admin_user')]
    if 'traffic_limit' in columns:
        print('✓ traffic_limit column exists')
    else:
        print('✗ traffic_limit column does NOT exist')
        print('  Run: python3 $HIDDIFY_DIR/hiddify-agent-traffic-manager/migrations/migrate_with_app.py')
except Exception as e:
    print(f'⚠ Could not check: {e}')
" 2>/dev/null; then
    :
else
    echo "⚠ Could not check database (app context needed)"
fi
echo ""

# Check 4: Is module initialized in base.py?
echo "4. Checking if module is initialized..."
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

if [ -z "$BASE_PY" ]; then
    # Check in site-packages
    if [ -n "$VENV_PYTHON" ]; then
        SITE_PACKAGES=$("$VENV_PYTHON" -c "import site; print(site.getsitepackages()[0])" 2>/dev/null)
        if [ -f "$SITE_PACKAGES/hiddifypanel/base.py" ]; then
            BASE_PY="$SITE_PACKAGES/hiddifypanel/base.py"
        fi
    fi
fi

if [ -n "$BASE_PY" ] && [ -f "$BASE_PY" ]; then
    if grep -q "hiddify_agent_traffic_manager" "$BASE_PY"; then
        echo "✓ Module is initialized in base.py"
        echo "  Location: $BASE_PY"
    else
        echo "✗ Module is NOT initialized in base.py"
        echo "  Location: $BASE_PY"
        echo "  Need to add: from hiddify_agent_traffic_manager import init_app"
    fi
else
    echo "⚠ base.py not found"
fi
echo ""

# Check 5: Service status
echo "5. Checking service status..."
if systemctl is-active --quiet hiddify-panel; then
    echo "✓ hiddify-panel is running"
else
    echo "✗ hiddify-panel is NOT running"
    echo "  Run: systemctl restart hiddify-panel"
fi
echo ""

echo "=========================================="
echo "Summary:"
echo "=========================================="
echo "If all checks pass, traffic management should be visible at /admin/adminuser/"
echo "If not, please:"
echo "1. Ensure module is installed: pip install -e /opt/hiddify-manager/hiddify-agent-traffic-manager"
echo "2. Ensure patches are applied: bash /opt/hiddify-manager/hiddify-agent-traffic-manager/run_on_server.sh"
echo "3. Ensure database migration is done"
echo "4. Restart services: systemctl restart hiddify-panel hiddify-panel-background-tasks"

