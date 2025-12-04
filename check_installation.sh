#!/bin/bash
# Script to check if Agent Traffic Manager is properly installed

echo "=== بررسی نصب Agent Traffic Manager ==="
echo ""

echo "1. بررسی نصب ماژول..."
if /opt/hiddify-manager/.venv313/bin/python -c "import hiddify_agent_traffic_manager; print('OK')" 2>/dev/null; then
    echo "✓ ماژول نصب شده است"
else
    echo "✗ ماژول نصب نشده است"
    echo "  راه‌حل: pip install -e /opt/hiddify-manager/hiddify-agent-traffic-manager"
fi

echo ""
echo "2. بررسی extension در base.py..."
BASE_PY="/opt/hiddify-manager/.venv313/lib/python3.13/site-packages/hiddifypanel/base.py"
if [ -f "$BASE_PY" ]; then
    if grep -qi "hiddify_agent_traffic_manager" "$BASE_PY" 2>/dev/null; then
        echo "✓ Extension در base.py اضافه شده"
    else
        echo "✗ Extension در base.py اضافه نشده"
        echo "  راه‌حل: اجرای install_complete.sh"
    fi
else
    echo "✗ base.py پیدا نشد: $BASE_PY"
fi

echo ""
echo "3. بررسی Database..."
/opt/hiddify-manager/.venv313/bin/python << 'EOF'
from hiddifypanel.database import db
from sqlalchemy import inspect
try:
    inspector = inspect(db.engine)
    columns = [col['name'] for col in inspector.get_columns('admin_user')]
    if 'traffic_limit' in columns:
        print("✓ traffic_limit column exists")
    else:
        print("✗ traffic_limit column does NOT exist")
        print("  راه‌حل: اجرای init_agent_traffic")
except Exception as e:
    print(f"✗ Error: {e}")
EOF

echo ""
echo "4. بررسی AdminstratorAdmin extension..."
/opt/hiddify-manager/.venv313/bin/python << 'EOF'
try:
    from hiddifypanel.panel.admin.AdminstratorAdmin import AdminstratorAdmin
    if hasattr(AdminstratorAdmin, 'column_formatters') and 'traffic_limit_GB' in AdminstratorAdmin.column_formatters:
        print("✓ AdminstratorAdmin is extended")
    else:
        print("✗ AdminstratorAdmin is NOT extended")
        print("  Available formatters:", list(getattr(AdminstratorAdmin, 'column_formatters', {}).keys()))
        print("  راه‌حل: بررسی لاگ‌ها و restart سرویس")
except Exception as e:
    print(f"✗ Error: {e}")
EOF

echo ""
echo "5. بررسی مسیر نصب HiddifyPanel..."
/opt/hiddify-manager/.venv313/bin/python << 'EOF'
try:
    import hiddifypanel
    path = hiddifypanel.__file__
    print(f"مسیر نصب: {path}")
    if 'hiddify-panel-custom' in path or 'smmnouri' in path:
        print("✓ از repository شخصی نصب شده")
    else:
        print("⚠ از repository رسمی نصب شده (نیاز به repository شخصی)")
except Exception as e:
    print(f"✗ Error: {e}")
EOF

echo ""
echo "6. بررسی لاگ‌های اخیر..."
echo "--- آخرین 20 خط لاگ ---"
journalctl -u hiddify-panel -n 20 --no-pager | grep -i "traffic\|extend\|agent" || echo "هیچ لاگ مرتبطی پیدا نشد"

echo ""
echo "=== پایان بررسی ==="
echo ""
echo "اگر مشکلاتی وجود دارد، به CHECK_INSTALLATION.md مراجعه کنید"

