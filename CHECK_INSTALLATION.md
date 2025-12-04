# بررسی نصب و عیب‌یابی

## بررسی اینکه آیا ماژول نصب شده است

### 1. بررسی نصب ماژول

```bash
# بررسی اینکه ماژول import می‌شود
/opt/hiddify-manager/.venv313/bin/python -c "import hiddify_agent_traffic_manager; print('OK')"
```

اگر خطا داد، ماژول نصب نشده است.

### 2. بررسی اینکه extension در base.py اضافه شده

```bash
# بررسی base.py
grep -i "hiddify_agent_traffic_manager" /opt/hiddify-manager/.venv313/lib/python3.13/site-packages/hiddifypanel/base.py
```

یا:

```bash
cat /opt/hiddify-manager/.venv313/lib/python3.13/site-packages/hiddifypanel/base.py | grep -i traffic
```

اگر چیزی پیدا نشد، extension اضافه نشده است.

### 3. بررسی Database

```bash
/opt/hiddify-manager/.venv313/bin/python << 'EOF'
from hiddifypanel.database import db
from sqlalchemy import inspect
inspector = inspect(db.engine)
columns = [col['name'] for col in inspector.get_columns('admin_user')]
print('traffic_limit column exists:', 'traffic_limit' in columns)
if 'traffic_limit' not in columns:
    print("ERROR: traffic_limit column does not exist in database!")
EOF
```

### 4. بررسی لاگ‌ها

```bash
# بررسی لاگ‌های hiddify-panel
journalctl -u hiddify-panel -n 100 --no-pager | grep -i traffic

# یا تمام لاگ‌ها
journalctl -u hiddify-panel -n 200 --no-pager
```

## راه‌حل: نصب از Repository شخصی شما

اگر می‌خواهید از repository شخصی خودتان نصب کنید (که تغییرات در سورس اعمال شده):

### روش 1: استفاده از setup_custom_repo.sh

```bash
cd /opt/hiddify-manager
git clone https://github.com/smmnouri/hiddify-agent-traffic-manager.git
cd hiddify-agent-traffic-manager
bash setup_custom_repo.sh
```

این اسکریپت:
1. HiddifyPanel را کلون می‌کند
2. تغییرات را اعمال می‌کند
3. به repository شما push می‌کند

### روش 2: استفاده از install.sh (نصب یک خطی)

```bash
bash <(curl -s https://raw.githubusercontent.com/smmnouri/hiddify-agent-traffic-manager/main/install.sh)
```

این اسکریپت:
1. Hiddify-Manager را نصب می‌کند (اگر نصب نباشد)
2. Repository سفارشی شما را کلون می‌کند
3. HiddifyPanel را از repository شما نصب می‌کند

### روش 3: نصب دستی از Repository شخصی

```bash
# 1. کلون کردن repository شخصی شما
cd /opt/hiddify-manager
git clone https://github.com/smmnouri/hiddify-panel-custom.git
cd hiddify-panel-custom

# 2. نصب از سورس
cd src  # یا مسیر صحیح
/opt/hiddify-manager/.venv313/bin/pip install -e .

# 3. Restart
systemctl restart hiddify-panel
systemctl restart hiddify-panel-background-tasks
```

## بررسی اینکه آیا از Repository شخصی نصب شده

```bash
# بررسی اینکه از کجا نصب شده
/opt/hiddify-manager/.venv313/bin/pip show hiddifypanel

# بررسی مسیر نصب
/opt/hiddify-manager/.venv313/bin/python -c "import hiddifypanel; print(hiddifypanel.__file__)"
```

اگر مسیر شامل `hiddify-panel-custom` یا repository شما باشد، از repository شخصی نصب شده.

## عیب‌یابی

### مشکل 1: فیلدها در فرم نمایش داده نمی‌شوند

**علت**: Extension به درستی extend نشده

**راه‌حل**:
```bash
# بررسی لاگ‌ها
journalctl -u hiddify-panel -n 100 --no-pager | grep -i "traffic\|extend"

# بررسی اینکه extension در base.py است
grep -i "hiddify_agent_traffic_manager" /opt/hiddify-manager/.venv313/lib/python3.13/site-packages/hiddifypanel/base.py
```

### مشکل 2: ستون‌ها در لیست نمایش داده نمی‌شوند

**علت**: AdminstratorAdmin به درستی extend نشده

**راه‌حل**:
```bash
# بررسی اینکه آیا AdminstratorAdmin extend شده
/opt/hiddify-manager/.venv313/bin/python << 'EOF'
try:
    from hiddifypanel.panel.admin.AdminstratorAdmin import AdminstratorAdmin
    if hasattr(AdminstratorAdmin, 'column_formatters') and 'traffic_limit_GB' in AdminstratorAdmin.column_formatters:
        print("OK: AdminstratorAdmin is extended")
    else:
        print("ERROR: AdminstratorAdmin is NOT extended")
        print("Available formatters:", list(getattr(AdminstratorAdmin, 'column_formatters', {}).keys()))
except Exception as e:
    print(f"ERROR: {e}")
EOF
```

### مشکل 3: Database column وجود ندارد

**راه‌حل**:
```bash
/opt/hiddify-manager/.venv313/bin/python << 'EOF'
from hiddifypanel.database import db
from sqlalchemy import inspect
inspector = inspect(db.engine)
columns = [col['name'] for col in inspector.get_columns('admin_user')]
if 'traffic_limit' not in columns:
    print("Adding traffic_limit column...")
    db.session.execute(db.text("ALTER TABLE admin_user ADD COLUMN traffic_limit BIGINT DEFAULT NULL"))
    db.session.commit()
    print("Column added successfully")
else:
    print("Column already exists")
EOF
```

## بررسی کامل نصب

اسکریپت زیر تمام موارد را بررسی می‌کند:

```bash
#!/bin/bash
echo "=== بررسی نصب Agent Traffic Manager ==="
echo ""

echo "1. بررسی نصب ماژول..."
if /opt/hiddify-manager/.venv313/bin/python -c "import hiddify_agent_traffic_manager; print('OK')" 2>/dev/null; then
    echo "✓ ماژول نصب شده است"
else
    echo "✗ ماژول نصب نشده است"
fi

echo ""
echo "2. بررسی extension در base.py..."
if grep -qi "hiddify_agent_traffic_manager" /opt/hiddify-manager/.venv313/lib/python3.13/site-packages/hiddifypanel/base.py 2>/dev/null; then
    echo "✓ Extension در base.py اضافه شده"
else
    echo "✗ Extension در base.py اضافه نشده"
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
except Exception as e:
    print(f"✗ Error: {e}")
EOF

echo ""
echo "=== پایان بررسی ==="
```

ذخیره کنید و اجرا کنید:
```bash
chmod +x check_installation.sh
./check_installation.sh
```

