#!/bin/bash
# Check and fix hiddify-panel crash

set -e

HIDDIFY_DIR="/opt/hiddify-manager"

echo "=========================================="
echo "Checking HiddifyPanel Crash"
echo "=========================================="
echo ""

# Check service status
echo "1. Checking service status..."
if systemctl is-active --quiet hiddify-panel; then
    echo "✓ hiddify-panel is running"
    exit 0
else
    echo "✗ hiddify-panel is NOT running"
fi
echo ""

# Check logs
echo "2. Checking recent logs..."
echo "Last 50 lines of hiddify-panel logs:"
journalctl -u hiddify-panel -n 50 --no-pager | tail -20
echo ""

# Check for syntax errors in patched files
echo "3. Checking for syntax errors..."

# Check base.py
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

if [ -n "$BASE_PY" ] && [ -f "$BASE_PY" ]; then
    echo "Checking base.py syntax..."
    python3 -m py_compile "$BASE_PY" 2>&1
    if [ $? -eq 0 ]; then
        echo "✓ base.py syntax is OK"
    else
        echo "✗ base.py has syntax errors!"
        echo "Restoring from backup..."
        BACKUP=$(ls -t "${BASE_PY}.backup."* 2>/dev/null | head -n1)
        if [ -n "$BACKUP" ] && [ -f "$BACKUP" ]; then
            cp "$BACKUP" "$BASE_PY"
            echo "✓ Restored from backup: $BACKUP"
        fi
    fi
fi

# Check AdminstratorAdmin.py
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

if [ -n "$ADMIN_PY" ] && [ -f "$ADMIN_PY" ]; then
    echo "Checking AdminstratorAdmin.py syntax..."
    python3 -m py_compile "$ADMIN_PY" 2>&1
    if [ $? -eq 0 ]; then
        echo "✓ AdminstratorAdmin.py syntax is OK"
    else
        echo "✗ AdminstratorAdmin.py has syntax errors!"
        echo "Restoring from backup..."
        BACKUP=$(ls -t "${ADMIN_PY}.backup."* 2>/dev/null | head -n1)
        if [ -n "$BACKUP" ] && [ -f "$BACKUP" ]; then
            cp "$BACKUP" "$ADMIN_PY"
            echo "✓ Restored from backup: $BACKUP"
        fi
    fi
fi

echo ""

# Check if module can be imported
echo "4. Checking if module can be imported..."
cd /opt/hiddify-manager
source .venv313/bin/activate 2>/dev/null || true

python3 -c "
try:
    from hiddify_agent_traffic_manager import init_app
    print('✓ Module can be imported')
except Exception as e:
    print(f'✗ Module import failed: {e}')
    import traceback
    traceback.print_exc()
" 2>&1

echo ""

# Try to start service
echo "5. Attempting to start service..."
systemctl start hiddify-panel
sleep 3

if systemctl is-active --quiet hiddify-panel; then
    echo "✓ Service started successfully"
else
    echo "✗ Service still failed"
    echo ""
    echo "Recent errors:"
    journalctl -u hiddify-panel -n 20 --no-pager | grep -i error
fi

